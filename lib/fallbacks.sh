#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — lib/fallbacks.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Absolute-minimum primitives usable before any other lib/ file
# is available. Sourced by boot-mini.sh unconditionally, and
# by post-fs-data.sh directly (it runs before /data mounts).
#
# Rules:
#   • No sourcing of any file.
#   • No dependency on lib/constants.sh, lib/process.sh, or
#     functions.sh.
#   • Only /proc reads + cat/grep/sed/tr/cut/printf. No
#     pgrep, ps, ss, netstat, nft, iptables, or awk.
#
# Public interface (all prefixed _fb_):
#   _fb_log_stderr           <msg>
#   _fb_is_port_open         <port> [proto]
#   _fb_read_conf            <file> <key> <default>
#   _fb_get_webui_port       [conf]
#   _fb_get_dashboard_port   [conf]
#   _fb_get_run_dir          <moddir>
#   _fb_is_ipv6_available
#   _fb_pid_is_alive         <pid>
#   _fb_get_profile_memory_hint [profile_file]
# ============================================================

if [ -n "${_LIB_FALLBACKS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_LIB_FALLBACKS_LOADED=1

# ============================================================
# [1] Logging
# ============================================================
_fb_log_stderr() {
    printf '%s\n' "$1" >&2
}

# ============================================================
# [2] Port check via /proc
# ============================================================
_fb_is_port_open() {
    local port="$1"
    local proto="${2:-tcp}"
    local hex_port

    case "$port" in
        ''|*[!0-9]*) return 1 ;;
    esac

    hex_port=$(printf "%04X" "$port" 2>/dev/null) || return 1
    [ -z "$hex_port" ] && return 1

    if [ "$proto" = "udp" ]; then
        [ -f /proc/net/udp ]  && grep -qi ":$hex_port " /proc/net/udp  2>/dev/null && return 0
        [ -f /proc/net/udp6 ] && grep -qi ":$hex_port " /proc/net/udp6 2>/dev/null && return 0
    else
        [ -f /proc/net/tcp ]  && grep -qi ":$hex_port " /proc/net/tcp  2>/dev/null && return 0
        [ -f /proc/net/tcp6 ] && grep -qi ":$hex_port " /proc/net/tcp6 2>/dev/null && return 0
    fi
    return 1
}

# ============================================================
# [3] Config reader
# ============================================================
_fb_read_conf() {
    local conf="$1"
    local key="$2"
    local default="$3"
    local val

    if [ -f "$conf" ]; then
        val=$(grep "^${key}=" "$conf" 2>/dev/null \
              | head -n1 \
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
# [4] Port guards
# ============================================================
_fb_get_webui_port() {
    local conf="${1:-${MODDIR:-/data/adb/modules/dnscrypt-proxy-webui}/proxy/webui.conf}"
    local reserved="${_MONITORING_UI_PORT:-8080}"
    local port clean

    port=$(_fb_read_conf "$conf" "PORT" "9090" 2>/dev/null)
    case "$port" in ''|*[!0-9]*) port="9090" ;; esac

    clean=$(printf '%s' "$port" | sed 's/^0*//')
    [ -z "$clean" ] && clean="0"

    if [ "$clean" -ge 1 ] && [ "$clean" -le 65535 ] && [ "$clean" != "$reserved" ]; then
        printf '%s' "$clean"
    else
        printf '9090'
    fi
}

_fb_get_dashboard_port() {
    local conf="${1:-${MODDIR:-/data/adb/modules/dnscrypt-proxy-webui}/proxy/webui.conf}"
    local reserved="${_MONITORING_UI_PORT:-8080}"
    local port clean

    port=$(_fb_read_conf "$conf" "DASHBOARD_PORT" "9091" 2>/dev/null)
    case "$port" in ''|*[!0-9]*) port="9091" ;; esac

    clean=$(printf '%s' "$port" | sed 's/^0*//')
    [ -z "$clean" ] && clean="0"

    if [ "$clean" -ge 1 ] && [ "$clean" -le 65535 ] && [ "$clean" != "$reserved" ]; then
        printf '%s' "$clean"
    else
        printf '9091'
    fi
}

# ============================================================
# [5] Run directory resolution
# ============================================================
# The chmod is applied unconditionally (not only when the
# directory is first created) so that any pre-existing run/
# with stale or inherited permissions is corrected on every
# call. This matters because run/ holds .watchdog_token and
# dnscrypt.status — both must stay 0700.
_fb_get_run_dir() {
    local moddir="$1"
    local rd test_file

    [ -z "$moddir" ] && { printf '/data/local/tmp'; return 0; }

    rd="$moddir/proxy/run"

    if [ ! -d "$rd" ]; then
        if ! mkdir -p "$rd" 2>/dev/null; then
            printf '/data/local/tmp'
            return 0
        fi
    fi
    chmod 0700 "$rd" 2>/dev/null

    test_file="$rd/.write_test.$$"
    if echo "ok" > "$test_file" 2>/dev/null; then
        rm -f "$test_file" 2>/dev/null
        printf '%s' "$rd"
        return 0
    fi

    rm -f "$test_file" 2>/dev/null
    printf '/data/local/tmp'
}

# ============================================================
# [6] IPv6 availability
# ============================================================
_fb_is_ipv6_available() {
    [ -f /proc/net/if_inet6 ] || return 1
    local count
    count=$(wc -l < /proc/net/if_inet6 2>/dev/null | tr -d ' ')
    case "$count" in ''|*[!0-9]*) return 1 ;; esac
    [ "$count" -gt 0 ]
}

# ============================================================
# [7] Process liveness
# ============================================================
_fb_pid_is_alive() {
    local pid="$1"
    local state

    [ -z "$pid" ] && return 1
    [ -d "/proc/$pid" ] || return 1

    state=$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null | awk '{print $1}')
    [ "$state" = "Z" ] && return 1
    return 0
}

# ============================================================
# [8] Profile memory hint
# ============================================================
_fb_get_profile_memory_hint() {
    local profile_file="${1:-${BIN_DIR:-/data/adb/modules/dnscrypt-proxy-webui/proxy}/selected_profile.txt}"
    local profile="pro"
    local mb

    if [ -f "$profile_file" ]; then
        local p
        p=$(cat "$profile_file" 2>/dev/null | tr -d '\r\n ')
        case "$p" in
            light|normal|pro|proplus|ultimate) profile="$p" ;;
        esac
    fi

    case "$profile" in
        light)    mb="80"  ;;
        normal)   mb="100" ;;
        pro)      mb="120" ;;
        proplus)  mb="160" ;;
        ultimate) mb="220" ;;
        *)        mb="80"  ;;
    esac

    printf '%s MB (%s)' "$mb" "$profile"
}