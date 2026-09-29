# Backup System Reference — DNSCrypt Smart Filter

Complete reference for the persistent user-data backup system
introduced in v1.2.0.

**Version**: v1.2.0
**Last updated**: 2026-09-29
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **Identifier inventory in this file (6 total)**:
>   • HARD-BK-01, HARD-BK-06, HARD-BK-16,
>     HARD-BK-17, HARD-BK-18, HARD-BK-19
>
> **NOTE ON IDENTIFIER GAPS**: BK-02 through BK-05, and
> BK-07 through BK-15 were never assigned in a released
> version — they were drafted during the v1.2.0 audit pass
> and consolidated into the six identifiers listed above
> before publication. The numbered gaps are retained so that
> future `HARD-BK-*` identifiers can reuse them without
> renumbering published entries.

> **📖 Related documents**:
> - Emergency recovery → [`EMERGENCY.md`](EMERGENCY.md)
> - Upgrade guide → [`UPGRADE.md`](UPGRADE.md) §3.1
> - Architecture → [`ARCHITECTURE.md`](ARCHITECTURE.md) §3.10, §4.10
> - Security model → [`SECURITY.md`](SECURITY.md) §5.31
> - Changelog → [`../CHANGELOG.md`](../CHANGELOG.md) §[v1.2.0]

> **v1.2.0 — this is the current release**:
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's choice is stored in `localStorage['dnscrypt-lang']`
>     and never transmitted to the server. Documentation remains
>     English-only.
>   • **FIX-1 — recovery mode uses a snapshot-and-reapply
>     strategy** (this revision): `customize.sh` restores the 5
>     user files into `$MODPATH/proxy/` **and** copies each to
>     `$MODPATH/.recovery_snapshot/` (§[8a]). The ZIP is then
>     extracted normally (§[9]) — which overwrites `webui.conf`
>     and `dnscrypt-proxy.toml` with the ZIP's defaults — and
>     finally the 5 files are re-applied from the snapshot
>     (§[9b2]). The extraction logic of §[9] is deliberately
>     left untouched, so the normal-install path is byte-for-byte
>     identical to the pre-recovery behavior. See §7.5 for the
>     full description and `ARCHITECTURE.md` §3.10 for the flow
>     diagram.
>   • `runtime_info.backups` returns **seven** fields
>     (previously five):
>       `available`, `in_flight_txn`, `orphan_txn`,
>       `last_backup`, `last_backup_name`, `last_stable`,
>       `path`.
>     See §8.1 for the full schema. This aligns the JSON
>     returned by `main.go` with the one already produced by
>     `status.sh --json` (which additionally exposes two
>     diagnostic-only fields — see §8.2).
>   • The `.manifest.json` `version` field is documented
>     accurately in §5.1: it is set to `"unknown"` for
>     snapshots created at runtime by `main.go`'s
>     `createAutoBackup()`. Only install-time snapshots
>     (created by `customize.sh`) record the actual module
>     version.
>   • §4.3 now lists **five** destructive operations that
>     trigger a pre-critical backup (previously four — the
>     fifth is `POST /api/save_custom_rules`).
>   • §9.1 clarifies that SHA256 verification is
>     **advisory**: a mismatch is logged but does not block
>     a restore.
>   • §12.5 (threat model) extended with the `backupMu`
>     serialization guarantee.
>   • All cross-references updated to point at the corrected
>     sections in `ARCHITECTURE.md` (§3.10, §4.10) and
>     `SECURITY.md` (§5.31).
>   • No structural changes — the directory layout, rotation
>     policy, and file list are identical to those introduced
>     in the original v1.2.0 draft.

> **v1.2.0 (Global Edition) — Corrections in this revision**:
>   • 🔧 **FIX-1 (snapshot-and-reapply)** — The FIX-1 description
>     in this file was corrected to match the actual
>     implementation in `customize.sh` (`§[8a]` + `§[9]` +
>     `§[9b2]`). The previous text described a
>     "reorder + exclude" strategy that was **never shipped**.
>     See the updated §7.5 below, and the authoritative
>     description in `ARCHITECTURE.md` §3.10 and
>     `SECURITY.md` §5.32.1.
>   • 🔧 **Reason string correction** — §4.3 previously listed
>     `pre-append-denylist` as the reason string for the
>     `append_denylist` operation. The actual reason string
>     recorded by `main.go` is `pre-denylist-save`, because
>     `appendDenylist` delegates to `saveDenylist` (which is
>     where the pre-critical backup is triggered). See §4.3
>     for the corrected table.

> **v1.2.0 (Global Edition) — Additional hardening in this revision**:
>   • 🛡️ **HARD-BK-01** — Every snapshot directory name in this
>     document now includes the mandatory `-<pid>` suffix (and,
>     for `main.go`-created snapshots, the additional random
>     `-<rand4>` suffix). This was introduced in v1.2.0 to
>     prevent second-level timestamp collisions between
>     concurrent backups and to give `rotate_backups` a stable
>     ordering key. See §3.2 for the full naming convention.
>   • 🛡️ **HARD-BK-06** — The `§7.2` listing command was rewritten
>     to sort by directory name (matching `rotate_backups`),
>     instead of by `mtime`. The previous command contradicted
>     the ordering rule documented in §6.5.
>   • 🛡️ **HARD-BK-16** — `§9.1` now clearly separates the
>     "at least 3 files exist" rule (part of **Layer 1**) from
>     the integrity checks (part of **Layer 3**), removing the
>     implicit confusion between the two.
>   • 🛡️ **HARD-BK-17** — The tiered retention table in `§6.1`
>     is now explicitly labelled as a planned enhancement
>     (v1.3.0), with the actual count-based policy stated
>     first.
>   • 🛡️ **HARD-BK-18** — `§4.2` now documents the BSD `stat`
>     fallback used by `functions.sh:get_last_backup_time`.
>   • 🛡️ **HARD-BK-19** — Minor formatting cleanups in §13.1.

---

## Table of Contents

1. [Why a Backup System?](#1-why-a-backup-system)
2. [The 5 Preserved Files](#2-the-5-preserved-files)
3. [Directory Layout](#3-directory-layout)
4. [Backup Triggers](#4-backup-triggers)
5. [File Formats](#5-file-formats)
6. [Retention and Rotation](#6-retention-and-rotation)
7. [Manual Operations](#7-manual-operations)
8. [Programmatic Access](#8-programmatic-access)
9. [Verification](#9-verification)
10. [Troubleshooting](#10-troubleshooting)
11. [Migration from v1.0.0 / v1.1.0](#11-migration-from-v100--v110)
12. [Security Model](#12-security-model)
13. [References](#13-references)

---

## 1. Why a Backup System?

### 1.1 The root cause

Before v1.2.0, the installer (`customize.sh`) used a
path-comparison check to detect upgrades:

```sh
if [ -d "$_EXISTING_MODULE" ] && [ "$_EXISTING_MODULE" != "$MODPATH" ]; then
    UPGRADE_DETECTED=1
fi
```

On an **in-place upgrade** (the most common case),
`$_EXISTING_MODULE` equals `$MODPATH`, so the condition was
always false. Result: the 5 user config files were silently
overwritten by the new module's defaults, and the user lost
hours of manual rule configuration.

The same bug affected:

- **Folder renames** (`DNSCrypt-Proxy-Webui`, etc.)
- **KernelSU / APatch** installs (different folder handling)
- **Reinstalls** after uninstall
- **Corrupted in-place data**

### 1.2 The fix

v1.2.0 replaces the "detect if this is an upgrade" approach with
a **"search for user data everywhere"** philosophy:

> Never ask *"is this an upgrade?"*.
> Always ask *"where is the user data?"*.

This is implemented as 10 defensive layers (see §1.3), of which
the backup system is a central piece.

### 1.3 The 10 defensive layers

| # | Layer | File | Role |
|:-:|-------|------|------|
| 1 | Multi-source detection | `customize.sh` | Search 7 candidate locations |
| 2 | Persistent backup | `customize.sh`, `functions.sh` | Snapshot to `/sdcard/` |
| 3 | Integrity verification | `customize.sh`, `functions.sh` | SHA256 + size checks |
| 4 | Transactional upgrades | `customize.sh` | Atomic with rollback |
| 5 | Root-solution compatibility | `customize.sh` | Magisk / KernelSU / APatch |
| 6 | SELinux preservation | `customize.sh`, `functions.sh` | `restorecon` / `chcon` |
| 7 | Recovery mode | `customize.sh` | Trigger file restore |
| 8 | Config migrations | `customize.sh` | Version-aware transforms |
| 9 | Automation + rotation | `service.sh`, `main.go` | Periodic + pre-critical |
| 10 | Observability | `status.sh`, `main.go` | Diagnose + runtime_info |

The backup system is **layers 2, 3, and 9**.

### 1.4 Why persistent, not tmp?

v1.1.0 (and earlier) created backups in `/data/local/tmp/`:

```sh
BACKUP_TMP="/data/local/tmp/dnscrypt-upgrade-backup-$$"
```

Two problems:

1. **`/data/local/tmp/` is cleared on reboot.** A user who
   installed the module and rebooted would lose their backup
   before they could use it.
2. **`/data/local/tmp/` is deleted on module uninstall.** A
   user who uninstalled the module then reinstalled it later
   would have no way to recover their settings.

The v1.2.0 system uses `/sdcard/dnscrypt-webui-backup/`, which:

- ✅ Survives reboots.
- ✅ Survives module uninstall.
- ✅ Survives factory reset of `/data` (but not of `/sdcard`).
- ✅ Is visible to the user from any file manager.
- ✅ Is accessible over USB (MTP).

---

## 2. The 5 Preserved Files

Only these five files are preserved. Everything else is either
rebuilt, re-downloaded, or regenerated.

| File | Purpose | Size (typical) |
|------|---------|:--------------:|
| `webui.conf` | WebUI + Dashboard ports, `BIND_ADDR`, `LOG_LEVEL` | ~500 B |
| `dnscrypt-proxy.toml` | DNSCrypt engine config + credentials | ~20 KB |
| `selected_profile.txt` | Active blocklist profile (`light`/`normal`/`pro`/`proplus`/`ultimate`) | ~5 B |
| `allowlist.txt` | User-defined allowlist | 0 B – 100 KB |
| `denylist.txt` | User-defined denylist | 0 B – 100 KB |

### 2.1 What is NOT preserved (and why)

| File | Reason |
|------|--------|
| `blocklist.txt` | Derived from `blocklist.raw` + user rules; rebuilt on every profile update |
| `blocklist.raw` | Downloaded from the internet; re-fetched |
| `public-resolvers.md` | Cache of dnscrypt-proxy's server list; regenerated |
| `blocked-ips.txt` | Static defaults; regenerated |
| `run/` | Runtime state only (PIDs, status, progress) |
| Binaries (`dnscrypt-proxy`, `dnscrypt-webui`) | Shipped fresh with each release |
| Log files | Rotated; not user data |

### 2.2 Typical snapshot size

| Content | Size |
|---------|:----:|
| Empty allowlist + denylist | ~25 KB |
| Moderate rules (~200 lines each) | ~30 KB |
| Heavy rules (~5,000 lines each) | ~120 KB |

**With the 21-snapshot cap**, total backup storage is at most ~2.5 MB.

---

## 3. Directory Layout

### 3.1 Full tree

```text
/sdcard/dnscrypt-webui-backup/
├── current/                                          ← live snapshot (always latest)
│   ├── webui.conf
│   ├── dnscrypt-proxy.toml
│   ├── selected_profile.txt
│   ├── allowlist.txt
│   ├── denylist.txt
│   └── .manifest.json
│
├── 20260926-095826-v1.2.0-12345/                     ← install snapshot (customize.sh)
│   ├── webui.conf
│   ├── ...
│   └── .manifest.json
│
├── 20260926-140000-auto-12345/                       ← periodic snapshot (service.sh)
│   └── ...
│
├── 20260926-150000-manual-12345/                     ← manual snapshot (action.sh)
│   └── ...
│
├── 20260926-152000-manual-12345-a1b2/                ← pre-critical snapshot (main.go)
│   └── ...
│
├── txn-20260926-160000-12345/                        ← in-flight transaction
│   ├── .state                                        ← "START" | "COMMIT" | "ROLLBACK"
│   ├── .pid                                          ← installer PID
│   └── <copied user files>
│
├── orphan-txn-20260925-120000-11111/                 ← preserved unfinished transaction
│   └── ...                                           ← (renamed during uninstall)
│
├── .last_stable                                      ← pointer to last known-good snapshot
├── .last_auto_backup                                 ← marker for periodic backup (mtime)
├── .upgrade_history.json                             ← full upgrade log
├── .upgrade_history.txt                              ← text fallback (no jq)
├── .pending_notification                             ← read by main.go at startup
└── README.md                                         ← user-facing guide
```

### 3.2 Directory name conventions

**⚠️ Important (v1.2.0)**: Every snapshot directory created in
v1.2.0 (and later) ends with a `-<pid>` suffix. This was added to
prevent second-level timestamp collisions when two processes start
a backup in the same wall-clock second. The `main.go` variant adds
an additional `-<rand4>` (4 random hex chars) for extra safety
against collisions from the same PID.

| Prefix / pattern | Created by | Purpose |
|------------------|-----------|---------|
| `current/` | `customize.sh`, `functions.sh` | Live snapshot — always up-to-date |
| `<timestamp>-<version>-<pid>/` | `customize.sh` at install | Historical snapshot, tagged with module version — BUG-CS-C fix |
| `<timestamp>-auto-<pid>/` | `functions.sh` on periodic trigger | Historical snapshot from `service.sh` — FSH-10 fix |
| `<timestamp>-manual-<pid>/` | `action.sh --backup`, `functions.sh` | Historical snapshot from a manual user action — ACT-5 / FSH-10 fix |
| `<timestamp>-manual-<pid>-<rand4>/` | `main.go:createAutoBackup` | Pre-critical snapshot from a destructive operation — BUG-E fix |
| `txn-<timestamp>-<pid>/` | `customize.sh` at transaction begin | In-flight upgrade transaction |
| `orphan-txn-<timestamp>-<pid>/` | `uninstall.sh` (rename) | Preserved unfinished transaction |

**Timestamp format**: `YYYYMMDD-HHMMSS` (local device time).

**`<pid>`**: the PID of the process that created the snapshot
(`customize.sh`'s PID, `action.sh`'s PID, `main.go`'s PID).

**`<rand4>`**: 4 hex characters (2 random bytes) generated by
`main.go:createAutoBackup` — additional collision protection.

**Ordering key**: directory name (`ls -1d */ | sed 's:/$::' |
grep -E '^[0-9]{8}-[0-9]{6}-' | sort -r`). The `-<pid>` and
`-<rand4>` suffixes appear *after* the timestamp, so the
lexicographic sort still produces chronological order.

### 3.3 The `current/` directory

`current/` is a **live mirror** of the most recent successful snapshot.
It is updated (via `rm -rf` + `mkdir` + copy) on every successful:

- Install / upgrade (`customize.sh`)
- Auto-backup (`service.sh` → `functions.sh`)
- Manual backup (`action.sh --backup`)
- Pre-critical backup (`main.go` → `createAutoBackup`)

`current/` is the **second-priority recovery source** in Layer 7
(after `.last_stable`, before in-place data).

### 3.4 Language preference (not preserved)

**Note**: The WebUI's language preference
(`localStorage['dnscrypt-lang']`) is **not** part of the backup.
It is:

- **Client-side only** — never transmitted to the server.
- **Stored per-browser** — different on each device that opens
  the WebUI.
- **Not in the backup directory** — the backup contains only the
  5 server-side config files.

After a fresh install or restore, the WebUI reverts to the
**default language (English)** on a fresh browser profile. If the
browser retains its `localStorage`, the previously chosen
language (e.g. Arabic) is automatically reapplied on first load.
This is intentional: the backup layer protects **user
configuration**, not **browser preferences**.

---

## 4. Backup Triggers

There are **four** triggers for a backup. Each writes a different
directory-name suffix to make the source identifiable.

### 4.1 Install / Upgrade (Layer 2)

**Trigger**: `customize.sh` runs during a module install or upgrade.

**When**: Before extraction, after the source is identified by
Layer 1 (multi-source detection).

**Target directory**: `<timestamp>-<version>-<pid>/`

**Sub-triggers**:

| Scenario | Backup created? |
|----------|:---------------:|
| Fresh install (no source found) | ❌ |
| In-place upgrade (source found) | ✅ |
| Rename-based recovery | ✅ |
| Reinstall after uninstall | ✅ (from `/sdcard/`) |

**Code reference**: `customize.sh` §[8d].

### 4.2 Periodic Auto-Backup (Layer 9)

**Trigger**: `service.sh` runs `auto_backup_if_needed()` at each boot.

**When**: If the last auto-backup is older than **24 hours** (86400 s).

**Target directory**: `<timestamp>-auto-<pid>/`

**Marker file**: `.last_auto_backup` (empty file; its mtime is read
via `stat -c %Y` with a BSD `stat -f %m` fallback — see
`functions.sh:get_last_backup_time`).

**Behavior**:

- First boot after a fresh install: creates a backup.
- Subsequent boots: skips if within 24 h.
- After 24 h: creates a new backup, then runs rotation.

**Code reference**: `functions.sh` §[26] `auto_backup_if_needed`.

### 4.3 Pre-Critical Backup (Layer 9)

**Trigger**: `main.go` calls `createAutoBackup(reason)` before a
destructive operation.

**When**: Immediately before any of these **five** operations:

| Operation | Reason string | Endpoint |
|-----------|---------------|----------|
| Profile change | `pre-profile-change` | `POST /api/update_profile` |
| Allowlist save | `pre-allowlist-save` | `POST /api/save_allowlist` |
| Denylist save | `pre-denylist-save` | `POST /api/save_denylist` |
| Combined rules save | `pre-custom-rules-save` | `POST /api/save_custom_rules` |
| Append denylist | `pre-denylist-save` (via `saveDenylist`) | `POST /api/append_denylist` |

**Reason string note (this revision)**: The `append_denylist`
endpoint does not call `createAutoBackup` directly. It delegates
to `saveDenylist`, which is where the pre-critical backup is
triggered with the reason `pre-denylist-save`. The previous
revision of this table listed a fictional reason string
`pre-append-denylist` that does not exist anywhere in the code.
The corrected table above matches the actual implementation
(`main.go` §[26] `appendDenylist` + §[26] `saveDenylist`).

**Target directory**: `<timestamp>-manual-<pid>-<rand4>/` (the
suffix is `-manual` because these are triggered by user actions —
the "pre-critical" nature is recorded only in the log line, not in
the directory name). The `<rand4>` suffix is specific to
`main.go`-created snapshots; `action.sh --backup` uses
`<timestamp>-manual-<pid>/` (no random suffix).

**Serialization (v1.2.0)**: `main.go` holds a `sync.Mutex`
(`backupMu`) for the entire duration of the shell invocation
(bounded by `AUTO_BACKUP_TIMEOUT = 15 s`). This prevents two
rapid user actions from triggering overlapping backups on the
same source directory. See §12.5 for the threat model.

**Best-effort**: If the backup fails, a warning is logged but the
destructive operation proceeds. The backup must **never** block
the user's intent.

**Code reference**: `main.go` §[36b] `createAutoBackup`.

### 4.4 Manual Backup (CLI)

**Trigger**: User runs `action.sh --backup`.

**When**: Anytime.

**Target directory**: `<timestamp>-manual-<pid>/`

**Behavior**:

- Backs up the 5 user config files.
- Writes `.manifest.json`.
- Rotates old snapshots (keep 21).
- Prints the current backup state (snapshot count + age).

**Code reference**: `action.sh` §[13].

### 4.5 Trigger summary table

| Trigger | Automatic? | Suffix | Frequency |
|---------|:----------:|--------|-----------|
| Install / Upgrade | ✅ | `<version>-<pid>` | Per install |
| Periodic | ✅ | `auto-<pid>` | Max 1 per 24 h |
| Pre-critical (main.go) | ✅ | `manual-<pid>-<rand4>` | Per destructive op |
| Manual (action.sh) | ❌ | `manual-<pid>` | User-initiated |

---

## 5. File Formats

### 5.1 `.manifest.json` (per snapshot)

Every snapshot directory contains a `.manifest.json` file:

```json
{
  "version": "v1.2.0",
  "timestamp": "20260926-095826",
  "source": "/data/adb/modules/dnscrypt-proxy-webui/proxy",
  "root_solution": "magisk",
  "files_count": 5,
  "files": [
    {
      "name": "webui.conf",
      "sha256": "a1b2c3d4e5f6..."
    },
    {
      "name": "dnscrypt-proxy.toml",
      "sha256": "f6e5d4c3b2a1..."
    },
    {
      "name": "selected_profile.txt",
      "sha256": "1234567890ab..."
    },
    {
      "name": "allowlist.txt",
      "sha256": "abcdef123456..."
    },
    {
      "name": "denylist.txt",
      "sha256": "654321fedcba..."
    }
  ]
}
```

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Module version at the time of the snapshot, **or** `"unknown"` for runtime snapshots |
| `timestamp` | string | `YYYYMMDD-HHMMSS` |
| `source` | string | Absolute path of the source directory |
| `root_solution` | string | `magisk` / `kernelsu` / `apatch` / `unknown` |
| `files_count` | number | Number of files successfully copied (0–5) |
| `files` | array | Per-file metadata |
| `files[].name` | string | File name (no path) |
| `files[].sha256` | string | SHA256 hash, or empty if `sha256sum` is unavailable |

> **⚠️ Accuracy note (v1.2.0)**:
>
> The `version` field is **not always** the module version. It
> depends on which code path created the snapshot:
>
> | Creator | `version` value | `root_solution` value |
> |---|---|---|
> | `customize.sh` (install / upgrade) | Actual module version (e.g. `v1.2.0`) | Detected at install time |
> | `main.go:createAutoBackup` | **`"unknown"`** | **`"unknown"`** |
> | `action.sh --backup` (via `functions.sh:backup_user_files`) | **`"unknown"`** | **`"unknown"`** |
> | `service.sh:auto_backup_if_needed` | **`"unknown"`** | **`"unknown"`** |
>
> The reason: at runtime, `main.go` and the shell helpers do not
> read `module.prop` to determine the version. They pass a
> literal `"unknown"` to `write_manifest` (see
> `functions.sh:write_manifest`, argument 4).
>
> **Consumer impact**: A tool that reads `.manifest.json` for
> verification (e.g. `verify_backup_integrity`) must treat
> `version` as advisory. The **integrity** check is based on the
> per-file `sha256` hashes, not on `version`. Likewise, the
> **directory name** must be treated as advisory: the
> `<pid>` and `<rand4>` suffixes vary per snapshot, so tools
> must match on the `<timestamp>-` prefix, not on the exact
> directory name.

**Usage**: `.manifest.json` is used by:

- **Layer 3** (integrity verification) — see §9.
- **Layer 10** (observability) — `runtime_info.backups` reads
  the count and metadata, not the contents of each file.

**Note**: The manifest is **advisory**. Missing or invalid manifests
do not block a restore.

### 5.2 `.last_stable` (single line)

Contains the **directory name** (not path) of the last known-good
snapshot:

```text
20260926-095826-v1.2.0-12345
```

**Updated when**: A snapshot is created by `customize.sh` and
verification passes.

**Read by**:

- `customize.sh` §[8a] (recovery mode).
- `main.go:buildBackupInfo()` (exposed as `runtime_info.backups.last_stable`).
- `status.sh --json` (exposed as `.backups.last_stable`).
- `status.sh --diagnose` (informational display).

**Note**: This file is **not** updated by runtime backups
(`main.go`, `service.sh`, `action.sh`). Only install-time
snapshots update `.last_stable`. This is deliberate: the pointer
must reference a version-tagged snapshot, not a runtime snapshot
whose `version` field is `"unknown"`.

### 5.3 `.last_auto_backup` (empty marker file)

An empty file whose **mtime** is used as the "last auto-backup
timestamp".

**Created/updated by**: `functions.sh:auto_backup_if_needed`.

**Read by**:

```sh
stat -c %Y "$PERSISTENT_BACKUP/.last_auto_backup" \
  || stat -f %m "$PERSISTENT_BACKUP/.last_auto_backup" \
  || echo 0
```

If the marker is missing, the age is treated as 0 → backup runs
immediately.

### 5.4 `.upgrade_history.json` (append-only log)

A JSON file that records every install / upgrade:

```json
{
  "upgrades": [
    {
      "from": "v1.1.0",
      "to": "v1.2.0",
      "date": "2026-09-26T10:30:00Z",
      "source": "/data/adb/modules/dnscrypt-proxy-webui/proxy",
      "root": "magisk",
      "files": 5
    }
  ]
}
```

**Written by**: `customize.sh:log_upgrade()` when `jq` is available.

**Fallback (no `jq`)**: A plain-text `.upgrade_history.txt`:

```text
2026-09-26T10:30:00Z | v1.1.0 → v1.2.0 | source=/data/adb/modules/dnscrypt-proxy-webui/proxy | files=5
```

**Rotation**: The history file is **not rotated** — it grows slowly
(~200 bytes per upgrade), so a few hundred KB after 1,000 upgrades.

### 5.5 `.pending_notification` (transient)

A single-line file written by `customize.sh` after a successful
restore during an upgrade.

**Read by**: `main.go:checkPendingNotifications()` at startup.

**Action**: Content is logged, then the file is deleted by
`main.go` (only). `service.sh` reads the file too (for the boot
log) but does **not** delete it — the deletion is centralized in
`main.go` to avoid a race where both processes could delete it
before the other reads it.

**Typical content**:

```text
Restored 5 user files from backup
```

### 5.6 `README.md` (user guide)

A static user-facing guide generated on first install. It explains:

- What is backed up (the 5 files).
- The directory structure.
- How rotation works.
- How to restore manually.
- How to trigger recovery mode.

**Never auto-updated** after creation — the user can edit it freely.

---

## 6. Retention and Rotation

### 6.1 Policy (actual implementation)

Rotation caps the number of snapshots at **21**. The implementation
is **count-based**: it keeps the 21 newest snapshots, sorted by
**directory name** (not by mtime — see §6.5).

There are no daily / weekly / monthly tiers today.

**Planned enhancement (v1.3.0)**: The following tiered policy is
under consideration for a future release, but is **not**
implemented in v1.2.0:

| Tier (planned) | Count | Typical age |
|----------------|:-----:|-------------|
| Daily | 5 | 0–5 days |
| Weekly | 4 | 1–4 weeks |
| Monthly | 12 | 1–12 months |
| **Total** | **21** | — |

The 21-cap is the immediate protection against unbounded growth.
Tier-based rotation is tracked in `docs/ROADMAP.md` §5.

### 6.2 When rotation runs

Rotation runs **after** a successful backup, triggered by:

- `service.sh:rotate_backups 21` (after periodic auto-backup).
- `action.sh --backup` (after manual backup).

**Not triggered** by `customize.sh` or `main.go` backups — the
periodic and manual flows are the only ones that rotate.

### 6.3 What is never rotated

| Item | Reason |
|------|--------|
| `current/` | Always needed for recovery |
| `txn-*/` | In-flight transactions |
| `orphan-txn-*/` | Preserved unfinished transactions |
| `.last_stable` | Recovery pointer |
| `.last_auto_backup` | Age marker |
| `.upgrade_history.json` / `.txt` | Audit trail |
| `README.md` | User guide |

### 6.4 Storage footprint

| Scenario | Snapshot count | Total size |
|----------|:--------------:|:----------:|
| Fresh install, no history | 1 (current only) | ~25 KB |
| Typical user (5 snapshots) | 5 | ~150 KB |
| Heavy user (21 snapshots) | 21 | ~2.5 MB |
| With orphan transactions | +1–3 | +~100 KB |

**Max theoretical footprint**: ~3 MB. This is negligible on any
modern Android device.

### 6.5 Rotation ordering — directory name vs mtime

**⚠️ Important implementation detail**:

`rotate_backups` sorts snapshots by **directory name**, not by
modification time. Directory names start with `YYYYMMDD-HHMMSS-`,
which produces the same order as the timestamps without relying
on the filesystem's `mtime` field.

**Why this matters**:

- If a user copies their backup directory to a new device with
  `rsync` or a similar tool, `mtime` values are preserved but
  may be reordered by the tool (e.g. `rsync -a` preserves
  `mtime`, but manual `cp` does not).
- Directory name ordering is **stable** across these operations.
- The three rotation implementations
  (`customize.sh:rotate_backups`, `functions.sh:rotate_backups`,
  `service.sh:_inline_rotate_backups`) all use the same rule:

  ```sh
  ls -1d */ | sed 's:/$::' | grep -E '^[0-9]{8}-[0-9]{6}-' | sort -r
  ```

  The regex `^[0-9]{8}-[0-9]{6}-` matches:
  - `20260926-095826-v1.2.0-12345`
  - `20260926-095826-auto-12345`
  - `20260926-095826-manual-12345`
  - `20260926-095826-manual-12345-a1b2`

  and **rejects**:
  - `current`
  - `txn-...`
  - `orphan-txn-...`
  - any file (not directory)

---

## 7. Manual Operations

### 7.1 Create a manual backup

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

**Expected output** (matches `action.sh` §[13]):

```text
╔════════════════════════════════════════════════════════╗
║  💾 DNSCrypt – Manual Backup                           ║
╚════════════════════════════════════════════════════════╝

  Source: /data/adb/modules/dnscrypt-proxy-webui/proxy
  Target: /sdcard/dnscrypt-webui-backup

  ✅ Backup created: /sdcard/dnscrypt-webui-backup/20260926-150000-manual-12345 (5 file(s))

  Current backup state:
    7 snapshot(s), latest 0s ago
```

If the backup fails (0 files copied), the script exits with code 3.

> **Note**: The PID suffix (`-12345`) depends on the `action.sh`
> process's own PID, so it varies on each invocation. The
> directory-name pattern is `<timestamp>-manual-<pid>` — see
> §3.2 for the exact conventions.

### 7.2 List snapshots

**Correct** — sort by directory name (matching `rotate_backups`):

```bash
su -c "cd /sdcard/dnscrypt-webui-backup && ls -1d */ | sed 's:/$::' | grep -E '^[0-9]{8}-[0-9]{6}-' | sort -r"
```

Or via the CLI diagnose tool:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | grep -A 20 "Backups"
```

**⚠️ HARD-BK-06 fix**: The previous version of this section used
`ls -1dt`, which sorts by `mtime`. That contradicted the
directory-name ordering rule documented in §6.5 and would have
produced inconsistent results on a device where `mtime` was
modified (e.g. after a manual `cp`). The command above uses
`sort -r` on the directory name — the same rule as
`rotate_backups`.

### 7.3 Inspect a snapshot

```bash
# Replace <pid> with the actual PID from the directory name
su -c "ls -la /sdcard/dnscrypt-webui-backup/20260926-095826-v1.2.0-12345/"
su -c "cat /sdcard/dnscrypt-webui-backup/20260926-095826-v1.2.0-12345/.manifest.json"
```

### 7.4 Restore manually

```bash
# 1. Identify the desired snapshot (replace <pid> with the real PID)
SNAP="20260926-095826-v1.2.0-12345"

# 2. Copy the 5 files back
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/webui.conf /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/dnscrypt-proxy.toml /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/selected_profile.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/allowlist.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/denylist.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"

# 3. Fix SELinux contexts
su -c "restorecon /data/adb/modules/dnscrypt-proxy-webui/proxy/"

# 4. Restart the service
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Tip**: To pick the newest snapshot programmatically (using the
same ordering as `rotate_backups`):

```bash
SNAP=$(su -c "cd /sdcard/dnscrypt-webui-backup && ls -1d */ | sed 's:/$::' | grep -E '^[0-9]{8}-[0-9]{6}-' | sort -r | head -n1")
echo "Newest snapshot: $SNAP"
```

### 7.5 Trigger recovery mode

If the module is unbootable or user data is corrupted:

```bash
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"
```

On next boot, `customize.sh` restores the last known-good snapshot
and continues with the normal install flow. See
[`EMERGENCY.md`](EMERGENCY.md) for the full procedure.

**⚠️ v1.2.0 fix (snapshot-and-reapply)**: In earlier drafts of
v1.2.0, recovery mode had a bug where the ZIP extraction step
(`customize.sh` §[9]) overwrote `webui.conf` and
`dnscrypt-proxy.toml` **after** the recovery restore (`§[8a]`),
and the subsequent restore step (`§[9c]`) was skipped in recovery
mode — so 2 of the 5 restored files were silently lost.

The final v1.2.0 release uses a **snapshot-and-reapply** strategy
that keeps the extraction logic of `§[9]` untouched and does not
depend on knowing what the ZIP contains:

| Phase | Section | What happens |
|-------|---------|--------------|
| **A** | `§[8a]` | Restore 5 files from `$RESTORE_SOURCE` into `$MODPATH/proxy/` **AND** copy each one to `$MODPATH/.recovery_snapshot/` (via `copy_with_context`). |
| **B** | `§[9]`  | Extract the ZIP normally. This step overwrites `webui.conf` and `dnscrypt-proxy.toml` with the ZIP's defaults — unavoidable without knowing the ZIP's contents. |
| **C** | `§[9b]` | Move root-level web assets into `web/`. |
| **D** | `§[9b2]`| Re-apply the 5 files from `$MODPATH/.recovery_snapshot/` back into `$MODPATH/proxy/`. |
| **E** | `§[9c]` | Skipped when `RECOVERY_MODE=1` — already handled by A + D. |

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

**Partial re-application**: If `§[9b2]` re-applies fewer files
than were snapshotted (e.g. one file is missing or empty), the
snapshot directory is **preserved** at
`$MODPATH/.recovery_snapshot/` so the user can recover the
remaining files manually.

See `ARCHITECTURE.md` §3.10 for the full flow, and
`SECURITY.md` §5.32.1 for the security analysis.

### 7.6 Delete a snapshot

```bash
# Replace <pid> with the actual PID
su -c "rm -rf /sdcard/dnscrypt-webui-backup/20260924-140000-v1.0.0-12345"
```

### 7.7 Delete everything

> ⚠️ **Destructive**: This removes all backups. The user data
> currently in the module's `proxy/` directory is **not** affected.

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

The next boot will recreate the directory (empty).

### 7.8 Copy backups off-device

```bash
# From PC (with adb + root)
adb shell su -c "tar czf /sdcard/dnscrypt-backup-$(date +%Y%m%d).tar.gz /sdcard/dnscrypt-webui-backup"
adb pull /sdcard/dnscrypt-backup-20260926.tar.gz
```

### 7.9 What about the language preference?

The WebUI's language preference (`localStorage['dnscrypt-lang']`)
is **not** part of any backup:

- It lives in the **browser's** `localStorage`, not on the device
  filesystem.
- It is **per-browser**, per-profile. It cannot be exported by
  the module.
- Restoring a snapshot does **not** change the WebUI's language.

If you want a **specific language on a new device**, open the
WebUI once and toggle the language with the `langToggle` button.
The choice is remembered on that device's browser.

---

## 8. Programmatic Access

### 8.1 Via `runtime_info` (recommended)

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
```

**Response (v1.2.0 — 7 fields)**:

```json
{
  "available": 7,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-09-26 15:00:00",
  "last_backup_name": "20260926-150000-manual-12345",
  "last_stable": "20260926-095826-v1.2.0-12345",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `available` | int | Number of snapshots (excludes `current/`, `txn-*/`, `orphan-txn-*/`) |
| `in_flight_txn` | int | Number of `txn-*` directories (install in progress or interrupted) |
| `orphan_txn` | int | Number of `orphan-txn-*` directories (preserved interrupted installs) |
| `last_backup` | string \| null | Modification time of the newest snapshot |
| `last_backup_name` | string \| null | Directory name of the newest snapshot (e.g. `20260926-150000-manual-12345`) |
| `last_stable` | string \| null | Content of the `.last_stable` pointer file, or null if not set |
| `path` | string | Absolute path of the backup directory |

**Displayed in**: WebUI and Dashboard System Info panels.

**Read-only**: `runtime_info` does not create or modify backups.

**Consumer pattern**: If `in_flight_txn > 0` or `orphan_txn > 0`,
the backup layer needs attention — see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §7.8–§7.10.

**Language-neutral**: The `backups` object is identical regardless
of the WebUI's selected language (English default or Arabic
toggle). The API never localizes JSON.

### 8.2 Via `status.sh --json`

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups'
```

**Response (same 7 fields as `runtime_info`)**:

```json
{
  "status": "ok",
  "available": 7,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-09-26 15:00:00",
  "last_backup_name": "20260926-150000-manual-12345",
  "last_backup_age_seconds": 3600,
  "last_stable": "20260926-095826-v1.2.0-12345",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

**`status.sh --json` adds two fields that `runtime_info` does not
expose**:

- `status` — `"ok"` / `"empty"` / `"missing"`.
- `last_backup_age_seconds` — numeric age (for scripting).

**Consistency guarantee (v1.2.0)**: The two schemas now match on
the seven shared fields. If they ever diverge, it indicates a
`main.go` / `status.sh` version mismatch — restart the WebUI and
re-run the commands.

### 8.3 Via `status.sh --check` (one-liner)

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
```

**Output example**:

```text
v1.2.0 | DNS=UP | WEBUI=UP | PROFILE=pro | MEM=120 MB (pro) | ENTRIES=250000 | BACKUP=7snap/1h ago | RUNDIR=/data/adb/modules/dnscrypt-proxy-webui/proxy/run
```

The `BACKUP=` field format is `<count>snap/<age>`.

### 8.4 Via `status.sh --diagnose`

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

Produces a full human-readable report including:

- System + module info.
- The 5 user data files with size + mtime.
- Backup listing (sorted by name).
- In-flight + orphan transaction listings.
- Recovery mode state.
- Pending notification content.
- Health checks with a final ✅ / ⚠️ / ❌.

---

## 9. Verification

### 9.1 Integrity checks — Layer 3

**Layer 3** (integrity verification) runs on every snapshot before
use. The checks are:

1. **Non-empty**: File exists and has size > 0.
2. **Not oversized**: File size < 10 MB (rejects corrupted uploads).
3. **SHA256 (advisory)**: `.manifest.json` records each file's
   hash. A mismatch is **logged as a warning** but does **not**
   block a restore. Rationale: The snapshot was just created from
   the same source; a mismatch would indicate a filesystem issue,
   but refusing to restore would be worse than restoring with a
   warning.

**A separate rule belongs to Layer 1, not Layer 3**:

- **Source selection** (part of **Layer 1** — multi-source
  detection): At least **3 of the 5** files must exist in a
  candidate directory for it to be selected as the source. A
  candidate with fewer than 3 files is skipped.

The two layers are intentionally separate: **Layer 1** decides
*where* the user data lives; **Layer 3** validates the quality of
the snapshot once it has been created. Both use overlapping file
lists, but they answer different questions.

**⚠️ v1.2.0 accuracy note**: `verify_backup_integrity()` performs
a **real** SHA256 comparison (not just size). The implementation
uses a 3-tier extraction to read the expected hash from
`.manifest.json`:

1. `jq` (most robust, handles multi-line JSON).
2. `awk` (fallback, handles multi-line JSON with regex escaping).
3. `grep` + `sed` (last resort, fragile with escaped chars).

If none of the three tiers extracts a hash (e.g. `sha256sum` is
unavailable, or the manifest is malformed), the check is **skipped
for that file** rather than failing. This is deliberate: the
integrity layer must never block a restore on a device where the
tooling is minimal.

### 9.2 Running verification manually

```bash
# Pick the newest snapshot by directory name
cd /sdcard/dnscrypt-webui-backup
SNAP=$(ls -1d */ | sed 's:/$::' | grep -E '^[0-9]{8}-[0-9]{6}-' | sort -r | head -1)
echo "Verifying: $SNAP"

# Check each file
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
    if [ -s "$SNAP/$f" ]; then
        echo "  ✅ $f ($(wc -c < "$SNAP/$f") bytes)"
    else
        echo "  ❌ $f (missing or empty)"
    fi
done

# Check manifest (if jq is available)
if [ -f "$SNAP/.manifest.json" ]; then
    echo "  📋 manifest: $(jq -r '.files_count' "$SNAP/.manifest.json") files"
else
    echo "  ⚠️  manifest missing"
fi
```

### 9.3 Full diagnose report

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §15.14 for the
full report format.

---

## 10. Troubleshooting

### 10.1 No backups appear

**Symptom**: `runtime_info.backups.available` is 0.

**Possible causes**:

1. **Fresh install** — no snapshot has been created yet.
   - **Fix**: Wait for the first boot (auto-backup runs) or
     trigger a manual backup.
2. **`/sdcard/` not mounted** — early in boot, `/sdcard/` may not
   be available.
   - **Check**: `su -c "ls /sdcard/"` should succeed.
3. **Directory permissions** — rare, but possible if `/sdcard/`
   has restrictive SELinux contexts.
   - **Check**: `su -c "ls -ld /sdcard/dnscrypt-webui-backup/"`

### 10.2 Snapshot exists but cannot be restored

**Symptom**: `customize.sh` reports "Restore failed".

**Possible causes**:

1. **Permissions**: Files must be readable by root.
   - **Fix**: `su -c "chmod 0600 /sdcard/dnscrypt-webui-backup/<snap>/*"`
2. **SELinux**: Files may have lost their `magisk_file` context.
   - **Fix**: `su -c "restorecon -R /sdcard/dnscrypt-webui-backup/"`
3. **Corrupt files**: A file is unreadable (bad sectors).
   - **Fix**: Try an older snapshot.

### 10.3 Rotation did not run

**Symptom**: More than 21 snapshots accumulate.

**Possible causes**:

1. **`service.sh` did not run** — check the main log:
   ```bash
   su -c "grep 'rotate_backups' /data/local/tmp/dnscrypt_main.log | tail"
   ```
2. **`functions.sh` missing** — the inline fallback may have
   failed silently.
   - **Check**: `su -c "ls -l /data/adb/modules/dnscrypt-proxy-webui/functions.sh"`

**Fix**: Run rotation manually:

```bash
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; rotate_backups 21"
```

### 10.4 Manual backup failed

**Symptom**: `action.sh --backup` exits with code 3.

**Possible causes**:

1. **Source directory missing**:
   ```bash
   su -c "ls /data/adb/modules/dnscrypt-proxy-webui/proxy/"
   ```
2. **All source files empty**:
   ```bash
   su -c "wc -c /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
   ```
3. **`/sdcard/` full**:
   ```bash
   su -c "df -h /sdcard"
   ```

### 10.5 Orphan transaction preserved

**Symptom**: An `orphan-txn-*/` directory appeared after uninstall.

**Meaning**: A previous install was interrupted mid-transaction.
The orphan contains the user data as it existed at that moment.
It is **preserved on purpose** — do not delete it blindly.

**Action**: Inspect it, then decide:

```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/orphan-txn-*/"
su -c "cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.state"
```

### 10.6 `backups` schema mismatch (v1.2.0)

**Symptom**: `runtime_info.backups` returns 5 fields (older shape)
while `status.sh --json` returns 7, or vice versa.

**Cause**: A version mismatch between `main.go` and
`status.sh`. This should not occur on v1.2.0 — both were updated
in the same release.

**Fix**:

1. Confirm the module version:
   ```bash
   su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
   ```
   → must be `version=v1.2.0`.

2. If the binary is stale (older than the scripts), reinstall
   the module from the v1.2.0 ZIP.

3. After fixing, restart the WebUI and re-run:
   ```bash
   su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
   curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'
   # → ["available", "in_flight_txn", "last_backup", "last_backup_name", "last_stable", "orphan_txn", "path"]
   ```

### 10.7 Language preference not restored (v1.2.0)

**Symptom**: After restoring a snapshot to a new device, the WebUI
opens in English even though the user had chosen Arabic on the
previous device.

**Cause**: This is **by design**, not a bug:

- The language preference lives in the **browser's**
  `localStorage['dnscrypt-lang']`.
- It is **client-side only** — never transmitted to the server.
- It is **not** part of the 5 preserved config files.
- Restoring server-side config does not affect browser storage.

**Fix**: Open the WebUI on the new device and click the
`langToggle` button once. The choice is remembered locally.

**If you want to preserve the choice across browsers**: This is
not supported by design (the project's design explicitly keeps
the language preference out of the server state to avoid adding
a user-tracking dimension). Community forks may extend this.

---

## 11. Migration from v1.0.0 / v1.1.0

### 11.1 From v1.1.0 (in-place)

**The upgrade is automatic.** No manual steps.

What happens during the upgrade:

1. `customize.sh` runs the multi-source detection (Layer 1).
2. It searches for the 5 user files in this order:
   - `$MODPATH/proxy` (in-place)
   - `/data/adb/modules/dnscrypt-proxy-webui/proxy` (standard)
   - `/data/adb/modules/DNSCrypt-Proxy-Webui/proxy` (legacy)
   - `/data/adb/modules/DNSCrypt-Proxy-WebUI/proxy` (variant)
   - `/sdcard/dnscrypt-webui-backup/current` (persistent)
   - `/sdcard/dnscrypt-webui-backup` (flat)
   - `/data/local/tmp/dnscrypt-webui-backup` (tmp fallback)
   - **On APatch**: `/data/adb/modules_update/dnscrypt-proxy-webui/proxy` and
     `/data/adb/modules_update/DNSCrypt-Proxy-Webui/proxy` are
     prepended to the list.
3. The first candidate with **≥ 3 valid files** wins.
4. A snapshot is created in `/sdcard/dnscrypt-webui-backup/`
   (name: `<timestamp>-<version>-<pid>`).
5. The transaction is committed.

**Result**: All 5 files are preserved, and a snapshot is created
for future recovery.

**Language note**: Upgrading from v1.1.0 preserves the user's
WebUI language preference (`localStorage['dnscrypt-lang']`) in
the browser. The WebUI continues to load in the previously
chosen language.

### 11.2 From v1.0.0 (in-place)

Same as v1.1.0, **plus**:

- **Config migration** (Layer 8): `MEMORY_LIMIT_HINT=auto` is added
  to `webui.conf` if missing.
- **Legacy backup cleanup**: `/data/local/tmp/dnscrypt_backup_uninstall/`
  (a v1.0.0 artifact) is removed automatically by `uninstall.sh`.

### 11.3 From a pre-v1.0.0 version

Same as v1.0.0, **but** the user data may not exist in the standard
locations. If nothing is found:

1. The installer proceeds as a fresh install.
2. Default config files are created.
3. **The user must reapply their custom rules manually.**

**Recommendation for pre-v1.0.0 users**: Before upgrading, take a
manual backup:

```bash
su -c "mkdir -p /sdcard/manual-backup"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf /sdcard/manual-backup/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml /sdcard/manual-backup/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/allowlist.txt /sdcard/manual-backup/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/denylist.txt /sdcard/manual-backup/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt /sdcard/manual-backup/"
```

Then upgrade and restore if needed (see §7.4).

### 11.4 No-op migrations

If the `SOURCE_VERSION` matches `TARGET_VERSION`, `migrate_config()`
does nothing. This is the case for v1.2.0 → v1.2.0 reinstalls.

### 11.5 Language preference across migrations

The WebUI's language toggle (English default + Arabic) is
**not affected** by any migration path:

- It is **client-side only** (`localStorage['dnscrypt-lang']`).
- It is **not** part of the 5 preserved files.
- It **does not** participate in `migrate_config()`.
- It **survives** every upgrade, downgrade, or reinstall —
  because it lives in the browser, not on the module.

After a migration, the WebUI may briefly load in English (default)
before the browser's `localStorage` is read and reapplied. This
is expected and only lasts for the first render frame.

---

## 12. Security Model

### 12.1 Permissions

| Path | Mode | Owner | Rationale |
|------|:----:|:-----:|-----------|
| `/sdcard/dnscrypt-webui-backup/` | `0700` | root | Owner-only |
| Snapshot directories | `0700` | root | Owner-only |
| Snapshot files | `0600` | root | Owner-only |
| `.manifest.json` | `0600` | root | Owner-only |
| `.last_stable` | `0600` | root | Owner-only |
| `.upgrade_history.json` | `0600` | root | Owner-only |
| `README.md` | `0644` | root | Readable by user |

**Note**: On Android, `/sdcard/` is typically a FUSE mount.
Permission semantics differ from ext4. The `0700`/`0600` modes
are enforced by the underlying storage layer where possible; the
primary protection is that `/sdcard/` is only accessible to apps
with `READ_EXTERNAL_STORAGE` or root.

### 12.2 What backups contain

| Data | Included? | Sensitivity |
|------|:---------:|-------------|
| WebUI/Dashboard ports | ✅ | Low |
| `BIND_ADDR` | ✅ | Low |
| `LOG_LEVEL` | ✅ | Low |
| DNSCrypt credentials (in TOML) | ✅ | **High** |
| `selected_profile.txt` | ✅ | Low |
| User rules (allowlist/denylist) | ✅ | Medium |
| DNSCrypt server list cache | ❌ | N/A |
| Binaries | ❌ | N/A |
| Log files | ❌ | N/A |
| **WebUI language preference** | **❌** | **N/A (browser-side only)** |

**Note**: The DNSCrypt credentials (username/password for the
internal monitoring_ui) are included because they live in
`dnscrypt-proxy.toml` → `[monitoring_ui]`. The snapshot directory
is `0700`, so only root can read them.

**Language preference note**: The WebUI language choice is
**never included** in backups — because it lives in the browser,
not on the device. This is a deliberate design decision: the
backup layer preserves server-side **user configuration**, not
**client-side UI preferences**.

### 12.3 SELinux contexts

Every copied file receives its original SELinux context:

- **Preferred**: `restorecon` (reads `file_contexts` and applies
  the correct context).
- **Fallback**: `chcon u:object_r:magisk_file:s0` (hardcoded
  context used by Magisk modules).

If neither tool is available, the copy succeeds without context
restoration. This is rare on Android (both tools exist in
`/system/bin/`).

### 12.4 Integrity guarantees

| Threat | Mitigation |
|--------|-----------|
| Bit rot in a snapshot | SHA256 in `.manifest.json` (advisory) |
| Empty/truncated file | Non-empty + size checks before restore |
| Malicious file substitution | Not mitigated (root-only directory) |
| Unauthorized read | `0700`/`0600` permissions |
| Directory deletion | `current/` and `.last_stable` ensure at least one recovery path |

### 12.5 Threat model summary

The backup system assumes:

- ✅ The device is rooted.
- ✅ `/sdcard/` is mounted and writable by root.
- ❌ The backup directory is **not** protected from a malicious
  root app.

**`backupMu` — serialization guarantee (v1.2.0)**:

Two concurrent calls to `createAutoBackup` (e.g. from two rapid
user actions) could each operate on the same source directory.
Without serialization, this would result in two concurrent
shell invocations writing to the same `.manifest.json` and to
the same `.tmp` files, with the possibility of a corrupted
snapshot.

`main.go` holds a single `sync.Mutex` (`backupMu`) for the
entire duration of the shell invocation
(`runShellWithTimeout(..., AUTO_BACKUP_TIMEOUT = 15 s)`). The
second caller blocks until the first finishes. See
`ARCHITECTURE.md` §4.3 for the full concurrency model.

**What `backupMu` does NOT protect against**:

- A user manually running `action.sh --backup` while the WebUI
  is also triggering a pre-critical backup. `action.sh` is a
  shell script; it does not coordinate with `main.go`'s mutex.
  In practice this is safe because the shell script uses
  `<pid>`-suffixed directory names (see §3.2) and atomic writes
  for the manifest. The worst case is a duplicate snapshot
  directory, which rotation will eventually clean up.

### 12.6 Language toggle — security considerations (v1.2.0)

The WebUI's bilingual feature (English default + Arabic toggle)
is a **client-side only** concern. From a security standpoint:

- **No server state**: The language preference is stored in
  `localStorage['dnscrypt-lang']` and never transmitted to the
  API. There is no session-side, no user-side, and no
  server-side state tied to the language.
- **No new network requests**: The toggle does not trigger any
  fetch/XHR/SSE activity. It only manipulates the DOM.
- **No SW cache pollution**: The Service Worker caches the HTML
  **once**. Both `translations.en` and `translations.ar` objects
  are inline in the same file.
- **No XSS regression**: All translated strings pass through
  `textContent` / `escapeHtml()` exactly like their English
  counterparts. The Arabic strings are static constants in the
  HTML source — they are not user-controlled.
- **No CSP change**: The in-page toggle does not require
  `'unsafe-inline'` for anything beyond what already existed.
- **No information disclosure**: The language preference reveals
  nothing about the user (English and Arabic are both widely
  spoken). It is not logged, not counted, and not reported.

For users who require stronger guarantees, they can:

- Encrypt the device (Android FBE).
- Copy the backup off-device regularly (§7.8).
- Use a separate encrypted container for long-term storage.
- Clear `localStorage` manually if they want the WebUI to
  forget the language choice.

---

## 13. References

### 13.1 Project files

| File | Role |
|------|------|
| `proxy/customize.sh` | Creates install/upgrade snapshots (Layers 1–8) |
| `proxy/functions.sh` | Backup helpers + rotation (Layers 2, 3, 9) |
| `proxy/service.sh` | Triggers periodic auto-backup (Layer 9) |
| `proxy/main.go` | Triggers pre-critical backup + reads pending notification (Layer 9 + Layer 10) |
| `proxy/status.sh` | Provides `--diagnose` and `--json` (Layer 10) |
| `proxy/action.sh` | Provides `--backup` (manual trigger) |
| `proxy/uninstall.sh` | Preserves backup + cleans orphan transactions |
| `proxy/post-fs-data.sh` | Does NOT touch backups (runs too early) |
| `proxy/watchdog.sh` | Does NOT touch backups (read-only diagnostics) |
| `META-INF/com/google/android/update-binary` | Root manager entry point (does not touch backups) |

### 13.2 Related documentation

| Document | Purpose |
|----------|---------|
| [`EMERGENCY.md`](EMERGENCY.md) | Emergency recovery procedures |
| [`UPGRADE.md`](UPGRADE.md) §3.1 | v1.1.0 → v1.2.0 upgrade guide |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) §3.10 | Backup & Restore flow diagram |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) §4.10 | v1.2.0 Backend additions (BAK-1..BAK-4) |
| [`SECURITY.md`](SECURITY.md) §5.31 | Data preservation security model |
| [`SECURITY.md`](SECURITY.md) §5.32.1 | FIX-1 recovery-mode correctness (snapshot-and-reapply) |
| [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §7.8–§7.10 | Backup-related issues |
| [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §12.9 | Recovery-mode correctness (FIX-1) |
| [`API.md`](API.md) §6.1.7 | `runtime_info` schema (7-field `backups`) |
| [`API.md`](API.md) §10.6 | Backup diagnostics examples |
| [`API.md`](API.md) §10.7 | Recovery mode examples |
| [`FAQ.md`](FAQ.md) Q121–Q130 | Backup questions |
| [`CHANGELOG.md`](../CHANGELOG.md) §[v1.2.0] | Release notes |
| [`INSTALL.md`](INSTALL.md) §10.5 | Manual backup before uninstall |

### 13.3 External references

- [Magisk — Module Structure](https://topjohnwu.github.io/Magisk/guides.html)
- [KernelSU — Module Docs](https://kernelsu.org/guide/module.html)
- [APatch — Documentation](https://github.com/bmax121/APatch)
- [Android SELinux — `restorecon`](https://source.android.com/docs/security/features/selinux)
- [SHA-256 — NIST FIPS 180-4](https://csrc.nist.gov/publications/detail/fips/180/4/final)

---

*Last updated: 2026-09-29*
*Version: v1.2.0*
*Author: gasciljh*