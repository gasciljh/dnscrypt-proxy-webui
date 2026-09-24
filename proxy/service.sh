#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – service.sh
# Version: v1.0.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Boot service launcher (Magisk/KernelSU phase).
#
#   Triggered automatically by Magisk at:
#     sys.boot_completed = 1
#
# Responsibilities:
#   • Wait for boot completion (max 60 × 3s = 180s)
#   • Wait for network readiness (max 15 × 2s = 30s)
#   • Read webui.conf (with Port Guard — reject 8080)
#   • Verify WebUI binary exists
#   • Start WebUI (with one retry on failure)
#   • Launch Watchdog as a standalone process
#   • Respect the disable file (skip if present)
#
# Design:
#   • Loads functions.sh if available; otherwise uses inline
#     fallbacks for all critical functions (is_port_open,
#     cleanup_proxy, start_webui, get_port, ...)
#   • Watchdog runs as a separate file so that $$ inside it
#     refers to the real Watchdog PID (not service.sh's).
#   • All error paths are logged to dnscrypt_main.log.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Determine module path
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

# ============================================================
# [2] Default paths (reconfigured after loading functions.sh)
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
PID_FILE="/data/local/tmp/dnscrypt.pid"
WEBUI_PID_FILE="/data/local/tmp/webui.pid"
WATCHDOG_PID_FILE="/data/local/tmp/watchdog.pid"
STATUS_FILE="/data/local/tmp/dnscrypt.status"
CRED_FILE="/data/local/tmp/dnscrypt_credentials.txt"

TOML_FILE="$MODDIR/proxy/dnscrypt-proxy.toml"

# ============================================================
# [2b] Read module version (before first log_msg call)
# ============================================================
MODULE_VERSION=""
if [ -f "$MODDIR/module.prop" ]; then
    MODULE_VERSION=$(grep "^version=" "$MODDIR/module.prop" 2>/dev/null | head -n 1 | cut -d= -f2 | tr -d '\r ')
fi
[ -z "$MODULE_VERSION" ] && MODULE_VERSION="unknown"

# ============================================================
# [3] log_msg
# ============================================================
log_msg() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE" 2>/dev/null
}

log_msg "service.sh started ($MODULE_VERSION)"

# ============================================================
# [4] Load functions.sh
# ============================================================
FUNCTIONS_LOADED=0
if [ -f "$MODDIR/functions.sh" ]; then
    # shellcheck disable=SC1090
    . "$MODDIR/functions.sh" 2>/dev/null
    if command -v cleanup_proxy >/dev/null 2>&1 \
       && command -v is_port_open >/dev/null 2>&1; then
        FUNCTIONS_LOADED=1
        log_msg "functions.sh loaded successfully"

        if command -v init_runtime_paths >/dev/null 2>&1; then
            init_runtime_paths
            log_msg "Runtime paths initialized"
        fi
    else
        log_msg "WARNING: functions.sh loaded but critical functions missing"
    fi
else
    log_msg "WARNING: functions.sh not found, using inline fallbacks"
fi

# ============================================================
# [5] Internal fallback (if functions.sh fails to load)
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

if [ "$FUNCTIONS_LOADED" = "0" ]; then
    _FB_RUN_DIR=$(_fallback_get_run_dir)
    STATUS_FILE="$_FB_RUN_DIR/dnscrypt.status"
    PID_FILE="$_FB_RUN_DIR/dnscrypt.pid"
    WEBUI_PID_FILE="$_FB_RUN_DIR/webui.pid"
    WATCHDOG_PID_FILE="$_FB_RUN_DIR/watchdog.pid"
    log_msg "Fallback paths: RUN_DIR=$_FB_RUN_DIR"
fi

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
        fi
    fi
    return 1
}

# --- Fallback: cleanup_proxy ---
_inline_cleanup_proxy() {
    pkill -9 -x dnscrypt-proxy 2>/dev/null
    if command -v fuser >/dev/null 2>&1; then
        fuser -k 5354/udp 2>/dev/null
        fuser -k 5354/tcp 2>/dev/null
    fi
    rm -f "$PID_FILE" 2>/dev/null
    rm -f /data/local/tmp/dnscrypt.pid 2>/dev/null
}

# --- Fallback: cleanup_webui ---
_inline_cleanup_webui() {
    pkill -9 -x dnscrypt-webui 2>/dev/null
    rm -f "$WEBUI_PID_FILE" 2>/dev/null
    rm -f /data/local/tmp/webui.pid 2>/dev/null
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
    if echo "$val" | grep -qE '^[0-9]+$' && [ "$val" -ge 1 ] && [ "$val" -le 65535 ]; then
        # Port Guard: reject 8080 (reserved for monitoring_ui)
        if [ "$val" = "8080" ]; then
            log_msg "WARNING: _inline_get_port: PORT=8080 conflicts with monitoring_ui — falling back to 9090"
            printf "9090"
            return 0
        fi
        printf "%s" "$val"
        return 0
    fi
    printf "9090"
}

# ============================================================
# [5b] Fallback: start_webui
# ============================================================
_inline_start_webui() {
    local bin="$1"
    local port="$2"

    log_msg "Starting WebUI (inline, port: $port)"
    _inline_cleanup_webui

    export HOME=/data/local/tmp

    if command -v setsid >/dev/null 2>&1; then
        setsid env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q setsid; then
        busybox setsid env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    else
        nohup env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    fi

    sleep 1
    local web_pid=""

    # pgrep -x matches the process name exactly (basename: "dnscrypt-webui")
    web_pid=$(pgrep -x "dnscrypt-webui" 2>/dev/null | head -n1)

    if [ -n "$web_pid" ]; then
        printf "%d\n" "$web_pid" > "${WEBUI_PID_FILE}.tmp"
        mv -f "${WEBUI_PID_FILE}.tmp" "$WEBUI_PID_FILE"
    fi

    local i=0
    while [ "$i" -lt 35 ]; do
        if [ -n "$web_pid" ] && ! kill -0 "$web_pid" 2>/dev/null; then
            log_msg "ERROR: WebUI process died (Port collision?)"
            return 1
        fi
        if _inline_is_port_open "$port" tcp; then
            log_msg "WebUI bound to port $port (PID: ${web_pid:-unknown})"
            return 0
        fi
        sleep 1
        i=$((i + 1))
    done

    log_msg "ERROR: WebUI failed to bind within 35s"
    return 1
}

# ============================================================
# [6] Unified wrappers
# ============================================================
if [ "$FUNCTIONS_LOADED" = "1" ]; then
    do_cleanup_proxy()  { cleanup_proxy; }
    do_cleanup_webui()  { cleanup_webui; }
    do_is_port_open()   { is_port_open "$1" "${2:-tcp}"; }
    do_start_webui()    { start_native_webui "$1" "$2"; }
    do_get_port()       { get_webui_port "$1"; }
    do_read_conf()      { get_conf_value "$1" "$2" "$3"; }
else
    do_cleanup_proxy()  { _inline_cleanup_proxy; }
    do_cleanup_webui()  { _inline_cleanup_webui; }
    do_is_port_open()   { _inline_is_port_open "$1" "${2:-tcp}"; }
    do_start_webui()    { _inline_start_webui "$1" "$2"; }
    do_get_port()       { _inline_get_port "$1"; }
    do_read_conf()      { _inline_read_conf "$1" "$2" "$3"; }
fi

# ============================================================
# [7] Initial cleanup
# ============================================================
do_cleanup_proxy
log_msg "Initial cleanup done"

# ============================================================
# [8] Migrate old PID files from /data/local/tmp
# ============================================================
if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ] && \
   [ "$RUN_DIR_ACTIVE" != "/data/local/tmp" ]; then
    for f in dnscrypt.pid webui.pid watchdog.pid dnscrypt.status; do
        if [ -f "/data/local/tmp/$f" ] && [ ! -f "$RUN_DIR_ACTIVE/$f" ]; then
            if [ "$f" = "dnscrypt.status" ]; then
                cp -f "/data/local/tmp/$f" "$RUN_DIR_ACTIVE/$f" 2>/dev/null
                log_msg "Migrated $f from tmp to run/"
            fi
        fi
        rm -f "/data/local/tmp/$f" 2>/dev/null
    done
fi

# ============================================================
# [9] Verify binary permissions
# ============================================================
BIN_DIR="$MODDIR/proxy"

if [ -f "$BIN_DIR/dnscrypt-proxy" ] && [ ! -x "$BIN_DIR/dnscrypt-proxy" ]; then
    chmod 0755 "$BIN_DIR/dnscrypt-proxy"
    log_msg "Fixed permissions for dnscrypt-proxy"
fi

if [ -f "$BIN_DIR/dnscrypt-webui" ] && [ ! -x "$BIN_DIR/dnscrypt-webui" ]; then
    chmod 0755 "$BIN_DIR/dnscrypt-webui"
    log_msg "Fixed permissions for dnscrypt-webui"
fi

# ============================================================
# [10] One-time notification when credentials are ready
# ============================================================
if [ -f "$CRED_FILE" ] && [ ! -f /data/local/tmp/.dnscrypt_credentials_shown ]; then
    log_msg "Login credentials are ready at: $CRED_FILE"
    touch /data/local/tmp/.dnscrypt_credentials_shown 2>/dev/null
fi

# ============================================================
# [11] If module is disabled → cleanup and exit
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    log_msg "WARNING: Module is disabled, cleaning up before exit"

    echo "OFF" > "$STATUS_FILE" 2>/dev/null

    if [ "$FUNCTIONS_LOADED" = "1" ] && command -v manage_firewall >/dev/null 2>&1; then
        manage_firewall 0 2>/dev/null
        log_msg "Firewall cleaned (via functions.sh)"
    fi

    do_cleanup_proxy 2>/dev/null
    do_cleanup_webui 2>/dev/null

    if command -v settings >/dev/null 2>&1; then
        _st_wait=0
        while [ "$_st_wait" -lt 5 ]; do
            if settings get global private_dns_mode >/dev/null 2>&1; then
                break
            fi
            sleep 1
            _st_wait=$((_st_wait + 1))
        done

        if settings delete global private_dns_mode 2>/dev/null; then
            log_msg "private_dns_mode reset to AUTO"
        else
            log_msg "WARNING: Failed to reset private_dns_mode (continuing)"
        fi
    else
        log_msg "settings command not available, skipping private_dns_mode reset"
    fi

    if command -v ndc >/dev/null 2>&1; then
        ndc resolver flushdefaultif 2>/dev/null
    fi

    log_msg "Module disabled cleanup completed"
    exit 0
fi

# ============================================================
# [12] Wait for boot completion
# ============================================================
_max=60
_wait=0
until [ "$(getprop sys.boot_completed 2>/dev/null || printf "0")" = "1" ] || [ "$_wait" -ge "$_max" ]; do
    sleep 3
    _wait=$((_wait + 3))
done
sleep 2
log_msg "Boot completed (waited ${_wait}s)"

# ============================================================
# [13] Wait for network readiness
# ============================================================
net_wait=0
while [ "$net_wait" -lt 15 ]; do
    if command -v ip >/dev/null 2>&1; then
        if ip route 2>/dev/null | grep -q 'default' \
           || ip -6 route 2>/dev/null | grep -q 'default'; then
            break
        fi
    elif command -v busybox >/dev/null 2>&1; then
        if busybox ip route 2>/dev/null | grep -q 'default' \
           || busybox ip -6 route 2>/dev/null | grep -q 'default'; then
            break
        fi
    fi
    sleep 2
    net_wait=$((net_wait + 1))
done

if [ "$net_wait" -ge 15 ]; then
    log_msg "WARNING: No default route after 30s, trying DNS reachability..."
    dns_wait=0
    while [ "$dns_wait" -lt 10 ]; do
        if ping -c 1 -W 2 9.9.9.9 >/dev/null 2>&1 \
           || ping6 -c 1 -W 2 2620:fe::fe >/dev/null 2>&1; then
            log_msg "DNS reachable via ping"
            break
        fi
        sleep 2
        dns_wait=$((dns_wait + 1))
    done
    if [ "$dns_wait" -ge 10 ]; then
        log_msg "WARNING: Still no network after 50s total, proceeding anyway"
    fi
fi
log_msg "Network ready (route wait: $((net_wait * 2))s)"

# ============================================================
# [14] Read webui.conf settings
# ============================================================
CONF_FILE="$BIN_DIR/webui.conf"
PORT=$(do_get_port "$CONF_FILE")
[ -z "$PORT" ] && PORT="9090"

AUTO_RESTART_DNS=$(do_read_conf "$CONF_FILE" "AUTO_RESTART_DNS" "1")
AUTO_RESTART_WEBUI=$(do_read_conf "$CONF_FILE" "AUTO_RESTART_WEBUI" "1")

case "$AUTO_RESTART_DNS"   in 0|1) ;; *) AUTO_RESTART_DNS="1"   ;; esac
case "$AUTO_RESTART_WEBUI" in 0|1) ;; *) AUTO_RESTART_WEBUI="1" ;; esac

log_msg "WebUI port: $PORT"
log_msg "AUTO_RESTART_DNS=$AUTO_RESTART_DNS, AUTO_RESTART_WEBUI=$AUTO_RESTART_WEBUI"
if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ]; then
    log_msg "Runtime paths: RUN_DIR=$RUN_DIR_ACTIVE"
else
    log_msg "Runtime paths: RUN_DIR=$(dirname "$PID_FILE")"
fi

# ============================================================
# [15] Verify WebUI binary exists
# ============================================================
WEBUI="$BIN_DIR/dnscrypt-webui"
if [ ! -f "$WEBUI" ]; then
    log_msg "ERROR: WebUI binary not found at $WEBUI"
    echo "OFF" > "$STATUS_FILE" 2>/dev/null
    exit 1
fi

# ============================================================
# [16] Start WebUI (two attempts)
# ============================================================
WEBUI_STARTED=0
for attempt in 1 2; do
    log_msg "WebUI start attempt $attempt/2..."
    if do_start_webui "$WEBUI" "$PORT"; then
        WEBUI_STARTED=1
        log_msg "WebUI started (Port: $PORT)"
        break
    fi
    if [ "$attempt" -lt 2 ]; then
        log_msg "WARNING: WebUI start attempt $attempt failed, retrying in 3s..."
        sleep 3
    fi
done

if [ "$WEBUI_STARTED" != "1" ]; then
    log_msg "ERROR: WebUI failed to start after 2 attempts"
fi

# ============================================================
# [17] Watchdog — independent process
# ============================================================
# The WATCHDOG_SCRIPT lives in the module root ($MODDIR/watchdog.sh),
# NOT in $MODDIR/proxy/. This is critical: the watchdog runs as a
# separate file so that $$ inside it refers to the actual watchdog
# PID, not the parent service.sh.
# ============================================================
WATCHDOG_SCRIPT="$MODDIR/watchdog.sh"

if [ ! -f "$WATCHDOG_SCRIPT" ]; then
    log_msg "ERROR: watchdog.sh not found at $WATCHDOG_SCRIPT"
    log_msg "   Watchdog will NOT be started — service continues without it"
else
    if [ ! -x "$WATCHDOG_SCRIPT" ]; then
        chmod 0755 "$WATCHDOG_SCRIPT" 2>/dev/null
    fi

    nohup "$WATCHDOG_SCRIPT" \
        "$WATCHDOG_PID_FILE" \
        "$MODDIR" \
        "$PORT" \
        "$AUTO_RESTART_DNS" \
        "$AUTO_RESTART_WEBUI" \
        >/dev/null 2>&1 &

    sleep 1

    if [ -f "$WATCHDOG_PID_FILE" ]; then
        wd_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$wd_pid" ] && kill -0 "$wd_pid" 2>/dev/null; then
            log_msg "Watchdog started (PID: $wd_pid)"
        else
            log_msg "WARNING: Watchdog PID file exists but process is not alive"
        fi
    else
        log_msg "WARNING: Watchdog PID file not created — check watchdog.sh"
    fi
fi

exit 0