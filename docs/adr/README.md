# Architecture Decision Records (ADRs)

**Version**: v1.6.0 (Global Edition)
**Last updated**: 2026-11-13
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui

> An ADR is a short, immutable record of a significant architectural or
> process decision. Each ADR answers **what** was decided, **why**, and
> **what are the consequences**. ADRs are numbered sequentially, their
> **decision record** is never edited after acceptance, and they are never
> deleted. **Metadata updates** (Status line, `Consolidated`, `Extended`,
> `Verified in`) and **clearly-marked Extension sections** are allowed —
> reversals require a new ADR.
>
> **Full methodology** (when to create one, lifecycle, writing
> guidelines, merge and supersede rules): see `docs/CONTRIBUTING.md` §5.9
> (ADR workflow) and `docs/MAP.md` §8 (Change Process). **This file is an
> index**, not a methodology guide.

## Index

| # | Title | Status | Date | Last change |
|:-:|---|:---:|:---:|---|
| [0001](0001-release-workflow.md) | Release workflow (two-branch model, automation, sync, PR templates, naming) | ✅ Accepted | 2026-09-24 | v1.6.0 — verified (7th cycle) |
| [0002](0002-external-dependency.md) | External dependency — `filepath-securejoin` | ✅ Accepted | 2026-10-10 | v1.6.0 — verified (still the only one) |
| [0003](0003-layered-bootstrap.md) | Layered Bootstrap | ✅ Accepted (extended) | 2026-10-15 | **v1.6.0 — 2-layer → 3-layer extension** |

**Status legend**: 💡 Proposed · ✅ Accepted · ✅ Accepted (extended) · ⛔ Deprecated · ⚠️ Superseded

## Lifecycle & Rules

| Status | Meaning |
|---|---|
| 💡 Proposed | Under discussion; not yet binding. |
| ✅ Accepted | The decision is in effect. |
| ✅ Accepted (extended) | The original decision is in effect, and has been refined by a later addition to the same file. The extension is clearly marked. No earlier decision was reversed. |
| ⛔ Deprecated | Still in effect, but no longer recommended. |
| ⚠️ Superseded | Replaced by a newer ADR. The old file remains as history. |

**Three absolute rules**:

1. **Never edit an Accepted ADR's *decision*.** To reverse a decision, create
   a new ADR and update the old one's status to `Superseded by ADR-NNNN`. To
   **extend** a decision without reversing it, append a clearly-marked
   `Extension (vX.Y.Z)` section and update the Status line to
   `✅ Accepted (extended in vX.Y.Z)`.
2. **Never renumber.** The order is the historical timeline.
3. **Never delete.** Even rejected proposals stay in the repository as
   `Proposed` or `Rejected`.

### Metadata vs decision

The following fields are **metadata** and may be updated in an Accepted ADR
without creating a new one. They record *state*, not *policy*:

| Field | Meaning |
|---|---|
| `Status` | Current lifecycle status. Changing from ✅ Accepted to ⛔ Deprecated or ⚠️ Superseded follows the rules above. Changing to `✅ Accepted (extended in vX.Y.Z)` requires an accompanying `Extension` section. |
| `Consolidated` | The date a set of pre-consolidation ADRs were merged into this file. Set once. |
| `Extended` | The date a later addition (with its own `Extension` section) was applied. Set at most once per extension. |
| `Verified in` | Records that a given release cycle **exercised** the decision without changing it. A "verified" ADR keeps its `✅ Accepted` status. This field is a marker of use, not a change of policy. |
| `Supersedes` / `Superseded by` | Pointer to a related ADR that replaces or is replaced by this one. Set as part of a supersession. |

The following field is **decision content** and must never be edited after
acceptance:

| Field | Meaning |
|---|---|
| `Context`, `Decision`, `Consequences`, `Alternatives Considered` | The recorded decision and its rationale. Changes require a new ADR. |

## Format

Every ADR follows this structure (see any file in the index above for a
complete example):

1. **Status** + **Date** + **Consolidated** + **Extended** + **Verified in** +
   **Authors** + **Supersedes** + **Superseded by**
2. **Context** — the forces at play, constraints, and problem statement.
3. **Decision** — what was decided, in active voice (*"We will..."*).
4. **Extension (vX.Y.Z)** — optional; only for ADRs whose decisions were
   refined without being reversed.
5. **Consequences** — Positive / Negative / Neutral.
6. **Alternatives Considered** — rejected options, with reasons.
7. **Related Decisions** — linked ADRs.
8. **References** — code paths, narrative docs, external sources.

**Filename**: `NNNN-short-title-in-kebab-case.md` (e.g. `0001-release-workflow.md`).

## Template

Copy this into a new `NNNN-title.md` file:

```markdown
# ADR-NNNN: Title

**Status**: 💡 Proposed
**Date**: YYYY-MM-DD
**Consolidated**: —
**Extended**: —
**Verified in**: —
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

## v1.6.0 extensions

**ADR-0003** (Layered Bootstrap) was extended in v1.6.0 from a 2-layer to
a 3-layer model:
- **v1.5.0**: Layer 0 (`boot-mini.sh`) + Layer 1 (`functions.sh`).
- **v1.6.0**: Layer 0 (`lib/*.sh` — 6 modules) + Layer 1 (`boot-mini.sh`
  aggregator) + Layer 2 (`functions.sh`).

The core v1.5.0 decision (separate bootstrap primitives from runtime
orchestrators) was **not reversed**. Only the "Layer 0" content was
reorganized from 1 file into 6 modules. See the `## Extension (v1.6.0)`
section in `0003-layered-bootstrap.md` for the full details.

**ADR-0001** and **ADR-0002** were **verified** in v1.6.0 — no changes
required. The seventh release cycle continued to use the two-branch model,
the automated release pipeline, the post-release sync, the split PR
templates, and the single external dependency (`filepath-securejoin v0.7.0`).

## References

- **Methodology**: `docs/CONTRIBUTING.md` §5.9 (ADR workflow),
  `docs/MAP.md` §8 (Change Process → ADR Methodology).
- **Version history**: `CHANGELOG.md` §[v1.0.0] through §[v1.6.0].
- **External**: [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions),
  [ADR GitHub Org](https://adr.github.io/).

---

*Last updated: 2026-11-13*
*Version: v1.6.0 (Global Edition)*