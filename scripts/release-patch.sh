#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – release-patch.sh
# Version: v1.0.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Automate a PATCH release (hotfix) from the `main` branch.
#
#   A PATCH release is used ONLY when a critical bug exists in a
#   released version and cannot wait for the next scheduled
#   release. It increments the PATCH component of the version.
#
#   This script:
#     • Verifies the current branch is `main`
#     • Verifies the version is a PATCH bump (not MINOR or MAJOR)
#     • Delegates to scripts/release.sh (same bump logic)
#     • Reminds the user to back-merge main → develop
#
# Usage:
#   ./scripts/release-patch.sh v1.0.1
#   ./scripts/release-patch.sh v1.0.1 --dry-run
#   ./scripts/release-patch.sh v1.0.1 --yes
#
# Options:
#   --dry-run       Show what would happen, change nothing
#   --no-push       Create commit + tag locally, do not push
#   --yes           Skip interactive confirmation
#   --help, -h      Show this help
#
# Requirements:
#   • git (2.30+)
#   • scripts/release.sh (same repository)
#   • CHANGELOG.md updated with the new patch version
#
# Full documentation:
#   docs/BRANCHING.md §8      (Hotfix Flow)
#   docs/RELEASE_PROCESS.md §2.3 (Hotfix release type)
#
# Exit codes:
#   0 = success
#   1 = invalid arguments or environment
#   2 = repository state invalid
#   3 = version rules violated
#   4 = user aborted
# ============================================================

set -euo pipefail

# ============================================================
# [1] Path resolution
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$REPO_ROOT"

RELEASE_SCRIPT="${SCRIPT_DIR}/release.sh"

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
DNSCrypt Smart Filter – release-patch.sh

Usage:
  release-patch.sh <version> [options]

Arguments:
  <version>          Semantic version with a PATCH bump (e.g. v1.0.1)

Options:
  --dry-run          Show what would happen, change nothing
  --no-push          Create commit + tag locally, do not push
  --yes, -y          Skip interactive confirmation
  --help, -h         Show this help

Examples:
  ./scripts/release-patch.sh v1.0.1
  ./scripts/release-patch.sh v1.0.1 --dry-run
  ./scripts/release-patch.sh v1.0.1 --yes

Rules:
  • Current branch MUST be `main`.
  • Version MUST bump only the PATCH component.
  • MINOR/MAJOR bumps are rejected — use `release.sh` for those.
  • After the release, `develop` MUST be back-merged.

See:
  docs/BRANCHING.md §8
  docs/RELEASE_PROCESS.md §2.3
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
    echo "Example: $0 v1.0.1" >&2
    exit 1
fi

# ============================================================
# [4] Header
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  🔧 DNSCrypt Smart Filter – Patch Release Automation      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Target patch version:${NC} ${GREEN}${VERSION}${NC}"
[ "$DRY_RUN" = "1" ] && echo -e "  ${BOLD}Mode:${NC}                 ${YELLOW}DRY-RUN${NC}"
[ "$NO_PUSH" = "1" ] && echo -e "  ${BOLD}Push:${NC}                 ${YELLOW}DISABLED${NC}"
echo ""

# ============================================================
# [5] Environment checks
# ============================================================
log_step "[1/5] Checking environment"

for tool in git sed awk; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "Required tool not found: $tool"
        exit 1
    fi
done
log_ok "Required tools: git, sed, awk"

if [ ! -f "$RELEASE_SCRIPT" ]; then
    log_error "Missing dependency: $RELEASE_SCRIPT"
    log_info "release-patch.sh delegates the bump logic to release.sh"
    log_info "Ensure scripts/release.sh exists in the repository"
    exit 1
fi

if [ ! -x "$RELEASE_SCRIPT" ]; then
    log_warn "release.sh is not executable — fixing permissions"
    chmod +x "$RELEASE_SCRIPT" 2>/dev/null || true
fi

log_ok "release.sh found: $RELEASE_SCRIPT"

# ============================================================
# [6] Validate version format (SemVer, no prerelease)
# ============================================================
log_step "[2/5] Validating version format"

if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_error "Invalid version: '$VERSION'"
    log_info "Patch versions must be in the form: vMAJOR.MINOR.PATCH"
    log_info "Prerelease suffixes (e.g. -beta1) are NOT allowed for patch releases"
    log_info "Examples: v1.0.1, v1.2.3"
    exit 3
fi

log_ok "Version format valid: $VERSION"

# ============================================================
# [7] Compute PATCH delta vs current VERSION
# ============================================================
log_step "[3/5] Verifying PATCH bump rules"

if [ ! -f "VERSION" ]; then
    log_error "VERSION file not found"
    exit 2
fi

CURRENT_VERSION=$(tr -d '\r\n' < VERSION | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$CURRENT_VERSION" ]; then
    log_error "VERSION file is empty"
    exit 2
fi

# Parse current
CURRENT_NO_V="${CURRENT_VERSION#v}"
CUR_MAJOR=$(echo "$CURRENT_NO_V" | cut -d. -f1)
CUR_MINOR=$(echo "$CURRENT_NO_V" | cut -d. -f2)
CUR_PATCH=$(echo "$CURRENT_NO_V" | cut -d. -f3)

# Parse target
TARGET_NO_V="${VERSION#v}"
NEW_MAJOR=$(echo "$TARGET_NO_V" | cut -d. -f1)
NEW_MINOR=$(echo "$TARGET_NO_V" | cut -d. -f2)
NEW_PATCH=$(echo "$TARGET_NO_V" | cut -d. -f3)

log_info "Current version: ${CURRENT_VERSION}"
log_info "Target version:  ${VERSION}"
echo ""

# Rule 1: MAJOR must be equal
if [ "$NEW_MAJOR" != "$CUR_MAJOR" ]; then
    log_error "MAJOR bump detected ($CUR_MAJOR → $NEW_MAJOR)"
    log_info "Patch releases MUST NOT change the MAJOR component"
    log_info "Use scripts/release.sh for MAJOR releases"
    exit 3
fi

# Rule 2: MINOR must be equal
if [ "$NEW_MINOR" != "$CUR_MINOR" ]; then
    log_error "MINOR bump detected ($CUR_MINOR → $NEW_MINOR)"
    log_info "Patch releases MUST NOT change the MINOR component"
    log_info "Use scripts/release.sh for MINOR releases"
    exit 3
fi

# Rule 3: PATCH must be exactly current + 1
EXPECTED_PATCH=$((CUR_PATCH + 1))

if [ "$NEW_PATCH" != "$EXPECTED_PATCH" ]; then
    log_error "PATCH must be exactly $EXPECTED_PATCH (current: $CUR_PATCH)"
    log_info "Patch releases increment PATCH by exactly 1"
    log_info "Expected: v${CUR_MAJOR}.${CUR_MINOR}.${EXPECTED_PATCH}"
    exit 3
fi

log_ok "PATCH bump valid: $CUR_PATCH → $NEW_PATCH"

# ============================================================
# [8] Verify branch is `main`
# ============================================================
log_step "[4/5] Verifying branch"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not a Git repository"
    exit 2
fi

CURRENT_BRANCH=$(git branch --show-current)

if [ -z "$CURRENT_BRANCH" ]; then
    log_error "Detached HEAD — checkout 'main' first"
    exit 2
fi

if [ "$CURRENT_BRANCH" != "main" ]; then
    log_error "Patch releases must be created from the 'main' branch"
    log_info "Current branch: $CURRENT_BRANCH"
    echo ""
    log_info "Switch with:"
    echo "    git checkout main"
    echo "    git pull origin main"
    echo "    ./scripts/release-patch.sh ${VERSION}"
    exit 2
fi

log_ok "On branch: main"

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
    log_info "Delete it first if you are certain:"
    echo "    git tag -d ${VERSION}"
    echo "    git push origin :refs/tags/${VERSION}"
    exit 2
fi
log_ok "Tag ${VERSION} is available"

# ============================================================
# [9] Confirmation
# ============================================================
log_step "[5/5] Confirmation"

echo -e "  ${BOLD}Patch release summary:${NC}"
echo ""
echo -e "    Current version:  ${CURRENT_VERSION}"
echo -e "    Target version:   ${GREEN}${VERSION}${NC}"
echo -e "    Branch:           ${CYAN}main${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}⚠️  Important:${NC}"
echo ""
echo "    1. This will delegate to scripts/release.sh"
echo "    2. It will bump VERSION + module.prop + update.json"
echo "    3. It will create a commit + tag on 'main'"
echo "    4. GitHub Actions will publish the release"
echo "    5. After the release: you MUST back-merge main → develop"
echo ""
echo -e "  ${DIM}Back-merge command (after the release is live):${NC}"
echo -e "    ${DIM}make sync${NC}"
echo -e "    ${DIM}(or: git checkout develop && git merge origin/main && git push)${NC}"
echo ""

if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
    read -rp "  Proceed with the patch release? (y/N) " -n 1 REPLY
    echo ""
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        log_warn "Aborted by user"
        exit 4
    fi
fi

# ============================================================
# [10] Delegate to release.sh
# ============================================================
log_step "Delegating to release.sh"

RELEASE_ARGS=("$VERSION")
[ "$DRY_RUN" = "1" ] && RELEASE_ARGS+=("--dry-run")
[ "$NO_PUSH" = "1" ] && RELEASE_ARGS+=("--no-push")
RELEASE_ARGS+=("--yes")  # already confirmed here

log_info "Running: release.sh ${RELEASE_ARGS[*]}"
echo ""

if ! "$RELEASE_SCRIPT" "${RELEASE_ARGS[@]}"; then
    log_error "release.sh failed — patch release was NOT published"
    log_info "Fix the issue and retry:"
    echo "    ./scripts/release-patch.sh ${VERSION}"
    exit 1
fi

# ============================================================
# [11] Post-release reminder
# ============================================================
echo ""
echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}${BOLD}║  ⚠️  Remember to back-merge main → develop               ║${NC}"
echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Why?${NC}"
echo "    Patch releases land on 'main' first. Without a back-merge,"
echo "    'develop' will be missing the fix, and the next"
echo "    release will reintroduce the bug."
echo ""
echo -e "  ${BOLD}How?${NC}"
echo "    make sync"
echo ""
echo -e "    ${DIM}or manually:${NC}"
echo "      git checkout develop"
echo "      git pull origin develop"
echo "      git merge origin/main --no-edit"
echo "      git push origin develop"
echo ""
echo -e "  ${DIM}See docs/BRANCHING.md §8.4 for details.${NC}"
echo ""

exit 0