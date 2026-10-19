# ADR-0002: External Dependency — `filepath-securejoin`

**Status**: ✅ Accepted
**Date**: 2026-10-10
**Consolidated**: 2026-10-19 (v1.5.0 Global Edition — renumbered from ADR-0007)
**Authors**: [@gasciljh](https://github.com/gasciljh)
**Supersedes**: —
**Superseded by**: —

---

## Context

The project followed a strict dependency-free policy since v1.0.0: only the Go
standard library was used (`REFERENCE.md` §1.2). This policy is cited in
`README.md`, `SECURITY.md`, and `REFERENCE.md` as a core design principle.

In v1.4.0, `removeModule` in `proxy/main.go` was hardened against path traversal
with `filepath.Base()` sanitization + `MODULES_DIR` prefix check + path
reconstruction from the trusted base. The defense is functionally correct — the
resulting path is safe for all valid inputs.

However, GitHub CodeQL's `go/path-injection` query does not recognize
`filepath.Base()` as a sanitizer in this data-flow context. Two alerts remained
open on `main` (#1, #2), and every future PR re-triggered the same alerts,
polluting the security dashboard.

**Constraints**:

- The project values its dependency-free posture as a core selling point.
- CodeQL runs on every PR to `main` and `develop`.
- Any mitigation must be auditable and documented.
- The dependency must be narrowly scoped — no transitive runtime dependencies.

## Decision

We will add `github.com/cyphar/filepath-securejoin v0.7.0` as the first and
only external Go dependency of the project, scoped exclusively to `removeModule`
in `proxy/main.go`.

- **Version**: pinned to `v0.7.0` in `proxy/go.mod`.
- **Scope**: exactly one call site — `securejoin.SecureJoin(MODULES_DIR, name)`.
- **Surrounding defenses** (kept, defence-in-depth): `filepath.Base()`
  sanitization, `MODULES_DIR` prefix check, fingerprint validation.
- **Checksums**: `proxy/go.sum` records the SHA-256 of `v0.7.0`.

**Rationale**:

- `filepath-securejoin` is the mitigation GitHub's own CodeQL documentation
  recommends for `go/path-injection`.
- Small (~500 LoC), stable, maintained by the containers community
  (`containerd`, `runc`, `buildah`, `podman`).
- `SecureJoin` rejects any path that would escape the base directory, even
  under adversarial inputs.
- Closes the two `go/path-injection` alerts permanently.

**Compliance rule**: any future external dependency MUST have its own ADR.
This ADR is the only authorized exception to the dependency-free policy of
`REFERENCE.md` §1.2.

## Consequences

### Positive

- ✅ CodeQL `go/path-injection` alerts closed automatically.
- ✅ The `removeModule` path is provably safe (defence-in-depth preserved).
- ✅ Future PRs will not re-trigger the same alert.
- ✅ The change is narrowly scoped — one function, one file.

### Negative

- ❌ The project is no longer fully dependency-free (this specific case only).
- ❌ `proxy/go.sum` is now required (previously absent).
- ❌ Supply-chain risk is non-zero, mitigated by provenance, small surface,
  and the `go.sum` checksum.
- ❌ A new review obligation: future dependency updates require the same
  discipline (ADR, audit, pin).

### Neutral

- ⚪ The dependency is pinned to `v0.7.0`. Upgrades require a separate PR plus
  a review of the upstream changelog.
- ⚪ When the project moves to Go 1.24+, `os.Root` becomes a candidate
  replacement. That would be a future ADR, not a change to this one.

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| Dismiss the CodeQL alert | Requires per-PR dismissal; the noise recurs every PR; future contributors re-evaluate the same concern. |
| Rewrite `removeModule` to bypass CodeQL's flow analysis | Optimizing for a scanner rather than for correctness is an anti-pattern; brittle against CodeQL updates. |
| Replace with a hand-rolled path-sanitizer | Reimplements a security-sensitive primitive; higher bug risk than a battle-tested library. |
| Use `os.Root` (Go 1.24+) | Not available on the project's current Go 1.22 target. |
| Accept the alert permanently | Pollutes the security dashboard; contradicts the project's security posture. |

## Related Decisions

- [ADR-0001](0001-release-workflow.md) — the release workflow that ships this
  dependency and the six-cycle verification of the release process.
- [ADR-0003](0003-layered-bootstrap.md) — applies the same "single source of
  truth" reasoning to the shell library.

## References

- **Code**: [`proxy/main.go`](../../proxy/main.go) → `removeModule()`.
- **Pin**: [`proxy/go.mod`](../../proxy/go.mod), [`proxy/go.sum`](../../proxy/go.sum).
- **Narrative**: `SECURITY.md` §5.34, `REFERENCE.md` §1.3, `CONTRIBUTING.md` §17.3.
- **External**: [CodeQL `go/path-injection`](https://codeql.github.com/codeql-query-help/go/go-path-injection/),
  [CWE-22](https://cwe.mitre.org/data/definitions/22.html),
  [`filepath-securejoin`](https://github.com/cyphar/filepath-securejoin).

---

*This ADR is immutable. To reverse or amend it, create a new ADR that supersedes
it and update its Status line.*