# Roadmap — DNSCrypt Smart Filter

> What's coming next — the forward-looking plan.

**Version**: v1.5.0 (Global Edition)
**Last updated**: 2026-10-19
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

---

## Table of Contents

1. [Philosophy & Priorities](#1-philosophy--priorities)
2. [v1.6.0 — Planned](#2-v160--planned)
3. [v2.0.0 — 2028](#3-v200--2028)
4. [Under Consideration](#4-under-consideration)
5. [Permanently Excluded](#5-permanently-excluded)
6. [See Also](#6-see-also)

---

## 1. Philosophy & Priorities

### 1.1 Six Principles

| # | Principle | Implementation |
|:-:|---|---|
| 1 | **Zero Telemetry** | No unauthorized external connections |
| 2 | **Localhost-First** | All services are local by default |
| 3 | **Minimal External Deps** | Go stdlib + exactly ONE authorized external dependency (`filepath-securejoin`, ADR-0002) |
| 4 | **Backward Compatible** | Upgrade is always safe |
| 5 | **User-Controlled** | Nothing runs without user decision |
| 6 | **Stable Release Workflow** | `main` is always stable; features are integrated through `develop` |

### 1.2 Priority Criteria

Every proposed feature is evaluated on six axes:

- 🎯 **Impact** — how many users benefit?
- ⚡ **Cost** — how long does implementation take?
- 🔒 **Security** — does it improve or weaken security?
- 🎨 **Complexity** — does it increase project complexity?
- 🧪 **Testability** — can it be tested automatically?
- ⚠️ **Stability** — does it affect RACE-1 (concurrency), PORT-2 (dynamic ports), or the v1.5.0 install cascade?

### 1.3 Symbols

| Symbol | Meaning |
|:---:|---|
| 📅 | Planned |
| 💡 | Under study |
| ⏸️ | Deferred |
| ❌ | Excluded |

### 1.4 Timeline at a Glance

| Version | Date | Type | Status |
|---|---|---|---|
| v1.0.0 | 2026-09-24 | Stable | ✅ shipped |
| v1.1.0 | 2026-09-26 | Polish | ✅ shipped |
| v1.2.0 | 2026-09-29 | Data-preservation | ✅ shipped |
| v1.3.0 | 2026-10-02 | Feature | ✅ shipped |
| v1.4.0 | 2026-10-06 | Integration | ✅ shipped |
| **v1.5.0** | **2026-10-13** | **Global Edition** | ✅ **current** |
| v1.6.0 | 2027 Q1–Q2 | Feature + hardening | 📅 planned |
| v2.0.0 | 2028 | Major rewrite | 💡 under study |

For what was delivered in each shipped version, see
[`CHANGELOG.md`](../CHANGELOG.md).

---

## 2. v1.6.0 — Planned

**Type**: Feature + hardening (MINOR).
**Goal**: Security hardening + PWA unification + advanced features.
**Status**: 📅 Planned.

> **Scope note**: v1.6.0 consolidates deferred work from v1.5.0
> (CSP hardening, PWA unification, backup integrity hardening)
> with the previously planned features (multi-language, 2FA,
> audit log, JWT). The release may ship in multiple MINOR
> iterations (v1.6.0, v1.6.x, v1.7.0).

### 2.1 Core Features (15 items)

| # | Feature | Priority | Complexity | Estimate |
|:-:|---|:---:|:---:|:---:|
| 1 | **Remove `'unsafe-inline'` from CSP** — convert inline handlers to `addEventListener`; nonce for remaining | 🔴 | 🟡 | 1–2 weeks |
| 2 | **Unify WebUI + Dashboard on one port** — single origin → single SW; `/api/metrics` moves to 9090 | 🟡 | 🟡 | 2–3 weeks |
| 3 | **Dedicated maskable icon** — SVG + PNG with wider safe zone; update manifest + sw.js | 🟡 | 🟢 | 3–5 days |
| 4 | **Backup integrity hardening** — `BACKUP_INTEGRITY_MODE=advisory\|enforce` in `webui.conf` | 🟡 | 🟡 | 1 week |
| 5 | **Extended multi-language** — FR, DE, ES, RU, ZH | 🟡 | 🟡 | 1–2 weeks/lang |
| 6 | **2FA (TOTP, RFC 6238)** — QR code + backup codes + enforcement policy | 🟡 | 🔴 | 2–3 weeks |
| 7 | **Audit logging** — structured JSON for every action | 🟡 | 🟡 | 1–2 weeks |
| 8 | **JWT authentication** — Bearer token alongside cookie; configurable expiry | 🟢 | 🟡 | 1 week |
| 9 | **Resolver health UI** — Prometheus metrics without `query_log` | 🟡 | 🟡 | 1–2 weeks |
| 10 | **Advanced rules editor** — syntax highlight + auto-complete + real-time validation + diff view | 🟡 | 🟡 | 2–3 weeks |
| 11 | **`append_denylist` with content** — WebUI sends `content` parameter (bug from v1.2.0) | 🟡 | 🟢 | 2–3 days |
| 12 | **Companion deep-links** — `dnsproxy://webui` + `dnsproxy://dashboard` | 🟢 | 🟢 | 2–3 days |
| 13 | **Companion version automation** — extend `make check-app-version` to compare with GitHub release | 🟢 | 🟢 | 1–2 days |
| 14 | **Backup export to PC** — `GET /api/export_backup` returning `.tar.gz` | 🟡 | 🟢 | 3–5 days |
| 15 | **Import/Export settings JSON** — single blob reusing v1.2.0 backup infra | 🟡 | 🟡 | 1 week |

### 2.2 Planned Fixes (4 items)

| # | Fix | Complexity |
|:-:|---|:---:|
| 16 | **`pgrep -x` on Android 5.x** — detect broken `pgrep -x`, fall back to `ps -ef \| grep` | 🟢 |
| 17 | **`awk` parser with `]` in TOML comment** — refine end-of-array match | 🟡 |
| 18 | **CSS cleanup** — remove unused rules from `index.html` (~1,500 lines today) | 🟢 |
| 19 | **Consolidate modal state** — replace `installModalActive` + `companionInstallInFlight` with `currentModal` state machine | 🟡 |

### 2.3 Performance Improvements (3 items)

| # | Improvement | Complexity |
|:-:|---|:---:|
| 20 | **Cache entries count** — `.count` file updated on rebuild; skip full line count | 🟢 |
| 21 | **Batch SSE broadcasts** — 100 ms buffer reduces overhead ~40% | 🟡 |
| 22 | **Dashboard metrics optimization** — cache upstream Prometheus for 5 s; invalidate on `update_profile` | 🟡 |

### 2.4 Workflow / Testing (3 items)

| # | Item | Complexity |
|:-:|---|:---:|
| 23 | **Badge support tooling** — `scripts/report-{memory,backup,rotation,install}.sh` + issue templates | 🟢 |
| 24 | **Live Dashboard tests** — mock `monitoring_ui`; verify JSON schema | 🟡 |
| 25 | **Android Emulator integration test for cascade** — boot emulator, run `install_app.sh --status`, exercise levels 1–3 | 🔴 |

**Estimated total**: ~20–28 weeks spread across 2–3 MINOR releases.

---

## 3. v2.0.0 — 2028

**Type**: Major release (MAJOR — Breaking).
**Goal**: Complete rebuild.
**Status**: 💡 Under study.

### 3.1 Goals

| Goal | Description |
|---|---|
| **3× faster** | Improve performance by 200% |
| **Modern interface** | Preact/HTM instead of Vanilla JS |
| **DoQ support** | DNS over QUIC |
| **Docker / Linux** | Full Linux x86_64 support (not just Android) |
| **API v2** | Full REST + OpenAPI |
| **Multi-Node** | Manage several devices from one panel |
| **Plugin System** | Add flexibility for developers |
| **Unified companion app** | Merge module + companion app into one deliverable |

### 3.2 Planned Breaking Changes

| Current | New | Reason |
|---|---|---|
| `/api?action=X` | `/api/v2/*` | Cleaner REST surface |
| `webui.conf` | `config.yaml` | Structured config; safer parsing |
| `STATUS_FILE` | `state.json` | Structured state |
| Cookie auth | JWT + OAuth2 | API-first authentication |
| 2 ports (9090 + 9091) | 1 unified port | PWA unification |
| `web/*.html` (static) | SPA (Preact) | Better UX, smaller payloads |
| Separate companion app | Merged into module | Single distribution |

---

## 4. Under Consideration

These are not committed to any release. They are recorded for
community discussion and future prioritization.

### 4.1 Possible Features

| Feature | Initial Evaluation |
|---|---|
| DNS Query Log UI | 🟡 Useful, but consumes a lot of space |
| Live Traffic Graph | 🟡 Nice, but requires data collection |
| Per-App Rules | 🔴 Very complex (requires VPN API) |
| Scheduled Rules | 🟡 Useful (e.g. block games after 8pm) |
| Geolocation Blocking | 🟡 Useful, but requires GeoIP database |
| Custom DNS Servers | 🟢 Easy, useful |
| Parental Controls | 🟡 Useful for families |
| CPU Temperature Monitor | 🟢 Easy |
| Battery Usage Stats | 🟡 Useful |
| Webhook Notifications | 🟡 Useful for advanced users |
| Metrics Export (Prometheus) | 🟡 For advanced users |
| Custom Themes | 🟢 Easy |
| Desktop Widgets | 🔴 Complex |
| Multi-Protocol Support | 🟡 DNSCrypt + DoH + DoT simultaneously |
| Docker Deployment | 🟡 Linux-based deployment |
| Systemd Integration | 🟡 Linux service management |
| USB Mode | 🟡 Configuration via USB (Android) |
| CLI Tool | 🟡 Separate `dnscrypt-cli` |
| GraphQL API | 🟡 Alternative to REST API v2 |
| WebSocket | 🟡 Alternative to SSE (bidirectional) |
| IPv6-only mode | 🟢 For modern devices |
| Remote backup storage (WebDAV, S3) | 🟡 Must remain opt-in |
| Tiered retention (daily/weekly/monthly) | 🟡 Carried from v1.2.0 draft |

### 4.2 Ideas Temporarily Rejected

| Idea | Reason |
|---|---|
| Cloud Sync | Violates Localhost-First |
| Remote API | Violates Localhost-First |
| Analytics Dashboard | Zero Telemetry |
| SaaS Version | Violates project philosophy |
| iOS companion app | Android-only project |

### 4.3 Deferred (Not Permanently Excluded)

These items are **deferred** — not permanently excluded, but not
shipped as of v1.5.0. They may be revisited in v1.6.0 or later.

| Feature | Reason | Target |
|---|---|---|
| **Signed releases via Cosign / Sigstore** | Key management burden for a single maintainer; SHA-256 + annotated tag provide baseline integrity. See `docs/adr/0001-release-workflow.md` §2 "Correction Notice — Signing and SBOM". | v2.0.0 or when signing infrastructure is ready |
| **SBOM generation (SPDX + CycloneDX)** | Requires a dedicated build step; deferred to keep the release pipeline lean in v1.x. See `docs/adr/0001-release-workflow.md` §2 "Correction Notice — Signing and SBOM". | v2.0.0 |

---

## 5. Permanently Excluded

| Feature | Reason |
|---|---|
| Telemetry / Analytics | Violates Zero-Telemetry |
| Cloud Sync | Violates LocalHost-First |
| Remote Account | No need for a local project |
| Ads / Monetization | Project is completely free |
| HTTPS-only | Breaks loopback (no certificate) |
| Per-App Blocking | Requires VPN API (complex) |
| Deep Packet Inspection | Violates privacy |
| Traffic Shaping | Outside DNS filter scope |
| Root without Magisk / KernelSU / APatch | Project is module-based |
| iOS Support | iOS does not support Magisk (confirmed by v1.4.0 iOS removal) |

---

## 6. See Also

- **What was delivered** → [`CHANGELOG.md`](../CHANGELOG.md)
- **How to contribute to priorities** →
  [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) §9
- **Development workflow priorities** →
  [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) §10
- **Why a decision was made** → [`docs/MAP.md`](MAP.md) §8
- **Full documentation structure** → [`docs/MAP.md`](MAP.md)

---

*Last updated: 2026-10-17*
*Version: v1.5.0 (Global Edition)*
*Author: gasciljh*