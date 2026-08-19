# IMPLEMENTATION STATUS

Last updated: 2026-08-19
Repository: `Mikayilzade/organism-cargo`

## Master state
- Design migrated: **YES**
- Design freeze authority present: **YES**
- Autonomous implementation handoff: **YES**
- Implementation started: **YES**
- 12A Technical bootstrap: **IN PROGRESS**
- 12B Vertical slice: **NO**
- 12C Core systems: **NO**
- 12D Content population: **NO**
- 12E UX/accessibility/controller/Deck: **NO**
- 12F Adversarial QA: **NO**
- 12G Empirical gates: **NO**
- 12H Release candidate: **NO**
- IMPLEMENTATION COMPLETE: **NO**

## Phase 12A completed increments

### Increment 1
- Added `project.godot`, runnable shell, deterministic simulation code boundary, fixed-point math foundation, typed `SimulationInput`, canonical checksum helper, and bootstrap headless tests.

### Increment 2
- Added JSON `ContentDocument`, deterministic `SaveEnvelope`, semantic input action catalog, boundary tests, and a Godot 4.7.1 GitHub Actions headless-test workflow.

### Increment 3
- Added stable-order file-backed content loading, bootstrap fixtures, atomic profile/session/settings save generations, backup recovery, and storage/content tests.

### Increment 4
- Performed a focused Godot typing compatibility pass without changing gameplay or persistence semantics.

### Increment 5
- Tightened strict-warning typing across bootstrap, boundary, content, and storage code for Godot 4.7.1.

### Increment 6
- Repaired JSON numeric schema-version normalization and checksum canonicalization; added fractional-schema and numeric payload regressions.

### Increment 7
- Repaired the remaining strict-warning storage test boundary by typing known payload arrays explicitly.

### Increment 8
- Added deterministic typed `ContentRegistry`, canonical top-level `AppStateMachine`, composition tests, and CI coverage.

### Increment 9
- Added `AppBootstrapService` as the composition root, required canonical core-family validation, safe fatal-content boot behavior, persistent-shell wiring, and bootstrap composition coverage.

### Increment 10
- Added direct persistent-shell headless smoke boot to CI so the configured main scene must execute, not merely parse.

### Increment 11
- Added `src/run/launch_commit_service.gd` as the first persistence-backed boundary for the frozen exactly-once Launch contract without yet claiming the Phase-12B gate.
- Launch requests first recover an already durable committed run for the same planning revision, so duplicate callbacks return the existing `run_id` and cannot allocate a second attempt.
- New commits require `LAUNCH_CONFIRM`, structural legality, non-empty launch/revision/profile/contract/version identities, canonical committed input, SHA-256 committed-input checksum, one allocated run identity, and successful atomic `session` persistence before transition to `TRANSIT_PLAYBACK`.
- Added deterministic injected run-ID allocation for tests while production defaults to 128 bits from Godot `Crypto`.
- Added `tests/unit/launch_commit_test_runner.gd` covering structural rejection, durable commit-before-transit ownership, persisted checksum/identity/lifecycle fields, duplicate callback idempotency, and rejection of a different revision once transit owns the app state.
- Extended the existing single CI workflow with the Launch commit suite; no additional workflow was created, preserving the anti-spam rule.
- No transit mechanic, gameplay content, campaign rule, or UX behavior was invented or simplified.

### Increment 12
- Tightened the durable Launch record against the exact Phase-11 persistence minimum instead of broadening into transit before the 12A runtime gate is proven.
- `LaunchCommitService` now requires a non-empty expected contract-definition checksum, persists it explicitly, and records a recovery-only Unix launch timestamp.
- Canonical committed input now includes contract identity plus rules/content/generator compatibility versions and the expected contract-definition checksum before SHA-256 is computed, so the durable checksum covers the compatibility identity required for deterministic reconstruction rather than only the caller's layout payload.
- Extended the Launch regression suite to reject missing contract-definition identity and to verify the complete canonical committed-input/checksum boundary and recovery timestamp.
- Explicit `bool(...)` conversion was added at dictionary-to-typed-test boundaries to avoid strict-warning Variant ambiguity under the Godot 4.7.1 CI policy.
- No gameplay rule, content, transit behavior, or UX flow changed.

### Increment 13
- Inspected the actual Increment-12 GitHub Actions run `32208704474`: project import, persistent-shell smoke boot, bootstrap, boundary, storage/content, and composition all passed under Godot 4.7.1; only the exactly-once Launch suite failed.
- Root cause was persistence representation drift, not gameplay logic: Godot's JSON round-trip normalized integral JSON numbers inside committed input to floats, so the in-memory pre-save Dictionary no longer compared/serialized identically after reload.
- `LaunchCommitService` now normalizes authoritative committed input through the same JSON representation used by persistence before computing the committed-input checksum and before writing the durable record.
- Launch regression coverage now verifies the normalized persisted record and proves that the reloaded canonical committed input recomputes exactly the stored checksum.
- This preserves the Phase-11 reconstruction invariant that committed input plus its checksum remains self-consistent after persistence/reload; no gameplay or persistence policy was redesigned.

## Checks performed
- Re-read `IMPLEMENTATION_START_HERE.md`, this live status, `AUTONOMY_RULES.md`, `DESIGN_STATUS.md`, `PHASE11_FINAL_FREEZE.md`, and the exact Launch/persistence authority in `PHASE11_TECH_PERSISTENCE.md` before implementation.
- Inspected current `main` at `fe8abfe415b29c3bcbd32ff576442bfcecfcd668` and the single Actions run it produced.
- Confirmed Godot 4.7.1 passed project import, persistent-shell smoke boot, bootstrap deterministic tests, content/persistence boundary tests, storage/content tests, and content-registry/app-state composition tests.
- Confirmed the first and only concrete failure was `tests/unit/launch_commit_test_runner.gd`: persisted JSON numbers reload as floats (`17.0`, `[1.0, 2.0]`) while the test expected the pre-save integer Variant tree.
- Repaired that persistence-normalization boundary in source and regression tests as one coherent checkpoint; no repeated speculative push is performed in this run.

## Current blockers
- No design blocker.
- 12A remains open until the single CI run from Increment 13 proves the repaired exactly-once Launch suite green together with the already-green import/smoke/bootstrap/boundary/storage/composition steps.
- Production core content remains intentionally absent at this stage; the shell's safe `FATAL_CONTENT_ERROR` path remains correct until deliberately tiny canonical vertical-slice content is introduced.

## NEXT ACTION
**Continue Phase 12A — inspect the single Godot Headless Tests run produced by Increment 13; if all steps are green, record the evidence, mark 12A COMPLETE, set 12B Vertical slice IN PROGRESS, and begin the smallest canonical PlanningSession -> validation -> LaunchConfirm path. If anything fails, repair only the first concrete failure as one coherent batch.**

Next run:
1. inspect the newest single Actions run for the Increment-13 checkpoint;
2. if any step fails, repair the first concrete parser/type/API/test blocker and leave later failures to the following run;
3. if every step is green, mark `12A Technical bootstrap: COMPLETE` with concrete run evidence and set `12B Vertical slice: IN PROGRESS`;
4. then read the exact planning/validation authorities required by the freeze before implementing the smallest editable PlanningSession -> validation -> LaunchConfirm ownership layer around the durable Launch service;
5. do not populate broad content, simulate transit early, redesign frozen gameplay, or bypass fatal-content validation for convenience.

Do not mark 12A complete until the project boots coherently, deterministic tests execute successfully under Godot 4.7.1, and the frozen domain model has a stable composition root.
