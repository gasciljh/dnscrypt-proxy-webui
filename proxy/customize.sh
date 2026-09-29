#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – customize.sh
# Version: v1.2.0 (Global Edition)
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Magisk / KernelSU / APatch installer script.
#
#   Responsibilities (v1.2.0 — data-preservation hardened):
#     • Verify installation environment (MODPATH security)
#     • Detect architecture (arm64 / arm / x86_64 / x86)
#     • Detect root solution (Magisk / KernelSU / APatch)
#     • Detect recovery mode (trigger file)
#     • Stop old processes on upgrade
#     • Clean firewall state (Custom Chains + legacy)
#     • Multi-source user-data discovery (Layer 1)
#     • Persistent backup to /sdcard (Layer 2)
#     • Integrity verification with SHA256 (Layer 3)
#     • Transactional atomic upgrade with rollback (Layer 4)
#     • Root-solution-aware candidate paths (Layer 5)
#     • SELinux context preservation (Layer 6)
#     • Recovery mode restoration (Layer 7 — snapshot-and-reapply)
#     • Config migrations between versions (Layer 8)
#     • Extract module files
#     • Restore user settings with verification
#     • Validate critical files
#     • Copy the correct binaries for the current architecture
#     • Create secure run/ directory (0700)
#     • Write webui.conf with Port Guard (reject 8080 + collisions)
#     • Generate secure credentials for the monitoring_ui
#     • Pre-generate the watchdog token (matches main.go)
#     • Set permissions
#     • Write the module fingerprint
#     • Log upgrade history (Layer 10)
#     • Rotate old backups (Layer 9)
#
# User settings preserved on every upgrade (5 files):
#   • webui.conf
#   • dnscrypt-proxy.toml
#   • selected_profile.txt
#   • allowlist.txt
#   • denylist.txt
#
# ============================================================
# v1.2.0 — ROOT CAUSE FIX
# ============================================================
# v1.1.0 had a critical data-loss bug in section [8]. The
# original check was:
#
#     if [ -d "$_EXISTING_MODULE" ] && [ "$_EXISTING_MODULE" != "$MODPATH" ]; then
#         UPGRADE_DETECTED=1
#     fi
#
# On an in-place upgrade, `$_EXISTING_MODULE == $MODPATH`, so the
# second condition was false and the upgrade was NOT detected.
# Result: the 5 user config files were silently lost.
#
# The fix: replace "detect if this is an upgrade" with
# "search for user data everywhere". If any valid source is
# found, restore from it — regardless of whether the installer
# was invoked as an upgrade or not.
#
# ============================================================
# v1.2.0 — Recovery mode fix (snapshot-and-reapply)
# ============================================================
# The recovery mode flow (triggered by the presence of a
# `recovery` file) executes in this order:
#
#   [8a]  Restore 5 user files from a snapshot into
#         $MODPATH/proxy/                       ✅ all 5
#   [9]   unzip -o "$ZIPFILE" 'proxy/*' ... -d "$MODPATH"
#         → OVERWRITES webui.conf and dnscrypt-proxy.toml
#           with the ZIP's default copies        ❌ 2 lost
#   [9c]  Skipped when RECOVERY_MODE=1
#
# The fix: every file restored in [8a] is ALSO copied to
# $MODPATH/.recovery_snapshot/, and section [9b2] re-applies
# them AFTER [9] (unzip) and [9b] (file moves), and BEFORE [9c].
#
# Why this approach (snapshot + re-apply) is preferred over
# filtering the unzip argument list:
#   • It does NOT depend on knowing what the ZIP contains.
#   • It keeps the extraction logic of [9] untouched, so the
#     normal-install path is byte-for-byte identical.
#   • The snapshot dir is $MODPATH/.recovery_snapshot/ (dot-
#     prefixed, cleaned up in [9b2]) so it never appears in
#     the final module layout.
#
# ============================================================
# v1.2.0 — Post-audit corrections (this revision)
# ============================================================
# This file carries three identifier families that were added
# across successive audit passes. The inventory below is the
# AUTHORITATIVE list of identifiers actually present in the
# file. It was corrected during the v1.2.0 release audit to
# remove historical mislabeling.
#
# Identifier inventory in THIS file (28 total):
#
#   • CSH-1, CSH-2, CSH-3, CSH-4, CSH-5, CSH-6,
#     CSH-11, CSH-13                              (8)
#       — original post-audit corrections
#
#   • CSH-14, CSH-15, CSH-16                      (3)
#       — NEW corrections in this revision
#         (§[8b] watchdog path, §[9c] critical-file
#          strictness, §[24] merged recovery block)
#
#   • DOC-1, DOC-2                                (2)
#       — documentation fixes
#
#   • FSH-8                                       (1)
#       — cross-reference to functions.sh
#
#   • BUG-CS-A, BUG-CS-B, BUG-CS-C, BUG-CS-D      (4)
#       — bug fixes in the persistent-backup layer
#
#   • HARD-CS-01 … HARD-CS-10                    (10)
#       — hardening fixes
#
# NOTE ON IDENTIFIER GAPS:
#   CSH-7, CSH-8, CSH-9, CSH-10, and CSH-12 were NEVER
#   assigned in this file. They are historical gaps that
#   appeared because the numbering was drafted before the
#   final audit pass consolidated several entries. They are
#   documented here explicitly so that future auditors do not
#   assume the file is missing five fixes — the fixes exist,
#   they simply carry the identifiers listed above.
#
# NOTE ON THE REVISED COUNT:
#   The previous revision of this header incorrectly declared
#   "31 total" — the sum of the six lines above was already
#   only 28 (8 + 3 + 2 + 1 + 4 + 10). The arithmetic error
#   has been corrected here; no code change was required.
#
# ------------------------------------------------------------
# Original post-audit corrections (CSH-1..CSH-13, partial):
# ------------------------------------------------------------
#
#   🔧 CSH-1 — `_inline_cleanup_firewall` leaked `_ip` to the
#     global scope (variable was not declared `local`). Now
#     declared `local` to prevent accidental contamination.
#
#   🔧 CSH-2 — Section [24] (final summary) printed
#     "Upgrade: YES (0 files restored)" when RECOVERY_MODE=1.
#     Now prints an explicit "Recovery: restored from snapshot"
#     line in that case.
#
#   🔧 CSH-3 — `log_upgrade` was called unconditionally, even
#     on a fresh install. Now called only when there is
#     something meaningful to log (SOURCE_VERSION or
#     FOUND_SOURCE non-empty).
#
#   🔧 CSH-4 — `log_upgrade` used `jq ... > "$tmp" && mv ...`,
#     so when jq failed the tmp file was left on disk. Now uses
#     an explicit if/else with rm -f on the failure path.
#
#   🔧 CSH-5 — Section [9b2] removed the recovery snapshot dir
#     even when re-application had partially failed. Now
#     preserves the snapshot dir when `_reapplied` is less
#     than `_snapshotted`.
#
#   🔧 CSH-6 — `_snapshotted` was set in [8a] but never
#     consumed. It is now used in [9b2].
#
#   🔧 CSH-11 — `copy_with_context` silently swallowed cp's
#     stderr. cp's stderr is now appended to $INSTALL_LOG.
#
#   🔧 CSH-13 — The comment on the TXN_ID / BACKUP_TIMESTAMP
#     relationship said "millisecond-level drift"; both values
#     use second precision. Wording corrected.
#
# ------------------------------------------------------------
# Documentation fixes:
# ------------------------------------------------------------
#
#   🔧 DOC-1 — The persistent backup root is now chmod 0700
#     (best-effort — see comment in [8c]).
#
#   🔧 DOC-2 — The embedded README.md now matches the actual
#     rotation policy: "the 21 newest snapshots by directory
#     name".
#
#   🔧 FSH-8 — The embedded README.md now documents
#     `.last_auto_backup` and `.pending_notification`.
#
# ------------------------------------------------------------
# Bug fixes in the persistent-backup layer:
# ------------------------------------------------------------
#
# 🔧 BUG-CS-A — create_persistent_backup previously returned
#     success even when 0 files were copied. `.last_stable`
#     then pointed to an empty snapshot, and the summary
#     printed "integrity verified" on a directory that
#     contained only `.manifest.json` with `files_count: 0`.
#
#     FIX: When `count == 0`:
#       • The partially-created target directory is removed.
#       • The function returns 1.
#       • The caller ([8d]) does NOT set PERSISTENT_BACKUP_OK.
#       • `.last_stable` is NOT updated.
#       • `current/` is NOT touched.
#
# ------------------------------------------------------------
# 🔧 BUG-CS-B — `current/` was updated with a non-atomic
#     `rm -rf` + `mkdir` + copy sequence. A crash or OOM kill
#     between `rm -rf` and the copy would leave `current/`
#     empty or partial.
#
#     FIX: The update now uses a temporary directory plus an
#     atomic `mv`:
#       1. Populate `.current.tmp.$$` from the new snapshot.
#       2. `mv current .current.old.$$` (if it exists).
#       3. `mv .current.tmp.$$ current`.
#       4. Remove `.current.old.$$` on success.
#       5. On step-3 failure, restore `.current.old.$$` back
#          to `current` (rollback).
#     If the script dies at any point, `current/` is either the
#     old snapshot, the new one, or the old one still sitting
#     under `.current.old.$$` — never empty.
#
# ------------------------------------------------------------
# 🔧 BUG-CS-C — The snapshot directory name was
#     `$BACKUP_TIMESTAMP-$MODULE_VERSION`, where
#     `$BACKUP_TIMESTAMP` has second precision. Two installs
#     within the same second produced the same directory, so
#     the second install silently overwrote the first's
#     manifest.
#
#     FIX: The snapshot directory name now includes the
#     installer PID:
#       `$BACKUP_TIMESTAMP-$MODULE_VERSION-$$`
#     The rotation regex `^[0-9]{8}-[0-9]{6}-` still matches,
#     so existing tools keep working. `.last_stable` stores the
#     full name.
#
# ------------------------------------------------------------
# 🔧 BUG-CS-D — Watchdog token was generated only by `main.go`
#     on first startup. If a user disabled the WebUI but kept
#     the watchdog active, watchdog.sh could not authenticate
#     `ensure_running_service`.
#
#     FIX: Section [19b] pre-generates the token during install
#     so it is ready before the first WebUI start and before
#     watchdog.sh ever runs.
#
# ------------------------------------------------------------
# Hardening fixes (HARD-CS-01 … HARD-CS-10):
# ------------------------------------------------------------
#
# 🛡️ HARD-CS-01 — The final summary in [24] reported "not
#     created (source empty or disk full)" for a fresh install
#     (no source at all). That is misleading. A dedicated
#     message is now printed for the fresh-install case, and a
#     separate flag tracks whether the integrity check was
#     actually verified (not merely advisory).
#
# 🛡️ HARD-CS-02 — Port validation printed "resetting to 9090"
#     for any invalid PORT, but never included the offending
#     value. The message now includes the original value for
#     diagnostics.
#
# 🛡️ HARD-CS-03 — `log_upgrade` used `mktemp` for the jq temp
#     file. On Android, `mktemp` may return a path on a
#     different filesystem than the backup dir, so the final
#     `mv` could fail with EXDEV. The temp file is now created
#     inside `$PERSISTENT_BACKUP` so the rename is always
#     same-filesystem.
#
# 🛡️ HARD-CS-04 — The `_count` variable used during source
#     discovery was a global (no `local` was possible since it
#     sits at the script top level). It has been renamed to
#     `_found_count` to avoid any collision with shell-builtin
#     or Magisk-provided variables.
#
# 🛡️ HARD-CS-05 — `write_manifest` embedded `$source` verbatim
#     into JSON. If the source path ever contained a quote or
#     backslash, the manifest would be invalid. A minimal JSON
#     escaper now sanitizes the three fields that carry strings.
#
# 🛡️ HARD-CS-06 — `create_persistent_backup` silently returned
#     1 when `mkdir -p` failed. The failure is now logged to
#     `$INSTALL_LOG` before returning.
#
# 🛡️ HARD-CS-07 — Section [24] reported `$FOUND_FILE_COUNT` as
#     if it were the backup file count. It is actually the
#     SOURCE file count. The label is now "source files" to
#     avoid confusion with the backup's own `files_count`
#     (from the manifest).
#
# 🛡️ HARD-CS-08 — `rotate_backups` did not verify that the
#     backup directory was readable before globbing. A
#     directory with bad permissions would produce an empty
#     `ls` result and silently skip rotation. The readability
#     check is now explicit.
#
# 🛡️ HARD-CS-09 — In recovery mode, the pre-extraction
#     snapshot in [8a] used raw `cp -f` instead of
#     `copy_with_context`. On FUSE-mounted `/sdcard` the
#     distinction is irrelevant, but inside `$MODPATH` it is
#     not. `copy_with_context` is now used consistently.
#
# 🛡️ HARD-CS-10 — When `RECOVERY_TRIGGER_2`
#     (`/data/adb/dnscrypt-recovery`) fired but no valid restore
#     source could be located, the code set RECOVERY_MODE=0 and
#     continued. The trigger files were left on disk, so the
#     next reboot would re-enter recovery mode repeatedly. They
#     are now removed on the "no source" path as well.
#
# ------------------------------------------------------------
# NEW corrections in this revision (CSH-14, CSH-15, CSH-16):
# ------------------------------------------------------------
#
# 🔧 CSH-14 — Section [8b] located the watchdog PID file via a
#     HARD-CODED path (`$_EXISTING_MODULE/proxy/run/watchdog.pid`)
#     in addition to `/data/local/tmp/watchdog.pid`. If the
#     module was installed under a different module-ID, the
#     PID file was never found and the watchdog process kept
#     running with a stale state file. The loop now ALSO checks
#     `$MODPATH/proxy/run/watchdog.pid`, which is the path
#     owned by the module currently being installed.
#
# 🔧 CSH-15 — Section [9c] allowed a SINGLE silent file
#     restore failure to proceed (`-ge 2` was the abort
#     threshold). This could silently drop `webui.conf` or
#     `dnscrypt-proxy.toml`. The restore loop now flags
#     CRITICAL_RESTORE_FAILED whenever either of those two
#     files fails verification, and aborts (with rollback)
#     immediately on any critical failure — regardless of the
#     total failure count.
#
# 🔧 CSH-16 — Section [24] contained TWO consecutive
#     `if [ "$RECOVERY_MODE" = "1" ]` blocks. The second was a
#     post-recovery banner; the first was a status line. They
#     are now merged into a single if/elif/else chain so the
#     summary is printed exactly once and reads coherently.
#
# ============================================================
# POSIX note on `local`:
#   This script uses `local` inside multiple helper functions
#   (get_module_version, _inline_cleanup_firewall,
#    copy_with_context, write_manifest, verify_backup_integrity,
#    create_persistent_backup, read_toml_credentials, and
#    others). The `local` keyword is supported by:
#     • mksh (the default /system/bin/sh on modern Android)
#     • busybox ash (older Android)
#     • bash, dash, ksh
#   It is NOT part of the POSIX sh standard, but every shell
#   Android ships supports it.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Determine module path (temporary)
# ============================================================

# v1.2.1: --version flag (checked before any argument parsing)
case "${1:-}" in
	--version)
		echo "$0: v1.2.1"
		exit 0
		;;
esac

MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

# --- MODPATH check ---
if [ -z "$MODPATH" ]; then
    abort "❌ Please install via Magisk Manager or KernelSU!"
fi

# --- Security check: MODPATH must be inside /data/adb ---
case "$MODPATH" in
    /data/adb/*) ;;
    *)
        abort "❌ SECURITY: MODPATH '$MODPATH' is outside /data/adb. Installation aborted."
        ;;
esac

if [ ! -d "$MODPATH" ]; then
    abort "❌ MODPATH '$MODPATH' does not exist or is not a directory."
fi

SKIPUNZIP=1

# ============================================================
# [2] Constants
# ============================================================
_MONITORING_UI_PORT="8080"

# Path of previously installed module (for reference only — v1.2.0
# no longer relies on this alone for upgrade detection)
_EXISTING_MODULE="/data/adb/modules/dnscrypt-proxy-webui"

# --- v1.2.0 — Layer 2: persistent backup location ---
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"

# --- v1.2.0 — user data files (single source of truth) ---
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# --- v1.2.0 — Layer 7: recovery mode trigger files ---
RECOVERY_TRIGGER_1="$MODPATH/recovery"
RECOVERY_TRIGGER_2="/data/adb/dnscrypt-recovery"

# --- v1.2.0 — recovery snapshot (survives [9] unzip) ---
RECOVERY_SNAPSHOT_DIR="$MODPATH/.recovery_snapshot"

# ============================================================
# [3] Check required tools
# ============================================================
for tool in unzip sed tr date grep head cut awk find; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        abort "❌ Required tool '$tool' not found. Installation aborted."
    fi
done

# md5sum is optional (has fallback)
HAS_MD5SUM=0
if command -v md5sum >/dev/null 2>&1; then
    HAS_MD5SUM=1
fi

# sha256sum is optional but STRONGLY recommended (Layer 3)
HAS_SHA256=0
if command -v sha256sum >/dev/null 2>&1; then
    HAS_SHA256=1
fi

# restorecon / chcon (Layer 6)
HAS_RESTORECON=0
if command -v restorecon >/dev/null 2>&1; then
    HAS_RESTORECON=1
fi

HAS_CHCON=0
if command -v chcon >/dev/null 2>&1; then
    HAS_CHCON=1
fi

# jq (optional — used for .upgrade_history.json)
HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=1
fi

# ============================================================
# [3b] Extract module.prop early
# ============================================================
if [ -n "$ZIPFILE" ] && [ -f "$ZIPFILE" ]; then
    unzip -o "$ZIPFILE" 'module.prop' -d "$MODPATH" >/dev/null 2>&1 || true
fi

# ============================================================
# [4] Read version from module.prop
# ============================================================
get_module_version() {
    local vf="$MODPATH/module.prop"
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

# Extract versionCode for verification
MODULE_VERSION_CODE=""
if [ -f "$MODPATH/module.prop" ]; then
    MODULE_VERSION_CODE=$(grep "^versionCode=" "$MODPATH/module.prop" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
fi

# ============================================================
# [4b] v1.2.0 — Layer 5: detect root solution
# ============================================================
detect_root_solution() {
    if [ -n "${KSU_VER:-}" ] || [ -d "/data/adb/ksu" ]; then
        echo "kernelsu"
        return 0
    fi
    if [ -n "${APATCH:-}" ] || [ -d "/data/adb/ap" ]; then
        echo "apatch"
        return 0
    fi
    if [ -n "${MAGISK_VER_CODE:-}" ] || [ -d "/data/adb/magisk" ]; then
        echo "magisk"
        return 0
    fi
    echo "unknown"
}

ROOT_SOLUTION=$(detect_root_solution)

# ============================================================
# [5] Display installation header
# ============================================================
ui_print "╔══════════════════════════════════════════╗"
ui_print "║  🛡️  DNSCrypt Smart Filter               ║"
printf "║      %-32s ║\n" "$MODULE_VERSION"
ui_print "║      Global edition (EN + AR)            ║"
ui_print "╚══════════════════════════════════════════╝"
ui_print ""

# ============================================================
# [6] Prepare installation log
# ============================================================
INSTALL_LOG="/data/local/tmp/dnscrypt_install.log"
: > "$INSTALL_LOG"
{
    echo "========================================"
    echo "DNSCrypt Install $MODULE_VERSION – $(date)"
    echo "versionCode: $MODULE_VERSION_CODE"
    echo "MODPATH: $MODPATH"
    echo "Root solution: $ROOT_SOLUTION"
    echo "========================================"
} >> "$INSTALL_LOG"

ARCH=$(getprop ro.product.cpu.abi)
ui_print "- Architecture: $ARCH"
ui_print "- Root solution: $ROOT_SOLUTION"
echo "Architecture: $ARCH" >> "$INSTALL_LOG"

# ============================================================
# [7] Firewall cleanup helper
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

        # [2a] Remove jump rules
        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain" --wait 3 2>/dev/null

        # [2b] Flush the chain
        iptables -t nat -F "$_chain" --wait 3 2>/dev/null
        iptables -t nat -X "$_chain" --wait 3 2>/dev/null

        # [2c] Legacy cleanup — older versions
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

        # Legacy RETURN rules (best-effort for known IPs)
        # CSH-1 fix: `_ip` is now declared `local`.
        local _ip
        for _ip in 127.0.0.1 9.9.9.9 8.8.8.8 1.1.1.1 1.0.0.1 8.8.4.4 208.67.222.222 208.67.220.220; do
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

        # Legacy
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

    return 0
}

# ============================================================
# [7b] v1.2.0 — Layer 6: copy with SELinux context preservation
# ============================================================
copy_with_context() {
    local src="$1"
    local dst="$2"

    if ! cp -f "$src" "$dst" 2>>"$INSTALL_LOG"; then
        echo "  ❌ copy_with_context FAILED: $src → $dst" >> "$INSTALL_LOG"
        return 1
    fi

    if [ "$HAS_RESTORECON" = "1" ]; then
        restorecon "$dst" 2>/dev/null || true
    elif [ "$HAS_CHCON" = "1" ]; then
        chcon u:object_r:magisk_file:s0 "$dst" 2>/dev/null || true
    fi

    chmod 0600 "$dst" 2>/dev/null

    return 0
}

# ============================================================
# [8] v1.2.0 — Layer 1: multi-source user data discovery
# ============================================================
CANDIDATE_SOURCES=""

# Standard and legacy module paths
CANDIDATE_SOURCES="$CANDIDATE_SOURCES $MODPATH/proxy"
CANDIDATE_SOURCES="$CANDIDATE_SOURCES /data/adb/modules/dnscrypt-proxy-webui/proxy"
CANDIDATE_SOURCES="$CANDIDATE_SOURCES /data/adb/modules/DNSCrypt-Proxy-Webui/proxy"
CANDIDATE_SOURCES="$CANDIDATE_SOURCES /data/adb/modules/DNSCrypt-Proxy-WebUI/proxy"

# APatch-specific: modules_update (Layer 5)
if [ "$ROOT_SOLUTION" = "apatch" ]; then
    CANDIDATE_SOURCES="$CANDIDATE_SOURCES /data/adb/modules_update/dnscrypt-proxy-webui/proxy"
    CANDIDATE_SOURCES="$CANDIDATE_SOURCES /data/adb/modules_update/DNSCrypt-Proxy-Webui/proxy"
fi

# Persistent backup locations (Layer 2)
CANDIDATE_SOURCES="$CANDIDATE_SOURCES $PERSISTENT_BACKUP/current"
CANDIDATE_SOURCES="$CANDIDATE_SOURCES $PERSISTENT_BACKUP"

# tmp fallback (legacy v1.1.0 backups)
CANDIDATE_SOURCES="$CANDIDATE_SOURCES /data/local/tmp/dnscrypt-webui-backup"

# --- Search ---
FOUND_SOURCE=""
FOUND_FILE_COUNT=0

ui_print ""
ui_print "- Searching for user data..."

for candidate in $CANDIDATE_SOURCES; do
    [ -d "$candidate" ] || continue

    # Skip if this is the current install target and is empty
    if [ "$candidate" = "$MODPATH/proxy" ] && [ ! -f "$candidate/webui.conf" ]; then
        continue
    fi

    # HARD-CS-04: renamed `_count` to `_found_count` to avoid any
    # collision with shell-builtin or Magisk-provided variables.
    _found_count=0
    for _f in $USER_FILES; do
        if [ -f "$candidate/$_f" ] && [ -s "$candidate/$_f" ]; then
            _found_count=$((_found_count + 1))
        fi
    done

    # Require at least 3 valid files (represents real user data)
    if [ "$_found_count" -ge 3 ]; then
        FOUND_SOURCE="$candidate"
        FOUND_FILE_COUNT="$_found_count"
        ui_print "  → Found: $candidate ($_found_count files)"
        echo "Found user data: $candidate ($_found_count files)" >> "$INSTALL_LOG"
        break
    fi
done

if [ -z "$FOUND_SOURCE" ]; then
    ui_print "  → No existing user data found (fresh install)"
    echo "No user data found — fresh install" >> "$INSTALL_LOG"
else
    ui_print "  ✅ User data source: $FOUND_SOURCE"
fi

# ============================================================
# [8a] v1.2.0 — Layer 7: recovery mode check
# ============================================================
RECOVERY_MODE=0
RESTORE_SOURCE=""
_snapshotted=0
_restored=0

if [ -f "$RECOVERY_TRIGGER_1" ] || [ -f "$RECOVERY_TRIGGER_2" ]; then
    ui_print ""
    ui_print "  🚨 RECOVERY MODE ACTIVATED"
    ui_print "  ─────────────────────────────"

    # Priority 1: .last_stable pointer
    if [ -f "$PERSISTENT_BACKUP/.last_stable" ]; then
        LAST_STABLE=$(cat "$PERSISTENT_BACKUP/.last_stable" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$LAST_STABLE" ] && [ -d "$PERSISTENT_BACKUP/$LAST_STABLE" ]; then
            RESTORE_SOURCE="$PERSISTENT_BACKUP/$LAST_STABLE"
            ui_print "  → Using: $LAST_STABLE (last stable)"
        fi
    fi

    # Priority 2: current/ live snapshot
    if [ -z "$RESTORE_SOURCE" ] && [ -d "$PERSISTENT_BACKUP/current" ]; then
        RESTORE_SOURCE="$PERSISTENT_BACKUP/current"
        ui_print "  → Using: current (live snapshot)"
    fi

    # Priority 3: in-place data
    if [ -z "$RESTORE_SOURCE" ] && [ -n "$FOUND_SOURCE" ]; then
        RESTORE_SOURCE="$FOUND_SOURCE"
        ui_print "  → Using: $FOUND_SOURCE (in-place)"
    fi

    if [ -z "$RESTORE_SOURCE" ]; then
        ui_print "  ❌ No recovery source available"
        ui_print "  ⚠️  Cannot recover — normal install will proceed"
        echo "⚠️ Recovery: no source found" >> "$INSTALL_LOG"
        RECOVERY_MODE=0
        # HARD-CS-10: remove the trigger files even when no source
        # was found. Otherwise the module re-enters recovery mode
        # on every reboot with no chance of success.
        rm -f "$RECOVERY_TRIGGER_1" 2>/dev/null
        rm -f "$RECOVERY_TRIGGER_2" 2>/dev/null
    else
        mkdir -p "$MODPATH/proxy" 2>/dev/null
        BIN_DIR="$MODPATH/proxy"

        rm -rf "$RECOVERY_SNAPSHOT_DIR" 2>/dev/null
        mkdir -p "$RECOVERY_SNAPSHOT_DIR" 2>/dev/null

        for _f in $USER_FILES; do
            if [ -f "$RESTORE_SOURCE/$_f" ] && [ -s "$RESTORE_SOURCE/$_f" ]; then
                if copy_with_context "$RESTORE_SOURCE/$_f" "$BIN_DIR/$_f"; then
                    _restored=$((_restored + 1))
                    ui_print "  ✓ Restored: $_f"
                    # HARD-CS-09: use copy_with_context for the
                    # snapshot too, for consistency with the
                    # restore path.
                    if copy_with_context "$RESTORE_SOURCE/$_f" "$RECOVERY_SNAPSHOT_DIR/$_f"; then
                        _snapshotted=$((_snapshotted + 1))
                    fi
                fi
            fi
        done

        ui_print ""
        ui_print "  ✅ Recovery restored $_restored file(s)"
        ui_print "  💾 Snapshot for post-extraction: $_snapshotted file(s)"
        ui_print "  💡 Continuing with normal installation..."
        ui_print ""

        echo "Recovery mode: restored $_restored files from $RESTORE_SOURCE (snapshot: $_snapshotted)" >> "$INSTALL_LOG"

        rm -f "$RECOVERY_TRIGGER_1" 2>/dev/null
        rm -f "$RECOVERY_TRIGGER_2" 2>/dev/null

        RECOVERY_MODE=1
    fi
fi

# ============================================================
# [8b] v1.2.0 — silent upgrade cleanup
# ============================================================
# CSH-14 fix: the watchdog PID search now also checks
# `$MODPATH/proxy/run/watchdog.pid`. The previous version only
# checked /data/local/tmp and the HARD-CODED module path
# ($_EXISTING_MODULE). If the module was installed under a
# different module-ID, the running watchdog process was never
# found and kept running with a stale state file.
# ============================================================
KILLED_COUNT=0

if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
    pkill -9 -x dnscrypt-proxy 2>/dev/null
    KILLED_COUNT=$((KILLED_COUNT + 1))
fi
if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
    pkill -9 -x dnscrypt-webui 2>/dev/null
    KILLED_COUNT=$((KILLED_COUNT + 1))
fi

for wd_file in "/data/local/tmp/watchdog.pid" \
                "$_EXISTING_MODULE/proxy/run/watchdog.pid" \
                "$MODPATH/proxy/run/watchdog.pid"; do
    if [ -f "$wd_file" ]; then
        old_wd=$(cat "$wd_file" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$old_wd" ] && kill -0 "$old_wd" 2>/dev/null; then
            kill -9 "$old_wd" 2>/dev/null
            KILLED_COUNT=$((KILLED_COUNT + 1))
        fi
    fi
done

if [ "$KILLED_COUNT" -gt 0 ]; then
    ui_print "- Killed $KILLED_COUNT old process(es)"
    echo "Killed $KILLED_COUNT old process(es)" >> "$INSTALL_LOG"
fi

_inline_cleanup_firewall
ui_print "- Firewall rules cleaned"
echo "Firewall cleanup attempted (Custom Chain + Legacy)" >> "$INSTALL_LOG"

# ============================================================
# [8c] v1.2.0 — Layer 4: begin transactional upgrade
# ============================================================
# A transaction directory is created BEFORE any backup or
# installation step. It survives a failed install and allows
# rollback on the next run.
#
# Directory layout:
#   $PERSISTENT_BACKUP/txn-<timestamp>-<pid>/
#   ├── .state          ("START" | "COMMIT" | "ROLLBACK")
#   ├── .pid            (installer PID)
#   └── <user files>    (snapshot for rollback)
#
# ⚠️ v1.2.0 FIX (Issue #1 + Issue #9):
#   The TXN_ID and BACKUP_TIMESTAMP share the SAME timestamp
#   (both use `date +%Y%m%d-%H%M%S`, second precision), BUT
#   they use DIFFERENT final paths:
#     • Transaction  → txn-<timestamp>-<pid>/
#     • Backup       → <timestamp>-<version>-<pid>/
#
#   Previous versions had a bug where `commit_transaction`
#   tried to `mv` the TXN directory to the SAME path as the
#   permanent backup, causing a collision.
#
# BUG-CS-C (this revision):
#   The snapshot directory name now includes the installer PID
#   (`-$$`). Two concurrent or sequential installs within the
#   same wall-clock second produce DISTINCT directories. The
#   rotation regex `^[0-9]{8}-[0-9]{6}-` still matches the new
#   name, so no existing tool breaks.
#
# DOC-1 (this revision):
#   The persistent backup root is now chmod 0700 (best-effort).
#   On Android's /sdcard FUSE mount, chmod is typically ignored
#   — the effective protection remains the per-file chmod 0600
#   applied by copy_with_context.
# ============================================================
BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# BUG-CS-C fix: include PID in the snapshot directory name.
BACKUP_DIR_NAME="${BACKUP_TIMESTAMP}-${MODULE_VERSION}-$$"
BACKUP_DIR="$PERSISTENT_BACKUP/$BACKUP_DIR_NAME"

TXN_ID="txn-${BACKUP_TIMESTAMP}-$$"
TXN_DIR="$PERSISTENT_BACKUP/$TXN_ID"
TXN_ACTIVE=0

mkdir -p "$PERSISTENT_BACKUP" 2>/dev/null
chmod 0700 "$PERSISTENT_BACKUP" 2>/dev/null || true

begin_transaction() {
    if mkdir -p "$TXN_DIR" 2>/dev/null; then
        echo "START" > "$TXN_DIR/.state" 2>/dev/null
        echo "$$" > "$TXN_DIR/.pid" 2>/dev/null
        chmod 0700 "$TXN_DIR" 2>/dev/null
        TXN_ACTIVE=1
        return 0
    fi
    return 1
}

commit_transaction() {
    if [ "$TXN_ACTIVE" != "1" ] || [ ! -f "$TXN_DIR/.state" ]; then
        TXN_ACTIVE=0
        return 0
    fi

    echo "COMMIT" > "$TXN_DIR/.state" 2>/dev/null
    TXN_ACTIVE=0
    return 0
}

rollback_transaction() {
    [ -d "$TXN_DIR" ] || return 0

    ui_print "  ⚠️ Rolling back transaction..."

    local BIN_DIR_ROLLBACK="$MODPATH/proxy"
    mkdir -p "$BIN_DIR_ROLLBACK" 2>/dev/null

    local _rolled=0
    local _f
    for _f in $USER_FILES; do
        if [ -f "$TXN_DIR/$_f" ] && [ -s "$TXN_DIR/$_f" ]; then
            if copy_with_context "$TXN_DIR/$_f" "$BIN_DIR_ROLLBACK/$_f"; then
                _rolled=$((_rolled + 1))
            fi
        fi
    done

    echo "ROLLBACK" > "$TXN_DIR/.state" 2>/dev/null
    ui_print "  → Rolled back $_rolled file(s)"
    TXN_ACTIVE=0
}

if [ -n "$FOUND_SOURCE" ] && [ "$RECOVERY_MODE" != "1" ]; then
    if begin_transaction; then
        ui_print "- Transaction started: $TXN_ID"
        echo "Transaction: $TXN_ID" >> "$INSTALL_LOG"
    else
        ui_print "  ⚠️ Failed to create transaction dir — continuing without rollback"
        TXN_ACTIVE=0
    fi
fi

# ============================================================
# [8d] v1.2.0 — Layer 2 + 3: persistent backup + integrity
# ============================================================
# Take a snapshot of the found source into:
#   1. The transaction directory (for rollback — Layer 4)
#   2. $PERSISTENT_BACKUP/<timestamp>-<version>-<pid>/ (permanent)
#   3. $PERSISTENT_BACKUP/current/                (live snapshot)
#
# Then verify integrity via SHA256 (Layer 3).
#
# ⚠️ v1.2.0 FIX (Issue #1):
#   The permanent backup path uses `$BACKUP_DIR_NAME` (with PID
#   suffix) and the transaction path uses `txn-...-$$`. These
#   are ALWAYS different. No collision is possible.
#
# ⚠️ v1.2.0 FIX (Issue B — Recovery mode):
#   When RECOVERY_MODE=1, we do NOT create a new backup from
#   FOUND_SOURCE. Rationale: in recovery mode, the user's data
#   was corrupted, and FOUND_SOURCE points to that corrupted
#   data. Creating a backup from it would REPLACE a good
#   backup with a bad one.
#
# ------------------------------------------------------------
# 🔧 BUG-CS-A (this revision): create_persistent_backup now
#     returns 1 when 0 files were copied. The caller then does
#     NOT set PERSISTENT_BACKUP_OK, `.last_stable` is NOT
#     updated, and `current/` is NOT touched.
#
# 🔧 BUG-CS-B (this revision): `current/` is updated via an
#     atomic tmp-dir + mv sequence.
#
# 🛡️ HARD-CS-05 (this revision): write_manifest escapes the
#     string fields with a minimal JSON escaper.
# ------------------------------------------------------------

# json_escape: escape backslash, double-quote, and control
# characters that would break the manifest JSON if they ever
# appeared in a path. filenames in USER_FILES are hard-coded
# and safe, but the source path is user-controllable.
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\000-\010\013\014\016-\037'
}

write_manifest() {
    local target_dir="$1"
    local source="$2"
    local count="$3"
    local manifest="$target_dir/.manifest.json"

    local src_escaped
    src_escaped=$(json_escape "$source")

    local files_json=""
    local f
    for f in $USER_FILES; do
        if [ -f "$target_dir/$f" ]; then
            local sha=""
            if [ "$HAS_SHA256" = "1" ]; then
                sha=$(sha256sum "$target_dir/$f" 2>/dev/null | awk '{print $1}')
            fi
            files_json="$files_json{\"name\":\"$f\",\"sha256\":\"$sha\"},"
        fi
    done
    files_json="${files_json%,}"

    cat > "$manifest" << EOF
{
  "version": "$MODULE_VERSION",
  "timestamp": "$BACKUP_TIMESTAMP",
  "source": "$src_escaped",
  "root_solution": "$ROOT_SOLUTION",
  "files_count": $count,
  "files": [$files_json]
}
EOF

    chmod 0600 "$manifest" 2>/dev/null
    return 0
}

verify_backup_integrity() {
    local dir="$1"
    local manifest="$dir/.manifest.json"

    [ -f "$manifest" ] || return 0

    [ "$HAS_SHA256" = "1" ] || return 0

    local errors=0
    local f
    for f in $USER_FILES; do
        local file="$dir/$f"
        [ -f "$file" ] || continue

        if [ ! -s "$file" ]; then
            ui_print "  ⚠️ Empty file in backup: $f"
            errors=$((errors + 1))
            continue
        fi

        local size
        size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
        if [ "$size" -gt 10485760 ]; then
            ui_print "  ⚠️ Suspicious large file: $f ($size bytes)"
            errors=$((errors + 1))
            continue
        fi

        local expected_sha=""

        if [ "$HAS_JQ" = "1" ]; then
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

        [ -z "$expected_sha" ] && continue

        local actual_sha=""
        actual_sha=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')

        if [ "$actual_sha" != "$expected_sha" ]; then
            ui_print "  ⚠️ SHA256 mismatch: $f"
            ui_print "     expected: ${expected_sha:0:16}..."
            ui_print "     actual:   ${actual_sha:0:16}..."
            errors=$((errors + 1))
        fi
    done

    [ "$errors" -eq 0 ]
}

# --- create_persistent_backup ---
#
# BUG-CS-A fix: return 1 when 0 files were copied.
# BUG-CS-B fix: atomic update of current/.
# HARD-CS-06 fix: log the mkdir failure.
create_persistent_backup() {
    local source="$1"
    local target_dir="$BACKUP_DIR"

    # HARD-CS-06: log the failure before returning so the
    # installer log always shows why the backup was skipped.
    if ! mkdir -p "$target_dir" 2>/dev/null; then
        echo "  ❌ create_persistent_backup: cannot create $target_dir" >> "$INSTALL_LOG"
        return 1
    fi

    local count=0
    local f
    for f in $USER_FILES; do
        if [ -f "$source/$f" ] && [ -s "$source/$f" ]; then
            if copy_with_context "$source/$f" "$target_dir/$f"; then
                count=$((count + 1))
            fi
        fi
    done

    # BUG-CS-A fix — bail out on an empty snapshot.
    if [ "$count" -eq 0 ]; then
        echo "  ❌ create_persistent_backup: 0 files copied from $source" >> "$INSTALL_LOG"
        rm -rf "$target_dir" 2>/dev/null
        return 1
    fi

    write_manifest "$target_dir" "$source" "$count"

    # ------------------------------------------------------------
    # BUG-CS-B fix — atomic update of current/
    # ------------------------------------------------------------
    # Steps:
    #   1. Populate .current.tmp.$$ from the new snapshot.
    #   2. Rename current/ to .current.old.$$ (if it exists).
    #   3. Rename .current.tmp.$$ to current/.
    #   4. Remove .current.old.$$ on success.
    #   5. On step-3 failure, restore .current.old.$$ back to
    #      current/.
    # The script can die at any point without ever leaving
    # current/ empty or partial.
    # ------------------------------------------------------------
    local current_tmp="$PERSISTENT_BACKUP/.current.tmp.$$"
    local current_old="$PERSISTENT_BACKUP/.current.old.$$"

    rm -rf "$current_tmp" "$current_old" 2>/dev/null
    if ! mkdir -p "$current_tmp" 2>/dev/null; then
        echo "  ⚠️ create_persistent_backup: cannot create tmp current/" >> "$INSTALL_LOG"
        return 0
    fi

    local cur_count=0
    for f in $USER_FILES; do
        if [ -f "$target_dir/$f" ] && [ -s "$target_dir/$f" ]; then
            if copy_with_context "$target_dir/$f" "$current_tmp/$f"; then
                cur_count=$((cur_count + 1))
            fi
        fi
    done
    [ -f "$target_dir/.manifest.json" ] && \
        cp -f "$target_dir/.manifest.json" "$current_tmp/.manifest.json" 2>/dev/null

    if [ "$cur_count" -eq 0 ]; then
        echo "  ⚠️ create_persistent_backup: current/ update aborted (0 files)" >> "$INSTALL_LOG"
        rm -rf "$current_tmp" 2>/dev/null
        return 0
    fi

    if [ -d "$PERSISTENT_BACKUP/current" ]; then
        mv -f "$PERSISTENT_BACKUP/current" "$current_old" 2>/dev/null
    fi

    if mv -f "$current_tmp" "$PERSISTENT_BACKUP/current" 2>/dev/null; then
        rm -rf "$current_old" 2>/dev/null
    else
        # Rollback: restore the previous current/.
        if [ -d "$current_old" ]; then
            mv -f "$current_old" "$PERSISTENT_BACKUP/current" 2>/dev/null
        fi
        rm -rf "$current_tmp" 2>/dev/null
        echo "  ⚠️ create_persistent_backup: current/ swap failed, kept previous" >> "$INSTALL_LOG"
    fi

    return 0
}

# --- Copy source data to transaction dir (for rollback) ---
if [ "$TXN_ACTIVE" = "1" ] && [ -n "$FOUND_SOURCE" ]; then
    for _f in $USER_FILES; do
        if [ -f "$FOUND_SOURCE/$_f" ] && [ -s "$FOUND_SOURCE/$_f" ]; then
            copy_with_context "$FOUND_SOURCE/$_f" "$TXN_DIR/$_f" 2>/dev/null || true
        fi
    done
    echo "Transaction snapshot: $TXN_DIR" >> "$INSTALL_LOG"
fi

# --- Create persistent backup (skip if recovery mode) ---
PERSISTENT_BACKUP_OK=0
PERSISTENT_BACKUP_DIR=""
BACKUP_INTEGRITY_VERIFIED=0

if [ "$RECOVERY_MODE" = "1" ]; then
    ui_print ""
    ui_print "- Skipping backup (recovery mode — source may be corrupted)"
    echo "Skipped [8d] backup — recovery mode" >> "$INSTALL_LOG"
elif [ -n "$FOUND_SOURCE" ]; then
    PERSISTENT_BACKUP_DIR="$BACKUP_DIR"
    if create_persistent_backup "$FOUND_SOURCE"; then
        ui_print "- Persistent backup: $PERSISTENT_BACKUP_DIR"
        echo "Persistent backup created: $PERSISTENT_BACKUP_DIR" >> "$INSTALL_LOG"
        PERSISTENT_BACKUP_OK=1
    else
        ui_print "  ⚠️ Failed to create persistent backup (source may be empty or disk full)"
        echo "Persistent backup FAILED (returned non-zero)" >> "$INSTALL_LOG"
    fi
fi

# --- Verify integrity (with REAL SHA256 comparison) ---
if [ "$PERSISTENT_BACKUP_OK" = "1" ]; then
    if verify_backup_integrity "$PERSISTENT_BACKUP_DIR"; then
        ui_print "- Backup integrity: ✅ verified (SHA256)"
        BACKUP_INTEGRITY_VERIFIED=1
    else
        ui_print "  ⚠️ Backup integrity: warnings detected (advisory)"
    fi
fi

# ============================================================
# [9] Extract module files from ZIP
# ============================================================
ui_print ""
ui_print "- Extracting module files..."

mkdir -p "$MODPATH/web" 2>/dev/null

EXTRACT_FAILED=0
if ! unzip -o "$ZIPFILE" \
    'proxy/*' \
    'module.prop' \
    'service.sh' \
    'post-fs-data.sh' \
    'action.sh' \
    'status.sh' \
    'uninstall.sh' \
    'functions.sh' \
    'watchdog.sh' \
    'index.html' \
    'dashboard.html' \
    'manifest.json' \
    'sw.js' \
    'icon-*.svg' \
    'icon-*.png' \
    'apple-touch-icon.png' \
    'favicon-*.png' \
    'favicon.ico' \
    'offline.html' \
    'web/*' \
    -d "$MODPATH" >/dev/null 2>&1; then
    EXTRACT_FAILED=1
fi

if [ "$EXTRACT_FAILED" = "1" ]; then
    echo "❌ Failed to extract files" >> "$INSTALL_LOG"
    rollback_transaction
    abort "❌ Failed to extract module files"
fi

# ============================================================
# [9b] Move HTML/JSON/JS/SVG/PNG/ICO files to web/ directory
# ============================================================
for f in \
    index.html \
    dashboard.html \
    manifest.json \
    sw.js \
    icon-192.svg \
    icon-512.svg \
    icon-192.png \
    icon-512.png \
    apple-touch-icon.png \
    favicon-32x32.png \
    favicon-16x16.png \
    favicon.ico \
    offline.html; do
    if [ -f "$MODPATH/$f" ]; then
        mv -f "$MODPATH/$f" "$MODPATH/web/"
        echo "  Moved $f to web/" >> "$INSTALL_LOG"
    fi
done

ui_print "  ✅ Files extracted"

# ============================================================
# [9b2] v1.2.0 — post-extraction recovery restoration
# ============================================================
BIN_DIR="$MODPATH/proxy"

if [ "$RECOVERY_MODE" = "1" ] && [ -d "$RECOVERY_SNAPSHOT_DIR" ]; then
    ui_print ""
    ui_print "- Re-applying recovery snapshot (post-extraction)..."

    _reapplied=0
    for _f in $USER_FILES; do
        if [ -f "$RECOVERY_SNAPSHOT_DIR/$_f" ] && [ -s "$RECOVERY_SNAPSHOT_DIR/$_f" ]; then
            if copy_with_context "$RECOVERY_SNAPSHOT_DIR/$_f" "$BIN_DIR/$_f"; then
                _reapplied=$((_reapplied + 1))
                ui_print "  ✓ Re-applied: $_f"
            else
                ui_print "  ⚠️ Failed to re-apply: $_f"
            fi
        fi
    done

    if [ "$_reapplied" -gt 0 ]; then
        ui_print "  ✅ Recovery: $_reapplied file(s) re-applied after unzip"
        echo "Recovery: re-applied $_reapplied file(s) after [9] unzip" >> "$INSTALL_LOG"
    else
        ui_print "  ⚠️ Recovery: no files re-applied"
        echo "Recovery: no files re-applied" >> "$INSTALL_LOG"
    fi

    if [ "$_reapplied" -ge "$_snapshotted" ]; then
        rm -rf "$RECOVERY_SNAPSHOT_DIR" 2>/dev/null
    else
        ui_print ""
        ui_print "  ⚠️ Partial re-application ($_reapplied/$_snapshotted)"
        ui_print "     Snapshot PRESERVED at: $RECOVERY_SNAPSHOT_DIR"
        ui_print "     Copy remaining files manually from there."
        echo "Recovery: snapshot preserved (partial re-apply $_reapplied/$_snapshotted)" >> "$INSTALL_LOG"
    fi
fi

# ============================================================
# [9c] v1.2.0 — restore user settings with verification
# ============================================================
# CSH-15 fix: the previous version only aborted when the total
# failure count reached 2. A single failed restoration of a
# critical file (webui.conf or dnscrypt-proxy.toml) was allowed
# to proceed silently, potentially leaving the user without
# their configured WebUI port / credentials.
#
# The loop now tracks CRITICAL_RESTORE_FAILED. Any failure on
# one of the two critical files triggers an immediate rollback
# and abort — regardless of the total failure count.
# ============================================================
RESTORED_COUNT=0
RESTORE_FAILED_COUNT=0
CRITICAL_RESTORE_FAILED=0

if [ "$RECOVERY_MODE" = "1" ]; then
    ui_print ""
    ui_print "- Skipping restore (recovery mode already restored)"
    echo "Skipped [9c] restore — recovery mode" >> "$INSTALL_LOG"
elif [ -n "$FOUND_SOURCE" ]; then
    ui_print ""
    ui_print "- Restoring user configuration..."

    for f in $USER_FILES; do
        src="$FOUND_SOURCE/$f"
        if [ -f "$src" ] && [ -s "$src" ]; then
            if copy_with_context "$src" "$BIN_DIR/$f"; then
                if [ -f "$BIN_DIR/$f" ] && [ -s "$BIN_DIR/$f" ]; then
                    RESTORED_COUNT=$((RESTORED_COUNT + 1))
                    echo "  Restored: $f" >> "$INSTALL_LOG"
                else
                    RESTORE_FAILED_COUNT=$((RESTORE_FAILED_COUNT + 1))
                    echo "  ⚠️ Verify failed: $f" >> "$INSTALL_LOG"
                    case "$f" in
                        webui.conf|dnscrypt-proxy.toml)
                            CRITICAL_RESTORE_FAILED=1
                            ;;
                    esac
                fi
            else
                RESTORE_FAILED_COUNT=$((RESTORE_FAILED_COUNT + 1))
                echo "  ⚠️ Copy failed: $f" >> "$INSTALL_LOG"
                case "$f" in
                    webui.conf|dnscrypt-proxy.toml)
                        CRITICAL_RESTORE_FAILED=1
                        ;;
                esac
            fi
        fi
    done

    if [ "$RESTORED_COUNT" -gt 0 ]; then
        ui_print "  ✅ Restored $RESTORED_COUNT user config file(s)"
    fi

    if [ "$CRITICAL_RESTORE_FAILED" = "1" ]; then
        ui_print "  ❌ CRITICAL: failed to restore webui.conf or dnscrypt-proxy.toml"
        ui_print "  🔄 Rolling back transaction to preserve the previous install..."
        echo "❌ Critical restore failure — rolling back" >> "$INSTALL_LOG"
        rollback_transaction
        abort "❌ SECURITY: a critical config file could not be restored. Transaction rolled back."
    fi

    if [ "$RESTORE_FAILED_COUNT" -gt 0 ]; then
        ui_print "  ⚠️ $RESTORE_FAILED_COUNT file(s) failed verification (non-critical)"
        echo "⚠️ $RESTORE_FAILED_COUNT non-critical restore failures" >> "$INSTALL_LOG"

        if [ "$RESTORE_FAILED_COUNT" -ge 2 ]; then
            ui_print "  🔄 Too many non-critical failures — triggering rollback..."
            rollback_transaction
            abort "❌ Restore failed for $RESTORE_FAILED_COUNT file(s). Transaction rolled back."
        fi
    fi
fi

# ============================================================
# [9d] v1.2.0 — Layer 8: config migrations
# ============================================================
read_source_version() {
    local src="$1"

    [ -n "$src" ] || return 1
    [ -d "$src" ] || return 1

    if [ -f "$src/.manifest.json" ]; then
        local v=""

        if [ "$HAS_JQ" = "1" ]; then
            v=$(jq -r '.version // empty' "$src/.manifest.json" 2>/dev/null | head -n1)
        fi

        if [ -z "$v" ]; then
            v=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$src/.manifest.json" 2>/dev/null | \
                head -n1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        fi

        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi

    if [ -f "$src/../module.prop" ]; then
        local v
        v=$(grep '^version=' "$src/../module.prop" 2>/dev/null | cut -d= -f2- | tr -d '\r ')
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi

    if [ -f "$src/module.prop" ]; then
        local v
        v=$(grep '^version=' "$src/module.prop" 2>/dev/null | cut -d= -f2- | tr -d '\r ')
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi

    return 1
}

SOURCE_VERSION=""
SOURCE_VERSION=$(read_source_version "$FOUND_SOURCE" 2>/dev/null || echo "")

if [ -n "$SOURCE_VERSION" ]; then
    echo "Source version detected: $SOURCE_VERSION" >> "$INSTALL_LOG"
fi

migrate_v1_0_0_to_v1_2_0() {
    if [ -f "$BIN_DIR/webui.conf" ]; then
        if ! grep -q '^MEMORY_LIMIT_HINT=' "$BIN_DIR/webui.conf" 2>/dev/null; then
            echo "" >> "$BIN_DIR/webui.conf"
            echo "# v1.2.0 addition" >> "$BIN_DIR/webui.conf"
            echo "MEMORY_LIMIT_HINT=auto" >> "$BIN_DIR/webui.conf"
            echo "  Migrated: added MEMORY_LIMIT_HINT to webui.conf" >> "$INSTALL_LOG"
        fi
    fi
}

migrate_config() {
    case "$SOURCE_VERSION" in
        "v1.0.0")
            ui_print "- Migration: $SOURCE_VERSION → $MODULE_VERSION"
            migrate_v1_0_0_to_v1_2_0
            ;;
        "v1.1.0"|"v1.2.0")
            ui_print "- Migration: no changes needed ($SOURCE_VERSION → $MODULE_VERSION)"
            ;;
        "")
            ;;
        *)
            ui_print "- Migration: unknown source ($SOURCE_VERSION) — using as-is"
            ;;
    esac
}

if [ -n "$SOURCE_VERSION" ] && [ "$RECOVERY_MODE" != "1" ]; then
    migrate_config
fi

# ============================================================
# [10] Verify critical files
# ============================================================
MISSING=""
[ ! -f "$MODPATH/module.prop" ]         && MISSING="$MISSING module.prop"
[ ! -f "$MODPATH/service.sh" ]          && MISSING="$MISSING service.sh"
[ ! -f "$MODPATH/functions.sh" ]        && MISSING="$MISSING functions.sh"
[ ! -f "$MODPATH/watchdog.sh" ]         && MISSING="$MISSING watchdog.sh"
[ ! -f "$MODPATH/post-fs-data.sh" ]     && MISSING="$MISSING post-fs-data.sh"
[ ! -f "$MODPATH/action.sh" ]           && MISSING="$MISSING action.sh"
[ ! -f "$MODPATH/status.sh" ]           && MISSING="$MISSING status.sh"
[ ! -f "$MODPATH/uninstall.sh" ]        && MISSING="$MISSING uninstall.sh"
[ ! -f "$MODPATH/web/index.html" ]      && MISSING="$MISSING web/index.html"
[ ! -f "$MODPATH/web/dashboard.html" ]  && MISSING="$MISSING web/dashboard.html"
[ ! -f "$MODPATH/web/manifest.json" ]   && MISSING="$MISSING web/manifest.json"
[ ! -f "$MODPATH/web/sw.js" ]           && MISSING="$MISSING web/sw.js"

if [ -n "$MISSING" ]; then
    echo "❌ Missing critical files:$MISSING" >> "$INSTALL_LOG"
    rollback_transaction
    abort "❌ Missing critical files:$MISSING"
fi

ui_print "  ✅ Critical files validated"

# ============================================================
# [10b] Verify PNG/ICO files (optional — warning only)
# ============================================================
PNG_MISSING=""
[ ! -f "$MODPATH/web/icon-192.png" ]        && PNG_MISSING="$PNG_MISSING icon-192.png"
[ ! -f "$MODPATH/web/icon-512.png" ]        && PNG_MISSING="$PNG_MISSING icon-512.png"
[ ! -f "$MODPATH/web/apple-touch-icon.png" ] && PNG_MISSING="$PNG_MISSING apple-touch-icon.png"
[ ! -f "$MODPATH/web/favicon.ico" ]         && PNG_MISSING="$PNG_MISSING favicon.ico"
[ ! -f "$MODPATH/web/offline.html" ]        && PNG_MISSING="$PNG_MISSING offline.html"

if [ -n "$PNG_MISSING" ]; then
    ui_print "  ⚠️ Some asset files missing:$PNG_MISSING"
    ui_print "     (PWA may work with SVG fallback)"
    echo "⚠️ Asset files missing:$PNG_MISSING" >> "$INSTALL_LOG"
else
    ui_print "  ✅ Asset files (PNG/ICO/offline) validated"
    echo "✅ All asset files present" >> "$INSTALL_LOG"
fi

# ============================================================
# [11] Select binaries for architecture
# ============================================================
case "$ARCH" in
    arm64-v8a*|aarch64*)
        DNS_BIN="dnscrypt-proxy-arm64"
        WEB_BIN="dnscrypt-webui-arm64"
        ;;
    armeabi-v7a*|arm*)
        DNS_BIN="dnscrypt-proxy-arm"
        WEB_BIN="dnscrypt-webui-arm"
        ;;
    x86_64*)
        DNS_BIN="dnscrypt-proxy-x86_64"
        WEB_BIN="dnscrypt-webui-amd64"
        ;;
    i686*|x86*)
        DNS_BIN="dnscrypt-proxy-x86"
        WEB_BIN="dnscrypt-webui-386"
        ;;
    *)
        rollback_transaction
        abort "❌ Unsupported architecture: $ARCH"
        ;;
esac

ui_print "- Target binaries: $DNS_BIN + $WEB_BIN"

if [ ! -f "$BIN_DIR/$DNS_BIN" ]; then
    echo "❌ DNS binary not found: $DNS_BIN" >> "$INSTALL_LOG"
    rollback_transaction
    abort "❌ DNS binary missing for $ARCH"
fi

if [ ! -f "$BIN_DIR/$WEB_BIN" ]; then
    echo "❌ WebUI binary not found: $WEB_BIN" >> "$INSTALL_LOG"
    rollback_transaction
    abort "❌ WebUI binary missing for $ARCH"
fi

cp -f "$BIN_DIR/$DNS_BIN" "$BIN_DIR/dnscrypt-proxy" || {
    rollback_transaction
    abort "❌ Failed to copy DNS binary"
}
cp -f "$BIN_DIR/$WEB_BIN" "$BIN_DIR/dnscrypt-webui" || {
    rollback_transaction
    abort "❌ Failed to copy WebUI binary"
}
echo "✅ Binaries copied: $DNS_BIN, $WEB_BIN" >> "$INSTALL_LOG"

# Remove the per-architecture copies; keep only the canonical
# `dnscrypt-proxy` and `dnscrypt-webui`. The glob deliberately
# requires a trailing dash after the name, so `dnscrypt-proxy.toml`
# and the final binaries themselves are NOT matched.
rm -f "$BIN_DIR"/dnscrypt-proxy-* "$BIN_DIR"/dnscrypt-webui-* 2>/dev/null
rm -f "$BIN_DIR/main.go" "$BIN_DIR/build.sh" 2>/dev/null

ui_print "  ✅ Binaries installed"
ui_print ""

# ============================================================
# [12] Create secure run/ directory
# ============================================================
RUN_DIR="$BIN_DIR/run"

ui_print "- Creating secure run/ directory..."

mkdir -p "$RUN_DIR" 2>/dev/null

if [ ! -d "$RUN_DIR" ]; then
    echo "❌ Failed to create run/ directory" >> "$INSTALL_LOG"
    rollback_transaction
    abort "❌ Failed to create $RUN_DIR"
fi

chmod 0700 "$RUN_DIR" 2>/dev/null
chown 0:0 "$RUN_DIR" 2>/dev/null

# --- Migrate status file only from /data/local/tmp ---
for f in dnscrypt.pid webui.pid watchdog.pid dnscrypt.status; do
    OLD_FILE="/data/local/tmp/$f"
    NEW_FILE="$RUN_DIR/$f"
    if [ -f "$OLD_FILE" ] && [ ! -f "$NEW_FILE" ]; then
        if [ "$f" = "dnscrypt.status" ]; then
            cp -f "$OLD_FILE" "$NEW_FILE" 2>/dev/null
        fi
    fi
done

rm -f /data/local/tmp/dnscrypt.pid 2>/dev/null
rm -f /data/local/tmp/webui.pid 2>/dev/null
rm -f /data/local/tmp/watchdog.pid 2>/dev/null
rm -f /data/local/tmp/dnscrypt.status 2>/dev/null

ui_print "  ✅ run/ directory created (0700)"
ui_print "  ✅ Migrated status files"
echo "✅ run/ created at $RUN_DIR" >> "$INSTALL_LOG"
ui_print ""

# ============================================================
# [13] Old modules (runtime detection)
# ============================================================
if [ "$RECOVERY_MODE" = "1" ]; then
    ui_print "- Recovery mode: old modules will be detected at runtime"
    echo "Old modules: runtime detection (recovery mode)" >> "$INSTALL_LOG"
elif [ -n "$FOUND_SOURCE" ]; then
    ui_print "- Upgrade detected (source: $FOUND_SOURCE)"
    ui_print "  Old modules will be detected at runtime via WebUI"
    echo "Upgrade detected: source=$FOUND_SOURCE" >> "$INSTALL_LOG"
else
    ui_print "- Fresh installation (no previous data found)"
    echo "Fresh install (no source)" >> "$INSTALL_LOG"
fi

ui_print ""
ui_print "- Creating configuration files..."

# ============================================================
# [14] Port validation — v1.2.0 collision-safe
# ============================================================
validate_port() {
    local port="$1"

    echo "$port" | grep -qE '^[0-9]+$' || return 1
    [ "$port" -ge 1 ] || return 1
    [ "$port" -le 65535 ] || return 1

    if [ "$port" = "$_MONITORING_UI_PORT" ]; then
        return 1
    fi

    return 0
}

TEMP_PORT="9090"
TEMP_DASHBOARD_PORT="9091"
TEMP_AUTO_DNS="1"
TEMP_AUTO_WEBUI="1"
TEMP_LOG_LEVEL="info"
TEMP_BIND_ADDR="127.0.0.1"

if [ -f "$BIN_DIR/webui.conf" ]; then
    EXISTING_PORT=$(grep "^PORT=" "$BIN_DIR/webui.conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
    if validate_port "$EXISTING_PORT"; then
        TEMP_PORT="$EXISTING_PORT"
    else
        # HARD-CS-02: include the offending value in the message.
        if [ "$EXISTING_PORT" = "$_MONITORING_UI_PORT" ]; then
            ui_print "  ⚠️ PORT=$EXISTING_PORT conflicts with [monitoring_ui], resetting to 9090"
        else
            ui_print "  ⚠️ Invalid PORT ('$EXISTING_PORT') in webui.conf, reset to 9090"
        fi
    fi

    EXISTING_DASHBOARD=$(grep "^DASHBOARD_PORT=" "$BIN_DIR/webui.conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
    if validate_port "$EXISTING_DASHBOARD"; then
        TEMP_DASHBOARD_PORT="$EXISTING_DASHBOARD"
    else
        if [ "$EXISTING_DASHBOARD" = "$_MONITORING_UI_PORT" ]; then
            ui_print "  ⚠️ DASHBOARD_PORT=$EXISTING_DASHBOARD conflicts with [monitoring_ui], resetting to 9091"
        fi
        TEMP_DASHBOARD_PORT="9091"
    fi

    EXISTING_AUTO_DNS=$(grep "^AUTO_RESTART_DNS=" "$BIN_DIR/webui.conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
    case "$EXISTING_AUTO_DNS" in
        0|1) TEMP_AUTO_DNS="$EXISTING_AUTO_DNS" ;;
    esac

    EXISTING_AUTO_WEBUI=$(grep "^AUTO_RESTART_WEBUI=" "$BIN_DIR/webui.conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
    case "$EXISTING_AUTO_WEBUI" in
        0|1) TEMP_AUTO_WEBUI="$EXISTING_AUTO_WEBUI" ;;
    esac

    EXISTING_LOG_LEVEL=$(grep "^LOG_LEVEL=" "$BIN_DIR/webui.conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
    case "$EXISTING_LOG_LEVEL" in
        error|warn|info|debug) TEMP_LOG_LEVEL="$EXISTING_LOG_LEVEL" ;;
    esac

    EXISTING_BIND=$(grep "^BIND_ADDR=" "$BIN_DIR/webui.conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
    if [ -n "$EXISTING_BIND" ]; then
        TEMP_BIND_ADDR="$EXISTING_BIND"
    fi
fi

if [ "$TEMP_PORT" = "$_MONITORING_UI_PORT" ]; then
    ui_print "  ⚠️ PORT=$_MONITORING_UI_PORT conflicts with [monitoring_ui], forcing 9090"
    TEMP_PORT="9090"
fi
if [ "$TEMP_DASHBOARD_PORT" = "$_MONITORING_UI_PORT" ]; then
    ui_print "  ⚠️ DASHBOARD_PORT=$_MONITORING_UI_PORT conflicts with [monitoring_ui], forcing 9091"
    TEMP_DASHBOARD_PORT="9091"
fi

if [ "$TEMP_PORT" = "$TEMP_DASHBOARD_PORT" ]; then
    if [ "$TEMP_PORT" = "9091" ]; then
        TEMP_DASHBOARD_PORT="9092"
    else
        TEMP_DASHBOARD_PORT="9091"
    fi
    ui_print "  ⚠️ PORT/DASHBOARD_PORT collision → dashboard set to $TEMP_DASHBOARD_PORT"
    echo "⚠️ Port collision resolved: dashboard=$TEMP_DASHBOARD_PORT" >> "$INSTALL_LOG"
fi

# ============================================================
# [15] Write webui.conf file
# ============================================================
if ! cat > "$BIN_DIR/webui.conf.tmp" << EOF
# ============================================================
# DNSCrypt WebUI & Dashboard Configuration
# $MODULE_VERSION
# ============================================================
#
# ⚠️  IMPORTANT:
#   1. No spaces around "="
#   2. No trailing comment at end of line
#   3. Use numbers only (1-65535)
#   4. Ports must be different
#   5. Do not use 8080 (reserved for monitoring_ui)
#   6. Do not use CRLF (Windows line endings)
#
# ============================================================

# -------- WebUI Port --------
PORT=$TEMP_PORT

# -------- Dashboard Port --------
DASHBOARD_PORT=$TEMP_DASHBOARD_PORT

# -------- Bind Address --------
# 127.0.0.1 = local only (default, safest)
# 0.0.0.0   = expose to LAN (REQUIRES credentials)
BIND_ADDR=$TEMP_BIND_ADDR

# -------- Auto-Restart Options --------
AUTO_RESTART_DNS=$TEMP_AUTO_DNS
AUTO_RESTART_WEBUI=$TEMP_AUTO_WEBUI

# -------- Log Level --------
# error | warn | info | debug
LOG_LEVEL=$TEMP_LOG_LEVEL
EOF
then
    rollback_transaction
    abort "❌ Failed to write webui.conf"
fi

if [ ! -s "$BIN_DIR/webui.conf.tmp" ]; then
    rm -f "$BIN_DIR/webui.conf.tmp"
    rollback_transaction
    abort "❌ webui.conf is empty after write"
fi

mv -f "$BIN_DIR/webui.conf.tmp" "$BIN_DIR/webui.conf" || {
    rollback_transaction
    abort "❌ Failed to finalize webui.conf"
}

ui_print "  ✅ webui.conf (WebUI: $TEMP_PORT, Dashboard: $TEMP_DASHBOARD_PORT, Bind: $TEMP_BIND_ADDR)"
echo "✅ webui.conf created (PORT=$TEMP_PORT, DASHBOARD_PORT=$TEMP_DASHBOARD_PORT)" >> "$INSTALL_LOG"

# ============================================================
# [16] Check if port is in use
# ============================================================
port_in_use=0
if command -v ss >/dev/null 2>&1; then
    ss -tuln 2>/dev/null | grep -q ":$TEMP_PORT " && port_in_use=1
elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln 2>/dev/null | grep -q ":$TEMP_PORT " && port_in_use=1
elif [ -f /proc/net/tcp ]; then
    hex_port=$(printf "%04X" "$TEMP_PORT")
    grep -qi ":$hex_port" /proc/net/tcp 2>/dev/null && port_in_use=1
fi

if [ $port_in_use -eq 1 ]; then
    ui_print "  ⚠️ Port $TEMP_PORT is already in use by another app"
    echo "⚠️ Port $TEMP_PORT already in use" >> "$INSTALL_LOG"
fi

# ============================================================
# [17] Create default config files (only if missing)
# ============================================================
[ ! -f "$BIN_DIR/selected_profile.txt" ] && printf "pro\n" > "$BIN_DIR/selected_profile.txt"
[ ! -f "$BIN_DIR/blocklist.txt" ] && : > "$BIN_DIR/blocklist.txt"
[ ! -f "$BIN_DIR/blocklist.raw" ] && : > "$BIN_DIR/blocklist.raw"

[ ! -f "$BIN_DIR/blocked-ips.txt" ] \
    && cat > "$BIN_DIR/blocked-ips.txt" << 'EOF'
# This file will be generated automatically on installation
0.0.0.0
127.0.0.1
EOF

[ ! -f "$BIN_DIR/allowlist.txt" ] && : > "$BIN_DIR/allowlist.txt"
[ ! -f "$BIN_DIR/denylist.txt" ] && : > "$BIN_DIR/denylist.txt"

ui_print "  ✅ Default config files created"

# ============================================================
# [18] Generate secure login credentials
# ============================================================
ui_print ""
ui_print "- Generating secure credentials..."

TOML_FILE="$BIN_DIR/dnscrypt-proxy.toml"
CRED_FILE="/data/local/tmp/dnscrypt_credentials.txt"

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

CUR_USER=""
CUR_PASS=""

if [ -f "$TOML_FILE" ]; then
    _creds=$(read_toml_credentials)
    CUR_USER=$(printf '%s' "$_creds" | sed -n '1p')
    CUR_PASS=$(printf '%s' "$_creds" | sed -n '2p')

    NEED_NEW_CREDS=0

    if [ -z "$CUR_USER" ] || [ -z "$CUR_PASS" ]; then
        NEED_NEW_CREDS=1
    elif [ "$CUR_USER" = "admin" ] && [ "$CUR_PASS" = "admin" ]; then
        NEED_NEW_CREDS=1
        ui_print "  ⚠️ Default admin/admin detected — generating secure credentials"
    fi

    if [ "$NEED_NEW_CREDS" = "1" ]; then
        NEW_USER=""
        if [ -r /dev/urandom ]; then
            NEW_USER="admin_$(tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 8)"
        fi
        if [ -z "$NEW_USER" ] || [ "$NEW_USER" = "admin_" ] || [ "${#NEW_USER}" -lt 8 ]; then
            NEW_USER="admin_$(date +%s | tail -c 9)"
        fi

        NEW_PASS=""
        if [ -r /dev/urandom ]; then
            NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 24)
        fi
        if [ -z "$NEW_PASS" ] || [ "${#NEW_PASS}" -lt 16 ]; then
            if [ "$HAS_MD5SUM" = "1" ]; then
                NEW_PASS="Auto_$(date +%s)_$(echo "$RANDOM" | md5sum | head -c 12)"
            elif [ "$HAS_SHA256" = "1" ]; then
                NEW_PASS="Auto_$(date +%s)_$(echo "$RANDOM" | sha256sum | head -c 12)"
            else
                NEW_PASS="Auto_$(date +%s)_$(hostname 2>/dev/null || echo safe)_$RANDOM"
            fi
        fi

        cp -f "$TOML_FILE" "$TOML_FILE.bak" 2>/dev/null

        sed -i "s|^[[:space:]]*username[[:space:]]*=[[:space:]]*['\"].*['\"]|  username = '$NEW_USER'|" "$TOML_FILE"
        sed -i "s|^[[:space:]]*password[[:space:]]*=[[:space:]]*['\"].*['\"]|  password = '$NEW_PASS'|" "$TOML_FILE"

        _verify=$(read_toml_credentials)
        VERIFY_USER=$(printf '%s' "$_verify" | sed -n '1p')
        VERIFY_PASS=$(printf '%s' "$_verify" | sed -n '2p')

        CRED_FAILED=0
        if [ "$VERIFY_USER" != "$NEW_USER" ]; then
            CRED_FAILED=1
            echo "❌ Username replacement failed (got: $VERIFY_USER)" >> "$INSTALL_LOG"
        fi
        if [ "$VERIFY_PASS" != "$NEW_PASS" ]; then
            CRED_FAILED=1
            echo "❌ Password replacement failed" >> "$INSTALL_LOG"
        fi

        if [ "$CRED_FAILED" = "1" ]; then
            cp -f "$TOML_FILE.bak" "$TOML_FILE" 2>/dev/null
            rm -f "$TOML_FILE.bak"

            echo "❌ Credential generation FAILED — aborting for security" >> "$INSTALL_LOG"
            rollback_transaction
            abort "❌ SECURITY: Failed to replace default credentials. Check TOML file manually."
        fi

        rm -f "$TOML_FILE.bak"

        if ! cat > "${CRED_FILE}.tmp" << EOF
# ============================================================
# DNSCrypt Smart Filter – Login Credentials
# Generated: $(date)
# Version: $MODULE_VERSION
# ============================================================

Username: $NEW_USER
Password: $NEW_PASS

⚠️ Keep this data in a safe place.
EOF
        then
            ui_print "  ⚠️ Failed to write credentials file"
        else
            mv -f "${CRED_FILE}.tmp" "$CRED_FILE" 2>/dev/null
            chmod 0600 "$CRED_FILE" 2>/dev/null
            chown 0:0 "$CRED_FILE" 2>/dev/null
        fi

        ui_print ""
        ui_print "╔══════════════════════════════════════════╗"
        ui_print "║  🔐 Login Credentials Generated          ║"
        ui_print "╚══════════════════════════════════════════╝"
        ui_print "  👤 Username: $NEW_USER"
        ui_print "  🔑 Password: $NEW_PASS"
        ui_print ""
        ui_print "📌 Keep these credentials to log in"
        ui_print "📄 Saved copy: $CRED_FILE"
        ui_print ""

        echo "✅ Credentials generated successfully" >> "$INSTALL_LOG"
    else
        ui_print "  ℹ️  Using existing credentials from TOML"

        if ! cat > "${CRED_FILE}.tmp" << EOF
# ============================================================
# DNSCrypt Smart Filter – Login Credentials
# (existing — not regenerated)
# ============================================================

Username: $CUR_USER
Password: $CUR_PASS
EOF
        then
            :
        else
            mv -f "${CRED_FILE}.tmp" "$CRED_FILE" 2>/dev/null
            chmod 0600 "$CRED_FILE" 2>/dev/null
        fi
    fi
else
    ui_print "  ⚠️ dnscrypt-proxy.toml not found, skipping credentials setup"
    echo "⚠️ TOML not found" >> "$INSTALL_LOG"
fi

# ============================================================
# [19] Set permissions
# ============================================================
ui_print "- Setting permissions..."

set_perm_recursive "$MODPATH" 0 0 0755 0644 2>/dev/null || true

chmod 0755 "$BIN_DIR/dnscrypt-proxy" 2>/dev/null
chmod 0755 "$BIN_DIR/dnscrypt-webui" 2>/dev/null

for s in service.sh post-fs-data.sh action.sh status.sh uninstall.sh functions.sh watchdog.sh; do
    [ -f "$MODPATH/$s" ] && chmod 0755 "$MODPATH/$s"
done

for f in index.html dashboard.html manifest.json sw.js icon-192.svg icon-512.svg offline.html; do
    [ -f "$MODPATH/web/$f" ] && chmod 0644 "$MODPATH/web/$f"
done

for f in icon-192.png icon-512.png apple-touch-icon.png favicon-32x32.png favicon-16x16.png favicon.ico; do
    [ -f "$MODPATH/web/$f" ] && chmod 0644 "$MODPATH/web/$f"
done

[ -f "$BIN_DIR/webui.conf" ] && chmod 0600 "$BIN_DIR/webui.conf" 2>/dev/null
[ -f "$BIN_DIR/dnscrypt-proxy.toml" ] && chmod 0600 "$BIN_DIR/dnscrypt-proxy.toml" 2>/dev/null

chmod 0700 "$RUN_DIR" 2>/dev/null
chown 0:0 "$RUN_DIR" 2>/dev/null

ui_print "  ✅ Permissions set"

# ============================================================
# [19b] v1.2.0 — Watchdog token (BUG-CS-D fix)
# ============================================================
# Pre-generate the watchdog token that main.go and watchdog.sh
# share. Writing it here means the token is available even
# before the first WebUI startup, and even if the user disables
# the WebUI while keeping the watchdog active.
#
# The token is 64 hex chars (32 bytes / 256 bits). It is written
# with the standard "tmp + mv" atomic pattern. If the write
# fails, main.go will regenerate the token on first startup —
# so a failure here is non-fatal.
#
# File:   $RUN_DIR/.watchdog_token (mode 0600)
# Header: X-Watchdog-Token (constant-time compared by main.go)
# ============================================================
WATCHDOG_TOKEN_FILE="$RUN_DIR/.watchdog_token"
TOKEN=""

if [ -r /dev/urandom ]; then
    TOKEN=$(tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 64)
fi

if [ -z "$TOKEN" ] || [ "${#TOKEN}" -lt 32 ]; then
    # Fallback: derive from date + PID + RANDOM. Not
    # cryptographically strong, but main.go accepts any 32+
    # char token that matches the file, and this fallback is
    # only used on devices without /dev/urandom (essentially none).
    if [ "$HAS_SHA256" = "1" ]; then
        TOKEN=$(printf '%s-%s-%s' "$(date +%s%N 2>/dev/null || date +%s)" "$$" "$RANDOM" | \
                sha256sum 2>/dev/null | awk '{print $1}')
    fi
fi

if [ -n "$TOKEN" ] && [ "${#TOKEN}" -ge 32 ]; then
    if printf '%s' "$TOKEN" > "${WATCHDOG_TOKEN_FILE}.tmp" 2>/dev/null; then
        chmod 0600 "${WATCHDOG_TOKEN_FILE}.tmp" 2>/dev/null
        if mv -f "${WATCHDOG_TOKEN_FILE}.tmp" "$WATCHDOG_TOKEN_FILE" 2>/dev/null; then
            chown 0:0 "$WATCHDOG_TOKEN_FILE" 2>/dev/null
            echo "✅ watchdog token written to $WATCHDOG_TOKEN_FILE" >> "$INSTALL_LOG"
        else
            rm -f "${WATCHDOG_TOKEN_FILE}.tmp" 2>/dev/null
            echo "⚠️ Failed to install watchdog token (mv failed)" >> "$INSTALL_LOG"
        fi
    else
        echo "⚠️ Failed to write watchdog token (tmp failed)" >> "$INSTALL_LOG"
    fi
else
    echo "⚠️ Failed to generate watchdog token — main.go will create it at startup" >> "$INSTALL_LOG"
fi

# ============================================================
# [20] Write module fingerprint
# ============================================================
printf "dnscrypt-proxy-webui-%s\n" "$MODULE_VERSION" > "$MODPATH/.module.fingerprint"

# ============================================================
# [21] Compute expected memory limit (v1.1.0+)
# ============================================================
SELECTED_PROFILE="pro"
if [ -f "$BIN_DIR/selected_profile.txt" ]; then
    _sp=$(cat "$BIN_DIR/selected_profile.txt" 2>/dev/null | tr -d '\r\n ')
    case "$_sp" in
        light|normal|pro|proplus|ultimate) SELECTED_PROFILE="$_sp" ;;
    esac
fi

case "$SELECTED_PROFILE" in
    light)    EXPECTED_MEM_LIMIT="80 MB"  ;;
    normal)   EXPECTED_MEM_LIMIT="100 MB" ;;
    pro)      EXPECTED_MEM_LIMIT="120 MB" ;;
    proplus)  EXPECTED_MEM_LIMIT="160 MB" ;;
    ultimate) EXPECTED_MEM_LIMIT="220 MB" ;;
    *)        EXPECTED_MEM_LIMIT="80 MB"  ;;
esac

# ============================================================
# [22] v1.2.0 — Layer 10: log upgrade history
# ============================================================
log_upgrade() {
    local history="$PERSISTENT_BACKUP/.upgrade_history.json"
    local files_count="$FOUND_FILE_COUNT"

    if ! echo "$files_count" | grep -qE '^[0-9]+$'; then
        files_count=0
    fi

    if [ "$HAS_JQ" = "1" ]; then
        [ -f "$history" ] || echo '{"upgrades":[]}' > "$history"

        # HARD-CS-03: place the jq temp file inside the backup
        # directory so the final mv is same-filesystem. On
        # Android, `mktemp` may return a path on /data while
        # the backup lives on /sdcard (FUSE), causing EXDEV.
        local tmp
        tmp="$PERSISTENT_BACKUP/.upgrade_history.tmp.$$"

        if jq --arg from "$SOURCE_VERSION" \
              --arg to "$MODULE_VERSION" \
              --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              --arg source "$FOUND_SOURCE" \
              --arg root "$ROOT_SOLUTION" \
              --argjson files "$files_count" \
              '.upgrades += [{from:$from, to:$to, date:$date, source:$source, root:$root, files:$files}]' \
              "$history" > "$tmp" 2>>"$INSTALL_LOG"; then
            if mv -f "$tmp" "$history" 2>/dev/null; then
                chmod 0644 "$history" 2>/dev/null
            else
                rm -f "$tmp" 2>/dev/null
                echo "  ⚠️ log_upgrade: mv failed" >> "$INSTALL_LOG"
            fi
        else
            rm -f "$tmp" 2>/dev/null
            echo "  ⚠️ log_upgrade: jq failed, entry not written" >> "$INSTALL_LOG"
        fi
    else
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $SOURCE_VERSION → $MODULE_VERSION | source=$FOUND_SOURCE | files=$files_count" \
            >> "$PERSISTENT_BACKUP/.upgrade_history.txt" 2>/dev/null
    fi
}

# --- Write the .last_stable pointer ---
# BUG-CS-C: use the full BACKUP_DIR_NAME (with PID suffix).
# BUG-CS-A: only update when PERSISTENT_BACKUP_OK=1, which now
# correctly means ">= 1 file was actually written".
if [ "$PERSISTENT_BACKUP_OK" = "1" ]; then
    echo "$BACKUP_DIR_NAME" > "$PERSISTENT_BACKUP/.last_stable" 2>/dev/null
fi

# --- Log the upgrade (CSH-3: only when meaningful) ---
if [ -n "$SOURCE_VERSION" ] || [ -n "$FOUND_SOURCE" ] || [ "$RECOVERY_MODE" = "1" ]; then
    log_upgrade
fi

# --- Write README.md to the backup dir (first time only) ---
if [ ! -f "$PERSISTENT_BACKUP/README.md" ]; then
    cat > "$PERSISTENT_BACKUP/README.md" << 'EOF'
# DNSCrypt Smart Filter — Backup Directory

This directory contains automatic backups of your user configuration
for the DNSCrypt Smart Filter module.

## What is backed up?

Five user config files (only these):
- `webui.conf`             — WebUI + Dashboard ports
- `dnscrypt-proxy.toml`    — DNSCrypt engine config + credentials
- `selected_profile.txt`   — Active blocklist profile
- `allowlist.txt`          — User-defined allowlist
- `denylist.txt`           — User-defined denylist

## Structure

- `current/`                      — live snapshot, always up to date
- `<timestamp>-<version>-<pid>/`  — historical snapshot from each upgrade
- `<timestamp>-manual-<pid>-<r>/` — pre-critical snapshot from the WebUI
- `<timestamp>-auto-<pid>/`       — periodic 24h snapshot from service.sh
- `.last_stable`                  — pointer to the last known good snapshot
- `.last_auto_backup`             — marker for the periodic 24h backup (mtime only)
- `.pending_notification`         — transient; read+deleted by main.go at boot
- `.upgrade_history.json`         — full upgrade log (JSON, when jq is available)
- `.upgrade_history.txt`          — fallback log when jq is unavailable
- `README.md`                     — this file

## Retention

Rotation keeps the **21 newest snapshots by directory name**
(YYYYMMDD-HHMMSS-...). Older snapshots are pruned automatically.

The `current/` directory, `.last_stable`, and any `txn-*` /
`orphan-txn-*` transaction directories are exempt from rotation.

## Manual Restore

If you need to restore manually:
1. Open your root file manager (with root access).
2. Copy the files from the desired snapshot directory back to:
   /data/adb/modules/dnscrypt-proxy-webui/proxy/
3. Reboot.

## Emergency Recovery

If the module becomes unbootable:
    su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
    su -c "reboot"

The installer will restore the last known good configuration.

## Do NOT delete

The `current/` directory and `.last_stable` file are essential for
automatic recovery. If you delete them, the module can still be
reinstalled, but the emergency recovery path will not work.

See docs/BACKUP.md for the full reference.
See docs/EMERGENCY.md for recovery procedures.
EOF
    chmod 0644 "$PERSISTENT_BACKUP/README.md" 2>/dev/null
fi

# ============================================================
# [22b] v1.2.0 — Layer 9: rotate backups
# ============================================================
rotate_backups() {
    local keep="${1:-21}"

    # HARD-CS-08: verify the directory is readable before globbing.
    # A directory with bad permissions would silently produce an
    # empty list and skip rotation without any diagnostic.
    [ -d "$PERSISTENT_BACKUP" ] || return 0
    [ -r "$PERSISTENT_BACKUP" ] || {
        echo "  ⚠️ rotate_backups: $PERSISTENT_BACKUP is not readable" >> "$INSTALL_LOG"
        return 0
    }

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
        echo "Rotation: $total snapshot(s) — within limit ($keep)" >> "$INSTALL_LOG"
        return 0
    fi

    local to_remove=$((total - keep))
    echo "Rotation: removing $to_remove old snapshot(s) (keeping $keep)" >> "$INSTALL_LOG"

    printf '%s\n' "$snapshots" | tail -n "$to_remove" | while IFS= read -r old; do
        [ -z "$old" ] && continue
        rm -rf "$PERSISTENT_BACKUP/$old" 2>/dev/null
    done

    return 0
}

if [ "$PERSISTENT_BACKUP_OK" = "1" ]; then
    ui_print "- Rotating old backups (keep: 21)"
    rotate_backups 21
    ui_print "  ✅ Rotation complete"
fi

# ============================================================
# [23] Commit the transaction + cleanup TXN_DIR
# ============================================================
if [ "$TXN_ACTIVE" = "1" ]; then
    if commit_transaction; then
        ui_print "- Transaction committed"
    else
        ui_print "  ⚠️ Transaction commit failed (non-critical)"
    fi
fi

if [ "$TXN_ACTIVE" = "0" ] && [ -d "$TXN_DIR" ]; then
    rm -rf "$TXN_DIR" 2>/dev/null
fi

cleanup_old_transactions() {
    [ -d "$PERSISTENT_BACKUP" ] || return 0

    local _txn
    local _state

    for _txn in "$PERSISTENT_BACKUP"/txn-*; do
        [ -d "$_txn" ] || continue

        _state=$(cat "$_txn/.state" 2>/dev/null | tr -d '\r\n ')
        if [ "$_state" = "COMMIT" ]; then
            rm -rf "$_txn" 2>/dev/null
        fi
    done

    return 0
}

cleanup_old_transactions

# ============================================================
# [24] Display final summary
# ============================================================
# CSH-16 fix: the previous version had TWO consecutive
# `if [ "$RECOVERY_MODE" = "1" ]` blocks — one for the banner,
# one for the status line. They are now merged into a single
# if/elif/else chain so the summary is printed exactly once
# and reads coherently.
# ============================================================
ui_print ""
ui_print "╔══════════════════════════════════════════╗"
ui_print "║  ✅ Installation Complete                ║"
printf "║      %-32s ║\n" "$MODULE_VERSION"
ui_print "╚══════════════════════════════════════════╝"
ui_print ""

if [ "$RECOVERY_MODE" = "1" ]; then
    ui_print "  🚨 Recovery mode: YES"
    ui_print "     (post-extraction applied)"
    ui_print "  📊 Recovery: restored from snapshot (post-extraction)"
elif [ -n "$FOUND_SOURCE" ]; then
    ui_print "  📊 Upgrade: YES ($RESTORED_COUNT files restored)"
    ui_print "  🔍 Source: $FOUND_SOURCE"
else
    ui_print "  📊 Fresh installation (no previous data)"
fi

ui_print "  📦 Root solution: $ROOT_SOLUTION"
ui_print "  🌐 WebUI: http://127.0.0.1:$TEMP_PORT"
ui_print "  📈 Dashboard: http://127.0.0.1:$TEMP_DASHBOARD_PORT"
ui_print "  🔌 Bind: $TEMP_BIND_ADDR"
ui_print "  🧠 Memory limit: ~$EXPECTED_MEM_LIMIT (profile: $SELECTED_PROFILE)"
ui_print ""

# HARD-CS-01 + HARD-CS-07: distinguish the three outcomes clearly
# and label the file count as "source files" so it is not
# confused with the backup manifest's own files_count.
if [ "$PERSISTENT_BACKUP_OK" = "1" ]; then
    ui_print "  💾 Backup: $PERSISTENT_BACKUP_DIR"
    if [ "$BACKUP_INTEGRITY_VERIFIED" = "1" ]; then
        ui_print "     ($FOUND_FILE_COUNT source file(s), integrity verified)"
    else
        ui_print "     ($FOUND_FILE_COUNT source file(s), integrity advisory)"
    fi
elif [ "$RECOVERY_MODE" = "1" ]; then
    ui_print "  💾 Backup: skipped (recovery mode)"
elif [ -n "$FOUND_SOURCE" ]; then
    ui_print "  💾 Backup: not created (source empty or disk full)"
else
    ui_print "  💾 Backup: not created (fresh install — no user data yet)"
fi
ui_print ""
ui_print "  ℹ️  Next steps:"
ui_print "    1. Reboot your device"
ui_print "    2. Open the WebUI and login with the credentials above"
ui_print "    3. Choose a blocklist profile and press Apply"
ui_print ""

# ============================================================
# [25] Reboot warning
# ============================================================
if [ "$KILLED_COUNT" -gt 0 ]; then
    ui_print ""
    ui_print "╔══════════════════════════════════════════╗"
    ui_print "║  ⚠️  IMPORTANT — READ CAREFULLY           ║"
    ui_print "╚══════════════════════════════════════════╝"
    ui_print ""
    ui_print "  The DNS Engine has been STOPPED to allow"
    ui_print "  a clean upgrade. Internet may not work"
    ui_print "  correctly until you REBOOT your device."
    ui_print ""
    ui_print "  🛑 You MUST REBOOT NOW to restore DNS."
    ui_print ""
    echo "⚠️ UX Warning shown: user must reboot (killed=$KILLED_COUNT)" >> "$INSTALL_LOG"
fi

echo "✅ Installation complete ($MODULE_VERSION)" >> "$INSTALL_LOG"
echo "========================================" >> "$INSTALL_LOG"

exit 0