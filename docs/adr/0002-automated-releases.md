# ADR-0002: Automated Releases via `scripts/release.sh` + `release.yml`

**Status**: ✅ Accepted

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: —

**Superseded by**: —

---

> **Identifier inventory in this file (5 total)**:
>   • HARD-ADR2-01 (Correction notice for the un-implemented
>     Cosign/SBOM parts — preserved from earlier revision, v1.4.0)
>   • HARD-ADR2-02 (v1.3.0 verification block extended with the
>     five server-side rotation refinements — v1.4.0)
>   • HARD-ADR2-03 (v1.4.0 verification block extended with
>     MAIN-01 — v1.4.0)
>   • HARD-ADR2-04 (Flow diagram + Decision Specifics — release
>     artifacts count corrected from "6" to "8" consistently —
>     v1.4.0)
>   • HARD-ADR2-05 (Header + footer `Last reviewed` sync +
>     identifier inventory + cross-references added — v1.4.0)
>
> **Cross-references**:
>   • [docs/ARCHITECTURE.md §4.13](../ARCHITECTURE.md) — v1.3.0
>     server-side refinements (authoritative)
>   • [docs/COMPATIBILITY.md §10.3.5](../COMPATIBILITY.md) — on-device
>     SNAP-*/ROT-* verification procedure
>   • [docs/GLOSSARY.md](../GLOSSARY.md) — SNAP-*/ROT-* terms,
>     Rotation Guardian badge
>   • [docs/HALL_OF_FAME.md](../HALL_OF_FAME.md) — Rotation Guardian
>     + Companion App Champion badges
>   • [docs/RELEASE_PROCESS.md](../RELEASE_PROCESS.md) §8.4 —
>     signature status; §8.5 — SBOM status
>   • [CHANGELOG.md](../../CHANGELOG.md) — version history

---

> **⚠️ Correction notice (2026-10-08, v1.4.0)**:
>
> This ADR's **Decision** section (below) describes a release
> pipeline that includes **Cosign keyless signing** and **SBOM
> generation** (SPDX + CycloneDX). **Neither of these has been
> implemented in the shipped pipeline.**
>
> The actual `.github/workflows/release.yml` explicitly documents
> in its **Non-goals** section:
>
> ```text
> • No GPG signing of the tag or the artifacts.
>   The tag is created ANNOTATED by release.sh (git tag -a),
>   not signed (git tag -s).
>
> • No Cosign signature. `cosign` is not invoked anywhere.
>
> • No SBOM. A software bill of materials is not generated.
>   The SHA256 file is the only integrity artifact attached
>   to the release.
> ```
>
> **What this means in practice**:
>
>   • The **Decision** below is preserved **unchanged** as a
>     historical record of what was proposed. Amending it would
>     violate the ADR-immutability rule (see the footer of this
>     file).
>   • The **"Signing"** subsection of the Decision, the
>     **Constraints** section, the **Positive** consequences
>     (bullet "Cryptographic provenance" and "SBOM included"),
>     and the **Release verification** section **do not
>     accurately describe the shipped pipeline**.
>   • Users who need to verify a release today should rely **only**
>     on the SHA-256 checksum (`.sha256` file) attached to each
>     GitHub Release. See
>     [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §8.4
>     and §8.5 for the current status and the roadmap entries
>     tracking signing + SBOM as future work.
>   • **A superseding ADR is expected** — either to (a) formally
>     drop signing/SBOM from the decision, or (b) re-affirm the
>     intent with a concrete implementation plan. See
>     [`docs/ROADMAP.md`](../ROADMAP.md) §11.2 for the workflow
>     roadmap entry "Migrate to signed commits (GPG / Sigstore)".
>
> **Scope of this correction**: the Verification History below
> (added in this revision) accurately reflects what the shipped
> pipeline does. The "Release verification" section at the bottom
> was corrected to remove the false claims about Cosign and SBOM.

---

> **Post-Release Verification (v1.4.0 — 2026-10-06)**:
>
> This ADR was reviewed during the v1.4.0 release cycle and
> **remains in effect** for the parts that were actually
> implemented. The Cosign/SBOM parts were **not** implemented —
> see the Correction notice above.
>
> **Verification notes**:
>
>   • Five releases have been published through this automated
>     pipeline: `v1.0.0`, `v1.1.0`, `v1.2.0`, `v1.3.0`, and
>     `v1.4.0`.
>   • `scripts/release.sh` and `scripts/release-patch.sh` have
>     had **no behavioral changes** since v1.0.0.
>   • `.github/workflows/release.yml` published all five releases
>     successfully.
>   • **v1.4.0 — 8 release artifacts** (up from 6 in v1.3.0):
>     - `dnscrypt-webui-1.4.0-module.zip`
>     - `dnscrypt-webui-1.4.0-module.zip.sha256`
>     - `dnscrypt-webui-arm64` (standalone)
>     - `dnscrypt-webui-arm` (standalone)
>     - `dnscrypt-webui-amd64` (standalone)
>     - `dnscrypt-webui-386` (standalone)
>     - `DNS-Proxy-v1.0.0.apk` (companion app — OPTIONAL)
>     - `DNS-Proxy-v1.0.0.apk.sha256` (companion checksum — OPTIONAL)
>   • **v1.4.0 pipeline additions**:
>     - New step "Fetch companion Android app APK" (REL-18).
>     - New step "Stage APK for module ZIP" (REL-19).
>     - The **Fetch** step is **best-effort** — a failed fetch
>       logs a warning but does **not** fail the release.
>   • **v1.4.0 runtime / integration additions** (shipped through
>     the pipeline, but not part of the pipeline itself):
>     - **Companion Android app** (`web/app-debug.apk`, optional).
>     - **CodeQL `go/path-injection` fix** in `removeModule` —
>       `filepath.Base()` sanitization + trusted base dir.
>     - **iOS PWA logic removed** from `index.html`.
>     - **MAIN-01** — `LOG_LEVEL` loaded immediately after
>       `initPaths()` in `main.go`.
>   • Total time per release: ~4-5 minutes (v1.4.0, including
>     the companion APK fetch).
>   • **No manual intervention** was required for any of the
>     five releases.
>   • **No Cosign signature** was attached.
>   • **No SBOM** was generated.
>
> **Result**: The decision is validated by five release cycles
> including a large data-preservation release and an integration
> release with optional assets. No superseding ADR is required
> for the **core** pipeline. A **separate** superseding ADR is
> expected for the signing/SBOM portion — see the Correction
> notice above.

> **Post-Release Verification (v1.3.0 — 2026-10-02)**:
>
> This ADR was reviewed during the v1.3.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • Four releases have been published through this automated
>     pipeline: `v1.0.0`, `v1.1.0`, `v1.2.0`, and `v1.3.0`.
>   • `scripts/release.sh` and `scripts/release-patch.sh` were
>     used with no behavioral changes.
>   • `.github/workflows/release.yml` published all four releases
>     successfully.
>   • The **6 expected artifacts** were attached to each GitHub
>     Release (module.zip, .sha256, 4 binaries).
>   • **v1.3.0 changes** (client-side + shell-side +
>     server-side):
>     - **Client-side**:
>       - PWA install button (`web/index.html`).
>       - Live status LED (`web/index.html`).
>     - **Shell-side**:
>       - DNS auto-start fix (`proxy/service.sh`).
>     - **Server-side rotation refinements** — five new
>       semantics that underpin the persistent backup directory:
>         🔧 **SNAP-MANIFEST** — `main.go:buildBackupInfo()`
>           detects a snapshot by the presence of a
>           `.manifest.json` file, not by the v1.2.0 name pattern
>           (`^[0-9]{8}-[0-9]{6}-`).
>         🔧 **SNAP-MTIME** — `last_backup_name` is selected by
>           **mtime** (descending), not by lexicographic
>           directory name. Supersedes the v1.2.0 BUG-3 rule.
>         🔧 **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** —
>           `functions.sh:rotate_backups()` was rewritten with
>           the same manifest-based detection, the same mtime
>           sort, and two additional protected targets on top
>           of the 21-newest window: the `.last_stable` recovery
>           pointer and the newest install snapshot (name
>           matching `-v<digit>`).
>       The same SNAP-*/ROT-* semantics were mirrored in 5 shell
>       scripts (`service.sh`, `watchdog.sh`, `status.sh`,
>       `customize.sh`, `action.sh`) and in `uninstall.sh`.
>       See [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.13.
>   • The release pipeline itself was **unchanged** from v1.2.0.
>   • **No Cosign signature** was attached.
>   • **No SBOM** was generated.
>
> **Result**: The decision is validated by a fourth release
> cycle. No superseding ADR is required for the core pipeline.

> **Post-Release Verification (v1.2.0 — 2026-09-29)** (retained as history):
>
> This ADR was reviewed during the v1.2.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • Three releases have been published through this automated
>     pipeline: `v1.0.0` (2026-09-24), `v1.1.0` (2026-09-26), and
>     `v1.2.0` (2026-09-29).
>   • `scripts/release.sh` and `scripts/release-patch.sh` have
>     had **no behavioral changes** since v1.0.0 — only header
>     comments and documentation blocks were updated during the
>     v1.2.0 cycle. The core logic is byte-for-byte identical:
>       - `release.sh`: version bump + commit + tag + push.
>       - `release-patch.sh`: three safety rules + delegate to
>         `release.sh`.
>   • `.github/workflows/release.yml` published all three releases
>     successfully.
>   • The **6 expected artifacts** were attached to each GitHub
>     Release (module.zip, .sha256, 4 binaries).
>   • Total time per release: ~3-4 minutes (measured on the
>     `v1.2.0` run).
>   • **No manual intervention** was required for any of the three
>     releases.
>   • The v1.2.0 addition — `upgrade-test.yml` (42-scenario matrix)
>     — did **not** change the release pipeline; it runs
>     independently as a QA tool.
>   • The new `backup-smoke-test` job in `ci.yml` validated the 10
>     defensive layers before the release was cut.
>   • **No Cosign signature** was attached.
>   • **No SBOM** was generated.
>
> **Result**: The decision is validated by three release cycles
> including a large data-preservation release.

> **Post-Release Verification (v1.1.0 — 2026-09-26)** (retained as history):
>
> This ADR was reviewed during the v1.1.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • Two releases have been published through this automated
>     pipeline: `v1.0.0` (2026-09-24) and `v1.1.0` (2026-09-26).
>   • `scripts/release.sh` and `scripts/release-patch.sh` were
>     used with no behavioral changes (no modifications to their
>     core logic since v1.0.0).
>   • `.github/workflows/release.yml` published both releases
>     successfully.
>   • The 6 expected artifacts were attached to each GitHub
>     Release (module.zip, .sha256, 4 binaries).
>   • Total time per release: ~3-4 minutes (measured on the
>     `v1.1.0` run).
>   • No manual intervention was required for either release.
>   • **No Cosign signature** was attached.
>   • **No SBOM** was generated.
>
> **Result**: The decision is validated by real-world usage.

---

## Context

### The problem

Releases involve **many mechanical steps** that are easy to get
wrong:

1. Update `VERSION` (single-line, must be exact).
2. Update `module.prop` (`version` + `versionCode` — the latter
   computed from a formula).
3. Update `update.json` (3 fields that must match `module.prop`).
4. Update `CHANGELOG.md` (human-readable, but must reference the
   version).
5. Create a `release: vX.Y.Z` commit.
6. Create an annotated tag.
7. Push both the branch and the tag.
8. Wait for CI to build 4 architectures.
9. Package the Magisk ZIP.
10. Generate SHA-256.
11. Create the GitHub Release with 6 artifacts (v1.4.0: 8 — see
    below).
12. Back-merge `main` into `develop` (see
    [ADR-0003](0003-post-release-sync.md)).

Doing this manually every release:

- Takes **15-30 minutes** of focused work.
- Introduces **typo risks** (`versionCode` miscalculation, wrong
  `zipUrl`).
- Makes it **hard to recover** from mistakes (tags are hard to
  move).
- **Discourages frequent releases** — the cognitive cost is too
  high.

> **Note (v1.4.0 correction)**: An earlier revision of this
> Context section listed "**Generate SHA-256, SBOM (SPDX +
> CycloneDX), Cosign signature**" as step 10. The SBOM and Cosign
> parts were never implemented. The step is corrected above to
> list only SHA-256.

### The forces at play

| Force | Direction |
|---|---|
| **Reliability** | 🎯 High — a wrong `versionCode` breaks user updates |
| **Speed** | ⚡ High — a release should take minutes, not half a day |
| **Reproducibility** | 🔒 High — same commit → same binary (SOURCE_DATE_EPOCH) |
| **Auditability** | 📜 High — every release must be traceable |
| **Simplicity** | 🧩 Medium — do not over-engineer with third-party tools |
| **Solo maintainer** | 👤 One person, limited time |

### Constraints

- The project uses **GitHub Actions** as its CI/CD platform.
- It has **no external dependencies** beyond the Go toolchain and
  shell.
- Every release must be **verifiable** — the SHA-256 checksum is
  the current integrity artifact.
  > **Note (v1.4.0 correction)**: An earlier revision of this
  > bullet stated "Every release must be
  > **cryptographically verifiable** (Cosign keyless)". Cosign
  > was **never** implemented. The current shipped pipeline
  > provides a SHA-256 checksum only. See the Correction notice
  > above and `docs/RELEASE_PROCESS.md` §8.4.
- The pipeline must remain **understandable** by a future
  contributor.
- The project uses **Conventional Commits** for automated commit
  messages.

### Scope

This ADR covers **the automation of the release pipeline**. It does
**not** cover:

- Branch structure → see [ADR-0001](0001-two-branch-model.md).
- Post-release sync → see [ADR-0003](0003-post-release-sync.md).
- Release-specific PR templates → see
  [ADR-0005](0005-release-specific-pr-template.md).
- The rename of `hotfix.sh` → `release-patch.sh` → see
  [ADR-0006](0006-rename-hotfix-to-release-patch.md).

---

## Decision

> **We will automate releases with two complementary layers:**
>
> 1. **`scripts/release.sh`** — a local Bash script that handles
>    the mechanical version bump and pushes an annotated tag.
> 2. **`.github/workflows/release.yml`** — a GitHub Actions
>    workflow triggered by the tag, that builds, packages, and
>    publishes the release.

### Specifics

#### Layer 1: `scripts/release.sh` (local)

- **Validates** SemVer format (`vMAJOR.MINOR.PATCH[-prerelease]`).
- **Computes** `versionCode` from the formula:
  `MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100 + HOTFIX`.
- **Verifies** the branch (`develop` or `release/*`), clean
  working tree, and available tag.
- **Updates** `VERSION`, `module.prop`, and `update.json`
  atomically (via `mktemp` + `mv`).
- **Creates** a `release: vX.Y.Z` commit and an annotated tag.
- **Pushes** to `origin` (unless `--no-push`).
- **Rolls back** on failure via `trap ERR`.
- **Offers** `--dry-run` for preview.

#### Layer 2: `.github/workflows/release.yml` (remote)

Triggered by **tag push** matching `v[0-9]+.[0-9]+.[0-9]+*`:

1. Checks out the repo (with full history — needed for
   `SOURCE_DATE_EPOCH`).
2. Sets up Go 1.22 and Android NDK r26b.
3. Determines the version from the tag.
4. Verifies the tag exists (on `workflow_dispatch` only).
5. Builds 4 architectures (`arm64`, `arm`, `amd64`, `386`).
6. Verifies each binary is **ELF** and **PIE**.
7. **(v1.4.0)** Fetches the companion Android app APK
   (best-effort).
8. **(v1.4.0)** Stages the APK at `web/app-debug.apk` before
   packaging.
9. Packages the Magisk ZIP with `scripts/package_module.sh`.
10. Uploads artifacts as a workflow backup (30-day retention).
11. Extracts the CHANGELOG section for release notes.
12. Creates the GitHub Release with **8 files** (v1.4.0):
    - `dnscrypt-webui-<version>-module.zip`
    - `dnscrypt-webui-<version>-module.zip.sha256`
    - 4 standalone binaries.
    - **(v1.4.0, OPTIONAL)** `DNS-Proxy-v<app-ver>.apk`
    - **(v1.4.0, OPTIONAL)** `DNS-Proxy-v<app-ver>.apk.sha256`
13. **Auto-syncs** `main → develop` (see
    [ADR-0003](0003-post-release-sync.md)).

#### Reproducibility guarantees

- `SOURCE_DATE_EPOCH` is set from the last commit's timestamp.
- `-trimpath` normalizes paths.
- `-buildid=` removes random build IDs.
- **Result**: the same commit produces byte-identical binaries.

#### Signing (NOT implemented)

> **⚠️ Correction (v1.4.0)**: The original Decision text below
> described signing and SBOM as shipped. **They are not
> implemented.** The text is preserved here for historical
> accuracy, with a strikethrough of the un-implemented bullets:

- ~~**Cosign keyless** (via Sigstore) — no keys to manage.~~
  **→ NOT IMPLEMENTED.**
- ~~**SBOM** in SPDX and CycloneDX formats.~~
  **→ NOT IMPLEMENTED.**

**What IS implemented today**:

- **SHA-256 checksum** (`.sha256` file) — the only integrity
  artifact attached to each release.
- **Annotated tag** (`git tag -a`) — created by `release.sh`.
  This is **not** the same as a signed tag (`git tag -s`).

**See**:
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §8.4 —
  signature status.
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §8.5 —
  SBOM status.
- `.github/workflows/release.yml` §Non-goals — the source of
  truth for what is and is not done.

### Flow diagram

```text
Developer runs:
    ./scripts/release.sh v1.4.0
        │
        ├── Validates format + computes versionCode
        ├── Updates VERSION, module.prop, update.json
        ├── Creates commit "release: v1.4.0"
        ├── Creates annotated tag v1.4.0
        └── Pushes branch + tag
                    │
                    ▼
GitHub Actions (release.yml) triggers
        │
        ├── Build (4 archs) → verify PIE
        ├── Fetch companion APK (v1.4.0, best-effort)
        ├── Stage APK for module ZIP (v1.4.0)
        ├── Package (ZIP + SHA256)
        ├── Publish GitHub Release (8 files — 6 mandatory + 2 optional)
        └── Sync main → develop (ADR-0003)
                    │
                    ▼
             Release is live ✅
```

---

## Consequences

### Positive

- ✅ **Eliminates human error.** The `versionCode` formula is
  computed once and never typed by hand.
- ✅ **Consistent artifacts.** Every release contains the exact
  same set of files.
- ✅ **Reproducible builds.** Same commit → same SHA-256, allowing
  independent verification.
- ~~✅ **Cryptographic provenance.** Cosign keyless signatures
  prove the release was built by GitHub Actions on `main`.~~
  **→ NOT IMPLEMENTED.** See the Correction notice above. The
  current provenance guarantee is limited to:
  - The SHA-256 checksum published alongside the release.
  - The GitHub Actions run (visible in the Actions tab).
  - The annotated tag (`git tag -a`) created by `release.sh`.
- ~~✅ **SBOM included.** Downstream users can audit dependencies.~~
  **→ NOT IMPLEMENTED.** Downstream users must audit dependencies
  manually via `proxy/go.mod` and `proxy/dnscrypt-proxy.version`.
- ✅ **Release takes ~5 minutes.** The maintainer only runs one
  command and reviews the outcome.
- ✅ **Encourages frequent releases.** Lower cost per release means
  smaller, more focused releases.
- ✅ **Scales with the project.** Adding architectures or artifacts
  only requires editing `release.yml`.
- ✅ **(v1.4.0) Optional companion APK.** The release can ship the
  companion Android app as an optional asset — a failed fetch
  does not fail the release.

### Negative

- ❌ **Two-layer complexity.** Contributors must understand that
  `release.sh` handles versioning and `release.yml` handles
  building — they cannot see the entire pipeline in one place.
- ❌ **GitHub Actions dependency.** Releases require a GitHub-hosted
  runner. Local-only releases are not supported.
- ❌ **Recovering from a bad tag is manual.** If the workflow
  fails, the maintainer must delete the tag
  (`git push origin :refs/tags/vX.Y.Z`) and re-run.
- ❌ **`release.sh` requires Bash + jq.** Not available in minimal
  environments (mitigated by `docs/RELEASE_PROCESS.md` §6
  fallback).
- ❌ **First-run cost.** The workflow must download the NDK (~1 GB)
  on cold cache — roughly 3-4 minutes on the first run, ~30 s
  cached.
- ❌ **(v1.4.0) Companion APK adds ~3 MB** to the module ZIP and
  ~10-15 s to the release pipeline (fetch + stage).

### Neutral

- ⚪ **`release.yml` is public.** Anyone can read the release steps
  — good for transparency, not for obfuscation.
- ⚪ **Tag-based trigger.** A tag push is the only path to a
  release. Manual workflow dispatch is also supported via
  `workflow_dispatch`.
- ⚪ **`SOURCE_DATE_EPOCH`** relies on the commit timestamp being
  stable — true as long as history is not rewritten.

---

## Alternatives Considered

| Alternative | Pros | Cons | Why rejected |
|---|---|---|---|
| **Fully manual releases** (no automation) | ✅ Total control<br>✅ Zero tooling overhead | ❌ 15-30 min per release<br>❌ Typo risk (wrong `versionCode`)<br>❌ Reproducibility not enforced<br>❌ Encourages infrequent releases<br>❌ No signature or SBOM | Too risky and too slow. A single mistake in `versionCode` breaks all user updates silently. |
| **`semantic-release`** (Node.js) | ✅ Fully automatic from commits<br>✅ Mature ecosystem<br>✅ Standard Conventional Commits integration | ❌ Requires Node.js in the build environment<br>❌ Assumes NPM ecosystem conventions<br>❌ Overkill for one release per month<br>❌ Adds a config file (`release.config.js`) with no clear benefit for a Go/Shell project | The project has **no Node.js dependency**. Adding one for a single monthly task is disproportionate. |
| **GoReleaser** (Go ecosystem) | ✅ Native Go support<br>✅ Cross-platform builds<br>✅ Snapshots + release notes | ❌ Assumes a **Go binary** as the primary artifact — here the primary artifact is a **Magisk ZIP**<br>❌ Config file (`goreleaser.yml`) would need many custom hooks<br>❌ Cannot natively produce Magisk module structure | GoReleaser is optimized for **Go binaries distributed via Homebrew/Scoop/apt**. Our artifact is a **Magisk module** with shell scripts + binaries + web assets — a shape GoReleaser does not model. |
| **Fully automated `release.sh`** (no local script, only a workflow_dispatch) | ✅ Zero local tooling<br>✅ One-click in GitHub UI | ❌ Requires manual version input in the Actions UI<br>❌ Loses the local "dry-run" preview<br>❌ Harder to test locally before publishing | The local script provides a **dry-run** and **rollback** safety net that a UI-only flow cannot. |
| **Two-layer: `release.sh` + `release.yml` (chosen)** | ✅ Local dry-run + rollback<br>✅ Remote CI + SHA-256 verification<br>✅ Reproducible builds<br>✅ Scales with project<br>✅ Zero new dependencies<br>✅ Validated across 5 release cycles (v1.0.0 → v1.4.0) | ❌ Two layers to document<br>❌ Requires Bash + jq locally | — |

---

## Related Decisions

| ADR | Relationship |
|---|---|
| [ADR-0001](0001-two-branch-model.md) | The two-branch model is a prerequisite — `release.sh` refuses to run from `main`. |
| [ADR-0003](0003-post-release-sync.md) | This ADR's workflow triggers the sync defined in ADR-0003 as its final step. |
| [ADR-0004](0004-unified-pr-template.md) | The unified PR template guides contributors toward the correct branch. |
| [ADR-0005](0005-release-specific-pr-template.md) | The release-specific template complements the unified one for `main`-targeting PRs. |
| [ADR-0006](0006-rename-hotfix-to-release-patch.md) | The PATCH-release workflow reuses `release.sh` with added safety rules. |

---

## References

### Project files

- [`scripts/release.sh`](../../scripts/release.sh) — Layer 1
  implementation.
- [`scripts/release-patch.sh`](../../scripts/release-patch.sh) —
  PATCH-release wrapper (delegates to `release.sh`).
- [`scripts/package_module.sh`](../../scripts/package_module.sh) —
  the packaging step.
- [`scripts/fetch_dns_binaries.sh`](../../scripts/fetch_dns_binaries.sh) —
  the DNS binaries fetcher invoked during packaging.
- [`scripts/fetch_app_apk.sh`](../../scripts/fetch_app_apk.sh) —
  **the companion APK fetcher (v1.4.0)**.
- [`proxy/build.sh`](../../proxy/build.sh) — the cross-compilation
  driver.
- [`.github/workflows/release.yml`](../../.github/workflows/release.yml) —
  Layer 2 implementation.
- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) —
  pre-release validation + `backup-smoke-test` (v1.2.0) +
  `Verify companion app metadata` (v1.4.0).
- [`.github/workflows/upgrade-test.yml`](../../.github/workflows/upgrade-test.yml) —
  42-scenario data-preservation matrix (v1.2.0, QA tool).
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) — step-by-step
  guide for the maintainer (§8.4 signature status, §8.5 SBOM
  status).
- [`docs/UPGRADE.md`](../UPGRADE.md) — version upgrade guide
  (§3.1 covers v1.0.0 → v1.1.0; §3.2 covers v1.1.0 → v1.2.0;
  §3.3 covers v1.2.0 → v1.3.0; §3.4 covers v1.3.0 → v1.4.0).
- [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.13 — v1.3.0
  server-side rotation refinements (SNAP-*/ROT-*).
- [`docs/COMPATIBILITY.md`](../COMPATIBILITY.md) §10.3.5 — on-device
  SNAP-*/ROT-* verification procedure.
- [`docs/GLOSSARY.md`](../GLOSSARY.md) — SNAP-*/ROT-* terms,
  Rotation Guardian badge.
- [`docs/HALL_OF_FAME.md`](../HALL_OF_FAME.md) — Rotation Guardian
  + Companion App Champion badges.
- [`docs/BRANCHING.md`](../BRANCHING.md) §6 — branch protection
  rules that gate the release.
- [`docs/API.md`](../API.md) §6.1.15 — `/app-debug.apk` route
  reference (v1.4.0).

### External references

- [Reproducible Builds Project](https://reproducible-builds.org/)
- [GitHub Actions — Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)

> **Note on Sigstore / Cosign / SBOM**: These tools are **NOT**
> used by this project as of v1.4.0. See the Correction notice at
> the top of this file and
> [`docs/ROADMAP.md`](../ROADMAP.md) §11.2 for the future-work
> entry "Migrate to signed commits (GPG / Sigstore)".

### Discussion

- Initial proposal: see commit history for `scripts/release.sh`
  and `.github/workflows/release.yml`.

### Release verification

> **⚠️ Corrected in this revision (v1.4.0)**: Earlier revisions
> of this section claimed "Cosign signature: verified." and
> "SBOM: SPDX + CycloneDX generated." for every release. **These
> claims were false** — Cosign and SBOM were never implemented.
> The list below reflects what actually happened.

- **v1.0.0** (2026-09-24) — first release through this automated
  pipeline.
  - Duration: ~4 minutes.
  - Artifacts: 6 attached correctly.
  - SHA-256 checksum: verified.
  - Auto-sync `main → develop`: succeeded.
- **v1.1.0** (2026-09-26) — second release; pipeline unchanged.
  - Duration: ~3.5 minutes.
  - Artifacts: 6 attached correctly.
  - SHA-256 checksum: verified.
  - Auto-sync `main → develop`: succeeded.
  - **No manual intervention was needed** for either release.
- **v1.2.0** (2026-09-29) — third release; pipeline unchanged.
  - Duration: ~3-4 minutes.
  - Artifacts: 6 attached correctly.
  - SHA-256 checksum: verified.
  - Auto-sync `main → develop`: succeeded.
  - **Data-Preservation Release** — the 10 defensive layers,
    BAK-1..4, FIX-1/2, and WD-TOKEN all shipped through the same
    pipeline without modification.
  - **No manual intervention was needed.**
- **v1.3.0** (2026-10-02) — fourth release; pipeline unchanged.
  - Duration: ~3-4 minutes.
  - Artifacts: 6 attached correctly.
  - SHA-256 checksum: verified.
  - Auto-sync `main → develop`: succeeded.
  - **Feature Release** — the PWA install button, live status
    LED, DNS auto-start fix, **and the server-side rotation
    refinements (SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST +
    ROT-MTIME + ROT-PROTECT)** all shipped through the same
    pipeline without modification.
  - **No manual intervention was needed.**
- **v1.4.0** (2026-10-06) — fifth release; pipeline extended.
  - Duration: ~4-5 minutes (including the companion APK fetch).
  - **Artifacts: 8 attached** (6 mandatory + 2 optional APK).
  - SHA-256 checksum: verified.
  - Auto-sync `main → develop`: succeeded.
  - **Integration Release** — the companion Android app, CodeQL
    `go/path-injection` fix, iOS PWA removal, and **MAIN-01
    (`LOG_LEVEL` load order)** all shipped through the same
    pipeline, with two new steps (Fetch companion APK + Stage
    APK for module ZIP).
  - **No manual intervention was needed.**
- See `CHANGELOG.md` for the full release history.

---

*This ADR is immutable. To reverse or amend it, create a new ADR
that supersedes it and update its Status line.*

*For the current status of signing and SBOM, see the Correction
notice at the top of this file and
[`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §8.4 and §8.5.*