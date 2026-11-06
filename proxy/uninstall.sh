#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — uninstall.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-19
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Magisk / KernelSU / APatch uninstall script.
#
# Responsibilities:
#   • Kill all running processes (dnscrypt-proxy, dnscrypt-webui,
#     watchdog.sh) and WAIT for them to actually exit.
#   • Clean the firewall (Custom Chains + Legacy).
#   • Reset system DNS settings (private_dns_mode).
#   • Restore the original route_localnet value.
#   • Remove runtime files (run/, PIDs, STATUS_FILE, locks,
#     logs, caches).
#   • Remove module configuration files.
#   • Remove the module fingerprint + disable file.
#   • Resolve txn-* directories:
#       – COMMIT              → removed
#       – ROLLBACK / empty    → removed
#       – START / no state    → RENAMED to orphan-txn-* (preserved)
#   • PRESERVE pre-existing orphan-txn-* directories.
#   • Remove any legacy backup directory from v1.0.0.
#   • PRESERVE the persistent backup directory and APK mirror.
#
# Options:
#   uninstall.sh          Full cleanup (default)
#   uninstall.sh --help   Show help
#
# Exit codes:
#   0 = success
#   1 = security violation (MODDIR outside expected paths)
#   2 = unknown command-line argument
#
# Design: SELF-CONTAINED (deliberate)
# ============================================================
# This script does NOT source functions.sh. Sourcing it would:
#   • create RUN_DIR and .bootstrap_cache — files this script
#     is about to delete,
#   • run functions.sh's top-level initialization, which is
#     counterproductive at uninstall time.
#
# More importantly, uninstall.sh must work even when
# functions.sh is missing or corrupt. It is the last script
# the module runs — if it depends on a broken library, the
# user is left with no way to clean up.
#
# Consequence: firewall cleanup and process cleanup below are
# inline, even though equivalent functions live in
# functions.sh. The duplication is intentional.
#
# Backup policy (IMPORTANT):
# ============================================================
# This script does NOT delete /sdcard/dnscrypt-webui-backup/.
# It contains the 5 user config files snapshotted at every
# upgrade, plus the companion APK mirror at apk/.
#
# The user can delete the whole directory at any time:
#     su -c "rm -rf /sdcard/dnscrypt-webui-backup"
#
# Transaction handling:
# ============================================================
# Four cases for txn-* directories:
#   1. State "COMMIT"      → removed
#   2. State "ROLLBACK"    → removed
#   3. State "START"       → renamed to orphan-txn-*, preserved
#   4. No .state (or empty) → renamed to orphan-txn-*, preserved
#
# Any pre-existing orphan-txn-* directories are PRESERVED as-is.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path + version
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

get_module_version() {
    local vf="$MODDIR/module.prop"
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

MODULE_VERSION="$(get_module_version)"

case "${1:-}" in
    --version)
        echo "$0: $MODULE_VERSION"
        exit 0
        ;;
esac

# ============================================================
# [2] Parse command-line arguments
# ============================================================
# Unknown arguments are a hard error. Magisk does not pass
# extra arguments to uninstall scripts, so a non-empty unknown
# argument almost certainly means a manual invocation with a
# typo — and silently proceeding would be dangerous on a
# destructive script.
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            cat << 'EOF'
DNSCrypt Smart Filter – uninstall.sh

Usage:
  uninstall.sh          Full cleanup (default)
  uninstall.sh --help   Show this help

Exit codes:
  0 = success
  1 = security violation (MODDIR outside expected paths)
  2 = unknown command-line argument

Note:
  This script is normally invoked automatically by Magisk when the
  module is removed. Do not run it manually except for cleanup.

  Your persistent backup directory is PRESERVED so you can
  restore settings if you reinstall later:
    /sdcard/dnscrypt-webui-backup/

  This includes the companion APK mirror:
    /sdcard/dnscrypt-webui-backup/apk/

  Any txn-* directory that was interrupted mid-flight (state=START
  or missing .state) will be renamed to orphan-txn-* and PRESERVED.
  Inspect manually before deleting.

  A pending recovery trigger (/data/adb/dnscrypt-recovery), if any,
  is REMOVED — it has no meaning once the module is gone.

  The companion Android app APK is NOT touched by this script.
  The module-internal copy is deleted with the module folder by
  the root manager. Any separately-installed companion app is
  unaffected.

  If you want to keep your settings in a separate manual backup,
  copy them before uninstalling:
    su -c "cp -a /data/adb/modules/dnscrypt-proxy-webui/proxy/ \
                /sdcard/dnscrypt-backup-manual/"
EOF
            exit 0
            ;;
        "")
            ;;
        *)
            echo "ERROR: unknown argument: $arg" >&2
            echo "       Use --help for usage information." >&2
            echo "       Refusing to run a destructive script on an unknown flag." >&2
            exit 2
            ;;
    esac
done

# ============================================================
# [3] Global paths
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
RUN_DIR="$MODDIR/proxy/run"
BIN_DIR="$MODDIR/proxy"

PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"

USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

APK_MIRROR_DIR="$PERSISTENT_BACKUP/apk"
APK_MIRROR_FILE="$APK_MIRROR_DIR/app-debug.apk"
APK_MIRROR_SHA_FILE="$APK_MIRROR_DIR/app-debug.apk.sha256"

RECOVERY_TRIGGER_1="$MODDIR/recovery"
RECOVERY_TRIGGER_2="/data/adb/dnscrypt-recovery"

LEGACY_BACKUP_DIR="/data/local/tmp/dnscrypt_backup_uninstall"

# ============================================================
# [4] Protected log helper
# ============================================================
# Appends a timestamped line to $LOG_FILE with the
# `[UNINSTALL]` prefix.
#
# The `LOG_DISABLED` flag short-circuits all writes once §[14]
# has removed the log file. Without it, the log is auto-created
# by every subsequent call.
LOG_DISABLED=0

log_msg() {
    [ "$LOG_DISABLED" = "1" ] && return 0

    if [ ! -d "/data/local/tmp" ]; then
        return 0
    fi
    if [ ! -f "$LOG_FILE" ]; then
        : > "$LOG_FILE" 2>/dev/null || return 0
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [UNINSTALL] $1" >> "$LOG_FILE" 2>/dev/null
}

log_msg "════════════════════════════════════════════"
log_msg "Uninstall started ($MODULE_VERSION)"
log_msg "MODDIR=$MODDIR"
log_msg "RUN_DIR=$RUN_DIR"
log_msg "Backup dir (preserved): $PERSISTENT_BACKUP"

# ============================================================
# [5] Security checks
# ============================================================
# Three validations before ANY destructive action:
#
#   1. MODDIR must be inside /data/adb/modules/.
#   2. MODDIR must not be exactly /data/adb/modules.
#   3. The module's basename should start with "dnscrypt".
case "$MODDIR" in
    /data/adb/modules/*) ;;
    *)
        log_msg "❌ SECURITY: MODDIR is not inside /data/adb/modules, aborting"
        exit 1
        ;;
esac

if [ "$MODDIR" = "/data/adb/modules" ]; then
    log_msg "❌ SECURITY: MODDIR equals MODULES_DIR, aborting"
    exit 1
fi

MODULE_ID=$(basename "$MODDIR")
case "$MODULE_ID" in
    dnscrypt*|DNSCrypt*)
        ;;
    *)
        log_msg "⚠️ MODULE_ID=$MODULE_ID is not recognized, but continuing"
        ;;
esac

# ============================================================
# [5a] Snapshot enumeration helper
# ============================================================
# Prints one snapshot directory name per line, newest first.
#
# Detection and ordering:
#   • SNAP-MANIFEST: directory is a snapshot iff it contains
#     a `.manifest.json` file.
#   • SNAP-MTIME: ordered by mtime, descending.
#
# Excludes (by name): current/, txn-*, orphan-txn-*,
# .restore_snap.*, apk/.
#
# Uses SUBSHELL ISOLATION for internal loop variables.
_uninstall_list_snapshots() {
    [ -d "$PERSISTENT_BACKUP" ] || return 0

    (
        cd "$PERSISTENT_BACKUP" 2>/dev/null || exit 0
        for _d in */; do
            _d="${_d%/}"
            [ -d "$_d" ] || continue
            case "$_d" in
                current|txn-*|orphan-txn-*|.restore_snap.*|apk) continue ;;
            esac
            [ -f "$_d/.manifest.json" ] || continue
            _mt=$(stat -c %Y "$_d" 2>/dev/null) \
                || _mt=$(stat -f %m "$_d" 2>/dev/null) \
                || _mt=0
            case "$_mt" in ''|*[!0-9]*) _mt=0 ;; esac
            printf '%s %s\n' "$_mt" "$_d"
        done | LC_ALL=C sort -rn -k1,1 | awk '{print $2}'
    )
}

# ============================================================
# [5b] Read state for the final report
# ============================================================
# Collects the state that the final summary (§[18]) reports.
ACTIVE_PROFILE="unknown"
if [ -f "$BIN_DIR/selected_profile.txt" ]; then
    _ap=$(cat "$BIN_DIR/selected_profile.txt" 2>/dev/null | tr -d '\r\n ')
    case "$_ap" in
        light|normal|pro|proplus|ultimate) ACTIVE_PROFILE="$_ap" ;;
    esac
fi
log_msg "Active profile at uninstall: $ACTIVE_PROFILE"

detect_root_solution() {
    if [ -n "${KSU_VER:-}" ] || [ -d "/data/adb/ksu" ]; then
        printf "KernelSU"
        return 0
    fi
    if [ -n "${APATCH:-}" ] || [ -d "/data/adb/ap" ]; then
        printf "APatch"
        return 0
    fi
    if [ -n "${MAGISK_VER_CODE:-}" ] || [ -d "/data/adb/magisk" ]; then
        printf "Magisk"
        return 0
    fi
    printf "unknown"
}

ROOT_SOLUTION=$(detect_root_solution)
log_msg "Root solution: $ROOT_SOLUTION"

BACKUP_COUNT=0
BACKUP_LAST_NAME=""
BACKUP_LAST_STABLE=""
BACKUP_TXN_COUNT=0
BACKUP_ORPHAN_COUNT=0

APK_MIRROR_PRESENT=0
APK_MIRROR_SHA_PRESENT=0
APK_MIRROR_SIZE_BYTES=0

if [ -d "$PERSISTENT_BACKUP" ]; then
    _ul_list=$(_uninstall_list_snapshots)

    if [ -n "$_ul_list" ]; then
        BACKUP_COUNT=$(printf '%s\n' "$_ul_list" | wc -l | tr -d ' ')
        [ -z "$BACKUP_COUNT" ] && BACKUP_COUNT=0

        if [ "$BACKUP_COUNT" -gt 0 ]; then
            BACKUP_LAST_NAME=$(printf '%s\n' "$_ul_list" | head -n1)
        fi
    fi

    BACKUP_TXN_COUNT=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d txn-*/ 2>/dev/null | \
        wc -l | tr -d ' ')
    [ -z "$BACKUP_TXN_COUNT" ] && BACKUP_TXN_COUNT=0

    BACKUP_ORPHAN_COUNT=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d orphan-txn-*/ 2>/dev/null | \
        wc -l | tr -d ' ')
    [ -z "$BACKUP_ORPHAN_COUNT" ] && BACKUP_ORPHAN_COUNT=0

    if [ -f "$LAST_STABLE_FILE" ]; then
        BACKUP_LAST_STABLE=$(cat "$LAST_STABLE_FILE" 2>/dev/null | tr -d '\r\n ')
    fi

    if [ -f "$APK_MIRROR_FILE" ]; then
        APK_MIRROR_PRESENT=1
        _apk_size=$(wc -c < "$APK_MIRROR_FILE" 2>/dev/null | tr -d ' ')
        case "$_apk_size" in
            ''|*[!0-9]*) _apk_size=0 ;;
        esac
        APK_MIRROR_SIZE_BYTES=$_apk_size

        if [ -f "$APK_MIRROR_SHA_FILE" ] && [ -s "$APK_MIRROR_SHA_FILE" ]; then
            APK_MIRROR_SHA_PRESENT=1
        fi
    fi

    log_msg "Preserved backups: $BACKUP_COUNT snapshot(s)"
    log_msg "In-flight transactions: $BACKUP_TXN_COUNT"
    log_msg "Orphan transactions: $BACKUP_ORPHAN_COUNT"
    if [ -n "$BACKUP_LAST_STABLE" ]; then
        log_msg "Last stable pointer: $BACKUP_LAST_STABLE"
    fi
    if [ "$APK_MIRROR_PRESENT" = "1" ]; then
        if [ "$APK_MIRROR_SHA_PRESENT" = "1" ]; then
            log_msg "Companion APK mirror: present ($APK_MIRROR_SIZE_BYTES bytes + .sha256)"
        else
            log_msg "Companion APK mirror: present ($APK_MIRROR_SIZE_BYTES bytes, no .sha256)"
        fi
    else
        log_msg "Companion APK mirror: not present"
    fi
else
    log_msg "No persistent backup directory found"
fi

if [ -f "$PENDING_NOTIFY_FILE" ]; then
    _pn=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$_pn" ]; then
        log_msg "Pending notification: $_pn"
    fi
fi

# ============================================================
# [6] Save route_localnet before changing it
# ============================================================
ORIGINAL_ROUTE_LOCALNET=""
if command -v sysctl >/dev/null 2>&1; then
    ORIGINAL_ROUTE_LOCALNET=$(sysctl -n net.ipv4.conf.all.route_localnet 2>/dev/null | tr -d '\r\n ')
fi

# ============================================================
# [7] Save the current EXIT trap (informational)
# ============================================================
# uninstall.sh does NOT install its own EXIT trap. Any EXIT
# trap the root manager may have installed remains in place.
FUNCTIONS_LOADED=0
log_msg "Using inline cleanup (self-contained uninstaller)"

# ============================================================
# [8] Internal cleanup functions (self-contained)
# ============================================================
# _kill_watchdogs_by_pattern — kills every live watchdog.sh
# regardless of PID file state.
#
# Uses ps + grep (NOT pgrep -f, which would match this very
# shell's argv when the script name contains "watchdog.sh").
# Without this function, a ghost watchdog whose PID file was
# lost or reused would survive a PID-file-based kill and
# start fighting the freshly reinstalled watchdog for restart
# attempts.
#
# Returns 0 on success (all watchdogs dead within 3s), 1 on
# timeout (some survived — likely D-state).
_kill_watchdogs_by_pattern() {
    local wd_pids
    wd_pids=$(ps -A -o PID,ARGS 2>/dev/null \
              | grep '/watchdog\.sh' \
              | grep -v grep \
              | awk '{print $1}')

    if [ -z "$wd_pids" ]; then
        return 0
    fi

    log_msg "Killing watchdog process(es): $(echo $wd_pids | tr '\n' ' ')"

    # shellcheck disable=SC2086
    kill -9 $wd_pids 2>/dev/null

    local wait_ticks=0
    while [ "$wait_ticks" -lt 30 ]; do
        if [ -z "$(ps -A -o ARGS 2>/dev/null \
                  | grep '/watchdog\.sh' \
                  | grep -v grep)" ]; then
            return 0
        fi
        sleep 0.1
        wait_ticks=$((wait_ticks + 1))
    done
    return 1
}

# _inline_kill_all terminates daemons and WAITS for exit.
#
# Order:
#   1. pkill -9 for proxy and webui.
#   2. Pattern-based kill for watchdog.sh (regardless of PID
#      file state).
#   3. Poll for actual death (100 ms × 30 = 3 s max). A
#      process in D-state (uninterruptible sleep on I/O) may
#      survive SIGKILL briefly.
#   4. fuser -k on the DNS ports (catches a process bound to
#      5354/udp or 5354/tcp but not named dnscrypt-proxy).
_inline_kill_all() {
    local _ki_wait=0
    local _ki_alive=0

    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-proxy 2>/dev/null
    fi
    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
    fi

    _kill_watchdogs_by_pattern

    while [ "$_ki_wait" -lt 30 ]; do
        _ki_alive=0
        if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
            _ki_alive=1
        fi
        if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
            _ki_alive=1
        fi
        if [ -n "$(ps -A -o ARGS 2>/dev/null | grep '/watchdog\.sh' | grep -v grep)" ]; then
            _ki_alive=1
        fi
        [ "$_ki_alive" -eq 0 ] && break
        sleep 0.1
        _ki_wait=$((_ki_wait + 1))
    done

    if [ "$_ki_wait" -ge 30 ]; then
        log_msg "⚠️ Process(es) still alive after 3s (likely D-state); continuing anyway"
    fi

    if command -v fuser >/dev/null 2>&1; then
        fuser -k 5354/udp 2>/dev/null
        fuser -k 5354/tcp 2>/dev/null
    fi
}

# _inline_cleanup_firewall — orphan prevention.
#
# Strategy:
#   1. Delete the DNSCRYPT_OUT / DNSCRYPT_OUT6 Custom Chains.
#   2. Best-effort legacy cleanup (rules from older versions).
#   3. No dependency on functions.sh (self-contained).
#
# Synchronization note:
#   This function removes the same SET of rules as:
#     • customize.sh    : _inline_cleanup_firewall
#     • post-fs-data.sh : inline_firewall_cleanup
#     • functions.sh    : manage_firewall 0
#   Any change to the RULES removed MUST be applied to all four.
_inline_cleanup_firewall() {
    if command -v nft >/dev/null 2>&1; then
        nft delete table inet dnscrypt_filter 2>/dev/null
        nft delete table ip dnscrypt_filter 2>/dev/null
        nft delete table ip6 dnscrypt_filter 2>/dev/null
    fi

    if command -v iptables >/dev/null 2>&1; then
        local _chain="DNSCRYPT_OUT"

        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -F "$_chain" --wait 3 2>/dev/null
        iptables -t nat -X "$_chain" --wait 3 2>/dev/null

        iptables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null

        iptables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 --wait 3 2>/dev/null

        iptables -t nat -D OUTPUT -d 127.0.0.1 -p udp --dport 53 \
            -j RETURN \
            -m comment --comment "dnscrypt_smart_filter_loopback_127.0.0.1" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -d 127.0.0.1 -p tcp --dport 53 \
            -j RETURN \
            -m comment --comment "dnscrypt_smart_filter_loopback_127.0.0.1" --wait 3 2>/dev/null

        iptables -t nat -D OUTPUT -d 127.0.0.1 -p udp --dport 53 \
            -j RETURN --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -d 127.0.0.1 -p tcp --dport 53 \
            -j RETURN --wait 3 2>/dev/null

        local _ip
        for _ip in 9.9.9.9 8.8.8.8 1.1.1.1 1.0.0.1 8.8.4.4 208.67.222.222 208.67.220.220; do
            iptables -t nat -D OUTPUT -d "$_ip" -p udp --dport 53 \
                -j RETURN --wait 3 2>/dev/null
            iptables -t nat -D OUTPUT -d "$_ip" -p tcp --dport 53 \
                -j RETURN --wait 3 2>/dev/null
        done
    fi

    if command -v ip6tables >/dev/null 2>&1; then
        local _chain6="DNSCRYPT_OUT6"

        ip6tables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain6" --wait 3 2>/dev/null
        ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain6" --wait 3 2>/dev/null
        ip6tables -t nat -F "$_chain6" --wait 3 2>/dev/null
        ip6tables -t nat -X "$_chain6" --wait 3 2>/dev/null

        ip6tables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination "[::1]:5354" \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
        ip6tables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination "[::1]:5354" \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null

        ip6tables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination "[::1]:5354" --wait 3 2>/dev/null
        ip6tables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination "[::1]:5354" --wait 3 2>/dev/null

        ip6tables -t nat -D OUTPUT -d ::1 -p udp --dport 53 \
            -j RETURN --wait 3 2>/dev/null
        ip6tables -t nat -D OUTPUT -d ::1 -p tcp --dport 53 \
            -j RETURN --wait 3 2>/dev/null
    fi
}

# ============================================================
# [9] Resolve transaction directories
# ============================================================
# Case handling:
#   • "COMMIT"   — removed. The install succeeded; the
#                  directory is a leftover from an interrupted
#                  cleanup step, not user data.
#   • "ROLLBACK" — removed. The rollback was applied.
#   • "START"    — renamed to orphan-txn-*, preserved.
#   • ""/other   — renamed to orphan-txn-*, preserved.
#
# The rename prefix is `orphan-` prepended to the original
# name with the `txn-` prefix stripped:
#   txn-20260101-120000-1234  →  orphan-20260101-120000-1234
# This preserves the timestamp and PID, letting a user
# correlate an orphan with a specific failed install in the log.
ORPHAN_TXN_CLEANED=0
ORPHAN_TXN_RENAMED=0

_resolve_txn_dirs() {
    local _txn _state _safe_name
    for _txn in "$PERSISTENT_BACKUP"/txn-*; do
        [ -d "$_txn" ] || continue

        _state=""
        [ -f "$_txn/.state" ] && _state=$(cat "$_txn/.state" 2>/dev/null | tr -d '\r\n ')

        case "$_state" in
            "COMMIT")
                if rm -rf "$_txn" 2>/dev/null; then
                    ORPHAN_TXN_CLEANED=$((ORPHAN_TXN_CLEANED + 1))
                    log_msg "🗑️ Removed committed-orphan txn: $(basename "$_txn")"
                fi
                ;;
            "ROLLBACK")
                if rm -rf "$_txn" 2>/dev/null; then
                    ORPHAN_TXN_CLEANED=$((ORPHAN_TXN_CLEANED + 1))
                    log_msg "🗑️ Removed rolled-back txn: $(basename "$_txn")"
                fi
                ;;
            *)
                log_msg "⚠️ Unfinished/unknown transaction: $(basename "$_txn") [state=${_state:-<none>}]"
                _safe_name="orphan-$(basename "$_txn" | sed 's/^txn-//')"
                if mv "$_txn" "$PERSISTENT_BACKUP/$_safe_name" 2>/dev/null; then
                    ORPHAN_TXN_RENAMED=$((ORPHAN_TXN_RENAMED + 1))
                    log_msg "   Renamed to: $_safe_name (preserved)"
                fi
                ;;
        esac
    done
}

if [ -d "$PERSISTENT_BACKUP" ]; then
    _resolve_txn_dirs

    if [ "$ORPHAN_TXN_CLEANED" -gt 0 ]; then
        log_msg "✅ Removed $ORPHAN_TXN_CLEANED orphan transaction(s)"
    fi
    if [ "$ORPHAN_TXN_RENAMED" -gt 0 ]; then
        log_msg "✅ Preserved $ORPHAN_TXN_RENAMED unfinished transaction(s)"
        log_msg "   Inspect manually: ls $PERSISTENT_BACKUP/orphan-txn-*"
    fi
fi

# ============================================================
# [10] Cleanup any legacy backup directory (v1.0.0)
# ============================================================
LEGACY_BACKUP_REMOVED=0
if [ -d "$LEGACY_BACKUP_DIR" ]; then
    if rm -rf "$LEGACY_BACKUP_DIR" 2>/dev/null; then
        LEGACY_BACKUP_REMOVED=1
        log_msg "🗑️  Removed legacy backup directory: $LEGACY_BACKUP_DIR"
    else
        log_msg "⚠️ Failed to remove legacy backup directory: $LEGACY_BACKUP_DIR"
    fi
else
    log_msg "ℹ️ No legacy backup directory present (nothing to remove)"
fi

# ============================================================
# [11] Main cleanup
# ============================================================
# The cleanup runs exactly ONCE. The single invocation is:
#   • Inline: _inline_kill_all + _inline_cleanup_firewall.
#
# _inline_kill_all:
#   - kills dnscrypt-proxy and dnscrypt-webui,
#   - kills watchdog.sh via pattern (v1.5.0+fix),
#   - polls for actual death (0.1s × 30),
#   - fuser -k on the DNS ports.
#
# _inline_cleanup_firewall:
#   - nftables: delete the dnscrypt_filter table,
#   - iptables: flush/delete DNSCRYPT_OUT + legacy cleanup,
#   - ip6tables: flush/delete DNSCRYPT_OUT6.
log_msg "🧹 Starting cleanup..."
_inline_kill_all
_inline_cleanup_firewall
log_msg "✅ Process & firewall cleanup completed"

# ============================================================
# [12] Reset DNS settings
# ============================================================
# Removes the module's changes to three system settings:
#
#   1. private_dns_mode
#   2. net.ipv4.conf.all.route_localnet
#   3. ndc resolver flushdefaultif
#
# All three are best-effort: a failure at any step is logged
# but does not abort the uninstall.
log_msg "🔄 Resetting DNS settings..."

_wait=0
while [ "$_wait" -lt 10 ]; do
    if settings get global private_dns_mode >/dev/null 2>&1; then
        break
    fi
    sleep 1
    _wait=$((_wait + 1))
done

if [ "$_wait" -ge 10 ]; then
    log_msg "⚠️ settings service not ready after 10s, attempting anyway..."
fi

if settings delete global private_dns_mode 2>/dev/null; then
    log_msg "✅ private_dns_mode reset to AUTO"
else
    log_msg "⚠️ Failed to reset private_dns_mode (continuing)"
fi

if [ -n "$ORIGINAL_ROUTE_LOCALNET" ] && command -v sysctl >/dev/null 2>&1; then
    if sysctl -w "net.ipv4.conf.all.route_localnet=$ORIGINAL_ROUTE_LOCALNET" >/dev/null 2>&1; then
        log_msg "✅ route_localnet restored to $ORIGINAL_ROUTE_LOCALNET"
    else
        log_msg "⚠️ Failed to restore route_localnet (was $ORIGINAL_ROUTE_LOCALNET)"
    fi
else
    if command -v sysctl >/dev/null 2>&1; then
        sysctl -w net.ipv4.conf.all.route_localnet=0 >/dev/null 2>&1
        log_msg "✅ route_localnet set to 0 (default)"
    fi
fi

if command -v ndc >/dev/null 2>&1; then
    if ndc resolver flushdefaultif 2>/dev/null; then
        log_msg "✅ DNS resolver flushed via ndc"
    else
        log_msg "⚠️ ndc resolver flush failed (non-fatal)"
    fi
fi

log_msg "✅ DNS reset completed"

# ============================================================
# [13] Cleanup run/ files
# ============================================================
# The module's run directory is at $MODDIR/proxy/run/. It
# holds all runtime state. Removed with a single `rm -rf`.
#
# The success check is `[ ! -d "$RUN_DIR" ]` — it verifies
# the directory is actually gone, rather than trusting `rm`'s
# exit code.
log_msg "🗑️  Removing run/ files..."

RUN_COUNT=0

if [ -d "$RUN_DIR" ]; then
    rm -rf "$RUN_DIR" 2>/dev/null
    if [ ! -d "$RUN_DIR" ]; then
        RUN_COUNT=1
    fi
    log_msg "✅ Removed run/ directory"
else
    log_msg "ℹ️ run/ directory not found (was it ever created?)"
fi

# ============================================================
# [14] Cleanup runtime files (in /data/local/tmp)
# ============================================================
# ⚠️ IMPORTANT: this section removes `dnscrypt_main.log` and
# then sets `LOG_DISABLED=1`. After this point, `log_msg()`
# becomes a silent no-op — the file is NOT re-created by any
# subsequent section.
#
# Categories of files removed:
#   a) PID files (7 paths)
#   b) STATUS + progress files (2 paths)
#   c) Credentials files (2 paths)
#   d) Log files (8 paths)
#   e) Log rotation sidecars (patterns)
#   f) Filter caches (patterns)
#   g) Bootstrap cache (2 paths)
#   h) Stale locks from crashed starts (v1.5.0+fix)
log_msg "🗑️  Removing runtime files from /data/local/tmp..."

RUNTIME_COUNT=0

# --- (a) PID files ---
for f in /data/local/tmp/dnscrypt.pid \
         /data/local/tmp/webui.pid \
         /data/local/tmp/watchdog.pid \
         /data/local/tmp/webui.pid.tmp \
         /data/local/tmp/watchdog.pid.tmp \
         /data/local/tmp/webui_tmp.pid \
         /data/local/tmp/watchdog_tmp.pid; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

# --- (b) Status + progress files ---
for f in /data/local/tmp/dnscrypt.status \
         /data/local/tmp/update_progress.txt; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

# --- (c) Credentials files ---
for f in /data/local/tmp/dnscrypt_credentials.txt \
         /data/local/tmp/.dnscrypt_credentials_shown; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

# --- (d) Log files ---
for f in /data/local/tmp/dnscrypt_install.log \
         /data/local/tmp/dnscrypt-query.log \
         /data/local/tmp/dnscrypt-blocked.log \
         /data/local/tmp/dnscrypt-blocked-ips.log \
         /data/local/tmp/dnscrypt-allowed.log \
         /data/local/tmp/dnscrypt-proxy.log \
         /data/local/tmp/dnscrypt-proxy.log.latest \
         /data/local/tmp/dnscrypt_main.log; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

# --- (e) Log rotation sidecars ---
for pattern in \
    "/data/local/tmp/dnscrypt_main.log.*.old" \
    "/data/local/tmp/dnscrypt_main.log.old" \
    "/data/local/tmp/dnscrypt_main.log.*.gz" \
    "/data/local/tmp/dnscrypt_main.log.emergency.*" \
    "/data/local/tmp/dnscrypt-proxy.log.*.gz" \
    "/data/local/tmp/dnscrypt-proxy.log.*.old"; do
    for f in $pattern; do
        [ -f "$f" ] || continue
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    done
done

# --- (f) Filter caches ---
for pattern in \
    "/data/local/tmp/*.filtered" \
    "/data/local/tmp/*.filtered.count" \
    "/data/local/tmp/_allow_norm.txt" \
    "/data/local/tmp/_deny_norm.txt"; do
    for f in $pattern; do
        [ -f "$f" ] || continue
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    done
done

# --- (g) Bootstrap cache (both locations) ---
for f in "$RUN_DIR/.bootstrap_cache" \
         "/data/local/tmp/.bootstrap_cache"; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

# --- (h) Stale locks from crashed starts (v1.5.0+fix) ---
# main.go and watchdog.sh use atomic mkdir locks under
# $RUN_DIR. If the module was uninstalled while a start was
# in progress (rare but possible), the locks could remain
# under /data/local/tmp (the fallback location). §[13] removed
# $RUN_DIR entirely, but the /data/local/tmp copies are
# removed here.
for f in /data/local/tmp/.service.start.lock \
         /data/local/tmp/.watchdog.pid.lock; do
    if [ -d "$f" ]; then
        rm -rf "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

# ------------------------------------------------------------
# Disable logging from this point forward.
# The log file has just been removed above. Any subsequent
# log_msg() call would re-create it — the LOG_DISABLED flag
# short-circuits those calls.
# ------------------------------------------------------------
LOG_DISABLED=1

# ============================================================
# [15] Cleanup module configuration files
# ============================================================
# Removes every configuration and state file from $BIN_DIR.
# After this section, the directory should contain only the
# binaries. The root manager will remove the entire module
# folder after this script exits, so the removal here is
# defensive.
MODULE_COUNT=0

if [ -d "$BIN_DIR" ]; then
    # --- (a) Profile + WebUI config ---
    for f in selected_profile.txt \
             webui.conf \
             webui.conf.tmp \
             dnscrypt-proxy.toml \
             dnscrypt-proxy.toml.bak; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    # --- (b) Blocklist files ---
    for f in blocklist.txt \
             blocklist.txt.tmp \
             blocklist.txt.bak \
             blocklist.txt.filtered \
             blocklist.txt.rules_tmp \
             blocklist.raw \
             blocklist.raw.tmp \
             blocklist.raw.tmp_write \
             blocklist.raw.bak \
             blocklist.raw.filtered \
             blocklist.raw.filtered.tmp \
             blocked-ips.txt; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    # --- (c) Allowlist + denylist ---
    for f in allowlist.txt \
             allowlist.txt.tmp_write \
             denylist.txt \
             denylist.txt.tmp_write; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    # --- (d) Auth files (legacy) ---
    for f in auth.json .auth_token; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    # --- (e) Resolver lists ---
    for f in public-resolvers.md \
             public-resolvers.md.minisig \
             relays.md \
             relays.md.minisig; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done
fi

# ============================================================
# [16] Remove module fingerprint and disable file
# ============================================================
# Two files in the module root:
#
#   • .module.fingerprint — a single-line marker written by
#     customize.sh §[20]. Read by main.go:checkOldModules()
#     and main.go:removeModule().
#   • disable — the Magisk/KernelSU "module disabled" marker.
if [ -f "$MODDIR/.module.fingerprint" ]; then
    rm -f "$MODDIR/.module.fingerprint" 2>/dev/null
fi

if [ -f "$MODDIR/disable" ]; then
    rm -f "$MODDIR/disable" 2>/dev/null
fi

# ============================================================
# [16b] Remove recovery triggers
# ============================================================
# Two recovery-trigger files exist:
#
#   • RECOVERY_TRIGGER_1 = $MODDIR/recovery
#     In-module trigger. Removed here because if the module
#     folder is left in place (partial uninstall, or
#     reinstall-triggered race), a leftover trigger would
#     spuriously enter recovery mode on the next install.
#
#   • RECOVERY_TRIGGER_2 = /data/adb/dnscrypt-recovery
#     External trigger. Magisk does NOT remove it when the
#     module is uninstalled. Its only meaning is "the NEXT
#     install should enter recovery mode". Once the module is
#     gone, that meaning is void — so the file is removed here.
RECOVERY_TRIGGER_REMOVED=0
RECOVERY_TRIGGER_INTERNAL_REMOVED=0

if [ -f "$RECOVERY_TRIGGER_2" ]; then
    if rm -f "$RECOVERY_TRIGGER_2" 2>/dev/null; then
        RECOVERY_TRIGGER_REMOVED=1
    fi
fi

if [ -f "$RECOVERY_TRIGGER_1" ]; then
    if rm -f "$RECOVERY_TRIGGER_1" 2>/dev/null; then
        RECOVERY_TRIGGER_INTERNAL_REMOVED=1
    fi
fi

# ============================================================
# [17] PRESERVE the persistent backup directory
# ============================================================
# This section is the counterpart to [10]'s legacy cleanup.
# Where [10] removes the v1.0.0 backup at
# /data/local/tmp/dnscrypt_backup_uninstall/, [17] explicitly
# PRESERVES the v1.2.0+ backup at /sdcard/dnscrypt-webui-backup/.
#
# The preservation is not implemented by an action — there is
# no `mv` or `cp` here. The directory survives because NOTHING
# in this script touches it.
#
# [18] reports what will survive, so the user sees the
# preservation in the output before the script exits.
# ============================================================

# ============================================================
# [17b] Compute the FINAL orphan-txn count
# ============================================================
# The initial BACKUP_ORPHAN_COUNT ([5b]) was captured BEFORE
# [9] renamed any START/no-state transactions. The final report
# must reflect the post-rename count.
BACKUP_ORPHAN_FINAL=$((BACKUP_ORPHAN_COUNT + ORPHAN_TXN_RENAMED))

# ============================================================
# [18] User-facing final message
# ============================================================
# The counterpart to the (removed) log-based summary. This
# section prints a human-friendly message to stdout. The
# Magisk/KernelSU manager captures this stdout and shows it
# to the user after the uninstall completes.
#
# Three cases drive the message body:
#   Case A: backup dir exists AND has ≥ 1 snapshot
#   Case B: backup dir exists but is empty
#   Case C: backup dir does not exist
#
# Two optional blocks may be appended:
#   • Orphan transaction notice (if BACKUP_ORPHAN_FINAL > 0).
#   • Recovery trigger notice (if either trigger was removed).
#
# Note: [14] set LOG_DISABLED=1. From that point on, log_msg
# is a silent no-op. This section uses raw `echo` (unaffected
# by LOG_DISABLED) and is therefore the canonical place for
# user-facing output.
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  DNSCrypt Smart Filter — Uninstall Complete"
echo "════════════════════════════════════════════════════════════"
echo ""

if [ -d "$PERSISTENT_BACKUP" ] && [ "$BACKUP_COUNT" -gt 0 ]; then
    echo "  💾 Your settings have been PRESERVED for future use:"
    echo ""
    echo "     Location:  $PERSISTENT_BACKUP"
    echo "     Snapshots: $BACKUP_COUNT"
    if [ -n "$BACKUP_LAST_NAME" ]; then
        echo "     Latest:    $BACKUP_LAST_NAME"
    fi
    if [ -n "$BACKUP_LAST_STABLE" ]; then
        echo "     Last stable: $BACKUP_LAST_STABLE"
    fi

    if [ -n "$USER_FILES" ]; then
        echo ""
        echo "     Preserved files:"
        for _uf in $USER_FILES; do
            echo "       - $_uf"
        done
    fi

    if [ "$APK_MIRROR_PRESENT" = "1" ]; then
        echo ""
        if [ "$APK_MIRROR_SHA_PRESENT" = "1" ]; then
            echo "     APK mirror: $APK_MIRROR_DIR/"
            echo "                 (${APK_MIRROR_SIZE_BYTES} bytes + .sha256)"
        else
            echo "     APK mirror: $APK_MIRROR_DIR/"
            echo "                 (${APK_MIRROR_SIZE_BYTES} bytes)"
        fi
    fi

    echo ""
    echo "  ✅ If you reinstall the module later, your settings will"
    echo "     be restored automatically from this backup."
    if [ "$APK_MIRROR_PRESENT" = "1" ]; then
        echo ""
        echo "  📱 The companion APK mirror is still available at:"
        echo "     $APK_MIRROR_FILE"
        if [ "$APK_MIRROR_SHA_PRESENT" = "1" ]; then
            echo "     $APK_MIRROR_SHA_FILE"
        fi
        echo "     (find it via any file manager — no root needed)"
    fi
    echo ""
    echo "  ⚠️  If you want to remove them manually:"
    echo "     su -c \"rm -rf $PERSISTENT_BACKUP\""
elif [ -d "$PERSISTENT_BACKUP" ]; then
    echo "  ℹ️  Persistent backup directory exists but contains"
    echo "     no snapshots yet: $PERSISTENT_BACKUP"
    echo ""
    echo "  ⚠️  You can remove it manually if you wish:"
    echo "     su -c \"rm -rf $PERSISTENT_BACKUP\""
else
    echo "  ℹ️  No persistent backup was found."
    echo ""
    echo "  The module did not create a backup in this installation,"
    echo "  so there is nothing to preserve."
fi

# ------------------------------------------------------------------
# Orphan transaction notice
# ------------------------------------------------------------------
# Uses the FINAL count (BACKUP_ORPHAN_FINAL) which includes any
# txn-* directories that [9] renamed to orphan-txn-* during
# this run.
# ------------------------------------------------------------------
if [ "$BACKUP_ORPHAN_FINAL" -gt 0 ]; then
    echo ""
    echo "  ⚠️  Unfinished transactions were PRESERVED:"
    echo ""
    echo "     Directory: $PERSISTENT_BACKUP/orphan-txn-*"
    if [ "$ORPHAN_TXN_RENAMED" -gt 0 ]; then
        echo ""
        echo "  Note: $ORPHAN_TXN_RENAMED txn-* director(ies) were"
        echo "        renamed to orphan-txn-* during this uninstall"
        echo "        (they were preserved, not deleted)."
    fi
    echo ""
    echo "  These directories may contain the only copy of your data"
    echo "  from an interrupted install. Inspect them manually:"
    echo "     su -c \"ls -la $PERSISTENT_BACKUP/orphan-txn-*/\""
    echo "     su -c \"cat $PERSISTENT_BACKUP/orphan-txn-*/.state\""
fi

# ------------------------------------------------------------------
# Recovery trigger notice
# ------------------------------------------------------------------
if [ "$RECOVERY_TRIGGER_REMOVED" = "1" ]; then
    echo ""
    echo "  ℹ️  A pending recovery trigger was removed:"
    echo "     $RECOVERY_TRIGGER_2"
    echo "     (It had no meaning once the module was uninstalled.)"
fi

if [ "$RECOVERY_TRIGGER_INTERNAL_REMOVED" = "1" ]; then
    echo ""
    echo "  ℹ️  An in-module recovery trigger was also removed:"
    echo "     $RECOVERY_TRIGGER_1"
fi

# ------------------------------------------------------------------
# Companion app notice
# ------------------------------------------------------------------
echo ""
echo "  ℹ️  The companion Android app is not affected by this uninstall:"
echo "       • The module-internal APK is removed with the module folder."
echo "       • The /sdcard/.../apk/ mirror survives (see above)."
echo "       • Any separately-installed companion app remains on your"
echo "         device — uninstall it from Android Settings if desired."

# ------------------------------------------------------------------
# Cleanup notices
# ------------------------------------------------------------------
if [ "$RUN_COUNT" = "1" ]; then
    echo ""
    echo "  🧹 Runtime directory (run/) was removed."
fi

if [ "$LEGACY_BACKUP_REMOVED" = "1" ]; then
    echo ""
    echo "  🧹 Legacy v1.0.0 backup directory was removed:"
    echo "     $LEGACY_BACKUP_DIR"
fi

echo ""
echo "  Exit code: 0 (success)"
echo "════════════════════════════════════════════════════════════"
echo ""

# ============================================================
# [19] Exit
# ============================================================
# No final `rm -f "$LOG_FILE"` is needed:
#
#   [14] removed $LOG_FILE and set LOG_DISABLED=1. From that
#   point on, log_msg became a silent no-op, so [15]..[18] did
#   NOT re-create the log file.
#
# The exit code is 0 — the uninstall completed successfully.
# Errors during the cleanup phases were logged and reported
# above, but the script's contract is "best-effort teardown":
# the root manager removes the module folder after this
# script exits regardless of any individual cleanup step.
# ============================================================
exit 0