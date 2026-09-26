#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – action.sh
# Version: v1.1.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Magisk / KernelSU "Action" button handler.
#
#   Modes:
#     action.sh              Start WebUI + open browser
#     action.sh --restart    Force restart WebUI
#     action.sh --status     Show WebUI status only
#     action.sh --check      Show comprehensive status
#     action.sh --help       Show help
#
# Exit codes:
#   0 = success
#   1 = error (startup failed)
#   2 = module disabled
#
# Notes:
#   • Loads functions.sh if available, otherwise uses inline fallbacks.
#   • The version is read dynamically from module.prop (not hardcoded).
#   • Port Guard: rejects port 8080 (reserved for monitoring_ui).
#
# v1.1.0 additions:
#   • --check now reports the active profile + expected memory hint
#   • Structured --check output with clear sections
#   • English-only messages (global release)
#   • Fallback for get_profile_memory_hint if functions.sh is missing
#
# Coordination with main.go v1.1.0:
#   • The constant _MONITORING_UI_PORT below MUST stay in sync
#     with MONITORING_UI_PORT in main.go.
#   • The memory hint is DISPLAY-ONLY. main.go remains the
#     authority for the actual debug.SetMemoryLimit() value.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Determine module path
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

# ============================================================
# [2] Shared constant
# ============================================================
_MONITORING_UI_PORT="8080"

# ============================================================
# [3] Default paths (reconfigured after loading functions.sh)
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
WEBUI_PID_FILE="/data/local/tmp/webui.pid"
WATCHDOG_PID_FILE="/data/local/tmp/watchdog.pid"
STATUS_FILE="/data/local/tmp/dnscrypt.status"
CRED_FILE="/data/local/tmp/dnscrypt_credentials.txt"

SELECTED_PROFILE_FILE="$MODDIR/proxy/selected_profile.txt"

log_msg() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [action] $1" >> "$LOG_FILE" 2>/dev/null
}

# ============================================================
# [4] Read version
# ============================================================
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
    printf 'unknown'
}

VERSION="$(get_version)"

# ============================================================
# [5] Internal fallback (if functions.sh is not loaded)
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

# ------------------------------------------------------------
# _inline_read_conf: supports values containing '='
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# _inline_read_port: Port Guard (reject 8080)
# ------------------------------------------------------------
_inline_read_port() {
    local conf="$1"
    local key="${2:-PORT}"
    local default="$3"
    local val
    val=$(_inline_read_conf "$conf" "$key" "$default")
    if echo "$val" | grep -qE '^[0-9]+$' && [ "$val" -ge 1 ] && [ "$val" -le 65535 ]; then
        # Port Guard
        if [ "$val" = "$_MONITORING_UI_PORT" ]; then
            printf "%s" "$default"
            return 0
        fi
        printf "%s" "$val"
        return 0
    fi
    printf "%s" "$default"
}

# ------------------------------------------------------------
# _inline_get_profile_memory_hint (v1.1.0)
# ------------------------------------------------------------
# Self-contained fallback for functions.sh:get_profile_memory_hint.
# Returns a user-facing string like "120 MB (pro)".
# ------------------------------------------------------------
_inline_get_profile_memory_hint() {
    local profile="pro"

    if [ -f "$SELECTED_PROFILE_FILE" ]; then
        local p
        p=$(cat "$SELECTED_PROFILE_FILE" 2>/dev/null | tr -d '\r\n ')
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
# [6] Display help
# ============================================================
show_help() {
    cat << EOF
DNSCrypt Smart Filter – action.sh ${VERSION}

Usage:
  action.sh              Start WebUI and open browser
  action.sh --restart    Force restart WebUI
  action.sh --status     Show WebUI status only
  action.sh --check      Show comprehensive status (DNS + WebUI + config)
  action.sh --help       Show this help

Exit codes:
  0 = success
  1 = error (startup failed)
  2 = module disabled

EOF
    exit 0
}

# ============================================================
# [7] Load functions.sh
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

# ============================================================
# [8] Unified wrappers
# ============================================================
if [ "$FUNCTIONS_LOADED" = "1" ]; then
    is_port_listening()  { is_port_open "$1" "${2:-tcp}"; }
    get_port()           { get_webui_port "$1"; }
    read_conf()          { get_conf_value "$1" "$2" "$3"; }

    # v1.1.0 — memory hint wrapper
    if command -v get_profile_memory_hint >/dev/null 2>&1; then
        get_mem_hint()   { get_profile_memory_hint; }
    else
        get_mem_hint()   { _inline_get_profile_memory_hint; }
    fi
else
    _FB_RUN_DIR=$(_fallback_get_run_dir)
    WEBUI_PID_FILE="$_FB_RUN_DIR/webui.pid"
    WATCHDOG_PID_FILE="$_FB_RUN_DIR/watchdog.pid"
    STATUS_FILE="$_FB_RUN_DIR/dnscrypt.status"

    is_port_listening()  { _inline_is_port_open "$1" "${2:-tcp}"; }
    get_port()           { _inline_read_port "$1" "PORT" "9090"; }
    read_conf()          { _inline_read_conf "$1" "$2" "$3"; }
    get_mem_hint()       { _inline_get_profile_memory_hint; }
fi

# ============================================================
# [9] Parse command-line arguments
# ============================================================
FORCE_RESTART=0
STATUS_ONLY=0
CHECK_MODE=0

for arg in "$@"; do
    case "$arg" in
        --restart) FORCE_RESTART=1 ;;
        --status)  STATUS_ONLY=1 ;;
        --check)   CHECK_MODE=1 ;;
        --help|-h) show_help ;;
        *)
            echo "❌ Unknown option: $arg"
            echo "Use --help for assistance"
            exit 1
            ;;
    esac
done

# ============================================================
# [10] Configure paths
# ============================================================
BIN_DIR="$MODDIR/proxy"
WEBUI="$BIN_DIR/dnscrypt-webui"
CONF_FILE="$BIN_DIR/webui.conf"
TOML_FILE="$BIN_DIR/dnscrypt-proxy.toml"

PORT=$(get_port "$CONF_FILE" 2>/dev/null)
[ -z "$PORT" ] && PORT="9090"

# ============================================================
# [11] Path 1: status only (--status)
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
# [12] Path 2: comprehensive check (--check)
# ============================================================
# v1.1.0:
#   • Structured sections (Service, Runtime, Config, Profile)
#   • Includes the expected memory limit for the active profile
#   • English-only output
# ============================================================
if [ "$CHECK_MODE" = "1" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    printf "║  🔍 DNSCrypt %-8s – System Check     ║\n" "$VERSION"
    echo "╚══════════════════════════════════════════════╝"
    echo ""

    # --- Section 1: Services ---
    echo "─── Service Status ─────────────────────────"
    if is_port_listening "$PORT" tcp; then
        printf "  🟢 WebUI    : Running on port %s\n" "$PORT"
    else
        printf "  🔴 WebUI    : Stopped\n"
    fi

    # --- DNS Engine ---
    if [ "$FUNCTIONS_LOADED" = "1" ] && command -v is_dnscrypt_running >/dev/null 2>&1; then
        if is_dnscrypt_running; then
            printf "  🟢 DNS      : Running on 5354/UDP\n"
        else
            printf "  🔴 DNS      : Stopped\n"
        fi
    else
        if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
            printf "  🟢 DNS      : Running (process exists)\n"
        else
            printf "  🔴 DNS      : Stopped\n"
        fi
    fi

    # --- Watchdog ---
    if [ -f "$WATCHDOG_PID_FILE" ]; then
        wd_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$wd_pid" ] && kill -0 "$wd_pid" 2>/dev/null; then
            wd_comm=$(cat "/proc/$wd_pid/comm" 2>/dev/null)
            case "$wd_comm" in
                sh|ash|bash|busybox|*sh)
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

    # --- Section 2: Runtime ---
    echo "─── Runtime ────────────────────────────────"
    if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ]; then
        printf "  📁 run/     : %s\n" "$RUN_DIR_ACTIVE"
    else
        printf "  📁 run/     : %s\n" "$(dirname "$WEBUI_PID_FILE")"
    fi

    # STATUS_FILE = user intent (may differ from actual state)
    if [ -f "$STATUS_FILE" ]; then
        st=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
        printf "  📄 Intent   : %s (user intent)\n" "${st:-UNKNOWN}"
    else
        printf "  📄 Intent   : (no file)\n"
    fi

    # Version + functions.sh
    printf "  🏷️  Version  : %s\n" "$VERSION"
    if [ "$FUNCTIONS_LOADED" = "1" ]; then
        printf "  📚 functions: ✅ loaded\n"
    else
        printf "  📚 functions: ⚠️ not loaded (fallback)\n"
    fi
    echo ""

    # --- Section 3: Configuration ---
    echo "─── Configuration ──────────────────────────"
    DASH_PORT=$(read_conf "$CONF_FILE" "DASHBOARD_PORT" "9091")
    printf "  🌐 WebUI port    : %s\n" "$PORT"
    printf "  📊 Dashboard port: %s\n" "$DASH_PORT"

    # Auto-restart config
    AUTO_DNS=$(read_conf "$CONF_FILE" "AUTO_RESTART_DNS" "1")
    AUTO_WEBUI=$(read_conf "$CONF_FILE" "AUTO_RESTART_WEBUI" "1")
    printf "  🔄 Auto-DNS      : %s\n" "$([ "$AUTO_DNS" = "1" ] && echo "enabled" || echo "disabled")"
    printf "  🔄 Auto-WebUI    : %s\n" "$([ "$AUTO_WEBUI" = "1" ] && echo "enabled" || echo "disabled")"

    # BIND_ADDR
    BIND_ADDR=$(read_conf "$CONF_FILE" "BIND_ADDR" "127.0.0.1")
    printf "  🔌 BIND_ADDR     : %s\n" "$BIND_ADDR"
    echo ""

    # --- Section 4: Profile + Memory (v1.1.0) ---
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

    # --- Module disabled? ---
    if [ -f "$MODDIR/disable" ]; then
        printf "  ⚠️  Module        : DISABLED (remove 'disable' file to enable)\n"
        echo ""
    fi

    # --- Credentials ---
    if [ -f "$CRED_FILE" ]; then
        printf "  🔐 Credentials   : available\n"
    else
        printf "  ⚠️  Credentials   : missing\n"
    fi

    echo ""
    echo "  🌐 Open: http://127.0.0.1:$PORT"
    echo ""
    exit 0
fi

# ============================================================
# [13] Refuse to start if module is disabled
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    log_msg "Module is disabled, cannot start WebUI"
    printf "⚠️  Module is disabled.\n"
    printf "Enable it first from Magisk/KernelSU.\n"
    exit 2
fi

# ============================================================
# [14] Verify WebUI binary exists
# ============================================================
if [ ! -f "$WEBUI" ]; then
    log_msg "WebUI binary not found at $WEBUI"
    printf "❌ WebUI binary not found.\n"
    printf "Try reinstalling the module.\n"
    exit 1
fi

# ============================================================
# [15] Start WebUI (if needed)
# ============================================================
STARTED_NOW=0

if [ "$FORCE_RESTART" = "1" ]; then
    log_msg "--restart flag detected, forcing WebUI restart"
    printf "🔄 Restarting WebUI...\n"
    STARTED_NOW=1
elif ! is_port_listening "$PORT" tcp; then
    log_msg "WebUI not running, starting..."
    printf "▶️  Starting WebUI...\n"
    STARTED_NOW=1
fi

if [ "$STARTED_NOW" = "1" ]; then
    if [ "$FUNCTIONS_LOADED" = "1" ] && command -v cleanup_orphans >/dev/null 2>&1; then
        cleanup_orphans 2>/dev/null
    fi

    if [ "$FUNCTIONS_LOADED" = "1" ] && command -v start_native_webui >/dev/null 2>&1; then
        if ! start_native_webui "$WEBUI" "$PORT"; then
            log_msg "start_native_webui returned failure"
            printf "❌ Failed to start WebUI.\n"
            printf "Check /data/local/tmp/dnscrypt_main.log\n"
            exit 1
        fi
    else
        # ---------- Fallback internal start ----------
        log_msg "functions.sh unavailable, using inline fallback"

        pkill -9 -x dnscrypt-webui 2>/dev/null
        rm -f "$WEBUI_PID_FILE" 2>/dev/null

        export HOME=/data/local/tmp

        if command -v setsid >/dev/null 2>&1; then
            setsid env HOME="$HOME" "$WEBUI" >/dev/null 2>&1 < /dev/null &
        else
            nohup env HOME="$HOME" "$WEBUI" >/dev/null 2>&1 < /dev/null &
        fi

        # Use pgrep -x to avoid false positives
        sleep 1
        local_pid=$(pgrep -x "dnscrypt-webui" 2>/dev/null | head -n1)
        if [ -n "$local_pid" ]; then
            printf "%s\n" "$local_pid" > "${WEBUI_PID_FILE}.tmp" 2>/dev/null
            mv -f "${WEBUI_PID_FILE}.tmp" "$WEBUI_PID_FILE" 2>/dev/null
        fi

        # Wait for the port to open (max 20s)
        local_i=0
        while [ "$local_i" -lt 20 ]; do
            if is_port_listening "$PORT" tcp; then
                break
            fi
            sleep 1
            local_i=$((local_i + 1))
        done

        if ! is_port_listening "$PORT" tcp; then
            log_msg "fallback start failed (timeout)"
            printf "❌ WebUI failed to start (timeout).\n"
            exit 1
        fi
    fi

    log_msg "WebUI started on port $PORT"
    printf "✅ WebUI started on port %s\n" "$PORT"
else
    log_msg "WebUI already running on port $PORT"
    printf "ℹ️  WebUI is already running on port %s\n" "$PORT"
fi

if [ "$STARTED_NOW" = "1" ]; then
    sleep 1
fi

# ============================================================
# [16] Open browser (5 fallback methods + timeout)
# ============================================================
URL="http://127.0.0.1:$PORT"

log_msg "Opening browser at $URL"
printf "🌐 Opening: %s\n" "$URL"

# --- Try 1: am start --user 0 -W (standard) ---
if timeout 5 am start --user 0 -W \
    -a android.intent.action.VIEW \
    -d "$URL" \
    --activity-clear-top \
    >/dev/null 2>&1; then
    log_msg "Browser opened via am start (standard)"
    printf "✅ Browser opened.\n"
    exit 0
fi

log_msg "Standard am start failed, trying alternative methods..."

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
        log_msg "Browser opened via explicit package: $DEFAULT_BROWSER"
        printf "✅ Browser opened.\n"
        exit 0
    fi
fi

# --- Try 3: am start without --user ---
if timeout 5 am start \
    -a android.intent.action.VIEW \
    -d "$URL" \
    >/dev/null 2>&1; then
    log_msg "Browser opened via am start (no --user)"
    printf "✅ Browser opened.\n"
    exit 0
fi

# --- Try 4: am start --activity-new-task ---
if timeout 5 am start \
    --activity-new-task \
    -a android.intent.action.VIEW \
    -d "$URL" \
    >/dev/null 2>&1; then
    log_msg "Browser opened via am start (new task)"
    printf "✅ Browser opened.\n"
    exit 0
fi

# --- Try 5: without -W (no wait) ---
if timeout 5 am start \
    -a android.intent.action.VIEW \
    -d "$URL" \
    >/dev/null 2>&1 &
then
    sleep 1
    log_msg "Browser opened via am start (async, no -W)"
    printf "✅ Browser opened (async).\n"
    exit 0
fi

# --- All attempts failed ---
log_msg "Could not open browser automatically"
printf "⚠️  Could not open browser automatically.\n"
printf "Please open manually: %s\n" "$URL"
exit 0