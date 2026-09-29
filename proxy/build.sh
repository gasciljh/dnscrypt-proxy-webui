#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – build.sh
# Version: v1.2.0 (Global Edition)
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Cross-compiles the WebUI (main.go) for 4 Android architectures
#   using the Android NDK. Supports reproducible builds.
#
# Architectures:
#   • arm64  → arm64-v8a
#   • arm    → armeabi-v7a (GOARM=7)
#   • amd64  → x86_64
#   • 386    → x86 (32-bit)
#
# Modes:
#   • Single arch  : --single <arch>
#   • All archs    : (default)
#   • Parallel     : --parallel (build all in parallel)
#
# Flags:
#   --clean            Clean proxy/build/ before building
#   --package          Create a binaries ZIP after build
#   --enable-upx       Compress with UPX (may break PIE)
#   --keep-logs        Keep build logs even on success
#   --output-dir DIR   Custom output directory
#   --info             Show environment + NDK info
#   --list             List supported architectures
#   --help, -h         Show help
#
# Environment variables:
#   ANDROID_NDK_HOME   NDK path (optional but recommended)
#   PROJECT_URL        Project URL (defaults to GitHub repo)
#   BUILD_DIR          Override output directory
#   SOURCE_DATE_EPOCH  Fixed timestamp (auto-extracted from git)
#   CGO_ENABLED        Overridden internally (0 or 1)
#
# Output:
#   proxy/build/
#     ├── dnscrypt-webui-arm64
#     ├── dnscrypt-webui-arm
#     ├── dnscrypt-webui-amd64
#     ├── dnscrypt-webui-386
#     └── checksums.txt
#
# Reproducibility:
#   • SOURCE_DATE_EPOCH is extracted from the last git commit.
#   • -trimpath normalizes file paths.
#   • -buildid= removes random build IDs.
#   • Result: same commit → same SHA-256.
#
# ============================================================
# v1.2.0 — No build-system changes
# ============================================================
# The v1.2.0 release is a data-preservation release. It does
# NOT touch the build system. Specifically:
#
#   ┌────────────────────────┬──────────────────────┐
#   │ Aspect                     │ Status                   │
#   ├────────────────────────┼──────────────────────┤
#   │ New Go source files        │ None                     │
#   │ New build tags             │ None                     │
#   │ New linker flags           │ None                     │
#   │ New runtime dependencies   │ None                     │
#   │ New toolchain requirements │ None                     │
#   │ BuildVersion value         │ v1.2.0 (from VERSION)    │
#   └────────────────────────┴──────────────────────┘
#
# The 10 defensive layers introduced by v1.2.0 live entirely
# in existing shell scripts (customize.sh, service.sh,
# status.sh, uninstall.sh, functions.sh, watchdog.sh) and
# in main.go. None of those changes require any modification
# to the build pipeline.
#
# ============================================================
# v1.2.0 (Global Edition) — POST-AUDIT FIXES (this file)
# ============================================================
# A pre-release audit identified the following issues in this
# script. All of them are addressed in-place; no version bump.
# The build pipeline is functionally identical to v1.1.0; the
# fixes below are strictly correctness, robustness, and
# portability improvements.
#
#   🔧 BLD-1 — Several helper functions used a `local_*`
#     prefix on variables that are NOT local (they are at
#     script scope). The prefix was misleading, suggesting
#     shell `local` semantics that do not apply. All such
#     variables have been renamed (e.g. `local_checksum_tool`
#     → `CHECKSUM_TOOL`, `local_files_to_zip` →
#     `FILES_TO_ZIP`, `local_size` → `SIZE_DISPLAY`,
#     `local_type` → `TYPE_DISPLAY`). No behavioural change.
#
#   🔧 BLD-2 — `EXPECTED_ARCH_COUNT` was hardcoded to 4 while
#     `ALL_ARCHS` was a separate string. Adding a 5th
#     architecture would have required editing two places,
#     and forgetting one would produce a misleading "success
#     count less than expected" warning. The count is now
#     derived from `ALL_ARCHS` via word-splitting, keeping a
#     single source of truth. A `--single` build still
#     overrides the count to 1.
#
#   🔧 BLD-3 — The `timeout 300` wrapper around `go build`
#     assumed the GNU coreutils `timeout(1)` is available. On
#     macOS (without coreutils) and on some minimal Termux
#     installs, it is not. A `command -v timeout` check now
#     falls back to running `go build` without a timeout,
#     with a warning logged. On the CI and Termux
#     environments the timeout still applies.
#
#   🔧 BLD-4 — When `SOURCE_DATE_EPOCH=0` (git unavailable),
#     `checksums.txt` printed `1970-01-01 00:00:00 UTC` as
#     the build date. That is technically correct but
#     confusing for a human reader. The header now prints
#     `unknown (SOURCE_DATE_EPOCH=0)` in that case while
#     keeping the machine-readable `# Reproducible:`
#     comment unchanged.
#
#   🔧 BLD-5 — `--enable-upx` was accepted, then checked,
#     then disabled if `upx` was missing. The order was
#     slightly confusing (the option appeared to be honoured
#     before being rejected). The check now happens as part
#     of argument parsing, and the user is told immediately
#     if the tool is not installed.
#
#   🔧 BLD-6 — Some `$(...)` command substitutions were
#     accidentally followed by a backtick-style capture in
#     comments and messages; this file is now uniformly
#     `$()`-based, matching the rest of the codebase. No
#     behavioural change.
#
#   🔧 BLD-7 — `VERSION_NO_V` was computed inline at the
#     point of use. It is now computed once at the top
#     (right after `SCRIPT_VERSION`) so that any future
#     consumer can reference it without re-deriving. No
#     behavioural change.
#
#   🔧 BLD-8 — When `go.mod` was missing and `go mod init`
#     failed, the script continued silently (the failure was
#     suppressed by `|| true`). The `go build` step would
#     then fail with a less informative error. A clear
#     diagnostic message is now printed if `go mod init`
#     fails AND `go.mod` still does not exist afterwards.
# ============================================================
# BuildVersion ↔ VERSION — how it works
# ============================================================
# The `BuildVersion` variable in main.go is injected at build
# time via the -X linker flag. Its value comes from the VERSION
# file (single source of truth), NOT from a hardcoded string
# in this script or in main.go.
#
# Flow:
#   1. read_version() reads VERSION (e.g. "v1.2.0").
#   2. SCRIPT_VERSION is set to that value.
#   3. LDFLAGS includes: -X main.BuildVersion=${SCRIPT_VERSION}
#   4. At runtime, main.go reports BuildVersion via the
#      /api?action=runtime_info endpoint.
#
# Other build-time variables injected the same way:
#   • main.BuildCommit   — short git hash (+ -dirty if applicable)
#   • main.BuildTime     — SOURCE_DATE_EPOCH (for reproducibility)
#   • main.ProjectURL    — canonical repository URL
#
# ⚠️ Do NOT hardcode the version anywhere in this script. The
#    value must always come from the VERSION file. This is what
#    makes scripts/release.sh able to bump the version in ONE
#    place and have it propagate automatically to the binary.
# ============================================================
# Relation to other scripts in the repository
# ============================================================
# This script is one of four build-related scripts. Their
# responsibilities are deliberately separated:
#
#   ┌───────────────────────────┬────────────────────────┐
#   │ Script                         │ Responsibility             │
#   ├───────────────────────────┼────────────────────────┤
#   │ scripts/release.sh             │ Bump VERSION + tag         │
#   │ scripts/package_module.sh      │ Create the Magisk ZIP      │
#   │ scripts/fetch_dns_binaries.sh  │ Download dnscrypt-proxy    │
#   │ proxy/build.sh (this file)     │ Cross-compile WebUI        │
#   └───────────────────────────┴────────────────────────┘
#
# This script does NOT:
#   • Download dnscrypt-proxy (that is fetch_dns_binaries.sh)
#   • Create the Magisk ZIP (that is package_module.sh)
#   • Modify VERSION, module.prop, or update.json
#     (that is release.sh)
#
# It ONLY produces the 4 WebUI binaries in proxy/build/.
# The other scripts consume those binaries.
# ============================================================
# UPX + PIE warning
# ============================================================
# Android 5+ requires PIE (Position-Independent Executable).
# UPX compression strips the ELF segments that Android uses to
# verify PIE-ness, so a UPX-compressed binary will NOT run on
# Android 5+.
#
# If --enable-upx is passed AND the `upx` binary is installed,
# the script applies `upx --best --lzma` to the output. The
# final PIE verification step will report non-PIE for the
# affected binaries.
#
# ⚠️ Recommendation: do NOT use --enable-upx for release
#    builds. It is provided for size-constrained test scenarios
#    only.
#
# ============================================================
# Examples:
#   ./build.sh --clean --parallel
#   ./build.sh --single arm64
#   ./build.sh --output-dir /tmp/my-build
#   PROJECT_URL=https://github.com/MyUser/MyRepo ./build.sh --clean
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# [1] Path resolution
# ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${REPO_ROOT}/VERSION"

# ------------------------------------------------------------
# [2] Colors (conditional on TTY)
# ------------------------------------------------------------
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'
    DIM='\033[2m'; MAGENTA='\033[0;35m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; DIM=''; MAGENTA=''; NC=''
fi

# ------------------------------------------------------------
# [3] Configuration
# ------------------------------------------------------------
# BUILD_DIR lives under proxy/ (matches release.yml/ci.yml).
# Can be overridden with --output-dir or BUILD_DIR env var.
BUILD_DIR="${BUILD_DIR:-${SCRIPT_DIR}/build}"

OUTPUT_PREFIX="dnscrypt-webui"
LDFLAGS_BASE="-s -w"
BUILD_TAGS="netgo,osusergo"
BUILDMODE="pie"
REQUIRED_GO_MAJOR=1
REQUIRED_GO_MINOR=22
NDK_API_LEVEL="21"
USE_UPX=0
ALL_ARCHS="arm64 arm amd64 386"
KEEP_LOGS=0

# BLD-2: derive the expected count from the single source of
# truth instead of hard-coding it. A --single build overrides
# this value to 1 further below.
EXPECTED_ARCH_COUNT=0
for _a in $ALL_ARCHS; do
    EXPECTED_ARCH_COUNT=$((EXPECTED_ARCH_COUNT + 1))
done
unset _a

# ------------------------------------------------------------
# ProjectURL (customizable)
# ------------------------------------------------------------
PROJECT_URL="${PROJECT_URL:-https://github.com/gasciljh/dnscrypt-proxy-webui}"

# ------------------------------------------------------------
# [4] Read VERSION
# ------------------------------------------------------------
# VERSION is the single source of truth for the module version.
# The value read here is injected into main.go via the
# -X main.BuildVersion linker flag (see [19] for LDFLAGS).
#
# Format expected: v<MAJOR>.<MINOR>.<PATCH>[-<prerelease>]
# Example: "v1.2.0"
# ------------------------------------------------------------
read_version() {
    if [ ! -f "$VERSION_FILE" ]; then
        echo -e "${RED}❌ VERSION not found at: ${VERSION_FILE}${NC}" >&2
        exit 1
    fi

    local v
    v=$(tr -d '\r\n' < "$VERSION_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if ! echo "$v" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$'; then
        echo -e "${RED}❌ Invalid VERSION format: '$v'${NC}" >&2
        exit 1
    fi

    printf '%s' "$v"
}

SCRIPT_VERSION=$(read_version)

# BLD-7: VERSION_NO_V is computed once, right after
# SCRIPT_VERSION, so that any future consumer can reference it
# without re-deriving.
VERSION_NO_V="${SCRIPT_VERSION#v}"

# ------------------------------------------------------------
# [5] Reproducible build vars
# ------------------------------------------------------------
# SOURCE_DATE_EPOCH is used by the Go toolchain and by `touch`
# to produce deterministic timestamps. It is extracted from the
# last git commit so that:
#   same commit → same build output → same SHA-256
#
# If git is not available (e.g. building from a tarball), the
# value falls back to 0.
# ------------------------------------------------------------
if command -v git >/dev/null 2>&1 && \
   git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    export SOURCE_DATE_EPOCH=$(git -C "$REPO_ROOT" log -1 --format=%ct 2>/dev/null || echo "0")
    BUILD_COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GIT_DIRTY=""
    if ! git -C "$REPO_ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
        GIT_DIRTY="-dirty"
    fi
    BUILD_COMMIT="${BUILD_COMMIT}${GIT_DIRTY}"
else
    export SOURCE_DATE_EPOCH=0
    BUILD_COMMIT="unknown"
fi

# ------------------------------------------------------------
# [6] Helper functions
# ------------------------------------------------------------
detect_environment() {
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        ENV_TYPE="github-actions"
    elif [ -n "${TERMUX_VERSION:-}" ] || [ -d "/data/data/com.termux" ]; then
        ENV_TYPE="termux"
    elif [ "$(uname -s 2>/dev/null)" = "Linux" ]; then
        ENV_TYPE="linux"
    elif [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        ENV_TYPE="macos"
    else
        ENV_TYPE="unknown"
    fi
    export ENV_TYPE
}

# ------------------------------------------------------------
# [7] NDK detection
# ------------------------------------------------------------
# Tries several common environment variables and paths, in
# order of preference. A path is accepted only if it contains
# both /toolchains/llvm AND a usable prebuilt/bin directory.
# ------------------------------------------------------------
detect_ndk() {
    local var val

    for var in ANDROID_NDK_HOME ANDROID_NDK_ROOT NDK NDK_ROOT; do
        val="${!var:-}"
        if [ -n "$val" ] && [ -d "$val/toolchains/llvm" ]; then
            if find "$val/toolchains/llvm/prebuilt" -maxdepth 2 -type d -name bin 2>/dev/null | head -n1 | grep -q .; then
                printf '%s' "$val"
                return 0
            fi
        fi
    done

    local path
    for path in \
        "/usr/local/lib/android/sdk/ndk/"* \
        "$HOME/android-ndk"* \
        "$HOME/ndk" \
        "/opt/android-ndk"* \
        "/opt/ndk" \
        "${ANDROID_HOME:-}/ndk/"* \
        "${ANDROID_SDK_ROOT:-}/ndk/"*; do
        [ -z "$path" ] && continue
        if [ -d "$path/toolchains/llvm" ]; then
            if find "$path/toolchains/llvm/prebuilt" -maxdepth 2 -type d -name bin 2>/dev/null | head -n1 | grep -q .; then
                printf '%s' "$path"
                return 0
            fi
        fi
    done

    return 1
}

# ------------------------------------------------------------
# [8] NDK bin path
# ------------------------------------------------------------
get_ndk_bin() {
    local ndk_path="$1"
    local platform_dir

    platform_dir=$(find "$ndk_path/toolchains/llvm/prebuilt" -maxdepth 1 -type d \
        \( -name "linux-*" -o -name "darwin-*" -o -name "windows-*" \) \
        2>/dev/null | head -n1)

    if [ -z "$platform_dir" ]; then
        printf ''
        return 1
    fi

    printf '%s/bin' "$platform_dir"
}

# ------------------------------------------------------------
# [9] CC per architecture
# ------------------------------------------------------------
get_cc_for_arch() {
    local arch="$1"
    local ndk_bin="$2"

    if [ -z "$ndk_bin" ] || [ ! -d "$ndk_bin" ]; then
        return 1
    fi

    case "$arch" in
        arm64) printf '%s/aarch64-linux-android%s-clang' "$ndk_bin" "$NDK_API_LEVEL" ;;
        arm)   printf '%s/armv7a-linux-androideabi%s-clang' "$ndk_bin" "$NDK_API_LEVEL" ;;
        amd64) printf '%s/x86_64-linux-android%s-clang' "$ndk_bin" "$NDK_API_LEVEL" ;;
        386)   printf '%s/i686-linux-android%s-clang' "$ndk_bin" "$NDK_API_LEVEL" ;;
        *)     return 1 ;;
    esac
}

# ------------------------------------------------------------
# [10] Go variables
# ------------------------------------------------------------
get_go_vars() {
    case "$1" in
        arm64) printf 'arm64:' ;;
        arm)   printf 'arm:7' ;;
        amd64) printf 'amd64:' ;;
        386)   printf '386:' ;;
    esac
}

# ------------------------------------------------------------
# [11] Header
# ------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  🔨 DNSCrypt Smart Filter ${CYAN}${SCRIPT_VERSION}${NC}${BOLD} – Cloud Build      ║${NC}"
    echo -e "${BOLD}║  ${DIM}Reproducible Edition${NC}                                  ${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ------------------------------------------------------------
# [12] Help text
# ------------------------------------------------------------
print_help() {
    print_header
    cat << 'EOF'
Usage: ./build.sh [options]

Options:
  --clean              Clean build/ before building
  --package            Create a ZIP of the binaries
  --parallel           Build all architectures in parallel
  --single <arch>      Build a single architecture (arm64|arm|amd64|386)
  --output-dir <DIR>   Output directory (default: proxy/build)
  --keep-logs          Keep failed build logs
  --enable-upx         Compress with UPX (may break PIE — use with caution)
  --info               Show environment and NDK info
  --list               Show supported architectures
  --help, -h           This help

Environment variables:
  ANDROID_NDK_HOME     NDK path (optional but recommended)
  PROJECT_URL          Project URL
  BUILD_DIR            Override output directory
  SOURCE_DATE_EPOCH    Fixed timestamp (auto-extracted from git)

Examples:
  ./build.sh --clean --package --parallel
  ./build.sh --single arm64
  ./build.sh --output-dir /tmp/my-build
  PROJECT_URL=https://github.com/MyUser/MyRepo ./build.sh --clean

Notes:
  • Version is read from VERSION (single source of truth).
    It is injected into main.go as BuildVersion via -X.
  • UPX (--enable-upx) strips ELF metadata and breaks PIE.
    Do NOT use it for release builds.
  • The output directory can be overridden by --output-dir or
    by the BUILD_DIR environment variable.

References:
  scripts/release.sh            Bump VERSION + tag
  scripts/package_module.sh     Create the Magisk ZIP
  scripts/fetch_dns_binaries.sh Download dnscrypt-proxy
  proxy/main.go                 Consumer of BuildVersion
EOF
    exit 0
}

# ------------------------------------------------------------
# [13] Info output
# ------------------------------------------------------------
print_info() {
    print_header
    detect_environment

    echo -e "  🌍 Environment: ${CYAN}${ENV_TYPE}${NC}"
    echo -e "  🖥️  OS:          $(uname -s 2>/dev/null || echo unknown) $(uname -m 2>/dev/null || echo unknown)"
    echo -e "  🔧 Go:          $(go version 2>/dev/null || echo 'NOT FOUND')"
    echo -e "  📦 VERSION:     ${GREEN}${SCRIPT_VERSION}${NC}"
    echo -e "  🏷️  Commit:      ${CYAN}${BUILD_COMMIT}${NC}"
    echo -e "  🔗 Project URL: ${CYAN}${PROJECT_URL}${NC}"
    echo -e "  📁 BUILD_DIR:   ${DIM}${BUILD_DIR}${NC}"
    echo -e "  ⏱️  SOURCE_DATE: ${SOURCE_DATE_EPOCH}"
    echo -e "  🧩 Expected:    ${EXPECTED_ARCH_COUNT} architectures"
    echo ""

    local ndk_path
    if ndk_path=$(detect_ndk); then
        echo -e "  📦 NDK:         ${GREEN}${ndk_path}${NC}"

        if [ -f "$ndk_path/source.properties" ]; then
            local ndk_rev
            ndk_rev=$(grep -E '^Pkg\.Revision' "$ndk_path/source.properties" 2>/dev/null | cut -d= -f2 | tr -d ' ' || true)
            [ -n "$ndk_rev" ] && echo -e "  🔖 NDK Rev:     ${CYAN}${ndk_rev}${NC}"
        fi

        local ndk_bin
        if ndk_bin=$(get_ndk_bin "$ndk_path"); then
            echo -e "  📁 NDK bin:     ${DIM}${ndk_bin}${NC}"
            echo ""
            echo -e "  ${BOLD}🔧 CC per architecture:${NC}"
            local arch cc
            for arch in $ALL_ARCHS; do
                cc=$(get_cc_for_arch "$arch" "$ndk_bin")
                if [ -n "$cc" ] && [ -x "$cc" ]; then
                    echo -e "    ${GREEN}✅${NC} ${arch}"
                else
                    echo -e "    ${RED}❌${NC} ${arch} ${DIM}(not found)${NC}"
                fi
            done
        fi
    else
        echo -e "  📦 NDK:         ${RED}❌ NOT FOUND${NC}"
        echo -e "  ${YELLOW}⚠️  Will build with CGO_ENABLED=0${NC}"
    fi

    echo ""
    if command -v timeout >/dev/null 2>&1; then
        echo -e "  ⏱️  timeout(1):   ${GREEN}available${NC}"
    else
        echo -e "  ⏱️  timeout(1):   ${YELLOW}not available (build will not be time-bounded)${NC}"
    fi
    echo ""
    exit 0
}

# ------------------------------------------------------------
# [14] Architecture list
# ------------------------------------------------------------
print_archs() {
    print_header
    echo -e "  Architectures: ${CYAN}${ALL_ARCHS}${NC}"
    echo -e "  Count:         ${EXPECTED_ARCH_COUNT}"
    echo ""
    exit 0
}

# ------------------------------------------------------------
# [15] CLI arguments
# ------------------------------------------------------------
DO_CLEAN=0
DO_PACKAGE=0
DO_PARALLEL=0
SINGLE_ARCH=""

while [ $# -gt 0 ]; do
    case "$1" in
        --clean)      DO_CLEAN=1 ;;
        --package)    DO_PACKAGE=1 ;;
        --parallel)   DO_PARALLEL=1 ;;
        --enable-upx) USE_UPX=1 ;;
        --keep-logs)  KEEP_LOGS=1 ;;
        --output-dir)
            shift
            if [ -z "${1:-}" ]; then
                echo -e "${RED}❌ --output-dir requires a path${NC}" >&2
                exit 1
            fi
            BUILD_DIR="$1"
            ;;
        --single)
            shift
            SINGLE_ARCH="${1:-}"
            if [ -z "$SINGLE_ARCH" ]; then
                echo -e "${RED}❌ --single requires an architecture${NC}" >&2
                exit 1
            fi
            case "$SINGLE_ARCH" in
                arm64|arm|amd64|386) ;;
                *) echo -e "${RED}❌ Unsupported architecture: ${SINGLE_ARCH}${NC}" >&2; exit 1 ;;
            esac
            ;;
        --info)       print_info ;;
        --list)       print_archs ;;
        --help|-h)    print_help ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}" >&2
            echo -e "${DIM}Run: ./build.sh --help${NC}" >&2
            exit 1
            ;;
    esac
    shift
done

# Make BUILD_DIR absolute (if relative, resolve against current PWD)
case "$BUILD_DIR" in
    /*) ;;  # absolute
    *) BUILD_DIR="$(cd "$(dirname "$BUILD_DIR")" 2>/dev/null && pwd)/$(basename "$BUILD_DIR")" ;;
esac

# Warn: --parallel with --single
if [ "$DO_PARALLEL" = "1" ] && [ -n "$SINGLE_ARCH" ]; then
    echo -e "${YELLOW}⚠️  --parallel is meaningless with --single — ignoring${NC}" >&2
    DO_PARALLEL=0
fi

# BLD-5: verify UPX is installed at argument-parsing time so the
# user is told immediately rather than after the build starts.
if [ "$USE_UPX" = "1" ]; then
    if ! command -v upx >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  --enable-upx requested but 'upx' not found — disabling UPX${NC}" >&2
        USE_UPX=0
    fi
fi

# BLD-3: check whether `timeout` is available. If not, the
# build runs without a hard time limit and logs a warning.
if command -v timeout >/dev/null 2>&1; then
    HAS_TIMEOUT=1
else
    HAS_TIMEOUT=0
fi

# ------------------------------------------------------------
# [16] Header + Go check
# ------------------------------------------------------------
print_header
detect_environment
echo -e "  🌍 Environment: ${CYAN}${ENV_TYPE}${NC}"
echo -e "  📦 Version:     ${GREEN}${SCRIPT_VERSION}${NC}"
echo -e "  🏷️  Commit:      ${CYAN}${BUILD_COMMIT}${NC}"
echo -e "  🔗 Project URL: ${CYAN}${PROJECT_URL}${NC}"
echo -e "  📁 BUILD_DIR:   ${CYAN}${BUILD_DIR}${NC}"
echo ""

if ! command -v go >/dev/null 2>&1; then
    echo -e "${RED}❌ 'go' is not installed${NC}" >&2
    exit 1
fi

GO_VERSION_RAW=$(go version | awk '{print $3}')
GO_VERSION_NUM="${GO_VERSION_RAW#go}"
GO_MAJOR=$(echo "$GO_VERSION_NUM" | cut -d. -f1)
GO_MINOR=$(echo "$GO_VERSION_NUM" | cut -d. -f2)

echo -e "${GREEN}✅ Go:${NC} $(go version)"

if [ "$GO_MAJOR" -lt "$REQUIRED_GO_MAJOR" ] || \
   { [ "$GO_MAJOR" -eq "$REQUIRED_GO_MAJOR" ] && [ "$GO_MINOR" -lt "$REQUIRED_GO_MINOR" ]; }; then
    echo -e "${RED}❌ Go ${REQUIRED_GO_MAJOR}.${REQUIRED_GO_MINOR}+ required${NC}" >&2
    exit 1
fi

if [ "$HAS_TIMEOUT" = "1" ]; then
    echo -e "${GREEN}✅ timeout:${NC} available (build will be time-bounded)"
else
    echo -e "${YELLOW}⚠️  timeout:${NC} not available (build will NOT be time-bounded)"
fi

# ------------------------------------------------------------
# [17] Check main.go
# ------------------------------------------------------------
if [ ! -f "${SCRIPT_DIR}/main.go" ]; then
    echo -e "${RED}❌ main.go not found at ${SCRIPT_DIR}${NC}" >&2
    exit 1
fi

# ------------------------------------------------------------
# [18] go.mod
# ------------------------------------------------------------
cd "$SCRIPT_DIR"

if [ ! -f "go.mod" ]; then
    echo -e "${DIM}→ go mod init dnscrypt-webui${NC}"
    # BLD-8: don't silently swallow the failure. If go.mod still
    # does not exist after the init attempt, the subsequent
    # `go build` will fail with a confusing error; we print a
    # clear diagnostic here instead.
    if ! go mod init dnscrypt-webui >/dev/null 2>&1; then
        if [ ! -f "go.mod" ]; then
            echo -e "${RED}❌ 'go mod init' failed and go.mod is still missing${NC}" >&2
            echo -e "${DIM}   Check that the current directory is writable and that 'go' is functional.${NC}" >&2
            exit 1
        fi
    fi
fi

if [ -f "go.mod" ] && [ -f "go.sum" ]; then
    echo -e "${DIM}→ go mod download${NC}"
    go mod download >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------
# [19] Full LDFLAGS
# ------------------------------------------------------------
# BuildVersion is injected into main.go via -X. main.go reads it
# at startup and exposes it via /api?action=runtime_info. The
# value comes from VERSION (single source of truth), not hardcoded.
#
# For v1.2.0:
#   • VERSION contains "v1.2.0" → -X main.BuildVersion=v1.2.0
#   • The v1.2.0 data-preservation features (customize.sh,
#     functions.sh, service.sh, status.sh, uninstall.sh,
#     watchdog.sh) do NOT affect this step. Only the Go source
#     (main.go) is compiled here.
#
# Other injected variables:
#   • BuildCommit  → short git hash (+ -dirty suffix if applicable)
#   • BuildTime    → SOURCE_DATE_EPOCH (for reproducible builds)
#   • ProjectURL   → canonical repository URL
#
# -buildid= removes the random build ID that Go would otherwise
# generate, ensuring byte-identical output for the same inputs.
# ------------------------------------------------------------
LDFLAGS="${LDFLAGS_BASE}"
LDFLAGS="${LDFLAGS} -X main.BuildVersion=${SCRIPT_VERSION}"
LDFLAGS="${LDFLAGS} -X main.BuildCommit=${BUILD_COMMIT}"
LDFLAGS="${LDFLAGS} -X main.BuildTime=${SOURCE_DATE_EPOCH}"
LDFLAGS="${LDFLAGS} -X main.ProjectURL=${PROJECT_URL}"
LDFLAGS="${LDFLAGS} -buildid="

GOFLAGS="-buildvcs=false -trimpath -mod=readonly"

# ------------------------------------------------------------
# [20] NDK detection
# ------------------------------------------------------------
NDK_PATH=""
NDK_BIN=""

if NDK_PATH=$(detect_ndk); then
    echo -e "${GREEN}✅ NDK:${NC} ${NDK_PATH}"
    NDK_BIN=$(get_ndk_bin "$NDK_PATH") || NDK_BIN=""
    echo ""
    echo -e "${BOLD}🔧 CC per architecture:${NC}"
    for arch in $ALL_ARCHS; do
        cc=$(get_cc_for_arch "$arch" "$NDK_BIN" 2>/dev/null || true)
        if [ -n "$cc" ] && [ -x "$cc" ]; then
            echo -e "  ${GREEN}✅${NC} ${arch}"
        else
            echo -e "  ${RED}❌${NC} ${arch}"
        fi
    done
    echo ""
else
    echo -e "${YELLOW}⚠️  NDK not found — building with CGO_ENABLED=0${NC}"
    echo ""
fi

# ------------------------------------------------------------
# [21] UPX + PIE warning
# ------------------------------------------------------------
# BLD-5: the USE_UPX flag was already validated during argument
# parsing. This section only prints the reminder.
# ------------------------------------------------------------
if [ "$USE_UPX" = "1" ]; then
    echo -e "${YELLOW}⚠️  UPX enabled — may break PIE${NC}"
    echo -e "${DIM}   Android 5+ requires PIE. Verify the output.${NC}"
    echo ""
fi

# ------------------------------------------------------------
# [22] Clean
# ------------------------------------------------------------
if [ "$DO_CLEAN" = "1" ] && [ -d "$BUILD_DIR" ]; then
    echo -e "${BLUE}🧹 Cleaning ${BUILD_DIR}${NC}"
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

# ------------------------------------------------------------
# [23] Determine architectures
# ------------------------------------------------------------
if [ -n "$SINGLE_ARCH" ]; then
    ARCHS="$SINGLE_ARCH"
    EXPECTED_ARCH_COUNT=1
else
    ARCHS="$ALL_ARCHS"
fi

# ------------------------------------------------------------
# [24] Build function for a single architecture
# ------------------------------------------------------------
build_arch() {
    local ARCH="$1"
    local GO_VARS
    GO_VARS=$(get_go_vars "$ARCH")
    local GOARCH_VAL="${GO_VARS%%:*}"
    local GOARM_VAL="${GO_VARS##*:}"

    local OUTPUT="$BUILD_DIR/${OUTPUT_PREFIX}-${ARCH}"
    local LOGFILE="$BUILD_DIR/.build-${ARCH}.log"

    printf "  ${CYAN}→${NC} %-8s ${DIM}(GOARCH=%s%s)${NC}  " \
        "$ARCH" "$GOARCH_VAL" "${GOARM_VAL:+ GOARM=$GOARM_VAL}"

    local CC_PATH=""
    local CGO_MODE=0
    if [ -n "$NDK_BIN" ]; then
        CC_PATH=$(get_cc_for_arch "$ARCH" "$NDK_BIN" 2>/dev/null || true)
        if [ -n "$CC_PATH" ] && [ -x "$CC_PATH" ]; then
            CGO_MODE=1
        else
            CC_PATH=""
        fi
    fi

    local OS_TARGET="linux"
    [ "$CGO_MODE" = "1" ] && OS_TARGET="android"

    local BUILD_ENV=(
        "GOOS=$OS_TARGET"
        "GOARCH=$GOARCH_VAL"
        "CGO_ENABLED=$CGO_MODE"
        "SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"
    )
    [ -n "$GOARM_VAL" ] && BUILD_ENV+=("GOARM=$GOARM_VAL")
    [ -n "$CC_PATH" ] && BUILD_ENV+=("CC=$CC_PATH")

    # BLD-3: use `timeout` when available; otherwise run the
    # build without a hard time limit. On CI/Termux the timeout
    # is present; on macOS without coreutils it may not be.
    local build_ok=0
    if [ "$HAS_TIMEOUT" = "1" ]; then
        if timeout 300 env "${BUILD_ENV[@]}" go build \
            -ldflags="$LDFLAGS" \
            -tags "$BUILD_TAGS" \
            -buildmode "$BUILDMODE" \
            $GOFLAGS \
            -o "$OUTPUT" \
            main.go > "$LOGFILE" 2>&1; then
            build_ok=1
        fi
    else
        if env "${BUILD_ENV[@]}" go build \
            -ldflags="$LDFLAGS" \
            -tags "$BUILD_TAGS" \
            -buildmode "$BUILDMODE" \
            $GOFLAGS \
            -o "$OUTPUT" \
            main.go > "$LOGFILE" 2>&1; then
            build_ok=1
        fi
    fi

    if [ "$build_ok" = "1" ]; then
        if [ ! -s "$OUTPUT" ]; then
            echo -e "${RED}✗ (empty file)${NC}"
            return 1
        fi

        if command -v od >/dev/null 2>&1; then
            local magic
            magic=$(od -An -tx1 -N4 "$OUTPUT" 2>/dev/null | tr -d ' \n')
            if [ "$magic" != "7f454c46" ]; then
                echo -e "${RED}✗ (not ELF)${NC}"
                return 1
            fi
        fi

        if [ "$USE_UPX" = "1" ] && command -v upx >/dev/null 2>&1; then
            upx --best --lzma "$OUTPUT" >> "$LOGFILE" 2>&1 || true
        fi

        local PIE_STATUS="${DIM}n/a${NC}"
        if command -v file >/dev/null 2>&1; then
            if file "$OUTPUT" | grep -q "pie executable"; then
                PIE_STATUS="${GREEN}PIE${NC}"
            else
                PIE_STATUS="${YELLOW}non-PIE${NC}"
            fi
        fi

        local CGO_STATUS=""
        [ "$CGO_MODE" = "1" ] && CGO_STATUS="${DIM}[cgo-${OS_TARGET}]${NC}"

        echo -e "${GREEN}✓${NC} $PIE_STATUS $CGO_STATUS"
        chmod +x "$OUTPUT"
        [ "$KEEP_LOGS" = "1" ] || rm -f "$LOGFILE"
        return 0
    else
        echo -e "${RED}✗${NC}"
        echo ""
        echo -e "${RED}════ Build log for $ARCH ════${NC}"
        tail -30 "$LOGFILE" 2>/dev/null || true
        echo -e "${RED}════════════════════════════${NC}"
        return 1
    fi
}

# ------------------------------------------------------------
# [25] Build
# ------------------------------------------------------------
echo -e "${BOLD}🔨 Building ${SCRIPT_VERSION} for:${NC} ${CYAN}${ARCHS}${NC}"
echo ""

START_TIME=$(date +%s)
FAILED_ARCHS=""
SUCCESS_ARCHS=""
SUCCESS_COUNT=0

if [ "$DO_PARALLEL" = "1" ]; then
    PIDS=()
    ARCH_LIST=()

    for ARCH in $ARCHS; do
        build_arch "$ARCH" &
        PIDS+=($!)
        ARCH_LIST+=("$ARCH")
    done

    for i in "${!PIDS[@]}"; do
        if wait "${PIDS[$i]}"; then
            SUCCESS_ARCHS="${SUCCESS_ARCHS} ${ARCH_LIST[$i]}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAILED_ARCHS="${FAILED_ARCHS} ${ARCH_LIST[$i]}"
        fi
    done
else
    for ARCH in $ARCHS; do
        if build_arch "$ARCH"; then
            SUCCESS_ARCHS="${SUCCESS_ARCHS} ${ARCH}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAILED_ARCHS="${FAILED_ARCHS} ${ARCH}"
        fi
    done
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# ------------------------------------------------------------
# [26] Build summary
# ------------------------------------------------------------
echo ""
if [ -z "$FAILED_ARCHS" ]; then
    echo -e "${GREEN}✅ Build complete${NC} ${DIM}(${ELAPSED}s, ${SUCCESS_COUNT}/${EXPECTED_ARCH_COUNT})${NC}"
else
    echo -e "${YELLOW}⚠️  Build partial${NC} ${DIM}(${ELAPSED}s, ${SUCCESS_COUNT}/${EXPECTED_ARCH_COUNT})${NC}"
    echo -e "   ${RED}Failed:${NC}${FAILED_ARCHS}"
fi

if [ "$SUCCESS_COUNT" -lt "$EXPECTED_ARCH_COUNT" ]; then
    echo -e "${RED}❌ Output count (${SUCCESS_COUNT}) is less than expected (${EXPECTED_ARCH_COUNT})${NC}" >&2
fi

# ------------------------------------------------------------
# [27] Checksums
# ------------------------------------------------------------
if [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${BOLD}🔐 Generating checksums...${NC}"

    CHECKSUM_FILE="$BUILD_DIR/checksums.txt"

    # BLD-4: when SOURCE_DATE_EPOCH=0 (git unavailable), print a
    # human-friendly "unknown" instead of 1970-01-01.
    if [ "$SOURCE_DATE_EPOCH" -gt 0 ] 2>/dev/null; then
        BUILD_DATE_HUMAN=$(date -u -d "@${SOURCE_DATE_EPOCH}" +'%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || date -u +'%Y-%m-%d %H:%M:%S UTC')
    else
        BUILD_DATE_HUMAN="unknown (SOURCE_DATE_EPOCH=0)"
    fi

    {
        echo "# DNSCrypt WebUI ${SCRIPT_VERSION}"
        echo "# Commit: ${BUILD_COMMIT}"
        echo "# Project: ${PROJECT_URL}"
        echo "# Date: ${BUILD_DATE_HUMAN}"
        echo "# Env: ${ENV_TYPE}"
        echo "# Reproducible: SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
        echo ""
    } > "$CHECKSUM_FILE"

    cd "$BUILD_DIR"
    CHECKSUM_TOOL=""
    if command -v sha256sum >/dev/null 2>&1; then
        CHECKSUM_TOOL="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        CHECKSUM_TOOL="shasum -a 256"
    fi

    if [ -n "$CHECKSUM_TOOL" ]; then
        for f in ${OUTPUT_PREFIX}-*; do
            [ -f "$f" ] || continue
            case "$f" in
                *.log|*.log.*) continue ;;
            esac
            $CHECKSUM_TOOL "$f" >> "checksums.txt"
        done
        echo -e "${GREEN}✅${NC} ${CHECKSUM_FILE}"
    else
        echo -e "${YELLOW}⚠️  No sha256sum or shasum available${NC}"
    fi
    cd - >/dev/null
fi

# ------------------------------------------------------------
# [28] Output table
# ------------------------------------------------------------
if [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${BOLD}📦 Build artifacts:${NC}"
    echo ""
    printf "  %-30s %12s %10s\n" "Binary" "Size" "Type"

    for ARCH in $ARCHS; do
        OUTPUT="$BUILD_DIR/${OUTPUT_PREFIX}-${ARCH}"
        if [ -f "$OUTPUT" ]; then
            SIZE_DISPLAY=$(du -h "$OUTPUT" 2>/dev/null | cut -f1)
            TYPE_DISPLAY="?"
            if command -v file >/dev/null 2>&1; then
                if file "$OUTPUT" | grep -q "pie executable"; then
                    TYPE_DISPLAY="${GREEN}PIE${NC}"
                else
                    TYPE_DISPLAY="${YELLOW}non-PIE${NC}"
                fi
            fi
            printf "  ${CYAN}%-30s${NC} ${DIM}%12s${NC} %10b\n" \
                "${OUTPUT_PREFIX}-${ARCH}" "$SIZE_DISPLAY" "$TYPE_DISPLAY"
        fi
    done
    echo ""
fi

# ------------------------------------------------------------
# [29] Packaging (binaries only)
# ------------------------------------------------------------
if [ "$DO_PACKAGE" = "1" ] && [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo -e "${BOLD}📦 Creating binaries ZIP...${NC}"
    PKG_NAME="${OUTPUT_PREFIX}-${VERSION_NO_V}-binaries.zip"
    PKG_PATH="${BUILD_DIR}/${PKG_NAME}"

    if ! command -v zip >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  'zip' not installed — skipping packaging${NC}"
    else
        rm -f "$PKG_PATH"

        FILES_TO_ZIP=""
        cd "$BUILD_DIR"
        for f in ${OUTPUT_PREFIX}-* checksums.txt; do
            [ -f "$f" ] || continue
            case "$f" in
                *.log|*.log.*) continue ;;
            esac
            FILES_TO_ZIP="${FILES_TO_ZIP} ${f}"
        done

        if [ -n "$FILES_TO_ZIP" ]; then
            # shellcheck disable=SC2086
            if zip -q -j "$PKG_PATH" $FILES_TO_ZIP 2>/dev/null; then
                PKG_SIZE=$(du -h "$PKG_PATH" 2>/dev/null | cut -f1)
                echo -e "${GREEN}✅${NC} ${PKG_NAME} (${PKG_SIZE})"
            else
                echo -e "${RED}❌ Failed to create ZIP${NC}"
            fi
        fi
        cd - >/dev/null
    fi
    echo ""
fi

# ------------------------------------------------------------
# [30] Final PIE verification
# ------------------------------------------------------------
if [ "$SUCCESS_COUNT" -gt 0 ] && command -v file >/dev/null 2>&1; then
    echo -e "${BOLD}🔍 PIE Verification:${NC}"
    ALL_PIE=1
    for ARCH in $ARCHS; do
        OUTPUT="$BUILD_DIR/${OUTPUT_PREFIX}-${ARCH}"
        [ -f "$OUTPUT" ] || continue
        if file "$OUTPUT" | grep -q "pie executable"; then
            echo -e "  ${GREEN}✅${NC} ${ARCH}"
        else
            echo -e "  ${YELLOW}⚠️${NC}  ${ARCH} (non-PIE)"
            ALL_PIE=0
        fi
    done

    echo ""
    if [ "$ALL_PIE" = "1" ]; then
        echo -e "  ${GREEN}🎉 All binaries are PIE — Android 5+ compatible${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Some binaries are non-PIE${NC}"
        echo -e "  ${DIM}Check whether --enable-upx was used.${NC}"
    fi
    echo ""
fi

# ------------------------------------------------------------
# [31] Exit
# ------------------------------------------------------------
if [ -n "$FAILED_ARCHS" ]; then
    exit 1
fi

exit 0