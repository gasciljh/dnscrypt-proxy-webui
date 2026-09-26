#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – watchdog.sh
# Version: v1.1.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Standalone watchdog process that monitors the WebUI and the
#   DNS Engine and restarts them when needed.
#
#   The watchdog is launched by service.sh as an independent
#   process (nohup + background), so that $$ inside this file
#   refers to the real watchdog PID, not service.sh's.
#
# Responsibilities:
#   • Monitor the WebUI (TCP port) and restart it if closed
#   • Monitor the DNS Engine (5354/UDP) and restart it via the
#     main.go API (POST /api/ensure_running_service)
#   • Respect STATUS_FILE as "user intent":
#       ON  → restart DNS if crashed
#       OFF → do nothing (user stopped it manually)
#   • Exponential backoff (30s → 600s max) per service
#   • Reset backoff on success and on STATUS_FILE change
#   • Handle HTTP 429 (rate limit) with additional backoff
#   • Exit cleanly when the disable file is present
#
# Arguments (in order):
#   1. WATCHDOG_PID_FILE   — path to the watchdog PID file
#   2. MODDIR              — module directory
#   3. PORT                — WebUI port (TCP)
#   4. AUTO_RESTART_DNS    — "0" or "1"
#   5. AUTO_RESTART_WEBUI  — "0" or "1"
#
# Credentials:
#   Read from dnscrypt-proxy.toml [monitoring_ui] section only.
#   Section header with trailing comment is supported.
#
# API call:
#   Uses POST /api/ensure_running_service (CSRF-GET protection).
#   Return codes:
#     0 — success (2xx)
#     1 — no HTTP client available
#     2 — network/timeout failure
#     3 — 429 rate-limited
#     4 — other HTTP error
#
# v1.1.0 additions:
#   • Logs the active profile + expected memory hint at startup
#     (self-contained — does not depend on functions.sh)
#   • Structured startup banner with profile context
#   • All messages are English (global release)
#
# Coordination with main.go v1.1.0:
#   • main.go adjusts the Go runtime soft memory limit based on
#     the selected profile (light → 80MB, ultimate → 220MB).
#   • This script only REPORTS the hint at startup; the actual
#     limit is managed by main.go.
#   • The watchdog does NOT need to know the memory limit to do
#     its job — restarting services is orthogonal to how much
#     memory the WebUI uses.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Parse arguments
# ============================================================
WATCHDOG_PID_FILE="$1"
MODDIR="$2"
PORT="$3"
AUTO_RESTART_DNS="$4"
AUTO_RESTART_WEBUI="$5"

# --- Argument validation ---
if [ -z "$WATCHDOG_PID_FILE" ] || [ -z "$MODDIR" ]; then
    echo "watchdog.sh: missing required args" >&2
    echo "Usage: watchdog.sh <pid_file> <moddir> <port> <auto_dns> <auto_webui>" >&2
    exit 1
fi

[ -z "$PORT" ]               && PORT="9090"
[ -z "$AUTO_RESTART_DNS" ]   && AUTO_RESTART_DNS="1"
[ -z "$AUTO_RESTART_WEBUI" ] && AUTO_RESTART_WEBUI="1"

case "$AUTO_RESTART_DNS"   in 0|1) ;; *) AUTO_RESTART_DNS="1"   ;; esac
case "$AUTO_RESTART_WEBUI" in 0|1) ;; *) AUTO_RESTART_WEBUI="1" ;; esac

# --- Validate MODDIR ---
if [ ! -d "$MODDIR" ]; then
    echo "watchdog.sh: MODDIR not found: $MODDIR" >&2
    exit 1
fi

# --- Validate WEBUI binary ---
WEBUI="$MODDIR/proxy/dnscrypt-webui"
if [ ! -f "$WEBUI" ]; then
    echo "watchdog.sh: WEBUI binary not found: $WEBUI" >&2
    exit 1
fi

# ============================================================
# [2] Paths
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
RUN_DIR="$MODDIR/proxy/run"
STATUS_FILE="$RUN_DIR/dnscrypt.status"
TOML_FILE="$MODDIR/proxy/dnscrypt-proxy.toml"
SELECTED_PROFILE_FILE="$MODDIR/proxy/selected_profile.txt"

# Fallback if run/ is not writable
if [ ! -d "$RUN_DIR" ] || [ ! -w "$RUN_DIR" ]; then
    RUN_DIR="/data/local/tmp"
    STATUS_FILE="/data/local/tmp/dnscrypt.status"
fi

# ============================================================
# [3] log_msg
# ============================================================
log_msg() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [watchdog] $1" >> "$LOG_FILE" 2>/dev/null
}

# ============================================================
# [4] Prevent duplicate watchdog instances
# ============================================================
if [ -f "$WATCHDOG_PID_FILE" ]; then
    old_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        old_comm=$(cat "/proc/$old_pid/comm" 2>/dev/null)
        case "$old_comm" in
            sh|ash|bash|busybox|*sh)
                log_msg "Watchdog already running (PID: $old_pid), exiting"
                exit 0
                ;;
            *)
                log_msg "PID $old_pid was reused by '$old_comm', ignoring"
                ;;
        esac
    fi
fi

# ============================================================
# [5] Write real PID
# ============================================================
# We run as an independent process (not a subshell).
# $$ = this process's PID = real watchdog PID.
# ============================================================
printf "%d\n" $$ > "${WATCHDOG_PID_FILE}.tmp"
mv -f "${WATCHDOG_PID_FILE}.tmp" "$WATCHDOG_PID_FILE"

log_msg "============================================"
log_msg "Watchdog started (PID: $$)"
log_msg "   Version: v1.1.0"
log_msg "   MODDIR:  $MODDIR"
log_msg "   PORT:    $PORT"
log_msg "   Auto-DNS:   $AUTO_RESTART_DNS"
log_msg "   Auto-WebUI: $AUTO_RESTART_WEBUI"
log_msg "   RUN_DIR: $RUN_DIR"
log_msg "   STATUS_FILE: $STATUS_FILE"
log_msg "============================================"

# ============================================================
# [6] Trap for clean exit
# ============================================================
# shellcheck disable=SC2064
trap '
    log_msg "Watchdog terminated (SIGTERM/SIGINT)";
    rm -f "$WATCHDOG_PID_FILE" 2>/dev/null;
    exit 0
' TERM INT

# shellcheck disable=SC2064
trap '
    log_msg "Watchdog terminated (SIGQUIT)";
    rm -f "$WATCHDOG_PID_FILE" 2>/dev/null;
    exit 0
' QUIT

# ============================================================
# [7] Internal helpers (self-contained — no functions.sh dependency)
# ============================================================

# --- Port check ---
_wd_is_port_open() {
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

# --- WebUI cleanup ---
_wd_cleanup_webui() {
    pkill -9 -x dnscrypt-webui 2>/dev/null
    rm -f "$RUN_DIR/webui.pid" 2>/dev/null
    rm -f /data/local/tmp/webui.pid 2>/dev/null
}

# --- Start WebUI ---
_wd_start_webui() {
    local bin="$1"
    local port="$2"

    log_msg "Starting WebUI (port: $port)"
    _wd_cleanup_webui

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
            log_msg "ERROR: WebUI process died (Port collision?)"
            return 1
        fi
        if _wd_is_port_open "$port" tcp; then
            log_msg "WebUI bound to port $port (PID: ${web_pid:-unknown})"
            return 0
        fi
        sleep 1
        i=$((i + 1))
    done

    log_msg "ERROR: WebUI failed to bind within 35s"
    return 1
}

# --- Read profile memory hint (v1.1.0, self-contained) ---
#
# Returns a user-facing string describing the expected soft
# memory limit for the active profile.
#
# ⚠️ This is a HINT only. main.go is the authority.
#
# Uses the same table as functions.sh:get_profile_memory_hint
# and main.go:memoryLimitForProfile.
# ============================================================
_wd_get_profile_memory_hint() {
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
# [8] Read credentials — section-restricted
# ============================================================
WATCH_USER=""
WATCH_PASS=""
HAS_CREDS=0

if [ -f "$TOML_FILE" ]; then
    in_section=0
    while IFS= read -r line || [ -n "$line" ]; do
        # Strip CR
        line=$(printf '%s' "$line" | tr -d '\r')
        # Strip whitespace
        trimmed=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip comments and empty lines
        case "$trimmed" in
            ''|\#*) continue ;;
        esac

        # ============================================================
        # Section header with optional trailing comment
        # ============================================================
        # Extract the content between the first [ and ]
        case "$trimmed" in
            \[*)
                section=$(printf '%s' "$trimmed" | sed 's/^\[\([^]]*\)\].*$/\1/')
                section=$(printf '%s' "$section" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                if [ "$section" = "monitoring_ui" ]; then
                    in_section=1
                else
                    in_section=0
                fi
                continue
                ;;
        esac

        [ "$in_section" = "0" ] && continue

        # ============================================================
        # Strict key matching
        # ============================================================
        case "$trimmed" in
            *=*)
                key=$(printf '%s' "$trimmed" | sed 's/^\([^=]*\)=.*/\1/')
                key=$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                val=$(printf '%s' "$trimmed" | sed 's/^[^=]*=//')
                val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                case "$val" in
                    *" #"*) val="${val%% #*}" ;;
                esac
                val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                val=$(printf '%s' "$val" | sed "s/^['\"]//;s/['\"]$//")

                case "$key" in
                    username) WATCH_USER="$val" ;;
                    password) WATCH_PASS="$val" ;;
                esac
                ;;
        esac
    done < "$TOML_FILE"
fi

if [ -n "$WATCH_USER" ] && [ -n "$WATCH_PASS" ]; then
    log_msg "Credentials loaded from [monitoring_ui]"
    HAS_CREDS=1
else
    log_msg "WARNING: no credentials in [monitoring_ui] — API may reject calls"
    HAS_CREDS=0
fi

# ============================================================
# [9] Check base64 availability
# ============================================================
# Check whether base64 is available; fall back to busybox if needed.
# ============================================================
BASE64_CMD=""
if command -v base64 >/dev/null 2>&1; then
    BASE64_CMD="base64"
elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q "^base64$"; then
    BASE64_CMD="busybox base64"
else
    log_msg "WARNING: no base64 available — will skip Basic Auth header"
fi

# ============================================================
# [10] Explicit safe PATH
# ============================================================
SAFE_PATH="/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin"

# ============================================================
# [11] API call helper
# ============================================================
# Uses POST /api/ensure_running_service for CSRF-GET protection.
#
# Return codes:
#   0 — success (2xx)
#   1 — no HTTP client available
#   2 — network/timeout failure
#   3 — 429 rate-limited
#   4 — other HTTP error
# ============================================================
watchdog_api_call() {
    local action="$1"
    local tool=""

    if command -v curl >/dev/null 2>&1; then
        tool="curl"
    elif command -v wget >/dev/null 2>&1; then
        tool="wget"
    elif command -v busybox >/dev/null 2>&1; then
        tool="busybox"
    else
        log_msg "WARNING: no HTTP client available"
        return 1
    fi

    # --- Build Authorization header ---
    local auth_header=""
    if [ "$HAS_CREDS" = "1" ] && [ -n "$BASE64_CMD" ]; then
        local b64
        b64=$(printf "%s:%s" "$WATCH_USER" "$WATCH_PASS" | $BASE64_CMD 2>/dev/null | tr -d '\n')
        if [ -n "$b64" ]; then
            auth_header="Authorization: Basic $b64"
        fi
    fi

    # --- URL ---
    local url="http://127.0.0.1:$PORT/api/${action}_service"

    # --- HTTP status code ---
    local http_code=""
    local exit_code=0

    case "$tool" in
        curl)
            # curl: use -w to obtain the HTTP status code
            local tmp_resp
            tmp_resp=$(mktemp 2>/dev/null || echo /tmp/wd_resp.$$)

            if [ -n "$auth_header" ]; then
                env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    curl -s --noproxy '*' --max-time 5 \
                    -o "$tmp_resp" -w '%{http_code}' \
                    -X POST \
                    -H "$auth_header" "$url" \
                    > /tmp/wd_code.$$ 2>/dev/null
            else
                env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    curl -s --noproxy '*' --max-time 5 \
                    -o "$tmp_resp" -w '%{http_code}' \
                    -X POST \
                    "$url" \
                    > /tmp/wd_code.$$ 2>/dev/null
            fi
            exit_code=$?

            if [ -f /tmp/wd_code.$$ ]; then
                http_code=$(cat /tmp/wd_code.$$ 2>/dev/null | tr -d '\r\n ')
            fi
            rm -f "$tmp_resp" /tmp/wd_code.$$ 2>/dev/null
            ;;

        wget)
            # wget: extract HTTP status from stderr
            local output
            if [ -n "$auth_header" ]; then
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    wget -qO- --no-proxy --timeout=5 --tries=1 \
                    --post-data='' \
                    --header="$auth_header" "$url" \
                    2>&1) || exit_code=$?
            else
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    wget -qO- --no-proxy --timeout=5 --tries=1 \
                    --post-data='' \
                    "$url" \
                    2>&1) || exit_code=$?
            fi
            # Try extracting HTTP status from output
            http_code=$(echo "$output" | grep -oE 'HTTP/[0-9.]+ [0-9]{3}' | head -n1 | grep -oE '[0-9]{3}$' || echo "")
            ;;

        busybox)
            local output
            if [ -n "$auth_header" ]; then
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    busybox wget -qO- --no-proxy --timeout=5 --tries=1 \
                    --post-data='' \
                    --header="$auth_header" "$url" \
                    2>&1) || exit_code=$?
            else
                output=$(env -i PATH="$SAFE_PATH" HOME=/data/local/tmp \
                    http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
                    no_proxy= NO_PROXY= \
                    busybox wget -qO- --no-proxy --timeout=5 --tries=1 \
                    --post-data='' \
                    "$url" \
                    2>&1) || exit_code=$?
            fi
            http_code=$(echo "$output" | grep -oE 'HTTP/[0-9.]+ [0-9]{3}' | head -n1 | grep -oE '[0-9]{3}$' || echo "")
            ;;
    esac

    # --- Analyze the result ---
    if [ "$exit_code" -ne 0 ]; then
        log_msg "WARNING: API call failed (exit=$exit_code) — network/timeout"
        return 2
    fi

    if [ -n "$http_code" ]; then
        case "$http_code" in
            200|201|202|204)
                log_msg "API call succeeded (HTTP $http_code)"
                return 0
                ;;
            429)
                log_msg "API rate-limited (HTTP 429) — backing off"
                return 3
                ;;
            *)
                log_msg "WARNING: API call returned HTTP $http_code"
                return 4
                ;;
        esac
    fi

    # No http_code but exit_code=0
    log_msg "API call succeeded (no HTTP code captured)"
    return 0
}

# ============================================================
# [12] Exponential backoff
# ============================================================
# - DNS_BACKOFF is separate from WEBUI_BACKOFF
# - Reset when STATUS_FILE changes
# - Double the delay on repeated failures
# ============================================================
BACKOFF_BASE=30
BACKOFF_MAX=600

WEBUI_BACKOFF_CURRENT=30
DNS_BACKOFF_CURRENT=30

# --- Previous DNS intent (to detect STATUS_FILE changes) ---
PREV_DESIRED=""

# ============================================================
# [13] Main loop
# ============================================================
log_msg "Entering main loop..."
LOOP_COUNT=0

# v1.1.0 — Log profile + memory hint once at the start of the loop
# (self-contained, does not depend on functions.sh)
{
    _profile_hint=$(_wd_get_profile_memory_hint)
    log_msg "Active profile: $_profile_hint"
} 2>/dev/null

while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))

    # --- [13.0] Compute sleep duration (max of the two) ---
    SLEEP_DURATION=$WEBUI_BACKOFF_CURRENT
    if [ "$DNS_BACKOFF_CURRENT" -gt "$SLEEP_DURATION" ]; then
        SLEEP_DURATION=$DNS_BACKOFF_CURRENT
    fi

    # But never sleep longer than BACKOFF_MAX
    [ "$SLEEP_DURATION" -gt "$BACKOFF_MAX" ] && SLEEP_DURATION="$BACKOFF_MAX"

    sleep "$SLEEP_DURATION"

    # --- [13.1] Check for disable ---
    if [ -f "$MODDIR/disable" ]; then
        log_msg "module disabled -> Watchdog exiting"
        rm -f "$WATCHDOG_PID_FILE" 2>/dev/null
        exit 0
    fi

    # ============================================================
    # [13.2] Restart WebUI
    # ============================================================
    if [ "$AUTO_RESTART_WEBUI" = "1" ]; then
        if ! _wd_is_port_open "$PORT" tcp; then
            log_msg "WebUI down on port $PORT — restarting..."
            _wd_cleanup_webui
            sleep 1

            if _wd_start_webui "$WEBUI" "$PORT"; then
                WEBUI_BACKOFF_CURRENT="$BACKOFF_BASE"
            else
                WEBUI_BACKOFF_CURRENT=$((WEBUI_BACKOFF_CURRENT * 2))
                [ "$WEBUI_BACKOFF_CURRENT" -gt "$BACKOFF_MAX" ] && WEBUI_BACKOFF_CURRENT="$BACKOFF_MAX"
                log_msg "WARNING: WebUI restart failed — next attempt in ${WEBUI_BACKOFF_CURRENT}s"
            fi
        else
            # WebUI is running — reset backoff
            WEBUI_BACKOFF_CURRENT="$BACKOFF_BASE"
        fi
    fi

    # ============================================================
    # [13.3] Restart DNS Engine
    # ============================================================
    #
    # STATUS_FILE represents "user intent":
    #   * ON  = user wants the service running -> Watchdog restarts it
    #   * OFF = user stopped it manually -> Watchdog does nothing
    #
    # DNS_BACKOFF is independent from WEBUI_BACKOFF.
    # Backoff resets when STATUS_FILE changes (user changed intent).
    #
    if [ "$AUTO_RESTART_DNS" = "1" ]; then
        desired="OFF"
        if [ -f "$STATUS_FILE" ]; then
            desired=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
        fi
        [ -z "$desired" ] && desired="OFF"

        # --- Detect intent change -> reset backoff ---
        if [ "$desired" != "$PREV_DESIRED" ]; then
            if [ -n "$PREV_DESIRED" ]; then
                log_msg "STATUS_FILE changed: $PREV_DESIRED -> $desired"
            fi
            PREV_DESIRED="$desired"
            DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
        fi

        if [ "$desired" = "ON" ]; then
            if ! _wd_is_port_open 5354 udp; then
                # Wait a moment + re-check (it may have just started)
                sleep 1
                recheck="OFF"
                if [ -f "$STATUS_FILE" ]; then
                    recheck=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n ')
                fi

                if [ "$recheck" != "ON" ]; then
                    log_msg "status changed to $recheck during check — skipping restart"
                    PREV_DESIRED="$recheck"
                    DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
                else
                    log_msg "DNS Engine down (5354/UDP) — calling ensure_running..."

                    watchdog_api_call "ensure_running"
                    RC=$?

                    case "$RC" in
                        0)
                            log_msg "DNS restart succeeded"
                            DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
                            ;;
                        3)
                            # rate-limited — extra backoff
                            DNS_BACKOFF_CURRENT=$((DNS_BACKOFF_CURRENT * 2))
                            [ "$DNS_BACKOFF_CURRENT" -gt "$BACKOFF_MAX" ] && DNS_BACKOFF_CURRENT="$BACKOFF_MAX"
                            log_msg "WARNING: rate-limited — next attempt in ${DNS_BACKOFF_CURRENT}s"
                            ;;
                        *)
                            DNS_BACKOFF_CURRENT=$((DNS_BACKOFF_CURRENT * 2))
                            [ "$DNS_BACKOFF_CURRENT" -gt "$BACKOFF_MAX" ] && DNS_BACKOFF_CURRENT="$BACKOFF_MAX"
                            log_msg "WARNING: DNS restart failed (rc=$RC) — next attempt in ${DNS_BACKOFF_CURRENT}s"
                            ;;
                    esac
                fi
            else
                # DNS is running — reset backoff
                DNS_BACKOFF_CURRENT="$BACKOFF_BASE"
            fi
        fi
    fi

    # --- [13.4] Periodic log every 20 iterations (~10 minutes) ---
    if [ $((LOOP_COUNT % 20)) -eq 0 ]; then
        log_msg "Watchdog alive (loop #$LOOP_COUNT, webui_backoff=${WEBUI_BACKOFF_CURRENT}s, dns_backoff=${DNS_BACKOFF_CURRENT}s)"
    fi
done

# Unreachable (infinite loop)
exit 0