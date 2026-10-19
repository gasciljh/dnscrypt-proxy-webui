# ADR-0001: Release Workflow

**Status**: ✅ Accepted
**Date**: 2026-09-24
**Consolidated**: 2026-10-18 (v1.5.0 Global Edition — merges ADRs 0001–0006)
**Authors**: [@gasciljh](https://github.com/gasciljh)
**Supersedes**: —
**Superseded by**: —

> This ADR consolidates six pre-consolidation decisions into one record:
> the two-branch model, automated releases, post-release sync, the unified
> PR template and its immediate reversal, and the `release-patch.sh` rename.
> The six sources are preserved as immutability history in Git; the
> surviving authoritative record is this file.

---

## Context

At the project's inception, all commits went directly to `main`. That created
three problems: an unstable `main` (users download broken releases), slow
iteration (contributors hesitate to push WIP), and no integration point
(features cannot be tested together before a release).

Releases were also fully manual — a 15–30 minute sequence of version bumps,
`versionCode` computation, `CHANGELOG` edits, tag creation, CI waits, and
artifact attachment. Each step was a typo risk, and a wrong `versionCode`
breaks user update detection silently. The cognitive cost discouraged frequent
releases.

Finally, pull requests targeting two different base branches needed clear
documentation: features go to `develop`, releases go to `main`. A single PR
template cannot serve both audiences well — feature PRs care about code
quality; release PRs care about version correctness, `CHANGELOG` completeness,
tag planning, and rollback preparedness.

**Constraints**: solo maintainer, GitHub Actions as the only CI/CD platform,
no external dependencies beyond the Go toolchain, every release must be
verifiable, the pipeline must be understandable by a future contributor.

## Decision

### 1. Two-branch model (`main` + `develop`)

- **`main`** is permanent and represents the latest released version. Direct
  pushes are forbidden. Only `release/*` and `hotfix/*` branches may merge
  into `main`. Every commit is tagged (`vX.Y.Z`) and released.
- **`develop`** is permanent and represents the integration state.
  Short-lived branches (`feature/*`, `fix/*`, `docs/*`, `chore/*`,
  `refactor/*`, `test/*`) branch from it and merge back via PRs.
- **Short-lived branches** are created per unit of work and deleted after
  merge. One branch = one purpose.
- **Never open a PR against `main`** except from `release/*` or `hotfix/*`.
- After each release, `main` is synced back into `develop` (see §3).

### 2. Automated releases (two layers)

- **Layer 1 — `scripts/release.sh` (local).** Validates SemVer, computes
  `versionCode` (`MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100`),
  updates `VERSION` / `module.prop` / `update.json` atomically, creates
  a `release: vX.Y.Z` commit, pushes an annotated tag, and rolls back on
  failure. Offers `--dry-run`, `--no-push`, `--yes`, `--skip-xnote`.
- **Layer 2 — `.github/workflows/release.yml` (remote).** Triggered by the
  tag push. Builds 4 architectures, verifies each is ELF + PIE, fetches
  the companion APK (best-effort), packages the Magisk ZIP, publishes the
  GitHub Release with 8 artifacts (module ZIP, `.sha256`, 4 binaries,
  APK, APK `.sha256`), then runs the post-release sync (§3).

**Reproducibility**: `SOURCE_DATE_EPOCH` from the last commit, `-trimpath`,
`-buildid=`. The same commit produces byte-identical binaries.

> ### Correction Notice — Signing and SBOM
>
> The original ADR-0002 proposal described **Cosign keyless signing** and
> **SBOM generation** (SPDX + CycloneDX) as shipped pipeline features.
> **Neither is implemented.**
>
> What is actually attached to each release:
>
> - **SHA-256 checksum** (`.sha256` file) — the only integrity artifact.
> - **Annotated tag** (`git tag -a`) — **not** a signed tag (`git tag -s`).
> - **GitHub Actions run log** — the build provenance.
>
> Users who need to verify a release today should rely **only** on the
> SHA-256 checksum. A future ADR will either formally drop Cosign/SBOM or
> re-affirm them with a concrete implementation plan. Tracked in
> `ROADMAP.md` §2.

### 3. Post-release sync (`main → develop`)

The final step of `release.yml`. Runs after the release is publicly published,
so we never sync `develop` with a failed build.

- **`continue-on-error: true`** — a sync failure never fails the release.
- **`--ff-only` first** — preserves linear history when possible.
- **Regular merge as fallback** — handles divergent `develop`.
- **`git merge --abort` + `exit 0`** — clean recovery on conflict.
- **Manual `make sync`** is required for `hotfix/*` releases, because
  `release.yml` cannot distinguish a hotfix tag from a regular tag.

### 4. PR templates (unified + release-specific)

- **`.github/PULL_REQUEST_TEMPLATE.md`** (default) — for `feature/*`,
  `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `test/*` PRs targeting
  `develop`. Includes a `🎯 Target Branch` section handling the two-branch
  model.
- **`.github/PULL_REQUEST_TEMPLATE/release.md`** — for `release/*` and
  `hotfix/*` PRs targeting `main`. Version-first layout; pre-flight
  checklist for version consistency; post-merge tag/sync plan; rollback
  plan; release-specific reviewer checklist.
- **Selection**: GitHub only auto-applies the default. Release PRs are
  opened with `?template=release.md`. This is documented in
  `CONTRIBUTING.md` §5.4 and §11.

**Reversal history**: ADR-0004 initially adopted a single unified template,
then reversed on the same day via ADR-0005 because release PRs and feature
PRs have different lifecycles, different risks, and different reviewer
focus. This was the **first reversal in the project's ADR history** — the
reversal is explicit and auditable, not silent. The default template
remains the unified one; the release template is selected by URL.

### 5. Naming: `release.sh` + `release-patch.sh`

The primary release script is `scripts/release.sh`. Its sibling is
`scripts/release-patch.sh` (renamed from `scripts/hotfix.sh`).

- **Prefix `release-`** — aligns the two scripts visually and alphabetically.
- **Suffix `-patch`** — describes the exact SemVer component the script
  increments (`PATCH`).
- **`hotfix/*` branch prefix remains** — aligns with Git Flow terminology.
  Each name lives in the domain where it belongs.

`release-patch.sh` enforces 3 safety rules: branch must be `main`, `MAJOR`
and `MINOR` must not change, `PATCH` must be exactly `current + 1`. It
delegates all bump logic to `release.sh`.

## Consequences

### Positive

- ✅ `main` is always deployable. Every commit is a tagged release.
- ✅ Features develop in isolation. A broken feature cannot affect other work.
- ✅ Releases take ~5 minutes instead of 15–30. `versionCode` is computed once.
- ✅ Reproducible builds. Same commit → same SHA-256.
- ✅ Zero manual toil on the sync step. `develop` never diverges from `main`.
- ✅ Focused review per PR type. Feature and release checklists do not mix.
- ✅ Validated across **six release cycles** (v1.0.0 through v1.5.0) without
  branch-protection bypasses or manual sync interventions.

### Negative

- ❌ Two branches to maintain. Mitigated by automatic sync.
- ❌ Two-layer release tooling. Contributors must understand that
  `release.sh` handles versioning and `release.yml` handles building.
- ❌ No Cosign signature and no SBOM. Downstream audit relies on the SHA-256
  checksum and manual `go.mod` / `dnscrypt-proxy.version` review.
- ❌ Two PR templates. Any change to the branch policy or the release process
  must be reflected in both files.
- ❌ Recovering from a bad tag is manual (delete tag, fix, re-tag, re-push).
- ❌ First-run cold cache costs ~3–4 minutes (NDK download).

### Neutral

- ⚪ Tag-based trigger. A tag push is the only automatic path to a release;
  `workflow_dispatch` supports manual re-publish.
- ⚪ The sync commit only appears when `develop` has diverged. In the common
  case it is a fast-forward push with no new commit.
- ⚪ `SOURCE_DATE_EPOCH` relies on the commit timestamp being stable — true
  as long as history is not rewritten.

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| Trunk-based development (single `main`) | Requires feature flags for WIP; a broken PR blocks all work; too aggressive for a solo-maintained project. |
| Full Git Flow (5+ branch types) | Over-engineered for one maintainer; slower feedback loops; no release trains. |
| Fully manual releases | 15–30 min per release; typo risk on `versionCode`; discourages frequent releases. |
| `semantic-release` (Node.js) | The project has no Node.js dependency; overkill for one monthly release. |
| GoReleaser | Optimized for Go binaries distributed via Homebrew/Scoop. Our artifact is a Magisk ZIP with shell scripts and web assets. |
| Fully automated remote-only release | Loses the local dry-run and rollback safety net. |
| Manual post-release sync | Defeats the purpose of automated releases; forgotten at 2 AM. |
| Separate sync workflow | Cannot easily read the tag from the release; extra failure mode. |
| Single unified PR template only | Under-serves the release PR case; version correctness is buried under feature checklists. |
| Unified template with an uncommented release section | Relies on the author remembering to uncomment; error-prone. |
| Keep `hotfix.sh` name | Inconsistent prefix with `release.sh`; search confusion with the `hotfix/*` branch prefix. |

## Related Decisions

- [ADR-0002](0002-external-dependency.md) — first external Go dependency,
  shipped through the workflow described here.
- [ADR-0003](0003-layered-bootstrap.md) — shell restructuring, released and
  CI-enforced through this workflow.

## References

- **Scripts**: [`scripts/release.sh`](../../scripts/release.sh),
  [`scripts/release-patch.sh`](../../scripts/release-patch.sh).
- **Workflow**: [`.github/workflows/release.yml`](../../.github/workflows/release.yml).
- **PR templates**:
  [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md),
  [`.github/PULL_REQUEST_TEMPLATE/release.md`](../../.github/PULL_REQUEST_TEMPLATE/release.md).
- **Narrative**: `CONTRIBUTING.md` §5 (branch strategy), §6 (commit
  convention), §11 (release process), §12 (branch protection), §13 (hotfix
  flow); `REFERENCE.md` §3.12 (`install_app.sh` contract and release
  artifacts); `CHANGELOG.md` §[v1.0.0] through §[v1.5.0].
- **External**: [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html),
  [Conventional Commits](https://www.conventionalcommits.org/),
  [Reproducible Builds](https://reproducible-builds.org/),
  [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow).

---

*This ADR is immutable. To reverse or amend it, create a new ADR that
supersedes it and update its Status line.*