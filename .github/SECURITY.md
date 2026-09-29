# Security Policy

**DNSCrypt Smart Filter** — Security policy and vulnerability disclosure.

> **Full document**: this is a summary page. The complete policy with the
> full threat model is available at:
> **[docs/SECURITY.md](../docs/SECURITY.md)**

**Version**: v1.2.0 (Global Edition)
**Last updated**: 2026-09-29

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **No new audit corrections** — v1.2.0 is a data-preservation
>     release. The Audit Corrections Registry remains at **#33** (the
>     last entry from v1.0.0).
>   • **New §5.31** (`docs/SECURITY.md`) — Data Preservation Security
>     Model. Documents the 10 defensive layers, the `backupMu`
>     serialization guarantee, and the threat model for the
>     persistent backup directory at
>     `/sdcard/dnscrypt-webui-backup/`.
>   • **New §5.32** (`docs/SECURITY.md`) — Correctness Fixes
>     (FIX-1, FIX-2). Neither is an exploitable vulnerability.
>   • **New §5.33** (`docs/SECURITY.md`) — Watchdog Token
>     (WD-TOKEN). Documents the `X-Watchdog-Token` authentication
>     that replaces the previous localhost bypass on
>     `POST /api/ensure_running_service`.
>   • **New §14.25–§14.30** (`docs/SECURITY.md`) — six new audit
>     checklist sections.
>   • **Breaking change for callers of `POST /api/append_denylist`** —
>     the endpoint now requires a `content` parameter.
>   • **Global edition — English default + Arabic toggle**: the WebUI
>     ships with English as the default language and an in-page
>     toggle to switch to Arabic. **No API impact** — see
>     `docs/SECURITY.md` §5.31.7.
>   • References updated to point at §5.31, §5.32, §5.33,
>     `docs/BACKUP.md`, and `docs/EMERGENCY.md`.

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
v1.2.0 (or any version)

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
  - Concurrency (mutexes)
  - Dynamic memory limit (`debug.SetMemoryLimit`, v1.1.0 — MEM-1)
  - **Pre-critical backups** (`createAutoBackup` + `backupMu`, v1.2.0)
  - **Watchdog token** (`X-Watchdog-Token`, v1.2.0)

- **Shell scripts** (`proxy/*.sh`):
  - Lifecycle (boot / uninstall)
  - Watchdog
  - Permissions
  - `shellQuote`-protected paths (extended in v1.1.0 — MEM-2)
  - **Backup helpers** (`backup_user_files`, `restore_user_files`,
    `rotate_backups`, `copy_with_context`, `verify_backup_integrity` —
    v1.2.0)
  - **SELinux context preservation** (`restorecon` / `chcon`, v1.2.0)

- **Frontend** (`web/`):
  - XSS
  - CSRF
  - Content Security Policy
  - Offline page behavior (`offline.html`, v1.1.0 fix)
  - **Bilingual language toggle** (client-side only, v1.2.0)

- **Persistent backup directory** (v1.2.0):
  - `/sdcard/dnscrypt-webui-backup/` — permissions, rotation,
    transaction state files, SHA256 manifest
  - `txn-*` / `orphan-txn-*` — transaction handling
  - `.last_stable` pointer
  - `.upgrade_history.json` — upgrade log

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
- **Data Guardian** badge (v1.2.0) for contributors who test the
  backup/restore system across devices, root solutions, and upgrade
  scenarios — see
  [`docs/HALL_OF_FAME.md`](../docs/HALL_OF_FAME.md)

---

## Related Documentation

| Document | Content |
|---|---|
| **[docs/SECURITY.md](../docs/SECURITY.md)** | Full policy + Threat Model + Audit Corrections Registry |
| [docs/SECURITY.md §5.30](../docs/SECURITY.md) | v1.1.0 runtime improvements (MEM-1 / MEM-2 / MEM-3) |
| [docs/SECURITY.md §5.31](../docs/SECURITY.md) | **v1.2.0 Data Preservation Security Model** |
| [docs/SECURITY.md §5.32](../docs/SECURITY.md) | **v1.2.0 Correctness Fixes (FIX-1, FIX-2)** |
| [docs/SECURITY.md §5.33](../docs/SECURITY.md) | **v1.2.0 Watchdog Token (WD-TOKEN)** |
| [docs/SECURITY.md §17.1](../docs/SECURITY.md) | v1.1.0 improvements registry |
| [docs/SECURITY.md §17.2](../docs/SECURITY.md) | **v1.2.0 runtime additions registry** |
| [docs/SECURITY.md §17.3](../docs/SECURITY.md) | **v1.2.0 post-audit corrections** |
| [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) | Architecture + Trade-offs (§3.10, §4.10) |
| [docs/BACKUP.md](../docs/BACKUP.md) | **Backup system reference (v1.2.0)** |
| [docs/EMERGENCY.md](../docs/EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) | Diagnostics + memory-limit + backup debugging |
| [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md) | Contribution guide |
| [docs/API.md](../docs/API.md) | HTTP API Reference (§6.1.7) |
| [docs/UPGRADE.md](../docs/UPGRADE.md) | Version upgrade guide (§3.0, §3.1) |
| [CHANGELOG.md](../CHANGELOG.md) | Version history (including v1.2.0) |

---

## Applied Protections (Summary)

| Category | Measures |
|---|---|
| **Authentication** | Constant-time comparison, Rate limiting (5/15 min), Login POST-only, Cookie-only sessions, **Watchdog token (`X-Watchdog-Token`, v1.2.0)** |
| **Sessions** | HttpOnly, SameSite=Lax, Secure (conditional), Session GC, Auth cache 60 s |
| **Headers** | Strict CSP, X-Frame-Options, nosniff, COOP, CORP |
| **Input** | MaxBytesReader (5 MB), Path whitelist, Atomic writes, `hasEndpoint` (exact match), `readConfPort` (range check), `shellQuote` (shell injection protection) |
| **DoS** | SSE Write Deadline (30 s), Rate limiting, limitedBuffer, dynamic per-profile memory limit (v1.1.0 — MEM-1), **bounded backup disk usage (v1.2.0)** |
| **Health endpoints** | `/healthz` public, `/readyz` localhost-only |
| **Firewall** | Custom Chains (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`), no orphans |
| **State** | STATUS_FILE = User Intent, reliable Watchdog, `rebuildMu` (serializes rebuildBlocklist), **`backupMu` (serializes pre-critical backups, v1.2.0)** |
| **IPv6** | Safe `getClientIP`, `[::1]` support |
| **Ports** | `runtime_info` returns actual ports — no hardcoded values, `MONITORING_UI_PORT` constant in metrics handler (v1.1.0 — MEM-3) |
| **Memory** | Per-profile `debug.SetMemoryLimit` (v1.1.0 — MEM-1), `profile_key` + `memory_limit_mb` exposed via `runtime_info` |
| **Offline page** | CSP removed from `offline.html` (v1.1.0 — no real attack surface exists; see full policy for reintroduction conditions) |
| **Data preservation (v1.2.0)** | 10 defensive layers, persistent backup directory with `0700`/`0600` permissions, SHA256 integrity verification (advisory), transactional install with rollback, recovery mode via trigger file, SELinux context preservation |

---

## Key Security Fixes (v1.2.0)

### Data preservation (v1.2.0)

- **Fixes a silent data-loss bug in v1.1.0** — The installer used a
  path-comparison check (`$_EXISTING_MODULE != $MODPATH`) that always
  failed on in-place upgrades. Result: the 5 user config files were
  silently erased on every upgrade. Fixed by the **10 defensive
  layers** (Layer 1 multi-source detection + Layer 2 persistent
  backup + Layer 4 transactional install). See
  [`docs/SECURITY.md`](../docs/SECURITY.md) §5.31.

### Watchdog token (v1.2.0 — WD-TOKEN)

- **Closes a CSRF hole on `POST /api/ensure_running_service`** —
  Before v1.2.0, this endpoint was protected only by an implicit
  "localhost bypass" — any web page loaded in a browser on the same
  device could silently trigger a service restart.
  - Now requires an `X-Watchdog-Token` header on localhost requests.
  - Token is a 32-byte secret from `crypto/rand`, written atomically
    to `$RUN_DIR/.watchdog_token` (mode `0600`).
  - Constant-time comparison via `subtle.ConstantTimeCompare`.
  - See [`docs/SECURITY.md`](../docs/SECURITY.md) §5.33.

### Correctness fixes (v1.2.0 — FIX-1, FIX-2)

- **FIX-1 — Recovery-mode reorder.** In an early v1.2.0 draft, the
  ZIP extraction step ran **after** the recovery restore and
  overwrote `webui.conf` and `dnscrypt-proxy.toml` with the ZIP's
  defaults. Fixed by reordering the phases and excluding the two
  files at risk when `RECOVERY_MODE=1`. See
  [`docs/SECURITY.md`](../docs/SECURITY.md) §5.32.

- **FIX-2 — Service Worker update-banner.** The v1.1.0 fix applied
  only to `index.html`. The [Reload] button sent `SKIP_WAITING` to
  the old worker, which ignored it. Fixed by sending `SKIP_WAITING`
  to `swRegistration.waiting` and applying the fix to **both**
  `index.html` and `dashboard.html`. See
  [`docs/SECURITY.md`](../docs/SECURITY.md) §5.32.

### Breaking change for API consumers (v1.2.0)

- **`POST /api/append_denylist`** — now **requires** a `content`
  parameter. Without it → `400 Bad Request`:
  ```json
  {"status": "error", "message": "Missing or empty 'content' parameter"}
  ```
  - **Why**: In earlier drafts, the endpoint took no arguments and
    re-saved the current denylist unchanged — a no-op that still
    consumed a pre-critical backup.
  - **Migration**: Send `content` (URL-encoded). Or use
    `POST /api/save_denylist` with the full new content.
  - See [`docs/API.md`](../docs/API.md) §6.2.7 and
    [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) §12.8.

### Runtime additions (not audit corrections)

These are documented in [`docs/SECURITY.md`](../docs/SECURITY.md)
§5.31 as **runtime additions**, not audit corrections. They close
edge cases rather than fix known exploitable vulnerabilities.

- **BAK-1 — 7-field `runtime_info.backups`.** Exposes
  `available`, `in_flight_txn`, `orphan_txn`, `last_backup`,
  `last_backup_name`, `last_stable`, `path`. Enables early
  detection of a degraded backup layer.

- **BAK-2 — `createAutoBackup(reason)` + `backupMu`.** Pre-critical
  backup before 5 destructive endpoints. Serialized by `backupMu`
  to prevent concurrent snapshot corruption.

- **BAK-3 — `cleanupOldTransactions()`.** Removes leftover
  `COMMIT`'d `txn-*` dirs at startup. Preserves `START`,
  `ROLLBACK`, and `orphan-txn-*`.

- **BAK-4 — `checkPendingNotifications()`.** Reads
  `.pending_notification` at startup; centralized deletion in
  `main.go` to avoid a race with `service.sh`.

### v1.1.0 runtime improvements (carried forward)

These are documented in [`docs/SECURITY.md`](../docs/SECURITY.md)
§5.30 as **runtime improvements**, not audit corrections.

- **MEM-1 — Dynamic memory limit per profile.** `main.go` sets
  `debug.SetMemoryLimit` based on the active profile (light=80 MB,
  normal=100 MB, pro=120 MB, proplus=160 MB, ultimate=220 MB).

- **MEM-2 — Extended `shellQuote` character set.** Adds `{`, `}`,
  `\n`, `\t` to the escape list (24 total).

- **MEM-3 — `MONITORING_UI_PORT` in metrics handler.** Removes the
  last hardcoded `"8080"` string.

### v1.1.0 critical fix (carried forward)

- **`web/offline.html`** — Removed the restrictive CSP meta tag
  (`default-src 'none'`) that silently blocked the offline page's
  own inline `<script>`.

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
- **Audit Corrections Registry remains at #33** — v1.2.0 does not
  extend it. New audit corrections will resume at **#34** in
  **v1.3.x**. See [`docs/SECURITY.md`](../docs/SECURITY.md) §17.
- **v1.2.0 does not introduce new attack vectors.** All v1.0.0 and
  v1.1.0 security fixes remain in place. The v1.2.0 additions
  (BAK-1..BAK-4, FIX-1, FIX-2, WD-TOKEN) are strictly defensive.
- **`web/offline.html` no longer has a CSP meta.** If you add dynamic
  content to that page in the future, reintroduce CSP — preferably
  with a nonce rather than `'unsafe-inline'`.
- **`POST /api/append_denylist` now requires a `content` parameter.**
  Update any scripts that called it with no arguments.
- **Persistent backup directory**: `/sdcard/dnscrypt-webui-backup/`
  is owned by root with mode `0700` on directories and `0600` on
  files. A malicious root app can still read it. See
  [`docs/BACKUP.md`](../docs/BACKUP.md) §12.5.

---

## Contact

- **Maintainer**: [@gasciljh](https://github.com/gasciljh)
- **GitHub**: [Report a vulnerability](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

---

*Last updated: 2026-09-29*
*Version: v1.2.0*