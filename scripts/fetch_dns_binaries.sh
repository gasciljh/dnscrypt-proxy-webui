#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – fetch_dns_binaries.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-19
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Fetch dnscrypt-proxy binaries for all supported Android
# architectures.
#
# Version source: proxy/dnscrypt-proxy.version (SSOT). This is
# the UPSTREAM DNS engine version (e.g. 2.1.18), independent of
# the module version (VERSION).
#
# The local cache is checked FIRST. A valid cached binary
# short-circuits the entire download path (unless --force).
#
# Fallback sources (tried in order when a download is needed):
#   1. GitHub API       — real asset names (most accurate)
#   2. android_<arch>-<version>.zip  — 2.1.18+ format
#   3. android-<arch>-<version>.zip  — older format
#   4. android_<arch>_<version>.zip  — underscore format
#
# Retry strategy — two layers:
#   • curl's own --retry 2 (3 total attempts per URL, 1s apart)
#   • 4 sequential fallback sources
#
# Usage:
#   ./scripts/fetch_dns_binaries.sh
#   ./scripts/fetch_dns_binaries.sh --arch arm64 --verbose
#   ./scripts/fetch_dns_binaries.sh --offline
#   ./scripts/fetch_dns_binaries.sh --json | jq '.summary'
#
# Environment:
#   GITHUB_TOKEN     — optional; raises GitHub API rate limit
#                      from 60 to 5000 requests/hour
#   DNS_CACHE_DIR    — override cache directory
#   NO_COLOR         — disable colored output
#
# Exit codes:
#   0 — all requested architectures ready
#   1 — at least one architecture failed
#   2 — invalid arguments / missing tools / missing version file
# ============================================================

set -euo pipefail

# ============================================================
# [1] Paths and constants
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DNS_VERSION_FILE="$REPO_ROOT/proxy/dnscrypt-proxy.version"

DEFAULT_CACHE_DIR="${DNS_CACHE_DIR:-${HOME}/.cache/dnscrypt-proxy-webui/dns-binaries}"

DNSCRYPT_REPO="DNSCrypt/dnscrypt-proxy"

# ⚠️ i386, not x86 — matches the dnscrypt-proxy convention on GitHub.
ALL_ARCHS="arm64 arm x86_64 i386"

HTTP_TIMEOUT=30

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
#
# ⚠️ build_candidate_urls uses stdout as its return channel.
#    Any helper invoked from inside it MUST write to stderr.
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
CACHE_DIR=""
SINGLE_ARCH=""
VERSION_OVERRIDE=""

show_help() {
    cat << 'EOF'
DNSCrypt Smart Filter – fetch_dns_binaries.sh

Usage:
  fetch_dns_binaries.sh [options]

Options:
  --arch <name>         Single architecture (arm64|arm|x86_64|i386)
  --cache-dir <dir>     Custom cache directory
  --version <ver>       Override the DNS version (default: from
                        proxy/dnscrypt-proxy.version)
  --offline             Use cache only (no download)
  --force, -f           Force re-download even if cached
  --verbose, -v         More details
  --quiet, -q           Quiet (errors only)
  --json, -j            JSON output (for CI)
  --help, -h            Show this help

Cache:
  The local cache is checked FIRST. A valid cached binary
  short-circuits the entire download path (unless --force).

Fallback sources (attempt order, when download is needed):
  1. GitHub API (actual asset names)
  2. GitHub Releases (2.1.18+: android_X-V.zip)
  3. GitHub Releases (old: android-X-V.zip)
  4. GitHub Releases (underscore: android_X_V.zip)

Examples:
  ./scripts/fetch_dns_binaries.sh
  ./scripts/fetch_dns_binaries.sh --arch arm64 --verbose
  ./scripts/fetch_dns_binaries.sh --offline
  ./scripts/fetch_dns_binaries.sh --json | jq '.summary'
EOF
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --arch)
            shift
            SINGLE_ARCH="${1:-}"
            if [ -z "$SINGLE_ARCH" ]; then
                log_error "--arch requires an architecture"
                exit 2
            fi
            case "$SINGLE_ARCH" in
                arm64|arm|x86_64|i386) ;;
                *)
                    log_error "Unsupported architecture: $SINGLE_ARCH"
                    log_info "Supported: $ALL_ARCHS"
                    exit 2
                    ;;
            esac
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
                log_error "--version requires a value (e.g. 2.1.18)"
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
# [5] Requested architectures
# ============================================================
if [ -n "$SINGLE_ARCH" ]; then
    ARCHS="$SINGLE_ARCH"
else
    ARCHS="$ALL_ARCHS"
fi

# ============================================================
# [6] Cache directory
# ============================================================
if [ -z "$CACHE_DIR" ]; then
    CACHE_DIR="$DEFAULT_CACHE_DIR"
fi

mkdir -p "$CACHE_DIR"
MANIFEST_FILE="$CACHE_DIR/.manifest.json"

# ============================================================
# [7] Read DNS version (SSOT)
# ============================================================
# Resolution: --version override → file → hardcoded fallback.
#
# When --version is used, it BYPASSES proxy/dnscrypt-proxy.version
# (the Single Source of Truth). A warning is emitted so the
# bypass is visible in logs and CI output — otherwise a stale
# override could silently ship binaries from a version the
# repo does not agree with.
read_dns_version() {
    if [ -n "$VERSION_OVERRIDE" ]; then
        log_warn "Using --version override: $VERSION_OVERRIDE (bypasses proxy/dnscrypt-proxy.version)"
        printf '%s' "$VERSION_OVERRIDE"
        return 0
    fi

    if [ -f "$DNS_VERSION_FILE" ]; then
        local v
        v=$(tr -d '\r\n' < "$DNS_VERSION_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi

    log_warn "proxy/dnscrypt-proxy.version missing — using hardcoded fallback 2.1.18" >&2
    printf '2.1.18'
}

DNS_VERSION="$(read_dns_version)"

if ! echo "$DNS_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_error "Invalid DNS version: '$DNS_VERSION'"
    log_info "Format: X.Y.Z (e.g. 2.1.18)"
    exit 2
fi

# ============================================================
# [8] Header
# ============================================================
if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  📥 DNSCrypt DNS Binaries Fetcher                         ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}DNS Version:${NC}  ${GREEN}${DNS_VERSION}${NC}"
    echo -e "  ${BOLD}Cache Dir:${NC}    ${DIM}${CACHE_DIR}${NC}"
    echo -e "  ${BOLD}Archs:${NC}        ${CYAN}${ARCHS}${NC}"
    [ "$OFFLINE" = "1" ] && echo -e "  ${BOLD}Mode:${NC}         ${YELLOW}OFFLINE${NC}"
    [ "$FORCE" = "1" ] && echo -e "  ${BOLD}Force:${NC}        ${YELLOW}YES${NC}"
    echo ""
fi

# ============================================================
# [9] Tool check
# ============================================================
for tool in curl unzip find file; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "Missing tool: $tool"
        exit 2
    fi
done

HAS_SHA256=0
SHA256_CMD=""
if command -v sha256sum >/dev/null 2>&1; then
    HAS_SHA256=1
    SHA256_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    HAS_SHA256=1
    SHA256_CMD="shasum -a 256"
fi

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=1
fi

# ============================================================
# [10] JSON accumulator
# ============================================================
JSON_RESULTS=""
JSON_DOWNLOADED=0
JSON_CACHED=0
JSON_FAILED=0

# ============================================================
# [11] Helpers
# ============================================================
file_size() {
    local out
    out=$(stat -c%s "$1" 2>/dev/null) && [ -n "$out" ] && {
        printf '%s' "$out"
        return 0
    }
    out=$(stat -f%z "$1" 2>/dev/null) && [ -n "$out" ] && {
        printf '%s' "$out"
        return 0
    }
    return 1
}

is_numeric() {
    case "${1:-}" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
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
    local file="$1"
    local sha="$2"
    local version="$3"
    local url="$4"

    [ "$HAS_JQ" = "0" ] && return 0

    local current="{}"
    if [ -f "$MANIFEST_FILE" ]; then
        current=$(cat "$MANIFEST_FILE" 2>/dev/null) || current="{}"
        echo "$current" | jq empty 2>/dev/null || current="{}"
    fi

    local updated
    if ! updated=$(echo "$current" | jq \
        --arg f "$file" \
        --arg s "$sha" \
        --arg v "$version" \
        --arg u "$url" \
        --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.[$f] = {sha256: $s, version: $v, url: $u, fetched_at: $t}' 2>/dev/null); then
        log_debug "manifest_set: jq failed for $file"
        return 1
    fi
    if [ -z "$updated" ]; then
        log_debug "manifest_set: jq returned empty for $file"
        return 1
    fi

    printf '%s\n' "$updated" > "$MANIFEST_FILE"
    return 0
}

# ============================================================
# [12] GitHub API asset-name lookup
# ============================================================
# ⚠️ stdout is the return channel for the asset name. Any
#    diagnostic output MUST go to stderr.
#
# GITHUB_TOKEN is sent to api.github.com (rate-limit benefit),
# NOT to release assets (public CDN).
fetch_asset_name_via_api() {
    local dns_arch="$1"
    local version="$2"
    local api_url="https://api.github.com/repos/${DNSCRYPT_REPO}/releases/tags/${version}"

    [ "$OFFLINE" = "1" ] && return 1

    local curl_args=(-fsSL --max-time "$HTTP_TIMEOUT")
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi

    local response
    response=$(curl "${curl_args[@]}" "$api_url" 2>/dev/null) || {
        log_debug "GitHub API failed for $version"
        return 1
    }

    local asset_name=""
    if [ "$HAS_JQ" = "1" ]; then
        asset_name=$(echo "$response" | jq -r \
            --arg arch "$dns_arch" \
            '.assets[] | select(.name | test("android_" + $arch + "-")) | .name' \
            2>/dev/null | head -n1)
    else
        asset_name=$(echo "$response" \
            | grep -oE '"name":[[:space:]]*"[^"]*"' \
            | sed 's/"name":[[:space:]]*"\([^"]*\)"/\1/' \
            | grep -E "android_${dns_arch}-" \
            | head -n1)
    fi

    if [ -z "$asset_name" ]; then
        log_debug "No asset found for $dns_arch in version $version"
        return 1
    fi

    printf '%s' "$asset_name"
    return 0
}

# ============================================================
# [13] Build candidate URLs
# ============================================================
# ⚠️ stdout is a newline-separated URL list consumed by
#    fetch_arch(). All logging MUST go to stderr.
#
# Guarantee: this function ALWAYS emits at least three URLs —
# the three static fallback patterns below are unconditional.
# The GitHub API lookup is best-effort and may add a fourth.
#
# Therefore the caller can rely on a non-empty result without a
# defensive length check. See fetch_arch() for the consuming
# code path.
build_candidate_urls() {
    local dns_arch="$1"
    local version="$2"

    local base="https://github.com/${DNSCRYPT_REPO}/releases/download/${version}"

    # --- 1) GitHub API (most accurate, best-effort) ---
    local asset_name
    if asset_name=$(fetch_asset_name_via_api "$dns_arch" "$version"); then
        log_debug "API: $asset_name"
        echo "${base}/${asset_name}"
    fi

    # --- 2) Format 2.1.18+ (android_ARCH-VERSION.zip) ---
    echo "${base}/dnscrypt-proxy-android_${dns_arch}-${version}.zip"

    # --- 3) Old format (android-ARCH-VERSION.zip) ---
    echo "${base}/dnscrypt-proxy-android-${dns_arch}-${version}.zip"

    # --- 4) Underscore format (android_ARCH_VERSION.zip) ---
    echo "${base}/dnscrypt-proxy-android_${dns_arch}_${version}.zip"

    return 0
}

# ============================================================
# [14] Download a single URL
# ============================================================
# Uses curl's built-in --retry 2 (3 total attempts, 1s apart)
# for transient failures. The 4-source fallback chain in
# build_candidate_urls handles permanent failures.
#
# GITHUB_TOKEN is NOT sent here. Release asset URLs are public
# and do not require auth; sending the token would risk leaking
# it to a CDN edge node.
download_url() {
    local url="$1"
    local dest="$2"

    local curl_args=(
        -fsSL
        --max-time "$HTTP_TIMEOUT"
        --retry 2
        --retry-delay 1
    )

    log_debug "GET $url"

    if curl "${curl_args[@]}" -o "$dest" "$url" 2>/dev/null; then
        if [ -s "$dest" ]; then
            return 0
        fi
    fi

    rm -f "$dest"
    return 1
}

# ============================================================
# [15] Extract binary from ZIP
# ============================================================
# Entire body runs inside a subshell ( `( ... )` ) so any EXIT
# trap installed inside is isolated from the caller's traps.
# This replaces the previous approach of capturing the caller's
# EXIT trap via `trap -p` and re-installing it with `eval`,
# which was fragile against traps containing shell
# metacharacters.
#
# The subshell's EXIT trap removes $tmp_extract on every path
# — success, failure, and signals — without needing manual
# cleanup on each `return 1`.
extract_binary() {
    local zip_path="$1"
    local output_path="$2"

    (
        set -e

        tmp_extract=$(mktemp -d "${TMPDIR:-/tmp}/dns-extract.XXXXXX")
        # Single-quoted body: $tmp_extract is expanded at trap
        # fire time, not install time.
        trap 'rm -rf "$tmp_extract" 2>/dev/null' EXIT

        if ! unzip -q -o "$zip_path" -d "$tmp_extract" 2>/dev/null; then
            log_error "Failed to unzip: $zip_path"
            exit 1
        fi

        # Prefer a file named dnscrypt-proxy* (excluding docs);
        # fall back to any ELF file.
        found=""
        found=$(find "$tmp_extract" -type f -name "dnscrypt-proxy*" \
            ! -name "*.txt" ! -name "*.md" 2>/dev/null | head -n1)

        if [ -z "$found" ]; then
            found=$(find "$tmp_extract" -type f 2>/dev/null | while IFS= read -r f; do
                if file "$f" 2>/dev/null | grep -qi "ELF"; then
                    echo "$f"
                    break
                fi
            done | head -n1)
        fi

        if [ -z "$found" ] || [ ! -f "$found" ]; then
            log_error "No binary found in ZIP"
            exit 1
        fi

        if ! cp "$found" "$output_path"; then
            log_error "Failed to copy extracted binary to $output_path"
            exit 1
        fi
        chmod 0755 "$output_path"

        exit 0
    )
}

# ============================================================
# [16] Fetch a single architecture
# ============================================================
# Phases:
#   1. Cache hit (unless --force)
#   2. Offline — cannot download
#   3. Download from candidate URLs (bounded by exit-code check)
#   4. Extract binary
#   5. Compute SHA + update manifest
fetch_arch() {
    local dns_arch="$1"
    local version="$2"

    local cache_file="$CACHE_DIR/dnscrypt-proxy-${dns_arch}"

    # ------------------------------------------------------------
    # Phase 1: cache hit
    # ------------------------------------------------------------
    if [ -f "$cache_file" ] && [ -s "$cache_file" ] && [ "$FORCE" = "0" ]; then

        local cached_sha
        cached_sha=$(manifest_get "dnscrypt-proxy-${dns_arch}")

        if [ -n "$cached_sha" ] && [ "$HAS_SHA256" = "1" ]; then
            local actual_sha
            actual_sha=$(file_sha256 "$cache_file")
            if [ "$actual_sha" != "$cached_sha" ]; then
                log_warn "$dns_arch: SHA mismatch — re-downloading"
                rm -f "$cache_file"
            fi
        fi

        if [ -f "$cache_file" ]; then
            local size
            size=$(file_size "$cache_file") || size=""
            if ! is_numeric "$size"; then
                size=0
            fi
            if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
                log_ok "$dns_arch → cache hit (${size} bytes)"
            fi
            JSON_CACHED=$((JSON_CACHED + 1))
            JSON_RESULTS="${JSON_RESULTS}{\"arch\":\"${dns_arch}\",\"status\":\"cached\",\"size\":${size}},"
            return 0
        fi
    fi

    # ------------------------------------------------------------
    # Phase 2: offline
    # ------------------------------------------------------------
    if [ "$OFFLINE" = "1" ]; then
        log_error "$dns_arch: cache missing (offline mode)"
        JSON_FAILED=$((JSON_FAILED + 1))
        JSON_RESULTS="${JSON_RESULTS}{\"arch\":\"${dns_arch}\",\"status\":\"failed\",\"reason\":\"offline_and_no_cache\"},"
        return 1
    fi

    # ------------------------------------------------------------
    # Phase 3: download from candidate URLs
    # ------------------------------------------------------------
    if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
        log_info "$dns_arch → downloading (v${version})..."
    fi

    local tmp_zip="$CACHE_DIR/.tmp-${dns_arch}.zip"
    local downloaded_url=""
    local attempt=0
    local success=0

    # build_candidate_urls always emits at least 3 URLs (see
    # §[13] for the guarantee). No defensive length check is
    # required — the loop below will simply try each in order.
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        [ "$success" = "1" ] && break

        attempt=$((attempt + 1))
        log_debug "Source attempt #${attempt}: ${url}"

        if download_url "$url" "$tmp_zip"; then
            if unzip -l "$tmp_zip" >/dev/null 2>&1; then
                downloaded_url="$url"
                success=1
                log_debug "Success: $url"
            else
                log_debug "Invalid ZIP: $url"
                rm -f "$tmp_zip"
            fi
        fi
    done <<EOF
$(build_candidate_urls "$dns_arch" "$version")
EOF

    if [ "$success" = "0" ]; then
        log_error "$dns_arch: download failed from all sources"
        rm -f "$tmp_zip"
        JSON_FAILED=$((JSON_FAILED + 1))
        JSON_RESULTS="${JSON_RESULTS}{\"arch\":\"${dns_arch}\",\"status\":\"failed\",\"reason\":\"all_sources_failed\"},"
        return 1
    fi

    # ------------------------------------------------------------
    # Phase 4: extract
    # ------------------------------------------------------------
    if ! extract_binary "$tmp_zip" "$cache_file"; then
        rm -f "$tmp_zip" "$cache_file"
        JSON_FAILED=$((JSON_FAILED + 1))
        JSON_RESULTS="${JSON_RESULTS}{\"arch\":\"${dns_arch}\",\"status\":\"failed\",\"reason\":\"extract_failed\"},"
        return 1
    fi

    rm -f "$tmp_zip"

    # ------------------------------------------------------------
    # Phase 5: compute SHA + update manifest
    # ------------------------------------------------------------
    local sha=""
    if [ "$HAS_SHA256" = "1" ]; then
        sha=$(file_sha256 "$cache_file")
    fi

    manifest_set "dnscrypt-proxy-${dns_arch}" "$sha" "$version" "$downloaded_url" 2>/dev/null || true

    local size
    size=$(file_size "$cache_file") || size=""
    if ! is_numeric "$size"; then
        size=0
    fi

    if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
        local sha_short=""
        [ -n "$sha" ] && sha_short="${sha:0:16}"
        log_ok "$dns_arch → ${size} bytes${sha_short:+ (sha256: ${sha_short}...)}"
    fi

    JSON_DOWNLOADED=$((JSON_DOWNLOADED + 1))
    JSON_RESULTS="${JSON_RESULTS}{\"arch\":\"${dns_arch}\",\"status\":\"downloaded\",\"size\":${size},\"url\":\"${downloaded_url}\"},"
    return 0
}

# ============================================================
# [17] Main loop
# ============================================================
TOTAL=0
SUCCESS=0

for arch in $ARCHS; do
    TOTAL=$((TOTAL + 1))
    if fetch_arch "$arch" "$DNS_VERSION"; then
        SUCCESS=$((SUCCESS + 1))
    fi
done

# ============================================================
# [18] Final output
# ============================================================
if [ "$JSON" = "1" ]; then
    JSON_RESULTS="${JSON_RESULTS%,}"
    PASSED=$([ "$SUCCESS" -eq "$TOTAL" ] && echo "true" || echo "false")

    cat << EOF
{
  "version": "${DNS_VERSION}",
  "cache_dir": "${CACHE_DIR}",
  "passed": ${PASSED},
  "summary": {
    "total": ${TOTAL},
    "success": ${SUCCESS},
    "downloaded": ${JSON_DOWNLOADED},
    "cached": ${JSON_CACHED},
    "failed": ${JSON_FAILED}
  },
  "results": [${JSON_RESULTS}]
}
EOF

    if [ "$SUCCESS" -lt "$TOTAL" ]; then
        exit 1
    fi
    exit 0
fi

if [ "$QUIET" = "0" ]; then
    echo ""
    echo -e "${BOLD}━━━ Summary ━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Version:${NC}  ${GREEN}${DNS_VERSION}${NC}"
    echo -e "  ${BOLD}Cache:${NC}    ${DIM}${CACHE_DIR}${NC}"
    echo ""
fi

if [ "$SUCCESS" -eq "$TOTAL" ]; then
    if [ "$QUIET" = "0" ]; then
        echo -e "${GREEN}${BOLD}✅ All architectures ready${NC} (${SUCCESS}/${TOTAL})"
        echo ""
    fi
    exit 0
else
    echo -e "${RED}${BOLD}❌ Some architectures failed${NC} (${SUCCESS}/${TOTAL})" >&2
    echo "" >&2
    exit 1
fi