#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter — build.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-18
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Cross-compiles the WebUI (main.go) for 4 Android architectures
# using the Android NDK. Supports reproducible builds.
#
# Architectures:
#   • arm64  → arm64-v8a
#   • arm    → armeabi-v7a (GOARM=7)
#   • amd64  → x86_64
#   • 386    → x86 (32-bit)
#
# Modes:
#   ./build.sh                     Build all 4 architectures
#   ./build.sh --single <arch>     Build one architecture
#   ./build.sh --parallel          Build all in parallel
#
# Flags:
#   --clean              Clean proxy/build/ before building
#   --package            Create a binaries ZIP after build
#   --enable-upx         Compress with UPX (may break PIE)
#   --keep-logs          Keep build logs even on success
#   --output-dir DIR     Custom output directory
#   --info               Show environment + NDK info
#   --list               List supported architectures
#   --help, -h           Show help
#
# Environment variables:
#   ANDROID_NDK_HOME     NDK path (optional but recommended)
#   PROJECT_URL          Project URL
#   BUILD_DIR            Override output directory
#   SOURCE_DATE_EPOCH    Fixed timestamp (auto-extracted from git)
#
# Output (proxy/build/):
#   dnscrypt-webui-arm64
#   dnscrypt-webui-arm
#   dnscrypt-webui-amd64
#   dnscrypt-webui-386
#   checksums.txt
#
# Reproducibility:
#   • SOURCE_DATE_EPOCH extracted from the last git commit
#   • -trimpath normalizes file paths
#   • -buildid= removes random build IDs
#   • Result: same commit → same SHA-256
#
# ⚠️ PIE requirements — two independent ways the build can produce
#    a non-PIE binary that will NOT run on Android 5+:
#
#    1. UPX (--enable-upx) strips the ELF segments Android uses to
#       verify PIE-ness. A UPX-compressed binary will not run on
#       Android 5+. Do NOT use --enable-upx for release builds.
#
#    2. Missing NDK forces CGO_ENABLED=0, which cannot produce a
#       PIE binary on linux (the linker would need external linking,
#       which only cgo provides). The build falls back to
#       -buildmode=default and emits a warning. Always provide
#       ANDROID_NDK_HOME for release builds.
# ============================================================

set -euo pipefail

# ============================================================
# [1] Path resolution
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${REPO_ROOT}/VERSION"

# ============================================================
# [2] Colors (conditional on TTY)
# ============================================================
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'
    DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

# ============================================================
# [3] Configuration
# ============================================================
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

EXPECTED_ARCH_COUNT=0
for _a in $ALL_ARCHS; do
    EXPECTED_ARCH_COUNT=$((EXPECTED_ARCH_COUNT + 1))
done
unset _a

PROJECT_URL="${PROJECT_URL:-https://github.com/gasciljh/dnscrypt-proxy-webui}"

# ============================================================
# [4] Read VERSION (SSOT for BuildVersion)
# ============================================================
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
VERSION_NO_V="${SCRIPT_VERSION#v}"

# ============================================================
# [5] Reproducible build vars (strict SOURCE_DATE_EPOCH)
# ============================================================
# SOURCE_DATE_EPOCH semantics:
#   0          = unknown / not applicable (no git, no commit)
#   > 0        = epoch seconds; enables reproducible builds
#   invalid    = coerced to 0 with a warning below
#
# The value is validated HERE — downstream code (LDFLAGS, the
# checksum block) may assume it is a non-negative integer.
# The `*[!0-9]*` pattern catches negative values (`-` is not a
# digit), so no `-lt 0` test is required.
SOURCE_DATE_EPOCH_RAW=""

if command -v git >/dev/null 2>&1 && \
   git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    SOURCE_DATE_EPOCH_RAW=$(git -C "$REPO_ROOT" log -1 --format=%ct 2>/dev/null || echo "0")
    BUILD_COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GIT_DIRTY=""
    if ! git -C "$REPO_ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
        GIT_DIRTY="-dirty"
    fi
    BUILD_COMMIT="${BUILD_COMMIT}${GIT_DIRTY}"
else
    SOURCE_DATE_EPOCH_RAW="0"
    BUILD_COMMIT="unknown"
fi

case "$SOURCE_DATE_EPOCH_RAW" in
    ''|*[!0-9]*)
        SOURCE_DATE_EPOCH=0
        ;;
    *)
        SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH_RAW"
        ;;
esac
export SOURCE_DATE_EPOCH
unset SOURCE_DATE_EPOCH_RAW

# ============================================================
# [6] Helper functions
# ============================================================

# detect_environment — identify the build environment.
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

# detect_ndk — find the Android NDK path.
#
# Search order:
#   1. Environment variables (ANDROID_NDK_HOME, ANDROID_NDK_ROOT,
#      NDK, NDK_ROOT)
#   2. Common install locations
#
# A valid NDK path must contain toolchains/llvm/prebuilt/*/bin.
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

# get_ndk_bin — extract the platform-specific bin/ directory.
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

# get_cc_for_arch — map a short arch name to its NDK clang path.
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

# get_go_vars — map a short arch name to "GOARCH:GOARM".
get_go_vars() {
    case "$1" in
        arm64) printf 'arm64:' ;;
        arm)   printf 'arm:7' ;;
        amd64) printf 'amd64:' ;;
        386)   printf '386:' ;;
    esac
}

# ============================================================
# [7] Header
# ============================================================
print_header() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  🔨 DNSCrypt Smart Filter ${CYAN}${SCRIPT_VERSION}${NC}${BOLD} – Cloud Build      ║${NC}"
    echo -e "${BOLD}║  ${DIM}Reproducible Edition${NC}                                  ${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
# [8] Help text
# ============================================================
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
  • Without NDK, CGO is disabled and the resulting binaries are
    non-PIE — they will NOT run on Android 5+. Always provide
    ANDROID_NDK_HOME for release builds.
  • The output directory can be overridden by --output-dir or
    by the BUILD_DIR environment variable.
EOF
    exit 0
}

# ============================================================
# [9] Info output
# ============================================================
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
        echo -e "  ${YELLOW}⚠️  Will build with CGO_ENABLED=0 → non-PIE (dev-only)${NC}"
        echo -e "  ${DIM}   Non-PIE binaries will NOT run on Android 5+.${NC}"
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

# ============================================================
# [10] Architecture list
# ============================================================
print_archs() {
    print_header
    echo -e "  Architectures: ${CYAN}${ALL_ARCHS}${NC}"
    echo -e "  Count:         ${EXPECTED_ARCH_COUNT}"
    echo ""
    exit 0
}

# ============================================================
# [11] CLI arguments
# ============================================================
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

# Make BUILD_DIR absolute. If the parent directory does not
# exist, warn and fall back to the current working directory
# rather than producing a bogus path.
case "$BUILD_DIR" in
    /*) ;;
    *)
        _build_parent="$(dirname "$BUILD_DIR")"
        _build_base="$(basename "$BUILD_DIR")"
        if _parent_abs="$(cd "$_build_parent" 2>/dev/null && pwd)"; then
            BUILD_DIR="${_parent_abs}/${_build_base}"
        else
            echo -e "${YELLOW}⚠️  Parent of BUILD_DIR does not exist: ${_build_parent}${NC}" >&2
            echo -e "${YELLOW}   Falling back to: $(pwd)/${_build_base}${NC}" >&2
            BUILD_DIR="$(pwd)/${_build_base}"
        fi
        unset _build_parent _build_base _parent_abs
        ;;
esac

if [ "$DO_PARALLEL" = "1" ] && [ -n "$SINGLE_ARCH" ]; then
    echo -e "${YELLOW}⚠️  --parallel is meaningless with --single — ignoring${NC}" >&2
    DO_PARALLEL=0
fi

if [ "$USE_UPX" = "1" ]; then
    if ! command -v upx >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  --enable-upx requested but 'upx' not found — disabling UPX${NC}" >&2
        USE_UPX=0
    fi
fi

if command -v timeout >/dev/null 2>&1; then
    HAS_TIMEOUT=1
else
    HAS_TIMEOUT=0
fi

# ============================================================
# [12] Header + Go check
# ============================================================
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

# Extract Go version robustly. Release builds report
# `go version go1.22.3 ...` — $3 is `go1.22.3`. Development
# builds report `go version devel go1.22-xyz ...` — $3 is
# `devel` and the minor is not parseable from that token.
GO_VERSION_RAW=$(go version | awk '{print $3}')
case "$GO_VERSION_RAW" in
    go*)
        GO_VERSION_NUM="${GO_VERSION_RAW#go}"
        ;;
    *)
        GO_VERSION_NUM=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | head -n1 | sed 's/^go//')
        ;;
esac

GO_MAJOR=$(echo "${GO_VERSION_NUM:-0}" | cut -d. -f1)
GO_MINOR=$(echo "${GO_VERSION_NUM:-0}" | cut -d. -f2)

if ! echo "$GO_MAJOR" | grep -qE '^[0-9]+$' || \
   ! echo "$GO_MINOR" | grep -qE '^[0-9]+$'; then
    echo -e "${RED}❌ Cannot parse Go version from: $(go version)${NC}" >&2
    exit 1
fi

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

# ============================================================
# [13] Check main.go
# ============================================================
if [ ! -f "${SCRIPT_DIR}/main.go" ]; then
    echo -e "${RED}❌ main.go not found at ${SCRIPT_DIR}${NC}" >&2
    exit 1
fi

# ============================================================
# [14] go.mod
# ============================================================
cd "$SCRIPT_DIR"

if [ ! -f "go.mod" ]; then
    echo -e "${DIM}→ go mod init dnscrypt-webui${NC}"
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

# ============================================================
# [15] Full LDFLAGS
# ============================================================
LDFLAGS="${LDFLAGS_BASE}"
LDFLAGS="${LDFLAGS} -X main.BuildVersion=${SCRIPT_VERSION}"
LDFLAGS="${LDFLAGS} -X main.BuildCommit=${BUILD_COMMIT}"
LDFLAGS="${LDFLAGS} -X main.BuildTime=${SOURCE_DATE_EPOCH}"
LDFLAGS="${LDFLAGS} -X main.ProjectURL=${PROJECT_URL}"
LDFLAGS="${LDFLAGS} -buildid="

GOFLAGS=(-buildvcs=false -trimpath -mod=readonly)

# ============================================================
# [16] NDK detection
# ============================================================
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
    echo -e "${YELLOW}⚠️  NDK not found — building with CGO_ENABLED=0 (non-PIE)${NC}"
    echo -e "${DIM}   The resulting binaries will NOT run on Android 5+.${NC}"
    echo -e "${DIM}   This mode is intended for local dev/testing only.${NC}"
    echo ""
fi

# ============================================================
# [17] UPX + PIE warning
# ============================================================
if [ "$USE_UPX" = "1" ]; then
    echo -e "${YELLOW}⚠️  UPX enabled — may break PIE${NC}"
    echo -e "${DIM}   Android 5+ requires PIE. Verify the output.${NC}"
    echo ""
fi

# ============================================================
# [18] Clean
# ============================================================
if [ "$DO_CLEAN" = "1" ] && [ -d "$BUILD_DIR" ]; then
    echo -e "${BLUE}🧹 Cleaning ${BUILD_DIR}${NC}"
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

# ============================================================
# [19] Determine architectures
# ============================================================
if [ -n "$SINGLE_ARCH" ]; then
    ARCHS="$SINGLE_ARCH"
    EXPECTED_ARCH_COUNT=1
else
    ARCHS="$ALL_ARCHS"
fi

# ============================================================
# [20] Build a single architecture
# ============================================================
# Output discipline: each call prints exactly ONE line. In
# parallel mode this prevents the progress prefix and the
# result suffix from interleaving across architectures.
build_arch() {
    local ARCH="$1"
    local GO_VARS
    GO_VARS=$(get_go_vars "$ARCH")
    local GOARCH_VAL="${GO_VARS%%:*}"
    local GOARM_VAL="${GO_VARS##*:}"

    local OUTPUT="$BUILD_DIR/${OUTPUT_PREFIX}-${ARCH}"
    local LOGFILE="$BUILD_DIR/.build-${ARCH}.log"

    # Resolve the C compiler for this architecture.
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

    # When CGO is disabled (no NDK), we fall back to a linux build.
    # `-buildmode=pie` requires external (cgo) linking on linux,
    # so using it with CGO_ENABLED=0 would fail. Use the default
    # buildmode in that case — the resulting binary is a fallback
    # for local testing, not for release. See the header of this
    # script for the full rationale.
    local EFFECTIVE_BUILDMODE="$BUILDMODE"
    if [ "$CGO_MODE" = "0" ]; then
        EFFECTIVE_BUILDMODE="default"
    fi

    local BUILD_ENV=(
        "GOOS=$OS_TARGET"
        "GOARCH=$GOARCH_VAL"
        "CGO_ENABLED=$CGO_MODE"
        "SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"
    )
    [ -n "$GOARM_VAL" ] && BUILD_ENV+=("GOARM=$GOARM_VAL")
    [ -n "$CC_PATH" ] && BUILD_ENV+=("CC=$CC_PATH")

    # Build. Use `timeout` when available (5-minute cap per arch).
    local build_ok=0
    if [ "$HAS_TIMEOUT" = "1" ]; then
        if timeout 300 env "${BUILD_ENV[@]}" go build \
            -ldflags="$LDFLAGS" \
            -tags "$BUILD_TAGS" \
            -buildmode "$EFFECTIVE_BUILDMODE" \
            "${GOFLAGS[@]}" \
            -o "$OUTPUT" \
            main.go > "$LOGFILE" 2>&1; then
            build_ok=1
        fi
    else
        if env "${BUILD_ENV[@]}" go build \
            -ldflags="$LDFLAGS" \
            -tags "$BUILD_TAGS" \
            -buildmode "$EFFECTIVE_BUILDMODE" \
            "${GOFLAGS[@]}" \
            -o "$OUTPUT" \
            main.go > "$LOGFILE" 2>&1; then
            build_ok=1
        fi
    fi

    # Single-line result for both parallel and serial modes.
    local PREFIX
    PREFIX=$(printf "  ${CYAN}→${NC} %-8s ${DIM}(GOARCH=%s%s)${NC}  " \
        "$ARCH" "$GOARCH_VAL" "${GOARM_VAL:+ GOARM=$GOARM_VAL}")

    if [ "$build_ok" = "1" ]; then
        if [ ! -s "$OUTPUT" ]; then
            printf '%s%s\n' "$PREFIX" "${RED}✗ (empty file)${NC}"
            return 1
        fi

        # Verify ELF magic when `od` is available. On stripped-down
        # hosts where `od` is missing, log a warning once instead
        # of silently skipping the check.
        if command -v od >/dev/null 2>&1; then
            local magic
            magic=$(od -An -tx1 -N4 "$OUTPUT" 2>/dev/null | tr -d ' \n')
            if [ "$magic" != "7f454c46" ]; then
                printf '%s%s\n' "$PREFIX" "${RED}✗ (not ELF)${NC}"
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

        printf '%s%s %s %s\n' "$PREFIX" "${GREEN}✓${NC}" "$PIE_STATUS" "$CGO_STATUS"
        chmod +x "$OUTPUT"
        [ "$KEEP_LOGS" = "1" ] || rm -f "$LOGFILE"
        return 0
    else
        printf '%s%s\n' "$PREFIX" "${RED}✗${NC}"
        echo ""
        echo -e "${RED}════ Build log for $ARCH ════${NC}"
        tail -30 "$LOGFILE" 2>/dev/null || true
        echo -e "${RED}════════════════════════════${NC}"
        return 1
    fi
}

# ============================================================
# [21] Build
# ============================================================
echo -e "${BOLD}🔨 Building ${SCRIPT_VERSION} for:${NC} ${CYAN}${ARCHS}${NC}"
echo ""

if command -v od >/dev/null 2>&1; then
    OD_AVAILABLE=1
else
    OD_AVAILABLE=0
    echo -e "${YELLOW}⚠️  'od' not available — ELF magic verification will be skipped${NC}"
fi

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

# ============================================================
# [22] Build summary
# ============================================================
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

# ============================================================
# [23] Checksums
# ============================================================
if [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${BOLD}🔐 Generating checksums...${NC}"

    CHECKSUM_FILE="$BUILD_DIR/checksums.txt"

    # Compute a human-readable build date. When SOURCE_DATE_EPOCH=0
    # OR the platform's `date` cannot interpret `-d @N` (BSD/macOS
    # without GNU coreutils), fall back to "unknown" — NOT to the
    # current date, which would silently break reproducibility.
    if [ "$SOURCE_DATE_EPOCH" -gt 0 ]; then
        BUILD_DATE_HUMAN=$(date -u -d "@${SOURCE_DATE_EPOCH}" +'%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || echo "unknown")
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

    # Deterministic filename order via LC_ALL=C sort.
    cd "$BUILD_DIR"
    CHECKSUM_TOOL=""
    if command -v sha256sum >/dev/null 2>&1; then
        CHECKSUM_TOOL="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        CHECKSUM_TOOL="shasum -a 256"
    fi

    if [ -n "$CHECKSUM_TOOL" ]; then
        for f in $(printf '%s\n' "${OUTPUT_PREFIX}"-* | LC_ALL=C sort); do
            [ -f "$f" ] || continue
            case "$f" in
                *.log|*.log.*|checksums.txt) continue ;;
            esac
            $CHECKSUM_TOOL "$f" >> "checksums.txt"
        done
        echo -e "${GREEN}✅${NC} ${CHECKSUM_FILE}"
    else
        echo -e "${YELLOW}⚠️  No sha256sum or shasum available${NC}"
    fi
    cd - >/dev/null
fi

# ============================================================
# [24] Output table
# ============================================================
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

# ============================================================
# [25] Packaging (binaries only)
# ============================================================
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
        for f in $(printf '%s\n' "${OUTPUT_PREFIX}"-* checksums.txt | LC_ALL=C sort); do
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

# ============================================================
# [26] Final PIE verification
# ============================================================
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
        echo -e "  ${DIM}Two possible causes:${NC}"
        echo -e "  ${DIM}  1. --enable-upx was used (strips ELF PIE segments)${NC}"
        echo -e "  ${DIM}  2. NDK was not found — CGO disabled, buildmode fell back to 'default'${NC}"
        echo -e "  ${DIM}Provide ANDROID_NDK_HOME and rebuild for a release.${NC}"
    fi
    echo ""
fi

# ============================================================
# [27] Exit
# ============================================================
if [ -n "$FAILED_ARCHS" ]; then
    exit 1
fi

exit 0