# CONCEPT TOURNAMENT — ROUND 2

Last updated: 2026-08-15
Status: **Round 2 complete; cross-round final comparison pending**

This file continues the destructive tournament begun in `TOURNAMENT.md`. It uses the same 20-point test for the remaining four finalists and records current-comparison evidence separately so the first-round record remains stable.

---

# Current-comparison evidence — 2026-08-15

## C27 — Creature Lab Triage
Nearby territory is occupied, but not by an exact match.

- `Veterinary Clinic Simulator` explicitly centers diagnosis from animal behavior, choosing tests/treatment, clinic upgrades, and unusual illnesses. This means “diagnose animals in a clinic” is not enough differentiation.
  - https://store.steampowered.com/app/1563240/Veterinary_Clinic_Simulator/
- `VetVR Veterinary Simulator` uses real veterinary logic, tests, charts, drugs, and animal cases as a training-oriented simulation.
  - https://store.steampowered.com/app/2210500/VetVR_Veterinary_Simulator/
- `Creature Lab` occupies the mad-scientist / creature-experiment noun space, although its core loop is mutation/experimentation rather than diagnosis.
  - https://store.steampowered.com/app/1309990/Creature_Lab/

**Implication:** C27 can survive only if it is visibly about *strange biology as an inferable rule system under limited tests*, not a veterinary-clinic reskin and not generic monster experimentation.

## C13 — Organism Cargo
A major new comparison materially raises adjacency-packing risk.

- `Outpacked` released April 1, 2026 and is explicitly a grid packing puzzle where items obey logical adjacency constraints such as hot items vs meltable items and fragile items vs soft items. It also includes 61 handcrafted levels and Workshop support.
  - https://store.steampowered.com/app/4012320/

This is dangerously close to the static version of C13. Therefore C13 must not be “pack creatures so incompatible neighbors do not touch.” Its differentiation must be the **transit simulation**: organisms change state over time, influence one another dynamically, and force the player to plan for what the cargo will become rather than merely satisfy a final packing checklist.

## C25 — Disaster Dispatcher
The territory is highly occupied.

- `911 Operator` already established emergency-call triage, police/fire/medical dispatch, limited teams, incidents, and city maps.
  - https://store.steampowered.com/app/503560/911_Operator/
- `Operator: Emergency Dispatcher` released on browser/mobile platforms in June 2026 and focuses on allocating police, ambulances, and firefighters under increasing pressure when not everyone can be saved.
  - https://www.crazygames.com/game/operator
- `DISPATCHED` is a 2026 Steam project about a night emergency operator answering calls, dispatching police/fire/medical units, and handling procedurally generated incidents with horror escalation.
  - https://store.steampowered.com/app/4543060/DISPATCHED/

**Implication:** the first sentence, screenshot, and input loop of C25 overlap current products too heavily. A fictional non-emergency reskin would not solve this unless the core interaction changes substantially.

## C23 — Dream Cartographer
Map manipulation and shifting-space mystery are both proven and increasingly visible.

- `Carto` makes rearranging map pieces alter the world and uses that as its defining puzzle mechanic.
  - https://store.steampowered.com/app/1172450/
- `Blue Prince` (2025) centers shifting rooms, changing floor plans, strategic drafting, mystery, and persistent knowledge; its strong review volume proves player appetite but raises comparison pressure for any “shifting mysterious place” pitch.
  - https://store.steampowered.com/app/1569580/
- `Exit Dream` uses layered dream spaces governed by hidden logic, showing that “dream + hidden spatial rules” is itself not empty territory.

**Implication:** C23 must not manipulate map tiles like `Carto` and must not sell itself as “another shifting mansion.” Its unique thesis must be **mapping as scientific inference**: the map is an executable hypothesis about topology, and correct predictions matter more than collecting rooms.

---

# C27 — Creature Lab Triage

## 1. One-sentence store pitch
Diagnose bizarre living specimens by choosing a few costly tests, inferring hidden biological traits from behavior and reactions, then applying treatments whose side effects depend on the creature's underlying rule set.

## 2. Ten-second trailer moment
A translucent creature shivers blue. The player places one droplet on a sample; three cells split, one turns black. They reject the obvious antifungal treatment, inject a stabilizer instead, and the creature's skin pattern instantly reorganizes while a hidden organ starts pulsing — proving the “disease” was actually a symbiotic state.

## 3. Exact 30-second core interaction
1. Observe 2–4 visible symptoms/behaviors.
2. Review known trait possibilities and current risk.
3. Spend one limited test charge: swab, light, reagent, thermal scan, pulse, food challenge, etc.
4. Read a compact reaction pattern.
5. Eliminate impossible causes or discover a trait interaction.
6. Choose whether to test again, begin treatment, isolate the specimen, or accept uncertainty.
7. Observe immediate treatment response and update the model.

The interesting decision is **which information is worth buying before intervention**, not clicking every medical tool.

## 4. Five-minute loop
- Receive a specimen and contract objective.
- Observe baseline behavior.
- Form 2–4 plausible hypotheses.
- Run the cheapest/highest-information test.
- Narrow diagnosis.
- Decide whether remaining uncertainty is tolerable.
- Apply treatment or containment.
- Watch response over a short deterministic window.
- Correct if a side effect reveals a hidden trait.
- Grade on survival/stability, unnecessary tests, treatment harm, time, and diagnostic confidence.

## 5. One-session loop
A 30–45 minute session contains several cases. Early cases teach one trait family at a time. Later cases combine infection, metabolism, symbiosis, environmental dependency, reproduction state, and anomalous biology. Between cases the player unlocks test methods, lab references, and safe handling protocols — not raw stat bonuses.

## 6. Hour-10 source of fresh decisions
Depth must come from rule interaction:
- symptoms with multiple possible causes;
- traits that suppress/mask other symptoms;
- tests whose result depends on temperature/light/feed state;
- treatment interactions;
- parasites vs symbionts;
- creatures that change phenotype under stress;
- time-dependent disease stages;
- inherited traits;
- incomplete historical information;
- limited samples/tests;
- risks to lab environment or neighboring specimens;
- cases where “cure everything” is worse than maintaining a stable equilibrium.

If hour 10 is still symptom lookup → matching drug, kill the concept.

## 7. Minimum viable content vocabulary
For a meaningful graybox:
- 8 hidden trait archetypes;
- 8 condition/disease archetypes;
- 6 observable symptom channels;
- 6 tests;
- 8 treatments/interventions;
- 4 environmental variables;
- 4 side-effect classes;
- 6 creature body-plan templates represented initially as icons/state panels.

Full visual creature variety can be layered later; systemic variety must work first.

## 8. Procedural/data-driven content
Strong candidates:
- trait combinations;
- hidden condition;
- symptom manifestation rules;
- test reaction tables;
- treatment effectiveness and side effects;
- environmental modifiers;
- case constraints;
- optional grading objectives.

Generation should start from a valid biological state, inject a bounded condition, derive observations, and verify that the available test set can distinguish at least one safe treatment path.

## 9. Handcrafted content
Must be authored:
- foundational biology grammar;
- visual symptom language;
- tutorial cases;
- rare milestone species;
- expressive treatment reactions;
- lab identity;
- a small set of memorable “impossible biology” rules.

## 10. One-week graybox prototype
No 3D clinic.
- one specimen state panel;
- 8 traits;
- 5 conditions;
- 5 tests;
- 6 treatments;
- deterministic reaction matrix;
- 20 generated known-answer cases;
- hypothesis checklist;
- costs for tests and harmful treatment;
- simple text/icon feedback.

Prototype question: **does choosing the next test feel like information strategy, or does the player simply exhaust the test list?**

## 11. Likely tutorial problem
Players need to learn fictional biology without feeling asked to study a manual. Establish 2–3 normal principles, show cause/effect visually, then introduce exceptions that are consistent. The lab notebook should automatically record proven relationships and let players filter observations.

## 12. Dominant-strategy / exploit risk
Threats:
- run every test;
- use broad-spectrum treatment first;
- restart cases after seeing hidden information;
- memorize symptom-to-condition tables;
- always isolate before doing anything.

Controls:
- test cost/time/sample scarcity;
- some tests perturb biology;
- broad-spectrum treatment causes specific tradeoffs;
- multi-trait ambiguity;
- scored deterministic seeds;
- treatment success depends on trait interactions, not condition label alone.

## 13. Repetition failure mode
The game becomes a reskinned medical multiple-choice quiz. The antidote is to make *biology relational*: treatment changes the system, test order matters, and the right outcome may be stable coexistence rather than “remove disease.”

## 14. Technical risk
**Moderate.** The discrete hidden-state model is tractable. Hard parts are case validation, causal explanation, avoiding opaque probability, and later expressive creature animation. Keep core rules deterministic or bounded-probability with clearly communicated uncertainty.

## 15. Art/audio burden
**Moderate.** Higher than C24/C12. Creatures need enough expressiveness that diagnosis feels embodied. Scope strategy:
- few modular body plans;
- layered symptom overlays;
- reusable animation states;
- strong sound cues;
- stylized lab presentation.

Do not require unique animation sets for every species.

## 16. Steam-comparison / derivative risk
**Moderate.** Veterinary diagnosis exists, and `Creature Lab` occupies the noun space. Required distinction:
> This is not a vet clinic. The patient is a puzzle system whose hidden biology changes what tests and treatments mean.

The store/trailer must show a strange rule interaction within seconds.

## 17. Demo boundary
- 6–8 cases;
- 3 trait families;
- 4 tests;
- 5 treatments;
- first multi-trait case as the climax;
- end when the player realizes two creatures with identical symptoms can require opposite treatments because of hidden biology.

## 18. Why a player tells a friend
- “I thought it was infected, but the parasite was the only thing keeping its metabolism stable.”
- “The obvious treatment made it worse because that species processes heat backwards.”
- emotionally memorable creature recovery adds more word-of-mouth than abstract factory repair.

## 19. Stream/short-clip value without explanation
A strange creature visibly reacting to a test or unexpectedly transforming after a treatment is strong. However, the reasoning behind the correct choice may need overlays to be legible to observers.

## 20. Kill condition
Kill C27 if:
1. optimal play is always “run all tests then pick known treatment”; or
2. without bespoke creature art the graybox has little emotional pull and the project would require a large asset/animation budget to become fun.

### Round-2 rescore
- H: **5.0**
- D: **4.8**
- S: **4.3**
- M: **4.2**
- A: **3.8**
- T: **4.2**
- C: **4.7**

Weighted score: **4.55 / 5**

**Round-2 verdict: ADVANCE TO CROSS-ROUND COMPARISON.**

C27 survives because it combines information strategy with emotional feedback. It remains below C21/C24 on scope certainty, and it must clearly escape veterinary-sim presentation.

---

# C13 — Organism Cargo

## 1. One-sentence store pitch
Pack a tiny transport hold with living cargo that eats, heats, infects, calms, grows, attracts, reproduces, and panics during the trip — then launch and watch whether your plan survives the journey.

## 2. Ten-second trailer moment
The player wedges a sleepy blue organism between a heater and an aggressive larva, closes the cargo doors, and launches. During transit the blue one absorbs heat, doubles in size, blocks ventilation, the larva wakes and starts biting its neighbor — then a soothing spore creature triggers and the whole hold stabilizes one tick before arrival.

## 3. Exact 30-second core interaction
- Read the route duration and hazards.
- Inspect 4–8 organisms and known traits.
- Place/rotate them in a small slot/grid hold.
- Preview only *known direct influences*, not the full future.
- Commit/launch.
- Transit runs in discrete ticks.
- Organisms change state and affect neighbors/hold systems.
- Review causal timeline if failure occurs.
- Repack with a specific prediction.

The game is not packing to satisfy static rules. It is **packing an initial state for a dynamic ecology under transit**.

## 4. Five-minute loop
1. Accept cargo contract.
2. Inspect route hazards and organism manifests.
3. Learn or infer traits.
4. Pack limited space.
5. Select optional equipment such as vent, divider, feeder, dampener.
6. Launch.
7. Observe 10–30 second transit simulation.
8. Diagnose cascade/failure.
9. Repack or change one support module.
10. Deliver with survival/condition/efficiency rating.

## 5. One-session loop
A 30–45 minute session contains several shipments. Routes introduce new conditions: heat spikes, darkness, vibration, radiation, low gravity, delay, customs constraints, limited power. New organisms expand the interaction graph. Player progression unlocks knowledge, route licenses, hold modules, and harder contracts rather than permanent power creep.

## 6. Hour-10 source of fresh decisions
- trait combinations and phase changes;
- growth changing spatial occupancy;
- feeding chains;
- predator/prey distraction;
- stress propagation;
- symbiosis;
- infection/contagion;
- temperature and gas exchange;
- route events;
- timed activation;
- organisms that produce resources needed by others;
- organisms that change traits after feeding/sleeping;
- equipment consuming scarce hold power/space;
- uncertain traits for newly discovered species;
- optional “no sedation / no divider / all alive” high-score objectives.

The core has a natural “prepare → simulate → explain → improve” rhythm.

## 7. Minimum viable content vocabulary
- 16 foundational organism trait modules;
- 8 state transitions;
- 5 environmental channels: heat, gas, light, stress, contamination;
- 6 support-module types;
- 5 hold geometries;
- 8 route modifiers;
- 6 contract scoring dimensions.

Individual organisms should be compositions of trait modules, not bespoke code.

## 8. Procedural/data-driven content
Excellent candidates:
- organism manifests;
- trait combinations;
- route modifiers;
- hold geometry;
- available support modules;
- scoring objectives;
- starting organism states.

Generation can simulate candidate manifests and reject impossible/degenerate cases. Later, a solver can search for at least one survivable arrangement or support-module choice.

## 9. Handcrafted content
- trait grammar;
- readable creature silhouettes;
- core animations/state reactions;
- route/hazard visual language;
- tutorial contracts;
- milestone organisms;
- cargo-hold art/audio identity.

## 10. One-week graybox prototype
- 5x5 slot grid;
- 10 creature tokens;
- 10 modular traits;
- heat/stress/contamination;
- growth and feeding;
- 3 support modules;
- deterministic 12-tick transit;
- causal event log;
- 15 manifests with known successful layouts.

Prototype question: **does the player form a plan about future organism behavior, or merely rerun shipments until lucky?**

## 11. Likely tutorial problem
Dynamic adjacency is harder than static packing. The interface must distinguish current effects from projected conditional effects. Early organisms should have one obvious trait each before composite species appear. Failure timeline needs clear “A heated B → B woke → B emitted spores → C panicked” causality.

## 12. Dominant-strategy / exploit risk
Threats:
- isolate every organism;
- sedate everything;
- maximize empty space;
- always use the same “buffer creature” between hazards;
- brute-force layouts;
- sacrifice cheap organisms to save expensive ones if scoring ignores welfare.

Countermeasures:
- small holds;
- contracts requiring density/efficiency;
- support-module power limits;
- some organisms need interaction;
- scoring includes condition/welfare;
- route-specific constraints;
- organisms whose safe state depends on mutual proximity.

## 13. Repetition failure mode
If transit outcomes are just a static adjacency checklist played as an animation, C13 collapses into `Outpacked`-like territory. State changes must matter: growth, timing, resource production, environmental feedback, and interaction chains are non-negotiable.

## 14. Technical risk
**Moderate-low to moderate** if fully discrete. Avoid freeform physics. A grid/slot graph plus deterministic tick simulation is tractable. Hard parts are solvability checking, causal UI, and visualizing growth/behavior without clipping or excessive animation complexity.

## 15. Art/audio burden
**Moderate.** Creature expressiveness is required but can be modular:
- 6–8 body silhouettes;
- color/pattern/accessory variants;
- reusable state animations: calm, stressed, feeding, sleeping, infected, growing, emitting;
- strong hold sounds and route events.

It should look alive without becoming a creature-collection content treadmill.

## 16. Steam-comparison / derivative risk
**Moderate after `Outpacked` discovery.** Static packing constraints are occupied. The required differentiation statement is:
> You do not solve the hold when the doors close. You choose the starting conditions of a living system, then transit changes every relationship.

If the trailer can be mistaken for static luggage/inventory packing, kill or reframe.

## 17. Demo boundary
- 10–12 organisms built from 8 traits;
- 2 hold shapes;
- 3 route hazards;
- 6 contracts;
- final demo contract introduces a creature that grows and changes adjacency mid-transit.

This single reveal should prove why the game is not a static packing puzzle.

## 18. Why a player tells a friend
- “My cargo ate itself because the heater woke the wrong creature.”
- “I used the animal everyone hated as a stress absorber and saved the shipment.”
- “The one creature I thought was useless grew into the perfect divider halfway through the trip.”

The system naturally creates compact stories.

## 19. Stream/short-clip value without explanation
Very strong. A colorful hold visibly going from calm to cascading chaos and then stabilizing is readable immediately. It is arguably the strongest pure clip candidate of Round 2.

## 20. Kill condition
Kill C13 if:
1. the best layouts can be solved almost entirely from static adjacency before launch; or
2. the transit phase is mainly spectacle rather than a deterministic consequence the player can learn to predict.

### Round-2 rescore
- H: **5.0**
- D: **4.8**
- S: **4.5**
- M: **4.4**
- A: **4.2**
- T: **4.4**
- C: **5.0**

Weighted score: **4.64 / 5**

**Round-2 verdict: ADVANCE TO CROSS-ROUND COMPARISON.**

C13 becomes much stronger when treated as a deterministic transit ecology rather than a packing puzzle. `Outpacked` forces this distinction and makes it healthier: dynamic transformation is now a mandatory pillar.

---

# C25 — Disaster Dispatcher

## 1. One-sentence store pitch
Manage a compact city crisis board where incomplete reports arrive over time, limited specialist teams must be committed before you know everything, and unattended incidents cascade into new problems.

## 2. Ten-second trailer moment
Three incident cards flash. A fire crew is sent across town, then new information reveals the “small” industrial alarm was chemical. Roads close, an ambulance reroutes, a power outage spreads, and the player cancels one response to save a hospital before its backup fails.

## 3. Exact 30-second core interaction
- receive/update incidents;
- inspect uncertainty and severity;
- choose a team and commitment duration;
- route/dispatch;
- new information changes expected value;
- decide whether to continue, reinforce, abort, or redirect.

Mechanically sound, but this exact loop is already recognizable from current dispatcher games.

## 4. Five-minute loop
Prioritize incidents, allocate teams, react to incomplete information, absorb cascading consequences, and finish a shift with a city-health score.

## 5. One-session loop
Escalating shift with evolving team capabilities and city-state modifiers. Campaign could carry consequences across shifts.

## 6. Hour-10 source of fresh decisions
Potentially strong through:
- hidden incident types;
- travel/network constraints;
- team specialization;
- cascading infrastructure;
- weather;
- public panic;
- simultaneous priorities;
- false/late information;
- mutually exclusive rescues.

The system is deep; originality is the problem.

## 7. Minimum viable content vocabulary
- 6 incident classes;
- 5 team types;
- 5 infrastructure nodes;
- 8 cascade relationships;
- 5 information states;
- 4 route constraints.

## 8. Procedural/data-driven content
Excellent: incident timing, hidden severity, location, cascade rules, team availability, travel times, infrastructure dependencies.

## 9. Handcrafted content
Core cascade grammar, tutorial, city-map visual identity, incident framing, ethical tone.

## 10. One-week graybox prototype
A node map, incident cards, 4 team types, travel timers, hidden incident states, cascade graph, 20 generated shifts. Very cheap to test.

## 11. Likely tutorial problem
Players need to understand probabilistic/uncertain information without feeling punished by hidden dice. Confidence and consequence ranges must be explicit.

## 12. Dominant-strategy / exploit risk
Always hold teams centrally, overcommit to highest severity, reload after hidden information, ignore low-scoring populations, discover one optimal reserve ratio.

## 13. Repetition failure mode
Colored incidents pop → drag matching unit → wait. This is the exact risk existing dispatcher titles already face.

## 14. Technical risk
**Low to moderate.** Discrete scheduling and graph simulation are feasible.

## 15. Art/audio burden
**Low to moderate.** Mostly board/UI, but calls/incidents may create authored audio/text burden if used heavily.

## 16. Steam-comparison / derivative risk
**Very high.** `911 Operator`, current browser `Operator: Emergency Dispatcher`, and 2026 Steam `DISPATCHED` all occupy the immediate fantasy and verbs. A horror twist is already being used by `DISPATCHED`. A realistic frame is already occupied by `911 Operator`.

## 17. Demo boundary
Easy technically, but hard commercially: a representative shift would also expose most of the core and invite direct comparison with incumbents.

## 18. Why a player tells a friend
Cascading “saved X but lost Y” stories are strong, but not uniquely attributable to this concept.

## 19. Stream/short-clip value without explanation
Moderate. A board full of incidents conveys pressure, but individual dispatch decisions require context.

## 20. Kill condition
The current market scan itself satisfies a near-kill condition: if the product can be accurately described to a player as “911 Operator with deeper cascading systems,” the differentiation burden is too high for the value gained.

### Round-2 rescore
- H: **4.7**
- D: **4.8**
- S: **4.7**
- M: **2.0**
- A: **4.8**
- T: **4.6**
- C: **3.8**

Weighted score: **4.20 / 5**

**Round-2 verdict: ELIMINATE FROM FINALIST BRACKET.**

Preserve as transferable ingredients only:
- delayed/incomplete information;
- limited specialist resources;
- commitment before certainty;
- cascade graphs;
- rerouting under changing state.

These could strengthen C13, C21, C24, or future scenario generation without preserving the emergency-dispatch product identity.

---

# C23 — Dream Cartographer

## 1. One-sentence store pitch
Map a small impossible place by drawing connections you believe are true; the map becomes an executable hypothesis, predicting where doors lead and which routes will exist when hidden spatial rules change.

## 2. Ten-second trailer moment
The player draws a connection between a red door and a spiral room. The paper map pulses, they step through the red door, and instead of the expected hall the room folds overhead and returns them behind themselves. They erase one assumption, mark “mirrors north when bell rings,” ring the bell, redraw the route, and the topology snaps into agreement.

## 3. Exact 30-second core interaction
- enter/observe one compact room;
- note landmarks, door symbols, orientation, and current global condition;
- predict where one exit should lead based on discovered laws;
- encode a connection or rule annotation on the map;
- traverse the exit;
- receive immediate confirmation/contradiction;
- update the hypothesis.

The core verb is **predict topology**, not collect map tiles.

## 4. Five-minute loop
1. Explore a few rooms.
2. Record observations.
3. Infer one spatial law.
4. Draw/test a route prediction.
5. Reach a previously inaccessible anchor.
6. Discover a rule modifier.
7. Revise map model.
8. Use the corrected model to reach a target or escape a loop.

## 5. One-session loop
A 30–60 minute expedition through one compact rule set. Progress is primarily knowledge. Between expeditions the player gains tools for expressing more complex map relations — layers, state tags, conditional arrows — while new regions introduce rule families rather than larger worlds.

## 6. Hour-10 source of fresh decisions
- doors keyed by symbols rather than physical direction;
- global state changes;
- rooms with rotational symmetry;
- conditional one-way connections;
- topology depending on traversal history;
- paired/linked rooms;
- loops that close only under specific states;
- false visual orientation;
- limited anchor points whose positions are invariant;
- map predictions that can be combined into route optimization;
- discovered laws that interact across layers.

The challenge must remain inferable. Arbitrary procedural weirdness is fatal.

## 7. Minimum viable content vocabulary
- 8 room archetypes;
- 6 door/exit symbol types;
- 8 topology rule operators;
- 4 global state variables;
- 5 invariant landmark types;
- 4 mapping annotation tools;
- 4 objective types.

## 8. Procedural/data-driven content
Possible but dangerous:
- choose a small set of topology laws;
- generate room graph under those laws;
- choose anchors/objectives;
- simulate reachable states;
- ensure observations exist that allow inference;
- reject ambiguous or unsolvable seeds.

This requires stronger validation than C12/C24 because “solvable” is not enough — it must also be *fairly inferable*.

## 9. Handcrafted content
- rule operators;
- visual clue grammar;
- tutorial expeditions;
- landmark identity;
- milestone spaces;
- map UI;
- sound cues for impossible transitions.

## 10. One-week graybox prototype
- 12 text/shape rooms;
- 4 exit symbols;
- 4 hidden topology rules;
- paper-like node map;
- draw/erase connections;
- traverse button;
- deterministic transition log;
- 8 manually authored rule scenarios.

No 3D exploration is required to test the thesis.

Prototype question: **does making and falsifying spatial hypotheses feel satisfying, or does it feel like manually documenting a puzzle the game already knows?**

## 11. Likely tutorial problem
Players may not know what belongs on the map. The map language must be expressive but constrained. Early levels should provide auto-marked observations while the player only chooses conclusions; later they gain freedom. Do not require handwriting recognition or freeform natural-language notes.

## 12. Dominant-strategy / exploit risk
- brute-force every door;
- screenshot/external spreadsheet mapping;
- exhaustive traversal instead of inference;
- mark every possible connection;
- exploit reset to test for free.

Countermeasures must reward prediction and route economy, but should not punish curiosity. Some information must be accessible only under costly state changes so inference saves meaningful effort.

## 13. Repetition failure mode
Observe room → draw line → test door becomes clerical. New rule operators must change what a “map” means, not merely add more nodes. Later puzzles should involve conditional topology and route planning, not scale.

## 14. Technical risk
**Moderate to high relative to finalists.** Discrete topology itself is easy; fair generation and clear stateful visualization are not. If freeform first-person exploration is added too early, asset burden rises sharply. Keep rules/node graph primary and presentation modular.

## 15. Art/audio burden
**Moderate.** Can be kept efficient through reusable rooms and strong impossible-transition effects. However, discovery fantasy weakens if every room is an abstract box. Needs enough environmental identity to support memory and wonder.

## 16. Steam-comparison / derivative risk
**Moderate-high.** `Carto` owns map manipulation; `Blue Prince` strongly occupies shifting-place mystery. Required distinction:
> The player does not rearrange rooms and does not draft them. The map is a predictive model of rules that already govern the place.

This is cognitively distinctive but harder to sell in a 10-second clip than C13/C21/C24.

## 17. Demo boundary
One 30–45 minute expedition:
- 8 rooms;
- 3 rule operators;
- one global state change;
- final objective requires predicting a route through a topology never traversed before.

That final prediction is the proof-of-concept moment.

## 18. Why a player tells a friend
- “I realized the doors weren't connected to rooms — they were connected to the *last symbol I had crossed*.”
- “I drew a route through rooms I had never visited and it actually worked.”

Strong intellectual word-of-mouth, weaker immediate emotional hook.

## 19. Stream/short-clip value without explanation
Moderate. Impossible space can look striking, but the cleverness of prediction may require narration or map overlay. A map line glowing and a room transition proving it right helps.

## 20. Kill condition
Kill C23 if:
1. players prefer brute-force exploration to using the map model; or
2. procedural rule combinations cannot reliably produce both solvability and fair inferability without heavy authored-case work.

### Round-2 rescore
- H: **4.3**
- D: **5.0**
- S: **4.0**
- M: **4.2**
- A: **4.5**
- T: **3.8**
- C: **4.0**

Weighted score: **4.34 / 5**

**Round-2 verdict: ADVANCE TO CROSS-ROUND COMPARISON, BUT AS A HIGH-RISK OUTLIER.**

C23 survives because it offers a genuinely different cognitive fantasy from the compact-workbench cluster. It should lose quickly in the next round if a primitive map-only graybox feels clerical or if fair generation proves too fragile.

---

# Round-2 ranking

1. **C13 Organism Cargo — 4.64 — ADVANCE**
2. **C27 Creature Lab Triage — 4.55 — ADVANCE**
3. **C23 Dream Cartographer — 4.34 — ADVANCE, HIGH-RISK**
4. **C25 Disaster Dispatcher — 4.20 — ELIMINATED**

The ranking is not the final product decision. C13/C27 benefit from emotional/visual legibility; C23 survives mainly to prevent the tournament from overfitting to workplace diagnosis games.

---

# Cross-round field after all eight finalist stress tests

## Strong survivors
- **C24 Inventory Reactor — 4.73**
- **C21 Machine Exorcist — 4.68**
- **C13 Organism Cargo — 4.64**
- **C12 Micro-Factory Troubleshooter — 4.58**
- **C27 Creature Lab Triage — 4.55**

## High-risk survivor
- **C23 Dream Cartographer — 4.34**

## Eliminated
- **C03 Signal Operator — 4.28** — avoidable current-market proximity.
- **C25 Disaster Dispatcher — 4.20** — direct fantasy/verb overlap with established and 2026 dispatcher products.

---

# Cross-round observations

## 1. The strongest repeated structure is now explicit
Four of the five strongest candidates use a common rhythm:

**inspect current state → form causal hypothesis → make a bounded intervention/setup → run/observe deterministic consequences → explain result → improve.**

That rhythm appears in C24, C21, C13, C12 and partly C27. This may be the actual design opportunity underneath the themes.

## 2. Dynamic state change is a stronger differentiator than static arrangement
`Outpacked` materially weakens any static version of C13, just as backpack/inventory games constrain C24. Both become stronger when the arrangement is only the *initial condition* for a dynamic simulation.

## 3. Emotional identity separates C21/C13/C27 from C24/C12
- C21: haunted machinery, expressive malfunctions.
- C13: living cargo, visible chaos and recovery.
- C27: patient/specimen attachment and treatment outcomes.
- C24: stronger pure system and spectacle, weaker emotional character.
- C12: strongest engineering/solvability, weakest fantasy.

## 4. C23 is strategically useful even if it later dies
It tests whether the project should remain a compact job/workbench game. If C23 cannot beat the leaders on primitive feel, the opportunity hypothesis becomes much stronger.

## 5. No reserve is needed yet
C30 Ruleforge remains mechanically excellent but emotionally weak. C10 Anomaly Warehouse remains vulnerable to sorting-wave comparison. Neither repairs a missing capability in the six-survivor field.

---

# NEXT ACTION

Run the **cross-round final tournament** before locking a product thesis.

The next stage should:
1. compare C24, C21, C13, C12, C27, and C23 head-to-head on a stricter final matrix that adds emotional desire, first-minute pleasure, teaching burden, prototype cost, demo strength, content scalability, market defensibility, and implementation ambiguity;
2. define a tiny primitive graybox experiment for each that can be reasoned about consistently even before code exists;
3. perform “theme removal” tests — whether the underlying decisions remain enjoyable with plain symbols;
4. perform “theme replacement” tests — whether the mechanic is strong enough that changing the nouns does not destroy it, while still identifying which theme adds the most desire;
5. eliminate down to **2–3 product candidates**;
6. then perform a final pairwise synthesis/rejection pass and select exactly one concept unless evidence demands a real prototype before selection;
7. if a real prototype is required, write a minimal validation specification rather than starting the production codebase;
8. update `STATUS.md`, then begin Phase 3 only after the winner is justified.

Do not declare the project complete. No game is remotely fully specified yet.