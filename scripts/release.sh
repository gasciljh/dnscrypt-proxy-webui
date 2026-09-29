#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – release.sh
# Version: v1.2.0 (Global Edition)
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Automate a new release locally: bump version files, create
#   an ANNOTATED tag, and push to origin. GitHub Actions
#   (.github/workflows/release.yml) handles the rest:
#     • Build 4 architectures
#     • Package the Magisk module ZIP
#     • Generate SHA-256 checksums
#     • Create the GitHub Release
#     • Sync main → develop (for regular releases only)
#
# Workflow (recommended):
#   1. Work on develop or a release/* branch
#   2. Ensure CHANGELOG.md has an [Unreleased] or [vX.Y.Z] section
#   3. Run: ./scripts/release.sh v1.3.0
#   4. GitHub Actions publishes the release automatically
#
# Usage:
#   ./scripts/release.sh v1.3.0
#   ./scripts/release.sh v1.3.0-beta1
#   ./scripts/release.sh v1.3.0 --dry-run
#   ./scripts/release.sh v1.3.0 --no-push
#   ./scripts/release.sh v1.3.0 --yes
#
# Options:
#   --dry-run       Show what would happen, change nothing
#   --no-push       Create commit + tag locally, do not push
#   --yes, -y       Skip interactive confirmation
#   --help, -h      Show this help
#
# Requirements:
#   • git    (2.30+)
#   • sed    (GNU or BSD)
#   • awk
#   • jq     (optional — required for update.json)
#
# Exit codes:
#   0 = success
#   1 = invalid arguments or environment
#   2 = repository state invalid
#   3 = version metadata mismatch (regression or verification failure)
#   4 = user aborted
#
# Relationship with release-patch.sh:
#   scripts/release-patch.sh is a thin wrapper around this
#   script. It adds 4 safety rules on top:
#     1. Current branch MUST be `main` (not `develop`).
#     2. MAJOR and MINOR components MUST NOT change.
#     3. PATCH MUST be exactly current + 1.
#     4. (Wrapper-only) A post-release back-merge is REQUIRED
#        because the auto-sync in release.yml does NOT run for
#        PATCH releases (see docs/BRANCHING.md §8).
#
#   release-patch.sh delegates the actual bump logic to this
#   script — the two are always in sync.
#
# versionCode formula:
#   versionCode = MAJOR × 1,000,000
#               + MINOR ×    10,000
#               + PATCH ×       100
#               + HOTFIX
#
#   In this script, HOTFIX is always 0.
#
#   Constraints:
#     • PATCH  must be ≤ 99
#     • MINOR  must be ≤ 99  (so it does not overflow into MAJOR)
#
#   Examples (canonical table — must match the code in [7]):
#     v1.0.0 → 1000000
#     v1.1.0 → 1010000
#     v1.2.0 → 1020000
#     v1.2.1 → 1020100   ← PATCH=1 → PATCH×100 = 100
#     v1.2.5 → 1020500
#     v1.3.0 → 1030000
#     v2.0.0 → 2000000
#
# ============================================================
# v1.2.0 — POST-AUDIT FIXES (still v1.2.0)
# ============================================================
#   🔧 P1 — versionCode example table corrected (v1.2.1 →
#     1020100, not 1020001).
#   🔧 BUG-R1 — update.json's zipUrl is now updated in the
#     same jq call, preventing a stale-zip window.
#   🔧 BUG-R2 — versionCode is printed in --dry-run mode too.
#   🔧 BUG-R3 — (folded into BUG-R1 during the audit cycle;
#     the original issue — a stale zipUrl window — is fully
#     addressed by BUG-R1's unified jq call.)
#   🔧 BUG-R4 — header says "annotated tag", not "signed tag".
#   🔧 R5 — auto-sync message qualified for PATCH vs stable.
#   🔧 R6 — ERR trap cleared after successful commit.
#   🔧 R7 — CHANGELOG regex accepts both `## [1.2.1]` and
#     `## [v1.2.1]` forms.
#   🔧 R8 — mktemp calls pass an explicit template.
#
# ============================================================
# v1.2.0 (Global Edition) — Additional hardening in this revision
# ============================================================
#   🛡️ HARD-REL-01 (was C-01) — The header no longer claims that
#     release.yml generates an SBOM. release.yml explicitly
#     declares SBOM generation as a non-goal; the release.sh
#     description now matches.
#
#   🛡️ HARD-REL-02 (was REL-1) — A version-regression check has
#     been added to section [9]. The script now refuses to
#     release a version whose versionCode is not strictly
#     greater than the current one in module.prop. Without this
#     check, an accidental `release.sh v1.0.0` while module.prop
#     says v1.2.0 would push a tag whose versionCode is smaller,
#     silently breaking Magisk update detection for all users.
#
#   🛡️ HARD-REL-03 (was REL-2) — The CHANGELOG regex now escapes
#     the dots in the version string. Previously, `## [1.2.0]`
#     matched any `## [1x2y0]` because `.` is a regex meta-
#     character.
#
#   🛡️ HARD-REL-04 (was REL-3) — Both `read -rp` calls now
#     tolerate EOF. Under `set -e`, a closed stdin previously
#     aborted the script with a bare exit 1 instead of a
#     clear user-facing message.
#
#   🛡️ HARD-REL-05 (was REL-4) — `mktemp` calls use
#     `${TMPDIR:-/tmp}/<template>` instead of the `-t` flag.
#     BSD `mktemp -t` appends its own X's rather than replacing
#     the ones in the template, producing paths like
#     `/tmp/module.prop.XXXXXX.abc123` — harmless on Linux,
#     non-portable on macOS.
#
#   🛡️ HARD-REL-06 (was REL-5) — Temporary files created by
#     `mktemp` are tracked in TMP_FILES and removed by the ERR
#     trap. Previously a `sed` or `jq` failure left an orphan
#     file under `$TMPDIR`.
#
#   🛡️ HARD-REL-07 (was REL-6) — The verification in [15] is
#     unchanged in behavior, but the `grep`/`head` pipelines
#     no longer rely on the outer `[ "$X" != "$Y" ]` to detect
#     a missing `version=` line. An explicit empty check gives
#     a clearer error message.
#
#   🛡️ HARD-REL-08 (was REL-7) — The header's fix list now
#     documents that BUG-R3 was folded into BUG-R1 during the
#     audit cycle (see the POST-AUDIT FIXES block above).
#
#   🛡️ HARD-REL-09 (was REL-8) — `REPLY` is reset after each
#     `read` to prevent accidental carry-over.
#
#   🛡️ HARD-REL-10 (was REL-9) — The box-drawing banner no
#     longer relies on emoji width; the top and bottom rules
#     use identical character counts.
#
# ============================================================
# v1.2.0 (Global Edition) — Revision 2 (M-2, M-3, L-1..L-5)
# ============================================================
#   🟡 M-2 — TMP_FILES cleanup now uses a single parameter
#     expansion (${TMP_FILES// $tmp/}) instead of a redundant
#     prefix-then-global pair. The `${TMP_FILES# $tmp}` line
#     was dead code — the global substitution that followed it
#     already covered the prefix case.
#
#   🟡 M-3 — `git tag -a` is now guarded. Previously the ERR
#     trap was cleared immediately after a successful commit,
#     so a tag-creation failure (rare: refs conflict, broken
#     ~/.gitconfig) would leave a commit with no tag and no
#     automatic recovery. The script now prints the exact retry
#     command and exits 1 with a clear message.
#
#   🟢 L-1 — `--yes, -y` is now documented in `--help`; the
#     case arm already accepted `-y`.
#
#   🟢 L-2 — NEW_ZIP_URL is computed once, before the dry-run
#     branch, instead of being duplicated in both arms.
#
#   🟢 L-3 — The `read -rp ... -n 1` prompts now consume the
#     rest of the line via a trailing `read -r _` so a future
#     prompt in the same script cannot inherit stray input.
#
#   🟢 L-4 — Exit code 3 is documented as "version metadata
#     mismatch" — it covers both the regression check in [9]
#     and the post-update verification failure in [15].
#
#   🟢 L-5 — The final summary now explicitly warns when
#     update.json was NOT updated because jq is unavailable.
#
# ============================================================

set -euo pipefail

# ============================================================
# [1] Path resolution
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$REPO_ROOT"

# ============================================================
# [2] Colors
# ============================================================
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

log_info()  { echo -e "  ${CYAN}→${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }
log_step()  { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }

# ============================================================
# [3] Arguments
# ============================================================
VERSION=""
DRY_RUN=0
NO_PUSH=0
SKIP_CONFIRM=0

show_help() {
    cat << 'EOF'
DNSCrypt Smart Filter – release.sh

Usage:
  release.sh <version> [options]

Arguments:
  <version>          Semantic version (e.g. v1.3.0, v1.3.0-beta1)

Options:
  --dry-run          Show what would happen, change nothing
  --no-push          Create commit + tag locally, do not push
  --yes, -y          Skip interactive confirmation
  --help, -h         Show this help

Examples:
  ./scripts/release.sh v1.3.0
  ./scripts/release.sh v1.3.0-beta1
  ./scripts/release.sh v1.3.0 --dry-run
  ./scripts/release.sh v1.3.0 --yes

Workflow:
  1. Work on develop or release/* branch
  2. Ensure CHANGELOG.md is updated
  3. Run release.sh
  4. GitHub Actions publishes the release automatically

For PATCH-only releases (hotfixes):
  Use ./scripts/release-patch.sh instead. See
  docs/BRANCHING.md §8.

References:
  docs/UPGRADE.md §3.1     v1.1.0 → v1.2.0 upgrade path
  docs/RELEASE_PROCESS.md  Full release process
EOF
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)     DRY_RUN=1; shift ;;
        --no-push)     NO_PUSH=1; shift ;;
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
    echo "Example: $0 v1.3.0" >&2
    exit 1
fi

# ============================================================
# [4] Header
# ============================================================
# HARD-REL-10: box-drawing rules use identical character counts.
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  DNSCrypt Smart Filter – Release Automation      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Target version:${NC} ${GREEN}${VERSION}${NC}"
[ "$DRY_RUN" = "1" ] && echo -e "  ${BOLD}Mode:${NC}           ${YELLOW}DRY-RUN${NC}"
[ "$NO_PUSH" = "1" ] && echo -e "  ${BOLD}Push:${NC}           ${YELLOW}DISABLED${NC}"
echo ""

# ============================================================
# [5] Environment checks
# ============================================================
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
    log_warn "jq not found — update.json will NOT be updated automatically"
    log_info "Install jq to enable automatic update.json updates"
fi

# ============================================================
# [6] Validate version format (SemVer)
# ============================================================
log_step "[2/9] Validating version format"

if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$'; then
    log_error "Invalid version: '$VERSION'"
    log_info "Required format: v<MAJOR>.<MINOR>.<PATCH>[-prerelease]"
    log_info "Examples: v1.3.0, v1.3.0-beta1, v2.0.0-rc1"
    exit 1
fi
log_ok "Version format valid: $VERSION"

# ============================================================
# [7] Compute versionCode
# ============================================================
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

# HARD-REL-02: bound MINOR so it does not overflow into MAJOR.
if [ "$MINOR" -gt 99 ]; then
    log_error "MINOR must be <= 99 (found: $MINOR)"
    log_info "versionCode formula reserves 2 digits for MINOR"
    exit 1
fi

VERSION_CODE=$((MAJOR * 1000000 + MINOR * 10000 + PATCH * 100))
log_ok "versionCode = $VERSION_CODE (from $VERSION_CORE)"

# ============================================================
# [8] Check Git repository
# ============================================================
log_step "[4/9] Checking Git repository state"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not a Git repository"
    exit 2
fi
log_ok "Git repository detected"

# --- Current branch ---
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

# --- Clean working tree ---
if [ -n "$(git status --porcelain)" ]; then
    log_error "Working tree is not clean"
    log_info "Uncommitted changes:"
    git status --short
    log_info "Commit or stash them first"
    exit 2
fi
log_ok "Working tree is clean"

# --- Tag does not already exist ---
if git rev-parse -q --verify "refs/tags/${VERSION}" >/dev/null 2>&1; then
    log_error "Tag ${VERSION} already exists"
    log_info "Delete it first: git tag -d ${VERSION} && git push origin :refs/tags/${VERSION}"
    exit 2
fi
log_ok "Tag ${VERSION} is available"

# --- Required files exist ---
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
# HARD-REL-03: escape regex meta-characters in the version
# string. Previously, `## [1.2.0]` matched `## [1x2y0]` because
# `.` matches any character in a regex.
CHANGELOG_VER_ESCAPED=$(printf '%s' "${VERSION#v}" | sed 's/\./\\./g')
if ! grep -qE "^## \[v?${CHANGELOG_VER_ESCAPED}\]|^## \[Unreleased\]" CHANGELOG.md; then
    log_warn "CHANGELOG.md does not contain a section for [${VERSION#v}] or [Unreleased]"
    log_info "Consider adding it before releasing"
    if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
        echo ""
        # HARD-REL-04: tolerate EOF on stdin.
        # L-3: drain the rest of the line so a later prompt
        # cannot inherit stray input.
        read -rp "  Continue anyway? (y/N) " -n 1 REPLY || REPLY=""
        read -r _ || true
        echo ""
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            log_warn "Aborted by user"
            exit 4
        fi
        REPLY=""
    fi
else
    log_ok "CHANGELOG.md contains a relevant section"
fi

# ============================================================
# [9] Read current version + HARD-REL-02 regression check
# ============================================================
log_step "[5/9] Reading current version"

CURRENT_VERSION=$(tr -d '\r\n' < VERSION 2>/dev/null || echo "unknown")
CURRENT_VC=$(grep '^versionCode=' module.prop 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r' || echo "unknown")

log_info "Current VERSION:     ${CURRENT_VERSION}"
log_info "Current versionCode: ${CURRENT_VC}"
echo ""
log_info "New VERSION:         ${VERSION}"
log_info "New versionCode:     ${VERSION_CODE}$([ "$DRY_RUN" = "1" ] && echo " (dry-run: not applied)")"

# HARD-REL-02: refuse to release a versionCode that is not
# strictly greater than the current one. Without this check,
# `release.sh v1.0.0` while module.prop says v1.2.0 would push
# a tag whose versionCode is smaller, silently breaking Magisk
# update detection for every installed user.
if [ "$CURRENT_VC" != "unknown" ] && echo "$CURRENT_VC" | grep -qE '^[0-9]+$'; then
    if [ "$VERSION_CODE" -le "$CURRENT_VC" ]; then
        log_error "Version regression detected"
        log_info "  current versionCode: $CURRENT_VC"
        log_info "  new versionCode:     $VERSION_CODE"
        log_info "New versionCode must be strictly greater than current."
        log_info "Check VERSION and module.prop — the target may already be released."
        exit 3
    fi
    log_ok "versionCode progression valid ($CURRENT_VC → $VERSION_CODE)"
fi

if [ "$CURRENT_VERSION" = "$VERSION" ]; then
    log_warn "Current version is already ${VERSION}"
    if [ "$DRY_RUN" != "1" ]; then
        log_error "Nothing to do"
        exit 3
    fi
fi

# ============================================================
# [10] Confirmation
# ============================================================
if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
    echo ""
    log_warn "This will:"
    echo "    1. Update VERSION       → ${VERSION}"
    echo "    2. Update module.prop   → version=${VERSION}, versionCode=${VERSION_CODE}"
    echo "    3. Update update.json   → version=${VERSION}, versionCode=${VERSION_CODE}, zipUrl=<new tag>"
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
    # HARD-REL-04: tolerate EOF on stdin.
    # L-3: drain the rest of the line.
    read -rp "  Proceed? (y/N) " -n 1 REPLY || REPLY=""
    read -r _ || true
    echo ""
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        log_warn "Aborted by user"
        exit 4
    fi
    REPLY=""
fi

# ============================================================
# [11] Backup current values (for rollback on failure)
# ============================================================
log_step "[6/9] Updating version files"

ORIG_VERSION=""
ORIG_MODULE_PROP=""
ORIG_UPDATE_JSON=""

# HARD-REL-06: track temp files so rollback can clean them.
TMP_FILES=""

if [ "$DRY_RUN" = "0" ]; then
    ORIG_VERSION=$(cat VERSION 2>/dev/null || true)
    ORIG_MODULE_PROP=$(cat module.prop 2>/dev/null || true)
    ORIG_UPDATE_JSON=$(cat update.json 2>/dev/null || true)

    rollback() {
        log_warn "Rolling back changes..."
        [ -n "$ORIG_VERSION" ] && printf '%s' "$ORIG_VERSION" > VERSION
        [ -n "$ORIG_MODULE_PROP" ] && printf '%s' "$ORIG_MODULE_PROP" > module.prop
        [ -n "$ORIG_UPDATE_JSON" ] && printf '%s' "$ORIG_UPDATE_JSON" > update.json
        git checkout -- VERSION module.prop update.json 2>/dev/null || true
        # HARD-REL-06: clean up any temp files left by mktemp.
        for _tf in $TMP_FILES; do
            [ -f "$_tf" ] && rm -f "$_tf"
        done
        log_info "Rollback complete"
    }
    trap 'rollback' ERR
fi

# ============================================================
# [12] Update VERSION (LF, single line)
# ============================================================
if [ "$DRY_RUN" = "0" ]; then
    printf '%s\n' "$VERSION" > VERSION
    log_ok "VERSION → ${VERSION}"
else
    log_info "[dry-run] Would update VERSION → ${VERSION}"
fi

# ============================================================
# [13] Update module.prop (version + versionCode)
# ============================================================
if [ "$DRY_RUN" = "0" ]; then
    # HARD-REL-05: full path with X's at the end — portable
    # across GNU coreutils, BSD, and MSYS. The `-t` flag is
    # NOT portable (BSD treats its argument as a prefix).
    tmp_prop="$(mktemp "${TMPDIR:-/tmp}/module.prop.XXXXXX")"
    TMP_FILES="$TMP_FILES $tmp_prop"
    sed -e "s|^version=.*|version=${VERSION}|" \
        -e "s|^versionCode=.*|versionCode=${VERSION_CODE}|" \
        module.prop > "$tmp_prop"
    mv -f "$tmp_prop" module.prop
    # M-2 fix: a single global substitution covers every case
    # (prefix, middle, suffix). The previous `${TMP_FILES# $tmp}`
    # line was redundant — the next line already handled it.
    TMP_FILES="${TMP_FILES// $tmp_prop/}"
    log_ok "module.prop → version=${VERSION}, versionCode=${VERSION_CODE}"
else
    log_info "[dry-run] Would update module.prop"
fi

# ============================================================
# [14] Update update.json (requires jq)
# ============================================================
# L-2 fix: compute NEW_ZIP_URL once, before the dry-run branch,
# instead of duplicating the same expression in both arms.
NEW_ZIP_URL="https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/${VERSION}/dnscrypt-webui-${VERSION#v}-module.zip"

if [ "$HAS_JQ" = "1" ]; then
    if [ "$DRY_RUN" = "0" ]; then
        # HARD-REL-05: portable mktemp.
        tmp_json="$(mktemp "${TMPDIR:-/tmp}/update.json.XXXXXX")"
        TMP_FILES="$TMP_FILES $tmp_json"
        jq --arg v "$VERSION" \
           --argjson vc "$VERSION_CODE" \
           --arg url "$NEW_ZIP_URL" \
           '.version = $v | .versionCode = $vc | .zipUrl = $url' \
           update.json > "$tmp_json" && mv -f "$tmp_json" update.json
        # M-2 fix: single global substitution.
        TMP_FILES="${TMP_FILES// $tmp_json/}"
        log_ok "update.json → version=${VERSION}, versionCode=${VERSION_CODE}"
        log_ok "update.json → zipUrl=${NEW_ZIP_URL}"
    else
        log_info "[dry-run] Would update update.json"
        log_info "[dry-run]   version=${VERSION}"
        log_info "[dry-run]   versionCode=${VERSION_CODE}"
        log_info "[dry-run]   zipUrl=${NEW_ZIP_URL}"
    fi
else
    log_warn "Skipping update.json (jq not available)"
fi

# ============================================================
# [15] Verify changes (sanity check)
# ============================================================
log_step "[7/9] Verifying changes"

if [ "$DRY_RUN" = "0" ]; then
    NEW_VERSION_FILE=$(tr -d '\r\n' < VERSION)
    NEW_PROP_VER=$(grep '^version=' module.prop | head -n1 | cut -d= -f2-)
    NEW_PROP_VC=$(grep '^versionCode=' module.prop | head -n1 | cut -d= -f2-)

    # HARD-REL-07: check for empty results explicitly so the
    # error message is clear when a line is missing.
    if [ -z "$NEW_PROP_VER" ]; then
        log_error "module.prop has no 'version=' line after update"
        exit 3
    fi
    if [ -z "$NEW_PROP_VC" ]; then
        log_error "module.prop has no 'versionCode=' line after update"
        exit 3
    fi

    if [ "$NEW_VERSION_FILE" != "$VERSION" ]; then
        log_error "VERSION file mismatch: expected '$VERSION', got '$NEW_VERSION_FILE'"
        exit 3
    fi
    if [ "$NEW_PROP_VER" != "$VERSION" ]; then
        log_error "module.prop version mismatch: expected '$VERSION', got '$NEW_PROP_VER'"
        exit 3
    fi
    if [ "$NEW_PROP_VC" != "$VERSION_CODE" ]; then
        log_error "module.prop versionCode mismatch: expected '$VERSION_CODE', got '$NEW_PROP_VC'"
        exit 3
    fi
    log_ok "VERSION, module.prop verified"
else
    log_info "[dry-run] Skipping verification"
fi

# ============================================================
# [16] Commit
# ============================================================
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
        # M-3 fix: DO NOT clear the ERR trap here. A tag-creation
        # failure right below would otherwise leave a commit with
        # no tag and no automatic recovery. The trap is cleared
        # in §[17] only after the tag is successfully created.
    fi
else
    log_info "[dry-run] Would commit: ${COMMIT_MSG}"
fi

# ============================================================
# [17] Tag
# ============================================================
TAG_MSG="Release ${VERSION}"

if [ "$DRY_RUN" = "0" ]; then
    # Note: this creates an ANNOTATED tag (git tag -a), not a
    # GPG-signed tag (git tag -s).
    #
    # M-3 fix: guard the tag creation. On failure the script
    # prints the exact retry command; the commit already exists
    # locally but no tag was pushed, so release.yml will not
    # fire until the tag is created and pushed.
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

    # R6: only now is it safe to disable the ERR trap — commit
    # AND tag both exist, so rollback() would be destructive.
    trap - ERR 2>/dev/null || true
else
    log_info "[dry-run] Would create annotated tag: ${VERSION}"
fi

# ============================================================
# [18] Push
# ============================================================
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

# ============================================================
# [19] Final summary
# ============================================================
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
        echo -e "     ${DIM}Install jq to enable automatic metadata updates.${NC}"
    fi
    echo ""
    echo -e "  ${DIM}References:${NC}"
    echo -e "    ${DIM}• docs/RELEASE_PROCESS.md — full release process${NC}"
    echo -e "    ${DIM}• docs/UPGRADE.md §3.1    — v1.1.0 → v1.2.0 upgrade path${NC}"
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

# L-5 fix: explicitly warn if update.json was not updated.
if [ "$HAS_JQ" != "1" ]; then
    echo ""
    echo -e "  ${YELLOW}⚠${NC}  update.json was NOT updated (jq unavailable)."
    echo -e "     ${DIM}Users who already installed the module will NOT${NC}"
    echo -e "     ${DIM}see the update until update.json is regenerated${NC}"
    echo -e "     ${DIM}by hand or with a jq-equipped environment.${NC}"
fi

if [ "$NO_PUSH" = "0" ]; then
    echo ""
    echo -e "${BOLD}Next:${NC}"
    echo "  • GitHub Actions (.github/workflows/release.yml) is now running."
    echo "  • It will build 4 architectures, package the module, and publish the release."
    echo "  • For regular releases (from develop/release/*), it will"
    echo "    sync main → develop automatically."
    echo "  • For PATCH releases (from main), you must back-merge manually:"
    echo "      make sync"
    echo ""
    echo -e "${DIM}  Monitor: https://github.com/gasciljh/dnscrypt-proxy-webui/actions${NC}"
else
    echo ""
    echo -e "${BOLD}Next (manual push):${NC}"
    echo "  git push origin ${CURRENT_BRANCH}"
    echo "  git push origin ${VERSION}"
fi
echo ""
echo -e "  ${DIM}References:${NC}"
echo -e "    ${DIM}• docs/RELEASE_PROCESS.md — full release process${NC}"
echo -e "    ${DIM}• docs/UPGRADE.md §3.1    — v1.1.0 → v1.2.0 upgrade path${NC}"
echo ""

exit 0