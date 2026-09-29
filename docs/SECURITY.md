# Security Policy — DNSCrypt Smart Filter

Vulnerability disclosure policy + threat model + applied protections.

**Version**: v1.2.0
**Last updated**: 2026-09-29
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh
**Contact**: [GitHub Private Vulnerability Reporting](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **No new audit corrections** — v1.2.0 is a data-preservation
>     release. The Audit Corrections Registry remains at #33 (the
>     last entry from v1.0.0).
>   • **Numbering clarification**: §5.31, §5.32, and §5.33 are
>     **SECTION** numbers in this document, **not** Audit
>     Correction numbers. They document v1.2.0's data-preservation
>     security model, its two correctness fixes, and its watchdog
>     token — none of which is an audit correction. The Audit
>     Corrections Registry remains at **#33** (see §17). New
>     audit corrections will resume at **#34** in v1.3.x.
>   • **New §5.31 — Data Preservation Security Model.** Documents
>     the 10 defensive layers, the `backupMu` serialization
>     guarantee, and the threat model for the persistent backup
>     directory at `/sdcard/dnscrypt-webui-backup/`.
>   • **New §5.32 — Recovery Mode Correctness Fix (FIX-1) and
>     Service Worker Update-Banner Fix (FIX-2).** Documents the
>     two correctness fixes that shipped with v1.2.0. Neither is
>     an exploitable vulnerability.
>     **Corrected in this revision**: the FIX-1 description now
>     reflects the actual implementation — **snapshot-and-reapply**
>     (using `$MODPATH/.recovery_snapshot/` + the new `§[9b2]`
>     block). The previous "reorder + exclude" description was
>     incorrect and has been fully replaced.
>   • **New §5.33 — Watchdog Token (WD-TOKEN).** Documents the
>     `X-Watchdog-Token` authentication that replaces the previous
>     localhost bypass on `POST /api/ensure_running_service`.
>   • §2.1 — added user-data preservation and backup-layer
>     integrity to protected assets.
>   • §3.1 — added new adversary scenarios (backup tampering,
>     recovery-mode abuse, watchdog impersonation).
>   • §3.2 — added v1.2.0 protections.
>   • §4.2 — added new backup-related assets.
>   • §11.1 — added backup event logging (auto-backup, restore,
>     rotation, orphan preservation).
>   • §11.3 — added backup-related log rotation notes.
>   • §13.2 — updated known-issues table with v1.2.0 status.
>   • §13.3 — added v1.2.0 compensating controls.
>   • §14 Security Checklist gained six new verification sections:
>     §14.25 (backup directory permissions), §14.26 (backupMu
>     serialization), §14.27 (7-field `backups` object), §14.28
>     (watchdog token), §14.29 (recovery-mode interaction),
>     §14.30 (SELinux context preservation).
>     **Corrected in this revision**: §14.29 now verifies the
>     FIX-1 snapshot-and-reapply markers
>     (`RECOVERY_SNAPSHOT_DIR` + `§[9b2]` re-apply block),
>     not the old "reorder + exclude" pattern.
>   • §16 Changelog gained a v1.2.0 entry.
>   • §17 Audit Corrections Registry header updated — v1.2.0 does
>     not extend the registry. Added §17.2 with the v1.2.0 runtime
>     additions (BAK-1..BAK-4, FIX-1, FIX-2, WD-TOKEN).
>     **Corrected in this revision**: the FIX-1 rationale in §17.2
>     now describes the snapshot-and-reapply mechanism.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']` and is never transmitted to
>     the server. Documentation remains English-only by project
>     convention. This has **no security impact** (see §5.31.7).
>   • **Encoding correction (this revision)**: fixed mojibake in
>     section markers, arrows, checkmarks, warnings, and box
>     drawing characters. All symbols now render as proper UTF-8.

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

---

## 1. Reporting a Vulnerability

### 1.1 Preferred Method

**Do not open a public GitHub Issue** — the vulnerability may be exploited before a fix is deployed.

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
v1.2.0 (or any version)

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

- **In scope**: `main.go`, shell scripts, HTML/JS, backup layer
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
| **User-data preservation** | **5 config files preserved across upgrades (v1.2.0)** |
| **Backup-layer integrity** | **`/sdcard/dnscrypt-webui-backup/` permissions + `backupMu` (v1.2.0)** |
| **Watchdog authentication** | **`X-Watchdog-Token` on `/api/ensure_running_service` (v1.2.0)** |

### 2.2 What We Do Not Protect

- **The DNS queries themselves** — visible to the DNSCrypt/DoH provider.
- **The local network** — if `BIND_ADDR=0.0.0.0`.
- **Root user** — can do anything by nature, including reading the
  persistent backup directory (`0700`, but root can bypass).
- **A root-privileged malicious app** — can read/write
  `/sdcard/dnscrypt-webui-backup/` and the watchdog token.

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
| **Malicious root app** | read/write `/sdcard/dnscrypt-webui-backup/` | tamper with user config |
| **Watchdog impersonator** | send requests to `ensure_running_service` without valid session | force DNS engine restart (fixed by WD-TOKEN in v1.2.0) |
| **Backup tamperer** | modify `.manifest.json` or files in the backup directory | inject configuration |
| **Recovery-mode abuser** | create a `recovery` trigger file | force a restore from a snapshot |

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
- **v1.2.0**: SHA256 integrity verification (advisory; see
  §5.31.4)
- **v1.2.0**: Transactional upgrade with rollback — prevents
  partial install states
- **v1.2.0**: Watchdog token (`X-Watchdog-Token`) — replaces the
  previous localhost bypass on `ensure_running_service`
- **v1.2.0**: SELinux context preservation via `restorecon` /
  `chcon` on every restored file
- **v1.2.0**: Recovery-mode snapshot-and-reapply (FIX-1) —
  preserves all 5 files even when the ZIP extraction step
  overwrites two of them

---

## 4. Assets & Trust Boundaries

### 4.1 Trust Boundaries

```text
┌────────────────────────────────────────────┐
│  Untrusted Zone                                    │
│  ┌──────────────────────────────────────┐   │
│  │  User Apps (Chrome, Games)                  │   │
│  └──────────────┬───────────────────────┘   │
│                   │ :53 DNS                        │
│  ┌─────────────▼───────────────────────┐   │
│  │  Trust Boundary 1: Firewall                │   │
│  │  (iptables IPv4 / ip6tables IPv6)          │   │
│  │  ┌────────────────────────────────┐  │   │
│  │  │  OUTPUT (nat) — clean               │  │   │
│  │  │    ├─ jump DNSCRYPT_OUT             │  │   │
│  │  │    └─ jump DNSCRYPT_OUT6            │  │   │
│  │  │                                     │  │   │
│  │  │  DNSCRYPT_OUT (custom chain)        │  │   │
│  │  │    ├─ RETURN (loopback + bootstrap) │  │   │
│  │  │    └─ DNAT → 127.0.0.1:5354        │  │   │
│  │  │                                     │  │   │
│  │  │  DNSCRYPT_OUT6 (custom chain)       │  │   │
│  │  │    ├─ RETURN (IPv6 loopback)        │  │   │
│  │  │    └─ DNAT → [::1]:5354            │  │   │
│  │  └────────────────────────────────┘  │   │
│  └──────────────┬──────────────────────┘   │
│                   │ 127.0.0.1:5354               │
│  ┌─────────────▼──────────────────────┐   │
│  │  Trusted Zone (WebUI)                     │   │
│  │  ┌───────────────────────────────┐  │    │
│  │  │  main.go :9090, :9091              │  │    │
│  │  │  + Auth, Rate limit, CSP           │  │    │
│  │  │  + CSRF (POST-only)                │  │    │
│  │  │  + Cookie-only sessions            │  │    │
│  │  │  + STATUS_FILE = "user intent"     │  │    │
│  │  │  + hasEndpoint (exact match)       │  │    │
│  │  │  + Basic Auth rate limit           │  │    │
│  │  │  + Login POST-only (NEW-1)         │  │    │
│  │  │  + /readyz localhost-only (NEW-4)  │  │    │
│  │  │  + shellQuote (NEW-5, ext. v1.1.0) │  │    │
│  │  │  + readConfPort range (NEW-3)      │  │    │
│  │  │  + auth cache 60s (NEW-6)          │  │    │
│  │  │  + rebuildMu mutex (RACE-1)        │  │    │
│  │  │  + runtime_info ports (PORT-2)     │  │    │
│  │  │  + MEM-1 memory limit (v1.1.0)     │  │    │
│  │  │  + MEM-3 monitoring port (v1.1.0)  │  │    │
│  │  │  + backupMu mutex (v1.2.0)         │  │    │
│  │  │  + watchdog token (v1.2.0)         │  │    │
│  │  │  + createAutoBackup (v1.2.0)       │  │    │
│  │  └───────────────────────────────┘  │    │
│  └────────────────────────────────────┘    │
│                   │ exec                          │
│  ┌─────────────▼─────────────────────┐     │
│  │  Trust Boundary 2: Shell Scripts (root)  │     │
│  │  + getSystemShell() fallback (Fix #2)    │     │
│  │  + shellQuote() for dynamic paths        │     │
│  │  + copy_with_context (v1.2.0)            │     │
│  │  + 10 defensive layers (v1.2.0)          │     │
│  │  + §[8a] + §[9b2] (FIX-1, v1.2.0)        │     │
│  └───────────────────────────────────┘      │
│                   │ copy/restore                  │
│  ┌─────────────▼─────────────────────┐     │
│  │  Trust Boundary 3: Persistent Backup     │     │
│  │  /sdcard/dnscrypt-webui-backup/          │     │
│  │  + mode 0700 / 0600                      │     │
│  │  + SHA256 manifest (advisory)            │     │
│  │  + transactional txn-* / orphan-txn-*    │     │
│  └───────────────────────────────────┘      │
└────────────────────────────────────────────┘
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
| **Memory limit state** | **memory (per-profile)** | **Low (v1.1.0)** |
| **Watchdog token** | **`$RUN_DIR/.watchdog_token` (mode 0600)** | **High (v1.2.0)** |
| **Persistent backups** | **`/sdcard/dnscrypt-webui-backup/`** | **High (v1.2.0)** |
| **Backup manifest** | **`<snap>/.manifest.json`** | **Medium (v1.2.0)** |
| **`.last_stable` pointer** | **`/sdcard/dnscrypt-webui-backup/.last_stable`** | **Low (v1.2.0)** |
| **`.upgrade_history.json`** | **`/sdcard/dnscrypt-webui-backup/.upgrade_history.json`** | **Medium (v1.2.0)** |
| **`txn-*` / `orphan-txn-*`** | **`/sdcard/dnscrypt-webui-backup/`** | **High (v1.2.0)** |
| **`.recovery_snapshot/` (transient)** | **`$MODPATH/.recovery_snapshot/`** | **High (v1.2.0, cleaned up by §[9b2])** |

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
In older versions, `toggle` and `restart` endpoints were accessible via GET. `SameSite=Lax` sends cookies on top-level GET navigation, allowing CSRF:

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
| **login** | GET or POST | **POST only** |
| **logout** | GET or POST | **POST only** |

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
  - `textContent` instead of `innerHTML`

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

### 5.6 Brute Force

- **Vector**: 10,000 login attempts.
- **Mitigation**:
  - 5 attempts / IP / 15 min
  - Intentional delay
  - `LOGIN_ATTEMPT_STALE_PERIOD = 1h`
  - **Fix #8**: includes Basic Auth (was unlimited)

### 5.7 Memory Exhaustion

- **Vector**: POST 1 GB to `/api/save_allowlist`.
- **Mitigation**:
  - `MaxBytesReader(5 MB)`
  - `io.LimitReader(50 MB)` for downloads
  - `limitedBuffer` (2048 bytes) for stderr capture

- **v1.1.0 addition — GC pressure as a DoS vector**:
  - Prior to v1.1.0, `debug.SetMemoryLimit(80 MB)` was hardcoded.
    On the `ultimate` profile, this caused GC thrashing.
  - v1.1.0 replaces the hardcoded value with a per-profile
    limit set by `memoryLimitForProfile()`:
    light=80 MB, normal=100, pro=120, proplus=160, ultimate=220.
  - This is a defense-in-depth measure: it does not fix a
    vulnerability, but it removes a self-inflicted DoS surface.

- **v1.2.0 addition — bounded backup disk usage**:
  - Rotation caps the number of snapshots at 21.
  - Each snapshot uses ~30–100 KB → total footprint ~2.5 MB max.
  - A malicious caller cannot force an unbounded backup growth:
    `createAutoBackup` is serialized by `backupMu` and rotation
    runs after each successful backup.

### 5.8 Timing Attacks

- **Vector**: measure response time to guess the password.
- **Mitigation**:
  - Use `subtle.ConstantTimeCompare`
  - **v1.2.0**: watchdog token comparison also uses
    `subtle.ConstantTimeCompare`

### 5.9 DNS Leak (Audit Correction #3 + #16)

**Background**:
dnscrypt-proxy queries `bootstrap_resolvers` directly on port 53 to download the server list. If they are not excluded from DNAT, a loop occurs:
- packet leaves → DNAT → 127.0.0.1:5354 → dnscrypt-proxy → loop.

**Solution applied**:
- 3-e: `awk` reads multi-line TOML.
- 3-f: IPv6 support in `get_dynamic_bootstrap`.
- 16-a: `manage_iptables` skips IPv6 (`case "$_ip" in *:*) continue`).
- 16-b: `manage_ip6tables` uses `::1` + `$BOOTSTRAP_IPS` with IPv4 filtering.

**Result**:

| Protocol | Firewall | Bootstrap handling |
|---|---|---|
| IPv4 | iptables | ✅ (with IPv6 filtering) |
| IPv6 | ip6tables | ✅ (with IPv4 filtering) |
| Any | nftables | ✅ (case filter) |

### 5.10 SSE DoS (Slow Client)

- **Vector**: 10,000 SSE connections with slow consumption to freeze the server.
- **Mitigation**: `SetWriteDeadline(30 s)` before each flush
  (see §5.10 full detail in v1.0.0 docs). Slow clients are
  disconnected.

### 5.11 Token Leakage (Audit Correction #15-a)

- **Vector**: XSS can read the token from a JSON response or JS storage.
- **Mitigation**:
  - No `sessionStorage`
  - No token in login response
  - HttpOnly cookie only

### 5.12 405 Method Not Allowed — RFC Compliance (Audit Correction #15-b)

- **Vector**: non-compliance with RFC 7231 §6.5.5.
- **Mitigation**:
  - `Allow: POST` header on 405
  - `Allow: GET, POST, OPTIONS` on OPTIONS response

<a name="513"></a>
### 5.13 Firewall Orphan Leak (Audit Correction #17)

**Background**:
The original release added dynamic RETURN rules directly to the public OUTPUT chain. When `bootstrap_resolvers` changed, old RETURN rules were left behind.

**Solution (Custom Chains)**:
- `DNSCRYPT_OUT` (IPv4) and `DNSCRYPT_OUT6` (IPv6) in `functions.sh`.
- `_inline_cleanup_firewall` unified in 3 files (`post-fs-data.sh`, `uninstall.sh`, `customize.sh`).
- `_legacy_cleanup_*` for upgrades from older versions (best-effort).

**Golden rule**:
Never pollute a public chain (OUTPUT/INPUT/FORWARD) with dynamic rules.
Use a dedicated Custom Chain — deleting it wipes all its rules.

<a name="514"></a>
### 5.14 State Integrity — STATUS_FILE Semantics (Audit Correction #18)

**Background**:
`STATUS_FILE` was written by `getStatusUncached` and by
`startService`/`stopService`. This conflict lost the "user intent"
meaning on crash.

**Solution**: `STATUS_FILE` is **read-only** with respect to
`getStatusUncached` — written only by `startService` /
`stopService`.

**Architectural contract**:

| Question | Answer |
|---|---|
| Meaning of STATUS_FILE | "User intent" |
| Who writes it? | `startService` / `stopService` only |
| Who reads it? | `getStatus`, Watchdog, `status.sh` |
| What happens on crash? | `STATUS_FILE` stays "ON" → Watchdog restarts |

<a name="515"></a>
### 5.15 IPv6 Rate Limit Bypass (Audit Correction #19)

**Solution**: `getClientIP(r)` uses `net.SplitHostPort` — IPv6
addresses like `[::1]:port` map to `::1` (not `[`).

<a name="516"></a>
### 5.16 Port Collision (Audit Correction #20)

**Solution**: `MONITORING_UI_PORT` constant. `main.go` refuses to
start if `PORT` or `DASHBOARD_PORT` = 8080.

**v1.1.0 addition**: `metricsProxyHandler` uses the constant —
no more hardcoded `"8080"` (see §5.30.3).

<a name="517"></a>
### 5.17 TOML Parsing — Section Injection (Audit Correction #21)

**Solution**: Section tracking (`inSection` boolean) in all 4 files
(`main.go`, `functions.sh`, `watchdog.sh`, `customize.sh`).

<a name="518"></a>
### 5.18 Basic Auth Rate Limit Bypass (Fix #8 / Audit #22)

**Solution**: `checkAuth` now records failed Basic Auth attempts in
`loginAttempts`. 5 attempts / 15 min lockout per IP.

<a name="519"></a>
### 5.19 Section Header with Comment (parsing) (Fix #10 / Audit #23)

**Solution**: Section detection uses `strings.Index(trimmed, "]")`
instead of `HasSuffix("]")` — supports `[monitoring_ui] # comment`.

<a name="520"></a>
### 5.20 Dashboard JSON Conversion (Fix #1 / Audit #25)

**Solution**: `parsePrometheus()` + `buildDashboardJSON()` convert
Prometheus text to JSON.

<a name="521"></a>
### 5.21 Preserve User Settings on Upgrade (Fix #3 / Audit #26)

**v1.0.0 solution**: Backup/restore around `unzip -o` for the 5
config files (mechanism: `/data/local/tmp/dnscrypt-upgrade-backup-$$`).

**v1.2.0 supersession**: The v1.0.0 mechanism is **superseded** by
the 10 defensive layers documented in §5.31. The v1.0.0 mechanism
had two limitations:
- `/data/local/tmp/` is cleared on reboot.
- `/data/local/tmp/` is deleted on uninstall.

The v1.2.0 persistent backup at `/sdcard/dnscrypt-webui-backup/`
survives reboot, uninstall, and factory reset of `/data`.

<a name="522"></a>
### 5.22 `fuser` PID Parsing (Fix #9 / Audit #27)

**Solution**: `fuser -n tcp "$port" | tr ' ' '\n' | grep -E
'^[0-9]+$' | head -n1` — one PID per line, numbers only.

<a name="523"></a>
### 5.23 Login POST-Only (Fix NEW-1 / Audit #28)

**Solution**: `/api/auth/login` and `/api/auth/logout` reject
non-POST requests with 405 + `Allow: POST`.

<a name="524"></a>
### 5.24 `readConfPort` Range Check (Fix NEW-3 / Audit #29)

**Solution**: `readConfPort` validates range `[1, 65535]`.

<a name="525"></a>
### 5.25 `/readyz` Localhost-Only (Fix NEW-4 / Audit #30)

**Solution**: `handleReadyz` rejects non-localhost requests with
`{"error": "readyz is localhost-only"}`.

<a name="526"></a>
### 5.26 `shellQuote` Injection Protection (Fix NEW-5 / Audit #31)

**v1.0.0**: 20-character escape set.
**v1.1.0**: Extended to 24 characters — see §5.30.2.

<a name="527"></a>
### 5.27 Auth Cache (60 s) (Fix NEW-6 / Audit #32)

**Solution**: `getMonitoringAuth` caches credentials in memory for
60 seconds. Empty results are **never** cached (BUG-C fix).

<a name="528"></a>
### 5.28 Rebuild Blocklist Mutex (RACE-1) (Audit #33)

**Solution**: `rebuildMu sync.Mutex` protects the entire
`rebuildBlocklist` function. Coarse-grained locking; no deadlock.

**v1.2.0 parallel**: `backupMu` uses the same pattern for
`createAutoBackup` — see §5.31.3.

<a name="529"></a>
### 5.29 Runtime Info Ports (PORT-2)

**Solution**: `buildRuntimeInfo()` returns `webui_port` +
`dashboard_port`. Frontend uses `window.location.hostname` to
build links dynamically.

<a name="530"></a>
### 5.30 v1.1.0 — Security-Relevant Runtime Changes

**v1.1.0 does not add new audit corrections.** It is a
documentation + polish release. However, three runtime changes
have a security-relevant dimension and are documented here for
completeness.

#### 5.30.1 Dynamic Memory Limit per Profile (MEM-1)

**Background**:

```go
// Before v1.1.0 (main.go, top of main()):
debug.SetMemoryLimit(80 * 1024 * 1024)  // ← hardcoded 80 MB
```

**Problem**: On the `ultimate` profile, the working set exceeds
80 MB during `rebuildBlocklist`. The Go runtime runs GC
continuously → CPU waste → WebUI appears frozen on low-RAM
devices.

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
`profile_key`. Displayed in both WebUI and Dashboard System Info
panels.

**Security rationale**: Removes a self-inflicted DoS surface. The
limit is **soft** — a breach does not OOM the process.

#### 5.30.2 Extended `shellQuote` Character Set (MEM-2)

**Background**:

The v1.0.0 `shellQuote` escaped 20 shell-significant characters.
Four were not escaped:
- `{`, `}` — brace expansion.
- `\n`, `\t` — word-splitting.

**Practical impact today**: `MODDIR` is derived from
`os.Executable()`. A normal user cannot make it contain `{` or
`\n`. No known exploitable path exists.

**Solution**:

```go
// After v1.1.0:
func shellQuote(s string) string {
    for _, r := range s {
        if r == ' ' || r == '"' || r == '\'' || r == '$' || r == '`' ||
            r == '\\' || r == '!' || r == '&' || r == '|' || r == ';' ||
            r == '(' || r == ')' || r == '<' || r == '>' || r == '*' ||
            r == '?' || r == '[' || r == ']' || r == '#' || r == '~' ||
            r == '{' || r == '}' || r == '\n' || r == '\t' {
            return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
        }
    }
    return s
}
```

**Security rationale**: Defense-in-depth. No known exploit existed.

#### 5.30.3 `MONITORING_UI_PORT` in Metrics Handler (MEM-3)

**Background**:

```go
// Before v1.1.0 (metricsProxyHandler):
req, err := http.NewRequestWithContext(r.Context(), "GET",
    "http://127.0.0.1:8080/api/metrics", nil)
//   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ hardcoded "8080"
```

**Solution**:

```go
// After v1.1.0:
monitoringURL := "http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"
```

**Security rationale**: Single source of truth. Reduces the
number of files to audit if the port ever changes.

<a name="531"></a>
### 5.31 v1.2.0 — Data Preservation Security Model

> **ℹ️ Section numbering note**: §5.31 is a **section number in
> this document**, not an Audit Correction number. The Audit
> Corrections Registry (§17) remains at **#33**. See the
> clarification at the top of this file, and §17.2 for the list
> of v1.2.0 additions that do **not** receive audit correction
> numbers.

**Background**:

Prior to v1.2.0, the installer used a path-comparison check
(`$_EXISTING_MODULE != $MODPATH`) to detect upgrades. On
**in-place upgrades** (the most common case), this check silently
failed: the installer thought it was a fresh install and overwrote
the 5 user config files with defaults.

**Impact** (v1.1.0 and earlier):

- 🔴 **Silent data loss** on every in-place upgrade.
- 🔴 Users lost hours of manual rule configuration.
- 🔴 The same bug affected folder renames, reinstalls, and
  KernelSU/APatch installs.

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

**Design philosophy**: *"Search for user data everywhere — do not
guess whether this is an upgrade."*

#### 5.31.1 Multi-Source Detection (Layer 1)

The installer searches **7 candidate locations** for the 5 user
config files:
1. `$MODPATH/proxy` (in-place).
2. `/data/adb/modules/dnscrypt-proxy-webui/proxy` (standard).
3. `/data/adb/modules/DNSCrypt-Proxy-Webui/proxy` (legacy).
4. `/data/adb/modules/DNSCrypt-Proxy-WebUI/proxy` (variant).
5. `$PERSISTENT_BACKUP/current` (persistent).
6. `$PERSISTENT_BACKUP` (flat).
7. `/data/local/tmp/dnscrypt-webui-backup` (tmp fallback).

On APatch, two `modules_update/` paths are **prepended** to the
list (Layer 5).

**Selection rule**: The first candidate with **≥ 3 valid files**
wins. A candidate with fewer than 3 files is skipped.

**Security rationale**: The installer never trusts a single path.
Even if a root solution renames or deletes the module folder, the
user data is still findable.

#### 5.31.2 Persistent Backup (Layer 2)

**Location**: `/sdcard/dnscrypt-webui-backup/`.

**Why this location**:
- ✅ Survives reboot (`/data/local/tmp/` does not).
- ✅ Survives module uninstall (`/data/adb/` does not).
- ✅ Survives factory reset of `/data` (`/data/adb/` does not).
- ✅ Visible from any file manager + over USB (MTP).

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

**Note**: On Android, `/sdcard/` is typically a FUSE mount.
Permission semantics differ from ext4. The `0700`/`0600` modes
are enforced by the FUSE layer where possible; the primary
protection is that `/sdcard/` is only accessible to apps with
`READ_EXTERNAL_STORAGE` or root.

**Rotation**: Keep the 21 newest snapshots, sorted by directory
name (not mtime). Total footprint bounded to ~2.5 MB.

**Uninstall policy**: The backup directory is **preserved** on
uninstall. A future reinstall can restore the user's settings
automatically (via Layer 1). A user can remove it manually with
`rm -rf /sdcard/dnscrypt-webui-backup`.

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

**Rationale**: Two rapid user actions (e.g. two `save_allowlist`
requests) could each trigger `createAutoBackup` on the same source
directory. Without serialization, this could corrupt a snapshot
(interleaved writes to `.manifest.json` and `.tmp` files).

**Bounded duration**: The lock is held for at most
`AUTO_BACKUP_TIMEOUT = 15 s` per call.

**Best-effort**: A failed backup logs a warning but never blocks
the user's action.

#### 5.31.4 Integrity Verification (Layer 3)

**Checks**:
1. **Non-empty**: File exists and has size > 0.
2. **Not oversized**: File size < 10 MB.
3. **SHA256 (advisory)**: `.manifest.json` records each file's
   hash. A mismatch is **logged as a warning** but does **not**
   block a restore.

**Why advisory**: The snapshot was just created from the same
source. A mismatch would indicate a filesystem issue, but
refusing to restore would be worse than restoring with a
warning.

**3-tier hash extraction**: `jq` → `awk` → `grep`/`sed`. If none
succeeds (e.g. `sha256sum` unavailable), the check is **skipped
for that file** rather than failing.

**Threat model coverage**:

| Threat | Mitigation |
|--------|-----------|
| Bit rot in a snapshot | SHA256 in `.manifest.json` (advisory) |
| Empty/truncated file | Non-empty + size checks |
| Malicious file substitution | Not mitigated (root-only directory) |
| Unauthorized read | `0700`/`0600` permissions |

#### 5.31.5 Transactional Upgrade (Layer 4)

**State machine**:
- `START` — install in progress or interrupted.
- `COMMIT` — install succeeded, cleanup skipped.
- `ROLLBACK` — rollback applied.

**Behavior**:
- On failure, an automatic rollback restores the previous state.
- Leftover `COMMIT`'d transactions are cleaned by
  `cleanupOldTransactions()` at startup.
- `START` transactions are preserved as `orphan-txn-*` on
  uninstall.

**Security rationale**: Prevents partial install states where the
module has neither the old nor the new configuration.

#### 5.31.6 SELinux Context Preservation (Layer 6)

**Preferred**: `restorecon` (reads `file_contexts`).
**Fallback**: `chcon u:object_r:magisk_file:s0`.

**Rationale**: A file copied to `/data/adb/` without its original
SELinux context may be unreadable by the WebUI process on
SELinux-enforcing ROMs.

#### 5.31.7 Language Toggle — Security Considerations

The WebUI's bilingual feature (English default + Arabic toggle)
is a **client-side only** concern. From a security standpoint:

- **No server state**: The language preference lives in
  `localStorage['dnscrypt-lang']` and is never transmitted to the
  API.
- **No new network requests**: The toggle only manipulates the
  DOM.
- **No SW cache pollution**: The Service Worker caches the HTML
  **once**. Both `translations.en` and `translations.ar` objects
  are inline in the same file.
- **No XSS regression**: All translated strings pass through
  `textContent` / `escapeHtml()`.
- **No CSP change**: The in-page toggle does not require
  `'unsafe-inline'` beyond what already existed.

#### 5.31.8 Data-Preservation Threat Model Summary

The backup system assumes:

- ✅ The device is rooted.
- ✅ `/sdcard/` is mounted and writable by root.
- ❌ The backup directory is **not** protected from a malicious
  root app.

**`backupMu` guarantee**: Two concurrent calls to
`createAutoBackup` cannot corrupt a snapshot.

**What `backupMu` does NOT protect against**:
- A user manually running `action.sh --backup` while the WebUI is
  also triggering a pre-critical backup. `action.sh` is a shell
  script; it does not coordinate with `main.go`'s mutex. In
  practice this is safe because the shell script uses
  `<pid>`-suffixed directory names and atomic writes for the
  manifest. The worst case is a duplicate snapshot directory,
  which rotation will eventually clean up.

<a name="532"></a>
### 5.32 v1.2.0 — Correctness Fixes (FIX-1, FIX-2)

> **ℹ️ Section numbering note**: §5.32 is a **section number in
> this document**, not an Audit Correction number. FIX-1 and
> FIX-2 are correctness fixes, not security vulnerabilities. See
> §17.2 for the complete list of v1.2.0 additions that do **not**
> extend the Audit Corrections Registry.

**Neither FIX-1 nor FIX-2 is an exploitable vulnerability.** They
are correctness fixes that shipped with v1.2.0. Both were caught
during the pre-release audit.

#### 5.32.1 Recovery Mode Correctness Fix (FIX-1)

**The bug** (early v1.2.0 draft only):

The ZIP extraction step (`customize.sh §[9]`) ran **after** the
recovery restore (`§[8a]`) and overwrote `webui.conf` and
`dnscrypt-proxy.toml` with the ZIP's defaults. The subsequent
restore step (`§[9c]`) was skipped in recovery mode, so the
corrupted files were never re-fixed.

**Result**: 2 of the 5 restored files were silently lost during
recovery.

**The fix (FIX-1) — snapshot-and-reapply strategy**:

Rather than reordering the ZIP extraction steps (which would
require maintaining a duplicate exclusion list that depends on
knowing the ZIP's contents), the final v1.2.0 release uses a
**snapshot-and-reapply** approach:

| Phase | Section | What happens |
|---|---|---|
| **A** | `§[8a]` | Restore 5 files from `$RESTORE_SOURCE` into `$MODPATH/proxy/` **AND** copy each file to `$MODPATH/.recovery_snapshot/` |
| **B** | `§[9]` | Extract the ZIP normally. This overwrites `webui.conf` and `dnscrypt-proxy.toml` with the ZIP's defaults (unavoidable without knowing the ZIP's contents) |
| **C** | `§[9b]` | Move root-level web assets into `web/` |
| **D** | `§[9b2]` | Re-apply the 5 files from `$MODPATH/.recovery_snapshot/` back into `$MODPATH/proxy/` |
| **E** | `§[9c]` | Skipped when `RECOVERY_MODE=1` — already handled by A + D |

**Why snapshot-and-reapply over "reorder + exclude"**:

- It does **not** depend on knowing what the ZIP contains. If a
  future release adds or removes files under `proxy/`, the fix
  keeps working.
- It keeps the extraction logic of `§[9]` **untouched**, so the
  normal-install path is byte-for-byte identical to the
  pre-recovery behavior.
- The snapshot directory uses `$MODPATH/.recovery_snapshot/`
  (dot-prefixed, cleaned up in `§[9b2]`), so it never appears in
  the final module layout.

**Partial re-application**: If `[9b2]` re-applies fewer files
than were snapshotted (e.g. one file is missing or empty), the
snapshot directory is **preserved** at
`$MODPATH/.recovery_snapshot/` so the user can recover the
remaining files manually.

**Security rationale**: The bug was a **data-loss** issue, not an
exploitable vulnerability. However, in a disaster-recovery
scenario (the only scenario where FIX-1 matters), silent data loss
would leave the user without their configuration — a
security-relevant outcome for a project whose primary goal is
"protected DNS".

**Verify you are on the fixed version**:

```bash
# 1. Module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# → must be version=v1.2.0

# 2. The snapshot directory constant must be present
su -c "grep -q 'RECOVERY_SNAPSHOT_DIR' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (snapshot dir)'"

# 3. The re-apply block (§[9b2]) must be present
su -c "grep -q 'Re-applying recovery snapshot' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (§[9b2] re-apply block)'"
```

**If the fix is missing**: reinstall the module from the v1.2.0 ZIP.

#### 5.32.2 Service Worker Update-Banner Fix (FIX-2)

**The bug (v1.1.0)**: The [Reload] button in the SW update banner
sent `SKIP_WAITING` to `navigator.serviceWorker.controller` — the
**old** worker — which ignored it. The new worker stayed in the
`waiting` state, so the banner reappeared on every page reload →
infinite loop.

**The fix (v1.2.0)**:
- Send `SKIP_WAITING` to `swRegistration.waiting` (the **new**
  worker).
- Reload on the `controllerchange` event.
- Guard double-clicks with a `pendingReload` flag.
- Applied to **both** `index.html` and `dashboard.html`.

**Security rationale**: Not exploitable. The v1.1.0 bug was a
usability regression. The v1.2.0 fix completes the v1.1.0 change
that only applied to `index.html`.

**Verify**:

```bash
su -c "grep -q 'swRegistration.waiting' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && \
       echo '✅ index.html'"
su -c "grep -q 'swRegistration.waiting' /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html && \
       echo '✅ dashboard.html'"
```

<a name="533"></a>
### 5.33 v1.2.0 — Watchdog Token (WD-TOKEN)

> **ℹ️ Section numbering note**: §5.33 is a **section number in
> this document**, not an Audit Correction number. WD-TOKEN is a
> defensive hardening of an existing endpoint, not a new audit
> correction. See §17.2 for the complete list of v1.2.0 additions
> that do **not** extend the Audit Corrections Registry.

**Background**:

The watchdog (`watchdog.sh`) needs to call
`POST /api/ensure_running_service` to recover a crashed DNS
engine.

**Before v1.2.0**: The endpoint was protected only by an implicit
"localhost bypass" — any web page loaded in a browser on the same
device could silently trigger a service restart via a CSRF
attack.

**Problem — CSRF via `<img>` tag**:

```html
<!-- This request is silently sent by the browser -->
<img src="http://127.0.0.1:9090/api/ensure_running_service">
```

Even though the endpoint is POST-only (see §5.2), the implicit
localhost bypass meant no authentication was required — any
page loaded in a browser on the same device could trigger it if
it used a POST.

**v1.2.0 solution — token authentication**:

```text
┌──────────────────────────────────────────────────────┐
│  Token lifecycle                                     │
│                                                      │
│  1. customize.sh §[19b] generates a 64-hex token     │
│     during install and writes it to:                 │
│         $RUN_DIR/.watchdog_token   (mode 0600)       │
│                                                      │
│  2. If the file is missing, main.go creates it on    │
│     the next run via loadOrCreateWatchdogToken().    │
│                                                      │
│  3. watchdog.sh reads the file on every API call     │
│     (no cache) and sends it as:                      │
│         X-Watchdog-Token: <token>                    │
│                                                      │
│  4. main.go verifyWatchdogToken() compares the       │
│     header against the file using                    │
│     subtle.ConstantTimeCompare.                      │
│                                                      │
│  5. On mismatch or missing header → 401.             │
└──────────────────────────────────────────────────────┘
```

**Characteristics**:

- **Localhost-scoped**: `isLocalRequest` is still required; a
  remote request with a valid token is rejected.
- **Constant-time**: no timing leak on comparison.
- **Not rate-limited**: token requests bypass the login
  limiter, so a flapping DNS engine does not lock the watchdog
  out.
- **Persistent**: the token file survives restarts. It is
  regenerated only if the file is missing.
- **Fail-closed**: if the token file is missing and no token is
  sent, the request falls back to normal user auth — which the
  watchdog does not have — so the request is rejected.

**Threat model coverage**:

| Threat | Mitigation |
|---|---|
| CSRF from a browser page | Requires `X-Watchdog-Token` header (not settable via `<img>`/`<form>`) |
| Impersonation by a non-root app | Token file is `0600`, owned by root |
| Token leak via timing | `subtle.ConstantTimeCompare` |
| Token leak via logging | Token is never logged |
| Replay | Token is a shared secret; no nonce. Rate limiting is not applied, but the endpoint only restarts the DNS engine. |

**Note**: The token file is excluded from the 5-file preservation
set (it is a runtime secret, not user config). If the file is
deleted, `main.go` regenerates it on the next run and
`watchdog.sh` picks it up on its next API call.

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

| BIND_ADDR | Secure | Reason |
|---|---|---|
| 127.0.0.1 | ✅ true | Secure Context |
| ::1 | ✅ true | Secure Context |
| localhost | ✅ true | Secure Context |
| 0.0.0.0 | ❌ false | Not a Secure Context |
| 192.168.x.x | ❌ false | Same reason |

#### 6.3.3 SameSite=Lax

| Value | Top-level GET | Cross-site POST | Cross-site GET |
|---|---|---|---|
| None | ✅ | ✅ | ✅ |
| Lax | ✅ | ❌ | ❌ |
| Strict | ❌ | ❌ | ❌ |

Reasons for Lax:
- Strict breaks PWA shortcuts.
- Lax + POST-only endpoints = full CSRF protection.

#### 6.3.4 HttpOnly
- JavaScript cannot read it.
- Prevents XSS from stealing the session.

### 6.4 Known Limitation: CSP `'unsafe-inline'`

**Current state**:

```http
script-src 'self' 'unsafe-inline';
style-src 'self' 'unsafe-inline';
```

**Reason**:
- Inline event handlers (`onclick="..."`) in HTML.

**Security impact**:
- Reduces XSS protection.
- But CSP is strict in other aspects (`frame-ancestors 'none'`, `object-src 'none'`).
- All scripts come from 'self'.
- No user input is inserted directly into innerHTML.

**TODO**: remove `'unsafe-inline'` — deferred to **v1.3.0**.
**Solution**: convert `onclick` to `addEventListener`.

---

## 7. Authentication

### 7.1 Supported Schemes

| Scheme | Priority | Rate Limited | Persistence |
|---|---|:---:|---|
| Basic Auth | 1 | Yes | per-request |
| Bearer Token | 2 | No | 24h (for compatibility) |
| Session Cookie | 3 | No | 24h (primary) |
| **Watchdog Token** | **4** | **No** | **per-request (v1.2.0)** |

**Audit Correction #15-a**:
- No token in login response.
- HttpOnly cookie only.
- `getStoredToken()` = no-op in the client.

**Fix #8**:
- Basic Auth protected by rate limiting.
- 5 failed attempts → 15-min lockout.

**Fix NEW-1**:
- `/api/auth/login` POST only.
- `/api/auth/logout` POST only.
- 405 + `Allow: POST` for non-POST.

**Fix NEW-6**:
- Auth cache (60 s) — reduces file I/O.

**v1.2.0 — Watchdog Token (WD-TOKEN)**:
- `X-Watchdog-Token` header for `/api/ensure_running_service`.
- Localhost-scoped.
- Constant-time comparison.
- Not rate-limited.
- See §5.33 for the full design.

### 7.2 Credentials Source

From `dnscrypt-proxy.toml` (`[monitoring_ui]` section only):

```toml
[monitoring_ui]
username = 'admin_xxxxxxxx'
password = 'xxxxxxxxxxxxxxxxxxxxxxxx'
```

Generated automatically in `customize.sh`:
- Refuse admin/admin.
- 24-char password.
- 8-char suffix for the username.

**Fix E**: reading from `[monitoring_ui]` only (section tracking).

**Fix #10**: support for section header with comment.

**Fix NEW-6**: cache read (60 s TTL).

**v1.2.0**: The credentials are also preserved in the persistent
backup at `/sdcard/dnscrypt-webui-backup/current/dnscrypt-proxy.toml`.

### 7.3 Constant-time Comparison

```go
userMatch := subtle.ConstantTimeCompare([]byte(user), []byte(expectedUser)) == 1
passMatch := subtle.ConstantTimeCompare([]byte(pass), []byte(expectedPass)) == 1
```

**v1.2.0**: The watchdog token also uses
`subtle.ConstantTimeCompare` (see §5.33).

### 7.4 Rate Limiting

- 5 failed attempts per IP.
- 15-minute lockout.
- `LOGIN_ATTEMPT_STALE_PERIOD = 1h` — cleanup of old IPs.
- `getClientIP()` — IPv6 support in the key.
- **Fix #8**: Basic Auth protected by the same mechanism.
- **v1.2.0**: Watchdog token requests bypass the limiter (a
  flapping DNS engine does not lock the watchdog out).

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
| **PORT/DASHBOARD_PORT** | **1–65535** | **readConfPort** |
| **backup reason (v1.2.0)** | **fixed set** | **`createAutoBackup(reason)` callers** |
| **backup dir name (v1.2.0)** | **`<ts>-<type>-<pid>[-<rand4>]`** | **`createAutoBackup` generator** |

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
- **v1.2.0**: The `reason` string passed to `createAutoBackup` is
  never used in a shell command — it is only used in the log
  line. The backup directory name is generated by `main.go`,
  not by the caller.

### 9.4 Endpoint Matching

- `hasEndpoint()` — exact matching.
- No `strings.Contains`.
- No `strings.HasPrefix` (with a single path).
- Only `path == "/api/NAME"` or `path == "/api/NAME/"`.

---

## 10. Cryptography

### 10.1 Library

- Standard Go library only (`crypto/*`).
- No external dependencies.

### 10.2 Algorithms

| Usage | Algorithm |
|---|---|
| Session token | crypto/rand (CSPRNG) |
| **Watchdog token (v1.2.0)** | **crypto/rand (CSPRNG), 32 bytes** |
| Content hash | SHA-256 |
| **Backup integrity hash (v1.2.0)** | **SHA-256 (via `sha256sum`)** |
| Password compare | subtle.ConstantTimeCompare |
| **Watchdog token compare (v1.2.0)** | **subtle.ConstantTimeCompare** |
| TLS (downloads) | TLS 1.2+ |
| Temp files | os.CreateTemp (CSPRNG-based) |

### 10.3 Not Present

- No blocklist encryption (public data).
- No log encryption.
- No credential file encryption.
- **No backup encryption** (v1.2.0) — the backup directory is
  `0700`, owned by root. Encrypting it would require a key
  storage mechanism that does not exist on Android.

*(All data is local on a root-enabled device.)*

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
  Example: `memory limit adjusted: 80 MB → 120 MB (profile=pro)`
- **v1.2.0 — backup events**:
  - `createAutoBackup`: log line with the reason string
    (`pre-profile-change`, `pre-allowlist-save`, etc.).
  - `cleanupOldTransactions`: number of `COMMIT`'d dirs
    removed.
  - `checkPendingNotifications`: content of
    `.pending_notification` (then removed).
  - Rotation: number of snapshots kept (21).
  - Restore: number of files restored.
- **v1.2.0 — recovery-mode events**:
  - `§[8a]`: restore + snapshot to `$MODPATH/.recovery_snapshot/`.
  - `§[9b2]`: re-apply from the snapshot.
  - Partial re-application leaves the snapshot in place.
- **v1.2.0 — watchdog token events**: token generation,
  regeneration on missing file. The **token value itself is
  never logged**.

### 11.2 What We Do Not Log

- DNS queries.
- Passwords explicitly.
- Session tokens.
- **Watchdog token (v1.2.0)**.
- Browsing history.
- **Backup file contents**.

### 11.3 Log Rotation

| Log | Threshold | Retention |
|---|---|---|
| dnscrypt_main.log | 1 MB | 5 .gz |
| dnscrypt-proxy.log | 6 MB | 3 days |
| dnscrypt-blocked.log | — | user-managed |
| **Backup logs (v1.2.0)** | **in `dnscrypt_main.log`** | **same rotation** |
| **`.upgrade_history.json` (v1.2.0)** | **not rotated** | **append-only** |

### 11.4 Privacy Guarantee

- Zero telemetry.
- No connection to any server other than DNSCrypt/DoH servers.
- **v1.2.0**: The persistent backup directory is **not** synced
  to any remote server. It lives on `/sdcard/` only.

---

## 12. Supply Chain

### 12.1 Dependencies

| Component | Source | Signing |
|---|---|---|
| Go stdlib | golang.org | ✓ |
| DNSCrypt-proxy | GitHub releases | ✓ (checksums) |
| HaGeZi blocklists | cdn.jsdelivr.net | — |
| Sigstore/Cosign | GitHub Actions | ✓ |

### 12.2 Build Security

- Reproducible builds (SOURCE_DATE_EPOCH).
- Signed releases (Cosign keyless).
- SBOM (SPDX + CycloneDX).
- Attestations via GitHub Actions.
- **v1.2.0**: The 42-scenario `upgrade-test.yml` matrix validates
  the 10 defensive layers before release.

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
| **Backup directory readable by root** | **Nature of the system (v1.2.0)** |
| **SHA256 backup check is advisory** | **Deliberate: never blocks a restore (v1.2.0)** |

### 13.2 Known Issues (will be fixed)

| Issue | Proposed fix | Version |
|---|---|---|
| CSP `'unsafe-inline'` | Convert onclick → addEventListener | v1.3.0 |
| `pgrep -x` on Android 5.x | fallback | v1.3.0 |
| awk with `]` in comment | improve parser | v1.3.0 |
| PWA dual-origin (9090 vs 9091) | unify on one port | v1.3.0 |
| `manifest.json` shortcuts do not read `runtime_info` | unify on one port | v1.3.0 |
| Maskable icon reuses `icon-512.png` | ship dedicated maskable SVG | v1.3.0 |
| **Backup integrity is advisory** | **opt-in enforcing mode** | **v1.3.0** |
| **`append_denylist` not used by WebUI** | **send `content` parameter** | **v1.3.0** |

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
- **10 defensive layers for user-data preservation (v1.2.0)**.
- **`backupMu` serialization (BAK-2, v1.2.0)**.
- **Persistent backup directory with `0700`/`0600` (v1.2.0)**.
- **SHA256 integrity verification, advisory (Layer 3, v1.2.0)**.
- **Transactional upgrade with rollback (Layer 4, v1.2.0)**.
- **Watchdog token on `/api/ensure_running_service` (WD-TOKEN, v1.2.0)**.
- **Snapshot-and-reapply in recovery mode (FIX-1, v1.2.0)**.

---

## 14. Security Checklist

### 14.1 Pre-release

- [ ] Go build passes.
- [ ] No hardcoded secrets.
- [ ] `detect-secrets` clean.
- [ ] No new dependencies without review.
- [ ] Release signed successfully (Cosign).
- [ ] SBOM generated and uploaded.
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
- [ ] **v1.2.0**: Backup directory exists with mode `0700`.
- [ ] **v1.2.0**: `.watchdog_token` exists with mode `0600`.
- [ ] **v1.2.0**: `backupMu` mutex declared in `main.go`.
- [ ] **v1.2.0**: `runtime_info.backups` returns 7 fields.
- [ ] **v1.2.0**: FIX-1 present in `customize.sh`
      (`RECOVERY_SNAPSHOT_DIR` + `§[9b2]` re-apply block).
- [ ] **v1.2.0**: FIX-2 present in both `index.html` and
      `dashboard.html`.

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
- [ ] **v1.2.0**: `backups.available >= 1` after first boot.
- [ ] **v1.2.0**: `backups.in_flight_txn == 0` (no stuck
      transactions).
- [ ] **v1.2.0**: `backups.orphan_txn == 0` (or documented).
- [ ] **v1.2.0**: Watchdog token file exists and is `0600`.
- [ ] **v1.2.0**: `.recovery_snapshot/` is absent after a
      successful recovery (§[9b2] cleaned it up).

### 14.3 User

- [ ] User did not share credentials.
- [ ] Did not open 0.0.0.0 without a firewall.
- [ ] **v1.2.0**: Did not delete `/sdcard/dnscrypt-webui-backup/`
      unintentionally.

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
- [ ] 405 with `Allow: POST` header.
- [ ] PWA shortcuts work.

### 14.6 Token Leakage Audit

- [ ] No token in login response.
- [ ] No sessionStorage in JS.
- [ ] HttpOnly cookie only.
- [ ] **v1.2.0**: Watchdog token never logged.

### 14.7 Firewall Audit

- [ ] iptables does not contain IPv6.
- [ ] ip6tables contains IPv6 bootstrap.
- [ ] nftables uses case filter (IPv4/IPv6).
- [ ] No DNS loop on IPv4.
- [ ] No DNS loop on IPv6.

### 14.8 Custom Chains Audit

- [ ] OUTPUT contains only jump rules (two static rules).
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
- [ ] _MONITORING_UI_PORT constant = "8080" in every shell.
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
- [ ] See §14.18 for the verify block.

### 14.24 v1.1.0 — `MONITORING_UI_PORT` in Metrics Handler (MEM-3)

- [ ] No hardcoded `"http://127.0.0.1:8080/api/metrics"` remains.
- [ ] `metricsProxyHandler` uses `MONITORING_UI_PORT`.

### 14.25 v1.2.0 — Backup Directory Permissions Audit

**Verify**:

```bash
# 1. Top-level directory is 0700
su -c "stat -c '%a %U:%G %n' /sdcard/dnscrypt-webui-backup/"
# Expected: 700 root:root /sdcard/dnscrypt-webui-backup/

# 2. Snapshot directories are 0700
su -c "find /sdcard/dnscrypt-webui-backup -maxdepth 1 -type d -exec stat -c '%a %n' {} \\;"
# Expected: 700 for all except current/ and txn-* (also 700)

# 3. Snapshot files are 0600
su -c "find /sdcard/dnscrypt-webui-backup -type f -exec stat -c '%a %n' {} \\;"
# Expected: 600 for all .conf/.toml/.txt/.json files
#           644 for README.md (readable by user)
```

**Note**: On Android, `/sdcard/` is typically a FUSE mount. Mode
semantics differ from ext4. The primary protection is that only
root (or apps with `READ_EXTERNAL_STORAGE`) can read the
directory.

### 14.26 v1.2.0 — `backupMu` Serialization Audit

**Verify**:

```bash
# 1. Static audit
grep -q 'backupMu' proxy/main.go && echo "✅ backupMu declared"
grep -A10 'func createAutoBackup' proxy/main.go | grep -q 'backupMu.Lock()' && echo "✅ Lock"
grep -A15 'func createAutoBackup' proxy/main.go | grep -q 'defer backupMu.Unlock()' && echo "✅ Unlock"

# 2. Runtime (concurrency test)
# Send two rapid save_allowlist requests; expect serialized backups
```

### 14.27 v1.2.0 — 7-Field `backups` Object Audit

**Verify**:

```bash
# 1. API returns exactly 7 fields
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'
# Expected:
# ["available","in_flight_txn","last_backup","last_backup_name","last_stable","orphan_txn","path"]

# 2. All 7 fields are present (not just some)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys | length'
# Expected: 7

# 3. `path` is the expected value
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups.path'
# Expected: /sdcard/dnscrypt-webui-backup

# 4. Cross-check with status.sh --json
diff <(curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -S '.backups') \
     <(su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | jq -S '.backups | del(.status, .last_backup_age_seconds)'")
# Expected: no diff
```

### 14.28 v1.2.0 — Watchdog Token Audit

**Verify**:

```bash
# 1. Token file exists
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: -rw------- (mode 0600)

# 2. Token is not empty
su -c "wc -c /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: ~64 (hex token) or ~65 (with newline)

# 3. Token file is not world-readable
su -c "stat -c '%a' /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: 600

# 4. Static audit in main.go
grep -q 'loadOrCreateWatchdogToken' proxy/main.go && echo "✅ token loader"
grep -q 'subtle.ConstantTimeCompare' proxy/main.go && echo "✅ constant-time compare"
grep -q 'X-Watchdog-Token' proxy/main.go && echo "✅ header name"

# 5. Static audit in watchdog.sh
grep -q 'watchdog_token' proxy/watchdog.sh && echo "✅ watchdog reads token"
grep -q 'X-Watchdog-Token' proxy/watchdog.sh && echo "✅ watchdog sends token"
```

### 14.29 v1.2.0 — Recovery-Mode Interaction Audit (FIX-1)

**Corrected in this revision**: This section now verifies the
**snapshot-and-reapply** markers, not the old "reorder + exclude"
pattern.

**Verify**:

```bash
# 1. Module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# → must be version=v1.2.0

# 2. The snapshot directory constant must be present
su -c "grep -q 'RECOVERY_SNAPSHOT_DIR' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (snapshot dir)'"

# 3. The re-apply block (§[9b2]) must be present
su -c "grep -q 'Re-applying recovery snapshot' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (§[9b2] re-apply block)'"

# 4. Recovery trigger paths
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>/dev/null && echo 'module trigger' || echo 'no module trigger'"
su -c "ls /data/adb/dnscrypt-recovery 2>/dev/null && echo 'external trigger' || echo 'no external trigger'"

# 5. Recovery source priority
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable 2>/dev/null"
# Expected: a snapshot name, or nothing if not set

su -c "ls /sdcard/dnscrypt-webui-backup/current/"
# Expected: 5 files + .manifest.json

# 6. Verify the transient snapshot directory is cleaned up
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/.recovery_snapshot/ 2>&1"
# Expected (after a successful recovery): No such file or directory
# (Preserved only if the re-apply was partial)
```

**Full procedure**: see §7.5 of [`docs/BACKUP.md`](BACKUP.md) and
[`docs/EMERGENCY.md`](EMERGENCY.md) §9.

### 14.30 v1.2.0 — SELinux Context Preservation Audit (Layer 6)

**Verify**:

```bash
# 1. `copy_with_context` present in functions.sh
su -c "grep -q 'copy_with_context' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && echo '✅ helper'"

# 2. `restorecon` available
su -c "which restorecon && echo '✅ restorecon' || echo '⚠️ no restorecon (fallback: chcon)'"

# 3. After a restore, check the context
su -c "ls -Z /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# Expected: u:object_r:magisk_file:s0 (or an appropriate context)
```

---

## 15. Acknowledgments

Thanks to everyone who has contributed to the security of the project:

- All the Security Researchers who have responsibly disclosed issues.
- The GitHub community for code review.
- **Anthropic Claude** for assistance with the audit and review.

---

## 16. Changelog — Security Changes

### v1.2.0 (2026-09-29)

**Data-preservation release — no new audit corrections.**

This release fixes a silent **data-loss bug** in v1.1.0 and hardens
the write path with the 10 defensive layers. It does not add new
audit correction numbers.

**New sections in this document**:

- **§5.31 — Data Preservation Security Model**
  Documents the 10 defensive layers, the `backupMu` serialization
  guarantee, and the threat model for the persistent backup
  directory.

- **§5.32 — Correctness Fixes (FIX-1, FIX-2)**
  Documents the two correctness fixes that shipped with v1.2.0.
  Neither is an exploitable vulnerability.
  **Corrected in this revision**: FIX-1 now describes
  snapshot-and-reapply, not "reorder + exclude".

- **§5.33 — Watchdog Token (WD-TOKEN)**
  Documents the `X-Watchdog-Token` authentication that replaces
  the previous localhost bypass on
  `POST /api/ensure_running_service`.

**New checklist sections**:

- §14.25 — Backup directory permissions audit.
- §14.26 — `backupMu` serialization audit.
- §14.27 — 7-field `backups` object audit.
- §14.28 — Watchdog token audit.
- §14.29 — Recovery-mode interaction audit (FIX-1).
  **Corrected in this revision**: verifies snapshot-and-reapply
  markers.
- §14.30 — SELinux context preservation audit.

**Asset table updates**:

- §2.1 — added user-data preservation, backup-layer integrity,
  and watchdog authentication.
- §4.2 — added `backups`, `.watchdog_token`, `.last_stable`,
  `.upgrade_history.json`, `txn-*`, `orphan-txn-*`, and
  `.recovery_snapshot/`.

**Adversary table updates**:

- §3.1 — added malicious root app, watchdog impersonator,
  backup tamperer, recovery-mode abuser.
- §3.2 — added the 10 defensive layers, `backupMu`, watchdog
  token, SHA256 advisory verification, transactional upgrade,
  SELinux preservation, and recovery-mode snapshot-and-reapply.

**Known issues updates**:

- §13.2 — added "Backup integrity is advisory" (v1.3.0) and
  "`append_denylist` not used by WebUI" (v1.3.0).

**Logging updates**:

- §11.1 — added backup event logging and recovery-mode event
  logging.
- §11.2 — confirmed that the watchdog token is never logged.
- §11.3 — added `.upgrade_history.json` (not rotated).

**Numbering clarification (this revision)**:

- The v1.2.0 changes block now states explicitly that §5.31,
  §5.32, and §5.33 are **section** numbers in this document,
  **not** Audit Correction numbers. Each of these sections
  contains an inline **ℹ️ Section numbering note** repeating
  the clarification. The Audit Corrections Registry remains at
  **#33**; the next audit correction will be **#34** in v1.3.x.
  See §17.2 for the complete list of v1.2.0 additions that do
  **not** extend the registry.

**No changes to**:
- §1 (Reporting)
- §5.1–5.29 (all prior attack vectors)
- §6–10 (Headers, Auth, Sessions, Input, Crypto)
- §12 (Supply Chain)
- §15 (Acknowledgments)

### v1.1.0 (2026-09-26)

**Polish release — no new audit corrections.**

**Runtime improvements**:

- **MEM-1 — Dynamic memory limit per profile**
- **MEM-2 — Extended `shellQuote` character set**
- **MEM-3 — `MONITORING_UI_PORT` in metrics handler**

**Documentation updates**:

- §5.30 (new) — documents MEM-1 / MEM-2 / MEM-3.
- §14.22 (new) — memory limit audit.
- §14.23 (new) — extended shellQuote audit.
- §14.24 (new) — MONITORING_UI_PORT audit.
- §2.1 — added memory limit integrity to protected assets.
- §3.2 — added dynamic per-profile memory limit.
- §11.1 — added memory limit transition logging.
- §13.3 — added MEM-1 / MEM-2 / MEM-3 to compensating controls.

### v1.0.0 (2026-09-24)

**First stable release.** All accumulated fixes from development
(33 Audit Corrections) are consolidated into a single stable
`v1.0.0`.

**Critical fixes (7 original)**:
- **Fix #1 — Dashboard JSON conversion** — Audit Correction #25.
- **Fix #2 — Shell fallback** — CI fix.
- **Fix #3 — Preserve user settings on upgrade** — Audit Correction #26.
- **Fix #4 — `.gitignore` negation** — Build fix.
- **Fix #5 — Pre-commit hooks** — Build fix.
- **Fix #6 — Asset Serving** — Build fix.
- **Fix #7 — CodeQL config drift** — Build fix.

**High fixes (2)**:
- **Fix #8 — Basic Auth rate limiting** — Audit Correction #22.
- **Fix #9 — `fuser` PID parsing** — Audit Correction #27.

**Medium fixes (3)**:
- **Fix #10 — Section header with comment** — Audit Correction #23.
- **Fix #11 — Per-port cache** — Performance.
- **Fix #12 — Exact endpoint matching** — Audit Correction #24.

**Additional security fixes (NEW-1..NEW-6)**:
- **Fix NEW-1 — Login POST-only** — Audit Correction #28.
- **Fix NEW-2 — `hasEndpoint` usage** — (merged into #24).
- **Fix NEW-3 — `readConfPort` range check** — Audit Correction #29.
- **Fix NEW-4 — `/readyz` localhost-only** — Audit Correction #30.
- **Fix NEW-5 — `shellQuote` injection protection** — Audit Correction #31.
- **Fix NEW-6 — Auth cache (60 s)** — Performance.

**Architectural fixes (RACE-1 + PORT-2)**:
- **RACE-1 — `rebuildMu` mutex** — Audit Correction #32.
- **PORT-2 — `runtime_info` ports** — UX + Audit Correction #33.

---

## 17. Audit Corrections Registry

> **v1.2.0 note**: This release does **not** extend the registry.
> The last audit correction is #33, from v1.0.0. v1.2.0 is a
> data-preservation release. Its additions (BAK-1..BAK-4,
> FIX-1/FIX-2, WD-TOKEN) are documented in §5.31, §5.32, and
> §5.33 without audit correction numbers — they close a data-loss
> bug and harden the write path, but they do not fix known
> exploitable vulnerabilities in earlier v1.2.0 drafts.
>
> **Numbering clarification**: §5.31, §5.32, and §5.33 are
> **section numbers** in this document, **not** Audit Correction
> numbers. The Audit Corrections Registry is a flat, monotonic
> sequence that only advances when a new audit correction is
> filed. It remains at **#33**.
>
> New audit corrections will resume at **#34** in **v1.3.x**.

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
**Next expected**: #34 (v1.3.x)

### 17.1 v1.1.0 Runtime Improvements (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| MEM-1 | Dynamic memory limit per profile | Closes a self-inflicted DoS surface (GC thrashing on `ultimate`) |
| MEM-2 | Extended `shellQuote` charset (`{`, `}`, `\n`, `\t`) | Defense in depth; no known exploit existed |
| MEM-3 | `MONITORING_UI_PORT` in metrics handler | Single source of truth; removes last hardcoded reserved port |

These are documented in §5.30 for completeness but are not
assigned audit correction numbers because they do not fix a
known exploitable vulnerability.

### 17.2 v1.2.0 Runtime Additions & Correctness Fixes (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| **BAK-1** | 7-field `runtime_info.backups` | Observability of the backup layer; enables early detection of a degraded state (`in_flight_txn > 0` or `orphan_txn > 0`) |
| **BAK-2** | `createAutoBackup(reason)` + `backupMu` | Pre-critical backup before 5 destructive endpoints; serialized by a mutex to prevent concurrent snapshot corruption |
| **BAK-3** | `cleanupOldTransactions()` | Removes leftover `COMMIT`'d `txn-*` dirs at startup; preserves `START`/`ROLLBACK` |
| **BAK-4** | `checkPendingNotifications()` | Reads `.pending_notification` at startup; centralized deletion in `main.go` to avoid a race with `service.sh` |
| **FIX-1** | Recovery-mode **snapshot-and-reapply** | Correctness fix — `§[8a]` restores + snapshots the 5 files to `$MODPATH/.recovery_snapshot/`, `§[9]` extracts the ZIP normally, and `§[9b2]` re-applies the 5 files from the snapshot. The extraction logic stays untouched; the normal-install path is byte-for-byte identical. |
| **FIX-2** | Service Worker update-banner | Correctness fix — sends `SKIP_WAITING` to the correct worker in both `index.html` and `dashboard.html` |
| **WD-TOKEN** | Watchdog token | Closes a CSRF hole on `ensure_running_service`; replaces the implicit localhost bypass |

These are documented in §5.31, §5.32, and §5.33 for completeness
but are not assigned audit correction numbers because they do not
fix a known exploitable vulnerability in an earlier v1.2.0 draft
(except WD-TOKEN, which closes a real — though low-severity —
CSRF surface that existed since v1.0.0).

### 17.3 Post-Audit Corrections (BUG-1..BUG-6, N-1, N-4)

The v1.2.0 post-audit pass applied **7 corrections** to
`proxy/main.go` (plus one user-agent derivation fix). They do not
change the API contract, but they fix behaviors that clients
could observe:

| ID | Scope | Observable effect |
|---|---|---|
| **BUG-1** | `appendDenylist` — the pre-critical backup is performed **once** | One snapshot per call instead of two |
| **BUG-2** | `createAutoBackup` — stderr is no longer discarded | Failed backups are now visible in `dnscrypt_main.log` |
| **BUG-3** | `buildBackupInfo` — snapshots are sorted by directory **name**, not `mtime` | `last_backup_name` now matches `status.sh --json` |
| **BUG-4** | `readLogFile` — a failed `Seek` is handled explicitly | `?action=read_log` no longer silently returns the wrong slice |
| **BUG-5** | `appendDenylist` — the response message distinguishes "rules applied" from "no changes" | See `docs/API.md` §6.2.7 |
| **BUG-6** | `main()` registers `/api/runtime_info/` (trailing slash) | See `docs/API.md` §6.1.7 |
| **N-1** | `USER_AGENT` derived from `BuildVersion` | Custom `-ldflags` no longer leave a stale UA |
| **N-4** | `getEntriesCount` caches `lastSize` even when count is `0` | Fewer full scans on the "no blocklist yet" state |

These are internal fixes and do not receive audit correction
numbers.

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
- [RFC 7282 — On Consensus and Humming in the IETF](https://datatracker.ietf.org/doc/html/rfc7282)
- [Go runtime/debug.SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [Android FUSE — Storage Access Framework](https://source.android.com/docs/core/storage)
- [Android SELinux — restorecon](https://source.android.com/docs/security/features/selinux)
- [SHA-256 — NIST FIPS 180-4](https://csrc.nist.gov/publications/detail/fips/180/4/final)

---

**Last updated**: 2026-09-29
**Version**: v1.2.0
**Author**: gasciljh