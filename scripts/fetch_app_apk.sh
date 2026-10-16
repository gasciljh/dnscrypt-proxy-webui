#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – fetch_app_apk.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-15
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Fetch the companion Android app APK from the
# dnscrypt-proxy-app repository releases.
#
# Version source: proxy/app-apk.version (SSOT, X.Y.Z no "v").
#
# Output (default ./dist/):
#   dist/DNS-Proxy-v<version>.apk
#   dist/DNS-Proxy-v<version>.apk.sha256
#
# The .sha256 sidecar references the FINAL staged filename,
# `app-debug.apk`, NOT the intermediate dist name. This makes
# the sidecar directly usable by `sha256sum -c` after
# release.yml copies it to `web/app-debug.apk.sha256`, and by
# install_app.sh on device.
#
# Usage:
#   ./scripts/fetch_app_apk.sh
#   ./scripts/fetch_app_apk.sh --verbose
#   ./scripts/fetch_app_apk.sh --offline
#   ./scripts/fetch_app_apk.sh --json | jq .
#
# Environment:
#   GITHUB_TOKEN     — optional; increases GitHub API rate limit
#   APP_CACHE_DIR    — override cache directory
#   NO_COLOR         — disable colored output
#
# Exit codes:
#   0 — APK ready (cache hit or download success)
#   1 — download failed from all sources
#   2 — invalid arguments / missing tools / missing version file
# ============================================================

set -euo pipefail

# ============================================================
# [1] Paths and constants
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_VERSION_FILE="$REPO_ROOT/proxy/app-apk.version"

APP_REPO="gasciljh/dnscrypt-proxy-app"
APP_ASSET_NAME="app-debug.apk"
SIDECAR_REF_NAME="app-debug.apk"

DEFAULT_OUTPUT_DIR="$REPO_ROOT/dist"
DEFAULT_CACHE_DIR="${APP_CACHE_DIR:-${HOME}/.cache/dnscrypt-proxy-webui/app}"

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
# [3] Logging
# ============================================================
# Stream discipline: info/ok → stdout; warn/error/debug → stderr.
# Keeps stdout clean for value-producing contexts (e.g. when
# this script's output is piped).
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
  --version <ver>       Override app version (default: from
                        proxy/app-apk.version)
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

Output:
  dist/DNS-Proxy-v<version>.apk
  dist/DNS-Proxy-v<version>.apk.sha256

Exit codes:
  0 — APK ready (cache hit or download success)
  1 — download failed from all sources
  2 — invalid arguments / missing tools / missing version file
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

# --force and --offline are mutually exclusive: --force discards
# a valid cache entry, --offline refuses to download. Combined,
# every architecture fails with "cache missing" even when the
# cache is present.
if [ "$OFFLINE" = "1" ] && [ "$FORCE" = "1" ]; then
    log_error "--offline and --force are mutually exclusive"
    log_info "  --offline  → use cache only"
    log_info "  --force    → ignore cache and re-download"
    exit 2
fi

# ============================================================
# [5] Defaults + tool check
# ============================================================
[ -z "$CACHE_DIR" ]  && CACHE_DIR="$DEFAULT_CACHE_DIR"
[ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"

mkdir -p "$CACHE_DIR" "$OUTPUT_DIR"
MANIFEST_FILE="$CACHE_DIR/.manifest.json"

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
# [6] Helpers
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

# write_sidecar <apk_path> <sidecar_path> <embedded_filename>
#
# Emits `<hash>  <filename>` (two spaces, standard sha256sum -c
# format). The embedded filename is the FINAL staged name, not
# the intermediate dist name. See header for rationale.
write_sidecar() {
    local src="$1"
    local dst="$2"
    local ref="$3"

    [ "$HAS_SHA256" = "0" ] && return 1

    local h
    h=$(file_sha256 "$src")
    [ -z "$h" ] && return 1

    printf '%s  %s\n' "$h" "$ref" > "$dst"
    return 0
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
# [7] Read app version (SSOT)
# ============================================================
# Resolution: --version override → file → abort.
#
# The --version value is normalized the same way as the file
# value: leading whitespace/CRLF trimmed, optional "v" prefix
# stripped. A bare "v" (which strips to an empty string) is
# rejected here with an explicit message — without this check
# the empty string would later fail the "X.Y.Z" regex and exit
# silently with code 2.
read_app_version() {
    if [ -n "$VERSION_OVERRIDE" ]; then
        local v
        v=$(printf '%s' "$VERSION_OVERRIDE" \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
            | sed 's/^v//')

        if [ -z "$v" ]; then
            log_error "--version value is empty after stripping the 'v' prefix"
            log_info "  Received: '$VERSION_OVERRIDE'"
            log_info "  Expected: X.Y.Z (e.g. 1.0.0, or v1.0.0)"
            return 1
        fi

        printf '%s' "$v"
        return 0
    fi

    if [ -f "$APP_VERSION_FILE" ]; then
        local v
        v=$(tr -d '\r\n' < "$APP_VERSION_FILE" \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
            | sed 's/^v//')
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
# [8] URLs
# ============================================================
GITHUB_URL="https://github.com/${APP_REPO}/releases/download/${APP_TAG}/${APP_ASSET_NAME}"

# Fallback: the "latest" pointer. Resolves even if the tag name
# scheme changes.
GITHUB_LATEST_URL="https://github.com/${APP_REPO}/releases/latest/download/${APP_ASSET_NAME}"

# ============================================================
# [9] Header
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
# [10] Output paths
# ============================================================
OUTPUT_APK="${OUTPUT_DIR}/DNS-Proxy-v${APP_VERSION}.apk"
OUTPUT_SHA="${OUTPUT_APK}.sha256"
CACHE_FILE="${CACHE_DIR}/DNS-Proxy-v${APP_VERSION}.apk"

# ============================================================
# [11] Cache check
# ============================================================
# Cache is keyed by version. A cached file is used only if its
# SHA matches the manifest entry (when both are available).
if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ] && [ "$FORCE" = "0" ]; then

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

        cp -f "$CACHE_FILE" "$OUTPUT_APK"

        if [ "$HAS_SHA256" = "1" ]; then
            write_sidecar "$OUTPUT_APK" "$OUTPUT_SHA" "$SIDECAR_REF_NAME"
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
  "sha256_embedded_name": "${SIDECAR_REF_NAME}",
  "size": ${size}
}
JSONEOF
        fi
        exit 0
    fi
fi

# ============================================================
# [12] Offline mode
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
# [13] Download
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
            # APK is a ZIP → first 2 bytes "PK". Rejects HTML
            # error pages that servers sometimes return with
            # HTTP 200.
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

mv -f "$tmp_file" "$CACHE_FILE"
chmod 0644 "$CACHE_FILE"

# ============================================================
# [14] Compute SHA + update manifest
# ============================================================
sha=""
if [ "$HAS_SHA256" = "1" ]; then
    sha=$(file_sha256 "$CACHE_FILE")
fi

manifest_set "DNS-Proxy-v${APP_VERSION}" "$sha" "$APP_VERSION" "$downloaded_url" 2>/dev/null || true

# ============================================================
# [15] Copy to output + write sidecar + self-test
# ============================================================
cp -f "$CACHE_FILE" "$OUTPUT_APK"

if [ "$HAS_SHA256" = "1" ]; then
    write_sidecar "$OUTPUT_APK" "$OUTPUT_SHA" "$SIDECAR_REF_NAME"

    # Self-test the sidecar: run `sha256sum -c` from a temp dir
    # with the referenced file present. This is the standard
    # validation; if it fails, the sidecar format has drifted.
    if [ -f "$OUTPUT_SHA" ] && [ -s "$OUTPUT_SHA" ]; then
        _tmpdir="$(mktemp -d 2>/dev/null || true)"
        if [ -z "$_tmpdir" ] || [ ! -d "$_tmpdir" ]; then
            log_debug "sidecar self-test skipped (mktemp unavailable)"
        else
            cp -f "$OUTPUT_APK" "${_tmpdir}/${SIDECAR_REF_NAME}" 2>/dev/null || true
            cp -f "$OUTPUT_SHA" "${_tmpdir}/${SIDECAR_REF_NAME}.sha256" 2>/dev/null || true
            if ! (cd "$_tmpdir" && $SHA256_CMD -c "${SIDECAR_REF_NAME}.sha256" >/dev/null 2>&1); then
                log_warn "sidecar self-test failed (format regression?)"
            else
                log_debug "sidecar self-test passed"
            fi
            rm -rf "$_tmpdir" 2>/dev/null || true
        fi
    fi
fi

size=$(file_size "$CACHE_FILE") || size=0
[ -z "$size" ] && size=0

# ============================================================
# [16] Final output
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
  "sha256_embedded_name": "${SIDECAR_REF_NAME}",
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
    log_ok "sidecar: $OUTPUT_SHA"
    log_info "  embedded name: ${SIDECAR_REF_NAME}"
    log_info "  (release.yml will copy the sidecar to"
    log_info "   web/app-debug.apk.sha256 before packaging)"
fi

exit 0
