# Hall of Fame — DNSCrypt Smart Filter

> Recognition for everyone who has contributed to this project.

**Version**: v1.4.0
**Last updated**: 2026-10-06
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • `Last updated` reflects the v1.4.0 release date.
>   • **New badge**: 🏆 **Companion App Champion (v1.4.0)** —
>     recognizes contributors who test the optional companion
>     Android app (`web/app-debug.apk`) on 3+ devices or ROMs.
>   • `Auditor` badge note: v1.4.0 does **not** add audit
>     corrections. The registry remains at **#33**.
>   • `Platform Fixer` badge note: `removeModule` path-injection
>     hardening is now documented as a CodeQL fix, **not** an
>     audit correction.
>   • `UI/UX` badge note: the removal of the iOS-specific install
>     path is documented.
>   • New subsection in "Audit Corrections Registry" for v1.3.0
>     and v1.4.0 — both are non-audit releases.
>   • "How to Get Added" extended with the Companion App Champion
>     acceptance criteria.
>   • "Changelog for Contributors" extended with a v1.3.0 section
>     (PWA install button, live status LED, DNS auto-start fix)
>     and a v1.4.0 section (companion app, CodeQL fix, iOS PWA
>     removal).
>   • `References` extended with the companion app repository and
>     the v1.4.0 documentation set.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention.

> **v1.3.0 changes**:
>   • Version bumped from v1.2.0 to v1.3.0.
>   • `Last updated` reflects the v1.3.0 release date
>     (2026-10-02).
>   • **New badge**: 🔔 **PWA Champion (v1.3.0)** — recognizes
>     contributors who test the smart PWA install button across
>     Chromium / Firefox / Samsung Internet.
>   • "Changelog for Contributors" extended with a v1.3.0
>     section.
>   • `References` extended with the v1.3.0 documentation set.

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • `Last updated` reflects the v1.2.0 release date
>     (2026-09-29).
>   • **New badge**: 🛡️ **Data Guardian** — recognizes
>     contributors who test the backup/restore system (the 10
>     defensive layers) across devices, root solutions, and
>     upgrade scenarios.
>   • `Concurrency Guardian` badge note extended: now also covers
>     `backupMu` (BAK-2, v1.2.0) in addition to `rebuildMu`
>     (RACE-1, v1.0.0).
>   • `Translator` badge note extended: with the bilingual WebUI
>     (English default + Arabic toggle), a significant
>     contribution to `translations.ar` also qualifies.
>   • `Auditor` badge note clarified: v1.2.0 does **not** add
>     audit corrections. The registry remains at **#33**.
>   • New subsection in "Audit Corrections Registry" explicitly
>     documenting that v1.2.0 is a data-preservation release, not
>     an audit-correction release.
>   • New subsection in "Changelog for Contributors" for the
>     v1.2.0 cycle.
>   • "How to Get Added" section extended with the Data Guardian
>     acceptance criteria.
>   • `References` extended with `docs/BACKUP.md` and
>     `docs/EMERGENCY.md`.

> **v1.4.0 (Global Edition) — Corrections in this revision**:
>   • 🔧 **HOF-1** — The v1.2.0 "Changelog for Contributors"
>     section previously described FIX-1 as a "recovery-mode
>     reorder". The actual implementation in `customize.sh` uses a
>     **snapshot-and-reapply** strategy (`§[8a]` + `§[9]` +
>     `§[9b2]`), which keeps the extraction logic of `§[9]`
>     untouched. The description has been corrected to match the
>     shipped code. See `docs/SECURITY.md` §5.32.1.
>   • 🔧 **HOF-2** — The "Next audit correction" line still said
>     "expected in v1.3.x". Since v1.3.0 did not add any audit
>     correction, the line now reads "expected in a future
>     release".

---

## 🏆 Contribution Badges

### 🥇 Founder

*People who created the project in its first 6 months.*

| Contributor | Contribution |
|---------|----------|
| [@gasciljh](https://github.com/gasciljh) | Created the project, core development, system architecture, Backend (Go), Dashboard (PWA), build system, and release system |

---

### 🔥 Top Contributors

*Top contributors with merged commits.*

| # | Contributor | Commits |
|:-:|---------|:-------:|
| 1 | [@gasciljh](https://github.com/gasciljh) | — |
| 2 | *Your spot is reserved* | — |

---

### 🛡️ Security Researchers

*Those who responsibly disclosed vulnerabilities.*

| Contributor | Vulnerability | Version |
|---------|--------|:-------:|
| *Your spot is reserved* | — | — |

**Note**: See [`SECURITY.md`](SECURITY.md) for how to report
vulnerabilities.

---

### 📖 Documentation

*Contributions exceeding 5+ PRs in documentation.*

| Contributor | Contribution |
|---------|----------|
| [@gasciljh](https://github.com/gasciljh) | Created and maintains all documentation files (25 files in `docs/` + root files + `.github/` files) |
| *Your spot is reserved* | — |

---

### 🌐 Translators

*Those who translated the interface or documentation to other
languages.*

| Contributor | Language |
|---------|-------|
| [@gasciljh](https://github.com/gasciljh) | Arabic / English (primary languages) |
| *Your spot is reserved* | — |

**Note (v1.2.0)**: Although the **documentation** is English-only
(global edition), the **WebUI itself remains bilingual
(English / Arabic)** for the benefit of Arabic-speaking users.

**v1.2.0 acceptance extension**: With the bilingual WebUI, a
significant contribution to the `translations.ar` object (e.g.
adding many new keys with correct Arabic strings and RTL
verification) also qualifies for this badge — not just a full
documentation translation.

---

### 🧪 Testing Heroes

*Those who tested on rare devices and reported results to help
compatibility.*

| Contributor | Testing scope |
|---------|-----------|
| *Your spot is reserved* | — |

**Acceptance criteria**:
- Testing on **3+ different devices** (Android 5-15).
- Submitting a detailed report (logs + behavior).
- Testing v1.4.0 on older devices (Android 5-9).
- Testing on non-Android platforms (Linux, macOS, WSL2).
- **(v1.2.0)** Testing the bilingual WebUI on multiple browsers.
- **(v1.3.0)** Testing the PWA install button on 3+ browsers.
- **(v1.4.0)** Testing the companion app install button on 3+
  devices.

---

### 💎 Compatibility Champions

*Those who tested on rare devices and reported results.*

| Contributor | Device | Notes |
|---------|--------|-----------|
| *Your spot is reserved* | — | — |

**Acceptance criteria**:
- Testing on **3+ different devices** (Android 5-15).
- Submitting a detailed report (logs + behavior).
- Testing v1.0.0 + v1.1.0 + v1.2.0 + v1.3.0 + v1.4.0 on older
  devices (Android 5-9).
- Testing on non-Android platforms (Linux, macOS, WSL2).

---

### 🎨 UI/UX

*Contributions in design and user experience.*

| Contributor | Contribution |
|---------|----------|
| [@gasciljh](https://github.com/gasciljh) | Designed the WebUI + Dashboard + PWA + icons + logo |
| *Your spot is reserved* | — |

**v1.2.0 note**: Contributions to the bilingual UI (English
default + Arabic toggle), the RTL layout, or the Service Worker
update-banner fix (FIX-2) qualify.

**v1.3.0 note**: Contributions to the smart PWA install button,
the live status LED, or the responsive design qualify.

**v1.4.0 note**: Contributions to the companion app install
button or the removal of the iOS-specific install path
(Android-only cleanup) qualify.

---

### 🔔 PWA Champion (v1.3.0)

*Those who test the smart PWA install button across browsers and
ROMs.*

| Contributor | Test scope | Version | Reference |
|---------|:---------:|:-------:|-----------|
| [@gasciljh](https://github.com/gasciljh) | PWA install button design + implementation + testing on 5 browsers | v1.3.0 | [ARCHITECTURE.md](ARCHITECTURE.md) §6.4 |
| *Your spot is reserved* | — | — | — |

**What this badge recognizes**:

The v1.3.0 release introduced a **smart PWA install button** that
adapts to the browser:

- **Chromium-based browsers** (Chrome, Edge, Brave, Samsung
  Internet) — clicking opens the native
  `beforeinstallprompt` dialog.
- **iOS Safari** — clicking shows step-by-step "Add to Home
  Screen" instructions (*removed in v1.4.0 — see the Data
  Guardian note below*).
- **Unsupported browsers** (Firefox, Opera Mini, older
  browsers) — clicking shows a friendly modal listing supported
  alternatives with Play Store links.

**v1.4.0 note**: The iOS-specific install path was **removed** in
v1.4.0 — the project is Android-only. The PWA install button
still works for Chromium-based browsers; unsupported browsers
receive the unified "unsupported browser" modal.

**Acceptance criteria**:

- ✅ Tested the PWA install button on **at least 3 browsers**:
  - Chrome (Chromium-based)
  - Samsung Internet (Chromium-based)
  - Firefox (unsupported → unified modal)
- ✅ Reported the exact behaviour for each browser.
- ✅ Verified the button is hidden when the app is already
  installed or running in standalone mode.
- ✅ Verified the Play Store links in the unsupported modal.
- ✅ Tested the "Install" flow end-to-end on Chromium.

**Example report**:

```text
Device:       Pixel 7
Android:      14 (API 34)
Browsers:
  - Chrome 120    → Native install dialog shown ✅
  - Samsung 22    → Native install dialog shown ✅
  - Firefox 121   → Unified unsupported modal shown ✅
  - Brave 1.60    → Native install dialog shown ✅
  - Opera Mini 76 → Unified unsupported modal shown ✅
Notes:       PWA install button hides after installation.
             Play Store links work for Chrome, Edge, Brave.
```

**Why this matters**:

The PWA install button is the primary way users add the WebUI to
their home screen. Testing it across browsers ensures users are
never left without guidance when their browser does not support
the native install flow.

**Reference**: [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §6.4;
[`docs/FAQ.md`](FAQ.md) (PWA questions).

---

### 🏆 Companion App Champion (v1.4.0)

*Those who test the optional companion Android app on multiple
devices or ROMs.*

| Contributor | Test scope | Version | Reference |
|---------|:---------:|:-------:|-----------|
| [@gasciljh](https://github.com/gasciljh) | Companion app design + integration + testing on 3 devices | v1.4.0 | [ARCHITECTURE.md](ARCHITECTURE.md) §8.6 |
| *Your spot is reserved* | — | — | — |

**What this badge recognizes**:

The v1.4.0 release introduced the **optional companion Android
app** — a lightweight WebView wrapper (~3 MB) that loads the
WebUI at `http://127.0.0.1:9090` directly, without requiring a
browser.

The APK is bundled into the module ZIP as `web/app-debug.apk`
(OPTIONAL) and is served at `GET /app-debug.apk`. It is
downloadable from the WebUI install button
(`<a download href="/app-debug.apk">`).

**Source repository**:
[gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app).

**Acceptance criteria**:

- ✅ Installed the companion APK from the WebUI install button on
  **3+ devices** or **3+ ROMs**.
- ✅ Documented any installation issues or behaviour differences.
- ✅ Verified the app opens the WebUI correctly.
- ✅ Verified the app handles the WebUI being offline (shows the
  offline page or a reasonable error).
- ✅ Reported Android version, device model, and ROM.

**Recommended scenarios to test**:

| Scenario | Expected result |
|---|---|
| Install APK from WebUI | Installs successfully |
| Launch companion app | Loads the WebUI at `127.0.0.1:9090` |
| WebUI stopped | Shows offline page or error |
| WebUI restarted | App reloads on next launch |
| Different ROMs | Behaviour consistent |

**Optional (bonus)**:

- Testing on Android 5.x (oldest supported).
- Testing the APK on a custom GSI or LineageOS.
- Reporting APK size variations across builds.

**Example report**:

```text
Devices tested:
  1. Pixel 6a     / Android 14 / Magisk 27.0      → ✅ Works
  2. Xiaomi 13    / MIUI 14    / KernelSU 0.9.5   → ✅ Works
  3. OnePlus 11   / OxygenOS 13 / APatch         → ✅ Works

Common notes:
  - Install button downloads the APK reliably.
  - App opens WebUI without browser involvement.
  - Offline state shows a clean error page.
```

**Why this matters**:

The companion app provides a native experience for users who do
not want to keep a browser tab open. Testing it across multiple
ROMs ensures the WebView integration works correctly regardless
of the OEM's WebView implementation.

**Reference**: [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) §1.9,
§10.8.

---

### 🔍 Auditor

*Those who discovered and fixed architectural vulnerabilities
(Audit Corrections).*

**Note**: The Auditor badge is granted to anyone who contributes at
least one Audit Correction.

⚠️ **v1.2.0 / v1.3.0 / v1.4.0 note**: None of these releases add
new audit corrections. The registry remains at **#33** (the last
entry from v1.0.0).

- **v1.2.0** additions (BAK-1..BAK-4, FIX-1, FIX-2) are
  **runtime improvements and correctness fixes**, not exploitable
  vulnerabilities — they are documented in `docs/SECURITY.md`
  §5.31 and §5.32 without audit numbers.
- **v1.3.0** is a **feature release** (PWA install button, live
  status LED, DNS auto-start fix) — no audit corrections.
- **v1.4.0** is an **integration release** (companion Android app,
  CodeQL path-injection hardening, iOS PWA removal). The CodeQL fix
  in `removeModule` **closes two pre-existing CodeQL alerts**
  (#1 and #2) — these are **not** numbered audit corrections; they
  are tracked in `docs/SECURITY.md` as CodeQL alerts.

New audit corrections will resume at **#34** in a future release.

| Contributor | Audit Correction | Version | Reference |
|---------|:----------------:|:-------:|-----------|
| [@gasciljh](https://github.com/gasciljh) | #13 CSRF-GET → POST-only | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #14 `pgrep -x` | v1.0.0 | — |
| [@gasciljh](https://github.com/gasciljh) | #15-a Token Leakage | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #15-b 405 Allow header | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #16-a/b IPv4/IPv6 Filter | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #17 Custom Chains (Orphan Fix) | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #18 STATUS_FILE Semantics | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #19 IPv6 Rate Limit | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #20 Port Collision 8080 | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #21 Section-Restricted TOML | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #22 Basic Auth Rate Limit Bypass | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #23 Section header with comment (parsing) | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #24 Exact endpoint matching | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #25 Dashboard JSON Conversion | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #26 Preserve User Settings on Upgrade | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #27 `fuser` PID parsing | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #28 Login POST-only (CSRF) | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #29 `readConfPort` range check | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #30 `/readyz` localhost-only | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #31 `shellQuote` injection protection | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #32 `rebuildMu` mutex (RACE-1) | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | #33 `runtime_info` dynamic ports (PORT-2) | v1.0.0 | [SECURITY.md](SECURITY.md) |
| **Anthropic Claude** | Assistance with code review and architectural audit | v1.0.0 | — |
| *Your spot is reserved* | — | — | — |

---

### 🔧 Platform Fixer

*Those who fixed platform-specific issues (Android/Linux/macOS).*

| Contributor | Fix | Version | Reference |
|---------|:-------:|:-------:|-----------|
| [@gasciljh](https://github.com/gasciljh) | `getSystemShell()` — Linux/macOS fallback (Fix #2) | v1.0.0 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| *Your spot is reserved* | — | — | — |

**Acceptance criteria**:

- Fixing an issue preventing the system from working on a specific
  platform (Linux, macOS, WSL2).
- **Example**: Fixing `runShell` to work on Linux/macOS (v1.0.0,
  Fix #2).
- **Requirements**:
  - ✅ The problem is clear (specific error in CI or local dev).
  - ✅ The fix works on all platforms (does not break Android).
  - ✅ Verification test.

---

### 📊 Metrics Wizard

*Those who improved the metrics/Dashboard system.*

| Contributor | Fix | Version | Reference |
|---------|:-------:|:-------:|-----------|
| [@gasciljh](https://github.com/gasciljh) | `parsePrometheus()` + `buildDashboardJSON()` (Fix #1) | v1.0.0 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| *Your spot is reserved* | — | — | — |

**Acceptance criteria**:

- Improvement in the metrics/Dashboard system.
- **Example**: `parsePrometheus()` + `buildDashboardJSON()` (v1.0.0,
  Fix #1).
- **Requirements**:
  - ✅ The problem affects data display or collection.
  - ✅ The solution reduces CPU/network or improves accuracy.
  - ✅ Verification test.

---

### ⚙️ Concurrency Guardian

*Those who fixed race conditions and concurrency issues.*

| Contributor | Fix | Version | Reference |
|---------|:-------:|:-------:|-----------|
| [@gasciljh](https://github.com/gasciljh) | `rebuildMu` mutex — serializes `rebuildBlocklist` (RACE-1) | v1.0.0 | [SECURITY.md](SECURITY.md) |
| [@gasciljh](https://github.com/gasciljh) | `backupMu` mutex — serializes pre-critical backups (BAK-2) | v1.2.0 | [SECURITY.md](SECURITY.md) §5.31 |
| *Your spot is reserved* | — | — | — |

**Acceptance criteria**:

- Detecting and fixing a real race condition.
- **Examples**:
  - `rebuildMu` protects `rebuildBlocklist` (v1.0.0, RACE-1).
  - `backupMu` serializes pre-critical backups (v1.2.0, BAK-2).
- **Requirements**:
  - ✅ The problem is documented (scenario + result).
  - ✅ The solution uses `sync.Mutex` / `sync.RWMutex` correctly.
  - ✅ `defer unlock()` in all paths.
  - ✅ No deadlock.

**v1.2.0 note**: The badge now recognizes contributions to **both**
the `rebuildMu` mutex (v1.0.0) and the `backupMu` mutex (v1.2.0).

---

### 🔌 Port Architect

*Those who fixed dynamic ports issues.*

| Contributor | Fix | Version | Reference |
|---------|:-------:|:-------:|-----------|
| [@gasciljh](https://github.com/gasciljh) | `runtime_info` ports — dynamic WebUI/Dashboard URLs (PORT-2) | v1.0.0 | [SECURITY.md](SECURITY.md) |
| *Your spot is reserved* | — | — | — |

**Acceptance criteria**:

- Fixing an issue in port management (hardcoded, validation,
  dynamic discovery).
- **Example**: `runtime_info` returns `webui_port` +
  `dashboard_port` (v1.0.0, PORT-2).
- **Requirements**:
  - ✅ The problem affects the user experience.
  - ✅ The solution supports LAN + IPv6.
  - ✅ No hardcoded ports in HTML/JS.

---

### 🧠 Memory Architect (v1.1.0)

*Those who test the dynamic memory limit across device RAM tiers
and report GC behavior.*

| Contributor | Test scope | Version | Reference |
|---------|:---------:|:-------:|-----------|
| [@gasciljh](https://github.com/gasciljh) | MEM-1 design + implementation + testing on 5 profile tiers | v1.1.0 | [SECURITY.md](SECURITY.md) §5.30.1 |
| *Your spot is reserved* | — | — | — |

**What this badge recognizes**:

The v1.1.0 release introduced **MEM-1** — a dynamic Go runtime soft
memory limit that adapts to the active blocklist profile
(light=80 MB → ultimate=220 MB). Testing this properly requires
running the WebUI on devices with different RAM tiers and reporting
actual GC behavior, RSS, and CPU usage.

Contributors who provide **concrete, reproducible memory data**
across multiple RAM tiers earn this badge.

**Acceptance criteria**:

- ✅ Tested the dynamic memory limit on **at least 3 different RAM
  tiers** (e.g. 1 GB, 3 GB, 6 GB+).
- ✅ Reported concrete data for each tier:
  - `runtime_info.memory_limit_mb` (the soft limit)
  - Process RSS (via `dumpsys meminfo` or `/proc/<pid>/status`)
  - CPU sample during activity
  - Observed GC behavior (or absence of GC thrashing)
- ✅ Compared against the expected values in
  [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) §5.4.
- ✅ If a mismatch was found, included the startup log line
  (`grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log`)
  and the contents of `selected_profile.txt`.

**Example report**:

```text
Profile:       ultimate
Device RAM:    6 GB
Soft limit:    220 MB (as expected)
RSS (idle):    62 MB
RSS (peak):    187 MB (during rebuildBlocklist)
CPU (idle):    0.8%
CPU (active):  4.2%
GC behavior:   No thrashing observed
Notes:         Ran for 48 h with heavy DNS activity. No slowdown.
```

**Why this matters**:

The v1.1.0 release fixes a self-inflicted DoS surface (GC thrashing
on the `ultimate` profile when running on lower-RAM devices). By
documenting real-world behavior across RAM tiers, contributors help
verify the fix works and identify any edge cases that need further
tuning.

**Reference**: [`docs/SECURITY.md`](SECURITY.md) §5.30.1;
[`docs/COMPATIBILITY.md`](COMPATIBILITY.md) §5.4.

---

### 🛡️ Data Guardian (v1.2.0)

*Those who test the backup/restore system across devices, root
solutions, and upgrade scenarios.*

| Contributor | Test scope | Version | Reference |
|---------|:---------:|:-------:|-----------|
| [@gasciljh](https://github.com/gasciljh) | 10 defensive layers design + implementation + testing on 3 root solutions | v1.2.0 | [SECURITY.md](SECURITY.md) §5.31 |
| *Your spot is reserved* | — | — | — |

**What this badge recognizes**:

The v1.2.0 release introduced the **10 defensive layers** — a
comprehensive data-preservation system that protects the 5 user
config files across in-place upgrades, renames, reinstalls, root
solution changes, and catastrophic failures.

Testing this properly requires:
- Running the module on devices with **different root solutions**
  (Magisk / KernelSU / APatch).
- Testing **in-place upgrades** from v1.0.0 and v1.1.0.
- Testing **recovery mode** and inspecting the result.
- Reporting concrete backup state via the 7-field
  `runtime_info.backups` object.

Contributors who provide **concrete, reproducible backup reports**
across multiple scenarios earn this badge.

**Acceptance criteria**:

- ✅ Tested the 10 data-preservation layers on **3+ devices** or
  **3+ root solutions** (Magisk / KernelSU / APatch).
- ✅ Verified that all 5 user config files
  (`webui.conf`, `dnscrypt-proxy.toml`, `selected_profile.txt`,
  `allowlist.txt`, `denylist.txt`) survive an in-place upgrade.
- ✅ Verified that recovery mode restores all 5 files.
- ✅ Reported the 7-field `backups` object before/after each
  scenario.
- ✅ Reported `status.sh --diagnose` output.
- ✅ Reported `dnscrypt_install.log` excerpts.
- ✅ If a mismatch was found, documented it with the exact
  reproduction steps.

**Recommended scenarios to test**:

| Scenario | Expected result |
|---|---|
| Fresh install | 5 files created; no backup (first install) |
| In-place upgrade from v1.1.0 | 5 files preserved; snapshot created |
| In-place upgrade from v1.0.0 | 5 files preserved; `MEMORY_LIMIT_HINT=auto` added |
| In-place upgrade from v1.2.0 | 5 files preserved; snapshot created |
| In-place upgrade from v1.3.0 | 5 files preserved; snapshot created |
| Reinstall after uninstall | 5 files restored from `/sdcard/` backup |
| Recovery mode | 5 files restored; trigger file consumed |
| Renamed module folder | 5 files found via multi-source detection |
| APatch install | 5 files found via `modules_update/` fallback |
| Concurrency | Two rapid `save_allowlist` calls → no corrupted snapshot |

**Optional (bonus)**:

- Testing after a factory reset of `/data`.
- Testing the SW update-banner fix (FIX-2) on both `index.html`
  and `dashboard.html`.
- Testing the bilingual toggle across different browsers.

**Example report**:

```text
Device:        Pixel 6a
Android:       14 (API 34)
Root:          Magisk 27.0
Scenario:      In-place upgrade v1.3.0 → v1.4.0
Files before:  5 (profile=ultimate, 200 allowlist, 50 denylist)
Files after:   5 (all identical)
Backups:       available=3, in_flight_txn=0, orphan_txn=0
last_stable:   20261006-120000-v1.4.0
Notes:         Recovery mode not triggered. All 5 files intact.
```

**Why this matters**:

The v1.2.0 release fixes a **data-loss bug** in v1.1.0 that
silently erased the 5 user config files on every in-place upgrade.
By documenting real-world behavior across devices and root
solutions, contributors help verify the fix works and identify any
edge cases that need further tuning.

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §12;
[`docs/SECURITY.md`](SECURITY.md) §5.31;
[`docs/FAQ.md`](FAQ.md) Q129.

---

## 🌟 Special Thanks

### Upstream Projects

- **[@DNSCrypt/dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)** — The core engine.
- **[@hagezi/dns-blocklists](https://github.com/hagezi/dns-blocklists)** — Excellent blocklist provider.
- **[@topjohnwu/Magisk](https://github.com/topjohnwu/Magisk)** — Module framework.
- **[@tiann/KernelSU](https://github.com/tiann/KernelSU)** — KernelSU system.
- **[@bmax121/APatch](https://github.com/bmax121/APatch)** — APatch root system.

### Tools

- **[@koalaman/shellcheck](https://github.com/koalaman/shellcheck)** — Shell linting.
- **[@mvdan/sh](https://github.com/mvdan/sh)** — `shfmt` shell formatting.
- **[@golangci/golangci-lint](https://github.com/golangci/golangci-lint)** — Go linter (v2 schema).
- **[@sigstore/cosign](https://github.com/sigstore/cosign)** — Digital signing of releases.
- **[@igorshubovych/markdownlint-cli](https://github.com/igorshubovych/markdownlint-cli)** — Markdown linting.
- **[@adrienverge/yamllint](https://github.com/adrienverge/yamllint)** — YAML linting.
- **[@rhysd/actionlint](https://github.com/rhysd/actionlint)** — GitHub Actions linting.
- **[@pre-commit/pre-commit](https://github.com/pre-commit/pre-commit)** — Git hooks framework.

### Community

- **XDA Developers community** — Continuous feedback.
- **Termux community** — Testing code on Android platforms.
- **r/Android** — Awareness and sharing.
- **Telegram groups** — Technical support between users.

### Audit Contributions (v1.0.0)

- **Anthropic Claude** — Assistance with code review and
  comprehensive architectural audit that led to the discovery and
  fixing of Audit Corrections #22-33.
- **Prometheus community** — For comprehensive documentation of the
  Text Format.
- **Netfilter community** — For comprehensive documentation of
  Custom Chains Best Practices.
- **GitHub Actions community** — For documentation on caching +
  retry patterns.
- **Go community** — For documentation on `sync.Mutex`, `sync.Once`,
  `sync.RWMutex`.

### v1.1.0 Acknowledgments

- **Go runtime/debug team** — For `debug.SetMemoryLimit` (used by
  MEM-1).
- **Reviewers of the `ultimate` GC thrashing issue** — For the
  analysis that motivated the per-profile limit.

### v1.2.0 Acknowledgments

- **Android FUSE / storage team** — For documentation on the
  `/sdcard/` FUSE mount behavior that informs the backup layer.
- **Android SELinux team** — For documentation on `restorecon` /
  `chcon` used by Layer 6.
- **Reviewers of the v1.1.0 in-place upgrade data-loss issue** —
  For the analysis that motivated the 10 defensive layers.

### v1.3.0 Acknowledgments

- **Chromium PWA team** — For documentation on the
  `beforeinstallprompt` event and the Web App Manifest spec.
- **Samsung Internet team** — For documentation on the PWA install
  flow on OneUI.

### v1.4.0 Acknowledgments

- **CodeQL team** — For the `go/path-injection` query that
  motivated the `removeModule` hardening.
- **The companion app contributors** — For maintaining
  [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app).

---

## 🎁 How to Get Added to the Hall of Fame

### 🥇 Founder
- Creating the original project.
- Releasing the first stable version.

### 🔥 Top Contributors
- **5+ merged PRs** → enters the list.
- **20+ merged PRs** → invited as co-maintainer.

### 🛡️ Security Researchers
- Discovering a real security vulnerability.
- Responsible disclosure.
- Waiting for the fix before public disclosure.
*(See [`SECURITY.md`](SECURITY.md) for how to report.)*

### 📖 Documentation
- Adding 5+ pull requests in `docs/` or `README.md`.
- Clear improvements (structure improvement, intensive typo
  correction, adding code examples).

### 🌐 Translators
- Translating `README.md` to a new language completely.
- Translating the interface and adding code in the `translations
  object` in `index.html`.
- Adding `docs/*.<lang>.md`.
- **(v1.2.0)** Adding significant contributions to the WebUI's
  `translations.ar` object (e.g. many new keys, RTL verification).

### 🧪 Testing Heroes
- Testing the project on 3 or more different devices.
- Submitting a detailed report (logs + actual behavior).
- Actively helping solve compatibility conflict issues.
- Testing v1.4.0 on different devices (especially Android 5–9).
- Testing on non-Android platforms (Linux, macOS, WSL2).
- **(v1.2.0)** Testing the bilingual WebUI on multiple browsers.
- **(v1.3.0)** Testing the PWA install button on 3+ browsers.
- **(v1.4.0)** Testing the companion app install button on 3+
  devices.

### 💎 Compatibility Champions
- Testing the project on 3 or more different devices.
- Submitting a detailed report (logs + actual behavior).
- Actively helping solve compatibility conflict issues.
- Testing v1.0.0 + v1.1.0 + v1.2.0 + v1.3.0 + v1.4.0 on different
  devices (especially Android 5–9).
- Testing on non-Android platforms (Linux, macOS, WSL2).

### 🎨 UI/UX
- Improving the visual design.
- Adding a useful UX feature.
- Improving and supporting accessibility.
- Testing the Dashboard JSON on different browsers.
- **(v1.2.0)** Improving the bilingual UI or the RTL layout.
- **(v1.3.0)** Improving the smart PWA install button or the live
  status LED.
- **(v1.4.0)** Improving the companion app install button.

### 🔔 PWA Champion (v1.3.0)
- Testing the PWA install button on **3+ browsers**.
- Reporting the exact behaviour for each browser.
- Verifying the button hides after installation.
- Testing the Play Store links in the unsupported modal.
- **Criteria**:
  - ✅ Tested on Chromium-based browsers (Chrome, Edge, Brave,
    Samsung Internet).
  - ✅ Tested on unsupported browsers (Firefox, Opera Mini).
  - ✅ Documented the behaviour differences.

### 🏆 Companion App Champion (v1.4.0)
- Installing the companion APK from the WebUI install button on
  **3+ devices** or **3+ ROMs**.
- Documenting installation issues or behaviour differences.
- Verifying the app opens the WebUI correctly.
- Verifying the app handles the WebUI being offline.
- **Criteria**:
  - ✅ Tested at least 3 scenarios from the recommended list.
  - ✅ Reported Android version, device model, and ROM.
  - ✅ If a mismatch was found, documented it with evidence.
- **Optional (bonus)**:
  - Testing on Android 5.x (oldest supported).
  - Testing on a custom GSI or LineageOS.

### 🔍 Auditor
- Discovering an **architectural** vulnerability (not just a bug).
- Providing a complete analysis explaining:
  - The catastrophic scenario (reproduction).
  - The real impact (impact analysis).
  - The proposed solution (proposed fix).
  - The added tests (test coverage).
- Granted the official number `Audit Correction #XX` after review.

**⚠️ v1.2.0 / v1.3.0 / v1.4.0 note**: None of these releases add new
audit corrections. The registry remains at **#33**. Audit
Corrections will resume at **#34** in a future release. If your
contribution fixes an architectural issue, it will be the first new
Auditor badge since v1.0.0.

### 🔧 Platform Fixer
- Fixing a problem preventing the system from working on a specific
  platform (Linux, macOS, WSL2).
- **Example**: Fixing `runShell` to work on Linux/macOS (v1.0.0,
  Fix #2).
- **Criteria**:
  - ✅ The problem is clear (specific error in CI or local dev).
  - ✅ The solution works on all platforms (does not break Android).
  - ✅ A test verifying the solution.

### 📊 Metrics Wizard
- Improvement in the metrics/Dashboard system.
- **Example**: `parsePrometheus()` + `buildDashboardJSON()`
  (v1.0.0, Fix #1).
- **Criteria**:
  - ✅ The problem affects data display or collection.
  - ✅ The solution reduces CPU/network or improves accuracy.
  - ✅ Tests covering different metrics cases.

### ⚙️ Concurrency Guardian
- Discovering and fixing a real race condition.
- **Examples**:
  - `rebuildMu` (v1.0.0, RACE-1).
  - `backupMu` (v1.2.0, BAK-2).
- **Criteria**:
  - ✅ The solution uses mutex correctly.
  - ✅ `defer unlock()` in all paths.
  - ✅ No deadlock in verification.

### 🔌 Port Architect
- Fixing port issues (hardcoded, validation, dynamic discovery).
- **Example**: `runtime_info` ports (v1.0.0, PORT-2).
- **Criteria**:
  - ✅ The solution supports LAN + IPv6.
  - ✅ No hardcoded ports in HTML/JS.

### 🧠 Memory Architect (v1.1.0)
- Testing the dynamic memory limit (MEM-1) across **3+ RAM tiers**.
- Reporting concrete data: `memory_limit_mb`, RSS, CPU, GC
  behavior.
- Identifying edge cases or proposing improvements to the
  per-profile constants.
- **Criteria**:
  - ✅ The report includes `runtime_info` output for the tested
    profile.
  - ✅ The report includes the startup log line.
  - ✅ The report compares against expected values from
    [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) §5.4.
  - ✅ If a mismatch is found, it is documented with evidence.

### 🛡️ Data Guardian (v1.2.0)
- Testing the 10 defensive layers across **3+ devices** or **3+
  root solutions** (Magisk / KernelSU / APatch).
- Verifying all 5 user config files survive an in-place upgrade.
- Verifying recovery mode restores all 5 files.
- Reporting the 7-field `backups` object for each scenario.
- **Criteria**:
  - ✅ Tested at least 3 scenarios from the recommended list.
  - ✅ Reported the 7-field `backups` object for each scenario.
  - ✅ Reported `status.sh --diagnose` output.
  - ✅ Reported `dnscrypt_install.log` excerpts.
  - ✅ If a mismatch was found, documented it with the exact
    reproduction steps.
- **Optional (bonus)**:
  - Testing after a factory reset of `/data`.
  - Testing the concurrency scenario (two rapid writes).
  - Testing the SW update-banner fix on both `index.html` and
    `dashboard.html`.
  - Testing the bilingual toggle across different browsers.

---

## 📊 Contributors List

### By Commit Count

*Updated automatically by GitHub image.*

![Contributors](https://contrib.rocks/image?repo=gasciljh/dnscrypt-proxy-webui)

---

## 📝 Notes for Contributors

### Rules

1. **Continuity**: The contribution must be **merged** into the
   main branch to count.
2. **Quality**: One excellent, large PR is much better than 10
   quick PRs of simple changes.
3. **Documentation**: Documentation contributions count as full
   software contributions — they are a cornerstone of the project.
4. **Translations**: Translating the project to any new language
   = full contribution.
5. **Rare devices**: The `Compatibility Champion` badge is granted
   upon documenting and testing the module on 3+ devices with
   different environments.
6. **Audit**: The `Auditor` badge is granted when **at least one
   Audit Correction** is accepted after a detailed review.
7. **Platform**: The `Platform Fixer` badge is granted when fixing
   a problem preventing operation on a specific platform.
8. **Metrics**: The `Metrics Wizard` badge is granted for a
   tangible improvement to the metrics/Dashboard system.
9. **Concurrency**: The `Concurrency Guardian` badge is granted
   for fixing a real race condition (RACE-1 or BAK-2).
10. **Ports**: The `Port Architect` badge is granted for fixing
    dynamic ports issues.
11. **Memory (v1.1.0)**: The `Memory Architect` badge is granted
    for testing the dynamic memory limit across 3+ RAM tiers with
    concrete, reproducible data.
12. **Data Preservation (v1.2.0)**: The `Data Guardian` badge is
    granted for testing the 10 defensive layers across 3+ devices
    or 3+ root solutions with concrete, reproducible backup
    reports.
13. **PWA (v1.3.0)**: The `PWA Champion` badge is granted for
    testing the smart PWA install button on 3+ browsers with
    documented behaviour.
14. **Companion App (v1.4.0)**: The `Companion App Champion` badge
    is granted for testing the optional companion Android app on
    3+ devices or 3+ ROMs.

### Disputes

In case of a dispute over accepting a contribution, the final
decision rests with the maintainers of the project.

### Updates

The Hall of Fame is **updated manually** in the following cases:
- End of each major release.
- When a very active and influential contributor appears.
- When the user requests addition to the list after meeting the
  criteria.
- When a new **Audit Correction** is accepted (added immediately
  with its number).
- When a new **Hotfix** is released (the table is updated
  automatically).
- **(v1.1.0)** When a **Memory Architect** report is accepted
  (added immediately).
- **(v1.2.0)** When a **Data Guardian** report is accepted (added
  immediately).
- **(v1.3.0)** When a **PWA Champion** report is accepted (added
  immediately).
- **(v1.4.0)** When a **Companion App Champion** report is
  accepted (added immediately).

---

## 🎖️ Audit Corrections Registry

Official registry of all discovered and fixed Audit Corrections:

### v1.0.0

| # | Description | Version | Reference |
|:-:|---|:---:|---|
| #1 | Fixed a critical typo in `isAllowedLogFile` | v1.0.0 | — |
| #3-e/f | `bootstrap_resolvers` dynamism + IPv6 | v1.0.0 | — |
| #5 | Old `loginAttempts` cleanup | v1.0.0 | — |
| #6-c | `limitedBuffer` (bounded stderr capture) | v1.0.0 | — |
| #7 | Dead code removal from `functions.sh` | v1.0.0 | — |
| #9/#9-b | `os.CreateTemp` (no race) | v1.0.0 | — |
| #10 | Debounce SSE | v1.0.0 | — |
| #13 | CSRF-GET → POST-only | v1.0.0 | [SECURITY.md](SECURITY.md) |
| #14 | `pgrep -x` (no false positives) | v1.0.0 | — |
| #15-a | Remove token from login response | v1.0.0 | [SECURITY.md](SECURITY.md) |
| #15-b | `Allow: POST` header for 405 | v1.0.0 | [SECURITY.md](SECURITY.md) |
| #16-a/b | IPv4/IPv6 firewall separation | v1.0.0 | [SECURITY.md](SECURITY.md) |
| **#17** | **Custom Chains (Orphan Fix)** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#18** | **STATUS_FILE Semantics** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#19** | **IPv6 Rate Limit Bypass** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#20** | **Port Collision 8080** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#21** | **Section-Restricted TOML** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#22** | **Basic Auth Rate Limit Bypass** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#23** | **Section header with comment (parsing)** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#24** | **Exact endpoint matching** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#25** | **Dashboard JSON Conversion** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#26** | **Preserve User Settings on Upgrade** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#27** | **`fuser` PID parsing** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#28** | **Login POST-only (CSRF)** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#29** | **`readConfPort` range check** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#30** | **`/readyz` localhost-only** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#31** | **`shellQuote` injection protection** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#32** | **`rebuildMu` mutex (RACE-1)** | **v1.0.0** | [SECURITY.md](SECURITY.md) |
| **#33** | **`runtime_info` dynamic ports (PORT-2)** | **v1.0.0** | [SECURITY.md](SECURITY.md) |

**Last Audit Correction**: #33 (v1.0.0)
**Next expected**: #34 (in a future release)

### v1.1.0 — No New Audit Corrections

**The v1.1.0 release does not extend the Audit Corrections
Registry.**

This is intentional. The v1.1.0 release introduces three runtime
improvements that close edge cases rather than fix known
exploitable vulnerabilities:

| ID | Change | Type |
|:-:|---|---|
| **MEM-1** | Dynamic memory limit per profile | Runtime improvement |
| **MEM-2** | Extended `shellQuote` charset (`{`, `}`, `\n`, `\t`) | Defense-in-depth |
| **MEM-3** | `MONITORING_UI_PORT` constant in metrics handler | Refactor |

These are documented in [`docs/SECURITY.md`](SECURITY.md) §5.30 and
§17.1 but are **not assigned audit correction numbers**.

**One critical fix in v1.1.0** (`web/offline.html` CSP removal) was
a functional regression, not an exploitable vulnerability — so it
also does not receive an audit correction number.

### v1.2.0 — No New Audit Corrections

**The v1.2.0 release does not extend the Audit Corrections
Registry either.**

This is intentional. The v1.2.0 release is a **data-preservation
release**. Its additions close a data-loss bug and harden the write
path, but they do not fix known exploitable vulnerabilities:

| ID | Change | Type |
|:-:|---|---|
| **BAK-1** | 7-field `runtime_info.backups` | Observability |
| **BAK-2** | `createAutoBackup` + `backupMu` + rotation | Data preservation |
| **BAK-3** | `cleanupOldTransactions` | Housekeeping |
| **BAK-4** | `checkPendingNotifications` | UX / observability |
| **FIX-1** | Recovery-mode correctness via **snapshot-and-reapply** | Correctness fix |
| **FIX-2** | Service Worker update-banner | Correctness fix |

These are documented in [`docs/SECURITY.md`](SECURITY.md) §5.31 and
§5.32 but are **not assigned audit correction numbers**.

### v1.3.0 — No New Audit Corrections

**The v1.3.0 release does not extend the Audit Corrections
Registry either.**

This is intentional. The v1.3.0 release is a **feature release**
(PWA install button, live status LED, DNS auto-start fix). It
contains no security fixes that warrant an audit correction
number.

### v1.4.0 — No New Audit Corrections

**The v1.4.0 release does not extend the Audit Corrections
Registry either.**

This is intentional. The v1.4.0 release is an **integration
release** (companion Android app, CodeQL path-injection hardening,
iOS PWA removal). The CodeQL fix in `removeModule`:

- Closes **two pre-existing CodeQL alerts** (#1 and #2) via
  `filepath.Base()` sanitization.
- Is tracked in `docs/SECURITY.md` as a CodeQL alert fix, **not**
  as a numbered audit correction.
- Follows the same pattern as the v1.3.0 CodeQL cleanup (6 of 8
  alerts closed in v1.3.0).

**The Audit Corrections Registry remains at #33.**

**Next audit correction** (if any) will be **#34**, expected in a
future release.

---

## 📋 Changelog for Contributors

### v1.4.0 (2026-10-06)

**Integration release — no breaking changes.**

**New badge (1)**:

- 🏆 **Companion App Champion (v1.4.0)** — recognizes contributors
  who test the optional companion Android app on 3+ devices or
  ROMs.

**Added**:

- **Companion Android app integration** — a lightweight WebView
  wrapper (~3 MB) is now bundled into the module ZIP as an
  **optional** asset (`web/app-debug.apk`). Fetched from
  [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app).
- **`GET /app-debug.apk`** — new static route in `main.go`.
- **WebUI install button** — converted from a JavaScript modal to a
  plain `<a download href="/app-debug.apk">` link.
- **Release pipeline** — stages the APK before packaging and
  attaches it to the GitHub Release.
- **CI step** — `Verify companion app metadata` (validates
  `proxy/app-apk.version` and `scripts/fetch_app_apk.sh`).

**Fixed**:

- **CodeQL `go/path-injection` in `removeModule`** — 2 alerts
  closed via `filepath.Base()` + `filepath.Join(MODULES_DIR, name)`.

**Removed**:

- **iOS PWA logic** (~35 lines) — Android-only project.

**Audit Corrections**: **None** — the registry remains at **#33**.

**See**: [`CHANGELOG.md`](../CHANGELOG.md) §[v1.4.0].

### v1.3.0 (2026-10-02)

**Feature release — no breaking changes.**

**New badge (1)**:

- 🔔 **PWA Champion (v1.3.0)** — recognizes contributors who test
  the smart PWA install button across Chromium / Firefox / Samsung
  Internet.

**Added**:

- **PWA install button** — dynamic, always-visible, browser-aware.
- **Live status LED** on the Today counter.

**Fixed**:

- **DNS auto-start after boot** — `service.sh` now waits for the
  WebUI then calls `POST /api/ensure_running_service` directly.

**Audit Corrections**: **None** — the registry remains at **#33**.

**See**: [`CHANGELOG.md`](../CHANGELOG.md) §[v1.3.0].

### v1.2.0 (2026-09-29)

**Data-preservation release — no breaking changes.**

**New badge (1)**:

- 🛡️ **Data Guardian** — recognizes contributors who test the
  backup/restore system across devices, root solutions, and
  upgrade scenarios.

**Data-preservation additions (10 defensive layers)**:

- **Layer 1** — Multi-source detection (7 candidate locations).
- **Layer 2** — Persistent backup to `/sdcard/dnscrypt-webui-backup/`.
- **Layer 3** — SHA256 integrity verification (advisory).
- **Layer 4** — Transactional upgrades with rollback.
- **Layer 5** — Root-solution compatibility (Magisk / KernelSU / APatch).
- **Layer 6** — SELinux preservation (`restorecon` / `chcon`).
- **Layer 7** — Recovery mode via trigger file.
- **Layer 8** — Config migrations.
- **Layer 9** — Auto-backup (24 h) + rotation (max 21 snapshots).
- **Layer 10** — Observability (`.upgrade_history.json`,
  `status.sh --diagnose`, 7-field `runtime_info.backups`).

**Runtime additions (4 — documented in `docs/SECURITY.md` §5.31)**:

- **BAK-1** — `runtime_info.backups` returns 7 fields.
- **BAK-2** — `createAutoBackup` + `backupMu` + rotation.
- **BAK-3** — `cleanupOldTransactions`.
- **BAK-4** — `checkPendingNotifications`.

**Correctness fixes (2 — documented in `docs/SECURITY.md` §5.32)**:

- **FIX-1** — Recovery-mode correctness via **snapshot-and-reapply**:
  `§[8a]` restores the 5 files AND copies each one to
  `$MODPATH/.recovery_snapshot/`. `§[9]` extracts the ZIP normally
  (the extraction logic is left untouched, so the normal-install
  path is byte-for-byte identical). `§[9b2]` re-applies the 5 files
  from the snapshot. This strategy does not depend on knowing the
  ZIP's contents.

- **FIX-2** — Service Worker update-banner (send `SKIP_WAITING` to
  the correct worker).

**New API fields (1)**:

- `runtime_info.backups` — a 7-field object describing the backup
  state.

**Documentation updates**:

- `docs/BACKUP.md` — new file (full backup system reference).
- `docs/EMERGENCY.md` — new file (emergency recovery guide).
- `docs/ARCHITECTURE.md` — new sections §3.10, §4.10.
- `docs/API.md` — §6.1.7 extended with the 7-field `backups`.
- `docs/SECURITY.md` — new sections §5.31, §5.32.
- `docs/COMPATIBILITY.md` — new §2.5, §8.4, §10.3, §10.7.
- `docs/FAQ.md` — new section Q121–Q130.
- `docs/CONTRIBUTING.md` — new §8.9, §8.10, §8.11, §9.5, §9.6.
- `docs/DEVELOPMENT.md` — new §8.12, §8.13, §8.14.

**Audit Corrections**: **None** — the registry remains at **#33**.

**See**: [`CHANGELOG.md`](../CHANGELOG.md) §[v1.2.0].

### v1.1.0 (2026-09-26)

**Polish release — no breaking changes.**

**New badges (1)**:

- 🧠 **Memory Architect** — recognizes contributors who test the
  dynamic memory limit across device RAM tiers.

**Runtime improvements (3 — documented in `docs/SECURITY.md` §5.30)**:

- **MEM-1** — Dynamic memory limit per profile. Replaces hardcoded
  80 MB with light=80 / normal=100 / pro=120 / proplus=160 /
  ultimate=220.
- **MEM-2** — Extended `shellQuote` charset (`{`, `}`, `\n`, `\t`).
- **MEM-3** — `MONITORING_UI_PORT` constant used in the metrics
  handler (removes last hardcoded `"8080"`).

**New API fields (2)**:

- `runtime_info.profile_key` — the active blocklist profile.
- `runtime_info.memory_limit_mb` — the effective soft memory limit.

**Critical fix (1)**:

- `web/offline.html` — Removed a restrictive CSP meta that
  silently blocked the page's own scripts.

**Documentation updates**:

- 16 documentation files updated.
- New section in `docs/SECURITY.md` (§5.30).
- New sections in `docs/ARCHITECTURE.md` (§3.9, §4.9).
- New section in `docs/COMPATIBILITY.md` (§5.4).
- New sections in `docs/TROUBLESHOOTING.md` (§4.12, §5.14, §6.10,
  §15.13).
- New questions in `docs/FAQ.md` (Q111–Q120).
- New section in `docs/UPGRADE.md` (§3.0).

**Audit Corrections**: **None** — the registry remains at **#33**.

**See**: [`CHANGELOG.md`](../CHANGELOG.md) §[v1.1.0].

### v1.0.0 (2026-09-24)

**First stable release.**

**Accepted Audit Corrections** (17 new):

- #17 — Custom Chains (Orphan Fix).
- #18 — STATUS_FILE Semantics.
- #19 — IPv6 Rate Limit Bypass.
- #20 — Port Collision 8080.
- #21 — Section-Restricted TOML.
- #22 — Basic Auth Rate Limit Bypass.
- #23 — Section header with comment.
- #24 — Exact endpoint matching.
- #25 — Dashboard JSON Conversion.
- #26 — Preserve User Settings on Upgrade.
- #27 — `fuser` PID parsing.
- #28 — Login POST-only (CSRF).
- #29 — `readConfPort` range check.
- #30 — `/readyz` localhost-only.
- #31 — `shellQuote` injection protection.
- #32 — `rebuildMu` mutex (RACE-1).
- #33 — `runtime_info` dynamic ports (PORT-2).

**Other fixes**:

- Fix #1: Dashboard JSON conversion (Audit #25).
- Fix #2: `getSystemShell()` fallback.
- Fix #3: Preserve settings on upgrade (Audit #26).
- Fix #4: `.gitignore` negation.
- Fix #5: Pre-commit hooks fixed.
- Fix #6: Asset Serving Fix (13 web files).
- Fix #7: CodeQL config drift.
- Fix #8: Basic Auth rate limiting (Audit #22).
- Fix #9: `fuser` PID parsing (Audit #27).
- Fix #10: Section header with comment (Audit #23).
- Fix #11: Per-port cache.
- Fix #12: Exact endpoint matching (Audit #24).

**New badges (5)**:

- 🔧 Platform Fixer.
- 📊 Metrics Wizard.
- ⚙️ Concurrency Guardian.
- 🔌 Port Architect.

**Documentation**:

- 22 files updated.
- 3 new guides.

---

## 🎯 How to Nominate Someone for the Hall of Fame

If you notice a contributor who deserves recognition:

1. **Open an Issue** titled `[Hall of Fame] Nomination: <username>`.
2. **Explain the reason** with evidence:
   - Links to PRs.
   - Links to helpful comments.
   - Provided fixes.
3. **Wait for review** from the maintainer.

**⚠️ Note**: A user cannot nominate themselves except after clearly
meeting the criteria.

---

## 🙏 Thanks to Everyone

**Even if your name is not on this list**, your contribution is
appreciated, including:

- ⭐ Starring the project on GitHub.
- 🐛 Opening a clear, understandable bug report.
- 💡 Suggesting a new feature idea.
- 📣 Sharing the project on social media.
- 💬 Helping other users in the Discussions section.
- 📖 Fixing a simple typo.
- 🆕 Testing on a new platform (Linux, macOS, WSL2).
- 🆕 Reporting a Dashboard issue.
- 🆕 Testing Login POST-only (NEW-1).
- 🆕 Testing `/readyz` localhost-only (NEW-4).
- 🆕 Testing RACE-1 (BLOCKLIST consistency).
- 🆕 **(v1.1.0)** Reporting memory-limit behavior across RAM tiers.
- 🆕 **(v1.2.0)** Testing the 10 defensive layers on a new device.
- 🆕 **(v1.2.0)** Reporting the 7-field `backups` object from a
  real device.
- 🆕 **(v1.2.0)** Testing recovery mode (`touch recovery && reboot`).
- 🆕 **(v1.2.0)** Testing the bilingual WebUI (EN ↔ AR toggle).
- 🆕 **(v1.3.0)** Testing the PWA install button on a new browser.
- 🆕 **(v1.4.0)** Testing the companion Android app on a new device.
- 🆕 **(v1.4.0)** Reporting CodeQL alerts on a modified branch.

...all are **very important contributions** and shape the success
and value of this project.

**Thank you all!** ❤️

---

## 📚 References

- [`SECURITY.md`](SECURITY.md) — How to report vulnerabilities +
  Audit Corrections Registry (§5.31, §5.32).
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — Contribution guide.
- [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) — Code of Conduct.
- [`CHANGELOG.md`](../CHANGELOG.md) — Version history (v1.0.0 +
  v1.1.0 + v1.2.0 + v1.3.0 + v1.4.0).
- [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — System architecture.
- [`docs/API.md`](API.md) — HTTP API Reference.
- [`docs/BACKUP.md`](BACKUP.md) — **Backup system reference
  (v1.2.0)**.
- [`docs/EMERGENCY.md`](EMERGENCY.md) — **Emergency recovery
  (v1.2.0)**.
- [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) — DNS binaries
  (Level 4).
- [`docs/GLOSSARY.md`](GLOSSARY.md) — Glossary.
- [`docs/ROADMAP.md`](ROADMAP.md) — Project plan.
- [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) — Compatibility
  matrix.
- [`docs/UPGRADE.md`](UPGRADE.md) — Version upgrade guide (§3.0,
  §3.1).
- [`docs/FAQ.md`](FAQ.md) — Frequently asked questions
  (Q121–Q130).
- [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) — This file.

### Companion App Repository

- **Repository**: https://github.com/gasciljh/dnscrypt-proxy-app
- **Releases**: https://github.com/gasciljh/dnscrypt-proxy-app/releases
- **Issues**: https://github.com/gasciljh/dnscrypt-proxy-app/issues

---

<div align="center">

**Last updated**: 2026-10-06
**Version**: v1.4.0

[⬆ Back to top](#hall-of-fame--dnscrypt-smart-filter)

</div>