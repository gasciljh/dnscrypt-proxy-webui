#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter – install_app.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-10
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Install / query / uninstall the companion Android app
#   (web/app-debug.apk) via `pm install`, bypassing the
#   browser's download-only UX.
#
#   Invoked by main.go: POST /api/install_companion_app (APK-5).
#   The endpoint is auth-protected + localhost-only + rate-limited.
#
# Modes:
#   install_app.sh                     Install the companion app
#   install_app.sh --status            Report current install state (JSON)
#   install_app.sh --uninstall         Uninstall the companion app
#   install_app.sh --help              Show help
#   install_app.sh --version           Show script version
#
# Output:
#   Always prints a single-line JSON object on stdout:
#     {"status":"ok|error","action":"...","message":"...",...}
#   main.go parses this JSON directly.
#
# Exit codes:
#   0 = success
#   1 = APK missing / corrupt / hash mismatch
#   2 = all install strategies failed
#   3 = invalid arguments
#   4 = not installed (--uninstall / --status only)
#
# Design notes:
#   • POSIX sh + `local` (matches the module's other shell scripts).
#   • No `set -e`: Android scripts must not abort on a single
#     unexpected non-zero (e.g. `pgrep` when no process exists).
#   • Self-contained: does NOT source functions.sh. This lets the
#     script run even when the module is in a degraded state.
#   • APK path is HARDCODED (CIS-3). No user input reaches any
#     path expression.
#   • SHA256 verification uses the sibling file
#     `web/app-debug.apk.sha256` (added by APK-8 in v1.5.0).
#     If that file is missing, verification is skipped with a
#     warning — this preserves backward compatibility with
#     modules built before the APK-8 pipeline landed.
#
# ============================================================
# v1.5.0 — Companion app direct install (APK-4)
# ============================================================
#   📱 CIA-1 — Pre-flight checks:
#     • APK exists and is non-empty
#     • APK is a valid ZIP (first 2 bytes == "PK")
#     • APK is not truncated (> 100 KB)
#     • Free space on /data >= 3× APK size
#
#   🛡️ CIS-1 — SELinux context preparation:
#     • restorecon (preferred) or chcon apk_data_file:s0
#     • NEVER disables SELinux (setenforce 0 is forbidden)
#
#   📱 CIA-2..5 — 5-level install cascade:
#     1. pm install -r --user 0 <apk>
#     2. pm install -r -i com.android.shell <apk>
#     3. pm install-create + install-write + install-commit
#     4. magisk su -c "pm install -r <apk>"
#     5. cmd package install -r <apk>
#
#   📱 CIA-6 — Error translation (AR + EN) for 7 common cases:
#     • INSTALL_FAILED_USER_RESTRICTED        (MIUI)
#     • INSTALL_FAILED_VERIFICATION_FAILURE   (Play Protect)
#     • INSTALL_FAILED_VERSION_DOWNGRADE
#     • INSTALL_FAILED_INSUFFICIENT_STORAGE
#     • INSTALL_FAILED_UPDATE_INCOMPATIBLE
#     • INSTALL_PARSE_FAILED_NO_CERTIFICATES
#     • INSTALL_FAILED_ALREADY_EXISTS
#
#   📱 CIA-7 — Post-install verification:
#     `pm list packages` + `dumpsys package <pkg>` to confirm
#     the install actually took effect.
#
#   📱 CIA-8 — JSON output:
#     {"status":"ok","action":"install","strategy":N,
#      "package":"...","version_name":"...","message":"..."}
#
#   📱 CIA-9 — Three modes (install / status / uninstall).
#
# ============================================================
# v1.5.0 — POST-AUDIT FIXES (this revision)
# ============================================================
#   🔧 CIA-10 — SC2155 fix: `_emit_json` now declares `json`
#     separately from assignment, matching the module's style
#     and silencing ShellCheck SC2155.
#
#   🔧 CIA-11 — SC2329 fix: the cascade no longer uses a
#     dynamic function-name expansion (`"_strategy_${n}"`).
#     An `_attempt()` dispatcher with an explicit `case`
#     statement is used instead, so ShellCheck sees all five
#     `_strategy_N` functions as called. Behavior identical.
#
#   🔧 CIA-12 — `MODDIR` 3-strategy resolver. Previously the
#     script assumed `$0` was at `$MODDIR/install_app.sh`
#     (post-install layout). When run from the source tree as
#     `sh proxy/install_app.sh`, this produced
#     `/data/adb/modules/proxy` — wrong module path, causing
#     `expected_version` to read as `unknown`. The resolver
#     now checks for `module.prop` in the script's own
#     directory (install layout) and in its parent (source
#     layout) before falling back to the Magisk default.
#
#   🔧 CIA-13 — JSON number detection. The previous 1–4 digit
#     whitelist (`[0-9]|[0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9][0-9][0-9]`)
#     emitted values like `apk_size=3284803` (7 digits) as JSON
#     STRINGS instead of numbers. The check is now
#     `''|*[!0-9]*` → string, `*` → number, so any
#     non-negative integer of any length is emitted correctly.
#     Booleans (`true`/`false`) are matched first.
#
#   🔧 CIA-14 — `log_msg` silent no-op when the log location
#     is unwritable. Two changes:
#       1. The guard uses OR, not nested AND. On Termux
#          without `su`, the log file is 0666 (so
#          `test -w $LOG_FILE` returns true) but the parent
#          directory `/data/local/tmp` lacks the `w` bit for
#          the current user. The previous nested-AND form
#          therefore evaluated false and let the write proceed,
#          producing a spurious "cannot create" on stderr.
#          The OR form short-circuits before the write.
#       2. The write is wrapped in a command group
#          `{ echo ... >> "$LOG_FILE"; } 2>/dev/null`. Without
#          the group, the shell opens the target for `>>`
#          BEFORE applying the command's own `2>/dev/null`, so
#          a shell-level open failure escapes the redirect. The
#          group form applies `2>/dev/null` to the shell's own
#          diagnostic before it is emitted.
#
# ============================================================
# Cross-references:
#   • proxy/main.go                — POST /api/install_companion_app (APK-5)
#   • proxy/app-apk.version        — SSOT for companion app version
#   • web/app-debug.apk            — companion APK (optional)
#   • web/app-debug.apk.sha256     — SHA256 sidecar (APK-8)
#   • scripts/package_module.sh    — bundles APK + .sha256
#   • scripts/fetch_app_apk.sh     — downloads APK + .sha256
#   • docs/ARCHITECTURE.md §4.12.4 — APK-4 reference
#   • CHANGELOG.md [v1.5.0]        — companion app direct install
# ============================================================

# ============================================================
# [1] Path resolution (CIA-12 — 3-strategy resolver)
# ============================================================
# Strategy order:
#   1. Script at $MODDIR/install_app.sh        → own dir has module.prop
#   2. Script at $MODDIR/proxy/install_app.sh  → parent has module.prop
#   3. Fallback                                 → /data/adb/modules/<basename>
#
# Strategies 1+2 make the script work both when installed AND
# when run from the source repository for testing.
# ============================================================
_self_dir="${0%/*}"
[ "$_self_dir" = "." ] && _self_dir="$(pwd)"
[ -z "$_self_dir" ] && _self_dir="."

if [ -f "$_self_dir/module.prop" ]; then
    # Case 1: install_app.sh at module root (post-install)
    MODDIR="$(cd "$_self_dir" && pwd)"
elif [ -f "$_self_dir/../module.prop" ]; then
    # Case 2: install_app.sh inside proxy/ (source tree)
    MODDIR="$(cd "$_self_dir/.." && pwd)"
else
    # Case 3: fallback — standard Magisk install layout
    case "$_self_dir" in
        /*) MODDIR="$_self_dir" ;;
        *)  MODDIR="/data/adb/modules/${_self_dir}" ;;
    esac
fi

# ============================================================
# [2] Constants
# ============================================================
SCRIPT_VERSION="v1.5.0"
APK_PATH="$MODDIR/web/app-debug.apk"
SHA_PATH="$MODDIR/web/app-debug.apk.sha256"
APP_VERSION_FILE="$MODDIR/proxy/app-apk.version"
LOG_FILE="/data/local/tmp/dnscrypt_main.log"

# Minimum APK size sanity check (100 KB)
MIN_APK_BYTES=102400

# Minimum free space multiplier (3× APK size)
SPACE_MULTIPLIER=3

# ============================================================
# [3] Argument parsing
# ============================================================
MODE="install"

case "${1:-}" in
    --version)
        echo "install_app.sh: $SCRIPT_VERSION"
        exit 0
        ;;
    --help|-h)
        cat << 'EOF'
DNSCrypt Smart Filter – install_app.sh

Usage:
  install_app.sh                Install the companion app
  install_app.sh --status       Report current state (JSON)
  install_app.sh --uninstall    Uninstall the companion app
  install_app.sh --version      Show script version
  install_app.sh --help         Show this help

Output:
  All modes print a single-line JSON object on stdout.
  Example: {"status":"ok","action":"install",...}

Exit codes:
  0 = success
  1 = APK missing / corrupt / hash mismatch
  2 = all install strategies failed
  3 = invalid arguments
  4 = not installed (--uninstall / --status only)
EOF
        exit 0
        ;;
    --status)
        MODE="status"
        ;;
    --uninstall)
        MODE="uninstall"
        ;;
    "")
        MODE="install"
        ;;
    *)
        echo "{\"status\":\"error\",\"message\":\"Unknown argument: $1\"}"
        exit 3
        ;;
esac

# ============================================================
# [4] Logging helper (with emergency 50 MB rotation)
# ============================================================
# Parity with functions.sh:log_fn / watchdog.sh:log_msg.
# `_LOG_CALL_COUNT` is a global by design.
#
# CIA-14: two safeguards against spurious "cannot create"
# errors on stderr when the log location is not fully usable:
#   1. Guard with OR (not nested AND) — either the file is
#      unwritable OR its parent is unwritable → silent no-op.
#   2. Wrap the write in a command group `{ ...; }` so that
#      `2>/dev/null` is applied to the shell's own open-time
#      diagnostic, not just to echo's stderr.
# ============================================================
_LOG_CALL_COUNT=0

log_msg() {
    if [ ! -w "$LOG_FILE" ] || [ ! -w "$(dirname "$LOG_FILE")" ]; then
        return 0
    fi

    _LOG_CALL_COUNT=$((_LOG_CALL_COUNT + 1))

    if [ $((_LOG_CALL_COUNT % 100)) -eq 0 ] && [ -f "$LOG_FILE" ]; then
        local _size
        _size=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
        if [ -n "$_size" ] && [ "$_size" -gt 52428800 ]; then
            local _emg
            _emg="${LOG_FILE}.emergency.$(date +%s)"
            mv -f "$LOG_FILE" "$_emg" 2>/dev/null
            : > "$LOG_FILE" 2>/dev/null
        fi
    fi

    { echo "$(date +'%Y-%m-%d %H:%M:%S') - [install_app] $1" >> "$LOG_FILE"; } 2>/dev/null
}

# ============================================================
# [5] JSON output helpers
# ============================================================
# _json_escape: minimal JSON string escaper.
# Parity with _act_json_escape in action.sh (HARD-ACT-01).
_json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\000-\010\013\014\016-\037'
}

# _emit_json <status> <action> [key=value ...]
# Emits a single-line JSON object and exits with the given status.
# The caller-supplied status code is the script's exit code.
#
# CIA-10: declare `json` separately from assignment (SC2155).
# CIA-13: emit any non-negative integer as a JSON number;
#         booleans matched first; everything else as a string.
# ------------------------------------------------------------
_emit_json() {
    local exit_code="$1"
    local status="$2"
    local action="$3"
    shift 3

    local json
    json="{\"status\":\"$( _json_escape "$status" )\""
    json="$json,\"action\":\"$( _json_escape "$action" )\""

    local kv k v
    for kv in "$@"; do
        k="${kv%%=*}"
        v="${kv#*=}"
        case "$v" in
            true|false)
                json="$json,\"$( _json_escape "$k" )\":$v"
                ;;
            ''|*[!0-9]*)
                json="$json,\"$( _json_escape "$k" )\":\"$( _json_escape "$v" )\""
                ;;
            *)
                json="$json,\"$( _json_escape "$k" )\":$v"
                ;;
        esac
    done

    json="$json}"
    printf '%s\n' "$json"
    exit "$exit_code"
}

# ============================================================
# [6] Read companion app version from SSOT
# ============================================================
read_app_version() {
    if [ -f "$APP_VERSION_FILE" ]; then
        local v
        v=$(tr -d '\r\n' < "$APP_VERSION_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$v" ]; then
            printf '%s' "$v"
            return 0
        fi
    fi
    printf 'unknown'
}

APP_VERSION=$(read_app_version)

# ============================================================
# [7] Determine companion app package name
# ============================================================
# The package name is fixed in the companion repository
# (gasciljh/dnscrypt-proxy-app). It is hardcoded here to avoid
# any dependency on aapt / aapt2 / apkanalyzer (none of which
# are guaranteed on Android).
# ============================================================
COMPANION_PKG="com.gasciljh.dnscrypt_proxy"

# ============================================================
# [8] Package state helpers
# ============================================================
_pkg_installed() {
    pm list packages 2>/dev/null | grep -qFx "package:$COMPANION_PKG"
}

_pkg_version_name() {
    # dumpsys output format varies; extract versionName if present.
    local out
    out=$(dumpsys package "$COMPANION_PKG" 2>/dev/null | grep -m1 'versionName=' || true)
    case "$out" in
        *versionName=*)
            printf '%s' "${out#*versionName=}" | tr -d '\r'
            ;;
        *)
            printf 'unknown'
            ;;
    esac
}

# ============================================================
# [9] MODE: --status
# ============================================================
# Fast path — reports install state and exits.
# ============================================================
if [ "$MODE" = "status" ]; then
    if _pkg_installed; then
        _vname=$(_pkg_version_name)
        log_msg "STATUS: installed (versionName=$_vname, expected=$APP_VERSION)"
        _emit_json 0 "ok" "status" \
            "installed=true" \
            "package=$COMPANION_PKG" \
            "version_name=$_vname" \
            "expected_version=$APP_VERSION"
    else
        log_msg "STATUS: not installed"
        _emit_json 4 "ok" "status" \
            "installed=false" \
            "package=$COMPANION_PKG" \
            "expected_version=$APP_VERSION"
    fi
fi

# ============================================================
# [10] MODE: --uninstall
# ============================================================
if [ "$MODE" = "uninstall" ]; then
    if ! _pkg_installed; then
        log_msg "UNINSTALL: not installed, nothing to do"
        _emit_json 4 "ok" "uninstall" \
            "message=not_installed" \
            "package=$COMPANION_PKG"
    fi

    log_msg "UNINSTALL: removing $COMPANION_PKG"
    _out=$(pm uninstall "$COMPANION_PKG" 2>&1)
    _rc=$?

    if [ "$_rc" -eq 0 ]; then
        log_msg "UNINSTALL: success"
        _emit_json 0 "ok" "uninstall" \
            "package=$COMPANION_PKG" \
            "message=uninstalled"
    else
        log_msg "UNINSTALL: failed (rc=$_rc): $_out"
        _emit_json 2 "error" "uninstall" \
            "package=$COMPANION_PKG" \
            "message=uninstall_failed" \
            "details=$_out"
    fi
fi

# ============================================================
# [11] MODE: install — pre-flight checks (CIA-1)
# ============================================================
log_msg "INSTALL: starting (app-version=$APP_VERSION, moddir=$MODDIR)"

# --- APK exists ---
if [ ! -f "$APK_PATH" ]; then
    log_msg "INSTALL: APK not found at $APK_PATH"
    _emit_json 1 "error" "install" \
        "reason=apk_not_found" \
        "message_ar=الملف المرافق للتطبيق غير موجود في الوحدة" \
        "message_en=Companion APK not found in the module" \
        "hint=أعد تثبيت الوحدة || Reinstall the module"
fi

# --- APK non-empty ---
if [ ! -s "$APK_PATH" ]; then
    log_msg "INSTALL: APK is empty"
    _emit_json 1 "error" "install" \
        "reason=apk_empty" \
        "message_ar=الملف المرافق فارغ — أعد تثبيت الوحدة" \
        "message_en=Companion APK is empty — reinstall the module"
fi

# --- Size sanity ---
APK_SIZE=$(wc -c < "$APK_PATH" 2>/dev/null | tr -d ' ')
case "$APK_SIZE" in
    ''|*[!0-9]*)
        APK_SIZE=0
        ;;
esac

if [ "$APK_SIZE" -lt "$MIN_APK_BYTES" ]; then
    log_msg "INSTALL: APK too small ($APK_SIZE bytes < $MIN_APK_BYTES)"
    _emit_json 1 "error" "install" \
        "reason=apk_too_small" \
        "size=$APK_SIZE" \
        "message_ar=الملف المرافق صغير جدًا — قد يكون تالفًا" \
        "message_en=Companion APK is suspiciously small — likely corrupt"
fi

# --- ZIP magic check (first 2 bytes must be "PK") ---
if command -v od >/dev/null 2>&1; then
    _magic=$(od -An -N2 -tx1 "$APK_PATH" 2>/dev/null | tr -d ' \n')
    if [ "$_magic" != "504b" ]; then
        log_msg "INSTALL: APK is not a valid ZIP (magic=$_magic)"
        _emit_json 1 "error" "install" \
            "reason=apk_not_zip" \
            "message_ar=الملف المرافق ليس ملف APK صالح — أعد تثبيت الوحدة" \
            "message_en=Companion APK is not a valid ZIP archive — reinstall the module"
    fi
fi

# --- SHA256 verification (APK-8 pipeline) ---
# If the sibling .sha256 file is missing, skip with a warning.
# This preserves compatibility with modules built before v1.5.0.
SHA_VERIFIED=0
if [ -f "$SHA_PATH" ] && command -v sha256sum >/dev/null 2>&1; then
    _expected=$(awk '{print $1}' "$SHA_PATH" 2>/dev/null | head -n1 | tr -d '\r\n ')
    _actual=$(sha256sum "$APK_PATH" 2>/dev/null | awk '{print $1}')

    if [ -n "$_expected" ] && [ -n "$_actual" ]; then
        if [ "$_expected" != "$_actual" ]; then
            log_msg "INSTALL: SHA256 mismatch (expected=${_expected:0:16}... actual=${_actual:0:16}...)"
            _emit_json 1 "error" "install" \
                "reason=sha_mismatch" \
                "message_ar=فشل التحقق من سلامة الملف — أعد تثبيت الوحدة" \
                "message_en=Integrity check failed — reinstall the module"
        fi
        SHA_VERIFIED=1
        log_msg "INSTALL: SHA256 verified"
    fi
elif [ ! -f "$SHA_PATH" ]; then
    log_msg "INSTALL: SHA256 sidecar missing — skipping verification (advisory)"
fi

# --- Free space on /data (>= 3× APK size) ---
if command -v df >/dev/null 2>&1; then
    _free_kb=$(df -k /data 2>/dev/null | awk 'NR==2 {print $4}')
    case "$_free_kb" in
        ''|*[!0-9]*) _free_kb=0 ;;
    esac
    _needed_kb=$(( (APK_SIZE / 1024) * SPACE_MULTIPLIER ))
    if [ "$_free_kb" -gt 0 ] && [ "$_free_kb" -lt "$_needed_kb" ]; then
        log_msg "INSTALL: insufficient storage (free=${_free_kb}KB, needed=${_needed_kb}KB)"
        _emit_json 1 "error" "install" \
            "reason=insufficient_storage" \
            "free_kb=$_free_kb" \
            "needed_kb=$_needed_kb" \
            "message_ar=المساحة غير كافية — حرّر ما لا يقل عن 50 ميجابايت" \
            "message_en=Insufficient storage — free at least 50 MB"
    fi
fi

# ============================================================
# [12] SELinux context preparation (CIS-1)
# ============================================================
# NEVER run `setenforce 0` — that would weaken the entire system.
# Instead, apply the correct context to the APK so that
# PackageManager accepts it.
# ============================================================
if command -v restorecon >/dev/null 2>&1; then
    restorecon "$APK_PATH" 2>/dev/null || true
    log_msg "INSTALL: restorecon applied to APK"
elif command -v chcon >/dev/null 2>&1; then
    chcon u:object_r:apk_data_file:s0 "$APK_PATH" 2>/dev/null || true
    log_msg "INSTALL: chcon apk_data_file:s0 applied to APK"
fi

# ============================================================
# [13] Cascade install (CIA-2..5)
# ============================================================
# Each strategy is attempted in order. The first one that
# produces a success (as confirmed by _pkg_installed) wins.
#
# "Success" is verified by `pm list packages` — NOT by the
# strategy's stdout — because some Android builds return
# "Success" even when the install is deferred to a UI prompt.
#
# CIA-11: the cascade is dispatched via an explicit `case`
# statement (`_attempt`) rather than a dynamic function-name
# expansion. This lets ShellCheck see all five `_strategy_N`
# functions as called (SC2329), and keeps the intent clear.
# ============================================================
STRATEGY_USED=0
STRATEGY_OUTPUT=""

# --- Strategy 1: pm install -r ---
_strategy_1() {
    log_msg "INSTALL: strategy 1 — pm install -r --user 0"
    STRATEGY_OUTPUT=$(pm install -r --user 0 "$APK_PATH" 2>&1)
    _pkg_installed
}

# --- Strategy 2: pm install -r -i com.android.shell ---
# Presents the install as coming from the Android shell — some
# MIUI variants allow this even when the default installer is
# restricted.
_strategy_2() {
    log_msg "INSTALL: strategy 2 — pm install -i com.android.shell"
    STRATEGY_OUTPUT=$(pm install -r --user 0 -i com.android.shell "$APK_PATH" 2>&1)
    _pkg_installed
}

# --- Strategy 3: session-based install ---
# Uses `install-create` + `install-write` + `install-commit`,
# which bypasses some Android 14+ verification hooks.
_strategy_3() {
    log_msg "INSTALL: strategy 3 — session-based install"

    local _session
    _session=$(pm install-create -r --user 0 2>/dev/null | grep -oE '\[[0-9]+\]' | tr -d '[]')

    if [ -z "$_session" ]; then
        STRATEGY_OUTPUT="install-create failed"
        return 1
    fi

    log_msg "INSTALL: session id = $_session"

    if ! pm install-write "$_session" base "$APK_PATH" >/dev/null 2>&1; then
        STRATEGY_OUTPUT="install-write failed"
        pm install-abandon "$_session" >/dev/null 2>&1
        return 1
    fi

    STRATEGY_OUTPUT=$(pm install-commit "$_session" 2>&1)
    _pkg_installed
}

# --- Strategy 4: magisk su (Magisk-only) ---
# On devices where the WebUI's UID lacks `INSTALL_PACKAGES`,
# but Magisk's own `su` context has it.
_strategy_4() {
    if ! command -v magisk >/dev/null 2>&1; then
        STRATEGY_OUTPUT="magisk not available"
        return 1
    fi

    log_msg "INSTALL: strategy 4 — magisk su"
    STRATEGY_OUTPUT=$(magisk su -c "pm install -r --user 0 '$APK_PATH'" 2>&1)
    _pkg_installed
}

# --- Strategy 5: cmd package install ---
# Alternate entry point — sometimes works where `pm` fails.
_strategy_5() {
    log_msg "INSTALL: strategy 5 — cmd package install"
    STRATEGY_OUTPUT=$(cmd package install -r --user 0 "$APK_PATH" 2>&1)
    _pkg_installed
}

# Dispatcher — explicit `case` so ShellCheck sees the calls.
_attempt() {
    case "$1" in
        1) _strategy_1 ;;
        2) _strategy_2 ;;
        3) _strategy_3 ;;
        4) _strategy_4 ;;
        5) _strategy_5 ;;
        *) return 1 ;;
    esac
}

# Execute the cascade.
for _strategy in 1 2 3 4 5; do
    if _attempt "$_strategy"; then
        STRATEGY_USED="$_strategy"
        log_msg "INSTALL: strategy $_strategy succeeded"
        break
    fi
    log_msg "INSTALL: strategy $_strategy failed (output: ${STRATEGY_OUTPUT:0:200})"
done

# ============================================================
# [14] Cascade result handling
# ============================================================
if [ "$STRATEGY_USED" = "0" ]; then
    # All strategies failed — translate the last output.
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
            _hint_ar="عطّل Play Protect مؤقتًا من متجر Play ← الإعدادات"
            _hint_en="Temporarily disable Play Protect: Play Store → Settings"
            ;;
        *INSTALL_FAILED_VERSION_DOWNGRADE*)
            _err_ar="نسخة التطبيق المثبَّتة أحدث"
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
            _err_ar="توقيع التطبيق المثبَّت مختلف"
            _err_en="Installed app has a different signature"
            _hint_ar="ألغِ التثبيت القديم يدويًا أولًا"
            _hint_en="Uninstall the existing app manually first"
            ;;
        *INSTALL_PARSE_FAILED_NO_CERTIFICATES*)
            _err_ar="ملف APK تالف أو غير موقَّع"
            _err_en="APK is corrupt or unsigned"
            _hint_ar="أعد تثبيت الوحدة"
            _hint_en="Reinstall the module"
            ;;
        *INSTALL_FAILED_ALREADY_EXISTS*)
            _err_ar="التطبيق مثبَّت بالفعل"
            _err_en="App is already installed"
            _hint_ar="استخدم زر إلغاء التثبيت أولًا"
            _hint_en="Use the uninstall button first"
            ;;
    esac

    log_msg "INSTALL: all strategies failed; translated error = $_err_en"
    _emit_json 2 "error" "install" \
        "reason=all_strategies_failed" \
        "message_ar=$_err_ar" \
        "message_en=$_err_en" \
        "hint_ar=$_hint_ar" \
        "hint_en=$_hint_en" \
        "last_output=${STRATEGY_OUTPUT:0:300}" \
        "sha_verified=$([ "$SHA_VERIFIED" = "1" ] && echo true || echo false)"
fi

# ============================================================
# [15] Post-install verification (CIA-7)
# ============================================================
_vname=$(_pkg_version_name)

if [ "$_vname" = "unknown" ]; then
    log_msg "INSTALL: success (versionName unavailable)"
else
    log_msg "INSTALL: success (versionName=$_vname)"
fi

# ============================================================
# [16] Final JSON output (CIA-8)
# ============================================================
_emit_json 0 "ok" "install" \
    "strategy=$STRATEGY_USED" \
    "package=$COMPANION_PKG" \
    "version_name=$_vname" \
    "expected_version=$APP_VERSION" \
    "apk_size=$APK_SIZE" \
    "sha_verified=$([ "$SHA_VERIFIED" = "1" ] && echo true || echo false)" \
    "message_ar=تم تثبيت التطبيق بنجاح" \
    "message_en=Companion app installed successfully"