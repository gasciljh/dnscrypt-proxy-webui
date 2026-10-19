# Security Policy — DNSCrypt Smart Filter

**Version**: v1.5.0 (Global Edition)
**Last updated**: 2026-10-18
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh
**Contact**: [GitHub Private Vulnerability Reporting](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

> **Canonical security reference.** This file merges the former
> `docs/SECURITY.md` (full policy) and `.github/SECURITY.md`
> (summary) into one document, in v1.5.0. It replaces both as of
> this release.

---

## Status Snapshot

| Metric | Value |
|---|---|
| Current version | v1.5.0 |
| Audit Corrections Registry | **#33** (last entry from v1.0.0) |
| External Go dependencies | **1** — `github.com/cyphar/filepath-securejoin v0.7.0` (ADR-0002) |
| Layered Bootstrap | Phase 0 active — Layer 0 `boot-mini.sh` + Layer 1 `functions.sh` (ADR-0003) |
| Companion install | 4 endpoints, one-shot CSRF token, per-IP rate limit |
| SELinux posture | Never `setenforce 0` — staging to `/data/local/tmp/` only |

### Security-Relevant Changes — At a Glance

| Version | Category | Highlights |
|---|---|---|
| v1.0.0 | Baseline | 33 Audit Corrections (CSRF, path-injection, port collision, IPv4/IPv6 separation, watchdog token skeleton, dynamic ports) |
| v1.1.0 | Runtime hardening | MEM-1 dynamic memory limit · MEM-2 extended `shellQuote` · MEM-3 `MONITORING_UI_PORT` constant |
| v1.2.0 | Data preservation | BAK-1..BAK-4 · FIX-1/FIX-2 · WD-TOKEN · 10 defensive layers · bilingual WebUI |
| v1.3.0 | Refinements | PWA install button · live status LED · DNS auto-start fix · SNAP-*/ROT-* semantics |
| v1.4.0 | Integration | Companion APK route · CodeQL `go/path-injection` fix · iOS PWA removal · MAIN-01 |
| v1.5.0 | Companion install | 4 endpoints · one-shot CSRF token · per-IP rate limit · SELinux staging · Play Protect trap · 75 s cascade deadline · Layered Bootstrap (ADR-0003) · `filepath-securejoin` (ADR-0002) |

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

- **In scope**: `main.go`, `install_app.sh`, shell scripts, HTML/JS,
  backup layer.
- **Out of scope**: dnscrypt-proxy upstream, Android OS, Magisk,
  the companion app repository.

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
- **Root user** — can do anything by nature, including reading the
  backup directory (`0700`, but root bypasses).
- **A root-privileged malicious app** — can read/write
  `/sdcard/dnscrypt-webui-backup/`.
- **The companion APK's own security** — out of scope (separate
  repository).
- **A malicious Play Protect app** — see §5.36.4 for the documented
  risk.

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
- `STATUS_FILE` = user intent (only `startService` / `stopService`
  write it)
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
- Persistent backup at `/sdcard/dnscrypt-webui-backup/`
  (mode 0700 / 0600)
- SHA256 integrity (advisory)
- Transactional upgrade with rollback
- SELinux context preservation (`restorecon` / `chcon`)
- Recovery mode (`recovery` trigger file)
- Config migrations
- Auto-backup (24 h) + rotation (21 snapshots)
- Observability (`status.sh --diagnose` + 7-field `backups`)

**Companion Install (v1.5.0)**
- One-shot CSRF token (60 s TTL)
- Per-IP rate limit (5 failed / 15 min)
- Localhost gate on all three install surfaces
- SELinux staging to `/data/local/tmp/` — **`setenforce 0` is never
  called**
- Play Protect temporary disable + trap restore
  (`$_VERIFIER_ORIG`)
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
│ │ + getSystemShell() fallback                                │ │
│ │ + shellQuote() for dynamic paths in main.go callers        │ │
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

This section is the canonical home for every attack vector the
project defends against. Each subsection follows a consistent
shape: **Background** (what was wrong) → **Solution** (what we do
now) → **Verify** (how to confirm the fix is in place). Sections
5.1–5.30 date from v1.0.0; 5.31 from v1.1.0; 5.32 from v1.2.0;
5.33–5.35 from v1.2.0/v1.4.0; 5.36 from v1.5.0.

### 5.1 Unauthorized Access

- **Vector**: malicious app tries to access the API.
- **Mitigation**: binding `127.0.0.1`, Basic/Bearer/Cookie auth,
  constant-time compare, rate limiting (includes Basic Auth).

**Verify**:

```bash
grep -q 'BIND_ADDR=127.0.0.1' proxy/webui.conf && echo "✅ default bind"
grep -q 'subtle.ConstantTimeCompare' proxy/main.go && echo "✅ constant-time"
```

### 5.2 CSRF

**Background**: GET-accessible toggle/restart allowed CSRF via
`SameSite=Lax` top-level navigation.

**Solution**: all state-changing endpoints POST-only:

| Endpoint | Before | After |
|---|---|---|
| toggle | GET | POST `/api/toggle_service` |
| restart | GET | POST `/api/restart_service` |
| ensure_running | GET | POST `/api/ensure_running_service` |
| login | GET/POST | POST only |
| logout | GET/POST | POST only |
| install_companion_app | — | POST only + one-shot token |

- 405 Method Not Allowed with `Allow: POST` (RFC 7231).
- PWA shortcuts still work (top-level GET).

**Verify**:

```bash
curl -i "http://127.0.0.1:9090/api/auth/login?username=x&password=y" \
  | head -1
# Expected: HTTP/1.1 405 Method Not Allowed
```

### 5.3 Path Traversal

- **Vector**: `GET /../../etc/passwd`.
- **Mitigation**: `serveStaticAssets` whitelist; no
  `filepath.Join(MODDIR, "web", r.URL.Path)`.

**Verify**:

```bash
curl -i "http://127.0.0.1:9090/../../etc/passwd" | head -1
# Expected: HTTP/1.1 404 Not Found
```

### 5.4 XSS

- **Vector**: allowlist contains `<script>`.
- **Mitigation**: `escapeHtml()` on all output, CSP `script-src 'self'`
  (with `'unsafe-inline'` — §6.3), `textContent` where user data is
  rendered.

### 5.5 Command Injection

- **Vector**: `param=; rm -rf /`.
- **Mitigation**:
  - No SQL (no database).
  - `exec.Command` called without a shell.
  - `runShell` limited to fixed commands.
  - Path whitelist + `limitedBuffer` for stderr capture.
  - `shellQuote()` applied to every dynamic path in `main.go`
    callers (`createAutoBackup`, `callInstallScript`, …).
  - **v1.2.0**: `copy_with_context` uses `shellQuote` for all
    dynamic paths (backup restore).
  - **v1.5.0**: `install_app.sh` uses a **hardcoded** APK path
    (`$MODDIR/web/app-debug.apk`) and double-quotes every path in
    shell commands (`"$APK_PATH"`, `"$STAGING_APK"`, …). It does
    **not** invoke Go's `shellQuote()` — the paths never enter a
    shell string. No user-controlled data reaches any path
    expression.

**Verify**:

```bash
grep -q 'func shellQuote' proxy/main.go && echo "✅ shellQuote exists"
grep -c 'shellQuote(' proxy/main.go | awk '$1 >= 3 {print "✅ used ≥3 times"}'
grep -v '^[[:space:]]*#' proxy/install_app.sh | \
  grep -qE '\$\(.*rm -rf.*\$' && echo "❌ unsafe" || echo "✅ no unsafe pattern"
```

### 5.6 Brute Force

- **Vector**: 10,000 login attempts.
- **Mitigation**: 5 attempts / IP / 15 min, intentional delay,
  `LOGIN_ATTEMPT_STALE_PERIOD = 1 h`. Basic Auth shares the limiter.
  Install endpoint has a **separate** per-IP limiter (see §5.36.2).

**Verify**:

```bash
for i in 1 2 3 4 5 6; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -u "wrong:wrong" http://127.0.0.1:9090/api?action=status
done
# Expected: 401 401 401 401 401 401 (6th is locked)
```

### 5.7 Memory Exhaustion

- **Vector**: POST 1 GB to `/api/save_allowlist`.
- **Mitigation**: `MaxBytesReader(5 MB)`, `io.LimitReader(50 MB)`
  for downloads, `limitedBuffer(2048)` for stderr.
- Dynamic per-profile memory limit prevents GC thrashing:
  light=80, normal=100, pro=120, proplus=160, ultimate=220.
- Rotation caps snapshots at 21 → total footprint ~2.5 MB.

### 5.8 Timing Attacks

- **Vector**: measure response time to guess secrets.
- **Mitigation**:
  - Password and Basic Auth use `subtle.ConstantTimeCompare`.
  - Watchdog token uses `subtle.ConstantTimeCompare`.
  - **Install token** uses `subtle.ConstantTimeCompare` against
    the stored token map. Go's map iteration order is randomized
    per call, so the comparison cost does not reveal the matched
    entry's position. The remaining token-level defenses — 256-bit
    entropy from `crypto/rand`, single-use semantics, 60-second
    TTL, per-IP rate limit (5 / 15 min), and localhost-only
    access — provide additional defense-in-depth beyond the
    constant-time comparison itself.

### 5.9 DNS Leak

**Background**: dnscrypt-proxy queries `bootstrap_resolvers` directly
on port 53 to download the server list. Without exclusion from DNAT,
a loop forms.

**Solution**:
- 3-e: `awk` reads multi-line TOML.
- 3-f: IPv6 support in `get_dynamic_bootstrap`.
- 16-a: `manage_iptables` skips IPv6
  (`case "$_ip" in *:*) continue`).
- 16-b: `manage_ip6tables` uses `::1` + `$BOOTSTRAP_IPS` with IPv4
  filtering.

| Protocol | Firewall | Bootstrap handling |
|---|---|---|
| IPv4 | iptables | ✅ (with IPv6 filtering) |
| IPv6 | ip6tables | ✅ (with IPv4 filtering) |
| Any | nftables | ✅ (case filter) |

**Verify**:

```bash
iptables -t nat -L DNSCRYPT_OUT -n | grep -c "RETURN"
# Expected: one RETURN per bootstrap IPv4 + loopback
ip6tables -t nat -L DNSCRYPT_OUT6 -n | grep -c "RETURN"
# Expected: one RETURN per bootstrap IPv6 + ::1
```

### 5.10 SSE DoS (Slow Client)

- **Vector**: 10,000 SSE connections with slow consumption.
- **Mitigation**: `SetWriteDeadline(30 s)` before each flush.

**Verify**:

```bash
grep -q 'SSE_WRITE_TIMEOUT' proxy/main.go && echo "✅ present"
```

### 5.11 Token Leakage

- **Vector**: XSS reads token from JSON or JS storage.
- **Mitigation**: no `sessionStorage`, no token in login response,
  HttpOnly cookie only.

**Verify**:

```bash
grep -q 'sessionStorage.*token' web/index.html && echo "❌ leak" || echo "✅ no sessionStorage token"
grep -q '"token".*json.NewEncoder' proxy/main.go && echo "❌ leak" || echo "✅ no token in JSON"
```

### 5.12 405 Method Not Allowed — RFC Compliance

- **Mitigation**: `Allow: POST` on 405 responses;
  `Allow: GET, HEAD, POST, OPTIONS` on OPTIONS.

### 5.13 Firewall Orphan Leak

**Background**: dynamic RETURN rules added to public `OUTPUT` chain
left orphans when `bootstrap_resolvers` changed.

**Solution**:
- `DNSCRYPT_OUT` (IPv4) and `DNSCRYPT_OUT6` (IPv6) Custom Chains.
- `_inline_cleanup_firewall` unified across `post-fs-data.sh`,
  `uninstall.sh`, `customize.sh`, and
  `functions.sh:manage_firewall 0`.
- `_legacy_cleanup_*` for upgrades from older versions.

**Golden rule**: never pollute a public chain with dynamic rules.

**Verify**:

```bash
iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'
# Expected: 0 (all dynamic rules are in DNSCRYPT_OUT)
```

### 5.14 STATUS_FILE Semantics

**Background**: `STATUS_FILE` was written by both `getStatusUncached`
and by `startService`/`stopService`, losing "user intent" meaning on
crash.

**Solution**: `STATUS_FILE` is **read-only** from the perspective of
`getStatusUncached`; written only by `startService` / `stopService`.

| Question | Answer |
|---|---|
| Meaning | "User intent" |
| Writers | `startService` / `stopService` only |
| Readers | `getStatus`, Watchdog, `status.sh` |
| On crash | `STATUS_FILE` stays "ON" → Watchdog restarts |

**Verify**:

```bash
awk '/func getStatusUncached/,/^}/' proxy/main.go | \
  grep -c 'atomicWriteFile'
# Expected: 0
```

### 5.15 IPv6 Rate Limit Bypass

- **Solution**: `getClientIP(r)` uses `net.SplitHostPort` —
  IPv6 addresses like `[::1]:port` map to `::1`.

**Verify**:

```bash
grep -q 'func getClientIP' proxy/main.go && echo "✅ present"
grep -A3 'func getClientIP' proxy/main.go | grep -q 'net.SplitHostPort' && echo "✅ IPv6-safe"
```

### 5.16 Port Collision

- **Solution**: `MONITORING_UI_PORT` constant. `main.go` refuses to
  start if `PORT` or `DASHBOARD_PORT` equals `8080`.
  `metricsProxyHandler` uses the constant (no hardcoded `"8080"`).

### 5.17 TOML Section Injection

- **Solution**: section tracking (`inSection` boolean) in all four
  parsers (`main.go`, `functions.sh`, `watchdog.sh`, `customize.sh`).

**Verify**:

```bash
grep -q 'inSection' proxy/main.go && echo "✅ main.go"
grep -q 'in_section' proxy/functions.sh && echo "✅ functions.sh"
grep -q 'in_section' proxy/watchdog.sh && echo "✅ watchdog.sh"
grep -q 'in_section' proxy/customize.sh && echo "✅ customize.sh"
```

### 5.18 Basic Auth Rate Limit Bypass

- **Solution**: `checkAuth` records failed Basic Auth attempts in
  `loginAttempts`. 5 attempts / 15 min lockout per IP.

**Verify**:

```bash
grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅ present"
```

### 5.19 Section Header with Comment

- **Solution**: section detection uses `strings.Index(trimmed, "]")`
  instead of `HasSuffix("]")` — supports
  `[monitoring_ui] # comment`.

### 5.20 Dashboard JSON Conversion

- **Vector**: `monitoring_ui` returns Prometheus text; Dashboard
  expects JSON.
- **Solution**: `parsePrometheus()` + `buildDashboardJSON()` convert
  Prometheus text to JSON. If the upstream response is already JSON,
  it is passed through unchanged.

**Verify**:

```bash
curl -s http://127.0.0.1:9091/api/metrics | jq '.total_queries'
# Expected: a number (not a JSON.parse error)
```

### 5.21 Exact Endpoint Matching

- **Vector**: `strings.Contains(r.URL.Path, "update_profile")` matches
  `/api/update_profile_evil`, `/prefix/api/update_profile`, etc.
- **Solution**: `hasEndpoint(path, name)` performs an exact match:

```go
func hasEndpoint(path, name string) bool {
    return path == "/api/"+name || path == "/api/"+name+"/"
}
```

Applied to every POST endpoint, including v1.5.0 install endpoints.

**Verify**:

```bash
curl -i -X POST http://127.0.0.1:9090/api/save_allowlist_evil | head -1
# Expected: HTTP/1.1 404 Not Found
```

### 5.22 Preserve User Settings on Upgrade

- **Earlier solution**: backup/restore around `unzip -o` for the 5
  config files (mechanism:
  `/data/local/tmp/dnscrypt-upgrade-backup-$$`).
- **v1.2.0 supersession**: replaced by the 10 defensive layers
  documented in §5.32.

### 5.23 `fuser` PID Parsing

- **Solution**:
  `fuser -n tcp "$port" | tr ' ' '\n' | grep -E '^[0-9]+$' | head -n1`
  — one PID per line, numbers only.

### 5.24 Login POST-Only

- **Solution**: `/api/auth/login` and `/api/auth/logout` reject
  non-POST requests with 405 + `Allow: POST`.

### 5.25 `readConfPort` Range Check

- **Solution**: `readConfPort` validates range `[1, 65535]`.

**Verify**:

```bash
grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' \
  && echo "✅ range check present"
```

### 5.26 `/readyz` Localhost-Only

- **Solution**: `handleReadyz` rejects non-localhost with
  `{"error": "readyz is localhost-only"}`.

**Verify**:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9091/readyz
# Expected: 200 or 503 (not 403)
```

### 5.27 `shellQuote` Injection Protection

- **v1.0.0**: 20-character escape set.
- **v1.1.0**: extended to 24 characters — see §5.31.2.
- **Applied to every dynamic shell path in `main.go`**. Callers
  that build shell commands (e.g. `createAutoBackup`,
  `callInstallScript`) use `shellQuote()` on all dynamic arguments.
  `install_app.sh` itself does not invoke `shellQuote()` (see §5.5);
  it relies on hardcoded paths and shell double-quoting.

### 5.28 Auth Cache (60 s)

- **Solution**: `getMonitoringAuth` caches credentials for 60 seconds.
  Empty results are never cached.
- **Not in the Audit Corrections Registry** — performance
  optimization, not a security finding.

### 5.29 Rebuild Blocklist Mutex (RACE-1)

- **Solution**: `rebuildMu sync.Mutex` protects the entire
  `rebuildBlocklist` function. `backupMu` follows the same pattern
  for `createAutoBackup`.

**Verify**:

```bash
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"
grep -qE 'backupMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ BAK-2"
```

### 5.30 Runtime Info Ports (PORT-2)

- **Solution**: `buildRuntimeInfo()` returns `webui_port` +
  `dashboard_port`. Frontend uses `window.location.hostname` to
  build links dynamically. `getWebUIPort` / `getDashboardPort` are
  cached for 30 seconds (`portConfMu`).

**Verify**:

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info \
  | jq '{webui_port, dashboard_port}'
# Expected: {"webui_port":"9090","dashboard_port":"9091"}
```

---

### 5.31 v1.1.0 — Runtime Hardening

#### 5.31.1 Dynamic Memory Limit (MEM-1)

`debug.SetMemoryLimit` is set per active profile
(light=80, normal=100, pro=120, proplus=160, ultimate=220). Called
from `main()` at startup and from `updateProfile()` on profile
change. `runtime_info` exposes `memory_limit_mb` + `profile_key`.

**Verify**:

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info \
  | jq '{profile_key, memory_limit_mb}'
grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1
```

#### 5.31.2 Extended `shellQuote` Character Set (MEM-2)

Escapes 24 characters (adds `{`, `}`, `\n`, `\t`). Defense in depth;
no known exploitable path.

**Verify**:

```bash
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ braces escaped"
grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\n'" && echo "✅ newline escaped"
```

#### 5.31.3 `MONITORING_UI_PORT` in Metrics Handler (MEM-3)

`metricsProxyHandler` uses the Go constant instead of the hardcoded
`"8080"` string.

**Verify**:

```bash
grep -A10 'func metricsProxyHandler' proxy/main.go | \
  grep -q 'MONITORING_UI_PORT' && echo "✅ constant used"
```

---

### 5.32 v1.2.0 — Data Preservation (10 Layers)

| # | Layer | File(s) |
|:-:|---|---|
| 1 | Multi-source detection (7 candidates) | `customize.sh` |
| 2 | Persistent backup | `customize.sh`, `functions.sh` |
| 3 | SHA256 integrity (advisory) | `customize.sh`, `functions.sh` |
| 4 | Transactional upgrades | `customize.sh` |
| 5 | Root-solution compatibility | `customize.sh` |
| 6 | SELinux preservation | `customize.sh`, `functions.sh` |
| 7 | Recovery mode | `customize.sh` |
| 8 | Config migrations | `customize.sh` |
| 9 | Automation + rotation | `service.sh`, `main.go` |
| 10 | Observability | `status.sh`, `main.go` |

**Persistent backup**: `/sdcard/dnscrypt-webui-backup/`, mode `0700`
on directories and `0600` on files. The **`apk/` mirror** (v1.5.0)
uses `0755` (no explicit mode in `customize.sh §[10c]`; inherits
umask).

**Rotation (ROT-MANIFEST + ROT-MTIME + ROT-PROTECT)**: keeps the
21 newest snapshots by mtime, with two protected targets
(`.last_stable` + newest install). The `apk/` subfolder is excluded
by name AND by manifest absence (two independent protections).

**`backupMu`** serializes `createAutoBackup` calls — prevents
concurrent snapshot corruption.

**Correctness fixes**:

- **FIX-1** — recovery-mode snapshot-and-reapply
  (`§[8a]` → `§[9]` → `§[9b2]`) because `[9]` unzip overwrites
  the restored files.
- **FIX-2** — Service Worker update banner sends `SKIP_WAITING`
  to `swRegistration.waiting`, reloads on `controllerchange`.

**Verify**:

```bash
# Layer presence
for L in CANDIDATE_SOURCES PERSISTENT_BACKUP verify_backup_integrity \
         begin_transaction detect_root_solution copy_with_context; do
  grep -q "$L" proxy/customize.sh && echo "✅ $L"
done

# ROT-* semantics
awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q '.manifest.json' \
  && echo "✅ ROT-MANIFEST"
awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q 'sort -rn -k1,1' \
  && echo "✅ ROT-MTIME"
awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q '_protected' \
  && echo "✅ ROT-PROTECT"
```

---

### 5.33 Watchdog Token (WD-TOKEN)

**Background**: `ensure_running_service` was protected only by an
implicit "localhost bypass" — exploitable via CSRF.

**Solution**:
- **Localhost-scoped**: `isLocalRequest` still required.
- **Constant-time**: `subtle.ConstantTimeCompare`.
- **Not rate-limited**: a flapping DNS engine does not lock the
  watchdog out.
- **Persistent**: token file survives restarts.
- **Fail-closed**: if the token file is missing and no token is
  sent, falls back to normal user auth.

**Verify**:

```bash
# Token file exists, mode 0600
stat -c '%a' /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token
# Expected: 600

# Missing token → 401
curl -s -o /dev/null -w "%{http_code}\n" \
  -X POST http://127.0.0.1:9090/api/ensure_running_service
# Expected: 401
```

---

### 5.34 CodeQL `go/path-injection` Fix in `removeModule`

> **Timeline**: v1.4.0 added `filepath.Base()` sanitization
> (functionally correct, but CodeQL's `go/path-injection` query did
> not recognize it as a sanitizer in this data-flow context, so two
> alerts remained open). The alerts were **fully closed** in the
> **interim, unreleased v1.4.1** revision by pinning
> `github.com/cyphar/filepath-securejoin v0.7.0` (ADR-0002).
> v1.5.0 inherits both changes.

**Background**: CodeQL flagged two `go/path-injection` alerts.

**Solution**:

```go
name := filepath.Base(modulePath)
if name == "" || name == "." || name == ".." ||
    name == string(filepath.Separator) {
    return error("Invalid module name")
}
expectedPrefix := MODULES_DIR + string(filepath.Separator)
if !strings.HasPrefix(filepath.Clean(modulePath), expectedPrefix) {
    return error("Invalid path")
}
cleanPath, err := securejoin.SecureJoin(MODULES_DIR, name)
if err != nil {
    return error("Invalid path")
}
```

**Why this closes the alerts**:

- `filepath.Base` is a CodeQL-recognized sanitizer.
- `securejoin.SecureJoin` combines a trusted base with a sanitized
  basename, refusing any path that would escape.
- `expectedPrefix` is defence-in-depth.

The dependency `github.com/cyphar/filepath-securejoin v0.7.0`
(ADR-0002) is the project's only external Go dependency.

**Verify**:

```bash
grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ sanitizer"
grep -q 'securejoin.SecureJoin' proxy/main.go && echo "✅ secure join"
grep -q 'filepath-securejoin v0.7.0' proxy/go.mod && echo "✅ pinned"
```

---

### 5.35 iOS PWA Removal + Companion APK Route

#### 5.35.1 iOS PWA Removal

Dead code on an Android-only project. Removing reduces surface.

**Verify**:

```bash
grep -qE '^\s*(function isIOSDevice|isIOSDevice\s*=)' \
  /data/adb/modules/dnscrypt-proxy-webui/web/index.html && \
  echo '❌ still present' || echo '✅ removed'
```

#### 5.35.2 Companion APK Route

- **Route**: `GET /app-debug.apk`.
- **Auth**: none (public). Contains no secrets; Android verifies
  the package signature at install time.
- **Cache-Control**: `public, max-age=3600, immutable`.
- **404** when the APK is absent (developer builds).

**Verify**:

```bash
curl -sI http://127.0.0.1:9090/app-debug.apk | head -3
# Expected (release build):
#   HTTP/1.1 200 OK
#   Content-Type: application/vnd.android.package-archive
#   Cache-Control: public, max-age=3600, immutable
# Expected (dev build):
#   HTTP/1.1 404 Not Found
```

---

### 5.36 v1.5.0 — Companion App Install Security

**Background**: v1.5.0 replaces the direct `<a download>` link with
a root-level install that runs `install_app.sh` — a 5-level
`pm install` cascade. The operation is privileged, irreversible in
the current request, and triggered from a browser origin — three
properties that make a dedicated security model necessary.

**Layout note**: `install_app.sh` is staged at the module root by
`customize.sh §[9]`. The repository source lives at
`proxy/install_app.sh`; after install, it lives at
`$MODDIR/install_app.sh`.

#### 5.36.1 One-Shot CSRF Token

1. `GET /api?action=install_token` — requires a valid session.
   Returns `{"token": "<64 hex>", "ttl": 60}`.
2. The token is stored in the `installTokens` map with an expiry of
   `now + INSTALL_TOKEN_TTL` (60 s).
3. The token is **consumed on first use**:
   `validateAndConsumeInstallToken(token)` deletes it from the map
   on success. A retry returns
   `401 Invalid or expired install token`.
4. Expired tokens are garbage-collected lazily. Server restart
   clears the map (tokens are 60 s by design).

**Why a separate token**:

- The install endpoint has side effects that outlive the session.
- The session cookie is long-lived (24 h). A one-shot token forces
  explicit per-request consent.
- CSRF exploitation becomes impractical: an attacker cannot know or
  guess a 64-hex random token.

**Security properties**:

| Property | Value | Notes |
|---|---|---|
| Entropy | 32 bytes `crypto/rand` → 64 hex | 256-bit random |
| Single-use | Deleted on first successful consumption | Retries fail with 401 |
| TTL | 60 seconds | Replay window is minimal |
| Rate limit | 5 failed install attempts / 15 min / IP | Applied on the install endpoint |
| Scope | Localhost-only (token issuance and install) | `isLocalRequest()` gate |
| Comparison | **`subtle.ConstantTimeCompare`** | Constant-time iteration over the token map; see §5.8 |

**Why not persist the token**: unlike the watchdog token (§5.33),
the install token is in-memory only. A server restart invalidates
all outstanding tokens — acceptable because the TTL is 60 seconds.

**Verify**:

```bash
# Issue a token
TOKEN=$(curl -s -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')
echo "${#TOKEN}"   # Expected: 64

# Second issuance should return a different token (single-use per request)
TOKEN2=$(curl -s -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')
[ "$TOKEN" != "$TOKEN2" ] && echo "✅ unique tokens"
```

#### 5.36.2 Per-IP Install Rate Limit

| Parameter | Value | Constant |
|---|---|---|
| Attempts | 5 | `MAX_INSTALL_ATTEMPTS` |
| Lockout | 15 minutes | `INSTALL_LOCKOUT_PERIOD` |
| Per | IP (IPv6-safe via `getClientIP`) | — |

**Separate map**: `installAttempts` is **distinct** from
`loginAttempts`. A failed login does not affect the install counter
and vice versa.

**Success reset**: a successful install resets the counter for that
IP.

**Lockout response**:

```http
HTTP/1.1 429 Too Many Requests
{"status": "error", "action": "install", "reason": "rate_limited",
 "message": "Too many install attempts. Try again in 15 minutes."}
```

**Verify**:

```bash
grep -q 'MAX_INSTALL_ATTEMPTS' proxy/main.go && echo "✅ limit constant"
grep -q 'INSTALL_LOCKOUT_PERIOD' proxy/main.go && echo "✅ lockout constant"
grep -q 'installAttempts' proxy/main.go && echo "✅ separate map"
```

#### 5.36.3 SELinux Staging

**Problem**: `/data/adb/` has the SELinux context `adb_data_file`.
`system_server` — which performs the install — **cannot read** files
with this context. Attempting `pm install` on
`/data/adb/.../app-debug.apk` produces `avc: denied { read }`.

**Fix**: copy the APK to
`/data/local/tmp/dnscrypt-companion.apk` (context `shell_data_file`,
readable by `system_server`).

**Critically**: SELinux is **never disabled** — no `setenforce 0`.
The staging directory is world-readable on most ROMs; the APK itself
is a public asset.

| Option | SELinux state | Attack window | Chosen? |
|---|---|---|---|
| `setenforce 0` | Disabled | Any crash leaves device unprotected | ❌ |
| `chcon` on module dir | Enforcing | Fragile, changes module context | ❌ |
| Stage to `/data/local/tmp/` | Enforcing | ~1 s world-readable copy | ✅ |
| Bind-mount elsewhere | Enforcing | Requires mount namespace | ❌ |

**Cleanup**: `install_app.sh §[12]` installs a trap that **removes**
the staged APK on **every** catchable exit path. The trap is split
into three handlers with a `_CLEANED_UP` re-entry guard:

```sh
trap '_cleanup_app' EXIT
trap '_cleanup_app; exit 130' INT
trap '_cleanup_app; exit 143' TERM
```

**Why the split**: in POSIX sh, a trapped signal whose handler does
not `exit` causes the script to resume after the handler returns. A
single `EXIT INT TERM` handler that cleans up but does not exit
allows the cascade to continue after SIGINT — re-staging the APK
and re-disabling Play Protect. The INT handler calls `exit 130`,
TERM calls `exit 143` (shell convention `128 + signal number`).
`_CLEANED_UP` ensures the cleanup body runs exactly once even when
the INT handler's `exit 130` triggers the EXIT handler.

**Race-free guarantee**: `pm install` blocks until it has finished
reading the file. By the time the trap fires, the staged APK is no
longer needed by `PackageManager`.

**Verify**:

```bash
grep -q '/data/local/tmp/dnscrypt-companion.apk' proxy/install_app.sh \
  && echo "✅ staging path"
grep -v '^[[:space:]]*#' proxy/install_app.sh | grep -q 'setenforce 0' \
  && echo "❌ SELinux disabled" || echo "✅ SELinux preserved"

# After an install attempt:
ls -la /data/local/tmp/dnscrypt-companion.apk 2>&1
# Expected: No such file or directory
```

#### 5.36.4 Play Protect Temporary Disable

**Problem**: Play Protect can silently block `pm install` of an APK
that did not originate from the Play Store.

**Fix**: temporarily disable the package verifier during the
cascade, restore on exit via the three-way trap.

```sh
_VERIFIER_ORIG=$(_read_verifier_state 2>/dev/null)
case "$_VERIFIER_ORIG" in
    "1")    settings put global package_verifier_enable 0 && \
            _VERIFIER_RESTORE=1 ;;
    "0")    ;;   # already disabled
    "null") settings put global package_verifier_enable 0 && \
            _VERIFIER_RESTORE=1 ;;
    *)      ;;   # unreadable — do not touch
esac
```

The trap restores the **exact captured value** (`$_VERIFIER_ORIG`),
not a hardcoded `1`.

> **Note on the captured value** (L-1): `_VERIFIER_ORIG = "1"` means
> the verifier was **enabled** at capture time; `"0"` means it was
> **disabled**. The trap restores the captured value verbatim — it
> does not assume the verifier was enabled.
>
> The inline comment in `proxy/install_app.sh §[12]` had these two
> values swapped until v1.5.0's L-1 correction (the code was always
> correct; only the comment was wrong). This blockquote exists so a
> future reviewer reading the script does not see a discrepancy.
> See `CHANGELOG.md` → Fixed → Shell → L-1.

**Duration**: the cascade is bounded by a **75-second deadline**
(`CASCADE_DEADLINE_SECONDS = 75`). Strictly shorter than `main.go`'s
90-second `INSTALL_TIMEOUT`, so the trap always fires before the
parent process kills the script.

**Restore value vs. hardcoded `1`**: the trap reads
`$_VERIFIER_ORIG` and restores it verbatim. A hardcoded `1` would
silently override a device-specific configuration where the
verifier was already disabled (`"0"`) or the key was unset
(`"null"`). Restoring the captured value is defence-in-depth: the
trap leaves the system in exactly the state it found it in.

**Caveats**:

- **Not restored on force reboot** — `settings put` writes to the
  system settings DB. A force-reboot during install may leave the
  verifier off until the next Play Protect scan.
- **SIGKILL skips the trap** — SIGKILL is uncatchable. The
  75-second deadline ensures the trap fires before the primary
  path (`main.go` via `exec.CommandContext`) sends SIGKILL.
- **`"null"` restore uses `settings delete`** — when the key was
  unset at capture time, restoring it via `settings put ... 1`
  would create the key with a value it never had. The trap
  preserves the "unset" state by calling `settings delete`
  instead.
- **`""` (read failure) skips restore entirely** — if
  `_read_verifier_state()` could not answer within the retry
  window, the script leaves the verifier untouched. This is
  fail-open by design: a boot-time settings-service failure must
  not corrupt an unrelated device setting.

**Verify**:

```bash
grep -q 'package_verifier_enable' proxy/install_app.sh && echo "✅ disable block"
grep -q '_VERIFIER_ORIG' proxy/install_app.sh && echo "✅ restore captured"
grep -q 'CASCADE_DEADLINE_SECONDS=75' proxy/install_app.sh && echo "✅ 75 s deadline"
```

#### 5.36.5 5-Level Cascade

1. `pm install -r --user 0 <apk>` — direct install.
2. `pm install -r --user 0 -i com.android.shell <apk>` —
   shell-attributed.
3. Session-based
   (`install-create` + `install-write` + `install-commit`).
4. `magisk su -c "pm install -r <apk>"`.
5. `cmd package install -r <apk>`.

**All 5 levels are semantically equivalent** — same
`PackageManager.installPackage` code path, different SELinux
domains. Android verifies the APK signature regardless of level.

**Attacker-controlled cascade failure**: a malicious ROM could
break every level so none succeeds. Result: failed install, not
compromised install. Android verifies the signature regardless.

**Verify**:

```bash
for p in 'pm install -r --user 0' \
         'pm install -r --user 0 -i com.android.shell' \
         'pm install-create' \
         'magisk su' \
         'cmd package install'; do
  grep -q "$p" proxy/install_app.sh && echo "  ✅ $p" || echo "  ❌ $p"
done
```

#### 5.36.6 Response Design — Failure is 200, Not 4xx

- **200** — success OR legitimate install failure (JSON body
  carries `status: "error"` + AR/EN messages).
- **401** — auth/token failure.
- **403** — non-localhost.
- **429** — rate limit.

**Rationale**: an install failure is a valid outcome of a
well-formed request. Only auth/rate-limit/token failures use 4xx.

#### 5.36.7 Package Name Candidates

`install_app.sh` tries **3 candidates** in order:

1. `com.gasciljh.dnsproxy.debug` (default)
2. `com.gasciljh.dnsproxy`
3. `com.gasciljh.dnscrypt_proxy` (legacy)

**Rationale**: the companion app has been released under multiple
package names across build variants. Trying all three means the
WebUI does not need to know the exact name.

**Security impact**: none. The list is hardcoded in
`install_app.sh`. Android verifies the package signature regardless
of the name.

**Verify**:

```bash
grep -q 'com.gasciljh.dnsproxy.debug' proxy/install_app.sh && echo "✅ candidate 1"
grep -qE 'com\.gasciljh\.dnsproxy([^.]|$)' proxy/install_app.sh && echo "✅ candidate 2"
grep -q 'com.gasciljh.dnscrypt_proxy' proxy/install_app.sh && echo "✅ candidate 3 (legacy)"
```

#### 5.36.8 SHA256 Verification

**Behavior**: if `web/app-debug.apk.sha256` is present, the APK's
SHA256 is verified **before any install strategy is attempted**. If
absent (dev builds), the script degrades to **advisory mode** — a
warning is logged, install proceeds.

**Rationale**: the `.sha256` is staged by `release.yml`. Dev builds
do not have it. The APK is a public artifact; the SHA256 guards
against bit-flip during the release pipeline, not against an
adversarial provider. Android verifies the **package signature** at
install time — the ultimate integrity check.

**Verify**:

```bash
grep -q 'app-debug.apk.sha256' proxy/install_app.sh && echo "✅ sidecar checked"
```

#### 5.36.9 Install Security — Summary

| Concern | Mitigation |
|---|---|
| Unauthorized install | `checkAuth()` required |
| Remote install | `isLocalRequest()` required on install + uninstall + install_token endpoints |
| Brute force | 5 failed / 15 min per IP |
| CSRF | one-shot token (60 s TTL) |
| Path traversal | APK path hardcoded in Go + sh |
| Shell injection | paths never enter a shell string; all args double-quoted in `install_app.sh`; `shellQuote()` used in `main.go` callers |
| SELinux relaxation | never `setenforce 0` — staging instead |
| Play Protect interference | temporary disable + trap restore + 75 s cascade deadline |
| APK tampering | SHA256 verification if `.sha256` present; Android signature always |
| Audit | full install log in `dnscrypt_main.log` |
| Install CPU DoS | per-IP rate limit |
| Token leak (XSS / extension) | 60 s TTL + single-use + 256-bit entropy + rate limit |
| Staged APK leftover | EXIT/INT/TERM traps remove it on every catchable exit path |
| Signal-interrupt resume | INT exits 130, TERM exits 143 |

**Integration verification** — see `docs/REFERENCE.md` §4.9 for the
full end-to-end test procedure.

---

## 6. Security Headers

### 6.1 Applied Headers

Every HTTP response from `main.go` carries these headers via
`securityHeadersMiddleware`:

```http
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline';
  style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:;
  font-src 'self' data:; connect-src 'self'; frame-ancestors 'none';
  base-uri 'self'; form-action 'self'; object-src 'none'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer
Permissions-Policy: geolocation=(), microphone=(), camera=(), payment=()
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin
```

**Rationale**:

| Header | Defense |
|---|---|
| CSP | XSS, code injection, mixed content, framing |
| `X-Content-Type-Options` | MIME-sniffing attacks |
| `X-Frame-Options` | Clickjacking (legacy; CSP `frame-ancestors` is authoritative) |
| `Referrer-Policy` | Leakage of URLs to external origins |
| `Permissions-Policy` | Access to device capabilities |
| COOP / CORP | Cross-origin isolation |

**Verify**:

```bash
curl -sI http://127.0.0.1:9090/ | grep -iE 'content-security|frame-options|referrer'
```

### 6.2 Cookie Security

```go
http.SetCookie(w, &http.Cookie{
    Name:     SESSION_COOKIE_NAME,        // "dnscrypt_session"
    Value:    token,
    Path:     "/",
    MaxAge:   int(SESSION_TTL.Seconds()),  // 86400 = 24h
    HttpOnly: true,
    Secure:   isSecureCookie(),            // conditional on localhost
    SameSite: http.SameSiteLaxMode,
})
```

`Secure=true` only when `BIND_ADDR` is loopback (`127.0.0.1`, `::1`,
`localhost`). `SameSite=Lax` (not `Strict`) so PWA shortcuts work;
CSRF protection comes from POST-only state-changing endpoints.

**Verify**:

```bash
grep -q 'HttpOnly: true' proxy/main.go && echo "✅ HttpOnly"
grep -q 'SameSiteLaxMode' proxy/main.go && echo "✅ SameSite=Lax"
grep -q 'func isSecureCookie' proxy/main.go && echo "✅ conditional Secure"
```

### 6.3 Known Limitation: CSP `'unsafe-inline'`

**Current state**: `script-src 'self' 'unsafe-inline'` and
`style-src 'self' 'unsafe-inline'`.

**Why it is present**: the WebUI uses inline `<script>` blocks in
`index.html`, `dashboard.html`, and `offline.html`, plus inline
`style` attributes throughout the CSS.

**Why it matters**: `'unsafe-inline'` reduces XSS protection from
"blocked by default" to "blocked unless inline is required". If an
attacker can inject HTML into a page, `'unsafe-inline'` allows them
to execute JavaScript.

**Why the project accepts this risk for now**:

- The WebUI has **no server-side rendered user data** in HTML.
  All user data reaches the DOM via `textContent` or `escapeHtml()`
  — the injection vector does not exist.
- The WebUI is **localhost-only by default** — an attacker would
  need to already be on the device.
- The install endpoint's CSRF token (§5.36.1) provides the
  defense that `'unsafe-inline'` would otherwise weaken.

**Removal plan**: deferred to a future release. See
`docs/ROADMAP.md` §2 for the current status.

**Compensating controls**:

- `escapeHtml()` applied to every DOM insertion of user data.
- `textContent` used for all interactive fields.
- No `eval`, `Function()`, or `innerHTML` on untrusted data.
- `frame-ancestors 'none'` prevents clickjacking.

---

## 7. Authentication

### 7.1 Supported Schemes

Evaluation order in `checkAuth()`:

| Priority | Scheme | Rate Limited | Persistence | Scope |
|:---:|---|:---:|---|---|
| **0** | Watchdog Token | No | per-request | `POST /api/ensure_running_service` only, localhost-only |
| **1** | Bearer Token | No | 24 h | All endpoints |
| **2** | Session Cookie | No | 24 h | All endpoints (primary) |
| **3** | Basic Auth | Yes (5 / 15 min) | per-request | All endpoints (fallback) |

**Install token** (§5.36.1) is **not** a session scheme. It is an
additional per-request credential required alongside a valid
session for `POST /api/install_companion_app`.

**Verify**:

```bash
grep -q 'func checkAuth' proxy/main.go && echo "✅ present"
grep -A20 'func checkAuth' proxy/main.go | grep -q 'verifyWatchdogToken' \
  && echo "✅ watchdog token checked first"
```

### 7.2 Credentials Source

From `dnscrypt-proxy.toml` `[monitoring_ui]` section **only**
(section tracking, no linear scan). Credentials cached for 60 s
(empty results are never cached — see §5.28).

**Why section-restricted**: prevents a compromised `[some_other]`
section from overriding the real credentials. See §5.17.

**Verify**:

```bash
grep -q 'inSection' proxy/main.go && echo "✅ section tracking"
grep -A5 'func readMonitoringAuthFromFile' proxy/main.go | \
  grep -q 'section == "monitoring_ui"' && echo "✅ name matched"
```

### 7.3 Constant-time Comparison

```go
userMatch := subtle.ConstantTimeCompare([]byte(user), []byte(expectedUser)) == 1
passMatch := subtle.ConstantTimeCompare([]byte(pass), []byte(expectedPass)) == 1
```

| Secret | Comparison | Notes |
|---|---|---|
| Password / Basic Auth | `subtle.ConstantTimeCompare` | Constant-time |
| Watchdog token | `subtle.ConstantTimeCompare` | Constant-time |
| Install token | `subtle.ConstantTimeCompare` | Constant-time iteration; see §5.8 |

**Why constant-time**: a non-constant-time comparison leaks
information about how many bytes of the input matched a stored
secret. Over many attempts, this reduces the search space. Go's
`subtle.ConstantTimeCompare` takes time proportional to the input
length regardless of where the first mismatch occurs.

**Verify**:

```bash
grep -c 'subtle.ConstantTimeCompare' proxy/main.go
# Expected: ≥ 3 (login + basic auth + watchdog)
```

### 7.4 Rate Limiting

- 5 failed attempts per IP / 15 min lockout.
- `getClientIP()` — IPv6-safe (`net.SplitHostPort`).
- Basic Auth protected by the same mechanism.
- Watchdog token requests bypass the login limiter (deliberately —
  a flapping DNS engine must not lock the watchdog out).
- Install endpoint has a separate per-IP limiter (§5.36.2).

**Verify**:

```bash
grep -q 'MAX_LOGIN_ATTEMPTS' proxy/main.go && echo "✅ limit constant"
grep -q 'LOGIN_LOCKOUT_PERIOD' proxy/main.go && echo "✅ lockout constant"
grep -q 'func isLockedOut' proxy/main.go && echo "✅ lockout check"
```

### 7.5 401 vs 403 vs 429 — Response Codes

| Code | Meaning | Where used |
|:---:|---|---|
| **401** | Authentication required / invalid | Missing or wrong credentials, expired session, expired install token |
| **403** | Authenticated but forbidden | `/readyz` from non-localhost; install endpoints from non-localhost |
| **429** | Too many attempts | Login lockout, install rate limit |
| **200** | Request processed | Even when the underlying operation failed (install failures are valid 200s) |

**Rationale**: install failures (e.g. `INSTALL_FAILED_VERIFICATION_FAILURE`)
are valid outcomes of a well-formed request. The HTTP status code
reflects the **request**, not the **outcome**. The JSON body carries
`status: "error"` for the outcome.

---

## 8. Session Management

### 8.1 Token Properties

| Property | Value |
|---|---|
| Length | 32 bytes → 64 hex characters |
| Source | `crypto/rand` (CSPRNG) |
| Storage | Memory only (never written to disk) |
| Delivery | `Set-Cookie` header only (never in JSON responses) |
| Lifetime | 24 hours (`SESSION_TTL`) |
| Extension | Sliding — extended on each request |

### 8.2 Lifecycle

```text
POST /api/auth/login
  ↓ (verify credentials)
createSession(username)
  ↓ (store in `sessions` map)
Set-Cookie: dnscrypt_session=<64-hex>; HttpOnly; SameSite=Lax; ...
  ↓
response JSON {status, message, profile}   ← no token in body

after 24h
  ↓
getSession() → expired → delete → 401

on logout
  ↓
destroySession(token) → delete → Set-Cookie MaxAge=-1
```

**Verify**:

```bash
grep -q 'func createSession' proxy/main.go && echo "✅ create"
grep -q 'func getSession' proxy/main.go && echo "✅ read"
grep -q 'func destroySession' proxy/main.go && echo "✅ destroy"
grep -q 'MaxAge:   -1' proxy/main.go && echo "✅ logout clears cookie"
```

### 8.3 Garbage Collection

Every 30 minutes (`SESSION_GC_PERIOD`), the `startSessionGC`
goroutine prunes:

- **Sessions** — expired entries.
- **Login attempts** — entries older than `LOGIN_ATTEMPT_STALE_PERIOD`
  (1 h).
- **Install attempts** — same staleness rule.

**Install tokens** are **not** GC'd by this goroutine — they are
pruned lazily inside `generateInstallToken()`.

**Verify**:

```bash
grep -q 'func startSessionGC' proxy/main.go && echo "✅ GC present"
grep -q 'SESSION_GC_PERIOD' proxy/main.go && echo "✅ period constant"
```

### 8.4 Session Fixation Defense

The session token is generated **after** successful authentication,
never before. There is no pre-auth token that could be fixed by an
attacker. `createSession()` deletes any existing expired sessions
but never reuses an existing token value.

**Verify**:

```bash
grep -A10 'func createSession' proxy/main.go | grep -q 'rand.Read' \
  && echo "✅ fresh entropy on every login"
```

---

## 9. Input Validation

### 9.1 Size Limits

| Input | Limit | Enforcement |
|---|---|---|
| POST body | 5 MB | `MaxBytesReader` |
| Allowlist content | 5 MB | same |
| Log file name | 200 chars | `isAllowedLogFile` |
| Username/password | 1024 chars | `MaxBytesReader` |
| SSE progress message | 200 chars | `write_progress` |
| Stderr capture | 2048 B | `limitedBuffer` |
| Blocklist download | 50 MB | `io.LimitReader` |
| Log file read | 500 KB | `io.LimitReader` |
| Log file download | 100 MB | explicit size check |
| Metrics upstream body | 2 MB | `io.LimitReader` |
| Install APK size | ≥ 100 KB | `MIN_APK_BYTES` |
| Install token length | 64 hex chars | `validateAndConsumeInstallToken` |

**Verify**:

```bash
grep -q 'MAX_POST_BODY_SIZE' proxy/main.go && echo "✅ POST body limit"
grep -q 'MAX_BLOCKLIST_SIZE' proxy/main.go && echo "✅ download limit"
grep -q 'MAX_LOG_READ_BYTES' proxy/main.go && echo "✅ log read limit"
grep -q 'MIN_APK_BYTES' proxy/install_app.sh && echo "✅ APK size check"
```

### 9.2 Port Validation

| Input | Rule |
|---|---|
| `PORT` | `[1, 65535]` and `≠ 8080` |
| `DASHBOARD_PORT` | `[1, 65535]` and `≠ 8080` and `≠ PORT` |
| Leading zeros | stripped before range check |
| Non-numeric | falls back to default |

**Verify**:

```bash
grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' \
  && echo "✅ range check"
```

### 9.3 Path Validation

| Input | Rule |
|---|---|
| `remove_module` path | `filepath.Base()` + `filepath.Clean()` + prefix check + `securejoin.SecureJoin` |
| Log file name | must start with `dnscrypt`, end with `.log`/`.gz`/`.old`/`.txt`, or contain `.emergency.` |
| Backup dir name | must match `<timestamp>-<type>-<pid>` (no `..`, no `/`) |
| Static assets | served from a hardcoded whitelist, never from `r.URL.Path` |

**Verify**:

```bash
grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ sanitized"
grep -q 'func sanitizeLogFileName' proxy/main.go && echo "✅ log name check"
```

### 9.4 Content Sanitization

| Context | Function |
|---|---|
| HTML output | `escapeHtml()` |
| Shell command (Go → shell) | `shellQuote()` |
| Shell command (`install_app.sh`) | hardcoded paths + double-quoted args |
| File system path | `filepath.Clean()` + `securejoin.SecureJoin` |
| IP address | `net.ParseIP()` |
| Endpoint name | `hasEndpoint()` exact match |
| JSON output | `json.Marshal()` (Go stdlib) |
| TOML parsing | section tracking + `parseTOMLValue()` |

### 9.5 Endpoint Matching

`hasEndpoint(path, name)` performs an **exact** match:

```go
func hasEndpoint(path, name string) bool {
    return path == "/api/"+name || path == "/api/"+name+"/"
}
```

Applied to every POST endpoint. Rejects `/api/update_profile_evil`,
`/prefix/api/update_profile`, and similar variations. See §5.21.

**Verify**:

```bash
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ exact match"
grep -c 'hasEndpoint(' proxy/main.go
# Expected: ≥ 20 (one per endpoint + dispatch tree)
```

---

## 10. Cryptography

### 10.1 Library

Go standard library only (`crypto/*`). The project's only external
Go dependency — `github.com/cyphar/filepath-securejoin v0.7.0` — is
used **only** for `removeModule` path sanitization, not for
cryptography.

**Verify**:

```bash
grep -c 'github.com/' proxy/go.mod
# Expected: 1 (filepath-securejoin only)
```

### 10.2 Algorithms

| Usage | Algorithm | Notes |
|---|---|---|
| Session token | `crypto/rand` (CSPRNG), 32 bytes → 64 hex | 256-bit entropy |
| Watchdog token | `crypto/rand`, 32 bytes → 64 hex | 256-bit entropy |
| Install token | `crypto/rand`, 32 bytes → 64 hex | 256-bit entropy, single-use, 60 s TTL |
| Content hash | SHA-256 | `contentHash()` for blocklist |
| Backup integrity | SHA-256 | `sha256sum` in shell |
| APK integrity | SHA-256 | Advisory if `.sha256` present |
| Password compare | `subtle.ConstantTimeCompare` | Go stdlib |
| Watchdog token compare | `subtle.ConstantTimeCompare` | Go stdlib |
| Install token compare | `subtle.ConstantTimeCompare` | Go stdlib |
| Temp files | `os.CreateTemp` | CSPRNG-based naming |
| TLS (downloads) | TLS 1.2+ | Go stdlib default |

### 10.3 What Is Not Encrypted (and Why)

| Data | Encrypted? | Reason |
|---|---|---|
| Blocklist | ❌ | Public artifact; no confidentiality requirement |
| Logs | ❌ | Diagnostic; contain IPs and actions but no secrets |
| Credentials (TOML) | ❌ | Protected by file mode `0600` + root ownership |
| Backup snapshots | ❌ | Protected by file mode `0600` + directory `0700` |
| Session tokens (memory) | N/A | In-process only; no persistence |
| Install tokens (memory) | N/A | 60 s TTL; no persistence |
| APK signature | ✅ (by Android) | Android PackageManager verifies at install |
| Release artifacts | ❌ | Only `.sha256` checksum attached (no Cosign/GPG) |

**Why no encryption-at-rest**: the backup directory is protected
by POSIX file modes (`0700` on directories, `0600` on files) plus
root ownership. A root-level attacker can bypass this regardless
of encryption — encrypting the backup would add key management
complexity without changing the threat model. The file modes are
sufficient for non-root attackers.

### 10.4 What Is Not Signed (and Why)

As of v1.5.0, the module ZIP and the four WebUI binaries are
**NOT** signed with Cosign or GPG. Only the SHA-256 checksum
(`.sha256` file) is attached to the release.

**Rationale**:

- **Threat model**: the SHA-256 checksum protects against bit-flip
  during download. It does not protect against a compromised
  release pipeline.
- **Trade-off**: signing requires maintaining a signing key and
  attaching the signature to every release. The project has a
  single maintainer; key management would be more risk than
  benefit.
- **Companion APK**: the companion APK **is** signed by Android
  package signature (via the companion repository's CI). This is
  a separate concern from the module ZIP.

**Roadmap**: signed releases (Cosign / Sigstore) are deferred to a
future release. See `docs/ROADMAP.md` §2.

---

## 11. Logging & Privacy

### 11.1 What We Log

| Event | Where | Fields |
|---|---|---|
| API requests | `dnscrypt_main.log` | IP, action, status |
| Login attempts | `dnscrypt_main.log` | IP, success/fail |
| Config changes | `dnscrypt_main.log` | file, reason |
| Errors | `dnscrypt_main.log` | message, limited stderr |
| Firewall cleanup | `dnscrypt_main.log` | mode |
| STATUS_FILE transitions | `dnscrypt_main.log` | old, new |
| Auth cache hits/misses | `dnscrypt_main.log` (debug) | key |
| Memory limit transitions | `dnscrypt_main.log` (info) | profile, MB |
| Backup events | `dnscrypt_main.log` | reason, files |
| Recovery-mode events | `dnscrypt_main.log` | trigger source |
| Watchdog token generation | `dnscrypt_main.log` | **value not logged** |
| Install request | `dnscrypt_main.log` | IP |
| Install cascade steps | `dnscrypt_main.log` | strategy, result |

### 11.2 What We Do Not Log

- DNS queries (unless explicitly enabled via `enable_query_log`)
- Passwords
- Session tokens
- Watchdog token **value**
- Install token **value**
- Browsing history
- Backup file **contents**
- APK contents

**Verify**:

```bash
grep -q 'sanitizeLogText' proxy/main.go && echo "✅ log injection defense"
grep -q 'MAX_LOG_MSG_SIZE' proxy/main.go && echo "✅ length limit"
```

### 11.3 Log Injection Defense

`sanitizeLogText()` removes newlines, carriage returns, and control
characters from user-controlled fields before they reach the log.
This prevents an attacker from injecting fake log entries.

**Verify**:

```bash
grep -A10 'func sanitizeLogText' proxy/main.go | \
  grep -q "'\\\\n' || r == '\\\\r'" && echo "✅ newline stripped"
```

### 11.4 Log Rotation

| Log | Threshold | Retention |
|---|---|---|
| `dnscrypt_main.log` | 1 MB (`MAX_LOG_SIZE`) | 5 `.gz` archives |
| `dnscrypt-proxy.log` | 6 MB (TOML `log_files_max_size`) | 3 days (TOML `log_files_max_age`) |
| `dnscrypt-proxy.log.*.gz` | — | 1 backup (`log_files_max_backups`) |
| `dnscrypt_main.log.*.old` | — | — (renamed before gzip) |
| `.upgrade_history.json` | not rotated | append-only |

**Emergency rotation**: `boot-mini.sh` and `log_msg()` in various
shell scripts rotate at 50 MB to prevent runaway growth when the
WebUI process is dead.

**Verify**:

```bash
grep -q 'MAX_LOG_SIZE' proxy/main.go && echo "✅ Go rotation"
grep -q 'MAX_GZ_FILES' proxy/main.go && echo "✅ archive pruning"
grep -q '52428800' proxy/boot-mini.sh && echo "✅ shell emergency rotation (50 MB)"
```

### 11.5 Privacy Posture

**Zero telemetry**: the project does not connect to any analytics
server, does not collect statistics, and does not send automatic
error reports.

**Network connections**:

| Destination | When | Data sent |
|---|---|---|
| DNSCrypt/DoH servers | Every DNS query | Query content (encrypted) |
| HaGeZi blocklist (jsDelivr) | Every profile download | None (GET request only) |
| Public resolvers (bootstrap) | Only to fetch server lists | None |
| GitHub Releases | Manual check / download | None |

**No connection to**:

- Google Analytics, Sentry, or any telemetry service.
- Any central server operated by the project.
- Any third-party CDN except jsDelivr for blocklists.

**Persistent backup**: stored locally at
`/sdcard/dnscrypt-webui-backup/`. **Not synced** to any remote
server. The `apk/` mirror (v1.5.0) is a copy of the public companion
APK — it contains no user data.

**Companion APK**: fetched by the **release pipeline** at build
time, not at install time. The install flow is entirely local.

---

## 12. Supply Chain

### 12.1 Components

| Component | Source | Signing / Integrity |
|---|---|---|
| Go stdlib | golang.org | ✔ (via toolchain) |
| `filepath-securejoin v0.7.0` | github.com/cyphar | ✔ (via `go.sum`) |
| dnscrypt-proxy | GitHub releases | ✔ (SHA-256 at fetch time) |
| HaGeZi blocklists | jsdelivr.net | — (content-level SHA-256 advisory) |
| Companion APK | GitHub releases | ✔ (Android package signature) |
| `install_app.sh` | in-module | covered by module ZIP's SHA-256 |
| Module ZIP | built from source | ✔ (`.sha256` file) |
| WebUI binaries | built from source | ✔ (same `.sha256`) |

### 12.2 External Go Dependency

The project has **exactly one** external Go dependency:
`github.com/cyphar/filepath-securejoin v0.7.0`.

**Why it exists**: closes two CodeQL `go/path-injection` alerts in
`removeModule` (§5.34). See `docs/adr/0002-external-dependency.md`
for the full policy.

**How it is verified**:

- Pinned in `proxy/go.mod` — exact version.
- Checksums in `proxy/go.sum` — SHA-256 of the module archive.
- `go build` with `-mod=readonly` — fails if `go.mod` or `go.sum`
  would need changes.
- `ci.yml` Step 6 verifies the pin is present.

**Compliance rule**: any future external dependency requires its
own ADR. The project's default is stdlib-only.

**Verify**:

```bash
grep -q 'filepath-securejoin v0.7.0' proxy/go.mod && echo "✅ pinned"
test -f proxy/go.sum && echo "✅ checksums present"
grep -c 'github.com/' proxy/go.mod
# Expected: 1
```

### 12.3 Release Signing — Current Status

| Artifact | Signed? | Verification |
|---|:---:|---|
| Module ZIP | ❌ | `.sha256` file only |
| WebUI binaries | ❌ | same `.sha256` |
| Companion APK | ✅ (Android) | PackageManager at install time |
| Git tag | ✅ (annotated) | `git tag -n <tag>` (annotated, not signed) |
| SBOM | ❌ | None generated |

**Roadmap**: signed releases (Cosign / Sigstore) and SBOM generation
are deferred to a future release. See `docs/ROADMAP.md` §2.

### 12.4 Build Security

- **Reproducible builds**: `SOURCE_DATE_EPOCH` extracted from the
  last commit's timestamp.
- **Trimmed paths**: `-trimpath` for consistent binary contents.
- **No build IDs**: `-buildid=` for deterministic output.
- **Version injection**: `-X main.BuildVersion=${SCRIPT_VERSION}`.
- **Vendored versions**: DNS engine pinned in
  `proxy/dnscrypt-proxy.version`; companion APK pinned in
  `proxy/app-apk.version`; securejoin pinned in `proxy/go.mod`.

**Verification**: `make build` produces byte-identical output on
the same commit.

### 12.5 CI/CD Verification

| Workflow | What it verifies |
|---|---|
| `ci.yml` | 4-arch build · shell syntax · backup layers · version consistency (9 files) · install_app.sh markers · boot-mini.sh integration · reserved-port sync |
| `codeql.yml` | SAST scan (security-extended query suite) for Go |
| `release.yml` | metadata consistency · CHANGELOG extraction · signed release · `main → develop` sync |
| `upgrade-test.yml` | 42-scenario data-preservation matrix (manual trigger) |

**Local equivalents**: `make check-all`, `make check-backup`,
`make check-install-app`, `make check-boot-mini`,
`make check-app-version`.

### 12.6 Pipeline Compromise Mitigation

**If an attacker compromises the release pipeline**, they could
publish a malicious module ZIP. The project mitigates this via:

- **Reproducible builds**: anyone can rebuild the ZIP from the
  tagged commit and compare the SHA-256.
- **Public commits**: every release is a tagged commit that anyone
  can review.
- **Companion APK signature**: the companion app cannot be
  replaced with a malicious APK signed by a different key.

**What is NOT mitigated**:

- A malicious commit that passes review (requires a compromised
  maintainer).
- A compromised GitHub account (requires 2FA + review).
- A supply-chain attack on the Go toolchain or NDK.

---

## 13. Known Limitations

### 13.1 Not Fixable

| Limitation | Reason |
|---|---|
| Root user bypasses everything | No protection against full root |
| LAN access if `BIND_ADDR=0.0.0.0` | Intentional feature |
| Root app can read logs | Nature of the system |
| `Secure=false` on LAN | Necessary to avoid breaking login |
| PWA dual-origin limitation | Service Worker bound to origin |
| `manifest.json` shortcuts static | Evaluated before JS |
| Soft memory limit is not a hard cap | Go runtime design |
| Backup directory readable by root | Nature of the system |
| SHA256 backup check is advisory | Deliberate — never blocks restore |
| Companion APK served without auth | No secrets; Android verifies signature |
| Install token is ephemeral | In-memory only; restart discards |
| Play Protect disable does not persist across reboot | `settings put` writes to DB; force-reboot may leave verifier off until next Play Protect scan |
| Package-name candidates are hardcoded | 3 candidates cover realistic variants |
| SIGKILL during install skips the trap | SIGKILL is uncatchable; 75 s cascade deadline ensures trap fires before primary path reaches SIGKILL |

### 13.2 Known Issues (Fix Planned)

| Issue | Proposed fix | Target |
|---|---|---|
| CSP `'unsafe-inline'` | Convert `onclick` → `addEventListener`; use nonce for remaining inline scripts | future release |
| `pgrep -x` on Android 5.x | Fallback to `ps -ef \| grep` | future release |
| `awk` parser with `]` in TOML comment | Refine end-of-array match | future release |
| PWA dual-origin (9090 vs 9091) | Unify WebUI + Dashboard on one port | future release |
| Maskable icon reuses `icon-512.png` | Dedicated maskable SVG | future release |
| Backup integrity is advisory | Opt-in `BACKUP_INTEGRITY_MODE=enforce` | future release |
| `append_denylist` not used by WebUI | Send `content` parameter from WebUI | future release |
| Companion app deep-links | `dnsproxy://` scheme | future release |
| Install token not rotated per-session | Rotate on logout | future release |
| `_VERIFIER_ORIG` comment mismatch (L-1) | Corrected in v1.5.0 | ✅ done |

### 13.3 Out of Scope

The following are **not** vulnerabilities in this project:

- **DNS query confidentiality** — the DNSCrypt/DoH provider sees
  the queries (encrypted). This is by design.
- **Blocklist content correctness** — HaGeZi is a third party. Report
  issues to `hagezi/dns-blocklists`.
- **DNSCrypt protocol weaknesses** — upstream. Report to
  `DNSCrypt/dnscrypt-proxy`.
- **Android OS vulnerabilities** — report to Google.
- **Magisk / KernelSU / APatch** — report to the respective
  maintainers.
- **The companion app** — separate repository
  (`gasciljh/dnscrypt-proxy-app`).
- **Browser PWA behavior** — the `beforeinstallprompt` event and
  WebView behavior vary by browser and are outside the module's
  control.

### 13.4 Deliberate Design Decisions

Some "limitations" are actually **deliberate design decisions**
made to balance security and usability:

| Decision | Security impact | Usability impact |
|---|---|---|
| No Cosign signing | Lower supply-chain integrity | Lower maintenance burden for a single maintainer |
| `'unsafe-inline'` CSP | Reduced XSS defense | Required for the current inline-script architecture |
| No backup encryption | Root attacker can read backups | Non-root attacker cannot (POSIX modes) |
| No token persistence | Restart invalidates sessions/tokens | No disk-based token leak |
| Watchdog token bypasses login limiter | Token remains valid during a DNS flap | Bypass requires the token file (root-only) |
| Install failures return HTTP 200 | Clients cannot rely on status code alone | Clients must read the JSON `status` field |

These decisions are documented here so a future reviewer knows
they were considered, not overlooked.

---

## 14. Audit Checklist

A compact table of manual checks per release. All commands assume
the module is installed at
`/data/adb/modules/dnscrypt-proxy-webui`. The checklist contains
**51 checks across 10 tables + 1 verification block**.

### 14.1 Build & CI

| Area | Check | Command |
|---|---|---|
| Build | Go build clean | `make build` |
| Build | Shell syntax | `bash -n proxy/*.sh scripts/*.sh` |
| Build | ShellCheck | `shellcheck --severity=warning proxy/*.sh scripts/*.sh` |
| Build | No secrets | `detect-secrets scan` |
| Build | gofmt clean | `gofmt -l proxy/` |
| Build | shfmt clean | `shfmt -d -i 4 -ci proxy/*.sh scripts/*.sh` |

### 14.2 Authentication

| Area | Check | Command |
|---|---|---|
| Auth | Login POST-only | `curl -i -X GET http://127.0.0.1:9090/api/auth/login` → 405 |
| Auth | `/readyz` localhost | from localhost → 200; from LAN → 403 |
| Auth | Basic Auth rate limit | 6 failed attempts → 429 |
| Auth | Watchdog token mode | `stat -c '%a' run/.watchdog_token` → 600 |
| Auth | Install token | `curl "…/api?action=install_token"` → `{token, ttl:60}`; second use → 401 |
| Auth | Install rate limit | 6 install attempts → 429 on 6th |

### 14.3 Firewall

| Area | Check | Command |
|---|---|---|
| Firewall | IPv4 chain | `iptables -t nat -L DNSCRYPT_OUT -n` |
| Firewall | IPv6 chain | `ip6tables -t nat -L DNSCRYPT_OUT6 -n` |
| Firewall | No orphans | `iptables -t nat -L OUTPUT -n \| grep -cE 'RETURN\|DNAT'` → 0 |

### 14.4 State & Concurrency

| Area | Check | Command |
|---|---|---|
| State | STATUS_FILE read-only | `awk '/func getStatusUncached/,/^}/' proxy/main.go \| grep -c atomicWriteFile` → 0 |
| Concurrency | `rebuildMu` | `grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go` |
| Concurrency | `backupMu` | `grep -qE 'backupMu[[:space:]]+sync\.Mutex' proxy/main.go` |

### 14.5 Endpoints & Matching

| Area | Check | Command |
|---|---|---|
| Endpoint | Exact match | `curl -i -X POST …/api/save_allowlist_evil` → 404 |
| Endpoint | `hasEndpoint` | `grep -q 'func hasEndpoint' proxy/main.go` |

### 14.6 Cookies & Sessions

| Area | Check | Command |
|---|---|---|
| Cookie | Attributes | `HttpOnly=true`; `Secure=conditional`; `SameSite=Lax` |
| Session | GC present | `grep -q 'func startSessionGC' proxy/main.go` |
| Session | Logout clears cookie | `grep -q 'MaxAge:   -1' proxy/main.go` |

### 14.7 Memory

| Area | Check | Command |
|---|---|---|
| Memory | Profile limit | `curl "…/api?action=runtime_info" \| jq .memory_limit_mb` |
| Memory | Startup log | `grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log \| tail -1` |

### 14.8 Backup & Recovery

| Area | Check | Command |
|---|---|---|
| Backup | Directory mode | `stat -c '%a' /sdcard/dnscrypt-webui-backup/` → 700 |
| Backup | 7-field schema | `curl "…/api?action=runtime_info" \| jq '.backups \| keys \| length'` → 7 |
| Backup | Recovery trigger | `touch $MODDIR/recovery && reboot` → files restored |
| Backup | SELinux context | `ls -Z proxy/webui.conf` |
| Backup | ROT-MANIFEST | `awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh \| grep -q '.manifest.json'` |
| Backup | ROT-MTIME | `awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh \| grep -q 'sort -rn -k1,1'` |
| Backup | ROT-PROTECT | `awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh \| grep -q '_protected'` |

### 14.9 CodeQL & Path Sanitization

| Area | Check | Command |
|---|---|---|
| CodeQL | `removeModule` sanitizer | `grep -q 'filepath.Base(modulePath)' proxy/main.go` |
| CodeQL | `SecureJoin` | `grep -q 'securejoin.SecureJoin' proxy/main.go` |

### 14.10 Companion Install

| Area | Check | Command |
|---|---|---|
| Companion | APK route | `curl -sI http://127.0.0.1:9090/app-debug.apk \| head -1` → 200 or 404 |
| Companion | Cascade levels | `grep -c 'pm install' proxy/install_app.sh` ≥ 3 |
| Companion | SELinux staging | `grep -q '/data/local/tmp/dnscrypt-companion.apk' proxy/install_app.sh` |
| Companion | No `setenforce 0` | `grep -v '^#' proxy/install_app.sh \| grep -q 'setenforce 0'` → must be empty |
| Companion | Trap split | `grep -q "exit 130' INT" proxy/install_app.sh` and `grep -q "exit 143' TERM"` |
| Companion | Cascade deadline | `grep 'CASCADE_DEADLINE_SECONDS=75' proxy/install_app.sh` |
| Companion | Legacy candidate | `grep -q 'com.gasciljh.dnscrypt_proxy' proxy/install_app.sh` |
| Companion | SHA256 sidecar | `grep -q 'app-debug.apk.sha256' proxy/install_app.sh` |

### 14.11 Post-Install Verification

After every install, verify the 10 defensive layers + the
v1.5.0 additions:

```bash
# 1. Module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.5.0

# 2. Service status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"

# 3. No firewall orphans
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# Expected: 0

# 4. Backups layer
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
# Expected: 7-field object

# 5. Watchdog token
su -c "stat -c '%a' /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: 600

# 6. Layer 0 / Layer 1 integrity
su -c "test -f /data/adb/modules/dnscrypt-proxy-webui/boot-mini.sh && echo '✅ Layer 0'"
su -c "test -f /data/adb/modules/dnscrypt-proxy-webui/install_app.sh && echo '✅ install_app.sh'"

# 7. Companion state
su -c "curl -s -b /tmp/cookies.txt 'http://127.0.0.1:9090/api?action=companion_app_state' | jq"
# Expected: {"status":"ok","action":"status",...}

# 8. Play Protect verifier
su -c "settings get global package_verifier_enable"
# Expected: 1 (or the original value)

# 9. SELinux enforcing
su -c "getenforce"
# Expected: Enforcing
```

---

## 15. Audit Corrections Registry

### 15.1 Registry — 33 Corrections (v1.0.0)

| # | Description | Category |
|:-:|---|---|
| #1 | Fixed typo in `isAllowedLogFile` | Logic |
| #3-e/f | Dynamic `bootstrap_resolvers` + IPv6 | DNS leak |
| #5 | Cleanup of old `loginAttempts` | Memory |
| #6-c | `limitedBuffer` (bounded stderr) | DoS |
| #7 | Dead code removal | Hygiene |
| #9/#9-b | `os.CreateTemp` (no race) | Race |
| #10 | Debounce SSE | DoS |
| #13 | CSRF-GET → POST-only | CSRF |
| #14 | `pgrep -x` | Logic |
| #15-a | Remove token from login response | Info leak |
| #15-b | `Allow: POST` header | RFC compliance |
| #16-a/b | IPv4/IPv6 separation | DNS leak |
| #17 | Custom Chains | Firewall |
| #18 | STATUS_FILE Semantics | State |
| #19 | IPv6 Rate Limit Bypass | Rate limit |
| #20 | Port Collision 8080 | Port |
| #21 | Section-Restricted TOML | Auth |
| #22 | Basic Auth Rate Limit Bypass | Rate limit |
| #23 | Section header with comment | Parsing |
| #24 | Exact endpoint matching | Path |
| #25 | Dashboard JSON Conversion | Data |
| #26 | Preserve User Settings on Upgrade | Data loss |
| #27 | `fuser` PID parsing | Logic |
| #28 | Login POST-only | CSRF |
| #29 | `readConfPort` range check | Port |
| #30 | `/readyz` localhost-only | Info leak |
| #31 | `shellQuote` injection protection | Injection |
| #32 | `rebuildMu` mutex (RACE-1) | Race |
| #33 | `runtime_info` dynamic ports (PORT-2) | Port |

**Last Audit Correction**: #33 (v1.0.0).
**Next expected**: #34 (future release).

### 15.2 v1.1.0+ — Runtime Additions (Not Audit Corrections)

v1.1.0 through v1.5.0 are **feature / polish / integration /
data-preservation** releases. **None extended the Audit Corrections
Registry.** Their additions are summarized in the "Security-Relevant
Changes — At a Glance" table at the top of this document and
detailed in the corresponding subsections of §5:

| Version | Additions | §Reference |
|---|---|---|
| v1.1.0 | MEM-1, MEM-2, MEM-3 | §5.31 |
| v1.2.0 | 10 layers, BAK-1..4, FIX-1/2, WD-TOKEN | §5.32, §5.33 |
| v1.3.0 | SNAP-*, ROT-*, DNS auto-start, PWA button, LED | §5.32 (rotation), §5.35 (PWA) |
| v1.4.0 | CodeQL `go/path-injection` **partial** fix (functional hardening via `filepath.Base()`; CodeQL did not recognize it as a sanitizer in this data-flow context) · Companion APK route · iOS PWA removal · MAIN-01 | §5.34, §5.35 |
| **interim v1.4.1** (unreleased, `go.mod`-only) | `filepath-securejoin v0.7.0` pin (ADR-0002) — **fully closed** the two `go/path-injection` alerts | §5.34 |
| v1.5.0 | Install endpoints, CSRF token, rate limit, SELinux staging, Play Protect trap, Layer 0/1 | §5.36 |

> **Timeline note**: The two `go/path-injection` alerts were opened
> against the v1.4.0 tree. v1.4.0 added `filepath.Base()` +
> `filepath.Clean()` + prefix check + `filepath.Join()` — all
> functionally correct, but CodeQL's `go/path-injection` query did
> not recognize `filepath.Base()` as a sanitizer in this specific
> data-flow context. The alerts were **fully closed** in the
> **interim, unreleased v1.4.1** revision by pinning
> `github.com/cyphar/filepath-securejoin v0.7.0` (ADR-0002). v1.5.0
> inherits both changes; the full history is in `CHANGELOG.md` →
> v1.4.0 §Fixed + v1.5.0 Interim v1.4.1 note.

### 15.3 Registry Integrity

The registry is a **monotonic sequence**. Numbers are never reused.
If a future correction is needed, it will be numbered **#34** —
regardless of how many logical fixes it contains.

**Slash-notation rows**:

- `#3-e/f` — two related fixes (3-e dynamic bootstrap, 3-f IPv6)
- `#9/#9-b` — two related fixes
- `#15-a` and `#15-b` — two related fixes
- `#16-a/b` — two related fixes

The **count of logical fixes** (32) differs from the **highest ID
assigned** (33) due to these combined rows and five gaps in the ID
sequence (`#2`, `#4`, `#8`, `#11`, `#12`).

**Why gaps exist**: the pre-consolidation numbering scheme absorbed
some fixes under other IDs. All gaps are documented under their
absorbed IDs.

---

## 16. Acknowledgments

### 16.1 Security Researchers

Thanks to everyone who has responsibly disclosed vulnerabilities
(see `docs/CONTRIBUTING.md` §7 for the Security Researcher badge).

*No entries yet — your spot is reserved.*

### 16.2 Code Review Contributors

- **Anthropic Claude** — Assistance with code review and
  architectural audit that led to the discovery and fixing of
  Audit Corrections #22–33 (v1.0.0).

### 16.3 Upstream Projects

- **[@DNSCrypt/dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)** —
  The DNS engine.
- **[@hagezi/dns-blocklists](https://github.com/hagezi/dns-blocklists)** —
  Blocklist source.
- **[@topjohnwu/Magisk](https://github.com/topjohnwu/Magisk)** —
  Module framework.
- **[@tiann/KernelSU](https://github.com/tiann/KernelSU)** — Root
  solution.
- **[@bmax121/APatch](https://github.com/bmax121/APatch)** — Root
  solution.
- **[@cyphar/filepath-securejoin](https://github.com/cyphar/filepath-securejoin)** —
  Path sanitization.

### 16.4 Standards & Tools

- **CodeQL** — `go/path-injection` query (closed 2 alerts in v1.4.1
  via ADR-0002).
- **OWASP** — Threat modeling guidance.
- **CWE / MITRE** — Vulnerability classification.
- **Go team** — `crypto/*`, `subtle.ConstantTimeCompare`,
  `runtime/debug.SetMemoryLimit`.
- **Android team** — SELinux, PackageManager, App Signing docs.

---

## 17. References

### 17.1 Specifications

| Spec | Relevance |
|---|---|
| RFC 7231 | HTTP/1.1 Semantics (status codes, `Allow` header) |
| RFC 6265bis | Cookies (`SameSite`, `Secure`, `HttpOnly`) |
| RFC 6749 | OAuth 2.0 (informational — not used) |
| RFC 6750 | Bearer tokens (informational) |
| W3C Server-Sent Events | `/events` endpoint |
| CWE Top 25 | Threat classification |
| OWASP ASVS | Application security verification |
| Prometheus Text Format | `monitoring_ui` metrics |

### 17.2 Project Files

| File | Purpose |
|---|---|
| `docs/REFERENCE.md` §1, §3 | System architecture, trade-offs |
| `docs/REFERENCE.md` §2 | HTTP API reference |
| `docs/REFERENCE.md` §4 | Backup system reference |
| `docs/GUIDE.md` §8 | Emergency recovery |
| `docs/CONTRIBUTING.md` | Contribution guide |
| `docs/adr/0002-external-dependency.md` | External dependency policy |
| `docs/adr/0003-layered-bootstrap.md` | Layered Bootstrap pattern |
| `docs/MAP.md` | Documentation structure |
| `CHANGELOG.md` | Version history |

### 17.3 External

- **DNSCrypt protocol**: https://dnscrypt.info/protocol
- **dnscrypt-proxy**: https://github.com/DNSCrypt/dnscrypt-proxy
- **HaGeZi blocklists**: https://github.com/hagezi/dns-blocklists
- **Magisk**: https://github.com/topjohnwu/Magisk
- **KernelSU**: https://github.com/tiann/KernelSU
- **APatch**: https://github.com/bmax121/APatch
- **filepath-securejoin**: https://github.com/cyphar/filepath-securejoin
- **Companion app**: https://github.com/gasciljh/dnscrypt-proxy-app

### 17.4 Related Sections in This Document

| Section | Topic |
|---|---|
| §5.8 | Timing attacks (constant-time comparison) |
| §5.21 | Exact endpoint matching |
| §5.31 | v1.1.0 runtime hardening |
| §5.32 | v1.2.0 data preservation |
| §5.33 | Watchdog token |
| §5.34 | CodeQL path-injection fix (with interim v1.4.1 timeline) |
| §5.35 | iOS PWA removal + companion APK route |
| §5.36 | v1.5.0 companion install security |
| §6.3 | CSP `'unsafe-inline'` limitation |
| §13 | Known limitations |

---

*This is the canonical security reference for DNSCrypt Smart
Filter. For contribution workflow, see `docs/CONTRIBUTING.md`. For
the documentation structure, see `docs/MAP.md`. For version
history, see `CHANGELOG.md`.*