# Security Policy

**DNSCrypt Smart Filter** — Security policy and vulnerability disclosure.

> **Full document**: this is a summary page. The complete policy with the full threat model is available at:
> **[docs/SECURITY.md](docs/SECURITY.md)**

---

## Reporting a Vulnerability

### Do not open a public Issue

The vulnerability may be exploited before a fix is deployed. Use one of the following channels:

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
v1.0.0 (or any version)

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

- **Shell scripts** (`proxy/*.sh`):
  - Lifecycle (boot / uninstall)
  - Watchdog
  - Permissions

- **Frontend** (`web/`):
  - XSS
  - CSRF
  - Content Security Policy

### Out of Scope

- **dnscrypt-proxy** itself (upstream) → report [here](https://github.com/DNSCrypt/dnscrypt-proxy/security)
- **Magisk / KernelSU / APatch** → report to the relevant maintainer
- **Android OS** → report to Google
- **HaGeZi blocklists** → report [here](https://github.com/hagezi/dns-blocklists/issues)

---

## Recognition

- **Security Researcher** badge in [`docs/HALL_OF_FAME.md`](docs/HALL_OF_FAME.md)
- Your name in the release that fixes the vulnerability
- **Auditor** badge for each accepted Audit Correction

---

## Related Documentation

| Document | Content |
|---|---|
| **[docs/SECURITY.md](docs/SECURITY.md)** | Full policy + Threat Model |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architecture + Trade-offs |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Troubleshooting |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Contribution guide |
| [CHANGELOG.md](CHANGELOG.md) | Version history (including security) |

---

## Applied Protections (Summary)

| Category | Measures |
|---|---|
| **Authentication** | Constant-time comparison, Rate limiting (5/15 min), Login POST-only (v1.0.0), Cookie-only sessions |
| **Sessions** | HttpOnly, SameSite=Lax, Secure (conditional), Session GC, Auth cache 60 s (v1.0.0) |
| **Headers** | Strict CSP, X-Frame-Options, nosniff, COOP, CORP |
| **Input** | MaxBytesReader (5 MB), Path whitelist, Atomic writes, `hasEndpoint` (exact match), `readConfPort` (range check), `shellQuote` (shell injection protection) |
| **DoS** | SSE Write Deadline (30 s), Rate limiting, limitedBuffer |
| **Health endpoints** | `/healthz` public, `/readyz` localhost-only (v1.0.0) |
| **Firewall** | Custom Chains (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`), no orphans |
| **State** | STATUS_FILE = User Intent, reliable Watchdog, `rebuildMu` (serializes rebuildBlocklist) (v1.0.0) |
| **IPv6** | Safe `getClientIP`, `[::1]` support |
| **Ports** | `runtime_info` returns actual ports — no hardcoded values (v1.0.0) |

---

## Key Security Fixes (v1.0.0)

### Critical

- **Login POST-only** — `/api/auth/login` rejects GET/HEAD/PUT/DELETE (CSRF protection).
- **`/readyz` localhost-only** — does not expose system details on LAN.
- **`shellQuote()`** — shell injection protection in dynamic paths.

### Important

- **`hasEndpoint()`** — exact path matching (no loose `strings.HasSuffix`).
- **`readConfPort` range check** — rejects values outside `[1, 65535]`.
- **Basic Auth rate limiting** — 5 attempts / 15 minutes.

### Improvements

- **`rebuildMu` mutex** — prevents race condition between `updateProfile` and `saveAllowlist`.
- **`runtime_info` ports** — dynamic links instead of hardcoded.
- **Auth cache (60 s)** — reduces file I/O without impacting security.

---

## Notes

- Do **not** share vulnerability details publicly before the fix.
- **Critical vulnerabilities** may warrant a **hotfix** release.
- **Responsible disclosure** is always appreciated.
- Read [docs/SECURITY.md](docs/SECURITY.md) for full details.

---

## Contact

- **Maintainer**: [@gasciljh](https://github.com/gasciljh)
- **GitHub**: [Report a vulnerability](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

---

*Last updated: 2026-09-24*
*Version: v1.0.0*