#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — action.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
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
#   action.sh --diagnose     Full diagnostic (delegates to status.sh)
#   action.sh --backup       Trigger an immediate backup
#   action.sh --help         Show help
#   action.sh --version      Show version
#
# Exit codes:
#   0   = success
#   1   = error (startup failed)
#   2   = module disabled
#   3   = backup failed (--backup only)
#   130 = interrupted (SIGINT)
#   143 = terminated (SIGTERM)
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
    --version) echo "$0: $MODULE_VERSION"; exit 0 ;;
esac

# ============================================================
# [2] Load functions.sh (boot-mini + lib/)
# ============================================================
if [ ! -f "$MODDIR/functions.sh" ]; then
    echo "action.sh: functions.sh missing" >&2
    exit 1
fi

# shellcheck disable=SC1090
. "$MODDIR/functions.sh" 2>/dev/null

if ! command -v start_native_webui >/dev/null 2>&1 \
   || ! command -v is_port_open >/dev/null 2>&1; then
    echo "action.sh: functions.sh failed to load required symbols" >&2
    exit 1
fi

# ============================================================
# [3] Parse arguments
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
        --help|-h)
            cat <<EOF
DNSCrypt Smart Filter – action.sh ${MODULE_VERSION}

Usage:
  action.sh                Start WebUI and open browser
  action.sh --restart      Force restart WebUI
  action.sh --status       Show WebUI status only
  action.sh --check        Comprehensive status
  action.sh --diagnose     Full diagnostic (runs status.sh)
  action.sh --backup       Trigger an immediate manual backup
  action.sh --help         Show this help
  action.sh --version      Show version

Exit codes:
  0   = success
  1   = error (startup failed)
  2   = module disabled
  3   = backup failed (--backup only)
  130 = interrupted (SIGINT)
  143 = terminated (SIGTERM)

EOF
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $arg"
            echo "Use --help for assistance"
            exit 1
            ;;
    esac
done

# ============================================================
# [4] Resolve port once
# ============================================================
PORT=$(get_webui_port "$WEBUI_CONF" 2>/dev/null)
[ -z "$PORT" ] && PORT="$DEFAULT_WEBUI_PORT"

# ============================================================
# [5] Mode: --status (read-only, no lock)
# ============================================================
if [ "$STATUS_ONLY" = "1" ]; then
    if is_port_open "$PORT" tcp; then
        printf "✅ WebUI is RUNNING on port %s\n" "$PORT"
        exit 0
    else
        printf "❌ WebUI is NOT running on port %s\n" "$PORT"
        exit 1
    fi
fi

# ============================================================
# [6] Mode: --diagnose (delegates to status.sh)
# ============================================================
if [ "$DIAGNOSE_MODE" = "1" ]; then
    STATUS_SCRIPT="$MODDIR/status.sh"

    if [ -f "$STATUS_SCRIPT" ]; then
        [ ! -x "$STATUS_SCRIPT" ] && chmod 0755 "$STATUS_SCRIPT" 2>/dev/null
        if [ -x "$STATUS_SCRIPT" ]; then
            exec "$STATUS_SCRIPT" --diagnose
        else
            exec sh "$STATUS_SCRIPT" --diagnose
        fi
    fi

    echo "⚠️ status.sh not found — falling back to --check mode"
    echo ""
    CHECK_MODE=1
fi

# ============================================================
# [7] Mode: --backup
# ============================================================
if [ "$BACKUP_MODE" = "1" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║  💾 DNSCrypt – Manual Backup                 ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""

    if [ ! -d "$BIN_DIR" ]; then
        echo "❌ Module directory not found: $BIN_DIR"
        exit 3
    fi

    echo "  Source: $BIN_DIR"
    echo "  Target: $PERSISTENT_BACKUP"
    echo ""

    if backup_create "$BIN_DIR" "" "$MODULE_VERSION" "manual-cli:$$"; then
        rotate_backups "$BACKUP_ROTATION_KEEP" 2>/dev/null || true

        echo ""
        echo "  ✅ Backup completed: $BACKUP_CREATED_PATH"
        echo ""
        echo "  Snapshots: $(count_snapshots) total"
        _last=$(read_last_stable 2>/dev/null)
        [ -n "$_last" ] && echo "  Last stable: $_last"
        echo ""

        log_msg "action.sh --backup: created $BACKUP_CREATED_PATH"
        exit 0
    else
        echo ""
        echo "  ❌ Backup failed"
        log_msg "action.sh --backup: failed"
        exit 3
    fi
fi

# ============================================================
# [8] Mode: --check
# ============================================================
if [ "$CHECK_MODE" = "1" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    printf "║  🔍 DNSCrypt %-8s – System Check     ║\n" "$MODULE_VERSION"
    echo "╚══════════════════════════════════════════════╝"
    echo ""

    # --- Service Status ---
    echo "─── Service Status ────────────────────────"
    if is_port_open "$PORT" tcp; then
        printf "  🟢 WebUI    : Running on port %s\n" "$PORT"
    else
        printf "  🔴 WebUI    : Stopped\n"
    fi

    if is_dnscrypt_running; then
        printf "  🟢 DNS      : Running on %s/UDP\n" "$DNS_ENGINE_PORT"
    else
        printf "  🔴 DNS      : Stopped\n"
    fi

    _wd_pid=$(read_pid_file "$WATCHDOG_PID_FILE" 2>/dev/null)
    if [ -n "$_wd_pid" ]; then
        printf "  🐕 Watchdog : Running (PID: %s)\n" "$_wd_pid"
    else
        _wd_count=$(count_watchdogs)
        case "$_wd_count" in
            0) printf "  🐕 Watchdog : inactive\n" ;;
            *) printf "  ⚠️  Watchdog : %s instances (PID file missing)\n" "$_wd_count" ;;
        esac
    fi
    echo ""

    # --- Runtime ---
    echo "─── Runtime ────────────────────────────────"
    printf "  📁 run/     : %s\n" "$RUN_DIR_ACTIVE"

    _intent="(no file)"
    if [ -f "$STATUS_FILE" ]; then
        _intent=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
        [ -z "$_intent" ] && _intent="(empty)"
    fi
    printf "  📄 Intent   : %s\n" "$_intent"
    printf "  🏷️  Version  : %s\n" "$MODULE_VERSION"
    printf "  📚 functions: ✅ loaded\n"
    echo ""

    # --- Configuration ---
    echo "─── Configuration ──────────────────────────"
    _dash=$(get_dashboard_port "$WEBUI_CONF")
    [ -z "$_dash" ] && _dash="$DEFAULT_DASHBOARD_PORT"
    printf "  🌐 WebUI port    : %s\n" "$PORT"
    printf "  📈 Dashboard port: %s\n" "$_dash"

    _adns=$(get_auto_restart_dns "$WEBUI_CONF")
    _aweb=$(get_auto_restart_webui "$WEBUI_CONF")
    printf "  🔄 Auto-DNS      : %s\n" "$([ "$_adns" = "1" ] && echo enabled || echo disabled)"
    printf "  🔄 Auto-WebUI    : %s\n" "$([ "$_aweb" = "1" ] && echo enabled || echo disabled)"

    _bind=$(read_conf "$WEBUI_CONF" "BIND_ADDR" "127.0.0.1")
    printf "  🔌 BIND_ADDR     : %s\n" "$_bind"
    echo ""

    # --- Profile & Memory ---
    echo "─── Profile & Memory ───────────────────────"
    _prof="pro"
    if [ -f "$SELECTED_PROFILE_FILE" ]; then
        _sp=$(cat "$SELECTED_PROFILE_FILE" 2>/dev/null | tr -d '\r\n ')
        case "$_sp" in light|normal|pro|proplus|ultimate) _prof="$_sp" ;; esac
    fi
    printf "  📋 Profile       : %s\n" "$_prof"
    printf "  🧠 Memory limit  : %s\n" "$(get_profile_memory_hint)"
    printf "  ℹ️  Managed by    : main.go (Go runtime soft limit)\n"
    echo ""

    # --- Backup & Recovery ---
    echo "─── Backup & Recovery ──────────────────────"
    _snaps=$(count_snapshots 2>/dev/null)
    case "$_snaps" in ''|*[!0-9]*) _snaps=0 ;; esac

    _txn=0
    if [ -d "$PERSISTENT_BACKUP" ]; then
        _txn=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && ls -1d txn-*/ 2>/dev/null | wc -l | tr -d ' ')
        case "$_txn" in ''|*[!0-9]*) _txn=0 ;; esac
    fi

    _orph=0
    if [ -d "$PERSISTENT_BACKUP" ]; then
        _orph=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && ls -1d orphan-txn-*/ 2>/dev/null | wc -l | tr -d ' ')
        case "$_orph" in ''|*[!0-9]*) _orph=0 ;; esac
    fi

    printf "  💾 Snapshots     : %s\n" "$_snaps"
    printf "  📁 Path          : %s\n" "$PERSISTENT_BACKUP"

    [ "$_txn" -gt 0 ]  && printf "  ⏳ In-flight txn : %s (install may be in progress)\n" "$_txn"
    [ "$_orph" -gt 0 ] && printf "  🗃️  Orphan txn    : %s (from interrupted install)\n" "$_orph"

    _ls=$(read_last_stable 2>/dev/null)
    [ -n "$_ls" ] && printf "  🎯 Last stable   : %s\n" "$_ls"

    _marker_mtime=0
    [ -f "$LAST_AUTO_BACKUP_MARKER" ] && {
        _marker_mtime=$(stat -c %Y "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
            || _marker_mtime=$(stat -f %m "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
            || _marker_mtime=0
    }
    case "$_marker_mtime" in ''|*[!0-9]*) _marker_mtime=0 ;; esac
    if [ "$_marker_mtime" -gt 0 ]; then
        _now=$(date +%s 2>/dev/null)
        case "$_now" in ''|*[!0-9]*) _now=0 ;; esac
        if [ "$_now" -gt 0 ]; then
            _age=$((_now - _marker_mtime))
            if [ "$_age" -lt 60 ]; then _age_str="${_age}s ago"
            elif [ "$_age" -lt 3600 ]; then _age_str="$((_age / 60))m ago"
            elif [ "$_age" -lt 86400 ]; then _age_str="$((_age / 3600))h ago"
            else _age_str="$((_age / 86400))d ago"
            fi
            printf "  🔄 Auto-backup   : %s\n" "$_age_str"
        fi
    fi

    _trigger=$(get_recovery_trigger "$MODDIR")
    if [ -f "$_trigger" ] || [ -f "$RECOVERY_TRIGGER_2" ]; then
        printf "  🚨 Recovery mode : TRIGGER PRESENT — next install will restore\n"
    fi

    if [ -f "$PENDING_NOTIFY_FILE" ]; then
        _pn=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
        [ -n "$_pn" ] && printf "  📢 Notification  : %s\n" "$_pn"
    fi

    printf "  ℹ️  Recovery      : touch %s && reboot\n" "$_trigger"
    echo ""

    [ -f "$MODDIR/disable" ] && printf "  ⚠️  Module        : DISABLED (remove 'disable' to enable)\n"

    if [ -f "$CRED_FILE" ]; then
        printf "  🔐 Credentials   : available\n"
    else
        printf "  ⚠️  Credentials   : missing\n"
    fi

    echo ""
    echo "  🌐 Open: http://127.0.0.1:$PORT"
    echo "  ℹ️  Full diagnostic: action.sh --diagnose"
    echo ""
    exit 0
fi

# ============================================================
# [9] Disable check
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    log_msg "action.sh: module disabled, refusing to start"
    printf "⚠️  Module is disabled.\n"
    printf "Enable it first from Magisk/KernelSU.\n"
    exit 2
fi

# ============================================================
# [10] Verify WebUI binary
# ============================================================
if [ ! -f "$WEBUI_BIN" ]; then
    log_msg "action.sh: WebUI binary missing: $WEBUI_BIN"
    printf "❌ WebUI binary not found.\n"
    printf "Try reinstalling the module.\n"
    exit 1
fi

# ============================================================
# [11] Acquire action lock
# ============================================================
_lock=$(get_lock_path "action-start")
if ! acquire_lock "$_lock" 60; then
    log_msg "action.sh: action lock timeout — another action is running"
    printf "⚠️  Another action is in progress.\n"
    printf "   If WebUI is starting, wait a few seconds and try again.\n"
    exit 1
fi
trap 'release_lock "$_lock"' EXIT
trap 'release_lock "$_lock"; exit 130' INT
trap 'release_lock "$_lock"; exit 143' TERM

# ============================================================
# [12] Start / restart WebUI
# ============================================================
STARTED_NOW=0

if [ "$FORCE_RESTART" = "1" ]; then
    log_msg "action.sh: --restart requested"
    printf "🔄 Restarting WebUI...\n"
    STARTED_NOW=1
elif ! is_port_open "$PORT" tcp; then
    log_msg "action.sh: WebUI not running, starting"
    printf "▶️  Starting WebUI...\n"
    STARTED_NOW=1
fi

if [ "$STARTED_NOW" = "1" ]; then
    cleanup_orphans 2>/dev/null || true

    if ! start_native_webui "$WEBUI_BIN" "$PORT"; then
        log_msg "action.sh: start_native_webui failed"
        printf "❌ Failed to start WebUI.\n"
        printf "Check %s\n" "$LOG_FILE"
        exit 1
    fi

    log_msg "action.sh: WebUI started on port $PORT"
    printf "✅ WebUI started on port %s\n" "$PORT"
else
    log_msg "action.sh: WebUI already running on port $PORT"
    printf "ℹ️  WebUI is already running on port %s\n" "$PORT"
fi

# Brief settle before opening the browser.
[ "$STARTED_NOW" = "1" ] && sleep 1

# ============================================================
# [13] Open browser (5 fallback strategies)
# ============================================================
_run_am() {
    local _timeout_s="$1"
    shift
    if [ -n "${TIMEOUT_CMD:-}" ]; then
        # shellcheck disable=SC2086
        $TIMEOUT_CMD "$_timeout_s" am "$@"
    else
        am "$@"
    fi
}

_open_browser() {
    local url="http://127.0.0.1:$1"

    log_msg "action.sh: opening browser at $url"
    printf "🌐 Opening: %s\n" "$url"

    # Strategy 1: standard blocking am start
    if _run_am 5 start --user 0 -W \
        -a android.intent.action.VIEW \
        -d "$url" \
        --activity-clear-top >/dev/null 2>&1; then
        log_msg "action.sh: browser via am start (standard)"
        printf "✅ Browser opened.\n"
        return 0
    fi

    # Strategy 2: resolve default browser package, then explicit
    local pkg
    pkg=$(cmd package resolve-activity --brief \
        -a android.intent.action.VIEW \
        -d "http://example.com" 2>/dev/null \
        | tail -n 1)

    if [ -n "$pkg" ] && [ "$pkg" != "No activity found" ]; then
        if _run_am 5 start --user 0 -W \
            -a android.intent.action.VIEW \
            -d "$url" \
            -n "$pkg" >/dev/null 2>&1; then
            log_msg "action.sh: browser via explicit package: $pkg"
            printf "✅ Browser opened.\n"
            return 0
        fi
    fi

    # Strategy 3: no --user flag
    if _run_am 5 start \
        -a android.intent.action.VIEW \
        -d "$url" >/dev/null 2>&1; then
        log_msg "action.sh: browser via am start (no --user)"
        printf "✅ Browser opened.\n"
        return 0
    fi

    # Strategy 4: new task
    if _run_am 5 start --activity-new-task \
        -a android.intent.action.VIEW \
        -d "$url" >/dev/null 2>&1; then
        log_msg "action.sh: browser via am start (new task)"
        printf "✅ Browser opened.\n"
        return 0
    fi

    # Strategy 5: async fire-and-forget
    (
        _run_am 5 start \
            -a android.intent.action.VIEW \
            -d "$url" >/dev/null 2>&1
    ) &
    sleep 0.3
    log_msg "action.sh: browser via am start (async)"
    printf "✅ Browser opened (async).\n"
    return 0
}

_open_browser "$PORT"

# The trap on EXIT releases the lock automatically.
exit 0