# ADR-0003: Post-Release Sync (`main → develop`)

**Status**: ✅ Accepted

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: —

**Superseded by**: —

---

## Context

### The problem

With the two-branch model adopted in [ADR-0001](0001-two-branch-model.md),
every release takes this shape:

1. `develop` accumulates features and fixes.
2. A `release/*` branch (or `develop` directly) merges into `main`.
3. A tag `vX.Y.Z` is created on `main`.
4. [ADR-0002](0002-automated-releases.md)'s workflow publishes the release.

**But then:** `develop` is now **behind** `main`.

`main` contains:
- The version bump commit (`release: vX.Y.Z`).
- Any PR-specific merge commits.
- Any release-specific fixes.

`develop` **does not** contain these commits — they were only made on
`main`. This creates **branch divergence**.

### Why divergence matters

Without a sync, the next release cycle starts from a `develop` that is
missing the previous release's commits. Consequences:

| Scenario | Result without sync |
|---|---|
| Next `release/*` PR targets `main` | Git tries to reintroduce old commits — merge conflicts |
| Contributors branch from `develop` | They miss the previous release's tag |
| `docs/BRANCHING.md` workflow breaks | The documented flow assumes `develop ≥ main` |
| Release notes become inaccurate | `main` and `develop` diverge further every cycle |

The drift compounds: **one missed sync per release**. After 6 months,
`develop` can be **dozens of commits behind** `main`, making the next
release PR merge painful.

### The forces at play

| Force | Direction |
|---|---|
| **Branch consistency** | 🎯 High — `develop` must reflect released code |
| **Zero manual toil** | ⚡ High — sync should happen automatically |
| **Failure isolation** | 🛡️ High — sync failure must never break a release |
| **Auditability** | 📜 Medium — sync commits must be traceable |
| **Simplicity** | 🧩 Medium — prefer fewer workflows |
| **Solo maintainer** | 👤 One person, forgetful at 2 AM |

### Constraints

- GitHub Actions is the only automation platform available.
- The sync must work with **branch protection rules** on `develop`.
- A failed sync must **not** roll back or block the release — the
  release is already public when sync runs.
- The sync must handle both **fast-forward** and **merge** cases.
- No external service (webhook, bot) may be required.

### Scope

This ADR covers **how and when `develop` is synced with `main`**. It does
**not** cover:

- Branch structure → see [ADR-0001](0001-two-branch-model.md).
- Release automation → see [ADR-0002](0002-automated-releases.md).
- PATCH-release flow → see [ADR-0006](0006-rename-hotfix-to-release-patch.md).

---

## Decision

> **We will embed a "Sync `main` → `develop`" step at the end of
> `.github/workflows/release.yml`, executed automatically after every
> successful release.**

### Specifics

#### Position in the pipeline

The sync is the **final step** of `release.yml`, after:

1. Build (4 architectures).
2. Verify binaries (ELF + PIE).
3. Package Magisk ZIP.
4. Upload backup artifacts.
5. Create GitHub Release.

Only when the release is **publicly published** does the sync run. This
ensures we never sync `develop` with a failed build.

#### Behavior

```yaml
- name: Sync main → develop
  if: github.event_name == 'push'
  continue-on-error: true
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

    git fetch origin main
    git fetch origin develop

    # Guard: skip if develop does not exist
    if ! git rev-parse --verify origin/develop >/dev/null 2>&1; then
      echo "::warning::develop branch missing — skipping sync"
      exit 0
    fi

    git checkout -B develop origin/develop

    # Prefer fast-forward
    if git merge origin/main --ff-only --no-edit 2>/dev/null; then
      echo "::notice::Fast-forward merge succeeded"
    else
      # Fallback: regular merge
      if ! git merge origin/main --no-edit \
           -m "chore: sync develop with main after <version> release"; then
        echo "::warning::Merge conflict — manual resolution required"
        git merge --abort || true
        exit 0
      fi
    fi

    git push origin develop
```

#### Key design choices

| Choice | Rationale |
|---|---|
| **`continue-on-error: true`** | Sync failure must never fail the release. |
| **`if: github.event_name == 'push'`** | Sync only on tag pushes, not manual `workflow_dispatch`. |
| **`--ff-only` first** | Preserves linear history when possible. |
| **Regular merge as fallback** | Handles the case where `develop` has diverged. |
| **`git merge --abort` + `exit 0`** | Clean recovery on conflict. |
| **`github-actions[bot]`** | Standard bot identity for CI commits. |
| **Guard for missing `develop`** | Prevents workflow failure before the branch exists. |

#### Trigger path

```text
Tag push (vX.Y.Z)
        │
        ▼
release.yml triggers
        │
        ├── Build (4 archs)
        ├── Package ZIP
        ├── Create GitHub Release ✅ (release is now live)
        │
        ▼
Sync main → develop
        │
        ├── Success → develop is up-to-date ✅
        │
        └── Failure → warning only, release still succeeded ✅
```

### What the sync does NOT do

- ❌ It does **not** fail the release on conflict.
- ❌ It does **not** force-push `develop`.
- ❌ It does **not** run on `workflow_dispatch` triggers.
- ❌ It does **not** re-build or re-verify anything.
- ❌ It does **not** touch `main` (only reads it).

---

## Consequences

### Positive

- ✅ **Zero manual toil.** The maintainer never runs `git merge origin/main`
  by hand after a release.
- ✅ **No compound drift.** Every release leaves `develop` exactly one
  commit ahead of `main` (or identical).
- ✅ **Predictable next release.** The next `release/*` PR starts from
  a synced `develop`.
- ✅ **Contributor clarity.** New contributors branching from `develop`
  get the latest released code.
- ✅ **Failure isolation.** A bug in the sync step never affects the
  published release.
- ✅ **Audit trail.** Sync commits are visible in the log with a
  descriptive message and the standard bot identity.

### Negative

- ❌ **Adds ~15 seconds** to every release workflow — negligible but
  non-zero.
- ❌ **Requires `contents: write` on `GITHUB_TOKEN`.** The workflow
  already has this for creating releases, so no new permission.
- ❌ **Branch protection may block the bot.** If `develop` is protected
  with "Restrict who can push", the sync fails silently (warning).
  Mitigated by adding `github-actions[bot]` to the allowlist — see
  `docs/BRANCHING.md` §6.
- ❌ **Merge conflicts require manual resolution.** In the rare case
  where `develop` and `main` have conflicting changes, the sync aborts
  with a warning. The maintainer must resolve manually.
- ❌ **The sync is invisible to the release.** Users see the release
  succeed, but the sync runs after. If it fails, no signal reaches
  the release page (only the Actions log).

### Neutral

- ⚪ **Sync commit is created only when fast-forward is not possible.**
  In the common case (no divergence), the sync is a fast-forward push
  with no new commit.
- ⚪ **`develop` gains a commit** in the divergent case — a
  `chore: sync develop with main` commit.
- ⚪ **The workflow file grows** by ~25 lines — acceptable given the
  benefit.

---

## Alternatives Considered

| Alternative | Pros | Cons | Why rejected |
|---|---|---|---|
| **Manual sync** (maintainer runs `git merge origin/main` after each release) | ✅ Zero automation<br>✅ Full control<br>✅ No workflow changes | ❌ Forgotten after 2 AM releases<br>❌ Requires remembering every time<br>❌ Doesn't scale past one maintainer<br>❌ Not documented in the release pipeline | Defeats the purpose of automated releases ([ADR-0002](0002-automated-releases.md)). The whole point is to reduce manual steps — adding one back is a regression. |
| **Separate `sync-main-to-develop.yml` workflow** | ✅ Single-responsibility workflow<br>✅ Easier to disable independently<br>✅ Cleaner `release.yml` | ❌ Two workflows to maintain<br>❌ Cannot easily read the tag/version from the release<br>❌ Extra workflow = extra YAML + extra failure mode<br>❌ Requires `workflow_run` trigger, which is fragile | The sync is **semantically tied** to the release, not a separate concern. Embedding it in `release.yml` keeps the whole release lifecycle in one file. This was explicitly decided against in `CHANGELOG.md` "Not Included" — a decision now formalized by this ADR. |
| **Do not sync at all** (accept divergence) | ✅ Zero automation<br>✅ No YAML changes<br>✅ Simplest | ❌ Drift compounds per release<br>❌ Next `release/*` PR becomes a nightmare<br>❌ Contributors branch from stale `develop`<br>❌ The documented two-branch flow breaks | Contradicts [ADR-0001](0001-two-branch-model.md). The two-branch model **requires** sync to function. Divergence is not an acceptable trade-off. |
| **External webhook / bot** (e.g. Mergify, custom app) | ✅ Powerful rules engine<br>✅ Cross-repo orchestration<br>✅ Advanced conflict handling | ❌ Adds a third-party dependency<br>❌ Requires app installation + permissions<br>❌ Costs money at scale<br>❌ Vendor lock-in for a solo project | The project values **zero external dependencies**. A 25-line YAML step achieves the same goal without an installed app. |
| **Sync in `release.sh` (local)** | ✅ Immediate feedback<br>✅ No CI minutes<br>✅ Visible to the maintainer | ❌ Requires the maintainer to be online after the release<br>❌ CI might not have finished yet<br>❌ Race condition with the release publish<br>❌ Loses the "sync after publish" guarantee | The sync must happen **after** the release is live. Only GitHub Actions knows when that happens. A local sync would race the workflow. |
| **Embedded in `release.yml` (chosen)** | ✅ One file to rule the release<br>✅ Runs after publish<br>✅ Failure-isolated<br>✅ Reads version from the tag<br>✅ No new dependencies | ❌ Slightly larger workflow<br>❌ Requires `contents: write` (already granted) | — |

---

## Related Decisions

| ADR | Relationship |
|---|---|
| [ADR-0001](0001-two-branch-model.md) | This ADR directly mitigates the "Negative" consequences listed in ADR-0001 (branch divergence). |
| [ADR-0002](0002-automated-releases.md) | The sync is the final step of the workflow defined in ADR-0002. |
| [ADR-0006](0006-rename-hotfix-to-release-patch.md) | PATCH releases trigger the same sync, but `docs/BRANCHING.md` §8.4 additionally documents a **manual** back-merge for `release-patch.sh` cases. |

---

## References

### Project files

- [`.github/workflows/release.yml`](../../.github/workflows/release.yml) — the workflow containing the sync step.
- [`docs/BRANCHING.md`](../BRANCHING.md) §8.4 — the back-merge requirement for PATCH releases.
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §10 — post-release sync documentation.
- [`docs/DEVELOPMENT.md`](../DEVELOPMENT.md) §7.2 — the CI/CD overview including the sync.
- [`Makefile`](../../Makefile) — the `make sync` target provides an equivalent manual command.

### External references

- [GitHub Actions — `continue-on-error`](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idcontinue-on-error)
- [GitHub Actions — `GITHUB_TOKEN` permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
- [Git — `git merge --ff-only`](https://git-scm.com/docs/git-merge#Documentation/git-merge.txt---ff-only)
- [GitHub Actions — Avoiding duplicate runs with `concurrency`](https://docs.github.com/en/actions/using-jobs/using-concurrency)

### Discussion

- Initial proposal: see commit history for `.github/workflows/release.yml`.
- The decision to embed sync rather than create a separate workflow is
  documented in `CHANGELOG.md` under "Not Included".

---

*This ADR is immutable. To reverse or amend it, create a new ADR that
supersedes it and update its Status line.*