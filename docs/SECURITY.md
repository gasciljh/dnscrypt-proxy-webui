# Security Policy — DNSCrypt Smart Filter

Vulnerability disclosure policy + threat model + applied protections.

**Version**: v1.1.0
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh
**Contact**: [GitHub Private Vulnerability Reporting](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • **No new audit corrections** — v1.1.0 is a documentation +
>     polish release. The Audit Corrections Registry remains at
>     #33 (the last entry from v1.0.0).
>   • Three runtime improvements are documented in this file
>     because they affect the security posture even though they
>     are not new audit corrections:
>       1. Dynamic memory limit per profile (main.go) — replaces
>          the previous hardcoded 80 MB limit. Prevents GC
>          pressure on the `ultimate` profile without weakening
>          the DoS protection on lighter profiles.
>       2. Extended `shellQuote()` character set — adds `{`, `}`,
>          `\n`, `\t` to the escape list. Defense-in-depth; no
>          known exploitable path existed before.
>       3. `MONITORING_UI_PORT` constant used in the metrics
>          handler — replaces the last hardcoded "8080" string.
>          Single point of truth for the reserved port.
>   • §14 Security Checklist gained three new verification
>     sections: §14.22 (memory limit), §14.23 (shellQuote
>     extension), §14.24 (MONITORING_UI_PORT).
>   • §16 Changelog gained a v1.1.0 entry.
>   • §17 Audit Corrections Registry header now notes that
>     v1.1.0 does not extend the registry.

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
v1.1.0 (or any version)

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

- **In scope**: `main.go`, shell scripts, HTML/JS
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

### 2.2 What We Do Not Protect

- **The DNS queries themselves** — visible to the DNSCrypt/DoH provider.
- **The local network** — if `BIND_ADDR=0.0.0.0`.
- **Root user** — can do anything by nature.

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
│  │  └───────────────────────────────┘  │    │
│  └────────────────────────────────────┘    │
│                   │ exec                          │
│  ┌─────────────▼─────────────────────┐     │
│  │  Trust Boundary 2: Shell Scripts (root)  │     │
│  │  + getSystemShell() fallback (Fix #2)    │     │
│  │  + shellQuote() for dynamic paths        │     │
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
    On the `ultimate` profile, this caused GC thrashing: the
    runtime spent significant CPU on garbage collection instead
    of serving requests. On low-RAM devices, this could make
    the WebUI unresponsive during peak DNS activity.
  - v1.1.0 replaces the hardcoded value with a per-profile
    limit set by `memoryLimitForProfile()`:
    light=80 MB, normal=100, pro=120, proplus=160, ultimate=220.
  - The limit is applied at startup (`main()`) and on every
    profile change (`updateProfile`). The state is exposed via
    `runtime_info.memory_limit_mb` for observability.
  - This is a defense-in-depth measure: it does not fix a
    vulnerability, but it removes a self-inflicted DoS surface
    that could be triggered by the legitimate `ultimate` profile.

### 5.8 Timing Attacks

- **Vector**: measure response time to guess the password.
- **Mitigation**:
  - Use `subtle.ConstantTimeCompare`

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

**Multi-layered**:
- `block_ipv6 = true` supported.
- `block_unqualified = true`.
- `block_undelegated = true`.

### 5.10 SSE DoS (Slow Client)

- **Vector**: 10,000 SSE connections with slow consumption to freeze the server.
- **Problem in the old design:**

  ```go
  // http.Server.WriteTimeout = 0 (infinite)
  // If the client is slow (TCP buffer full), Fprint blocks forever
  fmt.Fprint(w, msg)   // ← may hang the goroutine
  flusher.Flush()
  ```

- **Result (previously)**: each connection = 1 stuck goroutine → memory exhaustion.
- **Mitigation (Audit Correction #2):**

  ```go
  rc := http.NewResponseController(w)

  // before each write:
  _ = rc.SetWriteDeadline(time.Now().Add(SSE_WRITE_TIMEOUT))  // 30 s
  fmt.Fprint(w, msg)
  if err := flusher.Flush(); err != nil {
      return  // ← releases the goroutine
  }
  ```

- **Result (now)**: slow clients are disconnected after 30 s.

### 5.11 Token Leakage (Audit Correction #15-a)

- **Vector**: XSS can read the token from a JSON response or JS storage.
- **Mitigation**:
  - No `sessionStorage`
  - No token in login response
  - HttpOnly cookie only
  - Even if XSS exists, no token to steal

### 5.12 405 Method Not Allowed — RFC Compliance (Audit Correction #15-b)

- **Vector**: non-compliance with RFC 7231 §6.5.5.
- **Mitigation**:
  - `Allow: POST` header on 405
  - `Allow: GET, POST, OPTIONS` on OPTIONS response

<a name="513"></a>
### 5.13 Firewall Orphan Leak (Audit Correction #17)

**Background**:
The original release added dynamic RETURN rules directly to the public OUTPUT chain:

```bash
iptables -t nat -I OUTPUT -d 9.9.9.9 -p udp --dport 53 -j RETURN
iptables -t nat -I OUTPUT -d 8.8.8.8 -p udp --dport 53 -j RETURN
# ...
iptables -t nat -I OUTPUT -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:5354
```

**Problem (Orphaned Rules Leak)**:
1. The user changes `bootstrap_resolvers` in the TOML.
2. `$BOOTSTRAP_IPS` is reloaded after the cache expires (5 minutes).
3. `manage_iptables 0` (cleanup) removes RETURN rules only for the *current* IPs.
4. RETURN rules for the *old* IPs remain in OUTPUT forever.

**Real example**:

```bash
# Day 1: TOML = ['9.9.9.9', '8.8.8.8']
iptables -t nat -I OUTPUT -d 9.9.9.9 -j RETURN  # rule A
iptables -t nat -I OUTPUT -d 8.8.8.8 -j RETURN  # rule B

# Day 2: TOML = ['1.1.1.1']
# on stop/restart:
for _ip in 127.0.0.1 1.1.1.1; do    # ← misses 9.9.9.9 and 8.8.8.8!
    iptables -t nat -D OUTPUT -d "$_ip" -j RETURN
done
# Result: rules A and B are orphaned in OUTPUT forever ❌
```

**Impact**:
- Gradual pollution of OUTPUT.
- Cluttered `iptables -L output`.
- Tiny kernel memory per rule.
- On uninstall: `post-fs-data.sh` and `uninstall.sh` do not remove RETURN → permanent orphans.

**Solution (Custom Chains)**:

```bash
# 1) OUTPUT clean (two static rules only)
iptables -t nat -I OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT
iptables -t nat -I OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT

# 2) DNSCRYPT_OUT — Custom Chain
iptables -t nat -N DNSCRYPT_OUT
iptables -t nat -A DNSCRYPT_OUT -d 127.0.0.1 -j RETURN  # inside
iptables -t nat -A DNSCRYPT_OUT -d 9.9.9.9   -j RETURN
iptables -t nat -A DNSCRYPT_OUT -d 8.8.8.8   -j RETURN
iptables -t nat -A DNSCRYPT_OUT -j DNAT --to-destination 127.0.0.1:5354

# 3) Cleanup — mathematically guaranteed
iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT
iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT
iptables -t nat -F DNSCRYPT_OUT   # wipes all dynamic rules
iptables -t nat -X DNSCRYPT_OUT   # deletes the chain itself
```

**Golden rule**:
Never pollute a public chain (OUTPUT/INPUT/FORWARD) with dynamic rules.
Use a dedicated Custom Chain — deleting it wipes all its rules.

**Implementation**:
- `DNSCRYPT_OUT` (IPv4) and `DNSCRYPT_OUT6` (IPv6) in `functions.sh`.
- `_inline_cleanup_firewall` unified in 3 files (`post-fs-data.sh`, `uninstall.sh`, `customize.sh`).
- `_legacy_cleanup_*` for upgrades from older versions (best-effort).

<a name="514"></a>
### 5.14 State Integrity — STATUS_FILE Semantics (Audit Correction #18)

**Background**:
`STATUS_FILE` (`run/dnscrypt.status`) was written by two different functions with different meanings:

```go
// Before:
func getStatusUncached() string {
    _, found := isProcessRunning()
    if !found || !isPortOpenCached(5354) {
        atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)  // ← write!
        return "OFF"
    }
    atomicWriteFile(STATUS_FILE, []byte("ON"), 0666)
    return "ON"
}
```

**Problem**:
When the DNS engine crashes suddenly:
1. Watchdog reads `STATUS_FILE` every 30 s.
2. But WebUI (every 10 s) calls `getStatus` → `getStatusUncached`.
3. `getStatusUncached` writes "OFF" → loses "user intent" meaning.
4. Watchdog reads "OFF" → assumes "user stopped it manually" → ignores restart! ❌
5. DNS stays down forever.

**Impact**:
- Watchdog effectively disabled in the documented scenario (recovery after crash).
- Conflict between "user intent" and "actual state".
- Loss of trust in auto-restart.

**Solution (strict semantic separation)**:

```go
// After:
func getStatusUncached() string {
    _, found := isProcessRunning()
    if !found || !isPortOpenCached(5354) {
        return "OFF"  // ← read-only!
    }
    return "ON"
}

// STATUS_FILE is written only by startService/stopService:
func startService() {
    // ... after actual success ...
    atomicWriteFile(STATUS_FILE, []byte("ON"), 0666)
}

func stopService() {
    // ... on explicit stop ...
    atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)
}
```

**Architectural contract**:

| Question | Answer |
|---|---|
| What is the meaning of STATUS_FILE? | "User intent" |
| Who writes it? | `startService` / `stopService` only |
| Who reads it? | `getStatus`, Watchdog, `status.sh`, `action.sh --check` |
| Is it written by read-only functions? | Never |
| What happens on crash? | `STATUS_FILE` stays "ON" → Watchdog restarts |

**Legitimate exceptions**:
- `service.sh` with `disable` file present → OFF.
- `service.sh` when WebUI binary missing → OFF.
- `post-fs-data.sh` when `disable` present → OFF.

<a name="515"></a>
### 5.15 IPv6 Rate Limit Bypass (Audit Correction #19)

**Background**:

```go
// Before:
ip := strings.Split(r.RemoteAddr, ":")[0]
```

**Problem**:
- For RemoteAddr = `127.0.0.1:12345` → `127.0.0.1` ✅
- For RemoteAddr = `[::1]:12345` → `[` ❌

**Impact**:
- All IPv6-localhost users share the rate-limit key = `[`.
- One user could lock out others (simple DoS).
- Mismatch with IPv4 (different key).

**Solution**:

```go
// After:
func getClientIP(r *http.Request) string {
    host, _, err := net.SplitHostPort(r.RemoteAddr)
    if err != nil {
        return strings.Trim(r.RemoteAddr, "[]")
    }
    return host
}
```

<a name="516"></a>
### 5.16 Port Collision (Audit Correction #20)

**Background**:
`monitoring_ui` (in `dnscrypt-proxy.toml`) uses the fixed port 8080. If a user set `PORT=8080` or `DASHBOARD_PORT=8080`:
- Silent acceptance before the fix.
- Confusing failure for the user.

**Solution**:
- Unified constant `MONITORING_UI_PORT = "8080"` in `main.go`.
- Constant `_MONITORING_UI_PORT="8080"` in every shell script.
- `main.go` refuses to start if `PORT` or `DASHBOARD_PORT` = 8080.
- `customize.sh` refuses to write, falls back to default.
- `functions.sh`: `get_webui_port` / `get_dashboard_port` reject 8080.
- `status.sh` / `action.sh` / `service.sh`: fallback.

**Rule**:
Any change to the reserved port list must be applied across 7 files (`main.go` + 6 shell scripts).

**v1.1.0 addition**:
The `metricsProxyHandler` in `main.go` no longer contains the
hardcoded string `"http://127.0.0.1:8080/api/metrics"`. It now
builds the URL using the `MONITORING_UI_PORT` constant. This
closes the last hardcoded reference to the reserved port and
reduces the number of files that must be updated if the port
ever changes (see §5.30 below).

<a name="517"></a>
### 5.17 TOML Parsing — Section Injection (Audit Correction #21)

**Background**:

```go
// Before:
for _, line := range lines {
    if strings.HasPrefix(trimmed, "username") && strings.Contains(trimmed, "=") {
        // extracts username without verifying the section
    }
    if strings.HasPrefix(trimmed, "password") && strings.Contains(trimmed, "=") {
        // extracts password without verifying the section
    }
}
```

**Problem**:
- If the user adds another section with `username` (e.g. `[query_log]`), it may be extracted incorrectly.
- Theoretically: an attacker controlling the TOML could make `getMonitoringAuth` return values from another section → auth bypass.

**Impact**:
- Fragility if the TOML is edited with additional sections.
- Low practical risk (TOML is root-protected) but incorrect in principle.

**Solution**:

```go
// After:
inSection := false
for _, line := range lines {
    trimmed := strings.TrimSpace(line)

    // section tracking
    if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
        section := strings.TrimSpace(
            strings.TrimSuffix(strings.TrimPrefix(trimmed, "["), "]"))
        inSection = (section == "monitoring_ui")
        continue
    }

    if !inSection {
        continue  // ignore everything outside [monitoring_ui]
    }

    // extract key = value only inside the section
    // ...
}
```

**Applied in**: `main.go`, `functions.sh`, `watchdog.sh`, `customize.sh`.

<a name="518"></a>
### 5.18 Basic Auth Rate Limit Bypass (Fix #8 / Audit #22)

**Background**:

```go
// Before v1.0.0:
func checkAuth(r *http.Request) bool {
    // ...

    user, pass, ok := r.BasicAuth()
    if ok {
        userMatch := subtle.ConstantTimeCompare([]byte(user), []byte(expectedUser)) == 1
        passMatch := subtle.ConstantTimeCompare([]byte(pass), []byte(expectedPass)) == 1
        if userMatch && passMatch {
            return true
        }
        // ← does not record failed attempts here!
    }
    return false
}
```

**Problem**:
- `handleLogin` (POST `/api/auth/login`) records failed attempts in `loginAttempts`.
- But `checkAuth` (Basic Auth) does not record failed attempts.
- **Result**: an attacker on LAN can send unlimited Basic Auth requests without lockout.

**Catastrophic scenario**:

```bash
# Attacker tries 10,000 passwords
for pass in $(cat /usr/share/wordlists/rockyou.txt); do
    curl -u "admin:$pass" http://192.168.1.5:9090/api?action=status
done
# ← no rate limit → could finish 10,000 attempts
```

**Impact**:
- Unlimited brute force on LAN (if `BIND_ADDR` is exposed).
- Local attacker can bypass `handleLogin` rate limit.
- Clear design flaw (half-auth protected, half not).

**Solution**:

```go
// After v1.0.0:
func checkAuth(r *http.Request) bool {
    // ...

    user, pass, ok := r.BasicAuth()
    if ok {
        ip := getClientIP(r)

        // rate limiting for Basic Auth
        if isLockedOut(ip) {
            return false
        }

        userMatch := subtle.ConstantTimeCompare([]byte(user), []byte(expectedUser)) == 1
        passMatch := subtle.ConstantTimeCompare([]byte(pass), []byte(expectedPass)) == 1
        if userMatch && passMatch {
            recordLoginAttempt(ip, true)
            return true
        }

        // failed attempt → record
        recordLoginAttempt(ip, false)
    }
    return false
}
```

**Impact**:

| Scenario | Before v1.0.0 | After v1.0.0 |
|---|---|---|
| 5 failed Basic Auth attempts | No lockout | 15-min lockout |
| 6 attempts | No lockout | 401 (locked) |
| Successful attempt after 3 failures | Success | Success (resets) |
| Brute force from a different IP | Unlimited | Limited (per IP) |
| Brute force with a valid cookie | Impossible (no brute needed) | Same |

**Contract**:

```text
┌───────────────────────────────────────────┐
│  Any endpoint protected by checkAuth enforces:    │
│    • Rate limiting (5 attempts / 15 min)          │
│    • Lockout per IP                               │
│    • Success resets the counter                   │
│    • IPv6-safe (getClientIP)                      │
└───────────────────────────────────────────┘
```

<a name="519"></a>
### 5.19 Section Header with Comment (parsing) (Fix #10 / Audit #23)

**Background**:

```go
// Before v1.0.0:
if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
    // ⚠️ fails with `[monitoring_ui] # comment`
    // (the HasSuffix("]") condition is false because the line ends with `# comment`)
}
```

**Problem**:
- If the TOML contains:
  ```toml
  [monitoring_ui] # monitoring section
    username = 'admin'
    password = 'secret'
  ```
- The parser rejects `[monitoring_ui] # comment` → not a section → credentials not read.
- **Result**: login fails with correct credentials.

**Impact**:
- Login fails with no clear reason.
- Error messages say "invalid credentials" (misleading).

**Solution**:

```go
// After v1.0.0:
if strings.HasPrefix(trimmed, "[") {
    if end := strings.Index(trimmed, "]"); end > 0 {
        section := strings.TrimSpace(trimmed[1:end])
        inSection = (section == "monitoring_ui")
        continue
    }
}
```

**Applied in 4 files**:
- `main.go` → `getMonitoringAuth` / `readMonitoringAuthFromFile`.
- `functions.sh` → `read_toml_credentials`.
- `watchdog.sh` → credential reading.
- `customize.sh` → `[18]` verification.

**Impact**:

| TOML pattern | Before | After |
|---|---|---|
| `[monitoring_ui]` | ✅ | ✅ |
| `[monitoring_ui] ` | ✅ | ✅ |
| `[monitoring_ui]# comment` | ❌ | ✅ |
| `[monitoring_ui] # comment` | ❌ | ✅ |
| ` [monitoring_ui]` | ✅ | ✅ |

<a name="520"></a>
### 5.20 Dashboard JSON Conversion (Fix #1 / Audit #25)

**Background**:

```go
// Before v1.0.0:
func metricsProxyHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")  // ← lies
    // ...
    resp, _ := dashboardProxyClient.Do(req)
    defer resp.Body.Close()
    w.WriteHeader(resp.StatusCode)
    io.Copy(w, resp.Body)  // ← raw Prometheus text
}
```

**Problem**:
- `monitoring_ui` returns **Prometheus text format**:
  ```
  # HELP dnscrypt_proxy_query_total Total queries
  # TYPE dnscrypt_proxy_query_total counter
  dnscrypt_proxy_query_total 15234
  ```
- `metricsProxyHandler` declares `Content-Type: application/json`.
- `dashboard.html` fails at `JSON.parse()` → "Cannot fetch data" forever.
- Present for multiple versions.
- Previous fix "fixed" the path but not the format.

**Impact**:
- Dashboard does not work (full feature broken).
- Silent failure (no error message from main.go).
- User confusion ("Why is there no data?").

**Solution (Adapter Pattern)**:

```go
// 1. parsePrometheus — parses Prometheus text
func parsePrometheus(text string) map[string]float64 {
    result := make(map[string]float64)
    for _, line := range strings.Split(text, "\n") {
        line = strings.TrimSpace(line)
        if line == "" || strings.HasPrefix(line, "#") {
            continue
        }
        fields := strings.Fields(line)
        if len(fields) < 2 {
            continue
        }
        name := fields[0]
        if idx := strings.IndexByte(name, '{'); idx > 0 {
            name = name[:idx]
        }
        val, err := strconv.ParseFloat(fields[1], 64)
        if err != nil {
            continue
        }
        result[name] += val  // sum labels
    }
    return result
}

// 2. buildDashboardJSON — converts to the schema
func buildDashboardJSON(prom map[string]float64) map[string]interface{} {
    // ...
}

// 3. metricsProxyHandler — returns JSON
func metricsProxyHandler(w http.ResponseWriter, r *http.Request) {
    // ...
    body, _ := io.ReadAll(resp.Body)
    prom := parsePrometheus(string(body))
    dashboardJSON := buildDashboardJSON(prom)
    json.NewEncoder(w).Encode(dashboardJSON)
}
```

**Impact**:

| Before | After |
|-----|-----|
| `Content-Type: application/json` (lies) | `Content-Type: application/json` (correct) |
| Prometheus text | JSON schema |
| Dashboard broken | Dashboard works |
| `JSON.parse()` fails | `JSON.parse()` succeeds |

**Security**:
- No new attack vector.
- The fix also addresses a silent failure.

<a name="521"></a>
### 5.21 Preserve User Settings on Upgrade (Fix #3 / Audit #26)

**Background**:

```bash
# Before v1.0.0 (proxy/customize.sh):
# Wrong logic: relies on "file does not exist" for migration
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt; do
    if [ ! -f "$BIN_DIR/$f" ]; then
        cp "$MODPATH/proxy/$f" "$BIN_DIR/$f"  # ← never runs!
    fi
done

# Reason: unzip -o extracts defaults first → the file exists → condition is false.
```

**Problem**:
- On upgrade:
  1. `unzip -o` extracts the **defaults** from the new ZIP.
  2. It overwrites the user's old `webui.conf`.
  3. Migration logic fails (the file now exists).
  4. **Result**: user loses settings.
- **Lost files**:
  - `webui.conf` (PORT, DASHBOARD_PORT, BIND_ADDR, LOG_LEVEL)
  - `dnscrypt-proxy.toml` (credentials, cache size, etc.)
  - `selected_profile.txt`
  - `allowlist.txt`
  - `denylist.txt`

**Impact**:
- User data loss on every upgrade.
- User must reconfigure everything.
- Poor UX.

**Solution (backup + restore)**:

```bash
# [8b] Backup BEFORE extraction
BACKUP_TMP="/data/local/tmp/dnscrypt-upgrade-backup-$$"
if mkdir -p "$BACKUP_TMP" 2>/dev/null; then
    for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
        src="$_EXISTING_MODULE/proxy/$f"
        if [ -f "$src" ]; then
            cp -f "$src" "$BACKUP_TMP/$f" 2>/dev/null
        fi
    done
fi

# [9] extract module files (unzip -o)
unzip -o "$ZIPFILE" ...

# [9c] Restore AFTER extraction
if [ -n "$BACKUP_TMP" ] && [ -d "$BACKUP_TMP" ]; then
    for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
        if [ -f "$BACKUP_TMP/$f" ]; then
            cp -f "$BACKUP_TMP/$f" "$BIN_DIR/$f" 2>/dev/null
        fi
    done
    rm -rf "$BACKUP_TMP" 2>/dev/null
fi
```

**Impact**:

| File | Before | After |
|------|-----|-----|
| webui.conf | Lost | Preserved |
| dnscrypt-proxy.toml | Lost | Preserved |
| selected_profile.txt | Lost | Preserved |
| allowlist.txt | Lost | Preserved |
| denylist.txt | Lost | Preserved |

**Security**:
- Backup is created with `mkdir -p` (0700 typically).
- It is deleted after use.
- It does not contain more secrets than the original.

<a name="522"></a>
### 5.22 `fuser` PID Parsing (Fix #9 / Audit #27)

**Background**:

```bash
# Before v1.0.0 (proxy/functions.sh):
pid_on_port=$(fuser "$port/tcp" 2>/dev/null | tr -d ' ')
#                                                    ^^^^^^^^
#                                                    merges PIDs!
```

**Problem**:
- `fuser` returns PIDs separated by spaces: `"12345 67890"`.
- `tr -d ' '` merges them → `"1234567890"` (wrong PID).
- **Danger**: `kill -9 1234567890` may kill a random process.

**Scenario**:

```bash
$ fuser 9090/tcp 2>/dev/null
9090/tcp:            12345 67890

$ fuser 9090/tcp 2>/dev/null | tr -d ' '
1234567890  # ← wrong PID!

$ kill -9 1234567890  # ← dangerous!
```

**Impact**:
- Random process kill (DoS).
- Cleanup failure (wrong PID).

**Solution**:

```bash
# After v1.0.0:
pid_on_port=$(fuser -n tcp "$port" 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' | head -n1)
#             ^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^^^^ ^^^^^^^^^^
#             explicit proto  one PID per line   numbers only        first PID
```

**Impact**:

| Input | Before | After |
|-------|:---:|:---:|
| `12345` | `12345` | `12345` |
| `12345 67890` | `1234567890` ❌ | `12345` ✅ |
| `12345 67890 11111` | `123456789011111` ❌ | `12345` ✅ |
| `""` (empty) | `""` | `""` |

**Additional — `comm` check**:

```bash
# before kill, verify the process is really the WebUI
comm=$(cat "/proc/$pid_on_port/comm" 2>/dev/null)
case "$comm" in
    dnscrypt-webui*) kill -9 "$pid_on_port" ;;
    "") log_fn "PID $pid_on_port: process gone" ;;
    *) log_fn "PID $pid_on_port: NOT killing (unexpected: $comm)" ;;
esac
```

<a name="523"></a>
### 5.23 Login POST-Only (Fix NEW-1 / Audit #28)

**Background**:

```go
// Before v1.0.0:
if strings.HasSuffix(r.URL.Path, "/auth/login") {
    handleLogin(w, r)  // ← no method check!
    return
}
```

**Problem**:
- `handleAPI` passed **any request** (GET/HEAD/PUT/DELETE) to `handleLogin`.
- `handleLogin` used `r.FormValue("username")` and `r.FormValue("password")`, which **read the query string** when no body exists.
- **Result**:
  ```bash
  # worked before the fix ❌
  curl "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
  ```

**Impact**:
- **CSRF vector**: an attacker could send:
  ```html
  <img src="http://127.0.0.1:9090/api/auth/login?username=admin&password=X">
  ```
  → browser sends the request automatically → auto-login.
- **Log leak**: credentials in the URL are logged in:
  - Browser history.
  - Server access logs.
  - Referer headers.
- **Brute-force vector**: GET is easier to automate than POST.

**Solution**:

```go
// After v1.0.0:
if hasEndpoint(r.URL.Path, "auth/login") {
    if r.Method != http.MethodPost {
        w.Header().Set("Allow", "POST")
        w.WriteHeader(http.StatusMethodNotAllowed)
        json.NewEncoder(w).Encode(map[string]string{
            "status":  "error",
            "message": "Login requires POST (CSRF protection)",
        })
        return
    }
    handleLogin(w, r)
    return
}
```

Same handling for `/api/auth/logout`.

**Impact**:

| Method | Before | After |
|--------|-----|-----|
| POST | ✅ | ✅ |
| GET | ⚠️ **works** | ❌ 405 + Allow: POST |
| HEAD | ⚠️ **works** | ❌ 405 + Allow: POST |
| PUT | ⚠️ **works** | ❌ 405 + Allow: POST |
| DELETE | ⚠️ **works** | ❌ 405 + Allow: POST |

**Mapping table**:

| Old (GET) | New (POST) |
|---|---|
| `GET /api/auth/login?...` | `POST /api/auth/login` (JSON body) |
| `GET /api/auth/logout` | `POST /api/auth/logout` |

<a name="524"></a>
### 5.24 `readConfPort` Range Check (Fix NEW-3 / Audit #29)

**Background**:

```go
// Before v1.0.0:
func readConfPort(key, defaultPort string) string {
    val := readConfValue(key, defaultPort)
    if _, err := strconv.Atoi(val); err == nil && val != "" {
        return val  // ← accepts 0, 99999, -1, etc.
    }
    return defaultPort
}
```

**Problem**:
- `PORT=0` → Go selects a **random** port (unexpected).
- `PORT=99999` → `net.Listen` fails but `main()` exits with `exit 0` (silent error).
- `PORT=-1` → `net.Listen` error.
- No clear error message → user does not understand the failure.

**Impact**:
- Bad UX: "Why isn't the WebUI working?" with no clear reason.
- CI/CD may produce broken packages.
- No explicit failure (`exit code = 0`).

**Solution**:

```go
// After v1.0.0:
func readConfPort(key, defaultPort string) string {
    defer func() { recover() }()
    val := readConfValue(key, defaultPort)
    n, err := strconv.Atoi(val)
    if err != nil || n < 1 || n > 65535 {
        return defaultPort  // fallback
    }
    return val
}
```

**Impact**:

| Value | Before | After |
|-------|-----|-----|
| `PORT=9090` | ✅ works | ✅ works |
| `PORT=1` | ✅ works | ✅ works |
| `PORT=65535` | ✅ works | ✅ works |
| `PORT=0` | random port | ✅ fallback (9090) |
| `PORT=99999` | silent failure | ✅ fallback (9090) |
| `PORT=-1` | silent failure | ✅ fallback (9090) |
| `PORT=abc` | ✅ fallback | ✅ fallback |
| `PORT=` | ✅ fallback | ✅ fallback |

<a name="525"></a>
### 5.25 `/readyz` Localhost-Only (Fix NEW-4 / Audit #30)

**Background**:

```go
// Before v1.0.0:
func handleReadyz(w http.ResponseWriter, r *http.Request) {
    // ← no IP check!
    checks := map[string]string{
        "config":     "ok",           // reveals TOML existence
        "blocklist":  "ok",           // reveals BLOCKLIST existence
        "run_dir":    "ok",           // reveals run/ existence
        "dns_engine": "running",      // reveals DNS state
        "version":    BuildVersion,   // reveals build version
    }
    // ...
}
```

**Problem**:
- On `BIND_ADDR=0.0.0.0` (exposed to LAN):
- Any attacker on the same network could `curl http://192.168.1.5:9091/readyz`:
  - Learn system state.
  - Infer current errors.
  - Plan an attack.
- **Reconnaissance vector**.

**Impact**:
- Reconnaissance information leak on LAN.
- Not directly exploitable but enables other attacks.
- `/healthz` remains public (standard, lightweight, no details).

**Solution**:

```go
// After v1.0.0:
func handleReadyz(w http.ResponseWriter, r *http.Request) {
    if !isLocalRequest(r) {
        w.WriteHeader(http.StatusForbidden)
        json.NewEncoder(w).Encode(map[string]string{
            "error": "readyz is localhost-only",
        })
        return
    }
    // ... checks ...
}
```

**Comparison**:

| Endpoint | Before | After |
|----------|-----|-----|
| `/healthz` | public | public (standard) |
| `/readyz` | public | localhost-only |

<a name="526"></a>
### 5.26 `shellQuote` Injection Protection (Fix NEW-5 / Audit #31)

**Background**:

```go
// Before v1.0.0:
func isPortOpen(port int) bool {
    // ...
    cmd := fmt.Sprintf(". %s/functions.sh; is_port_open %d udp", MODDIR, port)
    return runShell(cmd) == nil  // ← MODDIR unquoted!
}
```

**Problem**:
If `MODDIR` contained:
- **A space**: `/data/adb/modules/dnscrypt proxy` → command fails.
- **Shell metacharacters**: `/tmp/evil;rm -rf/` → full injection:
  ```bash
  . /tmp/evil;rm -rf//functions.sh; is_port_open 5354 udp
  #     ↑ runs!
  ```

**Impact**:
- Theoretically: `MODDIR` is derived from `os.Executable()` — a normal user cannot change it.
- However, defense-in-depth is required.
- No practical vector today (but incorrect in principle).

**Solution (v1.0.0)**:

```go
// After v1.0.0:
func shellQuote(s string) string {
    for _, r := range s {
        if r == ' ' || r == '"' || r == '\'' || r == '$' || r == '`' ||
            r == '\\' || r == '!' || r == '&' || r == '|' || r == ';' ||
            r == '(' || r == ')' || r == '<' || r == '>' || r == '*' ||
            r == '?' || r == '[' || r == ']' || r == '#' || r == '~' {
            return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
        }
    }
    return s
}

// applied:
cmd := fmt.Sprintf(". %s/functions.sh; is_port_open %d udp", shellQuote(MODDIR), port)
```

**Usages (3+ places)**: `isPortOpen`, `startService`, `stopService`, SIGTERM handler.

**Security table**:

| Input | Before | After |
|-------|-----|-----|
| `/data/adb/modules/dnscrypt-proxy-webui` | ✅ | ✅ |
| `/tmp/foo bar` | ❌ | ✅ |
| `/tmp/$HOME` | ⚠️ expansion | ✅ literal |
| `/tmp/evil;rm -rf/` | injection | ✅ literal |

**v1.1.0 extension** (see §5.28 below for the extended version):

- The v1.0.0 character set above is missing three classes that
  could matter in edge cases:
  - `{`, `}` — brace expansion in shells (e.g. `a{b,c}` → `ab ac`).
  - `\n`, `\t` — whitespace that word-splitting treats as a
    separator when the string is embedded in a shell command.
- The extended `shellQuote` in v1.1.0 includes all four.

<a name="527"></a>
### 5.27 Auth Cache (60 s) (Fix NEW-6 / Audit #32)

**Background**:

```go
// Before v1.0.0:
func checkAuth(r *http.Request) bool {
    // ...
    expectedUser, expectedPass := getMonitoringAuth()  // ← file I/O on every request!
    // ...
}

func getMonitoringAuth() (string, string) {
    // reads the full TOML on every call
    data, _ := os.ReadFile(CONF)
    // ...
}
```

**Problem**:
- Every HTTP request calls `checkAuth`.
- `checkAuth` reads the entire `dnscrypt-proxy.toml` (~5–10 KB).
- On resource-constrained Android:
  - Continuous I/O → battery drain.
  - ~5–10 ms per request.

**Impact**:
- Not an attack vector — but **reduces performance**.
- From a security angle: potential DoS vector (1000 req/s → 10 MB/s I/O).
- With existing rate limiting, the impact is limited.

**Solution**:

```go
// After v1.0.0:
const AUTH_CACHE_TTL = 60 * time.Second

var (
    authCacheMu   sync.RWMutex
    authCacheUser string
    authCachePass string
    authCacheTime time.Time
)

func getMonitoringAuth() (username, password string) {
    // 1) cache check
    authCacheMu.RLock()
    if !authCacheTime.IsZero() && time.Since(authCacheTime) < AUTH_CACHE_TTL {
        u, p := authCacheUser, authCachePass
        authCacheMu.RUnlock()
        return u, p
    }
    authCacheMu.RUnlock()

    // 2) cache miss → file read
    user, pass := readMonitoringAuthFromFile()

    // 3) update cache
    authCacheMu.Lock()
    authCacheUser = user
    authCachePass = pass
    authCacheTime = time.Now()
    authCacheMu.Unlock()

    return user, pass
}

// manual invalidation (reserved for future use)
func invalidateAuthCache() {
    authCacheMu.Lock()
    authCacheUser = ""
    authCachePass = ""
    authCacheTime = time.Time{}
    authCacheMu.Unlock()
}
```

**Impact**:

| Scenario | Before | After |
|----------|-----|-----|
| 100 req/s | ~1 MB/s I/O | ~0 MB/s (cache) |
| Response time | ~5–10 ms | ~0.05 ms |
| Battery consumption | High | Low |

**Security**:
- **Changing credentials** does not take effect immediately (60 s delay).
- **Acceptable** because:
  - Credentials are rarely changed.
  - `invalidateAuthCache()` is available for immediate use.
  - TTL is short.
- No new attack vector.

<a name="528"></a>
### 5.28 Rebuild Blocklist Mutex (RACE-1) (Audit #33)

**Background**:

```go
// Before v1.0.0:
func rebuildBlocklist() error {
    // ← no lock!
    allowData, _ := os.ReadFile(ALLOWLIST_FILE)
    // ...
    atomicWriteStream(BLOCKLIST_FILE, 0644, func(w io.Writer) error {
        // ...
    })
    return nil
}

func updateProfile(key string) map[string]interface{} {
    // ...
    os.Rename(tempFile, RAW_BLOCKLIST_FILE)  // ← writes RAW
    rebuildBlocklist()                        // ← reads RAW + ALLOWLIST → BLOCKLIST
    // ...
}

func atomicSaveRulesInternal(req saveRulesRequest) (saveRulesResult, bool) {
    rulesStateMu.Lock()
    defer rulesStateMu.Unlock()

    atomicWriteFile(ALLOWLIST_FILE, ...)     // ← writes ALLOWLIST
    rebuildBlocklist()                        // ← reads RAW + ALLOWLIST → BLOCKLIST
    // ...
}
```

**Problem — race condition**:
- Both functions may call `rebuildBlocklist` concurrently.
- `updateProfile` runs in a **goroutine** (spawned from `handleAPI`).
- `atomicSaveRulesInternal` runs in another HTTP handler.
- **Result**:
  - Real race condition.
  - Final `BLOCKLIST` may contain an inconsistent mixture.

**Catastrophic scenario**:

```text
[updateProfile in goroutine]        [saveAllowlist in HTTP handler]
       ↓                                     ↓
   write RAW (v2)                       write ALLOWLIST (v2)
       ↓                                     ↓
   rebuildBlocklist ←────────────────→ rebuildBlocklist
   (no lock: interleaved reads)
   ↓                                     ↓
   BLOCKLIST may contain:
     - rules from ALLOWLIST v1 + RAW v2
     - missing rules
     - duplicated rules
```

**Impact**:
- Potential corruption of `BLOCKLIST` (requires manual rebuild).
- Low probability (but real).

**Solution**:

```go
// After v1.0.0:
var rebuildMu sync.Mutex

func rebuildBlocklist() error {
    rebuildMu.Lock()
    defer rebuildMu.Unlock()
    // ... existing code ...
}
```

**Coarse-grained lock** — the entire function is protected.

**Impact**:

| Scenario | Before | After |
|----------|-----|-----|
| `updateProfile` + `saveAllowlist` concurrently | race | serialized |
| `BLOCKLIST` consistency | may corrupt | guaranteed |
| `updateProfile` alone | works | works |
| `saveAllowlist` alone | works | works |

**Important constraint**: `defer rebuildMu.Unlock()` must always be present.

<a name="529"></a>
### 5.29 Runtime Info Ports (PORT-2)

**Background**:

```html
<!-- Before v1.0.0 (web/index.html): -->
<a href="http://127.0.0.1:9091" ...>Dashboard</a>
<!-- ↑ hardcoded port -->

<!-- Before v1.0.0 (web/dashboard.html): -->
<a href="http://127.0.0.1:9090">Back to Control Panel</a>
<!-- ↑ hardcoded port -->
```

**Problem**:
- User changes `PORT=8081` or `DASHBOARD_PORT=8082` in `webui.conf`.
- The HTML links remain `9090`/`9091` → **broken**.
- PWA shortcuts in `manifest.json` → broken.
- No dynamic way for the frontend to learn the ports.

**Impact**:
- Poor UX: "Why isn't the link working?"
- User must build the URL manually.
- Prevents reasonable port customization.

**Solution**:

**Backend** (`buildRuntimeInfo`):

```go
func buildRuntimeInfo() map[string]interface{} {
    info := map[string]interface{}{
        "version":     BuildVersion,
        // ... existing fields ...

        // v1.0.0 PORT-2:
        "webui_port":     getWebUIPort(),
        "dashboard_port": getDashboardPort(),
    }
    return info
}
```

**Frontend** (`web/index.html` + `web/dashboard.html`):

```javascript
// PORTS object
var PORTS = {
    webui:     '9090',
    dashboard: '9091'  // default — updated from runtime_info
};

function getDashboardUrl() {
    var hostname = window.location.hostname || '127.0.0.1';

    // IPv6 handling
    if (hostname.indexOf(':') !== -1 && hostname.charAt(0) !== '[') {
        hostname = '[' + hostname + ']';
    }

    var protocol = window.location.protocol === 'https:' ? 'https:' : 'http:';
    return protocol + '//' + hostname + ':' + PORTS.dashboard + '/';
}

// on loadRuntimeInfo:
if (data.webui_port)     PORTS.webui     = String(data.webui_port);
if (data.dashboard_port) {
    PORTS.dashboard = String(data.dashboard_port);
    updateDashboardLink();  // ← instant update
}

// in boot():
updateBackToHomeLinks();  // ← fallback before runtime_info
```

**PWA** (`manifest.json`):
- `x-note-port-limitation` — documented limitation.
- `x-note-ports` — reference table.
- **Cannot** read `runtime_info` (evaluated before JS).

**Offline** (`offline.html`):
- Ports info box (WebUI + Dashboard).
- Direct "Open Dashboard" button.
- Note: "Check `webui.conf` if you changed ports".

**Impact**:

| Scenario | Before | After |
|----------|-----|-----|
| Default (9090/9091) | ✅ works | ✅ works |
| DASHBOARD_PORT=8081 | ❌ broken link | ✅ works |
| PORT=8081 | ❌ broken link | ✅ works |
| LAN access | ❌ opens 127.0.0.1 | ✅ opens 192.168.1.x |
| IPv6 loopback | ❌ opens 127.0.0.1 | ✅ opens [::1] |
| runtime_info fails | — | ✅ fallback to 9090 |
| PWA shortcuts | ⚠️ default | ⚠️ default (documented) |

**Security**:
- No new information leakage.
- `runtime_info` is protected by `checkAuth`.
- No privileged escalation.

**Note**: this fix has no separate Audit Correction number — it is part of v1.0.0 with reference to `#529`.

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

**Problem**:
- The `ultimate` blocklist profile requires substantially more
  than 80 MB of working memory during `rebuildBlocklist` and
  while serving concurrent requests.
- `debug.SetMemoryLimit` is a **soft** limit: when actual usage
  approaches it, the Go runtime runs GC more aggressively.
- With 80 MB hardcoded, the `ultimate` profile triggered
  continuous GC cycles. On low-RAM devices this looked like an
  application freeze — a self-inflicted DoS surface.

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

func memoryLimitForProfile(key string) int64 {
    switch strings.ToLower(strings.TrimSpace(key)) {
    case "light":    return MEMORY_LIMIT_LIGHT
    case "normal":   return MEMORY_LIMIT_NORMAL
    case "pro":      return MEMORY_LIMIT_PRO
    case "proplus":  return MEMORY_LIMIT_PROPLUS
    case "ultimate": return MEMORY_LIMIT_ULTIMATE
    default:         return MEMORY_LIMIT_DEFAULT
    }
}

func applyMemoryLimit(key string) {
    memLimitMu.Lock()
    defer memLimitMu.Unlock()

    limit := memoryLimitForProfile(key)
    if limit == currentMemLimit && key == currentProfile {
        return
    }
    old := debug.SetMemoryLimit(limit)
    currentMemLimit = limit
    currentProfile = key
    logWithLevel("info", ...)
}
```

Called from:
- `main()` at startup (after `readSelectedProfile()`).
- `updateProfile()` after `atomicWriteFile(SELECTED_FILE)`.

**Impact**:

| Profile | Before v1.1.0 | After v1.1.0 |
|---------|:---:|:---:|
| light | 80 MB | 80 MB |
| normal | 80 MB | 100 MB |
| pro | 80 MB | 120 MB |
| proplus | 80 MB | 160 MB |
| ultimate | 80 MB (GC thrashing) | 220 MB |

**Observability**:
- `runtime_info` now exposes `memory_limit_mb` and
  `profile_key`. These are shown in both the WebUI and
  Dashboard System Info panels.
- The startup log line reports the effective limit:
  `🧠 v1.1.0: dynamic memory limit — profile=pro, limit=120 MB`.

**Security rationale**:
- Removes a self-inflicted DoS surface (GC thrashing) that a
  user could trigger by selecting the legitimate `ultimate`
  profile.
- The limit remains **soft** — it is not an enforced cap. An
  attacker who could already reach the process memory (e.g.
  via a separate bug) is not newly empowered; they were
  already inside the trust boundary.

#### 5.30.2 Extended `shellQuote` Character Set (MEM-2)

**Background**:

The v1.0.0 `shellQuote` escaped 20 shell-significant characters:
` `, `"`, `'`, `$`, `` ` ``, `\`, `!`, `&`, `|`, `;`, `(`, `)`,
`<`, `>`, `*`, `?`, `[`, `]`, `#`, `~`.

Four characters were not escaped:
- `{`, `}` — brace expansion in POSIX-compatible shells.
- `\n`, `\t` — whitespace that word-splitting treats as a
  separator.

**Problem**:
- A path containing `{` or `}` would be brace-expanded by the
  shell before being passed to the actual command. Example:
  `shellQuote("a{b,c}")` returned `a{b,c}` unchanged, and the
  shell then expanded it to two arguments `ab ac`.
- A path containing a literal newline or tab would be
  word-split into separate arguments.

**Practical impact today**:
- `MODDIR` is derived from `os.Executable()`. A normal user
  cannot make it contain `{` or `\n`.
- Therefore no known exploitable path exists.

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

**Security rationale**:
- Defense-in-depth. No known exploit existed before.
- Closes a class of input rather than a specific case.

#### 5.30.3 `MONITORING_UI_PORT` in Metrics Handler (MEM-3)

**Background**:

```go
// Before v1.1.0 (metricsProxyHandler):
req, err := http.NewRequestWithContext(r.Context(), "GET",
    "http://127.0.0.1:8080/api/metrics", nil)
//   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ hardcoded "8080"
```

**Problem**:
- The reserved port 8080 was hardcoded in one more place, even
  though the constant `MONITORING_UI_PORT` already existed.
- If the reserved port ever changes, this instance would be
  missed during the update.

**Solution**:

```go
// After v1.1.0:
monitoringURL := "http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"

req, err := http.NewRequestWithContext(r.Context(), "GET", monitoringURL, nil)
```

**Security rationale**:
- Single source of truth for the reserved port.
- Reduces the number of files to audit if the port ever changes.
- Aligns with the same pattern already used in
  `getWebUIPort()` and `getDashboardPort()`.

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

---

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

**TODO**: remove `'unsafe-inline'`.
**Solution**: convert `onclick` to `addEventListener`.
**Reference**: [MDN CSP script-src](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/script-src)

---

## 7. Authentication

### 7.1 Supported Schemes

| Scheme | Priority | Rate Limited | Persistence |
|---|---|:---:|---|
| Basic Auth | 1 | Yes | per-request |
| Bearer Token | 2 | No | 24h (for compatibility) |
| Session Cookie | 3 | No | 24h (primary) |

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

**Fix #10**: support for section header with comment (`[monitoring_ui] # comment`).

**Fix NEW-6**: cache read (60 s TTL).

### 7.3 Constant-time Comparison

```go
userMatch := subtle.ConstantTimeCompare([]byte(user), []byte(expectedUser)) == 1
passMatch := subtle.ConstantTimeCompare([]byte(pass), []byte(expectedPass)) == 1
```

### 7.4 Rate Limiting

- 5 failed attempts per IP.
- 15-minute lockout.
- `LOGIN_ATTEMPT_STALE_PERIOD = 1h` — cleanup of old IPs.
- `getClientIP()` — IPv6 support in the key.
- **Fix #8**: Basic Auth protected by the same mechanism.

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
| Content hash | SHA-256 |
| Password compare | subtle.ConstantTimeCompare |
| TLS (downloads) | TLS 1.2+ |
| Temp files | os.CreateTemp (CSPRNG-based) |

### 10.3 Not Present

- No blocklist encryption (public data).
- No log encryption.
- No credential file encryption.
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
- **Auth cache hits/misses** (debug level).
- **v1.1.0**: memory limit transitions (info level).
  Example: `memory limit adjusted: 80 MB → 120 MB (profile=pro)`

### 11.2 What We Do Not Log

- DNS queries.
- Passwords explicitly.
- Session tokens.
- Browsing history.

### 11.3 Log Rotation

| Log | Threshold | Retention |
|---|---|---|
| dnscrypt_main.log | 1 MB | 5 .gz |
| dnscrypt-proxy.log | 6 MB | 3 days |
| dnscrypt-blocked.log | — | user-managed |

### 11.4 Privacy Guarantee

- Zero telemetry.
- No connection to any server other than DNSCrypt/DoH servers.

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
| **Soft memory limit is not a hard cap** | **Go runtime design (v1.1.0)** |

### 13.2 Known Issues (will be fixed)

| Issue | Proposed fix | Version |
|---|---|---|
| CSP `'unsafe-inline'` | Convert onclick → addEventListener | v1.2 |
| `pgrep -x` on Android 5.x | fallback | v1.2 |
| awk with `]` in comment | improve parser | v1.2 |
| PWA dual-origin (9090 vs 9091) | unify on one port | v1.2 |
| `manifest.json` shortcuts do not read `runtime_info` | unify on one port | v1.2 |
| Maskable icon reuses `icon-512.png` | ship dedicated maskable SVG | v1.2 |

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
- **v1.1.0**: Dynamic per-profile memory limit (MEM-1).
- **v1.1.0**: Extended `shellQuote` charset (MEM-2).
- **v1.1.0**: `MONITORING_UI_PORT` in metrics handler (MEM-3).

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
- [ ] **v1.1.0**: `memory_limit_mb` + `profile_key` returned by `runtime_info`.
- [ ] **v1.1.0**: Memory limit applies correctly on startup.
- [ ] **v1.1.0**: Memory limit re-applies on profile change.
- [ ] **v1.1.0**: `MONITORING_UI_PORT` used in `metricsProxyHandler`.

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
- [ ] **v1.1.0**: Memory limit matches active profile.
- [ ] **v1.1.0**: Startup log reports the effective memory limit.

### 14.3 User

- [ ] User did not share credentials.
- [ ] Did not open 0.0.0.0 without a firewall.

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

**Verify**:

```bash
curl -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"test"}' \
    -i 2>&1 | grep -i "set-cookie"
```

### 14.5 CSRF Audit

- [ ] toggle → POST only.
- [ ] restart → POST only.
- [ ] ensure_running → POST only.
- [ ] login → POST only.
- [ ] logout → POST only.
- [ ] 405 with `Allow: POST` header.
- [ ] PWA shortcuts work.

**Verify**:

```bash
# GET must fail
curl -i "http://127.0.0.1:9090/api?action=toggle"
# Expected: 405 + Allow: POST

# POST must succeed
curl -i -X POST -b /tmp/cookies.txt \
    "http://127.0.0.1:9090/api/toggle_service"
# Expected: 200

# Login GET must fail
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: 405 + Allow: POST
```

### 14.6 Token Leakage Audit

- [ ] No token in login response.
- [ ] No sessionStorage in JS.
- [ ] HttpOnly cookie only.

**Verify**:

```bash
curl -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"test"}' | jq
# Expected: {status, message, profile} — no token
```

### 14.7 Firewall Audit

- [ ] iptables does not contain IPv6.
- [ ] ip6tables contains IPv6 bootstrap.
- [ ] nftables uses case filter (IPv4/IPv6).
- [ ] No DNS loop on IPv4.
- [ ] No DNS loop on IPv6.

**Verify**:

```bash
# 1. iptables must contain IPv4 bootstrap only
su -c "iptables -t nat -L OUTPUT -n | grep -E 'RETURN|DNAT'"

# 2. ip6tables must contain IPv6 bootstrap
su -c "ip6tables -t nat -L OUTPUT -n | grep -E 'RETURN|DNAT'"

# 3. test bootstrap directly (IPv4)
su -c "dig @9.9.9.9 google.com +short +timeout=3"

# 4. test bootstrap directly (IPv6)
su -c "dig @2606:4700:4700::1111 google.com +short +timeout=3"

# Expected: IP addresses within < 100 ms (no loop)
```

### 14.8 Custom Chains Audit

- [ ] OUTPUT contains only jump rules (two static rules).
- [ ] DNSCRYPT_OUT exists and contains RETURN + DNAT.
- [ ] DNSCRYPT_OUT6 exists (if IPv6 is available).
- [ ] No orphan RETURN rules in OUTPUT.
- [ ] On stopService: DNSCRYPT_OUT is fully removed.

**Verify**:

```bash
# 1. view OUTPUT
su -c "iptables -t nat -L OUTPUT -n -v"
# Expected: only two rules (udp/tcp dport 53 → DNSCRYPT_OUT)

# 2. view DNSCRYPT_OUT
su -c "iptables -t nat -L DNSCRYPT_OUT -n -v"
# Expected: RETURN rules + DNAT

# 3. static audit
grep -q "DNSCRYPT_OUT" proxy/functions.sh && echo "✅ Custom Chain present"
```

### 14.9 Status File Audit

- [ ] STATUS_FILE written only by startService/stopService.
- [ ] getStatusUncached does not write.
- [ ] Watchdog reads only.

**Verify**:

```bash
# 1. monitor STATUS_FILE
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"

# 2. crash recovery test
su -c "pkill -9 dnscrypt-proxy"
sleep 60
su -c "sh status.sh --json | jq .dns_engine.running"
# Expected: true (Watchdog restarted)

# 3. static audit
grep -A5 'func getStatusUncached' proxy/main.go | grep -q 'atomicWriteFile' && echo "⚠️ writes!" || echo "✅ read-only"
```

### 14.10 IPv6 Rate Limit Audit

- [ ] getClientIP uses net.SplitHostPort.

**Verify**:

```bash
grep -A5 'func getClientIP' proxy/main.go | grep -q 'net.SplitHostPort' && echo "✅ IPv6-safe"
```

### 14.11 Port Collision Audit

- [ ] MONITORING_UI_PORT constant = "8080" in main.go.
- [ ] _MONITORING_UI_PORT constant = "8080" in every shell.
- [ ] main.go rejects PORT=8080.
- [ ] customize.sh rejects PORT=8080.

**Verify**:

```bash
# 1. main.go test
grep -q 'MONITORING_UI_PORT = "8080"' proxy/main.go && echo "✅ Go constant"
grep -q '_MONITORING_UI_PORT="8080"' proxy/functions.sh && echo "✅ Shell constant"

# 2. Runtime test
echo "PORT=8080" >> proxy/webui.conf
cd proxy && go run main.go
# Expected: FATAL + exit 1
```

### 14.12 Section-Restricted TOML Audit

- [ ] getMonitoringAuth tracks sections.
- [ ] read_toml_credentials tracks sections.
- [ ] watchdog.sh reads from `[monitoring_ui]` only.

**Verify**:

```bash
grep -q 'inSection' proxy/main.go && echo "✅ main.go tracks sections"
grep -q 'in_section' proxy/functions.sh && echo "✅ functions.sh tracks sections"
grep -q 'in_section' proxy/watchdog.sh && echo "✅ watchdog.sh tracks sections"
```

### 14.13 Basic Auth Rate Limit Audit

- [ ] `checkAuth` records failed Basic Auth attempts.
- [ ] `isLockedOut` is checked before `BasicAuth`.
- [ ] Successful Basic Auth resets the counter.

**Verify**:

```bash
# 1. static audit
grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅ Basic Auth failures recorded"

# 2. Integration test (5 failed attempts)
for i in 1 2 3 4 5 6; do
  curl -u "wrong:wrong" http://127.0.0.1:9090/api?action=status \
    -o /dev/null -w "%{http_code}\n"
done
# Expected: 401, 401, 401, 401, 401, 401 (locked)
```

### 14.14 Exact Endpoint Matching Audit

- [ ] `hasEndpoint` present in main.go.
- [ ] All POST endpoints use `hasEndpoint`.
- [ ] No `strings.Contains` for paths.

**Verify**:

```bash
# 1. static audit
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ hasEndpoint present"

# 2. no strings.Contains for paths
! grep -q 'strings.Contains(r.URL.Path, "update_profile")' proxy/main.go && echo "✅ no loose matching"

# 3. Integration
curl -i "http://127.0.0.1:9090/api?action=definitely_unknown"
# Expected: 404
```

### 14.15 JSON Conversion Audit

- [ ] `parsePrometheus` present.
- [ ] `buildDashboardJSON` present.
- [ ] `metricsProxyHandler` returns JSON.
- [ ] Content-Type correct.

**Verify**:

```bash
# 1. static audit
grep -q 'func parsePrometheus' proxy/main.go && echo "✅ parsePrometheus"
grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅ buildDashboardJSON"

# 2. Integration
curl -s -I "http://127.0.0.1:9091/api/metrics" | grep Content-Type
# Expected: Content-Type: application/json; charset=utf-8

curl -s "http://127.0.0.1:9091/api/metrics" | jq '.total_queries'
# Expected: a number (instead of a parse error)
```

### 14.16 Login POST-only Audit

- [ ] `/api/auth/login` accepts POST only.
- [ ] `/api/auth/logout` accepts POST only.
- [ ] GET/HEAD/PUT/DELETE → 405 + `Allow: POST`.

**Verify**:

```bash
# 1. static audit
grep -q 'hasEndpoint(r.URL.Path, "auth/login")' proxy/main.go && echo "✅ login uses hasEndpoint"
grep -q 'http.StatusMethodNotAllowed' proxy/main.go && echo "✅ 405 present"

# 2. Integration — GET must fail
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: 405 Method Not Allowed + Allow: POST
```

### 14.17 `/readyz` Localhost-Only Audit

- [ ] `/readyz` rejects non-localhost.
- [ ] `/healthz` remains public.
- [ ] 403 for external requests.

**Verify**:

```bash
# 1. static audit
grep -A30 'func handleReadyz' proxy/main.go | grep -q 'isLocalRequest(r)' && echo "✅ readyz localhost-only"

# 2. Integration (from localhost: success)
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9091/readyz
# Expected: 200 or 503 (depending on state)

# 3. Integration (from LAN — if BIND_ADDR=0.0.0.0)
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.1.5:9091/readyz
# Expected: 403
```

### 14.18 `shellQuote` Audit

- [ ] `shellQuote` present in main.go.
- [ ] Used in 3+ places (isPortOpen, startService, stopService, SIGTERM).
- [ ] No `. " + MODDIR + "` without shellQuote.
- [ ] **v1.1.0**: extended character set includes `{`, `}`, `\n`, `\t`.

**Verify**:

```bash
# 1. static audit
grep -q 'func shellQuote' proxy/main.go && echo "✅ shellQuote present"
USAGE=$(grep -c 'shellQuote(MODDIR)' proxy/main.go)
[ "$USAGE" -ge 3 ] && echo "✅ shellQuote used $USAGE times"

# 2. v1.1.0 extended charset
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ braces"
grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\n'" && echo "✅ newline"
grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\t'" && echo "✅ tab"
```

### 14.19 `readConfPort` Range Audit

- [ ] `readConfPort` present in main.go.
- [ ] Checks `n < 1` and `n > 65535`.
- [ ] Falls back to default.

**Verify**:

```bash
# 1. static audit
grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' && echo "✅ range check present"
```

### 14.20 `rebuildMu` Mutex Audit

- [ ] `rebuildMu sync.Mutex` declared.
- [ ] `rebuildBlocklist` uses `rebuildMu.Lock()` + `defer Unlock()`.

**Verify**:

```bash
# 1. static audit
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ rebuildMu declared"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'rebuildMu.Lock()' && echo "✅ Lock present"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'defer rebuildMu.Unlock()' && echo "✅ Unlock present"
```

### 14.21 `runtime_info` Ports Audit

- [ ] `buildRuntimeInfo` returns `webui_port` + `dashboard_port`.
- [ ] `index.html` uses `data.dashboard_port`.
- [ ] `dashboard.html` uses `data.webui_port`.

**Verify**:

```bash
# 1. static audit (backend)
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ webui_port"
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"dashboard_port"' && echo "✅ dashboard_port"

# 2. static audit (frontend)
grep -q 'data.dashboard_port' web/index.html && echo "✅ index.html uses dashboard_port"
grep -q 'data.webui_port' web/dashboard.html && echo "✅ dashboard.html uses webui_port"

# 3. Integration (with custom ports)
# change PORT=8081 in webui.conf
curl -s "http://127.0.0.1:8081/api?action=runtime_info" | jq
# Expected: {..., "webui_port": "8081", "dashboard_port": "9091"}
```

### 14.22 v1.1.0 — Dynamic Memory Limit Audit (MEM-1)

- [ ] `memoryLimitForProfile` declared in main.go.
- [ ] `applyMemoryLimit` declared in main.go.
- [ ] All 5 profile constants defined.
- [ ] No hardcoded `debug.SetMemoryLimit(80 * 1024 * 1024)` remains.
- [ ] `applyMemoryLimit` called from `main()`.
- [ ] `applyMemoryLimit` called from `updateProfile`.

**Verify**:

```bash
# 1. static audit
grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ function"
grep -q 'func applyMemoryLimit' proxy/main.go && echo "✅ apply"

# 2. all profile constants
for c in LIGHT NORMAL PRO PROPLUS ULTIMATE DEFAULT; do
  grep -q "MEMORY_LIMIT_$c" proxy/main.go && echo "✅ MEMORY_LIMIT_$c"
done

# 3. no hardcoded limit
! grep -q 'debug.SetMemoryLimit(80 \* 1024 \* 1024)' proxy/main.go && echo "✅ no hardcoded 80MB"

# 4. called from main() and updateProfile()
grep -c 'applyMemoryLimit(' proxy/main.go
# Expected: >= 3 (definition + 2 call sites)
```

### 14.23 v1.1.0 — Extended `shellQuote` Audit (MEM-2)

See §14.18 for the verify block. This section exists as a
cross-reference so that a reviewer scanning for v1.1.0 items
finds the check under both labels.

### 14.24 v1.1.0 — `MONITORING_UI_PORT` in Metrics Handler (MEM-3)

- [ ] No hardcoded `"http://127.0.0.1:8080/api/metrics"` remains.
- [ ] `metricsProxyHandler` uses `MONITORING_UI_PORT`.

**Verify**:

```bash
# 1. no hardcoded URL
! grep -q '"http://127.0.0.1:8080/api/metrics"' proxy/main.go && echo "✅ no hardcoded URL"

# 2. constant used in handler
grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ constant used"

# 3. Integration — verify the proxy still works
curl -s -b /tmp/cookies.txt http://127.0.0.1:9091/api/metrics | jq '.total_queries'
# Expected: a number
```

---

## 15. Acknowledgments

Thanks to everyone who has contributed to the security of the project:

- All the Security Researchers who have responsibly disclosed issues.
- The GitHub community for code review.
- **Anthropic Claude** for assistance with the audit and review.

---

## 16. Changelog — Security Changes

### v1.1.0 (2026-09-26)

**Polish release — no new audit corrections.**

This release consolidates three runtime improvements that
affect the security posture but do not warrant new audit
correction numbers:

**Runtime improvements**:

- **MEM-1 — Dynamic memory limit per profile (main.go)**
  Replaces the hardcoded `debug.SetMemoryLimit(80 MB)` with a
  per-profile limit computed by `memoryLimitForProfile()`:
  light=80, normal=100, pro=120, proplus=160, ultimate=220.
  Prevents GC thrashing on heavy profiles without weakening
  DoS protection on light profiles. Exposed via
  `runtime_info.memory_limit_mb`.

- **MEM-2 — Extended `shellQuote` character set (main.go)**
  Adds `{`, `}`, `\n`, `\t` to the escape list. Defense in
  depth; no known exploitable path existed before.

- **MEM-3 — `MONITORING_UI_PORT` in metrics handler (main.go)**
  Removes the last hardcoded `"8080"` string from
  `metricsProxyHandler`. Single source of truth for the
  reserved port.

**Documentation updates**:

- §5.30 (new) — documents MEM-1 / MEM-2 / MEM-3 in the Attack
  Vectors section.
- §14.22 (new) — memory limit audit.
- §14.23 (new) — extended shellQuote audit (cross-reference).
- §14.24 (new) — MONITORING_UI_PORT audit.
- §2.1 — added memory limit integrity to protected assets.
- §3.2 — added dynamic per-profile memory limit to applied
  protections.
- §11.1 — added memory limit transition logging.
- §13.3 — added MEM-1 / MEM-2 / MEM-3 to compensating controls.

**No changes to**:
- §1–4 (Reporting, Scope, Threat Model, Assets)
- §5.1–5.29 (all prior attack vectors)
- §6–13 (Headers, Auth, Sessions, Input, Crypto, Logging,
  Supply Chain, Known Limitations)
- §15 (Acknowledgments)
- §17 (Audit Corrections Registry remains at #33)

### v1.0.0 (2026-09-24)

**First stable release.** All accumulated fixes from development (33 Audit Corrections) are consolidated into a single stable `v1.0.0`.

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

**Checklist updates**:
- §14.1: 6 new checks.
- §14.2: 6 new runtime checks.
- §14.5: +2 items (login/logout POST-only).
- §14.16-14.21: 6 new audit sections.

**Known issues remaining**:
- CSP `'unsafe-inline'` — scheduled for v1.2.
- CodeQL triggers `web/` — scheduled for v1.2.
- PWA dual-origin — scheduled for v1.2.

---

## 17. Audit Corrections Registry

> **v1.1.0 note**: This release does **not** extend the registry.
> The last audit correction is #33, from v1.0.0. v1.1.0 is a
> documentation + polish release that consolidates three
> runtime improvements (MEM-1, MEM-2, MEM-3) without assigning
> them audit correction numbers — they close edge cases, not
> new vulnerabilities.
>
> New audit corrections will resume at **#34** in v1.2.x.

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
**Next expected**: #34 (v1.2.x)

### 17.1 v1.1.0 Runtime Improvements (Not Audit Corrections)

| ID | Change | Rationale |
|:-:|---|---|
| MEM-1 | Dynamic memory limit per profile | Closes a self-inflicted DoS surface (GC thrashing on `ultimate`) |
| MEM-2 | Extended `shellQuote` charset (`{`, `}`, `\n`, `\t`) | Defense in depth; no known exploit existed |
| MEM-3 | `MONITORING_UI_PORT` in metrics handler | Single source of truth; removes last hardcoded reserved port |

These are documented in §5.30 for completeness but are not
assigned audit correction numbers because they do not fix a
known exploitable vulnerability.

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
- [RFC 7282 — On Consensus and Humming in the IETF (State vs Intent)](https://datatracker.ietf.org/doc/html/rfc7282)
- [Go runtime/debug.SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)

---

**Last updated**: 2026-09-26
**Version**: v1.1.0
**Author**: gasciljh