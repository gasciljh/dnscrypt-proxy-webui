# Security Policy — DNSCrypt Smart Filter

**Version**: v1.6.0 (Global Edition)
**Last updated**: 2026-11-13
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh
**Contact**: [GitHub Private Vulnerability Reporting](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

> **Canonical security reference.** This file merges the former
> `docs/SECURITY.md` (full policy) and `.github/SECURITY.md`
> (summary) into one document.

---

## Status Snapshot

| Metric | Value |
|---|---|
| Current version | v1.6.0 |
| Audit Corrections Registry | **#33** (last entry from v1.0.0) |
| External Go dependencies | **1** — `github.com/cyphar/filepath-securejoin v0.7.0` (ADR-0002) |
| Layered Bootstrap | 3 layers — `lib/*.sh` (6 modules) + `boot-mini.sh` + `functions.sh` (ADR-0003) |
| Companion install | 4 endpoints, one-shot CSRF token, per-IP rate limit |
| SELinux posture | Never `setenforce 0` — staging to `/data/local/tmp/` only |

### Security-Relevant Changes — At a Glance

| Version | Category | Highlights |
|---|---|---|
| v1.0.0 | Baseline | 33 Audit Corrections (CSRF, path-injection, port collision, IPv4/IPv6 separation, watchdog token skeleton, dynamic ports) |
| v1.1.0 | Runtime hardening | MEM-1 dynamic memory limit · MEM-2 extended `shellQuote` · MEM-3 `MONITORING_UI_PORT` constant |
| v1.2.0 | Data preservation | BAK-1..BAK-4 · FIX-1/FIX-2 · WD-TOKEN · 10 defensive layers · bilingual WebUI |
| v1.3.0 | Refinements | PWA install button · live status LED · DNS auto-start fix · SNAP-*/ROT-* semantics |
| v1.4.0 | Integration | Companion APK route · CodeQL `go/path-injection` fix (partial in v1.4.0, full in **v1.5.0**) · iOS PWA removal · MAIN-01 |
| v1.5.0 | Companion install | 4 endpoints · one-shot CSRF token · per-IP rate limit · SELinux staging · Play Protect trap · 75 s cascade deadline · Layered Bootstrap (ADR-0003) · `filepath-securejoin` (ADR-0002) |
| **v1.6.0** | **Architecture & UX** | **WebUI timezone fix (Unix timestamp)** · **PWA cache version bump** · **Shell scripts modularized into `lib/` (Layer 0)** · **`buildBackupInfo` mtime sort** · **Codebase cleanup** |

---

## Table of Contents

1. [Reporting a Vulnerability](#1-reporting-a-vulnerability)
2. [Security Scope](#2-security-scope)
3. [Threat Model](#3-threat-model)
4. [Assets & Trust Boundaries](#4-assets--trust-boundaries)
5. [Attack Vectors & Mitigations](#5-attack-vectors--mitigations)
6. [Security Headers](#6-security-headers)
7. [Authentication](#7-authentication)
8. [Session Management](#8-session-management)
9. [Input Validation](#9-input-validation)
10. [Cryptography](#10-cryptography)
11. [Logging & Privacy](#11-logging--privacy)
12. [Supply Chain](#12-supply-chain)
13. [Known Limitations](#13-known-limitations)
14. [Audit Checklist](#14-audit-checklist)
15. [Audit Corrections Registry](#15-audit-corrections-registry)
16. [Acknowledgments](#16-acknowledgments)
17. [References](#17-references)

---

## 1. Reporting a Vulnerability

### 1.1 Preferred Method

**Do not open a public GitHub Issue** — the vulnerability may be
exploited before a fix is deployed.

Use **GitHub Private Vulnerability Reporting**:
[Report a vulnerability](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

### 1.2 Required Information

- Description of the vulnerability
- Impact: what an attacker can do, prerequisites, exposed assets
- Reproduction steps
- Affected version
- Environment: Android version, device, root solution
- PoC if possible
- Suggested fix if you have one

### 1.3 SLA

| Phase | Duration |
|---|---|
| Acknowledgment | 24–48 hours |
| Initial assessment | 3–5 days |
| Fix | Depends on severity |
| Public disclosure | After fix |

### 1.4 Disclosure Scope

- **In scope**: `main.go`, `install_app.sh`, shell scripts (`lib/*.sh`), HTML/JS, backup layer.
- **Out of scope**: dnscrypt-proxy upstream, Android OS, Magisk, the companion app repository.

---

## 2. Security Scope

### 2.1 What We Protect

| Asset | Description |
|---|---|
| Service control | Who can start/stop DNS |
| Blocklists | Who can modify allowlist/denylist |
| Login credentials | username/password |
| Diagnostic files | logs, credentials |
| Query log | privacy |
| Firewall integrity | Custom Chains only |
| STATUS_FILE | User intent semantics |
| BLOCKLIST | `rebuildMu` mutex |
| Memory limit | Per-profile soft limit |
| User data | 5 config files across upgrades |
| Backup layer | `/sdcard/dnscrypt-webui-backup/` |
| Watchdog auth | `X-Watchdog-Token` header |
| Snapshot set | Rotation + protected targets |
| Install tokens | One-shot CSRF, 60 s TTL |

### 2.2 What We Do Not Protect

- **DNS queries themselves** — visible to the DNSCrypt/DoH provider.
- **The local network** — if `BIND_ADDR=0.0.0.0`.
- **Root user** — can do anything by nature.
- **A root-privileged malicious app** — can read/write `/sdcard/dnscrypt-webui-backup/`.
- **The companion APK's own security** — out of scope (separate repository).
- **A malicious Play Protect app** — see §5.36.4 for the documented risk.

---

## 3. Threat Model

### 3.1 Adversaries

| Adversary | Capabilities | Motivation |
|---|---|---|
| Malicious app | read `/data/local/tmp`, launch intent | DNS leakage |
| Local attacker | shell access (root or not) | modify blocklist |
| Malicious website | open browser → `127.0.0.1:9090` | CSRF |
| Local network | LAN access if `BIND_ADDR=0.0.0.0` | modify service |
| Internet MITM | intercept DNS | query leakage |
| LAN attacker | reconnaissance via `/readyz` | targeting |
| Resource-exhaustion attacker | trigger GC via profile change | DoS |
| Malicious root app | read/write backup dir | tamper with config |
| Watchdog impersonator | force DNS restart | DoS |
| Backup tamperer | modify `.manifest.json` | inject config |
| Recovery-mode abuser | create `recovery` file | force restore |
| Companion APK spoofer | serve tampered APK | trick user |
| Install brute-force | repeat POST install | CPU DoS |
| Install CSRF | malicious page triggers install | unauthorized install |
| Install token leak | XSS reads token | unauthorized install |

### 3.2 Applied Protections

**Network & Auth**
- Binding `127.0.0.1` by default; refuse `0.0.0.0` without credentials
- Login POST-only; `/readyz` localhost-only
- HttpOnly cookies + `SameSite=Lax` + conditional `Secure`
- Constant-time password and watchdog-token comparison
- Rate limiting (5 attempts / 15 min) — includes Basic Auth
- Session GC (30 min); SSE write deadline (30 s)
- Watchdog token (`X-Watchdog-Token`)

**Firewall & Networking**
- Custom iptables/ip6tables chains — no orphan rules
- nftables support via `dnscrypt_filter` table
- IPv4/IPv6 separation (no cross-protocol contamination)
- Dynamic bootstrap exception — prevents DNS loop
- Port Guard: `main.go` refuses port 8080

**Process & State**
- `STATUS_FILE` = user intent (only `startService` / `stopService` write it)
- `rebuildMu` serializes blocklist rebuilds
- `backupMu` serializes pre-critical backups
- `sync.Once` for shell detection
- `authCache` (60 s) + `lastUpdateCache` (5 s)

**Memory & DoS**
- `MaxBytesReader` (5 MB) on POST bodies
- `io.LimitReader` (50 MB) on blocklist downloads
- `limitedBuffer` (2048 B) for stderr capture
- Dynamic per-profile memory limit (80–220 MB)
- Per-IP install rate limit (5 / 15 min)
- 75-second cascade deadline in `install_app.sh`

**Data Preservation (10 layers)**
- Multi-source discovery (7 candidates)
- Persistent backup at `/sdcard/dnscrypt-webui-backup/` (mode 0700 / 0600)
- SHA256 integrity (advisory)
- Transactional upgrade with rollback
- SELinux context preservation (`restorecon` / `chcon`)
- Recovery mode (`recovery` trigger file)
- Config migrations
- Auto-backup (24 h) + rotation (21 snapshots)
- Observability (`status.sh --diagnose` + 7-field `backups`)

**Companion Install (v1.5.0+)**
- One-shot CSRF token (60 s TTL)
- Per-IP rate limit (5 failed / 15 min)
- Localhost gate on all three install surfaces
- SELinux staging to `/data/local/tmp/` — **`setenforce 0` is never called**
- Play Protect temporary disable + trap restore (`$_VERIFIER_ORIG`)
- 75 s cascade deadline < 90 s `INSTALL_TIMEOUT`
- SHA256 advisory verification of the APK
- Three-way signal trap (EXIT / INT / TERM; exit 130 / 143)

---

## 4. Assets & Trust Boundaries

### 4.1 Trust Boundaries

```text
┌───────────────────────────────────────────────────────────────┐
│ Untrusted Zone                                                │
│ User Apps → :53 DNS                                           │
│                                                               │
│ ┌─ Trust Boundary 1: Firewall ──────────────────────────────┐ │
│ │ OUTPUT (nat) → DNSCRYPT_OUT / DNSCRYPT_OUT6 (custom)      │ │
│ │ RETURN for loopback + bootstrap; DNAT for the rest        │ │
│ └───────────────────────────┬───────────────────────────────┘ │
│                             │ 127.0.0.1:5354                  │
│ ┌─ Trusted Zone (WebUI) ────▼───────────────────────────────┐ │
│ │ main.go :9090, :9091                                       │ │
│ │ + Auth, Rate limit, CSP, CSRF (POST-only)                 │ │
│ │ + STATUS_FILE = user intent                               │ │
│ │ + hasEndpoint (exact match)                               │ │
│ │ + rebuildMu, backupMu, portConfMu, installTokens          │ │
│ │ + watchdog token, install token                           │ │
│ └───────────────────────────┬───────────────────────────────┘ │
│                             │ exec                            │
│ ┌─ Trust Boundary 2: Shell Scripts (root) ──────────────────┐ │
│ │ + lib/constants.sh, lib/process.sh, lib/firewall.sh ...    │ │
│ │ + boot-mini.sh, functions.sh (Layered Bootstrap)          │ │
│ │ + install_app.sh: hardcoded APK path + double-quoted args  │ │
│ │ + SELinux staging; Play Protect trap; 75 s cascade deadline│ │
│ └───────────────────────────┬───────────────────────────────┘ │
│                             │ copy/restore                    │
│ ┌─ Trust Boundary 3: Persistent Backup ─────────────────────┐ │
│ │ /sdcard/dnscrypt-webui-backup/                             │ │
│ │ + mode 0700 / 0600                                        │ │
│ │ + SHA256 manifest (advisory)                              │ │
│ │ + transactional txn-* / orphan-txn-*                      │ │
│ │ + apk/ mirror (v1.5.0)                                    │ │
│ └────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

### 4.2 Assets

| Asset | Location | Sensitivity |
|---|---|---|
| Username/password | `dnscrypt-proxy.toml` | High |
| Session tokens | memory | Medium |
| Blocklist | `blocklist.txt` | Low |
| Allowlist/Denylist | `*.txt` | Medium |
| Logs | `/data/local/tmp/*.log` | Medium |
| Credentials (cached) | `/data/local/tmp/dnscrypt_credentials.txt` | High |
| STATUS_FILE | `run/dnscrypt.status` | Medium |
| Firewall chains | kernel memory | Medium |
| Auth cache | memory (60 s TTL) | Medium |
| Watchdog token | `run/.watchdog_token` (0600) | High |
| Persistent backups | `/sdcard/dnscrypt-webui-backup/` | High |
| Backup manifest | `<snap>/.manifest.json` | Medium |
| `.last_stable` | same dir | Low |
| `txn-*` / `orphan-txn-*` | same dir | High |
| Optional companion APK | `/data/.../web/app-debug.apk` | Low (public) |
| `installTokens` | memory (60 s TTL, one-shot) | High while valid |
| `installAttempts` | memory | Low |
| `companionStateCache` | memory (30 s TTL) | Low |
| `apk/` mirror | `/sdcard/.../apk/` | Low |

---

## 5. Attack Vectors & Mitigations

Each subsection follows: **Background** → **Solution** → **Verify**.

### 5.1 Unauthorized Access
- **Mitigation**: binding `127.0.0.1`, Basic/Bearer/Cookie auth, constant-time compare, rate limiting.
- **Verify**: `grep -q 'BIND_ADDR=127.0.0.1' proxy/webui.conf`

### 5.2 CSRF
- **Solution**: all state-changing endpoints POST-only.
- **Verify**: `curl -i "http://127.0.0.1:9090/api/auth/login?username=x&password=y" | head -1` → 405.

### 5.3 Path Traversal
- **Mitigation**: `serveStaticAssets` whitelist; no `filepath.Join(MODDIR, "web", r.URL.Path)`.
- **Verify**: `curl -i "http://127.0.0.1:9090/../../etc/passwd" | head -1` → 404.

### 5.4 XSS
- **Mitigation**: `escapeHtml()` on all output, CSP `script-src 'self'`.

### 5.5 Command Injection
- **Mitigation**: No SQL, `exec.Command` without shell, `runShell` limited to fixed commands, `shellQuote()` for dynamic paths, `install_app.sh` uses hardcoded paths and double quotes.

### 5.6 Brute Force
- **Mitigation**: 5 attempts / IP / 15 min. Basic Auth shares limiter. Install endpoint has separate limiter.

### 5.7 Memory Exhaustion
- **Mitigation**: `MaxBytesReader(5 MB)`, `io.LimitReader(50 MB)`, `limitedBuffer(2048)`.

### 5.8 Timing Attacks
- **Mitigation**: `subtle.ConstantTimeCompare` for passwords, watchdog tokens, and install tokens.

### 5.9 DNS Leak
- **Mitigation**: IPv4/IPv6 separation, dynamic bootstrap exceptions, Custom Chains.

### 5.10 SSE DoS (Slow Client)
- **Mitigation**: `SetWriteDeadline(30 s)` before each flush.

### 5.11 Token Leakage
- **Mitigation**: HttpOnly cookie only, no `sessionStorage`.

### 5.12 405 Method Not Allowed — RFC Compliance
- **Mitigation**: `Allow: POST` on 405 responses.

### 5.13 Firewall Orphan Leak
- **Mitigation**: Custom Chains, unified cleanup across scripts.

### 5.14 STATUS_FILE Semantics
- **Mitigation**: `STATUS_FILE` is read-only from the perspective of `getStatusUncached`.

### 5.15 IPv6 Rate Limit Bypass
- **Mitigation**: `getClientIP(r)` uses `net.SplitHostPort`.

### 5.16 Port Collision
- **Mitigation**: `MONITORING_UI_PORT` constant. Refuse to start on port 8080.

### 5.17 TOML Section Injection
- **Mitigation**: Section tracking (`inSection` boolean) in all parsers.

### 5.18 Basic Auth Rate Limit Bypass
- **Mitigation**: `checkAuth` records failed Basic Auth attempts in `loginAttempts`.

### 5.19 Section Header with Comment
- **Mitigation**: Section detection uses `strings.Index(trimmed, "]")`.

### 5.20 Dashboard JSON Conversion
- **Mitigation**: `parsePrometheus()` + `buildDashboardJSON()`.

### 5.21 Exact Endpoint Matching
- **Mitigation**: `hasEndpoint()` performs an exact match.

### 5.22 Preserve User Settings on Upgrade
- **Superseded by v1.2.0** (10 defensive layers).

### 5.23 `fuser` PID Parsing
- **Mitigation**: `fuser -n tcp "$port" | tr ' ' '\n' | grep -E '^[0-9]+$'`.

### 5.24 Login POST-Only
- **Mitigation**: Reject non-POST requests with 405.

### 5.25 `readConfPort` Range Check
- **Mitigation**: Validates range `[1, 65535]`.

### 5.26 `/readyz` Localhost-Only
- **Mitigation**: Rejects non-localhost with 403.

### 5.27 `shellQuote` Injection Protection
- **Mitigation**: 24-character escape set, applied to every dynamic shell path.

### 5.28 Auth Cache (60 s)
- **Mitigation**: Caches credentials for 60 seconds.

### 5.29 Rebuild Blocklist Mutex (RACE-1)
- **Mitigation**: `rebuildMu sync.Mutex` protects `rebuildBlocklist`.

### 5.30 Runtime Info Ports (PORT-2)
- **Mitigation**: `buildRuntimeInfo()` returns `webui_port` + `dashboard_port`.

---

### 5.31 v1.1.0 — Runtime Hardening
- **MEM-1**: Dynamic memory limit (`debug.SetMemoryLimit`).
- **MEM-2**: Extended `shellQuote` character set (24 chars).
- **MEM-3**: `MONITORING_UI_PORT` constant used in `metricsProxyHandler`.

---

### 5.32 v1.2.0 — Data Preservation (10 Layers)

| # | Layer | File(s) |
|:-:|---|---|
| 1 | Multi-source detection (7 candidates) | `customize.sh` |
| 2 | Persistent backup | `customize.sh`, `lib/backup.sh` |
| 3 | SHA256 integrity (advisory) | `customize.sh`, `lib/backup.sh` |
| 4 | Transactional upgrades | `customize.sh`, `lib/backup.sh` |
| 5 | Root-solution compatibility | `customize.sh` |
| 6 | SELinux preservation | `customize.sh`, `lib/backup.sh` |
| 7 | Recovery mode | `customize.sh` |
| 8 | Config migrations | `customize.sh` |
| 9 | Automation + rotation | `service.sh`, `main.go` |
| 10 | Observability | `status.sh`, `main.go` |

---

### 5.33 Watchdog Token (WD-TOKEN)
- **Mitigation**: Localhost-scoped, constant-time comparison, not rate-limited, persistent, fail-closed.

---

### 5.34 CodeQL `go/path-injection` Fix in `removeModule`
- **Solution**: `filepath.Base()` sanitizer + `securejoin.SecureJoin` (v1.4.0 functional, fully closed in **v1.5.0** via ADR-0002).

---

### 5.35 iOS PWA Removal + Companion APK Route
- **Solution**: Dead code removal. Route `GET /app-debug.apk` added.

---

### 5.36 v1.5.0 — Companion App Install Security

#### 5.36.1 One-Shot CSRF Token
- 64-hex random token, single-use, 60-second TTL, constant-time comparison.

#### 5.36.2 Per-IP Install Rate Limit
- 5 attempts / 15 min per IP. Separate from login attempts.

#### 5.36.3 SELinux Staging
- APK staged to `/data/local/tmp/` (context `shell_data_file`). Never `setenforce 0`.
- Traps (EXIT/INT/TERM) clean up the staged APK.

#### 5.36.4 Play Protect Temporary Disable
- Verifier temporarily disabled, restored via trap (`$_VERIFIER_ORIG`).

#### 5.36.5 5-Level Cascade
- `pm install` variants + `install-create/commit` + `cmd package install`.

#### 5.36.6 Response Design — Failure is 200, Not 4xx
- Install failures return 200 (JSON body carries `status: "error"`).

#### 5.36.7 Package Name Candidates
- 3 candidates tried in order. Android verifies the signature regardless of name.

#### 5.36.8 SHA256 Verification
- Sidecar `.sha256` checked if present; advisory mode otherwise.

---

### 5.37 v1.6.0 — Architecture & UX

#### 5.37.1 Modular Shell Architecture (`lib/`)
- Shell code split into 3 layers: `lib/*.sh` (6 modules) → `boot-mini.sh` → `functions.sh`.
- CI Step 9 enforces module presence and prevents Layer-0 redefinition in `functions.sh`.

#### 5.37.2 Timezone-Agnostic Timestamps
- Backend emits `last_update_unix` (int) + `last_update` (RFC3339) derived from the same `modTime`.
- Frontend renders via `toLocaleString()` — respects device timezone.

#### 5.37.3 `buildBackupInfo` mtime Sort
- Fixed: previously sorted by directory name, now sorts by `Info().ModTime()` — matches `rotate_backups` and `status.sh`.

---

## 6. Security Headers
- CSP: `default-src 'self'; script-src 'self' 'unsafe-inline'`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: no-referrer`
- `Permissions-Policy: geolocation=(), ...`
- COOP / CORP: `same-origin`

## 7. Authentication
- **Schemes**: Watchdog Token → Bearer → Session Cookie → Basic Auth.
- **Credentials Source**: `dnscrypt-proxy.toml` `[monitoring_ui]` section only.
- **Rate Limiting**: 5 failed attempts per IP / 15 min.

## 8. Session Management
- **Token**: 32 bytes → 64 hex. Memory only. HttpOnly cookie. 24h sliding TTL.
- **Garbage Collection**: Every 30 min (`startSessionGC`).

## 9. Input Validation
- **Size Limits**: POST (5 MB), Download (50 MB), Stderr (2048 B).
- **Port Validation**: `[1, 65535]` and `≠ 8080`.
- **Path Validation**: `filepath.Base()`, `filepath.Clean()`, `securejoin.SecureJoin`.
- **Endpoint Matching**: `hasEndpoint()` exact match.

## 10. Cryptography
- **Algorithms**: `crypto/rand`, SHA-256, `subtle.ConstantTimeCompare`.
- **Not Encrypted**: Blocklist, Logs, Credentials (protected by `0600`), Backups (protected by `0700`).

## 11. Logging & Privacy
- **Privacy Posture**: Zero telemetry.
- **Log Injection Defense**: `sanitizeLogText()` removes control characters.

## 12. Supply Chain
- **Dependencies**: Go stdlib, `filepath-securejoin v0.7.0`.
- **Release Signing**: No Cosign/GPG. SHA-256 checksum only. Companion APK signed by Android.

## 13. Known Limitations
- Root user bypasses everything.
- LAN access if `BIND_ADDR=0.0.0.0`.
- `'unsafe-inline'` CSP limitation.
- SIGKILL during install skips the trap (bounded by 75 s deadline).

## 14. Audit Checklist
- **14.1 Build & CI**: `make build`, `bash -n *.sh lib/*.sh scripts/*.sh`
- **14.2 Authentication**: Login POST-only, `/readyz` localhost-only, Basic Auth rate limit.
- **14.3 Firewall**: IPv4/IPv6 chains, no orphans.
- **14.4 State & Concurrency**: `STATUS_FILE` read-only, `rebuildMu` present.
- **14.5 Endpoints**: Exact match, `hasEndpoint` present.
- **14.6 Cookies & Sessions**: HttpOnly, SameSite=Lax, GC present.
- **14.7 Memory**: Profile limit via `runtime_info`.
- **14.8 Backup & Recovery**: Directory mode 700, 7-field schema, recovery trigger.
- **14.9 CodeQL & Path Sanitization**: `filepath.Base`, `securejoin.SecureJoin`.
- **14.10 Companion Install**: APK route, cascade levels, staging, no `setenforce 0`.

## 15. Audit Corrections Registry
- **33 Corrections** (v1.0.0).
- **v1.1.0+** are runtime additions, data preservation, and companion install security (not new audit corrections).

## 16. Acknowledgments
- Anthropic Claude (code review assistance).
- Upstream projects (DNSCrypt, HaGeZi, Magisk, KernelSU, APatch, securejoin).

## 17. References
- RFC 7231, RFC 6265bis, CWE Top 25, OWASP ASVS.