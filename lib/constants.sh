#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — lib/constants.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Single source of truth for every constant and pure lookup
# shared across more than one shell script.
#
# Sourced by boot-mini.sh. All higher-layer scripts
# (functions.sh, service.sh, action.sh, status.sh,
# watchdog.sh, uninstall.sh, customize.sh, post-fs-data.sh)
# inherit these constants transitively.
#
# Rules:
#   • No external dependencies.
#   • No filesystem writes.
#   • Any constant or pure lookup used by ≥2 scripts lives
#     HERE, not in the scripts themselves.
# ============================================================

if [ -n "${_LIB_CONSTANTS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_LIB_CONSTANTS_LOADED=1

# ============================================================
# [1] Fixed absolute paths
# ============================================================
# Same on every device regardless of where the module lives.
# Callers MUST NOT redefine these.
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
CRED_FILE="/data/local/tmp/dnscrypt_credentials.txt"
INSTALL_LOG="/data/local/tmp/dnscrypt_install.log"

PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
LEGACY_BACKUP_DIR="/data/local/tmp/dnscrypt_backup_uninstall"

LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
LAST_AUTO_BACKUP_MARKER="$PERSISTENT_BACKUP/.last_auto_backup"
UPGRADE_HISTORY_JSON="$PERSISTENT_BACKUP/.upgrade_history.json"
UPGRADE_HISTORY_TXT="$PERSISTENT_BACKUP/.upgrade_history.txt"
APK_MIRROR_DIR="$PERSISTENT_BACKUP/apk"

RECOVERY_TRIGGER_2="/data/adb/dnscrypt-recovery"

DEFAULT_MODULE_DIR="/data/adb/modules/dnscrypt-proxy-webui"
MODULE_ID="dnscrypt-proxy-webui"

# ============================================================
# [2] Reserved ports
# ============================================================
# _MONITORING_UI_PORT is reserved for dnscrypt-proxy's
# monitoring_ui endpoint. Every Port Guard in the tree rejects
# it. main.go enforces the same constraint on the Go side.
_MONITORING_UI_PORT="8080"
DEFAULT_WEBUI_PORT="9090"
DEFAULT_DASHBOARD_PORT="9091"
DNS_ENGINE_PORT="5354"

# ============================================================
# [3] User files
# ============================================================
# The five files preserved across upgrades and stored in the
# persistent backup directory.
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# ============================================================
# [4] Backup rotation
# ============================================================
BACKUP_ROTATION_KEEP=21
AUTO_BACKUP_INTERVAL=86400

# Snapshot directory names are YYYYMMDD-HHMMSS-<suffix>.
SNAPSHOT_TS_REGEX='^[0-9]{8}-[0-9]{6}-'

# Directories excluded from snapshot enumeration. Consumed by
# list_snapshots() in lib/backup.sh via:
#     case "$name" in $SNAPSHOT_EXCLUDE_PATTERN) continue ;; esac
SNAPSHOT_EXCLUDE_PATTERN="current|txn-*|orphan-txn-*|.restore_snap.*|apk"

# ============================================================
# [5] Bootstrap resolver fallback
# ============================================================
# Used ONLY when dnscrypt-proxy.toml cannot be parsed.
# The runtime source of truth remains the TOML file.
BOOTSTRAP_IPS_FALLBACK="9.9.9.9 8.8.8.8 1.1.1.1 1.0.0.1"
LOOPBACK_IPV4="127.0.0.1"
LOOPBACK_IPV6="::1"

# ============================================================
# [6] install_app.sh timeouts (seconds)
# ============================================================
# The hierarchy MUST hold:
#   CASCADE_DEADLINE < TIMEOUT_SERVER < TIMEOUT_CLIENT
# so the EXIT trap fires before main.go sends SIGKILL.
INSTALL_TIMEOUT_SERVER=90
INSTALL_TIMEOUT_CLIENT=120
INSTALL_CASCADE_DEADLINE=75
INSTALL_STRATEGY_TIMEOUT=20
INSTALL_MIN_BUDGET=3

# ============================================================
# [7] Watchdog backoff (seconds)
# ============================================================
WATCHDOG_BACKOFF_BASE=30
WATCHDOG_BACKOFF_MAX=600

# ============================================================
# [8] Version resolution
# ============================================================
# Reads module.prop. Falls back to a hardcoded string so
# callers never see an empty version.
get_module_version() {
    local root="${1:-${MODDIR:-${MODPATH:-$DEFAULT_MODULE_DIR}}}"
    local v=""

    if [ -f "$root/module.prop" ]; then
        v=$(grep '^version=' "$root/module.prop" 2>/dev/null \
            | head -n1 \
            | cut -d= -f2- \
            | tr -d '\r ')
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi

    printf 'v1.6.0'
}

# ============================================================
# [9] Recovery trigger path
# ============================================================
# Every script that checks or writes a recovery trigger MUST
# call this function. Canonical path: <module_root>/recovery.
get_recovery_trigger() {
    local root="${1:-${MODDIR:-${MODPATH:-$DEFAULT_MODULE_DIR}}}"
    printf '%s/recovery' "$root"
}

# ============================================================
# [10] Derived module paths
# ============================================================
# Callers invoke this once after resolving $MODDIR. All
# module-relative paths become globals so downstream code does
# not recompute them.
init_module_paths() {
    local root="$1"
    if [ -z "$root" ] || [ ! -d "$root" ]; then
        return 1
    fi

    BIN_DIR="$root/proxy"
    WEB_DIR="$root/web"

    TOML_FILE="$BIN_DIR/dnscrypt-proxy.toml"
    WEBUI_CONF="$BIN_DIR/webui.conf"
    SELECTED_PROFILE_FILE="$BIN_DIR/selected_profile.txt"
    BLOCKLIST_FILE="$BIN_DIR/blocklist.txt"
    RAW_BLOCKLIST_FILE="$BIN_DIR/blocklist.raw"
    BLOCKED_IPS_FILE="$BIN_DIR/blocked-ips.txt"

    WEBUI_BIN="$BIN_DIR/dnscrypt-webui"
    PROXY_BIN="$BIN_DIR/dnscrypt-proxy"

    RUN_DIR="$BIN_DIR/run"

    export BIN_DIR WEB_DIR
    export TOML_FILE WEBUI_CONF SELECTED_PROFILE_FILE
    export BLOCKLIST_FILE RAW_BLOCKLIST_FILE BLOCKED_IPS_FILE
    export WEBUI_BIN PROXY_BIN
    export RUN_DIR

    return 0
}

# ============================================================
# [11] Port validation (unified Port Guard)
# ============================================================
# Cleans leading zeros, validates range, rejects the reserved
# _MONITORING_UI_PORT. On any rejection, prints $fallback.
validate_port() {
    local port="$1"
    local fallback="${2:-$DEFAULT_WEBUI_PORT}"
    local clean

    case "$port" in
        ''|*[!0-9]*) printf '%s' "$fallback"; return 1 ;;
    esac

    clean=$(printf '%s' "$port" | sed 's/^0*//')
    [ -z "$clean" ] && clean="0"

    if [ "$clean" -lt 1 ] || [ "$clean" -gt 65535 ]; then
        printf '%s' "$fallback"
        return 1
    fi

    if [ "$clean" = "$_MONITORING_UI_PORT" ]; then
        printf '%s' "$fallback"
        return 1
    fi

    printf '%s' "$clean"
    return 0
}

# ============================================================
# [12] TOML credential reader (section-restricted)
# ============================================================
# Returns "user\npass" on stdout. Empty if file missing or
# [monitoring_ui] section absent. Only that section is read;
# other sections containing username/password keys are ignored.
parse_toml_value() {
    local s="$1"
    [ -z "$s" ] && return 0

    s=$(printf '%s' "$s" | sed 's/^[[:space:]]*//')

    case "$s" in
        \"*) printf '%s' "$s" | sed 's/^"//; s/".*//'; return 0 ;;
        \'*) printf '%s' "$s" | sed "s/^'//; s/'.*//"; return 0 ;;
    esac

    case "$s" in
        *" #"*) s="${s%% #*}" ;;
    esac

    printf '%s' "$s" | sed 's/[[:space:]]*$//'
    return 0
}

read_toml_credentials() {
    local user="" pass=""

    if [ -z "${TOML_FILE:-}" ] || [ ! -f "$TOML_FILE" ]; then
        printf '%s\n%s' "" ""
        return 0
    fi

    local in_section=0 line trimmed section key val
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(printf '%s' "$line" | tr -d '\r')
        trimmed=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        case "$trimmed" in ''|\#*) continue ;; esac

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

        case "$trimmed" in
            *=*)
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

    printf '%s\n%s' "$user" "$pass"
}

# ============================================================
# [13] Root solution detection (SSOT)
# ============================================================
# Defines ROOT_SOLUTION globally so every script (including
# main.go's shell subprocesses) inherits the correct value.
detect_root_solution() {
    local ksu=0 apatch=0 magisk=0
    [ -n "${KSU_VER:-}" ]         && ksu=$((ksu + 2))
    [ -d "/data/adb/ksu" ]        && ksu=$((ksu + 1))
    [ -n "${APATCH:-}" ]          && apatch=$((apatch + 2))
    [ -d "/data/adb/ap" ]         && apatch=$((apatch + 1))
    [ -n "${MAGISK_VER_CODE:-}" ] && magisk=$((magisk + 2))
    [ -d "/data/adb/magisk" ]     && magisk=$((magisk + 1))

    if [ "$ksu" -gt 0 ] && [ "$ksu" -ge "$apatch" ] && [ "$ksu" -ge "$magisk" ]; then
        printf "kernelsu"; return 0
    fi
    if [ "$apatch" -gt 0 ] && [ "$apatch" -ge "$magisk" ]; then
        printf "apatch"; return 0
    fi
    if [ "$magisk" -gt 0 ]; then
        printf "magisk"; return 0
    fi
    printf "unknown"
}

# Export so child processes (like those spawned by main.go) can see it
ROOT_SOLUTION="${ROOT_SOLUTION:-$(detect_root_solution)}"
export ROOT_SOLUTION