# ADR-0003: Layered Bootstrap

**Status**: ✅ Accepted
**Date**: 2026-10-15
**Consolidated**: 2026-10-18 (v1.5.0 Global Edition — renumbered from ADR-0008)
**Authors**: [@gasciljh](https://github.com/gasciljh)
**Supersedes**: —
**Superseded by**: —

---

## Context

The module's shell code accumulated shared primitives across 6–7 files. Each
copy carried comments like `# KEEP IN SYNC with functions.sh`, but the comments
were not enforced. Three quarters of maintenance work concentrated on the same
problem:

| Primitive | Copies | Approx. duplicated lines |
|-----------|-------:|-------------------------:|
| `rotate_backups` | 7 | ~490 |
| `is_port_open` | 6 | ~210 |
| `log_msg` | 6 | ~180 |
| `read_conf` | 5 | ~125 |
| `get_profile_memory_hint` | 5 | ~120 |
| `_list_snapshots` | 5 | ~150 |
| `_inline_cleanup_firewall` | 4 | ~120 |
| **Total** | — | **~1,395 lines** |

Historical evidence: v1.3.0 (SNAP-MANIFEST) → 7 files updated by hand. v1.5.0
(`apk/` mirror) → 7 files updated again. No automated check confirmed
consistency.

The design intent behind the duplication was defensive — *"each script must be
self-contained because `functions.sh` might fail to load"*. The rationale is
legitimate, but the implementation went too far: it duplicated **everything**,
including primitives that have no meaningful fallback path anyway.

**Constraints**:

- Caller scripts must remain bootable even if some library files are missing
  (partial install, SELinux context loss, disk corruption).
- `post-fs-data.sh` must always run (early boot). `uninstall.sh` must always
  complete.
- The module ZIP structure is fixed by Magisk conventions — no symlinks, no
  subdirectories under `proxy/`.
- Phase 0 must be **add-only**: no change to any caller script's behavior.

## Decision

Adopt the Layered Bootstrap pattern: exactly two layers with a strict dependency
direction (Layer 1 sources Layer 0; nothing else).

**Layer 0 — `proxy/boot-mini.sh`** (~285 lines, ~90 executable)

- Contains exactly **five primitives** and **one constant**:
  `log_msg`, `get_run_dir`, `read_conf`, `is_port_open`, `get_webui_port`,
  `_MONITORING_UI_PORT`.
- Zero dependencies (BusyBox / toybox built-ins only).
- Always present in the module ZIP; verified as a critical file by
  `customize.sh` §[10].

**Layer 1 — `proxy/functions.sh`**

- Every other shared function (firewall, backups, cleanup, WebUI launcher,
  TOML reader, watchdog token reader).
- Sources Layer 0 at load time: `. "$MODDIR/boot-mini.sh"`.
- Does **not** redefine any of the five primitives or the constant.
- Keeps thin aliases (`log_fn` → `log_msg`, `get_conf_value` → `read_conf`)
  for backward compatibility.

**Enforcement — dual guard**

- **CI guard**: `ci.yml` Step 9 ("Verify boot-mini.sh integration") fails the
  build if any primitive is missing, if `_MONITORING_UI_PORT` is not defined,
  if `functions.sh` does not source `boot-mini.sh`, or if `functions.sh`
  redefines a Layer-0 primitive.
- **Local guard**: `make check-boot-mini` runs the same checks locally.

**Out of scope (deferred)**: caller failure policy, removal of remaining inline
fallbacks, migration from `log_fn` to `log_msg`, further splitting of
`functions.sh`. These are tracked in `ROADMAP.md` §2.

## Consequences

### Positive

- ✅ Single source of truth for the five primitives and the reserved-port
  constant. A future change touches one file, not six.
- ✅ ~1,395 duplicated lines reduced to their canonical implementation.
- ✅ Stderr fallback for `log_msg` when `$LOG_FILE` is unwritable (early boot).
  On Android, stderr from a Magisk/KernelSU script reaches logcat.
- ✅ Boot-path stability: Phase 0 is add-only, so no boot-time behavior changes.
- ✅ Drift detection: the CI guard converts "KEEP IN SYNC" from a comment to an
  enforced contract.
- ✅ Testability: the five primitives can now be unit-tested by sourcing one
  file, without isolating them from `functions.sh`'s top-level side effects.
- ✅ v1.5.0 evidence: the `apk/` mirror skip in `customize.sh` §[10c] was
  applied consistently across all copies of `rotate_backups()` without a manual
  sweep — direct evidence of the pattern's value.

### Negative

- ❌ One more file to ship. `proxy/boot-mini.sh` must be included by
  `package_module.sh`, extracted by `customize.sh` §[9], verified by §[10],
  and covered by `ci.yml`'s `bash -n` check. All four integration points are
  implemented. Cost is bounded (~10 lines total).
- ❌ Indirect load order: `functions.sh` sources another file before defining
  its own functions. A future edit that reorders the sections would produce a
  subtle failure at load time. Only runtime testing catches this.
- ❌ Small learning curve: a developer reading `functions.sh` for the first time
  must know that `log_msg` lives in `boot-mini.sh`. The file header documents
  the split, so the curve is shallow.

### Neutral

- ⚪ No change to any caller's behavior. Every script that sourced
  `functions.sh` before Phase 0 still sources it. Every script that fell back
  to inline code still does.
- ⚪ No change to the module's public interface (no CLI flag, no HTTP endpoint,
  no on-disk file path changes).
- ⚪ No change to the module version. This is an internal refactor inside the
  v1.5.0 cycle.

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| Status quo (keep the duplication) | 7-file updates every time a primitive changes; "KEEP IN SYNC" comments are not enforced; the three historical sweeps prove the cost is real. |
| Full unification into a single `lib.sh` | If that file fails to load, every caller fails — including `post-fs-data.sh` and `uninstall.sh`, which must always run. The layered split lets each caller choose its own degradation policy. |
| Symlinks from `proxy/*.sh` to a central location | Symlinks do not survive the ZIP round-trip reliably on all Android filesystems; `unzip` behavior with symlinks is inconsistent; multiplies SELinux context failure modes. |
| Code-generation | Moves the duplication into the build system; CI must re-run the generator on every push; a developer forgetting to regenerate produces the same drift. |
| Make `functions.sh` mandatory | This is a caller policy, not a library-structure decision. Would break `post-fs-data.sh` and `uninstall.sh`. Deferred to a future ADR. |
| Verify parity between copies instead of removing them | Removing the duplication is strictly better than detecting it. |

## Related Decisions

- [ADR-0002](0002-external-dependency.md) — applies the same "single source of
  truth" reasoning to the Go dependency graph.
- [ADR-0001](0001-release-workflow.md) — the release workflow that ships the
  split and enforces it in CI across release cycles.

## References

- **Code**: [`proxy/boot-mini.sh`](../../proxy/boot-mini.sh),
  [`proxy/functions.sh`](../../proxy/functions.sh).
- **Integration**: [`proxy/customize.sh`](../../proxy/customize.sh) §[9], §[10];
  [`scripts/package_module.sh`](../../scripts/package_module.sh).
- **CI guard**: [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)
  Step 9; [`Makefile`](../../Makefile) `check-boot-mini` target.
- **Narrative**: `REFERENCE.md` §1.4 (Layered Bootstrap),
  `REFERENCE.md` §3.12 (`install_app.sh` contract),
  `REFERENCE.md` §1.2 (Zero-Footprint principle),
  `CONTRIBUTING.md` §17.2.

---

*This ADR is immutable. To reverse or amend it, create a new ADR that supersedes
it and update its Status line.*