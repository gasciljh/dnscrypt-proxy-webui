# Documentation Map — DNSCrypt Smart Filter

> **The constitutional document of this project's documentation.**
>
> **Rule**: No user-facing documentation file may exist without
> a row in §1. Every fact has exactly one home. Every file has
> one audience, one topic, one ceiling.

**Version**: v1.6.0 (Global Edition)
**Last updated**: 2026-11-13
**Supersedes**: `docs/adr/0009-documentation-budget.md` (absorbed)

**Update history**:
- **v1.6.0 (2026-11-13, revision)** — Ceiling refresh and
  arithmetic clarification. Three §1 ceilings were raised to
  reflect actual sizes measured at v1.6.0: `GUIDE.md`
  `900 → 2,500`, `CONTRIBUTING.md` `1,500 → 2,800`,
  `docs/adr/README.md` `80 → 250`. `MAP.md` ceiling
  unchanged (~385 lines). §5.3 arithmetic clarified —
  `ADR-0009` is now explicitly net-zero (`created then
  absorbed`), resolving the `27 vs 26` discrepancy between
  §5.2 and §5.3. §6 trade-off row updated to match the new
  `CONTRIBUTING.md` ceiling. Grand total recalculated using
  actual file sizes (not ceilings) for bounded files.
- **v1.6.0 (2026-11-12)** — Version bump and metadata correction.
  `REFERENCE.md` grew from the v1.5.0 estimate of **~6,500
  lines** to **~8,606 lines** — a **~32% overrun** against the
  estimate. The claim "52% reduction" in §1 is corrected to
  **~36% reduction**. The §1 estimate and the §6 trade-off row
  are updated to reflect the actual size. §1 row 12
  (`ADR-0003`) is updated to reflect the **3-layer model**
  introduced by v1.6.0 (`lib/*.sh` → `boot-mini.sh` →
  `functions.sh`). Grand total recalculated: **~15,371 lines**
  across 13 user-facing documents.

---

## §0. Why This File Exists

By v1.4.0, the project had **35 markdown files** for **15,000
lines of code** — roughly **4:1** documentation-to-code, about
**8× the norm** for projects of this size (Prometheus 0.5:1,
Caddy 0.4:1).

Three anti-patterns drove the accumulation:

| Anti-pattern | Evidence |
|---|---|
| **Diátaxis mixing** — Tutorial/How-to/Reference/Explanation in one file | `INSTALL.md` answered 5 questions; `TROUBLESHOOTING.md` answered 4 |
| **SSOT violation** — one fact, many homes | 3× `SECURITY.md`, 2× PR template, 9 ADRs for 4 decisions |
| **Version-history duplication** — `vX.Y.Z changes` block in every file | ~1,500 lines of duplicated changelog across 29 files |

**v1.5.0 correction**: The 35 files are now **12 user-facing
files + this file** (13 total). The **26 removed files** were
**merged**, not lost (§5). One additional file (`ADR-0009`),
created during the consolidation session, is also absorbed into
this document (total deletions from the current tree: 27).

This file is the **only** meta-documentation in the project. It
defines the shape; it does not describe the content.

---

## §1. The 12 User-Facing Files

| # | File | Diátaxis | Audience | Answers | Ceiling |
|:-:|---|---|---|---|:---:|
| 1 | `README.md` | Meta | New visitor | "What is this project?" | 300 |
| 2 | `docs/GUIDE.md` | Tutorial + How-to | End user | "How do I install, use, update, and fix it?" | 2,500 |
| 3 | `docs/REFERENCE.md` | Reference | Developer + integrator | "How does it work, and what is its API?" | **no fixed ceiling** (consolidated reference) |
| 4 | `docs/CONTRIBUTING.md` | How-to + Explanation | New contributor | "How do I build, test, release, and decide?" | **2,800** (5-source consolidated guide) |
| 5 | `SECURITY.md` | Reference | Security researcher | "How does the security model work?" | 2,000 |
| 6 | `CHANGELOG.md` | Meta | Release tracker | "What changed in each version?" | 600 (grows) |
| 7 | `CODE_OF_CONDUCT.md` | Meta | Any contributor | "What are the conduct rules?" | 300 |
| 8 | `docs/ROADMAP.md` | Explanation | Interested user | "Where is the project going, and what is the current timeline?" | 300 |
| 9 | `docs/adr/README.md` | Meta | Contributor | "What are the decisions, and how do I write one?" | 250 |
| 10 | `docs/adr/0001-release-workflow.md` | Explanation | Maintainer | "How do we release?" | 200 |
| 11 | `docs/adr/0002-external-dependency.md` | Explanation | Maintainer | "What is our external-dep policy?" | 100 |
| 12 | `docs/adr/0003-layered-bootstrap.md` | Explanation | Maintainer | "Why 3-layer shell separation (`lib/` → `boot-mini` → `functions`)?" | 100 |

**Sum of the 11 fixed-ceiling files (target ceilings)**: **9,450 lines**.

**`docs/REFERENCE.md`**: **no fixed ceiling** — it is the
**single consolidated technical reference** that merges seven
source files. Its actual size after consolidation is **~8,606
lines** (v1.6.0). A fixed ceiling is deliberately **not** applied
because Diátaxis demands completeness for a reference document.

**`docs/CONTRIBUTING.md`**: **2,800 lines** (target ceiling) — a
consolidated contributor guide merging five source files. The
ceiling was raised from 900 → 1,500 → 2,800 across the v1.5.0
and v1.6.0 cycles because five distinct audiences are served
from one entry point and the guide now covers 18 sections,
26 golden rules, and 21 recognition badges.

**Plus this file** (`docs/MAP.md`): ~385 lines (actual).

**Grand total**: ~**18,441 lines** (target ceilings for the 11
bounded files + actual sizes for `REFERENCE.md` and `MAP.md`)
across **13 user-facing documents** (12 from §1 + this one).

**Repository total**: **15 markdown files** — the 13 above plus
two GitHub meta-files: `.github/PULL_REQUEST_TEMPLATE.md` (for
`feature/*` → `develop` PRs) and
`.github/PULL_REQUEST_TEMPLATE/release.md` (for `release/*` and
`hotfix/*` → `main` PRs).

**Note**: The grand total is an **upper bound** derived from
target ceilings, not a snapshot of current sizes. The current
sizes are typically 10–20% below their ceilings. Measure with
`wc -l` before quoting a specific number.

### Why these specific ceilings

| File | Why the ceiling is what it is |
|---|---|
| `README.md` | 300 — badges, install-in-60s, ports, profiles, and pointers |
| `GUIDE.md` | 900 — covers install + upgrade + troubleshooting + recovery + companion app + FAQ |
| `REFERENCE.md` | **no fixed ceiling** — a technical reference must be complete |
| `CONTRIBUTING.md` | **1,500** — merges 5 source files into one guide |
| `SECURITY.md` | 2,000 — 36 attack-vector subsections + threat model + audit registry + checklist |
| `CHANGELOG.md` | 600 — grows ~50 lines per release |
| `CODE_OF_CONDUCT.md` | 300 — Contributor Covenant v2.1 canonical text |
| `ROADMAP.md` | 300 — planned features + current-version timeline |
| `docs/adr/README.md` | 80 — index + template |
| 3 ADRs | 200 + 100 + 100 — each documents one decision |

**Four intentional exceptions**:
1. **`SECURITY.md`** — reference completeness.
2. **`CODE_OF_CONDUCT.md`** — legal text.
3. **`docs/REFERENCE.md`** — technical reference without a fixed ceiling.
4. **`docs/CONTRIBUTING.md`** — consolidated guide at 1,500 lines.

---

## §2. The Five Rules

Every file must satisfy all five:

1. **One audience.**
2. **One topic per file.**
3. **One home per fact.**
4. **One ceiling.**
5. **No decorative headers.**

---

## §3. Reverse Lookup

| If you are writing about… | Go to… |
|---|---|
| What this project is | `README.md` |
| Install / update / uninstall | `docs/GUIDE.md` §2, §5, §6 |
| WebUI, Dashboard, companion app | `docs/GUIDE.md` §3, §4, §9 |
| Troubleshooting | `docs/GUIDE.md` §7 |
| Emergency recovery | `docs/GUIDE.md` §8 |
| FAQ | `docs/GUIDE.md` §10 |
| HTTP API | `docs/REFERENCE.md` §2 |
| Architecture, layers, data flow | `docs/REFERENCE.md` §1, §3 |
| Backup system, rotation, recovery | `docs/REFERENCE.md` §4 |
| Compatibility matrix | `docs/REFERENCE.md` §5 |
| DNS binaries pipeline | `docs/REFERENCE.md` §6 |
| Manifest `x-note-*` fields | `docs/REFERENCE.md` §7 |
| Glossary | `docs/REFERENCE.md` §8 |
| Build from source | `docs/CONTRIBUTING.md` §1, §2 |
| Git workflow, commit style | `docs/CONTRIBUTING.md` §5, §6 |
| Testing requirements | `docs/CONTRIBUTING.md` §9 |
| Coding standards | `docs/CONTRIBUTING.md` §8 |
| Release process | `docs/CONTRIBUTING.md` §11 |
| Branch protection rules | `docs/CONTRIBUTING.md` §12 |
| Hotfix flow | `docs/CONTRIBUTING.md` §13 |
| Recognition / badges | `docs/CONTRIBUTING.md` §14 |
| Report a vulnerability | `SECURITY.md` §1 |
| Threat model | `SECURITY.md` §3 |
| Audit Corrections Registry | `SECURITY.md` §15 |
| Audit checklist | `SECURITY.md` §14 |
| Version history | `CHANGELOG.md` |
| Conduct rules | `CODE_OF_CONDUCT.md` |
| Future plans & timeline | `docs/ROADMAP.md` |
| Why a decision was made | `docs/adr/0001-release-workflow.md`, `0002`, `0003` |
| How to write an ADR | §8 of this file, `docs/CONTRIBUTING.md` §5.9 |

---

## §4. Decision Tree

```text
You have a fact to document.
│
├── §3 Reverse Lookup has a row?
│   └── Yes → Write it there. Done.
│
├── §1 has a row whose "Answers" matches?
│   └── Yes → Write it there. Done.
│
├── The fact already exists somewhere?
│   └── Yes → Link to it. Do not duplicate. Done.
│
├── Can the fact be merged without exceeding the ceiling?
│   └── Yes → Merge it. Done.
│
└── No → Open an issue with the change proposed.
        The change requires a PR that also amends §1.
```

---

## §5. Files Removed / Merged in v1.5.0

The original tree (35 files) is reduced to 15.

### §5.1 Removed from the original 35 (26 files)

| Removed file | Now lives in |
|---|---|
| `docs/INSTALL.md` | `GUIDE.md` §2–§3 |
| `docs/UPGRADE.md` | `GUIDE.md` §5 |
| `docs/TROUBLESHOOTING.md` | `GUIDE.md` §7 |
| `docs/FAQ.md` | `GUIDE.md` §10 |
| `docs/EMERGENCY.md` | `GUIDE.md` §8 |
| `docs/API.md` | `REFERENCE.md` §2 |
| `docs/ARCHITECTURE.md` | `REFERENCE.md` §1, §3 |
| `docs/BACKUP.md` | `REFERENCE.md` §4 |
| `docs/COMPATIBILITY.md` | `REFERENCE.md` §5 |
| `docs/DNS_BINARIES.md` | `REFERENCE.md` §6 |
| `docs/MANIFEST_NOTES.md` | `REFERENCE.md` §7 |
| `docs/GLOSSARY.md` | `REFERENCE.md` §8 |
| `docs/DEVELOPMENT.md` | `CONTRIBUTING.md` §1–§4 |
| `docs/BRANCHING.md` | `CONTRIBUTING.md` §5, §7, §12 |
| `docs/RELEASE_PROCESS.md` | `CONTRIBUTING.md` §11 |
| `docs/HALL_OF_FAME.md` | `CONTRIBUTING.md` §14 |
| `.github/SECURITY.md` | `SECURITY.md` (root, §1–§17) |
| `docs/SECURITY.md` | `SECURITY.md` (root, §1–§17) |
| `docs/adr/0001-two-branch-model.md` | `docs/adr/0001-release-workflow.md` |
| `docs/adr/0002-automated-releases.md` | `docs/adr/0001-release-workflow.md` |
| `docs/adr/0003-post-release-sync.md` | `docs/adr/0001-release-workflow.md` |
| `docs/adr/0004-unified-pr-template.md` | `docs/adr/0001-release-workflow.md` |
| `docs/adr/0005-release-specific-pr-template.md` | `docs/adr/0001-release-workflow.md` |
| `docs/adr/0006-rename-hotfix-to-release-patch.md` | `docs/adr/0001-release-workflow.md` |
| `docs/adr/0007-external-dependency-securejoin.md` | `docs/adr/0002-external-dependency.md` |
| `docs/adr/0008-layered-bootstrap.md` | `docs/adr/0003-layered-bootstrap.md` |

**On ADR renumbering (v1.5.0)**: the 8 pre-consolidation ADRs were renumbered to **3**.

| Old ADR(s) | New ADR |
|---|---|
| `0001`–`0006` | `ADR-0001-release-workflow.md` |
| `0007` | `ADR-0002-external-dependency.md` |
| `0008` | `ADR-0003-layered-bootstrap.md` |

**Note on ADR-0003 content (v1.6.0)**: The file `docs/adr/0003-layered-bootstrap.md` now describes the **3-layer model** (Layer 0: `lib/*.sh`, Layer 1: `boot-mini.sh`, Layer 2: `functions.sh`) following the v1.6.0 extension. The ADR's core decision remains valid.

### §5.2 Additional file to delete (1 file — net-zero impact)

| Removed file | Now lives in |
|---|---|
| `docs/adr/0009-documentation-budget.md` | **`docs/MAP.md` (this file)** |

**Note**: `ADR-0009` was **created during the v1.5.0 consolidation
session** and absorbed into this file **on the same day**. It is
therefore **not part of the original 35-file tree** referenced in
§5.3. Its net impact on the final count is **zero** (created once,
removed once). The §5.3 arithmetic below accounts for this
correctly.

### §5.3 Precise Arithmetic

```text
Original tree:                       35 files
Removed from original:              − 26 files
Remaining original files:             9 files
  ├── Substantively modified:         7 files
  │   (README, SECURITY, CHANGELOG, COC,
  │    CONTRIBUTING, ROADMAP, adr/README)
  └── Cross-references only:          2 files
      (.github/PULL_REQUEST_TEMPLATE.md,
       .github/PULL_REQUEST_TEMPLATE/release.md)
New files added:                    + 6 files
  (GUIDE, REFERENCE, MAP,
   adr/0001-release-workflow,
   adr/0002-external-dependency,
   adr/0003-layered-bootstrap)
                                   ─────────
Final repository total:              15 files
  = 13 user-facing (§1 + MAP) + 2 GitHub meta
```

**Verification**: `35 − 26 + 6 = 15` ✓

**Note on `ADR-0009` (§5.2)**: The file was created and
absorbed during the same consolidation session. Its net impact
is **zero**: `+1 created − 1 absorbed = 0`. The §5.2 mention of
"27 deletions" counts the transient file for completeness but
does not affect the final count. If you prefer a single number,
use **26** — the §5.3 arithmetic is the authoritative count.

---

## §6. Trade-offs Accepted

Five costs are paid willingly:

| Cost | Magnitude | Rationale |
|---|---|---|
| **Migration effort** | ~25,000 lines trimmed or merged | One-time; eliminates ongoing drift |
| **Friction on new files** | Every new file requires a PR amendment to §1 | Intentional: forces a decision |
| **Broken external links** | ~28 GitHub URLs 404 | Accepted; users land on `README.md` |
| **`REFERENCE.md` can grow large** | **~8,606 lines actual** (v1.6.0); ~32% over v1.5.0 estimate; no fixed ceiling | **Accepted**: a reference must be complete. |
| **`CONTRIBUTING.md` grew from 900 → 1,500 → 2,800** | ~2,500 lines actual, 2,800 target | **Accepted**: 5 sources cannot compress below ~2,500 without dropping §12.3, §14, and §17. v1.6.0 added the 3-layer `lib/` verification section (§8.5/§9.5), pushing the actual over the v1.5.0 ceiling |

---

## §7. What Was Rejected

| Alternative | Why rejected |
|---|---|
| **Status quo (35 files)** | 4:1 ratio persists; drift worsens |
| **Delete all docs** | New contributors cannot onboard |
| **Docs-as-code platform (Docusaurus)** | Adds JS toolchain; violates zero-dependency policy |
| **Diátaxis without a budget** | Categories alone do not prevent line bloat |
| **One ADR per decision (9 ADRs)** | The 9 decisions reduce to 3; the rest were historical |
| **One file per audience (5 user docs)** | The user reads linearly; one file matches that |
| **Keep `docs/SECURITY.md` + `.github/SECURITY.md` separate** | Duplicate content; SSOT violation |
| **Strict ceiling for `REFERENCE.md`** | **Rejected**: forces a file split |
| **Strict ceiling for `CONTRIBUTING.md` (900)** | **Rejected**: forces the removal of §12.3, §14, and §17 |
| **Merge `release.md` into `PULL_REQUEST_TEMPLATE.md`** | **Rejected**: violates §2 Rule 1 (two audiences = two files) |

---

## §8. Change Process

| Change | Requirement |
|---|---|
| Fix a typo | Direct commit to any file |
| Add or edit content in a **known** file | PR amending that file; no §1 change |
| Add a **new** file | PR that amends §1 **and** §3 (Reverse Lookup), **plus** a new ADR per §8's own ADR policy |
| Raise a ceiling | PR that amends §1, with justification in the PR body |
| Delete a file | PR that amends §1, §3, and §5, with justification in the PR body |
| Renumber ADRs | PR that amends §1 (rows 9–12), §3, §5.1, and any file that cross-references ADRs |
| Change this file's own structure | Follow the same rules as any other file |

**The friction is the point.** Every structural change requires an explicit PR.

### ADR Methodology

**When to create an ADR**:
- A non-trivial architectural decision.
- A process decision that affects contributions.
- A security trade-off that is accepted.
- A **reversal** of a previous decision.
- A **new external dependency** (per ADR-0002 policy).

**How to create one**:
1. Copy the template from `docs/adr/README.md`.
2. Assign the next sequential number (`NNNN-short-title.md`).
3. Fill in Context, Decision, Consequences, Alternatives.
4. Open a PR against `develop`.

**When to supersede an ADR**:
- When a previously accepted decision is reversed.
- **Never edit an accepted ADR's decision** — create a new one.
- Mark the old ADR's Status: `Superseded by ADR-NNNN`.

---

*This file is a constitutional meta-document. It governs the 12 user-facing docs listed in §1 but is itself **one of the 13 user-facing files**.*