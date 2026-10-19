#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter — release.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-18
# ============================================================
# Automates a local release: bump version files, create an
# ANNOTATED tag, push to origin. GitHub Actions
# (.github/workflows/release.yml) publishes the release.
#
# For PATCH-only releases (hotfixes), use release-patch.sh.
#
# Usage:
#   ./scripts/release.sh v1.5.0 [options]
#
# Options:
#   --dry-run       Show changes without applying
#   --no-push       Create commit + tag locally, skip push
#   --skip-xnote    Skip the x-note-v<XYZ> presence check
#   --yes, -y       Skip interactive confirmation
#   --help, -h      Show this help
#
# Requirements: git 2.30+, sed, awk, jq (recommended).
#
# Exit codes:
#   0 = success
#   1 = invalid arguments or environment
#   2 = repository state invalid
#   3 = version metadata mismatch
#   4 = user aborted
#
# versionCode = MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100
#   v1.5.0 → 1050000 · v1.5.1 → 1050100 · v1.6.0 → 1060000
#   Constraints: PATCH ≤ 99, MINOR ≤ 99
# ============================================================

set -euo pipefail

# ────────────────────────────────────────────────────────────
# [1] Paths
# ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

# ────────────────────────────────────────────────────────────
# [2] Colors (conditional on TTY and NO_COLOR)
# ────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

# ────────────────────────────────────────────────────────────
# [3] Logging
# ────────────────────────────────────────────────────────────
log_info()  { echo -e "  ${CYAN}→${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }
log_step()  { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }

# ────────────────────────────────────────────────────────────
# [4] Helpers
# ────────────────────────────────────────────────────────────
# prompt_confirm — 0 on y/Y, 1 otherwise (incl. EOF).
prompt_confirm() {
    local _reply=""
    read -rp "$1" -n 1 _reply || _reply=""
    read -r _ || true
    echo ""
    case "$_reply" in
        [Yy]) return 0 ;;
        *)    return 1 ;;
    esac
}

# calc_version_code — MAJOR*1M + MINOR*10K + PATCH*100.
# Leading zeros stripped. Prerelease + build suffixes stripped
# defensively (the caller's regex already rejects them).
calc_version_code() {
    local _core="${1#v}"
    _core="${_core%%-*}"
    _core="${_core%%+*}"
    local _major _minor _patch
    _major=$(echo "$_core" | cut -d. -f1 | sed 's/^0*//')
    _minor=$(echo "$_core" | cut -d. -f2 | sed 's/^0*//')
    _patch=$(echo "$_core" | cut -d. -f3 | sed 's/^0*//')
    [ -z "$_major" ] && _major=0
    [ -z "$_minor" ] && _minor=0
    [ -z "$_patch" ] && _patch=0
    echo $((_major * 1000000 + _minor * 10000 + _patch * 100))
}

# ────────────────────────────────────────────────────────────
# [5] Arguments
# ────────────────────────────────────────────────────────────
VERSION=""
DRY_RUN=0
NO_PUSH=0
SKIP_CONFIRM=0
SKIP_XNOTE=0

show_help() {
    cat << 'EOF'
DNSCrypt Smart Filter – release.sh

Usage:
  release.sh <version> [options]

Arguments:
  <version>          Semantic version (e.g. v1.5.0, v1.5.0-beta1)

Options:
  --dry-run          Show what would happen, change nothing
  --no-push          Create commit + tag locally, do not push
  --skip-xnote       Skip the x-note-v<XYZ> presence check
  --yes, -y          Skip interactive confirmation
  --help, -h         Show this help

Examples:
  ./scripts/release.sh v1.5.0
  ./scripts/release.sh v1.5.0 --dry-run
  ./scripts/release.sh v1.5.0 --yes

Manual step — x-note-v<XYZ>:
  The per-release field "x-note-v<XYZ>" in update.json (e.g.
  "x-note-v150" for v1.5.0) contains hand-written release
  notes shown in the auto-update metadata of the root manager.
  It cannot be auto-generated.

  This script VERIFIES its presence and ABORTS if missing.
  Pass --skip-xnote to bypass the check (not recommended).

For PATCH-only releases (hotfixes), use release-patch.sh.
EOF
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)     DRY_RUN=1; shift ;;
        --no-push)     NO_PUSH=1; shift ;;
        --skip-xnote)  SKIP_XNOTE=1; shift ;;
        --yes|-y)      SKIP_CONFIRM=1; shift ;;
        --help|-h)     show_help ;;
        -*)
            log_error "Unknown option: $1"
            echo "Use --help for assistance" >&2
            exit 1
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION="$1"
            else
                log_error "Multiple versions provided: '$VERSION' and '$1'"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    log_error "Version is required"
    echo "Usage: $0 <version> [options]" >&2
    echo "Example: $0 v1.5.0" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# [6] Header
# ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  DNSCrypt Smart Filter – Release Automation      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Target version:${NC} ${GREEN}${VERSION}${NC}"
[ "$DRY_RUN" = "1" ] && echo -e "  ${BOLD}Mode:${NC}           ${YELLOW}DRY-RUN${NC}"
[ "$NO_PUSH" = "1" ] && echo -e "  ${BOLD}Push:${NC}           ${YELLOW}DISABLED${NC}"
[ "$SKIP_XNOTE" = "1" ] && echo -e "  ${BOLD}x-note check:${NC}   ${YELLOW}SKIPPED${NC}"
echo ""

# ────────────────────────────────────────────────────────────
# [7] Environment check
# ────────────────────────────────────────────────────────────
log_step "[1/9] Checking environment"

for tool in git sed awk; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "Required tool not found: $tool"
        exit 1
    fi
done
log_ok "Required tools: git, sed, awk"

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=1
    log_ok "jq available (update.json will be updated)"
else
    log_warn "jq NOT found — update.json will NOT be updated automatically"
    log_warn "  End users will NOT see the update through the Magisk/"
    log_warn "  KernelSU auto-update channel until update.json is"
    log_warn "  regenerated on a jq-equipped environment."
    log_warn "  The x-note-v<XYZ> check will also be skipped."
    log_info "Install jq: apt install jq / brew install jq / pkg install jq"
fi

# ────────────────────────────────────────────────────────────
# [8] Version format validation
# ────────────────────────────────────────────────────────────
log_step "[2/9] Validating version format"

if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$'; then
    log_error "Invalid version: '$VERSION'"
    log_info "Required: v<MAJOR>.<MINOR>.<PATCH>[-prerelease]"
    log_info "Examples: v1.5.0, v1.5.0-beta1, v2.0.0-rc1"
    exit 1
fi
log_ok "Version format valid: $VERSION"

# ────────────────────────────────────────────────────────────
# [9] Compute versionCode
# ────────────────────────────────────────────────────────────
log_step "[3/9] Computing versionCode"

VERSION_NO_V="${VERSION#v}"
VERSION_CORE="${VERSION_NO_V%%-*}"
MAJOR=$(echo "$VERSION_CORE" | cut -d. -f1)
MINOR=$(echo "$VERSION_CORE" | cut -d. -f2)
PATCH=$(echo "$VERSION_CORE" | cut -d. -f3)

if ! echo "$MAJOR" | grep -qE '^[0-9]+$' \
   || ! echo "$MINOR" | grep -qE '^[0-9]+$' \
   || ! echo "$PATCH" | grep -qE '^[0-9]+$'; then
    log_error "Failed to parse version numbers from: $VERSION"
    exit 1
fi

if [ "$PATCH" -gt 99 ]; then
    log_error "PATCH must be <= 99 (found: $PATCH)"
    log_info "versionCode formula reserves 2 digits for PATCH"
    exit 1
fi

if [ "$MINOR" -gt 99 ]; then
    log_error "MINOR must be <= 99 (found: $MINOR)"
    log_info "versionCode formula reserves 2 digits for MINOR"
    exit 1
fi

VERSION_CODE=$(calc_version_code "$VERSION")
log_ok "versionCode = $VERSION_CODE (from $VERSION_CORE)"

# x-note key format: v1.5.0 → x-note-v150
XNOTE_KEY="x-note-v${VERSION_CORE//./}"
log_info "Required x-note key: ${XNOTE_KEY}"

# ────────────────────────────────────────────────────────────
# [10] Git repository state
# ────────────────────────────────────────────────────────────
log_step "[4/9] Checking Git repository state"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not a Git repository"
    exit 2
fi
log_ok "Git repository detected"

CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    log_error "Detached HEAD — checkout a branch first"
    exit 2
fi

case "$CURRENT_BRANCH" in
    develop|main)
        log_ok "On branch: $CURRENT_BRANCH"
        ;;
    release/*)
        log_ok "On release branch: $CURRENT_BRANCH"
        ;;
    *)
        log_error "Releases must be created from 'develop', 'main', or 'release/*'"
        log_info "Current branch: $CURRENT_BRANCH"
        log_info "Switch with: git checkout develop"
        exit 2
        ;;
esac

if [ -n "$(git status --porcelain)" ]; then
    log_error "Working tree is not clean"
    log_info "Uncommitted changes:"
    git status --short
    log_info "Commit or stash them first"
    exit 2
fi
log_ok "Working tree is clean"

if git rev-parse -q --verify "refs/tags/${VERSION}" >/dev/null 2>&1; then
    log_error "Tag ${VERSION} already exists"
    log_info "Delete it first: git tag -d ${VERSION} && git push origin :refs/tags/${VERSION}"
    exit 2
fi
log_ok "Tag ${VERSION} is available"

MISSING_FILES=""
[ ! -f "VERSION" ]       && MISSING_FILES="$MISSING_FILES VERSION"
[ ! -f "module.prop" ]   && MISSING_FILES="$MISSING_FILES module.prop"
[ ! -f "update.json" ]   && MISSING_FILES="$MISSING_FILES update.json"
[ ! -f "CHANGELOG.md" ]  && MISSING_FILES="$MISSING_FILES CHANGELOG.md"

if [ -n "$MISSING_FILES" ]; then
    log_error "Missing required files:$MISSING_FILES"
    exit 2
fi
log_ok "Required files present: VERSION, module.prop, update.json, CHANGELOG.md"

# --- CHANGELOG check ---
CHANGELOG_VER_ESCAPED=$(printf '%s' "${VERSION#v}" | sed 's/\./\\./g')
if ! grep -qE "^## \[v?${CHANGELOG_VER_ESCAPED}\]|^## \[Unreleased\]" CHANGELOG.md; then
    log_warn "CHANGELOG.md does not contain a section for [${VERSION#v}] or [Unreleased]"
    log_info "Consider adding it before releasing"
    if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
        prompt_confirm "  Continue anyway? (y/N) " || { log_warn "Aborted by user"; exit 4; }
    fi
else
    log_ok "CHANGELOG.md contains a relevant section"
fi

# --- x-note-v<XYZ> check (HARD REQUIREMENT) ---
if [ "$SKIP_XNOTE" = "1" ]; then
    log_warn "x-note check skipped (--skip-xnote)"
    log_warn "  update.json may not contain a fresh ${XNOTE_KEY} entry."
    log_warn "  End users may see a stale release note in their update UI."
elif [ "$HAS_JQ" = "1" ]; then
    if jq -e --arg k "$XNOTE_KEY" '.[$k]' update.json >/dev/null 2>&1; then
        log_ok "update.json contains ${XNOTE_KEY}"
    else
        echo ""
        log_error "update.json is missing the required '${XNOTE_KEY}' field."
        echo ""
        log_info "Expected format (single-line string):"
        echo -e "    ${DIM}\"${XNOTE_KEY}\": \"v${VERSION_NO_V} — <short release note>\",${NC}"
        echo ""
        log_info "See an existing entry (e.g. 'x-note-v140') in update.json"
        log_info "for the expected structure."
        echo ""
        log_info "To bypass this check (NOT recommended):"
        echo -e "    ${DIM}$0 ${VERSION} --skip-xnote${NC}"
        echo ""
        exit 3
    fi
fi

# ────────────────────────────────────────────────────────────
# [11] Read current version + regression check
# ────────────────────────────────────────────────────────────
log_step "[5/9] Reading current version"

CURRENT_VERSION=$(tr -d '\r\n' < VERSION 2>/dev/null || true)
[ -z "$CURRENT_VERSION" ] && CURRENT_VERSION="unknown"

CURRENT_VC=$(grep '^versionCode=' module.prop 2>/dev/null \
             | head -n1 \
             | cut -d= -f2- \
             | tr -d '\r' || true)
[ -z "$CURRENT_VC" ] && CURRENT_VC="unknown"

log_info "Current VERSION:     ${CURRENT_VERSION}"
log_info "Current versionCode: ${CURRENT_VC}"
echo ""
log_info "New VERSION:         ${VERSION}"
log_info "New versionCode:     ${VERSION_CODE}$([ "$DRY_RUN" = "1" ] && echo " (dry-run: not applied)")"

# --- Equality check ---
if [ "$CURRENT_VERSION" = "$VERSION" ]; then
    log_warn "Current version is already ${VERSION}"
    if [ "$DRY_RUN" != "1" ]; then
        log_error "Nothing to do — VERSION, module.prop, and update.json"
        log_error "are already at ${VERSION}."
        exit 3
    fi
    log_info "Dry-run: continuing despite version equality"
fi

# --- Regression check ---
if [ "$CURRENT_VC" != "unknown" ] && echo "$CURRENT_VC" | grep -qE '^[0-9]+$'; then
    if [ "$VERSION_CODE" -lt "$CURRENT_VC" ]; then
        log_error "Version regression detected"
        log_info "  current versionCode: $CURRENT_VC"
        log_info "  new versionCode:     $VERSION_CODE"
        log_info "New versionCode must be strictly greater than current."
        log_info "Check VERSION and module.prop — the target may already be released."
        exit 3
    fi
    if [ "$VERSION_CODE" -gt "$CURRENT_VC" ]; then
        log_ok "versionCode progression valid ($CURRENT_VC → $VERSION_CODE)"
    fi
fi

# ────────────────────────────────────────────────────────────
# [12] Confirmation
# ────────────────────────────────────────────────────────────
# Manual fields NOT touched here (updated separately by hand
# before tagging, or covered by `make check-all`):
#   • web/manifest.json  → version (strip 'v')
#   • web/sw.js          → CACHE_VERSION (invalidates PWA cache)
#   • web/index.html     → var VERSION
#   • web/dashboard.html → var VERSION + <title>
if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
    echo ""
    log_warn "This will:"
    echo "    1. Update VERSION       → ${VERSION}"
    echo "    2. Update module.prop   → version=${VERSION}, versionCode=${VERSION_CODE}"
    echo "    3. Update update.json   → 6 fields:"
    echo "         • version             = ${VERSION}"
    echo "         • versionCode         = ${VERSION_CODE}"
    echo "         • versionName         = ${VERSION} (Global Edition)"
    echo "         • releaseDate         = $(date -u +%Y-%m-%d)"
    echo "         • zipUrl              = <new tag URL>"
    echo "         • x-note-last-updated = $(date -u +%Y-%m-%d)"
    echo "    4. Create commit        → release: ${VERSION}"
    echo "    5. Create annotated tag → ${VERSION}"
    if [ "$NO_PUSH" = "1" ]; then
        echo "    6. (Skip push — --no-push)"
    else
        echo "    6. Push to origin       → ${CURRENT_BRANCH} + tag"
        echo ""
        log_info "GitHub Actions will then publish the release automatically."
    fi
    echo ""
    echo -e "  ${DIM}Manual fields NOT touched by this script (update before tagging):${NC}"
    echo -e "    ${DIM}• web/manifest.json  → version  (strip 'v' prefix — PWA spec)${NC}"
    echo -e "    ${DIM}• web/sw.js          → CACHE_VERSION  (invalidates PWA cache)${NC}"
    echo -e "    ${DIM}• web/index.html     → var VERSION${NC}"
    echo -e "    ${DIM}• web/dashboard.html → var VERSION + <title>${NC}"
    echo -e "    ${DIM}• proxy/app-apk.version        (only if companion app changed)${NC}"
    echo -e "    ${DIM}• proxy/dnscrypt-proxy.version (only if DNS engine changed)${NC}"
    echo ""
    prompt_confirm "  Proceed? (y/N) " || { log_warn "Aborted by user"; exit 4; }
fi

# ────────────────────────────────────────────────────────────
# [13] Backup + rollback (BUG-9, BUG-10)
# ────────────────────────────────────────────────────────────
# Captures originals so rollback() can restore on failure.
# TMP_FILES tracks mktemp artifacts to clean up.
#
# `git checkout HEAD --` (not `git checkout --`): restores from
# the HEAD commit, not the index. After a partial `git add`, the
# index contains the NEW values — restoring from it would leave
# the working tree in the opposite state.
#
# BUG-10: `printf '%s\n'` — `$(cat VERSION)` strips trailing
# newlines; writing without `\n` produces a file that
# `grep '^versionCode='` may not match at end-of-line.
# BUG-9: callers in [17] must invoke `rollback` explicitly
# before `exit 3` — `exit` bypasses the ERR trap.
log_step "[6/9] Updating version files"

ORIG_VERSION=""
ORIG_MODULE_PROP=""
ORIG_UPDATE_JSON=""

TMP_FILES=""

if [ "$DRY_RUN" = "0" ]; then
    ORIG_VERSION=$(cat VERSION 2>/dev/null || true)
    ORIG_MODULE_PROP=$(cat module.prop 2>/dev/null || true)
    ORIG_UPDATE_JSON=$(cat update.json 2>/dev/null || true)

    # shellcheck disable=SC2329
    rollback() {
        log_warn "Rolling back changes..."
        [ -n "$ORIG_VERSION" ]     && printf '%s\n' "$ORIG_VERSION"     > VERSION
        [ -n "$ORIG_MODULE_PROP" ] && printf '%s\n' "$ORIG_MODULE_PROP" > module.prop
        [ -n "$ORIG_UPDATE_JSON" ] && printf '%s\n' "$ORIG_UPDATE_JSON" > update.json
        git checkout HEAD -- VERSION module.prop update.json 2>/dev/null || true
        for _tf in $TMP_FILES; do
            [ -f "$_tf" ] && rm -f "$_tf"
        done
        log_info "Rollback complete"
    }
    trap 'rollback' ERR
fi

# ────────────────────────────────────────────────────────────
# [14] Update VERSION
# ────────────────────────────────────────────────────────────
if [ "$DRY_RUN" = "0" ]; then
    printf '%s\n' "$VERSION" > VERSION
    log_ok "VERSION → ${VERSION}"
else
    log_info "[dry-run] Would update VERSION → ${VERSION}"
fi

# ────────────────────────────────────────────────────────────
# [15] Update module.prop
# ────────────────────────────────────────────────────────────
if [ "$DRY_RUN" = "0" ]; then
    tmp_prop="$(mktemp "${TMPDIR:-/tmp}/module.prop.XXXXXX")"
    TMP_FILES="$TMP_FILES $tmp_prop"
    sed -e "s|^version=.*|version=${VERSION}|" \
        -e "s|^versionCode=.*|versionCode=${VERSION_CODE}|" \
        module.prop > "$tmp_prop"
    mv -f "$tmp_prop" module.prop
    TMP_FILES="${TMP_FILES// $tmp_prop/}"
    log_ok "module.prop → version=${VERSION}, versionCode=${VERSION_CODE}"
else
    log_info "[dry-run] Would update module.prop"
fi

# ────────────────────────────────────────────────────────────
# [16] Update update.json (requires jq) — BUG-13, BUG-14
# ────────────────────────────────────────────────────────────
# The 4 web files below are NOT touched by this script. They
# must be updated BEFORE running it (see [12] Confirmation).
# `sw.js CACHE_VERSION` is the critical one — without it, the
# PWA cache is never invalidated and users keep stale assets
# after the release.
NEW_ZIP_URL="https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/${VERSION}/dnscrypt-webui-${VERSION#v}-module.zip"
NEW_VERSION_NAME="${VERSION} (Global Edition)"
NEW_RELEASE_DATE="$(date -u +%Y-%m-%d)"

if [ "$HAS_JQ" = "1" ]; then
    if [ "$DRY_RUN" = "0" ]; then
        tmp_json="$(mktemp "${TMPDIR:-/tmp}/update.json.XXXXXX")"
        TMP_FILES="$TMP_FILES $tmp_json"
        jq --arg v "$VERSION" \
           --argjson vc "$VERSION_CODE" \
           --arg url "$NEW_ZIP_URL" \
           --arg vn "$NEW_VERSION_NAME" \
           --arg rd "$NEW_RELEASE_DATE" \
           '.version = $v
          | .versionCode = $vc
          | .versionName = $vn
          | .releaseDate = $rd
          | .zipUrl = $url
          | .["x-note-last-updated"] = $rd' \
           update.json > "$tmp_json" && mv -f "$tmp_json" update.json
        TMP_FILES="${TMP_FILES// $tmp_json/}"
        log_ok "update.json → version=${VERSION}"
        log_ok "update.json → versionCode=${VERSION_CODE}"
        log_ok "update.json → versionName=${NEW_VERSION_NAME}"
        log_ok "update.json → releaseDate=${NEW_RELEASE_DATE}"
        log_ok "update.json → zipUrl=${NEW_ZIP_URL}"
        log_ok "update.json → x-note-last-updated=${NEW_RELEASE_DATE}"

        echo ""
        log_info "Fields NOT touched by this script (verify before tagging):"
        log_info "  • ${XNOTE_KEY}         (verified in [10] — present)"
        log_info "  • web/manifest.json    → version  (strip 'v' prefix)"
        log_info "  • web/sw.js            → CACHE_VERSION  (critical for PWA)"
        log_info "  • web/index.html       → var VERSION"
        log_info "  • web/dashboard.html   → var VERSION + <title>"
        log_info "  • proxy/app-apk.version        (only if companion app changed)"
        log_info "  • proxy/dnscrypt-proxy.version (only if DNS engine changed)"
    else
        log_info "[dry-run] Would update update.json (6 fields):"
        log_info "[dry-run]   version=${VERSION}"
        log_info "[dry-run]   versionCode=${VERSION_CODE}"
        log_info "[dry-run]   versionName=${NEW_VERSION_NAME}"
        log_info "[dry-run]   releaseDate=${NEW_RELEASE_DATE}"
        log_info "[dry-run]   zipUrl=${NEW_ZIP_URL}"
        log_info "[dry-run]   x-note-last-updated=${NEW_RELEASE_DATE}"
    fi
else
    log_warn "Skipping update.json (jq not available)"
    log_warn "  Fields left stale: version, versionCode, versionName,"
    log_warn "  releaseDate, zipUrl, x-note-last-updated"
    log_info "Install jq and re-run: apt install jq / brew install jq / pkg install jq"
fi

# ────────────────────────────────────────────────────────────
# [17] Verify changes (BUG-9)
# ────────────────────────────────────────────────────────────
# Every `exit 3` here MUST be preceded by `rollback` — `exit`
# bypasses the ERR trap. Without this, a silent update.json
# write failure leaves VERSION + module.prop at the new value
# while update.json stays old → inconsistent release state.
log_step "[7/9] Verifying changes"

if [ "$DRY_RUN" = "0" ]; then
    NEW_VERSION_FILE=$(tr -d '\r\n' < VERSION)
    NEW_PROP_VER=$(grep '^version=' module.prop | head -n1 | cut -d= -f2-)
    NEW_PROP_VC=$(grep '^versionCode=' module.prop | head -n1 | cut -d= -f2-)

    if [ -z "$NEW_PROP_VER" ]; then
        log_error "module.prop has no 'version=' line after update"
        rollback; exit 3
    fi
    if [ -z "$NEW_PROP_VC" ]; then
        log_error "module.prop has no 'versionCode=' line after update"
        rollback; exit 3
    fi

    if [ "$NEW_VERSION_FILE" != "$VERSION" ]; then
        log_error "VERSION file mismatch: expected '$VERSION', got '$NEW_VERSION_FILE'"
        rollback; exit 3
    fi
    if [ "$NEW_PROP_VER" != "$VERSION" ]; then
        log_error "module.prop version mismatch: expected '$VERSION', got '$NEW_PROP_VER'"
        rollback; exit 3
    fi
    if [ "$NEW_PROP_VC" != "$VERSION_CODE" ]; then
        log_error "module.prop versionCode mismatch: expected '$VERSION_CODE', got '$NEW_PROP_VC'"
        rollback; exit 3
    fi
    log_ok "VERSION, module.prop verified"

    if [ "$HAS_JQ" = "1" ]; then
        JSON_VER=$(jq -r '.version // empty' update.json 2>/dev/null || echo "")
        JSON_VC=$(jq -r '.versionCode // empty' update.json 2>/dev/null || echo "")
        JSON_VN=$(jq -r '.versionName // empty' update.json 2>/dev/null || echo "")
        JSON_RD=$(jq -r '.releaseDate // empty' update.json 2>/dev/null || echo "")

        if [ "$JSON_VER" != "$VERSION" ]; then
            log_error "update.json version mismatch: expected '$VERSION', got '$JSON_VER'"
            rollback; exit 3
        fi
        if [ "$JSON_VC" != "$VERSION_CODE" ]; then
            log_error "update.json versionCode mismatch: expected '$VERSION_CODE', got '$JSON_VC'"
            rollback; exit 3
        fi
        if [ "$JSON_VN" != "$NEW_VERSION_NAME" ]; then
            log_error "update.json versionName mismatch: expected '$NEW_VERSION_NAME', got '$JSON_VN'"
            rollback; exit 3
        fi
        if [ "$JSON_RD" != "$NEW_RELEASE_DATE" ]; then
            log_error "update.json releaseDate mismatch: expected '$NEW_RELEASE_DATE', got '$JSON_RD'"
            rollback; exit 3
        fi
        log_ok "update.json verified (version, versionCode, versionName, releaseDate)"
    fi
else
    log_info "[dry-run] Skipping verification"
fi

# ────────────────────────────────────────────────────────────
# [18] Commit + tag
# ────────────────────────────────────────────────────────────
log_step "[8/9] Creating commit and tag"

COMMIT_MSG="release: ${VERSION}"

if [ "$DRY_RUN" = "0" ]; then
    git add VERSION module.prop
    if [ "$HAS_JQ" = "1" ]; then
        git add update.json
    fi

    if git diff --cached --quiet; then
        log_warn "No changes staged — nothing to commit"
    else
        git commit -m "$COMMIT_MSG"
        log_ok "Commit created: ${COMMIT_MSG}"

        # Disable ERR trap NOW: the commit has landed. A later
        # failure must NOT rewrite files back to ORIG_VERSION —
        # rollback after a successful commit would leave an
        # uncommitted revert of the committed changes.
        trap - ERR 2>/dev/null || true
    fi
else
    log_info "[dry-run] Would commit: ${COMMIT_MSG}"
fi

# Annotated tag (`git tag -a`), not signed (`git tag -s`).
TAG_MSG="Release ${VERSION}"

if [ "$DRY_RUN" = "0" ]; then
    if ! git tag -a "$VERSION" -m "$TAG_MSG"; then
        log_error "Failed to create annotated tag: ${VERSION}"
        log_info "The release commit exists locally but is untagged."
        log_info "To retry once the underlying issue is fixed:"
        log_info "  git tag -a ${VERSION} -m '${TAG_MSG}'"
        log_info "  git push origin ${CURRENT_BRANCH}"
        log_info "  git push origin ${VERSION}"
        exit 1
    fi
    log_ok "Annotated tag created: ${VERSION}"
else
    log_info "[dry-run] Would create annotated tag: ${VERSION}"
fi

# ────────────────────────────────────────────────────────────
# [19] Push
# ────────────────────────────────────────────────────────────
log_step "[9/9] Pushing to origin"

if [ "$NO_PUSH" = "1" ]; then
    log_warn "Push skipped (--no-push)"
    echo ""
    log_info "To push manually later:"
    echo "    git push origin ${CURRENT_BRANCH}"
    echo "    git push origin ${VERSION}"
elif [ "$DRY_RUN" = "0" ]; then
    if git push origin "$CURRENT_BRANCH"; then
        log_ok "Pushed branch: ${CURRENT_BRANCH}"
    else
        log_error "Failed to push branch ${CURRENT_BRANCH}"
        log_info "The commit and tag are still local — fix the issue and retry"
        log_info "  git push origin ${CURRENT_BRANCH}"
        log_info "  git push origin ${VERSION}"
        exit 1
    fi

    if git push origin "$VERSION"; then
        log_ok "Pushed tag: ${VERSION}"
    else
        log_error "Failed to push tag ${VERSION}"
        log_info "The branch is on origin, but the tag is still local."
        log_info "Retry with:"
        log_info "  git push origin ${VERSION}"
        log_info "Until the tag is pushed, release.yml will NOT fire."
        exit 1
    fi
else
    log_info "[dry-run] Would push: ${CURRENT_BRANCH}"
    log_info "[dry-run] Would push: ${VERSION}"
fi

# ────────────────────────────────────────────────────────────
# [20] Final summary (BUG-13, BUG-14)
# ────────────────────────────────────────────────────────────
trap - ERR 2>/dev/null || true

echo ""
if [ "$DRY_RUN" = "1" ]; then
    echo -e "${YELLOW}${BOLD}╔═════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║  DRY-RUN Complete — no changes were made        ║${NC}"
    echo -e "${YELLOW}${BOLD}╚═════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Run without ${CYAN}--dry-run${NC} to apply changes."
    if [ "$HAS_JQ" != "1" ]; then
        echo ""
        echo -e "  ${YELLOW}⚠${NC}  update.json will NOT be updated (jq unavailable)."
    fi
    if [ "$SKIP_XNOTE" = "1" ]; then
        echo ""
        echo -e "  ${YELLOW}⚠${NC}  x-note check was skipped (--skip-xnote)."
        echo -e "     ${DIM}The ${XNOTE_KEY} field is not verified.${NC}"
    fi
    echo ""
    exit 0
fi

echo -e "${GREEN}${BOLD}╔═════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║  Release prepared successfully                  ║${NC}"
echo -e "${GREEN}${BOLD}╚═════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Version:${NC}       ${GREEN}${VERSION}${NC}"
echo -e "  ${BOLD}versionCode:${NC}   ${GREEN}${VERSION_CODE}${NC}"
echo -e "  ${BOLD}Branch:${NC}        ${CYAN}${CURRENT_BRANCH}${NC}"
echo -e "  ${BOLD}Tag:${NC}           ${CYAN}${VERSION}${NC} (annotated)"

if [ "$HAS_JQ" != "1" ]; then
    echo ""
    echo -e "  ${YELLOW}⚠${NC}  update.json was NOT updated (jq unavailable)."
    echo -e "     ${DIM}Users who already installed the module will NOT${NC}"
    echo -e "     ${DIM}see the update until update.json is regenerated.${NC}"
    echo -e "     ${DIM}Fields left stale: version, versionCode,${NC}"
    echo -e "     ${DIM}versionName, releaseDate, zipUrl, x-note-last-updated.${NC}"
fi

if [ "$SKIP_XNOTE" = "1" ]; then
    echo ""
    echo -e "  ${YELLOW}⚠${NC}  x-note check was skipped (--skip-xnote)."
    echo -e "     ${DIM}The ${XNOTE_KEY} field was not verified.${NC}"
    echo -e "     ${DIM}End users may see a stale release note.${NC}"
fi

echo ""
echo -e "  ${BOLD}Fields NOT touched by this script:${NC}"
echo -e "    ${DIM}• ${XNOTE_KEY}         (verified in [10] — present)${NC}"
echo -e "    ${DIM}• web/manifest.json    → version  (strip 'v' prefix)${NC}"
echo -e "    ${DIM}• web/sw.js            → CACHE_VERSION  (critical for PWA)${NC}"
echo -e "    ${DIM}• web/index.html       → var VERSION${NC}"
echo -e "    ${DIM}• web/dashboard.html   → var VERSION + <title>${NC}"
echo -e "    ${DIM}• proxy/app-apk.version        (only if companion app changed)${NC}"
echo -e "    ${DIM}• proxy/dnscrypt-proxy.version (only if DNS engine changed)${NC}"

if [ "$NO_PUSH" = "0" ]; then
    echo ""
    echo -e "${BOLD}Next:${NC}"
    echo "  • GitHub Actions (.github/workflows/release.yml) is now running."
    echo "  • It will build 4 architectures, package the module, and"
    echo "    publish the release."
    echo "  • It also runs the sync main → develop step at the end of"
    echo "    the release. If that step fails (e.g. a merge conflict),"
    echo "    back-merge manually with:"
    echo "        make sync"
    echo ""
    echo -e "${DIM}  Monitor: https://github.com/gasciljh/dnscrypt-proxy-webui/actions${NC}"
else
    echo ""
    echo -e "${BOLD}Next (manual push):${NC}"
    echo "  git push origin ${CURRENT_BRANCH}"
    echo "  git push origin ${VERSION}"
fi
echo ""

exit 0