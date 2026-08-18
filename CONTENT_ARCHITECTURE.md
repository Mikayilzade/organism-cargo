# ORGANISM CARGO — CONTENT ARCHITECTURE

Status: **FINAL CANONICAL CONTENT SPECIFICATION — PHASE 11 RECONCILED**
Last updated: 2026-08-15

This file defines launch-facing content for **Organism Cargo**. It may combine and tune already-frozen mechanics from `MECHANICS.md` and `DECISION_ARCHITECTURE.md`; it may not invent hidden one-off simulation systems. Phase-11 exact campaign, demo, non-dominance and redundancy requirements are folded in here.

---

# 1. Content contract

The content layer must simultaneously:
1. teach a small rule vocabulary gradually;
2. create premium-campaign depth without hundreds of bespoke assets;
3. support deterministic generated/recombined mastery content;
4. keep every species readable through body silhouette + at most 1–3 significant traits;
5. preserve the product identity that **the hold is not solved when the doors close**.

Reject content that requires one-off runtime code, hidden targeting, unexplained exceptions, unreadable trait stacks, static packing as the main solution, or a Bronze path with no certified valid solution.

---

# 2. Exact scope targets

## 2.1 MVP / vertical slice
- 4 body plans: B01 Dot, B02 Domino, B03 Corner, B04 Bar;
- T01–T10 foundation trait families;
- 9 representative playable species;
- 6 supports;
- 3 hold families/layout groups;
- 5 route-hazard families;
- 12 authored contracts;
- 6 tutorial/milestone cases within those 12;
- 6 generated challenge templates;
- 2 discovery contracts;
- no flavor variants required.

## 2.2 Public demo — FROZEN
- 4 body plans;
- **10 species total = 9 fully documented + 1 bounded-discovery species**;
- 4 supports: Cooler, Filter, Baffle, Feed Cartridge;
- 3 hold layouts from two families;
- 3 route-hazard families;
- 10 authored contracts;
- 3 generated/recombined templates;
- exactly 1 discovery contract;
- normal first-clear target about 60–90 minutes.

The old `8 documented + 2 discovery` wording is invalid everywhere.

Demo identity gates:
- by D03 at latest, a visible post-launch state/relationship change matters;
- at least 5 of D01–D10 contain a Bronze-relevant post-launch timing/state change;
- testers should predominantly describe the game as planning what organisms will do during transit, not static packing.

## 2.3 Launch target
- 4 body plans;
- 10 significant trait families;
- **22 species maximum before empirical redundancy cuts**;
- 6 supports;
- 5 hold families / 12 authored layouts;
- 7 route-hazard/profile families;
- 18 authored route profiles/timelines target;
- exactly 48 authored campaign contracts;
- 14 tutorial/milestone contracts within the 48 target;
- 8 discovery contracts within the 48 target;
- 24 generated/recombined challenge templates;
- 6 authored final mastery contracts included in the 48;
- up to 2 presentation-only flavor variants/species where useful;
- Codex target: launch species + T01–T10 + 7 hazard families + 6 supports.

Campaign first-clear target: about 8–12 hours. Long-tail depth comes from Gold/alternate solution families/generated challenges, never grind.

If empirical redundancy gates cut species, the launch count decreases. No replacement mechanic is added merely to preserve 22.

---

# 3. Numeric parameter bands

These bands prevent arbitrary per-species arithmetic. Balance testing may move a whole band coherently; content may not silently create unbounded exceptions.

## 3.1 Stress profiles
**Hardy**: agitated enter 8, exit 4; panic enter 14, exit 9.  
**Standard**: agitated enter 6, exit 3; panic enter 11, exit 7.  
**Sensitive**: agitated enter 5, exit 2; panic enter 9, exit 6.

## 3.2 Contamination profiles
**Resistant**: intake x0.5 fixed-point, contaminated enter 11, exit 5.  
**Standard**: intake x1.0, enter 8, exit 4.  
**Vulnerable**: intake x1.5, enter 7, exit 3.

## 3.3 Satiety
- low reserve start 3–4;
- normal reserve start 5–7;
- high reserve start 8–9;
- ordinary metabolism -1 every 2 ticks;
- high metabolism -1/tick;
- feed intake cap 1, 2 or 3 units/tick.

## 3.4 Source/sink magnitudes
Continuous environmental output: weak 2, standard 3, strong 4.  
T10 pulse: typically 4–6 per legal bounded trigger.  
Sink/mitigation capacity: weak 2, standard 3, strong 4.  
Direct social stress modification: weak 1, standard 2, strong 3.

No launch species exceeds strong continuous output. Larger magnitudes belong to route hazards or bounded pulses.

## 3.5 Range
- adjacency = Manhattan 1;
- near = Manhattan <=2;
- directed = cardinal ray 2 or 3;
- no always-on whole-hold organism aura.

## 3.6 Lifecycle timing
Qualifying duration: quick 1 tick, standard 2 consecutive ticks, slow 3.  
Normal delayed output: next tick or +2 ticks maximum. Longer hidden timers are prohibited.

---

# 4. Launch roster — O01–O22

The roster is a **maximum** pending prototype keep/cut evidence.

## O01 Ember Pod
B01 Dot; Standard stress/contamination; T01 Heat Emitter + T03 Alarm Emitter. Unstable heat/social source. Readability: sac brightens/trembles. Tier 1–6. Generated manifests below Tier 4: max 3.

## O02 Hushling
B01 Dot; Sensitive/Standard; T04 Soother. Capacity-1 calm/awake social stabilizer. Readability: antennae open only while soothing. Tier 1–6. Never validate content by assuming it soothes beyond capacity.

## O03 Silt Grazer
B01 -> B02; Standard stress, Resistant contamination; T06 Filter Feeder + T08 Growth. Consumes contamination and turns success into future topology. Readability: budding forward segment. Tier 2–6. Generated cases must prove a legal growth family unless blocked growth is explicit intended pressure.

## O04 Spore Bell
B01; Hardy/Standard; T05 Spore Shedder + bounded T10 contamination pulse. Persistent contamination cascade seed. Readability: bell fills with motes. Tier 2–6. First discovery never combines another undocumented contamination rule.

## O05 Warmback
B02; Hardy/Resistant; T01 + T09. Harmful thermal body + one-target narrow protection. Readability: hot dorsal plates + shield link. Tier 2–6. One protected target maximum.

## O06 Cradle Moss
B01; Sensitive/Resistant; T04 + T07 producer-form feeding grammar. Beneficial cluster anchor whose documented state gates can remove soothing/feeding. Readability: fronds open/fold. Tier 2–6. Do not count its two benefits as independent when the same state disables both.

## O07 Pulse Mite
B01; Sensitive/Standard; T03 + bounded T10 heat pulse on PANICKED entry. Converts social failure into heat failure. Readability: one panic flash. Tier 2–6. Recursive pulse chains invalid.

## O08 Glass Larva
B01 -> B03 Corner; Sensitive/Vulnerable; T07 + T08. Future-space lifecycle puzzle. Readability: transparent body shows future lobes. Tier 2–6. Mature footprint must be validated.

## O09 Ash Sponge
B02; Hardy/Resistant; T02 + T06 + bounded delayed T10 social downside. Two-channel helper that accumulates a later social cost. Readability: swells red then emits agitation wave. Tier 4–6 only. Never treat as universal helper.

## O10 Frost Finch
B01; Sensitive/Standard; T02. Simple local heat sink and living-vs-powered baseline. Readability: visible frost mantle. Tier 1–6.

## O11 Rattle Reed
B04; Standard/Resistant; directed T03. Orientation defines a directed social hazard. Readability: reed chambers point along emission ray. Tier 3–6. Directed overlay taught before use.

## O12 Velvet Nurse
B02; Standard/Standard; T04 + T09. One-target soothe+buffer specialist with positional/state cost. Readability: directed blue neighbor glow. Tier 3–6. Max 2 in generated manifests.

## O13 Cinder Snail
B02 -> B04; Hardy/Resistant; T01 + T08. Heat exposure causes linear growth/future obstruction. Readability: shell extends in facing direction. Tier 3–6. First use cannot also hide route timing.

## O14 Mire Sipper
B01; Standard/Resistant; T06. Simple contamination sink without lifecycle. Readability: siphon animation only while consuming. Tier 1–6.

## O15 Lantern Tick
B01; Sensitive/Standard; bounded T10 temporary-food pulse on CALM recovery after AGITATED. Recovery-timing resource source. Readability: abdomen lights at recovery boundary. Tier 4–6. Must declare cooldown/episode/trigger cap; self-sustaining loops rejected.

## O16 Moth Cushion
B03; Sensitive/Vulnerable; T04 + explicit sleep-gated soothing. Large-footprint soother with wake/sleep vulnerability. Readability: wing-corner folds shut asleep. Tier 3–6. No contract can require soothing and mandatory sleep simultaneously without solvable timing.

## O17 Coal Urchin
B01; Hardy/Resistant; T02 + T03. Thermal helper that becomes social liability. Readability: spines cool/flare. Tier 4–6. Generator rejects cases where both sides are irrelevant.

## O18 Spindle Bloom
B01 -> B04; Standard/Standard; T05 + T08. Contamination source whose emission footprint expands. Readability: bud unfurls into spore line. Tier 4–6. Advanced only; Bronze causal explanation must remain bounded.

## O19 Amber Leech
B01; Standard/Resistant; T07 + T09. Consumes food while protecting the same compatible partner. Readability: feeding/protection tether. Tier 3–6. Conservation required; no infinite feed/protect loop.

## O20 Whistle Crab
B03; Hardy/Standard; T03 + T09. Protector that becomes an alarm hazard under stress. Readability: shelter claw + whistle rings. Tier 4–6. Cannot protect against stress, preserving downside.

## O21 Pale Drifter
B02; Standard/Vulnerable; bounded T10 cleansing pulse on waking + explicit sleep lifecycle. Timed contamination relief, not continuous filter. Readability: one clearing ring on wake. Tier 5–6/discovery first. One pulse per sleep episode.

## O22 Splitcap
B02 -> authored 4-cell extension using existing body-plan grammar; Sensitive/Standard; T06 + T08 + T03. Successful filtering causes growth then possible social instability. Readability: cap splits into four lobes. Tier 6 authored/validated generation only. Future footprint and post-growth adjacency must be solver-validated.

## 4.1 Mandatory redundancy gates
Prototype comparison clusters:
- O06 / O12 / O16;
- O05 / O19 / O20.

For each representative validation set, record preferred placement, support choice and revision choice. If two members of one cluster create the same preferred decision in **>=70%** of representative cases, cut/merge the less readable species.

This is a keep/cut gate, not an invitation to invent replacement mechanics.

---

# 5. Support roster and non-dominance gates

Supports are exactly S01–S06:
- S01 Cooler;
- S02 Filter;
- S03 Baffle;
- S04 Nest Pad;
- S05 Feed Cartridge;
- S06 Monitor Beacon.

The goal is not equal frequency; it is no universal best support.

| Support | Preferred authored proof | Legal-but-inferior proof | Alternate living/structural family | Non-dominance reason |
|---|---|---|---|---|
| S01 Cooler | C07/C22/C44 | C29 Brownout/fixture pressure | Frost Finch / Coal Urchin | power+fixture cost, local capacity, Brownout |
| S02 Filter | C12 | C16/C39 beneficial contamination timing | Mire Sipper / Silt Grazer / Ash Sponge | can remove useful contamination; power+fixture |
| S03 Baffle | C14/C27 | C19/C39 where it breaks beneficial relation | topology + Hushling/Velvet Nurse | occupies spatial opportunity, blocks links/rays |
| S04 Nest Pad | C20/C23 | C21 vibration/arrival-awake | natural sleep timing | capacity 1, wake hazards, explicit sleep gates |
| S05 Feed Cartridge | C19/C22 | C16/C39 early feeding/growth harmful | Cradle Moss / Lantern Tick | finite reserve, occupies space, can accelerate dangerous growth |
| S06 Monitor Beacon | C33/C36/C40 | documented non-discovery cases | conservative bounded inference | no mitigation; never required for Bronze |

Global gates:
- across C17–C48, Cooler+Filter may be certified primary Bronze pair in at most **8** contracts;
- at least one contract in each Chapters 3–6 makes Cooler or Filter actively inferior through power, fixture, timing or beneficial-channel logic;
- Baffle+one soother cannot erase all social decisions without another spatial/lifecycle cost;
- living substitutes trade cargo-space/state vulnerability/secondary effects for reduced fixture/power cost;
- powered supports trade fixture/power for predictable operation while powered;
- neither family may strictly dominate the launch set.

---

# 6. Hold families and layouts

Launch families:

## HF1 Open Crate
5x5 to 6x5, broad zones, 1–2 utility fixtures. H01 Training Crate, H02 Long Crate, H03 Twin-Fixture Crate.

## HF2 Split Hold
5x6 to 6x6, partial wall/spine, baffle-compatible boundary, two utility fixtures. H04 Split Hold, H05 Offset Split, H06 Narrow Gate.

## HF3 Bent Hold
Irregular L/bent area, 2–3 fixtures, uneven zones. H07 Bent Hold, H08 Hook Hold.

## HF4 Service Bay
Moderate cargo area, dense fixture topology, tight route power. H09 Service Bay, H10 Cross-Fixture Bay.

## HF5 Constricted Vault
7x6 to 9x7 bounding area with 20–35% blocked cells, pockets and necks, high growth/directional pressure. H11 Three-Pocket Vault, H12 S-Corridor Vault.

Launch generation uses authored layouts only. It may choose/mirror/rotate only where symmetry data permits; no arbitrary procedural topology at launch.

---

# 7. Route hazard/profile families

- RH1 Thermal Surge — bounded heat to named zone/ticks.
- RH2 Contamination Leak — contamination source in named cells/zones/ticks.
- RH3 Vibration Burst — stress-field event and explicit wake requests.
- RH4 Brownout — Phase-A powered-support capacity change.
- RH5 Vent Cycle — existing decay/vent modifier; may also use declared heat-removal input.
- RH6 Thermal Gradient — different heat input in declared zones using existing heat grammar.
- RH7 Maintenance Oscillation — deterministic sequence of existing inputs such as Brownout then Vibration; not a new effect type.

Sequencing limits:
- Tier 0–1: 0–1 family;
- Tier 2: max 1 family, optionally two non-overlapping events;
- Tier 3: max 2;
- Tier 4–5: max 3, no more than 2 simultaneously;
- Tier 6: max 4, normally <=2 simultaneous unless authored final readability evidence says otherwise;
- normal route <=24 ticks;
- first exposure uses exact timing/intensity;
- bounded uncertainty never hides two independent dimensions at once.

---

# 8. Exact authored campaign graph — C01–C48

Bronze completion is the **only** campaign progression currency. A node unlocks when all named prerequisites are Bronze-complete. Silver/Gold, Challenge results, achievements, retry count, XP, money, online state and undocumented knowledge flags are never campaign prerequisites.

| Contract | Prerequisites | Primary purpose |
|---|---|---|
| C01 | none | placement / launch |
| C02 | C01 | soothing |
| C03 | C01 | heat / alarm |
| C04 | C02 | heat sink |
| C05 | C03 | first route heat consequence |
| C06 | C04 | Domino / orientation |
| C07 | C05,C06 | optional welfare + Cooler |
| C08 | C07 | Ch1 capstone: dynamic trait activation |
| C09 | C08 | contamination sink intro |
| C10 | C08 | contamination source intro |
| C11 | C09,C10 | contamination route leak |
| C12 | C11 | Filter |
| C13 | C11 | Silt Grazer / useful contamination |
| C14 | C12,C13 | Baffle / cluster-separate tradeoff |
| C15 | C14 | authored recombination case |
| C16 | C14,C15 | Ch2 capstone: contamination feeding + future footprint |
| C17 | C16 | Cradle Moss / awake-asleep role |
| C18 | C16 | Glass Larva / growth footprint |
| C19 | C17,C18 | Feed Cartridge |
| C20 | C17 | Nest Pad / sleep |
| C21 | C20 | vibration wake timing |
| C22 | C18,C19 | Cinder Snail / heat-driven growth |
| C23 | C20,C21 | Moth Cushion + Warmback timing/protection |
| C24 | C22,C23 | Ch3 capstone: wake + growth + support tradeoff |
| C25 | C24 | Pulse Mite social-to-heat cascade |
| C26 | C24 | Velvet Nurse narrow protection |
| C27 | C25 | Rattle Reed / directed overlay |
| C28 | C26 | Service Bay / fixture competition |
| C29 | C27,C28 | Brownout + support priority |
| C30 | C29 | Coal Urchin helper-liability composite |
| C31 | C29 | Whistle Crab protection downside |
| C32 | C30,C31 | Ch4 capstone: interruptible four-step cascade |
| C33 | C32 | Monitor Beacon / evidence tool |
| C34 | C33 | Lantern Tick bounded discovery |
| C35 | C34 | Lantern Tick documented use |
| C36 | C33 | Pale Drifter bounded wake discovery |
| C37 | C36 | Pale Drifter documented use |
| C38 | C35,C37 | Spindle Bloom advanced lifecycle |
| C39 | C38 | Amber Leech dependency |
| C40 | C39 | Ch5 capstone: unknown route detail / Monitor tradeoff |
| C41 | C40 | Ash Sponge advanced composite |
| C42 | C40 | Splitcap mastery species |
| C43 | C41,C42 | Constricted Vault mastery topology |
| C44 | C43 | Thermal Gradient recombination |
| C45 | C43 | Maintenance Oscillation recombination |
| C46 | C44,C45 | anti-template helper-liability test |
| C47 | C46 | penultimate full-system mastery |
| C48 | C47 | final Living Manifest |

Capstones: C08, C16, C24, C32, C40, C48.

Build-time graph validator must assert:
- exactly 48 nodes;
- every prerequisite exists;
- graph acyclic;
- C01 has none;
- every C09–C48 reachable from C01;
- no non-Bronze progression dependency leaks in;
- each capstone is gated behind both required teaching lanes;
- imported demo progress maps only to C01–C08; D09–D10 never auto-clear C09+.

---

# 9. Campaign content structure and dynamic-transit quotas

## Chapter 1 — Read the Hold, C01–C08
Placement, Hushling, Ember Pod, Frost Finch, first Thermal Surge, Domino orientation, first optional welfare/Gold, dynamic activation capstone.

## Chapter 2 — Useful Neighbors, C09–C16
Mire Sipper, Spore Bell, contamination leak, Filter, Silt Grazer, Baffle, growth, recombination, contamination-feeding/future-footprint capstone.

## Chapter 3 — Plan for Later, C17–C24
Cradle Moss, Glass Larva, Feed Cartridge, Nest Pad, Vibration, Cinder Snail, Moth Cushion, Warmback, wake+growth+support capstone.

## Chapter 4 — Protect the Weak Link, C25–C32
Pulse Mite, Velvet Nurse, Rattle Reed, Service Bay, Brownout/power priority, Coal Urchin, Whistle Crab, interruptible cascade capstone.

## Chapter 5 — Discover, Don’t Guess, C33–C40
Monitor Beacon, Lantern Tick discovery/documentation, Pale Drifter discovery/documentation, Spindle Bloom, Amber Leech, bounded-route-information capstone.

## Chapter 6 — No Familiar Template, C41–C48
Ash Sponge, Splitcap, Constricted Vault, Thermal Gradient, Maintenance Oscillation, anti-template composites, full-system mastery. C48 contains no new rule.

Dynamic content gates:
- C01–C04 may be near-static tutorials;
- **every C05–C48** must contain a decision-relevant post-launch state/footprint/channel/support-power change;
- **at least 20 of C09–C48** must require Bronze planning around two or more temporally separated changes;
- at least two contracts per chapter in Chapters 2–6 make pure maximum-spacing inferior/impossible for rule-driven reasons;
- Chapter 3 at least one, Chapter 4 at least one, Chapter 6 at least two make the obvious permanent growth-corner/edge reserve strategically bad;
- Tier 4+ authored content includes Hushling/Velvet Nurse/Moth Cushion cases where the familiar helper is unavailable, vulnerable at the decisive window or inferior;
- after Chapter 2, no more than three consecutive contracts share the same symmetry-normalized role-to-zone Bronze template.

C48 requirements:
- irregular authored vault;
- 7–9 organisms from >=5 learned role families;
- >=1 lifecycle species;
- >=1 beneficial-dangerous composite;
- three known hazard families in readable sequence;
- power/fixture pressure;
- >=2 certified Bronze strategy families;
- Gold rewards efficient support + welfare stability, never intentional harm;
- no new species behavior/hidden fact/foundation rule.

---

# 10. Authored vs generated content

Always authored:
- C01–C48;
- first introductions of species/supports/holds/hazards/trait families;
- all discovery contracts;
- final mastery contracts;
- tutorial text/cues;
- launch hold layouts;
- milestone flavor framing.

Generator may vary only validated data:
- manifest from unlocked/documented pools;
- starting meters within bands;
- orientations;
- authored hold/symmetry variant;
- support allowance;
- route profile/timing from validated templates;
- mandatory/Silver/Gold predicate templates;
- deterministic seed.

Generator never invents new trait definitions, species, executable callbacks, arbitrary topology or hidden mechanics.

---

# 11. Generated challenge pipeline

## Stage 1 — seeded assembly
Input: generator version, deterministic seed, tier, documented content set, requested family. Select hold, route, manifest, starting state, support allowance and predicates.

## Stage 2 — structural validation
Reject impossible t0 fit, missing required fixture, impossible mandatory predicate, invalid trait composition, or required growth with no legal family when blocked growth is not explicit pressure.

## Stage 3 — certified Bronze construction
Use known-valid layout families and/or bounded search through the authoritative simulator. **Every surfaced challenge has at least one proven Bronze solution.** Tier 4+ should target two materially distinct Bronze families where tractable (different support loadout, zone allocation or key adjacency/growth reservation, not symmetric swaps).

## Stage 4 — medal validation
Prove every offered medal. Reject Gold/Silver if no certified solution exists within search budget. Never require worse mandatory welfare solely to satisfy mastery.

## Stage 5 — causal opacity
For canonical Bronze and plausible near-miss, generate causal graph. Reject when shortest useful failure explanation exceeds 6 major links below Tier 6; Tier 6 maximum 8 only with grouped routine propagation. Reject cases requiring >2 unseen state changes to be remembered simultaneously.

## Stage 6 — dynamic-transit significance
Reject when:
- t0 legality/static adjacency explains the intended solution;
- no meaningful organism state, footprint, environment, route power or timing relation changes after launch;
- safe timing perturbation makes no strategic difference;
- pure maximum-spacing is best without a dynamic relationship, except explicit `separation under changing topology` family.

## Stage 7 — anti-template diversity
Fingerprint:
- hold family;
- manifest role histogram;
- pressure channels;
- lifecycle yes/no;
- cluster/separate relation count;
- powered-support optimal set;
- route sequence;
- canonical zone allocation;
- source-edge fraction / growth-reserve pattern diagnostics.

Reject/down-rank similarity >0.80 against any of last five surfaced challenges. Reject the same powered-support pair as optimal in >3 consecutive surfaced challenges.

## Stage 8 — difficulty calibration
Tier uses organism count, pressure families, hazards, support complexity and information burden. Solver effort is secondary to human explanation structure.

## Stage 9 — freeze record
Persist generator/content/rules versions, seed, selected IDs/starting parameters, medal predicate version, validation hash and at least one hidden QA solution fingerprint.

---

# 12. Demo specification — canonical 9+1 split

Included species:
- documented: O01 Ember Pod, O02 Hushling, O03 Silt Grazer, O04 Spore Bell, O06 Cradle Moss, O07 Pulse Mite, O08 Glass Larva, O10 Frost Finch, O14 Mire Sipper;
- bounded discovery: **O13 Cinder Snail only**.

Included supports: Cooler, Filter, Baffle, Feed Cartridge.  
Included hazards: Thermal Surge, Contamination Leak, Vibration Burst.  
Included holds: Training Crate, Long Crate, Split Hold.

Authored arc:
- D01 placement/orientation;
- D02 Hushling + Ember Pod;
- D03 Thermal Surge and first clearly relevant transit change;
- D04 Frost Finch capacity limit;
- D05 contamination leak + Mire Sipper;
- D06 Spore Bell persistence;
- D07 Silt Grazer future growth;
- D08 support choice: Filter vs no-powered Gold family;
- D09 bounded Cinder Snail discovery;
- D10 growth timing + thermal route event + competing proximity.

Outside demo: Nest Pad, Monitor Beacon, Brownout/power priority, Service Bay/Constricted Vault, Ash Sponge/other mastery composites, Pale Drifter, advanced generator families, Chapters 5–6, final mastery.

Demo transfer:
- settings and codex knowledge transfer;
- D01–D08 may map cleanly to C01–C08;
- D09–D10 never auto-complete C09+;
- imported knowledge never unlocks Challenge mode early;
- no mechanical power bonus.

---

# 13. Narrative/flavor scope

Player role: specialist cargo ecologist/containment planner for an inter-habitat transport service.

Each authored contract uses at most a shipment title, one-sentence context, manifest notes and optional arrival note. No branching dialogue required.

Every species has common name, silhouette/icon, 1–2 sentence ecological note, exact documented mechanical summary and one memorable handling sentence.

Tone: curious, competent, lightly strange; not grim body horror. Failure emphasizes unsafe/stressed delivery, not gore.

Environmental flavor (labels, habitat stamps, prior-handler notes, wear) is never mechanically authoritative unless mirrored in explicit rules UI.

---

# 14. Canonical content schemas

## SpeciesDefinition
`species_id`, localization keys, body plan, starting/stage definitions, legal orientations, stress/contamination/satiety profiles, trait instances, compatibility tags, readability tags, tier min/max, generator exclusions, optional discovery definition, presentation profile, content version.

## TraitInstance
Trait family, parameter band, state/sleep gate, target selector, range model, effect parameters, optional delay/capacity, compatibility tags, UI summary, causal key, and for T10 exactly one finite trigger policy. No executable callback field.

## HoldDefinition
ID/family, dimensions, usable/blocked cells, utility/bed fixtures, zones, baffle boundaries, power capacity, legal symmetry transforms, tier range, version.

## RouteDefinition
ID, tick count, hazard events, known-information policy, bounded uncertainty if any, base power, zone modifiers, tier range, version.

## ContractDefinition
ID, chapter/tier, hold/route, manifest, starting overrides, support allowance, mandatory/Silver/Gold predicates, knowledge overrides, tutorial steps, unlock rewards, flavor ID, prerequisite IDs, hidden QA solution fingerprints, content version.

## DocumentationState
Documented species/traits, observed clues, support/hazard codex unlocks, Bronze/medal state, generated history seeds/fingerprints. Campaign progression is derived from the exact Bronze prerequisite graph, not medal totals.

---

# 15. Content validation acceptance index

A launch-content build must pass all of the following:

1. exact 48-node Bronze prerequisite graph validation;
2. exact demo 9 documented + 1 discovery split;
3. C05–C48 dynamic-transit significance;
4. >=20 C09–C48 cases with >=2 temporally separated Bronze-relevant changes;
5. chapter anti-isolation and anti-growth-corner quotas;
6. role-to-zone repetition limit;
7. S01–S06 preferred/inferior/alternate proof matrix;
8. Cooler+Filter cap of 8 primary Bronze cases across C17–C48;
9. mandatory O06/O12/O16 and O05/O19/O20 redundancy trials with >=70% cut/merge rule;
10. all T10 definitions have finite trigger guards and no positive self-loop;
11. generated challenges certify Bronze and every offered medal;
12. generated content passes causal-opacity and recent-fingerprint gates;
13. no generated challenge is static-packing-only;
14. no global empty-space medal/reward axis is introduced;
15. every discovery Bronze is conservatively solvable without Monitor Beacon;
16. final contract contains no new rule;
17. all content uses only frozen body/trait/state/route/support grammar.

**Content specification result: FROZEN pending only final cross-file contradiction clearance. No future Phase-5 design work remains.**
