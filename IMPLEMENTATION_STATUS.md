# IMPLEMENTATION STATUS

Last updated: 2026-08-18
Repository: `Mikayilzade/organism-cargo`

## Master state
- Design migrated: **YES**
- Design freeze authority present: **YES — exact copied canon verified**
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

## Phase 12A progress — increment 1

Implemented the first recoverable technical bootstrap increment directly from the frozen `TECHNICAL_SPEC.md`:

- Added `project.godot` targeting the frozen Godot 4.7.1 / typed-GDScript implementation direction and 1280×800 baseline viewport.
- Added the minimal runnable presentation shell at `scenes/shell/shell.tscn` with `src/app/shell.gd`; it deliberately owns no authoritative gameplay state.
- Established authoritative simulation code under `src/sim`, separate from scene/Node presentation code.
- Added `src/sim/fixed_math.gd` with the canonical `FIXED_SCALE = 1000` foundation and explicit non-negative floor / signed-toward-zero helpers.
- Added `src/sim/model/simulation_input.gd` as the first typed domain/API value object containing compatibility identity (`content_version`, `rules_version`, contract, route and seed).
- Added `src/sim/checksum/canonical_checksum.gd` with deterministic ordered bootstrap serialization and SHA-256 checksum support.
- Added `tests/unit/bootstrap_test_runner.gd`, a Godot headless `SceneTree` test executable covering fixed-point examples, canonical serialization/checksum stability and typed SimulationInput construction.

## Phase 12A progress — increment 2

Established the next required 12A boundaries without populating or redesigning gameplay content:

- Added `src/content/content_document.gd` as the initial UTF-8 JSON content boundary. It rejects malformed/non-object JSON, missing or wrong-typed schema/version/kind/id/payload headers, unsupported old schema values, blank stable identifiers and unexpected content kinds.
- Added `src/save/save_envelope.gd` as a deterministic persistence envelope skeleton. Profile/session/settings payloads can be separated by `kind`; payload JSON is serialized with sorted keys/full precision and protected by SHA-256 before acceptance. This is deliberately an envelope/validation layer only; atomic primary/tmp/backup installation remains a later persistence increment.
- Added `src/ui/input_action_catalog.gd` containing the frozen remappable semantic action family and the six keyboard/controller planning focus regions (`MANIFEST`, `HOLD`, `INSPECTOR`, `ROUTE`, `OBJECTIVES_SUPPORTS`, `TOOLBAR`). This is semantic input abstraction only and does not make physical bindings authoritative.
- Added `tests/unit/boundary_test_runner.gd` covering valid/invalid content headers, expected-kind rejection, save round-trip, profile/session separation, checksum tamper rejection, required remappable action completeness and focus-region validation.
- Added `.github/workflows/headless-tests.yml`, pinned to the frozen Godot 4.7.1 stable Linux binary, to import/parse the project and run both headless test runners on pushes/PRs/manual dispatch.

## Checks performed

- Re-read the canonical Phase-11 persistence and UX/accessibility contracts before implementing their skeleton boundaries.
- Verified from the official Godot GitHub release that `4.7.1-stable` is the released maintenance baseline and that the Linux x86_64 release asset path used by CI resolves from the official release.
- Attempted to download/run Godot 4.7.1 inside the current execution container; outbound DNS is unavailable there, so the engine could not be executed locally.
- Committed a repository-native GitHub Actions execution path specifically to close that validation gap. The workflow definition now performs engine version reporting, project import/parse, bootstrap tests and the new boundary tests.
- No gameplay/content rules were invented or changed.

## Current blockers

- No design blocker.
- Validation gap remains until one real Godot 4.7.1 workflow/local run is observed and any parser/type/test failures are repaired. The repository now contains the execution path rather than only an unexecuted test suite.

## NEXT ACTION

**Continue Phase 12A — observe/repair real Godot validation, then complete the first durable persistence and content-loading path.**

On the next implementation run:
1. inspect the `Godot Headless Tests` workflow result for the latest main commit (or execute the same commands under an available Godot 4.7.1 runtime); repair every parser/type/test failure before advancing;
2. once green, add file-backed content loading/duplicate-ID rejection plus a tiny bootstrap fixture set only sufficient to exercise the loader, not full game content;
3. implement the first atomic persistence store skeleton (`tmp` -> parse/checksum verify -> replace primary while retaining backup generation) with profile/session/settings kept separate, following `PHASE11_TECH_PERSISTENCE.md`;
4. add focused headless tests for primary/backup selection, tampered envelope rejection and settings isolation;
5. update this file with exact commands/results and the next 12A increment.

Do not mark 12A complete until the project boots cleanly and deterministic tests actually execute successfully under Godot 4.7.1.
