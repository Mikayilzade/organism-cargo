# ORGANISM CARGO — IMPLEMENTATION STATUS

Last updated: 2026-08-22
Repository: `Mikayilzade/organism-cargo`
Branch: `main`

## Master state
- Design frozen: **YES**
- Canonical implementation authority: **`PHASE11_FINAL_FREEZE.md` + frozen authority chain**
- 12A Technical Bootstrap: **COMPLETE**
- 12B Vertical Slice: **COMPLETE**
- 12C Core Systems: **IN PROGRESS**
- 12D Content Population: **NO**
- 12E UX / Accessibility / Controller / Deck: **NO**
- 12F Adversarial QA: **NO**
- 12G Empirical Gates: **NO**
- 12H Release Candidate: **NO**
- IMPLEMENTATION COMPLETE: **NO**

## Current implementation checkpoint — Increment 96

### Phase / subsystem
**12C Core Systems — H05 Vent Cycle production Phase-D integration boundary**

### Repository truth read before work
This run re-read the mandatory recovery chain before implementation:
- `IMPLEMENTATION_START_HERE.md`
- `IMPLEMENTATION_STATUS.md`
- `AUTONOMY_RULES.md`
- `DESIGN_STATUS.md`
- `PHASE11_FINAL_FREEZE.md`
- current-subsystem canon: `GAME_BIBLE.md`, `MECHANICS.md`, `TECHNICAL_SPEC.md`

The relevant frozen rule remains: H05 is not a fourth environmental channel. It modifies the existing Phase-D decay/venting authority for only the already-enabled frozen channels: Heat, Stress field and Contamination. Phase D still propagates from a common source snapshot, then applies decay/venting, clamps and publishes exposure.

### Entry validation
- Increment 95 checkpoint: `e173df4bc8ae361f37ed825abb475c701977024f` (`12C: add deterministic H05 vent modifier primitive`).
- Latest observable `organism-cargo/godot-headless` status for Increment 95: **SUCCESS**, workflow run `32562560036`.
- Therefore the run followed the prior `NEXT ACTION` success branch rather than repairing CI.

### Implemented in Increment 96
- Added `src/sim/phase_d_environment_resolver.gd` as the shared deterministic production Phase-D boundary for the three frozen spatial channels.
- The resolver consumes the active tick hazard set plus the already-authored Phase-D rules and uses `H05VentCycleKernel` exactly once to derive effective tick-local vent/decay maps.
- Heat retains the existing `thermal_rules.vent_by_cell` authority; H05 modifies that map before `ThermalResponseKernel.propagate_heat`.
- Contamination retains the existing `contamination_rules.vent_by_cell` authority; H05 modifies that map before `ContaminationEnvironmentKernel.propagate_phase_d`.
- Stress field retains its existing `stress_field_rules.decay_by_cell` authority. The shared boundary maps that existing decay field into the H05 vent-authority vocabulary and maps the effective value back to `decay_by_cell` before `StressFieldEnvironmentKernel.propagate_phase_d`; no new stress mechanic or channel was introduced.
- The shared boundary rejects missing/unknown channels, negative authored Phase-D vent/decay values, and any H05 attempt to create a channel not enabled by the caller.
- It preserves deterministic H05 event evidence and exposes H05 authority payload/checksum plus a final Phase-D environment authority payload/checksum suitable for inclusion in transit tick checksums.
- Extended the already-wired `tests/unit/h05_vent_cycle_kernel_test_runner.gd` rather than adding another CI workflow. Existing H05 primitive tests remain and new production-boundary acceptance covers all three channels.
- Added an inactive-H05 equivalence fixture that runs the same generated fields through the new boundary and directly through each existing Phase-D kernel, requiring exact dictionary equality for Heat, Stress field and Contamination.
- Added active-H05 acceptance proving the same authored H05 changes the published Phase-D exposure of all three enabled channels and produces deterministic evidence/checksum material.

### Files changed
- `src/sim/phase_d_environment_resolver.gd` — new shared deterministic Phase-D/H05 composition boundary.
- `tests/unit/h05_vent_cycle_kernel_test_runner.gd` — expanded primitive + production-boundary acceptance.
- `IMPLEMENTATION_STATUS.md` — this recoverable checkpoint and exact continuation instruction.

### Validation performed / available
- Entry checkpoint CI was verified green before changes: `organism-cargo/godot-headless = success` for `e173df4bc8ae361f37ed825abb475c701977024f`.
- The existing GitHub workflow already executes `tests/unit/h05_vent_cycle_kernel_test_runner.gd`; no extra workflow or notification source was created.
- This environment has no working direct network clone/runtime checkout, so the new GDScript cannot be truthfully reported locally executed before the checkpoint. The single checkpoint push will trigger the existing headless suite; its result must be inspected at the start of the next autonomous run before further normal commits.

### Deliberately not changed
- No gameplay/canonical design files.
- No fourth channel, new hazard family, species, support, currency or progression rule.
- No H06 Zone Isolation implementation.
- No T10 Reactive Pulse implementation.
- No fixture-only S05 production support change.
- No S03 directed-interceptor runtime binding.
- No speculative additional CI workflow.

### Remaining H05 integration work
The new boundary is production-grade and tested through the existing H05 test runner, but the current transit runners still call the individual Phase-D kernels directly. The next increment must wire this shared resolver into those existing transit execution paths, then place its H05 events in tick snapshots/result evidence and append its authority payload/checksum material to per-tick replay checksums. In particular, `transit_power_integrated_runner_base.gd` must strip H05 from the legacy `TransitSliceRunner` delegation (which only accepts H01) and handle it at the shared Phase-D boundary; `transit_stress_field_integrated_runner.gd` must consume the same tick-effective stress-field decay authority rather than a static rule map.

### Blockers / deferred known work
- **No user-action blocker.**
- Current implementation is intentionally incomplete: 12C remains in progress.
- Existing deferred items from prior checkpoints remain deferred unless a later `NEXT ACTION` selects them: fixture-only S05 production path, S03 directed-interceptor binding, remaining S04 composition edges, H06, T10 and subsequent complete A–I integration/acceptance.

### Canonical contradictions
- **NONE discovered.** The H05 integration boundary preserves the frozen rule that Vent Cycle modifies environmental decay/venting without creating a new simulation system.

## NEXT ACTION
At the start of the next run, first query current `main` and the latest `organism-cargo/godot-headless` status for this Increment-96 checkpoint. If the workflow failed, inspect the first concrete failure and make one focused repair checkpoint only; do not broaden scope.

If green, continue the same **12C / H05 production integration** and finish the runner wiring in one coherent batch:
1. route active H05 hazards through `PhaseDEnvironmentResolver` inside the production heat/contamination Phase-D execution path;
2. exclude H05 from the legacy `TransitSliceRunner` delegated hazard set so the base H01-only validator is not asked to own H05;
3. route the production stress-field Phase-D path through the same resolver/effective `decay_by_cell` authority for ticks where that channel is enabled;
4. persist deterministic `H05_VENT_MODIFIED` events and effective vent/decay evidence in end-tick snapshots/result evidence;
5. include H05/Phase-D authority material in every affected tick checksum;
6. add focused end-to-end production fixtures proving an active H05 changes exposure/checksum and an inactive H05 preserves prior production output byte-equivalent where applicable.

Do not begin H06, T10, fixture-only S05, S03 directed runtime binding, 12D, 12E or later phases until this H05 runner integration checkpoint is green and the subsequent exact `NEXT ACTION` selects the next subsystem.
