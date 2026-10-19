# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Author**: gasciljh
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Last updated**: 2026-10-19

---

## [Unreleased]

_No pending changes._

---

## [v1.5.0] - 2026-10-19

**Feature release** — companion app one-tap root install, twelve
frontend state fixes, nine server-side code-review corrections,
four post-build bug fixes, and **thirteen post-audit fixes**
from the pre-release code review.

**Audit Corrections Registry** remains at **#33** (last entry from
v1.0.0). v1.5.0 is a **feature release**, not an audit-correction
release.

**Interim v1.4.1 note**: `v1.4.1` was an interim, unreleased,
`go.mod`-only revision. It pinned
`github.com/cyphar/filepath-securejoin v0.7.0` (ADR-0002) to close
two CodeQL `go/path-injection` alerts in `removeModule`. It was
never tagged, has no CHANGELOG entry of its own, and is fully
superseded by v1.5.0.

### Highlights

- **Companion app one-tap root install** — the WebUI install
  button opens an **install-method modal** (three actions across
  two categories: local root install + two GitHub fallbacks). The
  local path runs `install_app.sh` — a **5-level `pm install`
  cascade** bounded by a 75-second deadline.
- **Layered Bootstrap (Phase 0)** — shell library split into
  Layer 0 (`proxy/boot-mini.sh`) and Layer 1 (`proxy/functions.sh`).
- **Manifest Notes extraction** — 6 `x-note-*` fields removed from
  `web/manifest.json`; content moved to `docs/REFERENCE.md` §7.
  Manifest shrinks from ~6 KB to ~3 KB.
- **4 new backend endpoints** — `install_companion_app`,
  `uninstall_companion_app`, `install_token`, `companion_app_state`.
- **Frontend state fixes** — companion button survives language
  toggles; status card updates instantly; Dashboard section-nav
  fixed; install rate-limit message rendered distinctly.
- **Server-side corrections** — logger three-layer split, port
  cache, dead-branch removal, hash source alignment.
- **Post-build fixes** — `installModalActive` stuck-flag,
  `companionInstallInFlight` stuck-flag after modal replacement,
  401 token-expiry message correction, `install_token`
  incorrectly matched as install-family.
- **Post-audit fixes** — 13 fixes from the pre-release code
  review covering build, backend, shell, security, and
  documentation (see §"Fixed — Post-audit" below).

### Added

**Backend (Go)** — 4 new endpoints in `proxy/main.go`:

- `POST /api/install_companion_app` — root install; auth +
  localhost + one-shot CSRF token; rate-limited per IP.
- `POST /api/uninstall_companion_app` — uninstall; implemented
  but not exposed in the v1.5.0 UI.
- `GET /api?action=install_token` — one-shot CSRF token (64 hex,
  60 s TTL, single use, localhost-only).
- `GET /api?action=companion_app_state` — cached install state
  (30 s TTL).

**Backend helpers** — 10 new functions in §[17d]:
`getInstallScript`, `generateInstallToken`,
`validateAndConsumeInstallToken`, `recordInstallAttempt`,
`isInstallLockedOut`, `callInstallScript`, `installCompanionApp`,
`uninstallCompanionApp`, `getCompanionState`,
`invalidateCompanionStateCache`.

**Backend constants** — `INSTALL_SCRIPT_REL`,
`INSTALL_TIMEOUT` (90 s), `INSTALL_TOKEN_TTL` (60 s),
`MAX_INSTALL_ATTEMPTS` (5), `INSTALL_LOCKOUT_PERIOD` (15 min),
`COMPANION_STATE_CACHE_TTL` (30 s).

**Backend concurrency** — `installTokens`, `installAttempts`,
`companionStateCache`, plus `portConfMu` for the 30 s TTL port
cache.

**Shell — `proxy/boot-mini.sh` (new)** — Layer 0 primitives:
`log_msg`, `get_run_dir`, `read_conf`, `is_port_open`,
`get_webui_port`, `_MONITORING_UI_PORT`. Zero dependencies.

**Shell — `proxy/install_app.sh` (new)** — the companion install
script. Modes: install / `--status` / `--uninstall` / `--help` /
`--version`. Features: 5-level cascade, per-strategy polling,
AR + EN error translation, SELinux staging
(`/data/local/tmp/dnscrypt-companion.apk`), Play Protect
temporary disable + trap restore, SHA256 verification, 75 s
cascade deadline, three-way signal-trap split (EXIT / INT / TERM
with exit 130 / 143).

**Frontend** — install-method modal (three actions across two
categories), `_resetModalLayout()`, `handleCompanionInstall()`,
`doCompanionInstall(token)`, `getCompanionApkUrl()`,
`renderCompanionButton()` (pure renderer),
`renderAllDynamic()` (single dynamic-render entry point),
`isInstallFamilyUrl()` (session-expired-modal suppressor).

**Frontend state fixes (12)** — companion button survives
language toggles (IDX-23); status card updates instantly
(IDX-23b); install-method modal re-renders correctly across
language toggles (IDX-24); Dashboard section-nav uses real card
IDs (IDX-25); card-expand hint is centered (IDX-25a); install
rate-limit message distinct (IDX-429); install-family 401
distinct (IDX-401-DISTINCT); Dashboard `isRefreshing` reset on
401 (DASH-REFRESH-01); Dashboard session-expired retry
(DASH-SESSION-RETRY-01); Dashboard dual-timer hint
(DASH-HINT-01); Dashboard `scrollend` scheduling (DASH-HINT-02);
512 icon safe-circle fit (ICON-512-SAFEZONE-01).

**Documentation — `docs/REFERENCE.md` §7 (new)** — consolidated
reference for the 6 extracted `x-note-*` fields plus the trimmed
`x-note-companion-apk` narrative.

**CI/CD** — `ci.yml` smoke-test steps verify `install_app.sh`
presence and Layered Bootstrap integrity. `release.yml` stages
the APK `.sha256` sidecar and enforces metadata consistency.
`upgrade-test.yml` 42-scenario matrix now stages `boot-mini.sh`
and exports `MODDIR` before sourcing.

### Changed

**Backend** — `HTTP_WRITE_TIMEOUT` raised from 60 s to 150 s (the
pre-patch 60 s was shorter than `INSTALL_TIMEOUT` = 90 s).
`callInstallScript()` uses `getSystemShell()`.

**Shell** — `customize.sh §[9]` extracts `install_app.sh` and
`boot-mini.sh`; `customize.sh §[10]` verifies both as critical
files; `customize.sh §[10c]` mirrors APK + `.sha256` to
`$PERSISTENT_BACKUP/apk/`. `functions.sh` sources `boot-mini.sh`
at load time.

**Frontend** — `sw.js` `CACHE_VERSION` bumped to `v1.5.0`;
`manifest.json` version `1.5.0`; 6 `x-note-*` fields removed, 1
trimmed, 1 (`x-note-docs`) added.

**Build & Metadata** — `VERSION` = `v1.5.0`; `module.prop`
`versionCode` = `1050000`; `update.json` version + `versionCode`
+ `zipUrl` + `releaseDate` updated.

**Documentation** — 35 markdown files reduced to 15 (13
user-facing + 2 GitHub PR templates) in a single consolidation
session. The 27 removed files — including `docs/MANIFEST_NOTES.md`
(added earlier in this release cycle) — were merged into 7 new
documents (`docs/GUIDE.md`, `docs/REFERENCE.md`,
`docs/CONTRIBUTING.md`, `docs/MAP.md`, and 3 consolidated ADRs
`0001-release-workflow`, `0002-external-dependency`,
`0003-layered-bootstrap`) plus the two GitHub PR templates
(`.github/PULL_REQUEST_TEMPLATE.md` and
`.github/PULL_REQUEST_TEMPLATE/release.md`). `docs/MANIFEST_NOTES.md`
content now lives in `docs/REFERENCE.md` §7. See `docs/MAP.md` for
the new structure, the reverse-lookup table, and the decision tree.

### Fixed

**Pre-release**

- **CSH-22** — `install_app.sh` was packaged but never extracted
  by `customize.sh §[9]`, so `getInstallScript()` resolved a
  non-existent path. Every install returned
  `reason=script_not_found`.
- **MAIN-REENT-01** — `logWithLevel` could deadlock on a failed
  log rotation (`sync.Mutex` is not reentrant in Go). Logger
  split into three layers: `logWithLevel` / `logLocked` /
  `writeLocked`.

**Frontend** — 12 state fixes (companion button, status card,
Dashboard section-nav, hint toast, rate-limit message, 401
distinctness, `isRefreshing`, session-expired retry, dual-timer
hint, `scrollend`, icon safe-circle). Plus:

- **BUG-1 (HIGH)** — `installModalActive` could get permanently
  stuck at `true` if the session expired while the install-method
  modal (IDX-24) was open. Once stuck, every subsequent confirm
  dialog's backdrop-click was silently swallowed until the page
  was reloaded. Fix: reset the flag in `closeConfirmModal()` and
  `showConfirmModal()`, enforcing the invariant
  `installModalActive === true ⇒ the install modal is the one
  currently visible`.
- **BUG-2 (MEDIUM)** — an expired one-shot CSRF token (HTTP 401
  from `/api/install_companion_app`) rendered `t('installError')`
  instead of the documented `t('installTokenError')`. Fix: added
  an explicit `401` branch in `doCompanionInstall()`.
- **BUG-3 (HIGH)** — `companionInstallInFlight` could stay `true`
  after a modal replacement (e.g. the session-expired modal
  opened over the install-method modal during an install attempt),
  leaving the install button permanently disabled. Fix: reset the
  flag in `showConfirmModal()` alongside `installModalActive`.
- **BUG-4 (MEDIUM)** — `isInstallFamilyUrl()` incorrectly matched
  `install_token`, suppressing the session-expired modal for a
  URL that actually needs it. Fix: `install_token` is excluded
  from the list — only the two token-consuming endpoints remain.
- **O2** (cosmetic) — `isInstallFamilyUrl()` documents that
  `uninstall_companion_app` is covered by the
  `install_companion_app` substring check; reordered to list the
  more-specific match first.
- **L-5** — `applyProfile()` now prefixes its confirm dialog with
  `t('unsavedWarning')` when `hasUnsavedChanges()` returns true.
- **Dashboard `scrollend` feature detection** corrected: the
  feature test must use `'onscrollend' in window`, not
  `'onscrollend' in document`.

**Backend** — `isLocalRequest` dead branch removed
(MAIN-DEADLOCALHOST-01); `appendDenylist` hash source aligned
with `saveDenylist` (MAIN-APPENDHASH-01); `getCompanionState`
three-phase read (V15-CODE-01); `callInstallScript` uses
`getSystemShell()` (V15-CODE-03); `installAttempts` added to
session GC; companion state cache invalidated unconditionally
after every install/uninstall. Plus:

- **M-1** — `isLocalRequest()` now uses `net.IP.IsLoopback()`
  instead of a string comparison against `"127.0.0.1"`/`"::1"`.
  Accepts any `127.0.0.0/8` address and IPv4-mapped IPv6 forms
  (`::ffff:127.0.0.1`).
- **`HTTP_WRITE_TIMEOUT` raised from 60 s to 150 s.**
- **`install_token` endpoint gated to localhost** — the local
  install-family gate now covers the GET token endpoint in
  addition to the two POST endpoints.

**Shell**

- **L-1** — `_VERIFIER_ORIG` comment corrected: `"0"` = was
  disabled, `"1"` = was enabled (the pre-patch comment had the
  two values swapped). The code was always correct; only the
  comment was wrong.
- **L-2** (verification) — `_wait_for_install()` was audited;
  the loop is already bounded by both `_timeout` (while
  condition) and `_deadline` (per-iteration wall-clock check).
  No code change was required.
- **L-3** — `boot-mini.sh` documents the sole legitimate
  `_MONITORING_UI_PORT` duplicate.
- **L-4** — `customize.sh §[7]` firewall comment clarified:
  "MUST match" → "MUST be functionally equivalent".

**CI/CD**

- `upgrade-test.yml` uses `run_scenario()` wrapper and stages
  `boot-mini.sh`.
- `ci.yml` Step 2 (Layer function presence) converted from
  silent no-op to hard assertion.
- `release-patch.sh` leading-zero fix.

**Post-audit — build (`proxy/build.sh`)**

- **BUILD-NDK-01 (CRITICAL)** — `-buildmode=pie` requires
  external (cgo) linking on linux. When NDK is missing,
  `CGO_ENABLED=0` combined with `-buildmode=pie` fails with
  `"requires external (cgo) linking, but cgo is not enabled"`.
  Fix: `EFFECTIVE_BUILDMODE` falls back to `default` when
  `CGO_MODE=0`. The resulting binary is non-PIE (documented in
  the header and warned about at every failure). Release builds
  always have NDK → PIE preserved.

**Post-audit — backend (`proxy/main.go`)**

- **MAIN-EXIT-01 (CRITICAL)** — `main()` returned silently with
  exit code 0 when `mainServer.ListenAndServe()` failed. The
  root manager interpreted "started OK" while the WebUI was
  unreachable. Fix: `os.Exit(1)` after the error log.
- **MAIN-INSTALL-SCRIPT-01 (CRITICAL)** — `getInstallScript()`
  returned a single path (`$MODDIR/install_app.sh`). Before
  `customize.sh §[9]` stages the file at the module root, the
  source-tree layout places it at `$PROXYDIR/install_app.sh` —
  the single-candidate version failed with
  `reason=script_not_found` in that state. Fix: two-candidate
  search identical to `getFunctionsScript()`.
- **MAIN-CONF-PANIC-01 (HIGH)** — `readConfValue()` and
  `readConfPort()` used `defer recover()` without a named return.
  On panic, the functions returned the zero value `""` instead
  of `defaultValue`, which would break `net.JoinHostPort` with
  an empty port. Fix: named return + pre-initialization of the
  result variable.
- **MAIN-AUTH-PARTIAL-01 (MEDIUM)** — `readMonitoringAuthFromFile()`
  used a bare `defer recover()`. If a panic occurred after
  `username` was populated but before `password`,
  `getMonitoringAuth` would cache the partial credentials
  (because it caches when at least one field is non-empty),
  leaving the WebUI with permanently broken credentials. Fix:
  the `defer` resets both fields on panic.
- **MAIN-SSE-DEADLOCK-01 (CRITICAL)** — `sseHandler()` added the
  channel to `sseClients` before sending the initial
  status/stats/resources events. A concurrent `broadcastEvent`
  could fill the 100-slot buffer between the map insertion and
  the first send — the send would then block forever (no reader
  had entered the loop yet), and the `defer` cleanup would
  never run. Fix: send the three initial events BEFORE the map
  insertion. Once registered, the loop is running and consumes
  the buffer.
- **MAIN-START-PORTCACHE-01 (HIGH)** — `startService()` called
  `getStatus()` which consults `isPortOpenCached(5354)` (5 s
  TTL). A stale "open" entry from a previous run or a zombie
  process would short-circuit the start, leaving the module
  stuck without a working DNS engine. Fix: clear
  `portCacheMap` before `getStatus()`.
- **MAIN-FW-TIMEOUT-01 (HIGH)** — `manage_firewall 1` iterates
  over up to 32 bootstrap IPs × 2 protocols × 2 strategies,
  each guarded by `iptables --wait 5`. Under contention with
  netd this can exceed the 15 s default `runShell` budget,
  leaving the firewall partially applied. Fix: 90 s explicit
  timeout in `startService()`, `stopService()`, and the
  shutdown handler.

**Post-audit — security (`proxy/main.go`)**

- **SEC-SYMLINK-01 (HIGH)** — `/data/local/tmp/` is
  world-writable. A local attacker could create a symlink
  named like a log file (e.g. `dnscrypt-evil.log` →
  `webui.conf`), and `readLogFile` / `clearLogFile` /
  `handleDownloadLog` / `listLogFiles` would follow it under
  root privileges — reading or truncating an arbitrary file.
  Fix: new `safeOpenRegular()` helper with three-layer defence
  (Lstat pre-check + `O_NOFOLLOW` + `os.SameFile` post-check).
  All four log operations route through it. `listLogFiles()`
  also skips `entry.Type()&os.ModeSymlink` and
  `!info.Mode().IsRegular()` at scan time.

**Post-audit — shell (`proxy/install_app.sh`)**

- **INSTALL-VERSION-01 (MEDIUM)** — `SCRIPT_VERSION="v1.5.0"`
  was hardcoded. After an upgrade to a future version,
  `install_app.sh --version` would report `v1.5.0` regardless
  of the actual module version. Fix: dynamic read from
  `module.prop` via `get_version()` — matches the pattern used
  by `action.sh`, `status.sh`, `customize.sh`, `service.sh`,
  `uninstall.sh`, and `watchdog.sh`.

**Post-audit — documentation**

- **DOC-SECURITY-DATE-01** — `SECURITY.md` `Last updated` was
  `2026-10-17`, one day behind the rest of the documentation.
  Fix: `2026-10-18`.
- **DOC-PR-TEMPLATE-01** — `.github/PULL_REQUEST_TEMPLATE.md`
  contained 16 broken `docs/*.md` references after the v1.5.0
  documentation consolidation. Fix: all references repaired to
  their new homes (`REFERENCE.md`, `CONTRIBUTING.md`,
  `GUIDE.md`, `SECURITY.md`, and the 3 consolidated ADRs).
  `HARD-PRT-*` identifiers removed (prohibited by `MAP.md`
  §2 Rule 5).
- **DOC-RELEASE-TEMPLATE-01** — `.github/PULL_REQUEST_TEMPLATE/release.md`
  contained 17 broken references. Fix: all repaired. `ADR-0005`
  and `ADR-0006` references redirected to
  `docs/adr/0001-release-workflow.md §4, §5`. `ADR-0007` →
  `ADR-0002`. `ADR-0008` → `ADR-0003`. `HARD-RPR-*` identifiers
  removed. "POST-AUDIT FIXES" block removed.

### Security

**No new audit corrections.** The Audit Corrections Registry
remains at **#33**. v1.5.0 additions are documented as feature
additions and code-review polish:

- One-shot CSRF token on `install_companion_app` — 60 s TTL,
  constant-time comparison via `subtle.ConstantTimeCompare`.
- Per-IP install rate limit — 5 failed attempts / 15 min,
  separate map from `loginAttempts`.
- SELinux staging — **`setenforce 0` is never called**.
- Play Protect temporary disable + trap restore with a 75 s
  cascade deadline.
- Three-way signal trap (EXIT / INT / TERM with `_CLEANED_UP`
  guard).
- `isLocalRequest()` uses `net.IP.IsLoopback()` — correct
  handling of IPv4-mapped IPv6 (`::ffff:127.0.0.1`), closing a
  loopback-detection gap for `ensure_running_service` and the
  install-family endpoints.
- **Post-audit**: symlink rejection in all log-file operations
  (SEC-SYMLINK-01) — see §Fixed.

The post-build bug fixes (BUG-1..BUG-4), the cosmetic O2, and
the thirteen post-audit fixes (BUILD-NDK-01 through
DOC-RELEASE-TEMPLATE-01) are quality, correctness, and
robustness fixes. They do not change the security posture in
any way that would warrant extending the Audit Corrections
Registry.

### Breaking Changes

**None.** All v1.4.0 clients work unchanged. All v1.5.0 changes
are additive.

### Notes

**Detailed line counts, file counts, and version file tables**
now live in dedicated sections:

- **Line counts per file** → the table in this section
- **File count model (fresh clone / package / full build)** →
  `docs/REFERENCE.md` §1.8.3
- **Version file update procedure** → `docs/CONTRIBUTING.md` §11.4
- **Full Audit Corrections Registry** → `SECURITY.md` §15

**Summary of what changed in v1.5.0's line counts** (full table
in `REFERENCE.md` §1.4):

| File | v1.5.0 size | Δ from v1.4.0 |
|---|---:|---:|
| `proxy/main.go` | **5,731** | +212 (4 endpoints, 10 helpers, M-1 fix) |
| `proxy/install_app.sh` | **1,101** (new) | — |
| `proxy/boot-mini.sh` | **291** (new) | — |
| `proxy/customize.sh` | 2,718 | ±0 (L-4 comment swap) |
| `proxy/functions.sh` | 2,059 | +~30 (sources `boot-mini.sh`) |
| `proxy/uninstall.sh` | 1,387 | ±0 |
| `proxy/watchdog.sh` | **1,326** | −30 (counting drift) |
| `scripts/package_module.sh` | 972 | +~20 (APK optional handling) |

These values supersede any earlier figure in `docs/REFERENCE.md`,
`README.md`, or `SECURITY.md`.

---

## [v1.4.0] - 2026-10-06

**Integration release** — companion Android app + CodeQL cleanup
+ iOS removal + `LOG_LEVEL` startup-order fix.

### Added

- **Companion Android app integration** — signed APK from
  [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)
  bundled into the module ZIP as `web/app-debug.apk` (OPTIONAL).
  - `proxy/app-apk.version` — SSOT for the app version (`1.0.0`).
  - `scripts/fetch_app_apk.sh` — new fetcher (cache, download,
    SHA256, JSON output, offline mode, `--version` override).
  - `GET /app-debug.apk` — new static route in `proxy/main.go`.
  - **WebUI install button** — converted from a JavaScript modal
    (`beforeinstallprompt`) to a direct `<a download>` link.
  - **Module ZIP** — `scripts/package_module.sh` now bundles
    `web/app-debug.apk` when present.
- **CI/CD integration** — release pipeline fetches the APK into
  `dist/`, stages it at `web/app-debug.apk`, and attaches
  `dist/DNS-Proxy-v*.apk` + `.sha256` to the GitHub Release.
- **Makefile targets** — `make fetch-apk`,
  `make check-app-version`.

### Changed

- Version bumped across all metadata — `VERSION` (`v1.3.0` →
  `v1.4.0`), `module.prop` (`versionCode=1040000`),
  `update.json`, `web/index.html`, `proxy/main.go` header.
- `proxy/main.go` — new `APK_FILE` constant + `serveStaticAssets`
  entry for `/app-debug.apk`.
- `web/index.html` — install button is now
  `<a id="pwaInstallBtn" href="/app-debug.apk" download="DNS-Proxy.apk">`.
- `scripts/package_module.sh` — `WEB_FILES_REQUIRED` and
  `REQUIRED_IN_ZIP` include `app-debug.apk` with OPTIONAL-handling.
- `web/dashboard.html` — version updated to `v1.4.0`.

### Fixed

- **MAIN-01** — `LOG_LEVEL` loaded too late in `main()`. Now
  called immediately after `initPaths()`, before any other
  log-emitting call.
- **CodeQL `go/path-injection` in `removeModule` (partial)** —
  the caller-provided path is sanitized with `filepath.Base()`
  and the final path is rebuilt from `MODULES_DIR` + basename.
  This is functionally correct but CodeQL's `go/path-injection`
  query does **not** recognize `filepath.Base()` as a sanitizer
  in this data-flow context, so the two alerts remained open.
  They were **fully closed** in the **interim, unreleased
  v1.4.1** revision by pinning
  `github.com/cyphar/filepath-securejoin v0.7.0` (ADR-0002) —
  see the "Interim v1.4.1 note" at the top of the v1.5.0
  section.

### Removed

- **iOS PWA logic** (`web/index.html`) — Android-only project.
  ~35 lines removed. `apple-touch-icon.png` is retained (used by
  Android launchers as an icon fallback).

### Security

- **No new audit corrections.** Registry remains at **#33**.
- CodeQL status — 8/8 alerts closed (6 in v1.2.0 + 2 in v1.4.1
  via ADR-0002).

### Breaking Changes

**None.**

### Notes

`web/app-debug.apk` is not tracked by git (`.gitignore` §[20]).
The SW bypasses `/app-debug.apk` (rule 9; see
`docs/REFERENCE.md` §7.7.7).

The repository at v1.4.0 contained **90 tracked files** + 1 build
artifact (91 in the working tree after a release build).

---

## [v1.3.0] - 2026-10-02

**Feature release** — PWA install button, live status LED,
boot-path DNS auto-start, and two server-side refinements.

### Added

- **PWA install button (WebUI)** — smart, browser-adaptive
  (`beforeinstallprompt`). Removed in v1.4.0.
- **Live status LED on the Today counter** — 12×12 LED, green
  when running, red when stopped.
- **SNAP-MANIFEST** — manifest-based snapshot detection in
  `proxy/main.go:buildBackupInfo()`.
- **SNAP-MTIME** — mtime sort for `last_backup_name`.

### Changed

- Version bump across all metadata; `versionCode=1030000`.
- **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** — rotation rewrite in
  `proxy/functions.sh:rotate_backups()`.
- **`proxy/service.sh`** — boot-path DNS auto-start via direct API
  call.

### Fixed

- **`service.sh` — DNS auto-start after boot** — closes a boot
  race. Bounded wait (up to 60 s) then direct call with
  `X-Watchdog-Token`.

### Security

- **No new audit corrections.** Registry remains at **#33**.

### Breaking Changes

**None.**

### Notes

**Reversed decisions**:

| Original decision | Reversal | Rationale |
|---|---|---|
| v1.2.0 BUG-3: `buildBackupInfo` sorts by name | SNAP-MTIME: sorts by mtime | Robustness against clock drift + alignment with `status.sh --json` |
| v1.2.0 `rotate_backups`: name-pattern + name sort | ROT-* semantics | Same rationale + `.last_stable` + newest install protection |

---

## [v1.2.0] - 2026-09-29

**Data-preservation release** — the biggest reliability
improvement since v1.0.0.

### Highlights

- **10 defensive layers** — replaces the "detect upgrade?"
  heuristic with a "search everywhere" philosophy. Fixes a
  **silent data-loss bug** in v1.1.0 that erased the 5 user
  config files on every in-place upgrade.
- **Persistent backup directory** at
  `/sdcard/dnscrypt-webui-backup/` — survives reboot and module
  uninstall.
- **Transactional upgrades** with automatic rollback.
- **Recovery mode** — trigger file restores last known-good
  config on next boot.
- **Bilingual WebUI** (English default + Arabic toggle).
- **7-field `runtime_info.backups`** object.
- **Watchdog token** (`X-Watchdog-Token`) — closes a CSRF hole on
  `POST /api/ensure_running_service`.

### Added

**Backend** — `createAutoBackup(reason)`, `backupMu`,
`cleanupOldTransactions()`, `checkPendingNotifications()`,
`buildBackupInfo()`, `loadOrCreateWatchdogToken()`,
`verifyWatchdogToken()`, `runShellWithTimeout()`.

**Shell** — `backup_user_files`, `restore_user_files`,
`rotate_backups`, `auto_backup_if_needed`,
`cleanup_old_transactions`, `copy_with_context`,
`verify_backup_integrity`, `write_manifest`,
`get_watchdog_token`. `customize.sh` now implements the 10
defensive layers.

**Frontend** — Bilingual WebUI across all three HTML pages;
System Info panel shows 6 backup fields.

**CI/CD** — new `backup-smoke-test` job; new 42-scenario
`upgrade-test.yml` matrix.

**Documentation** — `docs/BACKUP.md`, `docs/EMERGENCY.md` (both
new files, both now merged into `docs/REFERENCE.md` §4 and
`docs/GUIDE.md` §8 respectively).

### Fixed

- **Silent data-loss bug** — installer used a path-comparison
  check that failed on in-place upgrades.
- **FIX-1** — recovery-mode snapshot-and-reapply strategy.
- **FIX-2** — Service Worker update-banner sends `SKIP_WAITING`
  to `swRegistration.waiting`, reloads on `controllerchange`.

### Security

- **No new audit corrections.** Registry remains at **#33**.
- **Watchdog token** — closes a CSRF hole on
  `POST /api/ensure_running_service`.

### Breaking Changes

**`POST /api/append_denylist` now requires a `content` parameter.**
Missing or empty → HTTP 400 with
`{"status":"error","message":"Missing or empty 'content' parameter"}`.

**Migration**: send `content` (URL-encoded), or use
`POST /api/save_denylist` with the full new content.

---

## [v1.1.0] - 2026-09-26

**Polish release** — documentation + three runtime improvements.

### Added

- `memoryLimitForProfile(key)`, `applyMemoryLimit(key)`,
  `readSelectedProfile()`, `memLimitMu`.
- `runtime_info` new fields: `profile_key`, `memory_limit_mb`.
- `functions.sh:get_profile_memory_hint()`.
- Dev workflow infrastructure: `docs/BRANCHING.md`,
  `docs/RELEASE_PROCESS.md`, `scripts/release.sh`,
  `scripts/release-patch.sh`, ADRs 0001–0006,
  `.github/PULL_REQUEST_TEMPLATE/release.md`.

### Fixed

- **`web/offline.html`** — removed restrictive CSP meta that
  blocked the page's own scripts.
- **`proxy/customize.sh`** — port collision fix.
- **`web/sw.js`** — removed misleading comment claiming
  `CACHE_VERSION` was updated automatically.

### Security

- **No new audit corrections.** Registry remains at **#33**.

### Breaking Changes

**None.**

---

## [v1.0.0] - 2026-09-24

**First stable release** — initial public release of DNSCrypt
Smart Filter.

### Overview

| Metric | Value |
|--------|:-----:|
| Total Audit Corrections | **33** |
| Supported architectures | **4** (arm64, arm, amd64, 386) |
| Documentation files | **14** (in `docs/`) |
| Shell scripts | **8** (in `proxy/`) |
| Build scripts | **3** (in `scripts/`) |
| Web/PWA files | **13** (in `web/`) |
| Tracked files | **86** |

### Added

**Backend** — HTTP API, `/healthz`, `/readyz`, `/api/metrics`,
`/events`, `runtime_info`, `hasEndpoint()`, `getSystemShell()`,
`shellQuote()`, `readConfPort()`, `rebuildMu`, auth cache
(60 s), per-port cache, session GC, SSE write deadline (30 s).

**Frontend** — Bilingual WebUI, monitoring Dashboard, Service
Worker, offline fallback, PWA manifest, SVG + PNG + ICO icons,
edit-mode FSM, draft auto-save, hash conflict detection,
dynamic ports.

**Shell** — `customize.sh`, `service.sh`, `post-fs-data.sh`,
`watchdog.sh`, `action.sh`, `status.sh`, `uninstall.sh`,
`functions.sh`, `build.sh`.

**Build** — `scripts/fetch_dns_binaries.sh`,
`scripts/package_module.sh`, `scripts/generate-icons.sh`.

**CI/CD** — `ci.yml`, `release.yml`, `codeql.yml`,
`dependabot.yml`, `.pre-commit-config.yaml`.

**Documentation** — 14 files in `docs/`; root `README.md`,
`SECURITY.md`, `CODE_OF_CONDUCT.md`, `LICENSE`, `CHANGELOG.md`.

### Security

**33 Audit Corrections applied.** The full registry — with
per-entry descriptions — lives in `SECURITY.md` §15.

The 33 corrections cover:

- **Authentication & sessions** (5): #13, #15-a/b, #22, #24
- **CSRF** (2): #13, #28
- **Firewall** (3): #16-a/b, #17
- **Ports** (2): #20, #33
- **Concurrency** (1): #32
- **Injection** (3): #21, #23, #31
- **Rate limiting** (2): #19, #22
- **Path/state** (5): #18, #26, #29, #30, #33
- **Data** (3): #25, #26, #32
- **Logic / hygiene** (10): #1, #3-e/f, #5, #6-c, #7, #9/#9-b, #10, #14, #27

**Last applied**: #33 (v1.0.0).
**Next expected**: #34 (future release).

### Breaking Changes

N/A — first stable release.

### Known Issues

| Issue | Target |
|-------|:------:|
| CSP `'unsafe-inline'` in `script-src` | Deferred |
| `pgrep -x` on Android 5.x | Deferred |
| `awk` parser with `]` in comment | Deferred |
| PWA dual-origin limitation (9090 vs 9091) | Deferred |
| `manifest.json` shortcuts don't read `runtime_info` | Deferred |

---

## Notes

### Audit Corrections Registry

The full registry — with descriptions, categories, and per-entry
analysis — lives in **`SECURITY.md` §15**.

**Key facts**:

- **33 total corrections** filed against the v1.0.0 tree.
- **No new corrections** in v1.1.0, v1.2.0, v1.3.0, v1.4.0, or
  v1.5.0 — those releases added **runtime improvements**,
  **correctness fixes**, **feature additions**, and
  **post-audit fixes** (v1.5.0), not audit-correction entries.
- **Next expected**: #34 (future release).

The registry uses a **monotonic numbering scheme**. Numbers are
never reused. Rows with slash notation (`#3-e/f`, `#9/#9-b`,
`#15-a/b`, `#16-a/b`) represent two related fixes under one ID.

### Line counts, file counts, and version files

These are **not** part of the CHANGELOG. For the current values,
see:

- **`docs/REFERENCE.md` §1.4** — line counts per file
- **`docs/REFERENCE.md` §1.8.3** — file count model (fresh
  clone, package, full build)
- **`docs/CONTRIBUTING.md` §11.4** — version file update
  procedure
- **`SECURITY.md` §15** — full Audit Corrections Registry

### Historical references

Entries for **v1.0.0 through v1.4.0** reference files and ADRs by
their **historical names** — e.g. `docs/BRANCHING.md`,
`docs/RELEASE_PROCESS.md`, `ADRs 0001–0006`. Those files were
created at the version where they are mentioned and merged into
newer documents as part of the v1.5.0 documentation
consolidation. The v1.5.0 "Documentation" change entry
(`Changed`) documents the migration. See `docs/MAP.md` for the
current structure and the full reverse-lookup table.

### Links

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)

[Unreleased]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.5.0...HEAD
[v1.5.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.4.0...v1.5.0
[v1.4.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.3.0...v1.4.0
[v1.3.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.2.0...v1.3.0
[v1.2.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.1.0...v1.2.0
[v1.1.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.0.0...v1.1.0
[v1.0.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/releases/tag/v1.0.0