# DNSCrypt Smart Filter

System-wide DNS filtering for Android devices, built on DNSCrypt
and dnscrypt-proxy.

[![CI](https://github.com/gasciljh/dnscrypt-proxy-webui/actions/workflows/ci.yml/badge.svg)](https://github.com/gasciljh/dnscrypt-proxy-webui/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-v1.5.0-blue.svg)](https://github.com/gasciljh/dnscrypt-proxy-webui/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%205%2B-brightgreen.svg)](https://www.android.com/)
[![Magisk](https://img.shields.io/badge/Magisk-20.4%2B-orange.svg)](https://github.com/topjohnwu/Magisk)
[![KernelSU](https://img.shields.io/badge/KernelSU-supported-purple.svg)](https://kernelsu.org/)
[![Go](https://img.shields.io/badge/Go-1.22-00ADD8.svg)](https://go.dev/)
[![Android App](https://img.shields.io/badge/Android%20App-v1.0.0-3DDC84.svg)](https://github.com/gasciljh/dnscrypt-proxy-app)

---

## What This Is

A Magisk / KernelSU / APatch module that turns an Android device
into a filtered, encrypted DNS resolver:

- Local DNS engine on `127.0.0.1:5354` (DNSCrypt + DoH)
- Transparent redirection of port 53 (Custom Chains, no orphan rules)
- Multi-level blocklists (HaGeZi Light → Ultimate)
- Allowlist / Denylist with a browser editor
- Bilingual WebUI (English default + Arabic toggle)
- Separate monitoring Dashboard with JSON metrics
- Installable PWA with offline fallback
- Zero telemetry — no connection to any analytics server

Works at the system level — no per-app configuration, no VPN.

---

## Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| Android | 5.0 (API 21) | 10+ (API 29) |
| Root | Magisk 20.4+ / KernelSU 0.9+ / APatch | Magisk 26+ |
| Kernel | 3.10+ | 4.14+ |
| RAM | 1 GB | 2 GB+ |
| `/data` free | 20 MB | — |
| `/sdcard` free | 6 MB | 50 MB+ |
| Architecture | arm64 / arm / x86_64 / x86 | arm64 |

**Not compatible with**: AdAway (port conflict), VPN apps
(routing conflict), SuperSU (legacy).

For per-profile memory recommendations, see
[`docs/GUIDE.md`](docs/GUIDE.md) §3.3.

---

## Install (60 seconds)

1. Download `dnscrypt-webui-1.5.0-module.zip` from
   [Releases](https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest).
2. Verify: `sha256sum -c dnscrypt-webui-1.5.0-module.zip.sha256`.
3. Install via **Magisk Manager** / **KernelSU** / **APatch**.
4. **Reboot**.
5. Open `http://127.0.0.1:9090` and log in with the credentials
   printed during install.

Full walkthrough (upgrade, uninstall, recovery, companion app):
see [`docs/GUIDE.md`](docs/GUIDE.md).

---

## Ports

| Port | Service | Configurable |
|:----:|---|---|
| 9090 | WebUI | `webui.conf` → `PORT` |
| 9091 | Dashboard | `webui.conf` → `DASHBOARD_PORT` |
| 8080 | monitoring_ui (internal) | fixed — reserved |
| 5354 | DNS engine (internal) | fixed |

Port `8080` is reserved. `main.go` refuses to start if `PORT` or
`DASHBOARD_PORT` conflicts with it. Port values outside
`[1, 65535]` fall back to defaults.

---

## Blocklist Profiles

| Profile | Source | Approximate entries | WebUI soft limit |
|---|---|---:|---:|
| Light | HaGeZi Light | ~40,000 | 80 MB |
| Normal | HaGeZi Normal | ~120,000 | 100 MB |
| **PRO** (default) | HaGeZi PRO | ~250,000 | 120 MB |
| PRO++ | HaGeZi PRO++ | ~350,000 | 160 MB |
| Ultimate | HaGeZi Ultimate | ~500,000 | 220 MB |

Source: [HaGeZi DNS Blocklists](https://github.com/hagezi/dns-blocklists).

---

## Architecture

```text
User Apps → :53 (DNS)
    │
    ▼
iptables / ip6tables / nftables
(Custom Chains: DNSCRYPT_OUT / DNSCRYPT_OUT6)
    │
    ▼
dnscrypt-proxy :5354
    ├── blocklist.txt (local filter)
    └── DNSCrypt / DoH (encrypted upstream)

WebUI :9090     ← HTTP / SSE ←──── browser
Dashboard :9091 ← /api/metrics (JSON proxy)
                  → monitoring_ui :8080

Companion install (v1.5.0):
    WebUI button ──► install-method modal (3 actions)
        ├──► local root install (5-level pm install cascade)
        ├──► GitHub page (external)
        └──► GitHub APK (direct download)

Persistent Backup :/sdcard/dnscrypt-webui-backup/
    ← 10 defensive layers; protects the 5 user config files
    ← survives reboot and module uninstall
    ← apk/ subfolder mirrors web/app-debug.apk (v1.5.0)

Shell layout (v1.5.0 — Layered Bootstrap):
    proxy/boot-mini.sh  (Layer 0 — 5 primitives + constant)
            ↑ sourced by
    proxy/functions.sh  (Layer 1 — advanced functions)
```

Full architecture, trade-offs, and internals:
see [`docs/REFERENCE.md`](docs/REFERENCE.md) §1, §3.

---

## Optional Android App

A ~3 MB native WebView wrapper for the WebUI
([separate repository](https://github.com/gasciljh/dnscrypt-proxy-app)):

- **Size**: ~3 MB · **Stack**: Kotlin + WebView · **Min Android**: 5.0
- **Telemetry**: None · **Source**:
  [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)

**Install paths** (v1.5.0): click **📲 Install App** in the WebUI
header → choose **Install locally** (5-level `pm install` cascade,
requires root), or one of the two GitHub fallbacks (Open GitHub
page / Direct download).

Full details, failure modes, and cascade reference:
see [`docs/GUIDE.md`](docs/GUIDE.md) §9.

---

## Security

- **Binding**: `127.0.0.1` by default; `0.0.0.0` requires
  credentials.
- **Auth**: Login POST-only, constant-time comparison, rate limit
  (5 / 15 min, includes Basic Auth), HttpOnly cookies with
  `SameSite=Lax`.
- **Firewall**: Custom Chains only — no orphan rules.
- **Data preservation (v1.2.0)**: 10 defensive layers, persistent
  backup with mode `0700` / `0600`, SHA256 advisory verification,
  transactional install with rollback.
- **Companion install (v1.5.0)**: One-shot CSRF token (60 s TTL),
  per-IP rate limit, localhost-only, SELinux staging
  (**never `setenforce 0`**), Play Protect trap, 75 s cascade
  deadline.

**No GPG or Cosign signing** as of v1.5.0. Only the `.sha256`
checksum is attached to the release.

Full threat model, 36 attack-vector subsections, and audit registry:
see [`SECURITY.md`](SECURITY.md).

---

## Performance

| Metric | Value |
|---|---|
| RAM (WebUI idle / peak) | ~15 MB / ~35 MB (profile-dependent) |
| RAM (DNS engine) | ~5 MB |
| Battery | ~1–2% / day |
| DNS latency (cached) | ~1–5 ms |
| `rebuildBlocklist` (500K) | ~1 s |
| Companion install (root) | ~5–15 s (typical) |

The Go runtime soft memory limit is set per profile
(light=80 MB → ultimate=220 MB). `runtime_info` exposes
`profile_key` + `memory_limit_mb`.

Detailed benchmarks by profile:
see [`docs/REFERENCE.md`](docs/REFERENCE.md) §3.5.

---

## Documentation

**The documentation map is [`docs/MAP.md`](docs/MAP.md).** It
defines the 12 user-facing documentation files and the rule that
every fact has exactly one home.

| Audience | Start here |
|---|---|
| New visitor | [`docs/GUIDE.md`](docs/GUIDE.md) §1–§3 |
| End user | [`docs/GUIDE.md`](docs/GUIDE.md) |
| Integrator | [`docs/REFERENCE.md`](docs/REFERENCE.md) §2 |
| Contributor | [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) |
| Security researcher | [`SECURITY.md`](SECURITY.md) |

---

## Contributing

- **Bug reports** → [Issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues/new?template=bug_report.yml)
- **Feature requests** → [Issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues/new?template=feature_request.yml)
- **Pull requests** → follow [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)
- **Security reports** → [`SECURITY.md`](SECURITY.md) §1 (**not** a public issue)

This project follows the
[Contributor Covenant v2.1](CODE_OF_CONDUCT.md).

---

## Related Projects

| Project | Description |
|---|---|
| [**dnscrypt-proxy-app**](https://github.com/gasciljh/dnscrypt-proxy-app) | Native Android WebView wrapper for the WebUI (optional, ~3 MB) |

---

## Credits

- [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) — DNS engine
- [HaGeZi DNS Blocklists](https://github.com/hagezi/dns-blocklists) — blocklists
- [Magisk](https://github.com/topjohnwu/Magisk) / [KernelSU](https://github.com/tiann/KernelSU) / [APatch](https://github.com/bmax121/APatch) — root solutions
- [filepath-securejoin](https://github.com/cyphar/filepath-securejoin) — path sanitization (ADR-0002)
- [Go runtime/debug](https://pkg.go.dev/runtime/debug#SetMemoryLimit) — memory limit

---

## License

MIT — see [`LICENSE`](LICENSE). The Code of Conduct is licensed
under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

---

## Links

- **Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
- **Releases**: https://github.com/gasciljh/dnscrypt-proxy-webui/releases
- **Issues**: https://github.com/gasciljh/dnscrypt-proxy-webui/issues
- **Discussions**: https://github.com/gasciljh/dnscrypt-proxy-webui/discussions
- **Security reports**: https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new
- **Companion app**: https://github.com/gasciljh/dnscrypt-proxy-app