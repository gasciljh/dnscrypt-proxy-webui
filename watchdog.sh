#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — watchdog.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Standalone watchdog. Monitors WebUI (TCP port) and DNS engine
# (5354/UDP), restarts them as needed. Launched by service.sh
# as an independent process.
#
# Single-instance guarantees:
#   1. is_duplicate_watchdog (four-layer /proc check)
#   2. Atomic startup lock via acquire_lock
#   3. PID file written atomically
#
# User intent is read via get_user_intent() (auto-migrates from
# v1.5.0 legacy location). STATUS_FILE semantics are preserved.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path + --version
# ============================================================
_MODDIR_FROM_SELF=${0%/*}
[ "$_MODDIR_FROM_SELF" = "." ] && _MODDIR_FROM_SELF=$(pwd)
case $_MODDIR_FROM_SELF in
    /*) ;;
    *)  _MODDIR_FROM_SELF="/data/adb/modules/${_MODDIR_FROM_SELF}" ;;
esac

case "${1:-}" in
    --version)
        _v="v0.0.0-unknown"
        [ -f "$_MODDIR_FROM_SELF/module.prop" ] && \
            _v=$(grep '^version=' "$_MODDIR_FROM_SELF/module.prop" 2>/dev/null \
                | head -n1 | cut -d= -f2- | tr -d '\r ')
        echo "$0: $_v"
        exit 0
        ;;
esac

# ============================================================
# [2] Argument validation
# ============================================================
if [ "$#" -ne 5 ]; then
    echo "watchdog.sh: requires exactly 5 arguments, got $#" >&2
    echo "Usage: watchdog.sh <pid_file> <moddir> <port> <auto_dns> <auto_webui>" >&2
    exit 1
fi

WATCHDOG_PID_FILE="$1"
MODDIR="$2"
PORT="$3"
AUTO_RESTART_DNS="$4"
AUTO_RESTART_WEBUI="$5"

if [ -z "$WATCHDOG_PID_FILE" ] || [ -z "$MODDIR" ]; then
    echo "watchdog.sh: missing required args" >&2
    exit 1
fi

if [ ! -d "$MODDIR" ]; then
    echo "watchdog.sh: MODDIR not found: $MODDIR" >&2
    exit 1
fi

# Port Guard: reject reserved 8080, non-numeric, out-of-range.
case "$PORT" in
    ''|*[!0-9]*) PORT="$DEFAULT_WEBUI_PORT" ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ] || [ "$PORT" = "8080" ]; then
    PORT="${DEFAULT_WEBUI_PORT:-9090}"
fi

case "$AUTO_RESTART_DNS"   in 0|1) ;; *) AUTO_RESTART_DNS="1"   ;; esac
case "$AUTO_RESTART_WEBUI" in 0|1) ;; *) AUTO_RESTART_WEBUI="1" ;; esac

# ============================================================
# [3] Load functions.sh (boot-mini → all lib/)
# ============================================================
LOG_PREFIX="[watchdog]"

if [ ! -f "$MODDIR/functions.sh" ]; then
    echo "watchdog.sh: functions.sh missing" >&2
    exit 1
fi

# shellcheck disable=SC1090
. "$MODDIR/functions.sh" 2>/dev/null

if ! command -v log_msg >/dev/null 2>&1 \
   || ! command -v is_port_open >/dev/null 2>&1 \
   || ! command -v start_native_webui >/dev/null 2>&1 \
   || ! command -v get_watchdog_token >/dev/null 2>&1 \
   || ! command -v get_user_intent >/dev/null 2>&1; then
    echo "watchdog.sh: functions.sh failed to load required symbols" >&2
    exit 1
fi

LOG_PREFIX="[watchdog]"

BIN_DIR="${BIN_DIR:-$MODDIR/proxy}"
WEBUI_BIN="${WEBUI_BIN:-$BIN_DIR/dnscrypt-webui}"
TOML_FILE="${TOML_FILE:-$BIN_DIR/dnscrypt-proxy.toml}"
STATUS_FILE="${STATUS_FILE:-${RUN_DIR_ACTIVE:-$BIN_DIR/run}/dnscrypt.status}"
WATCHDOG_TOKEN_FILE="${WATCHDOG_TOKEN_FILE:-$(dirname "$STATUS_FILE")/.watchdog_token}"

WATCHDOG_VERSION=$(get_module_version "$MODDIR" 2>/dev/null)
[ -z "$WATCHDOG_VERSION" ] && WATCHDOG_VERSION="v1.6.0"

# ============================================================
# [4] Duplicate watchdog check (four-layer /proc)
# ============================================================
if is_duplicate_watchdog "$WATCHDOG_PID_FILE"; then
    _existing=$(existing_watchdog_pid "$WATCHDOG_PID_FILE" 2>/dev/null)
    log_msg "Watchdog already running (PID: ${_existing:-unknown}) — exiting"
    exit 0
fi

# ============================================================
# [5] Acquire startup lock + write PID
# ============================================================
_WD_LOCK_PATH=""
_WD_LOCK_HELD=0

_wd_terminate() {
    local sig="${1:-?}"
    if [ "$_WD_LOCK_HELD" = "1" ] && [ -n "$_WD_LOCK_PATH" ]; then
        release_lock "$_WD_LOCK_PATH"
        _WD_LOCK_HELD=0
    fi
    log_msg "Watchdog terminated (SIG$sig)"
    remove_pid_file "$WATCHDOG_PID_FILE"
    exit 0
}

_WD_LOCK_PATH=$(get_lock_path "watchdog-startup")
if ! acquire_lock "$_WD_LOCK_PATH" 60; then
    log_msg "Another watchdog is starting (lock held) — exiting"
    exit 0
fi
_WD_LOCK_HELD=1

if ! write_pid_file "$WATCHDOG_PID_FILE" "$$"; then
    log_msg "FATAL: cannot write PID file: $WATCHDOG_PID_FILE"
    release_lock "$_WD_LOCK_PATH"
    _WD_LOCK_HELD=0
    exit 1
fi

release_lock "$_WD_LOCK_PATH"
_WD_LOCK_HELD=0

# ============================================================
# [6] Traps (installed only after PID file is committed)
# ============================================================
trap '_wd_terminate TERM' TERM
trap '_wd_terminate INT'  INT
trap '_wd_terminate QUIT' QUIT

# ============================================================
# [7] Load Basic Auth fallback credentials
# ============================================================
WATCH_USER=""
WATCH_PASS=""
HAS_CREDS=0

if command -v read_toml_credentials >/dev/null 2>&1 && [ -f "$TOML_FILE" ]; then
    _creds=$(read_toml_credentials 2>/dev/null)
    WATCH_USER=$(printf '%s' "$_creds" | sed -n '1p')
    WATCH_PASS=$(printf '%s' "$_creds" | sed -n '2p')
    if [ -n "$WATCH_USER" ] && [ -n "$WATCH_PASS" ]; then
        HAS_CREDS=1
    fi
fi

# ============================================================
# [8] Startup diagnostics (READ-ONLY)
# ============================================================
_pending_msg=""
[ -f "$PENDING_NOTIFY_FILE" ] && \
    _pending_msg=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')

_last_stable=$(read_last_stable 2>/dev/null)

_snap_count=$(count_snapshots 2>/dev/null)
case "$_snap_count" in ''|*[!0-9]*) _snap_count=0 ;; esac

_txn_count=0
[ -d "$PERSISTENT_BACKUP" ] && \
    _txn_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d txn-*/ 2>/dev/null | wc -l | tr -d ' ')
case "$_txn_count" in ''|*[!0-9]*) _txn_count=0 ;; esac

_orphan_count=0
[ -d "$PERSISTENT_BACKUP" ] && \
    _orphan_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d orphan-txn-*/ 2>/dev/null | wc -l | tr -d ' ')
case "$_orphan_count" in ''|*[!0-9]*) _orphan_count=0 ;; esac

log_msg "============================================"
log_msg "Watchdog started (PID: $$, version: $WATCHDOG_VERSION)"
log_msg "─── Config ───"
log_msg "   MODDIR:     $MODDIR"
log_msg "   PORT:       $PORT"
log_msg "   Auto-DNS:   $AUTO_RESTART_DNS"
log_msg "   Auto-WebUI: $AUTO_RESTART_WEBUI"
log_msg "─── Paths ───"
log_msg "   RUN_DIR:    ${RUN_DIR_ACTIVE:-$BIN_DIR/run}"
log_msg "   STATUS_FILE: $STATUS_FILE"
log_msg "─── Data Preservation (READ-ONLY) ───"
log_msg "   Snapshots:      $_snap_count"
log_msg "   In-flight txn:  $_txn_count"
log_msg "   Orphan txn:     $_orphan_count"
log_msg "   Last stable:    ${_last_stable:-(none yet)}"
[ -n "$_pending_msg" ] && log_msg "   Notification:   $_pending_msg"
log_msg "   Auth: token=${WATCHDOG_TOKEN_FILE} basic=$HAS_CREDS"
log_msg "============================================"

# ============================================================
# [9] API call helper
# ============================================================
# Returns the same codes as lib/http.sh::http_request:
#   0 = success (includes 202 Accepted), 1 = no client,
#   2 = network, 3 = rate-limited (429), 4 = HTTP error
#
# Populates HTTP_CODE and HTTP_ERROR (globals). HTTP_BODY is
# captured so the caller can inspect {"action":"..."} fields.
_call_api() {
    local token header="" url rc saved

    url="http://127.0.0.1:$PORT/api/ensure_running_service"

    token=$(get_watchdog_token 2>/dev/null)
    if [ -n "$token" ] && [ "${#token}" -ge 32 ]; then
        header="X-Watchdog-Token: $token"
    elif [ "$HAS_CREDS" = "1" ]; then
        header=$(build_basic_auth_header "$WATCH_USER" "$WATCH_PASS" 2>/dev/null)
    fi

    if [ -z "$header" ]; then
        HTTP_ERROR="no credentials available"
        HTTP_CODE=""
        return 2
    fi

    saved="${HTTP_CAPTURE_BODY:-0}"
    HTTP_CAPTURE_BODY=1
    http_post "$url" "" "$header"
    rc=$?
    HTTP_CAPTURE_BODY="$saved"
    return $rc
}

# ============================================================
# [10] Backoff state
# ============================================================
BACKOFF_BASE="${WATCHDOG_BACKOFF_BASE:-30}"
BACKOFF_MAX="${WATCHDOG_BACKOFF_MAX:-600}"

WEBUI_BACKOFF_CURRENT="$BACKOFF_BASE"
DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
PREV_DESIRED=""
LAST_WEBUI_ATTEMPT=0
LAST_DNS_ATTEMPT=0
LOOP_COUNT=0

log_msg "Entering main loop (base=${BACKOFF_BASE}s, max=${BACKOFF_MAX}s)"
log_msg "Active profile: $(get_profile_memory_hint 2>/dev/null || echo unknown)"

# ============================================================
# [11] Main loop
# ============================================================
while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))

    # --- [11.0] Compute sleep: min of both backoffs ---
    SLEEP_DURATION="$WEBUI_BACKOFF_CURRENT"
    [ "$DNS_BACKOFF_CURRENT" -lt "$SLEEP_DURATION" ] && \
        SLEEP_DURATION="$DNS_BACKOFF_CURRENT"
    [ "$SLEEP_DURATION" -lt 5 ] && SLEEP_DURATION=5
    [ "$SLEEP_DURATION" -gt "$BACKOFF_MAX" ] && SLEEP_DURATION="$BACKOFF_MAX"

    sleep "$SLEEP_DURATION"

    # --- [11.1] Disable check ---
    if [ -f "$MODDIR/disable" ]; then
        log_msg "Module disabled — watchdog exiting"
        remove_pid_file "$WATCHDOG_PID_FILE"
        exit 0
    fi

    # --- [11.2] Safe now computation ---
    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac

    # --- [11.3] WebUI restart ---
    if [ "$AUTO_RESTART_WEBUI" = "1" ]; then
        if [ $((now - LAST_WEBUI_ATTEMPT)) -ge "$WEBUI_BACKOFF_CURRENT" ]; then
            LAST_WEBUI_ATTEMPT="$now"

            if ! is_port_open "$PORT" tcp; then
                log_msg "WebUI down on port $PORT — restarting"

                if start_native_webui "$WEBUI_BIN" "$PORT"; then
                    WEBUI_BACKOFF_CURRENT="$BACKOFF_BASE"
                else
                    WEBUI_BACKOFF_CURRENT=$((WEBUI_BACKOFF_CURRENT * 2))
                    [ "$WEBUI_BACKOFF_CURRENT" -gt "$BACKOFF_MAX" ] && \
                        WEBUI_BACKOFF_CURRENT="$BACKOFF_MAX"
                    log_msg "WebUI restart failed — next attempt in ${WEBUI_BACKOFF_CURRENT}s"
                fi
            else
                WEBUI_BACKOFF_CURRENT="$BACKOFF_BASE"
            fi
        fi
    fi

    # --- [11.4] DNS restart ---
    if [ "$AUTO_RESTART_DNS" = "1" ]; then
        desired=$(get_user_intent)

        if [ "$desired" != "$PREV_DESIRED" ]; then
            [ -n "$PREV_DESIRED" ] && \
                log_msg "STATUS_FILE changed: $PREV_DESIRED → $desired"
            PREV_DESIRED="$desired"
            DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
        fi

        if [ "$desired" = "ON" ] && \
           [ $((now - LAST_DNS_ATTEMPT)) -ge "$DNS_BACKOFF_CURRENT" ]; then
            LAST_DNS_ATTEMPT="$now"

            if ! is_port_open "$DNS_ENGINE_PORT" udp; then
                # TOCTOU mitigation: re-read intent immediately
                # before the API call, using the same trusted path.
                sleep 1
                recheck=$(get_user_intent)

                if [ "$recheck" != "ON" ]; then
                    log_msg "intent changed to $recheck — skipping DNS restart"
                    PREV_DESIRED="$recheck"
                    DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
                else
                    log_msg "DNS down ($DNS_ENGINE_PORT/UDP) — calling API"
                    _call_api
                    RC=$?

                    case "$RC" in
                        0)
                            case "$HTTP_BODY" in
                                *'"action":"started"'*)
                                    log_msg "✅ DNS started (action=started)"
                                    ;;
                                *'"action":"restart_initiated"'*)
                                    log_msg "✅ DNS restart initiated (async) — grace 10s"
                                    sleep 10
                                    ;;
                                *'"action":"none"'*)
                                    log_msg "✅ DNS already running (action=none)"
                                    ;;
                                *'"action":"skipped"'*)
                                    log_msg "ℹ️ DNS skipped (action=skipped)"
                                    ;;
                                *)
                                    log_msg "✅ DNS API OK (HTTP $HTTP_CODE)"
                                    ;;
                            esac
                            DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
                            ;;
                        3)
                            DNS_BACKOFF_CURRENT=$((DNS_BACKOFF_CURRENT * 2))
                            [ "$DNS_BACKOFF_CURRENT" -gt "$BACKOFF_MAX" ] && \
                                DNS_BACKOFF_CURRENT="$BACKOFF_MAX"
                            log_msg "⚠️ DNS API rate-limited — next in ${DNS_BACKOFF_CURRENT}s"
                            ;;
                        *)
                            DNS_BACKOFF_CURRENT=$((DNS_BACKOFF_CURRENT * 2))
                            [ "$DNS_BACKOFF_CURRENT" -gt "$BACKOFF_MAX" ] && \
                                DNS_BACKOFF_CURRENT="$BACKOFF_MAX"
                            log_msg "⚠️ DNS restart failed: ${HTTP_ERROR:-unknown} (rc=$RC) — next in ${DNS_BACKOFF_CURRENT}s"
                            ;;
                    esac
                fi
            else
                DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
            fi
        fi
    fi

    # --- [11.5] Periodic alive log ---
    if [ $((LOOP_COUNT % 20)) -eq 0 ]; then
        log_msg "Watchdog alive (loop #$LOOP_COUNT, webui=${WEBUI_BACKOFF_CURRENT}s, dns=${DNS_BACKOFF_CURRENT}s)"
    fi
done

# Unreachable — infinite loop above
exit 0