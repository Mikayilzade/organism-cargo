# GAME BIBLE — ORGANISM CARGO

Status: **FINAL TOP-LEVEL CANONICAL SPECIFICATION / PHASE 11 RECONCILED**
Design complete: **NO — cross-file contradiction sweep still in progress**
Last updated: 2026-08-15

This file is the final top-level design contract for **Organism Cargo**. It contains no future-phase placeholders. Detailed implementation rules live in the domain documents listed under **Authority map**. If this file and a domain document appear to disagree, the more specific domain document wins only when it is explicitly marked canonical and does not conflict with a Phase-11 freeze item.

## Authority map

- `MECHANICS.md` — deterministic tick simulation, organism traits/states, channels, growth, support behavior, transit event ordering.
- `DECISION_ARCHITECTURE.md` — contract rules, scoring, uncertainty, planning authority, Causal Review and player decision structure.
- `PHASE4_CLOSURE.md` — mechanical closure evidence and exploit review.
- `CONTENT_ARCHITECTURE.md` — launch roster, supports, holds, hazards, authored/generated content and validation.
- `UX_ARCHITECTURE.md` — states, controls, HUD, onboarding, accessibility and presentation.
- `ECONOMY_COMMERCIAL.md` — progression, medals, premium model, demo and commercial boundaries.
- `TECHNICAL_SPEC.md` — runtime/data architecture, determinism, persistence, idempotency and test hooks.
- `PHASE11_FREEZE.md` — exact campaign graph, demo migration, dynamic-transit quotas, support/species validation gates, edge semantics and unified acceptance index while final source-file fold-in is being completed.
- `WHOLE_GAME_SIMULATION.md` and `ADVERSARIAL_REVIEW.md` — validation history; not independent authorities once their repairs are folded into canonical sources.

---

# 1. Product thesis

## Codename
**Organism Cargo**. Commercial title remains intentionally implementation-flexible and may change without altering design.

## One-sentence hook
**Pack living cargo into a constrained transport hold, commit to launch, then watch a deterministic ecology evolve as organisms grow, feed, sleep, contaminate, soothe, panic, protect and alter one another during transit.**

## Genre
Premium single-player systemic puzzle / compact strategy simulation for PC/Steam.

Packing is the setup interface, not the game identity. The actual game is prediction, commitment, causal observation and revision.

## Core fantasy
The player is a specialist who can safely transport impossible organisms because they can predict how a tiny living system will change after the hold closes.

## Non-negotiable differentiator
**The hold is not solved when the doors close.**

A normal contract must derive meaningful difficulty from post-launch state, footprint, environmental, support-power or relationship changes. Static packing logic may teach the first few concepts but cannot become the dominant launch experience.

## Design pillars
1. **Predictable living cascades** — deterministic, learnable rules; no hidden outcome RNG for a known committed state.
2. **Inspect → hypothesize → arrange → commit → simulate → explain → revise** — causal review is part of the core loop.
3. **Small vocabulary, deep combinations** — reusable traits and channels generate depth instead of hundreds of bespoke creatures.
4. **Alive at a glance** — important state changes are visually readable and have non-audio/non-color equivalents.
5. **Compact competence fantasy** — one hold and one job stay deep; scope must not expand into ship, colony, logistics or creature-collection simulation.

## Anti-pillars
The game is not allowed to become a static sorting/packing puzzle, inventory autobattler, freeform physics sandbox, pet-care simulator, collection treadmill, logistics empire, open-world delivery game, multiplayer service, action combat game, grind economy, stat-power roguelite or lore-heavy dialogue game.

---

# 2. Scope contract

Launch is single-player and offline-capable. There is no mandatory backend, PvP, co-op, live-service progression, loot box, paid power, energy timer, first-person ship traversal, base building, breeding/genetics metagame or large dialogue tree.

Gameplay authority is a **discrete deterministic tick simulation**. Visual animation may interpolate and dramatize outcomes but never determine them.

The launch content ceiling is deliberately bounded:
- **48 authored campaign contracts**, C01–C48;
- **22 launch species maximum before empirical redundancy cuts**;
- **6 support modules**, S01–S06;
- bounded families of hold layouts and route hazards;
- generated/recombined challenges only when a certified valid solution and dynamic-transit significance are known;
- a public demo with **10 species total: 9 documented + 1 bounded-discovery species**.

A prototype may reduce the 22-species roster when redundancy tests fail. It may not add new trait grammar merely to preserve a target count.

---

# 3. Player-facing loop

## Immediate planning loop
The player inspects the manifest, hold, route and known traits; selects cargo/supports; places, moves or rotates legal items; reads predicted relationships; and forms a causal hypothesis.

## Contract loop
1. receive manifest, hold, route/hazard and objectives;
2. inspect documented information and any explicit bounded uncertainty;
3. arrange organisms and allowed supports;
4. commit once to launch;
5. run deterministic transit;
6. observe state/footprint/environment/support changes and cascades;
7. enter Causal Review;
8. identify the earliest actionable causes of success/failure;
9. revise the initial plan and retry when needed;
10. earn Bronze for mandatory delivery success, with Silver/Gold for optional mastery conditions.

A failed run is evidence, not punishment. Retry preserves the same committed inputs unless the player changes them.

## Session loop
Normal sessions are several short contracts, usually 25–45 minutes total, with clean stopping points between contracts. Learning alternates familiar recombination, one new rule relationship and a higher-complexity case rather than introducing several unrelated mechanics at once.

## Long-term loop
Progression unlocks knowledge, new combinations, species, holds, hazards, supports and challenge families. It does **not** grant permanent numerical power. Previously learned species remain relevant through recombination.

---

# 4. Player verbs and control contract

Canonical verbs are:
- inspect/select;
- place/move;
- rotate when orientation is defined;
- place/configure an allowed support;
- inspect trait/state/route overlays;
- reset planning state;
- commit/launch;
- pause transit where allowed;
- review/scrub completed transit and causal ancestry;
- retry the same contract;
- compare mandatory and optional objectives.

All required gameplay paths must support **mouse+keyboard, keyboard-only, controller-only and Steam Deck/1280×800**. Input remapping is mandatory for gameplay actions. No game-critical state may require audio, color discrimination, fine-pointer precision or rapid repeated input.

---

# 5. Game-state contract

Major runtime states are:
`BOOT → MAIN_MENU → PROFILE/NEW_GAME → CONTRACT_SELECT → PLANNING → LAUNCH_COMMIT → TRANSIT → RESULTS/CAUSAL_REVIEW → CONTRACT_SELECT`.

`PAUSED`, `SETTINGS`, `CODEX`, `SAVE_RECOVERY` and confirmation modals are explicit substates/overlays and may not mutate simulation authority accidentally.

Launch is an exactly-once authoritative transition. Results/progression application is idempotent. Reopening Results, reloading, cloud reconciliation or repeated UI actions must not award completion twice.

Transit resumption reconstructs deterministically from committed input/seed/version/checksum data. A platform-specific partial runtime object is never the sole source of truth.

---

# 6. Core mechanical architecture

Detailed event order and formulas are in `MECHANICS.md`. Top-level invariants are frozen here:

- Known initial state + committed content/rules version + seed always produces the same authoritative transit result.
- Brownout/power availability is resolved before same-tick powered-support effects; a support disabled by Brownout has no same-tick mitigation authority.
- Simultaneous material causes preserve multi-parent causal ancestry even if the UI shows one display-first branch.
- Repeated illegal growth against an unchanged obstruction creates one blocked-growth episode consequence, not repeated every-tick punishment. A new consequence requires a relevant condition/retry boundary change.
- Sleep disables only traits explicitly gated by sleep state; passive emissions never disappear merely because an organism looks asleep.
- Every reactive-pulse trait has a finite trigger guard: once per run, once per episode or explicit maximum triggers. Unlimited positive self-trigger loops are invalid content.
- Continuous physics and presentation interpolation cannot alter occupancy, event order, thresholds or outcome authority.

---

# 7. Decision and difficulty architecture

Pressure comes from constrained topology, changing footprints, environmental channels, support power/fixtures, route hazards, organism state timing, incomplete-but-explicit discovery information and optional mastery objectives.

Difficulty rises by combining known rules temporally, not mainly by adding more creatures or inflating numbers.

The design must structurally resist universal strategies:
- maximize empty space;
- isolate every organism;
- use Cooler+Filter by default;
- rely on one universal soother/protector;
- reserve the same growth corner every contract;
- brute-force by blind shuffle without causal understanding.

At least C05–C48 contain a decision-relevant post-launch change. At least 20 of C09–C48 require Bronze planning around two or more temporally separated changes. Later chapters include authored cases where maximum spacing, permanent growth reserves, common supports or common protectors are inferior for rule-driven reasons.

---

# 8. Campaign and progression

The campaign contains exactly **48 nodes** in six eight-contract chapters. The exact prerequisite graph is frozen in `PHASE11_FREEZE.md` and must be copied into implementation data without reinterpretation.

Campaign progression uses **Bronze completion only**. Silver/Gold, challenges, achievements, money, XP, retry count, online activity and knowledge flags are never campaign prerequisites.

Chapter capstones are C08, C16, C24, C32, C40 and C48. Branches provide choice but converge before capstones so required teaching lanes cannot be skipped.

Challenge mode unlocks only through its canonical full-game progression gate. Imported demo knowledge does not unlock it early.

---

# 9. Content architecture

Launch organism roster is a maximum of 22 species O01–O22, defined in `CONTENT_ARCHITECTURE.md` and tested against the unique-decision/readability matrix in `PHASE11_FREEZE.md`.

Mandatory empirical redundancy clusters are:
- O06 / O12 / O16;
- O05 / O19 / O20.

If two members of a cluster drive the same preferred placement/support/revision decision in at least 70% of a representative validation set, the less readable species is cut or merged.

Supports are exactly:
- S01 Cooler;
- S02 Filter;
- S03 Baffle;
- S04 Nest Pad;
- S05 Feed Cartridge;
- S06 Monitor Beacon.

No support is designed for equal usage; the requirement is non-dominance. Each has authored preferred cases, legal-but-inferior cases and alternative Bronze families. Across C17–C48, Cooler+Filter may be the certified primary Bronze pair in at most 8 contracts.

Generated challenges are rejected unless they have a certified valid solution, meaningful post-launch change, bounded causal opacity and adequate distance from recent challenge fingerprints.

---

# 10. Causal Review

Causal Review is a mandatory core feature, not optional analytics.

It must let a player quickly answer:
- what meaningful event changed first;
- which trait, support, hazard or state transition caused it;
- which later events descended from it;
- which objective eventually failed or succeeded;
- what initial decision could plausibly be revised.

Stored causal graphs preserve all material roots. UI may compress branches for readability but never fabricate a single cause when the simulation stored multiple material causes.

Raw event logs may exist for debugging but are not the intended player explanation interface.

---

# 11. Scoring and economy

Bronze means all mandatory delivery conditions passed. Silver and Gold are optional mastery layers and never block campaign progression.

The design has no generic money grind, consumable monetization or permanent stat-upgrade economy. Supports are contract/loadout decisions rather than long-term power purchases.

Optional mastery can reward efficiency, welfare, constraint satisfaction, lower support dependence or other contract-specific goals only when the objective is explicit before launch.

---

# 12. Narrative and tone

Narrative is light, systemic and subordinate to play. Contract flavor explains why strange organisms need transport and gives the world specificity, but all gameplay remains understandable when flavor text is skipped.

Tone is curious, slightly strange and competent rather than cruel, graphic or medical-realistic. Organisms can be stressed or fail delivery conditions without turning the game into suffering spectacle.

---

# 13. Visual, audio and presentation contract

Presentation is stylized and readable. A small reusable body-plan/animation vocabulary communicates calm/stress, feeding, sleeping, contamination, growth, emission, protection, recovery and other mechanically relevant states.

Every gameplay-critical cue has:
- a non-audio equivalent;
- a non-color-only representation;
- reduced-motion compatibility;
- reduced-flash compatibility.

The hold remains legible at 1280×720, Steam Deck 1280×800 and maximum supported UI scale without hiding mandatory controls or objective information.

---

# 14. Onboarding and knowledge

Early contracts isolate one core relationship at a time. C01–C04 may be near-static onboarding exceptions; by C05 the game must demonstrate that post-launch change matters.

The Codex distinguishes documented knowledge, bounded-discovery information and run-observed evidence. Unknown behavior is never arbitrary: discovery content has explicit information bounds and must support conservative successful planning without requiring the Monitor Beacon.

Demo import may transfer documented knowledge but never grants mechanical power or skips later full-game teaching nodes beyond the explicit C01–C08 mapping.

---

# 15. Demo contract

The public demo contains:
- 10 species = **9 documented + 1 bounded discovery**;
- Cooler, Filter, Baffle and Feed Cartridge;
- 3 hold layouts from two families;
- 3 hazard families;
- 10 authored contracts;
- 3 generated/recombined challenge templates;
- exactly 1 discovery contract;
- roughly 60–90 minutes normal first-clear content.

D01–D08 may map to C01–C08 completion in the full game. D09–D10 never auto-clear C09+. Settings and knowledge transfer; no demo completion grants mechanical power. Imported knowledge cannot unlock Challenge mode early.

By demo contract 3 at the latest, a visible post-launch state change changes a relationship or risk. At least 5 of 10 authored demo contracts make post-launch timing/state change relevant to Bronze success.

---

# 16. Persistence and recovery

Canonical save behavior is detailed in `TECHNICAL_SPEC.md` and frozen by Phase 11:
- launch commit is exactly-once;
- Results/progression application is idempotent;
- committed transit input stores seed, content/rules versions and checksums required for reconstruction;
- corrupt primary save attempts validated backup recovery;
- double corruption enters explicit recovery/new-profile flow rather than silently inventing progress;
- migration failure preserves recoverable source data and reports failure;
- cloud/local divergence uses explicit deterministic reconciliation rules, not newest-file-wins blindly;
- legacy rules/content versions are either reconstructable through retained compatibility data or the affected in-progress transit is safely invalidated with an explicit restart path;
- demo migration is versioned and applies only documented mappings.

---

# 17. Commercial model

Premium PC/Steam release. No ads, paid power, loot boxes, energy timers or manipulative daily-streak dependency.

A downloadable Steam demo is part of the launch strategy because the hook is mechanical and testable in a small slice.

Store/trailer messaging must emphasize **living cargo changing after commitment**, not generic satisfying packing. The strongest 10-second marketing beat is a clear plan visibly turning into a learnable cascade, followed by a targeted revision that fixes it.

Commercial title, final price, capsule art and release date are intentionally business-flexible and do not block design freeze.

---

# 18. Technical implementation contract

Implementation uses a data-driven deterministic simulation with explicit content IDs and versioning. Required technical properties:
- stable event ordering;
- integer/fixed deterministic authority where floating-point divergence could matter;
- authoritative grid/slot occupancy separate from visual transforms;
- trait/state/support definitions in validated data;
- reproducible contract seeds;
- solver/generator validation hooks;
- causal-event ancestry persisted or reconstructable for Results;
- test harness able to run the same committed case repeatedly and compare authoritative hashes;
- save schema versioning and migration tests;
- input abstraction for mouse/keyboard, keyboard-only, controller and Deck;
- no game logic tied to framerate or animation completion.

Engine choice is an implementation decision only if it satisfies these contracts without changing gameplay semantics.

---

# 19. Unified acceptance gate

The full acceptance index is maintained in `PHASE11_FREEZE.md`. Design/implementation is not acceptable unless automated or scripted tests cover at minimum:
- deterministic replay/hash equality;
- event ordering and simultaneous-cause ancestry;
- Brownout same-tick authority;
- blocked-growth episode semantics;
- finite reactive triggers/no infinite resource loops;
- campaign graph validity and Bronze-only prerequisites;
- demo migration boundaries;
- support non-dominance content coverage;
- species redundancy gates;
- generated-challenge certified solvability and dynamic significance;
- exactly-once launch and idempotent Results;
- save corruption/backup/migration/cloud divergence/legacy behavior;
- keyboard-only, controller-only, Deck, 1280×720, maximum UI scale, remapped controls, no-audio, non-color, reduced-motion and reduced-flash paths.

---

# 20. Prototype-dependent empirical gates

These are deliberate validation obligations, not undefined design:
1. after representative failures, at least 70% of validation cases should let players state a specific causal explanation and intended revision rather than blind shuffle;
2. at least half of memorable/interesting validation outcomes should depend on post-launch state change;
3. after rule familiarity, ordinary non-mastery planning should not settle above an 8-minute median first-launch analysis time;
4. helper/protector redundancy clusters must feel decision-distinct or be cut/merged;
5. demo testers should predominantly describe the game as planning for what creatures do during transit, not static packing;
6. Causal Review must surface an actionable first cause quickly without requiring raw-log reading.

Failure of these gates triggers redesign/cuts inside the frozen scope, not automatic feature expansion.

---

# 21. Vertical slice contract

The first implementation slice exists to falsify the thesis cheaply. It must include:
- one compact hold;
- a small representative organism subset including at least one post-launch footprint change, one environmental source/sink relationship and one social/protection interaction;
- at least one powered support and one living substitute/alternative;
- deterministic transit with enough ticks for two temporally separated changes;
- commit → transit → Causal Review → revise → retry;
- saved/reloaded committed state reconstruction;
- keyboard/mouse and controller-complete critical path;
- debug timeline/hash output;
- at least three authored cases, one intentionally static tutorial and two genuinely dynamic cases.

The slice fails even when technically functional if testers solve mainly by static spacing, cannot explain failures, or do not perceive the transit phase as the reason the game is interesting.

---

# 22. Definition of design completion

`DESIGN COMPLETE = YES` may be set only when:
- all domain documents are reconciled with this file and `PHASE11_FREEZE.md`;
- no stale TBD/old-phase/obsolete demo/control/progression wording remains in canonical sources;
- the contradiction sweep finds no competing authority for a gameplay rule;
- every programmer-facing gameplay question has an explicit answer or a clearly harmless implementation-flexible boundary;
- prototype-dependent empirical gates are clearly marked as validation gates rather than unresolved design.

Until that repository-wide reconciliation succeeds, the project remains **in progress** and production implementation remains blocked.