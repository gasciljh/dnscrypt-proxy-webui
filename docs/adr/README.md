# Architecture Decision Records (ADRs) — DNSCrypt Smart Filter

> A curated log of the architectural and process decisions that shape the project.

**Version**: v1.0.0
**Last updated**: 2026-09-24
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **📖 Related documents**:
> - Git workflow → [`../BRANCHING.md`](../BRANCHING.md)
> - Release process → [`../RELEASE_PROCESS.md`](../RELEASE_PROCESS.md)
> - Contribution guide → [`../CONTRIBUTING.md`](../CONTRIBUTING.md)
> - Architecture → [`../ARCHITECTURE.md`](../ARCHITECTURE.md)

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

An **Architecture Decision Record (ADR)** is a short, immutable document
that captures a **significant decision** made during the project's lifetime.

Each ADR answers three questions:

| Question | Purpose |
|---|---|
| **What** was decided? | The decision itself. |
| **Why** was it decided? | The context and forces at play. |
| **What are the consequences?** | What becomes easier / harder as a result. |

ADRs are:

- **Lightweight** — one file per decision, 30-100 lines.
- **Immutable** — never edited after acceptance; reversed by a new ADR.
- **Numbered** — sequential, never reused.
- **Versioned** — committed to the repository alongside code.

The concept was popularized by Michael Nygard in 2011 and is used by
Kubernetes, Rust, React, and dozens of other major projects.

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

### 2.2 What they are NOT

- ❌ **Not a tutorial** — see `docs/ARCHITECTURE.md`.
- ❌ **Not a changelog** — see `CHANGELOG.md`.
- ❌ **Not a spec** — see `docs/API.md`.
- ❌ **Not a plan** — see `docs/ROADMAP.md`.

ADRs are specifically about **decisions** — the "why" behind the "what".

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

---

## 4. ADR Lifecycle

### 4.1 States

```text
┌───────────┐   ┌───────────┐   ┌───────────────┐
│ PROPOSED  │──▶│ ACCEPTED  │──▶│  DEPRECATED   │
└───────────┘   └───────────┘   └───────────────┘
                      │
                      │ (reversed by a new ADR)
                      ▼
                ┌───────────────┐
                │  SUPERSEDED   │
                │  by ADR-00XX  │
                └───────────────┘
```

| State | Meaning |
|---|---|
| **Proposed** | Under discussion; not yet binding. |
| **Accepted** | The decision is in effect. |
| **Deprecated** | Still in effect, but no longer recommended. |
| **Superseded by ADR-00XX** | Replaced by a newer ADR. |

### 4.2 Rules

1. **Never edit an Accepted ADR** — its content is historical.
2. **To reverse a decision**, create a **new ADR** that supersedes it.
3. **Update the superseded ADR** with a single line: `Status: Superseded by ADR-00XX`.
4. **Update this index** when the status changes.
5. **Never delete an ADR** — even rejected ones are kept as "Proposed" or "Rejected".

### 4.3 Immutability Example

If ADR-0004 decides "use a unified PR template" and later we decide to
create a release-specific template:

- ✅ Create `ADR-0005-release-specific-pr-template.md` with `Status: Accepted`.
- ✅ Edit `ADR-0004` to add: `**Status**: Superseded by [ADR-0005](0005-...)`.
- ❌ Do NOT rewrite ADR-0004's content.
- ❌ Do NOT delete ADR-0004.

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

Describe the situation that led to this decision. What forces are at play?
What constraints exist? What problem are we solving?

Be specific. Avoid jargon. Assume the reader knows the project but not
the internal history.

## Decision

State the decision clearly in the active voice:

> "We will ..."

One paragraph. If the decision has multiple parts, use a numbered list.

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

- ❌ **Retroactive justification** — writing an ADR after the fact to look thorough.
- ❌ **Hidden decisions** — changing behavior without an ADR.
- ❌ **Ambiguity** — "we might consider possibly" (make a decision!).
- ❌ **Too long** — 500-line ADRs are unread. Split into multiple ADRs.
- ❌ **Editing Accepted ADRs** — use a new superseding ADR instead.

---

## 9. Relationship with CHANGELOG

ADRs and `CHANGELOG.md` serve different purposes:

| Document | Purpose | Scope |
|---|---|---|
| **ADR** | **Why** a decision was made | Long-term |
| **CHANGELOG** | **What** changed for users | Per release |
| **ROADMAP** | **What** is planned | Future |
| **PR description** | **How** the change was implemented | One PR |

### When a decision affects users

If an ADR changes user-visible behavior (e.g. a rename, a breaking change),
**both** documents must be updated:

1. **ADR** — the full rationale.
2. **CHANGELOG** — a one-line entry referencing the ADR.

Example in `CHANGELOG.md`:

```markdown
### Changed
- Renamed `scripts/hotfix.sh` → `scripts/release-patch.sh` ([ADR-0006](docs/adr/0006-rename-hotfix-to-release-patch.md))
```

### When a decision is internal only

If an ADR affects only internal tooling (e.g. CI config refactor), only
the ADR is needed. The CHANGELOG may reference it as a "Chore".

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
| [`../../CHANGELOG.md`](../../CHANGELOG.md) | Version history |

### 10.2 External References

- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) (original article)
- [ADR GitHub Org](https://adr.github.io/) — collection of ADR tools
- [Kubernetes Enhancement Proposals (KEPs)](https://github.com/kubernetes/enhancements)
- [Rust RFCs](https://github.com/rust-lang/rfcs)
- [React RFCs](https://github.com/reactjs/rfcs)
- [ThoughtWorks — Lightweight ADRs](https://www.thoughtworks.com/radar/techniques/lightweight-architecture-decision-records)

---

*Last updated: 2026-09-24*
*Version: v1.0.0*
*Author: gasciljh*