# ADR-0005: Release-Specific PR Template

**Status**: ✅ Accepted

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: [ADR-0004](0004-unified-pr-template.md)

**Superseded by**: —

---

> **Identifier inventory in this file (5 total)**:
>   • HARD-ADR5-01 (v1.3.0 verification block extended with
>     server-side rotation refinements — v1.4.0)
>   • HARD-ADR5-02 (v1.4.0 verification block extended with
>     MAIN-01 — v1.4.0)
>   • HARD-ADR5-03 (Release verification section extended —
>     v1.3.0 SNAP-*/ROT-* + v1.4.0 MAIN-01 — v1.4.0)
>   • HARD-ADR5-04 (References section extended with rotation
>     cross-references — v1.4.0)
>   • HARD-ADR5-05 (Header identifier inventory + cross-references
>     added — v1.4.0)
>
> **Cross-references**:
>   • [docs/ARCHITECTURE.md §4.13](../ARCHITECTURE.md) — v1.3.0
>     server-side refinements (authoritative)
>   • [docs/ARCHITECTURE.md §4.1, §11.37](../ARCHITECTURE.md) —
>     MAIN-01 (`LOG_LEVEL` load-order fix)
>   • [docs/COMPATIBILITY.md §10.3.5](../COMPATIBILITY.md) — on-device
>     SNAP-*/ROT-* verification procedure
>   • [docs/GLOSSARY.md](../GLOSSARY.md) — SNAP-*/ROT-* terms,
>     Rotation Guardian badge
>   • [docs/HALL_OF_FAME.md](../HALL_OF_FAME.md) — Rotation Guardian
>     + Companion App Champion badges
>   • [docs/BRANCHING.md §4.4](../BRANCHING.md) — when to use which
>     template
>   • [docs/RELEASE_PROCESS.md §5, §6.5, §10](../RELEASE_PROCESS.md)
>     — release PR flow + sync documentation
>   • [ADR-0004](0004-unified-pr-template.md) — the superseded
>     decision
>   • [CHANGELOG.md](../../CHANGELOG.md) — version history

---

> **Post-Release Verification (v1.4.0 — 2026-10-06)**:
>
> This ADR was reviewed during the v1.4.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • The release-specific template
>     (`.github/PULL_REQUEST_TEMPLATE/release.md`) has now been used
>     for **five releases**: `v1.0.0`, `v1.1.0`, `v1.2.0`, `v1.3.0`,
>     and `v1.4.0`.
>   • The template's **version-first layout** continues to prove
>     effective — reviewers find the critical release fields faster
>     than with the unified template.
>   • The **`?template=release.md` query-string pattern** documented
>     in `docs/BRANCHING.md` §4.4 and `docs/RELEASE_PROCESS.md` §6.5
>     has worked as intended across all five cycles.
>   • The **unified template** (from ADR-0004) remains the default
>     for all non-release PRs — the two templates continue to
>     coexist without conflict.
>   • **v1.4.0 additions worked as designed**: the release template
>     was **NOT modified** for the v1.4.0 integration release. The
>     companion app integration, CodeQL `go/path-injection` fix,
>     iOS PWA removal, and **MAIN-01** (`LOG_LEVEL` load-order fix
>     in `main.go`) were all described in the "Changes overview"
>     section without needing a new dedicated section — the
>     existing structure was sufficient. This is the intended
>     behavior for additive releases: the template scales, it does
>     not grow.
>   • The **post-merge checklist** in the release template reminded
>     the maintainer of the tag push and auto-sync steps for
>     `v1.4.0`.
>   • The **rollback plan section** documented the resilience of the
>     v1.4.0 pipeline: a failed companion APK fetch is
>     **best-effort** and does **not** fail the release (matching
>     the `release.yml` behaviour). No rollback was required.
>   • The **reversal of ADR-0004** has been validated across five
>     release cycles — no contributor has requested reverting it.
>
> **Result**: The decision is validated by five release cycles
> including the v1.4.0 integration release. No superseding ADR is
> required.

> **Post-Release Verification (v1.3.0 — 2026-10-02)**:
>
> This ADR was reviewed during the v1.3.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • The release-specific template
>     (`.github/PULL_REQUEST_TEMPLATE/release.md`) has been used
>     for **four releases**: `v1.0.0`, `v1.1.0`, `v1.2.0`, and
>     `v1.3.0`.
>   • The template's **version-first layout** continued to prove
>     effective.
>   • The **`?template=release.md` query-string pattern** worked as
>     intended for the `release/v1.3.0` → `main` PR.
>   • The **unified template** remained the default for all
>     non-release PRs.
>   • **v1.3.0 was a small feature release**: the PWA install
>     button, live status LED, and DNS auto-start fix did **not**
>     require a new section in the release template. The "Changes
>     overview" section captured them adequately.
>   • **Server-side rotation refinements shipped in v1.3.0** — this
>     release ALSO contained five new semantics that underpin the
>     persistent backup directory (also documented in
>     `CHANGELOG.md` [v1.3.0] and
>     [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.13):
>       - **SNAP-MANIFEST** — `main.go:buildBackupInfo()` detects
>         a snapshot by the presence of a `.manifest.json` file,
>         not by the v1.2.0 name pattern (`^[0-9]{8}-[0-9]{6}-`).
>       - **SNAP-MTIME** — `last_backup_name` is selected by
>         **mtime** (descending), not by lexicographic directory
>         name. Supersedes the v1.2.0 BUG-3 rule.
>       - **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** —
>         `functions.sh:rotate_backups()` was rewritten with the
>         same manifest-based detection, the same mtime sort, and
>         two additional protected targets on top of the
>         21-newest window: the `.last_stable` recovery pointer
>         and the newest install snapshot (name matching
>         `-v<digit>`).
>     The same SNAP-*/ROT-* semantics were mirrored in 5 other
>     shell scripts (`service.sh`, `watchdog.sh`, `status.sh`,
>     `customize.sh`, `action.sh`) and in `uninstall.sh`.
>     **This further validates the release template**: a
>     cross-cutting release touching client-side JS, shell
>     scripts, Go code, and backup/rotation semantics across 8+
>     files was handled cleanly without touching the template's
>     structure.
>   • The **post-merge checklist** worked as intended — the tag
>     push and auto-sync steps were documented and executed.
>   • The **reversal of ADR-0004** has been validated across four
>     release cycles — no contributor has requested reverting it.
>
> **Result**: The decision is validated by four release cycles
> including a focused feature release with server-side
> refinements. No superseding ADR is required.

> **Post-Release Verification (v1.2.0 — 2026-09-29)** (retained as history):
>
> This ADR was reviewed during the v1.2.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • The release-specific template
>     (`.github/PULL_REQUEST_TEMPLATE/release.md`) has now been used
>     for **three releases**: `v1.0.0`, `v1.1.0`, and `v1.2.0`.
>   • The template's **version-first layout** continues to prove
>     effective — reviewers find the critical release fields faster
>     than with the unified template.
>   • The **`?template=release.md` query-string pattern** documented
>     in `docs/BRANCHING.md` §4.4 and `docs/RELEASE_PROCESS.md` §6.5
>     has worked as intended across all three cycles.
>   • The **unified template** (from ADR-0004) remains the default
>     for all non-release PRs — the two templates continue to
>     coexist without conflict.
>   • **v1.2.0 additions worked as designed**: the release template
>     gained a new **"v1.2.0 — data preservation"** section
>     (10 defensive layers, `backupMu`, 7-field `backups` object,
>     watchdog token, bilingual WebUI, 42-scenario matrix, and the
>     `append_denylist` breaking-change check).
>   • The **post-merge checklist** in the release template caught
>     the maintainer's attention and reminded them of the tag push
>     and auto-sync steps for `v1.2.0`.
>   • The **reversal of ADR-0004** has been validated across three
>     release cycles — no contributor has requested reverting it.
>
> **Result**: The decision is validated by three release cycles
> including the v1.2.0 data-preservation release.

> **Post-Release Verification (v1.1.0 — 2026-09-26)** (retained as history):
>
> This ADR was reviewed during the v1.1.0 release cycle and
> **remains in effect**. No amendments were needed.
>
> **Verification notes**:
>
>   • The release-specific template
>     (`.github/PULL_REQUEST_TEMPLATE/release.md`) has been used
>     for **two releases**: `v1.0.0` (2026-09-24) and `v1.1.0`
>     (2026-09-26).
>   • The template's **version-first layout** (version +
>     versionCode at the top) has proven effective — reviewers
>     report finding the critical release fields faster than with
>     the unified template.
>   • The **`?template=release.md` query-string pattern** documented
>     in `docs/BRANCHING.md` §4.4 and `docs/RELEASE_PROCESS.md` §6.5
>     has worked as intended.
>   • The **unified template** (from ADR-0004) remains the default
>     for all non-release PRs — the two templates coexist without
>     conflict, exactly as this ADR intended.
>   • The **reversal of ADR-0004** has been validated: the
>     supersession was correct, and no contributor has requested
>     reverting it.
>   • The **post-merge checklist** in the release template
>     (tag push, `release.yml` trigger, back-merge reminder) has
>     caught the maintainer at least once per release.
>
> **Result**: The decision is validated by real-world usage across
> two release cycles.

---

## Context

### The problem

[ADR-0004](0004-unified-pr-template.md) adopted a single unified PR
template. That decision was valid for **most** pull requests —
features, fixes, docs, chores, refactors, tests.

But it under-served **one specific case**: **release PRs** (from
`release/*` or `hotfix/*` branches targeting `main`).

A release PR has a **different lifecycle, different risks, and
different review concerns** than a feature PR:

| Aspect | Feature PR | Release PR |
|---|---|---|
| **Frequency** | Weekly | Monthly at most |
| **Target branch** | `develop` | `main` |
| **Impact if wrong** | Broken `develop` (fixable) | Broken release (users affected) |
| **Key files touched** | `proxy/*`, `web/*` | `VERSION`, `module.prop`, `update.json`, `CHANGELOG.md` |
| **Post-merge action** | None | Automatic release publish |
| **Reviewer focus** | Code quality | Version correctness + release readiness |
| **Rollback cost** | Low | High (tag + release + users) |

The unified template was dominated by **code-quality concerns**
(Testing Checklist, Security Checklist, Audit Corrections). For a
release PR, these are mostly **irrelevant** — the code was already
reviewed on `develop`. What matters instead is:

- Version numbers are internally consistent.
- `CHANGELOG.md` is complete.
- The tag plan is correct.
- The back-merge after release is planned.

### The forces at play

| Force | Direction |
|---|---|
| **Release safety** | 🎯 Critical — mistakes affect all users |
| **Reviewer focus** | 🔍 High — the reviewer must see release-specific items first |
| **Discoverability** | 📖 High — contributors must know which template to use |
| **Maintenance cost** | 📉 Medium — two files is manageable |
| **Consistency** | 🔄 Medium — both templates should share structure |
| **Solo maintainer** | 👤 One person, needs clear checklists |

### Constraints

- GitHub supports **multiple PR templates** only if they live in
  `.github/PULL_REQUEST_TEMPLATE/` — the default one stays at
  `.github/PULL_REQUEST_TEMPLATE.md`.
- Non-default templates are opened via `?template=<name>.md` in
  the URL.
- The default template **must remain the unified one** — because
  most PRs are feature/fix/docs.
- The release template must be **self-documenting** — the author
  should understand the release flow from reading it.
- The two templates must not **contradict** each other.

### Scope

This ADR covers **the existence and content of a second PR
template**. It does **not** cover:

- The unified template's content → see
  [ADR-0004](0004-unified-pr-template.md).
- Branch structure → see [ADR-0001](0001-two-branch-model.md).
- Release automation → see [ADR-0002](0002-automated-releases.md).
- The PATCH-release script name → see
  [ADR-0006](0006-rename-hotfix-to-release-patch.md).

---

## Decision

> **We will create a second PR template at**
> **`.github/PULL_REQUEST_TEMPLATE/release.md`, dedicated to**
> **releases from `release/*` and `hotfix/*` branches into `main`.**
>
> **The unified template at `.github/PULL_REQUEST_TEMPLATE.md`**
> **remains the default and continues to serve all other PR types.**

### Specifics

#### File layout

```text
.github/
├── PULL_REQUEST_TEMPLATE.md         ← default (unified)
└── PULL_REQUEST_TEMPLATE/
    └── release.md                   ← release-specific
```

#### When each template applies

| Branch prefix | Base | Template to use |
|---|---|---|
| `feature/*` | `develop` | Default (`PULL_REQUEST_TEMPLATE.md`) |
| `fix/*` | `develop` | Default |
| `docs/*` | `develop` | Default |
| `chore/*` | `develop` | Default |
| `refactor/*` | `develop` | Default |
| `test/*` | `develop` | Default |
| `release/*` | `main` | **Release template** (`?template=release.md`) |
| `hotfix/*` | `main` | **Release template** (`?template=release.md`) |

#### How the release template is opened

Because GitHub only auto-applies the **default** template, the
release template must be selected explicitly:

```text
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.4.0?template=release.md
```

**Mitigation**:

- `docs/BRANCHING.md` §4.4 documents the URL pattern.
- `docs/RELEASE_PROCESS.md` §5 includes the pre-built link.
- `.github/PULL_REQUEST_TEMPLATE.md` includes a one-line reminder
  at the top pointing to the release template for releases.

#### Content of `release.md`

The release template covers **only** what matters for a release:

1. **Header**: version being released + target branch (`main`).
2. **Pre-flight checklist**:
   - [ ] On `release/*` or `hotfix/*` branch.
   - [ ] `VERSION`, `module.prop`, `update.json` are in sync.
   - [ ] `versionCode` computed correctly.
   - [ ] `CHANGELOG.md` updated for this version.
3. **Version summary**: explicit fields for `version` and
   `versionCode`.
4. **Changes overview**: brief list of what's included in the
   release.
5. **Post-merge plan**:
   - [ ] Tag push command documented.
   - [ ] `release.yml` will auto-publish.
   - [ ] `main → develop` sync planned (automatic for
     `release/*`, manual for `hotfix/*`).
6. **Rollback plan**: what to do if the release is broken.
7. **Reviewer checklist** specific to releases.

#### Design principles for `release.md`

| Principle | Implementation |
|---|---|
| **Concise** | Under 100 lines — it is filled in under 5 minutes. |
| **Version-first** | The version pair appears at the top, before anything else. |
| **Post-merge-aware** | Explicit reminders about tagging and back-merging. |
| **Consistent** | Uses the same Markdown conventions as the default template. |
| **No feature noise** | Omits Testing / Security / Audit sections — the code was already reviewed on `develop`. |

### Diagram

```text
Contributor opens a PR
        │
        ├── feature/* → develop ────▶ Default template
        ├── fix/*     → develop ────▶ Default template
        ├── docs/*    → develop ────▶ Default template
        │
        ├── release/* → main ───────▶ ?template=release.md
        └── hotfix/*  → main ───────▶ ?template=release.md
```

---

## Consequences

### Positive

- ✅ **Focused release review.** The reviewer sees version
  correctness, `CHANGELOG` completeness, and tag plan — not
  generic code checkboxes.
- ✅ **Fewer release mistakes.** The version pair is verified
  against the computed `versionCode` before the PR is merged.
- ✅ **Clear post-merge steps.** The template includes the tag push
  and the back-merge reminders, reducing the chance of forgetting
  them.
- ✅ **Consistent with ADR principles.** The reversal of ADR-0004
  is explicit and auditable, not silent.
- ✅ **No disruption to feature contributors.** The default
  template is unchanged.
- ✅ **Backward compatible.** Nothing in the release process is
  modified — only how the PR is documented.

### Negative

- ❌ **Two files to maintain.** Any change to the branch policy or
  the release process must be reflected in **both** templates.
- ❌ **Discoverability gap.** GitHub does **not** auto-apply the
  release template — the author must know to append
  `?template=release.md`. Mitigated by documentation in
  `docs/BRANCHING.md` §4.4 and a top-level reminder in the
  default template.
- ❌ **Silent fallback to default.** If the contributor forgets the
  query string, the default template opens. The PR still works,
  but without release-specific checklists.
- ❌ **Documentation overhead.** Every reference to "the PR
  template" must now specify which one.
- ❌ **Slight CI complexity.** Markdownlint now covers two PR
  templates instead of one.

### Neutral

- ⚪ **The release template lives in a subfolder.** GitHub's
  convention is `.github/PULL_REQUEST_TEMPLATE/` for multiple
  templates.
- ⚪ **The default template gets one extra line** pointing to the
  release template.
- ⚪ **No new CI workflow** is required — the existing markdownlint
  job covers the new file.

---

## Alternatives Considered

| Alternative | Pros | Cons | Why rejected |
|---|---|---|---|
| **Keep only the unified template** (no change) | ✅ One file<br>✅ Zero maintenance<br>✅ Discoverable by default | ❌ Release PRs miss version-specific checklists<br>❌ Reviewer must manually hunt for `VERSION`, `versionCode`, `CHANGELOG`<br>❌ Post-merge steps get forgotten<br>❌ Contradicts the reason ADR-0004 was questioned | The whole point of this ADR is to close the gap. Keeping the unified template alone would leave the release PR case unaddressed. |
| **Replace the unified template with a release-only template** | ✅ One file<br>✅ Perfect for releases<br>✅ Discoverable by default | ❌ Every feature/fix PR would show release checkboxes<br>❌ Release sections would be deleted 90% of the time<br>❌ Confusing for contributors<br>❌ Regression in feature-PR quality | Features are the majority of PRs. Optimizing the default for the rare case is the wrong trade-off. |
| **Use YAML Issue Forms for PRs** | ✅ Structured fields<br>✅ Required vs optional<br>✅ Beautiful UI | ❌ **Not supported for PRs** — YAML forms are an Issues-only feature<br>❌ Would require an Issue-first workflow for releases (extra friction) | Technically impossible. GitHub's YAML forms apply to Issues only, and there is no roadmap to extend them to PRs. |
| **Single template with a "Release mode" section that the author uncomments** | ✅ One file<br>✅ Author chooses what to keep | ❌ Relies on the author remembering to uncomment<br>❌ HTML comment blocks are invisible in the rendered PR<br>❌ No guarantee the release section is used<br>❌ Inconsistent PR quality | The uncommenting pattern is error-prone and undiscoverable. It works in theory, fails in practice. |
| **Query-string template only** (`.github/PULL_REQUEST_TEMPLATE/release.md` without keeping the default) | ✅ Same file layout as the chosen option | ❌ Without a default template, GitHub shows "Open a blank PR"<br>❌ Contributors must always append `?template=...`<br>❌ Worse UX than having a default | The default template is essential for the 90% case. Removing it trades a small gain for a large loss. |
| **Unified default + release-specific sub-template (chosen)** | ✅ Best of both:<br>  • Default works for 90% of PRs<br>  • Release template covers the 10% critical case<br>  • Both are documented<br>  • Reversal of ADR-0004 is explicit | ❌ Two files<br>❌ Discoverability requires documentation | — |

---

## Relationship with ADR-0004

[ADR-0004](0004-unified-pr-template.md) decided to use a **single
unified template**. This ADR **supersedes** that decision by
introducing a **second template**.

### What changed

| Aspect | ADR-0004 | ADR-0005 (this) |
|---|---|---|
| Number of templates | 1 | 2 |
| Default template | Unified | Unified (unchanged) |
| Release PRs | Use the default | Use `release.md` |
| Reversal documented? | — | ✅ Yes, in ADR-0005 |
| Original ADR status | Accepted | **Superseded** |

### What did NOT change

- ✅ The default template's content remains as defined in ADR-0004.
- ✅ The branch policy from
  [ADR-0001](0001-two-branch-model.md) is unchanged.
- ✅ The release pipeline from
  [ADR-0002](0002-automated-releases.md) is unchanged.
- ✅ The post-release sync from
  [ADR-0003](0003-post-release-sync.md) is unchanged.

### Why reversal is documented, not hidden

ADR-0004 was accepted and then reversed **on the same day**. Rather
than editing ADR-0004 or deleting it, we:

1. Kept ADR-0004 as-is, marking it `Superseded`.
2. Documented the reversal reasoning in ADR-0004's "Why Reversed"
   section.
3. Documented the new decision in this ADR-0005.

This is the ADR system working as designed: **history is preserved,
decisions are traceable, and readers can understand the full
journey**.

---

## Related Decisions

| ADR | Relationship |
|---|---|
| [ADR-0001](0001-two-branch-model.md) | The two-branch model creates the need for two templates. |
| [ADR-0002](0002-automated-releases.md) | Release PRs trigger the automation defined in ADR-0002 when merged. |
| [ADR-0003](0003-post-release-sync.md) | The release template reminds the author of the automatic sync. |
| [ADR-0004](0004-unified-pr-template.md) | **Superseded by this ADR.** Provided the original unified template. |
| [ADR-0006](0006-rename-hotfix-to-release-patch.md) | Defines the PATCH-release script that the release template's post-merge section references. |

---

## References

### Project files

- [`.github/PULL_REQUEST_TEMPLATE/release.md`](../../.github/PULL_REQUEST_TEMPLATE/release.md) —
  the release-specific template.
- [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) —
  the default unified template.
- [`docs/BRANCHING.md`](../BRANCHING.md) §4.4 — when to use which
  template.
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §5 — the
  release PR flow; §6.5 — the query-string pattern.
- [`docs/DEVELOPMENT.md`](../DEVELOPMENT.md) §6 — release summary
  for developers.
- [`docs/UPGRADE.md`](../UPGRADE.md) — version upgrade guide
  (§3.1 covers v1.0.0 → v1.1.0; §3.2 covers v1.1.0 → v1.2.0;
  §3.3 covers v1.2.0 → v1.3.0; §3.4 covers v1.3.0 → v1.4.0 — all
  four used the release template).
- [`scripts/release.sh`](../../scripts/release.sh) — the local
  release automation.
- [`scripts/release-patch.sh`](../../scripts/release-patch.sh) —
  the PATCH-release variant.
- [`docs/adr/0004-unified-pr-template.md`](0004-unified-pr-template.md) —
  the superseded decision.
- [`docs/BACKUP.md`](../BACKUP.md) — backup system reference
  (v1.2.0 additions to the release template).
- [`docs/EMERGENCY.md`](../EMERGENCY.md) — emergency recovery
  (v1.2.0 additions to the release template).
- [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.13 — v1.3.0
  server-side rotation refinements (SNAP-*/ROT-*); §4.1 and §11.37
  — MAIN-01 load-order fix (v1.4.0).
- [`docs/COMPATIBILITY.md`](../COMPATIBILITY.md) §10.3.5 — on-device
  SNAP-*/ROT-* verification procedure.
- [`docs/GLOSSARY.md`](../GLOSSARY.md) — SNAP-*/ROT-* terms,
  Rotation Guardian badge.
- [`docs/HALL_OF_FAME.md`](../HALL_OF_FAME.md) — Rotation Guardian
  + Companion App Champion badges.

### External references

- [GitHub Docs — Creating a pull request template](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository)
- [GitHub Docs — Using multiple pull request templates](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository) (query-string selection)
- [GitHub Docs — About automation for issues and pull requests with query parameters](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels#using-query-parameters-to-customize-issues)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

### Discussion

- Original reversal: initiated while writing
  [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md).
- Prior decision: [ADR-0004](0004-unified-pr-template.md).

### Release verification

- **v1.0.0** (2026-09-24) — first release using the release
  template.
  - `release/v1.0.0` → PR against `main` via
    `?template=release.md`.
  - Version-first layout: `version=v1.0.0`, `versionCode=1000000`.
  - All pre-flight checklists completed.
  - Post-merge tag push documented and executed.
  - Auto-sync triggered correctly.
  - **No missing release-specific field** was reported by the
    reviewer.
- **v1.1.0** (2026-09-26) — second release; template unchanged.
  - `release/v1.1.0` → PR against `main` via
    `?template=release.md`.
  - Version-first layout: `version=v1.1.0`, `versionCode=1010000`.
  - All pre-flight checklists completed.
  - The **v1.1.0-specific** checklist items (memory-related
    fields, runtime_info additions) were filled in correctly.
  - Post-merge tag push documented and executed.
  - Auto-sync triggered correctly.
- **v1.2.0** (2026-09-29) — third release; template **extended**
  with v1.2.0-specific checks.
  - `release/v1.2.0` → PR against `main` via
    `?template=release.md`.
  - Version-first layout: `version=v1.2.0`, `versionCode=1020000`.
  - All pre-flight checklists completed.
  - **New v1.2.0 sections** were filled in:
    - "v1.2.0 — data preservation" (10 defensive layers).
    - "v1.2.0 — backup layer verification" (7-field object).
    - "v1.2.0 — watchdog token (WD-TOKEN)".
    - "v1.2.0 — bilingual WebUI (EN + AR)".
    - "v1.2.0 — 42-scenario matrix".
    - "v1.2.0 — breaking change check"
      (`append_denylist content`).
  - Post-merge tag push documented and executed.
  - Auto-sync triggered correctly.
  - The **rollback plan section** documented the data-preservation
    safety net (persistent backup directory preserved on rollback).
- **v1.3.0** (2026-10-02) — fourth release; template **unchanged**.
  - `release/v1.3.0` → PR against `main` via
    `?template=release.md`.
  - Version-first layout: `version=v1.3.0`, `versionCode=1030000`.
  - All pre-flight checklists completed.
  - The **feature-release scope** was documented in the "Changes
    overview" section without needing a new dedicated section.
    This release shipped **three categories** of changes:
    - **Client-side**: PWA install button + live status LED.
    - **Shell-side**: DNS auto-start fix in `service.sh`.
    - **Server-side rotation refinements**: **SNAP-MANIFEST** +
      **SNAP-MTIME** (in `main.go:buildBackupInfo()`) and
      **ROT-MANIFEST** + **ROT-MTIME** + **ROT-PROTECT** (in
      `functions.sh:rotate_backups()`), mirrored in 5 other
      scripts. See [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md)
      §4.13.
  - Post-merge tag push documented and executed.
  - Auto-sync triggered correctly.
  - **Cross-cutting validation**: a release touching client-side
    JS, shell scripts, Go code, and backup/rotation semantics
    across 8+ files was handled by the same release template
    without any structural change.
- **v1.4.0** (2026-10-06) — fifth release; template **unchanged**.
  - `release/v1.4.0` → PR against `main` via
    `?template=release.md`.
  - Version-first layout: `version=v1.4.0`, `versionCode=1040000`.
  - All pre-flight checklists completed.
  - The **integration-release scope** was documented in the
    "Changes overview" section. It shipped:
    - Companion Android app (`web/app-debug.apk`, **optional**).
    - CodeQL `go/path-injection` fix in `removeModule`.
    - iOS PWA logic removal.
    - **MAIN-01** — `LOG_LEVEL` loaded immediately after
      `initPaths()` in `main.go`. See
      [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.1 and
      §11.37.
  - The companion app is an **optional** asset — the release
    template's rollback plan section documented that a failed
    companion APK fetch does **not** fail the release. No
    rollback was required.
  - Post-merge tag push documented and executed.
  - Auto-sync triggered correctly.
  - **No new template section** was needed for the companion
    integration, the CodeQL fix, or the startup-order fix — the
    existing structure scaled as intended.
- **Discoverability** — verified:
  - `docs/BRANCHING.md` §4.4 documents the query-string pattern.
  - `docs/RELEASE_PROCESS.md` §5 includes a pre-built link.
  - `.github/PULL_REQUEST_TEMPLATE.md` contains the one-line
    reminder.
  - No contributor has needed to ask which template to use.
- **Rollback plan section** — never exercised (all five releases
  were successful).
- **Next review**: v1.5.0 cycle (or when the PR workflow changes).
- See `CHANGELOG.md` for the full release history.

---

*This ADR is immutable. To reverse or amend it, create a new ADR
that supersedes it and update its Status line.*
