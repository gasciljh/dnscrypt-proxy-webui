# DNS Binaries — Enterprise Guide (Level 4)

> Comprehensive guide to fetching, caching, and verifying
> `dnscrypt-proxy` binaries in DNSCrypt Smart Filter.

**Version**: v1.4.0
**Last updated**: 2026-10-08
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **Identifier inventory in this file (6 total)**:
>   • HARD-DNS-01 (`Last updated` correction — v1.4.0)
>   • HARD-DNS-02 (§8.1 `upgrade-test.yml` trigger corrected —
>     `workflow_dispatch` only, not "Manual + weekly" — v1.4.0)
>   • HARD-DNS-03 (header + middle + footer `Last updated`
>     synchronized — v1.4.0)
>   • HARD-DNS-04 (§8.7 v1.2.0 workflow additions — expanded —
>     v1.4.0)
>   • HARD-DNS-05 (v1.3.0 block retained and confirmed correct —
>     v1.4.0)
>   • HARD-DNS-06 (v1.4.0 companion APK orthogonality note
>     retained — v1.4.0)
>
> **Cross-references**:
>   • [docs/ARCHITECTURE.md](ARCHITECTURE.md) — DNS Binaries
>     Management (§14)
>   • [docs/API.md](API.md) — API reference
>   • [docs/SECURITY.md](SECURITY.md) — Audit Corrections
>   • [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting
>   • [docs/GLOSSARY.md](GLOSSARY.md) — Glossary
>   • [docs/COMPATIBILITY.md](COMPATIBILITY.md) — Compatibility
>     matrix
>   • [docs/UPGRADE.md](UPGRADE.md) — Version upgrade guide
>   • [docs/BACKUP.md](BACKUP.md) — Backup system reference (v1.2.0)
>   • [docs/EMERGENCY.md](EMERGENCY.md) — Emergency recovery (v1.2.0)
>   • [docs/ROADMAP.md](ROADMAP.md) — Project plan
>   • [CHANGELOG.md](../CHANGELOG.md) — Version history
>   • [dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) —
>     Companion Android app repository (v1.4.0)

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • `Last updated` reflects the v1.4.0 file-editing date
>     (2026-10-08).
>   • **No change to the DNS-binaries pipeline.** The DNS version
>     (`proxy/dnscrypt-proxy.version`) stays at `2.1.18`.
>   • **Companion Android app integration** — the module ZIP may
>     now include `web/app-debug.apk`. The APK is fetched by a
>     **separate** script (`scripts/fetch_app_apk.sh`) and has
>     **no relation** to the DNS-binaries pipeline. See §8.8 for
>     the distinction.
>   • §12.3 (Project Documentation) extended with the companion
>     app repository.
>   • §13.5 (Version History) extended with a v1.4.0 row.
>   • **Encoding correction (this revision)**: every mojibake
>     sequence (e.g. `вҖ”` instead of `—`, `вҶ’` instead of `→`)
>     has been replaced with proper UTF-8.

> **v1.3.0 changes**:
>   • Version bumped from v1.2.0 to v1.3.0.
>   • **No change to the DNS-binaries pipeline.** The DNS version
>     stayed at `2.1.18`.
>   • The v1.3.0 release was a **client-side + boot-flow** release:
>       - PWA install button (WebUI)
>       - Live status LED on the Today counter (WebUI)
>       - DNS auto-start after boot (`service.sh` §[19])
>     None of these touch the fetch / cache / verify pipeline.
>   • **Server-side rotation refinements** — the v1.3.0 release
>     ALSO refined the snapshot-detection and rotation semantics
>     that underpin the persistent backup directory
>     (SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME,
>     ROT-PROTECT). Those refinements touched `main.go`,
>     `functions.sh`, and 6 other shell scripts. **They do NOT
>     affect the DNS-binaries pipeline** — that pipeline is
>     independent of the backup layer and does not read the
>     snapshot directory.

> **v1.2.0 changes** (kept for reference):
>   • Version bumped from v1.1.0 to v1.2.0.
>   • `Last updated` reflects the v1.2.0 release date.
>   • **Important note**: the upstream DNS version
>     (`proxy/dnscrypt-proxy.version`) stays at `2.1.18` in
>     v1.2.0. The v1.2.0 release was a data-preservation release
>     and did **not** bump the DNS version — only the module
>     version.
>   • §2.5 (v1.2.0 Example) reaffirms the version-separation
>     rule: the module version and the DNS version are
>     independent.
>   • §8 (CI Integration) updated:
>       - §8.1 (Related Workflows) — new row for `upgrade-test.yml`.
>       - §8.3 (Cache Key) — note on v1.2.0 ↔ v1.1.0 cache reuse.
>       - §8.7 (new) — v1.2.0 Workflow Additions: no impact on
>         the DNS-binaries pipeline.
>   • §9 (Command Reference) examples updated from `v1.0.0` to
>     `v1.2.0`.
>   • §10 (Updating the Version) — examples updated to reflect
>     the v1.2.0 release cycle.
>   • §11.8 (new) — v1.2.0 Specific: No Impact on DNS Binaries.
>   • §12.3 (Project Documentation) extended with:
>       - [`docs/BACKUP.md`](BACKUP.md)
>       - [`docs/EMERGENCY.md`](EMERGENCY.md)
>       - [`docs/UPGRADE.md`](UPGRADE.md)
>   • §13.5 (Version History) extended with a v1.2.0 row.

> **v1.4.0 — Corrections in this revision**:
>   • 🔧 **HARD-DNS-01 + HARD-DNS-03** — `Last updated` corrected
>     in all three locations (the header metadata block, the
>     `**Last updated**` line inside the intro blockquote, and
>     the trailing `*Last updated:*` line). All three now read
>     `2026-10-08`, matching every other file in the v1.4.0
>     module.
>   • 🔧 **HARD-DNS-02** — §8.1 (Related Workflows): the
>     `upgrade-test.yml` row incorrectly described the trigger
>     frequency as "Manual + weekly". The actual workflow is
>     **`workflow_dispatch` only** (manual), as documented in
>     its own header. The row now reads "Manual
>     (`workflow_dispatch`)".
>   • 🟡 **HARD-DNS-04** — §8.7 (v1.2.0 Workflow Additions)
>     expanded with the v1.3.0 rotation refinements and the
>     v1.4.0 companion APK additions, and a cross-reference to
>     §8.8.
>   • 🟢 **HARD-DNS-05** — v1.3.0 block confirmed correct and
>     retained (no change needed beyond adding a note about the
>     rotation refinements being orthogonal).
>   • 🟢 **HARD-DNS-06** — v1.4.0 companion APK orthogonality
>     note retained.

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

**Three versions coexist in the project** — do not confuse them:

| Version | Source file | Value in v1.4.0 |
|---|---|:---:|
| **DNS version** (upstream) | `proxy/dnscrypt-proxy.version` | `2.1.18` |
| **Module version** (this project) | `VERSION` | `v1.4.0` |
| **Companion app version** (v1.4.0) | `proxy/app-apk.version` | `1.0.0` |

- The **DNS version** changes only when upstream ships a new release.
- The **module version** changes with each project release.
- The **companion app version** changes only when the companion
  repository publishes a new APK.
- All three are **independent**.

**v1.2.0 / v1.3.0 / v1.4.0 reaffirmation**: None of these releases
bumped the DNS version. The DNS version stays at `2.1.18`, identical
to v1.1.0.

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
| ✅ **CI cache** | ~83% faster in release (~30s → ~5s) | Level 4 |
| ✅ **Delegation** | Centralized code, easier maintenance | Level 4 |
| ✅ **Retry logic** | 3 attempts on transient failure | Level 4 |
| ✅ **Better error logging** | Track source + attempts | Level 4 |

**Orthogonality with v1.1.0 / v1.2.0 / v1.3.0 / v1.4.0 runtime additions**:

- The **v1.1.0** additions (MEM-1 dynamic memory limit, MEM-2
  extended `shellQuote`, MEM-3 `MONITORING_UI_PORT` constant)
  live in `main.go` and the shell scripts.
- The **v1.2.0** additions (10 data-preservation layers) live in
  `customize.sh`, `functions.sh`, `service.sh`, `status.sh`,
  `uninstall.sh`, and `main.go`.
- The **v1.3.0** additions (PWA install button, live status LED,
  DNS auto-start after boot, **rotation refinements
  SNAP-*/ROT-***) live in `web/index.html`, `proxy/service.sh`,
  `proxy/main.go`, and the shell scripts that mirror the rotation
  semantics.
- The **v1.4.0** additions (companion APK integration, CodeQL fix,
  iOS PWA removal) live in `web/app-debug.apk` (asset),
  `scripts/fetch_app_apk.sh`, and `proxy/main.go`.

**None of these** touch the DNS-binaries pipeline. This document
remains valid across the entire v1.0.0 → v1.1.0 → v1.2.0 → v1.3.0
→ v1.4.0 chain.

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
┌────────────────────────────────────────────────────────────┐
│  proxy/dnscrypt-proxy.version                              │
│  (2.1.18)                                                  │
└──────────────────────┬─────────────────────────────────────┘
                       │
    ┌──────────────────┼──────────────────┐
    ▼                  ▼                  ▼
┌────────┐       ┌───────────┐      ┌───────────┐
│ fetch  │       │ package   │      │ release.yml│
│ _dns   │       │ _module   │      │  (verify +│
│ .sh    │       │ .sh       │      │   package)│
└────────┘       └───────────┘      └───────────┘
                  │
                  ▼
           ┌───────────┐
           │ ci.yml    │
           │ (verify)  │
           └───────────┘
```

**v1.2.0 / v1.3.0 / v1.4.0 note**: No new consumer was added in any
of these cycles. The 10 defensive layers, the rotation refinements
(SNAP-*/ROT-*), the PWA install button, and the companion APK
integration do **not** read this file.

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

### 2.4 v1.1.0 Example — DNS Version Stays the Same

The v1.1.0 module release **did not change** the DNS version:

```bash
# Before v1.1.0 release
cat VERSION                          # v1.0.0
cat proxy/dnscrypt-proxy.version     # 2.1.18

# After v1.1.0 release
cat VERSION                          # v1.1.0
cat proxy/dnscrypt-proxy.version     # 2.1.18  ← unchanged
```

### 2.5 v1.2.0 Example — DNS Version Stays the Same

The v1.2.0 module release **did not change** the DNS version
either:

```bash
# Before v1.2.0 release
cat VERSION                          # v1.1.0
cat proxy/dnscrypt-proxy.version     # 2.1.18

# After v1.2.0 release
cat VERSION                          # v1.2.0
cat proxy/dnscrypt-proxy.version     # 2.1.18  ← unchanged
```

**Why?** The v1.2.0 release was a **data-preservation release**:

- 10 defensive layers.
- 4 runtime additions in `main.go` (BAK-1..BAK-4).
- 2 correctness fixes (FIX-1, FIX-2).
- Bilingual WebUI (client-side only).
- **No changes to the encrypted DNS engine or its binaries.**

### 2.6 v1.3.0 Example — DNS Version Stays the Same

The v1.3.0 module release **did not change** the DNS version:

```bash
# Before v1.3.0 release
cat VERSION                          # v1.2.0
cat proxy/dnscrypt-proxy.version     # 2.1.18

# After v1.3.0 release
cat VERSION                          # v1.3.0
cat proxy/dnscrypt-proxy.version     # 2.1.18  ← unchanged
```

**Why?** The v1.3.0 release was a **client-side + boot-flow +
rotation-refinement** release:

- PWA install button (WebUI).
- Live status LED (WebUI).
- DNS auto-start after boot (`service.sh` §[19]).
- Rotation refinements (SNAP-*/ROT-*) — **orthogonal to DNS
  binaries**.
- **No changes to the encrypted DNS engine or its binaries.**

### 2.7 v1.4.0 Example — DNS Version Stays the Same

The v1.4.0 module release **did not change** the DNS version:

```bash
# Before v1.4.0 release
cat VERSION                          # v1.3.0
cat proxy/dnscrypt-proxy.version     # 2.1.18

# After v1.4.0 release
cat VERSION                          # v1.4.0
cat proxy/dnscrypt-proxy.version     # 2.1.18  ← unchanged
```

**Why?** The v1.4.0 release added a **companion Android app** —
an **additive asset** that has **no relation** to the DNS-binaries
pipeline. The DNS engine itself is unchanged.

**Rule**: Only update `proxy/dnscrypt-proxy.version` when the
**upstream** `dnscrypt-proxy` project ships a new release (see §10).

---

## 3. How It Works

### 3.1 General Flow

```text
┌────────────────────────────────────────────────────────┐
│  [1] Read the version                                  │
│      proxy/dnscrypt-proxy.version → "2.1.18"           │
└────────────────────┬───────────────────────────────────┘
                     ▼
┌────────────────────────────────────────────────────────┐
│  [2] Check Cache                                       │
│      ~/.cache/dnscrypt-proxy-webui/dns-binaries/       │
│      ├── dnscrypt-proxy-arm64       ✅                 │
│      ├── dnscrypt-proxy-arm         ✅                 │
│      ├── dnscrypt-proxy-x86_64      ✅                 │
│      ├── dnscrypt-proxy-i386        ❌ (missing)       │
│      └── .manifest.json                                │
└────────────────────┬───────────────────────────────────┘
                     ▼
              ┌──────────────┐
              │ Cache Complete? │
              └──────┬───────┘
           ✅ Yes     │      ❌ No
              │       │       │
              ▼       │       ▼
        ┌──────────┐  │  ┌────────────────┐
        │ Use      │  │  │ Call fetch script│
        │ cache    │  │  └────────┬───────┘
        └──────────┘  │           ▼
              │       │  ┌────────────────┐
              │       │  │ Try 5 fallback │
              │       │  │     sources    │
              │       │  └────────┬───────┘
              │       │           ▼
              │       │  ┌────────────────┐
              │       │  │ SHA256 verify  │
              │       │  └────────┬───────┘
              │       │           ▼
              │       │  ┌────────────────┐
              │       │  │ Save to cache +│
              │       │  │ update manifest│
              │       │  └────────┬───────┘
              │       │           │
              └───────┴───────────┘
                      ▼
              ┌────────────────┐
              │ Copy to staging│
              │ (i386→x86 map) │
              └────────┬───────┘
                       ▼
              ┌────────────────┐
              │ Create Magisk ZIP│
              └────────────────┘
```

### 3.2 Architecture Mapping

| GitHub name | Cache name | Staging name | WebUI arch |
|---|---|---|---|
| `arm64` | `arm64` | `arm64` | `arm64` |
| `arm` | `arm` | `arm` | `arm` |
| `x86_64` | `x86_64` | `x86_64` | `amd64` |
| `i386` | `i386` | **`x86`** ⚠️ | `386` |

**⚠️ Important architectural note:**
`customize.sh` expects `dnscrypt-proxy-x86` (Android convention), but
GitHub provides `i386` (Linux convention).

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

**5. jsDelivr CDN (small files only):**
```text
    # NOTE: jsDelivr's /gh/ endpoint serves files from the
    # git tree, not release assets. Release ZIP files
    # (dnscrypt-proxy-android_*-*.zip) are NOT in the git
    # tree and are therefore NOT served by jsDelivr.
    #
    # If fetch_dns_binaries.sh uses jsDelivr, it is only for
    # small files (e.g. .version, .minisig). Verify against
    # the actual script before relying on this URL.
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
    "fetched_at": "2026-10-06T10:30:00Z"
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

⚠️ **Note**: GitHub Actions cache is evicted after 7 days of non-use.
Because the workflow runs on every push and PR, it will not be evicted.

**v1.2.0 / v1.3.0 / v1.4.0 note**: No change to the cache TTL policy.
The DNS version did not change, so the cache key continues to match
across all v1.x releases.

---

## 6. SHA256 Verification

### 6.1 Mechanism

```text
┌─────────────────────────────────┐
│ On fetch:                       │
│   1. Download binary            │
│   2. Compute SHA256             │
│   3. Save in .manifest.json     │
└────────────────┬────────────────┘
                 ▼
┌─────────────────────────────────┐
│ On use (later):                 │
│   1. Read SHA from manifest     │
│   2. Compute actual SHA         │
│   3. Compare                    │
│   ✅ Match → use                │
│   ❌ Differ → re-fetch          │
└─────────────────────────────────┘
```

**v1.2.0 + v1.3.0 + v1.4.0 note**: This SHA256 verification is
**distinct** from the v1.2.0 backup integrity verification (Layer 3)
and from the v1.4.0 companion APK verification:

| Verification | Target | File |
|---|---|---|
| **DNS binaries SHA256** | Downloaded `dnscrypt-proxy` binaries | `.manifest.json` in DNS cache |
| **Backup integrity SHA256** (Layer 3) | The 5 user config files | `.manifest.json` in each backup snapshot |
| **Companion APK SHA256** (v1.4.0) | The downloaded `app-debug.apk` | `.manifest.json` in the APK cache |

All three use SHA256, but they cover different artifacts and live in
different directories.

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
./scripts/package_module.sh --version v1.4.0 --force 2>/dev/null || \
  ./scripts/fetch_dns_binaries.sh --force
```

---

## 7. Retry Logic

### 7.1 The Problem

If `fetch_dns_binaries.sh` fails, the workflow fails **immediately**
without retry.

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

**Conclusion**: Retry logic handles **transient failures** only.
Permanent errors (version missing) fail after 3 attempts (as they should).

---

## 8. CI Integration

### 8.1 Related Workflows

| Workflow | Role | Trigger | v1.4.0 |
|---|---|---|---|
| **`release.yml`** | Uses cache or fetches | On tag push `v*` (or manual re-publish) | + companion APK fetch/stage |
| **`ci.yml`** | Verifies presence + metadata | Every push/PR to `main` or `develop` | + APK metadata check |
| **`upgrade-test.yml`** | 42-scenario data-preservation matrix | **Manual (`workflow_dispatch`) only** | Unchanged |
| **`codeql.yml`** | SAST — Go security analysis | Push/PR + weekly schedule | Unchanged |

**v1.4.0 clarification**: The v1.4.0 release adds two new steps to
`release.yml` — `Fetch companion Android app APK` and
`Stage APK for module ZIP`. **Neither** touches the DNS-binaries
pipeline. The `fetch_dns_binaries.sh` and `package_module.sh`
scripts are the same as in v1.3.0 for DNS purposes.

**v1.4.0 correction (HARD-DNS-02)**: The `upgrade-test.yml` trigger
is **`workflow_dispatch` only** (manual). Earlier revisions of this
document incorrectly described it as "Manual + weekly". The actual
workflow has no `schedule:` trigger — see the workflow's own header
for the rationale (the 42-scenario matrix is expensive and the
failures it originally detected were unrelated to the
data-preservation layers).

### 8.2 Cache Flow

```text
┌────────────────────────────────────────────────────────┐
│  release.yml                                           │
│  (on tag push)                                         │
│                                                        │
│  1. Read DNS version                                   │
│  2. Restore from cache                                 │
│  3. Cache hit? → use                                   │
│     Cache miss? → fetch + verify                       │
│  4. Verify SHA                                         │
│  5. Fetch companion APK (v1.4.0)                       │
│  6. Stage companion APK (v1.4.0)                       │
│  7. Package into Magisk ZIP                            │
└────────────────────────────────────────────────────────┘
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

**v1.2.0 / v1.3.0 / v1.4.0 note**: The cache key still uses
`dns_version` (which is `2.1.18` for all these releases). This means
a v1.4.0 build reuses the v1.1.0 DNS-binaries cache. This is
intentional and correct — the DNS version did not change.

### 8.4 Expected Cache Hit Rate

| Scenario | Hit Rate |
|---|:---:|
| Stable version | ~95% |
| After version change | ~0% (first time) |
| After a week | ~100% |
| **v1.4.0 vs v1.1.0** | **100%** (DNS version unchanged) |

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
| Additional triggers (pushes, PRs): | ~5-10 |
| Retry overhead (rare): | ~1-2 |
| **Total**: | **~6-12 minutes/month** |

**Free tier**: 2000 minutes/month → ~1.3% only.

### 8.7 v1.2.0 + v1.3.0 + v1.4.0 Workflow Additions — Impact on DNS Binaries

The v1.2.0, v1.3.0, and v1.4.0 releases added CI features that
**did not** affect the DNS-binaries pipeline:

**v1.2.0 additions**:

**1. `backup-smoke-test` job** (in `ci.yml`):
- Validates the 10 defensive layers.
- **Does NOT download or verify any DNS binary.**

**2. `upgrade-test.yml`** (new file):
- 42-scenario matrix.
- Uses pre-built binaries from the CI cache.
- **Does NOT re-fetch the DNS binaries.**

**v1.3.0 additions**:

No CI configuration change was required for v1.3.0. The
`backup-smoke-test` job verifies **function presence** (via grep),
not internal semantics, so the rotation refinements
(SNAP-MANIFEST + SNAP-MTIME in `main.go`; ROT-MANIFEST + ROT-MTIME
+ ROT-PROTECT in `functions.sh`; the mirrored implementations in 5
shell scripts) passed the smoke test unchanged. The
**`upgrade-test.yml`** matrix was updated separately (L9-02 / L9-03
now write `.manifest.json` files into the synthetic snapshots) — this
is documented in the workflow's own header, not here.

**v1.4.0 additions** (see also §8.8):

Two new steps in `release.yml` and one new step in `ci.yml`, all
related to the companion APK. None touch the DNS-binaries cache.

**Conclusion**: All v1.2.0 / v1.3.0 / v1.4.0 CI additions are
**orthogonal** to the DNS-binaries pipeline.

### 8.8 v1.4.0 Workflow Additions — Impact on DNS Binaries

The v1.4.0 release added **two new steps** to `release.yml` and
**one new step** to `ci.yml`, all related to the **companion APK**:

**1. `Fetch companion Android app APK`** (release.yml):
- Runs `scripts/fetch_app_apk.sh --output-dir ./dist`.
- Downloads the APK from a **separate repository**
  (`gasciljh/dnscrypt-proxy-app`).
- **Does NOT touch the DNS-binaries cache.**

**2. `Stage APK for module ZIP`** (release.yml):
- Copies `dist/DNS-Proxy-v*.apk` → `web/app-debug.apk`.
- **Does NOT touch the DNS-binaries cache.**

**3. `Verify companion app metadata`** (ci.yml):
- Validates `proxy/app-apk.version` format.
- **Does NOT touch the DNS-binaries cache.**

**Comparison table**:

| Pipeline | Script | Cache dir | Target artifact |
|---|---|---|---|
| **DNS binaries** | `scripts/fetch_dns_binaries.sh` | `~/.cache/dnscrypt-proxy-webui/dns-binaries` | `dnscrypt-proxy-*` binaries |
| **Companion APK** | `scripts/fetch_app_apk.sh` | `~/.cache/dnscrypt-proxy-webui/app` | `app-debug.apk` |

They never overlap.

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

### 9.2 `fetch_app_apk.sh` (v1.4.0) — Companion App

```bash
# Fetch the companion APK (default cache-first)
./scripts/fetch_app_apk.sh

# Custom output directory (used by release.yml)
./scripts/fetch_app_apk.sh --output-dir ./dist

# Verbose / force / offline
./scripts/fetch_app_apk.sh --verbose
./scripts/fetch_app_apk.sh --force
./scripts/fetch_app_apk.sh --offline

# JSON output (CI)
./scripts/fetch_app_apk.sh --json | jq .
```

**⚠️ Note**: This script is **separate** from
`fetch_dns_binaries.sh`. Do not confuse the two.

### 9.3 `package_module.sh` — Flag Differences

```bash
# Full build (fetches if needed)
./scripts/package_module.sh --version v1.4.0

# --skip-dns-fetch: Skip DNS fetch (use cache only)
./scripts/package_module.sh \
    --version v1.4.0 \
    --skip-dns-fetch

# --offline: alias for --skip-dns-fetch (same behavior)
./scripts/package_module.sh \
    --version v1.4.0 \
    --offline
```

**⚠️ Note**:
- `--skip-dns-fetch` and `--offline` are **identical** (aliases).
- Both fail if cache is incomplete (does not attempt fetch).

**Difference vs `fetch_dns_binaries.sh`**:
- `--offline` in `fetch_dns_binaries.sh`: Uses cache only (fails if
  incomplete).
- `--offline` in `package_module.sh`: Passes `--skip-dns-fetch`
  (does not call `fetch_dns_binaries.sh` at all).

```bash
# Custom cache directory
./scripts/package_module.sh \
    --version v1.4.0 \
    --dns-cache-dir /tmp/dns-cache
```

### 9.4 Manual Commands

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

### 9.5 Manual Trigger from GitHub

```bash
# Via gh CLI
gh workflow run release.yml

# Or from the web
# Actions → Release → Run workflow
```

### 9.6 Make Targets (v1.4.0)

```bash
# Fetch DNS binaries (via package_module.sh)
make package

# Fetch companion APK
make fetch-apk

# Validate companion APK version format
make check-app-version

# All local validations
make check-all
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
   git push origin develop
   ```

> **Automatic result:**
> - ✅ `release.yml` will use the new version on next release.
> - ✅ New cache will be created.
> - ✅ Next release uses the new version.

**⚠️ Distinction from module version**: This step updates the **DNS
version**, not the module version. See §10.2 for the module version.

### 10.2 Module Version Bump

**Example: `v1.3.0` → `v1.4.0`** (the v1.4.0 release cycle):

```bash
# 1. VERSION
echo "v1.4.0" > VERSION

# 2. module.prop
sed -i 's/^version=.*/version=v1.4.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1040000/' module.prop

# 3. update.json
nano update.json

# 4. Commit
git add VERSION module.prop update.json
git commit -m "release: v1.4.0"
```

**Important**: This step does **not** touch
`proxy/dnscrypt-proxy.version`. The DNS version stays at `2.1.18`.

**For the next release** (`v1.5.0`):
```bash
echo "v1.5.0" > VERSION
sed -i 's/^version=.*/version=v1.5.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1050000/' module.prop
```

The manual procedure above is a fallback. The recommended path is:
```bash
./scripts/release.sh v1.5.0
```
which handles all three files automatically.

### 10.3 Difference Table

| Upgrade | What changes | Action | Affected workflows |
|---|---|---|---|
| **DNS version** (2.1.18 → 2.1.19) | `proxy/dnscrypt-proxy.version` | ✅ One file | `release.yml`, `ci.yml` |
| **Module version** (v1.3.0 → v1.4.0) | `VERSION` + `module.prop` + `update.json` | Automated via `release.sh` | `ci.yml`, `release.yml` |
| **Companion app version** (1.0.0 → 1.1.0) | `proxy/app-apk.version` | ✅ One file | `release.yml`, `ci.yml` (metadata check) |

**Common confusion**: All three are called "version" in the codebase.
This table is the authoritative distinction.

### 10.4 v1.4.0 Version History

| Release | Module Version | DNS Version | Companion App | Notes |
|---|:---:|:---:|:---:|---|
| First stable | v1.0.0 | 2.1.18 | — | 33 audit corrections |
| Polish | v1.1.0 | 2.1.18 | — | MEM-1/2/3 |
| Data preservation | v1.2.0 | 2.1.18 | — | 10 layers + BAK-1..4 + FIX-1/2 |
| PWA + boot fix | v1.3.0 | 2.1.18 | — | PWA button + LED + DNS auto-start + rotation refinements |
| **Companion app** | **v1.4.0** | **2.1.18** | **1.0.0** | **Companion APK + CodeQL + iOS removal** |
| Next minor (planned) | v1.5.0 | 2.1.18 (expected) | 1.0.0 (expected) | No DNS change expected |

**Rule**: The DNS version only changes when upstream
`dnscrypt-proxy` ships a new release. It is not coupled to the module
version or the companion app version.

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

`package_module.sh` detects the shortage and calls
`fetch_dns_binaries.sh` automatically.

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

### 11.6 Scenario: `i386` vs `x86` mismatch

**Symptom**:
```text
✗ dnscrypt-proxy-x86: cache miss
✓ arm64: cache hit
```

**Cause**: `customize.sh` expects `x86` but cache contains `i386`.

**Solution**: `map_to_cache_name()` in `package_module.sh` handles
this:
```bash
map_to_cache_name "dnscrypt-proxy-x86"  # → "dnscrypt-proxy-i386"
```

**To verify**:
```bash
ls ~/.cache/dnscrypt-proxy-webui/dns-binaries/ | grep -E 'x86|i386'
```

### 11.7 Scenario: Old cache containing different version

**Symptom**: `package_module.sh` fails with `SHA mismatch` or
`wrong version`.

**Solution**:
```bash
# 1. Delete old cache
rm -rf ~/.cache/dnscrypt-proxy-webui/dns-binaries/

# 2. Fetch new
./scripts/fetch_dns_binaries.sh

# 3. Verify
cat ~/.cache/dnscrypt-proxy-webui/dns-binaries/.manifest.json | jq -r '.[].version'
```

### 11.8 Scenario: v1.2.0 / v1.3.0 / v1.4.0 — No Impact on DNS Binaries

**Symptom** (user concern): "I upgraded to v1.4.0. Do I need to
re-fetch the DNS binaries?"

**Answer**: **No.** The v1.4.0 release does **not** change the DNS
version (`proxy/dnscrypt-proxy.version` stays at `2.1.18`). The
DNS binaries cache is unchanged.

**Verify** (after installing v1.4.0):
```bash
# Module version changed
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.4.0

# DNS version unchanged
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.version" 2>/dev/null
# Expected: 2.1.18
```

**Why users may ask this**: The v1.4.0 changelog mentions the
companion app, CodeQL, and iOS removal. None of them touch the DNS
engine or its binaries.

### 11.9 Scenario: v1.4.0 — Companion APK vs DNS Binaries confusion

**Symptom** (potential confusion): "Does the companion APK share
the same cache or pipeline as the DNS binaries?"

**Answer**: **No.** They are entirely separate:

| Aspect | DNS Binaries | Companion APK (v1.4.0) |
|---|---|---|
| Script | `scripts/fetch_dns_binaries.sh` | `scripts/fetch_app_apk.sh` |
| Cache | `~/.cache/dnscrypt-proxy-webui/dns-binaries/` | `~/.cache/dnscrypt-proxy-webui/app/` |
| Version source | `proxy/dnscrypt-proxy.version` | `proxy/app-apk.version` |
| Destination | `proxy/dnscrypt-proxy-<arch>` (module ZIP) | `web/app-debug.apk` (module ZIP) |
| Source repo | `DNSCrypt/dnscrypt-proxy` | `gasciljh/dnscrypt-proxy-app` |
| Mandatory | Yes | **No** (optional) |

**They never overlap**, and neither affects the other's cache key
or workflow step.

### 11.10 Scenario: v1.4.0 — Backup directory vs DNS cache

**Symptom** (potential confusion): "Does the DNS cache and the
backup directory share the same path?"

**Answer**: **No.** They are separate:

| Directory | Purpose | Owner |
|---|---|---|
| `~/.cache/dnscrypt-proxy-webui/dns-binaries/` | DNS binaries cache (dev machine) | Developer |
| `/sdcard/dnscrypt-webui-backup/` | Backup of 5 user config files (Android device) | End user |

- The DNS cache is on the **developer's machine**.
- The backup directory is on the **Android device**.
- They never overlap.

### 11.11 Scenario: v1.3.0 rotation refinements — no DNS impact

**Symptom** (potential confusion): "Does the v1.3.0 rotation
refinement (SNAP-*/ROT-*) affect DNS binaries?"

**Answer**: **No.** The rotation refinements touched 8 files
(`main.go`, `functions.sh`, `service.sh`, `watchdog.sh`,
`status.sh`, `customize.sh`, `action.sh`, `uninstall.sh`) but
**none** of them feed the DNS-binaries pipeline. The pipelines are
independent:

- DNS binaries: `fetch_dns_binaries.sh` → `dns-binaries/` cache →
  `proxy/dnscrypt-proxy-<arch>` in the module ZIP.
- Rotation semantics: `main.go:buildBackupInfo` + 7 shell scripts
  → the persistent backup directory at
  `/sdcard/dnscrypt-webui-backup/`.

See `docs/ARCHITECTURE.md` §4.13.2 for the rotation reference and
§14 for the DNS-binaries reference.

---

## 12. References

### 12.1 Project Files

| File | Description |
|---|---|
| `proxy/dnscrypt-proxy.version` | Single Source of Truth for DNS version |
| `proxy/app-apk.version` | Single Source of Truth for companion app version (v1.4.0) |
| `scripts/fetch_dns_binaries.sh` | DNS binaries fetcher |
| `scripts/fetch_app_apk.sh` | Companion APK fetcher (v1.4.0) |
| `scripts/package_module.sh` | Calls both fetchers |
| `.github/workflows/release.yml` | Uses cache + stages APK |
| `.github/workflows/ci.yml` | Verifies metadata |
| `.github/workflows/upgrade-test.yml` | v1.2.0 42-scenario matrix |
| `docs/ARCHITECTURE.md` | Architectural section (§14 — DNS Binaries; §4.13 — rotation refinements) |
| `docs/SECURITY.md` | Audit Corrections |
| `docs/UPGRADE.md` | Version upgrade guide |
| `docs/BACKUP.md` | Backup system reference (v1.2.0) |
| `docs/EMERGENCY.md` | Emergency recovery (v1.2.0) |
| `docs/TROUBLESHOOTING.md` | Troubleshooting |
| `docs/GLOSSARY.md` | Terms |
| **`docs/DNS_BINARIES.md`** | This file |

### 12.2 External Links

- [DNSCrypt/dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)
- [GitHub Releases API](https://docs.github.com/en/rest/releases/releases)
- [GitHub Actions Cache](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [jsDelivr CDN](https://www.jsdelivr.com/)
- [Exponential Backoff (AWS)](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
- [RFC 7231 §7.1.3 — Retry-After](https://datatracker.ietf.org/doc/html/rfc7231#section-7.1.3)

### 12.3 Project Documentation

- [docs/ARCHITECTURE.md](ARCHITECTURE.md) — DNS Binaries Management (§14) + v1.3.0 rotation refinements (§4.13)
- [docs/API.md](API.md) — API reference
- [docs/SECURITY.md](SECURITY.md) — Audit Corrections
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting
- [docs/GLOSSARY.md](GLOSSARY.md) — Glossary
- [docs/COMPATIBILITY.md](COMPATIBILITY.md) — Compatibility matrix
- [docs/UPGRADE.md](UPGRADE.md) — Version upgrade guide
- [docs/BACKUP.md](BACKUP.md) — Backup system reference (v1.2.0)
- [docs/EMERGENCY.md](EMERGENCY.md) — Emergency recovery (v1.2.0)
- [docs/ROADMAP.md](ROADMAP.md) — Project plan
- [CHANGELOG.md](../CHANGELOG.md) — Version history
- [dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) —
  Companion Android app repository (v1.4.0)

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

> **1.** Never embed the DNS version anywhere — always use
> `proxy/dnscrypt-proxy.version`.
>
> **2.** Never write URLs manually — use `fetch_dns_binaries.sh`.
>
> **3.** Never skip SHA256 verification.
>
> **4.** Never disable retry logic — transient failures are common.
>
> **5.** Do not delete `~/.cache/dnscrypt-proxy-webui/` without
> reason — it will re-fetch.
>
> **6.** Use `--offline`/`--skip-dns-fetch` in CI when binaries are
> ready.
>
> **7.** Use `--force` after SHA mismatch (do not delete cache
> manually).
>
> **8.** **(v1.1.0)** Do not confuse **DNS version** (`2.1.18`) with
> **module version** (`v1.4.0`).
>
> **9.** **(v1.2.0)** Do not modify the DNS-binaries pipeline to
> accommodate the 10 defensive layers. They are orthogonal.
>
> **10.** **(v1.2.0)** Do not confuse the DNS-binaries cache with
> the persistent backup directory.
>
> **11.** **(v1.3.0)** The PWA install button, the DNS auto-start
> fix, and the rotation refinements (SNAP-*/ROT-*) do **not**
> affect the DNS-binaries pipeline.
>
> **12.** **(v1.4.0)** Do not confuse the DNS-binaries fetcher
> (`fetch_dns_binaries.sh`) with the companion APK fetcher
> (`fetch_app_apk.sh`). They are entirely separate.

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

### 13.5 Version History

| Module Version | DNS Version | Companion App | Notes |
|---|:---:|:---:|---|
| v1.0.0 | 2.1.18 | — | First stable release — Level 4 established |
| v1.1.0 | 2.1.18 | — | Polish release — DNS version unchanged |
| v1.2.0 | 2.1.18 | — | Data preservation release — DNS version unchanged |
| v1.3.0 | 2.1.18 | — | PWA + boot fix + rotation refinements — DNS version unchanged |
| **v1.4.0** | **2.1.18** | **1.0.0** | **Companion app — DNS version unchanged** |

**None of the v1.1.0 / v1.2.0 / v1.3.0 / v1.4.0 releases affected
this document's core pipeline.** All Level 4 infrastructure (5
fallback sources, SHA256, retry logic, cache) is carried forward
unchanged from v1.0.0.

### 13.6 Quick Reference Card

```bash
# DNS binaries version (Single Source of Truth)
cat proxy/dnscrypt-proxy.version                    # 2.1.18

# Companion app version (v1.4.0)
cat proxy/app-apk.version                           # 1.0.0

# Module version
cat VERSION                                         # v1.4.0

# Fetch DNS binaries
./scripts/fetch_dns_binaries.sh --verbose

# Fetch companion APK
./scripts/fetch_app_apk.sh --verbose

# Verify caches
ls -la ~/.cache/dnscrypt-proxy-webui/dns-binaries/
ls -la ~/.cache/dnscrypt-proxy-webui/app/

# Build + package (both pipelines)
make package

# Validate metadata
make check-app-version
```

---

*Last updated: 2026-10-08*
*Version: v1.4.0*
*Author: gasciljh*

---

<div align="center">

**💡 Need help with DNS binaries?**

- 📖 [docs/ARCHITECTURE.md](ARCHITECTURE.md) — Architectural section
- 🚨 [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting
- 📝 [CHANGELOG.md](../CHANGELOG.md) — Version history
- 🔄 [docs/UPGRADE.md](UPGRADE.md) — Upgrade guide
- 💾 [docs/BACKUP.md](BACKUP.md) — Backup system (v1.2.0)
- 🚨 [docs/EMERGENCY.md](EMERGENCY.md) — Emergency recovery (v1.2.0)
- 📱 [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) — Companion app (v1.4.0)

[⬆ Back to top](#dns-binaries--enterprise-guide-level-4)

</div>
