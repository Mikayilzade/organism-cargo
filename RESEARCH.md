# RESEARCH

Last updated: 2026-08-15
Research state: **broad Phase 1 discovery complete; concept tournament prepared**

This file contains dated evidence, hypotheses, candidate concepts, comparisons, rejected directions, and the shortlist that feeds the concept tournament. It is intentionally separate from `GAME_BIBLE.md`: research may remain probabilistic; the Bible must eventually contain only canonical design decisions.

---

# 1. Research rules

1. Date market-sensitive conclusions.
2. Distinguish first-party facts, measured third-party data, estimates, journalism/anecdotes, and our own inference.
3. A successful reference proves that a player desire exists; it does not prove that cloning the game will succeed.
4. A fast-growing microgenre is often a warning because supply can respond faster than this project can ship.
5. Favor durable motivations: mastery, transformation, optimization, discovery, collection, expression, risk/reward, problem solving, visible progress, surprise, and story-generating consequences.
6. Market data informs concept selection but does not replace a fun core loop.
7. A candidate must survive with its theme stripped away. If the underlying decisions are dull, lore cannot rescue it.
8. High score does not override a fatal scope, derivative, readability, or content-burden problem.

---

# 2. August 2026 market / production signals

## 2.1 Steam is attractive and brutally crowded
Sensor Tower's 2026 State of Gaming report describes continued strength in Steam units, premium revenue, and releases, while noting that larger publishers drove much of the growth.

Source:
- https://sensortower.com/report/state-of-gaming-2026

A separate Q1 2026 third-party Steam analysis estimated roughly 6,500 releases in 112 days, or more than 55 releases per day. Treat the exact revenue estimates in that analysis cautiously, but the release-volume signal is directionally useful.

Source:
- https://games-stats.com/blog/Steam_in_Q12026/

**Project implication:** discovery cannot depend on generic quality. The game needs a sentence-, screenshot-, and short-clip-level hook.

## 2.2 Depth/replayability correlates with breakout outcomes, but causality is uncertain
Turbine Games analyzed 1,712 Q4 2025 indie Steam launches and found strong associations between its success threshold and both multiplayer tags and longer average playtime. It reports 67% of its successes at 10h+ average playtime versus 13% of failures, while explicitly acknowledging that retention and content depth cannot be cleanly separated.

Source:
- https://turbine.games/2026/05/27/steam-indie-success-factors/

**Project implication:** favor recombination, mastery, and repeatable systemic situations. Do not inflate length with grind just to satisfy a duration target.

## 2.3 Multiplayer has distribution power, but is not free scope
2025–2026 breakout coverage repeatedly shows friend-group games producing strong organic stories and clips. Current examples include PEAK, R.E.P.O., Meccha Chameleon, and Big Walk. This matches the Turbine correlation but does not prove that multiplayer itself causes success.

Examples:
- https://www.pcgamer.com/games/puzzle/big-walk-has-sold-1-million-copies-making-it-a-bigger-hit-than-untitled-goose-game/
- https://www.windowscentral.com/gaming/the-viral-hit-of-2026-has-sold-15-million-copies-in-a-month-on-steam-costs-usd5-and-was-made-by-2-people

**Project implication:** design for *story-generating situations* and clipability, but preserve a single-player baseline unless a later prototype proves multiplayer is worth networking, synchronization, lobby, failure-state, and QA cost.

## 2.4 Sorting and retail simulators validate task satisfaction but are already crowded
PC Gamer documented a rapid August 2026 wave of shelf/tidying games after the breakout of *Librarian: Tidy Up the Arcane Library!*, and separately noted continuing floods of retail simulators.

Sources:
- https://www.pcgamer.com/gaming-industry/steam-week-in-review-games-about-sorting-1000s-of-mundane-objects-onto-shelves-are-the-new-craze-sweeping-pc-gaming/
- https://www.pcgamer.com/gaming-industry/steam-week-in-review-a-torrent-of-janky-retail-sims-continues-to-flood-steam-and-theres-no-end-in-sight/

**Project implication:** extract the satisfaction of chaos → order, broken → repaired, unknown → understood, inefficient → elegant. Do not make a plain sorting or generic shop clone.

## 2.5 Repair/diagnosis is commercially legible, but literal electronics repair is now occupied territory
Coverage around *ReStory* reports that the electronics-repair shop fantasy recouped its budget rapidly after its August 2026 launch and reached millions of dollars in early sales according to its publisher.

Source:
- https://www.gamesradar.com/games/simulation/chill-shop-sim-about-repairing-off-brand-ps1s-makes-its-budget-back-within-12-hours-and-earns-usd3-million-days-after-launch/

**Project implication:** diagnosis + testing + visible repair is a strong verb family. If we use it, the objects and rules must depart clearly from normal consumer electronics.

## 2.6 Tiny, tightly framed games can have enormous reach
### Papers, Please
Lucas Pope's desk-bound inspection game reached 5 million copies over its first decade. Its design layers mechanical document checking, efficiency, moral choices, family pressure, and narrative consequences into a compact workspace.

Sources:
- https://www.gamedeveloper.com/business/papers-please-has-sold-5-million-copies-in-a-decade
- https://fguillen.github.io/PapersPleaseDevlogScrap/

**Lesson:** a mundane task can support memorable play when multiple systems make the same action carry conflicting meanings.

### Strange Horticulture
A two-brother project used a compact desk/shop format, a strong occult-plant fantasy, low-pressure puzzle solving, and a well-performing demo. Publisher discussion attributes its long tail partly to theme specificity and word of mouth.

Sources:
- https://www.gamedeveloper.com/business/deep-dive-inside-strange-horticultures-delightful-steam-success
- https://www.pcgamer.com/how-strange-horticultures-devs-went-from-flash-to-one-of-the-best-games-of-the-year/

**Lesson:** specificity matters. “Occult plant shop” is easier to remember and recommend than “cozy puzzle game.”

### Buckshot Roulette
A compact, highly legible high-stakes ruleset became a major viral success. The official Steam page shows a tightly scoped first-person gambling/horror premise; later publisher/community communication reported millions of players/sales.

Sources:
- https://store.steampowered.com/app/2835570/BuckshotRoulette/
- https://steamcommunity.com/app/2835570/announcements/

**Lesson:** one room, one opponent, one striking object, and a tiny rule vocabulary can still produce tension and shareability. We should borrow compression and consequence, not its literal roulette/gambling design.

### Rusty's Retirement
This solo-developed 2024 idle farming game differentiates itself partly through *where* it runs: a thin strip at the bottom or side of the desktop. The official Steam description centers multitasking and automation; contemporary coverage reported 100,000 sales in five days.

Sources:
- https://store.steampowered.com/app/2666510/Rusty%27s_Retirement/
- https://www.pcgamesn.com/rustys-retirement/high-sales

**Lesson:** presentation format itself can be the hook. A project need not compete on world size if it owns an unusual interaction context.

### Backpack Battles
The game turns inventory arrangement and adjacency into the main strategic system rather than a housekeeping UI. It sold strongly in Early Access according to developer/publisher-reported figures and later launched in 2025.

Sources:
- https://store.steampowered.com/app/2427700/Backpack_Battles/
- https://gameworldobserver.com/2024/04/25/backpack-battles-sales-640k-copies-china-top-country

**Lesson:** spatial arrangement becomes deep when adjacency, timing, and combination rules make every placement consequential.

### The Roottrees are Dead
The concept began as a visually simple browser/itch project, grew from a game-jam prototype, and later became a polished Steam investigation game. The Steam version has thousands of overwhelmingly positive reviews; the itch page preserves the free prototype history.

Sources:
- https://jjohnstongames.itch.io/the-roottrees-are-dead
- https://store.steampowered.com/app/2754380/
- https://www.theverge.com/ai-artificial-intelligence/686651/roottrees-ai-original-illustrator-replacement

**Lesson:** prove the cognitive core cheaply before expensive presentation work. Investigation can be compelling through information structure rather than environment count.

### Potion Craft
Developer interviews and official community posts describe a small core team, a strong prelaunch demo/wishlist base, and many interdependent systems. Its tactile map-like potion-making interface gives the act of crafting a distinctive physical grammar.

Sources:
- https://vgtimes.com/vgtimes-interviews/114983-vgtimes-interview-with-the-author-of-potion-craft.html
- https://store.steampowered.com/news/posts/?enddate=1654716106&feed=steam_community_announcements

**Lesson:** a craft system is much stronger when the *process* is a game, not merely selecting a recipe from a menu.

## 2.7 Strange specificity can itself be marketable
August 2026 coverage of *Horse Magnifier: The Full Horse* shows a deliberately absurd one-mechanic premise earning strong early user reception, while using Steam Workshop to extend its puzzle content.

Source:
- https://www.pcgamer.com/games/puzzle/this-weeks-most-compelling-new-steam-game-is-horse-magnifier-which-is-about-magnifying-horses/

**Project implication:** do not sand the final concept into generic professionalism. A weird but immediately understandable noun+verb combination can be an advantage.

## 2.8 AI-assisted production has a player-perception risk
A 2026 paper analyzing 508,192 English-language Steam reviews reports lower recommendation rates and more negative sentiment for games disclosing generative-AI use than for procedural-generation games; its qualitative review sample frequently associated generative AI with low developer investment.

Source:
- https://arxiv.org/abs/2608.11539

A separate 2026 paper argues that AI lowers coordination/production barriers while also increasing structural oversupply.

Source:
- https://arxiv.org/abs/2608.07825

**Project implication:** AI may help us plan and implement, but the shipped game must visibly feel intentional rather than mass-produced. Do not use cheap-looking generated assets as a substitute for art direction. Procedural systems that create player value are different from using generative content merely to reduce effort.

---

# 3. Durable opportunity territory

The broad scan strengthens, rather than weakens, the following territory:

> **A compact, tactile or highly readable workplace/machine/container fantasy in which an ordinary task becomes strategic because hidden or interacting rules create diagnosis, optimization, risk, and visible consequences.**

Promising verb families:
- inspect;
- test;
- connect;
- route;
- repair;
- classify;
- pack;
- isolate;
- configure;
- diagnose;
- salvage;
- transform;
- contain;
- infer.

Required second-order depth candidates:
- adjacency effects;
- hidden properties;
- cascading state changes;
- incomplete information;
- limited tests/tools;
- mutually incompatible objectives;
- timing/order dependency;
- persistent contamination/side effects;
- procedural contracts with solvability validation;
- risk/reward decisions;
- “minimum intervention” optimization.

The strongest opportunity is **not** “make a simulator.” It is “make one satisfying job whose rules are strange enough to generate mastery.”

---

# 4. Scoring framework

Each candidate is scored 1–5:

- **H — Hook clarity (20%)**: understandable and showable quickly.
- **D — Systemic depth (20%)**: simple rules can produce mastery and varied decisions.
- **S — Scope fitness (20%)**: realistic for a small AI-assisted project.
- **M — Market distinctiveness (15%)**: recognizable difference without incomprehensibility.
- **A — Asset efficiency (10%)**: low dependence on expensive bespoke content.
- **T — Technical feasibility (10%)**: lower implementation and QA risk.
- **C — Clipability (5%)**: readable/surprising moments worth sharing.

Formula:

`Score = 0.20H + 0.20D + 0.20S + 0.15M + 0.10A + 0.10T + 0.05C`

The score is a filter, not a winner selector. It currently misses emotional resonance, prototype feel, tutorial burden, and derivative risk, which must be stress-tested separately.

---

# 5. Expanded candidate field — 30 distinct seeds

| ID | Concept seed | Core hook | H | D | S | M | A | T | C | Score |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| C01 | Curse Appraiser | Test and appraise strange objects whose hidden properties can help or ruin the shop | 5 | 5 | 4 | 5 | 4 | 4 | 5 | 4.60 |
| C02 | Impossible Repair Bench | Diagnose devices whose components obey unusual interacting laws | 5 | 5 | 4 | 5 | 4 | 4 | 5 | 4.60 |
| C03 | Signal Operator | Tune, isolate, decode, and route dangerous signals from one tactile control desk | 5 | 5 | 4 | 5 | 5 | 4 | 4 | 4.65 |
| C04 | Living Blueprint | Assemble modular mechanisms and watch them physically run or fail | 5 | 5 | 4 | 4 | 4 | 3 | 5 | 4.35 |
| C05 | Ritual Assembly Line | Build compact production chains where symbolic ingredients interact by discoverable laws | 4 | 5 | 4 | 5 | 4 | 4 | 5 | 4.40 |
| C06 | Containment Clerk | Inspect arrivals and construct correct containment procedures from clues | 5 | 4 | 4 | 4 | 4 | 4 | 4 | 4.20 |
| C07 | One-Room Time Machine | Change objects in one room and rewrite later states of that same space | 5 | 5 | 3 | 5 | 4 | 2 | 5 | 4.20 |
| C08 | Dungeon Maintenance Shift | Repair and rebalance a dungeon between adventurer waves | 5 | 4 | 4 | 4 | 3 | 4 | 5 | 4.15 |
| C09 | Mechanical Garden | Grow machine-organisms by connecting energy, motion, and behavior modules | 4 | 5 | 3 | 5 | 4 | 3 | 5 | 4.10 |
| C10 | Anomaly Warehouse | Store objects that alter nearby weight, labels, geometry, temperature, or time | 5 | 5 | 4 | 4 | 4 | 3 | 5 | 4.35 |
| C11 | Memory Forensics | Reconstruct events by manipulating layered evidence and testing hypotheses | 5 | 4 | 3 | 4 | 4 | 4 | 3 | 3.95 |
| C12 | Micro-Factory Troubleshooter | Diagnose a failing tiny factory and restore output with minimal changes | 4 | 5 | 5 | 4 | 5 | 5 | 4 | 4.60 |
| C13 | Organism Cargo | Pack living cargo whose needs and interactions change during transit | 5 | 4 | 4 | 5 | 4 | 4 | 5 | 4.40 |
| C14 | Night Archive | Catalog records whose contents alter or reveal each other | 4 | 4 | 5 | 3 | 5 | 5 | 3 | 4.20 |
| C15 | Rulebreaker Janitor | Restore spaces where each contaminant obeys a different physical rule | 5 | 4 | 4 | 4 | 3 | 4 | 5 | 4.15 |
| C16 | Tiny Ecosystem Mechanic | Repair a miniature ecosystem through a few changes and cascading effects | 4 | 5 | 3 | 5 | 4 | 3 | 4 | 4.05 |
| C17 | Contract Alchemist | Meet strange customer requirements using discoverable transformation laws | 4 | 5 | 4 | 4 | 4 | 4 | 4 | 4.20 |
| C18 | Route of Echoes | Plan routes through a compact map where each trip changes future traversal rules | 4 | 5 | 4 | 5 | 5 | 4 | 3 | 4.40 |
| C19 | Protocol Garden | Maintain a tiny greenhouse where organisms change each other's environmental rules | 4 | 5 | 4 | 4 | 4 | 4 | 4 | 4.20 |
| C20 | Counterfeit Customs | Detect impossible forgeries using documents, physical tests, provenance, and contradictions | 5 | 4 | 5 | 3 | 5 | 5 | 3 | 4.40 |
| C21 | Machine Exorcist | Repair haunted machines by separating mechanical faults from supernatural rule violations | 5 | 5 | 4 | 5 | 4 | 4 | 5 | 4.60 |
| C22 | Pocket Transit Controller | Repair a small transport network by rerouting around cascading faults and constraints | 4 | 5 | 5 | 3 | 5 | 5 | 4 | 4.45 |
| C23 | Dream Cartographer | Infer and map a shifting place whose topology changes according to discovered rules | 4 | 5 | 4 | 5 | 5 | 4 | 4 | 4.45 |
| C24 | Inventory Reactor | Pack modules into a small reactor/case where adjacency controls heat, power, risk, and chain reactions | 5 | 5 | 5 | 4 | 5 | 5 | 5 | 4.85 |
| C25 | Disaster Dispatcher | Allocate limited responders from one city board while incomplete information and incidents cascade | 5 | 5 | 4 | 4 | 5 | 4 | 4 | 4.50 |
| C26 | Lost & Found Oracle | Infer owners and histories of strange lost objects from clues and object interactions | 5 | 4 | 4 | 4 | 4 | 5 | 3 | 4.25 |
| C27 | Creature Lab Triage | Diagnose strange organisms through limited tests; treatments interact with hidden traits | 5 | 5 | 4 | 4 | 4 | 4 | 5 | 4.45 |
| C28 | Impossible Switchboard | Connect callers, machines, and signals while hidden protocols mutate routing rules | 5 | 5 | 5 | 4 | 5 | 5 | 4 | 4.80 |
| C29 | Scrap Machine Auction | Buy broken contraptions, assess risk, salvage modules, and rebuild profitable machines | 5 | 5 | 4 | 4 | 3 | 4 | 5 | 4.35 |
| C30 | Ruleforge | Build compact logic devices from physical rule-tokens to satisfy changing contracts | 4 | 5 | 5 | 5 | 5 | 5 | 4 | 4.75 |

---

# 6. First elimination / merge pass

This pass is intentionally aggressive. Rejected concepts remain recorded so future chats do not repeatedly rediscover them.

## Merge rather than compete
- **C01 + C02 → C21 Machine Exorcist.** The fusion gives appraisal/hidden properties emotional texture and gives repair a more original rule space. Keep C01/C02 as ingredient references, not separate finalists.
- **C28 → C03 Signal Operator.** C28 scores extremely well but overlaps heavily. Preserve switchboard/caller/protocol ideas as possible mechanics inside C03 rather than pretending they are separate games.

## Eliminate from current tournament
- **C04 Living Blueprint:** strong system, but simulation/physics validation can expand dramatically; weaker emotional identity than finalists.
- **C05 Ritual Assembly Line:** attractive, but factory/automation comparisons create a very high depth expectation. Could become a subsystem of another game.
- **C06 Containment Clerk:** good theme but risks becoming repeated classification paperwork without enough physical/systemic agency.
- **C07 One-Room Time Machine:** exceptional hook, unacceptable dependency/state-space risk for this project's first implementation target.
- **C08 Dungeon Maintenance Shift:** fun pitch but asset/content burden and “reverse dungeon” familiarity weaken it.
- **C09 Mechanical Garden:** elegant but technically and visually demanding if organisms must feel alive.
- **C10 Anomaly Warehouse:** keep as reserve. Sorting trend makes its first impression dangerously close to an already crowded wave unless anomalies dominate every second of play.
- **C11 Memory Forensics:** investigation is appealing, but high authored evidence/story burden conflicts with systemic-content goal.
- **C14 Night Archive:** efficient but too text/data dependent and visually weak for current discovery requirements.
- **C15 Rulebreaker Janitor:** transformation is strong, but risks reading as a themed cleaning sim in a crowded task-sim market.
- **C16 Tiny Ecosystem Mechanic:** deep but difficult to teach, validate, and show clearly; simulation balance risk.
- **C17 Contract Alchemist:** good system but Potion Craft/alchemy space already has strong incumbents; needs a more original verb.
- **C18 Route of Echoes:** high systemic potential but abstract and less visceral than better candidates.
- **C19 Protocol Garden:** interesting but overlaps ecosystem complexity and can drift into content-heavy organism design.
- **C20 Counterfeit Customs:** very finishable, but derivative proximity to Papers, Please / inspection games is too high unless transformed further.
- **C22 Pocket Transit Controller:** strong score, but visually and mechanically close to established minimalist transit/network puzzlers.
- **C26 Lost & Found Oracle:** charming, but likely becomes authored-clue content rather than reusable systemic play.
- **C29 Scrap Machine Auction:** good fantasy, but asset demand and overlap with repair/shop simulators are higher than C21.
- **C30 Ruleforge:** keep as reserve. Highest pure abstraction score, but it currently lacks an emotionally memorable fantasy and may look like a logic exercise rather than a game people desire.

---

# 7. Phase 2 shortlist — 8 concepts

The shortlist is deliberately diverse enough to challenge the current “compact strange workplace” hypothesis rather than merely confirming it.

## S1 — C24 Inventory Reactor
**Pitch:** Pack a small machine/reactor/case with modules whose adjacency and orientation determine power, heat, interference, safety, and chain reactions.

Why it survives:
- strongest raw score;
- physical/spatial readability;
- data-driven modules;
- replayable combinations;
- one-board asset efficiency;
- immediate before/after and failure spectacle.

Primary threat:
- derivative perception from inventory-autobattler/backpack games. Must feel like engineering a dangerous device, not equipping a backpack.

## S2 — C03 Signal Operator (including best C28 elements)
**Pitch:** Work one tactile console to tune, decode, route, prioritize, spoof, and contain signals under evolving protocol rules.

Why it survives:
- extremely asset-efficient;
- strong audiovisual feedback potential;
- broad difficulty space from a small vocabulary;
- one-room identity;
- can generate mystery without huge environments.

Primary threat:
- can become spreadsheet work. Embodiment, sound, consequence, and readable stakes are mandatory.

## S3 — C21 Machine Exorcist
**Pitch:** Diagnose strange machines where ordinary component faults and supernatural rule violations can mimic each other; repair the machine without awakening worse behavior.

Why it survives:
- combines two strong earlier seeds;
- tactile repair fantasy validated by current market interest, but transformed away from literal electronics;
- hidden-rule diagnosis supports mastery;
- dramatic malfunction/recovery clips.

Primary threat:
- modular art/animation burden. Device grammar must be reusable, not a collection of bespoke props.

## S4 — C12 Micro-Factory Troubleshooter
**Pitch:** You do not build giant factories; you receive small broken systems and must identify the fault and restore required output with the fewest changes.

Why it survives:
- exceptional scope fitness;
- challenges can be generated/validated from data;
- “diagnose, don't build” is a useful inversion;
- easy to prototype as primitives.

Primary threat:
- low emotional fantasy. Needs presentation and consequences that make a tiny production diagram feel alive.

## S5 — C27 Creature Lab Triage
**Pitch:** Strange organisms arrive with visible symptoms and hidden traits. Choose limited tests, infer the cause, and apply treatments whose side effects depend on biology.

Why it survives:
- clear diagnosis loop;
- adorable/grotesque visual possibilities;
- incomplete information and treatment interactions create decisions;
- cases can be generated from trait/symptom/treatment matrices.

Primary threat:
- medical UI can become repetitive; creature behavior must provide expressive feedback without requiring huge animation sets.

## S6 — C13 Organism Cargo
**Pitch:** Pack living cargo into a constrained vehicle/container; organisms heat, eat, infect, soothe, attract, grow, panic, or alter neighbors during transit.

Why it survives:
- spatial puzzle is instantly readable;
- high story/clip potential;
- compact rules can recombine dramatically;
- transport phase can reveal whether planning was sound.

Primary threat:
- avoid physics-heavy implementation. Prefer discrete slots/grid plus clear interaction graph unless later prototype proves physics is worth it.

## S7 — C25 Disaster Dispatcher
**Pitch:** From one compact city board, allocate limited teams to incidents while information arrives late and unattended problems cascade into new ones.

Why it survives:
- consequential decisions from a compact interface;
- strong pressure without action-combat burden;
- procedural incidents can combine;
- natural “I saved this, but caused that” stories.

Primary threat:
- visual abstraction and thematic sensitivity. Needs strong feedback and fictionalized framing if real disasters make play feel exploitative or grim.

## S8 — C23 Dream Cartographer
**Pitch:** Explore/infer a shifting compact place whose topology follows hidden laws; draw a map that becomes a working model of the world rather than a collectible checklist.

Why it survives:
- challenges the workplace hypothesis with a discovery-first alternative;
- low environment count if rooms are modular;
- mystery and mastery arise from rule inference;
- player-created understanding is the progression.

Primary threat:
- procedural topology can feel arbitrary. Rules must be inferable, deterministic enough, and visually communicated.

### Reserves
- **R1 — C30 Ruleforge:** mechanically excellent, fantasy insufficient.
- **R2 — C10 Anomaly Warehouse:** strong transformation/adjacency, but trend-clone perception risk.

---

# 8. Concept-tournament tests to run next

Each of the eight finalists must receive the same destructive examination. No concept may be protected because it “sounds cool.”

For each finalist answer:
1. one-sentence store pitch;
2. 10-second trailer/GIF moment;
3. exact 30-second core interaction;
4. five-minute loop;
5. one-session loop;
6. hour-10 source of fresh decisions;
7. minimum viable content vocabulary;
8. what can be procedural/data-driven;
9. what must be handcrafted;
10. one-week graybox prototype definition;
11. likely tutorial problem;
12. dominant-strategy/exploit risk;
13. repetition failure mode;
14. technical risk;
15. art/audio burden;
16. Steam-comparison/derivative risk;
17. demo boundary;
18. why a player tells a friend about it;
19. what a streamer/short clip would show without explanation;
20. kill condition — the prototype observation that would make us abandon it.

Then perform pairwise comparison and allow merges only where the merged concept becomes *simpler and stronger*, not larger.

---

# 9. Directions with a high burden of proof

Do not reopen without new evidence:
- plain shelf sorting / tidying;
- generic supermarket/retail simulator;
- generic Vampire-Survivors-like;
- standard deckbuilder roguelike with only a thematic skin;
- open-world survival crafting;
- multiplayer extraction/co-op horror as default scope;
- pure narrative adventure requiring large authored writing/art volume;
- mobile F2P idle economy;
- giant colony/city builder;
- ordinary electronics repair shop;
- Papers, Please-style document inspection with only a new setting.

---

# 10. Updated working hypothesis

The broader scan supports a sharper hypothesis:

> **The best target for this project is likely a premium PC game built around one compact physical or diegetic workspace, one highly legible job, and a small vocabulary of reusable rules whose interactions turn routine actions into diagnosis, planning, risk, and surprising consequences.**

Why this is attractive:
- strong scope control;
- easy to explain visually;
- supports a distinctive theme;
- favors reusable assets;
- supports demos;
- can deliver depth through combination rather than authored volume;
- remains viable as single-player;
- can produce clips through failure/cascade/recovery;
- lends itself to data-driven implementation later.

The hypothesis is **not locked**. Phase 2 must try to disprove it using the eight finalists.

---

# 11. Phase 1 conclusion

Broad opportunity discovery is complete enough to stop generating more ideas by default. Continuing to add candidates now would create idea-hoarding rather than improve selection.

**Phase 1 result:** 30 distinct seeds examined → merge/elimination pass → 8 finalists + 2 reserves.

Next work belongs to **Phase 2 — Concept tournament**.
