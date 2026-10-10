# Upgrade Guide — DNSCrypt Smart Filter

> Comprehensive guide for upgrading between DNSCrypt Smart Filter versions.

**Current version**: v1.4.0
**Last updated**: 2026-10-08
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **Identifier inventory in this file (7 total)**:
>   • HARD-UPG-01 (v1.3.0 block extended with server-side
>     rotation refinements — v1.4.0)
>   • HARD-UPG-02 (§1.1 v1.3.0 description extended with
>     SNAP-*/ROT-* — v1.4.0)
>   • HARD-UPG-03 (§1.3 v1.3.0 row extended with SNAP-*/ROT-* —
>     v1.4.0)
>   • HARD-UPG-04 (§3.3 extended with full SNAP-*/ROT-* details —
>     v1.4.0)
>   • HARD-UPG-05 (§4.8 extended with SNAP-*/ROT-* verification —
>     v1.4.0)
>   • HARD-UPG-06 (§5.9 extended with SNAP-*/ROT-* identifiers —
>     v1.4.0)
>   • HARD-UPG-07 (Header + footer `Last updated` sync + §7.1
>     references extended — v1.4.0)
>
> **Cross-references**:
>   • [docs/ARCHITECTURE.md §4.13](ARCHITECTURE.md) — v1.3.0
>     server-side refinements (authoritative)
>   • [docs/COMPATIBILITY.md §10.3.5](COMPATIBILITY.md) — on-device
>     SNAP-*/ROT-* verification procedure
>   • [docs/GLOSSARY.md](GLOSSARY.md) — SNAP-*/ROT-* terms,
>     Rotation Guardian badge
>   • [docs/BACKUP.md](BACKUP.md) — backup system reference
>   • [docs/EMERGENCY.md](EMERGENCY.md) — emergency recovery
>   • [docs/HALL_OF_FAME.md](HALL_OF_FAME.md) — Rotation Guardian
>     + Companion App Champion badges
>   • [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) §4.16 — rotation
>     semantics issues
>   • [CHANGELOG.md](../CHANGELOG.md) — version history

> **📖 Related documents**:
> - Git workflow → [`docs/BRANCHING.md`](BRANCHING.md)
> - Release process → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decisions → [`docs/adr/README.md`](adr/README.md)
> - Installation guide → [`docs/INSTALL.md`](INSTALL.md)
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)
> - Troubleshooting guide → [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md)

> **v1.4.0 changes**:
>   • Current version bumped from v1.3.0 to v1.4.0.
>   • `Last updated` reflects the v1.4.0 file-editing date
>     (2026-10-08).
>   • **New section**: §3.4 — v1.3.0 → v1.4.0 upgrade guide
>     (the current release, companion app integration).
>   • **New section**: §3.3 — v1.2.0 → v1.3.0 upgrade guide
>     (Historical: PWA install button + live status LED +
>     DNS auto-start fix + **server-side rotation refinements
>     SNAP-*/ROT-***).
>   • **§3 renumbered**: the v1.1.0 → v1.2.0 guide is now
>     **§3.2 (Historical)**; the "General Procedure",
>     "What Happens Behind the Scenes", "Installation Methods",
>     and "Common Messages" subsections shifted to
>     **§3.5, §3.6, §3.7, §3.8** respectively.
>   • **§1.1** rewritten: v1.4.0 is now the current release;
>     v1.3.0, v1.2.0, v1.1.0, and v1.0.0 are described as
>     history. The v1.3.0 paragraph now names the five server-side
>     rotation refinements.
>   • **§1.3** Version History table extended with v1.3.0 and
>     v1.4.0 rows; the v1.3.0 row now lists SNAP-MANIFEST,
>     SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, and ROT-PROTECT;
>     "Next planned" corrected to v1.5.0.
>   • **§3.3** extended with three new subsections:
>       - §3.3.1 — extended "What Changes" table (rotation
>         refinements row added).
>       - §3.3.5 (new) — "Server-Side Rotation Refinements
>         (SNAP-*/ROT-*)".
>       - §3.3.6 (new) — "Post-Upgrade Rotation Verification".
>   • **§4.1, §4.6, §4.11** — examples updated from `v1.2.0` /
>     `1020000` to `v1.4.0` / `1040000`.
>   • **§4.8** — added SNAP-*/ROT-* specific verification
>     commands.
>   • **§5.9** — extended the "Sort order note" with the
>     SNAP-*/ROT-* identifier names (SNAP-MANIFEST, SNAP-MTIME,
>     ROT-MANIFEST, ROT-MTIME, ROT-PROTECT) and the v1.3.0
>     cross-reference.
>   • **§6.7** — added a rotation-state reference row.
>   • **§6.9** — version check updated to `v1.4.0`.
>   • **§7.1** — added the rotation-related cross-references.
>   • **§7.3** — added a note that Cosign / SBOM are **not**
>     currently used (matches `docs/RELEASE_PROCESS.md` §8.4 and
>     §8.5).
>   • Footer — `Last updated` bumped to `2026-10-08`.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention. **No API impact.**
>   • **Encoding**: verified that all section markers, arrows,
>     checkmarks, warnings, and box-drawing characters render
>     as proper UTF-8.

> **v1.3.0 changes** (historical):
>   • Version bumped from v1.2.0 to v1.3.0.
>   • **New section**: §3.3 — v1.2.0 → v1.3.0 upgrade guide
>     (feature release: PWA install button + live status LED +
>     DNS auto-start fix + **server-side rotation refinements
>     SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME +
>     ROT-PROTECT**).
>   • **§3 renumbered**: the v1.1.0 → v1.2.0 guide is now
>     **§3.2**; the "General Procedure", "What Happens Behind
>     the Scenes", "Installation Methods", and "Common Messages"
>     subsections shifted accordingly.
>   • **§1.1** rewritten: v1.3.0 is the current release; the
>     v1.2.0, v1.1.0, and v1.0.0 releases are history.
>   • **§1.3** Version History table extended with the v1.3.0
>     row.
>   • **§6.3** added a note about `service.sh` calling
>     `ensure_running_service` at boot.
>   • No `v1.2.0` examples were modified in this revision (they
>     are used as historical snapshots, not as "current").
>   • **Server-side rotation refinements** — the v1.3.0 release
>     ALSO refined the snapshot-detection and rotation semantics
>     that underpin the persistent backup directory. Five
>     identifiers document the change (also used in
>     `CHANGELOG.md` [v1.3.0] and `docs/ARCHITECTURE.md` §4.13):
>
>       🔧 **SNAP-MANIFEST** — `main.go:buildBackupInfo()` now
>         detects a snapshot by the presence of a
>         `.manifest.json` file, not by the v1.2.0 name pattern
>         (`^[0-9]{8}-[0-9]{6}-`). Custom-named snapshots are
>         now visible to the API and to rotation.
>
>       🔧 **SNAP-MTIME** — `last_backup_name` is now selected
>         by **mtime** (descending). This supersedes the v1.2.0
>         BUG-3 lexicographic-name rule.
>
>       🔧 **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** —
>         `functions.sh:rotate_backups()` was rewritten with
>         the same manifest-based detection, the same mtime
>         sort, and **two additional protected targets** on top
>         of the 21-newest window: the `.last_stable` recovery
>         pointer and the newest install snapshot (name
>         matching `-v<digit>`).
>
>     The same SNAP-*/ROT-* semantics were mirrored in 5 shell
>     scripts (`service.sh`, `watchdog.sh`, `status.sh`,
>     `customize.sh`, `action.sh`) and in `uninstall.sh`.
>   • **Global edition** note (unchanged).

> **v1.2.0 changes** (historical):
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
>   • **Encoding correction (v1.2.0)**: verified that all
>     section markers, arrows, checkmarks, warnings, and box
>     drawing characters render as proper UTF-8.
>   • **Numbering correction (v1.2.0)**: §3 was
>     restructured for a consistent hierarchy. The v1.0.0 → v1.1.0
>     upgrade guide is now **§3.1** (was `§3.0.1`, nested under a
>     `§3.0 Historical Upgrades` wrapper). The v1.1.0 → v1.2.0
>     upgrade guide is now **§3.2** (was `§3.1`). The following
>     subsections shifted by one accordingly: **§3.3** General
>     Procedure, **§3.4** What Happens Behind the Scenes,
>     **§3.5** Installation Methods, **§3.6** Common Messages.
>     This fixed the H3/H4 mixing that made `§3.0.1` a
>     sub-subsection while `§3.1` returned to the H3 level.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Settings Preservation](#2-settings-preservation)
3. [Upgrade Procedure](#3-upgrade-procedure)
4. [Verification After Upgrade](#4-verification-after-upgrade)
5. [API Behavior Notes (v1.2.0+)](#5-api-behavior-notes-v120)
6. [Emergency Recovery](#6-emergency-recovery)
7. [References](#7-references)

---

## 1. Overview

### 1.1 Current Release

**v1.4.0 is the current stable release** of DNSCrypt Smart Filter.

**v1.0.0** (2026-09-24) was the first stable release — it
consolidated the entire development effort into a single
production-ready version with 33 audit corrections.

**v1.1.0** (2026-09-26) was a **polish release**:

- No breaking changes.
- Three runtime improvements (MEM-1, MEM-2, MEM-3).
- Two new `runtime_info` fields (`profile_key`, `memory_limit_mb`).

**v1.2.0** (2026-09-29) was the **Data-Preservation Release**:

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

**v1.3.0** (2026-10-02) was a **feature release**:

- **Smart dynamic PWA install button** (client-side only).
- **Live status LED** on the Today counter (client-side only).
- **DNS auto-start fix** (`service.sh` calls
  `ensure_running_service` at boot).
- **Server-side rotation refinements** — five new semantics
  underpin the persistent backup directory:
  - **SNAP-MANIFEST** — `main.go:buildBackupInfo()` detects a
    snapshot by the presence of a `.manifest.json` file (not by
    a name pattern).
  - **SNAP-MTIME** — `last_backup_name` is selected by **mtime**
    (descending), not by lexicographic directory name. Supersedes
    the v1.2.0 BUG-3 rule.
  - **ROT-MANIFEST** — `functions.sh:rotate_backups()` uses the
    same manifest-based detection.
  - **ROT-MTIME** — `rotate_backups()` uses the same mtime sort.
  - **ROT-PROTECT** — `rotate_backups()` preserves the
    `.last_stable` target and the newest install snapshot on top
    of the 21-newest window.
- No breaking changes.

**v1.4.0** (2026-10-06) is the **current Integration Release**:

- **Companion Android app** (~3 MB WebView wrapper) bundled as an
  OPTIONAL asset (`web/app-debug.apk`), served at
  `GET /app-debug.apk`.
- **CodeQL `go/path-injection` fix** in `removeModule` — hardened
  via `filepath.Base()` + trusted base dir. No API contract
  change for valid inputs.
- **iOS PWA logic removed** — Android-only project.
- **MAIN-01** — `LOG_LEVEL` loaded immediately after
  `initPaths()` in `main.go` (startup-order fix).
- **Release assets**: 8 files (was 6) — the two companion APK
  entries are optional.
- No breaking changes.

See [CHANGELOG.md](../CHANGELOG.md) for the full history.

This guide covers:

- The **settings preservation mechanism** that applies to all
  in-place upgrades.
- The **general upgrade procedure** for future versions.
- The **specific upgrade from v1.3.0 to v1.4.0** (§3.4).
- The **specific upgrade from v1.2.0 to v1.3.0** (§3.3).
- The **specific upgrade from v1.1.0 to v1.2.0** (§3.2,
  Historical).
- The **historical upgrade from v1.0.0 to v1.1.0** (§3.1).
- **Emergency recovery** procedures.
- **v1.2.0+ API behavior notes** (important for scripts and
  integrations).

### 1.2 Design Principles

The upgrade system is built on:

| Principle | Implementation |
|---|---|
| **Zero data loss** | 5 user config files are automatically backed up and restored |
| **Idempotent** | Reinstalling the same version is safe |
| **Automatic** | No manual configuration after upgrade |
| **Reversible** | Emergency recovery + recovery mode supported |
| **No silent breaking changes** | v1.1.0, v1.2.0, v1.3.0, and v1.4.0 API additions are strictly additive |
| **Persistent** | (v1.2.0+) The backup directory survives reboot, uninstall, and `/data` reset |
| **Protected recovery** | (v1.3.0+) `.last_stable` and the newest install snapshot are protected from rotation |
| **Optional companion** | (v1.4.0) The companion Android app is bundled as an OPTIONAL asset — a dev build without it still works |

### 1.3 Project Version History

| Version | Date | Type | Notes |
|---|---|:---:|---|
| v1.0.0 | 2026-09-24 | First stable | 33 audit corrections, 20 fixes, Level 4 infrastructure |
| v1.1.0 | 2026-09-26 | Polish | MEM-1/2/3, dynamic memory limit, `profile_key` + `memory_limit_mb` |
| v1.2.0 | 2026-09-29 | Data preservation | 10 defensive layers, BAK-1..BAK-4, FIX-1/2, bilingual WebUI, `backups` object, recovery mode |
| v1.3.0 | 2026-10-02 | Feature | PWA install button, live status LED, DNS auto-start fix, **SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** |
| **v1.4.0** | **2026-10-06** | **Integration** | **Companion Android app (optional), CodeQL `go/path-injection` fix, iOS PWA removal, MAIN-01, 8 release artifacts** |

**Next planned**:

- **v1.5.0** — CSP hardening (remove `'unsafe-inline'`), PWA port
  unification, backup integrity hardening, companion app
  deep-links. See [`ROADMAP.md`](ROADMAP.md) §5.
- **v1.6.0** — Multi-language (FR/DE/ES/RU/ZH), 2FA, audit
  logging, JWT. See [`ROADMAP.md`](ROADMAP.md) §6.
- **v2.0.0** — Major rewrite. See [`ROADMAP.md`](ROADMAP.md) §7.

### 1.4 Data-Preservation Upgrade Model (v1.2.0+)

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

**v1.3.0 refinement**: Layer 9 (rotation) was refined with
**manifest-based detection** (ROT-MANIFEST) and **mtime sorting**
(ROT-MTIME), plus **two additional protected targets**
(ROT-PROTECT: `.last_stable` and the newest install snapshot).
This makes recovery mode and rollback significantly more
reliable.

**What this changes for users**:

- ✅ The 5 config files are now preserved **and** snapshotted for
  future recovery.
- ✅ The snapshot location survives reboot, uninstall, and
  factory reset of `/data`.
- ✅ A failed upgrade automatically rolls back.
- ✅ New CLI tools let you create manual backups
  (`action.sh --backup`) and inspect the state
  (`status.sh --diagnose`).
- ✅ (v1.3.0+) The `.last_stable` recovery pointer is protected
  from rotation — recovery mode can no longer be silently broken.
- ✅ No user action is required — everything is automatic.

**What this changes for the upgrade mechanism**:

- ❌ The legacy `BACKUP_TMP` mechanism (v1.0.0) is **superseded**.
  See §2.3 for the comparison.

**v1.4.0 addition**: The v1.4.0 integration of the companion
Android app does **not** change the upgrade mechanism. The APK is
an optional asset; the module continues to work without it, and a
failed APK fetch during the release pipeline does **not** fail the
release.

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

**This behavior is identical in v1.0.0, v1.1.0, v1.2.0, v1.3.0,
and v1.4.0** — the underlying mechanism improved, but the
user-facing guarantee is the same.

### 2.2 Additional Files

| File | Action | Note |
|---|---|---|
| `blocklist.raw` | 🔄 Downloaded | Re-fetched on profile update |
| `blocklist.txt` | 🔄 Rebuilt | Derived from `blocklist.raw` + rules |
| `blocked-ips.txt` | 🔄 Recreated | From defaults |
| `run/` directory | 🔄 Recreated | Runtime state only |
| Logs | 🔄 Rotated | Fresh log files |
| `web/app-debug.apk` | 🔄 Replaced | **v1.4.0** — optional asset; absent in dev builds |

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

**v1.2.0+** (current mechanism):

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

**v1.3.0 addition**: The rotation logic (Layer 9) now detects
snapshots by the presence of `.manifest.json` (ROT-MANIFEST),
sorts by mtime (ROT-MTIME), and preserves two additional
targets (ROT-PROTECT): the `.last_stable` pointer and the newest
install snapshot.

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

**Or**, use the module's own CLI tool (v1.2.0+):

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
- [ ] Available storage: `df -h /sdcard` → > 10 MB free (v1.2.0+)
- [ ] Battery: > 30%
- [ ] Internet: Working (for blocklist re-download)
- [ ] Manual backup (recommended, especially before v1.2.0)
- [ ] **v1.3.0 → v1.4.0**: confirm `proxy/app-apk.version` is
      up to date (informational; the release pipeline fetches the
      APK).

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

**If you are still on v1.0.0**: upgrade directly to v1.4.0. The
v1.1.0 → v1.2.0 upgrade (§3.2) and the subsequent steps supersede
this and preserve everything.

### 3.2 Upgrading from v1.1.0 to v1.2.0 (Historical)

This was the **Data-Preservation Release**. It fixed a silent
data-loss bug in v1.1.0 and hardened the write path with the 10
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

### 3.3 Upgrading from v1.2.0 to v1.3.0 (Historical)

This was a **feature release**, focused on the WebUI install
experience, DNS reliability at boot, **and server-side rotation
refinements**.

#### 3.3.1 What Changes

| Category | Change | Impact |
|---|---|---|
| **WebUI** | Smart dynamic PWA install button | Client-side only |
| **WebUI** | Live status LED on the Today counter | Client-side only |
| **`service.sh`** | DNS auto-start after boot (calls `ensure_running_service` directly) | Faster DNS after reboot |
| **`main.go:buildBackupInfo`** | **SNAP-MANIFEST** — snapshot detection by `.manifest.json` presence (not name pattern) | Custom-named snapshots now visible |
| **`main.go:buildBackupInfo`** | **SNAP-MTIME** — `last_backup_name` selected by mtime (not name) | Robust against clock drift + manual renames |
| **`functions.sh:rotate_backups`** | **ROT-MANIFEST** — same manifest-based detection | Rotation no longer misses custom-named snapshots |
| **`functions.sh:rotate_backups`** | **ROT-MTIME** — same mtime sort | Deterministic rotation order |
| **`functions.sh:rotate_backups`** | **ROT-PROTECT** — preserves `.last_stable` + newest install snapshot | Recovery mode can no longer be silently broken |
| **Documentation** | Minor updates across `docs/` | Read-only |

#### 3.3.2 What Does NOT Change

- ✅ **All API endpoints** — same paths, same methods, same auth.
- ✅ **`runtime_info.backups`** schema — same 7 fields.
- ✅ **`X-Watchdog-Token`** on `ensure_running_service` — unchanged.
- ✅ **10 defensive layers** — unchanged.
- ✅ **Bilingual WebUI** — unchanged.
- ✅ **Memory limit per profile** (MEM-1) — unchanged.
- ✅ **`append_denylist`** requires `content` — unchanged.
- ✅ **Settings preservation** — 5 files preserved.
- ✅ **Firewall layout** — `DNSCRYPT_OUT` / `DNSCRYPT_OUT6`.
- ✅ **DNS version** — still `2.1.18`.

#### 3.3.3 Step-by-Step

```bash
# 1. Note the current state
ORIG_PROFILE=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
echo "Before: profile=$ORIG_PROFILE"

# 2. Optional: take a manual snapshot
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"

# 3. Download the v1.3.0 ZIP
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.3.0/dnscrypt-webui-1.3.0-module.zip

# 4. Verify SHA-256
sha256sum -c dnscrypt-webui-1.3.0-module.zip.sha256

# 5. Install via Magisk Manager → Reboot
su -c "reboot"

# 6. After boot (~60s), verify
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
```

#### 3.3.4 Rolling Back to v1.2.0

```bash
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.2.0/dnscrypt-webui-1.2.0-module.zip
# Install via Magisk Manager → Reboot
su -c "reboot"
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.2.0
```

**Rollback caveats**:

- ⚠️ The WebUI loses the dynamic PWA install button and the live
  status LED.
- ⚠️ `buildBackupInfo` reverts to name-based sorting
  (SNAP-MANIFEST + SNAP-MTIME are lost).
- ⚠️ `rotate_backups` reverts to name-based detection and
  sorting; the `.last_stable` and newest install snapshot are
  **no longer protected** (ROT-PROTECT is lost). This makes
  recovery mode fragile again on v1.2.0.
- ⚠️ All other v1.2.0 features (10 defensive layers, backups object,
  watchdog token) remain.

#### 3.3.5 Server-Side Rotation Refinements (SNAP-*/ROT-*)

> **This subsection is new in v1.4.0.** It was missing from the
> previous revision of this upgrade guide. The v1.3.0 release
> introduced five new semantics that affect how the persistent
> backup directory is enumerated, sorted, and pruned.

**The five refinements**:

| ID | File | Change |
|:-:|---|---|
| **SNAP-MANIFEST** | `proxy/main.go` | `buildBackupInfo()` now detects a snapshot by the presence of a `.manifest.json` file, **not** by the v1.2.0 name-pattern matching (`^[0-9]{8}-[0-9]{6}-`). |
| **SNAP-MTIME** | `proxy/main.go` | `last_backup_name` is now selected by **mtime** (descending). This **supersedes** the v1.2.0 BUG-3 lexicographic-name rule. |
| **ROT-MANIFEST** | `proxy/functions.sh` | `rotate_backups()` uses the same manifest-based detection. Excludes `current/`, `txn-*`, and `orphan-txn-*` by name. |
| **ROT-MTIME** | `proxy/functions.sh` | `rotate_backups()` uses the same mtime-descending sort. |
| **ROT-PROTECT** | `proxy/functions.sh` | `rotate_backups()` preserves **two additional protected targets** on top of the 21-newest window: the `.last_stable` recovery pointer and the newest install snapshot (name matching `-v<digit>`). |

**Mirrored semantics**: The same SNAP-*/ROT-* behavior was
applied to 5 shell scripts (`service.sh`, `watchdog.sh`,
`status.sh`, `customize.sh`, `action.sh`) and to `uninstall.sh`.

**Why this matters**:

- **SNAP-MANIFEST** — Custom-named snapshots (e.g.
  `pre-v130-manual-20261008/`) were **silently skipped** by the
  v1.2.0 name-pattern detection. They are now counted.
- **SNAP-MTIME** — The v1.2.0 lexicographic-name sort could
  select a "stale" name if the snapshot names diverged from
  their mtimes. mtime is robust.
- **ROT-PROTECT** — The v1.2.0 rotation had **no explicit
  protection** for the `.last_stable` pointer or the newest
  install snapshot. A pathological distribution of snapshots
  could cause the 21-newest window to evict exactly the
  snapshots that the recovery path depended on.

**Impact on your device**:

- ✅ **`runtime_info.backups.available`** may now count
  directories that were previously invisible (custom-named
  snapshots with a `.manifest.json`).
- ✅ **`runtime_info.backups.last_backup_name`** may now show a
  different snapshot (the one with the newest mtime, not the
  lexicographically-last name).
- ✅ **Rotation** now preserves the `.last_stable` target and the
  newest install snapshot — even if they fall outside the
  21-newest window.
- ⚠️ **Stale pointers**: If your v1.2.0 install had a
  `.last_stable` pointing at a snapshot that had already been
  pruned, that pointer is **not repaired** by the upgrade. See
  [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §4.16.3.

**Reference**: [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.13;
§11.31–§11.33.

#### 3.3.6 Post-Upgrade Rotation Verification

After upgrading to v1.3.0 (or later), verify the new rotation
semantics:

```bash
# 1. Confirm the module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# → v1.3.0 or newer

# 2. Check the 7-field backups object
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"

# 3. Verify snapshot enumeration (SNAP-MANIFEST)
for d in /sdcard/dnscrypt-webui-backup/*/; do
    name=$(basename "$d")
    case "$name" in
        current|txn-*|orphan-txn-*) continue ;;
    esac
    if [ -f "$d/.manifest.json" ]; then
        echo "  ✅ $name (counted)"
    else
        echo "  ⚠️  $name (NO manifest — not counted)"
    fi
done

# 4. Verify ROT-* markers in functions.sh
su -c "grep -q 'ROT-MANIFEST' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && \
       echo '✅ ROT-MANIFEST present'"
su -c "grep -q 'ROT-MTIME' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && \
       echo '✅ ROT-MTIME present'"
su -c "grep -q 'ROT-PROTECT' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && \
       echo '✅ ROT-PROTECT present'"

# 5. Verify .last_stable target exists
LAST_STABLE=$(cat /sdcard/dnscrypt-webui-backup/.last_stable 2>/dev/null)
if [ -n "$LAST_STABLE" ] && [ -d "/sdcard/dnscrypt-webui-backup/$LAST_STABLE" ]; then
    echo "✅ .last_stable target exists"
else
    echo "⚠️  .last_stable target missing — see TROUBLESHOOTING §4.16.3"
fi
```

**Full verification procedure**:
[`docs/COMPATIBILITY.md`](COMPATIBILITY.md) §10.3.5.

**Rotation Guardian badge**: If you verified these semantics on
**3+ devices** or **3+ root solutions**, you qualify for the
🎯 **Rotation Guardian** badge — see
[`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md).

### 3.4 Upgrading from v1.3.0 to v1.4.0 (Current)

This is the **Integration Release**, focused on the optional
companion Android app and a CodeQL hardening.

#### 3.4.1 What Changes

| Category | Change | Impact |
|---|---|---|
| **Companion app** | `web/app-debug.apk` bundled as an OPTIONAL asset | New install option |
| **`GET /app-debug.apk`** | New public static route (mime `application/vnd.android.package-archive`) | Additive |
| **WebUI install button** | Now a direct `<a download href="/app-debug.apk">` link | Client-side only |
| **iOS PWA logic** | Removed (~35 lines) | Android-only project |
| **`removeModule`** | CodeQL `go/path-injection` hardened via `filepath.Base()` + trusted base dir | No API contract change for valid inputs |
| **`main.go` startup order** | **MAIN-01** — `LOG_LEVEL` loaded immediately after `initPaths()` | Early startup log lines now respect the configured level |
| **Release assets** | 8 files (was 6) — the two APK entries are optional | Release pipeline only |
| **New files** | `proxy/app-apk.version`, `scripts/fetch_app_apk.sh` | Build/dev only |
| **Documentation** | New §8.6 in INSTALL, new §6.1.15 in API, new §5.34/§5.35 in SECURITY, etc. | Read-only |

#### 3.4.2 What Does NOT Change

- ✅ **All API endpoints** — same paths, same methods, same auth.
- ✅ **`runtime_info.backups`** schema — same 7 fields.
- ✅ **`X-Watchdog-Token`** on `ensure_running_service` — unchanged.
- ✅ **10 defensive layers** — unchanged.
- ✅ **Bilingual WebUI** — unchanged.
- ✅ **Memory limit per profile** (MEM-1) — unchanged.
- ✅ **`append_denylist`** requires `content` — unchanged.
- ✅ **Settings preservation** — 5 files preserved.
- ✅ **Firewall layout** — `DNSCRYPT_OUT` / `DNSCRYPT_OUT6`.
- ✅ **DNS version** — still `2.1.18`.
- ✅ **SNAP-*/ROT-* semantics** — unchanged.

#### 3.4.3 Step-by-Step

```bash
# 1. Note the current state
ORIG_PROFILE=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
echo "Before: profile=$ORIG_PROFILE"

ORIG_PORTS=$(su -c "grep -E '^(PORT|DASHBOARD_PORT)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf")
echo "Before: $ORIG_PORTS"

# 2. Optional: take a manual snapshot
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"

# 3. Download the v1.4.0 ZIP (release assets: 8 files)
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.4.0/dnscrypt-webui-1.4.0-module.zip

# 4. Verify SHA-256
sha256sum -c dnscrypt-webui-1.4.0-module.zip.sha256
# Expected: OK

# 5. Install via Magisk Manager → Reboot
su -c "reboot"

# 6. After boot (~60s), verify (see §4)
```

#### 3.4.4 What to Expect in the Install Log

The `customize.sh` output is unchanged from v1.2.0/v1.3.0 except
for one optional line about the companion APK:

```text
- Architecture: arm64-v8a
- Upgrade detected, cleaning old instances...
  → Killed 3 old process(es)
  → Firewall rules cleaned (Custom Chain + Legacy)
  ✅ Old instances cleaned
  → Multi-source detection (Layer 1): 5 file(s) found
  → Transaction begun (Layer 4): txn-20261008-150000-12345
  → Persistent backup created (Layer 2): 20261008-150000-v1.4.0-12345
    → SHA256 manifest written (Layer 3)
- Extracting module files...
  ✅ Files extracted
  ✅ Companion APK extracted (optional)     ← v1.4.0 (release build only)
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
  📱 Companion APK: bundled (optional, v1.4.0)   ← v1.4.0
```

#### 3.4.5 The Companion App

The v1.4.0 release ships an **optional** companion Android app —
a ~3 MB WebView wrapper that opens the WebUI at
`127.0.0.1:9090` directly.

**Where to find it**:

- **In the WebUI header**: tap **📲 Install App** (a direct
  `<a download>` link).
- **Direct URL**: `http://127.0.0.1:9090/app-debug.apk`.
- **Companion repository**:
  [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app).

**If the button leads to "file not found"**:

Your module ZIP is a **developer build** that does not bundle
the APK. This is expected for local builds. Use the browser-based
WebUI, or download the APK directly from the companion repository.

**Details**:

| Attribute | Value |
|---|---|
| Size | ~3 MB |
| Stack | Kotlin + WebView |
| Min Android | 5.0 (API 21) |
| Telemetry | None |
| Version pin | `proxy/app-apk.version` (`1.0.0`) |

**Uninstall**: The companion app is **not** uninstalled by
`uninstall.sh`. Remove it separately via the Android app manager
if desired.

#### 3.4.6 The `remove_module` Behavior Change

The v1.4.0 `remove_module` endpoint now sanitizes the
caller-provided path via `filepath.Base()` and rebuilds the final
path from the trusted `MODULES_DIR` constant.

**Impact on existing clients**:

- ✅ **Valid inputs** (any directory directly under
  `/data/adb/modules/`): unchanged behavior.
- ⚠️ **Malformed inputs** (empty basename, `.`, `..`, `/`-only):
  now short-circuit with an error **before** any file operation.

**Correct usage**:

```bash
curl -X POST -b /tmp/cookies.txt \
    -d "path=/data/adb/modules/dnscrypt-old" \
    http://127.0.0.1:9090/api/remove_module
```

**See**: [`docs/API.md`](API.md) §6.2.10,
[`docs/SECURITY.md`](SECURITY.md) §5.34,
[`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §12.10.

#### 3.4.7 Rolling Back to v1.3.0

```bash
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.3.0/dnscrypt-webui-1.3.0-module.zip
# Install via Magisk Manager → Reboot
su -c "reboot"
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.3.0
```

**Rollback caveats**:

- ⚠️ The `/app-debug.apk` route stops responding with 200.
- ⚠️ The install button reverts to the `beforeinstallprompt`
  chain (smart dynamic behavior).
- ⚠️ The iOS branches return to `index.html`.
- ⚠️ The `removeModule` hardening reverts to the old behavior
  (CodeQL alerts return).
- ⚠️ MAIN-01 is lost — early startup log lines may ignore
  `LOG_LEVEL`.
- ⚠️ All other v1.2.0/v1.3.0 features remain.

### 3.5 General Procedure (Future Versions)

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
#    📱 Companion APK: bundled (optional, v1.4.0)           ← v1.4.0+

# 5. Reboot the device
su -c "reboot"

# 6. After boot (wait 60 seconds)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"  # v1.2.0+
```

### 3.6 What Happens Behind the Scenes

`proxy/customize.sh` performs these steps (v1.2.0+):

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
9. Extracts the new ZIP (including `web/app-debug.apk` when
   present, v1.4.0).
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
24. (v1.4.0) Prints the companion APK status (informational).

**v1.3.0 note**: Step 21 (`.last_stable` update) is now protected
by ROT-PROTECT — the pointer target will not be pruned by
rotation even if it falls outside the 21-newest window.

**On failure**: any error before step 22 triggers an automatic
rollback. The `txn-*` directory is preserved as `orphan-txn-*` for
manual inspection.

### 3.7 Installation Methods

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

**v1.2.0+**: APatch installs use the `modules_update/` fallback
source (Layer 5).

### 3.8 Common Messages

| Message | Meaning |
|---|---|
| `Upgrade detected: YES (5 files restored)` | Settings preserved ✅ |
| `Upgrade detected: NO` | Fresh installation |
| `PORT=8080 conflicts with [monitoring_ui], resetting to 9090` | Port Guard auto-fixed the port |
| `⚠️ Default admin/admin detected — generating secure credentials` | Credentials regenerated |
| `🛑 You MUST REBOOT NOW to restore DNS` | Old processes were killed |
| `🧠 Memory limit: ~XXX MB (profile: <key>)` | **v1.1.0+** — computed soft limit |
| `→ Multi-source detection (Layer 1): 5 file(s) found` | **v1.2.0+** — source located |
| `→ Persistent backup created (Layer 2): ...` | **v1.2.0+** — snapshot created |
| `→ Transaction begun (Layer 4): txn-...` | **v1.2.0+** — transaction started |
| `📊 Upgrade detected: YES (5 files restored)` | **v1.2.0+** — summary |
| `⚠️ auto-backup failed (continuing)` | **v1.2.0+** — best-effort; write still proceeds |
| `🛡️ Preserved (last_stable): <name>` | **v1.3.0+** — ROT-PROTECT active |
| `🛡️ Preserved (newest install): <name>` | **v1.3.0+** — ROT-PROTECT active |
| `📱 Companion APK: bundled (optional, v1.4.0)` | **v1.4.0** — APK present |
| `📱 Companion APK: not bundled (dev build)` | **v1.4.0** — APK absent (expected for dev builds) |

---

## 4. Verification After Upgrade

### 4.1 Version Check

```bash
# Module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.4.0

# versionCode
su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: versionCode=1040000
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
**v1.2.0+ addition**: "Backup & Recovery" section in the default
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

### 4.7 Memory Limit Verification (v1.1.0+)

```bash
# 1. Check the startup log line
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
# Expected: 🧠 v1.1.0: dynamic memory limit — profile=pro, limit=120 MB

# 2. Confirm the profile file matches
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Expected: pro (must match profile_key from §4.6)
```

### 4.8 Backup Layer Verification (v1.2.0+; refined v1.3.0)

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

**v1.3.0 additions** — verify the rotation refinements:

```bash
# 8. SNAP-MANIFEST — every counted snapshot has a .manifest.json
for d in /sdcard/dnscrypt-webui-backup/*/; do
    name=$(basename "$d")
    case "$name" in
        current|txn-*|orphan-txn-*) continue ;;
    esac
    if [ -f "$d/.manifest.json" ]; then
        echo "  ✅ $name (counted by SNAP-MANIFEST)"
    else
        echo "  ⚠️  $name (NO manifest — not counted)"
    fi
done

# 9. SNAP-MTIME — compare runtime last_backup_name with local newest-by-mtime
echo "  Reported last_backup_name:"
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups.last_backup_name'
echo "  Newest by mtime (recomputed locally):"
ls -1dt /sdcard/dnscrypt-webui-backup/*/ 2>/dev/null | \
    grep -vE '/(current|txn-|orphan-txn-)' | \
    while IFS= read -r d; do
        [ -f "$d/.manifest.json" ] && basename "$d"
    done | head -n1
# Expected: the two lines match

# 10. ROT-PROTECT — verify the .last_stable target exists
LAST_STABLE=$(cat /sdcard/dnscrypt-webui-backup/.last_stable 2>/dev/null)
if [ -n "$LAST_STABLE" ] && [ -d "/sdcard/dnscrypt-webui-backup/$LAST_STABLE" ]; then
    echo "✅ ROT-PROTECT works — .last_stable target exists"
else
    echo "⚠️  .last_stable target missing — see TROUBLESHOOTING §4.16.3"
fi

# 11. ROT-* markers in functions.sh
su -c "grep -q 'ROT-MANIFEST' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && \
       echo '✅ ROT-MANIFEST present'"
su -c "grep -q 'ROT-MTIME' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && \
       echo '✅ ROT-MTIME present'"
su -c "grep -q 'ROT-PROTECT' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && \
       echo '✅ ROT-PROTECT present'"
```

### 4.9 Watchdog Token Verification (v1.2.0+)

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

### 4.10 Bilingual WebUI Check (v1.2.0+)

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

### 4.11 Companion APK Verification (v1.4.0+)

```bash
# 1. APK file is bundled (release build)
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk"
# Expected (release build): ~3 MB
# Expected (dev build):     No such file or directory

# 2. HTTP route responds
su -c "curl -sI http://127.0.0.1:9090/app-debug.apk | head -3"
# Expected (release build):
#   HTTP/1.1 200 OK
#   Content-Type: application/vnd.android.package-archive
#   Cache-Control: public, max-age=3600, immutable
# Expected (dev build):
#   HTTP/1.1 404 Not Found

# 3. Install button uses the direct link
su -c "grep -q 'href=\"/app-debug.apk\"' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && \
       echo '✅ direct <a download> link'"

# 4. iOS PWA logic is removed
su -c "grep -q 'isIOSDevice' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && \
       echo '❌ iOS logic still present' || echo '✅ iOS logic removed'"

# 5. Companion app version pin
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/app-apk.version"
# Expected: 1.0.0

# 6. MAIN-01 — LOG_LEVEL loaded early (v1.4.0)
su -c "grep -q 'MAIN-01' /data/adb/modules/dnscrypt-proxy-webui/main.go 2>/dev/null || \
       grep -q 'MAIN-01' /data/local/tmp/dnscrypt_main.log && \
       echo '✅ MAIN-01 documented'"
```

### 4.12 Unified Verification Script

```bash
#!/system/bin/sh
# verify-upgrade.sh — comprehensive post-upgrade check (v1.4.0)

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
echo "=== Backup State (v1.2.0+) ==="
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'

echo ""
echo "=== Backup Directory (v1.2.0+) ==="
ls -la /sdcard/dnscrypt-webui-backup/ 2>&1 | head -10

echo ""
echo "=== Rotation Refinements (v1.3.0+) ==="
for marker in ROT-MANIFEST ROT-MTIME ROT-PROTECT; do
    if grep -q "$marker" /data/adb/modules/dnscrypt-proxy-webui/functions.sh 2>/dev/null; then
        echo "  ✅ $marker present"
    else
        echo "  ⚠️  $marker not found"
    fi
done
LAST_STABLE=$(cat /sdcard/dnscrypt-webui-backup/.last_stable 2>/dev/null)
if [ -n "$LAST_STABLE" ] && [ -d "/sdcard/dnscrypt-webui-backup/$LAST_STABLE" ]; then
    echo "  ✅ .last_stable target exists: $LAST_STABLE"
else
    echo "  ⚠️  .last_stable target missing"
fi

echo ""
echo "=== Watchdog Token (v1.2.0+) ==="
ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token 2>&1
stat -c '%a' /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token 2>&1

echo ""
echo "=== Bilingual WebUI (v1.2.0+) ==="
for f in index.html dashboard.html offline.html; do
    grep -q 'id="langToggle"' /data/adb/modules/dnscrypt-proxy-webui/web/$f && echo "✅ $f toggle"
done

echo ""
echo "=== Companion APK (v1.4.0+) ==="
ls -la /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk 2>&1
curl -sI http://127.0.0.1:9090/app-debug.apk | head -1
grep -q 'href="/app-debug.apk"' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && \
    echo "✅ direct install link"
grep -q 'isIOSDevice' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && \
    echo "❌ iOS logic still present" || echo "✅ iOS logic removed"

echo ""
echo "✅ Verification complete"
```

Save this as `/sdcard/verify-upgrade.sh` and run:

```bash
su -c "sh /sdcard/verify-upgrade.sh"
```

---

## 5. API Behavior Notes (v1.2.0+)

> **ℹ️ Important for scripts and integrations.**
>
> These are the **behaviors of v1.2.0 and later**. They are
> unchanged from v1.0.0 and v1.1.0 except where noted. **No
> breaking changes** (except the `append_denylist` content
> requirement — see §5.10).

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
  "generated_at": "2026-10-08T10:30:00Z",
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

**v1.4.0 response**:

```json
{
  "version": "v1.4.0",
  "bind_addr": "127.0.0.1",
  "webui_port": "9090",
  "dashboard_port": "9091",
  "profile_key": "pro",
  "memory_limit_mb": 120,
  "run_dir": "...",
  "status_file": "..."
}
```

### 5.8 `get_profile` Includes `memory_limit_mb` (v1.1.0+)

**Endpoint**: `GET /api?action=get_profile`

**v1.1.0+ response**:

```json
{
  "key": "pro",
  "name": "HaGeZi PRO",
  "entries": 250000,
  "is_empty": false,
  "last_update": "2026-10-08 10:30:00",
  "memory_limit_mb": 120
}
```

### 5.9 `runtime_info.backups` — New Object (v1.2.0+; refined v1.3.0)

**Endpoint**: `GET /api?action=runtime_info`

**v1.2.0+ addition** — a new `backups` object with **7 fields**:

```json
{
  "backups": {
    "available": 5,
    "in_flight_txn": 0,
    "orphan_txn": 0,
    "last_backup": "2026-10-08 15:00:00",
    "last_backup_name": "20261008-150000-manual-12345",
    "last_stable": "20261008-095826-v1.4.0-12345",
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

**v1.3.0 semantics change**:

Two of the seven fields are computed differently on v1.3.0+:

- **`available`** — **SNAP-MANIFEST**: a directory is counted
  iff it contains a `.manifest.json` file. The v1.2.0 name-pattern
  rule (`^[0-9]{8}-[0-9]{6}-`) is **superseded**. Custom-named
  snapshots are now visible; directories that match the name
  pattern but lack a manifest are no longer counted.
- **`last_backup_name`** — **SNAP-MTIME**: the "newest"
  snapshot is selected by **mtime** (descending), not by
  lexicographic directory name. This supersedes the v1.2.0
  BUG-3 rule. Robust against clock drift and manual renames.

**Client compatibility**:

- ✅ **JSON parsers** (any language): unaffected. New fields are
  ignored by code that reads only the original 5 fields. The two
  refined fields (`available`, `last_backup_name`) keep their
  types but may change their **values** in edge cases (custom-named
  snapshots, mtime vs. name divergence).
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
[`docs/BACKUP.md`](BACKUP.md) §8.1;
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.13.1.

### 5.10 `append_denylist` Requires `content` (v1.2.0+)

**Endpoint**: `POST /api/append_denylist`

**⚠️ Breaking change for callers** — this endpoint now requires a
`content` parameter.

**Before (v1.1.0 and earlier drafts of v1.2.0)**:

- Calling with no arguments re-saved the current denylist
  unchanged — a no-op that still consumed a pre-critical backup.

**After (v1.2.0+)**:

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
WebUI-side update is planned for **v1.5.0** (see
[`docs/ROADMAP.md`](ROADMAP.md) §5.1.11).

**Reference**: [`docs/API.md`](API.md) §6.2.7;
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §12.8.

### 5.11 Watchdog Token on `ensure_running_service` (v1.2.0+)

**Endpoint**: `POST /api/ensure_running_service`

**v1.2.0 change**: The endpoint now requires an
`X-Watchdog-Token` header for localhost requests.

**Before v1.2.0**: An implicit "localhost bypass" allowed the
watchdog to call this endpoint without auth. This was exploitable
via CSRF.

**After v1.2.0+**:

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

### 5.13 `remove_module` CodeQL Hardening (v1.4.0+)

**Endpoint**: `POST /api/remove_module`

**v1.4.0 change**: The endpoint now sanitizes the caller-provided
path via `filepath.Base()` and rebuilds the final path from the
trusted `MODULES_DIR` constant.

**Before v1.4.0**: The endpoint used `strings.HasPrefix` +
`filepath.Clean` — the two CodeQL `go/path-injection` alerts were
open.

**After v1.4.0+**: The two CodeQL alerts are closed.

**Client compatibility**:

- ✅ **Valid inputs** (any directory directly under
  `/data/adb/modules/`): unchanged behavior.
- ⚠️ **Malformed inputs** (empty basename, `.`, `..`, `/`-only):
  now short-circuit with an error before any file operation.

**Correct usage**:

```bash
curl -X POST -b /tmp/cookies.txt \
    -d "path=/data/adb/modules/dnscrypt-old" \
    http://127.0.0.1:9090/api/remove_module
```

**Reference**: [`docs/API.md`](API.md) §6.2.10;
[`docs/SECURITY.md`](SECURITY.md) §5.34;
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.12.3.

### 5.14 New Static Route `/app-debug.apk` (v1.4.0+)

**Endpoint**: `GET /app-debug.apk`

**v1.4.0 addition** — a public static route that serves the
optional companion Android app APK.

**Behavior**:

- **Public** (no auth required).
- **Mime type**: `application/vnd.android.package-archive`.
- **Cache-Control**: `public, max-age=3600, immutable`.
- **Returns 404** when the file is absent (dev build).

**Client usage**:

```bash
# Check the route
curl -sI http://127.0.0.1:9090/app-debug.apk | head -3

# Download the APK
curl -o DNS-Proxy.apk http://127.0.0.1:9090/app-debug.apk
```

**Reference**: [`docs/API.md`](API.md) §6.1.15;
[`docs/SECURITY.md`](SECURITY.md) §5.35.2;
[`docs/INSTALL.md`](INSTALL.md) §8.6.

### 5.15 MAIN-01 — `LOG_LEVEL` Load Order Fix (v1.4.0+)

**v1.4.0 change**: `main.go` now calls
`currentLogLevel = loadLogLevel()` **immediately after
`initPaths()`**, before any other log-emitting call.

**Before v1.4.0**: The load happened after `readSelectedProfile()`,
`applyMemoryLimit()`, `getWatchdogToken()`,
`checkPendingNotifications()`, and `cleanupOldTransactions()`.
Those early log lines were always emitted at the default `"info"`
level, even when the user had set `LOG_LEVEL=error` or
`LOG_LEVEL=warn` in `webui.conf`.

**After v1.4.0+**: Every log line — including those emitted during
startup initialization — respects the user's configured level.

**Client compatibility**: **None affected** — this is an
observability fix for the log stream only.

**Verification**:

```bash
# The startup banner should include this line
su -c "grep 'MAIN-01' /data/local/tmp/dnscrypt_main.log | tail -1"
# Expected: 🔧 v1.4.0: currentLogLevel loaded right after initPaths (MAIN-01)
```

**Reference**: [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.1 and
§11.37.

---

## 6. Emergency Recovery

### 6.1 If Installation Fails

```bash
# 1. Check storage
df -h /data
df -h /sdcard

# 2. Check ZIP integrity
unzip -t /sdcard/dnscrypt-webui-1.4.0-module.zip

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

**v1.2.0+ alternative**: use recovery mode (§6.8) — it restores
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

**v1.2.0+**: If the watchdog no longer restarts the DNS engine,
see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §5.15 (watchdog
token issues).

**v1.3.0+**: If the recovery path seems broken (e.g. `.last_stable`
points to a pruned snapshot), see
[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §4.16 (rotation
semantics issues).

### 6.4 If Settings Are Missing

**Scenario**: The automatic restore did not run (rare).

**v1.2.0+ (recommended)** — restore from the persistent backup:

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

**v1.3.0+ alternative** — if `current/` is more recent than the
newest snapshot, restore from `current/`:

```bash
SNAP=/sdcard/dnscrypt-webui-backup/current
# ... same 5 copy commands as above
```

**v1.0.0 legacy mechanism** (still available if the v1.2.0+ backup
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

**v1.2.0+ note**: `selected_profile.txt` is critical — it drives
the memory limit. If missing, `main.go` falls back to `"pro"`.

### 6.5 Full Module Removal

**v1.2.0+ change**: `uninstall.sh` **preserves** the persistent
backup directory at `/sdcard/dnscrypt-webui-backup/`. A future
reinstall will restore your settings automatically (via Layer 1).

**v1.4.0 note**: The companion Android app, if installed, is **not**
removed by `uninstall.sh`. Remove it separately via the Android
app manager.

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

# 5. v1.2.0+: remove the external recovery trigger
su -c "rm -f /data/adb/dnscrypt-recovery"

# 6. Reboot
su -c "reboot"
```

**To also remove the persistent backup directory** (v1.2.0+):

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

**To uninstall the companion app** (v1.4.0+):

1. Long-press the **DNS Proxy** icon → **Uninstall**.
2. Or: **Settings** → **Apps** → **DNS Proxy** → **Uninstall**.

**Note**: The installer's `uninstall.sh` performs steps 1–5
automatically when the module is removed via the Magisk app.

**v1.2.0+ uninstall policy summary**:

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
| Companion app (installed) | ❌ (not touched) |

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
| Backup directory missing | Reboot or `action.sh --backup` |
| Watchdog not restarting DNS | Check token file — §6.8 |
| Orphan-txn preserved | Inspect before deleting — §6.7 |
| Recovery mode triggered unintentionally | Remove trigger file — §6.8 |
| **v1.3.0+**: `.last_stable` points to a missing snapshot | See TROUBLESHOOTING §4.16.3 |
| **v1.3.0+**: custom-named snapshot is invisible | Add `.manifest.json` — TROUBLESHOOTING §4.16.1 |
| **v1.4.0**: Install button → "file not found" | Dev build; use browser PWA — §3.4.5 |
| **v1.4.0**: Companion app install fails | Allow "Install unknown apps" — §3.4.5 |
| **v1.4.0**: `remove_module` → "Invalid path" | Malformed input; use full module path — §3.4.6 |

### 6.7 Backup Location Reference

| Location | Purpose | Retention |
|---|---|---|
| `/sdcard/dnscrypt-webui-backup/` | **v1.2.0+** persistent backup | 21 snapshots (rotation) |
| `/sdcard/dnscrypt-webui-backup/current/` | **v1.2.0+** live snapshot | Always |
| `/sdcard/dnscrypt-webui-backup/txn-*/` | **v1.2.0+** in-flight transaction | Removed after commit/rollback |
| `/sdcard/dnscrypt-webui-backup/orphan-txn-*/` | **v1.2.0+** preserved interrupted install | Preserved on purpose |
| `/sdcard/dnscrypt-webui-backup/.last_stable` | **v1.2.0+** recovery pointer | Persistent (**ROT-PROTECT** protected since v1.3.0) |
| `/sdcard/dnscrypt-webui-backup/.upgrade_history.json` | **v1.2.0+** upgrade log | Append-only |
| `/sdcard/dnscrypt-webui-backup/*-v<digit>*/` | **v1.3.0+** newest install snapshot | Preserved by **ROT-PROTECT** |
| `/data/local/tmp/dnscrypt-upgrade-backup-*` | Legacy auto-backup | Deleted after restore |
| `/data/local/tmp/dnscrypt_backup_uninstall/` | Legacy uninstall backup | Removed in v1.2.0+ |
| `/sdcard/dnscrypt-backup-YYYYMMDD/` | Manual backup | User-managed |

**v1.2.0+ reminder**: The persistent backup directory is
**preserved** on uninstall. A future reinstall will find it
automatically via Layer 1 (multi-source detection).

**v1.3.0+ reminder**: The `.last_stable` target and the newest
install snapshot are protected from rotation. Even if they fall
outside the 21-newest window, they are never pruned.

### 6.8 Recovery Mode (v1.2.0+; strengthened v1.3.0)

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

**v1.3.0 improvement**: ROT-PROTECT ensures the `.last_stable`
target is **protected from rotation** even if it falls outside
the 21-newest window. This makes recovery mode significantly more
reliable on v1.3.0+ than it was on v1.2.0.

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

**If the recovery path seems broken** (e.g. `.last_stable` points
to a pruned snapshot), see
[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §4.16.3.

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

**Verify you are on a fixed version (v1.2.0 or newer)**:

```bash
# Module version must be v1.2.0 or newer
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# → version=v1.2.0 or newer

# The snapshot directory constant must be present
su -c "grep -q 'RECOVERY_SNAPSHOT_DIR' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (snapshot dir)'"

# The re-apply block (§[9b2]) must be present
su -c "grep -q 'Re-applying recovery snapshot' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (§[9b2] re-apply block)'"
```

**If the fix is missing**: reinstall the module from a v1.2.0 (or
newer) ZIP.

**v1.3.0 cross-reference**: The rotation refinements
(SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME,
ROT-PROTECT) strengthen the recovery path indirectly — the
`.last_stable` target that recovery mode relies on is now
**protected from rotation**. See
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.13.2, §11.33.

**Full analysis**: [`SECURITY.md`](SECURITY.md) §5.32.1.
**Flow diagram**: [`ARCHITECTURE.md`](ARCHITECTURE.md) §3.10.
**Emergency procedure**: [`EMERGENCY.md`](EMERGENCY.md) §9.6.

---

## 7. References

### 7.1 Related Documentation

| Document | Purpose |
|---|---|
| [`docs/INSTALL.md`](INSTALL.md) | Installation guide (§8.6 companion app) |
| [`docs/BRANCHING.md`](BRANCHING.md) | Git branching strategy |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Release process guide (§8.4, §8.5 signature/SBOM status) |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records |
| [`docs/API.md`](API.md) | Full HTTP API reference (§6.1.7, §6.1.15, §2.8) |
| [`docs/SECURITY.md`](SECURITY.md) | Security policy + Audit Corrections (§5.31, §5.32, §5.33, §5.34, §5.35) |
| [`docs/BACKUP.md`](BACKUP.md) | **Backup system reference (v1.2.0 + v1.3.0 rotation)** |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting guide (§4.15, §4.16, §5.16, §12.10) |
| [`docs/FAQ.md`](FAQ.md) | Frequently asked questions (Q111–Q130) |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | System architecture (§3.10, §4.10, §4.12, **§4.13 — v1.3.0 rotation refinements**, §6.8) |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Device compatibility matrix (**§10.3.5 — on-device SNAP-*/ROT-* verification**) |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries management (Level 4) |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Terms and abbreviations (SNAP-*/ROT-*, Rotation Guardian) |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition (**Rotation Guardian + Companion App Champion** badges) |
| [`docs/ROADMAP.md`](ROADMAP.md) | Future plans (§5 v1.5.0, §6 v1.6.0, §7 v2.0.0) |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history |
| [`README.md`](../README.md) | Overview |

### 7.2 Project Files

| File | Purpose |
|---|---|
| `proxy/customize.sh` | Magisk installer (10 defensive layers, §[8a] + §[9b2] for FIX-1) |
| `proxy/functions.sh` | Shared shell library (backup helpers + **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT**) |
| `proxy/main.go` | HTTP server (**SNAP-MANIFEST + SNAP-MTIME** in `buildBackupInfo`, MAIN-01 load order) |
| `proxy/service.sh` | Boot service launcher + periodic auto-backup + boot-path DNS auto-start (v1.3.0) |
| `proxy/watchdog.sh` | Standalone watchdog process (token auth, manifest-based snapshot counter) |
| `proxy/action.sh` | Magisk Action button (+ `--backup`, `--diagnose`, v1.3.0 rotation semantics) |
| `proxy/status.sh` | Status display (+ `--diagnose`, `--json`, v1.3.0 `_list_snapshots`) |
| `proxy/uninstall.sh` | Cleanup + orphan txn preservation (+ manifest-based snapshot count) |
| `proxy/app-apk.version` | **Companion app version pin (v1.4.0)** |
| `scripts/fetch_app_apk.sh` | **Companion APK fetcher (v1.4.0)** |
| `VERSION` | Single source of truth |
| `module.prop` | Magisk module definition |
| `update.json` | Auto-update metadata |

### 7.3 External References

- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [KernelSU Documentation](https://kernelsu.org/)
- [APatch](https://github.com/bmax121/APatch)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [Android FUSE — Storage Access Framework](https://source.android.com/docs/core/storage)
- [Android SELinux — restorecon](https://source.android.com/docs/security/features/selinux)
- [Android App Signing — Package Signature Verification](https://source.android.com/docs/security/features/apksigning)
- [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) — Companion app repository

> **Note on signing and SBOM**: As of v1.4.0, the module ZIP and
> the four WebUI binaries are **NOT** signed with Cosign or GPG,
> and **no SBOM** (SPDX or CycloneDX) is generated. Only the
> SHA-256 checksum (`.sha256` file) is attached to the release.
> The companion APK **is** signed (Android package signature by
> the app repository's CI). See
> [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) §8.4 and §8.5
> for the current status and roadmap.

---

<div align="center">

**Last updated**: 2026-10-08
**Version**: v1.4.0
**Author**: gasciljh

**💡 Tip**: Since v1.2.0, the persistent backup directory is
preserved on uninstall — reinstalling restores your settings
automatically!

**🛡️ v1.3.0+**: The `.last_stable` recovery pointer and the
newest install snapshot are protected from rotation — recovery
mode can no longer be silently broken!

**📱 v1.4.0**: An optional companion Android app is available —
see §3.4.5 for details.

[⬆ Back to top](#upgrade-guide--dnscrypt-smart-filter)

</div>