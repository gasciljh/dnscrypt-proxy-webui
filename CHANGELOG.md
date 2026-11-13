# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Author**: gasciljh
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Last updated**: 2026-11-13

---

## [Unreleased]

_No pending changes._

---

## [v1.6.0] - 2026-11-12

**Architecture & UX release** — full shell modularization into `lib/`, WebUI timezone fix, PWA cache update, DNS version bump, and codebase cleanup.

### Highlights

- **WebUI Timezone Fix** — The WebUI now correctly displays the last update time using the device's local timezone instead of raw UTC. This is achieved by sending a Unix timestamp (`last_update_unix`) from the backend and formatting it via `toLocaleString` in the frontend.
- **Architectural Refactor (Layered Bootstrap 3-Layer)** — Fully extracted shell libraries into a dedicated `lib/` directory at the module root (Layer 0). `boot-mini.sh` became a Layer 1 aggregator, and `functions.sh` became Layer 2.
- **PWA Cache Update** — Bumped the Service Worker `CACHE_VERSION` to `v1.6.0` to ensure existing clients seamlessly receive the new UI and timezone fixes without manual cache clearing.
- **DNS Version Bump** — `proxy/dnscrypt-proxy.version` bumped from `2.1.18` to `2.1.20` to ship the latest upstream engine.
- **Codebase Cleanup** — Removed excessive comments across all files and standardized code headers for a more professional and maintainable codebase.

### Added

**Architecture (lib/)**
- `lib/constants.sh`: Single source of truth for fixed paths, reserved ports, and TOML parsers.
- `lib/fallbacks.sh`: Standalone primitives for early boot or degraded environments.
- `lib/process.sh`: Portable process management via `/proc` (no reliance on `pgrep`/`pkill`).
- `lib/http.sh`: Unified HTTP client (curl/wget cascade) with proxy isolation.
- `lib/backup.sh`: User-data preservation, transaction management, and snapshot rotation.
- `lib/firewall.sh`: nftables/iptables management for DNS redirection.

### Changed

**Backend (`main.go`)**
- `buildProfileResponse` now includes `last_update_unix`.
- `updateProfileBody` and `buildBackupInfo` use RFC3339 UTC for string fallbacks and Unix timestamps for local rendering.
- Preserved the 5-second `TTL Cache` (`LAST_UPDATE_CACHE_TTL`) for `last_update` to prevent unnecessary disk I/O.

**Frontend (`index.html` & `dashboard.html`)**
- `index.html` uses a new `formatUnixTimestamp()` helper to display local device time.
- Version bumped across all UI elements to `v1.6.0`.

**Shell Scripts**
- All scripts (`customize.sh`, `service.sh`, `watchdog.sh`, etc.) now rely on the `lib/` directory for their dependencies.
- `customize.sh` now validates the presence of all 6 `lib/*.sh` modules before completing installation.
- `customize.sh` credential rewrite is now section-aware (only modifies `[monitoring_ui]`).
- Version arithmetic in `customize.sh` is now safe for prerelease suffixes (e.g., `-beta`).
- Updated `Makefile` and CI configurations to validate the `lib/` modules.

### Fixed

- Fixed an issue where the WebUI displayed `YYYY-MM-DD HH:MM:SS` in UTC, causing confusion for users in different timezones.
- Fixed a potential silent failure during install when `lib/*.sh` files were missing from the ZIP.
- Synchronized `BuildVersion` in `main.go` with the module version `v1.6.0`.

### Security

- **No new audit corrections.** The Audit Corrections Registry remains at **#33**.
- The modular `lib/` architecture improves security by isolating functions and ensuring that critical paths (like firewall and backup cleanup) are strictly controlled.

### Breaking Changes

**None.** All v1.5.0 configurations and data structures remain fully compatible.

---

## [v1.5.0] - 2026-10-19

**Feature release** — companion app one-tap root install, twelve frontend state fixes, nine server-side code-review corrections, four post-build bug fixes, and **thirteen post-audit fixes** from the pre-release code review.

### Added

**Companion App Install**
- `install_app.sh`: 5-level `pm install` cascade with a 75-second deadline and three-way trap split (EXIT/INT/TERM).
- 4 new HTTP endpoints: `install_companion_app`, `uninstall_companion_app`, `install_token`, `companion_app_state`.
- One-shot CSRF token (60s TTL) and per-IP install rate limit (5 attempts / 15 min).
- SELinux staging to `/data/local/tmp/` (never `setenforce 0`).
- Play Protect temporary disable with trap restoration (`$_VERIFIER_ORIG`).
- APK mirror (`apk/`) to `/sdcard/dnscrypt-webui-backup/apk/`.

**Architecture (Layered Bootstrap 2-Layer)**
- Extracted 5 primitives and `_MONITORING_UI_PORT` into `boot-mini.sh` (Layer 0).
- `functions.sh` became Layer 1, sourcing `boot-mini.sh`.
- Added `filepath-securejoin v0.7.0` as the sole external Go dependency (ADR-0002).

### Changed

**Frontend (`index.html`)**
- Replaced the direct `<a download>` install link with an install-method modal (IDX-24).
- 12 state fixes for session expiry, install family 401s, and modal interactions.

**Backend (`main.go`)**
- Logger three-layer split (`logWithLevel` / `logLocked` / `writeLocked`) to eliminate reentrancy deadlock.
- Added 30-second TTL cache for ports (`getWebUIPort` / `getDashboardPort`).
- IPv6-safe loopback detection using `net.IP.IsLoopback()`.

### Fixed

- Fixed 4 post-build bugs (CSH-22, MAIN-REENT-01, MAIN-PORTCACHE-01, MAIN-DEADLOCALHOST-01).
- Fixed `append_denylist` using a mismatched hash source.
- 9 backend code-review corrections (V15-CODE-01..04, etc.).

### Security

- **No new audit corrections.** The Audit Corrections Registry remains at **#33**.
- Added localhost gate to all three install surfaces.
- Added constant-time comparison for install tokens.

---

## Notes

### Audit Corrections Registry

The full registry — with descriptions, categories, and per-entry analysis — lives in **`SECURITY.md` §15**.

- **33 total corrections** filed against the v1.0.0 tree.
- **No new corrections** in v1.6.0 or v1.5.0. These releases focused on architecture, UX, and feature additions.

### Links

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)

[Unreleased]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.6.0...HEAD
[v1.6.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.5.0...v1.6.0
[v1.5.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.4.0...v1.5.0
[v1.4.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.3.0...v1.4.0
[v1.3.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.2.0...v1.3.0
[v1.2.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.1.0...v1.2.0
[v1.1.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.0.0...v1.1.0
[v1.0.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/releases/tag/v1.0.0