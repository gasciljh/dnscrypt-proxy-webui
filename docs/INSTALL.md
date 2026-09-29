# Installation Guide — DNSCrypt Smart Filter

> Detailed step-by-step installation guide.

**Version**: v1.2.0
**Last updated**: 2026-09-29
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • §4.3 (What Happens During Installation) rewritten for the
>     10 defensive layers (Layer 1..Layer 10).
>   • §4.4 (Successful Installation Screen) now includes the
>     backup layer output and the restore summary.
>   • §7.2 (`/readyz` verification) updated to expect `v1.2.0`.
>   • §7.7 (Dashboard verification) unchanged.
>   • §7.10 (Runtime Info verification) now verifies the
>     7-field `backups` object in addition to `profile_key` +
>     `memory_limit_mb`.
>   • **§7.12 (new)** — Verify Backup Layer (7-field object,
>     snapshot count, `.last_stable`).
>   • **§9.3 (What Happens During Update) rewritten** — the
>     10-layer model replaces the legacy `BACKUP_TMP` flow.
>   • **§9.8 (new)** — Verify the backup layer after upgrade.
>   • **§10.3 (What Happens on Uninstall) updated** — the
>     persistent backup directory is now **preserved** on
>     uninstall (see §10.7).
>   • **§10.7 (new)** — Preserved backup directory after
>     uninstall.
>   • **§10.8 (new)** — Trigger recovery mode.
>   • §12 renamed from "v1.1.0 Specific Notes" to
>     "v1.2.0 Specific Notes".
>   • **§12.4 (Key Changes in v1.2.0)** — new table with the
>     10 defensive layers + BAK-1..BAK-4 + FIX-1/FIX-2.
>   • **§12.6 (new)** — v1.2.0 backup: quick test.
>   • **§12.7 (new)** — v1.2.0 recovery mode: quick test.
>   • §13 (Unified Verification Script) extended with v1.2.0
>     checks (backup state, 7-field object, recovery triggers).
>   • All ZIP filename examples updated: `1.1.0` → `1.2.0`.
>   • No structural changes to the installation procedure.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention.

> **v1.2.0 (Global Edition) — Corrections in this revision**:
>   • 🔧 **FIX-1 description** — §12.4 previously described FIX-1
>     as a "recovery-mode reorder" that "excludes 2 files at
>     risk". The actual implementation in `customize.sh` uses a
>     **snapshot-and-reapply** strategy (`§[8a]` + `§[9]` +
>     `§[9b2]`), which keeps the extraction logic of `§[9]`
>     untouched. The description has been corrected to match the
>     shipped code.
>   • 🔧 **Backup directory path** — §10.7 previously showed
>     `rm -rf /sdcrypt-webui-backup`, which is a typo. The
>     correct path is `/sdcard/dnscrypt-webui-backup`. Corrected.

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
12. [v1.2.0 Specific Notes](#12-v120-specific-notes)
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
| **Storage (`/sdcard/`)** | **10 MB** (for backups, v1.2.0) |
| **Architecture** | arm64 / arm / x86_64 / x86 |

### 1.2 Recommended

| Requirement | Recommended |
|---------|-----------|
| **Android** | 10+ (API 29) |
| **Root** | Magisk 26+ |
| **Kernel** | 4.14+ |
| **RAM** | 2 GB+ |

**v1.1.0 note**: On 1 GB devices, prefer the `light` or
`normal` profile. The `ultimate` profile sets a 220 MB soft
limit for the WebUI process — see §12.4.

**v1.2.0 note**: The persistent backup directory requires at
least **10 MB** free on `/sdcard/`. Each snapshot uses ~30–100 KB;
the rotation cap (21 snapshots) bounds the total to ~2.5 MB.
See [`docs/BACKUP.md`](BACKUP.md) §6.4.

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

df -h /sdcard
# → Avail: 45G  (must be ≥ 10 MB, v1.2.0)
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
# Latest release (v1.2.0)
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.2.0-module.zip

# Or
curl -L -o dnscrypt-webui-1.2.0-module.zip \
    https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.2.0-module.zip
```

### 3.2 Verify SHA-256

```bash
# Download checksum
curl -L -O https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/module.zip.sha256

# Verify
sha256sum -c module.zip.sha256
# → dnscrypt-webui-1.2.0-module.zip: OK
```

### 3.3 Verify Signature (optional, recommended)

```bash
# Download signature + certificate
curl -L -O https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.2.0-module.zip.sig
curl -L -O https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.2.0-module.zip.pem

# Verify (Cosign keyless)
cosign verify-blob \
    --signature dnscrypt-webui-1.2.0-module.zip.sig \
    --certificate dnscrypt-webui-1.2.0-module.zip.pem \
    --certificate-identity-regexp "https://github.com/gasciljh/dnscrypt-proxy-webui/.*" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    dnscrypt-webui-1.2.0-module.zip
```

**Expected**:
```text
Verified OK
```

### 3.4 Transfer to Device

```bash
# Via ADB
adb push dnscrypt-webui-1.2.0-module.zip /sdcard/Download/

# Or copy manually
```

---

## 4. Installation via Magisk

### 4.1 From Magisk Manager

1. Open **Magisk Manager**.
2. Go to **Modules**.
3. Press **Install from storage**.
4. Choose `dnscrypt-webui-1.2.0-module.zip`.
5. Press **OK** to confirm.

### 4.2 From TWRP (alternative)

```bash
# In TWRP
adb push dnscrypt-webui-1.2.0-module.zip /sdcard/
# Then from TWRP: Install → choose the ZIP
```

### 4.3 What Happens During Installation

The steps inside `customize.sh` now follow the **10 defensive
layers** introduced in v1.2.0:

1. `customize.sh` starts.
2. Detects the architecture (e.g. `arm64-v8a`).
3. **Layer 1 — Multi-source detection** — searches 7 candidate
   locations for user data (in-place, standard, legacy,
   persistent `current/`, persistent flat, tmp fallback, plus
   APatch `modules_update/`).
4. **Upgrade check** — detects the old module (if present).
5. **Stop old processes** (`pkill dnscrypt-proxy`, `dnscrypt-webui`).
6. **Firewall cleanup** (Custom Chains + Legacy).
7. **Layer 4 — Begin transaction** — creates a `txn-*` directory
   under `/sdcard/dnscrypt-webui-backup/` with `.state = START`.
8. **Layer 2 — Persistent backup** — snapshots the 5 user config
   files to:
   - `/sdcard/dnscrypt-webui-backup/<ts>-<version>-<pid>/`
   - The 5 files: `webui.conf`, `dnscrypt-proxy.toml`,
     `selected_profile.txt`, `allowlist.txt`, `denylist.txt`.
   - Writes `.manifest.json` with per-file SHA256 (Layer 3).
9. **Extract module files** (`unzip -o`).
10. Move web files (HTML/JSON/ICO) to `web/`.
11. **Layer 6 — Restore user settings** (via `copy_with_context`):
    - Copies saved files over defaults.
    - Restores SELinux context (`restorecon` / `chcon`).
    - Sets mode `0600`.
12. **Layer 5 — Root-solution detection** — adapts the restore
    source to Magisk / KernelSU / APatch.
13. Verify critical files.
14. Select the correct binaries for the architecture.
15. Create `run/` directory with `0700` permissions.
16. Write `webui.conf` (with **Port Guard** to reject 8080).
17. Generate **secure credentials** (username + password).
18. Set permissions.
19. Write the module fingerprint.
20. **Layer 8 — Config migrations** — applies version-aware
    transforms (e.g. `MEMORY_LIMIT_HINT=auto`).
21. **Layer 10 — Update `.last_stable`** pointer + append
    `.upgrade_history.json`.
22. **Commit the transaction** — removes the `txn-*` directory
    and writes `.state = COMMIT`.
23. Print the expected memory limit for the active profile
    (informational — set by `main.go` at startup).

**On failure**: any error before step 22 triggers an automatic
rollback (Layer 4). The `txn-*` directory is preserved as
`orphan-txn-*` for manual inspection.

### 4.4 Successful Installation Screen

**Expected in Magisk**:
```text
╔═════════════════════════════════════╗
║  🛡️  DNSCrypt Smart Filter                ║
║      v1.2.0                               ║
║      Professional Edition                 ║
╚═════════════════════════════════════╝

- Architecture: arm64-v8a
- Upgrade detected, cleaning old instances...
  → Killed 3 old process(es)
  → Firewall rules cleaned (Custom Chain + Legacy)
  ✅ Old instances cleaned
  → Multi-source detection (Layer 1): 5 file(s) found
  → Transaction begun (Layer 4): txn-20260929-150000-12345
  → Persistent backup created (Layer 2): 20260929-150000-v1.2.0-12345
    → SHA256 manifest written (Layer 3)
- Extracting module files...
  ✅ Files extracted
- Restoring user configuration...
  ✅ Restored 5 user config file(s)
- Target binaries: dnscrypt-proxy-arm64 + dnscrypt-webui-arm64
- Creating secure run/ directory...
  ✅ run/ directory created (0700)
  ✅ Migrated status files

- Generating secure credentials...

╔════════════════════════════════════╗
║  🔐 Login Credentials Generated          ║
╚════════════════════════════════════╝
  👤 Username: admin_xxxxxxxx
  🔑 Password: XXXXXXXXXXXXXXXXXXXXXXXX

📌 Keep these credentials to log in
📄 Saved copy: /data/local/tmp/dnscrypt_credentials.txt

╔═════════════════════════════════════╗
║  ✅ Installation Complete                 ║
║      v1.2.0                               ║
╚═════════════════════════════════════╝

  📊 Upgrade detected: YES (5 files restored)
  💾 Persistent backup: /sdcard/dnscrypt-webui-backup/
  🌐 WebUI: http://127.0.0.1:9090
  📈 Dashboard: http://127.0.0.1:9091
  🔌 Bind: 127.0.0.1
  🧠 Memory limit: ~120 MB (profile: pro)   ← v1.1.0

  ℹ️  Next steps:
    1. Reboot your device
    2. Open the WebUI and login with the credentials above
    3. Choose a blocklist profile and press Apply
```

⚠️ **Important**: Copy the credentials — you will need them in **Step 8**.

**v1.1.0 addition**: The `🧠 Memory limit: ~120 MB (profile: pro)`
line is computed by `customize.sh` from
`selected_profile.txt`. It reflects the soft limit that
`main.go` will apply at startup. See §12.4 for the full table.

**v1.2.0 addition**: The `💾 Persistent backup:` line confirms that
Layer 2 created a snapshot in `/sdcard/dnscrypt-webui-backup/`.
On the first boot after installation, `service.sh` runs
`auto_backup_if_needed(24 h)` and may create an additional
`-auto-` snapshot.

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
4. Choose `dnscrypt-webui-1.2.0-module.zip`.
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
- **v1.2.0**: Layer 5 (Root-solution detection) prepends the
  `modules_update/` paths to the candidate list, so user data is
  still found even if APatch has already deleted the old module
  folder.

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
╔════════════════════════════════════════════════╗
║  🛡️  DNSCrypt Smart Filter v1.2.0                      ║
║      ✅ ACTIVE                                         ║
╚════════════════════════════════════════════════╝

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

# Readiness (localhost-only — Fix NEW-4)
su -c "curl -s http://127.0.0.1:9090/readyz"
# → {"blocklist":"ok","config":"ok","run_dir":"ok","status":"ready","version":"v1.2.0"}
```

⚠️ **Note**: `version` must be `v1.2.0`.

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

⚠️ **Fix A**: Not written by read-only functions — written only by `startService` / `stopService`.

⚠️ **Fix #2**: `getSystemShell()` uses `sync.Once` — cached once (no repeated overhead).

### 7.6 Verify No Orphans

```bash
# Number of direct DNAT/RETURN rules in OUTPUT (outside DNSCRYPT_OUT)
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
```
**Expected**: `0` (no orphans).

If you see a number > 0 → see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

### 7.7 Verify Dashboard (v1.1.0)

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

⚠️ **If tables are empty** → see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §4.8.

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

# 3. Persistent backup directory (v1.2.0 — still exists)
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
# Expected: current/, <ts>-<version>/…, .last_stable, …

# 4. Legacy backup directory (v1.1.0 artifact — should NOT exist)
su -c "ls -la /data/local/tmp/dnscrypt-upgrade-backup-* 2>/dev/null"
# Expected: (none — superseded by the persistent backup)
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

### 7.10 Verify Runtime Info (PORT-2 + MEM-1 + BAK-1)

```bash
# 1. Ports (PORT-2)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# 2. From LAN (with BIND_ADDR=0.0.0.0)
curl -s http://192.168.1.5:9090/api?action=runtime_info | jq '.bind_addr'
# Expected: "0.0.0.0"

# 3. Profile + Memory (v1.1.0 — MEM-1)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"
# Expected: {"profile_key": "pro", "memory_limit_mb": 120}

# 4. Confirm the value matches the profile
# If profile_key is "ultimate", memory_limit_mb must be 220.
# If profile_key is "light", memory_limit_mb must be 80.
# See §12.4 for the full table.

# 5. Backups object (v1.2.0 — BAK-1) — 7 fields
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
# Expected: an object with 7 keys:
#   available, in_flight_txn, orphan_txn,
#   last_backup, last_backup_name, last_stable, path
```

**Verify the startup log line** (v1.1.0, still present):

```bash
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
# Expected: 🧠 v1.1.0: dynamic memory limit — profile=pro, limit=120 MB
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

### 7.12 Verify Backup Layer (v1.2.0 — new)

```bash
# 1. Backup directory exists
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
# Expected: current/, <ts>-<version>/…, .last_stable, …

# 2. Backup state (7-field object)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
# Expected: {"available": N, "in_flight_txn": 0, "orphan_txn": 0, ...}

# 3. Sanity: no in-flight or orphan transactions
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | select(.in_flight_txn > 0 or .orphan_txn > 0)'"
# Expected: no output (nothing to worry about)

# 4. The 5 preserved files are present in current/
su -c "ls /sdcard/dnscrypt-webui-backup/current/"
# Expected: webui.conf, dnscrypt-proxy.toml, selected_profile.txt,
#           allowlist.txt, denylist.txt, .manifest.json

# 5. .last_stable pointer
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"
# Expected: a snapshot directory name (e.g. 20260929-095826-v1.2.0-12345)

# 6. Full diagnostic (Layer 10)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
# Expected: sections for System Info, Backups, User Data Files,
#           Recovery & Notifications, Health Checks.
```

**If `available == 0`**: run a manual backup — see §7.13.

### 7.13 Create a Manual Backup (v1.2.0 — new)

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

**Expected output**:
```text
╔════════════════════════════════════════════════════════╗
║  💾 DNSCrypt – Manual Backup                           ║
╚════════════════════════════════════════════════════════╝

  Source: /data/adb/modules/dnscrypt-proxy-webui/proxy
  Target: /sdcard/dnscrypt-webui-backup

  ✅ Backup created: .../<ts>-manual-<pid> (5 file(s))

  Current backup state:
    7 snapshot(s), latest 0s ago
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

⚠️ **v1.1.0**: Login is **POST-only** — if you use a script, use POST (see [`API.md`](API.md)).

### 8.3 Choose a List

1. In **📝 Select Blocklist**, choose:
   - ☀️ **Light** (40K entries) — recommended for 1 GB RAM devices
   - 🧹 **Normal** (120K) — recommended for 2 GB RAM devices
   - 🛡️ **PRO** (250K) — recommended (default), 3 GB RAM devices
   - ⚡ **PRO++** (350K) — recommended for 4 GB RAM devices
   - 🔥 **Ultimate** (500K) — for 6 GB+ RAM devices
2. Press **Apply**.
3. Wait (30s - 5 min depending on the list).

**v1.1.0 note**: Each profile sets a corresponding memory limit
for the WebUI process. Choose based on your device's RAM:

| Profile | RAM target | WebUI soft limit |
|---|---|---:|
| Light | 1 GB | 80 MB |
| Normal | 2 GB | 100 MB |
| PRO | 3 GB | 120 MB |
| PRO++ | 4 GB | 160 MB |
| Ultimate | 6 GB+ | 220 MB |

See §12.4 for details.

**v1.2.0 note**: A pre-critical backup is created before each
profile change (BAK-2). See §7.12.

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

**v1.2.0**: A pre-critical backup is created before each save
(BAK-2). No user action is required.

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

**v1.1.0**: The System Info panel (in both WebUI and Dashboard)
now also shows the active profile and the memory limit. See
§7.10.

**v1.2.0**: The System Info panel now also displays **6 backup
fields** from the new `backups` object:

- **Backups** — snapshot count.
- **Latest Backup** — newest snapshot name.
- **Last Stable** — pointer content.
- **In-flight Txn** — number of `txn-*` dirs.
- **Orphan Txn** — number of `orphan-txn-*` dirs.
- **Backup Path** — `/sdcard/dnscrypt-webui-backup`.

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
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.2.0-module.zip

# 2. Install over the old one (from Magisk directly)
# 3. Reboot
```

### 9.3 What Happens During Update

**v1.2.0** — the 10 defensive layers are applied automatically:

- **Layer 1** — Multi-source detection finds the 5 user files
  in 7 candidate locations.
- **Layer 2** — Snapshot to `/sdcard/dnscrypt-webui-backup/`
  (survives reboot, uninstall, and `/data` reset).
- **Layer 3** — SHA256 integrity verification (advisory).
- **Layer 4** — Transactional install with automatic rollback.
- **Layer 5** — Root-solution detection (Magisk / KernelSU / APatch).
- **Layer 6** — SELinux context preservation.
- **Layer 7** — Recovery mode (not triggered on a normal update).
- **Layer 8** — Config migrations.
- **Layer 9** — Rotation (max 21 snapshots).
- **Layer 10** — Full observability.
- **Result**: Your settings are preserved **and** a persistent
  snapshot is created for future recovery.

**Preserved files (5)**:

| File | Purpose |
|---|---|
| `webui.conf` | WebUI/Dashboard settings |
| `dnscrypt-proxy.toml` | DNSCrypt settings + credentials |
| `selected_profile.txt` | Active profile |
| `allowlist.txt` | Custom rules |
| `denylist.txt` | Custom rules |

**⚠️ Security note**:
- Backup directory: `/sdcard/dnscrypt-webui-backup/`.
- Permissions: `0700` on the directory, `0600` on files.
- **Preserved after a successful upgrade** — used for future
  recovery.
- Rotation cap: 21 snapshots (~2.5 MB max).
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
- **Verify PORT-2 + MEM-1**:
  ```bash
  su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port, profile_key, memory_limit_mb}'"
  # → {"webui_port": "9090", "dashboard_port": "9091", "profile_key": "pro", "memory_limit_mb": 120}
  ```
- **Verify the persistent backup layer (v1.2.0)**:
  ```bash
  su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
  # → {"available": N, "in_flight_txn": 0, "orphan_txn": 0, ...}
  su -c "ls -la /sdcard/dnscrypt-webui-backup/"
  # → current/, <ts>-<version>/…, .last_stable, …
  ```

### 9.5 Upgrading from an older version

1. **install**:
   - `customize.sh` detects the old module.
   - Kills processes.
   - Runs `_inline_cleanup_firewall`.
   - **Layer 1** — multi-source detection (7 candidates).
   - **Layer 2** — persistent snapshot to `/sdcard/`.
   - Extracts the new files.
   - **Layer 6** — restore with SELinux context.
2. **reboot**:
   - `service.sh` starts the WebUI.
   - On the first `startService()`:
     - `DNSCRYPT_OUT` is created.
     - `DNSCRYPT_OUT6` is created (if IPv6 is available).
     - `STATUS_FILE` = "ON".
     - `applyMemoryLimit()` is called from `main()`.
   - On boot, `service.sh` runs `auto_backup_if_needed(24 h)`
     and `rotate_backups(21)`.
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

   # v1.1.0 fields present
   su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"
   ```
4. **Verify the backup layer (v1.2.0)**:
   ```bash
   # Backup directory created
   su -c "ls -d /sdcard/dnscrypt-webui-backup/"

   # 7-field backups object
   su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'"
   # → ["available","in_flight_txn","last_backup","last_backup_name","last_stable","orphan_txn","path"]

   # .last_stable pointer (set by install-time snapshot)
   su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"
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
# Expected: 1020000 (v1.2.0)
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
| v1.2.0 | 1020000 |
| v2.0.0 | 2000000 |

### 9.8 Verify the Backup Layer After Upgrade (v1.2.0 — new)

```bash
# 1. Persistent backup directory exists
su -c "ls -la /sdcard/dnscrypt-webui-backup/"

# 2. At least one snapshot exists
COUNT=$(su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups.available'")
[ "$COUNT" -ge 1 ] && echo "✅ $COUNT snapshot(s)" || echo "❌ no snapshot"

# 3. The 7-field object is well-formed
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'"
# Expected: 7 keys

# 4. Cross-check with status.sh --json
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | jq '.backups'"
# Expected: same 7 shared fields

# 5. .last_stable is set
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable" | grep -qE '^[0-9]{8}-[0-9]{6}-' && echo "✅ valid"

# 6. Full diagnostic (Layer 10)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | head -20
```

**If `available == 0`**: run a manual backup (see §7.13) or reboot
to let `service.sh` run `auto_backup_if_needed(24 h)`.

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

1. **Stop all processes** (`pkill -9`).
2. **Full firewall cleanup** (`-D` + `-F` + `-X`).
3. **Legacy cleanup** (best-effort).
4. **Reset DNS settings** to normal (**AUTO**).
5. **Restore `route_localnet`** to its original state (instead of
   forcing 0).
6. **Delete runtime files** in `/data/local/tmp/`.
7. **Delete module settings** (blocklist, allowlist, denylist, ...).
8. **Remove legacy backup directory** (v1.0.0 artifact, if any).
9. **v1.2.0 — Preserve the persistent backup directory**
   (`/sdcard/dnscrypt-webui-backup/`) so a future reinstall can
   restore your settings.
10. **v1.2.0 — Rename `txn-*` with `.state=START` to
    `orphan-txn-*`** (preserved for manual inspection).
11. **v1.2.0 — Remove `txn-*` with `.state=COMMIT` or
    `.state=ROLLBACK`**.
12. **v1.2.0 — Remove the external recovery trigger**
    (`/data/adb/dnscrypt-recovery`) if present.

**v1.2.0 note**: The persistent backup directory is **preserved**
on uninstall so that a reinstall can recover your 5 config files
automatically (via Layer 1 multi-source detection). To remove it
manually:

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

**v1.1.0 behavior (superseded)**: `uninstall.sh` did not create a
backup, and the module settings were removed permanently. Since
v1.2.0, the persistent backup **survives** the uninstall.

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

### 10.5 Manual Backup Before Uninstall (v1.2.0)

> **v1.2.0 note**: You **do not need** to do this anymore. The
> persistent backup at `/sdcard/dnscrypt-webui-backup/` survives
> uninstall and is restored automatically on the next install.

**Only if** you plan to wipe `/sdcard/` or do a factory reset:

```bash
# Create an external backup directory
su -c "mkdir -p /sdcard/manual-backup-$(date +%Y%m%d)"

# Copy the 5 user config files
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf /sdcard/manual-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml /sdcard/manual-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt /sdcard/manual-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/allowlist.txt /sdcard/manual-backup-$(date +%Y%m%d)/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/denylist.txt /sdcard/manual-backup-$(date +%Y%m%d)/"

# Verify
su -c "ls -la /sdcard/manual-backup-$(date +%Y%m%d)/"
```

**Or**, take a manual snapshot from the module's own system:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

Then copy `/sdcard/dnscrypt-webui-backup/` off-device (§7.8 in
[`docs/BACKUP.md`](BACKUP.md)).

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

### 10.7 Preserved Backup Directory After Uninstall (v1.2.0 — new)

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

### 10.8 Trigger Recovery Mode (v1.2.0 — new)

If the module is unbootable or user data is corrupted:

```bash
# Option A — module-specific trigger
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"

# Option B — external trigger (survives module folder loss)
su -c "touch /data/adb/dnscrypt-recovery"
su -c "reboot"
```

On the next boot, `customize.sh` runs in **recovery mode** and
restores the last known-good snapshot from
`/sdcard/dnscrypt-webui-backup/`.

**Recovery source priority**:
1. `.last_stable` → the pointer file.
2. `current/` → the live snapshot.
3. In-place `proxy/` → fallback.

**Verify the recovery**:
```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
```

**Both trigger files are removed** after a successful restore.

**Full guide**: [`docs/EMERGENCY.md`](EMERGENCY.md) §9.

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

## 12. v1.2.0 Specific Notes

### 12.1 First-Time Installation

1. **Port Guard**: If `webui.conf` exists with `PORT=8080` → automatically replaced with `9090`.
2. **Credentials**: Generated by `customize.sh`. Save them.
3. **Firewall**: Starts empty (no Custom Chains). Created on first run.
4. **Dashboard**: Works immediately (JSON metrics).
5. **Memory limit**: Printed by `customize.sh` during install
   (informational — the effective limit is set by `main.go` at
   startup). See §12.4.
6. **v1.2.0 — Persistent backup**: On the first boot,
   `service.sh` runs `auto_backup_if_needed(24 h)`, creating
   the first snapshot at `/sdcard/dnscrypt-webui-backup/`.

### 12.2 On Upgrade

1. **Auto backup/restore**: 5 files preserved.
2. **Orphan cleanup**: Automatic from `customize.sh` (legacy best-effort).
3. **Custom Chains**: Recreated on first `startService()`.
4. **STATUS_FILE**: Read from the old file if present.
5. **Memory limit**: Recomputed at startup from the preserved
   `selected_profile.txt`.
6. **v1.2.0 — Persistent backup**: A new snapshot is created
   by `customize.sh` (Layer 2), and `.last_stable` is updated
   (Layer 10).
7. **v1.2.0 — Rotation**: The periodic and manual flows keep the
   21 newest snapshots.

### 12.3 On Uninstall

1. **Full cleanup**: `_inline_cleanup_firewall` + `_legacy_cleanup_*`.
2. **Legacy backup cleanup**: Any `/data/local/tmp/dnscrypt_backup_uninstall/`
   from v1.0.0 is removed.
3. **DNS reset**: `settings delete global global private_dns_mode`.
4. **v1.2.0 — Persistent backup is PRESERVED**. The
   `/sdcard/dnscrypt-webui-backup/` directory survives the
   uninstall and is restored on the next install (Layer 1).
   See §10.3 and §10.7.
5. **v1.2.0 — Orphan transactions preserved**. `txn-*` with
   `.state=START` are renamed to `orphan-txn-*` (see §10.7).
6. **v1.2.0 — External recovery trigger removed**
   (`/data/adb/dnscrypt-recovery`).

### 12.4 Key Changes in v1.2.0

| Feature | Impact on Installation |
|---|---|
| **Layer 1 — Multi-source detection** | `customize.sh` searches 7 candidate locations for user data. |
| **Layer 2 — Persistent backup** | Snapshots to `/sdcard/dnscrypt-webui-backup/` (survives reboot + uninstall + `/data` reset). |
| **Layer 3 — SHA256 integrity** | Advisory check; a mismatch is logged but does not block a restore. |
| **Layer 4 — Transactional upgrade** | Atomic install with automatic rollback (`txn-*` directories). |
| **Layer 5 — Root-solution detection** | Magisk / KernelSU / APatch each handled correctly (APatch uses `modules_update/`). |
| **Layer 6 — SELinux preservation** | `restorecon` (or `chcon` fallback) on every restored file. |
| **Layer 7 — Recovery mode** | A `recovery` trigger file restores the last known-good config on next boot. |
| **Layer 8 — Config migrations** | Version-aware transforms (e.g. `MEMORY_LIMIT_HINT=auto`). |
| **Layer 9 — Rotation** | Max 21 snapshots; periodic (24 h) + pre-critical backups. |
| **Layer 10 — Observability** | `status.sh --diagnose`, 7-field `runtime_info.backups`. |
| **BAK-1 — 7-field backups schema** | `runtime_info.backups` returns `available`, `in_flight_txn`, `orphan_txn`, `last_backup`, `last_backup_name`, `last_stable`, `path`. |
| **BAK-2 — Pre-critical backups** | `createAutoBackup(reason)` called from 5 destructive endpoints; serialized by `backupMu`. |
| **BAK-3 — `cleanupOldTransactions`** | Removes leftover `COMMIT`'d `txn-*` dirs at startup. |
| **BAK-4 — `checkPendingNotifications`** | Reads `.pending_notification` at startup. |
| **FIX-1 — Recovery-mode correctness via snapshot-and-reapply** | `§[8a]` restores the 5 files **and** copies each to `$MODPATH/.recovery_snapshot/`. `§[9]` extracts the ZIP normally (the extraction logic is left untouched, so the normal-install path is byte-for-byte identical). `§[9b2]` re-applies the 5 files from the snapshot. This strategy does not depend on knowing the ZIP's contents. |
| **FIX-2 — Service Worker update-banner** | Send `SKIP_WAITING` to the correct worker (both `index.html` + `dashboard.html`). |
| **New CLI — `action.sh --backup`** | Trigger a manual backup (see §7.13). |
| **New CLI — `status.sh --diagnose`** | Full diagnostic report (see §7.12). |
| **Bilingual WebUI** | English default + Arabic toggle. Client-side only; no API impact. |
| **MEM-1 / MEM-2 / MEM-3** (carried forward from v1.1.0) | Dynamic memory limit per profile; extended `shellQuote`; `MONITORING_UI_PORT` constant. |
| **Fix #1 / #2 / #3** (carried forward from v1.0.0) | Dashboard JSON; `getSystemShell`; preserve settings. |
| **NEW-1 / NEW-3 / NEW-4 / NEW-5 / NEW-6** (carried forward) | Login POST-only; `readConfPort` range; `/readyz` localhost; `shellQuote`; auth cache. |
| **RACE-1 / PORT-2** (carried forward) | `rebuildMu` mutex; `runtime_info` ports. |

**Memory limits per profile (MEM-1, carried forward from v1.1.0)**:

| `profile_key` | Soft limit | Typical RAM |
|---|---:|:---:|
| `light` | 80 MB | 1 GB |
| `normal` | 100 MB | 2 GB |
| `pro` | 120 MB | 3 GB |
| `proplus` | 160 MB | 4 GB |
| `ultimate` | 220 MB | 6 GB+ |

**Semantics**: `debug.SetMemoryLimit` is a **soft** limit. The Go
runtime does not kill the process — it runs GC more aggressively
instead. Setting it too low causes CPU waste; too high wastes
RAM. Hence the per-profile values.

### 12.5 Verify the Version

```bash
# Method 1: module.prop
su -c "grep -E '^(version|versionCode)=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected:
# version=v1.2.0
# versionCode=1020000

# Method 2: runtime_info
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | grep version"
# Expected: contains "version":"v1.2.0"

# Method 3: status.sh --check
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# Expected: starts with "v1.2.0"

# Method 4: readyz
su -c "curl -s http://127.0.0.1:9090/readyz | grep version"
# Expected: contains "version":"v1.2.0"

# Method 5: WebUI
# Open http://127.0.0.1:9090 — it appears in the footer / badge
```

**Additional v1.1.0 verifications**:

```bash
# Memory fields present
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"
# Expected: {"profile_key": "<profile>", "memory_limit_mb": <value>}

# Startup log line
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
# Expected: 🧠 v1.1.0: dynamic memory limit — profile=<key>, limit=<value> MB
```

**Additional v1.2.0 verifications**:

```bash
# Backups object (7 fields)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'"
# Expected: ["available","in_flight_txn","last_backup","last_backup_name","last_stable","orphan_txn","path"]

# Backup directory exists
su -c "ls -d /sdcard/dnscrypt-webui-backup/" && echo "✅ present"

# .last_stable is set
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable" | grep -qE '^[0-9]{8}-[0-9]{6}-' && echo "✅ valid"

# Diagnostic tool exists
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | head -5

# Bilingual WebUI — toggle present in all three pages
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && echo '✅ index'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html && echo '✅ dashboard'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/offline.html && echo '✅ offline'"
```

### 12.6 v1.2.0 Backup — Quick Test

```bash
# 1. Record the current profile
ORIG_PROFILE=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
echo "Before: $ORIG_PROFILE"

# 2. Create a manual backup
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"

# 3. Change the profile (as a "damage" simulation)
su -c "echo 'light' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 4. Restore the original file from the newest snapshot
SNAP=$(su -c "ls -1dt /sdcard/dnscrypt-webui-backup/*/ | \
       grep -vE '/(current|txn-|orphan-txn-)' | head -1" | tr -d '\r')
su -c "cp $SNAP/selected_profile.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "restorecon /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 5. Verify
NEW_PROFILE=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
[ "$NEW_PROFILE" = "$ORIG_PROFILE" ] && echo "✅ restored" || echo "❌ mismatch"
```

### 12.7 v1.2.0 Recovery Mode — Quick Test

**Pre-flight checklist**:

- [ ] You have a recent snapshot: `su -c "ls /sdcard/dnscrypt-webui-backup/"`.
- [ ] `.last_stable` is set: `su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"`.
- [ ] You recorded the current profile:
  `su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"`.

**Procedure**:

```bash
# 1. Note the current profile
ORIG=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")

# 2. Change it (simulate damage)
su -c "echo 'light' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 3. Trigger recovery
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"

# 4. After boot (~60s), verify
NEW=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
[ "$NEW" = "$ORIG" ] && echo "✅ Recovery restored the profile" || echo "❌ mismatch"

# 5. Confirm the trigger file is gone
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>&1"
# Expected: No such file or directory
```

**Full guide**: [`docs/EMERGENCY.md`](EMERGENCY.md) §9.

---

## 13. Unified Verification Script

After installation, run this script for a comprehensive check:

```bash
#!/bin/bash
# verify-install.sh — Comprehensive verification after installation (v1.2.0)

echo "╔════════════════════════════════════╗"
echo "║  DNSCrypt Verification Script            ║"
echo "║  v1.2.0                                  ║"
echo "╚════════════════════════════════════╝"
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

echo "=== [4] Dashboard (Fix #1) ==="
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

echo "=== [7] Config (Fix #3) ==="
su -c "grep -E '^(PORT|DASHBOARD_PORT|BIND_ADDR)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
echo ""

echo "=== [8] Runtime Info (PORT-2 + MEM-1) ==="
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" | grep -E 'webui_port|dashboard_port|version|profile_key|memory_limit_mb'
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

echo "=== [13] v1.1.0 — Memory limit (MEM-1) ==="
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"
echo "Expected values by profile:"
echo "  light=80, normal=100, pro=120, proplus=160, ultimate=220"
echo ""

echo "=== [14] v1.1.0 — Startup log line ==="
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
echo ""

echo "=== [15] v1.1.0 — Profile file vs runtime ==="
echo -n "selected_profile.txt: "
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
echo -n "runtime profile_key:  "
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'"
echo "(these two must match)"
echo ""

echo "=== [16] v1.2.0 — Backup state (7 fields) ==="
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
echo ""

echo "=== [17] v1.2.0 — Backup directory ==="
su -c "ls -la /sdcard/dnscrypt-webui-backup/ | head -10"
echo ""

echo "=== [18] v1.2.0 — .last_stable pointer ==="
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"
echo ""

echo "=== [19] v1.2.0 — No in-flight or orphan transactions ==="
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups | \"in_flight_txn=\\(.in_flight_txn) orphan_txn=\\(.orphan_txn)\"'"
echo ""

echo "=== [20] v1.2.0 — Diagnostic tool ==="
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | head -10
echo ""

echo "=== [21] v1.2.0 — Backup CLI ==="
su -c "test -x /data/adb/modules/dnscrypt-proxy-webui/action.sh" && echo "✅ action.sh present"
su -c "grep -q '\-\-backup' /data/adb/modules/dnscrypt-proxy-webui/action.sh && echo '✅ --backup flag'"
echo ""

echo "=== [22] v1.2.0 — Bilingual WebUI ==="
for f in index.html dashboard.html offline.html; do
    su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/$f && echo '✅ $f toggle'"
done
echo ""

echo "=== [23] v1.2.0 — 10 defensive layers in customize.sh ==="
for L in CANDIDATE_SOURCES PERSISTENT_BACKUP verify_backup_integrity \
         begin_transaction detect_root_solution copy_with_context \
         RECOVERY_TRIGGER migrate_config; do
    su -c "grep -q '$L' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ $L' || echo '❌ $L'"
done
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
| [FAQ.md](FAQ.md) | Frequently asked questions (Q121–Q130) |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Troubleshooting |
| [COMPATIBILITY.md](COMPATIBILITY.md) | Compatibility matrix |
| [SECURITY.md](SECURITY.md) | Security + Audit Corrections (§5.31, §5.32) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Full architecture (§3.10, §4.10) |
| [API.md](API.md) | HTTP API Reference (§6.1.7) |
| [UPGRADE.md](UPGRADE.md) | Upgrade guide (§3.0, §3.1) |
| [BACKUP.md](BACKUP.md) | **Backup system reference (v1.2.0)** |
| [EMERGENCY.md](EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
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
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [Android FUSE — Storage Access Framework](https://source.android.com/docs/core/storage)
- [Android SELinux — restorecon](https://source.android.com/docs/security/features/selinux)

### 14.3 Quick Links

- **Releases**: https://github.com/gasciljh/dnscrypt-proxy-webui/releases
- **Issues**: https://github.com/gasciljh/dnscrypt-proxy-webui/issues
- **Discussions**: https://github.com/gasciljh/dnscrypt-proxy-webui/discussions
- **Security**: https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new
- **Attestations**: https://github.com/gasciljh/dnscrypt-proxy-webui/attestations

---

<div align="center">

**Last updated**: 2026-09-29
**Version**: v1.2.0
**Author**: gasciljh

</div>