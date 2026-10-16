#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — service.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-15
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Boot service launcher (Magisk / KernelSU phase).
# Triggered automatically at sys.boot_completed = 1.
#
# Responsibilities:
#   • Wait for boot completion (multi-signal — see [12])
#   • Wait for network readiness (max 15 × 2s + 10 × 2s)
#   • Read webui.conf (with Port Guard — reject 8080)
#   • Verify WebUI binary exists
#   • Start WebUI (with one retry on failure)
#   • Launch Watchdog as a standalone process
#   • Respect the disable file (skip if present)
#   • Trigger a periodic auto-backup if needed
#   • Rotate old backups
#   • Clean up leftover COMMIT'd transactions
#   • Read .pending_notification (install → boot messaging)
#   • Log active profile + expected memory limit
#   • Ensure DNS starts after boot via a direct
#     /api/ensure_running_service call
#
# Design:
#   • Sources functions.sh (which sources boot-mini.sh).
#   • On functions.sh load failure, only the minimum
#     primitives are redefined inline so the WebUI can start
#     and the user can see what is broken. Advanced features
#     (firewall, backup, rotation) are skipped with a warning.
#   • Watchdog runs as a separate file so $$ inside it refers
#     to the real Watchdog PID (not service.sh's).
#   • All error paths are logged to dnscrypt_main.log.
#
# Module layout:
#   Shell scripts live in $MODDIR (NOT under proxy/).
#   Binaries and configs live under $MODDIR/proxy/.
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
# [2] Default paths (reconfigured after loading functions.sh)
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

# --- Reserved port (from boot-mini.sh if available; 8080 otherwise) ---
# The assignment is finalized after functions.sh is sourced.
_MONITORING_UI_PORT=""

# ============================================================
# [3] Log helper (fallback)
# ============================================================
# functions.sh sources boot-mini.sh which defines log_msg. If
# functions.sh is unavailable, this local version is used
# instead. No rotation — a single append per line.
log_msg() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE" 2>/dev/null
}

log_msg "service.sh started ($MODULE_VERSION)"

# ============================================================
# [4] Load functions.sh (sources boot-mini.sh)
# ============================================================
# functions.sh already calls init_runtime_paths() at source
# time. We only call it here as an idempotent fallback when
# $RUN_DIR_ACTIVE is still empty.
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
            log_msg "Runtime paths initialized (deferred, RUN_DIR was empty)"
        fi
    else
        log_msg "WARNING: functions.sh loaded but critical functions missing"
    fi
else
    log_msg "WARNING: functions.sh not found, using inline fallbacks"
fi

# Finalize _MONITORING_UI_PORT: prefer the value from
# boot-mini.sh (via functions.sh); fall back to 8080.
_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"

# ============================================================
# [5] Inline fallbacks (minimal)
# ============================================================
# If functions.sh failed to load, only the primitives required
# to start the WebUI are provided here. Every other feature
# (firewall, backup, rotation, cleanup) is skipped with a
# warning rather than silently reimplemented — the module is
# in a degraded state and the user must see it clearly.
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
# Three probes: /proc/net → ss → netstat.
# The trailing space in ":$hex_port " is required — without it,
# ":1F90" would also match ":1F90A".
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
# Uses plain `grep "^${key}="` — the `-F` flag would treat `^`
# as a literal character, defeating the anchor and always
# returning the default.
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
# Waits up to 35 s for the port to bind, and detects early
# process death (port collision) as a distinct failure mode.
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
# Each wrapper is defined in both branches of the if/else so
# the rest of the script reads identically regardless of
# whether functions.sh loaded.
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
# [7] Initial cleanup
# ============================================================
# Kill any leftover dnscrypt-proxy process from a previous run
# before the WebUI and DNS engine start. Defensive: the
# previous shutdown should have cleaned up, but a hard reboot
# (power loss, watchdog reset) can leave the process running.
#
# Note: cleanup_proxy does NOT touch the WebUI or the
# watchdog. Those are handled separately in [16] and [17].
do_cleanup_proxy
log_msg "Initial cleanup done"

# --- Cleanup leftover COMMIT'd transactions ---
# Defense-in-depth: main.go also does this at startup, but a
# boot-time cleanup catches the case where main.go never
# started.
do_cleanup_transactions

# ============================================================
# [7b] Read pending notification (if any)
# ============================================================
# customize.sh writes .pending_notification after a successful
# restore during an upgrade. main.go also reads this file at
# startup, but if the WebUI has not started yet we still want
# the boot log to reflect what happened during the install.
#
# We log the content but do NOT delete the file — main.go
# owns the deletion (it re-reads the file at startup).
if [ -f "$PENDING_NOTIFY_FILE" ]; then
    _pending_msg=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$_pending_msg" ]; then
        log_msg "📢 Install notification: $_pending_msg"
    fi
fi

# ============================================================
# [8] Migrate old PID files from /data/local/tmp
# ============================================================
# v1.2.0 migrated the runtime directory from /data/local/tmp to
# $MODDIR/proxy/run/. This section moves the surviving files
# from the legacy location to the new one on first boot after
# an upgrade.
#
# `dnscrypt.status` carries the user's ON/OFF intent and MUST
# NOT be deleted from /data/local/tmp unless the copy into
# $RUN_DIR_ACTIVE actually succeeded. On failure we keep the
# source and log a WARNING. PID files are transient and always
# safe to drop.
if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ] && \
   [ "$RUN_DIR_ACTIVE" != "/data/local/tmp" ]; then
    for _mf in dnscrypt.pid webui.pid watchdog.pid dnscrypt.status; do
        [ -f "/data/local/tmp/$_mf" ] || continue

        if [ "$_mf" = "dnscrypt.status" ]; then
            if [ -f "$RUN_DIR_ACTIVE/$_mf" ]; then
                # Already present in run/ — tmp copy is stale.
                rm -f "/data/local/tmp/$_mf" 2>/dev/null
            elif cp -f "/data/local/tmp/$_mf" "$RUN_DIR_ACTIVE/$_mf" 2>/dev/null; then
                log_msg "Migrated $_mf from tmp to run/"
                rm -f "/data/local/tmp/$_mf" 2>/dev/null
            else
                log_msg "WARNING: could not migrate $_mf — keeping /tmp copy"
            fi
        else
            # PID files are transient — always safe to drop.
            rm -f "/data/local/tmp/$_mf" 2>/dev/null
        fi
    done
fi

# ============================================================
# [9] Verify binary permissions
# ============================================================
# A manual reinstall or an unusual file-manager copy can strip
# the execute bit. This section re-applies it before the
# binaries are used.
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
# customize.sh writes /data/local/tmp/dnscrypt_credentials.txt
# on every install. Log a one-time hint on first boot so the
# user sees a clear pointer to their login file.
if [ -f "$CRED_FILE" ] && [ ! -f /data/local/tmp/.dnscrypt_credentials_shown ]; then
    log_msg "Login credentials are ready at: $CRED_FILE"
    touch /data/local/tmp/.dnscrypt_credentials_shown 2>/dev/null
fi

# ============================================================
# [11] If module is disabled → cleanup and exit
# ============================================================
# When the user disables the module, the manager touches a
# `disable` file in the module folder. The boot service
# respects that and:
#   1. Writes OFF to STATUS_FILE (user intent = off).
#   2. Cleans up the firewall.
#   3. Kills the DNS engine and WebUI processes.
#   4. Resets the system's private DNS mode to AUTO.
#   5. Exits cleanly with code 0.
#
# `settings delete global private_dns_mode` is wrapped in a
# bounded wait loop because the settings service may not be
# ready immediately after boot.
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
# Magisk triggers this script when `sys.boot_completed = 1`
# fires, but on some ROMs that property is set BEFORE the
# system is truly usable. The two most common symptoms of
# firing too early:
#
#   • `settings` service not yet available → private_dns_mode
#     reset fails silently
#   • Network stack partially initialized → the network wait
#     in [13] fails and the DNS engine starts without
#     reachability
#
# Fix: wait for TWO independent signals, in order.
#
#   Signal 1 (primary)   — `sys.boot_completed = 1`
#     Polled every 3 s, max 180 s (60 iterations).
#     A ROM that never sets this is broken; we still proceed
#     after the timeout with a warning.
#
#   Signal 2 (secondary) — boot animation has stopped
#     `init.svc.bootanim = stopped` OR
#     `service.bootanim.exit = 1`
#     Polled every 2 s, max 30 s (15 iterations).
#     Best-effort: some minimal ROMs do not define either
#     property. On timeout we proceed with a warning.
#
# A final 2-second grace period follows, letting the property
# observer settle before the network check in [13] begins.
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
# Two-stage network readiness check:
#
#   Stage 1 (30 seconds) — wait for a default route.
#   Stage 2 (20 seconds) — if no default route was seen, fall
#     back to a ping reachability check against two public DNS
#     servers.
#
# If neither succeeds within 50 seconds total, log a warning
# and proceed anyway. Refusing to start on a device with a
# slow network is worse than starting with a partially-
# initialized network: the DNS engine and WebUI can bind their
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
# Reads the values service.sh needs:
#   PORT               — WebUI listen port (default 9090)
#   AUTO_RESTART_DNS   — watchdog restarts DNS if it crashes
#   AUTO_RESTART_WEBUI — watchdog restarts WebUI if it dies
#
# `do_get_port` applies the Port Guard (rejects 8080) and the
# leading-zero-safe numeric check. The two AUTO_RESTART values
# are validated as either "0" or "1" — a value outside that
# set is normalized to "1".
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
# Purely informational. main.go remains the authority for the
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
# Triggers a backup of the 5 user config files to the
# persistent directory if the last one is older than 24 hours.
#
# `BACKUP_STATUS` distinguishes "created" from "skipped" by
# comparing the mtime of `.last_auto_backup` before and after
# the call. Consumed by the summary block in [18].
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
    # `^[0-9]{8}-[0-9]{6}-`. current/, txn-*, orphan-txn-*,
    # .restore_snap.*, and apk/ are excluded by the pattern.
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
# no way to interact with the module. Exit code 1 and write
# OFF to the status file so the user's intent is not left
# ambiguous.
WEBUI="$BIN_DIR/dnscrypt-webui"
if [ ! -f "$WEBUI" ]; then
    log_msg "ERROR: WebUI binary not found at $WEBUI"
    echo "OFF" > "$STATUS_FILE" 2>/dev/null
    exit 1
fi

# ============================================================
# [16] Start WebUI (two attempts)
# ============================================================
# Two attempts with a 3-second pause between them. Each
# attempt goes through `do_start_webui`, which:
#   • cleans up any leftover WebUI process,
#   • launches the binary via setsid/busybox-setsid/nohup,
#   • writes the PID file atomically,
#   • waits up to 35 seconds for the port to bind.
#
# Worst-case wall-clock for [16] = 2 × (35 + 3) = 76 seconds.
# On a healthy device, the first attempt succeeds in < 2 s.
WEBUI_STARTED=0
for _attempt in 1 2; do
    log_msg "WebUI start attempt $_attempt/2..."
    if do_start_webui "$WEBUI" "$PORT"; then
        WEBUI_STARTED=1
        log_msg "WebUI started (Port: $PORT)"
        break
    fi
    if [ "$_attempt" -lt 2 ]; then
        log_msg "WARNING: WebUI start attempt $_attempt failed, retrying in 3s..."
        sleep 3
    fi
done

if [ "$WEBUI_STARTED" != "1" ]; then
    log_msg "ERROR: WebUI failed to start after 2 attempts"
fi

# ============================================================
# [17] Watchdog — independent process
# ============================================================
# The watchdog is a SEPARATE PROCESS, not a subshell of this
# script. This is critical: inside watchdog.sh, `$$` must
# resolve to the watchdog's own PID (not service.sh's), so
# that its PID file and duplicate-instance guard work.
#
# WATCHDOG_SCRIPT lives in the module root ($MODDIR), NOT in
# $MODDIR/proxy/. Standard Magisk layout: shell scripts at the
# root, binaries and configs under proxy/.
#
# Launch strategy: mirrors _inline_start_webui and
# start_native_webui — setsid → busybox setsid → nohup.
#
# Arguments passed to watchdog.sh (5, in order):
#   1. WATCHDOG_PID_FILE
#   2. MODDIR
#   3. PORT
#   4. AUTO_RESTART_DNS
#   5. AUTO_RESTART_WEBUI
#
# After launch, wait up to 3 s for the PID file to appear.
WATCHDOG_SCRIPT="$MODDIR/watchdog.sh"

if [ ! -f "$WATCHDOG_SCRIPT" ]; then
    log_msg "ERROR: watchdog.sh not found at $WATCHDOG_SCRIPT"
    log_msg "   Watchdog will NOT be started — service continues without it"
else
    if [ ! -x "$WATCHDOG_SCRIPT" ]; then
        chmod 0755 "$WATCHDOG_SCRIPT" 2>/dev/null
    fi

    if command -v setsid >/dev/null 2>&1; then
        setsid "$WATCHDOG_SCRIPT" \
            "$WATCHDOG_PID_FILE" \
            "$MODDIR" \
            "$PORT" \
            "$AUTO_RESTART_DNS" \
            "$AUTO_RESTART_WEBUI" \
            >/dev/null 2>&1 < /dev/null &
    elif command -v busybox >/dev/null 2>&1 && \
         busybox --list 2>/dev/null | grep -q setsid; then
        busybox setsid "$WATCHDOG_SCRIPT" \
            "$WATCHDOG_PID_FILE" \
            "$MODDIR" \
            "$PORT" \
            "$AUTO_RESTART_DNS" \
            "$AUTO_RESTART_WEBUI" \
            >/dev/null 2>&1 < /dev/null &
    else
        nohup "$WATCHDOG_SCRIPT" \
            "$WATCHDOG_PID_FILE" \
            "$MODDIR" \
            "$PORT" \
            "$AUTO_RESTART_DNS" \
            "$AUTO_RESTART_WEBUI" \
            >/dev/null 2>&1 < /dev/null &
    fi

    # Wait up to 3 s for the PID file to appear.
    _wd_wait=0
    while [ "$_wd_wait" -lt 3 ] && [ ! -f "$WATCHDOG_PID_FILE" ]; do
        sleep 1
        _wd_wait=$((_wd_wait + 1))
    done

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

# ============================================================
# [18] Final structured summary
# ============================================================
# Compact, structured summary. Every field is emitted as a
# separate log line prefixed with a bullet point, so the boot
# log can be grepped for a specific field without parsing a
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
#   • ON  → call the API to ensure the DNS engine is running
#   • OFF → do nothing (user stopped it manually)
#
# Three-way HTTP client cascade:
#   The cascade tries curl → wget → busybox wget. Each attempt
#   is guarded by `command -v`, and the first that succeeds
#   returns immediately. If none is available, a clear warning
#   is logged and the watchdog's own retry loop takes over.
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
        # Try curl → wget → busybox wget. The first client whose
        # `command -v` succeeds is used.
        #
        # Both stdout and stderr are captured into
        # `_api_response` so a client-level error is preserved
        # in the boot log.
        # --------------------------------------------------------
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
                # The response is one of:
                #   {"status":"ON",  "action":"none"}     — already running
                #   {"status":"ON",  "action":"started"}  — started now
                #   {"status":"OFF", "action":"skipped"}  — user wants OFF
                #
                # Substring match, not a JSON parse — keeps the
                # script POSIX-portable. Any unrecognized response
                # falls through to the generic "succeeded" message.
                # --------------------------------------------------------
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

exit 0
