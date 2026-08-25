# ORGANISM CARGO — IMPLEMENTATION STATUS

Last updated: 2026-08-25
Repository: `Mikayilzade/organism-cargo`
Branch: `main`

## Master state
- Design frozen: **YES**
- Canonical implementation authority: **`PHASE11_FINAL_FREEZE.md` + frozen authority chain**
- 12A Technical Bootstrap: **COMPLETE**
- 12B Vertical Slice: **COMPLETE**
- 12C Core Systems: **COMPLETE**
- 12D Content Population: **COMPLETE**
- 12E UX / Accessibility / Controller / Deck: **COMPLETE**
- 12F Adversarial QA: **IN PROGRESS**
- 12G Empirical Gates: **NO**
- 12H Release Candidate: **NO**
- IMPLEMENTATION COMPLETE: **NO**

## Current implementation checkpoint — Increment 191

### Phase / subsystem
**12F adversarial persistence — compatibility recovery class D + retained-legacy reconstruction acceptance**

### Repository truth / entry validation
- Re-read `IMPLEMENTATION_START_HERE.md`, `IMPLEMENTATION_STATUS.md`, `AUTONOMY_RULES.md`, `DESIGN_STATUS.md`, `PHASE11_FINAL_FREEZE.md`, then the exact current authority `PHASE11_TECH_PERSISTENCE.md`.
- Entry head: `23c824acedba2b8c4318c4764a0ba193771aeafd` (Increment 190).
- Inspected the exact Increment-190 push runs on that SHA. All three required workflows completed successfully: `Phase 12F Persistence Adversarial` run `32837107804`, `Godot Headless Tests`, and `Content Population Validator`.
- Reconciled the dedicated 12F persistence coverage against `PHASE11_TECH_PERSISTENCE.md` section 12 and the checksum-mismatch policy in section 4.
- Found one concrete uncovered production invariant: `_validate_compatibility()` already classified missing/incorrect compatibility as recovery class D, but `resume_current()` only persisted class C quarantine. A class-D Continue could therefore return an error without durably invalidating the obsolete run or retaining an explicit editable planning baseline, contrary to the canonical missing-compatibility behavior.

### Implemented in Increment 191
- Extended `TransitReconstructionService.resume_current()` with explicit recovery-class-D handling.
- When an in-progress run references a rules/content/contract package that cannot reconstruct it exactly, the service now:
  - refuses to simulate under the supplied current-but-different package;
  - preserves the immutable old `run_id` and `canonical_committed_input` for diagnostics/history;
  - durably changes lifecycle to `ABANDONED/INVALIDATED`;
  - stores an exact `planning_baseline` clone of the committed layout;
  - records the compatibility failure reason and `restart_under_current_version_required = true`;
  - returns the truthful recovery action `restart_from_committed_layout_under_current_version`;
  - does not fabricate a final-result checksum or old outcome.
- Added `phase12f_compatibility_recovery_adversarial_test_runner.gd` and wired it into the single existing hard-fail persistence workflow.
- The new runner attacks both sides of the compatibility boundary:
  - a retained exact legacy rules/content/contract package reconstructs the old committed run deterministically and preserves its run identity;
  - a missing legacy package represented by current-but-different compatibility enters class D, durably invalidates only the resumable session, preserves the exact committed layout as restart baseline, does not fabricate an outcome, and cannot silently resume again.
- The class-D attack also seeds permanent Bronze/Gold/completion-ledger profile state and proves session invalidation cannot roll historical permanent progression back.
- No gameplay mechanic, simulation phase, checksum algorithm, campaign graph, content definition, medal rule or save schema was redesigned.

### Validation / policy
- Increment-190 dedicated persistence CI, broad Godot headless CI and content validation are green before this change.
- Static review traces the new behavior directly to `PHASE11_TECH_PERSISTENCE.md` section 4 class D and section 12 reconstruction acceptance.
- The new focused runner is added to the existing persistence workflow rather than creating another workflow surface.
- This runtime has no local Godot 4.7.1 binary. Fresh GitHub Actions from this single Increment-191 checkpoint are the executable validation path.
- All meaningful code/test/workflow/status changes are batched into one checkpoint commit/push.

### Blockers / cautions
- No user-action blocker.
- Fresh Increment-191 CI must confirm Godot 4.7.1 parsing and all four dedicated persistence attack runners together.
- Persistence acceptance should be reconciled one final time after CI; any still-uncovered canonical invariant must be covered before leaving this domain.
- 12F remains incomplete; do not begin 12G yet.

### Canonical contradictions
- **NONE discovered.**

## NEXT ACTION
At the start of the next run, inspect the exact Increment-191 `Phase 12F Persistence Adversarial`, `Godot Headless Tests`, and `Content Population Validator` workflows.

If any executable workflow is red, inspect the first exact executable failure and make one focused repair batch only; do not stack speculative fixes.

If all executable workflows are green:
1. perform a final line-by-line reconciliation of the mandatory persistence acceptance list in `PHASE11_TECH_PERSISTENCE.md` against the four dedicated 12F runners plus already-green broad persistence tests; cover any remaining concrete gap in one coherent batch;
2. if persistence acceptance is exhausted, move immediately to a substantial non-persistence 12F adversarial cluster: hostile state-machine/UI event ordering plus impossible/edge planning layouts and campaign/content lock-bypass attempts, reading the frozen authority chain for those exact subsystems first;
3. keep 12G blocked until 12F has no known specification-breaking blocker.

Do not report overall completion until `IMPLEMENTATION COMPLETE = YES`.
