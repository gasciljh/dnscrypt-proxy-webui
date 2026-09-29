// ============================================================
// DNSCrypt Smart Filter – Go Module Definition
// Version: v1.2.0 (Global Edition)
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
//   • No external dependencies — the project uses only the Go
//     standard library (crypto, net/http, os, sync, ...).
//   • `go.sum` is intentionally absent because there are no
//     dependencies to verify.
//
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
// Build:
//   The build system (proxy/build.sh) uses:
//     • -buildvcs=false  → no VCS stamping
//     • -trimpath        → path normalization for reproducible builds
//     • -buildid=        → deterministic build ID
//     • -mod=readonly    → fail if go.mod needs changes
//
// ⚠️ Do NOT add external dependencies without an ADR. The
//    dependency-free policy is one of the project's core
//    architectural principles (see docs/ARCHITECTURE.md §1.2
//    and docs/adr/README.md §3).
// ============================================================

module dnscrypt-webui

go 1.22