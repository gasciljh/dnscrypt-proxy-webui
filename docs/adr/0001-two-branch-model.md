# ADR-0001: Two-Branch Model (`main` + `develop`)

**Status**: ✅ Accepted

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: —

**Superseded by**: —

---

## Context

### The problem

At the project's inception, all commits were pushed directly to `main`.
While simple, this created three recurring problems:

1. **Unstable `main`**: any incomplete feature or experimental change
   could reach users immediately.
2. **Slow iteration**: contributors hesitated to push work-in-progress
   because it would pollute the released branch.
3. **No integration point**: features could not be tested together before
   a release — each was either ready or blocked entirely.

### The forces at play

| Force | Direction |
|---|---|
| **Stability of `main`** | 🔒 High — users download releases from here |
| **Speed of iteration** | ⚡ High — features must not block each other |
| **Contributor friction** | 📉 Low — onboarding must stay simple |
| **Release cadence** | 📅 Predictable — releases are milestones, not surprises |
| **Solo maintainer** | 👤 One person, limited time budget |

### Constraints

- The project is **maintained by a single author** today.
- It is **open to contributions** and should scale to a small team.
- It uses **GitHub Actions** for CI, which is free for public repos but
  should not be wasted on redundant runs.
- The **release automation** (`release.yml`) must remain simple.

### Scope

This ADR covers **branch structure only**. It does **not** cover:

- Branch protection rules → see [`docs/BRANCHING.md`](../BRANCHING.md) §6.
- Release automation → see [ADR-0002](0002-automated-releases.md).
- Post-release syncing → see [ADR-0003](0003-post-release-sync.md).
- PR templates → see [ADR-0004](0004-unified-pr-template.md) and
  [ADR-0005](0005-release-specific-pr-template.md).

---

## Decision

> **We will adopt a two-branch model: `main` (stable releases only) and
> `develop` (integration branch).**

### Specifics

1. **`main`** is **permanent** and represents the latest released version.
   - Direct pushes are forbidden (enforced by branch protection).
   - Only `release/*` and `hotfix/*` branches may merge into `main`.
   - Every commit on `main` is tagged (`vX.Y.Z`) and released.

2. **`develop`** is **permanent** and represents the integration state.
   - Short-lived branches (`feature/*`, `fix/*`, `docs/*`, `chore/*`,
     `refactor/*`, `test/*`) branch **from** `develop` and merge **back into**
     `develop` via pull requests.
   - Direct pushes are allowed for the maintainer (relaxed protection).
   - It should always build successfully — a broken `develop` blocks
     all work.

3. **Short-lived branches** are created for every unit of work and deleted
   after merge.
   - One branch = one purpose.
   - Max lifetime: ~2 weeks (rebase if longer).

4. **`main` accepts PRs only from**:
   - `release/*` — regular releases.
   - `hotfix/*` — emergency PATCH releases.
   - Never directly from `develop`, `feature/*`, or any other branch.

5. **After each release**, `main` is automatically synced back into `develop`
   to prevent drift (see [ADR-0003](0003-post-release-sync.md)).

### Diagram

```text
main ─────●──────────────────●───────────────●──── (releases)
          ↑                  ↑               ↑
       [release/*]        [release/*]     [hotfix/*]
          │                  │               │
develop ──●──●──●──●──●──●───●──●──●──●──●───●──── (integration)
            ↑  ↑  ↑       ↑
        [feat]│  │    [fix]
            [docs]│
              [chore]
```

---

## Consequences

### Positive

- ✅ **`main` is always deployable.** Every commit is a tagged release.
- ✅ **Features develop in isolation.** A broken feature cannot affect
  `develop`'s other work.
- ✅ **Integration testing is possible.** Features meet on `develop`
  before reaching users.
- ✅ **Clear onboarding.** New contributors have one obvious starting
  point (`develop`).
- ✅ **Scales to a small team.** The model is standard enough that any
  developer familiar with GitHub Flow can contribute immediately.
- ✅ **CI is efficient.** Only PRs and merges to `main` / `develop` trigger
  the full build matrix; feature pushes to their own branch run a
  lighter check.

### Negative

- ❌ **Two branches to maintain.** The project must keep `develop` in sync
  with `main` after every release — otherwise, the next release PR will
  contain stale commits. This is mitigated by
  [ADR-0003](0003-post-release-sync.md).
- ❌ **Slightly more process.** Contributors must learn the branch rules.
  This is mitigated by `docs/BRANCHING.md` and the PR template
  ([ADR-0005](0005-release-specific-pr-template.md)).
- ❌ **Merge overhead.** Fast-forward merges from `develop` to `main` are
  rare; most releases require a merge commit or a squash. This is
  acceptable because releases are infrequent (monthly at most).
- ❌ **Branch protection setup is manual.** GitHub does not version
  branch rules in the repository — they must be configured via
  Settings. Documented in `docs/BRANCHING.md` §6.

### Neutral

- ⚪ **One additional branch in the remote.** Storage cost is negligible.
- ⚪ **`git clone` fetches `main` by default** — contributors must
  explicitly `git checkout develop`. Documented in `docs/DEVELOPMENT.md`
  §2.1.
- ⚪ **Commit history** stays linear on each branch, but the graph becomes
  a two-lane highway. This is the standard shape of GitHub Flow.

---

## Alternatives Considered

| Alternative | Pros | Cons | Why rejected |
|---|---|---|---|
| **Trunk-Based Development** (single `main`, no `develop`) | ✅ Simplest possible workflow<br>✅ No sync overhead<br>✅ Ideal for mature CI/CD | ❌ Requires feature flags for WIP<br>❌ No integration branch<br>❌ A broken PR blocks all work<br>❌ Harder for new contributors | Too aggressive for a solo-maintained project without feature-flag infrastructure. The cost of a broken `main` (users download broken releases) is too high. |
| **Full Git Flow** (Vincent Driessen) | ✅ Well-documented<br>✅ Scales to large teams<br>✅ Explicit release branches | ❌ Over-engineered for a solo project<br>❌ 5+ branch types to maintain<br>❌ `release/*` and `hotfix/*` often overlap<br>❌ Slower feedback loops | Adds complexity without proportional benefit. The project does not have "release trains" that require long-lived release branches. |
| **Single `main` branch** (previous state) | ✅ Zero process<br>✅ Zero sync overhead | ❌ Unstable `main`<br>❌ No integration point<br>❌ Contributors blocked by WIP<br>❌ Silent regressions reach users | This is what we are replacing. It created the problems described in the Context section. |
| **GitLab Flow** (environment branches) | ✅ Fine-grained per environment<br>✅ Good for multi-stage deployments | ❌ Assumes deployment environments (staging, prod) that do not exist here<br>❌ Android module is not a deployed service<br>❌ Extra overhead for no gain | The project is a **downloadable artifact**, not a running service. There are no environments to promote between. |
| **Two-branch model (chosen)** | ✅ Balances stability and iteration<br>✅ Standard enough to be familiar<br>✅ Simple enough for a solo maintainer<br>✅ Scales to a small team | ❌ Requires post-release sync (ADR-0003)<br>❌ Slightly more process than single-branch | — |

---

## Related Decisions

| ADR | Relationship |
|---|---|
| [ADR-0002](0002-automated-releases.md) | Automated releases depend on this two-branch model — they tag `main` and trigger the release pipeline. |
| [ADR-0003](0003-post-release-sync.md) | The post-release sync (`main → develop`) exists to mitigate the "Negative" consequences of this decision. |
| [ADR-0004](0004-unified-pr-template.md) | The unified PR template guides contributors toward the correct branch. |
| [ADR-0005](0005-release-specific-pr-template.md) | The release-specific template complements the unified one for `main`-targeting PRs. |
| [ADR-0006](0006-rename-hotfix-to-release-patch.md) | The rename from `hotfix.sh` to `release-patch.sh` reflects the terminology used in this ADR (PATCH releases come from `hotfix/*` branches). |

---

## References

### Project files

- [`docs/BRANCHING.md`](../BRANCHING.md) — the full operational specification of this decision.
- [`docs/CONTRIBUTING.md`](../CONTRIBUTING.md) — contributor guide referencing this model.
- [`docs/DEVELOPMENT.md`](../DEVELOPMENT.md) — daily workflow for developers.
- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — runs on PRs targeting `main` and `develop`.
- [`.github/workflows/codeql.yml`](../../.github/workflows/codeql.yml) — same triggers for SAST.
- [`.github/workflows/release.yml`](../../.github/workflows/release.yml) — publishes releases from tags on `main`.

### External references

- [GitHub Flow — GitHub Docs](https://docs.github.com/en/get-started/quickstart/github-flow)
- [A successful Git branching model — Vincent Driessen (2010)](https://nvie.com/posts/a-successful-git-branching-model/)
- [Trunk Based Development](https://trunkbaseddevelopment.com/)
- [GitLab Flow](https://docs.gitlab.com/ee/topics/gitlab_flow.html)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

### Discussion

- Original proposal: see commit history for `docs/BRANCHING.md` and
  `docs/adr/README.md`.

---

*This ADR is immutable. To reverse or amend it, create a new ADR that
supersedes it and update its Status line.*