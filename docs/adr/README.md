# Architecture Decision Records (ADRs) — DNSCrypt Smart Filter

> A curated log of the architectural and process decisions that
> shape the project.

**Version**: v1.1.0
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • `Last updated` reflects the v1.1.0 release date.
>   • §3.3 (Examples from this project) extended with the
>     v1.1.0 runtime improvements (MEM-1 / MEM-2 / MEM-3) as
>     examples of contributions that do **not** need an ADR.
>   • §6.5 (Index Statistics) annotated with the v1.0.0 and
>     v1.1.0 release cycles.
>   • **New subsection** §6.6 — ADRs by Release Cycle — for a
>     clear timeline view.
>   • §9 (Relationship with CHANGELOG) extended with a new
>     subsection "Runtime Improvements vs ADRs" that explains
>     why MEM-1/2/3 did not generate ADRs.
>   • §10 (References) extended with `docs/UPGRADE.md`.
>   • No new ADRs were added in v1.1.0. The registry remains at
>     **6 ADRs** (5 accepted + 1 superseded).

> **📖 Related documents**:
> - Git workflow → [`../BRANCHING.md`](../BRANCHING.md)
> - Release process → [`../RELEASE_PROCESS.md`](../RELEASE_PROCESS.md)
> - Contribution guide → [`../CONTRIBUTING.md`](../CONTRIBUTING.md)
> - Architecture → [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
> - Version upgrade guide → [`../UPGRADE.md`](../UPGRADE.md)

---

## Table of Contents

1. [What is an ADR?](#1-what-is-an-adr)
2. [Why ADRs?](#2-why-adrs)
3. [When to Create an ADR?](#3-when-to-create-an-adr)
4. [ADR Lifecycle](#4-adr-lifecycle)
5. [File Naming & Location](#5-file-naming--location)
6. [ADR Index](#6-adr-index)
7. [Template](#7-template)
8. [Writing Guidelines](#8-writing-guidelines)
9. [Relationship with CHANGELOG](#9-relationship-with-changelog)
10. [References](#10-references)

---

## 1. What is an ADR?

An **Architecture Decision Record (ADR)** is a short, immutable
document that captures a **significant decision** made during the
project's lifetime.

Each ADR answers three questions:

| Question | Purpose |
|---|---|
| **What** was decided? | The decision itself. |
| **Why** was it decided? | The context and forces at play. |
| **What are the consequences?** | What becomes easier / harder as a result. |

ADRs are:

- **Lightweight** — one file per decision, 30-100 lines.
- **Immutable** — never edited after acceptance; reversed by a new
  ADR.
- **Numbered** — sequential, never reused.
- **Versioned** — committed to the repository alongside code.

The concept was popularized by Michael Nygard in 2011 and is used by
Kubernetes, Rust, React, and dozens of other major projects.

**In this project**: ADRs are used for both **process** decisions
(e.g. the two-branch model) and **architectural** decisions. See
§3.3 for examples across both v1.0.0 and v1.1.0.

---

## 2. Why ADRs?

### 2.1 Problems they solve

| Problem | Without ADRs | With ADRs |
|---|---|---|
| **Lost context** | "Why did we do this?" — nobody remembers | Documented in one place |
| **Repeated debates** | The same discussion resurfaces every 6 months | Read ADR-00XX first |
| **Silent reversals** | Decision changed in a PR without notice | Superseding ADR is explicit |
| **Onboarding friction** | New contributors rediscover history | Read the ADR index |
| **Audit trail** | No trace of when/why a choice was made | Immutable log |

**Example**: The v1.1.0 runtime improvement MEM-1 (dynamic memory
limit) touched `main.go`, `functions.sh`, four shell scripts, and
the `runtime_info` API. Without the ADR system, a future
contributor might wonder: "Why does `main.go` call
`applyMemoryLimit()` at startup **and** after every profile change?"

The answer — "because the limit is a function of the active
profile, and profile changes happen at those two points" — is
trivial to document, but easy to lose. Whether it warrants a full
ADR is a judgment call (see §3.3); what matters is that the
**rationale is captured somewhere canonical**.

### 2.2 What they are NOT

- ❌ **Not a tutorial** — see `docs/ARCHITECTURE.md`.
- ❌ **Not a changelog** — see `CHANGELOG.md`.
- ❌ **Not a spec** — see `docs/API.md`.
- ❌ **Not a plan** — see `docs/ROADMAP.md`.

ADRs are specifically about **decisions** — the "why" behind the
"what".

---

## 3. When to Create an ADR?

### 3.1 Create an ADR when

- ✅ A **non-trivial architectural** decision is made.
- ✅ A **process decision** affects how contributions are made.
- ✅ A **security trade-off** is accepted.
- ✅ A **previous decision is reversed**.
- ✅ Two or more **alternatives** were seriously considered.
- ✅ The decision has **long-term consequences** (6+ months).

### 3.2 Do NOT create an ADR when

- ❌ The change is a **bug fix** (use commits).
- ❌ The change is a **small refactor** (use PR description).
- ❌ The change is **purely cosmetic** (use commit message).
- ❌ The decision is **easily reversible** within a sprint.
- ❌ The decision is already documented in an existing ADR.
- ❌ The change is a **runtime improvement** that does not alter
  the architecture (e.g. MEM-1 / MEM-2 / MEM-3 — see §3.3).

### 3.3 Examples from this project

| Decision | Type | ADR? |
|---|---|:---:|
| Two-branch model (`main` + `develop`) | Process | ✅ |
| Automated releases via `release.sh` | Process | ✅ |
| Auto-sync `main → develop` in `release.yml` | Process | ✅ |
| Unified PR template | Process | ✅ |
| Release-specific PR template | Process (reversal) | ✅ |
| Rename `hotfix.sh` → `release-patch.sh` | Process | ✅ |
| Custom iptables chains | Architecture | ✅ |
| `STATUS_FILE = User Intent` | Architecture | ✅ |
| `rebuildMu` mutex (RACE-1) | Architecture | ✅ |
| `runtime_info` dynamic ports (PORT-2) | Architecture | ✅ |
| Fix a typo in a variable name | Bug fix | ❌ |
| Change button color in `index.html` | Cosmetic | ❌ |
| **MEM-1 — Dynamic memory limit per profile (v1.1.0)** | **Runtime improvement** | **❌** |
| **MEM-2 — Extended `shellQuote` charset (v1.1.0)** | **Runtime improvement** | **❌** |
| **MEM-3 — `MONITORING_UI_PORT` constant (v1.1.0)** | **Runtime improvement** | **❌** |
| **`offline.html` CSP fix (v1.1.0)** | **Bug fix** | **❌** |

**Why MEM-1/2/3 do not need ADRs**:

- They do **not** change the project's architecture (still Go
  runtime + `debug.SetMemoryLimit` + shell scripts).
- They tune **values** (per-profile MB) and **constants**
  (`MONITORING_UI_PORT`), not structure.
- Their rationale is fully captured in `docs/SECURITY.md` §5.30
  and `CHANGELOG.md` §[v1.1.0].

**When would a memory-related change need an ADR?** If we ever:

- Replace `debug.SetMemoryLimit` with a **custom memory manager**.
- Introduce **hard** memory limits (e.g. cgroups on Android).
- Move memory budgeting to a **separate service or helper**.

Those would qualify as architectural decisions.

### 3.4 Quick Decision Flow

```text
Is it a bug fix?  ──yes──▶ Commits only
       │
       no
       ▼
Is it cosmetic?  ──yes──▶ Commit message only
       │
       no
       ▼
Is it a runtime improvement?  ──yes──▶ SECURITY.md + CHANGELOG.md
       │
       no
       ▼
Is it a small refactor?  ──yes──▶ PR description
       │
       no
       ▼
   ✅ ADR
```

---

## 4. ADR Lifecycle

### 4.1 States

```text
┌───────────┐    ┌───────────┐    ┌─────────────┐
│ PROPOSED    │──▶│ ACCEPTED    │──▶│  DEPRECATED   │
└───────────┘    └───────────┘    └─────────────┘
                      │
                      │ (reversed by a new ADR)
                      ▼
                ┌─────────────┐
                │  SUPERSEDED   │
                │  by ADR-00XX  │
                └─────────────┘
```

| State | Meaning |
|---|---|
| **Proposed** | Under discussion; not yet binding. |
| **Accepted** | The decision is in effect. |
| **Deprecated** | Still in effect, but no longer recommended. |
| **Superseded by ADR-00XX** | Replaced by a newer ADR. |

### 4.2 Rules

1. **Never edit an Accepted ADR** — its content is historical.
2. **To reverse a decision**, create a **new ADR** that supersedes
   it.
3. **Update the superseded ADR** with a single line:
   `Status: Superseded by ADR-00XX`.
4. **Update this index** when the status changes.
5. **Never delete an ADR** — even rejected ones are kept as
   "Proposed" or "Rejected".

### 4.3 Immutability Example

If ADR-0004 decides "use a unified PR template" and later we decide
to create a release-specific template:

- ✅ Create `ADR-0005-release-specific-pr-template.md` with
  `Status: Accepted`.
- ✅ Edit `ADR-0004` to add:
  `**Status**: Superseded by [ADR-0005](0005-...)`.
- ❌ Do NOT rewrite ADR-0004's content.
- ❌ Do NOT delete ADR-0004.

This is exactly what happened in v1.0.0 (see §6.1).

---

## 5. File Naming & Location

### 5.1 Location

All ADRs live in:

```text
docs/adr/
```

### 5.2 Naming Convention

```text
NNNN-short-title-in-kebab-case.md
```

| Part | Rule |
|---|---|
| `NNNN` | 4-digit sequential number, zero-padded (`0001`, `0002`, ...). |
| `short-title` | Lowercase, kebab-case, descriptive. |
| `.md` | Markdown. |

### 5.3 Examples

```text
docs/adr/
├── README.md                                  ← this file
├── 0001-two-branch-model.md
├── 0002-automated-releases.md
├── 0003-post-release-sync.md
├── 0004-unified-pr-template.md
├── 0005-release-specific-pr-template.md
└── 0006-rename-hotfix-to-release-patch.md
```

### 5.4 Numbering Rules

- **Sequential** — never skip numbers.
- **Never reuse** — even if an ADR is rejected.
- **Never renumber** — order is the historical timeline.

---

## 6. ADR Index

### 6.1 Accepted

| # | Title | Status | Date |
|:-:|---|:---:|:---:|
| [0001](0001-two-branch-model.md) | Two-branch model (`main` + `develop`) | ✅ Accepted | 2026-09-24 |
| [0002](0002-automated-releases.md) | Automated releases via `scripts/release.sh` | ✅ Accepted | 2026-09-24 |
| [0003](0003-post-release-sync.md) | Auto-sync `main → develop` in `release.yml` | ✅ Accepted | 2026-09-24 |
| [0004](0004-unified-pr-template.md) | Unified PR template | ⚠️ Superseded | 2026-09-24 |
| [0005](0005-release-specific-pr-template.md) | Release-specific PR template | ✅ Accepted | 2026-09-24 |
| [0006](0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` | ✅ Accepted | 2026-09-24 |

### 6.2 Superseded / Deprecated

| # | Title | Superseded by |
|:-:|---|---|
| [0004](0004-unified-pr-template.md) | Unified PR template | [0005](0005-release-specific-pr-template.md) |

### 6.3 Proposed

*None currently.*

### 6.4 Rejected

*None currently.*

### 6.5 Index Statistics

| Category | Count |
|---|:---:|
| Total ADRs | **6** |
| Accepted (active) | **5** |
| Superseded | **1** |
| Proposed | 0 |
| Rejected | 0 |
| **Added in v1.0.0 cycle** | **6** |
| **Added in v1.1.0 cycle** | **0** |

**Note**: v1.1.0 did not add any new ADRs. The three runtime
improvements (MEM-1 / MEM-2 / MEM-3) are documented in
`docs/SECURITY.md` §5.30 but do **not** warrant ADRs (see §3.3).

### 6.6 ADRs by Release Cycle

```text
v1.0.0 cycle (2026-09-24):
  ├── ADR-0001  Two-branch model
  ├── ADR-0002  Automated releases
  ├── ADR-0003  Post-release sync
  ├── ADR-0004  Unified PR template           (superseded)
  ├── ADR-0005  Release-specific PR template  (supersedes 0004)
  └── ADR-0006  Rename hotfix.sh → release-patch.sh

v1.1.0 cycle (2026-09-26):
  └── (no new ADRs)

v1.2.0 cycle (planned):
  └── (to be determined — likely a memory-related ADR if the
       architecture changes; otherwise none)
```

---

## 7. Template

Copy this into a new file when creating an ADR:

```markdown
# ADR-NNNN: <Short Title>

**Status**: Proposed | Accepted | Deprecated | Superseded by [ADR-NNNN](NNNN-...)

**Date**: YYYY-MM-DD

**Authors**: @username

**Supersedes**: [ADR-NNNN](NNNN-...) (if applicable)

**Superseded by**: [ADR-NNNN](NNNN-...) (if applicable)

---

## Context

Describe the situation that led to this decision. What forces are at
play? What constraints exist? What problem are we solving?

Be specific. Avoid jargon. Assume the reader knows the project but
not the internal history.

## Decision

State the decision clearly in the active voice:

> "We will ..."

One paragraph. If the decision has multiple parts, use a numbered
list.

## Consequences

### Positive

- ✅ What becomes easier?
- ✅ What is now possible?
- ✅ What risk is mitigated?

### Negative

- ❌ What becomes harder?
- ❌ What trade-offs did we accept?
- ❌ What is now constrained?

### Neutral

- ⚪ What changes but is neither better nor worse?

## Alternatives Considered

| Alternative | Pros | Cons | Why rejected |
|---|---|---|---|
| Alternative A | ... | ... | ... |
| Alternative B | ... | ... | ... |
| **Chosen** | ✅ ... | ❌ ... | — |

## Related Decisions

- [ADR-NNNN](NNNN-...) — relationship (supersedes / superseded by / related).

## References

- Link to relevant PRs, Issues, discussions.
- Link to external documentation.
- Link to related project files.
```

---

## 8. Writing Guidelines

### 8.1 Style

| Rule | Example |
|---|---|
| **Use active voice** | "We will use X" (not "X will be used") |
| **Be specific** | "5-minute TTL" (not "short TTL") |
| **Quantify when possible** | "reduces I/O by ~100×" (not "much faster") |
| **Avoid jargon** | Explain acronyms on first use |
| **Use lists** | Prefer bullets over dense paragraphs |
| **Include links** | Reference files, PRs, external specs |
| **Keep it short** | 30-100 lines is ideal |

### 8.2 Content Checklist

Before submitting an ADR, verify:

- [ ] Title is **descriptive** (not "ADR for stuff").
- [ ] Context explains the **problem**, not the solution.
- [ ] Decision is written in **active voice**.
- [ ] Consequences list **positive, negative, neutral**.
- [ ] At least **two alternatives** were considered.
- [ ] Rejected alternatives have a **reason**.
- [ ] Status is **Proposed** (initially).
- [ ] Date is **ISO 8601** (`YYYY-MM-DD`).
- [ ] Related ADRs are **linked**.
- [ ] No broken **links** or **references**.

### 8.3 Anti-patterns

- ❌ **Retroactive justification** — writing an ADR after the fact
  to look thorough.
- ❌ **Hidden decisions** — changing behavior without an ADR.
- ❌ **Ambiguity** — "we might consider possibly" (make a decision!).
- ❌ **Too long** — 500-line ADRs are unread. Split into multiple
  ADRs.
- ❌ **Editing Accepted ADRs** — use a new superseding ADR instead.
- ❌ **ADR for a runtime improvement** — see §3.3.

---

## 9. Relationship with CHANGELOG

ADRs and `CHANGELOG.md` serve different purposes:

| Document | Purpose | Scope |
|---|---|---|
| **ADR** | **Why** a decision was made | Long-term |
| **CHANGELOG** | **What** changed for users | Per release |
| **ROADMAP** | **What** is planned | Future |
| **PR description** | **How** the change was implemented | One PR |

### 9.1 When a decision affects users

If an ADR changes user-visible behavior (e.g. a rename, a breaking
change), **both** documents must be updated:

1. **ADR** — the full rationale.
2. **CHANGELOG** — a one-line entry referencing the ADR.

Example in `CHANGELOG.md`:

```markdown
### Changed
- Renamed `scripts/hotfix.sh` → `scripts/release-patch.sh` ([ADR-0006](docs/adr/0006-rename-hotfix-to-release-patch.md))
```

### 9.2 When a decision is internal only

If an ADR affects only internal tooling (e.g. CI config refactor),
only the ADR is needed. The CHANGELOG may reference it as a
"Chore".

### 9.3 Runtime Improvements vs ADRs

Not every change that "feels important" needs an ADR. The v1.1.0
release is a good example:

| Change | ADR? | Where documented |
|---|:---:|---|
| **MEM-1** — Dynamic memory limit per profile | ❌ | `docs/SECURITY.md` §5.30.1 + `CHANGELOG.md` |
| **MEM-2** — Extended `shellQuote` charset | ❌ | `docs/SECURITY.md` §5.30.2 + `CHANGELOG.md` |
| **MEM-3** — `MONITORING_UI_PORT` in metrics handler | ❌ | `docs/SECURITY.md` §5.30.3 + `CHANGELOG.md` |
| **`offline.html` CSP fix** | ❌ | `CHANGELOG.md` §Fixed → Critical |

**Rule of thumb**:

- If the change **modifies** an existing decision's **value** →
  no ADR.
- If the change **alters** the decision's **structure** → new ADR.
- If the change **reverses** the decision → new superseding ADR.

**Why MEM-1 does not need an ADR**:

- The architecture is unchanged: Go runtime manages memory,
  `debug.SetMemoryLimit` sets the soft limit.
- MEM-1 modifies the **value** of that limit (from a fixed 80 MB
  to per-profile).
- The rationale is fully captured in `docs/SECURITY.md` §5.30.1.

**When it *would* need an ADR**:

- Replacing `debug.SetMemoryLimit` with a custom memory manager.
- Introducing hard limits via cgroups.
- Delegating memory budgeting to a separate helper.

Those would be architectural changes.

### 9.4 Summary Table

| Change type | ADR | SECURITY.md | CHANGELOG.md | ROADMAP.md |
|---|:---:|:---:|:---:|:---:|
| Architectural decision | ✅ | — | ✅ | — |
| Process decision | ✅ | — | ✅ | — |
| Runtime improvement | ❌ | ✅ | ✅ | — |
| Audit Correction | ❌ | ✅ | ✅ | — |
| Bug fix | ❌ | — | ✅ | — |
| New feature (planned) | — | — | — | ✅ |
| New feature (delivered) | — | — | ✅ | ✅ |

---

## 10. References

### 10.1 Project Files

| File | Purpose |
|---|---|
| [`../BRANCHING.md`](../BRANCHING.md) | Git branching strategy |
| [`../RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) | Release process |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | Contribution guide |
| [`../DEVELOPMENT.md`](../DEVELOPMENT.md) | Developer guide |
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | System architecture |
| [`../SECURITY.md`](../SECURITY.md) | Security policy |
| [`../ROADMAP.md`](../ROADMAP.md) | Future plans |
| [`../UPGRADE.md`](../UPGRADE.md) | Version upgrade guide |
| [`../../CHANGELOG.md`](../../CHANGELOG.md) | Version history (v1.0.0 + v1.1.0) |

### 10.2 External References

- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) (original article)
- [ADR GitHub Org](https://adr.github.io/) — collection of ADR tools
- [Kubernetes Enhancement Proposals (KEPs)](https://github.com/kubernetes/enhancements)
- [Rust RFCs](https://github.com/rust-lang/rfcs)
- [React RFCs](https://github.com/reactjs/rfcs)
- [ThoughtWorks — Lightweight ADRs](https://www.thoughtworks.com/radar/techniques/lightweight-architecture-decision-records)

### 10.3 v1.0.0 Cycle References

The six ADRs added in the v1.0.0 cycle:

| ADR | Introduced in | Rationale |
|:-:|---|---|
| 0001 | v1.0.0 | Two-branch model |
| 0002 | v1.0.0 | Automated releases |
| 0003 | v1.0.0 | Post-release sync |
| 0004 | v1.0.0 | Unified PR template (superseded) |
| 0005 | v1.0.0 | Release-specific PR template |
| 0006 | v1.0.0 | Rename hotfix.sh → release-patch.sh |

### 10.4 v1.1.0 Cycle References

**No new ADRs were added.** The v1.1.0 changes were:

- Runtime improvements (MEM-1/2/3) — see `docs/SECURITY.md` §5.30.
- Critical fix (`offline.html` CSP) — see `CHANGELOG.md`.
- Documentation updates — see `docs/UPGRADE.md` §3.0.

None of these warranted an ADR (see §3.3 and §9.3).

---

*Last updated: 2026-09-26*
*Version: v1.1.0*
*Author: gasciljh*