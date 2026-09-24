# Roadmap — DNSCrypt Smart Filter

> What's coming next in DNSCrypt Smart Filter — a comprehensive vision for future releases.

**Current version**: v1.0.0
**Last updated**: 2026-09-24
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **📖 Development workflow**:
> - Git branching strategy → [`docs/BRANCHING.md`](BRANCHING.md)
> - Release process → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [✅ What Was Delivered in v1.0.0](#2--what-was-delivered-in-v100)
3. [v1.1.0 — Q4 2026](#3-v110--q4-2026)
4. [v1.2.0 — Q1 2027](#4-v120--q1-2027)
5. [v1.3.0 — Q2 2027](#5-v130--q2-2027)
6. [v2.0.0 — 2028](#6-v200--2028)
7. [Under Consideration](#7-under-consideration)
8. [Permanently Excluded](#8-permanently-excluded)
9. [How to Contribute to Priorities](#9-how-to-contribute-to-priorities)
10. [Development Workflow Priorities](#10-development-workflow-priorities)

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
- ⚙️ **Stability**: Does it affect RACE-1 (concurrency) or PORT-2 (dynamic ports)?

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
| Build scripts (scripts/) | **5** (added `release.sh`, `release-patch.sh`) |
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
- ✅ **Splitting fixes by severity** (Critical → High → Medium) eased prioritization.
- ✅ **Backup/restore of settings** solved a long-standing problem.
- ✅ **`getSystemShell()`** fixed CI permanently.
- ✅ **Adapter Pattern** for metrics (Prometheus → JSON) avoided upstream modifications.
- ✅ **`sync.Once`** for `getSystemShell` — zero overhead.
- ✅ **Per-port cache** fixed the drift issue.
- ✅ **Two-branch model** (`main` + `develop`) keeps releases stable while enabling
  fast feature iteration — see [`docs/BRANCHING.md`](BRANCHING.md).
- ✅ **Automated `release.sh`** reduces human error during version bumping.
- ✅ **ADR system** provides a transparent audit trail for architectural decisions —
  including explicit reversals (see [ADR-0004](adr/0004-unified-pr-template.md) vs
  [ADR-0005](adr/0005-release-specific-pr-template.md)).

**What didn't work yet**:
- ⚠️ **CSP `'unsafe-inline'`** is still present (target: v1.1.0).
- ⚠️ **Some Dashboard fields** remain empty (`resolver_health`, `top_domains`).
- ⚠️ **PWA dual-origin limitation** (9090 ≠ 9091) — needs unification.
- ⚠️ **`manifest.json` shortcuts** cannot read `runtime_info` (static).

**Lessons**:
- 🎓 **Order matters**: Fix Critical before features.
- 🎓 **Comprehensive documentation** is part of the fix.
- 🎓 **Retry logic** is essential in CI for anything depending on the internet.
- 🎓 **Coarse-grained `rebuildMu` lock**: Simpler + no deadlock.
- 🎓 **Dynamic ports via `runtime_info`**: Needs both Frontend + Backend changes.
- 🎓 **Using `window.location.hostname`** in JS is better than `127.0.0.1` (LAN + IPv6).
- 🎓 **Branch strategy upfront** prevents accidental `main` pollution later.
- 🎓 **Reversals are healthy**: ADR-0004 → ADR-0005 proves the ADR system works.
- 🎓 **Naming matters**: `hotfix.sh` → `release-patch.sh` reduced conceptual confusion
  (see [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md)).

---

## 3. v1.1.0 — Q4 2026

**Type**: ✨ Feature Release (MINOR).
**Goal**: Security + UX + unification.
**Status**: 📅 Planned.

### 3.1 Core Features

#### 🎯 3.1.1 Remove `'unsafe-inline'` from CSP

**Status**: 📅 Planned
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

#### 🎯 3.1.2 Unify WebUI + Dashboard on one port

**Status**: 📅 Planned
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium
**Reference**: `docs/ARCHITECTURE.md`

**Current problem:**
- **PWA dual-origin limitation**: Service Worker bound to a single origin (9090 ≠ 9091).
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

#### 🎯 3.1.3 Improve `manifest.json` shortcuts

**Status**: 📅 Planned
**Priority**: 🟢 Low
**Complexity**: 🟢 Easy

**Current problem**: Shortcuts are static (9090/9091 hardcoded).

**Solution**:
- After §3.1.2 (port unification), no need for duplicate shortcuts.
- Single shortcut for `/dashboard`.

**Estimate**: ~1 day.

---

#### 🎯 3.1.4 Encrypt credentials file

**Status**: 📅 Planned
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium

**Current problem:**
`/data/local/tmp/dnscrypt_credentials.txt` contains username/password in plain text.

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

#### 🆕 🎯 3.1.5 Add live Dashboard tests

**Status**: 📅 Planned (new)
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium

**Idea**: Add end-to-end tests for the Dashboard:
- Mock monitoring_ui server.
- Simulate Prometheus text.
- Verify JSON output schema.

**Estimate**: ~3-5 days.

---

### 3.2 Planned Fixes

#### 🔧 3.2.1 `pgrep -x` on Android 5.x

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

#### 🔧 3.2.2 `awk` parser with `]` in comment

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

#### 🔧 3.2.3 CSS cleanup

**Status**: 📅 Planned | **Complexity**: 🟢 Easy
`index.html` has ~1500 lines of CSS. Can be reduced by removing unused rules and merging similar ones.

**Estimate**: ~2-3 days.

---

### 3.3 Performance Improvements

#### ⚡ 3.3.1 Cache `entries count` in a file

**Status**: 📅 Planned | **Complexity**: 🟢 Easy
`getEntriesCount()` reads the entire `blocklist.txt` to count lines. Save count in `.count` and update on rebuild.

**Estimate**: ~1-2 days.

---

#### ⚡ 3.3.2 Batch SSE broadcasts

**Status**: 📅 Planned | **Complexity**: 🟡 Medium
Buffer SSE events for 100ms and send them in batches to reduce overhead by ~40%.

**Estimate**: ~3-5 days.

---

#### 🆕 ⚡ 3.3.3 Dashboard metrics optimization

**Status**: 📅 Planned (new)
**Complexity**: 🟡 Medium

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

### 3.4 v1.1.0 Summary

| # | Feature | Priority | Complexity | Estimate |
|:-:|---|:---:|:---:|:---:|
| 1 | Remove `'unsafe-inline'` from CSP | 🔴 | 🟡 | 1-2 weeks |
| 2 | Unify WebUI + Dashboard | 🟡 | 🟡 | 2-3 weeks |
| 3 | Improve manifest shortcuts | 🟢 | 🟢 | 1 day |
| 4 | Encrypt credentials file | 🟡 | 🟡 | 3-5 days |
| 5 | Fix `pgrep -x` on Android 5.x | 🟢 | 🟢 | 1 day |
| 6 | Fix `awk` parser | 🟢 | 🟡 | 1-2 days |
| 7 | CSS cleanup | 🟢 | 🟢 | 2-3 days |
| 8 | Caching entries count | 🟡 | 🟢 | 1-2 days |
| 9 | Batch SSE broadcasts | 🟡 | 🟡 | 3-5 days |
| 10 | 🆕 Dashboard metrics optimization | 🟡 | 🟡 | 3-5 days |
| 11 | 🆕 Live Dashboard tests | 🟡 | 🟡 | 3-5 days |

**Estimated time**: ~6-8 weeks.

---

## 4. v1.2.0 — Q1 2027

**Type**: ✨ Feature Release (MINOR).
**Goal**: Advanced features + monitoring.
**Status**: 📅 Planned.

### 4.1 Core Features

#### 🎯 4.1.1 2FA (Two-Factor Authentication)

**Status**: 📅 Planned | **Priority**: 🟡 Medium | **Complexity**: 🔴 High
- TOTP (Time-based One-Time Password).
- QR code for Google Authenticator / Aegis.
- Backup codes.
- **Impact**: +100% security for exposed accounts.
- **Estimate**: ~2-3 weeks.

---

#### 🎯 4.1.2 Detailed Audit Logging

**Status**: 📅 Planned | **Priority**: 🟡 Medium | **Complexity**: 🟡 Medium
Log every action:
- Login (success/failure).
- Rule modification.
- Service start/stop.
- Setting modification.

**Structure**:
```json
{
  "timestamp": "2026-09-24T10:30:00Z",
  "user": "admin_xxx",
  "action": "save_allowlist",
  "result": "success",
  "details": {"entries": 25}
}
```
- **Estimate**: ~1-2 weeks.

---

#### 🎯 4.1.3 Improved Resolver Health UI

**Status**: 📅 Planned
**Priority**: 🟡 Medium
**Complexity**: 🟡 Medium

**Current problem:**
`resolver_health` in Dashboard doesn't display data (needs `enable_query_log`).

**Planned solution:**
- Collect metrics from Prometheus directly.
- Display resolver stats without needing query_log.
- Track each resolver (success_rate, avg_response_ms).

**Estimate**: ~1-2 weeks.

---

#### 🎯 4.1.4 Advanced Filtering Rules Editor

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

#### 🎯 4.1.5 Remote Dashboard over HTTPS

**Status**: 💡 Under study | **Priority**: 🟡 Medium | **Complexity**: 🔴 High
- HTTPS with self-signed certificate.
- Secure LAN access support.
- **⚠️ Complex**: Requires certificate management.
- **Decision**: 📅 Planned.

---

#### 🆕 🎯 4.1.6 JWT Authentication (instead of Cookie)

**Status**: 📅 Planned (new)
**Priority**: 🟢 Low
**Complexity**: 🟡 Medium

**Idea**: Support JWT for API consumers (instead of Cookie only):
- Authorization: Bearer <jwt>
- Configurable expiration.
- Revocation list.

**Estimate**: ~1 week.

---

### 4.2 v1.2.0 Summary

| # | Feature | Priority | Complexity | Estimate |
|:-:|---|:---:|:---:|:---:|
| 1 | 2FA | 🟡 | 🔴 | 2-3 weeks |
| 2 | Audit Logging | 🟡 | 🟡 | 1-2 weeks |
| 3 | Resolver Health UI | 🟡 | 🟡 | 1-2 weeks |
| 4 | Rules Editor | 🟡 | 🟡 | 2-3 weeks |
| 5 | Remote HTTPS | 🟡 | 🔴 | 📅 |
| 6 | 🆕 JWT Authentication | 🟢 | 🟡 | 1 week |

**Estimated time**: ~8-12 weeks.

---

## 5. v1.3.0 — Q2 2027

**Type**: ✨ Feature Release (MINOR).
**Goal**: Broaden application scope.
**Status**: 📅 Planned.

### 5.1 Features

#### 🎯 5.1.1 DoH3 Support (DNS over HTTP/3)

**Status**: 📅 Planned | **Priority**: 🟡 Medium
- QUIC-based DoH.
- Better performance on weak networks.
- Requires dnscrypt-proxy update.

**Estimate**: ~1-2 weeks.

---

#### 🎯 5.1.2 Firewall Configuration UI

**Status**: 📅 Planned | **Priority**: 🟡 Medium
- View Custom Chains from the interface.
- Add/remove rules manually.
- Backup/restore rules.

**Estimate**: ~2-3 weeks.

---

#### 🎯 5.1.3 Multiple User Accounts

**Status**: 📅 Planned | **Priority**: 🟢 Low
- Admin / Viewer / Operator.
- Different permissions.
- **⚠️ Complexity**: Requires full RBAC.

**Estimate**: ~3-4 weeks.

---

#### 🆕 🎯 5.1.4 Extended Multi-Language Support

**Status**: 📅 Planned (new)

**Idea**: Add new translations (FR, DE, ES, RU, ZH, ...).

**Implementation**:
- Update `translations` object in `index.html` + `dashboard.html`.
- Add `docs/*.<lang>.md`.

**Estimate**: ~1-2 weeks (per language).

---

#### 🆕 🎯 5.1.5 Import/Export Settings

**Status**: 📅 Planned (new)
**Priority**: 🟡 Medium

**Idea**: Export/import all settings as JSON.

**Content**:
```json
{
  "version": "v1.3.0",
  "exported_at": "2026-09-24T...",
  "config": {
    "webui.conf": "...",
    "allowlist.txt": "...",
    "denylist.txt": "...",
    "selected_profile.txt": "..."
  }
}
```

**Estimate**: ~1 week.

---

### 5.2 v1.3.0 Summary

| # | Feature | Priority | Estimate |
|:-:|---|:---:|:---:|
| 1 | DoH3 support | 🟡 | 1-2 weeks |
| 2 | Firewall UI | 🟡 | 2-3 weeks |
| 3 | Multiple Users | 🟢 | 3-4 weeks |
| 4 | 🆕 Multi-language | 🟡 | 1-2 weeks/lang |
| 5 | 🆕 Import/Export | 🟡 | 1 week |

**Estimated time**: ~10-14 weeks.

---

## 6. v2.0.0 — 2028

**Type**: 💥 Major Release (MAJOR — Breaking).
**Goal**: Complete rebuild.
**Status**: 💡 Under study.

### 6.1 Goals

| Goal | Description |
|---|---|
| **3× faster** | Improve performance by 200% |
| **Modern interface** | Preact/HTM instead of Vanilla JS |
| **DoQ support** | DNS over QUIC |
| **Docker/Linux** | Full Linux x86_64 support (not just Android) |
| **API v2** | Full REST + OpenAPI |
| **Multi-Node** | Manage several devices from one panel |
| **Plugin System** | Add flexibility for developers |

### 6.2 Planned Breaking Changes

| Current | New | Version |
|---|---|---|
| `/api?action=X` | `/api/v2/*` | v2.0.0 |
| `webui.conf` | `config.yaml` | v2.0.0 |
| `STATUS_FILE` | `state.json` | v2.0.0 |
| `/api/auth/login` (Cookie) | JWT + OAuth2 | v2.0.0 |
| 2 ports (9090 + 9091) | Single unified port | v2.0.0 |
| `web/*.html` (static) | SPA (Preact) | v2.0.0 |

**Reference**: [`UPGRADE.md`](UPGRADE.md) (will be updated)

---

## 7. Under Consideration

### 7.1 Possible Features

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

### 7.2 Ideas Temporarily Rejected

| Idea | Reason |
|---|---|
| **Cloud Sync** | Violates Localhost-First |
| **Remote API** | Violates Localhost-First |
| **Analytics Dashboard** | Zero Telemetry |
| **SaaS Version** | Violates project philosophy |
| **Mobile App (iOS/Android)** | Project is already web-based + PWA |

---

## 8. Permanently Excluded

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

## 9. How to Contribute to Priorities

### 9.1 Ways to Contribute

- 👍 **React to Issues** to confirm the request.
- 💬 **Discussions** for open discussion.
- 🎯 **Feature Request** by opening an Issue using the dedicated template.
- 💪 **Submit a PR** directly for implementation.
- 🗳️ **Vote** on proposed Issues.
- 🆕 **Test ProtoFeatures** on experimental branches (`develop` or `feature/*`).
- 🆕 **Propose an ADR** for architectural decisions (see §10.6).

### 9.2 What Raises a Feature's Priority

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

### 9.3 What Lowers a Feature's Priority

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

### 9.4 🆕 For Contributors

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
  - **Hotfix/PATCH** → PR against `main` (via `hotfix/*`, using `release-patch.sh`).
- Look for Issues labeled `good first issue`.
- Start with a small bug fix.

---

## 10. Development Workflow Priorities

> This section documents the **process priorities** introduced alongside
> `docs/BRANCHING.md`, `docs/RELEASE_PROCESS.md`, and `docs/adr/`.

### 10.1 Why a Workflow Roadmap?

Feature roadmaps describe **what to build**. A workflow roadmap describes
**how to build it safely**. Both are necessary for a healthy project.

### 10.2 Workflow Priorities (Current Status)

| Priority | Item | Status |
|:---:|---|:---:|
| 🔴 | Keep `main` protected (PR + CI + CodeQL required) | ✅ Policy defined in [`docs/BRANCHING.md`](BRANCHING.md) §6 |
| 🔴 | Automate releases via `scripts/release.sh` + `release.yml` | ✅ Implemented ([ADR-0002](adr/0002-automated-releases.md)) |
| 🔴 | Two-branch model (`main` + `develop`) | ✅ Implemented ([ADR-0001](adr/0001-two-branch-model.md)) |
| 🟠 | Auto-sync `main → develop` after each release | ✅ Implemented in `release.yml` ([ADR-0003](adr/0003-post-release-sync.md)) |
| 🟠 | PATCH releases via `scripts/release-patch.sh` | ✅ Implemented ([ADR-0006](adr/0006-rename-hotfix-to-release-patch.md)) |
| 🟠 | Release-specific PR template | ✅ Implemented ([ADR-0005](adr/0005-release-specific-pr-template.md)) |
| 🟠 | Require CI pass on `develop` before opening a `release/*` PR | 📅 Policy defined in `docs/BRANCHING.md` §6 |
| 🟡 | Architecture Decision Records system | ✅ Implemented (`docs/adr/`) |
| 🟡 | Add lightweight `pr-check.yml` for PR validation | 💡 Under consideration |
| 🟢 | Migrate to signed commits (GPG / Sigstore) | 💡 Under consideration |
| 🟢 | Add pre-commit hook for `git commit --amend` protection | 💡 Under consideration |
| 🟢 | Automated changelog generation from Conventional Commits | 💡 Under consideration |

**Summary**:

| Category | Count |
|---|:---:|
| ✅ Implemented | **8** |
| 📅 Policy defined | **1** |
| 💡 Under consideration | **4** |

### 10.3 Workflow Milestones

```text
2026 Q3 ✅ v1.0.0        — initial stable release
2026 Q3 ✅ Workflow v1   — main + develop + release.sh + release-patch.sh + ADRs (current)
2026 Q4 📅 Workflow v1.1 — pr-check.yml + signed commits
2027 Q1 📅 Workflow v1.2 — automated changelog + contributor metrics
2027 Q2 📅 Workflow v1.3 — full CI/CD audit
```

### 10.4 Long-Term Workflow Vision

- **Zero-touch releases**: `git tag` → signed release published.
- **Automated changelog**: generate from Conventional Commits.
- **Release cadence metrics**: track time-from-merge-to-release.
- **Contributor onboarding**: reduce first-PR friction.
- **Post-release telemetry** (opt-in only, aggregate): understand adoption
  without violating the Zero-Telemetry principle.
- **Complete ADR coverage**: every architectural decision documented.

### 10.5 ADRs Index

> Full ADR system documentation: [`docs/adr/README.md`](adr/README.md)

| # | Title | Status |
|:-:|---|:---:|
| [0001](adr/0001-two-branch-model.md) | Two-branch model (`main` + `develop`) | ✅ Accepted |
| [0002](adr/0002-automated-releases.md) | Automated releases via `scripts/release.sh` | ✅ Accepted |
| [0003](adr/0003-post-release-sync.md) | Post-release sync (`main → develop`) | ✅ Accepted |
| [0004](adr/0004-unified-pr-template.md) | Unified PR template | ⚠️ Superseded by ADR-0005 |
| [0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template | ✅ Accepted |
| [0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` | ✅ Accepted |

**Total**: 6 ADRs (5 accepted + 1 superseded).

### 10.6 ADR Process

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

---

## 📊 Timeline Summary

```text
2025 Q4  │ v0.x.x (beta) ✅
2026 Q3  │ v1.0.0 ✅ (current)
2026 Q3  │ Workflow v1 — branch strategy + releases + ADRs ✅ (current)
2026 Q4  │ v1.1.0 📅 (CSP + SW + config + optimize)
2026 Q4  │ Workflow v1.1 📅 (pr-check + signed commits)
2027 Q1  │ v1.2.0 📅 (2FA + Audit Log + Health UI + JWT)
2027 Q2  │ v1.3.0 📅 (DoH3 + Firewall UI + Multi-lang)
2027 Q3  │ Stability + bugfixes
2027 Q4  │ v2.0.0 💥 (Major Rewrite)
2028+    │ 💡 (Multi-Node + API v2 + Plugins)
```

---

## 🎯 Long-Term Vision

**2026 (Q3-Q4)**: Stability + Security.
- Fix all Critical Bugs ✅.
- Zero known critical issues.
- Comprehensive documentation.
- **Two-branch workflow in place** ✅.
- **ADR system established** ✅.

**2027 (Q1-Q2)**: Advanced features.
- 2FA + Audit Log.
- Multi-language.
- DoH3 + Firewall UI.
- JWT Authentication.

**2027 (Q3-Q4)**: Rebuild.
- v2.0.0 Major Release.
- API v2 + OpenAPI.
- Plugin System.

**2028+**: Expansion.
- Multi-Node Management.
- Desktop/Linux Support.
- Docker deployment.

---

## 📚 References

| Document | Purpose |
|---|---|
| [`CHANGELOG.md`](../CHANGELOG.md) | What was delivered |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Trade-offs |
| [`docs/SECURITY.md`](SECURITY.md) | Known Issues + Audit Corrections |
| [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) | How to contribute |
| [`docs/BRANCHING.md`](BRANCHING.md) | Git branching strategy |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Release process guide |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records index |
| [`docs/UPGRADE.md`](UPGRADE.md) | Upgrade guide |
| [`docs/FAQ.md`](FAQ.md) | Frequently asked questions |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | Level 4 infrastructure |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Compatibility matrix |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary |
| [`docs/API.md`](API.md) | HTTP API Reference |
| [`docs/INSTALL.md`](INSTALL.md) | Installation guide |
| [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) | Developer guide |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting guide |

---

*Last updated: 2026-09-24*
*Current version: v1.0.0*
*Author: gasciljh*

---

<div align="center">

**🚀 Our vision**: Secure, free, and local DNS for everyone.

[⬆ Back to top](#roadmap--dnscrypt-smart-filter)

</div>