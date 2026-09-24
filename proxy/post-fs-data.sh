#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – post-fs-data.sh
# Version: v1.0.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Early boot cleanup script (Magisk/KernelSU phase).
#
#   Runs BEFORE system_server starts (post-fs-data phase).
#
# Responsibilities:
#   • Emergency cleanup when the module is disabled
#   • Clean Custom Chains (DNSCRYPT_OUT / DNSCRYPT_OUT6)
#   • Clean legacy rules from older versions (best-effort)
#   • Kill lingering dnscrypt-proxy / dnscrypt-webui processes
#   • Remove stale PID files (both locations)
#   • Write STATUS_FILE = OFF (legitimate when disabled)
#
# Design:
#   • Self-contained — no dependency on functions.sh
#     (it may not be ready at this boot phase)
#   • No background processes — Magisk does not wait for them
#   • Safe on all devices (path checks + security guards)
#   • Idempotent — safe to run multiple times
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Determine module path safely
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)

case "$MODDIR" in
    /*) ;;
    *) MODDIR="/data/adb/modules/${MODDIR}" ;;
esac

# --- Security check: must be inside /data/adb/modules ---
case "$MODDIR" in
    /data/adb/modules/*) ;;
    *)
        # Not a known path — exit silently
        exit 0
        ;;
esac

# --- Check: are we actually in a module path? ---
if [ ! -d "$MODDIR" ]; then
    exit 0
fi

# ============================================================
# [2] Paths
# ============================================================
LOG_FILE="/data/local/tmp/dnscrypt_main.log"
RUN_DIR="$MODDIR/proxy/run"
MOD_NAME=$(basename "$MODDIR" 2>/dev/null || echo "dnscrypt-proxy-webui")

# --- Determine active run directory ---
if [ -d "$RUN_DIR" ] && [ -w "$RUN_DIR" ]; then
    STATUS_FILE="$RUN_DIR/dnscrypt.status"
    PID_FILE="$RUN_DIR/dnscrypt.pid"
    WEBUI_PID_FILE="$RUN_DIR/webui.pid"
    WATCHDOG_PID_FILE="$RUN_DIR/watchdog.pid"
else
    STATUS_FILE="/data/local/tmp/dnscrypt.status"
    PID_FILE="/data/local/tmp/dnscrypt.pid"
    WEBUI_PID_FILE="/data/local/tmp/webui.pid"
    WATCHDOG_PID_FILE="/data/local/tmp/watchdog.pid"
fi

# ============================================================
# [3] Protected log_msg
# ============================================================
log_msg() {
    if [ ! -d "/data/local/tmp" ]; then
        return 0
    fi
    if [ ! -f "$LOG_FILE" ]; then
        : > "$LOG_FILE" 2>/dev/null || return 0
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [post-fs-data] $1" >> "$LOG_FILE" 2>/dev/null
}

# ============================================================
# [4] Custom Chain cleanup (orphan prevention)
# ============================================================
# Strategy:
#   1. Delete the DNSCRYPT_OUT / DNSCRYPT_OUT6 Custom Chains entirely
#   2. Best-effort legacy cleanup (rules from older versions)
#   3. No dependency on functions.sh (it may not be ready yet)
#
# Why this is sufficient:
#   All dynamic rules live inside Custom Chains. Deleting the
#   chain deletes everything. No orphans remain.
#
# Why we also clean legacy:
#   A user may have upgraded from an older version and disabled
#   the module before manage_firewall 1 (which performs legacy
#   cleanup) could run. In that case, old rules (direct DNAT +
#   RETURN without a chain) may still be present. We clean them
#   best-effort.
# ============================================================
inline_firewall_cleanup() {
    # --- [1] nftables: delete the entire table ---
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

        # ------------------------------------------------------------
        # [2a] Remove jump rules from OUTPUT
        # ------------------------------------------------------------
        # After the Custom Chains change, OUTPUT holds only two static
        # rules: jumps to DNSCRYPT_OUT.
        # ------------------------------------------------------------
        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain" --wait 3 2>/dev/null

        # ------------------------------------------------------------
        # [2b] Flush the chain itself
        # ------------------------------------------------------------
        iptables -t nat -F "$_chain" --wait 3 2>/dev/null
        iptables -t nat -X "$_chain" --wait 3 2>/dev/null

        # ------------------------------------------------------------
        # [2c] Legacy cleanup — older versions
        # ------------------------------------------------------------
        # Old DNAT rules (with comment)
        iptables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 \
            -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null

        # Old DNAT rules (without comment — even older versions)
        iptables -t nat -D OUTPUT -p udp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 \
            -j DNAT --to-destination 127.0.0.1:5354 --wait 3 2>/dev/null

        # Old RETURN rules (with comment)
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
        # (may not match anything, but is harmless)
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

    return 0
}

# ============================================================
# [5] Main path: if module is disabled → emergency cleanup
# ============================================================
# No background operators: Magisk does not wait for background
# processes. Without them, we guarantee cleanup completes before
# the script exits.
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    log_msg "Module '$MOD_NAME' is DISABLED. Starting emergency cleanup..."

    # --- 1) Firewall cleanup (Custom Chain + Legacy) ---
    inline_firewall_cleanup
    log_msg "✅ Firewall cleaned (Custom Chain + Legacy)"

    # --- 2) Kill remaining processes (safety net) ---
    # Note: post-fs-data runs before boot completes, so we don't
    # expect active processes. We check anyway for safety.
    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-proxy 2>/dev/null
        log_msg "🔪 Killed lingering dnscrypt-proxy"
    fi
    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
        log_msg "🔪 Killed lingering dnscrypt-webui"
    fi

    # --- 3) Remove PID files from both locations (run/ + tmp) ---
    rm -f "$RUN_DIR/dnscrypt.pid" 2>/dev/null
    rm -f "$RUN_DIR/webui.pid" 2>/dev/null
    rm -f "$RUN_DIR/watchdog.pid" 2>/dev/null

    rm -f /data/local/tmp/dnscrypt.pid 2>/dev/null
    rm -f /data/local/tmp/webui.pid 2>/dev/null
    rm -f /data/local/tmp/watchdog.pid 2>/dev/null

    log_msg "✅ PID files removed"

    # --- 4) Set status file in both locations ---
    # Writing OFF here is legitimate: the module is explicitly
    # disabled by the user, so OFF represents the correct intent.
    echo "OFF" > "$STATUS_FILE" 2>/dev/null
    if [ "$STATUS_FILE" != "/data/local/tmp/dnscrypt.status" ]; then
        echo "OFF" > /data/local/tmp/dnscrypt.status 2>/dev/null
    fi

    log_msg "✅ Emergency cleanup complete"
    # Note: resetting private_dns_mode is moved to service.sh
    # because the settings service may not be ready during post-fs-data.
fi

# ============================================================
# [6] Exit
# ============================================================
exit 0