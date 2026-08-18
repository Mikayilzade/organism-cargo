# ORGANISM CARGO — IMPLEMENTATION START HERE

Status: **DESIGN FROZEN / IMPLEMENTATION NOT STARTED**

This repository is the dedicated implementation home for Organism Cargo. The game design is complete and frozen. Implementation must follow the canonical design instead of inventing, silently simplifying, or replacing gameplay rules.

## Read this first on every fresh implementation session
1. `IMPLEMENTATION_START_HERE.md`
2. `IMPLEMENTATION_STATUS.md`
3. `DESIGN_STATUS.md`
4. `PHASE11_FINAL_FREEZE.md`
5. `GAME_BIBLE.md`
6. `PHASE11_FREEZE.md`
7. `MECHANICS.md`
8. `DECISION_ARCHITECTURE.md`
9. `CONTENT_ARCHITECTURE.md`
10. `PHASE11_TECH_PERSISTENCE.md`
11. `PHASE11_UX_ACCESSIBILITY.md`
12. `PHASE11_PROGRESSION.md`
13. `TECHNICAL_SPEC.md`
14. `UX_ARCHITECTURE.md`
15. `ECONOMY_COMMERCIAL.md`
16. `PHASE4_CLOSURE.md`
17. `WHOLE_GAME_SIMULATION.md`
18. `ADVERSARIAL_REVIEW.md`

Selection history (`RESEARCH.md`, `TOURNAMENT.md`, `TOURNAMENT_ROUND2.md`, `CROSS_ROUND_FINAL.md`) is non-authoritative unless the implementation task specifically needs historical rationale.

When files disagree on implementation-sensitive behavior, obey the authority order in `PHASE11_FINAL_FREEZE.md`.

## Autonomous implementation protocol
A user message such as `го`, or an hourly continuation task, authorizes exactly the next substantial implementation increment from `IMPLEMENTATION_STATUS.md`.

Every run must:
1. read the current status and required canonical files for the affected subsystem;
2. perform one substantial but recoverable increment;
3. run the most relevant automated/manual checks available;
4. keep the repository in a coherent state;
5. commit/save all meaningful work;
6. update `IMPLEMENTATION_STATUS.md` with what changed, what was tested, blockers, and the exact `NEXT ACTION`;
7. never leave critical implementation state only in chat.

One run is **not** one phase. A phase may require many runs. Prefer a smaller tested increment over a huge partially working batch.

## Phase 12 implementation ladder

### 12A — Technical bootstrap
Create the engine/project structure, deterministic simulation foundation, content/data loading, input abstraction, persistence skeleton, test harness, and minimal runnable shell.

Exit gate: project boots cleanly; deterministic unit tests can run; the frozen domain model has a clear code home.

### 12B — Vertical slice
Implement one complete playable contract with deliberately tiny content:
planning -> cargo placement -> validation -> exactly-once Launch -> deterministic transit -> success/failure -> Causal Review -> targeted Retry.

Exit gate: the complete loop is playable and the same committed input reproduces the same authoritative result.

### 12C — Core systems complete
Implement all frozen simulation rules and interactions, including tick ordering, Brownout, growth, blocked-growth episodes, stress, sleep, hazards, supports, adjacency, state transitions, cause ancestry, Launch/result idempotency, save/recovery and deterministic resume.

Exit gate: canonical mechanical acceptance tests pass and no frozen core rule is stubbed.

### 12D — Content population
Populate the frozen 22-species roster, support set, campaign C01–C48, Challenges, demo mapping and data-driven balance/content definitions.

Exit gate: exact campaign prerequisites, content ceilings, challenge validity and launch constraints validate automatically.

### 12E — UX / accessibility / controller / Deck
Implement onboarding, planning UI, transit presentation, Causal Review, menus/settings, keyboard-only, controller-only, Steam Deck 1280×800, remapping, UI scale, Reduced Motion/Flashing and non-color/non-audio equivalents.

Exit gate: every required gameplay path passes the frozen accessibility/input acceptance criteria.

### 12F — Adversarial QA
Attack saves, duplicate Launch, duplicate Results, recovery, corruption/legacy state, impossible layouts, campaign locks, generated challenge validity, dominant strategies, targeted Retry, cloud/profile merge behavior, hostile timing and edge cases.

Exit gate: no known specification-breaking blocker remains and regression coverage exists for repaired failures.

### 12G — Empirical gates / playtest validation
Validate the prototype-dependent gates in `PHASE11_FINAL_FREEZE.md`.

These are empirical obligations, not permission for casual redesign. If a gate fails, record evidence, reopen only the minimum affected canonical rule, reconcile the design deliberately, then implement the approved amendment.

### 12H — Release candidate
Performance, packaging, regression, save compatibility, demo build, required platform/store integration already in scope, release checklist and final candidate verification.

Exit gate: `IMPLEMENTATION COMPLETE = YES` only after implementation, content, UX/accessibility, persistence, QA, empirical gates, regression and release-candidate criteria are all satisfied.

## Hard rules
- Do not change gameplay because implementation is inconvenient.
- Do not add species, supports, currencies, campaign nodes, hazard families, modes, platforms, multiplayer, monetization systems or new core mechanics unless a deliberate canonical design amendment is first recorded.
- Keep authoritative simulation deterministic and testable independently from presentation wherever practical.
- Make content data-driven where the frozen specification permits it.
- Do not hide failed tests. Record the failure and either repair it in the same increment or make it the next explicit blocker.
- Do not mark a phase complete because code exists; satisfy its exit gate.
- Do not mark the project complete before `IMPLEMENTATION COMPLETE = YES`.

## Design-change protocol
If implementation reveals a real contradiction or impossible requirement:
1. stop only the affected behavior;
2. document the exact conflict and evidence;
3. identify the minimum canonical files affected;
4. amend design deliberately before changing gameplay behavior;
5. add regression/acceptance coverage for the amendment;
6. continue implementation from the updated canon.

## Status ownership
- `DESIGN_STATUS.md` is frozen design history.
- `IMPLEMENTATION_STATUS.md` is the live source of truth for Phase 12+.
- `PHASE11_FINAL_FREEZE.md` remains the highest implementation-sensitive design authority.

## Completion condition
The implementation chat may report **Завершено** only when `IMPLEMENTATION COMPLETE = YES`. Intermediate runs remain **В процессе** even when an individual phase or milestone finishes.
