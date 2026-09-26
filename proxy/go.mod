// ============================================================
// DNSCrypt Smart Filter – Go Module Definition
// Version: v1.1.0
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
// v1.1.0 notes:
//   • The Go runtime soft memory limit is set dynamically by
//     main.go based on the active blocklist profile:
//       light → 80 MB, normal → 100 MB, pro → 120 MB,
//       proplus → 160 MB, ultimate → 220 MB.
//   • This behavior uses `runtime/debug.SetMemoryLimit` from
//     the Go standard library — no new dependency is required.
//   • The module stays dependency-free; the memory limit feature
//     adds zero bytes to go.sum (which remains absent).
//
// Build:
//   The build system (proxy/build.sh) uses:
//     • -buildvcs=false  → no VCS stamping
//     • -trimpath        → path normalization for reproducible builds
//     • -buildid=        → deterministic build ID
//     • -mod=readonly    → fail if go.mod needs changes
//
// ============================================================

module dnscrypt-webui

go 1.22