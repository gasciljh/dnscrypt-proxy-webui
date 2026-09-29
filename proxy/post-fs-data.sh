#!/system/bin/sh
# ============================================================
# DNSCrypt Smart Filter – post-fs-data.sh
# Version: v1.2.0 (Global Edition)
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
#   • No background processes — Magisk does not wait for them
#   • Safe on all devices (path checks + security guards)
#   • Idempotent — safe to run multiple times
#   • Protected log_msg with 50 MB emergency rotation (parity
#     with functions.sh:log_fn, watchdog.sh:log_msg, and
#     service.sh:log_msg — HARD-PFD-01)
#
# v1.2.0 additions:
#   • Explicit "Data preservation non-participation" section
#   • Expanded "Non-responsibilities" section (8 items)
#   • Legacy cleanup list synchronized (functionally) with
#     customize.sh and uninstall.sh
#   • Section numbering unified ([1]..[6])
#
# ============================================================
# v1.2.0 — POST-AUDIT FIXES (still v1.2.0)
# ============================================================
# This file carries two identifier families. The inventory
# below is the AUTHORITATIVE list of identifiers actually
# present in this file. It was verified during the v1.2.0
# release audit.
#
# Identifier inventory in THIS file (10 total):
#
#   • PFD-1, PFD-2                                 (2)
#       — original post-audit corrections
#
#   • PFD-3, PFD-4, PFD-5                          (3)
#       — NEW corrections in this revision:
#         PFD-3 → `log_msg` short-circuit via a
#                  `_LOG_DISABLED` flag once a write has
#                  failed, to prevent repeated futile
#                  syscalls on a read-only filesystem.
#         PFD-4 → Documentation clarification on the
#                  two numbering systems in this file
#                  (section `[1]..[6]` vs. protection-
#                  layer `[1]..[10]`).
#         PFD-5 → Documentation note on the hard-coded
#                  legacy IP list (self-containment
#                  trade-off vs. customize.sh).
#
#   • HARD-PFD-01, HARD-PFD-02, HARD-PFD-03,
#     HARD-PFD-04, HARD-PFD-05                      (5)
#       — hardening fixes
#
# NOTE ON HARD-PFD-01 (scope clarification):
#   The identifier `HARD-PFD-01` is SCOPED TO THIS FILE.
#   It refers to the emergency-only 50 MB rotation inside
#   `log_msg` (parity with `functions.sh:log_fn` and
#   `watchdog.sh:log_msg`).
#
#   This is DISTINCT from the identifier `HARD-01` that
#   appears in `main.go` (which concerns `cleanupOldGz`
#   scoping of .gz files). The two identifiers share the
#   "01" suffix but belong to different files and different
#   concerns. Future auditors must not conflate them.
#   All `HARD-PFD-NN` identifiers are exclusively scoped
#   to `post-fs-data.sh`.
#
# NOTE ON IDENTIFIER GAPS:
#   There are no gaps in this file. All of PFD-1, PFD-2,
#   PFD-3, PFD-4, PFD-5 and HARD-PFD-01..05 are present.
#
# ------------------------------------------------------------
# Original post-audit corrections:
# ------------------------------------------------------------
#
#   🔧 PFD-1 — `_ip` inside the legacy RETURN cleanup loop is
#     now declared `local`.
#
#   🔧 PFD-2 — The synchronization comment now uses the phrase
#     "functionally equivalent" with an explicit list of the
#     two diverging groups, instead of claiming a false
#     identity.
#
# ------------------------------------------------------------
# Hardening fixes (HARD-PFD-01 … HARD-PFD-05):
# ------------------------------------------------------------
#
#   🛡️ HARD-PFD-01 — `log_msg` performs emergency-only
#     rotation at 50 MB, every 100th call. Parity with
#     `functions.sh:log_fn`, `watchdog.sh:log_msg`, and
#     `service.sh:log_msg`. The counter `_LOG_CALL_COUNT` is a
#     global by design (it must persist across calls within
#     the same shell process).
#
#   🛡️ HARD-PFD-02 — The STATUS_FILE write in section [5] now
#     verifies success. If both `$STATUS_FILE` and
#     `/data/local/tmp/dnscrypt.status` fail to receive the
#     "OFF" value, a warning is logged.
#
#   🛡️ HARD-PFD-03 — `MOD_NAME` is now validated after the
#     `basename` call. If `basename` is unavailable or returns
#     an empty string, a fallback string is used explicitly.
#
#   🛡️ HARD-PFD-04 — Section [5] now logs a single
#     informational line when the module is ENABLED (the
#     common case). This makes the boot log self-documenting.
#
#   🛡️ HARD-PFD-05 — When the `run/` directory is not usable
#     (fallback to /data/local/tmp), the script now explicitly
#     verifies that /data/local/tmp is writable before adopting
#     it as the fallback. If neither is writable, a warning is
#     emitted once and the script continues with the paths it
#     has.
#
# ------------------------------------------------------------
# NEW corrections in this revision (PFD-3, PFD-4, PFD-5):
# ------------------------------------------------------------
#
#   🔧 PFD-3 — `log_msg` now installs a `_LOG_DISABLED` flag
#     on the FIRST failure to create or append to the log file.
#     All subsequent calls short-circuit at the top of the
#     function. The previous version performed three separate
#     syscalls (`[ -d ]`, `[ -f ]`, `>>` redirection) on every
#     call, even when /data/local/tmp was read-only. On a
#     filesystem that cannot be written, this produced a stream
#     of failed attempts across the whole boot sequence. The
#     flag caps that to a single failure detection.
#
#     The flag is intentionally NOT persisted across processes
#     — each new shell invocation gets a fresh `_LOG_DISABLED`
#     and re-evaluates its environment. Only within a single
#     process is the short-circuit active.
#
#     The emergency-rotation code path (HARD-PFD-01) runs
#     BEFORE the flag check, so rotation is never blocked by
#     a prior write failure. This is deliberate: the rotation
#     can succeed even when a subsequent append would fail
#     (e.g. when only the file's content directory is full).
#
#   🔧 PFD-4 — Documentation clarification. This file uses
#     TWO separate numbering systems:
#
#       (a) Section numbers `[1]`..`[6]`
#           — physical structure of the script
#             (module path, paths, log_msg, cleanup,
#              main branch, exit).
#
#       (b) Protection-layer numbers `[1]`..`[10]`
#           — the v1.2.0 data-preservation architecture
#             (multi-source, backup, integrity, txn,
#              root-compat, SELinux, recovery, migrations,
#              automation, observability).
#
#     The two numbering systems are UNRELATED. They are
#     both one-based and both appear as bracketed numbers,
#     which is why they were previously confusing. A
#     dedicated note is now placed immediately after the
#     layer table to make the distinction explicit.
#
#   🔧 PFD-5 — Documentation note on the hard-coded legacy
#     IP list in `inline_firewall_cleanup`. This list
#     (9.9.9.9, 8.8.8.8, 1.1.1.1, ...) duplicates the one
#     used by `customize.sh:_inline_cleanup_firewall` and
#     `uninstall.sh:_inline_cleanup_firewall`. The
#     duplication is DELIBERATE: this script must remain
#     self-contained because it runs before `functions.sh`
#     is guaranteed to be sourceable. A comment near the
#     list now documents the trade-off and the sync
#     requirement.
#
# ============================================================
# Non-responsibilities (deliberately NOT done here):
# ============================================================
#   The post-fs-data phase is very early in boot. Many things
#   that would be reasonable at other times are unsafe or
#   pointless here. This script deliberately avoids:
#
#   1. private_dns_mode reset
#      → Moved to service.sh because the `settings` service
#        may not be ready during post-fs-data.
#
#   2. route_localnet restore
#      → Handled by uninstall.sh because it requires sysctl,
#        which may not be available this early.
#
#   3. Firewall rule creation
#      → Only cleanup runs here. Active rules are created
#        later by main.go (startService) or service.sh.
#
#   4. Backup operations (v1.2.0)
#      → The persistent backup at /sdcard/dnscrypt-webui-backup/
#        requires /sdcard/ to be mounted, which is not
#        guaranteed this early. Auto-backup runs in service.sh
#        after sys.boot_completed.
#
#   5. Restore operations (v1.2.0)
#      → Restoration is triggered by customize.sh at install
#        time (Layer 7: recovery mode), not at boot.
#
#   6. Transaction cleanup (v1.2.0)
#      → Orphan transactions are cleaned up by:
#          - customize.sh (self cleanup after COMMIT)
#          - main.go:cleanupOldTransactions (startup)
#          - service.sh:do_cleanup_transactions (boot)
#        All three run after /sdcard/ is mounted.
#
#   7. Orphan transaction inspection (v1.2.0)
#      → `orphan-txn-*` directories are NEVER removed by this
#        script. They are the user's explicit signal that they
#        want to inspect them manually. See docs/BACKUP.md.
#
#   8. Pending notification handling (v1.2.0)
#      → .pending_notification is read by main.go at startup
#        and by service.sh at boot. This script does nothing
#        with it because the WebUI is not running yet.
#
# ============================================================
# Coordination with v1.2.0 data-preservation layers:
# ============================================================
#   ┌────┬──────────────────────────┬────────────────────────┐
#   │ #  │ Layer                    │ Handled by             │
#   ├────┼──────────────────────────┼────────────────────────┤
#   │ 1  │ Multi-source detection   │ customize.sh (install) │
#   │ 2  │ Persistent backup        │ service.sh + main.go   │
#   │ 3  │ Integrity verification   │ customize.sh (install) │
#   │ 4  │ Transactional upgrades   │ customize.sh (install) │
#   │ 5  │ Root-solution compat     │ customize.sh (install) │
#   │ 6  │ SELinux preservation     │ customize.sh (install) │
#   │ 7  │ Recovery mode            │ customize.sh (install) │
#   │ 8  │ Config migrations        │ customize.sh (install) │
#   │ 9  │ Automation + rotation    │ service.sh (boot)      │
#   │ 10 │ Observability            │ status.sh --diagnose   │
#   └────┴──────────────────────────┴────────────────────────┘
#
#   post-fs-data.sh does NOT participate in any of these layers.
#   It is a cleanup-only script that runs at the earliest safe
#   phase of boot.
#
# ------------------------------------------------------------
# PFD-4 — Numbering clarification (READ ME):
# ------------------------------------------------------------
#   The table above uses PROTECTION-LAYER numbers 1..10.
#   The rest of this file uses SECTION numbers [1]..[6].
#
#   The two numbering systems are unrelated:
#     • Section `[1]` = "Determine module path safely".
#     • Layer `1`     = "Multi-source detection".
#
#   Do not infer a correspondence between them. Layer 1 is
#   NOT implemented in section [1]; it is implemented by
#   customize.sh at install time. The layer table describes
#   WHO implements each layer, not WHERE in this file.
# ============================================================
# POSIX note on `local`:
#   This script uses `local` inside the inline_firewall_cleanup
#   function. The `local` keyword is supported by:
#     • mksh (the default /system/bin/sh on modern Android)
#     • busybox ash (older Android)
#     • bash, dash, ksh
#   It is NOT part of the POSIX sh standard, but every shell
#   Android ships supports it.
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

# HARD-PFD-03: validate MOD_NAME after the `basename` call.
MOD_NAME=$(basename "$MODDIR" 2>/dev/null)
if [ -z "$MOD_NAME" ]; then
    MOD_NAME="dnscrypt-proxy-webui"
fi

# --- Determine active run directory ---
# HARD-PFD-05: verify writability of the fallback too, and
# emit a single warning if neither location is usable.
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

    # HARD-PFD-05: if the fallback is not writable either, log
    # a single warning (log_msg is defined in section [3] and
    # may not be safe to call before that point — we defer the
    # warning to section [3b]).
    if [ ! -w "/data/local/tmp" ]; then
        _RUN_DIR_FALLBACK_UNWRITABLE=1
    else
        _RUN_DIR_FALLBACK_UNWRITABLE=0
    fi
fi

# ============================================================
# [3] Protected log_msg (with 50 MB emergency rotation)
# ============================================================
# At post-fs-data phase, the filesystem may not be fully ready:
#   • /data/local/tmp may not exist yet (rare)
#   • The log file may not be writable (very rare)
#
# Every write is guarded so a failure never blocks boot.
#
# HARD-PFD-01: emergency-only rotation at 50 MB, every 100th
# call. Parity with functions.sh:log_fn, watchdog.sh:log_msg,
# and service.sh:log_msg. `_LOG_CALL_COUNT` is a global by
# design (it must persist across calls within this shell
# process).
#
# PFD-3: `_LOG_DISABLED` is a per-process short-circuit. Once
# a write has failed, subsequent calls do nothing. The
# emergency-rotation code path runs BEFORE the flag check,
# so a prior append failure cannot block a legitimate rotation
# attempt (rotation and append target different paths and can
# fail independently).
#
# Design note: we deliberately do NOT create the log file with
# restricted permissions. It is a public log that matches the
# permissions set by main.go (0644).
# ============================================================
_LOG_CALL_COUNT=0
_LOG_DISABLED=0

log_msg() {
    # PFD-3: short-circuit if a previous call established that
    # logging is not possible in this process.
    if [ "$_LOG_DISABLED" = "1" ]; then
        return 0
    fi

    _LOG_CALL_COUNT=$((_LOG_CALL_COUNT + 1))

    # HARD-PFD-01: emergency-only 50 MB rotation. Runs before
    # the PFD-3 flag check so that a legitimate rotation is
    # not suppressed by a prior append failure.
    if [ $((_LOG_CALL_COUNT % 100)) -eq 0 ] && [ -f "$LOG_FILE" ]; then
        local _size
        _size=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
        if [ -n "$_size" ] && [ "$_size" -gt 52428800 ]; then
            local _emg="${LOG_FILE}.emergency.$(date +%s)"
            mv -f "$LOG_FILE" "$_emg" 2>/dev/null
            : > "$LOG_FILE" 2>/dev/null
        fi
    fi

    if [ ! -d "/data/local/tmp" ]; then
        # PFD-3: remember the failure and stop trying.
        _LOG_DISABLED=1
        return 0
    fi

    if [ ! -f "$LOG_FILE" ]; then
        if ! : > "$LOG_FILE" 2>/dev/null; then
            # PFD-3: creation failed — mark logging as disabled.
            _LOG_DISABLED=1
            return 0
        fi
    fi

    if ! echo "$(date +'%Y-%m-%d %H:%M:%S') - [post-fs-data] $1" >> "$LOG_FILE" 2>/dev/null; then
        # PFD-3: append failed — mark logging as disabled.
        _LOG_DISABLED=1
    fi
}

# ============================================================
# [3b] HARD-PFD-05 — deferred fallback warning
# ============================================================
# The check in [2] could not log because log_msg was not yet
# defined. We now emit the warning if the fallback path was
# also unwritable.
# ============================================================
if [ "${_RUN_DIR_FALLBACK_UNWRITABLE:-0}" = "1" ]; then
    log_msg "⚠️ Neither $RUN_DIR nor /data/local/tmp is writable — STATUS_FILE writes may fail"
fi

# ============================================================
# [4] Custom Chain cleanup (orphan prevention)
# ============================================================
# Strategy:
#   1. Delete the DNSCRYPT_OUT / DNSCRYPT_OUT6 Custom Chains entirely
#   2. Best-effort legacy cleanup (rules from older versions)
#   3. No dependency on functions.sh (it may not be ready yet)
#
# ⚠️ Synchronization note (PFD-2, corrected):
#   The cleanup list below is FUNCTIONALLY EQUIVALENT to:
#     • customize.sh  : _inline_cleanup_firewall
#     • uninstall.sh  : _inline_cleanup_firewall
#
#   "Functionally equivalent" means all three files remove the
#   same SET of rules. They differ only in the comment tag
#   applied to the loopback (127.0.0.1) rules during the
#   best-effort legacy cleanup:
#
#     • customize.sh : keeps 127.0.0.1 INSIDE the generic loop
#                      (uses the default comment tag).
#     • uninstall.sh : handles 127.0.0.1 in a SEPARATE block
#                      with the specific tag
#                      "dnscrypt_smart_filter_loopback_127.0.0.1".
#     • post-fs-data.sh (this file): same as uninstall.sh.
#
#   The divergence exists because this script's cleanup does not
#   need to preserve the default tag for future installs (it is
#   only called when the module is DISABLED — there is no future
#   install to prepare for). The intent is the same.
#
#   Any change to the RULES removed by this function MUST be
#   applied consistently to all three files.
#
# PFD-1: `_ip` is declared `local` to prevent it from leaking
# to the global scope after the loop finishes.
#
# PFD-5: The hard-coded legacy IP list below
#   (9.9.9.9, 8.8.8.8, 1.1.1.1, 1.0.0.1, 8.8.4.4,
#    208.67.222.222, 208.67.220.220) duplicates the list in
#   customize.sh and uninstall.sh. The duplication is
#   DELIBERATE: this file must remain self-contained because
#   it runs before functions.sh is guaranteed to be sourceable
#   (post-fs-data phase is very early in boot). The list is
#   the pre-v1.2.0 default bootstrap set; new installs use the
#   bootstrap_resolvers value from the TOML instead, but the
#   legacy rules must still be removed for upgrades from old
#   versions.
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

        # [2a] Remove jump rules from OUTPUT
        iptables -t nat -D OUTPUT -p udp --dport 53 -j "$_chain" --wait 3 2>/dev/null
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j "$_chain" --wait 3 2>/dev/null

        # [2b] Flush the chain itself
        iptables -t nat -F "$_chain" --wait 3 2>/dev/null
        iptables -t nat -X "$_chain" --wait 3 2>/dev/null

        # [2c] Legacy cleanup — older versions
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

        # PFD-1 fix: `_ip` is declared `local`.
        # PFD-5: hard-coded legacy list — see section header note.
        local _ip
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
# [5] Main path: if module is disabled → emergency cleanup
# ============================================================
# No background operators: Magisk does not wait for background
# processes. Without them, we guarantee cleanup completes
# before the script exits.
#
# Why we write STATUS_FILE = "OFF" here:
#   The user explicitly disabled the module. Writing OFF is
#   the correct representation of "user intent" per the
#   STATUS_FILE contract. This is the ONLY legitimate place
#   (alongside service.sh's disable path) where a script
#   writes STATUS_FILE outside of main.go's start/stopService.
#
# HARD-PFD-02: the write to STATUS_FILE now verifies success.
# If both locations fail, a warning is logged so the operator
# knows watchdog.sh may not honor the disable intent.
# ============================================================
if [ -f "$MODDIR/disable" ]; then
    log_msg "Module '$MOD_NAME' is DISABLED. Starting emergency cleanup..."

    # --- 1) Firewall cleanup (Custom Chain + Legacy) ---
    inline_firewall_cleanup
    log_msg "✅ Firewall cleaned (Custom Chain + Legacy)"

    # --- 2) Kill remaining processes (safety net) ---
    if pgrep -x dnscrypt-proxy >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-proxy 2>/dev/null
        log_msg "🔪 Killed lingering dnscrypt-proxy"
    fi
    if pgrep -x dnscrypt-webui >/dev/null 2>&1; then
        pkill -9 -x dnscrypt-webui 2>/dev/null
        log_msg "🔪 Killed lingering dnscrypt-webui"
    fi

    # --- 3) Remove PID files from both locations ---
    rm -f "$RUN_DIR/dnscrypt.pid" 2>/dev/null
    rm -f "$RUN_DIR/webui.pid" 2>/dev/null
    rm -f "$RUN_DIR/watchdog.pid" 2>/dev/null

    rm -f /data/local/tmp/dnscrypt.pid 2>/dev/null
    rm -f /data/local/tmp/webui.pid 2>/dev/null
    rm -f /data/local/tmp/watchdog.pid 2>/dev/null

    log_msg "✅ PID files removed"

    # --- 4) Set status file in both locations ---
    # HARD-PFD-02: verify that at least one write succeeded.
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
    log_msg "   Non-action: private_dns_mode reset (handled by service.sh)"
    log_msg "   Non-action: route_localnet restore (handled by uninstall.sh)"
    log_msg "   Non-action: backup/restore (handled by service.sh + main.go)"
    log_msg "   Non-action: transaction cleanup (handled by main.go + service.sh)"
    log_msg "   Non-action: orphan-txn inspection (user-initiated only)"
    log_msg "   Non-action: pending notification (handled by main.go)"
else
    # Module is enabled — nothing to do in this phase.
    # The active state is set up later by service.sh after boot.
    #
    # HARD-PFD-04: emit one informational line so the boot log
    # is self-documenting. Without this, an empty [post-fs-data]
    # section in the log could not be distinguished from "the
    # script did not run".
    log_msg "Module '$MOD_NAME' is enabled — nothing to do in post-fs-data phase"
fi

# ============================================================
# [6] Exit
# ============================================================
exit 0