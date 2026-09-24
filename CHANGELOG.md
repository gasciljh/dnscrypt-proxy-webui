# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Author**: gasciljh
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui

---

## [Unreleased]

### 📖 Dev Workflow Infrastructure (post-v1.0.0)

> This section documents the **development workflow** additions made after
> `v1.0.0`. These are **process/tooling improvements** — no changes to the
> runtime behavior of the module itself.

#### Added

##### Branching & Release Documentation

- **`docs/BRANCHING.md`** — Complete Git branching strategy guide.
  - Two-branch model: `main` (stable releases) + `develop` (integration).
  - Short-lived branch conventions: `feature/*`, `fix/*`, `docs/*`,
    `chore/*`, `refactor/*`, `test/*`, `release/*`, `hotfix/*`.
  - Naming rules, workflows, PR rules, and protection policy.
  - Hotfix flow with back-merge requirement.
  - 10 sections, ~28 KB.

- **`docs/RELEASE_PROCESS.md`** — Complete release process guide.
  - Release types: Stable, Prerelease, Hotfix.
  - Version bumping (SemVer + `versionCode` formula).
  - `scripts/release.sh` usage (5 modes).
  - GitHub Actions pipeline (11 steps) explained in detail.
  - Post-release verification (Cosign, SBOM, SHA-256, PIE check).
  - Rollback procedures and emergency actions.
  - 12 sections, ~30 KB.

##### Release Scripts

- **`scripts/release.sh`** — Local release automation script.
  - Validates SemVer format (`vMAJOR.MINOR.PATCH[-prerelease]`).
  - Computes `versionCode` from the SemVer formula.
  - Checks branch (`develop` or `release/*`), working tree, and tag availability.
  - Updates `VERSION`, `module.prop`, and `update.json` atomically.
  - Creates a `release: vX.Y.Z` commit + signed tag.
  - Pushes to `origin` (unless `--no-push`).
  - Modes: `--dry-run`, `--no-push`, `--yes`, `--help`.
  - Rollback on failure (trap + atomic writes).

- **`scripts/release-patch.sh`** — Local PATCH-release automation script.
  - Wraps `scripts/release.sh` with **3 additional safety rules**:
    1. Branch **must** be `main` (not `develop`).
    2. `MAJOR` and `MINOR` components **must not** change.
    3. `PATCH` **must** be exactly `current + 1`.
  - Rejects MAJOR/MINOR bumps — those use `release.sh`.
  - Delegates the actual bump to `release.sh` (no logic duplication).
  - Reminds the maintainer to back-merge `main → develop`.
  - Modes: `--dry-run`, `--no-push`, `--yes`, `--help`.

##### Architecture Decision Records (ADRs)

- **`docs/adr/README.md`** — ADR index, template, and methodology.
  - Explains the ADR lifecycle (Proposed / Accepted / Deprecated / Superseded).
  - Provides a canonical ADR template for future decisions.
  - Documents the relationship between ADRs and `CHANGELOG.md`.
  - 10 sections, ~15 KB.

- **`docs/adr/0001-two-branch-model.md`** — Adopts `main` + `develop`.
- **`docs/adr/0002-automated-releases.md`** — Adopts `release.sh` + `release.yml`.
- **`docs/adr/0003-post-release-sync.md`** — Auto-syncs `main → develop`.
- **`docs/adr/0004-unified-pr-template.md`** — Single PR template (⚠️ Superseded).
- **`docs/adr/0005-release-specific-pr-template.md`** — Release PR template (reverses ADR-0004).
- **`docs/adr/0006-rename-hotfix-to-release-patch.md`** — Renames the PATCH script.

##### Contributor Templates

- **`.github/PULL_REQUEST_TEMPLATE/release.md`** — Dedicated PR template for
  releases (`release/*` → `main` and `hotfix/*` → `main`).
  - Concise (< 100 lines of content).
  - Version-first layout (`version` + `versionCode` at the top).
  - Post-merge checklist (tag push, `release.yml` trigger, back-merge).
  - Rollback plan section.
  - Reviewer checklist tailored to releases.
  - Opened via `?template=release.md` (see `docs/BRANCHING.md` §4.4).

#### Changed

- **`.github/workflows/ci.yml`** — Added `develop` to `push.branches`
  and `pull_request.branches`.
  - CI now runs on PRs targeting `develop`, not just `main`.

- **`.github/workflows/codeql.yml`** — Added `develop` to `push.branches`
  and `pull_request.branches`.
  - SAST scanning now runs on `develop` to catch security issues
    before they reach `main`.

- **`.github/workflows/release.yml`** — Added **"Sync main → develop"** step.
  - After a successful release, GitHub Actions automatically fast-forwards
    (or merges) `main` into `develop`.
  - Uses `continue-on-error: true` — the sync failure never blocks a release.
  - Only runs on tag pushes (`github.event_name == 'push'`).

- **`.github/PULL_REQUEST_TEMPLATE.md`** — Added `🎯 Target Branch` section.
  - Explains `develop` (default) vs `main` (releases/hotfixes only).
  - Added a "Branch policy" block to the Final Checklist.
  - Added a reminder box at the bottom of the template.

- **`.github/CODEOWNERS`** — Extended file ownership patterns.
  - Added `/docs/BRANCHING.md`, `/docs/RELEASE_PROCESS.md`, `/scripts/release.sh`.
  - Added `/docs/adr/` (all ADRs).
  - Added `/scripts/release-patch.sh`.
  - Added `/.github/PULL_REQUEST_TEMPLATE/` (release template).
  - Added repo hygiene files.
  - Added missing `.github/` files.
  - Added missing root files.
  - Clarified that CODEOWNERS works on file paths, not branches.

- **`Makefile`** — Added release-oriented targets.
  - `make release VERSION=vX.Y.Z` — prepare a stable release.
  - `make release-patch VERSION=vX.Y.Z` — prepare a PATCH release (from `main`).
  - `make sync` — sync `develop` with `main` after a PATCH release.
  - Guards: `$(origin VERSION)` check prevents accidental no-op releases.
  - **Renamed target** `hotfix:` → `release-patch:` (see ADR-0006).
  - Help text updated with new targets.

- **`README.md`** — Added CI badge and Dev Workflow references.
  - Added CI status badge.
  - Added `Branching & Release` callout box.
  - Updated `Project Structure` (docs: 14 → 16 files, added `scripts/release.sh`).
  - Updated `Development` section with `git checkout develop`.
  - Added new `Releasing` section.
  - Extended `Documentation` table with `BRANCHING.md` + `RELEASE_PROCESS.md`.

- **`.gitattributes`** — Added merge strategies for workflow files.
  - `CHANGELOG.md` → `merge=union` (prevents conflicts on concurrent updates).
  - `VERSION` → `merge=union` (prevents conflicts during version bumps).

- **`docs/CONTRIBUTING.md`** — Updated to reference the new workflow docs.
  - Added `Branching & Release` callout at the top.
  - Section 4 (`Branch Strategy`) now delegates to `docs/BRANCHING.md`.
  - Section 6 (`Pull Request Process`) explains base branch selection.
  - Section 10 (`Release Process`) now delegates to `docs/RELEASE_PROCESS.md`.
  - Section 13 (`Contributors Reference`) added Golden Rule #18
    (open PRs against `develop`).

- **`docs/DEVELOPMENT.md`** — Updated to reflect the new workflow.
  - Added `Branching & Release` callout at the top.
  - Section 2 (`Environment Setup`) — added `git checkout develop` step.
  - Section 4 (`Project Structure`) — updated `docs/` to 16 files.
  - Section 5 (`Daily Workflow`) — all steps now branch from `develop`.
  - Section 6 (`Release`) — summarized and delegated to `docs/RELEASE_PROCESS.md`.
  - Section 7 (`CI/CD`) — updated triggers to include `develop`.
  - Section 10 (`Contributor Notes`) — added `Branch Policy Reminder` and
    Golden Rule #18.

- **`docs/ROADMAP.md`** — Updated workflow priorities.
  - Section 2.6 (`Statistics`) — updated counts (`docs: 23`, `scripts: 5`, `ADRs: 6`).
  - Section 2.7 (`Features Added`) — added 5 ADR-related entries.
  - Section 2.8 (`Lessons Learned`) — added lessons about ADRs and naming.
  - Section 10 (`Development Workflow Priorities`) — updated statuses:
    * `release-patch.sh` now marked **Implemented**.
    * Release-specific PR template now marked **Implemented**.
    * Added `ADRs Index` (§10.5).
    * Added `ADR Process` (§10.6).

#### Notes

- **No runtime code was modified.** These changes are strictly about the
  development workflow, CI/CD configuration, and documentation.
- **`v1.0.0` runtime behavior is unchanged.** Users on `v1.0.0` do not need
  to take any action.
- **The `develop` branch will be created** alongside these changes.
- **Branch Protection Rules** (for `main` and `develop`) must be configured
  manually in the repository settings — see `docs/BRANCHING.md` §6.
- **ADRs supersede, they do not delete.** ADR-0004 remains in the repository
  marked as `Superseded by ADR-0005`. History is preserved.

#### Reversed Decisions

The following decisions were made and then **explicitly reversed** during
the `[Unreleased]` cycle. Each reversal is documented via an ADR:

| Original Decision | Reversal | Documentation |
|---|---|---|
| ADR-0004: Unified PR template only | ADR-0005: Add release-specific template | [ADR-0004](docs/adr/0004-unified-pr-template.md) → [ADR-0005](docs/adr/0005-release-specific-pr-template.md) |
| Initial draft: `scripts/hotfix.sh` | ADR-0006: Rename to `release-patch.sh` | [ADR-0006](docs/adr/0006-rename-hotfix-to-release-patch.md) |

**Why reversals are documented:** The ADR system is designed to preserve
history. Reversals are not hidden — they are traceable, reasoned, and
linked. See `docs/adr/README.md` §4 (ADR Lifecycle) for the full methodology.

#### Not Included

The following items were considered and intentionally **not** added:

- **`.github/workflows/sync-main-to-develop.yml`** — the sync logic is
  embedded directly in `release.yml` to keep the workflow count minimal.
  See [ADR-0003](docs/adr/0003-post-release-sync.md).
- **`.github/workflows/pr-check.yml`** — `ci.yml` already covers PR builds
  for both `main` and `develop`. Under consideration for v1.1.0 (see
  `docs/ROADMAP.md` §10.2).
- **Signed commits (GPG / Sigstore)** — planned for a future workflow
  version (see `docs/ROADMAP.md` §10.3).
- **Automated changelog from Conventional Commits** — planned for a future
  workflow version (see `docs/ROADMAP.md` §10.3).

---

## [v1.0.0] - 2026-09-24

> **First Stable Release** — Initial public release of DNSCrypt Smart Filter.
>
> This is the first production-ready release of the project. It consolidates
> the entire development effort into a single stable version, including
> **33 Audit Corrections**, **20 fixes**, and complete Level 4 infrastructure
> for DNS binaries management.

### 📊 Overview

| Metric | Value |
|--------|:-----:|
| Total Audit Corrections | **33** |
| Total fixes | **20** |
| Supported architectures | **4** (arm64, arm, amd64, 386) |
| Documentation files | **14** (in `docs/`) |
| Shell scripts | **8** (in `proxy/`) |
| Build scripts | **3** (in `scripts/`) |
| Web/PWA files | **13** (in `web/`) |

### ✨ Highlights

#### Security

- Login POST-only (CSRF protection)
- `/readyz` localhost-only
- `shellQuote()` Shell injection protection
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
- SSE live updates (status, stats, resources, progress)
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
- Multi-architecture support

#### Documentation

- 14 documentation files in `docs/`
- Bilingual README (EN + AR)
- Full threat model in `docs/SECURITY.md`
- Comprehensive FAQ
- Comprehensive troubleshooting guide
- Audit Corrections Registry (#1 → #33)
- Installation, upgrade, and development guides

### Added

#### Backend (Go)

- **HTTP API** — full REST API for WebUI and Dashboard.
- **`/healthz`** — public liveness endpoint.
- **`/readyz`** — localhost-only readiness endpoint.
- **`/api/metrics`** — JSON metrics proxy (Prometheus → JSON).
- **`/events`** — SSE stream for live updates.
- **`runtime_info`** endpoint — build info + actual ports (PORT-2).
- **`hasEndpoint()`** — exact path matching (no loose `strings.Contains`).
- **`getSystemShell()`** — platform-agnostic shell detection (`sync.Once`).
- **`shellQuote()`** — shell injection protection for dynamic paths.
- **`readConfPort()`** — port range check `[1, 65535]`.
- **`rebuildMu`** — `sync.Mutex` serializing `rebuildBlocklist` (RACE-1).
- **Auth cache (60 s)** — reduces file I/O on every request.
- **Per-port cache** — `portCacheMap` supports multiple ports independently.
- **Session GC** — periodic cleanup (every 30 min).
- **SSE Write Deadline (30 s)** — DoS protection against slow clients.

#### Frontend (PWA)

- **Bilingual WebUI** (English + Arabic) with full RTL support.
- **Monitoring Dashboard** with JSON metrics.
- **Service Worker** (`sw.js`) with cache versioning.
- **Offline fallback page** (`offline.html`).
- **PWA manifest** with shortcuts, icons, and meta notes.
- **SVG + PNG + ICO icons** for all browsers and platforms.
- **Edit mode FSM** — VIEW / EDIT / ROLLBACK states for rules editor.
- **Draft auto-save** — localStorage-backed, 1-hour retention.
- **Content-hash conflict detection** — 409 responses handled gracefully.
- **Dynamic port links** — reads `runtime_info`, uses `window.location.hostname`.

#### Shell Scripts

- **`customize.sh`** — installer with backup/restore of 5 user config files.
- **`service.sh`** — boot service with standalone Watchdog launcher.
- **`post-fs-data.sh`** — early boot cleanup with Custom Chain cleanup.
- **`watchdog.sh`** — standalone process with exponential backoff.
- **`action.sh`** — Magisk Action handler (browser opener with fallbacks).
- **`status.sh`** — status display with 4 modes (default, `--short`, `--json`, `--check`).
- **`uninstall.sh`** — cleanup with backup preservation.
- **`functions.sh`** — shared library with Custom Chains + Port Guard.
- **`build.sh`** — cross-compilation for 4 architectures with reproducible builds.

#### Build & Packaging

- **`scripts/fetch_dns_binaries.sh`** — Level 4 DNS binaries fetcher with:
  - GitHub API + 4 fallback URL formats + jsDelivr CDN.
  - SHA256 verification.
  - Local cache + `.manifest.json`.
  - Offline mode (`--offline`).
  - JSON output (`--json`).
  - Retry logic (3 attempts).
- **`scripts/package_module.sh`** — builds the Magisk ZIP with:
  - 32-file verification.
  - Web asset verification (PNG + ICO + SVG + offline.html).
  - i386 ↔ x86 mapping for `customize.sh`.
  - Reproducible timestamps.
- **`scripts/generate-icons.sh`** — generates PNG + ICO from SVG.

#### CI/CD

- **`.github/workflows/ci.yml`** — build matrix for 4 architectures.
- **`.github/workflows/release.yml`** — signed release with 6 artifacts.
- **`.github/workflows/codeql.yml`** — SAST with `security-extended` queries.
- **`.github/dependabot.yml`** — weekly updates for Actions, monthly for Go.
- **`.pre-commit-config.yaml`** — 15 hook configurations.

#### Documentation

- 14 comprehensive documentation files in `docs/`.
- Root `README.md` with full project overview.
- Root `SECURITY.md` — summary policy.
- Root `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1.
- Root `LICENSE` — MIT License.
- Root `CHANGELOG.md` — this file.

### Security

**Authentication and authorization**

- **Login POST-only** (`/api/auth/login`) — Fix NEW-1 (Audit #28).
- **Logout POST-only** (`/api/auth/logout`) — Fix NEW-1 (Audit #28).
- **Basic Auth rate limiting** — 5 attempts / 15 min — Fix #8 (Audit #22).
- **Constant-time comparison** — `subtle.ConstantTimeCompare` on all credentials.
- **Cookie-only sessions** — no token in JSON responses — Audit #15-a.
- **SameSite=Lax + HttpOnly + Secure (conditional)** — cookie flags.
- **Session GC** — periodic cleanup of expired sessions.
- **Auth cache (60 s)** — Fix NEW-6 — reduces file I/O on every request.

**Input validation and sanitization**

- **`hasEndpoint()`** — exact path matching — Fix #12 + NEW-2 (Audit #24).
- **`readConfPort()`** — range check `[1, 65535]` — Fix NEW-3 (Audit #29).
- **`shellQuote()`** — shell injection protection — Fix NEW-5 (Audit #31).
- **`MaxBytesReader`** — 5 MB limit on all POST bodies.
- **`limitedBuffer`** — bounded stderr capture (2048 bytes).
- **Path whitelist** — `isAllowedLogFile` + `filepath.Clean`.
- **Atomic writes** — `atomicWriteFile` + `atomicWriteStream` with `fsync`.

**Network and firewall**

- **Custom Chains** — `DNSCRYPT_OUT` / `DNSCRYPT_OUT6` — Fix (Audit #17).
- **Port Guard 8080** — reserved for `monitoring_ui` — Fix (Audit #20).
- **IPv4/IPv6 separation** — no cross-protocol contamination — Audit #16.
- **`/readyz` localhost-only** — Fix NEW-4 (Audit #30).
- **BIND_ADDR enforcement** — refuses to start if exposed without credentials.
- **IPv6-safe `getClientIP()`** — `net.SplitHostPort` instead of `strings.Split` — Audit #19.

**State and concurrency**

- **STATUS_FILE = User Intent** — Audit #18.
- **`rebuildMu` mutex** — serializes `rebuildBlocklist` — RACE-1 (Audit #32).
- **Section-restricted TOML parsing** — Audit #21.
- **Section header with comment** — Audit #23.
- **Preserve settings on upgrade** — backup/restore of 5 files — Audit #26.

**HTTP security headers**

- **CSP** (Content-Security-Policy) with strict directives.
- **X-Content-Type-Options: nosniff**.
- **X-Frame-Options: DENY**.
- **Referrer-Policy: no-referrer**.
- **Permissions-Policy** — disables geolocation, microphone, camera, payment.
- **Cross-Origin-Opener-Policy: same-origin**.
- **Cross-Origin-Resource-Policy: same-origin**.

**Rate limiting**

- **Login** — 5 attempts / 15 min per IP.
- **Basic Auth** — 5 attempts / 15 min per IP.
- **IPv6-safe** — `[::1]` handled correctly.
- **Automatic reset** — successful login resets the counter.

**Stability**

- **SSE Write Deadline (30 s)** — prevents slow-client DoS.
- **Panic recovery** — `handleAPI` recovers from panics.
- **`os.Exit(1)` on startup failures** — no silent failures.

### Architecture

- **Custom iptables chains** (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`) — no orphans.
- **nftables support** — via `dnscrypt_filter` table.
- **Legacy cleanup** — `_legacy_cleanup_*` for migration from older shells.
- **Watchdog as standalone process** — correct PID (`$$` in own file).
- **Streaming blocklist rebuild** — ~2 MB peak memory instead of ~150 MB.
- **Auth cache** — 60 s TTL, `sync.RWMutex` protected.
- **Per-port cache** — `portCacheMap` with independent entries.
- **Platform-agnostic shell** — `getSystemShell()` works on Android/Linux/macOS.
- **Structured metrics** — Prometheus → JSON via `parsePrometheus` + `buildDashboardJSON`.
- **Dynamic ports** — `runtime_info` returns `webui_port` + `dashboard_port`.

### Fixed

| # | Fix | File(s) |
|:-:|-----|---------|
| 1 | Dashboard JSON conversion (Prometheus → JSON) | `proxy/main.go` |
| 2 | Shell fallback for Linux/macOS (`getSystemShell`) | `proxy/main.go` |
| 3 | Preserve user settings on upgrade | `proxy/customize.sh` |
| 4 | `.gitignore` negation for `proxy/run/*` | `.gitignore` |
| 5 | Pre-commit hooks (`golangci-lint` v2) | `.pre-commit-config.yaml` |
| 6 | Asset serving (13 web files) | `proxy/main.go` + `scripts/package_module.sh` |
| 7 | CodeQL config drift | `.github/workflows/codeql.yml` |
| 8 | Basic Auth rate limit bypass | `proxy/main.go` |
| 9 | `fuser` PID parsing (merged PIDs) | `proxy/functions.sh` |
| 10 | Section header with comment | 4 files |
| 11 | Per-port cache (not time-keyed) | `proxy/main.go` |
| 12 | Exact endpoint matching | `proxy/main.go` |
| **NEW-1** | **Login POST-only (CSRF)** | `proxy/main.go` |
| **NEW-2** | **`hasEndpoint` usage** | `proxy/main.go` |
| **NEW-3** | **`readConfPort` range check** | `proxy/main.go` |
| **NEW-4** | **`/readyz` localhost-only** | `proxy/main.go` |
| **NEW-5** | **`shellQuote` injection protection** | `proxy/main.go` |
| **NEW-6** | **Auth cache (60 s)** | `proxy/main.go` |
| **RACE-1** | **`rebuildMu` mutex** | `proxy/main.go` |
| **PORT-2** | **`runtime_info` dynamic ports** | `proxy/main.go` + 3 HTML files |

**Total**: 20 fixes.

### Performance

| Metric | Value |
|--------|:-----:|
| RAM (idle WebUI) | ~15 MB |
| RAM (peak during rebuild) | ~25 MB |
| Battery drain | ~1–2% / day |
| DNS latency (cached) | ~1–5 ms |
| Service startup | ~2–5 s |
| `rebuildBlocklist` (100K) | ~200 ms |
| `rebuildBlocklist` (500K) | ~1 s |
| `parsePrometheus` (10 metrics) | ~50 µs |
| `hasEndpoint` (exact match) | <100 ns |
| `getSystemShell` (cached) | <10 ns |
| `getMonitoringAuth` (cached) | ~50 ns |

### Known Issues

| Issue | Priority | Target |
|-------|:--------:|:------:|
| CSP `'unsafe-inline'` in `script-src` | 🟡 Medium | v1.1.0 |
| `pgrep -x` may not work on Android 5.x | 🟢 Low | v1.1.0 |
| `awk` parser may fail with `]` in comment | 🟢 Low | v1.1.0 |
| PWA dual-origin limitation (9090 vs 9091) | 🟡 Medium | v1.1.0 (unified) |
| `manifest.json` shortcuts do not read `runtime_info` | 🟢 Low | v1.1.0 |
| Dashboard does not show `bind_addr` (only in `runtime_info`) | 🟢 Low | v1.1.0 |

### Notes

#### First Release

This is the **first public release** of DNSCrypt Smart Filter. There are no previous versions. All features, security fixes, and infrastructure were developed and consolidated into this single stable `v1.0.0` release.

#### Audit Corrections

All 33 Audit Corrections are documented in [`docs/SECURITY.md`](docs/SECURITY.md) with full details:
- Problem description
- Catastrophic scenario
- Impact analysis
- Solution applied
- Reference to the corresponding section

See §17 — Audit Corrections Registry for the complete list.

#### Repository Layout

```text
dnscrypt-proxy-webui/
├── VERSION                        # v1.0.0
├── module.prop                    # Magisk definition
├── update.json                    # Auto-update metadata
├── README.md / SECURITY.md / CHANGELOG.md
├── CODE_OF_CONDUCT.md / LICENSE / Makefile
│
├── .github/                       # CI/CD + templates
├── .devcontainer/                 # Dev environment
├── scripts/                       # Build & release tools
├── proxy/                         # Go backend + shell scripts
├── web/                           # Frontend (PWA)
└── docs/                          # 14 documentation files
```

#### Verification

To verify the release on a device:

```bash
# Version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.0.0

su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: versionCode=1000000

# Dashboard JSON (Fix #1)
curl -s -I http://127.0.0.1:9091/api/metrics | grep Content-Type
# Expected: application/json; charset=utf-8

# Login POST-only (NEW-1)
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: 405 Method Not Allowed

# Runtime info ports (PORT-2)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# No orphans in iptables
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# Expected: 0
```

### Credits

- **gasciljh** — Full development, testing, and auditing.
- **Anthropic Claude** — Code review and architectural audit assistance.
- **DNSCrypt Community** — For `dnscrypt-proxy`.
- **HaGeZi** — For the DNS blocklists.
- **Magisk / KernelSU / APatch teams** — For the module framework.

### References

- [README.md](README.md) — Project overview
- [SECURITY.md](SECURITY.md) — Security policy (summary)
- [docs/SECURITY.md](docs/SECURITY.md) — Full policy + Audit Corrections Registry
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Architecture + Trade-offs
- [docs/API.md](docs/API.md) — HTTP API Reference
- [docs/INSTALL.md](docs/INSTALL.md) — Installation guide
- [docs/UPGRADE.md](docs/UPGRADE.md) — Upgrade guide
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) — Compatibility matrix
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — Troubleshooting guide
- [docs/FAQ.md](docs/FAQ.md) — Frequently asked questions
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — Developer guide
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — Contribution guide
- [docs/DNS_BINARIES.md](docs/DNS_BINARIES.md) — DNS binaries management
- [docs/GLOSSARY.md](docs/GLOSSARY.md) — Glossary
- [docs/HALL_OF_FAME.md](docs/HALL_OF_FAME.md) — Contributors recognition
- [docs/ROADMAP.md](docs/ROADMAP.md) — Future plans

---

## 📖 Legend — Audit Corrections

The complete list of 33 Audit Corrections applied in v1.0.0:

| # | Description | Reference |
|:-:|---|---|
| #1 | Fixed typo in `isAllowedLogFile` | — |
| #3-e/f | Dynamic `bootstrap_resolvers` + IPv6 | docs/SECURITY.md#59 |
| #5 | Cleanup of old `loginAttempts` | — |
| #6-c | `limitedBuffer` (bounded stderr capture) | — |
| #7 | Dead code removal from `functions.sh` | — |
| #9/#9-b | `os.CreateTemp` (no race) | — |
| #10 | Debounce SSE | — |
| #13 | CSRF-GET → POST-only | docs/SECURITY.md#52 |
| #14 | `pgrep -x` (no false positives) | — |
| #15-a | Remove token from login response | docs/SECURITY.md#511 |
| #15-b | `Allow: POST` header for 405 | docs/SECURITY.md#512 |
| #16-a/b | IPv4/IPv6 firewall separation | docs/SECURITY.md#59 |
| #17 | Custom Chains (Orphan Fix) | docs/SECURITY.md#513 |
| #18 | STATUS_FILE Semantics | docs/SECURITY.md#514 |
| #19 | IPv6 Rate Limit Bypass | docs/SECURITY.md#515 |
| #20 | Port Collision 8080 | docs/SECURITY.md#516 |
| #21 | Section-Restricted TOML | docs/SECURITY.md#517 |
| #22 | Basic Auth Rate Limit Bypass | docs/SECURITY.md#518 |
| #23 | Section header with comment (parsing) | docs/SECURITY.md#519 |
| #24 | Exact endpoint matching | docs/SECURITY.md#520 |
| #25 | Dashboard JSON Conversion | docs/SECURITY.md#520 |
| #26 | Preserve User Settings on Upgrade | docs/SECURITY.md#521 |
| #27 | `fuser` PID parsing | docs/SECURITY.md#522 |
| #28 | Login POST-only (CSRF) | docs/SECURITY.md#523 |
| #29 | `readConfPort` range check | docs/SECURITY.md#524 |
| #30 | `/readyz` localhost-only | docs/SECURITY.md#525 |
| #31 | `shellQuote` injection protection | docs/SECURITY.md#526 |
| #32 | `rebuildMu` mutex (RACE-1) | docs/SECURITY.md#528 |
| #33 | `runtime_info` dynamic ports (PORT-2) | docs/SECURITY.md#529 |

**Total**: 33 Audit Corrections.

**Next expected**: #34 (v1.1.x)

---

## 🔗 Links

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)

---

[Unreleased]: https://github.com/gasciljh/dnscrypt-proxy-webui/compare/v1.0.0...HEAD
[v1.0.0]: https://github.com/gasciljh/dnscrypt-proxy-webui/releases/tag/v1.0.0