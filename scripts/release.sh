#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – release.sh
# Version: v1.1.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Automate a new release locally: bump version files, create
#   a signed tag, and push to origin. GitHub Actions
#   (.github/workflows/release.yml) handles the rest:
#     • Build 4 architectures
#     • Package the Magisk module ZIP
#     • Generate SHA-256 + SBOM
#     • Create the GitHub Release
#     • Sync main → develop
#
# Workflow (recommended):
#   1. Work on develop or a release/* branch
#   2. Ensure CHANGELOG.md has an [Unreleased] or [vX.Y.Z] section
#   3. Run: ./scripts/release.sh v1.1.0
#   4. GitHub Actions publishes the release automatically
#
# Usage:
#   ./scripts/release.sh v1.2.0
#   ./scripts/release.sh v1.2.0-beta1
#   ./scripts/release.sh v1.2.0 --dry-run
#   ./scripts/release.sh v1.2.0 --no-push
#   ./scripts/release.sh v1.2.0 --yes
#
# Options:
#   --dry-run       Show what would happen, change nothing
#   --no-push       Create commit + tag locally, do not push
#   --yes           Skip interactive confirmation
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
#   3 = version files inconsistent
#   4 = user aborted
#
# Relationship with release-patch.sh:
#   scripts/release-patch.sh is a thin wrapper around this script.
#   It adds 3 safety rules on top:
#     1. Current branch MUST be `main` (not `develop`).
#     2. MAJOR and MINOR components MUST NOT change.
#     3. PATCH MUST be exactly current + 1.
#
#   release-patch.sh delegates the actual bump logic to this
#   script — the two are always in sync because there is no
#   duplicated code. See docs/adr/0006-rename-hotfix-to-release-patch.md.
#
#   Which one to use:
#     • release.sh       → stable, prerelease, or any SemVer bump
#                          (run from develop or release/*)
#     • release-patch.sh → PATCH-only (run from main)
#
# versionCode formula:
#   versionCode = MAJOR × 1,000,000
#               + MINOR ×    10,000
#               + PATCH ×       100
#               + HOTFIX
#
#   In this script, HOTFIX is always 0. The HOTFIX component is
#   reserved for future use (e.g. a release that re-tags the
#   same MAJOR.MINOR.PATCH with an incremented build counter).
#   Current releases do not use it.
#
#   Constraints:
#     • PATCH  must be ≤ 99 (two digits, because PATCH is ×100)
#     • HOTFIX must be ≤ 99 (two digits, because HOTFIX is ×1)
#
# v1.1.0 changes:
#   • Version bumped to v1.1.0 (documentation only — no behavior
#     changes in this script since v1.0.0).
#   • Added a "Relationship with release-patch.sh" section to
#     make the delegation explicit.
#   • Documented the versionCode formula including the unused
#     HOTFIX component. The prior header was silent on HOTFIX,
#     which could confuse a reader comparing it with docs/.
#   • Expanded the [14] update.json comment to explain why jq is
#     required for that step but optional for the rest of the
#     script.
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
  <version>          Semantic version (e.g. v1.1.0, v1.1.0-beta1)

Options:
  --dry-run          Show what would happen, change nothing
  --no-push          Create commit + tag locally, do not push
  --yes              Skip interactive confirmation
  --help, -h         Show this help

Examples:
  ./scripts/release.sh v1.1.0
  ./scripts/release.sh v1.1.0-beta1
  ./scripts/release.sh v1.1.0 --dry-run
  ./scripts/release.sh v1.1.0 --yes

Workflow:
  1. Work on develop or release/* branch
  2. Ensure CHANGELOG.md is updated
  3. Run release.sh
  4. GitHub Actions publishes the release automatically

For PATCH-only releases (hotfixes):
  Use ./scripts/release-patch.sh instead. See
  docs/BRANCHING.md §8 and docs/adr/0006.
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
    echo "Example: $0 v1.1.0" >&2
    exit 1
fi

# ============================================================
# [4] Header
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  🚀 DNSCrypt Smart Filter – Release Automation            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
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
    log_info "Examples: v1.1.0, v1.2.0, v1.2.0-beta1, v2.0.0-rc1"
    exit 1
fi
log_ok "Version format valid: $VERSION"

# ============================================================
# [7] Compute versionCode
# ============================================================
# Formula: MAJOR*1000000 + MINOR*10000 + PATCH*100 + HOTFIX
#
# HOTFIX is always 0 in this script. The prerelease suffix
# (e.g. "-beta1") is ignored for versionCode — a prerelease
# uses the same code as its stable counterpart.
#
# See the header for the full explanation.
# ============================================================
log_step "[3/9] Computing versionCode"

VERSION_NO_V="${VERSION#v}"
VERSION_CORE="${VERSION_NO_V%%-*}"     # strip prerelease suffix
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
# Warn (do not block) if CHANGELOG.md lacks a section for this
# version or an [Unreleased] section. The maintainer may still
# want to proceed for a snapshot release.
if ! grep -qE "^## \[${VERSION#v}\]|^## \[Unreleased\]" CHANGELOG.md; then
    log_warn "CHANGELOG.md does not contain a section for [${VERSION#v}] or [Unreleased]"
    log_info "Consider adding it before releasing"
    if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
        echo ""
        read -rp "  Continue anyway? (y/N) " -n 1 REPLY
        echo ""
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            log_warn "Aborted by user"
            exit 4
        fi
    fi
else
    log_ok "CHANGELOG.md contains a relevant section"
fi

# ============================================================
# [9] Read current version
# ============================================================
log_step "[5/9] Reading current version"

CURRENT_VERSION=$(tr -d '\r\n' < VERSION 2>/dev/null || echo "unknown")
CURRENT_VC=$(grep '^versionCode=' module.prop 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r' || echo "unknown")

log_info "Current VERSION:     ${CURRENT_VERSION}"
log_info "Current versionCode: ${CURRENT_VC}"
echo ""
log_info "New VERSION:         ${VERSION}"
log_info "New versionCode:     ${VERSION_CODE}"

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
    echo "    3. Update update.json   → version=${VERSION}, versionCode=${VERSION_CODE}"
    echo "    4. Create commit        → release: ${VERSION}"
    echo "    5. Create tag           → ${VERSION}"
    if [ "$NO_PUSH" = "1" ]; then
        echo "    6. (Skip push — --no-push)"
    else
        echo "    6. Push to origin       → ${CURRENT_BRANCH} + tag"
        echo ""
        log_info "GitHub Actions will then publish the release automatically."
    fi
    echo ""
    read -rp "  Proceed? (y/N) " -n 1 REPLY
    echo ""
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        log_warn "Aborted by user"
        exit 4
    fi
fi

# ============================================================
# [11] Backup current values (for rollback on failure)
# ============================================================
log_step "[6/9] Updating version files"

ORIG_VERSION=""
ORIG_MODULE_PROP=""
ORIG_UPDATE_JSON=""

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
    # Use temp file for atomic sed on both GNU and BSD
    tmp_prop="$(mktemp)"
    sed -e "s|^version=.*|version=${VERSION}|" \
        -e "s|^versionCode=.*|versionCode=${VERSION_CODE}|" \
        module.prop > "$tmp_prop"
    mv -f "$tmp_prop" module.prop
    log_ok "module.prop → version=${VERSION}, versionCode=${VERSION_CODE}"
else
    log_info "[dry-run] Would update module.prop"
fi

# ============================================================
# [14] Update update.json (requires jq)
# ============================================================
# update.json is a JSON object with 4 keys:
#   version, versionCode, zipUrl, changelog
#
# Only version and versionCode are updated here. zipUrl and
# changelog are set by the packaging pipeline in release.yml —
# they use a fixed URL template with the tag substituted at
# build time.
#
# jq is REQUIRED for this step. Without jq, the script skips
# update.json entirely and logs a warning. The release can
# still proceed, but the maintainer must update update.json
# manually afterwards. This is deliberate: sed-based JSON
# editing is fragile and can silently corrupt the file.
# ============================================================
if [ "$HAS_JQ" = "1" ]; then
    if [ "$DRY_RUN" = "0" ]; then
        tmp_json="$(mktemp)"
        jq --arg v "$VERSION" \
           --argjson vc "$VERSION_CODE" \
           '.version = $v | .versionCode = $vc' \
           update.json > "$tmp_json" && mv -f "$tmp_json" update.json
        log_ok "update.json → version=${VERSION}, versionCode=${VERSION_CODE}"
    else
        log_info "[dry-run] Would update update.json"
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
    fi
else
    log_info "[dry-run] Would commit: ${COMMIT_MSG}"
fi

# ============================================================
# [17] Tag
# ============================================================
TAG_MSG="Release ${VERSION}"

if [ "$DRY_RUN" = "0" ]; then
    git tag -a "$VERSION" -m "$TAG_MSG"
    log_ok "Tag created: ${VERSION}"
else
    log_info "[dry-run] Would create tag: ${VERSION}"
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
        exit 1
    fi
else
    log_info "[dry-run] Would push: ${CURRENT_BRANCH}"
    log_info "[dry-run] Would push: ${VERSION}"
fi

# ============================================================
# [19] Final summary
# ============================================================
# Remove rollback trap — we succeeded
trap - ERR 2>/dev/null || true

echo ""
if [ "$DRY_RUN" = "1" ]; then
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║  🔍 DRY-RUN Complete — no changes were made              ║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Run without ${CYAN}--dry-run${NC} to apply changes."
    exit 0
fi

echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║  ✅ Release prepared successfully                        ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Version:${NC}       ${GREEN}${VERSION}${NC}"
echo -e "  ${BOLD}versionCode:${NC}   ${GREEN}${VERSION_CODE}${NC}"
echo -e "  ${BOLD}Branch:${NC}        ${CYAN}${CURRENT_BRANCH}${NC}"
echo -e "  ${BOLD}Tag:${NC}           ${CYAN}${VERSION}${NC}"

if [ "$NO_PUSH" = "0" ]; then
    echo ""
    echo -e "${BOLD}Next:${NC}"
    echo "  • GitHub Actions (.github/workflows/release.yml) is now running."
    echo "  • It will build 4 architectures, package the module, and publish the release."
    echo "  • Then it will sync main → develop automatically."
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