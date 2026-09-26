#!/usr/bin/env bash
# ============================================================
# DNSCrypt Smart Filter – devcontainer setup
# Version: v1.1.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Runs automatically after the devcontainer is created
#   (postCreateCommand). Installs all tools required for
#   development and building.
#
# Features:
#   • Idempotent — safe to run more than once
#   • Verbose — displays every step
#   • Final check — verifies each tool installed correctly
#
# Tools installed:
#   • Go 1.22               (from devcontainer feature)
#   • make, git, curl, jq, zip, unzip
#   • shellcheck            (Shell linting)
#   • shfmt                 (Shell formatting)
#   • golangci-lint v2.5.0  (Go linting)
#   • staticcheck           (Go static analysis)
#   • gosec                 (Go security)
#   • actionlint            (GitHub Actions linting)
#   • python3 + pip
#   • detect-secrets        (secret scanning)
#   • pre-commit            (Git hooks)
#   • yamllint              (YAML linting)
#   • markdownlint          (Markdown linting)
#
# Expected duration:
#   ~2–4 minutes (depending on network speed)
#
# Tool install chain (7 phases):
#   ┌───┬───────────────────────────────────────┐
#   │ #  │ Phase                                       │
#   ├───┼───────────────────────────────────────┤
#   │ 1  │ apt update                                  │
#   │ 2  │ Basic tools (via apt)                       │
#   │ 3  │ Shell tools (shellcheck, shfmt)             │
#   │ 4  │ Go tools (golangci-lint, staticcheck, ...)  │
#   │ 5  │ Python tools (pip, pre-commit, yamllint,..) │
#   │ 6  │ Android NDK check (optional)                │
#   │ 7  │ Project setup (permissions, pre-commit)     │
#   └───┴───────────────────────────────────────┘
#
#   Each phase prints a header (─────) so the log is scannable.
#   Every tool install is wrapped in a `command -v` check, so
#   re-running the script only installs what is missing.
#
# golangci-lint v2 — path note:
#   golangci-lint changed its module path between v1 and v2:
#     • v1:  github.com/golangci/golangci-lint/cmd/golangci-lint
#     • v2:  github.com/golangci/golangci-lint/v2/cmd/golangci-lint
#
#   This script installs v2 (the current major), using the v2
#   module path. The install flow is:
#     1. Detect existing golangci-lint.
#     2. If version starts with "v2.", keep it.
#     3. Otherwise remove the old binary and reinstall.
#     4. Install via `go install .../v2/cmd/...@v2.5.0`.
#     5. Fallback to install.sh from the v2 branch if go install
#        fails (e.g. proxy issues on CI).
#     6. Symlink into /usr/local/bin for compatibility.
#
#   The version check uses `grep -qE '^v?2\.'` on the output of
#   `golangci-lint --version` — the v2 release line prints a
#   leading "v2." (with the "v" prefix). This is deliberate: it
#   rejects both v1 (e.g. "1.55.0") and unversioned builds.
#
# Idempotency behavior:
#   The script is safe to run multiple times. For each tool:
#     • If already installed at the correct version → skip.
#     • If installed at a wrong/old version → reinstall.
#     • If not installed → install.
#     • If install fails → warn and continue (except golangci-lint,
#       which is considered critical — but even then, a warning is
#       logged and the script continues to the final verification).
#
#   The script does NOT fail the devcontainer on individual tool
#   failures. A partial toolchain is still usable — the missing
#   tool will show as ✗ in the final table, and the developer can
#   re-run `bash .devcontainer/setup.sh` after fixing the network.
#
# v1.1.0 additions:
#   • Version bumped to v1.1.0 (documentation only — no behavior
#     changes since v1.0.0).
#   • Added a "Tool install chain" table summarizing the 7 phases.
#   • Added a "golangci-lint v2 — path note" section explaining
#     the module path change between v1 and v2, the version check
#     regex, and the fallback install path.
#   • Added an "Idempotency behavior" section documenting what
#     happens when the script is re-run with partial state.
#   • Confirmed all log messages and comments are English.
# ============================================================

set -euo pipefail

# ============================================================
# [1] Colors
# ============================================================
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

log_step()  { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
log_error() { echo -e "  ${RED}✗${NC} $1"; }
log_info()  { echo -e "  ${DIM}·${NC} $1"; }

# ============================================================
# [2] Header
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  🔧 DNSCrypt Smart Filter – DevContainer Setup           ║${NC}"
echo -e "${BOLD}║  ${DIM}v1.1.0${NC}                                                 ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════${NC}${BOLD}╝${NC}"
echo ""

# ============================================================
# [3] User and path detection
# ============================================================
CURRENT_USER="$(whoami)"
WORKSPACE_DIR="$(pwd)"

log_info "User: $CURRENT_USER"
log_info "Workspace: $WORKSPACE_DIR"
log_info "Sudo: $([ "$(id -u)" -eq 0 ] && echo "N/A (root)" || echo "available")"

# Do we need sudo?
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ============================================================
# [4] Update packages
# ============================================================
log_step "[1/7] Updating package lists"

$SUDO apt-get update -qq
log_ok "Package lists updated"

# ============================================================
# [5] Basic tools
# ============================================================
log_step "[2/7] Basic tools"

BASIC_PACKAGES=(
    ca-certificates
    curl
    wget
    git
    make
    jq
    zip
    unzip
    file
    python3
    python3-pip
    python3-venv
)

$SUDO apt-get install -y --no-install-recommends "${BASIC_PACKAGES[@]}" >/dev/null
log_ok "Basics: ${BASIC_PACKAGES[*]}"

# ============================================================
# [6] Shell tools
# ============================================================
log_step "[3/7] Shell tools"

# --- shellcheck ---
if ! command -v shellcheck >/dev/null 2>&1; then
    $SUDO apt-get install -y --no-install-recommends shellcheck >/dev/null
fi
if command -v shellcheck >/dev/null 2>&1; then
    log_ok "shellcheck $(shellcheck --version 2>/dev/null | awk '/version:/ {print $2}')"
else
    log_warn "shellcheck not installed"
fi

# --- shfmt ---
if ! command -v shfmt >/dev/null 2>&1; then
    SHFMT_VERSION="3.8.0"
    SHFMT_ARCH="linux_amd64"
    case "$(uname -m)" in
        aarch64|arm64) SHFMT_ARCH="linux_arm64" ;;
        armv7l|armv6l) SHFMT_ARCH="linux_arm" ;;
        x86_64)        SHFMT_ARCH="linux_amd64" ;;
    esac

    SHFMT_URL="https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_${SHFMT_ARCH}"
    log_info "Downloading shfmt v${SHFMT_VERSION} (${SHFMT_ARCH})..."

    if curl -fsSL "$SHFMT_URL" -o /tmp/shfmt 2>/dev/null; then
        $SUDO install -m 0755 /tmp/shfmt /usr/local/bin/shfmt
        rm -f /tmp/shfmt
    else
        log_warn "Failed to download shfmt"
    fi
fi
if command -v shfmt >/dev/null 2>&1; then
    log_ok "shfmt $(shfmt --version 2>/dev/null)"
else
    log_warn "shfmt not installed"
fi

# ============================================================
# [7] Go tools
# ============================================================
log_step "[4/7] Go tools"

# Check Go
if ! command -v go >/dev/null 2>&1; then
    log_error "Go is not installed — it should come from the devcontainer feature"
    exit 1
fi
log_ok "Go $(go version | awk '{print $3}')"

# GOBIN setup
export GOPATH="${GOPATH:-$HOME/go}"
export GOBIN="${GOPATH}/bin"
mkdir -p "$GOBIN"

# Ensure GOBIN is on PATH
if ! echo "$PATH" | grep -q "$GOBIN"; then
    export PATH="$GOBIN:$PATH"
    # Add to .bashrc as well
    if ! grep -q "GOBIN\|/go/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Go binaries" >> "$HOME/.bashrc"
        echo "export PATH=\"\$HOME/go/bin:\$PATH\"" >> "$HOME/.bashrc"
    fi
fi

# --- golangci-lint (v2.5.0) ---
#
# See the "golangci-lint v2 — path note" in the header for the
# rationale behind the version check regex and the v2 module
# path. Do not downgrade to v1 without updating the check regex.
# ============================================================
GOLANGCI_VERSION="v2.5.0"
GOLANGCI_INSTALLED=0

# 1. Check current version
if command -v golangci-lint >/dev/null 2>&1; then
    CURRENT_GOLANGCI=$(golangci-lint --version 2>/dev/null | head -1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    if echo "$CURRENT_GOLANGCI" | grep -qE '^v?2\.'; then
        log_ok "golangci-lint $(golangci-lint --version 2>/dev/null | head -1)"
        GOLANGCI_INSTALLED=1
    else
        log_info "golangci-lint is outdated ($CURRENT_GOLANGCI) — will update to $GOLANGCI_VERSION"
    fi
fi

# 2. Install if needed
if [ "$GOLANGCI_INSTALLED" = "0" ]; then
    log_info "Installing golangci-lint ${GOLANGCI_VERSION}..."

    # Remove the old version first
    if command -v golangci-lint >/dev/null 2>&1; then
        OLD_PATH=$(command -v golangci-lint)
        log_info "Removing old version from: $OLD_PATH"
        $SUDO rm -f "$OLD_PATH" 2>/dev/null || rm -f "$OLD_PATH" 2>/dev/null || true
    fi

    # Install via go install (v2 path)
    if go install "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCI_VERSION}" 2>/dev/null; then
        # Ensure GOBIN is on PATH
        if [ -x "$GOBIN/golangci-lint" ]; then
            log_ok "golangci-lint installed at $GOBIN/golangci-lint"
            # Symlink into /usr/local/bin (optional — for compatibility)
            $SUDO ln -sf "$GOBIN/golangci-lint" /usr/local/bin/golangci-lint 2>/dev/null || true
            export PATH="$GOBIN:$PATH"
            GOLANGCI_INSTALLED=1
        fi
    else
        log_warn "Failed to install golangci-lint v2.5.0 via go install"
        log_info "Trying install.sh..."

        # Fallback: install.sh with v2 path
        if curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/v2/master/install.sh" | \
            $SUDO sh -s -- -b /usr/local/bin "$GOLANGCI_VERSION" 2>/dev/null; then
            GOLANGCI_INSTALLED=1
        fi
    fi
fi

# 3. Final verification
if command -v golangci-lint >/dev/null 2>&1; then
    GOLANGCI_VER=$(golangci-lint --version 2>/dev/null | head -1)
    if echo "$GOLANGCI_VER" | grep -qE 'v?2\.'; then
        log_ok "golangci-lint $GOLANGCI_VER ✅"
    else
        log_warn "golangci-lint $GOLANGCI_VER ⚠️ (needs v2.x)"
    fi
else
    log_error "❌ golangci-lint not installed"
fi

# --- staticcheck ---
if ! command -v staticcheck >/dev/null 2>&1; then
    log_info "Installing staticcheck..."
    if ! go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null; then
        log_warn "Failed to install staticcheck"
    fi
fi
if command -v staticcheck >/dev/null 2>&1; then
    log_ok "staticcheck $(staticcheck --version 2>/dev/null | head -1)"
else
    log_warn "staticcheck not installed (non-critical)"
fi

# --- gosec (optional) ---
if ! command -v gosec >/dev/null 2>&1; then
    log_info "Installing gosec (optional)..."
    go install github.com/securego/gosec/v2/cmd/gosec@latest 2>/dev/null || true
fi
if command -v gosec >/dev/null 2>&1; then
    log_ok "gosec $(gosec --version 2>/dev/null | head -1)"
else
    log_info "gosec not installed (optional)"
fi

# --- actionlint ---
if ! command -v actionlint >/dev/null 2>&1; then
    log_info "Installing actionlint (GitHub Actions linting)..."
    go install github.com/rhysd/actionlint/cmd/actionlint@latest 2>/dev/null || true
fi
if command -v actionlint >/dev/null 2>&1; then
    log_ok "actionlint $(actionlint --version 2>/dev/null | head -1)"
else
    log_info "actionlint not installed (optional)"
fi

# ============================================================
# [8] Python tools
# ============================================================
log_step "[5/7] Python tools"

# pip upgrade
python3 -m pip install --quiet --upgrade pip 2>/dev/null || true
log_ok "pip $(python3 -m pip --version 2>/dev/null | awk '{print $2}')"

# --- pre-commit ---
if ! command -v pre-commit >/dev/null 2>&1; then
    log_info "Installing pre-commit..."
    python3 -m pip install --quiet pre-commit 2>/dev/null || \
        python3 -m pip install --quiet --user pre-commit 2>/dev/null || \
        log_warn "Failed to install pre-commit"
fi
if command -v pre-commit >/dev/null 2>&1; then
    log_ok "pre-commit $(pre-commit --version 2>/dev/null | awk '{print $2}')"
else
    log_warn "pre-commit not installed"
fi

# --- detect-secrets ---
if ! command -v detect-secrets >/dev/null 2>&1; then
    log_info "Installing detect-secrets..."
    python3 -m pip install --quiet detect-secrets==1.5.0 2>/dev/null || \
        python3 -m pip install --quiet --user detect-secrets==1.5.0 2>/dev/null || \
        log_warn "Failed to install detect-secrets"
fi
if command -v detect-secrets >/dev/null 2>&1; then
    log_ok "detect-secrets $(detect-secrets --version 2>/dev/null || echo 'unknown')"
else
    log_warn "detect-secrets not installed"
fi

# --- PyYAML ---
if ! python3 -c "import yaml" 2>/dev/null; then
    python3 -m pip install --quiet pyyaml 2>/dev/null || true
fi
if python3 -c "import yaml" 2>/dev/null; then
    log_ok "PyYAML available"
else
    log_info "PyYAML not installed (optional)"
fi

# --- yamllint ---
if ! command -v yamllint >/dev/null 2>&1; then
    log_info "Installing yamllint..."
    python3 -m pip install --quiet yamllint 2>/dev/null || \
        python3 -m pip install --quiet --user yamllint 2>/dev/null || \
        log_warn "Failed to install yamllint"
fi
if command -v yamllint >/dev/null 2>&1; then
    log_ok "yamllint $(yamllint --version 2>/dev/null | awk '{print $NF}')"
else
    log_info "yamllint not installed (optional)"
fi

# --- markdownlint ---
# Note: requires Node.js — may not be present in the DevContainer
if ! command -v markdownlint >/dev/null 2>&1 && ! command -v markdownlint-cli >/dev/null 2>&1; then
    if command -v npm >/dev/null 2>&1; then
        log_info "Installing markdownlint-cli (npm)..."
        $SUDO npm install -g markdownlint-cli 2>/dev/null || \
            log_warn "Failed to install markdownlint"
    else
        log_info "markdownlint not installed (requires npm)"
    fi
fi
if command -v markdownlint >/dev/null 2>&1; then
    log_ok "markdownlint $(markdownlint --version 2>/dev/null || echo 'installed')"
elif command -v markdownlint-cli >/dev/null 2>&1; then
    log_ok "markdownlint-cli $(markdownlint-cli --version 2>/dev/null || echo 'installed')"
else
    log_info "markdownlint not installed (optional)"
fi

# ============================================================
# [9] Android NDK (optional)
# ============================================================
log_step "[6/7] Android NDK (optional)"

NDK_FOUND=0
for var in ANDROID_NDK_HOME ANDROID_NDK_ROOT NDK NDK_ROOT; do
    val="${!var:-}"
    if [ -n "$val" ] && [ -d "$val/toolchains/llvm" ]; then
        log_ok "$var = $val"
        NDK_FOUND=1
    fi
done

if [ "$NDK_FOUND" = "0" ]; then
    log_info "NDK not found — build will use CGO_ENABLED=0"
    log_info "To install the NDK: https://developer.android.com/ndk/downloads"
fi

# ============================================================
# [10] Project setup
# ============================================================
log_step "[7/7] Project setup"

# --- Executable permissions ---
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 2>/dev/null || true
    log_ok "scripts/*.sh — executable"
fi

if [ -d "proxy" ]; then
    for f in build.sh customize.sh service.sh post-fs-data.sh \
             action.sh status.sh uninstall.sh functions.sh watchdog.sh; do
        [ -f "proxy/$f" ] && chmod +x "proxy/$f" 2>/dev/null || true
    done
    log_ok "proxy/*.sh — executable"
fi

if [ -d ".devcontainer" ]; then
    [ -f ".devcontainer/setup.sh" ] && chmod +x .devcontainer/setup.sh 2>/dev/null || true
fi

# --- go mod download ---
if [ -f "proxy/go.mod" ]; then
    (cd proxy && go mod download 2>/dev/null) || true
    log_ok "go mod download"
fi

# --- pre-commit install ---
if command -v pre-commit >/dev/null 2>&1 && [ -f ".pre-commit-config.yaml" ]; then
    if pre-commit install --install-hooks 2>/dev/null; then
        log_ok "pre-commit hooks installed"
    else
        log_warn "Failed to install pre-commit hooks (may need to run manually)"
    fi
fi

# ============================================================
# [11] Final check
# ============================================================
log_step "Final check"

echo ""
echo -e "${BOLD}Installed tools:${NC}"
echo ""

# Table
print_tool() {
    local name="$1"
    local cmd="$2"
    local version_cmd="$3"
    local version=""

    if command -v "$cmd" >/dev/null 2>&1; then
        version=$(eval "$version_cmd" 2>/dev/null | head -1 | tr -d '\r\n' || echo "installed")
        printf "  ${GREEN}✓${NC} %-18s ${DIM}%s${NC}\n" "$name" "$version"
    else
        printf "  ${RED}✗${NC} %-18s ${DIM}(not installed)${NC}\n" "$name"
    fi
}

print_tool "Go"           "go"           "go version | awk '{print \$3}'"
print_tool "make"         "make"         "make --version | head -1"
print_tool "git"          "git"          "git --version | awk '{print \$3}'"
print_tool "curl"         "curl"         "curl --version | head -1 | awk '{print \$2}'"
print_tool "jq"           "jq"           "jq --version"
print_tool "shellcheck"   "shellcheck"   "shellcheck --version | awk '/version:/ {print \$2}'"
print_tool "shfmt"        "shfmt"        "shfmt --version"
print_tool "golangci-lint" "golangci-lint" "golangci-lint --version | head -1"
print_tool "staticcheck"  "staticcheck"  "staticcheck --version | head -1"
print_tool "gosec"        "gosec"        "gosec --version | head -1"
print_tool "actionlint"   "actionlint"   "actionlint --version | head -1"
print_tool "pre-commit"   "pre-commit"   "pre-commit --version | awk '{print \$2}'"
print_tool "detect-secrets" "detect-secrets" "detect-secrets --version | head -1"
print_tool "yamllint"     "yamllint"     "yamllint --version | awk '{print \$NF}'"
print_tool "python3"      "python3"      "python3 --version | awk '{print \$2}'"

echo ""
echo -e "${BOLD}Project checks:${NC}"
echo ""

# VERSION
if [ -f "VERSION" ]; then
    printf "  ${GREEN}✓${NC} %-25s ${DIM}%s${NC}\n" "VERSION" "$(cat VERSION)"
else
    printf "  ${RED}✗${NC} %-25s ${DIM}(missing)${NC}\n" "VERSION"
fi

# proxy/go.mod
if [ -f "proxy/go.mod" ]; then
    printf "  ${GREEN}✓${NC} %-25s ${DIM}%s${NC}\n" "proxy/go.mod" "$(grep '^module' proxy/go.mod | awk '{print $2}')"
else
    printf "  ${RED}✗${NC} %-25s ${DIM}(missing)${NC}\n" "proxy/go.mod"
fi

# main.go
if [ -f "proxy/main.go" ]; then
    printf "  ${GREEN}✓${NC} %-25s ${DIM}%d KB${NC}\n" "proxy/main.go" "$(( $(wc -c < proxy/main.go) / 1024 ))"
else
    printf "  ${RED}✗${NC} %-25s ${DIM}(missing)${NC}\n" "proxy/main.go"
fi

# scripts/
if [ -d "scripts" ]; then
    count=$(find scripts -name "*.sh" -type f 2>/dev/null | wc -l)
    printf "  ${GREEN}✓${NC} %-25s ${DIM}%d file(s)${NC}\n" "scripts/*.sh" "$count"
else
    printf "  ${RED}✗${NC} %-25s ${DIM}(missing)${NC}\n" "scripts/"
fi

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}✅ DevContainer Setup complete${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo -e "  ${CYAN}1.${NC} Build the project:"
echo -e "     ${DIM}make build${NC}"
echo ""
echo -e "  ${CYAN}2.${NC} Package the module:"
echo -e "     ${DIM}make package${NC}"
echo ""
echo -e "  ${CYAN}3.${NC} Available tools:"
echo -e "     ${DIM}make help${NC}     ${DIM}# list of all targets${NC}"
echo -e "     ${DIM}make version${NC}  ${DIM}# show current version${NC}"
echo ""
echo -e "  ${CYAN}4.${NC} pre-commit hooks are active — every commit is checked automatically"
echo ""

exit 0