#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — install_app.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Install / query / uninstall the companion Android app
# (web/app-debug.apk) via `pm install`.
#
# Called by main.go as a subprocess. Modes:
#   (no args)      Install            → JSON on stdout
#   --status       Report state       → JSON on stdout
#   --uninstall    Uninstall          → JSON on stdout
#   --version      Show version       → text
#   --help         Show help          → text
#
# Exit codes:
#   0   = success
#   1   = APK missing / corrupt / hash mismatch
#   2   = all install strategies failed
#   3   = invalid arguments
#   4   = not installed (--uninstall / --status)
#   130 = interrupted (SIGINT)
#   143 = terminated (SIGTERM)
#
# Timeout hierarchy (must stay in sync with main.go):
#   Client (web/index.html) : 120 s
#   Server (main.go)        :  90 s
#   Cascade deadline (§[4]) :  75 s
#   Per-strategy            :  20 s
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module root
# ============================================================
_self_dir="${0%/*}"
[ "$_self_dir" = "." ] && _self_dir="$(pwd)"
[ -z "$_self_dir" ] && _self_dir="."

if [ -f "$_self_dir/module.prop" ]; then
    MODDIR="$_self_dir"
elif [ -f "$_self_dir/../module.prop" ]; then
    MODDIR="$(cd "$_self_dir/.." && pwd)"
else
    MODDIR=""
    for _cand in \
        /data/adb/modules/dnscrypt-proxy-webui \
        /data/adb/modules_update/dnscrypt-proxy-webui \
        /data/adb/ksu/modules/dnscrypt-proxy-webui \
        /data/adb/ap/modules/dnscrypt-proxy-webui; do
        [ -f "$_cand/module.prop" ] && { MODDIR="$_cand"; break; }
    done
    [ -z "$MODDIR" ] && MODDIR="$_self_dir"
fi
unset _self_dir _cand

# ============================================================
# [2] Constants
# ============================================================
SCRIPT_VERSION="v1.6.0"
[ -f "$MODDIR/module.prop" ] && {
    _v=$(grep '^version=' "$MODDIR/module.prop" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r ')
    [ -n "$_v" ] && SCRIPT_VERSION="$_v"
}

APK_PATH="$MODDIR/web/app-debug.apk"
SHA_PATH="$MODDIR/web/app-debug.apk.sha256"
APP_VERSION_FILE="$MODDIR/proxy/app-apk.version"
LOG_FILE="/data/local/tmp/dnscrypt_main.log"

MIN_APK_BYTES=102400
SPACE_MULTIPLIER=3

CASCADE_DEADLINE_SECONDS=75
STRATEGY_TIMEOUT=20
MIN_STRATEGY_BUDGET=3

COMPANION_PKG_CANDIDATES="com.gasciljh.dnsproxy.debug com.gasciljh.dnsproxy com.gasciljh.dnscrypt_proxy"
STAGING_APK="/data/local/tmp/dnscrypt-companion.apk"

# ============================================================
# [3] Argument parsing
# ============================================================
MODE="install"
case "${1:-}" in
    --version) echo "install_app.sh: $SCRIPT_VERSION"; exit 0 ;;
    --help|-h)
        cat << 'EOF'
DNSCrypt Smart Filter – install_app.sh

Usage:
  install_app.sh                Install the companion app
  install_app.sh --status       Report current state (JSON)
  install_app.sh --uninstall    Uninstall the companion app
  install_app.sh --version      Show script version
  install_app.sh --help         Show this help
EOF
        exit 0
        ;;
    --status)    MODE="status" ;;
    --uninstall) MODE="uninstall" ;;
    "")          MODE="install" ;;
    *)
        echo "{\"status\":\"error\",\"message\":\"Unknown argument: $1\"}"
        exit 3
        ;;
esac

# ============================================================
# [4] Cascade deadline
# ============================================================
_CASCADE_START=$(date +%s 2>/dev/null)
case "$_CASCADE_START" in ''|*[!0-9]*) _CASCADE_START=0 ;; esac
if [ "$_CASCADE_START" -le 0 ]; then
    _CASCADE_DEADLINE=9999999999
else
    _CASCADE_DEADLINE=$((_CASCADE_START + CASCADE_DEADLINE_SECONDS))
fi
unset _CASCADE_START

# ============================================================
# [5] Logging
# ============================================================
_log_line_count=0
log_msg() {
    [ -d /data/local/tmp ] || return 0
    _log_line_count=$((_log_line_count + 1))
    {
        printf '%s - [install_app] %s\n' \
            "$(date +'%Y-%m-%d %H:%M:%S')" "$1"
    } >> "$LOG_FILE" 2>/dev/null
}

# ============================================================
# [6] JSON helpers
# ============================================================
_json_escape() {
    printf '%s' "$1" \
        | sed 's/\\/\\\\/g; s/"/\\"/g' \
        | sed 's/\t/\\t/g; s/\r/\\r/g' \
        | awk 'BEGIN{ORS=""} {if (NR>1) printf "\\n"; printf "%s", $0}' \
        | tr -d '\000-\010\013\014\016-\037'
}

_emit_json() {
    local exit_code="$1" status="$2" action="$3"
    shift 3

    local json
    json="{\"status\":\"$(_json_escape "$status")\""
    json="$json,\"action\":\"$(_json_escape "$action")\""

    local kv prefix key value
    for kv in "$@"; do
        prefix="${kv%%:*}"
        kv="${kv#*:}"
        key="${kv%%=*}"
        value="${kv#*=}"

        case "$prefix" in
            n)
                case "$value" in
                    ''|*[!0-9]*)
                        json="$json,\"$(_json_escape "$key")\":\"$(_json_escape "$value")\""
                        ;;
                    *)
                        json="$json,\"$(_json_escape "$key")\":$value"
                        ;;
                esac
                ;;
            b)
                case "$value" in
                    true|false)
                        json="$json,\"$(_json_escape "$key")\":$value"
                        ;;
                    *)
                        json="$json,\"$(_json_escape "$key")\":\"$(_json_escape "$value")\""
                        ;;
                esac
                ;;
            s|*)
                json="$json,\"$(_json_escape "$key")\":\"$(_json_escape "$value")\""
                ;;
        esac
    done

    printf '%s}\n' "$json"
    exit "$exit_code"
}

# ============================================================
# [7] Timeout wrapper
# ============================================================
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout"
elif command -v busybox >/dev/null 2>&1 \
     && busybox --list 2>/dev/null | grep -q '^timeout$'; then
    TIMEOUT_CMD="busybox timeout"
fi

_run_pm() {
    local _now _remaining
    _now=$(date +%s 2>/dev/null)
    case "$_now" in ''|*[!0-9]*) _now=0 ;; esac
    _remaining=$(( _CASCADE_DEADLINE - _now ))

    [ "$_remaining" -lt "$MIN_STRATEGY_BUDGET" ] && return 124
    [ "$_remaining" -gt "$STRATEGY_TIMEOUT" ] && _remaining="$STRATEGY_TIMEOUT"

    if [ -n "$TIMEOUT_CMD" ]; then
        # shellcheck disable=SC2086
        $TIMEOUT_CMD "$_remaining" "$@"
    else
        "$@"
    fi
}

# ============================================================
# [8] Package detection
# ============================================================
COMPANION_PKG="com.gasciljh.dnsproxy.debug"

_detect_and_update_pkg() {
    local _p
    for _p in $COMPANION_PKG_CANDIDATES; do
        if dumpsys package "$_p" 2>/dev/null | grep -q 'versionName='; then
            COMPANION_PKG="$_p"
            return 0
        fi
    done
    return 1
}

_pkg_version_name() {
    local out
    out=$(dumpsys package "$COMPANION_PKG" 2>/dev/null | grep -m1 'versionName=' || true)
    case "$out" in
        *versionName=*) printf '%s' "${out#*versionName=}" | tr -d '\r' ;;
        *)              printf 'unknown' ;;
    esac
}

_wait_for_install() {
    local _timeout="${1:-15}"
    local _deadline="${2:-0}"
    local _i=0
    local _vname

    while [ "$_i" -lt "$_timeout" ]; do
        if [ "$_deadline" -gt 0 ] 2>/dev/null; then
            local _now
            _now=$(date +%s 2>/dev/null)
            case "$_now" in ''|*[!0-9]*) _now=0 ;; esac
            if [ "$_now" -gt 0 ] && [ "$_now" -ge "$_deadline" ]; then
                return 1
            fi
        fi

        if _detect_and_update_pkg; then
            _vname=$(_pkg_version_name)
            if [ -z "$_vname" ] || [ "$_vname" = "unknown" ] || [ "$_vname" = "$APP_VERSION" ]; then
                return 0
            fi
        fi
        sleep 1
        _i=$((_i + 1))
    done
    return 1
}

# ============================================================
# [9] Expected app version
# ============================================================
read_app_version() {
    if [ -f "$APP_VERSION_FILE" ]; then
        local v
        v=$(tr -d '\r\n' < "$APP_VERSION_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -n "$v" ] && { printf '%s' "$v"; return 0; }
    fi
    printf 'unknown'
}
APP_VERSION=$(read_app_version)

# ============================================================
# [10] MODE: --status
# ============================================================
if [ "$MODE" = "status" ]; then
    if _detect_and_update_pkg; then
        _vname=$(_pkg_version_name)
        _emit_json 0 "ok" "status" \
            "b:installed=true" \
            "s:package=$COMPANION_PKG" \
            "s:version_name=$_vname" \
            "s:expected_version=$APP_VERSION"
    else
        _emit_json 4 "ok" "status" \
            "b:installed=false" \
            "s:package=$COMPANION_PKG" \
            "s:expected_version=$APP_VERSION"
    fi
fi

# ============================================================
# [11] MODE: --uninstall
# ============================================================
if [ "$MODE" = "uninstall" ]; then
    if ! _detect_and_update_pkg; then
        _emit_json 4 "ok" "uninstall" \
            "s:package=$COMPANION_PKG" \
            "s:message=not_installed"
    fi

    if _out=$(_run_pm pm uninstall "$COMPANION_PKG" 2>&1); then
        _emit_json 0 "ok" "uninstall" \
            "s:package=$COMPANION_PKG" \
            "s:message=uninstalled"
    else
        _rc=$?
        _emit_json 2 "error" "uninstall" \
            "s:package=$COMPANION_PKG" \
            "s:message=uninstall_failed" \
            "n:rc=$_rc" \
            "s:details=$_out"
    fi
fi

# ============================================================
# [12] Install — pre-flight checks
# ============================================================
log_msg "INSTALL: starting (version=$APP_VERSION, moddir=$MODDIR)"

[ ! -f "$APK_PATH" ] && \
    _emit_json 1 "error" "install" \
        "s:reason=apk_not_found" \
        "s:message_ar=الملف المرافق للتطبيق غير موجود في الوحدة" \
        "s:message_en=Companion APK not found in the module"

[ ! -s "$APK_PATH" ] && \
    _emit_json 1 "error" "install" \
        "s:reason=apk_empty" \
        "s:message_ar=الملف المرافق فارغ — أعد تثبيت الوحدة" \
        "s:message_en=Companion APK is empty — reinstall the module"

APK_SIZE=$(wc -c < "$APK_PATH" 2>/dev/null | tr -d ' ')
case "$APK_SIZE" in ''|*[!0-9]*) APK_SIZE=0 ;; esac

[ "$APK_SIZE" -lt "$MIN_APK_BYTES" ] && \
    _emit_json 1 "error" "install" \
        "s:reason=apk_too_small" \
        "n:size=$APK_SIZE" \
        "s:message_ar=الملف المرافق صغير جداً — قد يكون تالفاً" \
        "s:message_en=Companion APK is suspiciously small — likely corrupt"

if command -v od >/dev/null 2>&1; then
    _magic=$(od -An -N2 -tx1 "$APK_PATH" 2>/dev/null | tr -d ' \n')
    [ "$_magic" != "504b" ] && \
        _emit_json 1 "error" "install" \
            "s:reason=apk_not_zip" \
            "s:message_ar=الملف المرافق ليس APK صالح" \
            "s:message_en=Companion APK is not a valid ZIP archive"
fi

SHA_VERIFIED=0
if [ -f "$SHA_PATH" ] && command -v sha256sum >/dev/null 2>&1; then
    _expected=$(awk '{print $1}' "$SHA_PATH" 2>/dev/null | head -n1 | tr -d '\r\n ')
    _actual=$(sha256sum "$APK_PATH" 2>/dev/null | awk '{print $1}')
    if [ -n "$_expected" ] && [ -n "$_actual" ]; then
        [ "$_expected" != "$_actual" ] && \
            _emit_json 1 "error" "install" \
                "s:reason=sha_mismatch" \
                "s:message_ar=فشل التحقق من السلامة — أعد تثبيت الوحدة" \
                "s:message_en=Integrity check failed — reinstall the module"
        SHA_VERIFIED=1
    fi
fi

if command -v df >/dev/null 2>&1; then
    _free_kb=$(df -k /data 2>/dev/null | awk 'NR==2 {print $4}')
    case "$_free_kb" in ''|*[!0-9]*) _free_kb=0 ;; esac
    _needed_kb=$(( (APK_SIZE / 1024) * SPACE_MULTIPLIER ))
    if [ "$_free_kb" -gt 0 ] && [ "$_free_kb" -lt "$_needed_kb" ]; then
        _emit_json 1 "error" "install" \
            "s:reason=insufficient_storage" \
            "n:free_kb=$_free_kb" \
            "n:needed_kb=$_needed_kb" \
            "s:message_ar=المساحة غير كافية" \
            "s:message_en=Insufficient storage"
    fi
fi

# ============================================================
# [13] Cleanup infrastructure + traps
# ============================================================
_STAGED_OK=0
_CLEANED_UP=0
_VERIFIER_RESTORE=0
_VERIFIER_ORIG=""
_ACTIVE_SESSION=""

_read_verifier_state() {
    local _try=0 _raw=""
    while [ "$_try" -lt 5 ]; do
        _raw=$(settings get global package_verifier_enable 2>/dev/null)
        case "$_raw" in
            '') ;;
            'null') printf 'null'; return 0 ;;
            *) printf '%s' "$_raw" | tr -d '\r\n '; return 0 ;;
        esac
        sleep 1
        _try=$((_try + 1))
    done
    printf ''
    return 1
}

_cleanup_app() {
    [ "$_CLEANED_UP" = "1" ] && return 0
    _CLEANED_UP=1

    if [ -n "$_ACTIVE_SESSION" ]; then
        _run_pm pm install-abandon "$_ACTIVE_SESSION" >/dev/null 2>&1 || true
        _ACTIVE_SESSION=""
    fi

    [ "$_STAGED_OK" = "1" ] && [ -f "$STAGING_APK" ] && rm -f "$STAGING_APK" 2>/dev/null

    case "$_VERIFIER_RESTORE" in
        1)
            case "$_VERIFIER_ORIG" in
                "0"|"1")
                    settings put global package_verifier_enable "$_VERIFIER_ORIG" 2>/dev/null
                    ;;
                "null")
                    settings delete global package_verifier_enable 2>/dev/null
                    ;;
            esac
            ;;
    esac
    return 0
}

trap '_cleanup_app' EXIT
trap '_cleanup_app; exit 130' INT
trap '_cleanup_app; exit 143' TERM

# ============================================================
# [14] Disable Play Protect verifier
# ============================================================
_VERIFIER_ORIG=$(_read_verifier_state 2>/dev/null)

case "$_VERIFIER_ORIG" in
    "1"|"null")
        if settings put global package_verifier_enable 0 2>/dev/null; then
            _VERIFIER_RESTORE=1
            log_msg "INSTALL: verifier disabled (will restore)"
        fi
        ;;
    *)
        _VERIFIER_RESTORE=0
        _VERIFIER_ORIG=""
        ;;
esac

# ============================================================
# [15] Stage APK to /data/local/tmp
# ============================================================
if cp -f "$APK_PATH" "$STAGING_APK" 2>/dev/null; then
    chmod 0644 "$STAGING_APK" 2>/dev/null
    APK_PATH="$STAGING_APK"
    _STAGED_OK=1
fi

# ============================================================
# [16] Unified strategy cascade
# ============================================================
STRATEGY_USED=0
STRATEGY_OUTPUT=""

_run_strategy() {
    local _sid _rc _vname
    case "$1" in
        1)
            STRATEGY_OUTPUT=$(_run_pm pm install -r --user 0 "$APK_PATH" 2>&1)
            _rc=$?
            ;;
        2)
            STRATEGY_OUTPUT=$(_run_pm pm install -r --user 0 -i com.android.shell "$APK_PATH" 2>&1)
            _rc=$?
            ;;
        3)
            _sid=$(_run_pm pm install-create -r --user 0 2>/dev/null | grep -oE '\[[0-9]+\]' | tr -d '[]')
            if [ -z "$_sid" ]; then
                STRATEGY_OUTPUT="install-create failed"
                return 1
            fi
            _ACTIVE_SESSION="$_sid"

            if ! _run_pm pm install-write "$_sid" base "$APK_PATH" >/dev/null 2>&1; then
                STRATEGY_OUTPUT="install-write failed"
                _run_pm pm install-abandon "$_sid" >/dev/null 2>&1
                _ACTIVE_SESSION=""
                return 1
            fi

            STRATEGY_OUTPUT=$(_run_pm pm install-commit "$_sid" 2>&1)
            _rc=$?
            if [ "$_rc" -ne 0 ]; then
                _run_pm pm install-abandon "$_sid" >/dev/null 2>&1
                _ACTIVE_SESSION=""
                return 1
            fi
            _ACTIVE_SESSION=""
            ;;
        4)
            if ! command -v magisk >/dev/null 2>&1; then
                STRATEGY_OUTPUT="magisk not available"
                return 1
            fi
            STRATEGY_OUTPUT=$(_run_pm magisk su -c "pm install -r --user 0 '$APK_PATH'" 2>&1)
            _rc=$?
            ;;
        5)
            STRATEGY_OUTPUT=$(_run_pm cmd package install -r --user 0 "$APK_PATH" 2>&1)
            _rc=$?
            ;;
        *)
            return 1
            ;;
    esac

    if [ "$_rc" -ne 0 ]; then
        return 1
    fi

    if _detect_and_update_pkg; then
        _vname=$(_pkg_version_name)
        if [ -z "$_vname" ] || [ "$_vname" = "unknown" ] || [ "$_vname" = "$APP_VERSION" ]; then
            return 0
        fi
    fi
    return 1
}

for _strategy in 1 2 3 4 5; do
    _now=$(date +%s 2>/dev/null)
    case "$_now" in ''|*[!0-9]*) _now=0 ;; esac
    if [ "$_now" -gt 0 ] && [ "$_now" -ge "$_CASCADE_DEADLINE" ]; then
        STRATEGY_OUTPUT="cascade deadline reached before strategy $_strategy"
        log_msg "INSTALL: deadline reached (strategy $_strategy)"
        break
    fi

    if _run_strategy "$_strategy"; then
        STRATEGY_USED="$_strategy"
        log_msg "INSTALL: strategy $_strategy succeeded (pkg=$COMPANION_PKG)"
        break
    fi
    log_msg "INSTALL: strategy $_strategy failed (${STRATEGY_OUTPUT:0:200})"

    if _wait_for_install 15 "$_CASCADE_DEADLINE"; then
        STRATEGY_USED="$_strategy"
        log_msg "INSTALL: strategy $_strategy registered after delay"
        break
    fi
done

# ============================================================
# [17] Error translation (8 cases, AR + EN)
# ============================================================
if [ "$STRATEGY_USED" = "0" ]; then
    _err_ar="فشل تثبيت التطبيق — جرّب التنزيل اليدوي"
    _err_en="Install failed — try manual download"
    _hint_ar=""
    _hint_en=""

    case "$STRATEGY_OUTPUT" in
        *INSTALL_FAILED_USER_RESTRICTED*)
            _err_ar="MIUI/HyperOS حجب التثبيت"
            _err_en="MIUI/HyperOS blocked the install"
            _hint_ar="فعّل: الإعدادات ← خيارات المطوّر ← تثبيت عبر USB"
            _hint_en="Enable: Settings → Developer options → Install via USB"
            ;;
        *INSTALL_FAILED_VERIFICATION_FAILURE*)
            _err_ar="Play Protect حجب التطبيق"
            _err_en="Play Protect blocked the app"
            _hint_ar="عطّل Play Protect مؤقتاً: متجر Play ← الإعدادات"
            _hint_en="Temporarily disable Play Protect: Play Store → Settings"
            ;;
        *INSTALL_FAILED_VERSION_DOWNGRADE*)
            _err_ar="النسخة المثبّتة أحدث"
            _err_en="Installed app version is newer"
            _hint_ar="ألغِ التثبيت القديم ثم أعد المحاولة"
            _hint_en="Uninstall the current version and retry"
            ;;
        *INSTALL_FAILED_INSUFFICIENT_STORAGE*)
            _err_ar="المساحة غير كافية"
            _err_en="Insufficient storage"
            _hint_ar="حرّر مساحة ثم أعد المحاولة"
            _hint_en="Free up storage and retry"
            ;;
        *INSTALL_FAILED_UPDATE_INCOMPATIBLE*)
            _err_ar="توقيع التطبيق المثبّت مختلف"
            _err_en="Installed app has a different signature"
            _hint_ar="ألغِ التثبيت القديم يدوياً أولاً"
            _hint_en="Uninstall the existing app manually first"
            ;;
        *INSTALL_PARSE_FAILED_NO_CERTIFICATES*)
            _err_ar="ملف APK تالف أو غير موقّع"
            _err_en="APK is corrupt or unsigned"
            _hint_ar="أعد تثبيت الوحدة"
            _hint_en="Reinstall the module"
            ;;
        *INSTALL_FAILED_ALREADY_EXISTS*)
            _err_ar="التطبيق مثبّت بالفعل"
            _err_en="App is already installed"
            _hint_ar="استخدم زر إلغاء التثبيت أولاً"
            _hint_en="Use the uninstall button first"
            ;;
        *INSTALL_FAILED_INTERNAL_ERROR*)
            _err_ar="خطأ داخلي — قد يكون Play Protect غير متاح"
            _err_en="Internal error — Play Protect may be unreachable"
            _hint_ar="أعد تشغيل الجهاز ثم حاول مرة أخرى"
            _hint_en="Reboot the device and retry"
            ;;
    esac

    _sha_ok="false"
    [ "$SHA_VERIFIED" = "1" ] && _sha_ok="true"

    _emit_json 2 "error" "install" \
        "s:reason=all_strategies_failed" \
        "s:message_ar=$_err_ar" \
        "s:message_en=$_err_en" \
        "s:hint_ar=$_hint_ar" \
        "s:hint_en=$_hint_en" \
        "s:last_output=${STRATEGY_OUTPUT:0:300}" \
        "b:sha_verified=$_sha_ok"
fi

# ============================================================
# [18] Success output
# ============================================================
_detect_and_update_pkg 2>/dev/null
_vname=$(_pkg_version_name)

_sha_ok="false"
[ "$SHA_VERIFIED" = "1" ] && _sha_ok="true"

_emit_json 0 "ok" "install" \
    "n:strategy=$STRATEGY_USED" \
    "s:package=$COMPANION_PKG" \
    "s:version_name=$_vname" \
    "s:expected_version=$APP_VERSION" \
    "n:apk_size=$APK_SIZE" \
    "b:sha_verified=$_sha_ok" \
    "s:message_ar=تم تثبيت التطبيق بنجاح" \
    "s:message_en=Companion app installed successfully"