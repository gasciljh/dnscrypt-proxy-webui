#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — action.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-19
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Magisk / KernelSU / APatch "Action" button handler.
#
# Modes:
#   action.sh                Start WebUI + open browser
#   action.sh --restart      Force restart WebUI
#   action.sh --status       Show WebUI status only
#   action.sh --check        Comprehensive status
#   action.sh --diagnose     Full diagnostic report
#   action.sh --backup       Trigger an immediate backup
#   action.sh --help         Show help
#   action.sh --version      Show version
#
# Exit codes:
#   0 = success
#   1 = error (startup failed)
#   2 = module disabled
#   3 = backup failed (--backup only)
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path + version
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

get_version() {
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

VERSION="$(get_version)"

case "${1:-}" in
    --version)
        echo "$0: $VERSION"
        exit 0
        ;;
esac

# ============================================================
# [2] Default paths
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
WEBUI_PID_FILE="/data/local/tmp/webui.pid"
WATCHDOG_PID_FILE="/data/local/tmp/watchdog.pid"
STATUS_FILE="/data/local/tmp/dnscrypt.status"
CRED_FILE="/data/local/tmp/dnscrypt_credentials.txt"

SELECTED_PROFILE_FILE="$MODDIR/proxy/selected_profile.txt"

PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"
LAST_AUTO_BACKUP_MARKER="$PERSISTENT_BACKUP/.last_auto_backup"
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

RECOVERY_TRIGGER_1="$MODDIR/recovery"
RECOVERY_TRIGGER_2="/data/adb/dnscrypt-recovery"

_MONITORING_UI_PORT=""

# ============================================================
# [3] Log prefix + fallback log_msg
# ============================================================
LOG_PREFIX="[action]"

log_msg_fallback() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [action] $1" >> "$LOG_FILE" 2>/dev/null
}

# ============================================================
# [4] Load functions.sh (which sources boot-mini.sh)
# ============================================================
FUNCTIONS_LOADED=0
if [ -f "$MODDIR/functions.sh" ]; then
    # shellcheck disable=SC1090
    . "$MODDIR/functions.sh" 2>/dev/null

    if command -v is_port_open >/dev/null 2>&1 \
       && command -v get_webui_port >/dev/null 2>&1; then
        FUNCTIONS_LOADED=1

        if command -v init_runtime_paths >/dev/null 2>&1; then
            init_runtime_paths
        fi
    fi
fi

LOG_PREFIX="[action]"

_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"

# ============================================================
# [5] Minimal inline fallbacks
# ============================================================
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

# --- Fallback: is_port_open ---
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

# --- Fallback: read_conf ---
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

# --- Fallback: get_port with Port Guard ---
_inline_get_port() {
    local conf="$1"
    local val
    val=$(_inline_read_conf "$conf" "PORT" "9090")

    if ! echo "$val" | grep -qE '^[0-9]+$'; then
        printf "9090"
        return 0
    fi

    local val_clean
    val_clean=$(printf '%s' "$val" | sed 's/^0*//')
    [ -z "$val_clean" ] && val_clean="0"

    if [ "$val_clean" -ge 1 ] && [ "$val_clean" -le 65535 ]; then
        if [ "$val_clean" = "$_MONITORING_UI_PORT" ]; then
            log_msg_fallback "WARNING: _inline_get_port: PORT=$val_clean conflicts with monitoring_ui — falling back to 9090"
            printf "9090"
            return 0
        fi
        printf "%s" "$val_clean"
        return 0
    fi
    printf "9090"
}

# --- Fallback: start_webui ---
_inline_start_webui() {
    local bin="$1"
    local port="$2"

    log_msg_fallback "Starting WebUI (inline, port: $port)"

    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null

        local _kill_wait=0
        while [ "$_kill_wait" -lt 30 ]; do
            if ! pgrep -x dnscrypt-webui >/dev/null 2>&1; then
                break
            fi
            sleep 0.1
            _kill_wait=$((_kill_wait + 1))
        done
    fi
    rm -f "$WEBUI_PID_FILE" 2>/dev/null

    local _port_wait=0
    while [ "$_port_wait" -lt 30 ]; do
        if ! _inline_is_port_open "$port" tcp; then
            break
        fi
        sleep 0.1
        _port_wait=$((_port_wait + 1))
    done

    export HOME=/data/local/tmp

    if command -v setsid >/dev/null 2>&1; then
        setsid env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q setsid; then
        busybox setsid env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    else
        nohup env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    fi

    sleep 1
    local _pid=""
    _pid=$(pgrep -x "dnscrypt-webui" 2>/dev/null | head -n1)
    if [ -n "$_pid" ]; then
        printf "%s\n" "$_pid" > "${WEBUI_PID_FILE}.tmp" 2>/dev/null
        mv -f "${WEBUI_PID_FILE}.tmp" "$WEBUI_PID_FILE" 2>/dev/null
    fi

    local _i=0
    while [ "$_i" -lt 20 ]; do
        if _inline_is_port_open "$port" tcp; then
            return 0
        fi
        sleep 1
        _i=$((_i + 1))
    done
    return 1
}

# --- Fallback: list_snapshots + backup_summary ---
_inline_list_snapshots() {
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
            # PREMIUM FIX: Extract timestamp from directory name
            _ts=$(printf "%s" "$_d" | cut -d'-' -f1,2)
            case "$_ts" in ''|*[!0-9-]*) _ts="00000000-000000" ;; esac
            printf '%s %s\n' "$_ts" "$_d"
        done | LC_ALL=C sort -r -k1,1 | awk '{print $2}'
    )

    [ -z "$list" ] && return 0

    if [ "$limit" -gt 0 ] 2>/dev/null; then
        printf '%s\n' "$list" | head -n "$limit"
    else
        printf '%s\n' "$list"
    fi
}

_inline_backup_summary() {
    [ -d "$PERSISTENT_BACKUP" ] || {
        printf "not initialized"
        return
    }

    local _list
    _list=$(_inline_list_snapshots)

    if [ -z "$_list" ]; then
        printf "no snapshots yet"
        return
    fi

    local count
    count=$(printf '%s\n' "$_list" | wc -l | tr -d ' ')

    local newest
    newest=$(printf '%s\n' "$_list" | head -n1)

    # PREMIUM FIX: Extract timestamp from directory name instead of ModTime
    local _ts
    _ts=$(printf "%s" "$newest" | cut -d'-' -f1,2)
    local date_str="${_ts:0:4}-${_ts:4:2}-${_ts:6:2}"
    local time_str="${_ts:9:2}:${_ts:11:2}"
    printf "%s snapshot(s), latest %s %s UTC" "$count" "$date_str" "$time_str"
}

# ============================================================
# [6] Unified wrappers
# ============================================================
if [ "$FUNCTIONS_LOADED" = "1" ]; then
    is_port_listening()  { is_port_open "$1" "${2:-tcp}"; }
    get_port()           { get_webui_port "$1"; }
    act_log()            { log_msg "$1"; }

    if command -v get_profile_memory_hint >/dev/null 2>&1; then
        get_mem_hint()   { get_profile_memory_hint; }
    else
        get_mem_hint()   { printf "unknown"; }
    fi

    if command -v backup_user_files >/dev/null 2>&1; then
        do_backup_now()  { backup_user_files "$MODDIR/proxy"; }
    else
        do_backup_now()  { return 1; }
    fi

    if command -v rotate_backups >/dev/null 2>&1; then
        do_rotate_backups() { rotate_backups "${1:-21}"; }
    else
        do_rotate_backups() { return 0; }
    fi

    if command -v cleanup_orphans >/dev/null 2>&1; then
        do_cleanup_orphans() { cleanup_orphans; }
    else
        do_cleanup_orphans() { return 0; }
    fi

    if command -v start_native_webui >/dev/null 2>&1; then
        do_start_webui() { start_native_webui "$1" "$2"; }
    else
        do_start_webui() { _inline_start_webui "$1" "$2"; }
    fi

    if command -v is_dnscrypt_running >/dev/null 2>&1; then
        do_is_dns_running() { is_dnscrypt_running; }
    else
        do_is_dns_running() { pgrep -x dnscrypt-proxy >/dev/null 2>&1; }
    fi

    backup_summary()     { _inline_backup_summary; }
else
    _FB_RUN_DIR=$(_fallback_get_run_dir)
    WEBUI_PID_FILE="$_FB_RUN_DIR/webui.pid"
    WATCHDOG_PID_FILE="$_FB_RUN_DIR/watchdog.pid"
    STATUS_FILE="$_FB_RUN_DIR/dnscrypt.status"

    is_port_listening()  { _inline_is_port_open "$1" "${2:-tcp}"; }
    get_port()           { _inline_get_port "$1"; }
    read_conf()          { _inline_read_conf "$1" "$2" "$3"; }
    act_log()            { log_msg_fallback "$1"; }
    get_mem_hint()       { printf "unknown (functions.sh not loaded)"; }
    do_backup_now()      { return 1; }
    do_rotate_backups()  { return 0; }
    do_cleanup_orphans() { return 0; }
    do_start_webui()     { _inline_start_webui "$1" "$2"; }
    do_is_dns_running()  { pgrep -x dnscrypt-proxy >/dev/null 2>&1; }
    backup_summary()     { _inline_backup_summary; }
fi

# ============================================================
# [7] show_help
# ============================================================
show_help() {
    cat << EOF
DNSCrypt Smart Filter – action.sh ${VERSION}

Usage:
  action.sh                Start WebUI and open browser
  action.sh --restart      Force restart WebUI
  action.sh --status       Show WebUI status only
  action.sh --check        Comprehensive status
  action.sh --diagnose     Full diagnostic report
  action.sh --backup       Trigger an immediate manual backup
  action.sh --help         Show this help

Exit codes:
  0 = success
  1 = error (startup failed)
  2 = module disabled
  3 = backup failed (--backup only)

EOF
    exit 0
}

# ============================================================
# [8] Parse command-line arguments
# ============================================================
FORCE_RESTART=0
STATUS_ONLY=0
CHECK_MODE=0
DIAGNOSE_MODE=0
BACKUP_MODE=0

for arg in "$@"; do
    case "$arg" in
        --restart)   FORCE_RESTART=1 ;;
        --status)    STATUS_ONLY=1 ;;
        --check)     CHECK_MODE=1 ;;
        --diagnose)  DIAGNOSE_MODE=1 ;;
        --backup)    BACKUP_MODE=1 ;;
        --help|-h)   show_help ;;
        *)
            echo "❌ Unknown option: $arg"
            echo "Use --help for assistance"
            exit 1
            ;;
    esac
done

# ============================================================
# [9] Configure paths
# ============================================================
BIN_DIR="$MODDIR/proxy"
WEBUI="$BIN_DIR/dnscrypt-webui"
CONF_FILE="$BIN_DIR/webui.conf"
TOML_FILE="$BIN_DIR/dnscrypt-proxy.toml"

PORT=$(get_port "$CONF_FILE" 2>/dev/null)
[ -z "$PORT" ] && PORT="9090"

# ============================================================
# [10] Path 1: status only (--status)
# ============================================================
if [ "$STATUS_ONLY" = "1" ]; then
    if is_port_listening "$PORT" tcp; then
        printf "✅ WebUI is RUNNING on port %s\n" "$PORT"
        exit 0
    else
        printf "❌ WebUI is NOT running on port %s\n" "$PORT"
        exit 1
    fi
fi

# ============================================================
# [11] Path 2: diagnose mode (--diagnose)
# ============================================================
if [ "$DIAGNOSE_MODE" = "1" ]; then
    STATUS_SCRIPT="$MODDIR/status.sh"

    if [ -f "$STATUS_SCRIPT" ]; then
        if [ ! -x "$STATUS_SCRIPT" ]; then
            chmod 0755 "$STATUS_SCRIPT" 2>/dev/null || true
        fi

        if [ -x "$STATUS_SCRIPT" ]; then
            exec "$STATUS_SCRIPT" --diagnose
        else
            exec sh "$STATUS_SCRIPT" --diagnose
        fi
    else
        echo "⚠️ status.sh not found — falling back to --check mode"
        echo "   Expected at: $STATUS_SCRIPT"
        echo ""
        CHECK_MODE=1
    fi
fi

# ============================================================
# [12] Path 3: backup mode (--backup)
# ============================================================
if [ "$BACKUP_MODE" = "1" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║  💾 DNSCrypt – Manual Backup                 ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""

    if [ "$FUNCTIONS_LOADED" != "1" ]; then
        echo "❌ Cannot run --backup: functions.sh is not loaded."
        echo "   The backup layer is unavailable in this state."
        echo "   Reinstall the module or run:"
        echo "     su -c \"sh $MODDIR/status.sh --diagnose\""
        echo ""
        act_log "--backup failed: functions.sh not loaded"
        exit 3
    fi

    if [ ! -d "$BIN_DIR" ]; then
        echo "❌ Module directory not found: $BIN_DIR"
        echo "   Is the module installed?"
        exit 3
    fi

    echo "  Source: $BIN_DIR"
    echo "  Target: $PERSISTENT_BACKUP"
    echo ""

    if do_backup_now; then
        do_rotate_backups 21 >/dev/null 2>&1 || true

        echo ""
        echo "  ✅ Backup completed successfully."
        echo ""
        echo "  Current backup state:"
        echo "    $(backup_summary)"
        echo ""
        act_log "--backup completed successfully"
        exit 0
    else
        echo ""
        echo "  ❌ Backup failed. See message above."
        act_log "--backup failed"
        exit 3
    fi
fi

# ============================================================
# [13] Path 4: comprehensive check (--check)
# ============================================================
if [ "$CHECK_MODE" = "1" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    printf "║  🔍 DNSCrypt %-8s – System Check     ║\n" "$VERSION"
    echo "╚══════════════════════════════════════════════╝"
    echo ""

    echo "─── Service Status ────────────────────────"
    if is_port_listening "$PORT" tcp; then
        printf "  🟢 WebUI    : Running on port %s\n" "$PORT"
    else
        printf "  🔴 WebUI    : Stopped\n"
    fi

    if do_is_dns_running; then
        printf "  🟢 DNS      : Running on 5354/UDP\n"
    else
        printf "  🔴 DNS      : Stopped\n"
    fi

    if [ -f "$WATCHDOG_PID_FILE" ]; then
        wd_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$wd_pid" ] && kill -0 "$wd_pid" 2>/dev/null; then
            wd_comm=$(cat "/proc/$wd_pid/comm" 2>/dev/null)
            case "$wd_comm" in
                sh|ash|bash|mksh|busybox|*sh)
                    printf "  🐕 Watchdog : Running (PID: %s)\n" "$wd_pid"
                    ;;
                *)
                    printf "  🐕 Watchdog : PID %s was reused\n" "$wd_pid"
                    ;;
            esac
        fi
    else
        printf "  🐕 Watchdog : inactive\n"
    fi
    echo ""

    echo "─── Runtime ────────────────────────────────"
    if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ]; then
        printf "  📁 run/     : %s\n" "$RUN_DIR_ACTIVE"
    else
        printf "  📁 run/     : %s\n" "$(dirname "$WEBUI_PID_FILE")"
    fi

    if [ -f "$STATUS_FILE" ]; then
        st=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
        printf "  📄 Intent   : %s (user intent)\n" "${st:-UNKNOWN}"
    else
        printf "  📄 Intent   : (no file)\n"
    fi

    printf "  🏷️  Version  : %s\n" "$VERSION"
    if [ "$FUNCTIONS_LOADED" = "1" ]; then
        printf "  📚 functions: ✅ loaded\n"
    else
        printf "  📚 functions: ⚠️ not loaded (fallback)\n"
    fi
    echo ""

    echo "─── Configuration ──────────────────────────"
    DASH_PORT=$(read_conf "$CONF_FILE" "DASHBOARD_PORT" "9091")
    printf "  🌐 WebUI port    : %s\n" "$PORT"
    printf "  📈 Dashboard port: %s\n" "$DASH_PORT"

    AUTO_DNS=$(read_conf "$CONF_FILE" "AUTO_RESTART_DNS" "1")
    AUTO_WEBUI=$(read_conf "$CONF_FILE" "AUTO_RESTART_WEBUI" "1")
    printf "  🔄 Auto-DNS      : %s\n" "$([ "$AUTO_DNS" = "1" ] && echo "enabled" || echo "disabled")"
    printf "  🔄 Auto-WebUI    : %s\n" "$([ "$AUTO_WEBUI" = "1" ] && echo "enabled" || echo "disabled")"

    BIND_ADDR=$(read_conf "$CONF_FILE" "BIND_ADDR" "127.0.0.1")
    printf "  🔌 BIND_ADDR     : %s\n" "$BIND_ADDR"
    echo ""

    echo "─── Profile & Memory ───────────────────────"
    ACTIVE_PROFILE="pro"
    if [ -f "$SELECTED_PROFILE_FILE" ]; then
        _ap=$(cat "$SELECTED_PROFILE_FILE" 2>/dev/null | tr -d '\r\n ')
        case "$_ap" in
            light|normal|pro|proplus|ultimate) ACTIVE_PROFILE="$_ap" ;;
        esac
    fi

    MEMORY_HINT=$(get_mem_hint 2>/dev/null)
    [ -z "$MEMORY_HINT" ] && MEMORY_HINT="unknown"

    printf "  📋 Profile       : %s\n" "$ACTIVE_PROFILE"
    printf "  🧠 Memory limit  : %s\n" "$MEMORY_HINT"
    printf "  ℹ️  Managed by    : main.go (Go runtime soft limit)\n"
    echo ""

    echo "─── Backup & Recovery ──────────────────────"

    _snap_count=0
    if [ -d "$PERSISTENT_BACKUP" ]; then
        _snap_count=$(_inline_list_snapshots | wc -l | tr -d ' ')
        [ -z "$_snap_count" ] && _snap_count=0
    fi

    _txn_count=0
    if [ -d "$PERSISTENT_BACKUP" ]; then
        _txn_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d txn-*/ 2>/dev/null | \
            wc -l | tr -d ' ')
        case "$_txn_count" in ''|*[!0-9]*) _txn_count=0 ;; esac
    fi

    _orphan_count=0
    if [ -d "$PERSISTENT_BACKUP" ]; then
        _orphan_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d orphan-txn-*/ 2>/dev/null | \
            wc -l | tr -d ' ')
        case "$_orphan_count" in ''|*[!0-9]*) _orphan_count=0 ;; esac
    fi

    printf "  💾 State         : %s\n" "$(backup_summary)"
    printf "  📁 Path          : %s\n" "$PERSISTENT_BACKUP"
    printf "  📸 Snapshots     : %s\n" "$_snap_count"

    if [ "$_txn_count" -gt 0 ]; then
        printf "  ⏳ In-flight txn : %s (install in progress or interrupted)\n" "$_txn_count"
    fi

    if [ "$_orphan_count" -gt 0 ]; then
        printf "  🗃️  Orphan txn    : %s (preserved from interrupted install)\n" "$_orphan_count"
    fi

    if [ -f "$LAST_STABLE_FILE" ]; then
        _ls=$(cat "$LAST_STABLE_FILE" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$_ls" ]; then
            printf "  🎯 Last stable   : %s\n" "$_ls"
        fi
    fi

    if [ -f "$LAST_AUTO_BACKUP_MARKER" ]; then
        _auto_mtime=$(stat -c %Y "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
            || _auto_mtime=$(stat -f %m "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
            || _auto_mtime=0
        if echo "$_auto_mtime" | grep -qE '^[0-9]+$' && [ "$_auto_mtime" -gt 0 ]; then
            _auto_now=$(date +%s 2>/dev/null)
            case "$_auto_now" in
                ''|*[!0-9]*) _auto_now=0 ;;
            esac
            if [ "$_auto_now" -gt 0 ]; then
                _auto_age=$((_auto_now - _auto_mtime))
                if [ "$_auto_age" -lt 60 ]; then
                    _auto_age_str="${_auto_age}s ago"
                elif [ "$_auto_age" -lt 3600 ]; then
                    _auto_age_str="$((_auto_age / 60))m ago"
                elif [ "$_auto_age" -lt 86400 ]; then
                    _auto_age_str="$((_auto_age / 3600))h ago"
                else
                    _auto_age_str="$((_auto_age / 86400))d ago"
                fi
                printf "  🔄 Auto-backup   : %s\n" "$_auto_age_str"
            fi
        fi
    fi

    if [ -f "$RECOVERY_TRIGGER_1" ] || [ -f "$RECOVERY_TRIGGER_2" ]; then
        printf "  🚨 Recovery mode : TRIGGER PRESENT — next install will restore\n"
    fi

    if [ -f "$PENDING_NOTIFY_FILE" ]; then
        _pn=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$_pn" ]; then
            printf "  📢 Notification  : %s\n" "$_pn"
        fi
    fi

    printf "  ℹ️  Recovery      : touch %s/recovery && reboot\n" "$MODDIR"
    echo ""

    if [ -f "$MODDIR/disable" ]; then
        printf "  ⚠️  Module        : DISABLED (remove 'disable' file to enable)\n"
        echo ""
    fi

    if [ -f "$CRED_FILE" ]; then
        printf "  🔐 Credentials   : available\n"
    else
        printf "  ⚠️  Credentials   : missing\n"
    fi

    echo ""
    echo "  🌐 Open: http://127.0.0.1:$PORT"
    echo "  ℹ️  Full diagnostic report: action.sh --diagnose"
    echo ""
    exit 0
fi

# ============================================================
# [14] Refuse to start if module is disabled
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    act_log "Module is disabled, cannot start WebUI"
    printf "⚠️  Module is disabled.\n"
    printf "Enable it first from Magisk/KernelSU.\n"
    exit 2
fi

# ============================================================
# [15] Verify WebUI binary exists
# ============================================================
if [ ! -f "$WEBUI" ]; then
    act_log "WebUI binary not found at $WEBUI"
    printf "❌ WebUI binary not found.\n"
    printf "Try reinstalling the module.\n"
    exit 1
fi

# ============================================================
# [16] Start WebUI (if needed)
# ============================================================
STARTED_NOW=0

if [ "$FORCE_RESTART" = "1" ]; then
    act_log "--restart flag detected, forcing WebUI restart"
    printf "🔄 Restarting WebUI...\n"
    STARTED_NOW=1
elif ! is_port_listening "$PORT" tcp; then
    act_log "WebUI not running, starting..."
    printf "▶️  Starting WebUI...\n"
    STARTED_NOW=1
fi

if [ "$STARTED_NOW" = "1" ]; then
    if [ "$FUNCTIONS_LOADED" = "1" ]; then
        do_cleanup_orphans 2>/dev/null

        if ! do_start_webui "$WEBUI" "$PORT"; then
            act_log "start_native_webui returned failure"
            printf "❌ Failed to start WebUI.\n"
            printf "Check /data/local/tmp/dnscrypt_main.log\n"
            exit 1
        fi
    else
        act_log "functions.sh unavailable, using inline fallback"

        if ! _inline_start_webui "$WEBUI" "$PORT"; then
            act_log "fallback start failed (timeout)"
            printf "❌ WebUI failed to start (timeout).\n"
            exit 1
        fi
    fi

    act_log "WebUI started on port $PORT"
    printf "✅ WebUI started on port %s\n" "$PORT"
else
    act_log "WebUI already running on port $PORT"
    printf "ℹ️  WebUI is already running on port %s\n" "$PORT"
fi

if [ "$STARTED_NOW" = "1" ]; then
    sleep 1
fi

# ============================================================
# [17] Open browser (5 fallback methods + timeout)
# ============================================================
URL="http://127.0.0.1:$PORT"

act_log "Opening browser at $URL"
printf "🌐 Opening: %s\n" "$URL"

# --- Try 1: am start --user 0 -W (standard, blocking) ---
if timeout 5 am start --user 0 -W \
    -a android.intent.action.VIEW \
    -d "$URL" \
    --activity-clear-top \
    >/dev/null 2>&1; then
    act_log "Browser opened via am start (standard)"
    printf "✅ Browser opened.\n"
    exit 0
fi

act_log "Standard am start failed, trying alternative methods..."

# --- Try 2: resolve-activity then explicit start ---
DEFAULT_BROWSER=$(cmd package resolve-activity \
    --brief \
    -a android.intent.action.VIEW \
    -d "http://example.com" 2>/dev/null \
    | tail -n 1)

if [ -n "$DEFAULT_BROWSER" ] && [ "$DEFAULT_BROWSER" != "No activity found" ]; then
    if timeout 5 am start --user 0 -W \
        -a android.intent.action.VIEW \
        -d "$URL" \
        -n "$DEFAULT_BROWSER" \
        >/dev/null 2>&1; then
        act_log "Browser opened via explicit package: $DEFAULT_BROWSER"
        printf "✅ Browser opened.\n"
        exit 0
    fi
fi

# --- Try 3: am start without --user ---
if timeout 5 am start \
    -a android.intent.action.VIEW \
    -d "$URL" \
    >/dev/null 2>&1; then
    act_log "Browser opened via am start (no --user)"
    printf "✅ Browser opened.\n"
    exit 0
fi

# --- Try 4: am start --activity-new-task ---
if timeout 5 am start \
    --activity-new-task \
    -a android.intent.action.VIEW \
    -d "$URL" \
    >/dev/null 2>&1; then
    act_log "Browser opened via am start (new task)"
    printf "✅ Browser opened.\n"
    exit 0
fi

# --- Try 5: fire-and-forget ---
(
    timeout 5 am start \
        -a android.intent.action.VIEW \
        -d "$URL" \
        >/dev/null 2>&1
) &

sleep 0.3

act_log "Browser opened via am start (async, no -W)"
printf "✅ Browser opened (async).\n"
exit 0