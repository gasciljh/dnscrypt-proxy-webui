# ADR-0002: Automated Releases via `scripts/release.sh` + `release.yml`

**Status**: ✅ Accepted

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: —

**Superseded by**: —

---

## Context

### The problem

Releases involve **many mechanical steps** that are easy to get wrong:

1. Update `VERSION` (single-line, must be exact).
2. Update `module.prop` (`version` + `versionCode` — the latter
   computed from a formula).
3. Update `update.json` (3 fields that must match `module.prop`).
4. Update `CHANGELOG.md` (human-readable, but must reference the version).
5. Create a `release: vX.Y.Z` commit.
6. Create an annotated tag.
7. Push both the branch and the tag.
8. Wait for CI to build 4 architectures.
9. Package the Magisk ZIP.
10. Generate SHA-256, SBOM (SPDX + CycloneDX), Cosign signature.
11. Create the GitHub Release with 6 artifacts.
12. Back-merge `main` into `develop` (see [ADR-0003](0003-post-release-sync.md)).

Doing this manually every release:

- Takes **15-30 minutes** of focused work.
- Introduces **typo risks** (`versionCode` miscalculation, wrong `zipUrl`).
- Makes it **hard to recover** from mistakes (tags are hard to move).
- **Discourages frequent releases** — the cognitive cost is too high.

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
- It has **no external dependencies** beyond the Go toolchain and shell.
- Every release must be **cryptographically verifiable** (Cosign keyless).
- The pipeline must remain **understandable** by a future contributor.
- The project uses **Conventional Commits** for automated commit messages.

### Scope

This ADR covers **the automation of the release pipeline**. It does **not**
cover:

- Branch structure → see [ADR-0001](0001-two-branch-model.md).
- Post-release sync → see [ADR-0003](0003-post-release-sync.md).
- Release-specific PR templates → see [ADR-0005](0005-release-specific-pr-template.md).
- The rename of `hotfix.sh` → `release-patch.sh` → see [ADR-0006](0006-rename-hotfix-to-release-patch.md).

---

## Decision

> **We will automate releases with two complementary layers:**
>
> 1. **`scripts/release.sh`** — a local Bash script that handles the
>    mechanical version bump and pushes a signed tag.
> 2. **`.github/workflows/release.yml`** — a GitHub Actions workflow
>    triggered by the tag, that builds, packages, signs, and publishes
>    the release.

### Specifics

#### Layer 1: `scripts/release.sh` (local)

- **Validates** SemVer format (`vMAJOR.MINOR.PATCH[-prerelease]`).
- **Computes** `versionCode` from the formula:
  `MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100 + HOTFIX`.
- **Verifies** the branch (`develop` or `release/*`), clean working tree,
  and available tag.
- **Updates** `VERSION`, `module.prop`, and `update.json` atomically
  (via `mktemp` + `mv`).
- **Creates** a `release: vX.Y.Z` commit and an annotated tag.
- **Pushes** to `origin` (unless `--no-push`).
- **Rolls back** on failure via `trap ERR`.
- **Offers** `--dry-run` for preview.

#### Layer 2: `.github/workflows/release.yml` (remote)

Triggered by **tag push** matching `v[0-9]+.[0-9]+.[0-9]+*`:

1. Checks out the repo (with full history — needed for `SOURCE_DATE_EPOCH`).
2. Sets up Go 1.22 and Android NDK r26b.
3. Determines the version from the tag.
4. Builds 4 architectures (`arm64`, `arm`, `amd64`, `386`).
5. Verifies each binary is **ELF** and **PIE**.
6. Packages the Magisk ZIP with `scripts/package_module.sh`.
7. Uploads artifacts as a workflow backup (30-day retention).
8. Creates the GitHub Release with 6 files:
   - `dnscrypt-webui-<version>-module.zip`
   - `dnscrypt-webui-<version>-module.zip.sha256`
   - 4 standalone binaries.
9. **Auto-syncs** `main → develop` (see [ADR-0003](0003-post-release-sync.md)).

#### Reproducibility guarantees

- `SOURCE_DATE_EPOCH` is set from the last commit's timestamp.
- `-trimpath` normalizes paths.
- `-buildid=` removes random build IDs.
- **Result**: the same commit produces byte-identical binaries.

#### Signing

- **Cosign keyless** (via Sigstore) — no keys to manage.
- **SBOM** in SPDX and CycloneDX formats.
- All artifacts are attached to the GitHub Release.

### Flow diagram

```text
Developer runs:
    ./scripts/release.sh v1.1.0
        │
        ├── Validates format + computes versionCode
        ├── Updates VERSION, module.prop, update.json
        ├── Creates commit "release: v1.1.0"
        ├── Creates tag v1.1.0
        └── Pushes branch + tag
                    │
                    ▼
GitHub Actions (release.yml) triggers
        │
        ├── Build (4 archs) → verify PIE
        ├── Package (ZIP + SHA256)
        ├── Sign (Cosign keyless) + SBOM
        ├── Publish GitHub Release (6 files)
        └── Sync main → develop (ADR-0003)
                    │
                    ▼
Release is live ✅
```

---

## Consequences

### Positive

- ✅ **Eliminates human error.** The `versionCode` formula is computed
  once and never typed by hand.
- ✅ **Consistent artifacts.** Every release contains the exact same
  set of files.
- ✅ **Reproducible builds.** Same commit → same SHA-256, allowing
  independent verification.
- ✅ **Cryptographic provenance.** Cosign keyless signatures prove
  the release was built by GitHub Actions on `main`.
- ✅ **SBOM included.** Downstream users can audit dependencies.
- ✅ **Release takes ~5 minutes.** The maintainer only runs one command
  and reviews the outcome.
- ✅ **Encourages frequent releases.** Lower cost per release means
  smaller, more focused releases.
- ✅ **Scales with the project.** Adding architectures or artifacts
  only requires editing `release.yml`.

### Negative

- ❌ **Two-layer complexity.** Contributors must understand that
  `release.sh` handles versioning and `release.yml` handles building —
  they cannot see the entire pipeline in one place.
- ❌ **GitHub Actions dependency.** Releases require a GitHub-hosted
  runner. Local-only releases are not supported.
- ❌ **Recovering from a bad tag is manual.** If the workflow fails,
  the maintainer must delete the tag (`git push origin :refs/tags/vX.Y.Z`)
  and re-run.
- ❌ **`release.sh` requires Bash + jq.** Not available in minimal
  environments (mitigated by `docs/RELEASE_PROCESS.md` §6 fallback).
- ❌ **First-run cost.** The workflow must download the NDK (~1 GB)
  on cold cache — roughly 3-4 minutes on the first run, ~30 s cached.

### Neutral

- ⚪ **`release.yml` is public.** Anyone can read the release steps —
  good for transparency, not for obfuscation.
- ⚪ **Tag-based trigger.** A tag push is the only path to a release.
  Manual workflow dispatch is also supported via `workflow_dispatch`.
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
| **Two-layer: `release.sh` + `release.yml` (chosen)** | ✅ Local dry-run + rollback<br>✅ Remote CI + signing + SBOM<br>✅ Reproducible builds<br>✅ Scales with project<br>✅ Zero new dependencies | ❌ Two layers to document<br>❌ Requires Bash + jq locally | — |

---

## Related Decisions

| ADR | Relationship |
|---|---|
| [ADR-0001](0001-two-branch-model.md) | The two-branch model is a prerequisite — `release.sh` refuses to run from `main`. |
| [ADR-0003](0003-post-release-sync.md) | This ADR's workflow triggers the sync defined in ADR-0003 as its final step. |
| [ADR-0006](0006-rename-hotfix-to-release-patch.md) | The PATCH-release workflow reuses `release.sh` with added safety rules. |

---

## References

### Project files

- [`scripts/release.sh`](../../scripts/release.sh) — Layer 1 implementation.
- [`scripts/package_module.sh`](../../scripts/package_module.sh) — the packaging step.
- [`scripts/fetch_dns_binaries.sh`](../../scripts/fetch_dns_binaries.sh) — the DNS binaries fetcher invoked during packaging.
- [`proxy/build.sh`](../../proxy/build.sh) — the cross-compilation driver.
- [`.github/workflows/release.yml`](../../.github/workflows/release.yml) — Layer 2 implementation.
- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — pre-release validation.
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) — step-by-step guide for the maintainer.
- [`docs/BRANCHING.md`](../BRANCHING.md) §6 — branch protection rules that gate the release.

### External references

- [Sigstore Cosign — Overview](https://docs.sigstore.dev/cosign/overview/)
- [SPDX Specification](https://spdx.dev/)
- [CycloneDX Specification](https://cyclonedx.org/)
- [Reproducible Builds Project](https://reproducible-builds.org/)
- [GitHub Actions — Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Conventional Commits](https://www.conventionalcommits.org/)

### Discussion

- Initial proposal: see commit history for `scripts/release.sh` and
  `.github/workflows/release.yml`.

---

*This ADR is immutable. To reverse or amend it, create a new ADR that
supersedes it and update its Status line.*