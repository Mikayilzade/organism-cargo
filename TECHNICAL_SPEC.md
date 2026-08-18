# ORGANISM CARGO — TECHNICAL IMPLEMENTATION SPECIFICATION

Status: **CANONICAL PHASE 8 — TECHNICAL ARCHITECTURE LOCKED**
Last updated: 2026-08-15
Production code started: **NO**

This file defines how the locked Organism Cargo design is to be implemented without changing its gameplay. It is subordinate to the product thesis in `GAME_BIBLE.md`, the authoritative rules in `MECHANICS.md`, the player-decision rules in `DECISION_ARCHITECTURE.md`, and the canonical content/UX/commercial specifications.

The central technical invariant is:

> **Authoritative gameplay is a deterministic, discrete, data-defined simulation that can run headlessly without rendering, audio, input timing, or frame rate.**

Any implementation shortcut that makes animation, physics, unordered collection iteration, wall-clock timing, or platform-dependent floating-point behavior authoritative violates this specification.

---

# 1. Engine and runtime direction

## 1.1 Engine decision

**Use Godot 4.7.1 stable as the initial implementation baseline.**

Evidence checked 2026-08-15:
- Godot's official archive lists `4.7.1-stable` released 2026-07-14 while 4.8 remains development-only.
- Godot's stable documentation is on the 4.7 branch.

Why Godot fits this project:
- first-class 2D/UI workflow matches the grid/inspector/timeline-heavy game;
- project does not require high-end 3D rendering, large-world streaming, or AAA tooling;
- GDScript permits rapid AI-assisted iteration while remaining readable for a small codebase;
- headless/test-oriented simulation can be kept separate from the scene tree;
- Windows/Linux export path is compatible with PC/Steam-first and Steam Deck goals;
- no engine royalty or backend requirement is introduced.

Do **not** start on Godot 4.8 development builds. A later stable engine upgrade is allowed only behind a green regression suite and deterministic replay comparison.

## 1.2 Language decision

Primary implementation language: **typed GDScript**.

Rules:
- use explicit static types on public APIs and authoritative state fields;
- warnings treated seriously in CI/build validation;
- simulation code must not depend on scene Nodes;
- avoid dynamic dictionaries inside the hot authoritative kernel after content loading where a typed value object is reasonable;
- C# is not required for launch. Introduce native/C# code only if profiling demonstrates an actual bottleneck or platform integration gap.

## 1.3 Rendering model

2D authoritative layout + 2D presentation.

The hold is rendered from grid coordinates. Organisms may use layered sprites, skeletal/2D animation, shader effects, particles, and tweening, but their presentation transforms are consumers of authoritative state only.

No rigid-body or navigation simulation determines organism occupancy, adjacency, exposure, growth, targeting, or contract outcomes.

---

# 2. Repository / project structure

Target structure:

```text
/project.godot
/src
  /app              # composition root, boot, global services
  /state            # top-level app/game state machine
  /sim              # pure deterministic simulation kernel
    /model           # immutable defs + mutable runtime state classes
    /phases          # A..I canonical tick phases
    /traits          # trait evaluators by foundation family
    /effects         # effect records, aggregation, target selection
    /predicates      # contract/objective evaluation
    /causality       # events, links, trace building
    /checksum        # canonical serialization/hash
  /planning         # placement legality, commands, undo/redo
  /content          # loading, typed conversion, validation
  /generator        # challenge construction, mutation, validation
  /campaign         # unlock graph, discovery, medals
  /save             # profiles, atomic persistence, migrations
  /ui               # presenters/controllers, focus/input abstraction
  /audio            # event-to-audio presentation
  /platform         # Steam abstraction, OS paths, cloud hooks
  /debug            # trace viewer, injectors, debug profiles
/scenes
  /shell
  /campaign
  /contract
  /review
  /settings
/ui
/assets
/content
  /species
  /traits
  /supports
  /body_plans
  /holds
  /hazards
  /routes
  /contracts
  /campaign
  /challenges
/localization
/tests
  /unit
  /simulation
  /content
  /generator
  /save
  /integration
  /fixtures
/tools
  /validators
  /batch_sim
```

Boundary rules:
- `/src/sim` imports no scene or presentation code.
- `/src/ui` may read snapshots/events but never mutate simulation internals directly.
- `/content` contains data, not executable per-species scripts.
- all platform calls are behind `/src/platform`.
- tests can instantiate the simulation without creating a visible window.

---

# 3. Authoritative application state machine

Exactly one top-level `AppStateMachine` owns transitions. Screens may request transitions; they do not change global state independently.

Canonical states:

1. `BOOT`
2. `FIRST_RUN_PREFLIGHT`
3. `TITLE`
4. `CAMPAIGN_MAP`
5. `CONTRACT_BRIEF`
6. `PLANNING`
7. `LAUNCH_CONFIRM`
8. `TRANSIT_PLAYBACK`
9. `CAUSAL_REVIEW`
10. `RESULTS`
11. `CHALLENGE_SELECT`
12. `CODEX`
13. `SETTINGS`
14. `CAMPAIGN_COMPLETE`
15. `SAVE_RECOVERY`
16. `FATAL_CONTENT_ERROR` for development/validation failure only.

`PAUSE` is an overlay/substate of playback/menu contexts, not a separate simulation state.

Required transitions:
- Boot validates core content before exposing campaign gameplay.
- Brief creates or loads a `PlanningSession`.
- Planning creates a committed immutable transit input only through Launch Confirm.
- Transit owns a simulation result plus presentation cursor; authoritative simulation may precompute immediately or advance deterministically tick-by-tick, but presentation speed cannot alter output.
- Transit completion/fail-fast enters Causal Review before Results.
- Retry from last launch clones the committed layout into a new editable PlanningSession.
- Results writes campaign progression only after mandatory success evaluation is final.
- Settings can overlay most non-authoritative states and writes to a settings file separate from campaign data.

Scene policy:
- use a persistent shell scene for global navigation/services;
- load one major feature scene at a time;
- do not encode progression truth in scene existence or node names.

---

# 4. Deterministic simulation kernel

## 4.1 Kernel API

Minimum conceptual API:

```text
SimulationInput
  content_version
  rules_version
  contract_id
  route_profile_id
  seed
  committed_layout
  support_configuration
  initial_runtime_state

SimulationRunner.run(input) -> SimulationResult
SimulationRunner.step(state, tick) -> TickResult
```

`SimulationResult` contains:
- final authoritative state;
- every end-of-tick snapshot required for review/debugging;
- ordered event log;
- causal links;
- mandatory predicate result;
- medal/objective results;
- first decisive failure;
- reproducibility checksum sequence.

The simulation must also support a reduced-memory production mode if needed, but test/debug builds retain complete snapshots.

## 4.2 Numeric policy

Authoritative values use integers.

Default domains follow Phase-4 validation bands; where a fractional multiplier such as contamination resistance `0.5` or `1.5` is required, use **scaled integers**, not floats.

Canonical scale:
- `FIXED_SCALE = 1000`.
- 0.5 = 500; 1.0 = 1000; 1.5 = 1500.
- multiplication uses integer intermediate values and one documented rounding rule.

Canonical rounding:
- non-negative gameplay division uses floor unless a rule explicitly states otherwise;
- signed deltas round toward zero only when the rule explicitly requires signed division;
- validators reject definitions relying on unspecified rounding.

Do not use floating-point values for:
- thresholds;
- environmental fields;
- internal meters;
- target ranking;
- tick timing;
- objective evaluation;
- generator solvability.

Floats are acceptable for animation time, screen transforms, volume, interpolation, and presentation-only particles.

## 4.3 Stable identity and ordering

Every runtime organism/support receives a stable `instance_id` at committed-layout construction.

IDs are assigned from canonical manifest/support order, never object memory address.

Every operation that could involve multiple entities declares an ordering:
- primary rule selector;
- distance if applicable;
- grid coordinate ordering if applicable;
- final tie-break by stable instance ID.

Never rely on dictionary/hash iteration order for authoritative effects.

Before processing unordered containers, convert to a stable array and sort with the rule's canonical comparator.

## 4.4 Tick integration

Implement the exact A–I phase order from `MECHANICS.md` as explicit functions. A trait can register evaluators in a permitted phase but cannot dynamically insert/reorder global phases.

Recommended call graph:

```text
run_tick
  phase_a_route_input
  phase_b_start_transitions
  phase_c_generate_channels
  phase_d_propagate_channels
  phase_e_exposure_interactions
  phase_f_apply_internal_meters
  phase_g_evaluate_thresholds
  phase_h_end_consequences
  phase_i_completion_check
```

Each phase receives a read snapshot and writes effects/events to a phase-local buffer. Commits occur only at defined boundaries.

## 4.5 RNG / seeds

Base campaign simulation currently requires **no random transit outcomes**.

A seed exists for:
- generated challenge construction;
- deterministic selection from explicitly allowed content sets;
- optional cosmetic/presentation randomness only when replay checksum excludes it.

Use a dedicated RNG object per generator operation. Never call a global random function from authoritative simulation.

Persist:
- `seed`;
- `generator_version`;
- `rules_version`;
- `content_version`.

A shared challenge code must resolve to the same challenge only when those compatibility versions match. If not, show `legacy seed version` rather than silently generating a different puzzle.

## 4.6 Reproducibility checksum

At end of time zero and each tick, produce a canonical state serialization and 64-bit+ hash/checksum.

Canonical serialization order:
1. rules/content identifiers;
2. tick;
3. route state;
4. grid cells in row-major `(y,x)` order;
5. organism instances by `instance_id`;
6. support instances by `instance_id`;
7. queued transitions/events in canonical order;
8. objective aggregate state.

The checksum is not security. It is a determinism diagnostic.

Tests must compare checksum sequences, not only final success/failure.

---

# 5. Canonical content-definition schemas

All mechanical content is external data loaded into typed immutable definitions.

Preferred source format: UTF-8 JSON files under `/content`, one definition or small coherent collection per file. JSON is chosen for diffability, AI/tool generation, external validation, and engine independence. Godot scenes/resources remain presentation assets, not the canonical mechanical database.

Every content file includes:
- `schema_version`;
- stable string `id`;
- localization keys rather than player-facing English;
- optional `dev_notes` ignored at runtime.

## 5.1 BodyPlanDefinition

Fields:
- id;
- legal orientations;
- stages;
- per-stage local occupied-cell offsets;
- deterministic growth addition/removal cells;
- symmetry metadata for UI;
- presentation silhouette reference.

## 5.2 TraitDefinition

Fields:
- id;
- family `T01..T10`;
- trigger phase;
- state/condition gate;
- target selector;
- range model;
- numeric parameters;
- capacity;
- cooldown/event guard if used;
- effect list;
- UI summary localization template;
- causal-log localization template.

The JSON cannot contain arbitrary code expressions. Behavior is selected from the fixed trait-family grammar.

## 5.3 SpeciesDefinition

Fields:
- id;
- body_plan_id;
- initial stage/orientation restrictions;
- stress profile;
- contamination profile;
- satiety/metabolism profile;
- ordered trait IDs + allowed parameter variant IDs;
- tags/compatibility tags;
- initial meter values;
- discovery/documentation tier;
- generator tier/exclusions;
- visual/audio presentation IDs;
- codex localization keys.

## 5.4 SupportDefinition

Fields:
- id;
- placement class;
- footprint/fixture requirements;
- power draw;
- capacity;
- selector;
- legal target/link rules;
- channel/effect grammar;
- brownout behavior;
- availability tier;
- presentation/localization refs.

## 5.5 HoldDefinition

Fields:
- dimensions;
- usable/blocked cell mask;
- zones;
- fixture coordinates/types;
- power capacity;
- propagation modifiers;
- authored support boundaries;
- presentation skin ID.

## 5.6 HazardDefinition

Fields:
- id/family;
- target scope;
- channel/state/power effect grammar;
- legal intensity bands;
- presentation warnings;
- documentation tier;
- generator exclusions.

## 5.7 RouteProfileDefinition

Fields:
- id;
- tick_count;
- ordered route-event schedule;
- visible/unknown information segments;
- base propagation/vent modifiers if allowed;
- compatible hazard references.

Route events are sorted by tick, then authored order/ID.

## 5.8 ContractDefinition

Fields:
- id;
- tier/type;
- hold_id;
- route_profile_id;
- manifest entries with stable manifest order;
- initial organism state overrides if any;
- available support pool/quantities;
- mandatory predicate tree;
- Silver/Gold predicate trees;
- knowledge/discovery rules;
- brief localization keys;
- allowed uncertainty;
- retry/save policy flags only where globally permitted;
- generator participation/exclusion.

## 5.9 PredicateDefinition

Predicates are a closed grammar, e.g.:
- meter <=/>= threshold at final;
- state/flag present or absent at final;
- never-entered state across timeline;
- max/min timeline aggregate;
- growth stage reached/not reached;
- zone final position;
- support count/power/space condition;
- intervention/layout metric where canonically scored.

Composite operators: `ALL`, `ANY`, and narrowly scoped `NOT` over leaf predicates.

No executable script strings.

## 5.10 CampaignGraphDefinition

Fields:
- 48 node definitions;
- tier;
- prerequisite contract IDs;
- capstone flags;
- unlock outputs;
- discovery unlocks;
- challenge/template unlocks.

## 5.11 ChallengeTemplateDefinition

Fields:
- template ID/version;
- allowed species/body plans/supports/holds/hazards;
- tier band;
- manifest size band;
- required dynamic-mechanic tags;
- mutation budget;
- objective grammar;
- explicit exclusions;
- validation limits.

## 5.12 Localization data

All visible text uses keys. Source language may be maintained through Godot-supported localization resources/CSV/PO workflow, but mechanical data stores only keys.

Validator reports missing keys before release builds.

---

# 6. Runtime state schemas

## 6.1 OrganismState

- instance_id;
- species_id;
- anchor cell;
- orientation;
- current body stage;
- stress;
- contamination_load;
- satiety;
- primary behavioral state;
- condition flags bitset/enumerated set;
- trait-local bounded counters/timers;
- consecutive-condition counters;
- event guards/cooldowns;
- delivery-failed markers where canonical;
- occupied cells derived, not independently editable.

## 6.2 GridState

Per cell:
- coordinate;
- occupancy owner ID/type;
- fixture ID if any;
- zone IDs;
- heat;
- stress field;
- contamination;
- active route modifiers.

Coordinates are small integer value objects. Row-major index is the canonical storage/index order.

## 6.3 SupportState

- stable instance_id;
- support_id;
- anchor/orientation if relevant;
- fixture/footprint;
- linked target ID if relevant;
- player-declared power priority;
- powered/off/degraded state;
- finite in-run capacity remaining;
- local counters.

## 6.4 RouteState

- current tick;
- active hazard/event IDs;
- available power;
- hold-wide modifiers;
- unknown-information disclosure state;
- fail-fast marker if route-defined.

## 6.5 ObjectiveState

Contains timeline aggregates needed by predicates so the engine does not need to infer them from presentation logs:
- max/min meter values;
- entered-state flags/counts;
- critical occurrences;
- growth occurrences;
- support usage;
- contract-specific allowed canonical aggregates.

## 6.6 SimulationSnapshot

Snapshot is an immutable/deep-frozen conceptual record of all authoritative state at a boundary.

Production implementation may use efficient copy-on-write/delta structures later, but semantic behavior must match full snapshots.

---

# 7. Content loading and validation pipeline

## 7.1 Load stages

At boot/development validation:
1. enumerate content manifests in deterministic path order;
2. parse JSON;
3. validate schema version and required fields;
4. resolve references;
5. convert to typed immutable definitions;
6. run cross-definition validators;
7. compute `content_version` hash from canonical mechanical data;
8. expose read-only content registry.

Malformed or contradictory core content must fail loudly in development/CI. Release builds must not silently substitute values.

## 7.2 Required validators

Validators must cover at minimum:
- unique stable IDs;
- known schema versions;
- legal body offsets/orientations;
- no duplicate footprint cells;
- stress hysteresis ordering;
- contamination enter/exit ordering;
- meters/rates inside global content bands;
- allowed trait family and phase;
- deterministic selector present for every capacity-limited effect;
- no random authoritative target selector;
- trait count/species readability limits;
- all references resolve;
- supports use exactly one placement class;
- hold fixture/cell validity;
- route events fit route ticks;
- known/unknown information is explicit;
- predicate leaves use supported grammar;
- medal predicates cannot contradict mandatory welfare rules in prohibited ways;
- campaign prerequisite graph is acyclic;
- no mandatory progression dependency on medals;
- localization key coverage;
- generator tiers/exclusions are coherent;
- discovery content obeys first-contact limits;
- content-version canonicalization is stable across file enumeration order.

## 7.3 Build gate

A shipping candidate cannot be produced while any `ERROR` validator remains. Warnings require explicit allowlisting with reason.

---

# 8. Planning model, commands, undo/redo, launch commit

Planning uses a mutable `PlanningSession` separate from transit state.

Planning state contains:
- contract ID/content version;
- placed manifest instances;
- support instances;
- links;
- power priority;
- selected overlays/UI state separately;
- command history;
- saved working setup;
- last committed setup if one exists.

Each authoritative planning edit is a command with sufficient before/after data:
- PlaceOrganism;
- MoveOrganism;
- RotateOrganism;
- RemoveOrganism;
- PlaceSupport;
- RemoveSupport;
- ChangeSupportLink;
- ChangePowerPriority;
- ResetSetup composite command.

Undo/redo changes planning state only. UI selection/hover is not in command history.

At launch:
1. validate structural launch legality;
2. show warnings separately;
3. canonicalize placement/order;
4. build immutable `CommittedLayout`;
5. store it as `last_launch` before transit begins;
6. clear planning undo history from the transit context;
7. derive initial simulation state exclusively from contract definitions + committed layout + explicit seed/version.

Retry from last launch:
- clone committed layout back into a fresh editable PlanningSession;
- begin with empty command history;
- preserve prior result for compare markers until the next launch or explicit reset.

---

# 9. Causal event-log architecture

Causal Review requires first-class structured events, not strings emitted as an afterthought.

## 9.1 EventRecord

Fields:
- monotonically increasing `event_id` within simulation;
- tick;
- phase;
- event_type;
- source kind/id;
- target kind/id/cell/zone;
- effect channel/meter/state;
- before value;
- delta;
- after value;
- rule/trait/hazard ID;
- direct/propagated classification;
- parent event IDs;
- root trigger event ID;
- severity/presentation priority;
- localization template key + structured parameters.

Strings are rendered later from localization keys.

## 9.2 Causal links

A causal parent must represent an actual rule dependency, not temporal proximity.

Examples:
- route thermal surge -> cell heat increase -> organism stress increase -> panic threshold -> alarm emission -> neighbor stress -> neighbor critical.
- contamination source -> cell contamination -> target intake -> contaminated entry -> spore pulse.

Aggregated effects may have multiple parent events.

## 9.3 Review indexes

After simulation, build indexes:
- events by tick;
- events by entity;
- events by cell/zone;
- root trigger -> descendants;
- target change -> direct parents;
- state-transition events;
- predicate-relevant events;
- first decisive failure chain.

This permits timeline grouping, jump-to-cause/root, focus filtering, and start/final compare without rescanning arbitrary UI text.

## 9.4 First decisive failure

A mandatory predicate evaluator returns both outcome and evidence IDs. The failure analyzer selects the earliest event after which the failed predicate became irrecoverable when such a point is definable; otherwise it selects the final violating state plus strongest causal root.

Do not fabricate certainty: if multiple independent causes are equally necessary, display a multi-cause chain.

## 9.5 Event volume policy

Raw debug traces may include low-level arithmetic. Player-facing review collapses low-value events into grouped summaries.

High-speed playback must prioritize presentation of:
1. primary state changes;
2. critical/delivery predicate changes;
3. growth;
4. support power transitions;
5. major route hazards;
6. reactive pulses;
7. only then routine meter/channel changes.

The underlying authoritative log remains complete enough for diagnostics.

---

# 10. Save and persistence architecture

## 10.1 Files

Separate files:
- `profile.sav` — campaign/unlocks/codex/best medals/challenge history;
- `session.sav` — current contract planning or committed transit/review recovery state;
- `settings.cfg` — machine/user preferences, **not Steam Cloud required by default**;
- `profile.backup.sav` and/or rotating recovery generations;
- optional diagnostic logs excluded from Cloud.

This separation aligns with Steam Cloud guidance to keep frequently changed and less frequently changed data separable and avoid machine-specific settings in cloud saves.

## 10.2 Serialization envelope

Every save envelope contains:
- save_format_version;
- game_build_version;
- profile UUID;
- content_version;
- rules_version;
- timestamp only for conflict/recovery UX, never gameplay;
- payload;
- payload checksum.

## 10.3 Atomic write

Write algorithm:
1. serialize to temp file in same save directory;
2. flush/close;
3. verify payload parse/checksum;
4. move current valid save to backup generation;
5. atomically replace destination where OS/filesystem semantics permit;
6. on next boot, validate primary then backup.

Never overwrite the only valid profile directly.

## 10.4 Save points

Persist profile after:
- successful contract completion/unlocks;
- codex discovery threshold;
- medal improvement;
- campaign completion;
- challenge-history update where retained.

Persist session after meaningful planning changes using debounce, and immediately on:
- leaving Planning;
- confirmed launch;
- entering Review;
- app quit request.

## 10.5 Transit quit/resume policy

Canonical policy: **reconstruct, do not serialize mutable mid-phase simulation internals.**

On launch save:
- committed input is persisted.

During transit:
- save the highest fully presented authoritative tick index opportunistically if useful.

On resume:
1. reload the immutable committed input;
2. rerun deterministically from tick 0 to completion or saved review state;
3. verify checksums;
4. present paused at the saved playback tick or final review.

If checksum mismatches, do not continue silently. Fall back to the beginning of the committed transit/review and flag a diagnostic warning in development; preserve player progression.

Rationale: transit is short (normally 10–24 ticks), so deterministic reconstruction is safer than migrating complex mid-phase state.

## 10.6 In-planning persistence

Save complete legal/partially-unplaced planning setup, links, power priority, contract/version IDs, and last-launch baseline reference. Undo history does **not** need to survive process restart; the current arrangement does.

## 10.7 Demo -> full transfer

Use the same profile schema and stable content IDs in demo/full. Full build recognizes demo profile marker and imports compatible campaign progress exactly once or directly shares the same logical cloud profile where platform configuration permits.

Import must be idempotent and never overwrite newer full-game progress.

Steam documentation explicitly supports shared cloud storage between app IDs via shared cloud App ID; use that only after testing the exact unreleased/released behavior in Steamworks. Local import fallback remains mandatory.

## 10.8 Steam Cloud conflict assumptions

Steam may synchronize before/after sessions; therefore saves must not assume a single device lineage.

Conflict strategy:
- prefer platform-provided conflict UI where available;
- internal save envelope exposes timestamp + monotonic local revision + completed-contract count for human-readable recovery information;
- never automatically merge two divergent active planning sessions;
- campaign-profile merge, if implemented, may safely union permanent cleared contracts/codex unlocks and take best medal per contract only after tests prove no progression contradiction;
- settings remain local to avoid Deck/desktop display conflicts.

---

# 11. Generator architecture

Generator is offline, deterministic, versioned, and subordinate to the same simulation kernel.

## 11.1 Safe construction strategy

Prefer **known-valid construction + bounded mutation**, not blind random boards.

Pipeline:
1. choose template/tier from explicit inputs + seed;
2. choose compatible hold/route/support pool;
3. construct or select a known-valid committed arrangement;
4. verify dynamic-transit requirement;
5. mutate manifest/layout/route/objectives within template budget;
6. derive player-facing unsolved contract from the valid source;
7. run validator/solver boundary checks;
8. reject degenerate/static/opaque cases;
9. emit challenge with generator version + seed.

The shipped game does not need to expose the source solution.

## 11.2 Solver boundary

A validator may search candidate layouts offline/in-process for challenge proof. The player UI never calls a solver to recommend moves.

Solver responsibilities:
- prove at least one mandatory-success layout within allowed content;
- reject trivially impossible contracts;
- estimate breadth/degeneracy metrics where computationally feasible;
- detect challenges solved without meaningful post-launch state change;
- detect universal-support/static-isolation degeneracy;
- produce diagnostic evidence, not player hints.

Do not require exhaustive enumeration of huge state spaces at runtime. Templates should keep construction inside bounded searchable spaces or preserve a known-valid source layout.

## 11.3 Dynamic validity checks

Generated challenge is rejected if:
- time-zero/static adjacency alone satisfies its intended challenge with no meaningful transit state change;
- all significant hazards/traits are irrelevant to every known-valid solution;
- mandatory success depends on undocumented randomness (forbidden anyway);
- first decisive failures are consistently too causally opaque under review heuristics;
- required content exceeds the player's documented tier;
- only one pixel-perfect/arbitrary placement survives without readable reason;
- challenge is functionally identical to a recent generated history beyond configured similarity threshold.

## 11.4 Featured seeds

If featured daily/weekly-style seeds are retained, they are just archived seed codes distributed through optional Steam news/static rotation or local curated lists. No reward expires; no backend is gameplay-critical.

---

# 12. Input and UI architecture

## 12.1 Input abstraction

Define semantic actions, never hard-code physical keys in feature logic.

Minimum actions:
- navigate;
- accept/cancel;
- pointer primary/secondary;
- rotate;
- inspect;
- undo/redo;
- overlay cycle/toggle;
- launch;
- playback pause;
- playback speed up/down;
- tick step;
- timeline previous/next significant event;
- tab/panel navigation.

Mouse is primary, but every mandatory gameplay action has a keyboard/gamepad path.

## 12.2 Gamepad planning model

Gamepad uses grid-focus mode:
- D-pad/stick moves logical cell/card focus;
- accept picks up/places;
- shoulder/face action rotates;
- triggers or shoulder buttons switch hold/manifest/inspector regions;
- focus remains visible at all times.

Do not emulate a free mouse cursor as the only gamepad solution.

## 12.3 Focus/navigation

Every interactive Control declares explicit neighbor/focus order where automatic ordering is ambiguous. Modal focus is trapped until closed. No critical feature requires hover.

## 12.4 Aspect ratios and UI scale

Baseline: 16:9, but support common PC aspect ratios including 16:10 and ultrawide through anchored panels and bounded central hold.

The hold itself should remain entirely visible at default scale for normal launch dimensions. On small screens/large UI scale, side panels may become tabs/drawers rather than shrinking text below accessibility minimum.

## 12.5 Localization-safe layout

Rules:
- no fixed-width text boxes sized only for English;
- buttons support text expansion or documented abbreviation fallback;
- icons never carry unique meaning without text/tooltip/legend;
- dynamic sentence fragments use localization templates with named parameters rather than string concatenation;
- causal review groups render from structured data.

## 12.6 Overlays and tooltips

Overlays are presentation projections of current planning facts or recorded transit snapshots. They never invoke hidden future simulation.

Tooltip/inspector presenters consume immutable view models generated from canonical content/runtime state.

## 12.7 Accessibility technical hooks

Settings must be data-driven and instantly previewable where safe:
- text/UI scale;
- color-independent pattern/icon mode;
- reduced flashing;
- reduced motion;
- effect intensity;
- playback speed;
- audio channel volumes;
- non-speech gameplay captions;
- input remapping;
- hold overlay contrast;
- optional larger grid/cursor indicators.

Reduced motion changes animation only, never tick duration or event authority.

---

# 13. Audio / visual presentation boundary

Presentation subscribes to authoritative snapshots and event records.

Allowed:
- tween sprite from old to new posture after a state event;
- emit particles when contamination event occurs;
- play one alarm chirp when panic entry event occurs;
- interpolate channel overlays between tick snapshots for readability;
- slow dramatic presentation around severe events.

Forbidden:
- animation callback applies gameplay meter change;
- particle collision transmits contamination;
- audio duration decides wake/sleep timing;
- frame delta accumulates authoritative exposure;
- sprite overlap determines adjacency;
- canceled/skipped animation suppresses an event.

If the player skips playback, authoritative result and event log are unchanged.

---

# 14. Performance and memory budgets

The game is intentionally small-state. Correctness/readability take priority over premature micro-optimization.

Launch upper design bounds for stress testing (not typical content):
- hold bounding grid <= 12x10 cells;
- solid organism instances <= 24;
- support instances <= 8;
- route ticks <= 32;
- environmental channels = 3 foundation channels;
- mechanically significant traits <= 3 per species instance, plus bounded local state;
- authoritative events target <= 2,000 per transit typical hard stress case <= 10,000 before grouping;
- full debug snapshots for 32 ticks should remain comfortably memory-resident.

Performance targets:
- UI/presentation target 60 FPS on ordinary lower-mid-range PC and Steam Deck-class hardware;
- simulation of a normal contract should complete substantially faster than real-time and ideally within a few milliseconds to tens of milliseconds in release build;
- batch test runner must simulate thousands of small contracts without rendering;
- no gameplay input waits for generator exhaustive search on the main frame; generated challenge construction can use bounded worker/background computation only if deterministic output and cancellation are controlled, otherwise precompute/curate templates.

Do not parallelize the authoritative per-contract kernel until profiling proves need; accidental nondeterminism is more costly than saving microseconds on <120 cells.

---

# 15. Debug and test tooling required before content scale-up

Mandatory tools:

## 15.1 Deterministic replay test
Run one input N times and across test environments/builds; compare tick checksum sequence + result + event IDs/order.

## 15.2 Golden contract fixtures
Each foundation mechanic has committed JSON input/result fixtures with expected checksums and key causal chains.

## 15.3 Event-trace diff
Human-readable diff between two simulation results:
- first checksum divergence tick;
- first differing entity/cell;
- event sequence divergence;
- predicate divergence.

## 15.4 Batch simulator
CLI/headless tool that runs authored contracts and generated seeds, emitting success rates across known candidate layouts/fixtures where provided, event volumes, validator warnings, and timing metrics.

## 15.5 Snapshot inspector
Developer screen/tool for arbitrary tick state: grid channels, meters, queued transitions, trait-local counters, objective aggregates, checksum.

## 15.6 Route-event injector
Developer-only override to trigger hazard/brownout/vent/vibration events on chosen ticks for mechanic QA.

## 15.7 Unlock/debug profile
Create campaign profiles at each tier, all-unlocked state, demo state, campaign-complete state, and damaged/migration test states.

## 15.8 Save migration fixture suite
Persist representative old-version fixtures in tests. Every migration must be repeatable, idempotent where applicable, and preserve permanent progress.

## 15.9 Generator validator
Given seed/template/version, returns accepted/rejected plus exact reason and source-valid solution evidence in development mode.

## 15.10 Performance stress scenes/tests
Largest allowed grid/entities/events; review timeline with event cap; maximal UI scale/localized long strings; rapid repeated retry; 1,000+ headless simulations.

---

# 16. Automated test layers

## Unit
- grid coordinates/distance;
- footprint rotation;
- placement legality;
- threshold hysteresis;
- fixed-point math;
- selectors/tie-breaks;
- support power allocation;
- predicate grammar;
- command undo/redo;
- canonical serialization.

## Simulation
- each trait T01–T10;
- each support S01–S06;
- each route hazard family;
- same-tick multi-threshold behavior;
- growth blocked/retry;
- contamination persistence;
- sleep/wake precedence;
- pulse/event guards;
- fail-fast;
- all representative Phase-4 paper contracts reproduced digitally.

## Content
- all validators;
- every authored contract loads;
- every campaign dependency resolves;
- every species obeys bands;
- localization coverage.

## Generator
- deterministic same-seed challenge;
- known-valid proof preserved;
- invalid/static/degenerate rejection;
- version incompatibility reporting;
- tier restrictions.

## Save
- atomic-write recovery;
- corrupt primary -> valid backup;
- demo import;
- migration chain;
- in-planning restore;
- transit reconstruction;
- divergent cloud-like profiles do not silently overwrite.

## Integration/UI
- launch-validity warnings versus blockers;
- transition Planning -> Commit -> Transit -> Review -> Retry;
- input parity for mandatory actions;
- focus remains reachable at 200% UI scale;
- reduced-motion does not alter checksums;
- skip/speed changes do not alter simulation checksums;
- localization text expansion.

---

# 17. Build, release, platform, logging, telemetry

## 17.1 Build configurations

At minimum:
- `dev` — asserts, full event trace, debug tools, content hot reload if safe;
- `test` — headless/CI deterministic tests;
- `demo` — restricted content manifest, compatible save schema;
- `release` — production assertions/logging policy, full content;
- optional `release_debug` for QA with diagnostic trace enabled.

Demo/full should share code and schemas; content manifest/unlock ceiling differentiates them.

## 17.2 Platform abstraction

Steam integration behind `PlatformService`:
- initialized/available;
- achievements;
- cloud configuration hooks/status if used;
- language query where useful;
- Steam Deck/controller hints only through generic input layer;
- optional rich presence later.

Game must remain playable offline with local saves. Steam API failure cannot block campaign gameplay.

## 17.3 Steam Cloud

Prefer Steam Auto-Cloud initially for small profile/session save files unless API-level conflict/file control becomes necessary. Enable cross-device save paths and test Deck/desktop transfer. Do not cloud machine-specific video/input settings by default.

## 17.4 Logging/privacy

Release logs may include:
- build/content/rules versions;
- non-personal error codes;
- simulation checksum/input IDs for crash diagnosis;
- stack traces where platform permits.

Do not log free-form personally identifying paths/usernames where avoidable. Sanitize filesystem paths in shareable diagnostics.

## 17.5 Crash reporting

No mandatory third-party account. If an external crash-reporting SDK is later selected, document data collected, retention, opt-out/consent obligations, and regional/privacy implications before integration.

## 17.6 Telemetry

Default design requires **no gameplay telemetry** to function.

Optional anonymous playtest/release analytics may be considered only if:
- collection is disclosed;
- it contains no free-form player content;
- no mandatory account is created;
- gameplay works identically without network;
- design decisions are not changed into retention manipulation.

Phase 8 does not mandate telemetry.

---

# 18. Implementation sequence and vertical-slice gates

Production implementation begins only after `DESIGN COMPLETE = YES`; this is an implementation order, not authorization to code now.

## Slice 0 — Kernel harness

Build:
- grid/state model;
- content loader for minimal fixtures;
- A–I phase skeleton;
- checksum;
- headless test runner.

Gate:
- identical fixture produces identical checksums repeatedly;
- no Node/frame dependency.

## Slice 1 — Art-free dynamic transit proof

Build only graybox:
- 5x5 hold;
- representative 8–10 organisms;
- heat/stress/contamination;
- growth/feeding;
- 10 trait families at minimum representative level;
- 12 ticks;
- basic event log;
- planning place/move/rotate;
- launch/retry.

Gate — **product kill gate**:
- dynamic post-launch changes materially determine outcomes;
- failure trace lets a tester name cause and propose a specific revision;
- if static arrangement inspection solves most cases, stop and redesign before art/content production.

## Slice 2 — Causal review vertical slice

Add:
- structured event parents/root;
- timeline;
- jump to failure/cause;
- start/final compare;
- three representative supports/hazards.

Gate:
- a failed run can be explained without opening debug logs.

## Slice 3 — Complete foundation systems

Add all six supports, canonical state precedence, predicates, medals, discovery/uncertainty boundary, all validation fixtures.

Gate:
- Phase-4 representative contracts reproduce expected architecture digitally.

## Slice 4 — MVP content pipeline

Add canonical JSON schemas/validators, 9 species/12 contracts/3 holds/5 hazards, save/load, codex basics.

Gate:
- all MVP content data-only; no species-specific script hacks.

## Slice 5 — Public-demo quality

Add UX polish, four demo supports, 10 demo contracts, accessibility core, localization pipeline, demo->full save transfer test, audio/visual event presentation.

Gate:
- demo proves transit differentiator within first session;
- no inaccessible mandatory pointer-only action;
- deterministic regression suite green.

## Slice 6 — Launch content scale

Scale to 22 species, 48 contracts, 12 hold layouts, 7 hazards/18 routes, campaign graph, 24 challenge templates.

Gate:
- validators/batch simulation stay green;
- no new authoritative mechanic outside frozen grammar without reopening design.

## Slice 7 — Release hardening

Steam integration, Cloud, achievements, controller/Deck QA, migration fixtures, performance, localization, corrupted-save recovery, release logging.

Gate:
- release checklist and all final acceptance tests pass.

---

# 19. Technical failure modes and required defenses

1. **Frame rate changes outcomes** -> kernel tests with presentation disabled and variable playback speeds.
2. **Dictionary iteration changes target order** -> sort every authoritative multi-target set canonically.
3. **Float drift** -> integer/scaled-integer authority only.
4. **Per-species script sprawl** -> closed trait grammar + validator forbidding executable data.
5. **UI becomes simulator authority** -> state mutations only through planning commands or kernel.
6. **Animation skip loses events** -> presentation subscribes to completed authoritative records.
7. **Save corrupted on crash** -> temp+verify+backup+replace.
8. **Engine upgrade breaks replay** -> checksum fixture suite before upgrade acceptance.
9. **Generated seeds change after patch** -> generator/rules/content version in seed contract.
10. **Cloud sync overwrites newer progress** -> valid envelope/recovery policy; settings separated; no silent divergent-session merge.
11. **Review log becomes unreadably huge** -> structured low-level log + grouped player projection.
12. **Generator ships static packing puzzles** -> dynamic validity rejection.
13. **Solver leaks solution into UI** -> generator/validator service has no player-facing recommendation API.
14. **Steam unavailable blocks game** -> local platform fallback.
15. **Localization breaks layout** -> long-string and scale stress fixtures.
16. **Gamepad is fake mouse** -> logical focus/grid control architecture.
17. **Undo corrupts identity/order** -> commands preserve stable planning instance IDs and canonicalize only at commit.
18. **Mid-transit save migration explodes complexity** -> reconstruct from immutable committed input instead.
19. **Content patch invalidates active run** -> save retains content/rules version; incompatible session returns safely to planning/contract with explicit recovery rather than replaying under changed rules silently.
20. **Debug optimization accidentally changes semantics** -> golden checksum traces are the contract.

---

# 20. Intentional implementation flexibility

The following are intentionally left to implementation/profiling because they do not alter design if invariants hold:
- exact scene-node hierarchy inside a feature screen;
- exact sprite batching/caching strategy;
- whether complete simulation is precomputed at Launch or calculated tick-by-tick ahead of presentation;
- exact hash algorithm for diagnostic checksums, provided it is stable and versioned;
- exact JSON parser/helper classes;
- exact save compression, if any;
- exact Steam integration wrapper/plugin selected at implementation time;
- exact automated test framework/add-on, provided tests can run headlessly and in CI;
- exact worker-thread use for generator validation, provided output is deterministic and main-game state is not mutated concurrently.

These choices are **not** licenses to change authoritative math, event order, player information, content grammar, save semantics, or UX behavior.

---

# 21. Phase-8 acceptance tests

Phase 8 is closed only if the specification answers all of these without requiring a future developer to invent game behavior:

- engine/runtime direction chosen: **PASS**;
- deterministic numeric/order policy defined: **PASS**;
- A–I kernel integration contract defined: **PASS**;
- stable seed/version/checksum policy defined: **PASS**;
- canonical mechanical data schemas defined: **PASS**;
- runtime state schemas defined: **PASS**;
- validators and build gate defined: **PASS**;
- planning command/commit/retry model defined: **PASS**;
- causal log sufficient for Phase-6 review defined: **PASS**;
- atomic save/recovery/demo-transfer/cloud assumptions defined: **PASS**;
- generator/solver boundary and rejection rules defined: **PASS**;
- mouse/keyboard/gamepad/localization/accessibility technical architecture defined: **PASS**;
- presentation-authority separation defined: **PASS**;
- scope-appropriate performance bounds defined: **PASS**;
- debug/test tooling defined before content scale-up: **PASS**;
- build/platform/privacy/telemetry boundaries defined: **PASS**;
- vertical implementation slices and product kill gate defined: **PASS**;
- technical failure-mode defenses defined: **PASS**;
- implementation-flexible choices explicitly bounded: **PASS**.

**Phase 8 result: PASS — technical implementation specification is complete enough to proceed to whole-game paper simulation/adversarial design review.**

This does **not** authorize production code and does **not** set `DESIGN COMPLETE = YES`.

---

# 22. Source notes checked for Phase 8 — 2026-08-15

Primary-source facts used in technical selection:
- Godot official archive: 4.7.1 is the current stable patch release as of this pass; 4.8 is still development.
- Godot stable documentation: 4.7 branch is current stable documentation; fixed seed support exists, though authoritative gameplay here avoids RNG where possible.
- Steamworks Steam Cloud documentation: Cloud syncs files before/after sessions, recommends small/separated save files, advises avoiding machine-specific settings in cloud data, supports cross-platform configurations, and documents shared Cloud app ID use relevant to demo/full transfer.
- Steamworks Steam Deck recommendations: clouded saves are strongly recommended for Deck/PC continuity.

Revalidate engine patch, Steamworks requirements, controller/Deck guidance, and platform integration details immediately before implementation/release because these are external moving targets.