# Installation Guide — DNSCrypt Smart Filter

> Detailed step-by-step installation guide.

**Version**: v1.0.0
**Last updated**: 2026-09-24
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

---

## Table of Contents

1. [Requirements](#1-requirements)
2. [Verifying Requirements](#2-verifying-requirements)
3. [Download](#3-download)
4. [Installation via Magisk](#4-installation-via-magisk)
5. [Installation via KernelSU](#5-installation-via-kernelsu)
6. [Installation via APatch](#6-installation-via-apatch)
7. [Verifying Installation](#7-verifying-installation)
8. [Initial Setup](#8-initial-setup)
9. [Updating](#9-updating)
10. [Uninstalling](#10-uninstalling)
11. [Quick Reference](#11-quick-reference)
12. [v1.0.0 Specific Notes](#12-v100-specific-notes)
13. [Unified Verification Script](#13-unified-verification-script)
14. [References](#14-references)

---

## 1. Requirements

### 1.1 Mandatory

| Requirement | Minimum |
|---------|-------------|
| **Android** | 5.0 (API 21) |
| **Root** | Magisk 20.4+ or KernelSU 0.9+ or APatch |
| **Kernel** | 3.10+ |
| **RAM** | 1 GB |
| **Storage** | 20 MB free |
| **Architecture** | arm64 / arm / x86_64 / x86 |

### 1.2 Recommended

| Requirement | Recommended |
|---------|-----------|
| **Android** | 10+ (API 29) |
| **Root** | Magisk 26+ |
| **Kernel** | 4.14+ |
| **RAM** | 2 GB+ |

### 1.3 Does Not Work With

- ❌ SuperSU (legacy)
- ❌ KingRoot (untrusted)
- ❌ Android 4.x or older
- ❌ Very old Kernel 3.10 (limited fallback)
- ⚠️ VPN apps (conflict at the `redirect` level)
- ⚠️ AdAway (uses the same DNS redirect port)

---

## 2. Verifying Requirements

### 2.1 Root

```bash
# Open Terminal (Termux / Material Terminal / ADB)
su -c "id"
# → uid=0(root) gid=0(root)
```

### 2.2 Android Version

```bash
getprop ro.build.version.release
# → 14

getprop ro.build.version.sdk
# → 34
```

### 2.3 Architecture

```bash
getprop ro.product.cpu.abi
# → arm64-v8a
```

### 2.4 Kernel

```bash
uname -r
# → 5.15.94-android13-...
```

### 2.5 Magisk / KernelSU / APatch

```bash
# Magisk
su -c "magisk -V"
# → 27.0  (or any version ≥ 20.4)

# KernelSU
su -c "ksud -V"
# → KernelSU version: 0.9.x  (or any version ≥ 0.9.0)

# APatch
su -c "apd -V" 2>/dev/null || su -c "apd --version"
# → APatch version: ...
```

### 2.6 Storage

```bash
df -h /data
# → Avail: 45G  (must be ≥ 20 MB)
```

### 2.7 Architecture Support

| Arch (ABI) | Supported Binary |
|------|----------------|
| `arm64-v8a` | `dnscrypt-webui-arm64` |
| `armeabi-v7a` | `dnscrypt-webui-arm` |
| `x86_64` | `dnscrypt-webui-amd64` |
| `x86` | `dnscrypt-webui-386` |

---

## 3. Download

### 3.1 From GitHub Releases

```bash
# Latest release
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.0.0-module.zip

# Or
curl -L -o dnscrypt-webui-1.0.0-module.zip \
    https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.0.0-module.zip
```

### 3.2 Verify SHA-256

```bash
# Download checksum
curl -L -O https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/module.zip.sha256

# Verify
sha256sum -c module.zip.sha256
# → dnscrypt-webui-1.0.0-module.zip: OK
```

### 3.3 Verify Signature (optional, recommended)

```bash
# Download signature + certificate
curl -L -O https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.0.0-module.zip.sig
curl -L -O https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.0.0-module.zip.pem

# Verify (Cosign keyless)
cosign verify-blob \
    --signature dnscrypt-webui-1.0.0-module.zip.sig \
    --certificate dnscrypt-webui-1.0.0-module.zip.pem \
    --certificate-identity-regexp "https://github.com/gasciljh/dnscrypt-proxy-webui/.*" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    dnscrypt-webui-1.0.0-module.zip
```

**Expected**:
```text
Verified OK
```

### 3.4 Transfer to Device

```bash
# Via ADB
adb push dnscrypt-webui-1.0.0-module.zip /sdcard/Download/

# Or copy manually
```

---

## 4. Installation via Magisk

### 4.1 From Magisk Manager

1. Open **Magisk Manager**.
2. Go to **Modules**.
3. Press **Install from storage**.
4. Choose `dnscrypt-webui-1.0.0-module.zip`.
5. Press **OK** to confirm.

### 4.2 From TWRP (alternative)

```bash
# In TWRP
adb push dnscrypt-webui-1.0.0-module.zip /sdcard/
# Then from TWRP: Install → choose the ZIP
```

### 4.3 What Happens During Installation

The steps inside `customize.sh`:

1. `customize.sh` starts.
2. Detects the architecture (e.g. `arm64-v8a`).
3. **Upgrade check** — detects the old module (if present).
4. **Stop old processes** (`pkill dnscrypt-proxy`, `dnscrypt-webui`).
5. **Firewall cleanup** (Custom Chains + Legacy).
6. **Backup user settings** (before extraction):
   - `webui.conf`
   - `dnscrypt-proxy.toml`
   - `selected_profile.txt`
   - `allowlist.txt`
   - `denylist.txt`
   - Path: `/data/local/tmp/dnscrypt-upgrade-backup-$$`.
7. **Extract module files** (`unzip -o`).
8. Move web files (HTML/JSON/SVG/PNG/ICO) to `web/`.
9. **Restore user settings** (after extraction):
   - Copy saved files over `defaults`.
   - Delete the backup directory.
10. Verify critical files.
11. Select the correct binaries for the architecture.
12. Create `run/` directory with `0700` permissions.
13. Write `webui.conf` (with **Port Guard** to reject 8080).
14. Generate **secure credentials** (username + password).
15. Set permissions.
16. Write the module fingerprint.

### 4.4 Successful Installation Screen

**Expected in Magisk**:
```text
╔══════════════════════════════════════════╗
║  🛡️  DNSCrypt Smart Filter              ║
║      v1.0.0                               ║
║      Professional Edition                 ║
╚══════════════════════════════════════════╝

- Architecture: arm64-v8a
- Upgrade detected, cleaning old instances...
  → Killed 3 old process(es)
  → Firewall rules cleaned (Custom Chain + Legacy)
  ✅ Old instances cleaned
  → Backed up 5 user config file(s)
- Extracting module files...
  ✅ Files extracted
- Restoring user configuration...
  ✅ Restored 5 user config file(s)
- Target binaries: dnscrypt-proxy-arm64 + dnscrypt-webui-arm64
- Creating secure run/ directory...
  ✅ run/ directory created (0700)
  ✅ Migrated status files

- Generating secure credentials...

╔══════════════════════════════════════════╗
║  🔐 Login Credentials Generated          ║
╚══════════════════════════════════════════╝
  👤 Username: admin_xxxxxxxx
  🔑 Password: XXXXXXXXXXXXXXXXXXXXXXXX

📌 Keep these credentials to log in
📄 Saved copy: /data/local/tmp/dnscrypt_credentials.txt

╔══════════════════════════════════════════╗
║  ✅ Installation Complete                ║
║      v1.0.0                               ║
╚══════════════════════════════════════════╝

  📊 Upgrade detected: YES (5 files restored)
  🌐 WebUI: http://127.0.0.1:9090
  📈 Dashboard: http://127.0.0.1:9091
  🔌 Bind: 127.0.0.1

  ℹ️  Next steps:
    1. Reboot your device
    2. Open the WebUI and login with the credentials above
    3. Choose a blocklist profile and press Apply
```

⚠️ **Important**: Copy the credentials — you will need them in **Step 8**.

### 4.5 Possible Warnings During Installation

**Warning 1 — Port Guard**:
If an old `webui.conf` contains `PORT=8080`:
```text
⚠️ PORT=8080 conflicts with [monitoring_ui], resetting to 9090
```
This is expected — `customize.sh` detects the conflict and replaces it automatically.

**Warning 2 — Settings restoration**:
On upgrade:
```text
📊 Upgrade detected: YES
  → Backed up 5 user config file(s)
  → Restored 5 user config file(s)
```
This is correct behavior — your settings are preserved.

**Warning 3 — Restoration failure (rare)**:
```text
⚠️ Failed to create backup dir (continuing with defaults)
```
See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) for the solution.

**Warning 4 — Mandatory reboot**:
If `KILLED_COUNT > 0`, a warning is shown:
```text
⚠️  IMPORTANT — READ CAREFULLY
The DNS Engine has been STOPPED to allow
a clean upgrade. Internet may not work
correctly until you REBOOT your device.
🛑 You MUST REBOOT NOW to restore DNS.
```

---

## 5. Installation via KernelSU

### 5.1 From KernelSU Manager

1. Open **KernelSU Manager**.
2. Go to **Modules**.
3. Press **Install**.
4. Choose `dnscrypt-webui-1.0.0-module.zip`.
5. Press **Install**.

### 5.2 Difference from Magisk

- KernelSU uses the same `customize.sh`.
- Everything else is identical.
- `MODPATH = /data/adb/modules/dnscrypt-proxy-webui`.

---

## 6. Installation via APatch

### 6.1 From APatch Manager

1. Open **APatch**.
2. Go to **Modules**.
3. Press **Install**.
4. Choose the ZIP file.
5. Press **Confirm**.

### 6.2 Difference from Magisk

- APatch supports the same Magisk structure.
- The `magisk` executable is not present (uses `apd`) but the scripts are fully compatible.

---

## 7. Verifying Installation

### 7.1 After Reboot

⚠️ **Important**: Reboot the device after installation.

```bash
# After boot (wait 30-60 seconds)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"
```

**Expected**:
```text
╔══════════════════════════════════════════════════════════╗
║  🛡️  DNSCrypt Smart Filter v1.0.0
║      ✅ ACTIVE
╚══════════════════════════════════════════════════════════╝

━━━ 🖥️  Service Status ━━━
  🟢 DNS Engine:   running on port 5354/UDP
  🟢 WebUI:        running on port 9090
  🟢 Watchdog:     running (PID: 12345)

━━━ 🌐 Links ━━━
  WebUI:     http://127.0.0.1:9090
  Dashboard: http://127.0.0.1:9091
  ...
```

### 7.2 Verify the WebUI

```bash
# Liveness
su -c "curl -s http://127.0.0.1:9090/healthz"
# → ok

# Readiness (localhost-only — v1.0.0 Fix NEW-4)
su -c "curl -s http://127.0.0.1:9090/readyz"
# → {"blocklist":"ok","config":"ok","run_dir":"ok","status":"ready","version":"v1.0.0"}
```

⚠️ **Note**: `version` must be `v1.0.0`.

⚠️ **From LAN (after BIND_ADDR=0.0.0.0)**:
```bash
curl -i http://192.168.1.5:9091/readyz
# → 403 Forbidden
# {"error": "readyz is localhost-only"}
```
This is intentional (Fix NEW-4). Use `/healthz` instead.

### 7.3 Verify DNS

```bash
# Test the query
su -c "nslookup google.com 127.0.0.1"

# Or dig
su -c "dig @127.0.0.1 google.com +short"
```

### 7.4 Verify iptables (Custom Chains)

**Check `OUTPUT` (must be clean)**:
```bash
su -c "iptables -t nat -L OUTPUT -n -v | grep DNSCRYPT_OUT"
```
**Expected** (only two rules — note `DNSCRYPT_OUT` specified):
```text
DNSCRYPT_OUT  udp  --  0.0.0.0/0  0.0.0.0/0  udp dpt:53
DNSCRYPT_OUT  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:53
```

⚠️ **Note**: `OUTPUT` must contain only jump rules. No direct `DNAT` or `RETURN`.

**Check `DNSCRYPT_OUT`**:
```bash
su -c "iptables -t nat -L DNSCRYPT_OUT -n -v"
```

**Expected** (depends on `bootstrap_resolvers` in `dnscrypt-proxy.toml`):
```text
Chain DNSCRYPT_OUT (2 references)
 1  RETURN  all  --  0.0.0.0/0  127.0.0.1
 2  RETURN  all  --  0.0.0.0/0  9.9.9.9
 3  RETURN  all  --  0.0.0.0/0  8.8.8.8
 4  RETURN  all  --  0.0.0.0/0  1.1.1.1
 5  RETURN  all  --  0.0.0.0/0  1.0.0.1
 6  DNAT    all  --  0.0.0.0/0  0.0.0.0/0  to:127.0.0.1:5354
```

⚠️ **Number of RETURN rules** = `1 (loopback) + number of bootstrap_resolvers`.

**Check IPv6 (if available)**:
```bash
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n"
```

### 7.5 Verify STATUS_FILE

```bash
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"
```

**Expected**: `ON` (if the service is running).

**Meaning of STATUS_FILE**:
- `ON` = "User wants the service running" (user intent).
- `OFF` = "User stopped the service" (user intent).

⚠️ **v1.0.0 — Fix A**: Not written by read-only functions — written only by `startService` / `stopService`.

⚠️ **v1.0.0 — Fix #2**: `getSystemShell()` uses `sync.Once` — cached once (no repeated overhead).

### 7.6 Verify No Orphans

```bash
# Number of direct DNAT/RETURN rules in OUTPUT (outside DNSCRYPT_OUT)
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
```
**Expected**: `0` (no orphans).

If you see a number > 0 → see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

### 7.7 Verify Dashboard (v1.0.0)

```bash
# 1. Correct Content-Type
su -c "curl -sI http://127.0.0.1:9091/api/metrics | grep -i content-type"
# Expected: Content-Type: application/json; charset=utf-8

# 2. JSON works
su -c "curl -s http://127.0.0.1:9091/api/metrics" | head -5
# Expected: { "generated_at": ..., "total_queries": ..., ... }

# 3. Open Dashboard in browser
# http://127.0.0.1:9091
# You should see statistics (total_queries, blocked_queries, cache_stats)
```

⚠️ **If tables are empty** → see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

**Before v1.0.0**: `/api/metrics` returned Prometheus text with `Content-Type: application/json` → `JSON.parse()` failed → Dashboard broken.

⚠️ **Breaking change (Fix #12)**: `GET /api?action=unknown` now returns `404` (instead of 200).

### 7.8 Verify Preserved Settings (after upgrade)

```bash
# 1. webui.conf
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf" | grep -E '^(PORT|DASHBOARD_PORT|BIND_ADDR|LOG_LEVEL)='
# Expected: your custom values (not defaults)

# 2. allowlist.txt + denylist.txt
su -c "wc -l /data/adb/modules/dnscrypt-proxy-webui/proxy/allowlist.txt"
su -c "wc -l /data/adb/modules/dnscrypt-proxy-webui/proxy/denylist.txt"
# Expected: same number as before upgrade

# 3. backup directory (if upgrade was successful — it is auto-deleted)
su -c "ls -la /data/local/tmp/dnscrypt-upgrade-backup-* 2>/dev/null"
# Expected: (none — deleted after successful restore)
# Note: if present, see TROUBLESHOOTING.md
```

### 7.9 Verify Basic Auth Rate Limit (optional)

```bash
# 5 failed attempts
for i in {1..6}; do
  curl -u "wrong:wrong" -o /dev/null -w "%{http_code}\n" \
    http://127.0.0.1:9090/api?action=status
done
# Expected: 401, 401, 401, 401, 401, 401 (locked at 6)
```

⚠️ **Warning**: This will lock IP `127.0.0.1` for **15 minutes**. For testing only.

**Immediate reset**: Restart the WebUI:
```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 7.10 Verify Runtime Info (PORT-2)

```bash
# 1. runtime_info returns ports
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# 2. From LAN (with BIND_ADDR=0.0.0.0)
curl -s http://192.168.1.5:9090/api?action=runtime_info | jq '.bind_addr'
# Expected: "0.0.0.0"
```

### 7.11 Verify Login POST-only

```bash
# 1. GET must fail
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: 405 Method Not Allowed + Allow: POST

# 2. POST must succeed
curl -i -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"..."}'
# Expected: 200 + Set-Cookie
```

---

## 8. Initial Setup

### 8.1 Open the WebUI

- **From Magisk**: Modules → DNSCrypt → **Action**.
- **Manually**: Open the browser at `http://127.0.0.1:9090`.

### 8.2 Login

Use the credentials generated in **Step 4.4**:
```text
👤 Username: admin_xxxxxxxx
🔑 Password: XXXXXXXXXXXXXXXXXXXXXXXX
```

⚠️ **v1.0.0**: Login is **POST-only** — if you use a script, use POST (see [`API.md`](API.md)).

### 8.3 Choose a List

1. In **📝 Select Blocklist**, choose:
   - ☀️ **Light** (40K entries) — recommended for beginners
   - 🧹 **Normal** (120K) — balanced
   - 🛡️ **PRO** (250K) — recommended (default)
   - ⚡ **PRO++** (350K)
   - 🔥 **Ultimate** (500K) — for powerful devices
2. Press **Apply**.
3. Wait (30s - 5 min depending on the list).

### 8.4 Configure Custom Rules (optional)

**Allowlist (exceptions)**:
```text
googleadservices.com
s.youtube.com
*.whatsapp.net
```

**Denylist (additional blocking)**:
```text
facebook.com
tiktok.com
```

### 8.5 Install PWA (optional)

1. Open Chrome on the phone.
2. Go to `http://127.0.0.1:9090`.
3. From the **Menu** → **Install app** or **Add to Home screen**.
4. A DNSCrypt icon will appear on the Home Screen.

### 8.6 Open the Dashboard (optional)

- **From WebUI**: Press **📊 Dashboard** (green badge).
- **Manually**: Open the browser at `http://127.0.0.1:9091`.

You will see:
- Total queries.
- Blocked queries.
- Cache hit ratio.
- Resolver health.
- Top queried domains.

**To enable `recent_queries` + `top_domains`**:
Edit `dnscrypt-proxy.toml`:
```toml
[monitoring_ui]
  enabled = true
  enable_query_log = true
  privacy_level = 1
```
Then:
```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 8.7 Test DNS

Open `https://www.dnsleaktest.com` — you should see:
- ✅ Cloudflare or Quad9 (or your chosen server, not your ISP).

---

## 9. Updating

### 9.1 Auto-update (Magisk)

1. **Magisk Manager** → **Settings** → ✅ Update channel: **Custom**.
2. In `module.prop` the path should be:
   ```text
   updateJson=https://raw.githubusercontent.com/gasciljh/dnscrypt-proxy-webui/main/update.json
   ```
3. Magisk will check for updates automatically and show notifications.

### 9.2 Manually

```bash
# 1. Download the new ZIP
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-X.Y.Z-module.zip

# 2. Install over the old one (from Magisk directly)
# 3. Reboot
```

### 9.3 What Happens During Update

**v1.0.0**:
- `customize.sh` **backs up** 5 settings files.
- Extracts the new ZIP (with `unzip -o`).
- **Restores** the saved files over defaults.
- **Result**: Your settings are 100% preserved.

**Preserved files (5)**:

| File | Purpose |
|---|---|
| `webui.conf` | WebUI/Dashboard settings |
| `dnscrypt-proxy.toml` | DNSCrypt settings + credentials |
| `selected_profile.txt` | Active profile |
| `allowlist.txt` | Custom rules |
| `denylist.txt` | Custom rules |

**⚠️ Security note**:
- Backup directory: `/data/local/tmp/dnscrypt-upgrade-backup-$$`.
- Permissions: `0700` by default (root only).
- Deleted **automatically** after a successful restore.
- If restore fails → see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

### 9.4 After Update

- Reboot is required if the service was stopped.
- Check `CHANGELOG.md` for changes.
- Verify with `status.sh`.
- Verify Custom Chains:
  ```bash
  su -c "iptables -t nat -L DNSCRYPT_OUT -n"
  su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
  # → 0 (no orphans)
  ```
- **Verify Dashboard**:
  ```bash
  su -c "curl -s http://127.0.0.1:9091/api/metrics | jq '.total_queries'"
  ```
- **Verify Settings**:
  ```bash
  su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
  # → PORT=9090 (or your custom value)
  ```
- **Verify PORT-2**:
  ```bash
  su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
  # → {"webui_port": "9090", "dashboard_port": "9091"}
  ```

### 9.5 Upgrading from an older version

1. **install**:
   - `customize.sh` detects the old module.
   - Kills processes.
   - Runs `_inline_cleanup_firewall`.
   - **backup** of 5 files.
   - Extracts the new files.
   - **restore** of the saved files.
2. **reboot**:
   - `service.sh` starts the WebUI.
   - On the first `startService()`:
     - `DNSCRYPT_OUT` is created.
     - `DNSCRYPT_OUT6` is created (if IPv6 is available).
     - `STATUS_FILE` = "ON".
3. **Verify**:
   ```bash
   # No orphans
   su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
   # → 0

   # Custom Chains exist
   su -c "iptables -t nat -L DNSCRYPT_OUT -n"

   # STATUS_FILE = user intent
   su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"

   # Dashboard works
   su -c "curl -s http://127.0.0.1:9091/api/metrics | jq '.total_queries'"
   # → number (instead of parse error)

   # Settings preserved
   su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
   ```

**No manual action required** — everything is automatic.

### 9.6 Upgrading from a very old version

⚠️ **Warning**: Upgrading from a very old version may lose some settings (because backup/restore was added only in v1.0.0).

**Recommended procedure**:

1. **Before installation**: Take a manual backup:
   ```bash
   su -c "mkdir -p /sdcard/dnscrypt-backup-manual"
   su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/*.txt /sdcard/dnscrypt-backup-manual/"
   su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf /sdcard/dnscrypt-backup-manual/"
   su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml /sdcard/dnscrypt-backup-manual/"
   ```
2. **Install the new ZIP**.
3. **Reboot**.
4. **Verify and restore manually if needed**:
   ```bash
   su -c "cp /sdcard/dnscrypt-backup-manual/webui.conf /data/adb/modules/dnscrypt-proxy-webui/proxy/"
   su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
   ```

**See** [`UPGRADE.md`](UPGRADE.md) for details of each upgrade.

### 9.7 Verify versionCode

```bash
su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: 1000000 (v1.0.0)
```

**Formula**:
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

---

## 10. Uninstalling

### 10.1 From Magisk

1. **Magisk Manager** → **Modules**.
2. Press 🗑️ (remove) next to **DNSCrypt Smart Filter**.
3. Reboot the device (**Reboot**).

### 10.2 From KernelSU

1. **KernelSU Manager** → **Modules**.
2. Press **Uninstall** next to the module.
3. Reboot the device (**Reboot**).

### 10.3 What Happens

During removal, `uninstall.sh` runs:

1. **Save backup** to `/data/local/tmp/dnscrypt_backup_uninstall/`:
   - Settings files (8 files).
   - credentials.
   - `module.prop`.
   - Status file.
   - `RESTORE.txt`.
2. **Stop all processes** (`pkill -9`).
3. **Full firewall cleanup** (`-D` + `-F` + `-X`).
4. **Legacy cleanup** (best-effort).
5. **Reset DNS settings** to normal (**AUTO**).
6. **Restore `route_localnet`** to its original state (instead of forcing 0).
7. **Delete runtime files** in `/data/local/tmp/`.
8. **Delete module settings** (blocklist, allowlist, denylist, ...).

### 10.4 Manual Removal (if normal uninstall fails)

```bash
su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
su -c "rm -rf /data/local/tmp/dnscrypt*"

# Delete Custom Chains (IPv4)
su -c "iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -F DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -X DNSCRYPT_OUT 2>/dev/null"

# Delete Custom Chains (IPv6)
su -c "ip6tables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -F DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -X DNSCRYPT_OUT6 2>/dev/null"

# Reset DNS
su -c "settings delete global private_dns_mode"
su -c "ndc resolver flushdefaultif 2>/dev/null"

# Reboot
```

### 10.5 Recovering Settings

```bash
# Backup is saved in:
su -c "ls /data/local/tmp/dnscrypt_backup_uninstall/"

# To restore:
# 1. Reinstall the module normally
# 2. Copy the old files to proxy/
su -c "cp /data/local/tmp/dnscrypt_backup_uninstall/*.conf /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /data/local/tmp/dnscrypt_backup_uninstall/*.toml /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /data/local/tmp/dnscrypt_backup_uninstall/*.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 10.6 Verify Firewall Cleanliness After Removal

```bash
# Must be 0 (no orphans)
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT|DNSCRYPT'"
# → 0

# Must be 0 (chain deleted)
su -c "iptables -t nat -L DNSCRYPT_OUT -n 2>&1 | grep -c 'No chain'"
# → 1 (i.e. No chain/target/match by that name)
```

If there are orphans → see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

### 10.7 Verify Backup Files

```bash
su -c "cat /data/local/tmp/dnscrypt_backup_uninstall/RESTORE.txt"
```

Contains:
- Creation date.
- Version.
- File list.
- Restore instructions.

---

## 11. Quick Reference

| Step | Time | Note |
|---|---|---|
| Download | 30s | ~30 MB |
| Verify (SHA-256) | 5s | — |
| Verify (Cosign) | 15s | Optional |
| Install | 15s | Via Magisk |
| Reboot | 60s | Mandatory |
| Initial setup | 5 min | With list download |
| **Total** | **~7 minutes** | — |

---

## 12. v1.0.0 Specific Notes

### 12.1 First-Time Installation

1. **Port Guard**: If `webui.conf` exists with `PORT=8080` → automatically replaced with `9090`.
2. **Credentials**: Generated by `customize.sh`. Save them.
3. **Firewall**: Starts empty (no Custom Chains). Created on first run.
4. **Dashboard**: Works immediately (JSON metrics).

### 12.2 On Upgrade

1. **Auto backup/restore**: 5 files preserved.
2. **Orphan cleanup**: Automatic from `customize.sh` (legacy best-effort).
3. **Custom Chains**: Recreated on first `startService()`.
4. **STATUS_FILE**: Read from the old file if present.

### 12.3 On Uninstall

1. **Full cleanup**: `_inline_cleanup_firewall` + `_legacy_cleanup_*`.
2. **Backup**: Saved to `/data/local/tmp/dnscrypt_backup_uninstall/`.
3. **DNS reset**: `settings delete global private_dns_mode`.

### 12.4 Key Changes in v1.0.0

| Feature | Impact on Installation |
|---|---|
| **Dashboard JSON** (Fix #1) | Works immediately |
| **getSystemShell** (Fix #2) | No impact on Android |
| **Preserve settings** (Fix #3) | Automatic backup/restore |
| **Login POST-only** (NEW-1) | Make sure to use POST |
| **`/readyz` localhost** (NEW-4) | No LAN access |
| **`hasEndpoint`** (Fix #12) | Stricter endpoints |
| **`readConfPort`** (NEW-3) | Rejects invalid port values |
| **`rebuildMu`** (RACE-1) | Safe BLOCKLIST |
| **`runtime_info` ports** (PORT-2) | Dynamic links |
| **Auth cache** (NEW-6) | Credentials change after 60s |
| **`shellQuote`** (NEW-5) | No impact on user |
| **Basic Auth rate limit** (Fix #8) | May lock after 5 attempts |
| **404 for unknown action** (Fix #12) | Scripts may need update |
| **Section header with comment** (Fix #10) | `[monitoring_ui] # comment` supported now |
| **Per-port cache** (Fix #11) | Correct cache per port |

### 12.5 Verify the Version

```bash
# Method 1: module.prop
su -c "grep -E '^(version|versionCode)=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"

# Method 2: runtime_info
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | grep version"

# Method 3: WebUI
# Open http://127.0.0.1:9090 — it appears in the footer
```

---

## 13. Unified Verification Script

After installation, run this script for a comprehensive check:

```bash
#!/bin/bash
# verify-install.sh — Comprehensive verification after installation (v1.0.0)

echo "╔══════════════════════════════════════════╗"
echo "║  DNSCrypt Verification Script            ║"
echo "║  v1.0.0                                  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

echo "=== [1] Version ==="
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
echo ""

echo "=== [2] Services ==="
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --short"
echo ""

echo "=== [3] Health ==="
su -c "curl -s http://127.0.0.1:9090/healthz"
echo ""
su -c "curl -s http://127.0.0.1:9090/readyz" | head -3
echo ""

echo "=== [4] Dashboard (v1.0.0 Fix #1) ==="
su -c "curl -s http://127.0.0.1:9091/api/metrics" | head -3
echo ""

echo "=== [5] Firewall (no orphans) ==="
COUNT=$(su -c "iptables -t nat -L OUTPUT -n 2>/dev/null | grep -cE 'RETURN|DNAT'")
echo "Orphan rules count: $COUNT (expected: 0)"
su -c "iptables -t nat -L DNSCRYPT_OUT -n 2>/dev/null | head -3"
echo ""

echo "=== [6] Status File (user intent) ==="
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"
echo ""

echo "=== [7] Config (v1.0.0 Fix #3) ==="
su -c "grep -E '^(PORT|DASHBOARD_PORT|BIND_ADDR)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
echo ""

echo "=== [8] Runtime Info (PORT-2) ==="
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" | grep -E 'webui_port|dashboard_port|version'
echo ""

echo "=== [9] Auth Status ==="
su -c "cat /data/local/tmp/dnscrypt_credentials.txt" 2>/dev/null | head -8
echo ""

echo "=== [10] NEW-1: Login POST-only ==="
su -c "curl -s -o /dev/null -w 'GET /api/auth/login → %{http_code}\n' 'http://127.0.0.1:9090/api/auth/login?username=admin&password=X'"
echo "Expected: 405 (from localhost)"
echo ""

echo "=== [11] NEW-4: /readyz localhost-only ==="
su -c "curl -s -o /dev/null -w 'GET /readyz (from localhost) → %{http_code}\n' 'http://127.0.0.1:9091/readyz'"
echo "Expected: 200 or 503"
echo ""

echo "=== [12] PORT-2: runtime_info ports ==="
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | grep -E 'webui_port|dashboard_port'"
echo ""

echo "✅ Verification complete"
```

**To use**:
```bash
# Copy the script
nano /sdcard/verify-install.sh
# Paste the content

# Run it
su -c "sh /sdcard/verify-install.sh"
```

---

## 14. References

### 14.1 Project Documentation

| Document | Purpose |
|---|---|
| [README.md](../README.md) | Overview |
| [FAQ.md](FAQ.md) | Frequently asked questions |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Troubleshooting |
| [COMPATIBILITY.md](COMPATIBILITY.md) | Compatibility matrix |
| [SECURITY.md](SECURITY.md) | Security + Audit Corrections |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Full architecture |
| [API.md](API.md) | HTTP API Reference |
| [UPGRADE.md](UPGRADE.md) | Upgrade guide |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guide |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Developer guide |
| [DNS_BINARIES.md](DNS_BINARIES.md) | DNS binaries management |
| [GLOSSARY.md](GLOSSARY.md) | Glossary |
| [ROADMAP.md](ROADMAP.md) | Future plans |
| [HALL_OF_FAME.md](HALL_OF_FAME.md) | Contributors recognition |
| [CHANGELOG.md](../CHANGELOG.md) | Version history |

### 14.2 External Documentation

- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [KernelSU Documentation](https://kernelsu.org/)
- [APatch](https://github.com/bmax121/APatch)
- [Cosign (Sigstore)](https://docs.sigstore.dev/cosign/overview/)
- [dnscrypt-proxy Wiki](https://github.com/DNSCrypt/dnscrypt-proxy/wiki)
- [HaGeZi DNS Blocklists](https://github.com/hagezi/dns-blocklists)

### 14.3 Quick Links

- **Releases**: https://github.com/gasciljh/dnscrypt-proxy-webui/releases
- **Issues**: https://github.com/gasciljh/dnscrypt-proxy-webui/issues
- **Discussions**: https://github.com/gasciljh/dnscrypt-proxy-webui/discussions
- **Security**: https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new
- **Attestations**: https://github.com/gasciljh/dnscrypt-proxy-webui/attestations

---

<div align="center">

**Last updated**: 2026-09-24
**Version**: v1.0.0
**Author**: gasciljh

</div>