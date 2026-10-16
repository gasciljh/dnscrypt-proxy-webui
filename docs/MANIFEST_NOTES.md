# Manifest Notes — DNSCrypt Smart Filter

Consolidated technical reference for every `x-note-*` field in
`web/manifest.json`.

**Version**: v1.5.0 (Global Edition)
**Last updated**: 2026-10-15
**Author**: gasciljh
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui

---

## Table of Contents

1. [Purpose](#1-purpose)
2. [Why This File Exists](#2-why-this-file-exists)
3. [Source of Truth](#3-source-of-truth)
4. [Maskable Safe Zone](#4-maskable-safe-zone)
5. [Icon Source Pipeline](#5-icon-source-pipeline)
6. [Language Policy](#6-language-policy)
7. [Backup Schema](#7-backup-schema)
8. [Reserved Ports](#8-reserved-ports)
9. [PWA Shortcuts — Dual-Origin Limitation](#9-pwa-shortcuts--dual-origin-limitation)
10. [Companion APK Integration](#10-companion-apk-integration)
11. [Tracked-File Model](#11-tracked-file-model)
12. [Deferred Items](#12-deferred-items)
13. [Cross-References](#13-cross-references)

---

## 1. Purpose

`web/manifest.json` is parsed by the browser on every PWA
install. Its file size directly affects the install prompt
latency and the Service Worker's precache count.

Historically, the manifest carried **11 `x-note-*` fields**
totaling ~6 KB. As of v1.5.0, this was reduced to **5 fields**
totaling ~3 KB. The removed technical detail — maskable safe
zones, icon generation pipelines, backup schema, deferred
work — now lives **here** in `docs/MANIFEST_NOTES.md`.

This file is the **canonical reference** for those details.
`web/manifest.json`'s `x-note-docs` field points here.

---

## 2. Why This File Exists

| Reason | Effect |
|---|---|
| **Manifest size** | Reduced from ~6 KB to ~3 KB — faster install prompt, smaller precache payload |
| **Single source of truth** | Every technical note that used to live inline in the manifest is now here, versioned and diffable |
| **Better grep** | `grep -r "x-note-maskable"` finds the manifest reference and this file's full explanation |
| **Easier translation** | Technical prose no longer mixes with structural JSON |
| **Cleaner diffs** | A manifest change (e.g. adding a new icon size) produces a small diff, not a reflow of prose |

---

## 3. Source of Truth

| `x-note-*` field in manifest.json | Full reference |
|---|---|
| `x-note-last-updated` | this file, header |
| `x-note-version` | `VERSION` + `docs/ARCHITECTURE.md` §8 |
| `x-note-companion-apk` | §10, §11 |
| `x-note-shortcuts` | §9 |
| `x-note-docs` | this file (entry point) |

**Note**: `x-note-ports`, `x-note-maskable`, `x-note-icon-source`,
`x-note-language`, `x-note-backup-schema`, `x-note-future-work`,
and `x-note-companion-apk`'s file-count claim were **moved here**
in v1.5.0. They no longer exist as standalone fields in the
manifest.

---

## 4. Maskable Safe Zone

### 4.1 W3C Specification

Per the [W3C Web App Manifest](https://www.w3.org/TR/appmanifest/#maskable),
the **maskable safe zone** is a **circle** whose diameter is
**80%** of the icon's smallest dimension, centered on the icon.

For a **512×512** canvas:

```
radius = (512 × 0.8) / 2 = 204.8 px
center = (256, 256)
test   : (x - 256)² + (y - 256)² ≤ 41943
```

Any pixel outside this circle may be cropped by the launcher's
mask shape.

### 4.2 Current Icon

`web/icon-512.svg` is declared in the manifest with **two
purposes**:

| Entry | `src` | `purpose` |
|---|---|---|
| `icons[2]` | `/icon-512.png` | `any` |
| `icons[4]` | `/icon-512.png` | `maskable` |

### 4.3 Shield Control-Point Analysis

Every control point of the shield path in `icon-512.svg` fits
inside the W3C safe circle with comfortable margins:

| Point | Coordinates | Distance from center | Margin |
|---|---:|---:|---:|
| Top vertex | (256, 60) | 196.0 px | **+8.8 px** |
| Right shoulder | (416, 142) | 196.5 px | **+8.3 px** |
| Right edge | (416, 256) | 160.0 px | +44.8 px |
| Bottom vertex | (256, 448) | 192.0 px | +12.8 px |
| Left shoulder | (96, 142) | 196.5 px | **+8.3 px** |
| Left edge | (96, 256) | 160.0 px | +44.8 px |

**Result**: no clipping on launchers that apply a **40%
circular mask** (Pixel Launcher, most AOSP builds).

### 4.4 Known Limitations

On OEM launchers with **45%+ circular masks**, the shield's
shoulders may clip by a few pixels. This is inherent to a
shield-shaped icon at 512 px — a purpose-built maskable asset
would require a different silhouette (typically a solid square
with the glyph centered). See §12 Deferred Items.

### 4.5 Verification

```bash
# Confirm the shield path in the SVG matches the analysis
grep -oE 'M [0-9]+ [0-9]+' web/icon-512.svg
```

Expected output includes:

```
M 256 60       # top vertex
M 256 76 ...   # inner highlight
```

---

## 5. Icon Source Pipeline

### 5.1 Mapping

`scripts/generate-icons.sh` produces every PNG/ICO from the two
SVG sources:

| Source SVG | Output file | Size | Purpose |
|---|---|---:|---|
| `icon-192.svg` | `icon-192.png` | 192×192 | PWA small |
| `icon-512.svg` | `icon-512.png` | 512×512 | PWA large |
| `icon-512.svg` | `apple-touch-icon.png` | 180×180 | Launcher fallback |
| `icon-512.svg` | `favicon-32x32.png` | 32×32 | Modern favicon |
| `icon-512.svg` | `favicon-16x16.png` | 16×16 | Legacy favicon |
| `favicon-16/32.png` | `favicon.ico` | multi | IE + bookmarks |

### 5.2 Critical Note

**`icon-192.png` is generated from `icon-192.svg`**, NOT from
`icon-512.svg`. The two SVG sources have different viewBox
scales and different corner treatments (rounded vs full-bleed).
Mixing them would produce a visually inconsistent small icon.

### 5.3 Regeneration Command

```bash
./scripts/generate-icons.sh --force
```

**Always regenerate PNGs before bumping `CACHE_VERSION` in
`web/sw.js`.** Otherwise, clients with an existing cache keep
the old PNGs for the full `CACHE_VERSION` lifetime.

### 5.4 Tool Chain

The generation script auto-detects the first available tool
from: `rsvg-convert` → `magick` → `convert` → `inkscape`.

For `favicon.ico`: `ImageMagick` → `icotool` → PNG-as-ICO
fallback.

---

## 6. Language Policy

### 6.1 Decision

The project is **English default + Arabic toggle**. The manifest
declares:

```json
"lang": "en",
"dir": "ltr"
```

### 6.2 Rationale

- **Single canonical default** — English (Global Edition).
- **First-class Arabic** — full RTL CSS, bilingual strings in
  every HTML file, no fork or parallel codebase.
- **Client-side only** — the toggle is stored in
  `localStorage['dnscrypt-lang']` and never transmitted.
- **Server-neutral** — the HTTP API returns JSON without
  localized strings (except AR/EN message pairs on install
  errors).

### 6.3 Runtime Behavior

| State | `document.documentElement` |
|---|---|
| First visit | `lang="en" dir="ltr"` |
| User clicks toggle | `lang="ar" dir="rtl"` |
| Reload | Restored from `localStorage` in a `<script>` in `<head>` (before CSS paints, to avoid FOUC) |

### 6.4 Service Worker

The SW is **language-neutral**. It does not read
`localStorage` (that API is not available inside a Service
Worker context) and caches only language-agnostic assets.

### 6.5 No Server State

No server-side preference is stored. Two devices pointing at
the same module can have different languages.

---

## 7. Backup Schema

### 7.1 The `runtime_info.backups` Object

`GET /api?action=runtime_info` returns a **7-field** `backups`
object (introduced in v1.2.0):

| Field | Type | Description |
|---|---|---|
| `available` | int | Number of snapshots (see §7.2) |
| `in_flight_txn` | int | Number of `txn-*` directories |
| `orphan_txn` | int | Number of `orphan-txn-*` directories |
| `last_backup` | string \| null | mtime of the newest snapshot, formatted `YYYY-MM-DD HH:MM:SS` |
| `last_backup_name` | string \| null | Directory name of the newest snapshot |
| `last_stable` | string \| null | Content of `.last_stable` pointer, or `null` |
| `path` | string | Absolute path of the persistent backup directory |

### 7.2 Snapshot Detection Rule (SNAP-MANIFEST)

A directory counts as a snapshot **if and only if** it contains
a `.manifest.json` file.

Excluded by name:
- `current/`
- `txn-*`
- `orphan-txn-*`
- `apk/` (v1.5.0)
- `.restore_snap.*`

### 7.3 Sort Rule (SNAP-MTIME)

Snapshots are sorted by **mtime** (descending), not by
directory name. This is robust against clock drift and manual
renames.

### 7.4 Rotation Policy

`rotate_backups()` keeps the **21 newest** snapshots by mtime,
with two protected targets:

- The `.last_stable` pointer (recovery target).
- The newest install snapshot (name matching `-v<digit>`).

The `apk/` subfolder is preserved by **two independent
mechanisms**:
1. It lacks a `.manifest.json` (SNAP-MANIFEST excludes it).
2. It is explicitly listed in the `case` skip inside
   `rotate_backups()`.

### 7.5 Diagnostics

```bash
# Full backup state
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'

# On-device diagnostic
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups'
```

Full reference: [`BACKUP.md`](BACKUP.md) §8.

---

## 8. Reserved Ports

### 8.1 Port Table

| Port | Service | Configurable |
|:----:|---|---|
| **9090** | WebUI | `webui.conf` → `PORT` |
| **9091** | Dashboard | `webui.conf` → `DASHBOARD_PORT` |
| **8080** | `monitoring_ui` (internal) | **Reserved — do not change** |
| **5354** | DNS engine (internal) | **Reserved — do not change** |

### 8.2 Reserved Port 8080

`8080` is the internal `monitoring_ui` port that
`dnscrypt-proxy` exposes. It is **hardcoded** as a Go constant
(`MONITORING_UI_PORT`) in `main.go` and as `_MONITORING_UI_PORT`
in `proxy/boot-mini.sh`.

**Cross-file sync guarantee**: CI verifies that both values
match (`ci.yml` Step 10 — Verify reserved-port constant sync).

### 8.3 Guard Chain

Every component rejects port 8080 for WebUI or Dashboard:

| Component | Check |
|---|---|
| `main.go` | refuses to start if `PORT=8080` or `DASHBOARD_PORT=8080` |
| `customize.sh` | resets to 9090/9091 with a warning |
| `functions.sh` | `get_webui_port` / `get_dashboard_port` fall back |
| `boot-mini.sh` | `get_webui_port` Port Guard |
| `action.sh`, `service.sh`, `status.sh`, `watchdog.sh` | check before use |

### 8.4 Range Check

`readConfPort()` validates `[1, 65535]`. Values outside the
range fall back to the default (9090 / 9091).

---

## 9. PWA Shortcuts — Dual-Origin Limitation

### 9.1 The Problem

The module exposes **two separate HTTP servers**:

- WebUI on port **9090**
- Dashboard on port **9091**

In browser terms, these are **different origins**
(`http://127.0.0.1:9090` ≠ `http://127.0.0.1:9091`).

### 9.2 Manifest Constraint

A Web App Manifest's `shortcuts[]` URLs **MUST be same-origin
with the manifest's `start_url`**. A single manifest installed
from port 9090 cannot navigate to port 9091 through a shortcut.

### 9.3 Current Design

Both shortcuts in `web/manifest.json` use **relative URLs**:

```json
"url": "/?source=shortcut_webui"
"url": "/?source=shortcut_dashboard"
```

These resolve to the manifest's **current origin** at install
time.

| Install origin | Both shortcuts open |
|---|---|
| 9090 (WebUI) | WebUI |
| 9091 (Dashboard) | Dashboard |

### 9.4 Compensating Mechanism

Because shortcuts cannot cross origins, the WebUI provides a
**dynamic Dashboard link** built from
`/api?action=runtime_info`:

```javascript
// web/index.html
if (data.dashboard_port) {
    PORTS.dashboard = String(data.dashboard_port);
    updateDashboardLink();
}
```

This link works for any configured port and any hostname
(127.0.0.1, `[::1]`, LAN IPs).

### 9.5 Future Fix

The long-term solution is to **unify the WebUI and Dashboard
on a single port** (e.g. Dashboard at `/dashboard`), which
would eliminate the dual-origin problem entirely. See §12
Deferred Items.

---

## 10. Companion APK Integration

### 10.1 Serving

The companion Android app is served at:

```
GET /app-debug.apk
```

Public route — **no authentication**. Returns 404 when the APK
is absent (developer builds).

### 10.2 Cache-Control

```http
Cache-Control: public, max-age=3600, immutable
```

The browser's own HTTP cache is the primary storage layer. The
Service Worker bypasses this path (rule 9 in `sw.js`).

### 10.3 Version Pinning

The APK version is pinned in `proxy/app-apk.version` (currently
`1.0.0`, no `v` prefix). This is the **Single Source of Truth**
for the companion app version.

A version bump in that file propagates to:
- `scripts/fetch_app_apk.sh` (fetcher)
- `web/index.html`'s `getCompanionApkUrl()` (dynamic URL builder)
- `release.yml` (staging step)

### 10.4 SHA256 Verification

When `web/app-debug.apk.sha256` is present in the module ZIP,
`install_app.sh` verifies the APK hash before any install
strategy is attempted. If the file is absent (dev builds), the
script degrades to advisory mode.

### 10.5 Source Repository

The APK is built in a separate repository:
**[gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)**.

The module's `release.yml` fetches it at build time via
`scripts/fetch_app_apk.sh`.

---

## 11. Tracked-File Model

### 11.1 Three Canonical States

| State | When | Tracked | Artifacts | Working tree | Dirs |
|---|---|:---:|:---:|:---:|:---:|
| Fresh clone | After `git clone` | 97 | 0 | 97 | 15 |
| After package | After `make fetch-apk && make package` | 97 | 4 | 101 | 17 |
| After full build | After `make build` | 97 | 11 | 108 | 18 |

### 11.2 Canonical Commands

```bash
git ls-files | wc -l                                            # 97
find . -type f -not -path './.git/*' | wc -l                    # 97 / 101 / 108
find . -type d -not -path './.git/*' -not -name '.git' | wc -l  # 15 / 17 / 18
```

The **tracked count (97)** is fixed and independent of the
local build state. It is the number GitHub sees.

### 11.3 Cross-References

The same three-state model is documented in:
- `README.md` §Project Structure
- `docs/ARCHITECTURE.md` §8.2–§8.3
- `web/manifest.json` → `x-note-companion-apk` (summary only)

---

## 12. Deferred Items

The following items were considered and **intentionally not**
shipped in v1.5.0. Tracked in
[`ROADMAP.md`](ROADMAP.md).

| Item | Reason |
|---|---|
| **Purpose-built maskable icon** | Current PNG reuses `icon-512.png`; a dedicated asset would improve 45%+ mask compatibility |
| **CSP `'unsafe-inline'` removal** | Requires converting ~40 inline `onclick=` handlers to `addEventListener()` |
| **PWA port unification** | Move Dashboard to `/dashboard` on port 9090 — eliminates the dual-origin limitation (§9) |
| **Real screenshots array** | Chrome's richer install UI requires a `screenshots[]` field |
| **Multi-language support (FR/DE/ES/RU/ZH)** | Each adds ~2 KB to `index.html`; scope creep without demand |
| **Companion app manifest entry** | A dedicated manifest for the WebView wrapper |
| **Backup integrity enforcing mode** | Currently advisory only (see §7) |
| **`append_denylist` from WebUI** | Endpoint exists; UI does not use it |
| **Data Guardian badge tooling** | Manual verification required today |
| **Companion app deep-links** | `dnsproxy://` scheme for cross-app navigation |

---

## 13. Cross-References

| Topic | Primary reference |
|---|---|
| Backup system | [`BACKUP.md`](BACKUP.md) |
| Emergency recovery | [`EMERGENCY.md`](EMERGENCY.md) |
| Version upgrade | [`UPGRADE.md`](UPGRADE.md) |
| Architecture | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| HTTP API | [`API.md`](API.md) |
| Security model | [`SECURITY.md`](SECURITY.md) |
| Compatibility | [`COMPATIBILITY.md`](COMPATIBILITY.md) |
| Roadmap | [`ROADMAP.md`](ROADMAP.md) |
| Layered Bootstrap (ADR) | [`adr/0008-layered-bootstrap.md`](adr/0008-layered-bootstrap.md) |
| External dependency (ADR) | [`adr/0007-external-dependency-securejoin.md`](adr/0007-external-dependency-securejoin.md) |
| Version history | [`../CHANGELOG.md`](../CHANGELOG.md) |

---

**Last updated**: 2026-10-15
**Version**: v1.5.0
**Author**: gasciljh

---

## 14. Note on `.secrets.baseline`

The `version` field in `.secrets.baseline` (`"1.5.0"`) is the
**detect-secrets schema version**, not the module version. The
value happens to coincide with the current module version by
coincidence. **Do not update it during releases** — `detect-secrets`
manages this field automatically.
