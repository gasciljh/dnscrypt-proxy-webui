#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – fetch_dns_binaries.sh
# Version: v1.1.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Fetch dnscrypt-proxy binaries for all supported Android
#   architectures. The version is read from the Single Source
#   of Truth file `proxy/dnscrypt-proxy.version`.
#
# Sources (in priority order):
#   1. GitHub API (real asset names)        — most accurate
#   2. android_<arch>-<version>.zip         — 2.1.18+ format
#   3. android-<arch>-<version>.zip         — older format
#   4. android_<arch>_<version>.zip         — underscore format
#   5. jsDelivr CDN mirror                  — fallback
#   6. Local cache                          — offline mode
#
# Features:
#   • 5 fallback sources for resilience
#   • SHA256 verification via `.manifest.json`
#   • Local cache (~/.cache/dnscrypt-proxy-webui/dns-binaries)
#   • Offline mode (--offline)
#   • JSON output for CI (--json)
#   • Idempotent — safe to run multiple times
#
# Retry strategy:
#   There is no explicit retry loop in this script. Resilience
#   comes from two layers:
#     • curl's own --retry 2 (per URL, 1s apart)
#     • 5 sequential fallback sources (if one fails, try the next)
#   This is sufficient for transient failures. For permanent
#   failures (nonexistent version, network down), the script
#   exits with code 1 — callers (package_module.sh, CI) are
#   expected to handle that.
#
#   ⚠️ Earlier versions of this header claimed "Retry logic per
#   source (--retry on CI)". No such --retry flag exists. The
#   claim was inaccurate and has been removed.
#
# DNS version vs module version:
#   This script deals with the dnscrypt-proxy upstream version
#   (e.g. 2.1.18), NOT the module version (e.g. v1.1.0). They
#   are independent:
#     • Module version   → VERSION file (managed by release.sh)
#     • DNS version      → proxy/dnscrypt-proxy.version (this file)
#   Changing the DNS version requires editing only that one file
#   (see docs/DNS_BINARIES.md §10).
#
# Usage:
#   ./scripts/fetch_dns_binaries.sh
#   ./scripts/fetch_dns_binaries.sh --arch arm64 --verbose
#   ./scripts/fetch_dns_binaries.sh --offline
#   ./scripts/fetch_dns_binaries.sh --json | jq '.summary'
#
# Environment:
#   GITHUB_TOKEN      — Optional. Increases GitHub API rate limit
#                       from 60 to 5000 requests/hour.
#   DNS_CACHE_DIR     — Override the default cache directory.
#   NO_COLOR          — Disable colored output.
#
# v1.1.0 changes:
#   • Version bumped to v1.1.0 (documentation only — no behavior
#     changes in this script since v1.0.0).
#   • Removed the unused MAX_RETRIES variable. Retries are handled
#     entirely by curl (--retry 2 per URL) and by the 5-source
#     fallback chain.
#   • Corrected the "Retry logic per source (--retry on CI)" line
#     in the previous header. That flag never existed.
#   • Added an explicit note about the DNS-version / module-version
#     separation, since both are called "version" in the codebase.
# ============================================================

set -euo pipefail

# ============================================================
# [1] Paths and constants
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DNS_VERSION_FILE="$REPO_ROOT/proxy/dnscrypt-proxy.version"

# Default cache directory (can be overridden by --cache-dir or env)
DEFAULT_CACHE_DIR="${DNS_CACHE_DIR:-${HOME}/.cache/dnscrypt-proxy-webui/dns-binaries}"

# dnscrypt-proxy GitHub repo
DNSCRYPT_REPO="DNSCrypt/dnscrypt-proxy"

# Supported architectures (local name → dnscrypt-proxy name on GitHub)
# ⚠️ Note: i386, not x86 (per dnscrypt-proxy convention)
ALL_ARCHS="arm64 arm x86_64 i386"

# Timeout for each HTTP request (seconds)
HTTP_TIMEOUT=30

# ============================================================
# [2] Colors (conditional on TTY and NO_COLOR)
# ============================================================
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

# ============================================================
# [3] Output helpers
# ============================================================
log_info()  { echo -e "  ${CYAN}→${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }
log_debug() { [ "$VERBOSE" = "1" ] && echo -e "  ${DIM}·${NC} $1" || true; }

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
  --version <ver>       DNS version (default: from proxy/dnscrypt-proxy.version)
  --offline             Use cache only (no download)
  --force               Force re-download even if present
  --verbose, -v         More details
  --quiet, -q           Quiet (errors only)
  --json, -j            JSON output (for CI)
  --help, -h            Show this help

Sources (in priority order):
  1. GitHub API (actual asset names)
  2. GitHub Releases (2.1.18+: android_X-V.zip)
  3. GitHub Releases (old: android-X-V.zip)
  4. GitHub Releases (underscore: android_X_V.zip)
  5. jsDelivr CDN (mirror)
  6. Local cache

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
# [5] Determine requested architectures
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
# [7] Read DNS version (Single Source of Truth)
# ============================================================
# ⚠️ This is the dnscrypt-proxy upstream version (e.g. 2.1.18),
#    NOT the module version (e.g. v1.1.0). See the header note.
# ============================================================
read_dns_version() {
    # 1) CLI override
    if [ -n "$VERSION_OVERRIDE" ]; then
        printf '%s' "$VERSION_OVERRIDE"
        return 0
    fi

    # 2) From the version file (Single Source of Truth)
    if [ -f "$DNS_VERSION_FILE" ]; then
        local v
        v=$(tr -d '\r\n' < "$DNS_VERSION_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi

    # 3) Fallback (should not be used after the file is created)
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
MISSING_TOOLS=""
for tool in curl unzip find; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    log_error "Missing tools:$MISSING_TOOLS"
    exit 2
fi

# sha256sum or shasum
HAS_SHA256=0
if command -v sha256sum >/dev/null 2>&1; then
    HAS_SHA256=1
    SHA256_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    HAS_SHA256=1
    SHA256_CMD="shasum -a 256"
fi

# jq (optional — improves parsing)
HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=1
fi

# ============================================================
# [10] Statistics for JSON output
# ============================================================
JSON_RESULTS=""
JSON_DOWNLOADED=0
JSON_CACHED=0
JSON_FAILED=0

# ============================================================
# [11] Helper functions
# ============================================================
file_size() {
    stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo "?"
}

# SHA-256 of the file
file_sha256() {
    [ "$HAS_SHA256" = "0" ] && return 1
    $SHA256_CMD "$1" 2>/dev/null | awk '{print $1}'
}

# ============================================================
# manifest_get — read SHA-256 from manifest
# ============================================================
# Takes a single key (binary name) and returns its SHA-256.
# ============================================================
manifest_get() {
    local key="$1"
    if [ "$HAS_JQ" = "1" ] && [ -f "$MANIFEST_FILE" ]; then
        jq -r --arg k "$key" '.[$k].sha256 // empty' "$MANIFEST_FILE" 2>/dev/null
    fi
}

# Update manifest
manifest_set() {
    local file="$1"
    local sha="$2"
    local version="$3"
    local url="$4"

    if [ "$HAS_JQ" = "0" ]; then
        return 0
    fi

    # Read the current manifest or create a new one
    local current="{}"
    if [ -f "$MANIFEST_FILE" ]; then
        current=$(cat "$MANIFEST_FILE" 2>/dev/null) || current="{}"
        # Validate that it is valid JSON
        if ! echo "$current" | jq empty 2>/dev/null; then
            current="{}"
        fi
    fi

    # Update
    local updated
    updated=$(echo "$current" | jq \
        --arg f "$file" \
        --arg s "$sha" \
        --arg v "$version" \
        --arg u "$url" \
        --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.[$f] = {sha256: $s, version: $v, url: $u, fetched_at: $t}')
    printf '%s\n' "$updated" > "$MANIFEST_FILE"
}

# ============================================================
# [12] GitHub API — fetch the actual asset name
# ============================================================
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

    # Extract the matching asset name
    local asset_name=""
    if [ "$HAS_JQ" = "1" ]; then
        asset_name=$(echo "$response" | jq -r \
            --arg arch "$dns_arch" \
            '.assets[] | select(.name | test("android_" + $arch + "-")) | .name' \
            2>/dev/null | head -n1)
    else
        # Fallback without jq: use regex
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
build_candidate_urls() {
    local dns_arch="$1"
    local version="$2"

    local base="https://github.com/${DNSCRYPT_REPO}/releases/download/${version}"

    # --- 1) GitHub API (most accurate) ---
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

    # --- 5) jsDelivr CDN (mirror) ---
    echo "https://cdn.jsdelivr.net/gh/${DNSCRYPT_REPO}@${version}/dnscrypt-proxy-android_${dns_arch}-${version}.zip"
}

# ============================================================
# [14] Download a single URL
# ============================================================
# Uses curl's built-in --retry 2 (with --retry-delay 1) for
# transient failures. No external retry loop — the 5-source
# fallback chain in [13] handles permanent failures.
# ============================================================
download_url() {
    local url="$1"
    local dest="$2"

    local curl_args=(
        -fsSL
        --max-time "$HTTP_TIMEOUT"
        --retry 2
        --retry-delay 1
    )
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi

    log_debug "GET $url"

    if curl "${curl_args[@]}" -o "$dest" "$url" 2>/dev/null; then
        # Verify that the file is not empty
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
extract_binary() {
    local zip_path="$1"
    local output_path="$2"

    # Create a temporary directory
    local tmp_extract
    tmp_extract=$(mktemp -d "${TMPDIR:-/tmp}/dns-extract.XXXXXX")
    trap "rm -rf '$tmp_extract'" RETURN

    if ! unzip -q -o "$zip_path" -d "$tmp_extract" 2>/dev/null; then
        log_error "Failed to unzip: $zip_path"
        return 1
    fi

    # Find the binary
    local found=""
    found=$(find "$tmp_extract" -type f -name "dnscrypt-proxy*" ! -name "*.txt" ! -name "*.md" 2>/dev/null | head -n1)

    if [ -z "$found" ]; then
        # Fallback: any ELF file
        found=$(find "$tmp_extract" -type f 2>/dev/null | while IFS= read -r f; do
            if file "$f" 2>/dev/null | grep -qi "ELF"; then
                echo "$f"
                break
            fi
        done | head -n1)
    fi

    if [ -z "$found" ] || [ ! -f "$found" ]; then
        log_error "No binary found in ZIP"
        return 1
    fi

    cp "$found" "$output_path"
    chmod 0755 "$output_path"
    return 0
}

# ============================================================
# [16] Fetch a single architecture
# ============================================================
fetch_arch() {
    local dns_arch="$1"
    local version="$2"

    local cache_file="$CACHE_DIR/dnscrypt-proxy-${dns_arch}"

    # ============================================================
    # [16.1] Cache hit (without --force)
    # ============================================================
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
            size=$(file_size "$cache_file")
            if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
                log_ok "$dns_arch → cache hit (${size} bytes)"
            fi
            JSON_CACHED=$((JSON_CACHED + 1))
            JSON_RESULTS="${JSON_RESULTS}{\"arch\":\"${dns_arch}\",\"status\":\"cached\",\"size\":${size}},"
            return 0
        fi
    fi

    # ============================================================
    # [16.2] Offline mode — cannot download
    # ============================================================
    if [ "$OFFLINE" = "1" ]; then
        log_error "$dns_arch: cache missing (offline mode)"
        JSON_FAILED=$((JSON_FAILED + 1))
        JSON_RESULTS="${JSON_RESULTS}{\"arch\":\"${dns_arch}\",\"status\":\"failed\",\"reason\":\"offline_and_no_cache\"},"
        return 1
    fi

    # ============================================================
    # [16.3] Download from sources
    # ============================================================
    if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
        log_info "$dns_arch → downloading (v${version})..."
    fi

    local tmp_zip="$CACHE_DIR/.tmp-${dns_arch}.zip"
    local downloaded_url=""
    local attempt=0
    local success=0

    while IFS= read -r url; do
        [ -z "$url" ] && continue
        [ "$success" = "1" ] && break

        attempt=$((attempt + 1))

        if download_url "$url" "$tmp_zip"; then
            # Verify ZIP is valid (contains at least one file)
            if unzip -l "$tmp_zip" >/dev/null 2>&1; then
                downloaded_url="$url"
                success=1
                log_debug "Success: $url"
            else
                log_debug "Invalid ZIP: $url"
                rm -f "$tmp_zip"
            fi
        fi
    done < <(build_candidate_urls "$dns_arch" "$version")

    if [ "$success" = "0" ]; then
        log_error "$dns_arch: download failed from all sources"
        rm -f "$tmp_zip"
        JSON_FAILED=$((JSON_FAILED + 1))
        JSON_RESULTS="${JSON_RESULTS}{\"arch\":\"${dns_arch}\",\"status\":\"failed\",\"reason\":\"all_sources_failed\"},"
        return 1
    fi

    # ============================================================
    # [16.4] Extract the binary
    # ============================================================
    if ! extract_binary "$tmp_zip" "$cache_file"; then
        rm -f "$tmp_zip" "$cache_file"
        JSON_FAILED=$((JSON_FAILED + 1))
        JSON_RESULTS="${JSON_RESULTS}{\"arch\":\"${dns_arch}\",\"status\":\"failed\",\"reason\":\"extract_failed\"},"
        return 1
    fi

    rm -f "$tmp_zip"

    # ============================================================
    # [16.5] Compute SHA + update manifest
    # ============================================================
    local sha=""
    if [ "$HAS_SHA256" = "1" ]; then
        sha=$(file_sha256 "$cache_file")
    fi

    manifest_set "dnscrypt-proxy-${dns_arch}" "$sha" "$version" "$downloaded_url" 2>/dev/null || true

    local size
    size=$(file_size "$cache_file")

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

# --- JSON mode ---
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

# --- Human mode ---
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