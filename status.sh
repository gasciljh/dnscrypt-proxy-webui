#!/system/bin/sh
# shellcheck shell=ksh
# shellcheck disable=SC2059  # printf color codes are trusted constants
# ============================================================
# DNSCrypt Smart Filter — status.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Display current status of the DNSCrypt Smart Filter module.
#
# Modes:
#   status.sh                Full display (default)
#   status.sh --short        Short display (OK / STOPPED / ...)
#   status.sh --json         JSON output
#   status.sh --check        Single-line core summary
#   status.sh --verbose      Extended display (adds ports + paths)
#   status.sh --diagnose     Full diagnostic report
#   status.sh --help         Show help
#   status.sh --version      Show version
#
# Exit codes:
#   0 = everything running
#   1 = nothing running
#   2 = partial (only one service running)
#   3 = module disabled
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
    echo "ERROR: functions.sh not found — cannot report status" >&2
    exit 1
fi

# shellcheck disable=SC1090
. "$MODDIR/functions.sh" 2>/dev/null

if ! command -v list_snapshots >/dev/null 2>&1 \
   || ! command -v is_port_open >/dev/null 2>&1; then
    echo "ERROR: functions.sh failed to load required symbols" >&2
    exit 1
fi

# ============================================================
# [3] Parse arguments
# ============================================================
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
  status.sh --verbose/-V    Extended display (adds ports + config paths)
  status.sh --diagnose/-d   Full diagnostic report (backups + health)
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

_mode_count=0
_mode_list=""
[ "$SHORT_MODE" = "1" ]    && { _mode_count=$((_mode_count + 1)); _mode_list="$_mode_list --short"; }
[ "$CHECK_MODE" = "1" ]    && { _mode_count=$((_mode_count + 1)); _mode_list="$_mode_list --check"; }
[ "$JSON_MODE" = "1" ]     && { _mode_count=$((_mode_count + 1)); _mode_list="$_mode_list --json"; }
[ "$DIAGNOSE_MODE" = "1" ] && { _mode_count=$((_mode_count + 1)); _mode_list="$_mode_list --diagnose"; }

if [ "$_mode_count" -gt 1 ]; then
    echo "ERROR: only one primary mode may be selected at a time."
    echo "       got:$_mode_list"
    exit 1
fi

if [ "$VERBOSE_MODE" = "1" ] && [ "$_mode_count" -gt 0 ]; then
    echo "ERROR: --verbose cannot be combined with a primary mode."
    echo "       got:$_mode_list --verbose"
    exit 1
fi

# ============================================================
# [4] Resolve ports
# ============================================================
PORT=$(get_webui_port "$WEBUI_CONF" 2>/dev/null)
[ -z "$PORT" ] && PORT="$DEFAULT_WEBUI_PORT"

DASHBOARD_PORT=$(get_dashboard_port "$WEBUI_CONF" 2>/dev/null)
[ -z "$DASHBOARD_PORT" ] && DASHBOARD_PORT="$DEFAULT_DASHBOARD_PORT"

# ============================================================
# [5] Profile
# ============================================================
PROFILE_KEY=""
PROFILE_NAME="unknown"

if [ -f "$SELECTED_PROFILE_FILE" ]; then
    PROFILE_KEY=$(cat "$SELECTED_PROFILE_FILE" 2>/dev/null | tr -d '\r\n ')
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

MEMORY_HINT=$(get_profile_memory_hint 2>/dev/null)
[ -z "$MEMORY_HINT" ] && MEMORY_HINT="80 MB (pro)"

# ============================================================
# [6] Backup state
# ============================================================
BACKUP_COUNT=0
BACKUP_TXN_COUNT=0
BACKUP_ORPHAN_COUNT=0
BACKUP_LAST_TIME=""
BACKUP_LAST_EPOCH=0
BACKUP_LAST_AGE_SEC=-1
BACKUP_LAST_NAME=""
BACKUP_LAST_STABLE=""
BACKUP_STATUS="missing"

format_age() {
    local sec="$1"
    case "$sec" in
        ''|*[!0-9-]*) printf "N/A"; return ;;
    esac
    [ "$sec" -lt 0 ] && { printf "N/A"; return; }
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

_snapshot_display_time() {
    local name="$1" ts
    ts=$(printf '%s' "$name" | cut -d'-' -f1,2)
    case "$ts" in
        ''|*[!0-9-]*) printf "unknown"; return ;;
    esac
    [ "${#ts}" -eq 15 ] || { printf "unknown"; return; }
    printf '%s-%s-%s %s:%s UTC' \
        "${ts:0:4}" "${ts:4:2}" "${ts:6:2}" "${ts:9:2}" "${ts:11:2}"
}

_file_age_seconds() {
    local path="$1" mtime now
    [ -f "$path" ] || { printf '-1'; return; }
    mtime=$(stat -c %Y "$path" 2>/dev/null) \
        || mtime=$(stat -f %m "$path" 2>/dev/null) \
        || mtime=0
    case "$mtime" in ''|*[!0-9]*) mtime=0 ;; esac
    [ "$mtime" -le 0 ] && { printf '-1'; return; }
    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    [ "$now" -le 0 ] && { printf '-1'; return; }
    printf '%d' $((now - mtime))
}

if [ -d "$PERSISTENT_BACKUP" ]; then
    BACKUP_STATUS="empty"

    _bk_count=$(count_snapshots 2>/dev/null)
    case "$_bk_count" in ''|*[!0-9]*) _bk_count=0 ;; esac
    BACKUP_COUNT="$_bk_count"

    _txn=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d txn-*/ 2>/dev/null | wc -l | tr -d ' ')
    case "$_txn" in ''|*[!0-9]*) _txn=0 ;; esac
    BACKUP_TXN_COUNT="$_txn"

    _orph=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d orphan-txn-*/ 2>/dev/null | wc -l | tr -d ' ')
    case "$_orph" in ''|*[!0-9]*) _orph=0 ;; esac
    BACKUP_ORPHAN_COUNT="$_orph"

    if [ "$BACKUP_COUNT" -gt 0 ]; then
        BACKUP_STATUS="ok"
        BACKUP_LAST_NAME=$(list_snapshots 1)

        if [ -n "$BACKUP_LAST_NAME" ]; then
            BACKUP_LAST_TIME=$(_snapshot_display_time "$BACKUP_LAST_NAME")

            _manifest="$PERSISTENT_BACKUP/$BACKUP_LAST_NAME/.manifest.json"
            BACKUP_LAST_AGE_SEC=$(_file_age_seconds "$_manifest")
            case "$BACKUP_LAST_AGE_SEC" in ''|*[!0-9-]*) BACKUP_LAST_AGE_SEC=-1 ;; esac
        fi
    fi

    BACKUP_LAST_STABLE=$(read_last_stable 2>/dev/null)
fi

BACKUP_LAST_AGE=$(format_age "$BACKUP_LAST_AGE_SEC")

# ============================================================
# [7] Pending notification + recovery trigger
# ============================================================
PENDING_NOTIFY_CONTENT=""
[ -f "$PENDING_NOTIFY_FILE" ] && \
    PENDING_NOTIFY_CONTENT=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')

RECOVERY_TRIGGER=$(get_recovery_trigger "$MODDIR")
RECOVERY_MODE_ACTIVE="NO"
if [ -f "$RECOVERY_TRIGGER" ] || [ -f "$RECOVERY_TRIGGER_2" ]; then
    RECOVERY_MODE_ACTIVE="YES"
fi

# ============================================================
# [8] Service status
# ============================================================
DNS_RUNNING="NO"
is_dnscrypt_running 2>/dev/null && DNS_RUNNING="YES"

WEBUI_RUNNING="NO"
is_webui_running "$PORT" 2>/dev/null && WEBUI_RUNNING="YES"

WATCHDOG_RUNNING="NO"
WATCHDOG_PID=""
_wd=$(read_pid_file "$WATCHDOG_PID_FILE" 2>/dev/null)
if [ -n "$_wd" ]; then
    WATCHDOG_RUNNING="YES"
    WATCHDOG_PID="$_wd"
fi

# ============================================================
# [9] Intent, blocklist, config, IPv6, root
# ============================================================
STATUS_FROM_FILE="UNKNOWN"
[ -f "$STATUS_FILE" ] && \
    STATUS_FROM_FILE=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')

BLOCKLIST_COUNT="0"
BLOCKLIST_SIZE="0"
if [ -f "$BLOCKLIST_FILE" ]; then
    BLOCKLIST_COUNT=$(wc -l < "$BLOCKLIST_FILE" 2>/dev/null | tr -d ' ')
    BLOCKLIST_SIZE=$(wc -c < "$BLOCKLIST_FILE" 2>/dev/null | tr -d ' ')
fi
case "$BLOCKLIST_COUNT" in ''|*[!0-9]*) BLOCKLIST_COUNT="0" ;; esac
case "$BLOCKLIST_SIZE"  in ''|*[!0-9]*) BLOCKLIST_SIZE="0"  ;; esac

RAW_BLOCKLIST_COUNT="0"
RAW_BLOCKLIST_SIZE="0"
if [ -f "$RAW_BLOCKLIST_FILE" ]; then
    RAW_BLOCKLIST_COUNT=$(wc -l < "$RAW_BLOCKLIST_FILE" 2>/dev/null | tr -d ' ')
    RAW_BLOCKLIST_SIZE=$(wc -c < "$RAW_BLOCKLIST_FILE" 2>/dev/null | tr -d ' ')
fi
case "$RAW_BLOCKLIST_COUNT" in ''|*[!0-9]*) RAW_BLOCKLIST_COUNT="0" ;; esac
case "$RAW_BLOCKLIST_SIZE"  in ''|*[!0-9]*) RAW_BLOCKLIST_SIZE="0"  ;; esac

LAST_UPDATE="unknown"
if [ -f "$BLOCKLIST_FILE" ]; then
    _age=$(_file_age_seconds "$BLOCKLIST_FILE")
    case "$_age" in ''|*[!0-9-]*) _age=-1 ;; esac
    [ "$_age" -ge 0 ] && LAST_UPDATE=$(format_age "$_age")
fi

IS_DISABLED="NO"
[ -f "$MODDIR/disable" ] && IS_DISABLED="YES"

AUTO_DNS=$(get_auto_restart_dns "$WEBUI_CONF")
AUTO_WEBUI=$(get_auto_restart_webui "$WEBUI_CONF")

BIND_ADDR=$(read_conf "$WEBUI_CONF" "BIND_ADDR" "127.0.0.1")

IPV6_AVAILABLE="NO"
is_ipv6_available 2>/dev/null && IPV6_AVAILABLE="YES"

ACTIVE_RUN_DIR="${RUN_DIR_ACTIVE:-$(dirname "$STATUS_FILE")}"

DNS_PID=$(read_pid_file "$PID_FILE" 2>/dev/null)
WEBUI_PID=$(read_pid_file "$WEBUI_PID_FILE" 2>/dev/null)

ROOT_SOLUTION="unknown"
if [ -n "${KSU_VER:-}" ] || [ -d "/data/adb/ksu" ]; then
    ROOT_SOLUTION="KernelSU"
elif [ -n "${APATCH:-}" ] || [ -d "/data/adb/ap" ]; then
    ROOT_SOLUTION="APatch"
elif [ -n "${MAGISK_VER_CODE:-}" ] || [ -d "/data/adb/magisk" ]; then
    ROOT_SOLUTION="Magisk"
fi

# ============================================================
# [10] JSON helpers
# ============================================================
esc_json() {
    [ -z "$1" ] && { printf ''; return; }
    printf '%s' "$1" | sed '
        s/\\/\\\\/g
        s/"/\\"/g
        s/\t/\\t/g
        s/\r/\\r/g
        s/\f/\\f/g
    ' | tr '\n' ' '
}

_json_str() {
    [ -z "$1" ] && printf 'null' || printf '"%s"' "$(esc_json "$1")"
}

_exit_code() {
    if [ "$IS_DISABLED" = "YES" ]; then
        echo 3
    elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ]; then
        echo 0
    elif [ "$DNS_RUNNING" = "NO" ] && [ "$WEBUI_RUNNING" = "NO" ]; then
        echo 1
    else
        echo 2
    fi
}

# ============================================================
# [11] --check mode
# ============================================================
if [ "$CHECK_MODE" = "1" ]; then
    _dns="DNS=$( [ "$DNS_RUNNING" = "YES" ] && echo UP || echo DOWN )"
    _web="WEBUI=$( [ "$WEBUI_RUNNING" = "YES" ] && echo UP || echo DOWN )"
    _prof="PROFILE=${PROFILE_KEY:-unknown}"
    _mem="MEM=${MEMORY_HINT}"
    _ent="ENTRIES=$BLOCKLIST_COUNT"
    _bak="BACKUP=${BACKUP_COUNT}snap/${BACKUP_LAST_AGE}"
    _run="RUNDIR=$ACTIVE_RUN_DIR"
    _dis=""
    [ "$IS_DISABLED" = "YES" ] && _dis=" DISABLED"

    printf "%s | %s | %s | %s | %s | %s | %s | %s%s\n" \
        "$MODULE_VERSION" "$_dns" "$_web" "$_prof" "$_mem" "$_ent" "$_bak" "$_run" "$_dis"

    exit "$(_exit_code)"
fi

# ============================================================
# [12] --json mode
# ============================================================
if [ "$JSON_MODE" = "1" ]; then
    CHECKED_AT=$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)
    MEM_MB=$(printf '%s' "$MEMORY_HINT" | grep -oE '^[0-9]+' || echo "0")

    BACKUP_LAST_HUMAN=""
    [ -n "$BACKUP_LAST_TIME" ] && [ "$BACKUP_LAST_TIME" != "unknown" ] && \
        BACKUP_LAST_HUMAN="$BACKUP_LAST_TIME"

    cat << EOF
{
  "version": "$(esc_json "$MODULE_VERSION")",
  "checked_at": "$CHECKED_AT",
  "functions_loaded": true,
  "root_solution": "$(esc_json "$ROOT_SOLUTION")",
  "run_dir": "$(esc_json "$ACTIVE_RUN_DIR")",
  "dns_engine": {
    "running": $([ "$DNS_RUNNING" = "YES" ] && echo "true" || echo "false"),
    "port": $DNS_ENGINE_PORT,
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
# [13] --short mode
# ============================================================
if [ "$SHORT_MODE" = "1" ]; then
    if [ "$IS_DISABLED" = "YES" ]; then
        echo "DISABLED"
    elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ]; then
        echo "OK"
    elif [ "$DNS_RUNNING" = "YES" ]; then
        echo "DNS_ONLY"
    elif [ "$WEBUI_RUNNING" = "YES" ]; then
        echo "WEBUI_ONLY"
    else
        echo "STOPPED"
    fi
    exit "$(_exit_code)"
fi

# ============================================================
# [14] Colour setup (all modes below use it)
# ============================================================
if [ -t 1 ]; then
    C_RED=$(printf '\033[0;31m');   C_GREEN=$(printf '\033[0;32m')
    C_YELLOW=$(printf '\033[0;33m'); C_BLUE=$(printf '\033[0;34m')
    C_CYAN=$(printf '\033[0;36m');  C_MAGENTA=$(printf '\033[0;35m')
    C_BOLD=$(printf '\033[1m');     C_DIM=$(printf '\033[2m')
    C_NC=$(printf '\033[0m')
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
    C_CYAN=''; C_MAGENTA=''; C_BOLD=''; C_DIM=''; C_NC=''
fi

# ============================================================
# [15] --diagnose mode
# ============================================================
if [ "$DIAGNOSE_MODE" = "1" ]; then
    echo ""
    echo "================================================================="
    echo "  DNSCrypt Smart Filter — Diagnostic Report"
    echo "  Version: $MODULE_VERSION"
    echo "  Date:    $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "================================================================="
    echo ""

    echo "${C_BOLD}─── System Information ───${C_NC}"
    echo "  Android:       $(getprop ro.build.version.release 2>/dev/null) (API $(getprop ro.build.version.sdk 2>/dev/null))"
    echo "  Device:        $(getprop ro.product.model 2>/dev/null)"
    echo "  Kernel:        $(uname -r 2>/dev/null)"
    echo "  Architecture:  $(getprop ro.product.cpu.abi 2>/dev/null)"
    echo "  SoC:           $(getprop ro.product.board 2>/dev/null)"
    echo "  Root solution: $ROOT_SOLUTION"
    [ "$ROOT_SOLUTION" = "Magisk" ] && \
        echo "  Magisk:        $(magisk -V 2>/dev/null || echo 'unknown')"
    echo ""

    echo "${C_BOLD}─── Module Information ───${C_NC}"
    echo "  Version:       $MODULE_VERSION"
    echo "  Module path:   $MODDIR"
    echo "  Runtime dir:   $ACTIVE_RUN_DIR"
    echo "  functions.sh:  loaded"
    echo ""

    echo "${C_BOLD}─── Service Status ───${C_NC}"
    if [ "$DNS_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✅${C_NC} DNS Engine:   running (port $DNS_ENGINE_PORT/UDP)"
    else
        echo "  ${C_RED}❌${C_NC} DNS Engine:   ${C_RED}STOPPED${C_NC}"
    fi
    if [ "$WEBUI_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✅${C_NC} WebUI:        running (port $PORT)"
    else
        echo "  ${C_RED}❌${C_NC} WebUI:        ${C_RED}STOPPED${C_NC}"
    fi
    if [ "$WATCHDOG_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✅${C_NC} Watchdog:     running (PID: $WATCHDOG_PID)"
    else
        echo "  ${C_DIM}−${C_NC} Watchdog:     inactive"
    fi
    [ "$IS_DISABLED" = "YES" ] && \
        echo "  ${C_YELLOW}⚠️${C_NC} Module:       ${C_YELLOW}DISABLED${C_NC}"
    echo ""

    echo "${C_BOLD}─── Recovery & Notifications ───${C_NC}"
    if [ "$RECOVERY_MODE_ACTIVE" = "YES" ]; then
        echo "  ${C_YELLOW}⚠️${C_NC} Recovery mode: ${C_YELLOW}TRIGGER FILE PRESENT${C_NC}"
        [ -f "$RECOVERY_TRIGGER" ]    && echo "     - $RECOVERY_TRIGGER"
        [ -f "$RECOVERY_TRIGGER_2" ]  && echo "     - $RECOVERY_TRIGGER_2"
    else
        echo "  ${C_GREEN}✅${C_NC} Recovery mode: not triggered"
    fi

    if [ -n "$PENDING_NOTIFY_CONTENT" ]; then
        echo "  ${C_CYAN}ℹ️${C_NC} Pending notification:"
        echo "     ${C_DIM}$PENDING_NOTIFY_CONTENT${C_NC}"
    else
        echo "  ${C_DIM}−${C_NC} Pending notification: none"
    fi
    echo ""

    echo "${C_BOLD}─── User Data Files ───${C_NC}"
    echo "  Location: $BIN_DIR"
    echo ""
    _ud_missing=0
    for _f in $USER_FILES; do
        _fp="$BIN_DIR/$_f"
        if [ -f "$_fp" ]; then
            _size=$(wc -c < "$_fp" 2>/dev/null | tr -d ' ')
            _age=$(_file_age_seconds "$_fp")
            _age_str=$(format_age "$_age")
            printf "  ${C_GREEN}✅${C_NC} %-25s ${C_DIM}%8s bytes  (modified %s)${C_NC}\n" \
                "$_f" "$_size" "$_age_str"
        else
            printf "  ${C_RED}❌${C_NC} %-25s ${C_DIM}(missing)${C_NC}\n" "$_f"
            _ud_missing=$((_ud_missing + 1))
        fi
    done
    echo ""

    echo "${C_BOLD}─── Backups ───${C_NC}"
    echo "  Location: $PERSISTENT_BACKUP"

    case "$BACKUP_STATUS" in
        missing)
            echo "  ${C_YELLOW}⚠️${C_NC} Directory not found"
            ;;
        empty)
            echo "  ${C_YELLOW}⚠️${C_NC} Directory exists but contains no snapshots"
            ;;
        ok)
            echo "  ${C_GREEN}✅${C_NC} $BACKUP_COUNT snapshot(s) available"
            echo "     Last backup: ${C_DIM}$BACKUP_LAST_NAME${C_NC} ($BACKUP_LAST_AGE)"
            echo ""
            echo "  ${C_BOLD}Recent snapshots:${C_NC}"
            _bk_i=0
            while IFS= read -r _snap; do
                [ -z "$_snap" ] && continue
                _bk_i=$((_bk_i + 1))
                _fc=0
                for _chk in "$PERSISTENT_BACKUP/$_snap"/*.conf \
                            "$PERSISTENT_BACKUP/$_snap"/*.toml \
                            "$PERSISTENT_BACKUP/$_snap"/*.txt; do
                    [ -f "$_chk" ] && _fc=$((_fc + 1))
                done
                _man=""
                [ -f "$PERSISTENT_BACKUP/$_snap/.manifest.json" ] && _man=" +manifest"
                _ts_str=$(_snapshot_display_time "$_snap")
                printf "    ${C_DIM}%2d.${C_NC} %-40s ${C_DIM}(%s files%s, %s)${C_NC}\n" \
                    "$_bk_i" "$_snap" "$_fc" "$_man" "$_ts_str"
            done <<EOF
$(list_snapshots 10)
EOF
            [ -n "$BACKUP_LAST_STABLE" ] && {
                echo ""
                echo "  ${C_BOLD}.last_stable:${C_NC} $BACKUP_LAST_STABLE"
            }
            ;;
    esac

    [ "$BACKUP_TXN_COUNT" -gt 0 ] && {
        echo ""
        echo "  ${C_YELLOW}⚠️${C_NC} In-flight transactions: $BACKUP_TXN_COUNT"
    }
    [ "$BACKUP_ORPHAN_COUNT" -gt 0 ] && {
        echo ""
        echo "  ${C_YELLOW}⚠️${C_NC} Orphan transactions: $BACKUP_ORPHAN_COUNT"
    }
    echo ""

    echo "${C_BOLD}─── Health Checks ───${C_NC}"
    _health=0

    if [ "$DNS_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✅${C_NC} DNS engine listening on $DNS_ENGINE_PORT/UDP"
    else
        echo "  ${C_RED}❌${C_NC} DNS engine NOT listening on $DNS_ENGINE_PORT/UDP"
        _health=$((_health + 1))
    fi

    if [ "$WEBUI_RUNNING" = "YES" ]; then
        echo "  ${C_GREEN}✅${C_NC} WebUI listening on port $PORT"
    else
        echo "  ${C_RED}❌${C_NC} WebUI NOT listening on port $PORT"
        _health=$((_health + 1))
    fi

    if [ "$BLOCKLIST_COUNT" -gt 0 ]; then
        echo "  ${C_GREEN}✅${C_NC} Blocklist loaded ($BLOCKLIST_COUNT entries, $BLOCKLIST_SIZE bytes)"
    else
        echo "  ${C_YELLOW}⚠️${C_NC} Blocklist is empty (no profile applied yet?)"
    fi

    [ -f "$TOML_FILE" ] && echo "  ${C_GREEN}✅${C_NC} dnscrypt-proxy.toml present" \
                        || { echo "  ${C_RED}❌${C_NC} dnscrypt-proxy.toml MISSING"; _health=$((_health + 1)); }

    [ -f "$WEBUI_CONF" ] && echo "  ${C_GREEN}✅${C_NC} webui.conf present" \
                         || { echo "  ${C_RED}❌${C_NC} webui.conf MISSING"; _health=$((_health + 1)); }

    if [ -n "$PROFILE_KEY" ]; then
        echo "  ${C_GREEN}✅${C_NC} Active profile: $PROFILE_NAME ($MEMORY_HINT)"
    else
        echo "  ${C_YELLOW}⚠️${C_NC} Profile file missing or invalid"
    fi

    if [ "$IS_DISABLED" = "NO" ]; then
        if [ "$STATUS_FROM_FILE" = "ON" ] && [ "$DNS_RUNNING" = "NO" ]; then
            echo "  ${C_YELLOW}⚠️${C_NC} STATUS_FILE=ON but DNS is not running"
        elif [ "$STATUS_FROM_FILE" = "OFF" ] && [ "$DNS_RUNNING" = "YES" ]; then
            echo "  ${C_YELLOW}⚠️${C_NC} STATUS_FILE=OFF but DNS is running"
        fi
    fi

    if [ "$_ud_missing" -gt 0 ]; then
        echo "  ${C_RED}❌${C_NC} $_ud_missing user data file(s) missing"
        _health=$((_health + 1))
    else
        echo "  ${C_GREEN}✅${C_NC} All 5 user data files present"
    fi

    case "$BACKUP_STATUS" in
        ok)    echo "  ${C_GREEN}✅${C_NC} Backup layer healthy ($BACKUP_COUNT snapshots)" ;;
        empty) echo "  ${C_YELLOW}⚠️${C_NC} Backup layer exists but empty" ;;
        *)     echo "  ${C_YELLOW}⚠️${C_NC} Backup directory not initialized" ;;
    esac
    echo ""

    echo "${C_BOLD}─── Diagnosis ───${C_NC}"
    if [ "$IS_DISABLED" = "YES" ]; then
        echo "  ${C_YELLOW}⚠️  Module is disabled.${C_NC}"
        echo "     Enable: remove $MODDIR/disable and reboot"
    elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ] && [ "$_health" -eq 0 ]; then
        echo "  ${C_GREEN}✅ All systems operational${C_NC}"
    elif [ "$_health" -gt 0 ]; then
        echo "  ${C_RED}❌ $_health critical issue(s) detected${C_NC}"
    else
        echo "  ${C_YELLOW}⚠️  Services not fully running${C_NC}"
        echo "     Try: su -c 'sh $MODDIR/action.sh --restart'"
    fi

    echo ""
    echo "================================================================="
    echo "  End of report"
    echo "================================================================="
    echo ""

    _ec=$(_exit_code)
    [ "$_ec" -eq 0 ] && [ "$_health" -gt 0 ] && _ec=2
    exit "$_ec"
fi

# ============================================================
# [16] Full mode (default) + optional --verbose additions
# ============================================================
if [ "$IS_DISABLED" = "YES" ]; then
    OVERALL="${C_YELLOW}WARNING: DISABLED${C_NC}"
elif [ "$DNS_RUNNING" = "YES" ] && [ "$WEBUI_RUNNING" = "YES" ]; then
    OVERALL="${C_GREEN}ACTIVE${C_NC}"
elif [ "$DNS_RUNNING" = "YES" ] || [ "$WEBUI_RUNNING" = "YES" ]; then
    OVERALL="${C_YELLOW}PARTIAL${C_NC}"
else
    OVERALL="${C_RED}STOPPED${C_NC}"
fi

DNS_ICON=$(  [ "$DNS_RUNNING"      = "YES" ] && printf "${C_GREEN}[ON]${C_NC}"  || printf "${C_RED}[OFF]${C_NC}")
WEBUI_ICON=$([ "$WEBUI_RUNNING"    = "YES" ] && printf "${C_GREEN}[ON]${C_NC}"  || printf "${C_RED}[OFF]${C_NC}")
WD_ICON=$(   [ "$WATCHDOG_RUNNING" = "YES" ] && printf "${C_GREEN}[ON]${C_NC}"  || printf "${C_DIM}[--]${C_NC}")
IPV6_ICON=$( [ "$IPV6_AVAILABLE"   = "YES" ] && printf "${C_GREEN}[+]${C_NC}"   || printf "${C_DIM}[-]${C_NC}")

DNS_TEXT=$(  [ "$DNS_RUNNING"      = "YES" ] && printf "running on port %s/UDP" "$DNS_ENGINE_PORT" || printf "stopped")
WEBUI_TEXT=$([ "$WEBUI_RUNNING"    = "YES" ] && printf "running on port %s"     "$PORT"             || printf "stopped")
WD_TEXT=$(   [ "$WATCHDOG_RUNNING" = "YES" ] && printf "running (PID: %s)"       "$WATCHDOG_PID"     || printf "inactive")

echo ""
echo "============================================================"
printf "  DNSCrypt Smart Filter %s\n" "$MODULE_VERSION"
printf "  Status: %s\n" "$OVERALL"
echo "============================================================"
echo ""

printf "%s--- Service Status ---%s\n" "$C_CYAN" "$C_NC"
printf "  %s DNS Engine:   %s\n" "$DNS_ICON"   "$DNS_TEXT"
printf "  %s WebUI:        %s\n" "$WEBUI_ICON" "$WEBUI_TEXT"
printf "  %s Watchdog:     %s\n" "$WD_ICON"    "$WD_TEXT"

[ "$IS_DISABLED" = "YES" ] && \
    printf "  ${C_YELLOW}WARNING: Module disabled (disable file present)${C_NC}\n"

if [ "$STATUS_FROM_FILE" != "UNKNOWN" ]; then
    _expected=$([ "$DNS_RUNNING" = "YES" ] && echo "ON" || echo "OFF")
    if [ "$STATUS_FROM_FILE" != "$_expected" ]; then
        printf "  ${C_DIM}(status file: %s - user intent; may differ from actual state)${C_NC}\n" \
            "$STATUS_FROM_FILE"
    fi
fi
echo ""

printf "%s--- Links ---%s\n" "$C_CYAN" "$C_NC"
printf "  ${C_BOLD}WebUI:${C_NC}     ${C_BLUE}http://127.0.0.1:%s${C_NC}\n" "$PORT"
printf "  ${C_BOLD}Dashboard:${C_NC} ${C_BLUE}http://127.0.0.1:%s${C_NC}\n" "$DASHBOARD_PORT"
echo ""

printf "%s--- Profile & Memory ---%s\n" "$C_CYAN" "$C_NC"
printf "  Profile:       %s\n" "$PROFILE_NAME"
printf "  Memory limit:  %s\n" "$MEMORY_HINT"
printf "  ${C_DIM}Managed by:    main.go (Go runtime soft limit)${C_NC}\n"
echo ""

printf "%s--- Active Blocklist ---%s\n" "$C_CYAN" "$C_NC"
printf "  Entries:       %s\n" "$BLOCKLIST_COUNT"
printf "  File size:     %s bytes\n" "$BLOCKLIST_SIZE"
printf "  Last update:   %s\n" "$LAST_UPDATE"
printf "  ${C_DIM}Raw source:    %s entries / %s bytes${C_NC}\n" \
    "$RAW_BLOCKLIST_COUNT" "$RAW_BLOCKLIST_SIZE"
echo ""

printf "%s--- Backup & Recovery ---%s\n" "$C_CYAN" "$C_NC"
case "$BACKUP_STATUS" in
    missing)
        printf "  ${C_YELLOW}⚠️${C_NC}  Status:        ${C_YELLOW}no backup directory${C_NC}\n"
        printf "  ${C_DIM}Path:          %s${C_NC}\n" "$PERSISTENT_BACKUP"
        ;;
    empty)
        printf "  ${C_YELLOW}⚠️${C_NC}  Status:        ${C_YELLOW}directory exists but empty${C_NC}\n"
        printf "  ${C_DIM}Path:          %s${C_NC}\n" "$PERSISTENT_BACKUP"
        ;;
    ok)
        printf "  ${C_GREEN}✅${C_NC}  Snapshots:     %s\n" "$BACKUP_COUNT"
        printf "  Last backup:   %s ${C_DIM}(%s)${C_NC}\n" "$BACKUP_LAST_TIME" "$BACKUP_LAST_AGE"
        printf "  ${C_DIM}Latest:        %s${C_NC}\n" "$BACKUP_LAST_NAME"
        [ -n "$BACKUP_LAST_STABLE" ] && \
            printf "  ${C_DIM}Last stable:   %s${C_NC}\n" "$BACKUP_LAST_STABLE"
        printf "  ${C_DIM}Path:          %s${C_NC}\n" "$PERSISTENT_BACKUP"
        ;;
esac

[ "$BACKUP_TXN_COUNT"    -gt 0 ] && printf "  ${C_YELLOW}⚠️${C_NC}  In-flight:     %s txn dir(s)\n" "$BACKUP_TXN_COUNT"
[ "$BACKUP_ORPHAN_COUNT" -gt 0 ] && printf "  ${C_YELLOW}⚠️${C_NC}  Orphans:       %s orphan-txn dir(s)\n" "$BACKUP_ORPHAN_COUNT"

[ "$RECOVERY_MODE_ACTIVE" = "YES" ] && \
    printf "  ${C_YELLOW}⚠️${C_NC}  Recovery mode: ${C_YELLOW}TRIGGER PRESENT${C_NC}\n"

[ -n "$PENDING_NOTIFY_CONTENT" ] && \
    printf "  ${C_CYAN}ℹ️${C_NC}  Notification:  %s\n" "$PENDING_NOTIFY_CONTENT"
echo ""

printf "%s--- Configuration ---%s\n" "$C_CYAN" "$C_NC"
printf "  Auto-DNS:      %s\n" "$([ "$AUTO_DNS" = "1" ] && printf "${C_GREEN}enabled${C_NC}" || printf "${C_DIM}disabled${C_NC}")"
printf "  Auto-WebUI:    %s\n" "$([ "$AUTO_WEBUI" = "1" ] && printf "${C_GREEN}enabled${C_NC}" || printf "${C_DIM}disabled${C_NC}")"
printf "  BIND_ADDR:     %s\n" "$BIND_ADDR"
printf "  IPv6:          %s %s\n" "$IPV6_ICON" \
    "$([ "$IPV6_AVAILABLE" = "YES" ] && echo "available" || echo "unavailable")"
echo ""

printf "%s--- Information ---%s\n" "$C_CYAN" "$C_NC"
printf "  Version:       %s\n" "$MODULE_VERSION"
printf "  Root solution: %s\n" "$ROOT_SOLUTION"
printf "  Module path:   %s\n" "$MODDIR"
printf "  Runtime dir:   %s\n" "$ACTIVE_RUN_DIR"

[ -n "$WEBUI_PID" ]    && printf "  PID WebUI:     %s\n" "$WEBUI_PID"
[ -n "$DNS_PID" ]      && printf "  PID DNS:       %s\n" "$DNS_PID"
[ -n "$WATCHDOG_PID" ] && printf "  PID Watchdog:  %s\n" "$WATCHDOG_PID"
echo ""

# ============================================================
# [17] --verbose additions
# ============================================================
if [ "$VERBOSE_MODE" = "1" ]; then
    printf "%s--- Verbose: Ports & Environment ---%s\n" "$C_MAGENTA" "$C_NC"
    printf "  WebUI port:        %s\n" "$PORT"
    printf "  Dashboard port:    %s\n" "$DASHBOARD_PORT"
    printf "  Monitoring UI:     %s (reserved)\n" "$_MONITORING_UI_PORT"
    printf "  DNS engine port:   %s\n" "$DNS_ENGINE_PORT"
    printf "  DNS engine proto:  UDP/TCP\n"
    echo ""
    printf "  ${C_DIM}webui.conf:         %s${C_NC}\n" "$WEBUI_CONF"
    printf "  ${C_DIM}dnscrypt-proxy.toml: %s${C_NC}\n" "$TOML_FILE"
    printf "  ${C_DIM}selected_profile:   %s${C_NC}\n" "$SELECTED_PROFILE_FILE"
    printf "  ${C_DIM}blocklist.txt:      %s${C_NC}\n" "$BLOCKLIST_FILE"
    printf "  ${C_DIM}blocklist.raw:      %s${C_NC}\n" "$RAW_BLOCKLIST_FILE"
    printf "  ${C_DIM}backup dir:         %s${C_NC}\n" "$PERSISTENT_BACKUP"
    printf "  ${C_DIM}recovery trigger:   %s${C_NC}\n" "$RECOVERY_TRIGGER"
    echo ""
    printf "  STATUS_FILE raw:   %s\n" "${STATUS_FROM_FILE:-<missing>}"
    echo ""

    if [ "$BACKUP_STATUS" = "ok" ]; then
        printf "%s--- Verbose: All Backups ---%s\n" "$C_MAGENTA" "$C_NC"
        while IFS= read -r _snap; do
            [ -z "$_snap" ] && continue
            _fc=0
            for _chk in "$PERSISTENT_BACKUP/$_snap"/*.conf \
                        "$PERSISTENT_BACKUP/$_snap"/*.toml \
                        "$PERSISTENT_BACKUP/$_snap"/*.txt; do
                [ -f "$_chk" ] && _fc=$((_fc + 1))
            done
            _sz=$(du -sh "$PERSISTENT_BACKUP/$_snap" 2>/dev/null | cut -f1)
            _ts_str=$(_snapshot_display_time "$_snap")
            printf "  %-40s ${C_DIM}%s files, %s, %s${C_NC}\n" \
                "$_snap" "$_fc" "$_sz" "$_ts_str"
        done <<EOF
$(list_snapshots)
EOF
        echo ""
    fi
fi

# ============================================================
# [18] Hints
# ============================================================
if [ "$IS_DISABLED" = "YES" ]; then
    printf "%sWARNING: Module is disabled.${C_NC}\n" "$C_YELLOW"
    printf "   ${C_DIM}To enable: remove the file %s/disable${C_NC}\n" "$MODDIR"
    echo ""
elif [ "$DNS_RUNNING" = "NO" ] && [ "$WEBUI_RUNNING" = "NO" ]; then
    printf "%sHINT: To start the service:${C_NC}\n" "$C_YELLOW"
    printf "   ${C_DIM}1. Open Magisk/KernelSU${C_NC}\n"
    printf "   ${C_DIM}2. Tap Action on the module${C_NC}\n"
    printf "   ${C_DIM}3. Or from WebUI: press \"Start Service\"${C_NC}\n"
    echo ""
elif [ "$DNS_RUNNING" = "NO" ] || [ "$WEBUI_RUNNING" = "NO" ]; then
    printf "%sHINT: To restore full state:${C_NC}\n" "$C_YELLOW"
    printf "   ${C_DIM}Run the module from Magisk (Action button)${C_NC}\n"
    echo ""
fi

if [ "$VERBOSE_MODE" != "1" ]; then
    printf "${C_DIM}Tip: run 'status.sh --diagnose' for a full report${C_NC}\n"
    echo ""
fi

exit "$(_exit_code)"