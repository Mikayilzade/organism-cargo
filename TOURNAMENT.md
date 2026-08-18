# CONCEPT TOURNAMENT

Last updated: 2026-08-15
Status: **Phase 2 in progress — Round 1 complete**

This file exists because the destructive concept tests are now large enough that keeping them inside `RESEARCH.md` would make external evidence and concept analysis difficult to navigate. `RESEARCH.md` remains the market/reference evidence base; this file is the elimination arena. Final design decisions belong in `GAME_BIBLE.md` only after a concept is locked.

---

# Tournament rules

1. No concept is protected because it sounds exciting.
2. Every finalist receives the same 20-point destructive test.
3. Preliminary Phase 1 scores are discarded when stress testing exposes new risks.
4. A concept can lose despite a high numerical score if its likely prototype is boring, derivative, unreadable, or too expensive.
5. Merges are allowed only when the merged game becomes simpler and stronger. Feature accumulation is not a merge.
6. The winner must eventually survive a primitive prototype test as well as paper analysis.
7. Market comparisons are used to detect occupied territory, not to imitate existing games.

## Current comparison evidence added for Round 1 — 2026-08-15

The targeted scan materially changed the risk picture:

- `Signal Station` is a 2026 Steam title about operating a remote listening station, aligning satellites, analyzing waveforms, decoding an impossible signal, and repairing equipment. This creates direct thematic/presentation proximity to C03.
  - https://store.steampowered.com/app/4007640/
- `Signal Simulator` has already explored a SETI-style observatory with interactive antenna controls, signal detection/decoding, maintenance, and power management.
  - https://store.steampowered.com/app/839310/
- Several 2026 jam/prototype games also use radio/signal-operator fantasies, including `Signal: Offline`, `Operator`, and `The Message`. Individually these are not major commercial competitors, but together they indicate that the signal-desk idea is an obvious design territory rather than a uniquely empty niche.
  - https://dakota-m.itch.io/signal-offline
  - https://duck-bear.itch.io/operator
  - https://mgiuca.itch.io/the-message
- `Modulus: Factory Automation` released in April 2026 and explicitly sells production-line optimization under spatial constraints. `Automate It: Factory Puzzle` also occupies factory-building puzzle territory. C12 therefore must be sold as *diagnosis/minimal intervention*, never as another automation builder.
  - https://store.steampowered.com/app/2779120/
  - https://store.steampowered.com/app/2472770/
- `D1AL-ogue` (2026) uses android repair as a puzzle/story interaction, while current `ReStory` coverage validates ordinary electronics repair as a legible fantasy. C21 needs the mechanical-vs-supernatural diagnostic system to dominate its identity.
  - https://store.steampowered.com/app/4270390/
- `OH DEMON! Fix my TV` (2026) uses a supernatural repair joke/premise, but not the same systemic diagnosis structure proposed for C21. It raises title/theme-comparison risk without invalidating the mechanic.
  - https://store.steampowered.com/app/4191830/
- Reactor language is also occupied by games such as `Feed the Reactor` and the forthcoming `Unstable Nuclear Reactor`; neither appears to use C24's proposed adjacency/orientation engineering model, but the word “reactor” by itself is not a differentiator.
  - https://store.steampowered.com/app/4009730/
  - https://store.steampowered.com/app/4644400/

**Round-1 implication:** concept differentiation must live in the interaction grammar. Theme nouns such as signal, factory, repair, reactor, occult, or operator are not sufficient hooks.

---

# Round 1 — C24 / C03 / C21 / C12

## C24 — Inventory Reactor

### 1. One-sentence store pitch
Engineer compact unstable machines by arranging and rotating modules whose proximity changes power, heat, interference, safety, and chain reactions — then pulse the system and survive the result.

### 2. Ten-second trailer moment
A player rotates a coolant module into the last free slot beside a glowing core. Heat drops, three power links ignite in sequence, a multiplier climbs — then an overlooked interference link overloads a capacitor, an arc jumps two cells, and half the board blacks out while one emergency isolator barely saves the contract.

### 3. Exact 30-second core interaction
- Read a compact contract: required output, maximum heat, banned failure state, optional efficiency target.
- Inspect a 5x5 or 6x6 casing and a small module tray.
- Drag/rotate one module.
- Connection overlays immediately preview possible power/heat/interference relationships without revealing the final dynamic result.
- Press **Pulse/Test**.
- A short deterministic simulation runs.
- Read the failure or success trace.
- Make one informed layout change.

The important action is not “organize inventory.” It is **predict a coupled machine, test the prediction, then improve the configuration**.

### 4. Five-minute loop
1. Accept one machine contract.
2. Understand required outputs/constraints.
3. Inspect casing geometry and supplied modules.
4. Build an initial layout.
5. Pulse-test the machine.
6. Interpret resource flows and fault traces.
7. Reconfigure one or more modules.
8. Achieve safe output.
9. Optionally optimize for fewer modules, lower heat, lower cost, or higher stability.
10. Receive grade/reward and unlock a new rule/module.

### 5. One-session loop
A 25–45 minute session contains roughly 4–8 contracts. Early jobs teach one relationship at a time; later jobs combine them. Between jobs the player chooses a small progression benefit such as a diagnostic overlay, a new module family, an alternate casing, or permission to take higher-risk contracts. Progression should expand decision vocabulary rather than merely add percentage bonuses.

### 6. Hour-10 source of fresh decisions
Freshness must come from combinatorics, not from hundreds of bespoke levels:
- multiple simultaneous resources: power, heat, signal/interference, pressure/charge;
- directional ports;
- modules that transform one resource into another;
- phase/order-sensitive modules;
- modules that activate only above/below thresholds;
- negative adjacency and shielding;
- unstable modules with known conditional behaviors;
- casing geometry that blocks obvious templates;
- contracts with mutually competing requirements;
- damaged or partially fixed starting layouts;
- limited replacement stock;
- optional “minimum intervention” objectives;
- challenge seeds generated from known-solvable systems.

If hour 10 is still just “place the best cooling next to the hottest thing,” the concept has failed.

### 7. Minimum viable content vocabulary
For a meaningful prototype-to-full-game path:
- 4 resource channels;
- 6 port/direction behaviors;
- ~24 foundational module archetypes;
- ~12 advanced/conditional module archetypes;
- 6 casing geometries;
- 10 contract modifiers;
- 6 failure classes;
- 4 optional scoring dimensions.

Launch quantity can later expand, but the core must already feel deep with about 12 modules in graybox.

### 8. Procedural/data-driven content
Good candidates for data-driven generation:
- module definitions and parameters;
- casing masks;
- contract requirements;
- starting damage/configuration;
- available module pool;
- optional constraints;
- target efficiency bands;
- challenge seeds.

A safe generator can begin from a known-valid configuration, mutate/remove/rotate a bounded number of modules, then calculate whether a solution remains reachable under the allowed intervention budget.

### 9. Handcrafted content
Must remain authored:
- the fundamental module families;
- visual language for each resource;
- tutorial sequence;
- unusual milestone contracts;
- major progression unlock order;
- sound design identity;
- a limited set of memorable catastrophic effects.

### 10. One-week graybox prototype
A valid primitive test requires only:
- one 6x6 board;
- draggable/rotatable rectangles;
- 12 module types;
- power, heat, and interference;
- deterministic tick simulation;
- one overlay showing causal links;
- 10 manually defined contracts;
- reset/undo;
- no meta progression;
- placeholder shapes/text only.

The prototype question is: **does testing and revising a layout feel like understanding a machine, or merely solving arithmetic?**

### 11. Likely tutorial problem
Players can be overwhelmed by simultaneous invisible relationships. Every consequence must be traceable. The game needs layered teaching and post-test causal visualization: “A heated B; B crossed threshold; B amplified C; C overloaded D.” Raw meters are insufficient.

### 12. Dominant-strategy / exploit risk
Risks:
- universal low-heat safe template;
- always maximizing empty spacing;
- brute-force testing every placement;
- one module family making others obsolete;
- memorized layouts solving most contracts.

Countermeasures:
- irregular casings;
- contract-specific module pools;
- efficiency/cost constraints;
- interaction thresholds;
- limited pulse tests only if testing remains fun rather than punitive;
- rule combinations that change which layout is optimal.

Do not use randomness merely to defeat solved layouts.

### 13. Repetition failure mode
The game becomes a prettier inventory optimizer where each job feels like the same adjacency puzzle. Repetition is especially dangerous because `Backpack Battles` already proves adjacency as a mature strategic vocabulary. C24 must make **dynamic machine behavior and causal diagnosis** more important than static packing.

### 14. Technical risk
**Moderate-low to moderate.** A deterministic grid graph is tractable. Main complexity lies in:
- stable simulation ordering;
- readable causal traces;
- challenge validation;
- avoiding combinatorial explosion in an automated solver;
- save/version compatibility for data-defined modules.

Avoid continuous physics.

### 15. Art/audio burden
**Low to moderate.** One board/case and reusable modules are efficient. However, the game must make abstract resource changes feel physical through animation, sound, sparks, pulses, fan spin, heat glow, warning lights, and mechanical motion. A dead spreadsheet aesthetic would destroy the hook.

### 16. Steam-comparison / derivative risk
**Moderate.** Risks come from:
- Backpack/inventory adjacency games;
- generic reactor/power-management games;
- forthcoming reactor-themed puzzle titles.

Required differentiation statement:
> This is not an autobattler inventory and not a merge reactor. It is a deterministic compact-machine engineering game where layout creates a dynamic system that you diagnose by pulsing it.

If trailers cannot communicate that distinction, kill or radically rename/reframe it.

### 17. Demo boundary
A demo can contain:
- 8–12 contracts;
- 12–16 modules;
- 3 resource channels;
- 2 casing shapes;
- one advanced conditional rule introduced at the end.

The demo should end immediately after players realize the same parts can behave very differently in a new casing. Do not expose the full module taxonomy.

### 18. Why a player tells a friend
- “I fixed the whole reactor by rotating one tiny relay.”
- “My perfect layout detonated because the coolant loop was feeding interference back into the core.”
- shareable compact solutions invite comparison.

### 19. Stream/short-clip value without explanation
A glowing board, visible chain of energy, escalating alarms, one last-second stable state, or spectacular cascade is legible without lore.

### 20. Kill condition
Abandon C24 if a primitive 12-module version shows either of these after repeated sessions:
1. players mostly solve by trial-and-error placement instead of forming causal predictions; or
2. after learning the rules, a small set of layout templates solves most jobs with minor cosmetic adjustment.

### Round-1 rescore
- H Hook clarity: **5.0**
- D Systemic depth: **5.0**
- S Scope fitness: **5.0**
- M Market distinctiveness: **3.5**
- A Asset efficiency: **5.0**
- T Technical feasibility: **4.5**
- C Clipability: **5.0**

Weighted score: **4.73 / 5**

**Round-1 verdict: ADVANCE.**

The original 4.85 score was too generous on distinctiveness. Despite the downgrade, C24 remains exceptionally strong because the core can be validated with an almost art-free prototype and has a clean path from puzzle clarity to systemic depth.

---

## C03 — Signal Operator

### 1. One-sentence store pitch
Operate a tactile communications desk where you must isolate, decode, authenticate, prioritize, and route overlapping transmissions while interference and protocol conflicts turn every connection into a risk.

### 2. Ten-second trailer moment
Three channels chatter at once. A waveform is isolated, a physical patch cable is moved, a red priority lamp flashes, the player spoofs an ID code, and a routed signal briefly clears — before a hidden carrier hijacks the same line and every meter jumps.

### 3. Exact 30-second core interaction
- Select a noisy channel.
- Tune frequency/filter until a pattern becomes readable.
- Identify one property: source, urgency, authenticity, payload, or destination.
- Consult a compact active-protocol card.
- Patch/route the signal.
- Hear/see the downstream response.
- React if interference or a conflicting signal changes the situation.

### 4. Five-minute loop
1. Receive several transmissions.
2. Separate them.
3. Extract enough information to classify each.
4. Decide what deserves limited bandwidth/attention.
5. Route, hold, reject, spoof, or isolate.
6. Observe consequences and new transmissions.
7. Survive the shift segment with acceptable error rate.

### 5. One-session loop
A 30–45 minute shift gradually increases channel count and protocol complexity. Between shifts, the player unlocks hardware or receives revised procedures that sometimes invalidate old habits. Story should emerge through what the signals imply, but dialogue volume must not become the content engine.

### 6. Hour-10 source of fresh decisions
Potential depth:
- overlapping frequencies;
- bandwidth scarcity;
- delayed consequences;
- spoofed identities;
- signals that interfere with specific equipment;
- changing protocol priority;
- multi-stage routing;
- repeated senders whose behavior can be learned;
- uncertain authenticity;
- timed windows;
- conflicting obligations;
- partial automation that creates new failure modes.

### 7. Minimum viable content vocabulary
- 5 signal properties;
- 4 channel manipulation verbs;
- 6 routing destinations;
- 10 protocol rules;
- 5 interference types;
- 4 urgency classes;
- a small library of reusable audio/visual signal archetypes.

### 8. Procedural/data-driven content
- frequency ranges;
- interference combinations;
- routing constraints;
- protocol permutations;
- sender traits;
- timing windows;
- signal priority mixes.

### 9. Handcrafted content
- tactile desk layout;
- audio identity;
- first teaching cases;
- milestone transmissions;
- narrative framing;
- critical protocol changes.

### 10. One-week graybox prototype
- 4 channels;
- 3 knobs/sliders;
- 6 destinations;
- 6 protocol rules;
- simple synthesized tones or placeholder waveforms;
- 15 generated signal events;
- no 3D room;
- no narrative.

The prototype question is: **is operating the signal itself enjoyable when all mystery/lore is removed?**

### 11. Likely tutorial problem
The interface can become specialist-looking before it becomes understandable. Players need fictional but internally consistent signal concepts, not real telecommunications coursework. Visual alternatives must duplicate audio information for accessibility.

### 12. Dominant-strategy / exploit risk
- always prioritize the highest urgency label;
- wait until information is complete before acting;
- memorize one routing rule table;
- pause/slow time to remove pressure;
- ignore uncertain low-value channels.

The system needs competing priorities and consequences, but arbitrary protocol churn would feel unfair.

### 13. Repetition failure mode
Tune → decode → route becomes a sequence of interface chores. Narrative mystery may hide repetition for a few hours but cannot fix a dull base verb.

### 14. Technical risk
**Moderate.** Core logic is manageable, but simultaneous event scheduling, deterministic timing, audio generation/processing, accessibility duplication, and UI state complexity can create subtle bugs.

### 15. Art/audio burden
**Moderate.** Environment assets are low, but audio is not optional decoration — it is part of the fantasy. The console also needs unusually strong motion/feedback to avoid feeling like forms software.

### 16. Steam-comparison / derivative risk
**High after the targeted 2026 scan.** `Signal Station` now occupies an extremely close one-room analog-console / impossible-signal fantasy. `Signal Simulator` covers SETI-style operation historically, and multiple 2026 jam projects show the same conceptual gravity.

C03 can still be mechanically distinct if it becomes a **real-time routing/protocol strategy game**, but its title, first screenshots, and first trailer seconds would fight an avoidable comparison battle.

### 17. Demo boundary
One full 20–30 minute shift with three escalating protocol layers could work. The problem is that a narrative signal mystery risks either spoiling too much in the demo or misleading players into expecting authored story volume.

### 18. Why a player tells a friend
Potentially: “I had two emergencies and discovered one caller was using another channel as a carrier.” This is weaker and harder to explain than C24/C21 moments.

### 19. Stream/short-clip value without explanation
Meters, knobs, static, and frantic patching can look good, but without context an observer may not understand why a routing decision matters.

### 20. Kill condition
Kill C03 if either:
1. the no-story graybox feels like administrative multitasking rather than pleasurable instrument operation; or
2. a 10-second trailer cannot be made obviously different from `Signal Station` / SETI-console games without adding major extra systems.

### Round-1 rescore
- H: **4.5**
- D: **5.0**
- S: **4.5**
- M: **2.5**
- A: **5.0**
- T: **4.0**
- C: **4.0**

Weighted score: **4.28 / 5**

**Round-1 verdict: ELIMINATE FROM FINALIST BRACKET; retain as an ingredient reference.**

What survives from C03:
- tactile diegetic controls;
- simultaneous information streams;
- protocol conflicts;
- audiovisual causality;
- limited bandwidth/attention as pressure.

These may strengthen another game later without preserving the occupied signal-operator fantasy.

---

## C21 — Machine Exorcist

### 1. One-sentence store pitch
Repair modular haunted machines by proving whether each impossible symptom comes from ordinary component failure or a supernatural rule violation — because replacing the wrong part can make the haunting worse.

### 2. Ten-second trailer moment
A machine rattles and prints nonsense. The player tests a capacitor: normal. The voltage meter points backward only when a brass gear turns. A chalk seal is placed around the gear; every needle snaps to zero, the lights return — then a face briefly appears in the oscilloscope as the repaired machine starts.

### 3. Exact 30-second core interaction
- Observe one or two symptoms.
- Open a modular machine panel.
- Choose one limited diagnostic test.
- Compare the result against known mechanical behavior and discovered occult rules.
- Swap, isolate, rotate, ground, seal, or reroute one component.
- Power-test briefly.
- Read the machine's response and update the diagnosis.

The core must be **inference with physical intervention**, not hidden-object hunting and not generic repair animation.

### 4. Five-minute loop
1. Receive machine and contract symptoms.
2. Inspect exterior clues and panel topology.
3. Run cheap/non-destructive tests.
4. Form a cause hypothesis.
5. Open the relevant subsystem.
6. Apply a mechanical repair or supernatural containment action.
7. Conduct a risky powered test.
8. Correct secondary consequences if necessary.
9. Return machine, salvage it, or declare it unsafe.
10. Earn rating/resources/knowledge based on correctness, damage, unnecessary part replacement, and containment quality.

### 5. One-session loop
A 30–50 minute session contains several jobs of increasing ambiguity. Between jobs:
- buy or calibrate diagnostic tools;
- record newly proven occult laws in a workshop manual;
- unlock machine/component families;
- choose between safe routine jobs and lucrative anomalous jobs;
- manage a very small inventory of replacement parts/containment supplies.

Do not turn the workshop into a generic shop-management simulator.

### 6. Hour-10 source of fresh decisions
The game can remain fresh by combining two fault grammars:

**Mechanical faults**
- open/short circuits;
- leaks;
- jams;
- worn timing;
- misalignment;
- sensor errors;
- unstable power;
- damaged connectors.

**Occult rule violations**
- a component mirrors the state of another;
- measurements lie while a condition is true;
- current flows opposite to indicated polarity;
- a part remembers its previous slot;
- two identical parts cannot coexist safely;
- testing one subsystem alters another;
- a fault moves when observed/powered;
- a component activates according to symbolic adjacency/order rather than wiring alone.

Depth comes from symptoms that can be produced by either family and from combined cases where both are present.

### 7. Minimum viable content vocabulary
- 8 core component archetypes;
- 6 machine subsystem roles;
- 8 mechanical fault types;
- 8 occult rule types;
- 6 diagnostic tools/tests;
- 5 repair verbs;
- 4 containment verbs;
- 4 reusable machine chassis initially.

A full game can expand these, but the prototype must already generate multiple plausible diagnoses from this smaller set.

### 8. Procedural/data-driven content
Strong candidates:
- machine component graph;
- hidden mechanical faults;
- occult modifiers;
- symptom generation;
- available tests;
- replacement-part stock;
- customer constraints;
- optional risk modifiers;
- payout/grade.

Generation strategy: create a valid healthy machine → inject one or more bounded faults/rules → derive observable symptoms → verify that available tests can distinguish at least one safe solution path.

### 9. Handcrafted content
- component visual families;
- major chassis silhouettes;
- tutorial jobs;
- occult rule definitions;
- memorable milestone anomalies;
- workshop identity;
- strong malfunction/exorcism audio;
- a limited amount of flavor text/customer framing.

### 10. One-week graybox prototype
Build it as a 2D panel before any first-person workshop:
- one 8-slot machine graph;
- 10 component cards;
- 4 mechanical faults;
- 4 occult rules;
- 5 diagnostic tests;
- swap/isolate/seal actions;
- deterministic power-test resolution;
- textual symptom log;
- 12 test cases.

Prototype question: **can a player genuinely infer a hidden cause, or do they just try every action until the machine works?**

### 11. Likely tutorial problem
The game asks players to learn both normal machine logic and abnormal laws. It must establish a simple “normal” model first, then violate it one rule at a time. The journal/manual should record discovered rules automatically; memorization should reward mastery but not be mandatory for accessibility.

### 12. Dominant-strategy / exploit risk
Major threats:
- replace every component until fixed;
- spam every diagnostic test;
- always seal everything “just in case”;
- memorize fault/symptom lookup tables;
- restart a job until receiving easier faults.

Controls:
- replacement cost/availability;
- destructive or time-consuming tests;
- containment materials that can themselves alter behavior;
- penalties for unnecessary intervention;
- multiple faults with overlapping symptoms;
- deterministic seeds for scored/challenge jobs.

### 13. Repetition failure mode
Every case becomes “find the bad part.” To prevent this, occult rules must modify **relationships and diagnostic truth**, not merely add spooky visual effects. Some cases should be solved by rerouting or changing observation order, not replacing anything.

### 14. Technical risk
**Moderate.** The system can be discrete and deterministic; the largest risk is validating generated cases and explaining causal chains. Avoid physics-driven disassembly. Use modular panels/chassis and symbolic state transitions.

### 15. Art/audio burden
**Moderate, but controllable.** More demanding than C24/C12 because machines need personality. Scope control:
- shared panel system;
- interchangeable components;
- limited chassis silhouettes;
- stylized rather than photoreal repair;
- reusable anomaly shaders/effects;
- audio and motion carry much of the “alive/haunted” feeling.

### 16. Steam-comparison / derivative risk
**Moderate.** Repair games are occupied. `D1AL-ogue` and `ReStory` reinforce this. `OH DEMON! Fix my TV` also proves that supernatural+repair wording is not automatically unique.

However, the exact mechanical thesis — **ordinary faults and supernatural rules deliberately mimic one another, and the player must distinguish them with limited tests** — remains materially different from ordinary electronics repair, story-based repair minigames, or supernatural comedy.

This distinction must be visible in the first trailer, not explained on a store page paragraph.

### 17. Demo boundary
A strong demo:
- 6–8 jobs;
- first 2 teach normal mechanical diagnosis;
- job 3 introduces the first impossible measurement;
- later jobs combine one mechanical + one occult fault;
- ends just as the player realizes occult rules are systematic and learnable, not random horror events.

### 18. Why a player tells a friend
- “The machine wasn't broken — the meter was cursed and lying whenever the motor stopped.”
- “I fixed the electrical fault and accidentally freed the thing that was keeping the gearbox stable.”
- players can compare weird diagnoses and elegant minimal repairs.

### 19. Stream/short-clip value without explanation
A physical machine reacting impossibly to a sensible repair is visually legible: gauges reverse, one component crawls/rotates, a seal stabilizes the system, lights recover, or a wrong test triggers a controlled supernatural cascade.

### 20. Kill condition
Kill C21 if a graybox reveals either:
1. the best strategy is brute-force replacement/testing rather than inference; or
2. occult rules feel arbitrary enough that failures cannot be predicted after the player has learned the system.

### Round-1 rescore
- H: **5.0**
- D: **5.0**
- S: **4.5**
- M: **4.5**
- A: **4.0**
- T: **4.5**
- C: **5.0**

Weighted score: **4.68 / 5**

**Round-1 verdict: ADVANCE.**

C21 loses a little scope efficiency versus C24/C12 but currently has the strongest emotional identity in Round 1. Its biggest design obligation is to prove that “haunted” means consistent learnable rules rather than random events.

---

## C12 — Micro-Factory Troubleshooter

### 1. One-sentence store pitch
You don't build giant factories: you receive tiny broken production systems, diagnose what is actually wrong, and restore the required output with the fewest possible interventions.

### 2. Ten-second trailer moment
A miniature line misroutes red parts, starves one machine, and jams. The player pauses, toggles one sensor condition, restarts — then the whole miniature factory synchronizes and the target products pour out while a “1 change” perfect-repair badge appears.

### 3. Exact 30-second core interaction
- Observe the target output and current machine state.
- Run the line briefly.
- Inspect bottleneck/error traces.
- Form a hypothesis.
- Change one connection, component state, threshold, sensor rule, or machine parameter.
- Restart from deterministic checkpoint.
- Compare output against the target and intervention budget.

### 4. Five-minute loop
1. Receive a compact broken system.
2. Understand target throughput/quality.
3. Watch one short production cycle.
4. Inspect limited diagnostics.
5. Identify the smallest plausible fault region.
6. Apply one repair/change.
7. Rerun.
8. Refine if needed.
9. Finish when target remains stable for the verification window.
10. Score on correctness, intervention count, downtime, and optional efficiency.

### 5. One-session loop
A session is a set of contracts introducing new components/fault classes. Player progression can unlock advanced diagnostics, but should not make old logic irrelevant. Difficulty grows through coupled systems and ambiguity, not through factories becoming enormous.

### 6. Hour-10 source of fresh decisions
- mechanical jams vs sensor faults vs routing errors;
- intermittent faults;
- buffers hiding upstream problems;
- coupled production loops;
- quality constraints;
- energy/heat limits;
- stale or delayed sensor information;
- intentional redundancies;
- multiple locally valid repairs with different costs;
- minimal-intervention challenges;
- hidden “healthy” configuration that must be inferred rather than rebuilt.

### 7. Minimum viable content vocabulary
- belts/links;
- splitter/merger;
- processor;
- buffer;
- gate;
- sensor;
- source;
- sink/target;
- 8–10 fault mutations;
- 5 diagnostics;
- 4 scoring constraints.

### 8. Procedural/data-driven content
C12 has the cleanest generation strategy in Round 1:
1. generate or load a healthy valid graph;
2. simulate to prove target output;
3. inject one or more bounded faults;
4. confirm the target now fails;
5. retain the original healthy state as a proof of solvability;
6. optionally search for alternative repairs and calculate minimum intervention distance.

This gives procedural challenges without relying on random unsolvable puzzles.

### 9. Handcrafted content
- component/fault taxonomy;
- teaching sequence;
- special contract layouts;
- visual identity;
- progression unlock order;
- high-level campaign framing.

### 10. One-week graybox prototype
Extremely cheap:
- 2D node/link graph;
- 8 component types;
- colored square “products”;
- deterministic ticks;
- 8 fault mutations;
- run/pause/reset;
- change counter;
- 15 known-answer puzzles.

Prototype question: **does diagnosing somebody else's broken system feel satisfying, or does it feel like unpaid software debugging?**

### 11. Likely tutorial problem
Factory-game players are trained to rebuild/optimize freely. C12 must communicate that the existing system is mostly correct and information is valuable. Early jobs should reward observing before editing.

### 12. Dominant-strategy / exploit risk
- rebuild the whole system;
- disconnect suspected areas until only a simple line remains;
- brute-force parameter changes;
- exploit scoring by making a large semantic change count as one UI action;
- memorize standard fault patterns.

The intervention metric must count **semantic modifications**, not clicks. Contracts may restrict editable regions or charge for replaced components.

### 13. Repetition failure mode
Trace bottleneck → find broken node → flip value becomes monotonous. Later problems need fault ambiguity, interacting loops, and misleading downstream symptoms while preserving fair inference.

### 14. Technical risk
**Low to moderate.** Discrete simulation is straightforward. The main sophisticated work is generator validation, minimum-change scoring, and clear trace visualization. This is still materially safer than physics, AI agents, large worlds, or networking.

### 15. Art/audio burden
**Low.** C12 could look polished with a stylized miniature factory board and a small component set. The danger is emotional sterility. Motion, miniature scale, sound, and physical feedback need to make the graph feel like a machine rather than a diagram.

### 16. Steam-comparison / derivative risk
**Moderate.** `Modulus` and `Automate It` confirm factory-puzzle interest but also occupy the build/optimize framing.

C12's required store distinction:
> You inherit a working design with hidden faults. Rebuilding is wasteful. The puzzle is diagnosis and minimum intervention.

If marketing slips into “build, automate, optimize,” the concept has lost its differentiator.

### 17. Demo boundary
This is exceptionally demo-friendly:
- 15–25 compact faults;
- 6 component types;
- first coupled-loop puzzle as the demo climax;
- challenge scoreboard for fewest interventions could create replay without requiring huge content.

### 18. Why a player tells a friend
The intellectual satisfaction is strong but emotionally weaker than C21:
- “The jam wasn't at the jammed machine — one bad sensor two stages earlier was starving the buffer.”
- “I fixed the whole line with one change.”

### 19. Stream/short-clip value without explanation
A tangled failed miniature line snapping into synchronized motion after one change is readable, but less inherently surprising than a reactor cascade or haunted machine behavior.

### 20. Kill condition
Kill C12 if:
1. the graybox consistently feels like debugging work rather than play; or
2. the most satisfying part is free factory building, because that would push the project into a more crowded and much larger genre.

### Round-1 rescore
- H: **4.0**
- D: **5.0**
- S: **5.0**
- M: **4.0**
- A: **5.0**
- T: **5.0**
- C: **3.5**

Weighted score: **4.58 / 5**

**Round-1 verdict: ADVANCE.**

C12 is the safest candidate to prototype and potentially implement, but not currently the most marketable. It survives because a boring graybox would be discovered extremely cheaply, and a fun graybox would provide a powerful systemic foundation.

---

# Round-1 pairwise verdict

## C24 vs C21
- C24: better scope efficiency, cleaner deterministic simulation, easier procedural generation, stronger pure spatial clarity.
- C21: stronger fantasy, more memorable stories, less “strategy UI” feeling, greater authored presentation burden.
- Result: **both advance**. They test different strengths and should not be merged yet.

## C24 vs C12
- C24 is more visually distinctive and clip-friendly.
- C12 has the cleaner challenge generator and the strongest “known healthy state → injected fault → provable repair” pipeline.
- A merge would likely turn C24 into “repair a reactor” and reduce the free spatial-engineering fantasy while making it resemble C21.
- Result: **do not merge**. Borrow C12's minimum-intervention challenge mode and validation methodology later if useful.

## C21 vs C12
- Both are diagnosis games.
- C12 diagnoses deterministic production logic; C21 diagnoses a physical device under two overlapping rule systems.
- Merging them would create an unnecessarily large haunted-factory game.
- Result: **do not merge**. C21 may borrow C12's generation principle: start from a known healthy machine, inject bounded faults, verify diagnostic distinguishability.

## C03 vs the field
C03 is not bad. It loses because current market proximity is avoidable and because its clip requires more contextual explanation. Preserve its best *interaction principles*, not its product identity.

---

# Round-1 ranking

1. **C24 Inventory Reactor — 4.73 — ADVANCE**
2. **C21 Machine Exorcist — 4.68 — ADVANCE**
3. **C12 Micro-Factory Troubleshooter — 4.58 — ADVANCE**
4. **C03 Signal Operator — 4.28 — ELIMINATED from finalist bracket**

The numeric order is not the final tournament result. In particular, C21 may beat C24 once emotional resonance and player-desire tests are weighted more heavily.

---

# What Round 1 changed

1. C03's distinctiveness was materially overestimated in Phase 1. Current 2026 signal-console projects make its market position weaker than its raw mechanics.
2. C24 remains the best pure systems/scope candidate, but “reactor” and adjacency alone cannot carry differentiation. Dynamic causal simulation must be its identity.
3. C21 emerged as the strongest fantasy/word-of-mouth candidate. Its system must prove that supernatural behavior is consistent and learnable.
4. C12 remains the strongest engineering candidate for cheap graybox validation and procedural solvability.
5. No merge reduces complexity enough to justify merging the three survivors.

---

# NEXT TOURNAMENT ACTION

Round 2 must apply the identical 20-point test to:
- **C27 Creature Lab Triage**
- **C13 Organism Cargo**
- **C25 Disaster Dispatcher**
- **C23 Dream Cartographer**

Then:
1. rescore all four after targeted current-comparison research;
2. eliminate at least one unless all four survive an unusually strong test;
3. compare Round-2 survivors against C24/C21/C12;
4. consider reserves C30/C10 only if the eight-finalist tournament reveals a missing strength;
5. do not select the final game until the full finalist bracket has been stress-tested.
