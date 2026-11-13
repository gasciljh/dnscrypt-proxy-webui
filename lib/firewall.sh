#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — lib/firewall.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Firewall management: redirect DNS (port 53) to the local
# DNSCrypt engine on 127.0.0.1:5354 and [::1]:5354.
#
# Sourced by boot-mini.sh after lib/constants.sh and
# lib/process.sh. Requires at call time:
#   TOML_FILE, DNS_ENGINE_PORT, BOOTSTRAP_IPS_FALLBACK,
#   LOOPBACK_IPV4, LOOPBACK_IPV6
# ============================================================

if [ -n "${_LIB_FIREWALL_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_LIB_FIREWALL_LOADED=1

# ============================================================
# [1] Historical IP list (cleanup only)
# ============================================================
# Union of every IP that any version could have created a
# RETURN rule for, plus the current bootstrap_resolvers from
# dnscrypt-proxy.toml (v1.6.0: FDN + DNS.SB + CZ.NIC).
_LEGACY_CLEANUP_IPS="9.9.9.9 8.8.8.8 1.1.1.1 1.0.0.1 8.8.4.4 208.67.222.222 208.67.220.220 94.140.14.14 94.140.14.15 94.140.14.140 94.140.15.15 80.67.169.12 80.67.169.40 185.95.218.42 185.95.218.43 193.17.47.1 185.43.135.1"

_FW_CACHE=""
_FW_CACHE_TIME=0

_fw_log() {
    if command -v log_msg >/dev/null 2>&1; then
        log_msg "$1"
    else
        printf '%s\n' "$1" >&2
    fi
}

# ============================================================
# [2] Backend detection
# ============================================================
_fw_probe_nft() {
    command -v nft >/dev/null 2>&1 || return 1
    nft add table ip _dnscrypt_probe 2>/dev/null || return 1
    if nft add chain ip _dnscrypt_probe _test \
        '{ type nat hook output priority -100 ; }' 2>/dev/null; then
        nft delete table ip _dnscrypt_probe 2>/dev/null
        return 0
    fi
    nft delete table ip _dnscrypt_probe 2>/dev/null
    return 1
}

_fw_probe_ipt() {
    command -v iptables >/dev/null 2>&1 || return 1
    iptables -t nat -L -n >/dev/null 2>&1
}

# Only positive results are cached. A "none" result is treated
# as transient (backend may not have been loaded yet during
# early boot) and is re-probed on every call.
firewall_detect_backend() {
    local now
    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac

    if [ -n "$_FW_CACHE" ] && [ "$_FW_CACHE" != "none" ] \
       && [ "$((now - _FW_CACHE_TIME))" -lt 60 ]; then
        printf '%s' "$_FW_CACHE"
        return 0
    fi

    if _fw_probe_nft; then
        _FW_CACHE="nftables"
    elif _fw_probe_ipt; then
        _FW_CACHE="iptables"
    else
        _FW_CACHE="none"
    fi
    _FW_CACHE_TIME="$now"

    printf '%s' "$_FW_CACHE"
    [ "$_FW_CACHE" != "none" ]
}

# ============================================================
# [3] IPv6 availability
# ============================================================
firewall_is_ipv6_available() {
    [ -f /proc/net/if_inet6 ] || return 1
    local count
    count=$(wc -l < /proc/if_inet6 2>/dev/null | tr -d ' ')
    case "$count" in ''|*[!0-9]*) return 1 ;; esac
    [ "$count" -gt 0 ]
}

# ============================================================
# [4] Bootstrap IPs (dynamic, from TOML)
# ============================================================
firewall_get_bootstrap_ips() {
    local raw=""

    if [ -n "${TOML_FILE:-}" ] && [ -f "$TOML_FILE" ]; then
        raw=$(awk '
            /^[[:space:]]*bootstrap_resolvers[[:space:]]*=/ { in_array=1 }
            in_array { printf "%s\n", $0 }
            in_array && /\][[:space:]]*(#|$)/ { exit }
        ' "$TOML_FILE" 2>/dev/null \
        | tr -d "',\"\r" \
        | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}|[0-9a-fA-F]{0,4}(:[0-9a-fA-F]{0,4}){2,7}' \
        | sort -u | head -n 32 | tr '\n' ' ')
    fi

    if [ -z "$raw" ] || [ -z "${raw// /}" ]; then
        raw="$BOOTSTRAP_IPS_FALLBACK"
    fi
    printf '%s' "${raw% }"
}

# ============================================================
# [5] nftables — apply
# ============================================================
_firewall_nft_apply() {
    local bootstrap ip

    bootstrap=$(firewall_get_bootstrap_ips)

    nft delete table ip dnscrypt_filter 2>/dev/null
    nft delete table ip6 dnscrypt_filter 2>/dev/null
    nft delete table inet dnscrypt_filter 2>/dev/null

    # --- IPv4 ---
    if ! nft add table ip dnscrypt_filter 2>/dev/null; then
        return 1
    fi
    if ! nft add chain ip dnscrypt_filter out \
        '{ type nat hook output priority -100 ; }' 2>/dev/null; then
        nft delete table ip dnscrypt_filter 2>/dev/null
        return 1
    fi

    for ip in $LOOPBACK_IPV4 $bootstrap; do
        case "$ip" in *:*) continue ;; esac
        nft add rule ip dnscrypt_filter out ip daddr "$ip" udp dport 53 return 2>/dev/null || true
        nft add rule ip dnscrypt_filter out ip daddr "$ip" tcp dport 53 return 2>/dev/null || true
    done

    if ! nft add rule ip dnscrypt_filter out udp dport 53 \
        dnat to "$LOOPBACK_IPV4:$DNS_ENGINE_PORT" 2>/dev/null; then
        nft delete table ip dnscrypt_filter 2>/dev/null
        return 1
    fi
    if ! nft add rule ip dnscrypt_filter out tcp dport 53 \
        dnat to "$LOOPBACK_IPV4:$DNS_ENGINE_PORT" 2>/dev/null; then
        nft delete table ip dnscrypt_filter 2>/dev/null
        return 1
    fi

    # --- IPv6 ---
    if firewall_is_ipv6_available; then
        if nft add table ip6 dnscrypt_filter 2>/dev/null && \
           nft add chain ip6 dnscrypt_filter out \
               '{ type nat hook output priority -100 ; }' 2>/dev/null; then

            for ip in $LOOPBACK_IPV6 $bootstrap; do
                case "$ip" in *:*) ;; *) continue ;; esac
                nft add rule ip6 dnscrypt_filter out ip6 daddr "$ip" udp dport 53 return 2>/dev/null || true
                nft add rule ip6 dnscrypt_filter out ip6 daddr "$ip" tcp dport 53 return 2>/dev/null || true
            done

            if ! nft add rule ip6 dnscrypt_filter out udp dport 53 \
                dnat to "[$LOOPBACK_IPV6]:$DNS_ENGINE_PORT" 2>/dev/null; then
                nft delete table ip6 dnscrypt_filter 2>/dev/null
            else
                nft add rule ip6 dnscrypt_filter out tcp dport 53 \
                    dnat to "[$LOOPBACK_IPV6]:$DNS_ENGINE_PORT" 2>/dev/null || true
            fi
        fi
    fi

    _fw_log "nftables: applied (v4 DNAT → $LOOPBACK_IPV4:$DNS_ENGINE_PORT, v6 → [$LOOPBACK_IPV6]:$DNS_ENGINE_PORT)"
    return 0
}

# ============================================================
# [6] nftables — cleanup
# ============================================================
_firewall_nft_cleanup() {
    nft delete table ip dnscrypt_filter 2>/dev/null
    nft delete table ip6 dnscrypt_filter 2>/dev/null
    nft delete table inet dnscrypt_filter 2>/dev/null
    return 0
}

# ============================================================
# [7] Shared NAT rule helpers
# ============================================================
_fw_nat_apply_dnat() {
    local cmd="$1"
    local proto="$2"
    local target="$3"

    if $cmd -t nat -I OUTPUT -p "$proto" --dport 53 \
        -j DNAT --to-destination "$target" \
        -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null; then
        return 0
    fi

    $cmd -t nat -I OUTPUT -p "$proto" --dport 53 \
        -j DNAT --to-destination "$target" --wait 3 2>/dev/null
}

_fw_nat_apply_return() {
    local cmd="$1"
    local ip="$2"
    local proto="$3"

    if $cmd -t nat -I OUTPUT -d "$ip" -p "$proto" --dport 53 -j RETURN \
        -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null; then
        return 0
    fi

    $cmd -t nat -I OUTPUT -d "$ip" -p "$proto" --dport 53 -j RETURN --wait 3 2>/dev/null
}

_fw_ipt_remove_return() {
    local ip="$1"
    local proto="$2"

    iptables -t nat -D OUTPUT -d "$ip" -p "$proto" --dport 53 -j RETURN \
        -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
    iptables -t nat -D OUTPUT -d "$ip" -p "$proto" --dport 53 -j RETURN \
        -m comment --comment "dnscrypt_smart_filter_loopback_${ip}" --wait 3 2>/dev/null
    iptables -t nat -D OUTPUT -d "$ip" -p "$proto" --dport 53 -j RETURN --wait 3 2>/dev/null
    return 0
}

_fw_ip6t_remove_return() {
    local ip="$1"
    local proto="$2"

    ip6tables -t nat -D OUTPUT -d "$ip" -p "$proto" --dport 53 -j RETURN \
        -m comment --comment "dnscrypt_smart_filter" --wait 3 2>/dev/null
    ip6tables -t nat -D OUTPUT -d "$ip" -p "$proto" --dport 53 -j RETURN \
        -m comment --comment "dnscrypt_smart_filter_loopback_${ip}" --wait 3 2>/dev/null
    ip6tables -t nat -D OUTPUT -d "$ip" -p "$proto" --dport 53 -j RETURN --wait 3 2>/dev/null
    return 0
}

# ============================================================
# [8] iptables — apply + cleanup (IPv4)
# ============================================================
_firewall_ipt_cleanup() {
    local chain="DNSCRYPT_OUT"
    local bootstrap ip

    command -v iptables >/dev/null 2>&1 || return 0

    bootstrap="$(firewall_get_bootstrap_ips) $_LEGACY_CLEANUP_IPS"

    iptables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 3 2>/dev/null
    iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 3 2>/dev/null
    iptables -t nat -F "$chain" --wait 3 2>/dev/null
    iptables -t nat -X "$chain" --wait 3 2>/dev/null

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

    for ip in $LOOPBACK_IPV4 $bootstrap; do
        case "$ip" in *:*) continue ;; esac
        _fw_ipt_remove_return "$ip" udp
        _fw_ipt_remove_return "$ip" tcp
    done
    return 0
}

_firewall_ipt_apply() {
    local chain="DNSCRYPT_OUT"
    local bootstrap ip added=0

    _firewall_ipt_cleanup

    bootstrap=$(firewall_get_bootstrap_ips)

    if iptables -t nat -N "$chain" --wait 3 2>/dev/null && \
       iptables -t nat -I OUTPUT -p udp --dport 53 -j "$chain" --wait 3 2>/dev/null && \
       iptables -t nat -I OUTPUT -p tcp --dport 53 -j "$chain" --wait 3 2>/dev/null; then

        for ip in $LOOPBACK_IPV4 $bootstrap; do
            case "$ip" in *:*) continue ;; esac
            iptables -t nat -A "$chain" -d "$ip" -j RETURN --wait 3 2>/dev/null && \
                added=$((added + 1))
        done

        if [ "$added" -gt 0 ] && \
           iptables -t nat -A "$chain" -j DNAT \
               --to-destination "$LOOPBACK_IPV4:$DNS_ENGINE_PORT" --wait 3 2>/dev/null; then
            _fw_log "iptables: applied (custom chain, $added RETURN rules)"
            return 0
        fi

        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 3 2>/dev/null
        iptables -t nat -F "$chain" --wait 3 2>/dev/null
        iptables -t nat -X "$chain" --wait 3 2>/dev/null
    fi

    if ! _fw_nat_apply_dnat iptables udp "$LOOPBACK_IPV4:$DNS_ENGINE_PORT"; then
        _fw_log "iptables: failed to add UDP DNAT"
        return 1
    fi
    if ! _fw_nat_apply_dnat iptables tcp "$LOOPBACK_IPV4:$DNS_ENGINE_PORT"; then
        _fw_log "iptables: failed to add TCP DNAT"
        _firewall_ipt_cleanup
        return 1
    fi

    for ip in $LOOPBACK_IPV4 $bootstrap; do
        case "$ip" in *:*) continue ;; esac
        _fw_nat_apply_return iptables "$ip" udp
        _fw_nat_apply_return iptables "$ip" tcp
    done

    _fw_log "iptables: applied (direct DNAT)"
    return 0
}

# ============================================================
# [9] ip6tables — apply + cleanup (IPv6)
# ============================================================
_firewall_ip6t_cleanup() {
    local chain="DNSCRYPT_OUT6"
    local bootstrap ip

    command -v ip6tables >/dev/null 2>&1 || return 0
    ip6tables -t nat -L -n >/dev/null 2>&1 || return 0

    bootstrap="$(firewall_get_bootstrap_ips) $_LEGACY_CLEANUP_IPS"

    ip6tables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 3 2>/dev/null
    ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 3 2>/dev/null
    ip6tables -t nat -F "$chain" --wait 3 2>/dev/null
    ip6tables -t nat -X "$chain" --wait 3 2>/dev/null

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

    for ip in $LOOPBACK_IPV6 $bootstrap; do
        case "$ip" in *:*) ;; *) continue ;; esac
        _fw_ip6t_remove_return "$ip" udp
        _fw_ip6t_remove_return "$ip" tcp
    done
    return 0
}

_firewall_ip6t_apply() {
    local chain="DNSCRYPT_OUT6"
    local bootstrap ip added=0

    firewall_is_ipv6_available || return 0

    command -v ip6tables >/dev/null 2>&1 || return 0
    if ! ip6tables -t nat -L -n >/dev/null 2>&1; then
        _fw_log "ip6tables: nat not supported, IPv6 filtering skipped"
        return 0
    fi

    _firewall_ip6t_cleanup
    bootstrap=$(firewall_get_bootstrap_ips)

    if ip6tables -t nat -N "$chain" --wait 3 2>/dev/null && \
       ip6tables -t nat -I OUTPUT -p udp --dport 53 -j "$chain" --wait 3 2>/dev/null && \
       ip6tables -t nat -I OUTPUT -p tcp --dport 53 -j "$chain" --wait 3 2>/dev/null; then

        for ip in $LOOPBACK_IPV6 $bootstrap; do
            case "$ip" in *:*) ;; *) continue ;; esac
            ip6tables -t nat -A "$chain" -d "$ip" -j RETURN --wait 3 2>/dev/null && \
                added=$((added + 1))
        done

        if [ "$added" -gt 0 ] && \
           ip6tables -t nat -A "$chain" -j DNAT \
               --to-destination "[$LOOPBACK_IPV6]:$DNS_ENGINE_PORT" --wait 3 2>/dev/null; then
            _fw_log "ip6tables: applied (custom chain, $added RETURN rules)"
            return 0
        fi

        ip6tables -t nat -D OUTPUT -p udp --dport 53 -j "$chain" --wait 3 2>/dev/null
        ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j "$chain" --wait 3 2>/dev/null
        ip6tables -t nat -F "$chain" --wait 3 2>/dev/null
        ip6tables -t nat -X "$chain" --wait 3 2>/dev/null
    fi

    if ! _fw_nat_apply_dnat ip6tables udp "[$LOOPBACK_IPV6]:$DNS_ENGINE_PORT"; then
        return 1
    fi
    if ! _fw_nat_apply_dnat ip6tables tcp "[$LOOPBACK_IPV6]:$DNS_ENGINE_PORT"; then
        _firewall_ip6t_cleanup
        return 1
    fi

    for ip in $LOOPBACK_IPV6 $bootstrap; do
        case "$ip" in *:*) ;; *) continue ;; esac
        _fw_nat_apply_return ip6tables "$ip" udp
        _fw_nat_apply_return ip6tables "$ip" tcp
    done

    _fw_log "ip6tables: applied (direct DNAT)"
    return 0
}

# ============================================================
# [10] Public API — apply
# ============================================================
firewall_apply() {
    local backend
    backend=$(firewall_detect_backend)

    case "$backend" in
        nftables)
            if _firewall_nft_apply; then
                return 0
            fi
            _fw_log "nftables: apply failed, falling back to iptables"
            _firewall_ipt_apply || true
            _firewall_ip6t_apply || true
            return 0
            ;;
        iptables)
            _firewall_ipt_apply || true
            _firewall_ip6t_apply || true
            return 0
            ;;
        *)
            _fw_log "firewall: no backend available"
            return 1
            ;;
    esac
}

# ============================================================
# [11] Public API — cleanup
# ============================================================
firewall_cleanup() {
    _firewall_nft_cleanup
    _firewall_ipt_cleanup
    _firewall_ip6t_cleanup
    _fw_log "firewall: cleanup complete"
    return 0
}

# ============================================================
# [12] Backward-compat wrappers
# ============================================================
manage_firewall() {
    case "${1:-1}" in
        0) firewall_cleanup ;;
        1) firewall_apply ;;
        *) return 1 ;;
    esac
}

manage_iptables() {
    case "${1:-1}" in
        0) _firewall_ipt_cleanup ;;
        1) _firewall_ipt_apply ;;
        *) return 1 ;;
    esac
}

manage_ip6tables() {
    case "${1:-1}" in
        0) _firewall_ip6t_cleanup ;;
        1) _firewall_ip6t_apply ;;
        *) return 1 ;;
    esac
}

manage_nftables() {
    case "${1:-1}" in
        0) _firewall_nft_cleanup ;;
        1) _firewall_nft_apply ;;
        *) return 1 ;;
    esac
}

# ============================================================
# [13] Inline cleanup — for post-fs-data.sh
# ============================================================
# post-fs-data.sh runs before /data is guaranteed writable.
# It calls this instead of the full firewall_cleanup to avoid
# touching TOML_FILE.
firewall_emergency_cleanup() {
    _firewall_nft_cleanup

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
        for ip in $LOOPBACK_IPV4 $BOOTSTRAP_IPS_FALLBACK $_LEGACY_CLEANUP_IPS; do
            case "$ip" in *:*) continue ;; esac
            _fw_ipt_remove_return "$ip" udp
            _fw_ipt_remove_return "$ip" tcp
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
        for ip6 in $LOOPBACK_IPV6 $BOOTSTRAP_IPS_FALLBACK $_LEGACY_CLEANUP_IPS; do
            case "$ip6" in *:*) ;; *) continue ;; esac
            _fw_ip6t_remove_return "$ip6" udp
            _fw_ip6t_remove_return "$ip6" tcp
        done
    }
    return 0
}