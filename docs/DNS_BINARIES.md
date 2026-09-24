# DNS Binaries — Enterprise Guide (Level 4)

> Comprehensive guide to fetching, caching, and verifying `dnscrypt-proxy` binaries in DNSCrypt Smart Filter.

**Version**: v1.0.0
**Last updated**: 2026-09-24
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

---

## Table of Contents

1. [Overview](#1-overview)
2. [Single Source of Truth](#2-single-source-of-truth)
3. [How It Works](#3-how-it-works)
4. [5 Fallback Sources](#4-5-fallback-sources)
5. [Cache Structure](#5-cache-structure)
6. [SHA256 Verification](#6-sha256-verification)
7. [Retry Logic](#7-retry-logic)
8. [CI Integration](#8-ci-integration)
9. [Command Reference](#9-command-reference)
10. [Updating the Version](#10-updating-the-version)
11. [Troubleshooting](#11-troubleshooting)
12. [References](#12-references)
13. [Summary](#13-summary)

---

## 1. Overview

### 1.1 What is dnscrypt-proxy?

**dnscrypt-proxy** is the encrypted DNS engine the project depends on:

- Source: [DNSCrypt/dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)
- License: ISC License
- Availability: 4 architectures (arm64, arm, i386, x86_64)
- Current version: **2.1.18**

### 1.2 Challenges before Level 4

| Challenge | Problem |
|---|---|
| **Embedded URLs** | URL format in code might change without update |
| **Duplicated version** | `2.1.5` embedded in two different places |
| **i386 vs x86** | Different names between GitHub and staging |
| **No SHA verification** | No integrity check |
| **No cache** | Every build = fresh download |
| **No fallback** | If GitHub fails → build fails |
| **Slow CI** | ~30s per release |
| **No retry** | Transient failure → workflow fails |

### 1.3 Solution (Level 4)

| Feature | Benefit | Version |
|---|---|---|
| ✅ **Single Source of Truth** | One file determines DNS version | Level 4 |
| ✅ **5 fallback sources** | Resilient to GitHub changes | Level 4 |
| ✅ **SHA256 verification** | Corruption detection | Level 4 |
| ✅ **Local cache** | Speed + offline | Level 4 |
| ✅ **CI cache** | ~70% faster in release | Level 4 |
| ✅ **Delegation** | Centralized code, easier maintenance | Level 4 |
| ✅ **Retry logic** | 3 attempts on transient failure | Level 4 |
| ✅ **Better error logging** | Track source + attempts | Level 4 |

---

## 2. Single Source of Truth

### 2.1 The Central File

**Path:** `proxy/dnscrypt-proxy.version`

**Content:**
```text
2.1.18
```
*Single line only — no comments, no spaces.*

### 2.2 Who Reads This File?

```text
┌─────────────────────────────────────────────┐
│  proxy/dnscrypt-proxy.version               │
│  (2.1.18)                                    │
└──────────────┬──────────────────────────────┘
               │
    ┌──────────┼──────────┬──────────────┐
    ▼          ▼          ▼              ▼
┌────────┐ ┌────────┐ ┌──────────────┐ ┌─────────┐
│ fetch  │ │package │ │ release.yml  │ │ ci.yml  │
│ _dns   │ │_module │ │  (verify +   │ │(verify) │
│ .sh    │ │.sh     │ │   package)   │ │         │
└────────┘ └────────┘ └──────────────┘ └─────────┘
```

### 2.3 Upgrade Scenario

**Before Level 4:**
```bash
# Edit 5 files manually
sed -i 's/2.1.5/2.1.18/' scripts/package_module.sh
sed -i 's/2.1.5/2.1.18/' .github/workflows/release.yml
# ... 3 more files ...
```

**After Level 4:**
```bash
# Edit one file
echo "2.1.18" > proxy/dnscrypt-proxy.version
```
> **🎯 Everything else updates automatically.**

---

## 3. How It Works

### 3.1 General Flow

```text
┌──────────────────────────────────────────────────────────┐
│  [1] Read the version                                     │
│      proxy/dnscrypt-proxy.version → "2.1.18"              │
└───────────────────────┬──────────────────────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────┐
│  [2] Check Cache                                          │
│      ~/.cache/dnscrypt-proxy-webui/dns-binaries/          │
│      ├── dnscrypt-proxy-arm64       ✅                    │
│      ├── dnscrypt-proxy-arm         ✅                    │
│      ├── dnscrypt-proxy-x86_64      ✅                    │
│      ├── dnscrypt-proxy-i386        ❌ (missing)          │
│      └── .manifest.json                                   │
└───────────────────────┬──────────────────────────────────┘
                        ▼
              ┌─────────┴─────────┐
              │ Cache Complete?   │
              └─────────┬─────────┘
           ✅ Yes      │      ❌ No
              │       │       │
              ▼       │       ▼
        ┌─────────┐  │  ┌──────────────────────┐
        │ Use     │  │  │ Call fetch script    │
        │ cache   │  │  └──────────┬───────────┘
        └─────────┘  │             ▼
              │      │  ┌──────────────────────┐
              │      │  │ Try 5 fallback srcs  │
              │      │  └──────────┬───────────┘
              │      │             ▼
              │      │  ┌──────────────────────┐
              │      │  │ SHA256 verification  │
              │      │  └──────────┬───────────┘
              │      │             ▼
              │      │  ┌──────────────────────┐
              │      │  │ Save to cache +      │
              │      │  │ update manifest      │
              │      │  └──────────┬───────────┘
              │      │             │
              └──────┴─────────────┘
                        ▼
              ┌──────────────────────┐
              │ Copy to staging      │
              │ (with i386→x86 map)  │
              └──────────┬───────────┘
                        ▼
              ┌──────────────────────┐
              │ Create Magisk ZIP    │
              └──────────────────────┘
```

### 3.2 Architecture Mapping

| GitHub name | Cache name | Staging name | WebUI arch |
|---|---|---|---|
| `arm64` | `arm64` | `arm64` | `arm64` |
| `arm` | `arm` | `arm` | `arm` |
| `x86_64` | `x86_64` | `x86_64` | `amd64` |
| `i386` | `i386` | **`x86`** ⚠️ | `386` |

**⚠️ Important architectural note:**
`customize.sh` expects `dnscrypt-proxy-x86` (Android convention), but GitHub provides `i386` (Linux convention).

**Solution:** `map_to_cache_name()` in `package_module.sh`:
```bash
map_to_cache_name() {
    case "$1" in
        dnscrypt-proxy-x86)    echo "dnscrypt-proxy-i386" ;;
        dnscrypt-proxy-x86_64) echo "dnscrypt-proxy-x86_64" ;;
        dnscrypt-proxy-arm64)  echo "dnscrypt-proxy-arm64" ;;
        dnscrypt-proxy-arm)    echo "dnscrypt-proxy-arm" ;;
        *) echo "$1" ;;
    esac
}
```

---

## 4. 5 Fallback Sources

### 4.1 Order

| # | Source | Description | Status |
|:-:|---|---|:---:|
| **1** | GitHub API | Actual asset names (most accurate) | 🥇 |
| **2** | `android_X-V.zip` | Format 2.1.18+ | 🥈 |
| **3** | `android-X-V.zip` | Older format | 🥉 |
| **4** | `android_X_V.zip` | Underscore format | — |
| **5** | jsDelivr CDN | Fallback mirror | — |

### 4.2 URL Examples (for `arm64`, version `2.1.18`)

**1. GitHub API:**
```text
GET https://api.github.com/repos/DNSCrypt/dnscrypt-proxy/releases/tags/2.1.18
→ Reads the assets list
→ Extracts: dnscrypt-proxy-android_arm64-2.1.18.zip
→ Constructs URL:
https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.18/dnscrypt-proxy-android_arm64-2.1.18.zip
```

**2. Format 2.1.18+:**
```text
https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.18/dnscrypt-proxy-android_arm64-2.1.18.zip
```

**3. Older format:**
```text
https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.18/dnscrypt-proxy-android-arm64-2.1.18.zip
```

**4. Underscore format:**
```text
https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.18/dnscrypt-proxy-android_arm64_2.1.18.zip
```

**5. jsDelivr CDN:**
```text
https://cdn.jsdelivr.net/gh/DNSCrypt/dnscrypt-proxy@2.1.18/dnscrypt-proxy-android_arm64-2.1.18.zip
```

### 4.3 How the Trial Works

```bash
# The script tries in sequence
while IFS= read -r url; do
    if download_url "$url" "$tmp_file"; then
        # Succeeded → stop
        break
    fi
done < <(build_candidate_urls "$arch" "$version")
```
> **Benefit:** If GitHub changes format, the script tries another format.

### 4.4 Runtime Example

```text
$ ./scripts/fetch_dns_binaries.sh --arch arm64 --verbose

  DNS Version:  2.1.18
  Cache Dir:    ~/.cache/dnscrypt-proxy-webui/dns-binaries
  Archs:        arm64
  Mode:         download

  → arm64 → downloading (v2.1.18)...
  · API: dnscrypt-proxy-android_arm64-2.1.18.zip
  · GET https://github.com/DNSCrypt/.../dnscrypt-proxy-android_arm64-2.1.18.zip
  ✓ arm64 → 8523418 bytes (sha256: a1b2c3d4e5f6...)

━━━ Summary ━━━

  Version:  2.1.18
  Cache:    ~/.cache/dnscrypt-proxy-webui/dns-binaries

✅ All architectures ready (1/1)
```

---

## 5. Cache Structure

### 5.1 Layout

```text
~/.cache/dnscrypt-proxy-webui/dns-binaries/
├── dnscrypt-proxy-arm64          ← binary (arm64-v8a)
├── dnscrypt-proxy-arm            ← binary (armeabi-v7a)
├── dnscrypt-proxy-x86_64         ← binary (x86_64)
├── dnscrypt-proxy-i386           ← binary (i386, 32-bit)
└── .manifest.json                ← metadata (SHA256 + URL + timestamp)
```

### 5.2 `.manifest.json`

**Structure:**
```json
{
  "dnscrypt-proxy-arm64": {
    "sha256": "a1b2c3d4e5f6...",
    "version": "2.1.18",
    "url": "https://github.com/DNSCrypt/...",
    "fetched_at": "2026-09-24T10:30:00Z"
  },
  "dnscrypt-proxy-arm": { ... },
  "dnscrypt-proxy-x86_64": { ... },
  "dnscrypt-proxy-i386": { ... }
}
```

**Benefits:**
- 📊 **Full tracking:** When and where it was fetched (`fetched_at`).
- 🔒 **SHA256:** For later verification.
- 🔄 **Cache invalidation:** If version differs → re-fetch.

### 5.3 Cache Invalidation

**When is cache rebuilt?**
| Scenario | Action |
|---|---|
| New version in `dnscrypt-proxy.version` | ✅ Re-fetch |
| `--force` | ✅ Re-fetch |
| SHA mismatch | ✅ Re-fetch |
| Size < 3 MB | ✅ Re-fetch |
| Cache complete | ⏸️ Use it |

### 5.4 Cache Size

| Binary | Approximate size |
|---|:---:|
| `dnscrypt-proxy-arm64` | ~8 MB |
| `dnscrypt-proxy-arm` | ~7 MB |
| `dnscrypt-proxy-x86_64` | ~7.5 MB |
| `dnscrypt-proxy-i386` | ~7 MB |
| **Total** | **~30 MB** |

### 5.5 Cache TTL

| Layer | TTL | Source | Reason |
|---|:---:|---|---|
| **GitHub Actions Cache** | 7 days (auto) | GitHub | Default GitHub setting |
| **Local cache** | ∞ (until `--force`) | Developer | For offline development |
| **CI cache** | Depends on `dns_version` | Workflow | Reuse between runs |

⚠️ **Note**: GitHub Actions cache is evicted after 7 days of non-use. Because the workflow runs weekly, it will not be evicted.

---

## 6. SHA256 Verification

### 6.1 Mechanism

```text
┌─────────────────────────────────────┐
│ On fetch:                            │
│   1. Download binary                │
│   2. Compute SHA256                 │
│   3. Save in .manifest.json         │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│ On use (later):                      │
│   1. Read SHA from manifest         │
│   2. Compute actual SHA             │
│   3. Compare                        │
│   ✅ Match → use                     │
│   ❌ Differ → re-fetch               │
└─────────────────────────────────────┘
```

### 6.2 Example

```bash
# 1. First fetch
$ ./scripts/fetch_dns_binaries.sh
  ✓ arm64 → 8523418 bytes (sha256: a1b2c3d4e5f6...)

# 2. Manifest
$ cat ~/.cache/.../.manifest.json | jq
{
  "dnscrypt-proxy-arm64": {
    "sha256": "a1b2c3d4e5f6...",
    "version": "2.1.18",
    ...
  }
}

# 3. Later run
$ ./scripts/fetch_dns_binaries.sh
  ✓ arm64 → cache hit (8523418 bytes)
  # ✅ SHA matches — no re-fetch

# 4. If the file is corrupted
$ echo "corrupted" > ~/.cache/.../dnscrypt-proxy-arm64
$ ./scripts/fetch_dns_binaries.sh
  ⚠ arm64: SHA mismatch — re-downloading
  → arm64 → downloading (v2.1.18)...
  ✓ arm64 → 8523418 bytes
```

### 6.3 In Release Workflow

```yaml
- name: Verify DNS binaries SHA256
  run: |
    # Computes SHA for each binary in cache
    # Compares with manifest
    # Fails the workflow if different
```
> **Benefit:** Prevents publishing a ZIP with corrupted binaries.

### 6.4 Commands

```bash
# Check SHA manually
sha256sum ~/.cache/dnscrypt-proxy-webui/dns-binaries/dnscrypt-proxy-arm64

# Compare with manifest
jq -r '."dnscrypt-proxy-arm64".sha256' ~/.cache/.../.manifest.json

# Force re-fetch (on SHA mismatch)
./scripts/fetch_dns_binaries.sh --force --verbose

# In package_module.sh (on upgrade)
./scripts/package_module.sh --version v1.0.0 --force 2>/dev/null || \
  ./scripts/fetch_dns_binaries.sh --force
```

---

## 7. Retry Logic

### 7.1 The Problem

If `fetch_dns_binaries.sh` fails, the workflow fails **immediately** without retry.

**Common causes of transient failure**:
- GitHub API rate limit (60 requests/hour without token).
- Transient network timeout.
- Temporary CDN issue.
- Momentary DNS resolution failure.

### 7.2 The Solution

Retry logic (3 attempts) with exponential backoff (5s, 10s).

**Backoff schedule:**

| Attempt | Delay before | Total time |
|:---:|---|:---:|
| 1 | — | 0s |
| 2 | 5s | 5s |
| 3 | 10s | 15s |
| (fail) | — | exit 1 |

### 7.3 Why Exponential (Not Fixed)?

**Reason:**
- **Transient failures** need time to recover.
- **Rate limits** often need 60s+ to recover.
- **Exponential backoff** = industry standard (RFC 7231 §7.1.3).

### 7.4 Examples

**Success on attempt 1:**
```text
→ Attempt 1/3...
  ✓ arm64 → cache hit
  ✓ arm → cache hit
  ...
::notice::✅ Fetch succeeded on attempt 1
```

**Success on attempt 2** (transient rate limit):
```text
→ Attempt 1/3...
  ⚠ GitHub API failed (rate limit)
  ✗ arm64: all sources failed
::warning::Attempt 1 failed
→ Waiting 5s before retry...
→ Attempt 2/3...
  ✓ arm64 → 8523418 bytes
  ...
::notice::✅ Fetch succeeded on attempt 2
```

**All attempts failed:**
```text
→ Attempt 1/3...
::warning::Attempt 1 failed
→ Waiting 5s before retry...
→ Attempt 2/3...
::warning::Attempt 2 failed
→ Waiting 10s before retry...
→ Attempt 3/3...
::warning::Attempt 3 failed
::error::❌ All 3 attempts failed
```

### 7.5 When Retries Run

- ✅ **cache miss** (missing files).
- ✅ **force=true** (forced re-fetch).
- ❌ **cache hit** (no need).

### 7.6 Retry vs No Retry — Detail

**Before retry:**
```yaml
- name: Fetch DNS binaries
  run: |
    chmod +x scripts/fetch_dns_binaries.sh
    ./scripts/fetch_dns_binaries.sh --verbose
    # ← transient failure = full workflow failure
```

**After retry:**
```yaml
- name: Fetch DNS binaries
  run: |
    # ... retry loop with 3 attempts + exponential backoff ...
```

**Impact by failure type:**

| Scenario | Type | Before | After |
|---|:---:|:---:|:---:|
| Transient network timeout | Transient | ❌ fail | ✅ success (attempt 2) |
| Transient rate limit (429) | Transient | ❌ fail | ✅ success (attempt 3) |
| CDN hiccup | Transient | ❌ fail | ✅ success (attempt 2) |
| **Version does not exist** | **Permanent** | ❌ fail | ❌ fail (after 3 attempts) |
| **DNS resolution fail (network down)** | **Permanent** | ❌ fail | ❌ fail (after 3 attempts) |
| Cache hit | — | ✅ success | ✅ success (attempt 1) |

**Conclusion**: Retry logic handles **transient failures** only. Permanent errors (version missing) fail after 3 attempts (as they should).

---

## 8. CI Integration

### 8.1 Related Workflows

| Workflow | Role | Frequency |
|---|---|---|
| **`release.yml`** | Uses cache or fetches | On tag |
| **`ci.yml`** | Verifies presence only | Every push/PR |

### 8.2 Cache Flow

```text
┌──────────────────────────────────────────────┐
│  release.yml                                 │
│  (on push tag)                               │
│                                              │
│  1. Read DNS version                         │
│  2. Restore from cache                       │
│  3. Cache hit? → use                         │
│     Cache miss? → fetch + verify             │
│  4. Verify SHA                               │
│  5. Package into Magisk ZIP                  │
└──────────────────────────────────────────────┘
```

### 8.3 Cache Key

```yaml
key: dnscrypt-binaries-v${{ dns_version }}-${{ runner.os }}
restore-keys: |
  dnscrypt-binaries-v${{ dns_version }}-
  dnscrypt-binaries-
```

**Benefit:**
- New version → new cache.
- Same version → cache hit (~5s instead of ~30s).

### 8.4 Expected Cache Hit Rate

| Scenario | Hit Rate |
|---|:---:|
| Stable version | ~95% |
| After version change | ~0% (first time) |
| After a week | ~100% |

### 8.5 Cache Size

| Item | Size |
|---|:---:|
| 4 binaries | ~30 MB |
| `.manifest.json` | ~1 KB |
| **Total** | **~30 MB** |

**GitHub Actions cache limit**: 10 GB per repo.
**Consumption ratio**: ~0.3%.

### 8.6 Monthly Minutes Consumption

| Item | Minutes |
|---|:---:|
| cache hit (typical): ~40s | — |
| cache miss: ~2-5 min | — |
| **Weekly schedule**: ~4 runs/month × ~3 min | ~12 |
| **Additional triggers**: | ~5-10 |
| **Retry overhead (rare)**: | ~1-2 |
| **Total**: | **~20-27 minutes/month** |

**Free tier**: 2000 minutes/month → ~1.3% only.

---

## 9. Command Reference

### 9.1 `fetch_dns_binaries.sh`

```bash
# Fetch all architectures (default)
./scripts/fetch_dns_binaries.sh

# Single architecture
./scripts/fetch_dns_binaries.sh --arch arm64

# Full details
./scripts/fetch_dns_binaries.sh --verbose

# Force re-fetch (bypass cache)
./scripts/fetch_dns_binaries.sh --force

# Offline (cache only)
./scripts/fetch_dns_binaries.sh --offline

# JSON output (CI)
./scripts/fetch_dns_binaries.sh --json | jq '.summary'

# Custom cache directory
./scripts/fetch_dns_binaries.sh --cache-dir /tmp/dns-cache

# Specific version (override file)
./scripts/fetch_dns_binaries.sh --version 2.1.17

# Help
./scripts/fetch_dns_binaries.sh --help
```

### 9.2 `package_module.sh` — Flag Differences

```bash
# Full build (fetches if needed)
./scripts/package_module.sh --version v1.0.0

# --skip-dns-fetch: Skip fetch (use cache only)
./scripts/package_module.sh \
    --version v1.0.0 \
    --skip-dns-fetch

# --offline: alias for --skip-dns-fetch (same behavior)
./scripts/package_module.sh \
    --version v1.0.0 \
    --offline
```

**⚠️ Note**:
- `--skip-dns-fetch` and `--offline` are **identical** (aliases).
- Both fail if cache is incomplete (does not attempt fetch).

**Difference vs `fetch_dns_binaries.sh`**:
- `--offline` in `fetch_dns_binaries.sh`: Uses cache only (fails if incomplete).
- `--offline` in `package_module.sh`: Passes `--skip-dns-fetch` (does not call `fetch_dns_binaries.sh` at all).

```bash
# Custom cache directory
./scripts/package_module.sh \
    --version v1.0.0 \
    --dns-cache-dir /tmp/dns-cache
```

### 9.3 Manual Commands

```bash
# Read version
cat proxy/dnscrypt-proxy.version

# Change version
echo "2.1.18" > proxy/dnscrypt-proxy.version

# Check cache
ls -la ~/.cache/dnscrypt-proxy-webui/dns-binaries/

# Check manifest
cat ~/.cache/dnscrypt-proxy-webui/dns-binaries/.manifest.json | jq

# Delete cache
rm -rf ~/.cache/dnscrypt-proxy-webui/dns-binaries/

# Check SHA manually
sha256sum ~/.cache/dnscrypt-proxy-webui/dns-binaries/dnscrypt-proxy-arm64
```

### 9.4 Manual Trigger from GitHub

```bash
# Via gh CLI
gh workflow run release.yml

# Or from the web
# Actions → Release → Run workflow
```

---

## 10. Updating the Version

### 10.1 Updating dnscrypt-proxy

**Steps (4 steps):**

1. **Verify the new version**:
   ```bash
   curl -s https://api.github.com/repos/DNSCrypt/dnscrypt-proxy/releases/latest \
       | jq -r .tag_name
   ```
2. **Update the file**:
   ```bash
   echo "2.1.19" > proxy/dnscrypt-proxy.version
   ```
3. **(Optional) Update fallback in `fetch_dns_binaries.sh`**:
   ```bash
   sed -i "s/printf '2.1.18'/printf '2.1.19'/" scripts/fetch_dns_binaries.sh
   ```
   *(fallback only — will not be used if the file exists)*.
4. **Verify + push**:
   ```bash
   git add proxy/dnscrypt-proxy.version scripts/fetch_dns_binaries.sh
   git commit -m "build: bump dnscrypt-proxy to 2.1.19"
   git push origin main
   ```

> **Automatic result:**
> - ✅ `release.yml` will use the new version on next release.
> - ✅ New cache will be created.
> - ✅ Next release uses the new version.

### 10.2 Module Version Bump

Example: `v1.0.0` → `v1.0.1`:

```bash
# 1. VERSION
echo "v1.0.1" > VERSION

# 2. module.prop
sed -i 's/^version=.*/version=v1.0.1/' module.prop
sed -i 's/^versionCode=.*/versionCode=1000001/' module.prop

# 3. update.json
nano update.json

# 4. Commit
git add VERSION module.prop update.json
git commit -m "release: v1.0.1"
```
*(No relation to DNS version — this is the module version only).*

### 10.3 Difference Table

| Upgrade | What changes | Action | Affected workflows |
|---|---|---|---|
| **DNS version** (2.1.18 → 2.1.19) | `proxy/dnscrypt-proxy.version` | ✅ One file | `release.yml`, `ci.yml` |
| **Module version** (v1.0.0 → v1.0.1) | `VERSION` + `module.prop` + `update.json` | Manual edit | `ci.yml`, `release.yml` |

---

## 11. Troubleshooting

### 11.1 Common Errors

| # | Error | Cause | Solution |
|:-:|---|---|---|
| 1 | `proxy/dnscrypt-proxy.version missing` | File deleted | Create it: `echo 2.1.18 > ...` |
| 2 | `DNS version format invalid` | Wrong format | Use X.Y.Z |
| 3 | `all_sources_failed` | GitHub not responding | Check internet + GITHUB_TOKEN |
| 4 | `SHA mismatch` | File corrupted | `--force` |
| 5 | `--skip-dns-fetch` + empty cache | Contradiction | Populate cache first |
| 6 | `cache hit but wrong version` | Old cache | `--force` |
| 7 | `jq not found` | jq missing | `apt install jq` |
| 8 | `All N attempts failed` | transient failures | Increase retries |
| 9 | `429 rate-limited` | GitHub API limit | Use `GITHUB_TOKEN` |
| 10 | `github_api_failed` | GitHub API error | Fallback runs automatically |

### 11.2 Scenario: GitHub API Failed

```bash
$ ./scripts/fetch_dns_binaries.sh --verbose
  → arm64 → downloading (v2.1.18)...
  · API: https://api.github.com/...  ← failed (rate limit)
  · GET https://github.com/...  ← succeeded
  ✓ arm64 → 8523418 bytes
```
*Solution:* The script tried the second source automatically.

### 11.3 Scenario: Incomplete Cache

`package_module.sh` detects the shortage and calls `fetch_dns_binaries.sh` automatically.

### 11.4 Scenario: Rate Limit on GitHub API

```bash
# Use GITHUB_TOKEN
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
./scripts/fetch_dns_binaries.sh
```

In CI: `${{ secrets.GITHUB_TOKEN }}` is available automatically.

**Rate limits:**
- Without token: 60 req/hour.
- With token: 5000 req/hour.

### 11.5 Scenario: Retry Logic Active

**Symptom**:
```text
→ Attempt 1/3...
  ⚠ API failed
::warning::Attempt 1 failed
→ Waiting 5s before retry...
→ Attempt 2/3...
  ✓ arm64 → 8523418 bytes
::notice::✅ Fetch succeeded on attempt 2
```

**This is correct behavior** — retry solved the problem.

**If failure persists after 3 attempts**:
```bash
# 1. Check GITHUB_TOKEN
echo $GITHUB_TOKEN

# 2. Increase retries (if using a custom wrapper)

# 3. Run manually for diagnosis
GITHUB_TOKEN=$GITHUB_TOKEN ./scripts/fetch_dns_binaries.sh --verbose
```

### 11.6 Scenario: `i386` vs `x86` mismatch

**Symptom**:
```text
✗ dnscrypt-proxy-x86: cache miss
✗ arm64: cache hit
```

**Cause**: `customize.sh` expects `x86` but cache contains `i386`.

**Solution**: `map_to_cache_name()` in `package_module.sh` handles this:
```bash
map_to_cache_name "dnscrypt-proxy-x86"  # → "dnscrypt-proxy-i386"
```

**To verify**:
```bash
ls ~/.cache/dnscrypt-proxy-webui/dns-binaries/ | grep -E 'x86|i386'
```

### 11.7 Scenario: Old cache containing different version

**Symptom**: `package_module.sh` fails with `SHA mismatch` or `wrong version`.

**Solution**:
```bash
# 1. Delete old cache
rm -rf ~/.cache/dnscrypt-proxy-webui/dns-binaries/

# 2. Fetch new
./scripts/fetch_dns_binaries.sh

# 3. Verify
cat ~/.cache/dnscrypt-proxy-webui/dns-binaries/.manifest.json | jq -r '.[].version'
```

---

## 12. References

### 12.1 Project Files

| File | Description |
|---|---|
| `proxy/dnscrypt-proxy.version` | Single Source of Truth |
| `scripts/fetch_dns_binaries.sh` | Central script |
| `scripts/package_module.sh` | Calls fetch |
| `.github/workflows/release.yml` | Uses cache |
| `.github/workflows/ci.yml` | Verifies |
| `docs/ARCHITECTURE.md` | Architectural section |
| `docs/SECURITY.md` | Audit Corrections |
| **`docs/DNS_BINARIES.md`** | This file |
| **`docs/TROUBLESHOOTING.md`** | Troubleshooting |
| **`docs/GLOSSARY.md`** | Terms |

### 12.2 External Links

- [DNSCrypt/dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)
- [GitHub Releases API](https://docs.github.com/en/rest/releases/releases)
- [GitHub Actions Cache](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [jsDelivr CDN](https://www.jsdelivr.com/)
- [Exponential Backoff (AWS)](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
- [RFC 7231 §7.1.3 — Retry-After](https://datatracker.ietf.org/doc/html/rfc7231#section-7.1.3)

### 12.3 Project Documentation

- [docs/ARCHITECTURE.md](ARCHITECTURE.md) — DNS Binaries Management
- [docs/API.md](API.md) — API reference
- [docs/SECURITY.md](SECURITY.md) — Audit Corrections
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting
- [docs/GLOSSARY.md](GLOSSARY.md) — Glossary
- [docs/COMPATIBILITY.md](COMPATIBILITY.md) — Compatibility matrix
- [docs/ROADMAP.md](ROADMAP.md) — Project plan
- [CHANGELOG.md](../CHANGELOG.md) — Version history

---

## 13. Summary

### 13.1 What Level 4 Provides

| Feature | Benefit | Version |
|---|---|---|
| **Single Source of Truth** | One file for upgrade | Level 4 |
| **5 fallback sources** | High reliability | Level 4 |
| **SHA256 verification** | Guaranteed integrity | Level 4 |
| **Local cache** | Faster build | Level 4 |
| **CI cache** | ~70% improvement | Level 4 |
| **Offline mode** | Build without internet | Level 4 |
| **JSON output** | CI/CD integration | Level 4 |
| **Delegation** | Centralized maintenance | Level 4 |
| **Retry logic** | 3 attempts + exponential backoff | Level 4 |

### 13.2 Golden Rules

> **1.** Never embed the DNS version anywhere — always use `proxy/dnscrypt-proxy.version`.
>
> **2.** Never write URLs manually — use `fetch_dns_binaries.sh`.
>
> **3.** Never skip SHA256 verification.
>
> **4.** Never disable retry logic — transient failures are common.
>
> **5.** Do not delete `~/.cache/dnscrypt-proxy-webui/` without reason — it will re-fetch.
>
> **6.** Use `--offline`/`--skip-dns-fetch` in CI when binaries are ready.
>
> **7.** Use `--force` after SHA mismatch (do not delete cache manually).

### 13.3 Numbers

| Metric | Before Level 4 | After Level 4 |
|---|:---:|:---:|
| Fallback sources | 1 | **5** |
| SHA verification | ❌ | ✅ |
| Cache hit rate | 0% | **~95%** |
| CI time (release) | ~30s | **~5s** (cache hit) |
| Retry attempts | 0 | **3** |
| Files to update (version bump) | 5 | **1** |
| Manual URLs | yes | **no** |

### 13.4 Resource Consumption

| Metric | Value |
|---|:---:|
| Local cache size | ~30 MB |
| CI cache size | ~30 MB |
| CI minutes/month | ~20-27 |
| Free tier ratio (2000 min) | ~1.3% |

---

*Last updated: 2026-09-24*
*Version: v1.0.0*
*Author: gasciljh*

---

<div align="center">

**📥 Need help with DNS binaries?**

- 📖 [docs/ARCHITECTURE.md](ARCHITECTURE.md) — Architectural section
- 🆘 [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting
- 📝 [CHANGELOG.md](../CHANGELOG.md) — Version history

[⬆ Back to top](#dns-binaries--enterprise-guide-level-4)

</div>