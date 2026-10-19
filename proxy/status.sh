#!/system/bin/sh
# shellcheck shell=ksh
# shellcheck disable=SC2059  # printf color codes are trusted constants
# ============================================================
# DNSCrypt Smart Filter — status.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-18
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Display the current status of the DNSCrypt Smart Filter
# module.
#
# Modes:
#   status.sh                Full display (default)
#   status.sh --short        Short display (OK / STOPPED / ...)
#   status.sh --json         JSON output
#   status.sh --check        Single-line core summary
#   status.sh --verbose      Extended display (adds ports +
#                            config file paths)
#   status.sh --diagnose     Full diagnostic report
#   status.sh --help         Show help
#   status.sh --version      Show version
#
# Exit codes:
#   0 = everything running
#   1 = nothing running
#   2 = partial (only one service running)
#   3 = module disabled
#
# Design:
#   • This is a DIAGNOSTIC tool. It MUST always produce a
#     report, even when functions.sh is unavailable or
#     corrupt — a broken module is precisely when the user
#     needs this tool most.
#   • Sources functions.sh when available for accurate data
#     (is_dnscrypt_running, is_webui_running, get_dashboard_port).
#   • Falls back to inline primitives when functions.sh fails.
#   • Version is read dynamically from module.prop (SSOT).
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path + version
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

get_module_version() {
    local vf="$MODDIR/module.prop"
    if [ -f "$vf" ]; then
        local v
        v=$(grep "^version=" "$vf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi
    printf 'v0.0.0-unknown'
}

MODULE_VERSION="$(get_module_version)"

case "${1:-}" in
    --version)
        echo "$0: $MODULE_VERSION"
        exit 0
        ;;
esac

# ============================================================
# [2] Default paths (reconfigured after loading functions.sh)
# ============================================================
STATUS_FILE="/data/local/tmp/dnscrypt.status"
PID_FILE="/data/local/tmp/dnscrypt.pid"
WEBUI_PID_FILE="/data/local/tmp/webui.pid"
WATCHDOG_PID_FILE="/data/local/tmp/watchdog.pid"

BIN_DIR="$MODDIR/proxy"
BLOCKLIST_FILE="$BIN_DIR/blocklist.txt"
RAW_BLOCKLIST_FILE="$BIN_DIR/blocklist.raw"
CONF_FILE="$BIN_DIR/webui.conf"
TOML_FILE="$BIN_DIR/dnscrypt-proxy.toml"
SELECTED_FILE="$BIN_DIR/selected_profile.txt"

# --- Data preservation paths ---
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"
LAST_AUTO_BACKUP_MARKER="$PERSISTENT_BACKUP/.last_auto_backup"
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# --- Recovery mode trigger files ---
RECOVERY_TRIGGER_1="$MODDIR/recovery"
RECOVERY_TRIGGER_2="/data/adb/dnscrypt-recovery"

# --- Reserved port (finalized after loading functions.sh) ---
_MONITORING_UI_PORT=""

# ============================================================
# [3] Parse command-line arguments
# ============================================================
# Primary modes are mutually exclusive; --verbose is a modifier only.
SHORT_MODE=0
JSON_MODE=0
CHECK_MODE=0
VERBOSE_MODE=0
DIAGNOSE_MODE=0

for arg in "$@"; do
    case "$arg" in
        --short|-s)     SHORT_MODE=1 ;;
        --json|-j)      JSON_MODE=1 ;;
        --check|-c)     CHECK_MODE=1 ;;
        --verbose|-V)   VERBOSE_MODE=1 ;;
        --diagnose|-d)  DIAGNOSE_MODE=1 ;;
        --help|-h)
            cat << EOF
DNSCrypt Smart Filter - status.sh ${MODULE_VERSION}

Usage:
  status.sh                 Full display (default)
  status.sh --short/-s      Short display (OK / STOPPED / ...)
  status.sh --check/-c      Single-line core summary
  status.sh --json/-j       JSON output
  status.sh --verbose/-V    Extended display (adds ports + config file paths)
  status.sh --diagnose/-d   Full diagnostic report (backups + user data)
  status.sh --help/-h       Show this help

Mode rules:
  • Primary modes --short, --check, --json, --diagnose are
    mutually exclusive. Selecting two or more in one
    invocation is a hard error.
  • --verbose is a modifier for the default (no-primary-mode)
    display. It cannot be combined with any primary mode.

Exit codes:
  0 = everything running
  1 = nothing running
  2 = partial (only one running)
  3 = module disabled

EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $arg"
            echo "Use --help for assistance"
            exit 1
            ;;
    esac
done

# Enforce mutual exclusivity.
_mode_count=0
_mode_list=""
[ "$SHORT_MODE" = "1" ]    && { _mode_count=$((_mode_count + 1)); _mode_list="$_mode_list --short"; }
[ "$CHECK_MODE" = "1" ]    && { _mode_count=$((_mode_count + 1)); _mode_list="$_mode_list --check"; }
[ "$JSON_MODE" = "1" ]     && { _mode_count=$((_mode_count + 1)); _mode_list="$_mode_list --json"; }
[ "$DIAGNOSE_MODE" = "1" ] && { _mode_count=$((_mode_count + 1)); _mode_list="$_mode_list --diagnose"; }

if [ "$_mode_count" -gt 1 ]; then
    echo "ERROR: only one primary mode may be selected at a time."
    echo "       got:$_mode_list"
    echo "       See 'status.sh --help' for details."
    exit 1
fi

if [ "$VERBOSE_MODE" = "1" ] && [ "$_mode_count" -gt 0 ]; then
    echo "ERROR: --verbose cannot be combined with a primary mode."
    echo "       got:$_mode_list --verbose"
    echo "       See 'status.sh --help' for details."
    exit 1
fi

# ============================================================
# [4] Load functions.sh (sources boot-mini.sh)
# ============================================================
# Lenient: a functions.sh that exists but fails to source does
# NOT abort status.sh. The script falls through to the inline
# fallbacks in [5] and continues to produce a report.
FUNCTIONS_LOADED=0
if [ -f "$MODDIR/functions.sh" ]; then
    # shellcheck disable=SC1090
    . "$MODDIR/functions.sh" 2>/dev/null

    if command -v is_port_open >/dev/null 2>&1; then
        FUNCTIONS_LOADED=1

        if command -v init_runtime_paths >/dev/null 2>&1; then
            init_runtime_paths
        fi
    fi
fi

# Finalize _MONITORING_UI_PORT: prefer the value from
# boot-mini.sh (via functions.sh); fall back to 8080.
_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"

# ============================================================
# [5] Inline fallbacks
# ============================================================
# status.sh keeps a full fallback set — a broken module is
# precisely when the user needs this tool most.
_FALLBACK_RUN_DIR="$MODDIR/proxy/run"

_fallback_get_run_dir() {
    if [ -d "$_FALLBACK_RUN_DIR" ] && [ -w "$_FALLBACK_RUN_DIR" ]; then
        printf "%s" "$_FALLBACK_RUN_DIR"
        return 0
    fi
    if mkdir -p "$_FALLBACK_RUN_DIR" 2>/dev/null; then
        chmod 0700 "$_FALLBACK_RUN_DIR" 2>/dev/null
        if [ -w "$_FALLBACK_RUN_DIR" ]; then
            printf "%s" "$_FALLBACK_RUN_DIR"
            return 0
        fi
    fi
    printf "%s" "/data/local/tmp"
}

if [ "$FUNCTIONS_LOADED" = "0" ]; then
    _FB_RUN_DIR=$(_fallback_get_run_dir)
    STATUS_FILE="$_FB_RUN_DIR/dnscrypt.status"
    PID_FILE="$_FB_RUN_DIR/dnscrypt.pid"
    WEBUI_PID_FILE="$_FB_RUN_DIR/webui.pid"
    WATCHDOG_PID_FILE="$_FB_RUN_DIR/watchdog.pid"
fi

# Three probes: /proc/net → ss → netstat.
# The trailing space in ":$hex_port " prevents :1F90 from
# matching :1F90A.
_inline_is_port_open() {
    local port="$1"
    local proto="${2:-tcp}"
    local hex_port

    case "$port" in
        ''|*[!0-9]*) return 1 ;;
    esac

    hex_port=$(printf "%04X" "$port" 2>/dev/null) || return 1

    if [ "$proto" = "udp" ]; then
        if [ -f /proc/net/udp ] && grep -qi ":$hex_port " /proc/net/udp 2>/dev/null; then
            return 0
        fi
        if [ -f /proc/net/udp6 ] && grep -qi ":$hex_port " /proc/net/udp6 2>/dev/null; then
            return 0
        fi
        if command -v ss >/dev/null 2>&1; then
            ss -lun 2>/dev/null | grep -q ":$port " && return 0
        elif command -v netstat >/dev/null 2>&1; then
            netstat -uln 2>/dev/null | grep -q ":$port " && return 0
        fi
    else
        if [ -f /proc/net/tcp ] && grep -qi ":$hex_port " /proc/net/tcp 2>/dev/null; then
            return 0
        fi
        if [ -f /proc/net/tcp6 ] && grep -qi ":$hex_port " /proc/net/tcp6 2>/dev/null; then
            return 0
        fi
        if command -v ss >/dev/null 2>&1; then
            ss -ltn 2>/dev/null | grep -q ":$port " && return 0
        elif command -v netstat >/dev/null 2>&1; then
            netstat -tln 2>/dev/null | grep -q ":$port " && return 0
        fi
    fi
    return 1
}

_inline_read_conf() {
    local conf="$1"
    local key="$2"
    local default="$3"

    if [ -f "$conf" ]; then
        local val
        val=$(grep "^${key}=" "$conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r')
        case "$val" in
            *" #"*)
                val="${val%% #*}"
                ;;
        esac
        val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$val" ]; then
            printf "%s" "$val"
            return 0
        fi
    fi
    printf "%s" "$default"
}

# Leading zeros stripped before range check (some shells
# interpret 090 as octal 72).
_inline_read_port() {
    local conf="$1"
    local key="$2"
    local default="$3"
    local val val_clean
    val=$(_inline_read_conf "$conf" "$key" "$default")

    val_clean=$(printf '%s' "$val" | sed 's/^0*//')
    [ -z "$val_clean" ] && val_clean="0"

    if echo "$val_clean" | grep -qE '^[0-9]+$' && [ "$val_clean" -ge 1 ] && [ "$val_clean" -le 65535 ]; then
        if [ "$val_clean" = "$_MONITORING_UI_PORT" ]; then
            printf "%s" "$default"
            return 0
        fi
        printf "%s" "$val_clean"
        return 0
    fi
    printf "%s" "$default"
}

# /proc/net/if_inet6 lists one line per interface with an IPv6 address.
_inline_is_ipv6_available() {
    if [ ! -f /proc/net/if_inet6 ]; then
        return 1
    fi
    local count
    count=$(wc -l < /proc/net/if_inet6 2>/dev/null | tr -d ' ')
    if [ -z "$count" ] || [ "$count" -eq 0 ]; then
        return 1
    fi
    return 0
}

# Display-only — main.go is the authority. Table matches
# main.go:memoryLimitForProfile and functions.sh:get_profile_memory_hint.
_inline_get_profile_memory_hint() {
    local profile="pro"

    if [ -f "$SELECTED_FILE" ]; then
        local p
        p=$(cat "$SELECTED_FILE" 2>/dev/null | tr -d '\r\n ')
        case "$p" in
            light|normal|pro|proplus|ultimate) profile="$p" ;;
        esac
    fi

    local mb
    case "$profile" in
        light)    mb="80"  ;;
        normal)   mb="100" ;;
        pro)      mb="120" ;;
        proplus)  mb="160" ;;
        ultimate) mb="220" ;;
        *)        mb="80"  ;;
    esac

    printf "%s MB (%s)" "$mb" "$profile"
}

# ============================================================
# [6] Unified wrappers
# ============================================================
if [ "$FUNCTIONS_LOADED" = "1" ]; then
    is_tcp_open()           { is_port_open "$1" tcp; }
    is_udp_open()           { is_port_open "$1" udp; }
    read_conf()             { read_conf "$1" "$2" "$3"; }
    read_webui_port()       { get_webui_port "$CONF_FILE" 2>/dev/null; }

    if command -v get_dashboard_port >/dev/null 2>&1; then
        read_dashboard_port() { get_dashboard_port "$CONF_FILE" 2>/dev/null; }
    else
        read_dashboard_port() { _inline_read_port "$CONF_FILE" "DASHBOARD_PORT" "9091"; }
    fi

    if command -v is_ipv6_available >/dev/null 2>&1; then
        ipv6_available()    { is_ipv6_available; }
    else
        ipv6_available()    { _inline_is_ipv6_available; }
    fi

    if command -v get_profile_memory_hint >/dev/null 2>&1; then
        mem_hint()          { get_profile_memory_hint; }
    else
        mem_hint()          { _inline_get_profile_memory_hint; }
    fi
else
    is_tcp_open()           { _inline_is_port_open "$1" tcp; }
    is_udp_open()           { _inline_is_port_open "$1" udp; }
    read_conf()             { _inline_read_conf "$1" "$2" "$3"; }
    read_webui_port()       { _inline_read_port "$CONF_FILE" "PORT" "9090"; }
    read_dashboard_port()   { _inline_read_port "$CONF_FILE" "DASHBOARD_PORT" "9091"; }
    ipv6_available()        { _inline_is_ipv6_available; }
    mem_hint()              { _inline_get_profile_memory_hint; }
fi

# ============================================================
# [7] Profile resolver
# ============================================================
PROFILE_KEY=""
PROFILE_NAME="unknown"

if [ -f "$SELECTED_FILE" ]; then
    PROFILE_KEY=$(cat "$SELECTED_FILE" 2>/dev/null | tr -d '\r\n ')
    case "$PROFILE_KEY" in
        light)    PROFILE_NAME="Light" ;;
        normal)   PROFILE_NAME="Normal" ;;
        pro)      PROFILE_NAME="PRO" ;;
        proplus)  PROFILE_NAME="PRO++" ;;
        ultimate) PROFILE_NAME="Ultimate" ;;
        "")       PROFILE_NAME="unknown" ;;
        *)        PROFILE_NAME="$PROFILE_KEY" ;;
    esac
else
    PROFILE_KEY="pro"
    PROFILE_NAME="PRO"
fi

MEMORY_HINT=$(mem_hint 2>/dev/null)
[ -z "$MEMORY_HINT" ] && MEMORY_HINT="80 MB (pro)"

# ============================================================
# [7b] Backup resolver
# ============================================================
# SNAP-MANIFEST: a directory is a snapshot iff it contains
# .manifest.json. Sort: mtime descending. Excludes current/,
# txn-*, orphan-txn-*, .restore_snap.*, apk/.
#
# Subshell isolation prevents cd/loop vars from leaking.
_list_snapshots() {
    local limit="${1:-0}"
    [ -d "$PERSISTENT_BACKUP" ] || return 0

    local list
    list=$(
        cd "$PERSISTENT_BACKUP" 2>/dev/null || exit 0
        for _d in */; do
            _d="${_d%/}"
            [ -d "$_d" ] || continue
            case "$_d" in
                current|txn-*|orphan-txn-*|.restore_snap.*|apk) continue ;;
            esac
            [ -f "$_d/.manifest.json" ] || continue
            _mt=$(stat -c %Y "$_d" 2>/dev/null) \
                || _mt=$(stat -f %m "$_d" 2>/dev/null) \
                || _mt=0
            case "$_mt" in ''|*[!0-9]*) _mt=0 ;; esac
            printf '%s %s\n' "$_mt" "$_d"
        done | LC_ALL=C sort -rn -k1,1 | awk '{print $2}'
    )

    [ -z "$list" ] && return 0

    if [ "$limit" -gt 0 ] 2>/dev/null; then
        printf '%s\n' "$list" | head -n "$limit"
    else
        printf '%s\n' "$list"
    fi
}

# Exactly 0 returns "0s ago" (not "N/A") — distinguishes
# "created this second" from "age unknown". "N/A" for empty /
# non-numeric / negative input.
format_age() {
    local sec="$1"
    if [ -z "$sec" ] || ! echo "$sec" | grep -qE '^-?[0-9]+$' || [ "$sec" -lt 0 ]; then
        printf "N/A"
        return
    fi
    if [ "$sec" -lt 60 ]; then
        printf "%ds ago" "$sec"
    elif [ "$sec" -lt 3600 ]; then
        printf "%dm ago" $((sec / 60))
    elif [ "$sec" -lt 86400 ]; then
        printf "%dh ago" $((sec / 3600))
    else
        printf "%dd ago" $((sec / 86400))
    fi
}

# --- Collect backup state ---
BACKUP_COUNT=0
BACKUP_TXN_COUNT=0
BACKUP_ORPHAN_COUNT=0
BACKUP_LAST_TIME=""
BACKUP_LAST_EPOCH=0
BACKUP_LAST_AGE_SEC=0
BACKUP_LAST_NAME=""
BACKUP_LAST_STABLE=""
BACKUP_STATUS="missing"

if [ -d "$PERSISTENT_BACKUP" ]; then
    BACKUP_STATUS="empty"

    _bk_count=$( _list_snapshots | wc -l | tr -d ' ' )
    [ -z "$_bk_count" ] && _bk_count=0
    BACKUP_COUNT="$_bk_count"

    _txn_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d txn-*/ 2>/dev/null | \
        wc -l | tr -d ' ')
    [ -z "$_txn_count" ] && _txn_count=0
    BACKUP_TXN_COUNT="$_txn_count"

    _orphan_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d orphan-txn-*/ 2>/dev/null | \
        wc -l | tr -d ' ')
    [ -z "$_orphan_count" ] && _orphan_count=0
    BACKUP_ORPHAN_COUNT="$_orphan_count"

    if [ "$BACKUP_COUNT" -gt 0 ]; then
        BACKUP_STATUS="ok"

        BACKUP_LAST_NAME=$( _list_snapshots 1 )

        if [ -n "$BACKUP_LAST_NAME" ] && [ -d "$PERSISTENT_BACKUP/$BACKUP_LAST_NAME" ]; then
            BACKUP_LAST_EPOCH=$(stat -c %Y "$PERSISTENT_BACKUP/$BACKUP_LAST_NAME" 2>/dev/null) \
                || BACKUP_LAST_EPOCH=$(stat -f %m "$PERSISTENT_BACKUP/$BACKUP_LAST_NAME" 2>/dev/null) \
                || BACKUP_LAST_EPOCH=0

            if ! echo "$BACKUP_LAST_EPOCH" | grep -qE '^[0-9]+$'; then
                BACKUP_LAST_EPOCH=0
            fi

            if [ "$BACKUP_LAST_EPOCH" -gt 0 ]; then
                # Use the directory as the reference file for
                # `date -r` — `date -d @epoch` works on GNU
                # coreutils but not Android's toybox.
                BACKUP_LAST_TIME=$(date -d "@$BACKUP_LAST_EPOCH" '+%Y-%m-%d %H:%M' 2>/dev/null)
                if [ -z "$BACKUP_LAST_TIME" ]; then
                    BACKUP_LAST_TIME=$(date -r "$PERSISTENT_BACKUP/$BACKUP_LAST_NAME" '+%Y-%m-%d %H:%M' 2>/dev/null)
                fi
                [ -z "$BACKUP_LAST_TIME" ] && BACKUP_LAST_TIME="unknown"

                _now=$(date +%s)
                if echo "$_now" | grep -qE '^[0-9]+$'; then
                    BACKUP_LAST_AGE_SEC=$((_now - BACKUP_LAST_EPOCH))
                fi
            fi
        fi
    fi

    if [ -f "$LAST_STABLE_FILE" ]; then
        BACKUP_LAST_STABLE=$(cat "$LAST_STABLE_FILE" 2>/dev/null | tr -d '\r\n ')
    fi
fi

BACKUP_LAST_AGE=$(format_age "$BACKUP_LAST_AGE_SEC")

# ============================================================
# [7c] Pending notification + recovery mode
# ============================================================
PENDING_NOTIFY_CONTENT=""
if [ -f "$PENDING_NOTIFY_FILE" ]; then
    PENDING_NOTIFY_CONTENT=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
fi

RECOVERY_MODE_ACTIVE="NO"
if [ -f "$RECOVERY_TRIGGER_1" ] || [ -f "$RECOVERY_TRIGGER_2" ]; then
    RECOVERY_MODE_ACTIVE="YES"
fi

# ============================================================
# [8] Collect data
# ============================================================

# [8a] Ports
PORT=$(read_webui_port)
DASHBOARD_PORT=$(read_dashboard_port)
[ -z "$PORT" ] && PORT="9090"
[ -z "$DASHBOARD_PORT" ] && DASHBOARD_PORT="9091"

# [8b] DNS Engine status
# Prefer functions.sh's is_dnscrypt_running (PID + comm + port
# cross-check). Fallback: pgrep -x + is_udp_open 5354.
DNS_RUNNING="NO"
if [ "$FUNCTIONS_LOADED" = "1" ] && command -v is_dnscrypt_running >/dev/null 2>&1; then
    if is_dnscrypt_running; then
        DNS_RUNNING="YES"
    fi
else
    if pgrep -x dnscrypt-proxy >/dev/null 2>&1 && is_udp_open 5354; then
        DNS_RUNNING="YES"
    fi
fi

# [8c] WebUI status
WEBUI_RUNNING="NO"
if [ "$FUNCTIONS_LOADED" = "1" ] && command -v is_webui_running >/dev/null 2>&1; then
    if is_webui_running "$PORT"; then
        WEBUI_RUNNING="YES"
    fi
else
    if is_tcp_open "$PORT"; then
        WEBUI_RUNNING="YES"
    fi
fi

# [8d] User intent (STATUS_FILE)
STATUS_FROM_FILE="UNKNOWN"
if [ -f "$STATUS_FILE" ]; then
    STATUS_FROM_FILE=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
fi

# [8e] Blocklist stats
BLOCKLIST_COUNT="0"
BLOCKLIST_SIZE="0"
if [ -f "$BLOCKLIST_FILE" ]; then
    BLOCKLIST_COUNT=$(wc -l < "$BLOCKLIST_FILE" 2>/dev/null | tr -d ' ')
    [ -z "$BLOCKLIST_COUNT" ] && BLOCKLIST_COUNT="0"
    BLOCKLIST_SIZE=$(wc -c < "$BLOCKLIST_FILE" 2>/dev/null | tr -d ' ')
    [ -z "$BLOCKLIST_SIZE" ] && BLOCKLIST_SIZE="0"
fi

RAW_BLOCKLIST_COUNT="0"
RAW_BLOCKLIST_SIZE="0"
if [ -f "$RAW_BLOCKLIST_FILE" ]; then
    RAW_BLOCKLIST_COUNT=$(wc -l < "$RAW_BLOCKLIST_FILE" 2>/dev/null | tr -d ' ')
    [ -z "$RAW_BLOCKLIST_COUNT" ] && RAW_BLOCKLIST_COUNT="0"
    RAW_BLOCKLIST_SIZE=$(wc -c < "$RAW_BLOCKLIST_FILE" 2>/dev/null | tr -d ' ')
    [ -z "$RAW_BLOCKLIST_SIZE" ] && RAW_BLOCKLIST_SIZE="0"
fi

# [8f] Last blocklist update time
LAST_UPDATE="unknown"
if [ -f "$BLOCKLIST_FILE" ]; then
    LAST_UPDATE=$(date -r "$BLOCKLIST_FILE" '+%Y-%m-%d %H:%M' 2>/dev/null)
    [ -z "$LAST_UPDATE" ] && LAST_UPDATE="unknown"
fi

# [8g] Module disabled?
IS_DISABLED="NO"
[ -f "$MODDIR/disable" ] && IS_DISABLED="YES"

# [8h] Auto-restart configuration
AUTO_DNS=$(read_conf "$CONF_FILE" "AUTO_RESTART_DNS" "1")
AUTO_WEBUI=$(read_conf "$CONF_FILE" "AUTO_RESTART_WEBUI" "1")
case "$AUTO_DNS"   in 0|1) ;; *) AUTO_DNS="1"   ;; esac
case "$AUTO_WEBUI" in 0|1) ;; *) AUTO_WEBUI="1" ;; esac

# [8i] BIND_ADDR
BIND_ADDR=$(read_conf "$CONF_FILE" "BIND_ADDR" "127.0.0.1")

# [8j] Watchdog status
WATCHDOG_RUNNING="NO"
WATCHDOG_PID=""
if [ -f "$WATCHDOG_PID_FILE" ]; then
    wd_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$wd_pid" ] && kill -0 "$wd_pid" 2>/dev/null; then
        wd_comm=$(cat "/proc/$wd_pid/comm" 2>/dev/null)
        case "$wd_comm" in
            sh|ash|bash|mksh|busybox|*sh)
                WATCHDOG_RUNNING="YES"
                WATCHDOG_PID="$wd_pid"
                ;;
        esac
    fi
fi

# [8k] IPv6 availability
IPV6_AVAILABLE="NO"
if ipv6_available; then
    IPV6_AVAILABLE="YES"
fi

# [8l] Active run directory
if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ]; then
    ACTIVE_RUN_DIR="$RUN_DIR_ACTIVE"
else
    ACTIVE_RUN_DIR=$(dirname "$STATUS_FILE")
fi

# [8m] PIDs
DNS_PID=""
if [ -f "$PID_FILE" ]; then
    DNS_PID=$(cat "$PID_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$DNS_PID" ] && ! kill -0 "$DNS_PID" 2>/dev/null; then
        DNS_PID=""
    fi
fi

WEBUI_PID=""
if [ -f "$WEBUI_PID_FILE" ]; then
    WEBUI_PID=$(cat "$WEBUI_PID_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$WEBUI_PID" ] && ! kill -0 "$WEBUI_PID" 2>/dev/null; then
        WEBUI_PID=""
    fi
fi

# [8n] Root solution
detect_root_solution() {
    if [ -n "${KSU_VER:-}" ] || [ -d "/data/adb/ksu" ]; then
        printf "KernelSU"
        return 0
    fi
    if [ -n "${APATCH:-}" ] || [ -d "/data/adb/ap" ]; then
        printf "APatch"
        return 0
    fi
    if [ -n "${MAGISK_VER_CODE:-}" ] || [ -d "/data/adb/magisk" ]; then
        printf "Magisk"
        return 0
    fi
    printf "unknown"
}

ROOT_SOLUTION=$(detect_root_solution)

# ============================================================
# [9] JSON escaping helpers
# ============================================================
# Minimal JSON string escaper. In sed, `\b` is a word-boundary
# anchor (not backspace), so a `s/\b/\\b/g` rule would corrupt
# every string field. Backspace does not appear in any value
# this function is used on — no replacement needed.
esc_json() {
    if [ -z "$1" ]; then
        printf ''
        return
    fi
    printf '%s' "$1" | sed '
        s/\\/\\\\/g
        s/"/\\"/g
        s/\t/\\t/g
        s/\r/\\r/g
        s/\f/\\f/g
    ' | tr '\n' ' '
}

# Empty → literal `null`; non-empty → quoted JSON string.
_json_str() {
    if [ -z "$1" ]; then
        printf 'null'
    else
        printf '"%s"' "$(esc_json "$1")"
    fi
}

# ============================================================
# [10] Quick check mode (single line)
# ============================================================
# Eight pipe-separated fields for shell scripting:
#   <version> | DNS=<UP|DOWN> | WEBUI=<UP|DOWN> |
#   PROFILE=<key> | MEM=<hint> | ENTRIES=<count> |
#   BACKUP=<count>snap/<age> | RUNDIR=<path>[ DISABLED]
if [ "$CHECK_MODE" = "1" ]; then
    dns_str="DNS=$( [ "$DNS_RUNNING" = "YES" ] && echo "UP" || echo "DOWN" )"
    webui_str="WEBUI=$( [ "$WEBUI_RUNNING" = "YES" ] && echo "UP" || echo "DOWN" )"
    profile_str="PROFILE=${PROFILE_KEY:-unknown}"
    mem_str="MEM=${MEMORY_HINT}"
    entries_str="ENTRIES=$BLOCKLIST_COUNT"
    backup_str="BACKUP=${BACKUP_COUNT}snap/${BACKUP_LAST_AGE}"
    rundir_str="RUNDIR=$ACTIVE_RUN_DIR"
    disabled_str=""
    [ "$IS_DISABLED" = "YES" ] && disabled_str=" DISABLED"

    printf "%s | %s | %s | %s | %s | %s | %s | %s%s\n" \
        "$MODULE_VERSION" "$dns_str" "$webui_str" "$profile_str" "$mem_str" "$entries_str" "$backup_str" "$rundir_str" "$disabled_str"

    if [ "$IS_DISABLED" = "YES" ]; then
        exit 3
    elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ]; then
        exit 0
    elif [ "$DNS_RUNNING" = "NO" ] && [ "$WEBUI_RUNNING" = "NO" ]; then
        exit 1
    else
        exit 2
    fi
fi

# ============================================================
# [11] JSON mode
# ============================================================
# Hand-formatted (no jq dependency). Nullable fields use
# `_json_str` (emits literal `null` for empty values, not "").
if [ "$JSON_MODE" = "1" ]; then
    CHECKED_AT=$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)

    MEM_MB=$(printf '%s' "$MEMORY_HINT" | grep -oE '^[0-9]+' || echo "0")

    BACKUP_LAST_HUMAN=""
    if [ -n "$BACKUP_LAST_TIME" ] && [ "$BACKUP_LAST_TIME" != "unknown" ]; then
        BACKUP_LAST_HUMAN="$BACKUP_LAST_TIME"
    fi

    cat << EOF
{
  "version": "$(esc_json "$MODULE_VERSION")",
  "checked_at": "$CHECKED_AT",
  "functions_loaded": $([ "$FUNCTIONS_LOADED" = "1" ] && echo "true" || echo "false"),
  "root_solution": "$(esc_json "$ROOT_SOLUTION")",
  "run_dir": "$(esc_json "$ACTIVE_RUN_DIR")",
  "dns_engine": {
    "running": $([ "$DNS_RUNNING" = "YES" ] && echo "true" || echo "false"),
    "port": 5354,
    "pid": $(_json_str "$DNS_PID")
  },
  "webui": {
    "running": $([ "$WEBUI_RUNNING" = "YES" ] && echo "true" || echo "false"),
    "port": $PORT,
    "url": "http://127.0.0.1:$PORT",
    "pid": $(_json_str "$WEBUI_PID")
  },
  "dashboard": {
    "port": $DASHBOARD_PORT,
    "url": "http://127.0.0.1:$DASHBOARD_PORT"
  },
  "bind_addr": "$(esc_json "$BIND_ADDR")",
  "watchdog": {
    "running": $([ "$WATCHDOG_RUNNING" = "YES" ] && echo "true" || echo "false"),
    "pid": $(_json_str "$WATCHDOG_PID")
  },
  "auto_restart": {
    "dns": $AUTO_DNS,
    "webui": $AUTO_WEBUI
  },
  "ipv6_available": $([ "$IPV6_AVAILABLE" = "YES" ] && echo "true" || echo "false"),
  "status_file": "$(esc_json "$STATUS_FROM_FILE")",
  "recovery_mode_active": $([ "$RECOVERY_MODE_ACTIVE" = "YES" ] && echo "true" || echo "false"),
  "pending_notification": $(_json_str "$PENDING_NOTIFY_CONTENT"),
  "profile": {
    "key": "$(esc_json "$PROFILE_KEY")",
    "name": "$(esc_json "$PROFILE_NAME")",
    "memory_limit_mb": $MEM_MB
  },
  "blocklist": {
    "entries": $BLOCKLIST_COUNT,
    "size_bytes": $BLOCKLIST_SIZE,
    "last_update": "$(esc_json "$LAST_UPDATE")"
  },
  "blocklist_raw": {
    "entries": $RAW_BLOCKLIST_COUNT,
    "size_bytes": $RAW_BLOCKLIST_SIZE
  },
  "backups": {
    "status": "$(esc_json "$BACKUP_STATUS")",
    "available": $BACKUP_COUNT,
    "in_flight_txn": $BACKUP_TXN_COUNT,
    "orphan_txn": $BACKUP_ORPHAN_COUNT,
    "last_backup": $(_json_str "$BACKUP_LAST_HUMAN"),
    "last_backup_name": $(_json_str "$BACKUP_LAST_NAME"),
    "last_backup_age_seconds": $BACKUP_LAST_AGE_SEC,
    "last_stable": $(_json_str "$BACKUP_LAST_STABLE"),
    "path": "$(esc_json "$PERSISTENT_BACKUP")"
  },
  "disabled": $([ "$IS_DISABLED" = "YES" ] && echo "true" || echo "false")
}
EOF
    exit 0
fi

# ============================================================
# [12] Short mode
# ============================================================
# One word on stdout: OK / DNS_ONLY / WEBUI_ONLY / STOPPED / DISABLED.
if [ "$SHORT_MODE" = "1" ]; then
    if [ "$IS_DISABLED" = "YES" ]; then
        echo "DISABLED"
        exit 3
    elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ]; then
        echo "OK"
        exit 0
    elif [ "$DNS_RUNNING" = "YES" ]; then
        echo "DNS_ONLY"
        exit 2
    elif [ "$WEBUI_RUNNING" = "YES" ]; then
        echo "WEBUI_ONLY"
        exit 2
    else
        echo "STOPPED"
        exit 1
    fi
fi

# ============================================================
# [13] Diagnose mode
# ============================================================
# Full diagnostic report. Intended to be pasted verbatim into a
# GitHub issue. Colors applied only when stdout is a TTY.
if [ "$DIAGNOSE_MODE" = "1" ]; then
    if [ -t 1 ]; then
        C_RED=$(printf '\033[0;31m'); C_GREEN=$(printf '\033[0;32m')
        C_YELLOW=$(printf '\033[0;33m'); C_CYAN=$(printf '\033[0;36m')
        C_BOLD=$(printf '\033[1m'); C_DIM=$(printf '\033[2m'); C_NC=$(printf '\033[0m')
    else
        C_RED=''; C_GREEN=''; C_YELLOW=''; C_CYAN=''; C_BOLD=''; C_DIM=''; C_NC=''
    fi

    echo ""
    echo "================================================================="
    echo "  DNSCrypt Smart Filter — Diagnostic Report"
    echo "  Version: $MODULE_VERSION"
    echo "  Date:    $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "================================================================="
    echo ""

    # --- System info ---
    echo "${C_BOLD}─── System Information ───${C_NC}"
    echo "  Android:       $(getprop ro.build.version.release 2>/dev/null) (API $(getprop ro.build.version.sdk 2>/dev/null))"
    echo "  Device:        $(getprop ro.product.model 2>/dev/null)"
    echo "  Kernel:        $(uname -r 2>/dev/null)"
    echo "  Architecture:  $(getprop ro.product.cpu.abi 2>/dev/null)"
    echo "  SoC:           $(getprop ro.product.board 2>/dev/null)"
    echo "  Root solution: $ROOT_SOLUTION"
    if [ "$ROOT_SOLUTION" = "Magisk" ]; then
        echo "  Magisk:        $(magisk -V 2>/dev/null || echo 'unknown')"
    fi
    echo ""

    # --- Module info ---
    echo "${C_BOLD}─── Module Information ───${C_NC}"
    echo "  Version:       $MODULE_VERSION"
    echo "  Module path:   $MODDIR"
    echo "  Runtime dir:   $ACTIVE_RUN_DIR"
    echo "  functions.sh:  $([ "$FUNCTIONS_LOADED" = "1" ] && echo 'loaded' || echo 'NOT loaded (using fallback)')"
    echo ""

    # --- Service status ---
    echo "${C_BOLD}─── Service Status ───${C_NC}"
    if [ "$DNS_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✓${C_NC} DNS Engine:   running (port 5354/UDP)"
    else
        echo "  ${C_RED}✗${C_NC} DNS Engine:   ${C_RED}STOPPED${C_NC}"
    fi
    if [ "$WEBUI_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✓${C_NC} WebUI:        running (port $PORT)"
    else
        echo "  ${C_RED}✗${C_NC} WebUI:        ${C_RED}STOPPED${C_NC}"
    fi
    if [ "$WATCHDOG_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✓${C_NC} Watchdog:     running (PID: $WATCHDOG_PID)"
    else
        echo "  ${C_DIM}−${C_NC} Watchdog:     inactive"
    fi
    if [ "$IS_DISABLED" = "YES" ]; then
        echo "  ${C_YELLOW}⚠${C_NC} Module:       ${C_YELLOW}DISABLED${C_NC}"
    fi
    echo ""

    # --- Recovery mode + pending notification ---
    echo "${C_BOLD}─── Recovery & Notifications ───${C_NC}"
    if [ "$RECOVERY_MODE_ACTIVE" = "YES" ]; then
        echo "  ${C_YELLOW}⚠${C_NC} Recovery mode: ${C_YELLOW}TRIGGER FILE PRESENT${C_NC}"
        [ -f "$RECOVERY_TRIGGER_1" ] && echo "     - $RECOVERY_TRIGGER_1"
        [ -f "$RECOVERY_TRIGGER_2" ] && echo "     - $RECOVERY_TRIGGER_2"
        echo "     ${C_DIM}The next install will restore the last known good config.${C_NC}"
    else
        echo "  ${C_GREEN}✓${C_NC} Recovery mode: not triggered"
    fi

    if [ -n "$PENDING_NOTIFY_CONTENT" ]; then
        echo "  ${C_CYAN}ℹ${C_NC} Pending notification:"
        echo "     ${C_DIM}$PENDING_NOTIFY_CONTENT${C_NC}"
        echo "     ${C_DIM}(main.go will log and delete this at startup)${C_NC}"
    else
        echo "  ${C_DIM}−${C_NC} Pending notification: none"
    fi
    echo ""

    # --- User data files ---
    echo "${C_BOLD}─── User Data Files ───${C_NC}"
    echo "  Location: $BIN_DIR"
    echo ""
    _ud_missing=0
    for _f in $USER_FILES; do
        _fp="$BIN_DIR/$_f"
        if [ -f "$_fp" ]; then
            _size=$(wc -c < "$_fp" 2>/dev/null | tr -d ' ')
            _mtime=$(date -r "$_fp" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
            printf "  ${C_GREEN}✓${C_NC} %-25s ${C_DIM}%8s bytes  (%s)${C_NC}\n" "$_f" "$_size" "$_mtime"
        else
            printf "  ${C_RED}✗${C_NC} %-25s ${C_DIM}(missing)${C_NC}\n" "$_f"
            _ud_missing=$((_ud_missing + 1))
        fi
    done
    echo ""

    # --- Backups ---
    echo "${C_BOLD}─── Backups ───${C_NC}"
    echo "  Location: $PERSISTENT_BACKUP"

    case "$BACKUP_STATUS" in
        missing)
            echo "  ${C_YELLOW}⚠${C_NC} Directory not found"
            echo "     ${C_DIM}(It is created on first successful install or first auto-backup)${C_NC}"
            ;;
        empty)
            echo "  ${C_YELLOW}⚠${C_NC} Directory exists but contains no snapshots"
            ;;
        ok)
            echo "  ${C_GREEN}✓${C_NC} $BACKUP_COUNT snapshot(s) available"
            echo "     Last backup: ${C_DIM}$BACKUP_LAST_NAME${C_NC} ($BACKUP_LAST_AGE)"
            echo ""

            echo "  ${C_BOLD}Recent snapshots:${C_NC}"
            _bk_i=0
            while IFS= read -r _snap; do
                [ -z "$_snap" ] && continue
                _bk_i=$((_bk_i + 1))
                _file_count=0
                for _chk in "$PERSISTENT_BACKUP/$_snap"/*.conf "$PERSISTENT_BACKUP/$_snap"/*.toml "$PERSISTENT_BACKUP/$_snap"/*.txt; do
                    [ -f "$_chk" ] && _file_count=$((_file_count + 1))
                done
                [ -z "$_file_count" ] && _file_count=0
                _has_manifest=""
                [ -f "$PERSISTENT_BACKUP/$_snap/.manifest.json" ] && _has_manifest=" +manifest"
                _snap_time=$(date -r "$PERSISTENT_BACKUP/$_snap" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "?")
                printf "    ${C_DIM}%2d.${C_NC} %-30s ${C_DIM}(%s files%s, %s)${C_NC}\n" \
                    "$_bk_i" "$_snap" "$_file_count" "$_has_manifest" "$_snap_time"
            done <<EOF
$(_list_snapshots 10)
EOF

            if [ -n "$BACKUP_LAST_STABLE" ]; then
                echo ""
                echo "  ${C_BOLD}.last_stable:${C_NC} $BACKUP_LAST_STABLE"
            fi

            if [ -f "$LAST_AUTO_BACKUP_MARKER" ]; then
                _auto_mtime=$(stat -c %Y "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
                    || _auto_mtime=$(stat -f %m "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
                    || _auto_mtime=0
                if echo "$_auto_mtime" | grep -qE '^[0-9]+$' && [ "$_auto_mtime" -gt 0 ]; then
                    _auto_now=$(date +%s 2>/dev/null)
                    case "$_auto_now" in ''|*[!0-9]*) _auto_now=0 ;; esac
                    if [ "$_auto_now" -gt 0 ]; then
                        _auto_age=$((_auto_now - _auto_mtime))
                        echo "  ${C_BOLD}Last auto-backup:${C_NC} $(format_age "$_auto_age")"
                    fi
                fi
            fi
            ;;
    esac

    # --- In-flight transactions ---
    if [ "$BACKUP_TXN_COUNT" -gt 0 ]; then
        echo ""
        echo "  ${C_YELLOW}⚠${C_NC} In-flight transactions: $BACKUP_TXN_COUNT"
        echo "     ${C_DIM}(An install may be in progress, or a previous install was interrupted)${C_NC}"
        (cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d txn-*/ 2>/dev/null | \
            sed 's:/$::' | \
            while IFS= read -r _txn; do
                [ -z "$_txn" ] && continue
                _state=$(cat "$PERSISTENT_BACKUP/$_txn/.state" 2>/dev/null | tr -d '\r\n ')
                [ -z "$_state" ] && _state="(no state)"
                printf "     ${C_DIM}•${C_NC} %-30s ${C_DIM}[%s]${C_NC}\n" "$_txn" "$_state"
            done)
    fi

    # --- Orphan transactions ---
    if [ "$BACKUP_ORPHAN_COUNT" -gt 0 ]; then
        echo ""
        echo "  ${C_YELLOW}⚠${C_NC} Orphan transactions: $BACKUP_ORPHAN_COUNT"
        echo "     ${C_DIM}(Preserved from a previous interrupted install; inspect manually)${C_NC}"
        (cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d orphan-txn-*/ 2>/dev/null | \
            sed 's:/$::' | \
            while IFS= read -r _orphan; do
                [ -z "$_orphan" ] && continue
                printf "     ${C_DIM}•${C_NC} %s\n" "$_orphan"
            done)
    fi
    echo ""

    # --- Health checks ---
    echo "${C_BOLD}─── Health Checks ───${C_NC}"
    _health_issues=0

    if [ "$DNS_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✓${C_NC} DNS engine listening on 5354/UDP"
    else
        echo "  ${C_RED}✗${C_NC} DNS engine NOT listening on 5354/UDP"
        _health_issues=$((_health_issues + 1))
    fi

    if [ "$WEBUI_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✓${C_NC} WebUI listening on port $PORT"
    else
        echo "  ${C_RED}✗${C_NC} WebUI NOT listening on port $PORT"
        _health_issues=$((_health_issues + 1))
    fi

    if [ "$BLOCKLIST_COUNT" -gt 0 ]; then
        echo "  ${C_GREEN}✓${C_NC} Blocklist loaded ($BLOCKLIST_COUNT entries, $BLOCKLIST_SIZE bytes)"
    else
        echo "  ${C_YELLOW}⚠${C_NC} Blocklist is empty (no profile applied yet?)"
    fi

    if [ -f "$TOML_FILE" ]; then
        echo "  ${C_GREEN}✓${C_NC} dnscrypt-proxy.toml present"
    else
        echo "  ${C_RED}✗${C_NC} dnscrypt-proxy.toml MISSING"
        _health_issues=$((_health_issues + 1))
    fi

    if [ -f "$CONF_FILE" ]; then
        echo "  ${C_GREEN}✓${C_NC} webui.conf present"
    else
        echo "  ${C_RED}✗${C_NC} webui.conf MISSING"
        _health_issues=$((_health_issues + 1))
    fi

    if [ -n "$PROFILE_KEY" ]; then
        echo "  ${C_GREEN}✓${C_NC} Active profile: $PROFILE_NAME ($MEMORY_HINT)"
    else
        echo "  ${C_YELLOW}⚠${C_NC} Profile file missing or invalid"
    fi

    if [ "$IS_DISABLED" = "NO" ]; then
        if [ "$STATUS_FROM_FILE" = "ON" ] && [ "$DNS_RUNNING" = "NO" ]; then
            echo "  ${C_YELLOW}⚠${C_NC} STATUS_FILE=ON but DNS engine is not running (Watchdog should recover it)"
        elif [ "$STATUS_FROM_FILE" = "OFF" ] && [ "$DNS_RUNNING" = "YES" ]; then
            echo "  ${C_YELLOW}⚠${C_NC} STATUS_FILE=OFF but DNS engine is running (user intent mismatch)"
        fi
    fi

    if [ "$_ud_missing" -gt 0 ]; then
        echo "  ${C_RED}✗${C_NC} $_ud_missing user data file(s) missing"
        _health_issues=$((_health_issues + 1))
    else
        echo "  ${C_GREEN}✓${C_NC} All 5 user data files present"
    fi

    if [ "$BACKUP_STATUS" = "ok" ]; then
        echo "  ${C_GREEN}✓${C_NC} Backup layer healthy ($BACKUP_COUNT snapshot(s))"
    elif [ "$BACKUP_STATUS" = "empty" ]; then
        echo "  ${C_YELLOW}⚠${C_NC} Backup layer exists but is empty"
    else
        echo "  ${C_YELLOW}⚠${C_NC} Backup directory not initialized"
    fi

    echo ""

    # --- Diagnosis ---
    echo "${C_BOLD}─── Diagnosis ───${C_NC}"
    if [ "$IS_DISABLED" = "YES" ]; then
        echo "  ${C_YELLOW}⚠  Module is disabled.${C_NC}"
        echo "     To enable: remove $MODDIR/disable and reboot"
    elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ] && [ "$_health_issues" -eq 0 ]; then
        echo "  ${C_GREEN}✅ All systems operational${C_NC}"
        if [ "$BACKUP_COUNT" -eq 0 ]; then
            echo "  ${C_YELLOW}⚠  No backups available yet${C_NC}"
            echo "     ${C_DIM}A backup will be created on next boot (auto) or before the next risky operation${C_NC}"
        fi
    elif [ "$_health_issues" -gt 0 ]; then
        echo "  ${C_RED}❌ $_health_issues critical issue(s) detected${C_NC}"
        echo "     See the 'Health Checks' section above"
        echo "     Full guide: docs/GUIDE.md §7"
    else
        echo "  ${C_YELLOW}⚠  Services not fully running${C_NC}"
        echo "     Try: su -c 'sh $MODDIR/action.sh --restart'"
    fi

    echo ""
    echo "================================================================="
    echo "  End of report"
    echo "  Attach this to your bug report:"
    echo "    https://github.com/gasciljh/dnscrypt-proxy-webui/issues"
    echo "================================================================="
    echo ""

    if [ "$IS_DISABLED" = "YES" ]; then
        exit 3
    elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ] && [ "$_health_issues" -eq 0 ]; then
        exit 0
    else
        exit 2
    fi
fi

# ============================================================
# [14] Full mode (default)
# ============================================================
# Multi-section, colored, human-readable report.
if [ -t 1 ]; then
    RED=$(printf '\033[0;31m')
    GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[0;33m')
    BLUE=$(printf '\033[0;34m')
    CYAN=$(printf '\033[0;36m')
    DIM=$(printf '\033[2m')
    BOLD=$(printf '\033[1m')
    MAGENTA=$(printf '\033[0;35m')
    NC=$(printf '\033[0m')
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; DIM=''; BOLD=''; MAGENTA=''; NC=''
fi

# --- Overall status ---
if [ "$IS_DISABLED" = "YES" ]; then
    OVERALL="${YELLOW}WARNING: DISABLED${NC}"
elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ]; then
    OVERALL="${GREEN}ACTIVE${NC}"
elif [ "$DNS_RUNNING" = "YES" ] || [ "$WEBUI_RUNNING" = "YES" ]; then
    OVERALL="${YELLOW}PARTIAL${NC}"
else
    OVERALL="${RED}STOPPED${NC}"
fi

DNS_ICON=$([ "$DNS_RUNNING" = "YES" ] && printf "${GREEN}[ON]${NC}" || printf "${RED}[OFF]${NC}")
DNS_TEXT=$([ "$DNS_RUNNING" = "YES" ] && printf "running on port 5354/UDP" || printf "stopped")

WEBUI_ICON=$([ "$WEBUI_RUNNING" = "YES" ] && printf "${GREEN}[ON]${NC}" || printf "${RED}[OFF]${NC}")
WEBUI_TEXT=$([ "$WEBUI_RUNNING" = "YES" ] && printf "running on port %s" "$PORT" || printf "stopped")

WATCHDOG_ICON=$([ "$WATCHDOG_RUNNING" = "YES" ] && printf "${GREEN}[ON]${NC}" || printf "${DIM}[--]${NC}")
WATCHDOG_TEXT=$([ "$WATCHDOG_RUNNING" = "YES" ] && printf "running (PID: %s)" "$WATCHDOG_PID" || printf "inactive")

IPV6_ICON=$([ "$IPV6_AVAILABLE" = "YES" ] && printf "${GREEN}[+]${NC}" || printf "${DIM}[-]${NC}")

# ============================================================
# [15] Display
# ============================================================
echo ""
echo "============================================================"
printf "  DNSCrypt Smart Filter %s\n" "$MODULE_VERSION"
printf "  Status: %s\n" "$OVERALL"
echo "============================================================"
echo ""

printf "%s--- Service Status ---%s\n" "$CYAN" "$NC"
printf "  %s DNS Engine:   %s\n" "$DNS_ICON" "$DNS_TEXT"
printf "  %s WebUI:        %s\n" "$WEBUI_ICON" "$WEBUI_TEXT"
printf "  %s Watchdog:     %s\n" "$WATCHDOG_ICON" "$WATCHDOG_TEXT"

if [ "$IS_DISABLED" = "YES" ]; then
    printf "  ${YELLOW}WARNING: Module disabled (disable file present)${NC}\n"
fi

if [ "$STATUS_FROM_FILE" != "UNKNOWN" ]; then
    EXPECTED=$([ "$DNS_RUNNING" = "YES" ] && echo "ON" || echo "OFF")
    if [ "$STATUS_FROM_FILE" != "$EXPECTED" ]; then
        printf "  ${DIM}(status file: %s - user intent; may differ from actual state)${NC}\n" "$STATUS_FROM_FILE"
    fi
fi

echo ""

printf "%s--- Links ---%s\n" "$CYAN" "$NC"
printf "  ${BOLD}WebUI:${NC}     ${BLUE}http://127.0.0.1:%s${NC}\n" "$PORT"
printf "  ${BOLD}Dashboard:${NC} ${BLUE}http://127.0.0.1:%s${NC}\n" "$DASHBOARD_PORT"
echo ""

printf "%s--- Profile & Memory ---%s\n" "$CYAN" "$NC"
printf "  Profile:       %s\n" "$PROFILE_NAME"
printf "  Memory limit:  %s\n" "$MEMORY_HINT"
printf "  ${DIM}Managed by:    main.go (Go runtime soft limit)${NC}\n"
echo ""

printf "%s--- Active Blocklist ---%s\n" "$CYAN" "$NC"
printf "  Entries:       %s\n" "$BLOCKLIST_COUNT"
printf "  File size:     %s bytes\n" "$BLOCKLIST_SIZE"
printf "  Last update:   %s\n" "$LAST_UPDATE"
printf "  ${DIM}Raw source:    %s entries / %s bytes${NC}\n" "$RAW_BLOCKLIST_COUNT" "$RAW_BLOCKLIST_SIZE"
echo ""

printf "%s--- Backup & Recovery ---%s\n" "$CYAN" "$NC"
case "$BACKUP_STATUS" in
    missing)
        printf "  ${YELLOW}⚠${NC}  Status:        ${YELLOW}no backup directory${NC}\n"
        printf "  ${DIM}Path:          %s${NC}\n" "$PERSISTENT_BACKUP"
        printf "  ${DIM}(created automatically on first boot / install)${NC}\n"
        ;;
    empty)
        printf "  ${YELLOW}⚠${NC}  Status:        ${YELLOW}directory exists but empty${NC}\n"
        printf "  ${DIM}Path:          %s${NC}\n" "$PERSISTENT_BACKUP"
        ;;
    ok)
        printf "  ${GREEN}✓${NC}  Snapshots:     %s\n" "$BACKUP_COUNT"
        printf "  Last backup:   %s ${DIM}(%s)${NC}\n" "$BACKUP_LAST_TIME" "$BACKUP_LAST_AGE"
        printf "  ${DIM}Latest:        %s${NC}\n" "$BACKUP_LAST_NAME"
        if [ -n "$BACKUP_LAST_STABLE" ]; then
            printf "  ${DIM}Last stable:   %s${NC}\n" "$BACKUP_LAST_STABLE"
        fi
        printf "  ${DIM}Path:          %s${NC}\n" "$PERSISTENT_BACKUP"
        ;;
esac

if [ "$BACKUP_TXN_COUNT" -gt 0 ]; then
    printf "  ${YELLOW}⚠${NC}  In-flight:     %s txn dir(s) — install in progress or interrupted\n" "$BACKUP_TXN_COUNT"
fi

if [ "$BACKUP_ORPHAN_COUNT" -gt 0 ]; then
    printf "  ${YELLOW}⚠${NC}  Orphans:       %s preserved orphan-txn dir(s)\n" "$BACKUP_ORPHAN_COUNT"
fi

if [ "$RECOVERY_MODE_ACTIVE" = "YES" ]; then
    printf "  ${YELLOW}⚠${NC}  Recovery mode: ${YELLOW}TRIGGER PRESENT${NC} — next install will restore\n"
fi

if [ -n "$PENDING_NOTIFY_CONTENT" ]; then
    printf "  ${CYAN}ℹ${NC}  Notification:  %s\n" "$PENDING_NOTIFY_CONTENT"
fi

echo ""

printf "%s--- Configuration ---%s\n" "$CYAN" "$NC"
printf "  Auto-DNS:      %s\n" "$([ "$AUTO_DNS" = "1" ] && printf "${GREEN}enabled${NC}" || printf "${DIM}disabled${NC}")"
printf "  Auto-WebUI:    %s\n" "$([ "$AUTO_WEBUI" = "1" ] && printf "${GREEN}enabled${NC}" || printf "${DIM}disabled${NC}")"
printf "  BIND_ADDR:     %s\n" "$BIND_ADDR"
printf "  IPv6:          %s %s\n" "$IPV6_ICON" "$([ "$IPV6_AVAILABLE" = "YES" ] && echo "available" || echo "unavailable")"
echo ""

printf "%s--- Information ---%s\n" "$CYAN" "$NC"
printf "  Version:       %s\n" "$MODULE_VERSION"
printf "  Root solution: %s\n" "$ROOT_SOLUTION"
printf "  Module path:   %s\n" "$MODDIR"
printf "  Runtime dir:   %s\n" "$ACTIVE_RUN_DIR"
printf "  ${DIM}functions.sh:  %s${NC}\n" \
    "$([ "$FUNCTIONS_LOADED" = "1" ] && echo "loaded" || echo "not loaded (warning)")"

if [ -n "$WEBUI_PID" ]; then
    printf "  PID WebUI:     %s\n" "$WEBUI_PID"
fi

if [ -n "$DNS_PID" ]; then
    printf "  PID DNS:       %s\n" "$DNS_PID"
fi

if [ "$WATCHDOG_RUNNING" = "YES" ]; then
    printf "  PID Watchdog:  %s\n" "$WATCHDOG_PID"
fi

echo ""

# ============================================================
# [16] Verbose extra section
# ============================================================
if [ "$VERBOSE_MODE" = "1" ]; then
    printf "%s--- Verbose: Ports & Environment ---%s\n" "$MAGENTA" "$NC"

    printf "  WebUI port:        %s\n" "$PORT"
    printf "  Dashboard port:    %s\n" "$DASHBOARD_PORT"
    printf "  Monitoring UI:     %s (reserved)\n" "$_MONITORING_UI_PORT"
    printf "  DNS engine port:   5354\n"
    printf "  DNS engine proto:  UDP/TCP\n"
    echo ""

    printf "  ${DIM}webui.conf:        %s${NC}\n" "$CONF_FILE"
    printf "  ${DIM}dnscrypt-proxy.toml: %s${NC}\n" "$TOML_FILE"
    printf "  ${DIM}selected_profile:  %s${NC}\n" "$SELECTED_FILE"
    printf "  ${DIM}blocklist.txt:     %s${NC}\n" "$BLOCKLIST_FILE"
    printf "  ${DIM}blocklist.raw:     %s${NC}\n" "$RAW_BLOCKLIST_FILE"
    printf "  ${DIM}backup dir:        %s${NC}\n" "$PERSISTENT_BACKUP"
    echo ""

    printf "  STATUS_FILE raw:   %s\n" "${STATUS_FROM_FILE:-<missing>}"
    echo ""

    if [ "$BACKUP_STATUS" = "ok" ]; then
        printf "%s--- Verbose: All Backups ---%s\n" "$MAGENTA" "$NC"
        while IFS= read -r _snap; do
            [ -z "$_snap" ] && continue
            _file_count=0
            for _chk in "$PERSISTENT_BACKUP/$_snap"/*.conf "$PERSISTENT_BACKUP/$_snap"/*.toml "$PERSISTENT_BACKUP/$_snap"/*.txt; do
                [ -f "$_chk" ] && _file_count=$((_file_count + 1))
            done
            [ -z "$_file_count" ] && _file_count=0
            _snap_size=$(du -sh "$PERSISTENT_BACKUP/$_snap" 2>/dev/null | cut -f1)
            _snap_time=$(date -r "$PERSISTENT_BACKUP/$_snap" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "?")
            printf "  %-30s ${DIM}%s files, %s, %s${NC}\n" "$_snap" "$_file_count" "$_snap_size" "$_snap_time"
        done <<EOF
$(_list_snapshots)
EOF
        echo ""
    fi

    if [ "$BACKUP_TXN_COUNT" -gt 0 ]; then
        printf "%s--- Verbose: In-flight Transactions ---%s\n" "$MAGENTA" "$NC"
        (cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d txn-*/ 2>/dev/null | \
            sed 's:/$::' | \
            while IFS= read -r _txn; do
                [ -z "$_txn" ] && continue
                _state=$(cat "$PERSISTENT_BACKUP/$_txn/.state" 2>/dev/null | tr -d '\r\n ')
                _pid=$(cat "$PERSISTENT_BACKUP/$_txn/.pid" 2>/dev/null | tr -d '\r\n ')
                printf "  %-30s ${DIM}state=%s pid=%s${NC}\n" "$_txn" "${_state:-none}" "${_pid:-none}"
            done)
        echo ""
    fi

    if [ "$BACKUP_ORPHAN_COUNT" -gt 0 ]; then
        printf "%s--- Verbose: Orphan Transactions ---%s\n" "$MAGENTA" "$NC"
        (cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d orphan-txn-*/ 2>/dev/null | \
            sed 's:/$::' | \
            while IFS= read -r _orphan; do
                [ -z "$_orphan" ] && continue
                _orphan_size=$(du -sh "$PERSISTENT_BACKUP/$_orphan" 2>/dev/null | cut -f1)
                _orphan_time=$(date -r "$PERSISTENT_BACKUP/$_orphan" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "?")
                printf "  %-30s ${DIM}%s, %s${NC}\n" "$_orphan" "$_orphan_size" "$_orphan_time"
            done)
        echo ""
    fi

    if [ "$RECOVERY_MODE_ACTIVE" = "YES" ]; then
        printf "%s--- Verbose: Recovery Triggers ---%s\n" "$MAGENTA" "$NC"
        [ -f "$RECOVERY_TRIGGER_1" ] && printf "  ${YELLOW}•${NC} %s\n" "$RECOVERY_TRIGGER_1"
        [ -f "$RECOVERY_TRIGGER_2" ] && printf "  ${YELLOW}•${NC} %s\n" "$RECOVERY_TRIGGER_2"
        echo ""
    fi
fi

# ============================================================
# [17] Help hints
# ============================================================
if [ "$IS_DISABLED" = "YES" ]; then
    printf "%sWARNING: Module is disabled.${NC}\n" "$YELLOW"
    printf "   ${DIM}To enable: remove the file %s/disable${NC}\n" "$MODDIR"
    echo ""
elif [ "$DNS_RUNNING" = "NO" ] && [ "$WEBUI_RUNNING" = "NO" ]; then
    printf "%sHINT: To start the service:${NC}\n" "$YELLOW"
    printf "   ${DIM}1. Open Magisk/KernelSU${NC}\n"
    printf "   ${DIM}2. Tap Action on the module${NC}\n"
    printf "   ${DIM}3. Or from WebUI: press \"Start Service\"${NC}\n"
    echo ""
elif [ "$DNS_RUNNING" = "NO" ] || [ "$WEBUI_RUNNING" = "NO" ]; then
    printf "%sHINT: To restore full state:${NC}\n" "$YELLOW"
    printf "   ${DIM}Run the module from Magisk (Action button)${NC}\n"
    echo ""
fi

if [ "$VERBOSE_MODE" != "1" ]; then
    printf "${DIM}Tip: run 'status.sh --diagnose' for a full report (backups + health)${NC}\n"
    echo ""
fi

# ============================================================
# [18] Exit code
# ============================================================
# Mirrors the state model used by --check, --json, and --short.
if [ "$IS_DISABLED" = "YES" ]; then
    exit 3
elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ]; then
    exit 0
elif [ "$DNS_RUNNING" = "NO" ] && [ "$WEBUI_RUNNING" = "NO" ]; then
    exit 1
else
    exit 2
fi