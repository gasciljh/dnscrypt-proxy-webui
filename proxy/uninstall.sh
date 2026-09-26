#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – uninstall.sh
# Version: v1.1.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Magisk / KernelSU / APatch uninstall script.
#
#   Triggered automatically when the module is removed via the
#   Magisk/KernelSU manager, or manually for cleanup.
#
# Responsibilities:
#   • Kill all running processes (dnscrypt-proxy, dnscrypt-webui)
#   • Clean the firewall (Custom Chains + Legacy, via functions.sh
#     if available, otherwise inline)
#   • Reset system DNS settings (private_dns_mode)
#   • Restore the original route_localnet value (do not force 0)
#   • Remove runtime files (run/, PIDs, STATUS_FILE, logs, caches)
#   • Remove module configuration files (webui.conf, .toml, blocklists)
#   • Remove the module fingerprint + disable file
#   • Remove any legacy backup directory from older versions
#
# Options:
#   uninstall.sh          Full cleanup (default)
#   uninstall.sh --help   Show help
#
# v1.1.0 — Backup removed:
#   Previous versions (v1.0.0) created a backup at:
#     /data/local/tmp/dnscrypt_backup_uninstall/
#
#   This behavior is now intentionally removed. Reasons:
#     • The module no longer ships a restore utility.
#     • Backups created false expectations of recoverability.
#     • Users who want to keep settings should do so manually
#       before uninstalling.
#
#   Any existing backup directory from v1.0.0 is cleaned up
#   automatically by this script (see section [16]).
#
# Security:
#   • MODDIR must be inside /data/adb/modules/
#   • MODDIR cannot equal the modules directory itself
#
# Design:
#   • Loads functions.sh if available; otherwise uses inline
#     fallbacks (aggressive_cleanup + firewall cleanup)
#   • The inline cleanup is self-contained (nftables + iptables
#     + ip6tables) and does NOT depend on functions.sh
#
# Non-responsibilities (deliberately NOT done here):
#   • No `debug.SetMemoryLimit` reset — the Go runtime releases
#     memory when the process exits; there is no persistent state.
#   • No firewall rule creation — this is a removal script; only
#     cleanup runs.
#   • No system-wide DNS reconfiguration beyond private_dns_mode
#     reset. Any custom resolvers set by the user are preserved.
#   • No backup creation — settings are removed permanently.
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
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            cat << EOF
DNSCrypt Smart Filter – uninstall.sh

Usage:
  uninstall.sh          Full cleanup (default)
  uninstall.sh --help   Show this help

Note:
  This script is normally invoked automatically by Magisk when the
  module is removed. Do not run it manually except for cleanup.

  No backup is created. All module settings are removed permanently.
  If you want to keep your settings, copy them manually before
  uninstalling:

    cp -a /data/adb/modules/dnscrypt-proxy-webui/proxy/ \\
          /sdcard/dnscrypt-backup/
EOF
            exit 0
            ;;
        *) ;;  # Ignore unknown arguments (Magisk may pass extras)
    esac
done

# ============================================================
# [3] Global paths
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
RUN_DIR="$MODDIR/proxy/run"
BIN_DIR="$MODDIR/proxy"

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
log_msg "Uninstall started (v1.1.0)"
log_msg "MODDIR=$MODDIR"
log_msg "RUN_DIR=$RUN_DIR"

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
# [5b] Read active profile (v1.1.0 — for summary only)
# ============================================================
ACTIVE_PROFILE="unknown"
if [ -f "$BIN_DIR/selected_profile.txt" ]; then
    _ap=$(cat "$BIN_DIR/selected_profile.txt" 2>/dev/null | tr -d '\r\n ')
    case "$_ap" in
        light|normal|pro|proplus|ultimate) ACTIVE_PROFILE="$_ap" ;;
    esac
fi
log_msg "Active profile at uninstall: $ACTIVE_PROFILE"

# ============================================================
# [6] Save route_localnet before changing it
# ============================================================
ORIGINAL_ROUTE_LOCALNET=""
if command -v sysctl >/dev/null 2>&1; then
    ORIGINAL_ROUTE_LOCALNET=$(sysctl -n net.ipv4.conf.all.route_localnet 2>/dev/null | tr -d '\r\n ')
fi

# ============================================================
# [7] Load functions.sh if available
# ============================================================
FUNCTIONS_LOADED=0
if [ -f "$MODDIR/functions.sh" ]; then
    # shellcheck disable=SC1090
    . "$MODDIR/functions.sh" 2>/dev/null
    if command -v aggressive_cleanup >/dev/null 2>&1; then
        FUNCTIONS_LOADED=1
    fi
fi

# ============================================================
# [8] Internal fallback functions
# ============================================================

_inline_kill_all() {
    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-proxy 2>/dev/null
    fi
    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
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
# Mirrors post-fs-data.sh's inline_firewall_cleanup.
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

        # [2c] Legacy cleanup — older versions
        # Old DNAT rules (with comment)
        iptables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null

        # Old DNAT rules (without comment)
        iptables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 --wait 3 2>/dev/null

        # Old RETURN rules (with comment for loopback)
        iptables -t nat -D OUTPUT -d 127.0.0.1 -p udp --dport 53 \
            -j RETURN \
            -m comment --comment "dnscrypt_smart_filter_loopback_127.0.0.1" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -d 127.0.0.1 -p tcp --dport 53 \
            -j RETURN \
            -m comment --comment "dnscrypt_smart_filter_loopback_127.0.0.1" --wait 3 2>/dev/null

        # Old RETURN rules (without comment)
        iptables -t nat -D OUTPUT -d 127.0.0.1 -p udp --dport 53 \
            -j RETURN --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -d 127.0.0.1 -p tcp --dport 53 \
            -j RETURN --wait 3 2>/dev/null

        # Best-effort: try removing RETURN rules for well-known bootstrap IPs
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

        # [3a] Remove jump rules from OUTPUT
        ip6tables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain6" --wait 3 2>/dev/null
        ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain6" --wait 3 2>/dev/null

        # [3b] Flush the chain itself
        ip6tables -t nat -F "$_chain6" --wait 3 2>/dev/null
        ip6tables -t nat -X "$_chain6" --wait 3 2>/dev/null

        # [3c] Legacy cleanup
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
# [9] Cleanup any legacy backup directory (v1.0.0)
# ============================================================
# Previous versions created a backup at:
#   /data/local/tmp/dnscrypt_backup_uninstall/
#
# This version no longer creates backups. Any existing directory
# from a prior v1.0.0 install is removed here to leave a clean
# state after uninstall.
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
# [10] Main cleanup
# ============================================================
log_msg "🧹 Starting cleanup..."

if [ "$FUNCTIONS_LOADED" = "1" ]; then
    log_msg "Using aggressive_cleanup from functions.sh"
    aggressive_cleanup 2>/dev/null
else
    log_msg "Using inline fallback cleanup"
    _inline_kill_all
    _inline_cleanup_firewall
fi

# Belt-and-suspenders: additional cleanup in case the above failed
_inline_kill_all
_inline_cleanup_firewall

log_msg "✅ Process & firewall cleanup completed"

# ============================================================
# [11] Reset DNS settings
# ============================================================
log_msg "🔄 Resetting DNS settings..."

# Wait for the settings service to be ready
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

# --- Restore route_localnet (rather than forcing it to 0) ---
# The original value (usually "0" on stock Android) is captured
# in section [6]. Restoring it avoids clobbering a custom value
# that the user or another module may have set intentionally.
if [ -n "$ORIGINAL_ROUTE_LOCALNET" ] && command -v sysctl >/dev/null 2>&1; then
    if sysctl -w "net.ipv4.conf.all.route_localnet=$ORIGINAL_ROUTE_LOCALNET" >/dev/null 2>&1; then
        log_msg "✅ route_localnet restored to $ORIGINAL_ROUTE_LOCALNET"
    else
        log_msg "⚠️ Failed to restore route_localnet (was $ORIGINAL_ROUTE_LOCALNET)"
    fi
else
    # Fallback: set to 0 (the default)
    if command -v sysctl >/dev/null 2>&1; then
        sysctl -w net.ipv4.conf.all.route_localnet=0 >/dev/null 2>&1
        log_msg "✅ route_localnet set to 0 (default)"
    fi
fi

if command -v ndc >/dev/null 2>&1; then
    ndc resolver flushdefaultif 2>/dev/null
fi

log_msg "✅ DNS reset completed"

# ============================================================
# [12] Cleanup run/ files
# ============================================================
log_msg "🗑️  Removing run/ files..."

RUN_COUNT=0

if [ -d "$RUN_DIR" ]; then
    # rm -rf instead of rmdir (rmdir fails with .write_test or hidden files)
    rm -rf "$RUN_DIR" 2>/dev/null
    if [ ! -d "$RUN_DIR" ]; then
        RUN_COUNT=1
    fi
    log_msg "✅ Removed run/ directory"
else
    log_msg "ℹ️ run/ directory not found (was it ever created?)"
fi

# ============================================================
# [13] Cleanup temporary runtime files (in /data/local/tmp)
# ============================================================
log_msg "🗑️  Removing runtime files from /data/local/tmp..."

RUNTIME_COUNT=0

# --- PID files ---
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

# --- Status + Progress ---
for f in /data/local/tmp/dnscrypt.status \
         /data/local/tmp/update_progress.txt; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

# --- Credentials ---
for f in /data/local/tmp/dnscrypt_credentials.txt \
         /data/local/tmp/.dnscrypt_credentials_shown; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

# --- Log files ---
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

# --- Cleanup rotated logs ---
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

# --- Temp files from apply_custom_rules_only (legacy) ---
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

# --- Bootstrap cache ---
for f in "$RUN_DIR/.bootstrap_cache" \
         "/data/local/tmp/.bootstrap_cache"; do
    if [ -f "$f" ]; then
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

log_msg "✅ Removed $RUNTIME_COUNT runtime files from /data/local/tmp"

# ============================================================
# [14] Cleanup module configuration files
# ============================================================
log_msg "🗑️  Removing module configuration files..."

MODULE_COUNT=0

if [ -d "$BIN_DIR" ]; then
    # --- Core configuration files ---
    for f in selected_profile.txt \
             webui.conf \
             webui.conf.tmp \
             dnscrypt-proxy.toml \
             dnscrypt-proxy.toml.bak; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    # --- Blocklist + variants ---
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

    # --- Allowlist + denylist ---
    for f in allowlist.txt \
             allowlist.txt.tmp_write \
             denylist.txt \
             denylist.txt.tmp_write; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    # --- Auth (legacy) ---
    for f in auth.json .auth_token; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done

    # --- Cached resolvers ---
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
# [15] Remove module fingerprint and disable file
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
# [16] (removed) — backup handling no longer applies
# ============================================================
# In v1.0.0 this section created a backup at:
#   /data/local/tmp/dnscrypt_backup_uninstall/
#
# In v1.1.0 the backup is not created. Any legacy backup
# directory was cleaned up in section [9].
# ============================================================

# ============================================================
# [17] Final summary
# ============================================================
log_msg "════════════════════════════════════════════"
log_msg "✅ Uninstall completed successfully"
log_msg "   • Removed profile: $ACTIVE_PROFILE"
log_msg "   • run/ directory: $([ "$RUN_COUNT" -gt 0 ] && echo "removed" || echo "not present")"
log_msg "   • Runtime files removed: $RUNTIME_COUNT"
log_msg "   • Module config files removed: $MODULE_COUNT"
log_msg "   • Firewall: Custom Chains removed (DNSCRYPT_OUT / DNSCRYPT_OUT6)"
log_msg "   • Legacy rules: cleaned (best-effort)"
log_msg "   • route_localnet: restored to ${ORIGINAL_ROUTE_LOCALNET:-0}"
log_msg "   • Legacy backup dir: $([ "$LEGACY_BACKUP_REMOVED" = "1" ] && echo "removed" || echo "not present")"
log_msg "   • Non-actions: memory limit auto-released on process exit"
log_msg "   • Note: no backup was created (v1.1.0 behavior)"
log_msg "════════════════════════════════════════════"

exit 0