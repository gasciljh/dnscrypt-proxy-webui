# Glossary — Terms & Abbreviations

> Comprehensive reference for all terms and abbreviations used
> in DNSCrypt Smart Filter.

**Version**: v1.1.0
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • §5 Project-Specific Terms gained 6 new entries:
>     MEM-1 (Dynamic memory limit), MEM-2 (Extended shellQuote),
>     MEM-3 (MONITORING_UI_PORT constant), `profile_key`,
>     `memory_limit_mb`, and "Soft limit".
>   • §6 Go & Shell Terms gained 2 new entries:
>     `debug.SetMemoryLimit` and `memLimitMu`.
>   • §8 Metrics & Abstraction Terms gained a v1.1.0 note
>     about the `runtime_info` additions.
>   • §10 Common Abbreviations gained 4 entries:
>     GC, RSS, OOM, LMK.
>   • §11 Fixes Index gained a new section for the v1.1.0
>     Runtime Improvements (MEM-1 / MEM-2 / MEM-3).
>   • The Audit Corrections Registry remains at #33 — v1.1.0
>     does not extend it (see `docs/SECURITY.md` §17).
>   • §12 References updated with v1.1.0 additions.

---

## Table of Contents

1. [DNS Terms](#1-dns-terms)
2. [Network & Firewall Terms](#2-network--firewall-terms)
3. [Web & Security Terms](#3-web--security-terms)
4. [Android & Root Terms](#4-android--root-terms)
5. [Project-Specific Terms](#5-project-specific-terms)
6. [Go & Shell Terms](#6-go--shell-terms)
7. [CI/CD & Release Terms](#7-cicd--release-terms)
8. [Metrics & Abstraction Terms](#8-metrics--abstraction-terms)
9. [Advanced Security Terms](#9-advanced-security-terms)
10. [Common Abbreviations](#10-common-abbreviations)
11. [Fixes Index](#11-fixes-index)

---

## 1. DNS Terms

### 🌐 DNS — Domain Name System

A system that translates domain names (e.g. `google.com`) into IP
addresses (e.g. `142.250.185.46`).

**Without it**: You would type `142.250.185.46` instead of
`google.com`!

**Default port**: `53` (UDP/TCP).

---

### 🔐 DNSCrypt

**DNS query encryption protocol** developed by
[OpenDNS](https://www.opendns.com/).

**Purpose**: Prevent ISPs from seeing or tampering with DNS queries.

**Port**: `443` (UDP/TCP).
**Encryption**: X25519 + XSalsa20-Poly1305.

**Difference from DoH**: DNSCrypt is lighter (smaller data size) —
better on mobile networks.

---

### 🌐 DoH — DNS over HTTPS

**Sending DNS queries over HTTPS** (port 443) — appears like a normal
website visit.

**Purpose**: Bypass firewalls that block port 53.

**Providers**: Cloudflare, Google, Quad9.

**Difference from DNSCrypt**: DoH uses standard HTTPS — works anywhere
but slightly heavier.

---

### 🔒 DoT — DNS over TLS

**Sending DNS queries over TLS** (port 853).

**Difference from DoH**: DoT uses a dedicated port (853) → easier to
block.

**Difference from DNSCrypt**: DoT uses standard TLS 1.3 — but is easily
blocked.

---

### 🛡️ DNSSEC — DNS Security Extensions

**Security extensions for DNS** that cryptographically verify response
authenticity (signature).

**Purpose**: Prevent DNS spoofing attacks.

**⚠️ Note**: DNSSEC ensures **authenticity** — not privacy (that's
DNSCrypt/DoH's job).

---

### 🚀 Bootstrap Resolvers

**Public DNS servers** used only to download the actual server list
(`public-resolvers.md`).

**After download**: Not used — the engine starts using DNSCrypt/DoH
servers.

**Example**:
```toml
bootstrap_resolvers = ['9.9.9.9:53', '8.8.8.8:53', '1.1.1.1:53', '1.0.0.1:53']
```

**⚠️ v1.0.0**: Excluded from DNS redirection via `RETURN` rules inside
`DNSCRYPT_OUT`.

---

### ⚠️ DNS Leak

**Leakage of DNS queries** outside the encrypted tunnel (e.g. silently
using the ISP's DNS).

**Common causes**:
- VPN does not redirect DNS.
- Some apps use their own DNS (hardcoded).
- IPv6 routing not covered.

**Test**: Visit [dnsleaktest.com](https://www.dnsleaktest.com).

---

### 🚫 Blocklist

**List of blocked domains** — the actual source of blocking.

**Levels**: Light, Normal, PRO, PRO++, Ultimate.

**Source**: [HaGeZi DNS Blocklists](https://github.com/hagezi/dns-blocklists).

---

### 🎯 DNS Engine

**The actual DNS engine** — `dnscrypt-proxy` itself.

**In the project**:
- Binary: `proxy/dnscrypt-proxy`
- Version: `proxy/dnscrypt-proxy.version` (2.1.18)
- Listens on: `127.0.0.1:5354` (UDP/TCP)

**Managed by**: `main.go` via `startService()` / `stopService()`.

**⚠️ v1.1.0 note**: The DNS version (2.1.18) is **separate** from the
module version (v1.1.0). See §5 "DNS Version" for the distinction.

---

## 2. Network & Firewall Terms

### 🔥 iptables

**Linux firewall tool** (Netfilter).

**Common tables**:
- `filter` — allow/reject packets.
- `nat` — address translation (DNAT/SNAT).
- `mangle` — modify packet fields.

**Example from the project**:
```bash
iptables -t nat -I OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT
```

**⚠️ Note**: On Android 10+, `nftables` is often used instead.

---

### 🔥 nftables

**Modern replacement for iptables** (Kernel 4.10+).

**Advantages**: Faster, cleaner, supports IPv4 and IPv6 in the same
rules.

**Example from the project**:
```bash
nft add table inet dnscrypt_filter
nft add chain inet dnscrypt_filter dnscrypt_chain '{ type nat hook output priority -100; }'
```

---

### 📦 Custom Chains

**Dedicated iptables chains** created and managed independently from
the public chains.

**In the project**:
- `DNSCRYPT_OUT` (IPv4).
- `DNSCRYPT_OUT6` (IPv6).

**Philosophy**:
- ✅ Dynamic rules go **inside** the chain.
- ✅ Public `OUTPUT` is clean (two static rules).
- ✅ Cleanup = `-F` + `-X` = complete wipe in one shot.

**⚠️ Audit Correction #17** — Reason: Prevent **Orphans** when changing
`bootstrap_resolvers`.

---

### 🔄 DNAT — Destination NAT

**Destination address translation** of a network packet.

**In the project**:
```bash
-j DNAT --to-destination 127.0.0.1:5354
```
Means: "Any DNS query going to any server → redirect to local DNSCrypt
engine".

---

### ⏪ RETURN

**End processing of the packet in the current chain** and return to
before the `jump`.

**In the project**:
```bash
-A DNSCRYPT_OUT -d 127.0.0.1 -j RETURN
-A DNSCRYPT_OUT -d 9.9.9.9   -j RETURN
```
Means: "Do not redirect DNS queries from the DNSCrypt engine itself →
prevent infinite loop".

---

### 🔀 Orphan Rules

**Leftover firewall rules** with no effect (orphaned) — due to lack of
cleanup.

**Problem**: Accumulate over time → pollute the firewall.

**Solution in the project**: Custom Chains — **no orphans**.

---

### 🌐 IPv4

**Fourth version of the Internet Protocol** — 32-bit addresses.

**Format**: `192.168.1.1`

**Maximum**: ~4.3 billion addresses (exhausted in 2011!).

---

### 🌐 IPv6

**Sixth version** — 128-bit addresses.

**Format**: `2001:db8::1` or `[::1]` (localhost).

**Advantage**: ~340 undecillion addresses!

**⚠️ In the project**: Full support via `DNSCRYPT_OUT6` and
`getClientIP()`.

---

### 🔌 Loopback — 127.0.0.1 / ::1

**The "device itself" address** — does not leave the device.

**IPv4**: `127.0.0.1`
**IPv6**: `::1`

**In the project**: All servers run on loopback (by default) for
security.

---

### 🔀 Race Condition

**Condition where two operations reach the same data at the same
time** → unexpected results.

**Solution**: Mutexes + Atomic writes.

**Test**: `go run -race main.go`.

**v1.0.0 — RACE-1**: `rebuildMu` protects `rebuildBlocklist`.

---

### 🏗️ `rebuildMu`

**`sync.Mutex` in `main.go`** that protects `rebuildBlocklist` from
race conditions.

**Structure**:
```go
var rebuildMu sync.Mutex

func rebuildBlocklist() error {
    rebuildMu.Lock()
    defer rebuildMu.Unlock()
    // ...
}
```

**Problem before v1.0.0**:
- `updateProfile` (in goroutine) + `atomicSaveRulesInternal` (in HTTP
  handler) → BLOCKLIST inconsistent.

**Solution**:
- Coarse-grained lock — the entire function is protected.

**⚠️ v1.0.0 — RACE-1** (Audit Correction #32).

---

## 3. Web & Security Terms

### 📱 PWA — Progressive Web App

**Web app** that can be installed on the home screen like a normal app.

**Requirements**:
- `manifest.json` — description and icons.
- `sw.js` — Service Worker.
- HTTPS or localhost.

**In the project**: Works on `http://127.0.0.1:9090`.

---

### ⚙️ Service Worker (SW)

**Script that runs in the background** — controls network and storage.

**Functions**:
- Caching (offline support).
- Intercepting requests.
- Update notifications.

**In the project**: `web/sw.js` — manages Cache + detects updates.

**⚠️ dual-origin limitation**: SW is bound to a single origin (9090 ≠
9091).

---

### 📡 SSE — Server-Sent Events

**Unidirectional HTTP connection** — server pushes updates to client.

**Difference from WebSocket**:
- ✅ SSE: Simple, unidirectional (server → client).
- ⚠️ WebSocket: Complex, bidirectional.

**In the project**: `/events` endpoint — sends service status,
progress, statistics.

**⚠️ v1.0.0**: SSE Write Deadline = 30s (DoS protection).

---

### 🛡️ CSP — Content-Security-Policy

**HTTP header** that restricts resource sources (Scripts, Styles,
Images).

**Purpose**: Prevent XSS attacks.

**Example from the project**:
```http
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; frame-ancestors 'none'
```

**⚠️ Note**: `'unsafe-inline'` is currently present (TODO v1.2: remove
it).

**v1.1.0 note**: `web/offline.html` **no longer has a CSP meta**. The
previous `default-src 'none'` silently blocked the page's own scripts.
See §9 "Offline Page CSP Removal".

---

### 🎯 CSRF — Cross-Site Request Forgery

**Attack that tricks the browser** into sending an unwanted request
(using the victim's cookies).

**Example**:
```html
<img src="http://127.0.0.1:9090/api/toggle_service">
<!-- If opened from a malicious site → executes! -->
```

**Solution in the project**: **CSRF-GET Protection** — all state
endpoints → POST only.

**v1.0.0 — NEW-1**: Login POST-only.

---

### 🚨 XSS — Cross-Site Scripting

**Attack that injects malicious JavaScript** into a web page.

**Solution**:
- `escapeHtml()` on all outputs.
- Strict CSP.
- `textContent` instead of `innerHTML`.

---

### 🌍 CORS — Cross-Origin Resource Sharing

**HTTP header** that allows or blocks access from different domains.

**In the project**: `Same-Origin` only (no actual CORS).

---

### 🔒 COOP — Cross-Origin-Opener-Policy

**Header that protects against side-channel attacks** (like Spectre).

**Value**: `same-origin` (no sharing with other windows).

---

### 🔒 CORP — Cross-Origin-Resource-Policy

**Header that prevents external pages** from loading project resources.

**Value**: `same-origin`.

---

### 🍪 SameSite — SameSite Cookie Attribute

**Cookie value** that determines when it is sent across cross-site
requests.

| Value | Top-level GET | Cross-site POST | Note |
|---|:---:|:---:|---|
| `None` | ✅ | ✅ | Dangerous |
| `Lax` ✅ | ✅ | ❌ | Balanced |
| `Strict` | ❌ | ❌ | Breaks PWA shortcuts |

**In the project**: `Lax` (balanced between security and PWA support).

---

### 🔒 HttpOnly

**Cookie attribute** that prevents JavaScript from reading it.

**Benefit**: Even if XSS exists, it cannot steal the session.

---

### 🎣 Clickjacking

**Attack that places the page in a transparent iframe** and tricks the
user into clicking.

**Solution**: `X-Frame-Options: DENY` (present in the project).

---

## 4. Android & Root Terms

### 🔓 Root

**Superuser privileges** (like `sudo` on Linux).

**Without it**: The module cannot modify iptables or system settings.

---

### 🎩 Magisk

**Most popular Android root tool** — systemless modification.

**Features**:
- Supports Systemless Modules.
- Hides root from apps (MagiskHide/DenyList).

**In the project**: Supported from 20.4+.

---

### 🐧 KernelSU

**Modern alternative to Magisk** that works in kernel space.

**Advantages**: Less detectable, faster.

**In the project**: Supported from 0.9.0+.

---

### 🔧 APatch

**Another alternative** combining KernelSU and kernel patching.

**In the project**: Supported (latest).

---

### 📦 Module

**ZIP package** installed via Magisk/KernelSU.

**Components**:
- `module.prop` — description and version.
- `customize.sh` — installation script.
- `service.sh` — runs at boot.
- Module files.

---

### 💿 ROM

**Modified operating system** (historically Read-Only Memory).

**Examples**: LineageOS, Pixel Experience, MIUI, OneUI.

---

### ⚙️ Kernel

**System kernel** — manages hardware and processes.

**Common Android versions**: 3.10, 4.4, 4.14, 5.4, 5.15.

**In the project**: Requires 3.10+.

---

### 🔢 API Level

**Android version number** (for programming).

| Android | API |
|---|:---:|
| 5.0 | 21 |
| 10 | 29 |
| 14 | 34 |
| 15 | 35 |

**In the project**: Minimum API 21 (Android 5.0).

---

### 🏗️ ABI / Architecture

**Processor architecture** — determines the appropriate binaries.

| ABI | Description |
|---|---|
| `arm64-v8a` | ARM 64-bit (modern) |
| `armeabi-v7a` | ARM 32-bit |
| `x86_64` | Intel 64-bit |
| `x86` | Intel 32-bit |

**In the project**: Supports all four.

---

## 5. Project-Specific Terms

### 📄 STATUS_FILE

**File that represents "User Intent"**.

**Values**:
- `ON` — User wants the service running.
- `OFF` — User stopped it manually.

**⚠️ Audit Fix A**: Written only by `startService()` /
`stopService()`.

**Path**: `proxy/run/dnscrypt.status`.

---

### 🎯 User Intent

**Architectural concept** — what the user actually wants (not the
actual system state).

**Difference**:
- **User intent**: `ON` (for example).
- **Actual state**: May be `OFF` (due to crash).

**Benefit**: Watchdog relies on intent for restart.

---

### 🐕 Watchdog

**Standalone process** that monitors WebUI and DNS Engine and restarts
them on failure.

**In the project**: `proxy/watchdog.sh` — runs with exponential
backoff.

**v1.0.0**: Separate DNS backoff + reset on STATUS_FILE change.

**v1.1.0**: Logs active profile + memory hint at startup.

---

### 🎯 Audit Correction

**Numbered security or architectural fix** (#1, #17, ...).

**In v1.0.0**:
- #17: Custom Chains.
- #18: STATUS_FILE semantics.
- #19: IPv6 rate limit.
- #20: Port Collision.
- #21: Section TOML.
- #22: Basic Auth Rate Limit Bypass.
- #23: Section header with comment.
- #24: Exact endpoint matching.
- #25: Dashboard JSON Conversion.
- #26: Preserve User Settings on Upgrade.
- #27: `fuser` PID parsing.
- #28: Login POST-only (CSRF).
- #29: `readConfPort` range check.
- #30: `/readyz` localhost-only.
- #31: `shellQuote` injection protection.
- #32: `rebuildMu` mutex (RACE-1).
- #33: `runtime_info` dynamic ports (PORT-2).

**v1.1.0 does NOT add audit corrections.** The registry remains at
#33. See §5 "MEM-1 / MEM-2 / MEM-3" for v1.1.0 runtime improvements.

---

### 🩹 Hotfix

**Quick fix** for an existing release — without adding features.

**Format**: `vX.Y.Z-hotfixN` (major.minor.patch-hotfixN).

**In v1.1.0 context**: A hotfix from `v1.1.0` would be `v1.1.1` (PATCH
release via `scripts/release-patch.sh`).

---

### ✅ Allowlist

**Whitelist** — domains excluded from blocking.

**Example**:
```text
googleadservices.com
s.youtube.com
*.whatsapp.net
```

---

### ❌ Denylist

**Blacklist** — domains with additional blocking.

**Example**:
```text
facebook.com
tiktok.com
```

---

### 📁 Profile

**Profile file** that determines the protection level (Blocklist).

**5 levels**:
- `light` — ~40K entries, 80 MB soft limit (v1.1.0).
- `normal` — ~120K, 100 MB soft limit (v1.1.0).
- `pro` — ~250K (recommended), 120 MB soft limit (v1.1.0).
- `proplus` — ~350K, 160 MB soft limit (v1.1.0).
- `ultimate` — ~500K, 220 MB soft limit (v1.1.0).

---

### 🔐 Credentials

**Login credentials** (username + password) for WebUI/Dashboard.

**Automatically generated** in `customize.sh` during installation.

**Saved in**: `[monitoring_ui]` in `dnscrypt-proxy.toml`.

**v1.0.0 — Fix NEW-6**: Auth cache 60s.

---

### 🚪 Port Guard

**Security measure** that rejects port 8080 assignment.

**Reason**: Port 8080 is reserved for `[monitoring_ui]` in
`dnscrypt-proxy.toml`.

**Applied in**: 7 files (main.go + 6 shell scripts).

**⚠️ Audit #20.**

---

### 🆔 RACE-1 (v1.0.0)

**Critical fix** that prevents race conditions in `rebuildBlocklist`.

**Problem**:
- `updateProfile` (in goroutine) + `atomicSaveRulesInternal` (HTTP
  handler)
- → BLOCKLIST inconsistent.

**Solution**: `rebuildMu sync.Mutex` (coarse-grained locking).

**⚠️ Audit Correction #32.**

---

### 🆔 PORT-2 (v1.0.0)

**Architectural fix** that makes WebUI/Dashboard links dynamic.

**Problem before**:
- `index.html`: `http://127.0.0.1:9091` (hardcoded).
- `dashboard.html`: `http://127.0.0.1:9090` (hardcoded).

**Solution**:
- `runtime_info` returns `webui_port` + `dashboard_port`.
- Frontend builds links dynamically.
- Uses `window.location.hostname` (supports LAN + IPv6).

**⚠️ Audit Correction #33.**

---

### 🏗️ rebuildBlocklist

**Go function** that rebuilds `blocklist.txt` from:
- `blocklist.raw` (source)
- `allowlist.txt` (exceptions)
- `denylist.txt` (additional blocking)

**Structure**: Streaming I/O (~2 MB peak).

**v1.0.0 — RACE-1**: Protected by `rebuildMu`.

---

### 🔢 `runtime_info` Ports

**New fields in `runtime_info`** (v1.0.0 — PORT-2).

**Structure**:
```json
{
  "webui_port": "9090",
  "dashboard_port": "9091"
}
```

**Benefits**:
- Dynamic links in `index.html` and `dashboard.html`.
- Support LAN (`window.location.hostname`).
- No need to rebuild on port change.

**⚠️ v1.0.0 — PORT-2.**

---

### 💾 Setting Preservation (Fix #3)

**Architectural concept** — preserve user settings during upgrade.

**Before v1.0.0**: `unzip -o` extracted defaults over custom → settings
lost.

**After v1.0.0**:
1. **Backup** before extraction (`[8b]`).
2. **Restore** after extraction (`[9c]`).

**Preserved files (5)**:
- `webui.conf`, `dnscrypt-proxy.toml`, `selected_profile.txt`,
  `allowlist.txt`, `denylist.txt`.

**⚠️ v1.0.0 — Fix #3.**

---

### 📊 Single Source of Truth

**Architectural concept** — one source of truth.

**In the project**:
- `VERSION` — module version (v1.1.0).
- `proxy/dnscrypt-proxy.version` — DNS version (2.1.18).

**⚠️ Level 4.**

---

### 🏢 Level 4 (Enterprise)

**Enterprise-level infrastructure** for managing DNS binaries.

**Components**:
- `proxy/dnscrypt-proxy.version` (Single Source of Truth).
- `scripts/fetch_dns_binaries.sh` (5 fallback sources).
- SHA256 verification.
- Local cache + CI cache.
- Retry logic (3 attempts + exponential backoff).

**Benefits**:
- ✅ Retry logic for transient failures.
- ✅ Cache hit rate ~95%.
- ✅ 99.9% reliability.

**⚠️ Level 4 — Consolidated in v1.0.0.**

---

### 📋 NEW-1..NEW-6 (v1.0.0)

**6 additional security fixes** in v1.0.0:

| # | Fix | Impact |
|:-:|---|---|
| **NEW-1** | Login POST-only (CSRF) | 405 for non-POST |
| **NEW-2** | `hasEndpoint` instead of `HasSuffix` | Exact matching |
| **NEW-3** | `readConfPort` range check | Rejects 0, 99999, ... |
| **NEW-4** | `/readyz` localhost-only | 403 for LAN requests |
| **NEW-5** | `shellQuote()` | Shell injection protection |
| **NEW-6** | Auth cache (60s) | Reduce file I/O |

**Audit Corrections**: #28, (merged with #24), #29, #30, #31,
(Performance).

---

### 🆕 MEM-1 — Dynamic Memory Limit (v1.1.0)

**Runtime improvement** (not an audit correction) that replaces the
hardcoded `debug.SetMemoryLimit(80 MB)` with a per-profile limit.

**Values**:

| Profile | Soft limit |
|---|---:|
| light | 80 MB |
| normal | 100 MB |
| pro | 120 MB |
| proplus | 160 MB |
| ultimate | 220 MB |

**Applied by**: `applyMemoryLimit(key)` called from `main()` (at
startup) and `updateProfile()` (on profile change).

**Rationale**: On the `ultimate` profile, actual usage approaches
200 MB. With an 80 MB soft limit, the Go runtime runs GC
continuously → "GC thrashing" → slow/unresponsive WebUI on low-RAM
devices.

**Exposed via**: `runtime_info.memory_limit_mb`.

**Reference**: `docs/SECURITY.md` §5.30.1; `docs/ARCHITECTURE.md`
§3.9.

---

### 🆕 MEM-2 — Extended `shellQuote` Charset (v1.1.0)

**Runtime improvement** that extends `shellQuote()` from 20 to 24
shell-significant characters.

**Added characters**: `{`, `}`, `\n`, `\t`.

**Rationale**: `{`/`}` could brace-expand; `\n`/`\t` could word-split
when embedded in a shell command. **No known exploit existed** — this
is defense-in-depth.

**Reference**: `docs/SECURITY.md` §5.30.2.

---

### 🆕 MEM-3 — `MONITORING_UI_PORT` in Metrics Handler (v1.1.0)

**Runtime improvement** that removes the last hardcoded `"8080"`
string from `metricsProxyHandler`.

**Before**:
```go
"http://127.0.0.1:8080/api/metrics"
```

**After**:
```go
"http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"
```

**Rationale**: Single source of truth for the reserved port.

**Reference**: `docs/SECURITY.md` §5.30.3.

---

### 🆕 `profile_key` (v1.1.0)

**New field in `runtime_info`** that identifies the active blocklist
profile.

**Values**: `light` / `normal` / `pro` / `proplus` / `ultimate`.

**Source**: `main.go` reads `proxy/selected_profile.txt` at startup
via `readSelectedProfile()`. Falls back to `"pro"` for unknown values.

**Purpose**: Observability + System Info panel display.

---

### 🆕 `memory_limit_mb` (v1.1.0)

**New field in `runtime_info`** that reports the effective Go soft
memory limit for the active profile.

**Type**: int (MB).

**Values**: `80` / `100` / `120` / `160` / `220`.

**Purpose**: Observability + System Info panel display + API
verification.

---

### 🆕 Soft Limit (v1.1.0)

**Go runtime concept** — `debug.SetMemoryLimit` is a **soft** limit.

**Behavior**:
- The Go runtime does **not** kill the process when the limit is
  reached.
- It runs garbage collection (GC) more aggressively instead.
- Setting it **too low** → GC overhead → CPU waste → WebUI appears
  slow.
- Setting it **too high** → RAM waste.

**Why per-profile values?** Different blocklist profiles have
different working-set sizes. A single value either wastes memory on
light profiles or starves the heavy ones.

**Reference**: `docs/COMPATIBILITY.md` §5.4.1.

---

### 🆕 DNS Version vs Module Version (v1.1.0)

**Two independent versions** coexist in the project:

| Version | Source file | v1.1.0 value |
|---|---|:---:|
| **DNS version** (upstream) | `proxy/dnscrypt-proxy.version` | `2.1.18` |
| **Module version** (this project) | `VERSION` | `v1.1.0` |

- The **DNS version** changes only when upstream ships a new
  `dnscrypt-proxy` release.
- The **module version** changes with each project release.
- The two are **independent**. v1.1.0 did **not** bump the DNS version.

**Common confusion**: Both are called "version" in the codebase.

**Reference**: `docs/DNS_BINARIES.md` §1.1.

---

## 6. Go & Shell Terms

### 🔒 Mutex — Mutual Exclusion

**Locking mechanism** that prevents two operations from accessing the
same data at the same time.

**In the project**:
```go
var sessionsMu sync.RWMutex

sessionsMu.Lock()
defer sessionsMu.Unlock()
```

**Benefit**: Prevent Race Conditions.

---

### 🔒 `sync.Mutex` (v1.0.0)

**Default lock in Go** — provides Lock/Unlock.

**In the project — RACE-1**:
```go
var rebuildMu sync.Mutex

func rebuildBlocklist() error {
    rebuildMu.Lock()
    defer rebuildMu.Unlock()
    // ...
}
```

**Constraint**: Does not distinguish between read and write (use
`sync.RWMutex` for reads).

---

### 🔒 `sync.RWMutex`

**Lock that allows multiple concurrent reads** (but one write).

**In the project**:
- `sessionsMu sync.RWMutex`
- `authCacheMu sync.RWMutex`

**Benefit**: Higher performance with many reads.

---

### 🔒 `sync.Once`

**Go primitive** that runs a function **only once** no matter how many
times it is called.

**In the project**:
```go
var systemShellOnce sync.Once

func getSystemShell() string {
    systemShellOnce.Do(func() {
        // ... runs once
    })
    return systemShellPath
}
```

**Benefit**: No overhead after the first call.

**v1.0.0 — Fix #2.**

---

### 🔒 `memLimitMu` (v1.1.0)

**`sync.Mutex` in `main.go`** that protects the memory-limit state.

**Protected fields**:
- `currentMemLimit int64`
- `currentProfile string`

**Structure**:
```go
var memLimitMu sync.Mutex

func applyMemoryLimit(key string) {
    memLimitMu.Lock()
    defer memLimitMu.Unlock()
    // ...
}
```

**Rule**: `currentMemLimit` and `currentProfile` are read/written
**only** while holding `memLimitMu`.

**Reference**: `docs/ARCHITECTURE.md` §4.9.1.

---

### 🏃 Goroutine

**Lightweight thread** in Go — managed by the runtime.

**Advantage**: Thousands of goroutines with small memory cost.

**In the project**: SSE handler, updateProfile, etc.

---

### 📝 Atomic Write

**Atomic write** — either fully succeeds or fully fails.

**Method**:
1. Write to a temp file `.tmp`.
2. `fsync()` to ensure disk write.
3. `rename()` atomic (POSIX guarantees this).

**In the project**: `atomicWriteFile` / `atomicWriteStream`.

---

### 🐚 Shell Script

**Script for the Unix shell** (`/system/bin/sh` on Android).

**In the project**: All `proxy/*.sh` files.

**⚠️ Note**: Uses POSIX sh (not bash).

---

### 📌 shebang

**First line in a script** that determines the interpreter.

**In the project**:
```bash
#!/system/bin/sh
```

**Difference from `#!/bin/bash`**: POSIX (compatible with BusyBox).

---

### 🎯 `getSystemShell()`

**Go function** that determines the appropriate shell path for the
platform.

**Logic**:
1. `/system/bin/sh` (Android).
2. `/bin/sh` (Linux/macOS).
3. `/usr/bin/sh`.
4. Fallback: `"sh"` (PATH lookup).

**Cached in**: `sync.Once` (no overhead).

**Benefits**:
- ✅ CI works on Linux.
- ✅ Works on macOS.
- ✅ Works on Android.

**⚠️ v1.0.0 — Fix #2.**

---

### 🎯 `shellQuote()`

**Go function** that wraps a path with safe quotes.

**Structure (v1.1.0 — extended)**:
```go
func shellQuote(s string) string {
    for _, r := range s {
        if r == ' ' || r == '"' || ... ||
           r == '{' || r == '}' || r == '\n' || r == '\t' {
            return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
        }
    }
    return s
}
```

**Usage**:
```go
cmd := fmt.Sprintf(". %s/functions.sh; ...", shellQuote(MODDIR), port)
```

**Benefits**:
- ✅ Prevents shell injection.
- ✅ Supports spaces in `MODDIR`.
- ✅ **(v1.1.0)** Handles brace expansion + word-splitting.

**⚠️ v1.0.0 — NEW-5** + **v1.1.0 — MEM-2**.

---

### 🎯 `readConfPort()`

**Go function** that reads a port from `webui.conf` with range check.

**Structure**:
```go
func readConfPort(key, defaultPort string) string {
    val := readConfValue(key, defaultPort)
    n, err := strconv.Atoi(val)
    if err != nil || n < 1 || n > 65535 {
        return defaultPort  // fallback
    }
    return val
}
```

**Benefits**:
- ✅ Rejects `PORT=0`.
- ✅ Rejects `PORT=99999`.
- ✅ Rejects `PORT=-1`.
- ✅ Safe fallback.

**⚠️ v1.0.0 — NEW-3.**

---

### 🔍 `hasEndpoint()`

**Go function** that applies **exact path matching**.

**Implementation**:
```go
func hasEndpoint(path, name string) bool {
    return path == "/api/"+name || path == "/api/"+name+"/"
}
```

**Comparison**:

| Path | `strings.Contains` | `hasEndpoint` |
|--------|:---:|:---:|
| `/api/save_allowlist` | ✅ | ✅ |
| `/api/save_allowlist_extra` | ✅ (**bug**) | ❌ |
| `/prefix/api/save_allowlist` | ✅ (**bug**) | ❌ |

**⚠️ v1.0.0 — Fix #12 + NEW-2.**

---

### 🎯 `debug.SetMemoryLimit` (v1.1.0 — MEM-1)

**Go standard library function** (from `runtime/debug`) that sets a
**soft** memory limit for the Go runtime.

**Semantics**:
- Not a hard cap — the runtime does **not** OOM on breach.
- Prefers running GC more aggressively as the limit is approached.
- Introduced in Go 1.19 (available in the project's Go 1.22 toolchain).

**Usage in the project**:
```go
debug.SetMemoryLimit(220 * 1024 * 1024)  // 220 MB (ultimate)
```

**Rule**: Called only from `applyMemoryLimit(key)`.

**Reference**: `docs/SECURITY.md` §5.30.1.

---

## 7. CI/CD & Release Terms

### 🔄 CI — Continuous Integration

**Continuous integration** — every push/PR runs automated checks.

**In the project**: `.github/workflows/ci.yml`.

---

### 🚀 CD — Continuous Deployment

**Continuous deployment** — automatic release when changes are merged.

**In the project**: `.github/workflows/release.yml` (on tag push).

---

### 📦 SemVer — Semantic Versioning

**Semantic versioning** — `v<MAJOR>.<MINOR>.<PATCH>`.

- **MAJOR**: Breaking change.
- **MINOR**: New feature (compatible).
- **PATCH**: Bug fix.

**Example**: `v1.1.0`.

---

### 📊 versionCode

**Increasing integer** used in Magisk/Android.

**Formula**: `MAJOR*1M + MINOR*10K + PATCH*100 + HOTFIX`.

**Examples**:

| Version | versionCode |
|---|:---:|
| v1.0.0 | 1000000 |
| v1.0.1 | 1000001 |
| v1.1.0 | 1010000 |
| v1.1.1 | 1010001 |
| v1.2.0 | 1020000 |
| v2.0.0 | 2000000 |

**⚠️ Constraint**: `hotfix` ≤ 99.

---

### 🔐 SBOM — Software Bill of Materials

**List of software components** — generated at release.

**Formats**:
- SPDX (Linux Foundation).
- CycloneDX (OWASP).

**In the project**: `sbom.spdx.json` + `sbom.cdx.json`.

---

### ✍️ Cosign

**Signing tool** from Sigstore — signs binaries without keys
(keyless).

**In the project**: Signs every file in the Release.

**Verification**:
```bash
cosign verify-blob --signature X.sig --certificate X.pem X
```

---

### 🏗️ SOURCE_DATE_EPOCH

**Environment variable** for reproducible builds.

**Benefit**: Same commit → same SHA256 of binary.

**In the project**: Extracted from `git log -1 --format=%ct`.

---

### 🔄 Conventional Commits

**Standard for commit messages** — `type(scope): subject`.

**Types**: feat, fix, docs, security, perf, refactor, test, chore,
release.

**Example**:
```bash
security(iptables): implement Custom Chains to prevent orphan rules
```

---

## 8. Metrics & Abstraction Terms

### 📊 Prometheus

**Monitoring system + time-series database** — open source.

**Source**: [prometheus.io](https://prometheus.io/)

**In the project**: `dnscrypt-proxy` uses Prometheus format for
`monitoring_ui` metrics.

**Port**: `8080` (monitoring_ui).

---

### 📄 Prometheus Text Format

**Text format** for exposing metrics in Prometheus.

**Format**:
```text
# HELP dnscrypt_proxy_query_total Total queries
# TYPE dnscrypt_proxy_query_total counter
dnscrypt_proxy_query_total 15234
dnscrypt_proxy_blocked_query_total 1523
dnscrypt_proxy_cache_hits_total{type="positive"} 12500
```

**Components**:
- `# HELP` — description.
- `# TYPE` — type (counter, gauge, histogram).
- `name value` — value.
- `name{label="v"} value` — with labels.

**⚠️ v1.0.0**: Converted to JSON in `main.go`.

---

### 🔄 `parsePrometheus()`

**Function in `main.go`** that parses Prometheus text format into
`map[string]float64`.

**Behavior**:
- Ignores comments (`#`) and empty lines.
- Extracts metric name (without labels).
- Sums multiple values for the same name (labels).

**Example**:
```go
func parsePrometheus(text string) map[string]float64 {
    result := make(map[string]float64)
    for _, line := range strings.Split(text, "\n") {
        // ...
        result[name] += val
    }
    return result
}
```

**⚠️ v1.0.0 — Fix #1.**

---

### 🔄 `buildDashboardJSON()`

**Function in `main.go`** that converts `map[string]float64` into JSON
schema expected by `dashboard.html`.

**Fields**:
- `total_queries` — from `dnscrypt_proxy_query_total`.
- `blocked_queries` — from `dnscrypt_proxy_blocked_query_total`.
- `cache_stats.cache_hits` — from `dnscrypt_proxy_cache_hits_total`.
- `cache_stats.cache_misses` — from `dnscrypt_proxy_cache_misses_total`.
- `cache_stats.cache_hit_ratio` — computed.

**⚠️ v1.0.0 — Fix #1.**

---

### 🔍 `findMetric()`

**Helper function** that searches for the first key matching any of
the patterns.

**Usage**:
```go
findMetric(prom, "dnscrypt_proxy_query_total", "dnscrypt_query_total")
```

**Benefit**: Support for **multiple metric names** across
dnscrypt-proxy versions.

**⚠️ v1.0.0 — Fix #1.**

---

### 🎭 Adapter Pattern

**Design pattern** that converts an interface to another expected by
the client.

**In the project**:
- **Client** → `dashboard.html` (expects JSON).
- **Adapter** → `metricsProxyHandler` (converts).
- **Adaptee** → `monitoring_ui` (Prometheus text).

**Diagram**:
```text
Client → Adapter → Adaptee
JSON ← metricsProxyHandler ← Prometheus text
```

**Benefit**: No modification to `dnscrypt-proxy` (upstream) —
conversion in `main.go`.

**⚠️ v1.0.0 — §16 (Metrics Abstraction).**

---

### 🏗️ Label Aggregation

**Summing multiple Prometheus values for the same metric**.

**Example**:
```text
dnscrypt_proxy_cache_hits_total{type="positive"} 100
dnscrypt_proxy_cache_hits_total{type="negative"} 50
```

**Result in JSON**:
```json
"cache_hits": 150
```

**⚠️ v1.0.0**: In `parsePrometheus` via `result[name] += val`.

---

### 🔢 `portCacheMap`

**Map in `main.go`** that stores the state of each port independently.

**Structure**:
```go
type portCacheEntry struct {
    open bool
    time time.Time
}

var portCacheMap = make(map[int]portCacheEntry)
```

**Benefit**: **Independent cache per port** (instead of a single
variable).

**⚠️ v1.0.0 — Fix #7.**

---

### 🌍 Platform-Agnostic Shell

**Architectural concept** — code works on any platform (Android,
Linux, macOS).

**Applied in v1.0.0**:
- `getSystemShell()` instead of `/system/bin/sh`.
- Fallback to alternative paths.
- `sync.Once` for cache.

**Benefit**: CI works on Linux, development on macOS, production on
Android.

**⚠️ v1.0.0 — §15 (ARCHITECTURE.md).**

---

### 📊 Structured Metrics

**Architectural concept** — metrics as structured JSON, not raw text.

**Before v1.0.0**: `metricsProxyHandler` returned Prometheus text.
**After v1.0.0**: Returns JSON schema.

**Benefit**:
- `JSON.parse()` works on the client.
- Dashboard functional.
- API usable from scripts.

**⚠️ v1.0.0 — §16 (ARCHITECTURE.md).**

**v1.1.0 note**: `metricsProxyHandler` builds the upstream URL from
the `MONITORING_UI_PORT` constant (MEM-3) instead of the hardcoded
string `"8080"`. Behavior is unchanged.

---

### 🎯 Per-Port Cache

**Architectural concept** — independent cache per port.

**Before v1.0.0**: Single variable `cachedPortStatus` → gives wrong
result when switching ports.

**After v1.0.0**: `portCacheMap` (map per port).

**Benefit**: Correct cache for each port (5354, 9090, 9091, etc.).

**⚠️ v1.0.0 — Fix #7.**

---

## 9. Advanced Security Terms

### 🔐 Login POST-Only (NEW-1)

**Security concept** — `/api/auth/login` accepts **POST only**.

**Before v1.0.0**: Accepted GET → CSRF vector + credential leak in
URL.

**After v1.0.0**:
```go
if hasEndpoint(r.URL.Path, "auth/login") {
    if r.Method != http.MethodPost {
        w.Header().Set("Allow", "POST")
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    handleLogin(w, r)
    return
}
```

**Benefits**:
- Prevents CSRF vector.
- Prevents credential leak in browser history + server logs.

**⚠️ v1.0.0 — NEW-1 (Audit #28).**

---

### 🎯 `/readyz` Localhost-Only (NEW-4)

**Security concept** — `/readyz` rejects requests from outside
localhost.

**Before v1.0.0**: Available for any request (even on LAN) →
reconnaissance.

**After v1.0.0**:
```go
func handleReadyz(w http.ResponseWriter, r *http.Request) {
    if !isLocalRequest(r) {
        w.WriteHeader(http.StatusForbidden)
        json.NewEncoder(w).Encode(map[string]string{
            "error": "readyz is localhost-only",
        })
        return
    }
    // ...
}
```

**Benefits**:
- Prevents system detail leak on LAN.
- `/healthz` remains public (standard, lightweight, no details).

**⚠️ v1.0.0 — NEW-4 (Audit #30).**

---

### 🛡️ `shellQuote()` (NEW-5 + MEM-2)

**Function in `main.go`** that wraps a path with safe quotes.

**⚠️ See §6 for full details.**

**⚠️ v1.0.0 — NEW-5 (Audit #31)** + **v1.1.0 — MEM-2**.

---

### 🔢 `readConfPort()` (NEW-3)

**Function in `main.go`** that verifies the port range `[1, 65535]`.

**⚠️ See §6 for full details.**

**⚠️ v1.0.0 — NEW-3 (Audit #29).**

---

### 📦 Auth Cache (NEW-6)

**Architectural concept** — cache credentials in memory for 60
seconds.

**Structure**:
```go
const AUTH_CACHE_TTL = 60 * time.Second

var (
    authCacheMu   sync.RWMutex
    authCacheUser string
    authCachePass string
    authCacheTime time.Time
)
```

**Before v1.0.0**:
- Every HTTP request reads the full `dnscrypt-proxy.toml` → ~5-10 ms
  per request.

**After v1.0.0**:
- Cache hit → ~0.05 ms per request.

**Benefits**:
- Less I/O on Android.
- Less battery.
- Faster response.

**⚠️ v1.0.0 — NEW-6.**

---

### 🔍 Exact Endpoint Matching (Fix #12)

**Architectural concept** — match path exactly, not with
`strings.Contains`.

**Before v1.0.0**: `strings.Contains` matches
`/api/update_profile_evil`.

**After v1.0.0**: `hasEndpoint` rejects any non-matching path.

**Benefits**:
- Smaller attack surface.
- Clearer error messages.
- 404 for unknown action.

**⚠️ v1.0.0 — Fix #12 (Audit #24).**

---

### 🛡️ Basic Auth Rate Limiting (Fix #8)

**Protection** against brute force via Basic Auth.

**Before v1.0.0**: `checkAuth` did not record failed attempts →
unlimited brute force on LAN.

**After v1.0.0**:
```go
user, pass, ok := r.BasicAuth()
if ok {
    ip := getClientIP(r)

    if isLockedOut(ip) {
        return false
    }

    if userMatch && passMatch {
        recordLoginAttempt(ip, true)
        return true
    }
    recordLoginAttempt(ip, false)  // ← records failure
}
```

**Benefits**:
- 5 attempts / 15 minutes.
- Lockout per IP.
- Success resets the counter.

**⚠️ v1.0.0 — Fix #8 (Audit #22).**

---

### 🆕 Offline Page CSP Removal (v1.1.0)

**Critical fix** in `web/offline.html`.

**Before v1.1.0**: The page had a restrictive CSP meta:
```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none'; ...">
```

**Problem**: `default-src 'none'` implicitly forbids `script-src`,
which **silently blocked** the page's own inline `<script>`. The page
rendered correctly but every interactive feature (Retry, Diagnose,
language toggle, auto-retry) silently failed.

**After v1.1.0**: CSP meta removed entirely.

**Rationale**: The page has no user data, no forms, no network calls
after load, and uses only `textContent`. There is nothing to protect
with CSP. If a future version adds dynamic content from untrusted
sources, CSP must be reintroduced — preferably with a nonce rather
than `'unsafe-inline'`.

**⚠️ v1.1.0 — Critical Fix (not an audit correction; it was a
functional regression, not an exploitable vulnerability).**

---

## 10. Common Abbreviations

| Abbreviation | Meaning | Full Form |
|:---:|---|---|
| **ABI** | Application Binary Interface | Application Binary Interface |
| **ACL** | Access Control List | Access Control List |
| **API** | Application Programming Interface | Application Programming Interface |
| **CI/CD** | Continuous Integration / Deployment | Continuous Integration / Deployment |
| **CORS** | Cross-Origin Resource Sharing | Cross-Origin Resource Sharing |
| **COOP** | Cross-Origin-Opener-Policy | Cross-Origin-Opener-Policy |
| **CORP** | Cross-Origin-Resource-Policy | Cross-Origin-Resource-Policy |
| **CSP** | Content-Security-Policy | Content-Security-Policy |
| **CSRF** | Cross-Site Request Forgery | Cross-Site Request Forgery |
| **CRLF** | Carriage Return + Line Feed | Carriage Return + Line Feed |
| **DNAT** | Destination Network Address Translation | Destination Network Address Translation |
| **DNS** | Domain Name System | Domain Name System |
| **DoH** | DNS over HTTPS | DNS over HTTPS |
| **DoS** | Denial of Service | Denial of Service |
| **DoT** | DNS over TLS | DNS over TLS |
| **GC** | Garbage Collector / Collection | Garbage Collector / Collection |
| **HTTP** | Hypertext Transfer Protocol | Hypertext Transfer Protocol |
| **HTTPS** | HTTP Secure | HTTP Secure |
| **IP** | Internet Protocol | Internet Protocol |
| **JSON** | JavaScript Object Notation | JavaScript Object Notation |
| **JWT** | JSON Web Token | JSON Web Token |
| **LMK** | Low Memory Killer | Low Memory Killer (Android) |
| **NAT** | Network Address Translation | Network Address Translation |
| **OOM** | Out Of Memory | Out Of Memory |
| **PEM** | Privacy Enhanced Mail | Privacy Enhanced Mail |
| **PWA** | Progressive Web App | Progressive Web App |
| **RBAC** | Role-Based Access Control | Role-Based Access Control |
| **RSS** | Resident Set Size | Resident Set Size |
| **SAST** | Static Application Security Testing | Static Application Security Testing |
| **SBOM** | Software Bill of Materials | Software Bill of Materials |
| **SemVer** | Semantic Versioning | Semantic Versioning |
| **SSE** | Server-Sent Events | Server-Sent Events |
| **SSRF** | Server-Side Request Forgery | Server-Side Request Forgery |
| **SW** | Service Worker | Service Worker |
| **TLS** | Transport Layer Security | Transport Layer Security |
| **TOML** | Tom's Obvious Minimal Language | Tom's Obvious Minimal Language |
| **TTL** | Time To Live | Time To Live |
| **UDP** | User Datagram Protocol | User Datagram Protocol |
| **UI** | User Interface | User Interface |
| **XHR** | XMLHttpRequest | XMLHttpRequest |
| **XSS** | Cross-Site Scripting | Cross-Site Scripting |
| **YAML** | YAML Ain't Markup Language | YAML Ain't Markup Language |

**v1.0.0 Abbreviations**:

| Abbreviation | Meaning | Full Form |
|:---:|---|---|
| **Adapter** | Adapter | Adapter Pattern |
| **Backoff** | Exponential Backoff | Exponential Backoff |
| **Metrics** | Metrics / Prometheus | Metrics / Prometheus |
| **Payload** | HTTP Payload | HTTP Payload |
| **RACE** | Race Condition | Race Condition |
| **RMW** | Read-Modify-Write | Read-Modify-Write |
| **TTL** | Time To Live | Time To Live |

**v1.1.0 Abbreviations**:

| Abbreviation | Meaning | Full Form |
|:---:|---|---|
| **MEM** | Memory improvement ID | Memory improvement (MEM-1/2/3) |
| **Soft limit** | Go runtime soft limit | `debug.SetMemoryLimit` |

---

## 11. Fixes Index

### 🔴 v1.0.0 — Critical Fixes (7)

| # | Fix | Reference |
|:-:|---|---|
| **#1** | Dashboard JSON conversion | `parsePrometheus` + `buildDashboardJSON` (§8) |
| **#2** | Shell fallback | `getSystemShell()` (§6) |
| **#3** | Preserve user settings | `Setting Preservation` (§5) |
| **#4** | `.gitignore` negation | (outside glossary scope) |
| **#5** | Pre-commit hooks | (outside glossary scope) |
| **#6** | Asset Serving | (outside glossary scope) |
| **#7** | CodeQL config drift | (outside glossary scope) |

### 🔴 v1.0.0 — Additional Security Fixes (NEW-1..NEW-6)

| # | Fix | Reference |
|:-:|---|---|
| **NEW-1** | Login POST-only | `Login POST-Only` (§9) |
| **NEW-2** | `hasEndpoint` usage | `hasEndpoint()` (§6) |
| **NEW-3** | `readConfPort` range check | `readConfPort()` (§6 + §9) |
| **NEW-4** | `/readyz` localhost-only | `/readyz Localhost-Only` (§9) |
| **NEW-5** | `shellQuote` injection protection | `shellQuote()` (§6 + §9) |
| **NEW-6** | Auth cache (60s) | `Auth Cache` (§5 + §9) |

### 🔴 v1.0.0 — Architectural Fixes (RACE-1 + PORT-2)

| # | Fix | Reference |
|:-:|---|---|
| **RACE-1** | `rebuildMu` mutex | `RACE-1` + `rebuildMu` (§2 + §5) |
| **PORT-2** | `runtime_info` dynamic ports | `PORT-2` + `runtime_info Ports` (§5) |

### 🟠 v1.0.0 — High Fixes

| # | Fix | Reference |
|:-:|---|---|
| **#8** | Basic Auth rate limiting | `Basic Auth Rate Limiting` (§9) |
| **#9** | `fuser` PID parsing | (outside glossary scope) |

### 🟡 v1.0.0 — Medium Fixes

| # | Fix | Reference |
|:-:|---|---|
| **#10** | Section header with comment | (outside glossary scope) |
| **#11** | Per-port cache | `portCacheMap` (§8) |
| **#12** | Exact endpoint matching | `Exact Endpoint Matching` (§9) |

### 🆕 v1.1.0 — Runtime Improvements (Not Audit Corrections)

| ID | Change | Reference |
|:-:|---|---|
| **MEM-1** | Dynamic memory limit per profile | `MEM-1` (§5) + `debug.SetMemoryLimit` (§6) |
| **MEM-2** | Extended `shellQuote` charset | `MEM-2` (§5) + `shellQuote()` (§6) |
| **MEM-3** | `MONITORING_UI_PORT` in metrics handler | `MEM-3` (§5) |

### 🆕 v1.1.0 — New Fields

| Field | Purpose | Reference |
|:-:|---|---|
| **`profile_key`** | Active profile identifier | `profile_key` (§5) |
| **`memory_limit_mb`** | Effective Go soft limit | `memory_limit_mb` (§5) |

### 🆕 v1.1.0 — Critical Fix (Not an Audit Correction)

| # | Fix | Reference |
|:-:|---|---|
| **offline.html** | Removed restrictive CSP meta | `Offline Page CSP Removal` (§9) |

### v1.0.0 — Audit Corrections Registry

The last audit correction is **#33** (v1.0.0). See
`docs/SECURITY.md` §17 for the full registry.

**Next expected**: #34 (v1.2.x).

---

## 12. References

### RFCs and Specifications

- [RFC 1035](https://www.rfc-editor.org/rfc/rfc1035) — DNS
- [RFC 8484](https://www.rfc-editor.org/rfc/rfc8484) — DoH
- [RFC 7858](https://www.rfc-editor.org/rfc/rfc7858) — DoT
- [RFC 7231](https://www.rfc-editor.org/rfc/rfc7231) — HTTP/1.1
- [RFC 7231 §6.5.5](https://datatracker.ietf.org/doc/html/rfc7231#section-6.5.5) — 405 Method Not Allowed
- [RFC 7231 §7.1.3](https://datatracker.ietf.org/doc/html/rfc7231#section-7.1.3) — Retry-After
- [RFC 6265bis](https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis) — Cookies

### Educational Sites

- [DNS Fundamentals](https://www.cloudflare.com/learning/dns/what-is-dns/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [MDN Web Docs](https://developer.mozilla.org/)
- [Netfilter Documentation](https://www.netfilter.org/documentation/)
- [Prometheus Text Format](https://prometheus.io/docs/instrumenting/exposition_formats/)
- [Exponential Backoff (AWS)](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)

### Internal Documentation

| Document | Purpose |
|---|---|
| [docs/ARCHITECTURE.md](ARCHITECTURE.md) | Full architecture |
| [docs/SECURITY.md](SECURITY.md) | Security + Audit Corrections |
| [docs/API.md](API.md) | HTTP API Reference |
| [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Troubleshooting |
| [docs/COMPATIBILITY.md](COMPATIBILITY.md) | Compatibility matrix |
| [docs/DNS_BINARIES.md](DNS_BINARIES.md) | DNS binaries management (Level 4) |
| [docs/DEVELOPMENT.md](DEVELOPMENT.md) | Developer guide |
| [docs/CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guide |
| [docs/INSTALL.md](INSTALL.md) | Installation guide |
| [docs/UPGRADE.md](UPGRADE.md) | Upgrade guide (v1.0.0 → v1.1.0) |
| [docs/FAQ.md](FAQ.md) | Frequently asked questions |
| [CHANGELOG.md](../CHANGELOG.md) | Version history |

---

## 13. Contributing

Found a missing term? Or an unclear definition?

- 🐛 **Open an Issue** titled `[Docs] Glossary: term X`.
- 🔧 **Submit a PR** directly to add it.
- 📖 Follow the existing formatting style.
- ✅ Make sure to add the appropriate section (1-12).

---

*Last updated: 2026-09-26*
*Version: v1.1.0*
*Author: gasciljh*

---

<div align="center">

**💡 Tip**: Bookmark this page as a quick reference!

[⬆ Back to top](#glossary--terms--abbreviations)

</div>