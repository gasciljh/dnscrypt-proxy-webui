#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – fetch_dns_binaries.sh
# Version: v1.3.0 (Global Edition)
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Fetch dnscrypt-proxy binaries for all supported Android
#   architectures. The version is read from the Single Source
#   of Truth file `proxy/dnscrypt-proxy.version`.
#
# Sources (in attempt order):
#   The local cache is checked FIRST. If a valid cached binary
#   is present (and --force was not passed), no network access
#   happens at all. When a download is required, the following
#   sources are attempted in order:
#
#     1. GitHub API (real asset names)        — most accurate
#     2. android_<arch>-<version>.zip         — 2.1.18+ format
#     3. android-<arch>-<version>.zip         — older format
#     4. android_<arch>_<version>.zip         — underscore format
#
#   Note: earlier versions of this header listed "Local cache"
#   as source #6, which understated its role. The cache is the
#   first line of defense and short-circuits the entire download
#   path when it is valid.
#
#   The jsDelivr CDN probe that used to be source #5 has been
#   REMOVED in this revision (v1.2.0). Reason: jsDelivr's /gh/
#   endpoint serves files from the git tree, and the
#   dnscrypt-proxy-android_*.zip files are release assets, not
#   tree files — the probe was guaranteed to 404 on every cache
#   miss while still costing one HTTP request (up to 30s) per
#   architecture. See docs/DNS_BINARIES.md §4.2 for the full
#   rationale and the re-enable procedure if upstream ever
#   starts committing binaries to the repo tree.
#
# Features:
#   • Local cache checked first (~/.cache/dnscrypt-proxy-webui/dns-binaries)
#   • 4 fallback sources when a download is required
#   • SHA256 verification via `.manifest.json`
#   • Offline mode (--offline)
#   • JSON output for CI (--json)
#   • Idempotent — safe to run multiple times
#
# Retry strategy:
#   There is no explicit retry loop in this script. Resilience
#   comes from two layers:
#     • curl's own --retry 2 (per URL, 1s apart)
#     • 4 sequential fallback sources (if one fails, try the next)
#   This is sufficient for transient failures. For permanent
#   failures (nonexistent version, network down), the script
#   exits with code 1 — callers (package_module.sh, CI) are
#   expected to handle that.
#
# DNS version vs module version:
#   This script deals with the dnscrypt-proxy upstream version
#   (e.g. 2.1.18), NOT the module version (e.g. v1.2.0). They
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
# ============================================================
# v1.1.0 changes (kept):
#   • Version bumped to v1.1.0 (documentation only).
#   • Removed the unused MAX_RETRIES variable.
#   • Corrected the "Retry logic per source" claim.
#
# v1.2.0 changes:
#   • Version bumped to v1.2.0 (documentation only — no behavior
#     changes in this script since v1.1.0, apart from the audit
#     fixes listed below).
#   • Confirmed that the DNS version (`proxy/dnscrypt-proxy.version`)
#     stays at 2.1.18 for the v1.2.0 release.
#   • Global English edition.
#
# ============================================================
# v1.2.0 — POST-AUDIT FIXES (this file, still v1.2.0)
# ============================================================
# A pre-release audit of this file identified the following
# issues. All of them are addressed in-place; no version bump.
#
#   🔧 FDB-1 (critical) — `log_debug()` wrote to stdout, not
#     stderr. In the `build_candidate_urls()` context, stdout
#     is the FUNCTION'S RETURN CHANNEL. When the API call
#     succeeded AND --verbose was set, the function emitted two
#     lines (a debug line + the URL), and the calling loop tried
#     to download the debug line as a URL.
#
#     FIX: all log output except `log_info` / `log_ok` now goes
#     to stderr.
#
#   🔧 FDB-2 — `manifest_set()` did not check jq's exit code
#     before writing. A jq failure would truncate the manifest
#     to zero bytes, silently disabling SHA verification.
#
#     FIX: jq's exit status is now checked before the write.
#
#   🔧 FDB-3 — The header's "Sources (in priority order)" list
#     placed "Local cache" at position #6, implying it was the
#     last fallback. In reality, the cache is checked FIRST.
#
#     FIX: the header now separates "cache-first" from the
#     download-fallback chain. No code change.
#
# ============================================================
# v1.2.0 (Global Edition) — Additional hardening in this revision
# ============================================================
#   🛡️ FDB-4 (was DNS-1) — The jsDelivr URL at the end of
#     `build_candidate_urls()` pointed at a `/gh/` path, which
#     serves files from the git tree, not release assets. The
#     dnscrypt-proxy-android_*.zip files are release assets and
#     are NOT in the git tree, so this URL was guaranteed to
#     404 on every cache miss while still costing one HTTP
#     request per architecture.
#
#     FIX (this revision): the URL has been REMOVED from the
#     candidate list. The jsDelivr probe is disabled by default;
#     the code path that would re-enable it is documented in
#     the comments of `build_candidate_urls()` and in
#     docs/DNS_BINARIES.md §4.2.
#
#   🛡️ FDB-5 — `file_size()` may return `"?"` when `stat` fails.
#     The previous version interpolated this value directly into
#     JSON output (`"size":?`), producing invalid JSON. An
#     `is_numeric()` helper is now used to coerce the value to
#     `0` before writing. Parity with HARD-PM-04 (package_module.sh)
#     and HARD-GIC-01 (generate-icons.sh).
#
#   🛡️ FDB-6 — `file(1)` is used in `extract_binary()` as a
#     fallback identifier, but was not in the required-tools
#     check in [9]. A system without `file` would silently skip
#     the ELF fallback. `file` is now a required tool.
#
#   🛡️ FDB-7 — `extract_binary()` used `trap "..." RETURN`. The
#     RETURN trap is not reliably fired under `set -e` in every
#     shell, and can leave `/tmp/dns-extract.XXXXXX` directories
#     behind on failure. The function now uses an EXIT trap with
#     explicit cleanup on each return path.
#
#   🛡️ FDB-8 — `--version` did not validate that a value was
#     present. Passing `--version` as the last argument left
#     `VERSION_OVERRIDE` empty and the script silently fell back
#     to the version file. Parity with the `--arch` and
#     `--cache-dir` validation. A clear error is now emitted.
#
#   🛡️ FDB-9 — `read_dns_version()` returns a hardcoded
#     `2.1.18` fallback when the version file is missing. The
#     fallback itself is correct (it matches the current DNS
#     release), but a silent fallback hides the missing file
#     from the operator. A warning is now written to stderr
#     before the fallback is returned.
#
# ============================================================
# v1.2.0 — SECOND-PASS AUDIT FIXES (this revision)
# ============================================================
# A second audit identified three medium-severity issues and
# five low-severity hygiene items. All are addressed here.
#
#   🔧 FDB-10 (M-1) — The `attempt` counter in `fetch_arch()`
#     was declared, incremented, and never read. Dead code,
#     a leftover from the v1.1.0 MAX_RETRIES removal.
#
#     FIX: `attempt` is now used in a `log_debug` line so that
#     `--verbose` output shows which source index is being
#     tried. This makes the fallback chain observable without
#     changing behavior.
#
#   🔧 FDB-11 (M-2) — `file_size()` could never return a
#     failure status, because the final `echo "?"` always
#     succeeded. Callers wrote `size=$(file_size ... || echo "")`
#     but the `|| echo ""` branch was unreachable. The function
#     was effectively lying about its own error contract.
#
#     FIX: `file_size()` now `return 1`s when both `stat`
#     variants fail. The caller in `fetch_arch()` keeps the
#     `is_numeric` coercion (FDB-5), so JSON output stays
#     valid regardless. This matches HARD-PM-04 (package_module.sh)
#     and HARD-GIC-01 (generate-icons.sh).
#
#   🔧 FDB-12 (M-3) — The jsDelivr probe (FDB-4) was documented
#     as guaranteed to 404, but was still emitted on every
#     cache miss, costing one HTTP request (up to 30s) per
#     architecture. FDB-4 only documented the cost; it did not
#     remove it.
#
#     FIX: the probe is removed from `build_candidate_urls()`.
#     The URL is preserved in a comment block for re-enabling
#     if upstream ever starts committing binaries to the git
#     tree. See docs/DNS_BINARIES.md §4.2.
#
#   🟢 FDB-13 (L-1) — `SHA256_CMD` was left unset when neither
#     `sha256sum` nor `shasum` was available. This was safe in
#     practice (the `HAS_SHA256` guard runs first), but a
#     future refactor could dereference it. Now initialized to
#     the empty string.
#
#   🟢 FDB-14 (L-2) — `extract_binary()` set a global EXIT
#     trap and cleared it with `trap - EXIT`, which would have
#     clobbered any EXIT trap installed by the caller. This
#     was safe today (no caller installs one) but fragile.
#
#     FIX: the previous EXIT trap is saved with `trap -p EXIT`
#     before installation, and restored on every return path.
#
#   🟢 FDB-15 (L-3) — The JSON result line was built by string
#     concatenation. All current inputs are constrained (arch
#     names from a fixed list, numeric sizes, locally-built
#     URLs), so this was safe. The code is left as-is for
#     readability, but the constraint is now documented in a
#     comment to prevent a future caller from injecting an
#     unescaped value.
#
#   🟢 FDB-16 (L-4) — `download_url()` sent `GITHUB_TOKEN` to
#     `github.com/.../releases/download/...`. Those URLs are
#     public and do not require auth. Sending the token is not
#     a leak (same origin), but it is unnecessary. The header
#     is now sent only to `api.github.com` (the only host that
#     actually benefits from it), avoiding token transmission
#     to the release-download CDN.
#
#   🟢 FDB-17 (L-5) — `log_debug()` used a one-line
#     `[ ... ] && echo ... || true` idiom that is harder to
#     read than an explicit `if`. Rewritten as an `if` block.
#     No behavior change.
#
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
# ⚠️ Stream discipline (FDB-1 fix):
#   • log_info / log_ok  → stdout (user-facing, NOT captured
#                          in a value-producing context)
#   • log_warn / log_error / log_debug → stderr (safe in any
#                          stdout-capturing context)
#
#   Any future helper that may be invoked inside `$(...)` or
#   `< <(...)` MUST use stderr.
# ============================================================
log_info()  { echo -e "  ${CYAN}→${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }

# FDB-17 fix: explicit `if` is easier to read than the
# `[ ... ] && echo ... || true` one-liner. Same behavior.
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
  --version <ver>       DNS version (default: from proxy/dnscrypt-proxy.version)
  --offline             Use cache only (no download)
  --force               Force re-download even if present
  --verbose, -v         More details
  --quiet, -q           Quiet (errors only)
  --json, -j            JSON output (for CI)
  --help, -h            Show this help

Cache:
  The local cache is checked FIRST. A valid cached binary
  short-circuits the entire download path (unless --force).

Sources (in attempt order, when a download is needed):
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
            # FDB-8 fix: validate presence, matching --arch
            # and --cache-dir.
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
#    NOT the module version (e.g. v1.2.0). See the header note.
#
# v1.2.0 note: the DNS version stays at 2.1.18 for the v1.2.0
# release. The module version is v1.2.0, but the DNS engine is
# unchanged from v1.1.0.
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
    # FDB-9 fix: warn loudly so a missing version file is visible.
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
# FDB-6 fix: `file` is used by extract_binary()'s ELF fallback.
# It must be present, or the fallback silently fails on systems
# without it.
for tool in curl unzip find file; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "Missing tool: $tool"
        exit 2
    fi
done

# sha256sum or shasum
# FDB-13 fix: SHA256_CMD is initialized to the empty string
# so a future refactor cannot dereference an unset variable.
HAS_SHA256=0
SHA256_CMD=""
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
# FDB-11 fix: file_size() now returns 1 when both `stat`
# variants fail. Previously the trailing `echo "?"` always
# succeeded, so the function could never signal failure and
# the caller's `|| echo ""` branch was unreachable.
#
# Callers must handle the failure explicitly:
#   size=$(file_size "$f") || size=""
#   if ! is_numeric "$size"; then size=0; fi
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

# FDB-5 fix: is_numeric — true iff the argument is one or more
# digits. Used to coerce a failed file_size() to 0 before it
# reaches JSON output.
is_numeric() {
    case "${1:-}" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
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
# Returns empty stdout (not an error) when the key is missing
# or the manifest is unreadable.
# ============================================================
manifest_get() {
    local key="$1"
    if [ "$HAS_JQ" = "1" ] && [ -f "$MANIFEST_FILE" ]; then
        jq -r --arg k "$key" '.[$k].sha256 // empty' "$MANIFEST_FILE" 2>/dev/null
    fi
}

# ============================================================
# manifest_set — update the manifest atomically (FDB-2 fix)
# ============================================================
# Writes a JSON object to $MANIFEST_FILE. If jq fails, or if
# the result is empty, the function returns 1 WITHOUT touching
# the existing manifest.
# ============================================================
manifest_set() {
    local file="$1"
    local sha="$2"
    local version="$3"
    local url="$4"

    if [ "$HAS_JQ" = "0" ]; then
        return 0
    fi

    # Read the current manifest or create a new one.
    local current="{}"
    if [ -f "$MANIFEST_FILE" ]; then
        current=$(cat "$MANIFEST_FILE" 2>/dev/null) || current="{}"
        # Validate that it is valid JSON
        if ! echo "$current" | jq empty 2>/dev/null; then
            current="{}"
        fi
    fi

    # Update. FDB-2 fix: check jq's exit code and the
    # non-emptiness of its output BEFORE writing the file.
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
# [12] GitHub API — fetch the actual asset name
# ============================================================
# NOTE (FDB-1): log_debug writes to stderr since v1.2.0. This
# function's stdout is the RETURN CHANNEL for the asset name;
# any stray stdout write would corrupt the result.
#
# NOTE (FDB-16): GITHUB_TOKEN is sent here (api.github.com) but
# NOT to the release-download CDN. api.github.com is the only
# host that benefits from the token (rate limits); release
# assets are public.
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
# FDB-1 note: this function's stdout is a NEWLINE-SEPARATED
# list of URLs consumed by `while IFS= read -r url` in [16.3].
# Any log output here MUST go to stderr. log_debug is safe
# since v1.2.0 (see [3]).
#
# FDB-12 fix (M-3): the jsDelivr probe (former source #5) has
# been removed. jsDelivr's /gh/ endpoint serves files from the
# git tree, and dnscrypt-proxy-android_*.zip files are release
# assets, not tree files — the probe was guaranteed to 404 on
# every cache miss while still costing one HTTP request (up
# to 30s) per architecture. To re-enable it if upstream ever
# starts committing binaries to the git tree, uncomment the
# `echo` line in the block at the bottom of this function.
#
# See docs/DNS_BINARIES.md §4.2 for the full rationale.
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

    # --- 5) jsDelivr CDN — DISABLED (FDB-12 / was DNS-1) ---
    # ⚠️ The URL below is a best-effort probe and is currently
    # guaranteed to 404: /gh/ serves files from the git tree,
    # but dnscrypt-proxy-android_*.zip files are release assets
    # and do NOT exist in the tree. It was costing one HTTP
    # request (up to 30s) per cache miss while never succeeding.
    #
    # To re-enable if upstream ever starts committing binaries
    # to the repo tree, uncomment the line below:
    #
    # echo "https://cdn.jsdelivr.net/gh/${DNSCRYPT_REPO}@${version}/dnscrypt-proxy-android_${dns_arch}-${version}.zip"
}

# ============================================================
# [14] Download a single URL
# ============================================================
# Uses curl's built-in --retry 2 (with --retry-delay 1) for
# transient failures. No external retry loop — the 4-source
# fallback chain in [13] handles permanent failures.
#
# FDB-16 fix: no GITHUB_TOKEN header is sent here. Release
# asset URLs (github.com/.../releases/download/...) are public
# and do not require auth; sending the token was unnecessary
# and risked leaking it to a CDN edge node.
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
# FDB-7 fix: the previous version used `trap "..." RETURN`,
# which is not reliably fired under `set -e` in every shell.
# The function now uses an EXIT trap with explicit cleanup on
# each return path.
#
# FDB-14 fix (L-2): the previous EXIT trap (if any) is saved
# with `trap -p EXIT` before installation, and restored on
# every return path. This makes the function composable — a
# future caller that installs its own EXIT trap will not have
# it silently clobbered.
# ============================================================
extract_binary() {
    local zip_path="$1"
    local output_path="$2"

    # Create a temporary directory
    local tmp_extract
    tmp_extract=$(mktemp -d "${TMPDIR:-/tmp}/dns-extract.XXXXXX")

    # FDB-7 + FDB-14: save the previous EXIT trap, install our
    # own, and restore the previous one on every return path.
    local prev_exit_trap
    prev_exit_trap=$(trap -p EXIT)

    # shellcheck disable=SC2064
    trap "rm -rf '$tmp_extract' 2>/dev/null" EXIT

    # Internal helper: restore the previous EXIT trap.
    _restore_exit_trap() {
        if [ -n "$prev_exit_trap" ]; then
            eval "$prev_exit_trap"
        else
            trap - EXIT
        fi
    }

    if ! unzip -q -o "$zip_path" -d "$tmp_extract" 2>/dev/null; then
        log_error "Failed to unzip: $zip_path"
        rm -rf "$tmp_extract" 2>/dev/null
        _restore_exit_trap
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
        rm -rf "$tmp_extract" 2>/dev/null
        _restore_exit_trap
        return 1
    fi

    cp "$found" "$output_path"
    chmod 0755 "$output_path"

    rm -rf "$tmp_extract" 2>/dev/null
    _restore_exit_trap
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
            # FDB-5 fix: coerce failed file_size() to 0 before JSON.
            # FDB-11 fix: file_size() now returns 1 on failure, so
            # the `|| size=""` fallback is reachable.
            local size
            size=$(file_size "$cache_file") || size=""
            if ! is_numeric "$size"; then
                size=0
            fi
            if [ "$JSON" = "0" ] && [ "$QUIET" = "0" ]; then
                log_ok "$dns_arch → cache hit (${size} bytes)"
            fi
            JSON_CACHED=$((JSON_CACHED + 1))
            # FDB-15 note: all interpolated values are constrained
            # (arch from a fixed list, size numeric), so raw string
            # concatenation is safe here. Do NOT extend this pattern
            # to caller-supplied strings.
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
    # FDB-10 fix (M-1): `attempt` is now used in a log_debug line
    # below, so the fallback chain is observable under --verbose.
    # Previously it was declared, incremented, and never read.
    local attempt=0
    local success=0

    while IFS= read -r url; do
        [ -z "$url" ] && continue
        [ "$success" = "1" ] && break

        attempt=$((attempt + 1))
        log_debug "Source attempt #${attempt}: ${url}"

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

    # FDB-2 fix: manifest_set returns 1 on jq failure. The
    # `|| true` suppresses the error; the cache file itself
    # remains valid, and the previous manifest is preserved.
    manifest_set "dnscrypt-proxy-${dns_arch}" "$sha" "$version" "$downloaded_url" 2>/dev/null || true

    # FDB-5 + FDB-11 fix: coerce failed file_size() to 0 before JSON.
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