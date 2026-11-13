# User Guide — DNSCrypt Smart Filter

**Version**: v1.6.0 (Global Edition)
**Last updated**: 2026-11-13
**Audience**: End users installing, using, upgrading, and troubleshooting the module.

> This file replaces `docs/INSTALL.md`, `docs/UPGRADE.md`,
> `docs/TROUBLESHOOTING.md`, `docs/FAQ.md`, and
> `docs/EMERGENCY.md` (merged in v1.5.0). If you are a
> developer, see `docs/CONTRIBUTING.md`. If you are an
> integrator, see `docs/REFERENCE.md` §2.

## Table of Contents

1. [What You Get](#1-what-you-get)
2. [Install](#2-install)
3. [First-Time Setup](#3-first-time-setup)
4. [Daily Use](#4-daily-use)
5. [Update](#5-update)
6. [Uninstall](#6-uninstall)
7. [Troubleshooting](#7-troubleshooting)
8. [Emergency Recovery](#8-emergency-recovery)
9. [Companion Android App](#9-companion-android-app)
10. [FAQ](#10-faq)
11. [Reference](#11-reference)

---

## 1. What You Get

A Magisk/KernelSU module that turns your device into a
system-wide encrypted DNS resolver. It blocks ads and trackers
in **every app** — no VPN required.

### 1.1 Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| Android | 5.0 (API 21) | 10+ (API 29) |
| Root | Magisk 20.4+ / KernelSU 0.9+ / APatch | Magisk 26+ |
| RAM | 1 GB | 2 GB+ |
| `/data` free | 20 MB | — |
| `/sdcard` free | 6 MB | 50 MB+ |
| Architecture | arm64 / arm / x86_64 / x86 | arm64 |

**v1.6.0 `/sdcard` note**: The 6 MB minimum accounts for the
persistent backup (~2.5 MB with rotation) plus the companion APK
mirror (~3 MB, best-effort). 50 MB recommended leaves headroom
for `txn-*` staging during an install.

### 1.2 What does NOT work with it

- **VPN apps** — the VPN tunnels all traffic through its own
  resolver, bypassing the module.
- **AdAway** — both redirect port 53, causing conflicts.
- **SuperSU** / **KingRoot** — legacy / untrusted root solutions.
- **Android 4.x** — not supported.

### 1.3 Verify your device

```bash
# Root
su -c "id"
# → uid=0(root) gid=0(root)

# Android version
getprop ro.build.version.release
getprop ro.build.version.sdk

# Architecture
getprop ro.product.cpu.abi

# Root solution
su -c "magisk -V"   # or: ksud -V, apd --version
```

---

## 2. Install

### 2.1 Download

From [GitHub Releases](https://github.com/gasciljh/dnscrypt-proxy-webui/releases):

```bash
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest/download/dnscrypt-webui-1.6.0-module.zip
```

The release has 8 assets (2 optional):

| Asset | Required | Purpose |
|---|:---:|---|
| `dnscrypt-webui-1.6.0-module.zip` | ✅ | The module |
| `dnscrypt-webui-1.6.0-module.zip.sha256` | ✅ | Integrity |
| `dnscrypt-webui-{arm64,arm,amd64,386}` | ✅ | Standalone binaries |
| `DNS-Proxy-v1.0.0.apk` + `.sha256` | Optional | Companion app |

**No GPG signing** as of v1.6.0. The `.sha256` file is the only
integrity artifact. See `docs/REFERENCE.md` §3 for details.

### 2.2 Verify SHA-256

```bash
sha256sum -c dnscrypt-webui-1.6.0-module.zip.sha256
# → OK
```

On macOS: use `shasum -a 256` instead.

### 2.3 Install via Magisk / KernelSU / APatch

The procedure is identical for all three. Only the manager UI
differs:

| Manager | Path |
|---|---|
| **Magisk** | Modules → Install from storage → select ZIP → OK |
| **KernelSU** | Modules → Install → select ZIP → Confirm |
| **APatch** | Modules → Install → select ZIP → Confirm |

### 2.4 What happens during install

The installer runs 10 defensive layers plus the v1.5.0/v1.6.0 additions:

1. Detects architecture + existing module.
2. Searches 7 locations for user data (Layer 1).
3. Kills any running `dnscrypt-proxy` / `dnscrypt-webui`.
4. Cleans firewall rules (Custom Chains + legacy).
5. Begins a transaction (`txn-*`, state=START) (Layer 4).
6. Snapshots user data to `/sdcard/` (Layer 2).
7. Writes `.manifest.json` with per-file SHA256 (Layer 3).
8. Extracts module files (including `boot-mini.sh`,
   `lib/*.sh` (6 modules, v1.6.0), and `install_app.sh`).
9. Mirrors the companion APK to
   `/sdcard/dnscrypt-webui-backup/apk/` (v1.5.0, best-effort).
10. Restores user data with SELinux contexts (Layer 6).
11. Verifies critical files (v1.6.0 includes all 6 `lib/*.sh`
    modules and `install_app.sh`; a missing file triggers rollback).
12. Applies config migrations (Layer 8).
13. Commits the transaction.

**On any failure before step 13**: automatic rollback. The
`txn-*` directory is preserved as `orphan-txn-*` for inspection.

### 2.5 Expected install screen (abbreviated)

```text
╔══════════════════════════════════════╗
║  ✅ Installation Complete            ║
║      v1.6.0                          ║
╚══════════════════════════════════════╝

  📊 Upgrade: YES
  🔍 Source: /data/adb/modules/dnscrypt-proxy-webui/proxy
  📦 Root: Magisk
  🌐 WebUI: http://127.0.0.1:9090
  📈 Dashboard: http://127.0.0.1:9091
  🔌 Bind: 127.0.0.1
  🧠 Memory: ~120 MB (pro)
  💾 Backup: 20261112-120000-v1.6.0-12345
     Last stable: 20261112-120000-v1.6.0-12345
  📱 APK mirror: /sdcard/dnscrypt-webui-backup/apk
  🔐 SHA256: present

  ℹ️  Next steps:
    1. Reboot your device
    2. Open WebUI and log in with the credentials above
    3. Choose a blocklist profile and Apply
```

**Copy the credentials** printed above — you will need them in
§3.2.

### 2.6 Common warnings

| Warning | Meaning | Action |
|---|---|---|
| `Port collision resolved` | `PORT` and `DASHBOARD_PORT` were equal; auto-fixed | None |
| `Failed to create backup dir (continuing)` | `/sdcard` not writable | Reboot |
| `Companion APK mirror skipped` | APK absent or `/sdcard` full | None (optional feature) |
| `Missing critical files: boot-mini.sh` | Corrupt ZIP | Re-download + verify |
| `CRITICAL: lib/ directory not found` | Corrupt ZIP or missing `lib/` | Re-download + verify |
| `Missing critical files: install_app.sh` | Corrupt ZIP | Re-download + verify |
| `🛑 You MUST REBOOT NOW` | Old processes were killed | Reboot |

**Note**: If `PORT` was set to `8080` (reserved), the installer
silently replaces it with `9090` during the `webui.conf` write step.
There is no explicit warning for this specific case.

### 2.7 Reboot

```bash
su -c "reboot"
```

Reboot is **mandatory** after install — the DNS engine cannot
start without it.

---

## 3. First-Time Setup

### 3.1 Open the WebUI

Two ways:
- **From Magisk**: Modules → DNSCrypt Proxy → **Action** button.
- **From browser**: Navigate to `http://127.0.0.1:9090`.

### 3.2 Login

Use the credentials printed during install, or:

```bash
su -c "cat /data/local/tmp/dnscrypt_credentials.txt"
```

Or read them directly from the TOML (safer, avoids comments):

```bash
su -c "grep -E '^[[:space:]]*(username|password)[[:space:]]*=' \
    /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml"
```

Values are between single quotes — do **not** copy the quotes.

### 3.3 Choose a blocklist profile

In the WebUI → **📝 Select Blocklist** → choose:

| Profile | Entries | WebUI memory limit | Recommended for |
|---|---:|---:|---|
| Light | 40K | 80 MB | 1 GB RAM devices |
| Normal | 120K | 100 MB | 2 GB RAM |
| **PRO** (default) | 250K | 120 MB | 3 GB RAM |
| PRO++ | 350K | 160 MB | 4 GB RAM |
| Ultimate | 500K | 220 MB | 6 GB+ RAM |

Press **Apply**. Download takes 30 s – 5 min depending on the
list and network.

### 3.4 Optional: custom rules

Two lists in the WebUI:
- **Allowlist** — exceptions (domains that bypass blocking).
- **Denylist** — extra blocking.

Wildcards supported: `*.example.com`.

A pre-critical backup is created before each save.

### 3.5 Optional: PWA

To install the **WebUI itself** as a PWA:
1. Open Chrome at `http://127.0.0.1:9090`.
2. Chrome menu → **Install app** or **Add to Home screen**.

### 3.6 Optional: companion Android app

See §9 below.

### 3.7 Verify everything works

```bash
# Service status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"

# DNS query test
su -c "nslookup google.com 127.0.0.1"

# Health check
su -c "curl -s http://127.0.0.1:9090/healthz"
# → ok
```

**v1.6.0 — Local timezone check**: after login, the WebUI's
"Last update:" field should match your **device clock** (not UTC).
If you upgraded from v1.5.0, force-refresh the WebUI
(Ctrl+Shift+R, or the 🔄 Force Refresh button) to load the new
JavaScript.

---

## 4. Daily Use

### 4.1 Start / stop the service

From the WebUI:
- **▶️ Start Service** — starts the DNS engine.
- **⏹️ Stop Service** — stops it.

Or via CLI:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

The **watchdog** restarts the DNS engine automatically if it
crashes — but only if you have not manually stopped it (user
intent is tracked in `dnscrypt.status`).

### 4.2 Dashboard

Open `http://127.0.0.1:9091` for:
- Live query statistics.
- Cache performance.
- Resolver health.
- Top domains.
- Recent queries.

**Note**: `top_domains` and `recent_queries` require the query log,
which is **enabled by default** in `dnscrypt-proxy.toml`
(`enable_query_log = true`, `privacy_level = 1`). If you previously
disabled it, restore those lines and restart the service.

### 4.3 Update the blocklist

The blocklist is **not** re-downloaded automatically. It is fetched
from the internet only when you press **Apply** in the WebUI
(which sends `POST /api/update_profile`).

To check whether a newer list exists without applying it, press
the **🔄 Update Current Lists** button — this only queries the
upstream version, it does not download.

The `24h` interval mentioned in some backup settings applies to
**backup rotation**, not blocklist refresh.

### 4.4 Language toggle

The WebUI ships bilingual (English default + Arabic). Click the
**🇸🇦 العربية** button in the header. Preference persists in
browser `localStorage`.

**v1.6.0 — timezone-aware rendering**: the "Last update:"
timestamp now respects the device's local timezone in **both**
languages. In Arabic (`ar-EG`), it uses Arabic numerals; in
English (`en-US`), it uses Latin digits. Both reflect your
device's clock.

---

## 5. Update

### 5.1 Automatic

If `update.json` is configured in `module.prop` (it is by
default):
1. Magisk Manager → Settings → Update channel → **Custom**.
2. Magisk shows a notification when a new version is available.

### 5.2 Manual

1. Download the new ZIP from GitHub Releases.
2. Verify the SHA-256 (§2.2).
3. Install over the old one via Magisk / KernelSU / APatch.
4. Reboot.

### 5.3 What is preserved

The **5 user config files** survive every update:

| File | Purpose |
|---|---|
| `webui.conf` | Ports, `BIND_ADDR`, `LOG_LEVEL` |
| `dnscrypt-proxy.toml` | DNSCrypt config + credentials |
| `selected_profile.txt` | Active profile |
| `allowlist.txt` | Custom allowlist |
| `denylist.txt` | Custom denylist |

**Not preserved** (rebuilt or re-downloaded):
- `blocklist.txt` — rebuilt from `blocklist.raw`.
- `blocklist.raw` — downloaded from the internet.
- `run/` directory — recreated.
- Logs — rotated.
- `lib/*.sh` — reinstalled from the new ZIP (v1.6.0).

**Not affected by updates**:
- The WebUI language preference (client-side).
- The companion app if separately installed.
- The PWA cache — **may trigger an "Update available" banner**;
  click **Reload** to apply.

### 5.4 Verify after update

```bash
# Version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# → version=v1.6.0

# Services
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# → DNS=UP | WEBUI=UP | ...

# No firewall orphans
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# → 0

# Config preserved
su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# → PORT=9090 (or your custom value)

# v1.6.0 — modular lib/ present
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/lib/*.sh | wc -l"
# → 6 (constants, fallbacks, process, http, backup, firewall)

# v1.6.0 — local timezone fix active
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=get_profile | \
    jq '{last_update, last_update_unix}'
# → Both fields present; last_update_unix is an integer
```

### 5.5 If the update fails

If the installer detects a critical-file failure, it triggers an
**automatic rollback** and aborts. Your previous version remains
functional. See `dnscrypt_install.log`:

```bash
su -c "grep -iE 'error|fail|abort' \
    /data/local/tmp/dnscrypt_install.log | tail -20"
```

Common causes:
- Corrupt ZIP (re-download + verify SHA-256).
- Insufficient disk space.
- ZIP from an old release (missing v1.6.0 `lib/*.sh` files).

---

## 6. Uninstall

### 6.1 Automatic

- **Magisk**: Modules → DNSCrypt Proxy → 🗑️ (Remove) → Reboot.
- **KernelSU**: Modules → Uninstall → Reboot.
- **APatch**: Modules → Uninstall → Reboot.

### 6.2 What happens

`uninstall.sh` runs:
1. Kills all processes (`dnscrypt-proxy`, `dnscrypt-webui`).
2. Cleans firewall rules (Custom Chains + legacy).
3. Resets `private_dns_mode` to AUTO.
4. Restores the original `route_localnet` value.
5. Removes runtime files from `/data/local/tmp/`.
6. Removes module config files.
7. **Preserves the backup directory** at
   `/sdcard/dnscrypt-webui-backup/` (so a future reinstall can
   restore your settings).
8. **Preserves the `apk/` mirror** (v1.5.0).
9. Removes `txn-*` with state COMMIT or ROLLBACK.
10. Renames `txn-*` with state START to `orphan-txn-*` (preserved).
11. Removes the recovery trigger (if any).

**v1.6.0 note**: The `lib/*.sh` directory (Layer 0) is inside
the module folder and is removed with the module. Your 5 config
files are unaffected.

### 6.3 What is preserved

| Item | Preserved? |
|---|:---:|
| `/sdcard/dnscrypt-webui-backup/` (all snapshots) | ✅ |
| `current/` live snapshot | ✅ |
| `orphan-txn-*/` | ✅ |
| `apk/` mirror (v1.5.0) | ✅ |
| `.last_stable` pointer | ✅ |
| `.upgrade_history.json` | ✅ |
| Companion app (if installed separately) | ✅ (untouched) |

To remove everything manually:

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

### 6.4 Manual removal (if uninstall fails)

```bash
su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
su -c "rm -rf /data/local/tmp/dnscrypt*"

# Firewall cleanup
su -c "iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -F DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -X DNSCRYPT_OUT 2>/dev/null"

su -c "ip6tables -t nat -F DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -X DNSCRYPT_OUT6 2>/dev/null"

# DNS reset
su -c "settings delete global private_dns_mode"
su -c "ndc resolver flushdefaultif"

# Reboot
su -c "reboot"
```

---

## 7. Troubleshooting

### 7.1 Diagnose first

Before doing anything, run:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

This produces a full report (system info, service status, user
data files, backup state, health checks, diagnosis).

For bug reports, also collect:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" \
    > /sdcard/diagnose.json
su -c "tail -200 /data/local/tmp/dnscrypt_main.log" \
    > /sdcard/logs.txt
```

### 7.2 Decision tree

```text
Problem?
│
├── Cannot install → §7.3
├── Cannot open WebUI → §7.4
├── Cannot log in → §7.5
├── DNS not working → §7.6
├── Some sites not blocked → §7.7
├── Battery drains → §7.8
├── Companion app won't install → §7.9
├── Timezone wrong / not updating → §7.11
└── Nothing else → §8 (Emergency)
```

### 7.3 Cannot install

| Symptom | Cause | Fix |
|---|---|---|
| `Please install via Magisk` | Manual install | Use Magisk/KernelSU |
| `SECURITY: MODPATH outside /data/adb` | Unsafe path | Reinstall via root manager |
| `Required tool 'X' not found` | Missing busybox | Use a ROM with busybox |
| `Failed to extract module files` | Corrupt ZIP / disk full | Re-download + verify SHA; free space |
| `Missing critical files: boot-mini.sh` | Corrupt ZIP | Re-download + verify SHA |
| `CRITICAL: lib/ directory not found` | Corrupt ZIP or missing `lib/` | Re-download + verify SHA (v1.6.0) |
| `Missing critical files: lib/constants.sh` | ZIP had `lib/` but missing a file | Re-download + verify SHA (v1.6.0) |
| `Missing critical files: install_app.sh` | Corrupt ZIP | Re-download + verify SHA |
| `DNS binary missing for <arch>` | Unsupported ABI | Check `getprop ro.product.cpu.abi` |
| `Port collision resolved` | `PORT` == `DASHBOARD_PORT` | None — expected |

### 7.4 Cannot open WebUI

**Loop**:

```bash
# 1. Is the process running?
su -c "pgrep -x dnscrypt-webui"

# 2. Is the port open?
su -c "ss -ltn | grep 9090"

# 3. If not, start it
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh"

# 4. Check the log
su -c "tail -50 /data/local/tmp/dnscrypt_main.log"
```

| Symptom | Cause | Fix |
|---|---|---|
| Port 9090 used by another app | Port collision | Change `PORT` in `webui.conf`, restart |
| `Connection refused` with `BIND_ADDR=0.0.0.0` | Credentials missing | Reinstall (regenerates credentials) |
| Blank page | Missing web assets | Reinstall the module |
| `404` on icons | Missing assets | Reinstall the module |

### 7.5 Cannot log in

| Symptom | Cause | Fix |
|---|---|---|
| `Invalid credentials` | Wrong password | See §3.2 for how to retrieve |
| `Too many attempts` | Rate limited | Wait 15 min or restart WebUI |
| `Session expired` frequently | Bad system time | Set automatic time |
| Credentials change not applied | 60 s cache | Restart WebUI |

### 7.6 DNS not working

**Loop**:

```bash
# 1. DNS engine running?
su -c "pgrep -x dnscrypt-proxy"

# 2. Port 5354/udp open?
su -c "ss -uln | grep 5354"

# 3. Firewall redirect present?
su -c "iptables -t nat -L DNSCRYPT_OUT -n"

# 4. Query works?
su -c "nslookup google.com 127.0.0.1"
```

| Symptom | Cause | Fix |
|---|---|---|
| DNS engine stopped | Crashed, watchdog waiting | `action.sh --restart` |
| Firewall missing | Rules dropped | `su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 1"` |
| Wrong binary | Architecture mismatch | `getprop ro.product.cpu.abi` |
| SELinux blocking | Rare | `restorecon -R module/` |

### 7.7 Some sites not blocked

| Site | Reason | Solution |
|---|---|---|
| **YouTube ads** | Same domain as content | Use YouTube ReVanced or a browser with AdBlock |
| **Facebook/Instagram in-feed** | Same domain as posts | DNS cannot distinguish |
| **Any app using its own DoH** | Hardcoded DNS | Not blockable via DNS |
| **A specific domain** | Not in blocklist | Add to **Denylist** in the WebUI |
| **Cached DNS** | Old resolution | Restart browser/device |

### 7.8 Battery drains

- **Cause**: Usually the `ultimate` profile on a low-RAM device.
- **Fix**: Use `light` / `normal` / `pro` instead.
- **Cause**: Watchdog loop on a repeatedly-failing service.
- **Fix**: Set `AUTO_RESTART_DNS=0` in `webui.conf`, restart.

### 7.9 Companion app won't install

See §9.4 for the full list of cascade failure modes.

Quick reference:

| Symptom | Cause | Fix |
|---|---|---|
| Modal does not open | Service Worker stale | Clear site data in DevTools |
| `Failed to get install token` | Token expired | Retry — reopen the modal |
| `Too many install attempts` | Rate limited | Wait 15 min or restart WebUI |
| `All install strategies failed` | ROM-specific block | Check modal's hint (§9.4) |
| `APK not found` | Dev build without APK | Use GitHub fallback |

### 7.10 Collect diagnostics for a bug report

```bash
# Full diagnostic
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" \
    > /sdcard/diagnose.txt 2>&1

# JSON state
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" \
    > /sdcard/diagnose.json 2>&1

# Logs
su -c "tail -200 /data/local/tmp/dnscrypt_main.log" \
    > /sdcard/logs.txt 2>&1
```

Attach `diagnose.txt` + `diagnose.json` + `logs.txt` to the issue
at [github.com/gasciljh/dnscrypt-proxy-webui/issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues).

### 7.11 Timezone wrong / not updating (v1.6.0)

**Symptoms**:
- The WebUI still shows UTC (e.g., `04:03:46` instead of `07:03:46`).
- The timestamp does not change after changing device timezone.
- The timestamp shows `null` or `undefined`.

**Cause & Fix**:

| Symptom | Cause | Fix |
|---|---|---|
| Shows old UTC time | Stale `index.html` from PWA cache | Force-refresh (Ctrl+Shift+R) or click **🔄 Force Refresh** in the WebUI. Or: DevTools → Application → Storage → Clear site data → reload. |
| Timestamp is `null` | Backend did not return `last_update_unix` (mixed-version upgrade) | Verify module version is `v1.6.0`: `grep '^version=' $MODDIR/module.prop`. If older, reinstall the v1.6.0 ZIP. |
| Wrong timezone displayed | Browser is using a cached `Intl` locale | Hard-reload the page. If persists, clear browser cache for `127.0.0.1:9090`. |
| Timestamp format odd in Arabic | Browser lacks `ar-EG` locale data | Update Chrome/Firefox to a recent version. |

**Verification**:

```bash
# 1. Backend returns both fields
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=get_profile | \
    jq '{last_update, last_update_unix}'

# Expected: both fields present; last_update_unix is a large integer.

# 2. Unix timestamp converts to expected local time
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=get_profile | \
    jq -r '.last_update_unix' | xargs -I {} date -d @{}

# 3. Compare with device clock
date
# Both should match (same timezone).
```

---

## 8. Emergency Recovery

### 8.1 Bootloop

**Method A — Recovery**:

```bash
# In TWRP recovery
adb shell
mount /data
rm -rf /data/adb/modules/dnscrypt-proxy-webui
reboot
```

**Method B — Safe Mode**:
- Reboot holding Volume Down until the lock screen appears.
- Open Magisk Manager → Modules → disable/remove DNSCrypt.
- Reboot normally.

**Method C — ADB**:

```bash
adb shell su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
adb reboot
```

**Method D — Disable only**:

```bash
adb shell su -c "touch /data/adb/modules/dnscrypt-proxy-webui/disable"
adb reboot
```

### 8.2 User data lost after upgrade

If `webui.conf`, `allowlist.txt`, etc. reset to defaults:

```bash
# 1. Check what's available
su -c "ls -la /sdcard/dnscrypt-webui-backup/"

# 2. Find the newest snapshot (function is defined in lib/backup.sh §[5])
SNAP=$(su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; list_snapshots 1" | tr -d '\r')

# 3. Restore the 5 files
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt \
         allowlist.txt denylist.txt; do
    su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/$f /data/adb/modules/dnscrypt-proxy-webui/proxy/"
done

# 4. Fix SELinux contexts
su -c "restorecon /data/adb/modules/dnscrypt-proxy-webui/proxy/"

# 5. Restart
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**If no backup exists**: check `orphan-txn-*/` (see §8.6), then
`/data/local/tmp/`, then the last-chance manual backup.

### 8.3 DNS completely broken

```bash
# 1. Full restart
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 2. If still broken, firewall reset
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 0"
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 1"

# 3. Restart again
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 8.4 WebUI unreachable

```bash
# 1. Kill any zombie process
su -c "pkill -9 -x dnscrypt-webui"

# 2. Clear the PID file
su -c "rm -f /data/adb/modules/dnscrypt-proxy-webui/proxy/run/webui.pid"

# 3. Start again
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh"

# 4. If it still fails, run manually to see errors
su -c "cd /data/adb/modules/dnscrypt-proxy-webui/proxy && \
    HOME=/data/local/tmp ./dnscrypt-webui"
```

### 8.5 Firewall rules broken

```bash
# Full reset
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 0"
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 1"

# Verify
su -c "iptables -t nat -L DNSCRYPT_OUT -n"
```

If `functions.sh` is broken, manual cleanup:

```bash
su -c "iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -F DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -X DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -F OUTPUT"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 8.6 Recovery mode (one-command)

**Use when**: the module is unbootable but you can run ADB.

**Procedure**:

```bash
# 1. Create trigger (module-specific)
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"

# OR (survives module folder loss)
su -c "touch /data/adb/dnscrypt-recovery"

# 2. Reboot
su -c "reboot"

# 3. Wait for boot (~60s), then verify
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

**Recovery source priority**:
1. `.last_stable` pointer.
2. `current/` live snapshot.
3. In-place `proxy/` directory.

**v1.3.0+**: The `.last_stable` target is protected from rotation
(ROT-PROTECT), so recovery mode is significantly more reliable.

### 8.7 Corrupted backup directory

```bash
# 1. Check permissions
su -c "stat -c '%a %U:%G %n' /sdcard/dnscrypt-webui-backup/"

# 2. Fix if wrong
su -c "chmod 0700 /sdcard/dnscrypt-webui-backup"
su -c "chown root:root /sdcard/dnscrypt-webui-backup"

# 3. Check for missing manifests
for d in /sdcard/dnscrypt-webui-backup/*/; do
    name=$(basename "$d")
    case "$name" in
        current|txn-*|orphan-txn-*|apk) continue ;;
    esac
    [ -f "$d/.manifest.json" ] || echo "⚠️ $name missing manifest"
done

# 4. If unrecoverable, start fresh
su -c "mv /sdcard/dnscrypt-webui-backup \
    /sdcard/dnscrypt-webui-backup.broken-$(date +%Y%m%d)"
su -c "reboot"
```

---

## 9. Companion Android App

**Optional** (since v1.4.0). A ~3 MB native Android app that
opens the WebUI in a WebView wrapper.

### 9.1 What it is

| Attribute | Value |
|---|---|
| Size | ~3 MB |
| Stack | Kotlin + WebView |
| Min Android | 5.0 (API 21) |
| Telemetry | None |
| Source | [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) |
| Version | Pinned in `proxy/app-apk.version` |

### 9.2 Install via WebUI

Click **📲 Install App** in the WebUI header. A modal opens with
**three actions across two categories**:

| Category | Action | What it does |
|---|---|---|
| **Local** | Install locally (root) | 5-level `pm install` cascade |
| **GitHub** | Open GitHub page | Opens companion repo in browser |
| **GitHub** | Direct download | Opens APK download URL |

**Requirements for the local path**:
- Root.
- APK present in the module ZIP.
- Access via `127.0.0.1` (localhost-only).
- Valid CSRF token (60 s TTL).
- Not rate-limited (5 / 15 min).

### 9.3 The 5-level cascade

| Level | Command |
|:-:|---|
| 1 | `pm install -r --user 0 <apk>` |
| 2 | `pm install -r --user 0 -i com.android.shell <apk>` |
| 3 | Session-based (`install-create` + `install-write` + `install-commit`) |
| 4 | `magisk su -c "pm install -r <apk>"` (Magisk only) |
| 5 | `cmd package install -r <apk>` (Android 8.0+) |

First success wins. Bounded by a 75-second deadline.

### 9.4 Failure modes

| `message_en` in modal | Cause | Fix |
|---|---|---|
| `MIUI/HyperOS blocked the install` | `INSTALL_FAILED_USER_RESTRICTED` | Settings → Dev options → Install via USB |
| `Play Protect blocked the app` | `INSTALL_FAILED_VERIFICATION_FAILURE` | Disable Play Protect temporarily |
| `Installed app version is newer` | `INSTALL_FAILED_VERSION_DOWNGRADE` | Uninstall current version |
| `Insufficient storage` | `INSTALL_FAILED_INSUFFICIENT_STORAGE` | Free up space |
| `Different signature` | `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Uninstall manually |
| `App is already installed` | `INSTALL_FAILED_ALREADY_EXISTS` | Uninstall current version, or use **Update App** |
| `APK corrupt` | `INSTALL_PARSE_FAILED_NO_CERTIFICATES` | Reinstall module |
| `Internal error` | `INSTALL_FAILED_INTERNAL_ERROR` | Reboot, retry |

**Always available**: the modal's **⬇️ Download manually** button,
or open `http://127.0.0.1:9090/app-debug.apk` in a browser.

### 9.5 Uninstall the companion app

Standard Android uninstall:
- Long-press the **DNS Proxy** icon → **Uninstall**.
- Or: Settings → Apps → DNS Proxy → Uninstall.
- Or: `adb uninstall com.gasciljh.dnsproxy.debug`.

**The module is not affected.**

---

## 10. FAQ

### 10.1 General

**Q: Do I need root?**
A: Yes. Root is required for `iptables`, `private_dns_mode`, and
running the DNS engine as a system service.

**Q: Is it open source?**
A: Yes, MIT license. https://github.com/gasciljh/dnscrypt-proxy-webui

**Q: Is it free?**
A: Yes. No paid version, no tracking, no ads.

**Q: Does it work offline?**
A: Yes. Blocklists are downloaded once and applied locally.
Internet is only needed to (a) download new lists and (b) reach
DNSCrypt servers.

**Q: What is "Zero Telemetry"?**
A: The project does not connect to any analytics server. All
outbound connections are limited to DNSCrypt servers and
blocklist sources.

### 10.2 Installation

**Q: Can I use it with AdAway?**
A: No — conflict on port 53. Use one or the other.

**Q: Can I use it with a VPN?**
A: No — VPN apps bypass DNS redirect. Use one or the other.

**Q: Will it survive an OTA?**
A: No. Android OTA typically removes the module — you must
reinstall it after the OTA. Your config survives (in `/sdcard/`).

**Q: Does it work on Android 14/15?**
A: Yes — the module supports Android 5.0 through 15.

### 10.3 Usage

**Q: Why do YouTube ads still appear?**
A: Ads come from `googlevideo.com`, the same domain as video
content. Blocking that domain would break YouTube. Use ReVanced
or a browser AdBlock.

**Q: Why do Facebook/Instagram in-feed ads still appear?**
A: Same reason — in-feed ads are served from the same domain as
posts. DNS cannot distinguish them.

**Q: Can I block a specific domain?**
A: Yes — add it to the **Denylist** in the WebUI.

**Q: How do I exclude a site from blocking?**
A: Add it to the **Allowlist**. Wildcards supported.

**Q: How do I change the WebUI port?**
A: Edit `webui.conf` → `PORT=9191` → restart. Do NOT use 8080
(reserved for monitoring_ui).

### 10.4 Security

**Q: Is my data safe?**
A: Yes. All processing is local. Zero telemetry. Credentials
have high entropy. The backup directory is `0700` root-owned.

**Q: What is `BIND_ADDR`?**
A: The listening address. Default `127.0.0.1` (local only).
Setting `0.0.0.0` requires strong credentials — the module
refuses to start without them.

**Q: Can a malicious app steal my data?**
A: Difficult. The WebUI is localhost-only, has rate limits, and
enforces POST-only login. Only an app with full root can read
the module data.

### 10.5 Updates

**Q: Are settings lost on upgrade?**
A: No. Since v1.2.0, the 5 user config files are preserved
automatically.

**Q: How do I copy settings to another device?**
A:
```bash
adb pull /sdcard/dnscrypt-webui-backup/ ./my-backup/
# On the new device:
adb push ./my-backup/ /sdcard/dnscrypt-webui-backup/
# Then install the module — it auto-restores.
```

**Q: How do I roll back?**
A: Download the previous version's ZIP, install over the current
one, reboot. Data is preserved.

### 10.6 v1.6.0-specific

**Q: Why does "Last update:" now show a different time?**
A: v1.6.0 changed the display from **UTC** to your **device's
local timezone**. If you were used to seeing `04:03:46`, you will
now see `07:03:46` (or your local equivalent). This is the
correct time. See §7.11 if it does not work.

**Q: What is the `lib/` directory?**
A: `lib/` is a new folder (v1.6.0) that holds 6 single-purpose
shell modules: `constants.sh`, `fallbacks.sh`, `process.sh`,
`http.sh`, `backup.sh`, `firewall.sh`. It is part of the
module's internal architecture and is removed when you uninstall.
It does not affect your configuration.

**Q: The PWA shows "Update available" — what do I do?**
A: Click **Reload** in the banner. v1.6.0 bumped the PWA cache
version, so existing installs must reload to see the new
timezone fix and other UI changes.

**Q: Do I need to do anything different to upgrade from v1.5.0?**
A: No. The standard upgrade (§5) works. Just remember to
force-refresh the WebUI after the reboot if you want to see the
timezone fix.

---

## 11. Reference

### 11.1 Ports

| Port | Service | Protocol |
|---:|---|---|
| 9090 | WebUI | HTTP |
| 9091 | Dashboard | HTTP |
| 5354 | DNS engine | UDP + TCP |
| 8080 | monitoring_ui (internal) | HTTP |

### 11.2 Paths

| Path | Purpose |
|---|---|
| `/data/adb/modules/dnscrypt-proxy-webui/` | Module root |
| `/data/adb/modules/dnscrypt-proxy-webui/lib/` | Shell modules (Layer 0, v1.6.0) |
| `/data/adb/modules/dnscrypt-proxy-webui/proxy/` | Config + binaries |
| `/data/adb/modules/dnscrypt-proxy-webui/proxy/run/` | Runtime state |
| `/data/adb/modules/dnscrypt-proxy-webui/web/` | Static assets |
| `/sdcard/dnscrypt-webui-backup/` | Persistent backups |
| `/data/local/tmp/dnscrypt_main.log` | WebUI + service log |
| `/data/local/tmp/dnscrypt-proxy.log` | DNS engine log |
| `/data/local/tmp/dnscrypt_credentials.txt` | Login credentials |

### 11.3 Essential commands

```bash
# Full diagnostic
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"

# One-line status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"

# Restart service
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# Manual backup
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"

# Check version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"

# Check backup state
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups'

# v1.6.0 — modular lib/ present
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/lib/*.sh | wc -l"
# → 6
```

### 11.4 Exit codes

`status.sh --check`:

| Code | Meaning |
|:---:|---|
| 0 | Everything running |
| 1 | Nothing running |
| 2 | Partial |
| 3 | Module disabled |

### 11.5 Version formula

```text
versionCode = MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100
```

| Version | versionCode |
|---|:---:|
| v1.0.0 | 1000000 |
| v1.5.0 | 1050000 |
| **v1.6.0 (current)** | **1060000** |
| v1.7.0 (planned) | 1070000 |
| v2.0.0 | 2000000 |

### 11.6 What's new in v1.6.0

If you are upgrading from v1.5.0, you will notice:

| Change | Impact |
|---|---|
| **Local timezone** | "Last update:" now matches your device clock (was UTC) |
| **Modular shell (`lib/`)** | New `lib/*.sh` directory — affects shell internals only; no user action needed |
| **PWA cache bump** | May see "Update available" banner on next visit — click **Reload** |
| **DNS version** | Bumped 2.1.18 → 2.1.20 (same engine, newer build) |
| **Version display** | Footers, badges, and `status.sh` all report `v1.6.0` |

**No action required** beyond the standard upgrade (§5).

### 11.7 What's not in this guide

- **Architecture, internals, design decisions** →
  `docs/REFERENCE.md` §1
- **Modular shell (`lib/`) details** → `docs/REFERENCE.md` §1.4
- **Local timezone fix internals** → `docs/REFERENCE.md` §3.10
- **HTTP API schema** → `docs/REFERENCE.md` §2
- **Backup system details (SNAP-*, ROT-*, transaction states)** →
  `docs/REFERENCE.md` §4
- **Developer setup, build, release process** →
  `docs/CONTRIBUTING.md`
- **Version history (v1.0.0 → v1.6.0)** → `CHANGELOG.md`
- **Security audit corrections** → `SECURITY.md` §15
- **Documentation map** → `docs/MAP.md`

---

**Footer**

**Version**: v1.6.0 (Global Edition)
**Last updated**: 2026-11-13
**Author**: gasciljh

For bug reports: [github.com/gasciljh/dnscrypt-proxy-webui/issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues)
For security reports: see `SECURITY.md` §1 — do **not** open a public issue.