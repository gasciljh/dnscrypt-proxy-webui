# ADR-0005: Release-Specific PR Template

**Status**: ✅ Accepted

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: [ADR-0004](0004-unified-pr-template.md)

**Superseded by**: —

---

## Context

### The problem

[ADR-0004](0004-unified-pr-template.md) adopted a single unified PR
template. That decision was valid for **most** pull requests — features,
fixes, docs, chores, refactors, tests.

But it under-served **one specific case**: **release PRs** (from
`release/*` or `hotfix/*` branches targeting `main`).

A release PR has a **different lifecycle, different risks, and different
review concerns** than a feature PR:

| Aspect | Feature PR | Release PR |
|---|---|---|
| **Frequency** | Weekly | Monthly at most |
| **Target branch** | `develop` | `main` |
| **Impact if wrong** | Broken `develop` (fixable) | Broken release (users affected) |
| **Key files touched** | `proxy/*`, `web/*` | `VERSION`, `module.prop`, `update.json`, `CHANGELOG.md` |
| **Post-merge action** | None | Automatic release publish |
| **Reviewer focus** | Code quality | Version correctness + release readiness |
| **Rollback cost** | Low | High (tag + release + users) |

The unified template was dominated by **code-quality concerns** (Testing
Checklist, Security Checklist, Audit Corrections). For a release PR,
these are mostly **irrelevant** — the code was already reviewed on
`develop`. What matters instead is:

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
- Non-default templates are opened via `?template=<name>.md` in the URL.
- The default template **must remain the unified one** — because most
  PRs are feature/fix/docs.
- The release template must be **self-documenting** — the author should
  understand the release flow from reading it.
- The two templates must not **contradict** each other.

### Scope

This ADR covers **the existence and content of a second PR template**.
It does **not** cover:

- The unified template's content → see [ADR-0004](0004-unified-pr-template.md).
- Branch structure → see [ADR-0001](0001-two-branch-model.md).
- Release automation → see [ADR-0002](0002-automated-releases.md).
- The PATCH-release script name → see [ADR-0006](0006-rename-hotfix-to-release-patch.md).

---

## Decision

> **We will create a second PR template at**
> **`.github/PULL_REQUEST_TEMPLATE/release.md`, dedicated to releases**
> **from `release/*` and `hotfix/*` branches into `main`.**
>
> **The unified template at `.github/PULL_REQUEST_TEMPLATE.md` remains**
> **the default and continues to serve all other PR types.**

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

Because GitHub only auto-applies the **default** template, the release
template must be selected explicitly:

```text
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.1.0?template=release.md
```

**Mitigation**:

- `docs/BRANCHING.md` §4.4 documents the URL pattern.
- `docs/RELEASE_PROCESS.md` §5 includes the pre-built link.
- `.github/PULL_REQUEST_TEMPLATE.md` includes a one-line reminder at the
  top pointing to the release template for releases.

#### Content of `release.md`

The release template covers **only** what matters for a release:

1. **Header**: version being released + target branch (`main`).
2. **Pre-flight checklist**:
   - [ ] On `release/*` or `hotfix/*` branch.
   - [ ] `VERSION`, `module.prop`, `update.json` are in sync.
   - [ ] `versionCode` computed correctly.
   - [ ] `CHANGELOG.md` updated for this version.
3. **Version summary**: explicit fields for `version` and `versionCode`.
4. **Changes overview**: brief list of what's included in the release.
5. **Post-merge plan**:
   - [ ] Tag push command documented.
   - [ ] `release.yml` will auto-publish.
   - [ ] `main → develop` sync planned (automatic for `release/*`,
     manual for `hotfix/*`).
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

- ✅ **Focused release review.** The reviewer sees version correctness,
  `CHANGELOG` completeness, and tag plan — not generic code checkboxes.
- ✅ **Fewer release mistakes.** The version pair is verified against
  the computed `versionCode` before the PR is merged.
- ✅ **Clear post-merge steps.** The template includes the tag push and
  the back-merge reminders, reducing the chance of forgetting them.
- ✅ **Consistent with ADR principles.** The reversal of ADR-0004 is
  explicit and auditable, not silent.
- ✅ **No disruption to feature contributors.** The default template
  is unchanged.
- ✅ **Backward compatible.** Nothing in the release process is modified
  — only how the PR is documented.

### Negative

- ❌ **Two files to maintain.** Any change to the branch policy or the
  release process must be reflected in **both** templates.
- ❌ **Discoverability gap.** GitHub does **not** auto-apply the release
  template — the author must know to append `?template=release.md`.
  Mitigated by documentation in `docs/BRANCHING.md` §4.4 and a top-level
  reminder in the default template.
- ❌ **Silent fallback to default.** If the contributor forgets the query
  string, the default template opens. The PR still works, but without
  release-specific checklists.
- ❌ **Documentation overhead.** Every reference to "the PR template"
  must now specify which one.
- ❌ **Slight CI complexity.** Markdownlint now covers two PR templates
  instead of one.

### Neutral

- ⚪ **The release template lives in a subfolder.** GitHub's convention
  is `.github/PULL_REQUEST_TEMPLATE/` for multiple templates.
- ⚪ **The default template gets one extra line** pointing to the release
  template.
- ⚪ **No new CI workflow** is required — the existing markdownlint job
  covers the new file.

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

[ADR-0004](0004-unified-pr-template.md) decided to use a **single unified
template**. This ADR **supersedes** that decision by introducing a
**second template**.

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
- ✅ The branch policy from [ADR-0001](0001-two-branch-model.md) is unchanged.
- ✅ The release pipeline from [ADR-0002](0002-automated-releases.md) is unchanged.
- ✅ The post-release sync from [ADR-0003](0003-post-release-sync.md) is unchanged.

### Why reversal is documented, not hidden

ADR-0004 was accepted and then reversed **on the same day**. Rather than
editing ADR-0004 or deleting it, we:

1. Kept ADR-0004 as-is, marking it `Superseded`.
2. Documented the reversal reasoning in ADR-0004's "Why Reversed" section.
3. Documented the new decision in this ADR-0005.

This is the ADR system working as designed: **history is preserved,
decisions are traceable, and readers can understand the full journey**.

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

- [`.github/PULL_REQUEST_TEMPLATE/release.md`](../../.github/PULL_REQUEST_TEMPLATE/release.md) — the new release-specific template (to be created).
- [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) — the default unified template.
- [`docs/BRANCHING.md`](../BRANCHING.md) §4.4 — when to use which template.
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §5 — the release PR flow.
- [`docs/DEVELOPMENT.md`](../DEVELOPMENT.md) §6 — release summary for developers.
- [`scripts/release.sh`](../../scripts/release.sh) — the local release automation.
- [`scripts/release-patch.sh`](../../scripts/release-patch.sh) — the PATCH-release variant.

### External references

- [GitHub Docs — Creating a pull request template](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository)
- [GitHub Docs — Using multiple pull request templates](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository) (query-string selection)
- [GitHub Docs — About automation for issues and pull requests with query parameters](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels#using-query-parameters-to-customize-issues)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

### Discussion

- Original reversal: initiated while writing
  [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md).
- Prior decision: [ADR-0004](0004-unified-pr-template.md).

---

*This ADR is immutable. To reverse or amend it, create a new ADR that
supersedes it and update its Status line.*