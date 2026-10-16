# Compatibility Matrix — DNSCrypt Smart Filter

Comprehensive compatibility reference: Android, ROMs, Kernels, Chipsets, Firewalls.

**Version**: v1.4.0 (Global Edition)
**Last updated**: 2026-10-08
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **Identifier inventory in this file (10 total)**:
>   • HARD-COMPAT-01 (backup section move — historical)
>   • HARD-COMPAT-02 (curl auth examples — historical)
>   • HARD-COMPAT-03 (CI backup matrix — historical)
>   • HARD-COMPAT-04 (MEM-1 runtime verification — historical)
>   • HARD-COMPAT-V14-01..03 (v1.4.0 — companion app notes)
>   • HARD-COMPAT-V14-04 (v1.4.0 — `Last updated` correction)
>   • HARD-COMPAT-V14-05 (v1.4.0 — v1.3.0 block server-side context)
>   • HARD-COMPAT-V14-06 (v1.4.0 — §2.5 SNAP-MANIFEST note)
>   • HARD-COMPAT-V14-07 (v1.4.0 — §10.3.5 SNAP/ROT verification)
>   • HARD-COMPAT-V14-08 (v1.4.0 — POST-AUDIT FIXES + cross-refs)

> **⚠️ API examples & authentication**:
>   The `curl` examples in this document use the shorthand form
>   `curl -s http://127.0.0.1:9090/api?action=...`. If your
>   install has credentials in `[monitoring_ui]` (which
>   `customize.sh §[18]` generates by default), those requests
>   will return **HTTP 401 Unauthorized**.
>
>   To authenticate, derive the credentials from the TOML file
>   and pass them with `-u`:
>
>   ```bash
>   CREDS=$(su -c "sed -n '/^\[monitoring_ui\]/,/^\[/p' \
>       /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml \
>     | grep -E '^(username|password)=' | cut -d\"'\" -f2 | tr '\n' ':' | sed 's/:$//'")
>
>   curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq
>   ```

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • `Last updated` reflects the v1.4.0 file-editing date (2026-10-08).
>   • §1.3 (What's New) rewritten to reflect the v1.4.0 feature
>     set (companion Android app integration, CodeQL hardening,
>     iOS PWA removal).
>   • §1.4 (What Was New in v1.3.0) — **extended with server-side
>     refinements context** (SNAP-MANIFEST, SNAP-MTIME,
>     ROT-MANIFEST, ROT-MTIME, ROT-PROTECT). The previous version
>     mentioned only the client-side changes.
>   • §1.5 (What Was New in v1.2.0) — renumbered from §1.3.
>   • §1.6 (What Was New in v1.1.0) — renumbered from §1.4.
>   • §1.7 (What Was New in v1.0.0) — renumbered from §1.5.
>   • §1.8 (Bilingual WebUI) — renumbered from §1.6.
>   • §1.9 (Companion Android App) — new subsection.
>   • §2.4 extended with the v1.4.0 companion app note.
>   • §2.5 extended with a v1.3.0 SNAP-MANIFEST note (the
>     `available` count rule changed).
>   • §5.4 extended with a note about the v1.4.0 companion app
>     (no memory impact — the APK is a static asset).
>   • §7.2 extended with the v1.4.0 Root + Companion App table.
>   • §8.1 extended with 2 new v1.4.0 rows:
>       - `Companion APK missing from release ZIP` (optional asset)
>       - `iOS-specific PWA path removed` (breaking if you relied
>         on the iOS install modal).
>   • §10.3 extended with a v1.4.0 compatibility testing subsection.
>   • **§10.3.5 (new) — v1.3.0 server-side refinements verification**:
>     how to test SNAP-MANIFEST + SNAP-MTIME + ROT-* on a device.
>   • §10.8 (Companion App Champion badge) — new subsection.
>   • §11.1 updated with the v1.4.0 documentation set (BACKUP.md,
>     EMERGENCY.md, UPGRADE.md, ARCHITECTURE.md §4.13).
>   • §11.3 (Companion App Repository) — new subsection.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's choice is stored in `localStorage['dnscrypt-lang']`.
>     Documentation remains English-only by project convention.
>   • Companion Android app: `web/app-debug.apk` (OPTIONAL) is
>     bundled into the module ZIP by the release pipeline. The APK
>     is fetched from
>     [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)
>     and served at `GET /app-debug.apk` on the WebUI.

> **v1.3.0 changes (historical — extended in this revision)**:
>   • Version bumped from v1.2.0 to v1.3.0.
>   • **Client-side changes**:
>       - PWA install button (dynamic, always-visible, browser-aware)
>       - Live status LED on the Today counter
>   • **Boot-path fix**: DNS auto-start after boot — `service.sh`
>     §[19] performs a bounded wait for the WebUI to become ready,
>     then calls `POST /api/ensure_running_service` directly. This
>     avoids the 30-60 s delay caused by the watchdog's first
>     polling interval. Compatibility impact: **✅ Faster DNS
>     availability after reboot**.
>   • **Server-side refinements to the backup layer** — the
>     v1.3.0 release ALSO rewrote the snapshot-detection and
>     rotation semantics that underpin `runtime_info.backups`.
>     Three identifiers document the change (also used in
>     `CHANGELOG.md` [v1.3.0] and `docs/ARCHITECTURE.md` §4.13):
>
>       🔧 **SNAP-MANIFEST** — `main.go:buildBackupInfo()` now
>         detects a snapshot by the presence of a
>         `.manifest.json` file (instead of the
>         `<YYYYMMDD>-<HHMMSS>-...` name pattern). Effect on
>         compatibility: the `available` field's count rule
>         changed. For snapshots produced by the standard
>         toolchain, the result is identical (every snapshot
>         carries a manifest). For custom-named snapshots, the
>         new count includes them; the old count did not.
>
>       🔧 **SNAP-MTIME** — `buildBackupInfo()` now selects
>         `last_backup_name` by **mtime** (descending), with a
>         name-based fallback when `DirEntry.Info()` fails.
>         Compatibility impact: the field's **value** may differ
>         only when the system clock was adjusted backwards, or
>         when a snapshot has a non-standard name. The field's
>         **type and schema** are unchanged.
>
>       🔧 **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** —
>         `functions.sh:rotate_backups()` was rewritten with
>         the same detection (ROT-MANIFEST), the same mtime
>         sort (ROT-MTIME), and two additional protected
>         targets on top of the 21-newest window (ROT-PROTECT):
>           • the `.last_stable` recovery pointer;
>           • the newest install snapshot (name matching
>             `-v<digit>`).
>         Compatibility impact: **✅ no API change**. The
>         rotation happens in the shell layer; the API only
>         observes the resulting snapshot list.
>
>   • **Parallel application**: the same SNAP-MANIFEST /
>     ROT-* semantics were applied to `watchdog.sh`,
>     `status.sh`, `customize.sh`, `action.sh`, and
>     `uninstall.sh`. Every consumer of the persistent backup
>     directory now agrees on which snapshots exist and which
>     is the newest. Compatibility impact: **✅ no API change**.
>
>   • See `CHANGELOG.md` [v1.3.0] and
>     `docs/ARCHITECTURE.md` §4.13 for the full story.

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • Global edition — English default + Arabic toggle.
>   • **10 data-preservation layers** — see §1.5.
>   • **Persistent backup directory** (`/sdcard/dnscrypt-webui-backup/`)
>     — see §2.5 for the Android version matrix.
>   • **`runtime_info.backups` — 7 fields** (additive).
>   • **Bilingual WebUI** (English default + Arabic toggle).
>   • **Watchdog token** on `POST /api/ensure_running_service`
>     — security hardening (BUG-B fix).

> **v1.4.0 (Global Edition) — Additional hardening in this revision**:
>   • 🛡️ **HARD-COMPAT-V14-01** — All `curl` examples continue to
>     document the authentication requirement. No behavioral change.
>   • 🛡️ **HARD-COMPAT-V14-02** — The "What's New" section now
>     consistently lists v1.0.0 → v1.1.0 → v1.2.0 → v1.3.0 → v1.4.0
>     as a linear chain. No version is skipped.
>   • 🛡️ **HARD-COMPAT-V14-03** — The companion Android app is
>     documented as **optional** in every reference. A missing APK
>     does not break any compatibility row.

> **v1.4.0 (Global Edition) — POST-AUDIT FIXES (this revision)**:
>   A post-audit review of this file against the v1.3.0 / v1.4.0
>   code identified the following documentation gaps. All are
>   addressed in-place; no version bump.
>
>   🔧 **HARD-COMPAT-V14-04** — **`Last updated` corrected.** The
>     header and footer previously said `2026-10-06` (which
>     corresponded to the v1.4.0 release date, not to the v1.4.0
>     file-editing date). Both now read `2026-10-08`, matching
>     every other file in the v1.4.0 module.
>
>   🔧 **HARD-COMPAT-V14-05** — **`v1.3.0` block extended.** The
>     previous block mentioned only the client-side changes (PWA
>     install button, live status LED) and the DNS auto-start fix.
>     It did NOT mention the **server-side refinements** to
>     snapshot detection and rotation (SNAP-MANIFEST, SNAP-MTIME,
>     ROT-MANIFEST, ROT-MTIME, ROT-PROTECT) that are central to
>     the `runtime_info.backups` object documented in §2.4. The
>     v1.3.0 block above now documents them, with explicit
>     "Compatibility impact" notes for each identifier.
>
>   🔧 **HARD-COMPAT-V14-06** — **§2.5 updated.** The backup
>     compatibility matrix now notes that the `available` field's
>     count rule is **SNAP-MANIFEST** (v1.3.0): a snapshot is
>     counted **iff** its directory contains a `.manifest.json`
>     file. The previous version did not mention this rule.
>
>   🔧 **HARD-COMPAT-V14-07** — **§10.3.5 added.** A new
>     verification subsection for the v1.3.0 server-side
>     refinements: how to confirm SNAP-MANIFEST, SNAP-MTIME,
>     ROT-MANIFEST, ROT-MTIME, and ROT-PROTECT are active on a
>     real device.
>
>   🟢 **HARD-COMPAT-V14-08** — **Cross-references added.**
>     §11.2 now points at `docs/ARCHITECTURE.md` §4.13 (the
>     authoritative source for the v1.3.0 server-side
>     refinements) and at `CHANGELOG.md` §[v1.3.0].

---

## Table of Contents

1. [Overview](#1-overview)
2. [Android Versions](#2-android-versions)
3. [ROMs](#3-roms)
4. [Kernels](#4-kernels)
5. [Chipsets (SoCs)](#5-chipsets-socs)
6. [Firewall Backends](#6-firewall-backends)
7. [Root Solutions](#7-root-solutions)
8. [Known Issues](#8-known-issues)
9. [Bug Report Template](#9-bug-report-template)
10. [Contributing Reports](#10-contributing-reports)
11. [References](#11-references)

---

## 1. Overview

### 1.1 Status Symbols

| Symbol | Meaning |
|:-----:|--------|
| ✅ | **Supported and tested** |
| 🟢 | **Supported** (not tested on every device) |
| ⚠️ | **Works with caveats** (needs configuration) |
| 🔶 | **Beta** (needs more testing) |
| ❌ | **Not supported** |

### 1.2 Minimum Requirements

| Requirement | Minimum | Recommended |
|---------|:-----------:|:---------:|
| **Android** | 5.0 (API 21) | 10+ (API 29) |
| **Root** | Magisk 20.4 | Magisk 26+ |
| **Kernel** | 3.10 | 4.14+ |
| **RAM** | 1 GB | 2 GB+ |
| **Storage** | 20 MB | 30 MB+ |
| **Storage (`/sdcard/`)** | **10 MB** | **50 MB+** (for backups) |
| **Architecture** | arm64 / arm / x86_64 / x86 | arm64 |

**v1.2.0 note**: The `/sdcard/` storage requirement is new in
v1.2.0 because of the persistent backup directory
(`/sdcard/dnscrypt-webui-backup/`). Each snapshot uses ~30–100 KB;
the rotation cap (21 snapshots) bounds the total to ~2.5 MB.

**v1.4.0 note**: The companion Android app APK (when bundled) adds
~3 MB to the module ZIP, but the APK itself is stored in the
device's internal storage after installation (not on `/sdcard/`).
The `/sdcard/` requirement is unchanged.

### 1.3 What's New in v1.4.0

**Integration release** — companion Android app + CodeQL hardening
+ iOS PWA cleanup.

**Compatibility-relevant changes**:

| # | Change | Compatibility impact |
|:-:|---|---|
| **1** | **Companion Android app integrated** — `web/app-debug.apk` is now bundled into the module ZIP as an **optional** asset | ✅ Optional — the module works without it. Served at `GET /app-debug.apk`. |
| **2** | **CodeQL `go/path-injection` fix in `removeModule`** | ✅ Security hardening — no behavioral change |
| **3** | **iOS PWA logic removed** (Android-only project) | ⚠️ If you relied on the iOS "Add to Home Screen" instructions, they are gone. All browsers now fall through to the unified "unsupported browser" modal. |
| **4** | **`GET /app-debug.apk` endpoint** | ✅ Additive — returns 404 when the APK is absent |
| **5** | **Release pipeline stages the APK** before packaging | ✅ No change for end users |

**Base compatibility**: no change in system requirements.

### 1.4 What Was New in v1.3.0

**Feature release** — PWA install button + live status LED +
DNS auto-start fix + **server-side backup refinements**.

**Compatibility-relevant changes**:

| # | Change | Compatibility impact |
|:-:|---|---|
| **1** | **PWA install button** — dynamic, always-visible, browser-aware | ✅ Client-side only — no API change |
| **2** | **Live status LED** on the Today counter | ✅ Client-side only |
| **3** | **DNS auto-start after boot** — `service.sh` now waits for the WebUI then calls `POST /api/ensure_running_service` directly | ✅ Faster DNS availability after reboot |
| **4** | **`watchdog.sh` backoff behavior unchanged** — the boot-path fix does not affect crash recovery | ✅ No impact |
| **5** | **SNAP-MANIFEST** — `buildBackupInfo()` detects snapshots by `.manifest.json` presence, not name pattern | ✅ **API contract unchanged**. The `available` count may be **larger** for the same on-disk state (custom-named snapshots are now visible). |
| **6** | **SNAP-MTIME** — `last_backup_name` is selected by mtime, not lexicographic name | ✅ **API contract unchanged**. The field **value** may differ only under clock drift or a non-standard snapshot name. |
| **7** | **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** — `rotate_backups` rewritten with the same detection + sort + two protected targets | ✅ **API contract unchanged**. Rotation happens in the shell layer. |
| **8** | **Parallel application** — the same SNAP-* / ROT-* semantics applied to `watchdog.sh`, `status.sh`, `customize.sh`, `action.sh`, `uninstall.sh` | ✅ **API contract unchanged**. |

**Consumers of `runtime_info.backups`**: see §2.4 for the field
description, and §10.3.5 for a verification procedure.

### 1.5 What Was New in v1.2.0

**Data-preservation release** — 10 defensive layers.

| # | Change | Compatibility impact |
|:-:|---|---|
| **1** | **10 data-preservation layers** | ✅ Fixes a data-loss bug that affected v1.1.0 in-place upgrades. See §2.5. |
| **2** | **Persistent backup directory** (`/sdcard/dnscrypt-webui-backup/`) | ⚠️ Requires writable `/sdcard/`. See §2.5. |
| **3** | **SHA256 integrity verification** | ✅ Advisory — never blocks restore. |
| **4** | **Transactional upgrades** with rollback | ✅ Requires write access to the backup dir. |
| **5** | **Root-solution compatibility** | ✅ Adds support for APatch. See §7.2. |
| **6** | **SELinux preservation** (`restorecon` / `chcon`) | ✅ Works on all SELinux-enforcing ROMs. |
| **7** | **Recovery mode** via trigger file | ✅ Requires an explicit file + reboot. |
| **8** | **Config migrations** (Layer 8) | ✅ No user action required. |
| **9** | **Auto-backup (24 h) + rotation (21 snapshots)** | ✅ Runs on `service.sh` boot. |
| **10** | **CLI diagnose tool** (`status.sh --diagnose`) | ✅ Local-only, no network required. |
| **11** | **`runtime_info.backups` — 7 fields** | ✅ Additive — 5 fields still present. |
| **12** | **Bilingual WebUI (English default + Arabic toggle)** | ✅ Client-side only. No API impact. See §1.8. |
| **13** | **Watchdog token on `POST /api/ensure_running_service`** | ⚠️ Security hardening — clients that relied on the localhost bypass must now send `X-Watchdog-Token`. |

### 1.6 What Was New in v1.1.0

**Polish release** — dynamic memory limit + extended shellQuote.

| # | Change | Compatibility impact |
|:-:|---|---|
| **1** | **MEM-1: Dynamic memory limit per profile** | ✅ Improves performance on light profiles (less GC) and heavy profiles (no GC thrashing). See §5.4. |
| **2** | **MEM-2: Extended `shellQuote` (24 chars)** | ⚪ No impact on user |
| **3** | **MEM-3: `MONITORING_UI_PORT` constant** | ⚪ No impact on user |
| **4** | **`runtime_info` new fields** (`profile_key`, `memory_limit_mb`) | ✅ Displayed in System Info panels |
| **5** | **`get_profile` new field** (`memory_limit_mb`) | ✅ Additive — clients unaffected |
| **6** | **Uninstall no longer creates backup** | ⚠️ Manual backup recommended — but **superseded by v1.2.0** (see §2.5). |

### 1.7 What Was New in v1.0.0

**First stable release.**

| # | Change | Compatibility impact |
|:-:|---|---|
| **1** | Dashboard JSON conversion | ✅ Works on all modern browsers now |
| **2** | `getSystemShell()` fallback | ✅ CI works on Linux/macOS |
| **3** | Preserve settings on upgrade | ✅ No settings loss (mechanism later superseded by v1.2.0) |
| **4** | `.gitignore` negation | ⚪ No impact on user |
| **5** | Basic Auth rate limiting | ⚠️ Scripts may lock out after 5 attempts |
| **6** | Section header with comment | ✅ Broader TOML compatibility |
| **7** | Per-port cache | ⚪ No impact |
| **8** | Exact endpoint matching | ⚠️ 404 for unknown actions |
| **9** | Login POST-only | ⚠️ GET on `/api/auth/login` rejected (405) |
| **10** | `/readyz` localhost-only | ⚠️ LAN requests rejected (403) |
| **11** | `shellQuote()` | ⚪ No impact on user |
| **12** | `readConfPort` range check | ✅ Safe fallback for invalid values |
| **13** | `rebuildMu` mutex (RACE-1) | ✅ BLOCKLIST always consistent |
| **14** | `runtime_info` dynamic ports (PORT-2) | ✅ Dynamic links |
| **15** | Auth cache (60 s) | ⚠️ Credential changes take effect after ≤ 60 s |

### 1.8 Bilingual WebUI (v1.2.0)

The WebUI ships with **English as the default language** and an
in-page **`langToggle` button** to switch to Arabic. This is a
client-side-only feature with **no compatibility impact** on the
API, the config files, or the backend.

**Browser compatibility for the language toggle**:

| Browser | English (default) | Arabic (toggle) | RTL layout |
|---|:---:|:---:|:---:|
| Chrome 90+ | ✅ | ✅ | ✅ |
| Chrome 88–89 | ✅ | ✅ | ✅ |
| Firefox 92+ | ✅ | ✅ | ✅ |
| Firefox 88–91 | ✅ | ✅ | ⚠️ (partial RTL fixes may be needed) |
| Safari 15+ | ✅ | ✅ | ✅ |
| Safari 14 | ✅ | ✅ | ⚠️ |
| Samsung Internet (recent) | ✅ | ✅ | ✅ |
| Edge 90+ | ✅ | ✅ | ✅ |
| **IE 11 (Windows desktop only)** | ❌ | ❌ | ❌ |

**Notes**:

- The bilingual feature requires **no extra storage**, **no extra
  network requests**, and **no server state**.
- The Service Worker caches the HTML **once**. Both `translations.en`
  and `translations.ar` objects are inline in the same file.
- The user's preference is stored in
  `localStorage['dnscrypt-lang']` — a few bytes per browser profile.
- No API endpoint accepts or returns a language identifier. JSON
  payloads are identical regardless of the selected language.
- **IE 11** is listed for completeness: it is a **Windows desktop**
  browser and is **not available on Android**. It is not supported
  by this project.

### 1.9 Companion Android App (v1.4.0)

The module may ship an **optional** companion Android app APK at
`web/app-debug.apk`. When present, it is:

- Served at `GET /app-debug.apk` (mime:
  `application/vnd.android.package-archive`).
- Cached with `Cache-Control: public, max-age=3600, immutable`.
- Downloadable from the WebUI install button
  (`<a download href="/app-debug.apk">`).
- **Not** required for the module to function.

**Compatibility impact**:

| Scenario | Impact |
|---|---|
| APK bundled (release build) | ✅ A "📲 Install App" button appears in the WebUI |
| APK absent (dev build) | ✅ No button; `GET /app-debug.apk` returns 404 |
| Browser blocks APK download | ⚠️ User can download it manually from the GitHub Release |

**Minimum Android version for the companion app**: 5.0 (API 21) —
same as the module itself.

**Source repository**: [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app).

---

## 2. Android Versions

| Version | API | Status | Notes |
|---------|:---:|:------:|-------|
| **15** | 35 | 🟢 | Needs testing |
| **14** | 34 | ✅ | Tested |
| **13** | 33 | ✅ | Tested |
| **12** | 31-32 | ✅ | Tested |
| **11** | 30 | ✅ | Tested |
| **10** | 29 | ✅ | Tested (v1.2.0 backup fully supported) |
| **9** | 28 | 🟢 | Works |
| **8.1** | 27 | 🟢 | Works |
| **8.0** | 26 | 🟢 | Works |
| **7.1** | 25 | ⚠️ | May need iptables adjustments |
| **7.0** | 24 | ⚠️ | Same |
| **6.0** | 23 | ⚠️ | Doze mode issues |
| **5.1** | 22 | ⚠️ | Limited (backup dir OK, but SELinux tools may be missing) |
| **5.0** | 21 | ⚠️ | Minimum supported |

### 2.1 Android-specific Notes

**Android 10+**:
- ✅ Works smoothly.
- ✅ Private DNS integration.
- ✅ SELinux permissive with no issues.
- ✅ Dashboard works (Fix #1).
- ✅ Dynamic memory limit applies (v1.1.0).
- ✅ **v1.2.0 backup fully supported** — FUSE `/sdcard/` mount,
  `restorecon` available, `sha256sum` available.
- ✅ Bilingual WebUI works in all modern browsers.
- ✅ **v1.4.0**: Companion Android app installs smoothly.

**Android 8-9**:
- ✅ Works.
- ⚠️ Battery optimization may stop the Watchdog.
- 💡 **Solution**: add to exceptions.
- ✅ **v1.2.0 backup works** — same FUSE mount.
- ✅ Bilingual WebUI works.
- ✅ **v1.4.0**: Companion app works.

**Android 6-7**:
- ⚠️ Doze mode stops services.
- 💡 **Solution**: disable battery optimization.
- ⚠️ iptables may differ.
- ✅ `getSystemShell()`: works correctly on all versions.
- ⚠️ **v1.2.0 backup works** but `restorecon` may not be
  available. In that case, `customize.sh` falls back to
  `chcon u:object_r:magisk_file:s0`.
- ⚠️ Bilingual WebUI works but very old browsers may not fully
  support the RTL flip — recommend Chrome 88+ or Firefox 92+.
- ✅ **v1.4.0**: Companion app works (min Android 5.0).

**Android 5**:
- ⚠️ Requires kernel 3.10+.
- ⚠️ May not support nftables.
- ⚠️ `pgrep -x`: may not work properly → fallback in code.
- ✅ `sync.Once`: requires Go 1.22+ (available in the build).
- ⚠️ **v1.2.0 backup**: `sha256sum` may be missing. In that case,
  `verify_backup_integrity` skips SHA256 checks (advisory) and
  relies on size + non-empty checks only. The backup is still
  created and restored — just without checksum verification.
- ⚠️ Bilingual WebUI: only modern browsers. IE 11 is not
  supported (and is not available on Android anyway).
- ⚠️ **v1.4.0**: Companion app requires API 21+ — works.

### 2.2 Dashboard Compatibility

| Browser | SVG Icons | PNG Icons | JSON Metrics | Login POST | Profile/Memory | Backups Display | Bilingual (EN+AR) |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Chrome 90+ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Chrome 88-89 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Firefox 92+ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Safari 15+ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Samsung Internet (recent) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **IE 11 (Windows desktop only)** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

**Reason**: v1.0.0 added PNG icons to precache, supporting older browsers.

**v1.2.0 note**: The "Backups Display" column reflects whether the
System Info panel can render the new `backups` object. All modern
browsers (Chrome 88+, Firefox 92+, Safari 15+) render it without
any change. IE 11 is not supported and is not available on Android.

**v1.2.0 note (Bilingual)**: The bilingual column reflects whether
the `langToggle` button and RTL layout work correctly. All modern
browsers support it. Older browsers may render the RTL layout
imperfectly — the toggle still switches languages, but right-to-left
alignment may be partial.

### 2.3 Dashboard — v1.1.0 Fields

The System Info panel in both `index.html` and `dashboard.html`
displays two additional rows populated from `runtime_info`:

| Row | Field | Type |
|---|---|---|
| **Profile** | `profile_key` | string |
| **Memory limit** | `memory_limit_mb` | int |

**Compatibility**:
- ✅ All modern browsers render the new rows without any change.
- ⚠️ IE 11: not supported (already excluded).
- ✅ No new browser API is used.
- ✅ The rows display the same values regardless of the WebUI's
  selected language.

### 2.4 Dashboard — v1.2.0 + v1.4.0 Fields

The System Info panel in both `index.html` and `dashboard.html`
displays **six additional rows** populated from the `backups`
object (v1.2.0), plus a **companion-app install button** (v1.4.0):

**v1.2.0 — Backup rows**:

| Row | Field | Type |
|---|---|---|
| **Backups** | `backups.available` | int |
| **Latest Backup** | `backups.last_backup_name` | string \| null |
| **Last Stable** | `backups.last_stable` | string \| null |
| **In-flight Txn** | `backups.in_flight_txn` | int |
| **Orphan Txn** | `backups.orphan_txn` | int |
| **Backup Path** | `backups.path` | string |

**v1.3.0 note on `available` (HARD-COMPAT-V14-06)**: Since
v1.3.0, the `available` field counts a directory as a snapshot
**iff** it contains a `.manifest.json` file (SNAP-MANIFEST).
For the standard toolchain's output, the value is identical to
v1.2.0's name-pattern-based count. It differs only when:
- A custom-named snapshot exists (v1.3.0 counts it; v1.2.0 did
  not).
- A directory matches the name pattern but lacks a manifest
  (v1.3.0 excludes it; v1.2.0 counted it).

**v1.4.0 — Companion app button**:

The main WebUI (`index.html`) now shows an install button:

```html
<a id="pwaInstallBtn" class="pwa-install-btn"
   href="/app-debug.apk" download="DNS-Proxy.apk">
    📲 Install App
</a>
```

- ✅ Served by `main.go` via `serveStaticAssets` when the APK is
  present.
- ✅ Returns HTTP 404 when the APK is absent (local dev builds).
- ✅ No JavaScript required — it is a plain `<a download>` link.

**Compatibility**:
- ✅ All modern browsers render the new rows and the button.
- ✅ No new browser API — the fields are simple text rendered
  from the existing JSON response; the button is a plain link.
- ⚠️ IE 11: not supported.

### 2.5 Backup Compatibility by Android Version (v1.2.0)

> **Placement note (HARD-COMPAT-01)**: This section was previously
> located at §5.5, under "Chipsets (SoCs)". The content has no
> relationship to SoC hardware; it belongs with the Android
> version matrix. See §5.5 for the redirect stub.

The v1.2.0 persistent backup lives at
`/sdcard/dnscrypt-webui-backup/`. Its behavior depends on how
Android mounts `/sdcard/` and what SELinux tools are available.

| Android | `/sdcard/` mount | `sha256sum` | `restorecon` | Backup support |
|---|:---:|:---:|:---:|:---:|
| **5.0 – 5.1** | FUSE (legacy) | ⚠️ may be missing | ⚠️ may be missing | 🟢 Partial (advisory checks skipped) |
| **6.0 – 7.1** | FUSE | ✅ | ⚠️ falls back to `chcon` | 🟢 Full |
| **8.0 – 9.0** | FUSE | ✅ | ✅ | ✅ Full |
| **10 – 13** | FUSE (sdcardfs replaced by FUSE) | ✅ | ✅ | ✅ Full |
| **14 – 15** | FUSE | ✅ | ✅ | ✅ Full |

**Why this matters**:

1. **FUSE mount behavior**: `/sdcard/` is a FUSE (or sdcardfs)
   mount on every Android version. Its permissions are managed
   by the FUSE daemon, not by the underlying ext4/f2fs mount.
   This is why the backup uses `0700` mode on the top-level
   directory and `0600` on files — the FUSE layer enforces them
   for root processes.

2. **`sha256sum` availability**: On very old devices (Android
   5.x with a minimal Toybox), `sha256sum` may not exist. In
   that case, `verify_backup_integrity` (Layer 3) skips the hash
   check and relies on size + non-empty checks only.

3. **`restorecon` vs `chcon`**: `restorecon` reads the system's
   `file_contexts` database and applies the correct SELinux
   context. `chcon` sets the context manually. The v1.2.0
   `copy_with_context` helper prefers `restorecon` and falls
   back to `chcon u:object_r:magisk_file:s0` if it is missing.

4. **Snapshot detection (v1.3.0 — SNAP-MANIFEST)**: Since
   v1.3.0, `runtime_info.backups.available` counts a directory
   as a snapshot **iff** it contains a `.manifest.json` file.
   This rule is **platform-independent** — it applies on every
   Android version. The only difference across Android versions
   is that on Android 5.x, the manifest's `files[].sha256`
   field may be empty when `sha256sum` is unavailable; the
   manifest itself is still written (SNAP-MANIFEST only checks
   for **presence**, not contents).

5. **Rotation semantics (v1.3.0 — ROT-MANIFEST / ROT-MTIME /
   ROT-PROTECT)**: Since v1.3.0, `rotate_backups` uses the
   same manifest-based detection and mtime sort as
   `buildBackupInfo`, and preserves the `.last_stable` target
   and the newest install snapshot. This is also
   platform-independent.

**Verified by CI (HARD-COMPAT-03)**: The
`.github/workflows/upgrade-test.yml` matrix (42 scenarios)
exercises the **shell logic** of the backup layer on
`ubuntu-22.04`, with mocked Android paths. It does **not**
emulate specific Android versions — that requires real devices
(see §10.3).

**User-facing impact**:

- **Android 8+**: The backup layer is fully functional. No
  caveats.
- **Android 6–7.1**: Backup works. SELinux context preservation
  uses `chcon` fallback. The context is correct but the tool
  path is different.
- **Android 5.0–5.1**: Backup works, but SHA256 verification is
  skipped (advisory). The backup is still safe.

### 2.6 Platform Support

| Platform | `getSystemShell()` | `hasEndpoint()` | Dashboard JSON | `memoryLimitForProfile` | **v1.2.0 backup helpers** |
|---|:---:|:---:|:---:|:---:|:---:|
| Android | ✅ | ✅ | ✅ | ✅ | ✅ |
| Linux (CI) | ✅ | ✅ | ✅ | ✅ | ⚠️ (no `/sdcard/`) |
| macOS (dev) | ✅ | ✅ | ✅ | ✅ | ⚠️ (no `/sdcard/`) |
| Termux | ⚠️ | ✅ | ✅ | ✅ | ⚠️ (no `/sdcard/`) |
| Windows (WSL2) | ✅ | ✅ | ✅ | ✅ | ⚠️ (no `/sdcard/`) |

Before v1.0.0: Linux/macOS failed in `runShell` (path
`/system/bin/sh` did not exist).
After v1.0.0: `getSystemShell()` selects the right path
automatically.

**v1.1.0**: `memoryLimitForProfile` uses only the Go standard
library (`runtime/debug`) — no platform-specific behavior.

**v1.2.0**: The backup helpers (`backup_user_files`,
`restore_user_files`, `rotate_backups`) assume the
`/sdcard/dnscrypt-webui-backup/` path, which only exists on
Android. The CI runs them in a temporary directory via
`.github/workflows/upgrade-test.yml`. See that workflow for the
emulation setup.

**v1.3.0**: The SNAP-MANIFEST / SNAP-MTIME / ROT-* semantics
are implemented identically on all platforms — they depend only
on the filesystem's `stat` and `mv` behavior, which is portable
across Linux, macOS, and Android.

**v1.4.0**: The companion Android app APK is a static asset —
no platform-specific behavior on the server side.

---

## 3. ROMs

| ROM | Status | Notes |
|-----|:------:|-------|
| **Stock Android** | ✅ | Any version |
| **LineageOS** | ✅ | All versions |
| **Pixel Experience** | ✅ | Tested |
| **Evolution X** | ✅ | Tested |
| **crDroid** | ✅ | Tested |
| **AOSP Extended** | ✅ | Tested |
| **MIUI (Xiaomi)** | ⚠️ | Needs MIUI optimization disabled; backup dir works |
| **OneUI (Samsung)** | ⚠️ | May stop the service automatically |
| **ColorOS (OPPO)** | ⚠️ | Aggressive battery killer |
| **OxygenOS (OnePlus)** | 🟢 | Works |
| **HydrogenOS** | 🟢 | Works |
| **EMUI (Huawei)** | ⚠️ | May stop the service |
| **FuntouchOS (vivo)** | ⚠️ | Aggressive killing |
| **RealmeUI** | ⚠️ | Same |
| **Custom GSI** | 🟢 | Works |

### 3.1 ROM-specific Configuration

**MIUI**:
```text
Settings → Apps → Manage apps → DNSCrypt
→ Autostart: ON
→ Battery saver: No restrictions
→ Other permissions: Start in background
```

**OneUI**:
```text
Settings → Device care → Battery → Background usage limits
→ Never sleeping apps → Add DNSCrypt
```

**ColorOS**:
```text
Settings → Battery → App battery management → DNSCrypt
→ Allow background activity
→ Allow auto-launch
```

### 3.2 Setting Preservation — Evolution

**v1.0.0 – v1.1.0** (legacy mechanism):

On all supported ROMs, the installer preserved the 5 config files
using a backup in `/data/local/tmp/dnscrypt-upgrade-backup-$$`.
This was **deleted on reboot** and **lost on uninstall**.

**v1.2.0** (current mechanism):

The 10 defensive layers replace the legacy mechanism. The 5 files
are now preserved in `/sdcard/dnscrypt-webui-backup/`, which
**survives reboot**, **uninstall**, and **factory reset of
`/data`**.

**ROM-specific behavior**:

| ROM family | Backup directory behavior |
|---|---|
| AOSP / LineageOS | ✅ `/sdcard/` is FUSE-mounted; backup works |
| MIUI | ✅ Works; may need `MIUI optimization` disabled for reliable auto-backup |
| OneUI | ✅ Works |
| ColorOS / FuntouchOS | ⚠️ Aggressive battery killer may delay `service.sh`; backup still works |
| EMUI | ⚠️ Works |
| Custom GSI | ✅ Works |

**Verification after upgrade**:

```bash
# Verify the 5 preserved files survived
su -c "ls -la /sdcard/dnscrypt-webui-backup/current/"
# Expected: 5 files + .manifest.json

# Verify current profile
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
```

### 3.3 Bilingual WebUI on Different ROMs

The WebUI's language toggle works on **all ROMs** because it is a
purely browser-side feature. However, the **browser shipped with
the ROM** matters:

| ROM family | Default browser | Bilingual support |
|---|---|---|
| AOSP / LineageOS | AOSP Browser / Chrome | ✅ |
| MIUI | MIUI Browser (Chromium-based) | ✅ |
| OneUI | Samsung Internet | ✅ (recent versions) |
| ColorOS | Oppo Browser (Chromium-based) | ✅ |
| EMUI | Huawei Browser | ⚠️ (may need Chrome for full RTL) |
| Custom GSI | Chrome / Firefox | ✅ |

**Recommendation**: For best results with the Arabic (RTL) layout,
use **Chrome 88+**, **Firefox 92+**, or a recent version of
**Samsung Internet**.

---

## 4. Kernels

| Kernel | Version | Status |
|---|---|:---:|
| Linux 3.10 | 3.10 | ⚠️ |
| Linux 3.18 | 3.18 | ⚠️ |
| Linux 4.4 | 4.4 | 🟢 |
| Linux 4.9 | 4.9 | ✅ |
| Linux 4.14 | 4.14 | ✅ |
| Linux 4.19 | 4.19 | ✅ |
| Linux 5.4 | 5.4 | ✅ |
| Linux 5.10 | 5.10 | ✅ |
| Linux 5.15 | 5.15 | ✅ |
| Linux 6.1 | 6.1 | ✅ |
| Linux 6.6 | 6.6 | ✅ |

### 4.1 Kernel Requirements

| Feature | Minimum | In v1.4.0 |
|---|---|---|
| iptables-nat | 3.10 | — |
| nftables | 4.10 | — |
| netns | 3.0 | — |
| cgroup v2 | 4.5 | — |
| `/bin/sh` | 4.x+ | ✅ (Linux dev) |
| `sync.Once` (Go runtime) | 4.4+ | ✅ |
| `sync.Mutex` (Go runtime) | 3.x+ | ✅ |
| `debug.SetMemoryLimit` | 3.x+ (Go runtime) | ✅ (v1.1.0) |
| **`rename(2)` atomicity** | **3.x+** | **✅ (v1.2.0 transactions)** |
| **`sha256sum` (from coreutils)** | **Android 4.4+** | **✅ (v1.2.0 backup)** |
| **`restorecon` / `chcon`** | **SELinux kernel** | **✅ (v1.2.0 Layer 6)** |
| **`stat -c %Y` / `stat -f %m`** | **Any** | **✅ (v1.3.0 ROT-MTIME)** |

**Note**: `debug.SetMemoryLimit` was introduced in Go 1.19.
Since v1.1.0 uses Go 1.22, this is available on all supported
kernel versions — the kernel itself is not involved.

**v1.2.0 note**: The transactional upgrade system (Layer 4) relies
on POSIX-atomic `rename(2)` for its `commit_transaction` and
`rollback_transaction` operations. Every supported kernel provides
this.

**v1.3.0 note**: The rotation rewrite (ROT-MTIME) reads the mtime
of snapshot directories via `stat -c %Y` (GNU coreutils) with a
`stat -f %m` (BSD/Toybox) fallback. Both forms are supported by
every Linux kernel; the difference is in the user-space `stat`
implementation, not the kernel.

**v1.4.0 note**: The companion app runs in userspace; no kernel
prerequisites beyond API 21.

### 4.2 Kernel Issues

**Kernel 3.10–3.18:**
- May not support `--wait` in `iptables`.
- May not support `nft`.
- `getSystemShell()` works (selects `/system/bin/sh`).
- ⚠️ **`sha256sum` may be missing** — v1.2.0 falls back to size
  checks (advisory).

**Kernel 4.14:**
- Supports `nft` with some limitations.
- `manage_nftables` works but may need fallback.
- ✅ v1.2.0 backup fully supported.

---

## 5. Chipsets (SoCs)

| SoC | Architecture | Status |
|---|---|:---:|
| Snapdragon 8 Gen 3 | arm64-v8a | ✅ |
| Snapdragon 8 Gen 2 | arm64-v8a | ✅ |
| Snapdragon 888 | arm64-v8a | ✅ |
| Snapdragon 865 | arm64-v8a | ✅ |
| Snapdragon 7xx | arm64-v8a | ✅ |
| Snapdragon 6xx | arm64-v8a / armeabi-v7a | ✅ |
| Snapdragon 4xx | arm64-v8a / armeabi-v7a | ✅ |
| Exynos 2100+ | arm64-v8a | ✅ |
| Exynos 990 | arm64-v8a | ✅ |
| Exynos 9820 | arm64-v8a | ✅ |
| Dimensity 9000+ | arm64-v8a | ✅ |
| Dimensity 1000+ | arm64-v8a | ✅ |
| Helio G series | arm64-v8a / armeabi-v7a | 🟢 |
| Kirin 9000 | arm64-v8a | 🟢 |
| Kirin 980 | arm64-v8a | 🟢 |
| Tensor (Pixel 6+) | arm64-v8a | ✅ |
| Intel x86 (Atom) | x86 / x86_64 | 🟢 |

### 5.1 Architecture Support

| Architecture (ABI) | Binaries | Status |
|---|---|:---:|
| `arm64-v8a` | `*-arm64` | ✅ |
| `armeabi-v7a` | `*-arm` | ✅ |
| `x86_64` | `*-amd64` | ✅ |
| `x86` | `*-386` | ✅ |

### 5.2 Performance by Architecture

| Arch | `parsePrometheus` | `hasEndpoint` | Memory |
|---|:---:|:---:|:---:|
| arm64-v8a | ~50 µs | <100 ns | ~15 MB |
| armeabi-v7a | ~150 µs | <200 ns | ~15 MB |
| x86_64 | ~40 µs | <80 ns | ~15 MB |
| x86 | ~200 µs | <250 ns | ~15 MB |

**Result**: v1.4.0 does not strain weak devices.

### 5.3 RACE-1 Performance

| Arch | `rebuildBlocklist` (100K) | `rebuildBlocklist` (500K) |
|---|:---:|:---:|
| arm64-v8a | ~200 ms | ~1 s |
| armeabi-v7a | ~600 ms | ~3 s |
| x86_64 | ~180 ms | ~900 ms |
| x86 | ~800 ms | ~4 s |

**Note**: `rebuildMu` adds no noticeable overhead (coarse-grained lock).

### 5.4 Memory Profile by Device RAM (v1.1.0 — MEM-1)

**This is the recommended profile by device tier.** The WebUI
process sets a per-profile **soft** memory limit (see §1.6 for
MEM-1). Choosing a profile that matches your device's RAM
avoids GC thrashing on the WebUI process while keeping DNS
filtering effective.

| Device RAM | Recommended profile | WebUI soft limit | Filters |
|---|:---:|---:|:---:|
| **1 GB** | `light` | 80 MB | ~40K entries |
| **2 GB** | `normal` | 100 MB | ~120K entries |
| **3 GB** | `pro` (default) | 120 MB | ~250K entries |
| **4 GB** | `proplus` | 160 MB | ~350K entries |
| **6 GB+** | `ultimate` | 220 MB | ~500K entries |

#### 5.4.1 What "Soft Limit" Means

- `debug.SetMemoryLimit` is a **soft** limit.
- The Go runtime does **not** kill the process when the limit is
  reached — it runs GC more aggressively instead.
- Setting the limit too low → GC runs constantly → CPU waste → the
  WebUI appears slow or unresponsive even though it is not crashed.
- Setting the limit too high → RAM waste, especially on
  low-RAM devices.

**v1.1.0** chooses the limit automatically based on the profile.
No user configuration is needed.

**v1.4.0 note**: The companion Android app runs in a separate
process (Android app sandbox). Its memory footprint is not
governed by `debug.SetMemoryLimit`.

#### 5.4.2 What Happens on Under-Powered Devices

If you run `ultimate` on a 2 GB device:

- ✅ It will work.
- ⚠️ The WebUI may feel slow after long DNS activity.
- ⚠️ Battery consumption may increase slightly.
- ⚠️ Background apps might be killed by Android's LMK.

**Recommendation**: match the profile to the device RAM tier.

#### 5.4.3 What Happens on Over-Powered Devices

If you run `light` on a 12 GB device:

- ✅ It works perfectly.
- ⚠️ You lose blocking for many domains.
- ⚠️ No performance benefit versus `pro`.

**Recommendation**: choose based on filtering goals, not just
RAM.

#### 5.4.4 How to Change the Profile

```bash
# From the WebUI:
#   Select a profile → Apply.

# Or from the terminal:
su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# Verify (wait ~5 s after restart).
# Note: /api/* requires authentication if [monitoring_ui] has
# credentials. Define $CREDS first — see the top of this file.
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info" \
    | jq '{profile_key, memory_limit_mb}'
```

#### 5.4.5 How to Read the Value

```bash
# Via runtime_info (requires auth if [monitoring_ui] has credentials):
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'
# Expected: 80 / 100 / 120 / 160 / 220 (MB)

# Via status.sh (v1.1.0+) — no auth required, runs locally as root:
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh" | grep -A3 "Profile & Memory"

# Via the System Info panel:
#   Open the WebUI → scroll to "System Info" → expand.
#   Look for "Profile" and "Memory limit".
```

#### 5.4.6 Relation to v1.2.0 Backup Layer

The v1.2.0 backup layer preserves the **profile choice** as part
of the 5 preserved files (`selected_profile.txt`). This means:

- If you switch profiles and later restore from a backup, the
  restored profile determines the memory limit at startup.
- The `service.sh` auto-backup runs after `main.go` applies the
  memory limit, so the snapshot reflects the current profile.
- The `runtime_info.backups` object (v1.2.0, 7 fields) does **not**
  include the profile — it only reports the backup state. The
  profile is exposed separately via `runtime_info.profile_key`.

> **Note**: The backup compatibility matrix for Android versions
> was **moved to §2.5** in this revision. It no longer appears
> in this section.

<a name="55"></a>
### 5.5 (Moved) Backup Compatibility by Android Version

> **ℹ️ Redirect stub — N-5 anchor**
>
> This section was **moved to [§2.5](#25-backup-compatibility-by-android-version-v120)**
> in the v1.2.0 cycle (HARD-COMPAT-01).
>
> **Why a stub?** To keep the old URL fragment
> (`#55` — used by external links, bookmarks, and search-engine
> caches) resolving to a valid section instead of a broken
> anchor.
>
> **Where to find the content**: See **§2.5 (Backup
> Compatibility by Android Version)** — it now lives under the
> correct parent section (Android Versions), where it belongs
> topically.
>
> **No content is duplicated here.** This stub exists solely to
> preserve the anchor.

---

## 6. Firewall Backends

| Backend | Status | Priority |
|---|:---:|---|
| **nftables** | ✅ | 1 (preferred) |
| **iptables** | ✅ | 2 |
| **ip6tables** | ✅ | complementary |
| none | ⚠️ | no redirect |

### 6.1 Detection Logic

```bash
detect_firewall() {
    # 1. try nftables (inet then ip)
    if nft add table inet test; then
        return "nftables"
    fi

    # 2. try iptables -t nat
    if iptables -t nat -L -n; then
        return "iptables"
    fi

    # 3. none
    return "none"
}
```

### 6.2 Compatibility Matrix

| Backend | Android 5 | 8 | 10 | 12 | 14 |
|---|:---:|:---:|:---:|:---:|:---:|
| nftables | ❌ | ⚠️ | 🟢 | ✅ | ✅ |
| iptables | ✅ | ✅ | ✅ | ✅ | ✅ |
| ip6tables | ⚠️ | ✅ | ✅ | ✅ | ✅ |

### 6.3 Custom Chains

| Backend | Custom Chain Name | Cleanup Method |
|---|---|---|
| iptables | `DNSCRYPT_OUT` | `-F` + `-X` |
| ip6tables | `DNSCRYPT_OUT6` | `-F` + `-X` |
| nftables | `dnscrypt_filter` (table) | `delete table` |

**Benefits:**
- ✅ No orphans when `bootstrap_resolvers` change in the TOML.
- ✅ Public `OUTPUT` remains clean (two static rules only).
- ✅ Cleanup = full wipe in one operation (mathematically guaranteed).

### 6.4 Firewall + v1.0.0

**No firewall changes in v1.0.0.** Custom Chains are still used.

**Verify**:

```bash
# iptables
su -c "iptables -t nat -L DNSCRYPT_OUT -n"

# ip6tables
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n"

# no orphans in OUTPUT
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# → 0
```

### 6.5 Firewall + v1.1.0

**No firewall changes in v1.1.0.** Custom Chains, `manage_firewall`,
and `_inline_cleanup_firewall` are unchanged.

### 6.6 Firewall + v1.2.0

**No firewall changes in v1.2.0.** The 10 data-preservation
layers are orthogonal to the firewall architecture.

### 6.7 Firewall + v1.3.0 / v1.4.0

**No firewall changes in v1.3.0 or v1.4.0.**

- v1.3.0's DNS auto-start fix in `service.sh` calls
  `POST /api/ensure_running_service`, which triggers the same
  `manage_firewall 1` path as before.
- v1.4.0's companion app is a static asset — no firewall interaction.

**Verify v1.4.0 firewall is unaffected**:

```bash
# Custom Chain still exists after v1.4.0 upgrade
su -c "iptables -t nat -L DNSCRYPT_OUT -n"
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n"

# No orphans
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# → 0
```

---

## 7. Root Solutions

| Solution | Status | Min Version |
|---|:---:|---|
| Magisk | ✅ | 20.4 |
| Magisk Delta | ✅ | latest |
| KernelSU | ✅ | 0.9.0 |
| APatch | ✅ | latest |
| SuperSU | ❌ | Legacy |
| KingRoot | ❌ | Untrusted |
| Magisk Canary | ✅ | latest |

### 7.1 Magisk Features

| Feature | Min Version |
|---|---|
| ui_print | 20.0 |
| abort | 20.0 |
| set_perm_recursive | 20.0 |
| KernelSU API | 0.9.0 |
| **APatch compatibility** | **APatch (any)** — v1.2.0 |

### 7.2 Root + v1.4.0 Compatibility

| Feature | Magisk 20.4+ | KernelSU | APatch |
|---|:---:|:---:|:---:|
| Backup/Restore (v1.0.0) | ✅ | ✅ | ✅ (legacy) |
| Multi-source detection (v1.2.0) | ✅ | ✅ | ✅ |
| Persistent backup to `/sdcard/` (v1.2.0) | ✅ | ✅ | ✅ |
| SHA256 verification (v1.2.0) | ✅ | ✅ | ✅ |
| Transactional upgrades (v1.2.0) | ✅ | ✅ | ✅ |
| `modules_update/` fallback (v1.2.0) | n/a | n/a | ✅ |
| SELinux preservation (v1.2.0) | ✅ | ✅ | ✅ |
| Recovery mode (v1.2.0) | ✅ | ✅ | ✅ |
| Config migrations (v1.2.0) | ✅ | ✅ | ✅ |
| Auto-backup + rotation (v1.2.0) | ✅ | ✅ | ✅ |
| CLI diagnose (v1.2.0) | ✅ | ✅ | ✅ |
| `runtime_info.backups` (v1.2.0) | ✅ | ✅ | ✅ |
| Fix #1 verify | ✅ | ✅ | ✅ |
| Fix #2 verify | ✅ | ✅ | ✅ |
| NEW-1..NEW-6 verify | ✅ | ✅ | ✅ |
| RACE-1 + PORT-2 verify | ✅ | ✅ | ✅ |
| MEM-1 memory limit (v1.1.0) | ✅ | ✅ | ✅ |
| MEM-2 extended shellQuote (v1.1.0) | ✅ | ✅ | ✅ |
| MEM-3 MONITORING_UI_PORT (v1.1.0) | ✅ | ✅ | ✅ |
| Bilingual WebUI (v1.2.0) | ✅ | ✅ | ✅ |
| DNS auto-start fix (v1.3.0) | ✅ | ✅ | ✅ |
| PWA install button (v1.3.0) | ✅ | ✅ | ✅ |
| Live status LED (v1.3.0) | ✅ | ✅ | ✅ |
| SNAP-MANIFEST detection (v1.3.0) | ✅ | ✅ | ✅ |
| SNAP-MTIME sort (v1.3.0) | ✅ | ✅ | ✅ |
| ROT-MANIFEST + ROT-MTIME + ROT-PROTECT (v1.3.0) | ✅ | ✅ | ✅ |
| **Companion app route** (v1.4.0) | ✅ | ✅ | ✅ |
| **CodeQL fix (removeModule)** (v1.4.0) | ✅ | ✅ | ✅ |

**`customize.sh` works the same way on all Root solutions.**

**v1.4.0 note**: The companion app route (`GET /app-debug.apk`)
is served by `main.go` on all root solutions. It is a static
asset — the root solution does not affect it.

### 7.3 Verification on Device

```bash
# 1. Check version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.4.0

# 2. v1.2.0 backup layers present in customize.sh
su -c "grep -q 'CANDIDATE_SOURCES' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 1'"
su -c "grep -q 'PERSISTENT_BACKUP' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 2'"
su -c "grep -q 'begin_transaction' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 4'"
su -c "grep -q 'detect_root_solution' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 5'"
su -c "grep -q 'copy_with_context' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 6'"
su -c "grep -q 'RECOVERY_MODE' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 7'"

# 3. v1.2.0 backup helpers in functions.sh
su -c "grep -q 'backup_user_files' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && echo '✅ backup helper'"
su -c "grep -q 'restore_user_files' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && echo '✅ restore helper'"
su -c "grep -q 'rotate_backups' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && echo '✅ rotation helper'"

# 4. MEM-1 memory limit (from v1.1.0, still present).
#    HARD-COMPAT-04: verify via the API instead of strings|grep,
#    because Go binaries may be stripped with -s -w.
L=$(su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info" \
    | jq -r '.memory_limit_mb')
[ -n "$L" ] && [ "$L" -gt 0 ] && echo "✅ MEM-1 active (limit=$L MB)"

# 5. v1.4.0 companion app route (only when APK is present)
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk 2>/dev/null" \
    && echo "✅ Companion APK present" \
    || echo "ℹ️ Companion APK absent (optional)"

# 6. v1.4.0 iOS PWA logic removed
su -c "grep -q 'isIOSDevice' /data/adb/modules/dnscrypt-proxy-webui/web/index.html" \
    && echo "❌ iOS logic still present" \
    || echo "✅ iOS logic removed"

# 7. v1.4.0 install button is a direct <a download>
su -c "grep -q 'href=\"/app-debug.apk\"' /data/adb/modules/dnscrypt-proxy-webui/web/index.html" \
    && echo "✅ <a download> button present"

# 8. v1.3.0 server-side refinements — SNAP-MANIFEST
su -c "grep -q 'manifest.json' /data/adb/modules/dnscrypt-proxy-webui/proxy/main.go 2>/dev/null" \
    && echo "✅ SNAP-MANIFEST present (main.go)"

# 9. v1.3.0 — ROT-MANIFEST in functions.sh
su -c "grep -q 'manifest.json' /data/adb/modules/dnscrypt-proxy-webui/functions.sh" \
    && echo "✅ ROT-MANIFEST present (functions.sh)"
```

### 7.4 Runtime Verification

> **Authentication**: All `/api/*` examples below require `-u "$CREDS"`
> if `[monitoring_ui]` has credentials.

```bash
# 1. runtime_info ports (PORT-2)
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# 2. runtime_info profile + memory (MEM-1)
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'
# Expected: {"profile_key": "<profile>", "memory_limit_mb": <N>}

# 3. runtime_info backups (BAK-1 — 7 fields)
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'

# 4. Dashboard JSON (Fix #1)
curl -s -I -u "$CREDS" http://127.0.0.1:9091/api/metrics | grep Content-Type
# Expected: application/json; charset=utf-8

# 5. Login POST-only (NEW-1) — does not require auth to test
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: 405 Method Not Allowed

# 6. /readyz localhost-only (NEW-4) — from LAN:
curl -i "http://192.168.1.5:9091/readyz"
# Expected: 403 Forbidden

# 7. Companion APK route (v1.4.0)
curl -sI http://127.0.0.1:9090/app-debug.apk | grep -E 'HTTP|Content-Type|Cache-Control'
# Expected when APK present:
#   HTTP/1.1 200 OK
#   Content-Type: application/vnd.android.package-archive
#   Cache-Control: public, max-age=3600, immutable
# Expected when APK absent:
#   HTTP/1.1 404 Not Found

# 8. Bilingual WebUI (v1.2.0)
# Open http://127.0.0.1:9090 in a browser
# → WebUI loads in English by default
# → Click the langToggle button in the header
# → WebUI switches to Arabic (RTL layout)
# → Reload the page — the choice persists
```

---

## 8. Known Issues

### 8.1 Known Issues

| # | Issue | Affected | Workaround |
|---|---|---|---|
| 1 | Battery optimization stops the Watchdog | Android 8-9 | Add to battery exceptions |
| 2 | MIUI kills background | MIUI 11-14 | Autostart + Battery: No restrictions |
| 3 | ColorOS kills aggressively | ColorOS | Allow background activity |
| 4 | iptables `--wait` unsupported | Kernel < 3.14 | Uses fallback |
| 5 | nft `inet` family unsupported | Kernel < 4.10 | Falls back to `ip` family |
| 6 | DNS leak on IPv6 | Some ROMs | `block_ipv6 = true` |
| 7 | Hotspot DNS leak | Android < 11 | Requires additional rules |
| 8 | Private DNS conflict | Android 9+ | Disabled automatically |
| 9 | VPN apps conflict | Any VPN | They cannot run together |
| 10 | SELinux enforcing blocks | Rare | Requires permissive |
| 11 | Orphans from old versions in OUTPUT | Upgrade from very old versions | Cleaned automatically |
| 12 | Dashboard shows empty data | Pre-v1.0.0 | Update to v1.0.0+ |
| 13 | Basic Auth locked after 5 attempts | v1.0.0+ | Wait 15 min or restart WebUI |
| 14 | 404 for unknown action | v1.0.0+ | Update the script to expect 404 |
| 15 | CI Go build fails on Linux | Pre-v1.0.0 | Update to v1.0.0+ |
| 16 | Settings lost on upgrade | Pre-v1.0.0 | Update to v1.2.0+ (full protection) |
| 17 | Login GET rejected (405) | v1.0.0+ | Update integration to use POST |
| 18 | `/readyz` from LAN rejected (403) | v1.0.0+ | Use `/healthz` instead |
| 19 | Credentials change delay (60 s) | v1.0.0+ | Wait 60 s or restart WebUI |
| 20 | Blocklist rebuild may take time on long lists | v1.0.0+ | Normal — RACE-1 serializes rebuilds |
| 21 | WebUI slow on `ultimate` (pre-v1.1.0) | v1.0.0 | Update to v1.1.0+ (MEM-1) |
| 22 | `profile_key` mismatch (rare) | v1.1.0+ | Fix `selected_profile.txt` + restart |
| 23 | No auto-backup on uninstall | v1.1.0+ | Manual backup before uninstall (**superseded by v1.2.0**) |
| 24 | `memory_limit_mb` unexpected | v1.1.0+ | Check startup log + `selected_profile.txt` |
| 25 | Backup directory missing on some ROMs | v1.2.0+ | See §8.4.1 |
| 26 | Recovery mode runs twice on some devices | v1.2.0+ | See §8.4.2 |
| 27 | Orphan-txn preserved on uninstall | v1.2.0+ | Intentional — see §8.4.3 |
| 28 | `runtime_info.backups` returns 7 fields | v1.2.0+ | Additive — see §8.4.4 |
| 29 | Bilingual toggle partial RTL on old browsers | v1.2.0+ | See §8.4.5 |
| **30** | **Companion APK missing from release ZIP** | **v1.4.0+** | **See §8.5.1** |
| **31** | **iOS-specific PWA path removed** | **v1.4.0+** | **See §8.5.2** |
| **32** | **`backups.available` may differ from v1.2.0** | **v1.3.0+** | **See §8.6.1** |

### 8.2 VPN Interaction

**VPN + DNSCrypt = conflict:**
- The VPN app takes `redirect` priority.
- DNS queries go through the VPN instead of the module.
- **Solution**: use only one of them.

### 8.3 v1.1.0-specific Issues

**Issue #21 — WebUI slow on `ultimate` (pre-v1.1.0)**:

- **Symptom** (v1.0.0 only): After switching to `ultimate`, the
  WebUI becomes slow or unresponsive. CPU is high on the WebUI
  process. Dashboard loads take 10+ seconds.
- **Cause**: `debug.SetMemoryLimit(80 MB)` was hardcoded in
  v1.0.0. On `ultimate`, actual working set approaches 200 MB
  → GC thrashing.
- **Solution**: Update to **v1.1.0** or later — the limit is
  computed per profile (220 MB for `ultimate`).
- **Verify**:
  ```bash
  su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'"
  # Expected: 220 (for ultimate on v1.1.0+)
  ```

**Issue #22 — `profile_key` mismatch (rare)**:

- **Symptom**: `runtime_info.profile_key` does not match
  `selected_profile.txt`, or the memory limit does not match the
  expected value for the profile.
- **Cause**: The WebUI reads the profile file only at startup
  and after `POST /api/update_profile`.
- **Solution**: Restart the WebUI:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  ```

**Issue #23 — No auto-backup on uninstall**:

- **Symptom**: After uninstalling on v1.1.0, no backup directory
  is created.
- **Solution**: **Update to v1.2.0+** — the persistent backup at
  `/sdcard/dnscrypt-webui-backup/` survives uninstall. See §2.5.

**Issue #24 — `memory_limit_mb` unexpected**:

- **Symptom**: `runtime_info.memory_limit_mb` does not match the
  expected value for the active profile.
- **Solution**:
  1. Verify the profile file:
     ```bash
     su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
     ```
  2. Verify the startup log:
     ```bash
     su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
     ```
  3. Fix and restart.

### 8.4 v1.2.0-specific Issues

#### 8.4.1 Issue #25 — Backup directory missing on some ROMs

**Symptom**: After upgrading to v1.2.0, the persistent backup
directory `/sdcard/dnscrypt-webui-backup/` does not exist, and
`runtime_info.backups.available` is 0.

**Possible causes**:

1. **`/sdcard/` not mounted at install time** — the installer
   runs before the FUSE daemon is ready on some ROMs.
2. **`/sdcard/` is read-only** — rare.
3. **Storage full** — if `/sdcard/` has less than ~10 MB free.

**Diagnosis**:

```bash
su -c "ls /sdcard/"
su -c "ls -la /sdcard/dnscrypt-webui-backup/ 2>&1"
su -c "df -h /sdcard"
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
```

**Solutions**:
- **Cause 1**: Reboot. On the next boot, `service.sh` runs
  `auto_backup_if_needed` and creates the directory.
- **Cause 3**: Free up space and reboot.

#### 8.4.2 Issue #26 — Recovery mode runs twice on some devices

**Symptom**: After triggering recovery mode
(`touch recovery && reboot`), the recovery runs twice on some
ROMs.

**Diagnosis**:

```bash
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>/dev/null"
su -c "ls /data/adb/dnscrypt-recovery 2>/dev/null"
su -c "grep -i 'recovery' /data/local/tmp/dnscrypt_install.log | tail -10"
```

**Solution**:

```bash
su -c "rm -f /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "rm -f /data/adb/dnscrypt-recovery"
su -c "reboot"
```

#### 8.4.3 Issue #27 — Orphan-txn preserved on uninstall

**Symptom**: After uninstalling the module, an `orphan-txn-*/`
directory appears under `/sdcard/dnscrypt-webui-backup/`.

**Is this a bug?** No — it is **intentional**. The orphan may
contain the **only** copy of the user's data.

**Action**:

```bash
su -c "cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.state"
su -c "ls -la /sdcard/dnscrypt-webui-backup/orphan-txn-*/"
```

**DO NOT DELETE BLINDLY**.

#### 8.4.4 Issue #28 — `runtime_info.backups` returns 7 fields

**Symptom**: Clients written for v1.1.0 expected 5 fields.

**Is this a breaking change?** No — it is **strictly additive**.

**Client pattern**:

```bash
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
```

#### 8.4.5 Issue #29 — Bilingual toggle partial RTL on old browsers

**Symptom**: After clicking the `langToggle` button, the WebUI
switches to Arabic but the layout is only partially mirrored.

**Solutions**:
- Use Chrome 88+, Firefox 92+, or a recent version of Samsung
  Internet.
- Clear the Service Worker cache:
  - Chrome DevTools → Application → Storage → Clear site data.

### 8.5 v1.4.0-specific Issues

#### 8.5.1 Issue #30 — Companion APK missing from release ZIP

**Symptom**: After installing v1.4.0, the WebUI install button
leads to a 404 page, and `GET /app-debug.apk` returns
`404 Not Found`.

**Is this a bug?** **No** — the companion APK is **optional**.
The release pipeline fetches it at build time from
[gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app).
If the fetch step fails (transient GitHub issue), the module ZIP
is built **without** the APK, and the release notes document
this.

**Diagnosis**:

```bash
# 1. Check if the APK exists on the device
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk 2>&1"

# 2. Check the route directly
curl -sI http://127.0.0.1:9090/app-debug.apk | head -3
# Expected when absent: HTTP/1.1 404 Not Found
```

**Solutions**:

- **If you do not need the companion app**: No action required.
  The WebUI works fully without it.
- **If you want the companion app**:
  1. Download the APK directly from
     [gasciljh/dnscrypt-proxy-app/releases](https://github.com/gasciljh/dnscrypt-proxy-app/releases).
  2. Install it manually (sideload).
  3. Optionally, place it at
     `/data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk`
     to make the WebUI button work.

#### 8.5.2 Issue #31 — iOS-specific PWA path removed

**Symptom**: On iOS Safari, clicking the WebUI install button no
longer shows the "Add to Home Screen" instructions. It now shows
the unified "unsupported browser" modal (with a Play Store link
for Chrome).

**Is this a bug?** **No** — it is a deliberate v1.4.0 change.
The project is **Android-only**; the iOS-specific install path
was removed to reduce code complexity. The `<a download>` link
also does not make sense on iOS (Safari does not install APKs).

**Workaround for iOS users**:
- The WebUI remains **fully functional** in Safari on iOS — only
  the "install as app" flow is missing.
- To install on the home screen: use Safari's built-in
  "Add to Home Screen" option from the share menu manually.

**Reference**: `CHANGELOG.md` §[v1.4.0] — "Removed" section.

### 8.6 v1.3.0-specific Issues

#### 8.6.1 Issue #32 — `backups.available` may differ from v1.2.0

**Symptom**: After upgrading from v1.2.0 to v1.3.0 (or later),
`runtime_info.backups.available` shows a **larger** value than it
did on v1.2.0, even though no new snapshot was created.

**Is this a bug?** **No** — it is the intended v1.3.0 behavior
(SNAP-MANIFEST). The count rule changed from "name pattern match"
to "manifest presence":

- **v1.2.0**: a directory counted as a snapshot iff its name
  matched `^[0-9]{8}-[0-9]{6}-`.
- **v1.3.0+**: a directory counts iff it contains a
  `.manifest.json` file.

**Effect**:

| Scenario | v1.2.0 count | v1.3.0+ count |
|---|---|---|
| Standard snapshots (with manifests) | N | N |
| Custom-named snapshot (with manifest) | excluded | **included** |
| Name-matching directory (without manifest) | included | **excluded** |

For the standard toolchain's output, both rules produce the same
count. They differ only when a custom-named snapshot exists, or
when a directory matches the name pattern but lacks a manifest.

**Diagnosis**:

```bash
# 1. List all directories that have a manifest
su -c "for d in /sdcard/dnscrypt-webui-backup/*/; do \
    [ -f \"\$d/.manifest.json\" ] && basename \"\$d\"; \
done"

# 2. Compare with the API count
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available'
```

**Action**: **None required** — the new rule is intentional and
produces a more accurate count. If a manifest-less directory
should be a snapshot, write a minimal `.manifest.json` (`{}`) into
it (see `EMERGENCY.md` §8.6).

**Reference**: `docs/ARCHITECTURE.md` §4.13.1 (SNAP-MANIFEST).

---

## 9. Bug Report Template

When reporting an issue, use the following template:

```markdown
## Environment

- **Module version**: v1.4.0
- **Android version**: 14 (API 34)
- **ROM**: LineageOS 21
- **Kernel**: 5.15.94-lineageos
- **SoC**: Snapdragon 8 Gen 2
- **Root**: Magisk 27.0
- **Architecture**: arm64-v8a

## Profile & Memory (v1.1.0+)

- **Active profile**:
- **`profile_key`**:
- **`memory_limit_mb`**:

## Backup State (v1.2.0+)

- **Backup directory exists?** (yes/no):
- **`backups.available`**:
- **`backups.in_flight_txn`**:
- **`backups.orphan_txn`**:
- **`backups.last_stable`**:
- **`.upgrade_history.json` present?** (yes/no):
- **Manifest count check (v1.3.0+)**: did you run §8.6.1's diagnostic?

## Companion App State (v1.4.0+)

- **`GET /app-debug.apk` returns**: 200 / 404
- **WebUI install button visible?** (yes/no):
- **Companion app installed on device?** (yes/no):

## WebUI Language (v1.2.0+)

- **Default language on load**: (English / Arabic)
- **Toggle button present?** (yes/no):
- **Toggle works?** (yes/no):
- **Browser + version**:

## Issue Description

[Clear description of the problem]

## Steps to Reproduce

1. ...
2. ...
3. ...

## Expected Behavior

[What should happen]

## Actual Behavior

[What actually happens]

## Logs

<details>
<summary>dnscrypt_main.log</summary>

```text
[Paste content here]
```
</details>

<details>
<summary>status.sh --json</summary>

```json
[Paste content here]
```
</details>

<details>
<summary>status.sh --diagnose (v1.2.0+)</summary>

```text
[Paste the full diagnostic report here]
```
</details>

<details>
<summary>Firewall state</summary>

```text
$ iptables -t nat -L OUTPUT -n
$ iptables -t nat -L DNSCRYPT_OUT -n
$ ip6tables -t nat -L DNSCRYPT_OUT6 -n
```
</details>

<details>
<summary>Runtime Info</summary>

```json
$ curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info
```
</details>

## Additional Context

- [ ] Works on a previous version
- [ ] New in v1.1.0
- [ ] New in v1.2.0
- [ ] New in v1.3.0
- [ ] New in v1.4.0
- [ ] Intermittent
- [ ] Occurs during upgrade
- [ ] Occurs with the Arabic toggle
- [ ] Occurs with the companion app button
- [ ] Occurs with the backup layer (v1.2.0+)
- [ ] Occurs with rotation (v1.3.0+)
```

### 9.1 Quick Diagnostics Script

```bash
#!/bin/bash
# diagnose.sh — collect all information in one shot (v1.4.0)

CREDS=$(su -c "sed -n '/^\[monitoring_ui\]/,/^\[/p' \
    /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml \
  | grep -E '^(username|password)=' | cut -d\"'\" -f2 | tr '\n' ':' | sed 's/:$//'")

echo "=== Module Info ==="
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/module.prop"

echo ""
echo "=== System Info ==="
echo "Android: $(getprop ro.build.version.release)"
echo "Device:  $(getprop ro.product.model)"
echo "Kernel:  $(uname -r)"
echo "Arch:    $(getprop ro.product.cpu.abi)"

echo ""
echo "=== Status ==="
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json"

echo ""
echo "=== Profile & Memory ==="
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"

echo ""
echo "=== Backups (v1.2.0 / v1.3.0) ==="
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"

echo ""
echo "=== Snapshot manifests (v1.3.0 SNAP-MANIFEST) ==="
su -c "for d in /sdcard/dnscrypt-webui-backup/*/; do \
    [ -f \"\$d/.manifest.json\" ] && basename \"\$d\"; \
done"

echo ""
echo "=== Companion App (v1.4.0) ==="
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk 2>&1"
curl -sI http://127.0.0.1:9090/app-debug.apk | head -3

echo ""
echo "=== Firewall ==="
su -c "iptables -t nat -L DNSCRYPT_OUT -n 2>/dev/null | head -5"

echo ""
echo "=== Logs ==="
su -c "tail -50 /data/local/tmp/dnscrypt_main.log"

echo ""
echo "=== Full Diagnostic ==="
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

---

## 10. Contributing Reports

### 10.1 We Welcome

- Compatibility reports from rare devices.
- Testing on different or modified ROMs.
- Solutions and workarounds for known issues.
- Detailed logs.
- Dashboard reports on different browsers.
- Platform reports (Linux, macOS, WSL2).
- Performance reports.
- **v1.1.0+**: Memory-limit reports per device RAM tier.
- **v1.2.0+**: Backup/restore reports across devices and root
  solutions.
- **v1.2.0+**: Bilingual WebUI reports across browsers.
- **v1.3.0+**: Snapshot-detection (SNAP-MANIFEST) and rotation
  (ROT-*) reports across filesystems and clock conditions.
- **v1.4.0+**: Companion app installation reports on various ROMs.

### 10.2 How to Contribute

1. Test on your device.
2. Fill in the template above.
3. Open an Issue titled `[Compat] <Device> <Android>`.
4. Attach the logs.

### 10.3 Compatibility Testing for v1.4.0

**Recommended tests** — focused on the v1.4.0 additions, in
addition to the v1.2.0 tests (which remain valid).

#### 10.3.1 Companion App Installation Test

```bash
# 1. Verify the APK is served
curl -sI http://127.0.0.1:9090/app-debug.apk | grep -E 'HTTP|Content-Type'
# Expected: HTTP/1.1 200 OK + application/vnd.android.package-archive

# 2. Verify the WebUI install button
# Open the WebUI → click "📲 Install App"
# → The APK should download

# 3. Install the APK
# → Open the downloaded file → Install

# 4. Verify the app opens the WebUI
# → Launch the companion app → it should load http://127.0.0.1:9090
```

**Report**:
- APK served correctly? (yes/no)
- Install button visible? (yes/no)
- APK installed without error? (yes/no)
- App opens WebUI correctly? (yes/no)
- Android version + device model:

#### 10.3.2 CodeQL Fix Verification

```bash
# 1. Verify the fix in main.go
grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ Base() present"
grep -q 'filepath.Join(MODULES_DIR, name)' proxy/main.go && echo "✅ Join() present"

# 2. Verify the path-injection defence
# Send a malicious path to /api/remove_module
curl -X POST -b /tmp/cookies.txt \
    --data-urlencode "path=../../etc/passwd" \
    http://127.0.0.1:9090/api/remove_module | jq
# Expected: {"status": "error", "message": "Invalid module name"}
```

#### 10.3.3 iOS PWA Removal Verification

```bash
# 1. Verify iOS logic removed
grep -q 'isIOSDevice' web/index.html && echo "❌ still present" || echo "✅ removed"
grep -q 'pwaStepIos' web/index.html && echo "❌ still present" || echo "✅ removed"

# 2. Verify the unified unsupported message
grep -q 'pwaUnsupportedTitle' web/index.html && echo "✅ unified modal present"
```

**Report**:
- iOS logic gone? (yes/no)
- Unified modal shows on Firefox? (yes/no)
- Play Store link works? (yes/no)

#### 10.3.4 v1.2.0 Backup Regression Tests

Repeat §10.3.1–§10.3.3 from the v1.2.0 testing suite to ensure
the 10 defensive layers still work:

- In-place upgrade from v1.3.0 to v1.4.0.
- Recovery mode still consumes the trigger file.
- All 5 user files preserved.

#### 10.3.5 v1.3.0 Server-Side Refinements Verification (new)

> **HARD-COMPAT-V14-07**: This subsection is new in v1.4.0. It
> documents how to confirm on a real device that the v1.3.0
> server-side refinements (SNAP-MANIFEST, SNAP-MTIME,
> ROT-MANIFEST, ROT-MTIME, ROT-PROTECT) are active.

**A. Verify SNAP-MANIFEST (snapshot detection)**

```bash
# 1. Confirm the manifest requirement is documented in main.go
#    (via the header or via runtime behavior).
#    The Go binary is likely stripped, so use the runtime behavior:

# 2. Create a manifest-less directory with a valid snapshot name
su -c "mkdir -p /sdcard/dnscrypt-webui-backup/29991231-235959-test"
su -c "echo 'test' > /sdcard/dnscrypt-webui-backup/29991231-235959-test/webui.conf"

# 3. Read the count BEFORE
BEFORE=$(curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available')

# 4. Read the count AFTER (should be unchanged)
AFTER=$(curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available')
[ "$BEFORE" = "$AFTER" ] && echo "✅ SNAP-MANIFEST active (manifest-less dir ignored)" \
                        || echo "❌ SNAP-MANIFEST may not be active"

# 5. Add a manifest, then re-check
su -c "echo '{}' > /sdcard/dnscrypt-webui-backup/29991231-235959-test/.manifest.json"
AFTER2=$(curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available')
[ "$AFTER2" -gt "$AFTER" ] && echo "✅ SNAP-MANIFEST active (manifest-carrying dir counted)" \
                           || echo "❌ SNAP-MANIFEST may not be active"

# 6. Clean up
su -c "rm -rf /sdcard/dnscrypt-webui-backup/29991231-235959-test"
```

**Report**:
- Manifest-less directory ignored? (yes/no)
- Manifest-carrying directory counted? (yes/no)

**B. Verify SNAP-MTIME (mtime sort)**

```bash
# 1. Create two directories with names that sort in the OPPOSITE
#    order from their mtimes.
#    Directory A: name is "later" but mtime is earlier.
#    Directory B: name is "earlier" but mtime is later.

su -c "mkdir -p /sdcard/dnscrypt-webui-backup/29991231-235959-a"
su -c "touch -d '2020-01-01 00:00:00' /sdcard/dnscrypt-webui-backup/29991231-235959-a"
su -c "echo '{}' > /sdcard/dnscrypt-webui-backup/29991231-235959-a/.manifest.json"

su -c "mkdir -p /sdcard/dnscrypt-webui-backup/20200101-000000-b"
su -c "touch -d '2030-01-01 00:00:00' /sdcard/dnscrypt-webui-backup/20200101-000000-b"
su -c "echo '{}' > /sdcard/dnscrypt-webui-backup/20200101-000000-b/.manifest.json"

# 2. The newest by mtime should be "...b", not "...a"
NEWEST=$(curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups.last_backup_name')
case "$NEWEST" in
    *-b) echo "✅ SNAP-MTIME active (newest is mtime-based)" ;;
    *-a) echo "❌ SNAP-MTIME may not be active (name-based sort)" ;;
    *)   echo "ℹ️ Unexpected newest: $NEWEST" ;;
esac

# 3. Clean up
su -c "rm -rf /sdcard/dnscrypt-webui-backup/29991231-235959-a"
su -c "rm -rf /sdcard/dnscrypt-webui-backup/20200101-000000-b"
```

**Report**:
- `last_backup_name` follows mtime? (yes/no)

**C. Verify ROT-PROTECT (protected targets)**

```bash
# 1. Note the current .last_stable target
STABLE=$(cat /sdcard/dnscrypt-webui-backup/.last_stable 2>/dev/null)
echo "Current .last_stable: $STABLE"

# 2. Trigger a rotation with a low keep count
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; rotate_backups 5"

# 3. Verify the target still exists
if [ -n "$STABLE" ] && [ -d "/sdcard/dnscrypt-webui-backup/$STABLE" ]; then
    echo "✅ ROT-PROTECT active (.last_stable preserved)"
else
    echo "ℹ️ Target missing or not set — check manually"
fi
```

**Report**:
- `.last_stable` target preserved? (yes/no)
- Newest install preserved? (yes/no)

**D. Verify ROT-MANIFEST (manifest-based rotation)**

```bash
# 1. Create a manifest-less directory
su -c "mkdir -p /sdcard/dnscrypt-webui-backup/20200101-000000-nomanifest"
su -c "echo 'test' > /sdcard/dnscrypt-webui-backup/20200101-000000-nomanifest/webui.conf"

# 2. Trigger rotation
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; rotate_backups 5"

# 3. Verify the manifest-less directory still exists (ROT-MANIFEST ignores it)
if [ -d /sdcard/dnscrypt-webui-backup/20200101-000000-nomanifest ]; then
    echo "✅ ROT-MANIFEST active (manifest-less dir ignored by rotation)"
else
    echo "❌ ROT-MANIFEST may not be active (manifest-less dir was pruned)"
fi

# 4. Clean up
su -c "rm -rf /sdcard/dnscrypt-webui-backup/20200101-000000-nomanifest"
```

**Report**:
- Manifest-less directory preserved? (yes/no)

**Consolidated report** (copy into your Issue):

```
[SNAP-MANIFEST]  manifest-less ignored / manifest-carrying counted
[SNAP-MTIME]     last_backup_name follows mtime
[ROT-PROTECT]    .last_stable preserved / newest install preserved
[ROT-MANIFEST]   manifest-less dir ignored by rotation
Device: <model> / Android <ver> / ROM <name>
```

### 10.4 Hall of Fame

Compatibility contributors are listed in
[`HALL_OF_FAME.md`](HALL_OF_FAME.md#-compatibility-champions).

### 10.5 Platform Champions

New badge for those testing on **non-Android platforms** (Linux,
macOS, WSL2).

### 10.6 Memory Architect Badge (v1.1.0)

New badge for contributors who test the dynamic memory limit on
multiple RAM tiers.

### 10.7 Data Guardian Badge (v1.2.0)

New badge for contributors who test the 10 data-preservation
layers on **3+ devices** or **3+ root solutions**.

**Acceptance criteria**:

- ✅ Tested at least 3 scenarios from the recommended list.
- ✅ Reported the 7-field `backups` object for each scenario.
- ✅ Reported `status.sh --diagnose` output.
- ✅ Reported `dnscrypt_install.log` excerpts.

### 10.8 Companion App Champion Badge (v1.4.0)

New badge for contributors who test the companion Android app on
**3+ different ROMs** or **3+ device models**.

**Acceptance criteria**:

- ✅ Installed the companion APK from the WebUI install button on
  3+ devices/ROMs.
- ✅ Documented any installation issues or behaviour differences.
- ✅ Verified the app opens the WebUI correctly.
- ✅ Reported Android version, device model, and ROM.

**Reference**: [`HALL_OF_FAME.md`](HALL_OF_FAME.md).

### 10.9 Rotation Semantics Champion Badge (v1.4.0)

New badge for contributors who test the v1.3.0 rotation semantics
(§10.3.5) on **3+ filesystems** or under **3+ clock conditions**
(e.g. `ext4`, `f2fs`, FUSE, with/without clock drift).

**Acceptance criteria**:

- ✅ Ran the §10.3.5 A/B/C/D verification on 3+ configurations.
- ✅ Reported the consolidated report for each.
- ✅ Documented any edge case where the semantics did not match
  the documentation.

**Reference**: [`HALL_OF_FAME.md`](HALL_OF_FAME.md).

---

## 11. References

### 11.1 Specifications and Tools

- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [KernelSU Documentation](https://kernelsu.org/)
- [APatch Documentation](https://github.com/bmax121/APatch)
- [Android Version History](https://developer.android.com/about/versions)
- [Linux Kernel Releases](https://kernel.org/)
- [DNSCrypt-proxy Wiki](https://github.com/DNSCrypt/dnscrypt-proxy/wiki)
- [Netfilter iptables Custom Chains Best Practices](https://www.netfilter.org/documentation/)
- [Prometheus Text Format](https://prometheus.io/docs/instrumenting/exposition_formats/)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [Android FUSE — Storage Access Framework](https://source.android.com/docs/core/storage)
- [Android SELinux — `restorecon`](https://source.android.com/docs/security/features/selinux)
- [POSIX `rename(2)` atomicity](https://pubs.opengroup.org/onlinepubs/9699919799/functions/rename.html)
- [POSIX `stat(2)` — mtime](https://pubs.opengroup.org/onlinepubs/9699919799/functions/stat.html)

### 11.2 Project Documentation

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Full architecture (§3.10, §4.10) |
| [`docs/ARCHITECTURE.md §4.13`](ARCHITECTURE.md#413-v130-backend-additions) | **v1.3.0 server-side refinements (authoritative)** — SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT |
| [`docs/ARCHITECTURE.md §11.31–§11.34`](ARCHITECTURE.md) | v1.3.0 trade-offs (manifest, mtime, protections, boot-path) |
| [`docs/SECURITY.md`](SECURITY.md) | Security policy + Audit Corrections (§5.31, §5.32) |
| [`docs/API.md`](API.md) | Full HTTP API reference (§6.1.7) |
| [`docs/BACKUP.md`](BACKUP.md) | **Backup system reference (v1.2.0 + v1.3.0 semantics)** |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [`docs/UPGRADE.md`](UPGRADE.md) | Version upgrade guide (§3.1, §3.2) |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries management (Level 4) |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Comprehensive troubleshooting |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) | Contribution guide |
| [`docs/FAQ.md`](FAQ.md) | Frequently asked questions |
| [`docs/INSTALL.md`](INSTALL.md) | Installation guide |
| [`docs/BRANCHING.md`](BRANCHING.md) | Git branching strategy |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history (§[v1.2.0], §[v1.3.0], §[v1.4.0]) |
| [`README.md`](../README.md) | Project overview |

### 11.3 Companion App Repository

- **Repository**: https://github.com/gasciljh/dnscrypt-proxy-app
- **Releases**: https://github.com/gasciljh/dnscrypt-proxy-app/releases
- **Issues**: https://github.com/gasciljh/dnscrypt-proxy-app/issues

---

*Last updated: 2026-10-08*
*Version: v1.4.0 (Global Edition)*
*Author: gasciljh*
