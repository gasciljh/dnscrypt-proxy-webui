#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — uninstall.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Magisk / KernelSU / APatch uninstall script.
#
# Responsibilities:
#   • Kill all module processes (proxy, webui, watchdog).
#   • Clean firewall (IPv4 + IPv6, nftables or iptables).
#   • Reset system DNS (private_dns_mode).
#   • Remove ALL runtime files INCLUDING .watchdog_token.
#   • PRESERVE the persistent backup directory and APK mirror.
#
# Exit codes:
#   0 = success
#   1 = security violation
#   2 = unknown command-line argument
#
# Fallback mode:
#   If functions.sh cannot be sourced, the script uses inline
#   equivalents. The defensive defaults guarantee that
#   ${DNS_ENGINE_PORT} and ${LOOPBACK_IPV4} are defined in both
#   paths, so the firewall cleanup cannot silently skip a
#   non-default port.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path + version
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

MODULE_VERSION="v0.0.0-unknown"
[ -f "$MODDIR/module.prop" ] && \
    MODULE_VERSION=$(grep '^version=' "$MODDIR/module.prop" 2>/dev/null \
        | head -n1 | cut -d= -f2- | tr -d '\r ')

case "${1:-}" in
    --version) echo "$0: $MODULE_VERSION"; exit 0 ;;
esac

# ============================================================
# [2] Parse arguments
# ============================================================
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            cat << 'EOF'
DNSCrypt Smart Filter – uninstall.sh

Usage:
  uninstall.sh          Full cleanup (default)
  uninstall.sh --help   Show this help

Note:
  Normally invoked automatically by Magisk when the module
  is removed. Your persistent backup directory is PRESERVED
  so you can restore settings if you reinstall later:
    /sdcard/dnscrypt-webui-backup/
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
# [3] Security checks
# ============================================================
case "$MODDIR" in
    /data/adb/modules/*) ;;
    *)
        echo "ERROR: MODDIR is not inside /data/adb/modules, aborting" >&2
        exit 1
        ;;
esac

if [ "$MODDIR" = "/data/adb/modules" ]; then
    echo "ERROR: MODDIR equals MODULES_DIR, aborting" >&2
    exit 1
fi

# ============================================================
# [4] Load functions.sh (boot-mini + lib/)
# ============================================================
if [ -f "$MODDIR/functions.sh" ]; then
    # shellcheck disable=SC1090
    . "$MODDIR/functions.sh" 2>/dev/null
fi

FUNCTIONS_LOADED=0
if command -v cleanup_proxy >/dev/null 2>&1 \
   && command -v kill_all_dnscrypt_processes >/dev/null 2>&1; then
    FUNCTIONS_LOADED=1
fi

# Defensive defaults — used by the inline fallback cleanup
DNS_ENGINE_PORT="${DNS_ENGINE_PORT:-5354}"
LOOPBACK_IPV4="${LOOPBACK_IPV4:-127.0.0.1}"
LOOPBACK_IPV6="${LOOPBACK_IPV6:-::1}"

log_msg "Uninstall started ($MODULE_VERSION)"
log_msg "MODDIR=$MODDIR"

# ============================================================
# [5] Snapshot state for the final report
# ============================================================
ACTIVE_PROFILE="unknown"
if [ -f "$BIN_DIR/selected_profile.txt" ]; then
    _ap=$(cat "$BIN_DIR/selected_profile.txt" 2>/dev/null | tr -d '\r\n ')
    case "$_ap" in light|normal|pro|proplus|ultimate) ACTIVE_PROFILE="$_ap" ;; esac
fi

ROOT_SOLUTION="unknown"
if [ -n "${KSU_VER:-}" ] || [ -d "/data/adb/ksu" ]; then
    ROOT_SOLUTION="KernelSU"
elif [ -n "${APATCH:-}" ] || [ -d "/data/adb/ap" ]; then
    ROOT_SOLUTION="APatch"
elif [ -n "${MAGISK_VER_CODE:-}" ] || [ -d "/data/adb/magisk" ]; then
    ROOT_SOLUTION="Magisk"
fi

BACKUP_COUNT=0
BACKUP_LAST_NAME=""
BACKUP_LAST_STABLE=""
BACKUP_TXN_COUNT=0
BACKUP_ORPHAN_COUNT=0
APK_MIRROR_PRESENT=0
APK_MIRROR_SHA_PRESENT=0
APK_MIRROR_SIZE_BYTES=0

if [ -d "$PERSISTENT_BACKUP" ]; then
    BACKUP_COUNT=$(count_snapshots 2>/dev/null)
    case "$BACKUP_COUNT" in ''|*[!0-9]*) BACKUP_COUNT=0 ;; esac
    [ "$BACKUP_COUNT" -gt 0 ] && BACKUP_LAST_NAME=$(list_snapshots 1 2>/dev/null)
    BACKUP_LAST_STABLE=$(read_last_stable 2>/dev/null)

    _txn=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d txn-*/ 2>/dev/null | wc -l | tr -d ' ')
    case "$_txn" in ''|*[!0-9]*) _txn=0 ;; esac
    BACKUP_TXN_COUNT="$_txn"

    _orph=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d orphan-txn-*/ 2>/dev/null | wc -l | tr -d ' ')
    case "$_orph" in ''|*[!0-9]*) _orph=0 ;; esac
    BACKUP_ORPHAN_COUNT="$_orph"

    if [ -f "$APK_MIRROR_DIR/app-debug.apk" ]; then
        APK_MIRROR_PRESENT=1
        _apk_size=$(wc -c < "$APK_MIRROR_DIR/app-debug.apk" 2>/dev/null | tr -d ' ')
        case "$_apk_size" in ''|*[!0-9]*) _apk_size=0 ;; esac
        APK_MIRROR_SIZE_BYTES="$_apk_size"
        if [ -f "$APK_MIRROR_DIR/app-debug.apk.sha256" ] && \
           [ -s "$APK_MIRROR_DIR/app-debug.apk.sha256" ]; then
            APK_MIRROR_SHA_PRESENT=1
        fi
    fi
fi

# ============================================================
# [6] Save route_localnet before cleanup
# ============================================================
ORIGINAL_ROUTE_LOCALNET=""
command -v sysctl >/dev/null 2>&1 && \
    ORIGINAL_ROUTE_LOCALNET=$(sysctl -n net.ipv4.conf.all.route_localnet 2>/dev/null | tr -d '\r\n ')

# ============================================================
# [7] Kill processes + firewall cleanup
# ============================================================
if [ "$FUNCTIONS_LOADED" = "1" ]; then
    kill_all_dnscrypt_processes >/dev/null 2>&1 || true
    firewall_cleanup 2>/dev/null || true
    log_msg "Process + firewall cleanup complete (via lib)"
else
    log_msg "functions.sh unavailable — using inline cleanup"

    pkill -9 -x dnscrypt-proxy 2>/dev/null
    pkill -9 -x dnscrypt-webui 2>/dev/null

    # Watchdog kill via /proc/<pid>/cmdline (portable)
    for _pid_dir in /proc/[0-9]*; do
        [ -d "$_pid_dir" ] || continue
        _pid="${_pid_dir##*/}"
        _comm=$(cat "$_pid_dir/comm" 2>/dev/null)
        [ "$_comm" = "grep" ] && continue
        _cmd=$(tr '\0' ' ' < "$_pid_dir/cmdline" 2>/dev/null)
        case "$_cmd" in
            *"/watchdog.sh"*) kill -9 "$_pid" 2>/dev/null ;;
        esac
    done

    sleep 1

    command -v nft >/dev/null 2>&1 && {
        nft delete table ip dnscrypt_filter 2>/dev/null
        nft delete table ip6 dnscrypt_filter 2>/dev/null
        nft delete table inet dnscrypt_filter 2>/dev/null
    }

    command -v iptables >/dev/null 2>&1 && {
        iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT --wait 3 2>/dev/null
        iptables -t nat -F DNSCRYPT_OUT --wait 3 2>/dev/null
        iptables -t nat -X DNSCRYPT_OUT --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination "$LOOPBACK_IPV4:$DNS_ENGINE_PORT" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination "$LOOPBACK_IPV4:$DNS_ENGINE_PORT" --wait 3 2>/dev/null
    }

    command -v ip6tables >/dev/null 2>&1 && \
        ip6tables -t nat -L -n >/dev/null 2>&1 && {
        ip6tables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT6 --wait 3 2>/dev/null
        ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT6 --wait 3 2>/dev/null
        ip6tables -t nat -F DNSCRYPT_OUT6 --wait 3 2>/dev/null
        ip6tables -t nat -X DNSCRYPT_OUT6 --wait 3 2>/dev/null
    }
fi

command -v fuser >/dev/null 2>&1 && {
    fuser -k "${DNS_ENGINE_PORT}/udp" 2>/dev/null
    fuser -k "${DNS_ENGINE_PORT}/tcp" 2>/dev/null
}

# ============================================================
# [8] Reset system DNS
# ============================================================
log_msg "Resetting DNS settings..."

_wait=0
while [ "$_wait" -lt 10 ]; do
    settings get global private_dns_mode >/dev/null 2>&1 && break
    sleep 1
    _wait=$((_wait + 1))
done

if settings delete global private_dns_mode 2>/dev/null; then
    log_msg "private_dns_mode reset to AUTO"
else
    log_msg "WARNING: private_dns_mode reset failed (continuing)"
fi

if [ -n "$ORIGINAL_ROUTE_LOCALNET" ] && command -v sysctl >/dev/null 2>&1; then
    sysctl -w "net.ipv4.conf.all.route_localnet=$ORIGINAL_ROUTE_LOCALNET" >/dev/null 2>&1 && \
        log_msg "route_localnet restored to $ORIGINAL_ROUTE_LOCALNET"
fi

command -v ndc >/dev/null 2>&1 && \
    ndc resolver flushdefaultif 2>/dev/null

# ============================================================
# [9] Resolve transaction directories
# ============================================================
ORPHAN_TXN_RENAMED=0
ORPHAN_TXN_CLEANED=0

if [ -d "$PERSISTENT_BACKUP" ]; then
    for _txn in "$PERSISTENT_BACKUP"/txn-*; do
        [ -d "$_txn" ] || continue

        _state=""
        [ -f "$_txn/.state" ] && \
            _state=$(cat "$_txn/.state" 2>/dev/null | tr -d '\r\n ')

        case "$_state" in
            COMMIT|ROLLBACK)
                rm -rf "$_txn" 2>/dev/null && ORPHAN_TXN_CLEANED=$((ORPHAN_TXN_CLEANED + 1))
                ;;
            *)
                _safe_name="orphan-$(basename "$_txn" | sed 's/^txn-//')"
                if mv "$_txn" "$PERSISTENT_BACKUP/$_safe_name" 2>/dev/null; then
                    ORPHAN_TXN_RENAMED=$((ORPHAN_TXN_RENAMED + 1))
                fi
                ;;
        esac
    done
fi

# ============================================================
# [10] Remove legacy v1.0.0 backup dir
# ============================================================
LEGACY_BACKUP_REMOVED=0
if [ -d "$LEGACY_BACKUP_DIR" ]; then
    rm -rf "$LEGACY_BACKUP_DIR" 2>/dev/null && LEGACY_BACKUP_REMOVED=1
fi

# ============================================================
# [11] Remove run/ directory (includes .watchdog_token there)
# ============================================================
RUN_DIR_REMOVED=0
if [ -d "$RUN_DIR" ]; then
    rm -rf "$RUN_DIR" 2>/dev/null && RUN_DIR_REMOVED=1
fi

# ============================================================
# [12] Remove runtime files from /data/local/tmp
# ============================================================
RUNTIME_COUNT=0

for f in \
    /data/local/tmp/dnscrypt.pid \
    /data/local/tmp/webui.pid \
    /data/local/tmp/watchdog.pid \
    /data/local/tmp/webui.pid.tmp \
    /data/local/tmp/watchdog.pid.tmp \
    /data/local/tmp/dnscrypt.status \
    /data/local/tmp/update_progress.txt \
    /data/local/tmp/dnscrypt_credentials.txt \
    /data/local/tmp/.dnscrypt_credentials_shown \
    /data/local/tmp/.watchdog_token \
    /data/local/tmp/.bootstrap_cache \
    /data/local/tmp/dnscrypt_install.log \
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
    "/data/local/tmp/dnscrypt-proxy.log.*.old" \
    "/data/local/tmp/*.filtered" \
    "/data/local/tmp/*.filtered.count" \
    "/data/local/tmp/_allow_norm.txt" \
    "/data/local/tmp/_deny_norm.txt"; do
    for f in $pattern; do
        [ -f "$f" ] || continue
        rm -f "$f" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    done
done

for lock in \
    /data/local/tmp/.service.start.lock \
    /data/local/tmp/.watchdog.pid.lock \
    /data/local/tmp/.action-start.lock; do
    if [ -d "$lock" ]; then
        rm -rf "$lock" 2>/dev/null && RUNTIME_COUNT=$((RUNTIME_COUNT + 1))
    fi
done

# Stop logging now that the log file is gone.
LOG_DISABLED=1

# ============================================================
# [13] Remove module config files
# ============================================================
MODULE_COUNT=0
if [ -d "$BIN_DIR" ]; then
    for f in selected_profile.txt webui.conf webui.conf.tmp \
             dnscrypt-proxy.toml dnscrypt-proxy.toml.bak \
             blocklist.txt blocklist.txt.tmp blocklist.txt.bak \
             blocklist.txt.filtered blocklist.txt.rules_tmp \
             blocklist.raw blocklist.raw.tmp blocklist.raw.tmp_write \
             blocklist.raw.bak blocklist.raw.filtered blocklist.raw.filtered.tmp \
             blocked-ips.txt allowlist.txt allowlist.txt.tmp_write \
             denylist.txt denylist.txt.tmp_write \
             auth.json .auth_token \
             public-resolvers.md public-resolvers.md.minisig \
             relays.md relays.md.minisig; do
        if [ -f "$BIN_DIR/$f" ]; then
            rm -f "$BIN_DIR/$f" 2>/dev/null && MODULE_COUNT=$((MODULE_COUNT + 1))
        fi
    done
fi

# ============================================================
# [14] Remove module fingerprint and disable file
# ============================================================
[ -f "$MODDIR/.module.fingerprint" ] && rm -f "$MODDIR/.module.fingerprint" 2>/dev/null
[ -f "$MODDIR/disable" ] && rm -f "$MODDIR/disable" 2>/dev/null

# ============================================================
# [15] Remove recovery triggers
# ============================================================
RECOVERY_TRIGGER=""
if [ "$FUNCTIONS_LOADED" = "1" ] && command -v get_recovery_trigger >/dev/null 2>&1; then
    RECOVERY_TRIGGER=$(get_recovery_trigger "$MODDIR" 2>/dev/null)
fi
[ -z "$RECOVERY_TRIGGER" ] && RECOVERY_TRIGGER="$MODDIR/recovery"

RECOVERY_INTERNAL_REMOVED=0
RECOVERY_EXTERNAL_REMOVED=0

if [ -f "$RECOVERY_TRIGGER" ]; then
    rm -f "$RECOVERY_TRIGGER" 2>/dev/null && RECOVERY_INTERNAL_REMOVED=1
fi
if [ -f "$RECOVERY_TRIGGER_2" ]; then
    rm -f "$RECOVERY_TRIGGER_2" 2>/dev/null && RECOVERY_EXTERNAL_REMOVED=1
fi

# ============================================================
# [16] PRESERVE backup directory — explicitly do nothing
# ============================================================
# $PERSISTENT_BACKUP and $APK_MIRROR_DIR are intentionally
# left untouched. The user's data survives the uninstall.

# ============================================================
# [17] Final report
# ============================================================
BACKUP_ORPHAN_FINAL=$((BACKUP_ORPHAN_COUNT + ORPHAN_TXN_RENAMED))

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  DNSCrypt Smart Filter — Uninstall Complete"
echo "════════════════════════════════════════════════════════════"
echo ""

if [ -d "$PERSISTENT_BACKUP" ] && [ "$BACKUP_COUNT" -gt 0 ]; then
    echo "  💾 Your settings have been PRESERVED:"
    echo ""
    echo "     Location:  $PERSISTENT_BACKUP"
    echo "     Snapshots: $BACKUP_COUNT"
    [ -n "$BACKUP_LAST_NAME" ] && echo "     Latest:    $BACKUP_LAST_NAME"
    [ -n "$BACKUP_LAST_STABLE" ] && echo "     Last stable: $BACKUP_LAST_STABLE"
    echo ""
    echo "     Preserved files:"
    for _uf in $USER_FILES; do echo "       - $_uf"; done

    if [ "$APK_MIRROR_PRESENT" = "1" ]; then
        echo ""
        if [ "$APK_MIRROR_SHA_PRESENT" = "1" ]; then
            echo "     APK mirror: $APK_MIRROR_DIR/"
            echo "                 ($APK_MIRROR_SIZE_BYTES bytes + .sha256)"
        else
            echo "     APK mirror: $APK_MIRROR_DIR/"
            echo "                 ($APK_MIRROR_SIZE_BYTES bytes)"
        fi
    fi

    echo ""
    echo "  ✅ Reinstall the module to restore these settings automatically."
    echo ""
    echo "  ⚠️  To remove manually:"
    echo "     su -c \"rm -rf $PERSISTENT_BACKUP\""
elif [ -d "$PERSISTENT_BACKUP" ]; then
    echo "  ℹ️  Backup directory exists but is empty: $PERSISTENT_BACKUP"
    echo ""
    echo "  ⚠️  To remove manually:"
    echo "     su -c \"rm -rf $PERSISTENT_BACKUP\""
else
    echo "  ℹ️  No persistent backup found (nothing to preserve)"
fi

if [ "$BACKUP_ORPHAN_FINAL" -gt 0 ]; then
    echo ""
    echo "  ⚠️  Unfinished transactions preserved:"
    echo ""
    echo "     $PERSISTENT_BACKUP/orphan-txn-*"
    if [ "$ORPHAN_TXN_RENAMED" -gt 0 ]; then
        echo ""
        echo "     ($ORPHAN_TXN_RENAMED txn-* renamed to orphan-txn-*)"
    fi
    echo ""
    echo "     Inspect: su -c \"ls -la $PERSISTENT_BACKUP/orphan-txn-*/\""
fi

if [ "$RECOVERY_EXTERNAL_REMOVED" = "1" ]; then
    echo ""
    echo "  🧹 Removed: $RECOVERY_TRIGGER_2"
fi
if [ "$RECOVERY_INTERNAL_REMOVED" = "1" ]; then
    echo "  🧹 Removed: $RECOVERY_TRIGGER"
fi

if [ "$RUN_DIR_REMOVED" = "1" ]; then
    echo ""
    echo "  🧹 Runtime directory removed (incl. .watchdog_token)"
fi

if [ "$LEGACY_BACKUP_REMOVED" = "1" ]; then
    echo ""
    echo "  🧹 Legacy v1.0.0 backup removed: $LEGACY_BACKUP_DIR"
fi

echo ""
echo "  ℹ️  Companion Android app unaffected:"
echo "     • Module-internal APK removed with module folder."
echo "     • /sdcard/.../apk/ mirror survives (see above)."
echo "     • Installed app on device remains — uninstall from"
echo "       Android Settings if desired."
echo ""
echo "  Exit code: 0 (success)"
echo "════════════════════════════════════════════════════════════"
echo ""

exit 0