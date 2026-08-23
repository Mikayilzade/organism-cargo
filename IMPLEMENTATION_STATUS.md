# ORGANISM CARGO — IMPLEMENTATION STATUS

Last updated: 2026-08-23
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

## Current implementation checkpoint — Increment 140

### Phase / subsystem
**12C Core Systems — establish deterministic T02 Heat Sink primitive**

### Entry validation
- Repository `main` at start: `dfd52f07fd5013f59946d236784aadbe4e4501c9` (`12C: bind T01 into production transit`).
- Explicit `organism-cargo/godot-headless` status for Increment 139: **SUCCESS**, workflow run `32659850883`.
- T01 production composition is therefore preserved as green authority.

### Implemented in Increment 140
- Added `T02HeatSinkKernel` as deterministic Phase-C living heat-sink authority.
- T02 removes heat only from the organism's current occupied cells and never below zero.
- Each organism has one total per-tick sink capacity across its entire current footprint; larger footprints do not multiply authored capacity.
- Capacity is restricted to frozen sink bands `2/3/4` (weak/standard/strong).
- Multiple T02 organisms resolve in stable `instance_id` order; occupied cells resolve in stable cell-key order, making finite-capacity allocation deterministic and replayable.
- Sleep does not implicitly disable the sink. Only definitions with explicit `sleep_gated=true` turn T02 off while `ASLEEP`, matching frozen sleep semantics.
- State gates use only canonical awake states and invalid definitions/runtime identities fail closed.
- Causal evidence records exact cell, before/after heat, removed amount, tick, phase and stable event ID.
- Added focused headless contract coverage for local capacity, multi-cell shared capacity, ordering determinism, explicit sleep gating and invalid capacity rejection.
- Added the T02 primitive contract to the existing notification-safe headless suite.

### Files changed
- `src/sim/t02_heat_sink_kernel.gd`
- `tests/unit/t02_heat_sink_kernel_test_runner.gd`
- `.github/workflows/headless-tests.yml`
- `IMPLEMENTATION_STATUS.md`

### Validation performed / available
- Increment 139 explicit custom headless status verified **SUCCESS** before work.
- Static review confirms the primitive is Phase-C only, local, bounded, integer-only and deterministic.
- Static review confirms multi-cell sinks share one total capacity instead of multiplying it per occupied cell.
- This checkpoint requires one authoritative GitHub Godot 4.7.1 headless run; no second speculative push is stacked in this increment.

### Deliberately not changed
- No frozen gameplay/design files.
- No T01/S01/H01/H05 production ordering changes.
- T02 is not yet bound into the production transit composition in this increment.
- No T03/T04 implementation and no 12D+ work.

### Blockers / deferred known work
- **No user-action blocker.**
- 12C remains incomplete.
- Increment 140 requires authoritative headless validation.

### Canonical contradictions
- **NONE discovered.** T02 maps directly to frozen `removes heat locally up to capacity` semantics and source/sink magnitude bands.

## NEXT ACTION
At the start of the next run, query current `main` and explicit `organism-cargo/godot-headless` status for Increment 140.

- If the workflow fails, inspect the first exact compile/runtime/assertion failure in `t02_heat_sink_kernel_test_runner.gd` and make one focused repair batch only.
- If the workflow is green, bind authored `t02_definitions` into the same production Phase-C heat composition as T01, before powered S01 mitigation and before Phase-D H05/thermal propagation, while preserving existing T01/S01/H01/H05 behavior.
- Production T02 integration must read current post-Phase-B organism runtime, write causal events into the checksum-visible Phase-C environmental event stream, and prove deterministic interaction with T01, S01 and H05.
- After T02 production binding is green, continue the frozen foundation gap with T03 Alarm Emitter, then T04 Soother.
- Do not begin 12D, 12E or later phases until the complete 12C exit gate is satisfied and recorded.
