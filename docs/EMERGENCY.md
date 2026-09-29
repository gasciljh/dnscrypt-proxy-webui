# Emergency Recovery Guide — DNSCrypt Smart Filter

Step-by-step procedures for recovering from catastrophic failures.

**Version**: v1.2.0
**Last updated**: 2026-09-29
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **📖 Related documents**:
> - Backup system reference → [`BACKUP.md`](BACKUP.md)
> - Upgrade guide → [`UPGRADE.md`](UPGRADE.md)
> - Troubleshooting → [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)
> - Security model → [`SECURITY.md`](SECURITY.md) §5.31, §5.32
> - Architecture → [`ARCHITECTURE.md`](ARCHITECTURE.md) §3.10, §4.10
> - Changelog → [`../CHANGELOG.md`](../CHANGELOG.md) §[v1.2.0]

> **v1.2.0 changes**:
>   • Version bumped from v1.0.0 to v1.2.0.
>   • **Global edition — English default + Arabic toggle** — the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) to switch to Arabic. The user's
>     choice is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention.
>   • **§9.6 (corrected in this revision)** — Recovery-mode
>     correctness note. Documents the v1.2.0 fix to the
>     `§[8a] → §[9] → §[9b2]` interaction that would have silently
>     overwritten 2 of 5 restored files. The implementation uses a
>     **snapshot-and-reapply** strategy, not a "reorder + exclude"
>     strategy. See `SECURITY.md` §5.32 for the full analysis and
>     `ARCHITECTURE.md` §3.10 for the flow diagram.
>   • **§3.5 (new)** — `backupMu` concurrency note. Explains why
>     rapid repeated API calls cannot corrupt a snapshot.
>   • **§5.5 (new)** — Full pre-flight checklist before testing
>     any recovery procedure on a device.
>   • **§5.10 (new)** — v1.2.0 language preference note. Explains
>     that the WebUI language choice survives all recovery paths
>     because it lives in the browser, not on the device.
>   • **§11 (extended)** — Emergency reference card now includes
>     the 7-field `runtime_info.backups` object and
>     `status.sh --diagnose` in the quick-command list.
>   • All commands updated to match v1.2.0 file paths and
>     behavior (`/sdcard/dnscrypt-webui-backup/`, recovery
>     triggers, orphan transaction handling).
>   • Cross-references updated to point at the corrected
>     sections in `BACKUP.md` §12.5, `ARCHITECTURE.md` §3.10,
>     and `SECURITY.md` §5.31, §5.32.
>   • **Encoding correction (this revision)**: fixed mojibake in
>     section markers, arrows, checkmarks, warnings, and box
>     drawing characters. All symbols now render as proper UTF-8.

---

## Table of Contents

1. [When to Use This Guide](#1-when-to-use-this-guide)
2. [Emergency Triage — Find the Right Scenario](#2-emergency-triage--find-the-right-scenario)
3. [Scenario 1: Module Bootloop](#3-scenario-1-module-bootloop)
4. [Scenario 2: User Data Lost After Upgrade](#4-scenario-2-user-data-lost-after-upgrade)
5. [Scenario 3: DNS Not Working After Install](#5-scenario-3-dns-not-working-after-install)
6. [Scenario 4: WebUI Unreachable](#6-scenario-4-webui-unreachable)
7. [Scenario 5: Firewall Rules Broken](#7-scenario-5-firewall-rules-broken)
8. [Scenario 6: Corrupted Backup Directory](#8-scenario-6-corrupted-backup-directory)
9. [Recovery Mode (One-Command Fix)](#9-recovery-mode-one-command-fix)
10. [Last-Resort Recovery (No Backups)](#10-last-resort-recovery-no-backups)
11. [Emergency Reference Card](#11-emergency-reference-card)
12. [References](#12-references)

---

## 1. When to Use This Guide

### 1.1 Scenarios covered

This guide covers the **catastrophic** scenarios where normal
operation is impossible:

| Symptom | Scenario |
|---------|:--------:|
| Device boots but the module keeps restarting things | §3 |
| Config files disappeared after an upgrade | §4 |
| DNS is completely broken after install | §5 |
| WebUI does not respond at all | §6 |
| Firewall rules are in an inconsistent state | §7 |
| The backup directory itself is damaged | §8 |
| The module cannot be reached via the WebUI | §9 |
| Nothing else works | §10 |

### 1.2 Prerequisites

Before using this guide, ensure you have:

- ✅ **A rooted device** (Magisk / KernelSU / APatch).
- ✅ **A terminal app** (Termux, Material Terminal) OR **ADB**.
- ✅ **A file manager with root access** (MiXplorer, MT Manager) — optional.
- ✅ **The user data location** from [`BACKUP.md`](BACKUP.md) §3.

### 1.3 The golden rule

> **Do not delete anything until you have inspected it.**

The backup system preserves unfinished transactions (Layer 4). A
directory named `txn-*` or `orphan-txn-*` may contain the **only**
copy of your user data if an install was interrupted mid-flight.
Read it before deleting it.

### 1.4 What is preserved

**Before** any recovery, remember what the v1.2.0 backup system
protects (see [`BACKUP.md`](BACKUP.md) §2):

| File | Purpose |
|---|---|
| `webui.conf` | WebUI + Dashboard ports, `BIND_ADDR`, `LOG_LEVEL` |
| `dnscrypt-proxy.toml` | DNSCrypt engine config + credentials |
| `selected_profile.txt` | Active blocklist profile |
| `allowlist.txt` | User-defined allowlist |
| `denylist.txt` | User-defined denylist |

Everything else (`blocklist.txt`, binaries, logs, `run/`) is
rebuilt or re-downloaded.

**Not preserved** (and never affected by recovery):

- The WebUI's **language preference** (English default + Arabic
  toggle) — it lives in the browser's
  `localStorage['dnscrypt-lang']`, not on the device.
- The browser's cache.
- Any client-side UI state.

### 1.5 What recovery does NOT affect

| Item | Impact |
|---|---|
| The DNS binaries cache (`~/.cache/...`) | Not touched — this is a dev-machine artifact |
| The WebUI language preference (`localStorage`) | Not touched — client-side only |
| The `META-INF/` bootstrap | Not touched — read-only at install time |
| The Magisk/KernelSU module framework | Not touched |

---

## 2. Emergency Triage — Find the Right Scenario

### 2.1 Decision tree

```text
What is the symptom?
│
├── Device does not boot / module bootloop
│   └── §3 (Module Bootloop)
│
├── Device boots but config files are gone
│   └── §4 (User Data Lost After Upgrade)
│
├── DNS resolution completely broken
│   └── §5 (DNS Not Working After Install)
│
├── WebUI shows blank page or refuses connection
│   └── §6 (WebUI Unreachable)
│
├── iptables / nftables rules are inconsistent
│   └── §7 (Firewall Rules Broken)
│
├── /sdcard/dnscrypt-webui-backup/ is damaged
│   └── §8 (Corrupted Backup Directory)
│
├── Nothing above matched, but the module is misbehaving
│   └── §9 (Recovery Mode)
│
└── Nothing worked
    └── §10 (Last-Resort Recovery)
```

### 2.2 First-response commands

Run these first — they are **read-only** and safe:

```bash
# 1. Module version + state
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/module.prop"

# 2. Full diagnostic report
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"

# 3. Available backups (7-field object)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups'

# 4. In-place config files
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/*.conf \
       /data/adb/modules/dnscrypt-proxy-webui/proxy/*.toml \
       /data/adb/modules/dnscrypt-proxy-webui/proxy/*.txt"
```

Save the output to a file for reference:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" > /sdcard/diagnose-before-recovery.txt
```

### 2.3 The 7-field `backups` object

Every diagnostic in this guide starts with this object (from
`runtime_info` or `status.sh --json`). Understanding it is the
fastest way to identify the correct scenario:

| Field | Meaning | Action |
|---|---|---|
| `available` | Snapshot count | `0` → §4 or §10 |
| `in_flight_txn` | `txn-*` directories | `>0` → inspect with §3.5 |
| `orphan_txn` | `orphan-txn-*` directories | `>0` → inspect with §4.4 |
| `last_backup` | Timestamp of newest snapshot | `null` → no backups |
| `last_backup_name` | Directory name of newest snapshot | Use as `$SNAP` in §4.3 |
| `last_stable` | Content of `.last_stable` pointer | If missing, recovery uses `current/` |
| `path` | Backup root path | Always `/sdcard/dnscrypt-webui-backup` |

**Quick check:**

```bash
curl -s -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" \
  | jq '.backups'
```

**Equivalent shell-only check** (when the WebUI is unreachable):

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups'
```

---

## 3. Scenario 1: Module Bootloop

### 3.1 Symptoms

- Device does not reach the home screen.
- Device enters a bootloop after installing or updating the module.
- ADB is available but the system does not finish booting.

### 3.2 Root cause analysis

Bootloops are caused by one of:

1. **Post-fs-data.sh failure** — the early boot script errored.
2. **Module disabled mid-boot** — inconsistent `disable` file state.
3. **Corrupted mount** — `/data/adb/modules/dnscrypt-proxy-webui`
   became inaccessible.
4. **Interrupted install** — an upgrade was interrupted mid-flight.
5. **Recovery trigger left in place** — a `recovery` file exists
   and triggers a re-install loop.

### 3.3 Solution A — Recovery partition

Boot into recovery mode (TWRP or stock recovery):

```bash
# In recovery
adb shell
mount /data

# Inspect the module
ls -la /data/adb/modules/dnscrypt-proxy-webui/

# If the module is broken, remove it
rm -rf /data/adb/modules/dnscrypt-proxy-webui

# Or, safer: disable the module (keeps files)
touch /data/adb/modules/dnscrypt-proxy-webui/disable

# Reboot
reboot
```

### 3.4 Solution B — Safe Mode

Boot into **Safe Mode** (usually by holding Volume Down during boot):

1. Device boots into Safe Mode with all Magisk modules disabled.
2. Open Magisk Manager.
3. Go to **Modules** → find DNSCrypt Proxy → tap the **disable**
   toggle (or **remove** to uninstall).
4. Reboot normally.

### 3.5 Solution C — ADB (no recovery)

If the device has ADB enabled and boot completes partially:

```bash
adb wait-for-device
adb shell su -c "touch /data/adb/modules/dnscrypt-proxy-webui/disable"
adb reboot
```

The device will boot normally with the module disabled.

**Also check for a stuck recovery trigger:**

```bash
adb shell su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>/dev/null"
adb shell su -c "ls /data/adb/dnscrypt-recovery 2>/dev/null"
```

If either file exists and you did not create it, remove it:

```bash
adb shell su -c "rm -f /data/adb/modules/dnscrypt-proxy-webui/recovery"
adb shell su -c "rm -f /data/adb/dnscrypt-recovery"
```

### 3.6 Solution D — Magisk overlay (advanced)

If `/data/adb/modules/dnscrypt-proxy-webui` is corrupted:

```bash
# In recovery
mount /data

# Rename the module folder (Magisk will skip it)
mv /data/adb/modules/dnscrypt-proxy-webui \
   /data/adb/modules/dnscrypt-proxy-webui.broken

# Reboot
reboot
```

Then, after boot, inspect `.broken/` to recover any user data
(see §4).

### 3.7 Post-recovery

After the device boots:

1. **Inspect the backup directory**:
   ```bash
   su -c "ls -la /sdcard/dnscrypt-webui-backup/"
   ```

2. **Check for in-flight or orphan transactions**:
   ```bash
   su -c "ls -d /sdcard/dnscrypt-webui-backup/txn-* 2>/dev/null"
   su -c "ls -d /sdcard/dnscrypt-webui-backup/orphan-txn-* 2>/dev/null"
   su -c "cat /sdcard/dnscrypt-webui-backup/txn-*/.state 2>/dev/null"
   ```

   | State | Meaning | Action |
   |---|---|---|
   | `START` | Interrupted install | **Preserve** — may contain the only copy of user data |
   | `COMMIT` | Successful install, cleanup skipped | Safe to remove (main.go does this at startup) |
   | `ROLLBACK` | Rollback already applied | Safe to remove |

3. **If snapshots exist**, reinstall the module. The multi-source
   detection (Layer 1) will find the data and restore it
   automatically.

4. **If no snapshots exist**, the user data is likely lost — see
   §4.4.

---

## 4. Scenario 2: User Data Lost After Upgrade

### 4.1 Symptoms

- After upgrading the module, `webui.conf` is reset to defaults.
- `allowlist.txt` and `denylist.txt` are empty.
- `selected_profile.txt` shows `pro` (default) instead of the
  user's choice.
- `dnscrypt-proxy.toml` has new credentials.

### 4.2 Root cause

This is the **legacy bug** from v1.1.0 (§1.1 of
[`BACKUP.md`](BACKUP.md)). It should not occur in v1.2.0, but may
occur if:

- The upgrade skipped v1.2.0 entirely (direct v1.0.0 → future).
- The `/sdcard/` partition was full at install time.
- The user data was on a partition that is now unmounted.
- The user manually edited files in `/data/local/tmp/` and those
  were cleared on reboot.

### 4.3 Solution — Restore from persistent backup

**Step 1**: Verify backups exist:

```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
```

**Step 2**: Check the full backup state (7-field object):

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups'
```

**Step 3**: Find the newest snapshot:

```bash
SNAP=$(su -c "ls -1dt /sdcard/dnscrypt-webui-backup/*/ | \
       grep -vE '/(current|txn-|orphan-txn-)' | head -1" | tr -d '\r')
echo "Newest snapshot: $SNAP"
```

**Step 4**: Inspect it:

```bash
su -c "ls -la $SNAP"
su -c "cat $SNAP/.manifest.json"
```

**Step 5**: Copy the 5 files back:

```bash
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
    su -c "cp $SNAP/$f /data/adb/modules/dnscrypt-proxy-webui/proxy/"
done
```

**Step 6**: Fix SELinux contexts:

```bash
su -c "restorecon /data/adb/modules/dnscrypt-proxy-webui/proxy/"
```

**Step 7**: Restart the service:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Step 8**: Verify:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | \
    grep -A5 "User Data Files"
```

### 4.4 Solution — No backups available

If `/sdcard/dnscrypt-webui-backup/` is missing or empty:

**Step 1**: Search for orphan transactions:

```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/txn-* 2>/dev/null"
su -c "ls -la /sdcard/dnscrypt-webui-backup/orphan-txn-* 2>/dev/null"
```

For each orphan found, inspect its state:

```bash
su -c "cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.state"
```

**Step 2**: Search everywhere for the config files:

```bash
su -c "find /sdcard -iname 'allowlist.txt' -o -iname 'denylist.txt' 2>/dev/null"
su -c "find /data -iname 'webui.conf' 2>/dev/null"
```

**Step 3**: Search `/data/local/tmp/` (legacy location):

```bash
su -c "ls -la /data/local/tmp/dnscrypt* 2>/dev/null"
su -c "ls -la /data/local/tmp/dnscrypt-upgrade-backup-* 2>/dev/null"
```

**Step 4**: Search the module folder's rename variants:

```bash
su -c "ls -la /data/adb/modules/DNSCrypt-Proxy-Webui/proxy/ 2>/dev/null"
su -c "ls -la /data/adb/modules/DNSCrypt-Proxy-WebUI/proxy/ 2>/dev/null"
```

**Step 5**: If found, copy them back manually (same as §4.3
steps 5–8).

**Step 6**: If nothing is found, the data is lost. Proceed with a
fresh install (§10).

### 4.5 Orphan transaction handling

If an `orphan-txn-*` directory exists (created by `uninstall.sh`
renaming a `txn-*` with `.state=START`), it contains the state of
the module at the moment the install was interrupted. It is
**preserved on purpose**.

To inspect and (optionally) use it:

```bash
# 1. Inspect the orphan's state
cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.state

# 2. Inspect the orphan's contents
ls -la /sdcard/dnscrypt-webui-backup/orphan-txn-*/

# 3. If the files look correct, restore them manually
ORPHAN=$(ls -d /sdcard/dnscrypt-webui-backup/orphan-txn-* | head -1)
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
    [ -f "$ORPHAN/$f" ] && su -c "cp $ORPHAN/$f /data/adb/modules/dnscrypt-proxy-webui/proxy/"
done

# 4. Fix SELinux contexts
su -c "restorecon /data/adb/modules/dnscrypt-proxy-webui/proxy/"

# 5. Restart
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Do not delete the orphan** unless you are certain you no longer
need its contents.

### 4.6 About `backupMu` (concurrency)

For context: the v1.2.0 runtime serializes pre-critical backups
with a `sync.Mutex` (`backupMu`). This prevents two rapid user
actions (e.g. two `save_allowlist` requests) from corrupting a
snapshot. If you suspect a snapshot was corrupted despite this,
check the log:

```bash
su -c "grep 'auto-backup' /data/local/tmp/dnscrypt_main.log | tail -20"
```

If you see two concurrent `auto-backup` entries with the same
timestamp, file an issue — this should not happen in v1.2.0.

---

## 5. Scenario 3: DNS Not Working After Install

### 5.1 Symptoms

- No internet access after installing the module.
- DNS queries time out.
- Apps cannot resolve domain names.

### 5.2 Root cause analysis

| Cause | Probability |
|-------|:-----------:|
| `dnscrypt-proxy` not running | High |
| Port 5354 not listening | High |
| `iptables` rules missing | High |
| SELinux blocking execution | Medium |
| Binary architecture mismatch | Medium |
| Corrupted config | Low |
| **Recovery mode incomplete (v1.2.0)** | **Low (fixed in v1.2.0)** |

### 5.3 Diagnostic commands

```bash
# 1. Check if the DNS engine is running
su -c "pgrep -x dnscrypt-proxy"

# 2. Check if port 5354 is listening (UDP)
su -c "ss -uln | grep 5354"

# 3. Check iptables rules
su -c "iptables -t nat -L DNSCRYPT_OUT -n"
su -c "iptables -t nat -L OUTPUT -n | grep DNSCRYPT"

# 4. Test a query directly
su -c "nslookup google.com 127.0.0.1"

# 5. Check the main log
su -c "tail -50 /data/local/tmp/dnscrypt_main.log"
su -c "tail -50 /data/local/tmp/dnscrypt-proxy.log"
```

### 5.4 Solution A — Restart the service

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

Wait ~10 seconds, then test:

```bash
su -c "nslookup google.com 127.0.0.1"
```

### 5.5 Solution B — Rebuild the firewall

If the engine is running but iptables rules are missing:

```bash
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 1"
```

### 5.6 Solution C — Verify the binary

```bash
# Check architecture
su -c "getprop ro.product.cpu.abi"
# → arm64-v8a

# Check the binary
su -c "file /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy"
# → should say: ELF ... ARM aarch64 ... pie executable

# If wrong:
# Reinstall the module (see §10).
```

### 5.7 Solution D — Check SELinux

```bash
su -c "getenforce"
# → Enforcing or Permissive
```

If **Enforcing** blocks execution:

```bash
# Check the log for SELinux denials
su -c "dmesg | grep -i avc | tail -20"
```

If denials reference the module binary, either:

- Set SELinux to permissive (temporary):
  ```bash
  su -c "setenforce 0"
  ```
- Or restore contexts:
  ```bash
  su -c "restorecon -R /data/adb/modules/dnscrypt-proxy-webui/"
  ```

### 5.8 Solution E — Full reset (last resort)

If none of the above works:

```bash
# 1. Stop everything
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 2. Clean up and rebuild the firewall
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; aggressive_cleanup"
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 1"

# 3. Restart
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 5.9 Pre-flight checklist before testing recovery

If you plan to test the recovery mode (§9) on a device:

- [ ] **Take a manual backup first**:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
  ```
- [ ] **Confirm the snapshot exists**:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups.available'
  ```
- [ ] **Confirm `.last_stable` is set**:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups.last_stable'
  ```
- [ ] **Note the current ports** (in case they change):
  ```bash
  su -c "grep -E '^(PORT|DASHBOARD_PORT)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
  ```
- [ ] **Note the current profile**:
  ```bash
  su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
  ```
- [ ] **Do not proceed** if any of the above is missing.

### 5.10 Language preference note (v1.2.0)

The WebUI's language preference (English default + Arabic toggle)
is **client-side only**:

- It lives in the browser's `localStorage['dnscrypt-lang']`.
- It is **not** part of the 5 preserved config files.
- It is **not** affected by:
  - DNS engine restarts.
  - Recovery mode.
  - Backup/restore cycles.
  - Module reinstalls.
  - Data-loss scenarios.

**What this means**: If your WebUI was displaying Arabic before an
incident, it will still display Arabic after the recovery — as
long as you are using the same browser. If you switch browsers or
clear `localStorage`, the WebUI reverts to the **default language
(English)**, and you can switch back with the `langToggle` button.

**No recovery step is ever needed** for the language preference.

---

## 6. Scenario 4: WebUI Unreachable

### 6.1 Symptoms

- Browser shows "Cannot connect" at `http://127.0.0.1:9090`.
- The WebUI process is not running.
- Dashboard (`:9091`) is also unavailable.

### 6.2 Diagnostic commands

```bash
# 1. Check if the WebUI process is running
su -c "pgrep -x dnscrypt-webui"

# 2. Check if port 9090 is listening
su -c "ss -ltn | grep 9090"

# 3. Check for port collisions
su -c "ss -ltn | grep -E '9090|9091|8080'"

# 4. Check the main log
su -c "tail -50 /data/local/tmp/dnscrypt_main.log"

# 5. Check the config
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
```

### 6.3 Solution A — Manual start

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh"
```

This starts the WebUI and opens the browser.

### 6.4 Solution B — Check for port collision

If port 9090 is used by another app:

```bash
# Change the port
su -c "sed -i 's/^PORT=.*/PORT=9191/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

Then access `http://127.0.0.1:9191`.

### 6.5 Solution C — Check BIND_ADDR

If `BIND_ADDR` was set to a non-loopback address:

```bash
su -c "grep BIND_ADDR /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
```

If it shows `0.0.0.0` or an IP, and the WebUI refuses to start
(because credentials are missing):

```bash
# Reset to localhost
su -c "sed -i 's/^BIND_ADDR=.*/BIND_ADDR=127.0.0.1/' \
       /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 6.6 Solution D — Kill and restart

```bash
# Kill any zombie process
su -c "pkill -9 -x dnscrypt-webui"

# Clear the PID file
su -c "rm -f /data/adb/modules/dnscrypt-proxy-webui/proxy/run/webui.pid"

# Start again
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh"
```

### 6.7 Solution E — Manual launch

```bash
# Run the binary directly (with output visible)
su -c "cd /data/adb/modules/dnscrypt-proxy-webui/proxy && \
       HOME=/data/local/tmp ./dnscrypt-webui"
```

This will print any startup errors to the console. Press Ctrl+C
to stop.

### 6.8 Solution F — Check the offline page (v1.2.0)

If the WebUI is reachable but the browser shows the offline page:

1. **The Service Worker served a cached offline response.**
   Force a hard reload:
   - Chrome: `Ctrl + Shift + R` (or long-press the reload button
     on mobile).
   - Firefox: `Ctrl + F5`.

2. **If the offline page persists**, the server is likely down.
   See §6.2.

3. **If the offline page shows a "Reload" banner that
   reappears after each reload** (v1.1.0 regression):
   - This was fixed in v1.2.0 for both `index.html` and
     `dashboard.html`. See §9.7.
   - Update to v1.2.0 or newer.

### 6.9 Language toggle not working (v1.2.0)

**Symptom**: The `langToggle` button in the WebUI header does not
switch to Arabic, or the layout does not flip to RTL.

**Possible causes**:

1. **Old browser** — very old browsers may not fully support the
   RTL flip. Use Chrome 88+, Firefox 92+, or Samsung Internet 16+.
2. **Stale Service Worker cache** — the SW may be serving an old
   HTML file.
3. **JavaScript error** — a runtime error in `toggleLanguage()`.

**Diagnostic**:

```bash
# 1. Verify the toggle exists in the served HTML
curl -s http://127.0.0.1:9090/ | grep -c 'id="langToggle"'
# Expected: >= 1

# 2. Verify both language objects exist
curl -s http://127.0.0.1:9090/ | grep -c 'translations'
# Expected: >= 1
```

**Solutions**:

- **Cause 1**: Use a modern browser.
- **Cause 2**: Hard-refresh the page (`Ctrl + Shift + R`) and
  clear site data in DevTools → Application → Storage.
- **Cause 3**: Open DevTools Console and check for errors.

**Note**: This is a client-side feature. It does **not** affect
the API, the DNS engine, or the firewall.

---

## 7. Scenario 5: Firewall Rules Broken

### 7.1 Symptoms

- DNS redirect does not work.
- Other apps' network breaks.
- `iptables -t nat -L OUTPUT` shows an inconsistent state.
- `DNSCRYPT_OUT` chain is missing or corrupt.

### 7.2 Diagnostic commands

```bash
# 1. List the OUTPUT chain
su -c "iptables -t nat -L OUTPUT -n --line-numbers"

# 2. List the Custom Chain
su -c "iptables -t nat -L DNSCRYPT_OUT -n --line-numbers"

# 3. Check for orphans
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# Expected: 0

# 4. IPv6
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n"
```

### 7.3 Solution A — Full firewall reset

```bash
# Clean everything
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 0"

# Rebuild
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 1"

# Verify
su -c "iptables -t nat -L DNSCRYPT_OUT -n"
```

### 7.4 Solution B — Manual cleanup (if functions.sh is broken)

```bash
# 1. Remove jump rules
su -c "iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"

# 2. Flush and delete the chain
su -c "iptables -t nat -F DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -X DNSCRYPT_OUT 2>/dev/null"

# 3. Same for IPv6
su -c "ip6tables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -F DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -X DNSCRYPT_OUT6 2>/dev/null"

# 4. Restart the service
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 7.5 Solution C — nftables cleanup

If the device uses nftables:

```bash
# Remove the table
su -c "nft delete table inet dnscrypt_filter 2>/dev/null"
su -c "nft delete table ip dnscrypt_filter 2>/dev/null"
su -c "nft delete table ip6 dnscrypt_filter 2>/dev/null"

# Rebuild via the service
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 7.6 Solution D — Emergency full flush

> ⚠️ **Destructive**: This deletes **all** NAT rules in the OUTPUT
> chain. Use only if you are certain no other service depends on
> them (e.g. no VPN).

```bash
su -c "iptables -t nat -F OUTPUT"
su -c "ip6tables -t nat -F OUTPUT"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

---

## 8. Scenario 6: Corrupted Backup Directory

### 8.1 Symptoms

- `runtime_info.backups.available` is negative or nonsensical.
- The WebUI/Dashboard shows "0 snapshots" but files exist.
- `ls /sdcard/dnscrypt-webui-backup/` errors.
- Snapshots are missing `.manifest.json`.

### 8.2 Diagnostic commands

```bash
# 1. Check the directory
su -c "ls -la /sdcard/dnscrypt-webui-backup/"

# 2. Check each snapshot
for d in /sdcard/dnscrypt-webui-backup/*/; do
    echo "=== $d ==="
    ls -la "$d"
done

# 3. Check permissions
su -c "stat -c '%a %U:%G %n' /sdcard/dnscrypt-webui-backup/"

# 4. Check the 7-field object
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups'
```

### 8.3 Solution A — Fix permissions

```bash
su -c "chmod 0700 /sdcard/dnscrypt-webui-backup"
su -c "chown root:root /sdcard/dnscrypt-webui-backup"
su -c "find /sdcard/dnscrypt-webui-backup -type d -exec chmod 0700 {} \\;"
su -c "find /sdcard/dnscrypt-webui-backup -type f -exec chmod 0600 {} \\;"
```

### 8.4 Solution B — Rebuild `current/`

If `current/` is missing or empty, rebuild it from the newest
snapshot:

```bash
# Find the newest valid snapshot
SNAP=$(su -c "ls -1dt /sdcard/dnscrypt-webui-backup/*/ | \
       grep -vE '/(current|txn-|orphan-txn-)' | head -1" | tr -d '\r')

# Rebuild current/
su -c "rm -rf /sdcard/dnscrypt-webui-backup/current"
su -c "mkdir -p /sdcard/dnscrypt-webui-backup/current"
su -c "cp -a $SNAP/* /sdcard/dnscrypt-webui-backup/current/"
su -c "chmod -R 0600 /sdcard/dnscrypt-webui-backup/current/"
```

### 8.5 Solution C — Rebuild `.last_stable`

```bash
# Find the newest snapshot name
NEWEST=$(basename "$SNAP")
su -c "echo '$NEWEST' > /sdcard/dnscrypt-webui-backup/.last_stable"
```

### 8.6 Solution D — Rebuild `.manifest.json`

If a snapshot is missing its manifest:

```bash
cd "$SNAP"

# Generate a new manifest
cat > /tmp/manifest.json << 'EOF'
{
  "version": "unknown",
  "timestamp": "rebuilt",
  "source": "manual",
  "root_solution": "unknown",
  "files_count": 0,
  "files": []
}
EOF

# Populate it
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
    if [ -f "$f" ]; then
        SHA=$(sha256sum "$f" | awk '{print $1}')
        # Append to files array...
        echo "  $f: $SHA"
    fi
done

su -c "cp /tmp/manifest.json $SNAP/.manifest.json"
```

**Note**: The `version` field is `"unknown"` when the manifest
is rebuilt manually. This matches the value used by runtime
backups (`main.go:createAutoBackup`, `action.sh --backup`,
`service.sh:auto_backup_if_needed`). See `BACKUP.md` §5.1 for
the full explanation.

### 8.7 Solution E — Start fresh

If the backup directory is unrecoverable:

```bash
# Inspect what remains
su -c "ls -laR /sdcard/dnscrypt-webui-backup/"

# If nothing useful remains:
su -c "mv /sdcard/dnscrypt-webui-backup /sdcard/dnscrypt-webui-backup.broken-$(date +%Y%m%d)"
su -c "reboot"
```

After reboot, the directory is recreated on the next auto-backup
or install.

---

## 9. Recovery Mode (One-Command Fix)

### 9.1 What it does

Recovery Mode restores the **last known-good configuration** from
the persistent backup. It is triggered by a file and runs before
normal installation.

**Chain of execution**:

1. `customize.sh` runs at install time.
2. It checks for `/data/adb/modules/dnscrypt-proxy-webui/recovery`
   OR `/data/adb/dnscrypt-recovery`.
3. If found: restores from `.last_stable` → `current/` → in-place.
4. Continues with the normal installation (does **not** exit early).
5. Removes the trigger file after success.

**v1.2.0 change**: In v1.2.0, recovery mode **no longer exits
early**. The previous version called `exit 0`, which could produce
a **partial module** (no binaries, no scripts) when installed from
scratch. The new flow restores user data, then proceeds with the
full install. See `ARCHITECTURE.md` §3.10 for the flow diagram.

### 9.2 When to use it

- The module is unbootable but you can run commands via ADB.
- Data is corrupted but the backup directory is intact.
- You want a "one-shot" recovery without manual file copying.
- You upgraded from a version with the v1.1.0 data-loss bug and
  want to recover from the persistent backup.

### 9.3 Procedure

**Step 1**: Create the trigger file:

```bash
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
```

Or, if the module directory is inaccessible:

```bash
su -c "touch /data/adb/dnscrypt-recovery"
```

**Step 2**: Reboot:

```bash
su -c "reboot"
```

**Step 3**: Wait for boot to complete (~30-60 seconds).

**Step 4**: Verify the recovery:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

Look for:

- "All 5 user data files present"
- "Backups: N snapshot(s)"
- The profile matches your expected value.

**Step 5**: Confirm the trigger file is gone:

```bash
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>/dev/null"
# Expected: (no output)
su -c "ls /data/adb/dnscrypt-recovery 2>/dev/null"
# Expected: (no output)
```

### 9.4 Recovery source priority

| Priority | Source | When used |
|:--------:|--------|-----------|
| 1 | `$PERSISTENT_BACKUP/<.last_stable>/` | If the pointer file exists |
| 2 | `$PERSISTENT_BACKUP/current/` | If `.last_stable` is missing |
| 3 | In-place `proxy/` directory | If no backup exists |

If all three fail, `customize.sh` aborts with an error message.

### 9.5 What recovery does NOT do

- ❌ It does **not** reinstall the module from scratch (it
  continues the normal install after restoring).
- ❌ It does **not** rebuild the firewall.
- ❌ It does **not** restart the DNS engine.
- ❌ It does **not** fix a corrupted `/sdcard/`.
- ❌ It does **not** affect the WebUI's language preference (that
  is a client-side concern).

After recovery, you may need to reboot again (or restart the
service) for the changes to take effect.

### 9.6 Recovery-mode correctness (v1.2.0 fix)

> **⚠️ Critical note for users upgrading from an early v1.2.0
> draft.**

The v1.2.0 release fixes a correctness bug in the recovery-mode
flow. The bug affected only early drafts of v1.2.0 and was fixed
before the final release.

**The bug**: In an early v1.2.0 draft, the ZIP extraction step
(`customize.sh §[9]`) ran **after** the recovery restore
(`§[8a]`) and overwrote `webui.conf` and `dnscrypt-proxy.toml`
with the ZIP's defaults. The subsequent restore step (`§[9c]`)
was skipped in recovery mode, so the corrupted files were never
re-fixed.

**Result**: 2 of the 5 restored files were silently lost during
recovery.

**The fix (FIX-1) — snapshot-and-reapply strategy**:

Rather than reordering the ZIP extraction steps (which would
require maintaining a duplicate exclusion list that depends on
knowing the ZIP's contents), the final v1.2.0 release uses a
**snapshot-and-reapply** approach:

1. **`§[8a]` — restore + snapshot**: In recovery mode, the 5 user
   files are restored from `$RESTORE_SOURCE` into
   `$MODPATH/proxy/` (via `copy_with_context`), **AND** a copy of
   each file is saved to `$MODPATH/.recovery_snapshot/`.

2. **`§[9]` — extract ZIP**: The ZIP is extracted normally. This
   step overwrites `webui.conf` and `dnscrypt-proxy.toml` with
   the ZIP's defaults — this is unavoidable without knowing the
   ZIP's contents.

3. **`§[9b2]` — re-apply snapshot**: The 5 files are re-applied
   from `$MODPATH/.recovery_snapshot/` into `$MODPATH/proxy/`.
   On partial re-application (i.e. fewer files re-applied than
   were snapshotted), the snapshot directory is **preserved** at
   `$MODPATH/.recovery_snapshot/` for manual inspection.

4. **`§[9c]` — skipped**: The normal-mode restore step is skipped
   when `RECOVERY_MODE=1`, because steps 1 and 3 already handled
   the restoration.

**Why this approach over filtering the unzip argument list**:

- It does **not** depend on knowing what the ZIP contains. If a
  future release adds or removes files under `proxy/`, the fix
  keeps working.
- It keeps the extraction logic of `§[9]` untouched, so the
  normal-install path is byte-for-byte identical to the
  pre-recovery behavior.
- The snapshot directory uses `$MODPATH/.recovery_snapshot/`
  (dot-prefixed, cleaned up in `§[9b2]`), so it never appears in
  the final module layout.

**How to verify you are on the fixed version**:

```bash
# 1. Check the module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# → must be version=v1.2.0

# 2. Check the fix is present in customize.sh
# (look for the recovery snapshot directory and the re-apply block)
su -c "grep -q 'RECOVERY_SNAPSHOT_DIR' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
       echo '✅ v1.2.0 fix present (snapshot dir)'"

su -c "grep -q 'Re-applying recovery snapshot' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
       echo '✅ v1.2.0 fix present (§[9b2] re-apply block)'"
```

If the fix is not present, reinstall the module from the v1.2.0
ZIP.

**Testing on a real device**: If you want to verify the fix
yourself, see the pre-flight checklist in §5.9. The full test
procedure is:

1. Set a distinctive value in `webui.conf` (e.g. `PORT=9191`).
2. Take a manual backup (`action.sh --backup`).
3. Trigger recovery (`touch recovery && reboot`).
4. After reboot, verify `PORT=9191` is still present.

### 9.7 Recovery mode and the Service Worker update banner

**Not directly related** — but worth mentioning here because it is
a **v1.2.0 correctness fix** that users may encounter during
recovery.

**The bug (v1.1.0)**: The [Reload] button in the update banner
sent `SKIP_WAITING` to `navigator.serviceWorker.controller` — the
**old** worker — which ignored it. The new worker stayed in the
`waiting` state, so the banner reappeared on every page reload →
infinite loop.

**The fix (v1.2.0)**:
- Send `SKIP_WAITING` to `swRegistration.waiting` (the **new**
  worker).
- Reload on the `controllerchange` event.
- Guard double-clicks with a `pendingReload` flag.
- Applied to **both** `index.html` and `dashboard.html`.

**Verify the fix is present**:

```bash
su -c "grep -q 'swRegistration.waiting' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && \
       echo '✅ index.html'"
su -c "grep -q 'swRegistration.waiting' /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html && \
       echo '✅ dashboard.html'"
su -c "grep -q 'id=\"swUpdateBanner\"' /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html && \
       echo '✅ banner in dashboard.html'"
```

If any of the above is missing, reinstall v1.2.0.

### 9.8 Recovery mode and the language preference

The WebUI's bilingual feature (English default + Arabic toggle)
is **not affected** by recovery mode:

- The language preference lives in `localStorage['dnscrypt-lang']`
  on the user's browser.
- Recovery mode restores the 5 server-side config files only.
- It never touches client-side browser storage.
- After recovery, the WebUI loads in the **previously chosen
  language** — as long as the browser retains its `localStorage`.
- If the browser's `localStorage` was cleared, the WebUI reverts
  to **English (default)**. The user can re-toggle with the
  `langToggle` button.

**No action needed** for the language preference after recovery.

---

## 10. Last-Resort Recovery (No Backups)

### 10.1 When to use this

Use this section only if:

- ❌ `/sdcard/dnscrypt-webui-backup/` is empty or missing.
- ❌ No `txn-*` or `orphan-txn-*` directories exist.
- ❌ No snapshot can be found in `/data/`, `/data/local/tmp/`,
  or `/sdcard/`.

### 10.2 Accept data loss and reinstall

**Step 1**: Take a final manual backup (in case something useful
remains):

```bash
su -c "mkdir -p /sdcard/last-chance-backup"
su -c "cp -a /data/adb/modules/dnscrypt-proxy-webui/proxy/* \
       /sdcard/last-chance-backup/ 2>/dev/null"
su -c "cp -a /data/local/tmp/dnscrypt* /sdcard/last-chance-backup/ 2>/dev/null"
```

**Step 2**: Uninstall the module:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/uninstall.sh"
```

Or via Magisk Manager: Modules → DNSCrypt Proxy → Remove.

**Step 3**: Reboot:

```bash
su -c "reboot"
```

**Step 4**: Reinstall the module from the GitHub Releases page.

**Step 5**: Reconfigure from scratch:

- Set the desired profile (`light`, `normal`, `pro`, `proplus`,
  `ultimate`).
- Re-add custom rules to `allowlist.txt` and `denylist.txt`.
- Toggle the WebUI language if needed (English default; Arabic
  via the `langToggle` button).

### 10.3 Recover DNS to a working state

If you do not want to reinstall the module:

```bash
# Remove the module folder
su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"

# Clean the firewall
su -c "iptables -t nat -F OUTPUT"
su -c "iptables -t nat -F DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -X DNSCRYPT_OUT 2>/dev/null"
su -c "ip6tables -t nat -F OUTPUT"
su -c "ip6tables -t nat -F DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -X DNSCRYPT_OUT6 2>/dev/null"

# Reset private DNS
su -c "settings delete global private_dns_mode"

# Reboot
su -c "reboot"
```

The device will boot with the system's default DNS.

### 10.4 Contact support

If you have exhausted all options and want help:

1. Collect diagnostics:
   ```bash
   su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" \
       > /sdcard/diagnose.txt 2>&1
   su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" \
       > /sdcard/diagnose.json 2>&1
   ```

2. Open an Issue:
   - **GitHub**: https://github.com/gasciljh/dnscrypt-proxy-webui/issues
   - Attach `diagnose.txt` and `diagnose.json`.
   - Describe the exact sequence that led to the failure.
   - Include the `backups` object from `diagnose.json` if the issue
     is backup-related.

3. For **security-related** issues, do **not** open a public
   Issue. Use [GitHub Private Vulnerability Reporting](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new).

---

## 11. Emergency Reference Card

### 11.1 Quick commands

```bash
# ============================================================
# STATUS
# ============================================================
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups'

# ============================================================
# SERVICE
# ============================================================
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"

# ============================================================
# BACKUP
# ============================================================
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"
su -c "cat /sdcard/dnscrypt-webui-backup/current/.manifest.json"

# ============================================================
# FIREWALL
# ============================================================
su -c "iptables -t nat -L DNSCRYPT_OUT -n"
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# Expected: 0

# ============================================================
# RECOVERY MODE
# ============================================================
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"
# (or, external trigger:)
su -c "touch /data/adb/dnscrypt-recovery"
su -c "reboot"

# ============================================================
# DISABLE MODULE (boot fix)
# ============================================================
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/disable"
su -c "reboot"

# ============================================================
# UNINSTALL
# ============================================================
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/uninstall.sh"

# ============================================================
# LANGUAGE TOGGLE (v1.2.0)
# ============================================================
# In-browser (DevTools Console):
#   localStorage.getItem('dnscrypt-lang')   // → "en" | "ar" | null
#   localStorage.removeItem('dnscrypt-lang') // reset to English default
#
# Note: This is a client-side preference. It has no server-side
# state and is not affected by any recovery procedure.
```

### 11.2 The 7-field `backups` object

Reference for interpreting `runtime_info` and `status.sh --json`
output:

| Field | Type | Meaning |
|---|---|---|
| `available` | int | Snapshot count (excludes `current/`, `txn-*`, `orphan-txn-*`) |
| `in_flight_txn` | int | `txn-*` directories (install in progress or interrupted) |
| `orphan_txn` | int | `orphan-txn-*` directories (preserved interrupted installs) |
| `last_backup` | string \| null | Timestamp of newest snapshot |
| `last_backup_name` | string \| null | Directory name of newest snapshot |
| `last_stable` | string \| null | Content of `.last_stable` pointer |
| `path` | string | Backup root path |

### 11.3 Paths reference

| Path | Purpose |
|------|---------|
| `/data/adb/modules/dnscrypt-proxy-webui/` | Module root |
| `/data/adb/modules/dnscrypt-proxy-webui/proxy/` | Config + binaries |
| `/data/adb/modules/dnscrypt-proxy-webui/proxy/run/` | Runtime state |
| `/data/adb/modules/dnscrypt-proxy-webui/recovery` | Recovery trigger (module) |
| `/data/adb/modules/dnscrypt-proxy-webui/disable` | Disable trigger |
| `/data/adb/modules/dnscrypt-proxy-webui/.recovery_snapshot/` | v1.2.0 — temporary snapshot for post-extraction re-apply |
| `/data/adb/dnscrypt-recovery` | Recovery trigger (external) |
| `/sdcard/dnscrypt-webui-backup/` | Persistent backups |
| `/sdcard/dnscrypt-webui-backup/current/` | Live snapshot |
| `/sdcard/dnscrypt-webui-backup/.last_stable` | Recovery pointer |
| `/sdcard/dnscrypt-webui-backup/txn-*/` | In-flight transactions |
| `/sdcard/dnscrypt-webui-backup/orphan-txn-*/` | Preserved interrupted installs |
| `/data/local/tmp/dnscrypt_main.log` | Main log |
| `/data/local/tmp/dnscrypt-proxy.log` | DNS engine log |
| `/data/local/tmp/dnscrypt_install.log` | Install log |
| `META-INF/com/google/android/update-binary` | Magisk bootstrap |

### 11.4 Exit codes reference

| Tool | Code | Meaning |
|------|:----:|---------|
| `status.sh --check` | 0 | Everything running |
| `status.sh --check` | 1 | Nothing running |
| `status.sh --check` | 2 | Partial |
| `status.sh --check` | 3 | Module disabled |
| `status.sh --diagnose` | 0 | Healthy |
| `status.sh --diagnose` | 2 | Issues detected |
| `status.sh --diagnose` | 3 | Module disabled |
| `action.sh --backup` | 0 | Backup created |
| `action.sh --backup` | 3 | Backup failed (0 files copied) |

### 11.5 Recovery trigger quick reference

| Trigger path | Where | Purpose |
|---|---|---|
| `$MODPATH/recovery` | Inside module | Per-module recovery |
| `/data/adb/dnscrypt-recovery` | Outside module | Survives module folder loss |

Both are checked by `customize.sh §[8a]`. Either one activates
recovery mode.

**Recovery source priority**: `.last_stable` → `current/` →
in-place `proxy/`.

**Recovery removes both trigger files** after a successful
restore.

### 11.6 Transaction directory states

| `.state` value | Meaning | Action |
|---|---|---|
| `START` | Install in progress, or interrupted | **Preserve** — may contain the only copy of user data |
| `COMMIT` | Install succeeded, cleanup skipped | Safe to remove (`main.go` does this at startup) |
| `ROLLBACK` | Rollback already applied | Safe to remove |
| (missing) | Inconsistent state | Inspect manually; do not delete blindly |

**Renamed on uninstall**:

- `txn-*` with `.state=START` → `orphan-txn-*` (preserved)
- `txn-*` with `.state=COMMIT` or `.state=ROLLBACK` → removed
- `orphan-txn-*` → preserved as-is

### 11.7 Language preference reference (v1.2.0)

| Aspect | Value |
|---|---|
| Default language | English |
| Available languages | English, Arabic (via `langToggle`) |
| Preference storage | `localStorage['dnscrypt-lang']` |
| Server state | None |
| Affected by recovery? | No |
| Affected by backup/restore? | No |
| Affected by module reinstall? | No |
| Reset to default by | Clearing browser `localStorage` |
| Manual reset command | `localStorage.removeItem('dnscrypt-lang')` (DevTools) |

### 11.8 Support links

- **Bug reports**: https://github.com/gasciljh/dnscrypt-proxy-webui/issues
- **Discussions**: https://github.com/gasciljh/dnscrypt-proxy-webui/discussions
- **Security**: https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new

---

## 12. References

### 12.1 Related documentation

| Document | Purpose |
|----------|---------|
| [`BACKUP.md`](BACKUP.md) | Backup system reference (v1.2.0) |
| [`UPGRADE.md`](UPGRADE.md) | Version upgrade guide |
| [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | General troubleshooting |
| [`INSTALL.md`](INSTALL.md) | Installation guide |
| [`SECURITY.md`](SECURITY.md) | Security model + §5.31, §5.32 |
| [`API.md`](API.md) | API reference |
| [`FAQ.md`](FAQ.md) | Frequently asked questions |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | System architecture + §3.10, §6.7 |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history |

### 12.2 Project files

| File | Role |
|------|------|
| `proxy/customize.sh` | Contains Layer 7 (recovery mode) and the v1.2.0 fix (§[8a], §[9b2]) |
| `proxy/functions.sh` | Backup helpers |
| `proxy/service.sh` | Auto-backup trigger |
| `proxy/main.go` | Pre-critical backup + notification |
| `proxy/status.sh` | `--diagnose` tool |
| `proxy/action.sh` | Manual backup trigger |
| `proxy/uninstall.sh` | Preserves backup + cleans orphan transactions |
| `META-INF/com/google/android/update-binary` | Magisk bootstrap |

### 12.3 External references

- [Magisk — Module Structure](https://topjohnwu.github.io/Magisk/guides.html)
- [KernelSU — Recovery](https://kernelsu.org/)
- [APatch — Documentation](https://github.com/bmax121/APatch)
- [Android — Safe Mode](https://source.android.com/docs/core/architecture/bootloader)
- [TWRP — Recovery Mode](https://twrp.me/)

### 12.4 Support

- **Bug reports**: https://github.com/gasciljh/dnscrypt-proxy-webui/issues
- **Discussions**: https://github.com/gasciljh/dnscrypt-proxy-webui/discussions
- **Security**: https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new

---

*Last updated: 2026-09-29*
*Version: v1.2.0*
*Author: gasciljh*