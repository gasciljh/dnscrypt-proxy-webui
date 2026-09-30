#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – functions.sh
# Version: v1.2.0 (Global Edition)
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Shared shell library sourced by other scripts (service.sh,
#   action.sh, status.sh, uninstall.sh, watchdog.sh, main.go).
#
# Responsibilities (v1.2.0):
#   • run/ directory management (init + fallback to /data/local/tmp)
#   • Bootstrap IP cache (5-minute TTL from TOML)
#   • Logging helper (with emergency-only rotation at 50 MB)
#   • Progress file writer (atomic)
#   • Config file reader (webui.conf)
#   • Port readers with Port Guard (rejects 8080)
#   • Section-restricted TOML credentials reader
#   • Profile memory hint reader (v1.1.0)
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
#   • SELinux context preservation helper (v1.2.0)
#   • Persistent backup/restore helpers (v1.2.0)
#   • Backup rotation (v1.2.0)
#   • Auto-backup trigger (v1.2.0)
#   • Transaction cleanup helper (v1.2.0)
#   • Watchdog token reader (v1.2.0)
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
# ============================================================
# v1.2.0 — Data preservation helpers
# ============================================================
# Five user config files are preserved across every upgrade:
#   • webui.conf
#   • dnscrypt-proxy.toml
#   • selected_profile.txt
#   • allowlist.txt
#   • denylist.txt
#
# This library exposes the following helpers, used by
# service.sh and (optionally) by main.go via runShell:
#
#   get_backup_dir
#   ensure_backup_dir
#   write_manifest <target_dir> <source> <count> [version]
#   verify_backup_integrity <dir>
#   backup_user_files <src_dir> [dst_dir] [version]
#   restore_user_files <src_dir> [dst_dir]
#   rotate_backups [keep_count]
#   get_last_backup_time
#   auto_backup_if_needed [interval_seconds]
#   cleanup_old_transactions
#   copy_with_context <src> <dst>
#   get_watchdog_token
#
# These helpers are also implemented inline in customize.sh so
# that the installer does not depend on this file. The versions
# here are the canonical reference and are used at runtime.
# ============================================================
#
# v1.1.0 coordination (unchanged in v1.2.0):
#   • The constant `_MONITORING_UI_PORT` below MUST stay in sync
#     with `MONITORING_UI_PORT` in main.go.
#   • Memory limits (light/normal/pro/proplus/ultimate) are
#     managed by main.go only. This file provides a read-only
#     helper `get_profile_memory_hint` for user-facing display.
#   • Port collision resolution is handled by customize.sh at
#     install time; this file only enforces the 8080 rejection.
# ============================================================
#
# v1.2.0 — POST-AUDIT FIXES (still v1.2.0)
# ============================================================
# This file carries two identifier families. The inventory
# below is the AUTHORITATIVE list of identifiers actually
# present in the file. It was corrected during the v1.2.0
# release audit to remove historical mislabeling and to
# document the true identifier set.
#
# Identifier inventory in THIS file (25 total):
#
#   • FSH-1, FSH-2, FSH-3, FSH-4, FSH-5, FSH-6, FSH-7,
#     FSH-9, FSH-10, FSH-11                     (10)
#       — original post-audit corrections
#         (FSH-8 is intentionally NOT in this file —
#          it belongs to customize.sh)
#
#   • FSH-12, FSH-13, FSH-14, FSH-15              (4)
#       — NEW corrections in this revision:
#         FSH-12 → real symlink rejection in
#                  `_load_bootstrap_from_cache`
#                  (HARD-FSH-06 was documented but the
#                   implementation was a no-op duplicate
#                   of the previous `-f` check)
#         FSH-13 → removed the redundant `: >` +
#                  `touch` pair in
#                  `auto_backup_if_needed`
#         FSH-14 → `restore_user_files` now aborts on
#                  critical-file failure (parity with
#                  CSH-15 in customize.sh)
#         FSH-15 → `get_watchdog_token` now rejects a
#                  token file that is not a regular file
#                  (symlink / FIFO / device rejection)
#
#   • HARD-FSH-01, HARD-FSH-02, HARD-FSH-03,
#     HARD-FSH-04, HARD-FSH-05, HARD-FSH-06,
#     HARD-FSH-07, HARD-FSH-08, HARD-FSH-09,
#     HARD-FSH-10, HARD-FSH-11                    (11)
#       — hardening fixes
#
# NOTE ON IDENTIFIER GAPS:
#   FSH-8 is intentionally absent from this file. It is a
#   cross-reference to customize.sh (see "Documentation
#   fixes" there) and does not represent a fix in this
#   library. This is documented so future auditors do not
#   assume the file is missing a fix.
#
# NOTE ON HARD-FSH-06 (documented fix vs. real fix):
#   HARD-FSH-06 was documented as "rejects symlinks", but
#   the original implementation duplicated the `[ ! -f ]`
#   check (which follows symlinks and returns true for a
#   regular target). The real fix is FSH-12 below. The
#   HARD-FSH-06 entry is kept in the inventory for
#   historical reference; the effective behavior is now
#   delivered by FSH-12.
#
# ------------------------------------------------------------
# Original post-audit corrections:
# ------------------------------------------------------------
#
#   🔧 FSH-1 — `write_manifest` now produces the SAME JSON
#     shape as customize.sh (including the `root_solution`
#     field).
#
#   🔧 FSH-2 — `copy_with_context` now redirects cp's stderr
#     to $LOG_FILE and logs a failure line via `log_fn`.
#
#   🔧 FSH-3 — `init_runtime_paths` now sets PROGRESS_FILE to
#     `$RUN_DIR/update_progress.txt` when run/ is usable.
#
#   🔧 FSH-4 — `cleanup_old_transactions` declares `_txn` and
#     `_state` as `local`.
#
#   🔧 FSH-5 — `backup_user_files` declares `local ts` at the
#     top of the function.
#
#   🔧 FSH-6 — `ensure_backup_dir` applies chmod 0700 even when
#     the backup root already exists.
#
#   🔧 FSH-7 — The doc table inside `verify_backup_integrity`
#     matches the actual return values.
#
#   🔧 FSH-9 — `backup_user_files` and `auto_backup_if_needed`
#     pass `${MODULE_VERSION:-unknown}` as the manifest version.
#
#   🔧 FSH-10 — Default snapshot directory names now include the
#     caller PID (`-$$`). Mirrors the identical fix in
#     `customize.sh` (BUG-CS-C) and in `main.go` (BUG-E).
#
#   🔧 FSH-11 — New `get_watchdog_token()` helper reads the
#     token file generated by `customize.sh` or `main.go`.
#
# ------------------------------------------------------------
# Hardening fixes (HARD-FSH-01 … HARD-FSH-11):
# ------------------------------------------------------------
#
#   🛡️ HARD-FSH-01 — `write_manifest` now escapes JSON special
#     characters in the `source` field (parity with the
#     identical fix in customize.sh HARD-CS-05). A `json_escape`
#     helper is defined once and reused.
#
#   🛡️ HARD-FSH-02 — The iptables/ip6tables fallback DNAT path
#     now installs RETURN rules for loopback and bootstrap
#     addresses, matching the Custom-Chain path. Without them,
#     dnscrypt-proxy's own bootstrap queries would be DNAT'd
#     back into itself, forming a resolver loop.
#
#   🛡️ HARD-FSH-03 — `verify_backup_integrity` logs a warning
#     when 0 user files are present, so the caller sees why the
#     function returned 1 instead of a silent failure.
#
#   🛡️ HARD-FSH-04 — `get_watchdog_token` prefers the
#     `$WATCHDOG_TOKEN_FILE` variable (already set by
#     `init_runtime_paths`) when available, falling back to
#     `run_file .watchdog_token` only if it is unset.
#
#   🛡️ HARD-FSH-05 — `is_dnscrypt_running` cross-checks the PID
#     file and verifies the PID's `comm` is exactly
#     `dnscrypt-proxy` before falling back to `pgrep -x`.
#
#   🛡️ HARD-FSH-06 — (see FSH-12 for the real implementation)
#     Historical: `_load_bootstrap_from_cache` was supposed to
#     require the cache file to be a regular file (not a
#     symlink or special file). The original code duplicated
#     the `-f` check, so it did NOT reject symlinks. FSH-12
#     replaces the duplicate with an explicit `-L` rejection.
#
#   🛡️ HARD-FSH-07 — `get_dynamic_bootstrap` bounds the number
#     of extracted addresses (MAX 32) so a malformed TOML
#     cannot produce an unbounded firewall rule set.
#
#   🛡️ HARD-FSH-08 — `_LOG_CALL_COUNT` is documented as an
#     intentional global that persists across `log_fn` calls.
#     It gates the emergency-only 50 MB rotation (every 100th
#     call).
#
#   🛡️ HARD-FSH-09 — `cleanup_proxy` now removes the `.tmp`
#     sidecar that a crashed `write_progress` may have left
#     behind.
#
#   🛡️ HARD-FSH-10 — `rotate_backups` refuses to prune when the
#     backup directory is not readable. Silent skips are now
#     logged.
#
#   🛡️ HARD-FSH-11 — `auto_backup_if_needed` now checks that
#     the resulting snapshot directory is a real directory
#     before touching the `.last_auto_backup` marker.
#
# ------------------------------------------------------------
# NEW corrections in this revision (FSH-12 … FSH-15):
# ------------------------------------------------------------
#
#   🔧 FSH-12 — `_load_bootstrap_from_cache` now ACTUALLY
#     rejects symlinks. The previous implementation performed
#     the same `[ ! -f "$file" ]` test twice, which follows
#     symlinks and returns true for a regular target. The
#     second test now uses `[ -L "$file" ]`, which detects a
#     symlink itself (regardless of its target).
#
#   🔧 FSH-13 — `auto_backup_if_needed` previously ran both
#     `: > "$marker"` and `touch "$marker"`. The first already
#     creates the file and updates its mtime; the second is
#     redundant. Only `touch` remains, since it expresses the
#     intent ("update the marker") more directly.
#
#   🔧 FSH-14 — `restore_user_files` now performs the same
#     critical-file strictness check that customize.sh
#     introduced as CSH-15. A restore failure of `webui.conf`
#     or `dnscrypt-proxy.toml` is treated as a critical
#     failure and returns non-zero immediately, so callers
#     (main.go, service.sh) can abort or retry without
#     silently leaving the user without their configured
#     WebUI port / credentials.
#
#   🔧 FSH-15 — `get_watchdog_token` now rejects a token file
#     that exists but is not a regular file (symlink, FIFO,
#     device node). This mirrors the FSH-12 hardening on the
#     bootstrap cache, and closes a theoretical vector where
#     a compromised run/ directory could redirect the token
#     read to an attacker-controlled path.
#
# ============================================================
# POSIX note on `local`:
#   This library uses `local` for all internal variables. The
#   `local` keyword is supported by:
#     • mksh (the default /system/bin/sh on modern Android)
#     • busybox ash (older Android)
#     • bash, dash, ksh
#   It is NOT part of the POSIX sh standard, but every shell
#   Android ships supports it.
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
#   • main.go             → MONITORING_UI_PORT
#   • functions.sh        → _MONITORING_UI_PORT (this file)
#   • customize.sh        → _MONITORING_UI_PORT
#   • action.sh           → _MONITORING_UI_PORT
#   • status.sh           → _MONITORING_UI_PORT
#   • service.sh          → (via functions.sh)
#   • watchdog.sh         → (uses TOML directly)
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

    # FSH-3 fix: match main.go's initPaths() — prefer run/ for
    # PROGRESS_FILE when the run directory is usable.
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

    export LOG_FILE PROGRESS_FILE STATUS_FILE PID_FILE WEBUI_PID_FILE WATCHDOG_PID_FILE
    export WATCHDOG_TOKEN_FILE
    export RUN_DIR_ACTIVE="$rd"
}

init_runtime_paths

# --- Fixed paths ---
TOML_FILE="$MODDIR/proxy/dnscrypt-proxy.toml"
WEBUI_CONF="$MODDIR/proxy/webui.conf"
SELECTED_PROFILE_FILE="$MODDIR/proxy/selected_profile.txt"

# --- v1.2.0 — Data preservation paths ---
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# --- Firewall cache variables ---
_FW_CACHE=""
_FW_CACHE_TIME=0

# ============================================================
# [3b] HARD-FSH-01 — JSON escape helper
# ============================================================
# Minimal JSON string escaper. Escapes backslash and double
# quote, and drops C0 control characters. Used by write_manifest
# for the `source` field, which is the only user-controllable
# string in the manifest.
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\000-\010\013\014\016-\037'
}

# ============================================================
# [4] Read bootstrap_resolvers from TOML
# ============================================================
# HARD-FSH-07: bound the number of extracted addresses so a
# malformed TOML cannot produce an unbounded firewall rule set.
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
    | head -n 32 \
    | tr '\n' ' '
}

# ============================================================
# [5] Load BOOTSTRAP_IPS (with cache)
# ============================================================
_BOOTSTRAP_CACHE_FILE="$MODDIR/proxy/run/.bootstrap_cache"
_BOOTSTRAP_CACHE_TTL=300  # 5 minutes

# ------------------------------------------------------------
# FSH-12 fix — REAL symlink rejection.
#
# The previous implementation performed the SAME `[ ! -f ... ]`
# test twice. `[ -f ]` follows symlinks and returns true if the
# final target is a regular file, so a symlink pointing to a
# regular file would have passed both checks. The second check
# is now an explicit `[ -L ]`, which returns true when the path
# itself is a symlink — regardless of what it points to.
#
# HARD-FSH-06 (documented) is now actually delivered by FSH-12.
# ------------------------------------------------------------
_load_bootstrap_from_cache() {
    # Reject non-existent paths and non-regular files.
    if [ ! -f "$_BOOTSTRAP_CACHE_FILE" ]; then
        return 1
    fi

    # Reject symlinks. `[ -L ]` is true when the path is a
    # symlink, even if its target exists and is a regular file.
    if [ -L "$_BOOTSTRAP_CACHE_FILE" ]; then
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

    # Reject anything that does not look like a space-separated
    # list of IP addresses. The regex accepts digits, dots,
    # colons, hex letters, and spaces — nothing else.
    if printf '%s' "$cached" | grep -qE '[^0-9a-fA-F.:[:space:]]'; then
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
# The WebUI (main.go) owns orderly rotation at 1 MB. This helper
# only rotates when the log exceeds 50 MB — that is an emergency
# threshold, not a routine one.
#
# HARD-FSH-08: `_LOG_CALL_COUNT` is an intentional GLOBAL. It
# persists across all `log_fn` calls within the same shell
# process and is the counter that gates the emergency rotation
# (which runs every 100th call). It is not declared `local`
# because it must survive across function invocations.
_LOG_CALL_COUNT=0

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
# [9b] Profile memory hint (v1.1.0)
# ============================================================
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
# Reads ONLY from [monitoring_ui]. Section tracking ignores any
# username/password in other sections.
#
# Supports section header with trailing comment:
#     [monitoring_ui] # monitoring section
#
# v1.0.0 fix: the pattern is extracted between the first [ and ].
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
# HARD-FSH-05: cross-check the PID file first and verify the
# PID's comm is exactly `dnscrypt-proxy`. This is the runtime
# analogue of main.go BUG-J and avoids false positives after
# PID reuse.
is_dnscrypt_running() {
    # Preferred check: PID file + comm match.
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

    # Fallback: exact-name pgrep + port check.
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
_LEGACY_CLEANUP_IPTABLES_DONE=0

_legacy_cleanup_iptables() {
    [ "$_LEGACY_CLEANUP_IPTABLES_DONE" = "1" ] && return 0
    _LEGACY_CLEANUP_IPTABLES_DONE=1

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
#
# HARD-FSH-02: In the fallback path the same RETURN rules used
# inside the Custom Chain are installed in OUTPUT before the
# DNAT rules. Without them, dnscrypt-proxy's own bootstrap
# queries would be DNAT'd back into itself.
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

    # Also clean up any leftover RETURN rules from a previous
    # fallback install (HARD-FSH-02).
    local _c_ip
    for _c_ip in $LOOPBACK_IPS $BOOTSTRAP_IPS; do
        case "$_c_ip" in *:*) continue ;; esac
        iptables -t nat -D OUTPUT -d "$_c_ip" -p udp --dport 53 \
            -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null
        iptables -t nat -D OUTPUT -d "$_c_ip" -p tcp --dport 53 \
            -j RETURN -m comment --comment "$comment" --wait 5 2>/dev/null
    done

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

        # Insert DNAT rules at the top first, then push them
        # down with the RETURN rules (so RETURN comes BEFORE
        # DNAT in the chain — matching the Custom Chain order).
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

        # HARD-FSH-02: now push the RETURN rules ABOVE the DNAT
        # rules, in reverse iteration order so that the final
        # chain reads exactly like the Custom Chain (RETURNs on
        # top, catch-all DNAT at the bottom).
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
            log_fn "⚠️ iptables: some RETURN rules failed to insert (fallback continues)"
        fi

        log_fn "✅ iptables: direct DNAT applied (fallback mode)"
    fi

    return 0
}

# ============================================================
# [18] Hybrid ip6tables (IPv6)
# ============================================================
# HARD-FSH-02: same fallback-RETURN fix as IPv4.
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

    # Also clean up any leftover RETURN rules from a previous
    # fallback install (HARD-FSH-02).
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

        # HARD-FSH-02: push RETURN rules above the DNAT rules.
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

        log_fn "✅ ip6tables: direct DNAT applied (fallback)"
    fi

    return 0
}

# ============================================================
# [19] nftables management
# ============================================================
# Uses a single inet table that covers both IPv4 and IPv6. The
# final DNAT rule redirects all port-53 traffic (both families)
# to the IPv4 loopback resolver. dnscrypt-proxy listens on
# 127.0.0.1:5354 and accepts both families there.
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
# HARD-FSH-09: also remove the `.tmp` sidecar that a crashed
# `write_progress` may have left behind.
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

    # HARD-FSH-09: stale progress temp file.
    rm -f "${PROGRESS_FILE}.tmp" 2>/dev/null

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
# [25] v1.2.0 — SELinux-aware file copy
# ============================================================
# Copies a single file and preserves its SELinux context.
# Preference order:
#   1. restorecon — the canonical tool
#   2. chcon u:object_r:magisk_file:s0 — manual fallback
#   3. no-op — if neither tool is available
#
# Also applies chmod 0600 (owner-only), which is appropriate for
# every file in the data-preservation set.
#
# ⚠️ FSH-2 fix: this function and the one in customize.sh share
#    identical FUNCTIONAL behavior (copy + SELinux context +
#    chmod 0600). They differ in ONE respect: how a failed cp
#    is reported.
#      • customize.sh → appends cp's stderr to $INSTALL_LOG
#      • functions.sh → appends cp's stderr to $LOG_FILE
# ============================================================
copy_with_context() {
    local src="$1"
    local dst="$2"

    if ! cp -f "$src" "$dst" 2>>"$LOG_FILE"; then
        log_fn "❌ copy_with_context FAILED: $src → $dst"
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
# [25b] v1.2.0 — Watchdog token reader (FSH-11)
# ============================================================
# Reads the token file that main.go and customize.sh write to
# $RUN_DIR/.watchdog_token (mode 0600). Used by watchdog.sh to
# authenticate its POST /api/ensure_running_service call against
# the X-Watchdog-Token header check in main.go (BUG-B fix).
#
# The token is a 64-char hex string (256 bits). Both writers
# (customize.sh §[19b] and main.go:loadOrCreateWatchdogToken)
# persist it atomically so that no partial read can occur.
#
# HARD-FSH-04: prefer the $WATCHDOG_TOKEN_FILE variable set by
# `init_runtime_paths` (identical to main.go's path), falling
# back to a `run_file` lookup only if it is empty.
#
# FSH-15: reject a token file that is not a regular file
# (symlink, FIFO, device node). This mirrors the FSH-12
# hardening on the bootstrap cache. A compromised run/ directory
# could theoretically redirect the token read to an attacker-
# controlled path, and the `-L` test closes that vector.
#
# Return values:
#   0 — token read successfully; printed to stdout (no newline)
#   1 — token file missing, not a regular file, or empty
# ============================================================
get_watchdog_token() {
    local token_file=""

    if [ -n "$WATCHDOG_TOKEN_FILE" ]; then
        token_file="$WATCHDOG_TOKEN_FILE"
    else
        token_file="$(run_file .watchdog_token)"
    fi

    # FSH-15: must exist and be a regular file.
    [ -f "$token_file" ] || return 1

    # FSH-15: must NOT be a symlink.
    [ -L "$token_file" ] && return 1

    local tok
    tok=$(cat "$token_file" 2>/dev/null | tr -d '\r\n ')

    [ -n "$tok" ] || return 1
    [ "${#tok}" -ge 32 ] || return 1

    printf "%s" "$tok"
    return 0
}

# ============================================================
# [26] v1.2.0 — Persistent backup helpers
# ============================================================

# --- get_backup_dir ---
get_backup_dir() {
    printf "%s" "$PERSISTENT_BACKUP"
}

# --- ensure_backup_dir ---
# Creates the backup root if missing, and applies chmod 0700
# in ALL cases (FSH-6 fix).
#
# On Android, /sdcard is a FUSE mount that typically ignores
# chmod. The call is best-effort — the effective protection
# remains the per-file chmod 0600 applied by copy_with_context.
ensure_backup_dir() {
    if [ ! -d "$PERSISTENT_BACKUP" ]; then
        mkdir -p "$PERSISTENT_BACKUP" 2>/dev/null || return 1
    fi
    chmod 0700 "$PERSISTENT_BACKUP" 2>/dev/null || true
    return 0
}

# --- write_manifest <target_dir> <source> <count> [version] ---
# Writes a .manifest.json with metadata about the snapshot.
#
# HARD-FSH-01: the `source` field is JSON-escaped with the
# shared `json_escape` helper. Previously a source path
# containing a quote or backslash produced invalid JSON.
write_manifest() {
    local target_dir="$1"
    local source="$2"
    local count="$3"
    local version="${4:-${MODULE_VERSION:-unknown}}"

    local manifest="$target_dir/.manifest.json"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)

    # Detect root solution if not already known (best-effort).
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

    # HARD-FSH-01: escape the user-controllable string fields.
    local src_escaped
    src_escaped=$(json_escape "$source")
    local version_escaped
    version_escaped=$(json_escape "$version")
    local root_escaped
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

# ------------------------------------------------------------
# verify_backup_integrity <dir>
# ------------------------------------------------------------
# Validates every user file in the given directory:
#   • Non-empty
#   • Size < 10 MB
#   • SHA256 matches the manifest (when jq/awk/sha256 are available)
#
# Returns 0 if clean, 1 if any warnings were detected.
#
# HARD-FSH-03: when 0 user files are found, a warning is logged
# so the caller understands why the function returned 1.
# ============================================================
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

    # v1.2.0 STRICT: manifest and sha256sum are mandatory.
    if [ "$strict" = "1" ]; then
        if [ ! -f "$manifest" ]; then
            log_fn "⚠️ verify_backup: manifest missing: $manifest"
            return 1
        fi
        if [ "$has_sha" != "1" ]; then
            log_fn "⚠️ verify_backup: sha256sum unavailable — cannot verify"
            return 1
        fi
    fi

    # v1.2.0 STRICT: expected file count from the manifest.
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
            log_fn "⚠️ verify_backup: empty file: $f"
            errors=$((errors + 1))
            continue
        fi

        local size
        size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
        if [ -n "$size" ] && [ "$size" -gt 10485760 ]; then
            log_fn "⚠️ verify_backup: oversized file: $f ($size bytes)"
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

        # v1.2.0 STRICT: missing hash is an error in strict mode.
        if [ -z "$expected_sha" ]; then
            if [ "$strict" = "1" ]; then
                log_fn "⚠️ verify_backup: no SHA256 in manifest for: $f"
                errors=$((errors + 1))
            fi
            continue
        fi

        local actual_sha
        actual_sha=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')

        if [ "$actual_sha" != "$expected_sha" ]; then
            log_fn "⚠️ verify_backup: SHA256 mismatch: $f"
            log_fn "   expected: ${expected_sha:0:16}..."
            log_fn "   actual:   ${actual_sha:0:16}..."
            errors=$((errors + 1))
        fi
    done

    if [ "$checked" -eq 0 ]; then
        # HARD-FSH-03: explicit log so the caller is not confused
        # by a silent "1" return.
        log_fn "⚠️ verify_backup: no user files found in $dir"
        return 1
    fi

    # v1.2.0 STRICT: cross-check the count against the manifest.
    if [ "$strict" = "1" ] && [ "$manifest_count" -gt 0 ]; then
        if [ "$checked" -ne "$manifest_count" ]; then
            log_fn "⚠️ verify_backup: count mismatch — manifest=$manifest_count, checked=$checked"
            errors=$((errors + 1))
        fi
    fi

    # v1.2.0: always log the summary (observability).
    log_fn "ℹ️ verify_backup: checked=$checked errors=$errors in $(basename "$dir")"

    [ "$errors" -eq 0 ]
}

# ------------------------------------------------------------
# backup_user_files <src_dir> [dst_dir] [version]
# ------------------------------------------------------------
# Takes a snapshot of the 5 user files from <src_dir>.
#
# If <dst_dir> is provided, files are written directly there
# (used by the transaction system and by main.go). Otherwise,
# a new timestamped directory is created under $PERSISTENT_BACKUP.
#
# Returns 0 on success (>= 1 file copied), 1 on any failure.
#
# FSH-10: the default directory name now includes the caller PID.
#   Naming convention for the default path:
#     <YYYYMMDD>-<HHMMSS>-manual-<pid>
#
#   When main.go passes an explicit dst_dir, the name is:
#     <YYYYMMDD>-<HHMMSS>-manual-<pid>-<rand4>
# ------------------------------------------------------------
backup_user_files() {
    local src_dir="$1"
    local dst_dir="$2"
    local version="${3:-${MODULE_VERSION:-unknown}}"
    local ts

    [ -d "$src_dir" ] || {
        log_fn "❌ backup_user_files: source dir not found: $src_dir"
        return 1
    }

    if [ -z "$dst_dir" ]; then
        ensure_backup_dir || {
            log_fn "❌ backup_user_files: cannot create backup root"
            return 1
        }
        ts=$(date +%Y%m%d-%H%M%S)
        # FSH-10: include PID in the default name.
        dst_dir="$PERSISTENT_BACKUP/$ts-manual-$$"
    fi

    mkdir -p "$dst_dir" 2>/dev/null || {
        log_fn "❌ backup_user_files: cannot create target: $dst_dir"
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

    # Issue 4 fix: fail if 0 files were copied.
    if [ "$count" -eq 0 ]; then
        log_fn "❌ backup_user_files: 0 files copied from $src_dir"
        rm -rf "$dst_dir" 2>/dev/null
        return 1
    fi

    write_manifest "$dst_dir" "$src_dir" "$count" "$version"

    log_fn "✅ backup_user_files: $count file(s) → $dst_dir"
    return 0
}

# ------------------------------------------------------------
# restore_user_files <src_dir> [dst_dir]
# ------------------------------------------------------------
# Restores the 5 user files from <src_dir> into <dst_dir>
# (default: $MODDIR/proxy) with SELinux context preservation
# and per-file verification.
#
# Returns 0 if at least one file was successfully restored,
# 1 otherwise.
#
# FSH-14: critical-file strictness (parity with CSH-15).
#   A restore failure of `webui.conf` or `dnscrypt-proxy.toml`
#   is treated as a critical failure. The function returns
#   non-zero IMMEDIATELY (without waiting for the total failure
#   count to reach any threshold), so callers (main.go,
#   service.sh) can abort the current operation and preserve
#   the previous state. Without this check, a single silent
#   failure could leave the user without their configured
#   WebUI port or credentials.
# ------------------------------------------------------------
restore_user_files() {
    local src_dir="$1"
    local dst_dir="${2:-$MODDIR/proxy}"

    [ -d "$src_dir" ] || {
        log_fn "❌ restore_user_files: source dir not found: $src_dir"
        return 1
    }

    mkdir -p "$dst_dir" 2>/dev/null || {
        log_fn "❌ restore_user_files: cannot create target: $dst_dir"
        return 1
    }

    # Verify source integrity first (advisory)
    verify_backup_integrity "$src_dir" || {
        log_fn "⚠️ restore_user_files: source has integrity warnings (continuing)"
    }

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
                            log_fn "❌ restore_user_files: CRITICAL verify failure: $f"
                            ;;
                    esac
                fi
            else
                failed=$((failed + 1))
                case "$f" in
                    webui.conf|dnscrypt-proxy.toml)
                        critical_failed=1
                        log_fn "❌ restore_user_files: CRITICAL copy failure: $f"
                        ;;
                esac
            fi
        fi
    done

    # FSH-14: critical-file failure short-circuits.
    if [ "$critical_failed" = "1" ]; then
        log_fn "❌ restore_user_files: critical file(s) failed — aborting"
        return 1
    fi

    if [ "$failed" -gt 0 ]; then
        log_fn "⚠️ restore_user_files: $failed non-critical file(s) failed"
    fi

    if [ "$restored" -gt 0 ]; then
        log_fn "✅ restore_user_files: $restored file(s) ← $src_dir"
        return 0
    fi

    log_fn "❌ restore_user_files: no files restored from $src_dir"
    return 1
}

# ------------------------------------------------------------
# rotate_backups [keep_count]
# ------------------------------------------------------------
# Prunes the persistent backup directory to keep at most
# `keep_count` snapshots (default 21), preserving:
#   • current/      (live snapshot)
#   • txn-*/        (in-flight transactions)
#   • orphan-txn-*/ (preserved interrupted transactions)
#   • .last_stable  (pointer)
#   • .upgrade_history.json / .txt
#   • .last_auto_backup
#   • README.md
#
# Snapshots are sorted by DIRECTORY NAME (which starts with
# YYYYMMDD-HHMMSS-). This is stable across reboots and does not
# depend on mtimes.
#
# HARD-FSH-10: refuse to prune when the directory is not
# readable, and log the skip.
# ------------------------------------------------------------
rotate_backups() {
    local keep="${1:-21}"

    [ -d "$PERSISTENT_BACKUP" ] || return 0

    if [ ! -r "$PERSISTENT_BACKUP" ]; then
        log_fn "⚠️ rotate_backups: $PERSISTENT_BACKUP is not readable — skipping"
        return 0
    fi

    local snapshots
    # v1.2.0: skip empty / manifest-less snapshots
    # A snapshot is counted for retention only if it is non-empty
    # AND contains a .manifest.json. Partial/failed copies are
    # ignored so they do not displace valid snapshots.
    snapshots=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d */ 2>/dev/null | \
        sed 's:/$::' | \
        grep -E '^[0-9]{8}-[0-9]{6}-' | \
        while IFS= read -r _d; do
            [ -z "$(ls -A "$_d" 2>/dev/null)" ] && continue
            [ -f "$_d/.manifest.json" ] || continue
            printf '%s\n' "$_d"
        done | \
        sort -r)

    [ -z "$snapshots" ] && return 0

    local total
    total=$(printf '%s\n' "$snapshots" | wc -l | tr -d ' ')

    if [ "$total" -le "$keep" ]; then
        log_fn "ℹ️ rotate_backups: $total snapshot(s) — within limit ($keep)"
        return 0
    fi

    local to_remove=$((total - keep))
    log_fn "🧹 rotate_backups: removing $to_remove old snapshot(s) (keeping $keep)"

    printf '%s\n' "$snapshots" | tail -n "$to_remove" | while IFS= read -r old; do
        [ -z "$old" ] && continue
        rm -rf "$PERSISTENT_BACKUP/$old" 2>/dev/null
    done

    log_fn "✅ rotate_backups: done"
    return 0
}

# ------------------------------------------------------------
# get_last_backup_time
# ------------------------------------------------------------
# Returns the epoch mtime of .last_auto_backup, or 0 if the
# marker does not exist.
# ------------------------------------------------------------
get_last_backup_time() {
    local marker="$PERSISTENT_BACKUP/.last_auto_backup"

    if [ ! -f "$marker" ]; then
        printf "0"
        return 0
    fi

    local mtime
    mtime=$(stat -c %Y "$marker" 2>/dev/null) \
        || mtime=$(stat -f %m "$marker" 2>/dev/null) \
        || mtime=0

    printf "%s" "$mtime"
}

# ------------------------------------------------------------
# auto_backup_if_needed [interval_seconds]
# ------------------------------------------------------------
# Triggers a backup if the last one is older than
# `interval_seconds` (default 86400 = 24 hours).
#
# Uses $PERSISTENT_BACKUP/.last_auto_backup as the marker file.
# Called by service.sh on every boot (Layer 9).
#
# HARD-FSH-11: the marker is updated only after verifying that
# the target directory actually exists. A partial failure does
# not lock out the next attempt for 24 hours.
#
# FSH-13: the previous version ran both `: > "$marker"` and
#   `touch "$marker"`. The first already creates the file and
#   updates its mtime; the second was redundant. Only `touch`
#   remains, since it expresses the intent ("update the marker")
#   directly.
# ------------------------------------------------------------
auto_backup_if_needed() {
    local interval="${1:-86400}"

    # Validate interval is numeric
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
        log_fn "ℹ️ auto_backup: skipped (last was ${age}s ago, interval=${interval}s)"
        return 0
    fi

    log_fn "🔄 auto_backup: starting (age=${age}s, interval=${interval}s)"

    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    # FSH-10: include PID in the target name.
    local target="$PERSISTENT_BACKUP/$ts-auto-$$"

    if backup_user_files "$src_dir" "$target"; then
        # HARD-FSH-11: verify the target actually exists before
        # advancing the marker. A silent failure here would push
        # the next attempt 24 hours into the future.
        if [ -d "$target" ]; then
            # FSH-13: single touch — the redundant `: >` was
            # removed. `touch` creates the file if missing and
            # updates its mtime otherwise, which is exactly the
            # marker semantics we need.
            touch "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null || true
        else
            log_fn "⚠️ auto_backup: target dir missing after backup — marker not updated"
            return 1
        fi

        # Rotate to keep the total bounded
        rotate_backups 21

        log_fn "✅ auto_backup: complete → $target"
        return 0
    fi

    log_fn "❌ auto_backup: failed"
    return 1
}

# ------------------------------------------------------------
# cleanup_old_transactions
# ------------------------------------------------------------
# Removes COMMIT'd txn-* directories from previous installs.
#
# The transaction system (customize.sh Layer 4) creates:
#   $PERSISTENT_BACKUP/txn-<timestamp>-<pid>/
#     ├── .state    — "START" | "COMMIT" | "ROLLBACK"
#     ├── .pid      — installer PID
#     └── <files>   — snapshot for rollback
#
# ROLLBACK and START transactions are PRESERVED — they may
# contain the only copy of a user's data if an install was
# interrupted mid-flight.
#
# FSH-4 fix: `_txn` and `_state` are declared `local`.
# ------------------------------------------------------------
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
        log_fn "✅ cleanup_old_transactions: removed $_removed COMMIT'd txn(s)"
    fi

    return 0
}