# Roadmap — DNSCrypt Smart Filter

> What's coming next in DNSCrypt Smart Filter — a comprehensive
> vision for future releases.

**Current version**: v1.3.0
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.2.0 changes**:
>   • Current version bumped from v1.1.0 to v1.2.0.
>   • `Last updated` reflects the v1.2.0 release date.
>   • **New section**: "What Was Delivered in v1.2.0" (§4).
>     The v1.2.0 data-preservation release (10 defensive layers,
>     BAK-1..BAK-4, FIX-1/FIX-2) and documentation updates are
>     now recorded here.
>   • **v1.3.0 section renumbered** (§5) — now contains the
>     next planned release, with carried-over items from the
>     original v1.2.0 plan (CSP hardening, port unification,
>     memory tooling) plus new items (backup integrity hardening,
>     `append_denylist` content parameter for the WebUI).
>   • **v1.4.0 section** — new placeholder for the release that
>     will introduce the WebUI translations FR/DE/ES/RU/ZH
>     (carried from the original v1.3.0 plan).
>   • **v2.0.0 section renumbered** (§7) — the major rewrite.
>   • §10 Development Workflow Priorities updated: v1.2.0 status
>     reflected.
>   • §11 Timeline Summary updated to include v1.2.0.
>   • §12 (new) — v1.2.0 Data-Preservation Registry (10 layers +
>     BAK-1..BAK-4 + FIX-1/FIX-2).
>   • **Corrected in this revision**: §4.4 and §12.3 now describe
>     **FIX-1** as a **snapshot-and-reapply** strategy (the actual
>     implementation in `customize.sh`), not as a
>     "reorder + exclude" strategy. See `docs/SECURITY.md` §5.32
>     for the full analysis.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention.
>   • **Encoding correction (this revision)**: fixed mojibake in
>     section markers, arrows, checkmarks, warnings, and box
>     drawing characters. All symbols now render as proper UTF-8.

> **📖 Development workflow**:
> - Git branching strategy → [`docs/BRANCHING.md`](BRANCHING.md)
> - Release process → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)
> - Version upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [✅ What Was Delivered in v1.0.0](#2--what-was-delivered-in-v100)
3. [✅ What Was Delivered in v1.1.0](#3--what-was-delivered-in-v110)
4. [✅ What Was Delivered in v1.2.0](#4--what-was-delivered-in-v120)
5. [v1.3.0 — Q1 2027](#5-v130--q1-2027)
6. [v1.4.0 — Q2 2027](#6-v140--q2-2027)
7. [v2.0.0 — 2028](#7-v200--2028)
8. [Under Consideration](#8-under-consideration)
9. [Permanently Excluded](#9-permanently-excluded)
10. [How to Contribute to Priorities](#10-how-to-contribute-to-priorities)
11. [Development Workflow Priorities](#11-development-workflow-priorities)
12. [v1.2.0 Data-Preservation Registry](#12-v120-data-preservation-registry)

---

## 1. Overview

### 1.1 Philosophy

The project roadmap is built on 6 principles:

| # | Principle | Implementation |
|:-:|---|---|
| 1 | **Zero Telemetry** | No unauthorized external connections |
| 2 | **Localhost-First** | All services are local by default |
| 3 | **Zero External Deps** | Go stdlib only |
| 4 | **Backward Compatible** | Upgrade is always safe |
| 5 | **User-Controlled** | Nothing runs without user decision |
| 6 | **Stable Release Workflow** | `main` is always stable; features are integrated through `develop` (see [`docs/BRANCHING.md`](BRANCHING.md)) |

### 1.2 Priority Criteria

Each proposed feature is evaluated based on:

- 🎯 **Impact**: How many users benefit?
- ⚡ **Cost**: How long does implementation take?
- 🔒 **Security**: Does it improve or weaken security?
- 🎨 **Complexity**: Does it increase project complexity?
- 🧪 **Testability**: Can it be tested automatically?
- ⚠️ **Stability**: Does it affect RACE-1 (concurrency) or
  PORT-2 (dynamic ports)?

### 1.3 Symbols

| Symbol | Meaning |
|:---:|---|
| ✅ | Complete |
| 🚧 | In progress |
| 📅 | Planned |
| 💡 | Under study |
| ⏸️ | Deferred |
| ❌ | Excluded |
| 🆕 | New in this update |

---

## 2. ✅ What Was Delivered in v1.0.0

**Release date**: 2026-09-24.
**Type**: First Stable Release — the project graduates from beta.

### 2.1 🔴 Critical Fixes (7)

| # | Fix | Status |
|:-:|---|:---:|
| **1** | Dashboard JSON conversion (Prometheus → JSON) | ✅ |
| **2** | Shell fallback for CI (`getSystemShell()`) | ✅ |
| **3** | Preserve user settings on upgrade | ✅ |
| **4** | Fixed `.gitignore` negation | ✅ |
| **5** | Pre-commit hooks fixed | ✅ |
| **6** | Asset Serving Fix (13 web files) | ✅ |
| **7** | CodeQL config drift | ✅ |

### 2.2 🔴 Additional Security Fixes (NEW-1 → NEW-6)

| # | Fix | Status |
|:-:|---|:---:|
| **NEW-1** | Login POST-only (CSRF protection) | ✅ |
| **NEW-2** | `hasEndpoint` usage (no `strings.HasSuffix`) | ✅ |
| **NEW-3** | `readConfPort` range check (1-65535) | ✅ |
| **NEW-4** | `/readyz` localhost-only | ✅ |
| **NEW-5** | `shellQuote()` injection protection | ✅ |
| **NEW-6** | Auth cache (60s) | ✅ |

### 2.3 🔴 Architectural Fixes (RACE-1 + PORT-2)

| # | Fix | Status |
|:-:|---|:---:|
| **RACE-1** | `rebuildMu` mutex (concurrency safety) | ✅ |
| **PORT-2** | `runtime_info` dynamic ports | ✅ |

### 2.4 🟠 High Priority Fixes

| # | Fix | Status |
|:-:|---|:---:|
| **8** | Basic Auth rate limiting | ✅ |
| **9** | `fuser` PID parsing | ✅ |

### 2.5 🟡 Medium Priority Fixes

| # | Fix | Status |
|:-:|---|:---:|
| **10** | Section header with comment (TOML) | ✅ |
| **11** | Per-port cache | ✅ |
| **12** | Exact endpoint matching (`hasEndpoint`) | ✅ |
| **-G** | `getMonitoringAuth` exact key match | ✅ |
| **-H** | `recordLoginAttempt` optimization | ✅ |
| **-I** | `isRunDirUsable` cache (30s) | ✅ |
| **-J** | `isPortOpen` native Go | ✅ |

### 2.6 📊 Statistics

| Category | Value |
|---|:---:|
| Total Audit Corrections | **33** |
| Supported architectures | **4** |
| Documentation files | **23** (16 core + 7 ADRs) |
| Architecture Decision Records | **6** (5 accepted + 1 superseded) |
| Shell scripts (proxy/) | **8** |
| Build scripts (scripts/) | **5** |
| Web/PWA files | **13** |
| Audit Corrections applied | **#1 → #33** |
| Breaking Changes | **6** |
| Files updated | **35+** |

### 2.7 🆕 Features Added

| Feature | Description | Reference |
|---|---|---|
| **Preserve settings on upgrade** | Automatic backup/restore of 5 files | Fix #3 |
| **Dynamic WebUI/Dashboard links** | Links updated from `runtime_info` | PORT-2 |
| **Login POST-only** | CSRF protection | NEW-1 |
| **`/readyz` localhost-only** | Info leak prevention | NEW-4 |
| **`shellQuote()`** | Shell injection protection | NEW-5 |
| **`readConfPort` range check** | Rejects values outside `[1, 65535]` | NEW-3 |
| **Auth cache 60s** | Reduce file I/O | NEW-6 |
| **`rebuildMu`** | Serialization for `rebuildBlocklist` | RACE-1 |
| **`runtime_info` ports** | Support dynamic ports | PORT-2 |
| **`hasEndpoint` exact matching** | Exact path matching | Fix #12 |
| **404 for unknown actions** | Better error reporting | Fix #12 |
| **Per-port cache** | Correct cache per port | Fix #11 |
| **Retry logic** (DNS binaries) | 3 attempts + exponential backoff | Level 4 |
| **Platform-Agnostic Shell** | Linux/macOS/Android | Fix #2 |
| **Two-branch model** | `main` + `develop` | ADR-0001 |
| **Automated releases** | `release.sh` + `release.yml` | ADR-0002 |
| **Post-release sync** | Auto-sync `main → develop` | ADR-0003 |
| **Release-specific PR template** | For `release/*` and `hotfix/*` | ADR-0005 |
| **ADR system** | Architecture Decision Records | ADR-0001 → 0006 |

### 2.8 🎯 Lessons Learned

**What worked**:
- ✅ **Splitting fixes by severity** (Critical → High → Medium) eased
  prioritization.
- ✅ **Backup/restore of settings** solved a long-standing problem.
- ✅ **`getSystemShell()`** fixed CI permanently.
- ✅ **Adapter Pattern** for metrics (Prometheus → JSON) avoided
  upstream modifications.
- ✅ **`sync.Once`** for `getSystemShell` — zero overhead.
- ✅ **Per-port cache** fixed the drift issue.
- ✅ **Two-branch model** (`main` + `develop`) keeps releases stable
  while enabling fast feature iteration — see
  [`docs/BRANCHING.md`](BRANCHING.md).
- ✅ **Automated `release.sh`** reduces human error during version
  bumping.
- ✅ **ADR system** provides a transparent audit trail for
  architectural decisions.

**What didn't work yet**:
- ⚠️ **CSP `'unsafe-inline'`** is still present (target: v1.3.0).
- ⚠️ **Some Dashboard fields** remain empty (`resolver_health`,
  `top_domains`).
- ⚠️ **PWA dual-origin limitation** (9090 ≠ 9091) — needs
  unification.
- ⚠️ **`manifest.json` shortcuts** cannot read `runtime_info`
  (static).

**Lessons**:
- 🎯 **Order matters**: Fix Critical before features.
- 🎯 **Comprehensive documentation** is part of the fix.
- 🎯 **Retry logic** is essential in CI for anything depending on
  the internet.
- 🎯 **Coarse-grained `rebuildMu` lock**: Simpler + no deadlock.
- 🎯 **Dynamic ports via `runtime_info`**: Needs both Frontend +
  Backend changes.
- 🎯 **Using `window.location.hostname`** in JS is better than
  `127.0.0.1` (LAN + IPv6).
- 🎯 **Branch strategy upfront** prevents accidental `main`
  pollution later.
- 🎯 **Reversals are healthy**: ADR-0004 → ADR-0005 proves the ADR
  system works.
- 🎯 **Naming matters**: `hotfix.sh` → `release-patch.sh` reduced
  conceptual confusion (see [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md)).

---

## 3. ✅ What Was Delivered in v1.1.0

**Release date**: 2026-09-26.
**Type**: Polish Release — documentation + runtime improvements.
**Audit Corrections**: None (registry remains at #33).

### 3.1 🎯 Overview

v1.1.0 is a focused release that closes **three runtime edge cases**
and brings **16 documentation files** to a consistent, English-only
global edition.

It is **not** an audit-correction release. The three improvements
(MEM-1 / MEM-2 / MEM-3) are documented in `docs/SECURITY.md` §5.30
but are **not assigned audit correction numbers** because they do
not fix known exploitable vulnerabilities.

### 3.2 🆕 Runtime Improvements (3)

| ID | Title | Impact |
|:-:|---|---|
| **MEM-1** | Dynamic memory limit per profile | Replaces hardcoded 80 MB with per-profile limits (light=80 → ultimate=220). Prevents GC thrashing on `ultimate`. |
| **MEM-2** | Extended `shellQuote` charset | Adds `{`, `}`, `\n`, `\t` (24 chars total). Defense-in-depth. |
| **MEM-3** | `MONITORING_UI_PORT` in metrics handler | Removes last hardcoded `"8080"` string. Single source of truth. |

### 3.3 📡 New API Fields (2)

| Field | Location | Type |
|---|---|---|
| `profile_key` | `runtime_info`, `get_profile` | string (light/normal/pro/proplus/ultimate) |
| `memory_limit_mb` | `runtime_info`, `get_profile` | int (80/100/120/160/220) |

### 3.4 🔴 Critical Fix (1)

| Fix | File | Impact |
|---|---|---|
| Removed restrictive CSP meta | `web/offline.html` | Fixed silent failure of Retry/Diagnose/language toggle/auto-retry |

**Root cause**: The CSP `default-src 'none'` implicitly forbade
`script-src`, which silently blocked the page's own inline script.

**Rationale for removal**: The page has no user data, no forms, no
network calls after load, and uses only `textContent`. There is
nothing to protect with CSP. If a future version adds dynamic content
from untrusted sources, CSP must be reintroduced — preferably with a
nonce.

### 3.5 📖 Documentation Updates

| Document | Change |
|---|---|
| `docs/SECURITY.md` | §5.30 (MEM-1/2/3), §14.22–14.24 (checklists), §17.1 |
| `docs/ARCHITECTURE.md` | §3.9 (Memory Limit Flow), §4.9 (v1.1.0 additions), §11.22 |
| `docs/API.md` | §2.1 (per-profile table), §6.1.7 (runtime_info schema) |
| `docs/COMPATIBILITY.md` | §5.4 (Memory profile by device RAM), §8.3 (v1.1.0 issues) |
| `docs/TROUBLESHOOTING.md` | §4.12 (memory limit), §5.14 (profile key), §6.10 (GC thrashing), §15.13 (helper) |
| `docs/FAQ.md` | Q8 (updated), Q111–Q120 (new) |
| `docs/INSTALL.md` | §4.4 (memory limit line), §7.10 (runtime_info), §12 (v1.1.0 notes) |
| `docs/UPGRADE.md` | §3.0 (full v1.0.0 → v1.1.0 guide) |
| `docs/GLOSSARY.md` | 8 new terms + 4 abbreviations |
| `docs/HALL_OF_FAME.md` | Memory Architect badge |
| `docs/BRANCHING.md` | Release examples updated to v1.2.0 |
| `docs/RELEASE_PROCESS.md` | versionCode table extended |
| `docs/DNS_BINARIES.md` | DNS-version vs module-version distinction |
| `docs/DEVELOPMENT.md` | §8.10 (memory debugging), §8.11 (all-profiles test), §10.8 (Golden Rule #21) |
| `docs/CONTRIBUTING.md` | §5.5 (MEM commits), §8.8 (memory testing), §13.1 (Golden Rule #21) |
| Root `README.md` | Version badge, RAM-by-profile table, MEM in Security |
| Root `CHANGELOG.md` | New `[v1.1.0]` section |
| Root `SECURITY.md` | v1.1.0 changes, MEM-1/2/3 summary |

### 3.6 📊 Statistics

| Category | Before (v1.0.0) | After (v1.1.0) |
|---|:---:|:---:|
| Audit Corrections | 33 | 33 (unchanged) |
| Runtime improvements | 0 | **3** (MEM-1/2/3) |
| New API fields | 0 | **2** (profile_key, memory_limit_mb) |
| Documentation files updated | — | **16** |
| Critical fixes | — | **1** (offline.html CSP) |

### 3.7 🎯 Lessons Learned

**What worked**:
- ✅ **Per-profile memory limit** removes a self-inflicted DoS
  surface without weakening light profiles.
- ✅ **Documentation-first** approach: every runtime change got its
  own section in SECURITY, ARCHITECTURE, COMPATIBILITY, API, and
  TROUBLESHOOTING.
- ✅ **Distinction between "runtime improvement" and "audit
  correction"** kept the Audit Corrections Registry clean
  (remains at #33).

**What was discovered**:
- 🔍 **`offline.html` had a silent CSP bug** since v1.0.0. Every
  interactive feature was blocked. This only surfaced during the
  v1.1.0 review.
- 🔍 **The version confusion** (DNS vs module) is a recurring
  source of questions. Resolved by explicit tables in
  `docs/DNS_BINARIES.md` §1.1 and `docs/GLOSSARY.md` §5.
- 🔍 **Golden Rule #21** (memory observability) was needed to
  prevent future contributors from adding a new profile without
  updating all 5 files.

**Carried over to v1.2.0**:
- CSP hardening (`'unsafe-inline'` removal) — required more work
  than originally estimated. **Deferred to v1.3.0**.
- PWA port unification — needs coordination with `main.go` mux
  routing. **Deferred to v1.3.0**.

---

## 4. ✅ What Was Delivered in v1.2.0

**Release date**: 2026-09-29.
**Type**: Data-Preservation Release (MINOR).
**Audit Corrections**: None (registry remains at #33).

### 4.1 🎯 Overview

v1.2.0 is the **Data-Preservation Release** — the biggest
reliability improvement since v1.0.0. It fixes a **data-loss bug**
in v1.1.0 that silently erased the 5 user config files on every
in-place upgrade, and hardens the write path with 10 defensive
layers.

It is **not** an audit-correction release. The additions
(BAK-1..BAK-4) are **runtime improvements**, and FIX-1 / FIX-2 are
**correctness fixes** — neither is assigned an audit correction
number. They are documented in `docs/SECURITY.md` §5.31 and §5.32.

### 4.2 🆕 10 Defensive Layers

| # | Layer | File(s) | Role |
|:-:|---|---|---|
| 1 | Multi-source detection | `customize.sh` | Search 7 candidate locations for user data |
| 2 | Persistent backup | `customize.sh`, `functions.sh` | Snapshot to `/sdcard/dnscrypt-webui-backup/` |
| 3 | SHA256 integrity verification | `customize.sh`, `functions.sh` | Advisory per-file checksum |
| 4 | Transactional upgrades | `customize.sh` | Atomic install with rollback |
| 5 | Root-solution compatibility | `customize.sh` | Magisk / KernelSU / APatch |
| 6 | SELinux preservation | `customize.sh`, `functions.sh` | `restorecon` / `chcon` |
| 7 | Recovery mode | `customize.sh` | Trigger file restore |
| 8 | Config migrations | `customize.sh` | Version-aware transforms |
| 9 | Automation + rotation | `service.sh`, `main.go` | Periodic + pre-critical backups |
| 10 | Observability | `status.sh`, `main.go` | `.upgrade_history.json` + 7-field `backups` |

### 4.3 🆕 Runtime Additions (4)

| ID | Title | Impact |
|:-:|---|---|
| **BAK-1** | 7-field `runtime_info.backups` | Adds `in_flight_txn` and `orphan_txn` to the existing 5 fields |
| **BAK-2** | `createAutoBackup(reason)` + `backupMu` | Pre-critical backup before 5 destructive endpoints; serialized by mutex |
| **BAK-3** | `cleanupOldTransactions()` | Removes leftover `COMMIT`'d `txn-*` dirs at startup |
| **BAK-4** | `checkPendingNotifications()` | Reads `.pending_notification` at startup |

### 4.4 🔧 Correctness Fixes (2)

| ID | Fix | Reference |
|:-:|---|---|
| **FIX-1** | Recovery-mode **snapshot-and-reapply** — `§[8a]` restores the 5 files and copies them to `$MODPATH/.recovery_snapshot/`; `§[9]` extracts the ZIP normally (extraction logic untouched, so the normal-install path stays byte-for-byte identical); `§[9b2]` re-applies the 5 files from the snapshot. The snapshot directory is cleaned up in `§[9b2]` unless the re-apply is partial. | `docs/SECURITY.md` §5.32.1 |
| **FIX-2** | Service Worker update-banner — send `SKIP_WAITING` to the correct worker (both `index.html` + `dashboard.html`) | `docs/SECURITY.md` §5.32.2 |

**Corrected in this revision**: FIX-1 is a **snapshot-and-reapply**
strategy, not a "reorder + exclude" strategy. An earlier draft
described it as "ZIP extraction runs before the restore and
excludes 2 files at risk" — that description did not match the
shipped implementation. The snapshot-and-reapply approach keeps
the extraction logic of `§[9]` untouched and does not depend on
knowing what the ZIP contains.

### 4.5 📡 New API Fields (1)

| Field | Location | Type |
|---|---|---|
| `backups` | `runtime_info` | object with 7 fields |

**Schema**:

```json
{
  "available": 5,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-09-29 15:00:00",
  "last_backup_name": "20260929-150000-manual-1234",
  "last_stable": "20260929-095826-v1.2.0-5678",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

### 4.6 🆕 New CLI Tools (2)

| Tool | Description |
|---|---|
| `action.sh --backup` | Trigger a manual backup |
| `status.sh --diagnose` | Full diagnostic report (Layer 10) |

### 4.7 🌐 Bilingual WebUI

| Aspect | Value |
|---|---|
| Default language | English |
| Toggle | In-page `langToggle` button |
| Alternative language | Arabic (RTL) |
| Storage | `localStorage['dnscrypt-lang']` |
| Server state | None |
| API impact | None (language-neutral) |

### 4.8 📖 Documentation Updates

| Document | Change |
|---|---|
| `docs/BACKUP.md` | **NEW** — full backup system reference |
| `docs/EMERGENCY.md` | **NEW** — emergency recovery guide |
| `docs/ARCHITECTURE.md` | §3.10 (Backup & Restore Flow), §4.10 (BAK-1..BAK-4), §6.7 (Bilingual WebUI) |
| `docs/API.md` | §6.1.7 (7-field `backups`), §10.6 (backup diagnostics), §10.7 (recovery), §10.8 (language-neutral API) |
| `docs/SECURITY.md` | §5.31 (Data Preservation Security Model), §5.32 (Recovery Mode Correctness Fix) |
| `docs/COMPATIBILITY.md` | §2.5 (Backup Compatibility by Android Version), §8.4 (v1.2.0 issues) |
| `docs/TROUBLESHOOTING.md` | §4.14 (recovery data loss), §7.8–§7.11 (backup issues), §15.13–§15.15 |
| `docs/FAQ.md` | Q121–Q130 (new) |
| `docs/CONTRIBUTING.md` | §8.9 (backup testing), §8.10 (matrix testing), §8.11 (bilingual testing), §9.5–§9.6, Golden Rule #22/#23 |
| `docs/DEVELOPMENT.md` | §8.12 (backup debugging), §8.13 (matrix testing), §8.14 (bilingual debugging) |
| `docs/INSTALL.md` | §4.3 (10-layer install), §7.12 (backup layer), §7.13 (manual backup), §10.7 (preserved backup), §10.8 (recovery mode) |
| `docs/UPGRADE.md` | §3.1 (full v1.1.0 → v1.2.0 guide) |
| `docs/GLOSSARY.md` | 20+ new terms (Persistent Backup, txn-*, orphan-txn-*, backupMu, etc.) + 4 abbreviations (FBE, MTP, FUSE, OTA) |
| `docs/HALL_OF_FAME.md` | Data Guardian badge |
| `docs/BRANCHING.md` | v1.2.0 changes block + version examples |
| `docs/RELEASE_PROCESS.md` | §1.6 v1.2.0 reference + versionCode table extended |
| `docs/DNS_BINARIES.md` | v1.2.0 changes block + §11.8–§11.10 |
| `docs/COMPATIBILITY.md` | §2.5 + §8.4 + §10.3 + §10.7 |
| `docs/ROADMAP.md` | This file |
| `CHANGELOG.md` | New `[v1.2.0]` section |
| `README.md` | Version badge + 10-layer description + Data Preservation section |
| `SECURITY.md` | v1.2.0 changes + BAK-1..BAK-4 summary |

### 4.9 📊 Statistics

| Category | Before (v1.1.0) | After (v1.2.0) |
|---|:---:|:---:|
| Audit Corrections | 33 | 33 (unchanged) |
| Defensive layers | 1 (legacy `BACKUP_TMP`) | **10** |
| Runtime additions | 3 (MEM-1/2/3) | **7** (+BAK-1..BAK-4) |
| Correctness fixes | 1 (offline.html CSP) | **3** (+FIX-1/FIX-2) |
| New API fields | 2 | **3** (+`backups` object) |
| New CLI tools | 0 | **2** (`--backup`, `--diagnose`) |
| Documentation files updated | 16 | **19** |
| Test scenarios (CI matrix) | 0 | **42** (upgrade-test.yml) |

### 4.10 🎯 Lessons Learned

**What worked**:
- ✅ **The "search everywhere" philosophy** (multi-source
  detection) is robust to renames, reinstalls, and root-solution
  differences. It replaced the fragile "detect if upgrade?"
  approach.
- ✅ **Persistent backup to `/sdcard/`** survives reboot,
  uninstall, and `/data` reset. Far more reliable than
  `/data/local/tmp/`.
- ✅ **Transactional install with rollback** means an interrupted
  upgrade cannot leave the module in a partial state.
- ✅ **Preserving `START` transactions as `orphan-txn-*`** on
  uninstall prevented data loss in the rare case of an interrupted
  install.
- ✅ **`backupMu` serialization** is a simple, coarse-grained
  solution that eliminates an entire class of concurrency bugs.
- ✅ **Bilingual WebUI** requires zero server-side state — a clean
  separation that avoids adding a user-tracking dimension.
- ✅ **Snapshot-and-reapply** (FIX-1) keeps the ZIP extraction
  logic untouched, so the normal-install path stays byte-for-byte
  identical to the pre-recovery behavior. No dependency on
  knowing the ZIP's contents.

**What was discovered**:
- 🔍 **The v1.1.0 data-loss bug** was caused by a path-comparison
  check (`$_EXISTING_MODULE != $MODPATH`) that always failed on
  in-place upgrades. The bug was silent — users lost their
  settings without any error.
- 🔍 **Recovery-mode interaction bug** (FIX-1): in an early v1.2.0
  draft, the ZIP extraction step overwrote 2 of 5 restored files.
  Caught during the pre-release audit and fixed with
  snapshot-and-reapply.
- 🔍 **Service Worker update-banner bug** (FIX-2): v1.1.0 shipped
  the fix for `index.html` but not `dashboard.html`. Also caught
  during the audit.
- 🔍 **`append_denylist` was a no-op** in early drafts — the
  endpoint took no arguments and re-saved the current denylist
  unchanged. Fixed by requiring a `content` parameter (BUG-A).

**Carried over to v1.3.0**:
- CSP hardening (`'unsafe-inline'` removal) — still pending.
- PWA port unification — still pending.
- WebUI update to use `append_denylist` with content — see §5.
- Memory Architect badge tooling — see §5.

---

## 5. v1.3.0 — Q1 2027

**Type**: ✨ Feature Release (MINOR).
**Goal**: Security hardening + PWA unification + memory tooling.
**Status**: 📅 Planned.

### 5.1 Core Features

#### 🎯 5.1.1 Remove `'unsafe-inline'` from CSP

**Status**: 📅 Planned (carried from v1.2.0)
**Priority**: 🔴 High
**Complexity**: 🟡 Medium
**Reference**: `docs/SECURITY.md`

**Current problem:**
```http
Content-Security-Policy: script-src 'self' 'unsafe-inline'
```
`'unsafe-inline'` reduces XSS protection.

**Planned solution:**

| Step | Description |
|---|---|
| 1 | Convert every `onclick="..."` to `addEventListener` |
| 2 | Remove `'unsafe-inline'` from `script-src` |
| 3 | Use `nonce` or `hash` for required scripts |
| 4 | Comprehensive retest (`index.html` + `dashboard.html`) |
| 5 | Update CSP in `main.go` |

**Impact**:
- ✅ Improves XSS protection by ~90%.
- ✅ Aligns with OpenSSF best practices.
- ⚠️ Requires comprehensive WebUI retest.

**Estimate**: ~1-2 weeks.

---

#### 🎯 5.1.2 Unify WebUI + Dashboard on one port

**Status**: 📅 Planned (carried from v1.2.0)
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium
**Reference**: `docs/ARCHITECTURE.md` §6.6

**Current problem:**
- **PWA dual-origin limitation**: Service Worker bound to a single
  origin (9090 ≠ 9091).
- User needs to install PWA twice (one per port).
- Assets stored twice (duplicated ~250 KB).

**Planned solution (Option A)**:
- Dashboard served from the same `9090` at `/dashboard`.
- Single origin → single SW → offline for both.
- Single PWA.

**Impact**:
- ✅ Perfect PWA experience.
- ✅ No asset duplication.
- ✅ Offline for both.
- ⚠️ **Breaking**: `/api/metrics` moves to 9090 (was 9091).
- ⚠️ Requires `runtime_info` update (remove `dashboard_port`).

**Estimate**: ~2-3 weeks.

---

#### 🎯 5.1.3 Dedicated Maskable Icon

**Status**: 📅 Planned (carried from v1.2.0)
**Priority**: 🟡 Medium
**Complexity**: 🟢 Easy
**Reference**: `web/manifest.json` `x-note-maskable`

**Current problem**:
- The `maskable` purpose reuses `icon-512.png`, which has a shield
  that extends to `y=52` (borderline at the 40% safe circle).
- On devices with aggressive circular masks (45%+), the top of the
  shield may be clipped.

**Planned solution**:
- New file: `web/icon-maskable.svg`.
- New PNG: `web/icon-maskable.png` (512×512, wider safe zone).
- Update `manifest.json` `maskable` entry.
- Update `web/sw.js` `PRECACHE_ASSETS`.
- Update `proxy/main.go` `serveStaticAssets`.
- Update `scripts/generate-icons.sh`.

**Estimate**: ~3-5 days.

---

#### 🎯 5.1.4 Improve `manifest.json` shortcuts

**Status**: 📅 Planned (carried from v1.2.0)
**Priority**: 🟢 Low
**Complexity**: 🟢 Easy

**Current problem**: Shortcuts are static (9090/9091 hardcoded).

**Solution**:
- After §5.1.2 (port unification), no need for duplicate shortcuts.
- Single shortcut for `/dashboard`.

**Estimate**: ~1 day.

---

#### 🎯 5.1.5 Encrypt credentials file

**Status**: 📅 Planned (carried from v1.2.0)
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium

**Current problem:**
`/data/local/tmp/dnscrypt_credentials.txt` contains username/password
in plain text.

**Planned solution:**

| Alternative | Evaluation |
|---|---|
| 🔴 Encrypt with AES-GCM | Requires key (where to store?) |
| 🟢 Delete the file entirely | Simplest — user reads from TOML |
| 🟡 Place file in `run/` (0700) | Instead of `/data/local/tmp` |

**Recommendation**: Combine (2) + (3):
- File at `proxy/run/credentials.txt` (0700, root-only).
- No copy in `/data/local/tmp`.

**Impact**:
- ✅ Improved permissions (0700 vs 0644).
- ✅ No duplicated copy.
- ⚠️ Requires updating `customize.sh` and `uninstall.sh`.

**Estimate**: ~3-5 days.

---

#### 🎯 5.1.6 Add live Dashboard tests

**Status**: 📅 Planned (carried from v1.2.0)
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium

**Idea**: Add end-to-end tests for the Dashboard:
- Mock monitoring_ui server.
- Simulate Prometheus text.
- Verify JSON output schema.

**Estimate**: ~3-5 days.

---

#### 🎯 5.1.7 Memory Architect badge support

**Status**: 📅 Planned (carried from v1.2.0)
**Priority**: 🟡 Medium
**Complexity**: 🟢 Easy

**Idea**: Since v1.1.0 introduced the Memory Architect badge, add
tooling to make it easier for contributors to earn it:
- A `scripts/report-memory.sh` helper that produces a standardized
  memory report (profile_key, memory_limit_mb, RSS, CPU sample).
- A GitHub Issue template for memory reports.
- A `docs/MEMORY_TESTING.md` guide.

**Impact**:
- ✅ Lowers the barrier for contributors.
- ✅ Standardizes reports for easier comparison.
- ✅ Aligns with the v1.1.0 MEM-1 verification requirements.

**Estimate**: ~2-3 days.

---

#### 🎯 5.1.8 Improve memory-limit observability

**Status**: 📅 Planned (carried from v1.2.0)
**Priority**: 🟢 Low
**Complexity**: 🟢 Easy

**Idea**: Add historical tracking of the memory limit to help
diagnose GC behavior over time:
- Log the limit at every profile change (already done in v1.1.0).
- Add a `memory_history` field to `runtime_info` with the last N
  transitions.
- Optionally expose a small dashboard chart.

**Estimate**: ~2-3 days.

---

#### 🆕 🎯 5.1.9 Data Guardian badge support

**Status**: 📅 Planned (new)
**Priority**: 🟡 Medium
**Complexity**: 🟢 Easy

**Idea**: Since v1.2.0 introduced the Data Guardian badge, add
tooling to make it easier for contributors to earn it:
- A `scripts/report-backup.sh` helper that produces a standardized
  backup report (7-field `backups` object + scenario details).
- A GitHub Issue template for backup reports.
- A `docs/BACKUP_TESTING.md` guide.

**Impact**:
- ✅ Lowers the barrier for contributors.
- ✅ Standardizes reports across root solutions.

**Estimate**: ~2-3 days.

---

#### 🆕 🎯 5.1.10 Backup integrity hardening

**Status**: 📅 Planned (new)
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium

**Idea**: Strengthen the advisory SHA256 check (Layer 3) into an
**opt-in enforcing mode**:
- Add `BACKUP_INTEGRITY_MODE=advisory|enforce` to `webui.conf`.
- In `enforce` mode, a SHA256 mismatch blocks the restore and
  falls back to the next snapshot.
- Default remains `advisory` for backward compatibility.

**Estimate**: ~1 week.

---

#### 🆕 🎯 5.1.11 WebUI `append_denylist` with content

**Status**: 📅 Planned (new)
**Priority**: 🟡 Medium
**Complexity**: 🟢 Easy

**Idea**: The v1.2.0 `POST /api/append_denylist` endpoint now
requires a `content` parameter (BUG-A fix), but the current WebUI
does not send it. Update the WebUI to use this endpoint for
incremental denylist additions.

**Files**: `web/index.html`.

**Estimate**: ~2-3 days.

---

### 5.2 Planned Fixes

#### 🔧 5.2.1 `pgrep -x` on Android 5.x

**Status**: 📅 Planned | **Complexity**: 🟢 Easy
`pgrep -x` may not work on Android 5.x (old Toybox).

**Solution**:
```bash
# fallback in functions.sh
if ! pgrep -x test >/dev/null 2>&1; then
    pgrep_x() {
        ps -ef 2>/dev/null | grep -E "[ /]$1( |$)" | awk '{print $2}' | head -n1
    }
fi
```
**Estimate**: ~1 day.

---

#### 🔧 5.2.2 `awk` parser with `]` in comment

**Status**: 📅 Planned | **Complexity**: 🟡 Medium
In `get_dynamic_bootstrap`, if the comment contains `]`:
```toml
bootstrap_resolvers = ['1.1.1.1'] # [note]
```
The awk may stop at the first `]`.

**Solution**:
```awk
# Use:
in_array && /\][[:space:]]*(#|$)/ && !/\[.*\]/ { exit }
```
**Estimate**: ~1-2 days.

---

#### 🔧 5.2.3 CSS cleanup

**Status**: 📅 Planned | **Complexity**: 🟢 Easy
`index.html` has ~1500 lines of CSS. Can be reduced by removing
unused rules and merging similar ones.

**Estimate**: ~2-3 days.

---

### 5.3 Performance Improvements

#### ⚡ 5.3.1 Cache `entries count` in a file

**Status**: 📅 Planned | **Complexity**: 🟢 Easy
`getEntriesCount()` reads the entire `blocklist.txt` to count lines.
Save count in `.count` and update on rebuild.

**Estimate**: ~1-2 days.

---

#### ⚡ 5.3.2 Batch SSE broadcasts

**Status**: 📅 Planned | **Complexity**: 🟡 Medium
Buffer SSE events for 100ms and send them in batches to reduce
overhead by ~40%.

**Estimate**: ~3-5 days.

---

#### ⚡ 5.3.3 Dashboard metrics optimization

**Status**: 📅 Planned | **Complexity**: 🟡 Medium

**Current problem:**
`metricsProxyHandler` does an HTTP GET on every request → overhead.

**Planned solution:**
- Cache Prometheus response for 5s.
- Cache parsed JSON for 5s.
- On `update_profile`, refresh the cache.

**Impact**:
- ✅ Reduce ~5-15 ms → ~0.5 ms on cache hit.
- ✅ Reduce load on monitoring_ui.

**Estimate**: ~3-5 days.

---

### 5.4 v1.3.0 Summary

| # | Feature | Priority | Complexity | Estimate |
|:-:|---|:---:|:---:|:---:|
| 1 | Remove `'unsafe-inline'` from CSP | 🔴 | 🟡 | 1-2 weeks |
| 2 | Unify WebUI + Dashboard | 🟡 | 🟡 | 2-3 weeks |
| 3 | Dedicated maskable icon | 🟡 | 🟢 | 3-5 days |
| 4 | Improve manifest shortcuts | 🟢 | 🟢 | 1 day |
| 5 | Encrypt credentials file | 🟡 | 🟡 | 3-5 days |
| 6 | Live Dashboard tests | 🟡 | 🟡 | 3-5 days |
| 7 | Memory Architect badge support | 🟡 | 🟢 | 2-3 days |
| 8 | Improve memory-limit observability | 🟢 | 🟢 | 2-3 days |
| 9 | **Data Guardian badge support** | 🟡 | 🟢 | 2-3 days |
| 10 | **Backup integrity hardening** | 🟡 | 🟡 | 1 week |
| 11 | **WebUI `append_denylist` with content** | 🟡 | 🟢 | 2-3 days |
| 12 | Fix `pgrep -x` on Android 5.x | 🟢 | 🟢 | 1 day |
| 13 | Fix `awk` parser | 🟢 | 🟡 | 1-2 days |
| 14 | CSS cleanup | 🟢 | 🟢 | 2-3 days |
| 15 | Caching entries count | 🟡 | 🟢 | 1-2 days |
| 16 | Batch SSE broadcasts | 🟡 | 🟡 | 3-5 days |
| 17 | Dashboard metrics optimization | 🟡 | 🟡 | 3-5 days |

**Estimated time**: ~10-13 weeks.

---

## 6. v1.4.0 — Q2 2027

**Type**: ✨ Feature Release (MINOR).
**Goal**: Extended multi-language + advanced features.
**Status**: 📅 Planned.

### 6.1 Core Features

#### 🎯 6.1.1 Extended Multi-Language Support

**Status**: 📅 Planned
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium

**Idea**: Add new WebUI translations beyond English + Arabic:
- French (FR)
- German (DE)
- Spanish (ES)
- Russian (RU)
- Chinese (ZH)

**Implementation**:
- Extend the `translations` object in `index.html`,
  `dashboard.html`, and `offline.html`.
- Add `docs/*.<lang>.md` for documentation translations.
- Update the `langToggle` button to cycle or offer a dropdown.
- Update `manifest.json` `x-note-language` to list supported
  languages.

**Note (v1.2.0)**: The WebUI currently ships bilingual
(English default + Arabic toggle). Documentation remains
English-only by convention — community translations are welcome
as separate files.

**Estimate**: ~1-2 weeks per language.

---

#### 🎯 6.1.2 2FA (Two-Factor Authentication)

**Status**: 📅 Planned | **Priority**: 🟡 Medium | **Complexity**: 🔴 High
- TOTP (Time-based One-Time Password).
- QR code for Google Authenticator / Aegis.
- Backup codes.
- **Impact**: +100% security for exposed accounts.
- **Estimate**: ~2-3 weeks.

---

#### 🎯 6.1.3 Detailed Audit Logging

**Status**: 📅 Planned | **Priority**: 🟡 Medium | **Complexity**: 🟡 Medium
Log every action:
- Login (success/failure).
- Rule modification.
- Service start/stop.
- Setting modification.

**Structure**:
```json
{
  "timestamp": "2026-09-29T10:30:00Z",
  "user": "admin_xxx",
  "action": "save_allowlist",
  "result": "success",
  "details": {"entries": 25}
}
```
- **Estimate**: ~1-2 weeks.

---

#### 🎯 6.1.4 Improved Resolver Health UI

**Status**: 📅 Planned
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium

**Current problem:**
`resolver_health` in Dashboard doesn't display data (needs
`enable_query_log`).

**Planned solution:**
- Collect metrics from Prometheus directly.
- Display resolver stats without needing query_log.
- Track each resolver (success_rate, avg_response_ms).

**Estimate**: ~1-2 weeks.

---

#### 🎯 6.1.5 Advanced Filtering Rules Editor

**Status**: 📅 Planned
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium

**Idea**: Rules editor with:
- Syntax highlighting.
- Auto-complete for popular domains.
- Real-time validation.
- Diff view before saving.

**Estimate**: ~2-3 weeks.

---

#### 🎯 6.1.6 Remote Dashboard over HTTPS

**Status**: 💡 Under study | **Priority**: 🟡 Medium | **Complexity**: 🔴 High
- HTTPS with self-signed certificate.
- Secure LAN access support.
- **⚠️ Complex**: Requires certificate management.
- **Decision**: 📅 Planned.

---

#### 🎯 6.1.7 JWT Authentication (instead of Cookie)

**Status**: 📅 Planned
**Priority**: 🟢 Low
**Complexity**: 🟡 Medium

**Idea**: Support JWT for API consumers (instead of Cookie only):
- Authorization: Bearer <jwt>
- Configurable expiration.
- Revocation list.

**Estimate**: ~1 week.

---

#### 🎯 6.1.8 DoH3 Support (DNS over HTTP/3)

**Status**: 📅 Planned
**Priority**: 🟡 Medium

**Idea**: QUIC-based DoH.
- Better performance on weak networks.
- Requires dnscrypt-proxy update.

**Estimate**: ~1-2 weeks.

---

#### 🎯 6.1.9 Firewall Configuration UI

**Status**: 📅 Planned
**Priority**: 🟡 Medium

**Idea**:
- View Custom Chains from the interface.
- Add/remove rules manually.
- Backup/restore rules.

**Estimate**: ~2-3 weeks.

---

#### 🎯 6.1.10 Multiple User Accounts

**Status**: 📅 Planned
**Priority**: 🟢 Low

**Idea**:
- Admin / Viewer / Operator roles.
- Different permissions.
- **⚠️ Complexity**: Requires full RBAC.

**Estimate**: ~3-4 weeks.

---

#### 🎯 6.1.11 Import/Export Settings

**Status**: 📅 Planned
**Priority**: 🟡 Medium

**Idea**: Export/import all settings as JSON.

**Content**:
```json
{
  "version": "v1.4.0",
  "exported_at": "2026-09-29T...",
  "config": {
    "webui.conf": "...",
    "allowlist.txt": "...",
    "denylist.txt": "...",
    "selected_profile.txt": "..."
  }
}
```

**v1.2.0 enhancement**: Can reuse the persistent backup system
(`/sdcard/dnscrypt-webui-backup/`) for the export.

**Estimate**: ~1 week.

---

#### 🆕 🎯 6.1.12 Backup/Snapshot export to PC

**Status**: 📅 Planned (new)
**Priority**: 🟡 Medium
**Complexity**: 🟢 Easy

**Idea**: One-command export of the persistent backup directory
to a `.tar.gz` file, downloadable via the WebUI:
- Add `GET /api/export_backup` endpoint.
- Add a "Download snapshot" button in System Info panel.
- Reuse the existing `action.sh --backup` shell flow.

**Estimate**: ~3-5 days.

---

### 6.2 v1.4.0 Summary

| # | Feature | Priority | Estimate |
|:-:|---|:---:|:---:|
| 1 | Extended Multi-Language | 🟡 | 1-2 weeks/lang |
| 2 | 2FA | 🟡 | 2-3 weeks |
| 3 | Audit Logging | 🟡 | 1-2 weeks |
| 4 | Resolver Health UI | 🟡 | 1-2 weeks |
| 5 | Rules Editor | 🟡 | 2-3 weeks |
| 6 | Remote HTTPS | 🟡 | 📅 |
| 7 | JWT Authentication | 🟢 | 1 week |
| 8 | DoH3 support | 🟡 | 1-2 weeks |
| 9 | Firewall UI | 🟡 | 2-3 weeks |
| 10 | Multiple Users | 🟢 | 3-4 weeks |
| 11 | Import/Export | 🟡 | 1 week |
| 12 | **Backup export to PC** | 🟡 | 3-5 days |

**Estimated time**: ~14-20 weeks.

---

## 7. v2.0.0 — 2028

**Type**: 💥 Major Release (MAJOR — Breaking).
**Goal**: Complete rebuild.
**Status**: 💡 Under study.

### 7.1 Goals

| Goal | Description |
|---|---|
| **3× faster** | Improve performance by 200% |
| **Modern interface** | Preact/HTM instead of Vanilla JS |
| **DoQ support** | DNS over QUIC |
| **Docker/Linux** | Full Linux x86_64 support (not just Android) |
| **API v2** | Full REST + OpenAPI |
| **Multi-Node** | Manage several devices from one panel |
| **Plugin System** | Add flexibility for developers |
| **Unified memory model** | Single memory budget across all components (v1.1.0 MEM-1 is the first step) |
| **Unified backup model** | Single backup framework shared by CLI + WebUI + third-party tools (v1.2.0 persistent backup is the foundation) |

### 7.2 Planned Breaking Changes

| Current | New | Version |
|---|---|---|
| `/api?action=X` | `/api/v2/*` | v2.0.0 |
| `webui.conf` | `config.yaml` | v2.0.0 |
| `STATUS_FILE` | `state.json` | v2.0.0 |
| `/api/auth/login` (Cookie) | JWT + OAuth2 | v2.0.0 |
| 2 ports (9090 + 9091) | Single unified port | v2.0.0 |
| `web/*.html` (static) | SPA (Preact) | v2.0.0 |
| Legacy `BACKUP_TMP` reference | Removed (superseded by v1.2.0 persistent backup) | v2.0.0 |

**Reference**: [`UPGRADE.md`](UPGRADE.md) (will be updated).

---

## 8. Under Consideration

### 8.1 Possible Features

| Feature | Initial Evaluation |
|---|---|
| **DNS Query Log UI** | 🟡 Useful, but consumes a lot of space |
| **Live Traffic Graph** | 🟡 Nice, but requires data collection |
| **Per-App Rules** | 🔴 Very complex (requires VPN API) |
| **Scheduled Rules** | 🟡 Useful (e.g. block games after 8pm) |
| **Geolocation Blocking** | 🟡 Useful, but requires GeoIP database |
| **Custom DNS Servers** | 🟢 Easy, useful |
| **Parental Controls** | 🟡 Useful for families |
| **CPU Temperature Monitor** | 🟢 Easy |
| **Battery Usage Stats** | 🟡 Useful |
| **Webhook Notifications** | 🟡 Useful for advanced users |
| **Metrics Export (Prometheus)** | 🟡 For advanced users |
| **Custom Themes** | 🟢 Easy |
| **Desktop Widgets** | 🔴 Complex |
| **Multi-Protocol Support** | 🟡 DNSCrypt + DoH + DoT at the same time |
| **Docker Deployment** | 🟡 Linux-based deployment |
| **Systemd Integration** | 🟡 Linux service management |
| **USB Mode** | 🟡 Configuration via USB (Android) |
| **CLI Tool** | 🟡 Separate `dnscrypt-cli` |
| **GraphQL API** | 🟡 Alternative to REST API v2 |
| **WebSocket** | 🟡 Alternative to SSE (bidirectional) |
| **IPv6-only mode** | 🟢 For modern devices |
| **Remote backup storage** (WebDAV, S3) | 🟡 Off-device backup destination — must remain opt-in |
| **Tiered retention** (daily/weekly/monthly) | 🟡 Carried from v1.2.0 draft (see `docs/BACKUP.md` §6.1) |

### 8.2 Ideas Temporarily Rejected

| Idea | Reason |
|---|---|
| **Cloud Sync** | Violates Localhost-First |
| **Remote API** | Violates Localhost-First |
| **Analytics Dashboard** | Zero Telemetry |
| **SaaS Version** | Violates project philosophy |
| **Mobile App (iOS/Android)** | Project is already web-based + PWA |

---

## 9. Permanently Excluded

| Feature | Reason |
|---|---|
| **Telemetry / Analytics** | Violates Zero-Telemetry |
| **Cloud Sync** | Violates Localhost-First |
| **Remote Account** | No need for a local project |
| **Ads / Monetization** | Project is completely free |
| **HTTPS-only** | Breaks loopback (no certificate) |
| **Per-App Blocking** | Requires VPN API (complex) |
| **Deep Packet Inspection** | Violates privacy |
| **Traffic Shaping** | Outside DNS filter scope |
| **Root without Magisk** | Project is Magisk-based |
| **iOS Support** | iOS does not support Magisk |

---

## 10. How to Contribute to Priorities

### 10.1 Ways to Contribute

- 👍 **React to Issues** to confirm the request.
- 💬 **Discussions** for open discussion.
- 🎯 **Feature Request** by opening an Issue using the dedicated
  template.
- 💪 **Submit a PR** directly for implementation.
- 🗳️ **Vote** on proposed Issues.
- 🆕 **Test ProtoFeatures** on experimental branches (`develop` or
  `feature/*`).
- 🆕 **Propose an ADR** for architectural decisions (see §11.6).
- 🆕 **(v1.1.0)** **Submit a memory report** for the Memory
  Architect badge (see [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md)).
- 🆕 **(v1.2.0)** **Submit a backup report** for the Data Guardian
  badge (see [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) and
  [`docs/BACKUP.md`](BACKUP.md) §12).

### 10.2 What Raises a Feature's Priority

| Factor | Impact |
|---|---|
| **Repeated user requests** | 🔝 High priority |
| **Security fix** | 🔝 High priority |
| **Tangible performance improvement** | ⬆️ Medium priority |
| **Easy to implement + big benefit** | ⬆️ Medium priority |
| **Aligns with project philosophy** | ✅ Prerequisite |
| **Developer contribution offer** | 🚀 Acceleration |
| **Solves an existing Issue** | ⬆️ Acceleration |
| **Integration testing on `develop`** | ⬆️ Acceleration (proves stability before `main`) |
| 🆕 **Accompanied by a well-written ADR** | ⬆️ Acceleration (shows reasoning) |
| 🆕 **(v1.1.0)** **Accompanied by a memory report across RAM tiers** | ⬆️ Acceleration (validates MEM-1) |
| 🆕 **(v1.2.0)** **Accompanied by a backup report across devices/root solutions** | ⬆️ Acceleration (validates the 10 defensive layers) |

### 10.3 What Lowers a Feature's Priority

| Factor | Impact |
|---|---|
| **Requires external dependencies** | ⚠️ Reduction |
| **Violates project philosophy** | ⬇️ Large reduction |
| **Complex without tangible benefit** | ⬇️ Reduction |
| **Requires VPN API** | ❌ Rejection |
| **Weighs down performance** | ⬇️ Reduction |
| **Breaks RACE-1 (concurrency)** | ⬇️ Large reduction |
| **Breaks PORT-2 (dynamic ports)** | ⬇️ Large reduction |
| **Significantly increases binary size** | ⬇️ Reduction |
| **Requires unnecessary Breaking Changes** | ⬇️ Large reduction |
| **PR opened against `main` without following [`docs/BRANCHING.md`](BRANCHING.md)** | ⛔ Closed without review |
| 🆕 **(v1.1.0)** **Adds a new blocklist profile without updating all 5 memory-limit locations** | ⬇️ Large reduction |
| 🆕 **(v1.2.0)** **Modifies the 10 defensive layers without updating `docs/BACKUP.md` and `docs/EMERGENCY.md`** | ⬇️ Large reduction |
| 🆕 **(v1.2.0)** **Adds a user-facing string without both EN and AR entries** | ⬇️ Large reduction |

### 10.4 🆕 For Contributors

**If you want to accelerate a feature**:
1. Open an Issue with details.
2. Add your vote (👍).
3. Announce your willingness to contribute.
4. Contribute with a PR (fastest way).

**Priority of PR contributions**:
- 🔴 Security fixes.
- 🟠 Bug fixes.
- 🟡 Performance improvements.
- 🟢 New features.
- ⚪ Documentation.

**Where to start?**
- See [`docs/CONTRIBUTING.md`](CONTRIBUTING.md).
- Follow the branch policy in [`docs/BRANCHING.md`](BRANCHING.md):
  - **Feature/fix/docs** → branch from `develop`, PR against `develop`.
  - **Release** → PR against `main` (via `release/*`).
  - **Hotfix/PATCH** → PR against `main` (via `hotfix/*`, using
    `release-patch.sh`).
- Look for Issues labeled `good first issue`.
- Start with a small bug fix.
- **(v1.1.0)** If you have multiple devices with different RAM
  tiers, submit a **memory report** — it counts as a valid
  contribution and earns the Memory Architect badge.
- **(v1.2.0)** If you have multiple devices or root solutions,
  submit a **backup report** — it counts as a valid contribution
  and earns the Data Guardian badge.

---

## 11. Development Workflow Priorities

> This section documents the **process priorities** introduced
> alongside `docs/BRANCHING.md`, `docs/RELEASE_PROCESS.md`, and
> `docs/adr/`.

### 11.1 Why a Workflow Roadmap?

Feature roadmaps describe **what to build**. A workflow roadmap
describes **how to build it safely**. Both are necessary for a
healthy project.

### 11.2 Workflow Priorities (Current Status)

| Priority | Item | Status |
|:---:|---|:---:|
| 🔴 | Keep `main` protected (PR + CI + CodeQL required) | ✅ Policy defined in [`docs/BRANCHING.md`](BRANCHING.md) §6 |
| 🔴 | Automate releases via `scripts/release.sh` + `release.yml` | ✅ Implemented ([ADR-0002](adr/0002-automated-releases.md)) |
| 🔴 | Two-branch model (`main` + `develop`) | ✅ Implemented ([ADR-0001](adr/0001-two-branch-model.md)) |
| 🟠 | Auto-sync `main → develop` after each release | ✅ Implemented in `release.yml` ([ADR-0003](adr/0003-post-release-sync.md)) |
| 🟠 | PATCH releases via `scripts/release-patch.sh` | ✅ Implemented ([ADR-0006](adr/0006-rename-hotfix-to-release-patch.md)) |
| 🟠 | Release-specific PR template | ✅ Implemented ([ADR-0005](adr/0005-release-specific-pr-template.md)) |
| 🟠 | Require CI pass on `develop` before opening a `release/*` PR | ✅ Policy defined in `docs/BRANCHING.md` §6 |
| 🟡 | Architecture Decision Records system | ✅ Implemented (`docs/adr/`) |
| 🟡 | **42-scenario CI matrix** (`upgrade-test.yml`) | ✅ **Implemented in v1.2.0** |
| 🟡 | **`backup-smoke-test` job in `ci.yml`** | ✅ **Implemented in v1.2.0** |
| 🟡 | Add lightweight `pr-check.yml` for PR validation | 💡 Under consideration (deferred to v1.3.0) |
| 🟢 | Migrate to signed commits (GPG / Sigstore) | 💡 Under consideration |
| 🟢 | Add pre-commit hook for `git commit --amend` protection | 💡 Under consideration |
| 🟢 | Automated changelog generation from Conventional Commits | 💡 Under consideration |
| 🟡 | **(v1.1.0)** Memory-report Issue template | 📅 Planned for v1.3.0 |
| 🟢 | **(v1.1.0)** `scripts/report-memory.sh` helper | 📅 Planned for v1.3.0 |
| 🆕 🟡 | **(v1.2.0)** Backup-report Issue template | 📅 Planned for v1.3.0 |
| 🆕 🟢 | **(v1.2.0)** `scripts/report-backup.sh` helper | 📅 Planned for v1.3.0 |

**Summary**:

| Category | Count |
|---|:---:|
| ✅ Implemented | **10** |
| 📅 Planned (v1.3.0) | **4** |
| 💡 Under consideration | **4** |

### 11.3 Workflow Milestones

```text
2026 Q3 ✅ v1.0.0        — initial stable release
2026 Q3 ✅ Workflow v1   — main + develop + release.sh + release-patch.sh + ADRs
2026 Q3 ✅ v1.1.0        — polish release + MEM-1/2/3 + Memory Architect badge
2026 Q3 ✅ v1.2.0        — data-preservation release + 10 layers + BAK-1..4 + FIX-1/2
                          + 42-scenario matrix + Data Guardian badge + Bilingual WebUI
2026 Q4 📅 v1.3.0        — CSP hardening + PWA unification + memory/backup tooling
2027 Q1 📅 Workflow v1.1 — pr-check.yml + signed commits
2027 Q1 📅 v1.4.0        — 2FA + Audit Log + Multi-language + JWT
2027 Q2 📅 Workflow v1.2 — automated changelog + contributor metrics
2027 Q2 📅 v2.0.0        — major rewrite
2027 Q3 📅 Workflow v1.3 — full CI/CD audit
```

### 11.4 Long-Term Workflow Vision

- **Zero-touch releases**: `git tag` → signed release published.
- **Automated changelog**: generate from Conventional Commits.
- **Release cadence metrics**: track time-from-merge-to-release.
- **Contributor onboarding**: reduce first-PR friction.
- **Post-release telemetry** (opt-in only, aggregate): understand
  adoption without violating the Zero-Telemetry principle.
- **Complete ADR coverage**: every architectural decision
  documented.
- **(v1.1.0)** **Memory observability across devices**: collect
  anonymous RAM-tier data to improve the per-profile soft limits.
- **(v1.2.0)** **Backup observability across devices**: standardize
  backup reports to improve the 10 defensive layers based on
  real-world scenarios.

### 11.5 ADRs Index

> Full ADR system documentation:
> [`docs/adr/README.md`](adr/README.md)

| # | Title | Status |
|:-:|---|:---:|
| [0001](adr/0001-two-branch-model.md) | Two-branch model (`main` + `develop`) | ✅ Accepted |
| [0002](adr/0002-automated-releases.md) | Automated releases via `scripts/release.sh` | ✅ Accepted |
| [0003](adr/0003-post-release-sync.md) | Post-release sync (`main → develop`) | ✅ Accepted |
| [0004](adr/0004-unified-pr-template.md) | Unified PR template | ⚠️ Superseded by ADR-0005 |
| [0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template | ✅ Accepted |
| [0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` | ✅ Accepted |

**Total**: 6 ADRs (5 accepted + 1 superseded).

**v1.2.0 note**: The v1.2.0 release cycle did **not** add any new
ADR. Its 10 data-preservation layers, 4 runtime additions
(BAK-1..BAK-4), and 2 correctness fixes (FIX-1, FIX-2) are
documented as runtime improvements in `docs/SECURITY.md` §5.31,
§5.32, and §17.2 — not as architectural decisions. See
[`docs/adr/README.md`](adr/README.md) §3.3 for the criteria.

### 11.6 ADR Process

**When to create an ADR?**

- A non-trivial architectural decision.
- A process decision that affects contributions.
- A security trade-off that is accepted.
- A **reversal** of a previous decision.

**How?**

1. Copy the template from [`docs/adr/README.md`](adr/README.md) §7.
2. Assign the next sequential number (`NNNN-short-title.md`).
3. Fill in Context, Decision, Consequences, Alternatives.
4. Open a PR against `develop` with the ADR.
5. After merge, update the ADR index in `docs/adr/README.md` §6.

**When to supersede an ADR?**

- When a previously accepted decision is reversed.
- Never edit an accepted ADR — create a new one.
- Mark the old ADR's Status: `Superseded by ADR-NNNN`.

**Full details**: [`docs/adr/README.md`](adr/README.md) §3 and §4.

### 11.7 v1.1.0 Runtime Improvements — Registry

The v1.1.0 release added three runtime improvements that are
**not** audit corrections. They are documented here for
completeness:

| ID | Change | Where documented |
|:-:|---|---|
| **MEM-1** | Dynamic memory limit per profile | `docs/SECURITY.md` §5.30.1 |
| **MEM-2** | Extended `shellQuote` charset | `docs/SECURITY.md` §5.30.2 |
| **MEM-3** | `MONITORING_UI_PORT` in metrics handler | `docs/SECURITY.md` §5.30.3 |

These are tracked separately from the Audit Corrections Registry
(which remains at **#33**). Any future contribution in this
category will be assigned a `MEM-N` identifier.

### 11.8 v1.2.0 Runtime Additions — Registry

The v1.2.0 release added four runtime additions and two
correctness fixes that are **not** audit corrections. See §12
for the full registry.

---

## 12. v1.2.0 Data-Preservation Registry

The v1.2.0 release introduced the following additions, tracked
separately from the Audit Corrections Registry (which remains at
**#33**).

### 12.1 The 10 Defensive Layers

| # | Layer | File(s) | Role |
|:-:|---|---|---|
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

### 12.2 Runtime Additions (4)

| ID | Change | Where documented |
|:-:|---|---|
| **BAK-1** | `runtime_info.backups` returns 7 fields | `docs/SECURITY.md` §5.31 |
| **BAK-2** | `createAutoBackup` + `backupMu` + rotation | `docs/SECURITY.md` §5.31 |
| **BAK-3** | `cleanupOldTransactions` | `docs/SECURITY.md` §5.31 |
| **BAK-4** | `checkPendingNotifications` | `docs/SECURITY.md` §5.31 |

### 12.3 Correctness Fixes (2)

| ID | Fix | Where documented |
|:-:|---|---|
| **FIX-1** | Recovery-mode **snapshot-and-reapply** — `§[8a]` restores the 5 files and copies them to `$MODPATH/.recovery_snapshot/`; `§[9]` extracts the ZIP normally (extraction logic untouched); `§[9b2]` re-applies the 5 files from the snapshot. | `docs/SECURITY.md` §5.32.1 |
| **FIX-2** | Service Worker update-banner (send `SKIP_WAITING` to correct worker) | `docs/SECURITY.md` §5.32.2 |

**Corrected in this revision**: FIX-1 is a **snapshot-and-reapply**
strategy, not a "reorder + exclude" strategy. An earlier draft
described it as "ZIP extraction before restore" — that
description did not match the shipped implementation.

### 12.4 Post-Audit Corrections (BUG-1..BUG-6, N-1, N-4)

The v1.2.0 post-audit pass applied **7 corrections** to
`proxy/main.go` (plus one user-agent derivation fix). They do not
change the API contract, but they fix behaviors that clients
could observe:

| ID | Scope | Observable effect |
|---|---|---|
| **BUG-1** | `appendDenylist` — the pre-critical backup is performed **once** | One snapshot per call instead of two |
| **BUG-2** | `createAutoBackup` — stderr is no longer discarded | Failed backups are now visible in `dnscrypt_main.log` |
| **BUG-3** | `buildBackupInfo` — snapshots are sorted by directory **name**, not `mtime` | `last_backup_name` now matches `status.sh --json` |
| **BUG-4** | `readLogFile` — a failed `Seek` is handled explicitly | `?action=read_log` no longer silently returns the wrong slice |
| **BUG-5** | `appendDenylist` — the response message distinguishes "rules applied" from "no changes" | See `docs/API.md` §6.2.7 |
| **BUG-6** | `main()` registers `/api/runtime_info/` (trailing slash) | See `docs/API.md` §6.1.7 |
| **N-1** | `USER_AGENT` derived from `BuildVersion` | Custom `-ldflags` no longer leave a stale UA |
| **N-4** | `getEntriesCount` caches `lastSize` even when count is `0` | Fewer full scans on the "no blocklist yet" state |

### 12.5 Audit Corrections Registry — Unchanged

The Audit Corrections Registry remains at **#33** — the last entry
from v1.0.0. The v1.1.0 and v1.2.0 releases did **not** extend it.

**Next expected**: **#34** (v1.3.x), if any architectural
vulnerability is discovered.

**Reference**: `docs/SECURITY.md` §17.

---

## 13. Timeline Summary

```text
2025 Q4  │ v0.x.x (beta) ✅
2026 Q3  │ v1.0.0 ✅ (2026-09-24)
2026 Q3  │ Workflow v1 — branch strategy + releases + ADRs ✅
2026 Q3  │ v1.1.0 ✅ (2026-09-26) — MEM-1/2/3 + Memory Architect badge
2026 Q3  │ v1.2.0 ✅ (2026-09-29) — data-preservation + 10 layers + BAK-1..4
2026 Q4  │ v1.3.0 📅 (CSP + PWA unification + backup integrity hardening)
2027 Q1  │ Workflow v1.1 📅 (pr-check + signed commits)
2027 Q1  │ v1.4.0 📅 (2FA + Audit Log + Multi-language + JWT)
2027 Q2  │ Workflow v1.2 📅 (automated changelog)
2027 Q2  │ v2.0.0 💥 (Major Rewrite)
2027 Q3  │ Workflow v1.3 📅 (full CI/CD audit)
2028+    │ 💡 (Multi-Node + API v2 + Plugins)
```

---

## 🎯 Long-Term Vision

**2026 (Q3-Q4)**: Stability + Security + Data Preservation.
- Fix all Critical Bugs ✅ (v1.0.0).
- Runtime polish + memory improvements ✅ (v1.1.0).
- Data preservation + 10 defensive layers ✅ (v1.2.0).
- Zero known critical issues.
- Comprehensive documentation.
- Two-branch workflow in place ✅.
- ADR system established ✅.
- Memory Architect badge launched ✅ (v1.1.0).
- Data Guardian badge launched ✅ (v1.2.0).

**2027 (Q1-Q2)**: Advanced features.
- CSP hardening (v1.3.0).
- PWA unification (v1.3.0).
- Backup integrity hardening (v1.3.0).
- 2FA + Audit Log (v1.4.0).
- Multi-language (v1.4.0).
- DoH3 + Firewall UI.
- JWT Authentication.

**2027 (Q3-Q4)**: Rebuild.
- v2.0.0 Major Release.
- API v2 + OpenAPI.
- Plugin System.
- Unified backup model.

**2028+**: Expansion.
- Multi-Node Management.
- Desktop/Linux Support.
- Docker deployment.

---

## 📚 References

| Document | Purpose |
|---|---|
| [`CHANGELOG.md`](../CHANGELOG.md) | What was delivered (v1.0.0 + v1.1.0 + v1.2.0) |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Trade-offs (§3.10, §4.10) |
| [`docs/SECURITY.md`](SECURITY.md) | Known Issues + Audit Corrections (§5.31, §5.32) |
| [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) | How to contribute |
| [`docs/BRANCHING.md`](BRANCHING.md) | Git branching strategy |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Release process guide |
| [`docs/UPGRADE.md`](UPGRADE.md) | Version upgrade guide (§3.0, §3.1) |
| [`docs/BACKUP.md`](BACKUP.md) | **Backup system reference (v1.2.0)** |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records index |
| [`docs/FAQ.md`](FAQ.md) | Frequently asked questions (Q111–Q130) |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | Level 4 infrastructure |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Compatibility matrix (incl. memory + backup) |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition (Memory Architect + Data Guardian) |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary (MEM-1/2/3 + BAK + v1.2.0 terms) |
| [`docs/API.md`](API.md) | HTTP API Reference (§6.1.7) |
| [`docs/INSTALL.md`](INSTALL.md) | Installation guide |
| [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) | Developer guide |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting guide |

---

*Last updated: 2026-10-02*
*Current version: v1.3.0*
*Author: gasciljh*

---

<div align="center">

**🚀 Our vision**: Secure, free, and local DNS for everyone.

[⬆ Back to top](#roadmap--dnscrypt-smart-filter)

</div>