# ADR-0006: Rename `hotfix.sh` → `release-patch.sh`

**Status**: ✅ Accepted

**Date**: 2026-09-24

**Authors**: [@gasciljh](https://github.com/gasciljh)

**Supersedes**: —

**Superseded by**: —

---

## Context

### The problem

An early draft of the release tooling proposed a script named
`scripts/hotfix.sh` — a wrapper around [`scripts/release.sh`](../../scripts/release.sh)
that adds three safety rules for PATCH-only releases.

The name `hotfix.sh` was **inherited from the general Git culture** where
"hotfix" is a well-known term (see Git Flow). However, on closer
inspection, this name introduced **three distinct problems**:

1. **Inconsistent naming.** The primary release script is `release.sh`.
   Its sibling was `hotfix.sh` — different prefix, different semantics.
   Reading the `scripts/` folder, a contributor would not immediately
   see them as a related pair.

2. **Conceptual mismatch.** In Semantic Versioning, what the script
   produces is a **PATCH release** (increments `PATCH` only). "Hotfix"
   is a **Git Flow term** that refers to the branch (`hotfix/*`), not
   the version component. Mixing terminology across two different
   naming systems created ambiguity.

3. **Prefix collision with branches.** The project already uses
   `hotfix/*` as a **branch prefix** (see [ADR-0001](0001-two-branch-model.md)).
   Having both `hotfix/*` (branch) and `hotfix.sh` (script) meant that
   a search for "hotfix" returned results from two unrelated domains —
   the branch and the tool.

### The forces at play

| Force | Direction |
|---|---|
| **Naming consistency** | 🎯 High — related tools should share a prefix |
| **Semantic accuracy** | 📖 High — the name should describe what the tool does |
| **Search clarity** | 🔍 High — distinct concepts should have distinct names |
| **Backward compatibility** | ⚠️ Medium — the tool is unreleased, so no external users |
| **Documentation updates** | 📝 Medium — several files reference the old name |
| **Cognitive load** | 🧠 Medium — fewer mental mappings = better DX |

### Constraints

- The tool must be released in `v1.0.0` — this is the **last chance** to
  rename it without breaking user scripts.
- The rename must be **complete** — no `hotfix.sh` alias left behind.
- Documentation, `Makefile`, `CHANGELOG.md`, and `ROADMAP.md` must be
  updated in the same change set.
- The rename must not change the script's **behavior** — only its name.

### Scope

This ADR covers **the name of the PATCH-release wrapper script**. It does
**not** cover:

- The PATCH-release logic itself → see [ADR-0002](0002-automated-releases.md).
- The `hotfix/*` branch naming → see [ADR-0001](0001-two-branch-model.md).
- The release workflow → see [ADR-0002](0002-automated-releases.md) and
  [ADR-0003](0003-post-release-sync.md).

---

## Decision

> **We will rename `scripts/hotfix.sh` → `scripts/release-patch.sh`,**
> **aligning the prefix with `scripts/release.sh` and reflecting the**
> **actual version component the script increments (PATCH).**

### Specifics

#### Naming rationale

| Aspect | Rationale |
|---|---|
| **Prefix `release-`** | Matches `release.sh` — the two form a discoverable pair. |
| **Suffix `-patch`** | Describes the exact SemVer component: `PATCH`. |
| **Kebab-case** | Consistent with `fetch_dns_binaries.sh`, `package_module.sh`, `generate-icons.sh`. |
| **`.sh` extension** | Explicit shell script (not a binary). |

#### The naming pair

```text
scripts/
├── release.sh                  ← MINOR/MAJOR releases (from develop)
├── release-patch.sh            ← PATCH releases (from main)
├── fetch_dns_binaries.sh
├── generate-icons.sh
└── package_module.sh
```

The two release scripts now sit side by side, alphabetically adjacent,
and share the `release-` prefix.

#### What changes

| Item | Before | After |
|---|---|---|
| Script file | `scripts/hotfix.sh` | `scripts/release-patch.sh` |
| Header comment | `DNSCrypt Smart Filter – hotfix.sh` | `DNSCrypt Smart Filter – release-patch.sh` |
| Usage examples | `./scripts/hotfix.sh v1.0.1` | `./scripts/release-patch.sh v1.0.1` |
| Help text | `hotfix.sh <version>` | `release-patch.sh <version>` |
| Error messages | "Hotfixes MUST NOT..." | "Patch releases MUST NOT..." |
| Summary box | "Hotfix summary:" | "Patch release summary:" |
| Post-reminder | "Hotfixes land on 'main' first" | "Patch releases land on 'main' first" |

#### What does NOT change

- ✅ The script's **behavior** — same 3 safety rules (branch = `main`,
  `MAJOR` equal, `MINOR` equal, `PATCH` = current + 1).
- ✅ The delegation to [`scripts/release.sh`](../../scripts/release.sh).
- ✅ The `--dry-run`, `--no-push`, `--yes`, `--help` flags.
- ✅ The exit codes (`0`, `1`, `2`, `3`, `4`).
- ✅ The `hotfix/*` **branch prefix** — that remains, because it aligns
  with the widely-recognized Git Flow terminology (see
  [ADR-0001](0001-two-branch-model.md)).

#### Files updated as part of this rename

| File | Change |
|---|---|
| `scripts/hotfix.sh` | 🗑️ Deleted |
| `scripts/release-patch.sh` | ✨ Created (same logic) |
| `Makefile` | Target `hotfix:` → `release-patch:` (or aliased) |
| `docs/BRANCHING.md` §8 | References updated |
| `docs/RELEASE_PROCESS.md` §2.3 | References updated |
| `docs/ROADMAP.md` §10 | References updated |
| `CHANGELOG.md` | Entry rewritten |

#### Conceptual clarification

| Term | Domain | Meaning |
|---|---|---|
| **`hotfix/*`** | Branch name | Emergency fix branch created from `main` |
| **PATCH** | SemVer component | Third number in `vX.Y.Z` |
| **`release-patch.sh`** | Script | Tool that bumps PATCH from `main` |

By separating these three, each concept has **one name** in **one domain**.

### Diagram

```text
Concept                    Branch             Script              Version
─────────────────────────────────────────────────────────────────────────
Regular release      ──▶   release/*      ──▶  release.sh      ──▶  MINOR / MAJOR
                                                                            │
Emergency fix        ──▶   hotfix/*       ──▶  release-patch.sh ─▶  PATCH
                            ▲                   ▲                    ▲
                            │                   │                    │
                            └─── Git term ──────┴──── SemVer term ──┘
```

---

## Consequences

### Positive

- ✅ **Naming consistency.** `release.sh` and `release-patch.sh` share
  a prefix and can be listed together with a single glob
  (`scripts/release*.sh`).
- ✅ **Semantic accuracy.** The name describes the exact version
  component (`PATCH`), matching the SemVer vocabulary used everywhere
  else in the project.
- ✅ **Search clarity.** Searching for "hotfix" now returns only the
  **branch** concept — no more false positives from a script.
- ✅ **Better onboarding.** A new contributor reading `scripts/` sees
  two clearly related tools.
- ✅ **Aligned with `docs/BRANCHING.md`.** The branch is `hotfix/*`
  (Git convention), the script is `release-patch.sh` (SemVer convention).
  Each name lives in the domain where it belongs.
- ✅ **Future-proof.** If a MINOR-emergency or MAJOR-emergency variant
  is ever needed, the pattern `release-minor.sh`, `release-major.sh`
  extends naturally.

### Negative

- ❌ **Documentation churn.** Five files must be updated simultaneously
  (see the table above). Missing one creates an inconsistent state.
- ❌ **Lost muscle memory.** Contributors who saw the draft
  `hotfix.sh` name must relearn. This is mitigated by the fact that
  the tool is **not yet released** — no external scripts reference it.
- ❌ **One more naming convention to explain.** The `hotfix/*` branch
  and the `release-patch.sh` script use **different vocabularies**.
  This must be documented (done in this ADR).
- ❌ **Git history discontinuity.** `git log scripts/release-patch.sh`
  will show only the commits after the rename. The history of
  `hotfix.sh` (drafts) is technically preserved but not reachable via
  the new path.
- ❌ **No alias for the old name.** Users who somehow learned the draft
  name will hit an error. Accepted because the tool was never released.

### Neutral

- ⚪ **The header version** stays `v1.0.0` — the rename is part of the
  initial release, not a separate version.
- ⚪ **The script's content is 95% identical.** Only the header,
  usage strings, and messages change.
- ⚪ **The `hotfix/*` branch prefix remains.** Only the script name
  changes.

---

## Alternatives Considered

| Alternative | Pros | Cons | Why rejected |
|---|---|---|---|
| **Keep `hotfix.sh`** (no change) | ✅ Matches Git Flow terminology<br>✅ Zero documentation churn<br>✅ Familiar to Git users | ❌ Inconsistent prefix with `release.sh`<br>❌ Confusing search results (branch vs script)<br>❌ Mixes Git vocabulary with SemVer vocabulary<br>❌ Does not describe the version component | Accepts three problems in exchange for zero effort. Since the script is not yet released, this is the cheapest moment to fix the name. |
| **`patch-release.sh`** | ✅ Contains both `patch` and `release`<br>✅ Descriptive | ❌ Prefix is `patch-`, not `release-`<br>❌ Breaks the visual pairing with `release.sh`<br>❌ Alphabetical listing groups it with `p`, not `r` | The point of the rename is to **group** the two release scripts. `patch-release.sh` defeats that goal. |
| **`release-hotfix.sh`** | ✅ Keeps the "hotfix" term<br>✅ Uses the `release-` prefix | ❌ Reinforces the branch/script confusion<br>❌ Long name (17 characters)<br>❌ Uses Git vocabulary for a SemVer concept | Keeps the original problem while adding the desired prefix. Worst of both worlds. |
| **`rpatch.sh`** | ✅ Short (10 characters)<br>✅ Easy to type | ❌ Opaque — nobody knows what `rpatch` means<br>❌ Inconsistent with the `release-` prefix<br>❌ Not self-documenting | Saves 5 characters at the cost of comprehensibility. Rejected on first principles. |
| **`release-patch.sh` (chosen)** | ✅ Shares prefix with `release.sh`<br>✅ Uses precise SemVer terminology<br>✅ Kebab-case, self-documenting<br>✅ Alphabetically adjacent to `release.sh`<br>✅ Extensible (`release-minor.sh`, `release-major.sh`) | ❌ `hotfix/*` branch and `release-patch.sh` script use different vocabularies | — |

---

## Related Decisions

| ADR | Relationship |
|---|---|
| [ADR-0001](0001-two-branch-model.md) | Defines the `hotfix/*` branch prefix, which remains unchanged. |
| [ADR-0002](0002-automated-releases.md) | Defines `release.sh`, the sibling of `release-patch.sh`. |
| [ADR-0005](0005-release-specific-pr-template.md) | References `release-patch.sh` in the release PR template. |

---

## References

### Project files

- [`scripts/release.sh`](../../scripts/release.sh) — the primary release script.
- [`scripts/release-patch.sh`](../../scripts/release-patch.sh) — the renamed script.
- [`Makefile`](../../Makefile) — updated target (`hotfix:` → `release-patch:`).
- [`docs/BRANCHING.md`](../BRANCHING.md) §8 — hotfix flow documentation.
- [`docs/RELEASE_PROCESS.md`](../RELEASE_PROCESS.md) §2.3 — PATCH release type.
- [`docs/ROADMAP.md`](../ROADMAP.md) §10.2 — workflow priorities.
- [`CHANGELOG.md`](../../CHANGELOG.md) — the rename is recorded here.

### External references

- [Semantic Versioning 2.0.0 — PATCH definition](https://semver.org/#spec-item-6)
- [A successful Git branching model — Vincent Driessen (hotfix branches)](https://nvie.com/posts/a-successful-git-branching-model/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Conventional Commits](https://www.conventionalcommits.org/)

### Discussion

- Initial draft name: `hotfix.sh` (used in an earlier proposal).
- Rename decided during the workflow overhaul that produced
  [ADR-0001](0001-two-branch-model.md) through
  [ADR-0005](0005-release-specific-pr-template.md).

---

*This ADR is immutable. To reverse or amend it, create a new ADR that
supersedes it and update its Status line.*