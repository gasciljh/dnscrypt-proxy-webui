#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – package_module.sh
# Version: v1.0.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Build the final Magisk / KernelSU / APatch ZIP for release.
#
#   Combines:
#     • 8 shell scripts (customize, service, post-fs-data,
#       action, status, uninstall, functions, watchdog)
#     • 2 configuration files (webui.conf, dnscrypt-proxy.toml)
#     • 4 WebUI binaries (arm64, arm, amd64, 386)
#     • 4 DNS binaries  (arm64, arm, x86_64, x86)
#     • 13 web/PWA files (HTML + icons + manifest + SW + offline)
#     • module.prop
#
#   Total: 32 required files, verified after packaging.
#
# Features:
#   • Auto-detects BUILD_DIR (proxy/build or ./build)
#   • Uses SOURCE_DATE_EPOCH for reproducible builds
#   • Reuses DNS binaries cache (via fetch_dns_binaries.sh)
#   • Maps i386 ↔ x86 for customize.sh compatibility
#   • Verifies ZIP structure (fails on missing files)
#   • Generates SHA-256 checksum file
#   • Idempotent — safe to run multiple times
#
# Options:
#   --version VERSION      Module version (required)
#   --build-dir DIR        WebUI binaries directory
#   --output-dir DIR       Output directory (default: ./dist)
#   --dns-cache-dir DIR    DNS binaries cache directory
#   --skip-dns-fetch       Use cache only (no download)
#   --keep-staging         Keep staging directory (for diagnostics)
#   --verbose, -v          Verbose
#   --help, -h             Show this help
#
# Environment:
#   SOURCE_DATE_EPOCH      Fixed timestamp (auto from git if unset)
#   DNS_CACHE_DIR          Override the default DNS binaries cache
#   TMPDIR                 Override temp directory for staging
#
# Outputs (in --output-dir):
#   • dnscrypt-webui-<version>-module.zip
#   • dnscrypt-webui-<version>-module.zip.sha256
#
# Examples:
#   ./scripts/package_module.sh --version v1.0.0
#   ./scripts/package_module.sh --version v1.0.0 --skip-dns-fetch
#   ./scripts/package_module.sh --version v1.0.0 --verbose
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# [1] Default settings
# ------------------------------------------------------------
VERSION=""
BUILD_DIR=""
OUTPUT_DIR="./dist"
DNS_CACHE_DIR="${DNS_CACHE_DIR:-${HOME}/.cache/dnscrypt-proxy-webui/dns-binaries}"
SKIP_DNS_FETCH=0
VERBOSE=0
KEEP_STAGING=0

# ------------------------------------------------------------
# [2] Paths
# ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

DNS_VERSION_FILE="$REPO_ROOT/proxy/dnscrypt-proxy.version"
FETCH_SCRIPT="$SCRIPT_DIR/fetch_dns_binaries.sh"

# ------------------------------------------------------------
# [3] Colors
# ------------------------------------------------------------
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

log_info()  { echo -e "  ${CYAN}→${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }
log_debug() { [ "$VERBOSE" = "1" ] && echo -e "  ${DIM}·${NC} $1" || true; }

# ------------------------------------------------------------
# [4] Helper functions
# ------------------------------------------------------------
file_size() {
    stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo "?"
}

sha256_compat() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$@"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$@"
    else
        return 1
    fi
}

# ------------------------------------------------------------
# [5] Arguments
# ------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --version)         VERSION="${2:-}"; shift 2 ;;
        --build-dir)       BUILD_DIR="${2:-}"; shift 2 ;;
        --output-dir)      OUTPUT_DIR="${2:-}"; shift 2 ;;
        --dns-cache-dir)   DNS_CACHE_DIR="${2:-}"; shift 2 ;;
        --skip-dns-fetch)  SKIP_DNS_FETCH=1; shift ;;
        --keep-staging)    KEEP_STAGING=1; shift ;;
        --verbose|-v)      VERBOSE=1; shift ;;
        --help|-h)
            cat << 'HELP_EOF'
DNSCrypt Smart Filter – package_module.sh

Usage:
  package_module.sh --version vX.Y.Z [options]

Options:
  --version VERSION      Module version (required)
  --build-dir DIR        WebUI binaries directory
  --output-dir DIR       Output directory (default: ./dist)
  --dns-cache-dir DIR    DNS binaries cache directory
  --skip-dns-fetch       Use cache only (no download)
  --keep-staging         Keep staging directory (for diagnostics)
  --verbose, -v          Verbose
  --help, -h             Show this help

Examples:
  ./scripts/package_module.sh --version v1.0.0
  ./scripts/package_module.sh --version v1.0.0 --skip-dns-fetch
HELP_EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 2
            ;;
    esac
done

# ------------------------------------------------------------
# [6] Read VERSION
# ------------------------------------------------------------
if [ -z "$VERSION" ]; then
    if [ -f VERSION ]; then
        VERSION=$(tr -d '\r\n' < VERSION | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
        log_error "VERSION not specified and VERSION file missing"
        exit 2
    fi
fi

if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$'; then
    log_error "Invalid version: '$VERSION'"
    log_info "Required format: v<major>.<minor>.<patch>[-prerelease]"
    exit 2
fi

VERSION_NO_V="${VERSION#v}"

# ------------------------------------------------------------
# [7] Read DNS version
# ------------------------------------------------------------
if [ ! -f "$DNS_VERSION_FILE" ]; then
    log_error "Missing: $DNS_VERSION_FILE"
    log_info "Create it with: echo '2.1.18' > $DNS_VERSION_FILE"
    exit 2
fi

DNS_VERSION=$(tr -d '\r\n' < "$DNS_VERSION_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if ! echo "$DNS_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_error "Invalid DNS version: '$DNS_VERSION'"
    exit 2
fi

# ------------------------------------------------------------
# [8] Auto-detect BUILD_DIR
# ------------------------------------------------------------
if [ -z "$BUILD_DIR" ]; then
    for candidate in "$REPO_ROOT/proxy/build" "$REPO_ROOT/build"; do
        if [ -d "$candidate" ] && \
           find "$candidate" -name "dnscrypt-webui-*" -type f 2>/dev/null | grep -q .; then
            BUILD_DIR="$candidate"
            break
        fi
    done
    [ -z "$BUILD_DIR" ] && BUILD_DIR="$REPO_ROOT/proxy/build"
fi

# ------------------------------------------------------------
# [9] SOURCE_DATE_EPOCH
# ------------------------------------------------------------
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
        SOURCE_DATE_EPOCH=$(git log -1 --format=%ct 2>/dev/null || echo 0)
    else
        SOURCE_DATE_EPOCH=0
    fi
fi
export SOURCE_DATE_EPOCH

# ------------------------------------------------------------
# [10] Header
# ------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  📦 package_module.sh                                     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Module VERSION:${NC}  ${GREEN}${VERSION}${NC}"
echo -e "  ${BOLD}DNS Version:${NC}     ${GREEN}${DNS_VERSION}${NC}"
echo -e "  ${BOLD}BUILD_DIR:${NC}       ${DIM}${BUILD_DIR}${NC}"
echo -e "  ${BOLD}OUTPUT_DIR:${NC}      ${DIM}${OUTPUT_DIR}${NC}"
echo -e "  ${BOLD}CACHE_DIR:${NC}       ${DIM}${DNS_CACHE_DIR}${NC}"
echo -e "  ${BOLD}EPOCH:${NC}           ${DIM}${SOURCE_DATE_EPOCH}${NC}"
[ "$SKIP_DNS_FETCH" = "1" ] && echo -e "  ${BOLD}Mode:${NC}            ${YELLOW}SKIP-DNS-FETCH${NC}"
echo ""

# ------------------------------------------------------------
# [11] Check required tools
# ------------------------------------------------------------
MISSING=""
for tool in zip unzip cp find sort mktemp du; do
    command -v "$tool" >/dev/null 2>&1 || MISSING="$MISSING $tool"
done

if [ -n "$MISSING" ]; then
    log_error "Missing tools:$MISSING"
    exit 2
fi

if ! sha256_compat </dev/null >/dev/null 2>&1; then
    log_error "Neither sha256sum nor shasum available"
    exit 2
fi

log_ok "Required tools available"

# ------------------------------------------------------------
# [12] Check project structure
# ------------------------------------------------------------
[ -d "$REPO_ROOT/proxy" ] || { log_error "proxy/ directory missing"; exit 2; }
[ -d "$REPO_ROOT/web" ]   || { log_error "web/ directory missing"; exit 2; }
[ -f "$REPO_ROOT/module.prop" ] || { log_error "module.prop missing"; exit 2; }

# ------------------------------------------------------------
# [13] Check web files (13 files)
# ------------------------------------------------------------
WEB_FILES_REQUIRED=(
    "index.html"
    "dashboard.html"
    "manifest.json"
    "sw.js"
    "icon-192.svg"
    "icon-512.svg"
    "icon-192.png"
    "icon-512.png"
    "apple-touch-icon.png"
    "favicon-32x32.png"
    "favicon-16x16.png"
    "favicon.ico"
    "offline.html"
)

WEB_MISSING=0
for f in "${WEB_FILES_REQUIRED[@]}"; do
    if [ ! -f "$REPO_ROOT/web/$f" ]; then
        log_error "Missing: web/$f"
        WEB_MISSING=$((WEB_MISSING + 1))
    fi
done

if [ "$WEB_MISSING" -gt 0 ]; then
    log_error "$WEB_MISSING web file(s) missing"
    log_info "Run: ./scripts/generate-icons.sh"
    exit 1
fi

log_ok "All web files present (${#WEB_FILES_REQUIRED[@]} files)"

# ------------------------------------------------------------
# [14] Check WebUI binaries (4 architectures)
# ------------------------------------------------------------
WEBUI_ARCHS="arm64 arm amd64 386"

for arch in $WEBUI_ARCHS; do
    bin="$BUILD_DIR/dnscrypt-webui-$arch"
    if [ ! -f "$bin" ]; then
        log_error "Missing: $bin"
        log_info "Run first: ./proxy/build.sh --clean --parallel"
        exit 1
    fi
    [ -x "$bin" ] || chmod 0755 "$bin"
done

log_ok "4 WebUI binaries present in $BUILD_DIR"

# ------------------------------------------------------------
# [15] Prepare DNS binaries
# ------------------------------------------------------------
DNS_BINARIES_REQUIRED=(
    "dnscrypt-proxy-arm64"
    "dnscrypt-proxy-arm"
    "dnscrypt-proxy-x86_64"
    "dnscrypt-proxy-x86"
)

map_to_cache_name() {
    case "$1" in
        dnscrypt-proxy-x86)    echo "dnscrypt-proxy-i386" ;;
        dnscrypt-proxy-x86_64) echo "dnscrypt-proxy-x86_64" ;;
        dnscrypt-proxy-arm64)  echo "dnscrypt-proxy-arm64" ;;
        dnscrypt-proxy-arm)    echo "dnscrypt-proxy-arm" ;;
        *) echo "$1" ;;
    esac
}

check_cache_complete() {
    local missing=0
    for name in "${DNS_BINARIES_REQUIRED[@]}"; do
        local cache_name
        cache_name=$(map_to_cache_name "$name")
        local f="$DNS_CACHE_DIR/$cache_name"
        if [ ! -f "$f" ] || [ ! -s "$f" ]; then
            log_debug "cache miss: $cache_name"
            missing=$((missing + 1))
        fi
    done
    [ "$missing" -eq 0 ]
}

mkdir -p "$DNS_CACHE_DIR"

if check_cache_complete; then
    log_ok "All DNS binaries present in cache"
else
    log_info "Some DNS binaries are missing from cache"

    if [ "$SKIP_DNS_FETCH" = "1" ]; then
        log_error "Cannot fetch binaries (--skip-dns-fetch)"
        log_info "Add binaries manually to: $DNS_CACHE_DIR"
        log_info "Or run: ./scripts/fetch_dns_binaries.sh"
        exit 1
    fi

    if [ ! -f "$FETCH_SCRIPT" ]; then
        log_error "Missing: $FETCH_SCRIPT"
        exit 1
    fi

    [ -x "$FETCH_SCRIPT" ] || chmod +x "$FETCH_SCRIPT"

    log_info "Invoking: scripts/fetch_dns_binaries.sh"
    echo ""

    FETCH_ARGS=(
        "--cache-dir" "$DNS_CACHE_DIR"
        "--version" "$DNS_VERSION"
    )
    [ "$VERBOSE" = "1" ] && FETCH_ARGS+=("--verbose")

    if ! "$FETCH_SCRIPT" "${FETCH_ARGS[@]}"; then
        log_error "fetch_dns_binaries.sh failed"
        exit 1
    fi

    echo ""
    log_ok "fetch_dns_binaries.sh succeeded"
fi

# Check reasonable size (>= 3 MB)
for name in "${DNS_BINARIES_REQUIRED[@]}"; do
    cache_name=$(map_to_cache_name "$name")
    f="$DNS_CACHE_DIR/$cache_name"
    if [ ! -f "$f" ]; then
        log_error "Missing after fetch: $cache_name"
        exit 1
    fi
    size=$(file_size "$f")
    if [ "$size" -lt 3145728 ]; then
        log_error "$cache_name is too small ($size bytes)"
        log_info "The file may be corrupt — re-download with:"
        log_info "  ./scripts/fetch_dns_binaries.sh --force"
        exit 1
    fi
    log_debug "$cache_name: $size bytes"
done

log_ok "4 DNS binaries ready"

# ------------------------------------------------------------
# [16] Create staging
# ------------------------------------------------------------
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/dnscrypt-pkg.XXXXXX")
trap '[ "$KEEP_STAGING" = "0" ] && rm -rf "$STAGING"' EXIT

mkdir -p "$STAGING/proxy" "$STAGING/web"

# --- module.prop ---
cp "$REPO_ROOT/module.prop" "$STAGING/module.prop"

# --- Shell scripts (8) ---
for s in customize.sh service.sh post-fs-data.sh action.sh status.sh uninstall.sh functions.sh watchdog.sh; do
    src="$REPO_ROOT/proxy/$s"
    [ -f "$src" ] || { log_error "Missing: proxy/$s"; exit 1; }
    cp "$src" "$STAGING/$s"
    chmod 0755 "$STAGING/$s"
done

# --- Config (2) ---
for f in dnscrypt-proxy.toml webui.conf; do
    src="$REPO_ROOT/proxy/$f"
    [ -f "$src" ] || { log_error "Missing: proxy/$f"; exit 1; }
    cp "$src" "$STAGING/proxy/$f"
    chmod 0600 "$STAGING/proxy/$f"
done

# --- WebUI binaries (4) ---
for arch in $WEBUI_ARCHS; do
    cp "$BUILD_DIR/dnscrypt-webui-$arch" "$STAGING/proxy/"
    chmod 0755 "$STAGING/proxy/dnscrypt-webui-$arch"
done

# --- DNS binaries (4) ---
for name in "${DNS_BINARIES_REQUIRED[@]}"; do
    cache_name=$(map_to_cache_name "$name")
    src="$DNS_CACHE_DIR/$cache_name"
    [ -f "$src" ] || { log_error "Missing: $src"; exit 1; }
    cp "$src" "$STAGING/proxy/$name"
    chmod 0755 "$STAGING/proxy/$name"
done

# --- Web files (13) ---
for f in "${WEB_FILES_REQUIRED[@]}"; do
    src="$REPO_ROOT/web/$f"
    [ -f "$src" ] || { log_error "Missing: web/$f"; exit 1; }
    cp "$src" "$STAGING/web/$f"
    chmod 0644 "$STAGING/web/$f"
done

staging_size=$(du -sh "$STAGING" 2>/dev/null | cut -f1)
log_ok "staging ready ($staging_size)"

# ------------------------------------------------------------
# [17] Reproducibility (set timestamps)
# ------------------------------------------------------------
if ! find "$STAGING" -exec touch -d "@${SOURCE_DATE_EPOCH}" {} + 2>/dev/null; then
    find "$STAGING" -exec touch -t "202001010000.00" {} + 2>/dev/null || \
        log_warn "Failed to set timestamps — ZIP may not be reproducible"
fi

log_ok "timestamps set"

# ------------------------------------------------------------
# [18] Create ZIP
# ------------------------------------------------------------
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" && pwd)"

OUTPUT_NAME="dnscrypt-webui-${VERSION_NO_V}-module.zip"
OUTPUT_PATH="$OUTPUT_DIR_ABS/$OUTPUT_NAME"

rm -f "$OUTPUT_PATH"

FILELIST="$STAGING/.filelist.txt"
(cd "$STAGING" && find . -type f -not -name ".filelist.txt" | LC_ALL=C sort > "$FILELIST")

if [ ! -s "$FILELIST" ]; then
    log_error "File list is empty"
    exit 1
fi

FILE_COUNT=$(wc -l < "$FILELIST")
log_info "File count: $FILE_COUNT"

if ! (cd "$STAGING" && zip -X -q "$OUTPUT_PATH" -@ < "$FILELIST"); then
    log_error "Failed to create ZIP"
    exit 1
fi

rm -f "$FILELIST"

if [ ! -f "$OUTPUT_PATH" ]; then
    log_error "ZIP was not created"
    exit 1
fi

zip_size=$(file_size "$OUTPUT_PATH")
zip_size_human=$(du -h "$OUTPUT_PATH" | cut -f1)
log_ok "ZIP: $OUTPUT_NAME ($zip_size_human)"

# ------------------------------------------------------------
# [19] Verify ZIP structure (32 required files)
# ------------------------------------------------------------
REQUIRED_IN_ZIP=(
    "module.prop"

    "customize.sh"
    "service.sh"
    "post-fs-data.sh"
    "action.sh"
    "status.sh"
    "uninstall.sh"
    "functions.sh"
    "watchdog.sh"

    "proxy/dnscrypt-proxy.toml"
    "proxy/webui.conf"

    "proxy/dnscrypt-proxy-arm64"
    "proxy/dnscrypt-proxy-arm"
    "proxy/dnscrypt-proxy-x86_64"
    "proxy/dnscrypt-proxy-x86"

    "proxy/dnscrypt-webui-arm64"
    "proxy/dnscrypt-webui-arm"
    "proxy/dnscrypt-webui-amd64"
    "proxy/dnscrypt-webui-386"

    "web/index.html"
    "web/dashboard.html"
    "web/manifest.json"
    "web/sw.js"
    "web/icon-192.svg"
    "web/icon-512.svg"
    "web/icon-192.png"
    "web/icon-512.png"
    "web/apple-touch-icon.png"
    "web/favicon-32x32.png"
    "web/favicon-16x16.png"
    "web/favicon.ico"
    "web/offline.html"
)

ZIP_CONTENTS=$(unzip -l "$OUTPUT_PATH" 2>/dev/null | awk '{print $4}')

MISSING_IN_ZIP=0
for item in "${REQUIRED_IN_ZIP[@]}"; do
    if ! echo "$ZIP_CONTENTS" | grep -qFx "$item"; then
        log_error "ZIP missing: $item"
        MISSING_IN_ZIP=$((MISSING_IN_ZIP + 1))
    fi
done

if [ "$MISSING_IN_ZIP" -gt 0 ]; then
    log_error "ZIP incomplete: $MISSING_IN_ZIP file(s)"
    exit 1
fi

log_ok "ZIP structure valid (${#REQUIRED_IN_ZIP[@]} files)"

# Additional stats
PNG_COUNT=$(echo "$ZIP_CONTENTS" | grep -cE '^web/.*\.png$' || echo 0)
ICO_COUNT=$(echo "$ZIP_CONTENTS" | grep -cE '^web/.*\.ico$' || echo 0)
SVG_COUNT=$(echo "$ZIP_CONTENTS" | grep -cE '^web/.*\.svg$' || echo 0)

log_info "Icons: ${PNG_COUNT} PNG + ${SVG_COUNT} SVG + ${ICO_COUNT} ICO"

# ------------------------------------------------------------
# [20] SHA-256 checksum
# ------------------------------------------------------------
CHECKSUM_FILE="$OUTPUT_DIR_ABS/${OUTPUT_NAME}.sha256"
(cd "$OUTPUT_DIR_ABS" && sha256_compat "$OUTPUT_NAME" > "${OUTPUT_NAME}.sha256")

if [ ! -f "$CHECKSUM_FILE" ]; then
    log_error "Failed to create checksum"
    exit 1
fi

SHA256_HASH=$(awk '{print $1}' "$CHECKSUM_FILE")
log_ok "checksum: ${SHA256_HASH:0:16}..."

# ------------------------------------------------------------
# [21] Final summary
# ------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ${GREEN}✅ Package created successfully${NC}                          ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}ZIP:${NC}            ${GREEN}${OUTPUT_PATH}${NC}"
echo -e "  ${BOLD}Size:${NC}           ${zip_size_human} (${zip_size} bytes)"
echo -e "  ${BOLD}Module Ver:${NC}     ${VERSION}"
echo -e "  ${BOLD}DNS Engine:${NC}     ${DNS_VERSION}"
echo -e "  ${BOLD}DNS Cache:${NC}      ${DIM}${DNS_CACHE_DIR}${NC}"
echo -e "  ${BOLD}SHA-256:${NC}        ${SHA256_HASH}"
echo -e "  ${BOLD}Checksum:${NC}       ${CHECKSUM_FILE}"
echo ""
echo -e "  ${BOLD}web/ contents:${NC}"
echo -e "    ${DIM}• HTML:${NC}     2 files"
echo -e "    ${DIM}• Manifest:${NC} 1 file"
echo -e "    ${DIM}• SW:${NC}       1 file"
echo -e "    ${DIM}• SVG:${NC}      ${SVG_COUNT} file(s)"
echo -e "    ${DIM}• PNG:${NC}      ${PNG_COUNT} file(s)"
echo -e "    ${DIM}• ICO:${NC}      ${ICO_COUNT} file(s)"
echo -e "    ${DIM}• Offline:${NC}  1 file"
echo ""

if [ "$VERBOSE" = "1" ]; then
    echo -e "${BOLD}ZIP contents:${NC}"
    unzip -l "$OUTPUT_PATH" | tail -n +4 | head -n -2
    echo ""
fi

exit 0