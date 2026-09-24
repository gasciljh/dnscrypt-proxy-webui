# Upgrade Guide — DNSCrypt Smart Filter

> Comprehensive guide for upgrading between DNSCrypt Smart Filter versions.

**Current version**: v1.0.0
**Last updated**: 2026-09-24
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **📖 Related documents**:
> - Git workflow → [`docs/BRANCHING.md`](BRANCHING.md)
> - Release process → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decisions → [`docs/adr/README.md`](adr/README.md)
> - Installation guide → [`docs/INSTALL.md`](INSTALL.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Settings Preservation](#2-settings-preservation)
3. [Upgrade Procedure](#3-upgrade-procedure)
4. [Verification After Upgrade](#4-verification-after-upgrade)
5. [API Behavior Notes (v1.0.0)](#5-api-behavior-notes-v100)
6. [Emergency Recovery](#6-emergency-recovery)
7. [References](#7-references)

---

## 1. Overview

### 1.1 First Release

**v1.0.0 is the first stable release** of DNSCrypt Smart Filter.

There are **no previous versions** to upgrade from. This guide covers:

- The **settings preservation mechanism** that applies to all future upgrades.
- The **general upgrade procedure** for future versions.
- **Emergency recovery** procedures.
- **v1.0.0 API behavior notes** (important for scripts and integrations).

### 1.2 Design Principles

The upgrade system is built on:

| Principle | Implementation |
|---|---|
| **Zero data loss** | 5 user config files are automatically backed up and restored |
| **Idempotent** | Reinstalling the same version is safe |
| **Automatic** | No manual configuration after upgrade |
| **Reversible** | Emergency recovery supported |

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

### 2.5 Pre-Upgrade Checklist

- [ ] Available storage: `df -h /data` → > 50 MB free
- [ ] Battery: > 30%
- [ ] Internet: Working (for blocklist re-download)
- [ ] Manual backup (recommended)

---

## 3. Upgrade Procedure

### 3.1 General Procedure (Future Versions)

When a new version is released, follow these steps:

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

---

## 4. Verification After Upgrade

### 4.1 Version Check

```bash
# Module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"

# versionCode
su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# v1.0.0 → 1000000
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

### 4.6 Runtime Info Check (PORT-2)

```bash
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}
```

### 4.7 Unified Verification Script

```bash
#!/system/bin/sh
# verify.sh — Comprehensive post-upgrade check

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
echo "=== Runtime Info (PORT-2) ==="
curl -s http://127.0.0.1:9090/api?action=runtime_info | grep -E 'webui_port|dashboard_port'

echo ""
echo "✅ Verification complete"
```

Save this as `/sdcard/verify-upgrade.sh` and run:

```bash
su -c "sh /sdcard/verify-upgrade.sh"
```

---

## 5. API Behavior Notes (v1.0.0)

> **ℹ️ Important for scripts and integrations.**
>
> These are the **behaviors of v1.0.0**. They differ from what a generic
> REST API might expect. Know them before writing clients.

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

**Reference**: `docs/SECURITY.md` — Audit #28.

### 5.2 Logout Is POST-Only

**Endpoint**: `POST /api/auth/logout`

Same rules as login. Non-POST → `405`.

### 5.3 `/api/metrics` Returns JSON

**Endpoint**: `GET /api/metrics` (port 9091)

Response:

```json
{
  "generated_at": "2026-09-24T10:30:00Z",
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

### 5.7 Runtime Info Returns Actual Ports (PORT-2)

**Endpoint**: `GET /api?action=runtime_info`

Returns:

```json
{
  "version": "v1.0.0",
  "bind_addr": "127.0.0.1",
  "webui_port": "9090",
  "dashboard_port": "9091",
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

---

## 6. Emergency Recovery

### 6.1 If Installation Fails

```bash
# 1. Check storage
df -h /data

# 2. Check ZIP integrity
unzip -t /sdcard/dnscrypt-webui-<version>-module.zip

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

### 6.5 Full Module Removal

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

# 4. Reboot
su -c "reboot"
```

**Note**: The installer's `uninstall.sh` performs this automatically when the module is removed via the Magisk app.

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

### 6.7 Backup Location Reference

| Location | Purpose | Retention |
|---|---|---|
| `/data/local/tmp/dnscrypt-upgrade-backup-*` | Auto-backup during upgrade | Deleted after successful restore |
| `/data/local/tmp/dnscrypt_backup_uninstall/` | Auto-backup during uninstall | Preserved (unless `--delete-backup`) |
| `/sdcard/dnscrypt-backup-YYYYMMDD/` | Manual backup | User-managed |

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
| `proxy/customize.sh` | Magisk installer (backup/restore) |
| `proxy/service.sh` | Boot service launcher |
| `proxy/watchdog.sh` | Standalone watchdog process |
| `proxy/uninstall.sh` | Cleanup on removal |
| `proxy/functions.sh` | Shared shell library |
| `VERSION` | Single source of truth |
| `module.prop` | Magisk module definition |
| `update.json` | Auto-update metadata |

### 7.3 External References

- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [KernelSU Documentation](https://kernelsu.org/)
- [APatch](https://github.com/bmax121/APatch)
- [Cosign (Sigstore)](https://docs.sigstore.dev/cosign/overview/)

---

<div align="center">

**Last updated**: 2026-09-24
**Version**: v1.0.0
**Author**: gasciljh

**💡 Tip**: Take a backup before any major upgrade!

[⬆ Back to top](#upgrade-guide--dnscrypt-smart-filter)

</div>
