#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — service.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-19
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Boot service launcher (Magisk / KernelSU / APatch phase).
# Triggered at sys.boot_completed = 1.
#
# Responsibilities:
#   • Wait for boot completion (multi-signal)
#   • Wait for network readiness
#   • Read webui.conf (Port Guard rejects 8080)
#   • Start WebUI (idempotent: kill → wait → verify → start)
#   • Start Watchdog (idempotent: kill → nohup → verify)
#   • Respect the disable file
#   • Trigger periodic auto-backup if needed
#   • Rotate old backups
#   • Clean up COMMIT'd transactions
#   • Read .pending_notification
#   • Ensure DNS starts after boot via /api/ensure_running_service
#
# Design:
#   • Sources functions.sh (which sources boot-mini.sh).
#   • On functions.sh load failure, only minimum primitives
#     are redefined inline so the WebUI can still start.
#   • Watchdog is a separate process so $$ inside it resolves
#     to the watchdog PID (not service.sh's).
#   • All error paths are logged to dnscrypt_main.log.
#
# Idempotency model (v1.5.0+fix):
#   Every `start_*` step is prefixed with a `_kill_*_safely`
#   helper that polls for actual process death (up to 3-5 s
#   with 100 ms intervals), then verifies the port is free
#   before launching. Repeated invocations therefore always
#   converge to exactly one of each process.
#
#   Watchdog is launched via nohup (not setsid). On Android,
#   setsid + & through `su -c` can produce TWO processes
#   (wrapper + real), breaking the single-instance guarantee.
#   nohup launches exactly one child.
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

MODULE_VERSION="$(get_version)"

case "${1:-}" in
    --version)
        echo "$0: $MODULE_VERSION"
        exit 0
        ;;
esac

# ============================================================
# [2] Default paths (reconfigured after functions.sh loads)
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
PID_FILE="/data/local/tmp/dnscrypt.pid"
WEBUI_PID_FILE="/data/local/tmp/webui.pid"
WATCHDOG_PID_FILE="/data/local/tmp/watchdog.pid"
STATUS_FILE="/data/local/tmp/dnscrypt.status"
CRED_FILE="/data/local/tmp/dnscrypt_credentials.txt"

TOML_FILE="$MODDIR/proxy/dnscrypt-proxy.toml"
SELECTED_PROFILE_FILE="$MODDIR/proxy/selected_profile.txt"

# --- Data preservation paths ---
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# --- Reserved port (finalized after functions.sh is sourced) ---
_MONITORING_UI_PORT=""

# ============================================================
# [3] Log helper (fallback)
# ============================================================
# Used only when functions.sh failed to load. log_msg from
# boot-mini.sh takes precedence once sourced.
log_msg() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE" 2>/dev/null
}

log_msg "service.sh started ($MODULE_VERSION)"

# ============================================================
# [4] Load functions.sh (sources boot-mini.sh)
# ============================================================
FUNCTIONS_LOADED=0
if [ -f "$MODDIR/functions.sh" ]; then
    # shellcheck disable=SC1090
    . "$MODDIR/functions.sh" 2>/dev/null
    if command -v cleanup_proxy >/dev/null 2>&1 \
       && command -v is_port_open >/dev/null 2>&1; then
        FUNCTIONS_LOADED=1
        log_msg "functions.sh loaded successfully"

        if command -v init_runtime_paths >/dev/null 2>&1 \
           && [ -z "$RUN_DIR_ACTIVE" ]; then
            init_runtime_paths
            log_msg "Runtime paths initialized (deferred)"
        fi
    else
        log_msg "WARNING: functions.sh loaded but critical functions missing"
    fi
else
    log_msg "WARNING: functions.sh not found, using inline fallbacks"
fi

# Prefer boot-mini.sh's constant; fall back to 8080.
_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"

# ============================================================
# [5] Inline fallbacks (minimal)
# ============================================================
# Only the primitives required to start the WebUI are
# provided here. Advanced features (firewall, backup, rotation)
# skip gracefully via [6] wrappers.
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
# /proc/net → ss → netstat. Trailing space in ":$hex_port "
# prevents :1F90 from matching :1F90A.
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

# --- Fallback: get_port (with Port Guard) ---
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
            log_msg "WARNING: _inline_get_port: PORT=$val_clean conflicts with monitoring_ui — falling back to 9090"
            printf "9090"
            return 0
        fi
        printf "%s" "$val_clean"
        return 0
    fi
    printf "9090"
}

# --- Fallback: start_webui ---
# Three-way launch: setsid → busybox setsid → nohup.
# Waits up to 35 s for the port to bind; detects early death.
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
    web_pid=$(pgrep -x "dnscrypt-webui" 2>/dev/null | head -n1)

    if [ -n "$web_pid" ]; then
        if printf "%d\n" "$web_pid" > "${WEBUI_PID_FILE}.tmp" 2>/dev/null \
           && mv -f "${WEBUI_PID_FILE}.tmp" "$WEBUI_PID_FILE" 2>/dev/null; then
            :
        else
            log_msg "WARNING: could not write WebUI PID file ($WEBUI_PID_FILE)"
            rm -f "${WEBUI_PID_FILE}.tmp" 2>/dev/null
        fi
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
    do_cleanup_webui()  { cleanup_webui; }
    do_is_port_open()   { is_port_open "$1" "${2:-tcp}"; }
    do_start_webui()    { start_native_webui "$1" "$2"; }
    do_get_port()       { get_webui_port "$1"; }
    do_read_conf()      { read_conf "$1" "$2" "$3"; }

    if command -v get_profile_memory_hint >/dev/null 2>&1; then
        do_mem_hint()   { get_profile_memory_hint; }
    else
        do_mem_hint()   { printf "unknown"; }
    fi

    if command -v auto_backup_if_needed >/dev/null 2>&1; then
        do_auto_backup()   { auto_backup_if_needed "${1:-86400}"; }
    else
        do_auto_backup()   { return 0; }
    fi

    if command -v rotate_backups >/dev/null 2>&1; then
        do_rotate_backups() { rotate_backups "${1:-21}"; }
    else
        do_rotate_backups() { return 0; }
    fi

    if command -v cleanup_old_transactions >/dev/null 2>&1; then
        do_cleanup_transactions() { cleanup_old_transactions; }
    else
        do_cleanup_transactions() { return 0; }
    fi

    do_cleanup_proxy() { cleanup_proxy; }

    if command -v manage_firewall >/dev/null 2>&1; then
        do_cleanup_firewall() { manage_firewall 0; }
    else
        do_cleanup_firewall() { return 0; }
    fi
else
    do_cleanup_webui()  { _inline_cleanup_webui; }
    do_is_port_open()   { _inline_is_port_open "$1" "${2:-tcp}"; }
    do_start_webui()    { _inline_start_webui "$1" "$2"; }
    do_get_port()       { _inline_get_port "$1"; }
    do_read_conf()      { _inline_read_conf "$1" "$2" "$3"; }
    do_mem_hint()       { printf "unknown (functions.sh not loaded)"; }
    do_auto_backup()    { return 0; }
    do_rotate_backups() { return 0; }
    do_cleanup_transactions() { return 0; }
    do_cleanup_proxy()  { return 0; }
    do_cleanup_firewall() { return 0; }
fi

# ============================================================
# [6b] Process lifecycle helpers (idempotency primitives)
# ============================================================
# Four helpers give service.sh idempotent start semantics.
# Every "start" in [16]/[17] is preceded by a corresponding
# "kill … safely" call that:
#   1. Sends SIGKILL to every matching process.
#   2. Polls until the process set is empty (100 ms × N).
#   3. Returns 0 on success, 1 on timeout (logged by caller).
#
# Polling interval (100 ms) is aggressive but bounded: the
# worst-case wait is 5 s (webui) or 3 s (watchdog), which is
# well within the boot budget. A blind `sleep 1` would not be
# sufficient on devices where SIGKILL takes longer to reap.

# _kill_webui_safely — kill all dnscrypt-webui instances.
# Uses pgrep -x (exact comm match) to avoid matching unrelated
# shells whose argv contains the string.
_kill_webui_safely() {
    local pids wait
    pids=$(pgrep -x dnscrypt-webui 2>/dev/null)
    if [ -n "$pids" ]; then
        # Word-splitting is intentional: kill takes multiple PIDs.
        # shellcheck disable=SC2086
        kill -9 $pids 2>/dev/null
    fi

    wait=0
    while [ "$wait" -lt 50 ]; do
        if ! pgrep -x dnscrypt-webui >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
        wait=$((wait + 1))
    done
    return 1
}

# _wait_port_free — poll until the port accepts no connection.
# Caller must have already killed any process that held it.
_wait_port_free() {
    local port="$1"
    local wait=0
    while [ "$wait" -lt 30 ]; do
        if ! do_is_port_open "$port" tcp; then
            return 0
        fi
        sleep 0.1
        wait=$((wait + 1))
    done
    return 1
}

# _kill_watchdogs_safely — kill all watchdog.sh instances.
# Uses ps + grep (not pgrep -f) because pgrep -f would also
# match this very shell's argv when the script name contains
# "watchdog.sh". The `grep -v grep` filter excludes the grep
# process itself; `grep -v 'service\.sh'` is not needed because
# service.sh does not carry that literal string.
_kill_watchdogs_safely() {
    local pids wait
    pids=$(ps -A -o PID,ARGS 2>/dev/null \
        | grep '/watchdog\.sh' \
        | grep -v grep \
        | awk '{print $1}')
    if [ -n "$pids" ]; then
        # shellcheck disable=SC2086
        kill -9 $pids 2>/dev/null
    fi

    wait=0
    while [ "$wait" -lt 30 ]; do
        if [ -z "$(ps -A -o ARGS 2>/dev/null \
                  | grep '/watchdog\.sh' \
                  | grep -v grep)" ]; then
            return 0
        fi
        sleep 0.1
        wait=$((wait + 1))
    done
    return 1
}

# _count_watchdogs — current watchdog count (0, 1, 2, …).
# Used to verify single-instance after launch.
_count_watchdogs() {
    ps -A -o ARGS 2>/dev/null \
        | grep '/watchdog\.sh' \
        | grep -v grep \
        | wc -l \
        | tr -d ' '
}

# ============================================================
# [7] Initial cleanup
# ============================================================
# Kill any leftover dnscrypt-proxy from a previous run before
# the WebUI and DNS engine start. Defensive: previous shutdown
# should have cleaned up, but a hard reboot can leave the
# process running.
do_cleanup_proxy
log_msg "Initial cleanup done"

# Cleanup leftover COMMIT'd transactions.
# Defense-in-depth: main.go also does this, but a boot-time
# cleanup catches the case where main.go never started.
do_cleanup_transactions

# ============================================================
# [7b] Read pending notification (informational)
# ============================================================
# customize.sh writes .pending_notification after a successful
# restore during an upgrade. main.go owns the deletion; this
# read is purely for the boot log.
if [ -f "$PENDING_NOTIFY_FILE" ]; then
    _pending_msg=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$_pending_msg" ]; then
        log_msg "📢 Install notification: $_pending_msg"
    fi
fi

# ============================================================
# [8] Migrate old PID files from /data/local/tmp
# ============================================================
# v1.2.0 migrated the runtime dir to $MODDIR/proxy/run/.
# `dnscrypt.status` carries user intent and is preserved on
# successful copy; PID files are transient and always dropped.
if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ] && \
   [ "$RUN_DIR_ACTIVE" != "/data/local/tmp" ]; then
    for _mf in dnscrypt.pid webui.pid watchdog.pid dnscrypt.status; do
        [ -f "/data/local/tmp/$_mf" ] || continue

        if [ "$_mf" = "dnscrypt.status" ]; then
            if [ -f "$RUN_DIR_ACTIVE/$_mf" ]; then
                rm -f "/data/local/tmp/$_mf" 2>/dev/null
            elif cp -f "/data/local/tmp/$_mf" "$RUN_DIR_ACTIVE/$_mf" 2>/dev/null; then
                log_msg "Migrated $_mf from tmp to run/"
                rm -f "/data/local/tmp/$_mf" 2>/dev/null
            else
                log_msg "WARNING: could not migrate $_mf — keeping /tmp copy"
            fi
        else
            rm -f "/data/local/tmp/$_mf" 2>/dev/null
        fi
    done
fi

# ============================================================
# [9] Verify binary permissions
# ============================================================
# A manual reinstall or file-manager copy can strip the
# execute bit. Re-apply it before use.
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
    else
        log_msg "Firewall cleanup skipped (functions.sh not loaded)"
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
# [12] Wait for boot completion — multi-signal
# ============================================================
# Magisk triggers this script when sys.boot_completed = 1
# fires, but on some ROMs that property is set BEFORE the
# system is truly usable. Symptoms of firing too early:
#   • `settings` service not available → private_dns_mode
#     reset fails silently
#   • Network stack partially initialized → [13] fails
#
# Fix: wait for TWO independent signals:
#   1. sys.boot_completed = 1 (poll every 3 s, max 180 s)
#   2. Boot animation stopped (poll every 2 s, max 30 s)
#
# Timeout is a soft failure — we proceed with a WARNING.
_wait=0
_max=60
_boot_property_seen=0

until [ "$_boot_property_seen" = "1" ] || [ "$_wait" -ge "$_max" ]; do
    if [ "$(getprop sys.boot_completed 2>/dev/null || printf "0")" = "1" ]; then
        _boot_property_seen=1
        break
    fi
    sleep 3
    _wait=$((_wait + 1))
done

if [ "$_boot_property_seen" = "1" ]; then
    log_msg "Boot completed (sys.boot_completed=1 after ${_wait}x3s)"
else
    log_msg "WARNING: sys.boot_completed never set after ${_max}x3s — proceeding anyway"
fi

# --- Signal 2: boot animation stopped (best-effort) ---
_anim_wait=0
_anim_max=15
_bootanim_ready=0

while [ "$_anim_wait" -lt "$_anim_max" ]; do
    _anim_state=$(getprop init.svc.bootanim 2>/dev/null)
    _anim_exit=$(getprop service.bootanim.exit 2>/dev/null)

    if [ "$_anim_state" = "stopped" ] || [ "$_anim_exit" = "1" ]; then
        _bootanim_ready=1
        break
    fi

    sleep 2
    _anim_wait=$((_anim_wait + 1))
done

if [ "$_bootanim_ready" = "1" ]; then
    log_msg "Boot animation stopped (init.svc.bootanim='${_anim_state:-}' service.bootanim.exit='${_anim_exit:-}')"
else
    log_msg "WARNING: boot animation did not stop after ${_anim_max}x2s — proceeding anyway"
fi

# Final grace period: let the property observer and the
# settings service settle before the network check.
sleep 2

# ============================================================
# [13] Wait for network readiness
# ============================================================
# Two-stage check:
#   Stage 1 (30 s) — wait for a default route.
#   Stage 2 (20 s) — fall back to ping reachability.
#
# If neither succeeds within 50 s, log a warning and proceed.
# Refusing to start on a slow network is worse than starting
# partially initialized: the WebUI and DNS engine bind
# loopback sockets regardless of external reachability, and
# the blocklist download retries automatically.
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
# Values read:
#   PORT               — WebUI listen port (default 9090)
#   AUTO_RESTART_DNS   — watchdog restarts DNS on crash
#   AUTO_RESTART_WEBUI — watchdog restarts WebUI on crash
#
# do_get_port applies the Port Guard (rejects 8080) and the
# leading-zero-safe numeric check. AUTO_RESTART values outside
# {0,1} normalize to "1".
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
# [14b] Log active profile + memory hint
# ============================================================
# Informational only. main.go remains the authority for the
# actual debug.SetMemoryLimit() value.
ACTIVE_PROFILE="pro"
if [ -f "$SELECTED_PROFILE_FILE" ]; then
    _ap=$(cat "$SELECTED_PROFILE_FILE" 2>/dev/null | tr -d '\r\n ')
    case "$_ap" in
        light|normal|pro|proplus|ultimate) ACTIVE_PROFILE="$_ap" ;;
    esac
fi

MEMORY_HINT=$(do_mem_hint)
log_msg "Active profile: $ACTIVE_PROFILE"
log_msg "Expected memory limit: $MEMORY_HINT (managed by main.go)"

# ============================================================
# [14c] Auto-backup if needed
# ============================================================
# Triggers a backup of the 5 user config files if the last
# one is older than 24 hours.
#
# BACKUP_STATUS distinguishes "created" from "skipped" by
# comparing the mtime of .last_auto_backup before and after.
# Consumed by the summary block in §[18].
BACKUP_STATUS="not-attempted"
BACKUP_COUNT="0"
LAST_STABLE_NAME=""

if [ "$FUNCTIONS_LOADED" = "1" ]; then
    log_msg "🔄 Checking auto-backup state (interval=86400s)..."

    _marker_before=0
    if [ -f "$PERSISTENT_BACKUP/.last_auto_backup" ]; then
        _marker_before=$(stat -c %Y "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null) \
            || _marker_before=$(stat -f %m "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null) \
            || _marker_before=0
    fi

    if do_auto_backup 86400; then
        _marker_after=0
        if [ -f "$PERSISTENT_BACKUP/.last_auto_backup" ]; then
            _marker_after=$(stat -c %Y "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null) \
                || _marker_after=$(stat -f %m "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null) \
                || _marker_after=0
        fi

        case "$_marker_before" in ''|*[!0-9]*) _marker_before=0 ;; esac
        case "$_marker_after"  in ''|*[!0-9]*) _marker_after=0  ;; esac

        if [ "$_marker_after" -gt 0 ] && [ "$_marker_after" != "$_marker_before" ]; then
            BACKUP_STATUS="created"
            log_msg "✅ Auto-backup: new snapshot created"
        else
            BACKUP_STATUS="skipped"
            log_msg "ℹ️ Auto-backup: skipped (recent snapshot exists)"
        fi
    else
        BACKUP_STATUS="failed"
        log_msg "⚠️ Auto-backup check failed (non-fatal)"
    fi

    # Rotate old snapshots to keep the total bounded.
    if do_rotate_backups 21; then
        log_msg "✅ Backup rotation complete (keep=21)"
    else
        log_msg "⚠️ Backup rotation failed (non-fatal)"
    fi

    # --- Collect backup state for the summary ---
    # Counts directories matching the timestamp pattern
    # ^[0-9]{8}-[0-9]{6}-. Excludes current/, txn-*, orphan-txn-*,
    # .restore_snap.*, apk/.
    if [ -d "$PERSISTENT_BACKUP" ]; then
        BACKUP_COUNT=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d ./*/ 2>/dev/null | \
            sed 's:/$::' | \
            grep -cE '^[0-9]{8}-[0-9]{6}-' | tr -d ' ')
        [ -z "$BACKUP_COUNT" ] && BACKUP_COUNT=0
    fi

    if [ -f "$LAST_STABLE_FILE" ]; then
        LAST_STABLE_NAME=$(cat "$LAST_STABLE_FILE" 2>/dev/null | tr -d '\r\n ')
    fi
else
    BACKUP_STATUS="skipped (functions.sh not loaded)"
    log_msg "Backup operations skipped — functions.sh not loaded"
fi

# ============================================================
# [15] Verify WebUI binary exists
# ============================================================
# A missing binary is fatal: without the WebUI, the user has
# no way to interact with the module. Write OFF to
# STATUS_FILE so the user's intent is not left ambiguous.
WEBUI="$BIN_DIR/dnscrypt-webui"
if [ ! -f "$WEBUI" ]; then
    log_msg "ERROR: WebUI binary not found at $WEBUI"
    echo "OFF" > "$STATUS_FILE" 2>/dev/null
    exit 1
fi

# ============================================================
# [16] Start WebUI — linear sequence, no confusing conditionals
# ============================================================
# Sequence:
#   [A] Kill any existing WebUI (poll for death, up to 5 s).
#   [B] Wait for the port to be free (poll, up to 3 s). If
#       still occupied after 3 s, force-kill via fuser and
#       wait again.
#   [C] Start the WebUI (up to 2 attempts).
#   [D] Verify: exactly one process + port bound.
#
# Why "always attempt to start" instead of "start only if
# port is free":
#   A port-check false positive (kernel TIME_WAIT transient,
#   or a race between two `ss` calls) would prevent a
#   legitimate start. Better to let start_native_webui's own
#   bind attempt report the real failure with a clear log.
#
# The `do_start_webui` wrapper delegates to
# start_native_webui (or its inline fallback), which already
# performs its own cleanup. The explicit kill/wait here is
# additional diagnostics — it shows in the log WHY start is
# being attempted.
WEBUI_STARTED=0

# --- [A] Kill existing WebUI ---
log_msg "🧹 Killing any existing WebUI before start..."
if ! _kill_webui_safely; then
    log_msg "⚠️ WebUI survived 5s (likely D-state); proceeding anyway"
fi
log_msg "✅ Previous WebUI instances cleared"

# --- [B] Wait for port to be free (with fuser fallback) ---
log_msg "🔍 Waiting for port $PORT to be free..."
if ! _wait_port_free "$PORT"; then
    log_msg "⚠️ Port $PORT still in use after 3s, forcing cleanup"
    if command -v fuser >/dev/null 2>&1; then
        fuser -k "$PORT"/tcp 2>/dev/null
        sleep 1
    fi
    if ! _wait_port_free "$PORT"; then
        log_msg "❌ Port $PORT STILL in use after fuser"
        log_msg "   Diagnostic: ss -tlnp | grep :$PORT"
        log_msg "   Proceeding anyway — start will report its own failure"
    fi
fi

# --- [C] Start (2 attempts) ---
for _attempt in 1 2; do
    log_msg "WebUI start attempt $_attempt/2..."
    if do_start_webui "$WEBUI" "$PORT"; then
        WEBUI_STARTED=1
        log_msg "✅ WebUI started (port: $PORT)"
        break
    fi
    if [ "$_attempt" -lt 2 ]; then
        log_msg "WARNING: WebUI start attempt $_attempt failed, retrying in 3s..."
        _kill_webui_safely
        _wait_port_free "$PORT"
        sleep 3
    fi
done

if [ "$WEBUI_STARTED" != "1" ]; then
    log_msg "ERROR: WebUI failed to start after 2 attempts"
fi

# --- [D] Verify: exactly one WebUI process ---
if [ "$WEBUI_STARTED" = "1" ]; then
    sleep 1
    _wb_count=$(pgrep -x dnscrypt-webui 2>/dev/null | wc -l | tr -d ' ')
    case "$_wb_count" in
        1)
            log_msg "✅ WebUI verification: 1 instance (correct)"
            ;;
        0)
            log_msg "❌ WebUI verification: 0 instances (start failed)"
            WEBUI_STARTED=0
            ;;
        *)
            log_msg "⚠️ WebUI verification: $_wb_count instances (expected 1)"
            ;;
    esac
fi

# ============================================================
# [17] Start Watchdog — single instance guaranteed
# ============================================================
# The watchdog is a SEPARATE PROCESS (not a subshell), so
# `$$` inside watchdog.sh resolves to the watchdog's own PID.
#
# Launch strategy: nohup is preferred over setsid. On Android,
# setsid + & through `su -c` can produce TWO processes (one
# for the setsid wrapper, one for the actual watchdog), which
# breaks the single-instance guarantee that watchdog.sh's own
# PID-file check relies on. nohup launches exactly one child
# process and does not create a new session — this is
# sufficient for a daemon that ignores SIGHUP anyway.
#
# Three-phase:
#   1. Kill any existing watchdog (poll for death, up to 3 s).
#   2. Launch one watchdog via nohup.
#   3. Verify: exactly one process by counting matching argv.
WATCHDOG_SCRIPT="$MODDIR/watchdog.sh"

if [ ! -f "$WATCHDOG_SCRIPT" ]; then
    log_msg "ERROR: watchdog.sh not found at $WATCHDOG_SCRIPT"
    log_msg "   Watchdog will NOT be started — service continues without it"
else
    if [ ! -x "$WATCHDOG_SCRIPT" ]; then
        chmod 0755 "$WATCHDOG_SCRIPT" 2>/dev/null
    fi

    # --- Phase 1: kill existing watchdogs ---
    log_msg "🧹 Killing any existing Watchdog..."
    if ! _kill_watchdogs_safely; then
        log_msg "⚠️ Some watchdogs survived 3s (likely D-state)"
    fi
    rm -f "$WATCHDOG_PID_FILE" 2>/dev/null
    log_msg "✅ Previous Watchdog instances cleared"

    # --- Phase 2: launch one watchdog ---
    # nohup is the primary launcher. setsid is a fallback only
    # for devices without nohup (rare on Android, but possible
    # on minimal builds).
    _launcher=""
    if command -v nohup >/dev/null 2>&1; then
        nohup "$WATCHDOG_SCRIPT" \
            "$WATCHDOG_PID_FILE" \
            "$MODDIR" \
            "$PORT" \
            "$AUTO_RESTART_DNS" \
            "$AUTO_RESTART_WEBUI" \
            >/dev/null 2>&1 < /dev/null &
        _launcher="nohup"
    elif command -v setsid >/dev/null 2>&1; then
        setsid "$WATCHDOG_SCRIPT" \
            "$WATCHDOG_PID_FILE" \
            "$MODDIR" \
            "$PORT" \
            "$AUTO_RESTART_DNS" \
            "$AUTO_RESTART_WEBUI" \
            >/dev/null 2>&1 < /dev/null &
        _launcher="setsid (fallback)"
    else
        "$WATCHDOG_SCRIPT" \
            "$WATCHDOG_PID_FILE" \
            "$MODDIR" \
            "$PORT" \
            "$AUTO_RESTART_DNS" \
            "$AUTO_RESTART_WEBUI" \
            >/dev/null 2>&1 < /dev/null &
        _launcher="direct (fallback)"
    fi
    log_msg "Watchdog launched via $_launcher"

    # --- Phase 3: verify single instance ---
    # Wait up to 5 s for the PID file, then count matching
    # processes. Expect exactly 1.
    _wd_wait=0
    while [ "$_wd_wait" -lt 5 ] && [ ! -f "$WATCHDOG_PID_FILE" ]; do
        sleep 1
        _wd_wait=$((_wd_wait + 1))
    done

    sleep 1  # let the process fully initialize

    _wd_count=$(_count_watchdogs)
    case "$_wd_count" in
        1)
            wd_pid=$(pgrep -f '/watchdog\.sh' 2>/dev/null | head -n1)
            log_msg "✅ Watchdog started (PID: ${wd_pid:-unknown}, single instance)"
            ;;
        0)
            log_msg "❌ Watchdog failed to start (0 instances)"
            ;;
        *)
            log_msg "⚠️ CRITICAL: $_wd_count watchdog instances (expected 1)"
            log_msg "   Investigate immediately: ps -A | grep watchdog"
            ;;
    esac
fi

# ============================================================
# [18] Final structured summary
# ============================================================
# Compact, one log line per field, prefixed with a bullet.
# Each field can be grepped individually without parsing a
# multi-line blob.
log_msg "─────────────────────────────────────────────"
log_msg "service.sh summary ($MODULE_VERSION):"
log_msg "  • WebUI:        port $PORT (started=$([ "$WEBUI_STARTED" = "1" ] && echo yes || echo no))"
log_msg "  • Profile:      $ACTIVE_PROFILE"
log_msg "  • Memory hint:  $MEMORY_HINT"
log_msg "  • Auto-restart: DNS=$AUTO_RESTART_DNS WebUI=$AUTO_RESTART_WEBUI"
log_msg "  • Auto-backup:  $BACKUP_STATUS"
log_msg "  • Snapshots:    $BACKUP_COUNT"
if [ -n "$LAST_STABLE_NAME" ]; then
    log_msg "  • Last stable:  $LAST_STABLE_NAME"
else
    log_msg "  • Last stable:  (none yet)"
fi
log_msg "  • functions.sh: $([ "$FUNCTIONS_LOADED" = "1" ] && echo loaded || echo fallback)"
log_msg "─────────────────────────────────────────────"

# ============================================================
# [19] Ensure DNS starts after boot
# ============================================================
# Root cause:
#   The watchdog enters a 30 s wait loop before its first DNS
#   attempt. By the time it fires, the WebUI may not have
#   finished binding yet → the API call fails. Result: DNS
#   does not start automatically until the user opens the
#   WebUI manually.
#
# Fix:
#   service.sh waits for the WebUI to become ready, then calls
#   the API directly. DNS starts within seconds instead of
#   30-60 seconds.
#
# Readiness check: token file exists AND is non-empty, and
# the WebUI port accepts TCP. Both conditions are checked
# every 2 s for up to 60 s.
#
# Intent check: STATUS_FILE is read to determine whether DNS
# should start:
#   • ON  → call the API to ensure DNS is running
#   • OFF → do nothing (user stopped it manually)
#
# Three-way HTTP client cascade: curl → wget → busybox wget.
# Each attempt is guarded by `command -v`, and the first
# success returns immediately. If no client is available, a
# warning is logged and the watchdog's own retry loop takes
# over.
log_msg "🔧 Ensuring DNS starts after boot..."

# Guard: WATCHDOG_TOKEN_FILE may be undefined if functions.sh
# failed to load.
if [ -z "$WATCHDOG_TOKEN_FILE" ]; then
    WATCHDOG_TOKEN_FILE="$(dirname "$STATUS_FILE")/.watchdog_token"
fi

_wait_webui=0
_wait_max=60
while [ "$_wait_webui" -lt "$_wait_max" ]; do
    if [ -f "$WATCHDOG_TOKEN_FILE" ] && \
       [ -n "$(cat "$WATCHDOG_TOKEN_FILE" 2>/dev/null)" ] && \
       do_is_port_open "$PORT" tcp 2>/dev/null; then
        log_msg "✅ WebUI ready after ${_wait_webui}s"
        break
    fi
    sleep 2
    _wait_webui=$((_wait_webui + 2))
done

if [ "$_wait_webui" -ge "$_wait_max" ]; then
    log_msg "⚠️ WebUI not ready after ${_wait_max}s — proceeding anyway"
fi

_dns_intent=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
[ -z "$_dns_intent" ] && _dns_intent="OFF"
log_msg "   DNS intent: $_dns_intent"

if [ "$_dns_intent" = "ON" ]; then
    _tok=$(cat "$WATCHDOG_TOKEN_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$_tok" ] && [ "${#_tok}" -ge 32 ]; then
        log_msg "   Calling ensure_running_service API..."

        # --------------------------------------------------------
        # Three-way HTTP client cascade.
        # --------------------------------------------------------
        # Both stdout and stderr are captured into `_api_response`
        # so a client-level error is preserved in the boot log.
        _api_client=""
        if command -v curl >/dev/null 2>&1; then
            _api_client="curl"
        elif command -v wget >/dev/null 2>&1; then
            _api_client="wget"
        elif command -v busybox >/dev/null 2>&1 && \
             busybox --list 2>/dev/null | grep -q "^wget$"; then
            _api_client="busybox-wget"
        fi

        _api_response=""
        _api_rc=1

        case "$_api_client" in
            curl)
                _api_response=$(curl -sS \
                    --max-time 10 \
                    -X POST \
                    -H "X-Watchdog-Token: $_tok" \
                    --data "" \
                    "http://127.0.0.1:$PORT/api/ensure_running_service" 2>&1)
                _api_rc=$?
                ;;
            wget)
                _api_response=$(wget -qO- \
                    --timeout=10 \
                    --header="X-Watchdog-Token: $_tok" \
                    --post-data="" \
                    "http://127.0.0.1:$PORT/api/ensure_running_service" 2>&1)
                _api_rc=$?
                ;;
            busybox-wget)
                _api_response=$(busybox wget -qO- \
                    --timeout=10 \
                    --header="X-Watchdog-Token: $_tok" \
                    --post-data="" \
                    "http://127.0.0.1:$PORT/api/ensure_running_service" 2>&1)
                _api_rc=$?
                ;;
            *)
                log_msg "⚠️ No HTTP client available (curl/wget/busybox-wget)"
                log_msg "   Watchdog will handle DNS restart via its own retry loop"
                ;;
        esac

        if [ -n "$_api_client" ]; then
            log_msg "   Client: $_api_client"
            log_msg "   API response: $_api_response (rc=$_api_rc)"

            if [ "$_api_rc" -eq 0 ]; then
                # --------------------------------------------------------
                # Extract the `action` field (best-effort).
                # --------------------------------------------------------
                # Response shapes:
                #   {"status":"ON",  "action":"none"}     — already running
                #   {"status":"ON",  "action":"started"}  — started now
                #   {"status":"OFF", "action":"skipped"}  — user wants OFF
                #
                # Substring match, not a JSON parse — keeps the
                # script POSIX-portable. Any unrecognized response
                # falls through to the generic "succeeded" message.
                case "$_api_response" in
                    *'"action":"started"'*)
                        log_msg "✅ DNS start requested successfully (action=started)"
                        ;;
                    *'"action":"none"'*)
                        log_msg "✅ DNS already running (action=none)"
                        ;;
                    *'"action":"skipped"'*)
                        log_msg "ℹ️ DNS restart skipped (action=skipped — user wants OFF)"
                        ;;
                    *)
                        log_msg "✅ DNS start requested successfully"
                        ;;
                esac
            else
                log_msg "⚠️ API call failed (rc=$_api_rc) — Watchdog will retry"
            fi
        fi
    else
        log_msg "⚠️ Watchdog token not ready — Watchdog will handle DNS"
    fi
else
    log_msg "ℹ️ User intent is OFF — skipping DNS auto-start"
fi

# ============================================================
# [20] Clean exit
# ============================================================
# All state has been logged. The root manager treats exit 0
# as "boot service completed". A non-zero exit is interpreted
# as "boot service failed" and may trigger a reboot loop.
exit 0