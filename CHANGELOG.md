# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Author**: gasciljh
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Last updated**: 2026-10-15

---

## [Unreleased]

Changes that will land in the next release. This section is
**empty at the moment of each release** — planned features are
tracked in [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## [v1.5.0] - 2026-10-13

**Feature release** — companion app one-tap root install, plus
twelve frontend state/interaction fixes and nine server-side
code-review corrections. Full bilingual UI (EN + AR) is retained
throughout.

**Audit Corrections Registry** remains at **#33** (last entry from
v1.0.0). v1.5.0 is a **feature release**, not an audit-correction
release. The four new endpoints, the 5-level `pm install` cascade,
and every accompanying fix are documented as feature additions and
code-review polish, not as audit corrections.

**Phase 0 — Layered Bootstrap**: shell primitives extracted into
`proxy/boot-mini.sh` (Layer 0), consumed by `proxy/functions.sh`
(Layer 1). See `docs/adr/0008-layered-bootstrap.md`.

**Manifest Notes extraction**: 7 `x-note-*` fields moved from
`web/manifest.json` into `docs/MANIFEST_NOTES.md`. The manifest
shrinks from ~6 KB to ~3 KB. See §11.62 in
`docs/ARCHITECTURE.md`.

**Interim v1.4.1 note**: `v1.4.1` was an interim, unreleased,
`go.mod`-only revision. It pinned
`github.com/cyphar/filepath-securejoin v0.7.0` (see ADR-0007) to
close two CodeQL `go/path-injection` alerts in `removeModule`.
It was never tagged, has no CHANGELOG entry of its own, and is
fully superseded by v1.5.0. The complete v1.4.1 delta:
- `proxy/go.mod` — added `require github.com/cyphar/filepath-securejoin v0.7.0`.
- `proxy/go.sum` — new file (introduced in v1.4.1).
- `proxy/main.go` — `removeModule` routes the caller-provided
  path through `filepath.Base()` and rebuilds the final path
  from `MODULES_DIR` + the sanitized basename.
- `docs/adr/0007-external-dependency-securejoin.md` — new ADR
  authorising the first (and only) external Go dependency.

### 📊 Overview

| Metric | Value |
|--------|:-----:|
| Total Audit Corrections | 33 (unchanged from v1.0.0) |
| New HTTP endpoints | **4** (`install_companion_app`, `uninstall_companion_app`, `install_token`, `companion_app_state`) |
| New shell scripts | **2** (`proxy/boot-mini.sh`, `proxy/install_app.sh`) |
| Install cascade levels | **5** (`pm install` variants) |
| Frontend state fixes | **12** (IDX-23, IDX-23b, IDX-24, IDX-25, IDX-25a, IDX-429, IDX-401-DISTINCT, DASH-REFRESH-01, DASH-SESSION-RETRY-01, DASH-HINT-01, DASH-HINT-02, ICON-512-SAFEZONE-01) |
| Server-side code-review corrections | **9** (MAIN-REENT-01, MAIN-PORTCACHE-01, MAIN-DEADLOCALHOST-01, MAIN-APPENDHASH-01, MAIN-02, MAIN-03, MAIN-04, MAIN-05, MAIN-CACHE-01) |
| Documentation corrections | **13 categories** (see Legend) |
| Tracked files | **97** (was 90 in v1.4.0; **+7**) |
| Build artifacts | **0–11** (all gitignored) |
| Working tree | **97–108** (three canonical states) |
| Test scenarios (CI matrix) | 42 (`upgrade-test.yml`, unchanged) |
| Platform coverage | Android / Linux / macOS / WSL2 |

### ✨ Highlights

- **Companion app one-tap root install** — the WebUI install button
  no longer opens a plain `<a download>` link. It opens an
  **install-method modal** (IDX-24) offering **three actions across
  two categories**:
  1. **Install locally** (recommended) — `POST /api/install_companion_app`
     with a one-shot CSRF token; the server runs
     `install_app.sh` (at the module root) — a **5-level `pm install`
     cascade**.
  2. **Open GitHub page** — external URL.
  3. **Direct download from GitHub** — external URL.

  The cascade tries, in order:
  1. `pm install -r --user 0 <apk>`
  2. `pm install -r --user 0 -i com.android.shell <apk>`
  3. Session-based (`install-create` + `install-write` + `install-commit`)
  4. `magisk su -c "pm install -r <apk>"`
  5. `cmd package install -r <apk>`

  All bounded by a **75-second `CASCADE_DEADLINE_SECONDS`** constant,
  strictly less than the server-side 90-second `INSTALL_TIMEOUT`.
  **SELinux is never disabled** — the APK is staged to
  `/data/local/tmp/` (context `shell_data_file`) instead. Play
  Protect's package verifier is temporarily disabled for the
  duration of the cascade and restored via a three-way
  `EXIT / INT / TERM` trap that returns the exact captured value.

- **Layered Bootstrap (Phase 0)** — the shell layer is split into
  **Layer 0** (`proxy/boot-mini.sh`: the five primitives +
  `_MONITORING_UI_PORT`) and **Layer 1** (`proxy/functions.sh`).
  Callers source `functions.sh` as before; the split is
  transparent. CI verifies that `functions.sh` does not redefine
  any Layer-0 primitive.

- **Manifest Notes extraction** — 7 `x-note-*` fields (maskable,
  icon-source, language, backup-schema, ports, future-work,
  extended companion-apk) were moved from `web/manifest.json`
  into a new `docs/MANIFEST_NOTES.md`. The manifest is now ~3 KB
  (was ~6 KB) with 5 fields. The new file is the authoritative
  reference for every extracted field.

- **Four new backend endpoints** in `proxy/main.go`:
  - `POST /api/install_companion_app` — root install (CSRF token + rate-limited, localhost-only)
  - `POST /api/uninstall_companion_app` — reserved for future UI (localhost-only)
  - `GET  /api?action=install_token` — one-shot CSRF token (60 s TTL, localhost-only)
  - `GET  /api?action=companion_app_state` — install state (30 s cache)

- **Companion APK mirror** — `customize.sh §[10c]` mirrors the APK
  and its `.sha256` sidecar to
  `/sdcard/dnscrypt-webui-backup/apk/` (best-effort). The mirror
  survives uninstall and is preserved by `rotate_backups()` because
  it has no `.manifest.json` and is explicitly listed in the `case`
  statement that skips `current/`, `txn-*/`, and `orphan-txn-*/`.

- **Frontend state fixes** — twelve interaction/state corrections:
  - **IDX-23** — companion button state survives language toggles.
  - **IDX-23b** — "Service Running" status card updates instantly
    on language toggle.
  - **IDX-24** — install-method modal (three actions across two
    categories).
  - **IDX-25** — Dashboard section-nav dead links fixed.
  - **IDX-25a** — Dashboard centered hint toast.
  - **IDX-429** — install rate-limit message rendered distinctly.
  - **IDX-401-DISTINCT** — install-family 401 no longer triggers
    the generic "Session Expired" modal.
  - **DASH-REFRESH-01** — `isRefreshing` reset on 401.
  - **DASH-SESSION-RETRY-01** — session-expired modal's primary
    action is a full reload.
  - **DASH-HINT-01** — card-expand hint uses a dual-timer lifecycle.
  - **DASH-HINT-02** — card-expand hint scheduled via `scrollend`.
  - **ICON-512-SAFEZONE-01** — shield path fits the W3C maskable
    safe circle (radius 204.8 px, center 256,256).

- **Nine server-side code-review corrections** in `proxy/main.go`:
  - **MAIN-REENT-01** — logger split into three layers
    (`logWithLevel` / `logLocked` / `writeLocked`), eliminating a
    latent deadlock when `os.Rename` fails during log rotation.
  - **MAIN-PORTCACHE-01** — `getWebUIPort()` / `getDashboardPort()`
    use a 30-second TTL cache.
  - **MAIN-DEADLOCALHOST-01** — `isLocalRequest()` no longer
    contains an unreachable `"localhost"` comparison.
  - **MAIN-APPENDHASH-01** — `appendDenylist()` uses
    `getRulesState().DenylistHash`, matching the source consulted
    by `saveDenylist()`.
  - **MAIN-02** — `getCompanionState()` uses a three-phase read
    (short lock → probe outside lock → short lock) instead of
    holding the mutex for up to 90 seconds.
  - **MAIN-03** — install endpoints return proper HTTP status codes
    (401 / 403 / 429 / 200).
  - **MAIN-04** — `callInstallScript()` captures stderr through a
    bounded `limitedBuffer` (2048 bytes).
  - **MAIN-05** — `startSessionGC()` also prunes `installAttempts`.
  - **MAIN-CACHE-01** — companion state cache is invalidated
    unconditionally after every install/uninstall attempt.

- **Documentation sweep** — corrections applied across `README.md`,
  `docs/API.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/MANIFEST_NOTES.md`, `.shellcheckrc`, `.gitattributes`,
  `.editorconfig`, and the file headers. Consolidated tables live
  in each file's "Documentation Corrections" section
  (`docs/SECURITY.md` §18, `docs/API.md` §13,
  `docs/ARCHITECTURE.md` §17).

### Added

#### Backend (Go) — v1.5.0

- **4 new HTTP endpoints** in `proxy/main.go` §[32] `handleAPI`:
  - `POST /api/install_companion_app` — root install; requires auth
    + localhost + one-shot CSRF token; rate-limited per IP.
  - `POST /api/uninstall_companion_app` — uninstall; reserved for
    a future UI.
  - `GET  /api?action=install_token` — one-shot CSRF token (64 hex
    chars, 60 s TTL, single use). Consumed by the install endpoint.
    Localhost-only.
  - `GET  /api?action=companion_app_state` — cached install state
    (30 s TTL). Invalidated after every install/uninstall attempt.

- **10 helper functions** in `proxy/main.go` §[17d]:
  - `getInstallScript()`
  - `generateInstallToken()`
  - `validateAndConsumeInstallToken()`
  - `recordInstallAttempt()`
  - `isInstallLockedOut()`
  - `callInstallScript()`
  - `installCompanionApp()`
  - `uninstallCompanionApp()`
  - `getCompanionState()`
  - `invalidateCompanionStateCache()`

- **3 new concurrency primitives** in `proxy/main.go` §[8b]:
  - `installTokens` (`sync.Mutex`) — CSRF token store
  - `installAttempts` (`sync.Mutex`) — per-IP install rate limiter
  - `companionStateCache` (`sync.Mutex`) — 30 s response cache

- **New constants** in `proxy/main.go` §[3b]:
  - `INSTALL_SCRIPT_REL = "install_app.sh"` (relative to `MODDIR`)
  - `INSTALL_TIMEOUT = 90 * time.Second`
  - `INSTALL_TOKEN_TTL = 60 * time.Second`
  - `MAX_INSTALL_ATTEMPTS = 5`
  - `INSTALL_LOCKOUT_PERIOD = 15 * time.Minute`
  - `COMPANION_STATE_CACHE_TTL = 30 * time.Second`

- **Status helper functions** in `proxy/main.go` §[32]:
  - `writeInstallError(w, status, action, reason, message)`
  - `classifyInstallResult(result)`
  - `isInstallFamilyUrl(url)`

- **Port cache** in `proxy/main.go` §[3] + §[8] + §[9]:
  - `readConfPortCached(key, defaultPort, which)` — 30 s TTL cache.
  - `CONF_PORT_CACHE_TTL = 30 * time.Second`.
  - `portConfMu` (`sync.RWMutex`) + `cachedWebPort` + `cachedDashPort`.

- **Logger split** in `proxy/main.go` §[10]:
  - `logWithLevel(level, msg)` — public entry point.
  - `logLocked(level, msg)` — internal; assumes lock held.
  - `writeLocked(level, msg)` — internal; assumes lock held.
  - Rotate-failure path now calls `writeLocked`, never
    `logWithLevel`.

- **`HTTP_WRITE_TIMEOUT` raised** from 60 s → **150 s** (in `main.go`
  §[3]). The pre-patch 60-second value was shorter than
  `INSTALL_TIMEOUT` (90 s), so a slow install would complete
  successfully on the device but the client would see a connection
  reset before the JSON response arrived. 150 s leaves 60 s of
  headroom.

#### Shell Scripts — v1.5.0

- **`proxy/boot-mini.sh` (NEW)** — Layer 0 primitives extracted
  from the shell layer (Phase 0):
  - `log_msg`
  - `get_run_dir`
  - `read_conf`
  - `is_port_open`
  - `get_webui_port`
  - `_MONITORING_UI_PORT` (single source of truth, value = `8080`)

  Zero dependencies. Sourced by `functions.sh` at load time. CI
  verifies that `functions.sh` does not redefine any of the five
  primitives.

- **`proxy/install_app.sh` (NEW)** — the companion install script.
  Staged at the **module root** (next to `customize.sh`). Modes:
  - `install_app.sh` — install the companion app
  - `install_app.sh --status` — report state (JSON)
  - `install_app.sh --uninstall` — remove the package
  - `install_app.sh --version` — print the script version
  - `install_app.sh --help` — show help

  Implementation details:
  - **Pre-flight checks** — APK exists, ZIP magic `PK`, size
    > 100 KB, free space ≥ 3× APK size.
  - **5-level cascade** — with per-strategy polling (15 s) to
    confirm the package registered.
  - **Error translation** — AR + EN for 7 common failure modes,
    with optional hints.
  - **SELinux staging** — APK copied to
    `/data/local/tmp/dnscrypt-companion.apk`. `setenforce 0` is
    **never** called.
  - **Play Protect temporary disable** — the verifier is disabled
    for the duration of the cascade and restored on every
    catchable exit path. The trap restores the exact captured
    value (`$_VERIFIER_ORIG`).
  - **SHA256 verification** — if `web/app-debug.apk.sha256` is
    present, the APK hash is verified before any install strategy
    is attempted. Advisory if missing.
  - **75-second cascade deadline** (`CASCADE_DEADLINE_SECONDS=75`).
  - **Three-way signal-trap split** — `EXIT` / `INT` / `TERM` with
    a `_CLEANED_UP` re-entry guard. INT exits **130**, TERM exits
    **143**.
  - **ShellCheck fixes** — SC2015 × 2, SC2181 × 1, SC2329
    suppression via inline comment.

- **`proxy/customize.sh`** — three additions:
  - **CSH-20** — new section §[10c]: mirror the companion APK +
    `.sha256` to `$PERSISTENT_BACKUP/apk/` (best-effort).
  - **CSH-22** — `install_app.sh` and `boot-mini.sh` are now part
    of the §[9] unzip argument list and the §[10] critical-files
    check. Before CSH-22, `install_app.sh` was packaged but not
    extracted, so `main.go`'s `getInstallScript()` resolved a
    non-existent path and every install returned
    `reason=script_not_found`.
  - **CSH-21** — version bump v1.4.0 → v1.5.0.

- **`proxy/functions.sh`** — one behaviour fix + documentation:
  - **FSH-DEF-01** — `restore_user_files()` now **breaks** out of
    the restore loop on a critical-file failure.
  - Documented that the library is orthogonal to the companion
    install flow; every helper preserves the `apk/` subfolder.

- **`proxy/uninstall.sh`** — APK mirror preservation policy:
  - The companion APK mirror at `$PERSISTENT_BACKUP/apk/` is
    preserved explicitly and reported in the final summary.
  - New section §[0.5] documents the full APK mirror preservation
    policy.

- **`scripts/package_module.sh`** — five new fixes:
  - `web/app-debug.apk.sha256` bundled as a SECOND optional entry.
  - `install_app.sh` and `boot-mini.sh` added to the module ZIP's
    shell script set.
  - Header counters corrected: 35 entries (33 required + 2 optional).
  - `WEB_FILES_REQUIRED` split into `WEB_FILES_REQUIRED` (13) +
    `WEB_FILES_OPTIONAL` (2).
  - Removed a stray `# shellcheck disable=SC2064`.

#### Frontend (PWA) — v1.5.0

- **`web/index.html`** — install-method modal (IDX-24):
  - Three actions across two categories: local install / GitHub
    page / direct GitHub download.
  - `showInstallModal(token)` builds the modal HTML inline.
  - `_resetModalLayout()` (idempotent) restores the standard modal
    layout at the start of every `showConfirmModal()` call.
  - `handleCompanionInstall()` disables the install button during
    the token fetch and re-enables it on both success and failure
    paths.
  - `doCompanionInstall(token)` calls
    `POST /api/install_companion_app` with `retries = 0` (the first
    request consumes the one-shot token).
  - `getCompanionApkUrl()` builds the direct-download URL from
    `companionState.expected_version` (SSOT from
    `proxy/app-apk.version`), with fallbacks to
    `runtimeInfoData.app_version` and a hardcoded default.

- **`web/index.html`** — state fixes:
  - **IDX-23** — `companionState` is the single source of truth;
    `renderCompanionButton()` is a pure renderer.
  - **IDX-23b** — `renderAllDynamic()` funnels every
    language-sensitive, state-driven element through one entry
    point called from `updateUIStrings()`.
  - **IDX-429** — `xhrRequest()` recognises HTTP 429 and attaches
    `err.code = 429`; `doCompanionInstall()` renders
    `t('installRateLimited')`.
  - **IDX-401-DISTINCT** — `isInstallFamilyUrl(url)` suppresses
    the generic session-expired modal for install-family URLs.

- **`web/dashboard.html`** — state fixes:
  - **IDX-25** — `updateNavLinks()` now points at the real card IDs
    (`runtimeInfoCard`, `diagFilesCard`).
  - **IDX-25a** — the card-expand hint is centered in the viewport.
  - **DASH-REFRESH-01** — `isRefreshing` is reset inside
    `handleSessionExpired()` and inside the 401 branch of
    `fetchDashboardData()`.
  - **DASH-SESSION-RETRY-01** — the session-expired modal's primary
    action resets `sessionExpired` and `isRefreshing`, then calls
    `location.reload()`. On cold-start (no data cached), the
    dashboard redirects immediately to the WebUI URL instead of
    showing a modal.
  - **DASH-HINT-01** — `resetCardHintTimer()` manages **two**
    timers (`cardHintTimer` + `cardHintRemoveTimer`).
  - **DASH-HINT-02** — the hint is scheduled via the `scrollend`
    event (with a 400 ms `setTimeout` fallback).

- **`web/icon-512.svg`** — **ICON-512-SAFEZONE-01**:
  - The shield path was corrected so every control point fits
    inside the W3C maskable safe circle (radius 204.8 px, center
    256,256).
  - Top vertex: `y = 52 → y = 60`.
  - Shoulders: `y = 116 → y = 130`.

- **`web/sw.js`** — three additions/fixes:
  - **SW-PRECACHE-01** — `PRECACHE_ASSETS` remains at **11 files**.
    `/dashboard.html` was considered but NOT added: on the WebUI
    origin (9090), it would be cached under a wrong key (the
    catch-all serves `index.html` for any unknown path); on the
    Dashboard origin (9091), it duplicates `/`. See
    `docs/MANIFEST_NOTES.md` §9.
  - **SW-DEF-01** — `clients.claim()` is now guarded with a
    `.catch()`, so a rejected claim no longer skips the client
    notification loop.
  - **SW-DEF-02** — `client.postMessage()` is wrapped in `try/catch`.

- **`web/offline.html`** — one fix:
  - **OFF-DEF-03** — a **persistent banner** replaces the
    transient 5-second toast that appeared after the auto-retry
    budget was exhausted. The banner remains visible and offers a
    "Retry now" button, giving the user a clear next action.

#### Documentation — v1.5.0

- **`docs/MANIFEST_NOTES.md` (NEW)** — consolidates 7 `x-note-*`
  fields extracted from `web/manifest.json`:
  - Maskable safe zone (W3C spec, control-point analysis)
  - Icon source pipeline (SVG → PNG → ICO)
  - Language policy (EN default + AR toggle)
  - Backup schema (7-field `runtime_info.backups`)
  - Reserved ports (9090 / 9091 / 8080 / 5354)
  - PWA shortcuts dual-origin limitation
  - Companion APK integration
  - Tracked-file model (three canonical states)
  - Deferred items

- **`docs/API.md`** — seven new sections and a comprehensive
  post-audit block:
  - §1.4 "What was New in v1.5.0".
  - §1.5 "What was New in v1.5.0+ (Post-release)".
  - §2.7 "Install Token" — full lifecycle.
  - §6.1.16 `GET /api?action=install_token`.
  - §6.1.17 `GET /api?action=companion_app_state`.
  - §6.2.14 `POST /api/install_companion_app`.
  - §6.2.15 `POST /api/uninstall_companion_app`.
  - §13 "Documentation Corrections to This File".

- **`docs/ARCHITECTURE.md`** — extensive additions:
  - §2.1 diagram updated with `install_app.sh` and `boot-mini.sh`.
  - §2.2 component table extended.
  - §3.11 companion install flow — full end-to-end sequence.
  - §4.6.7 code-review corrections.
  - §4.6.8 post-release backend patches.
  - §4.14 v1.5.0 backend additions.
  - §5.0 Layered Bootstrap overview (new).
  - §5.8 `install_app.sh` contract (13 subsections).
  - §6.9–§6.12 frontend fixes.
  - §8.2 + §8.3 file-count model.
  - §11.45–§11.62 trade-offs.
  - §17 "Documentation Corrections to This File".

- **`docs/SECURITY.md`** — new §5.36 "Companion App Install
  Security" with nine subsections:
  - §5.36.1 — one-shot CSRF token.
  - §5.36.2 — per-IP install rate limit.
  - §5.36.3 — SELinux staging (never `setenforce 0`) + staged-APK
    cleanup via three-way trap.
  - §5.36.4 — Play Protect temporary disable + trap-restore +
    75 s cascade deadline.
  - §5.36.5 — 5-level cascade security rationale.
  - §5.36.6 — "failure is 200, not 4xx" design.
  - §5.36.7 — 3 package-name candidates.
  - §5.36.8 — SHA256 advisory verification.
  - §5.36.9 — summary table.
  - §18 "Documentation Corrections to This File".

- **`README.md`** — corrections:
  - Install-method modal usage (three actions).
  - Cascade deadline note.
  - Companion app install flow.
  - `/sdcard` storage requirement corrected from `~13 MB` to `~6 MB`.
  - File-count model (three canonical states).
  - Line-count note (install_app.sh → 1,101 lines).
  - Documentation table includes `docs/MANIFEST_NOTES.md`.

#### CI/CD — v1.5.0

- **`.github/workflows/ci.yml`** — new smoke-test steps:
  - **Step 2 (fixed)** — hard assertions via a `_check_required`
    helper. The pre-fix revision used `grep -q PATTERN file && echo`,
    which is silently exempt from `set -e` and therefore never
    actually failed the step.
  - **Step 4 (fixed)** — same defect as Step 2; converted to hard
    assertions.
  - **Step 10 (fixed)** — the accepted fallback pattern for
    `_MONITORING_UI_PORT` now includes the trailing `"`, so the
    check matches the actual scripts.
  - **Step 8** — verifies `proxy/install_app.sh` is present and
    executable, and that the CSH-22 integration is intact.
  - **Step 9** — verifies the Layered Bootstrap integration.
  - The `bash -n` syntax check now covers **10 shell scripts** (was
    8 — `install_app.sh` and `boot-mini.sh` added).

- **`.github/workflows/release.yml`** — additions:
  - The release pipeline fetches and stages
    `web/app-debug.apk.sha256` alongside `web/app-debug.apk` before
    packaging.
  - **New step** — "Verify metadata consistency": on tag pushes,
    verifies `VERSION == module.prop.version == update.json.version`,
    `releaseDate == x-note-last-updated`, and that the `versionCode`
    matches the canonical formula.
  - **Sync step hardened** — bounded rebase-skip loop
    (`MAX_SKIP_ITERATIONS=100`) with real conflict detection.

- **`.github/workflows/upgrade-test.yml`** — fix:
  - The scenario dispatcher now wraps the entire `case` body in a
    `run_scenario()` function. The pre-fix revision used `local`
    outside any function, which is a fatal error under `set -e` in
    bash and silently aborted ~14 scenarios.

#### Tracked file deltas

**The 7 tracked files added in v1.5.0**:

- `.shellcheckrc`
- `.github/codeql/codeql-config.yml`
- `docs/adr/0007-external-dependency-securejoin.md`
- `docs/adr/0008-layered-bootstrap.md`
- `docs/MANIFEST_NOTES.md`
- `proxy/boot-mini.sh`
- `proxy/go.sum`

**Total tracked files**: 97 (was 90 in v1.4.0).

---

### Changed

#### Backend (Go)

- **`proxy/main.go`** — version string `v1.4.0` → `v1.5.0` in the header.
- **`proxy/main.go`** — `USER_AGENT` built from `BuildVersion` + platform + project URL.
- **`proxy/main.go`** — `handleAPI` registers the 4 new endpoints.
- **`proxy/main.go`** — the localhost gate now covers all three
  install surfaces.
- **`proxy/main.go`** — `getWebUIPort()` / `getDashboardPort()` now
  route through the 30 s TTL cache (MAIN-PORTCACHE-01).
- **`proxy/main.go`** — `logWithLevel` split into three layers
  (MAIN-REENT-01).
- **`proxy/main.go`** — `isLocalRequest` dead-branch removed
  (MAIN-DEADLOCALHOST-01).
- **`proxy/main.go`** — `appendDenylist` now passes
  `getRulesState().DenylistHash` (MAIN-APPENDHASH-01).
- **`proxy/main.go`** — `HTTP_WRITE_TIMEOUT` raised from 60 s to
  150 s.

#### Shell Scripts

- **`proxy/customize.sh`** — version bumped v1.4.0 → v1.5.0 (CSH-21).
- **`proxy/customize.sh`** — §[10c] APK mirror added (CSH-20).
- **`proxy/customize.sh`** — `install_app.sh` and `boot-mini.sh`
  added to §[9] unzip, §[10] critical-files check, and §[19] chmod
  (CSH-22).
- **`proxy/functions.sh`** — version bumped v1.4.0 → v1.5.0.
- **`proxy/functions.sh`** — `restore_user_files()` now breaks on
  critical-file failure (FSH-DEF-01).
- **`proxy/uninstall.sh`** — version bumped v1.4.0 → v1.5.0.
- **`scripts/package_module.sh`** — version bumped v1.4.0 → v1.5.0.
- **`scripts/generate-icons.sh`** — version bumped v1.4.0 → v1.5.0.

#### Frontend (PWA)

- **`web/sw.js`** — `CACHE_VERSION` bumped from `v1.4.0` to
  `v1.5.0`. `PRECACHE_ASSETS` remains at **11 files**.
- **`web/manifest.json`** — `version` bumped to `1.5.0` (no `v`).
  `x-note-*` fields reduced from 11 to 5 (6 extracted to
  `docs/MANIFEST_NOTES.md`). Size reduced from ~6 KB to ~3 KB.
- **`web/index.html`** — `var VERSION = 'v1.5.0'`; `<title>` and
  footer updated.
- **`web/dashboard.html`** — `var VERSION = 'v1.5.0'`; `<title>`
  and footer updated.
- **`web/offline.html`** — `var VERSION = 'v1.5.0'`; `<title>` and
  badge updated.

#### Build & Configuration

- **`VERSION`** — `v1.4.0` → `v1.5.0`.
- **`module.prop`** — `version=v1.5.0`, `versionCode=1050000`.
- **`update.json`** — `version=v1.5.0`, `versionCode=1050000`,
  `versionName=v1.5.0 (Global Edition)`,
  `releaseDate=2026-10-13`, `zipUrl=...v1.5.0...`,
  `x-note-last-updated=2026-10-13`.
- **`proxy/go.mod`** — header only (no functional change from
  v1.4.1).
- **`proxy/go.sum`** — unchanged from v1.4.1.

#### Documentation

- **`CHANGELOG.md`** (this file) — Legend rewritten with the
  count-reconciliation table (see §Legend). Header date bumped.
- **`docs/SECURITY.md`** — §18 added. Documentation-corrections
  identifier inventory consolidated.
- **`docs/ARCHITECTURE.md`** — §17 expanded with
  ARCH-MANIFEST-01.
- **`.shellcheckrc`** — the `SC-VERIFY-01` correction removed the
  inaccurate "last-wins" claim and replaced it with "merge"
  semantics.

---

### Fixed

#### Critical — v1.5.0 pre-release

- **CSH-22 — `install_app.sh` was not extracted** by
  `customize.sh §[9]`'s unzip argument list, even though it was
  packaged by `scripts/package_module.sh §[16]` at the ZIP root.
  After a normal install, `$MODPATH/install_app.sh` did not exist,
  and `main.go getInstallScript()` resolved a non-existent path.
  Every install attempt returned `reason=script_not_found`,
  defeating the primary v1.5.0 feature. Fixed by adding
  `install_app.sh` (and `boot-mini.sh`) to the §[9] extraction
  list, the §[10] MISSING check, and the §[19] chmod loop.

- **MAIN-REENT-01 — deadlock in `logWithLevel`** on log rotation
  failure. The pre-patch implementation held `logMutex` and called
  `logWithLevel` recursively from inside the rotation branch when
  `os.Rename` failed. `sync.Mutex` is **not reentrant** in Go, so
  a failed rename on a full or read-only `/data/local/tmp` would
  deadlock the calling goroutine. Fixed by splitting the logger
  into three layers.

#### Important — v1.5.0 pre-release

- **DASH-REFRESH-01 — Dashboard Refresh button locked** in the
  "loading" state for the remainder of the tab's lifetime after a
  401. Fixed by resetting `isRefreshing` inside the 401 branch
  before calling `handleSessionExpired()`.

- **DASH-SESSION-RETRY-01 — Dashboard tab frozen** after the
  session-expired modal. Fixed by resetting both `sessionExpired`
  and `isRefreshing`, then calling `location.reload()`.

- **DASH-HINT-01 — card-expand hint removed** during the fade-out
  window. Fixed by introducing `cardHintRemoveTimer` and clearing
  both timers together inside `resetCardHintTimer()`.

- **DASH-HINT-02 — card-expand hint scheduled** with a fixed
  400 ms `setTimeout`. Fixed by scheduling through the `scrollend`
  event (with a 400 ms `setTimeout` fallback) and sharing a
  `cardHintScheduled` guard.

- **IDX-25 — Dashboard section-nav dead links**. Fixed by pointing
  the two anchors at the real IDs (`runtimeInfoCard`,
  `diagFilesCard`).

- **IDX-23 — Companion button state reverted** to "Install App"
  on every language toggle. Fixed by introducing `companionState`
  (single source of truth) + `renderCompanionButton()` (pure
  renderer).

- **IDX-23b — Status card delay** of ~3 s after language toggle.
  Fixed by routing every state-driven, language-sensitive element
  through `renderAllDynamic()`.

- **IDX-429 — HTTP 429 shown as generic "Install failed"**. Fixed
  by having `xhrRequest()` recognise HTTP 429, attaching
  `err.code = 429`, and rendering `t('installRateLimited')`.

- **IDX-401-DISTINCT — 401 from install-family URLs triggered**
  the generic "Session Expired" modal. Fixed by adding
  `isInstallFamilyUrl(url)` and suppressing the modal for
  install-family URLs.

- **ICON-512-SAFEZONE-01 — Shield shoulders clipped** on Android
  launchers that apply a 40% circular mask. Fixed by moving the
  top vertex from `y=52` to `y=60` and the shoulders from `y=116`
  to `y=130`.

- **MAIN-DEADLOCALHOST-01 — `isLocalRequest` dead branch**.
  Removed an unreachable `"localhost"` comparison.

- **MAIN-APPENDHASH-01 — spurious 409 conflict** on
  `append_denylist` when `denylist.txt` had been modified
  externally. Fixed by aligning `appendDenylist()`'s hash source
  with `saveDenylist()`'s.

- **MAIN-02 — `getCompanionState()` held the mutex** for up to
  90 s. Fixed by using a three-phase read.

- **MAIN-03 — install endpoints returned HTTP 200** for every
  outcome, including rate-limit and token failures. Fixed by
  returning 401 / 403 / 429 as documented.

- **MAIN-04 — `callInstallScript()` captured stderr** through an
  unbounded `bytes.Buffer`. Fixed by using a `limitedBuffer`
  capped at `MAX_STDERR_CAPTURE` (2048 bytes).

- **MAIN-05 — `installAttempts` never garbage-collected**. Fixed
  by adding the pruning loop to `startSessionGC()`.

- **MAIN-CACHE-01 — companion state cache not invalidated** after
  install/uninstall. Fixed by calling
  `invalidateCompanionStateCache()` after every terminal outcome.

- **CIA-DEF-03 — signal-trap integrity**. The pre-patch single
  `EXIT INT TERM` trap cleaned up but did **not** call `exit` for
  the INT and TERM cases. Fixed by splitting into three handlers
  with a `_CLEANED_UP` re-entry guard.

- **CIA-DEF-04 — ShellCheck 0.11.0 warnings**. Fixed:
  - `SC2015` × 2 — replaced `A && B || C` with explicit
    `if/then/fi` blocks.
  - `SC2181` × 1 — replaced `_out=$(...); _rc=$?; if [ "$_rc" ...`
    with a direct `if _out=$(...); then` construct.

- **CIA-DEF-05 — `SC2329` false positive**. Added
  `# shellcheck disable=SC2329` above `_cleanup_app`.

- **V15-CODE-05 — cascade not bounded**. Added a 75-second
  wall-clock deadline (`CASCADE_DEADLINE_SECONDS=75`).

- **V15-CODE-07 — trap restore value**. The trap now restores the
  **exact captured value** of `package_verifier_enable`
  (`$_VERIFIER_ORIG`) rather than a hardcoded `1`.

#### Critical — v1.5.0+ post-release

- **HTTP_WRITE_TIMEOUT was 60 s** — shorter than the server-side
  `INSTALL_TIMEOUT = 90 s`. A slow install (65–75 s) would complete
  successfully on the device but the client would see a connection
  reset before the JSON response arrived. Fixed by raising
  `HTTP_WRITE_TIMEOUT` to **150 s**.

- **`install_token` endpoint was not localhost-restricted** — the
  `isLocalRequest()` gate covered only `install_companion_app` and
  `uninstall_companion_app`. Fixed by extending the gate to the
  `install_token` GET endpoint.

- **`upgrade-test.yml` scenarios used `local` outside any
  function**. In bash, `local` outside a function is a fatal error
  under `set -e`. This silently aborted ~14 scenarios. Fixed by
  wrapping the entire scenario body in a `run_scenario()` function.

- **`ci.yml` Step 2 (Verify Layer 1-10 function presence) was
  silently no-op**. The pre-fix revision used
  `grep -q PATTERN file && echo "✅"`, which is exempt from
  `set -e` in bash. Fixed with a `_check_required` helper that
  emits `::error::` and `exit 1` on any missing pattern.

- **`ci.yml` Step 4 (Verify v1.2.0 docs referenced)** had the
  same defect. Fixed.

- **`ci.yml` Step 10 (Verify reserved-port constant sync)** — the
  accepted-fallback `case` pattern was missing the trailing `"`,
  so it failed on every script that used the accepted pattern.
  Fixed by adding the trailing quote.

- **`release-patch.sh` leading-zero bug** — `$((CUR_PATCH + 1))`
  under `set -e` on a version like `v1.5.08` produces
  `bash: 08: value too great for base`. Fixed with a
  `strip_leading_zeros()` helper.

- **`release-patch.sh` PATCH bump string comparison** —
  `[ "$NEW_PATCH" != "$EXPECTED_PATCH" ]` rejected `"09"` against
  `"9"`. Fixed by switching to numeric comparison (`-ne`).

- **`web/dashboard.html` scrollend feature detection** — the
  pre-fix check `'onscrollend' in document` always returned
  `false`. Fixed to `'onscrollend' in window`.

- **`update.json` had `releaseDate != x-note-last-updated`**. Fixed
  by synchronizing both to `2026-10-13`.

- **`update.json` was missing `x-note-v150`**. Fixed by adding it.

#### Documentation corrections

The following documentation-accuracy corrections were applied
across the project. None advances the Audit Corrections Registry
(still **#33**).

- **`CHANGELOG.md` (this file)** — `watchdog.sh` line count
  corrected from **1,356** to **1,326** in the canonical Line
  counts table.

- **`docs/ARCHITECTURE.md`** — file-count corrections:
  - Repository file counts: **90 → 97 tracked**, **+4 → +7**
    added in v1.5.0, `proxy/` count set to **18**, `docs/`
    count set to **19**.
  - `docs/adr/0008-layered-bootstrap.md` and
    `docs/MANIFEST_NOTES.md` added to the tree.
  - `install_app.sh` line count consolidated to **1,101**.
  - §5.8.4 trap snippet corrected.
  - §4.1 table backticks corrected.
  - All `MAN-TRIM-CHANGELOG` references removed.

- **`docs/SECURITY.md`** — encoding and content corrections:
  - The file's entire encoding was restored to clean UTF-8.
  - §5.36.3 corrected — the trap **does** remove the staged APK.
  - §5.36.4 corrected — Play Protect duration is bounded by the
    75-second cascade deadline.
  - §12.1 corrected — `install_app.sh` is covered by the module
    ZIP's SHA-256.
  - §13.2 corrected — the staged-APK cleanup is resolved.
  - §14.34 corrected in eight places for BusyBox grep portability.
  - Header inventory consolidated into §18.

- **`docs/API.md`** — response-shape corrections:
  - §4.1 "three" response shapes corrected to **"four"**.
  - §4.2 "only exception" corrected to **"two exceptions"**.
  - §5.1 install-specific response shapes corrected.
  - §6.1.17 not-installed response corrected.
  - §6.2.14 / §6.2.15 corrected.
  - §1.1 timeout table expanded.
  - §13 added with the consolidated correction table.

- **`README.md`** — numeric and consistency corrections:
  - `proxy/` = 17 / 18 inconsistency unified to **18**.
  - Sub-list arithmetic corrected to sum to **97 tracked**.
  - `+4 tracked files` corrected to **+7**.
  - "survives... factory reset of `/data`" corrected.
  - "signed tag" corrected to **"annotated tag"**.
  - "PATCH requires manual back-merge" corrected.
  - Exit codes 130 and 143 added.
  - `install_app.sh` line count breakdown corrected.
  - `boot-mini.sh` added to the Project Structure tree.
  - `docs/MANIFEST_NOTES.md` added to the Documentation table.
  - **The entire file's encoding was restored to clean UTF-8**
    (mojibake from a prior Windows-1252 → UTF-8 cycle).

- **`web/manifest.json`** — `x-note-companion-apk` file-count
  claim corrected to **97 tracked + 0-11 artifacts (97-108)**.

- **`web/sw.js`** — 4 companion endpoints re-attributed to
  **v1.5.0** (were implicitly v1.4.0).

- **`.shellcheckrc`** — the `SC-VERIFY-01` correction removed the
  inaccurate "last-wins" claim about `disable=` directives and
  replaced it with "merge (union)" semantics.

- **`.gitattributes`** — 4 fixes:
  - `VERSION merge=union` → **`merge=binary`** (union would
    produce a two-line corrupt file).
  - `*.sh diff=shell` → **`diff=bash`** (shell is not a built-in
    diff driver).
  - `go.sum text eol=lf` duplicate removed.
  - `web/app-debug.apk` duplicate lines merged.

- **`.editorconfig`** — removed the arbitrary
  `[.gitattributes] insert_final_newline = false` section.

- **`.pre-commit-config.yaml`, `.gitignore`, `.gitattributes`,
  `.editorconfig`** — version bumped from v1.4.0 to v1.5.0.

- **`codeql.yml`** — prose correction: the "9 shell scripts"
  wording corrected to **10**.

### Removed

- **iOS PWA logic** was already removed in v1.4.0. No further
  browser-specific logic was removed in v1.5.0.
- **7 `x-note-*` fields** were removed from `web/manifest.json`
  and relocated to `docs/MANIFEST_NOTES.md`. The fields themselves
  are preserved; only their location changed.
- No features were removed. All v1.0.0 through v1.4.0 APIs,
  endpoints, and config formats remain functional.

### Deprecated

Nothing in this release.

### Security

- **No new audit corrections.** The Audit Corrections Registry
  remains at **#33** (last entry from v1.0.0). v1.5.0 is a
  feature release.

- **Companion install security model** is documented in
  `docs/SECURITY.md` §5.36, with nine subsections covering the
  one-shot CSRF token, the per-IP rate limit, SELinux staging,
  Play Protect trap semantics, the 3 package-name candidates, the
  "failure is 200" design, and the SHA256 advisory verification.

- **All security fixes from v1.0.0 through v1.4.0 remain in
  place**, including the watchdog token, the CodeQL
  `go/path-injection` hardening, the login POST-only enforcement,
  and the 60-second auth cache.

- **Additional protections added in v1.5.0**:
  - One-shot CSRF token on `POST /api/install_companion_app`
    (60 s TTL, single use, constant-time comparison).
  - Per-IP install rate limit (5 failed attempts / 15 min
    lockout), separate from `loginAttempts`.
  - SELinux staging — `setenforce 0` is **never** called.
  - Play Protect temporary disable + trap restore with a
    75 s cascade deadline.
  - `shellQuote()` on all paths in `install_app.sh`.
  - `getSystemShell()` used by `callInstallScript()`.
  - Three-way signal trap with exit codes 130 (SIGINT) and
    143 (SIGTERM) — CIA-DEF-03.
  - Logger three-layer split — eliminates a latent deadlock on
    log-rotation failure (MAIN-REENT-01).
  - The `install_token` endpoint is now **localhost-only**.

### Breaking Changes

**None.** v1.5.0 is fully backward compatible with v1.4.0:

- All existing API endpoints work with the same paths, methods,
  and auth.
- All existing config files (`webui.conf`, `dnscrypt-proxy.toml`)
  keep the same format.
- All existing shell script CLI flags work the same way.
- All previously-issued v1.4.0 tokens and cookies remain valid.
- The 7-field `runtime_info.backups` object is unchanged.
- The watchdog token model is unchanged.

**Additive only**:

- 4 new HTTP endpoints under `/api/*`.
- 2 new shell scripts (`proxy/boot-mini.sh`, `proxy/install_app.sh`).
- 1 new optional directory (`$PERSISTENT_BACKUP/apk/`).
- 1 new optional file (`web/app-debug.apk.sha256`).
- 1 new documentation file (`docs/MANIFEST_NOTES.md`).

The Service Worker's bypass rule 2 (`/api/*`) already covers all
four new endpoints — no Service Worker change was required for
v1.5.0.

### Notes

#### Companion app install flow

The WebUI install button opens an **install-method modal**
(IDX-24) offering **three actions across two categories**:

| Category | Action | Requires | Notes |
|---|---|---|---|
| **Local** | **Install locally** | Root; APK present in module ZIP | Runs `install_app.sh` — 5-level `pm install` cascade |
| **GitHub** | **Open GitHub page** | Internet | External URL |
| **GitHub** | **Direct download from GitHub** | Internet | External URL |

The local install path requires:

1. A valid session (or Bearer/Basic).
2. A localhost request.
3. A one-shot CSRF token from `GET /api?action=install_token`.
4. `isInstallLockedOut(ip)` to be false.

On failure, the WebUI offers a **"⬇️ Download manually"** button
that navigates to `/app-debug.apk`.

#### Line counts (verified 2026-10-13)

The following line counts are **canonical**, verified with
`wc -l` on the v1.5.0 working tree:

| File | Lines |
|---|---:|
| `proxy/main.go` | 5,519 |
| `proxy/install_app.sh` | 935 |
| `proxy/customize.sh` | 2,718 |
| `proxy/functions.sh` | 2,059 |
| `proxy/uninstall.sh` | 1,387 |
| `proxy/watchdog.sh` | **1,090** |
| `scripts/package_module.sh` | 972 |

These values supersede any earlier figure in
`docs/ARCHITECTURE.md`, `README.md`, `docs/SECURITY.md`, or
`docs/API.md`. The `watchdog.sh` entry was corrected from
**1,356** to **1,326** in the post-release patch cycle.

#### Version Files — Where to Update

At each release, the version string appears in:

| File | Field | v1.5.0 value |
|---|---|---|
| `VERSION` | entire file | `v1.5.0` |
| `module.prop` | `version=` | `v1.5.0` |
| `module.prop` | `versionCode=` | `1050000` |
| `update.json` | `.version` | `v1.5.0` |
| `update.json` | `.versionCode` | `1050000` |
| `update.json` | `.versionName` | `v1.5.0 (Global Edition)` |
| `update.json` | `.releaseDate` | `2026-10-13` |
| `update.json` | `.zipUrl` | `.../download/v1.5.0/dnscrypt-webui-1.5.0-module.zip` |
| `update.json` | `."x-note-last-updated"` | `2026-10-13` |
| `web/manifest.json` | `.version` | `1.5.0` (no `v`) |
| `web/sw.js` | `CACHE_VERSION` | `v1.5.0` |
| `web/index.html` | `var VERSION` | `v1.5.0` |
| `web/dashboard.html` | `var VERSION` | `v1.5.0` |
| `web/offline.html` | `var VERSION` | `v1.5.0` |
| `proxy/main.go` | `BuildVersion` (runtime) | injected via `-X` at build time |
| `proxy/install_app.sh` | `SCRIPT_VERSION` | `v1.5.0` |
| `proxy/app-apk.version` | entire file | `1.0.0` (companion app, no `v`) |
| `proxy/dnscrypt-proxy.version` | entire file | `2.1.18` (DNS engine, no `v`) |

`scripts/release.sh` updates the first nine automatically. The
remaining entries must be updated manually if they reference the
version.

#### File count model — three canonical states

The repository has three reproducible states, verified with
`git ls-files | wc -l` and `find . -type f | wc -l`:

| State | When | Tracked | Artifacts | Working tree | Dirs |
|---|---|:---:|:---:|:---:|:---:|
| **Fresh clone** | After `git clone` | 97 | 0 | 97 | 15 |
| **After package** | After `make fetch-apk && make package` | 97 | 4 | 101 | 17 |
| **After full build** | After `make build` | 97 | 11 | 108 | 18 |

The **tracked count (97)** is fixed and canonical — it is what
GitHub sees. The **artifact count (0–11)** depends on which build
steps have been run locally.

**The 7 tracked files added in v1.5.0** are:

- `.shellcheckrc`
- `.github/codeql/codeql-config.yml`
- `docs/adr/0007-external-dependency-securejoin.md`
- `docs/adr/0008-layered-bootstrap.md`
- `docs/MANIFEST_NOTES.md`
- `proxy/boot-mini.sh`
- `proxy/go.sum`

#### Audit Corrections Registry — Unchanged

v1.5.0 does **not** extend the Audit Corrections Registry. The
last entry is #33 (from v1.0.0). The registry is a flat, monotonic
sequence that advances only when a new audit correction is filed.

The v1.5.0 additions — 4 endpoints, 2 new shell scripts, 12
frontend state fixes, 9 server-side code-review corrections, and
13 documentation-correction categories — are documented as feature
additions and code-review polish, not as audit corrections.

#### What is Preserved (unchanged)

The 5 user config files preserved by the 10 defensive layers
(introduced in v1.2.0):

| File | Purpose |
|---|---|
| `webui.conf` | WebUI + Dashboard ports, `BIND_ADDR`, `LOG_LEVEL` |
| `dnscrypt-proxy.toml` | DNSCrypt engine config + credentials |
| `selected_profile.txt` | Active blocklist profile |
| `allowlist.txt` | User-defined allowlist |
| `denylist.txt` | User-defined denylist |

#### Companion APK — Git tracking and caching

- **Not tracked by git**: `web/app-debug.apk` and
  `web/app-debug.apk.sha256` are build artifacts.
- **Not precached by the Service Worker**: the path
  `/app-debug.apk` is listed in `shouldBypass()` (rule 9).
- **Mirrored (best-effort)**: `customize.sh §[10c]` mirrors the
  APK + `.sha256` to `/sdcard/dnscrypt-webui-backup/apk/`.

#### Companion app — optional by design

The APK is treated as a best-effort asset throughout the pipeline:

| Stage | Behaviour if missing |
|---|---|
| `scripts/fetch_app_apk.sh` | exits 0 on cache hit, exits 1 on `--offline` + no cache |
| `release.yml` Fetch step | logs `::warning::` — release continues |
| `release.yml` Stage step | logs `::warning::` — packaging continues |
| `scripts/package_module.sh` | logs warning — ZIP built without APK |
| `customize.sh §[10c]` | skips mirror silently |
| `proxy/main.go` route | returns 404 for `/app-debug.apk` |
| `install_app.sh` | exits with `reason=apk_not_found` |
| WebUI install button | click offers a "Download manually" fallback |

#### Not Included

The following items were considered and intentionally **not**
added in v1.5.0. See [`docs/ROADMAP.md`](docs/ROADMAP.md) for
the current plan.

- **CSP `'unsafe-inline'` removal**.
- **PWA port unification (9090 + 9091 → single port)**.
- **Dedicated maskable icon (`icon-maskable.svg` / `.png`)**.
- **Backup integrity enforcing mode**.
- **WebUI using `append_denylist` with `content`**.
- **Data Guardian badge tooling**.
- **Companion app deep-links (`dnsproxy://` scheme)**.
- **Companion app version bump automation**.
- **Extended multi-language support (FR, DE, ES, RU, ZH)**.
- **2FA + Audit Logging**.
- **JWT authentication alternative to cookies**.

---

## [v1.4.0] - 2026-10-06

**Integration release** — companion Android app + CodeQL cleanup
+ iOS removal + `LOG_LEVEL` startup-order fix.

### Added

- **Companion Android app integration** — a signed APK from the
  sister repository
  [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)
  is now bundled into the module ZIP as `web/app-debug.apk`
  (OPTIONAL — the build succeeds without it).
  - `proxy/app-apk.version` — Single Source of Truth for the app
    version (currently `1.0.0`, no `v` prefix).
  - `scripts/fetch_app_apk.sh` — new fetcher (cache, download,
    SHA256, `.manifest.json`, JSON output, offline mode,
    `--version` override).
  - `GET /app-debug.apk` — new static route in `proxy/main.go`.
  - **WebUI install button** — converted from a JavaScript modal
    (`beforeinstallprompt`) to a direct `<a download>` link.
  - **Module ZIP** — `scripts/package_module.sh` now bundles
    `web/app-debug.apk` when present.
- **CI/CD integration** — the release pipeline fetches the APK
  into `dist/`, stages it at `web/app-debug.apk`, and attaches
  `dist/DNS-Proxy-v*.apk` + `.sha256` to the GitHub Release.
- **Makefile targets** — `make fetch-apk` and
  `make check-app-version`.

### Changed

- **Version bump across all metadata** — `VERSION` (`v1.3.0` to
  `v1.4.0`), `module.prop` (`versionCode=1040000`), `update.json`,
  `web/index.html`, `proxy/main.go` header.
- **`proxy/main.go`** — new `APK_FILE` constant +
  `serveStaticAssets` entry for `/app-debug.apk`.
- **`web/index.html`** — install button is now
  `<a id="pwaInstallBtn" href="/app-debug.apk" download="DNS-Proxy.apk">`.
- **`scripts/package_module.sh`** — `WEB_FILES_REQUIRED` and
  `REQUIRED_IN_ZIP` now include `app-debug.apk` with an
  OPTIONAL-handling branch.
- **`web/dashboard.html`** — version updated from `v1.3.0` to
  `v1.4.0`.

### Fixed

- **MAIN-01 — `LOG_LEVEL` loaded too late in `main()`**. The call
  now happens **immediately after `initPaths()`**, before any
  other log-emitting call.
- **CodeQL `go/path-injection` in `removeModule`** — two alerts
  (#1, #2) closed by routing the caller-provided path through
  `filepath.Base()` and rebuilding the final path from
  `MODULES_DIR` + the sanitized basename, using
  `securejoin.SecureJoin`.

### Removed

- **iOS PWA logic** (`web/index.html`) — Android-only project.
  Roughly 35 lines removed.
- **Note**: `web/apple-touch-icon.png` is **retained** — it is
  used by Android launchers as an icon fallback and by the
  `manifest.json` icons array.

### Security

- **No new audit corrections.** The Audit Corrections Registry
  remains at **#33**.
- **CodeQL status** — 6 of 8 alerts closed in v1.3.0, remaining 2
  (`go/path-injection` in `removeModule`) closed in this release.

### Breaking Changes

**None.**

### Notes

#### Companion APK — git tracking and caching

- **Not tracked by git**: `web/app-debug.apk` is a build artifact.
  See `.gitignore` §[20]. The repository at v1.4.0 contained
  **90 tracked files** + 1 build artifact (91 in the working tree
  after a release build).
- **Not precached by the Service Worker**: `/app-debug.apk` is
  listed in `shouldBypass()` (rule 9).

#### Version Files — Where to Update

| File | Field | v1.4.0 value |
|---|---|---|
| `VERSION` | entire file | `v1.4.0` |
| `module.prop` | `version=` | `v1.4.0` |
| `module.prop` | `versionCode=` | `1040000` |
| `update.json` | `.version` | `v1.4.0` |
| `update.json` | `.versionCode` | `1040000` |
| `update.json` | `.releaseDate` | `2026-10-06` |
| `web/manifest.json` | `.version` | `1.4.0` (no `v`) |
| `web/sw.js` | `CACHE_VERSION` | `v1.4.0` |
| `web/index.html` | `var VERSION` | `v1.4.0` |
| `web/dashboard.html` | `var VERSION` | `v1.4.0` |
| `proxy/main.go` | `BuildVersion` | `v1.4.0` |
| `proxy/app-apk.version` | entire file | `1.0.0` (companion app, no `v`) |

---

## [v1.3.0] - 2026-10-02

**Feature release + server-side refinements** — PWA install
button, live status LED, boot-path DNS auto-start, and two
previously undocumented server-side refinements in `main.go`
and `functions.sh`.

### Added

- **PWA install button (WebUI)** — smart, dynamic install button
  that adapts to the browser (Chromium / iOS Safari /
  unsupported). The modal is fully language-aware (EN + AR).
  **Note**: this `beforeinstallprompt` chain was **removed in
  v1.4.0** in favour of a direct `<a download>` link.
- **Live status LED on the Today counter (WebUI)** — a 12×12 LED
  that pulses green when the DNS engine is running and turns
  solid red when the service is stopped.
- **SNAP-MANIFEST — manifest-based snapshot detection**
  (`proxy/main.go:buildBackupInfo()`).
- **SNAP-MTIME — mtime sort for `last_backup_name`**
  (`proxy/main.go:buildBackupInfo()`).

### Changed

- **Version bump across all metadata** — `VERSION`,
  `module.prop` (`version` + `versionCode=1030000`),
  `update.json`, `web/sw.js`, `web/manifest.json`, the two SVG
  icons.
- **`proxy/functions.sh:rotate_backups()` — rotation rewrite**
  (ROT-MANIFEST, ROT-MTIME, ROT-PROTECT).
- **`proxy/service.sh`** — boot-path DNS auto-start via direct
  API call.

### Fixed

- **`service.sh` — DNS auto-start after boot**. Root cause:
  `watchdog.sh` waits a fixed 30-second interval before its first
  API call, and by the time it fires
  `POST /api/ensure_running_service`, the WebUI may not have
  finished binding to its port. Fixed by having `service.sh`
  perform a direct, bounded wait (up to 60 s) then call the API
  itself with the `X-Watchdog-Token` header.

### Security

- **No new audit corrections.** The Audit Corrections Registry
  remains at **#33**.

### Breaking Changes

**None.**

### Notes

#### Reversed Decisions

| Original Decision | Reversal | Rationale |
|---|---|---|
| v1.2.0 BUG-3: `buildBackupInfo` sorts by directory **name** | v1.3.0 SNAP-MTIME: sorts by **mtime** | Robustness against clock drift and manual renames; alignment with `status.sh --json`. |
| v1.2.0 `rotate_backups`: name-pattern detection, name sort | v1.3.0 ROT-MANIFEST + ROT-MTIME + ROT-PROTECT | Same rationale, plus explicit protection of `.last_stable` and the newest install snapshot. |

---

## [v1.2.0] - 2026-09-29

**Data-preservation release** — the biggest reliability
improvement since v1.0.0.

### 📊 Overview

| Metric | Value |
|--------|:-----:|
| Total Audit Corrections | 33 (unchanged from v1.0.0) |
| Defensive layers | **10** |
| Runtime additions | **4** (BAK-1..BAK-4) |
| Correctness fixes | **2** (FIX-1, FIX-2) |
| Test scenarios (CI matrix) | **42** (`upgrade-test.yml`) |

### ✨ Highlights

- **10 defensive layers** for user-data preservation — replaces
  the fragile "detect upgrade?" heuristic with a "search
  everywhere" philosophy. Fixes a **silent data-loss bug** in
  v1.1.0 that erased the 5 user config files on every in-place
  upgrade.
- **Persistent backup directory** at
  `/sdcard/dnscrypt-webui-backup/` — survives reboot and module
  uninstall.
- **Transactional upgrades** with automatic rollback.
- **Recovery mode** — a trigger file restores the last known-good
  config on the next boot.
- **Bilingual WebUI** (English default + Arabic toggle).
- **7-field `runtime_info.backups`** object.
- **Watchdog token** (`X-Watchdog-Token`) — closes a CSRF hole on
  `POST /api/ensure_running_service`.

### Added

#### Backend (Go)

- `createAutoBackup(reason string)`
- `backupMu sync.Mutex`
- `cleanupOldTransactions()`
- `checkPendingNotifications()`
- `buildBackupInfo()` (7-field `backups` object)
- `loadOrCreateWatchdogToken()`
- `verifyWatchdogToken()`
- `runShellWithTimeout(cmd, timeout)`

#### Shell Scripts

- `functions.sh:backup_user_files`, `restore_user_files`,
  `rotate_backups`, `auto_backup_if_needed`,
  `cleanup_old_transactions`, `copy_with_context`,
  `verify_backup_integrity`, `write_manifest`,
  `get_watchdog_token`.
- `customize.sh` — 10 defensive layers.
- `customize.sh §[19b]` — pre-generate watchdog token.
- `customize.sh §[8a]/§[9]/§[9b2]` — snapshot-and-reapply for
  recovery mode (FIX-1).
- `status.sh --diagnose`, `status.sh --json`, `action.sh --backup`,
  `action.sh --diagnose`.

#### Frontend (PWA)

- Bilingual WebUI (`web/index.html`, `web/dashboard.html`,
  `web/offline.html`).
- System Info panel now displays 6 backup fields.

#### CI/CD

- `ci.yml` — new `backup-smoke-test` job.
- `upgrade-test.yml` — new **42-scenario matrix**.

#### Documentation

- `docs/BACKUP.md` — new file.
- `docs/EMERGENCY.md` — new file.

### Fixed

- **Silent data-loss bug in v1.1.0** — the installer used a
  path-comparison check that always failed on in-place upgrades.
  Fixed by the 10 defensive layers.
- **FIX-1 — Recovery-mode correctness** — snapshot-and-reapply
  strategy.
- **FIX-2 — Service Worker update-banner** — send
  `SKIP_WAITING` to `swRegistration.waiting`, reload on
  `controllerchange`.

### Security

- **No new audit corrections.** The registry remains at **#33**.
- **Watchdog token** — closes a CSRF hole on
  `POST /api/ensure_running_service`.

### Breaking Changes

**None.**

The pre-v1.2.0 `POST /api/append_denylist` endpoint already
accepted a `content` parameter. v1.2.0 did **not** make it
mandatory — it documented the parameter as **required** in the
error response body and added the same requirement to the
WebUI. This is a documentation-tightening change, not a
contract change: existing clients that already sent `content`
are unaffected.

### Notes

#### What is Preserved

The 5 user config files protected by the 10 defensive layers:

| File | Purpose |
|---|---|
| `webui.conf` | WebUI + Dashboard ports, `BIND_ADDR`, `LOG_LEVEL` |
| `dnscrypt-proxy.toml` | DNSCrypt engine config + credentials |
| `selected_profile.txt` | Active blocklist profile |
| `allowlist.txt` | User-defined allowlist |
| `denylist.txt` | User-defined denylist |

#### v1.2.0 Post-Audit Corrections

Twelve corrections applied to `main.go` after the initial v1.2.0
release. All are catalogued in `docs/SECURITY.md` §17.3 under
the `BUG-A..BUG-L` identifiers, and in
`docs/ARCHITECTURE.md` §4.6.3.

---

## [v1.1.0] - 2026-09-26

**Polish Release** — documentation + three runtime
improvements.

### 📊 Overview

| Metric | Value |
|--------|:-----:|
| Total Audit Corrections | 33 (unchanged from v1.0.0) |
| Runtime improvements | **3** (MEM-1, MEM-2, MEM-3) |
| New `runtime_info` fields | **2** (`profile_key`, `memory_limit_mb`) |

### ✨ Highlights

- **Dynamic memory limit per profile (MEM-1)** —
  `debug.SetMemoryLimit` set per active blocklist profile.
- **Extended `shellQuote` charset (MEM-2)** — adds `{`, `}`,
  `\n`, `\t`.
- **`MONITORING_UI_PORT` constant (MEM-3)**.
- **`offline.html` CSP fix** — removed the restrictive CSP meta
  that silently blocked the offline page's own scripts.

### Added

- `memoryLimitForProfile(key string) int64`
- `applyMemoryLimit(key string)`
- `readSelectedProfile() string`
- `memLimitMu sync.Mutex` + `currentMemLimit int64` +
  `currentProfile string`
- `runtime_info` new fields: `profile_key`, `memory_limit_mb`.
- `functions.sh:get_profile_memory_hint()`.
- Dev workflow infrastructure: `docs/BRANCHING.md`,
  `docs/RELEASE_PROCESS.md`, `scripts/release.sh`,
  `scripts/release-patch.sh`, ADRs 0001–0006,
  `.github/PULL_REQUEST_TEMPLATE/release.md`.

### Fixed

- **`web/offline.html`** — removed the restrictive CSP meta.
- **`proxy/customize.sh`** — port collision fix.
- **`web/sw.js`** — removed the misleading comment claiming
  `CACHE_VERSION` was "updated automatically by
  sync_versions.sh".

### Security

- **No new audit corrections.** The registry remains at **#33**.
- **MEM-1, MEM-2, MEM-3** documented as runtime improvements.

### Breaking Changes

**None.**

---

## [v1.0.0] - 2026-09-24

**First Stable Release** — initial public release of DNSCrypt
Smart Filter.

### 📊 Overview

| Metric | Value |
|--------|:-----:|
| Total Audit Corrections | **33** |
| Supported architectures | **4** (arm64, arm, amd64, 386) |
| Documentation files | **14** (in `docs/`) |
| Shell scripts | **8** (in `proxy/`) |
| Build scripts | **3** (in `scripts/`) |
| Web/PWA files | **13** (in `web/`) |
| Tracked files | **86** |

### ✨ Highlights

#### Security

- Login POST-only (CSRF protection)
- `/readyz` localhost-only
- `shellQuote()` shell injection protection
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
- SSE live updates
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

### Added

#### Backend (Go)

- HTTP API — full REST API for WebUI and Dashboard.
- `/healthz`, `/readyz`, `/api/metrics`, `/events`.
- `runtime_info` endpoint — build info + actual ports (PORT-2).
- `hasEndpoint()` — exact path matching.
- `getSystemShell()` — platform-agnostic shell detection.
- `shellQuote()` — shell injection protection.
- `readConfPort()` — port range check `[1, 65535]`.
- `rebuildMu` — `sync.Mutex` serializing `rebuildBlocklist`.
- Auth cache (60 s).
- Per-port cache.
- Session GC (every 30 min).
- SSE Write Deadline (30 s).

#### Frontend (PWA)

- Bilingual WebUI (English + Arabic).
- Monitoring Dashboard with JSON metrics.
- Service Worker (`sw.js`).
- Offline fallback page.
- PWA manifest with shortcuts, icons, and meta notes.
- SVG + PNG + ICO icons.
- Edit mode FSM (VIEW / EDIT / ROLLBACK).
- Draft auto-save (1-hour retention).
- Content-hash conflict detection (409 responses).
- Dynamic port links.

#### Shell Scripts

- `customize.sh`, `service.sh`, `post-fs-data.sh`,
  `watchdog.sh`, `action.sh`, `status.sh`, `uninstall.sh`,
  `functions.sh`, `build.sh`.

#### Build & Packaging

- `scripts/fetch_dns_binaries.sh` — DNS binaries fetcher.
- `scripts/package_module.sh` — Magisk ZIP builder.
- `scripts/generate-icons.sh` — PNG + ICO from SVG.

#### CI/CD

- `.github/workflows/ci.yml` — build matrix for 4 architectures.
- `.github/workflows/release.yml` — annotated-tag release.
- `.github/workflows/codeql.yml` — SAST.
- `.github/dependabot.yml`.
- `.pre-commit-config.yaml`.

#### Documentation

- 14 comprehensive documentation files in `docs/`.
- Root `README.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `LICENSE`, `CHANGELOG.md`.

### Fixed

All 33 Audit Corrections were applied in v1.0.0. See the
**Legend** section below for the complete cross-reference
table.

### Security

**33 Audit Corrections applied.** The full registry lives in
`docs/SECURITY.md` §17.

### Breaking Changes

N/A — first stable release.

### Known Issues

| Issue | Priority | Target |
|-------|:--------:|:------:|
| CSP `'unsafe-inline'` in `script-src` | 🟡 Medium | Deferred |
| `pgrep -x` may not work on Android 5.x | 🟢 Low | Deferred |
| `awk` parser may fail with `]` in comment | 🟢 Low | Deferred |
| PWA dual-origin limitation (9090 vs 9091) | 🟡 Medium | Deferred |
| `manifest.json` shortcuts do not read `runtime_info` | 🟢 Low | Deferred |
| Dashboard does not show `bind_addr` | 🟢 Low | Deferred |

---

## 📖 Legend — Correction & Identifier Reference

This section is the **single consolidated reference** for every
correction, identifier, and non-audit addition mentioned in
this CHANGELOG.

### How to read the registry

The **Audit Corrections Registry** is defined in
`docs/SECURITY.md` §17. It is a flat, monotonic sequence of
numbered fixes filed against the v1.0.0 tree. Entries #1–#33
were all filed in v1.0.0. No new entry has been filed since.

Two conventions apply:

- **Row format** — each row is a numbered audit correction.
- **Slash notation** — a row like `#3-e/f` or `#16-a/b` contains
  **two** logical fixes (e.g. `#16-a` = IPv4 side, `#16-b` =
  IPv6 side). The slash form is shorthand for the two.

### Count reconciliation

Two different figures appear in this file and in
`docs/SECURITY.md`:

| Figure | Meaning |
|---|---|
| **#33** | The **highest audit-correction ID** ever assigned. This is the "identifier ceiling". |
| **32** | The **count of logical fixes** actually catalogued (see below). |

**Arithmetic**:

| Source | Count |
|---|---|
| Physical rows in the registry table | **29** |
| Rows with slash-notation (2 fixes each): `#3-e/f`, `#9/#9-b`, `#16-a/b` | **+3** extra |
| **Total logical fixes catalogued** | **32** |
| **Highest audit-correction ID** | **33** |

### Gaps in the ID sequence

The following IDs were **assigned during the v1.0.0 audit
cycle** but do not appear as standalone rows in the registry
table:

| ID | Status |
|:-:|---|
| **#2** | Absorbed into #1 during a post-audit consolidation pass |
| **#4** | Absorbed into #3-e/f during the same pass |
| **#8** | Documented as "Fix #8" in `docs/SECURITY.md` §5.18 and `docs/API.md` §3.3 — same subject as #22 (Basic Auth rate limit) |
| **#11** | Documented as "Fix #11" in `docs/SECURITY.md` §4.8.10 — same subject as #29 (per-port cache) |
| **#12** | Documented as "Fix #12" in `docs/SECURITY.md` §4.8.11 and `docs/API.md` §7.1 — same subject as #24 (exact endpoint matching) |

The **#33 ceiling** is retained as the historical identifier
anchor in `docs/SECURITY.md` §17 and across every sibling
document (`docs/ARCHITECTURE.md`, `docs/API.md`,
`docs/SECURITY.md`). The **32 logical fixes** are the actual
count. The **gaps #2, #4, #8, #11, #12** are historical
artifacts of the pre-consolidation numbering scheme.

No audit correction has been filed since v1.0.0. New entries
will resume at **#34** (the next identifier after the current
ceiling) in a future release.

The v1.5.0 additions — 4 endpoints, 2 new shell scripts, 12
frontend state fixes, 9 server-side code-review corrections —
are **not** audit corrections. They are documented as feature
additions and code-review polish.

### Audit Corrections (#1 – #33)

Applied in v1.0.0. The `#33` identifier is the highest ID; the
catalogue contains **32 logical fixes** (see the reconciliation
tables above).

| # | Description | Reference |
|:-:|---|---|
| #1 | Fixed typo in `isAllowedLogFile` | — |
| #3-e/f | Dynamic `bootstrap_resolvers` + IPv6 | SECURITY.md §5.9 |
| #5 | Cleanup of old `loginAttempts` | — |
| #6-c | `limitedBuffer` (bounded stderr capture) | — |
| #7 | Dead code removal from `functions.sh` | — |
| #9/#9-b | `os.CreateTemp` (no race) | — |
| #10 | Debounce SSE | — |
| #13 | CSRF-GET → POST-only | SECURITY.md §5.2 |
| #14 | `pgrep -x` (no false positives) | — |
| #15-a | Remove token from login response | SECURITY.md §5.11 |
| #15-b | `Allow: POST` header for 405 | SECURITY.md §5.12 |
| #16-a/b | IPv4/IPv6 firewall separation | SECURITY.md §5.9 |
| #17 | Custom Chains (Orphan Fix) | SECURITY.md §5.13 |
| #18 | STATUS_FILE Semantics | SECURITY.md §5.14 |
| #19 | IPv6 Rate Limit Bypass | SECURITY.md §5.15 |
| #20 | Port Collision 8080 | SECURITY.md §5.16 |
| #21 | Section-Restricted TOML | SECURITY.md §5.17 |
| #22 | Basic Auth Rate Limit Bypass | SECURITY.md §5.18 |
| #23 | Section header with comment (parsing) | SECURITY.md §5.19 |
| #24 | Exact endpoint matching | SECURITY.md §5.20 |
| #25 | Dashboard JSON Conversion | SECURITY.md §5.20 |
| #26 | Preserve User Settings on Upgrade | SECURITY.md §5.21 |
| #27 | `fuser` PID parsing | SECURITY.md §5.22 |
| #28 | Login POST-only (CSRF) | SECURITY.md §5.23 |
| #29 | `readConfPort` range check | SECURITY.md §5.24 |
| #30 | `/readyz` localhost-only | SECURITY.md §5.25 |
| #31 | `shellQuote` injection protection | SECURITY.md §5.26 |
| #32 | `rebuildMu` mutex (RACE-1) | SECURITY.md §5.28 |
| #33 | `runtime_info` dynamic ports (PORT-2) | SECURITY.md §5.29 |

**Last applied**: #33 (v1.0.0)
**Next expected**: **#34** (in a future release)

### v1.1.0 Runtime Improvements (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| MEM-1 | Dynamic memory limit per profile | Closes a self-inflicted DoS surface |
| MEM-2 | Extended `shellQuote` charset | Defense in depth; no known exploit |
| MEM-3 | `MONITORING_UI_PORT` in metrics handler | Single source of truth |

### v1.2.0 Runtime Additions & Correctness Fixes (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| BAK-1 | 7-field `runtime_info.backups` | Observability of the backup layer |
| BAK-2 | `createAutoBackup` + `backupMu` + rotation | Pre-critical backup before 5 destructive endpoints |
| BAK-3 | `cleanupOldTransactions` | Removes leftover `COMMIT`'d `txn-*` dirs at startup |
| BAK-4 | `checkPendingNotifications` | Reads `.pending_notification` at startup |
| FIX-1 | Recovery-mode snapshot-and-reapply | Correctness fix |
| FIX-2 | Service Worker update-banner | Correctness fix |
| WD-TOKEN | Watchdog token | Closes a CSRF hole on `ensure_running_service` |
| BUG-A..L | `main.go` post-audit corrections | See `docs/SECURITY.md` §17.3 |

### v1.3.0 Feature & Correctness Additions (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| PWA-BTN | Dynamic PWA install button | Feature (client-side) |
| LED | Live status LED on Today counter | Feature (client-side) |
| DNS-AUTOSTART | DNS auto-start after boot via direct API call | Correctness fix |
| SNAP-MANIFEST | `buildBackupInfo` — manifest-based detection | Correctness fix |
| SNAP-MTIME | `buildBackupInfo` — mtime sort | Correctness fix |
| ROT-MANIFEST | `rotate_backups` — manifest-based detection | Correctness fix |
| ROT-MTIME | `rotate_backups` — mtime sort | Correctness fix |
| ROT-PROTECT | `rotate_backups` — preserve `.last_stable` + newest install | Correctness fix |

### v1.4.0 Integration Additions (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| APK-1 | `APK_FILE` + `serveStaticAssets` entry + per-extension Cache-Control | Feature |
| APK-2 | `/app-debug.apk` route | Feature |
| CQ-FIX | CodeQL `go/path-injection` fix in `removeModule` | Security hardening |
| IOS-REMOVE | iOS PWA logic removed | Cleanup |
| MAIN-01 | `LOG_LEVEL` loaded immediately after `initPaths()` | Correctness fix |

### v1.5.0 Additions (Not Audit Corrections)

The v1.5.0 release **does not extend the Audit Corrections
Registry**. The identifiers below are feature additions,
code-review corrections, and documentation-accuracy
corrections.

#### Backend — companion app install

| ID | Change | Reference |
|:-:|---|---|
| APK-3 | `COMPANION_PKG` constant (retained-for-documentation) | ARCHITECTURE.md §4.14.1 |
| APK-4 | `INSTALL_SCRIPT_REL` + `getInstallScript()` | ARCHITECTURE.md §4.14.1 |
| APK-5 | `POST /api/install_companion_app` handler | ARCHITECTURE.md §4.14.2 |
| APK-6 | `GET /api?action=companion_app_state` handler + 30 s cache | ARCHITECTURE.md §4.14.3 |
| APK-7 | `POST /api/uninstall_companion_app` handler | ARCHITECTURE.md §4.14.4 |
| APK-8 | `.sha256` sidecar bundling in `release.yml` | ARCHITECTURE.md §14.13 |
| APK-11 | Install timeouts + token TTL + rate limits | ARCHITECTURE.md §4.14.5 |
| APK-12 | Package name candidates | ARCHITECTURE.md §5.8.7 |

#### Shell — install_app.sh implementation

| ID | Change | Reference |
|:-:|---|---|
| CIA-1 | Pre-flight checks | ARCHITECTURE.md §5.8.2 |
| CIA-2..5 | 5-level `pm install` cascade | ARCHITECTURE.md §5.8.5 |
| CIA-6 | AR + EN error translation | ARCHITECTURE.md §5.8.8 |
| CIA-7 | Post-install version_name extraction | ARCHITECTURE.md §5.8.10 |
| CIA-8 | Single-line JSON output | ARCHITECTURE.md §5.8.9 |
| CIA-9 | Three modes (`--status` / `--uninstall` / install) | ARCHITECTURE.md §5.8.1 |
| CIA-10..16 | ShellCheck + robustness fixes | ARCHITECTURE.md §5.8.10 |
| CIA-DEF-03 | Three-way signal-trap split with exit 130/143 | ARCHITECTURE.md §5.8.3, SECURITY.md §5.36.3 |
| CIA-DEF-04 | `SC2015` + `SC2181` fixes | install_app.sh header |
| CIA-DEF-05 | `SC2329` suppression | install_app.sh header |

#### Frontend — companion install + state fixes

| ID | Change | Reference |
|:-:|---|---|
| IDX-23 | Companion button state survives language toggles | ARCHITECTURE.md §6.9 |
| IDX-23b | Status card updates instantly on language toggle | ARCHITECTURE.md §6.10 |
| IDX-24 | Install-method modal | ARCHITECTURE.md §3.11 |
| IDX-25 | Dashboard section-nav dead links fixed | ARCHITECTURE.md §6.11 |
| IDX-25a | Centered card-expand hint toast | ARCHITECTURE.md §6.12 |
| IDX-429 | Install rate-limit message rendered distinctly | ARCHITECTURE.md §6.9 |
| IDX-401-DISTINCT | Install-family 401 suppresses the session modal | ARCHITECTURE.md §6.9 |
| DASH-REFRESH-01 | `isRefreshing` reset on 401 | ARCHITECTURE.md §6.10 |
| DASH-SESSION-RETRY-01 | Session-expired primary action is a full reload | ARCHITECTURE.md §6.10 |
| DASH-HINT-01 | Card-expand hint uses dual timers | ARCHITECTURE.md §6.12 |
| DASH-HINT-02 | Card-expand hint scheduled via `scrollend` | ARCHITECTURE.md §6.12 |
| ICON-512-SAFEZONE-01 | Shield path fits W3C maskable safe circle | `web/icon-512.svg` header |
| SW-PRECACHE-01 | `PRECACHE_ASSETS` remains at 11 files (`/dashboard.html` deliberately NOT added) | `web/sw.js` header, MANIFEST_NOTES.md §9 |
| OFF-DEF-03 | Persistent auto-retry-stopped banner replaces transient toast | `web/offline.html` header |

#### Shell — v1.5.0 pre-release and post-release corrections

| ID | Change | Reference |
|:-:|---|---|
| CSH-20 | `customize.sh §[10c]` — mirror APK + `.sha256` | customize.sh header |
| CSH-21 | Version bump v1.4.0 → v1.5.0 | customize.sh header |
| CSH-22 | `install_app.sh` extraction fix | customize.sh header |
| V15-CODE-05 | 75-second cascade deadline | install_app.sh header |
| V15-CODE-06 | Cross-ref `§4.12.4` → `§4.14.1` | install_app.sh header |
| V15-CODE-07 | Trap restores `$_VERIFIER_ORIG` | install_app.sh header |

#### Backend — v1.5.0 code-review corrections

| ID | Change | Reference |
|:-:|---|---|
| V15-CODE-01 | `getCompanionState()` Phase-3 comment | main.go header |
| V15-CODE-02 | GC banner restructured | main.go header |
| V15-CODE-03 | `callInstallScript()` uses `getSystemShell()` | main.go header |
| V15-CODE-04 | `handleAPI()` panic logging | main.go header |
| V15-CODE-15 | `R3-01` doc-comment refreshed | main.go header |

#### v1.5.0+ post-release patches

| ID | Change | Reference |
|:-:|---|---|
| MAIN-REENT-01 | Logger three-layer split — eliminates a latent deadlock on rotation failure | ARCHITECTURE.md §4.6.8 |
| MAIN-PORTCACHE-01 | 30 s TTL cache for `getWebUIPort` / `getDashboardPort` | ARCHITECTURE.md §4.6.8 |
| MAIN-DEADLOCALHOST-01 | `isLocalRequest` dead-branch removal | ARCHITECTURE.md §4.6.8 |
| MAIN-APPENDHASH-01 | `appendDenylist` hash source aligned | ARCHITECTURE.md §4.6.8 |
| MAIN-CACHE-01 | Companion state cache invalidated unconditionally | ARCHITECTURE.md §4.14.7 |
| HTTP-WRITE-TIMEOUT | `HTTP_WRITE_TIMEOUT` raised to 150 s | ARCHITECTURE.md §11.57 |
| INSTALL-TOKEN-GATE | `install_token` endpoint gated to localhost | ARCHITECTURE.md §4.14.2 |

### Documentation Corrections (Per File)

Consolidated in each file's own section:

| File | Section | Purpose |
|---|---|---|
| `docs/ARCHITECTURE.md` | §17 | All `ARCH-*` corrections |
| `docs/SECURITY.md` | §18 | All `HARD-SEC-*` corrections |
| `docs/API.md` | §13 | All `API-*` corrections |
| `README.md` | Header | All `README-DOC-*` corrections + UTF-8 restoration |
| `CHANGELOG.md` | This file | `CHG-DOC-01`, `CHG-DATE-01`, count reconciliation |
| `docs/MANIFEST_NOTES.md` | — | New file (v1.5.0); canonical reference for extracted `x-note-*` fields |
| `.shellcheckrc` | Header | `SC-VERIFY-01`, `SC-DATE-02` |
| `.gitattributes` | Header | 4 fixes (VERSION merge, diff driver, duplicates) |
| `.editorconfig` | Header | `[.gitattributes]` section removed |
| `proxy/*.sh` | Header | `CSH-*`, `FSH-*`, `UNS-*`, `PM-*`, `GIC-*` |
| `web/*.html`, `web/sw.js` | Header | `SW-DOC-*`, `OFF-*`, `SW-PRECACHE-01` |
| `web/manifest.json` | `x-note-*` fields | `MAN-*` |
| `proxy/main.go` | Header | `MAIN-XREF-01` |

### Cross-file identifiers

The following identifiers are **cross-references** between
files, not corrections themselves:

| Identifier | File | Description |
|---|---|---|
| CHG-DOC-01 | `CHANGELOG.md` | `watchdog.sh` line count corrected 1,356 → 1,326 |
| ARCH-DOC-06 | `docs/ARCHITECTURE.md` | Repository file counts corrected (97 tracked / 18 proxy / 19 docs) |
| ARCH-DOC-07 | `docs/ARCHITECTURE.md` | `manifest.json` size updated to ~3 KB |
| ARCH-MANIFEST-01 | `docs/ARCHITECTURE.md` | `docs/MANIFEST_NOTES.md` added as authoritative reference |
| SW-DOC-02 | `web/sw.js` | Endpoint re-attribution (4 endpoints = v1.5.0, not v1.4.0) |
| README-DOC-02 | `README.md` | Per-directory count correction (97 tracked) |
| MAIN-XREF-01 | `proxy/main.go` | Documentation-only cross-reference block |
| API-XREF-01 | `docs/API.md` | Cross-reference block for the v1.5.0++ cycle |
| HARD-SEC-XREF-01 | `docs/SECURITY.md` | Cross-reference block for the v1.5.0++ cycle |
| MAN-NOTES-01 | `docs/MANIFEST_NOTES.md` | Canonical reference for extracted `x-note-*` fields |

### Retired identifiers

The following identifiers appeared in earlier revisions of
this CHANGELOG but are **no longer referenced**:

- **WD-V15-01..05** — earlier drafts described five
  documentation corrections in `watchdog.sh`'s header. Those
  identifiers do not exist in `watchdog.sh`. Removed.
- **MAN-TRIM-CHANGELOG** — described an earlier manifest
  trimming pass. The identifier was never defined in
  `web/manifest.json` or any other file. Removed.
- **1..20 (v1.0.0 Fixed table)** — replaced by the
  `#1..#33` Audit Corrections Registry from
  `docs/SECURITY.md` §17. The old short numbers were a
  parallel scheme that duplicated the registry.
- **ARCH-DOC-01**, **ARCH-DOC-03** — superseded by
  ARCH-DOC-05 (no-op edits).
- **ARCH-DATE-01** — superseded by ARCH-DATE-02.
- **ARCH-LEGEND-01**, **ARCH-REF-01** — Legend and
  References restructuring removed them.
- **API-V15-01..18** — consolidated into `docs/API.md` §13.2.
- **API-DATE** — the date bump is documented in the header.
- **API-XREF-01** — consolidated into `docs/API.md` §13.4.

---

## 🔗 Links

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
