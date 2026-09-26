# Compatibility Matrix — DNSCrypt Smart Filter

Comprehensive compatibility reference: Android, ROMs, Kernels, Chipsets, Firewalls.

**Version**: v1.1.0
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • Added a new section §5.4 (Memory profile by device RAM)
>     that maps the v1.1.0 dynamic memory limit to the SoC/RAM
>     tier recommended for each profile.
>   • §1.3 (What's New) extended with MEM-1 / MEM-2 / MEM-3.
>   • §2.3 (Dashboard compatibility) updated with the two new
>     `runtime_info` fields.
>   • §6.4 (Firewall + v1.0.0) extended with v1.1.0 additions.
>   • §7.2 (Root + compatibility) extended with the v1.1.0
>     verification table.
>   • §8.1 (Known issues) gained four v1.1.0 entries.
>   • §8.3 (v1.1.0-specific issues) — new section.
>   • §10.3 (v1.1.0 compatibility testing) — new verification
>     checklist.
>   • No changes to the core compatibility rules.

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

### 1.3 What's New in v1.1.0

**Compatibility-relevant changes**:

| # | Change | Compatibility impact |
|:-:|---|---|
| **1** | **MEM-1: Dynamic memory limit per profile** | ✅ Improves performance on light profiles (less GC) and heavy profiles (no GC thrashing). See §5.4. |
| **2** | **MEM-2: Extended `shellQuote` (24 chars)** | ⚪ No impact on user |
| **3** | **MEM-3: `MONITORING_UI_PORT` constant** | ⚪ No impact on user |
| **4** | **`runtime_info` new fields** (`profile_key`, `memory_limit_mb`) | ✅ Displayed in System Info panels |
| **5** | **`get_profile` new field** (`memory_limit_mb`) | ✅ Additive — clients unaffected |
| **6** | **Uninstall no longer creates backup** | ⚠️ Manual backup recommended (see §8.3) |

**Base compatibility**: no change in system requirements.

### 1.4 What Was New in v1.0.0

**Compatibility-relevant changes** (for reference):

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
| **9** | Login POST-only | ⚠️ GET on `/api/auth/login` rejected (405) |
| **10** | `/readyz` localhost-only | ⚠️ LAN requests rejected (403) |
| **11** | `shellQuote()` | ⚪ No impact on user |
| **12** | `readConfPort` range check | ✅ Safe fallback for invalid values |
| **13** | `rebuildMu` mutex (RACE-1) | ✅ BLOCKLIST always consistent |
| **14** | `runtime_info` dynamic ports (PORT-2) | ✅ Dynamic links |
| **15** | Auth cache (60 s) | ⚠️ Credential changes take effect after ≤ 60 s |

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
- ✅ Dashboard works (Fix #1).
- ✅ Dynamic memory limit applies (v1.1.0).

**Android 8-9**:
- ✅ Works.
- ⚠️ Battery optimization may stop the Watchdog.
- 💡 **Solution**: add to exceptions.

**Android 6-7**:
- ⚠️ Doze mode stops services.
- 💡 **Solution**: disable battery optimization.
- ⚠️ iptables may differ.
- ✅ `getSystemShell()`: works correctly on all versions.

**Android 5**:
- ⚠️ Requires kernel 3.10+.
- ⚠️ May not support nftables.
- ⚠️ `pgrep -x`: may not work properly → fallback in code.
- 🆕 `sync.Once`: requires Go 1.22+ (available in the build).

### 2.2 Dashboard Compatibility

| Browser | SVG Icons | PNG Icons | JSON Metrics | Login POST | Profile/Memory |
|---|:---:|:---:|:---:|:---:|:---:|
| Chrome 90+ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Chrome 88-89 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Firefox 92+ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Safari 15+ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Samsung Internet 16+ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **IE 11** | ❌ | ✅ | ❌ | ❌ | ❌ |

**Reason**: v1.0.0 added PNG icons to precache, supporting older browsers.

**Note**: Login POST-only requires `fetch()` or `XMLHttpRequest` — all modern browsers support it.

### 2.3 Dashboard — v1.1.0 Fields

The System Info panel in both `index.html` and `dashboard.html`
now displays two additional rows populated from
`runtime_info`:

| Row | Field | Type |
|---|---|---|
| **Profile** | `profile_key` | string |
| **Memory limit** | `memory_limit_mb` | int |

**Compatibility**:
- ✅ All modern browsers (Chrome 88+, Firefox 92+, Safari 15+,
  Samsung Internet 16+) render the new rows without any change.
- ⚠️ IE 11: not supported (already excluded).
- ✅ No new browser API is used — the fields are simple text
  rendered from the existing JSON response.

### 2.4 Platform Support

| Platform | `getSystemShell()` | `hasEndpoint()` | Dashboard JSON | `memoryLimitForProfile` |
|---|:---:|:---:|:---:|:---:|
| Android | ✅ | ✅ | ✅ | ✅ |
| Linux (CI) | ✅ | ✅ | ✅ | ✅ |
| macOS (dev) | ✅ | ✅ | ✅ | ✅ |
| Termux | ⚠️ | ✅ | ✅ | ✅ |
| Windows (WSL2) | ✅ | ✅ | ✅ | ✅ |

Before v1.0.0: Linux/macOS failed in `runShell` (path
`/system/bin/sh` did not exist).
After v1.0.0: `getSystemShell()` selects the right path
automatically.

**v1.1.0**: `memoryLimitForProfile` uses only the Go standard
library (`runtime/debug`) — no platform-specific behavior.

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

On all supported ROMs, since v1.0.0 the installer preserves:
- `webui.conf`
- `dnscrypt-proxy.toml`
- `selected_profile.txt`
- `allowlist.txt`
- `denylist.txt`

**Note**: On older ROMs (< Android 9), backup may fail if
`/data/local/tmp/` is restricted. Check the log:

```bash
grep "Backed up\|Restored" /data/local/tmp/dnscrypt_install.log
```

**Verify after upgrade**:

```bash
su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# Must display your custom value (not the default 9090)
```

**v1.1.0 addition**: The preserved `selected_profile.txt` drives
the memory limit. If the file is missing after upgrade, `main.go`
falls back to `"pro"` — verify it survived:

```bash
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Expected: one of light / normal / pro / proplus / ultimate
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

| Feature | Minimum | In v1.1.0 |
|---|---|---|
| iptables-nat | 3.10 | — |
| nftables | 4.10 | — |
| netns | 3.0 | — |
| cgroup v2 | 4.5 | — |
| `/bin/sh` | 4.x+ | ✅ (Linux dev) |
| `sync.Once` (Go runtime) | 4.4+ | ✅ |
| `sync.Mutex` (Go runtime) | 3.x+ | ✅ |
| **`debug.SetMemoryLimit`** | **3.x+ (Go runtime)** | **✅ (v1.1.0)** |

**Note**: `debug.SetMemoryLimit` was introduced in Go 1.19.
Since v1.1.0 uses Go 1.22, this is available on all supported
kernel versions — the kernel itself is not involved.

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

**Result**: v1.1.0 does not strain weak devices.

### 5.3 RACE-1 Performance

| Arch | `rebuildBlocklist` (100K) | `rebuildBlocklist` (500K) |
|---|:---:|:---:|
| arm64-v8a | ~200 ms | ~1 s |
| armeabi-v7a | ~600 ms | ~3 s |
| x86_64 | ~180 ms | ~900 ms |
| x86 | ~800 ms | ~4 s |

**Note**: `rebuildMu` adds no noticeable overhead (coarse-grained lock).

### 5.4 Memory Profile by Device RAM (v1.1.0 — MEM-1)

**This is the recommended profile by device tier.** The WebUI
process sets a per-profile **soft** memory limit (see §1.3
for MEM-1). Choosing a profile that matches your device's RAM
avoids GC thrashing on the WebUI process while keeping DNS
filtering effective.

| Device RAM | Recommended profile | WebUI soft limit | Filters |
|---|:---:|---:|:---:|
| **1 GB** | `light` | 80 MB | ~40K entries |
| **2 GB** | `normal` | 100 MB | ~120K entries |
| **3 GB** | `pro` (default) | 120 MB | ~250K entries |
| **4 GB** | `proplus` | 160 MB | ~350K entries |
| **6 GB+** | `ultimate` | 220 MB | ~500K entries |

#### 5.4.1 What "Soft Limit" Means

- `debug.SetMemoryLimit` is a **soft** limit.
- The Go runtime does **not** kill the process when the limit is
  reached — it runs GC more aggressively instead.
- Setting the limit too low → GC runs constantly → CPU waste → the
  WebUI appears slow or unresponsive even though it is not crashed.
- Setting the limit too high → RAM waste, especially on
  low-RAM devices.

**v1.1.0** chooses the limit automatically based on the profile.
No user configuration is needed.

#### 5.4.2 What Happens on Under-Powered Devices

If you run `ultimate` on a 2 GB device:

- ✅ It will work.
- ⚠️ The WebUI may feel slow after long DNS activity.
- ⚠️ Battery consumption may increase slightly.
- ⚠️ Background apps might be killed by Android's LMK.

**Recommendation**: match the profile to the device RAM tier.

#### 5.4.3 What Happens on Over-Powered Devices

If you run `light` on a 12 GB device:

- ✅ It works perfectly.
- ⚠️ You lose blocking for many domains.
- ⚠️ No performance benefit versus `pro`.

**Recommendation**: choose based on filtering goals, not just
RAM.

#### 5.4.4 How to Change the Profile

```bash
# From the WebUI:
#   Select a profile → Apply.

# Or from the terminal:
su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# Verify (wait ~5 s after restart):
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" \
    | jq '{profile_key, memory_limit_mb}'
```

#### 5.4.5 How to Read the Value

```bash
# Via runtime_info:
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'
# Expected: 80 / 100 / 120 / 160 / 220 (MB)

# Via status.sh (v1.1.0):
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh" | grep -A3 "Profile & Memory"

# Via the System Info panel:
#   Open the WebUI → scroll to "System Info" → expand.
#   Look for "Profile" and "Memory limit".
```

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
- ✅ `rebuildMu` (RACE-1) protects `rebuildBlocklist` from race conditions.
- ✅ `runtime_info` (PORT-2) returns actual ports (no hardcoded).

### 6.5 Firewall + v1.1.0

**No firewall changes in v1.1.0.** Custom Chains, `manage_firewall`,
and `_inline_cleanup_firewall` are unchanged.

**v1.1.0 additions relevant to firewall scripts**:

| Change | Impact on firewall |
|---|---|
| MEM-2 (extended `shellQuote`) | ✅ More robust when passing `MODDIR` to `runShell` for iptables commands |
| MEM-3 (`MONITORING_UI_PORT` constant) | ⚪ Unrelated to firewall |
| MEM-1 (memory limit) | ⚪ Unrelated to firewall |

**Verify v1.1.0 firewall-related changes**:

```bash
# MEM-2: shellQuote extended charset
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ braces"
grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\n'" && echo "✅ newline"

# Firewall unaffected: verify no orphans
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# → 0

# Verify Custom Chains still functional
su -c "iptables -t nat -L DNSCRYPT_OUT -n 2>/dev/null | head -3"
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

### 7.2 Root + v1.1.0 Compatibility

| Feature | Magisk 20.4+ | KernelSU | APatch |
|---|:---:|:---:|:---:|:---:|
| Backup/Restore | ✅ | ✅ | ✅ |
| Fix #1 verify | ✅ | ✅ | ✅ |
| Fix #2 verify | ✅ | ✅ | ✅ |
| NEW-1..NEW-6 verify | ✅ | ✅ | ✅ |
| RACE-1 + PORT-2 verify | ✅ | ✅ | ✅ |
| `hasEndpoint` | ✅ | ✅ | ✅ |
| Dashboard JSON | ✅ | ✅ | ✅ |
| Login POST-only | ✅ | ✅ | ✅ |
| `/readyz` localhost-only | ✅ | ✅ | ✅ |
| `rebuildMu` mutex | ✅ | ✅ | ✅ |
| `runtime_info` ports | ✅ | ✅ | ✅ |
| **MEM-1 memory limit** | **✅** | **✅** | **✅** |
| **MEM-2 extended shellQuote** | **✅** | **✅** | **✅** |
| **MEM-3 MONITORING_UI_PORT** | **✅** | **✅** | **✅** |
| **`runtime_info` profile_key + memory_limit_mb** | **✅** | **✅** | **✅** |
| **`get_profile` memory_limit_mb** | **✅** | **✅** | **✅** |

**`customize.sh` works the same way on all Root solutions.**

**v1.1.0 note**: MEM-1 uses `debug.SetMemoryLimit` from the Go
standard library. It is unrelated to the root solution — the
same behavior applies everywhere.

### 7.3 Verification on Device

```bash
# 1. Check version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.1.0

# 2. Fix #2 — getSystemShell
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui | grep -q 'getSystemShell' && echo '✅ Fix #2'"

# 3. Fix #1 — buildDashboardJSON
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui | grep -q 'buildDashboardJSON' && echo '✅ Fix #1'"

# 4. RACE-1 — rebuildMu
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui | grep -q 'rebuildMu' && echo '✅ RACE-1'"

# 5. MEM-1 — memoryLimitForProfile
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui | grep -q 'memoryLimitForProfile' && echo '✅ MEM-1'"

# 6. MEM-1 — MEMORY_LIMIT constants
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui | grep -q 'MEMORY_LIMIT_ULTIMATE' && echo '✅ MEM-1 constants'"
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
    http://127.0.0.1:9090/api?status
done
# Expected: 401 × 5 then 401 (locked)

# 6. MEM-1 — memory_limit_mb present
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'
# Expected: a number (80 / 100 / 120 / 160 / 220)

# 7. MEM-1 — profile_key present
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'
# Expected: light / normal / pro / proplus / ultimate

# 8. MEM-1 — profile_key matches selected_profile.txt
diff <(curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key') \
     <(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
# Expected: no diff output
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
| 12 | Dashboard shows empty data | Pre-v1.0.0 | Update to v1.0.0+ |
| 13 | Basic Auth locked after 5 attempts | v1.0.0+ | Wait 15 min or restart WebUI |
| 14 | 404 for unknown action | v1.0.0+ | Update the script to expect 404 |
| 15 | CI Go build fails on Linux | Pre-v1.0.0 | Update to v1.0.0+ |
| 16 | Settings lost on upgrade | Pre-v1.0.0 | Update to v1.0.0+ |
| 17 | Login GET rejected (405) | v1.0.0+ | Update integration to use POST |
| 18 | `/readyz` from LAN rejected (403) | v1.0.0+ | Use `/healthz` instead |
| 19 | Credentials change delay (60 s) | v1.0.0+ | Wait 60 s or restart WebUI |
| 20 | Blocklist rebuild may take time on long lists | v1.0.0+ | Normal — RACE-1 serializes rebuilds |
| **21** | **WebUI slow on `ultimate` (pre-v1.1.0)** | **v1.0.0** | **Update to v1.1.0 (MEM-1)** |
| **22** | **`profile_key` mismatch (rare)** | **v1.1.0+** | **Fix `selected_profile.txt` + restart** |
| **23** | **No auto-backup on uninstall** | **v1.1.0+** | **Manual backup before uninstall** |
| **24** | **`memory_limit_mb` unexpected** | **v1.1.0+** | **Check startup log + `selected_profile.txt`** |

### 8.2 VPN Interaction

**VPN + DNSCrypt = conflict:**
- The VPN app takes `redirect` priority.
- DNS queries go through the VPN instead of the module.
- **Solution**: use only one of them.

### 8.3 v1.1.0-specific Issues

**Issue #21 — WebUI slow on `ultimate` (pre-v1.1.0)**:

- **Symptom** (v1.0.0 only): After switching to `ultimate`, the
  WebUI becomes slow or unresponsive. CPU is high on the WebUI
  process. Dashboard loads take 10+ seconds.
- **Cause**: `debug.SetMemoryLimit(80 MB)` was hardcoded in
  v1.0.0. On `ultimate`, actual working set approaches 200 MB
  → GC thrashing.
- **Solution**: Update to **v1.1.0** — the limit is now computed
  per profile (220 MB for `ultimate`).
- **Verify**:
  ```bash
  su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'"
  # Expected: 220 (for ultimate on v1.1.0)
  ```
- **Reference**: [SECURITY.md](SECURITY.md) §5.30.1;
  [TROUBLESHOOTING.md](TROUBLESHOOTING.md) §6.10.

**Issue #22 — `profile_key` mismatch (rare)**:

- **Symptom**: `runtime_info.profile_key` does not match
  `selected_profile.txt`, or the memory limit does not match the
  expected value for the profile.
- **Cause**: The WebUI reads the profile file only at startup
  and after `POST /api/update_profile`. Direct edits to the file
  are not monitored.
- **Solution**: Restart the WebUI:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  ```
- **Verify**:
  ```bash
  diff <(curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key') \
       <(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
  # Expected: no diff
  ```
- **Reference**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) §5.14.

**Issue #23 — No auto-backup on uninstall**:

- **Symptom**: After uninstalling on v1.1.0, no backup directory
  is created.
- **Cause**: Intentional — v1.1.0 removed the auto-backup on
  uninstall.
- **Solution**: Take a manual backup before uninstalling:
  ```bash
  su -c "mkdir -p /sdcard/dnscrypt-backup-$(date +%Y%m%d)"
  su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
  # ... (see INSTALL.md §10.5 for the full list)
  ```
- **Reference**: [INSTALL.md](INSTALL.md) §10.5;
  [UPGRADE.md](UPGRADE.md) §6.5.

**Issue #24 — `memory_limit_mb` unexpected**:

- **Symptom**: `runtime_info.memory_limit_mb` does not match the
  expected value for the active profile.
- **Cause**: The startup log may show an error, or the profile
  file may be missing/invalid.
- **Solution**:
  1. Verify the profile file:
     ```bash
     su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
     ```
  2. Verify the startup log:
     ```bash
     su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
     ```
  3. If either is wrong, fix and restart:
     ```bash
     su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
     su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
     ```
- **Reference**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) §4.12, §5.14.

---

## 9. Bug Report Template

When reporting an issue, use the following template:

```markdown
## Environment

- **Module version**: v1.1.0
- **Android version**: 14 (API 34)
- **ROM**: LineageOS 21
- **Kernel**: 5.15.94-lineageos
- **SoC**: Snapdragon 8 Gen 2
- **Root**: Magisk 27.0
- **Architecture**: arm64-v8a

## Profile & Memory (v1.1.0)

- **Active profile** (from `selected_profile.txt`):
- **`profile_key`** (from `runtime_info`):
- **`memory_limit_mb`** (from `runtime_info`):
- **Expected limit for the profile** (see §5.4):

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
[Paste content here — include the "dynamic memory limit" line if present]
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
  "version": "v1.1.0",
  "webui_port": "9090",
  "dashboard_port": "9091",
  "profile_key": "pro",
  "memory_limit_mb": 120,
  ...
}
```
</details>

## Additional Context

- [ ] Works on a previous version
- [ ] New in v1.1.0
- [ ] Intermittent

## Screenshots

[If possible]
```

### 9.1 Quick Diagnostics Script

```bash
#!/bin/bash
# diagnose.sh — collect all information in one shot (v1.1.0)

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
echo "=== Profile & Memory (v1.1.0) ==="
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"

echo ""
echo "=== Firewall ==="
su -c "iptables -t nat -L OUTPUT -n | head -5"
su -c "iptables -t nat -L DNSCRYPT_OUT -n 2>/dev/null | head -5"
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n 2>/dev/null | head -5"

echo ""
echo "=== Dashboard ==="
su -c "curl -s http://127.0.0.1:9091/api/metrics" | head -20

echo ""
echo "=== Runtime Info ==="
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

### 9.2 v1.1.0-specific Diagnostics

```bash
#!/bin/bash
# diagnose-v110.sh — v1.1.0-specific checks

echo "=== MEM-1: Memory limit active ==="
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" \
    | jq '{profile_key, memory_limit_mb}'

echo ""
echo "=== MEM-1: Startup log line ==="
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"

echo ""
echo "=== MEM-1: Profile file vs runtime ==="
echo -n "selected_profile.txt: "
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
echo -n "runtime profile_key:  "
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'"

echo ""
echo "=== MEM-2: Extended shellQuote (binary check) ==="
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui 2>/dev/null | grep -q 'shellQuote' && echo '✅ shellQuote present in binary'"

echo ""
echo "=== MEM-3: MONITORING_UI_PORT (source only) ==="
# Not present in the binary — verify via the repo
grep -q 'MONITORING_UI_PORT' proxy/main.go 2>/dev/null && echo "✅ MEM-3 present in source" \
    || echo "ℹ️  Source not available on device (this is normal)"

echo ""
echo "=== v1.1.0: Version in all files ==="
V=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/module.prop" | grep '^version=' | cut -d= -f2)
echo "module.prop: $V"
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.version'" \
    | xargs -I{} echo "runtime_info: {}"

echo ""
echo "✅ v1.1.0-specific diagnostics complete."
```

---

## 10. Contributing Reports

### 10.1 We Welcome

- Compatibility reports from rare devices.
- Testing on different or modified ROMs.
- Solutions and workarounds for known issues.
- Detailed logs.
- Dashboard reports on different browsers.
- Platform reports (Linux, macOS, WSL2).
- Performance reports (`rebuildBlocklist` duration).
- **v1.1.0**: Memory-limit reports per device RAM tier.

### 10.2 How to Contribute

1. Test on your device.
2. Fill in the template above.
3. Open an Issue titled `[Compat] <Device> <Android>`.
4. Attach the logs.

### 10.3 Compatibility Testing for v1.1.0

**Recommended tests**:

```bash
# 1. Test Dashboard (Fix #1, still in v1.1.0)
echo "Open http://127.0.0.1:9091"
echo "Should show: total_queries, blocked_queries, cache_stats"

# 2. Test shell fallback (Fix #2, still in v1.1.0)
echo "Test on Linux/macOS (dev):"
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go
grep -q 'func getSystemShell' main.go && echo "✅ getSystemShell present"

# 3. Test Basic Auth rate limit (Fix #8, still in v1.1.0)
echo "5 failed attempts:"
for i in {1..6}; do
  curl -u "wrong:wrong" -o /dev/null -w "%{http_code}\n" \
    http://127.0.0.1:9090/api?action=status
done

# 4. Test 404 (Fix #12, still in v1.1.0)
echo "Unknown action:"
curl -i "http://127.0.0.1:9090/api?action=nonexistent"
# → 404 Not Found

# 5. Test Preserve Settings (Fix #3, still in v1.1.0)
echo "After upgrade:"
su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

# 6. Test Login POST-only (NEW-1, still in v1.1.0)
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# → 405 Method Not Allowed + Allow: POST

# 7. Test /readyz localhost-only (NEW-4, still in v1.1.0)
curl -i http://127.0.0.1:9091/readyz
# → 200 or 503 (from localhost)

# 8. Test shellQuote (NEW-5 + MEM-2)
grep -q 'func shellQuote' proxy/main.go && echo "✅ NEW-5 present"
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ MEM-2 braces"

# 9. Test Auth cache (NEW-6, still in v1.1.0)
grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅ NEW-6 present"

# 10. Test RACE-1 (rebuildMu)
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"

# 11. Test PORT-2 (runtime_info ports)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'

# 12. Test MEM-1 (memory limit)
grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1 function"
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'

# 13. Test MEM-1 (no hardcoded limit remains)
! grep -q 'debug.SetMemoryLimit(80 \* 1024 \* 1024)' proxy/main.go && echo "✅ MEM-1 no hardcoded"

# 14. Test MEM-3 (MONITORING_UI_PORT in metrics handler)
grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"

# 15. Test v1.1.0 profile_key (runtime_info field)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'
# Expected: light / normal / pro / proplus / ultimate
```

### 10.4 Hall of Fame

Compatibility contributors are listed in [`HALL_OF_FAME.md`](HALL_OF_FAME.md#-compatibility-champions).

### 10.5 Platform Champions

New badge for those testing on **non-Android platforms** (Linux, macOS, WSL2):

- 🖥️ Testing on Linux (CI-like environment).
- 🍎 Testing on macOS.
- 🐧 Testing on WSL2 (Windows).

**Benefit**: improves `getSystemShell()` and platform-agnostic shell behavior.

### 10.6 Memory Architect Badge (v1.1.0)

New badge for contributors who:

- Test the dynamic memory limit on multiple RAM tiers.
- Report GC-related issues with concrete data (profile, RSS,
  CPU sample, `runtime_info` output).
- Propose improvements to the per-profile constants.

**Reference**: [`HALL_OF_FAME.md`](HALL_OF_FAME.md) — Memory Architect.

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
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)

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

*Last updated: 2026-09-26*
*Version: v1.1.0*
*Author: gasciljh*