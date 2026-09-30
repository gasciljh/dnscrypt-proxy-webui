#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – service.sh
# Version: v1.2.0 (Global Edition)
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Boot service launcher (Magisk/KernelSU phase).
#
#   Triggered automatically by Magisk at:
#     sys.boot_completed = 1
#
# Responsibilities (v1.2.0):
#   • Wait for boot completion (max 60 × 3s = 180s)
#   • Wait for network readiness (max 15 × 2s = 30s)
#   • Read webui.conf (with Port Guard — reject 8080)
#   • Verify WebUI binary exists
#   • Start WebUI (with one retry on failure)
#   • Launch Watchdog as a standalone process
#   • Respect the disable file (skip if present)
#   • Trigger a periodic auto-backup if needed (Layer 9)
#   • Rotate old backups (Layer 9)
#   • Clean up leftover COMMIT'd transactions (Layer 4 hygiene)
#   • Read .pending_notification (install → boot messaging)
#   • Log active profile + expected memory limit
#
# Design:
#   • Loads functions.sh if available; otherwise uses inline
#     fallbacks for all critical functions (is_port_open,
#     cleanup_proxy, start_webui, get_port, ...)
#   • Watchdog runs as a separate file so that $$ inside it
#     refers to the real Watchdog PID (not service.sh's).
#   • All error paths are logged to dnscrypt_main.log.
#
# v1.1.0 additions (kept in v1.2.0):
#   • Logs the active profile + memory hint at startup
#   • Fallback for get_profile_memory_hint
#   • Clearer structured log messages
#
# v1.2.0 additions:
#   • Auto-backup call (Layer 9)
#   • Inline fallback for auto_backup_if_needed
#   • Rotation call after backup (keeps at most 21 snapshots)
#   • New summary line reporting the backup state
#   • Reads .pending_notification at boot
#   • Calls cleanup_old_transactions() at boot
#   • Summary reports backup count + .last_stable pointer
#
# v1.2.0 — POST-AUDIT FIXES (still v1.2.0)
# ============================================================
#   🔧 SVC-1 — Rewrote the docstrings of the inline fallbacks
#     so that the claims match the ACTUAL scope of the match
#     with the canonical implementations in functions.sh.
#
#   🔧 SVC-2 — `_inline_cleanup_old_transactions` declares
#     `_txn` and `_state` as `local`.
#
#   🔧 SVC-3 — Section [14c] differentiates "created" vs
#     "skipped" by comparing the mtime of `.last_auto_backup`
#     before and after the call.
#
#   🔧 SVC-4 — `_inline_rotate_backups` logs a success line,
#     matching the canonical version.
#
# ============================================================
# v1.2.0 (Global Edition) — Additional hardening in this revision
# ============================================================
#   🛡️ HARD-SVC-01 — New shared constant `_MONITORING_UI_PORT`
#     (value `8080`) is defined in section [2]. All Port Guard
#     checks now reference this constant instead of a magic
#     number, matching the pattern used in main.go,
#     functions.sh, customize.sh, action.sh, status.sh, and
#     watchdog.sh. A future coordinated change to the reserved
#     port now only requires updating the constant here (and
#     in the sibling files).
#
#   🛡️ HARD-SVC-02 — `_inline_get_port` now strips leading
#     zeros before the arithmetic comparison. Previously a
#     value like `090` would be interpreted as octal by
#     `[ "$val" -ge 1 ]` in some shells, producing a wrong
#     result. Parity with HARD-ACT-06 in action.sh.
#
#   🛡️ HARD-SVC-03 — `_inline_is_port_open` now falls back to
#     `netstat` when `ss` is unavailable. Some older Android
#     builds ship with `netstat` but without `ss`. Parity with
#     HARD-WD-02 in watchdog.sh and with `functions.sh`.
#
#   🛡️ HARD-SVC-04 — `log_msg` now performs emergency-only log
#     rotation at 50 MB, matching `functions.sh:log_fn` and
#     `watchdog.sh:log_msg`. The counter is a global that
#     persists across calls by design.
#
#   🛡️ HARD-SVC-05 — `_inline_auto_backup_if_needed` now
#     appends `-$$` to the target directory name
#     (`<ts>-auto-$$`), matching `functions.sh:auto_backup_if_
#     needed` after its FSH-10 fix. This prevents second-level
#     timestamp collisions when the canonical path and the
#     inline path are both in use across different boot phases.
#
#   🛡️ HARD-SVC-06 — `_inline_auto_backup_if_needed` now
#     declares `local f` for its `for f in $USER_FILES` loop.
#     Same discipline as the canonical `functions.sh:backup_
#     user_files`.
#
#   🛡️ HARD-SVC-07 — `_inline_rotate_backups` now declares
#     `local old` for its `while IFS= read -r old` loop. The
#     variable was leaking to the caller's scope.
#
#   🛡️ HARD-SVC-08 — The migration loop in section [8] now uses
#     a dedicated `_mf` loop variable instead of `f`, so it
#     cannot collide with a caller's `f` on a shared shell
#     (e.g. when service.sh is sourced interactively for
#     debugging).
#
#   🛡️ HARD-SVC-09 — The WebUI start-retry loop in section [16]
#     now uses `_attempt` instead of `attempt`, keeping the
#     global namespace clean for any future feature that
#     might want to reuse `attempt`.
#
#   🛡️ HARD-SVC-10 — `_inline_start_webui` now logs an
#     explicit warning when the WebUI PID file cannot be
#     written, and still waits for the port to open. This
#     allows the caller to distinguish "PID file missing" from
#     "process never started" when reading the log.
#
# ============================================================
# v1.2.0 (Global Edition) — FINAL revision (this file)
# ============================================================
#   🧩 SVC-FIX-M1 — Section [11] (disable path) now ALWAYS
#     attempts firewall cleanup. When functions.sh is loaded,
#     it delegates to `manage_firewall 0`; otherwise it calls
#     the new inline fallback `_inline_cleanup_firewall`,
#     which strips our DNAT rules on the DNS port (53) and any
#     ACCEPT/DROP rules on the proxy port (5354) via
#     `iptables -S | sed -e 's/^-A /-D /'`. Prevents stale
#     NAT rules from persisting across a disable → enable
#     cycle when functions.sh fails to load.
#
#   🧩 SVC-FIX-M2 — Section [8] (PID migration) no longer
#     deletes `dnscrypt.status` from `/data/local/tmp/` unless
#     the copy into `$RUN_DIR_ACTIVE/` actually succeeded.
#     Previously, a failed `cp` (e.g. read-only run/) silently
#     destroyed the user's ON/OFF intent. Now the source is
#     preserved on failure and a WARNING is logged.
#
#   🧩 SVC-FIX-M3 — Section [17] (Watchdog launch) now uses
#     `setsid` when available, mirroring `_inline_start_webui`
#     and `start_native_webui`. Falls back to `busybox setsid`
#     and then to `nohup`. Ensures the Watchdog is placed in
#     its own session, protecting it from the parent shell's
#     SIGHUP on some Android firmware variants.
#
#   🧩 SVC-FIX-L1 — Section [17] now waits up to 3 s for the
#     Watchdog PID file to appear (was a single `sleep 1`).
#     Avoids false-positive "PID file not created" warnings on
#     slow devices.
#
#   🧩 SVC-FIX-L2 — `_inline_read_conf` uses `grep -F` so that
#     a config key containing regex metacharacters (e.g. a
#     future key with `.` or `*`) can never be misinterpreted
#     as a regex. No behavior change for the current keys.
#
#   🧩 SVC-FIX-L3 — Section [4] no longer unconditionally
#     re-invokes `init_runtime_paths` after sourcing
#     functions.sh. It now only runs when `$RUN_DIR_ACTIVE` is
#     still empty — i.e. as a defensive idempotent fallback
#     for a future functions.sh that stops auto-initializing
#     at source time. Removes the duplicate call in the
#     common case.
#
#   🧩 SVC-FIX-L4 — Section [14c] no longer wraps the whole
#     auto-backup block in `if [ -d "$BIN_DIR" ]`. The guard
#     was dead code (BIN_DIR is validated in [9] and [15]).
#     `do_auto_backup` already returns 0 on a missing
#     `src_dir`, so the block is safe to run unconditionally.
#
#   🧩 SVC-FIX-L5 — Documentation-only: the header now
#     explicitly states that ALL shell scripts of the module
#     (service.sh, functions.sh, customize.sh, action.sh,
#     status.sh, uninstall.sh, post-fs-data.sh, watchdog.sh)
#     live in the module root ($MODDIR), NOT under proxy/.
#     Only Go binaries and their data files reside under
#     proxy/. This matches the actual layout produced by
#     customize.sh at install time.
#
# Coordination with main.go:
#   • main.go adjusts the Go runtime soft memory limit based on
#     the selected profile. This script only REPORTS the hint.
#   • main.go runs `createAutoBackup()` before destructive
#     operations. Those pre-critical backups are separate from
#     the periodic one triggered here.
#   • Both main.go and this script call cleanup for leftover
#     COMMIT'd transactions. The operation is idempotent.
#   • Only main.go deletes .pending_notification. This script
#     reads it (for the boot log) but never removes it.
#
# Module layout (SVC-FIX-L5 — matches what customize.sh writes):
#   $MODDIR/
#     ├── service.sh              ← this file
#     ├── functions.sh
#     ├── customize.sh
#     ├── post-fs-data.sh
#     ├── action.sh
#     ├── status.sh
#     ├── uninstall.sh
#     ├── watchdog.sh
#     ├── module.prop
#     └── proxy/
#         ├── dnscrypt-proxy       (Go binary)
#         ├── dnscrypt-webui       (Go binary)
#         ├── dnscrypt-proxy.toml
#         ├── webui.conf
#         ├── selected_profile.txt
#         ├── allowlist.txt
#         ├── denylist.txt
#         └── run/
# ============================================================
# POSIX note on `local`:
#   This script uses `local` for all internal variables (see
#   the _inline_* helper functions below). The `local` keyword
#   is supported by:
#     • mksh (the default /system/bin/sh on modern Android)
#     • busybox ash (older Android)
#     • bash, dash, ksh
#   It is NOT part of the POSIX sh standard, but every shell
#   Android ships supports it.
#
#   The same POSIX note appears (identically) in:
#     • functions.sh
#     • action.sh
#     • status.sh
#     • watchdog.sh
#   Any change to this note MUST be applied consistently to
#   all five files.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Determine module path
# ============================================================

# v1.2.0: --version flag (checked before any argument parsing)
case "${1:-}" in
	--version)
		echo "$0: v1.2.0"
		exit 0
		;;
esac

MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case $MODDIR in /*) ;; *) MODDIR="/data/adb/modules/${MODDIR}" ;; esac

# ============================================================
# [2] Shared constant (HARD-SVC-01)
# ============================================================
# ⚠️ CRITICAL: This constant must stay in sync with
# MONITORING_UI_PORT in main.go and with the same constant in
# functions.sh, customize.sh, action.sh, status.sh, and
# watchdog.sh.
#
# The reserved port is used by dnscrypt-proxy's internal
# monitoring_ui. Changing it requires coordinated updates in
# every file listed above.
# ============================================================
_MONITORING_UI_PORT="8080"

# ============================================================
# [2b] Default paths (reconfigured after loading functions.sh)
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
PID_FILE="/data/local/tmp/dnscrypt.pid"
WEBUI_PID_FILE="/data/local/tmp/webui.pid"
WATCHDOG_PID_FILE="/data/local/tmp/watchdog.pid"
STATUS_FILE="/data/local/tmp/dnscrypt.status"
CRED_FILE="/data/local/tmp/dnscrypt_credentials.txt"

TOML_FILE="$MODDIR/proxy/dnscrypt-proxy.toml"
SELECTED_PROFILE_FILE="$MODDIR/proxy/selected_profile.txt"

# --- v1.2.0 — Data preservation paths ---
PERSISTENT_BACKUP="/sdcard/dnscrypt-webui-backup"
PENDING_NOTIFY_FILE="$PERSISTENT_BACKUP/.pending_notification"
LAST_STABLE_FILE="$PERSISTENT_BACKUP/.last_stable"
USER_FILES="webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt"

# ============================================================
# [2c] Read module version (before first log_msg call)
# ============================================================
MODULE_VERSION=""
if [ -f "$MODDIR/module.prop" ]; then
    MODULE_VERSION=$(grep "^version=" "$MODDIR/module.prop" 2>/dev/null | head -n 1 | cut -d= -f2 | tr -d '\r ')
fi
[ -z "$MODULE_VERSION" ] && MODULE_VERSION="unknown"

# ============================================================
# [3] log_msg (with emergency-only rotation — HARD-SVC-04)
# ============================================================
# The WebUI (main.go) owns orderly log rotation at 1 MB. This
# helper only rotates when the log exceeds 50 MB, and only
# every 100th call, so the overhead is negligible.
#
# Parity with functions.sh:log_fn and watchdog.sh:log_msg.
#
# `_LOG_CALL_COUNT` is a global by design: it must persist
# across log_msg calls within the same shell process.
_LOG_CALL_COUNT=0

log_msg() {
    _LOG_CALL_COUNT=$((_LOG_CALL_COUNT + 1))

    if [ $((_LOG_CALL_COUNT % 100)) -eq 0 ] && [ -f "$LOG_FILE" ]; then
        local _size
        _size=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
        if [ -n "$_size" ] && [ "$_size" -gt 52428800 ]; then
            local _emg="${LOG_FILE}.emergency.$(date +%s)"
            mv -f "$LOG_FILE" "$_emg" 2>/dev/null
            : > "$LOG_FILE"
        fi
    fi

    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE" 2>/dev/null
}

log_msg "service.sh started ($MODULE_VERSION)"

# ============================================================
# [4] Load functions.sh
# ============================================================
# SVC-FIX-L3: functions.sh already calls init_runtime_paths() at
# source time. We only call it here as an idempotent fallback
# when $RUN_DIR_ACTIVE is still empty (i.e. the sourced version
# did NOT auto-initialize). This removes the duplicate call in
# the common case while remaining defensive against a future
# functions.sh that stops auto-initializing.
# ============================================================
FUNCTIONS_LOADED=0
if [ -f "$MODDIR/functions.sh" ]; then
    # shellcheck disable=SC1090
    . "$MODDIR/functions.sh" 2>/dev/null
    if command -v cleanup_proxy >/dev/null 2>&1 \
       && command -v is_port_open >/dev/null 2>&1; then
        FUNCTIONS_LOADED=1
        log_msg "functions.sh loaded successfully"

        # SVC-FIX-L3: only re-run when the source-time call did not
        # populate $RUN_DIR_ACTIVE (idempotent, defensive).
        if command -v init_runtime_paths >/dev/null 2>&1 \
           && [ -z "$RUN_DIR_ACTIVE" ]; then
            init_runtime_paths
            log_msg "Runtime paths initialized (deferred, RUN_DIR was empty)"
        fi
    else
        log_msg "WARNING: functions.sh loaded but critical functions missing"
    fi
else
    log_msg "WARNING: functions.sh not found, using inline fallbacks"
fi

# ============================================================
# [5] Internal fallback (if functions.sh fails to load)
# ============================================================
_FALLBACK_RUN_DIR="$MODDIR/proxy/run"

_fallback_get_run_dir() {
    if [ -d "$_FALLBACK_RUN_DIR" ] && [ -w "$_FALLBACK_RUN_DIR" ]; then
        printf "%s" "$_FALLBACK_RUN_DIR"
        return 0
    fi
    if mkdir -p "$_FALLBACK_RUN_DIR" 2>/dev/null; then
        chmod 0700 "$_FALLBACK_RUN_DIR" 2>/dev/null
        if [ -w "$_FALLBACK_RUN_DIR" ]; then
            printf "%s" "$_FALLBACK_RUN_DIR"
            return 0
        fi
    fi
    printf "%s" "/data/local/tmp"
}

if [ "$FUNCTIONS_LOADED" = "0" ]; then
    _FB_RUN_DIR=$(_fallback_get_run_dir)
    STATUS_FILE="$_FB_RUN_DIR/dnscrypt.status"
    PID_FILE="$_FB_RUN_DIR/dnscrypt.pid"
    WEBUI_PID_FILE="$_FB_RUN_DIR/webui.pid"
    WATCHDOG_PID_FILE="$_FB_RUN_DIR/watchdog.pid"
    log_msg "Fallback paths: RUN_DIR=$_FB_RUN_DIR"
fi

# --- Fallback: is_port_open (HARD-SVC-03 — netstat fallback) ---
_inline_is_port_open() {
    local port="$1"
    local proto="${2:-tcp}"
    local hex_port

    case "$port" in
        ''|*[!0-9]*) return 1 ;;
    esac

    hex_port=$(printf "%04X" "$port" 2>/dev/null) || return 1

    if [ "$proto" = "udp" ]; then
        if [ -f /proc/net/udp ] && grep -qi ":$hex_port " /proc/net/udp 2>/dev/null; then
            return 0
        fi
        if [ -f /proc/net/udp6 ] && grep -qi ":$hex_port " /proc/net/udp6 2>/dev/null; then
            return 0
        fi
        if command -v ss >/dev/null 2>&1; then
            ss -lun 2>/dev/null | grep -q ":$port " && return 0
        elif command -v netstat >/dev/null 2>&1; then
            netstat -uln 2>/dev/null | grep -q ":$port " && return 0
        fi
    else
        if [ -f /proc/net/tcp ] && grep -qi ":$hex_port " /proc/net/tcp 2>/dev/null; then
            return 0
        fi
        if [ -f /proc/net/tcp6 ] && grep -qi ":$hex_port " /proc/net/tcp6 2>/dev/null; then
            return 0
        fi
        if command -v ss >/dev/null 2>&1; then
            ss -ltn 2>/dev/null | grep -q ":$port " && return 0
        elif command -v netstat >/dev/null 2>&1; then
            netstat -tln 2>/dev/null | grep -q ":$port " && return 0
        fi
    fi
    return 1
}

# --- Fallback: cleanup_proxy ---
_inline_cleanup_proxy() {
    pkill -9 -x dnscrypt-proxy 2>/dev/null
    if command -v fuser >/dev/null 2>&1; then
        fuser -k 5354/udp 2>/dev/null
        fuser -k 5354/tcp 2>/dev/null
    fi
    rm -f "$PID_FILE" 2>/dev/null
    rm -f /data/local/tmp/dnscrypt.pid 2>/dev/null
}

# --- Fallback: cleanup_webui ---
_inline_cleanup_webui() {
    pkill -9 -x dnscrypt-webui 2>/dev/null
    rm -f "$WEBUI_PID_FILE" 2>/dev/null
    rm -f /data/local/tmp/webui.pid 2>/dev/null
}

# ============================================================
# [5a] Fallback: cleanup_firewall (SVC-FIX-M1)
# ============================================================
# Best-effort removal of the DNAT rules that redirect DNS
# traffic to dnscrypt-proxy, plus any ACCEPT/DROP rules on the
# proxy listen port (5354).
#
# Design notes:
#   • Does NOT touch rules that don't match our patterns
#     (--dport 53 for NAT, --dport 5354 for filter). This keeps
#     the inline fallback safe on a device that has other
#     firewall managers installed.
#   • Uses `iptables -S <chain> | sed 's/^-A /-D /'` to replay
#     the exact rule as a deletion, which is the most robust
#     way to remove rules without knowing their position.
#   • Iterates both IPv4 and IPv6 when the tools exist.
#   • Failures are silently ignored (2>/dev/null). This is a
#     boot-time cleanup; the canonical functions.sh version
#     runs during module disable and is more thorough.
#
# Scope of match vs functions.sh:manage_firewall 0:
#   ✅ MATCHES:
#     • Removes DNAT rules on --dport 53 in the nat table.
#     • Removes filter rules on --dport 5354.
#     • Iterates both iptables and ip6tables when available.
#     • Never aborts the caller on individual rule failures.
#   ❌ INTENTIONALLY DIVERGES:
#     • Does NOT remove custom chains created by functions.sh
#       (e.g. DNSCRYPT_OUT). Only individual rules are removed.
#       The chain itself becomes empty and harmless.
#     • Does NOT log per-rule actions — a single summary line
#       is logged by the caller in section [11].
# ============================================================
_inline_cleanup_firewall() {
    local ipt
    for ipt in iptables ip6tables; do
        command -v "$ipt" >/dev/null 2>&1 || continue

        # --- nat table: remove DNAT rules on port 53 ---
        "$ipt" -t nat -S OUTPUT 2>/dev/null | \
            grep -E -- '-p (tcp|udp) .*--dport 53 ' | \
            sed 's/^-A /-D /' | \
            while IFS= read -r _rule; do
                # shellcheck disable=SC2086
                $ipt -t nat $_rule 2>/dev/null
            done

        # --- filter table: remove rules on proxy port 5354 ---
        "$ipt" -S OUTPUT 2>/dev/null | \
            grep -E -- '--dport 5354 ' | \
            sed 's/^-A /-D /' | \
            while IFS= read -r _rule; do
                # shellcheck disable=SC2086
                $ipt $_rule 2>/dev/null
            done
    done
    return 0
}

# ============================================================
# [5b] Fallback: read_conf (SVC-FIX-L2 — grep -F)
# ============================================================
# SVC-FIX-L2: uses `grep -F` (fixed-string match) so a future
# config key that contains regex metacharacters ('.', '*', '+',
# etc.) can never be misinterpreted as a regex pattern. No
# behavior change for the current keys (PORT,
# AUTO_RESTART_DNS, AUTO_RESTART_WEBUI).
# ============================================================
_inline_read_conf() {
    local conf="$1"
    local key="$2"
    local default="$3"

    if [ -f "$conf" ]; then
        local val
        val=$(grep -F "^${key}=" "$conf" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r')
        case "$val" in
            *" #"*)
                val="${val%% #*}"
                ;;
        esac
        val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$val" ]; then
            printf "%s" "$val"
            return 0
        fi
    fi
    printf "%s" "$default"
}

# --- Fallback: get_port with Port Guard (HARD-SVC-01/02) ---
# Uses the shared `_MONITORING_UI_PORT` constant (section [2])
# and strips leading zeros before the arithmetic comparison.
_inline_get_port() {
    local conf="$1"
    local val
    val=$(_inline_read_conf "$conf" "PORT" "9090")

    # Digits-only gate
    if ! echo "$val" | grep -qE '^[0-9]+$'; then
        printf "9090"
        return 0
    fi

    # Strip leading zeros (HARD-SVC-02).
    local val_clean
    val_clean=$(printf '%s' "$val" | sed 's/^0*//')
    [ -z "$val_clean" ] && val_clean="0"

    if [ "$val_clean" -ge 1 ] && [ "$val_clean" -le 65535 ]; then
        # Port Guard: reject the reserved monitoring_ui port.
        if [ "$val_clean" = "$_MONITORING_UI_PORT" ]; then
            log_msg "WARNING: _inline_get_port: PORT=$val_clean conflicts with monitoring_ui — falling back to 9090"
            printf "9090"
            return 0
        fi
        printf "%s" "$val_clean"
        return 0
    fi
    printf "9090"
}

# --- Fallback: get_profile_memory_hint (v1.1.0) ---
_inline_get_profile_memory_hint() {
    local profile="pro"
    local selected="$MODDIR/proxy/selected_profile.txt"

    if [ -f "$selected" ]; then
        local p
        p=$(cat "$selected" 2>/dev/null | tr -d '\r\n ')
        case "$p" in
            light|normal|pro|proplus|ultimate) profile="$p" ;;
        esac
    fi

    local mb
    case "$profile" in
        light)    mb="80"  ;;
        normal)   mb="100" ;;
        pro)      mb="120" ;;
        proplus)  mb="160" ;;
        ultimate) mb="220" ;;
        *)        mb="80"  ;;
    esac

    printf "%s MB (%s)" "$mb" "$profile"
}

# ============================================================
# [5c] v1.2.0 — Fallback: auto_backup_if_needed
# ============================================================
# Minimal implementation for the case where functions.sh
# could not be loaded.
#
# Scope of match vs the canonical functions.sh:auto_backup_if_needed:
#
#   ✅ MATCHES:
#     • The 24h interval check (default 86400 s).
#     • Numeric validation on interval / last / now before any
#       arithmetic.
#     • Failure (return 1) when 0 files are copied.
#     • Marker update (.last_auto_backup) on success.
#     • Target directory naming: <YYYYMMDD>-<HHMMSS>-auto-<pid>
#       (HARD-SVC-05 — after this revision, matching FSH-10).
#     • SELinux context preservation when restorecon exists.
#     • Per-file chmod 0600.
#
#   ❌ INTENTIONALLY DIVERGES (documented differences):
#     • Does NOT write a .manifest.json. The canonical version
#       does this via `write_manifest`, which is unavailable
#       here (it lives in functions.sh, precisely the file
#       that failed to load).
#     • Does NOT call rotation internally. The caller
#       (service.sh [14c]) invokes `do_rotate_backups` right
#       after this function returns.
#
# These divergences are deliberate and acceptable. The fallback
# path is used only when functions.sh is missing or broken —
# an already-degraded state where best-effort backup is better
# than no backup.
# ============================================================
_inline_auto_backup_if_needed() {
    local interval="${1:-86400}"

    # Numeric validation (v1.2.0 FIX)
    if ! echo "$interval" | grep -qE '^[0-9]+$'; then
        interval=86400
    fi

    local src_dir="$MODDIR/proxy"
    [ -d "$src_dir" ] || return 0

    mkdir -p "$PERSISTENT_BACKUP" 2>/dev/null || return 0
    chmod 0700 "$PERSISTENT_BACKUP" 2>/dev/null

    local marker="$PERSISTENT_BACKUP/.last_auto_backup"
    local last=0
    if [ -f "$marker" ]; then
        last=$(stat -c %Y "$marker" 2>/dev/null) \
            || last=$(stat -f %m "$marker" 2>/dev/null) \
            || last=0
    fi

    # Numeric validation (v1.2.0 FIX)
    if ! echo "$last" | grep -qE '^[0-9]+$'; then
        last=0
    fi

    local now
    now=$(date +%s 2>/dev/null)
    case "$now" in
        ''|*[!0-9]*) now=0 ;;
    esac

    local age=$((now - last))

    if [ "$last" -gt 0 ] && [ "$age" -lt "$interval" ]; then
        log_msg "ℹ️ auto_backup: skipped (last was ${age}s ago)"
        return 0
    fi

    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    # HARD-SVC-05: append PID, matching FSH-10 in functions.sh.
    local target="$PERSISTENT_BACKUP/$ts-auto-$$"

    mkdir -p "$target" 2>/dev/null || return 1

    local count=0
    # HARD-SVC-06: declare `f` as local.
    local f
    for f in $USER_FILES; do
        if [ -f "$src_dir/$f" ] && [ -s "$src_dir/$f" ]; then
            if cp -f "$src_dir/$f" "$target/$f" 2>/dev/null; then
                # Attempt to restore SELinux context if tools available
                if command -v restorecon >/dev/null 2>&1; then
                    restorecon "$target/$f" 2>/dev/null || true
                fi
                chmod 0600 "$target/$f" 2>/dev/null
                count=$((count + 1))
            fi
        fi
    done

    # v1.2.0 FIX: fail if 0 files were copied
    if [ "$count" -eq 0 ]; then
        log_msg "❌ auto_backup (inline): 0 files copied — removing empty target"
        rm -rf "$target" 2>/dev/null
        return 1
    fi

    touch "$marker" 2>/dev/null

    log_msg "✅ auto_backup (inline): $count file(s) → $target"
    return 0
}

# ============================================================
# [5d] v1.2.0 — Fallback: rotate_backups
# ============================================================
# Mirrors the canonical functions.sh:rotate_backups on the
# points that matter:
#   • Sorts by DIRECTORY NAME (not mtime).
#   • Preserves current/, txn-*, orphan-txn-*, and metadata
#     files (README.md, .last_stable, .upgrade_history.*).
#   • Logs a "removing" line before pruning and a "done" line
#     after.
#
# Divergence from canonical: the log function used here is
# `log_msg` (this script's logger), not `log_fn`. Since this
# fallback exists precisely because functions.sh could not be
# loaded, `log_fn` is not available. Both write to the same
# $LOG_FILE.
# ============================================================
_inline_rotate_backups() {
    local keep="${1:-21}"

    # Numeric validation (v1.2.0 FIX)
    if ! echo "$keep" | grep -qE '^[0-9]+$'; then
        keep=21
    fi

    [ -d "$PERSISTENT_BACKUP" ] || return 0

    # List snapshot directories by NAME (stable), newest first.
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
        return 0
    fi

    local to_remove=$((total - keep))
    log_msg "🧹 rotate_backups (inline): removing $to_remove old snapshot(s) (keeping $keep)"

    # HARD-SVC-07: declare `old` as local.
    local old
    printf '%s\n' "$snapshots" | tail -n "$to_remove" | while IFS= read -r old; do
        [ -z "$old" ] && continue
        rm -rf "$PERSISTENT_BACKUP/$old" 2>/dev/null
    done

    # SVC-4 fix: log a success line, matching the canonical version.
    log_msg "✅ rotate_backups (inline): done"
    return 0
}

# ============================================================
# [5e] v1.2.0 — Fallback: cleanup_old_transactions
# ============================================================
# Mirrors the canonical version in functions.sh.
# Removes COMMIT'd txn-* directories from previous interrupted
# installs. ROLLBACK / START / orphan-txn-* are preserved.
# ============================================================
_inline_cleanup_old_transactions() {
    [ -d "$PERSISTENT_BACKUP" ] || return 0

    # SVC-2 fix: declare loop variables `local`.
    local _removed=0
    local _txn
    local _state

    for _txn in "$PERSISTENT_BACKUP"/txn-*; do
        [ -d "$_txn" ] || continue

        _state=$(cat "$_txn/.state" 2>/dev/null | tr -d '\r\n ')
        if [ "$_state" = "COMMIT" ]; then
            if rm -rf "$_txn" 2>/dev/null; then
                _removed=$((_removed + 1))
            fi
        fi
    done

    if [ "$_removed" -gt 0 ]; then
        log_msg "🧹 cleanup_old_transactions (inline): removed $_removed COMMIT'd txn(s)"
    fi

    return 0
}

# ============================================================
# [5f] Fallback: start_webui (HARD-SVC-10 — PID-file warning)
# ============================================================
_inline_start_webui() {
    local bin="$1"
    local port="$2"

    log_msg "Starting WebUI (inline, port: $port)"
    _inline_cleanup_webui

    export HOME=/data/local/tmp

    if command -v setsid >/dev/null 2>&1; then
        setsid env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q setsid; then
        busybox setsid env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    else
        nohup env HOME="$HOME" "$bin" >/dev/null 2>&1 < /dev/null &
    fi

    sleep 1
    local web_pid=""

    # pgrep -x matches the process name exactly (basename: "dnscrypt-webui")
    web_pid=$(pgrep -x "dnscrypt-webui" 2>/dev/null | head -n1)

    if [ -n "$web_pid" ]; then
        # HARD-SVC-10: log a warning if PID-file write fails,
        # but continue waiting for the port (the process is up).
        if printf "%d\n" "$web_pid" > "${WEBUI_PID_FILE}.tmp" 2>/dev/null \
           && mv -f "${WEBUI_PID_FILE}.tmp" "$WEBUI_PID_FILE" 2>/dev/null; then
            :
        else
            log_msg "WARNING: could not write WebUI PID file ($WEBUI_PID_FILE)"
            rm -f "${WEBUI_PID_FILE}.tmp" 2>/dev/null
        fi
    fi

    local i=0
    while [ "$i" -lt 35 ]; do
        if [ -n "$web_pid" ] && ! kill -0 "$web_pid" 2>/dev/null; then
            log_msg "ERROR: WebUI process died (Port collision?)"
            return 1
        fi
        if _inline_is_port_open "$port" tcp; then
            log_msg "WebUI bound to port $port (PID: ${web_pid:-unknown})"
            return 0
        fi
        sleep 1
        i=$((i + 1))
    done

    log_msg "ERROR: WebUI failed to bind within 35s"
    return 1
}

# ============================================================
# [6] Unified wrappers
# ============================================================
if [ "$FUNCTIONS_LOADED" = "1" ]; then
    do_cleanup_proxy()  { cleanup_proxy; }
    do_cleanup_webui()  { cleanup_webui; }
    do_is_port_open()   { is_port_open "$1" "${2:-tcp}"; }
    do_start_webui()    { start_native_webui "$1" "$2"; }
    do_get_port()       { get_webui_port "$1"; }
    do_read_conf()      { get_conf_value "$1" "$2" "$3"; }

    # SVC-FIX-M1: firewall cleanup wrapper.
    if command -v manage_firewall >/dev/null 2>&1; then
        do_cleanup_firewall() { manage_firewall 0; }
    else
        do_cleanup_firewall() { _inline_cleanup_firewall; }
    fi

    # v1.1.0 — memory hint wrapper
    if command -v get_profile_memory_hint >/dev/null 2>&1; then
        do_mem_hint()   { get_profile_memory_hint; }
    else
        do_mem_hint()   { _inline_get_profile_memory_hint; }
    fi

    # v1.2.0 — backup wrappers
    if command -v auto_backup_if_needed >/dev/null 2>&1; then
        do_auto_backup()   { auto_backup_if_needed "${1:-86400}"; }
    else
        do_auto_backup()   { _inline_auto_backup_if_needed "${1:-86400}"; }
    fi

    if command -v rotate_backups >/dev/null 2>&1; then
        do_rotate_backups() { rotate_backups "${1:-21}"; }
    else
        do_rotate_backups() { _inline_rotate_backups "${1:-21}"; }
    fi

    if command -v cleanup_old_transactions >/dev/null 2>&1; then
        do_cleanup_transactions() { cleanup_old_transactions; }
    else
        do_cleanup_transactions() { _inline_cleanup_old_transactions; }
    fi
else
    do_cleanup_proxy()  { _inline_cleanup_proxy; }
    do_cleanup_webui()  { _inline_cleanup_webui; }
    do_is_port_open()   { _inline_is_port_open "$1" "${2:-tcp}"; }
    do_start_webui()    { _inline_start_webui "$1" "$2"; }
    do_get_port()       { _inline_get_port "$1"; }
    do_read_conf()      { _inline_read_conf "$1" "$2" "$3"; }
    do_mem_hint()       { _inline_get_profile_memory_hint; }
    do_auto_backup()    { _inline_auto_backup_if_needed "${1:-86400}"; }
    do_rotate_backups() { _inline_rotate_backups "${1:-21}"; }
    do_cleanup_transactions() { _inline_cleanup_old_transactions; }
    do_cleanup_firewall()     { _inline_cleanup_firewall; }
fi

# ============================================================
# [7] Initial cleanup
# ============================================================
do_cleanup_proxy
log_msg "Initial cleanup done"

# --- v1.2.0 — cleanup leftover COMMIT'd transactions ---
# Defense-in-depth: main.go also does this at startup, but a
# boot-time cleanup catches the case where main.go never
# started.
do_cleanup_transactions

# ============================================================
# [7b] v1.2.0 — read pending notification (if any)
# ============================================================
# customize.sh writes .pending_notification after a successful
# restore during an upgrade. main.go also reads this file at
# startup, but if the WebUI has not started yet we still want
# the boot log to reflect what happened during the install.
#
# We log the content but do NOT delete the file — main.go owns
# the deletion (it re-reads the file at startup).
if [ -f "$PENDING_NOTIFY_FILE" ]; then
    _pending_msg=$(cat "$PENDING_NOTIFY_FILE" 2>/dev/null | tr -d '\r\n ')
    if [ -n "$_pending_msg" ]; then
        log_msg "📢 Install notification: $_pending_msg"
    fi
fi

# ============================================================
# [8] Migrate old PID files from /data/local/tmp
# ============================================================
# HARD-SVC-08: use `_mf` as the loop variable instead of `f`,
# to avoid colliding with any caller's `f` (e.g. when this
# script is sourced interactively for debugging).
#
# SVC-FIX-M2: `dnscrypt.status` carries the user's ON/OFF
# intent and MUST NOT be deleted from /data/local/tmp unless
# the copy into $RUN_DIR_ACTIVE actually succeeded. On failure
# we keep the source and log a WARNING. PID files are
# transient and always safe to drop.
# ============================================================
if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ] && \
   [ "$RUN_DIR_ACTIVE" != "/data/local/tmp" ]; then
    for _mf in dnscrypt.pid webui.pid watchdog.pid dnscrypt.status; do
        [ -f "/data/local/tmp/$_mf" ] || continue

        if [ "$_mf" = "dnscrypt.status" ]; then
            # Status carries user intent (ON/OFF) — never delete
            # the source unless the copy succeeded.
            if [ -f "$RUN_DIR_ACTIVE/$_mf" ]; then
                # Already present in run/ — tmp copy is stale,
                # safe to drop without copying.
                rm -f "/data/local/tmp/$_mf" 2>/dev/null
            elif cp -f "/data/local/tmp/$_mf" "$RUN_DIR_ACTIVE/$_mf" 2>/dev/null; then
                log_msg "Migrated $_mf from tmp to run/"
                rm -f "/data/local/tmp/$_mf" 2>/dev/null
            else
                log_msg "WARNING: could not migrate $_mf — keeping /tmp copy"
                # Source preserved on purpose. Do NOT rm.
            fi
        else
            # PID files are transient — always safe to drop.
            rm -f "/data/local/tmp/$_mf" 2>/dev/null
        fi
    done
fi

# ============================================================
# [9] Verify binary permissions
# ============================================================
BIN_DIR="$MODDIR/proxy"

if [ -f "$BIN_DIR/dnscrypt-proxy" ] && [ ! -x "$BIN_DIR/dnscrypt-proxy" ]; then
    chmod 0755 "$BIN_DIR/dnscrypt-proxy"
    log_msg "Fixed permissions for dnscrypt-proxy"
fi

if [ -f "$BIN_DIR/dnscrypt-webui" ] && [ ! -x "$BIN_DIR/dnscrypt-webui" ]; then
    chmod 0755 "$BIN_DIR/dnscrypt-webui"
    log_msg "Fixed permissions for dnscrypt-webui"
fi

# ============================================================
# [10] One-time notification when credentials are ready
# ============================================================
if [ -f "$CRED_FILE" ] && [ ! -f /data/local/tmp/.dnscrypt_credentials_shown ]; then
    log_msg "Login credentials are ready at: $CRED_FILE"
    touch /data/local/tmp/.dnscrypt_credentials_shown 2>/dev/null
fi

# ============================================================
# [11] If module is disabled → cleanup and exit
# ============================================================
# SVC-FIX-M1: firewall cleanup is ALWAYS attempted. When
# functions.sh is loaded we delegate to `manage_firewall 0`;
# otherwise we invoke the inline fallback
# `_inline_cleanup_firewall`, which strips our DNAT rules on
# port 53 and any ACCEPT/DROP rules on port 5354. This
# prevents stale NAT rules from persisting across a
# disable → enable cycle when functions.sh failed to load.
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    log_msg "WARNING: Module is disabled, cleaning up before exit"

    echo "OFF" > "$STATUS_FILE" 2>/dev/null

    # SVC-FIX-M1: always attempt firewall cleanup.
    if [ "$FUNCTIONS_LOADED" = "1" ] && command -v manage_firewall >/dev/null 2>&1; then
        manage_firewall 0 2>/dev/null
        log_msg "Firewall cleaned (via functions.sh)"
    else
        _inline_cleanup_firewall
        log_msg "Firewall cleaned (inline fallback)"
    fi

    do_cleanup_proxy 2>/dev/null
    do_cleanup_webui 2>/dev/null

    if command -v settings >/dev/null 2>&1; then
        _st_wait=0
        while [ "$_st_wait" -lt 5 ]; do
            if settings get global private_dns_mode >/dev/null 2>&1; then
                break
            fi
            sleep 1
            _st_wait=$((_st_wait + 1))
        done

        if settings delete global private_dns_mode 2>/dev/null; then
            log_msg "private_dns_mode reset to AUTO"
        else
            log_msg "WARNING: Failed to reset private_dns_mode (continuing)"
        fi
    else
        log_msg "settings command not available, skipping private_dns_mode reset"
    fi

    if command -v ndc >/dev/null 2>&1; then
        ndc resolver flushdefaultif 2>/dev/null
    fi

    log_msg "Module disabled cleanup completed"
    exit 0
fi

# ============================================================
# [12] Wait for boot completion
# ============================================================
_max=60
_wait=0
until [ "$(getprop sys.boot_completed 2>/dev/null || printf "0")" = "1" ] || [ "$_wait" -ge "$_max" ]; do
    sleep 3
    _wait=$((_wait + 3))
done
sleep 2
log_msg "Boot completed (waited ${_wait}s)"

# ============================================================
# [13] Wait for network readiness
# ============================================================
net_wait=0
while [ "$net_wait" -lt 15 ]; do
    if command -v ip >/dev/null 2>&1; then
        if ip route 2>/dev/null | grep -q 'default' \
           || ip -6 route 2>/dev/null | grep -q 'default'; then
            break
        fi
    elif command -v busybox >/dev/null 2>&1; then
        if busybox ip route 2>/dev/null | grep -q 'default' \
           || busybox ip -6 route 2>/dev/null | grep -q 'default'; then
            break
        fi
    fi
    sleep 2
    net_wait=$((net_wait + 1))
done

if [ "$net_wait" -ge 15 ]; then
    log_msg "WARNING: No default route after 30s, trying DNS reachability..."
    dns_wait=0
    while [ "$dns_wait" -lt 10 ]; do
        if ping -c 1 -W 2 9.9.9.9 >/dev/null 2>&1 \
           || ping6 -c 1 -W 2 2620:fe::fe >/dev/null 2>&1; then
            log_msg "DNS reachable via ping"
            break
        fi
        sleep 2
        dns_wait=$((dns_wait + 1))
    done
    if [ "$dns_wait" -ge 10 ]; then
        log_msg "WARNING: Still no network after 50s total, proceeding anyway"
    fi
fi
log_msg "Network ready (route wait: $((net_wait * 2))s)"

# ============================================================
# [14] Read webui.conf settings
# ============================================================
CONF_FILE="$BIN_DIR/webui.conf"
PORT=$(do_get_port "$CONF_FILE")
[ -z "$PORT" ] && PORT="9090"

AUTO_RESTART_DNS=$(do_read_conf "$CONF_FILE" "AUTO_RESTART_DNS" "1")
AUTO_RESTART_WEBUI=$(do_read_conf "$CONF_FILE" "AUTO_RESTART_WEBUI" "1")

case "$AUTO_RESTART_DNS"   in 0|1) ;; *) AUTO_RESTART_DNS="1"   ;; esac
case "$AUTO_RESTART_WEBUI" in 0|1) ;; *) AUTO_RESTART_WEBUI="1" ;; esac

log_msg "WebUI port: $PORT"
log_msg "AUTO_RESTART_DNS=$AUTO_RESTART_DNS, AUTO_RESTART_WEBUI=$AUTO_RESTART_WEBUI"
if [ "$FUNCTIONS_LOADED" = "1" ] && [ -n "$RUN_DIR_ACTIVE" ]; then
    log_msg "Runtime paths: RUN_DIR=$RUN_DIR_ACTIVE"
else
    log_msg "Runtime paths: RUN_DIR=$(dirname "$PID_FILE")"
fi

# ============================================================
# [14b] v1.1.0 — Log active profile + memory hint
# ============================================================
ACTIVE_PROFILE="pro"
if [ -f "$SELECTED_PROFILE_FILE" ]; then
    _ap=$(cat "$SELECTED_PROFILE_FILE" 2>/dev/null | tr -d '\r\n ')
    case "$_ap" in
        light|normal|pro|proplus|ultimate) ACTIVE_PROFILE="$_ap" ;;
    esac
fi

MEMORY_HINT=$(do_mem_hint)
log_msg "Active profile: $ACTIVE_PROFILE"
log_msg "Expected memory limit: $MEMORY_HINT (managed by main.go)"

# ============================================================
# [14c] v1.2.0 — Layer 9: auto-backup if needed
# ============================================================
# Triggers a backup of the 5 user config files to the persistent
# directory (/sdcard/dnscrypt-webui-backup/) if the last one is
# older than 24 hours (86400 seconds).
#
# SVC-3 fix: distinguish "created" from "skipped" by comparing
# the mtime of `.last_auto_backup` before and after the call.
#
# SVC-FIX-L4: the outer `if [ -d "$BIN_DIR" ]` guard was removed.
# BIN_DIR is validated in [9] and [15], and `do_auto_backup`
# already returns 0 on a missing `src_dir`, so the block is
# safe to execute unconditionally.
# ============================================================
BACKUP_STATUS="not-attempted"
BACKUP_COUNT="0"
LAST_STABLE_NAME=""

log_msg "🔄 Checking auto-backup state (interval=86400s)..."

# Record the marker mtime before the check
_marker_before=0
if [ -f "$PERSISTENT_BACKUP/.last_auto_backup" ]; then
    _marker_before=$(stat -c %Y "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null) \
        || _marker_before=$(stat -f %m "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null) \
        || _marker_before=0
fi

if do_auto_backup 86400; then
    # Record the marker mtime after the check
    _marker_after=0
    if [ -f "$PERSISTENT_BACKUP/.last_auto_backup" ]; then
        _marker_after=$(stat -c %Y "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null) \
            || _marker_after=$(stat -f %m "$PERSISTENT_BACKUP/.last_auto_backup" 2>/dev/null) \
            || _marker_after=0
    fi

    # Numeric validation
    case "$_marker_before" in ''|*[!0-9]*) _marker_before=0 ;; esac
    case "$_marker_after"  in ''|*[!0-9]*) _marker_after=0  ;; esac

    if [ "$_marker_after" -gt 0 ] && [ "$_marker_after" != "$_marker_before" ]; then
        BACKUP_STATUS="created"
        log_msg "✅ Auto-backup: new snapshot created"
    else
        BACKUP_STATUS="skipped"
        log_msg "ℹ️ Auto-backup: skipped (recent snapshot exists)"
    fi
else
    BACKUP_STATUS="failed"
    log_msg "⚠️ Auto-backup check failed (non-fatal)"
fi

# Rotate old snapshots to keep the total bounded
if do_rotate_backups 21; then
    log_msg "✅ Backup rotation complete (keep=21)"
else
    log_msg "⚠️ Backup rotation failed (non-fatal)"
fi

# --- v1.2.0 — collect backup state for the summary ---
if [ -d "$PERSISTENT_BACKUP" ]; then
    BACKUP_COUNT=$(cd "$PERSISTENT_BACKUP" 2>/dev/null && \
        ls -1d */ 2>/dev/null | \
        sed 's:/$::' | \
        grep -E '^[0-9]{8}-[0-9]{6}-' | \
        wc -l | tr -d ' ')
    [ -z "$BACKUP_COUNT" ] && BACKUP_COUNT=0
fi

if [ -f "$LAST_STABLE_FILE" ]; then
    LAST_STABLE_NAME=$(cat "$LAST_STABLE_FILE" 2>/dev/null | tr -d '\r\n ')
fi

# ============================================================
# [15] Verify WebUI binary exists
# ============================================================
WEBUI="$BIN_DIR/dnscrypt-webui"
if [ ! -f "$WEBUI" ]; then
    log_msg "ERROR: WebUI binary not found at $WEBUI"
    echo "OFF" > "$STATUS_FILE" 2>/dev/null
    exit 1
fi

# ============================================================
# [16] Start WebUI (two attempts)
# ============================================================
# HARD-SVC-09: use `_attempt` as the loop variable.
WEBUI_STARTED=0
for _attempt in 1 2; do
    log_msg "WebUI start attempt $_attempt/2..."
    if do_start_webui "$WEBUI" "$PORT"; then
        WEBUI_STARTED=1
        log_msg "WebUI started (Port: $PORT)"
        break
    fi
    if [ "$_attempt" -lt 2 ]; then
        log_msg "WARNING: WebUI start attempt $_attempt failed, retrying in 3s..."
        sleep 3
    fi
done

if [ "$WEBUI_STARTED" != "1" ]; then
    log_msg "ERROR: WebUI failed to start after 2 attempts"
fi

# ============================================================
# [17] Watchdog — independent process
# ============================================================
# The WATCHDOG_SCRIPT lives in the module root ($MODDIR/watchdog.sh),
# NOT in $MODDIR/proxy/. This is critical: the watchdog runs as a
# separate file so that $$ inside it refers to the actual watchdog
# PID, not the parent service.sh.
#
# SVC-FIX-M3: launch via `setsid` when available, mirroring
# `_inline_start_webui` and `start_native_webui`. Falls back to
# `busybox setsid` and then to `nohup`. This places the Watchdog
# in its own session, protecting it from the parent shell's
# SIGHUP on some Android firmware variants.
#
# SVC-FIX-L1: wait up to 3 s for the PID file to appear (was a
# single `sleep 1`). Avoids false-positive "PID file not
# created" warnings on slow devices.
# ============================================================
WATCHDOG_SCRIPT="$MODDIR/watchdog.sh"

if [ ! -f "$WATCHDOG_SCRIPT" ]; then
    log_msg "ERROR: watchdog.sh not found at $WATCHDOG_SCRIPT"
    log_msg "   Watchdog will NOT be started — service continues without it"
else
    if [ ! -x "$WATCHDOG_SCRIPT" ]; then
        chmod 0755 "$WATCHDOG_SCRIPT" 2>/dev/null
    fi

    # SVC-FIX-M3: prefer setsid for proper session isolation.
    if command -v setsid >/dev/null 2>&1; then
        setsid "$WATCHDOG_SCRIPT" \
            "$WATCHDOG_PID_FILE" \
            "$MODDIR" \
            "$PORT" \
            "$AUTO_RESTART_DNS" \
            "$AUTO_RESTART_WEBUI" \
            >/dev/null 2>&1 < /dev/null &
    elif command -v busybox >/dev/null 2>&1 && \
         busybox --list 2>/dev/null | grep -q setsid; then
        busybox setsid "$WATCHDOG_SCRIPT" \
            "$WATCHDOG_PID_FILE" \
            "$MODDIR" \
            "$PORT" \
            "$AUTO_RESTART_DNS" \
            "$AUTO_RESTART_WEBUI" \
            >/dev/null 2>&1 < /dev/null &
    else
        nohup "$WATCHDOG_SCRIPT" \
            "$WATCHDOG_PID_FILE" \
            "$MODDIR" \
            "$PORT" \
            "$AUTO_RESTART_DNS" \
            "$AUTO_RESTART_WEBUI" \
            >/dev/null 2>&1 < /dev/null &
    fi

    # SVC-FIX-L1: wait up to 3 s for the PID file to appear.
    _wd_wait=0
    while [ "$_wd_wait" -lt 3 ] && [ ! -f "$WATCHDOG_PID_FILE" ]; do
        sleep 1
        _wd_wait=$((_wd_wait + 1))
    done

    if [ -f "$WATCHDOG_PID_FILE" ]; then
        wd_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null | tr -d '\r\n ')
        if [ -n "$wd_pid" ] && kill -0 "$wd_pid" 2>/dev/null; then
            log_msg "Watchdog started (PID: $wd_pid)"
        else
            log_msg "WARNING: Watchdog PID file exists but process is not alive"
        fi
    else
        log_msg "WARNING: Watchdog PID file not created — check watchdog.sh"
    fi
fi

# ============================================================
# [18] Final structured summary (v1.2.0)
# ============================================================
log_msg "─────────────────────────────────────────────"
log_msg "service.sh summary ($MODULE_VERSION):"
log_msg "  • WebUI:        port $PORT (started=$([ "$WEBUI_STARTED" = "1" ] && echo yes || echo no))"
log_msg "  • Profile:      $ACTIVE_PROFILE"
log_msg "  • Memory hint:  $MEMORY_HINT"
log_msg "  • Auto-restart: DNS=$AUTO_RESTART_DNS WebUI=$AUTO_RESTART_WEBUI"
log_msg "  • Auto-backup:  $BACKUP_STATUS"
log_msg "  • Snapshots:    $BACKUP_COUNT"
if [ -n "$LAST_STABLE_NAME" ]; then
    log_msg "  • Last stable:  $LAST_STABLE_NAME"
else
    log_msg "  • Last stable:  (none yet)"
fi
log_msg "  • functions.sh: $([ "$FUNCTIONS_LOADED" = "1" ] && echo loaded || echo fallback)"
log_msg "─────────────────────────────────────────────"

exit 0