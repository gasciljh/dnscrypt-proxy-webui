# Documentation Map — DNSCrypt Smart Filter

> **The constitutional document of this project's documentation.**
>
> **Rule**: No user-facing documentation file may exist without
> a row in §1. Every fact has exactly one home. Every file has
> one audience, one topic, one ceiling.

**Version**: v1.5.0 (Global Edition)
**Last updated**: 2026-10-18
**Supersedes**: `docs/adr/0009-documentation-budget.md` (absorbed)

**Update history**:

- **v1.5.0 (2026-10-18, revision)** — `release.md` preserved as a
  separate file (Option A). Final count: **15 markdown files**
  (13 user-facing + 2 GitHub meta-files). §5.1 loses one deletion
  entry; §5.3 arithmetic updated; §7 records the rejected merge.
- **v1.5.0 (2026-10-18)** — CONTRIBUTING ceiling raised
  `900 → 1,500` and documented as the fourth intentional
  exception. `CONTRIBUTING.md` is now a **5-source merge**
  (original + `DEVELOPMENT.md` + `BRANCHING.md` +
  `RELEASE_PROCESS.md` + `HALL_OF_FAME.md`). The 8 pre-consolidation
  ADRs were renumbered to **3** in `CONTRIBUTING.md §17.4`.
- **v1.5.0 (2026-10-17)** — REFERENCE.md ceiling set to
  `no fixed ceiling` after the 7-source consolidation. This
  update also formalizes the "three intentional exceptions".

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
defines the shape; it does not describe the content. It is read
by contributors before they write, not by users seeking to use
the project.

---

## §1. The 12 User-Facing Files

| # | File | Diátaxis | Audience | Answers | Ceiling |
|:-:|---|---|---|---|:---:|
| 1 | `README.md` | Meta | New visitor | "What is this project?" | 300 |
| 2 | `docs/GUIDE.md` | Tutorial + How-to | End user | "How do I install, use, update, and fix it?" | 900 |
| 3 | `docs/REFERENCE.md` | Reference | Developer + integrator | "How does it work, and what is its API?" | **no fixed ceiling** (consolidated reference — see below) |
| 4 | `docs/CONTRIBUTING.md` | How-to + Explanation | New contributor | "How do I build, test, release, and decide?" | **1,500** (5-source consolidated guide — see below) |
| 5 | `SECURITY.md` | Reference | Security researcher | "How does the security model work?" | 2,000 |
| 6 | `CHANGELOG.md` | Meta | Release tracker | "What changed in each version?" | 600 (grows) |
| 7 | `CODE_OF_CONDUCT.md` | Meta | Any contributor | "What are the conduct rules?" | 300 |
| 8 | `docs/ROADMAP.md` | Explanation | Interested user | "Where is the project going?" | 300 |
| 9 | `docs/adr/README.md` | Meta | Contributor | "What are the decisions, and how do I write one?" | 80 |
| 10 | `docs/adr/0001-release-workflow.md` | Explanation | Maintainer | "How do we release?" | 200 |
| 11 | `docs/adr/0002-external-dependency.md` | Explanation | Maintainer | "What is our external-dep policy?" | 100 |
| 12 | `docs/adr/0003-layered-bootstrap.md` | Explanation | Maintainer | "Why Layer 0 / Layer 1?" | 100 |

**Sum of the 11 fixed-ceiling files**: **6,380 lines**.

**`docs/REFERENCE.md`**: **no fixed ceiling** — it is the
**single consolidated technical reference** that merges seven
source files (`ARCHITECTURE`, `API`, `BACKUP`, `COMPATIBILITY`,
`DNS_BINARIES`, `MANIFEST_NOTES`, `GLOSSARY`). Its expected size
is **~6,500 lines** after consolidation. A fixed ceiling is
deliberately **not** applied, because:

1. **Diátaxis demands completeness** for a reference document —
   trimming it would make it misleading.
2. **The seven sources total ~13,500 lines**. Compression to
   ~6,500 is already a 52% reduction.
3. **A fixed ceiling would force a split**, contradicting the
   "12 user-facing files" model that is the whole point of this
   consolidation.

**`docs/CONTRIBUTING.md`**: **1,500 lines** — it is the
**single consolidated contributor guide** that merges **five**
source files (`CONTRIBUTING`, `DEVELOPMENT`, `BRANCHING`,
`RELEASE_PROCESS`, `HALL_OF_FAME`). The ceiling was raised from
the original **900** to **1,500** in v1.5.0 because:

1. **Five distinct audiences** (new contributor, developer,
   releaser, release-manager, recognized contributor) are
   deliberately served from one entry point — splitting would
   reintroduce the navigation problem the consolidation exists
   to solve.
2. **The five sources total ~10,300 lines**. Compression to
   ~1,500 is already an **85% reduction**.
3. **Several blocks are irreplaceable**:
   - **§12.3** — the GitHub Rulesets bypass trap discovered
     during the v1.1.0 release cycle (PR #6).
   - **§14.1** — the full 18-badge recognition table.
   - **§17** — the v1.5.0-specific notes (install cascade,
     Layered Bootstrap, external dependency, ADR renumbering).

**Plus this file** (`docs/MAP.md`): 355 lines.

**Grand total**: ~**13,235 lines** across **13 user-facing
documents** (12 from §1 + this one).

**Repository total**: **15 markdown files** — the 13 above plus
two GitHub meta-files: `.github/PULL_REQUEST_TEMPLATE.md` (for
`feature/*` → `develop` PRs) and
`.github/PULL_REQUEST_TEMPLATE/release.md` (for `release/*` and
`hotfix/*` → `main` PRs). Both are GitHub meta-files, not
user-facing documentation, and are therefore not counted in this
map. Their existence, rationale, and reversal history are recorded
in `docs/adr/0001-release-workflow.md` §Decision → §4.

### Why these specific ceilings

The ceilings are not arbitrary. Each reflects the **minimum
content required to answer the file's question fully**:

| File | Why the ceiling is what it is |
|---|---|
| `README.md` | 300 — badges, install-in-60s, ports, profiles, and pointers; no API details |
| `GUIDE.md` | 900 — covers install + upgrade + troubleshooting + recovery + companion app + FAQ, without reference detail |
| `REFERENCE.md` | **no fixed ceiling** — a technical **reference** must be complete (Diátaxis). It merges 7 source files totaling ~13,500 lines; ~6,500 is already a 52% reduction. **Deliberate exception**: any fixed ceiling would force a file split |
| `CONTRIBUTING.md` | **1,500** — merges 5 source files (~10,300 lines) into one contributor-facing guide. 1,500 is the minimum required to preserve §12.3 (Ruleset bypass trap), §14 (18 badges), and §17 (v1.5.0-specific notes). **Deliberate exception** |
| `SECURITY.md` | 2,000 — 36 attack-vector subsections + threat model + audit registry + checklist. **Exception**: security is the project's primary value proposition |
| `CHANGELOG.md` | 600 — grows ~50 lines per release; the ceiling is the **current** size, not a hard cap |
| `CODE_OF_CONDUCT.md` | 300 — Contributor Covenant v2.1 canonical text is ~250 lines; **legal documents cannot be abbreviated** |
| `ROADMAP.md` | 300 — planned features only; no historical content |
| `docs/adr/README.md` | 80 — index + template; the methodology lives in `CONTRIBUTING.md §8` and `MAP.md §8` |
| 3 ADRs | 200 + 100 + 100 — each documents one decision in Context/Decision/Consequences form |

**Four intentional exceptions** to "keep ceilings small":

1. **`SECURITY.md`** — a reference document. A reference must be
   complete, or it is misleading. Trimming it would mean some
   attack vector is undocumented.
2. **`CODE_OF_CONDUCT.md`** — a legal document. The Contributor
   Covenant text cannot be modified.
3. **`docs/REFERENCE.md`** — a technical reference without a
   **fixed** ceiling. It merges 7 source files; a fixed ceiling
   would force a split, contradicting the 12-file model.
4. **`docs/CONTRIBUTING.md`** — a consolidated contributor
   guide at **1,500 lines**. It merges 5 source files and
   contains §12.3 (Ruleset bypass trap), §14 (18 badges), and
   §17 (v1.5.0-specific notes) — content that appears in no
   other file. Unlike exceptions 1–3, its ceiling **is** fixed
   (1,500); the exception is that the fixed value exceeds what
   "keep ceilings small" would otherwise suggest for a
   how-to+explanation file.

---

## §2. The Five Rules

Every file must satisfy all five:

1. **One audience.** If a file serves two audiences, it is two
   files.
2. **One topic per file.** The file's title must answer its
   question. A file may contain multiple sections answering
   related sub-questions of the same topic, provided they share
   an audience and are read linearly.
3. **One home per fact.** Every fact exists in exactly one
   place; other files link to it.
4. **One ceiling.** A file that exceeds its ceiling is split or
   trimmed — **unless §1 explicitly documents the reason**.
   **Four exceptions** are documented: `SECURITY.md` (reference
   completeness), `CODE_OF_CONDUCT.md` (legal text),
   `REFERENCE.md` (**no fixed ceiling**), and `CONTRIBUTING.md`
   (**1,500** — 5-source consolidated guide).
5. **No decorative headers.** No `HARD-*` identifiers, no
   "vX.Y.Z changes" blocks, no "Identifier inventory", no
   "Cross-references" sections.

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
| Future plans | `docs/ROADMAP.md` |
| Why a decision was made | `docs/adr/0001-release-workflow.md`, `0002`, `0003` |
| How to write an ADR | §8 of this file, `docs/CONTRIBUTING.md` §8 |

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

The original tree (35 files) is reduced to 15. The table below
lists all files to delete from the **current** tree, including
one special case at the end.

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

**On `CONTRIBUTING.md` as a merge target**: `CONTRIBUTING.md`
itself was **already one of the original 35 files**. Its merge
absorbs the four sibling sources above, producing a **5-source
consolidated guide** as described in §1. The consolidation is a
merge into an existing file, not a new file creation — that is
why the arithmetic in §5.3 stays at `35 − 26 + 6 = 15`.

**On `release.md` preservation**: `.github/PULL_REQUEST_TEMPLATE/release.md`
is **NOT** deleted. Its audience (release/hotfix PRs → `main`)
differs from the default template's audience (feature/fix/docs
PRs → `develop`). Per §2 Rule 1, two audiences = two files. The
decision and its reversal history are recorded in
`docs/adr/0001-release-workflow.md` §Decision → §4.

**On ADR renumbering (v1.5.0)**: the 8 pre-consolidation ADRs
were renumbered to **3**. Mapping:

| Old ADR(s) | New ADR |
|---|---|
| `0001`–`0006` (six ADRs about the release workflow) | `ADR-0001-release-workflow.md` |
| `0007` | `ADR-0002-external-dependency.md` |
| `0008` | `ADR-0003-layered-bootstrap.md` |

`ADR-0004` was already superseded before consolidation and is
absorbed into `ADR-0001` without a separate entry.

### §5.2 Additional file to delete (1 file, not in original 35)

| Removed file | Now lives in |
|---|---|
| `docs/adr/0009-documentation-budget.md` | **`docs/MAP.md` (this file)** |

> **Note on ADR-0009**: This ADR was **created during the v1.5.0
> documentation-consolidation session**, after the initial 35-file
> snapshot. It was never part of the pre-consolidation tree, and
> it is absorbed into `docs/MAP.md` (this document). It must be
> deleted from the tree after the consolidation is applied, but
> it is counted separately here to keep the arithmetic against
> the original 35 files clean.

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

Additional deletions (current tree, not in original 35):
  └── ADR-0009:                       1 file
Total deletions from current tree:   27 files
```

**Verification**: `35 − 26 + 6 = 15` ✓ (against original 35)
**Verification**: `15 (final) − 2 (PR templates) = 13` (§1 + this
file) ✓

---

## §6. Trade-offs Accepted

Five costs are paid willingly:

| Cost | Magnitude | Rationale |
|---|---|---|
| **Migration effort** | ~25,000 lines trimmed or merged | One-time; eliminates ongoing drift |
| **Friction on new files** | Every new file requires a PR amendment to §1 | Intentional: forces a decision |
| **Broken external links** | ~28 GitHub URLs 404 | Accepted; users land on `README.md` which links to `MAP.md` |
| **`REFERENCE.md` can grow large** | ~6,500 lines expected; no fixed ceiling | **Accepted**: a reference must be complete. §1 documents this as a deliberate exception |
| **`CONTRIBUTING.md` grew from 900 → 1,500** | ~1,500 lines expected (was 900 pre-v1.5.0) | **Accepted**: 5 sources (~10,300 lines) cannot compress to 900 without dropping §12.3, §14, and §17 |

Two costs were **avoided**:

| Avoided cost | Why |
|---|---|
| **Loss of historical data** | `CHANGELOG.md` retains every version. |
| **Loss of design rationale** | The 3 merged ADRs retain every decision. |

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
| **Keep `docs/adr/README.md` as meta-doc** | One more meta-doc; the ADR methodology now lives in §8 |
| **Strict ceiling for `REFERENCE.md` (1,500)** | **Rejected**: forces a file split, contradicting the 12-file model |
| **Strict ceiling for `CONTRIBUTING.md` (900)** | **Rejected**: forces the removal of §12.3, §14, and §17. Ceiling raised to 1,500 |
| **Merge `release.md` into `PULL_REQUEST_TEMPLATE.md`** | **Rejected**: violates §2 Rule 1 (two audiences = two files). `release/*` and `hotfix/*` PRs target `main` with a version-first lifecycle; `feature/*` / `fix/*` / `docs/*` PRs target `develop` with a code-quality lifecycle. Merging reintroduces the exact problem `ADR-0004` was reversed to fix. See `docs/adr/0001-release-workflow.md` §Decision → §4. |

---

## §8. Change Process

| Change | Requirement |
|---|---|
| Fix a typo | Direct commit to any file |
| Add or edit content in a **known** file | PR amending that file; no §1 change |
| Add a **new** file | PR that amends §1 **and** §3 (Reverse Lookup), **plus** a new ADR per ADR-0002 policy |
| Raise a ceiling | PR that amends §1, with justification in the PR body |
| Delete a file | PR that amends §1, §3, and §5, with justification in the PR body |
| Renumber ADRs | PR that amends §1 (rows 9–12), §3, §5.1, and any file that cross-references ADRs |
| Change this file's own structure | Follow the same rules as any other file |

**The friction is the point.** Every structural change requires
an explicit PR. That is how the map stays accurate over years
rather than months.

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
- **Never edit an accepted ADR** — create a new one.
- Mark the old ADR's Status: `Superseded by ADR-NNNN`.

**When to merge ADRs (v1.5.0 pattern)**:

- When multiple ADRs document a **single** decision (or a
  contiguous decision family).
- When the historical numbering no longer maps to the current
  architecture.
- The merge must preserve all rationale (Context, Decision,
  Consequences) in the target ADR.
- All cross-references across the codebase must be updated in
  the same PR.

**Current ADR index**: see §1 rows 9–12.

---

*This file is a constitutional meta-document. It governs the 12
user-facing docs listed in §1 but is itself **one of the 13
user-facing files** — not an exception. The original version of
this file tried to exempt itself from its own count, which is
exactly the kind of circular reasoning §0 was written to
eliminate.*

*It is updated only when the structure of the project's
documentation changes.*

*`REFERENCE.md` is the only file in this map without a fixed
ceiling. That exception is documented in §1 and §2 Rule 4.*

*`CONTRIBUTING.md` has a fixed ceiling of 1,500 — larger than
"keep ceilings small" would normally allow, but documented as a
deliberate exception in §1 and §2 Rule 4.*

*The two GitHub PR templates (`.github/PULL_REQUEST_TEMPLATE.md`
and `.github/PULL_REQUEST_TEMPLATE/release.md`) live outside this
map. They are not documentation; they are GitHub meta-files. Their
existence, rationale, and reversal history are recorded in
`docs/adr/0001-release-workflow.md`.*