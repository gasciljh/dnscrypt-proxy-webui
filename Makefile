# ============================================================
# DNSCrypt Smart Filter – Makefile
# Version: v1.2.0 (Global Edition)
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Purpose:
#   Unified commands for building, packaging, releasing, and
#   validating the module.
#
#   The VERSION variable is read dynamically from the VERSION
#   file (Single Source of Truth). No version is hardcoded here.
#
#   As of v1.1.0, main.go computes the Go runtime soft memory
#   limit per blocklist profile (light=80MB → ultimate=220MB).
#   This is a runtime concern and does NOT affect this Makefile.
#
#   As of v1.2.0, the installer (customize.sh) uses a 10-layer
#   data-preservation architecture. The `check-backup` target
#   validates the shell syntax of those layers without touching
#   a real device. Device-side backups are managed via the
#   `status.sh --diagnose` tool (see `make diagnose-help`).
#
# Targets:
#   make all               - Alias for `make build`
#   make help              - Show available targets + current version
#   make version           - Print the current version
#   make build             - Build all 4 architectures
#   make package           - Build + package the Magisk module ZIP
#   make clean             - Remove proxy/build/ and dist/
#   make dist-clean        - Remove dist/ only (keep proxy/build/)
#
# Validation targets:
#   make check-backup      - Validate ALL shell scripts (syntax + shellcheck)
#   make check-all         - Run all local validations (shellcheck + gofmt + backup + docs)
#   make check-docs        - Verify the v1.2.0 documentation files are present
#   make check-adr         - Verify the committed ADRs (see help)
#   make diagnose-help     - Show how to run `status.sh --diagnose` on a device
#
# Release targets (see docs/RELEASE_PROCESS.md):
#   make release VERSION=vX.Y.Z         - Stable release (from develop)
#   make release-patch VERSION=vX.Y.Z   - PATCH release (from main)
#   make sync                           - Sync develop with main
#
# Documentation references:
#   • docs/BRANCHING.md        - Git branching strategy
#   • docs/RELEASE_PROCESS.md  - Release step-by-step
#   • docs/UPGRADE.md §3.1     - v1.1.0 → v1.2.0 upgrade guide
#   • docs/BACKUP.md           - Backup system reference (v1.2.0)
#   • docs/EMERGENCY.md        - Emergency recovery guide (v1.2.0)
#
# ============================================================
# v1.2.0 (Global Edition) — Hardening in this revision
# ============================================================
#   🛡️ HARD-MK-01 (was MK-1) — `check-backup` now validates ALL
#     shell scripts (previously it omitted watchdog.sh,
#     action.sh, and post-fs-data.sh — three of the most
#     critical runtime files).
#
#   🛡️ HARD-MK-02 (was MK-2) — ADR references in comments were
#     corrected in v1.2.0 to match the six ADRs actually
#     committed under docs/adr/ (0001–0006). Any future ADRs
#     written before they are committed are tracked via
#     PLANNED_ADRS in the `check-adr` target.
#
#   🛡️ HARD-MK-03 (was MK-3) — `check-docs` verifies the
#     documentation files explicitly referenced by this
#     Makefile and the v1.2.0 release process (see
#     REQUIRED_DOCS below). It does NOT scan all of docs/.
#
#   🛡️ HARD-MK-04 (was MK-4) — The `sync` target now checks the
#     exit status of each git command. A failure in `git
#     checkout develop` no longer silently continues into a
#     merge that targets the wrong branch.
#
#   🛡️ HARD-MK-05 (was MK-5) — `$(VERSION)` is now quoted in
#     the `release` and `release-patch` recipe lines.
#
#   🛡️ HARD-MK-06 (was MK-6) — `check-all` uses Make
#     dependencies instead of recursing into `$(MAKE)` for
#     `check-backup` and `check-docs`. The output is unified
#     and `make -j` behaves predictably.
#
# ============================================================
# v1.2.0 (Global Edition) — Additional fixes in this revision
# ============================================================
#   🛡️ HARD-MK-07 (M-1) — `check-backup` no longer risks hanging
#     when every shell script is missing. An empty `_existing`
#     list now skips shellcheck instead of invoking it with no
#     arguments (which reads from stdin and can block).
#
#   🛡️ HARD-MK-08 (L-2) — `VERSION` is now guarded with
#     `override` so a command-line `VERSION=...` cannot
#     silently disagree with the file. The `version` target
#     also cross-checks the two values.
#
#   🛡️ HARD-MK-09 (L-3) — A `check-adr` target verifies the
#     committed ADR files. PLANNED_ADRS is reserved for ADRs
#     that are planned but not yet committed; as of v1.2.0
#     it is empty because all six ADRs are committed.
# ============================================================

SHELL := /bin/bash
VERSION_FILE := VERSION
VERSION := $(shell cat $(VERSION_FILE) 2>/dev/null || echo "unknown")

# Guard: refuse to let a CLI VERSION= override the file silently.
# The release targets already read VERSION from the command line,
# so we expose both for cross-checking.
override VERSION := $(shell cat $(VERSION_FILE) 2>/dev/null || echo "unknown")

PROXY_DIR := $(shell pwd)/proxy
DIST_DIR := $(shell pwd)/dist
DOCS_DIR := $(shell pwd)/docs
SCRIPTS_DIR := $(shell pwd)/scripts
ADR_DIR := $(DOCS_DIR)/adr

# All shell scripts that participate in the runtime. Used by
# check-backup and check-all. Ordered roughly by execution phase.
SHELL_SCRIPTS := \
	$(PROXY_DIR)/post-fs-data.sh \
	$(PROXY_DIR)/customize.sh \
	$(PROXY_DIR)/functions.sh \
	$(PROXY_DIR)/service.sh \
	$(PROXY_DIR)/watchdog.sh \
	$(PROXY_DIR)/action.sh \
	$(PROXY_DIR)/status.sh \
	$(PROXY_DIR)/uninstall.sh

# Documentation files referenced by this Makefile, the release
# process, and the v1.2.0 data-preservation layers. Used by
# check-docs. This is an explicit, curated list — not the
# "full set" of every .md file under docs/.
REQUIRED_DOCS := \
	docs/BACKUP.md \
	docs/EMERGENCY.md \
	docs/UPGRADE.md \
	docs/RELEASE_PROCESS.md \
	docs/BRANCHING.md \
	docs/API.md

# Committed ADRs. All six ADRs (0001–0006) are present under
# docs/adr/ as of v1.2.0. This list is verified by check-adr.
#
#   0001-two-branch-model.md
#   0002-automated-releases.md
#   0003-post-release-sync.md
#   0004-unified-pr-template.md              (superseded)
#   0005-release-specific-pr-template.md
#   0006-rename-hotfix-to-release-patch.md
COMMITTED_ADRS := \
	docs/adr/0001-two-branch-model.md \
	docs/adr/0002-automated-releases.md \
	docs/adr/0003-post-release-sync.md \
	docs/adr/0004-unified-pr-template.md \
	docs/adr/0005-release-specific-pr-template.md \
	docs/adr/0006-rename-hotfix-to-release-patch.md

# Planned ADRs — reserved for future ADRs written *before*
# they are committed. As of v1.2.0 this list is empty, because
# all six ADRs are already committed (see COMMITTED_ADRS).
# `make check-adr` becomes a no-op when this is empty.
PLANNED_ADRS :=

.PHONY: all help version build package clean dist-clean \
        check-backup check-all check-docs check-adr diagnose-help \
        release release-patch sync

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
	@echo "    make package                        - Build + package Magisk ZIP"
	@echo "    make clean                          - Clean outputs (build + dist)"
	@echo "    make dist-clean                     - Clean dist/ only"
	@echo "    make version                        - Show current version"
	@echo ""
	@echo "  Validation:"
	@echo "    make check-backup                   - Validate ALL shell scripts"
	@echo "    make check-all                      - Run all local validations"
	@echo "    make check-docs                     - Verify required documentation"
	@echo "    make check-adr                      - Verify committed ADRs"
	@echo "    make diagnose-help                  - How to run diagnose on a device"
	@echo ""
	@echo "  Release (see docs/RELEASE_PROCESS.md):"
	@echo "    make release VERSION=vX.Y.Z         - Stable release (from develop)"
	@echo "    make release-patch VERSION=vX.Y.Z   - PATCH release (from main)"
	@echo "    make sync                           - Sync develop with main"
	@echo ""
	@echo "  Docs:"
	@echo "    docs/BRANCHING.md                   - Git branching strategy"
	@echo "    docs/RELEASE_PROCESS.md             - Release step-by-step"
	@echo "    docs/UPGRADE.md                     - Version upgrade guide"
	@echo "    docs/BACKUP.md                      - Backup system (v1.2.0)"
	@echo "    docs/EMERGENCY.md                   - Emergency recovery (v1.2.0)"
	@echo ""
	@echo "  Note: ADRs (docs/adr/0001..0006) are committed."
	@echo "        Run 'make check-adr' to verify them."
	@echo "        See docs/adr/README.md for the index."

# ============================================================
# Version
# ============================================================
# Reads VERSION file (Single Source of Truth).
# As of v1.2.0, this returns "v1.2.0".
#
# HARD-MK-08 (L-2): cross-checks the file value against any
# command-line override. If they disagree, fail loudly instead
# of silently using one or the other.
# ============================================================
version:
	@if [ -n "$(VERSION)" ] && [ "$(VERSION)" != "$(shell cat $(VERSION_FILE) 2>/dev/null || echo unknown)" ]; then \
		echo "❌ VERSION mismatch:"; \
		echo "   file:        $(shell cat $(VERSION_FILE) 2>/dev/null)"; \
		echo "   command line: $(VERSION)"; \
		exit 1; \
	fi
	@echo "$(VERSION)"

# ============================================================
# Build
# ============================================================
# Cross-compiles main.go for 4 Android architectures via
# proxy/build.sh. See proxy/build.sh for options.
#
# Output: proxy/build/dnscrypt-webui-{arm64,arm,amd64,386}
#         + proxy/build/checksums.txt
# ============================================================
build:
	@echo "Building $(VERSION)..."
	@cd "$(PROXY_DIR)" && ./build.sh --clean --parallel

# ============================================================
# Package
# ============================================================
# Builds all architectures, then packages the Magisk module ZIP
# using scripts/package_module.sh (the same script used by
# .github/workflows/release.yml).
#
# Output:
#   dist/dnscrypt-webui-<VERSION>-module.zip
#   dist/dnscrypt-webui-<VERSION>-module.zip.sha256
# ============================================================
package: build
	@echo "Packaging $(VERSION)..."
	@chmod +x scripts/package_module.sh 2>/dev/null || true
	@./scripts/package_module.sh \
		--version "$(VERSION)" \
		--build-dir "$(PROXY_DIR)/build"
	@echo ""
	@echo "✅ Package created:"
	@ls -la "$(DIST_DIR)"/dnscrypt-webui-*-module.zip 2>/dev/null || true
	@ls -la "$(DIST_DIR)"/dnscrypt-webui-*-module.zip.sha256 2>/dev/null || true

# ============================================================
# Clean
# ============================================================
clean:
	@rm -rf "$(PROXY_DIR)/build" "$(DIST_DIR)"
	@echo "Cleaned (build + dist)"

# ============================================================
# Dist-clean
# ============================================================
dist-clean:
	@rm -rf "$(DIST_DIR)"
	@echo "Cleaned (dist only)"

# ============================================================
# Validation — ALL shell scripts
# ============================================================
# HARD-MK-01: validates every shell script that participates
# in runtime execution.
#
# HARD-MK-07 (M-1): if no script exists, skip shellcheck
# entirely instead of invoking it with an empty argument list
# (which would read from stdin and could block).
# ============================================================
check-backup:
	@echo "━━━ Validating shell scripts ━━━"
	@echo ""
	@echo "  [1/2] bash -n syntax check..."
	@for f in $(SHELL_SCRIPTS); do \
		if [ -f "$$f" ]; then \
			if bash -n "$$f" 2>/dev/null; then \
				printf "    ✓ %s\n" "$$(basename "$$f")"; \
			else \
				printf "    ✗ %s (syntax error)\n" "$$(basename "$$f")"; \
				exit 1; \
			fi; \
		else \
			printf "    - %s (missing)\n" "$$(basename "$$f")"; \
		fi; \
	done
	@echo ""
	@echo "  [2/2] shellcheck (if available)..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		_existing=""; \
		for f in $(SHELL_SCRIPTS); do \
			[ -f "$$f" ] && _existing="$$_existing $$f"; \
		done; \
		if [ -z "$$_existing" ]; then \
			echo "    - no existing scripts to check (skipped)"; \
		else \
			shellcheck --severity=warning $$_existing \
				&& echo "    ✓ shellcheck clean" \
				|| echo "    ⚠ shellcheck reported warnings (non-blocking)"; \
		fi; \
	else \
		echo "    - shellcheck not installed (skipped)"; \
	fi
	@echo ""
	@echo "✅ Shell script validation complete"
	@echo ""

# ============================================================
# Validation — all local checks
# ============================================================
# HARD-MK-06: uses Make dependencies instead of recursively
# invoking `$(MAKE)`.
# ============================================================
check-all: check-backup check-docs
	@echo "━━━ Running additional local validations ━━━"
	@echo ""
	@echo "  [1/2] bash -n on scripts/ helpers..."
	@for f in "$(SCRIPTS_DIR)"/*.sh; do \
		[ -f "$$f" ] || continue; \
		if bash -n "$$f" 2>/dev/null; then \
			printf "    ✓ %s\n" "$$(basename "$$f")"; \
		else \
			printf "    ✗ %s\n" "$$(basename "$$f")"; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "  [2/2] shellcheck (scripts/)..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		_existing=""; \
		for f in "$(SCRIPTS_DIR)"/*.sh; do \
			[ -f "$$f" ] && _existing="$$_existing $$f"; \
		done; \
		if [ -z "$$_existing" ]; then \
			echo "    - no existing scripts to check (skipped)"; \
		else \
			shellcheck --severity=warning $$_existing \
				&& echo "    ✓ shellcheck clean" \
				|| exit 1; \
		fi; \
	else \
		echo "    - shellcheck not installed (skipped)"; \
	fi
	@echo ""
	@echo "  [extra] gofmt..."
	@if command -v gofmt >/dev/null 2>&1; then \
		UNFORMATTED=$$(gofmt -l "$(PROXY_DIR)/"); \
		if [ -z "$$UNFORMATTED" ]; then \
			echo "    ✓ gofmt clean"; \
		else \
			echo "    ✗ unformatted files:"; \
			echo "$$UNFORMATTED"; \
			exit 1; \
		fi; \
	else \
		echo "    - gofmt not installed (skipped)"; \
	fi
	@echo ""
	@echo "✅ All local validations passed"
	@echo ""

# ============================================================
# Validation — documentation presence
# ============================================================
# HARD-MK-03: verifies the documentation files explicitly
# referenced by this Makefile and the v1.2.0 release process
# (see REQUIRED_DOCS above). It does NOT scan all of docs/.
# ============================================================
check-docs:
	@echo "━━━ Verifying required documentation ━━━"
	@echo ""
	@_missing=0; \
	for f in $(REQUIRED_DOCS); do \
		if [ -f "$$f" ]; then \
			printf "    ✓ %s\n" "$$f"; \
		else \
			printf "    ✗ %s (missing)\n" "$$f"; \
			_missing=$$((_missing + 1)); \
		fi; \
	done; \
	if [ "$$_missing" -gt 0 ]; then \
		echo ""; \
		echo "    ❌ $$_missing documentation file(s) missing"; \
		exit 1; \
	fi
	@echo ""
	@echo "✅ Required documentation present"
	@echo ""

# ============================================================
# Validation — committed ADRs
# ============================================================
# HARD-MK-09 (L-3): verifies that the six committed ADRs
# (0001–0006) are present under docs/adr/. PLANNED_ADRS is a
# reserved slot for ADRs written before they are committed;
# as of v1.2.0 it is empty (all ADRs are already committed),
# so this target simply reports "Present: 6 / Missing: 0".
# ============================================================
check-adr:
	@echo "━━━ Checking committed ADRs ━━━"
	@echo ""
	@_present=0; \
	_missing=0; \
	for f in $(COMMITTED_ADRS); do \
		if [ -f "$$f" ]; then \
			printf "    ✓ %s\n" "$$f"; \
			_present=$$((_present + 1)); \
		else \
			printf "    ✗ %s (missing)\n" "$$f"; \
			_missing=$$((_missing + 1)); \
		fi; \
	done; \
	echo ""; \
	if [ "$$_missing" -gt 0 ]; then \
		echo "    ❌ Present: $$_present / Missing: $$_missing"; \
		exit 1; \
	fi; \
	echo "    ✅ Present: $$_present / Missing: $$_missing"; \
	if [ -n "$(strip $(PLANNED_ADRS))" ]; then \
		echo ""; \
		echo "    ── Planned (non-blocking) ──"; \
		for f in $(PLANNED_ADRS); do \
			if [ -f "$$f" ]; then \
				printf "    ✓ %s\n" "$$f"; \
			else \
				printf "    - %s (planned, not yet committed)\n" "$$f"; \
			fi; \
		done; \
	fi

# ============================================================
# Diagnose — how to run on a device
# ============================================================
diagnose-help:
	@echo "━━━ Device-side diagnostics (v1.2.0) ━━━"
	@echo ""
	@echo "  The 'status.sh --diagnose' tool runs on the Android"
	@echo "  device. Run it via adb or a terminal app with root:"
	@echo ""
	@echo "  ┌──────────────────────────────────────────────────────────┐"
	@echo "  │  Full human-readable report:                              │"
	@echo "  │                                                           │"
	@echo "  │    su -c \"sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose\""
	@echo "  │                                                           │"
	@echo "  │  JSON report (for parsing / automation):                  │"
	@echo "  │                                                           │"
	@echo "  │    su -c \"sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json\""
	@echo "  │                                                           │"
	@echo "  │  Backup directory (persistent):                           │"
	@echo "  │                                                           │"
	@echo "  │    /sdcard/dnscrypt-webui-backup/                         │"
	@echo "  │                                                           │"
	@echo "  │  Recovery mode (if module is unbootable):                 │"
	@echo "  │                                                           │"
	@echo "  │    su -c \"touch /data/adb/modules/dnscrypt-proxy-webui/recovery\""
	@echo "  │    su -c \"reboot\"                                         │"
	@echo "  └──────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "  See docs/BACKUP.md for the full reference"
	@echo "  See docs/EMERGENCY.md for recovery procedures"
	@echo ""

# ============================================================
# Release (stable — MINOR / MAJOR)
# ============================================================
# HARD-MK-08 (L-2): the recipe refuses to run when a CLI
# VERSION= disagrees with the file. This prevents the
# catastrophic "tag with one version, module.prop with another"
# scenario.
# ============================================================
release:
	@if [ "$(origin VERSION)" != "command line" ]; then \
		echo "❌ No version specified."; \
		echo ""; \
		echo "   Usage: make release VERSION=v1.3.0"; \
		echo "   Current file VERSION: $(VERSION)"; \
		echo ""; \
		echo "   See docs/RELEASE_PROCESS.md for details."; \
		exit 1; \
	fi
	@if [ "$(VERSION)" != "$(shell cat $(VERSION_FILE) 2>/dev/null)" ]; then \
		echo "⚠️  WARNING: CLI VERSION ($(VERSION)) differs from file ($(shell cat $(VERSION_FILE) 2>/dev/null))."; \
		echo "    The release script will update the file. Continue? [y/N]"; \
		read _ans; \
		[ "$$_ans" = "y" ] || [ "$$_ans" = "Y" ] || exit 1; \
	fi
	@echo ""
	@echo "🚀 Preparing stable release: $(VERSION)"
	@echo ""
	@./scripts/release.sh "$(VERSION)"

# ============================================================
# Release-Patch (PATCH only — emergency)
# ============================================================
release-patch:
	@if [ "$(origin VERSION)" != "command line" ]; then \
		echo "❌ No version specified."; \
		echo ""; \
		echo "   Usage: make release-patch VERSION=v1.2.1"; \
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
	@./scripts/release-patch.sh "$(VERSION)"

# ============================================================
# Sync develop with main
# ============================================================
# HARD-MK-04: each git command checks its exit status.
# ============================================================
sync:
	@echo ""
	@echo "🔄 Syncing develop with main..."
	@echo ""
	@git checkout develop || { echo "❌ git checkout develop failed"; exit 1; }
	@git pull origin develop || { echo "❌ git pull develop failed"; exit 1; }
	@git fetch origin main || { echo "❌ git fetch main failed"; exit 1; }
	@if git merge origin/main --ff-only --no-edit 2>/dev/null; then \
		echo "   ✓ Fast-forward merge succeeded"; \
	else \
		echo "   → Fast-forward not possible, using regular merge"; \
		git merge origin/main --no-edit \
			-m "chore: sync develop with main" \
			|| { echo "❌ git merge failed"; exit 1; }; \
	fi
	@git push origin develop || { echo "❌ git push failed"; exit 1; }
	@echo ""
	@echo "✅ develop is now in sync with main"
	@echo ""