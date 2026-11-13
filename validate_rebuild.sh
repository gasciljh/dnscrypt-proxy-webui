#!/system/bin/sh
# ============================================================
# DNSCrypt v1.6.0 Rebuild — Local Validation Suite (v2)
# Fixed: main.go path = proxy/main.go, go.mod = proxy/go.mod
# ============================================================

MODDIR="${1:-$(pwd)}"
cd "$MODDIR" 2>/dev/null || { echo "❌ Cannot cd to $MODDIR"; exit 1; }

PASS=0; FAIL=0; WARN=0
TMP_ERR="${TMPDIR:-$PWD}/.goerr.$$"

ok()     { printf "  ✅ %s\n" "$1"; PASS=$((PASS+1)); }
err()    { printf "  ❌ %s\n" "$1"; FAIL=$((FAIL+1)); }
warn()   { printf "  ⚠️  %s\n" "$1"; WARN=$((WARN+1)); }
info()   { printf "  ℹ️  %s\n" "$1"; }
banner() { printf "\n═══ %s ═══\n" "$1"; }

# ============================================================
# 1. File existence
# ============================================================
banner "1. Required files"

for f in module.prop VERSION update.json Makefile proxy/main.go proxy/go.mod \
         functions.sh service.sh watchdog.sh status.sh \
         lib/process.sh web/index.html web/dashboard.html web/sw.js; do
    if [ -f "$f" ]; then
        ok "$f ($(wc -c < "$f" | tr -d ' ') bytes)"
    else
        err "$f MISSING"
    fi
done

# ============================================================
# 2. Version consistency
# ============================================================
banner "2. Version consistency (must all say v1.6.0)"

_prop_ver=$(grep '^version=' module.prop 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r ')
[ "$_prop_ver" = "v1.6.0" ] && ok "module.prop version=$_prop_ver" \
                             || err "module.prop version=$_prop_ver (expected v1.6.0)"

_prop_code=$(grep '^versionCode=' module.prop 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r ')
[ "$_prop_code" = "1060000" ] && ok "module.prop versionCode=$_prop_code" \
                              || err "module.prop versionCode=$_prop_code (expected 1060000)"

_ver=$(cat VERSION 2>/dev/null | tr -d '\r\n ')
[ "$_ver" = "v1.6.0" ] && ok "VERSION=$_ver" \
                       || err "VERSION=$_ver (expected v1.6.0)"

if command -v jq >/dev/null 2>&1; then
    _uj_ver=$(jq -r '.version // "null"' update.json 2>/dev/null)
    [ "$_uj_ver" = "v1.6.0" ] && ok "update.json .version=$_uj_ver" \
                              || err "update.json .version=$_uj_ver"
    _uj_code=$(jq -r '.versionCode // "null"' update.json 2>/dev/null)
    [ "$_uj_code" = "1060000" ] && ok "update.json .versionCode=$_uj_code" \
                                || err "update.json .versionCode=$_uj_code"
else
    warn "jq not installed — skipping update.json"
fi

if grep -q "CACHE_VERSION.*v1\.6\.0'" web/sw.js 2>/dev/null; then
    _cache=$(grep -oE "CACHE_VERSION = '[^']*'" web/sw.js | head -1)
    err "web/sw.js uses OLD cache: $_cache"
else
    _cache=$(grep -oE "CACHE_VERSION = '[^']*'" web/sw.js 2>/dev/null | head -1)
    [ -n "$_cache" ] && ok "web/sw.js cache bumped: $_cache"
fi

# ============================================================
# 3. Code modifications
# ============================================================
banner "3. Code modifications"

if grep -q "command -v pgrep" lib/process.sh 2>/dev/null; then
    err "lib/process.sh still references pgrep"
else
    ok "lib/process.sh: pgrep removed"
fi

if grep -q "for pid_dir in /proc/\[0-9\]\*" lib/process.sh 2>/dev/null; then
    ok "lib/process.sh: /proc scan present"
else
    err "lib/process.sh: /proc scan MISSING"
fi

grep -q "^get_user_intent()" functions.sh 2>/dev/null \
    && ok "functions.sh: get_user_intent() defined" \
    || err "functions.sh: get_user_intent() MISSING"

grep -q "fast-path" functions.sh 2>/dev/null \
    && ok "functions.sh: Fast-Path present" \
    || err "functions.sh: Fast-Path MISSING"

grep -q "Migrated legacy STATUS_FILE" functions.sh 2>/dev/null \
    && ok "functions.sh: Migration logging present" \
    || warn "functions.sh: Migration log not found"

grep -q 'get_user_intent' service.sh 2>/dev/null \
    && ok "service.sh: uses get_user_intent" \
    || err "service.sh: not updated"

grep -q 'restart_initiated' service.sh 2>/dev/null \
    && ok "service.sh: handles 202" \
    || err "service.sh: missing 202"

grep -q 'get_user_intent' watchdog.sh 2>/dev/null \
    && ok "watchdog.sh: uses get_user_intent" \
    || err "watchdog.sh: not updated"

grep -q 'restart_initiated' watchdog.sh 2>/dev/null \
    && ok "watchdog.sh: handles 202" \
    || err "watchdog.sh: missing 202"

grep -q 'grace 10s\|sleep 10' watchdog.sh 2>/dev/null \
    && ok "watchdog.sh: grace period present" \
    || warn "watchdog.sh: grace period not detected"

# --- main.go (in proxy/) ---
grep -q "func migrateStatusFile" proxy/main.go 2>/dev/null \
    && ok "proxy/main.go: migrateStatusFile() defined" \
    || err "proxy/main.go: migrateStatusFile() MISSING"

grep -q "func isDnsEngineAlive" proxy/main.go 2>/dev/null \
    && ok "proxy/main.go: isDnsEngineAlive() defined" \
    || err "proxy/main.go: isDnsEngineAlive() MISSING"

grep -q "StatusAccepted" proxy/main.go 2>/dev/null \
    && ok "proxy/main.go: HTTP 202 Accepted present" \
    || err "proxy/main.go: StatusAccepted MISSING"

grep -q "restart_initiated" proxy/main.go 2>/dev/null \
    && ok "proxy/main.go: restart_initiated present" \
    || err "proxy/main.go: restart_initiated MISSING"

if grep -A8 "func isProcessRunning" proxy/main.go 2>/dev/null | grep -q "pgrep"; then
    err "proxy/main.go: isProcessRunning uses pgrep"
else
    ok "proxy/main.go: isProcessRunning clean"
fi

grep -q 'STATUS_FROM_FILE=$(get_user_intent)' status.sh 2>/dev/null \
    && ok "status.sh: uses get_user_intent" \
    || err "status.sh: not updated"

grep -q 'user_intent' status.sh 2>/dev/null \
    && ok "status.sh: JSON key user_intent present" \
    || warn "status.sh: user_intent key not in JSON"

# ============================================================
# 4. Shell syntax
# ============================================================
banner "4. Shell syntax (sh -n)"

for f in functions.sh service.sh watchdog.sh status.sh boot-mini.sh \
         action.sh customize.sh uninstall.sh install_app.sh post-fs-data.sh \
         lib/process.sh lib/http.sh lib/firewall.sh lib/backup.sh \
         lib/constants.sh lib/fallbacks.sh; do
    [ -f "$f" ] || continue
    if sh -n "$f" 2>/dev/null; then
        ok "$f (syntax OK)"
    else
        err "$f (SYNTAX ERROR)"
        sh -n "$f" 2>&1 | head -3 | sed 's/^/      /'
    fi
done

# ============================================================
# 5. Go compilation (in proxy/)
# ============================================================
banner "5. Go compilation (proxy/)"

if command -v go >/dev/null 2>&1; then
    _goversion=$(go version 2>/dev/null | awk '{print $3}')
    info "go version: $_goversion"

    if [ ! -d "proxy" ]; then
        err "proxy/ directory not found"
    else
        info "go vet proxy/main.go..."
        if (cd proxy && go vet ./... 2>"$TMP_ERR"); then
            ok "go vet: clean"
        else
            warn "go vet warnings (non-fatal):"
            head -5 "$TMP_ERR" | sed 's/^/      /'
        fi
        rm -f "$TMP_ERR"

        info "go build (syntax check only)..."
        if (cd proxy && go build -o /dev/null . 2>"$TMP_ERR"); then
            ok "go build: succeeds"
        else
            err "go build FAILED:"
            head -20 "$TMP_ERR" | sed 's/^/      /'
        fi
        rm -f "$TMP_ERR"
    fi
else
    warn "go not installed — cannot verify proxy/main.go"
fi

# ============================================================
# 6. Project tooling
# ============================================================
banner "6. Project tooling"

if [ -f "Makefile" ]; then
    ok "Makefile present"
else
    warn "Makefile not found"
fi

if [ -f ".pre-commit-config.yaml" ]; then
    ok ".pre-commit-config.yaml present"
fi

if command -v shellcheck >/dev/null 2>&1 && [ -f ".shellcheckrc" ]; then
    ok "shellcheck + .shellcheckrc available"
fi

# ============================================================
# 7. Integration test
# ============================================================
banner "7. Integration (load functions.sh)"

if [ -f "functions.sh" ]; then
    _test_out=$(
        export MODDIR
        sh -c '
            . "$MODDIR/functions.sh" 2>/dev/null
            if command -v get_user_intent >/dev/null 2>&1; then
                _r=$(get_user_intent 2>/dev/null)
                case "$_r" in
                    ON|OFF) echo "OK:$_r" ;;
                    *)      echo "BAD:$_r" ;;
                esac
            else
                echo "MISSING_FN"
            fi
        ' 2>&1
    )
    case "$_test_out" in
        OK:ON)      ok "functions.sh → get_user_intent()=ON" ;;
        OK:OFF)     ok "functions.sh → get_user_intent()=OFF" ;;
        BAD:*)      err "functions.sh returns: $_test_out" ;;
        MISSING_FN) err "functions.sh: get_user_intent missing" ;;
        *)
            err "functions.sh FAILED to load:"
            printf '%s\n' "$_test_out" | head -5 | sed 's/^/      /'
            ;;
    esac
else
    err "functions.sh not found"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "═══════════════════════════════════════════════"
printf "  Results: %d passed, %d failed, %d warnings\n" "$PASS" "$FAIL" "$WARN"
echo "═══════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    echo "  ❌ BLOCKING ISSUES — do NOT push yet"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo "  ⚠️  Warnings present — review before pushing"
    exit 0
else
    echo "  ✅ ALL CHECKS PASSED — ready to deploy"
    exit 0
fi
