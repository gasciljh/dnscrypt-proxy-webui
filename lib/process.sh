#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — lib/process.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Portable process management: enumeration, killing, PID
# files, single-instance locking, port polling.
#
# Design:
#   • Enumerates processes via /proc directly, NOT via
#     `ps -A -o ARGS`. The latter is missing on many toybox
#     builds shipped with Android 5-8 and silently returns
#     empty output on those devices, defeating single-instance
#     guarantees.
#   • Every function is idempotent and safe to call on missing
#     processes.
# ============================================================

if [ -n "${_LIB_PROCESS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_LIB_PROCESS_LOADED=1

# ============================================================
# [1] Process enumeration
# ============================================================

# list_pids_by_comm <comm> — exact process-name match via
# /proc/<pid>/comm. Prints space-separated PIDs.
list_pids_by_comm() {
    local target="$1"
    local pid_dir pid comm found=""

    [ -z "$target" ] && return 1

    if command -v pgrep >/dev/null 2>&1; then
        found=$(pgrep -x "$target" 2>/dev/null | tr '\n' ' ')
        if [ -n "$found" ]; then
            printf '%s' "${found% }"
            return 0
        fi
    fi

    for pid_dir in /proc/[0-9]*; do
        [ -d "$pid_dir" ] || continue
        pid="${pid_dir##*/}"
        comm=$(cat "$pid_dir/comm" 2>/dev/null | tr -d '\r\n ')
        [ "$comm" = "$target" ] && found="$found $pid"
    done

    found="${found# }"
    [ -z "$found" ] && return 1
    printf '%s' "$found"
    return 0
}

# list_pids_by_cmdline <pattern> — substring match against
# the full command line from /proc/<pid>/cmdline. Skips grep
# processes to avoid self-matching.
list_pids_by_cmdline() {
    local pattern="$1"
    local pid_dir pid cmdline comm found=""

    [ -z "$pattern" ] && return 1

    for pid_dir in /proc/[0-9]*; do
        [ -d "$pid_dir" ] || continue
        pid="${pid_dir##*/}"
        comm=$(cat "$pid_dir/comm" 2>/dev/null | tr -d '\r\n ')
        [ "$comm" = "grep" ] && continue
        cmdline=$(tr '\0' ' ' < "$pid_dir/cmdline" 2>/dev/null)
        case "$cmdline" in
            *"$pattern"*) found="$found $pid" ;;
        esac
    done

    found="${found# }"
    [ -z "$found" ] && return 1
    printf '%s' "$found"
    return 0
}

# pid_is_alive <pid> — true only if the process exists AND is
# not a zombie.
pid_is_alive() {
    local pid="$1" state

    [ -z "$pid" ] && return 1
    [ -d "/proc/$pid" ] || return 1

    state=$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null | awk '{print $1}')
    [ "$state" = "Z" ] && return 1
    return 0
}

# ============================================================
# [2] Process termination
# ============================================================

# kill_by_comm <comm> [timeout_ticks]
kill_by_comm() {
    local name="$1"
    local timeout="${2:-30}"
    local pids wait

    pids=$(list_pids_by_comm "$name" 2>/dev/null)
    [ -z "$pids" ] && return 0

    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null

    wait=0
    while [ "$wait" -lt "$timeout" ]; do
        list_pids_by_comm "$name" >/dev/null 2>&1 || return 0
        sleep 0.1
        wait=$((wait + 1))
    done
    return 1
}

# kill_by_cmdline <pattern> [timeout_ticks]
kill_by_cmdline() {
    local pattern="$1"
    local timeout="${2:-30}"
    local pids wait

    pids=$(list_pids_by_cmdline "$pattern" 2>/dev/null)
    [ -z "$pids" ] && return 0

    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null

    wait=0
    while [ "$wait" -lt "$timeout" ]; do
        list_pids_by_cmdline "$pattern" >/dev/null 2>&1 || return 0
        sleep 0.1
        wait=$((wait + 1))
    done
    return 1
}

kill_dnscrypt_proxy_safely() { kill_by_comm "dnscrypt-proxy" "${1:-30}"; }
kill_webui_safely()          { kill_by_comm "dnscrypt-webui"  "${1:-50}"; }
kill_watchdogs_safely()      { kill_by_cmdline "/watchdog.sh" "${1:-30}"; }

# count_watchdogs — number of live watchdog.sh instances.
count_watchdogs() {
    local pids count

    pids=$(list_pids_by_cmdline "/watchdog.sh" 2>/dev/null)
    if [ -z "$pids" ]; then
        printf '0'
        return 0
    fi

    count=$(printf '%s' "$pids" | wc -w | tr -d ' ')
    printf '%s' "${count:-0}"
}

# kill_all_dnscrypt_processes — kills everything the module
# owns. Prints the number of subsystems (0-3) that had at
# least one process killed.
kill_all_dnscrypt_processes() {
    local killed=0 pids

    pids=$(list_pids_by_comm "dnscrypt-proxy" 2>/dev/null)
    if [ -n "$pids" ]; then
        kill_dnscrypt_proxy_safely 30 && killed=$((killed + 1))
    fi

    pids=$(list_pids_by_comm "dnscrypt-webui" 2>/dev/null)
    if [ -n "$pids" ]; then
        kill_webui_safely 50 && killed=$((killed + 1))
    fi

    pids=$(list_pids_by_cmdline "/watchdog.sh" 2>/dev/null)
    if [ -n "$pids" ]; then
        kill_watchdogs_safely 30 && killed=$((killed + 1))
    fi

    printf '%d' "$killed"
}

# ============================================================
# [3] PID file management
# ============================================================

# write_pid_file <path> <pid> — atomic via tmp + mv.
write_pid_file() {
    local path="$1"
    local pid="$2"
    local tmp="${path}.tmp.$$"

    [ -z "$path" ] && return 1
    [ -z "$pid" ] && return 1

    if ! printf '%d\n' "$pid" > "$tmp" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        return 1
    fi

    if ! mv -f "$tmp" "$path" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        return 1
    fi
    return 0
}

# read_pid_file <path> — prints PID if alive, empty otherwise.
read_pid_file() {
    local path="$1"
    local pid

    [ -f "$path" ] || return 1
    pid=$(cat "$path" 2>/dev/null | tr -d '\r\n ')
    [ -z "$pid" ] && return 1
    pid_is_alive "$pid" || return 1

    printf '%s' "$pid"
    return 0
}

# remove_pid_file <path> — silent, idempotent.
remove_pid_file() {
    [ -n "$1" ] && rm -f "$1" 2>/dev/null
    return 0
}

# ============================================================
# [4] Single-instance lock
# ============================================================
# get_lock_path <name>
# Returns the canonical lock directory path for a subsystem.
# Falls back to /data/local/tmp if RUN_DIR is unavailable.
get_lock_path() {
    local name="$1"
    local base="${RUN_DIR:-/data/local/tmp}"

    if [ -z "$name" ]; then
        printf '%s' "/data/local/tmp/.default.lock"
        return 0
    fi

    if [ ! -d "$base" ] || [ ! -w "$base" ]; then
        base="/data/local/tmp"
    fi

    printf '%s/.%s.lock' "$base" "$name"
}

# acquire_lock <lock_dir> [stale_seconds]
# Returns 0 on success, 1 if another process holds it.
acquire_lock() {
    local lock_dir="$1"
    local stale_seconds="${2:-600}"
    local tries=0

    [ -z "$lock_dir" ] && return 1

    while [ "$tries" -lt 3 ]; do
        if mkdir "$lock_dir" 2>/dev/null; then
            return 0
        fi

        if [ -d "$lock_dir" ] && _lock_is_stale "$lock_dir" "$stale_seconds"; then
            rm -rf "$lock_dir" 2>/dev/null
            tries=$((tries + 1))
            continue
        fi

        return 1
    done
    return 1
}

# release_lock <lock_dir>
release_lock() {
    [ -n "$1" ] && [ -d "$1" ] && rmdir "$1" 2>/dev/null
    return 0
}

# _lock_is_stale <lock_dir> <stale_seconds>
_lock_is_stale() {
    local lock_dir="$1"
    local stale_seconds="$2"
    local lock_mtime now age

    lock_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null) \
        || lock_mtime=$(stat -f %m "$lock_dir" 2>/dev/null) \
        || lock_mtime=0

    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    case "$lock_mtime" in ''|*[!0-9]*) lock_mtime=0 ;; esac

    [ "$now" -le 0 ] && return 1
    [ "$lock_mtime" -le 0 ] && return 1

    age=$((now - lock_mtime))
    [ "$age" -gt "$stale_seconds" ]
}

# ============================================================
# [5] Port polling
# ============================================================
# wait_port_free <port> [proto] [timeout_ticks]
wait_port_free() {
    local port="$1"
    local proto="${2:-tcp}"
    local timeout="${3:-30}"
    local wait=0

    [ -z "$port" ] && return 1
    command -v is_port_open >/dev/null 2>&1 || return 1

    while [ "$wait" -lt "$timeout" ]; do
        if ! is_port_open "$port" "$proto" 2>/dev/null; then
            return 0
        fi
        sleep 0.1
        wait=$((wait + 1))
    done
    return 1
}

# wait_port_listening <port> [proto] [timeout_seconds]
wait_port_listening() {
    local port="$1"
    local proto="${2:-tcp}"
    local timeout="${3:-35}"
    local wait=0

    [ -z "$port" ] && return 1
    command -v is_port_open >/dev/null 2>&1 || return 1

    while [ "$wait" -lt "$timeout" ]; do
        if is_port_open "$port" "$proto" 2>/dev/null; then
            return 0
        fi
        sleep 1
        wait=$((wait + 1))
    done
    return 1
}

# ============================================================
# [6] Watchdog verification
# ============================================================

# existing_watchdog_pid <pid_file>
# Four-layer verification that the PID in the file is a LIVE,
# NON-ZOMBIE process whose cmdline contains "watchdog.sh".
existing_watchdog_pid() {
    local pid_file="$1"
    local pid state cmdline

    [ -f "$pid_file" ] || return 1
    pid=$(cat "$pid_file" 2>/dev/null | tr -d '\r\n ')
    [ -z "$pid" ] && return 1
    [ -d "/proc/$pid" ] || return 1

    state=$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null | awk '{print $1}')
    [ "$state" = "Z" ] && return 1

    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
    case "$cmdline" in
        *watchdog.sh*) printf '%s' "$pid"; return 0 ;;
    esac
    return 1
}

# is_duplicate_watchdog <pid_file>
# Returns 0 if a verified watchdog is already running.
is_duplicate_watchdog() {
    [ -n "$(existing_watchdog_pid "$1" 2>/dev/null)" ]
}