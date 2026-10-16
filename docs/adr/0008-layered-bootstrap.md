# ADR-0008: Layered Bootstrap Pattern

**Status:** Accepted
**Date:** 2026-10-15
**Deciders:** gasciljh (project maintainer)
**Supersedes:** —
**Superseded by:** —
**Related:**
- ADR-0007 (external dependency policy — same "single source of truth" rationale)
- `docs/ARCHITECTURE.md` §3.12 (Layered Bootstrap architecture)
- `proxy/boot-mini.sh` (Layer 0 implementation)
- `proxy/functions.sh` (Layer 1 implementation)

---

## Context

The module's shell code has accumulated a chronic duplication problem
across its 1.5.0 lifecycle.

### The observable problem

Every time a shared shell primitive changes, the change must be applied
manually to every copy of that primitive. Measured against the v1.5.0
tree before this ADR:

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

### Historical evidence of the cost

Three quarters of maintenance work concentrated on the same problem:

- **v1.3.0** added the SNAP-MANIFEST snapshot-detection rule → 7 files
  updated by hand (each with a slightly different comment explaining
  why the change was needed).
- **v1.5.0** added the `apk/` companion-mirror subfolder → 7 files
  updated again.
- **v1.5.0+** added ACT-V15-02, SVC-V15-02, and UNS-APK-01 → 3 more
  files updated.

No automated check confirmed that the copies remained consistent.

### The deeper problem: "parity with canonical" as a self-defeating comment

Every copy carried a comment like:

```sh
# KEEP IN SYNC with functions.sh:rotate_backups
# parity with functions.sh:rotate_backups
# matching v1.3.0 semantics
```

These comments were meant to be warnings. In practice, they accumulated
into a fog: when a developer saw a diff touching one copy, they could
not tell from the comment alone whether the other six copies needed
the same change.

### The architectural question

The design intent behind the duplication was originally:

> "Each shell script must be self-contained, because `functions.sh`
> might fail to load."

This is a **defensive** rationale, not a performance one. It is
legitimate — a boot script that refuses to run because a library is
missing is worse than a boot script that runs without that library.
But the implementation went too far: it duplicated **everything**,
including small primitives that have no meaningful fallback path
anyway.

The correct decomposition is not "no library" vs. "one big library".
It is:

- A small, always-available library for the primitives that must
  never fail.
- A larger, optional library for the functions that can fail
  without taking the module down.

---

## Decision

Adopt the **Layered Bootstrap pattern** for the module's shell code.

The pattern defines exactly two layers of shared code:

### Layer 0 — `proxy/boot-mini.sh`

- **Size:** ~200 lines (≈90 executable).
- **Contents:** exactly five primitives and one constant:
  - `log_msg`
  - `get_run_dir`
  - `read_conf`
  - `is_port_open`
  - `get_webui_port`
  - `_MONITORING_UI_PORT` (shell-side single source of truth)
- **Dependencies:** none (only BusyBox / toybox built-ins).
- **Contract:** always present in the module ZIP; verified by
  `proxy/customize.sh` §[10] as a critical file.
- **Failure mode:** if `boot-mini.sh` is missing at install time,
  `customize.sh` aborts the install before any file is written.

### Layer 1 — `proxy/functions.sh`

- **Contents:** every other shared function (firewall management,
  backups, cleanup, WebUI launcher, TOML reader, etc.).
- **Sources Layer 0 at load time** (`. "$MODDIR/boot-mini.sh"`).
- **Depends on Layer 0** — it does not redefine any of the five
  primitives.
- **Keeps thin aliases** for backward compatibility with existing
  call sites:
  - `log_fn` → delegates to `log_msg`
  - `get_conf_value` → delegates to `read_conf`
- **Failure mode:** if `functions.sh` fails to load, the caller
  decides what to do based on its own criticality (see below).

### Caller policy — deferred per caller

This ADR does **not** change the failure policy of any caller script
in this phase. All callers continue to behave exactly as they did
before: source `functions.sh`, fall back to inline code if it fails.

Changing the caller policy is deferred to a future ADR (see
"Follow-up decisions" below).

### Enforcement — dual guard

Two independent checks ensure the split does not silently drift:

1. **CI guard** — `.github/workflows/ci.yml` Step 9
   ("Verify boot-mini.sh integration") fails the build if:
   - Any of the 5 primitives is missing from `boot-mini.sh`.
   - `_MONITORING_UI_PORT` is not defined in `boot-mini.sh`.
   - `functions.sh` does not source `boot-mini.sh`.
   - `functions.sh` redefines any Layer-0 primitive (except
     `log_msg`, which may be aliased as `log_fn`).
2. **Local guard** — `make check-boot-mini` runs the same checks
   locally, so a developer catches drift before pushing.

---

## Consequences

### Positive

- **Single source of truth** for the 5 primitives and the reserved-port
  constant. A future change (e.g. a new reserved port) touches one
  file, not six.
- **~1,395 duplicated lines reduced to their canonical implementation**
  in `boot-mini.sh` (≈90 executable lines) plus aliases in
  `functions.sh`.
- **Stderr fallback for `log_msg`.** The Layer-0 implementation writes
  to stderr when `$LOG_FILE` is unwritable (e.g. during early boot
  before `/data/local/tmp` is mounted). On Android, stderr from a
  Magisk/KernelSU script is captured by logcat — no diagnostic is
  silently lost. This was not guaranteed by the previous per-script
  copies.
- **Boot-path stability.** Because Phase 0 is add-only (no caller
  script modified), no boot-time behavior changes. The pattern is
  introduced without touching the code that runs at
  `sys.boot_completed`.
- **Drift detection.** The CI guard converts "KEEP IN SYNC" from a
  comment to an enforced contract.
- **Testability.** The 5 primitives can now be unit-tested by sourcing
  one file, without needing to isolate them from `functions.sh`'s
  top-level side effects (`init_runtime_paths`, bootstrap-cache
  initialization).

### Negative

- **One more file to ship.** `proxy/boot-mini.sh` must be:
  - included by `scripts/package_module.sh` in the module ZIP,
  - extracted by `proxy/customize.sh` §[9],
  - verified by `proxy/customize.sh` §[10],
  - covered by `ci.yml`'s `bash -n` syntax check.
  All four integration points are implemented in Phase 0. The
  cost is bounded (~10 lines of integration code total).
- **Indirect load order.** `functions.sh` now sources another file
  before defining its own functions. A future edit that reorders the
  `[1]` and `[1b]` sections (e.g. by moving `[1b]` below a function
  that uses `log_msg`) would produce a subtle failure at load time.
  The CI guard does not catch this specific case; only runtime
  testing does.
- **Small learning curve.** A developer reading `functions.sh` for the
  first time must know that `log_msg` lives in `boot-mini.sh`. The
  file header documents the split, and the delegation is one-line
  (`log_fn() { log_msg "$1"; }`), so the curve is shallow.

### Neutral

- **No change to any caller's behavior.** Every script that sourced
  `functions.sh` before Phase 0 still sources it. Every script that
  fell back to inline code before Phase 0 still falls back to inline
  code. Phase 0 is architecturally additive.
- **No change to the module's public interface.** No command-line
  flag, no HTTP endpoint, and no on-disk file path changes.
- **No change to the module version.** This is an internal refactor
  inside the v1.5.0 Global Edition cycle; `VERSION`, `module.prop`,
  and `update.json` are unchanged.

---

## Alternatives considered

### 1. Status quo (keep the duplication)

**Rejected.** The evidence in the Context section shows the duplication
has a measurable maintenance cost (7-file updates for three releases
in a row). "KEEP IN SYNC" comments are not a substitute for an
enforced contract.

### 2. Full unification into a single `lib.sh`

**Rejected.** This would require every caller to depend on one file.
If that file fails to load — for any reason (partial install, SELinux
context loss, disk corruption) — every caller script fails, including
`post-fs-data.sh` (which must always run) and `uninstall.sh` (which
must always complete). The layered split lets each caller choose its
own degradation policy without forcing a global one.

### 3. Symlinks from `proxy/*.sh` to a central location

**Rejected.** Symlinks do not survive the ZIP round-trip reliably on
all Android filesystems. `unzip` behavior with symlinks is
inconsistent, and the module installer already fights SELinux context
issues on every file. Adding symlinks would multiply the failure
modes.

### 4. Code-generation: one source file, multiple generated targets

**Rejected.** This would move the duplication into the build system.
The CI step would need to re-run the generator on every push, and a
developer forgetting to regenerate would produce the same class of
drift this ADR is trying to eliminate — but now with an extra
indirection layer.

### 5. Make `functions.sh` mandatory (fail if it does not load)

**Rejected for this ADR.** This is a legitimate design choice for some
callers (e.g. `action.sh`, which cannot do anything useful without
`functions.sh`). But it is a **caller policy**, not a
**library-structure** decision. Conflating the two would make this
ADR harder to review and harder to revert. The policy question is
deferred to a future ADR (see below).

### 6. Verify parity between copies instead of removing them

**Rejected.** A `verify-parity.sh` script that compares the `sha256`
of each duplicated function's body would catch drift **after** it
happens, not prevent it. Given the frequency of the change (three
times in three releases), even a perfect detector would still require
seven edits every time. Removing the duplication is strictly better
than detecting it.

---

## Follow-up decisions (deferred, not part of this ADR)

The following questions were considered during the design of this ADR
but are deliberately out of scope. Each will be decided by its own
ADR if pursued:

1. **Caller failure policy.** Should `service.sh` / `action.sh` fail
   hard when `functions.sh` is missing (as `post-fs-data.sh` always
   does), or degrade gracefully (as `status.sh` does)?
   *Current state: unchanged from before this ADR — each caller keeps
   its existing policy.*

2. **Removal of remaining inline fallbacks.** After Phase 0, callers
   still carry inline copies of primitives (`_inline_is_port_open`,
   `_inline_read_conf`, etc.) for the "`functions.sh` failed" path.
   These are now technically redundant with `boot-mini.sh` — but
   removing them would couple the callers to Layer 0 in a way that
   Phase 0 deliberately avoids.
   *Current state: kept as-is; removal deferred.*

3. **Migration from `log_fn` to `log_msg` at every call site.** The
   alias keeps `log_fn` working, but new code should use `log_msg`
   directly.
   *Current state: `log_fn` remains a supported alias; the migration
   is opportunistic (when a caller is edited for other reasons).*

4. **Reducing `functions.sh` itself.** After Layer 0 was extracted,
   `functions.sh` is still ~1,300 lines. A future ADR could split it
   further (e.g. `firewall.sh`, `backup.sh`), but the current split
   is the one that pays for itself most clearly.
   *Current state: single Layer-1 file.*

---

## Implementation record

| Item | Value |
|---|---|
| Phase | 0 (add-only) |
| Files added | 1 (`proxy/boot-mini.sh`) |
| Files modified | 6 (`proxy/functions.sh`, `proxy/customize.sh`, `scripts/package_module.sh`, `Makefile`, `.github/workflows/ci.yml`, `README.md`) |
| Files that did **not** change | 6 caller scripts (`service.sh`, `action.sh`, `status.sh`, `watchdog.sh`, `uninstall.sh`, `post-fs-data.sh`) |
| Caller behavior change | none |
| Boot-path risk | none (add-only) |
| CI check | `.github/workflows/ci.yml` Step 9 "Verify boot-mini.sh integration" |
| Local check | `make check-boot-mini` |

**Enforcement identifiers** (used in CI logs and commit messages):

- `LB-0-PRIM-1` — `boot-mini.sh` missing one of the 5 primitives
- `LB-0-PRIM-2` — `boot-mini.sh` missing `_MONITORING_UI_PORT`
- `LB-1-SRC-1` — `functions.sh` does not source `boot-mini.sh`
- `LB-1-REDEF-1` — `functions.sh` redefines a Layer-0 primitive
- `LB-1-REDEF-2` — `functions.sh` redefines `_MONITORING_UI_PORT`

---

## References

### Internal

- [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §3.12 — Layered Bootstrap
- [`README.md`](../README.md) — "Shell library layout" section
- [`proxy/boot-mini.sh`](../proxy/boot-mini.sh) — Layer 0 implementation
- [`proxy/functions.sh`](../proxy/functions.sh) — Layer 1 implementation
- [`proxy/customize.sh`](../proxy/customize.sh) §[9], §[10] — ZIP
  extraction and critical-file check
- [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) Step 9 —
  enforcement
- [`Makefile`](../Makefile) — `check-boot-mini` target

### External

- **ShellCheck SC2317** —
  [return-or-exit idiom](https://github.com/koalaman/shellcheck/wiki/SC2317)
  (used in `boot-mini.sh` for the `return 1 2>/dev/null || exit 1`
  pattern; the "return if sourced, exit if run directly" idiom has no
  clean ShellCheck-compatible form and is disabled at the exact line).

### Related ADRs

- **ADR-0007 — External dependency policy.** Uses the same "single
  source of truth" reasoning for the Go dependency graph that this ADR
  applies to the shell library.

---

*End of ADR-0008.*
