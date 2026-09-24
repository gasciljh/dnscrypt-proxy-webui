#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – status.sh
# Version: v1.0.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Display the current status of the DNSCrypt Smart Filter module.
#
# Modes:
#   status.sh                Full display (default)
#   status.sh --short        Short display (OK / STOPPED / ...)
#   status.sh --json         JSON output
#   status.sh --check        Single-line summary
#   status.sh --help         Show help
#
# Exit codes:
#   0 = everything running
#   1 = nothing running
#   2 = partial (only one service running)
#   3 = module disabled
#
# Reports:
#   • DNS Engine  (port 5354/UDP)
#   • WebUI       (port from webui.conf)
#   • Watchdog    (PID file + process verification)
#   • STATUS_FILE (user intent — may differ from actual state)
#   • Active profile + blocklist entry count
#   • Blocklist stats (raw + filtered)
#   • Configuration (AUTO_RESTART_*, BIND_ADDR, IPv6)
#   • Runtime directory
#
# Design:
#   • Loads functions.sh if available; otherwise uses inline
#     fallbacks (is_port_open, read_conf, read_webui_port, ...)
#   • Includes FIX: the wrapper for is_ipv6_available delegates
#     directly to _inline_is_ipv6_available to avoid infinite
#     recursion (previous wrapper called itself).
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

# ============================================================
# [2b] Shared constant
# ============================================================
_MONITORING_UI_PORT="8080"

# ============================================================
# [3] Read module version
# ============================================================
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

# ============================================================
# [4] Parse command-line arguments
# ============================================================
SHORT_MODE=0
JSON_MODE=0
CHECK_MODE=0
FORCE_MODE=0

for arg in "$@"; do
    case "$arg" in
        --short|-s) SHORT_MODE=1 ;;
        --json|-j)  JSON_MODE=1 ;;
        --check|-c) CHECK_MODE=1 ;;
        --force|-f) FORCE_MODE=1 ;;
        --help|-h)
            cat << EOF
DNSCrypt Smart Filter - status.sh ${MODULE_VERSION}

Usage:
  status.sh                 Full display (default)
  status.sh --short/-s      Short display (OK / STOPPED / ...)
  status.sh --check/-c      Single-line summary with all details
  status.sh --json/-j       JSON output
  status.sh --force/-f      Force check (bypass cache, slower but accurate)
  status.sh --help/-h       Show this help

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

# ============================================================
# [5] Load functions.sh
# ============================================================
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

# ============================================================
# [6] Internal fallback
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
fi

# --- inline: is_port_open ---
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

# --- inline: read_conf ---
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

# --- inline: read_port with Port Guard ---
_inline_read_port() {
    local conf="$1"
    local key="$2"
    local default="$3"
    local val
    val=$(_inline_read_conf "$conf" "$key" "$default")
    if echo "$val" | grep -qE '^[0-9]+$' && [ "$val" -ge 1 ] && [ "$val" -le 65535 ]; then
        # Port Guard: reject 8080 (reserved for monitoring_ui)
        if [ "$val" = "$_MONITORING_UI_PORT" ]; then
            printf "%s" "$default"
            return 0
        fi
        printf "%s" "$val"
        return 0
    fi
    printf "%s" "$default"
}

# --- inline: is_ipv6_available ---
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

# ============================================================
# [7] Unified wrappers
# ============================================================
# FIX: the previous wrapper for is_ipv6_available caused infinite
# recursion (SIGSEGV after ~18,000 iterations):
#
#   is_ipv6_available() {
#       command -v is_ipv6_available >/dev/null 2>&1 \
#           && is_ipv6_available \
#           || _inline_is_ipv6_available
#   }
#
# The wrapper redefined itself and then called itself.
# functions.sh already provides is_ipv6_available, so the
# fallback wrapper simply delegates to _inline_is_ipv6_available.
# ============================================================
if [ "$FUNCTIONS_LOADED" = "1" ]; then
    is_tcp_open()           { is_port_open "$1" tcp; }
    is_udp_open()           { is_port_open "$1" udp; }
    read_conf()             { get_conf_value "$1" "$2" "$3"; }
    read_webui_port()       { get_webui_port "$CONF_FILE" 2>/dev/null; }
    read_dashboard_port()   { get_dashboard_port "$CONF_FILE" 2>/dev/null; }
    is_ipv6_available()     { _inline_is_ipv6_available; }
else
    is_tcp_open()           { _inline_is_port_open "$1" tcp; }
    is_udp_open()           { _inline_is_port_open "$1" udp; }
    read_conf()             { _inline_read_conf "$1" "$2" "$3"; }
    read_webui_port()       { _inline_read_port "$CONF_FILE" "PORT" "9090"; }
    read_dashboard_port()   { _inline_read_port "$CONF_FILE" "DASHBOARD_PORT" "9091"; }
    is_ipv6_available()     { _inline_is_ipv6_available; }
fi

# ============================================================
# [8] Collect data
# ============================================================
PORT=$(read_webui_port)
DASHBOARD_PORT=$(read_dashboard_port)
[ -z "$PORT" ] && PORT="9090"
[ -z "$DASHBOARD_PORT" ] && DASHBOARD_PORT="9091"

# --- DNS Engine ---
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

# --- WebUI ---
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

# --- Status file ---
STATUS_FROM_FILE="UNKNOWN"
if [ -f "$STATUS_FILE" ]; then
    STATUS_FROM_FILE=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
fi

# --- Blocklist stats ---
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

LAST_UPDATE="unknown"
if [ -f "$BLOCKLIST_FILE" ]; then
    LAST_UPDATE=$(date -r "$BLOCKLIST_FILE" '+%Y-%m-%d %H:%M' 2>/dev/null)
    [ -z "$LAST_UPDATE" ] && LAST_UPDATE="unknown"
fi

# --- Profile ---
PROFILE_NAME="unknown"
PROFILE_KEY=""
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
fi

# --- Disabled ---
IS_DISABLED="NO"
[ -f "$MODDIR/disable" ] && IS_DISABLED="YES"

# --- AUTO_RESTART config ---
AUTO_DNS=$(read_conf "$CONF_FILE" "AUTO_RESTART_DNS" "1")
AUTO_WEBUI=$(read_conf "$CONF_FILE" "AUTO_RESTART_WEBUI" "1")
case "$AUTO_DNS"   in 0|1) ;; *) AUTO_DNS="1"   ;; esac
case "$AUTO_WEBUI" in 0|1) ;; *) AUTO_WEBUI="1" ;; esac

# --- BIND_ADDR ---
BIND_ADDR=$(read_conf "$CONF_FILE" "BIND_ADDR" "127.0.0.1")

# --- Watchdog ---
WATCHDOG_RUNNING="NO"
WATCHDOG_PID=""
if [ -f "$WATCHDOG_PID_FILE" ]; then
    wd_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$wd_pid" ] && kill -0 "$wd_pid" 2>/dev/null; then
        wd_comm=$(cat "/proc/$wd_pid/comm" 2>/dev/null)
        case "$wd_comm" in
            sh|ash|bash|busybox|*sh)
                WATCHDOG_RUNNING="YES"
                WATCHDOG_PID="$wd_pid"
                ;;
        esac
    fi
fi

# --- IPv6 ---
IPV6_AVAILABLE="NO"
if is_ipv6_available; then
    IPV6_AVAILABLE="YES"
fi

# --- Active RUN_DIR ---
if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ]; then
    ACTIVE_RUN_DIR="$RUN_DIR_ACTIVE"
else
    ACTIVE_RUN_DIR=$(dirname "$STATUS_FILE")
fi

# --- PIDs ---
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

# ============================================================
# [9] esc_json
# ============================================================
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
        s/\b/\\b/g
    ' | tr '\n' ' ' | sed 's/  */ /g'
}

# ============================================================
# [10] Quick check mode (single line)
# ============================================================
if [ "$CHECK_MODE" = "1" ]; then
    dns_str="DNS=$( [ "$DNS_RUNNING" = "YES" ] && echo "UP" || echo "DOWN" )"
    webui_str="WEBUI=$( [ "$WEBUI_RUNNING" = "YES" ] && echo "UP" || echo "DOWN" )"
    profile_str="PROFILE=${PROFILE_KEY:-unknown}"
    entries_str="ENTRIES=$BLOCKLIST_COUNT"
    rundir_str="RUNDIR=$ACTIVE_RUN_DIR"
    disabled_str=""
    [ "$IS_DISABLED" = "YES" ] && disabled_str=" DISABLED"

    printf "%s | %s | %s | %s | %s | %s%s\n" \
        "$MODULE_VERSION" "$dns_str" "$webui_str" "$profile_str" "$entries_str" "$rundir_str" "$disabled_str"

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
if [ "$JSON_MODE" = "1" ]; then
    CHECKED_AT=$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)

    cat << EOF
{
  "version": "$(esc_json "$MODULE_VERSION")",
  "checked_at": "$CHECKED_AT",
  "functions_loaded": $([ "$FUNCTIONS_LOADED" = "1" ] && echo "true" || echo "false"),
  "run_dir": "$(esc_json "$ACTIVE_RUN_DIR")",
  "dns_engine": {
    "running": $([ "$DNS_RUNNING" = "YES" ] && echo "true" || echo "false"),
    "port": 5354,
    "pid": "$(esc_json "$DNS_PID")"
  },
  "webui": {
    "running": $([ "$WEBUI_RUNNING" = "YES" ] && echo "true" || echo "false"),
    "port": $PORT,
    "url": "http://127.0.0.1:$PORT",
    "pid": "$(esc_json "$WEBUI_PID")"
  },
  "dashboard": {
    "port": $DASHBOARD_PORT,
    "url": "http://127.0.0.1:$DASHBOARD_PORT"
  },
  "bind_addr": "$(esc_json "$BIND_ADDR")",
  "watchdog": {
    "running": $([ "$WATCHDOG_RUNNING" = "YES" ] && echo "true" || echo "false"),
    "pid": "$(esc_json "$WATCHDOG_PID")"
  },
  "auto_restart": {
    "dns": $AUTO_DNS,
    "webui": $AUTO_WEBUI
  },
  "ipv6_available": $([ "$IPV6_AVAILABLE" = "YES" ] && echo "true" || echo "false"),
  "status_file": "$(esc_json "$STATUS_FROM_FILE")",
  "profile": {
    "key": "$(esc_json "$PROFILE_KEY")",
    "name": "$(esc_json "$PROFILE_NAME")"
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
  "disabled": $([ "$IS_DISABLED" = "YES" ] && echo "true" || echo "false")
}
EOF
    exit 0
fi

# ============================================================
# [12] Short mode
# ============================================================
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
# [13] Full mode (default)
# ============================================================
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
# [14] Display
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
        # Note: STATUS_FILE may differ from actual state during crash
        printf "  ${DIM}(status file: %s - user intent; may differ from actual state)${NC}\n" "$STATUS_FROM_FILE"
    fi
fi

echo ""

printf "%s--- Links ---%s\n" "$CYAN" "$NC"
printf "  ${BOLD}WebUI:${NC}     ${BLUE}http://127.0.0.1:%s${NC}\n" "$PORT"
printf "  ${BOLD}Dashboard:${NC} ${BLUE}http://127.0.0.1:%s${NC}\n" "$DASHBOARD_PORT"
echo ""

printf "%s--- Active Blocklist ---%s\n" "$CYAN" "$NC"
printf "  Profile:       %s\n" "$PROFILE_NAME"
printf "  Entries:       %s\n" "$BLOCKLIST_COUNT"
printf "  File size:     %s bytes\n" "$BLOCKLIST_SIZE"
printf "  Last update:   %s\n" "$LAST_UPDATE"
printf "  ${DIM}Raw source:    %s entries / %s bytes${NC}\n" "$RAW_BLOCKLIST_COUNT" "$RAW_BLOCKLIST_SIZE"
echo ""

printf "%s--- Configuration ---%s\n" "$CYAN" "$NC"
printf "  Auto-DNS:      %s\n" "$([ "$AUTO_DNS" = "1" ] && printf "${GREEN}enabled${NC}" || printf "${DIM}disabled${NC}")"
printf "  Auto-WebUI:    %s\n" "$([ "$AUTO_WEBUI" = "1" ] && printf "${GREEN}enabled${NC}" || printf "${DIM}disabled${NC}")"
printf "  BIND_ADDR:     %s\n" "$BIND_ADDR"
printf "  IPv6:          %s %s\n" "$IPV6_ICON" "$([ "$IPV6_AVAILABLE" = "YES" ] && echo "available" || echo "unavailable")"
echo ""

printf "%s--- Information ---%s\n" "$CYAN" "$NC"
printf "  Version:       %s\n" "$MODULE_VERSION"
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
# [15] Help hints
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

# ============================================================
# [16] Exit code
# ============================================================
if [ "$IS_DISABLED" = "YES" ]; then
    exit 3
elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ]; then
    exit 0
elif [ "$DNS_RUNNING" = "NO" ] && [ "$WEBUI_RUNNING" = "NO" ]; then
    exit 1
else
    exit 2
fi