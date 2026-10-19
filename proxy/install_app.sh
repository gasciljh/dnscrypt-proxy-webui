#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — install_app.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-19
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Install / query / uninstall the companion Android app
# (web/app-debug.apk) via `pm install`.
#
# Modes:
#   (no args)      Install
#   --status       Report state (JSON)
#   --uninstall    Uninstall (JSON)
#   --help         Show help
#   --version      Show version
#
# All modes except --help and --version print a single-line
# JSON object on stdout, parsed directly by main.go.
#
# Exit codes:
#   0   = success
#   1   = APK missing / corrupt / hash mismatch
#   2   = all install strategies failed, or uninstall failed
#   3   = invalid arguments
#   4   = not installed (--uninstall / --status)
#   130 = interrupted by SIGINT   (128 + 2)
#   143 = terminated by SIGTERM   (128 + 15)
#
# Timeout hierarchy (must stay in sync with main.go):
#   • WebUI client   : 120 s  (web/index.html)
#   • Server         :  90 s  (main.go INSTALL_TIMEOUT)
#   • Cascade        :  75 s  (§[2b])
#   • Per-strategy   :  20 s  (STRATEGY_TIMEOUT)
# The cascade deadline < server timeout, so the EXIT/INT/TERM
# traps always fire before main.go sends SIGKILL (uncatchable).
#
# Why this script does NOT use `set -e`:
#   The 5-level cascade in §[14] relies on non-zero returns
#   to fall through to the next strategy. Under `set -e`,
#   the first failed `pm install` would abort the script
#   before strategies 2-5 could be tried. Every command has
#   explicit `|| return 1` / `if command; then` handling;
#   the EXIT/INT/TERM traps provide the cleanup guarantees
#   that `set -e` would otherwise contribute. If a future
#   change genuinely needs `set -e` semantics, use an
#   explicit `|| exit 1` on that line — do NOT enable
#   `set -e` globally.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module root resolution
# ============================================================
# 1. $_self_dir/module.prop       → post-install layout
# 2. $_self_dir/../module.prop    → source-tree layout
# 3. Known Magisk/KernelSU/APatch location (fallback)
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
        if [ -f "$_cand/module.prop" ]; then
            MODDIR="$_cand"
            break
        fi
    done
    [ -z "$MODDIR" ] && MODDIR="$_self_dir"
fi
unset _self_dir _cand

# ============================================================
# [2] Constants
# ============================================================
# get_version — reads `version=` from module.prop. Dynamic
# version avoids a stale `--version` output after an upgrade
# (the script is extracted alongside module.prop by
# customize.sh §[9]).
get_version() {
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

SCRIPT_VERSION="$(get_version)"
APK_PATH="$MODDIR/web/app-debug.apk"
SHA_PATH="$MODDIR/web/app-debug.apk.sha256"
APP_VERSION_FILE="$MODDIR/proxy/app-apk.version"
LOG_FILE="/data/local/tmp/dnscrypt_main.log"

# Minimum APK size sanity check (100 KB).
MIN_APK_BYTES=102400

# Minimum free space multiplier (3× APK size).
SPACE_MULTIPLIER=3

# Wall-clock deadline for the entire cascade. Must be strictly
# less than main.go's INSTALL_TIMEOUT (90 s) so the EXIT trap
# always fires before the parent kills the process with SIGKILL
# (uncatchable — the Play Protect verifier would remain
# disabled).
CASCADE_DEADLINE_SECONDS=75

# Per-`pm` invocation cap. The effective value is
# min(STRATEGY_TIMEOUT, remaining_cascade_budget), computed at
# call time by _run_pm.
STRATEGY_TIMEOUT=20

# Minimum remaining budget required to start a subprocess.
# Below this, `timeout` would kill the command before it could
# do useful work; _run_pm short-circuits and returns the same
# exit code that timeout(1) uses (124).
MIN_STRATEGY_BUDGET=3

# Package name candidates. Tried in order; the debug variant is
# the default for a fresh install.
COMPANION_PKG_CANDIDATES="com.gasciljh.dnsproxy.debug com.gasciljh.dnsproxy com.gasciljh.dnscrypt_proxy"

# Staged APK path. /data/adb/ is adb_data_file context, which
# system_server cannot read; /data/local/tmp/ is shell_data_file,
# which it can. Staging here avoids SELinux errors without ever
# disabling SELinux.
STAGING_APK="/data/local/tmp/dnscrypt-companion.apk"

# ============================================================
# [2b] Cascade deadline computation
# ============================================================
# _CASCADE_START must be a non-negative integer. `date +%s` can
# theoretically fail (broken clock, restricted shell, ...). If it
# does, we set _CASCADE_DEADLINE to a very large sentinel value
# (9999999999 — year 2286) so the cascade runs to completion
# without timing out. The EXIT/INT/TERM trap still fires on any
# catchable exit path — the deadline is a secondary protection
# that ensures the trap fires before main.go's 90-second SIGKILL,
# not the primary protection.
_CASCADE_START=$(date +%s 2>/dev/null)
case "$_CASCADE_START" in
    ''|*[!0-9]*) _CASCADE_START=0 ;;
esac
if [ "$_CASCADE_START" -le 0 ]; then
    _CASCADE_DEADLINE=9999999999
else
    _CASCADE_DEADLINE=$(( _CASCADE_START + CASCADE_DEADLINE_SECONDS ))
fi
unset _CASCADE_START

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
  Install / --status / --uninstall print a single-line JSON
  object on stdout.
  --version and --help print human-readable text instead.

Exit codes:
  0 = success
  1 = APK missing / corrupt / hash mismatch
  2 = all install strategies failed, or uninstall failed
  3 = invalid arguments
  4 = not installed (--uninstall / --status)
  130 = interrupted by SIGINT
  143 = terminated by SIGTERM
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
# [4] Logging
# ============================================================
# Appends a timestamped line to LOG_FILE with 50 MB emergency
# rotation. Silent no-op when the log location is unwritable
# (a boot-time failure must never abort the script).
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
# [5] JSON output
# ============================================================
_json_escape() {
    printf '%s' "$1" \
        | sed 's/\\/\\\\/g; s/"/\\"/g' \
        | sed 's/\t/\\t/g; s/\r/\\r/g' \
        | awk 'BEGIN{ORS=""} {if (NR>1) printf "\\n"; printf "%s", $0}' \
        | tr -d '\000-\010\013\014\016-\037'
}

# _emit_json <exit_code> <status> <action> [type:key=value ...]
#
# Emits a single-line JSON object and exits with the given
# status code.
#
# Type prefixes (explicit — no auto-detection):
#   s:  JSON string  (escaped)
#   n:  JSON number  (validated as integer; falls back to string)
#   b:  JSON boolean (must be "true" or "false"; falls back to string)
#
# Explicit typing avoids the classic pitfall where a version
# string that happens to contain only digits (e.g. "1") is
# emitted as a JSON number and read back as a Go float64.
_emit_json() {
    local exit_code="$1"
    local status="$2"
    local action="$3"
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
                    ''|*[!0-9-]*) json="$json,\"$(_json_escape "$key")\":\"$(_json_escape "$value")\"" ;;
                    *) json="$json,\"$(_json_escape "$key")\":$value" ;;
                esac
                ;;
            b)
                case "$value" in
                    true|false) json="$json,\"$(_json_escape "$key")\":$value" ;;
                    *) json="$json,\"$(_json_escape "$key")\":\"$(_json_escape "$value")\"" ;;
                esac
                ;;
            s|*)
                json="$json,\"$(_json_escape "$key")\":\"$(_json_escape "$value")\""
                ;;
        esac
    done

    json="$json}"
    printf '%s\n' "$json"
    exit "$exit_code"
}

# ============================================================
# [6] Timeout wrapper
# ============================================================
# Preference: standalone `timeout` → `busybox timeout` → none.
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout"
elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q "^timeout$"; then
    TIMEOUT_CMD="busybox timeout"
fi

# _run_pm <args...>
#
# Wraps a pm/package-manager invocation in a timeout computed
# from the remaining cascade budget:
#
#   effective_timeout = min(STRATEGY_TIMEOUT, _CASCADE_DEADLINE - now)
#
# This bounds EVERY subprocess, including the three sub-commands
# of strategy 3, so the cascade cannot exceed _CASCADE_DEADLINE
# regardless of how many `pm` calls a strategy issues.
#
# When the remaining budget is below MIN_STRATEGY_BUDGET, the
# call short-circuits with exit code 124 (the same code that
# `timeout` returns on expiry) so callers see a consistent
# signal.
_run_pm() {
    local _now _remaining
    _now=$(date +%s)
    _remaining=$(( _CASCADE_DEADLINE - _now ))

    if [ "$_remaining" -lt "$MIN_STRATEGY_BUDGET" ]; then
        return 124
    fi
    [ "$_remaining" -gt "$STRATEGY_TIMEOUT" ] && _remaining="$STRATEGY_TIMEOUT"

    if [ -n "$TIMEOUT_CMD" ]; then
        # shellcheck disable=SC2086  # TIMEOUT_CMD is a deliberate word-split
        $TIMEOUT_CMD "$_remaining" "$@"
    else
        "$@"
    fi
}

# ============================================================
# [7] Package detection
# ============================================================
COMPANION_PKG=""

_detect_companion_pkg() {
    local _p
    for _p in $COMPANION_PKG_CANDIDATES; do
        if pm list packages 2>/dev/null | grep -qFx "package:$_p"; then
            printf '%s' "$_p"
            return 0
        fi
    done
    printf '%s' "com.gasciljh.dnsproxy.debug"
    return 0
}

COMPANION_PKG="$(_detect_companion_pkg)"

# Re-run detection. Called before each poll iteration and by
# the outer cascade loop after a strategy reports success.
_refresh_companion_pkg() {
    local _new_pkg
    _new_pkg="$(_detect_companion_pkg)"
    if [ -n "$_new_pkg" ]; then
        COMPANION_PKG="$_new_pkg"
    fi
}

_pkg_installed() {
    pm list packages 2>/dev/null | grep -qFx "package:$COMPANION_PKG"
}

_pkg_version_name() {
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

# _wait_for_install [timeout_seconds] [deadline_epoch]
#
# Polls `pm list packages` until the package appears or the
# timeout / absolute deadline is hit. Some ROMs return
# "Success" from `pm install` but delay package registration.
#
# Two independent bounds:
#   • _i < _timeout            (iteration count; `while` condition)
#   • now >= _deadline         (wall-clock; checked each iteration)
_wait_for_install() {
    local _timeout="${1:-15}"
    local _deadline="${2:-0}"
    local _i=0
    while [ "$_i" -lt "$_timeout" ]; do
        if [ "$_deadline" -gt 0 ] 2>/dev/null; then
            local _now
            _now=$(date +%s 2>/dev/null)
            case "$_now" in ''|*[!0-9]*) _now=0 ;; esac
            if [ "$_now" -gt 0 ] && [ "$_now" -ge "$_deadline" ]; then
                return 1
            fi
        fi

        _refresh_companion_pkg
        if _pkg_installed; then
            return 0
        fi
        sleep 1
        _i=$((_i + 1))
    done
    return 1
}

# ============================================================
# [8] App version reader
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
# [9] MODE: --status
# ============================================================
if [ "$MODE" = "status" ]; then
    _refresh_companion_pkg
    if _pkg_installed; then
        _vname=$(_pkg_version_name)
        log_msg "STATUS: installed (versionName=$_vname, expected=$APP_VERSION)"
        _emit_json 0 "ok" "status" \
            "b:installed=true" \
            "s:package=$COMPANION_PKG" \
            "s:version_name=$_vname" \
            "s:expected_version=$APP_VERSION"
    else
        log_msg "STATUS: not installed"
        _emit_json 4 "ok" "status" \
            "b:installed=false" \
            "s:package=$COMPANION_PKG" \
            "s:expected_version=$APP_VERSION"
    fi
fi

# ============================================================
# [10] MODE: --uninstall
# ============================================================
if [ "$MODE" = "uninstall" ]; then
    _refresh_companion_pkg
    if ! _pkg_installed; then
        log_msg "UNINSTALL: not installed, nothing to do"
        _emit_json 4 "ok" "uninstall" \
            "s:package=$COMPANION_PKG" \
            "s:message=not_installed"
    fi

    log_msg "UNINSTALL: removing $COMPANION_PKG"

    if _out=$(_run_pm pm uninstall "$COMPANION_PKG" 2>&1); then
        log_msg "UNINSTALL: success"
        _emit_json 0 "ok" "uninstall" \
            "s:package=$COMPANION_PKG" \
            "s:message=uninstalled"
    else
        _rc=$?
        log_msg "UNINSTALL: failed (rc=$_rc): $_out"
        _emit_json 2 "error" "uninstall" \
            "s:package=$COMPANION_PKG" \
            "s:message=uninstall_failed" \
            "s:details=$_out"
    fi
fi

# ============================================================
# [11] MODE: install — pre-flight checks
# ============================================================
log_msg "INSTALL: starting (app-version=$APP_VERSION, moddir=$MODDIR)"

if [ ! -f "$APK_PATH" ]; then
    log_msg "INSTALL: APK not found at $APK_PATH"
    _emit_json 1 "error" "install" \
        "s:reason=apk_not_found" \
        "s:message_ar=الملف المرافق للتطبيق غير موجود في الوحدة" \
        "s:message_en=Companion APK not found in the module" \
        "s:hint_ar=أعد تثبيت الوحدة" \
        "s:hint_en=Reinstall the module"
fi

if [ ! -s "$APK_PATH" ]; then
    log_msg "INSTALL: APK is empty"
    _emit_json 1 "error" "install" \
        "s:reason=apk_empty" \
        "s:message_ar=الملف المرافق فارغ — أعد تثبيت الوحدة" \
        "s:message_en=Companion APK is empty — reinstall the module"
fi

APK_SIZE=$(wc -c < "$APK_PATH" 2>/dev/null | tr -d ' ')
case "$APK_SIZE" in
    ''|*[!0-9]*) APK_SIZE=0 ;;
esac

if [ "$APK_SIZE" -lt "$MIN_APK_BYTES" ]; then
    log_msg "INSTALL: APK too small ($APK_SIZE bytes < $MIN_APK_BYTES)"
    _emit_json 1 "error" "install" \
        "s:reason=apk_too_small" \
        "n:size=$APK_SIZE" \
        "s:message_ar=الملف المرافق صغير جدًا — قد يكون تالفًا" \
        "s:message_en=Companion APK is suspiciously small — likely corrupt"
fi

if command -v od >/dev/null 2>&1; then
    _magic=$(od -An -N2 -tx1 "$APK_PATH" 2>/dev/null | tr -d ' \n')
    if [ "$_magic" != "504b" ]; then
        log_msg "INSTALL: APK is not a valid ZIP (magic=$_magic)"
        _emit_json 1 "error" "install" \
            "s:reason=apk_not_zip" \
            "s:message_ar=الملف المرافق ليس ملف APK صالح — أعد تثبيت الوحدة" \
            "s:message_en=Companion APK is not a valid ZIP archive — reinstall the module"
    fi
fi

SHA_VERIFIED=0
if [ -f "$SHA_PATH" ] && command -v sha256sum >/dev/null 2>&1; then
    _expected=$(awk '{print $1}' "$SHA_PATH" 2>/dev/null | head -n1 | tr -d '\r\n ')
    _actual=$(sha256sum "$APK_PATH" 2>/dev/null | awk '{print $1}')

    if [ -n "$_expected" ] && [ -n "$_actual" ]; then
        if [ "$_expected" != "$_actual" ]; then
            log_msg "INSTALL: SHA256 mismatch (expected=${_expected:0:16}... actual=${_actual:0:16}...)"
            _emit_json 1 "error" "install" \
                "s:reason=sha_mismatch" \
                "s:message_ar=فشل التحقق من سلامة الملف — أعد تثبيت الوحدة" \
                "s:message_en=Integrity check failed — reinstall the module"
        fi
        SHA_VERIFIED=1
        log_msg "INSTALL: SHA256 verified"
    fi
elif [ ! -f "$SHA_PATH" ]; then
    log_msg "INSTALL: SHA256 sidecar missing — skipping verification (advisory)"
else
    log_msg "INSTALL: sha256sum unavailable — cannot verify APK integrity (advisory)"
fi

if command -v df >/dev/null 2>&1; then
    _free_kb=$(df -k /data 2>/dev/null | awk 'NR==2 {print $4}')
    case "$_free_kb" in
        ''|*[!0-9]*) _free_kb=0 ;;
    esac
    _needed_kb=$(( (APK_SIZE / 1024) * SPACE_MULTIPLIER ))
    if [ "$_free_kb" -gt 0 ] && [ "$_free_kb" -lt "$_needed_kb" ]; then
        log_msg "INSTALL: insufficient storage (free=${_free_kb}KB, needed=${_needed_kb}KB)"
        _emit_json 1 "error" "install" \
            "s:reason=insufficient_storage" \
            "n:free_kb=$_free_kb" \
            "n:needed_kb=$_needed_kb" \
            "s:message_ar=المساحة غير كافية — حرّر ما لا يقل عن 50 ميجابايت" \
            "s:message_en=Insufficient storage — free at least 50 MB"
    fi
fi

# ============================================================
# [12] Cleanup infrastructure (Play Protect + staged APK)
# ============================================================
# Installed BEFORE any irreversible state change. Otherwise a
# signal arriving between the `settings put` and the trap
# installation would leave Play Protect permanently disabled.
_STAGED_OK=0
_CLEANED_UP=0

# _VERIFIER_RESTORE
#   0 = verifier untouched; cleanup does NOT modify it.
#   1 = verifier disabled by this script; cleanup MUST restore.
#
# _VERIFIER_ORIG
#   The exact value captured BEFORE the change. One of:
#     "0"    — was disabled
#     "1"    — was enabled
#     "null" — key was unset (cleanup uses `settings delete`)
#     ""     — read failed (treated as "do not touch")
_VERIFIER_RESTORE=0
_VERIFIER_ORIG=""

# _read_verifier_state — read package_verifier_enable with
# retries. The settings service may not be ready immediately
# after boot.
#
# Output (stdout):
#   "0" | "1"  — value captured
#   "null"     — settings answered, key is unset
#   ""         — settings did not answer within the retry window
_read_verifier_state() {
    local _try=0
    local _raw=""

    while [ "$_try" -lt 5 ]; do
        _raw=$(settings get global package_verifier_enable 2>/dev/null)
        case "$_raw" in
            ''|'null')
                if [ "$_raw" = "null" ]; then
                    printf 'null'
                    return 0
                fi
                ;;
            *)
                _raw=$(printf '%s' "$_raw" | tr -d '\r\n ')
                printf '%s' "$_raw"
                return 0
                ;;
        esac
        sleep 1
        _try=$((_try + 1))
    done

    printf ''
    return 1
}

# _cleanup_app — idempotent cleanup handler. Runs exactly once
# even when the INT/TERM handler's `exit` fires the EXIT
# handler (POSIX requires EXIT to fire on every exit path).
#
# shellcheck disable=SC2329  # invoked via trap below
_cleanup_app() {
    if [ "$_CLEANED_UP" = "1" ]; then
        return 0
    fi
    _CLEANED_UP=1

    if [ "$_STAGED_OK" = "1" ] && [ -f "$STAGING_APK" ]; then
        rm -f "$STAGING_APK" 2>/dev/null
    fi

    if [ "$_VERIFIER_RESTORE" = "1" ]; then
        case "$_VERIFIER_ORIG" in
            "0"|"1")
                settings put global package_verifier_enable "$_VERIFIER_ORIG" 2>/dev/null
                ;;
            "null")
                settings delete global package_verifier_enable 2>/dev/null
                ;;
        esac
    fi

    return 0
}

# Three separate handlers so the INT and TERM cases terminate
# with the conventional exit codes. Without the explicit `exit`,
# POSIX sh would resume execution after the trap body returns —
# the cascade would continue with the verifier disabled.
trap '_cleanup_app' EXIT
trap '_cleanup_app; exit 130' INT
trap '_cleanup_app; exit 143' TERM

_VERIFIER_ORIG=$(_read_verifier_state 2>/dev/null)

case "$_VERIFIER_ORIG" in
    "1")
        if settings put global package_verifier_enable 0 2>/dev/null; then
            _VERIFIER_RESTORE=1
            log_msg "INSTALL: Play Protect verifier disabled (will restore to 1)"
        else
            log_msg "INSTALL: could not disable Play Protect verifier (continuing)"
        fi
        ;;
    "0")
        log_msg "INSTALL: Play Protect verifier already disabled"
        ;;
    "null")
        if settings put global package_verifier_enable 0 2>/dev/null; then
            _VERIFIER_RESTORE=1
            log_msg "INSTALL: Play Protect verifier disabled (will delete key on restore)"
        else
            log_msg "INSTALL: could not disable Play Protect verifier (continuing)"
        fi
        ;;
    *)
        log_msg "INSTALL: package_verifier_enable unreadable — not touching it"
        _VERIFIER_RESTORE=0
        _VERIFIER_ORIG=""
        ;;
esac

# ============================================================
# [13] SELinux context preparation
# ============================================================
# NEVER run `setenforce 0`.
#
# /data/adb/ is mounted with a fixed SELinux context
# (adb_data_file) that system_server CANNOT read. restorecon
# and chcon cannot change it because the mount option
# `context=` overrides per-file labels.
#
# Fix: copy the APK to /data/local/tmp/ (shell_data_file).
if cp -f "$APK_PATH" "$STAGING_APK" 2>/dev/null; then
    chmod 0644 "$STAGING_APK" 2>/dev/null
    _staged_ctx=$(ls -Z "$STAGING_APK" 2>/dev/null | awk '{print $1}')
    log_msg "INSTALL: APK staged to $STAGING_APK (context: ${_staged_ctx:-unknown})"
    APK_PATH="$STAGING_APK"
    _STAGED_OK=1
else
    log_msg "INSTALL: staging to /data/local/tmp failed — using original path"
fi

# ============================================================
# [14] Cascade install (5 levels)
# ============================================================
# First strategy that produces a success (verified by
# `pm list packages`, NOT by stdout) wins.
STRATEGY_USED=0
STRATEGY_OUTPUT=""

# --- Strategy 1: pm install -r ---
_strategy_1() {
    log_msg "INSTALL: strategy 1 — pm install -r --user 0"
    STRATEGY_OUTPUT=$(_run_pm pm install -r --user 0 "$APK_PATH" 2>&1)
    _pkg_installed
}

# --- Strategy 2: pm install -r -i com.android.shell ---
# Some MIUI variants allow installs attributed to the shell.
_strategy_2() {
    log_msg "INSTALL: strategy 2 — pm install -i com.android.shell"
    STRATEGY_OUTPUT=$(_run_pm pm install -r --user 0 -i com.android.shell "$APK_PATH" 2>&1)
    _pkg_installed
}

# --- Strategy 3: session-based install ---
# Bypasses some Android 14+ verification hooks. Each step is
# bounded by _run_pm's budget check.
_strategy_3() {
    log_msg "INSTALL: strategy 3 — session-based install"

    local _session
    _session=$(_run_pm pm install-create -r --user 0 2>/dev/null | grep -oE '\[[0-9]+\]' | tr -d '[]')

    if [ -z "$_session" ]; then
        STRATEGY_OUTPUT="install-create failed"
        return 1
    fi

    log_msg "INSTALL: session id = $_session"

    if ! _run_pm pm install-write "$_session" base "$APK_PATH" >/dev/null 2>&1; then
        STRATEGY_OUTPUT="install-write failed"
        _run_pm pm install-abandon "$_session" >/dev/null 2>&1
        return 1
    fi

    STRATEGY_OUTPUT=$(_run_pm pm install-commit "$_session" 2>&1)
    _pkg_installed
}

# --- Strategy 4: magisk su (Magisk-only) ---
_strategy_4() {
    if ! command -v magisk >/dev/null 2>&1; then
        STRATEGY_OUTPUT="magisk not available"
        return 1
    fi

    log_msg "INSTALL: strategy 4 — magisk su"
    STRATEGY_OUTPUT=$(_run_pm magisk su -c "pm install -r --user 0 '$APK_PATH'" 2>&1)
    _pkg_installed
}

# --- Strategy 5: cmd package install ---
_strategy_5() {
    log_msg "INSTALL: strategy 5 — cmd package install"
    STRATEGY_OUTPUT=$(_run_pm cmd package install -r --user 0 "$APK_PATH" 2>&1)
    _pkg_installed
}

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

for _strategy in 1 2 3 4 5; do
    if [ "$(date +%s)" -ge "$_CASCADE_DEADLINE" ]; then
        STRATEGY_OUTPUT="cascade timeout (${CASCADE_DEADLINE_SECONDS}s deadline reached before strategy $_strategy)"
        log_msg "INSTALL: cascade deadline reached — aborting loop"
        break
    fi

    if _attempt "$_strategy"; then
        _refresh_companion_pkg
        if _pkg_installed; then
            STRATEGY_USED="$_strategy"
            log_msg "INSTALL: strategy $_strategy succeeded (pkg=$COMPANION_PKG)"
            break
        fi
    fi
    log_msg "INSTALL: strategy $_strategy reported failure (output: ${STRATEGY_OUTPUT:0:200})"

    if _wait_for_install 15 "$_CASCADE_DEADLINE"; then
        STRATEGY_USED="$_strategy"
        log_msg "INSTALL: strategy $_strategy registered after delay (pkg=$COMPANION_PKG)"
        break
    fi
done

# ============================================================
# [15] Cascade result handling
# ============================================================
# 8-case error translation (AR + EN). The final catch-all
# covers Android 14+ builds that emit INSTALL_FAILED_INTERNAL_ERROR
# when the Play Protect verifier was unreachable.
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
        *INSTALL_FAILED_INTERNAL_ERROR*)
            _err_ar="خطأ داخلي — قد يكون Play Protect غير متاح"
            _err_en="Internal error — Play Protect may be unreachable"
            _hint_ar="أعد تشغيل الجهاز ثم حاول مرة أخرى"
            _hint_en="Reboot the device and retry"
            ;;
    esac

    _sha_verified_json="false"
    if [ "$SHA_VERIFIED" = "1" ]; then
        _sha_verified_json="true"
    fi

    log_msg "INSTALL: all strategies failed; translated error = $_err_en"
    _emit_json 2 "error" "install" \
        "s:reason=all_strategies_failed" \
        "s:message_ar=$_err_ar" \
        "s:message_en=$_err_en" \
        "s:hint_ar=$_hint_ar" \
        "s:hint_en=$_hint_en" \
        "s:last_output=${STRATEGY_OUTPUT:0:300}" \
        "b:sha_verified=$_sha_verified_json"
fi

# ============================================================
# [16] Post-install verification
# ============================================================
# Extracts the installed `versionName` and returns it. The
# comparison against expected_version is performed by the WebUI.
_refresh_companion_pkg
_vname=$(_pkg_version_name)

if [ "$_vname" = "unknown" ]; then
    log_msg "INSTALL: success (versionName unavailable)"
else
    log_msg "INSTALL: success (versionName=$_vname)"
fi

# ============================================================
# [17] Final JSON output
# ============================================================
_sha_verified_json="false"
if [ "$SHA_VERIFIED" = "1" ]; then
    _sha_verified_json="true"
fi

_emit_json 0 "ok" "install" \
    "n:strategy=$STRATEGY_USED" \
    "s:package=$COMPANION_PKG" \
    "s:version_name=$_vname" \
    "s:expected_version=$APP_VERSION" \
    "n:apk_size=$APK_SIZE" \
    "b:sha_verified=$_sha_verified_json" \
    "s:message_ar=تم تثبيت التطبيق بنجاح" \
    "s:message_en=Companion app installed successfully"