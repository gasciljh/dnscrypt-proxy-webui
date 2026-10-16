#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – package_module.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-15
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Build the final Magisk / KernelSU / APatch ZIP for release.
#
# Combines:
#   • 10 shell scripts (customize, service, post-fs-data,
#     action, status, uninstall, functions, boot-mini,
#     watchdog, install_app)
#   • 2 config files (webui.conf, dnscrypt-proxy.toml)
#   • 4 WebUI binaries (arm64, arm, amd64, 386)
#   • 4 DNS binaries   (arm64, arm, x86_64, x86)
#   • 13 required web files + 2 optional
#     (app-debug.apk, app-debug.apk.sha256)
#   • module.prop
#
# Total: 36 entries (34 required + 2 optional), verified
# after packaging.
#
# Options:
#   --version VERSION      Module version (required)
#   --build-dir DIR        WebUI binaries directory
#   --output-dir DIR       Output directory (default: ./dist)
#   --dns-cache-dir DIR    DNS binaries cache directory
#   --skip-dns-fetch       Use cache only (no download)
#   --keep-staging         Keep staging directory (diagnostics)
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
# Reproducibility:
#   • SOURCE_DATE_EPOCH is applied to every file in staging via
#     `touch -d @N`. A capability probe runs first; if `touch`
#     does not support `-d @N`, the script aborts rather than
#     silently shipping a non-reproducible artifact.
#   • `zip -X` excludes extra file attributes.
#   • `find | LC_ALL=C sort` guarantees deterministic order.
# ============================================================

set -euo pipefail

# ============================================================
# [1] Default settings
# ============================================================
VERSION=""
BUILD_DIR=""
OUTPUT_DIR="./dist"
DNS_CACHE_DIR="${DNS_CACHE_DIR:-${HOME}/.cache/dnscrypt-proxy-webui/dns-binaries}"
SKIP_DNS_FETCH=0
VERBOSE=0
KEEP_STAGING=0

# ============================================================
# [2] Paths
# ============================================================
# After the `cd` below, every relative path — including the one
# passed via --output-dir or --build-dir — resolves against
# REPO_ROOT, not the caller's original cwd. The resolved
# absolute path is printed in [7d].
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

DNS_VERSION_FILE="$REPO_ROOT/proxy/dnscrypt-proxy.version"
FETCH_SCRIPT="$SCRIPT_DIR/fetch_dns_binaries.sh"

# ============================================================
# [3] Colors
# ============================================================
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

# ============================================================
# [4] Logging
# ============================================================
# Stream discipline: info/ok → stdout; warn/error/debug → stderr.
log_info()  { echo -e "  ${CYAN}→${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }

log_debug() {
    if [ "$VERBOSE" = "1" ]; then
        echo -e "  ${DIM}·${NC} $1" >&2
    fi
    return 0
}

# ============================================================
# [5] Helpers
# ============================================================
# file_size — returns size in bytes, or returns 1 on failure.
# Callers MUST validate numeric output before using it in an
# arithmetic context.
file_size() {
    local out
    out=$(stat -c%s "$1" 2>/dev/null) && [ -n "$out" ] && { printf '%s' "$out"; return 0; }
    out=$(stat -f%z "$1" 2>/dev/null) && [ -n "$out" ] && { printf '%s' "$out"; return 0; }
    return 1
}

is_numeric() {
    case "${1:-}" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

# count_matches — count matching lines in a stream.
#
# Note: GNU grep -c prints "0" on no-match but exits 1. The
# `|| true` silences the exit code without touching stdout.
# Do NOT rewrite as `grep ... || printf '0'` — that would
# append an extra "0" after grep's own output ("00").
count_matches() {
    local pattern="$1"
    local n
    n=$(grep -cE "$pattern" 2>/dev/null) || true
    [ -z "$n" ] && n=0
    printf '%s' "$n"
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

# calc_version_code — canonical versionCode from a SemVer string.
#
#   versionCode = MAJOR × 1,000,000
#               + MINOR ×    10,000
#               + PATCH ×       100
#
# Prerelease suffixes are ignored. Leading zeros are stripped
# before arithmetic so "01" does not trigger bash octal errors.
calc_version_code() {
    local v="${1#v}"
    local core="${v%%-*}"
    local major minor patch

    major=$(echo "$core" | cut -d. -f1 | sed 's/^0*//')
    minor=$(echo "$core" | cut -d. -f2 | sed 's/^0*//')
    patch=$(echo "$core" | cut -d. -f3 | sed 's/^0*//')

    [ -z "$major" ] && major=0
    [ -z "$minor" ] && minor=0
    [ -z "$patch" ] && patch=0

    echo $((major * 1000000 + minor * 10000 + patch * 100))
}

# ============================================================
# [6] Arguments
# ============================================================
while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            [ -n "${2:-}" ] || { log_error "--version requires a value"; exit 2; }
            VERSION="$2"; shift 2
            ;;
        --build-dir)
            [ -n "${2:-}" ] || { log_error "--build-dir requires a value"; exit 2; }
            BUILD_DIR="$2"; shift 2
            ;;
        --output-dir)
            [ -n "${2:-}" ] || { log_error "--output-dir requires a value"; exit 2; }
            OUTPUT_DIR="$2"; shift 2
            ;;
        --dns-cache-dir)
            [ -n "${2:-}" ] || { log_error "--dns-cache-dir requires a value"; exit 2; }
            DNS_CACHE_DIR="$2"; shift 2
            ;;
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
                         NOTE: relative paths are resolved against
                         the repository root, not the caller's cwd.
  --dns-cache-dir DIR    DNS binaries cache directory
  --skip-dns-fetch       Use cache only (no download)
  --keep-staging         Keep staging directory (for diagnostics)
  --verbose, -v          Verbose
  --help, -h             Show this help

Examples:
  ./scripts/package_module.sh --version v1.5.0
  ./scripts/package_module.sh --version v1.5.0 --skip-dns-fetch
  ./scripts/package_module.sh --version v1.5.0 --output-dir /tmp/out
HELP_EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 2
            ;;
    esac
done

# ============================================================
# [7] Read + validate VERSION
# ============================================================
if [ -z "$VERSION" ]; then
    if [ -f VERSION ]; then
        VERSION=$(tr -d '\r\n' < VERSION | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
        log_error "VERSION not specified and VERSION file missing"
        exit 2
    fi
fi

# Accept optional SemVer build metadata (`+...`) in addition to
# the prerelease suffix.
if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$'; then
    log_error "Invalid version: '$VERSION'"
    log_info "Required format: v<major>.<minor>.<patch>[-prerelease][+build]"
    exit 2
fi

VERSION_NO_V="${VERSION#v}"

# ============================================================
# [7b] Verify module.prop matches $VERSION
# ============================================================
if [ ! -f "$REPO_ROOT/module.prop" ]; then
    log_error "Missing: module.prop"
    exit 2
fi

MODPROP_VERSION=$(grep '^version=' "$REPO_ROOT/module.prop" | head -n1 | cut -d= -f2- | tr -d '\r ')
MODPROP_VC=$(grep '^versionCode=' "$REPO_ROOT/module.prop" | head -n1 | cut -d= -f2- | tr -d '\r ')

if [ -z "$MODPROP_VERSION" ]; then
    log_error "module.prop has no 'version=' line"
    exit 2
fi

if [ "$MODPROP_VERSION" != "$VERSION" ]; then
    log_error "Version mismatch between --version and module.prop"
    log_info "  --version:   $VERSION"
    log_info "  module.prop: $MODPROP_VERSION"
    log_info "Run 'scripts/release.sh' to update both consistently,"
    log_info "or pass --version '$MODPROP_VERSION' to package the current tree."
    exit 2
fi

EXPECTED_VC=$(calc_version_code "$VERSION")
if [ -z "$MODPROP_VC" ]; then
    log_warn "module.prop has no 'versionCode=' line"
elif ! is_numeric "$MODPROP_VC"; then
    log_warn "module.prop versionCode is not numeric: '$MODPROP_VC'"
    log_warn "  expected: $EXPECTED_VC (MAJOR*1M + MINOR*10K + PATCH*100)"
elif [ "$MODPROP_VC" != "$EXPECTED_VC" ]; then
    log_warn "versionCode does not match the canonical formula"
    log_warn "  module.prop: $MODPROP_VC"
    log_warn "  expected:    $EXPECTED_VC (MAJOR*1M + MINOR*10K + PATCH*100)"
    log_warn "This is a warning only — release.sh should keep these in sync."
fi

# ============================================================
# [7c] Verify update.json matches $VERSION
# ============================================================
UPDATE_JSON="$REPO_ROOT/update.json"
if [ -f "$UPDATE_JSON" ]; then
    UPDATE_JSON_VERSION=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$UPDATE_JSON" \
        | head -n1 \
        | sed -E 's/.*"([^"]*)"$/\1/') || UPDATE_JSON_VERSION=""

    if [ -z "$UPDATE_JSON_VERSION" ]; then
        log_warn "update.json has no parseable 'version' field"
    elif [ "$UPDATE_JSON_VERSION" != "$VERSION" ]; then
        log_warn "update.json version does not match --version"
        log_warn "  update.json: $UPDATE_JSON_VERSION"
        log_warn "  --version:   $VERSION"
        log_warn "Users who already installed the module will NOT see the update"
        log_warn "until update.json is regenerated by scripts/release.sh."
    fi

    UPDATE_JSON_URL=$(grep -oE '"zipUrl"[[:space:]]*:[[:space:]]*"[^"]*"' "$UPDATE_JSON" \
        | head -n1 \
        | sed -E 's/.*"([^"]*)"$/\1/') || UPDATE_JSON_URL=""
    if [ -n "$UPDATE_JSON_URL" ]; then
        EXPECTED_URL_SUFFIX="dnscrypt-webui-${VERSION_NO_V}-module.zip"
        case "$UPDATE_JSON_URL" in
            *"$EXPECTED_URL_SUFFIX") : ;;
            *)
                log_warn "update.json zipUrl filename does not match the ZIP we are building"
                log_warn "  zipUrl:   $UPDATE_JSON_URL"
                log_warn "  expected: .../$EXPECTED_URL_SUFFIX"
                ;;
        esac
    fi
else
    log_warn "update.json not found — skipping consistency check"
fi

# ============================================================
# [7d] Verify OUTPUT_DIR is writable early
# ============================================================
# Because [2] `cd`'d into REPO_ROOT, a relative --output-dir is
# resolved against REPO_ROOT. Print the resolved absolute path
# so the caller sees exactly which directory was created.
if ! mkdir -p "$OUTPUT_DIR" 2>/dev/null; then
    log_error "Cannot create OUTPUT_DIR: $OUTPUT_DIR"
    exit 2
fi
OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" && pwd)"

if [ ! -w "$OUTPUT_DIR_ABS" ]; then
    log_error "OUTPUT_DIR is not writable: $OUTPUT_DIR_ABS"
    exit 2
fi

log_debug "OUTPUT_DIR resolved to: $OUTPUT_DIR_ABS"

# ============================================================
# [8] Read DNS version
# ============================================================
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

# ============================================================
# [9] Auto-detect BUILD_DIR
# ============================================================
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

# ============================================================
# [10] SOURCE_DATE_EPOCH
# ============================================================
# Resolution: caller env → git commit → 0.
#
# Validation is strict: any value that is not a non-negative
# decimal integer (including negative values like "-1") is
# coerced to 0 with a warning. is_numeric() rejects the minus
# sign, so the negative case is covered by the same guard.
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
        SOURCE_DATE_EPOCH=$(git log -1 --format=%ct 2>/dev/null || echo 0)
    else
        SOURCE_DATE_EPOCH=0
    fi
fi
if ! is_numeric "$SOURCE_DATE_EPOCH"; then
    log_warn "SOURCE_DATE_EPOCH is not a non-negative integer ('$SOURCE_DATE_EPOCH'); using 0"
    SOURCE_DATE_EPOCH=0
fi
export SOURCE_DATE_EPOCH

# ============================================================
# [11] Header
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  📦 package_module.sh                                    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Module VERSION:${NC}  ${GREEN}${VERSION}${NC}"
echo -e "  ${BOLD}module.prop:${NC}     ${GREEN}${MODPROP_VERSION}${NC} (verified)"
echo -e "  ${BOLD}versionCode:${NC}     ${GREEN}${MODPROP_VC}${NC} (expected ${EXPECTED_VC})"
echo -e "  ${BOLD}DNS Version:${NC}     ${GREEN}${DNS_VERSION}${NC}"
echo -e "  ${BOLD}BUILD_DIR:${NC}       ${DIM}${BUILD_DIR}${NC}"
echo -e "  ${BOLD}OUTPUT_DIR:${NC}      ${DIM}${OUTPUT_DIR_ABS}${NC}"
echo -e "  ${BOLD}CACHE_DIR:${NC}       ${DIM}${DNS_CACHE_DIR}${NC}"
echo -e "  ${BOLD}EPOCH:${NC}           ${DIM}${SOURCE_DATE_EPOCH}${NC}"
[ "$SKIP_DNS_FETCH" = "1" ] && echo -e "  ${BOLD}Mode:${NC}            ${YELLOW}SKIP-DNS-FETCH${NC}"
echo ""

# ============================================================
# [12] Required tools
# ============================================================
MISSING=""
for tool in zip unzip cp find sort mktemp du; do
    command -v "$tool" >/dev/null 2>&1 || MISSING="$MISSING $tool"
done

if [ -n "$MISSING" ]; then
    log_error "Missing tools:$MISSING"
    exit 2
fi

if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    log_error "Neither sha256sum nor shasum available"
    exit 2
fi

log_ok "Required tools available"

# ============================================================
# [13] Project structure
# ============================================================
[ -d "$REPO_ROOT/proxy" ] || { log_error "proxy/ directory missing"; exit 2; }
[ -d "$REPO_ROOT/web" ]   || { log_error "web/ directory missing"; exit 2; }

# ============================================================
# [14] Web files
# ============================================================
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

WEB_FILES_OPTIONAL=(
    "app-debug.apk"
    "app-debug.apk.sha256"
)

WEB_MISSING=0
WEB_MISSING_ICONS=0
WEB_MISSING_HTML=0

for f in "${WEB_FILES_REQUIRED[@]}"; do
    if [ ! -s "$REPO_ROOT/web/$f" ]; then
        if [ -f "$REPO_ROOT/web/$f" ]; then
            log_error "Empty: web/$f"
        else
            log_error "Missing: web/$f"
        fi
        WEB_MISSING=$((WEB_MISSING + 1))
        case "$f" in
            icon-*.svg|icon-*.png|apple-touch-icon.png|favicon-*|favicon.ico)
                WEB_MISSING_ICONS=$((WEB_MISSING_ICONS + 1))
                ;;
            *.html)
                WEB_MISSING_HTML=$((WEB_MISSING_HTML + 1))
                ;;
        esac
    fi
done

for f in "${WEB_FILES_OPTIONAL[@]}"; do
    if [ ! -s "$REPO_ROOT/web/$f" ]; then
        log_warn "Optional web file missing: web/$f (skipping)"
    fi
done

if [ "$WEB_MISSING" -gt 0 ]; then
    log_error "$WEB_MISSING required web file(s) missing or empty"
    if [ "$WEB_MISSING_ICONS" -gt 0 ]; then
        log_info "Regenerate icons with: ./scripts/generate-icons.sh"
    fi
    if [ "$WEB_MISSING_HTML" -gt 0 ]; then
        log_info "HTML files are tracked in git; verify your checkout."
        log_info "  git status web/"
    fi
    exit 1
fi

log_ok "All required web files present (13 required)"

# ============================================================
# [15] WebUI binaries
# ============================================================
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

# ============================================================
# [16] DNS binaries
# ============================================================
DNS_BINARIES_REQUIRED=(
    "dnscrypt-proxy-arm64"
    "dnscrypt-proxy-arm"
    "dnscrypt-proxy-x86_64"
    "dnscrypt-proxy-x86"
)

# Map module-side name → cache-side name. The only mismatch is
# x86 → i386 (dnscrypt-proxy convention on GitHub).
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

# Size check (>= 3 MB). This is the HARD-FAIL call site — a
# binary whose size cannot be stat'd is corrupt/unreadable and
# must NOT ship. Compare with the SOFT-FAIL site below for ZIP
# size (informational only).
for name in "${DNS_BINARIES_REQUIRED[@]}"; do
    cache_name=$(map_to_cache_name "$name")
    f="$DNS_CACHE_DIR/$cache_name"
    if [ ! -f "$f" ]; then
        log_error "Missing after fetch: $cache_name"
        exit 1
    fi
    size=$(file_size "$f" || true)
    if ! is_numeric "$size"; then
        log_error "Cannot stat size of $cache_name (stat failed)"
        exit 1
    fi
    if [ "$size" -lt 3145728 ]; then
        log_error "$cache_name is too small ($size bytes)"
        log_info "The file may be corrupt — re-download with:"
        log_info "  ./scripts/fetch_dns_binaries.sh --force"
        exit 1
    fi
    log_debug "$cache_name: $size bytes"
done

log_ok "4 DNS binaries ready"

# ============================================================
# [17] Create staging
# ============================================================
# Strip ALL trailing slashes from TMPDIR, not just one, so a
# value like "/tmp///" normalizes cleanly.
_TMPDIR_CLEAN="${TMPDIR:-/tmp}"
while [ "${_TMPDIR_CLEAN%/}" != "$_TMPDIR_CLEAN" ]; do
    _TMPDIR_CLEAN="${_TMPDIR_CLEAN%/}"
done
[ -z "$_TMPDIR_CLEAN" ] && _TMPDIR_CLEAN="/tmp"

STAGING=$(mktemp -d "${_TMPDIR_CLEAN}/dnscrypt-pkg.XXXXXX")

# Cleanup trap: three handlers with a shared re-entry guard.
# The staged directory is only removed when KEEP_STAGING=0.
# The _CLEANED_UP flag prevents double-cleanup when the INT or
# TERM handler's `exit` triggers the EXIT handler.
_STAGING_CLEANED=0

_cleanup_staging() {
    [ "$_STAGING_CLEANED" = "1" ] && return 0
    _STAGING_CLEANED=1

    if [ "$KEEP_STAGING" = "0" ] && [ -n "${STAGING:-}" ] && [ -d "$STAGING" ]; then
        rm -rf "$STAGING" 2>/dev/null
    fi
    return 0
}

# shellcheck disable=SC2329  # invoked via traps below
trap '_cleanup_staging' EXIT
trap '_cleanup_staging; exit 130' INT
trap '_cleanup_staging; exit 143' TERM

mkdir -p "$STAGING/proxy" "$STAGING/web"

# --- module.prop ---
cp "$REPO_ROOT/module.prop" "$STAGING/module.prop"

# --- Shell scripts (10) ---
# boot-mini.sh is at the module root after install, because
# functions.sh sources it at load time.
for s in customize.sh service.sh post-fs-data.sh action.sh status.sh uninstall.sh functions.sh boot-mini.sh watchdog.sh install_app.sh; do
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

# --- Required web files (13) ---
for f in "${WEB_FILES_REQUIRED[@]}"; do
    src="$REPO_ROOT/web/$f"
    if [ ! -f "$src" ]; then
        log_error "Missing: web/$f"
        exit 1
    fi
    cp "$src" "$STAGING/web/$f"
    chmod 0644 "$STAGING/web/$f"
done

# --- Optional web files (2) ---
for f in "${WEB_FILES_OPTIONAL[@]}"; do
    src="$REPO_ROOT/web/$f"
    if [ ! -f "$src" ]; then
        log_warn "Optional file missing: web/$f (skipping)"
        continue
    fi
    cp "$src" "$STAGING/web/$f"
    chmod 0644 "$STAGING/web/$f"
done

staging_size=$(du -sh "$STAGING" 2>/dev/null | cut -f1 || true)
[ -z "$staging_size" ] && staging_size="?"
log_ok "staging ready (${staging_size})"

# ============================================================
# [18] Reproducibility (set timestamps)
# ============================================================
# Apply SOURCE_DATE_EPOCH to every staged file. Two-step process:
#
#   1. Probe `touch -d @N` on a temporary file. If the platform
#      does not support the `-d @N` form (BSD/macOS with a
#      non-GNU touch), abort — silently shipping a
#      non-reproducible artifact is worse than failing.
#
#   2. Run `find -exec touch -d @N {} +`. If this fails despite
#      the probe passing, the cause is a real filesystem issue
#      (permissions, I/O), not a missing flag. The error message
#      reflects that distinction.
_probe=$(mktemp "${_TMPDIR_CLEAN}/touch-probe.XXXXXX" 2>/dev/null || true)
if [ -n "$_probe" ] && [ -f "$_probe" ]; then
    if ! touch -d "@0" "$_probe" 2>/dev/null; then
        rm -f "$_probe" 2>/dev/null
        log_error "This platform's 'touch' does not support -d @N."
        log_info "Reproducibility cannot be guaranteed without it."
        log_info "Install GNU coreutils, or run packaging on Linux."
        exit 1
    fi
    rm -f "$_probe" 2>/dev/null
else
    log_warn "Could not create touch probe — skipping -d @N capability check"
fi

if ! find "$STAGING" -exec touch -d "@${SOURCE_DATE_EPOCH}" {} + 2>/dev/null; then
    log_error "Failed to apply SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH} to staging files"
    log_info "The touch -d @N probe passed, so the cause is likely"
    log_info "a filesystem permission or I/O issue on $STAGING."
    log_info "Refusing to continue: reproducibility would be broken."
    exit 1
fi

log_ok "timestamps set"

# ============================================================
# [19] Create ZIP
# ============================================================
# The file list comes from `find | LC_ALL=C sort`, so the order
# is deterministic across machines and locales. `zip -X`
# excludes extra file attributes (uid/gid metadata) that would
# otherwise vary between runs.
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

# ZIP size is informational. Validate numeric output before
# using it below; non-numeric is reported as "?" and packaging
# continues. This is the SOFT-FAIL site — compare with the
# HARD-FAIL for DNS binaries in [16].
if zip_size=$(file_size "$OUTPUT_PATH"); then
    if ! is_numeric "$zip_size"; then
        log_warn "file_size returned a non-numeric value: '$zip_size'"
        zip_size="?"
    fi
else
    log_warn "Cannot determine ZIP size (stat failed)"
    zip_size="?"
fi

zip_size_human=$(du -h "$OUTPUT_PATH" 2>/dev/null | cut -f1 || true)
[ -z "$zip_size_human" ] && zip_size_human="?"

log_ok "ZIP: $OUTPUT_NAME ($zip_size_human)"

# ============================================================
# [20] Verify ZIP structure (36 entries — 34 required + 2 optional)
# ============================================================
REQUIRED_IN_ZIP=(
    "module.prop"

    "customize.sh"
    "service.sh"
    "post-fs-data.sh"
    "action.sh"
    "status.sh"
    "uninstall.sh"
    "functions.sh"
    "boot-mini.sh"
    "watchdog.sh"
    "install_app.sh"

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

OPTIONAL_IN_ZIP=(
    "web/app-debug.apk"
    "web/app-debug.apk.sha256"
)

ZIP_CONTENTS=$(unzip -l "$OUTPUT_PATH" 2>/dev/null | awk '{print $4}')

MISSING_IN_ZIP=0

# grep -qFx -- is used with the explicit -- terminator so that
# a future REQUIRED_IN_ZIP entry starting with '-' cannot be
# interpreted as an option. All current entries start with a
# letter (module.prop, proxy/..., web/...), but the defensive
# -- protects against regressions.
for item in "${REQUIRED_IN_ZIP[@]}"; do
    if ! echo "$ZIP_CONTENTS" | grep -qFx -- "$item"; then
        log_error "ZIP missing: $item"
        MISSING_IN_ZIP=$((MISSING_IN_ZIP + 1))
    fi
done

for item in "${OPTIONAL_IN_ZIP[@]}"; do
    if ! echo "$ZIP_CONTENTS" | grep -qFx -- "$item"; then
        log_warn "Optional file not in ZIP: $item"
    fi
done

if [ "$MISSING_IN_ZIP" -gt 0 ]; then
    log_error "ZIP incomplete: $MISSING_IN_ZIP required file(s)"
    exit 1
fi

log_ok "ZIP structure valid (${#REQUIRED_IN_ZIP[@]} required + ${#OPTIONAL_IN_ZIP[@]} optional)"

# --- Icon stats ---
PNG_COUNT=$(echo "$ZIP_CONTENTS" | count_matches '^web/.*\.png$')
ICO_COUNT=$(echo "$ZIP_CONTENTS" | count_matches '^web/.*\.ico$')
SVG_COUNT=$(echo "$ZIP_CONTENTS" | count_matches '^web/.*\.svg$')

log_info "Icons: ${PNG_COUNT} PNG + ${SVG_COUNT} SVG + ${ICO_COUNT} ICO"

# ============================================================
# [21] SHA-256 checksum
# ============================================================
CHECKSUM_FILE="$OUTPUT_DIR_ABS/${OUTPUT_NAME}.sha256"
(cd "$OUTPUT_DIR_ABS" && sha256_compat "$OUTPUT_NAME" > "${OUTPUT_NAME}.sha256")

# `-s` (non-empty) instead of `-f` (exists): the shell creates
# the file BEFORE sha256_compat runs, so a silent tool failure
# would leave an empty file on disk.
if [ ! -s "$CHECKSUM_FILE" ]; then
    log_error "Failed to create a non-empty checksum file"
    log_info "  Path: $CHECKSUM_FILE"
    log_info "  This usually means sha256_compat failed silently —"
    log_info "  check that sha256sum or shasum is functional:"
    log_info "    echo test | sha256sum"
    exit 1
fi

SHA256_HASH=$(awk '{print $1}' "$CHECKSUM_FILE")
if [ -z "$SHA256_HASH" ]; then
    log_error "Checksum file is non-empty but its first field is empty"
    log_info "  Path: $CHECKSUM_FILE"
    exit 1
fi

log_ok "checksum: ${SHA256_HASH:0:16}..."

# ============================================================
# [22] Final summary
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ${GREEN}✅ Package created successfully${NC}                       ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}ZIP:${NC}            ${GREEN}${OUTPUT_PATH}${NC}"
echo -e "  ${BOLD}Size:${NC}           ${zip_size_human} (${zip_size} bytes)"
echo -e "  ${BOLD}Module Ver:${NC}     ${VERSION}"
echo -e "  ${BOLD}versionCode:${NC}    ${MODPROP_VC}"
echo -e "  ${BOLD}DNS Engine:${NC}     ${DNS_VERSION}"
echo -e "  ${BOLD}DNS Cache:${NC}      ${DIM}${DNS_CACHE_DIR}${NC}"
echo -e "  ${BOLD}SHA-256:${NC}        ${SHA256_HASH}"
echo -e "  ${BOLD}Checksum:${NC}       ${CHECKSUM_FILE}"
echo ""
echo -e "  ${BOLD}web/ contents:${NC}"
echo -e "    ${DIM}• HTML:${NC}       2 files (index, dashboard)"
echo -e "    ${DIM}• Manifest:${NC}   1 file"
echo -e "    ${DIM}• SW:${NC}         1 file"
echo -e "    ${DIM}• SVG:${NC}        ${SVG_COUNT} file(s)"
echo -e "    ${DIM}• PNG:${NC}        ${PNG_COUNT} file(s)"
echo -e "    ${DIM}• ICO:${NC}        ${ICO_COUNT} file(s)"
echo -e "    ${DIM}• Offline:${NC}    1 file"
echo -e "    ${DIM}• APK:${NC}        1 file (optional)"
echo -e "    ${DIM}• APK SHA256:${NC} 1 file (optional)"
echo ""
echo -e "  ${BOLD}References:${NC}"
echo -e "    ${DIM}• docs/BACKUP.md      — Backup system reference${NC}"
echo -e "    ${DIM}• docs/EMERGENCY.md   — Emergency recovery guide${NC}"
echo -e "    ${DIM}• docs/UPGRADE.md     — Version upgrade guide${NC}"
echo ""

if [ "$VERBOSE" = "1" ]; then
    echo -e "${BOLD}ZIP contents:${NC}"
    unzip -l "$OUTPUT_PATH" | tail -n +4 | head -n -2
    echo ""
fi

exit 0
