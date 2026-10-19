# ============================================================
# DNSCrypt Smart Filter — Makefile
# Version: v1.5.0 (Global Edition)
# Last updated: 2026-10-18
# Author: gasciljh
# Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
# ============================================================
# Unified commands for building, packaging, releasing, and
# validating the module.
#
# The release targets accept a CLI override:
#     make release VERSION=v1.5.1
#
# All other targets read VERSION from the VERSION file.
# ============================================================

SHELL := /bin/sh

# ────────────────────────────────────────────────────────────
# Version resolution
# ────────────────────────────────────────────────────────────
# CLI_VERSION captures a command-line `VERSION=...` before the
# `override` directive below makes VERSION immune to it. The
# release targets read CLI_VERSION; every other target reads
# VERSION — which is always the file's value.
#
# This isolates "did the user pass a version?" from the variable
# used by build/package/check targets, so a CLI value cannot
# silently disagree with the file.
# ────────────────────────────────────────────────────────────
VERSION_FILE := VERSION

CLI_VERSION := $(VERSION)
override VERSION := $(shell cat $(VERSION_FILE) 2>/dev/null || echo "unknown")

# ────────────────────────────────────────────────────────────
# Syntax checker — matches ci.yml
# ────────────────────────────────────────────────────────────
# The CI workflow's `bash -n` step is the authoritative syntax
# check. Local `make check-backup` uses the SAME tool so a green
# local run means a green CI run.
# ────────────────────────────────────────────────────────────
SH_CHECK := bash

PROXY_DIR   := $(shell pwd)/proxy
DIST_DIR    := $(shell pwd)/dist
DOCS_DIR    := $(shell pwd)/docs
SCRIPTS_DIR := $(shell pwd)/scripts
ADR_DIR     := $(DOCS_DIR)/adr

# ────────────────────────────────────────────────────────────
# Lists
# ────────────────────────────────────────────────────────────
SHELL_SCRIPTS := \
	$(PROXY_DIR)/post-fs-data.sh \
	$(PROXY_DIR)/customize.sh \
	$(PROXY_DIR)/functions.sh \
	$(PROXY_DIR)/boot-mini.sh \
	$(PROXY_DIR)/service.sh \
	$(PROXY_DIR)/watchdog.sh \
	$(PROXY_DIR)/action.sh \
	$(PROXY_DIR)/status.sh \
	$(PROXY_DIR)/uninstall.sh \
	$(PROXY_DIR)/install_app.sh

# Post-v1.5.0 consolidation (15 user-facing files, 2 of which
# are GitHub meta-files not checked here). The list below matches
# docs/MAP.md §1.
REQUIRED_DOCS := \
	README.md \
	SECURITY.md \
	CHANGELOG.md \
	CODE_OF_CONDUCT.md \
	docs/GUIDE.md \
	docs/REFERENCE.md \
	docs/CONTRIBUTING.md \
	docs/MAP.md \
	docs/ROADMAP.md

# Files that MUST NOT exist after the v1.5.0 consolidation.
# A stray `git checkout -- docs/` or a rebase accident cannot
# silently recreate them without failing `check-docs`.
FORBIDDEN_DOCS := \
	docs/INSTALL.md \
	docs/UPGRADE.md \
	docs/TROUBLESHOOTING.md \
	docs/FAQ.md \
	docs/EMERGENCY.md \
	docs/API.md \
	docs/ARCHITECTURE.md \
	docs/BACKUP.md \
	docs/COMPATIBILITY.md \
	docs/DNS_BINARIES.md \
	docs/MANIFEST_NOTES.md \
	docs/GLOSSARY.md \
	docs/DEVELOPMENT.md \
	docs/BRANCHING.md \
	docs/RELEASE_PROCESS.md \
	docs/HALL_OF_FAME.md \
	docs/SECURITY.md \
	.github/SECURITY.md \
	docs/adr/0001-two-branch-model.md \
	docs/adr/0002-automated-releases.md \
	docs/adr/0003-post-release-sync.md \
	docs/adr/0004-unified-pr-template.md \
	docs/adr/0005-release-specific-pr-template.md \
	docs/adr/0006-rename-hotfix-to-release-patch.md \
	docs/adr/0007-external-dependency-securejoin.md \
	docs/adr/0008-layered-bootstrap.md \
	docs/adr/0009-documentation-budget.md

# The 3 ADRs + the index, matching docs/adr/README.md.
COMMITTED_ADRS := \
	docs/adr/README.md \
	docs/adr/0001-release-workflow.md \
	docs/adr/0002-external-dependency.md \
	docs/adr/0003-layered-bootstrap.md

APP_VERSION_FILE := proxy/app-apk.version
APP_FETCH_SCRIPT := scripts/fetch_app_apk.sh
INSTALL_APP_FILE := proxy/install_app.sh

BOOT_MINI_FILE := proxy/boot-mini.sh
FUNCTIONS_FILE := proxy/functions.sh

.PHONY: all help version build package clean dist-clean \
        fetch-apk check-app-version check-install-app check-boot-mini \
        check-backup check-all check-docs check-adr diagnose-help \
        release release-patch sync

all: build

# ============================================================
# Help
# ============================================================
help:
	@echo "DNSCrypt Smart Filter — $(VERSION)"
	@echo ""
	@echo "  make build              Cross-compile 4 architectures"
	@echo "  make package            Build + package Magisk ZIP"
	@echo "  make clean              Remove proxy/build/ and dist/"
	@echo "  make dist-clean         Remove dist/ only"
	@echo "  make version            Print VERSION"
	@echo ""
	@echo "  make fetch-apk          Fetch companion APK into dist/"
	@echo "  make check-app-version  Validate proxy/app-apk.version"
	@echo "  make check-install-app  Verify proxy/install_app.sh"
	@echo "  make check-boot-mini    Verify proxy/boot-mini.sh (Layer 0)"
	@echo ""
	@echo "  make check-backup       Validate all runtime shell scripts"
	@echo "  make check-all          Run all local validations"
	@echo "  make check-docs         Verify documentation consistency"
	@echo "  make check-adr          Verify committed ADRs"
	@echo "  make diagnose-help      Show device-side diagnostic commands"
	@echo ""
	@echo "  make release VERSION=vX.Y.Z        Stable release"
	@echo "  make release-patch VERSION=vX.Y.Z  PATCH release"
	@echo "  make sync                          Sync develop with main"

# ============================================================
# Version
# ============================================================
version:
	@if [ -n "$(CLI_VERSION)" ] && [ "$(CLI_VERSION)" != "$(VERSION)" ]; then \
		echo "⚠️  CLI VERSION ($(CLI_VERSION)) differs from file ($(VERSION))." >&2; \
		echo "    The file value is authoritative for build/package targets." >&2; \
	fi
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
package: build check-install-app fetch-apk
	@echo "Packaging $(VERSION)..."
	@chmod +x scripts/package_module.sh 2>/dev/null || true
	@./scripts/package_module.sh \
		--version "$(VERSION)" \
		--build-dir "$(PROXY_DIR)/build"
	@echo ""
	@echo "✅ Package created:"
	@ls -la "$(DIST_DIR)"/dnscrypt-webui-*-module.zip 2>/dev/null || true
	@ls -la "$(DIST_DIR)"/dnscrypt-webui-*-module.zip.sha256 2>/dev/null || true
	@ls -la "$(DIST_DIR)"/DNS-Proxy-*.apk 2>/dev/null || true
	@ls -la "$(DIST_DIR)"/DNS-Proxy-*.apk.sha256 2>/dev/null || true

# ============================================================
# Clean
# ============================================================
clean:
	@rm -rf "$(PROXY_DIR)/build" "$(DIST_DIR)"
	@echo "Cleaned (build + dist)"

dist-clean:
	@rm -rf "$(DIST_DIR)"
	@echo "Cleaned (dist only)"

# ============================================================
# Companion APK — fetch
# ============================================================
fetch-apk:
	@echo "━━━ Fetching companion app APK ━━━"
	@chmod +x "$(APP_FETCH_SCRIPT)" 2>/dev/null || true
	@if [ ! -f "$(APP_FETCH_SCRIPT)" ]; then \
		echo "⚠️  $(APP_FETCH_SCRIPT) not found — skipping"; \
		exit 0; \
	fi
	@./$(APP_FETCH_SCRIPT) --output-dir "$(DIST_DIR)" || \
		echo "⚠️  APK fetch failed — continuing without it"
	@ls -la "$(DIST_DIR)"/DNS-Proxy-*.apk 2>/dev/null || \
		echo "   (no APK in dist/ — companion app is optional)"

# ============================================================
# Companion APK — version format
# ============================================================
check-app-version:
	@echo "━━━ Checking proxy/app-apk.version ━━━"
	@if [ ! -s "$(APP_VERSION_FILE)" ]; then \
		echo "  ❌ $(APP_VERSION_FILE) missing or empty"; \
		exit 1; \
	fi
	@APP_V="$$(tr -d '\r\n' < "$(APP_VERSION_FILE)" | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//')"; \
	if printf '%s' "$$APP_V" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		echo "  ✅ $(APP_VERSION_FILE): $$APP_V (valid)"; \
	else \
		echo "  ❌ invalid format: $$APP_V (expected X.Y.Z)"; \
		exit 1; \
	fi
	@if [ -s "$(APP_FETCH_SCRIPT)" ]; then \
		echo "  ✅ $(APP_FETCH_SCRIPT) present"; \
	else \
		echo "  ⚠️  $(APP_FETCH_SCRIPT) missing"; \
	fi

# ============================================================
# Companion APK — install script
# ============================================================
check-install-app:
	@echo "━━━ Checking proxy/install_app.sh ━━━"
	@if [ ! -f "$(INSTALL_APP_FILE)" ]; then \
		echo "  ❌ $(INSTALL_APP_FILE) missing"; exit 1; \
	fi
	@if [ ! -s "$(INSTALL_APP_FILE)" ]; then \
		echo "  ❌ $(INSTALL_APP_FILE) empty"; exit 1; \
	fi
	@if [ ! -x "$(INSTALL_APP_FILE)" ]; then \
		echo "  ⚠️  $(INSTALL_APP_FILE) is not executable"; \
		echo "      (run 'make package' to fix, or chmod +x manually)"; \
	fi
	@_lines=$$(wc -l < "$(INSTALL_APP_FILE)" | tr -d ' '); \
	echo "  ✅ present ($$_lines lines)"
	@_missing=0; \
	for marker in \
		"pm install -r --user 0" \
		"pm install -r --user 0 -i com.android.shell" \
		"pm install-create" \
		"magisk su" \
		"cmd package install" \
		"CASCADE_DEADLINE_SECONDS" \
		"package_verifier_enable" \
		"_VERIFIER_ORIG" \
		"/data/local/tmp/dnscrypt-companion.apk" \
	; do \
		if grep -q "$$marker" "$(INSTALL_APP_FILE)"; then \
			printf "    ✓ %s\n" "$$marker"; \
		else \
			printf "    ✗ %s\n" "$$marker"; \
			_missing=$$((_missing + 1)); \
		fi; \
	done; \
	if [ "$$_missing" -gt 0 ]; then \
		echo "  ❌ $$_missing marker(s) missing"; exit 1; \
	fi
	@if grep -v '^[[:space:]]*#' "$(INSTALL_APP_FILE)" | grep -q 'setenforce 0'; then \
		echo "  ❌ 'setenforce 0' found in executable code"; \
		exit 1; \
	fi
	@echo "  ✅ No 'setenforce 0' — SELinux staging only"
	@if grep -q "trap '_cleanup_app; exit 130' INT" "$(INSTALL_APP_FILE)" && \
	    grep -q "trap '_cleanup_app; exit 143' TERM" "$(INSTALL_APP_FILE)" && \
	    grep -q '_CLEANED_UP=1' "$(INSTALL_APP_FILE)"; then \
		echo "  ✅ Three-way trap split with re-entry guard"; \
	else \
		echo "  ❌ Three-way trap split missing or incomplete"; \
		exit 1; \
	fi

# ============================================================
# Layered Bootstrap — boot-mini.sh (Layer 0)
# ============================================================
check-boot-mini:
	@echo "━━━ Checking proxy/boot-mini.sh (Layer 0) ━━━"
	@if [ ! -s "$(BOOT_MINI_FILE)" ]; then \
		echo "  ❌ $(BOOT_MINI_FILE) missing or empty"; \
		exit 1; \
	fi
	@_lines=$$(wc -l < "$(BOOT_MINI_FILE)" | tr -d ' '); \
	echo "  ✅ present ($$_lines lines)"
	@_missing=0; \
	for fn in log_msg get_run_dir read_conf is_port_open get_webui_port; do \
		if grep -qE "^$$fn\(\)" "$(BOOT_MINI_FILE)"; then \
			printf "    ✓ %s\n" "$$fn"; \
		else \
			printf "    ✗ %s\n" "$$fn"; \
			_missing=$$((_missing + 1)); \
		fi; \
	done; \
	if [ "$$_missing" -gt 0 ]; then \
		echo "  ❌ $$_missing primitive(s) missing"; \
		exit 1; \
	fi
	@if grep -q '^_MONITORING_UI_PORT=' "$(BOOT_MINI_FILE)"; then \
		echo "  ✅ _MONITORING_UI_PORT defined (single source of truth)"; \
	else \
		echo "  ❌ _MONITORING_UI_PORT not defined in boot-mini.sh"; \
		exit 1; \
	fi
	@if [ ! -f "$(FUNCTIONS_FILE)" ]; then \
		echo "  ❌ $(FUNCTIONS_FILE) missing"; \
		exit 1; \
	fi
	@if grep -q 'boot-mini.sh' "$(FUNCTIONS_FILE)"; then \
		echo "  ✅ functions.sh sources boot-mini.sh"; \
	else \
		echo "  ❌ functions.sh does not source boot-mini.sh"; \
		exit 1; \
	fi
	@_redef=0; \
	for fn in get_run_dir read_conf is_port_open get_webui_port; do \
		if grep -qE "^$$fn[[:space:]]*\(\)" "$(FUNCTIONS_FILE)"; then \
			echo "  ❌ functions.sh redefines Layer-0 primitive: $$fn"; \
			_redef=$$((_redef + 1)); \
		fi; \
	done; \
	if [ "$$_redef" -gt 0 ]; then \
		exit 1; \
	fi
	@if grep -qE '^_MONITORING_UI_PORT=' "$(FUNCTIONS_FILE)"; then \
		echo "  ❌ functions.sh redefines _MONITORING_UI_PORT"; \
		exit 1; \
	fi
	@echo "  ✅ functions.sh does not redefine Layer-0 primitives"
	@echo "✅ boot-mini.sh integration verified"

# ============================================================
# Validation — all shell scripts
# ============================================================
check-backup:
	@echo "━━━ Validating shell scripts ━━━"
	@echo "  [1/2] $(SH_CHECK) -n syntax check..."
	@for f in $(SHELL_SCRIPTS); do \
		if [ -f "$$f" ]; then \
			if $(SH_CHECK) -n "$$f" 2>/dev/null; then \
				printf "    ✓ %s\n" "$$(basename "$$f")"; \
			else \
				printf "    ✗ %s (syntax error)\n" "$$(basename "$$f")"; \
				exit 1; \
			fi; \
		else \
			printf "    - %s (missing)\n" "$$(basename "$$f")"; \
		fi; \
	done
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
	@echo "✅ Shell script validation complete"

# ============================================================
# Validation — documentation consistency
# ============================================================
# Two-part check:
#   1. Every REQUIRED_DOCS file must exist.
#   2. No FORBIDDEN_DOCS file may exist (consolidation guard).
check-docs:
	@echo "━━━ Documentation consistency ━━━"
	@if [ -x "$(SCRIPTS_DIR)/check-docs.sh" ]; then \
		"$(SCRIPTS_DIR)/check-docs.sh"; \
	else \
		echo "  scripts/check-docs.sh not present — presence-only check"; \
		_missing=0; \
		for f in $(REQUIRED_DOCS); do \
			if [ -f "$$f" ]; then printf "  ✓ %s\n" "$$f"; \
			else printf "  ✗ %s (missing)\n" "$$f"; _missing=$$((_missing + 1)); fi; \
		done; \
		_forbidden=0; \
		for f in $(FORBIDDEN_DOCS); do \
			if [ -f "$$f" ]; then \
				printf "  ✗ %s (forbidden — consolidation was not applied?)\n" "$$f"; \
				_forbidden=$$((_forbidden + 1)); \
			fi; \
		done; \
		if [ "$$_missing" -gt 0 ] || [ "$$_forbidden" -gt 0 ]; then \
			echo "  ❌ missing: $$_missing / forbidden: $$_forbidden"; \
			exit 1; \
		fi; \
		echo "✅ 9 required docs present / 0 forbidden docs present"; \
	fi

# ============================================================
# Validation — committed ADRs
# ============================================================
check-adr:
	@echo "━━━ Committed ADRs ━━━"
	@_present=0; _missing=0; \
	for f in $(COMMITTED_ADRS); do \
		if [ -f "$$f" ]; then \
			printf "  ✓ %s\n" "$$f"; _present=$$((_present + 1)); \
		else \
			printf "  ✗ %s (missing)\n" "$$f"; _missing=$$((_missing + 1)); \
		fi; \
	done; \
	if [ "$$_missing" -gt 0 ]; then \
		echo "  ❌ Present: $$_present / Missing: $$_missing"; exit 1; \
	fi; \
	echo "  ✅ Present: $$_present / Missing: $$_missing"

# ============================================================
# Validation — all local checks
# ============================================================
check-all: check-backup check-docs check-app-version check-install-app check-boot-mini
	@echo "━━━ Additional validations ━━━"
	@echo "  [1/2] scripts/ syntax check..."
	@for f in "$(SCRIPTS_DIR)"/*.sh; do \
		[ -f "$$f" ] || continue; \
		if bash -n "$$f" 2>/dev/null; then \
			printf "    ✓ %s\n" "$$(basename "$$f")"; \
		else \
			printf "    ✗ %s\n" "$$(basename "$$f")"; \
			exit 1; \
		fi; \
	done
	@echo "  [2/2] scripts/ shellcheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		_existing=""; \
		for f in "$(SCRIPTS_DIR)"/*.sh; do \
			[ -f "$$f" ] && _existing="$$_existing $$f"; \
		done; \
		if [ -z "$$_existing" ]; then \
			echo "    - no scripts to check (skipped)"; \
		else \
			shellcheck --severity=warning $$_existing \
				&& echo "    ✓ shellcheck clean" \
				|| echo "    ⚠ shellcheck reported warnings (non-blocking)"; \
		fi; \
	else \
		echo "    - shellcheck not installed (skipped)"; \
	fi
	@if command -v gofmt >/dev/null 2>&1; then \
		UNFORMATTED=$$(gofmt -l "$(PROXY_DIR)/"); \
		if [ -z "$$UNFORMATTED" ]; then \
			echo "  ✓ gofmt clean"; \
		else \
			echo "  ✗ unformatted files:"; echo "$$UNFORMATTED"; exit 1; \
		fi; \
	fi
	@echo "✅ All local validations passed"

# ============================================================
# Diagnostics — device-side commands
# ============================================================
diagnose-help:
	@echo "━━━ Device-side diagnostics ━━━"
	@echo ""
	@echo "  Full report:"
	@echo "    su -c \"sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose\""
	@echo ""
	@echo "  JSON report:"
	@echo "    su -c \"sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json\""
	@echo ""
	@echo "  Companion app state:"
	@echo "    su -c \"sh /data/adb/modules/dnscrypt-proxy-webui/install_app.sh --status\""
	@echo ""
	@echo "  Persistent backup:"
	@echo "    /sdcard/dnscrypt-webui-backup/"
	@echo ""
	@echo "  Trigger recovery mode:"
	@echo "    su -c \"touch /data/adb/modules/dnscrypt-proxy-webui/recovery\""
	@echo "    su -c \"reboot\""
	@echo ""
	@echo "  See docs/REFERENCE.md §4 and docs/GUIDE.md §8."

# ============================================================
# Release — stable
# ============================================================
release:
	@if [ -z "$(CLI_VERSION)" ] || [ "$(CLI_VERSION)" = "unknown" ]; then \
		echo "❌ No version specified."; \
		echo "   Usage: make release VERSION=v1.5.0"; \
		echo "   Current VERSION file: $(VERSION)"; \
		exit 1; \
	fi
	@echo "🚀 Preparing stable release: $(CLI_VERSION)"
	@./scripts/release.sh "$(CLI_VERSION)"

# ============================================================
# Release — PATCH only
# ============================================================
release-patch:
	@if [ -z "$(CLI_VERSION)" ] || [ "$(CLI_VERSION)" = "unknown" ]; then \
		echo "❌ No version specified."; \
		echo "   Usage: make release-patch VERSION=v1.5.1"; \
		exit 1; \
	fi
	@echo "🔧 Preparing PATCH release: $(CLI_VERSION)"
	@echo "   Ensure you are on the 'main' branch."
	@echo "   After publishing, run: make sync"
	@./scripts/release-patch.sh "$(CLI_VERSION)"

# ============================================================
# Sync — develop with main
# ============================================================
sync:
	@echo "🔄 Syncing develop with main..."
	@git checkout develop || { echo "❌ checkout develop failed"; exit 1; }
	@git pull origin develop || { echo "❌ pull develop failed"; exit 1; }
	@git fetch origin main || { echo "❌ fetch main failed"; exit 1; }
	@if git merge origin/main --ff-only --no-edit 2>/dev/null; then \
		echo "   ✓ Fast-forward merge succeeded"; \
	else \
		git merge origin/main --no-edit -m "chore: sync develop with main" \
			|| { echo "❌ merge failed"; exit 1; }; \
	fi
	@git push origin develop || { echo "❌ push failed"; exit 1; }
	@echo "✅ develop in sync with main"