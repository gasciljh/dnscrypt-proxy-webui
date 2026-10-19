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
# Triggered automatically when the module is removed via the
# root manager, or manually for cleanup.
#
# Responsibilities:
#   • Kill all running processes (dnscrypt-proxy, dnscrypt-webui)
#     and WAIT for them to actually exit before proceeding.
#   • Clean the firewall (Custom Chains + Legacy).
#   • Reset system DNS settings (private_dns_mode).
#   • Restore the original route_localnet value.
#   • Remove runtime files (run/, PIDs, STATUS_FILE, logs, caches).
#   • Remove module configuration files.
#   • Remove the module fingerprint + disable file.
#   • Resolve txn-* directories:
#       – COMMIT              → removed (self-cleanup interrupted)
#       – ROLLBACK / empty    → removed (rollback already applied)
#       – START / no state    → RENAMED to orphan-txn-* and PRESERVED
#   • PRESERVE pre-existing orphan-txn-* directories.
#   • Remove any legacy backup directory from v1.0.0.
#   • PRESERVE the persistent backup directory
#     (/sdcard/dnscrypt-webui-backup/) so the user can restore
#     their settings if they reinstall later.
#   • PRESERVE the companion APK mirror
#     (/sdcard/dnscrypt-webui-backup/apk/).
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
#   • create RUN_DIR and .bootstrap_cache — files that this
#     script is about to delete,
#   • run functions.sh's top-level initialization, which is
#     counterproductive at uninstall time.
#
# More importantly, uninstall.sh must work even when
# functions.sh is missing or corrupt. It is the last script the
# module runs — if it depends on a broken library, the user is
# left with no way to clean up.
#
# Consequence: firewall cleanup and process cleanup below are
# inline, even though equivalent functions live in
# functions.sh. The duplication is intentional.
#
# Backup policy (IMPORTANT):
# ============================================================
# This script does NOT delete /sdcard/dnscrypt-webui-backup/.
#
# The persistent backup directory contains:
#   • The 5 user config files snapshotted at every upgrade.
#   • The companion APK mirror at apk/ (created best-effort by
#     customize.sh §[10c]).
#
# Preserving this directory allows the user to:
#   1. Reinstall the module later and recover settings
#      automatically.
#   2. Inspect, copy, or back up their configuration manually.
#   3. Find the companion APK via a file manager without root
#      access to /data/adb/.
#
# The user can delete the whole directory at any time:
#     su -c "rm -rf /sdcard/dnscrypt-webui-backup"
#
# Transaction handling:
# ============================================================
# Four cases for txn-* directories:
#
#   1. State "COMMIT"      → removed (leftover from a successful
#                            install that was interrupted before
#                            its own cleanup).
#   2. State "ROLLBACK"    → removed (rollback was applied).
#   3. State "START"       → renamed to orphan-txn-* and
#                            preserved (may contain the only copy
#                            of the user's data).
#   4. No .state (or empty) → renamed to orphan-txn-* and
#                            preserved (covers the crash-between-
#                            mkdir-and-echo case).
#
# Any pre-existing orphan-txn-* directories are PRESERVED as-is.
#
# POSIX note on `local`:
# ============================================================
# This script uses `local` inside three helper functions:
#   • _inline_cleanup_firewall  (_chain, _chain6, _ip)
#   • _inline_kill_all          (_ki_wait, _ki_alive)
#   • _resolve_txn_dirs         (_txn, _state, _safe_name)
#
# `_uninstall_list_snapshots` uses SUBSHELL ISOLATION instead
# of `local`. Its loop body runs inside a `( ... )` subshell, so
# the loop variables exist only there and never leak into the
# parent shell.
#
# The `local` keyword is supported by mksh, busybox ash, bash,
# dash, and ksh — every shell Android ships.
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

# --- Data preservation paths ---
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"

# The 5 files the persistent backup directory preserves.
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# --- Companion APK mirror paths ---
# Lives inside the persistent backup directory; preserved
# automatically. Used by §[5b] (detection) and §[18] (report).
APK_MIRROR_DIR="$PERSISTENT_BACKUP/apk"
APK_MIRROR_FILE="$APK_MIRROR_DIR/app-debug.apk"
APK_MIRROR_SHA_FILE="$APK_MIRROR_DIR/app-debug.apk.sha256"

# --- Recovery trigger paths ---
RECOVERY_TRIGGER_1="$MODDIR/recovery"
RECOVERY_TRIGGER_2="/data/adb/dnscrypt-recovery"

# Legacy backup directory (v1.0.0) — cleaned up below.
LEGACY_BACKUP_DIR="/data/local/tmp/dnscrypt_backup_uninstall"

# ============================================================
# [4] Protected log helper
# ============================================================
# Appends a timestamped line to $LOG_FILE with the
# `[UNINSTALL]` prefix.
#
# The `LOG_DISABLED` flag short-circuits all writes once §[14]
# has removed the log file. Without it, the log is auto-created
# by every subsequent call, requiring a final `rm` at the end
# of the script.
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
#   1. MODDIR must be inside /data/adb/modules/ — the canonical
#      Magisk/KernelSU/APatch location. A MODDIR outside this
#      tree is almost certainly a bug or a malicious wrapper,
#      and the script refuses to proceed (exit 1).
#
#   2. MODDIR must not be exactly /data/adb/modules — that
#      would be the parent directory of every module, and
#      removing it would destroy every installed module.
#      Exit 1 on detection.
#
#   3. The module's basename should start with "dnscrypt"
#      (case-insensitive). A module folder with a different
#      name is suspicious but not necessarily fatal — the
#      script logs a warning and continues.
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
#   • SNAP-MANIFEST: a directory is treated as a snapshot iff
#     it contains a `.manifest.json` file.
#   • SNAP-MTIME: ordered by mtime, descending.
#
# Excludes (by name): current/, txn-*, orphan-txn-*,
# .restore_snap.*, apk/.
#
# Uses SUBSHELL ISOLATION (`( ... )`), not `local`, for its
# internal loop variables. The subshell serves three purposes:
#   1. The inner `cd "$PERSISTENT_BACKUP"` does not leak into
#      the parent shell.
#   2. The loop variables (`_d`, `_mt`) exist only in the
#      subshell — no name collisions are possible.
#   3. The function works on any POSIX sh implementation.
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
# Collects the state that the final summary (§[18]) reports to
# the user:
#
#   ACTIVE_PROFILE         — profile key (defaults to "unknown")
#   ROOT_SOLUTION          — "KernelSU" | "APatch" | "Magisk" | "unknown"
#   BACKUP_COUNT           — number of snapshots
#   BACKUP_LAST_NAME       — newest snapshot name, or empty
#   BACKUP_TXN_COUNT       — number of in-flight transaction dirs
#   BACKUP_ORPHAN_COUNT    — number of pre-existing orphan dirs
#   BACKUP_LAST_STABLE     — content of .last_stable, or empty
#   APK_MIRROR_PRESENT     — 1 if $APK_MIRROR_FILE exists
#   APK_MIRROR_SHA_PRESENT — 1 if the .sha256 sidecar exists
#   APK_MIRROR_SIZE_BYTES  — size of the mirror APK in bytes
#
# All counts are computed via subshells that do not leak `cd`
# into the parent. Numeric values are validated before use in
# any arithmetic.
#
# Note on BACKUP_ORPHAN_COUNT: this is the count of orphan-txn-*
# dirs that existed BEFORE §[9] ran. §[9] may rename additional
# txn-* dirs into orphan-txn-*, so §[17b] computes a FINAL count
# (`BACKUP_ORPHAN_FINAL`) that includes those renames.
ACTIVE_PROFILE="unknown"
if [ -f "$BIN_DIR/selected_profile.txt" ]; then
    _ap=$(cat "$BIN_DIR/selected_profile.txt" 2>/dev/null | tr -d '\r\n ')
    case "$_ap" in
        light|normal|pro|proplus|ultimate) ACTIVE_PROFILE="$_ap" ;;
    esac
fi
log_msg "Active profile at uninstall: $ACTIVE_PROFILE"

# --- Root solution detection ---
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

# --- Count preserved snapshots ---
BACKUP_COUNT=0
BACKUP_LAST_NAME=""
BACKUP_LAST_STABLE=""
BACKUP_TXN_COUNT=0
BACKUP_ORPHAN_COUNT=0

# APK mirror presence flags — set here (not in [18]) so that
# [18] can report the mirror without re-probing the filesystem.
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

    # Detect the companion APK mirror and its optional .sha256
    # sidecar. Informational only — the mirror is preserved
    # automatically because it lives inside $PERSISTENT_BACKUP.
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

# --- Read pending notification (informational only) ---
if [ -f "$PENDING_NOTIFY_FILE" ]; then
    _pn=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$_pn" ]; then
        log_msg "Pending notification: $_pn"
    fi
fi

# ============================================================
# [6] Save route_localnet before changing it
# ============================================================
# The kernel's `net.ipv4.conf.all.route_localnet` sysctl
# controls whether the kernel accepts packets with a loopback
# source address arriving on a non-loopback interface. Some
# ROMs set it to 1 by default (usually for tethering or
# hotspot functionality).
#
# The module's firewall rules rely on this sysctl being enabled
# for DNAT'd DNS traffic to reach the loopback listener. On
# uninstall, the original value must be restored.
ORIGINAL_ROUTE_LOCALNET=""
if command -v sysctl >/dev/null 2>&1; then
    ORIGINAL_ROUTE_LOCALNET=$(sysctl -n net.ipv4.conf.all.route_localnet 2>/dev/null | tr -d '\r\n ')
fi

# ============================================================
# [7] Save the current EXIT trap (informational)
# ============================================================
# uninstall.sh does NOT install its own EXIT trap. Any EXIT
# trap the root manager may have installed remains in place —
# the script does not clobber it.
FUNCTIONS_LOADED=0
log_msg "Using inline cleanup (self-contained uninstaller)"

# ============================================================
# [8] Internal cleanup functions (self-contained)
# ============================================================
# _inline_kill_all terminates daemons and WAITS for exit.
#
# Fires `pkill -9` for both daemons, then polls `pgrep` for up
# to 3 seconds and only proceeds once both have disappeared.
# This prevents a process in D-state (uninterruptible sleep on
# I/O) from re-creating files inside a directory we believe to
# be gone.
#
# The function ends by calling `fuser -k` on the DNS ports.
# This is belt-and-suspenders: `fuser` catches the rare case
# where a process is bound to 5354/udp or 5354/tcp but is not
# named `dnscrypt-proxy`.
_inline_kill_all() {
    local _ki_wait=0
    local _ki_alive=0

    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-proxy 2>/dev/null
    fi
    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
    fi

    while [ "$_ki_wait" -lt 3 ]; do
        _ki_alive=0
        if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
            _ki_alive=1
        fi
        if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
            _ki_alive=1
        fi
        [ "$_ki_alive" -eq 0 ] && break
        sleep 1
        _ki_wait=$((_ki_wait + 1))
    done

    if [ "$_ki_wait" -ge 3 ]; then
        log_msg "⚠️ Process(es) still alive after 3s (likely D-state); continuing anyway"
    fi

    if command -v fuser >/dev/null 2>&1; then
        fuser -k 5354/udp 2>/dev/null
        fuser -k 5354/tcp 2>/dev/null
    fi
}

# _inline_cleanup_firewall — orphan prevention
# ============================================================
# Strategy:
#   1. Delete the DNSCRYPT_OUT / DNSCRYPT_OUT6 Custom Chains
#      entirely.
#   2. Best-effort legacy cleanup (rules from older versions).
#   3. No dependency on functions.sh (self-contained).
#
# Synchronization note:
#   This function removes the same SET of rules as:
#     • customize.sh    : _inline_cleanup_firewall
#     • post-fs-data.sh : inline_firewall_cleanup
#     • functions.sh    : manage_firewall 0
#   The files differ only in the comment tag applied to the
#   loopback (127.0.0.1) rules during the best-effort legacy
#   cleanup. Any change to the RULES removed by this function
#   MUST be applied consistently to all four.
#
# Three backends, in order:
#   1. nftables — delete the `dnscrypt_filter` table in all
#      three families (inet, ip, ip6).
#   2. iptables (IPv4) — remove the DNSCRYPT_OUT chain's jump
#      rules, flush and delete the chain, then best-effort
#      remove any legacy direct-DNAT rules and their RETURN
#      siblings.
#   3. ip6tables (IPv6) — same as (2), on the DNSCRYPT_OUT6
#      chain.
#
# Every individual command redirects stderr to /dev/null and
# never aborts the loop. A missing backend (no `nft` binary,
# no IPv6 support) causes its block to be skipped without
# error.
_inline_cleanup_firewall() {
    # --- [1] nftables: delete entire table ---
    if command -v nft >/dev/null 2>&1; then
        nft delete table inet dnscrypt_filter 2>/dev/null
        nft delete table ip dnscrypt_filter 2>/dev/null
        nft delete table ip6 dnscrypt_filter 2>/dev/null
    fi

    # --- [2] iptables (IPv4) — Custom Chain cleanup ---
    if command -v iptables >/dev/null 2>&1; then
        local _chain="DNSCRYPT_OUT"

        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain" --wait 3 2>/dev/null

        iptables -t nat -F "$_chain" --wait 3 2>/dev/null
        iptables -t nat -X "$_chain" --wait 3 2>/dev/null

        # Legacy cleanup
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

    # --- [3] ip6tables (IPv6) — Custom Chain cleanup ---
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
#   • "ROLLBACK" — removed. The rollback was applied; the
#                  snapshot is no longer needed.
#   • "START"    — renamed to orphan-txn-* and preserved.
#   • ""/other   — renamed to orphan-txn-* and preserved.
#                  Covers the crash-between-mkdir-and-echo case.
#
# The rename prefix is `orphan-` prepended to the original name
# with the `txn-` prefix stripped:
#   txn-20260101-120000-1234  →  orphan-20260101-120000-1234
# This preserves the timestamp and PID from the original
# transaction, which lets a user correlate an orphan with a
# specific failed install in the log.
#
# Counters ORPHAN_TXN_CLEANED and ORPHAN_TXN_RENAMED are global
# (readable by [17b] and [18]).
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
                # Covers:
                #   • state = "START"   (customize.sh wrote START)
                #   • state = ""        (crash before writing state;
                #                        preserve)
                #   • any unknown value (preserve defensively)
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
# v1.0.0 created a backup at
# /data/local/tmp/dnscrypt_backup_uninstall/ during uninstall.
# That behavior was removed in v1.1.0, but the directory itself
# is not removed by the root manager (it is outside the module
# folder), so it survives every subsequent upgrade and
# reinstall.
#
# This section removes that legacy directory if it exists. The
# user's REAL backup (the persistent
# /sdcard/dnscrypt-webui-backup/ tree) is completely separate
# and is preserved by [17].
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
#
#   • Inline: _inline_kill_all + _inline_cleanup_firewall.
#
# The inline path is the ONLY path — this script does not
# source functions.sh (see the design note at the top of the
# file).
#
# _inline_kill_all:
#   - kills dnscrypt-proxy and dnscrypt-webui,
#   - waits up to 3 s for both to exit,
#   - fuser -k on the DNS ports.
#
# _inline_cleanup_firewall:
#   - nftables: delete the dnscrypt_filter table,
#   - iptables: flush/delete DNSCRYPT_OUT + legacy cleanup,
#   - ip6tables: flush/delete DNSCRYPT_OUT6.
#
# The log line is emitted AFTER the cleanup completes, so a
# `tail -1 dnscrypt_main.log` mid-uninstall shows whether the
# process cleanup finished before the next section started.
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
#      The DNS-over-TLS setting in Android's network stack.
#      The module sets it (or leaves it unset) at install time;
#      the correct uninstall behavior is to DELETE the setting
#      so Android falls back to its own default (AUTO).
#
#      The `settings` service is often not ready immediately
#      after boot, so a bounded wait loop (up to 10 s) is
#      attempted before the delete.
#
#   2. net.ipv4.conf.all.route_localnet
#      The kernel sysctl that controls whether the kernel
#      accepts packets with a loopback source address arriving
#      on a non-loopback interface.
#
#      The original value was captured in [6] into
#      ORIGINAL_ROUTE_LOCALNET. This section restores it.
#
#      If ORIGINAL_ROUTE_LOCALNET is empty (sysctl was not
#      available at [6] time, or the read failed), the
#      fallback is to set the value to 0.
#
#   3. ndc resolver flushdefaultif
#      Flushes the DNS resolver cache for the default network
#      interface. Without this flush, the system may continue
#      using cached DNS answers obtained via the module's
#      DNAT'd path.
#
#      The flush is logged on BOTH success and failure — a
#      silent failure would leave the user with a hung
#      resolver and no trace in the log.
#
# All three operations are best-effort: a failure at any step
# is logged but does not abort the uninstall.
log_msg "🔄 Resetting DNS settings..."

# --- Wait for the settings service to become available ---
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

# --- Reset private_dns_mode ---
if settings delete global private_dns_mode 2>/dev/null; then
    log_msg "✅ private_dns_mode reset to AUTO"
else
    log_msg "⚠️ Failed to reset private_dns_mode (continuing)"
fi

# --- Restore route_localnet ---
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

# --- Flush the DNS resolver cache ---
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
# holds:
#   • dnscrypt.pid       — PID file of the DNS engine
#   • webui.pid          — PID file of the WebUI
#   • watchdog.pid       — PID file of the watchdog
#   • dnscrypt.status    — user intent ("ON" / "OFF")
#   • .watchdog_token    — 64-hex CSRF token shared with main.go
#   • .bootstrap_cache   — cached TTL-5min bootstrap resolver list
#   • update_progress.txt — progress file for /api?action=get_progress
#
# The whole directory is removed with a single `rm -rf`. The
# success check is `[ ! -d "$RUN_DIR" ]` — it verifies the
# directory is actually gone, rather than trusting `rm`'s exit
# code. On some Android filesystems, `rm -rf` can return 0
# even when a file inside the tree was not removed.
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
#   a) PID files (7 paths) — including .tmp sidecars and
#      alternative naming conventions from older versions.
#   b) STATUS + progress files (2 paths).
#   c) Credentials files (2 paths).
#   d) Log files (8 paths).
#   e) Log rotation sidecars (patterns).
#   f) Filter caches (patterns).
#   g) Bootstrap cache (2 paths).
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
# Removes every configuration and state file from
# $BIN_DIR (the module's proxy/ subdirectory). After this
# section, the directory should contain only:
#   • The two Go binaries (dnscrypt-proxy, dnscrypt-webui).
#   • Any per-architecture binaries not yet pruned.
#
# The root manager will remove the entire module folder after
# this script exits, so the removal here is defensive.
#
# Five groups of files, each with its own loop and its own
# counter increment (all accumulating into MODULE_COUNT):
#   a) Profile + WebUI config
#   b) Blocklist files
#   c) Allowlist + denylist
#   d) Auth files (legacy)
#   e) Resolver lists
#
# install_app.sh is deliberately NOT in this list. It lives
# inside the module folder, so the root manager deletes it
# when the module folder is removed.
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
#     customize.sh §[20]. Its content is
#     `dnscrypt-proxy-webui-<version>`. Read by:
#       - main.go:checkOldModules()  — to skip the current
#                                       install when scanning.
#       - main.go:removeModule()     — to refuse deletion of a
#                                       folder without the
#                                       fingerprint.
#     Removing it prevents a partially-removed module folder
#     from being mistaken for a valid install by a future
#     upgrade.
#
#   • disable — the Magisk/KernelSU "module disabled" marker.
#     Removing it is defensive.
#
# Both removals are best-effort.
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
#     The in-module trigger. Removed here because if the
#     module folder is left in place (partial uninstall, or
#     reinstall-triggered race), a leftover trigger would
#     spuriously enter recovery mode on the next install.
#
#   • RECOVERY_TRIGGER_2 = /data/adb/dnscrypt-recovery
#     The external trigger. This file lives OUTSIDE the module
#     directory, so Magisk does NOT remove it when the module
#     is uninstalled. Its only meaning is "the NEXT install
#     should enter recovery mode". Once the module is gone,
#     that meaning is void — so the file is removed here.
#
# Two separate flags track whether each file was actually
# present and removed. [18] uses them to decide whether to
# mention the removal in the summary.
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
#
# The companion APK mirror at apk/ is inside this directory,
# so it is preserved automatically.
# ============================================================

# ============================================================
# [17b] Compute the FINAL orphan-txn count
# ============================================================
# The initial BACKUP_ORPHAN_COUNT ([5b]) was captured BEFORE
# [9] renamed any START/no-state transactions. The final report
# must reflect the post-rename count.
#
# Both consumers ([18] log and [18] user message) must use
# BACKUP_ORPHAN_FINAL, never the raw BACKUP_ORPHAN_COUNT.
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
#
#   Case A: backup dir exists AND has ≥ 1 snapshot
#     → "Your settings have been PRESERVED" block, with the
#       5 preserved config files listed by name, the APK
#       mirror if present, and the manual removal command.
#
#   Case B: backup dir exists but is empty
#     → "directory exists but contains no snapshots" notice.
#
#   Case C: backup dir does not exist
#     → "No persistent backup was found" notice.
#
# Two optional blocks may be appended regardless of case:
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
#   NOT re-create the log file. The final state is the same as
#   the original design (no residual log), achieved without
#   the trailing `rm`.
#
# The exit code is 0 — the uninstall completed successfully.
# Errors during the cleanup phases were logged and reported
# above, but the script's contract is "best-effort teardown":
# the root manager removes the module folder after this
# script exits regardless of any individual cleanup step.
# ============================================================
exit 0