#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – uninstall.sh
# Version: v1.2.0 (Global Edition)
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Magisk / KernelSU / APatch uninstall script.
#
#   Triggered automatically when the module is removed via the
#   Magisk/KernelSU manager, or manually for cleanup.
#
# Responsibilities (v1.2.0):
#   • Kill all running processes (dnscrypt-proxy, dnscrypt-webui)
#     and WAIT for them to actually exit before proceeding.
#   • Clean the firewall (Custom Chains + Legacy)
#   • Reset system DNS settings (private_dns_mode)
#   • Restore the original route_localnet value
#   • Remove runtime files (run/, PIDs, STATUS_FILE, logs, caches)
#   • Remove module configuration files (webui.conf, .toml, blocklists)
#   • Remove the module fingerprint + disable file
#   • Remove the external recovery trigger
#   • Resolve txn-* directories (Layer 4 — v1.2.0):
#       – COMMIT              → removed (self-cleanup was interrupted)
#       – ROLLBACK / empty    → removed (rollback already applied)
#       – START               → RENAMED to orphan-txn-* and PRESERVED
#       – no .state           → RENAMED to orphan-txn-* and PRESERVED
#     (see [0.2] for the complete policy and rationale)
#   • PRESERVE pre-existing orphan-txn-* directories
#   • Remove any legacy backup directory from v1.0.0
#   • PRESERVE the persistent backup directory
#     (/sdcard/dnscrypt-webui-backup/) so the user can restore
#     their settings if they reinstall later (Layer 2 — v1.2.0)
#   • Notify the user of the backup location and count
#
# Options:
#   uninstall.sh          Full cleanup (default)
#   uninstall.sh --help   Show help
#
# Exit codes:
#   0 = success (full or partial cleanup completed)
#   1 = security violation (MODDIR outside expected paths)
#   2 = unknown command-line argument
#
# ============================================================
# [0] v1.2.0 — Backup policy (IMPORTANT)
# ============================================================
# This script does NOT delete /sdcard/dnscrypt-webui-backup/.
#
# The persistent backup directory contains the 5 user config
# files snapshotted at every upgrade and at every pre-critical
# operation (profile change, allowlist/denylist save).
#
# Preserving this directory allows the user to:
#   1. Reinstall the module later and recover their settings
#      automatically (Layer 1 + Layer 2 multi-source detection).
#   2. Manually inspect, copy, or back up their configuration
#      to another device before the SD card is wiped.
#
# The user can delete it manually at any time:
#     su -c "rm -rf /sdcard/dnscrypt-webui-backup"
#
# ============================================================
# [0.1] v1.1.0 — No auto-backup on uninstall
# ============================================================
# Previous versions (v1.0.0) created a backup at:
#   /data/local/tmp/dnscrypt_backup_uninstall/
#
# This behavior was intentionally removed in v1.1.0. The reason:
#   • The module no longer ships a restore utility for that
#     specific path.
#   • A v1.0.0-style backup created false expectations of
#     recoverability.
#   • Users who want to keep settings should do so manually,
#     OR rely on the v1.2.0 persistent backup directory
#     (/sdcard/dnscrypt-webui-backup/) which survives uninstall.
#
# Any existing backup directory from v1.0.0 is cleaned up
# automatically by this script (see section [10]).
#
# ============================================================
# [0.2] v1.2.0 — Transaction handling on uninstall
# ============================================================
# The transaction system (Layer 4) creates directories like:
#   /sdcard/dnscrypt-webui-backup/txn-<timestamp>-<pid>/
#
# During uninstall, four cases are handled:
#
#   1. txn-* with state "COMMIT"
#      → Removed. This is a leftover from a successful install
#        that was interrupted before its own cleanup step.
#
#   2. txn-* with state "ROLLBACK"
#      → Removed. The rollback was already applied; the
#        snapshot is no longer needed.
#
#   3. txn-* with state "START"
#      → RENAMED to orphan-txn-<timestamp>-<pid> and PRESERVED.
#        This transaction was interrupted mid-flight. The
#        directory may contain the only copy of a user's data.
#
#   4. txn-* with NO .state file (or an empty .state)
#      → RENAMED to orphan-txn-<timestamp>-<pid> and PRESERVED.
#        The transaction was interrupted between `mkdir` and
#        the `echo START > .state` step. As with case 3, the
#        directory may contain the only copy of a user's data.
#        See UNI-6 fix for the rationale.
#
# Any pre-existing orphan-txn-* directories are PRESERVED
# as-is — they are the user's explicit signal that they want
# to inspect them.
#
# See docs/BACKUP.md §7 and docs/EMERGENCY.md for details.
#
# ============================================================
# [0.3] v1.2.0 — The 10 defensive layers (context)
# ============================================================
#   ┌────┬──────────────────────┬─────────────────────┐
#   │ #  │ Layer                │ Role of uninstall   │
#   ├────┼──────────────────────┼─────────────────────┤
#   │ 1  │ Multi-source detect  │ install-time only   │
#   │ 2  │ Persistent backup    │ PRESERVED (not rem) │
#   │ 3  │ Integrity verify     │ install-time only   │
#   │ 4  │ Transactional upgrad │ cleanup + preserve  │
#   │ 5  │ Root-solution compat │ detected for summary│
#   │ 6  │ SELinux preservation │ not applicable      │
#   │ 7  │ Recovery mode        │ trigger cleaned     │
#   │ 8  │ Config migrations    │ install-time only   │
#   │ 9  │ Automation + rotation│ not applicable      │
#   │ 10 │ Observability        │ final summary       │
#   └────┴──────────────────────┴─────────────────────┘
#
#   Uninstall touches Layer 4 (transaction cleanup), Layer 7
#   (external recovery trigger cleanup), and reads Layer 10
#   (final summary). All other layers are either install-time
#   concerns or explicitly preserved.
#
# ============================================================
# v1.2.0 — POST-AUDIT FIXES (still v1.2.0)
# ============================================================
#   🔧 UNI-1 — External recovery trigger (/data/adb/dnscrypt-
#     recovery) is now removed during uninstall (section [16b]).
#
#   🔧 UNI-2 — Corrected the [8] comment to describe the actual
#     functional divergence vs customize.sh (loopback comment tag).
#
#   🔧 UNI-3 — `_ip` inside the legacy RETURN cleanup loop is now
#     declared `local`.
#
#   🔧 UNI-4 — The user-facing message in [19] now mentions the
#     START → orphan-txn rename behavior.
#
# ============================================================
# v1.2.0 (Global Edition) — Additional hardening in this revision
# ============================================================
#   🛡️ HARD-UNI-01 (was UNI-5) — `BACKUP_ORPHAN_COUNT` was
#     computed in [5b] BEFORE [9] renamed any START/no-state
#     transactions to orphan-txn-*. The final report therefore
#     printed a stale count. A new derived variable
#     `BACKUP_ORPHAN_FINAL = BACKUP_ORPHAN_COUNT + ORPHAN_TXN_RENAMED`
#     is now used by [18] and [19].
#
#   🛡️ HARD-UNI-02 (was UNI-6) — A `txn-*` directory WITHOUT a
#     `.state` file (or with an empty `.state`) is no longer
#     deleted. It is now RENAMED to orphan-txn-* and PRESERVED,
#     on the assumption that a crash occurred between `mkdir`
#     and the `echo START > .state` step of customize.sh.
#
#   🛡️ HARD-UNI-03 (was UNI-7) — `functions.sh` is no longer
#     sourced unconditionally in [7]. Sourcing it had the side
#     effect of creating $RUN_DIR and the bootstrap cache via
#     `init_runtime_paths`, which the script was about to
#     delete anyway. The guard now checks for the specific
#     symbol we need (`aggressive_cleanup`) without running
#     the file's top-level initialization.
#
#   🛡️ HARD-UNI-04 (was UNI-8) — The inline cleanup is now
#     invoked exactly ONCE in [11], regardless of whether
#     `aggressive_cleanup` was used. Previously the inline path
#     ran twice (belt-and-suspenders), which duplicated every
#     `iptables -D` / `nft delete` call and added log noise.
#
#   🛡️ HARD-UNI-05 (was UNI-9) — Unknown command-line arguments
#     are now a hard error (exit 2), instead of being silently
#     ignored. A typo like `uninstall.sh --dry-run` no longer
#     triggers a full, silent uninstall.
#
#   🛡️ HARD-UNI-06 (was UNI-10) — The top-level
#     "Responsibilities" list has been rewritten to describe
#     the actual behavior of the transaction resolver
#     (delete COMMIT/ROLLBACK, rename-and-preserve START/no-state).
#
#   🛡️ HARD-UNI-07 (was UNI-11) — The comment in [16b] about a
#     "race with the root manager" has been corrected. The
#     reason for not removing RECOVERY_TRIGGER_1 is simply
#     that the root manager deletes the whole module folder
#     after this script exits, so a manual removal here would
#     be redundant.
#
# ============================================================
# v1.2.0 (Global Edition) — Follow-up hardening (this revision)
# ============================================================
#   🛡️ HARD-UNI-08 — `_inline_kill_all` now WAITS for the
#     processes to actually disappear (up to 3 seconds) before
#     returning. Previously `pkill -9` + immediate `rm -rf $RUN_DIR`
#     could race against a process stuck in D-state, leaving
#     stale files behind or partially deleting the run dir.
#
#   🛡️ HARD-UNI-09 — The txn-* resolver loop ([9]) is now
#     wrapped in a function `_resolve_txn_dirs` and uses
#     `local` for its internal variables, matching the style
#     already used by `_inline_cleanup_firewall`.
#
#   🛡️ HARD-UNI-10 — `ndc resolver flushdefaultif` is now
#     logged on both success and failure. Previously a silent
#     failure left the user with a hung resolver and no trace
#     in the log to explain it.
#
#   🛡️ HARD-UNI-11 — The `[17]` PRESERVED log line is now
#     emitted only when the persistent backup directory
#     actually exists. A fresh install (no backup dir) no
#     longer prints a misleading "PRESERVED" message.
#
#   🛡️ HARD-UNI-12 — The `$( ... && echo X || echo Y )` idiom
#     used in the final summary has been replaced with explicit
#     `if/else` blocks to avoid the fragile `&&/||` fallback
#     if `echo` itself were to fail (e.g. closed stdout).
#
#   🛡️ HARD-UNI-13 — `RECOVERY_TRIGGER_1` ($MODDIR/recovery)
#     is now removed explicitly here, in addition to being
#     cleaned by the root manager. This avoids the rare
#     scenario where a reinstall happens before the module
#     folder is fully removed, which would spuriously enter
#     recovery mode on the next install.
#
#   🛡️ HARD-UNI-14 — The `--help` output and the final user
#     message now document the exit codes, so a manual
#     invocation can be scripted reliably.
#
# Security:
#   • MODDIR must be inside /data/adb/modules/
#   • MODDIR cannot equal the modules directory itself
#
# Design:
#   • Inline fallbacks are always used for the actual cleanup.
#     functions.sh is loaded only to obtain `aggressive_cleanup`
#     when it is present and safe to call — and the sourcing
#     is guarded to avoid running that file's initialization.
#   • The firewall cleanup list is functionally equivalent to:
#       - customize.sh    : _inline_cleanup_firewall
#       - post-fs-data.sh : inline_firewall_cleanup
#     The one intentional difference (127.0.0.1's comment tag)
#     is documented in [8]. Any change to the legacy cleanup
#     rules MUST be applied to all three files consistently.
#
# Non-responsibilities (deliberately NOT done here):
#   • No `debug.SetMemoryLimit` reset — the Go runtime releases
#     memory when the process exits; there is no persistent state.
#   • No firewall rule creation — this is a removal script; only
#     cleanup runs.
#   • No system-wide DNS reconfiguration beyond private_dns_mode
#     reset. Any custom resolvers set by the user are preserved.
#   • No deletion of /sdcard/dnscrypt-webui-backup/ — see [0].
#   • No deletion of orphan-txn-* — see [0.2].
#
# ============================================================
# POSIX note on `local`:
#   This script uses `local` inside its internal helper
#   functions (_inline_cleanup_firewall, _resolve_txn_dirs).
#   The `local` keyword is supported by:
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
# [2] Parse command-line arguments
# ============================================================
# HARD-UNI-05: unknown arguments are a hard error. Magisk does
# not pass extra arguments to uninstall scripts, so a non-empty
# unknown argument almost certainly means a manual invocation
# with a typo — and silently proceeding would be dangerous on
# a destructive script.
#
# HARD-UNI-14: exit codes are now documented in --help.
# ============================================================
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            cat << 'EOF'
DNSCrypt Smart Filter – uninstall.sh

Usage:
  uninstall.sh          Full cleanup (default)
  uninstall.sh --help   Show this help

Exit codes:
  0 = success (full or partial cleanup completed)
  1 = security violation (MODDIR outside expected paths)
  2 = unknown command-line argument

Note:
  This script is normally invoked automatically by Magisk when the
  module is removed. Do not run it manually except for cleanup.

  No automatic backup is created (v1.1.0+ behavior).

  Your persistent backup directory is PRESERVED so you can
  restore settings if you reinstall later:
    /sdcard/dnscrypt-webui-backup/

  Any txn-* directory that was interrupted mid-flight (state=START
  or missing .state) will be renamed to orphan-txn-* and PRESERVED
  — it may contain the only copy of a user's data. Inspect
  manually before deleting.

  A pending recovery trigger (/data/adb/dnscrypt-recovery), if any,
  is REMOVED — it has no meaning once the module is gone.

  If you want to keep your settings in a separate manual backup,
  copy them before uninstalling:
    su -c "cp -a /data/adb/modules/dnscrypt-proxy-webui/proxy/ \
                /sdcard/dnscrypt-backup-manual/"
EOF
            exit 0
            ;;
        "")
            # Empty string (e.g. from `uninstall.sh ""`) — ignore
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

# --- v1.2.0 — Data preservation paths ---
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# --- v1.2.0 — Recovery trigger paths (mirrors customize.sh) ---
RECOVERY_TRIGGER_1="$MODDIR/recovery"
RECOVERY_TRIGGER_2="/data/adb/dnscrypt-recovery"

# Legacy backup directory (v1.0.0) — cleaned up below
LEGACY_BACKUP_DIR="/data/local/tmp/dnscrypt_backup_uninstall"

# ============================================================
# [4] Protected log_msg
# ============================================================
log_msg() {
    if [ ! -d "/data/local/tmp" ]; then
        return 0
    fi
    if [ ! -f "$LOG_FILE" ]; then
        : > "$LOG_FILE" 2>/dev/null || return 0
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [UNINSTALL] $1" >> "$LOG_FILE" 2>/dev/null
}

log_msg "════════════════════════════════════════════"
log_msg "Uninstall started (v1.2.0 — Global Edition)"
log_msg "MODDIR=$MODDIR"
log_msg "RUN_DIR=$RUN_DIR"
log_msg "Backup dir (preserved): $PERSISTENT_BACKUP"

# ============================================================
# [5] Security checks
# ============================================================
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
# [5b] Read active profile + root solution (v1.2.0 — summary)
# ============================================================
ACTIVE_PROFILE="unknown"
if [ -f "$BIN_DIR/selected_profile.txt" ]; then
    _ap=$(cat "$BIN_DIR/selected_profile.txt" 2>/dev/null | tr -d '\r\n ')
    case "$_ap" in
        light|normal|pro|proplus|ultimate) ACTIVE_PROFILE="$_ap" ;;
    esac
fi
log_msg "Active profile at uninstall: $ACTIVE_PROFILE"

# --- Root solution detection (v1.2.0) ---
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

# --- Count preserved snapshots (v1.2.0) ---
BACKUP_COUNT=0
BACKUP_LAST_NAME=""
BACKUP_LAST_STABLE=""
BACKUP_TXN_COUNT=0
BACKUP_ORPHAN_COUNT=0

if [ -d "$PERSISTENT_BACKUP" ]; then
    BACKUP_COUNT=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d */ 2>/dev/null | \
        sed 's:/$::' | \
        grep -E '^[0-9]{8}-[0-9]{6}-' | \
        wc -l | tr -d ' ')
    [ -z "$BACKUP_COUNT" ] && BACKUP_COUNT=0

    if [ "$BACKUP_COUNT" -gt 0 ]; then
        BACKUP_LAST_NAME=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
            ls -1d */ 2>/dev/null | \
            sed 's:/$::' | \
            grep -E '^[0-9]{8}-[0-9]{6}-' | \
            sort -r | \
            head -n1)
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

    log_msg "Preserved backups: $BACKUP_COUNT snapshot(s)"
    log_msg "In-flight transactions: $BACKUP_TXN_COUNT"
    log_msg "Orphan transactions: $BACKUP_ORPHAN_COUNT"
    if [ -n "$BACKUP_LAST_STABLE" ]; then
        log_msg "Last stable pointer: $BACKUP_LAST_STABLE"
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
ORIGINAL_ROUTE_LOCALNET=""
if command -v sysctl >/dev/null 2>&1; then
    ORIGINAL_ROUTE_LOCALNET=$(sysctl -n net.ipv4.conf.all.route_localnet 2>/dev/null | tr -d '\r\n ')
fi

# ============================================================
# [7] Optionally load functions.sh
# ============================================================
# HARD-UNI-03: sourcing functions.sh runs its top-level
# initialization (init_runtime_paths, bootstrap-cache setup),
# which creates $RUN_DIR and .bootstrap_cache — files that
# this script is about to delete. We therefore avoid sourcing
# the file entirely, and instead detect its presence
# opportunistically: if `aggressive_cleanup` is already
# available as a function (only possible if the caller
# explicitly defined it), use it; otherwise fall back to the
# inline path. This preserves the caller's ability to provide
# a custom cleanup without paying the side effects.
#
# In practice, when uninstall.sh is invoked by Magisk/KernelSU,
# `aggressive_cleanup` is never pre-defined, so the inline path
# is always taken. The check remains for manual invocation
# scenarios where an operator may have sourced functions.sh
# themselves before invoking this script.
# ============================================================
FUNCTIONS_LOADED=0
if command -v aggressive_cleanup >/dev/null 2>&1; then
    FUNCTIONS_LOADED=1
    log_msg "aggressive_cleanup available in the current shell"
else
    log_msg "Using inline cleanup (functions.sh not pre-loaded)"
fi

# ============================================================
# [8] Internal fallback functions
# ============================================================

# ============================================================
# _inline_kill_all — terminate daemons and WAIT for exit
# ============================================================
# HARD-UNI-08: previously this function fired `pkill -9` and
# returned immediately. The caller then ran `rm -rf $RUN_DIR`
# in [13] while a process could still be in D-state (uninterruptible
# sleep on I/O), which caused either a failed unlink, or the
# process re-creating files inside a directory we believed to
# be gone. We now poll `pgrep` for up to 3 seconds and only
# proceed once both daemons have disappeared.
# ============================================================
_inline_kill_all() {
    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-proxy 2>/dev/null
    fi
    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
    fi

    # HARD-UNI-08: wait for processes to actually exit.
    _ki_wait=0
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

# ============================================================
# _inline_cleanup_firewall — orphan prevention
# ============================================================
# Strategy:
#   1. Delete the DNSCRYPT_OUT / DNSCRYPT_OUT6 Custom Chains entirely
#   2. Best-effort legacy cleanup (rules from older versions)
#   3. No dependency on functions.sh (self-contained)
#
# ⚠️ Synchronization note:
#   This function removes the same SET of rules as:
#     • customize.sh    : _inline_cleanup_firewall
#     • post-fs-data.sh : inline_firewall_cleanup
#   The files differ only in the comment tag applied to the
#   loopback (127.0.0.1) rules during the best-effort legacy
#   cleanup (see UNI-2). Any change to the RULES removed by
#   this function MUST be applied consistently to all three.
# ============================================================
_inline_cleanup_firewall() {
    # --- [1] nftables: delete entire table ---
    if command -v nft >/dev/null 2>&1; then
        nft delete table inet dnscrypt_filter 2>/dev/null
        nft delete table ip dnscrypt_filter 2>/dev/null
        nft delete table ip6 dnscrypt_filter 2>/dev/null
    fi

    # ============================================================
    # [2] iptables (IPv4) — Custom Chain cleanup
    # ============================================================
    if command -v iptables >/dev/null 2>&1; then
        local _chain="DNSCRYPT_OUT"

        # [2a] Remove jump rules from OUTPUT
        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain" --wait 3 2>/dev/null

        # [2b] Flush the chain itself
        iptables -t nat -F "$_chain" --wait 3 2>/dev/null
        iptables -t nat -X "$_chain" --wait 3 2>/dev/null

        # [2c] Legacy cleanup
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

        # UNI-3 fix: `_ip` is declared `local`.
        local _ip
        for _ip in 9.9.9.9 8.8.8.8 1.1.1.1 1.0.0.1 8.8.4.4 208.67.222.222 208.67.220.220; do
            iptables -t nat -D OUTPUT -d "$_ip" -p udp --dport 53 \
                -j RETURN --wait 3 2>/dev/null
            iptables -t nat -D OUTPUT -d "$_ip" -p tcp --dport 53 \
                -j RETURN --wait 3 2>/dev/null
        done
    fi

    # ============================================================
    # [3] ip6tables (IPv6) — Custom Chain cleanup
    # ============================================================
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
# [9] v1.2.0 — Resolve transaction directories
# ============================================================
# HARD-UNI-02 (was UNI-6): a txn-* directory with a missing or
# empty .state file is now treated like state=START — renamed
# to orphan-txn-* and preserved. Previously it was deleted,
# which could lose data from a crash that occurred between
# `mkdir` and `echo START > .state` in customize.sh.
#
# HARD-UNI-01 (was UNI-5): the counters ORPHAN_TXN_CLEANED and
# ORPHAN_TXN_RENAMED are exposed to the rest of the script, and
# a derived variable BACKUP_ORPHAN_FINAL is computed just
# before the final report to reflect the post-rename count.
#
# HARD-UNI-09: the loop body is now a function using `local`
# for its internal variables, matching the style already used
# by _inline_cleanup_firewall. The counters are still global
# because they must be readable by [17b], [18], and [19].
# ============================================================
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
                #   • state = ""        (HARD-UNI-02 — crash before
                #                        writing state; preserve)
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
# HARD-UNI-04: the cleanup runs exactly ONCE. Previously the
# inline path ran twice ("belt-and-suspenders"), duplicating
# every iptables/nft delete call.
# ============================================================
log_msg "🧹 Starting cleanup..."

if [ "$FUNCTIONS_LOADED" = "1" ]; then
    log_msg "Using aggressive_cleanup from the caller's shell"
    aggressive_cleanup 2>/dev/null
else
    log_msg "Using inline fallback cleanup"
    _inline_kill_all
    _inline_cleanup_firewall
fi

log_msg "✅ Process & firewall cleanup completed"

# ============================================================
# [12] Reset DNS settings
# ============================================================
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

# HARD-UNI-10: log the ndc result on both success and failure.
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
# [14] Cleanup temporary runtime files (in /data/local/tmp)
# ============================================================
log_msg "🗑️  Removing runtime files from /data/local/tmp..."

RUNTIME_COUNT=0

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

for f in /data/local/tmp/dnscrypt.status \
         /data/local/tmp/update_progress.txt; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

for f in /data/local/tmp/dnscrypt_credentials.txt \
         /data/local/tmp/.dnscrypt_credentials_shown; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

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

for f in "$RUN_DIR/.bootstrap_cache" \
         "/data/local/tmp/.bootstrap_cache"; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

log_msg "✅ Removed $RUNTIME_COUNT runtime files from /data/local/tmp"

# ============================================================
# [15] Cleanup module configuration files
# ============================================================
log_msg "🗑️  Removing module configuration files..."

MODULE_COUNT=0

if [ -d "$BIN_DIR" ]; then
    for f in selected_profile.txt \
             webui.conf \
             webui.conf.tmp \
             dnscrypt-proxy.toml \
             dnscrypt-proxy.toml.bak; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

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

    for f in allowlist.txt \
             allowlist.txt.tmp_write \
             denylist.txt \
             denylist.txt.tmp_write; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    for f in auth.json .auth_token; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    for f in public-resolvers.md \
             public-resolvers.md.minisig \
             relays.md \
             relays.md.minisig; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    log_msg "✅ Removed $MODULE_COUNT module config files"
else
    log_msg "⚠️ $BIN_DIR does not exist, skipping config cleanup"
fi

# ============================================================
# [16] Remove module fingerprint and disable file
# ============================================================
if [ -f "$MODDIR/.module.fingerprint" ]; then
    rm -f "$MODDIR/.module.fingerprint" 2>/dev/null
    log_msg "✅ Fingerprint removed"
fi

if [ -f "$MODDIR/disable" ]; then
    rm -f "$MODDIR/disable" 2>/dev/null
    log_msg "✅ disable file removed"
fi

# ============================================================
# [16b] v1.2.0 — Remove recovery triggers
# ============================================================
# RECOVERY_TRIGGER_2 (/data/adb/dnscrypt-recovery) lives OUTSIDE
# the module directory, so Magisk does NOT remove it when the
# module is uninstalled.
#
# HARD-UNI-07 (was UNI-11): the reason for removing it here is
# simply that the trigger's only meaning is "the NEXT install
# should enter recovery mode". Once the module is gone, that
# meaning is void.
#
# HARD-UNI-13: RECOVERY_TRIGGER_1 ($MODDIR/recovery) is now
# also removed explicitly here. The root manager deletes the
# whole module folder after this script exits, so in the
# normal path this is redundant — but if a reinstall is
# triggered before the folder is fully removed, a lingering
# RECOVERY_TRIGGER_1 would spuriously enter recovery mode on
# the next install. Removing it here is cheap and closes that
# race.
# ============================================================
RECOVERY_TRIGGER_REMOVED=0

if [ -f "$RECOVERY_TRIGGER_2" ]; then
    if rm -f "$RECOVERY_TRIGGER_2" 2>/dev/null; then
        RECOVERY_TRIGGER_REMOVED=1
        log_msg "🗑️  Removed external recovery trigger: $RECOVERY_TRIGGER_2"
    else
        log_msg "⚠️ Failed to remove external recovery trigger: $RECOVERY_TRIGGER_2"
    fi
else
    log_msg "ℹ️ No external recovery trigger present"
fi

if [ -f "$RECOVERY_TRIGGER_1" ]; then
    if rm -f "$RECOVERY_TRIGGER_1" 2>/dev/null; then
        RECOVERY_TRIGGER_INTERNAL_REMOVED=1
        log_msg "🗑️  Removed in-module recovery trigger: $RECOVERY_TRIGGER_1"
    else
        log_msg "⚠️ Failed to remove in-module recovery trigger: $RECOVERY_TRIGGER_1"
    fi
else
    log_msg "ℹ️ No in-module recovery trigger present"
fi

# ============================================================
# [17] v1.2.0 — PRESERVE the persistent backup directory
# ============================================================
# HARD-UNI-11: emit the PRESERVED message only when the
# directory actually exists. A fresh install (no backup dir)
# previously printed "PRESERVED" for a directory that was
# never created, which was misleading.
# ============================================================
if [ -d "$PERSISTENT_BACKUP" ]; then
    log_msg "💾 Persistent backup PRESERVED (not removed): $PERSISTENT_BACKUP"
    if [ "$BACKUP_COUNT" -gt 0 ]; then
        log_msg "   Snapshot count: $BACKUP_COUNT"
    fi
    if [ -n "$BACKUP_LAST_NAME" ]; then
        log_msg "   Latest snapshot: $BACKUP_LAST_NAME"
    fi
    if [ -n "$BACKUP_LAST_STABLE" ]; then
        log_msg "   Last stable: $BACKUP_LAST_STABLE"
    fi
else
    log_msg "ℹ️ No persistent backup directory present (nothing to preserve)"
fi

# ============================================================
# [17b] HARD-UNI-01 — Compute the FINAL orphan-txn count
# ============================================================
# The initial BACKUP_ORPHAN_COUNT (section [5b]) was captured
# BEFORE [9] renamed any START/no-state transactions. The
# final report must reflect the post-rename count, or the
# user sees a stale zero while the log shows a rename.
# ============================================================
BACKUP_ORPHAN_FINAL=$((BACKUP_ORPHAN_COUNT + ORPHAN_TXN_RENAMED))

# ============================================================
# [18] Final summary
# ============================================================
# HARD-UNI-12: the `$( ... && echo X || echo Y )` idiom has
# been replaced with explicit if/else blocks. The old idiom
# was fragile: if `echo` itself failed (closed stdout), the
# `||` branch would fire and report the opposite of the truth.
# ============================================================
log_msg "════════════════════════════════════════════"

if [ "$RUN_COUNT" -gt 0 ]; then
    _run_status="removed"
else
    _run_status="not present"
fi

if [ "$LEGACY_BACKUP_REMOVED" = "1" ]; then
    _legacy_status="removed"
else
    _legacy_status="not present"
fi

if [ "$RECOVERY_TRIGGER_REMOVED" = "1" ]; then
    _recovery_status="removed"
else
    _recovery_status="not present"
fi

log_msg "✅ Uninstall completed successfully"
log_msg "   • Root solution:            $ROOT_SOLUTION"
log_msg "   • Profile at uninstall:     $ACTIVE_PROFILE"
log_msg "   • run/ directory:           $_run_status"
log_msg "   • Runtime files removed:    $RUNTIME_COUNT"
log_msg "   • Module config files:      $MODULE_COUNT"
log_msg "   • Firewall:                 Custom Chains removed (DNSCRYPT_OUT / DNSCRYPT_OUT6)"
log_msg "   • Legacy rules:             cleaned (best-effort)"
log_msg "   • route_localnet:           restored to ${ORIGINAL_ROUTE_LOCALNET:-0}"
log_msg "   • Legacy backup dir:        $_legacy_status"
log_msg "   • External recovery trigger: $_recovery_status"
log_msg "   • Committed/rolled txns:    $ORPHAN_TXN_CLEANED removed"
log_msg "   • Unfinished txns:          $ORPHAN_TXN_RENAMED preserved (renamed to orphan-txn-*)"
if [ -d "$PERSISTENT_BACKUP" ]; then
    log_msg "   • Persistent backup:        PRESERVED"
    log_msg "     Path:                     $PERSISTENT_BACKUP"
    log_msg "     Snapshots:                $BACKUP_COUNT"
    if [ "$BACKUP_COUNT" -gt 0 ] && [ -n "$BACKUP_LAST_NAME" ]; then
        log_msg "     Latest:                   $BACKUP_LAST_NAME"
    fi
    if [ -n "$BACKUP_LAST_STABLE" ]; then
        log_msg "     Last stable:              $BACKUP_LAST_STABLE"
    fi
    # HARD-UNI-01: use the FINAL orphan-txn count, not the pre-rename one.
    if [ "$BACKUP_ORPHAN_FINAL" -gt 0 ]; then
        log_msg "     Orphan txn preserved:     $BACKUP_ORPHAN_FINAL"
    fi
else
    log_msg "   • Persistent backup:        not present"
fi
log_msg "   • Note: no auto-backup was created (v1.1.0+ behavior)"
if [ -d "$PERSISTENT_BACKUP" ]; then
    log_msg "   • Note: the backup directory can be removed manually:"
    log_msg "           rm -rf $PERSISTENT_BACKUP"
fi
log_msg "════════════════════════════════════════════"

# ============================================================
# [19] User-facing final message (v1.2.0)
# ============================================================
# HARD-UNI-14: exit codes are documented at the bottom of this
# message so a manual invocation can be scripted reliably.
# ============================================================
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
    echo ""
    echo "  ✅ If you reinstall the module later, your settings will"
    echo "     be restored automatically from this backup."
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

# HARD-UNI-01 + UNI-4: use the FINAL count, and explicitly
# mention the START → orphan-txn rename for the user.
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

if [ "$RECOVERY_TRIGGER_REMOVED" = "1" ]; then
    echo ""
    echo "  ℹ️  A pending recovery trigger was removed:"
    echo "     $RECOVERY_TRIGGER_2"
    echo "     (It had no meaning once the module was uninstalled.)"
fi

if [ "${RECOVERY_TRIGGER_INTERNAL_REMOVED:-0}" = "1" ]; then
    echo ""
    echo "  ℹ️  An in-module recovery trigger was also removed:"
    echo "     $RECOVERY_TRIGGER_1"
fi

echo ""
echo "  Exit code: 0 (success)"
echo "════════════════════════════════════════════════════════════"
echo ""

exit 0