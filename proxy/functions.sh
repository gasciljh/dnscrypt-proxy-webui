#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – functions.sh
# Version: v1.1.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Shared shell library sourced by other scripts (service.sh,
#   action.sh, status.sh, uninstall.sh, watchdog.sh, main.go).
#
# Responsibilities:
#   • run/ directory management (init + fallback to /data/local/tmp)
#   • Bootstrap IP cache (5-minute TTL from TOML)
#   • Logging helper (with emergency-only rotation at 50 MB)
#   • Progress file writer (atomic)
#   • Config file reader (webui.conf)
#   • Port readers with Port Guard (rejects 8080)
#   • Section-restricted TOML credentials reader
#   • Port check (TCP/UDP, IPv4/IPv6)
#   • Service state check (DNS engine + WebUI)
#   • IPv6 availability detection
#   • Firewall backend detection (nftables / iptables / none)
#   • Legacy cleanup for older versions
#   • iptables / ip6tables management with Custom Chains
#     (DNSCRYPT_OUT / DNSCRYPT_OUT6) — no orphan rules
#   • nftables management (inet table)
#   • Unified manage_firewall interface
#   • Process cleanup (proxy, webui, orphans)
#   • Aggressive cleanup (used on uninstall)
#   • WebUI launcher with retry
#   • Domain normalization + matching helpers
#   • Custom rules loading (Allowlist + Denylist)
#   • Secure random password/username generation
#
# Port Guard:
#   Port 8080 is reserved for monitoring_ui (dnscrypt-proxy.toml).
#   get_webui_port / get_dashboard_port reject it and fall back
#   to 9090 / 9091 respectively.
#
# Custom Chains:
#   All dynamic firewall rules live inside dedicated chains:
#     • DNSCRYPT_OUT   (IPv4)
#     • DNSCRYPT_OUT6  (IPv6)
#   Cleanup = -F + -X → complete wipe in one operation.
#   No orphans when bootstrap_resolvers change.
#
# Section-restricted TOML:
#   read_toml_credentials reads ONLY from [monitoring_ui].
#   Section tracking ignores any username/password in other
#   sections.
#
# v1.1.0 coordination with main.go:
#   • The constant `_MONITORING_UI_PORT` below MUST stay in sync
#     with `MONITORING_UI_PORT` in main.go. Any change to one
#     requires changing the other.
#   • Memory limits (light/normal/pro/proplus/ultimate) are
#     managed by main.go only. This file provides a read-only
#     helper `get_profile_memory_hint` for user-facing display.
#   • Port collision resolution is handled by customize.sh at
#     install time; this file only enforces the 8080 rejection.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Determine module path
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

# ============================================================
# [2] Shared constant with main.go
# ============================================================
# ⚠️ CRITICAL: This constant must stay in sync with MONITORING_UI_PORT
# in main.go. Any change here must also be applied there.
#
# The reserved port is used by dnscrypt-proxy's internal monitoring_ui.
# Changing it requires coordinated updates in:
#   • main.go          → MONITORING_UI_PORT
#   • functions.sh     → _MONITORING_UI_PORT (this file)
#   • customize.sh     → _MONITORING_UI_PORT
#   • action.sh        → _MONITORING_UI_PORT
#   • service.sh       → _MONITORING_UI_PORT
#   • status.sh        → _MONITORING_UI_PORT
#   • watchdog.sh      → (uses TOML directly)
#   • dnscrypt-proxy.toml → listen_address
# ============================================================
_MONITORING_UI_PORT="8080"

# ============================================================
# [3] run/ directory management
# ============================================================
RUN_DIR="$MODDIR/proxy/run"

ensure_run_dir() {
    if [ -d "$RUN_DIR" ] && [ -w "$RUN_DIR" ]; then
        return 0
    fi
    if mkdir -p "$RUN_DIR" 2>/dev/null; then
        chmod 0700 "$RUN_DIR" 2>/dev/null
        chown 0:0 "$RUN_DIR" 2>/dev/null
        if [ -w "$RUN_DIR" ]; then
            return 0
        fi
    fi
    return 1
}

get_run_dir() {
    if ensure_run_dir; then
        printf "%s" "$RUN_DIR"
    else
        printf "%s" "/data/local/tmp"
    fi
}

run_file() {
    local filename="$1"
    local run_dir
    run_dir=$(get_run_dir)
    printf "%s/%s" "$run_dir" "$filename"
}

init_runtime_paths() {
    local rd
    rd=$(get_run_dir)

    LOG_FILE="/data/local/tmp/dnscrypt_main.log"
    PROGRESS_FILE="/data/local/tmp/update_progress.txt"
    STATUS_FILE="$rd/dnscrypt.status"
    PID_FILE="$rd/dnscrypt.pid"
    WEBUI_PID_FILE="$rd/webui.pid"
    WATCHDOG_PID_FILE="$rd/watchdog.pid"

    export LOG_FILE PROGRESS_FILE STATUS_FILE PID_FILE WEBUI_PID_FILE WATCHDOG_PID_FILE
    export RUN_DIR_ACTIVE="$rd"
}

init_runtime_paths

# --- Fixed paths ---
TOML_FILE="$MODDIR/proxy/dnscrypt-proxy.toml"
WEBUI_CONF="$MODDIR/proxy/webui.conf"
SELECTED_PROFILE_FILE="$MODDIR/proxy/selected_profile.txt"

# --- Firewall cache variables ---
_FW_CACHE=""
_FW_CACHE_TIME=0

# ============================================================
# [4] Read bootstrap_resolvers from TOML
# ============================================================
get_dynamic_bootstrap() {
    if [ ! -f "$TOML_FILE" ]; then
        return 0
    fi

    awk '
        /^[[:space:]]*bootstrap_resolvers[[:space:]]*=/ { in_array=1 }
        in_array { printf "%s\n", $0 }
        in_array && /\][[:space:]]*(#|$)/ { exit }
    ' "$TOML_FILE" 2>/dev/null \
    | tr -d "',\"\r" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}|[0-9a-fA-F]{0,4}(:[0-9a-fA-F]{0,4}){2,7}' \
    | sort -u \
    | tr '\n' ' '
}

# ============================================================
# [5] Load BOOTSTRAP_IPS (with cache)
# ============================================================
_BOOTSTRAP_CACHE_FILE="$MODDIR/proxy/run/.bootstrap_cache"
_BOOTSTRAP_CACHE_TTL=300  # 5 minutes

_load_bootstrap_from_cache() {
    if [ ! -f "$_BOOTSTRAP_CACHE_FILE" ]; then
        return 1
    fi

    local cache_mtime now age
    cache_mtime=$(stat -c %Y "$_BOOTSTRAP_CACHE_FILE" 2>/dev/null) \
        || cache_mtime=$(stat -f %m "$_BOOTSTRAP_CACHE_FILE" 2>/dev/null) \
        || return 1

    now=$(date +%s)
    age=$((now - cache_mtime))

    if [ "$age" -lt 0 ] || [ "$age" -gt "$_BOOTSTRAP_CACHE_TTL" ]; then
        return 1
    fi

    local cached
    cached=$(cat "$_BOOTSTRAP_CACHE_FILE" 2>/dev/null)
    if [ -z "$cached" ]; then
        return 1
    fi

    printf "%s" "$cached"
    return 0
}

_save_bootstrap_to_cache() {
    local value="$1"
    mkdir -p "$MODDIR/proxy/run" 2>/dev/null
    printf "%s" "$value" > "$_BOOTSTRAP_CACHE_FILE" 2>/dev/null || true
}

# --- Try loading from cache first ---
_CACHED_BOOTSTRAP=$(_load_bootstrap_from_cache 2>/dev/null)

if [ -n "$_CACHED_BOOTSTRAP" ]; then
    BOOTSTRAP_IPS="$_CACHED_BOOTSTRAP"
else
    BOOTSTRAP_IPS_RAW=$(get_dynamic_bootstrap)

    if [ -z "$BOOTSTRAP_IPS_RAW" ] || [ -z "${BOOTSTRAP_IPS_RAW// /}" ]; then
        BOOTSTRAP_IPS="9.9.9.9 8.8.8.8 1.1.1.1 1.0.0.1"
    else
        BOOTSTRAP_IPS="$BOOTSTRAP_IPS_RAW"
    fi

    _save_bootstrap_to_cache "$BOOTSTRAP_IPS"
fi

# --- Loopback always included ---
LOOPBACK_IPS="127.0.0.1"

# ============================================================
# [6] Logging — Emergency-Only Rotation
# ============================================================
log_fn() {
    _LOG_CALL_COUNT=$((_LOG_CALL_COUNT + 1))

    if [ $((_LOG_CALL_COUNT % 100)) -eq 0 ] && [ -f "$LOG_FILE" ]; then
        local _size
        _size=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
        if [ -n "$_size" ] && [ "$_size" -gt 52428800 ]; then
            local emg="${LOG_FILE}.emergency.$(date +%s)"
            mv -f "$LOG_FILE" "$emg" 2>/dev/null
            : > "$LOG_FILE"
        fi
    fi

    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE" 2>/dev/null
}

# ============================================================
# [7] Write progress file
# ============================================================
write_progress() {
    local percent="$1"
    local msg="$2"

    case "$percent" in
        ''|*[!0-9]*) percent=0 ;;
    esac
    [ "$percent" -gt 100 ] && percent=100
    [ "$percent" -lt 0 ] && percent=0

    if [ ${#msg} -gt 200 ]; then
        msg=$(printf "%s" "$msg" | cut -c1-200)
    fi

    printf "%d|%s" "$percent" "$msg" > "${PROGRESS_FILE}.tmp" 2>/dev/null
    mv -f "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE" 2>/dev/null
}

# ============================================================
# [8] Read value from config file
# ============================================================
get_conf_value() {
    local conf="$1"
    local key="$2"
    local default="${3:-}"

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
    return 1
}

# ============================================================
# [9] Read WebUI/Dashboard ports — Port Guard
# ============================================================
#
# Port Guard: reject the reserved monitoring_ui port (8080).
#
# v1.1.0 note:
#   This function does NOT handle PORT/DASHBOARD_PORT equality.
#   That collision is resolved at install time by customize.sh
#   ([14b]). At runtime, main.go refuses to start if the two
#   ports are equal — the shell layer cannot intervene.
# ============================================================
get_webui_port() {
    local conf_file="${1:-$WEBUI_CONF}"
    local port
    port=$(get_conf_value "$conf_file" "PORT" "9090" 2>/dev/null)

    if echo "$port" | grep -qE '^[0-9]+$' && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        if [ "$port" = "$_MONITORING_UI_PORT" ]; then
            log_fn "⚠️ PORT=$port conflicts with monitoring_ui — falling back to 9090"
            printf "9090"
            return 0
        fi
        printf "%s" "$port"
        return 0
    fi
    printf "9090"
    return 1
}

get_dashboard_port() {
    local conf_file="${1:-$WEBUI_CONF}"
    local port
    port=$(get_conf_value "$conf_file" "DASHBOARD_PORT" "9091" 2>/dev/null)

    if echo "$port" | grep -qE '^[0-9]+$' && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        if [ "$port" = "$_MONITORING_UI_PORT" ]; then
            log_fn "⚠️ DASHBOARD_PORT=$port conflicts with monitoring_ui — falling back to 9091"
            printf "9091"
            return 0
        fi
        printf "%s" "$port"
        return 0
    fi
    printf "9091"
    return 1
}

# ============================================================
# [9b] v1.1.0 — profile memory hint (read-only)
# ============================================================
#
# Returns a user-facing string describing the expected soft
# memory limit for the active profile.
#
# ⚠️ This is a HINT only. main.go is the authority for the
#    actual debug.SetMemoryLimit() value.
#
# Usage:
#   get_profile_memory_hint
#     → "120 MB (pro)"
#     → "80 MB (light)"
# ============================================================
get_profile_memory_hint() {
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
# [10] Read AUTO_RESTART_* options
# ============================================================
get_auto_restart_dns() {
    local conf="${1:-$WEBUI_CONF}"
    local val
    val=$(get_conf_value "$conf" "AUTO_RESTART_DNS" "1")
    case "$val" in
        0|1) printf "%s" "$val" ;;
        *)   printf "1" ;;
    esac
}

get_auto_restart_webui() {
    local conf="${1:-$WEBUI_CONF}"
    local val
    val=$(get_conf_value "$conf" "AUTO_RESTART_WEBUI" "1")
    case "$val" in
        0|1) printf "%s" "$val" ;;
        *)   printf "1" ;;
    esac
}

# ============================================================
# [11] Read TOML credentials — Section-Restricted
# ============================================================
read_toml_credentials() {
    local user="" pass=""

    if [ ! -f "$TOML_FILE" ]; then
        printf "%s\n%s" "$user" "$pass"
        return 0
    fi

    local in_section=0
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(printf '%s' "$line" | tr -d '\r')
        local trimmed
        trimmed=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        case "$trimmed" in
            ''|\#*) continue ;;
        esac

        # Section header with trailing comment support
        case "$trimmed" in
            \[*)
                local section
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

        case "$trimmed" in
            *=*)
                local key val
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
                    username) user="$val" ;;
                    password) pass="$val" ;;
                esac
                ;;
        esac
    done < "$TOML_FILE"

    printf "%s\n%s" "$user" "$pass"
}

# ============================================================
# [12] Port check (TCP / UDP)
# ============================================================
is_port_open() {
    local port="$1"
    local proto="${2:-tcp}"

    case "$port" in
        ''|*[!0-9]*) return 1 ;;
    esac

    local hex_port
    hex_port=$(printf "%04X" "$port")

    if [ "$proto" = "udp" ]; then
        if [ -f /proc/net/udp ]; then
            grep -qi ":$hex_port " /proc/net/udp 2>/dev/null && return 0
        fi
        if [ -f /proc/net/udp6 ]; then
            grep -qi ":$hex_port " /proc/net/udp6 2>/dev/null && return 0
        fi

        if command -v ss >/dev/null 2>&1; then
            ss -lun 2>/dev/null | grep -q ":$port " && return 0
        fi

        if command -v netstat >/dev/null 2>&1; then
            netstat -uln 2>/dev/null | grep -q ":$port " && return 0
        fi
    else
        if [ -f /proc/net/tcp ]; then
            grep -qi ":$hex_port " /proc/net/tcp 2>/dev/null && return 0
        fi
        if [ -f /proc/net/tcp6 ]; then
            grep -qi ":$hex_port " /proc/net/tcp6 2>/dev/null && return 0
        fi

        if command -v ss >/dev/null 2>&1; then
            ss -ltn 2>/dev/null | grep -q ":$port " && return 0
        fi

        if command -v netstat >/dev/null 2>&1; then
            netstat -tln 2>/dev/null | grep -q ":$port " && return 0
        fi
    fi

    return 1
}

# ============================================================
# [13] Unified module service checks
# ============================================================
is_dnscrypt_running() {
    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        if is_port_open 5354 udp; then
            return 0
        fi
    fi
    return 1
}

is_webui_running() {
    local port="${1:-$(get_webui_port)}"
    is_port_open "$port" tcp
}

# ============================================================
# [14] Check IPv6 availability
# ============================================================
is_ipv6_available() {
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
# [15] Detect firewall (cache 60 seconds)
# ============================================================
detect_firewall() {
    local now
    now=$(date +%s 2>/dev/null || echo "0")
    if [ -n "$_FW_CACHE" ] && [ "$((now - _FW_CACHE_TIME))" -lt 60 ]; then
        printf "%s" "$_FW_CACHE"
        return 0
    fi

    if command -v nft >/dev/null 2>&1; then
        if nft add table inet dnscrypt_probe_test 2>/dev/null; then
            nft delete table inet dnscrypt_probe_test 2>/dev/null
            _FW_CACHE="nftables"
            _FW_CACHE_TIME="$now"
            printf "%s" "$_FW_CACHE"
            return 0
        fi

        if nft add table ip dnscrypt_probe_test 2>/dev/null; then
            nft delete table ip dnscrypt_probe_test 2>/dev/null
            _FW_CACHE="nftables"
            _FW_CACHE_TIME="$now"
            printf "%s" "$_FW_CACHE"
            return 0
        fi
    fi

    if command -v iptables >/dev/null 2>&1; then
        if iptables -t nat -L -n >/dev/null 2>&1; then
            _FW_CACHE="iptables"
            _FW_CACHE_TIME="$now"
            printf "%s" "$_FW_CACHE"
            return 0
        fi
    fi

    _FW_CACHE="none"
    _FW_CACHE_TIME="$now"
    printf "none"
    return 1
}

# ============================================================
# [16] Legacy Cleanup (migration from older versions)
# ============================================================
_LEGACY_CLEANUP_DONE=0

_legacy_cleanup_iptables() {
    [ "$_LEGACY_CLEANUP_DONE" = "1" ] && return 0
    _LEGACY_CLEANUP_DONE=1

    command -v iptables >/dev/null 2>&1 || return 0

    # --- Old DNAT (with comment) ---
    iptables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination 127.0.0.1:5354 \
        -m comment --comment "dnscrypt_smart_filter" 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination 127.0.0.1:5354 \
        -m comment --comment "dnscrypt_smart_filter" 2>/dev/null

    # --- Old DNAT (without comment) ---
    iptables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination 127.0.0.1:5354 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination 127.0.0.1:5354 2>/dev/null

    # --- Old RETURN rules ---
    local _ip
    for _ip in 127.0.0.1 $BOOTSTRAP_IPS; do
        case "$_ip" in *:*) continue ;; esac
        iptables -t nat -D OUTPUT -d "$_ip" -p udp --dport 53 \
            -j RETURN -m comment --comment "dnscrypt_smart_filter_loopback_${_ip}" 2>/dev/null
        iptables -t nat -D OUTPUT -d "$_ip" -p tcp --dport 53 \
            -j RETURN -m comment --comment "dnscrypt_smart_filter_loopback_${_ip}" 2>/dev/null
        iptables -t nat -D OUTPUT -d "$_ip" -p udp --dport 53 \
            -j RETURN 2>/dev/null
        iptables -t nat -D OUTPUT -d "$_ip" -p tcp --dport 53 \
            -j RETURN 2>/dev/null
    done

    return 0
}

_legacy_cleanup_ip6tables() {
    command -v ip6tables >/dev/null 2>&1 || return 0

    ip6tables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination "[::1]:5354" \
        -m comment --comment "dnscrypt_smart_filter" 2>/dev/null
    ip6tables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination "[::1]:5354" \
        -m comment --comment "dnscrypt_smart_filter" 2>/dev/null

    ip6tables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination "[::1]:5354" 2>/dev/null
    ip6tables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination "[::1]:5354" 2>/dev/null

    local _ip
    for _ip in ::1 $BOOTSTRAP_IPS; do
        case "$_ip" in
            *:*) ;;
            *) continue ;;
        esac
        ip6tables -t nat -D OUTPUT -d "$_ip" -p udp --dport 53 \
            -j RETURN -m comment --comment "dnscrypt_smart_filter_loopback_${_ip}" 2>/dev/null
        ip6tables -t nat -D OUTPUT -d "$_ip" -p tcp --dport 53 \
            -j RETURN -m comment --comment "dnscrypt_smart_filter_loopback_${_ip}" 2>/dev/null
        ip6tables -t nat -D OUTPUT -d "$_ip" -p udp --dport 53 \
            -j RETURN 2>/dev/null
        ip6tables -t nat -D OUTPUT -d "$_ip" -p tcp --dport 53 \
            -j RETURN 2>/dev/null
    done

    return 0
}

# ============================================================
# [17] Hybrid iptables (IPv4)
# ============================================================
# Strategy:
#   1. Full cleanup (Custom Chain + Legacy + Direct)
#   2. Try Custom Chain first (clean, no orphans)
#   3. If it fails → fallback to Direct DNAT
#
# Why Hybrid:
#   Some devices (OnePlus, some Samsung) have OEM chains
#   (such as onelink_nat_chain) that prevent Custom Chain
#   creation. In that case, Direct DNAT works reliably.
# ============================================================
manage_iptables() {
    local mode="$1"
    local chain="DNSCRYPT_OUT"
    local comment="dnscrypt_smart_filter"
    local dest_v4="127.0.0.1:5354"

    command -v iptables >/dev/null 2>&1 || return 1

    # --- Legacy cleanup (once) ---
    _legacy_cleanup_iptables

    # --- [A] Full cleanup (all methods) ---
    # Custom Chain
    iptables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 5 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 5 2>/dev/null
    iptables -t nat -F "$chain" --wait 5 2>/dev/null
    iptables -t nat -X "$chain" --wait 5 2>/dev/null

    # Direct DNAT (with comment)
    iptables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination "$dest_v4" \
        -m comment --comment "$comment" --wait 5 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination "$dest_v4" \
        -m comment --comment "$comment" --wait 5 2>/dev/null

    # Direct DNAT (without comment)
    iptables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination "$dest_v4" --wait 5 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination "$dest_v4" --wait 5 2>/dev/null

    if [ "$mode" != "1" ]; then
        log_fn "✅ iptables: cleaned (all methods)"
        return 0
    fi

    # --- [B] Try Custom Chain first ---
    local use_chain=0

    if iptables -t nat -N "$chain" --wait 5 2>/dev/null; then
        # Add jump rules
        if iptables -t nat -I OUTPUT -p udp --dport 53 -j "$chain" --wait 5 2>/dev/null && \
           iptables -t nat -I OUTPUT -p tcp --dport 53 -j "$chain" --wait 5 2>/dev/null; then

            # Add RETURN rules
            local _added_return=0
            local _ip
            for _ip in $LOOPBACK_IPS $BOOTSTRAP_IPS; do
                case "$_ip" in *:*) continue ;; esac
                if iptables -t nat -A "$chain" -d "$_ip" -j RETURN --wait 5 2>/dev/null; then
                    _added_return=$((_added_return + 1))
                fi
            done

            # Add DNAT catch-all
            if [ "$_added_return" -gt 0 ]; then
                if iptables -t nat -A "$chain" -j DNAT --to-destination "$dest_v4" --wait 5 2>/dev/null; then
                    use_chain=1
                    log_fn "✅ iptables: custom chain $chain created ($_added_return RETURN, 1 DNAT)"
                fi
            fi
        fi
    fi

    # --- [C] If Custom Chain failed → Fallback to Direct DNAT ---
    if [ "$use_chain" = "0" ]; then
        # Clean up any failed Custom Chain remnants
        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 5 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 5 2>/dev/null
        iptables -t nat -F "$chain" --wait 5 2>/dev/null
        iptables -t nat -X "$chain" --wait 5 2>/dev/null

        log_fn "ℹ️ iptables: custom chain failed, using direct DNAT"

        # Direct DNAT (fallback)
        if ! iptables -t nat -I OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "$dest_v4" \
                -m comment --comment "$comment" --wait 5 2>/dev/null; then
            log_fn "❌ iptables: failed to add UDP DNAT"
            return 1
        fi

        if ! iptables -t nat -I OUTPUT -p tcp --dport 53 \
                -j DNAT --to-destination "$dest_v4" \
                -m comment --comment "$comment" --wait 5 2>/dev/null; then
            log_fn "❌ iptables: failed to add TCP DNAT, rolling back UDP"
            iptables -t nat -D OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "$dest_v4" \
                -m comment --comment "$comment" --wait 5 2>/dev/null
            return 1
        fi

        log_fn "✅ iptables: direct DNAT applied (fallback mode)"
    fi

    return 0
}

# ============================================================
# [18] Hybrid ip6tables (IPv6)
# ============================================================
manage_ip6tables() {
    local mode="$1"
    local chain="DNSCRYPT_OUT6"
    local comment="dnscrypt_smart_filter"
    local dest_v6="[::1]:5354"

    if ! is_ipv6_available; then
        [ "$mode" = "1" ] && log_fn "ℹ️ IPv6 not available, skipping ip6tables"
        return 0
    fi

    command -v ip6tables >/dev/null 2>&1 || return 0

    if ! ip6tables -t nat -L -n >/dev/null 2>&1; then
        log_fn "ℹ️ ip6tables -t nat not supported, skipping IPv6"
        return 0
    fi

    _legacy_cleanup_ip6tables

    # --- [A] Full cleanup ---
    ip6tables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 5 2>/dev/null
    ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 5 2>/dev/null
    ip6tables -t nat -F "$chain" --wait 5 2>/dev/null
    ip6tables -t nat -X "$chain" --wait 5 2>/dev/null

    ip6tables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination "$dest_v6" \
        -m comment --comment "$comment" --wait 5 2>/dev/null
    ip6tables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination "$dest_v6" \
        -m comment --comment "$comment" --wait 5 2>/dev/null

    ip6tables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination "$dest_v6" --wait 5 2>/dev/null
    ip6tables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination "$dest_v6" --wait 5 2>/dev/null

    if [ "$mode" != "1" ]; then
        log_fn "✅ ip6tables: cleaned"
        return 0
    fi

    # --- [B] Try Custom Chain ---
    local use_chain=0

    if ip6tables -t nat -N "$chain" --wait 5 2>/dev/null; then
        if ip6tables -t nat -I OUTPUT -p udp --dport 53 -j "$chain" --wait 5 2>/dev/null && \
           ip6tables -t nat -I OUTPUT -p tcp --dport 53 -j "$chain" --wait 5 2>/dev/null; then

            local _added_return=0
            local _ip
            for _ip in ::1 $BOOTSTRAP_IPS; do
                case "$_ip" in
                    *:*) ;;
                    *) continue ;;
                esac
                if ip6tables -t nat -A "$chain" -d "$_ip" -j RETURN --wait 5 2>/dev/null; then
                    _added_return=$((_added_return + 1))
                fi
            done

            if [ "$_added_return" -gt 0 ]; then
                if ip6tables -t nat -A "$chain" -j DNAT --to-destination "$dest_v6" --wait 5 2>/dev/null; then
                    use_chain=1
                    log_fn "✅ ip6tables: custom chain $chain created ($_added_return RETURN, 1 DNAT)"
                fi
            fi
        fi
    fi

    # --- [C] Fallback to Direct DNAT ---
    if [ "$use_chain" = "0" ]; then
        ip6tables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 5 2>/dev/null
        ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 5 2>/dev/null
        ip6tables -t nat -F "$chain" --wait 5 2>/dev/null
        ip6tables -t nat -X "$chain" --wait 5 2>/dev/null

        log_fn "ℹ️ ip6tables: using direct DNAT (fallback)"

        if ! ip6tables -t nat -I OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "$dest_v6" \
                -m comment --comment "$comment" --wait 5 2>/dev/null; then
            log_fn "❌ ip6tables: failed UDP DNAT"
            return 1
        fi

        if ! ip6tables -t nat -I OUTPUT -p tcp --dport 53 \
                -j DNAT --to-destination "$dest_v6" \
                -m comment --comment "$comment" --wait 5 2>/dev/null; then
            ip6tables -t nat -D OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "$dest_v6" \
                -m comment --comment "$comment" --wait 5 2>/dev/null
            log_fn "❌ ip6tables: failed TCP DNAT"
            return 1
        fi

        log_fn "✅ ip6tables: direct DNAT applied (fallback)"
    fi

    return 0
}

# ============================================================
# [19] nftables management
# ============================================================
manage_nftables() {
    local mode="$1"
    local table="dnscrypt_filter"
    local chain="dnscrypt_chain"
    local dest_v4="127.0.0.1:5354"

    command -v nft >/dev/null 2>&1 || return 1

    nft delete table inet "$table" 2>/dev/null

    if [ "$mode" = "1" ]; then
        if ! nft add table inet "$table" 2>/dev/null; then
            log_fn "❌ nftables: failed to create table"
            return 1
        fi

        if ! nft add chain inet "$table" "$chain" \
                '{ type nat hook output priority -100 ; }' 2>/dev/null; then
            log_fn "❌ nftables: failed to create nat chain"
            nft delete table inet "$table" 2>/dev/null
            return 1
        fi

        local _ip
        for _ip in $LOOPBACK_IPS $BOOTSTRAP_IPS; do
            case "$_ip" in
                *:*)
                    nft add rule inet "$table" "$chain" \
                        ip6 daddr "$_ip" udp dport 53 return 2>/dev/null || true
                    nft add rule inet "$table" "$chain" \
                        ip6 daddr "$_ip" tcp dport 53 return 2>/dev/null || true
                    ;;
                *)
                    nft add rule inet "$table" "$chain" \
                        ip daddr "$_ip" udp dport 53 return 2>/dev/null || true
                    nft add rule inet "$table" "$chain" \
                        ip daddr "$_ip" tcp dport 53 return 2>/dev/null || true
                    ;;
            esac
        done

        nft add rule inet "$table" "$chain" \
            ip6 daddr ::1 udp dport 53 return 2>/dev/null || true
        nft add rule inet "$table" "$chain" \
            ip6 daddr ::1 tcp dport 53 return 2>/dev/null || true

        if ! nft add rule inet "$table" "$chain" \
                meta l4proto udp th dport 53 dnat to "$dest_v4" 2>/dev/null; then
            log_fn "❌ nftables: failed UDP DNAT"
            nft delete table inet "$table" 2>/dev/null
            return 1
        fi

        if ! nft add rule inet "$table" "$chain" \
                meta l4proto tcp th dport 53 dnat to "$dest_v4" 2>/dev/null; then
            log_fn "❌ nftables: failed TCP DNAT"
            nft delete table inet "$table" 2>/dev/null
            return 1
        fi

        log_fn "✅ nftables: rules added"
    fi

    return 0
}

# ============================================================
# [20] Firewall management (unified interface)
# ============================================================
manage_firewall() {
    local mode="$1"

    if [ "$mode" = "0" ]; then
        log_fn "🧹 Blind firewall cleanup..."
        manage_nftables 0 2>/dev/null
        manage_iptables 0 2>/dev/null
        manage_ip6tables 0 2>/dev/null
        return 0
    fi

    local fw
    fw=$(detect_firewall 2>/dev/null)

    case "$fw" in
        nftables)
            if ! manage_nftables 1 2>/dev/null; then
                log_fn "⚠️ nftables failed, falling back to iptables"
                manage_iptables 1 2>/dev/null
                manage_ip6tables 1 2>/dev/null
            fi
            ;;
        iptables)
            manage_iptables 1 2>/dev/null
            manage_ip6tables 1 2>/dev/null
            ;;
        *)
            log_fn "⚠️ No supported firewall found"
            ;;
    esac

    return 0
}

# ============================================================
# [21] Process cleanup
# ============================================================
cleanup_proxy() {
    log_fn "🧹 Cleaning up dnscrypt-proxy"

    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-proxy 2>/dev/null
        sleep 1
    fi

    if command -v fuser >/dev/null 2>&1; then
        fuser -k 5354/udp 2>/dev/null
        fuser -k 5354/tcp 2>/dev/null
    fi

    rm -f "$(run_file dnscrypt.pid)" 2>/dev/null
    rm -f /data/local/tmp/dnscrypt.pid 2>/dev/null

    log_fn "✅ cleanup_proxy completed"
}

cleanup_webui() {
    log_fn "🧹 Cleaning up dnscrypt-webui"

    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
    fi

    rm -f "$(run_file webui.pid)" 2>/dev/null
    rm -f /data/local/tmp/webui.pid 2>/dev/null

    log_fn "✅ cleanup_webui completed"
}

# ============================================================
# [22] Orphan process cleanup
# ============================================================
cleanup_orphans() {
    log_fn "🧹 Cleaning up orphan processes..."

    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        log_fn "Found orphan dnscrypt-proxy processes, killing..."
        pkill -9 -x dnscrypt-proxy 2>/dev/null
    fi

    local current_webui_pid=""
    local wpid_file
    wpid_file=$(run_file webui.pid)
    [ -f "$wpid_file" ] && current_webui_pid=$(cat "$wpid_file" 2>/dev/null | tr -d '\r\n ')

    local port
    port=$(get_webui_port)
    if command -v fuser >/dev/null 2>&1; then
        # Correct parsing of fuser output
        local pid_on_port
        pid_on_port=$(fuser -n tcp "$port" 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' | head -n1)

        if [ -n "$pid_on_port" ] && [ "$pid_on_port" != "$current_webui_pid" ]; then
            local comm
            comm=$(cat "/proc/$pid_on_port/comm" 2>/dev/null)
            case "$comm" in
                dnscrypt-webui|dnscrypt-webui*)
                    log_fn "Port $port held by PID $pid_on_port ($comm), killing..."
                    kill -9 "$pid_on_port" 2>/dev/null
                    ;;
                "")
                    log_fn "Port $port held by PID $pid_on_port (process gone), ignoring"
                    ;;
                *)
                    log_fn "Port $port held by PID $pid_on_port ($comm), NOT killing (unexpected process)"
                    ;;
            esac
        fi
    fi

    log_fn "✅ cleanup_orphans completed"
}

# ============================================================
# [23] Aggressive cleanup
# ============================================================
aggressive_cleanup() {
    log_fn "🧹 Aggressive cleanup starting..."
    cleanup_proxy
    cleanup_webui
    cleanup_orphans
    manage_firewall 0

    rm -f "$(run_file watchdog.pid)" 2>/dev/null
    rm -f /data/local/tmp/watchdog.pid 2>/dev/null

    log_fn "✅ Aggressive cleanup completed"
}

# ============================================================
# [24] Start WebUI
# ============================================================
start_native_webui() {
    local bin="$1"
    local port="${2:-9090}"

    log_fn "🚀 Starting WebUI (port: $port)"

    cleanup_webui

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
        local wpid_file
        wpid_file=$(run_file webui.pid)
        printf "%d\n" "$web_pid" > "${wpid_file}.tmp" 2>/dev/null
        mv -f "${wpid_file}.tmp" "$wpid_file" 2>/dev/null
    fi

    local i=0
    while [ "$i" -lt 35 ]; do
        if [ -n "$web_pid" ] && ! kill -0 "$web_pid" 2>/dev/null; then
            log_fn "❌ WebUI process died unexpectedly (Port collision?)"
            return 1
        fi

        if is_port_open "$port" tcp; then
            log_fn "✅ WebUI bound to port $port (PID: ${web_pid:-unknown})"
            return 0
        fi

        sleep 1
        i=$((i + 1))
    done

    log_fn "❌ WebUI failed to bind within 35s"
    return 1
}

# ============================================================
# [25] Normalize domain
# ============================================================
normalize_domain() {
    local line="$1"

    line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    case "$line" in
        ''|\#*) printf ""; return 1 ;;
    esac

    line="${line#||}"
    line="${line%^}"
    line="${line#\*.}"
    line="${line#.}"

    printf "%s" "$line" | tr 'A-Z' 'a-z'
    return 0
}

# ============================================================
# [26] Check domain match
# ============================================================
is_domain_match() {
    local blocked="$1"
    local allowed="$2"

    [ -z "$blocked" ] && return 1
    [ -z "$allowed" ] && return 1

    [ "$blocked" = "$allowed" ] && return 0

    case "$blocked" in
        *."$allowed") return 0 ;;
    esac

    return 1
}

# ============================================================
# [27] Load custom rules
# ============================================================
load_custom_rules() {
    local allow_file="$1"
    local deny_file="$2"
    local out_dir="$3"

    : > "$out_dir/_allow_norm.txt"
    : > "$out_dir/_deny_norm.txt"

    if [ -f "$allow_file" ]; then
        while IFS= read -r line; do
            local norm
            norm=$(normalize_domain "$line")
            [ -n "$norm" ] && echo "$norm" >> "$out_dir/_allow_norm.txt"
        done < "$allow_file"
    fi

    if [ -f "$deny_file" ]; then
        while IFS= read -r line; do
            local norm
            norm=$(normalize_domain "$line")
            [ -n "$norm" ] && echo "$norm" >> "$out_dir/_deny_norm.txt"
        done < "$deny_file"
    fi

    return 0
}

# ============================================================
# [28] Apply custom rules only (without download)
# ============================================================
apply_custom_rules_only() {
    local blocklist="$1"
    local allow_file="$2"
    local deny_file="$3"

    [ -f "$blocklist" ] || return 1

    local tmp_dir="/data/local/tmp"
    load_custom_rules "$allow_file" "$deny_file" "$tmp_dir"

    local allow_count deny_count
    allow_count=$(wc -l < "$tmp_dir/_allow_norm.txt" 2>/dev/null | tr -d ' ')
    deny_count=$(wc -l < "$tmp_dir/_deny_norm.txt" 2>/dev/null | tr -d ' ')

    if [ "${allow_count:-0}" = "0" ] && [ "${deny_count:-0}" = "0" ]; then
        log_fn "ℹ️ No custom rules to apply"
        rm -f "$tmp_dir/_allow_norm.txt" "$tmp_dir/_deny_norm.txt" 2>/dev/null
        return 0
    fi

    log_fn "⚙️ Applying custom rules (allow=$allow_count, deny=$deny_count)"

    local out="${blocklist}.filtered"
    : > "$out"

    local removed=0
    while IFS= read -r raw_line; do
        case "$raw_line" in
            ''|\#*)
                echo "$raw_line" >> "$out"
                continue
                ;;
        esac

        local norm
        norm=$(normalize_domain "$raw_line")
        if [ -z "$norm" ]; then
            echo "$raw_line" >> "$out"
            continue
        fi

        local allowed=0
        while IFS= read -r allow_dom; do
            [ -z "$allow_dom" ] && continue
            if is_domain_match "$norm" "$allow_dom"; then
                allowed=1
                break
            fi
        done < "$tmp_dir/_allow_norm.txt"

        if [ "$allowed" = "1" ]; then
            removed=$((removed + 1))
            continue
        fi

        echo "$raw_line" >> "$out"
    done < "$blocklist"

    if [ "${deny_count:-0}" -gt 0 ]; then
        echo "" >> "$out"
        echo "# === Custom Denylist ===" >> "$out"
        while IFS= read -r d; do
            [ -n "$d" ] && echo "$d" >> "$out"
        done < "$tmp_dir/_deny_norm.txt"
    fi

    if mv -f "$out" "$blocklist" 2>/dev/null; then
        log_fn "✅ Custom rules applied (removed=$removed, added=$deny_count)"
        rm -f "$tmp_dir/_allow_norm.txt" "$tmp_dir/_deny_norm.txt" 2>/dev/null
        return 0
    else
        log_fn "❌ Failed to swap filtered blocklist"
        rm -f "$out" "$tmp_dir/_allow_norm.txt" "$tmp_dir/_deny_norm.txt" 2>/dev/null
        return 1
    fi
}

# ============================================================
# [29] Generate random credentials
# ============================================================
generate_password() {
    local length="${1:-16}"
    local pass
    pass=$(tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c "$length")

    if [ -z "$pass" ] || [ "${#pass}" -lt "$length" ]; then
        pass="Auto_$(date +%s)_$(echo "$RANDOM" | md5sum | head -c 8)"
    fi

    printf "%s" "$pass"
}

generate_username() {
    local prefix="${1:-admin_}"
    local length="${2:-6}"
    local suffix
    suffix=$(tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c "$length")

    if [ -z "$suffix" ]; then
        suffix=$(date +%s | tail -c $((length + 1)))
    fi

    printf "%s%s" "$prefix" "$suffix"
}