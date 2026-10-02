# Glossary — Terms & Abbreviations

> Comprehensive reference for all terms and abbreviations used
> in DNSCrypt Smart Filter.

**Version**: v1.3.0
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']` and is never transmitted to
>     the server. Documentation remains English-only by project
>     convention.
>   • §5 Project-Specific Terms gained **20+ new entries** for
>     the v1.2.0 data-preservation release:
>       - Persistent Backup (v1.2.0)
>       - Transactional Upgrade (v1.2.0)
>       - `txn-*` directory (v1.2.0)
>       - `orphan-txn-*` directory (v1.2.0)
>       - `.last_stable` pointer (v1.2.0)
>       - `.last_backup` marker (v1.2.0)
>       - `.upgrade_history.json` (v1.2.0)
>       - `.pending_notification` (v1.2.0)
>       - Multi-Source Detection (v1.2.0)
>       - Recovery Mode Trigger (v1.2.0)
>       - `runtime_info.backups` (v1.2.0)
>       - `backupMu` (v1.2.0)
>       - `createAutoBackup` (v1.2.0)
>       - `cleanupOldTransactions` (v1.2.0)
>       - `checkPendingNotifications` (v1.2.0)
>       - `copy_with_context` (v1.2.0)
>       - `write_manifest` (v1.2.0)
>       - `verify_backup_integrity` (v1.2.0)
>       - Data Guardian (v1.2.0)
>       - Root-Solution Detection (v1.2.0)
>   • §6 Go & Shell Terms gained **4 new entries**:
>       - `sync.Mutex` (`backupMu`)
>       - `runShellWithTimeout`
>       - `AUTO_BACKUP_TIMEOUT`
>       - `META-INF/update-binary`
>   • §8 Metrics & Abstraction Terms gained a v1.2.0 note
>     about the 7-field `runtime_info.backups` object.
>   • §9 Advanced Security Terms gained **4 new entries**:
>       - 7-field Backups Schema
>       - Recovery Mode Correctness Fix
>       - Service Worker Update-Banner Fix
>       - Language Toggle (client-side only)
>   • §10 Common Abbreviations gained **4 new entries**:
>     FBE, MTP, FUSE, OTA.
>   • §11 Fixes Index gained a new section for the v1.2.0
>     Data-Preservation additions (BAK-1 / BAK-2 / BAK-3 / BAK-4)
>     and correctness fixes (FIX-1 / FIX-2), **plus** a new
>     note on the `HARD-*` file-scoped identifier family
>     (see §11 "Note on HARD-* identifiers").
>   • The Audit Corrections Registry remains at #33 — v1.2.0
>     does not extend it (see `docs/SECURITY.md` §17).
>   • §12 References updated with v1.2.0 additions
>     (`BACKUP.md`, `EMERGENCY.md`, `UPGRADE.md`).

> **v1.2.0 (Global Edition) — Corrections in this revision**:
>   • 🔧 **FIX-1 description** — §5 "Recovery Mode Trigger" and
>     §9 "Recovery Mode Correctness Fix" previously described
>     FIX-1 as a "reorder + exclude" strategy. The actual
>     implementation in `customize.sh` uses a
>     **snapshot-and-reapply** strategy (`§[8a]` + `§[9]` +
>     `§[9b2]`), which keeps the extraction logic of `§[9]`
>     untouched. The descriptions have been corrected to match
>     the shipped code.
>   • 🔧 **Reason string** — §5 "`createAutoBackup`" previously
>     listed `pre-append-denylist` for the `appendDenylist` call
>     site. The actual reason string recorded by `main.go` is
>     `pre-denylist-save`, because `appendDenylist` delegates to
>     `saveDenylist` (which is where the pre-critical backup is
>     triggered). The entry has been corrected.

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

**⚠️ v1.2.0 note**: The DNS version (2.1.18) is **separate** from the
module version (v1.2.0). See §5 "DNS Version vs Module Version" for
the distinction.

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
**v1.2.0 — BAK-2**: `backupMu` serializes pre-critical backups.

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

**v1.2.0 note**: `manifest.json` `lang` defaults to `en` and `dir`
to `ltr`. The in-page toggle updates both at runtime.

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

**v1.2.0**: The SW caches the HTML **once**, language-neutral. The
`[dir="rtl"]` CSS rules are applied client-side. See §9
"Service Worker Update-Banner Fix".

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

**In the project**: Supported (latest). See §5
"Root-Solution Detection".

---

### 📦 Module

**ZIP package** installed via Magisk/KernelSU/APatch.

**Components**:
- `module.prop` — description and version.
- `customize.sh` — installation script.
- `service.sh` — runs at boot.
- Module files.

**Bootstrap**: `META-INF/com/google/android/update-binary` — the root
manager's entry point. See §6.

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

**v1.2.0**: Sends `X-Watchdog-Token` header to
`/api/ensure_running_service`. Reads the token from
`$RUN_DIR/.watchdog_token` on every call (no cache). Read-only with
respect to the backup directory.

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

**v1.2.0 does NOT add audit corrections either.** See §5 "BAK-1" ..
"BAK-4" and §5 "FIX-1 / FIX-2" for v1.2.0 runtime additions and
correctness fixes. The registry remains at #33.

---

### 🩹 Hotfix

**Quick fix** for an existing release — without adding features.

**Format**: `vX.Y.Z-hotfixN` (major.minor.patch-hotfixN).

**In v1.2.0 context**: A hotfix from `v1.2.0` would be `v1.2.1`
(PATCH release via `scripts/release-patch.sh`).

---

### ✅ Allowlist

**Whitelist** — domains excluded from blocking.

**Example**:
```text
googleadservices.com
s.youtube.com
*.whatsapp.net
```

**v1.2.0**: A pre-critical backup is created before each save (BAK-2).

---

### ❌ Denylist

**Blacklist** — domains with additional blocking.

**Example**:
```text
facebook.com
tiktok.com
```

**v1.2.0**: A pre-critical backup is created before each save (BAK-2).

---

### 📁 Profile

**Profile file** that determines the protection level (Blocklist).

**5 levels**:
- `light` — ~40K entries, 80 MB soft limit (v1.1.0).
- `normal` — ~120K, 100 MB soft limit (v1.1.0).
- `pro` — ~250K (recommended), 120 MB soft limit (v1.1.0).
- `proplus` — ~350K, 160 MB soft limit (v1.1.0).
- `ultimate` — ~500K, 220 MB soft limit (v1.1.0).

**v1.2.0**: The profile choice is preserved by the 10 defensive
layers (it lives in `selected_profile.txt`, one of the 5 preserved
files). See §5 "Setting Preservation" and "Persistent Backup".

---

### 🔐 Credentials

**Login credentials** (username + password) for WebUI/Dashboard.

**Automatically generated** in `customize.sh` during installation.

**Saved in**: `[monitoring_ui]` in `dnscrypt-proxy.toml`.

**v1.0.0 — Fix NEW-6**: Auth cache 60s.

**v1.2.0**: Also present in the persistent backup at
`/sdcard/dnscrypt-webui-backup/current/dnscrypt-proxy.toml`.

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

**v1.2.0**: Called by the delegated `saveDenylist` path after a
pre-critical backup. The `appendDenylist` endpoint now requires a
`content` parameter (BUG-A fix) and returns `"Processed N rules"` or
`"No changes detected"`.

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

**v1.1.0**: Also returns `profile_key` and `memory_limit_mb`.
**v1.2.0**: Also returns `backups` (7 fields). See §5
"`runtime_info.backups`".

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

**v1.2.0 supersedes**: The v1.0.0 mechanism (`BACKUP_TMP` in
`/data/local/tmp/`) is **superseded** by the v1.2.0 10-layer
architecture. See §5 "Persistent Backup" and "Multi-Source Detection".

---

### 📊 Single Source of Truth

**Architectural concept** — one source of truth.

**In the project**:
- `VERSION` — module version (v1.2.0).
- `proxy/dnscrypt-proxy.version` — DNS version (2.1.18).
- `MONITORING_UI_PORT` — reserved port (8080).

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

| Version | Source file | v1.2.0 value |
|---|---|:---:|
| **DNS version** (upstream) | `proxy/dnscrypt-proxy.version` | `2.1.18` |
| **Module version** (this project) | `VERSION` | `v1.2.0` |

- The **DNS version** changes only when upstream ships a new
  `dnscrypt-proxy` release.
- The **module version** changes with each project release.
- The two are **independent**. v1.2.0 did **not** bump the DNS version.

**Common confusion**: Both are called "version" in the codebase.

**Reference**: `docs/DNS_BINARIES.md` §1.1.

---

### 🆕 Persistent Backup (v1.2.0)

**Layer 2** of the 10 defensive layers. All 5 user config files are
snapshotted to `/sdcard/dnscrypt-webui-backup/`.

**Why this location**:
- ✅ Survives reboot.
- ✅ Survives module uninstall.
- ✅ Survives factory reset of `/data`.
- ✅ Visible from any file manager + over USB (MTP).

**Rotation**: Keep the 21 newest snapshots, sorted by directory name.

**Reference**: `docs/BACKUP.md` §1.3, §3.

---

### 🆕 Transactional Upgrade (v1.2.0)

**Layer 4** of the 10 defensive layers. Every install runs inside a
`txn-*` directory.

**State machine**:
- `START` — install in progress or interrupted.
- `COMMIT` — install succeeded, cleanup skipped.
- `ROLLBACK` — rollback applied.

**Behavior**:
- On failure, an automatic rollback restores the previous state.
- Leftover `COMMIT`'d transactions are cleaned by
  `cleanupOldTransactions()` at startup.
- `START` transactions are preserved as `orphan-txn-*` on uninstall.

**Reference**: `docs/ARCHITECTURE.md` §3.10; `docs/BACKUP.md` §5.

---

### 🆕 `txn-*` directory (v1.2.0)

**In-flight transaction directory** created by `customize.sh` during
every install.

**Format**: `txn-<timestamp>-<pid>/`.

**Contents**:
- `.state` — `START` | `COMMIT` | `ROLLBACK`.
- `.pid` — installer PID (optional).
- Copied user files (for rollback).

**Lifetime**: Short-lived (removed after commit or rollback).

**Reference**: `docs/BACKUP.md` §3.2, §11.6.

---

### 🆕 `orphan-txn-*` directory (v1.2.0)

**Preserved interrupted transaction**.

**Created by**: `uninstall.sh` renaming a `txn-*` with
`.state=START`.

**Meaning**: A previous install was interrupted mid-flight. The
directory may contain the **only copy** of the user's data.

**Action**: **Preserve** — inspect manually before deleting.

**Reference**: `docs/BACKUP.md` §10.5; `docs/EMERGENCY.md` §4.5.

---

### 🆕 `.last_stable` pointer (v1.2.0)

**File containing the directory name** (not path) of the last
known-good snapshot.

**Content**: e.g. `20260926-095826-v1.2.0-12345`.

**Updated when**: A snapshot is created by `customize.sh` and
verification passes.

**Read by**:
- `customize.sh` §[8a] (recovery mode).
- `main.go:buildBackupInfo()` (as `runtime_info.backups.last_stable`).
- `status.sh --json`.
- `status.sh --diagnose`.

**Note**: This file is **not** updated by runtime backups
(`main.go`, `service.sh`, `action.sh`). Only install-time
snapshots update `.last_stable`.

**Reference**: `docs/BACKUP.md` §5.2.

---

### 🆕 `.last_backup` marker (v1.2.0)

**Empty marker file** whose **mtime** is used as the "last
auto-backup timestamp".

**Actually named**: `.last_auto_backup`.

**Created/updated by**: `functions.sh:auto_backup_if_needed`.

**Read by**:
```sh
stat -c %Y "$PERSISTENT_BACKUP/.last_auto_backup" \
  || stat -f %m "$PERSISTENT_BACKUP/.last_auto_backup" \
  || echo 0
```

If the marker is missing, the age is treated as 0 → backup runs
immediately.

**Reference**: `docs/BACKUP.md` §5.3.

---

### 🆕 `.upgrade_history.json` (v1.2.0)

**Append-only JSON log** recording every install / upgrade.

**Structure**:
```json
{
  "upgrades": [
    {
      "from": "v1.1.0",
      "to": "v1.2.0",
      "date": "2026-09-29T10:30:00Z",
      "source": "/data/adb/modules/dnscrypt-proxy-webui/proxy",
      "root": "magisk",
      "files": 5
    }
  ]
}
```

**Written by**: `customize.sh:log_upgrade()` when `jq` is available.

**Fallback** (no `jq`): plain-text `.upgrade_history.txt`.

**Not rotated** — grows slowly (~200 bytes per upgrade).

**Reference**: `docs/BACKUP.md` §5.4.

---

### 🆕 `.pending_notification` (v1.2.0)

**Transient single-line file** written by `customize.sh` after a
successful restore during an upgrade.

**Read by**: `main.go:checkPendingNotifications()` at startup.

**Action**: Content is logged, then the file is deleted by
`main.go` (only).

**Typical content**:
```text
Restored 5 user files from backup
```

**Reference**: `docs/BACKUP.md` §5.5; `docs/ARCHITECTURE.md`
§4.10.4.

---

### 🆕 Multi-Source Detection (v1.2.0)

**Layer 1** of the 10 defensive layers.

**Philosophy**: *"Search for user data everywhere — do not guess
whether this is an upgrade."*

**Candidates (7)**:
1. `$MODPATH/proxy` (in-place)
2. `/data/adb/modules/dnscrypt-proxy-webui/proxy` (standard)
3. `/data/adb/modules/DNSCrypt-Proxy-Webui/proxy` (legacy)
4. `/data/adb/modules/DNSCrypt-Proxy-WebUI/proxy` (variant)
5. `$PERSISTENT_BACKUP/current` (persistent)
6. `$PERSISTENT_BACKUP` (flat)
7. `/data/local/tmp/dnscrypt-webui-backup` (tmp fallback)

**On APatch**: two `modules_update/` paths are prepended to the
list.

**Selection rule**: The first candidate with **≥ 3 valid files**
wins.

**Reference**: `docs/BACKUP.md` §1.2, §11.1.

---

### 🆕 Recovery Mode Trigger (v1.2.0)

**Layer 7** of the 10 defensive layers.

**Trigger files**:
- `$MODPATH/recovery` (module-specific).
- `/data/adb/dnscrypt-recovery` (external, survives module folder
  loss).

**Either one activates recovery mode** on the next boot.

**Recovery source priority**:
1. `$PERSISTENT_BACKUP/.last_stable`.
2. `$PERSISTENT_BACKUP/current/`.
3. In-place data (fallback).

**Both trigger files are removed** after a successful restore.

**v1.2.0 correctness fix (snapshot-and-reapply)**: The recovery-mode
flow uses a **snapshot-and-reapply** strategy. `§[8a]` restores the
5 files into `$MODPATH/proxy/` **and** copies each one to
`$MODPATH/.recovery_snapshot/`. `§[9]` extracts the ZIP normally —
this overwrites `webui.conf` and `dnscrypt-proxy.toml` with the
ZIP's defaults. `§[9b2]` re-applies the 5 files from the snapshot.
The extraction logic of `§[9]` is deliberately left untouched, so
the normal-install path is byte-for-byte identical. See §9 for the
full analysis and `docs/ARCHITECTURE.md` §3.10 for the flow diagram.

**Reference**: `docs/EMERGENCY.md` §9; `docs/SECURITY.md` §5.32.1.

---

### 🆕 `runtime_info.backups` (v1.2.0)

**7-field JSON object** in `runtime_info` describing the backup
state.

**Schema**:
```json
{
  "available": 5,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-09-29 15:00:00",
  "last_backup_name": "20260929-150000-v1.2.0",
  "last_stable": "20260929-095826-v1.2.0",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

**Purpose**: Observability + System Info panel display + API
verification.

**Compatibility**: `status.sh --json` also exposes 2 diagnostic-only
fields (`status`, `last_backup_age_seconds`) that are not part of
the API surface.

**Reference**: `docs/API.md` §6.1.7; `docs/BACKUP.md` §8.1.

---

### 🆕 `backupMu` (v1.2.0)

**`sync.Mutex` in `main.go`** that serializes pre-critical backups.

**Protected**: The entire shell invocation of `createAutoBackup`.

**Timeout**: `AUTO_BACKUP_TIMEOUT = 15 s`.

**Rationale**: Two rapid user actions (e.g. two `save_allowlist`
requests) could each trigger `createAutoBackup` on the same source
directory. Without serialization, this could corrupt a snapshot.

**Reference**: `docs/ARCHITECTURE.md` §4.3, §4.10.2;
`docs/BACKUP.md` §12.5.

---

### 🆕 `createAutoBackup` (v1.2.0)

**Go function** in `main.go` that snapshots the 5 user config files
before a destructive operation.

**Called from 5 destructive endpoints, but only 4 distinct reason
strings** (because `appendDenylist` delegates to `saveDenylist`):

| Endpoint | Reason string |
|---|---|
| `POST /api/update_profile` | `"pre-profile-change"` |
| `POST /api/save_allowlist` | `"pre-allowlist-save"` |
| `POST /api/save_denylist` | `"pre-denylist-save"` |
| `POST /api/save_custom_rules` | `"pre-custom-rules-save"` |
| `POST /api/append_denylist` | (no own reason — delegates to `saveDenylist`, which uses `"pre-denylist-save"`) |

**Corrected in this revision**: The `appendDenylist` entry
previously listed `pre-append-denylist` — that string does **not**
exist in the code. `appendDenylist` delegates to `saveDenylist`, so
the recorded reason is `pre-denylist-save`.

**Semantics**:
- **Best-effort** — a failed backup never blocks the user's action.
- **Serialized** by `backupMu`.
- **Delegated** to `functions.sh:backup_user_files` via
  `runShellWithTimeout`.
- **Rotation**: after success, `rotate_backups 21` is invoked in
  the same shell call.

**Reference**: `docs/ARCHITECTURE.md` §4.10.2; `docs/BACKUP.md` §4.3.

---

### 🆕 `cleanupOldTransactions` (v1.2.0)

**Go function** in `main.go` that removes leftover `COMMIT`'d
transaction directories at startup.

**Logic**:
1. Read `$PERSISTENT_BACKUP`.
2. For each `txn-*` directory, read `.state`:
   - `COMMIT` → remove the directory.
   - `START` / `ROLLBACK` / missing → **preserve**.
3. Log the number of removed directories.

**Non-goals**:
- Does not touch `orphan-txn-*` directories.
- Does not touch `current/` or any `<timestamp>-...` snapshot.

**Reference**: `docs/ARCHITECTURE.md` §4.10.3.

---

### 🆕 `checkPendingNotifications` (v1.2.0)

**Go function** in `main.go` that reads `.pending_notification` at
startup, logs its content, and removes the file.

**File location**: `$PERSISTENT_BACKUP/.pending_notification`.

**Producer**: `customize.sh` (writes after a successful restore).

**Semantics**:
- Missing file → no-op (common case).
- Empty file → removed silently (debug log).
- Non-empty file → logged via `logEvent("📢 " + msg)`, then removed.

**Reference**: `docs/ARCHITECTURE.md` §4.10.4.

---

### 🆕 `copy_with_context` (v1.2.0)

**Shell helper** in `functions.sh` that copies a file with its
SELinux context and mode preserved.

**Behavior**:
1. Copy the file.
2. Restore SELinux context via `restorecon` (preferred) or
   `chcon u:object_r:magisk_file:s0` (fallback).
3. Set mode `0600`.

**Usage**: Any restore operation on a user file. Do **not** use a
bare `cp -f`.

**Reference**: `docs/BACKUP.md` §12.3; `docs/DEVELOPMENT.md` §10.4.

---

### 🆕 `write_manifest` (v1.2.0)

**Shell helper** in `functions.sh` that writes `.manifest.json`
with per-file SHA256 hashes.

**Fields**:
- `version` — actual module version (install-time) or `"unknown"`
  (runtime).
- `timestamp` — `YYYYMMDD-HHMMSS`.
- `source` — source directory.
- `root_solution` — `magisk` / `kernelsu` / `apatch` / `unknown`.
- `files_count` — 0–5.
- `files[]` — `{name, sha256}`.

**Advisory**: Missing or invalid manifests do not block a restore.

**Reference**: `docs/BACKUP.md` §5.1.

---

### 🆕 `verify_backup_integrity` (v1.2.0)

**Shell helper** in `functions.sh` that runs the Layer 3 integrity
checks.

**Checks**:
1. Non-empty (size > 0).
2. Not oversized (size < 10 MB).
3. SHA256 (advisory) — a mismatch is logged as a warning but does
  **not** block a restore.

**3-tier hash extraction**: `jq` → `awk` → `grep`/`sed`. If none
succeeds, the check is skipped for that file.

**Reference**: `docs/BACKUP.md` §9.1.

---

### 🆕 Data Guardian (v1.2.0)

**Contributor badge** for testing the backup/restore system across
devices, root solutions, and upgrade scenarios.

**Acceptance criteria**:
- ✅ Test the 10 data-preservation layers on **3+ devices** or
  **3+ root solutions**.
- ✅ Verify that all 5 user config files survive an in-place
  upgrade.
- ✅ Verify that recovery mode restores all 5 files.
- ✅ Report the 7-field `backups` object before/after each scenario.

**Reference**: `docs/HALL_OF_FAME.md`; `docs/FAQ.md` Q129.

---

### 🆕 Root-Solution Detection (v1.2.0)

**Layer 5** of the 10 defensive layers. Detects the active root
solution and adapts the candidate source list.

**Detected solutions**:
- **Magisk**: module folder kept during in-place upgrades.
- **KernelSU**: module folder kept.
- **APatch**: module folder may be **deleted before** `customize.sh`
  runs. The installer checks
  `/data/adb/modules_update/dnscrypt-proxy-webui/proxy` as a
  fallback source.

**Reference**: `docs/COMPATIBILITY.md` §7.2; `docs/BACKUP.md` §1.3.

---

### 🆕 BAK-1 .. BAK-4 (v1.2.0)

**4 runtime additions** (not audit corrections) in the v1.2.0
data-preservation release:

| ID | Change | Reference |
|:-:|---|---|
| **BAK-1** | `runtime_info.backups` returns 7 fields | §5 "`runtime_info.backups`" |
| **BAK-2** | `createAutoBackup` + `backupMu` + rotation | §5 "`createAutoBackup`", "`backupMu`" |
| **BAK-3** | `cleanupOldTransactions` | §5 "`cleanupOldTransactions`" |
| **BAK-4** | `checkPendingNotifications` | §5 "`checkPendingNotifications`" |

**Reference**: `docs/SECURITY.md` §5.31; `docs/ARCHITECTURE.md`
§4.10.

---

### 🆕 FIX-1 / FIX-2 (v1.2.0)

**2 correctness fixes** (not audit corrections) in the v1.2.0
release:

| ID | Fix | Reference |
|:-:|---|---|
| **FIX-1** | Recovery-mode correctness via **snapshot-and-reapply** — `§[8a]` restores the 5 files AND copies each to `$MODPATH/.recovery_snapshot/`; `§[9]` extracts the ZIP normally (extraction logic untouched); `§[9b2]` re-applies the 5 files from the snapshot | §9 "Recovery Mode Correctness Fix" |
| **FIX-2** | Service Worker update-banner — send `SKIP_WAITING` to the correct worker | §9 "Service Worker Update-Banner Fix" |

**Reference**: `docs/SECURITY.md` §5.32.

---

### 🆕 Bilingual WebUI (v1.2.0)

**Global-edition feature** — the WebUI ships with **English as the
default language** and an **in-page toggle** (`langToggle`) that
switches to Arabic.

**Properties**:
- Preference stored **client-side only** in
  `localStorage['dnscrypt-lang']`.
- **No server state** — never transmitted to the API.
- **No network requests** on toggle — pure DOM manipulation.
- **Service Worker cache** stays neutral (HTML cached once).

**Reference**: `docs/ARCHITECTURE.md` §6.7; `docs/API.md` §10.8.

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

**v1.2.0** — `backupMu` is another `sync.Mutex` in `main.go`. See
§5 "`backupMu`".

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

### 🔒 `sync.Mutex` (`backupMu`) (v1.2.0)

**`sync.Mutex` in `main.go`** that serializes pre-critical backups.

**Protected**: The entire shell invocation of `createAutoBackup`.

**Timeout**: `AUTO_BACKUP_TIMEOUT = 15 s`.

**Constraint**: The lock is held for the entire shell invocation.
Do **not** perform long operations while holding it.

**See**: §5 "`backupMu`" for the full rationale.

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

**v1.2.0**: Also used for `$PERSISTENT_BACKUP/current/` (atomic
update via `.current.tmp.$$` + `.current.old.$$` + `mv`) and for
the watchdog token file.

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

**v1.2.0**: `main()` registers `/api/runtime_info/` (with trailing
slash) — both variants return the same JSON.

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

### ⏱️ `runShellWithTimeout` (v1.2.0)

**Go function** in `main.go` that runs a shell command with a
bounded timeout.

**Usage in v1.2.0**:
```go
runShellWithTimeout(
    ". functions.sh; ensure_backup_dir; "+
    "backup_user_files <src> <dst> && "+
    ". functions.sh; rotate_backups 21",
    15*time.Second, // AUTO_BACKUP_TIMEOUT
)
```

**Behavior**:
- Distinguishes **timeout** from **exit non-zero** in the log.
- Does not kill the child process if the timeout fires — the child
  may still be running briefly (the caller does not retry
  automatically).

**Reference**: `docs/ARCHITECTURE.md` §4.3, §4.10.2.

---

### ⏱️ `AUTO_BACKUP_TIMEOUT` (v1.2.0)

**Go constant** in `main.go` — `15 s`.

**Purpose**: Bounds the duration of the `createAutoBackup` shell
invocation.

**Effect**: The `backupMu` mutex is held for at most this duration
per call.

**Rule**: Do **not** raise this without understanding the effect on
`backupMu` serialization.

**Reference**: `docs/ARCHITECTURE.md` §4.10.2.

---

### 📦 `META-INF/update-binary` (v1.2.0)

**Bootstrap script** that is the root manager's (Magisk/KernelSU/
APatch) entry point for a module ZIP.

**Path in the ZIP**: `META-INF/com/google/android/update-binary`.

**Purpose**:
- Sources `/data/adb/magisk/util_functions.sh`.
- Calls `install_module`, which runs the module's `customize.sh`.

**Non-responsibility**: Contains **no** DNSCrypt logic. All installer
logic lives in `proxy/customize.sh`.

**Accompanying file**: `META-INF/com/google/android/updater-script`
(single line `#MAGISK`) — signals that the ZIP is a Magisk module.

**v1.2.0 note**: Unchanged from v1.0.0. The 10 defensive layers are
not visible to `update-binary` — they live entirely in
`customize.sh` and other shell scripts.

**Reference**: `docs/ARCHITECTURE.md` §8.4.

---

## 7. CI/CD & Release Terms

### 🔄 CI — Continuous Integration

**Continuous integration** — every push/PR runs automated checks.

**In the project**: `.github/workflows/ci.yml`.

**v1.2.0 addition**: A `backup-smoke-test` job that validates the 10
data-preservation layers (syntax + function presence + path
consistency + docs references).

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

**Example**: `v1.2.0`.

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
| v1.2.1 | 1020001 |
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

### 🧪 `upgrade-test.yml` (v1.2.0)

**GitHub Actions workflow** that runs a **42-scenario matrix** (3
root solutions × 2 source versions × 7 scenarios).

**Trigger**: manual (`workflow_dispatch`) + weekly schedule.

**Purpose**: Validate the 10 data-preservation layers across the
combinations that matter most.

**Runs in**: ~10 minutes.

**Not part of the release pipeline** — it is a QA tool.

**Reference**: `docs/CONTRIBUTING.md` §8.10; `docs/DEVELOPMENT.md`
§7.4.

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

**v1.2.0 note**: The Dashboard's System Info panel also displays the
**7-field `backups` object** from `runtime_info`. See §5
"`runtime_info.backups`".

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

**⚠️ v1.0.0 — NEW-6.** — Also: **empty results are never cached**
(BUG-C fix).

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

### 🆕 7-field Backups Schema (v1.2.0)

**Security concept** — the `runtime_info.backups` object exposes 7
fields describing the backup layer's state.

**Purpose**:
- **Observability** — a user reporting an issue can paste the JSON.
- **Verification** — the System Info panel displays the values.
- **Consistency** — matches `status.sh --json` on 7 shared fields.

**Fields**: `available`, `in_flight_txn`, `orphan_txn`,
`last_backup`, `last_backup_name`, `last_stable`, `path`.

**Why this is a security-adjacent addition**: A non-zero
`in_flight_txn` or `orphan_txn` signals a degraded backup layer that
may need manual inspection. Exposing these fields allows scripts and
users to detect this condition early.

**⚠️ v1.2.0 — BAK-1 (not an audit correction).**

**Reference**: `docs/API.md` §6.1.7; `docs/BACKUP.md` §8.1.

---

### 🆕 Recovery Mode Correctness Fix (v1.2.0)

**Correctness fix (FIX-1)** in `customize.sh`.

**The bug**: In an early v1.2.0 draft, the ZIP extraction step
(`§[9]`) ran **after** the recovery restore (`§[8a]`) and overwrote
`webui.conf` and `dnscrypt-proxy.toml` with the ZIP's defaults. The
subsequent restore step (`§[9c]`) was skipped in recovery mode, so
the corrupted files were never re-fixed. **Result**: 2 of the 5
restored files were silently lost during recovery.

**The fix — snapshot-and-reapply strategy**:

Rather than reordering the ZIP extraction steps (which would require
maintaining a duplicate exclusion list that depends on knowing the
ZIP's contents), the final v1.2.0 release uses a
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
  future release adds or removes files under `proxy/`, the fix keeps
  working.
- It keeps the extraction logic of `§[9]` **untouched**, so the
  normal-install path is byte-for-byte identical to the pre-recovery
  behavior.
- The snapshot directory uses `$MODPATH/.recovery_snapshot/`
  (dot-prefixed, cleaned up in `§[9b2]`), so it never appears in the
  final module layout.

**Partial re-application**: If `§[9b2]` re-applies fewer files than
were snapshotted, the snapshot directory is **preserved** at
`$MODPATH/.recovery_snapshot/` for manual recovery.

**⚠️ v1.2.0 — FIX-1 (not an audit correction).**

**Reference**: `docs/SECURITY.md` §5.32.1; `docs/ARCHITECTURE.md`
§3.10.

---

### 🆕 Service Worker Update-Banner Fix (v1.2.0)

**Correctness fix (FIX-2)** in `web/index.html` and
`web/dashboard.html`.

**The bug (v1.1.0)**: The [Reload] button sent `SKIP_WAITING` to
`navigator.serviceWorker.controller` — the **old** worker — which
ignored it. The new worker stayed in the `waiting` state, so the
banner reappeared on every page reload → infinite loop.

**The fix (v1.2.0)**:
- Send `SKIP_WAITING` to `swRegistration.waiting` (the **new**
  worker).
- Reload on the `controllerchange` event.
- Guard double-clicks with a `pendingReload` flag.

**Scope**: The v1.1.0 fix applied only to `index.html`. The v1.2.0
release completes the fix in `dashboard.html` as well.

**⚠️ v1.2.0 — FIX-2 (not an audit correction).**

**Reference**: `docs/SECURITY.md` §5.32.2; `docs/ARCHITECTURE.md`
§6.5.

---

### 🆕 Language Toggle (client-side only) (v1.2.0)

**Security concept** — the WebUI's bilingual toggle (English default
+ Arabic) is a **client-side only** concern.

**Properties**:
- **No server state**: The language preference is stored in
  `localStorage['dnscrypt-lang']` and never transmitted to the API.
- **No new network requests**: The toggle only manipulates the DOM.
- **No SW cache pollution**: The Service Worker caches the HTML
  **once**. Both `translations.en` and `translations.ar` objects are
  inline in the same file.
- **No XSS regression**: All translated strings pass through
  `textContent` / `escapeHtml()` exactly like their English
  counterparts.
- **No CSP change**: The toggle does not require `'unsafe-inline'`
  for anything beyond what already existed.
- **No information disclosure**: The language preference reveals
  nothing about the user.

**⚠️ v1.2.0 — feature (not an audit correction).**

**Reference**: `docs/BACKUP.md` §12.6; `docs/ARCHITECTURE.md` §6.7.

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

**v1.2.0 Abbreviations**:

| Abbreviation | Meaning | Full Form |
|:---:|---|---|
| **FBE** | File-Based Encryption | File-Based Encryption (Android) |
| **MTP** | Media Transfer Protocol | Media Transfer Protocol |
| **FUSE** | Filesystem in Userspace | Filesystem in Userspace (`/sdcard/` mount) |
| **OTA** | Over-The-Air | Over-The-Air update |

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

### 🆕 v1.2.0 — Data-Preservation Additions (Not Audit Corrections)

| ID | Change | Reference |
|:-:|---|---|
| **BAK-1** | 7-field `runtime_info.backups` | `runtime_info.backups` (§5) + §9 "7-field Backups Schema" |
| **BAK-2** | `createAutoBackup` + `backupMu` + rotation | `createAutoBackup`, `backupMu` (§5) + §6 `backupMu` |
| **BAK-3** | `cleanupOldTransactions` | `cleanupOldTransactions` (§5) |
| **BAK-4** | `checkPendingNotifications` | `checkPendingNotifications` (§5) |

### 🆕 v1.2.0 — Correctness Fixes (Not Audit Corrections)

| ID | Fix | Reference |
|:-:|---|---|
| **FIX-1** | Recovery-mode **snapshot-and-reapply** | `Recovery Mode Correctness Fix` (§9) |
| **FIX-2** | Service Worker update-banner | `Service Worker Update-Banner Fix` (§9) |

### 🆕 v1.2.0 — 10 Defensive Layers

| # | Layer | Reference |
|:-:|---|---|
| 1 | Multi-Source Detection | `Multi-Source Detection` (§5) |
| 2 | Persistent Backup | `Persistent Backup` (§5) |
| 3 | SHA256 Integrity Verification | `verify_backup_integrity` (§5) |
| 4 | Transactional Upgrade | `Transactional Upgrade` (§5) |
| 5 | Root-Solution Compatibility | `Root-Solution Detection` (§5) |
| 6 | SELinux Preservation | `copy_with_context` (§5) |
| 7 | Recovery Mode | `Recovery Mode Trigger` (§5) |
| 8 | Config Migrations | (see `docs/BACKUP.md` §11) |
| 9 | Automation + Rotation | (see `docs/BACKUP.md` §6) |
| 10 | Observability | `runtime_info.backups` (§5) |

### 📁 File-Scoped Identifier Families (HARD-*)

> **Note on HARD-* identifiers**: The `HARD-XX-NN` family is
> **file-scoped**. Each source file documents its own `HARD-*`
> identifiers in its header block. They are **NOT** centrally
> catalogued here because they are implementation details, not
> project-wide decisions. If you are looking for a specific
> `HARD-*` identifier, open the source file that owns it.
>
> **Index of `HARD-*` families by owning file**:
>
> | Prefix | Owning file | Range | Purpose |
> |---|---|---|---|
> | `HARD-CS-*` | `proxy/customize.sh` | 01..10 | Installer hardening (10 defensive layers) |
> | `HARD-FSH-*` | `proxy/functions.sh` | 01..11 | Backup helpers + `get_watchdog_token` (FSH-11) |
> | `HARD-BK-*` | `docs/BACKUP.md` | 01..19 (with gaps) | Backup system reference hardening (see `docs/BACKUP.md` header for the exact list) |
> | `HARD-COMPAT-*` | `docs/COMPATIBILITY.md` | 01..07 | Device compatibility hardening |
> | `HARD-MK-*` | `Makefile` | 01..09 | Build-target hardening |
> | `HARD-PM-*` | `scripts/package_module.sh` | 01..10 | Module packaging hardening |
> | `BLD-*` | `proxy/build.sh` | 1..8 | Cross-compilation hardening |
> | `ACT-*` | `proxy/action.sh` | 1..N | Magisk Action button hardening (e.g. ACT-5) |
>
> **Why these are file-scoped, not project-wide**:
>
> - A `HARD-*` identifier describes a **concrete implementation
>   rule** inside a specific file (e.g. "always restore the SELinux
>   context after a copy"). It is not a project-level decision that
>   would justify an ADR.
> - Renumbering a `HARD-*` identifier in one file has no effect on
>   any other file. The family prefix (`CS`, `FSH`, `BK`, ...)
>   already encodes the owning file, so central numbering would add
>   coordination cost without any benefit.
> - If a `HARD-*` rule ever becomes a project-wide concern, it is
>   promoted to an **Audit Correction** (see §17 of
>   `docs/SECURITY.md`) or a **BAK-* / FIX-* / MEM-*** identifier
>   (see above). At that point it gains a project-wide number.
>
> **Cross-reference**:
>
> - The **Audit Corrections Registry** lives in
>   `docs/SECURITY.md` §17 (currently at **#33**; next expected
>   **#34** in v1.3.x).
> - The **v1.2.0 runtime additions** (BAK-1..BAK-4, FIX-1, FIX-2,
>   WD-TOKEN) are also listed in `docs/SECURITY.md` §17.2 — they
>   are deliberately **not** audit correction numbers.
> - The **10 defensive layers** correspond to the `HARD-CS-*` and
>   `HARD-FSH-*` families. See `docs/BACKUP.md` §1.3 for the layer
>   → file mapping.

### v1.0.0 — Audit Corrections Registry

The last audit correction is **#33** (v1.0.0). See
`docs/SECURITY.md` §17 for the full registry.

**Next expected**: #34 (v1.3.x).

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
| [docs/ARCHITECTURE.md](ARCHITECTURE.md) | Full architecture (§3.10, §4.10) |
| [docs/SECURITY.md](SECURITY.md) | Security + Audit Corrections (§5.31, §5.32) |
| [docs/API.md](API.md) | HTTP API Reference (§6.1.7) |
| [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Troubleshooting |
| [docs/COMPATIBILITY.md](COMPATIBILITY.md) | Compatibility matrix |
| [docs/DNS_BINARIES.md](DNS_BINARIES.md) | DNS binaries management (Level 4) |
| [docs/DEVELOPMENT.md](DEVELOPMENT.md) | Developer guide |
| [docs/CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guide |
| [docs/INSTALL.md](INSTALL.md) | Installation guide |
| [docs/UPGRADE.md](UPGRADE.md) | Upgrade guide (§3.0, §3.1) |
| [docs/BACKUP.md](BACKUP.md) | **Backup system reference (v1.2.0)** |
| [docs/EMERGENCY.md](EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [docs/FAQ.md](FAQ.md) | Frequently asked questions (Q121–Q130) |
| [CHANGELOG.md](../CHANGELOG.md) | Version history (v1.0.0 → v1.2.0) |

---

## 13. Contributing

Found a missing term? Or an unclear definition?

- 🐛 **Open an Issue** titled `[Docs] Glossary: term X`.
- 🔧 **Submit a PR** directly to add it.
- 📖 Follow the existing formatting style.
- ✅ Make sure to add the appropriate section (1-12).

---

*Last updated: 2026-10-02*
*Version: v1.3.0*
*Author: gasciljh*

---

<div align="center">

**💡 Tip**: Bookmark this page as a quick reference!

[⬆ Back to top](#glossary--terms--abbreviations)

</div>