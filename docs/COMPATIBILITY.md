# Compatibility Matrix — DNSCrypt Smart Filter

Comprehensive compatibility reference: Android, ROMs, Kernels, Chipsets, Firewalls.

**Version**: v1.3.0 (Global Edition)
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

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
>   # Define once per shell session
>   CREDS=$(su -c "sed -n '/^\[monitoring_ui\]/,/^\[/p' \
>       /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml \
>     | grep -E '^(username|password)=' | cut -d\"'\" -f2 | tr '\n' ':' | sed 's/:$//'")
>
>   # Then use it in any request
>   curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq
>   ```
>
>   Alternatively, read the credentials from
>   `/data/local/tmp/dnscrypt_credentials.txt` (mode 0600, root
>   only). The examples below are written **without** `-u` for
>   brevity; add `-u "$CREDS"` if you have credentials set.

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **New §2.5 — Backup Compatibility by Android Version.**
>     Moved from the old §5.5 (which was incorrectly placed
>     under "Chipsets (SoCs)"). Maps the v1.2.0 persistent
>     backup directory (`/sdcard/dnscrypt-webui-backup/`) to
>     the Android storage model: FUSE mount behavior,
>     external-storage permissions, and SELinux contexts.
>     Explains why the backup survives uninstall and factory
>     reset of `/data`.
>   • **New §8.4 — v1.2.0-specific Issues.** Documents five
>     new known issues that are specific to the
>     data-preservation release:
>       - `backup directory missing on some ROMs` (FUSE latency)
>       - `recovery mode runs twice on some devices`
>       - `orphan-txn preserved on uninstall` (intentional)
>       - `runtime_info.backups returns 7 fields` (client
>         compatibility)
>       - `bilingual toggle partial RTL on old browsers`
>   • **§1.3 (What's New) rewritten** to reflect the v1.2.0
>     feature set (10 defensive layers, persistent backup,
>     recovery mode, transactional upgrades, bilingual WebUI).
>   • **§1.4 (What Was New in v1.1.0) extracted** into its own
>     subsection (previously merged into §1.3).
>   • **§1.5 (What Was New in v1.0.0) renumbered**.
>   • **§1.6 (Bilingual WebUI) — new subsection.**
>   • **§2.6 (Platform Support) — renumbered** from §2.5.
>   • **§5.4 (Memory Profile by Device RAM) extended** with a
>     cross-reference to the v1.2.0 backup layer.
>   • **§7.2 (Root + Compatibility) extended** with the v1.2.0
>     verification table.
>   • **§8.1 (Known Issues) extended** with 5 new v1.2.0 rows.
>   • **§10.3 (v1.2.0 Compatibility Testing) — new section.**
>   • **§10.7 (Data Guardian Badge) — new section.**
>   • **§11.1 (References) updated** to include the v1.2.0
>     documentation set (`BACKUP.md`, `EMERGENCY.md`,
>     `UPGRADE.md`).
>   • **Global edition (English default + Arabic toggle)**:
>     the WebUI ships with English as the default language and
>     an in-page toggle (`langToggle`) that switches to Arabic.
>     The user's choice is stored in `localStorage['dnscrypt-lang']`.
>     Documentation remains English-only by project convention.

> **v1.2.0 (Global Edition) — Additional hardening in this revision**:
>   • 🛡️ **HARD-COMPAT-01** — `§5.5` (Backup Compatibility by
>     Android Version) has been **moved to §2.5**, under the
>     correct parent section (Android Versions). The old
>     placement under "Chipsets (SoCs)" was misleading — the
>     content has no relationship to SoC hardware. An HTML
>     anchor is retained at the old position (see §5.5 below)
>     so that any external link pointing at `#55` still
>     resolves to a valid section.
>   • 🛡️ **HARD-COMPAT-02** — All `curl` examples now carry an
>     authentication note at the top of the document. Previous
>     versions silently assumed no credentials, but
>     `customize.sh` generates them by default, so the examples
>     returned HTTP 401 on a fresh install.
>   • 🛡️ **HARD-COMPAT-03** — The `§2.5` CI verification note no
>     longer claims that `.github/workflows/upgrade-test.yml`
>     "emulates Android 5 through 15". The workflow runs on
>     `ubuntu-22.04` with mocked paths; it validates the
>     version-independent **shell logic**, not the Android
>     runtime.
>   • 🛡️ **HARD-COMPAT-04** — `§7.3` no longer uses
>     `strings dnscrypt-webui | grep memoryLimitForProfile` to
>     verify MEM-1. Go binaries may be stripped with `-s -w`
>     (removing symbol names); the check now queries the API
>     for the `memory_limit_mb` field, which is present
>     regardless of stripping.
>   • 🛡️ **HARD-COMPAT-05** — `§10.3.3` (Recovery Mode Test)
>     no longer uses `curl` immediately after `--restart`
>     without auth. It reads `selected_profile.txt` directly
>     instead, which requires no authentication.
>   • 🛡️ **HARD-COMPAT-06** — The `IE 11` row in the browser
>     compatibility tables now explicitly notes that IE 11 is a
>     **Windows desktop** browser (not available on Android),
>     and is listed for completeness only.
>   • 🛡️ **HARD-COMPAT-07** — Minor clarifications in
>     "Samsung Internet 16+" version notes.

> **v1.2.0 (Global Edition) — Corrections in this revision**:
>   • 🔧 **N-5 (anchor for the moved §5.5)** — The Backup
>     Compatibility matrix was moved from §5.5 to §2.5 in the
>     v1.2.0 cycle, but no anchor was placed at the old
>     position. Any external link to `#55` (or `#5-5`) was
>     therefore broken. A stub section (**§5.5 (Moved)**) now
>     lives at the end of §5, containing:
>       - an HTML anchor `<a name="55"></a>` (for legacy
>         `#55` links),
>       - a plain-language pointer to the new §2.5 location,
>       - a redirect note for both internal and external
>         references.
>     The stub is intentionally minimal and contains no
>     duplicated content — the single source of truth for
>     backup compatibility remains §2.5.

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

### 1.3 What's New in v1.2.0

**Compatibility-relevant changes**:

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
| **12** | **Bilingual WebUI (English default + Arabic toggle)** | ✅ Client-side only. No API impact. See §1.6. |

**Base compatibility**: no change in system requirements.

### 1.4 What Was New in v1.1.0

**Compatibility-relevant changes** (for reference):

| # | Change | Compatibility impact |
|:-:|---|---|
| **1** | **MEM-1: Dynamic memory limit per profile** | ✅ Improves performance on light profiles (less GC) and heavy profiles (no GC thrashing). See §5.4. |
| **2** | **MEM-2: Extended `shellQuote` (24 chars)** | ⚪ No impact on user |
| **3** | **MEM-3: `MONITORING_UI_PORT` constant** | ⚪ No impact on user |
| **4** | **`runtime_info` new fields** (`profile_key`, `memory_limit_mb`) | ✅ Displayed in System Info panels |
| **5** | **`get_profile` new field** (`memory_limit_mb`) | ✅ Additive — clients unaffected |
| **6** | **Uninstall no longer creates backup** | ⚠️ Manual backup recommended — but **superseded by v1.2.0** (see §2.5). |

### 1.5 What Was New in v1.0.0

**Compatibility-relevant changes** (for reference):

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

### 1.6 Bilingual WebUI (v1.2.0)

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

**Android 8-9**:
- ✅ Works.
- ⚠️ Battery optimization may stop the Watchdog.
- 💡 **Solution**: add to exceptions.
- ✅ **v1.2.0 backup works** — same FUSE mount.
- ✅ Bilingual WebUI works.

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

### 2.4 Dashboard — v1.2.0 Fields

The System Info panel in both `index.html` and `dashboard.html`
now displays **six additional rows** populated from the new
`backups` object:

| Row | Field | Type |
|---|---|---|
| **Backups** | `backups.available` | int |
| **Latest Backup** | `backups.last_backup_name` | string \| null |
| **Last Stable** | `backups.last_stable` | string \| null |
| **In-flight Txn** | `backups.in_flight_txn` | int |
| **Orphan Txn** | `backups.orphan_txn` | int |
| **Backup Path** | `backups.path` | string |

**Compatibility**:
- ✅ All modern browsers render the new rows.
- ✅ No new browser API — the fields are simple text rendered
  from the existing JSON response.
- ⚠️ IE 11: not supported.

### 2.5 Backup Compatibility by Android Version (v1.2.0 — new)

> **Placement note (HARD-COMPAT-01)**: This section was previously
> located at §5.5, under "Chipsets (SoCs)" — a misleading
> placement that has been corrected. The content has no
> relationship to SoC hardware; it belongs with the Android
> version matrix. See §5.5 for the redirect stub and the legacy
> `#55` anchor.

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
   check and relies on size + non-empty checks only. The backup
   is still created and restored — just without checksum
   verification.

3. **`restorecon` vs `chcon`**: `restorecon` reads the system's
   `file_contexts` database and applies the correct SELinux
   context. `chcon` sets the context manually. The v1.2.0
   `copy_with_context` helper prefers `restorecon` and falls
   back to `chcon u:object_r:magisk_file:s0` if it is missing.

**Verified by CI (HARD-COMPAT-03)**: The
`.github/workflows/upgrade-test.yml` matrix (42 scenarios)
exercises the **shell logic** of the backup layer on
`ubuntu-22.04`, with mocked Android paths
(`/data/adb/modules/...`, `/sdcard/...`) and scenario-specific
tool availability (e.g. missing `sha256sum`, missing
`restorecon`). This validates the version-independent **shell
code**; it does **not** emulate specific Android versions —
that requires real devices (see §10.3).

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

**Legacy upgrade check** (v1.0.0/v1.1.0 users):

```bash
# Look for the legacy backup from the OLD mechanism
su -c "ls -la /data/local/tmp/dnscrypt-upgrade-backup-*"
# May be present if the upgrade from v1.1.0 happened via the old path
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

| Feature | Minimum | In v1.2.0 |
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

**Note**: `debug.SetMemoryLimit` was introduced in Go 1.19.
Since v1.1.0 uses Go 1.22, this is available on all supported
kernel versions — the kernel itself is not involved.

**v1.2.0 note**: The transactional upgrade system (Layer 4) relies
on POSIX-atomic `rename(2)` for its `commit_transaction` and
`rollback_transaction` operations. Every supported kernel provides
this.

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

**Result**: v1.2.0 does not strain weak devices.

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
process sets a per-profile **soft** memory limit (see §1.4 for
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
> This section was **moved to [§2.5](#25-backup-compatibility-by-android-version-v120--new)**
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
> **What was the problem with the old location?** The content
> was incorrectly placed under "Chipsets (SoCs)". It has no
> relationship to SoC hardware; its topic is Android version
> compatibility for the persistent backup directory
> (`/sdcard/dnscrypt-webui-backup/`).
>
> **No content is duplicated here.** This stub exists solely to
> preserve the anchor. The single source of truth for backup
> compatibility remains §2.5.

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

*Compatibility: same as normal iptables/nftables constraints (see §6.2).*

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

**v1.1.0 additions relevant to firewall scripts**:

| Change | Impact on firewall |
|---|---|
| MEM-2 (extended `shellQuote`) | ✅ More robust when passing `MODDIR` to `runShell` for iptables commands |
| MEM-3 (`MONITORING_UI_PORT` constant) | ⚪ Unrelated to firewall |
| MEM-1 (memory limit) | ⚪ Unrelated to firewall |

### 6.6 Firewall + v1.2.0

**No firewall changes in v1.2.0.** The 10 data-preservation
layers are orthogonal to the firewall architecture:

| Layer | Interacts with firewall? |
|:-:|---|
| 1 (multi-source detection) | ❌ No |
| 2 (persistent backup) | ❌ No — writes to `/sdcard/`, not kernel |
| 3 (integrity verification) | ❌ No |
| 4 (transactional upgrades) | ❌ No |
| 5 (root-solution compat) | ❌ No |
| 6 (SELinux preservation) | ❌ No — file contexts only |
| 7 (recovery mode) | ❌ No |
| 8 (config migrations) | ❌ No |
| 9 (automation + rotation) | ❌ No |
| 10 (observability) | ❌ No |
| Bilingual WebUI | ❌ No — client-side only |

**Verify v1.2.0 firewall is unaffected**:

```bash
# Custom Chain still exists after v1.2.0 upgrade
su -c "iptables -t nat -L DNSCRYPT_OUT -n"
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n"

# No orphans
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# → 0

# v1.2.0 diagnostic tool still runs
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
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

### 7.2 Root + v1.2.0 Compatibility

| Feature | Magisk 20.4+ | KernelSU | APatch |
|---|:---:|:---:|:---:|
| Backup/Restore (v1.0.0) | ✅ | ✅ | ✅ (legacy) |
| **Multi-source detection (v1.2.0)** | **✅** | **✅** | **✅** |
| **Persistent backup to `/sdcard/` (v1.2.0)** | **✅** | **✅** | **✅** |
| **SHA256 verification (v1.2.0)** | **✅** | **✅** | **✅** |
| **Transactional upgrades (v1.2.0)** | **✅** | **✅** | **✅** |
| **`modules_update/` fallback (v1.2.0)** | **n/a** | **n/a** | **✅** |
| **SELinux preservation (v1.2.0)** | **✅** | **✅** | **✅** |
| **Recovery mode (v1.2.0)** | **✅** | **✅** | **✅** |
| **Config migrations (v1.2.0)** | **✅** | **✅** | **✅** |
| **Auto-backup + rotation (v1.2.0)** | **✅** | **✅** | **✅** |
| **CLI diagnose (v1.2.0)** | **✅** | **✅** | **✅** |
| **`runtime_info.backups` (v1.2.0)** | **✅** | **✅** | **✅** |
| Fix #1 verify | ✅ | ✅ | ✅ |
| Fix #2 verify | ✅ | ✅ | ✅ |
| NEW-1..NEW-6 verify | ✅ | ✅ | ✅ |
| RACE-1 + PORT-2 verify | ✅ | ✅ | ✅ |
| MEM-1 memory limit (v1.1.0) | ✅ | ✅ | ✅ |
| MEM-2 extended shellQuote (v1.1.0) | ✅ | ✅ | ✅ |
| MEM-3 MONITORING_UI_PORT (v1.1.0) | ✅ | ✅ | ✅ |
| **Bilingual WebUI (v1.2.0)** | **✅** | **✅** | **✅** |

**`customize.sh` works the same way on all Root solutions.**

**v1.2.0 note**: The `detect_root_solution()` function (Layer 5)
adapts the candidate source list based on the detected root
solution. In particular:

- **Magisk / KernelSU**: The module folder is kept during
  in-place upgrades. The standard candidate list suffices.
- **APatch**: The module folder may be **deleted before**
  `customize.sh` runs. The installer checks
  `/data/adb/modules_update/dnscrypt-proxy-webui/proxy` as a
  fallback source. This is the APatch-specific addition to
  Layer 1.

### 7.3 Verification on Device

```bash
# 1. Check version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.2.0

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
#    Define $CREDS first (see the top of this file).
L=$(su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info" \
    | jq -r '.memory_limit_mb')
[ -n "$L" ] && [ "$L" -gt 0 ] && echo "✅ MEM-1 active (limit=$L MB)"

# 5. v1.2.0 Bilingual WebUI check
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && echo '✅ index toggle'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html && echo '✅ dashboard toggle'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/offline.html && echo '✅ offline toggle'"
su -c "grep -q 'en:' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && grep -q 'ar:' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && echo '✅ EN+AR present'"
```

### 7.4 Runtime Verification

> **Authentication**: All `/api/*` examples below require `-u "$CREDS"`
> if `[monitoring_ui]` has credentials. Define `$CREDS` first — see
> the top of this file.

```bash
# 1. runtime_info ports (PORT-2)
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# 2. runtime_info profile + memory (MEM-1)
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'
# Expected: {"profile_key": "<profile>", "memory_limit_mb": <N>}

# 3. runtime_info backups (BAK-1 — 7 fields)
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
# Expected:
# {
#   "available": N,
#   "in_flight_txn": N,
#   "orphan_txn": N,
#   "last_backup": "...",
#   "last_backup_name": "...",
#   "last_stable": "...",
#   "path": "/sdcard/dnscrypt-webui-backup"
# }

# 4. Dashboard JSON (Fix #1)
curl -s -I -u "$CREDS" http://127.0.0.1:9091/api/metrics | grep Content-Type
# Expected: application/json; charset=utf-8

# 5. Login POST-only (NEW-1) — does not require auth to test
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: 405 Method Not Allowed

# 6. /readyz localhost-only (NEW-4) — from LAN:
curl -i "http://192.168.1.5:9091/readyz"
# Expected: 403 Forbidden

# 7. Bilingual WebUI (v1.2.0)
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
| 16 | Settings lost on upgrade | Pre-v1.0.0 | Update to v1.2.0 (full protection) |
| 17 | Login GET rejected (405) | v1.0.0+ | Update integration to use POST |
| 18 | `/readyz` from LAN rejected (403) | v1.0.0+ | Use `/healthz` instead |
| 19 | Credentials change delay (60 s) | v1.0.0+ | Wait 60 s or restart WebUI |
| 20 | Blocklist rebuild may take time on long lists | v1.0.0+ | Normal — RACE-1 serializes rebuilds |
| 21 | WebUI slow on `ultimate` (pre-v1.1.0) | v1.0.0 | Update to v1.1.0+ (MEM-1) |
| 22 | `profile_key` mismatch (rare) | v1.1.0+ | Fix `selected_profile.txt` + restart |
| 23 | No auto-backup on uninstall | v1.1.0+ | Manual backup before uninstall (**superseded by v1.2.0**) |
| 24 | `memory_limit_mb` unexpected | v1.1.0+ | Check startup log + `selected_profile.txt` |
| **25** | **Backup directory missing on some ROMs** | **v1.2.0+** | **See §8.4.1** |
| **26** | **Recovery mode runs twice on some devices** | **v1.2.0+** | **See §8.4.2** |
| **27** | **Orphan-txn preserved on uninstall** | **v1.2.0+** | **Intentional — see §8.4.3** |
| **28** | **`runtime_info.backups` returns 7 fields** | **v1.2.0+** | **Additive — see §8.4.4** |
| **29** | **Bilingual toggle partial RTL on old browsers** | **v1.2.0+** | **See §8.4.5** |

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
- **Solution**: Update to **v1.1.0** or **v1.2.0** — the limit
  is now computed per profile (220 MB for `ultimate`).
- **Verify**:
  ```bash
  # Define $CREDS first — see the top of this file
  su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'"
  # Expected: 220 (for ultimate on v1.1.0+)
  ```
- **Reference**: [SECURITY.md](SECURITY.md) §5.30.1;
  [TROUBLESHOOTING.md](TROUBLESHOOTING.md) §6.10.

**Issue #22 — `profile_key` mismatch (rare)**:

- **Symptom**: `runtime_info.profile_key` does not match
  `selected_profile.txt`, or the memory limit does not match the
  expected value for the profile.
- **Cause**: The WebUI reads the profile file only at startup
  and after `POST /api/update_profile`. Direct edits to the file
  are not monitored.
- **Solution**: Restart the WebUI:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  ```
- **Verify**:
  ```bash
  # Define $CREDS first — see the top of this file
  diff <(curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key') \
       <(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
  # Expected: no diff
  ```
- **Reference**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) §5.14.

**Issue #23 — No auto-backup on uninstall**:

- **Symptom**: After uninstalling on v1.1.0, no backup directory
  is created.
- **Cause**: Intentional — v1.1.0 removed the auto-backup on
  uninstall.
- **Solution**: **Update to v1.2.0** — the persistent backup at
  `/sdcard/dnscrypt-webui-backup/` survives uninstall and is
  preserved automatically. See §2.5.
- **Reference**: [UPGRADE.md](UPGRADE.md) §3.2.

**Issue #24 — `memory_limit_mb` unexpected**:

- **Symptom**: `runtime_info.memory_limit_mb` does not match the
  expected value for the active profile.
- **Cause**: The startup log may show an error, or the profile
  file may be missing/invalid.
- **Solution**:
  1. Verify the profile file:
     ```bash
     su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
     ```
  2. Verify the startup log:
     ```bash
     su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
     ```
  3. If either is wrong, fix and restart:
     ```bash
     su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
     su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
     ```
- **Reference**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) §4.12, §5.14.

### 8.4 v1.2.0-specific Issues

#### 8.4.1 Issue #25 — Backup directory missing on some ROMs

**Symptom**: After upgrading to v1.2.0, the persistent backup
directory `/sdcard/dnscrypt-webui-backup/` does not exist, and
`runtime_info.backups.available` is 0.

**Possible causes**:

1. **`/sdcard/` not mounted at install time** — the installer
   runs before the FUSE daemon is ready on some ROMs.
2. **`/sdcard/` is read-only** — rare, but possible if the user
   mounted external storage with restrictive flags.
3. **Storage full** — if `/sdcard/` has less than ~10 MB free,
   the backup dir cannot be created.

**Diagnosis**:

```bash
# 1. Check /sdcard/ is mounted
su -c "ls /sdcard/"
# Expected: the standard Android directory list (DCIM, Download, ...)

# 2. Check the backup directory
su -c "ls -la /sdcard/dnscrypt-webui-backup/ 2>&1"
# Expected (v1.2.0+): current/, <ts>-<version>-<pid>/, .last_stable, ...

# 3. Check storage
su -c "df -h /sdcard"
# Expected: at least 10 MB free

# 4. Check runtime_info (define $CREDS first — see top of file)
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
```

**Solutions**:

- **Cause 1**: Reboot. On the next boot, `service.sh` runs
  `auto_backup_if_needed` and creates the directory.
- **Cause 2**: Check the ROM's FUSE configuration. This is rare;
  file an issue.
- **Cause 3**: Free up space and reboot. The auto-backup will
  run on the next boot.

**Reference**: [BACKUP.md](BACKUP.md) §10.1;
[TROUBLESHOOTING.md](TROUBLESHOOTING.md) §7.8.

#### 8.4.2 Issue #26 — Recovery mode runs twice on some devices

**Symptom**: After triggering recovery mode
(`touch recovery && reboot`), the recovery runs twice on some
ROMs, or the recovery trigger file reappears after the first
boot.

**Possible causes**:

1. **Two trigger files present** — the module checks both
   `$MODPATH/recovery` and `/data/adb/dnscrypt-recovery`. If
   both exist, both are consumed in the same boot, which is
   fine. But if only one is removed by mistake, the other
   re-triggers on the next install.
2. **Persistent trigger file** — some root managers restore
   files from a persistent directory on boot, effectively
   re-creating the trigger.
3. **A second install was queued** — some managers queue the
   module install, causing `customize.sh` to run twice.

**Diagnosis**:

```bash
# 1. Check both trigger files
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>/dev/null"
su -c "ls /data/adb/dnscrypt-recovery 2>/dev/null"
# Expected after a successful recovery: both should be gone

# 2. Check the install log
su -c "grep -i 'recovery' /data/local/tmp/dnscrypt_install.log | tail -10"
# Expected: one "RECOVERY MODE ACTIVATED" line per install
```

**Solutions**:

- Remove both trigger files manually:
  ```bash
  su -c "rm -f /data/adb/modules/dnscrypt-proxy-webui/recovery"
  su -c "rm -f /data/adb/dnscrypt-recovery"
  su -c "reboot"
  ```
- If the trigger file reappears, check your root manager for a
  persistent-file restoration feature.

**Reference**: [EMERGENCY.md](EMERGENCY.md) §9;
[BACKUP.md](BACKUP.md) §10.

#### 8.4.3 Issue #27 — Orphan-txn preserved on uninstall

**Symptom**: After uninstalling the module, an `orphan-txn-*/`
directory appears under `/sdcard/dnscrypt-webui-backup/`.

**Is this a bug?** No — it is **intentional**.

**What it means**: An `orphan-txn-*` directory is a **preserved
unfinished transaction**. It was created when `uninstall.sh`
found a `txn-*` directory with `.state=START` — a signal that an
install was interrupted mid-flight. The orphan may contain the
**only** copy of the user's data.

**Action**:

```bash
# 1. Inspect the state
su -c "cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.state"
# Expected: START

# 2. Inspect the contents
su -c "ls -la /sdcard/dnscrypt-webui-backup/orphan-txn-*/"

# 3. Inspect the manifest (if present)
su -c "cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.manifest.json 2>/dev/null | jq"
```

**DO NOT DELETE BLINDLY**. See
[BACKUP.md](BACKUP.md) §10.5 and
[EMERGENCY.md](EMERGENCY.md) §4.5 for the full guidance.

**Reference**: [BACKUP.md](BACKUP.md) §10.5.

#### 8.4.4 Issue #28 — `runtime_info.backups` returns 7 fields

**Symptom**: Clients written for v1.1.0 expected
`runtime_info.backups` to have **5 fields**
(`available`, `last_backup`, `last_backup_name`, `last_stable`,
`path`). In v1.2.0, it has **7 fields** (adding `in_flight_txn`
and `orphan_txn`).

**Is this a breaking change?** No — it is **strictly additive**.

**Client compatibility**:

- ✅ **JSON parsers** (any language): unaffected. New fields are
  ignored by code that only reads the 5 original fields.
- ⚠️ **String indexing / regex-based parsers**: may break if they
  assume the object ends at a specific position. This is not
  recommended and is not supported.

**Recommended client pattern**:

```bash
# Define $CREDS first — see top of file

# Correct — read only what you need
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info \
    | jq '.backups.available'

# Correct — read the whole object
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info \
    | jq '.backups'

# WRONG — assume a fixed field count
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info \
    | grep -o '"backups":{[^}]*}'
```

**Reference**: [API.md](API.md) §6.1.7;
[UPGRADE.md](UPGRADE.md) §5.9.

#### 8.4.5 Issue #29 — Bilingual toggle partial RTL on old browsers

**Symptom**: After clicking the `langToggle` button, the WebUI
switches to Arabic but the layout is only partially mirrored
(e.g. some arrows or margins do not flip).

**Possible causes**:

1. **Browser version too old** — older browsers may not fully
   support CSS logical properties or `:dir()` selectors.
2. **Cached old CSS** — a stale Service Worker cache serving an
   older CSS block.

**Browser compatibility** (from §1.6):

| Browser | Full RTL support |
|---|:---:|
| Chrome 88+ | ✅ |
| Firefox 92+ | ✅ |
| Safari 15+ | ✅ |
| Samsung Internet (recent) | ✅ |
| Firefox 88–91 | ⚠️ (partial) |
| Safari 14 | ⚠️ (partial) |
| IE 11 (Windows desktop only) | ❌ |

**Solutions**:

- **Cause 1**: Use Chrome 88+, Firefox 92+, or a recent version
  of Samsung Internet for the best experience.
- **Cause 2**: Clear the Service Worker cache:
  - Chrome DevTools → Application → Storage → Clear site data.
  - Then reload.

**Reference**: [ARCHITECTURE.md](ARCHITECTURE.md) §6.7;
[docs/FAQ.md](FAQ.md) Q9.

---

## 9. Bug Report Template

When reporting an issue, use the following template:

```markdown
## Environment

- **Module version**: v1.2.0
- **Android version**: 14 (API 34)
- **ROM**: LineageOS 21
- **Kernel**: 5.15.94-lineageos
- **SoC**: Snapdragon 8 Gen 2
- **Root**: Magisk 27.0
- **Architecture**: arm64-v8a

## Profile & Memory (v1.1.0+)

- **Active profile** (from `selected_profile.txt`):
- **`profile_key`** (from `runtime_info`):
- **`memory_limit_mb`** (from `runtime_info`):
- **Expected limit for the profile** (see §5.4):

## Backup State (v1.2.0)

- **Backup directory exists?** (yes/no):
- **`backups.available`**:
- **`backups.in_flight_txn`**:
- **`backups.orphan_txn`**:
- **`backups.last_stable`**:
- **`.upgrade_history.json` present?** (yes/no):

## WebUI Language (v1.2.0)

- **Default language on load**: (English / Arabic)
- **Toggle button present in header?** (yes/no)
- **Toggle switches languages correctly?** (yes/no)
- **RTL layout correct after switching?** (yes/no)
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
[Paste content here — include the "dynamic memory limit" line if present]
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
<summary>Dashboard state</summary>

```json
$ curl -s -u "$CREDS" http://127.0.0.1:9091/api/metrics
{
  "generated_at": "...",
  "total_queries": ...,
  "blocked_queries": ...,
  "cache_stats": {...}
}
```
</details>

<details>
<summary>STATUS_FILE</summary>

```text
$ cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status
ON
```
</details>

<details>
<summary>Runtime Info</summary>

```json
$ curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info
{
  "version": "v1.2.0",
  "webui_port": "9090",
  "dashboard_port": "9091",
  "profile_key": "pro",
  "memory_limit_mb": 120,
  "backups": {
    "available": 5,
    "in_flight_txn": 0,
    "orphan_txn": 0,
    "last_backup": "...",
    "last_backup_name": "...",
    "last_stable": "...",
    "path": "/sdcard/dnscrypt-webui-backup"
  },
  ...
}
```
</details>

## Additional Context

- [ ] Works on a previous version
- [ ] New in v1.1.0
- [ ] New in v1.2.0
- [ ] Intermittent
- [ ] Occurs during upgrade
- [ ] Occurs with the Arabic toggle

## Screenshots

[If possible — attach both English and Arabic screenshots for
bilingual issues]
```

### 9.1 Quick Diagnostics Script

```bash
#!/bin/bash
# diagnose.sh — collect all information in one shot (v1.2.0)
#
# Authentication: the /api/* calls below require credentials if
# [monitoring_ui] has them set (which customize.sh does by
# default). Derive them once at the top of the script.

# Derive credentials from the TOML file (root required)
CREDS=$(su -c "sed -n '/^\[monitoring_ui\]/,/^\[/p' \
    /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml \
  | grep -E '^(username|password)=' | cut -d\"'\" -f2 | tr '\n' ':' | sed 's/:$//'")

echo "=== Module Info ==="
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/module.prop"

echo ""
echo "=== System Info ==="
echo "Android: $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk))"
echo "Device:  $(getprop ro.product.model)"
echo "Kernel:  $(uname -r)"
echo "SoC:     $(getprop ro.product.board)"
echo "Arch:    $(getprop ro.product.cpu.abi)"

echo ""
echo "=== Root Info ==="
which magisk 2>/dev/null && magisk -V
which ksud 2>/dev/null && ksud -V

echo ""
echo "=== Status ==="
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json"

echo ""
echo "=== Profile & Memory (v1.1.0+) ==="
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"

echo ""
echo "=== Backups (v1.2.0) ==="
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
su -c "ls -la /sdcard/dnscrypt-webui-backup/ 2>&1"

echo ""
echo "=== WebUI Language (v1.2.0) ==="
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && echo 'index: toggle present'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html && echo 'dashboard: toggle present'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/offline.html && echo 'offline: toggle present'"

echo ""
echo "=== Firewall ==="
su -c "iptables -t nat -L OUTPUT -n | head -5"
su -c "iptables -t nat -L DNSCRYPT_OUT -n 2>/dev/null | head -5"
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n 2>/dev/null | head -5"

echo ""
echo "=== Dashboard ==="
su -c "curl -s -u '$CREDS' http://127.0.0.1:9091/api/metrics" | head -20

echo ""
echo "=== Runtime Info ==="
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info"

echo ""
echo "=== Config ==="
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

echo ""
echo "=== Logs (last 50) ==="
su -c "tail -50 /data/local/tmp/dnscrypt_main.log"

echo ""
echo "=== Full Diagnostic (v1.2.0) ==="
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"

echo ""
echo "✅ Diagnostics complete. Save output to a file and attach to the issue."
```

### 9.2 v1.2.0-specific Diagnostics

```bash
#!/bin/bash
# diagnose-backup.sh — v1.2.0 backup-specific checks

# Derive credentials (root required)
CREDS=$(su -c "sed -n '/^\[monitoring_ui\]/,/^\[/p' \
    /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml \
  | grep -E '^(username|password)=' | cut -d\"'\" -f2 | tr '\n' ':' | sed 's/:$//'")

echo "=== Backup directory ==="
su -c "ls -la /sdcard/dnscrypt-webui-backup/ 2>&1"

echo ""
echo "=== Backup state (7 fields) ==="
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"

echo ""
echo "=== Backup vs status.sh alignment ==="
diff <(su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq -S '.backups'") \
     <(su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | jq -S '.backups | del(.status, .last_backup_age_seconds)'")
# Expected: no diff

echo ""
echo "=== .last_stable pointer ==="
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable 2>&1"

echo ""
echo "=== Upgrade history ==="
su -c "cat /sdcard/dnscrypt-webui-backup/.upgrade_history.json 2>/dev/null | jq" \
    || su -c "cat /sdcard/dnscrypt-webui-backup/.upgrade_history.txt 2>/dev/null"

echo ""
echo "=== In-flight transactions ==="
su -c "ls -la /sdcard/dnscrypt-webui-backup/txn-* 2>&1"

echo ""
echo "=== Orphan transactions ==="
su -c "ls -la /sdcard/dnscrypt-webui-backup/orphan-txn-* 2>&1"

echo ""
echo "=== Recovery mode triggers ==="
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>&1"
su -c "ls /data/adb/dnscrypt-recovery 2>&1"

echo ""
echo "=== Backup layer functions present ==="
su -c "grep -q 'CANDIDATE_SOURCES' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 1'"
su -c "grep -q 'PERSISTENT_BACKUP' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 2'"
su -c "grep -q 'verify_backup_integrity' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 3'"
su -c "grep -q 'begin_transaction' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 4'"
su -c "grep -q 'detect_root_solution' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 5'"
su -c "grep -q 'copy_with_context' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 6'"
su -c "grep -q 'RECOVERY_MODE' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 7'"
su -c "grep -q 'migrate_config' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 8'"
su -c "grep -q 'auto_backup_if_needed' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && echo '✅ Layer 9'"
su -c "grep -q 'diagnose' /data/adb/modules/dnscrypt-proxy-webui/status.sh && echo '✅ Layer 10'"

echo ""
echo "=== Bilingual WebUI check ==="
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && echo '✅ index.html toggle'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html && echo '✅ dashboard.html toggle'"
su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/offline.html && echo '✅ offline.html toggle'"

echo ""
echo "✅ v1.2.0 backup + language diagnostics complete."
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
- Performance reports (`rebuildBlocklist` duration).
- **v1.1.0+**: Memory-limit reports per device RAM tier.
- **v1.2.0+**: **Backup/restore reports** across devices, root
  solutions, and upgrade scenarios (see §10.7).
- **v1.2.0+**: **Bilingual WebUI reports** — how the language
  toggle behaves on different browsers and ROMs.

### 10.2 How to Contribute

1. Test on your device.
2. Fill in the template above.
3. Open an Issue titled `[Compat] <Device> <Android>`.
4. Attach the logs.

### 10.3 Compatibility Testing for v1.2.0

**Recommended tests** — focused on the 10 data-preservation
layers. Each test should be run **before** and **after** an
in-place upgrade from v1.1.0 to v1.2.0.

> **Authentication**: All `/api/*` calls below require `-u "$CREDS"`
> if `[monitoring_ui]` has credentials. Define `$CREDS` first — see
> the top of this file.

#### 10.3.1 Pre-Upgrade Baseline

```bash
# 1. Record the current profile + memory limit
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"

# 2. Record the current allowlist + denylist size
su -c "wc -l /data/adb/modules/dnscrypt-proxy-webui/proxy/allowlist.txt"
su -c "wc -l /data/adb/modules/dnscrypt-proxy-webui/proxy/denylist.txt"

# 3. Record the current webui.conf ports
su -c "grep -E '^(PORT|DASHBOARD_PORT|BIND_ADDR)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

# 4. Take a manual backup of the whole module directory
su -c "tar czf /sdcard/pre-v1.2.0-backup.tar.gz -C /data/adb/modules/dnscrypt-proxy-webui ."
```

#### 10.3.2 Post-Upgrade Verification

```bash
# 1. Verify all 5 files survived
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/*.conf"
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/*.toml"
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/*.txt"

# 2. Verify the profile matches the pre-upgrade baseline
diff <(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt") <(echo "pro")
# Expected: no diff (or whatever your baseline profile was)

# 3. Verify the memory limit matches the profile
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"

# 4. Verify the persistent backup directory exists
su -c "ls -la /sdcard/dnscrypt-webui-backup/"

# 5. Verify the 7-field backups object
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'"
# Expected: ["available", "in_flight_txn", "last_backup", "last_backup_name", "last_stable", "orphan_txn", "path"]

# 6. Verify the upgrade history was logged
su -c "cat /sdcard/dnscrypt-webui-backup/.upgrade_history.json | jq '.upgrades[-1]'"
```

#### 10.3.3 Recovery Mode Test

```bash
# 1. Note the current profile (read directly — no auth required)
ORIGINAL_PROFILE=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")

# 2. Change it manually (a "damage" simulation)
su -c "echo 'light' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 3. Verify the change took effect.
#    HARD-COMPAT-05: read the file directly instead of calling
#    the API, which would require auth.
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Expected: light

# 4. Trigger recovery
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"

# 5. After reboot, verify the original profile was restored
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Expected: $ORIGINAL_PROFILE

# 6. Verify the trigger file was consumed
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>&1"
# Expected: No such file or directory
```

#### 10.3.4 Cross-Root-Solution Test

Repeat §10.3.1–§10.3.3 on a device with a different root
solution (Magisk → KernelSU, KernelSU → APatch, etc.) and verify
the same results.

#### 10.3.5 Cross-Android-Version Test

Repeat §10.3.1–§10.3.3 on:
- **Android 5–5.1** (oldest supported).
- **Android 8–9** (mid-range).
- **Android 12–14** (modern).

Note the differences in:
- `sha256sum` availability (§2.5).
- `restorecon` vs `chcon` (§2.5).
- FUSE mount behavior (§2.5).

#### 10.3.6 Bilingual WebUI Test (v1.2.0)

```bash
# Verify the toggle is present in all three pages
for f in web/index.html web/dashboard.html web/offline.html; do
    echo "=== $f ==="
    grep -q 'id="langToggle"' "$f" && echo "  ✅ toggle"
    grep -q 'en:' "$f" && grep -q 'ar:' "$f" && echo "  ✅ en+ar"
    grep -q "dnscrypt-lang" "$f" && echo "  ✅ localStorage"
    grep -q '\[dir="rtl"\]' "$f" && echo "  ✅ RTL rules"
done
```

**Manual steps**:

1. Open the WebUI in **Chrome 88+**.
2. Confirm the page loads in **English** (default).
3. Click the `langToggle` button → page switches to **Arabic**.
4. Verify the layout is **RTL** (right-to-left).
5. Reload the page → the Arabic preference **persists**.
6. Repeat with **Firefox 92+** and a recent **Samsung Internet**.

**Report** for each browser:
- Toggle button visible? (yes/no)
- English default on load? (yes/no)
- Arabic renders correctly? (yes/no)
- RTL layout correct? (yes/no)
- Preference persists across reloads? (yes/no)

#### 10.3.7 Legacy v1.1.0 Regression Tests

Still run the v1.1.0 tests (they are not superseded):

```bash
# Define $CREDS first — see the top of this file

# 1. Test Dashboard (Fix #1)
echo "Open http://127.0.0.1:9091"
echo "Should show: total_queries, blocked_queries, cache_stats"

# 2. Test shell fallback (Fix #2)
grep -q 'func getSystemShell' proxy/main.go && echo "✅ getSystemShell present"

# 3. Test Basic Auth rate limit (Fix #8)
for i in {1..6}; do
  curl -u "wrong:wrong" -o /dev/null -w "%{http_code}\n" \
    http://127.0.0.1:9090/api?action=status
done

# 4. Test 404 (Fix #12)
curl -i -u "$CREDS" "http://127.0.0.1:9090/api?action=nonexistent"
# → 404 Not Found

# 5. Test Login POST-only (NEW-1)
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# → 405 Method Not Allowed + Allow: POST

# 6. Test /readyz localhost-only (NEW-4)
curl -i http://127.0.0.1:9091/readyz
# → 200 or 503 (from localhost)

# 7. Test MEM-1 (memory limit)
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'

# 8. Test RACE-1 (rebuildMu)
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"

# 9. Test PORT-2 (runtime_info ports)
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'

# 10. Test bilingual WebUI (v1.2.0)
grep -q 'id="langToggle"' web/index.html && echo "✅ bilingual index"
grep -q 'id="langToggle"' web/dashboard.html && echo "✅ bilingual dashboard"
grep -q 'id="langToggle"' web/offline.html && echo "✅ bilingual offline"
```

### 10.4 Hall of Fame

Compatibility contributors are listed in
[`HALL_OF_FAME.md`](HALL_OF_FAME.md#-compatibility-champions).

### 10.5 Platform Champions

New badge for those testing on **non-Android platforms** (Linux,
macOS, WSL2):

- 🖥️ Testing on Linux (CI-like environment).
- 🍎 Testing on macOS.
- 🐧 Testing on WSL2 (Windows).

**Benefit**: improves `getSystemShell()` and platform-agnostic
shell behavior.

### 10.6 Memory Architect Badge (v1.1.0)

New badge for contributors who:

- Test the dynamic memory limit on multiple RAM tiers.
- Report GC-related issues with concrete data (profile, RSS,
  CPU sample, `runtime_info` output).
- Propose improvements to the per-profile constants.

**Reference**: [`HALL_OF_FAME.md`](HALL_OF_FAME.md) — Memory Architect.

### 10.7 Data Guardian Badge (v1.2.0 — new)

New badge for contributors who:

- Test the 10 data-preservation layers on **3+ devices** or
  **3+ root solutions** (Magisk / KernelSU / APatch).
- Verify that all 5 user config files survive an in-place upgrade.
- Verify that recovery mode restores all 5 files.
- Report the 7-field `backups` object before/after each scenario.
- Report any mismatch with concrete evidence (logs +
  reproduction steps).

**Acceptance criteria** (from
[`HALL_OF_FAME.md`](HALL_OF_FAME.md)):

- ✅ Tested at least 3 scenarios from the recommended list.
- ✅ Reported the 7-field `backups` object for each scenario.
- ✅ Reported `status.sh --diagnose` output.
- ✅ Reported `dnscrypt_install.log` excerpts.
- ✅ If a mismatch was found, documented it with the exact
  reproduction steps.

**Optional (bonus)**:

- Testing after a factory reset of `/data`.
- Testing the concurrency scenario (two rapid writes).
- Testing the SW update-banner fix on both `index.html` and
  `dashboard.html`.
- **Testing the bilingual toggle across different browsers**.

**Reference**: [`HALL_OF_FAME.md`](HALL_OF_FAME.md) — Data Guardian;
[`BACKUP.md`](BACKUP.md) §12; [`SECURITY.md`](SECURITY.md) §5.31.

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

### 11.2 Project Documentation

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Full architecture (§3.10, §4.10) |
| [`docs/SECURITY.md`](SECURITY.md) | Security policy + Audit Corrections (§5.31, §5.32) |
| [`docs/API.md`](API.md) | Full HTTP API reference (§6.1.7) |
| [`docs/BACKUP.md`](BACKUP.md) | **Backup system reference (v1.2.0)** |
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
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history (v1.0.0 → v1.2.0) |
| [`README.md`](../README.md) | Project overview |

---

*Last updated: 2026-10-02*
*Version: v1.3.0 (Global Edition)*
*Author: gasciljh*