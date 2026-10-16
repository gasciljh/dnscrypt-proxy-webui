#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — boot-mini.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-15
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Layer 0 primitives. Sourced by functions.sh before any
# Layer-1 code runs.
#
# Public interface:
#   log_msg <message>
#   get_run_dir
#   read_conf <file> <key> <default>
#   is_port_open <port> [tcp|udp]
#   get_webui_port [conf_file]
#
# Public constant:
#   _MONITORING_UI_PORT — reserved monitoring_ui port (8080).
#     Single source of truth on the shell side. Must stay in
#     sync with MONITORING_UI_PORT in main.go. No caller script
#     may redefine it.
#
# Environment (all optional):
#   MODDIR      — module root (auto-detected from $0 when unset).
#   LOG_FILE    — defaults to /data/local/tmp/dnscrypt_main.log.
#   LOG_PREFIX  — defaults to [module].
#
# Design rules:
#   • No sourcing of any other file.
#   • No dependencies beyond busybox / toybox commands.
#   • No firewall, backup, rotation, TOML parsing, or JSON —
#     those live in Layer 1 (functions.sh).
# ============================================================

# Guard against double-sourcing.
if [ -n "${_BOOT_MINI_LOADED:-}" ]; then
    # shellcheck disable=SC2317  # return-or-exit idiom
    return 0 2>/dev/null || exit 0
fi
_BOOT_MINI_LOADED=1

# ============================================================
# [0] Environment setup
# ============================================================
# Standard Android binary paths. Set here so every Layer-1 file
# and caller script inherits the same PATH — this file is the
# single source of truth for the shell-side environment.
#
# Runs AFTER the double-sourcing guard so a second
# `. boot-mini.sh` does not duplicate the prefix in $PATH.
export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module root resolution
# ============================================================
# Resolution order:
#   1. Caller-supplied MODDIR (the normal path).
#   2. $0-derived path (source tree or post-install layout).
#   3. Canonical install path (last resort).
#
# $0-derived cases:
#   Source tree      $MODDIR/proxy/boot-mini.sh → strip /proxy
#   Post-install     $MODDIR/boot-mini.sh       → use as-is
#   Shell-invoked    $0 = "/system/bin/sh" etc. → canonical path
#   Bare name        $0 = "boot-mini.sh"        → canonical path
#
# The shell-path detection is deliberate: `sh -c "..."` sets $0
# to the shell's own path, and a naive `/*) use as-is` would
# produce MODDIR="/system/bin". Falling through to the canonical
# path keeps the failure recoverable.
if [ -z "${MODDIR:-}" ]; then
    _bm_dir="${0%/*}"
    case "$_bm_dir" in
        /*/proxy)
            MODDIR="${_bm_dir%/proxy}"
            ;;
        /system/*|/vendor/*|/sbin/*|/bin/*|/usr/*)
            MODDIR="/data/adb/modules/dnscrypt-proxy-webui"
            ;;
        /*)
            MODDIR="$_bm_dir"
            ;;
        *)
            MODDIR="/data/adb/modules/dnscrypt-proxy-webui"
            ;;
    esac
    unset _bm_dir
fi

# ============================================================
# [2] Constants
# ============================================================
LOG_FILE="${LOG_FILE:-/data/local/tmp/dnscrypt_main.log}"
LOG_PREFIX="${LOG_PREFIX:-[module]}"

# Reserved port for dnscrypt-proxy's monitoring_ui. Rejected by
# every Port Guard in the tree (main.go, customize.sh, action.sh,
# status.sh, service.sh, uninstall.sh) and by get_webui_port
# below.
_MONITORING_UI_PORT="8080"

# ============================================================
# [3] log_msg — timestamped append with emergency rotation
# ============================================================
# main.go owns orderly 1 MB rotation. This helper rotates only
# at 50 MB, and only every 100th call, to keep the overhead
# negligible on the hot path.
#
# When LOG_FILE and its parent directory are both unwritable,
# the message is emitted on stderr. On Android, stderr from a
# Magisk / KernelSU script reaches logcat — no diagnostic is
# silently lost.
_LOG_CALL_COUNT=0

log_msg() {
    _LOG_CALL_COUNT=$((_LOG_CALL_COUNT + 1))

    if [ $((_LOG_CALL_COUNT % 100)) -eq 0 ] && [ -f "$LOG_FILE" ]; then
        local _size
        _size=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
        if [ -n "$_size" ] && [ "$_size" -gt 52428800 ]; then
            mv -f "$LOG_FILE" "${LOG_FILE}.emergency.$(date +%s)" 2>/dev/null
            : > "$LOG_FILE" 2>/dev/null
        fi
    fi

    local _msg
    _msg="$(date +'%Y-%m-%d %H:%M:%S') - $LOG_PREFIX $1"

    if [ -w "$LOG_FILE" ] 2>/dev/null \
       || [ -w "$(dirname "$LOG_FILE")" ] 2>/dev/null; then
        printf '%s\n' "$_msg" >> "$LOG_FILE" 2>/dev/null && return 0
    fi

    printf '%s\n' "$_msg" >&2
}

# ============================================================
# [4] get_run_dir — $MODDIR/proxy/run, or /data/local/tmp
# ============================================================
# Prefers $MODDIR/proxy/run. Creates it with mode 0700 on first
# use. Falls back to /data/local/tmp only when the module-side
# directory is unavailable.
#
# Live write test: `[ -w "$rd" ]` only checks the permission
# bit. On Android with SELinux, a directory can appear writable
# but reject writes (e.g. wrong context, read-only mount). This
# helper therefore confirms real write-ability with a small
# test file — matching main.go:isRunDirUsable(), which uses
# os.WriteFile for the same reason.
#
# The test file is created with mode 0600 and removed
# immediately. If either write or remove fails, the module-side
# path is considered unusable and /data/local/tmp is returned.
get_run_dir() {
    local rd="$MODDIR/proxy/run"
    local test_file="$rd/.write_test"

    # Create the module-side directory if missing. Failure here
    # is not fatal — we fall through to the fallback path.
    if [ ! -d "$rd" ]; then
        mkdir -p "$rd" 2>/dev/null || {
            printf '%s' "/data/local/tmp"
            return 0
        }
        chmod 0700 "$rd" 2>/dev/null
        chown 0:0 "$rd" 2>/dev/null
    fi

    # Live write test — mirrors main.go:isRunDirUsable().
    if echo "ok" > "$test_file" 2>/dev/null; then
        rm -f "$test_file" 2>/dev/null
        printf '%s' "$rd"
        return 0
    fi

    # Write test failed (SELinux context, read-only FS, full
    # partition, …). Fall back to /data/local/tmp.
    printf '%s' "/data/local/tmp"
}

# ============================================================
# [5] read_conf — key=value from shell-style config
# ============================================================
# Trailing " #comment" is stripped. Whitespace is trimmed.
# Values containing '=' are preserved via `cut -d= -f2-`.
#
# Return convention:
#   0 = value present (stdout = value)
#   1 = value missing OR file absent (stdout = default)
read_conf() {
    local conf="$1" key="$2" default="$3"

    if [ -f "$conf" ]; then
        local val
        val=$(grep "^${key}=" "$conf" 2>/dev/null \
              | head -n 1 \
              | cut -d= -f2- \
              | tr -d '\r')

        case "$val" in
            *" #"*) val="${val%% #*}" ;;
        esac

        val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ -n "$val" ]; then
            printf '%s' "$val"
            return 0
        fi
    fi

    printf '%s' "$default"
    return 1
}

# ============================================================
# [6] is_port_open — /proc → ss → netstat
# ============================================================
# /proc/net is preferred: always present, zero forks.
#
# The trailing space in ":$hex_port " is required — without it,
# ":1F90" would also match ":1F90A" (a longer port whose prefix
# happens to equal ours).
is_port_open() {
    local port="$1"
    local proto="${2:-tcp}"
    local hex_port

    case "$port" in
        ''|*[!0-9]*) return 1 ;;
    esac

    hex_port=$(printf "%04X" "$port" 2>/dev/null) || return 1

    if [ "$proto" = "udp" ]; then
        [ -f /proc/net/udp ] \
            && grep -qi ":$hex_port " /proc/net/udp 2>/dev/null && return 0
        [ -f /proc/net/udp6 ] \
            && grep -qi ":$hex_port " /proc/net/udp6 2>/dev/null && return 0
        if command -v ss >/dev/null 2>&1; then
            ss -lun 2>/dev/null | grep -q ":$port " && return 0
        elif command -v netstat >/dev/null 2>&1; then
            netstat -uln 2>/dev/null | grep -q ":$port " && return 0
        fi
    else
        [ -f /proc/net/tcp ] \
            && grep -qi ":$hex_port " /proc/net/tcp 2>/dev/null && return 0
        [ -f /proc/net/tcp6 ] \
            && grep -qi ":$hex_port " /proc/net/tcp6 2>/dev/null && return 0
        if command -v ss >/dev/null 2>&1; then
            ss -ltn 2>/dev/null | grep -q ":$port " && return 0
        elif command -v netstat >/dev/null 2>&1; then
            netstat -tln 2>/dev/null | grep -q ":$port " && return 0
        fi
    fi

    return 1
}

# ============================================================
# [7] get_webui_port — Port Guard (rejects 8080)
# ============================================================
# Leading zeros are stripped before the range check: some shells
# interpret "090" as octal 72 in arithmetic contexts, which
# would pass a bogus port to the socket layer.
#
# Port Guard: 8080 is rejected (reserved for monitoring_ui) and
# the function falls back to the default.
get_webui_port() {
    local conf="${1:-$MODDIR/proxy/webui.conf}"
    local port clean

    port=$(read_conf "$conf" "PORT" "9090" 2>/dev/null)
    case "$port" in
        ''|*[!0-9]*) port="9090" ;;
    esac

    clean=$(printf '%s' "$port" | sed 's/^0*//')
    [ -z "$clean" ] && clean="0"

    if [ "$clean" -ge 1 ] \
       && [ "$clean" -le 65535 ] \
       && [ "$clean" != "$_MONITORING_UI_PORT" ]; then
        printf '%s' "$clean"
    else
        printf '9090'
    fi
}
