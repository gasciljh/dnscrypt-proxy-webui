#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — boot-mini.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Layer 0 aggregator. Loads lib/ in dependency order and
# exposes a stable public API regardless of which lib/ files
# are available.
#
# Public API:
#   log_msg                  <msg>
#   is_port_open             <port> [tcp|udp]
#   read_conf                <file> <key> <default>
#   get_webui_port           [conf]
#   get_dashboard_port       [conf]
#   get_run_dir              (uses $MODDIR)
#   is_ipv6_available
#   get_profile_memory_hint
# ============================================================

if [ -n "${_BOOT_MINI_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_BOOT_MINI_LOADED=1

# ============================================================
# [1] Environment
# ============================================================
export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

_bm_caller_log="${LOG_FILE:-}"
_bm_caller_prefix="${LOG_PREFIX:-}"

LOG_FILE="${LOG_FILE:-/data/local/tmp/dnscrypt_main.log}"
LOG_PREFIX="${LOG_PREFIX:-[module]}"

# ============================================================
# [2] Module root resolution
# ============================================================
if [ -z "${MODDIR:-}" ]; then
    _bm_dir="${0%/*}"
    case "$_bm_dir" in
        /*/proxy) MODDIR="${_bm_dir%/proxy}" ;;
        /system/*|/vendor/*|/sbin/*|/bin/*|/usr/*)
            MODDIR="/data/adb/modules/dnscrypt-proxy-webui" ;;
        /*) MODDIR="$_bm_dir" ;;
        *) MODDIR="/data/adb/modules/dnscrypt-proxy-webui" ;;
    esac
    unset _bm_dir
fi

# ============================================================
# [3] log_msg — 50 MB emergency rotation every 100 calls
# ============================================================
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
# [4] Locate and load lib/
# ============================================================
_LIB_BASE=""
for _cand in "$MODDIR/lib" "$MODDIR/proxy/lib"; do
    if [ -d "$_cand" ]; then
        _LIB_BASE="$_cand"
        break
    fi
done

if [ -z "$_LIB_BASE" ]; then
    log_msg "WARNING: lib/ directory not found — inline fallbacks only"
fi

# lib/constants.sh — shared constants (may override LOG_FILE)
if [ -n "$_LIB_BASE" ] && [ -f "$_LIB_BASE/constants.sh" ]; then
    . "$_LIB_BASE/constants.sh"
fi

# Restore caller-supplied overrides
[ -n "$_bm_caller_log" ] && LOG_FILE="$_bm_caller_log"
[ -n "$_bm_caller_prefix" ] && LOG_PREFIX="$_bm_caller_prefix"
unset _bm_caller_log _bm_caller_prefix

# Ensure essential constants exist even if constants.sh failed
_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"
DEFAULT_WEBUI_PORT="${DEFAULT_WEBUI_PORT:-9090}"
DEFAULT_DASHBOARD_PORT="${DEFAULT_DASHBOARD_PORT:-9091}"

# lib/fallbacks.sh — standalone primitives
if [ -n "$_LIB_BASE" ] && [ -f "$_LIB_BASE/fallbacks.sh" ]; then
    . "$_LIB_BASE/fallbacks.sh"
fi

# ============================================================
# [5] Public API — wrappers over lib/fallbacks.sh
# ============================================================
if command -v _fb_is_port_open >/dev/null 2>&1; then
    is_port_open()            { _fb_is_port_open "$@"; }
    read_conf()               { _fb_read_conf "$@"; }
    get_webui_port()          { _fb_get_webui_port "$@"; }
    get_dashboard_port()      { _fb_get_dashboard_port "$@"; }
    get_run_dir()             { _fb_get_run_dir "$MODDIR"; }
    is_ipv6_available()       { _fb_is_ipv6_available; }
    get_profile_memory_hint() { _fb_get_profile_memory_hint; }
else
    log_msg "WARNING: lib/fallbacks.sh not loaded — using inline primitives"

    is_port_open() {
        local port="$1" proto="${2:-tcp}" hex
        case "$port" in ''|*[!0-9]*) return 1 ;; esac
        hex=$(printf "%04X" "$port" 2>/dev/null) || return 1
        if [ "$proto" = "udp" ]; then
            [ -f /proc/net/udp ]  && grep -qi ":$hex " /proc/net/udp  2>/dev/null && return 0
            [ -f /proc/net/udp6 ] && grep -qi ":$hex " /proc/net/udp6 2>/dev/null && return 0
        else
            [ -f /proc/net/tcp ]  && grep -qi ":$hex " /proc/net/tcp  2>/dev/null && return 0
            [ -f /proc/net/tcp6 ] && grep -qi ":$hex " /proc/net/tcp6 2>/dev/null && return 0
        fi
        return 1
    }

    read_conf() {
        local conf="$1" key="$2" default="$3" val
        if [ -f "$conf" ]; then
            val=$(grep "^${key}=" "$conf" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r')
            case "$val" in *" #"*) val="${val%% #*}" ;; esac
            val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "$val" ] && { printf '%s' "$val"; return 0; }
        fi
        printf '%s' "$default"
        return 1
    }

    get_webui_port() {
        local conf="${1:-$MODDIR/proxy/webui.conf}" port clean
        port=$(read_conf "$conf" "PORT" "$DEFAULT_WEBUI_PORT" 2>/dev/null)
        case "$port" in ''|*[!0-9]*) port="$DEFAULT_WEBUI_PORT" ;; esac
        clean=$(printf '%s' "$port" | sed 's/^0*//')
        [ -z "$clean" ] && clean="0"
        if [ "$clean" -ge 1 ] && [ "$clean" -le 65535 ] \
           && [ "$clean" != "$_MONITORING_UI_PORT" ]; then
            printf '%s' "$clean"
        else
            printf '%s' "$DEFAULT_WEBUI_PORT"
        fi
    }

    get_dashboard_port() {
        local conf="${1:-$MODDIR/proxy/webui.conf}" port clean
        port=$(read_conf "$conf" "DASHBOARD_PORT" "$DEFAULT_DASHBOARD_PORT" 2>/dev/null)
        case "$port" in ''|*[!0-9]*) port="$DEFAULT_DASHBOARD_PORT" ;; esac
        clean=$(printf '%s' "$port" | sed 's/^0*//')
        [ -z "$clean" ] && clean="0"
        if [ "$clean" -ge 1 ] && [ "$clean" -le 65535 ] \
           && [ "$clean" != "$_MONITORING_UI_PORT" ]; then
            printf '%s' "$clean"
        else
            printf '%s' "$DEFAULT_DASHBOARD_PORT"
        fi
    }

    get_run_dir() {
        local rd="$MODDIR/proxy/run" tf
        [ -d "$rd" ] || mkdir -p "$rd" 2>/dev/null \
            || { printf '/data/local/tmp'; return 0; }
        chmod 0700 "$rd" 2>/dev/null
        tf="$rd/.write_test.$$"
        if echo "ok" > "$tf" 2>/dev/null; then
            rm -f "$tf" 2>/dev/null
            printf '%s' "$rd"
            return 0
        fi
        rm -f "$tf" 2>/dev/null
        printf '/data/local/tmp'
    }

    is_ipv6_available() {
        [ -f /proc/net/if_inet6 ] || return 1
        local n
        n=$(wc -l < /proc/net/if_inet6 2>/dev/null | tr -d ' ')
        case "$n" in ''|*[!0-9]*) return 1 ;; esac
        [ "$n" -gt 0 ]
    }

    get_profile_memory_hint() {
        local pf="$MODDIR/proxy/selected_profile.txt" p="pro" mb
        if [ -f "$pf" ]; then
            p=$(cat "$pf" 2>/dev/null | tr -d '\r\n ')
            case "$p" in light|normal|pro|proplus|ultimate) ;; *) p="pro" ;; esac
        fi
        case "$p" in
            light)    mb="80"  ;;
            normal)   mb="100" ;;
            pro)      mb="120" ;;
            proplus)  mb="160" ;;
            ultimate) mb="220" ;;
            *)        mb="80"  ;;
        esac
        printf '%s MB (%s)' "$mb" "$p"
    }
fi

# ============================================================
# [6] Load remaining lib/ modules
# ============================================================
# Order matters: process.sh's wait_port_free uses is_port_open
# (already defined above).
for _mod in process http backup firewall; do
    if [ -n "$_LIB_BASE" ] && [ -f "$_LIB_BASE/$_mod.sh" ]; then
        . "$_LIB_BASE/$_mod.sh"
    fi
done
unset _LIB_BASE _mod