# Security Policy — DNSCrypt Smart Filter

Vulnerability disclosure policy + threat model + applied protections.

**Version**: v1.5.0
**Last updated**: 2026-10-15
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh
**Contact**: [GitHub Private Vulnerability Reporting](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

> **v1.5.0 changes**:
>   • Version bumped from v1.4.0 to v1.5.0.
>   • **No new audit corrections** — v1.5.0 is a feature release.
>     The Audit Corrections Registry (§17) remains at **#33** (last
>     entry from v1.0.0). New audit corrections will resume at **#34**
>     in a future release.
>   • **Companion app one-tap install (APK-5, APK-11)** — the WebUI
>     install button now triggers a root-level install via
>     `install_app.sh`, gated by a one-shot CSRF token and a per-IP
>     rate limit. See **§5.36 (new)** for the full security model.
>   • **New auth scheme** — a one-shot **install token** (60 s TTL)
>     consumed by `POST /api/install_companion_app`. It is orthogonal
>     to the session cookie scheme. See **§7.1**.
>   • **New assets in the trust model** — `installTokens`
>     (in-memory), `installAttempts` (per-IP rate limiter), and
>     `companionStateCache` (30 s). See **§2.1** and **§4.2**.
>   • **New adversary scenarios** — install brute-force and CSRF on
>     the install endpoint. See **§3.1**.
>   • **SELinux staging (APK-11)** — the APK is copied to
>     `/data/local/tmp/` before the install. **SELinux is never
>     disabled**. See **§5.36.3**.
>   • **Play Protect temporary disable (APK-11)** — the package
>     verifier is disabled during the cascade and restored on exit
>     via a three-way `EXIT / INT / TERM` trap. See **§5.36.4**.
>   • **Client-side state fixes** (IDX-23, IDX-23b, IDX-25, IDX-25a)
>     — no security impact. Documented in `docs/ARCHITECTURE.md`
>     §6.9–§6.12.
>   • **All v1.4.0 sections retained**. §5.34 (CodeQL fix) and §5.35
>     (iOS removal + companion APK route) are preserved unchanged.

> **v1.5.0+ post-release patches**:
>   Documentation-accuracy corrections applied after the v1.5.0
>   Global Edition sweep. **None is an audit correction** — the
>   Registry (§17) remains at **#33**.
>
>   • **§5.36.3** — corrected the staged-APK cleanup description
>     (the trap *does* remove the file on every exit path).
>   • **§5.36.4** — corrected the Play Protect duration claim and
>     documented the `$_VERIFIER_ORIG` restore value.
>   • **§12.1** — corrected the `install_app.sh` signing-source
>     attribution (the script is covered by the module ZIP's SHA-256).
>   • **§13.2** — removed the "staged-APK cleanup" from Known Issues
>     (now resolved).
>   • **§14.34** — eight shell-portability corrections for BusyBox
>     grep compatibility (Android's default `grep`).
>   • Header date bumped to 2026-10-15.
>
>   Every identifier is catalogued in **§18 — Documentation
>   Corrections to This File**.

> **v1.4.0 changes** (historical):
>   • Version bumped from v1.3.0 to v1.4.0.
>   • **No new audit corrections**. Registry remains at #33.
>   • **CodeQL `go/path-injection` fix in `removeModule`** —
>     documented in §5.34.
>   • **iOS PWA logic removal** — Android-only project. §5.35.
>   • **`/app-debug.apk` static route (optional)** — public, no
>     auth. §5.35.2.
>   • **§12.1 Supply Chain corrected** — removed false claims
>     about Cosign / SBOM.
>   • **§14.1 Pre-release checklist corrected** — Cosign + SBOM
>     checkboxes removed.

> **v1.3.0 changes** (historical):
>   • Version bumped from v1.2.0 to v1.3.0.
>   • **No new audit corrections**.
>   • **PWA install button (client-side)** — no security impact.
>   • **Live status LED (client-side)** — no security impact.
>   • **DNS auto-start fix (`service.sh`)** — covered by WD-TOKEN
>     (§5.33).
>   • **`buildBackupInfo` sort order change** — name → mtime.
>   • **§6.4 and §13.2** — deferred CSP hardening.

> **v1.2.0 changes** (historical):
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **No new audit corrections**.
>   • **New §5.31 — Data Preservation Security Model.**
>   • **New §5.32 — Correctness Fixes (FIX-1, FIX-2).**
>   • **New §5.33 — Watchdog Token (WD-TOKEN).**
>   • **Global edition — English default + Arabic toggle.**

> **Numbering clarification**: §5.31 through §5.36 are **section
> numbers** in this document, **not** Audit Correction numbers.
> The Audit Corrections Registry is a flat, monotonic sequence that
> only advances when a new audit correction is filed.

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
14. [Security Checklist](#14-security-checklist)
15. [Acknowledgments](#15-acknowledgments)
16. [Changelog — Security Changes](#16-changelog--security-changes)
17. [Audit Corrections Registry](#17-audit-corrections-registry)
18. [Documentation Corrections to This File](#18-documentation-corrections-to-this-file)

---

## 1. Reporting a Vulnerability

### 1.1 Preferred Method

**Do not open a public GitHub Issue** — the vulnerability may be
exploited before a fix is deployed.

Instead, use **GitHub Private Vulnerability Reporting**:

- **GitHub**: [Report a vulnerability](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)
- **Alternative**: Open an Issue titled `[SECURITY]` with no sensitive details.
- **Discussions**: [Security category](https://github.com/gasciljh/dnscrypt-proxy-webui/discussions).

### 1.2 Required Information

```markdown
## Description
[Brief description of the vulnerability]

## Impact
- What can an attacker do?
- What are the prerequisites? (root, local access, ...)
- What assets are exposed?

## Reproduction Steps
1. ...
2. ...
3. ...

## Affected Version
v1.5.0 (or any version)

## Environment
- Android version:
- Device:
- Magisk/KernelSU version:

## PoC (if possible)
[code / screenshot / log]

## Suggested Fix (optional)
[Your idea for a solution]
```

### 1.3 SLA

| Phase | Duration |
|---|---|
| Acknowledgment | 24–48 hours |
| Initial assessment | 3–5 days |
| Fix | Depends on severity |
| Public disclosure | After fix |

### 1.4 Disclosure Scope

- **In scope**: `main.go`, `install_app.sh`, shell scripts, HTML/JS, backup layer
- **Out of scope**: dnscrypt-proxy upstream, Android OS, Magisk

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
| User intent integrity | `STATUS_FILE` semantics |
| BLOCKLIST integrity | `rebuildMu` mutex (v1.0.0) |
| Dynamic ports integrity | `runtime_info` ports (PORT-2) |
| Memory limit integrity | Dynamic per-profile limit (v1.1.0) |
| User-data preservation | 5 config files preserved across upgrades (v1.2.0) |
| Backup-layer integrity | `/sdcard/dnscrypt-webui-backup/` permissions + `backupMu` (v1.2.0) |
| Watchdog authentication | `X-Watchdog-Token` on `/api/ensure_running_service` (v1.2.0) |
| Snapshot-set integrity | Rotation respects manifest-based detection + mtime sort + protected targets (v1.3.0) |
| Optional companion APK | Served at `/app-debug.apk`; public, no auth needed (v1.4.0) |
| **Install token store (v1.5.0)** | **`installTokens` map — one-shot CSRF tokens, 60 s TTL; High while valid** |
| **Install rate limiter (v1.5.0)** | **`installAttempts` map — per-IP counters; Low (no secrets)** |
| **Companion state cache (v1.5.0)** | **`companionStateCache` — 30 s TTL; Low (no secrets)** |

### 2.2 What We Do Not Protect

- **The DNS queries themselves** — visible to the DNSCrypt/DoH provider.
- **The local network** — if `BIND_ADDR=0.0.0.0`.
- **Root user** — can do anything by nature, including reading the
  persistent backup directory (`0700`, but root can bypass).
- **A root-privileged malicious app** — can read/write
  `/sdcard/dnscrypt-webui-backup/`, the watchdog token, and the
  install token store (via `ptrace` on the running process).
- **The companion APK's own security** — the APK is an Android
  application distributed from a separate repository
  (`gasciljh/dnscrypt-proxy-app`). Its code, permissions, and
  network behavior are out of scope for this document.
- **A malicious Play Protect app** — the temporary disable of the
  package verifier during the install cascade is a documented
  risk (see §5.36.4).

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
| Advanced user | edit TOML manually | self-DoS |
| LAN attacker | reconnaissance via `/readyz` | targeting (fixed by NEW-4) |
| Resource-exhaustion attacker | trigger GC pressure via profile change | DoS on low-RAM devices (mitigated by v1.1.0 dynamic limits) |
| Malicious root app | read/write `/sdcard/dnscrypt-webui-backup/` | tamper with user config |
| Watchdog impersonator | send requests to `ensure_running_service` without valid session | force DNS engine restart (fixed by WD-TOKEN in v1.2.0) |
| Backup tamperer | modify `.manifest.json` or files in the backup directory | inject configuration |
| Recovery-mode abuser | create a `recovery` trigger file | force a restore from a snapshot |
| Companion APK spoofing | serve a modified `web/app-debug.apk` from the module | trick user into installing a tampered app. Mitigation: the APK is signature-verified by Android at install time |
| **Install brute-force (v1.5.0)** | **repeatedly POST `/api/install_companion_app` to force a root install** | **exhaust CPU / trigger repeated `pm install` runs. Mitigated by the per-IP rate limit (5 failed attempts / 15 min)** |
| **Install CSRF (v1.5.0)** | **a malicious web page loaded in a browser on the same device attempts to trigger the install endpoint** | **force an unauthorized install. Mitigated by the one-shot CSRF token from `/api?action=install_token` (see §5.36.1)** |
| **Install token leak (v1.5.0)** | **an XSS or a rogue extension reads the token from the DOM or a network log** | **install the companion app without user consent. Mitigated by the 60 s TTL and the one-shot nature of the token** |

### 3.2 Applied Protections

- Binding 127.0.0.1 by default
- Refuse to start if 0.0.0.0 without credentials
- Strict CSP (with `'unsafe-inline'` — see §6.4)
- HttpOnly cookies + SameSite=Lax
- Secure cookies (conditional on localhost)
- Constant-time password comparison
- Rate limiting (5 attempts / 15 min) — includes Basic Auth
- Session GC for cleanup
- SSE Write Deadline (prevents DoS)
- CSRF-GET protection — state-changing endpoints POST only
- Cookie-only auth — no token in JS storage or JSON response
- Dynamic bootstrap exception — prevents DNS loop
- IPv4/IPv6 firewall separation — no cross-protocol contamination
- Custom Chains in iptables — no orphans
- STATUS_FILE semantics — user intent preserved
- IPv6-safe rate limiting — supports `[::1]`
- Port Guard 8080 — reject monitoring_ui conflict
- Section-restricted TOML — read from `[monitoring_ui]` only
- Exact endpoint matching — no prefix matching
- Section header with comment — `[monitoring_ui] # comment`
- Per-port cache — no cross-port mixing
- Preserve user settings on upgrade — backup/restore
- Login POST-only — closes CSRF vector on `/api/auth/login`
- `/readyz` localhost-only — prevents info leakage
- `shellQuote()` — shell injection protection (extended in v1.1.0)
- `readConfPort` range check — reject values outside `[1, 65535]`
- `rebuildMu` mutex — prevents BLOCKLIST race
- `sync.Once` — thread-safe caching of shell detection
- **v1.1.0**: Dynamic per-profile memory limit — prevents GC
  pressure on heavy profiles while keeping DoS protection on
  light profiles
- **v1.1.0**: `MONITORING_UI_PORT` single source of truth in
  metrics handler — removes the last hardcoded reserved port
- **v1.2.0**: 10 defensive layers for user-data preservation
  (see §5.31)
- **v1.2.0**: `backupMu` serialization — prevents concurrent
  snapshot corruption
- **v1.2.0**: Persistent backup directory with mode `0700`/`0600`
  (see §5.31.2)
- **v1.2.0**: SHA256 integrity verification (advisory; see §5.31.4)
- **v1.2.0**: Transactional upgrade with rollback
- **v1.2.0**: Watchdog token (`X-Watchdog-Token`)
- **v1.2.0**: SELinux context preservation via `restorecon` /
  `chcon` on every restored file
- **v1.2.0**: Recovery-mode snapshot-and-reapply (FIX-1)
- **v1.3.0**: `service.sh` calls `ensure_running_service` at boot
- **v1.3.0**: ROT-MANIFEST — rotation detects snapshots by
  `.manifest.json` presence
- **v1.3.0**: ROT-MTIME — rotation sorts candidates by mtime
- **v1.3.0**: ROT-PROTECT — preserves `.last_stable` + newest
  install snapshot
- **v1.3.0**: SNAP-MANIFEST + SNAP-MTIME
- **v1.4.0**: CodeQL `go/path-injection` hardening in `removeModule`
  (see §5.34)
- **v1.4.0**: iOS-specific PWA code removed (see §5.35)
- **v1.4.0**: `/app-debug.apk` route is **public** (no auth) —
  acceptable because the file contains no secrets
- **v1.5.0**: **One-shot CSRF token** on
  `POST /api/install_companion_app` — 60 s TTL, consumed on first
  use, issued by `GET /api?action=install_token`. See §5.36.1.
- **v1.5.0**: **Per-IP rate limit** on
  `POST /api/install_companion_app` — 5 failed attempts / 15 min
  lockout, using a dedicated `installAttempts` map (separate from
  `loginAttempts`). See §5.36.2.
- **v1.5.0**: **SELinux staging** — the APK is copied to
  `/data/local/tmp/dnscrypt-companion.apk` (context
  `shell_data_file`) before the install. **`setenforce 0` is
  never called.** See §5.36.3.
- **v1.5.0**: **Play Protect temporary disable + trap-based
  restore** — the package verifier is disabled for the duration
  of the cascade and restored on any exit path (normal, error,
  SIGINT, SIGTERM). The cascade is bounded by a **75-second
  deadline** so the trap always fires inside `main.go`'s
  90-second `INSTALL_TIMEOUT`. The trap restores the exact
  captured value (`$_VERIFIER_ORIG`) rather than a hardcoded
  `1`. See §5.36.4.

---

## 4. Assets & Trust Boundaries

### 4.1 Trust Boundaries

```text
┌───────────────────────────────────────────────────────────────┐
│  Untrusted Zone                                               │
│  ┌──────────────────────────────────────────────────┐         │
│  │  User Apps (Chrome, Games)                       │         │
│  └───────────────────────┬──────────────────────────┘         │
│                          │ :53 DNS                            │
│  ┌───────────────────────▼──────────────────────────┐         │
│  │  Trust Boundary 1: Firewall                      │         │
│  │  (iptables IPv4 / ip6tables IPv6)                │         │
│  │  ┌────────────────────────────────────────────┐  │         │
│  │  │  OUTPUT (nat) — clean                      │  │         │
│  │  │    ├─ jump DNSCRYPT_OUT                    │  │         │
│  │  │    └─ jump DNSCRYPT_OUT6                   │  │         │
│  │  │                                            │  │         │
│  │  │  DNSCRYPT_OUT (custom chain)               │  │         │
│  │  │    ├─ RETURN (loopback + bootstrap)        │  │         │
│  │  │    └─ DNAT → 127.0.0.1:5354                │  │         │
│  │  │                                            │  │         │
│  │  │  DNSCRYPT_OUT6 (custom chain)              │  │         │
│  │  │    ├─ RETURN (IPv6 loopback)               │  │         │
│  │  │    └─ DNAT → [::1]:5354                    │  │         │
│  │  └────────────────────────────────────────────┘  │         │
│  └───────────────────────┬──────────────────────────┘         │
│                          │ 127.0.0.1:5354                     │
│  ┌───────────────────────▼──────────────────────────┐         │
│  │  Trusted Zone (WebUI)                            │         │
│  │  ┌────────────────────────────────────────────┐  │         │
│  │  │  main.go :9090, :9091                      │  │         │
│  │  │  + Auth, Rate limit, CSP                   │  │         │
│  │  │  + CSRF (POST-only)                        │  │         │
│  │  │  + Cookie-only sessions                    │  │         │
│  │  │  + STATUS_FILE = "user intent"             │  │         │
│  │  │  + hasEndpoint (exact match)               │  │         │
│  │  │  + Basic Auth rate limit                   │  │         │
│  │  │  + Login POST-only (NEW-1)                 │  │         │
│  │  │  + /readyz localhost-only (NEW-4)          │  │         │
│  │  │  + shellQuote (NEW-5, extended v1.1.0)     │  │         │
│  │  │  + readConfPort range (NEW-3)              │  │         │
│  │  │  + auth cache 60 s (NEW-6)                 │  │         │
│  │  │  + rebuildMu mutex (RACE-1)                │  │         │
│  │  │  + runtime_info ports (PORT-2)             │  │         │
│  │  │  + MEM-1 memory limit (v1.1.0)             │  │         │
│  │  │  + MEM-3 monitoring port (v1.1.0)          │  │         │
│  │  │  + backupMu mutex (v1.2.0)                 │  │         │
│  │  │  + watchdog token (v1.2.0)                 │  │         │
│  │  │  + createAutoBackup (v1.2.0)               │  │         │
│  │  │  + removeModule CodeQL (v1.4.0)            │  │         │
│  │  │  + /app-debug.apk route (v1.4.0)           │  │         │
│  │  │  + install token (v1.5.0)                  │  │         │
│  │  │  + installAttempts limiter (v1.5.0)        │  │         │
│  │  │  + companionStateCache (v1.5.0)            │  │         │
│  │  └────────────────────────────────────────────┘  │         │
│  └───────────────────────┬──────────────────────────┘         │
│                          │ exec                               │
│  ┌───────────────────────▼──────────────────────────┐         │
│  │  Trust Boundary 2: Shell Scripts (root)          │         │
│  │  + getSystemShell() fallback (Fix #2)            │         │
│  │  + shellQuote() for dynamic paths                │         │
│  │  + copy_with_context (v1.2.0)                    │         │
│  │  + 10 defensive layers (v1.2.0)                  │         │
│  │  + §[8a] + §[9b2] (FIX-1, v1.2.0)                │         │
│  │  + install_app.sh (v1.5.0)                       │         │
│  │    + SELinux staging (never setenforce)          │         │
│  │    + Play Protect disable + 3-way trap           │         │
│  │    + 75 s cascade deadline                       │         │
│  │    + 5-level cascade                             │         │
│  │    + EXIT/INT/TERM traps, exit 130 / 143         │         │
│  └───────────────────────┬──────────────────────────┘         │
│                          │ copy/restore                       │
│  ┌───────────────────────▼──────────────────────────┐         │
│  │  Trust Boundary 3: Persistent Backup             │         │
│  │  /sdcard/dnscrypt-webui-backup/                  │         │
│  │  + mode 0700 / 0600                              │         │
│  │  + SHA256 manifest (advisory)                    │         │
│  │  + transactional txn-* / orphan-txn-*            │         │
│  │  + apk/ mirror (v1.5.0)                          │         │
│  └──────────────────────────────────────────────────┘         │
└───────────────────────────────────────────────────────────────┘
```

### 4.2 Assets

| Asset | Location | Sensitivity |
|---|---|---|
| Username/password | `dnscrypt-proxy.toml` | High |
| Session tokens | memory (only) | Medium |
| Blocklist | `blocklist.txt` | Low |
| Allowlist/Denylist | `*.txt` | Medium |
| Logs | `/data/local/tmp/*.log` | Medium |
| Credentials (cached) | `/data/local/tmp/dnscrypt_credentials.txt` | High |
| PIDs | `run/*.pid` | Low |
| STATUS_FILE | `run/dnscrypt.status` | Medium |
| Firewall chains | kernel memory | Medium |
| Auth cache | memory (60 s TTL) | Medium |
| Rebuild mutex | memory | Low |
| Memory limit state | memory (per-profile) | Low (v1.1.0) |
| Watchdog token | `$RUN_DIR/.watchdog_token` (mode 0600) | High (v1.2.0) |
| Persistent backups | `/sdcard/dnscrypt-webui-backup/` | High (v1.2.0) |
| Backup manifest | `<snap>/.manifest.json` | Medium (v1.2.0) |
| `.last_stable` pointer | `/sdcard/dnscrypt-webui-backup/.last_stable` | Low (v1.2.0) |
| `.upgrade_history.json` | `/sdcard/dnscrypt-webui-backup/.upgrade_history.json` | Medium (v1.2.0) |
| `txn-*` / `orphan-txn-*` | `/sdcard/dnscrypt-webui-backup/` | High (v1.2.0) |
| `.recovery_snapshot/` (transient) | `$MODPATH/.recovery_snapshot/` | High (v1.2.0) |
| Optional companion APK | `/data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk` | Low (public; no secrets) |
| **`installTokens` (v1.5.0)** | **memory (map, 60 s TTL, one-shot)** | **High while valid** |
| **`installAttempts` (v1.5.0)** | **memory (map, per-IP counters)** | **Low** |
| **`companionStateCache` (v1.5.0)** | **memory (30 s TTL)** | **Low** |
| **`$PERSISTENT_BACKUP/apk/` (v1.5.0)** | **`/sdcard/dnscrypt-webui-backup/apk/`** | **Low (public APK + SHA256)** |

---

## 5. Attack Vectors & Mitigations

### 5.1 Unauthorized Access

- **Vector**: malicious app tries to access the API.
- **Mitigation**:
  - Binding 127.0.0.1
  - Basic Auth / Bearer / Cookie
  - Constant-time comparison
  - Rate limiting (includes Basic Auth)

### 5.2 CSRF — Comprehensive Fix (Audit Correction #13)

**Background**:
In older versions, `toggle` and `restart` endpoints were accessible
via GET. `SameSite=Lax` sends cookies on top-level GET navigation,
allowing CSRF:

```html
<a href="http://127.0.0.1:9090/api?action=toggle">
  Click here!
</a>
```

**Solution**:

| Endpoint | Before | After |
|---|---|---|
| toggle | GET | POST `/api/toggle_service` |
| restart | GET | POST `/api/restart_service` |
| ensure_running | GET | POST `/api/ensure_running_service` |
| login | GET or POST | POST only |
| logout | GET or POST | POST only |
| install_companion_app (v1.5.0) | n/a (new) | POST only + one-shot token |
| install_token (v1.5.0) | n/a (new) | GET — token issuance only; the token itself is one-shot |

- State-changing endpoints → POST only.
- Read-only endpoints (status, logs) → GET (idempotent).
- 405 Method Not Allowed with `Allow: POST` header (RFC 7231).
- PWA shortcuts still work (top-level GET).

### 5.3 Path Traversal

- **Vector**: `GET /../../etc/passwd`.
- **Mitigation**:
  - `serveStaticAssets` whitelist
  - No `filepath.Join(MODDIR, "web", r.URL.Path)`

### 5.4 XSS

- **Vector**: allowlist contains `<script>`.
- **Mitigation**:
  - `escapeHtml()` on every output
  - CSP `script-src 'self'` (with `'unsafe-inline'` — §6.4)
  - `textContent` instead of `innerHTML` where user data is rendered

### 5.5 SQL / Command Injection

- **Vector**: `param=; rm -rf /`.
- **Mitigation**:
  - No SQL (no database)
  - `exec.Command` is called without a shell
  - `runShell` is limited to fixed commands
  - Path whitelist
  - `limitedBuffer` captures stderr
  - **`shellQuote()`** — v1.0.0, extended in v1.1.0
  - **v1.2.0**: `copy_with_context` uses `shellQuote` for all
    dynamic paths (backup restore)
  - **v1.5.0**: `install_app.sh` uses `shellQuote()` on all paths
    and a hardcoded APK path. See §5.36.

### 5.6 Brute Force

- **Vector**: 10,000 login attempts.
- **Mitigation**:
  - 5 attempts / IP / 15 min
  - Intentional delay
  - `LOGIN_ATTEMPT_STALE_PERIOD = 1 h`
  - **Fix #8**: includes Basic Auth (was unlimited)
  - **v1.5.0**: separate per-IP limiter for the install endpoint
    (5 **failed** attempts / 15 min; success resets the counter).
    See §5.36.2.

### 5.7 Memory Exhaustion

- **Vector**: POST 1 GB to `/api/save_allowlist`.
- **Mitigation**:
  - `MaxBytesReader(5 MB)`
  - `io.LimitReader(50 MB)` for downloads
  - `limitedBuffer` (2048 bytes) for stderr capture

- **v1.1.0 addition — GC pressure as a DoS vector**:
  - Prior to v1.1.0, `debug.SetMemoryLimit(80 MB)` was hardcoded.
    On the `ultimate` profile, this caused GC thrashing.
  - v1.1.0 replaces the hardcoded value with a per-profile limit
    set by `memoryLimitForProfile()`:
    light=80 MB, normal=100, pro=120, proplus=160, ultimate=220.

- **v1.2.0 addition — bounded backup disk usage**:
  - Rotation caps the number of snapshots at 21.
  - Each snapshot uses ~30–100 KB → total footprint ~2.5 MB max.

- **v1.5.0 addition — install endpoint CPU + I/O cost**:
  - A single `pm install` cascade forks up to 5 subprocesses and
    performs a 3 MB copy + SHA256 hash.
  - The per-IP rate limit (5 / 15 min) caps the aggregate cost
    an attacker can impose.

### 5.8 Timing Attacks

- **Vector**: measure response time to guess the password.
- **Mitigation**:
  - Use `subtle.ConstantTimeCompare`
  - **v1.2.0**: watchdog token comparison also uses
    `subtle.ConstantTimeCompare`
  - **v1.5.0**: install token comparison also uses
    `subtle.ConstantTimeCompare` (see §5.36.1)

### 5.9 DNS Leak (Audit Correction #3 + #16)

**Background**:
dnscrypt-proxy queries `bootstrap_resolvers` directly on port 53 to
download the server list. If they are not excluded from DNAT, a loop
occurs:
- packet leaves → DNAT → 127.0.0.1:5354 → dnscrypt-proxy → loop.

**Solution applied**:
- 3-e: `awk` reads multi-line TOML.
- 3-f: IPv6 support in `get_dynamic_bootstrap`.
- 16-a: `manage_iptables` skips IPv6 (`case "$_ip" in *:*) continue`).
- 16-b: `manage_ip6tables` uses `::1` + `$BOOTSTRAP_IPS` with IPv4
  filtering.

**Result**:

| Protocol | Firewall | Bootstrap handling |
|---|---|---|
| IPv4 | iptables | ✅ (with IPv6 filtering) |
| IPv6 | ip6tables | ✅ (with IPv4 filtering) |
| Any | nftables | ✅ (case filter) |

### 5.10 SSE DoS (Slow Client)

- **Vector**: 10,000 SSE connections with slow consumption to freeze
  the server.
- **Mitigation**: `SetWriteDeadline(30 s)` before each flush.
  Slow clients are disconnected.

### 5.11 Token Leakage (Audit Correction #15-a)

- **Vector**: XSS can read the token from a JSON response or JS
  storage.
- **Mitigation**:
  - No `sessionStorage` for session tokens
  - No token in login response
  - HttpOnly cookie only

### 5.12 405 Method Not Allowed — RFC Compliance (Audit Correction #15-b)

- **Vector**: non-compliance with RFC 7231 §6.5.5.
- **Mitigation**:
  - `Allow: POST` header on 405
  - `Allow: GET, POST, OPTIONS` on OPTIONS response

### 5.13 Firewall Orphan Leak (Audit Correction #17)

**Background**:
The original release added dynamic RETURN rules directly to the public
OUTPUT chain. When `bootstrap_resolvers` changed, old RETURN rules were
left behind.

**Solution (Custom Chains)**:
- `DNSCRYPT_OUT` (IPv4) and `DNSCRYPT_OUT6` (IPv6) in `functions.sh`.
- `_inline_cleanup_firewall` unified in 3 files (`post-fs-data.sh`,
  `uninstall.sh`, `customize.sh`).
- `_legacy_cleanup_*` for upgrades from older versions (best-effort).

**Golden rule**:
Never pollute a public chain (OUTPUT/INPUT/FORWARD) with dynamic rules.
Use a dedicated Custom Chain — deleting it wipes all its rules.

### 5.14 State Integrity — STATUS_FILE Semantics (Audit Correction #18)

**Background**:
`STATUS_FILE` was written by `getStatusUncached` and by
`startService`/`stopService`. This conflict lost the "user intent"
meaning on crash.

**Solution**: `STATUS_FILE` is **read-only** with respect to
`getStatusUncached` — written only by `startService` / `stopService`.

**Architectural contract**:

| Question | Answer |
|---|---|
| Meaning of STATUS_FILE | "User intent" |
| Who writes it? | `startService` / `stopService` only |
| Who reads it? | `getStatus`, Watchdog, `status.sh` |
| What happens on crash? | `STATUS_FILE` stays "ON" → Watchdog restarts |

### 5.15 IPv6 Rate Limit Bypass (Audit Correction #19)

**Solution**: `getClientIP(r)` uses `net.SplitHostPort` — IPv6
addresses like `[::1]:port` map to `::1` (not `[`).

### 5.16 Port Collision (Audit Correction #20)

**Solution**: `MONITORING_UI_PORT` constant. `main.go` refuses to
start if `PORT` or `DASHBOARD_PORT` = 8080.

**v1.1.0 addition**: `metricsProxyHandler` uses the constant —
no more hardcoded `"8080"` (see §5.30.3).

### 5.17 TOML Parsing — Section Injection (Audit Correction #21)

**Solution**: Section tracking (`inSection` boolean) in all 4 files
(`main.go`, `functions.sh`, `watchdog.sh`, `customize.sh`).

### 5.18 Basic Auth Rate Limit Bypass (Fix #8 / Audit #22)

**Solution**: `checkAuth` now records failed Basic Auth attempts in
`loginAttempts`. 5 attempts / 15 min lockout per IP.

### 5.19 Section Header with Comment (parsing) (Fix #10 / Audit #23)

**Solution**: Section detection uses `strings.Index(trimmed, "]")`
instead of `HasSuffix("]")` — supports `[monitoring_ui] # comment`.

### 5.20 Dashboard JSON Conversion (Fix #1 / Audit #25)

**Solution**: `parsePrometheus()` + `buildDashboardJSON()` convert
Prometheus text to JSON.

### 5.21 Preserve User Settings on Upgrade (Fix #3 / Audit #26)

**v1.0.0 solution**: Backup/restore around `unzip -o` for the 5
config files (mechanism: `/data/local/tmp/dnscrypt-upgrade-backup-$$`).

**v1.2.0 supersession**: The v1.0.0 mechanism is **superseded** by the
10 defensive layers documented in §5.31.

### 5.22 `fuser` PID Parsing (Fix #9 / Audit #27)

**Solution**: `fuser -n tcp "$port" | tr ' ' '\n' | grep -E '^[0-9]+$'
| head -n1` — one PID per line, numbers only.

### 5.23 Login POST-Only (Fix NEW-1 / Audit #28)

**Solution**: `/api/auth/login` and `/api/auth/logout` reject non-POST
requests with 405 + `Allow: POST`.

### 5.24 `readConfPort` Range Check (Fix NEW-3 / Audit #29)

**Solution**: `readConfPort` validates range `[1, 65535]`.

### 5.25 `/readyz` Localhost-Only (Fix NEW-4 / Audit #30)

**Solution**: `handleReadyz` rejects non-localhost requests with
`{"error": "readyz is localhost-only"}`.

### 5.26 `shellQuote` Injection Protection (Fix NEW-5 / Audit #31)

**v1.0.0**: 20-character escape set.
**v1.1.0**: Extended to 24 characters — see §5.30.2.

### 5.27 Auth Cache (60 s) (Fix NEW-6 / Audit #32)

**Solution**: `getMonitoringAuth` caches credentials in memory for 60
seconds. Empty results are **never** cached.

### 5.28 Rebuild Blocklist Mutex (RACE-1) (Audit #33)

**Solution**: `rebuildMu sync.Mutex` protects the entire
`rebuildBlocklist` function.

**v1.2.0 parallel**: `backupMu` uses the same pattern for
`createAutoBackup` — see §5.31.3.

### 5.29 Runtime Info Ports (PORT-2)

**Solution**: `buildRuntimeInfo()` returns `webui_port` +
`dashboard_port`. Frontend uses `window.location.hostname` to build
links dynamically.

### 5.30 v1.1.0 — Security-Relevant Runtime Changes

**v1.1.0 does not add new audit corrections.** It is a documentation
+ polish release. However, three runtime changes have a
security-relevant dimension and are documented here for completeness.

#### 5.30.1 Dynamic Memory Limit per Profile (MEM-1)

**Background**:

```go
// Before v1.1.0 (main.go, top of main()):
debug.SetMemoryLimit(80 * 1024 * 1024)  // ← hardcoded 80 MB
```

**Problem**: On the `ultimate` profile, the working set exceeds 80 MB
during `rebuildBlocklist`. The Go runtime runs GC continuously → CPU
waste → WebUI appears frozen on low-RAM devices.

**Solution**:

```go
// After v1.1.0:
const (
    MEMORY_LIMIT_LIGHT     = 80 * 1024 * 1024
    MEMORY_LIMIT_NORMAL    = 100 * 1024 * 1024
    MEMORY_LIMIT_PRO       = 120 * 1024 * 1024
    MEMORY_LIMIT_PROPLUS   = 160 * 1024 * 1024
    MEMORY_LIMIT_ULTIMATE  = 220 * 1024 * 1024
    MEMORY_LIMIT_DEFAULT   = 80 * 1024 * 1024
)

func memoryLimitForProfile(key string) int64 { /* ... */ }
func applyMemoryLimit(key string) { /* ... */ }
```

**Called from**:
- `main()` at startup.
- `updateProfile()` on profile change.

**Impact**:

| Profile | Before v1.1.0 | After v1.1.0 |
|---------|:---:|:---:|
| light | 80 MB | 80 MB |
| normal | 80 MB | 100 MB |
| pro | 80 MB | 120 MB |
| proplus | 80 MB | 160 MB |
| ultimate | 80 MB (GC thrashing) | 220 MB |

**Observability**: `runtime_info` exposes `memory_limit_mb` and
`profile_key`.

**Security rationale**: Removes a self-inflicted DoS surface.

#### 5.30.2 Extended `shellQuote` Character Set (MEM-2)

**Background**:

The v1.0.0 `shellQuote` escaped 20 shell-significant characters. Four
were not escaped: `{`, `}`, `\n`, `\t`.

**Practical impact today**: `MODDIR` is derived from
`os.Executable()`. A normal user cannot make it contain `{` or `\n`.
No known exploitable path exists.

**Solution**: Extend the set to 24 characters.

**Security rationale**: Defense-in-depth.

#### 5.30.3 `MONITORING_UI_PORT` in Metrics Handler (MEM-3)

**Background**: `metricsProxyHandler` had a hardcoded `"8080"`.

**Solution**:

```go
// After v1.1.0:
monitoringURL := "http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"
```

**Security rationale**: Single source of truth.

### 5.31 v1.2.0 — Data Preservation Security Model

> **ℹ️ Section numbering note**: §5.31 is a **section number in this
> document**, not an Audit Correction number. The Audit Corrections
> Registry (§17) remains at **#33**.

**Background**: Prior to v1.2.0, the installer used a path-comparison
check that silently failed on in-place upgrades → silent data loss.

**v1.2.0 Solution — the 10 defensive layers**:

| # | Layer | File(s) | Role |
|:-:|---|---|---|
| 1 | Multi-source detection | `customize.sh` | Search 7 candidate locations for user data |
| 2 | Persistent backup | `customize.sh`, `functions.sh` | Snapshot to `/sdcard/dnscrypt-webui-backup/` |
| 3 | SHA256 integrity verification | `customize.sh`, `functions.sh` | Advisory per-file checksum |
| 4 | Transactional upgrades | `customize.sh` | Atomic install with rollback |
| 5 | Root-solution compatibility | `customize.sh` | Magisk / KernelSU / APatch |
| 6 | SELinux preservation | `customize.sh`, `functions.sh` | `restorecon` / `chcon` |
| 7 | Recovery mode | `customize.sh` | Trigger file restore |
| 8 | Config migrations | `customize.sh` | Version-aware transforms |
| 9 | Automation + rotation | `service.sh`, `main.go` | Periodic + pre-critical backups |
| 10 | Observability | `status.sh`, `main.go` | `.upgrade_history.json` + 7-field `backups` |

#### 5.31.1 Multi-Source Detection (Layer 1)

The installer searches **7 candidate locations** for the 5 user config
files (9 on APatch).

**Selection rule**: The first candidate with **≥ 3 valid files** wins.

#### 5.31.2 Persistent Backup (Layer 2)

**Location**: `/sdcard/dnscrypt-webui-backup/`.

**Permissions**:

| Path | Mode | Owner |
|---|:---:|:---:|
| `/sdcard/dnscrypt-webui-backup/` | `0700` | root |
| Snapshot directories | `0700` | root |
| Snapshot files | `0600` | root |
| `.manifest.json` | `0600` | root |
| `.last_stable` | `0600` | root |
| `.upgrade_history.json` | `0600` | root |
| `README.md` | `0644` | root |
| `apk/` (v1.5.0) | `0755` | root |
| `apk/app-debug.apk` (v1.5.0) | `0644` | root |
| `apk/app-debug.apk.sha256` (v1.5.0) | `0644` | root |

> **Note**: the `apk/` mirror directory is created by
> `customize.sh §[10c]` via `mkdir -p` without an explicit mode
> argument, so its effective mode is the process umask default
> (**`0755`** in the module's install context).

**Rotation (v1.3.0 — ROT-MANIFEST + ROT-MTIME + ROT-PROTECT)**:
Keep the 21 newest snapshots with manifest-based detection, mtime
sort, and two protected targets (`.last_stable` + newest install).

**v1.5.0 addition — `apk/` mirror exclusion**: the `apk/` subfolder
is preserved by **two independent mechanisms**:
  1. It lacks a `.manifest.json` (so ROT-MANIFEST excludes it).
  2. It is explicitly listed in the `case` skip inside
     `rotate_backups()` — `current|txn-*|orphan-txn-*|apk`.

#### 5.31.3 `backupMu` Serialization (BAK-2)

**Purpose**: Serialize pre-critical backups.

**Implementation**:

```go
var backupMu sync.Mutex

func createAutoBackup(reason string) {
    backupMu.Lock()
    defer backupMu.Unlock()
    // ... runShellWithTimeout(..., 15*time.Second) ...
}
```

**Rationale**: Prevents concurrent snapshot corruption.

#### 5.31.4 Integrity Verification (Layer 3)

**Checks**:
1. **Non-empty**: File exists and has size > 0.
2. **Not oversized**: File size < 10 MB.
3. **SHA256 (advisory)**: `.manifest.json` records each file's hash.
   A mismatch is **logged as a warning** but does **not** block a
   restore.
4. **Manifest presence (v1.3.0 — SNAP-MANIFEST)**: a directory must
   contain a `.manifest.json` file to be counted as a snapshot.

**Why advisory**: The snapshot was just created from the same source.
Refusing to restore would be worse than restoring with a warning.

#### 5.31.5 Transactional Upgrade (Layer 4)

**State machine**: `START` / `COMMIT` / `ROLLBACK`.

**Behavior**: automatic rollback on failure; leftover COMMIT'd
transactions cleaned at startup.

#### 5.31.6 SELinux Context Preservation (Layer 6)

**Preferred**: `restorecon`.

**Fallback**: `chcon u:object_r:magisk_file:s0`.

#### 5.31.7 Language Toggle — Security Considerations

The bilingual feature (English default + Arabic toggle) is a
**client-side only** concern. No server state, no new network
requests, no SW cache pollution, no XSS regression, no CSP change.

#### 5.31.8 Data-Preservation Threat Model Summary

The backup system assumes: rooted device, `/sdcard/` writable by root,
**not** protected from a malicious root app. `backupMu` guarantees two
concurrent `createAutoBackup` calls cannot corrupt a snapshot.

### 5.32 v1.2.0 — Correctness Fixes (FIX-1, FIX-2)

> **ℹ️ Section numbering note**: §5.32 is a **section number in this
> document**, not an Audit Correction number.

**Neither FIX-1 nor FIX-2 is an exploitable vulnerability.**

#### 5.32.1 Recovery Mode Correctness Fix (FIX-1)

**The bug**: ZIP extraction step overwrote `webui.conf` and
`dnscrypt-proxy.toml` after the recovery restore.

**The fix (FIX-1) — snapshot-and-reapply strategy**:

| Phase | Section | What happens |
|---|---|---|
| **A** | `§[8a]` | Restore 5 files + snapshot to `$MODPATH/.recovery_snapshot/` |
| **B** | `§[9]` | Extract the ZIP normally |
| **C** | `§[9b]` | Move root-level web assets into `web/` |
| **D** | `§[9b2]` | Re-apply the 5 files from the snapshot |
| **E** | `§[9c]` | Skipped when `RECOVERY_MODE=1` |

**Verify**:

```bash
su -c "grep -q 'RECOVERY_SNAPSHOT_DIR' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ FIX-1 present (snapshot dir)'"
su -c "grep -q 'Re-applying recovery snapshot' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ FIX-1 present (§[9b2] re-apply block)'"
```

#### 5.32.2 Service Worker Update-Banner Fix (FIX-2)

**The bug (v1.1.0)**: The [Reload] button sent `SKIP_WAITING` to the
wrong worker → infinite loop.

**The fix (v1.2.0)**:
- Send `SKIP_WAITING` to `swRegistration.waiting` (the **new** worker).
- Reload on `controllerchange`.
- Guard double-clicks with `pendingReload` flag.

### 5.33 v1.2.0 — Watchdog Token (WD-TOKEN)

> **ℹ️ Section numbering note**: §5.33 is a **section number in this
> document**, not an Audit Correction number.

**Background**: The `ensure_running_service` endpoint was protected
only by an implicit "localhost bypass" — exploitable via CSRF.

**v1.2.0 solution — token authentication**:

- **Localhost-scoped**: `isLocalRequest` is still required.
- **Constant-time**: `subtle.ConstantTimeCompare`.
- **Not rate-limited**: a flapping DNS engine does not lock the
  watchdog out.
- **Persistent**: the token file survives restarts.
- **Fail-closed**: if the token file is missing and no token is sent,
  the request falls back to normal user auth.

### 5.34 v1.4.0 — CodeQL `go/path-injection` Fix in `removeModule`

> **ℹ️ Section numbering note**: §5.34 is a **section number in this
> document**, not an Audit Correction number.

**Background**: CodeQL flagged two `go/path-injection` alerts.

**v1.4.0 solution**:

```go
name := filepath.Base(modulePath)
if name == "" || name == "." || name == ".." ||
    name == string(filepath.Separator) {
    return map[string]interface{}{"status": "error", "message": "Invalid module name"}
}
expectedPrefix := MODULES_DIR + string(filepath.Separator)
if !strings.HasPrefix(filepath.Clean(modulePath), expectedPrefix) {
    return map[string]interface{}{"status": "error", "message": "Invalid path"}
}
cleanPath, err := securejoin.SecureJoin(MODULES_DIR, name)
if err != nil {
    return map[string]interface{}{"status": "error", "message": "Invalid path"}
}
```

**Why this closes the alerts**:
- `filepath.Base` is a CodeQL-recognized sanitizer.
- `securejoin.SecureJoin` combines a trusted base directory with a
  sanitized basename, and refuses any path that would escape the base.
- The `expectedPrefix` check is defence-in-depth.

### 5.35 v1.4.0 — iOS PWA Removal + Companion APK Route

> **ℹ️ Section numbering note**: §5.35 is a **section number in this
> document**, not an Audit Correction number.

#### 5.35.1 iOS PWA Logic Removal

**Security rationale**: Android-only project → iOS branches were dead
code. Removing them reduces surface.

**Verify**:

```bash
# Anchored match avoids false positives from comments that merely
# mention the string "isIOSDevice".
su -c "grep -qE '^\s*(function isIOSDevice|isIOSDevice\s*=)' \
    /data/adb/modules/dnscrypt-proxy-webui/web/index.html && \
    echo '❌ still present' || echo '✅ removed'"
```

#### 5.35.2 Companion APK Route (v1.4.0)

**Route**: `GET /app-debug.apk`.

**Authentication**: None (public).

**Why no auth**: no secrets; Android signature-verifies at install.

### 5.36 v1.5.0 — Companion App Install Security (APK-5, APK-11)

> **ℹ️ Section numbering note**: §5.36 is a **section number in this
> document**, not an Audit Correction number.

**Background**: v1.5.0 replaces the direct `<a download>` link
(v1.4.0) with a **root-level install** that runs `install_app.sh` — a
5-level `pm install` cascade. The operation is **privileged**,
**irreversible in the current request** (the app remains installed),
and **triggered from a browser origin** — three properties that make
a dedicated security model necessary.

> **Layout note**: `install_app.sh` is staged at the **module root**
> (next to `customize.sh`), not under `proxy/`. The path is resolved
> by `main.go`'s `getInstallScript()` via
> `filepath.Join(MODDIR, INSTALL_SCRIPT_REL)`.

#### 5.36.1 One-Shot CSRF Token

**Purpose**: Prevent an attacker who can load a page in a browser on
the same device from triggering an install on the user's behalf.

**Mechanism**:

1. `GET /api?action=install_token` — requires a valid session.
   Returns `{ "token": "<64 hex>", "ttl": 60 }`.
2. The token is stored server-side in the `installTokens` map with an
   expiry of `now + INSTALL_TOKEN_TTL` (60 s).
3. The token is **consumed on first use**:
   `validateAndConsumeInstallToken(token)` deletes it from the map on
   success. A retry of the same token returns
   `401 Invalid or expired install token`.
4. Tokens are garbage-collected lazily — expired entries are removed
   when the next `generateInstallToken()` runs. Server restart clears
   the map (tokens are 60 s by design).

**Why a separate token (not just the session cookie)**:
- The install endpoint has **side effects that outlive the session** —
  the app remains installed after logout.
- The session cookie is long-lived (24 h). A one-shot token forces an
  explicit per-request consent.
- CSRF exploitation becomes impractical: an attacker cannot know or
  guess a 64-hex random token, and the token is invalidated on the
  first use.

**Why 60 seconds**: generous enough for a slow user, short enough that
a leaked token (e.g. via a screenshot) is unlikely to still be valid.

**Why not cache tokens across requests**: each click on "Install App"
generates a fresh token. Reusing a token across multiple clicks would
let a hijacked tab perform multiple installs without the user's
consent.

**Token comparison**: constant-time (`subtle.ConstantTimeCompare`).

**Token file location**: none — the token store is in-memory only.
Unlike the watchdog token (§5.33), the install token is not persisted
to disk.

#### 5.36.2 Per-IP Install Rate Limit

**Purpose**: Prevent an attacker from forcing repeated `pm install`
runs (each one forks up to 5 subprocesses and performs a 3 MB copy +
hash).

**Parameters**:

| Parameter | Value | Constant |
|---|---|---|
| Attempts | 5 | `MAX_INSTALL_ATTEMPTS` |
| Lockout | 15 minutes | `INSTALL_LOCKOUT_PERIOD` |
| Per | IP (IPv6-safe via `getClientIP`) | — |

**Separate map**: `installAttempts` is **distinct** from
`loginAttempts`. A failed login does not affect the install counter
and vice versa.

**Success reset**: a successful install resets the counter for that IP.

**Lockout response**:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json

{
  "status": "error",
  "action": "install",
  "message": "Too many install attempts. Try again in 15 minutes."
}
```

**Rationale for the limit choice**: mirrors the login rate limit for
consistency. The two limits serve different purposes (login =
credential guessing; install = resource exhaustion) but the same
parameters are sufficient for both.

#### 5.36.3 SELinux Staging

**The problem**: `/data/adb/` has the SELinux context `adb_data_file`.
The `system_server` process — which performs the install — **cannot
read** files with this context. Attempting
`pm install /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk`
produces:

```
avc: denied { read } for pid=... name="app-debug.apk" scontext=u:r:system_server:s0 ...
```

**The fix**:

```sh
STAGING_DIR="/data/local/tmp"
STAGING_APK="$STAGING_DIR/dnscrypt-companion.apk"

cp "$APK_PATH" "$STAGING_APK" 2>/dev/null
chmod 0644 "$STAGING_APK" 2>/dev/null
```

`/data/local/tmp/` has the context `shell_data_file`, which
`system_server` **can** read.

**Critically**: SELinux is **never disabled**. The script does not
call `setenforce 0`. The staging directory is world-readable on most
ROMs; the APK itself is a public asset.

**What this decision trades off**:

| Option | SELinux state during install | Attack window | Chosen? |
|---|---|---|---|
| `setenforce 0` for the duration | Disabled | Any crash leaves the device unprotected | ❌ |
| `chcon` the module directory | Enforcing | Changes the module's own context; fragile | ❌ |
| Stage to `/data/local/tmp/` | Enforcing | 3 MB copy, ~1 s; world-readable path | ✅ |
| Bind-mount elsewhere | Enforcing | Requires a mount namespace | ❌ |

**Why staging is the right trade-off**:
- The APK is a **public** asset — its exposure on a world-readable
  path is not a confidentiality issue.
- `pm install` reads the file synchronously; the file is removed on
  exit by the trap (see below).
- The alternative (`setenforce 0`) opens a device-wide vulnerability
  window that violates the module's own security goal (protected DNS).

**Cleanup**: `install_app.sh` §[12] installs a trap that **removes**
the staged APK (`/data/local/tmp/dnscrypt-companion.apk`) on **every**
catchable exit path.

**Trap structure (CIA-DEF-03)**: the trap is split into **three
separate handlers** with a `_CLEANED_UP` re-entry guard:

```sh
_CLEANED_UP=0

_cleanup_app() {
    if [ "$_CLEANED_UP" = "1" ]; then
        return 0
    fi
    _CLEANED_UP=1

    if [ "$_STAGED_OK" = "1" ] && [ -f "$STAGING_APK" ]; then
        rm -f "$STAGING_APK" 2>/dev/null
    fi

    if [ "$_VERIFIER_RESTORE" = "1" ]; then
        settings put global package_verifier_enable "$_VERIFIER_ORIG" 2>/dev/null
    fi

    return 0
}

trap '_cleanup_app' EXIT
trap '_cleanup_app; exit 130' INT
trap '_cleanup_app; exit 143' TERM
```

**Why the split**:
- In POSIX sh, a trapped signal whose handler does **not** call `exit`
  causes the script to **resume execution** after the handler returns.
  The pre-patch single `EXIT INT TERM` handler cleaned up but did not
  exit, so on SIGINT the cascade loop continued — re-staging the APK
  and re-disabling Play Protect. A user pressing Ctrl+C in a direct
  CLI invocation had to press it twice more to actually stop the
  script.
- The post-patch `INT` handler calls `exit 130` immediately after
  cleanup; the `TERM` handler calls `exit 143`. Exit codes `130` and
  `143` follow the shell convention (`128 + signal number`) for
  signal-terminated processes.
- `_CLEANED_UP` is a re-entry guard so the cleanup body runs **exactly
  once**, even when the INT handler's `exit 130` causes the EXIT
  handler to fire (POSIX requires EXIT to fire on every exit path).

**Impact on the primary invocation path** (main.go via
`exec.CommandContext`): none. `main.go` sends SIGKILL after
`INSTALL_TIMEOUT` — SIGKILL is uncatchable, so neither the pre-patch
nor the post-patch trap is involved. The split only affects direct CLI
use (`su -c "sh install_app.sh"`).

**Race-free guarantee**: the removal is safe because `pm install`
**blocks** until it has finished reading the file. By the time the
trap fires (normal exit, error exit, SIGINT, or SIGTERM), the staged
APK is no longer needed by PackageManager. There is no window during
which a partial read could be interrupted by the removal.

#### 5.36.4 Play Protect Temporary Disable

**The problem**: Google Play Protect can silently block `pm install`
of an APK that did not originate from the Play Store. On many ROMs
the verifier runs synchronously and rejects the install without a
useful error.

**The fix**:

```sh
# Install the traps BEFORE any irreversible state change.
trap '_cleanup_app' EXIT
trap '_cleanup_app; exit 130' INT
trap '_cleanup_app; exit 143' TERM

_VERIFIER_ORIG=$(_read_verifier_state 2>/dev/null)

case "$_VERIFIER_ORIG" in
    "1")
        if settings put global package_verifier_enable 0 2>/dev/null; then
            _VERIFIER_RESTORE=1
            log_msg "INSTALL: Play Protect verifier disabled (will restore to 1)"
        fi
        ;;
    "0")
        log_msg "INSTALL: Play Protect verifier already disabled"
        ;;
    "null")
        if settings put global package_verifier_enable 0 2>/dev/null; then
            _VERIFIER_RESTORE=1
        fi
        ;;
    *)
        # Unreadable — do not touch it.
        _VERIFIER_RESTORE=0
        _VERIFIER_ORIG=""
        ;;
esac
```

The traps are installed **before** the `settings put`, so a signal
arriving in the tiny window between the read and the write is still
handled correctly.

**Duration**: the verifier is disabled only for the duration of the
cascade. The cascade is bounded by a **75-second wall-clock deadline**
(`CASCADE_DEADLINE_SECONDS = 75`). The deadline is deliberately
shorter than `main.go`'s 90-second `INSTALL_TIMEOUT`, so the trap
always fires before the parent process kills the script.

**Restore value**: the trap restores the **exact captured value**
(`$_VERIFIER_ORIG`), not a hardcoded `1`. On every normal ROM the
captured value is `1`, so the behaviour is unchanged — the change is
defence-in-depth against an uncommon configuration where the setting
is `null` or another value.

**Caveats**:

- **Not restored on force reboot** — `settings put` writes to the
  system settings database. If the device is **force-rebooted** during
  the install (e.g. hardware reset button), the
  `package_verifier_enable` value may remain `0` across reboots. This
  is a well-known transient state, and Google Play re-enables the
  verifier on the next Play Protect scan.
- **SIGKILL skips the trap** — SIGKILL is uncatchable by design
  (POSIX). The primary invocation path (`main.go` via
  `exec.CommandContext`) sends SIGKILL after `INSTALL_TIMEOUT`. The
  75-second cascade deadline exists precisely to ensure the trap
  fires before that point on every realistic install.
- **Well-behaved ROMs** — the verifier is disabled for the duration of
  the cascade (typically a few seconds; worst case bounded by the
  75-second deadline). The window is short enough that a concurrent
  malicious install is impractical.
- **Adversarial ROMs** — on a ROM where `settings put` is a no-op
  (some custom kernels), the disable has no effect and the install
  fails cleanly.

**Threat model coverage**:

| Threat | Mitigation |
|---|---|
| Play Protect blocks legitimate install | Temporary disable + restore |
| Disable persists after crash | `trap` covers normal + error + SIGINT/SIGTERM paths; cascade bounded by 75 s deadline |
| Disable persists across reboot | Documented; transient; Play Protect self-heals |
| Attacker triggers a second install while verifier is off | Rate limit (§5.36.2) + short window |
| Cascade hangs, verifier never restored | 75-second deadline ensures the loop terminates inside `INSTALL_TIMEOUT` |

#### 5.36.5 5-Level Cascade — Security Rationale

The cascade is:

1. `pm install -r --user 0 <apk>` — direct install.
2. `pm install -r -i com.android.shell <apk>` — shell-attributed.
3. Session-based (`install-create` + `install-write` + `install-commit`).
4. `magisk su -c "pm install -r <apk>"`.
5. `cmd package install -r <apk>`.

**All 5 levels are semantically equivalent** — they invoke the same
`PackageManager.installPackage` code path with different SELinux
domains and different caller capabilities. The choice of level does
not affect the security of the resulting installation; Android still
verifies the APK signature.

**Order rationale**:

| Level | Why this position |
|---|---|
| 1 | Simplest, works on most ROMs. Fastest to succeed. |
| 2 | Works where Level 1 is blocked by shell restrictions. |
| 3 | Works where direct installs are blocked by verification prompts. Same API Google Play uses. |
| 4 | Explicit Magisk `su` — works where `/system/bin/su` is not Magisk. |
| 5 | Modern shell entrypoint. Bypasses some legacy checks. |

**Attacker-controlled cascade failure**: a malicious ROM or a rogue
root app could break every level so that none succeeds. The result is
a failed install, not a compromised install. Android verifies the
package signature regardless of which level is used.

#### 5.36.6 Response Design — Failure is 200, Not 4xx

The `install_companion_app` endpoint returns:

- **HTTP 200** for both success and install failure.
  - Success: `{"status": "ok", "action": "install", ...}`.
  - Failure: `{"status": "error", "action": "install", "message_ar": "...", "message_en": "..."}`.
- **HTTP 401** for auth/token failure.
- **HTTP 403** for non-localhost.
- **HTTP 429** for rate limit.

**Why**: an install failure is a **valid outcome of a well-formed
request**. The WebUI needs to read the AR/EN message from the body to
display it. Only auth/rate-limit/token failures use 4xx.

**Security rationale**: this does not weaken the security model. The
distinction between success and failure is in the JSON body, not the
HTTP status. An attacker cannot use a 200 response to mask a forbidden
request — the auth check runs first.

#### 5.36.7 Package Name Candidates (APK-12)

The script tries **3 package name candidates** in order:

1. `com.gasciljh.dnsproxy.debug` (default)
2. `com.gasciljh.dnsproxy`
3. `com.gasciljh.dnscrypt_proxy` (legacy)

**Rationale**: the companion app has been released under multiple
package names across build variants. Trying all three means the WebUI
does not need to know the exact name.

**Security impact**: none. The candidate list is hardcoded in
`install_app.sh` — no user input is involved. Android verifies the
package signature regardless of the name.

**Verify**:

```bash
# BusyBox grep does not support \b as a word boundary (it treats it
# as a literal backspace). The check uses an explicit character-class
# boundary instead.
grep -q 'com.gasciljh.dnsproxy.debug' proxy/install_app.sh && echo "✅ candidate 1"
grep -qE 'com\.gasciljh\.dnsproxy([^.]|$)' proxy/install_app.sh && echo "✅ candidate 2"
grep -q 'com.gasciljh.dnscrypt_proxy' proxy/install_app.sh && echo "✅ candidate 3 (legacy)"
```

**Location note**: the candidate list is defined **only** in
`install_app.sh`. `main.go` does not maintain a parallel list. The
detected package name is returned to `main.go` inside the JSON payload
from `callInstallScript("status")`.

#### 5.36.8 SHA256 Verification (CIA-1)

**Behavior**: if `web/app-debug.apk.sha256` is present, the APK's
SHA256 is verified **before any install strategy is attempted**. If
the file is absent (local developer builds), the script degrades to
**advisory mode** — a warning is logged, but the install proceeds.

**Rationale for advisory mode**:
- The `.sha256` is staged by `release.yml` (v1.5.0). Dev builds do not
  have it.
- The APK is a **public** artifact fetched from a **public**
  repository. The SHA256 guards against a bit-flip during the release
  pipeline, not against an adversarial provider.
- Android verifies the **package signature** at install time, which is
  the ultimate integrity check.

**Threat model coverage**:

| Threat | Mitigation |
|---|---|
| Corrupted APK in module ZIP | SHA256 mismatch → install aborted |
| Missing `.sha256` in dev build | Advisory mode; Android signature still verified |
| Tampered APK in module ZIP | SHA256 mismatch (if `.sha256` present) OR Android signature mismatch (always) |

#### 5.36.9 Install Security — Summary Table

| Concern | Mitigation | Section |
|---|---|---|
| Unauthorized install | `checkAuth()` required | §5.36.1 |
| Remote install | `isLocalRequest()` required on install + uninstall + install_token endpoints | §5.36.1 |
| Brute force | 5 failed attempts / 15 min per IP | §5.36.2 |
| CSRF | one-shot token (60 s TTL) | §5.36.1 |
| Path traversal | APK path hardcoded in Go + sh | §5.36.3 |
| Shell injection | `shellQuote()` on all paths | §5.5 |
| SELinux relaxation | NEVER `setenforce 0` — staging instead | §5.36.3 |
| Play Protect interference | temporary disable + restore via trap + 75 s cascade deadline | §5.36.4 |
| APK tampering | SHA256 verification if `.sha256` present | §5.36.8 |
| Audit | full log in `dnscrypt_main.log` | §11.1 |
| Install CPU DoS | per-IP rate limit | §5.36.2 |
| Token leak (XSS / extension) | 60 s TTL + one-shot | §5.36.1 |
| Staged APK leftover | EXIT/INT/TERM traps remove it on every catchable exit path | §5.36.3 |
| Signal-interrupt resume | INT exits 130, TERM exits 143 | §5.36.3 |

---

## 6. Security Headers

### 6.1 Applied Headers

```http
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer
Permissions-Policy: geolocation=(), microphone=(), camera=(), payment=()
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin
```

### 6.2 Why These?

| Header | Purpose |
|---|---|
| CSP | Prevents XSS, clickjacking |
| X-Content-Type-Options | Prevents MIME sniffing |
| X-Frame-Options | Prevents iframe embedding |
| Referrer-Policy | No referrer leakage |
| Permissions-Policy | Disables sensitive APIs |
| COOP + CORP | Cross-origin isolation |

### 6.3 Cookie Security

#### 6.3.1 Applied Settings

```go
http.SetCookie(w, &http.Cookie{
    Name:     SESSION_COOKIE_NAME,        // "dnscrypt_session"
    Value:    token,
    Path:     "/",
    MaxAge:   int(SESSION_TTL.Seconds()),  // 86400 = 24h
    HttpOnly: true,
    Secure:   isSecureCookie(),            // conditional (localhost only)
    SameSite: http.SameSiteLaxMode,        // Lax (PWA-friendly)
})
```

#### 6.3.2 Conditional Secure

```go
func isSecureCookie() bool {
    switch serverBindAddr {
    case "127.0.0.1", "::1", "localhost":
        return true
    }
    return false
}
```

#### 6.3.3 SameSite=Lax

Reasons for Lax: Strict breaks PWA shortcuts; Lax + POST-only
endpoints = full CSRF protection.

#### 6.3.4 HttpOnly

JavaScript cannot read it. Prevents XSS from stealing the session.

### 6.4 Known Limitation: CSP `'unsafe-inline'`

**Current state**:

```http
script-src 'self' 'unsafe-inline';
style-src 'self' 'unsafe-inline';
```

**Status**: removal of `'unsafe-inline'` is deferred to a future
release (see `docs/ROADMAP.md`). The v1.5.0 cycle focused on the
companion install flow.

---

## 7. Authentication

### 7.1 Supported Schemes

The session-based schemes are checked in order by `checkAuth`:

| Scheme | Priority | Rate Limited | Persistence |
|---|---|:---:|---|
| Basic Auth | 1 | Yes | per-request |
| Bearer Token | 2 | No | 24h (for compatibility) |
| Session Cookie | 3 | No | 24h (primary) |
| Watchdog Token | 4 | No | per-request (v1.2.0) |

**Install token (v1.5.0)** is **not** a session scheme. It is an
**additional** per-request credential required in addition to one of
the schemes above, for a single endpoint (`POST
/api/install_companion_app`).

| Property | Value |
|---|---|
| Issued by | `GET /api?action=install_token` (requires a session) |
| Consumed by | `POST /api/install_companion_app` (in addition to session) |
| TTL | 60 s (`INSTALL_TOKEN_TTL`) |
| Format | 64 hex chars (32 bytes) |
| Reusable | ❌ one-shot — deleted from the map on first use |
| Rate-limited | Yes — the install endpoint, per-IP, 5/15 min |

**Scheme precedence on `install_companion_app`**:

1. `checkAuth(r)` must succeed (Bearer / Cookie / Basic).
2. `isLocalRequest(r)` must succeed.
3. `isInstallLockedOut(ip)` must be false.
4. The one-shot token in the request body must be valid and unconsumed.

Any of the four failing short-circuits the request with the
appropriate HTTP status (401 / 403 / 429).

### 7.2 Credentials Source

From `dnscrypt-proxy.toml` (`[monitoring_ui]` section only).

**Fix E**: reading from `[monitoring_ui]` only (section tracking).

**Fix #10**: support for section header with comment.

**Fix NEW-6**: cache read (60 s TTL).

**v1.2.0**: credentials are preserved in the persistent backup.

### 7.3 Constant-time Comparison

```go
userMatch := subtle.ConstantTimeCompare([]byte(user), []byte(expectedUser)) == 1
passMatch := subtle.ConstantTimeCompare([]byte(pass), []byte(expectedPass)) == 1
```

**v1.2.0**: watchdog token also uses `subtle.ConstantTimeCompare`.

**v1.5.0**: install token also uses `subtle.ConstantTimeCompare`.

### 7.4 Rate Limiting

- 5 failed attempts per IP.
- 15-minute lockout.
- `LOGIN_ATTEMPT_STALE_PERIOD = 1 h`.
- `getClientIP()` — IPv6 support.
- **Fix #8**: Basic Auth protected by the same mechanism.
- **v1.2.0**: watchdog token requests bypass the login limiter.
- **v1.5.0**: separate per-IP limiter for the install endpoint
  (§5.36.2).

---

## 8. Session Management

### 8.1 Session Token

- Length: 32 bytes → 64 hex chars.
- Source: `crypto/rand` (CSPRNG).
- Storage: memory only.
- Not stored in JS (cookie-only).
- Not sent in JSON (Audit #15-a).
- Lifetime: 24 hours.
- Sliding: extended on each request.

### 8.2 Session Lifecycle

```text
1. POST /api/auth/login      ← POST only!
2. → verify credentials (constant-time)
3. → createSession(username)
4. → token = hex(rand(32))
5. → sessions[token] = Session{...}
6. → Set-Cookie: dnscrypt_session=token; HttpOnly; Secure; SameSite=Lax
7. → response JSON: {status, message, profile}
                   ← no token (Audit #15-a)
8. ... requests use the cookie automatically ...
9. After 24h → session expired
10. → getSession() deletes it from the map
11. → 401 → handleSessionExpired()
```

### 8.3 Session GC

```go
func startSessionGC() {
    ticker := time.NewTicker(30 * time.Minute)
    for range ticker.C {
        // 1. clean up expired sessions
        // 2. clean up old loginAttempts (Audit #5)
        // 3. clean up old installAttempts (v1.5.0)
    }
}
```

### 8.4 Cookie Security Rationale

Decision: Conditional Secure + SameSite=Lax + POST-only

| Option | CSRF (GET) | CSRF (POST) | PWA | LAN | Rating |
|---|---|---|---|---|---|
| Secure=false, Strict | ✅ | ✅ | ❌ | ✅ | PWA broken |
| Secure=false, Lax | ❌ | ✅ | ✅ | ✅ | CSRF-GET risk |
| Secure=true, Lax + POST-only | ✅ | ✅ | ✅ | ⚠️ | Optimal solution |

---

## 9. Input Validation

### 9.1 Limits

| Input | Limit | Enforcement |
|---|---|---|
| POST body | 5 MB | MaxBytesReader |
| allowlist content | 5 MB | same |
| log file name | 200 chars | isAllowedLogFile |
| username/password | 1024 chars | MaxBytesReader |
| SSE progress msg | 200 chars | write_progress |
| stderr capture | 2048 bytes | limitedBuffer |
| PORT/DASHBOARD_PORT | 1–65535 | readConfPort |
| backup reason (v1.2.0) | fixed set | `createAutoBackup(reason)` callers |
| backup dir name (v1.2.0) | `<ts>-<type>-<pid>[-<rand4>]` | `createAutoBackup` generator |
| remove_module path (v1.4.0) | basename only | `filepath.Base` + trusted base dir |
| install token (v1.5.0) | 64 hex chars | `validateAndConsumeInstallToken` |
| install body size (v1.5.0) | ≤ 5 MB (MaxBytesReader) | `handleAPI` |

### 9.2 Validation Functions

```go
func isAllowedLogFile(name string) bool {
    // - not empty, < 200 chars
    // - no /, \, \x00
    // - no ".."
    // - prefix: "dnscrypt"
    // - extension: .log, .gz, .old, .txt
}

func readConfPort(key, defaultPort string) string {
    // range check (1-65535)
}
```

### 9.3 Sanitization

- `escapeHtml()` before HTML render.
- `filepath.Clean()` before file operations.
- `net.ParseIP()` for IP validation.
- `url.QueryEscape()` in JS.
- **`shellQuote()`** — extended in v1.1.0.
- **v1.2.0**: the `reason` string passed to `createAutoBackup` is
  never used in a shell command.
- **v1.4.0**: `remove_module` sanitizes via `filepath.Base()`.
- **v1.5.0**: `install_app.sh` uses a hardcoded APK path and
  `shellQuote()` on all paths.

### 9.4 Endpoint Matching

- `hasEndpoint()` — exact matching.
- No `strings.Contains`.
- No `strings.HasPrefix` (with a single path).
- Only `path == "/api/NAME"` or `path == "/api/NAME/"`.
- **v1.5.0**: `install_companion_app` and `uninstall_companion_app`
  both use `hasEndpoint`.

---

## 10. Cryptography

### 10.1 Library

- Standard Go library only (`crypto/*`).
- No external dependencies (for crypto).

### 10.2 Algorithms

| Usage | Algorithm |
|---|---|
| Session token | crypto/rand (CSPRNG) |
| Watchdog token (v1.2.0) | crypto/rand (CSPRNG), 32 bytes |
| Content hash | SHA-256 |
| Backup integrity hash (v1.2.0) | SHA-256 (via `sha256sum`) |
| Password compare | subtle.ConstantTimeCompare |
| Watchdog token compare (v1.2.0) | subtle.ConstantTimeCompare |
| **Install token (v1.5.0)** | **crypto/rand (CSPRNG), 32 bytes → 64 hex** |
| **Install token compare (v1.5.0)** | **subtle.ConstantTimeCompare** |
| **APK integrity (v1.5.0)** | **SHA-256 (advisory if `.sha256` present)** |
| TLS (downloads) | TLS 1.2+ |
| Temp files | os.CreateTemp (CSPRNG-based) |

### 10.3 Not Present

- No blocklist encryption (public data).
- No log encryption.
- No credential file encryption.
- No backup encryption (v1.2.0).
- No APK signature verification by the server (v1.4.0).
- **No install token persistence (v1.5.0)** — tokens are in-memory
  only. Server restart discards them.

---

## 11. Logging & Privacy

### 11.1 What We Log

- API requests (IP, action).
- Login attempts (IP, success/fail).
- Config changes.
- Errors (with limited stderr).
- Firewall cleanup operations.
- STATUS_FILE transitions.
- Auth cache hits/misses (debug level).
- Memory limit transitions (info level, v1.1.0).
- **v1.2.0 — backup events** (createAutoBackup, cleanup,
  checkPendingNotifications, rotation, restore).
- **v1.2.0 — recovery-mode events**.
- **v1.2.0 — watchdog token events** (generation, regeneration;
  **token value never logged**).
- **v1.4.0 — companion APK route**: HTTP requests to
  `/app-debug.apk` are not individually logged.
- **v1.5.0 — install events**:
  - Token generation: `install_token issued for <ip>` (debug).
  - Token consumption: `install_token consumed for <ip>` (info).
  - Install attempt: `install attempt #N from <ip>` (info).
  - Install result: `install succeeded (strategy=N)` or
    `install failed: <reason>` (info).
  - Rate limit: `install rate limit hit for <ip>` (warning).
  - **The token value itself is never logged.**

### 11.2 What We Do Not Log

- DNS queries.
- Passwords explicitly.
- Session tokens.
- Watchdog token (v1.2.0).
- **Install token (v1.5.0)**.
- Browsing history.
- Backup file contents.

### 11.3 Log Rotation

| Log | Threshold | Retention |
|---|---|---|
| dnscrypt_main.log | 1 MB | 5 .gz |
| dnscrypt-proxy.log | 6 MB | 3 days |
| dnscrypt-blocked.log | — | user-managed |
| Backup logs (v1.2.0) | in `dnscrypt_main.log` | same rotation |
| `.upgrade_history.json` (v1.2.0) | not rotated | append-only |
| Install logs (v1.5.0) | in `dnscrypt_main.log` | same rotation |

### 11.4 Privacy Guarantee

- Zero telemetry.
- No connection to any server other than DNSCrypt/DoH servers.
- **v1.2.0**: The persistent backup directory is **not** synced to any
  remote server.
- **v1.4.0**: The companion APK is fetched by the **release pipeline**
  (build-time, GitHub Actions), not at install time on the device.
- **v1.5.0**: The install flow is **entirely local**. The local
  install path never contacts GitHub; the two GitHub paths are
  browser-side redirects that the user chooses explicitly.

---

## 12. Supply Chain

### 12.1 Dependencies

| Component | Source | Signing |
|---|---|---|
| Go stdlib | golang.org | ✔ (via Go toolchain) |
| DNSCrypt-proxy | GitHub releases (`DNSCrypt/dnscrypt-proxy`) | ✔ (SHA-256 checksums verified at fetch time) |
| HaGeZi blocklists | cdn.jsdelivr.net | — (content-level integrity via SHA-256 in `.manifest.json` when applicable) |
| Companion APK (v1.4.0) | GitHub releases (`gasciljh/dnscrypt-proxy-app`) | ✔ (Android package signature, verified at install time) |
| Install script (v1.5.0) | `install_app.sh` (in-module, staged at the module root) | covered by the module ZIP's SHA-256 (`package_module.sh` §[20]) |

**Note on release signing**: As of v1.5.0, the module ZIP and the four
WebUI binaries are **NOT** signed with Cosign or GPG. Only the SHA-256
checksum (`.sha256` file) is attached to the release.

**Note on SBOM**: As of v1.5.0, no SBOM (SPDX or CycloneDX) is
generated.

### 12.2 Build Security

- Reproducible builds (`SOURCE_DATE_EPOCH`).
- SHA-256 checksums attached to every release.
- `dns-binaries.version` pins the dnscrypt-proxy version.
- `proxy/app-apk.version` pins the companion app version (v1.4.0).
- **v1.5.0**: `ci.yml` verifies `install_app.sh` is present and
  executable. `release.yml` stages the APK's `.sha256` alongside the
  APK.
- The 42-scenario `upgrade-test.yml` matrix validates the 10
  defensive layers before release.

---

## 13. Known Limitations

### 13.1 Not Fixable

| Limitation | Reason |
|---|---|
| Root user bypasses everything | No protection against full root |
| LAN access if BIND_ADDR=0.0.0.0 | Intentional feature |
| App with root reads logs | Nature of the system |
| Secure=false on LAN | Necessary to avoid breaking login |
| PWA dual-origin limitation | Service Worker bound to origin |
| `manifest.json` shortcuts static | Evaluated before JS |
| Soft memory limit is not a hard cap | Go runtime design (v1.1.0) |
| Backup directory readable by root | Nature of the system (v1.2.0) |
| SHA256 backup check is advisory | Deliberate: never blocks a restore (v1.2.0) |
| Companion APK served without auth (v1.4.0) | Contains no secrets; Android signature-verifies at install |
| Install token is ephemeral (v1.5.0) | In-memory only; server restart discards outstanding tokens |
| Play Protect disable does not persist across reboot (v1.5.0) | `settings put` writes to the system DB; a forced reboot during the install may leave the verifier off until the next Play Protect scan |
| Package-name candidates are hardcoded (v1.5.0) | The 3 candidates cover all realistic variants; a fourth would require a script update |
| SIGKILL during the install skips the trap | SIGKILL is uncatchable by design. See §5.36.4 — the 75-second cascade deadline ensures the trap fires before the primary path reaches SIGKILL |

### 13.2 Known Issues (will be fixed)

| Issue | Proposed fix | Version |
|---|---|---|
| CSP `'unsafe-inline'` | Convert onclick → addEventListener | future |
| `pgrep -x` on Android 5.x | fallback | future |
| awk with `]` in comment | improve parser | future |
| PWA dual-origin (9090 vs 9091) | unify on one port | future |
| `manifest.json` shortcuts do not read `runtime_info` | unify on one port | future |
| Maskable icon reuses `icon-512.png` | ship dedicated maskable SVG | future |
| Backup integrity is advisory | opt-in enforcing mode | future |
| `append_denylist` not used by WebUI | send `content` parameter | future |
| Companion app deep-links | add `dnsproxy://` scheme | future |
| Companion version bump automation | add `check-app-version.sh` | future |
| Install token is not rotated per-session | rotate on logout | future |

**Note**: v1.5.0's scope focused on the companion app one-tap install
flow and three frontend state fixes (IDX-23, IDX-23b, IDX-25, IDX-25a).
The items above are deferred to a future release.

### 13.3 Compensating Controls

- BIND_ADDR=127.0.0.1 by default.
- Refuses 0.0.0.0 without credentials.
- Strict CSP (except inline).
- SSE Write Deadline (30 s).
- Rate limiting (login + Basic Auth).
- CSRF protection (POST-only).
- Cookie-only auth (no token in response).
- IPv4/IPv6 firewall separation (Audit #16).
- Custom Chains for iptables (Audit #17).
- STATUS_FILE semantics (Audit #18).
- IPv6-safe rate limiting (Audit #19).
- Port Guard 8080 (Audit #20).
- Section-restricted TOML (Audit #21).
- Exact endpoint matching (Fix #12).
- Basic Auth rate limiting (Fix #8).
- Section header with comment (Fix #10).
- Per-port cache (Fix #11).
- Preserve settings on upgrade (Fix #3).
- Login POST-only (NEW-1).
- `/readyz` localhost-only (NEW-4).
- `shellQuote()` injection protection (NEW-5, extended v1.1.0).
- `readConfPort` range check (NEW-3).
- `rebuildMu` mutex (RACE-1).
- `runtime_info` dynamic ports (PORT-2).
- `sync.Once` for shell detection (Fix #2).
- Auth cache (60 s) (NEW-6).
- Dynamic per-profile memory limit (MEM-1, v1.1.0).
- Extended `shellQuote` charset (MEM-2, v1.1.0).
- `MONITORING_UI_PORT` in metrics handler (MEM-3, v1.1.0).
- 10 defensive layers for user-data preservation (v1.2.0).
- `backupMu` serialization (BAK-2, v1.2.0).
- Persistent backup directory with `0700`/`0600` (v1.2.0).
- SHA256 integrity verification, advisory (Layer 3, v1.2.0).
- Transactional upgrade with rollback (Layer 4, v1.2.0).
- Watchdog token on `/api/ensure_running_service` (WD-TOKEN,
  v1.2.0).
- Snapshot-and-reapply in recovery mode (FIX-1, v1.2.0).
- ROT-MANIFEST + ROT-MTIME + ROT-PROTECT (v1.3.0).
- CodeQL `go/path-injection` hardening in `removeModule` (§5.34,
  v1.4.0).
- iOS PWA code removed (§5.35.1, v1.4.0).
- Companion APK served with Android signature verification (§5.35.2,
  v1.4.0).
- One-shot CSRF token on `install_companion_app` (§5.36.1, v1.5.0).
- Per-IP install rate limit (5 / 15 min) (§5.36.2, v1.5.0).
- SELinux staging — never `setenforce 0` (§5.36.3, v1.5.0).
- Play Protect temporary disable + trap restore + 75 s cascade
  deadline (§5.36.4, v1.5.0).
- SHA256 advisory verification of the APK (§5.36.8, v1.5.0).
- Staged APK cleanup via three-way trap with re-entry guard
  (§5.36.3, v1.5.0).
- Signal interrupts (SIGINT / SIGTERM) exit immediately with 130 /
  143 (§5.36.3, v1.5.0).

---

## 14. Security Checklist

### 14.1 Pre-release

- [ ] Go build passes.
- [ ] No hardcoded secrets.
- [ ] `detect-secrets` clean.
- [ ] No new dependencies without review.
- [ ] CSRF protection active on all state-changing endpoints.
- [ ] Login response contains no token.
- [ ] 405 includes `Allow: POST` header.
- [ ] IPv4/IPv6 firewall separation verified.
- [ ] STATUS_FILE written only from `startService`/`stopService`.
- [ ] IPv6 client IP handled correctly.
- [ ] Custom Chain cleanup verified.
- [ ] Port Guard 8080 active.
- [ ] Section-restricted TOML verified.
- [ ] Basic Auth rate limit active.
- [ ] Exact path matching verified.
- [ ] JSON conversion from Prometheus works.
- [ ] 404 for unknown action.
- [ ] Section header with comment supported.
- [ ] Login POST-only enforced.
- [ ] `/readyz` restricted to localhost.
- [ ] `shellQuote` applied to all dynamic paths.
- [ ] `readConfPort` range check active.
- [ ] `rebuildMu` mutex present on `rebuildBlocklist`.
- [ ] `runtime_info` returns correct ports.
- [ ] `memory_limit_mb` + `profile_key` returned by `runtime_info`.
- [ ] Memory limit applies correctly on startup.
- [ ] Memory limit re-applies on profile change.
- [ ] `MONITORING_UI_PORT` used in `metricsProxyHandler`.
- [ ] v1.2.0: Backup directory exists with mode `0700`.
- [ ] v1.2.0: `.watchdog_token` exists with mode `0600`.
- [ ] v1.2.0: `backupMu` mutex declared in `main.go`.
- [ ] v1.2.0: `runtime_info.backups` returns 7 fields.
- [ ] v1.2.0: FIX-1 present in `customize.sh`.
- [ ] v1.2.0: FIX-2 present in both `index.html` and
      `dashboard.html`.
- [ ] v1.3.0: ROT-MANIFEST present in `functions.sh`.
- [ ] v1.3.0: ROT-MTIME present in `functions.sh`.
- [ ] v1.3.0: ROT-PROTECT present in `functions.sh`.
- [ ] v1.3.0: SNAP-MANIFEST present in `main.go`.
- [ ] v1.3.0: SNAP-MTIME present in `main.go`.
- [ ] v1.4.0: `removeModule` uses `filepath.Base()` +
      `securejoin.SecureJoin`.
- [ ] v1.4.0: `/app-debug.apk` returns 200 (release) or 404
      (dev build), never 5xx.
- [ ] v1.4.0: iOS PWA logic absent from `web/index.html`.
- [ ] v1.5.0: `web/index.html` install button uses
      `handleCompanionInstall()` (not a direct `href="/app-debug.apk"`
      link). See §14.34.
- [ ] v1.5.0: `_resetModalLayout()` is called at the start of
      `showConfirmModal()`.
- [ ] v1.5.0: `handleCompanionInstall()` disables the install button
      during the token fetch and re-enables it on both success and
      failure paths.
- [ ] v1.5.0: IDX-23 fix present — `renderAllDynamic()` calls
      `renderCompanionButton()`.
- [ ] v1.5.0: IDX-23b fix present — `renderAllDynamic()` calls
      `updateStatusUI()` / `setNetworkDownUI()`.
- [ ] v1.5.0: IDX-25 fix present — `updateNavLinks()` uses
      `runtimeInfoCard` / `diagFilesCard`.
- [ ] v1.5.0: IDX-25a fix present — the hint toast is centered.
- [ ] v1.5.0: IDX-429 fix present — `xhrRequest()` recognises HTTP
      429 and `doCompanionInstall()` renders `t('installRateLimited')`.
- [ ] v1.5.0: IDX-401-DISTINCT fix present —
      `isInstallFamilyUrl()` suppresses the session-expired modal on
      install-family 401s.
- [ ] v1.5.0: DASH-REFRESH-01 fix present — `isRefreshing` reset on
      the 401 branch.
- [ ] v1.5.0: DASH-SESSION-RETRY-01 fix present — the session-expired
      primary action resets state and reloads.
- [ ] v1.5.0: DASH-HINT-01 fix present — dual-timer lifecycle.
- [ ] v1.5.0: DASH-HINT-02 fix present — `scrollend` + fallback.
- [ ] v1.5.0: ICON-512-SAFEZONE-01 present — the shield path fits
      the W3C maskable safe circle.
- [ ] v1.5.0: `install_app.sh` present and executable at the module
      root.
- [ ] v1.5.0: `install_app.sh` contains the 5 cascade levels.
- [ ] v1.5.0: `install_app.sh` contains SELinux staging.
- [ ] v1.5.0: `install_app.sh` contains the Play Protect trap.
- [ ] v1.5.0: `install_app.sh` trap restores `$_VERIFIER_ORIG`.
- [ ] v1.5.0: `install_app.sh` contains the 75-second cascade
      deadline.
- [ ] v1.5.0: `install_app.sh` installs three traps (EXIT / INT /
      TERM) with `_CLEANED_UP` re-entry guard.
- [ ] v1.5.0: `install_app.sh` INT handler calls `exit 130`; TERM
      handler calls `exit 143`.
- [ ] v1.5.0: `install_app.sh` trap removes the staged APK.
- [ ] v1.5.0: `install_app.sh` does not contain `setenforce 0`.
- [ ] v1.5.0: `main.go` registers the 4 install endpoints.
- [ ] v1.5.0: `main.go` compares install tokens in constant time.
- [ ] v1.5.0: `main.go` declares `portConfMu` and routes
      `getWebUIPort()` / `getDashboardPort()` through a 30 s cache.
- [ ] v1.5.0: `main.go` `logWithLevel` is split into three layers;
      the rotation-failure path calls `writeLocked`, never
      `logWithLevel`.
- [ ] v1.5.0: `main.go` `isLocalRequest` has no unreachable
      `"localhost"` comparison.
- [ ] v1.5.0: `main.go` `appendDenylist` uses
      `getRulesState().DenylistHash`.
- [ ] v1.5.0: `main.go` `handleAPI` applies the localhost gate to
      `install_companion_app`, `uninstall_companion_app`, and the
      `install_token` GET endpoint.

### 14.2 Runtime

- [ ] BIND_ADDR=127.0.0.1 (default).
- [ ] Strong credentials (24-char).
- [ ] CSP header applied.
- [ ] Rate limiting active for Login.
- [ ] Rate limiting active for Basic Auth.
- [ ] Session GC active.
- [ ] CSRF protection (POST-only) active.
- [ ] Cookie-only auth (no token in JS/JSON).
- [ ] Firewall rules applied correctly (IPv4 + IPv6).
- [ ] STATUS_FILE reflects user intent (not process state).
- [ ] No orphan iptables rules in OUTPUT.
- [ ] `/readyz` rejects non-localhost requests.
- [ ] `shellQuote` in all dynamic shell commands.
- [ ] `rebuildMu` prevents concurrent rebuilds.
- [ ] Auth cache (60 s) reduces I/O.
- [ ] `runtime_info` returns correct ports.
- [ ] Login POST-only enforced.
- [ ] Memory limit matches active profile.
- [ ] Startup log reports the effective memory limit.
- [ ] v1.2.0: `backups.available >= 1` after first boot.
- [ ] v1.2.0: `backups.in_flight_txn == 0`.
- [ ] v1.2.0: `backups.orphan_txn == 0` (or documented).
- [ ] v1.2.0: Watchdog token file exists and is `0600`.
- [ ] v1.2.0: `.recovery_snapshot/` is absent after a successful
      recovery.
- [ ] v1.3.0: `.last_stable` target preserved by rotation.
- [ ] v1.3.0: The newest install snapshot preserved by rotation.
- [ ] v1.3.0: A manifest-less directory is not counted in
      `backups.available`.
- [ ] v1.4.0: `/app-debug.apk` returns 200 when bundled.
- [ ] v1.5.0: `GET /api?action=install_token` returns a 64-hex token
      with `ttl: 60`.
- [ ] v1.5.0: The install token is consumed on first use.
- [ ] v1.5.0: `POST /api/install_companion_app` with no token returns
      401.
- [ ] v1.5.0: `POST /api/install_companion_app` from non-localhost
      returns 403.
- [ ] v1.5.0: 6 rapid install attempts trigger 429.
- [ ] v1.5.0: `/data/local/tmp/dnscrypt-companion.apk` exists briefly
      during install (staging) and is removed on exit.
- [ ] v1.5.0: A direct CLI invocation (`su -c "sh install_app.sh"`)
      terminates immediately on Ctrl+C with exit code 130.
- [ ] v1.5.0: A direct CLI invocation terminated by SIGTERM returns
      exit code 143.

### 14.3 User

- [ ] User did not share credentials.
- [ ] Did not open 0.0.0.0 without a firewall.
- [ ] v1.2.0: Did not delete `/sdcard/dnscrypt-webui-backup/`
      unintentionally.
- [ ] v1.4.0: If they installed the companion app, verified the
      package was signed by the expected developer key.
- [ ] v1.5.0: Understands that the install requires root and grants
      the companion app full root-triggered installation.

### 14.4 Cookie Audit

- [ ] HttpOnly=true.
- [ ] Secure=true (on localhost).
- [ ] Secure=false (on LAN).
- [ ] SameSite=Lax.
- [ ] Path=/.
- [ ] MaxAge=86400.
- [ ] MaxAge=-1 on logout.
- [ ] No Domain=.
- [ ] No Expires=.

### 14.5 CSRF Audit

- [ ] toggle → POST only.
- [ ] restart → POST only.
- [ ] ensure_running → POST only (+ watchdog token).
- [ ] login → POST only.
- [ ] logout → POST only.
- [ ] install_companion_app → POST only + install token (v1.5.0).
- [ ] 405 with `Allow: POST` header.
- [ ] PWA shortcuts work.

### 14.6 Token Leakage Audit

- [ ] No token in login response.
- [ ] No sessionStorage for session tokens.
- [ ] HttpOnly cookie only.
- [ ] v1.2.0: Watchdog token never logged.
- [ ] v1.5.0: Install token never logged.

### 14.7 Firewall Audit

- [ ] iptables does not contain IPv6.
- [ ] ip6tables contains IPv6 bootstrap.
- [ ] nftables uses case filter (IPv4/IPv6).
- [ ] No DNS loop on IPv4.
- [ ] No DNS loop on IPv6.

### 14.8 Custom Chains Audit

- [ ] OUTPUT contains only jump rules.
- [ ] DNSCRYPT_OUT exists and contains RETURN + DNAT.
- [ ] DNSCRYPT_OUT6 exists (if IPv6 is available).
- [ ] No orphan RETURN rules in OUTPUT.
- [ ] On stopService: DNSCRYPT_OUT is fully removed.

### 14.9 Status File Audit

- [ ] STATUS_FILE written only by startService/stopService.
- [ ] getStatusUncached does not write.
- [ ] Watchdog reads only.

### 14.10 IPv6 Rate Limit Audit

- [ ] getClientIP uses net.SplitHostPort.

### 14.11 Port Collision Audit

- [ ] MONITORING_UI_PORT constant = "8080" in main.go.
- [ ] _MONITORING_UI_PORT constant = "8080" in boot-mini.sh.
- [ ] main.go rejects PORT=8080.
- [ ] customize.sh rejects PORT=8080.

### 14.12 Section-Restricted TOML Audit

- [ ] getMonitoringAuth tracks sections.
- [ ] read_toml_credentials tracks sections.
- [ ] watchdog.sh reads from `[monitoring_ui]` only.

### 14.13 Basic Auth Rate Limit Audit

- [ ] `checkAuth` records failed Basic Auth attempts.
- [ ] `isLockedOut` is checked before `BasicAuth`.
- [ ] Successful Basic Auth resets the counter.

### 14.14 Exact Endpoint Matching Audit

- [ ] `hasEndpoint` present in main.go.
- [ ] All POST endpoints use `hasEndpoint`.
- [ ] No `strings.Contains` for paths.

### 14.15 JSON Conversion Audit

- [ ] `parsePrometheus` present.
- [ ] `buildDashboardJSON` present.
- [ ] `metricsProxyHandler` returns JSON.
- [ ] Content-Type correct.

### 14.16 Login POST-only Audit

- [ ] `/api/auth/login` accepts POST only.
- [ ] `/api/auth/logout` accepts POST only.
- [ ] GET/HEAD/PUT/DELETE → 405 + `Allow: POST`.

### 14.17 `/readyz` Localhost-Only Audit

- [ ] `/readyz` rejects non-localhost.
- [ ] `/healthz` remains public.
- [ ] 403 for external requests.

### 14.18 `shellQuote` Audit

- [ ] `shellQuote` present in main.go.
- [ ] Used in 3+ places.
- [ ] No `. " + MODDIR + "` without shellQuote.
- [ ] v1.1.0: extended character set includes `{`, `}`, `\n`, `\t`.

### 14.19 `readConfPort` Range Audit

- [ ] `readConfPort` present in main.go.
- [ ] Checks `n < 1` and `n > 65535`.
- [ ] Falls back to default.

### 14.20 `rebuildMu` Mutex Audit

- [ ] `rebuildMu sync.Mutex` declared.
- [ ] `rebuildBlocklist` uses `rebuildMu.Lock()` + `defer Unlock()`.

### 14.21 `runtime_info` Ports Audit

- [ ] `buildRuntimeInfo` returns `webui_port` + `dashboard_port`.
- [ ] `index.html` uses `data.dashboard_port`.
- [ ] `dashboard.html` uses `data.webui_port`.

### 14.22 v1.1.0 — Dynamic Memory Limit Audit (MEM-1)

- [ ] `memoryLimitForProfile` declared in main.go.
- [ ] `applyMemoryLimit` declared in main.go.
- [ ] All 5 profile constants defined.
- [ ] No hardcoded `debug.SetMemoryLimit(80 * 1024 * 1024)` remains.
- [ ] `applyMemoryLimit` called from `main()`.
- [ ] `applyMemoryLimit` called from `updateProfile`.

### 14.23 v1.1.0 — Extended `shellQuote` Audit (MEM-2)

- [ ] Extended character set includes `{`, `}`, `\n`, `\t`.

### 14.24 v1.1.0 — `MONITORING_UI_PORT` in Metrics Handler (MEM-3)

- [ ] No hardcoded `"http://127.0.0.1:8080/api/metrics"` remains.
- [ ] `metricsProxyHandler` uses `MONITORING_UI_PORT`.

### 14.25 v1.2.0 — Backup Directory Permissions Audit

**Verify**:

```bash
su -c "stat -c '%a %U:%G %n' /sdcard/dnscrypt-webui-backup/"
# Expected: 700 root:root /sdcard/dnscrypt-webui-backup/

su -c "find /sdcard/dnscrypt-webui-backup -maxdepth 1 -type d -exec stat -c '%a %n' {} \\;"

su -c "find /sdcard/dnscrypt-webui-backup -type f -exec stat -c '%a %n' {} \\;"
```

### 14.26 v1.2.0 — `backupMu` Serialization Audit

**Verify**:

```bash
grep -q 'backupMu' proxy/main.go && echo "✅ backupMu declared"
grep -q 'backupMu.Lock()' proxy/main.go && echo "✅ Lock present"
grep -q 'defer backupMu.Unlock()' proxy/main.go && echo "✅ Unlock present"
```

### 14.27 v1.2.0 — 7-Field `backups` Object Audit

**Verify**:

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys | length'
# Expected: 7

curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups.path'
# Expected: /sdcard/dnscrypt-webui-backup
```

### 14.28 v1.2.0 — Watchdog Token Audit

**Verify**:

```bash
su -c "stat -c '%a' /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: 600

grep -q 'loadOrCreateWatchdogToken' proxy/main.go && echo "✅ token loader"
grep -q 'subtle.ConstantTimeCompare' proxy/main.go && echo "✅ constant-time compare"
```

### 14.29 v1.2.0 — Recovery-Mode Interaction Audit (FIX-1)

**Verify**:

```bash
su -c "grep -q 'RECOVERY_SNAPSHOT_DIR' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ FIX-1 present (snapshot dir)'"
su -c "grep -q 'Re-applying recovery snapshot' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ FIX-1 present (§[9b2] re-apply block)'"
```

### 14.30 v1.2.0 — SELinux Context Preservation Audit (Layer 6)

**Verify**:

```bash
su -c "grep -q 'copy_with_context' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && echo '✅ helper'"
su -c "which restorecon && echo '✅ restorecon' || echo '⚠️ no restorecon (fallback: chcon)'"
su -c "ls -Z /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
```

### 14.31 v1.4.0 — CodeQL `go/path-injection` Fix Audit

**Verify**:

```bash
# BusyBox grep does not support -A / -B / -C (GNU extensions).
# Use awk with a range match instead.
awk '/func removeModule/,/^}/' proxy/main.go | grep -q 'filepath.Base' && echo "✅ filepath.Base present"
awk '/func removeModule/,/^}/' proxy/main.go | grep -q 'SecureJoin' && echo "✅ securejoin present"

# Or, equivalently, two separate single-line greps:
grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ sanitizer present"
grep -q 'securejoin.SecureJoin' proxy/main.go && echo "✅ trusted base dir present"

# Runtime check
curl -X POST http://127.0.0.1:9090/api/remove_module -d "path=/data/adb/modules/.."
# Expected: {"status":"error","message":"Invalid module name"}
```

### 14.32 v1.4.0 — Companion APK Route Audit

**Verify**:

```bash
su -c "test -s /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk && echo '✅ APK bundled' || echo '(dev build)'"
curl -sI http://127.0.0.1:9090/app-debug.apk | head -3
```

### 14.33 v1.3.0 — Server-Side Refinements Audit

**Verify (SNAP-MANIFEST + SNAP-MTIME)**:

```bash
awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q '.manifest.json' && echo "✅ SNAP-MANIFEST"
awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'ModTime()' && echo "✅ SNAP-MTIME"
```

**Verify (ROT-MANIFEST + ROT-MTIME + ROT-PROTECT)**:

```bash
awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q '.manifest.json' && echo "✅ ROT-MANIFEST"
awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q 'sort -rn -k1,1' && echo "✅ ROT-MTIME"
awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q '_protected' && echo "✅ ROT-PROTECT"
```

### 14.34 v1.5.0 — Companion Install Flow Audit

**Purpose**: verify that the companion install flow has all its
security controls present and configured as documented in §5.36.

**1. Static audit — the install script**

```bash
# 1.1 Script is present and executable at the MODULE ROOT.
su -c "test -x /data/adb/modules/dnscrypt-proxy-webui/install_app.sh && \
  echo '✅ install_app.sh executable' || echo '❌ missing or not executable'"

# 1.2 Script contains the 5 cascade levels
su -c "grep -q 'pm install -r --user 0' install_app.sh && echo '✅ level 1'"
su -c "grep -q 'pm install -r -i com.android.shell' install_app.sh && echo '✅ level 2'"
su -c "grep -q 'pm install-create' install_app.sh && echo '✅ level 3'"
su -c "grep -q 'magisk su' install_app.sh && echo '✅ level 4'"
su -c "grep -q 'cmd package install' install_app.sh && echo '✅ level 5'"

# 1.3 SELinux staging
su -c "grep -q '/data/local/tmp/dnscrypt-companion.apk' install_app.sh && \
  echo '✅ SELinux staging present'"

# 1.4 SELinux is NOT disabled
su -c "grep -q 'setenforce 0' install_app.sh && \
  echo '❌ SELinux relaxation found' || \
  echo '✅ no setenforce 0'"

# 1.5 Play Protect trap
su -c "grep -q 'package_verifier_enable' install_app.sh && \
  echo '✅ Play Protect disable present'"

# 1.6 Trap restores captured value
su -c "grep -q '_VERIFIER_ORIG' install_app.sh && \
  echo '✅ trap uses \$_VERIFIER_ORIG'"

# 1.7 Cascade deadline (definition + computation + usage + comments)
su -c "grep -c 'CASCADE_DEADLINE_SECONDS' install_app.sh"
# Expected: 3-5 occurrences

# 1.8 Three-way trap split
su -c "grep -q \"trap '_cleanup_app' EXIT\" install_app.sh && \
  echo '✅ EXIT trap installed'"
su -c "grep -q \"trap '_cleanup_app; exit 130' INT\" install_app.sh && \
  echo '✅ INT trap exits 130'"
su -c "grep -q \"trap '_cleanup_app; exit 143' TERM\" install_app.sh && \
  echo '✅ TERM trap exits 143'"
su -c "grep -q '_CLEANED_UP=1' install_app.sh && \
  echo '✅ cleanup re-entry guard present'"

# 1.9 Staged APK cleanup inside the trap
su -c "grep -q 'rm -f \"\$STAGING_APK\"' install_app.sh && \
  echo '✅ staged APK cleanup in trap'"

# 1.10 Package name candidates
# BusyBox grep does not support \b as a word boundary (it treats it
# as a literal backspace). The check uses an explicit character-class
# boundary.
su -c "grep -q 'com.gasciljh.dnsproxy.debug' install_app.sh && echo '✅ candidate 1'"
su -c "grep -qE 'com\.gasciljh\.dnsproxy([^.]|$)' install_app.sh && echo '✅ candidate 2'"
su -c "grep -q 'com.gasciljh.dnscrypt_proxy' install_app.sh && echo '✅ candidate 3 (legacy)'"

# 1.11 SHA256 advisory
su -c "grep -q 'app-debug.apk.sha256' install_app.sh && echo '✅ SHA256 advisory'"
```

**2. Static audit — the backend**

```bash
# 2.1 The 4 install endpoints are registered
grep -q 'install_companion_app' proxy/main.go && echo "✅ endpoint 1"
grep -q 'uninstall_companion_app' proxy/main.go && echo "✅ endpoint 2"
grep -q 'install_token' proxy/main.go && echo "✅ endpoint 3"
grep -q 'companion_app_state' proxy/main.go && echo "✅ endpoint 4"

# 2.2 Constants
grep -q 'INSTALL_TOKEN_TTL' proxy/main.go && echo "✅ TTL constant"
grep -q 'MAX_INSTALL_ATTEMPTS' proxy/main.go && echo "✅ attempts constant"
grep -q 'INSTALL_LOCKOUT_PERIOD' proxy/main.go && echo "✅ lockout constant"
grep -q 'COMPANION_STATE_CACHE_TTL' proxy/main.go && echo "✅ state cache TTL"

# 2.3 Constant-time token comparison
grep -q 'subtle.ConstantTimeCompare' proxy/main.go && echo "✅ constant-time"

# 2.4 Rate limit state
grep -q 'installAttempts' proxy/main.go && echo "✅ install attempts map"
grep -q 'isInstallLockedOut' proxy/main.go && echo "✅ lockout check"

# 2.5 Localhost gate covers all three surfaces (install, uninstall,
#     install_token)
grep -q 'isLocalRequest' proxy/main.go && echo "✅ localhost gate"

# 2.6 Port cache for getWebUIPort / getDashboardPort
grep -q 'portConfMu' proxy/main.go && echo "✅ port cache mutex"

# 2.7 Logger is split into three layers
grep -q 'logLocked' proxy/main.go && echo "✅ logger three-layer split"

# 2.8 appendDenylist uses getRulesState().DenylistHash
grep -q 'getRulesState().DenylistHash' proxy/main.go && echo "✅ appendDenylist hash source"
```

**3. Runtime audit**

```bash
# 3.1 Token generation
curl -s -b /tmp/cookies.txt "http://127.0.0.1:9090/api?action=install_token" | jq
# Expected: { "token": "<64 hex>", "ttl": 60 }

# 3.2 Token is one-shot — second use returns 401
TOKEN=$(curl -s -b /tmp/cookies.txt "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')
curl -s -b /tmp/cookies.txt -X POST "http://127.0.0.1:9090/api/install_companion_app" -d "token=$TOKEN" | jq -r '.status'
# (first use — may succeed or fail depending on the environment)
curl -s -b /tmp/cookies.txt -X POST "http://127.0.0.1:9090/api/install_companion_app" -d "token=$TOKEN"
# Expected (second use): {"status":"error","action":"install","message":"Invalid or expired install token"}

# 3.3 No token → 401
curl -i -X POST "http://127.0.0.1:9090/api/install_companion_app" -b /tmp/cookies.txt
# Expected: HTTP/1.1 401 Unauthorized

# 3.4 Non-localhost → 403 (test from another device on the LAN)
curl -i -X POST "http://192.168.1.5:9090/api/install_companion_app" -b /tmp/cookies.txt -d "token=foo"
# Expected: HTTP/1.1 403 Forbidden

# 3.5 Rate limit — 6 rapid attempts (all with fresh tokens)
for i in 1 2 3 4 5 6; do
  TOKEN=$(curl -s -b /tmp/cookies.txt "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')
  curl -s -o /dev/null -w "%{http_code}\n" -b /tmp/cookies.txt \
    -X POST "http://127.0.0.1:9090/api/install_companion_app" -d "token=$TOKEN"
done
# Expected: 200 for the first 5, 429 for the 6th

# 3.6 Companion state
curl -s -b /tmp/cookies.txt "http://127.0.0.1:9090/api?action=companion_app_state" | jq
# Expected: { "status": "ok", "action": "status", "installed": ..., ... }
```

**4. On-device staging audit (during an install)**

```bash
# While an install is in progress, in another terminal:
su -c "ls -la /data/local/tmp/dnscrypt-companion.apk"
# Expected: a 3 MB file (staging copy)

su -c "ls -Z /data/local/tmp/dnscrypt-companion.apk"
# Expected: u:object_r:shell_data_file:s0

# After the install completes, the file is REMOVED by the trap:
su -c "ls /data/local/tmp/dnscrypt-companion.apk 2>&1"
# Expected: "No such file or directory"
```

**5. Cascade deadline audit**

```bash
# 5.1 The constant is defined
su -c "grep 'CASCADE_DEADLINE_SECONDS=75' install_app.sh && \
  echo '✅ 75-second deadline defined'"

# 5.2 The deadline is enforced before each strategy
su -c "grep -c 'CASCADE_DEADLINE_SECONDS' install_app.sh"
# Expected: 3-5 occurrences

# 5.3 The deadline is shorter than main.go's INSTALL_TIMEOUT
su -c "grep 'CASCADE_DEADLINE_SECONDS=75' install_app.sh >/dev/null && \
  grep 'INSTALL_TIMEOUT' proxy/main.go | grep -q '90' && \
  echo '✅ 75 s deadline < 90 s INSTALL_TIMEOUT'"
```

**6. Signal handling audit**

```bash
# 6.1 Direct CLI invocation terminated by Ctrl+C returns 130
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/install_app.sh" &
PID=$!
sleep 2
kill -INT $PID
wait $PID
echo "exit=$?"
# Expected: exit=130, and /data/local/tmp/dnscrypt-companion.apk is gone

# 6.2 SIGTERM returns 143
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/install_app.sh" &
PID=$!
sleep 2
kill -TERM $PID
wait $PID
echo "exit=$?"
# Expected: exit=143

# 6.3 Cleanup runs exactly once even when INT triggers EXIT
#     (the _CLEANED_UP guard prevents double-cleanup)
su -c "grep -c 'install_app' /data/local/tmp/dnscrypt_main.log"
# The log should show one cleanup cycle per invocation, not two.
```

**7. Log audit**

```bash
su -c "grep 'install_token' /data/local/tmp/dnscrypt_main.log | tail -5"
# Expected: token generation and consumption events, WITHOUT the token value

su -c "grep 'install attempt' /data/local/tmp/dnscrypt_main.log | tail -5"
# Expected: install attempt and result events

# Verify the token value is NOT in the log. A bare grep -E '[a-f0-9]{64}'
# is too broad — it matches any SHA-256 hex string in the file, not only
# install tokens. The check is scoped to lines mentioning install_token.
su -c "grep 'install_token' /data/local/tmp/dnscrypt_main.log | \
  grep -E '[a-f0-9]{32,}' && echo '❌ token leak suspected' || \
  echo '✅ no install token leaked in the log'"
```

---

## 15. Acknowledgments

Thanks to everyone who has contributed to the security of the project:

- All the Security Researchers who have responsibly disclosed issues.
- The GitHub community for code review.
- **Anthropic Claude** for assistance with the audit and review.

---

## 16. Changelog — Security Changes

### v1.5.0 (2026-10-13)

**Feature release — companion app one-tap install.**

**No new audit corrections.** The registry remains at **#33**.

**New sections in this document**:

- **§5.36 — Companion App Install Security (APK-5, APK-11)**.
- **§14.34 — Companion install flow audit**.
- **§18 — Documentation Corrections to This File** (new consolidated
  table).

**Asset / adversary / protection updates**:

- §2.1 — added `installTokens`, `installAttempts`, and
  `companionStateCache`.
- §3.1 — added three new rows: install brute-force, install CSRF,
  and install token leak.
- §3.2 — added four v1.5.0 bullets.
- §4.2 — added the same three in-memory assets, plus the
  `$PERSISTENT_BACKUP/apk/` mirror.
- §7.1 — install token as a distinct, additional credential
  (separate table).
- §10.2 — three new crypto rows.
- §11.1 / §11.2 — install event logging + install tokens in the
  "do not log" list.
- §11.4 — local-only install path.
- §12.1 / §12.2 — `install_app.sh` and v1.5.0 CI/release additions.
- §13.1 / §13.2 / §13.3 — v1.5.0 limitations + compensating controls.

**Post-release audit corrections**: see §18 for the consolidated
table.

**Registry status**: unchanged at **#33**. Next expected: **#34**.

### v1.4.0 (2026-10-06) — historical

**Integration release — companion app + CodeQL fix + iOS removal.**

**No new audit corrections.**

**New sections in this document**:

- §5.34 — CodeQL `go/path-injection` Fix in `removeModule`.
- §5.35 — iOS PWA Removal + Companion APK Route.

### v1.3.0 (2026-10-02) — historical

**Feature release — PWA install button + live status LED + DNS
auto-start + server-side rotation refinements.**

**No new audit corrections.**

**Runtime changes with no security impact**:

- PWA install button (client-side).
- Live status LED (client-side).
- DNS auto-start fix (`service.sh`).
- `buildBackupInfo` sort order change (name → mtime).
- SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT.

### v1.2.0 (2026-09-29) — historical

**Data-preservation release.**

**New sections**:

- §5.31 — Data Preservation Security Model.
- §5.32 — Correctness Fixes (FIX-1, FIX-2).
- §5.33 — Watchdog Token (WD-TOKEN).

### v1.1.0 (2026-09-26) — historical

**Polish release — no new audit corrections.**

**Runtime improvements**: MEM-1, MEM-2, MEM-3.

### v1.0.0 (2026-09-24) — historical

**First stable release.** All 33 audit corrections consolidated.

---

## 17. Audit Corrections Registry

> **v1.5.0 note**: This release does **not** extend the registry.
> The last audit correction is #33, from v1.0.0. v1.5.0 is a feature
> release. Its companion install flow (§5.36) is documented without
> audit correction numbers.
>
> **Numbering clarification**: §5.31 through §5.36 are **section
> numbers** in this document, **not** Audit Correction numbers. The
> Audit Corrections Registry is a flat, monotonic sequence that only
> advances when a new audit correction is filed.
>
> New audit corrections will resume at **#34** in a future release.

| # | Description | Version | Section |
|:-:|---|---|---|
| #1 | Fixed typo in `isAllowedLogFile` | v1.0.0 | — |
| #3-e/f | Dynamic `bootstrap_resolvers` + IPv6 | v1.0.0 | §5.9 |
| #5 | Cleanup of old `loginAttempts` | v1.0.0 | — |
| #6-c | `limitedBuffer` (bounded stderr) | v1.0.0 | — |
| #7 | Dead code removal | v1.0.0 | — |
| #9/#9-b | `os.CreateTemp` (no race) | v1.0.0 | — |
| #10 | Debounce SSE | v1.0.0 | — |
| #13 | CSRF-GET → POST-only | v1.0.0 | §5.2 |
| #14 | `pgrep -x` | v1.0.0 | — |
| #15-a | Remove token from login response | v1.0.0 | §5.11 |
| #15-b | `Allow: POST` header | v1.0.0 | §5.12 |
| #16-a/b | IPv4/IPv6 separation | v1.0.0 | §5.9 |
| #17 | Custom Chains | v1.0.0 | §5.13 |
| #18 | STATUS_FILE Semantics | v1.0.0 | §5.14 |
| #19 | IPv6 Rate Limit Bypass | v1.0.0 | §5.15 |
| #20 | Port Collision 8080 | v1.0.0 | §5.16 |
| #21 | Section-Restricted TOML | v1.0.0 | §5.17 |
| #22 | Basic Auth Rate Limit Bypass | v1.0.0 | §5.18 |
| #23 | Section header with comment (parsing) | v1.0.0 | §5.19 |
| #24 | Exact endpoint matching | v1.0.0 | §5.20 |
| #25 | Dashboard JSON Conversion | v1.0.0 | §5.20 |
| #26 | Preserve User Settings on Upgrade | v1.0.0 | §5.21 |
| #27 | `fuser` PID parsing | v1.0.0 | §5.22 |
| #28 | Login POST-only (CSRF) | v1.0.0 | §5.23 |
| #29 | `readConfPort` range check | v1.0.0 | §5.24 |
| #30 | `/readyz` localhost-only | v1.0.0 | §5.25 |
| #31 | `shellQuote` injection protection | v1.0.0 | §5.26 |
| #32 | `rebuildMu` mutex (RACE-1) | v1.0.0 | §5.28 |
| #33 | `runtime_info` dynamic ports (PORT-2) | v1.0.0 | §5.29 |

**Last Audit Correction**: #33 (v1.0.0)
**Next expected**: #34 (future release)

### 17.1 v1.1.0 Runtime Improvements (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| MEM-1 | Dynamic memory limit per profile | Closes a self-inflicted DoS surface |
| MEM-2 | Extended `shellQuote` charset | Defense in depth; no known exploit |
| MEM-3 | `MONITORING_UI_PORT` in metrics handler | Single source of truth |

### 17.2 v1.2.0 Runtime Additions & Correctness Fixes (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| BAK-1 | 7-field `runtime_info.backups` | Observability of the backup layer |
| BAK-2 | `createAutoBackup(reason)` + `backupMu` | Serialized pre-critical backups |
| BAK-3 | `cleanupOldTransactions()` | Removes leftover `COMMIT`'d txns |
| BAK-4 | `checkPendingNotifications()` | Reads `.pending_notification` |
| FIX-1 | Recovery-mode snapshot-and-reapply | Correctness fix |
| FIX-2 | Service Worker update-banner | Correctness fix |
| WD-TOKEN | Watchdog token | Closes a CSRF hole on `ensure_running_service` |

### 17.3 v1.2.0 Post-Audit Corrections (BUG-A..BUG-L)

Documented in `docs/ARCHITECTURE.md` §4.6.3 and §4.6.8. The full set
of twelve `BUG-A..BUG-L` corrections to `main.go`. All entries fix
behaviours that clients could observe.

### 17.4 v1.3.0 + v1.4.0 + v1.5.0 Additions (Not Audit Corrections)

The v1.3.0, v1.4.0, and v1.5.0 releases did **not** extend the
registry. Their changes are documented as:

| Version | Change | Section / Reference |
|:-:|---|---|
| v1.3.0 | PWA install button (client-side) | §16 |
| v1.3.0 | Live status LED (client-side) | §16 |
| v1.3.0 | DNS auto-start via `service.sh` | §5.33 |
| v1.3.0 | `buildBackupInfo` sort order change (mtime) | §5.31.2, §5.31.4 |
| v1.3.0 | ROT-MANIFEST + ROT-MTIME + ROT-PROTECT | §5.31.2, §14.33 |
| v1.4.0 | CodeQL `go/path-injection` fix in `removeModule` | §5.34, §14.31 |
| v1.4.0 | iOS PWA logic removal | §5.35.1 |
| v1.4.0 | `/app-debug.apk` public route | §5.35.2, §14.32 |
| v1.5.0 | Companion app one-tap install (APK-5) | §5.36, §14.34 |
| v1.5.0 | One-shot CSRF token (`install_token`) | §5.36.1, §7.1 |
| v1.5.0 | Per-IP install rate limit | §5.36.2 |
| v1.5.0 | SELinux staging (never `setenforce 0`) | §5.36.3 |
| v1.5.0 | Play Protect temporary disable + trap | §5.36.4 |
| v1.5.0 | 75-second cascade deadline | §5.36.4, §14.34 |
| v1.5.0 | Trap restores `$_VERIFIER_ORIG` | §5.36.4, §14.34 |
| v1.5.0 | 5-level cascade rationale | §5.36.5 |
| v1.5.0 | `failure is 200, not 4xx` design | §5.36.6 |
| v1.5.0 | 3 package-name candidates (APK-12) | §5.36.7 |
| v1.5.0 | SHA256 advisory verification of APK | §5.36.8 |
| v1.5.0 | Client-side state fixes (IDX-23, IDX-23b, IDX-25, IDX-25a) | §18 |

**Registry status**: unchanged at **#33**. Next expected: **#34** in
a future release.

---

## 18. Documentation Corrections to This File

This section consolidates every documentation-accuracy correction
applied to this file. **None of these advances the Audit Corrections
Registry** — the registry (§17) remains at **#33**.

The table below is the authoritative index. Individual corrections
are described inline where they appear.

### 18.1 Pre-release sweep (v1.5.0)

| ID | Section | Correction |
|:-:|---|---|
| HARD-SEC-V15-01 | §5.36 | New section — companion install flow threat model |
| HARD-SEC-V15-02 | §5.36.3 | New — SELinux staging decision documented |
| HARD-SEC-V15-03 | §5.36.4 | New — Play Protect trap semantics documented |
| HARD-SEC-V15-04 | §3.2 | Extended — four v1.5.0 bullets |
| HARD-SEC-V15-05 | §2.1 + §4.2 | Extended — three new in-memory assets |
| HARD-SEC-V15-06 | §7.1 | Extended — install token as a distinct, additional credential |
| HARD-SEC-V15-07 | §16 | Extended — v1.5.0 changelog entry |
| HARD-SEC-V15-08 | §14.34 | New — companion install flow checklist |
| HARD-SEC-V15-09 | §17.4 | Extended — v1.5.0 additions table |
| HARD-SEC-V15-10 | §13.1 + §13.3 | Extended — v1.5.0 limitations + compensating controls |
| HARD-SEC-V15-12 | §14.1 | Rewritten — the stale v1.4.0 install-button item was replaced by the v1.5.0 behaviour |

### 18.2 Post-release sweep (v1.5.0+)

| ID | Section | Correction |
|:-:|---|---|
| HARD-SEC-V15-14 | §5.36.3 | Corrected — the trap **does** remove the staged APK on every catchable exit path |
| HARD-SEC-V15-15 | §5.36.4 | Corrected — Play Protect duration is bounded by the 75-second cascade deadline, not "< 5 s" |
| HARD-SEC-V15-16 | §12.1 | Corrected — `install_app.sh` is covered by the module ZIP's SHA-256 |
| HARD-SEC-V15-17 | §13.2 | Removed — staged-APK cleanup is now resolved |
| HARD-SEC-V15-DATE | header + footer | Date bumped to 2026-10-15 |
| HARD-SEC-V15-TRAP | §5.36.3 | Extended — three-way trap split with exit codes 130 / 143 |
| HARD-SEC-V15-SHELL | §14.34 | Corrected in eight places for BusyBox grep portability |

### 18.3 BusyBox grep portability corrections

Android ships BusyBox grep, which does not support:
  - `\b` word boundaries (treated as a literal backspace character).
  - `-A` / `-B` / `-C` context lines (GNU extensions).

The following eight runtime-audit commands in §14.34 were corrected:

| # | Was | Now |
|:-:|---|---|
| a | `grep -q 'com.gasciljh.dnsproxy\b'` | `grep -qE 'com\.gasciljh\.dnsproxy([^.]\|$)'` |
| b | `grep -A10 'func removeModule'` | `awk '/func removeModule/,/^}/'` |
| c | `grep -c 'CASCADE_DEADLINE_SECONDS'` expected 3 | expected 3-5 occurrences |
| d | `grep -E '[a-f0-9]{64}'` on log | scoped: `grep 'install_token' log \| grep -E '[a-f0-9]{32,}'` |
| e | `grep -q 'isIOSDevice'` | anchored: `grep -qE '^\s*(function isIOSDevice\|isIOSDevice\s*=)'` |
| f | `apk/` mode 0700 | corrected to 0755 (matches `mkdir -p` without explicit mode) |
| g | cascade-deadline count check | updated per (c) |
| h | awk-based replacement for `grep -A10` | added per (b) |

### 18.4 Related cross-file corrections

The following corrections are documented in sibling files. They
affect facts referenced from this document but are not themselves
corrections to `docs/SECURITY.md`.

| Identifier | File | Description |
|---|---|---|
| CHG-DOC-01 | `CHANGELOG.md` | `watchdog.sh` line count corrected 1,356 → 1,326 |
| ARCH-DOC-06 | `docs/ARCHITECTURE.md` | `proxy/` tracked-file count corrected 18 → 17 |
| SW-DOC-02 | `web/sw.js` | Endpoint re-attribution (4 endpoints = v1.5.0, not v1.4.0); IDX-24 description normalized |
| README-DOC-02 | `README.md` | Per-directory count correction |
| MAIN-REENT-01 | `proxy/main.go` | Logger three-layer split eliminates a latent deadlock on rotation failure |
| MAIN-PORTCACHE-01 | `proxy/main.go` | 30-second TTL cache for `getWebUIPort` / `getDashboardPort` |
| MAIN-DEADLOCALHOST-01 | `proxy/main.go` | `isLocalRequest` dead-branch removal |
| MAIN-APPENDHASH-01 | `proxy/main.go` | `appendDenylist` hash source aligned with `saveDenylist` |
| MAIN-CACHE-01 | `proxy/main.go` | Companion state cache invalidated unconditionally after install/uninstall |
| CIA-DEF-03 | `proxy/install_app.sh` | Three-way signal trap split with `_CLEANED_UP` re-entry guard |
| IDX-429 | `web/index.html` | Install rate-limit message rendered distinctly |
| IDX-401-DISTINCT | `web/index.html` | Install-family 401 no longer triggers the session-expired modal |
| DASH-REFRESH-01 | `web/dashboard.html` | `isRefreshing` reset on 401 |
| DASH-SESSION-RETRY-01 | `web/dashboard.html` | Session-expired primary action is a full retry |
| DASH-HINT-01 | `web/dashboard.html` | Dual-timer hint lifecycle |
| DASH-HINT-02 | `web/dashboard.html` | `scrollend` listener with fallback |
| ICON-512-SAFEZONE-01 | `web/icon-512.svg` | Shield path fits the W3C maskable safe circle |
| API-XREF-01 | `docs/API.md` | Cross-reference block for the v1.5.0++ cycle |
| HARD-SEC-XREF-01 | this file | Cross-reference block for the v1.5.0++ cycle |

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [DNSCrypt Protocol Specification](https://dnscrypt.info/protocol)
- [Magisk Security and Module Contexts](https://topjohnwu.github.io/Magisk/guides.html)
- [W3C Secure Contexts](https://w3c.github.io/webappsec-secure-contexts/)
- [MDN SameSite Cookies](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite)
- [RFC 7231 §6.5.5 — 405 Method Not Allowed](https://datatracker.ietf.org/doc/html/rfc7231#section-6.5.5)
- [RFC 6265bis — Cookies](https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis)
- [Netfilter iptables Custom Chains Best Practices](https://www.netfilter.org/documentation/)
- [Prometheus Text Format](https://prometheus.io/docs/instrumenting/exposition_formats/)
- [Go runtime/debug.SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [Android FUSE — Storage Access Framework](https://source.android.com/docs/core/storage)
- [Android SELinux — restorecon](https://source.android.com/docs/security/features/selinux)
- [Android App Signing — Package Signature Verification](https://source.android.com/docs/security/features/apksigning)
- [SHA-256 — NIST FIPS 180-4](https://csrc.nist.gov/publications/detail/fips/180/4/final)
- [CodeQL — go/path-injection query](https://codeql.github.com/codeql-query-help/go/go-path-injection/)
- [POSIX — Signals and trap](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_28)
- [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) — Companion app repository
- [Android PackageManager documentation](https://developer.android.com/reference/android/content/pm/PackageManager) — for `pm install` (v1.5.0)

---

**Last Audit Correction**: #33 (v1.0.0)
**Next expected**: #34 (in a future release)

**Last updated**: 2026-10-15
**Version**: v1.5.0
**Author**: gasciljh
