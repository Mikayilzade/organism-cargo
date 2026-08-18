# ORGANISM CARGO — PHASE 11 SPECIFICATION FREEZE

Status: **IN PROGRESS — CONSOLIDATION PASS 1 COMPLETE**
Last updated: 2026-08-15
Production code started: **NO**

This file is the Phase-11 reconciliation layer. It does not add a new game system. It turns already-canonical Phase-9/10 repairs into explicit implementation data and acceptance obligations so that a builder does not need to infer missing progression, balance-coverage, content-distinction, or validation rules.

Authority order during Phase 11:
1. `GAME_BIBLE.md` product thesis and anti-pillars;
2. this file for the exact Phase-11 freeze items below;
3. `MECHANICS.md`, `DECISION_ARCHITECTURE.md`, `CONTENT_ARCHITECTURE.md`, `UX_ARCHITECTURE.md`, `ECONOMY_COMMERCIAL.md`, `TECHNICAL_SPEC.md` for their domains;
4. `WHOLE_GAME_SIMULATION.md` and `ADVERSARIAL_REVIEW.md` only for repairs not yet folded into their source documents.

If an older document contradicts a frozen item here, this file wins until the source file is rewritten during the final contradiction sweep.

---

# 1. Frozen campaign graph — C01–C48

## 1.1 Graph rules
- Bronze completion is the only campaign progression currency.
- Silver/Gold, challenge completions, achievements, retry count, XP, money, and online activity are never prerequisites.
- A node unlocks when **all** named prerequisites are Bronze-complete.
- Chapter capstones are C08, C16, C24, C32, C40, C48.
- Clearing each capstone unlocks the next chapter entry pair.
- Branches provide choice without allowing the player to skip a chapter's required vocabulary.
- Every capstone prerequisite set covers the chapter's required teaching lanes.

## 1.2 Exact edge table

| Contract | Prerequisites | Purpose |
|---|---|---|
| C01 | none | placement / launch |
| C02 | C01 | soothing |
| C03 | C01 | heat/alarm |
| C04 | C02 | heat sink |
| C05 | C03 | first route heat consequence |
| C06 | C04 | Domino/orientation |
| C07 | C05,C06 | optional welfare + Cooler |
| C08 | C07 | Chapter-1 capstone: dynamic post-launch trait activation |
| C09 | C08 | contamination sink intro |
| C10 | C08 | contamination source intro |
| C11 | C09,C10 | contamination route leak |
| C12 | C11 | Filter support |
| C13 | C11 | Silt Grazer / beneficial contamination use |
| C14 | C12,C13 | Baffle / cluster-separate tradeoff |
| C15 | C14 | recombination / generated-style authored case |
| C16 | C14,C15 | Chapter-2 capstone: contamination feeding + future footprint |
| C17 | C16 | Cradle Moss / awake-asleep role |
| C18 | C16 | Glass Larva / growth footprint |
| C19 | C17,C18 | Feed Cartridge |
| C20 | C17 | Nest Pad / sleep |
| C21 | C20 | Vibration wake timing |
| C22 | C18,C19 | Cinder Snail / heat-driven growth |
| C23 | C20,C21 | Moth Cushion + Warmback timing/protection |
| C24 | C22,C23 | Chapter-3 capstone: wake window + growth + support tradeoff |
| C25 | C24 | Pulse Mite / social-to-heat cascade |
| C26 | C24 | Velvet Nurse / narrow protection |
| C27 | C25 | Rattle Reed / directed overlay |
| C28 | C26 | Service Bay / fixture competition |
| C29 | C27,C28 | Brownout + support priority |
| C30 | C29 | Coal Urchin / helper-liability composite |
| C31 | C29 | Whistle Crab / protection-with-downside |
| C32 | C30,C31 | Chapter-4 capstone: interruptible 4-step cascade |
| C33 | C32 | Monitor Beacon / evidence tool |
| C34 | C33 | Lantern Tick bounded discovery |
| C35 | C34 | Lantern Tick documented normal use |
| C36 | C33 | Pale Drifter bounded wake discovery |
| C37 | C36 | Pale Drifter documented normal use |
| C38 | C35,C37 | Spindle Bloom advanced lifecycle |
| C39 | C38 | Amber Leech dependency relation |
| C40 | C39 | Chapter-5 capstone: unknown route detail; Monitor competes with mitigation |
| C41 | C40 | Ash Sponge advanced composite |
| C42 | C40 | Splitcap mastery species |
| C43 | C41,C42 | Constricted Vault mastery topology |
| C44 | C43 | Thermal Gradient recombination |
| C45 | C43 | Maintenance Oscillation recombination |
| C46 | C44,C45 | anti-template helper-liability test |
| C47 | C46 | penultimate full-system mastery |
| C48 | C47 | final `Living Manifest` |

## 1.3 Graph acceptance tests
A build-time graph validator must assert:
- exactly 48 campaign nodes exist;
- every prerequisite ID exists;
- graph is acyclic;
- C01 has no prerequisite;
- only C48 has no campaign successor requirement;
- every C09–C48 is reachable from C01;
- no node requires a medal, challenge, achievement, online flag, currency, XP, retry count, or undocumented knowledge state;
- every chapter capstone is reachable only after its two teaching lanes have converged;
- imported demo progress can map only to C01–C08 clearance; D09–D10 never auto-clear C09+.

---

# 2. Demo freeze

Canonical public demo content is:
- **10 species total = 9 fully documented + 1 bounded-discovery species**;
- 4 supports: Cooler, Filter, Baffle, Feed Cartridge;
- 3 hold layouts from two families;
- 3 hazard families;
- 10 authored contracts;
- 3 generated/recombined challenge templates;
- exactly 1 discovery contract;
- roughly 60–90 minutes normal first clear.

The older `8 documented + 2 discovery` wording is superseded.

Demo transfer to full game:
- settings transfer;
- codex/knowledge transfer;
- demo medals/progress transfer where IDs map cleanly;
- D01–D08 may map to C01–C08 completion;
- D09–D10 do not auto-complete later campaign nodes;
- imported knowledge never unlocks Challenge mode before the normal Tier-2 capstone gate;
- there is no mechanical power bonus for owning/completing the demo.

Demo identity acceptance:
- by contract 3 at the latest, a visible post-launch state change must alter a relationship or risk;
- at least 5 of 10 demo authored contracts must contain a Bronze-relevant post-launch timing/state change;
- tester recall target: predominant description is “planning for what the creatures will do during transit,” not “packing creatures into a box.”

---

# 3. Dynamic-transit content gate

The following are now launch content-validation requirements, not suggestions.

## Authored campaign
- C01–C04 may be nearly static onboarding exceptions.
- Every C05–C48 contains at least one decision-relevant post-launch state/footprint/channel/support-power change.
- At least **20 of C09–C48** require the Bronze solution to anticipate **two or more temporally separated state changes**.
- At least two contracts per chapter in Chapters 2–6 must make pure maximum-spacing inferior or impossible for an existing-rule reason.
- Chapter 3 has at least one contract, Chapter 4 at least one, and Chapter 6 at least two where the obvious permanent growth-corner/edge reserve is strategically bad.
- Tier 4+ authored content includes explicit cases where a Hushling/Velvet Nurse/Moth Cushion is unavailable, vulnerable at the decisive window, or inferior to topology/support mitigation.
- No chapter after Chapter 2 has more than three consecutive contracts with the same normalized role-to-zone Bronze template.

## Generated challenges
Reject a generated challenge if:
- static t0 legality/adjacency explains the intended solution;
- no meaningful organism state, footprint, environmental relation, route power state, or timing relation changes after launch;
- solver timeout is the only evidence of solvability;
- Bronze has no explicit certified solution or known-valid source construction;
- shortest useful failure explanation exceeds normal opacity limits;
- it repeats the recent challenge fingerprint above the canonical similarity threshold;
- the same powered-support pair would be optimal in more than three consecutive surfaced challenges;
- its best Bronze family is pure maximum-spacing without a dynamic relationship, except the explicit `separation under changing topology` family.

---

# 4. Support non-dominance matrix

The balance objective is not equal usage frequency; it is **no universal best support**. Every support must have a clear job, a clear cost, and authored evidence that it can be best, legal-but-inferior, or unnecessary.

| Support | Preferred authored proof | Legal but inferior proof | Living-substitute / alternate Bronze family | Canonical non-dominance reason |
|---|---|---|---|---|
| S01 Cooler | C07/C22/C44 thermal timing case | C29 Brownout or fixture-pressure case | Frost Finch / Coal Urchin | power + fixture cost; local capacity; Brownout exposure |
| S02 Filter | C12 contamination peak case | C16/C39 where contamination is useful feed timing | Mire Sipper / Silt Grazer / Ash Sponge | power + fixture cost; may remove useful contamination |
| S03 Baffle | C14/C27 directed/social propagation case | C19/C39 where it breaks feed/symbiotic relation | topology spacing + Hushling/Velvet Nurse | occupies spatial opportunity; blocks beneficial links/rays |
| S04 Nest Pad | C20/C23 sleep-timing case | C21 vibration or arrival-awake case | naturally timed sleep species behavior | capacity 1; wake hazards; sleep only disables explicitly gated traits |
| S05 Feed Cartridge | C19/C22 timed growth/feed case | C16/C39 where early feeding/growth or competition is harmful | Cradle Moss / Lantern Tick | finite reserve; occupies fixture/cell; can accelerate dangerous growth |
| S06 Monitor Beacon | C33/C36/C40 discovery-evidence case | any fully documented non-discovery contract | conservative bounded inference without Monitor | no direct mitigation; never required for discovery Bronze |

Additional global support gates:
- Across C17–C48, Cooler+Filter is a certified primary Bronze pair in at most **8 contracts** (25%).
- At least one contract in each of Chapters 3–6 makes Cooler or Filter actively inferior due to timing, power, fixture location, or beneficial channel use.
- Baffle + one soother may not erase all stress decisions without creating another spatial/lifecycle tradeoff.
- Sleep suppresses only explicitly state-gated traits. No animation-implied shutdown.
- Powered support = predictable, fixture/power constrained, state-independent while powered unless data says otherwise.
- Living substitute = cargo-space cost, state vulnerability and/or secondary behavior. Neither family may strictly dominate the launch set.

---

# 5. 22-species unique-decision/readability matrix

A launch species remains only if its roster role creates a decision not adequately represented by another species at similar complexity. Prototype evidence may cut/merge redundant species; it may not expand the trait grammar to rescue redundancy.

| ID | Unique decision hook | Primary readability hook | Closest overlap | Prototype keep/cut gate |
|---|---|---|---|---|
| O01 Ember Pod | useful position vs heat+alarm escalation | sac brightens/trembles | O17 | keep if dual source causes distinct cascade planning |
| O02 Hushling | capacity-1 calm-only social stabilization | antennae open while soothing | O12/O16 | keep as simplest soother baseline |
| O03 Silt Grazer | contamination consumption causes future growth | visible budding forward segment | O14/O08 | keep if sink→topology timing is frequently decision-relevant |
| O04 Spore Bell | contamination source gated by contamination + pulse | bell fills with spores | O18 | keep as compact persistent cascade seed |
| O05 Warmback | harmful heat body + one-target protection | hot dorsal plates + shield link | O19/O20 | cut/merge if protector decision is not distinct from O19/O20 cluster |
| O06 Cradle Moss | food+soothing cluster anchor loses both through state | open/folded fronds | O12/O16 | cut/merge if dual-benefit state vulnerability adds no new layout choice |
| O07 Pulse Mite | social failure converts once into heat failure | one panic flash | O01/O17 | keep if cross-channel pulse creates memorable causal pivots |
| O08 Glass Larva | feed planning tied to Corner future footprint | transparent future lobes | O03/O13 | keep if footprint reservation differs materially from linear growers |
| O09 Ash Sponge | two-channel helper accumulates delayed social cost | swells red then agitation wave | O17/O14 | keep only as late composite; cut if it becomes universal helper |
| O10 Frost Finch | pure simple local heat sink | visible frost mantle | S01/O17 | keep as living-vs-powered baseline |
| O11 Rattle Reed | orientation defines directed social hazard | pointing reed chambers | O01/O20 | keep if directional overlay earns its cognitive load |
| O12 Velvet Nurse | one-target soothe+buffer specialist | blue directed neighbor glow | O02/O06/O16 | cut/merge if target-specialist choice is not measurably distinct |
| O13 Cinder Snail | heat exposure itself causes linear growth obstacle | extending shell | O08/O18 | keep if hazard→topology relation differs from feeding growth |
| O14 Mire Sipper | pure contamination sink without lifecycle | siphon only while consuming | O03/S02 | keep as simple contamination baseline |
| O15 Lantern Tick | recovery boundary creates bounded timed food pulse | abdomen lights on recovery | O06/O19 | keep if recovery timing creates non-obvious but explainable planning |
| O16 Moth Cushion | large Corner soother with sleep vulnerability | folded wing-corner | O02/O06/O12 | cut/merge if footprint+sleep does not create unique decision family |
| O17 Coal Urchin | thermal helper becomes social liability | spines cool/flare | O01/O10/O09 | keep if helper-liability tradeoff is clear and not redundant |
| O18 Spindle Bloom | contamination source expands footprint over time | bud unfurls to spore line | O04/O13 | keep as advanced source+topology compound |
| O19 Amber Leech | consumes food while protecting same partner | feeding/protection tether | O05/O20 | cut/merge if dependency/protection does not beat simpler protector roles |
| O20 Whistle Crab | protector becomes alarm hazard when stressed | shelter claw + whistle rings | O05/O19 | cut/merge if downside does not produce distinct planning from Warmback |
| O21 Pale Drifter | wake event produces one cleansing pulse | wake clearing ring | O15/O14 | keep as bounded-discovery timing species |
| O22 Splitcap | filtering success causes 4-cell growth + possible alarm | cap separates into four lobes | O03/O18 | keep only as mastery composite; never early/discovery |

Empirical redundancy gate:
- O06/O12/O16 and O05/O19/O20 are mandatory prototype comparison clusters.
- If two members of a cluster produce the same preferred placement/support/revision choice in >=70% of a representative validation set, cut or merge the less readable one.
- A cut reduces launch species count; it does **not** authorize adding replacement mechanics merely to preserve “22”.

---

# 6. Frozen deterministic edge semantics

These Phase-10 repairs are implementation rules now.

## 6.1 T10 Reactive Pulse guard
Every T10 definition declares exactly one:
- `once_per_run`;
- `once_per_episode`;
- explicit finite `max_triggers_per_run`.

Unlimited state-transition-triggered positive resource generation is forbidden. A validator rejects self-sustaining trigger/resource loops.

## 6.2 Simultaneous causal roots
When multiple independent same-phase causes materially contribute to one threshold/predicate failure, the causal event has multiple parents. UI may choose one display-first branch for brevity but the stored causal graph must preserve all material roots.

## 6.3 Brownout authority
Brownout/power capacity is finalized in **Phase A**. A support disabled by Brownout produces no same-tick Phase-C/E effect. Playback animation may lag visually but cannot change this.

## 6.4 Blocked-growth episode semantics
A deterministic growth attempt that is illegal begins/continues a `GROWTH_BLOCKED` episode.
- The blocked-growth consequence fires **once** when the unchanged blocked episode begins.
- It does not re-apply every subsequent tick merely because the same cells remain blocked.
- A new attempt/consequence is legal only after a relevant condition changes: target-cell legality/occupancy, orientation/body condition, growth trigger condition, or an explicitly defined retry boundary.
- The episode emits one causal root event plus later state consequences.

This supersedes any reading that repeatedly damages/stresses the organism every tick for the same unchanged obstruction.

## 6.5 Sleep trait gating
`ASLEEP` changes only behaviors explicitly gated by organism/trait data. Passive heat/spore/etc. output never disappears merely because the creature looks asleep.

---

# 7. Frozen authority/idempotency and persistence repairs

## 7.1 Launch commit
- `Launch Confirm` creates exactly one immutable `CommittedTransitInput` with a unique commit token.
- repeated confirm input, double-click, controller repeat, scene re-entry, or UI lag cannot create multiple transits/progression side effects.
- cancel before commit returns to editable Planning with no simulation/progression write.

## 7.2 Results progression
- campaign progression writes only after mandatory Results success evaluation is final;
- every Results award has an idempotency key derived from profile + contract/challenge identity + result token/version;
- re-entering Results, crash-recovery, or replaying presentation cannot duplicate unlocks, documentation, medals, achievements, or campaign completion;
- a better medal updates best result; it does not repeat one-time unlock side effects.

## 7.3 Transit resume
Canonical resume behavior is **reconstruction from committed input**, not persistence of a platform-sensitive partial simulation object.
- persist committed input, rules/content versions, presentation cursor if useful, and expected checksum sequence/checkpoint;
- on resume, rerun deterministically from tick 0 to the requested cursor/checkpoint;
- if checksum diverges, enter recovery flow and do not silently continue a different history.

## 7.4 Save recovery
- profile/settings writes are atomic temp-write -> fsync/flush as available -> replace;
- maintain one last-known-good backup for campaign profile;
- corrupt primary with valid backup => load backup, notify non-destructively, preserve corrupt file for diagnostics when possible;
- corrupt primary + corrupt backup => `SAVE_RECOVERY`, never auto-reset/delete without explicit user action;
- schema migration operates on a copy and commits only after validation;
- cloud/local divergence uses explicit newest-valid/version-compatible comparison; never merge authoritative progression by ad hoc union if that can duplicate one-time events.

## 7.5 Legacy version mismatch
- historical committed transit is reproducible only when required rules/content definitions are available and hashes match;
- if incompatible definitions are unavailable, show `legacy transit unavailable under current rules` and preserve final historical result metadata where possible;
- never rerun old input under new rules and present it as the same deterministic transit.

## 7.6 Demo migration
- full game imports compatible demo profile through explicit migration mapping;
- settings and knowledge transfer independently from campaign-clear mapping;
- C01–C08 completion mapping is idempotent;
- D09–D10 never map to C09+ completion;
- Challenge unlock gate is recomputed from full-game campaign prerequisites, not copied as a raw boolean.

---

# 8. Accessibility/input acceptance freeze

Mandatory launch acceptance surfaces:
- mouse + keyboard;
- keyboard-only;
- gamepad-only;
- Steam Deck-like 1280x800 target and 1280x720 minimum supported layout;
- UI scaling at the largest supported scale without hiding mandatory controls or objective state;
- non-color reading: state/pressure/validity never encoded by hue alone;
- no-audio path: every gameplay-critical cue has visual/text equivalent;
- reduced motion: no required information depends on movement amplitude;
- reduced flashing/intensity option;
- remapped controls preserve every mandatory action and focus traversal path.

Mouse remains the preferred efficiency baseline, but controller/Deck paths are **acceptance requirements**, not optional aspirations.

---

# 9. Unified acceptance-test index

This index is the minimum cross-system suite required before design freeze can be considered implementation-ready. Individual files may define more tests.

## A — Determinism / simulation
A01 identical committed input + version => identical checksum sequence and event log.  
A02 playback speed/pause/frame rate do not alter output.  
A03 stable entity ordering removes dictionary/hash-order dependence.  
A04 simultaneous thresholds use same Phase-F snapshot.  
A05 Brownout is authoritative from Phase A.  
A06 multi-root causal events preserve all material parents.  
A07 blocked growth fires one consequence per unchanged episode.  
A08 every T10 has finite trigger guard.  
A09 save/reload/resume reconstructs identical remaining transit.  
A10 incompatible legacy content never silently changes historical outcome.

## B — Planning / state machine
B01 invalid overlap/out-of-bounds blocks launch.  
B02 legal-but-risky future failure does not block launch.  
B03 undo/redo/reset cannot corrupt occupancy or support allocation.  
B04 repeated Launch Confirm yields one commit token.  
B05 abort active playback safely returns to the committed planning baseline without campaign penalty.  
B06 Retry from last launch reproduces exact committed layout as editable baseline.  
B07 Settings/pause cannot mutate authoritative transit.

## C — Campaign / progression
C01 graph has 48 acyclic reachable nodes with exact prerequisite table.  
C02 Bronze alone progresses campaign.  
C03 Results writes unlocks exactly once.  
C04 medal upgrades cannot replay one-time unlocks.  
C05 Challenge unlock occurs only after Tier-2 capstone.  
C06 demo mapping clears at most C01–C08.  
C07 campaign completion requires C48 and no medal total.

## D — Content / dominant strategy
D01 every C05–C48 has decision-relevant dynamic transit.  
D02 >=20 of C09–C48 require two separated post-launch changes for Bronze.  
D03 spacing/edge/growth-zone diversity quotas pass.  
D04 Cooler+Filter primary Bronze pair <=8 of C17–C48.  
D05 every S01–S06 has preferred, inferior, and alternate-use evidence where applicable.  
D06 roster redundancy clusters satisfy keep/cut evidence gate.  
D07 no universal all-channel buffer exists.  
D08 authored Bronze below Tier 6 normally explains in <=6 major causal links.

## E — Generator / solver
E01 every surfaced Bronze has certified solution or known-valid construction.  
E02 timeout is never success proof.  
E03 static-solvable candidates rejected.  
E04 medal solution is certified before medal is offered.  
E05 causal-opacity limits pass.  
E06 recent-fingerprint similarity and support-streak rules pass.  
E07 seed + generator/rules/content version reproduces exact challenge.  
E08 validation hash and hidden QA solution fingerprint persist.

## F — UX / causal review
F01 failure defaults to shortest useful failed-predicate -> decisive event -> root cause chain.  
F02 full log remains inspectable without being required for ordinary understanding.  
F03 growth failure shows attempted footprint and blocker.  
F04 current-state prediction aids do clerical arithmetic for the player when >3 contributors are relevant.  
F05 no critical distinction depends only on color/audio/motion.  
F06 controller/keyboard focus can reach every mandatory planning/review action.  
F07 review can jump between failed predicate, decisive event, direct cause, root cause, and affected entity/cell.

## G — Persistence / corruption
G01 atomic write survives interruption before replace.  
G02 corrupt primary loads valid backup.  
G03 corrupt primary+backup enters recovery without deletion.  
G04 migration failure leaves original untouched.  
G05 cloud/local divergence cannot duplicate unlock IDs/result tokens.  
G06 resume checksum mismatch enters recovery.  
G07 old rules/content mismatch never masquerades as deterministic equivalence.

## H — Accessibility / device
H01 1280x720 and 1280x800 mandatory screens remain usable at max supported UI scale.  
H02 keyboard-only complete campaign path.  
H03 gamepad-only complete campaign path.  
H04 remapped-input complete mandatory path.  
H05 no-audio complete mandatory path.  
H06 non-color complete mandatory path.  
H07 reduced-motion/reduced-flash paths preserve causality/readability.

## I — Demo/product identity
I01 demo contains 10 species = 9 documented + 1 discovery.  
I02 dynamic-transit identity appears by demo contract 3.  
I03 >=5/10 demo authored contracts use Bronze-relevant post-launch change.  
I04 demo migration does not grant mechanical power.  
I05 player-description validation favors transit prediction over static packing.

---

# 10. Prototype-dependent gates — not specification gaps

These are implementation/vertical-slice kill metrics and remain valid after paper design freeze:
1. >=70% of failed validation shipments should lead to an articulated causal explanation + specific intended revision before successful retry;
2. at least half of memorable validation outcomes should depend on post-launch state change;
3. ordinary C01–C40 non-mastery planning should not settle above 8-minute median first-launch time after rules are familiar;
4. O06/O12/O16 and O05/O19/O20 must prove decision-distinct or be cut/merged;
5. demo testers should primarily describe transit prediction rather than static packing;
6. Causal Review should expose an actionable first cause quickly without raw-log dependence.

Failing one of these gates during prototype does not justify hidden difficulty, retry punishment, or feature bloat. Simplify, cut redundancy, or revisit the relevant content rule.

---

# 11. Remaining Phase-11 work after this pass

Still required before `DESIGN COMPLETE = YES`:
1. fold the frozen items above into their canonical source files rather than relying indefinitely on an override document;
2. remove/replace stale `TBD`, `Phase 4/5/6/7/8 work`, and outdated mouse/gamepad language in `GAME_BIBLE.md`;
3. repair stale Phase-4 closure wording in `MECHANICS.md` now that later documents completed those items;
4. correct public-demo count/transfer wording in `CONTENT_ARCHITECTURE.md` and any other source;
5. fold blocked-growth/T10/Brownout/multi-root semantics into `MECHANICS.md` and `TECHNICAL_SPEC.md`;
6. fold launch/results idempotency, transit reconstruction, recovery, legacy-version, and demo-migration cases into `TECHNICAL_SPEC.md`;
7. fold device/accessibility acceptance obligations into `UX_ARCHITECTURE.md` and technical acceptance criteria;
8. run repository-wide contradiction search for superseded phrases/counts and verify no hidden second authority remains;
9. update the Game Bible to a concise final canonical overview that points to detailed frozen appendices;
10. only then set specification freeze and `DESIGN COMPLETE` to YES.
