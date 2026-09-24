# ============================================================
# DNSCrypt Smart Filter – Makefile
# Version: v1.0.0
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Unified commands for building, packaging, and releasing the
#   module.
#
#   The VERSION variable is read dynamically from the VERSION file
#   (Single Source of Truth). No version is hardcoded here.
#
# Targets:
#   make all               - Alias for `make build`
#   make help              - Show available targets + current version
#   make version           - Print the current version
#   make build             - Build all 4 architectures
#   make package           - Build all 4 architectures (same as build)
#   make clean             - Remove proxy/build/ and dist/
#
# Release targets (see docs/RELEASE_PROCESS.md):
#   make release VERSION=vX.Y.Z         - Stable release (from develop)
#   make release-patch VERSION=vX.Y.Z   - PATCH release (from main)
#   make sync                           - Sync develop with main
#
# Branching model:
#   See docs/BRANCHING.md for the full strategy.
# ============================================================

SHELL := /usr/bin/env bash
VERSION := $(shell cat VERSION 2>/dev/null || echo "unknown")
PROXY_DIR := $(shell pwd)/proxy
DIST_DIR := $(shell pwd)/dist

.PHONY: all help version build package clean release release-patch sync

all: build

# ============================================================
# Help
# ============================================================
help:
	@echo "DNSCrypt Smart Filter"
	@echo ""
	@echo "  VERSION: $(VERSION)"
	@echo ""
	@echo "  Build:"
	@echo "    make build                          - Build all architectures"
	@echo "    make package                        - Build + ZIP"
	@echo "    make clean                          - Clean outputs"
	@echo "    make version                        - Show current version"
	@echo ""
	@echo "  Release (see docs/RELEASE_PROCESS.md):"
	@echo "    make release VERSION=vX.Y.Z         - Stable release (from develop)"
	@echo "    make release-patch VERSION=vX.Y.Z   - PATCH release (from main)"
	@echo "    make sync                           - Sync develop with main"
	@echo ""
	@echo "  Docs:"
	@echo "    docs/BRANCHING.md                   - Git branching strategy"
	@echo "    docs/RELEASE_PROCESS.md             - Release step-by-step"

# ============================================================
# Version
# ============================================================
version:
	@echo "$(VERSION)"

# ============================================================
# Build
# ============================================================
build:
	@echo "Building $(VERSION)..."
	@cd "$(PROXY_DIR)" && ./build.sh --clean --parallel

# ============================================================
# Package
# ============================================================
package:
	@echo "Packaging $(VERSION)..."
	@cd "$(PROXY_DIR)" && ./build.sh --clean --parallel

# ============================================================
# Clean
# ============================================================
clean:
	@rm -rf "$(PROXY_DIR)/build" "$(DIST_DIR)"
	@echo "Cleaned"

# ============================================================
# Release (stable — MINOR / MAJOR)
# ============================================================
# Usage:
#   make release VERSION=v1.1.0
#
# Workflow:
#   • Should be run from `develop` (or a release/* branch)
#   • Updates VERSION + module.prop + update.json
#   • Creates commit + signed tag
#   • Pushes to origin
#   • GitHub Actions publishes the release automatically
#
# See: docs/RELEASE_PROCESS.md
#      docs/adr/0002-automated-releases.md
# ============================================================
release:
	@if [ "$(origin VERSION)" != "command line" ]; then \
		echo "❌ No version specified."; \
		echo ""; \
		echo "   Usage: make release VERSION=v1.1.0"; \
		echo "   Current file VERSION: $(VERSION)"; \
		echo ""; \
		echo "   See docs/RELEASE_PROCESS.md for details."; \
		exit 1; \
	fi
	@echo ""
	@echo "🚀 Preparing stable release: $(VERSION)"
	@echo ""
	@./scripts/release.sh $(VERSION)

# ============================================================
# Release-Patch (PATCH only — emergency)
# ============================================================
# Usage:
#   make release-patch VERSION=v1.0.1
#
# Workflow:
#   • MUST be run from `main` branch
#   • Only PATCH bump allowed (MAJOR/MINOR rejected)
#   • Delegates to scripts/release-patch.sh, which wraps
#     scripts/release.sh with 3 extra safety rules
#   • After the release: run `make sync` to back-merge
#     main → develop
#
# See: docs/BRANCHING.md §8
#      docs/adr/0006-rename-hotfix-to-release-patch.md
# ============================================================
release-patch:
	@if [ "$(origin VERSION)" != "command line" ]; then \
		echo "❌ No version specified."; \
		echo ""; \
		echo "   Usage: make release-patch VERSION=v1.0.1"; \
		echo "   Current file VERSION: $(VERSION)"; \
		echo ""; \
		echo "   See docs/BRANCHING.md §8 for details."; \
		exit 1; \
	fi
	@echo ""
	@echo "🔧 Preparing PATCH release: $(VERSION)"
	@echo ""
	@echo "⚠️  Ensure you are on the 'main' branch."
	@echo "   Verify with: git branch --show-current"
	@echo ""
	@echo "   After the release is published, run:"
	@echo "     make sync"
	@echo ""
	@./scripts/release-patch.sh $(VERSION)

# ============================================================
# Sync develop with main
# ============================================================
# Usage:
#   make sync
#
# Purpose:
#   • After a PATCH release lands on main, sync develop with main.
#   • Regular releases are synced automatically by
#     .github/workflows/release.yml — manual sync is only
#     needed for PATCH releases (release-patch.sh).
#
# Effect:
#   • Fetches latest main + develop
#   • Fast-forward merges main → develop (or regular merge)
#   • Pushes develop to origin
#
# See: docs/BRANCHING.md §8.4
#      docs/adr/0003-post-release-sync.md
# ============================================================
sync:
	@echo ""
	@echo "🔄 Syncing develop with main..."
	@echo ""
	@git checkout develop
	@git pull origin develop
	@git fetch origin main
	@if git merge origin/main --ff-only --no-edit 2>/dev/null; then \
		echo "   ✓ Fast-forward merge succeeded"; \
	else \
		echo "   → Fast-forward not possible, using regular merge"; \
		git merge origin/main --no-edit \
			-m "chore: sync develop with main"; \
	fi
	@git push origin develop
	@echo ""
	@echo "✅ develop is now in sync with main"
	@echo ""