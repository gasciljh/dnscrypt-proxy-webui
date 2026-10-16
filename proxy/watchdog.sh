#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — watchdog.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-15
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Standalone watchdog process that monitors the WebUI and the
# DNS Engine and restarts them when needed.
#
# Launched by service.sh as an independent process (setsid +
# background), so that $$ inside this file refers to the real
# watchdog PID, not service.sh's.
#
# Responsibilities:
#   • Monitor the WebUI (TCP port) and restart if closed
#   • Monitor the DNS Engine (5354/UDP) via the main.go API
#   • Respect STATUS_FILE as "user intent":
#       ON  → restart DNS if crashed
#       OFF → do nothing
#   • Exponential backoff (30s → 600s max) per service
#   • Reset backoff on success and on STATUS_FILE change
#   • Handle HTTP 429 (rate limit) with additional backoff
#   • Exit cleanly when the disable file is present
#
# Arguments (in order):
#   1. WATCHDOG_PID_FILE
#   2. MODDIR
#   3. PORT              — WebUI port
#   4. AUTO_RESTART_DNS  — "0" or "1"
#   5. AUTO_RESTART_WEBUI — "0" or "1"
#
# Authentication (preferred → fallback):
#   1. X-Watchdog-Token header — token from $RUN_DIR/.watchdog_token
#   2. Authorization: Basic    — [monitoring_ui] in the TOML
#
# Design:
#   • Sources functions.sh (which sources boot-mini.sh).
#     Falls back to a minimal inline set only when sourcing
#     fails.
#   • The HTTP client cascade in watchdog_api_call is unique
#     to this file and is never delegated.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Version resolution (works with a single --version arg)
# ============================================================
# Pre-resolve the module root from $0 so `--version` works
# standalone, before the 5-argument count check below.
_MODDIR_FROM_SELF=${0%/*}
[ "$_MODDIR_FROM_SELF" = "." ] && _MODDIR_FROM_SELF=$(pwd)
case $_MODDIR_FROM_SELF in
    /*) ;;
    *)  _MODDIR_FROM_SELF="/data/adb/modules/${_MODDIR_FROM_SELF}" ;;
esac

get_version_from() {
    local vf="$1/module.prop"
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

case "${1:-}" in
    --version)
        echo "$0: $(get_version_from "$_MODDIR_FROM_SELF")"
        exit 0
        ;;
esac

# ============================================================
# [2] Parse arguments
# ============================================================
# Requires EXACTLY 5 arguments. Fewer means the caller is
# broken; more means the caller expects an interface that does
# not exist.
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
    echo "Usage: watchdog.sh <pid_file> <moddir> <port> <auto_dns> <auto_webui>" >&2
    exit 1
fi

if [ ! -d "$MODDIR" ]; then
    echo "watchdog.sh: MODDIR not found: $MODDIR" >&2
    exit 1
fi

if ! echo "$PORT" | grep -qE '^[0-9]+$' || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    PORT="9090"
fi

[ -z "$AUTO_RESTART_DNS" ]   && AUTO_RESTART_DNS="1"
[ -z "$AUTO_RESTART_WEBUI" ] && AUTO_RESTART_WEBUI="1"

case "$AUTO_RESTART_DNS"   in 0|1) ;; *) AUTO_RESTART_DNS="1"   ;; esac
case "$AUTO_RESTART_WEBUI" in 0|1) ;; *) AUTO_RESTART_WEBUI="1" ;; esac

# Re-read the version using the caller-supplied MODDIR (the
# authoritative source for the running module).
WATCHDOG_VERSION="$(get_version_from "$MODDIR")"

# --- Validate WebUI binary ---
WEBUI="$MODDIR/proxy/dnscrypt-webui"
if [ ! -f "$WEBUI" ]; then
    echo "watchdog.sh: WEBUI binary not found: $WEBUI" >&2
    exit 1
fi

# ============================================================
# [3] Default paths
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
RUN_DIR="$MODDIR/proxy/run"
STATUS_FILE="$RUN_DIR/dnscrypt.status"
TOML_FILE="$MODDIR/proxy/dnscrypt-proxy.toml"
SELECTED_PROFILE_FILE="$MODDIR/proxy/selected_profile.txt"

WATCHDOG_TOKEN_FILE="$RUN_DIR/.watchdog_token"

# Data preservation paths (READ-ONLY access).
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# Fallback if run/ is not writable.
if [ ! -d "$RUN_DIR" ] || [ ! -w "$RUN_DIR" ]; then
    RUN_DIR="/data/local/tmp"
    STATUS_FILE="/data/local/tmp/dnscrypt.status"
    WATCHDOG_TOKEN_FILE="/data/local/tmp/.watchdog_token"
fi

# ============================================================
# [4] Log prefix (must precede sourcing boot-mini.sh)
# ============================================================
# boot-mini.sh reads LOG_PREFIX from the environment. Setting
# it here ensures every log_msg call lands with the
# [watchdog] tag, distinguishing watchdog events from service
# and WebUI events in the shared log file.
LOG_PREFIX="[watchdog]"

# ============================================================
# [5] Source functions.sh (which sources boot-mini.sh)
# ============================================================
# Search order:
#   1. $MODDIR/functions.sh        — post-install layout
#   2. $MODDIR/proxy/functions.sh  — defensive (should not exist)
#
# After a successful source, init_runtime_paths() is called to
# populate RUN_DIR_ACTIVE and the *_FILE path variables.
FUNCTIONS_LOADED=0

for _cand in "$MODDIR/functions.sh" "$MODDIR/proxy/functions.sh"; do
    if [ -f "$_cand" ]; then
        # shellcheck disable=SC1090
        . "$_cand" 2>/dev/null

        if command -v log_msg >/dev/null 2>&1 \
           && command -v is_port_open >/dev/null 2>&1 \
           && command -v cleanup_webui >/dev/null 2>&1 \
           && command -v start_native_webui >/dev/null 2>&1; then
            FUNCTIONS_LOADED=1

            if command -v init_runtime_paths >/dev/null 2>&1; then
                init_runtime_paths
            fi
        fi
        break
    fi
done

# Restore the preferred prefix after sourcing.
LOG_PREFIX="[watchdog]"

# ============================================================
# [6] Inline fallbacks (minimal)
# ============================================================
# Only the primitives required for monitoring are provided
# here. Everything else (backup, rotation, firewall) is
# unnecessary for the watchdog's job.
_fb_log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [watchdog] $1" >> "$LOG_FILE" 2>/dev/null
}

_fb_is_port_open() {
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

_fb_cleanup_webui() {
    pkill -9 -x dnscrypt-webui 2>/dev/null
    rm -f "$RUN_DIR/webui.pid" 2>/dev/null
    rm -f /data/local/tmp/webui.pid 2>/dev/null
}

_fb_start_webui() {
    local bin="$1"
    local port="$2"

    _fb_log "Starting WebUI (inline, port: $port)"

    _fb_cleanup_webui

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
        printf "%d\n" "$web_pid" > "${RUN_DIR}/webui.pid.tmp" 2>/dev/null
        mv -f "${RUN_DIR}/webui.pid.tmp" "${RUN_DIR}/webui.pid" 2>/dev/null
    fi

    local i=0
    while [ "$i" -lt 35 ]; do
        if [ -n "$web_pid" ] && ! kill -0 "$web_pid" 2>/dev/null; then
            _fb_log "ERROR: WebUI process died (Port collision?)"
            return 1
        fi
        if _fb_is_port_open "$port" tcp; then
            _fb_log "WebUI bound to port $port (PID: ${web_pid:-unknown})"
            return 0
        fi
        sleep 1
        i=$((i + 1))
    done

    _fb_log "ERROR: WebUI failed to bind within 35s"
    return 1
}

# ============================================================
# [7] Unified wrappers
# ============================================================
# Every call site below uses the do_* names, never the
# underlying functions directly. This lets the loop code read
# identically whether functions.sh loaded or not.
if [ "$FUNCTIONS_LOADED" = "1" ]; then
    do_log()           { log_msg "$1"; }
    do_is_port_open()  { is_port_open "$1" "${2:-tcp}"; }
    do_cleanup_webui() { cleanup_webui; }
    do_start_webui()   { start_native_webui "$1" "$2"; }

    if command -v get_profile_memory_hint >/dev/null 2>&1; then
        do_mem_hint()  { get_profile_memory_hint; }
    else
        do_mem_hint()  { printf "unknown"; }
    fi

    if command -v get_watchdog_token >/dev/null 2>&1; then
        do_get_token() { get_watchdog_token; }
    else
        do_get_token() { return 1; }
    fi
else
    do_log()           { _fb_log "$1"; }
    do_is_port_open()  { _fb_is_port_open "$1" "${2:-tcp}"; }
    do_cleanup_webui() { _fb_cleanup_webui; }
    do_start_webui()   { _fb_start_webui "$1" "$2"; }
    do_mem_hint()      { printf "unknown"; }
    do_get_token()     { return 1; }
fi

# ============================================================
# [8] Prevent duplicate watchdog instances
# ============================================================
# On startup, checks the existing PID file. If a live watchdog
# is already running, this process exits silently with code 0.
#
# `kill -0` returns 0 for zombies. The check therefore also
# inspects /proc/PID/stat and rejects state 'Z'. Without this,
# a zombie watchdog would block a new watchdog from starting.
#
# Three outcomes:
#   1. PID exists, alive, comm matches shell → log and exit 0.
#   2. PID exists, alive, comm is something else → PID
#      reused; log and continue.
#   3. PID exists, state is 'Z' → zombie; log and continue.
if [ -f "$WATCHDOG_PID_FILE" ]; then
    old_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$old_pid" ] && [ -d "/proc/$old_pid" ]; then
        # Extract the process state safely: strip everything up
        # to and including the LAST ')' in /proc/<pid>/stat,
        # then take the first field. This handles `comm` values
        # that contain spaces or parentheses (unlike a naive
        # `awk '{print $3}'`, which would split on them).
        old_state=$(sed 's/.*) //' "/proc/$old_pid/stat" 2>/dev/null | awk '{print $1}')

        if [ "$old_state" = "Z" ]; then
            do_log "PID $old_pid is a zombie (stale PID file) — ignoring"
        else
            old_comm=$(cat "/proc/$old_pid/comm" 2>/dev/null)
            case "$old_comm" in
                busybox|*sh)
                    do_log "Watchdog already running (PID: $old_pid), exiting"
                    exit 0
                    ;;
                *)
                    do_log "PID $old_pid was reused by '$old_comm', ignoring"
                    ;;
            esac
        fi
    fi
fi

# ============================================================
# [9] Write real PID
# ============================================================
# We run as an independent process (not a subshell).
# $$ = this process's PID = real watchdog PID.
#
# Explicit error check on both the tmp-write and the atomic
# rename. If either fails, the watchdog refuses to run — a
# watchdog without a PID file cannot be supervised by
# service.sh, and cannot be reliably stopped by uninstall.sh.
if ! printf "%d\n" $$ > "${WATCHDOG_PID_FILE}.tmp" 2>/dev/null; then
    do_log "FATAL: cannot write PID tmp file: ${WATCHDOG_PID_FILE}.tmp"
    exit 1
fi
if ! mv -f "${WATCHDOG_PID_FILE}.tmp" "$WATCHDOG_PID_FILE" 2>/dev/null; then
    do_log "FATAL: cannot move PID file into place: $WATCHDOG_PID_FILE"
    rm -f "${WATCHDOG_PID_FILE}.tmp" 2>/dev/null
    exit 1
fi

# ============================================================
# [10] Startup diagnostics (READ-ONLY)
# ============================================================
# Logs a structured snapshot of the module state at watchdog
# startup. This makes the boot log a complete picture without
# requiring the user to run status.sh manually.
#
# READ-ONLY: this block inspects the backup directory but does
# NOT create, modify, or delete any files.
#
# The snapshot counter requires BOTH a name match
# (`^[0-9]{8}-[0-9]{6}-`) AND a `.manifest.json` file, matching
# the canonical SNAP-MANIFEST detection rule. The `case`
# statement below also skips `apk/` and `.restore_snap.*`.
_pending_msg=""
if [ -f "$PENDING_NOTIFY_FILE" ]; then
    _pending_msg=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
fi

_last_stable=""
if [ -f "$LAST_STABLE_FILE" ]; then
    _last_stable=$(cat "$LAST_STABLE_FILE" 2>/dev/null | tr -d '\r\n ')
fi

_snap_count=0
if [ -d "$PERSISTENT_BACKUP" ]; then
    _snap_count=$(
        cd "$PERSISTENT_BACKUP" 2>/dev/null || exit 0
        count=0
        for _sd in */; do
            _sd="${_sd%/}"
            [ -d "$_sd" ] || continue
            case "$_sd" in
                current|txn-*|orphan-txn-*|apk|.restore_snap.*) continue ;;
            esac
            if ! echo "$_sd" | grep -qE '^[0-9]{8}-[0-9]{6}-'; then
                continue
            fi
            [ -f "$_sd/.manifest.json" ] || continue
            count=$((count + 1))
        done
        printf '%s' "$count"
    )
    [ -z "$_snap_count" ] && _snap_count=0
fi

_txn_count=0
if [ -d "$PERSISTENT_BACKUP" ]; then
    _txn_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d txn-*/ 2>/dev/null | \
        wc -l | tr -d ' ')
    [ -z "$_txn_count" ] && _txn_count=0
fi

_orphan_count=0
if [ -d "$PERSISTENT_BACKUP" ]; then
    _orphan_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d orphan-txn-*/ 2>/dev/null | \
        wc -l | tr -d ' ')
    [ -z "$_orphan_count" ] && _orphan_count=0
fi

_token_present="no"
if do_get_token >/dev/null 2>&1; then
    _token_present="yes"
fi

# --- Startup banner (structured) ---
do_log "============================================"
do_log "Watchdog started (PID: $$)"
do_log "   Version: $WATCHDOG_VERSION"
do_log "─── Config ───"
do_log "   MODDIR:     $MODDIR"
do_log "   PORT:       $PORT"
do_log "   Auto-DNS:   $AUTO_RESTART_DNS"
do_log "   Auto-WebUI: $AUTO_RESTART_WEBUI"
do_log "─── Paths ───"
do_log "   RUN_DIR:    $RUN_DIR"
do_log "   STATUS_FILE: $STATUS_FILE"
do_log "─── Auth ───"
do_log "   Token file: $WATCHDOG_TOKEN_FILE"
do_log "   Token ready: $_token_present"
do_log "   functions.sh: $([ "$FUNCTIONS_LOADED" = "1" ] && echo loaded || echo fallback)"
do_log "─── Data Preservation (READ-ONLY) ───"
do_log "   Snapshot dir:   $PERSISTENT_BACKUP"
do_log "   Snapshots:      $_snap_count"
do_log "   In-flight txn:  $_txn_count"
do_log "   Orphan txn:     $_orphan_count"
if [ -n "$_last_stable" ]; then
    do_log "   Last stable:    $_last_stable"
else
    do_log "   Last stable:    (none yet)"
fi
if [ -n "$_pending_msg" ]; then
    do_log "   Notification:   $_pending_msg"
    do_log "   (main.go will log and delete this at startup)"
fi
do_log "   Note: this script does NOT touch the backup directory."
do_log "   Note: install_app.sh is not supervised by the watchdog."
do_log "============================================"

# ============================================================
# [11] Traps for clean exit
# ============================================================
# Single handler function, three signal bindings. The
# single-quoted trap bodies defer $WATCHDOG_PID_FILE expansion
# to fire time.
#
# POSIX-mandated exit codes:
#   SIGINT  → 130
#   SIGTERM → 143
# We use 0 here because the watchdog exiting cleanly is a
# normal terminal state — a supervisor (service.sh) reads the
# PID file, not the exit code.
_wd_terminate() {
    local _sig="${1:-UNKNOWN}"
    do_log "Watchdog terminated (SIG$_sig)"
    rm -f "$WATCHDOG_PID_FILE" 2>/dev/null
    exit 0
}

trap '_wd_terminate TERM' TERM
trap '_wd_terminate INT'  INT
trap '_wd_terminate QUIT' QUIT

# ============================================================
# [12] Watchdog token reader
# ============================================================
# The token path is preferred over Basic Auth: independent of
# the credentials file, constant-time-compared, localhost-
# scoped, and not subject to the login rate limiter.
#
# Return values:
#   0 — token read and looks valid (>= 32 chars); printed to
#       stdout
#   1 — token file missing, empty, or too short
get_watchdog_token_fallback() {
    [ -f "$WATCHDOG_TOKEN_FILE" ] || return 1

    local tok
    tok=$(cat "$WATCHDOG_TOKEN_FILE" 2>/dev/null | tr -d '\r\n ')

    [ -n "$tok" ] || return 1
    [ "${#tok}" -ge 32 ] || return 1

    printf "%s" "$tok"
    return 0
}

# Final token getter: prefer functions.sh's version when
# available; fall back to the inline reader otherwise.
if [ "$FUNCTIONS_LOADED" = "1" ] && command -v get_watchdog_token >/dev/null 2>&1; then
    do_get_token() { get_watchdog_token; }
else
    do_get_token() { get_watchdog_token_fallback; }
fi

# ============================================================
# [13] Fallback credentials (Basic Auth)
# ============================================================
# Used ONLY when the watchdog token is unavailable. Requires
# functions.sh's read_toml_credentials, which handles the
# section-restricted TOML parsing.
#
# When functions.sh failed to load, Basic Auth is disabled —
# the watchdog continues in token-only mode. This is a
# deliberate degraded state: if functions.sh is missing, the
# module is in a broken configuration and the watchdog should
# not maintain a parallel TOML parser that could drift.
WATCH_USER=""
WATCH_PASS=""
HAS_CREDS=0

if [ "$FUNCTIONS_LOADED" = "1" ] && command -v read_toml_credentials >/dev/null 2>&1; then
    if [ -f "$TOML_FILE" ]; then
        _wd_creds=$(read_toml_credentials 2>/dev/null)
        WATCH_USER=$(printf '%s' "$_wd_creds" | sed -n '1p')
        WATCH_PASS=$(printf '%s' "$_wd_creds" | sed -n '2p')
        unset _wd_creds

        if [ -n "$WATCH_USER" ] && [ -n "$WATCH_PASS" ]; then
            HAS_CREDS=1
            do_log "Fallback credentials loaded from [monitoring_ui]"
        fi
    fi
fi

if [ "$HAS_CREDS" = "0" ]; then
    do_log "No fallback credentials (token-only mode)"
fi

# ============================================================
# [14] Base64 availability (Basic Auth fallback only)
# ============================================================
# If neither `base64` nor `busybox base64` is available,
# BASE64_CMD stays empty and watchdog_api_call skips the Basic
# Auth fallback — only the watchdog token path remains usable.
BASE64_CMD=""
if command -v base64 >/dev/null 2>&1; then
    BASE64_CMD="base64"
elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q "^base64$"; then
    BASE64_CMD="busybox base64"
fi

# ============================================================
# [15] Explicit safe PATH for the HTTP client
# ============================================================
# The HTTP client invocations below use `env -i` to start with
# an EMPTY environment, then explicitly set:
#   • PATH=$SAFE_PATH
#   • HOME=/data/local/tmp
#   • http_proxy / https_proxy / HTTP_PROXY / HTTPS_PROXY = ""
#   • no_proxy / NO_PROXY = ""
#
# The empty proxy variables are critical: on a device where the
# user has configured a proxy, an inherited `http_proxy` would
# redirect the watchdog's localhost API call through that
# proxy — which would fail (the proxy cannot reach 127.0.0.1)
# or leak the watchdog token to the proxy.
SAFE_PATH="/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin"

# ============================================================
# [16] API call helper
# ============================================================
# Uses POST /api/ensure_running_service for CSRF-GET protection.
#
# Authentication (preferred → fallback):
#   1. X-Watchdog-Token header  — preferred
#   2. Authorization: Basic ... — fallback (only when no token)
#
# Return codes:
#   0 — success (2xx)
#   1 — no HTTP client available
#   2 — network/timeout failure
#   3 — 429 rate-limited
#   4 — other HTTP error, or unable to determine the result
#
# Temp files live under $RUN_DIR, not /tmp. On modern Android,
# /tmp is NOT guaranteed to exist — a failed redirect would
# leave `http_code` empty and the function would fall through
# to "success", defeating the watchdog's primary purpose.
#
# 429 handling across all three HTTP clients:
#   • curl — reads the status code via `-w '%{http_code}'`.
#   • wget / busybox wget — `-qO-` does not print headers, so
#     we add `-S` (--server-response). The status line is
#     matched against `HTTP/[0-9.]+[[:space:]]+429`.
watchdog_api_call() {
    local action="$1"
    local tool=""
    local wd_token=""
    local token_header=""
    local auth_header=""
    local b64=""
    local url=""
    local http_code=""
    local exit_code=0
    local tmp_resp=""
    local tmp_code=""
    local output=""

    if command -v curl >/dev/null 2>&1; then
        tool="curl"
    elif command -v wget >/dev/null 2>&1; then
        tool="wget"
    elif command -v busybox >/dev/null 2>&1; then
        tool="busybox"
    else
        do_log "WARNING: no HTTP client available"
        return 1
    fi

    # --- Build X-Watchdog-Token header (preferred) ---
    wd_token=$(do_get_token 2>/dev/null || :)
    if [ -n "$wd_token" ]; then
        token_header="X-Watchdog-Token: $wd_token"
    fi

    # --- Build Authorization header (fallback) ---
    if [ -z "$wd_token" ] && [ "$HAS_CREDS" = "1" ] && [ -n "$BASE64_CMD" ]; then
        b64=$(printf "%s:%s" "$WATCH_USER" "$WATCH_PASS" | $BASE64_CMD 2>/dev/null | tr -d '\n')
        if [ -n "$b64" ]; then
            auth_header="Authorization: Basic $b64"
        fi
    fi

    url="http://127.0.0.1:$PORT/api/${action}_service"

    case "$tool" in
        curl)
            tmp_resp="${RUN_DIR}/.wd_resp.$$"
            tmp_code="${RUN_DIR}/.wd_code.$$"

            if [ -n "$token_header" ] && [ -n "$auth_header" ]; then
                env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    curl -s --noproxy '*' --max-time 5 \
                    -o "$tmp_resp" -w '%{http_code}' \
                    -X POST \
                    -H "$token_header" \
                    -H "$auth_header" "$url" \
                    > "$tmp_code" 2>/dev/null
            elif [ -n "$token_header" ]; then
                env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    curl -s --noproxy '*' --max-time 5 \
                    -o "$tmp_resp" -w '%{http_code}' \
                    -X POST \
                    -H "$token_header" \
                    "$url" \
                    > "$tmp_code" 2>/dev/null
            elif [ -n "$auth_header" ]; then
                env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    curl -s --noproxy '*' --max-time 5 \
                    -o "$tmp_resp" -w '%{http_code}' \
                    -X POST \
                    -H "$auth_header" "$url" \
                    > "$tmp_code" 2>/dev/null
            else
                env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    curl -s --noproxy '*' --max-time 5 \
                    -o "$tmp_resp" -w '%{http_code}' \
                    -X POST \
                    "$url" \
                    > "$tmp_code" 2>/dev/null
            fi
            exit_code=$?

            if [ -f "$tmp_code" ]; then
                http_code=$(cat "$tmp_code" 2>/dev/null | tr -d '\r\n ')
            fi
            rm -f "$tmp_resp" "$tmp_code" 2>/dev/null

            # --- Analyze curl result ---
            if [ "$exit_code" -ne 0 ]; then
                do_log "WARNING: API call failed (exit=$exit_code) — network/timeout"
                return 2
            fi

            if [ -n "$http_code" ]; then
                case "$http_code" in
                    200|201|202|204)
                        do_log "API call succeeded (HTTP $http_code)"
                        return 0
                        ;;
                    429)
                        do_log "API rate-limited (HTTP 429) — backing off"
                        return 3
                        ;;
                    *)
                        do_log "WARNING: API call returned HTTP $http_code"
                        return 4
                        ;;
                esac
            fi

            do_log "WARNING: API call returned no HTTP status code (undecidable) — treating as error"
            return 4
            ;;

        wget)
            if [ -n "$token_header" ] && [ -n "$auth_header" ]; then
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    wget -S -qO- --timeout=10 \
                    --post-data='' \
                    --header="$token_header" \
                    --header="$auth_header" "$url" \
                    2>&1) || exit_code=$?
            elif [ -n "$token_header" ]; then
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    wget -S -qO- --timeout=10 \
                    --post-data='' \
                    --header="$token_header" "$url" \
                    2>&1) || exit_code=$?
            elif [ -n "$auth_header" ]; then
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    wget -S -qO- --timeout=10 \
                    --post-data='' \
                    --header="$auth_header" "$url" \
                    2>&1) || exit_code=$?
            else
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    wget -S -qO- --timeout=10 \
                    --post-data='' \
                    "$url" \
                    2>&1) || exit_code=$?
            fi

            if [ "$exit_code" -eq 0 ]; then
                do_log "API call succeeded (wget exit 0)"
                return 0
            fi
            if [ "$exit_code" -eq 8 ]; then
                if printf '%s' "$output" | grep -qE 'HTTP/[0-9.]+[[:space:]]+429'; then
                    do_log "API rate-limited (HTTP 429) — backing off"
                    return 3
                fi
                do_log "WARNING: API call returned HTTP error (wget exit 8)"
                return 4
            fi
            do_log "WARNING: API call failed (wget exit=$exit_code) — network/timeout"
            return 2
            ;;

        busybox)
            if [ -n "$token_header" ] && [ -n "$auth_header" ]; then
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    busybox wget -S -qO- --timeout=10 \
                    --post-data='' \
                    --header="$token_header" \
                    --header="$auth_header" "$url" \
                    2>&1) || exit_code=$?
            elif [ -n "$token_header" ]; then
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    busybox wget -S -qO- --timeout=10 \
                    --post-data='' \
                    --header="$token_header" "$url" \
                    2>&1) || exit_code=$?
            elif [ -n "$auth_header" ]; then
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    busybox wget -S -qO- --timeout=10 \
                    --post-data='' \
                    --header="$auth_header" "$url" \
                    2>&1) || exit_code=$?
            else
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    busybox wget -S -qO- --timeout=10 \
                    --post-data='' \
                    "$url" \
                    2>&1) || exit_code=$?
            fi

            if [ "$exit_code" -eq 0 ]; then
                do_log "API call succeeded (busybox wget exit 0)"
                return 0
            fi

            if printf '%s' "$output" | grep -qE 'HTTP/[0-9.]+[[:space:]]+429'; then
                do_log "API rate-limited (HTTP 429) — backing off"
                return 3
            fi

            do_log "WARNING: API call failed (busybox wget exit=$exit_code) — HTTP or network error"
            return 4
            ;;
    esac

    # Unreachable — all three branches return explicitly.
    return 4
}

# ============================================================
# [17] Exponential backoff
# ============================================================
# Two independent backoff timers, one per monitored service:
#
#   WEBUI_BACKOFF_CURRENT — wait between WebUI restart attempts
#   DNS_BACKOFF_CURRENT   — wait between DNS restart attempts
#
# Both start at BACKOFF_BASE (30 seconds) and double up to
# BACKOFF_MAX (600 seconds = 10 minutes) on consecutive
# failures. Both reset to BACKOFF_BASE on:
#   • A successful restart.
#   • A change in the user's STATUS_FILE value (DNS only —
#     the WebUI has no equivalent "user intent" file).
#
# The main-loop sleep is the SMALLER of the two current
# backoffs, with a floor of 5 seconds and a ceiling of
# BACKOFF_MAX. This ensures a long backoff on one service
# does not delay the other service's recovery attempts.
BACKOFF_BASE=30
BACKOFF_MAX=600

WEBUI_BACKOFF_CURRENT=30
DNS_BACKOFF_CURRENT=30

PREV_DESIRED=""

# ============================================================
# [18] Main loop
# ============================================================
# Infinite `while true` loop. Each iteration performs:
#
#   [18.0] Compute the sleep duration for this iteration.
#   [18.1] Check for the module's `disable` file (exit cleanly
#          if present).
#   [18.2] Attempt a WebUI restart if its backoff has elapsed.
#   [18.3] Attempt a DNS restart if its backoff has elapsed
#          AND the user's STATUS_FILE says ON.
#   [18.4] Emit a periodic "alive" log line every 20 iterations.
#
# All state that survives across iterations is held in global
# variables. Making them `local` would reset them on every
# iteration.
#
# The loop is intentionally NOT bounded by a timeout or a
# maximum-iteration count — a watchdog's only correct
# termination condition is a signal (handled by the traps in
# [11]) or the module being disabled ([18.1]).
do_log "Entering main loop..."
LOOP_COUNT=0

LAST_WEBUI_ATTEMPT=0
LAST_DNS_ATTEMPT=0

_profile_hint=$(do_mem_hint)
do_log "Active profile: $_profile_hint"

while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))

    # ============================================================
    # [18.0] Compute sleep
    # ============================================================
    # Sleep duration is the SMALLER of the two current backoffs,
    # clamped to [5, BACKOFF_MAX].
    SLEEP_DURATION="$WEBUI_BACKOFF_CURRENT"
    if [ "$DNS_BACKOFF_CURRENT" -lt "$SLEEP_DURATION" ]; then
        SLEEP_DURATION="$DNS_BACKOFF_CURRENT"
    fi
    [ "$SLEEP_DURATION" -lt 5 ] && SLEEP_DURATION=5
    [ "$SLEEP_DURATION" -gt "$BACKOFF_MAX" ] && SLEEP_DURATION="$BACKOFF_MAX"

    sleep "$SLEEP_DURATION"

    # ============================================================
    # [18.1] Check for disable
    # ============================================================
    # The `disable` file is written by the manager when the user
    # disables the module. On detection, the watchdog removes
    # its own PID file and exits cleanly (code 0).
    if [ -f "$MODDIR/disable" ]; then
        do_log "module disabled -> Watchdog exiting"
        rm -f "$WATCHDOG_PID_FILE" 2>/dev/null
        exit 0
    fi

    # ============================================================
    # Guard against empty `date` output
    # ============================================================
    # `date +%s` can fail (returning empty) on a device where
    # the system clock is broken. An empty `now` would make
    # every arithmetic below fail. Setting `now=0` degrades
    # gracefully — no restart attempt fires this iteration.
    now=$(date +%s 2>/dev/null)
    case "$now" in
        ''|*[!0-9]*) now=0 ;;
    esac

    # ============================================================
    # [18.2] Restart WebUI
    # ============================================================
    # Only attempt a restart when ALL of the following hold:
    #   • AUTO_RESTART_WEBUI is "1".
    #   • WEBUI_BACKOFF_CURRENT has elapsed since
    #     LAST_WEBUI_ATTEMPT.
    #   • The WebUI port is NOT listening.
    #
    # If the WebUI port IS listening, the backoff is reset to
    # BACKOFF_BASE — a healthy service should not carry the
    # penalty of a previous failure.
    if [ "$AUTO_RESTART_WEBUI" = "1" ]; then
        if [ $((now - LAST_WEBUI_ATTEMPT)) -ge "$WEBUI_BACKOFF_CURRENT" ]; then
            LAST_WEBUI_ATTEMPT="$now"

            if ! do_is_port_open "$PORT" tcp; then
                do_log "WebUI down on port $PORT — restarting..."
                do_cleanup_webui
                sleep 1

                if do_start_webui "$WEBUI" "$PORT"; then
                    WEBUI_BACKOFF_CURRENT="$BACKOFF_BASE"
                else
                    WEBUI_BACKOFF_CURRENT=$((WEBUI_BACKOFF_CURRENT * 2))
                    [ "$WEBUI_BACKOFF_CURRENT" -gt "$BACKOFF_MAX" ] && WEBUI_BACKOFF_CURRENT="$BACKOFF_MAX"
                    do_log "WARNING: WebUI restart failed — next attempt in ${WEBUI_BACKOFF_CURRENT}s"
                fi
            else
                WEBUI_BACKOFF_CURRENT="$BACKOFF_BASE"
            fi
        fi
    fi

    # ============================================================
    # [18.3] Restart DNS Engine
    # ============================================================
    # STATUS_FILE represents "user intent":
    #   * ON  = user wants the service running → Watchdog
    #           restarts it
    #   * OFF = user stopped it manually → Watchdog does
    #           nothing
    #
    # DNS backoff resets when STATUS_FILE changes.
    #
    # TOCTOU mitigation:
    #   After the initial `if [ "$desired" = "ON" ]` check, the
    #   code re-reads STATUS_FILE immediately before calling the
    #   API. This closes the window in which the user could have
    #   pressed "Stop" in the WebUI between the first read and
    #   the API call.
    #
    # RC handling from watchdog_api_call:
    #   RC=0  → success. Reset backoff to base.
    #   RC=3  → rate-limited (HTTP 429). Double the backoff.
    #   other → any other failure. Double the backoff.
    if [ "$AUTO_RESTART_DNS" = "1" ]; then
        desired="OFF"
        if [ -f "$STATUS_FILE" ]; then
            desired=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
        fi
        [ -z "$desired" ] && desired="OFF"

        # --- Detect intent change → reset backoff ---
        if [ "$desired" != "$PREV_DESIRED" ]; then
            if [ -n "$PREV_DESIRED" ]; then
                do_log "STATUS_FILE changed: $PREV_DESIRED -> $desired"
            fi
            PREV_DESIRED="$desired"
            DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
        fi

        if [ "$desired" = "ON" ]; then
            if [ $((now - LAST_DNS_ATTEMPT)) -ge "$DNS_BACKOFF_CURRENT" ]; then
                LAST_DNS_ATTEMPT="$now"

                if ! do_is_port_open 5354 udp; then
                    sleep 1
                    recheck="OFF"
                    if [ -f "$STATUS_FILE" ]; then
                        recheck=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
                    fi

                    if [ "$recheck" != "ON" ]; then
                        do_log "status changed to $recheck during check — skipping restart"
                        PREV_DESIRED="$recheck"
                        DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
                    else
                        do_log "DNS Engine down (5354/UDP) — calling ensure_running..."

                        watchdog_api_call "ensure_running"
                        RC=$?

                        case "$RC" in
                            0)
                                do_log "DNS restart succeeded"
                                DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
                                ;;
                            3)
                                DNS_BACKOFF_CURRENT=$((DNS_BACKOFF_CURRENT * 2))
                                [ "$DNS_BACKOFF_CURRENT" -gt "$BACKOFF_MAX" ] && DNS_BACKOFF_CURRENT="$BACKOFF_MAX"
                                do_log "WARNING: rate-limited — next attempt in ${DNS_BACKOFF_CURRENT}s"
                                ;;
                            *)
                                DNS_BACKOFF_CURRENT=$((DNS_BACKOFF_CURRENT * 2))
                                [ "$DNS_BACKOFF_CURRENT" -gt "$BACKOFF_MAX" ] && DNS_BACKOFF_CURRENT="$BACKOFF_MAX"
                                do_log "WARNING: DNS restart failed (rc=$RC) — next attempt in ${DNS_BACKOFF_CURRENT}s"
                                ;;
                        esac
                    fi
                else
                    DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
                fi
            fi
        fi
    fi

    # ============================================================
    # [18.4] Periodic log every 20 iterations (~10 minutes)
    # ============================================================
    # Reports the current values of both backoffs so an operator
    # inspecting the log can see whether either service is in a
    # degraded state.
    if [ $((LOOP_COUNT % 20)) -eq 0 ]; then
        do_log "Watchdog alive (loop #$LOOP_COUNT, webui_backoff=${WEBUI_BACKOFF_CURRENT}s, dns_backoff=${DNS_BACKOFF_CURRENT}s)"
    fi
done

# Unreachable (infinite loop)
exit 0
