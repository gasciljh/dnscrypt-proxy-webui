# Upgrade Guide — DNSCrypt Smart Filter

> Comprehensive guide for upgrading between DNSCrypt Smart Filter versions.

**Current version**: v1.1.0
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **📖 Related documents**:
> - Git workflow → [`docs/BRANCHING.md`](BRANCHING.md)
> - Release process → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decisions → [`docs/adr/README.md`](adr/README.md)
> - Installation guide → [`docs/INSTALL.md`](INSTALL.md)

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • Added §1.3 — Project version history (v1.0.0 → v1.1.0).
>   • Added §3.0 — Upgrading from v1.0.0 to v1.1.0 (the first
>     in-place upgrade). Includes the memory-limit transition
>     and the two new `runtime_info` fields.
>   • Updated §2 (Settings Preservation) with the v1.1.0 behavior.
>   • Updated §4 (Verification) with the two new runtime_info fields.
>   • Updated §5 (API Behavior Notes) with the MEM-1 additions.
>   • Updated §6.3 (Settings missing) with memory-limit recovery.
>   • Updated §6.5 (Uninstall) to note that v1.1.0 no longer
>     creates a backup directory.
>   • No structural changes to the emergency recovery procedures.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Settings Preservation](#2-settings-preservation)
3. [Upgrade Procedure](#3-upgrade-procedure)
4. [Verification After Upgrade](#4-verification-after-upgrade)
5. [API Behavior Notes (v1.1.0)](#5-api-behavior-notes-v110)
6. [Emergency Recovery](#6-emergency-recovery)
7. [References](#7-references)

---

## 1. Overview

### 1.1 Current Release

**v1.1.0 is the second stable release** of DNSCrypt Smart Filter.

**v1.0.0** (2026-09-24) was the first stable release — it
consolidated the entire development effort into a single
production-ready version with 33 audit corrections.

**v1.1.0** (2026-09-26) is a **polish release**:

- **No breaking changes**.
- **No new audit corrections**.
- **Three runtime improvements** (MEM-1, MEM-2, MEM-3).
- **Two new `runtime_info` fields** (`profile_key`, `memory_limit_mb`).
- **Documentation updates** across `docs/`.

See [CHANGELOG.md](../CHANGELOG.md) for the full history.

This guide covers:

- The **settings preservation mechanism** that applies to all
  in-place upgrades.
- The **general upgrade procedure** for future versions.
- The **specific upgrade from v1.0.0 to v1.1.0** (§3.0).
- **Emergency recovery** procedures.
- **v1.1.0 API behavior notes** (important for scripts and
  integrations).

### 1.2 Design Principles

The upgrade system is built on:

| Principle | Implementation |
|---|---|
| **Zero data loss** | 5 user config files are automatically backed up and restored |
| **Idempotent** | Reinstalling the same version is safe |
| **Automatic** | No manual configuration after upgrade |
| **Reversible** | Emergency recovery supported |
| **No silent breaking changes** | v1.1.0 API additions are strictly additive |

### 1.3 Project Version History

| Version | Date | Type | Notes |
|---|---|:---:|---|
| v1.0.0 | 2026-09-24 | First stable | 33 audit corrections, 20 fixes, Level 4 infrastructure |
| **v1.1.0** | **2026-09-26** | **Polish** | **MEM-1/2/3, dynamic memory limit, profile_key + memory_limit_mb** |

**Next planned**:

- **v1.2.x** — CSP hardening (remove `'unsafe-inline'`),
  PWA port unification, dedicated maskable icon. See
  [`ROADMAP.md`](ROADMAP.md).
- **v2.0.0** — Major rewrite. See [`ROADMAP.md`](ROADMAP.md).

---

## 2. Settings Preservation

### 2.1 What Is Auto-Preserved?

The installer (`proxy/customize.sh`) automatically preserves **5 user config files** across upgrades:

| File | Purpose |
|---|---|
| `webui.conf` | WebUI + Dashboard ports, BIND_ADDR, LOG_LEVEL |
| `dnscrypt-proxy.toml` | DNSCrypt engine config + credentials |
| `selected_profile.txt` | Active blocklist profile |
| `allowlist.txt` | User-defined allowlist |
| `denylist.txt` | User-defined denylist |

**This behavior is identical in v1.0.0 and v1.1.0.** No change.

### 2.2 Additional Files

| File | Action | Note |
|---|---|---|
| `blocklist.raw` | 🔄 Downloaded | Re-fetched on profile update |
| `blocklist.txt` | 🔄 Rebuilt | Derived from `blocklist.raw` + rules |
| `blocked-ips.txt` | 🔄 Recreated | From defaults |
| `run/` directory | 🔄 Recreated | Runtime state only |
| Logs | 🔄 Rotated | Fresh log files |

### 2.3 How It Works

The installer runs these steps automatically:

1. **Backup phase** — before extraction:

   ```bash
   BACKUP_TMP="/data/local/tmp/dnscrypt-upgrade-backup-$$"
   mkdir -p "$BACKUP_TMP"
   for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
       [ -f "$_EXISTING_MODULE/proxy/$f" ] && cp -f "$_EXISTING_MODULE/proxy/$f" "$BACKUP_TMP/$f"
   done
   ```

2. **Extraction phase** — new files are extracted (overwriting defaults).

3. **Restore phase** — after extraction:

   ```bash
   for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
       [ -f "$BACKUP_TMP/$f" ] && cp -f "$BACKUP_TMP/$f" "$BIN_DIR/$f"
   done
   rm -rf "$BACKUP_TMP"
   ```

**Result**: Your settings survive the upgrade untouched.

### 2.4 Manual Backup (Recommended)

For extra safety, take a manual backup before upgrading:

```bash
# 1. Create a backup directory
su -c "mkdir -p /sdcard/dnscrypt-backup-$(date +%Y%m%d)"

# 2. Copy 5 config files
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/allowlist.txt /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/denylist.txt /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"

# 3. Verify
su -c "ls -la /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
```

**Recommended especially when upgrading from v1.0.0 to v1.1.0** — the memory profile is derived from `selected_profile.txt`, so preserving that file is critical for the memory limit to compute correctly.

### 2.5 Pre-Upgrade Checklist

- [ ] Available storage: `df -h /data` → > 50 MB free
- [ ] Battery: > 30%
- [ ] Internet: Working (for blocklist re-download)
- [ ] Manual backup (recommended)
- [ ] **v1.0.0 → v1.1.0**: note the current `selected_profile.txt`
      value (see §3.0)

---

## 3. Upgrade Procedure

### 3.0 Upgrading from v1.0.0 to v1.1.0

This is the **first in-place upgrade** since the project reached
its first stable release. It is **fully backward compatible**.

#### 3.0.1 What Changes

| Category | Change | Impact |
|---|---|---|
| **Memory limit** | Hardcoded 80 MB → per-profile dynamic | Improves `ultimate` performance |
| **`runtime_info`** | Two new fields: `profile_key`, `memory_limit_mb` | Additive |
| **`shellQuote`** | 20 chars → 24 chars | Internal only |
| **Metrics handler** | Uses `MONITORING_UI_PORT` constant | Internal only |
| **Uninstall** | No backup directory created anymore | Manual backup needed |
| **Documentation** | Updated across `docs/` | Read-only |
| **Scripts** | `customize.sh` prints memory hint | Cosmetic |

#### 3.0.2 What Does NOT Change

- ✅ **All API endpoints** — same paths, same methods, same auth.
- ✅ **Login POST-only** (from v1.0.0) — unchanged.
- ✅ **`/readyz` localhost-only** (from v1.0.0) — unchanged.
- ✅ **`hasEndpoint`** exact matching (from v1.0.0) — unchanged.
- ✅ **Custom Chains** (from v1.0.0) — unchanged.
- ✅ **Settings preservation** — 5 files preserved.
- ✅ **Firewall layout** — `DNSCRYPT_OUT` / `DNSCRYPT_OUT6`.
- ✅ **All v1.0.0 audit corrections** — still in place.
- ✅ **Config files** — no format changes.
- ✅ **Module version code formula** — unchanged.

#### 3.0.3 Step-by-Step

```bash
# 1. Note the current profile (for verification after upgrade)
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Example output: pro
# Remember this — the memory limit will be derived from it.

# 2. Take a manual backup (recommended)
su -c "mkdir -p /sdcard/dnscrypt-backup-$(date +%Y%m%d)"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/allowlist.txt /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/denylist.txt /sdcard/dnscrypt-backup-$(date +%Y%m%d)/"

# 3. Download the v1.1.0 ZIP
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.1.0/dnscrypt-webui-1.1.0-module.zip

# 4. Verify SHA-256
sha256sum -c dnscrypt-webui-1.1.0-module.zip.sha256
# Expected: OK

# 5. Install via Magisk Manager
#    Modules → Install from storage → select the ZIP
#    Watch the install screen — look for "Upgrade detected: YES"
#    and the "Memory limit" line (new in v1.1.0)

# 6. Reboot
su -c "reboot"

# 7. Wait ~60 seconds after boot
sleep 60

# 8. Verify the upgrade (see §4)
```

#### 3.0.4 What to Expect in the Install Log

The `customize.sh` output will now include a memory-limit line:

```text
  🧠 Memory limit: ~120 MB (profile: pro)   ← new in v1.1.0
```

This line is computed from the preserved `selected_profile.txt`. It
reflects the **soft limit** that `main.go` will apply at startup,
not the current RSS usage.

If you see a different value than expected (e.g. `80 MB` for
`pro`), the profile file was not preserved — see §2.4.

#### 3.0.5 The Memory Limit Transition

**Before the upgrade** (v1.0.0):

```go
// main.go, top of main():
debug.SetMemoryLimit(80 * 1024 * 1024)  // ← same for all profiles
```

**After the upgrade** (v1.1.0):

```go
// main.go, at startup:
initialProfile := readSelectedProfile()
applyMemoryLimit(initialProfile)
// → memoryLimitForProfile(profile) → debug.SetMemoryLimit(limit)
```

**What you will observe**:

| Profile | Before (v1.0.0) | After (v1.1.0) |
|---|---:|---:|
| light | 80 MB | 80 MB |
| normal | 80 MB | 100 MB |
| pro | 80 MB | 120 MB |
| proplus | 80 MB | 160 MB |
| ultimate | 80 MB | 220 MB |

The change is **internal** — no user action required. If your
device is on the `ultimate` profile, you may notice:

- ✅ **Lower CPU** during heavy DNS activity.
- ✅ **Faster WebUI response** (no GC thrashing).
- ⚠️ **Slightly higher RSS** (up to the new limit).
- ⚠️ **Slightly slower after a fresh boot** (one-time GC warmup).

These are expected and correct.

#### 3.0.6 Rolling Back to v1.0.0

If the new memory limit causes issues (rare), you can roll back:

```bash
# 1. Download the v1.0.0 ZIP
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.0.0/dnscrypt-webui-1.0.0-module.zip

# 2. Install over the current one from Magisk Manager
# 3. Reboot
su -c "reboot"

# 4. Verify rollback
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.0.0
```

**Rollback caveats**:

- ⚠️ Dynamic memory limit reverts to hardcoded 80 MB.
- ⚠️ `runtime_info` will no longer include `profile_key` /
  `memory_limit_mb`.
- ⚠️ System Info panels will not display profile / memory fields.
- ⚠️ `shellQuote` reverts to the 20-character set.
- ⚠️ `uninstall.sh` v1.0.0 will create a backup directory
  again (v1.1.0 behavior is reverted).

Your settings (5 files) remain preserved during rollback.

### 3.1 General Procedure (Future Versions)

When a new version is released in the future, follow these steps:

```bash
# 1. Download the new ZIP
#    From GitHub Releases:
#    https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest

# 2. Verify SHA-256 (recommended)
sha256sum -c dnscrypt-webui-<version>-module.zip.sha256

# 3. Install via Magisk Manager
#    Magisk Manager → Modules → Install from storage → select ZIP

# 4. Watch install messages:
#    ✅ Installation Complete
#    📊 Upgrade detected: YES (N files restored)
#    🌐 WebUI: http://127.0.0.1:9090
#    📈 Dashboard: http://127.0.0.1:9091
#    🧠 Memory limit: ~XXX MB (profile: <key>)   ← v1.1.0+

# 5. Reboot the device
su -c "reboot"

# 6. After boot (wait 60 seconds)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"
```

### 3.2 What Happens Behind the Scenes

`proxy/customize.sh` performs these steps:

1. Detects the current architecture (`getprop ro.product.cpu.abi`).
2. Detects the existing module (if any).
3. Kills old processes (`dnscrypt-proxy`, `dnscrypt-webui`).
4. Cleans firewall state (Custom Chains + legacy rules).
5. **Backs up 5 user config files** to `/data/local/tmp/dnscrypt-upgrade-backup-$$`.
6. Extracts the new ZIP.
7. Moves web assets to `web/`.
8. **Restores the 5 user config files** over the extracted defaults.
9. Verifies critical files.
10. Selects the correct binaries for the architecture.
11. Creates a secure `run/` directory (mode `0700`).
12. Writes `webui.conf` (with Port Guard — rejects port 8080).
13. Generates secure credentials (if missing).
14. Sets permissions.
15. Writes the module fingerprint.
16. **v1.1.0**: computes and prints the expected memory limit
    for the active profile (informational).

### 3.3 Installation Methods

#### Method A: Magisk Manager (Recommended)

1. Open **Magisk Manager**.
2. Go to **Modules** → **Install from storage**.
3. Select `dnscrypt-webui-<version>-module.zip`.
4. Confirm.
5. Reboot.

#### Method B: KernelSU Manager

1. Open **KernelSU Manager**.
2. Go to **Modules** → **Install**.
3. Select the ZIP.
4. Confirm.
5. Reboot.

#### Method C: APatch

1. Open **APatch**.
2. Go to **Modules** → **Install**.
3. Select the ZIP.
4. Confirm.
5. Reboot.

### 3.4 Common Messages

| Message | Meaning |
|---|---|
| `Upgrade detected: YES (5 files restored)` | Settings preserved ✅ |
| `Upgrade detected: NO` | Fresh installation |
| `PORT=8080 conflicts with [monitoring_ui], resetting to 9090` | Port Guard auto-fixed the port |
| `⚠️ Default admin/admin detected — generating secure credentials` | Credentials regenerated |
| `🛑 You MUST REBOOT NOW to restore DNS` | Old processes were killed |
| `🧠 Memory limit: ~XXX MB (profile: <key>)` | **v1.1.0** — computed soft limit |

---

## 4. Verification After Upgrade

### 4.1 Version Check

```bash
# Module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.1.0

# versionCode
su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: versionCode=1010000
```

### 4.2 Settings Preservation Check

```bash
# Ports and BIND_ADDR
su -c "grep -E '^(PORT|DASHBOARD_PORT|BIND_ADDR)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

# Credentials
su -c "grep -A2 '^\[monitoring_ui\]' /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml"

# Custom rules
su -c "wc -l /data/adb/modules/dnscrypt-proxy-webui/proxy/allowlist.txt"
su -c "wc -l /data/adb/modules/dnscrypt-proxy-webui/proxy/denylist.txt"
```

### 4.3 Service Status

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"
```

**Expected**:

- 🟢 DNS Engine: running on port 5354/UDP
- 🟢 WebUI: running on port 9090
- 🟢 Watchdog: running

**v1.1.0 addition**: A new "Profile & Memory" section:

```text
━━━ Profile & Memory ━━━
  Profile:       PRO
  Memory limit:  120 MB (pro)
  Managed by:    main.go (Go runtime soft limit)
```

### 4.4 Dashboard Check

```bash
# 1. Content-Type must be JSON
su -c "curl -sI http://127.0.0.1:9091/api/metrics | grep -i content-type"
# Expected: Content-Type: application/json; charset=utf-8

# 2. JSON must parse
su -c "curl -s http://127.0.0.1:9091/api/metrics" | jq '.total_queries'
# Expected: a number
```

Or open in browser: `http://127.0.0.1:9091`

### 4.5 Firewall Check

```bash
# No orphans in OUTPUT
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# Expected: 0

# Custom Chain exists
su -c "iptables -t nat -L DNSCRYPT_OUT -n"
# Expected: RETURN rules + DNAT

# IPv6 (if available)
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n"
```

### 4.6 Runtime Info Check (PORT-2 + MEM-1)

```bash
# Ports (PORT-2)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# v1.1.0 fields (MEM-1)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"
# Expected: {"profile_key": "<your profile>", "memory_limit_mb": <expected value>}
```

**Verify against the profile table**:

| `profile_key` | `memory_limit_mb` |
|:---:|:---:|
| `light` | 80 |
| `normal` | 100 |
| `pro` | 120 |
| `proplus` | 160 |
| `ultimate` | 220 |

**If the two values disagree** → see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §5.14.

### 4.7 Memory Limit Verification (v1.1.0)

```bash
# 1. Check the startup log line
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
# Expected: 🧠 v1.1.0: dynamic memory limit — profile=pro, limit=120 MB

# 2. Confirm the profile file matches
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Expected: pro (must match profile_key from §4.6)

# 3. Confirm no hardcoded 80 MB remains in the running binary
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui 2>/dev/null | grep -q 'memoryLimitForProfile' && echo '✅ MEM-1 present'"
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui 2>/dev/null | grep -q 'MEMORY_LIMIT_ULTIMATE' && echo '✅ constants present'"
```

### 4.8 Unified Verification Script

```bash
#!/system/bin/sh
# verify-upgrade.sh — comprehensive post-upgrade check (v1.1.0)

echo "=== Version ==="
grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop
grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop

echo ""
echo "=== Settings Preserved ==="
grep -E '^(PORT|DASHBOARD_PORT|BIND_ADDR)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf

echo ""
echo "=== Service Status ==="
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check

echo ""
echo "=== Dashboard JSON ==="
curl -s http://127.0.0.1:9091/api/metrics | head -3

echo ""
echo "=== Firewall (no orphans) ==="
iptables -t nat -L OUTPUT -n 2>/dev/null | grep -cE 'RETURN|DNAT'

echo ""
echo "=== Runtime Info (PORT-2 + MEM-1) ==="
curl -s http://127.0.0.1:9090/api?action=runtime_info | grep -E 'webui_port|dashboard_port|profile_key|memory_limit_mb'

echo ""
echo "=== Memory Limit (v1.1.0) ==="
grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1

echo ""
echo "✅ Verification complete"
```

Save this as `/sdcard/verify-upgrade.sh` and run:

```bash
su -c "sh /sdcard/verify-upgrade.sh"
```

---

## 5. API Behavior Notes (v1.1.0)

> **ℹ️ Important for scripts and integrations.**
>
> These are the **behaviors of v1.1.0**. They are unchanged from
> v1.0.0 except where noted. **No breaking changes.**

### 5.1 Login Is POST-Only

**Endpoint**: `POST /api/auth/login`

- ✅ POST → works
- ❌ GET / HEAD / PUT / DELETE → `405 Method Not Allowed` + `Allow: POST`

**Correct usage**:

```bash
curl -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"X"}' \
    -c /tmp/cookies.txt
```

**Reason**: Prevents CSRF + prevents credentials leaking in URLs.

**Reference**: [`SECURITY.md`](SECURITY.md) — Audit #28.

### 5.2 Logout Is POST-Only

**Endpoint**: `POST /api/auth/logout`

Same rules as login. Non-POST → `405`.

### 5.3 `/api/metrics` Returns JSON

**Endpoint**: `GET /api/metrics` (port 9091)

Response:

```json
{
  "generated_at": "2026-09-26T10:30:00Z",
  "total_queries": 15234,
  "blocked_queries": 1523,
  "cache_stats": {
    "enabled": true,
    "cache_hit_ratio": 0.82,
    "cache_hits": 12500,
    "cache_misses": 2734
  }
}
```

**Usage**:

```bash
curl -s http://127.0.0.1:9091/api/metrics | jq '.total_queries'
```

**To get raw Prometheus text** (bypass main.go):

```bash
curl -u "user:pass" http://127.0.0.1:8080/api/metrics
```

**v1.1.0 (MEM-3)**: The upstream URL used by `metricsProxyHandler`
is now built from the `MONITORING_UI_PORT` Go constant instead of
the hardcoded string `"8080"`. **Behavior is unchanged.**

### 5.4 `/readyz` Is Localhost-Only

**Endpoint**: `GET /readyz`

- ✅ From `127.0.0.1` or `[::1]` → `200` (or `503` if unhealthy)
- ❌ From LAN → `403 Forbidden` + `{"error": "readyz is localhost-only"}`

**For LAN health checks, use**:

```bash
curl http://192.168.1.5:9091/healthz
# → "ok"
```

**Difference**:

| Endpoint | Access | Info Exposed |
|---|:---:|---|
| `/healthz` | Public | `ok` |
| `/readyz` | localhost-only | System details |

### 5.5 Unknown Actions Return 404

**Endpoint**: `GET /api?action=<unknown>`

- ❌ Unknown action → `404 Not Found` + clear message
- ✅ Known action → `200 OK`

**Usage**:

```bash
status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:9090/api?action=unknown")
if [ "$status_code" = "404" ]; then
    echo "Endpoint not found"
fi
```

### 5.6 Basic Auth Rate Limiting

**Any endpoint using Basic Auth**:

- 5 failed attempts → 15-minute lockout (per IP)
- Successful attempt → resets counter
- IPv6-safe (`[::1]` handled correctly)

**Recommended for scripts**: Use Cookie auth instead.

```bash
# 1. Login
curl -c /tmp/cookies.txt -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"user","password":"pass"}'

# 2. Use cookie
curl -b /tmp/cookies.txt http://127.0.0.1:9090/api?action=status
```

### 5.7 Runtime Info Returns Actual Ports (PORT-2) + Memory (MEM-1)

**Endpoint**: `GET /api?action=runtime_info`

**v1.1.0 response**:

```json
{
  "version": "v1.1.0",
  "bind_addr": "127.0.0.1",
  "webui_port": "9090",
  "dashboard_port": "9091",
  "profile_key": "pro",
  "memory_limit_mb": 120,
  "run_dir": "...",
  "status_file": "..."
}
```

**Usage**:

```bash
# Get actual ports dynamically
WEBUI_PORT=$(curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.webui_port')
DASH_PORT=$(curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.dashboard_port')
```

**v1.1.0 additions (MEM-1)**:

| Field | Type | Description |
|---|---|---|
| `profile_key` | string | Active blocklist profile: `light` / `normal` / `pro` / `proplus` / `ultimate` |
| `memory_limit_mb` | int | Go runtime soft memory limit for the active profile |

**Why these fields exist**:

- **Observability** — for reporting issues.
- **Verification** — System Info panels display them.
- **Scriptability** — clients can adapt behavior based on the profile.

**Client compatibility**: All v1.0.0 clients continue to work —
the two fields are strictly additive. Clients that use a JSON
parser (not string indexing) are unaffected.

### 5.8 `get_profile` Includes `memory_limit_mb` (v1.1.0)

**Endpoint**: `GET /api?action=get_profile`

**v1.1.0 response**:

```json
{
  "key": "pro",
  "name": "HaGeZi PRO",
  "entries": 250000,
  "is_empty": false,
  "last_update": "2026-09-26 10:30:00",
  "memory_limit_mb": 120
}
```

**Additive change** — the field is new in v1.1.0. Clients ignoring
unknown fields are unaffected.

---

## 6. Emergency Recovery

### 6.1 If Installation Fails

```bash
# 1. Check storage
df -h /data

# 2. Check ZIP integrity
unzip -t /sdcard/dnscrypt-webui-1.1.0-module.zip

# 3. Check required tools
su -c "which unzip sed tr date grep head cut"
```

### 6.2 If the Device Bootloops

**Method A: From Recovery**

```bash
adb shell
mount /data
rm -rf /data/adb/modules/dnscrypt-proxy-webui
reboot
```

**Method B: From Safe Mode**

- Reboot into Safe Mode.
- Remove the module from Magisk Manager.

**Method C: Via ADB**

```bash
adb shell su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
adb reboot
```

### 6.3 If DNS Does Not Work After Install

```bash
# 1. Service status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"

# 2. Restart
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 3. Check Custom Chain
su -c "iptables -t nat -L DNSCRYPT_OUT -n"

# 4. Rebuild firewall
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 1"
```

**v1.1.0 addition** — if the WebUI is running but slow after
upgrade, check the memory profile:

```bash
# 1. Confirm the memory limit is correct
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"

# 2. Check the startup log
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"

# 3. If the profile is heavy (ultimate) and the device has < 4 GB RAM,
#    switch to a lighter one
su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §6.10 for the GC
thrashing diagnostic.

### 6.4 If Settings Are Missing

**Scenario**: The automatic restore did not run (rare).

```bash
# 1. Look for the automatic backup
ls -la /data/local/tmp/dnscrypt-upgrade-backup-*

# 2. Restore manually
BACKUP=$(ls -dt /data/local/tmp/dnscrypt-upgrade-backup-* 2>/dev/null | head -1)

su -c "cp $BACKUP/webui.conf /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $BACKUP/dnscrypt-proxy.toml /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $BACKUP/selected_profile.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $BACKUP/allowlist.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $BACKUP/denylist.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"

# 3. Restart
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Or from your manual backup**:

```bash
BACKUP=/sdcard/dnscrypt-backup-YYYYMMDD
su -c "cp $BACKUP/* /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**v1.1.0 note**: `selected_profile.txt` is critical — it drives the
memory limit. If missing, `main.go` falls back to `"pro"`.

### 6.5 Full Module Removal

**v1.1.0 change**: `uninstall.sh` no longer creates a backup
directory. Copy your settings manually before uninstalling if you
plan to reinstall (see §10.5 of [`INSTALL.md`](INSTALL.md)).

```bash
# 1. Remove the module files
su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"

# 2. Manual firewall cleanup (Custom Chains)
su -c "iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -F DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -X DNSCRYPT_OUT 2>/dev/null"

su -c "ip6tables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -F DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -X DNSCRYPT_OUT6 2>/dev/null"

# 3. Reset DNS settings
su -c "settings delete global private_dns_mode"
su -c "ndc resolver flushdefaultif"

# 4. Clean up legacy backup directory (v1.0.0 artifact, if any)
su -c "rm -rf /data/local/tmp/dnscrypt_backup_uninstall"

# 5. Reboot
su -c "reboot"
```

**Note**: The installer's `uninstall.sh` performs this automatically
when the module is removed via the Magisk app.

### 6.6 Recovery Checklist

| Situation | Action |
|---|---|
| Installation aborted | Check storage + ZIP integrity |
| Bootloop | Remove module from recovery |
| DNS not working | Restart service + check firewall |
| Settings missing | Restore from `/data/local/tmp/dnscrypt-upgrade-backup-*` |
| Dashboard broken | Check `curl 127.0.0.1:9091/api/metrics` |
| Login locked | Wait 15 min or restart WebUI |
| Firewall has orphans | Run `_legacy_cleanup_iptables` |
| **WebUI slow after upgrade (v1.1.0)** | **Check memory profile — §6.3** |
| **`profile_key` mismatch (v1.1.0)** | **Fix `selected_profile.txt` — §6.3** |

### 6.7 Backup Location Reference

| Location | Purpose | Retention |
|---|---|---|
| `/data/local/tmp/dnscrypt-upgrade-backup-*` | Auto-backup during upgrade | Deleted after successful restore |
| `/data/local/tmp/dnscrypt_backup_uninstall/` | Auto-backup during uninstall | **Not created in v1.1.0** (legacy from v1.0.0 removed) |
| `/sdcard/dnscrypt-backup-YYYYMMDD/` | Manual backup | User-managed |

**v1.1.0 reminder**: Since the uninstall-time auto-backup was
removed, take a manual backup (see §2.4) before uninstalling.

---

## 7. References

### 7.1 Related Documentation

| Document | Purpose |
|---|---|
| [`docs/INSTALL.md`](INSTALL.md) | Installation guide |
| [`docs/BRANCHING.md`](BRANCHING.md) | Git branching strategy |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Release process guide |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records |
| [`docs/API.md`](API.md) | Full HTTP API reference |
| [`docs/SECURITY.md`](SECURITY.md) | Security policy + Audit Corrections |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting guide |
| [`docs/FAQ.md`](FAQ.md) | Frequently asked questions |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | System architecture |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Device compatibility matrix |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries management (Level 4) |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Terms and abbreviations |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`docs/ROADMAP.md`](ROADMAP.md) | Future plans |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history |
| [`README.md`](../README.md) | Overview |

### 7.2 Project Files

| File | Purpose |
|---|---|
| `proxy/customize.sh` | Magisk installer (backup/restore + memory hint) |
| `proxy/service.sh` | Boot service launcher |
| `proxy/watchdog.sh` | Standalone watchdog process |
| `proxy/uninstall.sh` | Cleanup on removal (no backup in v1.1.0) |
| `proxy/functions.sh` | Shared shell library |
| `VERSION` | Single source of truth |
| `module.prop` | Magisk module definition |
| `update.json` | Auto-update metadata |

### 7.3 External References

- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [KernelSU Documentation](https://kernelsu.org/)
- [APatch](https://github.com/bmax121/APatch)
- [Cosign (Sigstore)](https://docs.sigstore.dev/cosign/overview/)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)

---

<div align="center">

**Last updated**: 2026-09-26
**Version**: v1.1.0
**Author**: gasciljh

**💡 Tip**: Take a backup before any major upgrade!

[⬆ Back to top](#upgrade-guide--dnscrypt-smart-filter)

</div>