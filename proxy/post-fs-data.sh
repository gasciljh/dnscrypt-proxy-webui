#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — post-fs-data.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-19
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Early boot cleanup script (Magisk/KernelSU phase).
# Runs BEFORE system_server starts (post-fs-data phase).
#
# Trigger: Magisk / KernelSU / APatch
#          during the post-fs-data boot phase (no arguments).
#
# Responsibilities (only when the module is disabled):
#   • Emergency cleanup of firewall rules
#   • Kill lingering dnscrypt-proxy / dnscrypt-webui processes
#   • Remove stale PID files (both locations)
#   • Write STATUS_FILE = OFF (legitimate when disabled)
#
# Design:
#   • Self-contained — no dependency on functions.sh. This
#     script runs before /data may be fully mounted, so it
#     cannot rely on Layer-1 primitives.
#   • No background processes — Magisk does not wait for them.
#   • Safe on all devices (path checks + security guards).
#   • Idempotent — safe to run multiple times.
#   • Log helper with 50 MB emergency rotation and a
#     `_LOG_DISABLED` short-circuit for unwritable locations.
#   • Uses `local` inside `inline_firewall_cleanup` — supported
#     by mksh, busybox ash, bash, dash, and ksh (every shell
#     Android ships).
#
# Non-responsibilities (deliberately NOT done here):
#   • private_dns_mode reset       → service.sh
#   • route_localnet restore       → uninstall.sh
#   • Firewall rule creation       → service.sh / main.go
#   • Backup operations            → service.sh (post-boot)
#   • Restore operations           → customize.sh (at install)
#   • Transaction cleanup          → main.go + service.sh
#   • Orphan-txn inspection        → user-initiated only
#   • Pending notification read    → main.go
#   • Companion install flow       → main.go + install_app.sh
#
# Cross-references:
#   • VERSION                    — module version (SSOT)
#   • proxy/functions.sh         — canonical shell library
#   • proxy/service.sh           — boot service
#   • proxy/uninstall.sh         — teardown
#   • docs/REFERENCE.md §1, §3   — architecture reference
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path (safely, with security check)
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)

case "$MODDIR" in
    /*) ;;
    *) MODDIR="/data/adb/modules/${MODDIR}" ;;
esac

# Security: must be inside /data/adb/modules. Exit silently
# otherwise — this script has no business running outside the
# module tree.
case "$MODDIR" in
    /data/adb/modules/*) ;;
    *) exit 0 ;;
esac

if [ ! -d "$MODDIR" ]; then
    exit 0
fi

# ============================================================
# [2] Paths
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
RUN_DIR="$MODDIR/proxy/run"

# Fallback to the canonical module ID if basename fails.
MOD_NAME=$(basename "$MODDIR" 2>/dev/null)
if [ -z "$MOD_NAME" ]; then
    MOD_NAME="dnscrypt-proxy-webui"
fi

# Prefers $RUN_DIR when writable; falls back to /data/local/tmp.
# If neither is writable, `_RUN_DIR_FALLBACK_UNWRITABLE` is set
# and [3b] emits a single warning once log_msg is available.
RUN_DIR_USABLE=0
if [ -d "$RUN_DIR" ] && [ -w "$RUN_DIR" ]; then
    RUN_DIR_USABLE=1
    STATUS_FILE="$RUN_DIR/dnscrypt.status"
    PID_FILE="$RUN_DIR/dnscrypt.pid"
    WEBUI_PID_FILE="$RUN_DIR/webui.pid"
    WATCHDOG_PID_FILE="$RUN_DIR/watchdog.pid"
else
    STATUS_FILE="/data/local/tmp/dnscrypt.status"
    PID_FILE="/data/local/tmp/dnscrypt.pid"
    WEBUI_PID_FILE="/data/local/tmp/webui.pid"
    WATCHDOG_PID_FILE="/data/local/tmp/watchdog.pid"

    if [ ! -w "/data/local/tmp" ]; then
        _RUN_DIR_FALLBACK_UNWRITABLE=1
    else
        _RUN_DIR_FALLBACK_UNWRITABLE=0
    fi
fi

# ============================================================
# [3] Protected log_msg (with 50 MB emergency rotation)
# ============================================================
# `_LOG_DISABLED` is a per-process short-circuit. Once a write
# has failed, subsequent calls do nothing. The rotation path
# runs BEFORE the flag check, so a prior append failure does
# not block a legitimate rotation attempt.
#
# `_LOG_CALL_COUNT` is a global by design — it must persist
# across calls within the same shell process.
_LOG_CALL_COUNT=0
_LOG_DISABLED=0

log_msg() {
    if [ "$_LOG_DISABLED" = "1" ]; then
        return 0
    fi

    _LOG_CALL_COUNT=$((_LOG_CALL_COUNT + 1))

    # Emergency-only rotation at 50 MB, every 100th call.
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

    if [ ! -d "/data/local/tmp" ]; then
        _LOG_DISABLED=1
        return 0
    fi

    if [ ! -f "$LOG_FILE" ]; then
        if ! : > "$LOG_FILE" 2>/dev/null; then
            _LOG_DISABLED=1
            return 0
        fi
    fi

    if ! echo "$(date +'%Y-%m-%d %H:%M:%S') - [post-fs-data] $1" >> "$LOG_FILE" 2>/dev/null; then
        _LOG_DISABLED=1
    fi
}

# ============================================================
# [3b] Deferred fallback warning
# ============================================================
if [ "${_RUN_DIR_FALLBACK_UNWRITABLE:-0}" = "1" ]; then
    log_msg "⚠️ Neither $RUN_DIR nor /data/local/tmp is writable — STATUS_FILE writes may fail"
fi

# ============================================================
# [4] Custom Chain cleanup (orphan prevention)
# ============================================================
# Removes the same SET of rules as customize.sh, uninstall.sh,
# and functions.sh:manage_firewall 0. They differ only in the
# comment tag applied to loopback rules during best-effort
# legacy cleanup. Any change to the RULES removed here MUST be
# applied consistently to all four.
#
# The hard-coded legacy IP list duplicates the pre-v1.2.0
# default bootstrap set. Deliberate: this file must remain
# self-contained because it runs before functions.sh is
# guaranteed to be sourceable.
#
# `_ip` is declared `local` to prevent it from leaking to the
# global scope after the loop finishes.
inline_firewall_cleanup() {
    # --- [1] nftables: delete the entire table ---
    if command -v nft >/dev/null 2>&1; then
        nft delete table inet dnscrypt_filter 2>/dev/null
        nft delete table ip dnscrypt_filter 2>/dev/null
        nft delete table ip6 dnscrypt_filter 2>/dev/null
    fi

    # --- [2] iptables (IPv4) — Custom Chain cleanup ---
    if command -v iptables >/dev/null 2>&1; then
        local _chain="DNSCRYPT_OUT"

        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain" --wait 3 2>/dev/null

        iptables -t nat -F "$_chain" --wait 3 2>/dev/null
        iptables -t nat -X "$_chain" --wait 3 2>/dev/null

        # Legacy cleanup — tagged and untagged variants
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

        iptables -t nat -D OUTPUT -d 127.0.0.1 -p udp --dport 53 \
            -j RETURN \
            -m comment --comment "dnscrypt_smart_filter_loopback_127.0.0.1" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -d 127.0.0.1 -p tcp --dport 53 \
            -j RETURN \
            -m comment --comment "dnscrypt_smart_filter_loopback_127.0.0.1" --wait 3 2>/dev/null

        iptables -t nat -D OUTPUT -d 127.0.0.1 -p udp --dport 53 \
            -j RETURN --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -d 127.0.0.1 -p tcp --dport 53 \
            -j RETURN --wait 3 2>/dev/null

        local _ip
        for _ip in 9.9.9.9 8.8.8.8 1.1.1.1 1.0.0.1 8.8.4.4 208.67.222.222 208.67.220.220; do
            iptables -t nat -D OUTPUT -d "$_ip" -p udp --dport 53 \
                -j RETURN --wait 3 2>/dev/null
            iptables -t nat -D OUTPUT -d "$_ip" -p tcp --dport 53 \
                -j RETURN --wait 3 2>/dev/null
        done
    fi

    # --- [3] ip6tables (IPv6) — Custom Chain cleanup ---
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
# [5] Main path
# ============================================================
# No background operators: Magisk does not wait for background
# processes. Without them, cleanup completes before the script
# exits.
#
# Why we write STATUS_FILE = "OFF" when disabled:
#   The user explicitly disabled the module. Writing OFF is
#   the correct representation of "user intent" per the
#   STATUS_FILE contract. This is the ONLY legitimate place
#   (alongside service.sh's disable path) where a script
#   writes STATUS_FILE outside of main.go's start/stopService.
#
# The write is verified; if both locations fail, a warning is
# logged so the operator knows watchdog.sh may not honor the
# disable intent.
if [ -f "$MODDIR/disable" ]; then
    log_msg "Module '$MOD_NAME' is DISABLED. Starting emergency cleanup..."

    # 1) Firewall cleanup (Custom Chain + Legacy)
    inline_firewall_cleanup
    log_msg "✅ Firewall cleaned (Custom Chain + Legacy)"

    # 2) Kill remaining processes
    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-proxy 2>/dev/null
        log_msg "🔪 Killed lingering dnscrypt-proxy"
    fi
    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
        log_msg "🔪 Killed lingering dnscrypt-webui"
    fi

    # 3) Remove PID files from both locations
    rm -f "$RUN_DIR/dnscrypt.pid" 2>/dev/null
    rm -f "$RUN_DIR/webui.pid" 2>/dev/null
    rm -f "$RUN_DIR/watchdog.pid" 2>/dev/null

    rm -f /data/local/tmp/dnscrypt.pid 2>/dev/null
    rm -f /data/local/tmp/webui.pid 2>/dev/null
    rm -f /data/local/tmp/watchdog.pid 2>/dev/null

    log_msg "✅ PID files removed"

    # 4) Write STATUS_FILE in both locations (verify at least
    # one succeeded).
    _status_written=0

    if echo "OFF" > "$STATUS_FILE" 2>/dev/null; then
        _status_written=1
    fi

    if [ "$STATUS_FILE" != "/data/local/tmp/dnscrypt.status" ]; then
        if echo "OFF" > /data/local/tmp/dnscrypt.status 2>/dev/null; then
            _status_written=1
        fi
    fi

    if [ "$_status_written" = "1" ]; then
        log_msg "✅ STATUS_FILE = OFF (user intent preserved)"
    else
        log_msg "⚠️ Failed to write STATUS_FILE to any location — watchdog may not honor disable"
    fi

    log_msg "✅ Emergency cleanup complete"
    log_msg "   Non-actions handled elsewhere: private_dns_mode (service.sh),"
    log_msg "   route_localnet (uninstall.sh), backup/restore (service.sh + main.go),"
    log_msg "   transaction cleanup (main.go + service.sh), companion install (main.go)"
else
    # Module is enabled — nothing to do in this phase.
    #
    # A single informational line makes the boot log
    # self-documenting. Without it, an empty [post-fs-data]
    # section in the log could not be distinguished from
    # "the script did not run".
    log_msg "Module '$MOD_NAME' is enabled — nothing to do in post-fs-data phase"
fi

# ============================================================
# [6] Exit
# ============================================================
exit 0