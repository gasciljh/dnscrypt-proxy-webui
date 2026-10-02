# Architecture Decision Records (ADRs) — DNSCrypt Smart Filter

> A curated log of the architectural and process decisions that
> shape the project.

**Version**: v1.3.0
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • `Last updated` reflects the v1.2.0 release date.
>   • §3.3 (Examples from this project) extended with the
>     v1.2.0 data-preservation additions (BAK-1 / BAK-2 / BAK-3 /
>     BAK-4, FIX-1 / FIX-2, WD-TOKEN) as examples of contributions
>     that do **not** need an ADR.
>   • §6.5 (Index Statistics) annotated with the v1.2.0 release
>     cycle.
>   • §6.6 (ADRs by Release Cycle) extended with the v1.2.0 cycle
>     (no new ADRs — data-preservation release).
>   • §9.3 (Runtime Improvements vs ADRs) extended with the
>     v1.2.0 additions and correctness fixes.
>   • §9.4 (Summary Table) extended with a new row for
>     **Correctness Fix**.
>   • §10.4 (v1.1.0 Cycle References) renamed and extended — now
>     covers both the v1.1.0 and v1.2.0 cycles.
>   • **No new ADRs were added in v1.2.0.** The registry remains
>     at **6 ADRs** (5 accepted + 1 superseded). The v1.2.0
>     release is a data-preservation release, not a re-architecture.
>   • **Global edition note**: the WebUI ships with English as the
>     default language and an in-page toggle to switch to Arabic.
>     This is a client-side-only feature and does **not** warrant
>     an ADR — it does not change the API or the architecture.

> **v1.2.0 (Global Edition) — Corrections in this revision**:
>   • 🔧 **FIX-1 description** — §3.3 and §9.3 previously described
>     FIX-1 as a "recovery-mode reorder". The actual implementation
>     in `customize.sh` uses a **snapshot-and-reapply** strategy
>     (`§[8a]` + `§[9]` + `§[9b2]`). The descriptions have been
>     corrected to match the shipped code. See
>     `docs/ARCHITECTURE.md` §3.10 and `docs/SECURITY.md` §5.32.1
>     for the authoritative reference.
>   • 🔧 **Encoding correction** — fixed mojibake in section
>     markers, arrows, checkmarks, warnings, and box drawing
>     characters. All symbols now render as proper UTF-8.

> **📖 Related documents**:
> - Git workflow → [`../BRANCHING.md`](../BRANCHING.md)
> - Release process → [`../RELEASE_PROCESS.md`](../RELEASE_PROCESS.md)
> - Contribution guide → [`../CONTRIBUTING.md`](../CONTRIBUTING.md)
> - Architecture → [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
> - Version upgrade guide → [`../UPGRADE.md`](../UPGRADE.md)
> - Backup system reference → [`../BACKUP.md`](../BACKUP.md)
> - Emergency recovery → [`../EMERGENCY.md`](../EMERGENCY.md)

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
§3.3 for examples across v1.0.0, v1.1.0, and v1.2.0.

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

**v1.2.0 example**: The Data-Preservation Release introduced the
10 defensive layers, `backupMu`, the 7-field `runtime_info.backups`
object, and the watchdog token. Each of these is a
**data-preservation mechanism** — not an architectural change. The
rationale lives in `docs/BACKUP.md` and `docs/SECURITY.md` §5.31.
No new ADRs were needed.

### 2.2 What they are NOT

- ❌ **Not a tutorial** — see `docs/ARCHITECTURE.md`.
- ❌ **Not a changelog** — see `CHANGELOG.md`.
- ❌ **Not a spec** — see `docs/API.md`.
- ❌ **Not a plan** — see `docs/ROADMAP.md`.
- ❌ **Not a data-preservation reference** — see `docs/BACKUP.md`.

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
- ❌ The change is a **correctness fix** that closes a data-loss
  bug without changing the architecture (e.g. FIX-1 / FIX-2 —
  see §3.3).
- ❌ The change is a **defensive hardening** that adds new layers
  to an existing subsystem (e.g. BAK-1..BAK-4, WD-TOKEN —
  see §3.3).

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
| **BAK-1 — 7-field `runtime_info.backups` (v1.2.0)** | **Runtime addition** | **❌** |
| **BAK-2 — `createAutoBackup` + `backupMu` (v1.2.0)** | **Runtime addition** | **❌** |
| **BAK-3 — `cleanupOldTransactions()` (v1.2.0)** | **Runtime addition** | **❌** |
| **BAK-4 — `checkPendingNotifications()` (v1.2.0)** | **Runtime addition** | **❌** |
| **FIX-1 — Recovery-mode correctness via snapshot-and-reapply (v1.2.0)** | **Correctness fix** | **❌** |
| **FIX-2 — Service Worker update-banner (v1.2.0)** | **Correctness fix** | **❌** |
| **WD-TOKEN — Watchdog token (v1.2.0)** | **Defensive hardening** | **❌** |
| **Bilingual WebUI (EN + AR, v1.2.0)** | **Client-side feature** | **❌** |
| **10 defensive layers (v1.2.0)** | **Extends existing backup subsystem** | **❌** |

**Why MEM-1/2/3 do not need ADRs**:

- They do **not** change the project's architecture (still Go
  runtime + `debug.SetMemoryLimit` + shell scripts).
- They tune **values** (per-profile MB) and **constants**
  (`MONITORING_UI_PORT`), not structure.
- Their rationale is fully captured in `docs/SECURITY.md` §5.30
  and `CHANGELOG.md` §[v1.1.0].

**Why BAK-1..BAK-4 do not need ADRs**:

- They extend an **already-existing subsystem** (the backup layer
  was introduced in v1.0.0 with `BACKUP_TMP`; v1.2.0 replaces its
  mechanism, not its purpose).
- They tune **values** (rotation count, timeout duration) and
  **observability surfaces** (7 fields, log lines), not
  architecture.
- Their rationale is fully captured in `docs/SECURITY.md` §5.31,
  `docs/BACKUP.md` §1.3, and `docs/ARCHITECTURE.md` §4.10.

**Why FIX-1 and FIX-2 do not need ADRs**:

- They are **correctness fixes** — they close regressions, not
  introduce decisions.
- FIX-1 corrects the interaction between the recovery-mode restore
  step (`§[8a]`) and the ZIP extraction step (`§[9]`) using a
  **snapshot-and-reapply** strategy (`§[9b2]`). The extraction
  logic of `§[9]` is deliberately left untouched; the fix is
  purely additive.
- FIX-2 corrects the Service Worker update-banner flow.
- Their rationale is fully captured in `docs/SECURITY.md` §5.32
  and `docs/ARCHITECTURE.md` §3.10.

**Why WD-TOKEN does not need an ADR**:

- It **replaces** an implicit bypass with an explicit token — a
  defensive hardening of an existing endpoint.
- It does **not** change the architecture: the endpoint already
  existed, the authentication mechanism simply changed shape.
- Its rationale is fully captured in `docs/SECURITY.md` §5.33 and
  `docs/ARCHITECTURE.md` §4.5.1.

**Why the Bilingual WebUI does not need an ADR**:

- It is a **client-side feature** — no server state, no API
  change, no architectural impact.
- The preference lives in `localStorage['dnscrypt-lang']`.
- Its rationale is fully captured in `docs/ARCHITECTURE.md` §6.7
  and `docs/API.md` §10.8.

**When would a memory-related change need an ADR?** If we ever:

- Replace `debug.SetMemoryLimit` with a **custom memory manager**.
- Introduce **hard** memory limits (e.g. cgroups on Android).
- Move memory budgeting to a **separate service or helper**.

Those would qualify as architectural decisions.

**When would a backup-related change need an ADR?** If we ever:

- Replace the filesystem-based backup with a **remote storage
  backend** (e.g. WebDAV, S3).
- Introduce a **database** for snapshot metadata.
- Move the backup layer to a **separate daemon**.

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
Is it a runtime improvement / addition?  ──yes──▶ SECURITY.md + CHANGELOG.md
       │
       no
       ▼
Is it a correctness fix?  ──yes──▶ SECURITY.md + CHANGELOG.md
       │
       no
       ▼
Is it a defensive hardening of an existing subsystem?  ──yes──▶ SECURITY.md + CHANGELOG.md
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
┌──────────┐    ┌──────────┐    ┌──────────────┐
│ PROPOSED │───▶│ ACCEPTED │───▶│  DEPRECATED  │
└──────────┘    └──────────┘    └──────────────┘
                      │
                      │ (reversed by a new ADR)
                      ▼
                ┌──────────────┐
                │  SUPERSEDED  │
                │  by ADR-00XX │
                └──────────────┘
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
| **Added in v1.2.0 cycle** | **0** |

**Note**: v1.1.0 did not add any new ADRs. The three runtime
improvements (MEM-1 / MEM-2 / MEM-3) are documented in
`docs/SECURITY.md` §5.30 but do **not** warrant ADRs (see §3.3).

**Note**: v1.2.0 did not add any new ADRs either. The
data-preservation additions (BAK-1..BAK-4), correctness fixes
(FIX-1, FIX-2), watchdog token (WD-TOKEN), bilingual WebUI, and
the 10 defensive layers are documented in `docs/SECURITY.md`
§5.31–§5.33, `docs/BACKUP.md`, and `docs/ARCHITECTURE.md` §3.10 /
§4.10 — but do **not** warrant ADRs (see §3.3).

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
  └── (no new ADRs — polish release)

v1.2.0 cycle (2026-09-29):
  └── (no new ADRs — data-preservation release)

v1.3.0 cycle (planned):
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
- ❌ **ADR for a correctness fix** — see §3.3.
- ❌ **ADR for a defensive hardening** — see §3.3.

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
and v1.2.0 releases are good examples:

**v1.1.0 cycle**:

| Change | ADR? | Where documented |
|---|:---:|---|
| **MEM-1** — Dynamic memory limit per profile | ❌ | `docs/SECURITY.md` §5.30.1 + `CHANGELOG.md` |
| **MEM-2** — Extended `shellQuote` charset | ❌ | `docs/SECURITY.md` §5.30.2 + `CHANGELOG.md` |
| **MEM-3** — `MONITORING_UI_PORT` in metrics handler | ❌ | `docs/SECURITY.md` §5.30.3 + `CHANGELOG.md` |
| **`offline.html` CSP fix** | ❌ | `CHANGELOG.md` §Fixed → Critical |

**v1.2.0 cycle**:

| Change | ADR? | Where documented |
|---|:---:|---|
| **BAK-1** — 7-field `runtime_info.backups` | ❌ | `docs/SECURITY.md` §5.31 + `docs/BACKUP.md` §8.1 + `CHANGELOG.md` |
| **BAK-2** — `createAutoBackup` + `backupMu` | ❌ | `docs/SECURITY.md` §5.31.3 + `docs/BACKUP.md` §4.3 + `CHANGELOG.md` |
| **BAK-3** — `cleanupOldTransactions()` | ❌ | `docs/SECURITY.md` §5.31 + `docs/BACKUP.md` §5.6 + `CHANGELOG.md` |
| **BAK-4** — `checkPendingNotifications()` | ❌ | `docs/SECURITY.md` §5.31 + `docs/BACKUP.md` §5.5 + `CHANGELOG.md` |
| **FIX-1** — Recovery-mode correctness via snapshot-and-reapply | ❌ | `docs/SECURITY.md` §5.32 + `docs/ARCHITECTURE.md` §3.10 + `CHANGELOG.md` |
| **FIX-2** — Service Worker update-banner | ❌ | `docs/SECURITY.md` §5.32 + `docs/ARCHITECTURE.md` §6.5 + `CHANGELOG.md` |
| **WD-TOKEN** — Watchdog token | ❌ | `docs/SECURITY.md` §5.33 + `docs/ARCHITECTURE.md` §4.5.1 + `CHANGELOG.md` |
| **Bilingual WebUI** (EN + AR) | ❌ | `docs/ARCHITECTURE.md` §6.7 + `docs/API.md` §10.8 + `CHANGELOG.md` |
| **10 defensive layers** | ❌ | `docs/BACKUP.md` §1.3 + `docs/ARCHITECTURE.md` §3.10 + `CHANGELOG.md` |

**Rule of thumb**:

- If the change **modifies** an existing decision's **value** →
  no ADR.
- If the change **alters** the decision's **structure** → new ADR.
- If the change **reverses** the decision → new superseding ADR.
- If the change **extends** an existing subsystem without altering
  its boundaries → no ADR.

**Why MEM-1 does not need an ADR**:

- The architecture is unchanged: Go runtime manages memory,
  `debug.SetMemoryLimit` sets the soft limit.
- MEM-1 modifies the **value** of that limit (from a fixed 80 MB
  to per-profile).
- The rationale is fully captured in `docs/SECURITY.md` §5.30.1.

**Why BAK-2 does not need an ADR**:

- The architecture is unchanged: the shell handles backups, Go
  triggers them.
- BAK-2 modifies **when** backups trigger and **how** they are
  serialized (with `backupMu`).
- The rationale is fully captured in `docs/SECURITY.md` §5.31.3.

**Why WD-TOKEN does not need an ADR**:

- The endpoint already existed; the change replaces an implicit
  localhost bypass with an explicit token.
- The architecture is unchanged: single-binary Go server with
  file-backed secrets.
- The rationale is fully captured in `docs/SECURITY.md` §5.33.

**When it *would* need an ADR**:

- Replacing `debug.SetMemoryLimit` with a custom memory manager.
- Introducing hard limits via cgroups.
- Delegating memory budgeting to a separate helper.
- Replacing the filesystem-based backup with a remote storage
  backend.
- Moving the backup layer to a separate daemon.

Those would be architectural changes.

### 9.4 Summary Table

| Change type | ADR | SECURITY.md | CHANGELOG.md | ROADMAP.md | BACKUP.md |
|---|:---:|:---:|:---:|:---:|:---:|
| Architectural decision | ✅ | — | ✅ | — | — |
| Process decision | ✅ | — | ✅ | — | — |
| Runtime improvement | ❌ | ✅ | ✅ | — | — |
| **Correctness fix** | ❌ | ✅ | ✅ | — | — |
| **Defensive hardening** | ❌ | ✅ | ✅ | — | — |
| **Data-preservation addition** | ❌ | ✅ | ✅ | — | ✅ |
| Audit Correction | ❌ | ✅ | ✅ | — | — |
| Bug fix | ❌ | — | ✅ | — | — |
| New feature (planned) | — | — | — | ✅ | — |
| New feature (delivered) | — | — | ✅ | ✅ | — |

**Legend**:

- **Runtime improvement** — tunes an existing value (e.g. MEM-1).
- **Correctness fix** — closes a regression (e.g. FIX-1, FIX-2).
- **Defensive hardening** — replaces an implicit mechanism with an
  explicit one (e.g. WD-TOKEN).
- **Data-preservation addition** — extends an existing subsystem
  (e.g. BAK-1..BAK-4, 10 defensive layers).

---

## 10. References

### 10.1 Project Files

| File | Purpose |
|---|---|
| [`../BRANCHING.md`](../BRANCHING.md) | Git branching strategy |
| [`../RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) | Release process |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | Contribution guide |
| [`../DEVELOPMENT.md`](../DEVELOPMENT.md) | Developer guide |
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | System architecture (§3.10, §4.10) |
| [`../SECURITY.md`](../SECURITY.md) | Security policy (§5.31, §5.32, §5.33) |
| [`../ROADMAP.md`](../ROADMAP.md) | Future plans |
| [`../UPGRADE.md`](../UPGRADE.md) | Version upgrade guide |
| [`../BACKUP.md`](../BACKUP.md) | **Backup system reference (v1.2.0)** |
| [`../EMERGENCY.md`](../EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [`../API.md`](../API.md) | HTTP API reference (§6.1.7) |
| [`../../CHANGELOG.md`](../../CHANGELOG.md) | Version history (v1.0.0 → v1.2.0) |

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

### 10.4 v1.1.0 and v1.2.0 Cycle References

**No new ADRs were added in either cycle.**

**v1.1.0 cycle (2026-09-26)** — Polish release:

- Runtime improvements (MEM-1/2/3) — see `docs/SECURITY.md` §5.30.
- Critical fix (`offline.html` CSP) — see `CHANGELOG.md`.
- Documentation updates — see `docs/UPGRADE.md` §3.0.

None of these warranted an ADR (see §3.3 and §9.3).

**v1.2.0 cycle (2026-09-29)** — Data-Preservation Release:

- Data-preservation additions (BAK-1..BAK-4) — see
  `docs/SECURITY.md` §5.31 and `docs/BACKUP.md`.
- Correctness fixes (FIX-1, FIX-2) — see `docs/SECURITY.md` §5.32.
- Watchdog token (WD-TOKEN) — see `docs/SECURITY.md` §5.33.
- Bilingual WebUI (EN + AR) — see `docs/ARCHITECTURE.md` §6.7.
- 10 defensive layers — see `docs/BACKUP.md` §1.3.
- 42-scenario CI matrix (`upgrade-test.yml`) — see
  `docs/CONTRIBUTING.md` §8.10.

None of these warranted an ADR (see §3.3 and §9.3).

**Why**: A data-preservation release that hardens an existing
subsystem (backup) and tunes existing mechanisms (correctness
fixes, defensive hardening) is **not** an architectural change.
Its rationale belongs in the data-preservation reference
(`docs/BACKUP.md`) and the security registry
(`docs/SECURITY.md`), not the ADR log.

The next ADR (likely #0007) would be expected in **v1.3.x** if a
proposed change alters the architecture (e.g. a new remote storage
backend, or a switch to cgroups-based memory limits).

---

*Last updated: 2026-10-02*
*Version: v1.3.0*
*Author: gasciljh*