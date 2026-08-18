# ORGANISM CARGO — DECISION ARCHITECTURE

Status: **FINAL CANONICAL PLAYER-DECISION SPECIFICATION — PHASE 11 RECONCILED**
Last updated: 2026-08-15

This file is canonical for planning actions, previews, support-resource decisions, behavioral-state precedence, content-construction restrictions, contract predicates, difficulty, medals, bounded uncertainty and player-facing mechanical acceptance tests. `MECHANICS.md` remains authority for transit phase order and simulation semantics; `PHASE11_FREEZE.md` wins on exact frozen Phase-11 items.

---

# 1. Planning-state action legality

Planning is free, reversible and untimed. There is no move count, planning timer, retry cost or score penalty for experimentation.

The player may:
- inspect manifest organisms, supports, cells, zones, fixtures, hazards and objectives;
- place/move/remove organisms;
- rotate through body-plan legal orientations;
- place/move/remove allowed supports;
- set a support link/target only when its definition permits one;
- set Brownout support priority where relevant;
- undo/redo;
- reset to last launch or original contract state;
- save the current working arrangement;
- launch any structurally legal arrangement even if known evidence suggests failure.

## 1.1 Placement legality
Placement is legal only if every current-footprint cell is in-bounds/usable, non-overlapping, orientation-valid and compliant with explicit zone/fixture/anchor restrictions.

Illegal reason labels are exact: overlap, blocked, outside hold, forbidden orientation, wrong zone, fixture required, unsupported link or exceeded support resource.

## 1.2 Future growth is not launch validity
A future growth cell may be blocked while the current setup remains legally launchable. Known growth risk is shown as a warning, not a structural invalidity.

Only a teaching-only tutorial may temporarily block launch to demonstrate a rule. That tutorial exception does not change the general mechanic.

## 1.3 Rotation
Rotation is discrete and may alter current footprint, directed rays and deterministic future-growth direction. Symmetric duplicate orientations may be collapsed in UI. No transit-time rotation exists.

## 1.4 Support placement classes
Every support declares exactly one class:
- **cargo-cell support** — occupies normal hold cell(s), blocks occupancy/growth;
- **utility-fixture support** — installs only in declared utility fixtures;
- **organism-bed support** — occupies/uses a bed/pad slot and may affect at most one linked/occupying organism unless explicitly defined otherwise.

## 1.5 Links
A target/link exists only when the support definition declares one. Invalid links caused by moving/removing target/support are visibly invalidated. Launch blocks only when the support definition says a valid link is mandatory.

## 1.6 Undo/redo and reset
Undoable: place, move, rotate, remove, support install/remove, link/priority change and reset where practical.

Launch clears the active planning command history. `Retry from last launch` restores the exact committed layout as a new editable baseline. `Reset contract` restores the original contract setup.

## 1.7 Launch validity
Launch requires:
- all mandatory manifest organisms placed;
- all current placements structurally legal;
- support allowance and pre-launch power/fixture constraints satisfied;
- every required support assignment/link valid;
- any explicit structural prerequisite satisfied.

Launch does **not** require predicted success, a medal, future growth space, low meters, any support, or a solver-approved arrangement.

---

# 2. Prediction and preview contract

The UI explains known current facts and immediate relationships but does not solve the future.

Canonical information layers:
1. **Facts** — current state + documented rule data;
2. **Immediate influence** — direct relationships implied by current arrangement;
3. **Transit evidence** — actual events from committed runs.

They must remain visually distinct.

## 2.1 Pre-launch facts
When documented/known, expose:
- current organism meters/states;
- current footprint/orientation and next documented growth footprint;
- documented trait rule/range/direction;
- current adjacency/compatibility;
- support effects/capacity;
- known route timeline/hazards;
- mandatory/Silver/Gold conditions;
- support allowance, fixtures, power and priority.

## 2.2 Immediate influence overlays
Allowed previews:
- current heat sources/sinks and local influence;
- stress-field sources/soothers;
- contamination sources/sinks;
- feeding/symbiotic links;
- directed rays;
- future documented footprint;
- support influence area;
- known Brownout availability/priority consequences.

The preview may state `A currently affects B`, `this cooler covers these cells`, `this documented growth stage requires these cells`.

It may not state `A will panic on tick 7`, `this plan succeeds`, recommend a placement, display full future heatmaps or provide an unobserved causal chain.

## 2.3 Arithmetic assistance
Exact documented current-state contributions may be shown, e.g. `+2 heat/tick` or `removes up to 3 contamination/tick`. UI may aggregate current contributors so the player is not forced to do clerical arithmetic. Any total must be labelled current-state-only and not include uncommitted future transitions.

## 2.4 Route preview
Known hazards show tick window, affected zone and declared intensity. Bounded unknowns are explicitly marked rather than silently omitted.

## 2.5 No auto-solver
No base-game control may rank placements, calculate success probability, simulate all layouts, label a plan safe or recommend a move.

---

# 3. Support-resource model

There are exactly three planning constraint families:
1. physical space/fixture topology;
2. utility power;
3. contract support allowance.

No per-contract money budget and no persistent consumable stock economy.

## 3.1 Power
Each hold has integer `power_capacity`; each powered support has integer `power_draw`.

Pre-launch structural invariant:

`sum(installed powered-support power_draw) <= power_capacity`

Known route Brownout can lower available transit power after launch.

## 3.2 Brownout priority
When installed demand exceeds temporary available route power:
1. allocate in player-declared unique priority order;
2. each support is fully powered or off unless its definition explicitly supports degraded operation;
3. powered/off transitions are causal events;
4. no random selection.

**Phase-A authority:** Brownout allocation is finalized in Phase A. A support turned off has no same-tick mitigation authority.

## 3.3 Contract allowance
A contract declares support types/quantities or a choice pool. This is loadout design, not currency. Feed Cartridge reserve is finite in-run but never a persistent purchased stock.

## 3.4 Opportunity cost
Every support costs at least one of cargo space, fixture slot, power, limited allowance, lost beneficial relation or finite in-run capacity.

---

# 4. Final support roster

## S01 Cooler
Utility fixture; powered; local heat mitigation; finite capacity; Brownout-vulnerable; no contamination/stress effect.

## S02 Filter
Utility fixture; powered; local environmental contamination removal; finite capacity; Brownout-vulnerable; does not directly reduce internal contamination load.

## S03 Baffle
Cargo/boundary support; no power; reshapes stress transmission and may block directed rays/beneficial relations/future space. It never deletes existing stress.

## S04 Nest Pad
Capacity-one organism-bed support. Enables sleep/recovery according to explicit eligibility/state data. **Sleep itself never disables an undeclared trait.** Any lost beneficial/harmful behavior must be explicitly sleep-gated in content data.

## S05 Feed Cartridge
Cargo-cell support; finite conserved food; compatibility and target allocation are deterministic; remains solid when empty unless a separately frozen rule says otherwise.

## S06 Monitor Beacon
Low-power utility information support. It may reveal one contract-declared bounded fact or exact local telemetry. It provides no direct mitigation, no success verdict and no layout recommendation. Discovery Bronze must remain conservatively solvable without it.

Prohibited support families: universal shield, global sedation, teleport/reposition during transit, transit undo, all-channel cleanser.

---

# 5. Behavioral-state precedence

Exactly one primary behavioral state:
- `CALM`;
- `AGITATED`;
- `PANICKED`;
- `ASLEEP`.

Condition flags such as `CONTAMINATED`, `CRITICAL`, `GROWTH_BLOCKED`, `DELIVERY_FAILED` are orthogonal.

## 5.1 Stress threshold invariant

`panic_enter > panic_exit >= agitated_enter > agitated_exit >= 0`

### CALM
- stress >= panic_enter -> queue PANICKED;
- else stress >= agitated_enter -> queue AGITATED;
- otherwise CALM.

### AGITATED
- stress >= panic_enter -> PANICKED;
- stress <= agitated_exit -> CALM;
- otherwise AGITATED.

### PANICKED
- stress > panic_exit -> PANICKED;
- stress <= agitated_exit -> CALM;
- otherwise AGITATED.

Awake mood transitions normally apply next tick start; transition-triggered consequences follow their trait phase and cannot retroactively change the crossing snapshot.

## 5.2 ASLEEP override
ASLEEP is the primary behavior while sleep persists, but internal stress/conditions still update. On wake, derive awake state from current stress:
- >= panic_enter => PANICKED;
- else >= agitated_enter => AGITATED;
- else CALM.

Wake resolves at the next valid Phase-B boundary. If sleep and wake are both queued for that same boundary, **wake wins**, and both requests/precedence are logged.

## 5.3 Explicit sleep gating — frozen
Being ASLEEP changes only effects explicitly marked with sleep state gates. No animation-implied global shutdown. Passive environmental output remains active unless its own trait data says otherwise.

## 5.4 Condition flags
`CONTAMINATED` uses explicit enter/exit thresholds. `CRITICAL` is normally sticky unless explicit recovery exists. `DELIVERY_FAILED` is contract evaluation, not mood.

`GROWTH_BLOCKED` represents the current blocked-growth episode. It may remain visible while obstruction persists, but **one unchanged episode creates one consequence only**. A new consequence requires a meaningful legality/occupancy/orientation/body/trigger/retry-boundary change as specified in `MECHANICS.md`.

---

# 6. Species/body-plan construction grammar

A species is data composition:
- one body plan and starting stage;
- legal orientations;
- base profiles/thresholds;
- 1–3 significant trait modules;
- optional passive readability tags;
- optional bounded growth/lifecycle transition;
- presentation metadata.

Normal trait-count ceiling:
- intro 1;
- standard 2;
- advanced 3;
- >3 only by formal readability exception and excluded from generated content by default.

Role tags: `SOURCE`, `SINK`, `SOCIAL`, `FEEDING`, `LIFECYCLE`, `REACTIVE`.

Forbidden/restricted combinations include:
- unconditional broad source+sink that mainly cancels itself;
- alarm+soother arithmetic-noise pair with identical range;
- self-contained contamination producer/filter immunity loop with no external dependency;
- any infinite positive resource loop;
- recursive unbounded T10 pulses;
- universal multi-channel resistance + broad benefit aura;
- impossible growth footprints;
- hidden target priorities.

A 2–3 trait species must create a real interaction/self-tradeoff/lifecycle/relationship decision, not stacked bonuses.

Body-plan vocabulary:
- B01 Dot = 1 cell;
- B02 Domino = 2 orthogonal cells;
- B03 Corner = 3-cell L;
- B04 Bar = 3-cell line.

Normal current footprint 1–3 cells; later foundation stage <=4. Standard species: at most one growth transition; rare advanced content may use two if readable. No open-ended growth.

---

# 7. Contract predicate grammar

Requirements are data-defined Boolean expressions using `ALL`, `ANY`, limited `NOT`, and explicit atomic predicates. Standard objectives should remain renderable as short plain-language conditions.

Entity selectors include instance, species, tag, all manifest, zone, support and hold.

Allowed final-state atomics include:
- primary state;
- condition flag;
- meter comparison;
- growth stage;
- zone;
- awake;
- supports used / installed power;
- `EMPTY_CELLS` **only for contract-specific authored efficiency use**;
- route completed.

Allowed timeline atomics include:
- never entered state;
- never gained flag;
- event count;
- max/min meter;
- max channel;
- ticks in state;
- growth-block episode/event count;
- support active ticks;
- explicit no-event alias.

Each contract has `mandatory[]`, optional `silver_objectives[]`, optional `gold_objectives[]`.

Predicate prohibitions:
- hidden unknowable rules;
- intentional irreversible harm as reward;
- opaque weighted sums;
- retry/planning-time penalties;
- pixel precision/manual speed;
- contradictory mandatory goals without explicit alternative structure.

---

# 8. Difficulty ladder

## Tier 0 — orientation/tutorial
2–3 organisms, one trait family, no hidden info, no meaningful support choice; near-static is allowed only here.

## Tier 1 — single causal link
3–4 organisms, one state change and one clear future consequence. Proves transit changes the answer.

## Tier 2 — competing proximity
4–6 organisms, reason to cluster + reason to separate, two pressure families, simple support opportunity cost.

## Tier 3 — temporal planning
4–7 organisms, growth or sleep/wake, known route window, multi-step causal chain, space/power tradeoff.

## Tier 4 — cascades/scarce mitigation
5–8 organisms, ~3 pressure families, multiple route events, limited fixtures/power/supports, multiple intervention families.

## Tier 5 — bounded discovery
4–7 organisms, one bounded undocumented rule or route detail, safe/informative failure, conservative Bronze without blind guessing, optional Monitor evidence tradeoff.

## Tier 6 — mastery recombination
6–10 organisms (often fewer), 3–4 pressure families, irregular hold, state-gated traits, Brownout/timing, strict transparent optional goals, no new foundation rule.

Do not create difficulty by hidden documented info, unreadable organism count, arbitrary noisy thresholds, planning timers, runtime randomness, clerical arithmetic or one-off exceptions.

---

# 9. Bronze / Silver / Gold

Mandatory delivery success is binary.

- Bronze = all mandatory predicates pass.
- Silver = Bronze + all Silver objectives.
- Gold = Silver + all Gold objectives unless a rare contract explicitly declares a transparent alternative optional set.

No hidden campaign weighted score.

Good optional axes:
- welfare stability;
- contamination control;
- no blocked-growth episodes;
- support/power efficiency;
- compactness only when the contract proves a dynamic density tradeoff;
- required awake/mature state;
- named support restriction;
- preservation of a beneficial relation.

## 9.1 Empty-space rule — frozen
`EMPTY_CELLS` remains a valid predicate primitive but **unused space is not a global medal axis**. It may appear only in a specific authored contract where density itself creates a meaningful dynamic transit tradeoff. There is no profile-wide, campaign-wide or challenge-wide empty-area score.

Never reward death/criticality, planning speed, fewer retries, fewer mouse moves, ignoring review or sacrificing a low-value organism.

Retries are unlimited in the campaign; only best medal persists.

---

# 10. Bounded uncertainty and documentation

Mechanically relevant facts are either `DOCUMENTED` or `UNDOCUMENTED` with bounded cues.

Never hide:
- footprint/orientation legality;
- visible primary state/condition flags;
- contract-critical welfare;
- existence/category of an undocumented behavior slot;
- hard placement restriction;
- physical growth possibility when contract-critical.

Discovery cues may expose an observational sentence, category icon, pre-launch behavior, handler note, Monitor category, known trigger/unknown magnitude or known effect/unknown trigger.

First campaign exposure to an undocumented trait must be conservatively solvable, safe to fail/retry, forgiving by design or reveal the effect early enough for informed retry. Blind 50/50 guessing is invalid.

A uniquely identifying observed causal event can permanently document the exact rule.

Unknown route information is rarer and always bounded. Transit remains deterministic per committed seed; uncertainty is informational only.

Monitor Beacon may make one bounded fact exact but is never required for campaign Bronze.

---

# 11. Canonical acceptance tests

## State tests
- exact threshold entry and hysteresis;
- CALM may skip directly to PANICKED after a large delta;
- sleep can accumulate stress and wake into the correct awake state;
- simultaneous sleep+wake -> wake wins;
- condition flags remain orthogonal;
- sleep enumerations prove only declared traits are gated.

## Trait tests
T01–T09 verify exact state gates, deterministic allocation, conservation/capacity and phase timing. T08 blocked growth verifies no push/alternate search and one unchanged-episode consequence only.

T10 tests:
- each definition declares exactly one finite guard: `once_per_run`, `once_per_episode` or finite `max_triggers_per_run`;
- no every-tick refire while state persists unless separately defined as a non-T10 continuous trait;
- simultaneous transitions batch correctly;
- no retroactive cancellation;
- recursive/self-sustaining positive loops rejected.

## Support tests
- pre-launch power overflow blocks launch;
- Brownout priority is deterministic and Phase-A authoritative;
- fixture exclusivity;
- Baffle/Feed support occupancy affects growth/placement;
- Cooler/Filter capacity exact;
- Nest capacity and explicit sleep gates;
- Feed conservation;
- Monitor never leaks solver output.

## Contract/preview tests
- legal predicted-failure setup remains launchable;
- structural invalidity produces exact reason;
- future growth warning does not block launch;
- current overlay updates immediately after edits;
- no future solver leak;
- unchanged retry reproduces identical event/checksum sequence;
- UI text maps exactly to predicates;
- Gold => Silver => Bronze;
- no retry penalty;
- unknown behavior is visibly marked and produces causal evidence;
- no global empty-space reward.

## Content-combination hard rejects
- impossible mandatory placement;
- impossible required growth across every legal initial family;
- unsupported selector;
- same-tick infinite trigger chain;
- mandatory powered-support requirement impossible under all legal support configurations;
- predicates referencing absent content;
- dynamic-transit violation outside C01–C04;
- unbounded T10 definition;
- generated challenge with no certified Bronze.

**Decision architecture result: FROZEN pending only final cross-file contradiction clearance.**
