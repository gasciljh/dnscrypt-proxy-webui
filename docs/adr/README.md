# Architecture Decision Records (ADRs)

**Version**: v1.5.0 (Global Edition)
**Last updated**: 2026-10-19
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui

> An ADR is a short, immutable record of a significant architectural or
> process decision. Each ADR answers **what** was decided, **why**, and
> **what are the consequences**. ADRs are numbered sequentially, never
> edited after acceptance, and never deleted — reversals require a new
> ADR that supersedes the old one.
>
> **Full methodology** (when to create one, lifecycle, writing
> guidelines, merge and supersede rules): see `docs/CONTRIBUTING.md` §8
> and `docs/MAP.md` §8. **This file is an index**, not a methodology
> guide.

## Index

| # | Title | Status | Date |
|:-:|---|:---:|:---:|
| [0001](0001-release-workflow.md) | Release workflow (two-branch model, automation, sync, PR templates, naming) | ✅ Accepted | 2026-09-24 |
| [0002](0002-external-dependency.md) | External dependency — `filepath-securejoin` | ✅ Accepted | 2026-10-10 |
| [0003](0003-layered-bootstrap.md) | Layered Bootstrap (Layer 0 / Layer 1) | ✅ Accepted | 2026-10-15 |

**Status legend**: 💡 Proposed · ✅ Accepted · ⛔ Deprecated · ⚠️ Superseded

## Lifecycle & Rules

| Status | Meaning |
|---|---|
| 💡 Proposed | Under discussion; not yet binding. |
| ✅ Accepted | The decision is in effect. |
| ⛔ Deprecated | Still in effect, but no longer recommended. |
| ⚠️ Superseded | Replaced by a newer ADR. The old file remains as history. |

**Three absolute rules**:

1. **Never edit an Accepted ADR.** To reverse a decision, create a new
   ADR and update the old one's status to `Superseded by ADR-NNNN`.
2. **Never renumber.** The order is the historical timeline.
3. **Never delete.** Even rejected proposals stay in the repository as
   `Proposed` or `Rejected`.

## Format

Every ADR follows this structure (see any file in the index above for a
complete example):

1. **Status** + **Date** + **Consolidated** + **Authors** + **Supersedes** + **Superseded by**
2. **Context** — the forces at play, constraints, and problem statement.
3. **Decision** — what was decided, in active voice (*"We will..."*).
4. **Consequences** — Positive / Negative / Neutral.
5. **Alternatives Considered** — rejected options, with reasons.
6. **Related Decisions** — linked ADRs.
7. **References** — code paths, narrative docs, external sources.

**Filename**: `NNNN-short-title-in-kebab-case.md` (e.g. `0001-release-workflow.md`).

## Template

Copy this into a new `NNNN-title.md` file:

```markdown
# ADR-NNNN: Title

**Status**: 💡 Proposed
**Date**: YYYY-MM-DD
**Consolidated**: —
**Authors**: @username
**Supersedes**: —
**Superseded by**: —

## Context

Describe the forces at play, constraints, and the problem being solved.

## Decision

State the decision in active voice: *"We will..."*.

## Consequences

### Positive
### Negative
### Neutral

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| ... | ... |

## Related Decisions

- [ADR-NNNN](NNNN-...) — relationship.

## References

- Code: ...
- Narrative docs: ...
- External: ...
```

## References

- **Methodology**: `docs/CONTRIBUTING.md` §8 (contribution workflow),
  `docs/MAP.md` §8 (documentation map, ADR methodology).
- **Version history**: `CHANGELOG.md`.
- **External**: [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions),
  [ADR GitHub Org](https://adr.github.io/).

---

*Last updated: 2026-10-19*
*Version: v1.5.0 (Global Edition)*