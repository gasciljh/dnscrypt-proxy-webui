#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — lib/http.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Unified HTTP client: curl → wget → busybox wget cascade
# behind one interface. Used by service.sh, watchdog.sh.
#
# Public interface:
#   http_request METHOD URL [BODY] [HDR1] [HDR2] [HDR3]
#     Sets globals: HTTP_BODY, HTTP_CODE, HTTP_ERROR
#     Returns: 0=2xx, 1=no client, 2=network,
#              3=429, 4=HTTP error, 5=bad args
#   http_get / http_post
#   get_watchdog_token_safe
#   build_basic_auth_header
#   ping_reachable HOST [SEC]
#
# Environment overrides (per call):
#   HTTP_TIMEOUT       — seconds (default 10)
#   HTTP_CAPTURE_BODY  — "1" to populate HTTP_BODY
# ============================================================

if [ -n "${_LIB_HTTP_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_LIB_HTTP_LOADED=1

# ============================================================
# [1] Fixed environment
# ============================================================
HTTP_SAFE_PATH="/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin"
HTTP_SAFE_HOME="/data/local/tmp"
HTTP_TIMEOUT_DEFAULT=10

# ============================================================
# [2] Tool detection (once, at source time)
# ============================================================
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout"
elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q '^timeout$'; then
    TIMEOUT_CMD="busybox timeout"
fi

BASE64_CMD=""
if command -v base64 >/dev/null 2>&1; then
    BASE64_CMD="base64"
elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q '^base64$'; then
    BASE64_CMD="busybox base64"
fi

# ============================================================
# [3] Public state
# ============================================================
HTTP_BODY=""
HTTP_CODE=""
HTTP_ERROR=""

# ============================================================
# [4] Client detection
# ============================================================
http_available_client() {
    if command -v curl >/dev/null 2>&1; then
        printf 'curl'
        return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        printf 'wget'
        return 0
    fi
    if command -v busybox >/dev/null 2>&1 \
       && busybox --list 2>/dev/null | grep -q '^wget$'; then
        printf 'busybox-wget'
        return 0
    fi
    return 1
}

http_list_clients() {
    local list=""
    if command -v curl >/dev/null 2>&1; then
        list="$list curl"
    fi
    if command -v wget >/dev/null 2>&1; then
        list="$list wget"
    fi
    if command -v busybox >/dev/null 2>&1 \
       && busybox --list 2>/dev/null | grep -q '^wget$'; then
        list="$list busybox-wget"
    fi
    printf '%s' "${list# }"
}

# ============================================================
# [5] Environment isolation
# ============================================================
_http_env() {
    env -i PATH="$HTTP_SAFE_PATH" HOME="$HTTP_SAFE_HOME" \
           TMPDIR="$HTTP_SAFE_HOME" \
           http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= \
           no_proxy= NO_PROXY= \
           "$@"
}

# ============================================================
# [6] curl runner
# ============================================================
_http_run_curl() {
    local method="$1" url="$2" body="$3" timeout="$4"
    local h1="$5" h2="$6" h3="$7"
    local body_file="$8" code_file="$9"

    set -- -s --noproxy '*' --max-time "$timeout" -o "$body_file" -w '%{http_code}'
    [ "$method" = "POST" ] && set -- "$@" -X POST -d "$body"
    [ -n "$h1" ] && set -- "$@" -H "$h1"
    [ -n "$h2" ] && set -- "$@" -H "$h2"
    [ -n "$h3" ] && set -- "$@" -H "$h3"
    set -- "$@" "$url"

    _http_env curl "$@" > "$code_file" 2>/dev/null
    return $?
}

# ============================================================
# [7] wget runner (plain + busybox)
# ============================================================
# Note: -S (server-response) is honoured by GNU wget even with -q,
# but busybox wget suppresses -S output under -q. The caller
# (http_request) compensates by mapping exit code 0 → "200" when
# http_code could not be parsed. See [9] below.
_http_run_wget() {
    local method="$1" url="$2" body="$3" timeout="$4"
    local h1="$5" h2="$6" h3="$7"
    local body_file="$8" hdr_file="$9"
    local client="${10:-wget}"

    set -- -S -q -O "$body_file" -T "$timeout"
    [ "$method" = "POST" ] && set -- "$@" --post-data="$body"
    [ -n "$h1" ] && set -- "$@" --header="$h1"
    [ -n "$h2" ] && set -- "$@" --header="$h2"
    [ -n "$h3" ] && set -- "$@" --header="$h3"
    set -- "$@" "$url"

    case "$client" in
        busybox-wget) _http_env busybox wget "$@" 2>"$hdr_file" ;;
        *)            _http_env wget         "$@" 2>"$hdr_file" ;;
    esac
    return $?
}

# ============================================================
# [8] HTTP code extraction from wget header dump
# ============================================================
_http_parse_wget_code() {
    local hdr_file="$1"
    local code

    [ -f "$hdr_file" ] || { printf ''; return 0; }
    code=$(grep -oE 'HTTP/[0-9.]+[[:space:]]+[0-9]{3}' "$hdr_file" 2>/dev/null \
        | tail -n1 \
        | grep -oE '[0-9]{3}$')
    printf '%s' "$code"
}

# ============================================================
# [9] Unified request
# ============================================================
http_request() {
    local method="$1" url="$2" body="${3:-}"
    local h1="${4:-}" h2="${5:-}" h3="${6:-}"

    HTTP_BODY=""
    HTTP_CODE=""
    HTTP_ERROR=""

    case "$method" in
        GET|POST) ;;
        *) HTTP_ERROR="invalid method: $method"; return 5 ;;
    esac
    [ -z "$url" ] && { HTTP_ERROR="empty url"; return 5; }

    local clients
    clients=$(http_list_clients)
    if [ -z "$clients" ]; then
        HTTP_ERROR="no HTTP client"
        return 1
    fi

    local timeout="${HTTP_TIMEOUT:-$HTTP_TIMEOUT_DEFAULT}"
    case "$timeout" in ''|*[!0-9]*) timeout="$HTTP_TIMEOUT_DEFAULT" ;; esac

    local run_dir="${RUN_DIR_ACTIVE:-${RUN_DIR:-$HTTP_SAFE_HOME}}"
    [ -d "$run_dir" ] && [ -w "$run_dir" ] || run_dir="$HTTP_SAFE_HOME"

    local tmp_body="${run_dir}/.http_body.$$"
    local tmp_code="${run_dir}/.http_code.$$"
    local tmp_hdr="${run_dir}/.http_hdr.$$"

    local last_error="all clients failed"
    local last_rc=2
    local client

    for client in $clients; do
        rm -f "$tmp_body" "$tmp_code" "$tmp_hdr" 2>/dev/null

        local rc=0 http_code=""

        case "$client" in
            curl)
                _http_run_curl "$method" "$url" "$body" "$timeout" \
                               "$h1" "$h2" "$h3" "$tmp_body" "$tmp_code"
                rc=$?
                [ -f "$tmp_code" ] && http_code=$(tr -d '\r\n ' < "$tmp_code" 2>/dev/null)
                ;;
            wget|busybox-wget)
                _http_run_wget "$method" "$url" "$body" "$timeout" \
                               "$h1" "$h2" "$h3" "$tmp_body" "$tmp_hdr" "$client"
                rc=$?
                [ -f "$tmp_hdr" ] && http_code=$(_http_parse_wget_code "$tmp_hdr")

                # Fallback: busybox wget does not emit -S output under -q.
                # A zero exit code means the transfer succeeded (HTTP 2xx),
                # because busybox wget returns non-zero on any HTTP error.
                if [ -z "$http_code" ] && [ "$rc" -eq 0 ]; then
                    http_code="200"
                fi
                ;;
        esac

        if [ -f "$tmp_body" ] && [ "${HTTP_CAPTURE_BODY:-0}" = "1" ]; then
            HTTP_BODY=$(cat "$tmp_body" 2>/dev/null)
        fi

        if [ -n "$http_code" ]; then
            case "$http_code" in
                2[0-9][0-9])
                    HTTP_CODE="$http_code"
                    rm -f "$tmp_body" "$tmp_code" "$tmp_hdr" 2>/dev/null
                    return 0
                    ;;
                429)
                    HTTP_CODE="$http_code"
                    HTTP_ERROR="rate limited (HTTP 429)"
                    rm -f "$tmp_body" "$tmp_code" "$tmp_hdr" 2>/dev/null
                    return 3
                    ;;
                *)
                    HTTP_CODE="$http_code"
                    HTTP_ERROR="HTTP $http_code"
                    rm -f "$tmp_body" "$tmp_code" "$tmp_hdr" 2>/dev/null
                    return 4
                    ;;
            esac
        fi

        if [ "$rc" -eq 8 ]; then
            last_error="unparseable response (via $client)"
        elif [ "$rc" -eq 0 ]; then
            last_error="no HTTP status (via $client)"
        else
            last_error="network error rc=$rc (via $client)"
        fi
        last_rc=2

        rm -f "$tmp_body" "$tmp_code" "$tmp_hdr" 2>/dev/null
    done

    HTTP_ERROR="$last_error"
    return $last_rc
}

# ============================================================
# [10] Convenience wrappers
# ============================================================
http_get()  { http_request GET  "$@"; }
http_post() { http_request POST "$@"; }

# ============================================================
# [11] Watchdog token reader
# ============================================================
get_watchdog_token_safe() {
    local token_file="${WATCHDOG_TOKEN_FILE:-}"

    if [ -z "$token_file" ]; then
        token_file="${RUN_DIR_ACTIVE:-${RUN_DIR:-/data/local/tmp}}/.watchdog_token"
        if [ ! -f "$token_file" ]; then
            token_file="/data/local/tmp/.watchdog_token"
        fi
    fi

    [ -f "$token_file" ] || return 1
    [ -L "$token_file" ] && return 1

    local tok
    tok=$(cat "$token_file" 2>/dev/null | tr -d '\r\n ')
    [ -n "$tok" ] || return 1
    [ "${#tok}" -ge 32 ] || return 1
    printf '%s' "$tok"
    return 0
}

# ============================================================
# [12] Basic Auth header builder
# ============================================================
build_basic_auth_header() {
    local user="$1" pass="$2" b64

    [ -n "$user" ] && [ -n "$pass" ] || return 1
    [ -n "$BASE64_CMD" ] || return 1

    # shellcheck disable=SC2086
    b64=$(printf '%s:%s' "$user" "$pass" | $BASE64_CMD 2>/dev/null | tr -d '\n')
    [ -n "$b64" ] || return 1

    printf 'Authorization: Basic %s' "$b64"
}

# ============================================================
# [13] Bounded ping
# ============================================================
ping_reachable() {
    local host="$1"
    local timeout_s="${2:-2}"
    local client="ping"

    case "$host" in
        *:*) command -v ping6 >/dev/null 2>&1 && client="ping6" ;;
    esac

    command -v "$client" >/dev/null 2>&1 || return 1

    if [ -n "$TIMEOUT_CMD" ]; then
        # shellcheck disable=SC2086
        $TIMEOUT_CMD "$timeout_s" "$client" -c 1 "$host" >/dev/null 2>&1
        return $?
    fi

    if "$client" -c 1 -W "$timeout_s" "$host" >/dev/null 2>&1; then
        return 0
    fi
    "$client" -c 1 "$host" >/dev/null 2>&1
}