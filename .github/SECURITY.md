# Security Policy

**DNSCrypt Smart Filter** — Security policy and vulnerability disclosure.

> **Full document**: this is a summary page. The complete policy with the
> full threat model is available at:
> **[docs/SECURITY.md](../docs/SECURITY.md)**

**Version**: v1.1.0
**Last updated**: 2026-09-26

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • **No new audit corrections** — v1.1.0 is a documentation + polish
>     release. The Audit Corrections Registry remains at **#33** (the
>     last entry from v1.0.0).
>   • Three runtime improvements (MEM-1 / MEM-2 / MEM-3) are documented
>     in [`docs/SECURITY.md`](../docs/SECURITY.md) §5.30 and §17.1.
>     They close edge cases rather than fix known exploitable
>     vulnerabilities.
>   • One **critical** fix in `web/offline.html` — removed a restrictive
>     CSP meta that silently blocked the offline page's own scripts.
>     See "Key Security Fixes (v1.1.0)" below.
>   • References updated to point at §5.30, §17.1, and
>     [`docs/UPGRADE.md`](../docs/UPGRADE.md).

---

## Reporting a Vulnerability

### Do not open a public Issue

The vulnerability may be exploited before a fix is deployed. Use one of
the following channels:

| Channel | URL | SLA |
|---|---|---|
| **GitHub Private Advisory** (preferred) | [Report a vulnerability](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new) | 24–48h |
| **Email** (alternative) | Open an Issue titled `[SECURITY]` with no details | 24–48h |
| **Discussions** (general) | [Security category](https://github.com/gasciljh/dnscrypt-proxy-webui/discussions) | — |

---

## Information Required in the Report

To expedite handling, include:

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
- Magisk/KernelSU/APatch version:

## PoC (if possible)
[code / screenshot / log]

## Suggested Fix (optional)
[Your idea for a solution]
```

---

## SLA (Service Level Agreement)

| Phase | Duration |
|---|---|
| Acknowledgment | 24–48 hours |
| Initial assessment | 3–5 days |
| Fix | Depends on severity |
| Public disclosure | After fix |

---

## Security Scope

### In Scope

- **Backend** (`proxy/main.go`):
  - Authentication and sessions
  - Rate limiting
  - CSRF protection
  - Path traversal
  - Input validation
  - Firewall (Custom Chains)
  - Concurrency (mutex)
  - **Dynamic memory limit** (`debug.SetMemoryLimit`, v1.1.0 — MEM-1)

- **Shell scripts** (`proxy/*.sh`):
  - Lifecycle (boot / uninstall)
  - Watchdog
  - Permissions
  - **`shellQuote`-protected paths** (extended in v1.1.0 — MEM-2)

- **Frontend** (`web/`):
  - XSS
  - CSRF
  - Content Security Policy
  - **Offline page behavior** (`offline.html`, v1.1.0 fix)

### Out of Scope

- **dnscrypt-proxy** itself (upstream) → report [here](https://github.com/DNSCrypt/dnscrypt-proxy/security)
- **Magisk / KernelSU / APatch** → report to the relevant maintainer
- **Android OS** → report to Google
- **HaGeZi blocklists** → report [here](https://github.com/hagezi/dns-blocklists/issues)

---

## Recognition

- **Security Researcher** badge in [`docs/HALL_OF_FAME.md`](../docs/HALL_OF_FAME.md)
- Your name in the release that fixes the vulnerability
- **Auditor** badge for each accepted Audit Correction
- **Memory Architect** badge (v1.1.0) for contributors who test the
  dynamic memory limit across multiple RAM tiers

---

## Related Documentation

| Document | Content |
|---|---|
| **[docs/SECURITY.md](../docs/SECURITY.md)** | Full policy + Threat Model + Audit Corrections Registry |
| [docs/SECURITY.md §5.30](../docs/SECURITY.md) | v1.1.0 runtime improvements (MEM-1 / MEM-2 / MEM-3) |
| [docs/SECURITY.md §17.1](../docs/SECURITY.md) | v1.1.0 improvements registry |
| [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) | Architecture + Trade-offs |
| [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) | Diagnostics + memory-limit debugging |
| [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md) | Contribution guide |
| [docs/UPGRADE.md](../docs/UPGRADE.md) | Version upgrade guide (v1.0.0 → v1.1.0) |
| [CHANGELOG.md](../CHANGELOG.md) | Version history (including v1.1.0) |

---

## Applied Protections (Summary)

| Category | Measures |
|---|---|
| **Authentication** | Constant-time comparison, Rate limiting (5/15 min), Login POST-only (v1.0.0), Cookie-only sessions |
| **Sessions** | HttpOnly, SameSite=Lax, Secure (conditional), Session GC, Auth cache 60 s (v1.0.0) |
| **Headers** | Strict CSP, X-Frame-Options, nosniff, COOP, CORP |
| **Input** | MaxBytesReader (5 MB), Path whitelist, Atomic writes, `hasEndpoint` (exact match), `readConfPort` (range check), `shellQuote` (shell injection protection) |
| **DoS** | SSE Write Deadline (30 s), Rate limiting, limitedBuffer, **dynamic per-profile memory limit (v1.1.0 — MEM-1)** |
| **Health endpoints** | `/healthz` public, `/readyz` localhost-only (v1.0.0) |
| **Firewall** | Custom Chains (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`), no orphans |
| **State** | STATUS_FILE = User Intent, reliable Watchdog, `rebuildMu` (serializes rebuildBlocklist) (v1.0.0) |
| **IPv6** | Safe `getClientIP`, `[::1]` support |
| **Ports** | `runtime_info` returns actual ports — no hardcoded values (v1.0.0), **`MONITORING_UI_PORT` constant in metrics handler (v1.1.0 — MEM-3)** |
| **Memory** | **Per-profile `debug.SetMemoryLimit` (v1.1.0 — MEM-1)**, `profile_key` + `memory_limit_mb` exposed via `runtime_info` |
| **Offline page** | **CSP removed from `offline.html` (v1.1.0 — no real attack surface exists; see full policy for reintroduction conditions)** |

---

## Key Security Fixes (v1.1.0)

### Critical

- **`web/offline.html`** — Removed the restrictive CSP meta tag
  (`default-src 'none'`) that silently blocked the offline page's own
  inline `<script>`. The page rendered correctly but every interactive
  feature (Retry, Diagnose, language toggle, auto-retry) silently
  failed. The CSP was redundant: the page has no user data, no forms,
  no network calls after load, and uses only `textContent`. If a future
  version adds dynamic content from untrusted sources, CSP must be
  reintroduced — preferably with a nonce rather than `'unsafe-inline'`.

### Runtime improvements (not audit corrections)

These are documented in [`docs/SECURITY.md`](../docs/SECURITY.md) §5.30
and §17.1 as **runtime improvements**, not audit corrections. They
close edge cases rather than fix known exploitable vulnerabilities.

- **MEM-1 — Dynamic memory limit per profile.** `main.go` now sets
  `debug.SetMemoryLimit` based on the active profile (light=80 MB,
  normal=100 MB, pro=120 MB, proplus=160 MB, ultimate=220 MB).
  Prevents GC thrashing on heavy profiles without weakening DoS
  protection on light ones. Exposed via `runtime_info.memory_limit_mb`.

- **MEM-2 — Extended `shellQuote` character set.** Adds `{`, `}`, `\n`,
  `\t` to the escape list (24 total). Defense-in-depth; no known
  exploitable path existed.

- **MEM-3 — `MONITORING_UI_PORT` in metrics handler.** Removes the
  last hardcoded `"8080"` string from `metricsProxyHandler`. Single
  source of truth for the reserved port.

### Important

- **`proxy/customize.sh`** — Port collision fix. When both `PORT` and
  `DASHBOARD_PORT` were `9091`, the previous logic detected the
  collision but reset dashboard to `9091` (no actual change). New
  logic: if `PORT=9091` → dashboard becomes `9092`; otherwise →
  dashboard becomes `9091`.

---

## Key Security Fixes (v1.0.0)

### Critical

- **Login POST-only** — `/api/auth/login` rejects GET/HEAD/PUT/DELETE
  (CSRF protection).
- **`/readyz` localhost-only** — does not expose system details on LAN.
- **`shellQuote()`** — shell injection protection in dynamic paths.

### Important

- **`hasEndpoint()`** — exact path matching (no loose
  `strings.HasSuffix`).
- **`readConfPort` range check** — rejects values outside `[1, 65535]`.
- **Basic Auth rate limiting** — 5 attempts / 15 minutes.

### Improvements

- **`rebuildMu` mutex** — prevents race condition between
  `updateProfile` and `saveAllowlist`.
- **`runtime_info` ports** — dynamic links instead of hardcoded.
- **Auth cache (60 s)** — reduces file I/O without impacting security.
- **Preserve settings on upgrade** — backup/restore of 5 user config
  files.
- **Custom Chains** — `DNSCRYPT_OUT` / `DNSCRYPT_OUT6` (no orphan
  rules).

---

## Notes

- Do **not** share vulnerability details publicly before the fix.
- **Critical vulnerabilities** may warrant a **hotfix** release.
- **Responsible disclosure** is always appreciated.
- Read [docs/SECURITY.md](../docs/SECURITY.md) for full details.
- **Audit Corrections Registry remains at #33** — v1.1.0 does not
  extend it. New audit corrections will resume at **#34** in v1.2.x.
  See [`docs/SECURITY.md`](../docs/SECURITY.md) §17.
- **v1.1.0 does not introduce new attack vectors.** All v1.0.0
  security fixes remain in place. The three runtime improvements
  (MEM-1 / MEM-2 / MEM-3) are strictly defensive.
- **`web/offline.html` no longer has a CSP meta.** If you add dynamic
  content to that page in the future, reintroduce CSP — preferably
  with a nonce rather than `'unsafe-inline'`.

---

## Contact

- **Maintainer**: [@gasciljh](https://github.com/gasciljh)
- **GitHub**: [Report a vulnerability](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

---

*Last updated: 2026-09-26*
*Version: v1.1.0*