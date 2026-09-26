# ADR-0004: Unified PR Template

**Status**: ⚠️ Superseded by [ADR-0005](0005-release-specific-pr-template.md)

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: —

**Superseded by**: [ADR-0005](0005-release-specific-pr-template.md) (2026-09-24)

---

> **⚠️ Historical ADR — Superseded**
>
> This decision was **reversed** on the same day it was made, after
> reviewing the release workflow in more depth. See
> [ADR-0005](0005-release-specific-pr-template.md) for the current
> decision and the rationale for the reversal.
>
> The content below is preserved **as-is** to document the original
> reasoning and to keep the decision history auditable.

---

> **Supersession Verification (v1.1.0 — 2026-09-26)**:
>
> This ADR was reviewed during the v1.1.0 release cycle to confirm
> that the **supersession decision** remains correct. No further
> amendments are needed.
>
> **Verification notes**:
>
>   • The reversal has been in effect through **two release cycles**
>     (v1.0.0 and v1.1.0) without any need to revisit it.
>   • The **unified template** (`.github/PULL_REQUEST_TEMPLATE.md`)
>     remains the **default** for all `feature/*`, `fix/*`, `docs/*`,
>     `chore/*`, `refactor/*`, and `test/*` PRs — exactly as the
>     supersession intended.
>   • The **release template**
>     (`.github/PULL_REQUEST_TEMPLATE/release.md`) introduced by
>     [ADR-0005](0005-release-specific-pr-template.md) is used
>     exclusively for `release/*` and `hotfix/*` → `main` PRs.
>   • No contributor has reported confusion about which template
>     to use. The `?template=release.md` pattern documented in
>     `docs/BRANCHING.md` §4.4 and `docs/RELEASE_PROCESS.md` §6.5
>     has worked as intended.
>   • The **reversal is validated**: keeping the unified template
>     as the default (not deleting it) was the right choice, since
>     95%+ of PRs are feature/fix/docs PRs targeting `develop`.
>   • No new ADR is needed to further modify this decision. ADR-0005
>     remains authoritative.
>
> **Result**: The supersession was correct, and no reconsideration
> is required. This ADR remains a historical record.

---

## Context

### The problem

With the two-branch model adopted in
[ADR-0001](0001-two-branch-model.md), pull requests can target
**two different base branches**:

- `develop` — for features, fixes, docs, chores, refactors, tests.
- `main` — for `release/*` and `hotfix/*` only.

The `PULL_REQUEST_TEMPLATE.md` file (added as part of the workflow
overhaul) initially needed to handle both cases.

### The forces at play

| Force | Direction |
|---|---|
| **Contributor clarity** | 🎯 High — PR authors must know which base branch to use |
| **Maintenance cost** | 📉 Low — one file is easier to update than many |
| **CI efficiency** | ⚡ Medium — fewer templates = fewer files for the linter |
| **Reviewer efficiency** | 🔍 High — the template must surface critical info |
| **Solo maintainer** | 👤 One person, limited time |

### Constraints

- GitHub supports **only one** `PULL_REQUEST_TEMPLATE.md` per
  repository at the root of `.github/`, `docs/`, or the repository
  itself.
- Multiple templates require the **query-string trick**
  (`?template=feature.md`), which is undiscoverable.
- YAML-based Issue Forms are **not available** for PRs (only
  Issues).
- The template must remain **valid Markdown** (rendered by GitHub).

### Scope

This ADR covers **the number of PR templates** used in the project.
It does **not** cover:

- The **content** of the template — see
  `.github/PULL_REQUEST_TEMPLATE.md`.
- Branch structure → see [ADR-0001](0001-two-branch-model.md).
- Release process → see [ADR-0002](0002-automated-releases.md).

---

## Decision

> **We will adopt a single unified PR template,**
> **`.github/PULL_REQUEST_TEMPLATE.md`, that serves all PR types**
> **(feature, fix, docs, release, hotfix).**

### Specifics

1. **One file only**: `.github/PULL_REQUEST_TEMPLATE.md`.
2. **Target branch selector** at the top:
   - A `🎯 Target Branch` section with checkboxes.
   - A quick-reference table mapping branch prefixes to base
     branches.
3. **Sections**:
   - `🎯 Target Branch` (new, to handle the two-branch model).
   - `📝 Description`.
   - `🔗 Related Issue`.
   - `🏷️ Change Type`.
   - `🔍 Audit Correction`.
   - `🧪 Testing`.
   - `🔒 Security Checklist`.
   - `📖 Documentation`.
   - `✅ Final Checklist`.
   - `🖼️ Screenshots`.
   - `📌 Additional Notes`.
   - `🎯 Reviewer Suggestion`.
4. **Branch policy block** in the Final Checklist:
   - "PR target is `develop` (or `main` **only** for `release/*` /
     `hotfix/*`)."
5. **Final reminder** (bottom of the file):
   - An ASCII box explaining the branch policy.
   - A list of pre-push verification commands.

### Diagram

```text
.github/
└── PULL_REQUEST_TEMPLATE.md      ← ONE file for everything
        │
        ├── 🎯 Target Branch      ← author selects: develop or main
        ├── 📝 Description
        ├── 🔗 Related Issue
        ├── 🏷️ Change Type
        ├── 🔍 Audit Correction
        ├── 🧪 Testing
        ├── 🔒 Security Checklist
        ├── 📖 Documentation
        ├── ✅ Final Checklist
        ├── 🖼️ Screenshots
        ├── 📌 Additional Notes
        └── 🎯 Reviewer Suggestion
```

---

## Consequences

### Positive

- ✅ **Single source of truth.** Only one file to update when the
  contribution process changes.
- ✅ **Automatic discovery.** GitHub applies it to **every** new PR
  — no query-string trick required.
- ✅ **Consistent structure.** Reviewers know exactly where to look.
- ✅ **Target branch clarity.** The `🎯 Target Branch` section
  handles the two-branch model explicitly.
- ✅ **Fewer files to lint.** `markdownlint` runs on one file, not
  five.
- ✅ **Simple maintenance.** One author maintains one file.

### Negative

- ❌ **Longer template.** A release PR must scroll past
  feature-specific sections (like the Audit Correction registry).
- ❌ **Release-specific context is buried.** The `🎯 Target Branch`
  section tells the author the base is `main`, but there is no
  release-specific checklist (e.g. "verify `CHANGELOG.md` was
  updated", "confirm version bump in `module.prop`").
- ❌ **Feature contributors may skip release sections.** Nothing in
  the template enforces that release-specific fields are filled.
- ❌ **The template grows over time.** Every new workflow addition
  (e.g. a new CI check) adds a line, making the template denser.
- ❌ **Not optimal for the release workflow.** Releases have a
  specific, short lifecycle (bump, tag, publish) that a
  general-purpose template does not capture well.

### Neutral

- ⚪ **Templates are Markdown.** GitHub renders them as-is; the
  author can delete sections freely.
- ⚪ **HTML comments** in the template provide guidance without
  cluttering the rendered view.
- ⚪ **The template lives in `.github/`** — the recommended
  location per GitHub docs.

---

## Alternatives Considered

| Alternative | Pros | Cons | Why rejected |
|---|---|---|---|
| **Multiple templates** (feature.md, release.md, bug.md) | ✅ Each PR type sees a focused template<br>✅ Shorter individual files | ❌ GitHub shows **only the default** — others require `?template=...` in the URL, which is undiscoverable<br>❌ More files to maintain<br>❌ Inconsistent structure across templates<br>❌ Extra files linted by CI | The default template is what contributors see **by default**. Relying on contributors to guess a query-string parameter defeats the purpose. |
| **No template** | ✅ Zero maintenance<br>✅ Zero constraints on authors | ❌ Inconsistent PR descriptions<br>❌ Missing critical info (device, ROM, logs, tests)<br>❌ More back-and-forth during review<br>❌ Reviewers must ask the same questions repeatedly | A template is a **forcing function** for quality. Without it, PRs degrade to "Fix bug" with no context — a pattern seen in many open-source projects. |
| **YAML Issue Forms** (used for Issues) | ✅ Structured fields<br>✅ Required vs optional<br>✅ Beautiful rendering in GitHub UI | ❌ **Not supported for PRs** — YAML forms are an **Issues-only** feature<br>❌ Would require contributors to open an Issue before every PR (indirect flow) | Technically impossible. GitHub's YAML forms apply to Issues only. |
| **Template query-string approach** (`?template=release.md`) | ✅ Allows per-type templates<br>✅ Stays in one folder | ❌ Requires the author to know and type the query string<br>❌ Broken links in docs easily<br>❌ Not discoverable from the New PR page<br>❌ PWA shortcut generation issues | Discoverability wins. Most contributors will not know to append `?template=release.md`. |
| **Unified template (chosen, then superseded)** | ✅ One file<br>✅ Easy discovery<br>✅ Consistent structure<br>✅ Target Branch section handles base selection | ❌ Longer file<br>❌ Release-specific checklists are missing<br>❌ Template grows over time | — |
| **Unified + release-specific templates** (later adopted in [ADR-0005](0005-release-specific-pr-template.md)) | ✅ Full coverage<br>✅ Release PRs get dedicated checklists<br>✅ Feature PRs stay focused | ❌ Two files to maintain<br>❌ Requires documentation on which to use<br>❌ Slightly more complex CI | **Chosen in ADR-0005** — see that ADR for the rationale. |

---

## Why This Decision Was Later Reversed

### The trigger

While drafting the release workflow documentation (see
[`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) and
[ADR-0002](0002-automated-releases.md)), the following became clear:

**A release PR has a very specific, short lifecycle:**

1. Bump `VERSION` + `module.prop` + `update.json`.
2. Update `CHANGELOG.md`.
3. Open a PR against `main`.
4. Wait for CI.
5. Merge (triggers `release.yml` on tag).

None of these steps fit naturally in the unified template, which is
dominated by feature-PR concerns (Testing Checklist, Security
Checklist, Audit Corrections, etc.).

### The insight

Releases are **rare** (monthly at most) but **high-stakes** (a
mistake breaks user updates). Features are **frequent** but
**low-stakes** (iterations are cheap).

**A single template optimized for frequency under-serves the rare
high-stakes case.**

### The reversal

- ADR-0005 introduces `.github/PULL_REQUEST_TEMPLATE/release.md` —
  a dedicated template for `release/*` and `hotfix/*` PRs.
- The unified template remains the **default** for all other PRs.
- `docs/BRANCHING.md` §4.4 documents when to use which.

This is the **first reversal** in the project's ADR history — and
it demonstrates exactly why ADRs are valuable: the reversal is
**explicit**, **reasoned**, and **traceable**, rather than a silent
change buried in a commit.

---

## Related Decisions

| ADR | Relationship |
|---|---|
| [ADR-0001](0001-two-branch-model.md) | This ADR's `🎯 Target Branch` section exists because of the two-branch model. |
| [ADR-0005](0005-release-specific-pr-template.md) | **Supersedes this ADR.** Introduces the release-specific template. |
| [ADR-0006](0006-rename-hotfix-to-release-patch.md) | Complements this ADR by formalizing the PATCH-release flow (which uses the release template from ADR-0005). |

---

## References

### Project files

- [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) —
  the unified template.
- [`.github/PULL_REQUEST_TEMPLATE/release.md`](../../.github/PULL_REQUEST_TEMPLATE/release.md) —
  the release-specific template (introduced by ADR-0005).
- [`docs/BRANCHING.md`](../BRANCHING.md) §5.1 — the PR-target
  rules.
- [`docs/CONTRIBUTING.md`](../CONTRIBUTING.md) §6 — the PR
  process.
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §6 — release
  PR steps.
- [`docs/UPGRADE.md`](../UPGRADE.md) — version upgrade guide
  (v1.0.0 → v1.1.0 used the release template).

### External references

- [GitHub Docs — Creating a pull request template](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository)
- [GitHub Docs — About issue and pull request templates](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/about-issue-and-pull-request-templates)
- [GitHub Docs — Syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms) (not available for PRs — relevant as confirmation)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

### Discussion

- Initial decision: see commit history for
  `.github/PULL_REQUEST_TEMPLATE.md`.
- Reversal: see [ADR-0005](0005-release-specific-pr-template.md)
  and the corresponding commit that added
  `.github/PULL_REQUEST_TEMPLATE/release.md`.

### Supersession verification

- **v1.0.0** (2026-09-24) — first release cycle using the two
  templates.
  - `v1.0.0` was published through a `release/*` PR using
    `?template=release.md`.
  - No confusion reported by the maintainer.
  - The unified template remained the default for feature/fix/docs
    PRs.
- **v1.1.0** (2026-09-26) — second release cycle; templates
  unchanged.
  - `v1.1.0` was published through a `release/*` PR using
    `?template=release.md`.
  - No new template was needed.
  - **No contributor requested** a different template or reported
    the query-string pattern as a problem.
- **Supersession status**: confirmed correct. ADR-0005 remains
  authoritative.
- **Next review**: v1.2.0 cycle (or when the PR workflow changes).
- See `CHANGELOG.md` for the full release history.

---

*This ADR is immutable. It has been superseded — see
[ADR-0005](0005-release-specific-pr-template.md) for the current
decision.*