#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – release-patch.sh
# Version: v1.2.0 (Global Edition)
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
#     • Verifies the PATCH is exactly current + 1 (no skipping)
#     • Delegates to scripts/release.sh (same bump logic)
#     • Reminds the user to back-merge main → develop
#
# Wrapper design:
#   This script is a THIN WRAPPER around scripts/release.sh.
#   It does NOT contain any version bump logic of its own.
#
#   What it adds on top of release.sh:
#     1. Branch check       — MUST be `main`
#     2. MAJOR equality     — must not change
#     3. MINOR equality     — must not change
#     4. PATCH monotonicity — must be exactly current + 1
#
#   After those checks pass, it calls:
#     scripts/release.sh <version> [--dry-run] [--no-push] --yes
#
#   See docs/adr/0006-rename-hotfix-to-release-patch.md.
#
# The 4 safety rules (detailed):
#
#   Rule 1 — Branch must be `main`
#   Rule 2 — MAJOR must not change
#   Rule 3 — MINOR must not change
#   Rule 4 — PATCH must be exactly current + 1
#
# versionCode formula (inherited from release.sh):
#   versionCode = MAJOR × 1,000,000
#               + MINOR ×    10,000
#               + PATCH ×       100
#               + HOTFIX
#
#   Canonical examples:
#     v1.0.0 → 1000000
#     v1.1.0 → 1010000
#     v1.2.0 → 1020000
#     v1.2.1 → 1020100
#     v1.2.5 → 1020500
#     v1.3.0 → 1030000
#     v2.0.0 → 2000000
#
# Exit codes:
#   0 = success
#   1 = invalid arguments or environment
#   2 = repository state invalid
#   3 = version rules violated
#   4 = user aborted
#
# ============================================================
# v1.2.0 — POST-AUDIT FIXES (still v1.2.0)
# ============================================================
#   🔧 P1 — versionCode example table corrected
#     (v1.2.1 → 1020100, not 1020001).
#   🔧 BUG-R4 — header says "annotated tag", not "signed".
#   🔧 R9 — back-merge banner only when a push occurred.
#   🔧 R5 — back-merge rationale clarified.
#
# ============================================================
# v1.2.0 (Global Edition) — Additional hardening in this revision
# ============================================================
#   🛡️ HARD-RP-01 — `read -rp` calls tolerate EOF. Under
#     `set -e`, a closed stdin previously aborted the script
#     with a bare exit 1. Parity with HARD-REL-04 in release.sh.
#
#   🛡️ HARD-RP-02 — CHANGELOG regex escapes the dots in the
#     version string. Previously `## [1.2.1]` matched
#     `## [1x2y1]` because `.` is a regex metacharacter.
#     Parity with HARD-REL-03 in release.sh.
#
#   🛡️ HARD-RP-03 — CURRENT_VERSION format is validated in [7]
#     before parsing. A malformed VERSION file now produces a
#     clear error instead of a cryptic bash arithmetic failure.
#
#   🛡️ HARD-RP-04 — `REPLY` is reset after each read. Parity
#     with HARD-REL-09.
#
#   🛡️ HARD-RP-05 — The jq availability message no longer
#     claims update.json is updated "automatically"; it now
#     says "by release.sh".
#
# ============================================================
# v1.2.0 (Global Edition) — Revision 2 (M-1..M-3, L-1..L-3)
# ============================================================
#   🔴 M-1 — The post-release back-merge banner was shown
#     even under --dry-run (NO_PUSH=0, DRY_RUN=1): nothing had
#     been pushed, yet the user was told to back-merge. The
#     guard now covers BOTH --no-push and --dry-run.
#
#   🟡 M-2 — The exit status of release.sh is now propagated.
#     Previously every failure was collapsed to exit 1, which
#     erased the distinction between an aborted user prompt
#     (4), a version-rule violation (3), a bad repo state (2),
#     and a bad environment (1). CI can now react correctly.
#
#   🟡 M-3 — `awk` was listed as a required tool but is not
#     used anywhere in this script. Removed from the tool
#     check to avoid rejecting otherwise-valid environments.
#
#   🟢 L-1 — `--yes, -y` documented (already accepted by the
#     case arm).
#
#   🟢 L-2 — `read -rp ... -n 1` prompts now drain the rest of
#     the line via `read -r _ || true` so a future prompt in
#     the same script cannot inherit stray input. Parity with
#     L-3 in release.sh.
#
#   🟢 L-3 — The banner comment in §[9] now clarifies that
#     `release.sh` (not this wrapper) is what actually bumps
#     module.prop and update.json.
#
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

# is_numeric — true iff the argument is one or more digits.
is_numeric() {
    case "${1:-}" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

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
  <version>          Semantic version with a PATCH bump (e.g. v1.2.1)

Options:
  --dry-run          Show what would happen, change nothing
  --no-push          Create commit + tag locally, do not push
  --yes, -y          Skip interactive confirmation
  --help, -h         Show this help

Examples:
  ./scripts/release-patch.sh v1.2.1
  ./scripts/release-patch.sh v1.2.1 --dry-run
  ./scripts/release-patch.sh v1.2.1 --yes

Rules:
  • Current branch MUST be `main`.
  • Version MUST bump only the PATCH component.
  • MINOR/MAJOR bumps are rejected — use `release.sh` for those.
  • PATCH must be exactly current + 1 (no skipping).
  • After the release, `develop` MUST be back-merged manually.

How this script works:
  It is a thin wrapper around scripts/release.sh. It performs
  four safety checks (branch, MAJOR equality, MINOR equality,
  PATCH monotonicity), then delegates to release.sh.

Requirements:
  • git (2.30+)
  • scripts/release.sh (same repository)
  • CHANGELOG.md updated with the new patch version
  • jq (optional — inherited from release.sh; needed only for
    automatic update.json updates by release.sh)

See:
  docs/BRANCHING.md §8
  docs/RELEASE_PROCESS.md §2.3
  docs/adr/0006-rename-hotfix-to-release-patch.md
  docs/UPGRADE.md §3.1   (v1.1.0 → v1.2.0 upgrade path)
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
    echo "Example: $0 v1.2.1" >&2
    exit 1
fi

# ============================================================
# [4] Header
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  DNSCrypt Smart Filter – Patch Release Automation        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Target patch version:${NC} ${GREEN}${VERSION}${NC}"
[ "$DRY_RUN" = "1" ] && echo -e "  ${BOLD}Mode:${NC}                 ${YELLOW}DRY-RUN${NC}"
[ "$NO_PUSH" = "1" ] && echo -e "  ${BOLD}Push:${NC}                 ${YELLOW}DISABLED${NC}"
echo ""

# ============================================================
# [5] Environment checks
# ============================================================
log_step "[1/6] Checking environment"

# M-3 fix: `awk` was removed. The script does not use it —
# keeping it in the check would reject valid environments.
for tool in git sed; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "Required tool not found: $tool"
        exit 1
    fi
done
log_ok "Required tools: git, sed"

# HARD-RP-05: message no longer claims "automatically".
if command -v jq >/dev/null 2>&1; then
    log_ok "jq available (update.json will be updated by release.sh)"
else
    log_warn "jq not found — release.sh will skip update.json"
    log_info "The PATCH release can still proceed"
    log_info "You MUST update update.json manually after the release"
fi

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
log_step "[2/6] Validating version format"

if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_error "Invalid version: '$VERSION'"
    log_info "Patch versions must be in the form: vMAJOR.MINOR.PATCH"
    log_info "Prerelease suffixes (e.g. -beta1) are NOT allowed for patch releases"
    log_info "Examples: v1.2.1, v1.3.1"
    exit 3
fi

log_ok "Version format valid: $VERSION"

# ============================================================
# [7] Compute PATCH delta vs current VERSION
# ============================================================
log_step "[3/6] Verifying PATCH bump rules"

if [ ! -f "VERSION" ]; then
    log_error "VERSION file not found"
    exit 2
fi

CURRENT_VERSION=$(tr -d '\r\n' < VERSION | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$CURRENT_VERSION" ]; then
    log_error "VERSION file is empty"
    exit 2
fi

# HARD-RP-03: validate the current VERSION format before parsing.
# A malformed file (e.g. "1.2" with only two components) would
# otherwise produce a cryptic bash arithmetic error.
if ! echo "$CURRENT_VERSION" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_error "Current VERSION file has an invalid format: '$CURRENT_VERSION'"
    log_info "Expected: vMAJOR.MINOR.PATCH (e.g. v1.2.0)"
    log_info "Fix VERSION before running a patch release"
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

# Numeric guard (defensive — the format check above already
# guarantees digits, but a non-numeric value here would
# indicate an internal inconsistency).
for _v in "$CUR_MAJOR" "$CUR_MINOR" "$CUR_PATCH" \
          "$NEW_MAJOR" "$NEW_MINOR" "$NEW_PATCH"; do
    if ! is_numeric "$_v"; then
        log_error "Internal error: failed to parse numeric component '$_v'"
        exit 2
    fi
done

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
log_step "[4/6] Verifying branch"

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

# --- CHANGELOG check ---
# HARD-RP-02: escape the dots in the version string before
# using it in the regex. Without this, `## [1.2.1]` would
# match `## [1x2y1]` and vice versa.
CHANGELOG_VER_ESCAPED=$(printf '%s' "${VERSION#v}" | sed 's/\./\\./g')
if ! grep -qE "^## \[v?${CHANGELOG_VER_ESCAPED}\]|^## \[Unreleased\]" CHANGELOG.md 2>/dev/null; then
    log_warn "CHANGELOG.md does not contain a section for [${VERSION#v}] or [Unreleased]"
    log_info "Consider adding it before releasing"
    if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
        echo ""
        # HARD-RP-01: tolerate EOF on stdin.
        # L-2: drain the rest of the line.
        read -rp "  Continue anyway? (y/N) " -n 1 REPLY || REPLY=""
        read -r _ || true
        echo ""
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            log_warn "Aborted by user"
            exit 4
        fi
        # HARD-RP-04: reset REPLY.
        REPLY=""
    fi
else
    log_ok "CHANGELOG.md contains a relevant section"
fi

# ============================================================
# [9] Confirmation
# ============================================================
log_step "[5/6] Confirmation"

echo -e "  ${BOLD}Patch release summary:${NC}"
echo ""
echo -e "    Current version:  ${CURRENT_VERSION}"
echo -e "    Target version:   ${GREEN}${VERSION}${NC}"
echo -e "    Branch:           ${CYAN}main${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}Important:${NC}"
echo ""
# L-3 fix: explicit that release.sh (not this wrapper) is what
# bumps module.prop and update.json.
echo "    1. This wrapper will delegate to scripts/release.sh"
echo "    2. release.sh will bump VERSION + module.prop + update.json"
echo "       (update.json also gets a new zipUrl — see release.sh)"
echo "    3. release.sh will create a commit + an ANNOTATED tag on 'main'"
echo "    4. GitHub Actions will publish the release"
echo "    5. After the release: you MUST back-merge main → develop"
echo "       (release.yml does not auto-sync for PATCH releases)"
echo ""
echo -e "  ${DIM}Back-merge command (after the release is live):${NC}"
echo -e "    ${DIM}make sync${NC}"
echo -e "    ${DIM}(or: git checkout develop && git merge origin/main && git push)${NC}"
echo ""

if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
    # HARD-RP-01: tolerate EOF.
    # L-2: drain the rest of the line.
    read -rp "  Proceed with the patch release? (y/N) " -n 1 REPLY || REPLY=""
    read -r _ || true
    echo ""
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        log_warn "Aborted by user"
        exit 4
    fi
    REPLY=""
fi

# ============================================================
# [10] Delegate to release.sh
# ============================================================
# All version bump logic, file updates, verification, commit,
# tag, and push are handled by release.sh. This script only
# adds the pre-flight checks above.
#
# M-2 fix: propagate the exact exit code of release.sh. The
# wrapper previously collapsed every failure to 1, hiding the
# difference between user abort (4), version-rule violation (3),
# bad repo state (2), and bad environment (1). CI pipelines
# can now react correctly to each case.
# ============================================================
log_step "[6/6] Delegating to release.sh"

RELEASE_ARGS=("$VERSION")
[ "$DRY_RUN" = "1" ] && RELEASE_ARGS+=("--dry-run")
[ "$NO_PUSH" = "1" ] && RELEASE_ARGS+=("--no-push")
RELEASE_ARGS+=("--yes")  # already confirmed here

log_info "Running: release.sh ${RELEASE_ARGS[*]}"
echo ""

if "$RELEASE_SCRIPT" "${RELEASE_ARGS[@]}"; then
    _rc=0
else
    _rc=$?
fi

if [ "$_rc" -ne 0 ]; then
    log_error "release.sh failed (exit=$_rc) — patch release was NOT published"
    case "$_rc" in
        1) log_info "release.sh: invalid arguments or environment" ;;
        2) log_info "release.sh: repository state invalid" ;;
        3) log_info "release.sh: version metadata mismatch" ;;
        4) log_info "release.sh: user aborted" ;;
        *) log_info "release.sh: unexpected exit code" ;;
    esac
    log_info "Fix the issue and retry:"
    echo "    ./scripts/release-patch.sh ${VERSION}"
    exit "$_rc"
fi

# ============================================================
# [11] Post-release reminder
# ============================================================
# R9 fix (extended): the back-merge banner is only meaningful
# when a push actually occurred. Under --no-push nothing was
# published; under --dry-run nothing was even committed. Show
# the banner only in the normal (push) case.
#
# M-1 fix: the dry-run branch was previously missing — the
# banner was shown even when --dry-run was passed.
if [ "$DRY_RUN" = "1" ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}Note: --dry-run was passed.${NC}"
    echo -e "  Nothing was committed, tagged, or pushed."
    echo -e "  The back-merge reminder is not applicable."
    echo ""
    echo -e "  Run without ${CYAN}--dry-run${NC} to apply the patch release."
    echo ""
    exit 0
fi

if [ "$NO_PUSH" = "1" ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}Note: --no-push was passed.${NC}"
    echo -e "  Nothing has been published yet."
    echo -e "  After you push manually, remember to back-merge main → develop:"
    echo -e "    ${DIM}git push origin main${NC}"
    echo -e "    ${DIM}git push origin ${VERSION}${NC}"
    echo -e "    ${DIM}make sync${NC}"
    echo ""
    exit 0
fi

echo ""
echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}${BOLD}║  Remember to back-merge main → develop                   ║${NC}"
echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Why?${NC}"
echo "    Patch releases land on 'main' first. Unlike regular"
echo "    releases (from develop / release/*), release.yml does"
echo "    NOT auto-sync main → develop for PATCH releases,"
echo "    because 'main' IS the sync target. Without a manual"
echo "    back-merge, 'develop' will be missing the fix, and"
echo "    the next release will reintroduce the bug."
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