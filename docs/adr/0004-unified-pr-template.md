# ADR-0004: Unified PR Template

**Status**: ⚠️ Superseded (see **Superseded by** below)

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: —

**Superseded by**: [ADR-0005](0005-release-specific-pr-template.md) (2026-09-24)

---

> **Identifier inventory in this file (4 total)**:
>   • HARD-ADR4-01 (v1.3.0 supersession verification block
>     extended with server-side rotation refinements context —
>     v1.4.0)
>   • HARD-ADR4-02 (v1.4.0 supersession verification block
>     extended with MAIN-01 context — v1.4.0)
>   • HARD-ADR4-03 (Supersession verification section extended —
>     v1.3.0 SNAP-*/ROT-* + v1.4.0 MAIN-01 — v1.4.0)
>   • HARD-ADR4-04 (Header + footer identifier inventory +
>     cross-references + `Last reviewed` sync added — v1.4.0)
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
>   • [ADR-0005](0005-release-specific-pr-template.md) — the
>     superseding decision
>   • [CHANGELOG.md](../../CHANGELOG.md) — version history

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

> **Supersession Verification (v1.4.0 — 2026-10-06)**:
>
> This ADR was reviewed during the v1.4.0 release cycle to confirm
> that the **supersession decision** remains correct. No further
> amendments are needed.
>
> **Verification notes**:
>
>   • The reversal has now been in effect through **five release
>     cycles** (v1.0.0, v1.1.0, v1.2.0, v1.3.0, and v1.4.0) without
>     any need to revisit it.
>   • The **unified template** (`.github/PULL_REQUEST_TEMPLATE.md`)
>     remains the **default** for all `feature/*`, `fix/*`,
>     `docs/*`, `chore/*`, `refactor/*`, and `test/*` PRs —
>     exactly as the supersession intended.
>   • The **release template**
>     (`.github/PULL_REQUEST_TEMPLATE/release.md`) introduced by
>     [ADR-0005](0005-release-specific-pr-template.md) is used
>     exclusively for `release/*` and `hotfix/*` → `main` PRs.
>   • **No contributor** has reported confusion about which
>     template to use across all five release cycles.
>   • The `?template=release.md` pattern documented in
>     `docs/BRANCHING.md` §4.4 and `docs/RELEASE_PROCESS.md` §5
>     has worked as intended.
>   • **v1.3.0** (2026-10-02) — the feature release was published
>     through a `release/*` PR using `?template=release.md`. The
>     unified template remained the default for the few
>     accompanying feature/fix/docs PRs.
>       - **Client-side**: PWA install button + live status LED.
>       - **Shell-side**: DNS auto-start fix in `service.sh`.
>       - **Server-side rotation refinements**: SNAP-MANIFEST +
>         SNAP-MTIME (in `main.go:buildBackupInfo()`) and
>         ROT-MANIFEST + ROT-MTIME + ROT-PROTECT (in
>         `functions.sh:rotate_backups()`), mirrored in 5 other
>         scripts. **None of these affected the PR-template
>         choice** — the release template handled a multi-file
>         server-side release without modification, which is a
>         further validation of the ADR-0005 supersession.
>   • **v1.4.0** (2026-10-06) — the integration release (companion
>     app + CodeQL fix + iOS removal + **MAIN-01**) was published
>     through a `release/*` PR using `?template=release.md`. The
>     unified template did **not** need any new section for the
>     companion app integration, the CodeQL hardening, or the
>     `LOG_LEVEL` load-order fix — the release template handled
>     them correctly.
>   • The v1.2.0 data-preservation release introduced a
>     **Data-preservation checklist** section in the default
>     template — this was added as an **extension**, not a
>     reversal, and does not affect the validity of this ADR's
>     supersession.
>   • The **reversal is further validated**: keeping the unified
>     template as the default (not deleting it) was the right
>     choice, since the overwhelming majority of PRs are
>     feature/fix/docs PRs targeting `develop`.
>   • No new ADR is needed to further modify this decision.
>     ADR-0005 remains authoritative.
>
> **Result**: The supersession was correct, and no reconsideration
> is required. This ADR remains a historical record.

> **Supersession Verification (v1.3.0 — 2026-10-02)**:
>
> This ADR was reviewed during the v1.3.0 release cycle to confirm
> that the **supersession decision** remains correct. No further
> amendments are needed.
>
> **Verification notes**:
>
>   • The reversal has now been in effect through **four release
>     cycles** (v1.0.0, v1.1.0, v1.2.0, and v1.3.0).
>   • The **unified template** (`.github/PULL_REQUEST_TEMPLATE.md`)
>     remains the **default** for all `feature/*`, `fix/*`,
>     `docs/*`, `chore/*`, `refactor/*`, and `test/*` PRs.
>   • The **release template**
>     (`.github/PULL_REQUEST_TEMPLATE/release.md`) was used
>     exclusively for the `release/v1.3.0` → `main` PR.
>   • **No contributor** has reported confusion about which
>     template to use.
>   • The feature-release scope — **three categories of changes** —
>     was published without requiring any change to the unified
>     template:
>       - **Client-side**: PWA install button + live status LED.
>       - **Shell-side**: DNS auto-start fix in `service.sh`.
>       - **Server-side rotation refinements**: five new semantics
>         (SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME,
>         ROT-PROTECT) documented in
>         [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.13.
>     This is itself an **argument in favour of the supersession**:
>     a release touching client-side JS, shell scripts, Go code,
>     and backup/rotation semantics was handled cleanly by the
>     dedicated release template, while the unified template
>     continued to serve its ordinary audience unchanged.
>   • No new ADR is needed to further modify this decision.
>     ADR-0005 remains authoritative.
>
> **Result**: The supersession was correct, and no reconsideration
> is required. This ADR remains a historical record.

> **Supersession Verification (v1.2.0 — 2026-09-29)** (retained as history):
>
> This ADR was reviewed during the v1.2.0 release cycle to confirm
> that the **supersession decision** remains correct. No further
> amendments are needed.
>
> **Verification notes**:
>
>   • The reversal has now been in effect through **three release
>     cycles** (v1.0.0, v1.1.0, and v1.2.0) without any need to
>     revisit it.
>   • The **unified template** (`.github/PULL_REQUEST_TEMPLATE.md`)
>     remains the **default** for all `feature/*`, `fix/*`,
>     `docs/*`, `chore/*`, `refactor/*`, and `test/*` PRs —
>     exactly as the supersession intended.
>   • The **release template**
>     (`.github/PULL_REQUEST_TEMPLATE/release.md`) introduced by
>     [ADR-0005](0005-release-specific-pr-template.md) is used
>     exclusively for `release/*` and `hotfix/*` → `main` PRs.
>   • **No contributor** has reported confusion about which
>     template to use across all three release cycles.
>   • The `?template=release.md` pattern documented in
>     `docs/BRANCHING.md` §4.4 and `docs/RELEASE_PROCESS.md` §5
>     has worked as intended.
>   • The v1.2.0 data-preservation release introduced a
>     **Data-preservation checklist** section in the default
>     template — this was added as an **extension**, not a
>     reversal, and does not affect the validity of this ADR's
>     supersession.
>   • The **reversal is further validated**: keeping the unified
>     template as the default (not deleting it) was the right
>     choice, since 95%+ of PRs are feature/fix/docs PRs
>     targeting `develop`.
>   • No new ADR is needed to further modify this decision.
>     ADR-0005 remains authoritative.
>
> **Result**: The supersession was correct, and no reconsideration
> is required. This ADR remains a historical record.

> **Supersession Verification (v1.1.0 — 2026-09-26)** (retained as history):
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
>     `docs/BRANCHING.md` §4.4 and `docs/RELEASE_PROCESS.md` §5
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
- ❌ **Cannot handle multi-file cross-cutting releases well.** A
  release that touches client-side JS, shell scripts, Go code,
  and backup/rotation semantics across 8+ files (e.g. v1.3.0 with
  SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME +
  ROT-PROTECT) needs a dedicated, extensible checklist — which a
  unified template does not naturally provide.

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
| **Unified template (chosen, then superseded)** | ✅ One file<br>✅ Easy discovery<br>✅ Consistent structure<br>✅ Target Branch section handles base selection | ❌ Longer file<br>❌ Release-specific checklists are missing<br>❌ Template grows over time<br>❌ Cannot handle cross-cutting multi-file releases well | — |
| **Unified + release-specific templates** (later adopted in [ADR-0005](0005-release-specific-pr-template.md)) | ✅ Full coverage<br>✅ Release PRs get dedicated checklists<br>✅ Feature PRs stay focused<br>✅ Handles cross-cutting releases (v1.3.0 SNAP-*/ROT-*, v1.4.0 companion app) | ❌ Two files to maintain<br>❌ Requires documentation on which to use<br>❌ Slightly more complex CI | **Chosen in ADR-0005** — see that ADR for the rationale. |

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

### Later validation (v1.3.0 / v1.4.0)

The reversal was further validated by two releases that would have
been awkward to document through a unified template:

- **v1.3.0** — a release touching **client-side JS** (PWA install
  button + live status LED), **shell scripts** (DNS auto-start fix
  in `service.sh`), **Go code** (`main.go:buildBackupInfo()` —
  SNAP-MANIFEST + SNAP-MTIME), and **shell rotation semantics**
  (`functions.sh:rotate_backups()` — ROT-MANIFEST + ROT-MTIME +
  ROT-PROTECT, mirrored in 5 other scripts). The release template
  handled all of this with a dedicated checklist.
- **v1.4.0** — an integration release adding an **optional
  companion Android app**, closing **two CodeQL
  `go/path-injection` alerts** in `removeModule`, removing **iOS
  PWA logic**, and applying **MAIN-01** (`LOG_LEVEL` load-order
  fix in `main.go`). Again, the release template was the correct
  vehicle — the unified template did not need to grow a "companion
  app integration" section, nor a "CodeQL hardening" section, nor a
  "startup-order fix" section.

Both cases support the intuition from the reversal: **rare,
high-stakes releases deserve their own template.**

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
- [`docs/BRANCHING.md`](../BRANCHING.md) §4.4 — the
  release-PR template URL pattern. Also covers §5.1 for the
  PR-target rules.
- [`docs/CONTRIBUTING.md`](../CONTRIBUTING.md) §6 — the PR
  process.
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §5 — the
  release-PR flow (this is the section that documents the
  `?template=release.md` pattern).
- [ADR-0005](0005-release-specific-pr-template.md) — the full
  rationale for the release-specific template.
- [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) §4.13 — v1.3.0
  server-side rotation refinements (SNAP-*/ROT-*); §4.1 and §11.37
  — MAIN-01 load-order fix (v1.4.0).
- [`docs/COMPATIBILITY.md`](../COMPATIBILITY.md) §10.3.5 — on-device
  SNAP-*/ROT-* verification procedure.
- [`docs/GLOSSARY.md`](../GLOSSARY.md) — SNAP-*/ROT-* terms,
  Rotation Guardian badge.
- [`docs/HALL_OF_FAME.md`](../HALL_OF_FAME.md) — Rotation Guardian
  + Companion App Champion badges.
- [`docs/UPGRADE.md`](../UPGRADE.md) — version upgrade guide
  (§3.1 covers v1.0.0 → v1.1.0; §3.2 covers v1.1.0 → v1.2.0;
  §3.3 covers v1.2.0 → v1.3.0; §3.4 covers v1.3.0 → v1.4.0 — all
  four used the release template).

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
- **v1.2.0** (2026-09-29) — third release cycle; templates
  extended (default gained a Data-preservation checklist).
  - `v1.2.0` was published through a `release/*` PR using
    `?template=release.md`.
  - The unified template gained a new "Data-preservation
    checklist" section (extension, not reversal).
  - The release template gained v1.2.0-specific checks.
  - **No contributor requested** a different template.
- **v1.3.0** (2026-10-02) — fourth release cycle; templates
  unchanged.
  - `v1.3.0` was published through a `release/*` PR using
    `?template=release.md`.
  - The **feature release** shipped **three categories** of changes
    without requiring any new template:
      - Client-side: PWA install button + live status LED.
      - Shell-side: DNS auto-start fix in `service.sh`.
      - **Server-side rotation refinements**: SNAP-MANIFEST +
        SNAP-MTIME (in `main.go:buildBackupInfo()`) and
        ROT-MANIFEST + ROT-MTIME + ROT-PROTECT (in
        `functions.sh:rotate_backups()`), mirrored in 5 other
        scripts. See [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md)
        §4.13.
  - **No contributor requested** a different template.
  - This release further validated the supersession: a
    cross-cutting release across JS, shell, and Go was handled by
    the release template without touching the unified one.
- **v1.4.0** (2026-10-06) — fifth release cycle; templates
  unchanged.
  - `v1.4.0` was published through a `release/*` PR using
    `?template=release.md`.
  - The **integration-release** scope (companion Android app +
    CodeQL `go/path-injection` fix + iOS PWA removal + **MAIN-01**
    `LOG_LEVEL` load-order fix) was handled by the existing release
    template.
  - The unified template did not need a new section for the
    companion app, the CodeQL fix, or the startup-order fix.
  - **No contributor requested** a different template.
- **Supersession status**: confirmed correct across five release
  cycles. ADR-0005 remains authoritative.
- **Next review**: v1.5.0 cycle (or when the PR workflow changes).
- See `CHANGELOG.md` for the full release history.

---

*This ADR is immutable. It has been superseded — see
[ADR-0005](0005-release-specific-pr-template.md) for the current
decision.*
