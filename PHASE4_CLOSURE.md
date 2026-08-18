# ORGANISM CARGO — PHASE 4 CLOSURE

Status: **CANONICAL VALIDATION EVIDENCE — RECONCILED WITH PHASE 11**
Last updated: 2026-08-15

This file preserves the mechanical validation evidence that originally closed Phase 4. It is not an independent rule authority when later frozen semantics in `GAME_BIBLE.md`, `MECHANICS.md`, `DECISION_ARCHITECTURE.md`, or `PHASE11_FREEZE.md` are more specific.

The original validation profile proved that the A–I deterministic architecture could express readable contracts with finite integer values. Phase-11 reconciliation changes only ambiguous edge semantics; it does not invalidate the validated core loop.

---

# 1. Closure verdict

Phase 4 remains **PASS / CLOSED** because:
1. one global tick order expresses the representative content;
2. every representative contract except the Tier-0 tutorial contains a meaningful post-launch consequence;
3. each foundation support can be useful and inferior in different contexts;
4. no tested layout/support exploit is universally dominant;
5. failures are representable in the causal model;
6. no representative case needs bespoke simulation code;
7. Bronze/Silver/Gold need not reward welfare harm;
8. deterministic replay is defined from the committed state;
9. the content grammar remains intentionally small;
10. Phase-11 edge repairs fit the existing architecture.

No remaining Phase-4 design task exists. Later work is cross-file reconciliation, empirical prototype validation, implementation and QA.

---

# 2. Preserved validation numeric profile

These values are validation scaffolding, not final balance constants.

Authoritative paper domains:
- heat/cell `0..20`;
- stress field/cell `0..12`;
- contamination/cell `0..20`;
- internal stress `0..20`;
- contamination load `0..20`;
- satiety `0..12`;
- support demand/capacity = integer units;
- representative transit length `6..16` ticks.

No probability is used.

## 2.1 Validation heat propagation
From the Phase-C snapshot each cell:
1. keeps its source value;
2. receives `floor(source_neighbor_heat / 4)` from each orthogonal neighbor;
3. loses passive cooling `1`;
4. clamps `0..20`.

## 2.2 Validation stress field
- source cell keeps full source contribution;
- orthogonally adjacent cells receive `floor(source / 2)`;
- distance-2 receives none in this profile;
- prior-tick field is discarded unless explicit persistence exists.

## 2.3 Validation contamination
From the pre-propagation snapshot:
1. sources add contamination;
2. each cell gives `floor(value / 5)` to each orthogonal neighbor;
3. passive decay is `-1` on vent ticks, otherwise `0`;
4. clamp `0..20`.

## 2.4 Meter intake
Unless overridden:
- heat stress gain = `floor(max(0, max_heat_on_occupied_cells - 6) / 2)`;
- stress-field gain = max stress field on occupied cells;
- contamination-load gain = `floor(max_contamination_on_occupied_cells / 3)`;
- CALM/unexposed baseline stress recovery = `-1/tick`;
- METABOLIC satiety loss = `-1` on ticks 2,4,6,...

Meters clamp to their domains.

## 2.5 Representative thresholds
- `agitated_enter = 6`;
- `agitated_exit = 3`;
- `panic_enter = 11`;
- `panic_exit = 7`;
- `contaminated_enter = 8`;
- `contaminated_exit = 4`;
- ordinary contamination delivery ceiling `<=10`;
- critical contamination where used `>=16`.

These may be tuned while preserving hysteresis and phase semantics.

---

# 3. Representative hold vocabulary

## HLD-A Training Crate
5x5; utility fixtures U1 northwest/U2 southeast; bed B1 center-left; power 3; LEFT/CENTER/RIGHT zones.

## HLD-B Split Hold
6x5; blocked `(3,2),(3,4)`; utilities on opposite sides; bed B1 `(2,5)`; baffle-compatible split; power 4; PORT/STARBOARD zones.

## HLD-C Bent Hold
6x6 bounding box with unusable `(5,1),(6,1),(6,2),(1,6),(2,6)`; utilities `(1,1),(6,6),(4,3)`; bed `(2,4)`; power 4; FORE/AFT zones.

---

# 4. Preserved support validation values

## S01 Cooler
Utility fixture; draw 2; removes up to 4 heat/tick at Manhattan <=1; allocation highest heat -> nearest -> coordinate order.

## S02 Filter
Utility fixture; draw 2; removes up to 4 environmental contamination/tick from fixture+adjacent cells; deterministic allocation; no direct internal-load cleanse.

## S03 Baffle
Unpowered physical/boundary support; validation reduction 75% across declared stress boundary with integer floor; blocks directed rays when solid and consumes spatial opportunity.

## S04 Nest Pad
Unpowered capacity-1 bed; validation example: stress <=7 for two qualifying ticks queues ASLEEP; example asleep stress-field intake x0.5; vibration or stress >=10 can wake. Only explicitly sleep-gated traits turn off.

## S05 Feed Cartridge
Unpowered cargo support; reserve 6 food; up to 2 food/tick to eligible adjacent consumers using lowest satiety then ID; remains solid empty.

## S06 Monitor Beacon
Draw 1; no mitigation; reveals only contract-declared bounded information and never success/layout recommendations.

Brownout power is finalized in Phase A; a disabled support has no same-tick effect.

---

# 5. Representative organism profile

- **O01 Ember Pod** — Dot; T01+T03; validation heat +3 CALM/AGITATED, +4 PANICKED; alarm +4 AGITATED/+7 PANICKED.
- **O02 Hushling** — Dot; T04; CALM/awake adjacent target `-3 stress/tick`, capacity 1, highest stress then ID.
- **O03 Silt Grazer** — Dot->Domino; T06+T08; consumes up to 3 contamination/tick; each 2 consumed -> +1 satiety; growth at satiety >=8 for two qualifying ticks.
- **O04 Spore Bell** — Dot; T05+T10; while CONTAMINATED emits +3 contamination/tick; legal contamination-entry pulse +4, finite-guarded.
- **O05 Warmback** — Domino; T01+T09; +2 heat per occupied cell/tick; one adjacent FRAGILE target receives 50% contamination intake.
- **O06 Cradle Moss** — Dot; T04 + feeding-producer grammar; while explicitly eligible/awake provides -2 stress to one adjacent target and 2 edible units/tick.
- **O07 Pulse Mite** — Dot; T03+T10; alarm +3/+6; legal PANICKED-entry pulse +5 heat, finite-guarded.
- **O08 Glass Larva** — Dot->Corner; T07+T08; compatible food up to 2/tick; growth at satiety >=9 for two ticks; mature footprint anchor+forward+right.
- **O09 Ash Sponge** — Domino; T02+T06 plus delayed bounded downside; absorbs up to 3 heat/tick and up to 2 contamination/tick; heavy absorption schedules later +2 stress-field output.

## 5.1 Blocked-growth reconciliation
Older validation wording such as `+N stress and retry next tick while condition remains true` is superseded.

For all growth species:
- a blocked deterministic growth attempt begins one `GROWTH_BLOCKED` episode;
- its configured consequence fires once on episode entry;
- unchanged obstruction does not reapply the same consequence every tick;
- a new episode/consequence requires a relevant legality/occupancy/orientation/body/trigger/retry-boundary change.

The original contracts remain valid because their lesson is future-space causality, not repeated punishment.

---

# 6. Representative contract evidence

## R1 Face Forward — Tier 0
HLD-A, 6 ticks, no hazards/supports. O01/O02/O03. Proves orientation/future-footprint preview. This is the permitted near-static tutorial.

## R2 One Bad Neighbor — Tier 1
HLD-A, 8 ticks, Thermal Surge ticks 3–4 LEFT; O01/O02/O07. Proves route heat -> state transition -> later alarm/pulse.

## R3 Useful Dirt — Tier 2
HLD-A, 10 ticks, contamination leak ticks 4–6; choose Filter or Baffle; O03/O04/O06/O01. Proves useful contamination/feed relation plus future growth. A blocked episode may invalidate welfare/medal, but unchanged obstruction has one episode consequence.

## R4 Wake Window — Tier 3
HLD-B, 12 ticks, vibration tick 5 and Thermal Surge ticks 8–9; Nest Pad + Cooler/Feed option; O06/O08/O01/O02/O05. Proves sleep is not universal safety because explicit sleep gates can remove useful output and wake timing matters.

## R5 Brownout Chain — Tier 4
HLD-C, 14 ticks, contamination leak, Brownout, Thermal Surge, vibration; Cooler/Filter/Baffle/Nest selection; O01/O07/O04/O03/O05/O06/O02. Proves support-priority causal chains and multiple intervention families.

Canonical chain family:
`wrong priority -> Filter off in Phase A -> higher contamination -> organism state/feeding/growth changes -> later social/thermal cascade`.

## R6 No Familiar Template — Tier 6
HLD-C authored transform; 16 ticks; vent, isolation, thermal surge, Brownout, vibration; exactly two supports; O09/O01/O07/O08/O06/O05/O04/O03. Proves bounded uncertainty, information-vs-mitigation, delayed downside and anti-universal-buffer behavior.

Ash Sponge/Pulse Mite interaction is finite because delayed output is scheduled and T10 is bounded.

---

# 7. Paper-simulation conclusions retained

R5 established:
- Phase-A route/power authority precedes support effects;
- contamination persists after a route source ends;
- support loss can create later organism changes without randomness;
- growth never pushes/searches alternatives;
- threshold/pulse order is deterministic;
- targeted retry through priority + future-space reservation can repair the causal chain.

R6 established:
- a helper downside can turn a central buffer cluster into an amplifier;
- zone isolation modifies propagation without moving geometry;
- Monitor can trade mitigation for evidence without solving layout;
- delayed outputs and finite T10 guards prevent infinite within-tick loops.

---

# 8. Exploit conclusions retained

Invalid universal strategies include isolate-all, sedate-all, maximize-empty-space, universal helper, default Cooler+Filter, invariant growth corner and one role-to-zone template.

`EMPTY_CELLS` may exist as a predicate primitive, but empty space is never a global/default reward; it is legal only as an authored contract-specific dynamic density objective.

Every T10 definition uses `once_per_run`, `once_per_episode`, or finite `max_triggers_per_run`.

Sleep disables only explicitly sleep-gated traits.

Simultaneous material causal roots are all stored even if the UI picks a display-first branch.

---

# 9. Closure acceptance evidence

Phase 4 stays closed because:
- the same A–I order expresses all representative cases;
- deterministic arithmetic/selectors avoid iteration-order outcomes;
- advanced cases support multiple intervention families;
- future footprint, beneficial adjacency and state change matter after launch;
- Causal Review can compress cascades while retaining ancestry;
- content validators can reject impossible, static-only, recursive or opaque cases;
- no new simulation subsystem is required by the launch architecture.

**Result: Phase 4 CLOSED. This file is validation evidence, not future-work inventory.**
