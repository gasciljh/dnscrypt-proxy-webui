# ADR-0003: Layered Bootstrap

**Status**: ✅ Accepted (extended in v1.6.0 — 2-layer → 3-layer)
**Date**: 2026-10-15
**Consolidated**: 2026-10-19 (v1.5.0 Global Edition — renumbered from ADR-0008)
**Extended**: 2026-11-12 (v1.6.0 Global Edition — `lib/` modularization)
**Authors**: [@gasciljh](https://github.com/gasciljh)
**Supersedes**: —
**Superseded by**: —

> **v1.6.0 note**: This ADR was **extended**, not superseded. The original
> v1.5.0 decision (separate bootstrap primitives from runtime orchestrators)
> remains **fully valid**. v1.6.0 refined it by splitting the "Layer 0"
> monolith (`boot-mini.sh`) into 6 single-purpose modules under `lib/`, and
> promoting `boot-mini.sh` to a Layer 1 aggregator. See §"Extension (v1.6.0)"
> below for the current 3-layer model. The v1.5.0 sections (Context, Decision,
> Consequences) are preserved verbatim as historical record.

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

> **Reproducibility note**: these counts were measured against the `v1.4.0`
> tag before the v1.5.0 consolidation. A future reviewer can verify the
> original duplication with:
>
> ```bash
> git grep -c 'rotate_backups' v1.4.0 -- '*.sh'
> git grep -c 'is_port_open'   v1.4.0 -- '*.sh'
> ```
>
> The current tree no longer contains the duplication — it was removed by
> this ADR.

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

## Decision (v1.5.0 baseline)

Adopt the Layered Bootstrap pattern: exactly two layers with a strict dependency
direction (Layer 1 sources Layer 0; nothing else).

**Layer 0 — `boot-mini.sh`** (~285 lines, ~90 executable)

- Contains exactly **five primitives** and **one constant**:
  `log_msg`, `get_run_dir`, `read_conf`, `is_port_open`, `get_webui_port`,
  `_MONITORING_UI_PORT`.
- Zero dependencies (BusyBox / toybox built-ins only).
- Always present in the module ZIP; verified as a critical file by
  `customize.sh` §[16].

**Layer 1 — `functions.sh`**

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
- ✅ v1.5.0 evidence: the `apk/` mirror skip in `customize.sh` §[27] was
  applied consistently across all copies of `rotate_backups()` without a manual
  sweep — direct evidence of the pattern's value.

### Negative

- ❌ One more file to ship. `boot-mini.sh` must be included by
  `package_module.sh`, extracted by `customize.sh` §[12], verified by §[16],
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

## Extension (v1.6.0) — 2-layer → 3-layer

### Why the v1.5.0 model needed extension

The v1.5.0 decision reduced duplication but left `boot-mini.sh` as a
**monolith**: 5 unrelated primitives + 1 constant + the sourcing logic for
`functions.sh` in one ~285-line file. Adding a 6th primitive meant editing
`boot-mini.sh`, `functions.sh`, `ci.yml`, and 2 documentation files. Adding
a 7th meant the same 5-file sweep.

More importantly, the *concept* of "Layer 0" mixed three concerns:
1. **Constants** (`_MONITORING_UI_PORT`) — pure data.
2. **Fallback primitives** (`is_port_open`, `read_conf`) — work even if
   `functions.sh` fails.
3. **Bootstrapping** (`log_msg` setup, PATH setup, log rotation) — runs
   exactly once at boot.

These three concerns have different change frequencies, different
consumers, and different testing strategies. Bundling them violated the
same "single responsibility" principle that motivated the v1.5.0 split.

### The 3-layer model

v1.6.0 splits the v1.5.0 "Layer 0" into **6 modules** under `lib/` and
promotes `boot-mini.sh` to a Layer 1 aggregator:

**Layer 0 — `lib/*.sh` (6 single-purpose modules)**

| Module | Responsibility | Approx. size |
|---|---|---:|
| `lib/constants.sh` | Paths, ports, `_MONITORING_UI_PORT`, TOML parsers, `validate_port()` | ~130 lines |
| `lib/fallbacks.sh` | Standalone primitives (`_fb_is_port_open`, `_fb_read_conf`, etc.) | ~150 lines |
| `lib/process.sh` | `/proc`-based process management (`kill_by_comm`, `list_pids_by_comm`) | ~280 lines |
| `lib/http.sh` | Unified HTTP client (curl → wget cascade) with proxy isolation | ~280 lines |
| `lib/backup.sh` | User-data preservation, transaction management, rotation | ~550 lines |
| `lib/firewall.sh` | nftables/iptables management for DNS redirection | ~350 lines |

- Zero dependencies between modules (except documented sourcing order).
- Each module has a single, well-named responsibility.
- Each module can be tested in isolation by sourcing it alone.

**Layer 1 — `boot-mini.sh` (aggregator)**

- Sources `lib/*.sh` in a fixed order: constants → fallbacks → process →
  http → backup → firewall.
- Sets up `PATH` and the 50 MB emergency log rotation.
- Provides thin wrappers: `is_port_open() { _fb_is_port_open "$@"; }`, etc.
- **No business logic.** No `case` chains for domain logic. No
  environment-specific branching beyond what `lib/` already exposes.

**Layer 2 — `functions.sh` (orchestrator)**

- Sources `boot-mini.sh`.
- Provides every other shared function (runtime paths, cleanup functions,
  WebUI launcher, etc.).
- Unchanged from v1.5.0 — its role is identical.
- **Still does not redefine any Layer-0 primitive or constant.**

### Enforcement — extended dual guard

**CI guard (`ci.yml` Step 9)**:
- All 6 `lib/*.sh` modules present.
- `boot-mini.sh` sources them.
- `functions.sh` sources `boot-mini.sh`.
- `functions.sh` does not redefine any Layer-0 primitive.
- `_MONITORING_UI_PORT` remains the single source of truth in
  `lib/constants.sh`.

**Local guard (`make check-boot-mini`)**: same checks locally.

**Manual exception**: `boot-mini.sh §[4]` sets
`_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"` because
`lib/constants.sh` may fail to source during a partial extraction. The
fallback keeps the value defined if `lib/constants.sh` is missing or
unreadable. `customize.sh` inherits the value by sourcing `boot-mini.sh`
in §[3]. This is the **sole documented fallback**; `ci.yml` Step 10 rejects
any other redeclare.

### Consequences of the extension

**Positive**:
- ✅ Single responsibility per module. Adding a 7th primitive means adding
  a 7th `lib/*.sh` file, updating `boot-mini.sh`'s sourcing order, and
  updating `ci.yml` Step 9. No change to `functions.sh`.
- ✅ Testing isolation. A developer can `bash lib/process.sh` in a sandbox
  without booting the full chain.
- ✅ Clear layering in the source tree: `lib/` for modules, `boot-mini.sh`
  for aggregation, `functions.sh` for orchestration.
- ✅ Zero behavior change for callers. Every script that sourced
  `functions.sh` in v1.5.0 still sources it in v1.6.0 without modification.

**Negative**:
- ❌ 6 files instead of 1. Total ~1,570 lines (vs. the v1.5.0 monolith's
  ~285 lines). The net line increase reflects the clarity of separation,
  not duplication — each module is genuinely distinct.
- ❌ 6 integration points in `package_module.sh`, `customize.sh` §[12],
  `customize.sh` §[16], and `ci.yml` Step 9. All implemented.
- ❌ A new contributor reading `functions.sh` must know the 3-layer chain:
  `functions.sh` → `boot-mini.sh` → `lib/*.sh`. The file headers document
  this.

**Neutral**:
- ⚪ Module version unchanged — this is an internal refactor inside the
  v1.6.0 cycle.
- ⚪ `_MONITORING_UI_PORT` definition moved from `boot-mini.sh` to
  `lib/constants.sh`. No consumer noticed.

### Verification (v1.6.0)

```bash
# All 6 lib/ modules present
for M in constants fallbacks process http backup firewall; do
    su -c "test -f /data/adb/modules/dnscrypt-proxy-webui/lib/$M.sh" && \
        echo "✅ lib/$M.sh"
done

# Layer chain works end-to-end
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; \
       type init_runtime_paths >/dev/null 2>&1 && \
       echo '✅ 3-layer chain OK'"

# No Layer-0 primitive redefined in functions.sh
for fn in log_msg get_run_dir read_conf is_port_open get_webui_port; do
    su -c "grep -qE '^${fn}[[:space:]]*\(\)' \
        /data/adb/modules/dnscrypt-proxy-webui/functions.sh" && \
        echo "❌ $fn redefined" || echo "✅ $fn lives only in Layer 0"
done
```

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| Status quo (keep the duplication) | 7-file updates every time a primitive changes; "KEEP IN SYNC" comments are not enforced; the three historical sweeps prove the cost is real. |
| Full unification into a single `lib.sh` | If that file fails to load, every caller fails — including `post-fs-data.sh` and `uninstall.sh`, which must always run. The layered split lets each caller choose its own degradation policy. |
| Symlinks from `proxy/*.sh` to a central location | Symlinks do not survive the ZIP round-trip reliably on all Android filesystems; `unzip` behavior with symlinks is inconsistent; multiplies SELinux context failure modes. |
| Code-generation | Moves the duplication into the build system; CI must re-run the generator on every push; a developer forgetting to regenerate produces the same drift. |
| Make `functions.sh` mandatory | This is a caller policy, not a library-structure decision. Would break `post-fs-data.sh` and `uninstall.sh`. Deferred to a future ADR. |
| Verify parity between copies instead of removing them | Removing the duplication is strictly better than detecting it. |
| **v1.6.0: Keep the v1.5.0 2-layer model** | The v1.5.0 monolith's mixed concerns are exactly the kind of "KEEP IN SYNC" drift the ADR was supposed to eliminate. Extending to 3 layers is the natural next step, not a new decision. |
| **v1.6.0: Split into more than 6 modules** | Diminishing returns. 6 modules already match the natural concern boundaries. Going to 10+ would multiply the integration points without improving clarity. |
| **v1.6.0: Use a single `lib/loader.sh` that sources modules by glob** | Order matters. A glob would lose the explicit dependency order (constants → fallbacks → process → http → backup → firewall). Explicit sourcing is intentional. |
| **v1.6.0: Replace `boot-mini.sh` entirely with `lib/*.sh`** | Then `functions.sh` would have to source 6 files directly, violating the single-source-of-truth principle for the sourcing order. `boot-mini.sh` as aggregator preserves the single entry point. |

## Related Decisions

- [ADR-0002](0002-external-dependency.md) — applies the same "single source of
  truth" reasoning to the Go dependency graph.
- [ADR-0001](0001-release-workflow.md) — the release workflow that ships the
  split and enforces it in CI across release cycles.

## References

- **Code (v1.6.0)**:
  - [`lib/constants.sh`](../../lib/constants.sh),
  - [`lib/fallbacks.sh`](../../lib/fallbacks.sh),
  - [`lib/process.sh`](../../lib/process.sh),
  - [`lib/http.sh`](../../lib/http.sh),
  - [`lib/backup.sh`](../../lib/backup.sh),
  - [`lib/firewall.sh`](../../lib/firewall.sh),
  - [`boot-mini.sh`](../../boot-mini.sh),
  - [`functions.sh`](../../functions.sh).
- **Integration**: [`customize.sh`](../../customize.sh) §[3], §[12], §[16];
  [`scripts/package_module.sh`](../../scripts/package_module.sh).
- **CI guard**: [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)
  Step 9; [`Makefile`](../../Makefile) `check-boot-mini` target.
- **Narrative**: `REFERENCE.md` §1.4 (Layered Bootstrap),
  `REFERENCE.md` §3.13 (`install_app.sh` contract),
  `REFERENCE.md` §1.2 (Zero-Footprint principle),
  `CONTRIBUTING.md` §17.2, `CONTRIBUTING.md` §18.2.
- **External**: [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions).

---

*This ADR is immutable. To reverse or amend it, create a new ADR that supersedes
it and update its Status line. The v1.6.0 extension was applied as an addition
to this file (not a replacement) because the core v1.5.0 decision — separate
bootstrap primitives from runtime orchestrators — remains fully valid. Only the
"Layer 0" content was reorganized from 1 file into 6 modules. The Status line
was updated from `✅ Accepted` to `✅ Accepted (extended in v1.6.0 — 2-layer →
3-layer)` to reflect this, but no earlier decision was reversed.*

*See `docs/adr/README.md` §"Metadata vs decision" for the rule that allows
extension notes to be appended without supersession.*