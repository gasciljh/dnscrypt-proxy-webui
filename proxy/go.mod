// ============================================================
// DNSCrypt Smart Filter – Go Module Definition
// Version: v1.0.0
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
// ============================================================

module dnscrypt-webui

go 1.22