# ORGANISM CARGO — WHOLE-GAME SIMULATION & CONSISTENCY REVIEW

Status: **CANONICAL PHASE 9 — WHOLE-GAME SIMULATION COMPLETE**
Last updated: 2026-08-15
Production code started: **NO**

This file validates that the previously locked product, mechanics, decision, content, UX, commercial, and technical specifications form one continuous implementable game rather than a collection of locally consistent documents.

Authority rule for Phase 9: where this document explicitly resolves a cross-file ambiguity, the resolution is canonical immediately and must be folded into the source document during the final specification-freeze reconciliation. It may not invent a new gameplay subsystem. Simulation authority remains in `MECHANICS.md`; planning and uncertainty authority remains in `DECISION_ARCHITECTURE.md`; content roster/counts remain in `CONTENT_ARCHITECTURE.md`; UX authority remains in `UX_ARCHITECTURE.md`; progression/commercial authority remains in `ECONOMY_COMMERCIAL.md`; implementation authority remains in `TECHNICAL_SPEC.md`.

---

# 1. Phase-9 verdict

**PASS WITH REPAIRS.**

A continuous player journey exists from first boot through campaign completion and 20+ hour mastery. No required transition depends on currency, XP, random transit outcomes, online services, hidden medal gates, or an undefined simulation state. The game can be implemented as one deterministic state machine with one campaign progression graph and one persistent knowledge model.

The review found several specification ambiguities. They are resolved in §14. None requires reopening the selected concept or adding a new simulation system.

Phase 9 does **not** set `DESIGN COMPLETE = YES`. Phase 10 adversarial review and Phase 11 specification freeze remain mandatory.

---

# 2. Continuous player journey — first boot to mastery

## 2.1 First boot — minute 0

Player sees:
- skippable studio/logo frame;
- first-run accessibility preflight;
- title screen.

Player knows:
- only that this is a compact living-cargo strategy/puzzle game;
- no trait arithmetic is required before entering campaign.

Player can:
- set UI scale, reduced motion/flashing, master volume, cue captions, and input method;
- begin Campaign;
- open Settings/Credits/Quit.

Persistent writes:
- settings are stored separately from campaign/profile state;
- creating a campaign profile writes a versioned profile envelope atomically.

Motivation:
- immediate promise is visual and mechanical: living cargo must be arranged before launch and will change after commitment.

No campaign progress, medal, currency, XP, support stock, or random reward exists.

## 2.2 Contract 01 — first 5 minutes

The opening contract teaches only what is necessary to make a legal committed state:
1. manifest cards;
2. hold cells and occupancy;
3. selecting/dragging/placing;
4. orientation when relevant;
5. exact distinction between illegal placement and legal-but-risky placement;
6. Launch as a deliberate commit;
7. transit playback;
8. result/review boundary.

The player sees the whole hold without scrolling. Organisms use simple Dot/body silhouettes and one-trait identities. The route is short and fully known.

The first tutorial may be nearly static because Tier 0 is the only exception to the product rule requiring meaningful post-launch change. By the end of the first few contracts, a route or organism state change must visibly alter the outcome after launch.

The player learns:
- planning is free and reversible;
- launch locks position/orientation/support configuration;
- playback speed does not change outcomes;
- transit is deterministic;
- failure is safe to retry.

Save semantics:
- planning arrangement autosaves on safe planning-state changes/debounced checkpoints;
- launch creates immutable committed input;
- no progress is granted merely for launching.

## 2.3 First understandable dynamic consequence — roughly minutes 5–15

Chapter 1 introduces Hushling, Ember Pod, Frost Finch, then Thermal Surge. The first dynamic lesson is intentionally narrow:

`route heat -> internal stress -> state change -> trait output / changed relationship`.

The player does not need all three environmental channels yet. Heat and stress are enough to establish that time-zero adjacency is not the whole answer.

Causal Review is introduced as soon as a failure contains a useful chain. It is not held until late game.

The review screen must be able to say, conceptually:
- Thermal Surge affected Ember Pod;
- Ember Pod crossed AGITATED threshold;
- its alarm activated on the next legal phase/tick;
- neighbor stress rose;
- delivery predicate failed.

The player can jump from failed predicate to decisive event to direct/root cause without reading a raw log.

## 2.4 First 30 minutes

Expected state after several Chapter-1 contracts:

Player knows:
- placement/orientation;
- current vs future consequence distinction;
- heat source/sink relation;
- soothing/alarm relation;
- at least one route hazard;
- Bronze success vs optional Silver/Gold;
- retry from last committed layout;
- Causal Review timeline.

Player has likely experienced:
- at least one first-attempt success;
- at least one recoverable failure;
- one targeted retry where changing a small number of cells fixes the causal chain.

Player has not encountered:
- persistent currency/XP;
- challenge-mode obligation;
- large codex study load;
- hidden route uncertainty;
- brownout priority;
- multi-stage mastery species.

Motivation promise at this point:
> “I can predict simple living interactions, failures explain themselves, and later cargo will combine these rules in stranger ways.”

## 2.5 First session — roughly 25–45 minutes

The player completes a compact set of contracts and stops safely on the campaign map or in planning.

A normal first session should end with 2–4 available campaign nodes once branching begins. The player is never told to farm a prior contract. Medal optimization is optional.

First-session unlocks are direct access/knowledge outputs:
- newly available campaign node(s);
- documented trait/species/hazard entries;
- first support access when its authored teaching milestone is cleared.

No unlock is expressed as `+10%` power.

## 2.6 First 2 hours — Chapter 2 into Chapter 3

The player now encounters contamination, persistent environmental residue, filter feeders, growth, Baffle, Feed Cartridge, and then sleep/wake timing.

The cognitive shift is:
- Chapter 1: `avoid obvious bad relationship`;
- Chapter 2: `choose between clustering and separation`;
- Chapter 3: `reserve space and align behavior with future timing`.

By roughly two hours the player must have seen all three environmental pressures as distinct systems:
- heat;
- stress field / internal stress;
- contamination.

They also must have made at least one genuine support tradeoff where the support is not simply free safety.

Generated/recombined Challenges unlock only after the Tier-2/Chapter-2 capstone requirement is satisfied. Merely documenting many rules early does not unlock Challenge mode.

## 2.7 Midgame — roughly hours 3–6

Chapter 4 makes mitigation scarce and introduces cascades, directional pressure, Service Bay fixture competition, Brownout, and power priority.

The player is no longer primarily learning isolated rule definitions. Difficulty comes from selecting the weak link in a causal graph.

Typical midgame reasoning:
- `I cannot cool and filter every risk because fixtures/power are limited.`
- `Which failure starts first?`
- `Can I use a living sink instead of a support?`
- `Will the brownout disable the support I need at the critical window?`
- `Does separating this alarm source also break a beneficial soothing/feed relation?`

A strong Chapter-4 contract allows at least two meaningful intervention families, e.g. prevent the first source from crossing a threshold or allow it to cross but isolate/mitigate propagation.

The player remains free to retry without punishment.

## 2.8 Discovery chapter — roughly hours 6–8

Chapter 5 introduces bounded uncertainty only after the player understands deterministic normal play.

Discovery never means “there is secretly a random rule.” It means one deterministic rule is incompletely documented but bounded by clues.

The player always knows:
- an undocumented behavior exists;
- its broad category or bounded clue set;
- contract-critical welfare bounds;
- that retry is safe;
- whether Monitor Beacon can trade mitigation for better evidence.

A discovery can end in:
- conservative first-attempt Bronze success plus learned rule; or
- safe informative failure followed by targeted retry.

Once the uniquely identifying causal observation occurs, the exact rule becomes documented permanently.

## 2.9 Late game — roughly hours 8–12

Chapter 6 does not add a hidden new foundation mechanic. It recombines:
- composite species;
- irregular holds;
- growth/lifecycle timing;
- multiple known hazards;
- Brownout/support priorities;
- beneficial-dangerous organisms;
- strict optional medals.

The final contract `Living Manifest` uses 7–9 organisms drawn from at least five learned role families, one lifecycle species, one beneficial-dangerous composite, an irregular vault, and three known hazard families. At least two Bronze strategy families must be validated.

The final skill tested is not memorizing a favorite layout. It is model-building under unfamiliar composition.

Campaign completion writes:
- final campaign-clear flag;
- best medals;
- final unlock set;
- codex/documentation state;
- challenge/mastery availability.

No cliffhanger or paid-content dependency is required.

## 2.10 20+ hour mastery behavior

Long-tail mastery is voluntary and built from:
- Gold optimization;
- alternate valid solution families;
- replay of authored mastery contracts;
- deterministic generated/recombined challenges;
- seed sharing;
- optional challenge constraints;
- self-imposed support/efficiency goals.

Long-tail behavior is invalid if it degenerates into:
- XP farming;
- rerolling random outcomes;
- always choosing one universal support pair;
- using one memorized layout template;
- static packing with transit as decorative playback.

Generated challenge anti-sameness requirements therefore remain gameplay-critical:
- recent-challenge fingerprint comparison;
- dynamic-transit significance test;
- dominant-support streak rejection/down-ranking;
- known-solvable validation;
- causal-opacity rejection.

---

# 3. Representative contract A — successful first attempt

Purpose: prove the normal path `Brief -> Planning -> Launch -> Transit -> Review -> Results` without failure.

Representative situation: early Chapter-1 thermal contract using Ember Pod, Hushling, Frost Finch and a known Thermal Surge.

## Brief

Known facts:
- Thermal Surge affects LEFT zone during a declared tick window;
- Ember Pod emits heat and alarms when sufficiently stressed;
- Hushling soothes one adjacent stressed neighbor while CALM/awake;
- Frost Finch is a bounded local heat sink;
- mandatory delivery requires no CRITICAL organism;
- optional medal asks that Ember Pod never PANIC.

Player choice:
- keep Ember Pod outside LEFT surge zone;
- place Frost Finch in a useful local thermal relationship;
- place Hushling adjacent to the likely stressed organism without exposing Hushling to unnecessary heat.

## Launch

The setup is structurally valid. The confirmation strip may show no warning. The committed input freezes positions, orientations, route profile, support state, version IDs, and starting meters.

## Transit A–I walkthrough

At each tick:
- **A** activates route input when the surge window begins;
- **B** applies any scheduled state transition from prior tick;
- **C** generates organism/support/hazard channel outputs;
- **D** propagates/decays heat/stress/contamination from a common snapshot;
- **E** evaluates local exposure and direct soothing/sink interactions;
- **F** commits internal meter deltas;
- **G** checks thresholds with hysteresis;
- **H** resolves immediate consequences and logs causes;
- **I** evaluates completion only at route end/fail-fast boundary.

Because the player kept the unstable source outside the surge zone and provided local mitigation, stress never reaches the decisive panic threshold.

## Causal Review

Success review still has value. The player can see:
- surge onset;
- Frost Finch heat removal;
- Hushling soothing activation if triggered;
- maximum stress reached;
- optional medal pass.

The review does not fabricate a dramatic chain when none exists.

## Results

Bronze is guaranteed by mandatory success; Silver/Gold are evaluated transparently. Campaign node unlocks occur only now, after final success evaluation.

Expected learning:
- good placement can be a hypothesis confirmed by transit, not only a response to failure.

---

# 4. Representative contract B — recoverable cascade failure and targeted retry

Purpose: prove that failure becomes evidence rather than random rearrangement.

Use the validated `Useful Dirt` structure from Phase 4:
- Silt Grazer;
- Spore Bell;
- Cradle Moss;
- Ember Pod;
- contamination leak;
- optional Filter/Baffle support choice;
- future growth space matters.

## Failed plan

The player correctly places Silt Grazer near contamination so it can consume residue, but places Cradle Moss in the Grazer's documented future growth cell.

Time-zero state is legal. Launch must remain permitted because future growth space is a strategic prediction, not a structural validity condition.

## Failure transit

Causal story:
1. route leak adds contamination;
2. Silt Grazer consumes contamination;
3. consumption raises satiety;
4. growth condition becomes satisfied for required duration;
5. scheduled growth attempts the deterministic forward cell;
6. cell is occupied by Cradle Moss;
7. `GROWTH_BLOCKED` is recorded and stress increases;
8. repeated pressure pushes Grazer into AGITATED/PANICKED or breaks the relevant welfare/optional predicate.

The exact tick-by-tick implementation follows A–I; the player-facing review groups routine propagation so the useful explanation remains short.

## Review requirements

The UI must support:
- jump from failed predicate to first decisive growth-block event;
- show the growth footprint that was attempted;
- show occupying entity/cell as direct blocker;
- distinguish direct cause (blocked deterministic growth cell) from propagated consequence (stress state change);
- compare time-zero vs final layout/state.

## Retry

`Retry from last launch` reconstructs the exact committed plan as editable planning baseline.

The player's targeted revision is one of:
- move Cradle Moss out of the future footprint;
- rotate/reorient the Grazer if legal and reserve alternate future space;
- use Filter to alter contamination/satiety timing if that creates a different valid strategy and the contract allows it.

The retry costs nothing and does not reduce any persistent score/progression meter.

Expected learning:
- `helpful now` can create `spatially dangerous later`;
- the player revises a causal hypothesis rather than brute-force shuffling.

---

# 5. Representative contract C — bounded uncertainty / discovery

Purpose: prove that incomplete knowledge is compatible with deterministic fairness.

Representative Chapter-5 case: Pale Drifter (`O21`) discovery.

Known before launch:
- Pale Drifter has a visible sleep/wake lifecycle;
- an undocumented reactive behavior exists;
- clue category identifies the behavior as a contamination-related wake reaction;
- exact magnitude/trigger detail is not yet documented;
- route contains a known or bounded vibration/wake window;
- mandatory Bronze thresholds are forgiving enough for a conservative plan;
- Monitor Beacon is available only if the authored contract defines its evidence mode.

Player choices:
- spend a fixture/power slot on Monitor Beacon for exact evidence;
- choose direct mitigation and accept bounded uncertainty;
- place vulnerable organisms outside the most conservative risk area.

## Discovery transit

When Pale Drifter wakes under the authored legal trigger, a cleansing Reactive Pulse occurs. The authoritative event contains:
- trigger event ID;
- source organism ID;
- affected cells/entities;
- exact channel deltas;
- parent/root causal link;
- documentation evidence tag.

If the observation uniquely identifies the rule, the profile marks the fact DOCUMENTED at run completion/review boundary according to content data.

## If first attempt fails

Failure cannot consume progress/resources. Causal Review shows the actual observed event. The player retries with exact learned evidence.

## If first attempt succeeds conservatively

The run still produces documentation evidence. Discovery is not dependent on deliberate failure.

Expected learning:
- uncertainty changes information strategy, not deterministic authority;
- Monitor is an opportunity-cost evidence tool, not an auto-solver.

---

# 6. Campaign graph / prerequisite validation

The 48 authored contracts remain six chapters/tiers of eight. Phase 9 validates the following graph invariants.

## 6.1 Mandatory progression invariant

A mandatory contract may depend only on:
- completion of named prerequisite contract(s);
- knowledge/documentation automatically granted by those prerequisites;
- systems/supports/hazards already introduced by those prerequisites.

It may **not** depend on:
- Silver/Gold medals;
- cumulative medal totals;
- XP;
- currency;
- number of failures/retries;
- generated challenge completion;
- optional achievements;
- calendar/online activity.

## 6.2 Chapter-capstone rule

Each chapter capstone is unlocked by a small authored prerequisite set covering the lessons that capstone assumes. Clearing the capstone opens the next chapter.

Exact node edges are content data and must pass a build-time graph validator:
- all 48 IDs reachable from C01;
- no cycles in mandatory prerequisite graph;
- no node depends on a later-tier lesson;
- every assumed documented rule appears on all paths that can reach the node;
- every capstone has at least one valid path that does not require optional medals.

## 6.3 Branching without knowledge holes

When a chapter offers multiple nodes, a later merge node may require both branches only if it uses lessons from both. Otherwise it should require only the relevant branch prerequisites.

The player-facing map marks locked-node prerequisite reasons in plain language, e.g. `Complete “Useful Neighbors” to continue`, never `Need 12 stars`.

## 6.4 Generated challenge unlock

Generated Challenges unlock after Chapter/Tier-2 capstone completion, approximately after the first 16 authored contracts. Having seen advanced demo/codex information does not bypass this gate.

This prevents an experienced demo player from entering generator content before the full campaign has established the intended vocabulary breadth.

---

# 7. Progression / unlock validation — no currency, no XP

Persistent progression state is a set of deterministic flags/records:
- cleared contract IDs;
- best medal per contract;
- documented species IDs;
- documented trait facts;
- observed discovery clue IDs;
- unlocked support knowledge;
- documented hazard/hold knowledge;
- campaign graph unlocks;
- challenge-template unlocks;
- campaign-complete flag;
- optional achievement records.

Every unlock must have an explicit source event, e.g.:
- `C07 cleared -> Cooler documented`;
- `C16 capstone cleared -> Tier 3 opened + Challenges base mode enabled`;
- `Pale Drifter unique wake event observed -> exact O21 wake-pulse fact documented`;
- `C48 cleared -> campaign complete + all compatible mastery challenge access`.

No persistent numerical power is derived from these flags.

A build-time campaign validator must reject any unlock reference that cannot be reached from C01 without medals/optional content.

---

# 8. Save, quit, crash, abandon, and resume simulation

## 8.1 Quit during Planning

Authoritative recoverable state:
- contract ID/content/rules version;
- current editable layout;
- support placements/links/priorities;
- planning metadata needed to rebuild UI;
- last committed layout if a prior attempt exists.

On Continue:
- return directly to Planning;
- rebuild inspectors/overlays from canonical data;
- undo stack may be reset unless safely serialized; loss of undo history is acceptable, loss of current plan is not;
- no launch or progression happens automatically.

## 8.2 Quit during Launch Confirmation

Launch confirmation itself is not authoritative commitment until final `Launch` action.

On quit/crash before commit:
- restore Planning state;
- do not create a transit record.

## 8.3 Quit during Transit

Canonical Phase-9 repair: **do not serialize mutable mid-phase simulation internals.**

Persist:
- immutable committed `SimulationInput`;
- completed safe authoritative tick index / playback cursor checkpoint;
- simulation/result identity/version/checksum metadata as available.

On Continue:
1. load committed input;
2. rerun deterministically from tick 0 to the saved completed tick (or whole result if cheaper);
3. verify checksum when stored;
4. restore `TRANSIT_PLAYBACK` paused at the recovered presentation cursor;
5. never duplicate causal events, unlocks, achievements, or Results writes.

If reconstruction fails version validation, fall back to last safe Planning committed layout with a clear recovery notice rather than continuing a mismatched run.

## 8.4 Quit during Causal Review

The authoritative transit is already complete.

Persist:
- committed input/result identity;
- final success/failure + medal evaluation;
- ordered causal events/snapshots or enough deterministic data to reconstruct them;
- review cursor/focus if inexpensive;
- whether Results/progression write has been finalized.

On Continue:
- return to Causal Review, not Planning;
- do not force the player to replay transit;
- Results may only apply progression exactly once.

## 8.5 Quit after Results

Progression transaction must be committed atomically before the UI presents the unlocked state as permanent.

On resume:
- campaign map reflects the completed contract/unlocks;
- no duplicate medal/unlock cards are required; optional `recent unlocks` presentation may be reconstructed separately.

## 8.6 Crash recovery

Save architecture uses temp-write -> verify -> backup -> replace.

Recovery priority:
1. valid primary save;
2. valid backup;
3. recoverable session record;
4. safe campaign/profile state with active contract returned to Planning;
5. explicit Save Recovery screen when automatic choice would discard meaningful progress.

No cloud/platform failure may block local play.

## 8.7 Contract abandon

From Planning:
- player may abandon to campaign map after confirmation if there are unsaved edits;
- no persistent penalty;
- uncleared contract remains available;
- cleared prior progress remains untouched.

From Transit:
- player must first choose `Abort transit`; because transit outcome is deterministic and short, abort discards only the active run and returns to the committed layout in Planning or map after explicit confirmation;
- no Bronze failure record is economically meaningful.

From Review after failure:
- `Return to map` is allowed;
- contract remains uncleared.

From Review after success:
- Results/progression must finalize before leaving if not already finalized.

---

# 9. Causal Review data-contract validation

Every UX request in Causal Review can be supplied by Phase-8 event/snapshot data.

Required event fields for player-facing review:
- event ID;
- tick;
- phase;
- event family/type;
- source instance/route/support ID;
- target instance/cell/zone IDs;
- numeric before/delta/after when relevant;
- parent event ID(s);
- root trigger ID/category;
- direct vs propagated classification;
- predicate impact tag when this event contributes to a failed/medal objective;
- localization template key.

Required indexes may be built post-simulation:
- events by organism;
- events by cell/zone;
- events by tick;
- root-to-descendant chain;
- predicate failure -> decisive event;
- direct cause -> parent/root;
- state transition history;
- start/final snapshot comparison.

No Phase-6 UX feature requires the engine to infer human-style causality from animation after the fact. Causality is structured authority.

Grouping rule:
- repetitive channel propagation may collapse into one player-facing causal group;
- raw trace remains available to debug tooling;
- grouped review must never change the underlying event order.

---

# 10. Gamepad / Steam Deck end-to-end path

Mouse remains the fastest baseline, but every mandatory action has a controller path.

## 10.1 Campaign/menus

- D-pad/stick moves focus among visible controls/nodes;
- confirm opens selected node/action;
- cancel goes back one layer;
- shoulder buttons may switch map panels/tabs;
- no hover-only information is mandatory.

## 10.2 Planning

Canonical controller interaction:
- focus grid cell or manifest card with D-pad/stick;
- confirm picks up/places selected entity;
- bumpers/triggers rotate when legal;
- dedicated focus action opens inspector;
- shoulder/tab actions cycle overlay family;
- undo/redo available from visible toolbar and remappable shortcuts;
- support link/priority lists use normal focus lists, not pointer emulation;
- Launch is a visible focused control followed by confirmation.

No mandatory placement requires pixel precision. Authority snaps to grid cells.

## 10.3 Transit

- confirm/primary toggles pause/play when playback controls focused;
- shoulder/trigger controls speed/step by mapped actions;
- focus can move between hold entities, event feed, and timeline;
- exact simulation never depends on controller repeat rate.

## 10.4 Review

- D-pad/bumper steps events/ticks;
- dedicated actions jump to first failure/direct cause through visible buttons as well as shortcuts;
- retry/reset/map are focusable;
- no timeline functionality depends on mouse-wheel or hover.

## 10.5 High UI scale / 1280x720 / Deck

At maximum supported practical scale:
- central hold must remain fully operable;
- side panels may become tabbed/stacked drawers rather than shrink text;
- route timeline may collapse to a scrollable/focused strip;
- objective/support information remains available in one action;
- selected organism/cell retains an obvious focus outline independent of color;
- no modal opens outside safe screen bounds.

This is a release acceptance path, not an optional polish item.

---

# 11. Demo -> full-game continuation — canonical repair

Earlier Phase-5/7 wording created ambiguity because the demo uses `D01..D10` while the full campaign uses `C01..C48`, yet full save transfer was promised. Phase 9 resolves the mapping.

## 11.1 Stable demo identity

Demo contracts remain `D01..D10` and retain their own completion records for compatibility and analytics/debugging. They are not silently renamed to campaign IDs.

## 11.2 Campaign-equivalence mapping

`Continue from Demo` on first full-game launch applies a deterministic migration table:
- `D01..D08` are certified onboarding-equivalent to the foundational learning obligations of `C01..C08`;
- if all mapped demo obligations were completed, `C01..C08` may be marked Bronze-cleared for progression purposes;
- a better demo medal is copied to a campaign contract **only when** that D/C pair uses mechanically equivalent optional predicates; otherwise campaign best medal starts at Bronze and the player may replay for Silver/Gold;
- `D09..D10` are demo-exclusive proof/discovery contracts and do **not** auto-clear `C09` or later campaign nodes.

Therefore the default continued full-game state is:
- Chapter 1 treated as taught/cleared if equivalence validation passes;
- Chapter 2 opening node(s), beginning at C09 according to the normal graph, available;
- no Tier-2 capstone, Challenge-mode, late support, or mastery access skipped.

## 11.3 Knowledge transfer

Persist from demo:
- all exact Codex facts legitimately documented;
- observed discovery clues;
- known support/hazard entries encountered in demo;
- settings/accessibility;
- demo completion/medal records.

Knowledge can be ahead of the ordinary campaign teaching order because knowledge is not numerical power and contracts still control manifests/support allowances. A later campaign teaching contract may acknowledge `Already documented` and omit redundant pop-up tutorial text while retaining its puzzle.

## 11.4 Cinder Snail discovery

If D09 documents Cinder Snail early, the full profile keeps that knowledge. The Chapter-3 Cinder Snail introduction remains playable but does not pretend the rule is unknown again.

## 11.5 Supports seen early in demo

Filter, Baffle, and Feed Cartridge can be marked known if learned in the demo, but full campaign contracts still decide whether each is available. Early knowledge never grants unrestricted loadout access.

## 11.6 Restart option

First full-game launch after demo offers:
- `Continue from Demo`;
- `Start Campaign from Beginning`.

Starting from beginning creates fresh campaign-clear state but may optionally preserve accessibility/settings. It must not force deletion of the imported demo record.

## 11.7 Migration failure

If demo/full content versions are incompatible:
- preserve settings where schema-compatible;
- preserve raw demo record separately;
- do not partially mark campaign nodes cleared;
- explain that campaign progress could not be mapped safely;
- start campaign at C01 without mechanical penalty.

This is preferable to silently skipping lessons with an invalid mapping.

---

# 12. 20+ hour adversarial behavior preview

These are Phase-9 observations to feed Phase 10.

## 12.1 Solved-template risk

Potential exploit: reserve one corner for growth, place a soother centrally, keep emitters at edges.

Existing counters:
- irregular/blocked hold layouts;
- different route-zone hazards;
- directed traits;
- support fixture topology;
- organisms requiring proximity;
- growth orientation;
- anti-template generator fingerprints.

Phase-10 question: is the counter-pressure strong enough in actual launch roster, or are these only theoretical counters?

## 12.2 Universal support pair risk

Potential dominant pair: Cooler + Filter for broad environmental safety.

Existing counters:
- fixture/power competition;
- cargo-cell alternatives;
- Brownout;
- stress/social problems unaffected by Cooler/Filter;
- support allowance variation;
- generator streak rejection.

Phase-10 must calculate representative coverage to ensure Cooler+Filter does not remain optimal too often despite those rules.

## 12.3 Isolation strategy risk

Existing counters:
- small holds;
- organisms needing feeding/symbiosis/soothing;
- growth space;
- density/medal constraints;
- route zones.

Phase-10 must test whether Bronze often permits simple maximum spacing anyway.

## 12.4 Brute-force retry risk

Because retry is free, a player can theoretically random-shuffle until success.

This is intentionally not prevented through retry costs. The design response is:
- high branching factor;
- deterministic evidence;
- fast targeted revisions;
- medal/mastery incentives;
- no random result that makes blind retries exciting.

Phase-10 should test whether early/mid contracts are sufficiently diagnostic that understanding is substantially faster than blind rearrangement.

## 12.5 Content exhaustion risk

Launch variety comes from 22 species, 6 supports, 12 holds, 7 hazards, 18 route profiles, 48 authored contracts, and 24 challenge templates. Quantity alone is not proof.

Phase-10 must examine role-histogram diversity and ensure late species create new relationships rather than reskinned arithmetic.

## 12.6 Generated-challenge sameness

The generator already rejects recent fingerprint similarity >0.80 and repeated optimal powered-support pairs. Phase-10 should stress-test whether this can still emit conceptually identical puzzles under different species names.

---

# 13. Whole-game state-transition audit

Required legal top-level paths:

`BOOT -> FIRST_RUN_PREFLIGHT -> TITLE -> CAMPAIGN_MAP -> CONTRACT_BRIEF -> PLANNING -> LAUNCH_CONFIRM -> TRANSIT_PLAYBACK -> CAUSAL_REVIEW -> RESULTS -> CAMPAIGN_MAP`

Failure path:

`... -> TRANSIT_PLAYBACK -> CAUSAL_REVIEW -> PLANNING (retry from last launch)`

Challenge path:

`TITLE/CAMPAIGN_MAP -> CHALLENGE_SELECT -> CONTRACT_BRIEF -> PLANNING -> ... -> CAUSAL_REVIEW -> RESULTS -> CHALLENGE_SELECT`

Codex/settings are non-authoritative detours and must return to the invoking context without changing simulation state.

Campaign final path:

`C48 RESULTS -> CAMPAIGN_COMPLETE -> CAMPAIGN_MAP`

Recovery path:

`BOOT -> SAVE_RECOVERY -> safe prior context` when automatic load cannot safely choose.

No required path needs a state absent from Phase-8 `AppStateMachine`.

---

# 14. Contradiction / ambiguity ledger and canonical repairs

## P9-01 — Demo documented-species count

Conflict:
- one Phase-5/7 summary says demo has 10 species with `8 fully documented + 2 bounded discovery`;
- detailed demo list identifies one bounded discovery species (Cinder Snail), which implies 9 fully documented + 1 discovery.

Repair:
- **canonical demo composition is 10 species total: 9 normally documented + 1 bounded discovery (Cinder Snail).**
- future source-file reconciliation must replace `8 + 2` wording with `9 + 1`.

Reason: the detailed roster and explicit single-discovery arc are more specific and internally coherent.

## P9-02 — Demo save-transfer wording

Conflict:
- Phase-5 wording says demo may carry a small cosmetic acknowledgment / no mechanical power bonus;
- Phase 7 locks full demo save transfer.

Repair:
- full progress/knowledge/settings transfer is canonical as defined in §11;
- there is **no mechanical power bonus**, which preserves the intent of the older Phase-5 sentence;
- cosmetic acknowledgment is optional and additional, not the only transfer.

## P9-03 — Demo IDs vs campaign IDs

Conflict:
- Phase 7 promises completed demo contract states + last valid campaign position;
- Phase 5 defines distinct D01–D10, not C01–C10.

Repair:
- use the explicit equivalence migration in §11: D01–D08 may certify C01–C08 onboarding clearance; D09–D10 remain demo-only records; full campaign resumes at C09/open Chapter-2 nodes.

## P9-04 — Quit during transit conditional UX wording

Conflict:
- Phase-6 text left two possibilities (`if persistence supports...`);
- Phase 8 later locked deterministic reconstruction rather than fragile mid-phase serialization.

Repair:
- Phase-8 decision wins: persist committed input + safe tick/cursor metadata; reconstruct deterministic transit on resume; return paused at recovered playback point.

## P9-05 — Gamepad priority wording

Conflict/age issue:
- early `GAME_BIBLE.md` language says mouse-first priority until UX architecture is complete;
- Phase 6 and 8 now define gamepad/Deck paths.

Repair:
- mouse remains the preferred efficiency baseline, but **gamepad/Steam Deck support for every mandatory action is now part of the canonical UX acceptance contract**.
- no feature may depend exclusively on hover or keyboard shortcuts.

## P9-06 — Challenge unlock vs imported knowledge

Potential ambiguity:
- demo can document supports/species earlier than normal campaign;
- Challenge mode unlocks after Tier-2 capstone.

Repair:
- imported knowledge never substitutes for the capstone completion flag. Challenge mode still unlocks through the authored Tier-2 capstone.

## P9-07 — Results write timing

Potential ambiguity:
- Causal Review appears before Results, but review already knows success/medal result.

Repair:
- simulation computes success/medal predicates before review;
- campaign progression is **committed exactly once at Results-finalization boundary**;
- review may display provisional/final evaluated outcome without mutating campaign progression;
- if the player exits a successful Review, Results finalization must occur atomically before returning to map.

## P9-08 — Active-run abort semantics

Previously underspecified.

Repair:
- aborting transit is allowed through explicit confirmation, discards only active run, and returns to committed layout in Planning; no persistent resource or punishment exists.
- production implementation may omit a fast abort button from tutorials, but the state transition must be safe.

---

# 15. Phase-9 acceptance checklist

- [x] one continuous path exists from first boot to campaign completion;
- [x] first 5 minutes, first 30 minutes, first 2 hours, midpoint, hour 8–12 completion, and 20+ hour mastery are simulated;
- [x] every stage states what the player knows, sees, chooses, risks, learns, unlocks, saves, and wants next;
- [x] successful-first-attempt contract traced through Brief -> Planning -> Launch -> A–I -> Review -> Results;
- [x] recoverable cascade failure traced through the same path and targeted retry;
- [x] bounded discovery case traced without random authority or blind guessing;
- [x] 48-contract/six-tier prerequisite invariants validated;
- [x] mandatory progression cannot depend on medals, XP, currency, grind, generated challenges, or achievements;
- [x] deterministic unlock state is defined;
- [x] quit in Planning, Launch Confirm, Transit, Review, Results, and crash recovery have safe semantics;
- [x] abandon semantics defined;
- [x] Causal Review requests are backed by structured Phase-8 event/snapshot data;
- [x] mouse and gamepad/Deck paths exist for every mandatory action;
- [x] high-UI-scale path does not require tiny pointer precision;
- [x] demo -> full transfer has exact ID/progression/knowledge behavior;
- [x] imported demo knowledge cannot skip Tier-2 Challenge unlock gate;
- [x] 20+ hour template/support/isolation/brute-force/content-exhaustion risks identified for destructive Phase-10 testing;
- [x] contradiction ledger contains explicit canonical answers rather than leaving obvious mismatches unresolved;
- [x] no production code was started;
- [x] `DESIGN COMPLETE` remains NO pending Phases 10–11.

**Phase-9 result: PASS.**

---

# 16. Required Phase-10 attack surface

Phase 10 must attempt to destroy the current design rather than add breadth.

Mandatory attacks:
1. fun risk — is prediction/revision actually more satisfying than static placement or random retry?
2. dominant layouts — test edge/corner/central-soother/growth-reserve templates across representative contracts;
3. support dominance — calculate whether Cooler+Filter, Baffle+Hushling, or another pair is optimal too often;
4. isolation dominance — measure how often Bronze permits simple maximum spacing;
5. welfare/scoring exploits — search for medals that reward harmful or degenerate play indirectly;
6. state-machine abuse — spam launch/cancel/retry/reset/abort/settings/save/quit across boundaries;
7. causality ambiguity — concurrent roots, simultaneous thresholds, grouped propagation, growth-block loops, delayed reactive outputs;
8. persistence corruption/version mismatch — interrupted writes, legacy content versions, demo migration mismatch, cloud/local divergence;
9. controller/accessibility blockers — max UI scale, keyboard-only, controller-only, reduced motion, no audio, color-independent cues;
10. content exhaustion — role overlap across 22 species and whether advanced species truly add decisions;
11. generator degeneracy — static solutions, opaque chains, same concept under reskinned manifests, solver false positives/timeouts;
12. campaign prerequisite holes — every branch path must teach all mandatory assumed knowledge;
13. technical scope risk — Causal Review, solver/generator, animation-event synchronization, and save migration must not exceed the compact production ceiling;
14. demo mispositioning — test whether a player can still reasonably conclude it is mainly a static packing game;
15. implementation ambiguity — collect every sentence that still requires a programmer to invent a gameplay rule.

Phase 10 should produce explicit exploit cases, severity, reproduction steps, design/technical correction, and retest criteria. Only after those fixes pass may Phase 11 perform final cross-file reconciliation and specification freeze.