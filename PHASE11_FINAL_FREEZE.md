# ORGANISM CARGO — PHASE 11 FINAL SPECIFICATION FREEZE

Status: **FINAL CANONICAL FREEZE / DESIGN COMPLETE**
Date: 2026-08-15
Production implementation started: **NO**

## Purpose

This file closes Phase 11. It adds no gameplay. It exists to remove the last editorial ambiguity between already-frozen Phase-11 supplements and older canonical-looking source text.

The game design is fully specified, internally reviewed, implementation-ready, and specification-frozen. Remaining uncertainty is empirical prototype validation only; no implementation session is expected to invent gameplay rules.

## Final authority order

For any implementation-sensitive conflict, use this precedence:

1. `PHASE11_FINAL_FREEZE.md`
2. `GAME_BIBLE.md`
3. `PHASE11_FREEZE.md`
4. `PHASE11_TECH_PERSISTENCE.md`
5. `PHASE11_UX_ACCESSIBILITY.md`
6. `PHASE11_PROGRESSION.md`
7. domain canon: `MECHANICS.md`, `DECISION_ARCHITECTURE.md`, `CONTENT_ARCHITECTURE.md`, `TECHNICAL_SPEC.md`, `UX_ARCHITECTURE.md`, `ECONOMY_COMMERCIAL.md`
8. `PHASE4_CLOSURE.md` as validation evidence
9. `WHOLE_GAME_SIMULATION.md` and `ADVERSARIAL_REVIEW.md` as validation history
10. concept-selection/research files as history only

Status banners in older files are non-authoritative where they disagree with this final freeze or `STATUS.md`.

## Final editorial overrides

These overrides are exact and finite. They supersede stale wording in older sources without creating any new mechanic.

### Technical persistence

`PHASE11_TECH_PERSISTENCE.md` is the final authority for:
- exactly-once Launch;
- one durable `run_id` per launch commit;
- deterministic `completion_id`;
- idempotent Results/progression application;
- deterministic transit reconstruction/resume;
- atomic save/recovery behavior;
- cloud/profile monotonic merge behavior;
- demo import idempotency;
- legacy compatibility failure behavior.

Authoritative transit truth is immutable committed input plus stable run identity, contract/route/layout/support configuration, seed, rules/content/generator versions, and checksums. A runtime/platform snapshot may accelerate recovery but is never the sole gameplay authority.

### Transit Continue / resume

If the player quit during transit, Continue restores the same committed run by deterministic reconstruction from authoritative committed input and saved recovery cursor/metadata, then returns to paused playback at the recovered presentation position. A platform/runtime snapshot is never the sole source of gameplay truth.

### Mandatory input/accessibility

`PHASE11_UX_ACCESSIBILITY.md` is final authority. Required gameplay must be completable through:
- mouse + keyboard;
- keyboard-only;
- controller-only;
- Steam Deck built-in controls at 1280×800.

Gameplay remapping is mandatory. No hover, right-click, mouse-wheel, drag, color-only, audio-only, flashing-only, or fine-precision-only interaction may be mandatory. Reduced Motion, Reduced Flashing, maximum UI scale, no-audio play, and non-color critical communication must preserve complete gameplay access.

Older wording such as “where practical” is superseded for required gameplay paths.

### Campaign progression

`PHASE11_PROGRESSION.md` and the exact graph in `PHASE11_FREEZE.md` / `CONTENT_ARCHITECTURE.md` are final authority.

Campaign prerequisites are Bronze-only according to the frozen C01–C48 prerequisite graph.

`ChallengeModeUnlocked := Bronze(C16) == true`.

Silver/Gold medals, achievements, challenge results, XP/currency, documented knowledge, clear-count totals, D09/D10, or imported demo knowledge do not substitute for Bronze(C16).

Demo D01–D08 may map to C01–C08 Bronze only through validated version mapping. D09–D10 never auto-clear C09+. Settings and valid documented knowledge may transfer. Mechanical power does not transfer. Import is monotonic and idempotent.

### Blocked growth

A first illegal growth attempt begins one `GROWTH_BLOCKED` episode and fires the configured consequence once on episode entry. Unchanged blocked ticks do not repeat that consequence. A new blocked-growth consequence requires a relevant legality/occupancy/orientation/body/trigger/retry-boundary change. Independent continuing sources may still alter stress or other meters.

Any older narrative implying repeated punishment from the same unchanged obstruction is validation-history shorthand and is superseded.

### Phase 9 / Phase 10 status

`WHOLE_GAME_SIMULATION.md` is Phase-9 validation history where a later canonical home exists.

`ADVERSARIAL_REVIEW.md` is Phase-10 validation history where a later canonical home exists.

Their empirical prototype gates remain active validation obligations, but historical repair wording does not outrank Phase-11 canon.

## Frozen implementation-readiness proof

A fresh implementation session has deterministic answers to all 20 required questions:

1. first boot through C48 and Challenges;
2. Launch ownership and duplicate-launch prevention;
3. unique authoritative transit identity;
4. transit resume without snapshot authority;
5. exactly-once Results/progression writes;
6. A–I tick phases and same-tick Brownout behavior;
7. simultaneous material cause ancestry;
8. unchanged blocked-growth episode behavior;
9. exact sleep suppression semantics;
10. exact C01–C48 prerequisite graph;
11. exact Challenge gate Bronze(C16);
12. exact demo transfer/non-transfer rules;
13. launch content ceilings and redundancy gates;
14. generated-challenge validity/dynamic-significance proof;
15. anti-dominance gates for Cooler+Filter, maximum spacing, universal protector/helper, permanent growth corner and repeated role-zone templates;
16. mandatory keyboard/controller/Deck paths;
17. non-color and non-audio critical-information equivalents;
18. Causal Review first cause, ancestry, compare and targeted Retry behavior;
19. save timing, atomicity, recovery, migration and cloud semantics;
20. distinction between empirical prototype gates and frozen gameplay rules.

Result: **20/20 deterministic.**

## Prototype-dependent empirical gates

These remain validation gates, not missing design:
- >=70% of representative failures should yield a specific causal explanation plus intended revision rather than blind shuffle;
- >=50% of interesting/memorable outcomes should depend on post-launch state change;
- ordinary non-mastery first-launch planning should have <=8-minute median after rule familiarity;
- helper/protector species must prove decision distinctness or be cut/merged;
- demo testers should describe the identity as planning for transit behavior rather than static packing;
- Causal Review must expose an actionable first cause without raw-log reading.

A prototype failure may reopen a specific rule later, but the current specification is complete enough to implement and test.

## No-new-design rule

From this freeze forward, implementation must treat the design as a contract. Do not add species, supports, currencies, campaign nodes, hazard families, monetization systems, platforms, multiplayer, or new core mechanics merely because implementation makes them tempting.

If implementation reveals a contradiction, record the exact contradiction and amend canonical design deliberately before changing gameplay behavior.

## Final decision

- Specification freeze: **YES**
- Internal semantic review: **YES**
- Fresh-session implementation readiness: **YES — 20/20 deterministic**
- DESIGN COMPLETE: **YES**
- Production implementation started: **NO**

Phase 12 may begin in a separate implementation run/session using this file and the authority chain above as the contract.