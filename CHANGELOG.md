# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Author**: gasciljh
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui

---

## [Unreleased]

> Changes that will land in the next release (`v1.3.0` or a future PATCH).
> Keep this section empty at the moment of each release.

### Planned (see `docs/ROADMAP.md` §5)

- Remove `'unsafe-inline'` from CSP (CSP hardening) — v1.3.0.
- Unify WebUI + Dashboard on a single port (PWA dual-origin fix) — v1.3.0.
- Dedicated maskable icon (`icon-maskable.svg` / `icon-maskable.png`) — v1.3.0.
- Backup integrity hardening (`BACKUP_INTEGRITY_MODE=enforce`) — v1.3.0.
- WebUI uses `append_denylist` with a `content` parameter — v1.3.0.
- Data Guardian badge tooling (`scripts/report-backup.sh`) — v1.3.0.
- Extended multi-language support (FR, DE, ES, RU, ZH) — v1.4.0.
- 2FA + Audit Logging — v1.4.0.

---

## [v1.3.0] - 2026-10-02

> **Feature release** — PWA install button + live status LED.

### Added

- **PWA install button (WebUI)** — a smart, dynamic install
  button that is **always visible** (except when the app is
  already installed or running standalone). Its behavior adapts
  to the browser:
    • Chromium-based browsers (Chrome, Edge, Brave, Samsung
      Internet) — clicking opens the native
      `beforeinstallprompt` dialog.
    • iOS Safari — clicking shows step-by-step "Add to Home
      Screen" instructions.
    • Unsupported browsers (Firefox, Opera Mini, older
      browsers) — clicking shows a friendly modal stating the
      browser is not supported, listing supported alternatives
      (Chrome, Edge, Brave) with Play Store links, so the user
      is guided rather than left without an explanation.
  The modal is fully language-aware (EN + AR). Implemented in
  `web/index.html` section [13c] and reflected in
  `web/manifest.json` via the new `x-note-v130` field.

- **Live status LED on the Today counter (WebUI)** — the
  "Today" stat now carries a 12x12 LED that pulses green when
  the DNS engine is running and turns solid red when the
  service is stopped. Implemented as pure CSS + JS, aligned
  with the existing `.status-dot` styling and the
  `updateStatsDisplay()` handler in `web/index.html`.

### 🐛 Fixed

- **`service.sh` — DNS auto-start after boot** (v1.3.0
  critical fix) — the DNS engine was not starting
  automatically after a device reboot when the user had
  previously left the service in the ON state. Root cause:
  `watchdog.sh` waits a fixed 30-second interval before its
  first API call, and by the time it fires
  `POST /api/ensure_running_service`, the WebUI may not have
  finished binding to its port. The watchdog would retry with
  exponential backoff (30s → 60s → 120s → ...), leaving DNS
  unavailable for minutes after boot.

  **Fix:** `service.sh` now performs a direct, bounded wait
  for the WebUI to become ready (up to 60 seconds, checking
  for the watchdog token file + the WebUI TCP port), then
  calls `POST /api/ensure_running_service` itself. This
  guarantees DNS starts within a few seconds of the WebUI
  coming up, without depending on the watchdog's polling
  interval.

  **Verified on-device:** DNS engine reaches "ON" state
  within 5 seconds of `service.sh` startup, with 3 processes
  running (webui + proxy + watchdog). See log block
  `[v1.3.0 FIX]` in `service.sh` section [19]. The
  `watchdog.sh` backoff behavior is left intact for crash
  recovery during normal runtime — it is only the boot path
  that now takes the direct route.

### Changed

- **Version bump across all metadata** — `VERSION`,
  `module.prop` (`version` + `versionCode=1030000`),
  `update.json` (`version` + `versionCode` + `versionName`
  + `zipUrl`), `web/sw.js` (`CACHE_VERSION`),
  `web/manifest.json` (`version`), the two SVG icons
  (`icon-192.svg`, `icon-512.svg`), and the header comments
  of `proxy/go.mod`, `scripts/generate-icons.sh`,
  `scripts/fetch_dns_binaries.sh`, and `proxy/webui.conf`.

- **`web/offline.html`** — version header, `<title>`,
  `pageTitle`, and `versionBadge` bumped to `v1.3.0`. The
  historical reference to the v1.2.0 data-preservation feature
  in `safeMsg2` (EN + AR) remains unchanged — the feature
  ships with v1.2.0, not v1.3.0.

- **`web/index.html` and `web/dashboard.html`** — internal
  documentation comments (IDX-* and DASH-* audit fixes) now
  carry the `v1.3.0` header. No behavioral change.

### Notes

- **Backward compatibility**: no breaking API changes.
  All additions since v1.2.0 are strictly additive.
- **Data preservation**: the 10-layer user-data preservation
  model (introduced in v1.2.0) is unchanged. The persistent
  backup directory `/sdcard/dnscrypt-webui-backup/` continues
  to protect the 5 user config files across upgrades,
  reinstalls, and uninstalls.
- **`docs/*.md`**: version headers remain at `v1.2.0` where
  they document historical behavior. Files that describe the
  current release have been updated separately.

---

## [v1.2.0] - 2026-09-30

> **Bug-fix release** — no new features, no breaking changes.

### 🐛 Fixed

- **`readLogFile` (main.go)** — the backward-seek fallback
  previously returned the OLDEST N bytes instead of the newest
  when `f.Seek(-N, io.SeekEnd)` failed. Now uses an
  `io.LimitReader` + tail-slice so the user always sees the
  most recent log entries.

- **`checkPendingNotifications` (main.go)** — the pending
  notification file is now validated before being forwarded to
  `logEvent`:
  - Non-`os.IsNotExist` read errors are logged at warn level.
  - Oversized payloads (>4 KB) are truncated with rune-boundary
    backoff (no multi-byte character is cut in half).
  - Invalid UTF-8 is rejected with a clear warning.
  - On read failure, a best-effort cleanup is attempted so a
    stuck file cannot loop indefinitely.

- **`rotate_backups` (functions.sh)** — retention counting now
  ignores snapshot directories that are empty or missing
  `.manifest.json`. Previously, partial/failed copies were
  counted and could displace valid snapshots from the
  retention window.

- **`verify_backup_integrity` (functions.sh)** — added an
  opt-in strict mode (`verify_backup_integrity <dir> 1`) that
  turns several silent skips into explicit failures:
  - Missing `.manifest.json` -> immediate return 1.
  - `sha256sum` unavailable -> immediate return 1.
  - Missing `sha256` entry in the manifest -> counted as error.
  - `checked != files_count` (from manifest) -> counted as error.
  Default behavior (strict=0) is unchanged and fully backward
  compatible.

- **`createAutoBackup` (main.go)** — on timeout, the partial
  target directory is now cleaned up after a 500 ms grace
  period, preventing accumulation of orphan snapshots on the
  SD card. Cleanup failures are logged at debug level only
  (non-fatal).

### Added

- **`--version` flag** on all six shell scripts
  (`action.sh`, `service.sh`, `status.sh`, `uninstall.sh`,
  `watchdog.sh`, `customize.sh`). Prints `<script>: v1.2.0`
  and exits 0. Note: `status.sh` already uses `-V` as an alias
  for `--verbose`, so only the long form is provided.

- **Observability:** `verify_backup_integrity` now always logs
  a `checked=N errors=M` summary line, regardless of mode.

- **`customize.sh` — content-based module discovery** — replaces
  the hardcoded `CANDIDATE_SOURCES` list with a scan of every
  `/data/adb/modules/*/` folder. The module is identified by
  `id=dnscrypt-proxy-webui` in `module.prop`, regardless of the
  folder name (renames, case variations, stale coexisting
  copies). When multiple candidates tie on file count, the
  HIGHEST VERSION wins; on version tie, the folder whose name
  equals `dnscrypt-proxy-webui` wins. This fixes silent data
  loss on upgrade when the module folder had been renamed.

- **`customize.sh` — stale module folder disambiguation** —
  after a successful restore, every other module folder with
  `id=dnscrypt-proxy-webui` (not the new `$MODPATH`, not the
  active source) is marked as disabled by touching a `disable`
  file. Magisk/KernelSU/APatch honor this flag. The change is
  reversible (`rm <dir>/disable`) and non-destructive.

- **`customize.sh` — blocklist reuse** — when upgrading, the
  previously generated `blocklist.raw` and `blocklist.txt`
  are copied from the active source install into the new one,
  saving ~30 seconds of network fetch on each upgrade. Both
  files remain regenerable (they are still omitted from the
  persistent backup, so no disk usage increase).

### Breaking Changes

None. Fully backward-compatible with v1.1.0 and v1.0.0.

### Notes

- The Magisk installer copy of `verify_backup_integrity` in
  `customize.sh` is duplicated for installer-context reasons
  and was not updated in this release. It will be aligned in
  a follow-up change.
- A deeper `runShellWithTimeout` fix (process-group kill via
  `SysProcAttr.Setpgid`) is planned for a future release.

---

## [v1.2.0-pre] - 2026-09-29

> **Data-Preservation Release** — the biggest reliability improvement
> since v1.0.0.
>
> No breaking changes. All `v1.0.0` and `v1.1.0` clients and
> configurations continue to work without modification. The one
> exception is `POST /api/append_denylist`, which now requires a
> `content` parameter (see §Breaking Changes below).
>
> **Audit Corrections Registry** remains at **#33** (the last entry
> from `v1.0.0`). `v1.2.0` is not an audit-correction release — its
> 10 defensive layers, 4 runtime additions (BAK-1..BAK-4), and 2
> correctness fixes (FIX-1, FIX-2) close a data-loss bug and harden
> the write path. See `docs/SECURITY.md` §5.31, §5.32, and §5.33 for
> the distinction.

### 📊 Overview

| Metric | Value |
|--------|:-----:|
| Total Audit Corrections | 33 (unchanged from v1.0.0) |
| Defensive layers | **10** (multi-source, persistent backup, transactions, recovery, etc.) |
| Runtime additions | **4** (BAK-1, BAK-2, BAK-3, BAK-4) |
| Correctness fixes | **2** (FIX-1, FIX-2) |
| New `runtime_info` fields | **1 object** (7-field `backups`) |
| New CLI tools | **2** (`action.sh --backup`, `status.sh --diagnose`) |
| Documentation files updated | **19** |
| New documentation files | **2** (`BACKUP.md`, `EMERGENCY.md`) |
| Test scenarios (CI matrix) | **42** (`upgrade-test.yml`) |
| Platform coverage | Android / Linux / macOS / WSL2 |

### ✨ Highlights

- **10 defensive layers** for user-data preservation — replaces the
  fragile "detect upgrade?" heuristic with a "search everywhere"
  philosophy. Fixes a **silent data-loss bug** in v1.1.0 that
  erased the 5 user config files on every in-place upgrade.
- **Persistent backup directory** at
  `/sdcard/dnscrypt-webui-backup/` — survives reboot, uninstall,
  and factory reset of `/data`.
- **Transactional upgrades** with automatic rollback — a failed
  install cannot leave the module in a partial state.
- **Recovery mode** — a trigger file restores the last known-good
  config on the next boot.
- **Bilingual WebUI** (English default + Arabic toggle) — client-side
  only, no server state.
- **7-field `runtime_info.backups`** object — new observability
  surface for the backup layer.
- **Watchdog token** (`X-Watchdog-Token`) — closes a CSRF hole on
  `POST /api/ensure_running_service`.
- **Two new CLI tools** — `action.sh --backup` and
  `status.sh --diagnose` (Layer 10).
- **42-scenario CI matrix** (`upgrade-test.yml`) — validates the
  10 defensive layers before every release.

### Added

#### Backend (Go) — v1.2.0

- **`createAutoBackup(reason string)`** — snapshots the 5 user
  config files before a destructive operation. Called from 4
  endpoint groups (one call site per group):
  - `updateProfile` → `"pre-profile-change"`
  - `saveAllowlist` → `"pre-allowlist-save"`
  - `saveDenylist` → `"pre-denylist-save"` (also used by
    `appendDenylist`, which delegates to `saveDenylist`)
  - `saveCustomRulesCombined` → `"pre-custom-rules-save"`
- **`backupMu sync.Mutex`** — serializes pre-critical backups.
  Bounded by `AUTO_BACKUP_TIMEOUT = 15 s`.
- **`cleanupOldTransactions()`** — removes leftover `COMMIT`'d
  `txn-*` directories at startup. Preserves `START`, `ROLLBACK`,
  and `orphan-txn-*`.
- **`checkPendingNotifications()`** — reads `.pending_notification`
  at startup, logs its content, and removes the file.
- **`buildBackupInfo()`** — returns the **7-field `backups` object**
  from `runtime_info`:
  - `available`, `in_flight_txn`, `orphan_txn`, `last_backup`,
    `last_backup_name`, `last_stable`, `path`.
- **`loadOrCreateWatchdogToken()`** — generates a 32-byte token
  from `crypto/rand`, writes it atomically (tmp + rename) to
  `$RUN_DIR/.watchdog_token` (mode `0600`).
- **`verifyWatchdogToken()`** — constant-time comparison via
  `subtle.ConstantTimeCompare`.
- **`runShellWithTimeout(cmd, timeout)`** — runs a shell command
  with a bounded timeout. Distinguishes timeout from exit non-zero
  in the log.
- **`lastUpdateMu sync.Mutex`** — TTL-based cache for
  `last_update` (5 s).
- **`USER_AGENT` derived from `BuildVersion`** — custom
  `-ldflags` no longer leave a stale UA.
- **`/api/runtime_info/`** (trailing slash) — both variants return
  the same JSON.
- **`getEntriesCount`** — now caches `lastSize` even when count is
  `0` (fewer full scans on the "no blocklist yet" state).
- **`readLogFile`** — a failed `Seek` is now handled explicitly.

#### Shell Scripts — v1.2.0

- **`functions.sh:backup_user_files`** — snapshots the 5 user
  config files to `/sdcard/dnscrypt-webui-backup/`.
- **`functions.sh:restore_user_files`** — restores with SELinux
  context + verification.
- **`functions.sh:rotate_backups`** — prunes to `keep_count`
  (default 21), sorted by directory name (not mtime).
- **`functions.sh:auto_backup_if_needed`** — periodic backup
  (24 h).
- **`functions.sh:cleanup_old_transactions`** — removes leftover
  `COMMIT`'d `txn-*` dirs.
- **`functions.sh:copy_with_context`** — copies a file with its
  SELinux context and `chmod 0600`.
- **`functions.sh:verify_backup_integrity`** — 3-tier hash
  extraction (`jq` → `awk` → `grep`/`sed`).
- **`functions.sh:write_manifest`** — writes `.manifest.json` with
  per-file SHA256.
- **`functions.sh:get_backup_dir`**, **`ensure_backup_dir`**,
  **`get_last_backup_time`** — helpers.
- **`functions.sh:get_watchdog_token`** (FSH-11) — reads
  `$RUN_DIR/.watchdog_token`.
- **`customize.sh`** — 10 defensive layers (rewritten):
  - Layer 1: multi-source detection (7 candidates).
  - Layer 2: persistent backup.
  - Layer 3: SHA256 integrity.
  - Layer 4: transactional install with rollback.
  - Layer 5: root-solution detection.
  - Layer 6: SELinux preservation.
  - Layer 7: recovery mode (trigger file).
  - Layer 8: config migrations.
  - Layer 9: rotation (max 21 snapshots).
  - Layer 10: `.upgrade_history.json` log.
- **`customize.sh §[19b]`** — pre-generates the watchdog token
  (64-hex from `/dev/urandom`).
- **`customize.sh §[8a]/§[9]/§[9b2]`** — **snapshot-and-reapply**
  strategy for recovery mode (FIX-1). `§[8a]` restores the 5 files
  into `$MODPATH/proxy/` **and** copies each to
  `$MODPATH/.recovery_snapshot/`. `§[9]` extracts the ZIP normally.
  `§[9b2]` re-applies the 5 files from the snapshot.
- **`service.sh`** — runs `auto_backup_if_needed(24 h)` +
  `rotate_backups(21)` + `cleanup_old_transactions` at boot.
- **`status.sh --diagnose`** — full diagnostic report (Layer 10).
- **`status.sh --json`** — 7-field `backups` object.
- **`action.sh --backup`** — manual backup trigger.
- **`action.sh --diagnose`** — full diagnostic trigger.
- **`watchdog.sh`** — reads `$RUN_DIR/.watchdog_token` on every
  API call and sends it as `X-Watchdog-Token` header.
- **`watchdog.sh`** — read-only snapshot of backup state in
  startup banner.
- **`uninstall.sh`** — preserves the persistent backup directory,
  renames `txn-*` with `.state=START` to `orphan-txn-*`, removes
  the external recovery trigger.

#### Frontend (PWA) — v1.2.0

- **`web/index.html`** — bilingual (English default + Arabic
  toggle). `translations.en` + `translations.ar` objects.
- **`web/dashboard.html`** — same bilingual additions.
- **`web/offline.html`** — bilingual additions + "Your data is
  safe" info box + recovery mode hint.
- **`web/index.html` / `web/dashboard.html`** — System Info panel
  now displays 6 backup fields from `runtime_info.backups`.
- **`web/sw.js`** — `CACHE_VERSION` bumped to `v1.2.0`.
  Documented SW independence from the backup layer.
- **`web/manifest.json`** — `lang=en` (default), `dir=ltr`
  (default). New `x-note-backup`, `x-note-backup-paths`,
  `x-note-recovery`, `x-note-language`, `x-note-docs`.

#### CI/CD — v1.2.0

- **`.github/workflows/ci.yml`** — new `backup-smoke-test` job:
  - `bash -n` on 8 shell scripts.
  - `shellcheck --severity=warning` on 5 scripts.
  - Function-presence checks for all 10 defensive layers.
  - `PERSISTENT_BACKUP` path consistency.
  - v1.2.0 documentation reference checks.
- **`.github/workflows/upgrade-test.yml`** — new **42-scenario
  matrix** (3 root solutions × 2 source versions × 7 scenarios).

#### Documentation — v1.2.0

- **`docs/BACKUP.md`** — **new file** (backup system reference).
  Covers the 10 defensive layers, directory layout, triggers,
  file formats, rotation, manual operations, programmatic access,
  verification, troubleshooting, migration, and security model.
- **`docs/EMERGENCY.md`** — **new file** (emergency recovery).
  Covers bootloop recovery, data-loss recovery, WebUI
  unreachability, firewall issues, corrupted backup directory,
  recovery mode, and last-resort recovery.
- **`docs/ARCHITECTURE.md` §3.10** — Backup & Restore Flow.
- **`docs/ARCHITECTURE.md` §4.10** — v1.2.0 Backend Additions
  (BAK-1..BAK-4, WD-TOKEN).
- **`docs/ARCHITECTURE.md` §6.7** — Bilingual WebUI (language toggle).
- **`docs/API.md` §6.1.7** — 7-field `backups` schema.
- **`docs/API.md` §10.6** — Backup diagnostics examples.
- **`docs/API.md` §10.7** — Recovery mode examples.
- **`docs/API.md` §10.8** — Language-neutral API.
- **`docs/SECURITY.md` §5.31** — Data Preservation Security Model.
- **`docs/SECURITY.md` §5.32** — Correctness Fixes (FIX-1, FIX-2).
- **`docs/SECURITY.md` §5.33** — Watchdog Token (WD-TOKEN).
- **`docs/SECURITY.md` §14.25–§14.30** — 6 new audit checklist
  sections.
- **`docs/COMPATIBILITY.md` §2.5** — Backup Compatibility by
  Android Version.
- **`docs/COMPATIBILITY.md` §8.4** — v1.2.0-specific Issues
  (backup directory missing, recovery mode runs twice, orphan-txn
  preserved, backups returns 7 fields, bilingual toggle partial
  RTL).
- **`docs/TROUBLESHOOTING.md` §4.13, §4.14, §5.15, §7.8, §10.4,
  §12.8, §12.9, §13.4, §13.5, §14.5, §15.14, §15.15** — backup
  + recovery diagnostics.
- **`docs/FAQ.md` Q121–Q130** — 10 new v1.2.0-specific questions.
- **`docs/CONTRIBUTING.md` §8.9–§8.11, §9.5, §9.6** — backup
  testing, matrix testing, bilingual testing, documentation
  patterns. Golden Rule #22 / #23.
- **`docs/DEVELOPMENT.md` §8.12–§8.14** — backup debugging,
  matrix testing, bilingual debugging.
- **`docs/INSTALL.md` §4.3, §4.4, §7.12, §7.13, §10.7, §10.8** —
  10-layer install, backup layer verification, manual backup,
  preserved backup after uninstall, recovery mode.
- **`docs/UPGRADE.md` §1.4, §3.1, §5.9–§5.12, §6.8** — data
  preservation model, v1.1.0→v1.2.0 upgrade, new API fields,
  append_denylist content, watchdog token, recovery mode.
- **`docs/GLOSSARY.md`** — 20+ new terms for v1.2.0
  (Persistent Backup, Transactional Upgrade, `txn-*`,
  `orphan-txn-*`, `backupMu`, `createAutoBackup`,
  `cleanupOldTransactions`, `checkPendingNotifications`,
  `copy_with_context`, `write_manifest`,
  `verify_backup_integrity`, Data Guardian, Root-Solution
  Detection, BAK-1..BAK-4, FIX-1/FIX-2, Bilingual WebUI).
  Plus 4 new abbreviations (FBE, MTP, FUSE, OTA).
- **`docs/HALL_OF_FAME.md`** — Data Guardian badge (v1.2.0).
- **`docs/ROADMAP.md` §4, §12** — v1.2.0 delivered section +
  Data-Preservation Registry.
- **`docs/BRANCHING.md`** — v1.2.0 changes block + version
  examples updated.
- **`docs/RELEASE_PROCESS.md` §1.6, §8.3, §10.5** — v1.2.0
  reference, verification steps, sync note.
- **`docs/DNS_BINARIES.md`** — v1.2.0 changes block + §11.8–§11.10.
- **`README.md`** — Version badge, 10-layer description, Data
  Preservation section, Persistent Backup Directory tree,
  Backup Storage metrics, Data Guardian badge.

### Changed

#### Backend (Go)

- **`main.go`** — Version string `v1.1.0` → `v1.2.0` (in
  `USER_AGENT`).
- **`main.go`** — `handleAPI` now calls `createAutoBackup(reason)`
  before 5 destructive endpoints.
- **`main.go`** — `handleAPI` now registers `/api/runtime_info/`
  (trailing slash) in addition to `/api/runtime_info`.
- **`main.go`** — `appendDenylist` now requires a `content`
  parameter and appends it. Returns distinct messages for
  `"Processed N rules"` vs `"No changes detected"`.
- **`main.go`** — `buildRuntimeInfo()` now exposes the 7-field
  `backups` object.
- **`main.go`** — `buildBackupInfo()` sorts snapshots by directory
  **name** (not mtime) for stability across `rsync` copies.
- **`main.go`** — `runShellWithTimeout` now distinguishes timeout
  from exit non-zero in the log.
- **`main.go`** — `cleanupOldTransactions()` called at startup.
- **`main.go`** — `checkPendingNotifications()` called at startup.

#### Shell Scripts

- **`customize.sh`** — rewritten for the 10 defensive layers.
  Snapshot-and-reapply strategy for recovery mode (FIX-1).
- **`customize.sh`** — `createAutoBackup` is no longer called
  twice from `appendDenylist` (BUG-1). One snapshot per call.
- **`functions.sh`** — `backup_user_files` and
  `auto_backup_if_needed` append `-$$` (PID) to their default
  target directory names (FSH-10) to prevent same-second
  collisions.
- **`service.sh`** — runs the periodic auto-backup + rotation +
  transaction cleanup at boot.
- **`status.sh`** — default output gains a "Backup & Recovery"
  section.
- **`action.sh`** — `--check` output gains a "Backup & Recovery"
  section.
- **`uninstall.sh`** — preserves the persistent backup directory,
  renames `txn-*` with `.state=START` to `orphan-txn-*`, removes
  the external recovery trigger (`/data/adb/dnscrypt-recovery`).
- **`watchdog.sh`** — no longer participates in any of the 10
  defensive layers. Read-only with respect to the backup
  directory. Sends `X-Watchdog-Token` header on every call.

#### Frontend (PWA)

- **`web/sw.js`** — `CACHE_VERSION` bumped from `v1.1.0` to
  `v1.2.0`. Documented SW independence from the backup layer.
- **`web/index.html`** — `var VERSION = 'v1.2.0'`. Bilingual
  toggle added. `[dir="rtl"]` CSS rules. `langToggle` button in
  the header. SW update-banner fix (FIX-2).
- **`web/dashboard.html`** — `var VERSION = 'v1.2.0'`. Same
  bilingual additions. SW update-banner fix completed
  (FIX-2). Added `<div id="swUpdateBanner">`.
- **`web/offline.html`** — `var VERSION = 'v1.2.0'`. Bilingual
  additions. `[dir="rtl"]` CSS rules.
- **`web/manifest.json`** — `version` field bumped to `1.2.0`.
  `lang=en` (default), `dir=ltr` (default). New meta notes.

#### Build & Configuration

- **`VERSION`** — `v1.1.0` → `v1.2.0`.
- **`module.prop`** — `version=v1.2.0`, `versionCode=1020000`.
- **`update.json`** — `version=v1.2.0`, `versionCode=1020000`,
  `zipUrl` updated to reference the `v1.2.0` tag.
- **`.github/workflows/ci.yml`** — new `backup-smoke-test` job.
- **`.github/workflows/upgrade-test.yml`** — **new file**
  (42-scenario matrix).
- **`.github/PULL_REQUEST_TEMPLATE.md`** — new "Data-preservation
  checklist" section + "Global edition (EN + AR)" checklist item.
- **`.github/PULL_REQUEST_TEMPLATE/release.md`** — new v1.2.0
  data-preservation checks.
- **`.github/CODEOWNERS`** — enumerates data-preservation files.
- **`Makefile`** — new `check-backup`, `check-all`,
  `diagnose-help` targets.
- **`README.md`** — Version badge `v1.1.0` → `v1.2.0`. Data
  Preservation section. Persistent Backup Directory tree.
  Backup Storage metrics table. Data Guardian badge reference.
- **`SECURITY.md`** (root) — v1.2.0 changes summary +
  BAK-1..BAK-4 summary.
- **`.gitignore`** — new backup staging patterns in §[19].
- **`.gitattributes`** — `proxy/dnscrypt-proxy.version` rule added.
- **`.editorconfig`** — `[proxy/run/*.tmp_*]` pattern added.

### Fixed

#### Critical (data preservation)

- **Silent data-loss bug in v1.1.0** — The installer used a
  path-comparison check (`$_EXISTING_MODULE != $MODPATH`) that
  always failed on in-place upgrades. As a result, the 5 user
  config files were silently erased on every upgrade. Fixed by
  the 10 defensive layers (Layer 1 multi-source detection + Layer
  2 persistent backup). See `docs/SECURITY.md` §5.31.

#### Important (correctness)

- **FIX-1 — Recovery-mode correctness** — In an early v1.2.0
  draft, the ZIP extraction step (`customize.sh §[9]`) ran
  **after** the recovery restore (`§[8a]`) and overwrote
  `webui.conf` and `dnscrypt-proxy.toml` with the ZIP's defaults.
  The subsequent restore step (`§[9c]`) was skipped in recovery
  mode, so 2 of the 5 restored files were silently lost.
  Fixed with a **snapshot-and-reapply** strategy:
  `§[8a]` restores the 5 files **and** copies each to
  `$MODPATH/.recovery_snapshot/`; `§[9]` extracts the ZIP
  normally (extraction logic untouched, so the normal-install
  path stays byte-for-byte identical); `§[9b2]` re-applies the 5
  files from the snapshot. The snapshot directory is preserved
  only if the re-apply is partial, so it never appears in the
  final module layout.
- **FIX-2 — Service Worker update-banner** — The v1.1.0 fix
  applied only to `index.html`. The [Reload] button sent
  `SKIP_WAITING` to `navigator.serviceWorker.controller` (the
  **old** worker), which ignored it. The new worker stayed in the
  `waiting` state, so the banner reappeared on every page reload.
  Fixed by sending `SKIP_WAITING` to `swRegistration.waiting`,
  reloading on `controllerchange`, and guarding double-clicks.
  Applied to **both** `index.html` and `dashboard.html`.

#### Post-Audit Corrections (BUG-1..BUG-6, N-1, N-4)

The v1.2.0 post-audit pass applied 7 corrections to
`proxy/main.go` (plus one user-agent derivation fix):

| ID | Scope | Observable effect |
|---|---|---|
| **BUG-1** | `appendDenylist` — pre-critical backup performed **once** | One snapshot per call instead of two |
| **BUG-2** | `createAutoBackup` — stderr no longer discarded | Failed backups now visible in log |
| **BUG-3** | `buildBackupInfo` — sort by directory **name** not mtime | `last_backup_name` matches `status.sh --json` |
| **BUG-4** | `readLogFile` — failed `Seek` handled explicitly | `?action=read_log` no longer silently returns wrong slice |
| **BUG-5** | `appendDenylist` — response distinguishes "applied" from "no changes" | See `docs/API.md` §6.2.7 |
| **BUG-6** | `main()` registers `/api/runtime_info/` (trailing slash) | See `docs/API.md` §6.1.7 |
| **N-1** | `USER_AGENT` derived from `BuildVersion` | Custom `-ldflags` no longer leave stale UA |
| **N-4** | `getEntriesCount` caches `lastSize` even when count is `0` | Fewer full scans on "no blocklist yet" |

#### Minor

- **`append_denylist`** — the endpoint no longer acts as a
  no-op when called without arguments. It now requires a
  `content` parameter (BUG-A fix in early drafts). Callers that
  relied on the no-op behavior must now send a `content`.
- **`isPidAlive`** — matches exact command names (no substring).
- **Watchdog token file** — written atomically (BUG-L).

### Removed

- **Legacy `BACKUP_TMP` mechanism** — the v1.0.0 backup flow
  (`/data/local/tmp/dnscrypt-upgrade-backup-$$`) is **superseded**
  by the v1.2.0 persistent backup at
  `/sdcard/dnscrypt-webui-backup/`. The mechanism itself was
  removed from `customize.sh`; the directory name is still cleaned
  up by `uninstall.sh` for users upgrading from v1.0.0.
- **Legacy v1.0.0 backup directory** —
  `/data/local/tmp/dnscrypt_backup_uninstall/` is removed
  automatically by `uninstall.sh`.
- **No features were removed.** All v1.0.0 and v1.1.0 APIs and
  endpoints remain functional.

### Deprecated

- Nothing in this release.

### Security

- **No new audit corrections.** The Audit Corrections Registry
  remains at **#33** (last entry from v1.0.0).
- **Watchdog token (WD-TOKEN)** — closes a CSRF hole on
  `POST /api/ensure_running_service`. Replaces the previous
  implicit "localhost bypass" that allowed any page in a browser
  on the same device to silently trigger a service restart. See
  `docs/SECURITY.md` §5.33.
- **`backupMu`** — serializes pre-critical backups. Prevents two
  rapid user actions from corrupting a snapshot.
- **Backup directory permissions** — `0700` on directories,
  `0600` on files.
- **SHA256 integrity verification** — advisory per-file checksum.
  A mismatch is logged but does not block a restore.
- **SELinux context preservation** — `restorecon` (preferred) or
  `chcon u:object_r:magisk_file:s0` (fallback) on every restored
  file.
- **All v1.0.0 and v1.1.0 security fixes remain in place** —
  Login POST-only, `/readyz` localhost-only, `shellQuote`,
  `readConfPort` range check, Basic Auth rate limiting,
  `rebuildMu` mutex, auth cache, Custom Chains, STATUS_FILE
  semantics, `hasEndpoint` exact matching, `runtime_info` dynamic
  ports, dynamic memory limit per profile, extended `shellQuote`
  charset, `MONITORING_UI_PORT` constant.

### Breaking Changes

**One breaking change for API consumers** — everything else is
additive.

- **`POST /api/append_denylist`** — now **requires** a `content`
  parameter. Without it → `400 Bad Request`:
  ```json
  {"status": "error", "message": "Missing or empty 'content' parameter"}
  ```
  - **Why**: In earlier drafts, the endpoint took no arguments and
    re-saved the current denylist unchanged — a no-op that still
    consumed a pre-critical backup.
  - **Migration**: Send `content` (URL-encoded). Or use
    `POST /api/save_denylist` with the full new content.
  - **WebUI**: does not currently use this endpoint (it uses
    `save_denylist`). The WebUI-side update is planned for v1.3.0.

**Everything else is additive**:

- All other API endpoints work with the same paths, methods, and
  auth.
- All config files (`webui.conf`, `dnscrypt-proxy.toml`) keep the
  same format.
- All shell script CLI flags work the same way, plus two new
  ones (`--backup`, `--diagnose`).
- All previously-issued v1.1.0 tokens and cookies remain valid
  (session GC schedule unchanged).
- The 7-field `backups` object is strictly additive — clients
  that read only the original 5 fields continue to work.
- The bilingual WebUI is a client-side concern only — the API is
  language-neutral.

### Notes

#### Audit Corrections Registry — Unchanged

`v1.2.0` does **not** extend the Audit Corrections Registry. The
last entry is #33 (from v1.0.0). New audit corrections will resume
at **#34** in v1.3.x. See `docs/SECURITY.md` §17.

#### What is Preserved

The 5 user config files preserved by the 10 defensive layers:

| File | Purpose |
|---|---|
| `webui.conf` | WebUI + Dashboard ports, `BIND_ADDR`, `LOG_LEVEL` |
| `dnscrypt-proxy.toml` | DNSCrypt engine config + credentials |
| `selected_profile.txt` | Active blocklist profile |
| `allowlist.txt` | User-defined allowlist |
| `denylist.txt` | User-defined denylist |

**Not preserved** (rebuilt or re-downloaded):
`blocklist.txt`, `blocklist.raw`, `public-resolvers.md`,
`blocked-ips.txt`, binaries, logs, and the `run/` directory.

#### Version Files — Where to Update

At each release, the version string appears in:

| File | Field | v1.2.0 value |
|---|---|---|
| `VERSION` | entire file | `v1.2.0` |
| `module.prop` | `version=` | `v1.2.0` |
| `module.prop` | `versionCode=` | `1020000` |
| `update.json` | `.version` | `v1.2.0` |
| `update.json` | `.versionCode` | `1020000` |
| `web/manifest.json` | `.version` | `1.2.0` (no `v`) |
| `web/sw.js` | `CACHE_VERSION` | `v1.2.0` |
| `web/index.html` | `var VERSION` | `v1.2.0` |
| `web/dashboard.html` | `var VERSION` | `v1.2.0` |
| `proxy/main.go` | `USER_AGENT` | `v1.2.0` |

`scripts/release.sh` updates the first five automatically. The
rest must be updated manually if they reference the version.

#### Rolling Back to v1.1.0

If needed (rare), roll back via Magisk Manager:

```bash
# 1. Download the v1.1.0 ZIP
wget https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.1.0/dnscrypt-webui-1.1.0-module.zip

# 2. Install over the current one from Magisk Manager
# 3. Reboot
```

**Rollback caveats**:

- ⚠️ `runtime_info.backups` reverts to 5 fields (if present at all).
- ⚠️ `action.sh --backup` stops working.
- ⚠️ `status.sh --diagnose` stops working.
- ⚠️ The persistent backup directory is **preserved** (not touched).
- ⚠️ The bilingual WebUI reverts to English-only if v1.1.0 was
  English-only.

Your settings (5 files) remain preserved during rollback.

#### Not Included

The following items were considered and intentionally **not**
added in `v1.2.0`:

- **CSP hardening** (removing `'unsafe-inline'` from
  `script-src`) — deferred to v1.3.0.
- **PWA port unification** (serving Dashboard from `9090/dashboard`)
  — deferred to v1.3.0.
- **Dedicated maskable icon** — deferred to v1.3.0.
- **Backup integrity enforcing mode** (`BACKUP_INTEGRITY_MODE=enforce`)
  — deferred to v1.3.0. Currently advisory only.
- **WebUI uses `append_denylist`** — deferred to v1.3.0.
- **Data Guardian badge tooling** — deferred to v1.3.0.
- **Extended multi-language support** (FR, DE, ES, RU, ZH) —
  deferred to v1.4.0.
- **JWT authentication alternative to cookies** — deferred to
  v1.4.0.

---

## [v1.1.0] - 2026-09-26

> **Polish Release** — Documentation + three runtime improvements.
>
> No breaking changes. All `v1.0.0` clients and configurations
> continue to work without modification.
>
> **Audit Corrections Registry** remains at **#33** (the last entry
> from `v1.0.0`). `v1.1.0` is not an audit-correction release — the
> three runtime changes (MEM-1, MEM-2, MEM-3) close edge cases rather
> than fix known exploitable vulnerabilities. See `docs/SECURITY.md`
> §17.1 for the distinction.

### 📊 Overview

| Metric | Value |
|--------|:-----:|
| Total Audit Corrections | 33 (unchanged from v1.0.0) |
| Runtime improvements | **3** (MEM-1, MEM-2, MEM-3) |
| New `runtime_info` fields | **2** (`profile_key`, `memory_limit_mb`) |
| Documentation files updated | **16** |
| Platform coverage | Android / Linux / macOS / WSL2 |

### ✨ Highlights

- **Dynamic memory limit per profile (MEM-1)** — `main.go` now sets
  `debug.SetMemoryLimit` per active blocklist profile instead of the
  hardcoded 80 MB. Prevents GC thrashing on `ultimate`.
- **Extended `shellQuote` charset (MEM-2)** — adds `{`, `}`, `\n`, `\t`
  to the escape list. Defense-in-depth.
- **`MONITORING_UI_PORT` constant (MEM-3)** — `metricsProxyHandler`
  no longer contains the hardcoded string `"8080"`.
- **Two new `runtime_info` fields** — `profile_key` + `memory_limit_mb`
  exposed via API and displayed in both WebUI and Dashboard.
- **CRITICAL: `offline.html` CSP fix** — removed the restrictive CSP meta
  that silently blocked the offline page's own scripts.

### Added

#### Backend (Go) — v1.1.0

- **`memoryLimitForProfile(key string) int64`** — returns the soft
  memory limit for a profile key.
  - `light` → 80 MB
  - `normal` → 100 MB
  - `pro` → 120 MB
  - `proplus` → 160 MB
  - `ultimate` → 220 MB
- **`applyMemoryLimit(key string)`** — applies the limit via
  `debug.SetMemoryLimit` and logs the transition. Thread-safe
  (`memLimitMu sync.Mutex`).
- **`readSelectedProfile() string`** — reads the active profile from
  `selected_profile.txt`, falls back to `"pro"` for unknown values.
- **`memLimitMu sync.Mutex`** + `currentMemLimit int64` +
  `currentProfile string` — new concurrency primitives for the
  memory-limit state.
- **`runtime_info` new fields** — `profile_key`, `memory_limit_mb`.
- **`get_profile` new field** — `memory_limit_mb`.

#### Shell Scripts — v1.1.0

- **`functions.sh:get_profile_memory_hint()`** — read-only helper
  returning `"120 MB (pro)"` style strings for user-facing display.
- **Inline fallback `_inline_get_profile_memory_hint`** in 4 scripts
  (`service.sh`, `action.sh`, `status.sh`, `watchdog.sh`) — keeps
  logs informative even if `functions.sh` is unavailable.
- **`customize.sh`** — computes and prints the expected memory limit
  at install time (informational only; `main.go` remains the authority).
- **`status.sh --check`** — new fields: `PROFILE=pro | MEM=120 MB (pro)`.
- **`status.sh --json`** — new `profile` object with `key`, `name`,
  `memory_limit_mb`.
- **`status.sh`** — new "Profile & Memory" section in default output.
- **`service.sh`** — logs active profile + memory hint at boot.
- **`action.sh --check`** — new "Profile & Memory" section.
- **`watchdog.sh`** — logs profile + memory hint at startup.

#### Frontend (PWA) — v1.1.0

- **`web/index.html`** — System Info panel now displays
  `profile_key` + `memory_limit_mb` (v1.1.0 fields).
- **`web/dashboard.html`** — same System Info additions.
- **`web/manifest.json`** — added `x-note-memory`,
  `x-note-runtime-info`, `x-note-icon-source` (documentation fields).
- **`web/icon-192.svg`** — header clarified: purpose `any` (not maskable).
- **`web/icon-512.svg`** — header corrected: this SVG is the source
  for 4 PNGs, NOT all of them. Honest safe-zone assessment added.

#### Documentation — v1.1.0

- **`docs/SECURITY.md` §5.30** — new section documenting MEM-1, MEM-2,
  MEM-3 from a security-posture perspective.
- **`docs/SECURITY.md` §14.22–14.24** — three new audit checklist
  sections.
- **`docs/ARCHITECTURE.md` §3.9** — Memory Limit Flow diagram.
- **`docs/ARCHITECTURE.md` §4.9** — v1.1.0 Backend Additions.
- **`docs/ARCHITECTURE.md` §11.22** — dynamic vs static memory limit
  trade-off.
- **`docs/API.md` §2.1** — Memory limits per profile table.
- **`docs/API.md` §6.1.7** — `runtime_info` updated schema.
- **`docs/COMPATIBILITY.md` §5.4** — Memory profile by device RAM.
- **`docs/COMPATIBILITY.md` §8.3** — four v1.1.0-specific issues.
- **`docs/TROUBLESHOOTING.md` §4.12, §5.14, §6.10** — memory-limit
  diagnostics.
- **`docs/TROUBLESHOOTING.md` §15.13** — memory diagnostics helper.
- **`docs/FAQ.md` Q111–Q120** — 10 new v1.1.0-specific questions.
- **`docs/INSTALL.md` §4.4** — expected memory limit line in the
  install summary.
- **`docs/UPGRADE.md` §3.0** — full v1.0.0 → v1.1.0 upgrade guide.
- **`docs/GLOSSARY.md`** — MEM-1, MEM-2, MEM-3, `profile_key`,
  `memory_limit_mb`, "soft limit" terms.
- **`docs/HALL_OF_FAME.md`** — Memory Architect badge (v1.1.0).

#### Dev Workflow Infrastructure

The following additions were developed during the `v1.0.0 → v1.1.0`
cycle and are now part of `v1.1.0`.

##### Branching & Release Documentation

- **`docs/BRANCHING.md`** — complete Git branching strategy guide.
  - Two-branch model: `main` (stable releases) + `develop` (integration).
  - Short-lived branch conventions: `feature/*`, `fix/*`, `docs/*`,
    `chore/*`, `refactor/*`, `test/*`, `release/*`, `hotfix/*`.
  - Naming rules, workflows, PR rules, and protection policy.
  - Hotfix flow with back-merge requirement.
  - 10 sections, ~28 KB.

- **`docs/RELEASE_PROCESS.md`** — complete release process guide.
  - Release types: Stable, Prerelease, Hotfix.
  - Version bumping (SemVer + `versionCode` formula).
  - `scripts/release.sh` usage (5 modes).
  - GitHub Actions pipeline (11 steps) explained in detail.
  - Post-release verification (Cosign, SBOM, SHA-256, PIE check).
  - Rollback procedures and emergency actions.
  - 12 sections, ~30 KB.

##### Release Scripts

- **`scripts/release.sh`** — local release automation script.
  - Validates SemVer format (`vMAJOR.MINOR.PATCH[-prerelease]`).
  - Computes `versionCode` from the SemVer formula.
  - Checks branch (`develop` or `release/*`), working tree, and tag
    availability.
  - Updates `VERSION`, `module.prop`, and `update.json` atomically.
  - Creates a `release: vX.Y.Z` commit + signed tag.
  - Pushes to `origin` (unless `--no-push`).
  - Modes: `--dry-run`, `--no-push`, `--yes`, `--help`.
  - Rollback on failure (trap + atomic writes).

- **`scripts/release-patch.sh`** — local PATCH-release automation script.
  - Wraps `scripts/release.sh` with **3 additional safety rules**:
    1. Branch **must** be `main` (not `develop`).
    2. `MAJOR` and `MINOR` components **must not** change.
    3. `PATCH` **must** be exactly `current + 1`.
  - Rejects MAJOR/MINOR bumps — those use `release.sh`.
  - Delegates the actual bump to `release.sh` (no logic duplication).
  - Reminds the maintainer to back-merge `main → develop`.
  - Modes: `--dry-run`, `--no-push`, `--yes`, `--help`.

##### Architecture Decision Records (ADRs)

- **`docs/adr/README.md`** — ADR index, template, and methodology.
  - Explains the ADR lifecycle (Proposed / Accepted / Deprecated /
    Superseded).
  - Provides a canonical ADR template for future decisions.
  - Documents the relationship between ADRs and `CHANGELOG.md`.
  - 10 sections, ~15 KB.

- **`docs/adr/0001-two-branch-model.md`** — Adopts `main` + `develop`.
- **`docs/adr/0002-automated-releases.md`** — Adopts `release.sh` +
  `release.yml`.
- **`docs/adr/0003-post-release-sync.md`** — Auto-syncs `main → develop`.
- **`docs/adr/0004-unified-pr-template.md`** — Single PR template
  (⚠️ Superseded by ADR-0005).
- **`docs/adr/0005-release-specific-pr-template.md`** — Release PR
  template (reverses ADR-0004).
- **`docs/adr/0006-rename-hotfix-to-release-patch.md`** — Renames the
  PATCH script.

##### Contributor Templates

- **`.github/PULL_REQUEST_TEMPLATE/release.md`** — dedicated PR template
  for releases (`release/*` → `main` and `hotfix/*` → `main`).
  - Concise (< 100 lines of content).
  - Version-first layout (`version` + `versionCode` at the top).
  - Post-merge checklist (tag push, `release.yml` trigger, back-merge).
  - Rollback plan section.
  - Reviewer checklist tailored to releases.
  - Opened via `?template=release.md` (see `docs/BRANCHING.md` §4.4).

### Changed

#### Backend (Go)

- **`main.go`** — Version string `v1.0.0` → `v1.1.0` (in `USER_AGENT`).
- **`main.go`** — `main()` no longer calls `debug.SetMemoryLimit(80MB)`
  directly. Instead:
  ```go
  initialProfile := readSelectedProfile()
  applyMemoryLimit(initialProfile)
  ```
- **`main.go`** — `updateProfile()` calls `applyMemoryLimit(key)` after
  `atomicWriteFile(SELECTED_FILE)` succeeds.
- **`main.go`** — `shellQuote()` now escapes `{`, `}`, `\n`, `\t` in
  addition to the original 20 characters.
- **`main.go`** — `metricsProxyHandler` builds the upstream URL from
  `MONITORING_UI_PORT` instead of the literal `"8080"`.
- **`main.go`** — `buildRuntimeInfo()` exposes `profile_key` +
  `memory_limit_mb`.
- **`main.go`** — `buildProfileResponse()` exposes `memory_limit_mb`.

#### Shell Scripts

- **`customize.sh`** — Port collision resolution: the check order
  changed from `equality → 8080` to `8080 → equality`. Fixes the
  case where both ports were `9091` (previously no-op).
- **`customize.sh`** — now computes and prints the expected memory
  limit for the active profile.
- **`functions.sh`** — added `SELECTED_PROFILE_FILE` global and
  `get_profile_memory_hint()` function.
- **`action.sh`** — `--check` output restructured with new sections.
- **`service.sh`** — logs profile + memory hint at startup.
- **`status.sh`** — `--check`, `--json`, and default output extended
  with profile + memory info.
- **`watchdog.sh`** — logs profile + memory hint at startup.

#### Frontend (PWA)

- **`web/sw.js`** — `CACHE_VERSION` bumped from `v1.0.0` to `v1.1.0`.
  Removed the misleading comment about `sync_versions.sh` (no such
  script exists).
- **`web/index.html`** — `var VERSION = 'v1.1.0'`. Title updated.
- **`web/dashboard.html`** — `var VERSION = 'v1.1.0'`. Title updated.
- **`web/offline.html`** — Version badge updated to `v1.1.0`. Critical
  CSP fix (see Fixed section below).
- **`web/manifest.json`** — `version` field bumped to `1.1.0`.
  `description` extended with v1.1.0 features.

#### Build & Configuration

- **`VERSION`** — `v1.0.0` → `v1.1.0`.
- **`module.prop`** — `version=v1.1.0`, `versionCode=1010000`.
  Description extended with v1.1.0 features.
- **`update.json`** — `version=v1.1.0`, `versionCode=1010000`,
  `zipUrl` updated to reference the `v1.1.0` tag.
- **`proxy/go.mod`** — documentation comments updated to reflect the
  v1.1.0 memory-limit behavior (still dependency-free).
- **`proxy/dnscrypt-proxy.toml`** — documentation section [14]
  extended with the per-profile soft limit table.
- **`proxy/webui.conf`** — documentation extended with the v1.1.0
  memory information.
- **`proxy/build.sh`** — documentation comments updated (no behavior
  change).
- **`.editorconfig`** — removed `indent_size = 4` from `[*.go]` because
  Go always uses tabs (the setting was ignored by most editors).
- **`.gitignore`** — removed the no-op negation `!proxy/dnscrypt-proxy.version`
  (it did not match any preceding pattern).
- **`.github/workflows/ci.yml`** — added `develop` to `push.branches`
  and `pull_request.branches`.
- **`.github/workflows/codeql.yml`** — added `develop` to `push.branches`
  and `pull_request.branches`.
- **`.github/workflows/release.yml`** — added "Sync main → develop"
  step. Uses `continue-on-error: true`.
- **`.github/PULL_REQUEST_TEMPLATE.md`** — added `🎯 Target Branch`
  section (develop vs main).
- **`.github/CODEOWNERS`** — added `/docs/adr/`,
  `/scripts/release-patch.sh`, `/.github/PULL_REQUEST_TEMPLATE/`,
  repo hygiene files.
- **`Makefile`** — added `release`, `release-patch`, `sync` targets.
  Renamed `hotfix:` → `release-patch:` (see ADR-0006).
- **`README.md`** — Version badge `v1.0.0` → `v1.1.0`. Added RAM-by-profile
  table. Added "v1.1.0 additions" to Security. Extended Performance
  section. Added CI badge + Dev Workflow references.
- **`docs/CONTRIBUTING.md`** — added "Branching & Release" callout.
  Section 4 delegates to `docs/BRANCHING.md`. Section 10 delegates to
  `docs/RELEASE_PROCESS.md`. Added Golden Rule #18.
- **`docs/DEVELOPMENT.md`** — added "Branching & Release" callout.
  Section 2 adds `git checkout develop`. Section 5 all steps branch
  from `develop`. Section 6 summarizes and delegates.
- **`docs/ROADMAP.md`** — Section 2.6 statistics updated. Section 2.7
  features added. Section 2.8 lessons added. Section 10 workflow
  priorities updated.

### Fixed

#### Critical

- **`web/offline.html`** — Removed the restrictive CSP meta tag
  (`default-src 'none'`) that silently blocked the page's own inline
  `<script>`. The page rendered correctly but **every interactive
  feature** (Retry, Diagnose, language toggle, auto-retry) silently
  failed. The CSP was redundant: the page has no user data, no forms,
  no network calls after load, and uses only `textContent`. If a
  future version adds dynamic content from untrusted sources, CSP
  must be reintroduced — preferably with a nonce rather than
  `'unsafe-inline'`.

#### Important

- **`proxy/customize.sh`** — Port collision fix. When both `PORT` and
  `DASHBOARD_PORT` were `9091`, the previous logic detected the
  collision but reset dashboard to `9091` (no actual change). New
  logic: if `PORT=9091` → dashboard becomes `9092`; otherwise →
  dashboard becomes `9091`.
- **`web/sw.js`** — Removed the misleading comment claiming
  `CACHE_VERSION` was "updated automatically by sync_versions.sh".
  No such script exists. The value is updated manually at each
  release. See "How to update CACHE_VERSION" in the file header.

#### Minor

- **`.gitignore`** — Removed the no-op negation
  `!proxy/dnscrypt-proxy.version` (did not match any preceding pattern).
- **`.editorconfig`** — Removed `indent_size = 4` from `[*.go]`
  (ignored by editors when `indent_style = tab`).

### Removed

- **`web/manifest.json`** — No items removed. The `screenshots` array
  was already removed in v1.0.0.
- **No features were removed.** All v1.0.0 APIs and endpoints remain
  functional.

### Deprecated

- Nothing in this release.

### Security

- **No new audit corrections.** The Audit Corrections Registry remains
  at **#33** (last entry from v1.0.0).
- **MEM-1, MEM-2, MEM-3** are documented in `docs/SECURITY.md` §5.30
  and §17.1 as **runtime improvements**, not as audit corrections.
  They close edge cases rather than fix known exploitable
  vulnerabilities.
- **All v1.0.0 security fixes remain in place** — Login POST-only,
  `/readyz` localhost-only, `shellQuote`, `readConfPort` range check,
  Basic Auth rate limiting, `rebuildMu` mutex, auth cache, Custom
  Chains, STATUS_FILE semantics, `hasEndpoint` exact matching,
  `runtime_info` dynamic ports.

### Breaking Changes

**None.** `v1.1.0` is fully backward compatible with `v1.0.0`:

- All API endpoints work with the same paths, methods, and auth.
- All config files (`webui.conf`, `dnscrypt-proxy.toml`) keep the same
  format.
- All shell script CLI flags work the same way.
- All previously-issued v1.0.0 tokens and cookies remain valid (session
  GC schedule unchanged).
- The two new `runtime_info` fields (`profile_key`, `memory_limit_mb`)
  are strictly additive. Clients that ignore unknown fields are
  unaffected.

### Notes

#### Audit Corrections Registry — Unchanged

`v1.1.0` does **not** extend the Audit Corrections Registry. The last
entry is #33 (from v1.0.0). New audit corrections will resume at
**#34** in v1.2.x. See `docs/SECURITY.md` §17.

#### Memory Limit — Semantics

`debug.SetMemoryLimit` is a **soft** limit. The Go runtime does **not**
kill the process when the limit is reached — it runs GC more
aggressively instead. Setting the limit too low causes CPU waste
(GC overhead); too high wastes RAM. The per-profile values balance
this trade-off.

#### Version Files — Where to Update

At each release, the version string appears in:

| File | Field | v1.1.0 value |
|---|---|---|
| `VERSION` | entire file | `v1.1.0` |
| `module.prop` | `version=` | `v1.1.0` |
| `module.prop` | `versionCode=` | `1010000` |
| `update.json` | `.version` | `v1.1.0` |
| `update.json` | `.versionCode` | `1010000` |
| `web/manifest.json` | `.version` | `1.1.0` (no `v`) |
| `web/sw.js` | `CACHE_VERSION` | `v1.1.0` |
| `web/index.html` | `var VERSION` | `v1.1.0` |
| `web/dashboard.html` | `var VERSION` | `v1.1.0` |
| `proxy/main.go` | `USER_AGENT` | `v1.1.0` |

`scripts/release.sh` updates the first five automatically. The rest
must be updated manually if they reference the version (or via
`generate-icons.sh --force` for icons, but icons don't embed the
version).

#### Reversed Decisions (from v1.0.0 cycle)

The following decisions were made and then **explicitly reversed**
during the `v1.0.0 → v1.1.0` cycle. Each reversal is documented via
an ADR:

| Original Decision | Reversal | Documentation |
|---|---|---|
| ADR-0004: Unified PR template only | ADR-0005: Add release-specific template | [ADR-0004](docs/adr/0004-unified-pr-template.md) → [ADR-0005](docs/adr/0005-release-specific-pr-template.md) |
| Initial draft: `scripts/hotfix.sh` | ADR-0006: Rename to `release-patch.sh` | [ADR-0006](docs/adr/0006-rename-hotfix-to-release-patch.md) |

**Why reversals are documented:** The ADR system is designed to
preserve history. Reversals are not hidden — they are traceable,
reasoned, and linked. See `docs/adr/README.md` §4 (ADR Lifecycle)
for the full methodology.

#### Not Included

The following items were considered and intentionally **not** added
in `v1.1.0`:

- **CSP hardening** — removing `'unsafe-inline'` from `script-src` is
  planned for `v1.2.0` (requires converting all `onclick=` to
  `addEventListener`). **Note**: Deferred further to v1.3.0.
- **PWA port unification** — serving Dashboard from `9090/dashboard`
  instead of `9091` is planned for `v1.2.0`. **Note**: Deferred
  further to v1.3.0.
- **Dedicated maskable icon** — `icon-maskable.svg` + `.png` planned
  for `v1.2.0`. **Note**: Deferred further to v1.3.0.
- **`.github/workflows/sync-main-to-develop.yml`** — the sync logic
  is embedded directly in `release.yml` to keep the workflow count
  minimal. See [ADR-0003](docs/adr/0003-post-release-sync.md).
- **`.github/workflows/pr-check.yml`** — `ci.yml` already covers PR
  builds for both `main` and `develop`.
- **Signed commits (GPG / Sigstore)** — planned for a future
  workflow version.
- **Automated changelog from Conventional Commits** — planned for a
  future workflow version.

---

## [v1.0.0] - 2026-09-24

> **First Stable Release** — Initial public release of DNSCrypt Smart
> Filter.
>
> This is the first production-ready release of the project. It
> consolidates the entire development effort into a single stable
> version, including **33 Audit Corrections**, **20 fixes**, and
> complete Level 4 infrastructure for DNS binaries management.

### 📊 Overview

| Metric | Value |
|--------|:-----:|
| Total Audit Corrections | **33** |
| Total fixes | **20** |
| Supported architectures | **4** (arm64, arm, amd64, 386) |
| Documentation files | **14** (in `docs/`) |
| Shell scripts | **8** (in `proxy/`) |
| Build scripts | **3** (in `scripts/`) |
| Web/PWA files | **13** (in `web/`) |

### ✨ Highlights

#### Security

- Login POST-only (CSRF protection)
- `/readyz` localhost-only
- `shellQuote()` Shell injection protection
- `readConfPort` range check (1–65535)
- Basic Auth rate limiting (5 attempts / 15 min)
- `rebuildMu` mutex — serializes blocklist rebuilds (RACE-1)
- Auth cache (60 s) — reduces file I/O
- Custom iptables/ip6tables chains (no orphan rules)
- STATUS_FILE = User Intent semantics
- Exact endpoint matching (`hasEndpoint`)
- 33 Audit Corrections applied

#### Features

- Multi-level blocklists (Light → Ultimate)
- Custom Rules (Allowlist + Denylist) with smart editor
- Draft auto-save with rollback (localStorage)
- Content-hash conflict detection (409)
- SSE live updates (status, stats, resources, progress)
- Installable PWA with offline support
- Separate monitoring Dashboard with JSON metrics
- Bilingual WebUI (English / Arabic) with full RTL
- Dynamic port links (PORT-2)
- Preserve settings on upgrade (backup/restore)

#### Infrastructure

- Reproducible builds (`SOURCE_DATE_EPOCH`)
- Cross-compilation for 4 architectures
- GitHub Actions: CI, Release, CodeQL
- Pre-commit hooks
- Multi-architecture support

#### Documentation

- 14 documentation files in `docs/`
- Bilingual README (EN + AR)
- Full threat model in `docs/SECURITY.md`
- Comprehensive FAQ
- Comprehensive troubleshooting guide
- Audit Corrections Registry (#1 → #33)
- Installation, upgrade, and development guides

### Added

#### Backend (Go)

- **HTTP API** — full REST API for WebUI and Dashboard.
- **`/healthz`** — public liveness endpoint.
- **`/readyz`** — localhost-only readiness endpoint.
- **`/api/metrics`** — JSON metrics proxy (Prometheus → JSON).
- **`/events`** — SSE stream for live updates.
- **`runtime_info`** endpoint — build info + actual ports (PORT-2).
- **`hasEndpoint()`** — exact path matching (no loose
  `strings.Contains`).
- **`getSystemShell()`** — platform-agnostic shell detection
  (`sync.Once`).
- **`shellQuote()`** — shell injection protection for dynamic paths.
- **`readConfPort()`** — port range check `[1, 65535]`.
- **`rebuildMu`** — `sync.Mutex` serializing `rebuildBlocklist`
  (RACE-1).
- **Auth cache (60 s)** — reduces file I/O on every request.
- **Per-port cache** — `portCacheMap` supports multiple ports
  independently.
- **Session GC** — periodic cleanup (every 30 min).
- **SSE Write Deadline (30 s)** — DoS protection against slow clients.

#### Frontend (PWA)

- **Bilingual WebUI** (English + Arabic) with full RTL support.
- **Monitoring Dashboard** with JSON metrics.
- **Service Worker** (`sw.js`) with cache versioning.
- **Offline fallback page** (`offline.html`).
- **PWA manifest** with shortcuts, icons, and meta notes.
- **SVG + PNG + ICO icons** for all browsers and platforms.
- **Edit mode FSM** — VIEW / EDIT / ROLLBACK states for rules editor.
- **Draft auto-save** — localStorage-backed, 1-hour retention.
- **Content-hash conflict detection** — 409 responses handled
  gracefully.
- **Dynamic port links** — reads `runtime_info`, uses
  `window.location.hostname`.

#### Shell Scripts

- **`customize.sh`** — installer with backup/restore of 5 user config
  files.
- **`service.sh`** — boot service with standalone Watchdog launcher.
- **`post-fs-data.sh`** — early boot cleanup with Custom Chain cleanup.
- **`watchdog.sh`** — standalone process with exponential backoff.
- **`action.sh`** — Magisk Action handler (browser opener with
  fallbacks).
- **`status.sh`** — status display with 4 modes (default, `--short`,
  `--json`, `--check`).
- **`uninstall.sh`** — cleanup with backup preservation.
- **`functions.sh`** — shared library with Custom Chains + Port Guard.
- **`build.sh`** — cross-compilation for 4 architectures with
  reproducible builds.

#### Build & Packaging

- **`scripts/fetch_dns_binaries.sh`** — Level 4 DNS binaries fetcher:
  - GitHub API + 4 fallback URL formats + jsDelivr CDN.
  - SHA256 verification.
  - Local cache + `.manifest.json`.
  - Offline mode (`--offline`).
  - JSON output (`--json`).
  - Retry logic (3 attempts).
- **`scripts/package_module.sh`** — builds the Magisk ZIP:
  - 32-file verification.
  - Web asset verification (PNG + ICO + SVG + offline.html).
  - i386 ↔ x86 mapping for `customize.sh`.
  - Reproducible timestamps.
- **`scripts/generate-icons.sh`** — generates PNG + ICO from SVG.

#### CI/CD

- **`.github/workflows/ci.yml`** — build matrix for 4 architectures.
- **`.github/workflows/release.yml`** — signed release with 6
  artifacts.
- **`.github/workflows/codeql.yml`** — SAST with `security-extended`
  queries.
- **`.github/dependabot.yml`** — weekly updates for Actions, monthly
  for Go.
- **`.pre-commit-config.yaml`** — 15 hook configurations.

#### Documentation

- 14 comprehensive documentation files in `docs/`.
- Root `README.md` with full project overview.
- Root `SECURITY.md` — summary policy.
- Root `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1.
- Root `LICENSE` — MIT License.
- Root `CHANGELOG.md` — this file.

### Security

**Authentication and authorization**

- **Login POST-only** (`/api/auth/login`) — Fix NEW-1 (Audit #28).
- **Logout POST-only** (`/api/auth/logout`) — Fix NEW-1 (Audit #28).
- **Basic Auth rate limiting** — 5 attempts / 15 min — Fix #8
  (Audit #22).
- **Constant-time comparison** — `subtle.ConstantTimeCompare` on all
  credentials.
- **Cookie-only sessions** — no token in JSON responses — Audit #15-a.
- **SameSite=Lax + HttpOnly + Secure (conditional)** — cookie flags.
- **Session GC** — periodic cleanup of expired sessions.
- **Auth cache (60 s)** — Fix NEW-6 — reduces file I/O on every
  request.

**Input validation and sanitization**

- **`hasEndpoint()`** — exact path matching — Fix #12 + NEW-2
  (Audit #24).
- **`readConfPort()`** — range check `[1, 65535]` — Fix NEW-3
  (Audit #29).
- **`shellQuote()`** — shell injection protection — Fix NEW-5
  (Audit #31).
- **`MaxBytesReader`** — 5 MB limit on all POST bodies.
- **`limitedBuffer`** — bounded stderr capture (2048 bytes).
- **Path whitelist** — `isAllowedLogFile` + `filepath.Clean`.
- **Atomic writes** — `atomicWriteFile` + `atomicWriteStream` with
  `fsync`.

**Network and firewall**

- **Custom Chains** — `DNSCRYPT_OUT` / `DNSCRYPT_OUT6` — Fix
  (Audit #17).
- **Port Guard 8080** — reserved for `monitoring_ui` — Fix
  (Audit #20).
- **IPv4/IPv6 separation** — no cross-protocol contamination —
  Audit #16.
- **`/readyz` localhost-only** — Fix NEW-4 (Audit #30).
- **BIND_ADDR enforcement** — refuses to start if exposed without
  credentials.
- **IPv6-safe `getClientIP()`** — `net.SplitHostPort` instead of
  `strings.Split` — Audit #19.

**State and concurrency**

- **STATUS_FILE = User Intent** — Audit #18.
- **`rebuildMu` mutex** — serializes `rebuildBlocklist` — RACE-1
  (Audit #32).
- **Section-restricted TOML parsing** — Audit #21.
- **Section header with comment** — Audit #23.
- **Preserve settings on upgrade** — backup/restore of 5 files —
  Audit #26.

**HTTP security headers**

- **CSP** (Content-Security-Policy) with strict directives.
- **X-Content-Type-Options: nosniff**.
- **X-Frame-Options: DENY**.
- **Referrer-Policy: no-referrer**.
- **Permissions-Policy** — disables geolocation, microphone, camera,
  payment.
- **Cross-Origin-Opener-Policy: same-origin**.
- **Cross-Origin-Resource-Policy: same-origin**.

**Rate limiting**

- **Login** — 5 attempts / 15 min per IP.
- **Basic Auth** — 5 attempts / 15 min per IP.
- **IPv6-safe** — `[::1]` handled correctly.
- **Automatic reset** — successful login resets the counter.

**Stability**

- **SSE Write Deadline (30 s)** — prevents slow-client DoS.
- **Panic recovery** — `handleAPI` recovers from panics.
- **`os.Exit(1)` on startup failures** — no silent failures.

### Architecture

- **Custom iptables chains** (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`) — no
  orphans.
- **nftables support** — via `dnscrypt_filter` table.
- **Legacy cleanup** — `_legacy_cleanup_*` for migration from older
  shells.
- **Watchdog as standalone process** — correct PID (`$$` in own file).
- **Streaming blocklist rebuild** — ~2 MB peak memory instead of
  ~150 MB.
- **Auth cache** — 60 s TTL, `sync.RWMutex` protected.
- **Per-port cache** — `portCacheMap` with independent entries.
- **Platform-agnostic shell** — `getSystemShell()` works on
  Android/Linux/macOS.
- **Structured metrics** — Prometheus → JSON via `parsePrometheus` +
  `buildDashboardJSON`.
- **Dynamic ports** — `runtime_info` returns `webui_port` +
  `dashboard_port`.

### Fixed

| # | Fix | File(s) |
|:-:|-----|---------|
| 1 | Dashboard JSON conversion (Prometheus → JSON) | `proxy/main.go` |
| 2 | Shell fallback for Linux/macOS (`getSystemShell`) | `proxy/main.go` |
| 3 | Preserve user settings on upgrade | `proxy/customize.sh` |
| 4 | `.gitignore` negation for `proxy/run/*` | `.gitignore` |
| 5 | Pre-commit hooks (`golangci-lint` v2) | `.pre-commit-config.yaml` |
| 6 | Asset serving (13 web files) | `proxy/main.go` + `scripts/package_module.sh` |
| 7 | CodeQL config drift | `.github/workflows/codeql.yml` |
| 8 | Basic Auth rate limit bypass | `proxy/main.go` |
| 9 | `fuser` PID parsing (merged PIDs) | `proxy/functions.sh` |
| 10 | Section header with comment | 4 files |
| 11 | Per-port cache (not time-keyed) | `proxy/main.go` |
| 12 | Exact endpoint matching | `proxy/main.go` |
| **NEW-1** | **Login POST-only (CSRF)** | `proxy/main.go` |
| **NEW-2** | **`hasEndpoint` usage** | `proxy/main.go` |
| **NEW-3** | **`readConfPort` range check** | `proxy/main.go` |
| **NEW-4** | **`/readyz` localhost-only** | `proxy/main.go` |
| **NEW-5** | **`shellQuote` injection protection** | `proxy/main.go` |
| **NEW-6** | **Auth cache (60 s)** | `proxy/main.go` |
| **RACE-1** | **`rebuildMu` mutex** | `proxy/main.go` |
| **PORT-2** | **`runtime_info` dynamic ports** | `proxy/main.go` + 3 HTML files |

**Total**: 20 fixes.

### Performance

| Metric | Value |
|--------|:-----:|
| RAM (idle WebUI) | ~15 MB |
| RAM (peak during rebuild) | ~25 MB |
| Battery drain | ~1–2% / day |
| DNS latency (cached) | ~1–5 ms |
| Service startup | ~2–5 s |
| `rebuildBlocklist` (100K) | ~200 ms |
| `rebuildBlocklist` (500K) | ~1 s |
| `parsePrometheus` (10 metrics) | ~50 µs |
| `hasEndpoint` (exact match) | <100 ns |
| `getSystemShell` (cached) | <10 ns |
| `getMonitoringAuth` (cached) | ~50 ns |

### Known Issues

| Issue | Priority | Target |
|-------|:--------:|:------:|
| CSP `'unsafe-inline'` in `script-src` | 🟡 Medium | v1.3.0 |
| `pgrep -x` may not work on Android 5.x | 🟢 Low | v1.3.0 |
| `awk` parser may fail with `]` in comment | 🟢 Low | v1.3.0 |
| PWA dual-origin limitation (9090 vs 9091) | 🟡 Medium | v1.3.0 |
| `manifest.json` shortcuts do not read `runtime_info` | 🟢 Low | v1.3.0 |
| Dashboard does not show `bind_addr` (only in `runtime_info`) | 🟢 Low | v1.3.0 |

### Notes

#### First Release

This is the **first public release** of DNSCrypt Smart Filter. There
are no previous versions. All features, security fixes, and
infrastructure were developed and consolidated into this single
stable `v1.0.0` release.

#### Audit Corrections

All 33 Audit Corrections are documented in
[`docs/SECURITY.md`](docs/SECURITY.md) with full details:
- Problem description
- Catastrophic scenario
- Impact analysis
- Solution applied
- Reference to the corresponding section

See §17 — Audit Corrections Registry for the complete list.

#### Repository Layout

```text
dnscrypt-proxy-webui/
├── VERSION                        # v1.0.0
├── module.prop                    # Magisk definition
├── update.json                    # Auto-update metadata
├── README.md / SECURITY.md / CHANGELOG.md
├── CODE_OF_CONDUCT.md / LICENSE / Makefile
│
├── .github/                       # CI/CD + templates
├── .devcontainer/                 # Dev environment
├── scripts/                       # Build & release tools
├── proxy/                         # Go backend + shell scripts
├── web/                           # Frontend (PWA)
└── docs/                          # 14 documentation files
```

#### Verification

To verify the release on a device:

```bash
# Version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.0.0

su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: versionCode=1000000

# Dashboard JSON (Fix #1)
curl -s -I http://127.0.0.1:9091/api/metrics | grep Content-Type
# Expected: application/json; charset=utf-8

# Login POST-only (NEW-1)
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: 405 Method Not Allowed

# Runtime info ports (PORT-2)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# No orphans in iptables
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# Expected: 0
```

### Credits

- **gasciljh** — Full development, testing, and auditing.
- **Anthropic Claude** — Code review and architectural audit
  assistance.
- **DNSCrypt Community** — For `dnscrypt-proxy`.
- **HaGeZi** — For the DNS blocklists.
- **Magisk / KernelSU / APatch teams** — For the module framework.

### References

- [README.md](README.md) — Project overview
- [SECURITY.md](SECURITY.md) — Security policy (summary)
- [docs/SECURITY.md](docs/SECURITY.md) — Full policy + Audit
  Corrections Registry
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Architecture +
  Trade-offs
- [docs/API.md](docs/API.md) — HTTP API Reference
- [docs/INSTALL.md](docs/INSTALL.md) — Installation guide
- [docs/UPGRADE.md](docs/UPGRADE.md) — Upgrade guide
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) — Compatibility
  matrix
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — Troubleshooting
  guide
- [docs/FAQ.md](docs/FAQ.md) — Frequently asked questions
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — Developer guide
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — Contribution guide
- [docs/DNS_BINARIES.md](docs/DNS_BINARIES.md) — DNS binaries
  management
- [docs/GLOSSARY.md](docs/GLOSSARY.md) — Glossary
- [docs/HALL_OF_FAME.md](docs/HALL_OF_FAME.md) — Contributors
  recognition
- [docs/ROADMAP.md](docs/ROADMAP.md) — Future plans

---

## 📖 Legend — Audit Corrections

The complete list of 33 Audit Corrections applied in v1.0.0:

| # | Description | Reference |
|:-:|---|---|
| #1 | Fixed typo in `isAllowedLogFile` | — |
| #3-e/f | Dynamic `bootstrap_resolvers` + IPv6 | docs/SECURITY.md#59 |
| #5 | Cleanup of old `loginAttempts` | — |
| #6-c | `limitedBuffer` (bounded stderr capture) | — |
| #7 | Dead code removal from `functions.sh` | — |
| #9/#9-b | `os.CreateTemp` (no race) | — |
| #10 | Debounce SSE | — |
| #13 | CSRF-GET → POST-only | docs/SECURITY.md#52 |
| #14 | `pgrep -x` (no false positives) | — |
| #15-a | Remove token from login response | docs/SECURITY.md#511 |
| #15-b | `Allow: POST` header for 405 | docs/SECURITY.md#512 |
| #16-a/b | IPv4/IPv6 firewall separation | docs/SECURITY.md#59 |
| #17 | Custom Chains (Orphan Fix) | docs/SECURITY.md#513 |
| #18 | STATUS_FILE Semantics | docs/SECURITY.md#514 |
| #19 | IPv6 Rate Limit Bypass | docs/SECURITY.md#515 |
| #20 | Port Collision 8080 | docs/SECURITY.md#516 |
| #21 | Section-Restricted TOML | docs/SECURITY.md#517 |
| #22 | Basic Auth Rate Limit Bypass | docs/SECURITY.md#518 |
| #23 | Section header with comment (parsing) | docs/SECURITY.md#519 |
| #24 | Exact endpoint matching | docs/SECURITY.md#520 |
| #25 | Dashboard JSON Conversion | docs/SECURITY.md#520 |
| #26 | Preserve User Settings on Upgrade | docs/SECURITY.md#521 |
| #27 | `fuser` PID parsing | docs/SECURITY.md#522 |
| #28 | Login POST-only (CSRF) | docs/SECURITY.md#523 |
| #29 | `readConfPort` range check | docs/SECURITY.md#524 |
| #30 | `/readyz` localhost-only | docs/SECURITY.md#525 |
| #31 | `shellQuote` injection protection | docs/SECURITY.md#526 |
| #32 | `rebuildMu` mutex (RACE-1) | docs/SECURITY.md#528 |
| #33 | `runtime_info` dynamic ports (PORT-2) | docs/SECURITY.md#529 |

**Total**: 33 Audit Corrections.

**Last**: #33 (v1.0.0).
**Next expected**: #34 (v1.3.x).

### v1.1.0 Runtime Improvements (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| MEM-1 | Dynamic memory limit per profile | Closes a self-inflicted DoS surface (GC thrashing on `ultimate`) |
| MEM-2 | Extended `shellQuote` charset (`{`, `}`, `\n`, `\t`) | Defense in depth; no known exploit existed |
| MEM-3 | `MONITORING_UI_PORT` in metrics handler | Single source of truth; removes last hardcoded reserved port |

These are documented in `docs/SECURITY.md` §5.30 and §17.1 for
completeness but are not assigned audit correction numbers because
they do not fix a known exploitable vulnerability.

### v1.2.0 Runtime Additions & Correctness Fixes (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| **BAK-1** | 7-field `runtime_info.backups` | Observability of the backup layer; enables early detection of a degraded state |
| **BAK-2** | `createAutoBackup` + `backupMu` + rotation | Pre-critical backup before 5 destructive endpoints |
| **BAK-3** | `cleanupOldTransactions` | Removes leftover `COMMIT`'d `txn-*` dirs at startup |
| **BAK-4** | `checkPendingNotifications` | Reads `.pending_notification` at startup |
| **FIX-1** | Recovery-mode **snapshot-and-reapply** | Correctness fix — `§[8a]` restores + snapshots the 5 files to `$MODPATH/.recovery_snapshot/`; `§[9]` extracts the ZIP normally (extraction logic untouched); `§[9b2]` re-applies the 5 files from the snapshot. The snapshot directory is cleaned up in `§[9b2]` unless the re-apply is partial. |
| **FIX-2** | Service Worker update-banner | Correctness fix (send `SKIP_WAITING` to correct worker) |
| **WD-TOKEN** | Watchdog token | Closes a CSRF hole on `ensure_running_service` |

These are documented in `docs/SECURITY.md` §5.31, §5.32, and §5.33
for completeness but are not assigned audit correction numbers
because they do not fix a known exploitable vulnerability in an
earlier v1.2.0 draft (except WD-TOKEN, which closes a real — though
low-severity — CSRF surface that existed since v1.0.0).

---

## 🔗 Links

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)

---

[Unreleased]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.2.0...HEAD
[v1.2.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.1.0...v1.2.0
[v1.1.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.0.0...v1.1.0
[v1.0.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/releases/tag/v1.0.0