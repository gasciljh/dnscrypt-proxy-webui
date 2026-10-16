# Security Policy

**DNSCrypt Smart Filter** — Security policy and vulnerability disclosure.

> **Full document**: this is a summary page. The complete policy with the
> full threat model is available at:
> **[docs/SECURITY.md](../docs/SECURITY.md)**

**Version**: v1.4.0 (Global Edition)
**Last updated**: 2026-10-08
**Author**: gasciljh
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui

> **Identifier inventory in this file (7 total)**:
>   • HARD-GHSEC-01 (`Last updated` correction — v1.4.0)
>   • HARD-GHSEC-02 (v1.3.0 block extended with SNAP-* / ROT-* — v1.4.0)
>   • HARD-GHSEC-03 (Key Security Fixes v1.3.0 — rotation section — v1.4.0)
>   • HARD-GHSEC-04 (Applied Protections table — v1.3.0 row — v1.4.0)
>   • HARD-GHSEC-05 (In Scope — v1.3.0 rotation semantics — v1.4.0)
>   • HARD-GHSEC-06 (Notes — v1.3.0 / v1.4.0 clarification — v1.4.0)
>   • HARD-GHSEC-07 (Cross-references + Related Documents — v1.4.0)
>
> **Cross-references**:
>   • [docs/SECURITY.md](../docs/SECURITY.md) — full policy + Audit Corrections Registry
>   • [docs/ARCHITECTURE.md §4.13](../docs/ARCHITECTURE.md) — v1.3.0 server-side refinements (authoritative)
>   • [docs/BACKUP.md](../docs/BACKUP.md) — backup system reference (v1.2.0 + v1.3.0 rotation semantics)
>   • [docs/EMERGENCY.md](../docs/EMERGENCY.md) — emergency recovery guide
>   • [CHANGELOG.md](../CHANGELOG.md) — version history (v1.0.0 → v1.4.0)
>   • [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) — companion app source

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • **No new audit corrections** — v1.4.0 is an integration
>     release. The Audit Corrections Registry remains at **#33**
>     (the last entry from v1.0.0).
>   • **CodeQL `go/path-injection` fix** — Two alerts (#1, #2) in
>     `removeModule` (`proxy/main.go`) were closed by routing the
>     caller-provided path through `filepath.Base()` and rebuilding
>     the final path from the trusted `MODULES_DIR` constant. No
>     user-controlled data reaches any path expression.
>   • **Companion Android app integration** — a native WebView
>     wrapper (~3 MB) is bundled into the module ZIP as an
>     **OPTIONAL** asset at `web/app-debug.apk`. It is served
>     publicly at `GET /app-debug.apk` (no auth required, no
>     telemetry, static file only).
>   • **iOS PWA logic removed** — Android-only project.
>   • **All v1.0.0 / v1.1.0 / v1.2.0 / v1.3.0 security fixes
>     remain in place.**

> **v1.3.0 changes**:
>   • Version bumped from v1.2.0 to v1.3.0.
>   • **No new audit corrections** — v1.3.0 is a feature release.
>     The Audit Corrections Registry remains at **#33**.
>   • **DNS auto-start after boot (critical fix)** — closes a race
>     in `service.sh` where the DNS engine did not start
>     automatically after reboot. Uses the same
>     `X-Watchdog-Token` introduced in v1.2.0. No new auth surface.
>   • **PWA install button** — dynamic per-browser behavior. No new
>     attack surface (operated on static strings only; converted
>     to a direct `<a download>` in v1.4.0).
>   • **Live status LED** — pure CSS + JS, no new network calls.
>   • **Server-side refinements to the backup layer** — the v1.3.0
>     release ALSO refined the snapshot-detection and rotation
>     semantics that underpin the persistent backup directory.
>     Three identifiers document the change (also used in
>     `CHANGELOG.md` [v1.3.0] and `docs/ARCHITECTURE.md` §4.13):
>
>       🔧 **SNAP-MANIFEST** — `main.go:buildBackupInfo()` now
>         detects a snapshot by the presence of a `.manifest.json`
>         file, not by the v1.2.0 name pattern
>         (`^[0-9]{8}-[0-9]{6}-`). This makes custom-named
>         snapshots visible to the API and to rotation.
>
>       🔧 **SNAP-MTIME** — `buildBackupInfo()` now selects
>         `last_backup_name` by **mtime** (descending), with a
>         name-based fallback when `DirEntry.Info()` fails. This
>         supersedes the v1.2.0 BUG-3 lexicographic-name rule.
>
>       🔧 **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** —
>         `functions.sh:rotate_backups()` was rewritten with the
>         same manifest-based detection, the same mtime sort, and
>         two additional protected targets on top of the
>         21-newest window:
>           • the `.last_stable` recovery pointer;
>           • the newest install snapshot (name matching
>             `-v<digit>`).
>
>     **Security rationale**: without ROT-PROTECT, the 21-newest
>     window could silently evict the exact snapshot that recovery
>     mode or rollback depends on — a security-relevant outcome for
>     a project whose primary goal is reliable, protected DNS. See
>     `docs/ARCHITECTURE.md` §4.13.2 and §11.31–§11.33.
>
>   • **Parallel application** — the same SNAP-MANIFEST /
>     SNAP-MTIME / ROT-* semantics were applied to `watchdog.sh`
>     (§[5b] snapshot counter), `status.sh` (`_list_snapshots`),
>     `customize.sh` (`rotate_backups`), `action.sh`
>     (`_inline_list_snapshots` + `_inline_rotate_backups` +
>     `_inline_backup_summary`), and `uninstall.sh` (§[5b]
>     `BACKUP_COUNT` / `BACKUP_LAST_NAME`). Every consumer of the
>     persistent backup directory now agrees on which snapshots
>     exist and which is the newest.
>
>   • **All v1.0.0 / v1.1.0 / v1.2.0 security fixes remain in
>     place.**

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **No new audit corrections** — v1.2.0 is a data-preservation
>     release. The Audit Corrections Registry remains at **#33** (the
>     last entry from v1.0.0).
>   • **New §5.31** (`docs/SECURITY.md`) — Data Preservation Security
>     Model.
>   • **New §5.32** (`docs/SECURITY.md`) — Correctness Fixes
>     (FIX-1, FIX-2). Neither is an exploitable vulnerability.
>   • **New §5.33** (`docs/SECURITY.md`) — Watchdog Token
>     (WD-TOKEN).
>   • **New §14.25–§14.30** (`docs/SECURITY.md`) — six new audit
>     checklist sections.
>   • **Breaking change for callers of `POST /api/append_denylist`** —
>     the endpoint now requires a `content` parameter.
>   • **Global edition — English default + Arabic toggle**: the WebUI
>     ships with English as the default language and an in-page
>     toggle to switch to Arabic. **No API impact**.
>   • **Note on rotation semantics (corrected in this revision)**:
>     The v1.2.0 description of the backup rotation — "sorted by
>     directory name" — was superseded in v1.3.0 by the
>     **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** semantics
>     documented in the v1.3.0 block above. The v1.2.0 mechanism
>     is retained here only as historical context. The
>     **authoritative** current description lives in
>     `docs/ARCHITECTURE.md` §4.13.2 and `docs/BACKUP.md` §6.5.

> **v1.2.0 (Global Edition) — Corrections in this revision**:
>   • 🔧 **FIX-1 description** — This summary now describes FIX-1
>     as a **snapshot-and-reapply** strategy (`§[8a]` + `§[9]` +
>     `§[9b2]`), matching the shipped code. See
>     `docs/SECURITY.md` §5.32.1 for the full analysis.

> **v1.4.0 — POST-AUDIT FIXES (this revision)**:
>   A post-audit review of this file against the v1.3.0 / v1.4.0
>   code identified the following documentation gaps. All are
>   addressed in-place; no version bump.
>
>   🔧 **HARD-GHSEC-01** — `Last updated` corrected. The header
>     and footer previously said `2026-10-06` (the v1.4.0 release
>     date, not the v1.4.0 file-editing date). Both now read
>     `2026-10-08`, matching every other file in the v1.4.0
>     module.
>
>   🔧 **HARD-GHSEC-02** — `v1.3.0` block extended. The previous
>     block mentioned only the client-side changes (PWA install
>     button, live status LED) and the DNS auto-start fix. It did
>     NOT mention the **server-side refinements** to snapshot
>     detection and rotation (SNAP-MANIFEST, SNAP-MTIME,
>     ROT-MANIFEST, ROT-MTIME, ROT-PROTECT) that are central to
>     the backup-layer security model. The v1.3.0 block above now
>     documents them, with an explicit security rationale for
>     ROT-PROTECT.
>
>   🔧 **HARD-GHSEC-03** — `Key Security Fixes (v1.3.0)` section
>     extended. A new subsection documents the server-side
>     rotation refinements and their security rationale. The
>     previous version covered only the DNS auto-start fix, the
>     PWA install button, and the status LED.
>
>   🟡 **HARD-GHSEC-04** — `Applied Protections` table updated.
>     A new row documents the v1.3.0 rotation hardening
>     (SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME +
>     ROT-PROTECT).
>
>   🟡 **HARD-GHSEC-05** — `In Scope` sections extended. The
>     Backend, Shell scripts, and Persistent backup directory
>     entries now mention the v1.3.0 rotation semantics, so a
>     reporter knows rotation behavior is in scope for security
>     review.
>
>   🟡 **HARD-GHSEC-06** — `Notes` section extended. A new bullet
>     clarifies that v1.3.0 and v1.4.0 do not introduce new attack
>     vectors, and that the v1.2.0 rotation documentation is
>     superseded by the v1.3.0 semantics.
>
>   🟢 **HARD-GHSEC-07** — `Cross-references` block added at the
>     top of the file, and the `Related Documentation` table
>     extended with `docs/ARCHITECTURE.md` §4.13 (the authoritative
>     source for the v1.3.0 rotation semantics), `docs/SECURITY.md`
>     §5.34 and §5.35 (the v1.4.0 CodeQL fix and companion APK),
>     and `docs/SECURITY.md` §17.4 (the v1.3.0 + v1.4.0 additions
>     registry).

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
v1.4.0 (or any version)

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
  - **Snapshot detection and rotation semantics** (v1.3.0 —
    SNAP-MANIFEST + SNAP-MTIME in `buildBackupInfo`,
    ROT-MANIFEST + ROT-MTIME + ROT-PROTECT in
    `functions.sh:rotate_backups`)
  - **`removeModule` path sanitization** (`filepath.Base()` +
    `filepath.Join()`, v1.4.0)
  - **Static companion APK route** (`GET /app-debug.apk`, v1.4.0)

- **Shell scripts** (`proxy/*.sh`):
  - Lifecycle (boot / uninstall)
  - Watchdog
  - Permissions
  - `shellQuote`-protected paths (extended in v1.1.0 — MEM-2)
  - **Backup helpers** (v1.2.0)
  - **Rotation hardening** (v1.3.0 — ROT-MANIFEST + ROT-MTIME +
    ROT-PROTECT, mirrored in `customize.sh`, `action.sh`,
    `uninstall.sh`, `status.sh` (`_list_snapshots`), and
    `watchdog.sh` (§[5b]))
  - **SELinux context preservation** (v1.2.0)
  - **DNS auto-start after boot** (`service.sh` §[19], v1.3.0 —
    uses the same `X-Watchdog-Token` header as the watchdog)

- **Frontend** (`web/`):
  - XSS
  - CSRF
  - Content Security Policy
  - Offline page behavior (`offline.html`, v1.1.0 fix)
  - **Bilingual language toggle** (client-side only, v1.2.0)
  - **PWA install button** (dynamic per-browser, v1.3.0; converted
    to `<a download>` in v1.4.0)
  - **Companion APK download** (v1.4.0)

- **Persistent backup directory** (v1.2.0, rotation hardened in v1.3.0):
  - `/sdcard/dnscrypt-webui-backup/` — permissions, rotation,
    transaction state files, SHA256 manifest
  - `txn-*` / `orphan-txn-*` — transaction handling
  - `.last_stable` pointer — **ROT-PROTECT target (v1.3.0)**: never
    pruned by rotation
  - Newest install snapshot — **ROT-PROTECT target (v1.3.0)**: never
    pruned by rotation
  - `.upgrade_history.json` — upgrade log

### Out of Scope

- **dnscrypt-proxy** itself (upstream) → report [here](https://github.com/DNSCrypt/dnscrypt-proxy/security)
- **Magisk / KernelSU / APatch** → report to the relevant maintainer
- **Android OS** → report to Google
- **HaGeZi blocklists** → report [here](https://github.com/hagezi/dns-blocklists/issues)
- **dnscrypt-proxy-app** (companion app) → report to the companion
  repo's issue tracker:
  https://github.com/gasciljh/dnscrypt-proxy-app/issues

---

## Recognition

- **Security Researcher** badge in [`docs/HALL_OF_FAME.md`](../docs/HALL_OF_FAME.md)
- Your name in the release that fixes the vulnerability
- **Auditor** badge for each accepted Audit Correction
- **Memory Architect** badge (v1.1.0) for contributors who test the
  dynamic memory limit across multiple RAM tiers
- **Data Guardian** badge (v1.2.0) for contributors who test the
  backup/restore system across devices, root solutions, and
  upgrade scenarios — see
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
| [docs/SECURITY.md §5.34](../docs/SECURITY.md) | **v1.4.0 CodeQL `go/path-injection` Fix** |
| [docs/SECURITY.md §5.35](../docs/SECURITY.md) | **v1.4.0 iOS PWA Removal + Companion APK Route** |
| [docs/SECURITY.md §17.1](../docs/SECURITY.md) | v1.1.0 improvements registry |
| [docs/SECURITY.md §17.2](../docs/SECURITY.md) | v1.2.0 runtime additions registry |
| [docs/SECURITY.md §17.3](../docs/SECURITY.md) | v1.2.0 post-audit corrections |
| [docs/SECURITY.md §17.4](../docs/SECURITY.md) | **v1.3.0 + v1.4.0 additions (registry unchanged at #33)** |
| [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) | Architecture + Trade-offs (§3.10, §4.10) |
| **[docs/ARCHITECTURE.md §4.13](../docs/ARCHITECTURE.md)** | **v1.3.0 server-side refinements (SNAP-* / ROT-* — authoritative)** |
| [docs/ARCHITECTURE.md §11.31–§11.34](../docs/ARCHITECTURE.md) | v1.3.0 trade-offs (manifest, mtime, protections, boot-path) |
| [docs/BACKUP.md](../docs/BACKUP.md) | **Backup system reference (v1.2.0 + v1.3.0 rotation semantics)** |
| [docs/EMERGENCY.md](../docs/EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) | Diagnostics + memory-limit + backup debugging |
| [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md) | Contribution guide |
| [docs/API.md](../docs/API.md) | HTTP API Reference (§6.1.7) |
| [CHANGELOG.md](../CHANGELOG.md) | Version history (including v1.3.0 and v1.4.0) |

---

## Applied Protections (Summary)

| Category | Measures |
|---|---|
| **Authentication** | Constant-time comparison, Rate limiting (5/15 min), Login POST-only, Cookie-only sessions, **Watchdog token (`X-Watchdog-Token`, v1.2.0)** |
| **Sessions** | HttpOnly, SameSite=Lax, Secure (conditional), Session GC, Auth cache 60 s |
| **Headers** | Strict CSP, X-Frame-Options, nosniff, COOP, CORP |
| **Input** | MaxBytesReader (5 MB), Path whitelist, Atomic writes, `hasEndpoint` (exact match), `readConfPort` (range check), `shellQuote` (shell injection protection), **`filepath.Base()` sanitization in `removeModule` (v1.4.0)** |
| **DoS** | SSE Write Deadline (30 s), Rate limiting, limitedBuffer, dynamic per-profile memory limit (v1.1.0 — MEM-1), **bounded backup disk usage (v1.2.0)** |
| **Health endpoints** | `/healthz` public, `/readyz` localhost-only |
| **Firewall** | Custom Chains (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`), no orphans |
| **State** | STATUS_FILE = User Intent, reliable Watchdog, `rebuildMu` (serializes rebuildBlocklist), **`backupMu` (serializes pre-critical backups, v1.2.0)** |
| **IPv6** | Safe `getClientIP`, `[::1]` support |
| **Ports** | `runtime_info` returns actual ports, `MONITORING_UI_PORT` constant (v1.1.0 — MEM-3) |
| **Memory** | Per-profile `debug.SetMemoryLimit` (v1.1.0 — MEM-1) |
| **Offline page** | CSP removed from `offline.html` (v1.1.0) |
| **Data preservation (v1.2.0)** | 10 defensive layers, persistent backup directory with `0700`/`0600` permissions, SHA256 integrity verification (advisory), transactional install with rollback, recovery mode via trigger file, SELinux context preservation |
| **Backup rotation hardening (v1.3.0)** | **SNAP-MANIFEST + SNAP-MTIME (main.go `buildBackupInfo`) and ROT-MANIFEST + ROT-MTIME + ROT-PROTECT (`functions.sh:rotate_backups`)** — manifest-based detection, mtime sort, and protection of `.last_stable` + newest install snapshot from pruning |
| **Boot reliability (v1.3.0)** | DNS auto-start after boot via direct API call in `service.sh` (uses the same watchdog token as the watchdog process) |
| **Static asset safety (v1.4.0)** | Companion APK served as a static file — no server-side logic executes to serve it; the WebUI install button is a plain `<a download>` link |

---

## Key Security Fixes (v1.4.0)

### CodeQL `go/path-injection` hardening (v1.4.0)

- **Two CodeQL alerts (#1, #2) closed in `removeModule`
  (`proxy/main.go`)** — the caller-provided path is now routed through
  `filepath.Base()` and the final path is reconstructed from the
  trusted `MODULES_DIR` constant. No user-controlled data reaches
  any path expression. Defence-in-depth prefix check kept as a
  second layer.
- **No API contract change** — `POST /api/remove_module` keeps the
  same path, method, auth requirements, and response shape.

### Companion APK integration (v1.4.0)

- **Static file only** — the companion APK is served at
  `GET /app-debug.apk` via `http.ServeFile`. No server-side logic
  executes to serve it.
- **Public route** (no auth required) — same policy as the static
  SVG/PNG/ICO assets. The APK contains no user data.
- **404 when absent** — the intended behaviour for local developer
  builds without a network fetch.
- **iOS PWA logic removed** — Android-only project. Removes ~35
  lines of iOS-specific code from `web/index.html`.

---

## Key Security Fixes (v1.3.0)

### Backup rotation hardening (v1.3.0 — SNAP-* / ROT-*)

- **Why this matters for security**: The persistent backup directory
  at `/sdcard/dnscrypt-webui-backup/` is the **last line of defense**
  for user configuration. If rotation silently evicts the snapshot
  that recovery mode depends on (`.last_stable`) or the snapshot that
  rollback depends on (the newest install), the user can lose their
  configuration during a failed upgrade. The v1.3.0 refinements close
  this class of failure.

- **SNAP-MANIFEST** — `main.go:buildBackupInfo()` now detects a
  snapshot by `.manifest.json` presence, not by the v1.2.0 name
  pattern. Custom-named snapshots are therefore visible to the API
  (and cannot be silently orphaned).

- **SNAP-MTIME** — `last_backup_name` is now selected by mtime
  (descending), with a name-based fallback. This is robust against
  clock drift and manual renames, and it aligns `runtime_info` with
  the shell-side `status.sh --json` object.

- **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** — `functions.sh:
  rotate_backups()` was rewritten with the same detection, the same
  sort, and two additional protected targets:

  | Target | Why it is protected |
  |---|---|
  | `.last_stable` target | Recovery mode priority-1 source; pruning it would break recovery. |
  | Newest install snapshot | Used by rollback and `.upgrade_history`; pruning it would break rollback. |

  **Threat model coverage**:

  | Threat | Mitigation |
  |---|---|
  | Manifest-less directory mistaken for a snapshot | **ROT-MANIFEST** excludes it. |
  | Clock drift or manual rename displacing the newest snapshot | **ROT-MTIME** sorts by mtime, not name. |
  | Rotation evicting the recovery pointer | **ROT-PROTECT** never prunes `.last_stable`. |
  | Rotation evicting the rollback target | **ROT-PROTECT** never prunes the newest install snapshot. |

- **Parallel application** — the same semantics are now in
  `watchdog.sh` (§[5b] counter), `status.sh` (`_list_snapshots`),
  `customize.sh` (`rotate_backups`), `action.sh`
  (`_inline_list_snapshots` + `_inline_rotate_backups` +
  `_inline_backup_summary`), and `uninstall.sh` (§[5b]
  `BACKUP_COUNT` / `BACKUP_LAST_NAME`).

- **Reference**: `docs/ARCHITECTURE.md` §4.13 (authoritative),
  §11.31–§11.34 (trade-offs), `docs/BACKUP.md` §6.5 (rotation
  ordering).

### DNS auto-start after boot (v1.3.0)

- **Race condition closed** — the DNS engine was not starting
  automatically after reboot when the user had left the service in
  the ON state. Root cause: `watchdog.sh` waits 30 s before its
  first API call, and by then the WebUI may not have bound to its
  port yet.
- **Fix** — `service.sh` now performs a direct, bounded wait for
  the WebUI to become ready, then calls
  `POST /api/ensure_running_service` itself.
- **Security** — uses the same `X-Watchdog-Token` header
  introduced in v1.2.0. No new authentication surface.

### PWA install button (v1.3.0)

- **No new attack surface** — operated entirely on static strings
  and DOM elements. Removed entirely in v1.4.0.

### Live status LED (v1.3.0)

- **No security implications** — pure CSS + JS. No network calls,
  no user input.

---

## Key Security Fixes (v1.2.0)

### Data preservation (v1.2.0)

- **Fixes a silent data-loss bug in v1.1.0** — The installer used a
  path-comparison check that always failed on in-place upgrades.
  Result: the 5 user config files were silently erased on every
  upgrade. Fixed by the **10 defensive layers**. See
  [`docs/SECURITY.md`](../docs/SECURITY.md) §5.31.

### Watchdog token (v1.2.0 — WD-TOKEN)

- **Closes a CSRF hole on `POST /api/ensure_running_service`** —
  Before v1.2.0, this endpoint was protected only by an implicit
  "localhost bypass". Now requires an `X-Watchdog-Token` header.
  - Token is a 32-byte secret from `crypto/rand`, written atomically
    to `$RUN_DIR/.watchdog_token` (mode `0600`).
  - Constant-time comparison via `subtle.ConstantTimeCompare`.
  - See [`docs/SECURITY.md`](../docs/SECURITY.md) §5.33.

### Correctness fixes (v1.2.0 — FIX-1, FIX-2)

- **FIX-1 — Recovery-mode correctness via snapshot-and-reapply.**
  The previous v1.2.0 draft had a bug where the ZIP extraction step
  overwrote 2 of the 5 restored files during recovery.

  **The fix uses snapshot-and-reapply**:

  1. `§[8a]` — In recovery mode, the 5 user files are restored
     **and** copied to `$MODPATH/.recovery_snapshot/`.
  2. `§[9]` — The ZIP is extracted normally (extraction logic
     untouched, so the normal-install path is byte-for-byte
     identical).
  3. `§[9b2]` — The 5 files are re-applied from the snapshot. On
     partial re-application, the snapshot directory is preserved
     for manual inspection.

  See [`docs/SECURITY.md`](../docs/SECURITY.md) §5.32.1 for the
  full analysis.

- **FIX-2 — Service Worker update-banner.** The v1.1.0 fix applied
  only to `index.html`. Fixed by sending `SKIP_WAITING` to
  `swRegistration.waiting` and applying the fix to **both**
  `index.html` and `dashboard.html`.

### Breaking change for API consumers (v1.2.0)

- **`POST /api/append_denylist`** — now **requires** a `content`
  parameter. Without it → `400 Bad Request`:
  ```json
  {"status": "error", "message": "Missing or empty 'content' parameter"}
  ```
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
  `COMMIT`'d `txn-*` dirs at startup.

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

- **`hasEndpoint()`** — exact path matching.
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
- **Audit Corrections Registry remains at #33** — v1.2.0, v1.3.0,
  and v1.4.0 do not extend it. New audit corrections will resume at
  **#34** in a future release. See
  [`docs/SECURITY.md`](../docs/SECURITY.md) §17.
- **v1.3.0 and v1.4.0 do not introduce new attack vectors.** All
  v1.0.0, v1.1.0, and v1.2.0 security fixes remain in place.
  - The v1.3.0 additions (PWA install button, live status LED, DNS
    auto-start) are feature/correctness improvements. The PWA button
    operated entirely on static strings; the status LED is pure CSS;
    the DNS auto-start uses the existing watchdog token.
  - The v1.3.0 **server-side refinements** (SNAP-MANIFEST,
    SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT) **harden** the
    backup layer: they eliminate a class of failure where rotation
    could silently prune a snapshot that recovery mode or rollback
    depends on. They are strictly defensive and do not change the
    API contract.
  - The v1.4.0 additions (Companion APK, CodeQL fix, iOS removal)
    are strictly defensive. The APK is a static file served
    publicly; the CodeQL fix closes two path-injection alerts; the
    iOS removal reduces the browser-detection surface.
- **The v1.2.0 rotation description ("sorted by directory name") is
  superseded.** The authoritative current description is the v1.3.0
  **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** semantics in
  `docs/ARCHITECTURE.md` §4.13.2 and `docs/BACKUP.md` §6.5.
- **`web/offline.html` no longer has a CSP meta.** If you add dynamic
  content to that page in the future, reintroduce CSP — preferably
  with a nonce rather than `'unsafe-inline'`.
- **`POST /api/append_denylist` now requires a `content` parameter.**
  Update any scripts that called it with no arguments.
- **Persistent backup directory**: `/sdcard/dnscrypt-webui-backup/`
  is owned by root with mode `0700` on directories and `0600` on
  files. A malicious root app can still read it. See
  [`docs/BACKUP.md`](../docs/BACKUP.md) §12.5.
- **Companion APK** is served publicly at `GET /app-debug.apk`. It is
  a static file with no telemetry. If you build the module locally
  without fetching the APK, the route returns 404 — this is the
  intended behaviour.

---

## Contact

- **Maintainer**: [@gasciljh](https://github.com/gasciljh)
- **GitHub**: [Report a vulnerability](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)

---

*Last updated: 2026-10-08*
*Version: v1.4.0*
*Author: gasciljh*
