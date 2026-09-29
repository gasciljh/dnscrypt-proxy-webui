#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – package_module.sh
# Version: v1.2.0 (Global Edition)
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
# Web file list (13 files) vs SW precache (11 files):
#   The ZIP ships 13 web files. The Service Worker precaches 11
#   of these (sw.js itself is never cached, and index.html /
#   dashboard.html are served network-first as navigations).
#   See web/sw.js §[2] for the exact PRECACHE_ASSETS list.
#
# Icon source mapping (verified against generate-icons.sh):
#   • icon-192.png         ← from icon-192.svg
#   • icon-512.png         ← from icon-512.svg
#   • apple-touch-icon.png ← from icon-512.svg
#   • favicon-32x32.png    ← from icon-512.svg
#   • favicon-16x16.png    ← from icon-512.svg
#   • favicon.ico          ← from favicon-16.png + favicon-32.png
#
# Features:
#   • Auto-detects BUILD_DIR (proxy/build or ./build)
#   • Uses SOURCE_DATE_EPOCH for reproducible builds
#   • Reuses DNS binaries cache (via fetch_dns_binaries.sh)
#   • Maps i386 ↔ x86 for customize.sh compatibility
#   • Verifies VERSION ↔ module.prop consistency (PM-1)
#   • Verifies VERSION ↔ update.json consistency (PM-6)
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
# ============================================================
# v1.2.0 — POST-AUDIT FIXES (still v1.2.0)
# ============================================================
#   🔧 PM-1 — verify module.prop version == $VERSION (hard)
#     and versionCode == canonical formula (warn).
#   🔧 PM-2 — log_debug writes to stderr (matches siblings).
#   🔧 PM-3 — value-taking flags check that a value is present.
#
# ============================================================
# v1.2.0 (Global Edition) — Additional hardening in this revision
# ============================================================
#   🛡️ HARD-PM-01 (was PM-4) — Reproducibility fallback made
#     consistent. When SOURCE_DATE_EPOCH cannot be applied via
#     `touch -d @N`, the script now FAILS LOUDLY instead of
#     silently falling back to a different fixed date. Two
#     builds on two different OSes that succeed now produce the
#     same bytes; a build that could not apply the epoch is not
#     allowed to masquerade as reproducible.
#
#   🛡️ HARD-PM-02 (was PM-5) — The `grep -c ... || echo 0`
#     pattern that produced "0\n0" on zero matches is replaced
#     with a helper that returns exactly one line. Fixes the
#     malformed "Icons: 0\n0 PNG" log line.
#
#   🛡️ HARD-PM-03 (was PM-6) — update.json is now read and its
#     `version` field is compared to $VERSION. A mismatch is a
#     WARNING (not a hard error), because local/CI packaging
#     can legitimately run before the metadata is bumped by
#     release.sh.
#
#   🛡️ HARD-PM-04 (was PM-7) — `file_size` output is validated
#     as numeric before being used in an arithmetic comparison.
#     Prevents a syntax error under `set -e` when `stat` fails.
#
#   🛡️ HARD-PM-05 (was PM-8) — Web files are checked for
#     non-empty size (`-s`), not just existence. A 0-byte
#     placeholder from a failed checkout is caught here.
#
#   🛡️ HARD-PM-06 (was PM-9) — The EXIT trap uses an explicit
#     `if` instead of `&&` short-circuit, making the intent
#     unambiguous and the exit status of the trap well-defined
#     on every shell.
#
#   🛡️ HARD-PM-07 (was PM-10) — `calc_version_code` strips
#     leading zeros before arithmetic so that `v01.2.3` does
#     not trigger bash's octal-interpretation error.
#
#   🛡️ HARD-PM-08 (was PM-11) — OUTPUT_DIR writability is
#     checked early (section [6d]) instead of at the end.
#
#   🛡️ HARD-PM-09 (was PM-12) — TMPDIR trailing slash is
#     normalized before building the staging path.
#
#   🛡️ HARD-PM-10 (was PM-13) — The remediation hint after a
#     missing web file is tailored: icon files suggest
#     generate-icons.sh, other files point at git checkout.
#
# ============================================================
# v1.2.0 (Global Edition) — Revision 2 (M-1..M-2, L-1..L-6)
# ============================================================
#   🟡 M-1 — `zip_size=$(file_size ... || echo 0)` replaced
#     with an explicit if/else that validates numeric output.
#     This was the exact anti-pattern HARD-PM-04 forbids; it
#     was applied in §[15] but bypassed in §[18]. Now both
#     sites use the same guarded pattern.
#
#   🟡 M-2 — Relative --output-dir is resolved after
#     `cd "$REPO_ROOT"`, which can surprise callers who pass a
#     path from outside the repo. Documented in §[2] and in
#     the --help text; the resolved absolute path is now
#     printed during the early writability check in §[6d].
#
#   🟢 L-1 — favicon.ico is now included in the icon-missing
#     counter (previously `favicon-*` missed it because of the
#     dash).
#
#   🟢 L-2 — VERSION regex now accepts SemVer build metadata
#     (`+build.123`) in addition to the existing prerelease
#     suffix.
#
#   🟢 L-3 — Non-numeric versionCode in module.prop now emits
#     a dedicated warning using the existing is_numeric helper.
#
#   🟢 L-4 — sha256 availability check now uses `command -v`
#     first (cheaper than piping /dev/null through sha256sum).
#
#   🟢 L-5 — `du -h` for the human-readable ZIP size now has a
#     fallback to "?" if du fails.
#
#   🟢 L-6 — TMPDIR trailing-slash normalization now strips all
#     trailing slashes, not just one.
#
# ============================================================
# Reproducibility:
#   • SOURCE_DATE_EPOCH is applied via `touch -d "@N"` to every
#     file in staging before ZIP creation. If `touch -d` is not
#     available, the script exits with an error rather than
#     silently using a different timestamp.
#   • `zip -X` excludes extra file attributes.
#   • `find | LC_ALL=C sort` guarantees deterministic file order.
#   • Result: same source + same EPOCH + same platform family
#     → same ZIP SHA-256.
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
# NOTE (M-2): After this `cd`, every relative path — including
# the one passed via --output-dir or --build-dir — is resolved
# relative to REPO_ROOT, not to the caller's original cwd.
# The resolved absolute path is printed in §[6d].
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

# log_info and log_ok intentionally write to stdout: they are
# user-facing terminal output.
# log_warn, log_error, and log_debug write to stderr (PM-2).
log_info()  { echo -e "  ${CYAN}→${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }
log_debug() { [ "$VERBOSE" = "1" ] && echo -e "  ${DIM}·${NC} $1" >&2 || true; }

# ------------------------------------------------------------
# [4] Helper functions
# ------------------------------------------------------------
# file_size — returns size in bytes, or empty string on failure.
# HARD-PM-04: callers MUST validate that the output is numeric
# before using it in an arithmetic context.
# ------------------------------------------------------------
file_size() {
    local out
    out=$(stat -c%s "$1" 2>/dev/null) && [ -n "$out" ] && { printf '%s' "$out"; return 0; }
    out=$(stat -f%z "$1" 2>/dev/null) && [ -n "$out" ] && { printf '%s' "$out"; return 0; }
    return 1
}

# is_numeric — true iff the argument is one or more digits.
is_numeric() {
    case "${1:-}" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

# count_matches — count matching lines in a stream, exactly one
# line of output, always numeric.
# HARD-PM-02: replaces `grep -c ... || echo 0`, which emitted
# "0\n0" on zero matches.
# ------------------------------------------------------------
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
#   versionCode = MAJOR * 1,000,000
#               + MINOR *    10,000
#               + PATCH *       100
#
# Prerelease suffixes are ignored. HOTFIX is not used by any
# current release tooling.
#
# HARD-PM-07: leading zeros are stripped before arithmetic, so
# a value like "01" does not trigger bash's octal error.
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# [5] Arguments
# ------------------------------------------------------------
# PM-3 fix: each value-taking flag now requires a value.
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
  ./scripts/package_module.sh --version v1.2.0
  ./scripts/package_module.sh --version v1.2.0 --skip-dns-fetch
  ./scripts/package_module.sh --version v1.2.0 --output-dir /tmp/out

References:
  docs/BACKUP.md         Backup system reference (v1.2.0)
  docs/EMERGENCY.md      Emergency recovery guide (v1.2.0)
  docs/UPGRADE.md §3.1   v1.1.0 → v1.2.0 upgrade path
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

# L-2 fix: accept optional SemVer build metadata (`+...`) in
# addition to the existing optional prerelease suffix.
if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$'; then
    log_error "Invalid version: '$VERSION'"
    log_info "Required format: v<major>.<minor>.<patch>[-prerelease][+build]"
    exit 2
fi

VERSION_NO_V="${VERSION#v}"

# ------------------------------------------------------------
# [6b] PM-1 fix: verify module.prop matches $VERSION
# ------------------------------------------------------------
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
    # L-3 fix: non-numeric versionCode deserves its own message.
    log_warn "module.prop versionCode is not numeric: '$MODPROP_VC'"
    log_warn "  expected: $EXPECTED_VC (MAJOR*1M + MINOR*10K + PATCH*100)"
elif [ "$MODPROP_VC" != "$EXPECTED_VC" ]; then
    log_warn "versionCode does not match the canonical formula"
    log_warn "  module.prop: $MODPROP_VC"
    log_warn "  expected:    $EXPECTED_VC (MAJOR*1M + MINOR*10K + PATCH*100)"
    log_warn "This is a warning only — release.sh should keep these in sync."
fi

# ------------------------------------------------------------
# [6c] HARD-PM-03: verify update.json version matches $VERSION
# ------------------------------------------------------------
# update.json is what the root manager reads to offer updates.
# If it disagrees with the ZIP we are producing, users who
# already installed the module will not be offered the update —
# even though the ZIP exists.
#
# This is a WARNING (not a hard error) because packaging for a
# local test can legitimately run before release.sh has bumped
# the metadata.
# ------------------------------------------------------------
UPDATE_JSON="$REPO_ROOT/update.json"
if [ -f "$UPDATE_JSON" ]; then
    UPDATE_JSON_VERSION=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$UPDATE_JSON" \
        | head -n1 \
        | sed -E 's/.*"([^"]*)"$/\1/')

    if [ -z "$UPDATE_JSON_VERSION" ]; then
        log_warn "update.json has no parseable 'version' field"
    elif [ "$UPDATE_JSON_VERSION" != "$VERSION" ]; then
        log_warn "update.json version does not match --version"
        log_warn "  update.json: $UPDATE_JSON_VERSION"
        log_warn "  --version:   $VERSION"
        log_warn "Users who already installed the module will NOT see the update"
        log_warn "until update.json is regenerated by scripts/release.sh."
    fi

    # Also check the zipUrl filename.
    UPDATE_JSON_URL=$(grep -oE '"zipUrl"[[:space:]]*:[[:space:]]*"[^"]*"' "$UPDATE_JSON" \
        | head -n1 \
        | sed -E 's/.*"([^"]*)"$/\1/')
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

# ------------------------------------------------------------
# [6d] HARD-PM-08: verify OUTPUT_DIR is writable early
# ------------------------------------------------------------
# M-2: because §[2] `cd`'d into REPO_ROOT, a relative
# --output-dir is resolved against REPO_ROOT. We print the
# resolved absolute path here so the caller sees exactly which
# directory was created / checked.
# ------------------------------------------------------------
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
# HARD-PM-01: the epoch is either taken from the environment,
# from the last git commit, or fixed to 0. Whatever the value,
# the primary touch path is authoritative: if `touch -d @N`
# is not available on this platform, we FAIL rather than
# silently substituting a different date. A build that cannot
# honor the requested epoch must not pretend to be reproducible.
# ------------------------------------------------------------
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
        SOURCE_DATE_EPOCH=$(git log -1 --format=%ct 2>/dev/null || echo 0)
    else
        SOURCE_DATE_EPOCH=0
    fi
fi
# Numeric guard.
if ! is_numeric "$SOURCE_DATE_EPOCH"; then
    log_warn "SOURCE_DATE_EPOCH is not numeric ('$SOURCE_DATE_EPOCH'); using 0"
    SOURCE_DATE_EPOCH=0
fi
export SOURCE_DATE_EPOCH

# ------------------------------------------------------------
# [10] Header
# ------------------------------------------------------------
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

# L-4 fix: prefer `command -v` over piping /dev/null through the
# hashing tool for the availability check.
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    log_error "Neither sha256sum nor shasum available"
    exit 2
fi

log_ok "Required tools available"

# ------------------------------------------------------------
# [12] Check project structure
# ------------------------------------------------------------
[ -d "$REPO_ROOT/proxy" ] || { log_error "proxy/ directory missing"; exit 2; }
[ -d "$REPO_ROOT/web" ]   || { log_error "web/ directory missing"; exit 2; }

# ------------------------------------------------------------
# [13] Check web files (13 files)
# ------------------------------------------------------------
# HARD-PM-05: checks for non-empty size, not just existence.
# HARD-PM-10: remediation hint is tailored to the type of file.
# L-1 fix: favicon.ico is explicitly included in the icon set.
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
        # L-1: include favicon.ico explicitly — `favicon-*` alone
        # does not match it because of the dash.
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

if [ "$WEB_MISSING" -gt 0 ]; then
    log_error "$WEB_MISSING web file(s) missing or empty"
    if [ "$WEB_MISSING_ICONS" -gt 0 ]; then
        log_info "Regenerate icons with: ./scripts/generate-icons.sh"
    fi
    if [ "$WEB_MISSING_HTML" -gt 0 ]; then
        log_info "HTML files are tracked in git; verify your checkout."
        log_info "  git status web/"
    fi
    exit 1
fi

log_ok "All web files present and non-empty (${#WEB_FILES_REQUIRED[@]} files)"

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
# HARD-PM-04: validate that file_size returned a number before
# using it in arithmetic.
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

# ------------------------------------------------------------
# [16] Create staging
# ------------------------------------------------------------
# HARD-PM-09 + L-6: strip *all* trailing slashes from TMPDIR,
# not just one, so a value like "/tmp///" normalizes cleanly.
_TMPDIR_CLEAN="${TMPDIR:-/tmp}"
while [ "${_TMPDIR_CLEAN%/}" != "$_TMPDIR_CLEAN" ]; do
    _TMPDIR_CLEAN="${_TMPDIR_CLEAN%/}"
done
[ -z "$_TMPDIR_CLEAN" ] && _TMPDIR_CLEAN="/tmp"

STAGING=$(mktemp -d "${_TMPDIR_CLEAN}/dnscrypt-pkg.XXXXXX")

# HARD-PM-06: explicit `if` instead of `&&` short-circuit.
# The trap's exit status is now unambiguous on every shell.
# shellcheck disable=SC2064
trap 'if [ "$KEEP_STAGING" = "0" ]; then rm -rf "$STAGING"; fi' EXIT

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

staging_size=$(du -sh "$STAGING" 2>/dev/null | cut -f1 || echo "?")
log_ok "staging ready (${staging_size})"

# ------------------------------------------------------------
# [17] Reproducibility (set timestamps)
# ------------------------------------------------------------
# HARD-PM-01: fail loudly if the requested epoch cannot be
# applied, rather than silently substituting a fixed 2020 date.
# The whole point of SOURCE_DATE_EPOCH is that two builds of
# the same source produce the same bytes; substituting a
# different date would defeat that.
# ------------------------------------------------------------
if ! find "$STAGING" -exec touch -d "@${SOURCE_DATE_EPOCH}" {} + 2>/dev/null; then
    log_error "Failed to apply SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH} to staging files"
    log_info "This platform's 'touch' does not support -d @N."
    log_info "Refusing to continue: reproducibility would be broken."
    log_info "Install GNU coreutils, or run the packaging step on Linux."
    exit 1
fi

log_ok "timestamps set"

# ------------------------------------------------------------
# [18] Create ZIP
# ------------------------------------------------------------
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

# M-1 fix: same guarded pattern as §[15] — validate that
# file_size produced a numeric value before using it below.
if zip_size=$(file_size "$OUTPUT_PATH"); then
    if ! is_numeric "$zip_size"; then
        log_warn "file_size returned a non-numeric value: '$zip_size'"
        zip_size="?"
    fi
else
    log_warn "Cannot determine ZIP size (stat failed)"
    zip_size="?"
fi

# L-5 fix: fall back to "?" if du fails, instead of emitting an
# empty string silently.
zip_size_human=$(du -h "$OUTPUT_PATH" 2>/dev/null | cut -f1 || true)
[ -z "$zip_size_human" ] && zip_size_human="?"

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

# Additional stats.
# HARD-PM-02: use count_matches instead of `grep -c ... || echo 0`.
PNG_COUNT=$(echo "$ZIP_CONTENTS" | count_matches '^web/.*\.png$')
ICO_COUNT=$(echo "$ZIP_CONTENTS" | count_matches '^web/.*\.ico$')
SVG_COUNT=$(echo "$ZIP_CONTENTS" | count_matches '^web/.*\.svg$')

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
echo -e "    ${DIM}• SVG:${NC}        ${SVG_COUNT} file(s) — icon-192, icon-512"
echo -e "    ${DIM}• PNG:${NC}        ${PNG_COUNT} file(s)"
echo -e "    ${DIM}• ICO:${NC}        ${ICO_COUNT} file(s)"
echo -e "    ${DIM}• Offline:${NC}    1 file"
echo ""
echo -e "  ${BOLD}v1.2.0 data preservation:${NC}"
echo -e "    ${GREEN}✓${NC} 10 defensive layers bundled (existing shell scripts)"
echo -e "    ${DIM}• Backup dir on device: /sdcard/dnscrypt-webui-backup/${NC}"
echo -e "    ${DIM}• NOT included in ZIP (created at runtime)${NC}"
echo ""
echo -e "  ${BOLD}References:${NC}"
echo -e "    ${DIM}• docs/BACKUP.md      — Backup system reference${NC}"
echo -e "    ${DIM}• docs/EMERGENCY.md   — Emergency recovery guide${NC}"
echo -e "    ${DIM}• docs/UPGRADE.md     — v1.1.0 → v1.2.0 upgrade path${NC}"
echo ""

if [ "$VERBOSE" = "1" ]; then
    echo -e "${BOLD}ZIP contents:${NC}"
    unzip -l "$OUTPUT_PATH" | tail -n +4 | head -n -2
    echo ""
fi

exit 0