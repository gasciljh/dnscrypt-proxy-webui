#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — post-fs-data.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Early boot cleanup script. Runs BEFORE system_server starts
# (post-fs-data phase), when only /data and /proc are reliably
# available. /sdcard may not be mounted; settings, am, pm are
# all unavailable.
#
# Responsibilities (only when the module is disabled):
#   • Kill any lingering dnscrypt-proxy / dnscrypt-webui /
#     watchdog.sh processes
#   • Emergency firewall cleanup (best-effort)
#   • Remove stale PID files from both RUN_DIR and /tmp
#
# Design Notes:
#   • STATUS_FILE is deliberately NOT modified. It represents
#     "user intent" (ON/OFF), not "current state". Preserving
#     it lets DNS auto-restart after the user re-enables the
#     module without manually starting it again.
#   • Self-contained: sources only lib/constants.sh and
#     lib/firewall.sh. Does NOT source boot-mini.sh.
# ============================================================

export PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin:$PATH

# ============================================================
# [1] Module path (security-checked)
# ============================================================
MODDIR=${0%/*}
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
case "$MODDIR" in
    /*) ;;
    *) MODDIR="/data/adb/modules/${MODDIR}" ;;
esac

# Must live under /data/adb/modules. Anything else is a
# mis-invocation and must not proceed.
case "$MODDIR" in
    /data/adb/modules/*) ;;
    *) exit 0 ;;
esac

[ -d "$MODDIR" ] || exit 0

# ============================================================
# [2] Load minimal lib dependencies
# ============================================================
_LIB_BASE=""
for _cand in "$MODDIR/lib" "$MODDIR/proxy/lib"; do
    if [ -d "$_cand" ]; then
        _LIB_BASE="$_cand"
        break
    fi
done

if [ -n "$_LIB_BASE" ] && [ -f "$_LIB_BASE/constants.sh" ]; then
    . "$_LIB_BASE/constants.sh"
fi

# Ensure essential constants exist even if constants.sh was
# unavailable.
LOG_FILE="${LOG_FILE:-/data/local/tmp/dnscrypt_main.log}"
DNS_ENGINE_PORT="${DNS_ENGINE_PORT:-5354}"
BOOTSTRAP_IPS_FALLBACK="${BOOTSTRAP_IPS_FALLBACK:-9.9.9.9 8.8.8.8 1.1.1.1 1.0.0.1}"
LOOPBACK_IPV4="${LOOPBACK_IPV4:-127.0.0.1}"
LOOPBACK_IPV6="${LOOPBACK_IPV6:-::1}"
USER_FILES="${USER_FILES:-webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt}"

if [ -n "$_LIB_BASE" ] && [ -f "$_LIB_BASE/firewall.sh" ]; then
    . "$_LIB_BASE/firewall.sh"
fi

# ============================================================
# [3] Lightweight log_msg (no rotation)
# ============================================================
log_msg() {
    if printf '%s\n' "$(date +'%Y-%m-%d %H:%M:%S') - [post-fs-data] $1" \
        >> "$LOG_FILE" 2>/dev/null; then
        return 0
    fi
    printf '%s\n' "[post-fs-data] $1" >&2
}

# ============================================================
# [4] /proc-based process enumeration
# ============================================================
_kill_by_comm() {
    local name="$1"
    local pid_dir pid comm
    for pid_dir in /proc/[0-9]*; do
        [ -d "$pid_dir" ] || continue
        pid="${pid_dir##*/}"
        comm=$(cat "$pid_dir/comm" 2>/dev/null)
        [ "$comm" = "$name" ] && kill -9 "$pid" 2>/dev/null
    done
}

_kill_watchdogs() {
    local pid_dir pid comm cmd
    for pid_dir in /proc/[0-9]*; do
        [ -d "$pid_dir" ] || continue
        pid="${pid_dir##*/}"
        comm=$(cat "$pid_dir/comm" 2>/dev/null)
        [ "$comm" = "grep" ] && continue
        cmd=$(tr '\0' ' ' < "$pid_dir/cmdline" 2>/dev/null)
        case "$cmd" in
            *"/watchdog.sh"*) kill -9 "$pid" 2>/dev/null ;;
        esac
    done
}

# ============================================================
# [5] Fallback firewall cleanup
# ============================================================
if ! command -v firewall_emergency_cleanup >/dev/null 2>&1; then
    firewall_emergency_cleanup() {
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
                -j DNAT --to-destination "$LOOPBACK_IPV4:$DNS_ENGINE_PORT" \
                -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
            iptables -t nat -D OUTPUT -p tcp --dport 53 \
                -j DNAT --to-destination "$LOOPBACK_IPV4:$DNS_ENGINE_PORT" \
                -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
            iptables -t nat -D OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "$LOOPBACK_IPV4:$DNS_ENGINE_PORT" --wait 3 2>/dev/null
            iptables -t nat -D OUTPUT -p tcp --dport 53 \
                -j DNAT --to-destination "$LOOPBACK_IPV4:$DNS_ENGINE_PORT" --wait 3 2>/dev/null

            local ip
            for ip in $LOOPBACK_IPV4 $BOOTSTRAP_IPS_FALLBACK 8.8.4.4 208.67.222.222 208.67.220.220 94.140.14.14; do
                case "$ip" in *:*) continue ;; esac
                iptables -t nat -D OUTPUT -d "$ip" -p udp --dport 53 -j RETURN \
                    -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
                iptables -t nat -D OUTPUT -d "$ip" -p udp --dport 53 -j RETURN \
                    -m comment --comment "dnscrypt_smart_filter_loopback_${ip}" --wait 3 2>/dev/null
                iptables -t nat -D OUTPUT -d "$ip" -p udp --dport 53 -j RETURN --wait 3 2>/dev/null
                iptables -t nat -D OUTPUT -d "$ip" -p tcp --dport 53 -j RETURN \
                    -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
                iptables -t nat -D OUTPUT -d "$ip" -p tcp --dport 53 -j RETURN \
                    -m comment --comment "dnscrypt_smart_filter_loopback_${ip}" --wait 3 2>/dev/null
                iptables -t nat -D OUTPUT -d "$ip" -p tcp --dport 53 -j RETURN --wait 3 2>/dev/null
            done
        }

        command -v ip6tables >/dev/null 2>&1 && \
            ip6tables -t nat -L -n >/dev/null 2>&1 && {
            ip6tables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT6 --wait 3 2>/dev/null
            ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT6 --wait 3 2>/dev/null
            ip6tables -t nat -F DNSCRYPT_OUT6 --wait 3 2>/dev/null
            ip6tables -t nat -X DNSCRYPT_OUT6 --wait 3 2>/dev/null
            ip6tables -t nat -D OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "[$LOOPBACK_IPV6]:$DNS_ENGINE_PORT" \
                -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
            ip6tables -t nat -D OUTPUT -p tcp --dport 53 \
                -j DNAT --to-destination "[$LOOPBACK_IPV6]:$DNS_ENGINE_PORT" \
                -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
            ip6tables -t nat -D OUTPUT -p udp --dport 53 \
                -j DNAT --to-destination "[$LOOPBACK_IPV6]:$DNS_ENGINE_PORT" --wait 3 2>/dev/null
            ip6tables -t nat -D OUTPUT -p tcp --dport 53 \
                -j DNAT --to-destination "[$LOOPBACK_IPV6]:$DNS_ENGINE_PORT" --wait 3 2>/dev/null

            local ip6
            for ip6 in $LOOPBACK_IPV6 $BOOTSTRAP_IPS_FALLBACK 8.8.4.4 208.67.222.222 208.67.220.220 94.140.14.14; do
                case "$ip6" in *:*) ;; *) continue ;; esac
                ip6tables -t nat -D OUTPUT -d "$ip6" -p udp --dport 53 -j RETURN \
                    -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
                ip6tables -t nat -D OUTPUT -d "$ip6" -p udp --dport 53 -j RETURN \
                    -m comment --comment "dnscrypt_smart_filter_loopback_${ip6}" --wait 3 2>/dev/null
                ip6tables -t nat -D OUTPUT -d "$ip6" -p udp --dport 53 -j RETURN --wait 3 2>/dev/null
                ip6tables -t nat -D OUTPUT -d "$ip6" -p tcp --dport 53 -j RETURN \
                    -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
                ip6tables -t nat -D OUTPUT -d "$ip6" -p tcp --dport 53 -j RETURN \
                    -m comment --comment "dnscrypt_smart_filter_loopback_${ip6}" --wait 3 2>/dev/null
                ip6tables -t nat -D OUTPUT -d "$ip6" -p tcp --dport 53 -j RETURN --wait 3 2>/dev/null
            done
        }
        return 0
    }
fi

# ============================================================
# [6] Main path
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    _mod_name=$(basename "$MODDIR" 2>/dev/null)
    [ -z "$_mod_name" ] && _mod_name="dnscrypt-proxy-webui"

    log_msg "Module '$_mod_name' DISABLED — emergency cleanup starting"

    # --- 1) Kill processes (watchdog first so it cannot resurrect) ---
    _kill_watchdogs
    log_msg "Watchdog processes terminated"

    _kill_by_comm "dnscrypt-webui"
    log_msg "WebUI processes terminated"

    _kill_by_comm "dnscrypt-proxy"
    log_msg "DNS engine processes terminated"

    # --- 2) Emergency firewall cleanup ---
    firewall_emergency_cleanup
    log_msg "Firewall rules cleaned"

    # --- 3) Remove PID files from both locations ---
    _pids_removed=0

    for base in "$MODDIR/proxy/run" "/data/local/tmp"; do
        [ -d "$base" ] || continue
        for pf in dnscrypt.pid webui.pid watchdog.pid \
                  .watchdog_token .bootstrap_cache; do
            if [ -f "$base/$pf" ]; then
                rm -f "$base/$pf" 2>/dev/null && _pids_removed=$((_pids_removed + 1))
            fi
        done
    done

    log_msg "Removed $_pids_removed stale runtime file(s)"

    # --- 4) STATUS_FILE is deliberately NOT modified ---
    _current_intent="(missing)"
    [ -f "$MODDIR/proxy/run/dnscrypt.status" ] && \
        _current_intent=$(cat "$MODDIR/proxy/run/dnscrypt.status" 2>/dev/null | tr -d '\r\n ')
    [ "$_current_intent" = "(missing)" ] && \
        [ -f "/data/local/tmp/dnscrypt.status" ] && \
        _current_intent=$(cat "/data/local/tmp/dnscrypt.status" 2>/dev/null | tr -d '\r\n ')

    log_msg "STATUS_FILE preserved (user intent: ${_current_intent:-unknown})"
    log_msg "Emergency cleanup complete — non-actions handled by service.sh"
else
    log_msg "Module enabled — nothing to do in post-fs-data phase"
fi

# ============================================================
# [7] Exit
# ============================================================
exit 0