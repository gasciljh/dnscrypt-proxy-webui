# ADR-0003: Post-Release Sync (`main → develop`)

**Status**: ✅ Accepted

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: —

**Superseded by**: —

---

> **Identifier inventory in this file (5 total)**:
>   • HARD-ADR3-01 (v1.3.0 verification block extended with
>     server-side rotation refinements — v1.4.0)
>   • HARD-ADR3-02 (v1.4.0 verification block extended with
>     MAIN-01 — v1.4.0)
>   • HARD-ADR3-03 (Release verification section extended —
>     v1.3.0 SNAP-*/ROT-* + v1.4.0 MAIN-01 — v1.4.0)
>   • HARD-ADR3-04 (References section extended with rotation
>     cross-references — v1.4.0)
>   • HARD-ADR3-05 (Header + footer `Last reviewed` sync +
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
>   • [docs/RELEASE_PROCESS.md](../RELEASE_PROCESS.md) §10 — sync
>     documentation; §8.4 — signature status; §8.5 — SBOM status
>   • [docs/BRANCHING.md](../BRANCHING.md) §8.4 — PATCH back-merge
>   • [CHANGELOG.md](../../CHANGELOG.md) — version history

---

> **Post-Release Verification (v1.4.0 — 2026-10-06)**:
>
> This ADR was reviewed during the v1.4.0 release cycle and
> **remains in effect**, with **one correctness fix** applied to
> the sync step's environment. See the "v1.4.0 fix" note below.
>
> **Verification notes**:
>
>   • The **automatic** sync (via `release.yml`) has now been
>     verified **five times**: after `v1.0.0`, `v1.1.0`, `v1.2.0`,
>     `v1.3.0`, and `v1.4.0`.
>   • In all five cases, `develop` was fast-forwarded to match
>     `main` **without any manual intervention**.
>   • The `continue-on-error: true` flag has **never been
>     triggered** — no sync failures to date.
>   • The **manual** back-merge path (`make sync`) remains
>     prepared but **still untested** — no PATCH release has been
>     cut yet. The first realistic scenario remains
>     `v1.4.0 → v1.4.1` (via `hotfix/*`).
>   • The `github-actions[bot]` identity is still correctly
>     configured in the repository's branch-protection allowlist.
>   • The v1.4.0 release introduced an **integration release** with
>     two new pipeline steps (Fetch companion APK + Stage APK for
>     module ZIP) — the sync step ran **after** these, unchanged
>     in position (still the final step).
>   • **v1.4.0 runtime / integration additions** (shipped through
>     the pipeline, but not part of the pipeline itself):
>     - **Companion Android app** (`web/app-debug.apk`, optional).
>     - **CodeQL `go/path-injection` fix** in `removeModule` —
>       `filepath.Base()` sanitization + trusted base dir.
>     - **iOS PWA logic removed** from `index.html`.
>     - **MAIN-01** — `LOG_LEVEL` loaded immediately after
>       `initPaths()` in `main.go`.
>     These are documented in `CHANGELOG.md` §[v1.4.0] and
>     [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.1, §4.12,
>     §6.8, §11.37. They are orthogonal to the sync step — the
>     sync only moves commits; it does not inspect their content.
>
> **v1.4.0 fix — `${V}` environment variable**:
>
>   🔧 The sync step's **commit message** uses `${V}` (the release
>   tag). Before v1.4.0, the step's `env:` block declared:
>
>   ```yaml
>   V: ${{ steps.version.outputs.version }}   # ← WRONG
>   ```
>
>   However, the "Determine and validate version" step **does not
>   emit** an output named `version` — it emits `value` and
>   `no_v`. The mismatch caused `${V}` to be **empty** on every
>   divergent merge, producing a commit message like:
>
>   ```text
>   chore: sync develop with main after  release   ← two spaces
>   ```
>
>   **The fix** (applied in v1.4.0):
>
>   ```yaml
>   V: ${{ steps.version.outputs.value }}    # ← CORRECT
>   ```
>
>   **Impact on this ADR**: the "Behavior" YAML snippet below now
>   includes the `V:` env var. Note that in the **fast-forward**
>   case (all five releases so far) the `${V}` variable is never
>   read — the divergent path is the only one that uses it. Since
>   no divergent merge has yet occurred, this fix is
>   **un-verified in production** but correct per the workflow's
>   output definitions. See
>   [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §10.2 for
>   the current sync-failure documentation.
>
> **Result**: The decision is validated across five release cycles
> (including one large data-preservation release, one feature
> release with server-side refinements, and one integration
> release). The `${V}` fix is a **correctness improvement** to the
> sync's divergent-merge path, not a structural change. No
> superseding ADR is required.

> **Post-Release Verification (v1.3.0 — 2026-10-02)**:
>
> This ADR was reviewed during the v1.3.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • The **automatic** sync (via `release.yml`) has been verified
>     **four times**: after `v1.0.0`, `v1.1.0`, `v1.2.0`, and
>     `v1.3.0`.
>   • In all four cases, `develop` was fast-forwarded to match
>     `main` **without any manual intervention**.
>   • The `continue-on-error: true` flag has **never been
>     triggered** — no sync failures to date.
>   • The **manual** back-merge path (`make sync`) remains
>     prepared but **still untested** — no PATCH release has been
>     cut yet.
>   • The `github-actions[bot]` identity is still correctly
>     configured.
>   • The v1.3.0 release was a **feature release** with
>     **three** categories of changes:
>     - **Client-side**:
>       - PWA install button (`web/index.html`).
>       - Live status LED (`web/index.html`).
>     - **Shell-side**:
>       - DNS auto-start fix (`proxy/service.sh`).
>     - **Server-side rotation refinements** — five new semantics
>       that underpin the persistent backup directory (also used
>       in `CHANGELOG.md` [v1.3.0] and
>       [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.13):
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
>     The v1.3.0 pipeline structure was unchanged from v1.2.0,
>     and the sync step's position remained final — the server-side
>     refinements are orthogonal to the sync, which only moves
>     commits.
>   • The `v1.3.0` fast-forward succeeded even though the release
>     touched **8 files with backup/rotation logic** plus the
>     client-side files. The sync step does not inspect commit
>     content, so this is expected.
>
> **Result**: The decision is validated by a fourth release
> cycle. No superseding ADR is required.

> **Post-Release Verification (v1.2.0 — 2026-09-29)** (retained as history):
>
> This ADR was reviewed during the v1.2.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • The **automatic** sync (via `release.yml`) has now been
>     verified **three times**: after `v1.0.0`, after `v1.1.0`, and
>     after `v1.2.0`.
>   • In all three cases, `develop` was fast-forwarded to match
>     `main` **without any manual intervention**.
>   • The `continue-on-error: true` flag has **never been triggered**
>     — no sync failures to date.
>   • The **manual** back-merge path (`make sync`) remains prepared
>     but **still untested** — no PATCH release has been cut yet.
>     The first realistic scenario remains `v1.2.0 → v1.2.1` (via
>     `hotfix/*`).
>   • The `github-actions[bot]` identity is still correctly
>     configured in the repository's branch-protection allowlist.
>   • The v1.2.0 release introduced a **much larger** change set
>     (10 defensive layers + BAK-1..4 + FIX-1/2 + WD-TOKEN + docs)
>     than the previous two releases — and the fast-forward path
>     still succeeded cleanly.
>
> **Result**: The decision is validated across three release cycles
> including the largest release to date.

> **Post-Release Verification (v1.1.0 — 2026-09-26)** (retained as history):
>
> This ADR was reviewed during the v1.1.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • The **automatic** sync (via `release.yml`) has been verified
>     twice: after `v1.0.0` and after `v1.1.0`.
>   • In both cases, `develop` was fast-forwarded (or merged) to
>     match `main` **without any manual intervention**.
>   • The `continue-on-error: true` flag has never been triggered
>     — no sync failures to date.
>   • The **manual** back-merge path (`make sync`) has been
>     prepared but not yet exercised for a real PATCH release.
>     The next realistic scenario would be `v1.1.0 → v1.1.1`
>     (via `hotfix/*`).
>   • The `github-actions[bot]` identity is correctly configured
>     in the repository's branch-protection allowlist (verified
>     during the v1.1.0 release).
>
> **Result**: The decision is validated by real-world usage for
> the **automatic** path. The **manual** path remains untested in
> production (no PATCH releases have been cut yet).

---

## Context

### The problem

With the two-branch model adopted in
[ADR-0001](0001-two-branch-model.md), every release takes this
shape:

1. `develop` accumulates features and fixes.
2. A `release/*` branch (or `develop` directly) merges into `main`.
3. A tag `vX.Y.Z` is created on `main`.
4. [ADR-0002](0002-automated-releases.md)'s workflow publishes the
   release.

**But then:** `develop` is now **behind** `main`.

`main` contains:
- The version bump commit (`release: vX.Y.Z`).
- Any PR-specific merge commits.
- Any release-specific fixes.

`develop` **does not** contain these commits — they were only made
on `main`. This creates **branch divergence**.

### Why divergence matters

Without a sync, the next release cycle starts from a `develop` that
is missing the previous release's commits. Consequences:

| Scenario | Result without sync |
|---|---|
| Next `release/*` PR targets `main` | Git tries to reintroduce old commits — merge conflicts |
| Contributors branch from `develop` | They miss the previous release's tag |
| `docs/BRANCHING.md` workflow breaks | The documented flow assumes `develop ≥ main` |
| Release notes become inaccurate | `main` and `develop` diverge further every cycle |

The drift compounds: **one missed sync per release**. After 6
months, `develop` can be **dozens of commits behind** `main`, making
the next release PR merge painful.

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

This ADR covers **how and when `develop` is synced with `main`**. It
does **not** cover:

- Branch structure → see [ADR-0001](0001-two-branch-model.md).
- Release automation → see [ADR-0002](0002-automated-releases.md).
- PATCH-release flow → see
  [ADR-0006](0006-rename-hotfix-to-release-patch.md).
- The content of individual releases (e.g. the v1.3.0
  SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME +
  ROT-PROTECT server-side refinements documented in
  [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.13) — the sync
  only moves commits; it does not inspect their content.

---

## Decision

> **We will embed a "Sync `main` → `develop`" step at the end of**
> **`.github/workflows/release.yml`, executed automatically after**
> **every successful release.**

### Specifics

#### Position in the pipeline

The sync is the **final step** of `release.yml`, after:

1. Build (4 architectures).
2. Verify binaries (ELF + PIE).
3. **(v1.4.0)** Fetch companion APK (best-effort).
4. **(v1.4.0)** Stage APK for module ZIP.
5. Package Magisk ZIP.
6. Upload backup artifacts.
7. Extract CHANGELOG section.
8. Create GitHub Release.

Only when the release is **publicly published** does the sync run.
This ensures we never sync `develop` with a failed build.

#### Behavior

```yaml
- name: Sync main → develop
  if: github.event_name == 'push'
  continue-on-error: true
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    V: ${{ steps.version.outputs.value }}   # ← v1.4.0 fix: was .outputs.version
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
           -m "chore: sync develop with main after ${V} release"; then
        echo "::warning::Merge conflict — manual resolution required"
        git merge --abort || true
        exit 0
      fi
    fi

    git push origin develop
```

> **Note (v1.4.0)**: The `V:` environment variable is new — before
> v1.4.0 the step read `${{ steps.version.outputs.version }}`,
> which was **empty** because the version-determination step emits
> `value`, not `version`. The fix reads `${{ steps.version.outputs.value }}`.
> This affects only the **divergent-merge** commit message; the
> fast-forward path never reads `${V}`. See the top of this file
> for the full history.

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
| **`V: ${{ steps.version.outputs.value }}`** | **v1.4.0** — correct source for the release tag; previously empty. |

#### Trigger path

```text
Tag push (vX.Y.Z)
        │
        ▼
release.yml triggers
        │
        ├── Build (4 archs)
        ├── Fetch companion APK (v1.4.0)
        ├── Stage APK for module ZIP (v1.4.0)
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
- ❌ It does **not** inspect commit content — a release that
  touches backup/rotation semantics (e.g. v1.3.0's SNAP-MANIFEST
  + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME + ROT-PROTECT) is synced
  exactly like any other release.

---

## Consequences

### Positive

- ✅ **Zero manual toil.** The maintainer never runs
  `git merge origin/main` by hand after a release.
- ✅ **No compound drift.** Every release leaves `develop` exactly
  one commit ahead of `main` (or identical).
- ✅ **Predictable next release.** The next `release/*` PR starts
  from a synced `develop`.
- ✅ **Contributor clarity.** New contributors branching from
  `develop` get the latest released code.
- ✅ **Failure isolation.** A bug in the sync step never affects
  the published release.
- ✅ **Audit trail.** Sync commits are visible in the log with a
  descriptive message and the standard bot identity.
- ✅ **(v1.4.0) Correct commit message on divergent merges.** The
  `V:` fix ensures the sync commit reads
  `chore: sync develop with main after v1.4.0 release`
  (with the tag) rather than
  `chore: sync develop with main after  release`
  (two spaces).
- ✅ **Content-agnostic.** The sync works regardless of *what*
  changed — client-side files, shell scripts, Go code,
  backup/rotation semantics, or any combination.

### Negative

- ❌ **Adds ~15 seconds** to every release workflow — negligible
  but non-zero.
- ❌ **Requires `contents: write` on `GITHUB_TOKEN`.** The
  workflow already has this for creating releases, so no new
  permission.
- ❌ **Branch protection may block the bot.** If `develop` is
  protected with "Restrict who can push", the sync fails silently
  (warning). Mitigated by adding `github-actions[bot]` to the
  allowlist — see `docs/BRANCHING.md` §6.
- ❌ **Merge conflicts require manual resolution.** In the rare
  case where `develop` and `main` have conflicting changes, the
  sync aborts with a warning. The maintainer must resolve
  manually.
- ❌ **The sync is invisible to the release.** Users see the
  release succeed, but the sync runs after. If it fails, no
  signal reaches the release page (only the Actions log).

### Neutral

- ⚪ **Sync commit is created only when fast-forward is not
  possible.** In the common case (no divergence), the sync is a
  fast-forward push with no new commit.
- ⚪ **`develop` gains a commit** in the divergent case — a
  `chore: sync develop with main after <tag> release` commit.
- ⚪ **The workflow file grows** by ~25 lines — acceptable given
  the benefit.
- ⚪ **The sync is orthogonal to release content.** Whether the
  release changes client-side JS, Go backup logic, or shell
  rotation semantics, the sync step behaves identically.

---

## Alternatives Considered

| Alternative | Pros | Cons | Why rejected |
|---|---|---|---|
| **Manual sync** (maintainer runs `git merge origin/main` after each release) | ✅ Zero automation<br>✅ Full control<br>✅ No workflow changes | ❌ Forgotten after 2 AM releases<br>❌ Requires remembering every time<br>❌ Doesn't scale past one maintainer<br>❌ Not documented in the release pipeline | Defeats the purpose of automated releases ([ADR-0002](0002-automated-releases.md)). The whole point is to reduce manual steps — adding one back is a regression. |
| **Separate `sync-main-to-develop.yml` workflow** | ✅ Single-responsibility workflow<br>✅ Easier to disable independently<br>✅ Cleaner `release.yml` | ❌ Two workflows to maintain<br>❌ Cannot easily read the tag/version from the release<br>❌ Extra workflow = extra YAML + extra failure mode<br>❌ Requires `workflow_run` trigger, which is fragile | The sync is **semantically tied** to the release, not a separate concern. Embedding it in `release.yml` keeps the whole release lifecycle in one file. This was explicitly decided against in `CHANGELOG.md` "Not Included" — a decision now formalized by this ADR. |
| **Do not sync at all** (accept divergence) | ✅ Zero automation<br>✅ No YAML changes<br>✅ Simplest | ❌ Drift compounds per release<br>❌ Next `release/*` PR becomes a nightmare<br>❌ Contributors branch from stale `develop`<br>❌ The documented two-branch flow breaks | Contradicts [ADR-0001](0001-two-branch-model.md). The two-branch model **requires** sync to function. Divergence is not an acceptable trade-off. |
| **External webhook / bot** (e.g. Mergify, custom app) | ✅ Powerful rules engine<br>✅ Cross-repo orchestration<br>✅ Advanced conflict handling | ❌ Adds a third-party dependency<br>❌ Requires app installation + permissions<br>❌ Costs money at scale<br>❌ Vendor lock-in for a solo project | The project values **zero external dependencies**. A 25-line YAML step achieves the same goal without an installed app. |
| **Sync in `release.sh` (local)** | ✅ Immediate feedback<br>✅ No CI minutes<br>✅ Visible to the maintainer | ❌ Requires the maintainer to be online after the release<br>❌ CI might not have finished yet<br>❌ Race condition with the release publish<br>❌ Loses the "sync after publish" guarantee | The sync must happen **after** the release is live. Only GitHub Actions knows when that happens. A local sync would race the workflow. |
| **Embedded in `release.yml` (chosen)** | ✅ One file to rule the release<br>✅ Runs after publish<br>✅ Failure-isolated<br>✅ Reads version from the tag<br>✅ No new dependencies<br>✅ Content-agnostic<br>✅ **(v1.4.0)** Correct `${V}` on divergent merges | ❌ Slightly larger workflow<br>❌ Requires `contents: write` (already granted) | — |

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

- [`.github/workflows/release.yml`](../../.github/workflows/release.yml) —
  the workflow containing the sync step.
- [`docs/BRANCHING.md`](../BRANCHING.md) §8.4 — the back-merge
  requirement for PATCH releases.
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §10 —
  post-release sync documentation.
- [`docs/DEVELOPMENT.md`](../DEVELOPMENT.md) §7.2 — the CI/CD
  overview including the sync.
- [`docs/UPGRADE.md`](../UPGRADE.md) — version upgrade guide
  (§3.1 covers v1.0.0 → v1.1.0; §3.2 covers v1.1.0 → v1.2.0;
  §3.3 covers v1.2.0 → v1.3.0; §3.4 covers v1.3.0 → v1.4.0 — the
  latter two relied on the automatic sync path).
- [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.13 — v1.3.0
  server-side rotation refinements (SNAP-*/ROT-*); §4.1 and §11.37
  — MAIN-01 load-order fix.
- [`docs/COMPATIBILITY.md`](../COMPATIBILITY.md) §10.3.5 — on-device
  SNAP-*/ROT-* verification procedure.
- [`docs/GLOSSARY.md`](../GLOSSARY.md) — SNAP-*/ROT-* terms,
  Rotation Guardian badge.
- [`docs/HALL_OF_FAME.md`](../HALL_OF_FAME.md) — Rotation Guardian
  + Companion App Champion badges.
- [`Makefile`](../../Makefile) — the `make sync` target provides
  an equivalent manual command.

### External references

- [GitHub Actions — `continue-on-error`](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idcontinue-on-error)
- [GitHub Actions — `GITHUB_TOKEN` permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
- [Git — `git merge --ff-only`](https://git-scm.com/docs/git-merge#Documentation/git-merge.txt---ff-only)
- [GitHub Actions — Avoiding duplicate runs with `concurrency`](https://docs.github.com/en/actions/using-jobs/using-concurrency)

### Discussion

- Initial proposal: see commit history for
  `.github/workflows/release.yml`.
- The decision to embed sync rather than create a separate workflow
  is documented in `CHANGELOG.md` under "Not Included".
- The `${V}` environment-variable fix is documented in
  `docs/RELEASE_PROCESS.md` §10.2 and in this ADR's top section.

### Release verification

- **v1.0.0** (2026-09-24) — first release using the automatic sync.
  - Sync result: **fast-forward merge succeeded**.
  - `develop` matched `main` post-release.
  - No manual intervention.
- **v1.1.0** (2026-09-26) — second release; sync unchanged.
  - Sync result: **fast-forward merge succeeded**.
  - `develop` matched `main` post-release.
  - No manual intervention.
- **v1.2.0** (2026-09-29) — third release; sync unchanged.
  - Sync result: **fast-forward merge succeeded**.
  - `develop` matched `main` post-release.
  - No manual intervention.
  - The largest release to date (10 defensive layers) still used
    the fast-forward path.
- **v1.3.0** (2026-10-02) — fourth release; sync unchanged.
  - Sync result: **fast-forward merge succeeded**.
  - `develop` matched `main` post-release.
  - No manual intervention.
  - The **feature release** shipped **three** categories of changes:
    - Client-side: PWA install button + live status LED.
    - Shell-side: DNS auto-start fix in `service.sh`.
    - Server-side rotation refinements: **SNAP-MANIFEST** +
      **SNAP-MTIME** (in `main.go:buildBackupInfo()`) and
      **ROT-MANIFEST** + **ROT-MTIME** + **ROT-PROTECT** (in
      `functions.sh:rotate_backups()`), mirrored in 5 other
      scripts.
  - The fast-forward path succeeded even though the release
    touched backup/rotation logic across 8 files — the sync step
    does not inspect commit content.
- **v1.4.0** (2026-10-06) — fifth release; sync correctness fix.
  - Sync result: **fast-forward merge succeeded**.
  - `develop` matched `main` post-release.
  - No manual intervention.
  - The **integration release** shipped the companion Android app
    (`web/app-debug.apk`, optional), the CodeQL
    `go/path-injection` fix in `removeModule`, the iOS PWA logic
    removal, and **MAIN-01** (`LOG_LEVEL` load-order fix in
    `main.go`).
  - The pipeline gained two new steps (Fetch companion APK +
    Stage APK for module ZIP) before the sync.
  - **Correctness fix**: the sync step's `V:` env var now reads
    `${{ steps.version.outputs.value }}` (was
    `${{ steps.version.outputs.version }}`, which was empty).
    The fast-forward path does not read `${V}`, so the fix is
    un-verified in production — but it is correct per the
    workflow's output definitions.
- **Manual sync path** (`make sync`) — **not yet exercised**.
  - It will be needed if a PATCH release is cut via `hotfix/*`
    (e.g. `v1.4.1`).
  - See [`docs/BRANCHING.md`](../BRANCHING.md) §8.4 for the
    procedure.
- **`continue-on-error: true`** — never triggered (no sync
  failures to date, across five releases).
- See `CHANGELOG.md` for the full release history.

---

*This ADR is immutable. To reverse or amend it, create a new ADR
that supersedes it and update its Status line.*

*For the `${V}` fix history, see the top of this file and
[`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §10.2.*