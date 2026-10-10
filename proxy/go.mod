// ============================================================
// DNSCrypt Smart Filter – Go Module Definition
// Version: v1.4.0 (Global Edition)
// Last updated: 2026-10-08
// Author: gasciljh
// Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
// ============================================================
// Purpose:
//   Defines the Go module for the WebUI backend (proxy/main.go).
//
// Notes:
//   • Module path: dnscrypt-webui
//   • Go version: 1.22 (matches the toolchain in devcontainer,
//     CI, and release workflows)
//   • Historically dependency-free. As of v1.4.1, exactly ONE
//     external dependency is allowed: filepath-securejoin
//     (see ADR-0007). All other code remains stdlib-only.
//   • `go.sum` was intentionally absent before v1.4.1. It now
//     pins github.com/cyphar/filepath-securejoin v0.7.0 (ADR-0007).
//
// ============================================================
// Cross-references:
// ============================================================
//   • VERSION                        — module version (SSOT)
//   • proxy/main.go                  — consumer of this module
//   • proxy/build.sh                 — build entry point
//   • proxy/dnscrypt-proxy.toml      — DNS engine config
//   • proxy/webui.conf               — WebUI/Dashboard ports
//   • proxy/app-apk.version          — companion app version (v1.4.0)
//   • .github/workflows/ci.yml       — Go 1.22 build matrix
//   • .github/workflows/release.yml  — release pipeline
//   • .devcontainer/devcontainer.json — Go 1.22 feature
//   • docs/ARCHITECTURE.md §1.2      — Zero-Footprint principle
//   • docs/ARCHITECTURE.md §4.13     — v1.3.0 server-side refinements
//   • docs/adr/README.md §3          — dependency-free policy
//   • CHANGELOG.md                   — version history (v1.0.0 → v1.4.0)
// ============================================================
// v1.1.0 notes (kept):
//   • The Go runtime soft memory limit is set dynamically by
//     main.go based on the active blocklist profile:
//       light → 80 MB, normal → 100 MB, pro → 120 MB,
//       proplus → 160 MB, ultimate → 220 MB.
//   • This behavior uses `runtime/debug.SetMemoryLimit` from
//     the Go standard library — no new dependency is required.
//   • The module stays dependency-free; the memory limit feature
//     adds zero bytes to go.sum (which remains absent).
//
// v1.2.0 notes:
//   • Version bumped from v1.1.0 to v1.2.0 (documentation only —
//     no behavioral changes to the Go module itself).
//   • The v1.2.0 release is a data-preservation release. It does
//     NOT add any new Go dependencies, new build tags, or new
//     linker flags. The 10 defensive layers introduced by v1.2.0
//     live entirely in existing shell scripts (customize.sh,
//     service.sh, status.sh, uninstall.sh, functions.sh,
//     watchdog.sh) and in existing sections of main.go.
//   • New Go code added in main.go (all using the Go standard
//     library only):
//       - createAutoBackup(reason string)
//       - checkPendingNotifications()
//       - cleanupOldTransactions()
//       - buildBackupInfo() — extended with last_backup_name
//                             and last_stable
//   • All of the above use only:
//       - os, filepath, strings, fmt, time — already imported
//   • No new imports were added to main.go. The dependency-free
//     policy of the project is preserved.
//
// ============================================================
// v1.3.0 notes — main.go WAS modified (corrected in this revision):
// ============================================================
//   • Version bumped from v1.2.0 to v1.3.0.
//
//   ⚠️ CORRECTION (this revision): Earlier drafts of this file
//      claimed "No new Go code was added" for v1.3.0. That claim
//      was inaccurate. The v1.3.0 release DID modify
//      `main.go:buildBackupInfo()` with two server-side
//      refinements:
//
//        🔧 SNAP-MANIFEST — snapshot detection by `.manifest.json`
//          presence (replaces the v1.2.0 name-pattern rule
//          `^[0-9]{8}-[0-9]{6}-`).
//
//        🔧 SNAP-MTIME — `last_backup_name` selection by mtime,
//          descending (replaces the v1.2.0 lexicographic-name
//          rule). Name-based fallback when DirEntry.Info() fails.
//
//   • Both refinements use ONLY the Go standard library:
//       - os.ReadDir, os.Stat      — already imported (v1.2.0)
//       - sort.Slice               — already imported (v1.2.0)
//       - strings, filepath        — already imported (v1.2.0)
//
//   • Parallel shell-side refinements (NOT part of this module,
//     documented here for traceability):
//       - functions.sh:rotate_backups() → ROT-MANIFEST + ROT-MTIME
//         + ROT-PROTECT
//       - service.sh → boot-path DNS auto-start
//       - watchdog.sh, status.sh, customize.sh, action.sh,
//         uninstall.sh — same SNAP-*/ROT-* semantics
//
//   • The client-side changes (PWA install button, live status
//     LED) live in web/*.html and web/*.js — NOT in this module.
//
//   • No new imports were added to main.go. The dependency-free
//     policy of the project is preserved.
//
//   • See CHANGELOG.md [v1.3.0] and docs/ARCHITECTURE.md §4.13
//     for the full v1.3.0 delta.
//
// v1.4.1 notes:
//   • First and only external dependency added:
//       github.com/cyphar/filepath-securejoin v0.7.0
//   • Rationale: CodeQL does not recognize filepath.Base() as a
//     sanitizer for go/path-injection in the removeModule data
//     flow. SecureJoin is the official CodeQL-recommended fix.
//     See ADR-0007 for the full decision record.
//   • Scope: ONLY proxy/main.go:removeModule. All other code
//     remains standard-library-only.
//   • This supersedes the "no external dependencies" clause of
//     docs/ARCHITECTURE.md §1.2 — for this case only.
//
// v1.4.0 notes:
//   • Version bumped from v1.3.0 to v1.4.0 (documentation only —
//     no behavioral changes to the Go module itself).
//   • The v1.4.0 release is an integration release:
//       - Companion Android app (web/app-debug.apk) bundled
//         into the module ZIP as an OPTIONAL asset.
//       - `GET /app-debug.apk` route added in main.go.
//       - CodeQL `go/path-injection` fix in `removeModule`
//         (uses only `path/filepath` — already imported).
//       - iOS PWA logic removed (Android-only project).
//       - MAIN-01: LOG_LEVEL load-order fix in main.go.
//   • The only new Go code is:
//       - `APK_FILE` constant (filepath.Join)
//       - `serveStaticAssets` entry for `/app-debug.apk`
//       - `removeModule` hardening (filepath.Base +
//          filepath.Join)
//       - `main()` — `currentLogLevel = loadLogLevel()`
//          moved to immediately after `initPaths()`
//   • All of the above use only:
//       - path/filepath — already imported
//   • No new imports were added. The dependency-free policy of
//     the project is preserved.
//
// Build:
//   The build system (proxy/build.sh) uses:
//     • -buildvcs=false  → no VCS stamping
//     • -trimpath        → path normalization for reproducible builds
//     • -buildid=        → deterministic build ID
//     • -mod=readonly    → fail if go.mod needs changes
//
// ⚠️ Do NOT add external dependencies without an ADR.
//    ADR-0007 authorizes exactly ONE: filepath-securejoin.
//    Any future external dependency MUST have its own ADR.
//
// ⚠️ If you change the `go` directive below (currently 1.22),
//    you MUST also update:
//      • proxy/build.sh  → REQUIRED_GO_MAJOR / REQUIRED_GO_MINOR
//      • .github/workflows/ci.yml       → GO_VERSION
//      • .github/workflows/release.yml  → GO_VERSION
//      • .devcontainer/devcontainer.json → go version
//      • docs/DEVELOPMENT.md            → toolchain requirements
// ============================================================

module dnscrypt-webui

go 1.22

require github.com/cyphar/filepath-securejoin v0.7.0
