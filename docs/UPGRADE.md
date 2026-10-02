# Upgrade Guide — DNSCrypt Smart Filter

> Comprehensive guide for upgrading between DNSCrypt Smart Filter versions.

**Current version**: v1.3.0
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **📖 Related documents**:
> - Git workflow → [`docs/BRANCHING.md`](BRANCHING.md)
> - Release process → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decisions → [`docs/adr/README.md`](adr/README.md)
> - Installation guide → [`docs/INSTALL.md`](INSTALL.md)
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **Major update** — added §1.4 (Data-Preservation Upgrade
>     Model) documenting the 10 defensive layers that replace the
>     legacy `BACKUP_TMP` mechanism.
>   • Added the v1.1.0 → v1.2.0 upgrade guide (now **§3.2**) — the
>     second in-place upgrade. Includes the persistent backup
>     directory transition, the `backups` object, and the new CLI
>     tools.
>   • The previous v1.0.0 → v1.1.0 upgrade guide is now **§3.1**
>     (Historical).
>   • Updated §2 (Settings Preservation) — the v1.0.0 mechanism
>     is now **superseded** by the v1.2.0 10-layer model.
>   • Updated §4 (Verification) — added the 7-field `backups`
>     object check and the `status.sh --diagnose` tool.
>   • Updated §5 (API Behavior Notes) — added `runtime_info.backups`
>     schema and the `append_denylist` content requirement.
>   • Updated §6.3 (DNS issues) — added the recovery-mode procedure.
>   • Updated §6.5 (Uninstall) — the persistent backup directory is
>     now **preserved** on uninstall.
>   • Updated §6.7 (Backup locations) — added the persistent backup
>     directory and the `txn-*` / `orphan-txn-*` states.
>   • Added §6.8 (Recovery mode) — full step-by-step procedure.
>   • **Added §6.9 (Recovery-mode correctness — FIX-1)** — documents
>     the actual **snapshot-and-reapply** implementation. This
>     supersedes the previously incorrect "reorder + exclude"
>     description that appeared in early documentation.
>   • Corrected all instances of the mis-typed path
>     `/sdcrypt-webui-backup` (missing `ard/`) to the correct
>     `/sdcard/dnscrypt-webui-backup` throughout the document.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention. **No API impact.**
>   • **Encoding correction (this revision)**: verified that all
>     section markers, arrows, checkmarks, warnings, and box
>     drawing characters render as proper UTF-8.
>   • **Numbering correction (this revision)**: §3 was
>     restructured for a consistent hierarchy. The v1.0.0 → v1.1.0
>     upgrade guide is now **§3.1** (was `§3.0.1`, nested under a
>     `§3.0 Historical Upgrades` wrapper). The v1.1.0 → v1.2.0
>     upgrade guide is now **§3.2** (was `§3.1`). The following
>     subsections shifted by one accordingly: **§3.3** General
>     Procedure, **§3.4** What Happens Behind the Scenes,
>     **§3.5** Installation Methods, **§3.6** Common Messages.
>     This fixes the H3/H4 mixing that made `§3.0.1` a
>     sub-subsection while `§3.1` returned to the H3 level.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Settings Preservation](#2-settings-preservation)
3. [Upgrade Procedure](#3-upgrade-procedure)
4. [Verification After Upgrade](#4-verification-after-upgrade)
5. [API Behavior Notes (v1.2.0)](#5-api-behavior-notes-v120)
6. [Emergency Recovery](#6-emergency-recovery)
7. [References](#7-references)

---

## 1. Overview

### 1.1 Current Release

**v1.2.0 is the third stable release** of DNSCrypt Smart Filter.

**v1.0.0** (2026-09-24) was the first stable release — it
consolidated the entire development effort into a single
production-ready version with 33 audit corrections.

**v1.1.0** (2026-09-26) was a **polish release**:

- No breaking changes.
- Three runtime improvements (MEM-1, MEM-2, MEM-3).
- Two new `runtime_info` fields (`profile_key`, `memory_limit_mb`).

**v1.2.0** (2026-09-29) is the **Data-Preservation Release**:

- **Fixes a silent data-loss bug** in v1.1.0 that erased the 5
  user config files on every in-place upgrade.
- Introduces the **10 defensive layers** (multi-source detection,
  persistent backup, transactional upgrades, recovery mode, etc.).
- Adds the **`backups` object** to `runtime_info` (7 fields).
- Adds two new CLI tools: `action.sh --backup` and
  `status.sh --diagnose`.
- Ships a **bilingual WebUI** (English default + Arabic toggle) —
  client-side only.
- No breaking changes.

See [CHANGELOG.md](../CHANGELOG.md) for the full history.

This guide covers:

- The **settings preservation mechanism** that applies to all
  in-place upgrades.
- The **general upgrade procedure** for future versions.
- The **specific upgrade from v1.1.0 to v1.2.0** (§3.2).
- The **historical upgrade from v1.0.0 to v1.1.0** (§3.1).
- **Emergency recovery** procedures.
- **v1.2.0 API behavior notes** (important for scripts and
  integrations).

### 1.2 Design Principles

The upgrade system is built on:

| Principle | Implementation |
|---|---|
| **Zero data loss** | 5 user config files are automatically backed up and restored |
| **Idempotent** | Reinstalling the same version is safe |
| **Automatic** | No manual configuration after upgrade |
| **Reversible** | Emergency recovery + recovery mode supported |
| **No silent breaking changes** | v1.1.0 and v1.2.0 API additions are strictly additive |
| **Persistent** | (v1.2.0) The backup directory survives reboot, uninstall, and `/data` reset |

### 1.3 Project Version History

| Version | Date | Type | Notes |
|---|---|:---:|---|
| v1.0.0 | 2026-09-24 | First stable | 33 audit corrections, 20 fixes, Level 4 infrastructure |
| v1.1.0 | 2026-09-26 | Polish | MEM-1/2/3, dynamic memory limit, `profile_key` + `memory_limit_mb` |
| **v1.2.0** | **2026-09-29** | **Data preservation** | **10 defensive layers, BAK-1..BAK-4, FIX-1/2, bilingual WebUI, `backups` object, recovery mode** |

**Next planned**:

- **v1.3.0** — CSP hardening (remove `'unsafe-inline'`), PWA port
  unification, backup integrity hardening. See
  [`ROADMAP.md`](ROADMAP.md) §5.
- **v2.0.0** — Major rewrite. See [`ROADMAP.md`](ROADMAP.md) §7.

### 1.4 Data-Preservation Upgrade Model (v1.2.0)

Starting with v1.2.0, every in-place upgrade runs inside the
**10 defensive layers**:

| # | Layer | Role |
|:-:|---|---|
| 1 | Multi-source detection | Search 7 candidate locations for user data |
| 2 | Persistent backup | Snapshot to `/sdcard/dnscrypt-webui-backup/` |
| 3 | SHA256 integrity verification | Advisory per-file checksum |
| 4 | Transactional upgrades | Atomic install with rollback (`txn-*` dirs) |
| 5 | Root-solution compatibility | Magisk / KernelSU / APatch |
| 6 | SELinux preservation | `restorecon` / `chcon` |
| 7 | Recovery mode | Trigger file restores last known-good config |
| 8 | Config migrations | Version-aware transforms |
| 9 | Automation + rotation | Periodic (24 h) + pre-critical backups; max 21 snapshots |
| 10 | Observability | `.upgrade_history.json` + 7-field `backups` object |

**What this changes for users**:

- ✅ The 5 config files are now preserved **and** snapshotted for
  future recovery.
- ✅ The snapshot location survives reboot, uninstall, and
  factory reset of `/data`.
- ✅ A failed upgrade automatically rolls back.
- ✅ New CLI tools let you create manual backups
  (`action.sh --backup`) and inspect the state
  (`status.sh --diagnose`).
- ✅ No user action is required — everything is automatic.

**What this changes for the upgrade mechanism**:

- ❌ The legacy `BACKUP_TMP` mechanism (v1.0.0) is **superseded**.
  See §2.3 for the comparison.

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

**This behavior is identical in v1.0.0, v1.1.0, and v1.2.0** — the
underlying mechanism improved, but the user-facing guarantee is the
same.

### 2.2 Additional Files

| File | Action | Note |
|---|---|---|
| `blocklist.raw` | 🔄 Downloaded | Re-fetched on profile update |
| `blocklist.txt` | 🔄 Rebuilt | Derived from `blocklist.raw` + rules |
| `blocked-ips.txt` | 🔄 Recreated | From defaults |
| `run/` directory | 🔄 Recreated | Runtime state only |
| Logs | 🔄 Rotated | Fresh log files |

### 2.3 How It Works — Evolution

**v1.0.0 – v1.1.0** (legacy mechanism):

```bash
# Before extraction:
BACKUP_TMP="/data/local/tmp/dnscrypt-upgrade-backup-$$"
mkdir -p "$BACKUP_TMP"
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
    [ -f "$_EXISTING_MODULE/proxy/$f" ] && cp -f "$_EXISTING_MODULE/proxy/$f" "$BACKUP_TMP/$f"
done

# After extraction:
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
    [ -f "$BACKUP_TMP/$f" ] && cp -f "$BACKUP_TMP/$f" "$BIN_DIR/$f"
done
rm -rf "$BACKUP_TMP"
```

**Limitations of the legacy mechanism**:

- `/data/local/tmp/` is **cleared on reboot** — a user who
  rebooted before inspecting the backup lost it.
- `/data/local/tmp/` is **deleted on uninstall** — a user who
  uninstalled then reinstalled had no way to recover.
- No SHA256 verification.
- No transaction — a failed install could leave a partial state.
- No recovery mode.

**v1.2.0** (current mechanism):

The 10 defensive layers run during every install. The key phases:

1. **Layer 1 — Multi-source detection** — searches 7 candidate
   locations for the 5 user files.
2. **Layer 4 — Begin transaction** — creates a `txn-*` directory
   with `.state = START`.
3. **Layer 2 — Persistent backup** — snapshots the 5 files to
   `/sdcard/dnscrypt-webui-backup/<ts>-<version>-<pid>/`.
4. **Layer 3 — SHA256** — writes `.manifest.json` with per-file
   hashes.
5. **Extract** — unpacks the new ZIP.
6. **Layer 6 — Restore** — copies the 5 files back via
   `copy_with_context` (SELinux preservation + `chmod 0600`).
7. **Layer 5 — Root-solution detection** — adapts the source list
   to Magisk / KernelSU / APatch.
8. **Layer 8 — Config migrations** — applies version-aware
   transforms.
9. **Layer 10 — Update `.last_stable`** + append
   `.upgrade_history.json`.
10. **Commit** — removes the `txn-*` directory and writes
    `.state = COMMIT`.

**Result**: The 5 files are preserved **and** a version-tagged
snapshot is created for future recovery.

### 2.4 Manual Backup (Optional but Recommended)

Since v1.2.0, the automatic backup makes manual backups optional.
However, for extra safety or before a factory reset:

```bash
# 1. Create a backup directory (manual)
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

**Or**, use the module's own CLI tool (v1.2.0):

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

This creates a snapshot at
`/sdcard/dnscrypt-webui-backup/<ts>-manual-<pid>/`.

**Recommended especially before a factory reset of `/data`** — the
persistent backup directory lives on `/sdcard/`, which survives a
`/data` reset but not a full factory reset of `/sdcard/`.

### 2.5 Pre-Upgrade Checklist

- [ ] Available storage: `df -h /data` → > 50 MB free
- [ ] Available storage: `df -h /sdcard` → > 10 MB free (v1.2.0)
- [ ] Battery: > 30%
- [ ] Internet: Working (for blocklist re-download)
- [ ] Manual backup (recommended, especially before v1.2.0)
- [ ] **v1.1.0 → v1.2.0**: confirm the persistent backup directory
      exists (see §3.2.3)

---

## 3. Upgrade Procedure

### 3.1 Upgrading from v1.0.0 to v1.1.0 (Historical)

This was the **first in-place upgrade** since the project reached
its first stable release. It was **fully backward compatible**.

**What changed**:

| Category | Change | Impact |
|---|---|---|
| **Memory limit** | Hardcoded 80 MB → per-profile dynamic | Improved `ultimate` performance |
| **`runtime_info`** | Two new fields: `profile_key`, `memory_limit_mb` | Additive |
| **`shellQuote`** | 20 chars → 24 chars | Internal only |
| **Metrics handler** | Uses `MONITORING_UI_PORT` constant | Internal only |
| **Uninstall** | No backup directory created anymore | Manual backup needed |
| **Documentation** | Updated across `docs/` | Read-only |

**What did NOT change**:

- ✅ All API endpoints.
- ✅ Login POST-only.
- ✅ `/readyz` localhost-only.
- ✅ `hasEndpoint` exact matching.
- ✅ Custom Chains.
- ✅ Settings preservation.
- ✅ All v1.0.0 audit corrections.

**If you are still on v1.0.0**: upgrade directly to v1.2.0. The
v1.1.0 → v1.2.0 upgrade (§3.2) supersedes this step and preserves
everything.

### 3.2 Upgrading from v1.1.0 to v1.2.0 (Current)

This is the **Data-Preservation Release**. It fixes a silent
data-loss bug in v1.1.0 and hardens the write path with the 10
defensive layers.

#### 3.2.1 What Changes

| Category | Change | Impact |
|---|---|---|
| **Data preservation** | 10 defensive layers + persistent backup | Fixes data-loss bug |
| **`runtime_info`** | New `backups` object (7 fields) | Additive |
| **CLI tools** | `action.sh --backup`, `status.sh --diagnose` | New tools |
| **Recovery mode** | Trigger file restores last known-good config | New capability |
| **Uninstall** | Persistent backup directory preserved | New behavior |
| **WebUI** | Bilingual (English default + Arabic toggle) | Client-side only |
| **Watchdog** | `X-Watchdog-Token` auth | Replaces localhost bypass |
| **`append_denylist`** | Requires a `content` parameter | Breaking for callers |
| **FIX-1** | Recovery-mode **snapshot-and-reapply** (was incorrectly described as "reorder + exclude" in early drafts) | Correctness |
| **FIX-2** | Service Worker update-banner (`SKIP_WAITING` to the correct worker) | Correctness |
| **Documentation** | New `BACKUP.md` + `EMERGENCY.md` | Read-only |

#### 3.2.2 What Does NOT Change

- ✅ **All API endpoints** — same paths, same methods, same auth.
- ✅ **Login POST-only** (from v1.0.0) — unchanged.
- ✅ **`/readyz` localhost-only** (from v1.0.0) — unchanged.
- ✅ **`hasEndpoint`** exact matching (from v1.0.0) — unchanged.
- ✅ **Custom Chains** (from v1.0.0) — unchanged.
- ✅ **Settings preservation** — 5 files preserved.
- ✅ **Firewall layout** — `DNSCRYPT_OUT` / `DNSCRYPT_OUT6`.
- ✅ **All v1.0.0 and v1.1.0 runtime improvements** — still present.
- ✅ **Memory limit per profile** (MEM-1) — unchanged.
- ✅ **DNS version** — still `2.1.18`.
- ✅ **Module version code formula** — unchanged.

#### 3.2.3 Step-by-Step

```bash
# 1. Note the current state
ORIG_PROFILE=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
echo "Before: profile=$ORIG_PROFILE"

ORIG_PORTS=$(su -c "grep -E '^(PORT|DASHBOARD_PORT)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf")
echo "Before: $ORIG_PORTS"

# 2. Take a snapshot of the pre-upgrade state (recommended)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json > /sdcard/diagnose-before.json"

# 3. Manual backup (optional — v1.2.0 provides one automatically)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"

# 4. Download the v1.2.0 ZIP
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.2.0/dnscrypt-webui-1.2.0-module.zip

# 5. Verify SHA-256
sha256sum -c dnscrypt-webui-1.2.0-module.zip.sha256
# Expected: OK

# 6. Install via Magisk Manager
#    Modules → Install from storage → select the ZIP
#    Watch the install screen for the 10-layer output (see §3.2.4)

# 7. Reboot
su -c "reboot"

# 8. Wait ~60 seconds after boot
sleep 60

# 9. Verify the upgrade (see §4)
```

#### 3.2.4 What to Expect in the Install Log

The `customize.sh` output now includes the 10-layer trace:

```text
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
...

  📊 Upgrade detected: YES (5 files restored)
  💾 Persistent backup: /sdcard/dnscrypt-webui-backup/
  🌐 WebUI: http://127.0.0.1:9090
  📈 Dashboard: http://127.0.0.1:9091
  🔌 Bind: 127.0.0.1
  🧠 Memory limit: ~120 MB (profile: pro)
```

**The critical new lines**:

- `Multi-source detection (Layer 1): 5 file(s) found`
- `Persistent backup created (Layer 2): ...`
- `SHA256 manifest written (Layer 3)`
- `Transaction begun (Layer 4): ...`
- `💾 Persistent backup: /sdcard/dnscrypt-webui-backup/`

#### 3.2.5 The Backup Directory Transition

**Before v1.2.0**:

- No persistent backup directory.
- Backups lived in `/data/local/tmp/dnscrypt-upgrade-backup-$$`
  (deleted after install).

**After v1.2.0**:

- A persistent backup directory is created at
  `/sdcard/dnscrypt-webui-backup/`.
- It contains a snapshot of the current state
  (`<ts>-<version>-<pid>/`) **plus** a live mirror (`current/`).
- It survives reboot, uninstall, and `/data` reset.

**What you will observe after the upgrade**:

```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
# drwx------  current/
# drwx------  20260929-095826-v1.2.0-12345/
# -rw-------  .last_stable
# -rw-------  .upgrade_history.json
# -rw-r--r--  README.md
```

#### 3.2.6 The New CLI Tools

**`action.sh --backup`** — trigger a manual backup:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

Creates a snapshot at
`/sdcard/dnscrypt-webui-backup/<ts>-manual-<pid>/`.

**`status.sh --diagnose`** — full diagnostic report:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

Prints:

- System Information.
- Module Information.
- Service Status.
- Recovery & Notifications.
- User Data Files (all 5).
- Backups (count + latest).
- Health Checks.
- Diagnosis (✅ / ⚠️ / ❌).

#### 3.2.7 Rolling Back to v1.1.0

If the new behavior causes issues (rare), you can roll back:

```bash
# 1. Download the v1.1.0 ZIP
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.1.0/dnscrypt-webui-1.1.0-module.zip

# 2. Install over the current one from Magisk Manager
# 3. Reboot
su -c "reboot"

# 4. Verify rollback
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.1.0
```

**Rollback caveats**:

- ⚠️ `runtime_info.backups` reverts to 5 fields (if present at all).
- ⚠️ `action.sh --backup` stops working.
- ⚠️ `status.sh --diagnose` stops working.
- ⚠️ The persistent backup directory is **preserved** (not touched).
- ⚠️ The bilingual WebUI reverts to English-only if v1.1.0 was
  English-only for you.

Your settings (5 files) remain preserved during rollback.

**Note**: If you decide to roll back, the v1.2.0 persistent backup
directory stays on `/sdcard/`. You can remove it manually:

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

### 3.3 General Procedure (Future Versions)

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
#    💾 Persistent backup: /sdcard/dnscrypt-webui-backup/   ← v1.2.0+
#    🌐 WebUI: http://127.0.0.1:9090
#    📈 Dashboard: http://127.0.0.1:9091
#    🧠 Memory limit: ~XXX MB (profile: <key>)              ← v1.1.0+

# 5. Reboot the device
su -c "reboot"

# 6. After boot (wait 60 seconds)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"  # v1.2.0+
```

### 3.4 What Happens Behind the Scenes

`proxy/customize.sh` performs these steps (v1.2.0):

1. Detects the architecture (`getprop ro.product.cpu.abi`).
2. Detects the existing module (if any).
3. **Layer 1 — Multi-source detection** — searches 7 candidate
   locations for the 5 user files.
4. Kills old processes (`dnscrypt-proxy`, `dnscrypt-webui`).
5. Cleans firewall state (Custom Chains + legacy rules).
6. **Layer 4 — Begin transaction** — creates a `txn-*` directory
   with `.state = START`.
7. **Layer 2 — Persistent backup** — snapshots the 5 files to
   `/sdcard/dnscrypt-webui-backup/<ts>-<version>-<pid>/`.
8. **Layer 3 — SHA256** — writes `.manifest.json`.
9. Extracts the new ZIP.
10. Moves web assets to `web/`.
11. **Layer 6 — Restore** — copies the 5 files back via
    `copy_with_context` (SELinux + `chmod 0600`).
12. **Layer 5 — Root-solution detection** — adapts the source list.
13. Verifies critical files.
14. Selects the correct binaries for the architecture.
15. Creates a secure `run/` directory (mode `0700`).
16. Writes `webui.conf` (with Port Guard — rejects port 8080).
17. Generates secure credentials (if missing).
18. Sets permissions.
19. Writes the module fingerprint.
20. **Layer 8 — Config migrations** — version-aware transforms.
21. **Layer 10 — Update `.last_stable`** + append
    `.upgrade_history.json`.
22. **Commit the transaction** — removes the `txn-*` directory
    and writes `.state = COMMIT`.
23. Prints the expected memory limit for the active profile
    (informational).

**On failure**: any error before step 22 triggers an automatic
rollback. The `txn-*` directory is preserved as `orphan-txn-*` for
manual inspection.

### 3.5 Installation Methods

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

**v1.2.0**: APatch installs use the `modules_update/` fallback
source (Layer 5).

### 3.6 Common Messages

| Message | Meaning |
|---|---|
| `Upgrade detected: YES (5 files restored)` | Settings preserved ✅ |
| `Upgrade detected: NO` | Fresh installation |
| `PORT=8080 conflicts with [monitoring_ui], resetting to 9090` | Port Guard auto-fixed the port |
| `⚠️ Default admin/admin detected — generating secure credentials` | Credentials regenerated |
| `🛑 You MUST REBOOT NOW to restore DNS` | Old processes were killed |
| `🧠 Memory limit: ~XXX MB (profile: <key>)` | **v1.1.0+** — computed soft limit |
| `→ Multi-source detection (Layer 1): 5 file(s) found` | **v1.2.0** — source located |
| `→ Persistent backup created (Layer 2): ...` | **v1.2.0** — snapshot created |
| `→ Transaction begun (Layer 4): txn-...` | **v1.2.0** — transaction started |
| `📊 Upgrade detected: YES (5 files restored)` | **v1.2.0** — summary |
| `⚠️ auto-backup failed (continuing)` | **v1.2.0** — best-effort; write still proceeds |

---

## 4. Verification After Upgrade

### 4.1 Version Check

```bash
# Module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.2.0

# versionCode
su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: versionCode=1020000
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

**v1.1.0+ addition**: "Profile & Memory" section.
**v1.2.0 addition**: "Backup & Recovery" section in the default
output.

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

### 4.6 Runtime Info Check (PORT-2 + MEM-1 + BAK-1)

```bash
# Ports (PORT-2)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# v1.1.0 fields (MEM-1)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"
# Expected: {"profile_key": "<your profile>", "memory_limit_mb": <expected value>}

# v1.2.0 backups object (BAK-1)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'"
# Expected: ["available", "in_flight_txn", "last_backup", "last_backup_name",
#            "last_stable", "orphan_txn", "path"]
```

**Verify against the profile table**:

| `profile_key` | `memory_limit_mb` |
|:---:|:---:|
| `light` | 80 |
| `normal` | 100 |
| `pro` | 120 |
| `proplus` | 160 |
| `ultimate` | 220 |

### 4.7 Memory Limit Verification (v1.1.0)

```bash
# 1. Check the startup log line
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
# Expected: 🧠 v1.1.0: dynamic memory limit — profile=pro, limit=120 MB

# 2. Confirm the profile file matches
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Expected: pro (must match profile_key from §4.6)
```

### 4.8 Backup Layer Verification (v1.2.0)

```bash
# 1. Backup directory exists
su -c "ls -la /sdcard/dnscrypt-webui-backup/"

# 2. Backup state (7-field object)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"

# 3. Sanity: no in-flight or orphan transactions
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | select(.in_flight_txn > 0 or .orphan_txn > 0)'"
# Expected: no output

# 4. current/ contains all 5 files
su -c "ls /sdcard/dnscrypt-webui-backup/current/"
# Expected: webui.conf, dnscrypt-proxy.toml, selected_profile.txt,
#           allowlist.txt, denylist.txt, .manifest.json

# 5. .last_stable is set
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"
# Expected: a snapshot directory name

# 6. Cross-check with status.sh --json
diff <(su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -S '.backups'") \
     <(su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | jq -S '.backups | del(.status, .last_backup_age_seconds)'")
# Expected: no diff

# 7. Full diagnostic (Layer 10)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | head -30
```

### 4.9 Watchdog Token Verification (v1.2.0)

```bash
# Token file exists with mode 0600
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: -rw------- root root

su -c "stat -c '%a' /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: 600

# Test the recovery path
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# → DNS=UP

su -c "pkill -9 dnscrypt-proxy"
sleep 60
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# → DNS=UP (Watchdog restarted it)
```

### 4.10 Bilingual WebUI Check (v1.2.0)

```bash
# Toggle present in all three pages
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && echo '✅ index'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html && echo '✅ dashboard'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/offline.html && echo '✅ offline'"
```

**Manual test**:

1. Open `http://127.0.0.1:9090` in Chrome 88+.
2. Verify the page loads in **English**.
3. Click the `langToggle` button → the page switches to **Arabic**.
4. Verify the layout is **RTL**.
5. Reload → the preference **persists**.

### 4.11 Unified Verification Script

```bash
#!/system/bin/sh
# verify-upgrade.sh — comprehensive post-upgrade check (v1.2.0)

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
echo "=== Memory Limit (v1.1.0+) ==="
grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1

echo ""
echo "=== Backup State (v1.2.0) ==="
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'

echo ""
echo "=== Backup Directory (v1.2.0) ==="
ls -la /sdcard/dnscrypt-webui-backup/ 2>&1 | head -10

echo ""
echo "=== Watchdog Token (v1.2.0) ==="
ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token 2>&1
stat -c '%a' /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token 2>&1

echo ""
echo "=== Bilingual WebUI (v1.2.0) ==="
for f in index.html dashboard.html offline.html; do
    grep -q 'id="langToggle"' /data/adb/modules/dnscrypt-proxy-webui/web/$f && echo "✅ $f toggle"
done

echo ""
echo "✅ Verification complete"
```

Save this as `/sdcard/verify-upgrade.sh` and run:

```bash
su -c "sh /sdcard/verify-upgrade.sh"
```

---

## 5. API Behavior Notes (v1.2.0)

> **ℹ️ Important for scripts and integrations.**
>
> These are the **behaviors of v1.2.0**. They are unchanged from
> v1.0.0 and v1.1.0 except where noted. **No breaking changes**
> (except the `append_denylist` content requirement — see §5.10).

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
  "generated_at": "2026-09-29T10:30:00Z",
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

### 5.5 Unknown Actions Return 404

**Endpoint**: `GET /api?action=<unknown>`

- ❌ Unknown action → `404 Not Found` + clear message
- ✅ Known action → `200 OK`

### 5.6 Basic Auth Rate Limiting

**Any endpoint using Basic Auth**:

- 5 failed attempts → 15-minute lockout (per IP)
- Successful attempt → resets counter
- IPv6-safe (`[::1]` handled correctly)

**Recommended for scripts**: Use Cookie auth instead.

### 5.7 Runtime Info Returns Actual Ports (PORT-2) + Memory (MEM-1)

**Endpoint**: `GET /api?action=runtime_info`

**v1.2.0 response**:

```json
{
  "version": "v1.2.0",
  "bind_addr": "127.0.0.1",
  "webui_port": "9090",
  "dashboard_port": "9091",
  "profile_key": "pro",
  "memory_limit_mb": 120,
  "run_dir": "...",
  "status_file": "..."
}
```

### 5.8 `get_profile` Includes `memory_limit_mb` (v1.1.0)

**Endpoint**: `GET /api?action=get_profile`

**v1.1.0+ response**:

```json
{
  "key": "pro",
  "name": "HaGeZi PRO",
  "entries": 250000,
  "is_empty": false,
  "last_update": "2026-09-29 10:30:00",
  "memory_limit_mb": 120
}
```

### 5.9 `runtime_info.backups` — New Object (v1.2.0)

**Endpoint**: `GET /api?action=runtime_info`

**v1.2.0 addition** — a new `backups` object with **7 fields**:

```json
{
  "backups": {
    "available": 5,
    "in_flight_txn": 0,
    "orphan_txn": 0,
    "last_backup": "2026-09-29 15:00:00",
    "last_backup_name": "20260929-150000-manual-12345",
    "last_stable": "20260929-095826-v1.2.0-12345",
    "path": "/sdcard/dnscrypt-webui-backup"
  }
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
| `last_stable` | string \| null | Content of the `.last_stable` pointer |
| `path` | string | Absolute path of the backup directory |

**Client compatibility**:

- ✅ **JSON parsers** (any language): unaffected. New fields are
  ignored by code that reads only the original 5 fields.
- ⚠️ **String indexing / regex-based parsers**: may break if they
  assume a fixed field count. This is not recommended.

**Consumer pattern**:

```bash
# Correct — read only what you need
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available'

# Correct — read the whole object
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'

# WRONG — assume a fixed field count
curl -s http://127.0.0.1:9090/api?action=runtime_info | grep -o '"backups":{[^}]*}'
```

**Consistency with `status.sh --json`**:

The `status.sh --json` tool exposes the **same 7 fields** plus
**two diagnostic-only fields** (`status`, `last_backup_age_seconds`).
The two schemas match on the 7 shared fields.

**Reference**: [`docs/API.md`](API.md) §6.1.7;
[`docs/BACKUP.md`](BACKUP.md) §8.1.

### 5.10 `append_denylist` Requires `content` (v1.2.0)

**Endpoint**: `POST /api/append_denylist`

**⚠️ Breaking change for callers** — this endpoint now requires a
`content` parameter.

**Before (v1.1.0 and earlier drafts of v1.2.0)**:

- Calling with no arguments re-saved the current denylist
  unchanged — a no-op that still consumed a pre-critical backup.

**After (v1.2.0)**:

- `content` is **required**.
- Without it → `400 Bad Request`:
  ```json
  {
    "status": "error",
    "message": "Missing or empty 'content' parameter"
  }
  ```

**Correct usage**:

```bash
curl -X POST -b /tmp/cookies.txt \
    --data-urlencode "content=facebook.com
tiktok.com" \
    http://127.0.0.1:9090/api/append_denylist
```

**Alternative**: Use `POST /api/save_denylist` with the full new
content.

**Note**: The current WebUI does **not yet** send a `content`
parameter — it uses `save_denylist` for full content updates. The
WebUI-side update is planned for v1.3.0.

**Reference**: [`docs/API.md`](API.md) §6.2.7;
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §12.8.

### 5.11 Watchdog Token on `ensure_running_service` (v1.2.0)

**Endpoint**: `POST /api/ensure_running_service`

**v1.2.0 change**: The endpoint now requires an
`X-Watchdog-Token` header for localhost requests.

**Before v1.2.0**: An implicit "localhost bypass" allowed the
watchdog to call this endpoint without auth. This was exploitable
via CSRF.

**After v1.2.0**:

- The watchdog sends `X-Watchdog-Token: <token>`.
- The token file is `/data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token` (mode `0600`).
- Constant-time comparison via `subtle.ConstantTimeCompare`.

**Client compatibility**:

- ✅ **Watchdog**: updated transparently (v1.2.0 ships both).
- ⚠️ **Custom scripts** calling this endpoint: need to send the
  token.

**Correct usage** (for scripts):

```bash
TOKEN=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token")
curl -s -X POST -H "X-Watchdog-Token: $TOKEN" \
    http://127.0.0.1:9090/api/ensure_running_service | jq
```

**Reference**: [`docs/SECURITY.md`](SECURITY.md) §5.33.

### 5.12 Language Toggle Is Client-Side Only

**The API is language-neutral.** The WebUI's bilingual toggle
(English default + Arabic) is a **client-side concern only**:

- Preference stored in `localStorage['dnscrypt-lang']`.
- No API endpoint accepts or returns a language identifier.
- No server-side state.
- JSON payloads are identical regardless of the WebUI language.

**Impact on API clients**: **None.**

---

## 6. Emergency Recovery

### 6.1 If Installation Fails

```bash
# 1. Check storage
df -h /data
df -h /sdcard

# 2. Check ZIP integrity
unzip -t /sdcard/dnscrypt-webui-1.2.0-module.zip

# 3. Check required tools
su -c "which unzip sed tr date grep head cut sha256sum"

# 4. Check the install log
su -c "grep -iE 'error|fail|abort' /data/local/tmp/dnscrypt_install.log | tail -20"
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

**v1.2.0 alternative**: use recovery mode (§6.8) — it restores
the last known-good config without reinstalling.

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

**If the WebUI is running but slow after upgrade**:

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

**v1.2.0**: If the watchdog no longer restarts the DNS engine,
see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §5.15 (watchdog
token issues).

### 6.4 If Settings Are Missing

**Scenario**: The automatic restore did not run (rare).

**v1.2.0 (recommended)** — restore from the persistent backup:

```bash
# 1. Find the newest snapshot
SNAP=$(su -c "ls -1dt /sdcard/dnscrypt-webui-backup/*/ | \
       grep -vE '/(current|txn-|orphan-txn-)' | head -1" | tr -d '\r')
echo "Newest snapshot: $SNAP"

# 2. Restore the 5 files
su -c "cp $SNAP/webui.conf /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $SNAP/dnscrypt-proxy.toml /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $SNAP/selected_profile.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $SNAP/allowlist.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $SNAP/denylist.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"

# 3. Fix SELinux contexts
su -c "restorecon /data/adb/modules/dnscrypt-proxy-webui/proxy/"

# 4. Restart
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**v1.0.0 legacy mechanism** (still available if the v1.2.0 backup
is missing):

```bash
# 1. Look for the legacy backup
ls -la /data/local/tmp/dnscrypt-upgrade-backup-*

# 2. Restore manually
BACKUP=$(ls -dt /data/local/tmp/dnscrypt-upgrade-backup-* 2>/dev/null | head -1)

su -c "cp $BACKUP/webui.conf /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $BACKUP/dnscrypt-proxy.toml /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $BACKUP/selected_profile.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $BACKUP/allowlist.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $BACKUP/denylist.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"

su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Or from your manual backup**:

```bash
BACKUP=/sdcard/dnscrypt-backup-YYYYMMDD
su -c "cp $BACKUP/* /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**v1.2.0 note**: `selected_profile.txt` is critical — it drives
the memory limit. If missing, `main.go` falls back to `"pro"`.

### 6.5 Full Module Removal

**v1.2.0 change**: `uninstall.sh` **preserves** the persistent
backup directory at `/sdcard/dnscrypt-webui-backup/`. A future
reinstall will restore your settings automatically (via Layer 1).

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

# 5. v1.2.0: remove the external recovery trigger
su -c "rm -f /data/adb/dnscrypt-recovery"

# 6. Reboot
su -c "reboot"
```

**To also remove the persistent backup directory** (v1.2.0):

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

**Note**: The installer's `uninstall.sh` performs steps 1–5
automatically when the module is removed via the Magisk app.

**v1.2.0 uninstall policy summary**:

| Item | Preserved? |
|---|:---:|
| `current/` | ✅ |
| `<ts>-<version>/` snapshots | ✅ |
| `orphan-txn-*/` | ✅ |
| `.last_stable` | ✅ |
| `.upgrade_history.json` | ✅ |
| `README.md` | ✅ |
| `txn-*` with `COMMIT` or `ROLLBACK` | 🗑️ |
| Legacy v1.0.0 backup dir | 🗑️ |
| External recovery trigger | 🗑️ |

### 6.6 Recovery Checklist

| Situation | Action |
|---|---|
| Installation aborted | Check storage + ZIP integrity |
| Bootloop | Remove module from recovery, or use recovery mode (§6.8) |
| DNS not working | Restart service + check firewall |
| Settings missing | Restore from `/sdcard/dnscrypt-webui-backup/` (§6.4) |
| Dashboard broken | Check `curl 127.0.0.1:9091/api/metrics` |
| Login locked | Wait 15 min or restart WebUI |
| Firewall has orphans | Run `_legacy_cleanup_iptables` |
| WebUI slow after upgrade | Check memory profile — §6.3 |
| `profile_key` mismatch | Fix `selected_profile.txt` — §6.3 |
| **v1.2.0**: Backup directory missing | Reboot or `action.sh --backup` |
| **v1.2.0**: Watchdog not restarting DNS | Check token file — §6.8 |
| **v1.2.0**: Orphan-txn preserved | Inspect before deleting — §6.7 |
| **v1.2.0**: Recovery mode triggered unintentionally | Remove trigger file — §6.8 |

### 6.7 Backup Location Reference

| Location | Purpose | Retention |
|---|---|---|
| `/sdcard/dnscrypt-webui-backup/` | **v1.2.0** persistent backup | 21 snapshots (rotation) |
| `/sdcard/dnscrypt-webui-backup/current/` | **v1.2.0** live snapshot | Always |
| `/sdcard/dnscrypt-webui-backup/txn-*/` | **v1.2.0** in-flight transaction | Removed after commit/rollback |
| `/sdcard/dnscrypt-webui-backup/orphan-txn-*/` | **v1.2.0** preserved interrupted install | Preserved on purpose |
| `/sdcard/dnscrypt-webui-backup/.last_stable` | **v1.2.0** recovery pointer | Persistent |
| `/sdcard/dnscrypt-webui-backup/.upgrade_history.json` | **v1.2.0** upgrade log | Append-only |
| `/data/local/tmp/dnscrypt-upgrade-backup-*` | Legacy auto-backup | Deleted after restore |
| `/data/local/tmp/dnscrypt_backup_uninstall/` | Legacy uninstall backup | Removed in v1.2.0 |
| `/sdcard/dnscrypt-backup-YYYYMMDD/` | Manual backup | User-managed |

**v1.2.0 reminder**: The persistent backup directory is
**preserved** on uninstall. A future reinstall will find it
automatically via Layer 1 (multi-source detection).

### 6.8 Recovery Mode (v1.2.0)

**When to use it**:

- The module is unbootable but you can run commands via ADB.
- User data is corrupted but the backup directory is intact.
- You upgraded from a version with the v1.1.0 data-loss bug and
  want to recover from the persistent backup.

**Pre-flight checklist**:

- [ ] You have a recent snapshot:
  `su -c "ls /sdcard/dnscrypt-webui-backup/"`.
- [ ] `.last_stable` is set:
  `su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"`.
- [ ] You recorded the current profile:
  `su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"`.

**Procedure**:

```bash
# 1. Trigger recovery (module-specific)
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"

# Or, if the module folder is inaccessible (external trigger)
su -c "touch /data/adb/dnscrypt-recovery"
su -c "reboot"
```

**On next boot**: `customize.sh` runs in **recovery mode** and
restores the last known-good snapshot from
`/sdcard/dnscrypt-webui-backup/`.

**Recovery source priority**:
1. `.last_stable` → the pointer file.
2. `current/` → the live snapshot.
3. In-place `proxy/` → fallback.

**Verify the recovery** (after boot, ~60s):

```bash
# 1. All 5 files present
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/proxy/*.conf"
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/proxy/*.toml"
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/proxy/*.txt"

# 2. Profile restored
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Expected: your original profile

# 3. Trigger files consumed
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>&1"
# Expected: No such file or directory
su -c "ls /data/adb/dnscrypt-recovery 2>&1"
# Expected: No such file or directory

# 4. Full diagnostic
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

**Cleanup** (if the recovery did not complete):

```bash
su -c "rm -f /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "rm -f /data/adb/dnscrypt-recovery"
su -c "reboot"
```

**Full guide**: [`docs/EMERGENCY.md`](EMERGENCY.md) §9.

**If the watchdog no longer restarts the DNS engine**, see
[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §5.15.

### 6.9 Recovery-Mode Correctness (FIX-1, v1.2.0)

> **ℹ️ This section documents the actual implementation of
> FIX-1.** Earlier documentation incorrectly described it as
> "reorder + exclude". The correct term is
> **snapshot-and-reapply**.

**What FIX-1 actually does**:

The recovery-mode flow in `customize.sh` uses a
**snapshot-and-reapply** strategy — not a "reorder the phases and
filter the unzip argument list" strategy:

| Phase | Section | What happens |
|---|---|---|
| **A** | `§[8a]` | Restore 5 files from `$RESTORE_SOURCE` into `$MODPATH/proxy/` **AND** copy each file to `$MODPATH/.recovery_snapshot/` |
| **B** | `§[9]` | Extract the ZIP normally. This overwrites `webui.conf` and `dnscrypt-proxy.toml` with the ZIP's defaults (unavoidable without knowing the ZIP's contents) |
| **C** | `§[9b]` | Move root-level web assets into `web/` |
| **D** | `§[9b2]` | Re-apply the 5 files from `$MODPATH/.recovery_snapshot/` back into `$MODPATH/proxy/` |
| **E** | `§[9c]` | Skipped when `RECOVERY_MODE=1` — already handled by A + D |

**Why snapshot-and-reapply over "reorder + exclude"**:

- It does **not** depend on knowing what the ZIP contains. If a
  future release adds or removes files under `proxy/`, the fix
  keeps working.
- It keeps the extraction logic of `§[9]` **untouched**, so the
  normal-install path is byte-for-byte identical to the
  pre-recovery behavior.
- The snapshot directory uses `$MODPATH/.recovery_snapshot/`
  (dot-prefixed, cleaned up in `§[9b2]`), so it never appears in
  the final module layout.

**Partial re-application**: If `[9b2]` re-applies fewer files
than were snapshotted (e.g. one file is missing or empty), the
snapshot directory is **preserved** at
`$MODPATH/.recovery_snapshot/` so the user can recover the
remaining files manually.

**Verify you are on the fixed version**:

```bash
# Module version must be v1.2.0
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# → version=v1.2.0

# The snapshot directory constant must be present
su -c "grep -q 'RECOVERY_SNAPSHOT_DIR' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (snapshot dir)'"

# The re-apply block (§[9b2]) must be present
su -c "grep -q 'Re-applying recovery snapshot' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (§[9b2] re-apply block)'"
```

**If the fix is missing**: reinstall the module from the v1.2.0
ZIP.

**Full analysis**: [`SECURITY.md`](SECURITY.md) §5.32.1.
**Flow diagram**: [`ARCHITECTURE.md`](ARCHITECTURE.md) §3.10.
**Emergency procedure**: [`EMERGENCY.md`](EMERGENCY.md) §9.6.

---

## 7. References

### 7.1 Related Documentation

| Document | Purpose |
|---|---|
| [`docs/INSTALL.md`](INSTALL.md) | Installation guide |
| [`docs/BRANCHING.md`](BRANCHING.md) | Git branching strategy |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Release process guide |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records |
| [`docs/API.md`](API.md) | Full HTTP API reference (§6.1.7) |
| [`docs/SECURITY.md`](SECURITY.md) | Security policy + Audit Corrections (§5.31, §5.32, §5.33) |
| [`docs/BACKUP.md`](BACKUP.md) | **Backup system reference (v1.2.0)** |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting guide |
| [`docs/FAQ.md`](FAQ.md) | Frequently asked questions (Q111–Q130) |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | System architecture (§3.10, §4.10) |
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
| `proxy/customize.sh` | Magisk installer (10 defensive layers, §[8a] + §[9b2] for FIX-1) |
| `proxy/functions.sh` | Shared shell library (backup helpers) |
| `proxy/service.sh` | Boot service launcher + periodic auto-backup |
| `proxy/watchdog.sh` | Standalone watchdog process (token auth) |
| `proxy/action.sh` | Magisk Action button (+ `--backup`, `--diagnose`) |
| `proxy/status.sh` | Status display (+ `--diagnose`, `--json`) |
| `proxy/uninstall.sh` | Cleanup + orphan txn preservation |
| `VERSION` | Single source of truth |
| `module.prop` | Magisk module definition |
| `update.json` | Auto-update metadata |

### 7.3 External References

- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [KernelSU Documentation](https://kernelsu.org/)
- [APatch](https://github.com/bmax121/APatch)
- [Cosign (Sigstore)](https://docs.sigstore.dev/cosign/overview/)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [Android FUSE — Storage Access Framework](https://source.android.com/docs/core/storage)
- [Android SELinux — restorecon](https://source.android.com/docs/security/features/selinux)

---

<div align="center">

**Last updated**: 2026-10-02
**Version**: v1.3.0
**Author**: gasciljh

**💡 Tip**: Since v1.2.0, the persistent backup directory is
preserved on uninstall — reinstalling restores your settings
automatically!

[⬆ Back to top](#upgrade-guide--dnscrypt-smart-filter)

</div>