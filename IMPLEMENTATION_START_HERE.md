# ORGANISM CARGO — IMPLEMENTATION START HERE

Status: DESIGN FROZEN / IMPLEMENTATION NOT STARTED

This repository is the implementation home for Organism Cargo. The design is already complete. Implementation must follow the frozen design rather than inventing or casually simplifying gameplay.

## Required read order
1. `STATUS.md`
2. `PHASE11_FINAL_FREEZE.md`
3. `GAME_BIBLE.md`
4. `PHASE11_FREEZE.md`
5. `MECHANICS.md`
6. `DECISION_ARCHITECTURE.md`
7. `CONTENT_ARCHITECTURE.md`
8. `PHASE11_TECH_PERSISTENCE.md`
9. `PHASE11_UX_ACCESSIBILITY.md`
10. `PHASE11_PROGRESSION.md`
11. `TECHNICAL_SPEC.md`
12. `UX_ARCHITECTURE.md`
13. `ECONOMY_COMMERCIAL.md`
14. `PHASE4_CLOSURE.md`
15. `WHOLE_GAME_SIMULATION.md`
16. `ADVERSARIAL_REVIEW.md`

When files disagree on implementation-sensitive behavior, obey the authority order in `PHASE11_FINAL_FREEZE.md`.

## Autonomous implementation protocol
A continuation prompt means: read the current implementation status, perform the next substantial verifiable increment, test it, commit it, and update implementation status before ending. Never leave important state only in chat.

One run is not one phase. A phase may require multiple runs. Prefer a working, testable increment over a large partially implemented batch.

## Phase 12 implementation ladder

### 12A — Technical bootstrap
Create the engine/project structure, data model, deterministic simulation foundation, input abstraction, persistence skeleton, test harness, and minimal runnable shell.

Exit gate: project boots cleanly and automated tests can run.

### 12B — Vertical slice
Implement one complete playable contract: planning -> cargo placement -> Launch -> deterministic transit -> success/failure -> Causal Review -> targeted Retry.

Use a deliberately tiny content subset. Do not populate the full game yet.

Exit gate: the complete loop is playable and its simulation result is deterministic from committed inputs.

### 12C — Core systems complete
Implement all frozen simulation rules and their interactions, including growth, stress, sleep, hazards, supports, adjacency, causal ancestry, blocked-growth semantics, Brownout/tick ordering, launch idempotency, result idempotency, and persistence/recovery.

Exit gate: canonical mechanical acceptance tests pass.

### 12D — Content population
Populate the frozen 22-species roster, supports, campaign C01–C48, Challenge content, demo mapping, and data-driven balance/content definitions.

Exit gate: campaign prerequisite graph and launch content ceilings validate automatically.

### 12E — UX / accessibility / controller / Deck
Implement onboarding, planning UI, transit feedback, Causal Review, menus/settings, keyboard-only, controller-only, Steam Deck 1280x800, remapping, reduced motion/flashing, UI scaling, non-color and non-audio equivalents.

Exit gate: every required gameplay path passes frozen accessibility/input acceptance criteria.

### 12F — Adversarial QA
Attack saves, duplicate Launch, recovery, corrupted/legacy state, impossible layouts, campaign locks, generated challenge validity, dominant strategies, targeted Retry, cloud/profile merge behavior, and hostile edge cases.

Exit gate: no known spec-breaking blocker remains.

### 12G — Empirical design gates
Prototype/playtest the frozen empirical gates from `PHASE11_FINAL_FREEZE.md`. These are validation obligations, not permission to redesign casually.

If a gate fails, record exact evidence and reopen only the minimum affected canonical design rule before changing gameplay.

### 12H — Release candidate
Performance, packaging, regression, demo build, store/achievement integrations if frozen in scope, final save compatibility, and release checklist.

Exit gate: `IMPLEMENTATION COMPLETE = YES` only after build, tests, QA and release-candidate criteria are satisfied.

## Hard rules
- Do not change gameplay because implementation is inconvenient.
- Do not add new species, supports, currencies, modes, platforms, multiplayer, monetization systems or core mechanics without a deliberate canonical design amendment.
- Keep simulation logic deterministic and testable outside presentation where possible.
- Make content data-driven where the frozen specification permits it.
- Every run must update implementation status with exactly what changed, tests run, failures, and next action.
- Commit only working coherent increments when possible.
- If a run cannot finish a risky migration, preserve a recoverable state and document the exact blocker.

## Recommended implementation status file
Create and maintain `IMPLEMENTATION_STATUS.md` from the first implementation run. Keep design `STATUS.md` as frozen design history; implementation progress belongs in the new status file.

## Completion condition
Do not report the game finished merely because all systems exist. Completion requires implementation, content, UX/accessibility, persistence, adversarial QA, empirical gates, regression and a release candidate to be complete.
