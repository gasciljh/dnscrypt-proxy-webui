#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — customize.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Magisk / KernelSU / APatch installer (customize.sh hook).
#
# Sources boot-mini.sh (which loads all lib/). Uses:
#   lib/constants.sh  — paths, ports, USER_FILES, recovery path
#   lib/process.sh    — kill_* + list_pids_by_*
#   lib/backup.sh     — transaction_*, backup_create,
#                       mark_last_stable, restore_user_files
#   lib/firewall.sh   — firewall_cleanup
#   lib/fallbacks.sh  — write-test-safe run dir
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path + version
# ============================================================
if [ -n "${MODPATH:-}" ]; then
    MODDIR="$MODPATH"
else
    MODDIR=${0%/*}
    [ "$MODDIR" = "." ] && MODDIR=$(pwd)
    case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac
fi

# ============================================================
# [2] Security guards
# ============================================================
if [ -z "$MODPATH" ]; then
    echo "❌ Please install via Magisk Manager or KernelSU!" >&2
    exit 1
fi

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

if ! command -v abort >/dev/null 2>&1; then
    abort() { echo "$1" >&2; exit 1; }
fi

if ! command -v ui_print >/dev/null 2>&1; then
    ui_print() { echo "$1"; }
fi

SKIPUNZIP=1

# ============================================================
# [3] Load boot-mini + lib/
# ============================================================
for _cand in "$MODPATH/boot-mini.sh" "$MODDIR/boot-mini.sh"; do
    if [ -f "$_cand" ]; then
        _BM_PATH="$_cand"
        break
    fi
done

if [ -z "${_BM_PATH:-}" ] && [ -n "${ZIPFILE:-}" ] && [ -f "$ZIPFILE" ]; then
    unzip -o "$ZIPFILE" 'boot-mini.sh' 'lib/*' 'functions.sh' \
        'module.prop' -d "$MODPATH" >/dev/null 2>&1 || true
    for _cand in "$MODPATH/boot-mini.sh" "$MODDIR/boot-mini.sh"; do
        [ -f "$_cand" ] && { _BM_PATH="$_cand"; break; }
    done
fi

if [ -z "${_BM_PATH:-}" ]; then
    echo "❌ boot-mini.sh not available — cannot proceed" >&2
    exit 1
fi

if [ ! -d "$MODDIR/lib" ]; then
    echo "❌ CRITICAL: lib/ directory not found at $MODDIR/lib" >&2
    echo "   The ZIP must contain a 'lib/' folder at its root." >&2
    abort "❌ Installation aborted: missing library files."
fi

. "$_BM_PATH"
unset _BM_PATH _cand

if command -v init_module_paths >/dev/null 2>&1; then
    init_module_paths "$MODDIR" 2>/dev/null || true
fi

# ============================================================
# [4] Module version + root solution
# ============================================================
MODULE_VERSION=$(get_module_version "$MODPATH")

MODULE_VERSION_CODE=""
if [ -f "$MODPATH/module.prop" ]; then
    MODULE_VERSION_CODE=$(grep "^versionCode=" "$MODPATH/module.prop" 2>/dev/null \
        | head -n1 | cut -d= -f2- | tr -d '\r ')
fi

# ============================================================
# [5] Tools check
# ============================================================
for tool in unzip sed tr date grep head cut awk find chmod chown; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        abort "❌ Required tool '$tool' not found. Installation aborted."
    fi
done

# ============================================================
# [6] Install-time log + transaction state
# ============================================================
INSTALL_LOG="/data/local/tmp/dnscrypt_install.log"
: > "$INSTALL_LOG" 2>/dev/null

{
    echo "========================================"
    echo "DNSCrypt Install $MODULE_VERSION – $(date)"
    echo "versionCode: $MODULE_VERSION_CODE"
    echo "MODPATH: $MODPATH"
    echo "Root solution: $ROOT_SOLUTION"
    echo "========================================"
} >> "$INSTALL_LOG"

_INSTALLER_DONE=0
_INSTALLER_RECOVERY_SNAPSHOT=""

_installer_cleanup() {
    [ "$_INSTALLER_DONE" = "1" ] && return 0
    _INSTALLER_DONE=1

    if [ "${TXN_ACTIVE:-0}" = "1" ]; then
        echo "installer: SIGINT/SIGTERM/EXIT — rolling back txn" >> "$INSTALL_LOG"
        transaction_rollback 2>/dev/null || true
    fi

    if [ -n "$_INSTALLER_RECOVERY_SNAPSHOT" ] && \
       [ -d "$_INSTALLER_RECOVERY_SNAPSHOT" ]; then
        if [ ! -f "$(get_recovery_trigger "$MODPATH")" ]; then
            rm -rf "$_INSTALLER_RECOVERY_SNAPSHOT" 2>/dev/null
        fi
    fi
    return 0
}

trap '_installer_cleanup' EXIT
trap '_installer_cleanup; exit 130' INT
trap '_installer_cleanup; exit 143' TERM

# ============================================================
# [7] Display header
# ============================================================
ui_print "╔══════════════════════════════════════════╗"
ui_print "║  🛡️  DNSCrypt Smart Filter               ║"
printf "║      %-32s ║\n" "$MODULE_VERSION"
ui_print "║      Global edition (bilingual WebUI)    ║"
ui_print "╚══════════════════════════════════════════╝"
ui_print ""

ARCH=$(getprop ro.product.cpu.abi)
ui_print "- 📱 Architecture: $ARCH"
ui_print "- 🔐 Root solution: $ROOT_SOLUTION"
echo "Architecture: $ARCH" >> "$INSTALL_LOG"

# ============================================================
# [8] Recovery mode detection
# ============================================================
_INSTALLED_MODULE_DIR="/data/adb/modules/$MODULE_ID"
RECOVERY_TRIGGER_INSTALLED="$_INSTALLED_MODULE_DIR/recovery"
RECOVERY_TRIGGER_STAGING="$MODPATH/recovery"
RECOVERY_TRIGGER_EXTERNAL="/data/adb/dnscrypt-recovery"

RECOVERY_MODE=0
RESTORE_SOURCE=""
_recovery_restored=0
_recovery_snapshotted=0

if [ -f "$RECOVERY_TRIGGER_INSTALLED" ] || \
   [ -f "$RECOVERY_TRIGGER_STAGING" ] || \
   [ -f "$RECOVERY_TRIGGER_EXTERNAL" ]; then

    ui_print ""
    ui_print "  🚨 RECOVERY MODE ACTIVATED"
    ui_print "  ─────────────────────────────"

    _last_stable=$(read_last_stable 2>/dev/null)
    if [ -n "$_last_stable" ] && [ -d "$PERSISTENT_BACKUP/$_last_stable" ]; then
        RESTORE_SOURCE="$PERSISTENT_BACKUP/$_last_stable"
        ui_print "  → Source: $_last_stable (last stable)"
    fi

    if [ -z "$RESTORE_SOURCE" ] && [ -d "$PERSISTENT_BACKUP/current" ]; then
        RESTORE_SOURCE="$PERSISTENT_BACKUP/current"
        ui_print "  → Source: current"
    fi

    if [ -z "$RESTORE_SOURCE" ]; then
        _newest=$(list_snapshots 1)
        if [ -n "$_newest" ] && [ -d "$PERSISTENT_BACKUP/$_newest" ]; then
            if verify_backup_integrity "$PERSISTENT_BACKUP/$_newest" 1; then
                RESTORE_SOURCE="$PERSISTENT_BACKUP/$_newest"
                ui_print "  → Source: $_newest (smart fallback)"
            fi
        fi
    fi

    if [ -z "$RESTORE_SOURCE" ]; then
        ui_print "  ❌ No recovery source available"
        ui_print "  ⚠️  Proceeding with normal install"
        rm -f "$RECOVERY_TRIGGER_INSTALLED" \
              "$RECOVERY_TRIGGER_STAGING" \
              "$RECOVERY_TRIGGER_EXTERNAL" 2>/dev/null
    else
        mkdir -p "$MODPATH/proxy" 2>/dev/null
        _snapshot_dir="$MODPATH/.recovery_snapshot"
        _INSTALLER_RECOVERY_SNAPSHOT="$_snapshot_dir"

        rm -rf "$_snapshot_dir" 2>/dev/null
        mkdir -p "$_snapshot_dir" 2>/dev/null

        for _f in $USER_FILES; do
            if [ -f "$RESTORE_SOURCE/$_f" ] && [ -s "$RESTORE_SOURCE/$_f" ]; then
                if copy_with_context "$RESTORE_SOURCE/$_f" "$MODPATH/proxy/$_f"; then
                    _recovery_restored=$((_recovery_restored + 1))
                    copy_with_context "$RESTORE_SOURCE/$_f" "$_snapshot_dir/$_f" && \
                        _recovery_snapshotted=$((_recovery_snapshotted + 1))
                fi
            fi
        done

        ui_print "  ✅ Restored $_recovery_restored file(s)"

        rm -f "$RECOVERY_TRIGGER_INSTALLED" \
              "$RECOVERY_TRIGGER_STAGING" \
              "$RECOVERY_TRIGGER_EXTERNAL" 2>/dev/null

        RECOVERY_MODE=1
    fi
fi

# ============================================================
# [9] Multi-source discovery
# ============================================================
CANDIDATE_SOURCES=""

for _root in /data/adb/modules /data/adb/modules_update \
             /data/adb/ksu/modules /data/adb/ap/modules; do
    [ -d "$_root" ] || continue
    for _m in "$_root"/*; do
        [ -d "$_m" ] || continue
        [ -f "$_m/module.prop" ] || continue
        _id=$(grep '^id=' "$_m/module.prop" | head -1 | cut -d= -f2- | tr -d '\r ')
        [ "$_id" = "$MODULE_ID" ] || continue
        [ -f "$_m/proxy/webui.conf" ] && [ -s "$_m/proxy/webui.conf" ] || continue
        CANDIDATE_SOURCES="$CANDIDATE_SOURCES $_m/proxy"
    done
done

CANDIDATE_SOURCES="$CANDIDATE_SOURCES $PERSISTENT_BACKUP/current"

if [ ! -d "$PERSISTENT_BACKUP/current" ]; then
    _newest=$(list_snapshots 1)
    if [ -n "$_newest" ]; then
        CANDIDATE_SOURCES="$CANDIDATE_SOURCES $PERSISTENT_BACKUP/$_newest"
        echo "Smart fallback: newest snapshot $_newest" >> "$INSTALL_LOG"
    fi
fi

CANDIDATE_SOURCES="$CANDIDATE_SOURCES $PERSISTENT_BACKUP"
CANDIDATE_SOURCES="$CANDIDATE_SOURCES /data/local/tmp/dnscrypt-webui-backup"

FOUND_SOURCE=""
FOUND_FILE_COUNT=0
_best_version=""
_best_score=0

for candidate in $CANDIDATE_SOURCES; do
    [ -d "$candidate" ] || continue
    _found=0
    for _f in $USER_FILES; do
        [ -f "$candidate/$_f" ] && [ -s "$candidate/$_f" ] && _found=$((_found + 1))
    done
    [ "$_found" -lt 3 ] && continue

    _ver=$(read_source_version "$candidate" 2>/dev/null)
    [ -z "$_ver" ] && _ver="0.0.0"
    _ver=$(printf '%s' "$_ver" | tr -d 'v\r ')

    _vmaj=$(echo "$_ver" | cut -d. -f1); case "$_vmaj" in ""|*[!0-9]*) _vmaj=0 ;; esac
    _vmin=$(echo "$_ver" | cut -d. -f2); case "$_vmin" in ""|*[!0-9]*) _vmin=0 ;; esac
    _vpat=$(echo "$_ver" | cut -d. -f3); case "$_vpat" in ""|*[!0-9]*) _vpat=0 ;; esac

    _score=$(( _found * 1000000 + _vmaj * 10000 + _vmin * 100 + _vpat ))
    if [ "$_score" -gt "$_best_score" ]; then
        _best_score="$_score"
        _best_version="$_ver"
        FOUND_SOURCE="$candidate"
        FOUND_FILE_COUNT="$_found"
    fi
done

if [ -z "$FOUND_SOURCE" ]; then
    ui_print "  → No existing user data (fresh install)"
    echo "No user data found" >> "$INSTALL_LOG"
else
    _name=$(basename "$(dirname "$FOUND_SOURCE")")
    ui_print "  ✅ Found: $_name (v$_best_version, $FOUND_FILE_COUNT files)"
    echo "Selected: $_name at $FOUND_SOURCE" >> "$INSTALL_LOG"
fi

# ============================================================
# [10] Kill old processes + firewall cleanup
# ============================================================
KILLED=$(kill_all_dnscrypt_processes 2>/dev/null || echo 0)
case "$KILLED" in ''|*[!0-9]*) KILLED=0 ;; esac

for _lock in \
    "$MODPATH/proxy/run/.service.start.lock" \
    "$MODPATH/proxy/run/.watchdog.pid.lock" \
    "/data/local/tmp/.service.start.lock" \
    "/data/local/tmp/.watchdog.pid.lock"; do
    [ -d "$_lock" ] && rm -rf "$_lock" 2>/dev/null && \
        echo "  🧹 Removed stale lock: $_lock" >> "$INSTALL_LOG"
done

[ "$KILLED" -gt 0 ] && ui_print "- Killed $KILLED old process(es)"

TOML_FILE="${TOML_FILE:-$MODPATH/proxy/dnscrypt-proxy.toml}"
firewall_cleanup 2>/dev/null || true
ui_print "- 🔥 Firewall rules cleaned"

# ============================================================
# [11] Begin transaction
# ============================================================
if [ -n "$FOUND_SOURCE" ] && [ "$RECOVERY_MODE" != "1" ]; then
    if transaction_begin; then
        ui_print "- 📦 Transaction: $(basename "$TXN_DIR")"
        echo "TXN_DIR=$TXN_DIR" >> "$INSTALL_LOG"
    else
        ui_print "  ⚠️ Transaction unavailable — continuing without rollback"
    fi

    if [ "${TXN_ACTIVE:-0}" = "1" ] && [ -d "$TXN_DIR" ]; then
        for _f in $USER_FILES; do
            if [ -f "$FOUND_SOURCE/$_f" ] && [ -s "$FOUND_SOURCE/$_f" ]; then
                copy_with_context "$FOUND_SOURCE/$_f" "$TXN_DIR/$_f" 2>/dev/null || true
            fi
        done
    fi
fi

# ============================================================
# [12] Extract module files
# ============================================================
ui_print ""
ui_print "- 📂 Extracting module files..."

if ! unzip -o "$ZIPFILE" \
    'proxy/*' 'module.prop' 'service.sh' 'post-fs-data.sh' \
    'action.sh' 'status.sh' 'uninstall.sh' 'functions.sh' \
    'boot-mini.sh' 'watchdog.sh' 'install_app.sh' 'lib/*' \
    'index.html' 'dashboard.html' 'manifest.json' 'sw.js' \
    'icon-*.svg' 'icon-*.png' 'apple-touch-icon.png' \
    'favicon-*.png' 'favicon.ico' 'offline.html' 'web/*' \
    -d "$MODPATH" >/dev/null 2>&1; then
    transaction_rollback 2>/dev/null || true
    abort "❌ Failed to extract module files"
fi

mkdir -p "$MODPATH/web" 2>/dev/null
for f in index.html dashboard.html manifest.json sw.js \
         icon-192.svg icon-512.svg icon-192.png icon-512.png \
         apple-touch-icon.png favicon-32x32.png favicon-16x16.png \
         favicon.ico offline.html; do
    [ -f "$MODPATH/$f" ] && mv -f "$MODPATH/$f" "$MODPATH/web/" 2>/dev/null
done

ui_print "  ✅ Files extracted"
BIN_DIR="$MODPATH/proxy"

# ============================================================
# [13] Post-extraction recovery re-apply
# ============================================================
if [ "$RECOVERY_MODE" = "1" ] && [ -n "$_INSTALLER_RECOVERY_SNAPSHOT" ] && \
   [ -d "$_INSTALLER_RECOVERY_SNAPSHOT" ]; then
    ui_print ""
    ui_print "- Re-applying recovery snapshot..."

    _reapplied=0
    for _f in $USER_FILES; do
        if [ -f "$_INSTALLER_RECOVERY_SNAPSHOT/$_f" ] && \
           [ -s "$_INSTALLER_RECOVERY_SNAPSHOT/$_f" ]; then
            copy_with_context "$_INSTALLER_RECOVERY_SNAPSHOT/$_f" "$BIN_DIR/$_f" && \
                _reapplied=$((_reapplied + 1))
        fi
    done

    if [ "$_reapplied" -ge "$_recovery_snapshotted" ]; then
        rm -rf "$_INSTALLER_RECOVERY_SNAPSHOT" 2>/dev/null
        _INSTALLER_RECOVERY_SNAPSHOT=""
        ui_print "  ✅ $_reapplied file(s) re-applied"
    else
        ui_print "  ⚠️ Partial re-apply ($_reapplied/$_recovery_snapshotted)"
        ui_print "     Snapshot preserved: $_INSTALLER_RECOVERY_SNAPSHOT"
    fi
fi

# ============================================================
# [14] Restore user files
# ============================================================
if [ "$RECOVERY_MODE" != "1" ] && [ -n "$FOUND_SOURCE" ]; then
    ui_print ""
    ui_print "- 🔄 Restoring user configuration..."

    if restore_user_files "$FOUND_SOURCE" "$BIN_DIR"; then
        _restored=0
        for _f in $USER_FILES; do
            [ -f "$BIN_DIR/$_f" ] && [ -s "$BIN_DIR/$_f" ] && \
                _restored=$((_restored + 1))
        done
        ui_print "  ✅ Restored $_restored file(s)"
    else
        ui_print "  ❌ Restore failed on critical file(s)"
        transaction_rollback 2>/dev/null || true
        abort "❌ SECURITY: critical config restore failed. Transaction rolled back."
    fi

    for _bl in blocklist.raw blocklist.txt; do
        _dst="$BIN_DIR/$_bl"
        [ -f "$_dst" ] && [ -s "$_dst" ] && continue
        if [ -f "$FOUND_SOURCE/$_bl" ] && [ -s "$FOUND_SOURCE/$_bl" ]; then
            copy_with_context "$FOUND_SOURCE/$_bl" "$_dst" 2>/dev/null && \
                ui_print "  ✅ Reused $_bl"
        fi
    done
fi

# ============================================================
# [15] Config migrations
# ============================================================
SOURCE_VERSION=""
[ -n "$FOUND_SOURCE" ] && SOURCE_VERSION=$(read_source_version "$FOUND_SOURCE" 2>/dev/null)

if [ -n "$SOURCE_VERSION" ] && [ "$RECOVERY_MODE" != "1" ]; then
    case "$SOURCE_VERSION" in
        "v1.0.0")
            ui_print "- 🔄 Migration: v1.0.0 → $MODULE_VERSION"
            if [ -f "$BIN_DIR/webui.conf" ] && \
               ! grep -q '^MEMORY_LIMIT_HINT=' "$BIN_DIR/webui.conf" 2>/dev/null; then
                {
                    echo ""
                    echo "# v1.2.0 addition"
                    echo "MEMORY_LIMIT_HINT=auto"
                } >> "$BIN_DIR/webui.conf"
            fi
            ;;
        "v1.1.0"|"v1.2.0"|"v1.3.0"|"v1.4.0"|"v1.5.0")
            ui_print "- 🔄 No migration needed ($SOURCE_VERSION)"
            ;;
    esac
fi

# ============================================================
# [16] Verify critical files
# ============================================================
MISSING=""
for _f in module.prop service.sh functions.sh boot-mini.sh \
         watchdog.sh post-fs-data.sh action.sh status.sh \
         uninstall.sh install_app.sh \
         lib/constants.sh lib/fallbacks.sh lib/process.sh \
         lib/http.sh lib/backup.sh lib/firewall.sh \
         proxy/dnscrypt-proxy.version proxy/app-apk.version \
         web/index.html web/dashboard.html web/manifest.json web/sw.js; do
    [ -f "$MODPATH/$_f" ] || MISSING="$MISSING $_f"
done

if [ -n "$MISSING" ]; then
    echo "❌ Missing:$MISSING" >> "$INSTALL_LOG"
    transaction_rollback 2>/dev/null || true
    abort "❌ Missing critical files:$MISSING"
fi

ui_print "  ✅ Critical files validated"

# ============================================================
# [17] Select binaries + copy
# ============================================================
case "$ARCH" in
    arm64-v8a*|aarch64*) DNS_BIN="dnscrypt-proxy-arm64";  WEB_BIN="dnscrypt-webui-arm64" ;;
    armeabi-v7a*|arm*)   DNS_BIN="dnscrypt-proxy-arm";    WEB_BIN="dnscrypt-webui-arm" ;;
    x86_64*)             DNS_BIN="dnscrypt-proxy-x86_64"; WEB_BIN="dnscrypt-webui-amd64" ;;
    i686*|x86*)          DNS_BIN="dnscrypt-proxy-x86";    WEB_BIN="dnscrypt-webui-386" ;;
    *)
        transaction_rollback 2>/dev/null || true
        abort "❌ Unsupported architecture: $ARCH"
        ;;
esac

if [ ! -f "$BIN_DIR/$DNS_BIN" ] || [ ! -f "$BIN_DIR/$WEB_BIN" ]; then
    transaction_rollback 2>/dev/null || true
    abort "❌ Binaries missing for $ARCH"
fi

cp -f "$BIN_DIR/$DNS_BIN" "$BIN_DIR/dnscrypt-proxy" || \
    { transaction_rollback 2>/dev/null; abort "❌ Failed to copy DNS binary"; }
cp -f "$BIN_DIR/$WEB_BIN" "$BIN_DIR/dnscrypt-webui" || \
    { transaction_rollback 2>/dev/null; abort "❌ Failed to copy WebUI binary"; }

rm -f "$BIN_DIR"/dnscrypt-proxy-* "$BIN_DIR"/dnscrypt-webui-* 2>/dev/null
ui_print "  ✅ Binaries installed"
ui_print ""

# ============================================================
# [18] Create run/ directory
# ============================================================
RUN_DIR_TARGET="$BIN_DIR/run"
mkdir -p "$RUN_DIR_TARGET" 2>/dev/null || \
    { transaction_rollback 2>/dev/null; abort "❌ Failed to create $RUN_DIR_TARGET"; }

chmod 0700 "$RUN_DIR_TARGET" 2>/dev/null
chown 0:0 "$RUN_DIR_TARGET" 2>/dev/null

_STATUS_KEPT=0
if [ -f /data/local/tmp/dnscrypt.status ] && \
   [ ! -f "$RUN_DIR_TARGET/dnscrypt.status" ]; then
    if cp -f /data/local/tmp/dnscrypt.status "$RUN_DIR_TARGET/dnscrypt.status" 2>/dev/null; then
        chmod 0600 "$RUN_DIR_TARGET/dnscrypt.status" 2>/dev/null
    else
        _STATUS_KEPT=1
    fi
fi

rm -f /data/local/tmp/dnscrypt.pid /data/local/tmp/webui.pid /data/local/tmp/watchdog.pid 2>/dev/null
[ "$_STATUS_KEPT" = "0" ] && rm -f /data/local/tmp/dnscrypt.status 2>/dev/null

ui_print "  ✅ run/ created (0700)"

# ============================================================
# [19] webui.conf with Port Guards
# ============================================================
TEMP_PORT="$DEFAULT_WEBUI_PORT"
TEMP_DASHBOARD_PORT="$DEFAULT_DASHBOARD_PORT"
TEMP_AUTO_DNS="1"
TEMP_AUTO_WEBUI="1"
TEMP_LOG_LEVEL="info"
TEMP_BIND_ADDR="127.0.0.1"

if [ -f "$BIN_DIR/webui.conf" ]; then
    _p=$(grep '^PORT=' "$BIN_DIR/webui.conf" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r ')
    TEMP_PORT=$(validate_port "$_p" "$DEFAULT_WEBUI_PORT")

    _p=$(grep '^DASHBOARD_PORT=' "$BIN_DIR/webui.conf" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r ')
    TEMP_DASHBOARD_PORT=$(validate_port "$_p" "$DEFAULT_DASHBOARD_PORT")

    _v=$(grep '^AUTO_RESTART_DNS=' "$BIN_DIR/webui.conf" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r ')
    case "$_v" in 0|1) TEMP_AUTO_DNS="$_v" ;; esac

    _v=$(grep '^AUTO_RESTART_WEBUI=' "$BIN_DIR/webui.conf" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r ')
    case "$_v" in 0|1) TEMP_AUTO_WEBUI="$_v" ;; esac

    _v=$(grep '^LOG_LEVEL=' "$BIN_DIR/webui.conf" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r ')
    case "$_v" in error|warn|info|debug) TEMP_LOG_LEVEL="$_v" ;; esac

    _v=$(grep '^BIND_ADDR=' "$BIN_DIR/webui.conf" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r ')
    [ -n "$_v" ] && TEMP_BIND_ADDR="$_v"
fi

if [ "$TEMP_PORT" = "$TEMP_DASHBOARD_PORT" ]; then
    if [ "$TEMP_PORT" = "$DEFAULT_DASHBOARD_PORT" ]; then
        TEMP_DASHBOARD_PORT="9092"
    else
        TEMP_DASHBOARD_PORT="$DEFAULT_DASHBOARD_PORT"
    fi
    ui_print "  ⚠️ Port collision resolved → dashboard=$TEMP_DASHBOARD_PORT"
fi

cat > "$BIN_DIR/webui.conf.tmp" << EOF
# ============================================================
# DNSCrypt WebUI & Dashboard Configuration
# $MODULE_VERSION
# ============================================================
#   1. No spaces around "="
#   2. No trailing comments on value lines
#   3. Ports 1-65535 (1024+ recommended), not 8080 (reserved for monitoring_ui)
#   4. PORT != DASHBOARD_PORT
# ============================================================

PORT=$TEMP_PORT
DASHBOARD_PORT=$TEMP_DASHBOARD_PORT

# 127.0.0.1 = local only (default)
# 0.0.0.0   = LAN (requires credentials)
BIND_ADDR=$TEMP_BIND_ADDR

AUTO_RESTART_DNS=$TEMP_AUTO_DNS
AUTO_RESTART_WEBUI=$TEMP_AUTO_WEBUI

# error | warn | info | debug
LOG_LEVEL=$TEMP_LOG_LEVEL
EOF

if [ ! -s "$BIN_DIR/webui.conf.tmp" ]; then
    rm -f "$BIN_DIR/webui.conf.tmp"
    transaction_rollback 2>/dev/null || true
    abort "❌ webui.conf write produced empty file"
fi

chmod 0600 "$BIN_DIR/webui.conf.tmp" 2>/dev/null
mv -f "$BIN_DIR/webui.conf.tmp" "$BIN_DIR/webui.conf" || \
    { transaction_rollback 2>/dev/null; abort "❌ Failed to finalize webui.conf"; }

ui_print "  ✅ webui.conf (WebUI: $TEMP_PORT, Dashboard: $TEMP_DASHBOARD_PORT)"

# ============================================================
# [20] Default config files
# ============================================================
[ ! -f "$BIN_DIR/selected_profile.txt" ] && printf 'pro\n' > "$BIN_DIR/selected_profile.txt"
[ ! -f "$BIN_DIR/blocklist.txt" ] && : > "$BIN_DIR/blocklist.txt"
[ ! -f "$BIN_DIR/blocklist.raw" ] && : > "$BIN_DIR/blocklist.raw"
[ ! -f "$BIN_DIR/allowlist.txt" ] && : > "$BIN_DIR/allowlist.txt"
[ ! -f "$BIN_DIR/denylist.txt" ] && : > "$BIN_DIR/denylist.txt"
[ ! -f "$BIN_DIR/blocked-ips.txt" ] && cat > "$BIN_DIR/blocked-ips.txt" << 'EOF'
# Generated on installation
0.0.0.0
127.0.0.1
EOF

# ============================================================
# [21] Credentials
# ============================================================
ui_print ""
ui_print "- 🔐 Generating secure credentials..."

TOML_FILE="$BIN_DIR/dnscrypt-proxy.toml"

CUR_USER=""
CUR_PASS=""
if [ -f "$TOML_FILE" ]; then
    _creds=$(read_toml_credentials 2>/dev/null)
    CUR_USER=$(printf '%s' "$_creds" | sed -n '1p')
    CUR_PASS=$(printf '%s' "$_creds" | sed -n '2p')
fi

NEED_NEW_CREDS=0
if [ -z "$CUR_USER" ] || [ -z "$CUR_PASS" ]; then
    NEED_NEW_CREDS=1
elif [ "$CUR_USER" = "admin" ] && [ "$CUR_PASS" = "admin" ]; then
    NEED_NEW_CREDS=1
    ui_print "  ⚠️ Default admin/admin detected — regenerating"
fi

if [ "$NEED_NEW_CREDS" = "1" ]; then
    NEW_USER=""
    if [ -r /dev/urandom ]; then
        NEW_USER="admin_$(tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 8)"
    fi
    if [ -z "$NEW_USER" ] || [ "$NEW_USER" = "admin_" ] || [ "${#NEW_USER}" -lt 12 ]; then
        NEW_USER="admin_$(date +%s | tail -c 9)"
    fi

    NEW_PASS=""
    _attempt=0
    _valid=0
    while [ "$_attempt" -lt 3 ]; do
        _attempt=$((_attempt + 1))
        if [ ! -r /dev/urandom ]; then
            if command -v sha256sum >/dev/null 2>&1; then
                NEW_PASS="X$(printf '%s-%s-%s-%s-%s' \
                    "$(date +%s%N 2>/dev/null || date +%s)" \
                    "$$" "$RANDOM" "$RANDOM" "$RANDOM" \
                    | sha256sum 2>/dev/null | awk '{print $1}')"
            else
                NEW_PASS="Xx$(date +%s%N 2>/dev/null || date +%s)_$$_$RANDOM$RANDOM"
            fi
        else
            NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 32)
        fi

        _valid=1
        [ "${#NEW_PASS}" -ge 24 ] || _valid=0
        case "$NEW_PASS" in *[A-Z]*) ;; *) _valid=0 ;; esac
        case "$NEW_PASS" in *[a-z]*) ;; *) _valid=0 ;; esac
        case "$NEW_PASS" in *[0-9]*) ;; *) _valid=0 ;; esac
        [ "$_valid" = "1" ] && break
    done

    if [ "$_valid" != "1" ]; then
        transaction_rollback 2>/dev/null || true
        abort "❌ SECURITY: could not generate a password of required strength"
    fi

    cp -f "$TOML_FILE" "$TOML_FILE.bak" 2>/dev/null
    _CREDS_TMP="${TOML_FILE}.tmp.$$"
    if ! awk -v u="$NEW_USER" -v p="$NEW_PASS" -v q="'" '
        BEGIN { in_mu = 0 }
        /^[[:space:]]*\[/ {
            hdr = $0
            sub(/^[[:space:]]*\[/, "", hdr)
            sub(/\].*$/, "", hdr)
            gsub(/[[:space:]]/, "", hdr)
            in_mu = (hdr == "monitoring_ui")
            print
            next
        }
        in_mu && /^[[:space:]]*username[[:space:]]*=/ {
            print "  username = " q u q
            next
        }
        in_mu && /^[[:space:]]*password[[:space:]]*=/ {
            print "  password = " q p q
            next
        }
        { print }
    ' "$TOML_FILE" > "$_CREDS_TMP" 2>/dev/null; then
        rm -f "$_CREDS_TMP" "$TOML_FILE.bak"
        transaction_rollback 2>/dev/null || true
        abort "❌ SECURITY: TOML credential rewrite failed"
    fi

    if ! mv -f "$_CREDS_TMP" "$TOML_FILE" 2>/dev/null; then
        rm -f "$_CREDS_TMP" "$TOML_FILE.bak"
        transaction_rollback 2>/dev/null || true
        abort "❌ SECURITY: TOML credential write failed"
    fi

    _verify=$(read_toml_credentials 2>/dev/null)
    VU=$(printf '%s' "$_verify" | sed -n '1p')
    VP=$(printf '%s' "$_verify" | sed -n '2p')

    if [ "$VU" != "$NEW_USER" ] || [ "$VP" != "$NEW_PASS" ]; then
        [ -f "$TOML_FILE.bak" ] && cp -f "$TOML_FILE.bak" "$TOML_FILE" 2>/dev/null
        rm -f "$TOML_FILE.bak"
        transaction_rollback 2>/dev/null || true
        abort "❌ SECURITY: TOML credential write failed. Rolled back."
    fi
    rm -f "$TOML_FILE.bak"

    (
        umask 077
        _CRED_TMP="${CRED_FILE}.tmp.$$"
        _CRED_TMP_ALT="/data/local/tmp/.cred.$$.tmp"

        {
            cat << CREDEOF
# ============================================================
# DNSCrypt Smart Filter – Login Credentials
# Generated: $(date)
# Version: $MODULE_VERSION
# ============================================================

Username: $NEW_USER
Password: $NEW_PASS

⚠️ Keep this data in a safe place.
CREDEOF
        } > "$_CRED_TMP_ALT" 2>/dev/null || exit 1

        chmod 0600 "$_CRED_TMP_ALT" 2>/dev/null

        if mv -f "$_CRED_TMP_ALT" "$CRED_FILE" 2>/dev/null; then
            chmod 0600 "$CRED_FILE" 2>/dev/null
            chown 0:0 "$CRED_FILE" 2>/dev/null
            exit 0
        fi
        rm -f "$_CRED_TMP_ALT" 2>/dev/null
        exit 1
    ) || {
        ui_print "  ⚠️ Could not write $CRED_FILE (may be transient)"
    }

    ui_print ""
    ui_print "╔══════════════════════════════════════════╗"
    ui_print "║  🔐 Login Credentials                    ║"
    ui_print "╚══════════════════════════════════════════╝"
    ui_print "  👤 Username: $NEW_USER"
    ui_print "  🔑 Password: $NEW_PASS"
    ui_print ""
    ui_print "📄 Saved copy: $CRED_FILE (0600)"
    ui_print ""
else
    _cred_preview=$(printf '%.4s' "$CUR_PASS")
    ui_print "  ℹ️  Existing credentials preserved"
    ui_print "      👤 Username: $CUR_USER"
    ui_print "      🔑 Password: ${_cred_preview}… (unchanged)"
fi

# ============================================================
# [22] Permissions
# ============================================================
ui_print "- 🔒 Setting permissions..."

chmod 0755 "$BIN_DIR/dnscrypt-proxy" "$BIN_DIR/dnscrypt-webui" 2>/dev/null
for s in service.sh post-fs-data.sh action.sh status.sh \
         uninstall.sh functions.sh boot-mini.sh watchdog.sh install_app.sh; do
    [ -f "$MODPATH/$s" ] && chmod 0755 "$MODPATH/$s"
done

for lf in "$MODPATH"/lib/*.sh; do
    [ -f "$lf" ] && chmod 0644 "$lf"
done

for f in index.html dashboard.html manifest.json sw.js \
         icon-192.svg icon-512.svg offline.html; do
    [ -f "$MODPATH/web/$f" ] && chmod 0644 "$MODPATH/web/$f"
done
for f in icon-192.png icon-512.png apple-touch-icon.png \
         favicon-32x32.png favicon-16x16.png favicon.ico; do
    [ -f "$MODPATH/web/$f" ] && chmod 0644 "$MODPATH/web/$f"
done

[ -f "$BIN_DIR/webui.conf" ] && chmod 0600 "$BIN_DIR/webui.conf"
[ -f "$BIN_DIR/dnscrypt-proxy.toml" ] && chmod 0600 "$BIN_DIR/dnscrypt-proxy.toml"
chmod 0700 "$RUN_DIR_TARGET" 2>/dev/null
chown 0:0 "$RUN_DIR_TARGET" 2>/dev/null

# ============================================================
# [23] Watchdog token
# ============================================================
WATCHDOG_TOKEN_FILE="$RUN_DIR_TARGET/.watchdog_token"
TOKEN=""
if [ -r /dev/urandom ]; then
    TOKEN=$(tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 64)
fi
if [ -z "$TOKEN" ] || [ "${#TOKEN}" -lt 32 ]; then
    if command -v sha256sum >/dev/null 2>&1; then
        TOKEN=$(printf '%s-%s-%s' \
            "$(date +%s%N 2>/dev/null || date +%s)" "$$" "$RANDOM" \
            | sha256sum 2>/dev/null | awk '{print $1}')
    fi
fi

if [ -n "$TOKEN" ] && [ "${#TOKEN}" -ge 32 ]; then
    (
        umask 077
        _TTMP="${WATCHDOG_TOKEN_FILE}.tmp.$$"
        printf '%s' "$TOKEN" > "$_TTMP" 2>/dev/null || exit 1
        chmod 0600 "$_TTMP" 2>/dev/null
        mv -f "$_TTMP" "$WATCHDOG_TOKEN_FILE" 2>/dev/null || { rm -f "$_TTMP"; exit 1; }
        chown 0:0 "$WATCHDOG_TOKEN_FILE" 2>/dev/null
    ) && echo "watchdog token written" >> "$INSTALL_LOG" \
      || echo "watchdog token write failed" >> "$INSTALL_LOG"
fi

# ============================================================
# [24] Commit transaction + mark .last_stable
# ============================================================
PERSISTENT_BACKUP_OK=0
if [ "$RECOVERY_MODE" != "1" ] && [ -n "$FOUND_SOURCE" ]; then
    ui_print "- 💾 Creating persistent backup..."

    if backup_create "$FOUND_SOURCE" "" "$MODULE_VERSION" "$FOUND_SOURCE"; then
        PERSISTENT_BACKUP_OK=1
        _backup_name=$(basename "$BACKUP_CREATED_PATH")
        ui_print "  ✅ Backup: $BACKUP_CREATED_PATH"
        echo "backup created: $BACKUP_CREATED_PATH" >> "$INSTALL_LOG"

        if verify_backup_integrity "$BACKUP_CREATED_PATH" 0; then
            ui_print "  ✅ Integrity verified (SHA256)"
        else
            ui_print "  ⚠️ Integrity warnings (advisory)"
        fi

        if [ "${TXN_ACTIVE:-0}" = "1" ]; then
            transaction_commit && ui_print "- ✅ Transaction committed"
        fi

        mark_last_stable "$_backup_name" && \
            echo "last_stable: $_backup_name" >> "$INSTALL_LOG"

        rotate_backups "$BACKUP_ROTATION_KEEP"
        ui_print "  ✅ Rotation complete (keep $BACKUP_ROTATION_KEEP)"
    else
        ui_print "  ⚠️ Backup skipped (source empty or disk full)"
    fi
fi

# ============================================================
# [25] Upgrade history
# ============================================================
if [ -n "$SOURCE_VERSION" ] || [ -n "$FOUND_SOURCE" ]; then
    _hist="$PERSISTENT_BACKUP/.upgrade_history.txt"
    mkdir -p "$PERSISTENT_BACKUP" 2>/dev/null
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $SOURCE_VERSION → $MODULE_VERSION | source=$FOUND_SOURCE | files=$FOUND_FILE_COUNT" \
        >> "$_hist" 2>/dev/null
    chmod 0644 "$_hist" 2>/dev/null
fi

# ============================================================
# [26] README for backup directory (first install only)
# ============================================================
if [ ! -f "$PERSISTENT_BACKUP/README.md" ]; then
    cat > "$PERSISTENT_BACKUP/README.md" << 'README'
# DNSCrypt Smart Filter — Backup Directory

## Backed up files

- webui.conf             — WebUI + Dashboard ports
- dnscrypt-proxy.toml    — engine config + credentials
- selected_profile.txt   — active blocklist profile
- allowlist.txt          — custom allowlist
- denylist.txt           — custom denylist

## Structure

- current/                 — latest snapshot
- <ts>-<ver>-<pid>/        — per-install snapshot
- <ts>-manual-<pid>/       — manual backup
- <ts>-auto-<pid>/         — 24h auto backup
- .last_stable             — pointer to the last good snapshot
- apk/                     — companion APK mirror

## Manual restore

Copy desired files from a snapshot back to
/data/adb/modules/dnscrypt-proxy-webui/proxy/ then reboot.

## Emergency recovery

    su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
    su -c "reboot"

The installer will restore .last_stable.
README
    chmod 0644 "$PERSISTENT_BACKUP/README.md" 2>/dev/null
fi

# ============================================================
# [27] APK mirror (best-effort)
# ============================================================
APK_SRC="$MODPATH/web/app-debug.apk"
SHA_SRC="$MODPATH/web/app-debug.apk.sha256"
_apk_mirrored=0
_sha_mirrored=0

if [ -f "$APK_SRC" ] && [ -s "$APK_SRC" ]; then
    if mkdir -p "$APK_MIRROR_DIR" 2>/dev/null; then
        cp -f "$APK_SRC" "$APK_MIRROR_DIR/app-debug.apk" 2>/dev/null && \
            { chmod 0644 "$APK_MIRROR_DIR/app-debug.apk"; _apk_mirrored=1; }
        [ -f "$SHA_SRC" ] && [ -s "$SHA_SRC" ] && \
            cp -f "$SHA_SRC" "$APK_MIRROR_DIR/app-debug.apk.sha256" 2>/dev/null && \
            { chmod 0644 "$APK_MIRROR_DIR/app-debug.apk.sha256"; _sha_mirrored=1; }
    fi
fi

# ============================================================
# [28] Lock stale modules with lower version
# ============================================================
if [ -n "$FOUND_SOURCE" ]; then
    _vmaj=$(printf '%s' "${MODULE_VERSION#v}" | cut -d. -f1 | tr -dc '0-9')
    _vmin=$(printf '%s' "${MODULE_VERSION#v}" | cut -d. -f2 | tr -dc '0-9')
    _vpat=$(printf '%s' "${MODULE_VERSION#v}" | cut -d. -f3 | tr -dc '0-9')
    _new_score=$(( ${_vmaj:-0} * 10000 + ${_vmin:-0} * 100 + ${_vpat:-0} ))
    _disabled=0

    for _root in /data/adb/modules /data/adb/modules_update \
                 /data/adb/ksu/modules /data/adb/ap/modules; do
        [ -d "$_root" ] || continue
        for _m in "$_root"/*; do
            [ -d "$_m" ] && [ "$_m" != "$MODPATH" ] || continue
            [ -f "$_m/module.prop" ] || continue
            _mid=$(grep '^id=' "$_m/module.prop" | head -1 | cut -d= -f2- | tr -d '\r ')
            [ "$_mid" = "$MODULE_ID" ] || continue
            _mver=$(grep '^version=' "$_m/module.prop" | head -1 | cut -d= -f2- | tr -d 'v\r ')
            _mmaj=$(printf '%s' "$_mver" | cut -d. -f1 | tr -dc '0-9')
            _mmin=$(printf '%s' "$_mver" | cut -d. -f2 | tr -dc '0-9')
            _mpat=$(printf '%s' "$_mver" | cut -d. -f3 | tr -dc '0-9')
            _mscore=$(( ${_mmaj:-0} * 10000 + ${_mmin:-0} * 100 + ${_mpat:-0} ))
            if [ "$_mscore" -lt "$_new_score" ] && [ ! -f "$_m/disable" ]; then
                touch "$_m/disable" 2>/dev/null && _disabled=$((_disabled + 1))
            fi
        done
    done
    [ "$_disabled" -gt 0 ] && ui_print "  🔒 Locked $_disabled stale module(s)"
fi

# ============================================================
# [29] Final summary
# ============================================================
SELECTED_PROFILE="pro"
[ -f "$BIN_DIR/selected_profile.txt" ] && {
    _sp=$(cat "$BIN_DIR/selected_profile.txt" 2>/dev/null | tr -d '\r\n ')
    case "$_sp" in light|normal|pro|proplus|ultimate) SELECTED_PROFILE="$_sp" ;; esac
}
case "$SELECTED_PROFILE" in
    light)    EXPECTED_MEM="80 MB"  ;;
    normal)   EXPECTED_MEM="100 MB" ;;
    pro)      EXPECTED_MEM="120 MB" ;;
    proplus)  EXPECTED_MEM="160 MB" ;;
    ultimate) EXPECTED_MEM="220 MB" ;;
    *)        EXPECTED_MEM="80 MB"  ;;
esac

ui_print ""
ui_print "╔══════════════════════════════════════════╗"
ui_print "║  ✅ Installation Complete                ║"
printf "║      %-32s ║\n" "$MODULE_VERSION"
ui_print "╚══════════════════════════════════════════╝"
ui_print ""

if [ "$RECOVERY_MODE" = "1" ]; then
    ui_print "  🚨 Recovery mode: YES ($_recovery_restored files)"
elif [ -n "$FOUND_SOURCE" ]; then
    ui_print "  📊 Upgrade: YES"
    ui_print "  🔍 Source: $FOUND_SOURCE"
else
    ui_print "  🆕 Fresh installation"
fi

ui_print "  📦 Root: $ROOT_SOLUTION"
ui_print "  🌐 WebUI: http://127.0.0.1:$TEMP_PORT"
ui_print "  📈 Dashboard: http://127.0.0.1:$TEMP_DASHBOARD_PORT"
ui_print "  🔌 Bind: $TEMP_BIND_ADDR"
ui_print "  🧠 Memory: ~$EXPECTED_MEM ($SELECTED_PROFILE)"

if [ "$PERSISTENT_BACKUP_OK" = "1" ]; then
    ui_print "  💾 Backup: $(basename "$BACKUP_CREATED_PATH")"
    ui_print "     Last stable: $(read_last_stable 2>/dev/null)"
fi

[ "$_apk_mirrored" = "1" ] && ui_print "  📱 APK mirror: $APK_MIRROR_DIR"
[ "$_sha_mirrored" = "1" ] && ui_print "  🔐 SHA256: present"

ui_print ""
ui_print "  ℹ️  Next steps:"
ui_print "    1. Reboot your device"
ui_print "    2. Open WebUI and log in with the credentials above"
ui_print "    3. Choose a blocklist profile and Apply"

if [ "$KILLED" -gt 0 ]; then
    ui_print ""
    ui_print "╔══════════════════════════════════════════╗"
    ui_print "║  ⚠️  REBOOT REQUIRED                      ║"
    ui_print "╚══════════════════════════════════════════╝"
    ui_print ""
    ui_print "  The DNS engine was stopped for a clean"
    ui_print "  upgrade. Internet will not work correctly"
    ui_print "  until you REBOOT."
fi

echo "✅ Installation complete ($MODULE_VERSION)" >> "$INSTALL_LOG"

_INSTALLER_DONE=1
exit 0