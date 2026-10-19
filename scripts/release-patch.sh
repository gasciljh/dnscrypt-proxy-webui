#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter — release-patch.sh
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-19
# ============================================================
# Automates a PATCH release (hotfix) from the `main` branch.
#
# PATCH releases are for critical bugs in a released version.
# This script adds 4 safety checks on top of release.sh:
#   1. Current branch MUST be `main`.
#   2. MAJOR component MUST NOT change.
#   3. MINOR component MUST NOT change.
#   4. PATCH MUST be exactly current + 1 (no skipping).
#
# Then delegates ALL bump logic to release.sh.
#
# Usage:
#   ./scripts/release-patch.sh v1.5.1 [options]
#
# Options:
#   --dry-run       Show changes without applying
#   --no-push       Create commit + tag locally, skip push
#   --skip-xnote    Skip the x-note-v<XYZ> presence check
#   --yes, -y       Skip interactive confirmation
#   --help, -h      Show this help
#
# Exit codes:
#   0 = success · 1 = invalid arguments · 2 = repo state invalid
#   3 = version rule violated · 4 = user aborted
#
# Post-release: release.yml runs main → develop sync on every
# tag push. If it fails, back-merge manually: `make sync`.
#
# See docs/CONTRIBUTING.md §13 (Hotfix Flow) for the PATCH branch model.
# See docs/adr/0001-release-workflow.md §3 (Post-release sync) for the sync design.
# ============================================================

set -euo pipefail

# ────────────────────────────────────────────────────────────
# [1] Paths
# ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

RELEASE_SCRIPT="${SCRIPT_DIR}/release.sh"

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

is_numeric() {
    case "${1:-}" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

# strip_leading_zeros — "08" → 8 (avoids bash octal).
# Empty / all-zeros → "0".
strip_leading_zeros() {
    local _v
    _v=$(printf '%s' "$1" | sed 's/^0*//')
    [ -z "$_v" ] && _v="0"
    printf '%s' "$_v"
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
DNSCrypt Smart Filter – release-patch.sh

Usage:
  release-patch.sh <version> [options]

Arguments:
  <version>          Semantic version with PATCH bump (e.g. v1.5.1)

Options:
  --dry-run          Show what would happen, change nothing
  --no-push          Create commit + tag locally, do not push
  --skip-xnote       Skip the x-note-v<XYZ> presence check
  --yes, -y          Skip interactive confirmation
  --help, -h         Show this help

Examples:
  ./scripts/release-patch.sh v1.5.1
  ./scripts/release-patch.sh v1.5.1 --dry-run
  ./scripts/release-patch.sh v1.5.1 --yes

Rules:
  • Current branch MUST be `main`.
  • Version MUST bump only the PATCH component.
  • MINOR/MAJOR bumps are rejected — use release.sh for those.
  • PATCH must be exactly current + 1 (no skipping).
  • release.yml runs main → develop sync on tag push.
    If it fails, back-merge manually: make sync.

Manual step — x-note-v<XYZ>:
  The per-release field "x-note-v<XYZ>" in update.json (e.g.
  "x-note-v151" for v1.5.1) contains hand-written release notes
  shown in the auto-update metadata of the root manager.

  release.sh VERIFIES its presence and ABORTS if missing.
  Pass --skip-xnote to bypass the check (not recommended).

Requirements:
  git 2.30+, release.sh (same repo), CHANGELOG.md updated with
  the new patch version, update.json with x-note-v<XYZ>.

See:
  docs/CONTRIBUTING.md §13 (Hotfix Flow)
  docs/CONTRIBUTING.md §11 (Release Process)
  docs/adr/0001-release-workflow.md §3 (Post-release sync)
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
    echo "Example: $0 v1.5.1" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# [6] Header
# ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  DNSCrypt Smart Filter – Patch Release Automation        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Target patch version:${NC} ${GREEN}${VERSION}${NC}"
[ "$DRY_RUN" = "1" ] && echo -e "  ${BOLD}Mode:${NC}                 ${YELLOW}DRY-RUN${NC}"
[ "$NO_PUSH" = "1" ] && echo -e "  ${BOLD}Push:${NC}                 ${YELLOW}DISABLED${NC}"
[ "$SKIP_XNOTE" = "1" ] && echo -e "  ${BOLD}x-note check:${NC}         ${YELLOW}SKIPPED${NC}"
echo ""

# ────────────────────────────────────────────────────────────
# [7] Environment check
# ────────────────────────────────────────────────────────────
log_step "[1/6] Checking environment"

for tool in git sed; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "Required tool not found: $tool"
        exit 1
    fi
done
log_ok "Required tools: git, sed"

if command -v jq >/dev/null 2>&1; then
    log_ok "jq available (release.sh will update update.json)"
else
    log_warn "jq NOT found — release.sh will skip update.json"
    log_warn "  The x-note-v<XYZ> presence check will ALSO be skipped."
    log_info "The PATCH release can still proceed"
    log_info "You MUST update update.json manually after the release"
    log_info "Install jq: apt install jq / brew install jq / pkg install jq"
fi

if [ ! -f "$RELEASE_SCRIPT" ]; then
    log_error "Missing dependency: $RELEASE_SCRIPT"
    log_info "release-patch.sh delegates the bump logic to release.sh"
    exit 1
fi

if [ ! -x "$RELEASE_SCRIPT" ]; then
    log_warn "release.sh is not executable — fixing permissions"
    chmod +x "$RELEASE_SCRIPT" 2>/dev/null || true
fi

log_ok "release.sh found: $RELEASE_SCRIPT"

# ────────────────────────────────────────────────────────────
# [8] Version format validation
# ────────────────────────────────────────────────────────────
log_step "[2/6] Validating version format"

if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_error "Invalid version: '$VERSION'"
    log_info "Patch versions: vMAJOR.MINOR.PATCH (e.g. v1.5.1)"
    log_info "Prerelease suffixes (e.g. -beta1) are NOT allowed here"
    exit 3
fi

log_ok "Version format valid: $VERSION"

# ────────────────────────────────────────────────────────────
# [9] PATCH bump rules
# ────────────────────────────────────────────────────────────
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

# Validate current VERSION before parsing (a malformed file
# like "1.2" would produce a cryptic arithmetic error).
if ! echo "$CURRENT_VERSION" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_error "Current VERSION file has an invalid format: '$CURRENT_VERSION'"
    log_info "Expected: vMAJOR.MINOR.PATCH (e.g. v1.5.0)"
    log_info "Fix VERSION before running a patch release"
    exit 2
fi

# Parse current. Leading zeros stripped before arithmetic
# so "v1.5.08" is handled correctly (bash would reject "08"
# as an invalid octal literal).
CURRENT_NO_V="${CURRENT_VERSION#v}"
CUR_MAJOR=$(strip_leading_zeros "$(echo "$CURRENT_NO_V" | cut -d. -f1)")
CUR_MINOR=$(strip_leading_zeros "$(echo "$CURRENT_NO_V" | cut -d. -f2)")
CUR_PATCH=$(strip_leading_zeros "$(echo "$CURRENT_NO_V" | cut -d. -f3)")

# Parse target.
TARGET_NO_V="${VERSION#v}"
NEW_MAJOR=$(strip_leading_zeros "$(echo "$TARGET_NO_V" | cut -d. -f1)")
NEW_MINOR=$(strip_leading_zeros "$(echo "$TARGET_NO_V" | cut -d. -f2)")
NEW_PATCH=$(strip_leading_zeros "$(echo "$TARGET_NO_V" | cut -d. -f3)")

# Defensive numeric guard. Format checks above already
# guarantee digits, but a non-numeric value here would
# indicate an internal inconsistency.
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

# Rule 3: PATCH must be exactly current + 1.
# Numeric comparison (not string) so "9" and "09" compare equal.
EXPECTED_PATCH=$((CUR_PATCH + 1))

if [ "$NEW_PATCH" -ne "$EXPECTED_PATCH" ]; then
    log_error "PATCH must be exactly $EXPECTED_PATCH (current: $CUR_PATCH)"
    log_info "Patch releases increment PATCH by exactly 1"
    log_info "Expected: v${CUR_MAJOR}.${CUR_MINOR}.${EXPECTED_PATCH}"
    exit 3
fi

log_ok "PATCH bump valid: $CUR_PATCH → $NEW_PATCH"

# ────────────────────────────────────────────────────────────
# [10] Branch check
# ────────────────────────────────────────────────────────────
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
# Escape dots before regex — without this, "## [1.5.1]" would
# match "## [1x5y1]".
CHANGELOG_VER_ESCAPED=$(printf '%s' "${VERSION#v}" | sed 's/\./\\./g')
if ! grep -qE "^## \[v?${CHANGELOG_VER_ESCAPED}\]|^## \[Unreleased\]" CHANGELOG.md 2>/dev/null; then
    log_warn "CHANGELOG.md does not contain a section for [${VERSION#v}] or [Unreleased]"
    log_info "Consider adding it before releasing"
    if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
        prompt_confirm "  Continue anyway? (y/N) " \
            || { log_warn "Aborted by user"; exit 4; }
    fi
else
    log_ok "CHANGELOG.md contains a relevant section"
fi

# ────────────────────────────────────────────────────────────
# [11] Confirmation (BUG-13, BUG-14)
# ────────────────────────────────────────────────────────────
log_step "[5/6] Confirmation"

# Derive the x-note key for display.
#   v1.5.1 → x-note-v151
XNOTE_KEY="x-note-v${TARGET_NO_V//./}"

# Manual fields NOT touched by release.sh (or by this wrapper).
# They MUST be updated before tagging, or the release ships
# stale values — `sw.js CACHE_VERSION` is the critical one:
# without it, the PWA cache is never invalidated and every
# user keeps the old assets until they manually clear site
# data. See docs/REFERENCE.md §7.7.6 for the SW-PRECACHE
# rationale.
_print_manual_fields() {
    local _title="${1:-update before proceeding}"
    echo -e "  ${BOLD}Manual fields NOT touched by release.sh — ${_title}:${NC}"
    echo -e "    ${DIM}• ${XNOTE_KEY}         (verified — present in update.json)${NC}"
    echo -e "    ${DIM}• web/manifest.json   → version  (strip 'v' prefix)${NC}"
    echo -e "    ${DIM}• web/sw.js           → CACHE_VERSION  (critical for PWA)${NC}"
    echo -e "    ${DIM}• web/index.html      → var VERSION${NC}"
    echo -e "    ${DIM}• web/dashboard.html  → var VERSION + <title>${NC}"
    echo -e "    ${DIM}• proxy/app-apk.version        (only if companion app changed)${NC}"
    echo -e "    ${DIM}• proxy/dnscrypt-proxy.version (only if DNS engine changed)${NC}"
}

echo -e "  ${BOLD}Patch release summary:${NC}"
echo ""
echo -e "    Current version:  ${CURRENT_VERSION}"
echo -e "    Target version:   ${GREEN}${VERSION}${NC}"
echo -e "    Branch:           ${CYAN}main${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}Important:${NC}"
echo ""
echo "    1. This wrapper delegates to scripts/release.sh"
echo "    2. release.sh will bump:"
echo "         • VERSION       → ${VERSION}"
echo "         • module.prop   → version + versionCode"
echo "         • update.json   → 6 fields:"
echo "             - version            = ${VERSION}"
echo "             - versionCode        = (auto-computed)"
echo "             - versionName        = \"${VERSION} (Global Edition)\""
echo "             - releaseDate        = (UTC today)"
echo "             - zipUrl             = (new tag URL)"
echo "             - x-note-last-updated = (UTC today)"
echo "    3. release.sh verifies the '${XNOTE_KEY}' field is present"
echo "       in update.json and ABORTS if missing (exit 3)."
if [ "$SKIP_XNOTE" = "1" ]; then
    echo -e "       ${YELLOW}(SKIPPED — --skip-xnote was passed)${NC}"
fi
echo "    4. release.sh creates a commit + ANNOTATED tag on 'main'"
echo "    5. GitHub Actions will publish the release"
echo "    6. release.yml runs the main → develop sync on every tag push."
echo "       If it fails, back-merge manually: make sync"
echo ""
echo -e "  ${DIM}Files that MUST be updated before tagging (release.sh does NOT touch them):${NC}"
echo ""
_print_manual_fields "update before proceeding"
echo ""

if [ "$SKIP_XNOTE" = "1" ]; then
    echo -e "  ${YELLOW}${BOLD}⚠ WARNING:${NC} --skip-xnote is set."
    echo -e "  ${DIM}The '${XNOTE_KEY}' field in update.json will NOT be verified.${NC}"
    echo -e "  ${DIM}End users may see a stale release note in their update UI.${NC}"
    echo ""
fi

if [ "$SKIP_CONFIRM" != "1" ] && [ "$DRY_RUN" != "1" ]; then
    prompt_confirm "  Proceed with the patch release? (y/N) " \
        || { log_warn "Aborted by user"; exit 4; }
fi

# ────────────────────────────────────────────────────────────
# [12] Delegate to release.sh
# ────────────────────────────────────────────────────────────
# All version bump logic, file updates, verification, commit,
# tag, and push are handled by release.sh. This script only
# adds the 3 pre-flight PATCH rules above.
#
# The exact exit code of release.sh is propagated so a caller
# can distinguish user abort (4), version-rule violation (3),
# bad repo state (2), and bad environment (1).
log_step "[6/6] Delegating to release.sh"

RELEASE_ARGS=("$VERSION")
[ "$DRY_RUN" = "1" ] && RELEASE_ARGS+=("--dry-run")
[ "$NO_PUSH" = "1" ] && RELEASE_ARGS+=("--no-push")
[ "$SKIP_XNOTE" = "1" ] && RELEASE_ARGS+=("--skip-xnote")
RELEASE_ARGS+=("--yes")  # already confirmed above

log_info "Running: release.sh ${RELEASE_ARGS[*]}"
echo ""

_rc=0
"$RELEASE_SCRIPT" "${RELEASE_ARGS[@]}" || _rc=$?

if [ "$_rc" -ne 0 ]; then
    log_error "release.sh failed (exit=$_rc) — patch release was NOT published"
    case "$_rc" in
        1) log_info "release.sh: invalid arguments or environment" ;;
        2) log_info "release.sh: repository state invalid" ;;
        3) log_info "release.sh: version metadata mismatch (see above)" ;;
        4) log_info "release.sh: user aborted" ;;
        *) log_info "release.sh: unexpected exit code" ;;
    esac
    log_info "Fix the issue and retry:"
    echo "    ./scripts/release-patch.sh ${VERSION}"
    exit "$_rc"
fi

# ────────────────────────────────────────────────────────────
# [13] Post-release reminder (BUG-12, BUG-13, BUG-14)
# ────────────────────────────────────────────────────────────
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
    echo -e "  After you push manually, release.yml will run the"
    echo -e "  main → develop sync as part of the release workflow."
    echo ""
    echo -e "  To push manually:"
    echo -e "    ${DIM}git push origin main${NC}"
    echo -e "    ${DIM}git push origin ${VERSION}${NC}"
    echo ""
    echo -e "  If the sync step fails, back-merge manually:"
    echo -e "    ${DIM}make sync${NC}"
    echo ""
    echo -e "  ${DIM}Verify these fields match the tag (release.sh did NOT touch them):${NC}"
    echo ""
    _print_manual_fields "verify these match the tag"
    echo ""
    exit 0
fi

echo ""
echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}${BOLD}║  Post-release: sync main → develop (if not automatic)    ║${NC}"
echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}What happens next:${NC}"
echo "    release.yml runs the main → develop sync step at the"
echo "    end of every tag push. In the common case, the sync"
echo "    succeeds and nothing is required from you."
echo ""
echo -e "  ${BOLD}If the sync step fails${NC} (e.g. a real merge conflict):"
echo "    back-merge manually so 'develop' does not miss the fix."
echo "    Without it, the next release would reintroduce the bug."
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
echo -e "  ${DIM}See docs/adr/0001-release-workflow.md §3 for the sync design.${NC}"
echo ""
echo -e "  ${DIM}Verify these fields match the tag (release.sh did NOT touch them):${NC}"
echo ""
_print_manual_fields "verify these match the tag"
echo ""

exit 0