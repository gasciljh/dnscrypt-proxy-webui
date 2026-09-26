#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – build.sh
# Version: v1.1.0
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
# v1.1.0 notes:
#   • The Go runtime soft memory limit is now set dynamically by
#     main.go at startup based on the active blocklist profile
#     (light → 80MB, ultimate → 220MB). This does NOT affect the
#     build system — the memory limit is a runtime concern.
#   • No new build flags are required for v1.1.0.
#   • The module remains dependency-free (Go stdlib only), which
#     keeps the build reproducible and small.
#   • BuildVersion injected via -X main.BuildVersion is read by
#     main.go and used to populate the runtime_info endpoint.
#     The value comes from VERSION (not hardcoded here).
#
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
EXPECTED_ARCH_COUNT=4
ALL_ARCHS="arm64 arm amd64 386"
KEEP_LOGS=0

# ------------------------------------------------------------
# ProjectURL (customizable)
# ------------------------------------------------------------
PROJECT_URL="${PROJECT_URL:-https://github.com/gasciljh/dnscrypt-proxy-webui}"

# ------------------------------------------------------------
# [4] Read VERSION
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
VERSION_NO_V="${SCRIPT_VERSION#v}"

# ------------------------------------------------------------
# [5] Reproducible build vars
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
    exit 0
}

# ------------------------------------------------------------
# [14] Architecture list
# ------------------------------------------------------------
print_archs() {
    print_header
    echo -e "  Architectures: ${CYAN}${ALL_ARCHS}${NC}"
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
    go mod init dnscrypt-webui >/dev/null 2>&1 || true
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
# value comes from VERSION (Single Source of Truth), not hardcoded.
#
# Other injected variables:
#   • BuildCommit  → short git hash (+ -dirty suffix if applicable)
#   • BuildTime    → SOURCE_DATE_EPOCH (for reproducible builds)
#   • ProjectURL   → canonical repository URL
#
# -buildid= removes the random build ID that Go would otherwise
# generate, ensuring byte-identical output for the same inputs.
# ============================================================
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
if [ "$USE_UPX" = "1" ]; then
    echo -e "${YELLOW}⚠️  UPX enabled — may break PIE${NC}"
    echo -e "${DIM}   Android 5+ requires PIE. Verify the output.${NC}"
    if ! command -v upx >/dev/null 2>&1; then
        echo -e "${RED}❌ UPX not installed — disabling${NC}"
        USE_UPX=0
    fi
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

    if timeout 300 env "${BUILD_ENV[@]}" go build \
        -ldflags="$LDFLAGS" \
        -tags "$BUILD_TAGS" \
        -buildmode "$BUILDMODE" \
        $GOFLAGS \
        -o "$OUTPUT" \
        main.go > "$LOGFILE" 2>&1; then

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
    {
        echo "# DNSCrypt WebUI ${SCRIPT_VERSION}"
        echo "# Commit: ${BUILD_COMMIT}"
        echo "# Project: ${PROJECT_URL}"
        echo "# Date: $(date -u -d "@${SOURCE_DATE_EPOCH}" +'%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || date -u +'%Y-%m-%d %H:%M:%S UTC')"
        echo "# Env: ${ENV_TYPE}"
        echo "# Reproducible: SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
        echo ""
    } > "$CHECKSUM_FILE"

    cd "$BUILD_DIR"
    local_checksum_tool=""
    if command -v sha256sum >/dev/null 2>&1; then
        local_checksum_tool="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        local_checksum_tool="shasum -a 256"
    fi

    if [ -n "$local_checksum_tool" ]; then
        for f in ${OUTPUT_PREFIX}-*; do
            [ -f "$f" ] || continue
            case "$f" in
                *.log|*.log.*) continue ;;
            esac
            $local_checksum_tool "$f" >> "checksums.txt"
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
            local_size=$(du -h "$OUTPUT" 2>/dev/null | cut -f1)
            local_type="?"
            if command -v file >/dev/null 2>&1; then
                if file "$OUTPUT" | grep -q "pie executable"; then
                    local_type="${GREEN}PIE${NC}"
                else
                    local_type="${YELLOW}non-PIE${NC}"
                fi
            fi
            printf "  ${CYAN}%-30s${NC} ${DIM}%12s${NC} %10b\n" \
                "${OUTPUT_PREFIX}-${ARCH}" "$local_size" "$local_type"
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

        local_files_to_zip=""
        cd "$BUILD_DIR"
        for f in ${OUTPUT_PREFIX}-* checksums.txt; do
            [ -f "$f" ] || continue
            case "$f" in
                *.log|*.log.*) continue ;;
            esac
            local_files_to_zip="${local_files_to_zip} ${f}"
        done

        if [ -n "$local_files_to_zip" ]; then
            # shellcheck disable=SC2086
            if zip -q -j "$PKG_PATH" $local_files_to_zip 2>/dev/null; then
                pkg_size=$(du -h "$PKG_PATH" 2>/dev/null | cut -f1)
                echo -e "${GREEN}✅${NC} ${PKG_NAME} (${pkg_size})"
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