#!/system/bin/sh
# shellcheck shell=ksh
# ============================================================
# DNSCrypt Smart Filter — lib/backup.sh
# Version: v1.6.0 (Global Edition)
# Last updated: 2026-11-13
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# User-data preservation: snapshots, manifests, transactions,
# rotation, restore, and the .last_stable pointer.
#
# Sourced by boot-mini.sh after lib/constants.sh and
# lib/process.sh. Requires at call time:
#   LOG_FILE, PERSISTENT_BACKUP, LAST_STABLE_FILE,
#   LAST_AUTO_BACKUP_MARKER, USER_FILES, MODULE_VERSION,
#   ROOT_SOLUTION, BACKUP_ROTATION_KEEP,
#   BIN_DIR (used by restore_user_files as the default dst_dir;
#            set by init_module_paths() in lib/constants.sh —
#            callers that skip init_module_paths MUST pass an
#            explicit second argument)
#
# Invariant: backup_create() never touches .last_stable. Only
# an explicit mark_last_stable() call does, made by
# customize.sh at transaction COMMIT time — never by
# auto-backup, manual backup, or recovery restore.
# ============================================================

if [ -n "${_LIB_BACKUP_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_LIB_BACKUP_LOADED=1

# ============================================================
# [1] Logging helper
# ============================================================
_bk_log() {
    if command -v log_msg >/dev/null 2>&1; then
        log_msg "$1"
    else
        printf '%s\n' "$1" >&2
    fi
}

# ============================================================
# [2] File copy with SELinux context
# ============================================================
copy_with_context() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 1
    [ -n "$dst" ] || return 1

    if ! cp -f "$src" "$dst" 2>/dev/null; then
        return 1
    fi
    if command -v restorecon >/dev/null 2>&1; then
        restorecon "$dst" 2>/dev/null || true
    elif command -v chcon >/dev/null 2>&1; then
        chcon u:object_r:magisk_file:s0 "$dst" 2>/dev/null || true
    fi
    chmod 0600 "$dst" 2>/dev/null
    return 0
}

# ============================================================
# [3] JSON escape
# ============================================================
json_escape() {
    printf '%s' "$1" | awk '
        BEGIN { ORS = "" }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            gsub(/\t/, "\\t")
            gsub(/\r/, "\\r")
            if (NR > 1) printf "\\n"
            printf "%s", $0
        }
    ' | tr -d '\000-\010\013\014\016-\037'
}

# ============================================================
# [4] Manifest writer — explicit timestamp
# ============================================================
write_manifest_to() {
    local target_dir="$1"
    local ts="$2"
    local source="$3"
    local count="$4"
    local version="${5:-${MODULE_VERSION:-unknown}}"
    local root_sol="${6:-${ROOT_SOLUTION:-unknown}}"
    local manifest="$target_dir/.manifest.json"

    [ -d "$target_dir" ] || return 1
    [ -n "$ts" ] || return 1

    local version_escaped src_escaped root_escaped
    version_escaped=$(json_escape "$version")
    src_escaped=$(json_escape "$source")
    root_escaped=$(json_escape "$root_sol")

    local files_json="" f sha
    for f in $USER_FILES; do
        [ -f "$target_dir/$f" ] || continue
        sha=""
        if command -v sha256sum >/dev/null 2>&1; then
            sha=$(sha256sum "$target_dir/$f" 2>/dev/null | awk '{print $1}')
        fi
        files_json="$files_json{\"name\":\"$f\",\"sha256\":\"$sha\"},"
    done
    files_json="${files_json%,}"

    if ! cat > "$manifest" << EOF
{
  "version": "$version_escaped",
  "timestamp": "$ts",
  "source": "$src_escaped",
  "root_solution": "$root_escaped",
  "files_count": $count,
  "files": [$files_json]
}
EOF
    then
        return 1
    fi
    chmod 0600 "$manifest" 2>/dev/null
    return 0
}

# Backward-compat wrapper — uses current time if BACKUP_TIMESTAMP unset.
write_manifest() {
    local target_dir="$1"
    local source="$2"
    local count="$3"
    local version="${4:-${MODULE_VERSION:-unknown}}"
    local root_sol="${5:-${ROOT_SOLUTION:-unknown}}"
    local ts="${BACKUP_TIMESTAMP:-}"

    if [ -z "$ts" ]; then
        ts=$(date -u +%Y%m%d-%H%M%S)
        _bk_log "write_manifest: BACKUP_TIMESTAMP unset, using current time"
    fi
    write_manifest_to "$target_dir" "$ts" "$source" "$count" "$version" "$root_sol"
}

# ============================================================
# [5] Snapshot enumeration
# ============================================================
list_snapshots() {
    local limit="${1:-0}"
    local parent="${2:-$PERSISTENT_BACKUP}"
    local _d ts list

    [ -d "$parent" ] || return 0

    list=$(
        cd "$parent" 2>/dev/null || exit 0
        for _d in */; do
            _d="${_d%/}"
            [ -d "$_d" ] || continue
            case "$_d" in
                $SNAPSHOT_EXCLUDE_PATTERN) continue ;;
            esac
            printf '%s' "$_d" | grep -qE "$SNAPSHOT_TS_REGEX" || continue
            [ -f "$_d/.manifest.json" ] || continue
            ts=$(printf '%s' "$_d" | cut -d'-' -f1,2)
            case "$ts" in ''|*[!0-9-]*) ts="00000000-000000" ;; esac
            printf '%s %s\n' "$ts" "$_d"
        done | LC_ALL=C sort -r -k1,1 | awk '{print $2}'
    )

    [ -z "$list" ] && return 0

    if [ "$limit" -gt 0 ] 2>/dev/null; then
        printf '%s\n' "$list" | head -n "$limit"
    else
        printf '%s\n' "$list"
    fi
}

count_snapshots() {
    local parent="${1:-$PERSISTENT_BACKUP}"
    local count
    count=$(list_snapshots 0 "$parent" | wc -l | tr -d ' ')
    printf '%s' "${count:-0}"
}

# ============================================================
# [6] Integrity verification
# ============================================================
verify_backup_integrity() {
    local dir="$1"
    local strict="${2:-0}"
    local manifest="$dir/.manifest.json"

    [ -d "$dir" ] || return 1

    local errors=0 checked=0
    local has_jq=0 has_sha=0
    command -v jq >/dev/null 2>&1 && has_jq=1
    command -v sha256sum >/dev/null 2>&1 && has_sha=1

    if [ "$strict" = "1" ]; then
        [ ! -f "$manifest" ] && return 1
        [ "$has_sha" != "1" ] && return 1
    fi

    local manifest_count=0
    if [ "$strict" = "1" ] && [ "$has_jq" = "1" ]; then
        manifest_count=$(jq -r '.files_count // 0' "$manifest" 2>/dev/null)
        case "$manifest_count" in ''|*[!0-9]*) manifest_count=0 ;; esac
    fi

    local f file size expected_sha actual_sha
    for f in $USER_FILES; do
        file="$dir/$f"
        [ -f "$file" ] || continue
        checked=$((checked + 1))

        if [ ! -s "$file" ]; then
            errors=$((errors + 1))
            continue
        fi
        size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
        if [ -n "$size" ] && [ "$size" -gt 10485760 ]; then
            errors=$((errors + 1))
            continue
        fi
        [ -f "$manifest" ] || continue
        [ "$has_sha" != "1" ] && continue

        expected_sha=""
        if [ "$has_jq" = "1" ]; then
            expected_sha=$(jq -r --arg name "$f" '.files[]? | select(.name == $name) | .sha256 // empty' "$manifest" 2>/dev/null | head -n1)
        fi
        [ -z "$expected_sha" ] && continue

        actual_sha=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
        [ "$actual_sha" != "$expected_sha" ] && errors=$((errors + 1))
    done

    [ "$checked" -eq 0 ] && return 1
    if [ "$strict" = "1" ] && [ "$manifest_count" -gt 0 ] && [ "$checked" -ne "$manifest_count" ]; then
        errors=$((errors + 1))
    fi
    [ "$errors" -eq 0 ]
}

# ============================================================
# [7] Backup creation
# ============================================================
backup_create() {
    local src_dir="$1"
    local dst_dir="${2:-}"
    local version="${3:-${MODULE_VERSION:-unknown}}"
    local source="${4:-unknown}"
    local _ts f count=0

    BACKUP_CREATED_PATH=""
    BACKUP_CREATED_TS=""

    [ -d "$src_dir" ] || return 1

    if [ -z "$dst_dir" ]; then
        ensure_backup_dir || return 1
        _ts=$(date -u +%Y%m%d-%H%M%S)
        dst_dir="$PERSISTENT_BACKUP/$_ts-manual-$$"
    else
        _ts=$(basename "$dst_dir" | cut -d'-' -f1,2)
        case "$_ts" in
            ''|*[!0-9-]*) _ts=$(date -u +%Y%m%d-%H%M%S) ;;
            *)
                [ "${#_ts}" -ne 15 ] && _ts=$(date -u +%Y%m%d-%H%M%S)
                ;;
        esac
    fi

    mkdir -p "$dst_dir" 2>/dev/null || return 1
    chmod 0700 "$dst_dir" 2>/dev/null

    for f in $USER_FILES; do
        if [ -f "$src_dir/$f" ] && [ -s "$src_dir/$f" ]; then
            copy_with_context "$src_dir/$f" "$dst_dir/$f" && count=$((count + 1))
        fi
    done

    if [ "$count" -eq 0 ]; then
        rm -rf "$dst_dir" 2>/dev/null
        return 1
    fi

    # Hard failure: a snapshot without a manifest must not
    # survive to be referenced by .last_stable.
    if ! write_manifest_to "$dst_dir" "$_ts" "$source" "$count" "$version"; then
        rm -rf "$dst_dir" 2>/dev/null
        return 1
    fi

    _sync_current_dir "$dst_dir" >/dev/null 2>&1 || true

    BACKUP_CREATED_PATH="$dst_dir"
    BACKUP_CREATED_TS="$_ts"
    return 0
}

# Sync PERSISTENT_BACKUP/current/ (always reflects newest snapshot).
_sync_current_dir() {
    local src_dir="$1"
    local current="$PERSISTENT_BACKUP/current"
    local tmp="$PERSISTENT_BACKUP/.current.tmp.$$"
    local old="$PERSISTENT_BACKUP/.current.old.$$"
    local f cur_count=0

    rm -rf "$tmp" "$old" 2>/dev/null
    mkdir -p "$tmp" 2>/dev/null || return 1

    for f in $USER_FILES; do
        if [ -f "$src_dir/$f" ] && [ -s "$src_dir/$f" ]; then
            copy_with_context "$src_dir/$f" "$tmp/$f" && cur_count=$((cur_count + 1))
        fi
    done

    if [ -f "$src_dir/.manifest.json" ]; then
        cp -f "$src_dir/.manifest.json" "$tmp/.manifest.json" 2>/dev/null
        chmod 0600 "$tmp/.manifest.json" 2>/dev/null
    fi

    if [ "$cur_count" -eq 0 ]; then
        rm -rf "$tmp" 2>/dev/null
        return 1
    fi

    [ -d "$current" ] && mv -f "$current" "$old" 2>/dev/null

    if mv -f "$tmp" "$current" 2>/dev/null; then
        rm -rf "$old" 2>/dev/null
        return 0
    else
        [ -d "$old" ] && mv -f "$old" "$current" 2>/dev/null
        rm -rf "$tmp" 2>/dev/null
        return 1
    fi
}

# Backward-compat: creates a manual snapshot. Never marks stable.
backup_user_files() {
    local src="$1"
    local dst="${2:-}"
    local version="${3:-${MODULE_VERSION:-unknown}}"

    backup_create "$src" "$dst" "$version" "manual:$$" || return 1
    _bk_log "backup: $BACKUP_CREATED_PATH"
    return 0
}

# ============================================================
# [8] Restore
# ============================================================
# NOTE: dst_dir defaults to $BIN_DIR. Callers that do not call
# init_module_paths() MUST pass an explicit second argument,
# otherwise $BIN_DIR is empty and the function returns 1.
restore_user_files() {
    local src_dir="$1"
    local dst_dir="${2:-$BIN_DIR}"
    local _cf _f

    [ -d "$src_dir" ] || return 1
    [ -n "$dst_dir" ] || return 1
    [ -d "$dst_dir" ] || mkdir -p "$dst_dir" 2>/dev/null || return 1

    for _cf in webui.conf dnscrypt-proxy.toml; do
        if [ ! -f "$src_dir/$_cf" ] || [ ! -s "$src_dir/$_cf" ]; then
            _bk_log "restore: critical source missing: $_cf"
            return 1
        fi
    done

    verify_backup_integrity "$src_dir" 0 >/dev/null 2>&1 || true

    local snapdir restored=0 critical_failed=0
    snapdir=$(mktemp -d "${dst_dir}/.restore_snap.XXXXXX" 2>/dev/null) || snapdir=""

    if [ -n "$snapdir" ]; then
        for _cf in webui.conf dnscrypt-proxy.toml; do
            if [ -f "$dst_dir/$_cf" ] && [ -s "$dst_dir/$_cf" ]; then
                cp -f "$dst_dir/$_cf" "$snapdir/$_cf" 2>/dev/null || { rm -rf "$snapdir"; snapdir=""; break; }
            else
                : > "$snapdir/$_cf.absent" 2>/dev/null
            fi
        done
    fi

    for _f in $USER_FILES; do
        if [ -f "$src_dir/$_f" ] && [ -s "$src_dir/$_f" ]; then
            if copy_with_context "$src_dir/$_f" "$dst_dir/$_f"; then
                if [ -f "$dst_dir/$_f" ] && [ -s "$dst_dir/$_f" ]; then
                    restored=$((restored + 1))
                else
                    case "$_f" in webui.conf|dnscrypt-proxy.toml) critical_failed=1; break ;; esac
                fi
            else
                case "$_f" in webui.conf|dnscrypt-proxy.toml) critical_failed=1; break ;; esac
            fi
        fi
    done

    if [ "$critical_failed" = "1" ] && [ -n "$snapdir" ]; then
        for _cf in webui.conf dnscrypt-proxy.toml; do
            if [ -f "$snapdir/$_cf" ]; then
                cp -f "$snapdir/$_cf" "$dst_dir/$_cf" 2>/dev/null && chmod 0600 "$dst_dir/$_cf" 2>/dev/null
            elif [ -f "$snapdir/$_cf.absent" ]; then
                rm -f "$dst_dir/$_cf" 2>/dev/null
            fi
        done
    fi
    [ -n "$snapdir" ] && rm -rf "$snapdir" 2>/dev/null

    [ "$critical_failed" = "1" ] && return 1
    [ "$restored" -gt 0 ]
}

# ============================================================
# [9] Rotation
# ============================================================
rotate_backups() {
    local keep="${1:-$BACKUP_ROTATION_KEEP}"
    local protected="" list total to_remove newest name

    [ -d "$PERSISTENT_BACKUP" ] || return 0
    [ -r "$PERSISTENT_BACKUP" ] || return 0

    [ -f "$LAST_STABLE_FILE" ] && protected=$(read_last_stable 2>/dev/null)

    list=$(list_snapshots 0)
    [ -z "$list" ] && return 0

    total=$(printf '%s\n' "$list" | wc -l | tr -d ' ')
    [ "$total" -le "$keep" ] && return 0

    to_remove=$((total - keep))
    newest=$(printf '%s\n' "$list" | head -n1)

    while IFS= read -r name; do
        [ -z "$name" ] && continue
        [ "$name" = "$protected" ] && continue
        [ "$name" = "$newest" ] && continue
        rm -rf "${PERSISTENT_BACKUP:?}/${name:?}" 2>/dev/null
    done <<EOF
$(printf '%s\n' "$list" | tail -n "$to_remove")
EOF
    return 0
}

# ============================================================
# [10] Directory helpers
# ============================================================
ensure_backup_dir() {
    if [ ! -d "$PERSISTENT_BACKUP" ]; then
        mkdir -p "$PERSISTENT_BACKUP" 2>/dev/null || return 1
    fi
    chmod 0700 "$PERSISTENT_BACKUP" 2>/dev/null || true
    return 0
}

get_last_backup_time() {
    local marker="$LAST_AUTO_BACKUP_MARKER"
    local mtime

    [ -f "$marker" ] || { printf '0'; return 0; }

    mtime=$(stat -c %Y "$marker" 2>/dev/null) \
        || mtime=$(stat -f %m "$marker" 2>/dev/null) \
        || mtime=0
    case "$mtime" in ''|*[!0-9]*) mtime=0 ;; esac
    printf '%s' "$mtime"
}

# ============================================================
# [11] Auto-backup
# ============================================================
auto_backup_if_needed() {
    local interval="${1:-${AUTO_BACKUP_INTERVAL:-86400}}"
    local src_dir="${BIN_DIR:-$MODDIR/proxy}"
    local last now age ts target

    [ -d "$src_dir" ] || return 0
    ensure_backup_dir || return 0

    case "$interval" in ''|*[!0-9]*) interval=86400 ;; esac

    last=$(get_last_backup_time)
    case "$last" in ''|*[!0-9]*) last=0 ;; esac
    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    [ "$now" -le 0 ] && return 0

    age=$((now - last))
    if [ "$last" -gt 0 ] && [ "$age" -lt "$interval" ]; then
        return 0
    fi

    ts=$(date -u +%Y%m%d-%H%M%S)
    target="$PERSISTENT_BACKUP/$ts-auto-$$"

    if backup_create "$src_dir" "$target" "$MODULE_VERSION" "auto:$$"; then
        touch "$LAST_AUTO_BACKUP_MARKER" 2>/dev/null || true
        rotate_backups "$BACKUP_ROTATION_KEEP"
        _bk_log "auto_backup: $target"
        return 0
    fi
    return 1
}

# ============================================================
# [12] Transactions
# ============================================================
TXN_DIR=""
TXN_ACTIVE=0

transaction_begin() {
    local txn_root="$PERSISTENT_BACKUP"
    local ts pid txn_dir

    TXN_DIR=""
    TXN_ACTIVE=0

    ensure_backup_dir || return 1

    ts=$(date -u +%Y%m%d-%H%M%S)
    pid="$$"
    txn_dir="$txn_root/txn-${ts}-${pid}"

    mkdir -p "$txn_dir" 2>/dev/null || return 1
    chmod 0700 "$txn_dir" 2>/dev/null

    if ! echo "START" > "$txn_dir/.state" 2>/dev/null; then
        rm -rf "$txn_dir" 2>/dev/null
        return 1
    fi
    echo "$pid" > "$txn_dir/.pid" 2>/dev/null
    echo "$ts" > "$txn_dir/.start_ts" 2>/dev/null

    TXN_DIR="$txn_dir"
    TXN_ACTIVE=1
    return 0
}

transaction_commit() {
    if [ "${TXN_ACTIVE:-0}" != "1" ] || [ -z "${TXN_DIR:-}" ]; then
        return 0
    fi
    if ! echo "COMMIT" > "$TXN_DIR/.state" 2>/dev/null; then
        return 1
    fi
    TXN_ACTIVE=0
    return 0
}

transaction_rollback() {
    if [ -z "${TXN_DIR:-}" ] || [ ! -d "$TXN_DIR" ]; then
        TXN_ACTIVE=0
        return 0
    fi
    echo "ROLLBACK" > "$TXN_DIR/.state" 2>/dev/null
    TXN_ACTIVE=0
    return 0
}

cleanup_stale_transactions() {
    local txn_root="$PERSISTENT_BACKUP"
    local txn_dir name state start_mtime now age
    local stale_threshold=3600

    [ -d "$txn_root" ] || return 0

    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac

    for txn_dir in "$txn_root"/txn-*; do
        [ -d "$txn_dir" ] || continue
        name=$(basename "$txn_dir")
        state=""
        [ -f "$txn_dir/.state" ] && state=$(cat "$txn_dir/.state" 2>/dev/null | tr -d '\r\n ')

        case "$state" in
            COMMIT|ROLLBACK)
                rm -rf "$txn_dir" 2>/dev/null
                ;;
            START|"")
                start_mtime=$(stat -c %Y "$txn_dir" 2>/dev/null) \
                    || start_mtime=$(stat -f %m "$txn_dir" 2>/dev/null) \
                    || start_mtime=0
                case "$start_mtime" in ''|*[!0-9]*) start_mtime=0 ;; esac

                if [ "$now" -gt 0 ] && [ "$start_mtime" -gt 0 ]; then
                    age=$((now - start_mtime))
                    if [ "$age" -gt "$stale_threshold" ]; then
                        if mv "$txn_dir" "$txn_root/orphan-$name" 2>/dev/null; then
                            _bk_log "cleanup_stale_transactions: orphaned $name"
                        fi
                    fi
                fi
                ;;
        esac
    done
    return 0
}

cleanup_old_transactions() {
    cleanup_stale_transactions
}

# ============================================================
# [13] .last_stable — explicit-only
# ============================================================
mark_last_stable() {
    local name="$1"
    local tmp

    [ -n "$name" ] || return 1
    [ -d "$PERSISTENT_BACKUP/$name" ] || return 1

    tmp="$PERSISTENT_BACKUP/.last_stable.tmp.$$"
    if printf '%s' "$name" > "$tmp" 2>/dev/null; then
        if mv -f "$tmp" "$PERSISTENT_BACKUP/.last_stable" 2>/dev/null; then
            return 0
        fi
    fi
    rm -f "$tmp" 2>/dev/null
    return 1
}

read_last_stable() {
    [ -f "$LAST_STABLE_FILE" ] || return 1
    local name
    name=$(cat "$LAST_STABLE_FILE" 2>/dev/null | tr -d '\r\n ')
    [ -z "$name" ] && return 1
    printf '%s' "$name"
    return 0
}

# ============================================================
# [14] Source version reader
# ============================================================
read_source_version() {
    local src="$1"
    local v

    [ -n "$src" ] && [ -d "$src" ] || return 1

    if [ -f "$src/.manifest.json" ]; then
        if command -v jq >/dev/null 2>&1; then
            v=$(jq -r '.version // empty' "$src/.manifest.json" 2>/dev/null | head -n1)
        fi
        if [ -z "$v" ]; then
            v=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$src/.manifest.json" 2>/dev/null \
                | head -n1 \
                | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        fi
        [ -n "$v" ] && { printf '%s' "$v"; return 0; }
    fi

    if [ -f "$src/../module.prop" ]; then
        v=$(grep '^version=' "$src/../module.prop" 2>/dev/null | cut -d= -f2- | tr -d '\r ')
        [ -n "$v" ] && { printf '%s' "$v"; return 0; }
    fi
    if [ -f "$src/module.prop" ]; then
        v=$(grep '^version=' "$src/module.prop" 2>/dev/null | cut -d= -f2- | tr -d '\r ')
        [ -n "$v" ] && { printf '%s' "$v"; return 0; }
    fi
    return 1
}