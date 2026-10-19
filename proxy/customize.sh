#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — customize.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-18
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Magisk / KernelSU / APatch installer script.
#
# Responsibilities:
#   • Verify installation environment (MODPATH security)
#   • Detect architecture, root solution, recovery mode
#   • Multi-source user-data discovery
#   • Persistent backup to /sdcard
#   • Integrity verification with SHA256
#   • Transactional atomic upgrade with rollback
#   • Root-solution-aware candidate paths
#   • SELinux context preservation
#   • Recovery mode restoration
#   • Config migrations between versions
#   • Backup rotation + upgrade history
#   • Extract module files, restore user settings
#   • Generate credentials, set permissions, fingerprint
#   • Mirror companion APK to /sdcard (best-effort)
#
# The 5 user files preserved on every upgrade:
#   webui.conf, dnscrypt-proxy.toml, selected_profile.txt,
#   allowlist.txt, denylist.txt.
#
# Recovery mode is triggered by the presence of a `recovery`
# file ($MODPATH/recovery) or /data/adb/dnscrypt-recovery. On
# trigger, the 5 user files are restored from a snapshot and
# re-applied AFTER §[9] unzip overwrites them.
#
# Language policy: English only (Global edition).
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path + version
# ============================================================
# MODDIR resolution: caller-supplied, then $0-derived.
# Runs before --version so the version can be read from disk.
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

# get_module_version — reads `version=` from module.prop.
#
# Search order (highest priority first):
#   1. $MODDIR/module.prop         — installed module
#   2. $ZIPFILE                    — during install (SKIPUNZIP=1)
#   3. hardcoded fallback
#
# The ZIPFILE lookup uses `unzip -p` (pipe to stdout) so no
# temporary file is created.
get_module_version() {
    local v

    if [ -f "$MODDIR/module.prop" ]; then
        v=$(grep "^version=" "$MODDIR/module.prop" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi

    if [ -n "${ZIPFILE:-}" ] && [ -f "$ZIPFILE" ] && command -v unzip >/dev/null 2>&1; then
        v=$(unzip -p "$ZIPFILE" module.prop 2>/dev/null | grep "^version=" | head -n 1 | cut -d= -f2- | tr -d '\r ')
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi

    printf 'v0.0.0-unknown'
}

case "${1:-}" in
    --version)
        echo "$0: $(get_module_version)"
        exit 0
        ;;
esac

# --- MODPATH check ---
# Set by Magisk / KernelSU / APatch at install time.
if [ -z "$MODPATH" ]; then
    echo "❌ Please install via Magisk Manager or KernelSU!" >&2
    exit 1
fi

# --- Security: MODPATH must be inside /data/adb ---
case "$MODPATH" in
    /data/adb/*) ;;
    *)
        echo "❌ SECURITY: MODPATH '$MODPATH' is outside /data/adb. Installation aborted." >&2
        exit 1
        ;;
esac

if [ ! -d "$MODPATH" ]; then
    echo "❌ MODPATH '$MODPATH' does not exist or is not a directory." >&2
    exit 1
fi

# --- abort wrapper ---
# Magisk/KernelSU provide `abort`; a manual invocation does not.
# The wrapper guarantees a consistent error path in both cases.
if ! command -v abort >/dev/null 2>&1; then
    abort() {
        echo "$1" >&2
        exit 1
    }
fi

# shellcheck disable=SC2034
SKIPUNZIP=1

# ============================================================
# [2] Constants
# ============================================================
# Reserved port for dnscrypt-proxy's monitoring_ui.
#
# ⚠️ Must match boot-mini.sh:_MONITORING_UI_PORT. This is the
#    ONLY legitimate duplicate: customize.sh runs before the
#    module is extracted, so boot-mini.sh is not on disk yet.
_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"

# Reference path of a previously installed module.
_EXISTING_MODULE="/data/adb/modules/dnscrypt-proxy-webui"

# Persistent backup location.
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"

# The 5 user data files (single source of truth).
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# Recovery mode trigger files.
RECOVERY_TRIGGER_1="$MODPATH/recovery"
RECOVERY_TRIGGER_2="/data/adb/dnscrypt-recovery"

# Recovery snapshot directory. Survives §[9] unzip because it
# lives inside $MODPATH (which §[9] does not clean).
RECOVERY_SNAPSHOT_DIR="$MODPATH/.recovery_snapshot"

# ============================================================
# [3] Required and optional tools
# ============================================================
for tool in unzip sed tr date grep head cut awk find chmod chown; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        abort "❌ Required tool '$tool' not found. Installation aborted."
    fi
done

HAS_MD5SUM=0
command -v md5sum >/dev/null 2>&1 && HAS_MD5SUM=1

HAS_SHA256=0
command -v sha256sum >/dev/null 2>&1 && HAS_SHA256=1

HAS_RESTORECON=0
command -v restorecon >/dev/null 2>&1 && HAS_RESTORECON=1

HAS_CHCON=0
command -v chcon >/dev/null 2>&1 && HAS_CHCON=1

HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

# ============================================================
# [3b] Extract module.prop + boot-mini.sh, then source Layer 0
# ============================================================
# Both files are extracted early:
#   • module.prop  — so get_module_version() has a source.
#   • boot-mini.sh — so the Layer-0 primitives are available
#     before [4b]..[8]. Failure to extract is non-fatal: the
#     installer continues with fallbacks.
if [ -n "$ZIPFILE" ] && [ -f "$ZIPFILE" ]; then
    unzip -o "$ZIPFILE" 'module.prop' 'boot-mini.sh' -d "$MODPATH" >/dev/null 2>&1 || true
fi

if [ -f "$MODPATH/boot-mini.sh" ]; then
    # shellcheck disable=SC1091
    . "$MODPATH/boot-mini.sh" 2>/dev/null || true
fi

# ============================================================
# [4] Read module version
# ============================================================
MODULE_VERSION="$(get_module_version)"

# versionCode is logged for traceability; the root manager uses
# it for update detection.
MODULE_VERSION_CODE=""
if [ -f "$MODPATH/module.prop" ]; then
    MODULE_VERSION_CODE=$(grep "^versionCode=" "$MODPATH/module.prop" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
fi

# ============================================================
# [4b] Detect root solution
# ============================================================
# Detects the ACTIVE root solution. On a dual-root device (e.g.
# KernelSU installed over a leftover Magisk tree, or vice versa)
# a simple early-return ordering could pick the wrong one.
#
# Strategy: score each candidate, return the highest.
#   • Environment variable set → +2 (strong signal: the manager
#                                  injected its own env)
#   • Directory exists         → +1 (weak signal: could be a
#                                  stale leftover from a previous
#                                  install)
#
# Ties (equal scores) are broken by precedence:
#   KernelSU > APatch > Magisk
#
# A score of 0 for every candidate → "unknown".
detect_root_solution() {
    local ksu=0 apatch=0 magisk=0

    [ -n "${KSU_VER:-}" ]   && ksu=$((ksu + 2))
    [ -d "/data/adb/ksu" ]  && ksu=$((ksu + 1))

    [ -n "${APATCH:-}" ]      && apatch=$((apatch + 2))
    [ -d "/data/adb/ap" ]     && apatch=$((apatch + 1))

    [ -n "${MAGISK_VER_CODE:-}" ] && magisk=$((magisk + 2))
    [ -d "/data/adb/magisk" ]     && magisk=$((magisk + 1))

    if [ "$ksu" -gt 0 ] && [ "$ksu" -ge "$apatch" ] && [ "$ksu" -ge "$magisk" ]; then
        echo "kernelsu"
        return 0
    fi
    if [ "$apatch" -gt 0 ] && [ "$apatch" -ge "$magisk" ]; then
        echo "apatch"
        return 0
    fi
    if [ "$magisk" -gt 0 ]; then
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
ui_print "║      Global edition (bilingual WebUI)    ║"
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
ui_print "- 📱 Architecture: $ARCH"
ui_print "- 🔐 Root solution: $ROOT_SOLUTION"
echo "Architecture: $ARCH" >> "$INSTALL_LOG"

# ============================================================
# [7] Firewall cleanup
# ============================================================
# Best-effort removal of the DNAT rules installed by previous
# versions. Runs before any new firewall state is installed, so
# an upgrade from a version with different rules does not leave
# orphans behind.
#
# The rule set removed here MUST be functionally equivalent to
# functions.sh:manage_firewall 0, uninstall.sh:_inline_cleanup_firewall,
# and post-fs-data.sh:inline_firewall_cleanup. All four remove the
# same set of rules; they differ only in the comment tag applied
# to the loopback rules during best-effort legacy cleanup.
#
# The legacy RETURN rules for the pre-v1.2.0 default bootstrap
# set are best-effort: they are removed so that an upgrade from
# a version that used the old list does not leave orphans.
_inline_cleanup_firewall() {
    # --- nftables: delete the entire table ---
    if command -v nft >/dev/null 2>&1; then
        nft delete table inet dnscrypt_filter 2>/dev/null
        nft delete table ip dnscrypt_filter 2>/dev/null
        nft delete table ip6 dnscrypt_filter 2>/dev/null
    fi

    # --- iptables (IPv4) ---
    if command -v iptables >/dev/null 2>&1; then
        local _chain="DNSCRYPT_OUT"

        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -F "$_chain" --wait 3 2>/dev/null
        iptables -t nat -X "$_chain" --wait 3 2>/dev/null

        # Tagged variants
        iptables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null

        # Untagged variants
        iptables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 --wait 3 2>/dev/null

        # Legacy RETURN rules for known bootstrap IPs
        local _ip
        for _ip in 127.0.0.1 9.9.9.9 8.8.8.8 1.1.1.1 1.0.0.1 8.8.4.4 208.67.222.222 208.67.220.220; do
            iptables -t nat -D OUTPUT -d "$_ip" -p udp --dport 53 \
                -j RETURN --wait 3 2>/dev/null
            iptables -t nat -D OUTPUT -d "$_ip" -p tcp --dport 53 \
                -j RETURN --wait 3 2>/dev/null
        done
    fi

    # --- ip6tables (IPv6) ---
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

    return 0
}

# ============================================================
# [7b] SELinux-aware file copy
# ============================================================
# Copies a single file and preserves its SELinux context.
# Preference: restorecon → chcon → no-op.
# Applies chmod 0600 (owner-only).
#
# Functional behaviour matches functions.sh:copy_with_context.
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
# [8] Multi-source discovery of user data
# ============================================================
# Identifies the module by CONTENT (module.prop `id=`), not by
# folder name. Handles renames, case variations, and stale
# coexisting copies across all root-solution roots.
#
# Score formula (highest wins):
#   score = files * 1,000,000
#         + major *    10,000
#         + minor *       100
#         + patch
#
# Intent: a source with MORE user files ALWAYS wins over one
# with fewer, regardless of version. Ties on file count are
# broken by version.
#
# Tie-breaker: identical scores → the candidate whose PARENT
# directory is literally named `dnscrypt-proxy-webui` wins.
# This prefers the canonical module folder over an update
# staging folder.
CANDIDATE_SOURCES=""
MODULE_ID="dnscrypt-proxy-webui"

for _root in /data/adb/modules /data/adb/modules_update /data/adb/ksu/modules /data/adb/ap/modules; do
    [ -d "$_root" ] || continue
    for _m in "$_root"/*; do
        [ -d "$_m" ] || continue
        [ -f "$_m/module.prop" ] || continue
        _id=$(grep ^id= "$_m/module.prop" | head -1 | cut -d= -f2-)
        _id=$(printf "%s" "$_id" | tr -d "\r ")
        [ "$_id" = "$MODULE_ID" ] || continue
        [ -f "$_m/proxy/webui.conf" ] && [ -s "$_m/proxy/webui.conf" ] || continue
        CANDIDATE_SOURCES="$CANDIDATE_SOURCES $_m/proxy"
    done
done

CANDIDATE_SOURCES="$CANDIDATE_SOURCES $PERSISTENT_BACKUP/current"
CANDIDATE_SOURCES="$CANDIDATE_SOURCES $PERSISTENT_BACKUP"
CANDIDATE_SOURCES="$CANDIDATE_SOURCES /data/local/tmp/dnscrypt-webui-backup"

FOUND_SOURCE=""
FOUND_FILE_COUNT=0
_best_version=""
_best_score=0

for candidate in $CANDIDATE_SOURCES; do
    [ -d "$candidate" ] || continue
    _found_count=0
    for _f in $USER_FILES; do
        if [ -f "$candidate/$_f" ] && [ -s "$candidate/$_f" ]; then
            _found_count=$((_found_count + 1))
        fi
    done
    [ "$_found_count" -lt 3 ] && continue

    _m_dir=$(dirname "$candidate")
    _ver="0.0.0"

    # Manifest takes priority over module.prop — backup
    # snapshots have no module.prop.
    if [ -f "$candidate/.manifest.json" ]; then
        _ver=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$candidate/.manifest.json" 2>/dev/null | \
               head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    fi

    if [ "$_ver" = "0.0.0" ] && [ -f "$_m_dir/module.prop" ]; then
        _ver=$(grep ^version= "$_m_dir/module.prop" | head -1 | cut -d= -f2-)
    fi

    _ver=$(printf "%s" "$_ver" | tr -d "v\r ")

    _vmaj=$(echo "$_ver" | cut -d. -f1)
    _vmin=$(echo "$_ver" | cut -d. -f2)
    _vpat=$(echo "$_ver" | cut -d. -f3)
    case "$_vmaj" in ""|*[!0-9]*) _vmaj=0 ;; esac
    case "$_vmin" in ""|*[!0-9]*) _vmin=0 ;; esac
    case "$_vpat" in ""|*[!0-9]*) _vpat=0 ;; esac

    _score=$(( _found_count * 1000000 + _vmaj * 10000 + _vmin * 100 + _vpat ))
    if [ "$_score" -gt "$_best_score" ]; then
        _best_score="$_score"
        _best_version="$_ver"
        FOUND_SOURCE="$candidate"
        FOUND_FILE_COUNT="$_found_count"
    elif [ "$_score" -eq "$_best_score" ] && [ -n "$FOUND_SOURCE" ]; then
        _cand_base=$(basename "$_m_dir")
        _best_base=$(basename "$(dirname "$FOUND_SOURCE")")
        if [ "$_cand_base" = "$MODULE_ID" ] && [ "$_best_base" != "$MODULE_ID" ]; then
            FOUND_SOURCE="$candidate"
            FOUND_FILE_COUNT="$_found_count"
            _best_version="$_ver"
        fi
    fi
done

if [ -z "$FOUND_SOURCE" ]; then
    ui_print "  -> No existing user data found (fresh install)"
    echo "No user data found" >> "$INSTALL_LOG"
else
    if [ "$FOUND_SOURCE" = "$PERSISTENT_BACKUP/current" ]; then
        _found_name="backup/current"
    elif [ "$FOUND_SOURCE" = "$PERSISTENT_BACKUP" ]; then
        _found_name="backup"
    else
        _found_name=$(basename "$(dirname "$FOUND_SOURCE")")
    fi
    ui_print "  ✅ Found: $_found_name (v$_best_version, $FOUND_FILE_COUNT files)"
    echo "Selected: $_found_name (v$_best_version, $FOUND_FILE_COUNT files) at $FOUND_SOURCE" >> "$INSTALL_LOG"
fi

# ============================================================
# [8a] Recovery mode
# ============================================================
# Triggered by the presence of either:
#   • $MODPATH/recovery               (in-module trigger)
#   • /data/adb/dnscrypt-recovery     (external trigger)
#
# Restore source priority:
#   1. `.last_stable` pointer — last known-good snapshot.
#   2. `current/` live snapshot — newest successful install.
#   3. FOUND_SOURCE — best in-place candidate from [8].
#
# When active:
#   • The 5 files are restored into $MODPATH/proxy/ AND also
#     snapshotted into $RECOVERY_SNAPSHOT_DIR (so they can be
#     re-applied AFTER [9] unzip overwrites them).
#   • [9c] is skipped (restore already happened).
#   • [9b2] re-applies the snapshot after [9] and [9b].
#
# Both trigger files are removed on successful restore.
#
# If no source is available: log a warning, remove the trigger
# files, proceed with a normal install.
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
# [8b] Silent upgrade cleanup
# ============================================================
# Kills any running instance before [9] overwrites binaries in
# use, and so the new version starts clean.
#
# Processes killed:
#   • dnscrypt-proxy — DNS engine
#   • dnscrypt-webui — WebUI
#   • Watchdog — via PID files in known locations
#
# KILLED_COUNT is accumulated so [25] can warn the user that a
# reboot is required to restore DNS.
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
ui_print "- 🔥 Firewall rules cleaned"
echo "Firewall cleanup attempted (Custom Chain + Legacy)" >> "$INSTALL_LOG"

# ============================================================
# [8c] Begin transactional upgrade
# ============================================================
# A transaction directory is created BEFORE any backup or
# installation step. It survives a failed install and allows
# rollback on the next run.
#
# Layout:
#   $PERSISTENT_BACKUP/txn-<timestamp>-<pid>/
#   ├── .state          ("START" | "COMMIT" | "ROLLBACK")
#   ├── .pid            (installer PID)
#   └── <user files>    (snapshot for rollback)
#
# TXN_ID and BACKUP_DIR_NAME share the same timestamp but use
# DIFFERENT final paths, preventing a collision when both try
# to `mv` to the same destination.
BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR_NAME="${BACKUP_TIMESTAMP}-${MODULE_VERSION}-$$"
BACKUP_DIR="$PERSISTENT_BACKUP/$BACKUP_DIR_NAME"

TXN_ID="txn-${BACKUP_TIMESTAMP}-$$"
TXN_DIR="$PERSISTENT_BACKUP/$TXN_ID"
TXN_ACTIVE=0

mkdir -p "$PERSISTENT_BACKUP" 2>/dev/null
chmod 0700 "$PERSISTENT_BACKUP" 2>/dev/null || true

# begin_transaction — creates the transaction directory and
# writes its initial state (START) and PID.
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

# commit_transaction — marks the transaction as committed.
#
# A failed COMMIT write leaves TXN_ACTIVE=1, so [23] does not
# delete the transaction directory.
commit_transaction() {
    if [ "$TXN_ACTIVE" != "1" ] || [ ! -f "$TXN_DIR/.state" ]; then
        TXN_ACTIVE=0
        return 0
    fi

    if ! echo "COMMIT" > "$TXN_DIR/.state" 2>/dev/null; then
        echo "  ⚠️ commit_transaction: cannot write COMMIT state" >> "$INSTALL_LOG"
        return 1
    fi

    TXN_ACTIVE=0
    return 0
}

# rollback_transaction — restores user files from the
# transaction snapshot and marks the transaction as rolled
# back.
#
# The file copies happen FIRST, then the state file is written.
# A failed ROLLBACK write is logged but does not abort — the
# state file remaining at START is handled correctly by
# uninstall.sh (rename to orphan-txn-*, preserve).
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

    if ! echo "ROLLBACK" > "$TXN_DIR/.state" 2>/dev/null; then
        echo "  ⚠️ rollback_transaction: cannot write ROLLBACK state" >> "$INSTALL_LOG"
    fi

    ui_print "  → Rolled back $_rolled file(s)"
    TXN_ACTIVE=0
}

if [ -n "$FOUND_SOURCE" ] && [ "$RECOVERY_MODE" != "1" ]; then
    if begin_transaction; then
        ui_print "- 📦 Transaction started: $TXN_ID"
        echo "Transaction: $TXN_ID" >> "$INSTALL_LOG"
    else
        ui_print "  ⚠️ Failed to create transaction dir — continuing without rollback"
        TXN_ACTIVE=0
    fi
fi

# ============================================================
# [8d] Persistent backup + integrity verification
# ============================================================
# Snapshots the found source into:
#   1. The transaction directory (for rollback)
#   2. $PERSISTENT_BACKUP/<timestamp>-<version>-<pid>/
#   3. $PERSISTENT_BACKUP/current/ (live snapshot)
#
# Then verifies integrity via SHA256.
#
# When RECOVERY_MODE=1: we do NOT create a new backup from
# FOUND_SOURCE — the user's data was corrupted, and FOUND_SOURCE
# points to that corrupted data.
#
# `current/` is updated via an atomic tmp-dir + mv sequence:
# a reader sees either the OLD current/ (complete) or the NEW
# current/ (complete) — never a partial mix.

# json_escape — escape backslash, double-quote, and C0 control
# characters that would break the manifest JSON.
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\000-\010\013\014\016-\037'
}

# write_manifest <target_dir> <source> <count>
write_manifest() {
    local target_dir="$1"
    local source="$2"
    local count="$3"
    local manifest="$target_dir/.manifest.json"

    local version_escaped
    version_escaped=$(json_escape "$MODULE_VERSION")
    local timestamp_escaped
    timestamp_escaped=$(json_escape "$BACKUP_TIMESTAMP")
    local src_escaped
    src_escaped=$(json_escape "$source")
    local root_escaped
    root_escaped=$(json_escape "$ROOT_SOLUTION")

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
  "version": "$version_escaped",
  "timestamp": "$timestamp_escaped",
  "source": "$src_escaped",
  "root_solution": "$root_escaped",
  "files_count": $count,
  "files": [$files_json]
}
EOF

    chmod 0600 "$manifest" 2>/dev/null
    return 0
}

# verify_backup_integrity <dir>
#
# Validates every user file in the given directory:
#   • Non-empty
#   • Size < 10 MB
#   • SHA256 matches the manifest (when jq/awk/sha256 available)
#
# Returns 0 if clean, 1 if any warnings were detected.
#
# If the manifest is missing or sha256sum is unavailable, the
# function degrades to a size-only check — those two facilities
# are OPTIONAL on Android builds without GNU coreutils.
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

# create_persistent_backup — three outputs, in order:
#   1. The permanent snapshot directory ($BACKUP_DIR).
#   2. A .manifest.json inside it (via write_manifest).
#   3. An atomic update of $PERSISTENT_BACKUP/current/.
#
# Returns 1 when 0 files were copied — the caller then does
# NOT set PERSISTENT_BACKUP_OK.
create_persistent_backup() {
    local source="$1"
    local target_dir="$BACKUP_DIR"

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

    # Bail out on an empty snapshot.
    if [ "$count" -eq 0 ]; then
        echo "  ❌ create_persistent_backup: 0 files copied from $source" >> "$INSTALL_LOG"
        rm -rf "$target_dir" 2>/dev/null
        return 1
    fi

    write_manifest "$target_dir" "$source" "$count"

    # ----------------------------------------------------------
    # Atomic update of current/:
    #   1. Populate .current.tmp.$$ from the new snapshot.
    #   2. Rename current/ to .current.old.$$ (if it exists).
    #   3. Rename .current.tmp.$$ to current/.
    #   4. Remove .current.old.$$ on success.
    #   5. On step-3 failure, restore .current.old.$$ back.
    # ----------------------------------------------------------
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
        ui_print "- 💾 Persistent backup: $PERSISTENT_BACKUP_DIR"
        echo "Persistent backup created: $PERSISTENT_BACKUP_DIR" >> "$INSTALL_LOG"
        PERSISTENT_BACKUP_OK=1
    else
        ui_print "  ⚠️ Failed to create persistent backup (source may be empty or disk full)"
        echo "Persistent backup FAILED (returned non-zero)" >> "$INSTALL_LOG"
    fi
fi

# --- Verify integrity (with SHA256 comparison) ---
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
# SKIPUNZIP=1 was set in [1], so Magisk does NOT extract
# anything on its own — the entire extraction is controlled by
# this single `unzip` invocation.
#
# `install_app.sh` (CSH-22 fix) is part of this list. Before
# v1.5.0, the file was packaged but not extracted, so
# getInstallScript() in main.go resolved a non-existent path.
#
# `boot-mini.sh` is required since v1.5.0 Phase 0 — functions.sh
# sources it at load time.
#
# On failure, the transaction is rolled back and the install
# aborts — the user is not left with a partially-installed
# module.
ui_print ""
ui_print "- 📂 Extracting module files..."

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
    'boot-mini.sh' \
    'watchdog.sh' \
    'install_app.sh' \
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
# [9b] Move HTML/JSON/JS/SVG/PNG/ICO files to web/
# ============================================================
# The ZIP stores web assets at the ZIP root; the final module
# layout places them under $MODPATH/web/. This section performs
# the move after [9] extraction has placed them in $MODPATH.
#
# The move is idempotent: a file already in web/ from a
# previous install is simply not found at the root.
#
# A failed `mv` is logged explicitly. Without the check, a
# silent failure would surface later as "Missing critical files:
# web/index.html" in [10] — harder to diagnose than the actual
# cause.
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
        if mv -f "$MODPATH/$f" "$MODPATH/web/" 2>/dev/null; then
            echo "  Moved $f to web/" >> "$INSTALL_LOG"
        else
            echo "  ⚠️ Failed to move $f to web/" >> "$INSTALL_LOG"
        fi
    fi
done

ui_print "  ✅ Files extracted"

# ============================================================
# [9b2] Post-extraction recovery restoration
# ============================================================
# In recovery mode ([8a]), the 5 user config files were
# restored into $BIN_DIR and ALSO snapshotted into
# $RECOVERY_SNAPSHOT_DIR. The snapshot exists because [9]'s
# unzip overwrites webui.conf and dnscrypt-proxy.toml with the
# ZIP's default copies, losing the recovery data.
#
# This section re-applies the snapshot AFTER the unzip and the
# file moves, and BEFORE [9c] (which is skipped in recovery
# mode anyway).
#
# The snapshot directory is removed ONLY when the number of
# files actually re-applied equals the number that was
# snapshotted. On a partial re-application, the snapshot is
# PRESERVED so the user can complete the recovery manually.
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
# [9c] Restore user settings with verification
# ============================================================
# Copies the 5 user config files from the discovered source
# (FOUND_SOURCE, [8]) into the module's proxy/ directory.
# This is the NORMAL upgrade path — it does not run in
# recovery mode, because [8a] + [9b2] already restored the
# files.
#
# Critical failure: any failure on `webui.conf` or
# `dnscrypt-proxy.toml` triggers an immediate rollback and
# abort.
#
# Non-critical failures accumulate in RESTORE_FAILED_COUNT;
# two or more trigger a rollback.
#
# Blocklist reuse (nested block):
#   When FOUND_SOURCE has restored the 5 config files, we ALSO
#   try to reuse the blocklist from any available source.
#   Rationale: FOUND_SOURCE may be `backup/current/`, which
#   deliberately excludes blocklists (they are
#   re-downloadable). Without this reuse, [17] would create
#   empty placeholder files and force the user to press
#   "Apply" in the WebUI on every upgrade.
RESTORED_COUNT=0
RESTORE_FAILED_COUNT=0
CRITICAL_RESTORE_FAILED=0

if [ "$RECOVERY_MODE" = "1" ]; then
    ui_print ""
    ui_print "- Skipping restore (recovery mode already restored)"
    echo "Skipped [9c] restore — recovery mode" >> "$INSTALL_LOG"
elif [ -n "$FOUND_SOURCE" ]; then
    ui_print ""
    ui_print "- 🔄 Restoring user configuration..."

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

        # Blocklist reuse: search all candidates.
        for _bl in blocklist.raw blocklist.txt; do
            _dst="$MODPATH/proxy/$_bl"
            [ -f "$_dst" ] && [ -s "$_dst" ] && continue

            _src=""
            if [ -f "$FOUND_SOURCE/$_bl" ] && [ -s "$FOUND_SOURCE/$_bl" ]; then
                _src="$FOUND_SOURCE/$_bl"
            else
                for _bm in /data/adb/modules/*/; do
                    [ -f "$_bm/proxy/$_bl" ] && [ -s "$_bm/proxy/$_bl" ] || continue
                    _src="$_bm/proxy/$_bl"
                    break
                done
            fi

            if [ -n "$_src" ]; then
                if copy_with_context "$_src" "$_dst" 2>/dev/null; then
                    ui_print "  ✅ Reused $_bl ($(wc -c < "$_src") bytes)"
                    echo "Reused $_bl from $_src" >> "$INSTALL_LOG"
                fi
            fi
        done
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
# [9d] Config migrations
# ============================================================
# Migrates the user's config files from the source version to
# the current version. The source version is read from the
# manifest (preferred) or from module.prop (fallback).
#
# Version-specific migrations:
#
#   v1.0.0 → v1.2.0:
#     Adds MEMORY_LIMIT_HINT=auto to webui.conf if missing.
#
#   v1.1.0..v1.5.0 → v1.5.0:
#     No changes needed. Every config field added between
#     v1.1.0 and v1.5.0 is OPTIONAL.
#
#   unknown / empty source version:
#     The config is used as-is.
#
# The migration is SKIPPED in recovery mode.
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
            {
                echo ""
                echo "# v1.2.0 addition"
                echo "MEMORY_LIMIT_HINT=auto"
            } >> "$BIN_DIR/webui.conf"
            echo "  Migrated: added MEMORY_LIMIT_HINT to webui.conf" >> "$INSTALL_LOG"
        fi
    fi
}

migrate_config() {
    case "$SOURCE_VERSION" in
        "v1.0.0")
            ui_print "- 🔄 Migration: $SOURCE_VERSION → $MODULE_VERSION"
            migrate_v1_0_0_to_v1_2_0
            ;;
        "v1.1.0"|"v1.2.0"|"v1.3.0"|"v1.4.0"|"v1.5.0")
            ui_print "- 🔄 Migration: no changes needed ($SOURCE_VERSION → $MODULE_VERSION)"
            ;;
        "")
            ;;
        *)
            ui_print "- 🔄 Migration: unknown source ($SOURCE_VERSION) — using as-is"
            ;;
    esac
}

if [ -n "$SOURCE_VERSION" ] && [ "$RECOVERY_MODE" != "1" ]; then
    migrate_config
fi

# ============================================================
# [10] Verify critical files
# ============================================================
# install_app.sh is a REQUIRED file:
#   • Drives the one-tap companion app install.
#   • Staged at the ZIP root by the packaging script.
#   • A properly built ZIP always contains it.
#
# boot-mini.sh is REQUIRED since v1.5.0 Phase 0:
#   • Provides the Layer-0 primitives that functions.sh
#     sources at load time.
#
# On any missing file: the transaction is rolled back and the
# install aborts with the exact list of missing paths.
MISSING=""
[ ! -f "$MODPATH/module.prop" ]         && MISSING="$MISSING module.prop"
[ ! -f "$MODPATH/service.sh" ]          && MISSING="$MISSING service.sh"
[ ! -f "$MODPATH/functions.sh" ]        && MISSING="$MISSING functions.sh"
[ ! -f "$MODPATH/boot-mini.sh" ]        && MISSING="$MISSING boot-mini.sh"
[ ! -f "$MODPATH/watchdog.sh" ]         && MISSING="$MISSING watchdog.sh"
[ ! -f "$MODPATH/post-fs-data.sh" ]     && MISSING="$MISSING post-fs-data.sh"
[ ! -f "$MODPATH/action.sh" ]           && MISSING="$MISSING action.sh"
[ ! -f "$MODPATH/status.sh" ]           && MISSING="$MISSING status.sh"
[ ! -f "$MODPATH/uninstall.sh" ]        && MISSING="$MISSING uninstall.sh"
[ ! -f "$MODPATH/install_app.sh" ]      && MISSING="$MISSING install_app.sh"
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
# These files are OPTIONAL: the PWA install button falls back
# to the SVG icons when the PNG variants are absent. A missing
# PNG is therefore a cosmetic warning, not an install failure.
#
# offline.html is listed here too: the Service Worker degrades
# gracefully when the file is absent.
PNG_MISSING=""
[ ! -f "$MODPATH/web/icon-192.png" ]         && PNG_MISSING="$PNG_MISSING icon-192.png"
[ ! -f "$MODPATH/web/icon-512.png" ]         && PNG_MISSING="$PNG_MISSING icon-512.png"
[ ! -f "$MODPATH/web/apple-touch-icon.png" ] && PNG_MISSING="$PNG_MISSING apple-touch-icon.png"
[ ! -f "$MODPATH/web/favicon.ico" ]          && PNG_MISSING="$PNG_MISSING favicon.ico"
[ ! -f "$MODPATH/web/offline.html" ]         && PNG_MISSING="$PNG_MISSING offline.html"

if [ -n "$PNG_MISSING" ]; then
    ui_print "  ⚠️ Some asset files missing:$PNG_MISSING"
    ui_print "     (PWA may work with SVG fallback)"
    echo "⚠️ Asset files missing:$PNG_MISSING" >> "$INSTALL_LOG"
else
    ui_print "  ✅ Asset files (PNG/ICO/offline) validated"
    echo "✅ All asset files present" >> "$INSTALL_LOG"
fi

# ============================================================
# [10c] Mirror companion APK to /sdcard/
# ============================================================
# The companion APK (web/app-debug.apk) and its .sha256 sidecar
# are mirrored to /sdcard/dnscrypt-webui-backup/apk/ so that:
#   1. Users WITHOUT root can find the APK via a file manager
#      (/sdcard is world-readable; /data/adb is not).
#   2. The APK survives module uninstall.
#   3. A future reinstall can fall back to the mirrored copy.
#
# Best-effort: if /sdcard is not mounted or not writable, a
# warning is logged and the install continues.
#
# The mirror directory is EXCLUDED from rotation by both an
# explicit name skip AND the manifest check (no .manifest.json).
APK_MIRROR_DIR="$PERSISTENT_BACKUP/apk"
APK_SRC="$MODPATH/web/app-debug.apk"
SHA_SRC="$MODPATH/web/app-debug.apk.sha256"

_apk_mirrored=0
_sha_mirrored=0

if [ -f "$APK_SRC" ] && [ -s "$APK_SRC" ]; then
    if mkdir -p "$APK_MIRROR_DIR" 2>/dev/null; then
        if cp -f "$APK_SRC" "$APK_MIRROR_DIR/app-debug.apk" 2>/dev/null; then
            chmod 0644 "$APK_MIRROR_DIR/app-debug.apk" 2>/dev/null
            _apk_mirrored=1
        fi

        if [ -f "$SHA_SRC" ] && [ -s "$SHA_SRC" ]; then
            if cp -f "$SHA_SRC" "$APK_MIRROR_DIR/app-debug.apk.sha256" 2>/dev/null; then
                chmod 0644 "$APK_MIRROR_DIR/app-debug.apk.sha256" 2>/dev/null
                _sha_mirrored=1
            fi
        fi
    fi
fi

if [ "$_apk_mirrored" = "1" ]; then
    ui_print "  ✅ Companion APK mirrored: $APK_MIRROR_DIR"
    echo "APK mirror: $APK_MIRROR_DIR (sha=$_sha_mirrored)" >> "$INSTALL_LOG"
else
    ui_print "  ⚠️  Companion APK mirror skipped (best-effort)"
    echo "APK mirror: skipped (source missing or /sdcard unwritable)" >> "$INSTALL_LOG"
fi

# ============================================================
# [11] Select binaries for architecture
# ============================================================
# The module ZIP ships per-architecture binaries in $BIN_DIR/.
# This section picks the right pair for the device's ABI,
# copies each to its canonical name, and removes the
# per-architecture copies.
#
# ABI aliasing:
#   arm64-v8a / aarch64*  → arm64 binaries
#   armeabi-v7a / arm*    → arm binaries
#   x86_64*               → x86_64 (amd64) binaries
#   i686 / x86*           → x86 (386) binaries
#
# The `rm -f "$BIN_DIR"/dnscrypt-proxy-*` pattern deliberately
# requires a trailing dash, so `dnscrypt-proxy.toml` and the
# final binaries themselves are NOT matched.
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

ui_print "- 🎯 Target binaries: $DNS_BIN + $WEB_BIN"

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

# Remove per-architecture copies; keep only the canonical names.
rm -f "$BIN_DIR"/dnscrypt-proxy-* "$BIN_DIR"/dnscrypt-webui-* 2>/dev/null
rm -f "$BIN_DIR/main.go" "$BIN_DIR/build.sh" 2>/dev/null

ui_print "  ✅ Binaries installed"
ui_print ""

# ============================================================
# [12] Create secure run/ directory
# ============================================================
# The run/ directory is created with mode 0700 and owned by
# root. It holds all runtime state:
#   • dnscrypt.pid      — PID file of the DNS engine
#   • webui.pid         — PID file of the WebUI
#   • watchdog.pid      — PID file of the watchdog
#   • dnscrypt.status   — user intent: "ON" / "OFF"
#   • .watchdog_token   — 64-hex CSRF token shared with main.go
#   • .bootstrap_cache  — cached bootstrap resolver list
#   • update_progress.txt — progress file
#
# Migration: PID files from the legacy /data/local/tmp location
# are dropped (they are transient), but `dnscrypt.status` is
# PRESERVED if it exists — it carries the user's ON/OFF intent
# across the upgrade. If the copy fails (e.g. disk full,
# permission error), the source is kept so the intent is not
# lost.
RUN_DIR="$BIN_DIR/run"

ui_print "- 🔧 Creating secure run/ directory..."

mkdir -p "$RUN_DIR" 2>/dev/null

if [ ! -d "$RUN_DIR" ]; then
    echo "❌ Failed to create run/ directory" >> "$INSTALL_LOG"
    rollback_transaction
    abort "❌ Failed to create $RUN_DIR"
fi

chmod 0700 "$RUN_DIR" 2>/dev/null
chown 0:0 "$RUN_DIR" 2>/dev/null

# --- Migrate status file only from /data/local/tmp ---
# The source is deleted ONLY when the copy into $RUN_DIR
# actually succeeded (or when a fresh copy already exists at
# the destination). A failed copy leaves the source intact.
_STATUS_PRESERVED=0
for f in dnscrypt.pid webui.pid watchdog.pid dnscrypt.status; do
    OLD_FILE="/data/local/tmp/$f"
    NEW_FILE="$RUN_DIR/$f"
    if [ -f "$OLD_FILE" ] && [ ! -f "$NEW_FILE" ]; then
        if [ "$f" = "dnscrypt.status" ]; then
            if cp -f "$OLD_FILE" "$NEW_FILE" 2>/dev/null; then
                echo "  Migrated $f to $RUN_DIR" >> "$INSTALL_LOG"
            else
                echo "  ⚠️ Failed to migrate $f — keeping /tmp copy" >> "$INSTALL_LOG"
                _STATUS_PRESERVED=1
            fi
        fi
    fi
done

rm -f /data/local/tmp/dnscrypt.pid 2>/dev/null
rm -f /data/local/tmp/webui.pid 2>/dev/null
rm -f /data/local/tmp/watchdog.pid 2>/dev/null
if [ "$_STATUS_PRESERVED" = "0" ]; then
    rm -f /data/local/tmp/dnscrypt.status 2>/dev/null
fi

ui_print "  ✅ run/ directory created (0700)"
ui_print "  ✅ Migrated status files"
echo "✅ run/ created at $RUN_DIR" >> "$INSTALL_LOG"
ui_print ""

# ============================================================
# [13] Old modules (runtime detection)
# ============================================================
# Stale module folders are detected at RUNTIME by main.go's
# `checkOldModules()`. This section only logs a hint about
# what kind of install this is:
#
#   • Recovery mode  — the user explicitly triggered recovery.
#   • Upgrade        — a source was found in [8].
#   • Fresh install  — no source found.
#
# The actual disable-other-folders logic lives in [23b], which
# runs AFTER the module's own content is fully installed.
if [ "$RECOVERY_MODE" = "1" ]; then
    ui_print "- Recovery mode: old modules will be detected at runtime"
    echo "Old modules: runtime detection (recovery mode)" >> "$INSTALL_LOG"
elif [ -n "$FOUND_SOURCE" ]; then
    ui_print "- ⬆️  Upgrade detected (source: $FOUND_SOURCE)"
    ui_print "  Old modules will be detected at runtime via WebUI"
    echo "Upgrade detected: source=$FOUND_SOURCE" >> "$INSTALL_LOG"
else
    ui_print "- 🆕 Fresh installation (no previous data found)"
    echo "Fresh install (no source)" >> "$INSTALL_LOG"
fi

ui_print ""
ui_print "- ⚙️  Creating configuration files..."

# ============================================================
# [14] Port validation — collision-safe
# ============================================================
# Determines the final WebUI and Dashboard ports that will be
# written to webui.conf, applying three rules:
#
#   1. Range check: 1 <= port <= 65535.
#   2. Reserved-port check: port 8080 is rejected.
#   3. Distinctness: PORT must differ from DASHBOARD_PORT.
#
# Existing values are read from a webui.conf that may have
# been restored by [9c]. Invalid existing values fall back to
# the defaults (9090 / 9091) with a warning message.
#
# Leading zeros are stripped before the range check: some
# shells interpret "090" as octal 72 in arithmetic contexts,
# which would pass a bogus port to the socket layer.
validate_port() {
    local port="$1"

    echo "$port" | grep -qE '^[0-9]+$' || return 1

    local clean
    clean=$(printf '%s' "$port" | sed 's/^0*//')
    [ -z "$clean" ] && clean="0"

    [ "$clean" -ge 1 ] || return 1
    [ "$clean" -le 65535 ] || return 1

    if [ "$clean" = "$_MONITORING_UI_PORT" ]; then
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
# [15] Write webui.conf
# ============================================================
# Writes a fresh webui.conf using the values resolved in [14].
# The write is atomic: a `.tmp` file is written first, then
# moved into place. If either step fails, the transaction is
# rolled back and the install aborts.
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
# [16] Port in use check
# ============================================================
# Best-effort informational check whether another process is
# already listening on the WebUI port. The install does NOT
# abort if the port is busy — the user may have another
# process temporarily holding the port, and main.go's own
# startup will detect and log the conflict.
#
# Three detection methods, in order of preference:
#   1. `ss`       — the modern tool.
#   2. `netstat`  — the older tool.
#   3. /proc/net/tcp — the direct kernel view.
#
# The trailing space in ":$hex_port " prevents ":1F90" from
# matching ":1F90A" (a different, longer port whose prefix
# happens to equal ours).
port_in_use=0
if command -v ss >/dev/null 2>&1; then
    ss -tuln 2>/dev/null | grep -q ":$TEMP_PORT " && port_in_use=1
elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln 2>/dev/null | grep -q ":$TEMP_PORT " && port_in_use=1
elif [ -f /proc/net/tcp ]; then
    hex_port=$(printf "%04X" "$TEMP_PORT")
    grep -qi ":$hex_port " /proc/net/tcp 2>/dev/null && port_in_use=1
fi

if [ $port_in_use -eq 1 ]; then
    ui_print "  ⚠️ Port $TEMP_PORT is already in use by another app"
    echo "⚠️ Port $TEMP_PORT already in use" >> "$INSTALL_LOG"
fi

# ============================================================
# [17] Create default config files (only if missing)
# ============================================================
# After [9c]'s restore attempt, the module's proxy/ directory
# should contain the 5 user config files. Any file that is
# still missing at this point is created with a safe default.
#
# The `[ ! -f ]` guard makes this section idempotent: an
# upgrade that restored the file in [9c] leaves it untouched.
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
# Ensures the `[monitoring_ui]` section of dnscrypt-proxy.toml
# contains a non-default username/password pair.
#
# Trigger for regeneration:
#   • Either credential is missing, OR
#   • The credentials are the well-known default `admin`/`admin`.
#
# Preservation:
#   If both credentials exist AND are not `admin`/`admin`, the
#   section is left untouched. The credentials file at
#   /data/local/tmp/dnscrypt_credentials.txt is regenerated
#   from the existing values so the user always has a fresh
#   copy.
#
# Verification:
#   After writing the new credentials, both are read back and
#   compared. Any mismatch aborts the install and rolls back
#   the transaction — a silent credential-replacement failure
#   would leave the user locked out of their own WebUI.
#
# Fallback warning:
#   When /dev/urandom is unavailable (extremely rare on Android),
#   the fallback credentials are derived from the epoch time and
#   are therefore predictable. A warning is shown to the user
#   and logged so they know to change the password immediately.
ui_print ""
ui_print "- 🔐 Generating secure credentials..."

TOML_FILE="$BIN_DIR/dnscrypt-proxy.toml"
CRED_FILE="/data/local/tmp/dnscrypt_credentials.txt"

# parse_toml_value — extract a value from a TOML right-hand side.
#
# Quoted values (single or double) are returned verbatim between
# the delimiters — a '#' inside the quotes is NOT a comment.
# This is the TOML spec behavior: comments are only recognized
# outside of strings.
#
# Unquoted values have their inline " #" comment stripped and
# surrounding whitespace trimmed.
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

# read_toml_credentials — extract `username` and `password`
# from the `[monitoring_ui]` section of $TOML_FILE.
#
# Output: two lines on stdout — username, then password. Both
# are empty strings if the file, section, or fields are
# missing.
#
# The parser is section-restricted: any `username`/`password`
# pair in any OTHER section is deliberately ignored.
#
# NOTE: this parser is intentionally duplicated in three files
# (functions.sh, customize.sh, install_app.sh). Each file must
# be independently sourceable at different stages of the module
# lifecycle, so the duplication is deliberate. Any behavioral
# change MUST be applied to all three.
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
        # Username: 8 alphanumeric chars from /dev/urandom, or
        # "admin_" + last 8 chars of the current epoch.
        NEW_USER=""
        if [ -r /dev/urandom ]; then
            NEW_USER="admin_$(tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 8)"
        fi
        if [ -z "$NEW_USER" ] || [ "$NEW_USER" = "admin_" ] || [ "${#NEW_USER}" -lt 8 ]; then
            NEW_USER="admin_$(date +%s | tail -c 9)"
            ui_print "  ⚠️ /dev/urandom unavailable — using fallback username"
            echo "⚠️ Fallback username generated (predictable — change immediately)" >> "$INSTALL_LOG"
        fi

        # Password: 24 alphanumeric chars from /dev/urandom, or
        # "Auto_<epoch>_<hash prefix>".
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
            ui_print "  ⚠️ /dev/urandom unavailable — using fallback password"
            echo "⚠️ Fallback password generated (predictable — change immediately)" >> "$INSTALL_LOG"
        fi

        cp -f "$TOML_FILE" "$TOML_FILE.bak" 2>/dev/null

        sed -i "s|^[[:space:]]*username[[:space:]]*=[[:space:]]*['\"].*['\"]|  username = '$NEW_USER'|" "$TOML_FILE"
        sed -i "s|^[[:space:]]*password[[:space:]]*=[[:space:]]*['\"].*['\"]|  password = '$NEW_PASS'|" "$TOML_FILE"

        # Verification — read both fields back and compare. Any
        # mismatch is fatal.
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

        # Write the credentials file (atomic).
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
        # Credentials already exist and are not the default.
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
# Applies the module's canonical permission set:
#   • All files under $MODPATH: 0755 dirs / 0644 files
#   • The two binaries: 0755.
#   • All shell scripts at the module root: 0755.
#   • All web assets under $MODPATH/web: 0644.
#   • webui.conf and dnscrypt-proxy.toml: 0600.
#   • run/: 0700, owned by root:root.
ui_print "- 🔒 Setting permissions..."

set_perm_recursive "$MODPATH" 0 0 0755 0644 2>/dev/null || true

chmod 0755 "$BIN_DIR/dnscrypt-proxy" 2>/dev/null
chmod 0755 "$BIN_DIR/dnscrypt-webui" 2>/dev/null

for s in service.sh post-fs-data.sh action.sh status.sh uninstall.sh functions.sh boot-mini.sh watchdog.sh install_app.sh; do
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
# [19b] Watchdog token
# ============================================================
# Pre-generate the watchdog token that main.go and watchdog.sh
# share. Writing it here means the token is available even
# before the first WebUI startup.
#
# The token is 64 hex chars (32 bytes / 256 bits). Written
# with the standard "tmp + mv" atomic pattern. If the write
# fails, main.go will regenerate the token on first startup.
#
# File:   $RUN_DIR/.watchdog_token (mode 0600)
# Header: X-Watchdog-Token (constant-time compared by main.go)
WATCHDOG_TOKEN_FILE="$RUN_DIR/.watchdog_token"
TOKEN=""

if [ -r /dev/urandom ]; then
    TOKEN=$(tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 64)
fi

if [ -z "$TOKEN" ] || [ "${#TOKEN}" -lt 32 ]; then
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
# A single-line marker that identifies this module folder as
# belonging to DNSCrypt Smart Filter. Read by:
#   • main.go:checkOldModules()  — to skip the current install.
#   • main.go:removeModule()     — to refuse deletion of a
#                                   folder without the
#                                   fingerprint.
#   • customize.sh [8] discovery — as a secondary signal.
#
# Format: `<id>-<version>`.
printf "dnscrypt-proxy-webui-%s\n" "$MODULE_VERSION" > "$MODPATH/.module.fingerprint"

# ============================================================
# [21] Compute expected memory limit
# ============================================================
# Displays the memory limit that main.go WILL apply at runtime
# based on the selected profile. This is a HINT only — main.go
# is the authority (via debug.SetMemoryLimit).
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
# [22] Log upgrade history
# ============================================================
# Records every successful install in a machine-readable log
# under the persistent backup directory.
#
# Two formats:
#   • .upgrade_history.json — used when `jq` is available.
#   • .upgrade_history.txt  — fallback, one line per install.
#
# The jq temp file is created INSIDE $PERSISTENT_BACKUP so the
# final `mv` is on the same filesystem. On Android, `mktemp`
# may return a path under /data while the backup lives on
# /sdcard (FUSE) — a cross-device mv would fail with EXDEV.
log_upgrade() {
    local history="$PERSISTENT_BACKUP/.upgrade_history.json"
    local files_count="$FOUND_FILE_COUNT"

    if ! echo "$files_count" | grep -qE '^[0-9]+$'; then
        files_count=0
    fi

    if [ "$HAS_JQ" = "1" ]; then
        [ -f "$history" ] || echo '{"upgrades":[]}' > "$history"

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
# Uses the full BACKUP_DIR_NAME (with PID suffix). Only updated
# when PERSISTENT_BACKUP_OK=1, which means ">= 1 file was
# actually written".
if [ "$PERSISTENT_BACKUP_OK" = "1" ]; then
    echo "$BACKUP_DIR_NAME" > "$PERSISTENT_BACKUP/.last_stable" 2>/dev/null
fi

# --- Log the upgrade (only when meaningful) ---
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
- `apk/`                          — mirrored companion APK + .sha256
- `README.md`                     — this file

## Retention

Rotation keeps the **21 newest snapshots by mtime**, with two
additional protected targets that are never pruned:

- The `.last_stable` target (recovery pointer).
- The newest install snapshot (name matching `-v<digit>`).

Older snapshots are pruned automatically. The `current/` directory
and any `txn-*` / `orphan-txn-*` transaction directories are exempt
from rotation. The `apk/` mirror is also exempt — it lacks a
`.manifest.json`, so the manifest-based snapshot detection
(ROT-MANIFEST) never counts it as a snapshot.

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

See docs/REFERENCE.md §4 for the full reference.
See docs/GUIDE.md §8 for recovery procedures.
EOF
    chmod 0644 "$PERSISTENT_BACKUP/README.md" 2>/dev/null
fi

# ============================================================
# [22b] Rotate backups
# ============================================================
# Mirrors the canonical functions.sh:rotate_backups using the
# SAME rotation semantics:
#
#   • ROT-MANIFEST — a directory is treated as a snapshot iff
#     it contains a `.manifest.json` file.
#
#   • ROT-MTIME — candidates are sorted by mtime (numeric,
#     descending, `LC_ALL=C sort -rn -k1,1`), not by directory
#     name.
#
#   • ROT-PROTECT — two additional targets are preserved on top
#     of the 21-newest window:
#       • the `.last_stable` target (recovery pointer);
#       • the newest install snapshot (name matching `-v<digit>`).
#
# Canonical status: THIS is a mirrored copy. The reference
# implementation lives in `functions.sh:rotate_backups`. Any
# change there MUST be applied here as well — the installer
# runs before the module is extracted and cannot source that
# file.
#
# The `apk/` mirror subfolder is preserved by TWO independent
# mechanisms:
#   1. The `case` statement explicitly skips `apk/` by name.
#   2. The ROT-MANIFEST check requires a `.manifest.json` inside
#      the candidate directory — `apk/` has none.
rotate_backups() {
    local keep="${1:-21}"

    [ -d "$PERSISTENT_BACKUP" ] || return 0
    [ -r "$PERSISTENT_BACKUP" ] || {
        echo "  ⚠️ rotate_backups: $PERSISTENT_BACKUP is not readable" >> "$INSTALL_LOG"
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
                current|txn-*|orphan-txn-*|.restore_snap.*|apk) continue ;;
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
        echo "Rotation: $total snapshot(s) — within limit ($keep)" >> "$INSTALL_LOG"
        return 0
    fi

    local to_remove=$((total - keep))
    echo "Rotation: removing $to_remove old snapshot(s) (keeping $keep)" >> "$INSTALL_LOG"

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
            echo "  Preserved (last_stable): $_name" >> "$INSTALL_LOG"
            continue
        fi
        if [ "$_name" = "$_newest_install" ]; then
            echo "  Preserved (newest install): $_name" >> "$INSTALL_LOG"
            continue
        fi
        if rm -rf "${PERSISTENT_BACKUP:?}/${_name:?}" 2>/dev/null; then
            echo "  Removed: $_name" >> "$INSTALL_LOG"
        fi
    done <<EOF
$(printf '%s\n' "$_list" | tail -n "$to_remove")
EOF

    return 0
}

if [ "$PERSISTENT_BACKUP_OK" = "1" ]; then
    ui_print "- 🗂️  Rotating old backups (keep: 21)"
    rotate_backups 21
    ui_print "  ✅ Rotation complete"
fi

# ============================================================
# [23] Commit the transaction + cleanup TXN_DIR
# ============================================================
# Two cleanup paths:
#
#   1. TXN_ACTIVE=1 → the install reached this point normally.
#      `commit_transaction` writes COMMIT, then clears the
#      flag. On success, remove the transaction directory.
#
#   2. TXN_ACTIVE=0 → the install either never created a
#      transaction or already committed it.
#
# If `commit_transaction` fails to write the COMMIT state file,
# it returns 1 and leaves TXN_ACTIVE=1. The [23] cleanup block
# does NOT run, so the transaction directory survives with its
# state file still saying START. The next uninstall.sh call will
# rename it to `orphan-txn-*` and preserve it.
if [ "$TXN_ACTIVE" = "1" ]; then
    if commit_transaction; then
        ui_print "- ✅ Transaction committed"
    else
        ui_print "  ⚠️ Transaction commit failed (non-critical)"
    fi
fi

if [ "$TXN_ACTIVE" = "0" ] && [ -d "$TXN_DIR" ]; then
    rm -rf "$TXN_DIR" 2>/dev/null
fi

# cleanup_old_transactions removes leftover COMMIT'd txn
# directories from previous installs that failed between the
# commit write and their own cleanup step.
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
# [23b] Disable stale module folders
# ============================================================
# Mark every other folder with id=dnscrypt-proxy-webui (not
# $MODPATH, not $FOUND_SOURCE's parent) as disabled by touching
# a `disable` file. Magisk/KernelSU/APatch honor it.
#
# Why disable instead of rm -rf:
#   * Reversible: `rm disable` re-enables.
#   * Non-destructive: data is preserved.
#   * Safe: no recursive deletion.
#   * Discovery still sees them as fallback sources.
#
# Two skip rules:
#
#   1. Skip folders whose BASENAME matches $MODPATH's basename.
#      Rationale: Magisk replaces same-named module folders at
#      boot, so a folder with the same basename but a different
#      root is the update-staging directory for THIS install.
#
#   2. Skip folders whose parsed version is >= our version.
#      Rationale: a same-id folder with a higher or equal
#      version is either a concurrent install in progress or a
#      partially-updated tree. Disabling it could break the
#      other install.
#
# The version comparison uses the same score formula as [8]'s
# discovery: major*10000 + minor*100 + patch.
if [ -n "$FOUND_SOURCE" ]; then
    _src_dir=$(dirname "$FOUND_SOURCE")
    _target_basename=$(basename "$MODPATH")
    _new_ver="${MODULE_VERSION#v}"
    _new_vmaj=$(echo "$_new_ver" | cut -d. -f1); case "$_new_vmaj" in ""|*[!0-9]*) _new_vmaj=0 ;; esac
    _new_vmin=$(echo "$_new_ver" | cut -d. -f2); case "$_new_vmin" in ""|*[!0-9]*) _new_vmin=0 ;; esac
    _new_vpat=$(echo "$_new_ver" | cut -d. -f3); case "$_new_vpat" in ""|*[!0-9]*) _new_vpat=0 ;; esac
    _new_score=$((_new_vmaj * 10000 + _new_vmin * 100 + _new_vpat))

    _disabled_count=0
    for _root in /data/adb/modules /data/adb/modules_update /data/adb/ksu/modules /data/adb/ap/modules; do
        [ -d "$_root" ] || continue
        for _m in "$_root"/*; do
            [ -d "$_m" ] || continue
            [ "$_m" = "$MODPATH" ] && continue

            _m_name=$(basename "$_m")
            [ "$_m_name" = "$_target_basename" ] && continue

            [ -f "$_m/module.prop" ] || continue
            _mid=$(grep '^id=' "$_m/module.prop" | head -1 | cut -d= -f2-)
            _mid=$(printf "%s" "$_mid" | tr -d "\r ")
            [ "$_mid" = "$MODULE_ID" ] || continue

            _m_ver=$(grep '^version=' "$_m/module.prop" | head -1 | cut -d= -f2-)
            _m_ver=$(printf "%s" "$_m_ver" | tr -d "v\r ")
            _m_vmaj=$(echo "$_m_ver" | cut -d. -f1); case "$_m_vmaj" in ""|*[!0-9]*) _m_vmaj=0 ;; esac
            _m_vmin=$(echo "$_m_ver" | cut -d. -f2); case "$_m_vmin" in ""|*[!0-9]*) _m_vmin=0 ;; esac
            _m_vpat=$(echo "$_m_ver" | cut -d. -f3); case "$_m_vpat" in ""|*[!0-9]*) _m_vpat=0 ;; esac
            _m_score=$((_m_vmaj * 10000 + _m_vmin * 100 + _m_vpat))

            [ "$_m_score" -ge "$_new_score" ] && continue

            if [ ! -f "$_m/disable" ]; then
                if touch "$_m/disable" 2>/dev/null; then
                    ui_print "  🔒 Locked stale: $_m_name (v$_m_ver < v$_new_ver)"
                    _disabled_count=$((_disabled_count + 1))
                fi
            fi
        done
    done
    if [ "$_disabled_count" -gt 0 ]; then
        echo "Disabled $_disabled_count stale" >> "$INSTALL_LOG"
    fi
fi

# ============================================================
# [24] Display final summary
# ============================================================
# A single if/elif/else chain so the summary is printed exactly
# once and reads coherently.
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

if [ "$_apk_mirrored" = "1" ]; then
    ui_print "  📱 Companion APK mirror: $APK_MIRROR_DIR"
    if [ "$_sha_mirrored" = "1" ]; then
        ui_print "     (APK + .sha256 sidecar)"
    else
        ui_print "     (APK only — .sha256 not in module ZIP)"
    fi
fi

ui_print ""
ui_print "  ℹ️  Next steps:"
ui_print "    1. Reboot your device"
ui_print "    2. Open the WebUI and login with the credentials above"
ui_print "    3. Choose a blocklist profile and press Apply"
ui_print "    4. (Optional) Install the companion app:"
ui_print "       WebUI header → Install App → Install locally"
ui_print ""

# ============================================================
# [25] Reboot warning
# ============================================================
# If [8b] killed any running process, the DNS engine is now
# stopped. The kernel may have cached DNS state pointing at the
# old resolver, and Android's network stack may not re-read the
# new configuration until a full reboot.
#
# The warning is only shown when KILLED_COUNT > 0 — i.e. when
# an actual upgrade over a running module occurred.
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