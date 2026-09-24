#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – generate-icons.sh
# Version: v1.0.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Generate PNG and ICO icons from the SVG sources in web/.
#
#   Source SVGs:
#     • web/icon-192.svg
#     • web/icon-512.svg
#
#   Generated files:
#     • web/icon-192.png              (192×192)
#     • web/icon-512.png              (512×512)
#     • web/apple-touch-icon.png      (180×180, iOS)
#     • web/favicon-32x32.png         (32×32)
#     • web/favicon-16x16.png         (16×16)
#     • web/favicon.ico               (multi-size)
#
# Tools supported (auto-detected, in priority order):
#     1. rsvg-convert   (Ubuntu: apt install librsvg2-bin)  ← fastest
#     2. magick         (ImageMagick 7)
#     3. convert        (ImageMagick 6)
#     4. inkscape       (Inkscape CLI)
#
#   For the .ico file:
#     • ImageMagick (magick/convert) → best multi-size ICO
#     • icotool                       → fallback if available
#     • Copy favicon-32x32.png        → last-resort fallback
#
# Modes:
#   generate-icons.sh             Generate all icons (skip existing)
#   generate-icons.sh --force     Regenerate all icons (overwrite)
#   generate-icons.sh --check     Only verify that files exist
#   generate-icons.sh --verbose   Show verbose output
#   generate-icons.sh --help      Show this help
#
# Notes:
#   • Only regenerates files that are missing (unless --force).
#   • Non-fatal if some tools are absent — it will pick the next
#     available tool from the list.
#   • Designed to be idempotent — safe to run multiple times.
# ============================================================

set -euo pipefail

# ============================================================
# [1] Paths
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WEB_DIR="${REPO_ROOT}/web"

SVG_192="${WEB_DIR}/icon-192.svg"
SVG_512="${WEB_DIR}/icon-512.svg"

PNG_192="${WEB_DIR}/icon-192.png"
PNG_512="${WEB_DIR}/icon-512.png"
APPLE_TOUCH="${WEB_DIR}/apple-touch-icon.png"
FAVICON_32="${WEB_DIR}/favicon-32x32.png"
FAVICON_16="${WEB_DIR}/favicon-16x16.png"
FAVICON_ICO="${WEB_DIR}/favicon.ico"

# ============================================================
# [2] Colors
# ============================================================
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

# ============================================================
# [3] Arguments
# ============================================================
VERBOSE=0
CHECK_ONLY=0
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --verbose|-v) VERBOSE=1 ;;
        --check)      CHECK_ONLY=1 ;;
        --force|-f)   FORCE=1 ;;
        --help|-h)
            cat << 'EOF'
DNSCrypt Smart Filter – generate-icons.sh

Usage:
  generate-icons.sh [options]

Options:
  --verbose, -v    Verbose output
  --check          Only check that the required files exist
  --force, -f      Regenerate even if the files exist
  --help, -h       Show this help

Required tools (at least one):
  • rsvg-convert   (Ubuntu: apt install librsvg2-bin)
  • convert        (Ubuntu: apt install imagemagick)
  • inkscape       (Ubuntu: apt install inkscape)

Examples:
  ./scripts/generate-icons.sh
  ./scripts/generate-icons.sh --check
  ./scripts/generate-icons.sh --force --verbose
EOF
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

# ============================================================
# [4] Helper functions
# ============================================================
log_info()  { echo -e "  ${CYAN}→${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }
log_debug() { [ "$VERBOSE" = "1" ] && echo -e "  ${DIM}·${NC} $1" || true; }

file_size() {
    stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo "?"
}

# ============================================================
# [5] Tool detection
# ============================================================
ICON_TOOL=""
ICON_TOOL_CMD=""

if command -v rsvg-convert >/dev/null 2>&1; then
    ICON_TOOL="rsvg-convert"
    ICON_TOOL_CMD="rsvg-convert"
elif command -v magick >/dev/null 2>&1; then
    ICON_TOOL="ImageMagick (magick)"
    ICON_TOOL_CMD="magick"
elif command -v convert >/dev/null 2>&1; then
    ICON_TOOL="ImageMagick (convert)"
    ICON_TOOL_CMD="convert"
elif command -v inkscape >/dev/null 2>&1; then
    ICON_TOOL="Inkscape"
    ICON_TOOL_CMD="inkscape"
else
    ICON_TOOL=""
fi

# ============================================================
# [6] Header
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  🎨 DNSCrypt Smart Filter – Icon Generator                ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# [7] Check-only mode (--check)
# ============================================================
if [ "$CHECK_ONLY" = "1" ]; then
    echo -e "${BOLD}📋 File check:${NC}"
    echo ""

    MISSING=0

    for f in "$PNG_192" "$PNG_512" "$APPLE_TOUCH" "$FAVICON_32" "$FAVICON_16" "$FAVICON_ICO"; do
        if [ -f "$f" ]; then
            printf "  ${GREEN}✓${NC} %-30s ${DIM}(%s bytes)${NC}\n" "$(basename "$f")" "$(file_size "$f")"
        else
            printf "  ${RED}✗${NC} %-30s ${DIM}(missing)${NC}\n" "$(basename "$f")"
            MISSING=$((MISSING + 1))
        fi
    done

    echo ""
    if [ "$MISSING" -eq 0 ]; then
        echo -e "${GREEN}✅ All files present${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠  $MISSING file(s) missing${NC}"
        echo -e "${DIM}   Run: ./scripts/generate-icons.sh${NC}"
        exit 1
    fi
fi

# ============================================================
# [8] Verify tools and inputs
# ============================================================
if [ -z "$ICON_TOOL" ]; then
    log_error "No SVG → PNG conversion tool found"
    echo ""
    echo -e "${BOLD}Install one of:${NC}"
    echo "  ${DIM}Ubuntu/Debian:${NC}"
    echo "    sudo apt install librsvg2-bin    # ← recommended (fastest)"
    echo "    # or:"
    echo "    sudo apt install imagemagick"
    echo "    # or:"
    echo "    sudo apt install inkscape"
    echo ""
    echo "  ${DIM}macOS:${NC}"
    echo "    brew install librsvg"
    echo "    # or:"
    echo "    brew install imagemagick"
    echo ""
    echo "  ${DIM}Termux (Android):${NC}"
    echo "    pkg install imagemagick"
    echo ""
    exit 1
fi

log_info "Tool: ${ICON_TOOL}"

if [ ! -f "$SVG_192" ]; then
    log_error "Missing: $SVG_192"
    exit 1
fi

if [ ! -f "$SVG_512" ]; then
    log_error "Missing: $SVG_512"
    exit 1
fi

log_ok "Input files present"

# ============================================================
# [9] Unified SVG → PNG conversion
# ============================================================
# convert_svg_to_png SVG_PATH WIDTH HEIGHT OUTPUT_PATH
# ============================================================
convert_svg_to_png() {
    local svg="$1"
    local width="$2"
    local height="$3"
    local output="$4"

    # Skip if it exists and --force is not set
    if [ -f "$output" ] && [ "$FORCE" = "0" ]; then
        log_debug "Exists: $(basename "$output")"
        return 0
    fi

    case "$ICON_TOOL_CMD" in
        rsvg-convert)
            rsvg-convert \
                --width="$width" \
                --height="$height" \
                --keep-aspect-ratio \
                --background-color=none \
                --output="$output" \
                "$svg" 2>/dev/null
            ;;
        magick)
            magick -background none -density 384 \
                "$svg" -resize "${width}x${height}" \
                "$output" 2>/dev/null
            ;;
        convert)
            convert -background none -density 384 \
                "$svg" -resize "${width}x${height}" \
                "$output" 2>/dev/null
            ;;
        inkscape)
            inkscape \
                --export-type=png \
                --export-filename="$output" \
                --export-width="$width" \
                --export-height="$height" \
                "$svg" 2>/dev/null
            ;;
    esac

    if [ ! -f "$output" ] || [ ! -s "$output" ]; then
        log_error "Failed to generate: $(basename "$output")"
        return 1
    fi

    log_ok "$(basename "$output") (${width}×${height}, $(file_size "$output") bytes)"
    return 0
}

# ============================================================
# [10] ICO generation (multi-size)
# ============================================================
# ICO requires a specialized tool — ImageMagick is the best.
# If using rsvg-convert, generate PNGs first, then combine.
# ============================================================
generate_ico() {
    local output="$1"

    if [ -f "$output" ] && [ "$FORCE" = "0" ]; then
        log_debug "Exists: $(basename "$output")"
        return 0
    fi

    # Method 1: ImageMagick directly (best)
    if [ "$ICON_TOOL_CMD" = "magick" ] || [ "$ICON_TOOL_CMD" = "convert" ]; then
        "$ICON_TOOL_CMD" \
            "$FAVICON_16" \
            "$FAVICON_32" \
            -colors 256 \
            "$output" 2>/dev/null

        if [ -f "$output" ] && [ -s "$output" ]; then
            log_ok "$(basename "$output") (multi-size, $(file_size "$output") bytes)"
            return 0
        fi
    fi

    # Method 2: From existing PNGs (fallback)
    if [ -f "$FAVICON_32" ] && command -v icotool >/dev/null 2>&1; then
        icotool -c -o "$output" "$FAVICON_16" "$FAVICON_32" 2>/dev/null

        if [ -f "$output" ] && [ -s "$output" ]; then
            log_ok "$(basename "$output") (icotool, $(file_size "$output") bytes)"
            return 0
        fi
    fi

    # Method 3: Copy favicon-32 as ICO (crude fallback)
    if [ -f "$FAVICON_32" ]; then
        cp "$FAVICON_32" "$output" 2>/dev/null
        log_warn "$(basename "$output") (simplified copy of favicon-32)"
        return 0
    fi

    log_error "Failed to generate: $(basename "$output")"
    return 1
}

# ============================================================
# [11] Generation
# ============================================================
echo ""
echo -e "${BOLD}🎨 Generating...${NC}"
echo ""

# 192×192
convert_svg_to_png "$SVG_192" 192 192 "$PNG_192"

# 512×512
convert_svg_to_png "$SVG_512" 512 512 "$PNG_512"

# Apple Touch Icon (180×180)
convert_svg_to_png "$SVG_512" 180 180 "$APPLE_TOUCH"

# Favicon 32×32
convert_svg_to_png "$SVG_512" 32 32 "$FAVICON_32"

# Favicon 16×16
convert_svg_to_png "$SVG_512" 16 16 "$FAVICON_16"

# favicon.ico (multi-size)
generate_ico "$FAVICON_ICO"

# ============================================================
# [12] Summary
# ============================================================
echo ""
echo -e "${BOLD}━━━ Summary ━━━${NC}"
echo ""

GENERATED=0
TOTAL_SIZE=0

for f in "$PNG_192" "$PNG_512" "$APPLE_TOUCH" "$FAVICON_32" "$FAVICON_16" "$FAVICON_ICO"; do
    if [ -f "$f" ]; then
        size=$(file_size "$f")
        printf "  ${GREEN}✓${NC} %-30s ${DIM}%s bytes${NC}\n" "$(basename "$f")" "$size"
        GENERATED=$((GENERATED + 1))
        TOTAL_SIZE=$((TOTAL_SIZE + size))
    else
        printf "  ${RED}✗${NC} %-30s ${DIM}missing${NC}\n" "$(basename "$f")"
    fi
done

echo ""
echo -e "  ${BOLD}Total:${NC} $GENERATED/6 files ($TOTAL_SIZE bytes)"
echo ""

if [ "$GENERATED" -eq 6 ]; then
    echo -e "${GREEN}${BOLD}✅ Generated successfully!${NC}"
    echo ""
    echo -e "${DIM}💡 Tip: update manifest.json to add PNG as fallback:${NC}"
    echo -e "${DIM}   { \"src\": \"/icon-192.png\", \"sizes\": \"192x192\", \"type\": \"image/png\" }${NC}"
    echo ""
    exit 0
else
    echo -e "${YELLOW}${BOLD}⚠  Some files were not generated${NC}"
    echo ""
    exit 1
fi