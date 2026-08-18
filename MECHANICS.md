# ORGANISM CARGO — MECHANICAL ARCHITECTURE

Status: **FINAL CANONICAL MECHANICAL SPECIFICATION — PHASE 11 RECONCILED**
Last updated: 2026-08-15

This file is canonical for deterministic transit mechanics. It is subordinate to the product thesis and Phase-11 frozen invariants in `GAME_BIBLE.md` and `PHASE11_FREEZE.md`, and is designed to be implementation-ready without relying on stale Phase-4 placeholders.

---

# 1. Mechanical objective and invariants

The player chooses initial conditions for a compact deterministic ecology, commits, and then observes whether it survives transit. Packing is setup; prediction of post-launch change is the game.

The simulation must be:
1. **deterministic** — identical committed state + content/rules versions + route + seed produce identical authoritative results;
2. **discrete** — grid cells, integer/fixed-point values, explicit ranges, ordered phases and deterministic selectors define authority;
3. **explainable** — every outcome-relevant change has a causal event record;
4. **composable** — organisms are data-defined combinations of reusable traits, not bespoke scripts.

Dynamic-transit requirement:
- C01–C04 may be near-static onboarding exceptions;
- every C05–C48 must contain at least one Bronze-relevant post-launch state, footprint, environmental, support-power or relationship change;
- at least 20 of C09–C48 must require Bronze planning around two or more temporally separated changes.

---

# 2. Hold topology

## 2.1 Grid
The authoritative hold is a 2D orthogonal grid, typically about 5x5 to 9x7 usable cells with blocked cells and fixtures.

Each cell has:
- integer coordinate `(x,y)`;
- occupancy;
- passable/blocked state;
- optional fixture/support ID;
- environmental channel values;
- optional zone tags;
- route-hazard modifiers.

Diagonal contact is not adjacency unless a trait explicitly declares diagonal behavior.

## 2.2 Occupancy
At authoritative boundaries, one solid cell belongs to at most one organism or support. Visual interpolation/overlap has no mechanical meaning.

## 2.3 Footprints
A body stage is a set of local integer offsets from an anchor. Rotation exists only for declared legal orientations.

Placement is legal only when all footprint cells are inside usable cells, non-overlapping, orientation-valid and compliant with explicit zone/fixture requirements.

## 2.4 Distance
Default entity distance is Manhattan distance over nearest occupied cells:

`distance(A,B) = min(|ax-bx| + |ay-by|)`

Definitions:
- adjacent = distance 1;
- near = distance <= declared trait range;
- same zone = shares a declared zone tag, independent of distance.

No hidden Euclidean distance.

## 2.5 Directed line of effect
Ordinary emissions use range/environment rules and do not require line of sight. A trait tagged `directed` emits a cardinal ray from declared emitter cells and stops at the first applicable wall/fixture, first solid interceptor when `interceptable`, or maximum range.

---

# 3. Authoritative time model

Transit resolves integer ticks `t = 1..T`. Normal contracts target roughly 10–24 ticks; tutorials may be shorter. Playback speed, pausing and animation never affect authority.

## 3.1 Snapshot rule
Each phase reads a named snapshot and writes deterministic deltas/events that commit only at that phase boundary. Entity iteration order may not change additive outcomes.

## 3.2 Exact A–I tick order

### Phase A — Route, fixtures and power authority
1. advance route timeline;
2. activate/deactivate scheduled hazards;
3. compute hold modifiers and fixture availability;
4. finalize available power and Brownout support state;
5. record route/power events.

**Brownout authority:** any powered support disabled in Phase A produces no same-tick Phase-C/E mitigation. Visuals may lag, authority may not.

### Phase B — Start-of-tick transitions
1. decrement start-boundary timers;
2. resolve scheduled wake/recovery/maturation transitions;
3. apply transitions locked on the previous tick;
4. update body stage/footprint when required;
5. process deterministic growth attempt legality and blocked-growth episode state.

### Phase C — Passive environmental generation
1. active organisms/supports compute current-state output;
2. accumulate outputs per source cell;
3. add fixture/hazard channel contributions;
4. no target has reacted yet.

### Phase D — Environmental propagation/decay
1. propagate each spatial channel from a common source snapshot;
2. apply decay/venting;
3. clamp bounds;
4. publish the tick exposure snapshot.

### Phase E — Exposure and direct interactions
1. organisms sample occupied cells/environment;
2. evaluate adjacency/range/directed interactions;
3. emit feeding, soothing, agitation, contamination transfer and other direct effect records;
4. aggregate conflicts deterministically.

### Phase F — Internal meters
Apply aggregated changes to stress, contamination load, satiety and declared trait-local meters/timers, then clamp.

### Phase G — Threshold evaluation
Evaluate thresholds from the common post-F snapshot and queue transitions using one of:
- `immediate_end_tick`;
- `next_tick_start`;
- `scheduled(n)`.

### Phase H — End-of-tick consequences
1. resolve queued immediate consequences and legal T10 pulses;
2. evaluate critical/irreversible states;
3. evaluate fail-fast conditions;
4. commit causal events/ancestry;
5. take end-of-tick snapshot.

### Phase I — Completion check
If `t == T` or fail-fast ended the run, evaluate mandatory delivery and optional objectives from final state plus timeline aggregates.

Traits may add events inside a permitted phase but cannot reorder global phases.

---

# 4. Environmental channels

Exactly three launch spatial channels are authoritative unless a future frozen design change proves a non-redundant need.

## Heat
Local thermal burden; bounded integer/fixed-point field. Sources add heat; local propagation shares configured amounts to orthogonal neighbors; walls/fixtures may modify transfer; cooling/venting subtracts defined amounts; clamp to channel bounds.

## Stress field
Short-lived environmental agitation distinct from an organism's internal `stress` meter. It propagates shorter and decays faster than heat so it behaves as local social pressure.

## Contamination
Persistent residue/spores/microbes/anomalous matter. It can remain after a source changes state, propagate locally, decay through venting and be consumed/filtered.

Excluded as separate base channels: oxygen, humidity, light, sound, radiation and odor. They may exist only as route tags/binary requirements/flavor unless the design is formally reopened.

---

# 5. Organism runtime schema

Each organism instance contains at least:
- stable `instance_id`;
- `species_id`, `body_plan_id`, ordered trait IDs;
- anchor, legal orientation, current body stage/footprint;
- deterministic growth direction/footprint data;
- `stress`, `contamination_load`, `satiety`;
- rare visible trait-local timers/meters where needed;
- one primary behavioral state;
- orthogonal condition flags;
- causal/documentation metadata required by review.

Primary states:
- `CALM`;
- `AGITATED`;
- `PANICKED`;
- `ASLEEP`.

Condition flags include:
- `CONTAMINATED`;
- `CRITICAL`;
- `GROWTH_BLOCKED`;
- `DELIVERY_FAILED` when irreversible contract logic says so.

Growth stage is body state (`JUVENILE`, `MATURE`, optional `ENLARGED`), not primary mood state.

Delivery requirements may refer to survival/criticality, meter thresholds, growth stage, satiety, forbidden states/events, final zone and explicit timeline facts.

---

# 6. Internal meters and state semantics

## 6.1 Stress
Hysteresis is mandatory:
- below `agitated_enter` -> CALM unless another state overrides;
- `>= agitated_enter` -> AGITATED;
- `>= panic_enter` -> PANICKED;
- recovery uses lower `agitated_exit` / `panic_exit` thresholds.

Required ordering: `panic_enter > agitated_enter > agitated_exit`; panic/exit values must preserve legal hysteresis.

Panic must alter actual behavior/output/eligibility; it cannot be cosmetic.

## 6.2 Contamination load
Exposure deterministically changes contamination load; resistance modifies intake, not the environment field itself. `CONTAMINATED` uses explicit enter/exit thresholds with hysteresis where recoverable. There is no infection RNG.

## 6.3 Satiety
Satiety is deterministic nutritional reserve. Declared metabolism can reduce it. Feeding uses compatibility/range/allocation rules; organisms do not free-roam during transit.

## 6.4 Sleep
Sleep is explicit and state-gated. **Sleep changes only behaviors/traits whose data explicitly declares sleep gating.** No passive heat, spore, alarm, sink, producer or other output disappears merely because the creature's animation looks asleep.

Sleep is not universal safety: some organisms cannot sleep; some must arrive awake; wake hazards exist; useful traits may be sleep-gated; Nest Pad is capacity/space limited.

## 6.5 Criticality
`CRITICAL` is a severe welfare/survival boundary. Whether it fail-fasts or only invalidates objectives is contract data. Every transition retains causal ancestry.

---

# 7. Trait grammar T01–T10

A normal launch species has 1–3 mechanically significant traits.

Each trait declares:
- trigger phase/condition;
- target selector;
- range/adjacency model;
- effects;
- state/sleep gates;
- numeric parameters;
- capacities/delays;
- UI summary;
- causal-log template;
- finite reactive-trigger policy where applicable.

Foundation families:
- **T01 Heat Emitter** — adds heat while active.
- **T02 Heat Sink** — removes heat locally up to capacity.
- **T03 Alarm Emitter** — state-gated stress-field source.
- **T04 Soother** — capacity-limited reduction of exposure/internal stress for eligible targets.
- **T05 Spore Shedder** — state/stage-gated contamination source.
- **T06 Filter Feeder** — consumes contamination and converts it to satiety/benefit according to declared conservation rules.
- **T07 Grazer** — deterministic compatible feeding relation.
- **T08 Growth Trigger** — qualifying condition for `n` ticks queues the next declared footprint stage.
- **T09 Symbiotic Buffer** — narrow, conditional, capacity-limited resistance/mitigation for compatible targets.
- **T10 Reactive Pulse** — bounded event on a named transition/state boundary.

## 7.1 T10 finite trigger guard — frozen
Every T10 definition declares exactly one:
- `once_per_run`;
- `once_per_episode`;
- explicit finite `max_triggers_per_run`.

Unlimited positive state-transition/resource loops are invalid. Validators reject recursive same-tick chains and self-sustaining positive feedback that can maintain the same trigger indefinitely.

## 7.2 Trait prohibitions
Traits may not:
- roll authoritative random chances;
- move organisms autonomously;
- spawn unbounded entities;
- read future route events as hidden omniscience;
- silently mutate another trait's parameters;
- perform hidden global `best target` search;
- rely on presentation timing.

Targeting is deterministic and previewable.

---

# 8. Simultaneous effect resolution

Additive effects combine commutatively within a phase unless a declared cap applies.

Example: two `-2 stress` soothers + one `+3 stress` source => aggregate `-1` before clamping.

Multipliers are discouraged. When necessary, category order is:
1. source production modifier;
2. transmission modifier;
3. target intake/resistance modifier;
4. final clamp.

Within a category, fixed-point multipliers combine deterministically.

Capacity-limited target selectors may use only documented rules such as:
- nearest, then lowest `instance_id`;
- highest exposure, then nearest, then ID;
- clockwise from orientation;
- explicit pre-launch linked target.

Competing finite resources resolve proportionally when divisible or by a documented stable selector when indivisible.

## 8.1 Simultaneous thresholds and multi-root causality
All same-tick threshold decisions use the same post-F snapshot. One pulse cannot retroactively prevent another threshold crossing already determined from that snapshot.

When multiple independent material causes contribute to a threshold/predicate failure, the stored causal event preserves **all material parents**. UI may show one display-first branch for brevity but may not erase additional roots.

---

# 9. Growth and footprint change

Body plans define discrete stages. Example:
- juvenile `{(0,0)}`;
- mature `{(0,0),(1,0)}` relative to orientation;
- optional enlarged declared offsets.

Growth resolution:
1. derive next footprint from current anchor/orientation;
2. identify newly required cells;
3. if all are legal/empty, growth succeeds at the named boundary;
4. otherwise do not push, rotate automatically or search alternate space;
5. begin/continue a `GROWTH_BLOCKED` episode.

## 9.1 Blocked-growth episode semantics — frozen
A blocked deterministic growth attempt creates one episode with one entry consequence.

- The body-plan consequence fires **once when the unchanged blocked episode begins**.
- The same unchanged obstruction does not re-apply stress/damage/failure every tick.
- A new episode/consequence may begin only after a relevant condition changes: target-cell legality/occupancy, orientation/body condition, growth-trigger condition, or an explicitly defined retry boundary.
- The causal graph stores one blocked-growth root plus descendants.
- `GROWTH_BLOCKED` may remain visible while the episode persists.

This supersedes all older wording such as `+N stress and retry every tick while blocked`.

Shrink/retraction, when explicitly defined, vacates cells at the transition boundary; no entity moves automatically into them during transit.

---

# 10. Feeding

Feeding uses compatibility tags and adjacency/range, not animation collision.

Phase-E order:
1. compute available food outputs from source snapshot;
2. enumerate eligible consumer-source edges;
3. allocate using source selector/capacity;
4. emit satiety gain and source-cost effects;
5. commit in Phase F.

Food/resource conservation is mandatory. Cannibalism/predation remains outside launch scope.

---

# 11. Route hazards

Hazards are deterministic timeline inputs known before launch unless a bounded-discovery contract explicitly withholds part of the information.

Foundation families:
- **H01 Thermal Surge** — heat to hold/zone for declared ticks;
- **H02 Vibration Burst** — stress pressure and/or explicit wake request;
- **H03 Contamination Leak** — contamination to declared cells/zones;
- **H04 Power Brownout** — temporary support power reduction/disable, finalized Phase A;
- **H05 Vent Cycle** — modifies environmental decay/venting;
- **H06 Zone Isolation** — changes propagation across a declared boundary without moving geometry.

Content also defines derived route-profile families (e.g. Thermal Gradient, Maintenance Oscillation) by composing existing inputs; they are not new simulation systems.

---

# 12. Support modules S01–S06

- **S01 Cooler** — powered utility fixture, local heat removal up to capacity.
- **S02 Filter** — powered utility fixture, local contamination removal up to capacity; does not directly erase organism contamination load.
- **S03 Baffle** — physical/boundary support that alters stress transmission/directed relations while occupying spatial opportunity and potentially blocking beneficial relations.
- **S04 Nest Pad** — capacity-1 sleep/recovery support; sleep effects follow explicit trait gating only.
- **S05 Feed Cartridge** — finite conserved food reserve, occupies declared cell/fixture.
- **S06 Monitor Beacon** — information support only; never mandatory for discovery Bronze and never a solver/recommendation engine.

Supports carry space, fixture, power and/or contract-allowance opportunity cost. Powered support behavior is state-independent while powered unless its own data explicitly says otherwise.

Support balance is non-dominance, not equal usage. Across C17–C48, Cooler+Filter may be the certified primary Bronze pair in at most 8 contracts.

---

# 13. Success, failure and objective evaluation

## 13.1 Launch validity
Launch is blocked only by structural invalidity: missing mandatory cargo, illegal overlap/out-of-bounds/orientation/zone placement, exceeded support allowance/power, or explicitly required fixture/link absence.

Known predicted failure, risky adjacency or blocked future growth does not make a structurally legal plan unlaunchable.

## 13.2 Transit fail-fast
Fail-fast is rare and reserved for irreversible cases. Most failures continue when useful so the player can observe the cascade.

## 13.3 Mandatory evaluation
Mandatory conditions are Boolean predicates over final state and timeline facts. All must pass for Bronze/delivery success.

## 13.4 Optional mastery
Silver/Gold may reward welfare, support efficiency, clean control, required arrival states, no blocked growth or contract-specific spatial efficiency.

**Empty-space rule:** unused-cell count is **not** a global/default scoring axis. `EMPTY_CELLS` may appear only as an authored contract-specific predicate where density itself creates a demonstrated dynamic transit tradeoff. No persistent score rewards global empty area.

---

# 14. Causal event model

Every outcome-relevant authoritative change records at least:
- event ID;
- tick;
- phase;
- source entity/hazard/support;
- target entity/cell/channel;
- effect type/rule ID;
- pre-value;
- delta/transition;
- post-value;
- zero, one or multiple parent event IDs;
- display grouping metadata.

Causal Review must reconstruct meaningful chains such as route hazard -> exposure -> threshold transition -> trait output -> downstream failure. Routine propagation can be grouped visually, but stored ancestry is not discarded.

---

# 15. Anti-dominant-strategy mechanical requirements

The architecture must resist:
- isolate everything;
- sedate everything;
- maximize empty space;
- universal buffer/protector;
- Cooler+Filter default;
- one solved zone/growth template.

Counterweights come from beneficial adjacency/feeding/symbiosis, compact/irregular holds, future footprint reservation, route zones/timing, fixture/power scarcity, state-vulnerable living substitutes and explicit contract objectives.

No organism may provide broad unconditional mitigation of all three environmental channels with no meaningful downside.

---

# 16. Determinism invariants

1. Same canonical committed input + versions + seed => identical authoritative result/checksum sequence.
2. Entity iteration order cannot alter commutative outcomes.
3. Non-commutative selection uses documented stable tie-breaks.
4. Frame rate and animation do not affect state.
5. Base transit accepts no planning mutations after commit.
6. Pause/playback speed never changes outcome.
7. Deterministic reconstruction from committed input reproduces the same future.
8. Authoritative arithmetic uses integers/fixed-point with documented rounding.
9. Thresholds occur only at named phase boundaries.
10. Simulation-affecting content carries stable version/hash identifiers.

---

# 17. Edge-case authority

- Simultaneous critical conditions are all stored; UI may choose a primary display reason.
- Effects already emitted from a phase snapshot remain valid even if the source becomes critical later that tick.
- Route hazard Phase A precedes scheduled Phase-B growth.
- Brownout is final before same-tick support effects.
- Multiple threshold crossings preserve all legal condition/state changes from the common snapshot.
- Threshold comparisons are exact integers/fixed-point (`>=`, `<=` as declared), never fuzzy floats.
- Invalid content definitions are rejected before play.
- Sleep never implicitly disables a trait.
- Blocked growth never repeats an unchanged-episode penalty.
- T10 never has an unbounded trigger policy.

---

# 18. Challenge grammar

A strong challenge combines at least two pressure families:
- space/footprint;
- environment;
- relationship;
- time/hazards;
- support scarcity;
- optional objective pressure.

Advanced contracts generally combine 3–4 families, not all six. Difficulty comes from interaction and timing, not opaque rule count.

Generated content must be rejected when static time-zero legality/adjacency alone explains the intended solution, when no Bronze solution is certified, when causal opacity is excessive, or when a dominant support/layout fingerprint repeats beyond content gates.

---

# 19. Worked canonical texture example

Hold: 5x5. Transit: 8 ticks.

Manifest:
- A: 1x1 Heat Emitter + Alarm Emitter, panic threshold 8;
- B: 1x1 Soother, active only under its explicit state gates;
- C: juvenile 1x1 Filter Feeder, grows to 1x2 after satiety condition;
- D: Spore Shedder while contaminated.

Route:
- ticks 3–4 thermal surge on left zone;
- tick 6 vibration burst.

Planning tension:
- A near B can stabilize A, but exposing B to the surge may disable soothing;
- C near D can consume useful contamination, but future growth needs space;
- isolating D removes risk but also removes C's useful relation;
- reserving C's growth cell reduces buffer space around A/B.

Poor-plan causal texture:
1. surge raises A/B exposure;
2. B becomes AGITATED and its explicitly state-gated soothing turns off;
3. A later crosses panic threshold;
4. A's alarm raises local stress;
5. D's state allows contamination shedding;
6. C filters contamination and gains satiety;
7. C queues growth;
8. growth is blocked by an occupied reserved cell;
9. **one** blocked-growth episode consequence fires;
10. vibration adds a later distinct pressure.

The desired texture is simple individual rules producing a temporal interaction problem.

---

# 20. Exposed balance variables

Hold: width/height, blocked mask, zones, fixture locations, propagation/decay parameters.

Route: tick count, hazard start/end, target zone/cells, intensity, support-availability modifiers.

Organism: meter maxima, enter/exit thresholds, recovery, intake coefficients, trait magnitudes/ranges/capacities, growth delay/footprints, feeding rates, delivery thresholds, explicit sleep gates, T10 guard.

Supports: power cost, space/fixture cost, capacity, range, finite reserve.

Contract: allowed supports, power/support allowance, mandatory/Silver/Gold predicates, information-visibility policy.

Exact values are tunable data unless another canonical file freezes a validation profile. Tuning may not change phase order or invariants.

---

# 21. Mechanical acceptance gates

The implementation/graybox must prove:
1. multiple materially different valid layouts exist for representative contracts;
2. future footprint planning is required in representative content;
3. beneficial adjacency is sometimes necessary despite risk;
4. isolate-all, sedate-all, maximum-spacing and universal-buffer strategies fail/inferior on representative advanced content;
5. 12–20 tick cascades can be summarized in <=5 major steps where appropriate while preserving full ancestry;
6. one initial placement change can create a predictable multi-step consequence;
7. deterministic replay yields identical checksum/event sequences;
8. content validator rejects unsolvable/degenerate generated contracts;
9. roughly 6–10 organisms remain readable without constant tooltip use;
10. heat, stress field and contamination create distinct placement decisions;
11. every T10 passes finite-trigger/self-loop tests;
12. simultaneous multi-root failures retain all material parent events;
13. Brownout same-tick support disable is exact;
14. blocked-growth unchanged episode creates one consequence only;
15. asleep/awake enumerations show no implicit trait suppression;
16. no global empty-space reward leaks into campaign scoring.

**Mechanical specification result: FROZEN pending only cross-file contradiction clearance. No further Phase-4 design work remains.**
