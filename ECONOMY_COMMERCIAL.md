# ORGANISM CARGO — ECONOMY / RETENTION / COMMERCIAL MODEL

Status: **CANONICAL PHASE 7 — LOCKED**
Last updated: 2026-08-15

This file defines the commercial model, progression economy, campaign unlock rules, medal policy, replay/retention architecture, demo commercial boundary, store positioning, achievement philosophy, discount principles, ethical monetization limits, post-launch expansion boundary, and Phase-7 acceptance tests for **Organism Cargo**.

It is subordinate to the product thesis in `GAME_BIBLE.md`, the authoritative simulation in `MECHANICS.md`, the decision layer in `DECISION_ARCHITECTURE.md`, the content counts and campaign grammar in `CONTENT_ARCHITECTURE.md`, and the player-facing interaction contract in `UX_ARCHITECTURE.md`.

No commercial, progression, retention, or monetization decision may weaken the core learning loop:

**read → arrange → verify → commit → observe → explain → revise**.

---

# 1. Phase-7 design principles

The commercial and progression layer has six obligations:

1. **Charge for a complete game, not for relief from friction.**
2. **Reward mastery with access, recognition, and optional challenges rather than numerical power.**
3. **Never make failure expensive.** A failed transit is evidence and must remain safe to retry.
4. **Never require replaying solved content for currency.** Replaying must be chosen for mastery, alternate solutions, medals, discovery, or enjoyment.
5. **Use retention through curiosity and competence, not obligation.** No daily streaks, expiring rewards, energy, battle passes, or fear-of-missing-out schedules.
6. **Protect the differentiator commercially.** Store material, demo structure, screenshots, and trailers must show that the hold changes *after* launch.

---

# 2. Commercial model — LOCKED

## 2.1 Base product

**Organism Cargo is a one-time premium purchase.**

The base game includes at launch:
- the complete 48-contract authored campaign;
- all 22 launch species;
- all 6 foundation supports;
- all 5 hold families / 12 authored layouts;
- all 7 route-hazard families and 18 authored route profiles;
- all 24 generated/recombined challenge templates;
- all 6 authored final mastery contracts inside the 48;
- full Codex;
- all standard accessibility/settings features;
- all launch achievements;
- generated challenge mode;
- deterministic seed sharing where technically practical without a backend.

No mechanically important launch content is sold separately.

## 2.2 Prohibited launch monetization

The game has:
- no ads;
- no loot boxes;
- no gacha;
- no paid power;
- no paid hints required to progress;
- no consumable purchases;
- no energy/lives system;
- no paid retries;
- no premium currency;
- no battle pass;
- no season pass required for the base campaign;
- no FOMO shop;
- no rotating paid inventory;
- no mandatory account;
- no subscription;
- no real-money species unlocks;
- no real-money support unlocks;
- no paid medal boosters;
- no purchase that changes simulation balance.

## 2.3 Cosmetic DLC

No cosmetic DLC is required in the launch plan.

A later low-cost supporter/cosmetic pack is permissible only if:
- the base game already feels visually complete;
- it contains presentation-only items such as alternate hold trim, soundtrack/artbook, cosmetic organism variants, or developer-support extras;
- cosmetics never affect readability or disguise gameplay states;
- critical state colors/shapes/icons remain canonical and cannot be replaced by ambiguous cosmetics.

The project must not create artificial cosmetic scarcity to justify such a pack.

---

# 3. Current market evidence and pricing decision — 2026-08-15

Prices below are current US Steam list prices observed during this Phase-7 pass. They are evidence, not permanent facts, and must be rechecked close to release.

Relevant comparables:
- `Outpacked` — **$7.99**; compact static grid-packing logic puzzle with 61 handcrafted levels and Workshop. Source: https://store.steampowered.com/app/4012320/
- `Rusty's Retirement` — **$6.99**; compact desktop idle strategy/simulation with strong scope compression. Source: https://store.steampowered.com/app/2666510/
- `Backpack Battles` — **$14.99**; mature spatial inventory strategy with a demo and substantial systemic/replay content. Source: https://store.steampowered.com/app/2427700/
- `Strange Horticulture` — **$15.99**; highly specific compact puzzle/investigation game with a demo and strong authored identity. Source: https://store.steampowered.com/app/1574580/
- `Potion Craft: Alchemist Simulator` — **$19.99**; tactile systemic crafting/shop game with a larger established feature/content footprint. Source: https://store.steampowered.com/app/1210320/
- `The Roottrees are Dead` — **$19.99**; polished investigation game with substantial authored deduction content. Source: https://store.steampowered.com/app/2754380/

## 3.1 Locked pricing position

**Target US base list price: $14.99.**

Acceptable pre-release adjustment band: **$14.99–$17.99** only if final production quality, campaign length, replay depth, localization, and polish materially exceed the current minimum launch contract.

The default remains **$14.99** because:
- the project targets 8–12 hours for a first campaign clear plus mastery/replay;
- it has more systemic depth and content than a tiny static puzzle product;
- it remains intentionally compact and should not create a $20+ expectation for a large simulation sandbox;
- $14.99 sits near established premium systemic-indie comparables without pricing the game as disposable micro-content;
- the demo should reduce purchase uncertainty rather than a lower list price doing that work.

## 3.2 Price-floor content gate

Do not charge $14.99 unless all are true:
- all 48 campaign contracts are complete and validated;
- all 22 species are mechanically and visually readable;
- all 6 supports are useful in non-universal roles;
- all 7 hazard families are represented meaningfully;
- the Causal Review system is complete rather than placeholder text logs;
- campaign first-clear target remains approximately 8–12 hours for intended players;
- at least the 24 challenge templates or an equivalent validated long-tail system is present;
- accessibility and save/recovery commitments are implemented;
- demo demonstrates dynamic transit rather than static packing;
- the final build passes determinism and content-version QA.

If content is cut below this gate, price must be reconsidered rather than defended by marketing language.

## 3.3 Regional pricing

Regional prices should use the platform's current regional-pricing tools/recommendations as a starting point and be reviewed for affordability and major anomalies near launch.

Do not manually force simple FX conversion if it produces unreasonable local purchasing-power outcomes.

---

# 4. Discount policy principles

Discounts are acquisition tools, not artificial urgency systems.

## 4.1 Launch

Preferred launch offer:
- **10% launch discount** if platform rules and release plan support it;
- short standard launch window only;
- store page always shows the ordinary base price transparently.

A launch discount is optional, not necessary to satisfy the commercial model.

## 4.2 Early lifecycle

Principles:
- avoid immediately training players to wait for a large sale;
- no deep discount soon after launch merely to manufacture unit spikes;
- first ordinary seasonal discounts should normally remain modest, roughly 10–20%;
- deeper discounts should increase gradually only after the product has aged materially.

## 4.3 Mature lifecycle

Later 25–40% discounts are acceptable when they serve long-tail discovery and do not imply that early buyers paid for an unfinished version.

No exact calendar is design-canonical because platform events and commercial conditions change. The principle is canonical: **gradual, predictable discount depth; no fake scarcity.**

---

# 5. Persistent progression economy — NO CURRENCY

## 5.1 Decision

**The campaign uses no persistent currency, XP bar, consumable stockpile, or grind resource.**

There are therefore no:
- coins;
- credits;
- reputation points;
- upgrade materials;
- stars spent as currency;
- XP levels;
- persistent support inventory quantities.

Why:
- no resource is needed to express the core competence fantasy;
- a currency would tempt replay-for-income behavior;
- purchased power would undermine authored contract validation;
- failure must remain safe and informative;
- unlock pacing can be expressed directly through campaign milestones.

## 5.2 What progression actually unlocks

Persistent progression consists of **access and knowledge**:
- campaign contracts;
- species Codex entries;
- trait-family documentation;
- support access;
- hold layouts/families;
- route hazard documentation;
- generated challenge templates;
- mastery contracts;
- optional challenge modifiers;
- cosmetic recognition/badges if retained.

None make earlier rules numerically easier.

---

# 6. Campaign unlock architecture — 48 contracts

The 48 authored contracts are organized into **six progression tiers of eight contracts each**. These are mechanical progression tiers; presentation may name them as chapters/routes/clearance levels later without changing unlock logic.

Tier mapping:
- Tier 1: contracts 01–08 — fundamentals;
- Tier 2: 09–16 — first interacting systems;
- Tier 3: 17–24 — temporal planning and support tradeoffs;
- Tier 4: 25–32 — composite species, brownouts, stronger cascades;
- Tier 5: 33–40 — multi-pressure synthesis and bounded uncertainty;
- Tier 6: 41–48 — mastery, including the six authored final mastery contracts allocated by `CONTENT_ARCHITECTURE.md`.

## 6.1 Contract graph

Main campaign progression uses a **small branching graph**, not a strict single-file queue and not an open checklist.

Rules:
1. Contract 01 is available at new game.
2. Completing a contract's mandatory delivery conditions permanently marks it cleared.
3. Most clearances reveal 1–2 next contracts within the current tier.
4. A player normally has 2–4 uncleared campaign choices after the opening tutorials.
5. The tier capstone becomes available after the player clears the required foundational nodes for that tier; exact authored dependencies are content data.
6. Clearing the tier capstone opens the next tier.
7. Optional medals never gate the next campaign tier.
8. No solved contract must be replayed to unlock mandatory campaign content.

The graph may require specific prerequisite *contracts* when a later contract assumes a taught rule, but not a total number of medals or points.

## 6.2 Discovery entries

A discovery contract may introduce one bounded unknown trait/behavior under the Phase-4 uncertainty rules.

On successful completion or the authored evidence threshold defined for that discovery:
- the relevant Codex rule becomes permanently documented;
- future contracts can treat that rule as known;
- the unlock is knowledge only, not stat power.

A discovery unlock cannot be lost.

## 6.3 Supports

Supports unlock at authored teaching milestones.

Rules:
- once introduced, a support is globally known;
- contracts still define their own support allowance;
- unlocking a support does **not** mean it can be brought into every contract;
- player never buys/restocks support units.

This preserves contract validation while allowing the player's mental toolset to expand.

## 6.4 Holds and hazards

Hold layouts and hazard families enter the campaign through milestone contracts.

After first introduction:
- their Codex/help entry unlocks;
- they may appear in later authored/generated challenges according to tier rules;
- no purchase or upgrade is required.

## 6.5 Generated challenge mode unlock

Generated/recombined Challenges become available after **Tier 2 capstone completion (contract progression through roughly the first 16 authored contracts)**.

Reason:
- before this point the player has too little vocabulary for recombination to be meaningful;
- after this point the system can provide optional variety without distracting from onboarding.

Challenge template availability then expands automatically as the player documents the required species/support/hazard rule families.

The generator may never introduce a rule the player's campaign save has not documented unless the challenge is explicitly labeled `Discovery` and uses canonical bounded-unknown rules.

## 6.6 Mastery content unlock

The six authored final mastery contracts become available through Tier 6 prerequisites, not medal totals.

Optional `Mastery Variant` modifiers for earlier contracts may unlock after:
- campaign contract cleared once; and
- all mechanics used by the variant have been documented.

No Gold medal prerequisite is required for access.

---

# 7. Medal structure

## 7.1 Canonical medal semantics

Every scored contract can expose:
- **Bronze** — mandatory delivery success / valid clear;
- **Silver** — optional stronger condition demonstrating sound control;
- **Gold** — optional mastery condition requiring an elegant or stricter solution.

If a contract's existing content definition uses separate mandatory + Silver + Gold without a named Bronze, the UI maps successful mandatory completion to Bronze-equivalent campaign completion.

## 7.2 Medal gating

Medals do **not** gate:
- main campaign progression;
- species;
- supports;
- Codex facts needed for future mandatory contracts;
- accessibility options;
- save slots;
- core challenge mode.

Medals may gate only:
- cosmetic profile recognition;
- optional challenge badges;
- a small set of explicitly non-essential medal showcase achievements;
- leaderboard-like local summaries if implemented;
- convenience filtering such as `show contracts without Gold`.

## 7.3 No medal currency

Medals are not spent.

There is no `collect 30 Gold medals to buy X` system.

Reason: spending medals converts mastery evidence into a grind economy and pressures players to solve optional optimization goals before they want to.

## 7.4 Welfare rule

No medal may reward:
- intentionally making an organism CRITICAL;
- sacrificing a manifest organism unless the contract's product thesis is explicitly non-welfare and still respects prior scoring prohibitions;
- farming repeated state transitions for score;
- prolonging a solved transit artificially;
- exploiting save/reload randomness, because transit has no outcome randomness anyway.

---

# 8. Retry and anti-grind contract

The following are non-negotiable:

1. Retry is unlimited.
2. Retry costs no persistent resource.
3. Reset costs no persistent resource.
4. Failure cannot delete campaign progress.
5. Failure cannot consume a permanent support inventory.
6. Failure cannot reduce a progression meter.
7. Replaying a solved contract is never required for money/XP/material.
8. No mandatory content is locked behind cumulative playtime.
9. No random reward drop is required for completion.
10. Save/reload cannot improve a deterministic transit result from the same committed state.

A player may spend hours optimizing one Gold medal because the puzzle is enjoyable, but the game never economically coerces that behavior.

---

# 9. Retention architecture

Retention means **the player voluntarily wants to understand one more interaction**.

## 9.1 First 30 minutes

Goals:
- prove drag/rotate/inspect frictionlessness;
- show first visible post-launch state change within the first few contracts;
- produce at least one understandable failure cascade;
- teach Causal Review as a useful tool;
- give the player a successful hypothesis-driven retry;
- reveal that species will recombine rather than merely become harder versions.

Retention promise at 30 minutes:
> “I understand enough to make predictions, and I can already see combinations I haven't mastered yet.”

Do not introduce meta-economy, shops, reward calendars, or broad challenge menus here.

## 9.2 First session — 25–45 minutes

Goals:
- complete several short contracts;
- teach one environmental channel, one social relationship, and one temporal consequence;
- unlock at least one new organism or support conceptually;
- end on a clean choice of next campaign contracts;
- ensure stopping is safe and immediate.

The session ending should create curiosity, not obligation.

## 9.3 First 2 hours

By roughly two hours, the player should have experienced:
- heat, stress, and contamination as distinct pressures;
- at least one growth-space problem;
- at least one support tradeoff;
- at least one route hazard that changes the best initial arrangement;
- at least one discovery rule;
- a contract with multiple valid approaches;
- access or imminent access to generated Challenges.

The player should now recognize the game as a system, not a level pack of static packing puzzles.

## 9.4 Campaign midpoint

At the midpoint the game must shift from `learn one rule` to `compose known rules`.

Retention comes from:
- composite species;
- route timing windows;
- support power/space conflicts;
- conditional benefits;
- future-footprint changes;
- counterintuitive useful-dangerous relationships;
- optional medals that ask for cleaner control, not larger numbers.

Avoid introducing a flood of brand-new systems merely to create novelty.

## 9.5 Campaign completion

Completion must feel like full ownership of the rules, not a cliffhanger engineered for DLC.

The player receives:
- completed campaign state;
- final mastery summary;
- all unlocked challenge templates compatible with documented rules;
- campaign-wide medal summary;
- access to replay any authored contract;
- no forced New Game+.

## 9.6 20+ hour mastery

Long-tail play comes from:
- Gold optimization;
- alternate valid layouts;
- authored mastery contracts;
- deterministic generated/recombined challenges;
- seed sharing;
- optional constraint modifiers;
- personal solution efficiency;
- replaying older contracts with deeper understanding.

It does **not** come from:
- XP farming;
- daily chores;
- content timers;
- randomized loot;
- stat prestige resets;
- infinite numerical scaling.

---

# 10. Challenge / replay model

## 10.1 Authored contracts

Authored campaign contracts remain the primary teaching and curated mastery spine.

Every authored contract has:
- fixed content version;
- deterministic route sequence/seed;
- explicit mandatory predicates;
- optional medal predicates where used;
- known introduction dependencies.

## 10.2 Generated/recombined challenges

Generated challenge templates use Phase-5 generation rules and Phase-4 simulation authority.

Rules:
- derive from data-defined templates;
- use deterministic seeds;
- validate at least one legal successful strategy or construct from a known-valid solution and mutate safely;
- reject static/degenerate cases;
- reject opaque causal chains beyond review readability thresholds;
- record generator/content version with the seed;
- may expose multiple valid solutions;
- never award persistent currency.

## 10.3 Seed sharing

Preferred implementation:
- a challenge can display a compact seed/code containing generator version + seed ID where feasible;
- another player with the same compatible game version can enter the code locally;
- no account or server is required for the basic feature.

If later content versions change generation, old seed codes either:
- reconstruct using versioned definitions; or
- display a clear incompatibility message rather than silently producing a different puzzle.

## 10.4 Daily / weekly-style seeds

No live-service daily system is required.

An offline-friendly `Featured Seed` system is allowed only if it is generated deterministically from local calendar date + shipped seed table/version and has **no streak, expiration reward, currency, or exclusive content**.

Rules:
- missing a day/week has no penalty;
- old featured seeds remain accessible through history if practical;
- there is no notification pressure;
- there is no exclusive achievement requiring consecutive attendance.

This feature is optional and may be cut without harming retention architecture.

## 10.5 Score philosophy

The base design should favor **predicate medals** over one opaque global score.

If a numeric score is added later, it must be decomposable into visible factors such as:
- organism welfare;
- optional support restraint;
- power efficiency;
- avoided undesirable states;
- contract-specific constraints.

Never score raw speed of mouse input or number of planning moves; planning is intentionally free.

---

# 11. Achievement architecture

Achievements recognize milestones and understanding. Target launch count should remain moderate, roughly **30–45**, rather than hundreds of filler badges.

Allowed categories:

## Campaign milestones
- clear first contract;
- clear each major progression tier;
- complete campaign.

## Mechanical discoveries
- cause/recover from a named state interaction;
- use one organism's harmful trait as part of a successful solution;
- complete a successful transit involving growth after commitment;
- survive a planned support brownout;
- use a filter-feeder/symbiosis/etc. in a meaningful authored condition.

## Mastery
- Gold selected representative contracts;
- Gold all six final mastery contracts;
- solve a high-tier challenge under an optional constraint.

## Exploration
- document all species;
- document all hazard families;
- use every support successfully.

## Causal-review literacy
- identify/jump through a multi-link causal chain if implementation can track this robustly;
- succeed after retrying from a previously failed committed layout with a targeted change.

Prohibited achievements:
- launch 1,000 shipments;
- fail 500 times;
- play 100 hours;
- open the game on 30 consecutive days;
- grind the same action thousands of times;
- idle for arbitrary duration;
- missable FOMO calendar events;
- achievements dependent on paid DLC to maintain base-game 100% unless platform handling is intentionally separated.

---

# 12. Demo commercial boundary — LOCKED

The public demo is the Phase-5 ten-contract slice:
- 10 authored contracts;
- 10 species total;
- 8 fully documented + 2 bounded discovery encounters;
- 4 supports: Cooler, Filter, Baffle, Feed Cartridge;
- 3 hold layouts from two families;
- 3 route-hazard families;
- 3 generated/recombined challenge templates;
- 1 discovery contract;
- target first-clear time roughly 60–90 minutes.

## 12.1 Demo objective

The demo must prove three things before ending:
1. arrangement matters;
2. **transit changes the system after commitment**;
3. Causal Review lets the player understand and improve a failed plan.

The demo is a product proof, not a teaser consisting mainly of tutorials.

## 12.2 Demo ending beat

The demo ends immediately after the first contract that combines:
- future growth timing;
- a route hazard;
- a support tradeoff;
- at least one meaningful state change after launch.

The completion screen explicitly previews categories of later complexity without spoiling exact solutions:
- more composite organisms;
- Nest Pad / Monitor Beacon;
- brownouts;
- additional hold geometries;
- advanced hazards;
- multi-stage cascades;
- mastery/generated challenges.

## 12.3 Save transfer

**Demo save transfers to the full game.**

Transfer includes:
- completed demo contract states;
- best demo medals;
- Codex discoveries already earned;
- settings/accessibility configuration;
- last valid campaign position;
- challenge/demo records where compatible.

On first full-game launch, the player may either continue from transferred progress or restart campaign from contract 01 without deleting transferred settings.

The transfer must validate content/save version and fail gracefully if incompatible.

## 12.4 Withheld systems

The demo intentionally withholds:
- Nest Pad;
- Monitor Beacon;
- most composite Tier 4–6 species;
- advanced bounded uncertainty;
- later brownout combinations;
- final hold families;
- final hazard families;
- full 24-template challenge set;
- final mastery contracts.

Withholding exists to preserve later learning space, not to cripple the demo artificially.

## 12.5 Demo anti-mispositioning test

Fail the demo design if a player can finish it believing:
> “This is mainly a game where I fit creatures into a box while respecting adjacency rules.”

At least half of the demo's memorable successful/failure moments after onboarding must depend on transit-time changes.

---

# 13. Steam store positioning

## 13.1 Primary positioning sentence

**Pack living cargo, commit the hold, and predict the deterministic chain reactions as strange organisms grow, panic, feed, infect, soothe, and change each other during transit.**

Do not lead with `packing game`.

## 13.2 Primary tags — intended positioning

Highest-priority store/tag territory:
- Puzzle;
- Strategy;
- Simulation;
- Singleplayer;
- Indie.

Strong secondary tags if supported by the finished presentation:
- Logic;
- Management (only if player expectations remain compact; otherwise omit);
- Cute;
- Relaxing / Cozy only if trailers honestly show failure/cascade pressure rather than false calm;
- Creature Collector **must not** be used because collecting is not the game;
- Inventory Management should be treated cautiously because it can misposition the game as an autobattler/static packing title.

Actual Steam tags must be revalidated against current platform taxonomy at store setup.

## 13.3 Short description draft contract

A compliant short description must contain all three ideas:
1. living cargo;
2. commit/launch;
3. organisms change/interact during transit.

Canonical working copy:

> Pack a tiny hold with strange living cargo, commit to launch, then watch a deterministic transit simulation unfold. Predict how organisms will grow, feed, panic, infect, soothe, and change one another — explain the cascade, revise your layout, and deliver them safely.

This is working store copy, not the final commercial title/tagline.

## 13.4 Trailer structure

Target primary trailer: roughly 60–90 seconds.

Beat obligations:

### 0–5 sec — visual hook
Show a compact hold full of distinct organisms; doors close / `LAUNCH` commits.

### 5–15 sec — immediate cascade
Show 3–4 legible state changes: organism grows, neighbor loses space, stress wave propagates, another organism soothes/filters, objective changes.

### 15–25 sec — player agency
Cut back to planning: drag, rotate, inspect trait, reserve future footprint, choose support.

### 25–40 sec — prediction payoff
Launch revised plan; show same situation resolve differently.

### 40–55 sec — breadth
Rapid shots of contamination, feeding, sleep/wake, route hazard, brownout, directed interaction, different hold geometry.

### 55–70 sec — causal review
Show timeline/jump-to-cause briefly so failure reads as learnable strategy, not chaos.

### 70–end — progression/breadth/demo CTA
Show species/holds/challenge seed/mastery montage and demo availability.

Prohibited trailer failure:
- first 20 seconds only show dragging pieces into a grid;
- long cinematic worldbuilding before mechanics;
- unexplained chaos with no visible player prediction/revision;
- presenting hundreds of creatures as a collection fantasy.

## 13.5 Screenshot obligations

A minimum effective screenshot set must include:
1. planning hold with manifest + readable organisms;
2. active transit with one obvious state cascade;
3. growth changing footprint after launch;
4. environmental hazard + support interaction;
5. Causal Review timeline highlighting a chain;
6. different hold geometry;
7. advanced composite species situation;
8. campaign/challenge progression screen only after core gameplay screenshots.

At least half of store screenshots should visibly contain transit state/effect information, not just tidy initial layouts.

## 13.6 Anti-mispositioning rules

Do not market as:
- packing simulator;
- inventory autobattler;
- pet simulator;
- creature collector;
- transport tycoon;
- ship management game;
- physics sandbox;
- roguelite;
- idle game.

If press/players consistently describe the demo as one of these before release, revisit store presentation and possibly the first-session design before shipping.

---

# 14. Post-launch content boundary

The base game must stand alone. Post-launch work is optional and depends on reception, not an unfinished roadmap promise.

## 14.1 Free update territory

Free updates are preferred for:
- balance fixes;
- accessibility improvements;
- quality-of-life features;
- additional generated challenge templates using existing content grammar;
- a small number of new authored contracts using existing species/rules;
- seed-sharing improvements;
- bug fixes;
- localization additions where feasible;
- minor cosmetic variants;
- platform/Deck improvements.

## 14.2 Paid expansion territory

A paid expansion is allowed only when it contains a **substantial self-contained content layer**, for example:
- a meaningful new campaign chapter;
- several new species compositions;
- new hold family/layouts;
- at least one genuinely new but comprehensible trait/hazard grammar extension;
- new authored contracts and mastery content;
- corresponding UX/tutorial/codex support.

A paid expansion must not merely unlock species that obviously should have shipped in the base 22-species roster.

## 14.3 Simulation-grammar compatibility

Expansion rules must:
- preserve deterministic simulation;
- preserve causal logging;
- maintain versioned content definitions;
- remain teachable;
- not invalidate old contract solutions without explicit version migration;
- avoid requiring the base campaign to be rebalanced around ownership of expansion content.

## 14.4 Fragmentation prohibition

Do not create multiple small gameplay DLC packs where players need to inspect compatibility before sharing seeds.

If expansion ownership affects challenge seeds, the seed header must declare required content and fail clearly when content is absent.

---

# 15. Commercial and retention failure modes

## F1 — Static-packing marketing trap
Symptom: wishlisters/reviewers call it a creature packing game and do not mention transit prediction.

Response: change trailer/store/demo emphasis before adding more content.

## F2 — Price/content mismatch
Symptom: first-clear content falls materially below the 8–12 hour target or challenge breadth is cut while price remains $14.99+.

Response: restore content/polish or re-evaluate price.

## F3 — Medal compulsion blocks campaign
Symptom: player must optimize old contracts to reach new main mechanics.

Response: remove medal gate. Main campaign is mandatory-clear gated only.

## F4 — Challenge mode undermines campaign
Symptom: players encounter untaught rules through generated content or prefer generator grind to authored onboarding.

Response: strengthen documentation/tier locks and keep generation subordinate to documented campaign vocabulary.

## F5 — Retry punishment appears
Symptom: any failed transit consumes currency, stock, rating, or permanent resource.

Response: remove the persistent cost.

## F6 — Progression feels flat without currency
Symptom: contract completion lacks anticipation because no XP/coins exist.

Response: improve direct access/knowledge reveals, contract graph choice, species/support introductions, and visual progression rather than add currency reflexively.

## F7 — Gold becomes one-template puzzle
Symptom: one universal low-support/low-risk arrangement earns Gold across many contracts.

Response: author contract-specific optional predicates and challenge combinations; do not add grind.

## F8 — Daily feature creates obligation
Symptom: players feel they lose rewards by not checking in.

Response: remove streak/reward/expiration semantics; keep featured seeds archival and optional.

## F9 — DLC fragments deterministic sharing
Symptom: challenge codes produce silent differences across content ownership/version.

Response: version and declare required content, or disable incompatible import clearly.

## F10 — Store cozy label misleads
Symptom: players expect consequence-free organization and react negatively to failure/diagnosis.

Response: show stress, contamination, growth, failure, review, and retry in store materials; do not overuse cozy framing.

---

# 16. Phase-7 acceptance tests

Phase 7 passes only if all are true.

## Commercial model
- [x] one-time premium purchase is locked;
- [x] base launch content is complete rather than mechanically partitioned into DLC;
- [x] no paid power / ads / loot boxes / energy / subscription / FOMO system exists;
- [x] target price and content gate are defined;
- [x] discount principles do not rely on fake urgency.

## Progression
- [x] no persistent currency or XP is required;
- [x] campaign unlocks are direct prerequisite clears;
- [x] medals do not gate main content;
- [x] supports/hazards/species knowledge unlock directly;
- [x] failure/retry consumes no persistent resource;
- [x] solved-contract replay is never required for economy.

## Retention
- [x] first-30-minute promise is defined;
- [x] first-session / two-hour / midpoint / completion / 20+ hour retention sources are defined;
- [x] long-tail play uses mastery and deterministic recombination rather than grind;
- [x] daily/weekly-style content, if retained, has no streak/FOMO reward.

## Demo
- [x] ten-contract demo boundary is preserved;
- [x] demo proves transit-time state change;
- [x] demo save transfer is specified;
- [x] withheld content creates learning space rather than artificial crippleware.

## Store
- [x] target positioning sentence exists;
- [x] primary/secondary tag intent is defined;
- [x] trailer beats are defined;
- [x] screenshot obligations are defined;
- [x] anti-mispositioning rules are defined.

## Post-launch
- [x] free-update territory is separated from paid-expansion territory;
- [x] base game remains complete without expansion;
- [x] deterministic seed/content-version compatibility is protected;
- [x] expansion fragmentation is prohibited.

**Result: PASS — Phase 7 may close.**

---

# 17. Locked Phase-7 summary

The game's commercial/economy thesis is now:

> **Sell one complete $14.99-class premium systemic puzzle game. Progress through knowledge and direct campaign unlocks, never through currency. Let players retry freely, optimize because they want mastery, and use a generous save-transferring demo to prove that living cargo changes after the doors close. Retain players through curiosity, causal understanding, combinatorial challenges, and deterministic mastery — never through obligation.**

No production code begins here. Phase 8 must translate the already-locked product, mechanical, content, UX, and commercial contracts into an implementation-ready technical architecture.