# DNSCrypt Smart Filter

System-wide DNS filtering for Android devices, built on DNSCrypt and dnscrypt-proxy.

[![CI](https://github.com/gasciljh/dnscrypt-proxy-webui/actions/workflows/ci.yml/badge.svg)](https://github.com/gasciljh/dnscrypt-proxy-webui/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)](https://github.com/gasciljh/dnscrypt-proxy-webui/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%205%2B-brightgreen.svg)](https://www.android.com/)
[![Magisk](https://img.shields.io/badge/Magisk-20.4%2B-orange.svg)](https://github.com/topjohnwu/Magisk)
[![KernelSU](https://img.shields.io/badge/KernelSU-supported-purple.svg)](https://kernelsu.org/)
[![Go](https://img.shields.io/badge/Go-1.22-00ADD8.svg)](https://go.dev/)

> **📖 Project documentation**:
> - Git workflow → [`docs/BRANCHING.md`](docs/BRANCHING.md)
> - Release process → [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md)
> - Architecture Decisions → [`docs/adr/README.md`](docs/adr/README.md)

---

## Overview

DNSCrypt Smart Filter is a Magisk / KernelSU / APatch module that turns an Android device into a filtered, encrypted DNS resolver.

- Local DNS engine on `127.0.0.1:5354` (DNSCrypt / DoH)
- Transparent redirection of port 53 traffic to the local engine
- Multi-level blocklists (HaGeZi Light → Ultimate)
- Allowlist / Denylist with a browser editor
- Bilingual WebUI (English / Arabic)
- Separate monitoring Dashboard with JSON metrics
- Installable PWA with offline fallback

Works at the system level — no per-app configuration, no VPN.

---

## Requirements

- Android 5.0+ (API 21)
- Root: Magisk 20.4+ / KernelSU 0.9+ / APatch
- Kernel 3.10+
- 1 GB RAM (2 GB recommended)
- ~20 MB free storage
- Architectures: `arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`

Incompatible with:

- AdAway (port conflict)
- VPN apps (routing conflict)
- SuperSU (legacy)

---

## Installation

1. Download `dnscrypt-webui-1.0.0-module.zip` from [Releases](https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest).
2. Install via Magisk Manager / KernelSU Manager / APatch.
3. Save the credentials shown on-screen (also stored at `/data/local/tmp/dnscrypt_credentials.txt`).
4. Reboot.
5. Open `http://127.0.0.1:9090` and log in.
6. Select a blocklist profile and press **Apply**.

User settings are preserved across upgrades. The installer backs up the following files before extraction and restores them afterwards:

- `webui.conf`
- `dnscrypt-proxy.toml`
- `selected_profile.txt`
- `allowlist.txt`
- `denylist.txt`

---

## Ports

| Port | Service | Configurable |
|:----:|---|---|
| 9090 | WebUI | `webui.conf` → `PORT` |
| 9091 | Dashboard | `webui.conf` → `DASHBOARD_PORT` |
| 8080 | monitoring_ui (internal) | fixed |
| 5354 | DNS engine (internal) | fixed |

Port `8080` is reserved. `main.go` refuses to start if `PORT` or `DASHBOARD_PORT` conflicts with it. Port values outside `[1, 65535]` fall back to defaults.

---

## Blocklist Profiles

| Profile | Source | Approximate entries |
|---|---|---:|
| Light | HaGeZi Light | ~40,000 |
| Normal | HaGeZi Normal | ~120,000 |
| PRO | HaGeZi PRO | ~250,000 |
| PRO++ | HaGeZi PRO++ | ~350,000 |
| Ultimate | HaGeZi Ultimate | ~500,000 |

Source: [HaGeZi DNS Blocklists](https://github.com/hagezi/dns-blocklists).

---

## Architecture

```text
User Apps → :53 (DNS)
    ↓
iptables / ip6tables / nftables
(Custom Chains: DNSCRYPT_OUT / DNSCRYPT_OUT6)
    ↓
dnscrypt-proxy :5354
    ├── blocklist.txt (local filter)
    └── DNSCrypt / DoH (encrypted upstream)

WebUI :9090     ← HTTP / SSE ───── browser
Dashboard :9091 ← /api/metrics (JSON proxy)
                  → monitoring_ui :8080
```

Components:

| Component | Language | Role |
|---|---|---|
| `proxy/main.go` | Go | HTTP server, auth, blocklist rebuild, metrics proxy |
| `proxy/*.sh` | Shell (BusyBox) | Install, service lifecycle, watchdog, firewall |
| `web/` | HTML / CSS / JS | WebUI, Dashboard, PWA |
| `scripts/` | Bash | Build, packaging, DNS binaries fetcher, release automation |

---

## Project Structure

```text
dnscrypt-proxy-webui/
├── .editorconfig                    # EditorConfig rules (LF, indent, charset)
├── .gitattributes                   # Git attributes (LF enforcement, export-ignore)
├── .gitignore                       # Git ignore rules (build, secrets, IDE)
├── .pre-commit-config.yaml          # Pre-commit hooks
├── .secrets.baseline                # detect-secrets baseline
├── CHANGELOG.md                     # Version history
├── CODE_OF_CONDUCT.md               # Contributor Covenant v2.1
├── LICENSE                          # MIT License
├── Makefile                         # Unified commands
├── module.prop                      # Magisk/KernelSU definition
├── README.md                        # Overview (EN)
├── SECURITY.md                      # Security policy (root summary)
├── update.json                      # Auto-update metadata
├── VERSION                          # Single source of truth (v1.0.0)
│
├── .github/                         # CI/CD
│   ├── workflows/
│   │   ├── ci.yml                   # Build matrix for 4 architectures
│   │   ├── codeql.yml               # Security scanning (SAST)
│   │   └── release.yml              # Signed release + sync main → develop
│   │
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml           # Bug report template
│   │   ├── config.yml               # Issue template chooser
│   │   └── feature_request.yml      # Feature request template
│   │
│   ├── PULL_REQUEST_TEMPLATE.md     # Default PR template
│   ├── PULL_REQUEST_TEMPLATE/       # Additional PR templates
│   │   └── release.md               # Release-specific PR template
│   │
│   ├── CODEOWNERS                   # Auto-assign reviewers
│   ├── dependabot.yml               # Dependency updates
│   └── SECURITY.md                  # Security policy (summary)
│
├── .devcontainer/                   # Unified dev environment
│   ├── devcontainer.json            # VS Code Dev Container config
│   └── setup.sh                     # Auto-install dev tools
│
├── scripts/                         # Build & release tools
│   ├── fetch_dns_binaries.sh        # DNS binaries fetcher (Level 4)
│   ├── generate-icons.sh            # PNG/ICO icon generator
│   ├── package_module.sh            # Build Magisk ZIP
│   ├── release.sh                   # Stable / Prerelease automation
│   └── release-patch.sh             # PATCH-only (hotfix) automation
│
├── proxy/                           # Backend (Go + Shell)
│   ├── action.sh                    # Magisk Action button handler
│   ├── build.sh                     # 4-arch cross-compile
│   ├── customize.sh                 # Magisk installer (with backup/restore)
│   ├── dnscrypt-proxy.toml          # DNSCrypt engine config
│   ├── dnscrypt-proxy.version       # DNS binary version (2.1.18)
│   ├── functions.sh                 # Shared shell library
│   ├── go.mod                       # Go module definition
│   ├── main.go                      # HTTP server
│   ├── post-fs-data.sh              # Early boot cleanup
│   ├── service.sh                   # Boot service + Watchdog launcher
│   ├── status.sh                    # Status display (4 modes)
│   ├── uninstall.sh                 # Cleanup on removal
│   ├── watchdog.sh                  # Standalone watchdog process
│   └── webui.conf                   # WebUI/Dashboard config
│
├── web/                             # Frontend (PWA)
│   ├── apple-touch-icon.png         # iOS icon (180×180)
│   ├── dashboard.html               # Monitoring dashboard
│   ├── favicon.ico                  # IE + bookmarks
│   ├── favicon-16x16.png            # Legacy favicon
│   ├── favicon-32x32.png            # Modern favicon
│   ├── icon-192.png                 # PWA icon (PNG, legacy browsers)
│   ├── icon-192.svg                 # PWA icon (SVG, modern browsers)
│   ├── icon-512.png                 # PWA icon (maskable PNG)
│   ├── icon-512.svg                 # PWA icon (maskable SVG)
│   ├── index.html                   # Main UI (FSM + SW Update)
│   ├── manifest.json                # PWA manifest
│   ├── offline.html                 # Offline fallback page
│   └── sw.js                        # Service Worker (v1.0.0)
│
└── docs/                            # Documentation (23 files)
    ├── adr/                         # Architecture Decision Records (7 files)
    │   ├── README.md                # ADR index + template + methodology
    │   ├── 0001-two-branch-model.md
    │   ├── 0002-automated-releases.md
    │   ├── 0003-post-release-sync.md
    │   ├── 0004-unified-pr-template.md          (⚠️ Superseded)
    │   ├── 0005-release-specific-pr-template.md
    │   └── 0006-rename-hotfix-to-release-patch.md
    │
    ├── API.md                       # HTTP API reference
    ├── ARCHITECTURE.md              # System architecture
    ├── BRANCHING.md                 # Git branching strategy
    ├── COMPATIBILITY.md             # Device compatibility matrix
    ├── CONTRIBUTING.md              # Contribution guide
    ├── DEVELOPMENT.md               # Developer guide
    ├── DNS_BINARIES.md              # DNS binaries management
    ├── FAQ.md                       # Common questions
    ├── GLOSSARY.md                  # Terms & abbreviations
    ├── HALL_OF_FAME.md              # Contributors recognition
    ├── INSTALL.md                   # Installation guide
    ├── RELEASE_PROCESS.md           # Release process guide
    ├── ROADMAP.md                   # Future plans
    ├── SECURITY.md                  # Threat model + disclosure
    ├── TROUBLESHOOTING.md           # Troubleshooting guide
    └── UPGRADE.md                   # Version upgrade guide
```

---

## CLI Commands

```bash
# Full status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"

# JSON status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json"

# One-line status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"

# Restart WebUI
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# Comprehensive check (DNS + WebUI + config)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --check"
```

---

## Configuration

`proxy/webui.conf`:

```
PORT=9090
DASHBOARD_PORT=9091
BIND_ADDR=127.0.0.1
AUTO_RESTART_DNS=1
AUTO_RESTART_WEBUI=1
LOG_LEVEL=info
```

Rules:

- No spaces around `=`
- No trailing comments on the same line
- `PORT` and `DASHBOARD_PORT` must differ
- `BIND_ADDR=0.0.0.0` requires credentials set in `dnscrypt-proxy.toml` → `[monitoring_ui]`

`proxy/dnscrypt-proxy.toml` controls the DNS engine itself (listen addresses, resolver selection, cache, blocklists, monitoring UI). Credentials for the internal monitoring UI live in `[monitoring_ui]`.

---

## HTTP API

All endpoints on `http://127.0.0.1:9090` unless noted.

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| GET | `/healthz` | No | Liveness check |
| GET | `/readyz` | Localhost only | Readiness check |
| GET | `/api?action=status` | Yes | Service status (ON / OFF) |
| GET | `/api?action=get_profile` | Yes | Current profile + entry count |
| GET | `/api?action=get_custom_rules` | Yes | Allowlist + Denylist content |
| GET | `/api?action=runtime_info` | Yes | Build info + actual ports |
| GET | `/api?action=logs` | Yes | Last log lines |
| GET | `/api?action=list_logs` | Yes | List diagnostic files |
| GET | `/events` | Yes | SSE stream |
| GET | `/api/metrics` | Yes | Dashboard JSON (port 9091) |
| POST | `/api/auth/login` | No | Login (POST-only) |
| POST | `/api/auth/logout` | Yes | Logout (POST-only) |
| POST | `/api/update_profile` | Yes | Update blocklist |
| POST | `/api/save_allowlist` | Yes | Save allowlist |
| POST | `/api/save_denylist` | Yes | Save denylist |
| POST | `/api/toggle_service` | Yes | Toggle DNS engine |
| POST | `/api/restart_service` | Yes | Restart DNS engine |

Full reference: [`docs/API.md`](docs/API.md).

---

## Security

Applied protections:

- BIND_ADDR defaults to `127.0.0.1`; public binds require credentials
- Login POST-only (CSRF protection)
- Basic Auth rate limiting (5 attempts / 15 minutes)
- Constant-time password comparison (`subtle.ConstantTimeCompare`)
- HttpOnly session cookies with `SameSite=Lax`
- CSRF-GET protection on state-changing endpoints
- Strict CSP, `X-Frame-Options`, `nosniff`, COOP, CORP
- `MaxBytesReader` (5 MB) on all POST bodies
- `/readyz` restricted to localhost
- `shellQuote()` on all dynamic shell paths
- `readConfPort()` range check (1–65535)
- Custom iptables / ip6tables chains (no orphan rules)
- STATUS_FILE represents user intent (not process state)
- `rebuildMu` mutex serializes blocklist rebuilds
- Auth cache (60 s) reduces file I/O

Report vulnerabilities privately: [`SECURITY.md`](SECURITY.md).

---

## Performance

| Metric | Value |
|---|---|
| RAM (idle) | ~15 MB |
| RAM (peak) | ~25 MB |
| Battery | ~1–2% / day |
| DNS latency (cached) | ~1–5 ms |
| Service startup | ~2–5 s |
| `rebuildBlocklist` (500K entries) | ~1 s |

---

## Development

```bash
# 1. Clone
git clone https://github.com/gasciljh/dnscrypt-proxy-webui.git
cd dnscrypt-proxy-webui

# 2. Switch to develop (the integration branch)
git checkout develop

# 3. Common commands
make version         # show current version
make build           # build all 4 architectures
make package         # build + package
make clean           # clean build outputs
make help            # show available targets
```

**Branching**: This project uses `main` (stable releases) + `develop` (integration). Never commit to `main` directly — open a PR against `develop`.

**Workflow guides**:

- Git workflow → [`docs/BRANCHING.md`](docs/BRANCHING.md)
- Release automation → [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md)
- Architecture decisions → [`docs/adr/README.md`](docs/adr/README.md)

**Toolchain**: Go 1.22+, Android NDK r26b+ (for cross-compilation).

**Full guide**: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

---

## Building

```bash
cd proxy
./build.sh --clean --parallel          # all 4 architectures
./build.sh --single arm64              # one architecture
./build.sh --info                      # environment / NDK info
./build.sh --package                   # binaries ZIP
```

Output: `proxy/build/dnscrypt-webui-{arm64,arm,amd64,386}`.

Reproducible builds via `SOURCE_DATE_EPOCH` (extracted from the last commit).

---

## Releasing

Releases are automated through two scripts:

| Script | Use for | Branch | Bump |
|---|---|---|---|
| `release.sh` | Stable / Prerelease | `develop` or `release/*` | Any |
| `release-patch.sh` | Hotfix (PATCH only) | `main` | PATCH only |

**Stable release** (from `develop`):

```bash
./scripts/release.sh v1.1.0
```

**PATCH release** (from `main`):

```bash
./scripts/release-patch.sh v1.0.1
```

The scripts update version files, create a signed tag, and push to `origin`. GitHub Actions then builds the module, generates SBOM + Cosign signature, publishes the release, and auto-syncs `main → develop`.

**PATCH releases** require a **manual back-merge** after publication:

```bash
make sync
```

**Release PRs** (`release/*` or `hotfix/*` → `main`) should use the
release-specific PR template:

```text
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...<branch>?template=release.md
```

Full guide: [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md).

---

## Documentation

| File | Purpose |
|---|---|
| [`docs/INSTALL.md`](docs/INSTALL.md) | Installation guide |
| [`docs/FAQ.md`](docs/FAQ.md) | Common questions |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Diagnostics and fixes |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System architecture |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Threat model + Audit Corrections |
| [`docs/API.md`](docs/API.md) | HTTP API reference |
| [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) | Device compatibility matrix |
| [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) | Developer guide |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Contribution guidelines |
| [`docs/BRANCHING.md`](docs/BRANCHING.md) | Git branching strategy |
| [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md) | Release process guide |
| [`docs/adr/README.md`](docs/adr/README.md) | Architecture Decision Records |
| [`docs/UPGRADE.md`](docs/UPGRADE.md) | Version upgrade guide |
| [`docs/DNS_BINARIES.md`](docs/DNS_BINARIES.md) | DNS binaries management |
| [`docs/GLOSSARY.md`](docs/GLOSSARY.md) | Terms and abbreviations |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Future plans |
| [`docs/HALL_OF_FAME.md`](docs/HALL_OF_FAME.md) | Contributors |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Community guidelines |
| [`CHANGELOG.md`](CHANGELOG.md) | Version history |

---

## Contributing

- **Bug reports** → [Issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues/new?template=bug_report.yml)
- **Feature requests** → [Issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues/new?template=feature_request.yml)
- **Pull requests** → follow [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)
- **Branch policy** → [`docs/BRANCHING.md`](docs/BRANCHING.md)
- **Architecture decisions** → [`docs/adr/README.md`](docs/adr/README.md)
- **Security reports** → [`SECURITY.md`](SECURITY.md)

This project follows the [Contributor Covenant v2.1](CODE_OF_CONDUCT.md).

---

## Credits

- [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) — DNS engine
- [HaGeZi DNS Blocklists](https://github.com/hagezi/dns-blocklists) — blocklists
- [Magisk](https://github.com/topjohnwu/Magisk) — module framework
- [KernelSU](https://github.com/tiann/KernelSU) — alternative module framework
- [APatch](https://github.com/bmax121/APatch) — root solution
- [ShellCheck](https://github.com/koalaman/shellcheck) — shell linting
- [shfmt](https://github.com/mvdan/sh) — shell formatting
- [golangci-lint](https://github.com/golangci/golangci-lint) — Go linting
- [Cosign](https://github.com/sigstore/cosign) — artifact signing

---

## License

MIT — see [`LICENSE`](LICENSE).

The Code of Conduct is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

---

## Links

- Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
- Releases: https://github.com/gasciljh/dnscrypt-proxy-webui/releases
- Issues: https://github.com/gasciljh/dnscrypt-proxy-webui/issues
- Discussions: https://github.com/gasciljh/dnscrypt-proxy-webui/discussions
- Security reports: https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new