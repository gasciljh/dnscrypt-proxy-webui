<!-- ============================================================
     DNSCrypt Smart Filter – Pull Request Template
     Version: v1.1.0
     Author: gasciljh
     Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
     ============================================================
     This template appears automatically when a new PR is opened.
     Fill every section — delete what does not apply.
     Reference: docs/CONTRIBUTING.md#6 and docs/BRANCHING.md
     ============================================================
     v1.1.0 additions:
       • New MEM-1 / MEM-2 / MEM-3 grep verifications for the
         v1.1.0 changes in main.go (dynamic memory limit, extended
         shellQuote, MONITORING_UI_PORT usage in metrics handler).
       • runtime_info now exposes memory_limit_mb and profile_key —
         added a verification for those fields.
       • Header, version, and reminder sections updated to v1.1.0.
       • The Audit Corrections Registry below remains at #13–#33
         (the v1.0.0 record). v1.1.0 does not add new audit
         corrections — it is a polish release.
     ============================================================ -->

> ## 🚨 Before You Start
>
> **This is the DEFAULT template** — for features, fixes, docs, chores,
> refactors, and tests targeting `develop`.
>
> **If your PR is a RELEASE** (`release/*` → `main` or `hotfix/*` → `main`),
> please **use the release template instead**:
>
> ```text
> https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...<your-branch>?template=release.md
> ```
>
> **See:** [`docs/BRANCHING.md`](../docs/BRANCHING.md) §4.4 and
> [`docs/RELEASE_PROCESS.md`](../docs/RELEASE_PROCESS.md) §5.

---

## 🎯 Target Branch

> ⚠️ **Read this first — it prevents your PR from being closed.**
>
> This project uses a **two-branch strategy** (`main` + `develop`).
> Choosing the wrong base branch will block your PR.

**Choose exactly one:**

- [ ] **Target: `develop`** — for `feature/*`, `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `test/*`
  *(This is the correct choice for 99% of PRs.)*
- [ ] **Target: `main`** — **only** for `release/*` or `hotfix/*` branches
  *(If you check this, switch to the release template — see the callout above.)*

**Quick rule:**

| Your branch starts with… | Open the PR against… | Template |
|---|---|---|
| `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`, `test/` | `develop` | **This one** (default) |
| `release/`, `hotfix/` | `main` | **Release** (`?template=release.md`) |

📖 Full details: [`docs/BRANCHING.md`](../docs/BRANCHING.md) §5.1.

---

## 📝 Description

<!--
  Brief and clear description of what this PR does.
  Explain "what" and "why" — not just "how".

  Good example:
    "Fixes versionCode inconsistency between module.prop and update.json.
     Before: 3030801 (incorrect hotfix calculation).
     After:  1000000 (major*1M + minor*10K + patch*100 + hotfix).
     Impact: Magisk Manager detects updates correctly."

  Bad example:
    "Fix bugs and various improvements" ← says nothing!
-->



---

## 🔗 Related Issue

<!--
  Reference the Issue this PR resolves.
  GitHub links it automatically and closes the Issue on merge.
  Examples:
    Closes #123
    Fixes #456
    Resolves #789
    Refs #101  ← (does not close, just a reference)
-->

Closes #

---

## 🏷️ Change Type

<!--
  Select applicable types. Choose at least one.
  Helps determine the next version number (SemVer).
  See docs/BRANCHING.md §2 for which branch to use.
-->

- [ ] 🐛 **Bug fix** — fixes an error (PATCH)
- [ ] ✨ **Feature** — new feature (MINOR)
- [ ] 💥 **Breaking change** — breaks compatibility (MAJOR)
- [ ] 🔒 **Security fix** — security fix (PATCH)
- [ ] ⚡ **Performance** — performance improvement (PATCH)
- [ ] ♻️ **Refactor** — restructuring without behavior change (PATCH)
- [ ] 📖 **Documentation** — documentation only
- [ ] 🎨 **Style/UI** — style or interface
- [ ] 🔧 **Chore/Build** — routine tasks or build system
- [ ] ⚙️ **CI/CD** — CI workflows
- [ ] 🌐 **Translation** — translation
- [ ] 📋 **ADR** — Architecture Decision Record (see §📖 Documentation)

---

## 🔍 Audit Correction (for security/architecture fixes)

<!--
  Fill this section only if the PR fixes an architectural or security issue.
  See docs/SECURITY.md and docs/ARCHITECTURE.md.

  ┌─────────────────────────────────────────────────┐
  │  Audit Corrections Registry (v1.0.0)                    │
  ├─────────────────────────────────────────────────┤
  │  #13     CSRF-GET → POST-only                v1.0.0     │
  │  #14     pgrep -x (no false positives)       v1.0.0     │
  │  #15-a   Remove token from login response    v1.0.0     │
  │  #15-b   Allow: POST header for 405          v1.0.0     │
  │  #16-a/b IPv4/IPv6 firewall separation       v1.0.0     │
  │  #17     Custom Chains (Orphan Fix)          v1.0.0     │
  │  #18     STATUS_FILE Semantics               v1.0.0     │
  │  #19     IPv6 Rate Limit Bypass              v1.0.0     │
  │  #20     Port Collision 8080                 v1.0.0     │
  │  #21     Section-Restricted TOML             v1.0.0     │
  │  #22     Basic Auth Rate Limit               v1.0.0     │
  │  #23     Section header with comment         v1.0.0     │
  │  #24     Exact endpoint matching             v1.0.0     │
  │  #25     Dashboard JSON Conversion           v1.0.0     │
  │  #26     Preserve Settings on Upgrade        v1.0.0     │
  │  #27     fuser PID parsing                   v1.0.0     │
  │  #28     Login POST-only (CSRF)              v1.0.0     │
  │  #29     readConfPort range check            v1.0.0     │
  │  #30     /readyz localhost-only              v1.0.0     │
  │  #31     shellQuote injection protection     v1.0.0     │
  │  #32     rebuildMu mutex (RACE-1)            v1.0.0     │
  │  #33     runtime_info dynamic ports          v1.0.0     │
  └─────────────────────────────────────────────────┘

  ⚠️ v1.1.0 does NOT add new audit corrections. It is a
     documentation + polish release. The registry above remains
     the authoritative record through v1.0.0.

  If your PR fixes a new security/architecture issue, this PR
  should be the FIRST to add a new entry (starting at #34).

  Example:
    Number: #34
    Title: <fix title>
    Reference: docs/SECURITY.md
-->

- **Audit Correction number**: #
- **Title**:
- **Documentation reference**: `docs/SECURITY.md`

**Problem summary**:
<!-- Brief description: what was wrong? What was its impact? -->



**Solution summary**:
<!-- Brief description: how was it fixed? Why this approach? -->



---

## 🧪 Testing

### Mandatory checks

<!--
  All of these must pass before requesting review.
-->

- [ ] `make build` passed (Go build for all 4 architectures)
- [ ] `bash -n` clean on all modified shell scripts (`proxy/*.sh`, `scripts/*.sh`)
- [ ] `gofmt -l proxy/` is empty (no unformatted files)
- [ ] `shellcheck --severity=warning proxy/*.sh scripts/*.sh` is clean
- [ ] No hardcoded secrets (`detect-secrets` clean)

### 🆕 Core fix verifications (v1.0.0)

<!--
  Run these if the PR touches main.go or web/*.html.
  Fast (< 5 seconds total) — grep-based.
-->

- [ ] **Fix #1 — Dashboard JSON conversion**
  ```bash
  grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅"
  grep -q 'func parsePrometheus' proxy/main.go && echo "✅"
  ```
- [ ] **Fix #2 — Shell fallback**
  ```bash
  grep -q 'func getSystemShell' proxy/main.go && echo "✅"
  ! grep -q 'exec.CommandContext(ctx, "/system/bin/sh"' proxy/main.go && echo "✅"
  ```
- [ ] **Fix #8 — Basic Auth rate limit**
  ```bash
  grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅"
  ```
- [ ] **Fix #12 — Exact endpoint matching**
  ```bash
  grep -q 'func hasEndpoint' proxy/main.go && echo "✅"
  ```
- [ ] **NEW-1 — Login POST-only**
  ```bash
  grep -q 'hasEndpoint(r.URL.Path, "auth/login")' proxy/main.go && echo "✅"
  ```
- [ ] **NEW-3 — readConfPort range check**
  ```bash
  grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' && echo "✅"
  ```
- [ ] **NEW-4 — /readyz localhost-only**
  ```bash
  grep -A30 'func handleReadyz' proxy/main.go | grep -q 'isLocalRequest(r)' && echo "✅"
  ```
- [ ] **NEW-5 — shellQuote**
  ```bash
  grep -q 'func shellQuote' proxy/main.go && echo "✅"
  ```
- [ ] **NEW-6 — Auth cache**
  ```bash
  grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅"
  ```
- [ ] **RACE-1 — rebuildMu mutex**
  ```bash
  grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅"
  ```
- [ ] **PORT-2 — runtime_info ports**
  ```bash
  grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅"
  ```

### 🆕 v1.1.0 additions

<!--
  Run these if the PR touches main.go, functions.sh, service.sh,
  action.sh, status.sh, or watchdog.sh. All are grep-based.

  v1.1.0 introduced three runtime features that must be verified
  by any PR that could affect them:
    • MEM-1 — dynamic memory limit per profile
    • MEM-2 — extended shellQuote character set
    • MEM-3 — MONITORING_UI_PORT constant used everywhere
-->

- [ ] **MEM-1 — Dynamic memory limit (main.go)**
  ```bash
  grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅"
  grep -q 'func applyMemoryLimit' proxy/main.go && echo "✅"
  grep -q 'MEMORY_LIMIT_ULTIMATE' proxy/main.go && echo "✅"
  # Verify main() no longer uses the hardcoded 80MB call
  ! grep -q 'debug.SetMemoryLimit(80 \* 1024 \* 1024)' proxy/main.go && echo "✅ no hardcoded limit"
  # Verify updateProfile applies the new limit
  grep -A3 'atomicWriteFile(SELECTED_FILE' proxy/main.go | grep -q 'applyMemoryLimit' || \
    grep -B2 -A2 'applyMemoryLimit(key)' proxy/main.go | grep -q 'SELECTED_FILE' && echo "✅"
  ```

- [ ] **MEM-2 — Extended shellQuote (main.go)**
  ```bash
  # The v1.1.0 shellQuote must include {, }, \n, \t
  grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ braces"
  grep -A5 'func shellQuote' proxy/main.go | grep -q "'}'" && echo "✅ braces"
  grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\n'" && echo "✅ newline"
  grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\t'" && echo "✅ tab"
  ```

- [ ] **MEM-3 — MONITORING_UI_PORT used in metrics handler (main.go)**
  ```bash
  # Verify the constant is defined and used in the metrics proxy
  grep -q 'MONITORING_UI_PORT = "8080"' proxy/main.go && echo "✅ const"
  grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ used"
  # Verify no hardcoded ":8080/api/metrics" remains in the handler
  ! grep -q '"http://127.0.0.1:8080/api/metrics"' proxy/main.go && echo "✅ no hardcoded URL"
  ```

- [ ] **v1.1.0 — runtime_info new fields (main.go + web/*.html)**
  ```bash
  # Backend
  grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"memory_limit_mb"' && echo "✅ backend memory_limit_mb"
  grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"profile_key"' && echo "✅ backend profile_key"
  # Frontend — English + Arabic keys
  grep -q "riMemoryLimit" web/index.html && echo "✅ index.html"
  grep -q "riMemoryLimit" web/dashboard.html && echo "✅ dashboard.html"
  ```

- [ ] **v1.1.0 — shell-level memory hint helpers**
  ```bash
  # functions.sh must expose the read-only memory hint
  grep -q 'func get_profile_memory_hint' proxy/functions.sh 2>/dev/null || \
    grep -q 'get_profile_memory_hint()' proxy/functions.sh && echo "✅ functions.sh"
  # service.sh / action.sh / status.sh / watchdog.sh should each
  # provide an inline fallback for environments without functions.sh
  grep -q '_inline_get_profile_memory_hint' proxy/service.sh && echo "✅ service.sh fallback"
  grep -q '_inline_get_profile_memory_hint' proxy/action.sh && echo "✅ action.sh fallback"
  grep -q '_inline_get_profile_memory_hint' proxy/status.sh && echo "✅ status.sh fallback"
  grep -q '_wd_get_profile_memory_hint' proxy/watchdog.sh && echo "✅ watchdog.sh fallback"
  ```

- [ ] **v1.1.0 — version bump sanity**
  ```bash
  # VERSION, module.prop, and web/*.html should all agree
  V=$(cat VERSION)
  echo "VERSION: $V"
  grep -q "^version=$V" module.prop && echo "✅ module.prop"
  grep -q "\"version\": \"${V#v}\"" web/manifest.json && echo "✅ manifest.json"
  grep -q "CACHE_VERSION = '$V'" web/sw.js && echo "✅ sw.js"
  grep -q "var VERSION = '$V'" web/index.html && echo "✅ index.html"
  grep -q "var VERSION = '$V'" web/dashboard.html && echo "✅ dashboard.html"
  ```

### Custom tests (as applicable)

- [ ] Added new static verification steps (grep-based) for new security fixes
- [ ] Manually tested the change on a real device

### Manual test on a real device

<!--
  Very important! Automated tests are not enough for the Android environment.
  Test on a real device (or emulator) if possible.
-->

- [ ] Tested on a real Android device or emulator
- [ ] **Android version**: <!-- e.g. Android 14 -->
- [ ] **Device**: <!-- e.g. Pixel 6 Pro -->
- [ ] **ROM**: <!-- e.g. LineageOS 21 -->
- [ ] **Root**: <!-- e.g. Magisk 27.0 / KernelSU 0.9.5 -->

### Change-specific tests

**If the change is in the WebUI:**
- [ ] Opened WebUI and confirmed no JS errors
- [ ] Tested in both Arabic and English
- [ ] Tested PWA install / reload
- [ ] Tested SSE live updates
- [ ] Tested dynamic links (with custom PORT / DASHBOARD_PORT)

**If the change is in shell scripts:**
- [ ] Confirmed no new `shellcheck` warnings
- [ ] Tested on a real device (if possible)

**If the change is in the firewall:**
- [ ] Checked `iptables -t nat -L DNSCRYPT_OUT -n`
- [ ] Checked `ip6tables -t nat -L DNSCRYPT_OUT6 -n`
- [ ] Confirmed `OUTPUT` has no orphans:
  ```bash
  su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
  # Expected: 0
  ```
- [ ] Tested `stopService` and `startService` cleanly

**If the change is in `STATUS_FILE` semantics:**
- [ ] Confirmed `getStatusUncached` does not write `STATUS_FILE`
  ```bash
  grep -A5 'func getStatusUncached' proxy/main.go | grep -q 'atomicWriteFile' && echo "⚠️ writes!" || echo "✅ read-only"
  ```
- [ ] Tested crash recovery:
  ```bash
  su -c "pkill -9 dnscrypt-proxy"
  sleep 60
  su -c "sh status.sh --json | jq .dns_engine.running"
  # Expected: true
  ```

**If the change is in authentication:**
- [ ] Tested login / logout / session expiry
- [ ] Tested rate limiting (5 attempts / 15 minutes)
- [ ] Tested from IPv4 and IPv6 (`[::1]`)
- [ ] Tested Login POST-only:
  ```bash
  curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
  # Expected: 405 Method Not Allowed + Allow: POST
  ```
- [ ] Tested Basic Auth rate limit:
  ```bash
  for i in 1 2 3 4 5 6; do
    curl -u "wrong:wrong" http://127.0.0.1:9090/api?action=status \
      -o /dev/null -w "%{http_code}\n"
  done
  # Expected: 401 × 5 then 401 (locked)
  ```

**If the change is in `rebuildBlocklist` or `updateProfile` (RACE-1):**
- [ ] Confirmed `rebuildMu.Lock()` present + `defer rebuildMu.Unlock()`
- [ ] Tested concurrency manually (update + save simultaneously)
- [ ] Confirmed no deadlock (30 s timeout is enough)

**If the change is in `buildRuntimeInfo` or `runtime_info` (PORT-2 + v1.1.0):**
- [ ] Confirmed `webui_port` + `dashboard_port` present in JSON response:
  ```bash
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq
  # Expected: contains "webui_port" and "dashboard_port"
  ```
- [ ] Confirmed `memory_limit_mb` + `profile_key` present:
  ```bash
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb, .profile_key'
  # Expected: a number, and a profile key string
  ```
- [ ] Tested with custom ports (PORT=8081, DASHBOARD_PORT=8082)
- [ ] Confirmed `index.html` uses `data.dashboard_port`
- [ ] Confirmed `dashboard.html` uses `data.webui_port`

**If the change is in `/api/metrics` or `parsePrometheus` (Fix #1 + MEM-3):**
- [ ] Confirmed Content-Type:
  ```bash
  curl -s -I "http://127.0.0.1:9091/api/metrics" | grep Content-Type
  # Expected: application/json; charset=utf-8
  ```
- [ ] Confirmed JSON structure:
  ```bash
  curl -s "http://127.0.0.1:9091/api/metrics" | jq
  # Expected: {total_queries, blocked_queries, cache_stats, ...}
  ```
- [ ] Tested Dashboard in browser (no "Cannot fetch data")

**If the change is in the memory limit logic (v1.1.0 MEM-1):**
- [ ] Confirmed the limit adjusts when profile changes:
  ```bash
  # Start with light
  echo "light" > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  sleep 5
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'
  # Expected: 80

  # Switch to ultimate
  echo "ultimate" > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  sleep 5
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'
  # Expected: 220
  ```

---

## 🔒 Security Checklist

<!--
  Fill this section if the PR relates to security.
  See docs/SECURITY.md for full standards.
-->

### Basics

- [ ] Code contains no hardcoded secrets (passwords, tokens, keys)
- [ ] Contains no `console.log` or `fmt.Println` with sensitive data
- [ ] Used `subtle.ConstantTimeCompare` for secret comparison (if applicable)
- [ ] Applied `MaxBytesReader` on new POST bodies (if applicable)
- [ ] Used `atomicWriteFile` / `atomicWriteStream` for writes (if applicable)

### Authentication and endpoints

- [ ] Verified `checkAuth(r)` on every new endpoint (if applicable)
- [ ] Used `hasEndpoint(path, name)` instead of `strings.Contains` / `strings.HasSuffix`
- [ ] Used `getClientIP(r)` to extract IP (not `strings.Split`)
- [ ] Made `/api/auth/login` and `/api/auth/logout` POST-only (if applicable)
- [ ] If a new rate limit was added, registered attempts in `loginAttempts`

### Input Validation

- [ ] If adding a port read, used `readConfPort` (with range check 1–65535)
- [ ] If using a dynamic shell command, used `shellQuote()`
- [ ] If adding a new health endpoint, considered `isLocalRequest` (local-only)

### Firewall

- [ ] Did not pollute `OUTPUT` / `INPUT` / `FORWARD` with dynamic rules
- [ ] Used `DNSCRYPT_OUT` / `DNSCRYPT_OUT6` for the firewall
- [ ] Confirmed `--wait` on every `iptables` / `ip6tables` invocation
- [ ] Tested `_legacy_cleanup_*` after upgrade from an older version

### Concurrency (RACE-1)

- [ ] Any operation modifying `ALLOWLIST` / `DENYLIST` / `BLOCKLIST` calls `rebuildBlocklist`
- [ ] `rebuildBlocklist` is protected by `rebuildMu.Lock()` + `defer Unlock()`
- [ ] No nested deadlock (never calls a function that locks the same mutex)

### Memory (v1.1.0)

- [ ] If adding a new profile, updated `MEMORY_LIMIT_*` in main.go
- [ ] If adding a new profile, updated the inline fallback in all four shell scripts
  (`service.sh`, `action.sh`, `status.sh`, `watchdog.sh`)
- [ ] If adding a new profile, updated `webui.conf` template in `customize.sh`
- [ ] If adding a new profile, updated `web/index.html` `<select id="profileSelect">`

### For security fixes

- [ ] Updated `docs/SECURITY.md` (Attack Vectors section + §5.X)
- [ ] Updated `docs/ARCHITECTURE.md` (Trade-offs)
- [ ] Updated `docs/TROUBLESHOOTING.md` (Diagnostics)
- [ ] Added the Audit Correction #XX in the commit footer
- [ ] Added HTML anchor `<a name="XXX"></a>` (if a new section was created)
- [ ] Updated the Audit Corrections Registry in `docs/SECURITY.md`

---

## 📖 Documentation

<!--
  Do not forget to update documentation — it is part of PR quality.
  See docs/CONTRIBUTING.md#9.
-->

- [ ] Updated `CHANGELOG.md` (auto-generated at release, but note it if relevant)
- [ ] Updated `README.md` (if a new user-facing feature)
- [ ] Updated `docs/API.md` (if an API change)
- [ ] Updated `docs/ARCHITECTURE.md` (if an architectural change)
- [ ] Updated `docs/SECURITY.md` (if a security fix)
- [ ] Updated `docs/TROUBLESHOOTING.md` (if a common issue)
- [ ] Updated `docs/FAQ.md` (if a common question)
- [ ] Updated `docs/BRANCHING.md` or `docs/RELEASE_PROCESS.md` (if a workflow change)
- [ ] Added or updated an ADR in `docs/adr/` (if a non-trivial decision)
- [ ] If reversing an ADR, created a new one that supersedes it (never edit the old)
- [ ] Added / updated code comments (Go docstrings, shell comments)
- [ ] **v1.1.0** — if a new field was added to `runtime_info`, updated both
      `web/index.html` and `web/dashboard.html` translation tables (en + ar)

---

## ✅ Final Checklist

<!--
  Ensure every item is complete before requesting review.
-->

### Branch policy

- [ ] PR target is `develop` (or `main` **only** for `release/*` / `hotfix/*`)
- [ ] If targeting `main`, using the **release template** (`?template=release.md`)
- [ ] No direct push was made to `main` or `develop`
- [ ] Read [`docs/BRANCHING.md`](../docs/BRANCHING.md) if unsure

### General commitments

- [ ] Followed [Conventional Commits](https://www.conventionalcommits.org/) on every commit
  - Examples: `feat(webui): add dark mode`, `fix(proxy): resolve race condition`
  - For security fixes: `security(iptables): implement Custom Chains`
  - For ADRs: `docs(adr): add ADR-0007 for webhook notifications`
- [ ] Commit messages are clear and useful (no "WIP" or "fix stuff")
- [ ] Reasonable number of commits (no 50 commits for a small PR)
- [ ] No merge commits (`Merge branch 'main'`) — used `rebase` instead

### Code quality

- [ ] No dead code
- [ ] No unjustified `TODO` or `FIXME`
- [ ] No `fmt.Println` or `console.log` in production code
- [ ] Names are clear (`userCount` not `uc`)
- [ ] Comments on exported functions
- [ ] Every error is handled (`if err != nil`) correctly
- [ ] Used `defer unlock()` on every mutex (no forgotten unlock)

### Build verification

- [ ] `make build` passes
- [ ] `bash -n` clean on modified shell scripts
- [ ] No hardcoded `/system/bin/sh` (use `getSystemShell()`)
- [ ] No hardcoded `127.0.0.1` in HTML (use `window.location.hostname`)

### Documentation

- [ ] Reviewed every item in the "📖 Documentation" section above
- [ ] No broken links in the updated documentation
- [ ] Code examples in the documentation are correct (actually tested)

### Cleanliness

- [ ] Removed all temporary files (`*.tmp`, `*.bak`, `scratch.*`)
- [ ] No binary files uploaded without justification
- [ ] No `.DS_Store` or `Thumbs.db` files
- [ ] Reviewed `git diff` before pushing (no unintended changes)
- [ ] Confirmed no leftover `*.tmp_*` from `atomicWriteFile`

---

## 🖼️ Screenshots / Recordings

<!--
  If the PR relates to the UI, attach images or GIFs.
  For bug fixes: attach "before" and "after" images if possible.
  For logic changes: no images needed.
-->



---

## 📌 Additional Notes

<!--
  Anything else the reviewer needs to know:
  - Architectural decisions made
  - Trade-offs considered
  - Known limitations
  - Questions for the reviewer
  - References (RFCs, OWASP, Netfilter docs, ...)
-->



---

## 🎯 Reviewer Suggestion

<!--
  Optional: if you want a specific review, mention it here.
  Example:
    - @gasciljh: review the Custom Chains logic in functions.sh
    - @reviewer: check the queries in main.go
-->



---

<!-- ============================================================
     ⚠️ Final reminder:

     ┌────────────────────────────────────────────────┐
     │  🎯 Branch policy reminder                              │
     ├────────────────────────────────────────────────┤
     │  feature/*, fix/*, docs/*, chore/*, refactor/*, test/*  │
     │      → PR base: develop                                │
     │      → Template: this one (default)                    │
     │                                                         │
     │  release/*, hotfix/*                                    │
     │      → PR base: main                                   │
     │      → Template: ?template=release.md                  │
     │                                                         │
     │  Never open a PR directly against main for features.    │
     │  Read docs/BRANCHING.md for the full explanation.       │
     └────────────────────────────────────────────────┘

     • Ensure the PR references an Issue (if one exists)
     • Review the diff one last time before pushing
     • Test locally if possible
     • Be ready to respond and adjust

     🎯 Quick verification commands (before pushing):

       make build                          # Go build for all 4 architectures
       bash -n proxy/*.sh scripts/*.sh     # shell syntax check
       gofmt -l proxy/                     # Go format check
       shellcheck --severity=warning proxy/*.sh scripts/*.sh

     🎯 v1.1.0 extra checks (if main.go changed):

       grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1"
       grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ MEM-2"
       grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"

     📖 Documentation references:

       docs/BRANCHING.md        - Branch strategy
       docs/RELEASE_PROCESS.md  - Release process
       docs/adr/README.md       - Architecture Decision Records
       docs/CONTRIBUTING.md     - Contribution guide
       docs/SECURITY.md         - Security policy

     Current version: v1.1.0
     Last updated: 2026-09-26

     🎉 Thanks for your contribution! Every PR improves the project.
     ============================================================ -->