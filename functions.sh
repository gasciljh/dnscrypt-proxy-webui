#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — functions.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Layer-1 orchestrator. Sources boot-mini.sh (which loads all
# of lib/) and exposes runtime paths plus the handful of
# state-machine functions that are not covered by lib/.
#
# Public interface (beyond boot-mini.sh + lib/*):
#   init_runtime_paths
#   run_file <name>
#   ensure_run_dir
#   write_progress <percent> <msg>
#   get_auto_restart_dns     [conf]
#   get_auto_restart_webui   [conf]
#   get_watchdog_token
#   is_dnscrypt_running
#   is_webui_running         [port]
#   cleanup_proxy
#   cleanup_webui
#   cleanup_orphans
#   aggressive_cleanup
#   start_native_webui <bin> <port>
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module root + load boot-mini.sh (which loads lib/)
# ============================================================
if [ -z "${MODDIR:-}" ]; then
    _fn_dir="${0%/*}"
    case "$_fn_dir" in
        /*/proxy) MODDIR="${_fn_dir%/proxy}" ;;
        /system/*|/vendor/*|/sbin/*|/bin/*|/usr/*)
                  MODDIR="/data/adb/modules/dnscrypt-proxy-webui" ;;
        /*)       MODDIR="$_fn_dir" ;;
        *)        MODDIR="/data/adb/modules/dnscrypt-proxy-webui" ;;
    esac
    unset _fn_dir
fi

_BM_PATH=""
for _cand in "$MODDIR/boot-mini.sh" "$MODDIR/proxy/boot-mini.sh"; do
    [ -f "$_cand" ] && { _BM_PATH="$_cand"; break; }
done

if [ -z "$_BM_PATH" ]; then
    echo "functions.sh: boot-mini.sh not found" >&2
    return 1 2>/dev/null || exit 1
fi

. "$_BM_PATH"
unset _BM_PATH _cand

# ============================================================
# [2] Module paths (constants + derived)
# ============================================================
if command -v init_module_paths >/dev/null 2>&1; then
    init_module_paths "$MODDIR" 2>/dev/null || true
fi

BIN_DIR="${BIN_DIR:-$MODDIR/proxy}"
TOML_FILE="${TOML_FILE:-$BIN_DIR/dnscrypt-proxy.toml}"
WEBUI_CONF="${WEBUI_CONF:-$BIN_DIR/webui.conf}"
SELECTED_PROFILE_FILE="${SELECTED_PROFILE_FILE:-$BIN_DIR/selected_profile.txt}"
WEB_DIR="${WEB_DIR:-$MODDIR/web}"
RUN_DIR="${RUN_DIR:-$BIN_DIR/run}"

# ============================================================
# [3] Runtime paths
# ============================================================
init_runtime_paths() {
    local rd
    rd=$(get_run_dir)

    LOG_FILE="${LOG_FILE:-/data/local/tmp/dnscrypt_main.log}"

    if [ "$rd" != "/data/local/tmp" ]; then
        PROGRESS_FILE="$rd/update_progress.txt"
    else
        PROGRESS_FILE="/data/local/tmp/update_progress.txt"
    fi

    STATUS_FILE="$rd/dnscrypt.status"
    PID_FILE="$rd/dnscrypt.pid"
    WEBUI_PID_FILE="$rd/webui.pid"
    WATCHDOG_PID_FILE="$rd/watchdog.pid"
    WATCHDOG_TOKEN_FILE="$rd/.watchdog_token"

    export LOG_FILE PROGRESS_FILE STATUS_FILE PID_FILE
    export WEBUI_PID_FILE WATCHDOG_PID_FILE WATCHDOG_TOKEN_FILE
    export RUN_DIR_ACTIVE="$rd"
}

init_runtime_paths

# ============================================================
# [4] Path helpers
# ============================================================
run_file() {
    local base="${RUN_DIR_ACTIVE:-$(get_run_dir)}"
    printf '%s/%s' "$base" "$1"
}

ensure_run_dir() {
    local rd
    rd=$(get_run_dir)
    [ "$rd" = "/data/local/tmp" ] && return 1
    chown 0:0 "$rd" 2>/dev/null
    return 0
}

# ============================================================
# [5] Progress file (SSE feeder)
# ============================================================
write_progress() {
    local percent="$1"
    local msg="$2"

    case "$percent" in ''|*[!0-9]*) percent=0 ;; esac
    [ "$percent" -gt 100 ] && percent=100
    [ "$percent" -lt 0 ] && percent=0

    if [ ${#msg} -gt 200 ]; then
        msg=$(printf '%s' "$msg" | cut -c1-200)
    fi
    msg=$(printf '%s' "$msg" | tr '|' '/')

    [ -z "${PROGRESS_FILE:-}" ] && return 1

    printf '%d|%s' "$percent" "$msg" > "${PROGRESS_FILE}.tmp.$$" 2>/dev/null
    mv -f "${PROGRESS_FILE}.tmp.$$" "$PROGRESS_FILE" 2>/dev/null
    return 0
}

# ============================================================
# [6] Config readers (non-port values)
# ============================================================
get_auto_restart_dns() {
    local conf="${1:-$WEBUI_CONF}"
    local val
    val=$(read_conf "$conf" "AUTO_RESTART_DNS" "1")
    case "$val" in 0|1) printf '%s' "$val" ;; *) printf '1' ;; esac
}

get_auto_restart_webui() {
    local conf="${1:-$WEBUI_CONF}"
    local val
    val=$(read_conf "$conf" "AUTO_RESTART_WEBUI" "1")
    case "$val" in 0|1) printf '%s' "$val" ;; *) printf '1' ;; esac
}

# ============================================================
# [7] Watchdog token
# ============================================================
get_watchdog_token() {
    get_watchdog_token_safe
}

# ============================================================
# [8] State checks
# ============================================================
is_dnscrypt_running() {
    local pid_file pid comm
    pid_file=$(run_file dnscrypt.pid)

    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file" 2>/dev/null | tr -d '\r\n ')
        if pid_is_alive "$pid"; then
            comm=$(cat "/proc/$pid/comm" 2>/dev/null | tr -d '\r\n ')
            if [ "$comm" = "dnscrypt-proxy" ] && is_port_open "$DNS_ENGINE_PORT" udp; then
                return 0
            fi
        fi
    fi

    if list_pids_by_comm "dnscrypt-proxy" >/dev/null 2>&1; then
        is_port_open "$DNS_ENGINE_PORT" udp && return 0
    fi
    return 1
}

is_webui_running() {
    local port="${1:-$(get_webui_port "$WEBUI_CONF")}"
    is_port_open "$port" tcp
}

# ============================================================
# [9] Cleanup functions (delegate to lib/process.sh)
# ============================================================
cleanup_proxy() {
    log_msg "🧹 cleanup_proxy"
    local _start_ts
    _start_ts=$(date +%s)

    if ! kill_by_comm "dnscrypt-proxy" 30; then
        log_msg "⚠️ dnscrypt-proxy survived 3s (D-state?)"
    fi

    if command -v wait_port_free >/dev/null 2>&1; then
        if ! wait_port_free "$DNS_ENGINE_PORT" udp 30; then
            log_msg "⚠️ Port $DNS_ENGINE_PORT/udp busy after 3s (TIME_WAIT) — proceeding"
        fi
        if ! wait_port_free "$DNS_ENGINE_PORT" tcp 30; then
            log_msg "⚠️ Port $DNS_ENGINE_PORT/tcp busy after 3s (TIME_WAIT) — proceeding"
        fi
    fi

    remove_pid_file "$(run_file dnscrypt.pid)"
    rm -f /data/local/tmp/dnscrypt.pid 2>/dev/null
    [ -n "${PROGRESS_FILE:-}" ] && rm -f "${PROGRESS_FILE}.tmp" 2>/dev/null

    local _end_ts _elapsed
    _end_ts=$(date +%s)
    _elapsed=$((_end_ts - _start_ts))
    log_msg "✅ cleanup_proxy complete (${_elapsed}s)"
}

cleanup_webui() {
    log_msg "🧹 cleanup_webui"

    if ! kill_webui_safely 50; then
        log_msg "⚠️ dnscrypt-webui survived 5s (D-state?)"
    fi

    remove_pid_file "$(run_file webui.pid)"
    rm -f /data/local/tmp/webui.pid 2>/dev/null
    log_msg "✅ cleanup_webui complete"
}

cleanup_orphans() {
    log_msg "🧹 cleanup_orphans"

    kill_by_comm "dnscrypt-proxy" 30 >/dev/null 2>&1 || true

    local current_pid port pid_on_port comm
    current_pid=$(read_pid_file "$WEBUI_PID_FILE" 2>/dev/null)
    port=$(get_webui_port "$WEBUI_CONF")

    if command -v fuser >/dev/null 2>&1; then
        pid_on_port=$(fuser -n tcp "$port" 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' | head -n1)
        if [ -n "$pid_on_port" ] && [ "$pid_on_port" != "$current_pid" ]; then
            comm=$(cat "/proc/$pid_on_port/comm" 2>/dev/null)
            case "$comm" in
                dnscrypt-webui*)
                    kill -9 "$pid_on_port" 2>/dev/null
                    log_msg "cleanup_orphans: killed orphan webui PID $pid_on_port"
                    ;;
                "")
                    ;;
                *)
                    log_msg "cleanup_orphans: port $port held by PID $pid_on_port ($comm), NOT killing"
                    ;;
            esac
        fi
    fi
    log_msg "✅ cleanup_orphans complete"
}

aggressive_cleanup() {
    log_msg "🧹 aggressive_cleanup start"
    cleanup_proxy
    cleanup_webui
    cleanup_orphans
    firewall_cleanup
    rm -f "$(run_file watchdog.pid)" 2>/dev/null
    rm -f /data/local/tmp/watchdog.pid 2>/dev/null
    log_msg "✅ aggressive_cleanup complete"
}

# ============================================================
# [10] WebUI launcher
# ============================================================
start_native_webui() {
    local bin="$1"
    local port="${2:-$DEFAULT_WEBUI_PORT}"

    log_msg "🚀 start_native_webui (port: $port)"

    kill_webui_safely 50 || true

    if ! wait_port_free "$port" tcp 30; then
        if command -v fuser >/dev/null 2>&1; then
            fuser -k "$port/tcp" 2>/dev/null
            sleep 1
        fi
        if ! wait_port_free "$port" tcp 30; then
            log_msg "❌ Port $port still in use, aborting start"
            return 1
        fi
    fi

    export HOME=/data/local/tmp

    if command -v setsid >/dev/null 2>&1; then
        setsid env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q setsid; then
        busybox setsid env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    else
        nohup env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    fi

    sleep 1

    local pid=""
    pid=$(list_pids_by_comm "dnscrypt-webui" 2>/dev/null | awk '{print $1}')
    if [ -n "$pid" ]; then
        write_pid_file "$WEBUI_PID_FILE" "$pid" 2>/dev/null || \
            log_msg "⚠️ Failed to write $WEBUI_PID_FILE"
    fi

    local i=0
    while [ "$i" -lt 35 ]; do
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            log_msg "❌ WebUI process died (port collision?)"
            return 1
        fi
        if is_port_open "$port" tcp; then
            log_msg "✅ WebUI bound to port $port (PID: ${pid:-unknown})"
            return 0
        fi
        sleep 1
        i=$((i + 1))
    done

    log_msg "❌ WebUI failed to bind within 35s"
    return 1
}