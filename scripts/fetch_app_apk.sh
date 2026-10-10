#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – fetch_app_apk.sh
# Version: v1.4.0 (Global Edition)
# Last updated: 2026-10-08
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Fetch the companion Android app APK from the
#   dnscrypt-proxy-app repository releases.
#
# Single Source of Truth:
#   proxy/app-apk.version    (e.g. "1.0.0", no "v" prefix)
#
# Source URL pattern:
#   https://github.com/gasciljh/dnscrypt-proxy-app/
#     releases/download/v<version>/app-debug.apk
#
# Output (default: ./dist/):
#   dist/DNS-Proxy-v<version>.apk
#   dist/DNS-Proxy-v<version>.apk.sha256
#
# Features:
#   • Local cache checked first (~/.cache/dnscrypt-proxy-webui/app)
#   • SHA256 verification via .manifest.json
#   • Offline mode (--offline)
#   • JSON output for CI (--json)
#   • Idempotent — safe to run multiple times
#
# Usage:
#   ./scripts/fetch_app_apk.sh
#   ./scripts/fetch_app_apk.sh --verbose
#   ./scripts/fetch_app_apk.sh --offline
#   ./scripts/fetch_app_apk.sh --force
#   ./scripts/fetch_app_apk.sh --json | jq .
#
# Environment:
#   GITHUB_TOKEN     — Optional. Increases API rate limit.
#   APP_CACHE_DIR    — Override cache directory.
#   NO_COLOR         — Disable colored output.
#
# Exit codes:
#   0 — APK ready (cache hit or download success)
#   1 — Download failed from all sources
#   2 — Invalid arguments / missing tools / missing version file
#
# ============================================================
# v1.4.0 — initial release
# ============================================================
#   📱 FDAPK-1 — New script. Fetches the companion Android app
#     APK from gasciljh/dnscrypt-proxy-app releases and places
#     it in `dist/` as `DNS-Proxy-v<app-version>.apk`.
#
#     Invoked by:
#       • `.github/workflows/release.yml` (step "Fetch companion
#         Android app APK") — best-effort, does not block the
#         release if the fetch fails.
#       • `Makefile` target `fetch-apk` — developer convenience.
#
#     Idempotent. Uses a local cache under
#     `~/.cache/dnscrypt-proxy-webui/app/` and a
#     `.manifest.json` for SHA256 tracking.
#
#   📱 FDAPK-2 — Version-aware. The app version is read from
#     `proxy/app-apk.version` (single source of truth). The
#     version may be overridden with `--version`.
#
#   📱 FDAPK-3 — Fallback URL. If the pinned version's release
#     asset is not found, the script retries with the
#     `releases/latest/download/` URL. This lets the pipeline
#     recover from a release-tag naming change without a script
#     update.
#
#   📱 FDAPK-4 — Sanity check. After download, the first two
#     bytes are verified to be `PK` (ZIP magic). This rejects
#     HTML error pages that servers sometimes return with
#     HTTP 200.
#
# ============================================================
# v1.4.0 — Post-audit fixes (this revision)
# ============================================================
#   🔧 FDAPK-5 — `read_app_version` return-code handling.
#     The original code used:
#         APP_VERSION="$(read_app_version)"
#         if [ -z "$APP_VERSION" ]; then exit 2; fi
#
#     Under `set -e` (which the script enables), a non-zero
#     return from `read_app_version` causes the shell to exit
#     IMMEDIATELY with the function's exit status — BEFORE the
#     `if [ -z ... ]` check can run. The documented exit code 2
#     ("missing version file") was therefore never reached; the
#     script exited with code 1 instead.
#
#     Fix: capture the return status explicitly and translate
#     it to exit code 2:
#         if ! APP_VERSION="$(read_app_version)"; then
#             exit 2
#         fi
#
#     The `if !` guard is placed OUTSIDE the command
#     substitution so that `set -e` does not trigger on the
#     failed assignment. The explicit `exit 2` is now the ONLY
#     path for a missing/empty version file.
#
#   🔧 FDAPK-6 — `--help` now documents the short flags.
#     The argument parser has always accepted `-f`, `-v`, `-q`,
#     `-j`, `-h` (see the `case "$1" in` block in section [4]),
#     but the `--help` text only listed the long forms. This
#     made the short flags invisible to anyone who did not read
#     the source. The help text has been updated to show both
#     forms side-by-side, matching the actual parser.
#
#   🔧 FDAPK-7 — Tool-check `for` loop collapsed to `if`.
#     The original used:
#         for tool in curl; do
#             if ! command -v "$tool" >/dev/null 2>&1; then
#                 log_error "Missing tool: $tool"
#                 exit 2
#             fi
#         done
#     The single-iteration loop triggered ShellCheck SC2043
#     ("This loop will only ever run once"). It has been
#     rewritten as a plain `if` with a hardcoded `curl`, which
#     is both clearer and ShellCheck-clean.
#
# ============================================================
# Non-responsibilities (deliberately NOT done here)
# ============================================================
#   • Does NOT build the companion APK. The companion app
#     lives in a separate repository
#     (gasciljh/dnscrypt-proxy-app) and is built there.
#   • Does NOT publish the APK to the GitHub Release. That is
#     handled by `.github/workflows/release.yml` (attaches
#     `dist/DNS-Proxy-v*.apk` and `.sha256`).
#   • Does NOT touch the DNS binaries cache. That is
#     `scripts/fetch_dns_binaries.sh`.
#   • Does NOT touch `proxy/app-apk.version`. It is read-only.
#   • Does NOT touch the backup layer or the WebUI.
# ============================================================
# Coordination with the module
# ============================================================
#   • The version of the companion app is stored in
#     `proxy/app-apk.version` (single source of truth).
#   • The module's CI (`ci.yml`) verifies that the version
#     file exists and is well-formed — but does NOT require
#     the APK itself to be present.
#   • The module's packaging (`package_module.sh`) treats the
#     APK as OPTIONAL: it bundles `web/app-debug.apk` when it
#     exists, and warns (without failing) when it does not.
#   • The module's HTTP server (`main.go`) serves the APK at
#     `GET /app-debug.apk` when it is present, and returns
#     404 otherwise.
#
# Cross-references:
#   • proxy/app-apk.version         — Single Source of Truth
#   • scripts/fetch_dns_binaries.sh — the DNS-binaries equivalent
#   • scripts/package_module.sh     — bundles web/app-debug.apk
#   • .github/workflows/release.yml — CI consumer (best-effort)
#   • .github/workflows/ci.yml      — verifies metadata
#   • Makefile                      — `make fetch-apk`
#   • docs/DNS_BINARIES.md          — parallel pipeline reference
#   • docs/COMPATIBILITY.md         — companion app compatibility
#   • CHANGELOG.md §[v1.4.0]        — full v1.4.0 delta
# ============================================================
# POSIX note on `set -euo pipefail`:
#   This script uses bash (not POSIX sh). It is one of the
#   `scripts/*` helpers run by the developer or by CI, not by
#   Android at runtime. It is therefore free to use bash-isms.
# ============================================================

set -euo pipefail

# ============================================================
# [1] Paths and constants
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_VERSION_FILE="$REPO_ROOT/proxy/app-apk.version"

# Companion app repo (must match APP_REPO in dnscrypt-proxy-app)
APP_REPO="gasciljh/dnscrypt-proxy-app"
APP_ASSET_NAME="app-debug.apk"

# Default directories
DEFAULT_OUTPUT_DIR="$REPO_ROOT/dist"
DEFAULT_CACHE_DIR="${APP_CACHE_DIR:-${HOME}/.cache/dnscrypt-proxy-webui/app}"

# HTTP timeout (seconds)
HTTP_TIMEOUT=60

# ============================================================
# [2] Colors
# ============================================================
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
	CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
	RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

# ============================================================
# [3] Output helpers (stdout for user, stderr for diagnostics)
# ============================================================
log_info()  { echo -e "  ${CYAN}→${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }
log_debug() {
	if [ "$VERBOSE" = "1" ]; then
		echo -e "  ${DIM}·${NC} $1" >&2
	fi
}

# ============================================================
# [4] Arguments
# ============================================================
VERBOSE=0
JSON=0
QUIET=0
OFFLINE=0
FORCE=0
OUTPUT_DIR=""
CACHE_DIR=""
VERSION_OVERRIDE=""

show_help() {
	cat << 'EOF'
DNSCrypt Smart Filter – fetch_app_apk.sh

Usage:
  fetch_app_apk.sh [options]

Options:
  --output-dir <dir>    Output directory (default: ./dist)
  --cache-dir <dir>     Cache directory
  --version <ver>       App version (default: from proxy/app-apk.version)
  --offline             Use cache only (no download)
  --force, -f           Force re-download even if cached
  --verbose, -v         Verbose output
  --quiet, -q           Quiet (errors only)
  --json, -j            JSON output
  --help, -h            Show this help

Examples:
  ./scripts/fetch_app_apk.sh
  ./scripts/fetch_app_apk.sh -v
  ./scripts/fetch_app_apk.sh --offline
  ./scripts/fetch_app_apk.sh -j | jq .
  ./scripts/fetch_app_apk.sh -f --output-dir ./dist

Exit codes:
  0 — APK ready (cache hit or download success)
  1 — Download failed from all sources
  2 — Invalid arguments / missing tools / missing version file

Coordination:
  The app version is read from proxy/app-apk.version.
  This script does NOT touch the DNS binaries cache, the module
  version, or the WebUI. It is a pure fetcher.

See:
  scripts/fetch_dns_binaries.sh  — the DNS-binaries equivalent
  .github/workflows/release.yml  — CI consumer of this script
EOF
	exit 0
}

while [ $# -gt 0 ]; do
	case "$1" in
		--output-dir)
			shift
			OUTPUT_DIR="${1:-}"
			if [ -z "$OUTPUT_DIR" ]; then
				log_error "--output-dir requires a path"
				exit 2
			fi
			;;
		--cache-dir)
			shift
			CACHE_DIR="${1:-}"
			if [ -z "$CACHE_DIR" ]; then
				log_error "--cache-dir requires a path"
				exit 2
			fi
			;;
		--version)
			shift
			VERSION_OVERRIDE="${1:-}"
			if [ -z "$VERSION_OVERRIDE" ]; then
				log_error "--version requires a value (e.g. 1.0.0)"
				exit 2
			fi
			;;
		--offline)     OFFLINE=1 ;;
		--force|-f)    FORCE=1 ;;
		--verbose|-v)  VERBOSE=1 ;;
		--quiet|-q)    QUIET=1 ;;
		--json|-j)     JSON=1 ;;
		--help|-h)     show_help ;;
		*)
			log_error "Unknown option: $1"
			echo "Use --help for assistance" >&2
			exit 2
			;;
	esac
	shift
done

# ============================================================
# [5] Defaults
# ============================================================
[ -z "$CACHE_DIR" ]  && CACHE_DIR="$DEFAULT_CACHE_DIR"
[ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"

mkdir -p "$CACHE_DIR" "$OUTPUT_DIR"
MANIFEST_FILE="$CACHE_DIR/.manifest.json"

# ============================================================
# [6] Tool check
# ============================================================
# FDAPK-7: replaced the single-iteration `for tool in curl; do`
# loop (ShellCheck SC2043) with a plain `if`. Only curl is
# required for the download path; sha256 and jq are detected
# separately below because they are optional.
if ! command -v curl >/dev/null 2>&1; then
	log_error "Missing tool: curl"
	exit 2
fi

HAS_SHA256=0
SHA256_CMD=""
if command -v sha256sum >/dev/null 2>&1; then
	HAS_SHA256=1; SHA256_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
	HAS_SHA256=1; SHA256_CMD="shasum -a 256"
fi

HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

# ============================================================
# [7] Helpers
# ============================================================
file_size() {
	local out
	out=$(stat -c%s "$1" 2>/dev/null) && [ -n "$out" ] && { printf '%s' "$out"; return 0; }
	out=$(stat -f%z "$1" 2>/dev/null) && [ -n "$out" ] && { printf '%s' "$out"; return 0; }
	return 1
}

file_sha256() {
	[ "$HAS_SHA256" = "0" ] && return 1
	$SHA256_CMD "$1" 2>/dev/null | awk '{print $1}'
}

manifest_get() {
	local key="$1"
	if [ "$HAS_JQ" = "1" ] && [ -f "$MANIFEST_FILE" ]; then
		jq -r --arg k "$key" '.[$k].sha256 // empty' "$MANIFEST_FILE" 2>/dev/null
	fi
}

manifest_set() {
	local key="$1" sha="$2" version="$3" url="$4"
	[ "$HAS_JQ" = "0" ] && return 0

	local current="{}"
	if [ -f "$MANIFEST_FILE" ]; then
		current=$(cat "$MANIFEST_FILE" 2>/dev/null) || current="{}"
		echo "$current" | jq empty 2>/dev/null || current="{}"
	fi

	local updated
	if ! updated=$(echo "$current" | jq \
		--arg k "$key" --arg s "$sha" --arg v "$version" --arg u "$url" \
		--arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		'.[$k] = {sha256: $s, version: $v, url: $u, fetched_at: $t}' 2>/dev/null); then
		return 1
	fi
	[ -z "$updated" ] && return 1
	printf '%s\n' "$updated" > "$MANIFEST_FILE"
	return 0
}

# ============================================================
# [8] Read app version (Single Source of Truth)
# ============================================================
# FDAPK-5 fix: the return status of `read_app_version` is
# captured explicitly via `if !`, OUTSIDE the command
# substitution. This prevents `set -e` from exiting the shell
# with the function's internal exit status (1) before the
# documented `exit 2` can run.
# ============================================================
read_app_version() {
	if [ -n "$VERSION_OVERRIDE" ]; then
		printf '%s' "$VERSION_OVERRIDE" | sed 's/^v//'
		return 0
	fi
	if [ -f "$APP_VERSION_FILE" ]; then
		local v
		v=$(tr -d '\r\n' < "$APP_VERSION_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^v//')
		if [ -n "$v" ]; then
			printf '%s' "$v"
			return 0
		fi
	fi
	log_error "proxy/app-apk.version missing or empty"
	return 1
}

APP_VERSION=""
if ! APP_VERSION="$(read_app_version)"; then
	exit 2
fi

if [ -z "$APP_VERSION" ]; then
	exit 2
fi

if ! echo "$APP_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
	log_error "Invalid app version: '$APP_VERSION'"
	log_info "Format: X.Y.Z (e.g. 1.0.0)"
	exit 2
fi

APP_TAG="v${APP_VERSION}"

# ============================================================
# [9] URLs
# ============================================================
GITHUB_URL="https://github.com/${APP_REPO}/releases/download/${APP_TAG}/${APP_ASSET_NAME}"

# Fallback: "latest" pointer (works even if the tag name scheme changes)
GITHUB_LATEST_URL="https://github.com/${APP_REPO}/releases/latest/download/${APP_ASSET_NAME}"

# ============================================================
# [10] Header
# ============================================================
if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
	echo ""
	echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
	echo -e "${BOLD}║  📦 DNSCrypt Companion App — APK Fetcher                  ║${NC}"
	echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
	echo ""
	echo -e "  ${BOLD}App version:${NC}   ${GREEN}${APP_VERSION}${NC}"
	echo -e "  ${BOLD}Source repo:${NC}   ${DIM}${APP_REPO}${NC}"
	echo -e "  ${BOLD}Cache dir:${NC}     ${DIM}${CACHE_DIR}${NC}"
	echo -e "  ${BOLD}Output dir:${NC}    ${DIM}${OUTPUT_DIR}${NC}"
	[ "$OFFLINE" = "1" ] && echo -e "  ${BOLD}Mode:${NC}          ${YELLOW}OFFLINE${NC}"
	[ "$FORCE" = "1" ]   && echo -e "  ${BOLD}Force:${NC}         ${YELLOW}YES${NC}"
	echo ""
fi

# ============================================================
# [11] Output paths
# ============================================================
OUTPUT_APK="${OUTPUT_DIR}/DNS-Proxy-v${APP_VERSION}.apk"
OUTPUT_SHA="${OUTPUT_APK}.sha256"
CACHE_FILE="${CACHE_DIR}/DNS-Proxy-v${APP_VERSION}.apk"

# ============================================================
# [12] Cache check
# ============================================================
if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ] && [ "$FORCE" = "0" ]; then

	# v1.4.0: guard against set -e exit on corrupt manifest.
	cached_sha=$(manifest_get "DNS-Proxy-v${APP_VERSION}" || true)
	if [ -n "$cached_sha" ] && [ "$HAS_SHA256" = "1" ]; then
		actual_sha=$(file_sha256 "$CACHE_FILE")
		if [ "$actual_sha" != "$cached_sha" ]; then
			log_warn "SHA mismatch in cache — re-downloading"
			rm -f "$CACHE_FILE"
		fi
	fi

	if [ -f "$CACHE_FILE" ]; then
		size=$(file_size "$CACHE_FILE") || size=0
		[ -z "$size" ] && size=0

		# Copy from cache to output
		cp -f "$CACHE_FILE" "$OUTPUT_APK"

		# Write SHA256 file
		if [ "$HAS_SHA256" = "1" ]; then
			(cd "$OUTPUT_DIR" && $SHA256_CMD "$(basename "$OUTPUT_APK")" > "$(basename "$OUTPUT_SHA")")
		fi

		if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
			log_ok "cache hit → $OUTPUT_APK (${size} bytes)"
		fi

		if [ "$JSON" = "1" ]; then
			cat << JSONEOF
{
  "status": "cached",
  "version": "${APP_VERSION}",
  "apk_path": "${OUTPUT_APK}",
  "sha256_path": "${OUTPUT_SHA}",
  "size": ${size}
}
JSONEOF
		fi
		exit 0
	fi
fi

# ============================================================
# [13] Offline mode — cannot download
# ============================================================
if [ "$OFFLINE" = "1" ]; then
	log_error "cache missing (offline mode)"
	if [ "$JSON" = "1" ]; then
		cat << JSONEOF
{
  "status": "failed",
  "version": "${APP_VERSION}",
  "reason": "offline_and_no_cache"
}
JSONEOF
	fi
	exit 1
fi

# ============================================================
# [14] Download
# ============================================================
if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
	log_info "downloading ${APP_ASSET_NAME} (v${APP_VERSION})..."
fi

tmp_file="${CACHE_DIR}/.tmp-${APP_VERSION}.apk"
downloaded_url=""
success=0

for url in "$GITHUB_URL" "$GITHUB_LATEST_URL"; do
	[ "$success" = "1" ] && break

	log_debug "GET $url"

	curl_args=(
		-fsSL
		--max-time "$HTTP_TIMEOUT"
		--retry 2
		--retry-delay 1
	)
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
	fi

	if curl "${curl_args[@]}" -o "$tmp_file" "$url" 2>/dev/null; then
		if [ -s "$tmp_file" ]; then
			# Basic sanity: APK is a ZIP → first 2 bytes "PK"
			magic=$(head -c 2 "$tmp_file" 2>/dev/null || true)
			if [ "$magic" = "PK" ]; then
				downloaded_url="$url"
				success=1
				log_debug "Success: $url"
			else
				log_warn "Invalid APK (not a ZIP): $url"
				rm -f "$tmp_file"
			fi
		fi
	fi
done

if [ "$success" = "0" ]; then
	log_error "download failed from all sources"
	rm -f "$tmp_file"
	if [ "$JSON" = "1" ]; then
		cat << JSONEOF
{
  "status": "failed",
  "version": "${APP_VERSION}",
  "reason": "all_sources_failed",
  "urls_tried": ["${GITHUB_URL}", "${GITHUB_LATEST_URL}"]
}
JSONEOF
	fi
	exit 1
fi

# Move to cache
mv -f "$tmp_file" "$CACHE_FILE"
chmod 0644 "$CACHE_FILE"

# ============================================================
# [15] Compute SHA + manifest
# ============================================================
sha=""
if [ "$HAS_SHA256" = "1" ]; then
	sha=$(file_sha256 "$CACHE_FILE")
fi

manifest_set "DNS-Proxy-v${APP_VERSION}" "$sha" "$APP_VERSION" "$downloaded_url" 2>/dev/null || true

# ============================================================
# [16] Copy to output + write .sha256
# ============================================================
cp -f "$CACHE_FILE" "$OUTPUT_APK"

if [ "$HAS_SHA256" = "1" ]; then
	(cd "$OUTPUT_DIR" && $SHA256_CMD "$(basename "$OUTPUT_APK")" > "$(basename "$OUTPUT_SHA")")
fi

size=$(file_size "$CACHE_FILE") || size=0
[ -z "$size" ] && size=0

# ============================================================
# [17] Output
# ============================================================
if [ "$JSON" = "1" ]; then
	sha_escaped=$(printf '%s' "$sha" | sed 's/"/\\"/g')
	cat << JSONEOF
{
  "status": "downloaded",
  "version": "${APP_VERSION}",
  "apk_path": "${OUTPUT_APK}",
  "sha256_path": "${OUTPUT_SHA}",
  "sha256": "${sha_escaped}",
  "size": ${size},
  "url": "${downloaded_url}"
}
JSONEOF
	exit 0
fi

if [ "$QUIET" = "0" ]; then
	sha_short=""
	[ -n "$sha" ] && sha_short="${sha:0:16}..."
	log_ok "downloaded → $OUTPUT_APK (${size} bytes)"
	[ -n "$sha_short" ] && log_ok "sha256: $sha_short"
fi

exit 0
