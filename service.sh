#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — service.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Boot service launcher (Magisk / KernelSU / APatch phase).
# Triggered at sys.boot_completed = 1.
#
# Sources functions.sh (which loads boot-mini.sh + all lib/).
# Delegates every process operation to lib/process.sh, every
# HTTP call to lib/http.sh, every backup to lib/backup.sh,
# and every firewall op to lib/firewall.sh.
#
# Design Notes:
#   • Watchdog is killed via /proc-based enumeration, preventing
#     orphan watchdogs from restarting a disabled service.
#   • STATUS_FILE is PRESERVED during disable. It encodes user
#     intent, not current state. On re-enable, DNS auto-starts
#     if the user's last action was ON.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path + version
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

MODULE_VERSION="v0.0.0-unknown"
[ -f "$MODDIR/module.prop" ] && \
    MODULE_VERSION=$(grep '^version=' "$MODDIR/module.prop" 2>/dev/null \
        | head -n1 | cut -d= -f2- | tr -d '\r ')

case "${1:-}" in
    --version)
        echo "$0: $MODULE_VERSION"
        exit 0
        ;;
esac

# ============================================================
# [2] Load functions.sh (boot-mini + lib/)
# ============================================================
if [ ! -f "$MODDIR/functions.sh" ]; then
    echo "service.sh: functions.sh missing" >&2
    exit 1
fi

# shellcheck disable=SC1090
. "$MODDIR/functions.sh" 2>/dev/null

if ! command -v cleanup_proxy >/dev/null 2>&1 \
   || ! command -v start_native_webui >/dev/null 2>&1; then
    echo "service.sh: functions.sh failed to load required symbols" >&2
    exit 1
fi

log_msg "service.sh started ($MODULE_VERSION)"

# ============================================================
# [3] Cleanup leftovers
# ============================================================
cleanup_proxy
cleanup_old_transactions 2>/dev/null || true
log_msg "Initial cleanup done"

# ============================================================
# [4] Pending notification (informational only)
# ============================================================
if [ -f "$PENDING_NOTIFY_FILE" ]; then
    _pn=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
    [ -n "$_pn" ] && log_msg "📢 Install notification: $_pn"
fi

# ============================================================
# [5] Migrate legacy /data/local/tmp files
# ============================================================
if [ -n "$RUN_DIR_ACTIVE" ] && [ "$RUN_DIR_ACTIVE" != "/data/local/tmp" ]; then
    for _mf in dnscrypt.pid webui.pid watchdog.pid dnscrypt.status; do
        [ -f "/data/local/tmp/$_mf" ] || continue

        if [ "$_mf" = "dnscrypt.status" ]; then
            if [ -f "$RUN_DIR_ACTIVE/$_mf" ]; then
                rm -f "/data/local/tmp/$_mf" 2>/dev/null
            elif cp -f "/data/local/tmp/$_mf" "$RUN_DIR_ACTIVE/$_mf" 2>/dev/null; then
                chmod 0600 "$RUN_DIR_ACTIVE/$_mf" 2>/dev/null
                log_msg "Migrated $_mf from /tmp to run/"
                rm -f "/data/local/tmp/$_mf" 2>/dev/null
            else
                log_msg "WARNING: could not migrate $_mf (kept /tmp copy)"
            fi
        else
            rm -f "/data/local/tmp/$_mf" 2>/dev/null
        fi
    done
fi

# ============================================================
# [6] Fix binary permissions
# ============================================================
[ -f "$PROXY_BIN" ] && [ ! -x "$PROXY_BIN" ] && \
    chmod 0755 "$PROXY_BIN" 2>/dev/null && log_msg "Fixed permissions: dnscrypt-proxy"
[ -f "$WEBUI_BIN" ] && [ ! -x "$WEBUI_BIN" ] && \
    chmod 0755 "$WEBUI_BIN" 2>/dev/null && log_msg "Fixed permissions: dnscrypt-webui"

# ============================================================
# [7] One-time credentials notification
# ============================================================
if [ -f "$CRED_FILE" ] && [ ! -f /data/local/tmp/.dnscrypt_credentials_shown ]; then
    log_msg "Login credentials: $CRED_FILE"
    touch /data/local/tmp/.dnscrypt_credentials_shown 2>/dev/null
fi

# ============================================================
# [8] Disable path
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    log_msg "Module is DISABLED — cleaning up before exit"

    # Kill in dependency order: watchdog first so it does not
    # resurrect the WebUI while we are stopping it.
    kill_watchdogs_safely 30 2>/dev/null || true
    cleanup_webui 2>/dev/null || true
    cleanup_proxy 2>/dev/null || true
    log_msg "Processes terminated (watchdog → webui → proxy)"

    firewall_cleanup 2>/dev/null || true
    log_msg "Firewall cleaned"

    # Reset system DNS — the module's redirect no longer exists.
    if command -v settings >/dev/null 2>&1; then
        _wait=0
        while [ "$_wait" -lt 5 ]; do
            settings get global private_dns_mode >/dev/null 2>&1 && break
            sleep 1
            _wait=$((_wait + 1))
        done
        settings delete global private_dns_mode 2>/dev/null \
            && log_msg "private_dns_mode reset to AUTO"
    fi

    command -v ndc >/dev/null 2>&1 && \
        ndc resolver flushdefaultif 2>/dev/null

    # STATUS_FILE is deliberately NOT modified.
    log_msg "STATUS_FILE preserved (user intent kept: $(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n '))"
    log_msg "Module disabled cleanup complete"
    exit 0
fi

# ============================================================
# [9] Wait for boot completion (multi-signal)
# ============================================================
_wait=0
_max=60
_boot_done=0

while [ "$_wait" -lt "$_max" ]; do
    if [ "$(getprop sys.boot_completed 2>/dev/null || printf '0')" = "1" ]; then
        _boot_done=1
        break
    fi
    sleep 3
    _wait=$((_wait + 1))
done

if [ "$_boot_done" = "1" ]; then
    log_msg "Boot completed (${_wait}x3s)"
else
    log_msg "WARNING: sys.boot_completed not set after ${_max}x3s — proceeding"
fi

# Second signal: boot animation stopped
_anim_wait=0
_anim_max=15
_bootanim_ready=0

while [ "$_anim_wait" -lt "$_anim_max" ]; do
    _state=$(getprop init.svc.bootanim 2>/dev/null)
    _exit=$(getprop service.bootanim.exit 2>/dev/null)
    if [ "$_state" = "stopped" ] || [ "$_exit" = "1" ]; then
        _bootanim_ready=1
        break
    fi
    sleep 2
    _anim_wait=$((_anim_wait + 1))
done

[ "$_bootanim_ready" = "1" ] && log_msg "Boot animation stopped" \
    || log_msg "WARNING: boot animation still running after ${_anim_max}x2s"

sleep 2

# ============================================================
# [10] Wait for network readiness
# ============================================================
net_wait=0
while [ "$net_wait" -lt 15 ]; do
    if command -v ip >/dev/null 2>&1; then
        ip route 2>/dev/null | grep -q 'default' && break
        ip -6 route 2>/dev/null | grep -q 'default' && break
    elif command -v busybox >/dev/null 2>&1; then
        busybox ip route 2>/dev/null | grep -q 'default' && break
        busybox ip -6 route 2>/dev/null | grep -q 'default' && break
    fi
    sleep 2
    net_wait=$((net_wait + 1))
done

if [ "$net_wait" -ge 15 ]; then
    log_msg "WARNING: no default route after 30s — probing via ping"
    dns_wait=0
    while [ "$dns_wait" -lt 10 ]; do
        if ping_reachable 9.9.9.9 2 2>/dev/null || \
           ping_reachable 2620:fe::fe 2 2>/dev/null; then
            log_msg "Network reachable via ping"
            break
        fi
        sleep 2
        dns_wait=$((dns_wait + 1))
    done
    [ "$dns_wait" -ge 10 ] && log_msg "WARNING: still offline after 50s — proceeding"
fi
log_msg "Network ready (route wait: $((net_wait * 2))s)"

# ============================================================
# [11] Read webui.conf with Port Guards
# ============================================================
PORT=$(get_webui_port "$WEBUI_CONF")
[ -z "$PORT" ] && PORT="$DEFAULT_WEBUI_PORT"

AUTO_RESTART_DNS=$(get_auto_restart_dns "$WEBUI_CONF")
AUTO_RESTART_WEBUI=$(get_auto_restart_webui "$WEBUI_CONF")

case "$AUTO_RESTART_DNS"   in 0|1) ;; *) AUTO_RESTART_DNS="1"   ;; esac
case "$AUTO_RESTART_WEBUI" in 0|1) ;; *) AUTO_RESTART_WEBUI="1" ;; esac

log_msg "WebUI port: $PORT"
log_msg "AUTO_RESTART_DNS=$AUTO_RESTART_DNS AUTO_RESTART_WEBUI=$AUTO_RESTART_WEBUI"
log_msg "Runtime dir: $RUN_DIR_ACTIVE"

# ============================================================
# [12] Profile + memory hint (informational)
# ============================================================
ACTIVE_PROFILE="pro"
[ -f "$SELECTED_PROFILE_FILE" ] && {
    _sp=$(cat "$SELECTED_PROFILE_FILE" 2>/dev/null | tr -d '\r\n ')
    case "$_sp" in light|normal|pro|proplus|ultimate) ACTIVE_PROFILE="$_sp" ;; esac
}

MEMORY_HINT=$(get_profile_memory_hint 2>/dev/null)
[ -z "$MEMORY_HINT" ] && MEMORY_HINT="unknown"
log_msg "Active profile: $ACTIVE_PROFILE (memory: $MEMORY_HINT)"

# ============================================================
# [13] Auto-backup if needed
# ============================================================
BACKUP_STATUS="not-attempted"
BACKUP_COUNT="0"
LAST_STABLE_NAME=""

log_msg "🔄 Checking auto-backup state (interval=${AUTO_BACKUP_INTERVAL}s)"

_marker_before=0
[ -f "$LAST_AUTO_BACKUP_MARKER" ] && {
    _marker_before=$(stat -c %Y "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
        || _marker_before=$(stat -f %m "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
        || _marker_before=0
}

if auto_backup_if_needed "$AUTO_BACKUP_INTERVAL"; then
    _marker_after=0
    [ -f "$LAST_AUTO_BACKUP_MARKER" ] && {
        _marker_after=$(stat -c %Y "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
            || _marker_after=$(stat -f %m "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
            || _marker_after=0
    }
    case "$_marker_before" in ''|*[!0-9]*) _marker_before=0 ;; esac
    case "$_marker_after"  in ''|*[!0-9]*) _marker_after=0  ;; esac

    if [ "$_marker_after" -gt 0 ] && [ "$_marker_after" != "$_marker_before" ]; then
        BACKUP_STATUS="created"
        log_msg "✅ Auto-backup created"
    else
        BACKUP_STATUS="skipped"
        log_msg "ℹ️ Auto-backup skipped (recent snapshot exists)"
    fi
else
    BACKUP_STATUS="failed"
    log_msg "⚠️ Auto-backup failed (non-fatal)"
fi

rotate_backups "$BACKUP_ROTATION_KEEP" 2>/dev/null && \
    log_msg "✅ Backup rotation (keep $BACKUP_ROTATION_KEEP)"

BACKUP_COUNT=$(count_snapshots 2>/dev/null)
case "$BACKUP_COUNT" in ''|*[!0-9]*) BACKUP_COUNT=0 ;; esac

LAST_STABLE_NAME=$(read_last_stable 2>/dev/null)
[ -z "$LAST_STABLE_NAME" ] && LAST_STABLE_NAME="(none yet)"

# ============================================================
# [14] Verify WebUI binary
# ============================================================
if [ ! -f "$WEBUI_BIN" ]; then
    log_msg "ERROR: WebUI binary not found: $WEBUI_BIN"
    exit 1
fi

# ============================================================
# [15] Start WebUI
# ============================================================
WEBUI_STARTED=0

log_msg "🧹 Killing any existing WebUI..."
kill_webui_safely 50 || log_msg "⚠️ WebUI survived 5s — proceeding anyway"

if ! wait_port_free "$PORT" tcp 30; then
    log_msg "⚠️ Port $PORT still held, forcing cleanup"
    command -v fuser >/dev/null 2>&1 && { fuser -k "$PORT/tcp" 2>/dev/null; sleep 1; }
    wait_port_free "$PORT" tcp 30 || log_msg "❌ Port $PORT still in use"
fi

_attempt=0
while [ "$_attempt" -lt 2 ]; do
    _attempt=$((_attempt + 1))
    log_msg "WebUI start attempt $_attempt/2"

    if start_native_webui "$WEBUI_BIN" "$PORT"; then
        WEBUI_STARTED=1
        log_msg "✅ WebUI started (port $PORT)"
        break
    fi

    [ "$_attempt" -lt 2 ] && {
        log_msg "WARNING: attempt $_attempt failed — retrying in 3s"
        kill_webui_safely 50 || true
        wait_port_free "$PORT" tcp 30 || true
        sleep 3
    }
done

[ "$WEBUI_STARTED" != "1" ] && log_msg "ERROR: WebUI failed after 2 attempts"

# Verify exactly one instance
if [ "$WEBUI_STARTED" = "1" ]; then
    sleep 1
    _wb=$(list_pids_by_comm "dnscrypt-webui" 2>/dev/null | wc -w | tr -d ' ')
    case "$_wb" in
        1) log_msg "✅ WebUI verification: 1 instance" ;;
        0) log_msg "❌ WebUI verification: 0 instances"; WEBUI_STARTED=0 ;;
        *) log_msg "⚠️ WebUI verification: $_wb instances (expected 1)" ;;
    esac
fi

# ============================================================
# [16] Start Watchdog (single instance)
# ============================================================
WATCHDOG_SCRIPT="$MODDIR/watchdog.sh"

if [ ! -f "$WATCHDOG_SCRIPT" ]; then
    log_msg "ERROR: watchdog.sh not found — continuing without watchdog"
else
    [ ! -x "$WATCHDOG_SCRIPT" ] && chmod 0755 "$WATCHDOG_SCRIPT" 2>/dev/null

    log_msg "🧹 Killing any existing Watchdog..."
    kill_watchdogs_safely 30 || {
        log_msg "⚠️ Watchdogs survived 3s — force-killing"
        _pids=$(list_pids_by_cmdline "/watchdog.sh" 2>/dev/null)
        if [ -n "$_pids" ]; then
            # shellcheck disable=SC2086
            kill -9 $_pids 2>/dev/null
        fi
        sleep 2
    }

    _remaining=$(count_watchdogs)
    case "$_remaining" in ''|*[!0-9]*) _remaining=0 ;; esac

    rm -f "$WATCHDOG_PID_FILE" 2>/dev/null

    if [ "$_remaining" -gt 0 ]; then
        log_msg "⚠️ $_remaining watchdog(s) still alive — skipping launch to avoid duplication"
    else
        log_msg "✅ Previous watchdogs cleared"

        if command -v nohup >/dev/null 2>&1; then
            nohup "$WATCHDOG_SCRIPT" \
                "$WATCHDOG_PID_FILE" "$MODDIR" "$PORT" \
                "$AUTO_RESTART_DNS" "$AUTO_RESTART_WEBUI" \
                >/dev/null 2>&1 < /dev/null &
            log_msg "Watchdog launched via nohup"
        elif command -v setsid >/dev/null 2>&1; then
            setsid "$WATCHDOG_SCRIPT" \
                "$WATCHDOG_PID_FILE" "$MODDIR" "$PORT" \
                "$AUTO_RESTART_DNS" "$AUTO_RESTART_WEBUI" \
                >/dev/null 2>&1 < /dev/null &
            log_msg "Watchdog launched via setsid"
        else
            "$WATCHDOG_SCRIPT" \
                "$WATCHDOG_PID_FILE" "$MODDIR" "$PORT" \
                "$AUTO_RESTART_DNS" "$AUTO_RESTART_WEBUI" \
                >/dev/null 2>&1 < /dev/null &
            log_msg "Watchdog launched via direct background"
        fi

        # Wait for PID file, then verify single instance with
        # settle-retry to absorb fork/exec transients.
        _wait=0
        while [ "$_wait" -lt 5 ] && [ ! -f "$WATCHDOG_PID_FILE" ]; do
            sleep 1
            _wait=$((_wait + 1))
        done

        _wd=0
        _retry=0
        while [ "$_retry" -lt 5 ]; do
            _wd=$(count_watchdogs)
            case "$_wd" in ''|*[!0-9]*) _wd=0 ;; esac
            [ "$_wd" -le 1 ] && break
            sleep 1
            _retry=$((_retry + 1))
        done

        case "$_wd" in
            1) _wd_pid=$(read_pid_file "$WATCHDOG_PID_FILE" 2>/dev/null)
               log_msg "✅ Watchdog started (PID ${_wd_pid:-unknown})" ;;
            0) log_msg "❌ Watchdog failed to start" ;;
            *) log_msg "⚠️ CRITICAL: $_wd watchdog instances" ;;
        esac
    fi
fi

# ============================================================
# [17] Structured summary
# ============================================================
log_msg "─────────────────────────────────────────────"
log_msg "service.sh summary ($MODULE_VERSION):"
log_msg "  • WebUI:        port $PORT (started=$([ "$WEBUI_STARTED" = "1" ] && echo yes || echo no))"
log_msg "  • Profile:      $ACTIVE_PROFILE (memory: $MEMORY_HINT)"
log_msg "  • Auto-restart: DNS=$AUTO_RESTART_DNS WebUI=$AUTO_RESTART_WEBUI"
log_msg "  • Auto-backup:  $BACKUP_STATUS"
log_msg "  • Snapshots:    $BACKUP_COUNT"
log_msg "  • Last stable:  $LAST_STABLE_NAME"
log_msg "─────────────────────────────────────────────"

# ============================================================
# [18] Ensure DNS starts after boot
# ============================================================
log_msg "🔧 Ensuring DNS starts after boot..."

_wait_webui=0
_wait_max=60
while [ "$_wait_webui" -lt "$_wait_max" ]; do
    if [ -f "$WATCHDOG_TOKEN_FILE" ] && \
       [ -n "$(cat "$WATCHDOG_TOKEN_FILE" 2>/dev/null)" ] && \
       is_port_open "$PORT" tcp; then
        log_msg "✅ WebUI ready after ${_wait_webui}s"
        break
    fi
    sleep 2
    _wait_webui=$((_wait_webui + 2))
done

[ "$_wait_webui" -ge "$_wait_max" ] && \
    log_msg "⚠️ WebUI not ready after ${_wait_max}s — proceeding anyway"

_dns_intent=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
[ -z "$_dns_intent" ] && _dns_intent="OFF"
log_msg "DNS intent: $_dns_intent"

if [ "$_dns_intent" = "ON" ]; then
    _tok=$(get_watchdog_token 2>/dev/null)
    if [ -z "$_tok" ] || [ "${#_tok}" -lt 32 ]; then
        log_msg "⚠️ Watchdog token not ready — watchdog will handle DNS"
    else
        log_msg "Calling ensure_running_service API..."
        HTTP_CAPTURE_BODY=1 http_post \
            "http://127.0.0.1:$PORT/api/ensure_running_service" \
            "" "X-Watchdog-Token: $_tok"
        _rc=$?

        case "$_rc" in
            0)
                case "$HTTP_BODY" in
                    *'"action":"started"'*) log_msg "✅ DNS start requested (action=started)" ;;
                    *'"action":"none"'*)    log_msg "✅ DNS already running (action=none)" ;;
                    *'"action":"skipped"'*) log_msg "ℹ️ DNS restart skipped (action=skipped)" ;;
                    *)                       log_msg "✅ DNS API OK (HTTP $HTTP_CODE)" ;;
                esac
                ;;
            3) log_msg "⚠️ API rate-limited (HTTP 429) — watchdog will retry" ;;
            *) log_msg "⚠️ API failed: $HTTP_ERROR — watchdog will retry" ;;
        esac
    fi
else
    log_msg "ℹ️ User intent is OFF — skipping DNS auto-start"
fi

log_msg "service.sh exiting cleanly"
exit 0