#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – action.sh
# Version: v1.2.0 (Global Edition)
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Magisk / KernelSU "Action" button handler.
#
#   Modes:
#     action.sh                Start WebUI + open browser
#     action.sh --restart      Force restart WebUI
#     action.sh --status       Show WebUI status only
#     action.sh --check        Comprehensive status (see below)
#     action.sh --diagnose     Run full diagnostic report (v1.2.0)
#     action.sh --backup       Trigger an immediate backup (v1.2.0)
#     action.sh --help         Show help
#
# Exit codes:
#   0 = success
#   1 = error (startup failed)
#   2 = module disabled
#   3 = backup failed (--backup only)
#
# Notes:
#   • Loads functions.sh if available, otherwise uses inline fallbacks.
#   • The version is read dynamically from module.prop (not hardcoded).
#   • Port Guard: rejects port 8080 (reserved for monitoring_ui).
#
# v1.1.0 additions (kept):
#   • --check reports the active profile + expected memory hint
#   • Structured --check output with clear sections
#   • Fallback for get_profile_memory_hint if functions.sh is missing
#
# v1.2.0 additions:
#   • --diagnose: delegates to status.sh --diagnose
#   • --backup: triggers an immediate manual backup
#   • --check: new "Backup & Recovery" section
#
# v1.2.0 — POST-AUDIT FIXES (still v1.2.0)
# ============================================================
#   🔧 ACT-1 — `_inline_backup_now` writes a .manifest.json
#     with the same shape as functions.sh:write_manifest.
#   🔧 ACT-2 — `_inline_backup_now` applies chmod 0700
#     unconditionally (matches FSH-6 in functions.sh).
#   🔧 ACT-3 — `--diagnose` honors the shebang when possible.
#   🔧 ACT-4 — `--help` reflects the real --check output.
#   🔧 ACT-5 — `_inline_backup_now` uses `<ts>-manual-$$`.
#
# ============================================================
# v1.2.0 (Global Edition) — Additional hardening
# ============================================================
#   🛡️ HARD-ACT-01 — `_inline_backup_now` now JSON-escapes the
#     `source`, `version`, and `root_solution` fields via a
#     shared `_act_json_escape` helper. Parity with
#     HARD-CS-05 (customize.sh) and HARD-FSH-01 (functions.sh).
#     Without escaping, a path containing a quote or backslash
#     would produce an invalid manifest that any consumer
#     (customize.sh:read_source_version, verify_backup_integrity,
#     jq-based tooling) would silently mis-parse.
#
#   🛡️ HARD-ACT-02 — `_inline_backup_summary` declares `local
#     age` at the top of the function. Previously it declared
#     `local age` inside a nested `if` block, which works in
#     mksh/busybox but is fragile and confusing. The variable
#     is now declared with the other locals.
#
#   🛡️ HARD-ACT-03 — `_inline_backup_now` had a no-op line:
#       `[ "$ver_for_manifest" = "unknown" ] && ver_for_manifest="unknown"`
#     Removed. It was a tautology and could confuse shellcheck.
#
#   🛡️ HARD-ACT-04 — The `--backup` mode now prints a
#     normalized success line REGARDLESS of which backend was
#     used. Previously, when `functions.sh:backup_user_files`
#     handled the backup, it logged to the log file only and
#     produced NO stdout output, so the user saw nothing
#     between "Source: ..." and "Current backup state: ...".
#     The fallback path printed a "✅ Backup created" line, so
#     the two paths were visually inconsistent. Both paths now
#     produce the same user-facing confirmation.
#
#   🛡️ HARD-ACT-05 — Section [18] "Try 5" used the unusual
#     form `if timeout 5 am start ... & then`. In POSIX sh the
#     `&` in a condition part always makes the `if` succeed,
#     which happened to work but was confusing. Rewritten as an
#     explicit fire-and-forget with a clear comment so the
#     intent (best-effort, no exit-code check) is obvious.
#
#   🛡️ HARD-ACT-06 — `_inline_read_port` now performs the
#     numeric range check with a leading-zero-safe comparison.
#     Previously, a value like "090" would be interpreted as
#     octal by `[ "$val" -ge 1 ]` in some shells, and the
#     resulting value would be wrong. The check now strips
#     leading zeros before the arithmetic comparison.
#
#   🛡️ HARD-ACT-07 — `_inline_backup_summary` now returns a
#     distinct, unambiguous string for each state so callers
#     can rely on the text:
#       • "not initialized"  — backup dir missing
#       • "no snapshots yet" — dir exists, no snapshots
#       • "<N> snapshot(s), latest <age>" — snapshots exist
#     The old code had a branch where the age could be missing
#     and the string would end in "latest " with a trailing
#     space. Fixed.
#
#   🛡️ HARD-ACT-08 — `_inline_backup_now` now writes the
#     manifest ONLY after confirming that at least one file was
#     copied. Combined with the existing failure path (rm -rf
#     the target on 0 files), this guarantees that any snapshot
#     directory that survives on disk has a manifest with
#     `files_count > 0`.
#
# ============================================================
# v1.2.0 (Global Edition) — New post-audit fixes
# ============================================================
#   🛡️ ACT-M1 — `_inline_is_port_open` now includes a
#     `netstat` fallback (parity with service.sh HARD-SVC-03,
#     watchdog.sh HARD-WD-02, and functions.sh).
#
#   🛡️ ACT-M2 — `_inline_read_port` leading-zero handling is
#     now documented as the canonical implementation and will
#     be mirrored into functions.sh so that all consumers
#     (status.sh, main.go) benefit from the same fix.
#
#   🛡️ ACT-M3 — Snapshot naming convention is now explicitly
#     documented: shell uses `<ts>-manual-<pid>`, main.go uses
#     `<ts>-manual-<pid>-<rand4>`. No conflict because main.go
#     passes an explicit `dst_dir` to `backup_user_files`.
#
#   🛡️ ACT-L1 — `local_pid` / `local_i` renamed to `_act_pid`
#     and `_act_i` to make it clear they are global variables
#     in the top-level scope (no `local` keyword available).
#
#   🛡️ ACT-L2 — `_txn_count` and `_orphan_count` now go
#     through a numeric-validation guard before being printed,
#     matching the pattern used in status.sh.
#
#   🛡️ ACT-L3 — `--check` prefers `is_dnscrypt_running` when
#     available (already implemented in the code, but the
#     fallback path is now clearly documented).
#
#   🛡️ ACT-L4 — `--help` now mentions that `--check` always
#     returns 0 (informational only).
#
#   🛡️ ACT-L5 — Removed the unexplained `sleep 1` after the
#     fire-and-forget browser launch in Try 5.
#
#   🛡️ ACT-L6 — `_inline_rotate_backups` now emits a log line
#     on success, matching the canonical `functions.sh` version.
#
# Coordination with main.go:
#   • The constant _MONITORING_UI_PORT below MUST stay in sync
#     with MONITORING_UI_PORT in main.go.
#   • The memory hint is DISPLAY-ONLY. main.go remains the
#     authority for the actual debug.SetMemoryLimit() value.
#   • Backup directory is /sdcard/dnscrypt-webui-backup/ (v1.2.0).
#
# ============================================================
# POSIX note on `local`:
#   This script uses `local` for all internal variables. The
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

# v1.2.0: --version flag (checked before any argument parsing)
case "${1:-}" in
	--version)
		echo "$0: v1.2.0"
		exit 0
		;;
esac

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

# --- v1.2.0 — Data preservation paths ---
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"
LAST_AUTO_BACKUP_MARKER="$PERSISTENT_BACKUP/.last_auto_backup"
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# --- v1.2.0 — Recovery mode trigger files ---
RECOVERY_TRIGGER_1="$MODDIR/recovery"
RECOVERY_TRIGGER_2="/data/adb/dnscrypt-recovery"

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

# ------------------------------------------------------------
# _act_json_escape (HARD-ACT-01)
# ------------------------------------------------------------
# Minimal JSON string escaper. Escapes backslash and double
# quote, and drops C0 control characters. Parity with the
# identical helpers in customize.sh (HARD-CS-05) and
# functions.sh (HARD-FSH-01).
# ------------------------------------------------------------
_act_json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\000-\010\013\014\016-\037'
}

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

# ------------------------------------------------------------
# _inline_is_port_open
# ------------------------------------------------------------
# Checks whether a TCP/UDP port is listening.
#
# ACT-M1: Added `netstat` fallback for parity with
# service.sh (HARD-SVC-03), watchdog.sh (HARD-WD-02), and
# functions.sh.
# ------------------------------------------------------------
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
        elif command -v netstat >/dev/null 2>&1; then
            netstat -lun 2>/dev/null | grep -q ":$port " && return 0
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
# HARD-ACT-06: leading-zero-safe numeric comparison.
# A value like "090" would be treated as octal by `[ -ge ]`
# in some shells. The check now:
#   1. Verifies the string is digits-only.
#   2. Strips leading zeros before arithmetic.
#
# ACT-M2: This is now the canonical implementation. It will
# be mirrored into functions.sh so that all consumers
# (status.sh, main.go) benefit from the same fix.
# ------------------------------------------------------------
_inline_read_port() {
    local conf="$1"
    local key="${2:-PORT}"
    local default="$3"
    local val
    val=$(_inline_read_conf "$conf" "$key" "$default")

    # Digits-only gate
    if ! echo "$val" | grep -qE '^[0-9]+$'; then
        printf "%s" "$default"
        return 0
    fi

    # Strip leading zeros (HARD-ACT-06).
    local val_clean
    val_clean=$(printf '%s' "$val" | sed 's/^0*//')
    [ -z "$val_clean" ] && val_clean="0"

    if [ "$val_clean" -ge 1 ] && [ "$val_clean" -le 65535 ]; then
        # Port Guard
        if [ "$val_clean" = "$_MONITORING_UI_PORT" ]; then
            printf "%s" "$default"
            return 0
        fi
        printf "%s" "$val_clean"
        return 0
    fi
    printf "%s" "$default"
}

# ------------------------------------------------------------
# _inline_get_profile_memory_hint (v1.1.0, self-contained)
# ------------------------------------------------------------
# Returns a user-facing string describing the expected soft
# memory limit for the active profile.
#
# ⚠️ This is a HINT only. main.go is the authority.
#
# Uses the same table as:
#   • functions.sh:get_profile_memory_hint
#   • main.go:memoryLimitForProfile
#   • customize.sh [21]
#   • watchdog.sh:_wd_get_profile_memory_hint
#
# Table:
#   light    →  80 MB
#   normal   → 100 MB
#   pro      → 120 MB
#   proplus  → 160 MB
#   ultimate → 220 MB
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

# ------------------------------------------------------------
# _inline_backup_summary (v1.2.0)
# ------------------------------------------------------------
# Returns a one-line summary of the backup state:
#   "5 snapshot(s), latest 2h ago"      — backups exist
#   "no snapshots yet"                  — dir exists but empty
#   "not initialized"                   — dir missing
#
# HARD-ACT-02: `local age` is declared with the other locals.
# HARD-ACT-07: the returned string is unambiguous; no trailing
#              space when the age cannot be computed.
# ------------------------------------------------------------
_inline_backup_summary() {
    [ -d "$PERSISTENT_BACKUP" ] || {
        printf "not initialized"
        return
    }

    local count
    count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d */ 2>/dev/null | \
        sed 's:/$::' | \
        grep -E '^[0-9]{8}-[0-9]{6}-' | \
        wc -l | tr -d ' ')

    if [ -z "$count" ] || [ "$count" -eq 0 ]; then
        printf "no snapshots yet"
        return
    fi

    # Newest snapshot name (sorted by directory name)
    local newest
    newest=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d */ 2>/dev/null | \
        sed 's:/$::' | \
        grep -E '^[0-9]{8}-[0-9]{6}-' | \
        sort -r | \
        head -n1)

    # Age of newest
    local epoch age now age_str
    epoch=$(stat -c %Y "$PERSISTENT_BACKUP/$newest" 2>/dev/null) \
        || epoch=$(stat -f %m "$PERSISTENT_BACKUP/$newest" 2>/dev/null) \
        || epoch=0

    # Numeric validation
    if ! echo "$epoch" | grep -qE '^[0-9]+$'; then
        epoch=0
    fi

    age_str="unknown time"
    if [ "$epoch" -gt 0 ]; then
        now=$(date +%s 2>/dev/null)
        case "$now" in
            ''|*[!0-9]*) now=0 ;;
        esac

        if [ "$now" -gt 0 ]; then
            age=$((now - epoch))
            if [ "$age" -lt 60 ]; then
                age_str="${age}s ago"
            elif [ "$age" -lt 3600 ]; then
                age_str="$((age / 60))m ago"
            elif [ "$age" -lt 86400 ]; then
                age_str="$((age / 3600))h ago"
            else
                age_str="$((age / 86400))d ago"
            fi
        fi
    fi

    printf "%s snapshot(s), latest %s" "$count" "$age_str"
}

# ------------------------------------------------------------
# _inline_backup_now (v1.2.0)
# ------------------------------------------------------------
# Manual backup trigger used by --backup when functions.sh
# does not provide backup_user_files.
#
# HARD-ACT-01: JSON escaping on manifest string fields.
# HARD-ACT-03: removed the dead `[ ... ] && ...` tautology.
# HARD-ACT-08: manifest is written only after >= 1 file copied.
#
# ACT-M3: Naming convention is `<ts>-manual-<pid>`. main.go
# uses `<ts>-manual-<pid>-<rand4>` but passes an explicit
# `dst_dir` to `backup_user_files`, so there is no conflict.
# ------------------------------------------------------------
_inline_backup_now() {
    local src_dir="$MODDIR/proxy"
    [ -d "$src_dir" ] || {
        echo "❌ Source directory not found: $src_dir"
        return 1
    }

    mkdir -p "$PERSISTENT_BACKUP" 2>/dev/null || {
        echo "❌ Cannot create backup directory"
        return 1
    }
    # ACT-2 fix: apply chmod 0700 unconditionally (matches
    # functions.sh:ensure_backup_dir after FSH-6). On /sdcard
    # FUSE this is usually a no-op — the effective protection
    # remains per-file chmod 0600 below.
    chmod 0700 "$PERSISTENT_BACKUP" 2>/dev/null

    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    # ACT-5 fix: append `-$$` so the naming convention matches
    # functions.sh:backup_user_files (after FSH-10) and so that
    # two concurrent `--backup` invocations in the same second
    # cannot collide.
    local target="$PERSISTENT_BACKUP/$ts-manual-$$"

    mkdir -p "$target" 2>/dev/null || {
        echo "❌ Cannot create snapshot directory"
        return 1
    }

    local count=0
    local f
    for f in $USER_FILES; do
        if [ -f "$src_dir/$f" ] && [ -s "$src_dir/$f" ]; then
            if cp -f "$src_dir/$f" "$target/$f" 2>/dev/null; then
                if command -v restorecon >/dev/null 2>&1; then
                    restorecon "$target/$f" 2>/dev/null || true
                elif command -v chcon >/dev/null 2>&1; then
                    chcon u:object_r:magisk_file:s0 "$target/$f" 2>/dev/null || true
                fi
                chmod 0600 "$target/$f" 2>/dev/null
                count=$((count + 1))
            fi
        fi
    done

    # v1.2.0 FIX: fail if 0 files were copied (HARD-ACT-08).
    if [ "$count" -eq 0 ]; then
        echo "❌ No files copied (source may be empty)"
        rm -rf "$target" 2>/dev/null
        return 1
    fi

    # ACT-1 fix: write .manifest.json with the same shape as
    # functions.sh:write_manifest. Fields:
    #   version, timestamp, source, root_solution,
    #   files_count, files[]
    local manifest="$target/.manifest.json"
    local files_json=""
    local sha
    for f in $USER_FILES; do
        if [ -f "$target/$f" ]; then
            sha=""
            if command -v sha256sum >/dev/null 2>&1; then
                sha=$(sha256sum "$target/$f" 2>/dev/null | awk '{print $1}')
            fi
            files_json="$files_json{\"name\":\"$f\",\"sha256\":\"$sha\"},"
        fi
    done
    files_json="${files_json%,}"

    # Root-solution detection (best-effort).
    local root_sol="unknown"
    if [ -n "${KSU_VER:-}" ] || [ -d "/data/adb/ksu" ]; then
        root_sol="kernelsu"
    elif [ -n "${APATCH:-}" ] || [ -d "/data/adb/ap" ]; then
        root_sol="apatch"
    elif [ -n "${MAGISK_VER_CODE:-}" ] || [ -d "/data/adb/magisk" ]; then
        root_sol="magisk"
    fi

    # HARD-ACT-01: JSON-escape the string fields.
    local src_escaped version_escaped root_escaped
    src_escaped=$(_act_json_escape "$src_dir")
    version_escaped=$(_act_json_escape "$VERSION")
    root_escaped=$(_act_json_escape "$root_sol")

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

    echo "✅ Backup created: $target ($count file(s))"
    return 0
}

# ------------------------------------------------------------
# _inline_rotate_backups (v1.2.0)
# ------------------------------------------------------------
# Fallback used by --backup if functions.sh does not provide
# rotate_backups. Matches the canonical version.
#
# ACT-L6: now emits a log line on success, matching
# functions.sh:rotate_backups.
# ------------------------------------------------------------
_inline_rotate_backups() {
    local keep="${1:-21}"

    # Numeric validation
    if ! echo "$keep" | grep -qE '^[0-9]+$'; then
        keep=21
    fi

    [ -d "$PERSISTENT_BACKUP" ] || return 0

    local snapshots
    snapshots=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d */ 2>/dev/null | \
        sed 's:/$::' | \
        grep -E '^[0-9]{8}-[0-9]{6}-' | \
        sort -r)

    [ -z "$snapshots" ] && return 0

    local total
    total=$(printf '%s\n' "$snapshots" | wc -l | tr -d ' ')

    if [ "$total" -le "$keep" ]; then
        return 0
    fi

    local to_remove=$((total - keep))

    printf '%s\n' "$snapshots" | tail -n "$to_remove" | while IFS= read -r old; do
        [ -z "$old" ] && continue
        rm -rf "$PERSISTENT_BACKUP/$old" 2>/dev/null
    done

    log_msg "✅ rotate_backups (inline): done"
    return 0
}

# ============================================================
# [6] Display help
# ============================================================
show_help() {
    cat << EOF
DNSCrypt Smart Filter – action.sh ${VERSION}

Usage:
  action.sh                Start WebUI and open browser
  action.sh --restart      Force restart WebUI
  action.sh --status       Show WebUI status only
  action.sh --check        Comprehensive status: DNS + WebUI +
                             config + profile/memory + backup/recovery
  action.sh --diagnose     Run full diagnostic report (delegates to
                             status.sh --diagnose)
  action.sh --backup       Trigger an immediate manual backup
  action.sh --help         Show this help

Exit codes:
  0 = success (also used by --check, which is informational only)
  1 = error (startup failed)
  2 = module disabled
  3 = backup failed (--backup only)

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

    # v1.2.0 — backup wrappers
    if command -v backup_user_files >/dev/null 2>&1; then
        do_backup_now()  { backup_user_files "$MODDIR/proxy"; }
    else
        do_backup_now()  { _inline_backup_now; }
    fi

    if command -v rotate_backups >/dev/null 2>&1; then
        do_rotate_backups() { rotate_backups "${1:-21}"; }
    else
        do_rotate_backups() { _inline_rotate_backups "${1:-21}"; }
    fi

    backup_summary()     { _inline_backup_summary; }
else
    _FB_RUN_DIR=$(_fallback_get_run_dir)
    WEBUI_PID_FILE="$_FB_RUN_DIR/webui.pid"
    WATCHDOG_PID_FILE="$_FB_RUN_DIR/watchdog.pid"
    STATUS_FILE="$_FB_RUN_DIR/dnscrypt.status"

    is_port_listening()  { _inline_is_port_open "$1" "${2:-tcp}"; }
    get_port()           { _inline_read_port "$1" "PORT" "9090"; }
    read_conf()          { _inline_read_conf "$1" "$2" "$3"; }
    get_mem_hint()       { _inline_get_profile_memory_hint; }
    do_backup_now()      { _inline_backup_now; }
    do_rotate_backups()  { _inline_rotate_backups "${1:-21}"; }
    backup_summary()     { _inline_backup_summary; }
fi

# ============================================================
# [9] Parse command-line arguments
# ============================================================
FORCE_RESTART=0
STATUS_ONLY=0
CHECK_MODE=0
DIAGNOSE_MODE=0
BACKUP_MODE=0

for arg in "$@"; do
    case "$arg" in
        --restart)   FORCE_RESTART=1 ;;
        --status)    STATUS_ONLY=1 ;;
        --check)     CHECK_MODE=1 ;;
        --diagnose)  DIAGNOSE_MODE=1 ;;
        --backup)    BACKUP_MODE=1 ;;
        --help|-h)   show_help ;;
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
# [12] Path 2: v1.2.0 — diagnose mode (--diagnose)
# ============================================================
# Delegates to status.sh --diagnose, which produces a full
# report (system info, user data files, backups, health).
#
# ACT-3: honors the script's shebang when possible.
# ============================================================
if [ "$DIAGNOSE_MODE" = "1" ]; then
    STATUS_SCRIPT="$MODDIR/status.sh"

    if [ -f "$STATUS_SCRIPT" ]; then
        if [ ! -x "$STATUS_SCRIPT" ]; then
            chmod 0755 "$STATUS_SCRIPT" 2>/dev/null || true
        fi

        if [ -x "$STATUS_SCRIPT" ]; then
            exec "$STATUS_SCRIPT" --diagnose
        else
            # Fallback: read-only fs or chmod failed
            exec sh "$STATUS_SCRIPT" --diagnose
        fi
    else
        echo "⚠️ status.sh not found — falling back to --check mode"
        echo "   Expected at: $STATUS_SCRIPT"
        echo ""
        # Fall through to check mode by continuing below
        CHECK_MODE=1
    fi
fi

# ============================================================
# [13] Path 3: v1.2.0 — backup mode (--backup)
# ============================================================
# Triggers an immediate manual backup. Independent from the
# periodic auto-backup in service.sh.
#
# Uses functions.sh:backup_user_files when available; otherwise
# the inline fallback (_inline_backup_now).
#
# Rotates after successful backup, matching service.sh.
#
# HARD-ACT-04: normalized stdout confirmation on both paths.
# ============================================================
if [ "$BACKUP_MODE" = "1" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║  💾 DNSCrypt – Manual Backup                 ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""

    if [ ! -d "$BIN_DIR" ]; then
        echo "❌ Module directory not found: $BIN_DIR"
        echo "   Is the module installed?"
        exit 3
    fi

    echo "  Source: $BIN_DIR"
    echo "  Target: $PERSISTENT_BACKUP"
    echo ""

    if do_backup_now; then
        # Rotate to keep the total bounded (v1.2.0 FIX)
        do_rotate_backups 21 >/dev/null 2>&1 || true

        # HARD-ACT-04: print the confirmation explicitly so the
        # user sees the same message whether the fallback path
        # or functions.sh:backup_user_files handled the backup.
        # (The functions.sh path logs to the log file only.)
        echo ""
        echo "  ✅ Backup completed successfully."
        echo ""
        echo "  Current backup state:"
        echo "    $(backup_summary)"
        echo ""
        log_msg "--backup completed successfully"
        exit 0
    else
        echo ""
        echo "  ❌ Backup failed. See message above."
        log_msg "--backup failed"
        exit 3
    fi
fi

# ============================================================
# [14] Path 4: comprehensive check (--check)
# ============================================================
# v1.1.0:
#   • Structured sections (Service, Runtime, Config, Profile)
#   • Includes the expected memory limit for the active profile
#   • English-only output
#
# v1.2.0:
#   • New "Backup & Recovery" section showing:
#       - Snapshot count
#       - In-flight transactions (txn-*)
#       - Orphan transactions (orphan-txn-*)
#       - .last_stable pointer
#       - Auto-backup marker age
#       - Recovery mode state
#       - Pending notification content
#
# ACT-L2: `_txn_count` and `_orphan_count` now go through a
#         numeric-validation guard before being printed.
# ACT-L3: `--check` prefers `is_dnscrypt_running` when
#         available (already implemented, fallback documented).
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
    # ACT-L3: Prefer is_dnscrypt_running (port + process check)
    # when functions.sh is loaded. Fallback to pgrep otherwise.
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

    # --- Section 5: Backup & Recovery (v1.2.0) ---
    echo "─── Backup & Recovery ──────────────────────"

    # Snapshot count (excluding current/, txn-*, orphan-txn-*)
    _snap_count=0
    if [ -d "$PERSISTENT_BACKUP" ]; then
        _snap_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d */ 2>/dev/null | \
            sed 's:/$::' | \
            grep -E '^[0-9]{8}-[0-9]{6}-' | \
            wc -l | tr -d ' ')
        [ -z "$_snap_count" ] && _snap_count=0
    fi

    # In-flight transactions
    _txn_count=0
    if [ -d "$PERSISTENT_BACKUP" ]; then
        _txn_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d txn-*/ 2>/dev/null | \
            wc -l | tr -d ' ')
        case "$_txn_count" in ''|*[!0-9]*) _txn_count=0 ;; esac
    fi

    # Orphan transactions
    _orphan_count=0
    if [ -d "$PERSISTENT_BACKUP" ]; then
        _orphan_count=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d orphan-txn-*/ 2>/dev/null | \
            wc -l | tr -d ' ')
        case "$_orphan_count" in ''|*[!0-9]*) _orphan_count=0 ;; esac
    fi

    printf "  💾 State         : %s\n" "$(backup_summary)"
    printf "  📁 Path          : %s\n" "$PERSISTENT_BACKUP"
    printf "  📸 Snapshots     : %s\n" "$_snap_count"

    # In-flight transactions (informational)
    if [ "$_txn_count" -gt 0 ]; then
        printf "  ⏳ In-flight txn : %s (install in progress or interrupted)\n" "$_txn_count"
    fi

    # Orphan transactions (informational)
    if [ "$_orphan_count" -gt 0 ]; then
        printf "  🗃️  Orphan txn    : %s (preserved from interrupted install)\n" "$_orphan_count"
    fi

    # .last_stable pointer
    if [ -f "$LAST_STABLE_FILE" ]; then
        _ls=$(cat "$LAST_STABLE_FILE" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$_ls" ]; then
            printf "  🎯 Last stable   : %s\n" "$_ls"
        fi
    fi

    # Auto-backup marker age
    if [ -f "$LAST_AUTO_BACKUP_MARKER" ]; then
        _auto_mtime=$(stat -c %Y "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
            || _auto_mtime=$(stat -f %m "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null) \
            || _auto_mtime=0
        if echo "$_auto_mtime" | grep -qE '^[0-9]+$' && [ "$_auto_mtime" -gt 0 ]; then
            _auto_now=$(date +%s 2>/dev/null)
            case "$_auto_now" in
                ''|*[!0-9]*) _auto_now=0 ;;
            esac
            if [ "$_auto_now" -gt 0 ]; then
                _auto_age=$((_auto_now - _auto_mtime))
                if [ "$_auto_age" -lt 60 ]; then
                    _auto_age_str="${_auto_age}s ago"
                elif [ "$_auto_age" -lt 3600 ]; then
                    _auto_age_str="$((_auto_age / 60))m ago"
                elif [ "$_auto_age" -lt 86400 ]; then
                    _auto_age_str="$((_auto_age / 3600))h ago"
                else
                    _auto_age_str="$((_auto_age / 86400))d ago"
                fi
                printf "  🔄 Auto-backup   : %s\n" "$_auto_age_str"
            fi
        fi
    fi

    # Recovery mode state
    if [ -f "$RECOVERY_TRIGGER_1" ] || [ -f "$RECOVERY_TRIGGER_2" ]; then
        printf "  🚨 Recovery mode : TRIGGER PRESENT — next install will restore\n"
    fi

    # Pending notification
    if [ -f "$PENDING_NOTIFY_FILE" ]; then
        _pn=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$_pn" ]; then
            printf "  📢 Notification  : %s\n" "$_pn"
        fi
    fi

    printf "  ℹ️  Recovery      : touch %s/recovery && reboot\n" "$MODDIR"
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
    echo "  ℹ️  Full diagnostic report: action.sh --diagnose"
    echo ""
    exit 0
fi

# ============================================================
# [15] Refuse to start if module is disabled
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    log_msg "Module is disabled, cannot start WebUI"
    printf "⚠️  Module is disabled.\n"
    printf "Enable it first from Magisk/KernelSU.\n"
    exit 2
fi

# ============================================================
# [16] Verify WebUI binary exists
# ============================================================
if [ ! -f "$WEBUI" ]; then
    log_msg "WebUI binary not found at $WEBUI"
    printf "❌ WebUI binary not found.\n"
    printf "Try reinstalling the module.\n"
    exit 1
fi

# ============================================================
# [17] Start WebUI (if needed)
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

        # ACT-L1: Renamed from `local_pid` to `_act_pid`
        # (no `local` keyword at top level).
        sleep 1
        _act_pid=$(pgrep -x "dnscrypt-webui" 2>/dev/null | head -n1)
        if [ -n "$_act_pid" ]; then
            printf "%s\n" "$_act_pid" > "${WEBUI_PID_FILE}.tmp" 2>/dev/null
            mv -f "${WEBUI_PID_FILE}.tmp" "$WEBUI_PID_FILE" 2>/dev/null
        fi

        # Wait for the port to open (max 20s)
        # ACT-L1: Renamed from `local_i` to `_act_i`.
        _act_i=0
        while [ "$_act_i" -lt 20 ]; do
            if is_port_listening "$PORT" tcp; then
                break
            fi
            sleep 1
            _act_i=$((_act_i + 1))
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
# [18] Open browser (5 fallback methods + timeout)
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

# --- Try 5: fire-and-forget ---
# HARD-ACT-05: explicit fire-and-forget. No exit-code check
# is performed — the intent is best-effort. We do NOT wrap
# this in an `if` because `if cmd &` always succeeds in POSIX
# sh (the `&` backgrounds the command and the `if` reads the
# exit status of the backgrounding, which is always 0).
#
# ACT-L5: Removed the unexplained `sleep 1` that followed
# the asynchronous launch.
timeout 5 am start \
    -a android.intent.action.VIEW \
    -d "$URL" \
    >/dev/null 2>&1 &

log_msg "Browser opened via am start (async, no -W)"
printf "✅ Browser opened (async).\n"
exit 0