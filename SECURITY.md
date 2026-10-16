# Security Policy

**DNSCrypt Smart Filter** — Security policy and vulnerability disclosure.

> **Full document**: this is a summary page. The complete policy with the
> full threat model is available at:
> **[docs/SECURITY.md](docs/SECURITY.md)**

**Version**: v1.5.0 (Global Edition)
**Last updated**: 2026-10-13

> **Identifier inventory in this file (14 total)**:
>   • HARD-SECROOT-01 (`Last updated` correction — v1.4.0)
>   • HARD-SECROOT-02 (v1.3.0 block extended with SNAP-* / ROT-* — v1.4.0)
>   • HARD-SECROOT-03 (Cross-references section added — v1.4.0)
>   • HARD-SECROOT-04 (Key Security Fixes v1.3.0 — rotation — v1.4.0)
>   • HARD-SECROOT-05 (Applied Protections table — v1.3.0 row — v1.4.0)
>   • HARD-SECROOT-06 (In Scope — v1.3.0 rotation semantics — v1.4.0)
>   • HARD-SECROOT-07 (Notes — v1.3.0 / v1.4.0 clarification — v1.4.0)
>   • HARD-SECROOT-08 (v1.5.0 changes block added — v1.5.0)
>   • HARD-SECROOT-09 (In Scope — v1.5.0 install endpoints + install_app.sh — v1.5.0)
>   • HARD-SECROOT-10 (Applied Protections — v1.5.0 rows — v1.5.0)
>   • HARD-SECROOT-11 (Key Security Fixes v1.5.0 section added — v1.5.0)
>   • HARD-SECROOT-12 (Related Documentation — §5.36 + §14.34 added — v1.5.0)
>   • HARD-SECROOT-13 (Notes — v1.5.0 context — v1.5.0)
>   • HARD-SECROOT-DATE (Global Edition date bump — v1.5.0+)
>
> **Cross-references**:
>   • [docs/SECURITY.md](docs/SECURITY.md) — full policy + Audit Corrections Registry
>   • [docs/SECURITY.md §5.36](docs/SECURITY.md) — v1.5.0 companion install security model
>   • [docs/SECURITY.md §14.34](docs/SECURITY.md) — v1.5.0 companion install flow audit
>   • [docs/ARCHITECTURE.md §3.11](docs/ARCHITECTURE.md) — companion install flow (narrative)
>   • [docs/ARCHITECTURE.md §5.8](docs/ARCHITECTURE.md) — install_app.sh contract
>   • [docs/ARCHITECTURE.md §4.13](docs/ARCHITECTURE.md) — v1.3.0 server-side refinements
>   • [docs/ARCHITECTURE.md §4.14](docs/ARCHITECTURE.md) — v1.5.0 backend additions
>   • [docs/API.md §6.1.16, §6.1.17](docs/API.md) — install_token, companion_app_state
>   • [docs/API.md §6.2.14, §6.2.15](docs/API.md) — install/uninstall endpoints
>   • [docs/BACKUP.md](docs/BACKUP.md) — backup system reference (v1.2.0 + v1.3.0 rotation semantics)
>   • [docs/EMERGENCY.md](docs/EMERGENCY.md) — emergency recovery guide
>   • [CHANGELOG.md](CHANGELOG.md) — version history (v1.0.0 → v1.5.0)
>   • [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) — companion app source

> **v1.5.0 changes**:
>   • Version bumped from v1.4.0 to v1.5.0.
>   • **No new audit corrections** — v1.5.0 is a feature release.
>     The Audit Corrections Registry remains at **#33** (the last
>     entry from v1.0.0). The v1.5.0 additions are documented as
>     feature additions and code-review corrections — not as audit
>     corrections. See `docs/SECURITY.md` §17.4 for the registry
>     distinction.
>   • **Companion app one-tap root install** — the WebUI install
>     button now opens an install-method modal (IDX-24) offering
>     three actions (local root install / GitHub page / direct
>     APK download). The local path runs `proxy/install_app.sh`,
>     a 5-level `pm install` cascade. **Full security model**:
>     `docs/SECURITY.md` §5.36.
>   • **One-shot CSRF install token (60 s TTL)** — the
>     `POST /api/install_companion_app` endpoint requires a
>     single-use token issued by `GET /api?action=install_token`.
>     Constant-time comparison via `subtle.ConstantTimeCompare`.
>     Tokens are stored in-memory and consumed on first use.
>   • **Per-IP install rate limit (5 failed attempts / 15 min)** —
>     separate from the existing login rate limiter. Uses a
>     dedicated `installAttempts` map.
>   • **SELinux staging — `setenforce 0` is NEVER called.** The
>     APK is copied to `/data/local/tmp/dnscrypt-companion.apk`
>     (context `shell_data_file`) so that `system_server` can
>     read it. The staged copy is removed on every catchable
>     exit path via a three-way `EXIT / INT / TERM` trap
>     (CIA-DEF-03).
>   • **Play Protect temporary disable + trap-based restore** —
>     the package verifier is disabled for the duration of the
>     cascade and restored on any catchable exit path. The
>     cascade is bounded by a **75-second wall-clock deadline**
>     (V15-CODE-05), strictly less than the server-side 90-second
>     `INSTALL_TIMEOUT`, so the trap always fires before the
>     parent process kills the script. The trap restores the
>     **exact captured value** of `package_verifier_enable`
>     (V15-CODE-07), not a hardcoded `1`.
>   • **Companion APK mirror (best-effort)** — `customize.sh
>     §[10c]` mirrors the APK + `.sha256` to
>     `/sdcard/dnscrypt-webui-backup/apk/`. The mirror survives
>     uninstall and is preserved by `rotate_backups()` (two
>     independent protections: no `.manifest.json`, explicit
>     `case` skip). See `docs/SECURITY.md` §5.36.9.
>   • **CSH-22 packaging fix** — `install_app.sh` is now
>     extracted by `customize.sh §[9]` and validated in §[10].
>     Before CSH-22, the file was packaged but never extracted,
>     so `getInstallScript()` resolved a non-existent path and
>     every install attempt returned `reason=script_not_found`.
>   • **Frontend state fixes** (client-side only, no API
>     impact): IDX-23 (companion button survives language
>     toggles), IDX-23b (status card updates instantly), IDX-24
>     (install-method modal), IDX-25 (Dashboard section-nav),
>     IDX-25a (Dashboard centered hint), IDX-429 (rate-limit
>     message), IDX-401-DISTINCT (install-family 401 suppresses
>     the generic session-expired modal), DASH-REFRESH-01,
>     DASH-SESSION-RETRY-01, DASH-HINT-01, DASH-HINT-02,
>     ICON-512-SAFEZONE-01 (shield fits W3C safe circle).
>   • **Backend code-review corrections** (main.go):
>     MAIN-02 (getCompanionState three-phase read),
>     MAIN-03 (proper HTTP status 401/403/429),
>     MAIN-04 (bounded stderr via limitedBuffer),
>     MAIN-05 (installAttempts GC),
>     MAIN-CACHE-01 (companion state cache invalidated),
>     MAIN-REENT-01 (logger three-layer split — eliminates a
>     latent deadlock on log-rotation failure),
>     MAIN-PORTCACHE-01 (30 s TTL port cache),
>     MAIN-DEADLOCALHOST-01 (isLocalRequest dead branch
>     removed),
>     MAIN-APPENDHASH-01 (appendDenylist hash source aligned).
>   • **All v1.0.0 / v1.1.0 / v1.2.0 / v1.3.0 / v1.4.0 security
>     fixes remain in place.**

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • **No new audit corrections** — v1.4.0 is an integration
>     release. The Audit Corrections Registry remains at **#33**.
>   • **CodeQL `go/path-injection` fix** — Two alerts (#1, #2) in
>     `removeModule` (proxy/main.go) were closed by routing the
>     caller-provided path through `filepath.Base()` and rebuilding
>     the final path from the trusted `MODULES_DIR` constant.
>   • **Companion Android app integration** — a native WebView
>     wrapper (~3 MB) is bundled into the module ZIP as an
>     **OPTIONAL** asset at `web/app-debug.apk`. Served publicly
>     at `GET /app-debug.apk` (no auth required, no telemetry).
>   • **iOS PWA logic removed** — Android-only project.
>   • **All previous security fixes remain in place.**

> **v1.3.0 changes**:
>   • Version bumped from v1.2.0 to v1.3.0.
>   • **No new audit corrections** — v1.3.0 is a feature release.
>   • **PWA install button** — dynamic, browser-adaptive. No new
>     attack surface.
>   • **Live status LED** — pure CSS + JS, no network calls.
>   • **DNS auto-start after boot** — critical fix in `service.sh`,
>     closing a boot race. Uses the existing `X-Watchdog-Token`.
>   • **Server-side refinements to the backup layer** —
>     SNAP-MANIFEST + SNAP-MTIME in `main.go:buildBackupInfo()`,
>     and ROT-MANIFEST + ROT-MTIME + ROT-PROTECT in
>     `functions.sh:rotate_backups()`. See
>     `docs/ARCHITECTURE.md` §4.13.2.

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **No new audit corrections** — v1.2.0 is a data-preservation
>     release. The Audit Corrections Registry remains at **#33**.
>   • **New §5.31** (`docs/SECURITY.md`) — Data Preservation
>     Security Model.
>   • **New §5.32** (`docs/SECURITY.md`) — Correctness Fixes
>     (FIX-1, FIX-2).
>   • **New §5.33** (`docs/SECURITY.md`) — Watchdog Token
>     (WD-TOKEN).
>   • **New §14.25–§14.30** (`docs/SECURITY.md`) — six new audit
>     checklist sections.
>   • **Breaking change for callers of `POST /api/append_denylist`** —
>     the endpoint now requires a `content` parameter.
>   • **Global edition — English default + Arabic toggle**: client-side only.

> **v1.4.0 — POST-AUDIT FIXES (this revision)**:
>   A post-audit review of this file against the v1.3.0 / v1.4.0
>   code identified the following documentation gaps. All are
>   addressed in-place; no version bump.
>
>   🔧 **HARD-SECROOT-01** — **`Last updated` corrected.**
>   🔧 **HARD-SECROOT-02** — **`v1.3.0` block extended.**
>   🟢 **HARD-SECROOT-03** — **Cross-references section added.**
>   🔧 **HARD-SECROOT-04** — **"Key Security Fixes (v1.3.0)" extended.**
>   🟡 **HARD-SECROOT-05** — **"Applied Protections" table updated.**
>   🟡 **HARD-SECROOT-06** — **"In Scope" section extended.**
>   🟡 **HARD-SECROOT-07** — **"Notes" section extended.**

> **v1.5.0 — POST-AUDIT FIXES (this revision)**:
>   A post-audit review of this file against the v1.5.0 code
>   identified the following documentation gaps. All are
>   addressed in-place; no version bump.
>
>   🔧 **HARD-SECROOT-08** — **v1.5.0 changes block added.** The
>     header now documents the v1.5.0 feature additions (companion
>     install flow, 4 endpoints, one-shot CSRF token, per-IP rate
>     limit, SELinux staging, Play Protect trap, cascade deadline)
>     and the frontend/backend corrections, with explicit pointers
>     to `docs/SECURITY.md` §5.36 (full security model) and §14.34
>     (install flow audit).
>
>   🔧 **HARD-SECROOT-09** — **"In Scope" extended.** The Backend
>     section now includes the 4 v1.5.0 endpoints, the install
>     token, and the install rate limiter. The Shell Scripts
>     section now includes `proxy/install_app.sh`.
>
>   🟡 **HARD-SECROOT-10** — **"Applied Protections" table
>     extended.** New rows for v1.5.0: one-shot CSRF token,
>     per-IP install rate limit, SELinux staging, Play Protect
>     trap with cascade deadline.
>
>   🟢 **HARD-SECROOT-11** — **"Key Security Fixes (v1.5.0)"
>     section added.** Documents the companion install security
>     model briefly, with cross-references to `docs/SECURITY.md`
>     §5.36.
>
>   🟢 **HARD-SECROOT-12** — **"Related Documentation" table
>     extended.** Two new rows: `docs/SECURITY.md §5.36` and
>     `docs/SECURITY.md §14.34`.
>
>   🟡 **HARD-SECROOT-13** — **"Notes" section updated.** The
>     forward-looking `(v1.5.0 or later)` reference has been
>     replaced with an explicit statement that v1.5.0 shipped
>     without extending the registry.
>
>   🔧 **HARD-SECROOT-DATE** — `Last updated` bumped
>     2026-10-08 → 2026-10-13. No functional change.

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
v1.5.0 (or any version)

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
  - Rate limiting (login, Basic Auth, **install (v1.5.0)**)
  - CSRF protection
  - Path traversal
  - Input validation
  - Firewall (Custom Chains)
  - Concurrency (mutexes)
  - Dynamic memory limit (`debug.SetMemoryLimit`, v1.1.0 — MEM-1)
  - **Pre-critical backups** (`createAutoBackup` + `backupMu`, v1.2.0)
  - **Watchdog token** (`X-Watchdog-Token`, v1.2.0)
  - **Snapshot detection and rotation semantics** (v1.3.0)
  - **`removeModule` path sanitization** (v1.4.0)
  - **Static companion APK route** (`GET /app-debug.apk`, v1.4.0)
  - **v1.5.0 — Companion install endpoints**:
    - `POST /api/install_companion_app` — root install (CSRF + rate limit)
    - `POST /api/uninstall_companion_app` — reserved for future UI
    - `GET /api?action=install_token` — one-shot CSRF token (60 s TTL)
    - `GET /api?action=companion_app_state` — install state (30 s cache)
  - **v1.5.0 — Install token store** (`installTokens` map): 64-hex tokens, in-memory, single-use, constant-time comparison
  - **v1.5.0 — Install rate limiter** (`installAttempts` map): 5 failed attempts / 15 min per IP
  - **v1.5.0 — Companion state cache** (`companionStateCache`): 30 s TTL, invalidated after install/uninstall
  - **v1.5.0 — Logger three-layer split** (`logWithLevel` / `logLocked` / `writeLocked`) — eliminates a latent deadlock on log-rotation failure (MAIN-REENT-01)

- **Shell scripts** (`proxy/*.sh`):
  - Lifecycle (boot / uninstall)
  - Watchdog
  - Permissions
  - `shellQuote`-protected paths (extended in v1.1.0 — MEM-2)
  - **Backup helpers** (v1.2.0)
  - **Rotation hardening** (v1.3.0 ROT-* semantics)
  - **SELinux context preservation** (v1.2.0)
  - **DNS auto-start after boot** (v1.3.0)
  - **v1.5.0 — Companion install script** (`proxy/install_app.sh`):
    - 5-level `pm install` cascade
    - SELinux staging to `/data/local/tmp/dnscrypt-companion.apk` — **`setenforce 0` is never called**
    - Play Protect temporary disable + trap-based restore (`EXIT` / `INT` / `TERM`, exit codes 130 / 143)
    - 75-second cascade deadline (`CASCADE_DEADLINE_SECONDS`)
    - SHA256 verification (advisory if `.sha256` absent)
    - AR + EN error translation
  - **v1.5.0 — APK mirror** (`customize.sh §[10c]`): copies the companion APK + `.sha256` to `$PERSISTENT_BACKUP/apk/` (best-effort). Preserved by `rotate_backups()` (no `.manifest.json`, explicit `case` skip).

- **Frontend** (`web/`):
  - XSS
  - CSRF
  - Content Security Policy
  - Offline page behavior
  - **Bilingual language toggle** (v1.2.0)
  - **PWA install button** (v1.3.0; converted to `<a download>` in v1.4.0; converted to install-method modal in v1.5.0)
  - **Companion APK download** (v1.4.0)
  - **v1.5.0 install-method modal (IDX-24)** — three paths (local / GitHub page / GitHub direct)

- **Persistent backup directory** (v1.2.0, rotation hardened in v1.3.0):
  - `/sdcard/dnscrypt-webui-backup/` — permissions, rotation, transaction state files, SHA256 manifest
  - `txn-*` / `orphan-txn-*` — transaction handling
  - `.last_stable` pointer — ROT-PROTECT target (v1.3.0)
  - Newest install snapshot — ROT-PROTECT target (v1.3.0)
  - **`apk/` (v1.5.0)** — companion APK mirror; preserved by rotation
  - `.upgrade_history.json` — upgrade log

### Out of Scope

- **dnscrypt-proxy** itself (upstream) → report [here](https://github.com/DNSCrypt/dnscrypt-proxy/security)
- **Magisk / KernelSU / APatch** → report to the relevant maintainer
- **Android OS** → report to Google
- **HaGeZi blocklists** → report [here](https://github.com/hagezi/dns-blocklists/issues)
- **dnscrypt-proxy-app** (companion app) → report to the companion
  repo's issue tracker:
  https://github.com/gasciljh/dnscrypt-proxy-app/issues
- **Android PackageManager signature verification** — performed by
  the OS at install time, not by this project.

---

## Recognition

- **Security Researcher** badge in [`docs/HALL_OF_FAME.md`](docs/HALL_OF_FAME.md)
- Your name in the release that fixes the vulnerability
- **Auditor** badge for each accepted Audit Correction
- **Memory Architect** badge (v1.1.0) for contributors who test the
  dynamic memory limit across multiple RAM tiers
- **Data Guardian** badge (v1.2.0) for contributors who test the
  backup/restore system across devices, root solutions, and
  upgrade scenarios

---

## Related Documentation

| Document | Content |
|---|---|
| **[docs/SECURITY.md](docs/SECURITY.md)** | Full policy + Threat Model + Audit Corrections Registry |
| [docs/SECURITY.md §5.30](docs/SECURITY.md) | v1.1.0 runtime improvements (MEM-1 / MEM-2 / MEM-3) |
| [docs/SECURITY.md §5.31](docs/SECURITY.md) | **v1.2.0 Data Preservation Security Model** |
| [docs/SECURITY.md §5.32](docs/SECURITY.md) | **v1.2.0 Correctness Fixes (FIX-1, FIX-2)** |
| [docs/SECURITY.md §5.33](docs/SECURITY.md) | **v1.2.0 Watchdog Token (WD-TOKEN)** |
| [docs/SECURITY.md §5.34](docs/SECURITY.md) | **v1.4.0 CodeQL `go/path-injection` Fix** |
| [docs/SECURITY.md §5.35](docs/SECURITY.md) | **v1.4.0 iOS PWA Removal + Companion APK Route** |
| **[docs/SECURITY.md §5.36](docs/SECURITY.md)** | **v1.5.0 Companion App Install Security Model** |
| **[docs/SECURITY.md §14.34](docs/SECURITY.md)** | **v1.5.0 Companion Install Flow Audit** |
| [docs/SECURITY.md §17.1](docs/SECURITY.md) | v1.1.0 improvements registry |
| [docs/SECURITY.md §17.2](docs/SECURITY.md) | v1.2.0 runtime additions registry |
| [docs/SECURITY.md §17.3](docs/SECURITY.md) | v1.2.0 post-audit corrections |
| [docs/SECURITY.md §17.4](docs/SECURITY.md) | v1.3.0 + v1.4.0 + v1.5.0 additions (registry unchanged at #33) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architecture + Trade-offs |
| **[docs/ARCHITECTURE.md §3.11](docs/ARCHITECTURE.md)** | **v1.5.0 companion install flow (narrative)** |
| **[docs/ARCHITECTURE.md §5.8](docs/ARCHITECTURE.md)** | **v1.5.0 install_app.sh contract** |
| **[docs/ARCHITECTURE.md §4.14](docs/ARCHITECTURE.md)** | **v1.5.0 backend additions** |
| **[docs/ARCHITECTURE.md §4.13](docs/ARCHITECTURE.md)** | **v1.3.0 server-side refinements (SNAP-* / ROT-*)** |
| [docs/ARCHITECTURE.md §11.31–§11.34](docs/ARCHITECTURE.md) | v1.3.0 trade-offs |
| [docs/ARCHITECTURE.md §11.43–§11.51](docs/ARCHITECTURE.md) | v1.5.0 trade-offs |
| [docs/API.md §6.1.16, §6.1.17](docs/API.md) | **v1.5.0 install_token, companion_app_state** |
| [docs/API.md §6.2.14, §6.2.15](docs/API.md) | **v1.5.0 install/uninstall endpoints** |
| [docs/BACKUP.md](docs/BACKUP.md) | Backup system reference (v1.2.0 + v1.3.0 rotation semantics) |
| [docs/EMERGENCY.md](docs/EMERGENCY.md) | Emergency recovery (v1.2.0) |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Diagnostics + memory-limit + backup debugging |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Contribution guide |
| [CHANGELOG.md](CHANGELOG.md) | Version history (v1.0.0 → v1.5.0) |
| [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) | Companion app source repository |

---

## Applied Protections (Summary)

| Category | Measures |
|---|---|
| **Authentication** | Constant-time comparison, Rate limiting (5/15 min), Login POST-only, Cookie-only sessions, Watchdog token (`X-Watchdog-Token`, v1.2.0), **one-shot CSRF install token (v1.5.0)** |
| **Sessions** | HttpOnly, SameSite=Lax, Secure (conditional), Session GC, Auth cache 60 s |
| **Headers** | Strict CSP, X-Frame-Options, nosniff, COOP, CORP |
| **Input** | MaxBytesReader (5 MB), Path whitelist, Atomic writes, `hasEndpoint` (exact match), `readConfPort` (range check), `shellQuote` (shell injection protection), `filepath.Base()` sanitization in `removeModule` (v1.4.0) |
| **DoS** | SSE Write Deadline (30 s), Rate limiting, limitedBuffer, dynamic per-profile memory limit (v1.1.0), bounded backup disk usage (v1.2.0), **install rate limit (5/15 min, v1.5.0)**, **75-second cascade deadline (v1.5.0)** |
| **Health endpoints** | `/healthz` public, `/readyz` localhost-only |
| **Firewall** | Custom Chains (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`), no orphans |
| **State** | STATUS_FILE = User Intent, reliable Watchdog, `rebuildMu`, `backupMu` (v1.2.0), **`installTokens` / `installAttempts` / `companionStateCache` (v1.5.0)** |
| **IPv6** | Safe `getClientIP`, `[::1]` support |
| **Ports** | `runtime_info` returns actual ports; `MONITORING_UI_PORT` constant in metrics handler (v1.1.0) |
| **Memory** | Per-profile `debug.SetMemoryLimit` (v1.1.0); `profile_key` + `memory_limit_mb` exposed |
| **Offline page** | CSP removed from `offline.html` (v1.1.0 — no real attack surface) |
| **Data preservation (v1.2.0)** | 10 defensive layers, persistent backup directory with `0700`/`0600` permissions, SHA256 integrity (advisory), transactional install with rollback, recovery mode, SELinux context preservation |
| **Backup rotation hardening (v1.3.0)** | SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME + ROT-PROTECT |
| **Boot reliability (v1.3.0)** | DNS auto-start after boot via direct API call in `service.sh` |
| **Static asset safety (v1.4.0)** | Companion APK served as a static file |
| **Install security (v1.5.0)** | One-shot CSRF token (60 s, single-use), per-IP rate limit (5/15 min), **SELinux staging — never `setenforce 0`**, Play Protect temporary disable + trap restore, 75 s cascade deadline, SHA256 advisory verification, AR/EN error translation |

---

## Key Security Fixes (v1.5.0)

### Companion app install security (v1.5.0)

- **Reference**: `docs/SECURITY.md` §5.36 (full model), §14.34 (audit checklist).
- **One-shot CSRF token** — `POST /api/install_companion_app` requires a
  single-use token from `GET /api?action=install_token`. 64-hex
  (32 random bytes from `crypto/rand`), 60 s TTL, consumed on first
  use, constant-time comparison via `subtle.ConstantTimeCompare`.
- **Per-IP rate limit** — 5 failed attempts / 15 min, separate from
  the login rate limiter.
- **Localhost-only gate** — `isLocalRequest()` required.
- **SELinux staging** — the APK is copied to
  `/data/local/tmp/dnscrypt-companion.apk` (context
  `shell_data_file`). **`setenforce 0` is never called.**
- **Play Protect** — temporarily disabled for the cascade and restored
  via a three-way `EXIT` / `INT` / `TERM` trap (CIA-DEF-03). INT
  exits 130, TERM exits 143. The trap restores the exact captured
  value of `package_verifier_enable` (V15-CODE-07).
- **75-second cascade deadline** (V15-CODE-05) — strictly less than
  the 90-second `INSTALL_TIMEOUT`, so the trap always fires before
  the parent kills the script.
- **SHA256 verification** — if `web/app-debug.apk.sha256` is present,
  the APK hash is verified before any install strategy. Advisory
  otherwise.
- **CSH-22 packaging fix** — `install_app.sh` extraction + path
  constant alignment.

### Backend code-review corrections (v1.5.0)

- **MAIN-REENT-01** — logger three-layer split (`logWithLevel` /
  `logLocked` / `writeLocked`); the rotation-failure path no longer
  re-enters `logWithLevel`. Eliminates a latent deadlock on a full
  or read-only `/data/local/tmp`.
- **MAIN-PORTCACHE-01** — 30 s TTL cache for `getWebUIPort` /
  `getDashboardPort`. Response shape unchanged.
- **MAIN-DEADLOCALHOST-01** — `isLocalRequest()` dead branch removed.
- **MAIN-APPENDHASH-01** — `appendDenylist` hash source aligned with
  `saveDenylist`. Removes a spurious `409 conflict` on externally
  modified `denylist.txt`.
- **MAIN-02..05, MAIN-CACHE-01** — see `docs/SECURITY.md` §5.36 and
  `docs/ARCHITECTURE.md` §4.14.

---

## Key Security Fixes (v1.4.0)

### CodeQL `go/path-injection` hardening (v1.4.0)

- **Two CodeQL alerts (#1, #2) closed in `removeModule`** —
  `filepath.Base()` sanitization + trusted-base path construction.
- **No API contract change** — same path, method, auth, response.

### Companion APK integration (v1.4.0)

- Static file served publicly at `GET /app-debug.apk`. No server-side
  logic executes to serve it. 404 when absent.
- WebUI install button converted from a JavaScript-driven modal to a
  direct `<a download>` link.
- iOS PWA logic removed.

---

## Key Security Fixes (v1.3.0)

### Backup rotation hardening (v1.3.0)

- **SNAP-MANIFEST** — `buildBackupInfo()` detects snapshots by
  `.manifest.json` presence.
- **SNAP-MTIME** — `last_backup_name` selected by mtime.
- **ROT-MANIFEST** + **ROT-MTIME** + **ROT-PROTECT** —
  `rotate_backups()` rewritten with the same detection + sort +
  protected `.last_stable` + newest install snapshot.

### DNS auto-start after boot (v1.3.0)

- Boot race in `service.sh` closed: bounded wait for WebUI + direct
  `POST /api/ensure_running_service` with `X-Watchdog-Token`.

---

## Key Security Fixes (v1.2.0)

### Data preservation (v1.2.0)

- **Silent data-loss bug in v1.1.0** fixed by the 10 defensive layers.
- **Persistent backup directory** at `/sdcard/dnscrypt-webui-backup/`.

### Watchdog token (v1.2.0 — WD-TOKEN)

- CSRF hole on `POST /api/ensure_running_service` closed.
- Constant-time comparison. Fail-closed.

### Correctness fixes (v1.2.0 — FIX-1, FIX-2)

- **FIX-1** — recovery-mode snapshot-and-reapply.
- **FIX-2** — Service Worker update-banner.

### Breaking change (v1.2.0)

- `POST /api/append_denylist` now requires a `content` parameter.

### v1.1.0 runtime improvements (carried forward)

- **MEM-1** — Dynamic memory limit per profile.
- **MEM-2** — Extended `shellQuote` character set.
- **MEM-3** — `MONITORING_UI_PORT` in metrics handler.

### v1.1.0 critical fix (carried forward)

- **`web/offline.html`** — Restrictive CSP meta removed.

---

## Key Security Fixes (v1.0.0)

### Critical

- **Login POST-only** — CSRF protection.
- **`/readyz` localhost-only**.
- **`shellQuote()`** — shell injection protection.

### Important

- **`hasEndpoint()`** — exact path matching.
- **`readConfPort` range check**.
- **Basic Auth rate limiting**.

### Improvements

- **`rebuildMu` mutex**.
- **`runtime_info` ports**.
- **Auth cache (60 s)**.
- **Preserve settings on upgrade**.
- **Custom Chains** — `DNSCRYPT_OUT` / `DNSCRYPT_OUT6`.

---

## Notes

- Do **not** share vulnerability details publicly before the fix.
- **Critical vulnerabilities** may warrant a **hotfix** release.
- **Responsible disclosure** is always appreciated.
- Read [docs/SECURITY.md](docs/SECURITY.md) for full details.
- **Audit Corrections Registry remains at #33** — v1.2.0, v1.3.0,
  v1.4.0, and v1.5.0 do not extend it. New audit corrections will
  resume at **#34** in a future release. See `docs/SECURITY.md` §17.
- **v1.3.0, v1.4.0, and v1.5.0 do not introduce new attack vectors.**
  All v1.0.0, v1.1.0, and v1.2.0 security fixes remain in place.
- **v1.5.0 additions** are strictly defensive at the install-flow
  level: one-shot CSRF token, per-IP rate limit, SELinux staging
  (never `setenforce 0`), Play Protect trap with cascade deadline,
  SHA256 advisory verification, and the three-layer logger split
  (MAIN-REENT-01). Full model in `docs/SECURITY.md` §5.36.
- **The v1.2.0 rotation description ("sorted by directory name") is
  superseded.** The authoritative current description is the v1.3.0
  ROT-MANIFEST + ROT-MTIME + ROT-PROTECT semantics.
- **`web/offline.html` no longer has a CSP meta.** If you add dynamic
  content to that page in the future, reintroduce CSP — preferably
  with a nonce rather than `'unsafe-inline'`.
- **`POST /api/append_denylist` now requires a `content` parameter.**
- **Persistent backup directory**: `/sdcard/dnscrypt-webui-backup/`
  is owned by root with mode `0700` on directories and `0600` on
  files. A malicious root app can still read it.
- **Companion APK** is served publicly at `GET /app-debug.apk`. It is
  a static file with no telemetry.
- **Companion install** requires root and grants the WebUI a one-tap
  path to run `pm install`. The one-shot CSRF token and the per-IP
  rate limit are the primary controls; see `docs/SECURITY.md` §5.36.
- **`setenforce 0` is never called by this project.** The companion
  install uses SELinux staging instead. This is a hard invariant
  enforced by `ci.yml` (the "Verify companion install script
  (v1.5.0)" step fails the build if `setenforce 0` appears in any
  executable line of `install_app.sh`; comment lines that document
  the prohibition are filtered out via `grep -v '^#'`).

---

## Contact

- **Maintainer**: [@gasciljh](https://github.com/gasciljh)
- **GitHub**: [Report a vulnerability](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

---

*Last updated: 2026-10-13*
*Version: v1.5.0*
*Author: gasciljh*
