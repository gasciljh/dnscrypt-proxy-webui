# ADR-0007: External Dependency — `filepath-securejoin`

- **Status**: Accepted
- **Date**: 2026-10-10
- **Deciders**: gasciljh
- **Supersedes**: none
- **Related**: ADR-0006, `docs/ARCHITECTURE.md` §1.2

## Context

The project has, since v1.0.0, followed a strict **dependency-free
policy**: only the Go standard library is used
(`docs/ARCHITECTURE.md` §1.2 and `docs/adr/README.md` §3).

In v1.4.0, we hardened `removeModule` (in `proxy/main.go`) with a
multi-layer defense against path traversal, using only
`filepath.Base` + prefix checks + path reconstruction from a
trusted base directory. This defense is **functionally correct** —
the resulting path is safe for all valid inputs.

However, GitHub CodeQL's `go/path-injection` query does **not**
recognize `filepath.Base()` as a sanitizer in this data-flow
context. As a result:

- The alert remains open on `main`.
- Every future PR re-triggers the same alert, polluting the
  security dashboard.

Three options were considered:

1. **Dismiss** the alert with a written justification.
2. **Rewrite** the function to bypass CodeQL's flow analysis
   (hacky, less secure).
3. **Add** the official CodeQL-recommended mitigation:
   `github.com/cyphar/filepath-securejoin`.

## Decision

We chose **option 3** — add `github.com/cyphar/filepath-securejoin`
as the **first and only** external dependency of the project,
scoped exclusively to `proxy/main.go:removeModule`.

## Rationale

- **Official**: `filepath-securejoin` is the mitigation GitHub's
  own CodeQL documentation recommends for `go/path-injection`.
- **Audited**: The library is small (~500 LoC), stable (v0.7.0,
  released 2025), and maintained by the containers community
  (used by `containerd`, `runc`, `buildah`, `podman`).
- **Secure by design**: `SecureJoin` rejects any path that would
  escape the base directory, even in adversarial inputs.
- **Localized**: Only one function in one file uses it. Everything
  else remains standard-library-only.
- **Testable**: The change is small and covered by existing
  integration tests.

## Consequences

### Positive

- CodeQL `go/path-injection` alert is closed automatically.
- The code is now **provably** safe (defence-in-depth preserved:
  `SecureJoin` + prefix check + explicit name rejection +
  fingerprint validation).
- Future PRs will not re-trigger the same alert.
- The security dashboard is clean.

### Negative

- The project is **no longer fully dependency-free**. This ADR
  supersedes the "no external dependencies" clause of
  `docs/ARCHITECTURE.md` §1.2, but only for this specific case.
- `go.sum` is now required (previously it was intentionally
  absent).
- Supply-chain risk is non-zero, though mitigated by the library's
  provenance and small surface.

### Neutral

- The dependency is **pinned** to `v0.7.0`. Upgrades require a
  separate PR.

## Compliance

This ADR is the only authorized exception to the dependency-free
policy. **Any future external dependency MUST have its own ADR.**

## References

- GitHub CodeQL docs: `go/path-injection` recommended fix
- `github.com/cyphar/filepath-securejoin` v0.7.0
- CWE-22: Path Traversal
- `proxy/main.go` — `removeModule` function
- `docs/ARCHITECTURE.md` §1.2 — Zero-Footprint principle
- `docs/adr/README.md` §3 — Dependency-free policy
