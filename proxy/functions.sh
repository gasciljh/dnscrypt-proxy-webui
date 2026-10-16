#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — functions.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-15
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Layer 1 — advanced shell library. Sourced by:
#   • service.sh, action.sh, status.sh, uninstall.sh, watchdog.sh
#   • main.go (via runShell)
#
# Responsibilities:
#   • run/ directory hardening (chown 0:0)
#   • Bootstrap IP cache (5-minute TTL, atomic write)
#   • Progress file writer (atomic)
#   • Section-restricted TOML credentials reader
#   • Profile memory hint (display-only)
#   • Service state checks (DNS engine + WebUI)
#   • IPv6 availability detection
#   • Firewall management (nftables / iptables / ip6tables)
#   • Process cleanup (proxy, webui, orphans)
#   • WebUI launcher (setsid → busybox setsid → nohup)
#   • Persistent backup helpers (backup, restore, rotate)
#   • Watchdog token reader
#
# Delegated to Layer 0 (boot-mini.sh):
#   log_msg, get_run_dir, read_conf, is_port_open, get_webui_port,
#   and the _MONITORING_UI_PORT constant.
#
# File layout:
#   Part 1 of 3 — [1]–[11]:  Foundation
#   Part 2 of 3 — [12]–[17]: Firewall
#   Part 3 of 3 — [18]–[32]: Runtime + Backup
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module root resolution
# ============================================================
# Resolution order:
#   1. Caller-supplied MODDIR (the normal path).
#   2. $0-derived path (source tree or post-install layout).
#   3. Canonical install path.
#
# Mirrors boot-mini.sh's logic so functions.sh can locate
# boot-mini.sh even when MODDIR was not pre-set.
if [ -z "${MODDIR:-}" ]; then
    _fn_dir="${0%/*}"
    case "$_fn_dir" in
        /*/proxy) MODDIR="${_fn_dir%/proxy}" ;;
        /*)       MODDIR="$_fn_dir" ;;
        *)        MODDIR="/data/adb/modules/dnscrypt-proxy-webui" ;;
    esac
    unset _fn_dir
fi

# ============================================================
# [1b] Load boot-mini.sh (Layer 0)
# ============================================================
# Search order: module root first (post-install layout), then
# proxy/ (source tree). A missing boot-mini.sh is fatal — every
# function below depends on the primitives it defines. The
# error is emitted on stderr so the caller can see it in the
# log or logcat.
_BM_PATH=""
for _cand in "$MODDIR/boot-mini.sh" "$MODDIR/proxy/boot-mini.sh"; do
    if [ -f "$_cand" ]; then
        _BM_PATH="$_cand"
        break
    fi
done

if [ -z "$_BM_PATH" ]; then
    echo "functions.sh: boot-mini.sh not found (searched \$MODDIR and \$MODDIR/proxy)" >&2
    # shellcheck disable=SC2317  # return-or-exit idiom
    return 1 2>/dev/null || exit 1
fi

. "$_BM_PATH"
unset _BM_PATH _cand

# ============================================================
# [2] Run directory management
# ============================================================
# ensure_run_dir adds chown 0:0 that the Layer-0 primitive does
# not enforce on an already-existing directory.
# Returns 0 on success, 1 when only /data/local/tmp is available.
ensure_run_dir() {
    local rd
    rd=$(get_run_dir)
    [ "$rd" = "/data/local/tmp" ] && return 1
    chown 0:0 "$rd" 2>/dev/null
    return 0
}

# run_file <name> — absolute path of a runtime file.
run_file() {
    local run_dir
    run_dir=$(get_run_dir)
    printf "%s/%s" "$run_dir" "$1"
}

# init_runtime_paths — populates the runtime file paths and
# exports them. Prefers $RUN_DIR when writable; falls back to
# /data/local/tmp otherwise.
init_runtime_paths() {
    local rd
    rd=$(get_run_dir)

    LOG_FILE="/data/local/tmp/dnscrypt_main.log"

    if [ "$rd" != "/data/local/tmp" ]; then
        PROGRESS_FILE="$rd/update_progress.txt"
    else
        PROGRESS_FILE="/data/local/tmp/update_progress.txt"
    fi

    STATUS_FILE="$rd/dnscrypt.status"
    PID_FILE="$rd/dnscrypt.pid"
    WEBUI_PID_FILE="$rd/webui.pid"
    WATCHDOG_PID_FILE="$rd/watchdog.pid"
    WATCHDOG_TOKEN_FILE="$rd/.watchdog_token"

    export LOG_FILE PROGRESS_FILE STATUS_FILE PID_FILE
    export WEBUI_PID_FILE WATCHDOG_PID_FILE WATCHDOG_TOKEN_FILE
    export RUN_DIR_ACTIVE="$rd"
}

init_runtime_paths

# --- Fixed paths ---
TOML_FILE="$MODDIR/proxy/dnscrypt-proxy.toml"
WEBUI_CONF="$MODDIR/proxy/webui.conf"
SELECTED_PROFILE_FILE="$MODDIR/proxy/selected_profile.txt"

# --- Data preservation paths ---
#
# PERSISTENT_BACKUP and USER_FILES are the canonical Layer-1
# definitions. Two other files define the same values:
#
#   • customize.sh  — the installer runs BEFORE the module is
#                     extracted, so functions.sh is not on disk
#                     yet. It cannot source this file.
#   • install_app.sh — runs standalone (invoked by main.go, but
#                      via exec, not source). It also cannot
#                      source this file.
#
# The duplication is deliberate. Any change to PERSISTENT_BACKUP
# or USER_FILES MUST be applied to all three files. A CI check
# (`ci.yml` Step 3 — PERSISTENT_BACKUP path consistency)
# enforces that every file references the same path.
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# ============================================================
# [3] JSON escape helper
# ============================================================
# Escapes a string for safe inclusion inside a JSON string
# literal. Handles:
#   • backslash    → \\   (MUST be first)
#   • double-quote → \"
#   • tab          → \t
#   • CR           → \r
#   • LF           → \n   (multi-line input)
#
# After the explicit escapes, any remaining C0 control
# characters (0x00–0x08, 0x0B, 0x0C, 0x0E–0x1F) are dropped.
# Tab (0x09), CR (0x0D) and LF (0x0A) are excluded from the
# `tr` range because they have already been escaped above.
#
# NOTE: `tr` alone cannot perform this transformation — it
# operates per-byte and cannot insert multi-byte escape
# sequences. The `awk` pass handles the escape; `tr` cleans up
# whatever remains.
json_escape() {
    printf '%s' "$1" | awk '
        BEGIN { ORS = "" }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            gsub(/\t/, "\\t")
            gsub(/\r/, "\\r")
            if (NR > 1) printf "\\n"
            printf "%s", $0
        }
    ' | tr -d '\000-\010\013\014\016-\037'
}

# ============================================================
# [4] Bootstrap resolver cache
# ============================================================
# get_dynamic_bootstrap — extract bootstrap_resolvers from the
# TOML. Bounds the count at 32 so a malformed TOML cannot
# produce an unbounded firewall rule set.
#
# Anchor pattern requires bootstrap_resolvers to be the first
# non-whitespace token, so a commented-out line (`# bootstrap_...`)
# does not trigger collection.
get_dynamic_bootstrap() {
    [ ! -f "$TOML_FILE" ] && return 0

    awk '
        /^[[:space:]]*bootstrap_resolvers[[:space:]]*=/ { in_array=1 }
        in_array { printf "%s\n", $0 }
        in_array && /\][[:space:]]*(#|$)/ { exit }
    ' "$TOML_FILE" 2>/dev/null \
    | tr -d "',\"\r" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}|[0-9a-fA-F]{0,4}(:[0-9a-fA-F]{0,4}){2,7}' \
    | sort -u \
    | head -n 32 \
    | tr '\n' ' '
}

_BOOTSTRAP_CACHE_FILE="$(get_run_dir)/.bootstrap_cache"
_BOOTSTRAP_CACHE_TTL=300

# _load_bootstrap_from_cache — rejects missing paths, symlinks,
# non-regular files, stale entries, and content that does not
# look like a space-separated IP list.
_load_bootstrap_from_cache() {
    [ ! -f "$_BOOTSTRAP_CACHE_FILE" ] && return 1
    [ -L "$_BOOTSTRAP_CACHE_FILE" ] && return 1

    local cache_mtime now age
    cache_mtime=$(stat -c %Y "$_BOOTSTRAP_CACHE_FILE" 2>/dev/null) \
        || cache_mtime=$(stat -f %m "$_BOOTSTRAP_CACHE_FILE" 2>/dev/null) \
        || return 1

    # Guard: a failed `date` produces an empty `now`, which would
    # turn the arithmetic below into a syntax error.
    now=$(date +%s 2>/dev/null)
    case "$now" in
        ''|*[!0-9]*) return 1 ;;
    esac

    age=$((now - cache_mtime))

    if [ "$age" -lt 0 ] || [ "$age" -gt "$_BOOTSTRAP_CACHE_TTL" ]; then
        return 1
    fi

    local cached
    cached=$(cat "$_BOOTSTRAP_CACHE_FILE" 2>/dev/null)
    [ -z "$cached" ] && return 1

    if printf '%s' "$cached" | grep -qE '[^0-9a-fA-F.:[:space:]]'; then
        return 1
    fi

    printf "%s" "$cached"
    return 0
}

# _save_bootstrap_to_cache — atomic write via tmp + mv.
_save_bootstrap_to_cache() {
    local value="$1"
    local _rd
    _rd=$(get_run_dir)
    mkdir -p "$_rd" 2>/dev/null

    local _tmp="${_rd}/.bootstrap_cache.tmp.$$"
    if ! printf "%s" "$value" > "$_tmp" 2>/dev/null; then
        rm -f "$_tmp" 2>/dev/null
        return 0
    fi

    if ! mv -f "$_tmp" "$_rd/.bootstrap_cache" 2>/dev/null; then
        rm -f "$_tmp" 2>/dev/null
        return 0
    fi

    return 0
}

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

LOOPBACK_IPS="127.0.0.1"

# ============================================================
# [5] Progress file writer (atomic)
# ============================================================
# The message is truncated at 200 chars and sanitized of the
# pipe character (`|`), which is the field separator between
# percent and message in the file format. Without sanitization,
# a message containing `|` would shift the parse in main.go.
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

    # Replace the field separator to preserve the parse contract.
    msg=$(printf '%s' "$msg" | tr '|' '/')

    printf "%d|%s" "$percent" "$msg" > "${PROGRESS_FILE}.tmp" 2>/dev/null
    mv -f "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE" 2>/dev/null
}

# ============================================================
# [6] Dashboard port — Port Guard
# ============================================================
get_dashboard_port() {
    local conf_file="${1:-$WEBUI_CONF}"
    local port
    port=$(read_conf "$conf_file" "DASHBOARD_PORT" "9091" 2>/dev/null)

    if echo "$port" | grep -qE '^[0-9]+$' && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        if [ "$port" = "$_MONITORING_UI_PORT" ]; then
            log_msg "⚠️ DASHBOARD_PORT=$port conflicts with monitoring_ui — falling back to 9091"
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
# [7] Profile memory hint (display-only)
# ============================================================
# HINT only. main.go is the authority for the actual
# debug.SetMemoryLimit() value.
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
# [8] Auto-restart options
# ============================================================
get_auto_restart_dns() {
    local conf="${1:-$WEBUI_CONF}"
    local val
    val=$(read_conf "$conf" "AUTO_RESTART_DNS" "1")
    case "$val" in
        0|1) printf "%s" "$val" ;;
        *)   printf "1" ;;
    esac
}

get_auto_restart_webui() {
    local conf="${1:-$WEBUI_CONF}"
    local val
    val=$(read_conf "$conf" "AUTO_RESTART_WEBUI" "1")
    case "$val" in
        0|1) printf "%s" "$val" ;;
        *)   printf "1" ;;
    esac
}

# ============================================================
# [9] TOML credentials — section-restricted
# ============================================================
# Reads ONLY from [monitoring_ui]. Section tracking ignores any
# username/password in other sections.
#
# Supports section headers with trailing comments:
#     [monitoring_ui] # monitoring section
#
# NOTE: this parser is intentionally duplicated in three files
# (functions.sh, customize.sh, install_app.sh). Each file must
# be independently sourceable at different stages of the module
# lifecycle, so the duplication is deliberate. Any behavioral
# change MUST be applied to all three.
parse_toml_value() {
    local s="$1"
    [ -z "$s" ] && return 0
    s=$(printf '%s' "$s" | sed 's/^[[:space:]]*//')

    case "$s" in
        \"*)
            printf '%s' "$s" | sed 's/^"//; s/".*//'
            return 0
            ;;
    esac

    case "$s" in
        \'*)
            printf '%s' "$s" | sed "s/^'//; s/'.*//"
            return 0
            ;;
    esac

    case "$s" in
        *" #"*) s="${s%% #*}" ;;
    esac
    printf '%s' "$s" | sed 's/[[:space:]]*$//'
    return 0
}

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
                key=$(printf '%s' "$trimmed" | sed 's/^\([^=]*\)=.*$/\1/')
                key=$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                val=$(printf '%s' "$trimmed" | sed 's/^[^=]*=//')
                val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//')
                val=$(parse_toml_value "$val")

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
# [10] Service state checks
# ============================================================
# is_dnscrypt_running — two-tier check:
#   1. PID file → /proc/<pid>/comm == "dnscrypt-proxy" → port
#      5354/udp listening. The comm check catches PID reuse
#      after a reboot; the port check catches a process that is
#      alive but not yet bound.
#   2. Fallback: pgrep -x dnscrypt-proxy + port check.
is_dnscrypt_running() {
    local pid_file
    pid_file=$(run_file dnscrypt.pid)
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
            local comm
            comm=$(cat "/proc/$pid/comm" 2>/dev/null | tr -d '\r\n ')
            if [ "$comm" = "dnscrypt-proxy" ]; then
                if is_port_open 5354 udp; then
                    return 0
                fi
            fi
        fi
    fi

    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        if is_port_open 5354 udp; then
            return 0
        fi
    fi
    return 1
}

# is_webui_running [port] — defaults to get_webui_port.
# Port check only; the WebUI is a single process with a single
# listening socket.
is_webui_running() {
    local port="${1:-$(get_webui_port)}"
    is_port_open "$port" tcp
}

# ============================================================
# [11] IPv6 availability
# ============================================================
# /proc/net/if_inet6 lists one line per interface that has an
# IPv6 address. Its absence (or empty content) means IPv6 is
# not available on this device — all IPv6 firewall work can be
# skipped without error.
is_ipv6_available() {
    [ ! -f /proc/net/if_inet6 ] && return 1

    local count
    count=$(wc -l < /proc/net/if_inet6 2>/dev/null | tr -d ' ')

    # wc -l returns 0 for an empty file; treat "0 lines" as
    # "no interfaces with IPv6".
    [ -z "$count" ] && return 1
    [ "$count" -eq 0 ] && return 1

    return 0
}

# ============================================================
# [12] Firewall backend detection (60 s cache)
# ============================================================
# Probe order:
#   1. nftables — try `nft add table inet` (dual-stack) first,
#      then `ip` (IPv4-only). Delete the probe table on success.
#   2. iptables — verify the nat table is listable (catches
#      builds where the binary exists but the kernel module is
#      missing).
#   3. none — neither backend usable.
#
# Cached for 60 seconds. manage_firewall is called multiple
# times per boot; each detection costs several forks.
_FW_CACHE=""
_FW_CACHE_TIME=0

detect_firewall() {
    local now
    now=$(date +%s 2>/dev/null)
    case "$now" in
        ''|*[!0-9]*) now=0 ;;
    esac

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
# [13] Legacy firewall cleanup
# ============================================================
# Versions prior to v1.2.0 installed DNAT rules directly in
# OUTPUT, without a dedicated Custom Chain. Every upgrade must
# remove those legacy rules before installing the new ones.
#
# Every deletion is attempted twice — once with the
# `dnscrypt_smart_filter` comment tag, once without. This covers
# both the tagged rules (recent legacy versions) and the
# untagged rules (oldest legacy version).
#
# Both helpers are guarded by a once-per-shell flag. Without
# the guard, mode-0 (blind cleanup) followed by mode-1
# (install) would run the same delete cascade twice.

_LEGACY_CLEANUP_IPTABLES_DONE=0

_legacy_cleanup_iptables() {
    [ "$_LEGACY_CLEANUP_IPTABLES_DONE" = "1" ] && return 0
    _LEGACY_CLEANUP_IPTABLES_DONE=1

    command -v iptables >/dev/null 2>&1 || return 0

    iptables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination 127.0.0.1:5354 \
        -m comment --comment "dnscrypt_smart_filter" 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination 127.0.0.1:5354 \
        -m comment --comment "dnscrypt_smart_filter" 2>/dev/null

    iptables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination 127.0.0.1:5354 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination 127.0.0.1:5354 2>/dev/null

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

_LEGACY_CLEANUP_IP6TABLES_DONE=0

_legacy_cleanup_ip6tables() {
    [ "$_LEGACY_CLEANUP_IP6TABLES_DONE" = "1" ] && return 0
    _LEGACY_CLEANUP_IP6TABLES_DONE=1

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
# [14] Hybrid iptables (IPv4)
# ============================================================
# Strategy:
#   • mode != 1  →  full cleanup, return.
#   • mode == 1  →  cleanup, then:
#       1. Try Custom Chain (clean, no orphans).
#       2. If it fails → fallback to Direct DNAT.
#
# Some OEM chains (OnePlus, some Samsung) prevent Custom Chain
# creation; Direct DNAT works reliably on those.
#
# In the fallback path, the same RETURN rules used inside the
# Custom Chain are installed in OUTPUT before the DNAT rules.
# Without them, dnscrypt-proxy's own bootstrap queries would be
# DNAT'd back into itself, forming a resolver loop.
manage_iptables() {
    local mode="$1"
    local chain="DNSCRYPT_OUT"
    local comment="dnscrypt_smart_filter"
    local dest_v4="127.0.0.1:5354"

    command -v iptables >/dev/null 2>&1 || return 1

    _legacy_cleanup_iptables

    # --- [A] Full cleanup ---
    iptables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 5 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 5 2>/dev/null
    iptables -t nat -F "$chain" --wait 5 2>/dev/null
    iptables -t nat -X "$chain" --wait 5 2>/dev/null

    iptables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination "$dest_v4" \
        -m comment --comment "$comment" --wait 5 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination "$dest_v4" \
        -m comment --comment "$comment" --wait 5 2>/dev/null

    iptables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination "$dest_v4" --wait 5 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 \
        -j DNAT --to-destination "$dest_v4" --wait 5 2>/dev/null

    local _c_ip
    for _c_ip in $LOOPBACK_IPS $BOOTSTRAP_IPS; do
        case "$_c_ip" in *:*) continue ;; esac
        iptables -t nat -D OUTPUT -d "$_c_ip" -p udp --dport 53 \
            -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null
        iptables -t nat -D OUTPUT -d "$_c_ip" -p tcp --dport 53 \
            -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null
    done

    if [ "$mode" != "1" ]; then
        log_msg "✅ iptables: cleaned (all methods)"
        return 0
    fi

    # --- [B] Try Custom Chain first ---
    local use_chain=0

    if iptables -t nat -N "$chain" --wait 5 2>/dev/null; then
        if iptables -t nat -I OUTPUT -p udp --dport 53 -j "$chain" --wait 5 2>/dev/null && \
           iptables -t nat -I OUTPUT -p tcp --dport 53 -j "$chain" --wait 5 2>/dev/null; then

            local _added_return=0
            local _ip
            for _ip in $LOOPBACK_IPS $BOOTSTRAP_IPS; do
                case "$_ip" in *:*) continue ;; esac
                if iptables -t nat -A "$chain" -d "$_ip" -j RETURN --wait 5 2>/dev/null; then
                    _added_return=$((_added_return + 1))
                fi
            done

            if [ "$_added_return" -gt 0 ]; then
                if iptables -t nat -A "$chain" -j DNAT --to-destination "$dest_v4" --wait 5 2>/dev/null; then
                    use_chain=1
                    log_msg "✅ iptables: custom chain $chain created ($_added_return RETURN, 1 DNAT)"
                fi
            fi
        fi
    fi

    # --- [C] Fallback to Direct DNAT ---
    if [ "$use_chain" = "0" ]; then
        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 5 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 5 2>/dev/null
        iptables -t nat -F "$chain" --wait 5 2>/dev/null
        iptables -t nat -X "$chain" --wait 5 2>/dev/null

        log_msg "ℹ️ iptables: custom chain failed, using direct DNAT"

        if ! iptables -t nat -I OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "$dest_v4" \
                -m comment --comment "$comment" --wait 5 2>/dev/null; then
            log_msg "❌ iptables: failed to add UDP DNAT"
            return 1
        fi

        if ! iptables -t nat -I OUTPUT -p tcp --dport 53 \
                -j DNAT --to-destination "$dest_v4" \
                -m comment --comment "$comment" --wait 5 2>/dev/null; then
            log_msg "❌ iptables: failed to add TCP DNAT, rolling back UDP"
            iptables -t nat -D OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "$dest_v4" \
                -m comment --comment "$comment" --wait 5 2>/dev/null
            return 1
        fi

        local _insert_failed=0
        local _ip2
        for _ip2 in $LOOPBACK_IPS $BOOTSTRAP_IPS; do
            case "$_ip2" in *:*) continue ;; esac
            if ! iptables -t nat -I OUTPUT -d "$_ip2" -p udp --dport 53 \
                    -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null; then
                _insert_failed=1
            fi
            if ! iptables -t nat -I OUTPUT -d "$_ip2" -p tcp --dport 53 \
                    -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null; then
                _insert_failed=1
            fi
        done

        if [ "$_insert_failed" = "1" ]; then
            log_msg "⚠️ iptables: some RETURN rules failed to insert (fallback continues)"
        fi

        log_msg "✅ iptables: direct DNAT applied (fallback mode)"
    fi

    return 0
}

# ============================================================
# [15] Hybrid ip6tables (IPv6)
# ============================================================
# Same strategy as [14], adapted for IPv6:
#   1. Early-return if IPv6 is unavailable.
#   2. Early-return if the nat table is not supported by the
#      kernel build.
#   3. Full cleanup → Custom Chain → Direct DNAT fallback.
manage_ip6tables() {
    local mode="$1"
    local chain="DNSCRYPT_OUT6"
    local comment="dnscrypt_smart_filter"
    local dest_v6="[::1]:5354"

    if ! is_ipv6_available; then
        [ "$mode" = "1" ] && log_msg "ℹ️ IPv6 not available, skipping ip6tables"
        return 0
    fi

    command -v ip6tables >/dev/null 2>&1 || return 0

    if ! ip6tables -t nat -L -n >/dev/null 2>&1; then
        log_msg "ℹ️ ip6tables -t nat not supported, skipping IPv6"
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

    local _c_ip
    for _c_ip in ::1 $BOOTSTRAP_IPS; do
        case "$_c_ip" in
            *:*) ;;
            *) continue ;;
        esac
        ip6tables -t nat -D OUTPUT -d "$_c_ip" -p udp --dport 53 \
            -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null
        ip6tables -t nat -D OUTPUT -d "$_c_ip" -p tcp --dport 53 \
            -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null
    done

    if [ "$mode" != "1" ]; then
        log_msg "✅ ip6tables: cleaned"
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
                    log_msg "✅ ip6tables: custom chain $chain created ($_added_return RETURN, 1 DNAT)"
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

        log_msg "ℹ️ ip6tables: using direct DNAT (fallback)"

        if ! ip6tables -t nat -I OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "$dest_v6" \
                -m comment --comment "$comment" --wait 5 2>/dev/null; then
            log_msg "❌ ip6tables: failed UDP DNAT"
            return 1
        fi

        if ! ip6tables -t nat -I OUTPUT -p tcp --dport 53 \
                -j DNAT --to-destination "$dest_v6" \
                -m comment --comment "$comment" --wait 5 2>/dev/null; then
            ip6tables -t nat -D OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "$dest_v6" \
                -m comment --comment "$comment" --wait 5 2>/dev/null
            log_msg "❌ ip6tables: failed TCP DNAT"
            return 1
        fi

        local _ip2
        for _ip2 in ::1 $BOOTSTRAP_IPS; do
            case "$_ip2" in
                *:*) ;;
                *) continue ;;
            esac
            ip6tables -t nat -I OUTPUT -d "$_ip2" -p udp --dport 53 \
                -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null
            ip6tables -t nat -I OUTPUT -d "$_ip2" -p tcp --dport 53 \
                -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null
        done

        log_msg "✅ ip6tables: direct DNAT applied (fallback)"
    fi

    return 0
}

# ============================================================
# [16] nftables management
# ============================================================
# Single `inet` table covering both IPv4 and IPv6. Final DNAT
# rule redirects all port-53 traffic (both families) to the
# IPv4 loopback resolver.
#
# Rule order inside the chain (order matters):
#   1. RETURN for each bootstrap IPv4/IPv6.
#   2. RETURN for ::1.
#   3. DNAT for remaining UDP:53.
#   4. DNAT for remaining TCP:53.
#
# `nft delete table inet dnscrypt_filter` removes the whole
# table atomically — no orphan chains, no orphan rules.
manage_nftables() {
    local mode="$1"
    local table="dnscrypt_filter"
    local chain="dnscrypt_chain"
    local dest_v4="127.0.0.1:5354"

    command -v nft >/dev/null 2>&1 || return 1

    nft delete table inet "$table" 2>/dev/null

    if [ "$mode" = "1" ]; then
        if ! nft add table inet "$table" 2>/dev/null; then
            log_msg "❌ nftables: failed to create table"
            return 1
        fi

        if ! nft add chain inet "$table" "$chain" \
                '{ type nat hook output priority -100 ; }' 2>/dev/null; then
            log_msg "❌ nftables: failed to create nat chain"
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
            log_msg "❌ nftables: failed UDP DNAT"
            nft delete table inet "$table" 2>/dev/null
            return 1
        fi

        if ! nft add rule inet "$table" "$chain" \
                meta l4proto tcp th dport 53 dnat to "$dest_v4" 2>/dev/null; then
            log_msg "❌ nftables: failed TCP DNAT"
            nft delete table inet "$table" 2>/dev/null
            return 1
        fi

        log_msg "✅ nftables: rules added"
    fi

    return 0
}

# ============================================================
# [17] Firewall management (unified interface)
# ============================================================
# Mode:
#   "0" → remove all rules (blind cleanup).
#   "1" → install rules using the best available backend.
#
# Mode 0 invokes every backend's cleanup path unconditionally.
# It does NOT rely on `detect_firewall` being correct —
# guarantees no orphan rules even if the device switched
# backends between two runs.
#
# Always returns 0 — a device with no supported firewall must
# still allow the rest of the boot sequence to complete.
manage_firewall() {
    local mode="$1"

    if [ "$mode" = "0" ]; then
        log_msg "🧹 Blind firewall cleanup..."
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
                log_msg "⚠️ nftables failed, falling back to iptables"
                manage_iptables 1 2>/dev/null
                manage_ip6tables 1 2>/dev/null
            fi
            ;;
        iptables)
            manage_iptables 1 2>/dev/null
            manage_ip6tables 1 2>/dev/null
            ;;
        *)
            log_msg "⚠️ No supported firewall found"
            ;;
    esac

    return 0
}

# ============================================================
# [18] Process cleanup
# ============================================================
# cleanup_proxy terminates dnscrypt-proxy and removes its
# runtime artifacts.
#
# Order:
#   1. pkill -9 -x dnscrypt-proxy (exact-name match).
#   2. 1-second grace period (kernel reap before fuser).
#   3. fuser -k on the DNS ports (catches a process bound to
#      5354/udp but named differently).
#   4. Remove the PID file from both locations.
#   5. Remove the .tmp sidecar a crashed write_progress may
#      have left behind.
cleanup_proxy() {
    log_msg "🧹 Cleaning up dnscrypt-proxy"

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

    rm -f "${PROGRESS_FILE}.tmp" 2>/dev/null

    log_msg "✅ cleanup_proxy completed"
}

# cleanup_webui terminates dnscrypt-webui and removes its PID
# files.
#
# Does NOT call `fuser` on the WebUI port — the port is
# user-configurable, and a stale fuser call could kill an
# unrelated process that happened to listen on the same port.
cleanup_webui() {
    log_msg "🧹 Cleaning up dnscrypt-webui"

    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
    fi

    rm -f "$(run_file webui.pid)" 2>/dev/null
    rm -f /data/local/tmp/webui.pid 2>/dev/null

    log_msg "✅ cleanup_webui completed"
}

# ============================================================
# [19] Orphan process cleanup
# ============================================================
# Detects and kills processes holding a port this module owns
# but that are not the intended process (per PID file).
#
# Three cases for the current port holder:
#   1. comm == dnscrypt-webui → leftover from a previous run.
#      Kill it.
#   2. comm is empty → process already gone. Ignore.
#   3. comm is anything else → a FOREIGN process. DO NOT kill.
#      Log a warning so the operator can investigate.
#
# Case 3 is the critical safety valve: without it, a module
# that was misconfigured to a common port and then corrected
# would kill whatever legitimate service was listening.
cleanup_orphans() {
    log_msg "🧹 Cleaning up orphan processes..."

    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        log_msg "Found orphan dnscrypt-proxy processes, killing..."
        pkill -9 -x dnscrypt-proxy 2>/dev/null
    fi

    local current_webui_pid=""
    local wpid_file
    wpid_file=$(run_file webui.pid)
    [ -f "$wpid_file" ] && current_webui_pid=$(cat "$wpid_file" 2>/dev/null | tr -d '\r\n ')

    local port
    port=$(get_webui_port)
    if command -v fuser >/dev/null 2>&1; then
        # fuser writes "PID" or "PID1 PID2" (space-separated) to
        # stdout; the "user" column goes to stderr. Extract only
        # decimal PIDs to avoid picking up the numeric suffix of
        # a filename on ROMs that emit the target path.
        local pid_on_port
        pid_on_port=$(fuser -n tcp "$port" 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' | head -n1)

        if [ -n "$pid_on_port" ] && [ "$pid_on_port" != "$current_webui_pid" ]; then
            local comm
            comm=$(cat "/proc/$pid_on_port/comm" 2>/dev/null)
            case "$comm" in
                dnscrypt-webui|dnscrypt-webui*)
                    log_msg "Port $port held by PID $pid_on_port ($comm), killing..."
                    kill -9 "$pid_on_port" 2>/dev/null
                    ;;
                "")
                    log_msg "Port $port held by PID $pid_on_port (process gone), ignoring"
                    ;;
                *)
                    log_msg "Port $port held by PID $pid_on_port ($comm), NOT killing (unexpected process)"
                    ;;
            esac
        fi
    fi

    log_msg "✅ cleanup_orphans completed"
}

# ============================================================
# [20] Aggressive cleanup
# ============================================================
# Called by uninstall.sh and by any caller that needs a
# guaranteed full teardown.
#
# Order:
#   1. Processes first (release sockets before firewall teardown).
#   2. Firewall.
#   3. PID files last.
aggressive_cleanup() {
    log_msg "🧹 Aggressive cleanup starting..."
    cleanup_proxy
    cleanup_webui
    cleanup_orphans
    manage_firewall 0

    rm -f "$(run_file watchdog.pid)" 2>/dev/null
    rm -f /data/local/tmp/watchdog.pid 2>/dev/null

    log_msg "✅ Aggressive cleanup completed"
}

# ============================================================
# [21] Start WebUI
# ============================================================
# Launch strategy (three-way fallback):
#   1. `setsid`         — preferred; new session so the child
#                         survives the parent's exit.
#   2. `busybox setsid` — same, for BusyBox-only builds.
#   3. `nohup`          — last resort; ignores SIGHUP but does
#                         not create a new session.
#
# After launch, waits up to 35 seconds for the WebUI to bind.
# During this wait, also checks `kill -0` against the WebUI
# PID, so a port collision (which causes the WebUI to exit
# immediately) is detected as a distinct failure mode.
#
# Return: 0 = bound within timeout; 1 = died early or timeout.
start_native_webui() {
    local bin="$1"
    local port="${2:-9090}"

    log_msg "🚀 Starting WebUI (port: $port)"

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
            log_msg "❌ WebUI process died unexpectedly (Port collision?)"
            return 1
        fi

        if is_port_open "$port" tcp; then
            log_msg "✅ WebUI bound to port $port (PID: ${web_pid:-unknown})"
            return 0
        fi

        sleep 1
        i=$((i + 1))
    done

    log_msg "❌ WebUI failed to bind within 35s"
    return 1
}

# ============================================================
# [22] SELinux-aware file copy
# ============================================================
# Copies a single file and preserves its SELinux context.
# Preference: restorecon → chcon → no-op.
# Applies chmod 0600 (owner-only).
#
# The error path uses `log_msg` which handles an unset
# $LOG_FILE by falling back to stderr.
copy_with_context() {
    local src="$1"
    local dst="$2"

    if ! cp -f "$src" "$dst" 2>>"${LOG_FILE:-/dev/null}"; then
        log_msg "❌ copy_with_context FAILED: $src → $dst"
        return 1
    fi

    if command -v restorecon >/dev/null 2>&1; then
        restorecon "$dst" 2>/dev/null || true
    elif command -v chcon >/dev/null 2>&1; then
        chcon u:object_r:magisk_file:s0 "$dst" 2>/dev/null || true
    fi

    chmod 0600 "$dst" 2>/dev/null

    return 0
}

# ============================================================
# [23] Watchdog token reader
# ============================================================
# Reads the token written by customize.sh §[19b] or by main.go
# (loadOrCreateWatchdogToken). Used by watchdog.sh to
# authenticate its POST /api/ensure_running_service call.
#
# Token is 64 hex chars (256 bits). Both writers persist it
# atomically, so no partial read can occur. Symlink rejection
# prevents a race where the caller reads a link-target instead
# of the token itself.
#
# Return: 0 = token read (stdout, no newline); 1 = missing,
# symlink, or too short.
get_watchdog_token() {
    local token_file=""

    if [ -n "$WATCHDOG_TOKEN_FILE" ]; then
        token_file="$WATCHDOG_TOKEN_FILE"
    else
        token_file="$(run_file .watchdog_token)"
    fi

    [ -f "$token_file" ] || return 1
    [ -L "$token_file" ] && return 1

    local tok
    tok=$(cat "$token_file" 2>/dev/null | tr -d '\r\n ')

    [ -n "$tok" ] || return 1
    [ "${#tok}" -ge 32 ] || return 1

    printf "%s" "$tok"
    return 0
}

# ============================================================
# [24] Backup directory paths
# ============================================================
get_backup_dir() {
    printf "%s" "$PERSISTENT_BACKUP"
}

# ensure_backup_dir creates the backup root if missing and
# applies chmod 0700 in ALL cases.
#
# On Android, /sdcard is a FUSE mount that typically ignores
# chmod. The call is best-effort — the effective protection is
# the per-file chmod 0600 applied by copy_with_context.
ensure_backup_dir() {
    if [ ! -d "$PERSISTENT_BACKUP" ]; then
        mkdir -p "$PERSISTENT_BACKUP" 2>/dev/null || return 1
    fi
    chmod 0700 "$PERSISTENT_BACKUP" 2>/dev/null || true
    return 0
}

# ============================================================
# [25] write_manifest <target_dir> <source> <count> [version]
# ============================================================
# Writes a .manifest.json with metadata about the snapshot.
# Three string fields are escaped with the shared `json_escape`
# helper: source (user-controllable), version (module.prop),
# and root_solution (hard-coded enum).
#
# `timestamp` (date format) and `files_count` (integer) are
# safe by construction.
write_manifest() {
    local target_dir="$1"
    local source="$2"
    local count="$3"
    local version="${4:-${MODULE_VERSION:-unknown}}"

    local manifest="$target_dir/.manifest.json"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)

    local root_sol="${ROOT_SOLUTION:-}"
    if [ -z "$root_sol" ]; then
        if [ -n "${KSU_VER:-}" ] || [ -d "/data/adb/ksu" ]; then
            root_sol="kernelsu"
        elif [ -n "${APATCH:-}" ] || [ -d "/data/adb/ap" ]; then
            root_sol="apatch"
        elif [ -n "${MAGISK_VER_CODE:-}" ] || [ -d "/data/adb/magisk" ]; then
            root_sol="magisk"
        else
            root_sol="unknown"
        fi
    fi

    local src_escaped version_escaped root_escaped
    src_escaped=$(json_escape "$source")
    version_escaped=$(json_escape "$version")
    root_escaped=$(json_escape "$root_sol")

    local files_json=""
    local f
    for f in $USER_FILES; do
        if [ -f "$target_dir/$f" ]; then
            local sha=""
            if command -v sha256sum >/dev/null 2>&1; then
                sha=$(sha256sum "$target_dir/$f" 2>/dev/null | awk '{print $1}')
            fi
            files_json="$files_json{\"name\":\"$f\",\"sha256\":\"$sha\"},"
        fi
    done
    files_json="${files_json%,}"

    cat > "$manifest" << EOF
{
  "version": "$version_escaped",
  "timestamp": "$ts",
  "source": "$src_escaped",
  "root_solution": "$root_escaped",
  "files_count": $count,
  "files": [$files_json]
}
EOF

    chmod 0600 "$manifest" 2>/dev/null
    return 0
}

# ============================================================
# [26] verify_backup_integrity <dir> [strict]
# ============================================================
# Validates every user file in the given directory:
#   • Non-empty
#   • Size < 10 MB
#   • SHA256 matches the manifest (when jq/awk/sha256 available)
#
# strict=0 (default) — best-effort. Missing manifest or missing
#                     sha256sum are advisory only.
# strict=1           — manifest and sha256sum mandatory; also
#                     cross-checks the file count against the
#                     manifest's files_count.
#
# Returns 0 if clean, 1 if any warnings were detected. When 0
# user files are found, logs a warning and returns 1.
verify_backup_integrity() {
    local dir="$1"
    local strict="${2:-0}"
    local manifest="$dir/.manifest.json"

    [ -d "$dir" ] || return 1

    local errors=0
    local checked=0

    local has_jq=0
    command -v jq >/dev/null 2>&1 && has_jq=1

    local has_sha=0
    command -v sha256sum >/dev/null 2>&1 && has_sha=1

    if [ "$strict" = "1" ]; then
        if [ ! -f "$manifest" ]; then
            log_msg "⚠️ verify_backup: manifest missing: $manifest"
            return 1
        fi
        if [ "$has_sha" != "1" ]; then
            log_msg "⚠️ verify_backup: sha256sum unavailable — cannot verify"
            return 1
        fi
    fi

    local manifest_count=0
    if [ "$strict" = "1" ] && [ "$has_jq" = "1" ]; then
        manifest_count=$(jq -r '.files_count // 0' "$manifest" 2>/dev/null)
        case "$manifest_count" in
            ''|*[!0-9]*) manifest_count=0 ;;
        esac
    fi

    for f in $USER_FILES; do
        local file="$dir/$f"
        [ -f "$file" ] || continue
        checked=$((checked + 1))

        if [ ! -s "$file" ]; then
            log_msg "⚠️ verify_backup: empty file: $f"
            errors=$((errors + 1))
            continue
        fi

        local size
        size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
        if [ -n "$size" ] && [ "$size" -gt 10485760 ]; then
            log_msg "⚠️ verify_backup: oversized file: $f ($size bytes)"
            errors=$((errors + 1))
            continue
        fi

        [ -f "$manifest" ] || continue
        [ "$has_sha" = "1" ] || continue

        local expected_sha=""

        if [ "$has_jq" = "1" ]; then
            expected_sha=$(jq -r --arg name "$f" \
                '.files[]? | select(.name == $name) | .sha256 // empty' \
                "$manifest" 2>/dev/null | head -n1)
        fi

        if [ -z "$expected_sha" ]; then
            expected_sha=$(awk -v name="$f" '
                BEGIN {
                    gsub(/[.\[\]*+?(){}|^$\\]/, "\\\\&", name)
                }
                {
                    if (match($0, "\"name\"[[:space:]]*:[[:space:]]*\"" name "\"")) {
                        found = 1
                    }
                    if (found && match($0, "\"sha256\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"", m)) {
                        print m[1]
                        exit
                    }
                }' "$manifest" 2>/dev/null)
        fi

        if [ -z "$expected_sha" ]; then
            expected_sha=$(grep -o "\"name\"[[:space:]]*:[[:space:]]*\"$f\"[^}]*\"sha256\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$manifest" 2>/dev/null | \
                           head -n1 | \
                           sed 's/.*"sha256"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        fi

        if [ -z "$expected_sha" ]; then
            if [ "$strict" = "1" ]; then
                log_msg "⚠️ verify_backup: no SHA256 in manifest for: $f"
                errors=$((errors + 1))
            fi
            continue
        fi

        local actual_sha
        actual_sha=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')

        if [ "$actual_sha" != "$expected_sha" ]; then
            log_msg "⚠️ verify_backup: SHA256 mismatch: $f"
            log_msg "   expected: ${expected_sha:0:16}..."
            log_msg "   actual:   ${actual_sha:0:16}..."
            errors=$((errors + 1))
        fi
    done

    if [ "$checked" -eq 0 ]; then
        log_msg "⚠️ verify_backup: no user files found in $dir"
        return 1
    fi

    if [ "$strict" = "1" ] && [ "$manifest_count" -gt 0 ]; then
        if [ "$checked" -ne "$manifest_count" ]; then
            log_msg "⚠️ verify_backup: count mismatch — manifest=$manifest_count, checked=$checked"
            errors=$((errors + 1))
        fi
    fi

    log_msg "ℹ️ verify_backup: checked=$checked errors=$errors in $(basename "$dir")"

    [ "$errors" -eq 0 ]
}

# ============================================================
# [27] backup_user_files <src_dir> [dst_dir] [version]
# ============================================================
# Snapshots the 5 user files from <src_dir>.
#
# If <dst_dir> is provided, files are written directly there
# (used by the transaction system and by main.go). Otherwise a
# timestamped directory is created under $PERSISTENT_BACKUP:
#     <YYYYMMDD>-<HHMMSS>-manual-<pid>
#
# Returns 0 on success (>= 1 file copied), 1 on any failure.
#
# Iterates over $USER_FILES only. The `apk/` mirror subfolder
# (created by customize.sh §[10c]) is not in that list and is
# therefore never touched.
backup_user_files() {
    local src_dir="$1"
    local dst_dir="$2"
    local version="${3:-${MODULE_VERSION:-unknown}}"
    local ts

    [ -d "$src_dir" ] || {
        log_msg "❌ backup_user_files: source dir not found: $src_dir"
        return 1
    }

    if [ -z "$dst_dir" ]; then
        ensure_backup_dir || {
            log_msg "❌ backup_user_files: cannot create backup root"
            return 1
        }
        ts=$(date +%Y%m%d-%H%M%S)
        dst_dir="$PERSISTENT_BACKUP/$ts-manual-$$"
    fi

    mkdir -p "$dst_dir" 2>/dev/null || {
        log_msg "❌ backup_user_files: cannot create target: $dst_dir"
        return 1
    }

    local count=0
    local f
    for f in $USER_FILES; do
        if [ -f "$src_dir/$f" ] && [ -s "$src_dir/$f" ]; then
            if copy_with_context "$src_dir/$f" "$dst_dir/$f"; then
                count=$((count + 1))
            fi
        fi
    done

    if [ "$count" -eq 0 ]; then
        log_msg "❌ backup_user_files: 0 files copied from $src_dir"
        rm -rf "$dst_dir" 2>/dev/null
        return 1
    fi

    write_manifest "$dst_dir" "$src_dir" "$count" "$version"

    log_msg "✅ backup_user_files: $count file(s) → $dst_dir"
    return 0
}

# ============================================================
# [28] restore_user_files <src_dir> [dst_dir]
# ============================================================
# Restores the 5 user files from <src_dir> into <dst_dir>
# (default: $MODDIR/proxy) with SELinux context preservation
# and per-file verification.
#
# Returns 0 if at least one file was restored, 1 otherwise.
#
# Three-part safety model:
#
#   (a) PRE-FLIGHT — verify that BOTH critical source files
#       (webui.conf, dnscrypt-proxy.toml) exist and are
#       non-empty. If either is missing, return 1 immediately
#       without touching dst_dir.
#
#   (b) SNAPSHOT — before the restore loop, save the pre-restore
#       content of the two critical files into a temp dir. For
#       critical files that did not exist pre-restore, record
#       an `.absent` marker so rollback can DELETE them.
#
#   (c) ROLLBACK — on critical failure, restore the two critical
#       files from the snapshot (or delete them if absent).
#       The loop BREAKS on the first critical failure instead
#       of continuing to overwrite non-critical files with data
#       from an unverified source.
#
# Iterates over $USER_FILES only. The `apk/` mirror subfolder
# is never touched.
restore_user_files() {
    local src_dir="$1"
    local dst_dir="${2:-$MODDIR/proxy}"

    [ -d "$src_dir" ] || {
        log_msg "❌ restore_user_files: source dir not found: $src_dir"
        return 1
    }

    mkdir -p "$dst_dir" 2>/dev/null || {
        log_msg "❌ restore_user_files: cannot create target: $dst_dir"
        return 1
    }

    # --- (a) PRE-FLIGHT ---
    local _critical_missing=0
    local _cf
    for _cf in webui.conf dnscrypt-proxy.toml; do
        if [ ! -f "$src_dir/$_cf" ] || [ ! -s "$src_dir/$_cf" ]; then
            log_msg "❌ restore_user_files: critical source missing/empty: $_cf"
            _critical_missing=1
        fi
    done
    if [ "$_critical_missing" = "1" ]; then
        log_msg "❌ restore_user_files: aborting — critical source(s) incomplete"
        return 1
    fi

    verify_backup_integrity "$src_dir" || {
        log_msg "⚠️ restore_user_files: source has integrity warnings (continuing)"
    }

    # --- (b) SNAPSHOT ---
    # The temp dir lives inside dst_dir so the later `mv`/`cp`
    # stays on the same filesystem. It carries a distinctive
    # `.restore_snap.*` prefix that `rotate_backups` excludes
    # (no `.manifest.json`), so a signal-interrupted restore
    # cannot leak a false snapshot into the rotation set.
    local _snapdir=""
    _snapdir=$(mktemp -d "${dst_dir}/.restore_snap.XXXXXX" 2>/dev/null) || _snapdir=""

    if [ -n "$_snapdir" ]; then
        local _cf2
        for _cf2 in webui.conf dnscrypt-proxy.toml; do
            if [ -f "$dst_dir/$_cf2" ] && [ -s "$dst_dir/$_cf2" ]; then
                if ! cp -f "$dst_dir/$_cf2" "$_snapdir/$_cf2" 2>/dev/null; then
                    log_msg "⚠️ restore_user_files: snapshot of $_cf2 failed — no rollback available"
                    rm -rf "$_snapdir" 2>/dev/null
                    _snapdir=""
                    break
                fi
            else
                : > "$_snapdir/$_cf2.absent" 2>/dev/null
            fi
        done
    else
        log_msg "⚠️ restore_user_files: mktemp -d failed — no rollback available"
    fi

    # --- Restore loop ---
    local restored=0
    local failed=0
    local critical_failed=0

    for f in $USER_FILES; do
        local src="$src_dir/$f"
        if [ -f "$src" ] && [ -s "$src" ]; then
            if copy_with_context "$src" "$dst_dir/$f"; then
                if [ -f "$dst_dir/$f" ] && [ -s "$dst_dir/$f" ]; then
                    restored=$((restored + 1))
                else
                    failed=$((failed + 1))
                    case "$f" in
                        webui.conf|dnscrypt-proxy.toml)
                            critical_failed=1
                            log_msg "❌ restore_user_files: CRITICAL verify failure: $f"
                            break
                            ;;
                    esac
                fi
            else
                failed=$((failed + 1))
                case "$f" in
                    webui.conf|dnscrypt-proxy.toml)
                        critical_failed=1
                        log_msg "❌ restore_user_files: CRITICAL copy failure: $f"
                        break
                        ;;
                esac
            fi
        fi
    done

    # --- (c) ROLLBACK ---
    if [ "$critical_failed" = "1" ] && [ -n "$_snapdir" ]; then
        log_msg "🔄 restore_user_files: rolling back critical files..."
        local _cf3
        for _cf3 in webui.conf dnscrypt-proxy.toml; do
            if [ -f "$_snapdir/$_cf3" ]; then
                if cp -f "$_snapdir/$_cf3" "$dst_dir/$_cf3" 2>/dev/null; then
                    chmod 0600 "$dst_dir/$_cf3" 2>/dev/null
                    log_msg "  ✓ Rolled back: $_cf3"
                else
                    log_msg "  ⚠️ Rollback of $_cf3 failed"
                fi
            elif [ -f "$_snapdir/$_cf3.absent" ]; then
                if rm -f "$dst_dir/$_cf3" 2>/dev/null; then
                    log_msg "  ✓ Removed (was absent): $_cf3"
                fi
            fi
        done
    fi

    [ -n "$_snapdir" ] && rm -rf "$_snapdir" 2>/dev/null

    if [ "$critical_failed" = "1" ]; then
        log_msg "❌ restore_user_files: critical file(s) failed — aborting"
        return 1
    fi

    if [ "$failed" -gt 0 ]; then
        log_msg "⚠️ restore_user_files: $failed non-critical file(s) failed"
    fi

    if [ "$restored" -gt 0 ]; then
        log_msg "✅ restore_user_files: $restored file(s) ← $src_dir"
        return 0
    fi

    log_msg "❌ restore_user_files: no files restored from $src_dir"
    return 1
}

# ============================================================
# [29] rotate_backups [keep_count]
# ============================================================
# Prunes the persistent backup directory to keep at most
# `keep_count` snapshots (default 21), preserving:
#   • current/      (live snapshot)
#   • txn-*/        (in-flight transactions)
#   • orphan-txn-*/ (preserved interrupted transactions)
#   • apk/          (companion APK mirror, v1.5.0)
#   • .restore_snap.* (transient restore scratch — no manifest)
#   • .last_stable  (pointer)
#   • .upgrade_history.json / .txt
#   • .last_auto_backup
#   • README.md
#
# Three rotation semantics:
#
#   • ROT-MANIFEST — snapshots are detected by the presence of
#     `.manifest.json` (not by name pattern).
#
#   • ROT-MTIME — candidates are sorted by mtime (numeric,
#     descending), not by directory name.
#
#   • ROT-PROTECT — two additional targets are preserved on
#     top of the 21-newest window:
#       - the `.last_stable` target (recovery pointer)
#       - the newest install snapshot (name matching `-v<digit>`)
#
# Canonical status: THIS is the reference implementation.
# `customize.sh` §[22b] carries a mirrored copy because the
# installer runs before the module is extracted and cannot
# source this file. Any change here MUST be applied to the
# customize.sh copy as well.
#
# The `apk/` mirror subfolder is preserved by TWO independent
# mechanisms:
#   (a) The `case` statement explicitly skips it.
#   (b) It has no `.manifest.json`, so ROT-MANIFEST would
#       exclude it even without (a).
rotate_backups() {
    local keep="${1:-21}"

    [ -d "$PERSISTENT_BACKUP" ] || return 0
    [ -r "$PERSISTENT_BACKUP" ] || {
        log_msg "⚠️ rotate_backups: $PERSISTENT_BACKUP is not readable — skipping"
        return 0
    }

    local _protected=""
    if [ -f "$PERSISTENT_BACKUP/.last_stable" ]; then
        _protected=$(cat "$PERSISTENT_BACKUP/.last_stable" 2>/dev/null | tr -d '\r\n ')
    fi

    local _list
    _list=$(
        cd "$PERSISTENT_BACKUP" 2>/dev/null || exit 0
        for _d in */; do
            _d="${_d%/}"
            [ -d "$_d" ] || continue
            case "$_d" in
                current|txn-*|orphan-txn-*|apk|.restore_snap.*) continue ;;
            esac
            [ -f "$_d/.manifest.json" ] || continue
            _mt=$(stat -c %Y "$_d" 2>/dev/null) \
                || _mt=$(stat -f %m "$_d" 2>/dev/null) \
                || _mt=0
            case "$_mt" in ''|*[!0-9]*) _mt=0 ;; esac
            printf '%s %s\n' "$_mt" "$_d"
        done | LC_ALL=C sort -rn -k1,1
    )

    [ -z "$_list" ] && return 0

    local total
    total=$(printf '%s\n' "$_list" | wc -l | tr -d ' ')

    if [ "$total" -le "$keep" ]; then
        log_msg "ℹ️ rotate_backups: $total snapshot(s) — within limit ($keep)"
        return 0
    fi

    local to_remove=$((total - keep))
    log_msg "🧹 rotate_backups: removing $to_remove old snapshot(s) (keeping $keep)"

    local _newest_install
    _newest_install=$(
        printf '%s\n' "$_list" | \
        grep -E ' [0-9]{8}-[0-9]{6}-v[0-9]' | \
        head -n1 | \
        awk '{print $2}'
    )

    local _mt _name
    while IFS=' ' read -r _mt _name; do
        [ -z "$_name" ] && continue
        if [ "$_name" = "$_protected" ]; then
            log_msg "  🛡️ Preserved (last_stable): $_name"
            continue
        fi
        if [ "$_name" = "$_newest_install" ]; then
            log_msg "  🛡️ Preserved (newest install): $_name"
            continue
        fi
        if rm -rf "${PERSISTENT_BACKUP:?}/${_name:?}" 2>/dev/null; then
            log_msg "  🗑️ Removed: $_name"
        fi
    done <<EOF
$(printf '%s\n' "$_list" | tail -n "$to_remove")
EOF

    log_msg "✅ rotate_backups: done"
    return 0
}

# ============================================================
# [30] get_last_backup_time
# ============================================================
# Returns the epoch mtime of .last_auto_backup, or 0 if the
# marker does not exist.
get_last_backup_time() {
    local marker="$PERSISTENT_BACKUP/.last_auto_backup"

    [ ! -f "$marker" ] && { printf "0"; return 0; }

    local mtime
    mtime=$(stat -c %Y "$marker" 2>/dev/null) \
        || mtime=$(stat -f %m "$marker" 2>/dev/null) \
        || mtime=0

    printf "%s" "$mtime"
}

# ============================================================
# [31] auto_backup_if_needed [interval_seconds]
# ============================================================
# Triggers a backup if the last one is older than
# `interval_seconds` (default 86400 = 24 hours).
#
# Uses $PERSISTENT_BACKUP/.last_auto_backup as the marker.
# Called by service.sh on every boot.
#
# The marker is updated only after verifying the target
# directory exists. A silent failure would otherwise push the
# next attempt 24 hours into the future.
#
# Neither this function nor rotate_backups() touches the apk/
# mirror.
auto_backup_if_needed() {
    local interval="${1:-86400}"

    if ! echo "$interval" | grep -qE '^[0-9]+$'; then
        interval=86400
    fi

    ensure_backup_dir || return 0

    local src_dir="$MODDIR/proxy"
    [ -d "$src_dir" ] || return 0

    local last
    last=$(get_last_backup_time)

    if ! echo "$last" | grep -qE '^[0-9]+$'; then
        last=0
    fi

    local now
    now=$(date +%s)

    if ! echo "$now" | grep -qE '^[0-9]+$'; then
        now=0
    fi

    local age=$((now - last))

    if [ "$last" -gt 0 ] && [ "$age" -lt "$interval" ]; then
        log_msg "ℹ️ auto_backup: skipped (last was ${age}s ago, interval=${interval}s)"
        return 0
    fi

    log_msg "🔄 auto_backup: starting (age=${age}s, interval=${interval}s)"

    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local target="$PERSISTENT_BACKUP/$ts-auto-$$"

    if backup_user_files "$src_dir" "$target"; then
        if [ -d "$target" ]; then
            touch "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null || true
        else
            log_msg "⚠️ auto_backup: target dir missing after backup — marker not updated"
            return 1
        fi

        rotate_backups 21

        log_msg "✅ auto_backup: complete → $target"
        return 0
    fi

    log_msg "❌ auto_backup: failed"
    return 1
}

# ============================================================
# [32] cleanup_old_transactions
# ============================================================
# Removes COMMIT'd txn-* directories from previous installs.
#
# ROLLBACK and START transactions are PRESERVED — they may
# contain the only copy of a user's data if an install was
# interrupted mid-flight.
#
# Iterates over txn-* directories only. The apk/ mirror does
# not match that prefix and is never touched.
cleanup_old_transactions() {
    [ -d "$PERSISTENT_BACKUP" ] || return 0

    local _removed=0
    local _txn
    local _state

    for _txn in "$PERSISTENT_BACKUP"/txn-*; do
        [ -d "$_txn" ] || continue

        _state=$(cat "$_txn/.state" 2>/dev/null | tr -d '\r\n ')
        if [ "$_state" = "COMMIT" ]; then
            if rm -rf "$_txn" 2>/dev/null; then
                _removed=$((_removed + 1))
            fi
        fi
    done

    if [ "$_removed" -gt 0 ]; then
        log_msg "✅ cleanup_old_transactions: removed $_removed COMMIT'd txn(s)"
    fi

    return 0
}
