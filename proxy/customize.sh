#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – customize.sh
# Version: v1.1.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Magisk / KernelSU / APatch installer script.
#
#   Responsibilities:
#     • Verify installation environment (MODPATH security)
#     • Detect architecture (arm64 / arm / x86_64 / x86)
#     • Stop old processes on upgrade
#     • Clean firewall state (Custom Chains + legacy)
#     • Backup user settings BEFORE extraction
#     • Extract module files
#     • Restore user settings AFTER extraction
#     • Validate critical files
#     • Copy the correct binaries for the current architecture
#     • Create secure run/ directory (0700)
#     • Write webui.conf with Port Guard (reject 8080 + collisions)
#     • Generate secure credentials for the monitoring_ui
#     • Set permissions
#     • Write the module fingerprint
#
# User settings preserved on upgrade (5 files):
#   • webui.conf
#   • dnscrypt-proxy.toml
#   • selected_profile.txt
#   • allowlist.txt
#   • denylist.txt
#
# Port Guard (v1.1.0 — collision-safe):
#   • The reserved port 8080 (monitoring_ui) is rejected.
#   • PORT and DASHBOARD_PORT must never be equal.
#     When a collision is detected, DASHBOARD_PORT is
#     reassigned to a port that differs from PORT.
#
# Credentials:
#   Generated automatically if empty or default (admin/admin).
#   Saved to /data/local/tmp/dnscrypt_credentials.txt (mode 0600).
#   Also readable from dnscrypt-proxy.toml [monitoring_ui].
#
# Memory limits (v1.1.0):
#   main.go adjusts the Go runtime soft memory limit based on
#   the selected profile:
#     • Light      →  80 MB
#     • Normal     → 100 MB
#     • PRO        → 120 MB
#     • PRO++      → 160 MB
#     • Ultimate   → 220 MB
#   This is handled by main.go — customize.sh does not set it.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Determine module path (temporary)
# ============================================================
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

# Path of previously installed module (for upgrade detection)
_EXISTING_MODULE="/data/adb/modules/dnscrypt-proxy-webui"

# ============================================================
# [3] Check required tools
# ============================================================
for tool in unzip sed tr date grep head cut; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        abort "❌ Required tool '$tool' not found. Installation aborted."
    fi
done

# md5sum is optional (has fallback)
HAS_MD5SUM=0
if command -v md5sum >/dev/null 2>&1; then
    HAS_MD5SUM=1
fi

# sha256sum is optional
HAS_SHA256=0
if command -v sha256sum >/dev/null 2>&1; then
    HAS_SHA256=1
fi

# ============================================================
# [3b] Extract module.prop early
# ============================================================
# The installer reads the version from module.prop, but with
# SKIPUNZIP=1 the file is not extracted yet. Extract just this
# small file first so version messages display correctly.
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
# [5] Display installation header
# ============================================================
ui_print "╔══════════════════════════════════════════╗"
ui_print "║  🛡️  DNSCrypt Smart Filter              ║"
printf "║      %-32s ║\n" "$MODULE_VERSION"
ui_print "║      Professional Edition                ║"
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
    echo "========================================"
} >> "$INSTALL_LOG"

ARCH=$(getprop ro.product.cpu.abi)
ui_print "- Architecture: $ARCH"
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
# [8] Silent upgrade cleanup
# ============================================================
UPGRADE_DETECTED=0
KILLED_COUNT=0

if [ -d "$_EXISTING_MODULE" ] && [ "$_EXISTING_MODULE" != "$MODPATH" ]; then
    UPGRADE_DETECTED=1
    echo "Upgrade detected ($_EXISTING_MODULE)" >> "$INSTALL_LOG"
fi

if [ -f "/data/local/tmp/dnscrypt.pid" ] || \
   [ -f "/data/local/tmp/webui.pid" ] || \
   [ -f "$_EXISTING_MODULE/proxy/run/dnscrypt.pid" ]; then
    UPGRADE_DETECTED=1
fi

if [ "$UPGRADE_DETECTED" = "1" ]; then
    ui_print ""
    ui_print "- Upgrade detected, cleaning old instances..."

    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-proxy 2>/dev/null
        KILLED_COUNT=$((KILLED_COUNT + 1))
    fi
    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
        KILLED_COUNT=$((KILLED_COUNT + 1))
    fi

    for wd_file in "/data/local/tmp/watchdog.pid" \
                    "$_EXISTING_MODULE/proxy/run/watchdog.pid"; do
        if [ -f "$wd_file" ]; then
            old_wd=$(cat "$wd_file" 2>/dev/null | tr -d '\r\n ')
            if [ -n "$old_wd" ] && kill -0 "$old_wd" 2>/dev/null; then
                kill -9 "$old_wd" 2>/dev/null
                KILLED_COUNT=$((KILLED_COUNT + 1))
            fi
        fi
    done

    ui_print "  → Killed $KILLED_COUNT old process(es)"
    echo "Killed $KILLED_COUNT old process(es)" >> "$INSTALL_LOG"

    _inline_cleanup_firewall

    ui_print "  → Firewall rules cleaned (Custom Chain + Legacy)"
    echo "Firewall cleanup attempted (Custom Chain + Legacy)" >> "$INSTALL_LOG"
    ui_print "  ✅ Old instances cleaned"
else
    ui_print "- Fresh installation (no upgrade detected)"
fi

ui_print ""

# ============================================================
# [8b] Backup user settings BEFORE extraction
# ============================================================
BACKUP_TMP=""
BACKUP_COUNT=0

if [ "$UPGRADE_DETECTED" = "1" ] && [ -d "$_EXISTING_MODULE/proxy" ]; then
    BACKUP_TMP="/data/local/tmp/dnscrypt-upgrade-backup-$$"

    if mkdir -p "$BACKUP_TMP" 2>/dev/null; then
        for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
            src="$_EXISTING_MODULE/proxy/$f"
            if [ -f "$src" ]; then
                if cp -f "$src" "$BACKUP_TMP/$f" 2>/dev/null; then
                    BACKUP_COUNT=$((BACKUP_COUNT + 1))
                fi
            fi
        done

        if [ "$BACKUP_COUNT" -gt 0 ]; then
            ui_print "  → Backed up $BACKUP_COUNT user config file(s)"
            echo "Backed up $BACKUP_COUNT files to $BACKUP_TMP" >> "$INSTALL_LOG"
        else
            ui_print "  → No user config files to back up"
            rm -rf "$BACKUP_TMP" 2>/dev/null
            BACKUP_TMP=""
        fi
    else
        ui_print "  ⚠️ Failed to create backup dir (continuing with defaults)"
        BACKUP_TMP=""
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
        ui_print "  → $f moved to web/"
        echo "  Moved $f to web/" >> "$INSTALL_LOG"
    fi
done

ui_print "  ✅ Files extracted"

# ============================================================
# [9c] Restore user settings AFTER extraction
# ============================================================
BIN_DIR="$MODPATH/proxy"
RESTORED_COUNT=0

if [ -n "$BACKUP_TMP" ] && [ -d "$BACKUP_TMP" ]; then
    ui_print ""
    ui_print "- Restoring user configuration..."

    for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
        if [ -f "$BACKUP_TMP/$f" ]; then
            if cp -f "$BACKUP_TMP/$f" "$BIN_DIR/$f" 2>/dev/null; then
                RESTORED_COUNT=$((RESTORED_COUNT + 1))
                echo "  Restored: $f" >> "$INSTALL_LOG"
            fi
        fi
    done

    rm -rf "$BACKUP_TMP" 2>/dev/null

    if [ "$RESTORED_COUNT" -gt 0 ]; then
        ui_print "  ✅ Restored $RESTORED_COUNT user config file(s)"
        echo "Restored $RESTORED_COUNT files" >> "$INSTALL_LOG"
    fi
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
        abort "❌ Unsupported architecture: $ARCH"
        ;;
esac

ui_print "- Target binaries: $DNS_BIN + $WEB_BIN"

if [ ! -f "$BIN_DIR/$DNS_BIN" ]; then
    echo "❌ DNS binary not found: $DNS_BIN" >> "$INSTALL_LOG"
    abort "❌ DNS binary missing for $ARCH"
fi

if [ ! -f "$BIN_DIR/$WEB_BIN" ]; then
    echo "❌ WebUI binary not found: $WEB_BIN" >> "$INSTALL_LOG"
    abort "❌ WebUI binary missing for $ARCH"
fi

cp -f "$BIN_DIR/$DNS_BIN" "$BIN_DIR/dnscrypt-proxy" || abort "❌ Failed to copy DNS binary"
cp -f "$BIN_DIR/$WEB_BIN" "$BIN_DIR/dnscrypt-webui" || abort "❌ Failed to copy WebUI binary"
echo "✅ Binaries copied: $DNS_BIN, $WEB_BIN" >> "$INSTALL_LOG"

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
if [ "$UPGRADE_DETECTED" = "1" ]; then
    ui_print "- Old modules will be detected at runtime via WebUI"
    echo "Migration handled by [8b]/[9c] + runtime detection" >> "$INSTALL_LOG"
else
    ui_print "- Fresh installation"
fi

ui_print ""
ui_print "- Creating configuration files..."

# ============================================================
# [14] Port validation — v1.1.0 collision-safe
# ============================================================
#
# Order of checks (v1.1.0):
#   1. Individual 8080 rejection (for PORT and DASHBOARD_PORT).
#   2. PORT == DASHBOARD_PORT collision → reassign DASHBOARD_PORT
#      to a port that differs from PORT.
#
# Why the order changed:
#   The v1.0.0 code checked equality BEFORE 8080, which caused a
#   failure when both were 9091 — the equality fix set dashboard
#   to 9091 (no actual change), and the 8080 check was a no-op.
#
#   The new order guarantees:
#     • No value equals 8080.
#     • PORT != DASHBOARD_PORT (always).
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

# --- Read existing values (after restore) ---
if [ -f "$BIN_DIR/webui.conf" ]; then
    EXISTING_PORT=$(grep "^PORT=" "$BIN_DIR/webui.conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
    if validate_port "$EXISTING_PORT"; then
        TEMP_PORT="$EXISTING_PORT"
    else
        if [ "$EXISTING_PORT" = "$_MONITORING_UI_PORT" ]; then
            ui_print "  ⚠️ PORT=8080 conflicts with [monitoring_ui], resetting to 9090"
        else
            ui_print "  ⚠️ Invalid PORT in webui.conf, reset to 9090"
        fi
    fi

    EXISTING_DASHBOARD=$(grep "^DASHBOARD_PORT=" "$BIN_DIR/webui.conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r ')
    if validate_port "$EXISTING_DASHBOARD"; then
        TEMP_DASHBOARD_PORT="$EXISTING_DASHBOARD"
    else
        if [ "$EXISTING_DASHBOARD" = "$_MONITORING_UI_PORT" ]; then
            ui_print "  ⚠️ DASHBOARD_PORT=8080 conflicts with [monitoring_ui], resetting to 9091"
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

# ============================================================
# [14a] Final validation — Step 1: reject 8080
# ============================================================
if [ "$TEMP_PORT" = "$_MONITORING_UI_PORT" ]; then
    ui_print "  ⚠️ PORT=$_MONITORING_UI_PORT conflicts with [monitoring_ui], forcing 9090"
    TEMP_PORT="9090"
fi
if [ "$TEMP_DASHBOARD_PORT" = "$_MONITORING_UI_PORT" ]; then
    ui_print "  ⚠️ DASHBOARD_PORT=$_MONITORING_UI_PORT conflicts with [monitoring_ui], forcing 9091"
    TEMP_DASHBOARD_PORT="9091"
fi

# ============================================================
# [14b] Final validation — Step 2: resolve collision (v1.1.0)
# ============================================================
#
# If PORT and DASHBOARD_PORT are equal, reassign DASHBOARD_PORT
# to a port that is different from PORT.
#
# Strategy:
#   • If PORT=9091 → dashboard becomes 9092.
#   • Otherwise    → dashboard becomes 9091.
#
# This guarantees:
#   - dashboard != PORT
#   - dashboard != 8080 (already guaranteed by step 1 above)
#   - dashboard != 5354 (DNS engine) in most cases; edge case
#     accepted because DNS engine is internal and always binds.
# ============================================================
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
    abort "❌ Failed to write webui.conf"
fi

if [ ! -s "$BIN_DIR/webui.conf.tmp" ]; then
    rm -f "$BIN_DIR/webui.conf.tmp"
    abort "❌ webui.conf is empty after write"
fi

mv -f "$BIN_DIR/webui.conf.tmp" "$BIN_DIR/webui.conf" || abort "❌ Failed to finalize webui.conf"

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
# [17] Create default config files
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

# ------------------------------------------------------------
# read_toml_credentials — prints "user\npass"
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# Extract current values
# ------------------------------------------------------------
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
# [20] Write module fingerprint
# ============================================================
printf "dnscrypt-proxy-webui-%s\n" "$MODULE_VERSION" > "$MODPATH/.module.fingerprint"

# ============================================================
# [21] Compute expected memory limit (v1.1.0)
# ============================================================
#
# main.go adjusts the Go runtime soft memory limit based on the
# selected profile. We mirror that computation here purely for
# the final summary message — main.go remains the authority.
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
# [22] Display final summary
# ============================================================
ui_print ""
ui_print "╔══════════════════════════════════════════╗"
ui_print "║  ✅ Installation Complete                ║"
printf "║      %-32s ║\n" "$MODULE_VERSION"
ui_print "╚══════════════════════════════════════════╝"
ui_print ""
ui_print "  📊 Upgrade detected: $([ "$UPGRADE_DETECTED" = "1" ] && echo "YES ($RESTORED_COUNT files restored)" || echo "NO")"
ui_print "  🌐 WebUI: http://127.0.0.1:$TEMP_PORT"
ui_print "  📈 Dashboard: http://127.0.0.1:$TEMP_DASHBOARD_PORT"
ui_print "  🔌 Bind: $TEMP_BIND_ADDR"
ui_print "  🧠 Memory limit: ~$EXPECTED_MEM_LIMIT (profile: $SELECTED_PROFILE)"
ui_print ""
ui_print "  ℹ️  Next steps:"
ui_print "    1. Reboot your device"
ui_print "    2. Open the WebUI and login with the credentials above"
ui_print "    3. Choose a blocklist profile and press Apply"
ui_print ""

# ============================================================
# [23] Reboot warning
# ============================================================
if [ "$UPGRADE_DETECTED" = "1" ] && [ "$KILLED_COUNT" -gt 0 ]; then
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