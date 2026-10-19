#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – generate-icons.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-18
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Generate PNG and ICO icons from the SVG sources in web/.
#
# Source → Output mapping:
#   icon-192.svg   →  icon-192.png         (192×192)
#   icon-512.svg   →  icon-512.png         (512×512)
#   icon-512.svg   →  apple-touch-icon.png (180×180)
#   icon-512.svg   →  favicon-32x32.png    (32×32)
#   icon-512.svg   →  favicon-16x16.png    (16×16)
#   favicon-16x16.png + favicon-32x32.png → favicon.ico
#
# Tools (auto-detected, priority order):
#   rsvg-convert → magick → convert → inkscape
#
# ICO generation (cascade):
#   ImageMagick → icotool → copy of favicon-32x32.png
#
# Modes:
#   generate-icons.sh             Generate all (skip existing)
#   generate-icons.sh --force     Regenerate all (overwrite)
#   generate-icons.sh --check     Verify existing files only
#   generate-icons.sh --verbose   Show tool stderr
#   generate-icons.sh --help      Show this help
#
# Atomic writes:
#   Every output file is written to a PID-suffixed `.tmp.$$`
#   sibling first, then renamed into place only on success.
#   A trap on EXIT/INT/TERM removes any leftover temp files.
#   This guarantees that a partial or interrupted conversion
#   can never leave a truncated PNG/ICO on disk that a
#   subsequent --check or build would mistake for a valid
#   file.
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
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

# ============================================================
# [3] Logging
# ============================================================
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
  --verbose, -v    Verbose output (tool stderr)
  --check          Only check that the required files exist
  --force, -f      Regenerate even if the files exist
  --help, -h       Show this help

Required tools (at least one):
  • rsvg-convert   (Ubuntu: apt install librsvg2-bin)
  • magick         (ImageMagick 7)
  • convert        (ImageMagick 6)
  • inkscape       (Inkscape CLI)

Source → Output mapping:
  icon-192.svg   →  icon-192.png         (192×192)
  icon-512.svg   →  icon-512.png         (512×512)
  icon-512.svg   →  apple-touch-icon.png (180×180)
  icon-512.svg   →  favicon-32x32.png    (32×32)
  icon-512.svg   →  favicon-16x16.png    (16×16)
  favicon-16x16.png + favicon-32x32.png → favicon.ico

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
# [5] Cleanup infrastructure
# ============================================================
# Every output file is written to a PID-suffixed temp sibling
# first. Two independent protections against partial files:
#
#   1. _run_conversion / _run_ico rename the temp into place
#      ONLY after confirming the tool exited 0 AND the temp
#      file is non-empty. On failure, the temp is deleted
#      immediately.
#
#   2. _cleanup_temps, bound to EXIT / INT / TERM below,
#      removes any leftover temp files if the script is
#      interrupted between the tool call and the rename. The
#      _CLEANED_UP flag makes the handler idempotent — POSIX
#      requires EXIT to fire on every exit path, including
#      after INT/TERM.
_TEMP_FILES=""
_CLEANED_UP=0

_cleanup_temps() {
    [ "$_CLEANED_UP" = "1" ] && return 0
    _CLEANED_UP=1

    [ -z "$_TEMP_FILES" ] && return 0

    local _t
    for _t in $_TEMP_FILES; do
        [ -f "$_t" ] && rm -f "$_t" 2>/dev/null
    done

    return 0
}

# shellcheck disable=SC2329  # invoked via trap below
trap '_cleanup_temps' EXIT
trap '_cleanup_temps; exit 130' INT
trap '_cleanup_temps; exit 143' TERM

# _track_temp <path>
#   Register a temp path for cleanup. Called immediately after
#   mktemp-equivalent (we use a deterministic PID-suffixed name
#   rather than mktemp for readability in the build tree).
_track_temp() {
    _TEMP_FILES="$_TEMP_FILES $1"
}

# _untrack_temp <path>
#   Remove a temp path from the tracking list. Called after a
#   successful rename (the temp no longer exists) or after an
#   explicit removal (same).
_untrack_temp() {
    local _target="$1"
    local _new=""
    local _t

    for _t in $_TEMP_FILES; do
        [ "$_t" = "$_target" ] && continue
        _new="$_new $_t"
    done

    _TEMP_FILES="$_new"
}

# ============================================================
# [6] Helpers
# ============================================================
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

# ============================================================
# [7] Tool detection
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
fi

# ============================================================
# [8] Header
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  DNSCrypt Smart Filter – Icon Generator                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# [9] Check-only mode
# ============================================================
# Uses `-s` (non-empty) — a zero-byte file from a failed
# checkout is reported as missing.
if [ "$CHECK_ONLY" = "1" ]; then
    echo -e "${BOLD}File check:${NC}"
    echo ""

    MISSING=0

    for f in "$PNG_192" "$PNG_512" "$APPLE_TOUCH" "$FAVICON_32" "$FAVICON_16" "$FAVICON_ICO"; do
        if [ -s "$f" ]; then
            _sz=$(file_size "$f" || echo "?")
            printf "  ${GREEN}✓${NC} %-30s ${DIM}(%s bytes)${NC}\n" "$(basename "$f")" "$_sz"
        else
            if [ -f "$f" ]; then
                printf "  ${RED}✗${NC} %-30s ${DIM}(empty)${NC}\n" "$(basename "$f")"
            else
                printf "  ${RED}✗${NC} %-30s ${DIM}(missing)${NC}\n" "$(basename "$f")"
            fi
            MISSING=$((MISSING + 1))
        fi
    done

    echo ""
    if [ "$MISSING" -eq 0 ]; then
        echo -e "${GREEN}✅ All files present and non-empty${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠  $MISSING file(s) missing or empty${NC}"
        echo -e "${DIM}   Run: ./scripts/generate-icons.sh${NC}"
        exit 1
    fi
fi

# ============================================================
# [10] Verify tools + inputs
# ============================================================
if [ -z "$ICON_TOOL" ]; then
    log_error "No SVG → PNG conversion tool found"
    echo ""
    echo -e "${BOLD}Install one of:${NC}"
    echo "  ${DIM}Ubuntu/Debian:${NC}"
    echo "    sudo apt install librsvg2-bin    # recommended (fastest)"
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

if [ ! -s "$SVG_192" ]; then
    log_error "Missing or empty: $SVG_192"
    exit 1
fi

if [ ! -s "$SVG_512" ]; then
    log_error "Missing or empty: $SVG_512"
    exit 1
fi

log_ok "Input files present"

# ============================================================
# [11] SVG → PNG conversion (atomic)
# ============================================================
# When --verbose is set, the tool's stderr is inherited. When
# not, it is redirected to /dev/null. A literal `/dev/stderr`
# redirect was rejected — that path is a convenience symlink
# not guaranteed on minimal containers.
#
# Output discipline:
#   1. Convert to `<output>.tmp.$$` (registered with _track_temp).
#   2. Verify the temp file is non-empty AND the tool exited 0.
#   3. Rename temp → final output (atomic on the same fs).
#   4. Untrack the temp (it no longer exists as a separate file).
#
# On any failure:
#   • The temp file is removed immediately.
#   • The final output is left untouched (previous valid copy
#     survives an interrupted regeneration).
convert_svg_to_png() {
    local svg="$1"
    local width="$2"
    local height="$3"
    local output="$4"

    local tmp="${output}.tmp.$$"
    _track_temp "$tmp"
    rm -f "$tmp" 2>/dev/null

    local tool_rc=0

    case "$ICON_TOOL_CMD" in
        rsvg-convert)
            if [ "$VERBOSE" = "1" ]; then
                rsvg-convert \
                    --width="$width" \
                    --height="$height" \
                    --keep-aspect-ratio \
                    --background-color=none \
                    --output="$tmp" \
                    "$svg" || tool_rc=$?
            else
                rsvg-convert \
                    --width="$width" \
                    --height="$height" \
                    --keep-aspect-ratio \
                    --background-color=none \
                    --output="$tmp" \
                    "$svg" 2>/dev/null || tool_rc=$?
            fi
            ;;
        magick)
            if [ "$VERBOSE" = "1" ]; then
                magick -background none -density 384 \
                    "$svg" -resize "${width}x${height}" \
                    "$tmp" || tool_rc=$?
            else
                magick -background none -density 384 \
                    "$svg" -resize "${width}x${height}" \
                    "$tmp" 2>/dev/null || tool_rc=$?
            fi
            ;;
        convert)
            if [ "$VERBOSE" = "1" ]; then
                convert -background none -density 384 \
                    "$svg" -resize "${width}x${height}" \
                    "$tmp" || tool_rc=$?
            else
                convert -background none -density 384 \
                    "$svg" -resize "${width}x${height}" \
                    "$tmp" 2>/dev/null || tool_rc=$?
            fi
            ;;
        inkscape)
            if [ "$VERBOSE" = "1" ]; then
                inkscape \
                    --export-type=png \
                    --export-filename="$tmp" \
                    --export-width="$width" \
                    --export-height="$height" \
                    "$svg" || tool_rc=$?
            else
                inkscape \
                    --export-type=png \
                    --export-filename="$tmp" \
                    --export-width="$width" \
                    --export-height="$height" \
                    "$svg" 2>/dev/null || tool_rc=$?
            fi
            ;;
    esac

    # Verify: tool exited 0 AND temp is non-empty.
    if [ "$tool_rc" -ne 0 ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp" 2>/dev/null
        _untrack_temp "$tmp"
        log_error "Failed to generate: $(basename "$output")"
        log_info "Tool: $ICON_TOOL  Input: $(basename "$svg")  ${width}×${height}"
        if [ "$tool_rc" -ne 0 ]; then
            log_info "Tool exit code: $tool_rc"
        else
            log_info "Tool produced an empty file"
        fi
        [ "$VERBOSE" != "1" ] && log_info "Re-run with --verbose to see the tool's stderr"
        return 1
    fi

    # Atomic promote: temp → final output.
    if ! mv -f "$tmp" "$output" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        _untrack_temp "$tmp"
        log_error "Failed to install: $(basename "$output") (mv failed)"
        return 1
    fi
    _untrack_temp "$tmp"

    local sz
    sz=$(file_size "$output" || echo "?")
    log_ok "$(basename "$output") (${width}×${height}, ${sz} bytes)"
    return 0
}

# ============================================================
# [12] ICO generation (atomic)
# ============================================================
# Three fallback methods, same atomic discipline as
# convert_svg_to_png:
#   1. ImageMagick — best multi-size ICO.
#   2. icotool     — packed from the two favicon PNGs.
#   3. PNG-as-ICO  — crude copy of favicon-32x32.png (last
#                    resort; most modern browsers accept it).
generate_ico() {
    local output="$1"

    local tmp="${output}.tmp.$$"
    _track_temp "$tmp"
    rm -f "$tmp" 2>/dev/null

    # --- Method 1: ImageMagick directly (best multi-size ICO) ---
    if [ "$ICON_TOOL_CMD" = "magick" ] || [ "$ICON_TOOL_CMD" = "convert" ]; then
        local im_rc=0
        if [ "$VERBOSE" = "1" ]; then
            "$ICON_TOOL_CMD" \
                "$FAVICON_16" \
                "$FAVICON_32" \
                -colors 256 \
                "$tmp" || im_rc=$?
        else
            "$ICON_TOOL_CMD" \
                "$FAVICON_16" \
                "$FAVICON_32" \
                -colors 256 \
                "$tmp" 2>/dev/null || im_rc=$?
        fi

        if [ "$im_rc" -eq 0 ] && [ -s "$tmp" ]; then
            if mv -f "$tmp" "$output" 2>/dev/null; then
                _untrack_temp "$tmp"
                local sz; sz=$(file_size "$output" || echo "?")
                log_ok "$(basename "$output") (multi-size, ${sz} bytes)"
                return 0
            fi
        fi
        rm -f "$tmp" 2>/dev/null
    fi

    # --- Method 2: icotool from existing PNGs ---
    if [ -s "$FAVICON_32" ] && command -v icotool >/dev/null 2>&1; then
        local ico_rc=0
        if [ "$VERBOSE" = "1" ]; then
            icotool -c -o "$tmp" "$FAVICON_16" "$FAVICON_32" || ico_rc=$?
        else
            icotool -c -o "$tmp" "$FAVICON_16" "$FAVICON_32" 2>/dev/null || ico_rc=$?
        fi

        if [ "$ico_rc" -eq 0 ] && [ -s "$tmp" ]; then
            if mv -f "$tmp" "$output" 2>/dev/null; then
                _untrack_temp "$tmp"
                local sz; sz=$(file_size "$output" || echo "?")
                log_ok "$(basename "$output") (icotool, ${sz} bytes)"
                return 0
            fi
        fi
        rm -f "$tmp" 2>/dev/null
    fi

    # --- Method 3: crude copy of favicon-32x32 ---
    # The file is named .ico but contains PNG data. Most modern
    # browsers accept this; it is not a valid ICO container.
    if [ -s "$FAVICON_32" ]; then
        if cp "$FAVICON_32" "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            if mv -f "$tmp" "$output" 2>/dev/null; then
                _untrack_temp "$tmp"
                log_warn "$(basename "$output") (PNG-as-ICO fallback; some browsers may reject it)"
                return 0
            fi
        fi
        rm -f "$tmp" 2>/dev/null
    fi

    _untrack_temp "$tmp"
    log_error "Failed to generate: $(basename "$output")"
    return 1
}

# ============================================================
# [13] Generation
# ============================================================
# Order matters:
#   1. icon-192.svg → icon-192.png
#   2. icon-512.svg → icon-512.png
#   3. icon-512.svg → apple-touch-icon.png
#   4. icon-512.svg → favicon-32x32.png
#   5. icon-512.svg → favicon-16x16.png
#   6. favicon-16/32 → favicon.ico      (depends on 4 and 5)
#
# Two counters:
#   FRESH_COUNT   — files actually converted this run
#   SKIPPED_COUNT — files that pre-existed and were reused
echo ""
echo -e "${BOLD}Generating...${NC}"
echo ""

FRESH_COUNT=0
SKIPPED_COUNT=0

_run_conversion() {
    local svg="$1"
    local width="$2"
    local height="$3"
    local output="$4"

    if [ -s "$output" ] && [ "$FORCE" = "0" ]; then
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        log_debug "Exists: $(basename "$output")"
        return 0
    fi

    if convert_svg_to_png "$svg" "$width" "$height" "$output"; then
        FRESH_COUNT=$((FRESH_COUNT + 1))
    else
        return 1
    fi
}

_run_ico() {
    local output="$1"

    if [ -s "$output" ] && [ "$FORCE" = "0" ]; then
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        log_debug "Exists: $(basename "$output")"
        return 0
    fi

    if generate_ico "$output"; then
        FRESH_COUNT=$((FRESH_COUNT + 1))
    else
        return 1
    fi
}

_run_conversion "$SVG_192" 192 192 "$PNG_192"
_run_conversion "$SVG_512" 512 512 "$PNG_512"
_run_conversion "$SVG_512" 180 180 "$APPLE_TOUCH"
_run_conversion "$SVG_512" 32  32  "$FAVICON_32"
_run_conversion "$SVG_512" 16  16  "$FAVICON_16"
_run_ico "$FAVICON_ICO"

if [ "$SKIPPED_COUNT" -gt 0 ] && [ "$FORCE" = "0" ]; then
    echo ""
    log_info "$SKIPPED_COUNT file(s) already existed and were skipped (use --force to regenerate)"
fi

# ============================================================
# [14] Summary
# ============================================================
echo ""
echo -e "${BOLD}━━━ Summary ━━━${NC}"
echo ""

EXISTING=0
TOTAL_SIZE=0

for f in "$PNG_192" "$PNG_512" "$APPLE_TOUCH" "$FAVICON_32" "$FAVICON_16" "$FAVICON_ICO"; do
    if [ -s "$f" ]; then
        size=$(file_size "$f" || echo "")
        if ! is_numeric "$size"; then
            size=0
        fi
        printf "  ${GREEN}✓${NC} %-30s ${DIM}%s bytes${NC}\n" "$(basename "$f")" "$size"
        EXISTING=$((EXISTING + 1))
        TOTAL_SIZE=$((TOTAL_SIZE + size))
    else
        printf "  ${RED}✗${NC} %-30s ${DIM}missing or empty${NC}\n" "$(basename "$f")"
    fi
done

echo ""
echo -e "  ${BOLD}Total:${NC} $EXISTING/6 files ($TOTAL_SIZE bytes)"

if [ "$EXISTING" -eq 6 ]; then
    if [ "$SKIPPED_COUNT" -gt 0 ] && [ "$FRESH_COUNT" -gt 0 ]; then
        echo -e "  ${DIM}($FRESH_COUNT regenerated, $SKIPPED_COUNT reused)${NC}"
    elif [ "$SKIPPED_COUNT" -eq 6 ]; then
        echo -e "  ${DIM}(all files reused — use --force to regenerate)${NC}"
    fi
fi

echo ""

if [ "$EXISTING" -eq 6 ]; then
    echo -e "${GREEN}${BOLD}✅ All icons ready${NC}"
    echo ""
    exit 0
else
    echo -e "${YELLOW}${BOLD}⚠  Some files were not generated${NC}"
    echo ""
    exit 1
fi