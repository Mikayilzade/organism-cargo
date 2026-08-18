# ORGANISM CARGO — ADVERSARIAL REVIEW

Status: **CANONICAL PHASE 10 — COMPLETE WITH REPAIRS / PROTOTYPE RISKS DEFERRED**
Last updated: 2026-08-15
Production code started: **NO**

This document attacks the locked Organism Cargo design as if a hostile player, optimizer, accessibility user, corrupted save, generator edge case, or careless implementation were trying to break it. It does not add a new gameplay subsystem. Where this file repairs an ambiguity, the repair is canonical immediately and must be folded into the source documents during Phase 11 specification freeze.

Phase 10 cannot prove subjective fun without a playable prototype. It can, however, remove rules that obviously incentivize degenerate play, define hard anti-degeneracy gates, and convert remaining uncertainty into explicit prototype acceptance criteria.

---

# 1. Severity and attack format

Severity:
- **CRITICAL** — can invalidate the product thesis, corrupt progression, make deterministic replay false, or require redesign before implementation.
- **HIGH** — can create a broadly dominant strategy, unfair failure, inaccessible mandatory path, or major production trap.
- **MEDIUM** — can create repeated friction, misleading feedback, narrow content redundancy, or recoverable technical ambiguity.
- **LOW** — polish/readability concern that does not alter systemic correctness.

Each attack records:
- **Attack** — hostile behavior or failure case.
- **Expected** — intended design behavior.
- **Failure if unpatched** — why the current interpretation is unsafe.
- **Repair** — canonical answer.
- **Retest** — acceptance condition.

Verdict labels:
- `PASS` — current canonical rules already resist the attack.
- `REPAIRED` — Phase 10 adds a canonical clarification/constraint.
- `PROTOTYPE GATE` — cannot be honestly closed on paper; implementation prototype must measure it before production scope expands.

---

# 2. Fundamental fun-risk attacks

## F01 — Static placement is the real puzzle; transit is spectacle
Severity: **CRITICAL**  
Attack: a skilled player solves nearly every contract from time-zero adjacency, then watches transit only to confirm what was already obvious.

Expected: commitment matters because at least one relationship changes after launch and the player must reason about timing/state evolution.

Repair: preserve the existing transit-significance rule and strengthen it into a release/content gate:
1. every non-tutorial authored contract from C05 onward must contain at least one **decision-relevant dynamic event**, defined as a post-launch state/footprint/channel/support-power change whose timing or consequence makes at least one otherwise-plausible time-zero arrangement worse or invalid;
2. at least **50% of authored campaign contracts C09–C48** must require the successful Bronze solution to anticipate two or more temporally separated state changes, not merely one route hazard pulse;
3. generated challenges remain rejected when time-zero/static adjacency alone explains the intended solution;
4. demo telemetry/playtest review must show that at least half of memorable post-onboarding outcomes cited by testers depend on transit-time change.

Retest: sample each chapter plus all demo contracts and ask an evaluator to describe the decisive reason for the layout. If the answer is purely static fit/adjacency for more than the allowed exceptions, fail content validation.

Verdict: **REPAIRED**.

## F02 — Random-shuffle retry beats understanding
Severity: **CRITICAL**  
Attack: because retry is free, the player can repeatedly shuffle cargo and launch until Bronze succeeds without inspecting review.

Expected: free retry supports learning, not blind search.

Repair: do **not** add retry cost or attempt limits. Instead require challenge geometry/content to provide enough causal structure that blind search is inefficient relative to understanding. Causal Review remains instantly available and retry restores last launch. Prototype metric is mandatory:
- after onboarding, testers who fail must be able to name a specific causal hypothesis before most successful retries;
- target inherited from concept selection: **>=70% of failed prototype shipments** in the validation set lead to an articulated cause + specific planned revision rather than random rearrangement.

This is a **prototype gate**, not a progression punishment.

Verdict: **PROTOTYPE GATE**.

## F03 — The game feels like arithmetic homework
Severity: **HIGH**  
Attack: optimal play requires manually summing many +2/-3 effects, calculating propagation, and tracking counters.

Expected: exact rules are inspectable, but the player reasons in relationships/timing while UI handles clerical arithmetic.

Repair:
- current-state one-tick totals may be shown on demand;
- Causal Review may show exact historical values;
- no contract may require a Bronze solution that depends on mentally combining more than **three simultaneous numeric contributors to one target variable** without the UI surfacing the aggregate current-state contribution;
- authored content should prefer threshold bands, timing, capacity, orientation, and tradeoffs over close arithmetic margins;
- generator rejects Bronze solutions whose certified safety margin is one unit on multiple independent thresholds unless the contract is explicitly Tier-6 precision mastery and the cause remains legible.

Verdict: **REPAIRED**.

## F04 — Causal Review fatigue
Severity: **HIGH**  
Attack: every transit produces dozens of events and the player must repeatedly inspect a forensic tool to progress.

Expected: Review is useful when needed, optional when success is obvious.

Repair:
- success enters Causal Review but the player may continue directly to Results after the decisive summary is visible;
- failure review defaults to the shortest useful chain from failed predicate to root cause, not the entire log;
- routine propagation collapses into grouped events;
- no Bronze campaign contract should require reading more than **six major causal links** below Tier 6; existing generator opacity limits become an authored-content review target too;
- repeated retry of the same contract may preserve the user's last review focus/filter.

Verdict: **REPAIRED**.

## F05 — Planning sessions become unbounded analysis paralysis
Severity: **MEDIUM/HIGH**  
Attack: late contracts produce 20+ minute silent planning sessions before a 15-second transit.

Expected: no timer pressure, but contracts remain compact enough for repeated hypothesis cycles.

Repair: no forced timer. Scope/content constraint:
- normal manifest remains **3–7 organisms**; 8–9 reserved for authored late mastery/final contracts;
- normal hold remains fully visible;
- first plausible Bronze plan for a new non-mastery contract should be formable by intended players without exhaustive enumeration;
- if playtests show median first-launch planning above **8 minutes** on ordinary C01–C40 contracts after the player understands the rules, simplify the contract rather than adding hints that solve it.

Verdict: **PROTOTYPE GATE**.

---

# 3. Dominant-layout attacks

## L01 — Maximum spacing / edge isolation is universal Bronze
Severity: **CRITICAL**

Attack: put organisms on edges/corners, maximize Manhattan distance, use empty cells as universal defense.

Why it is dangerous: this would collapse spatial reasoning into one reusable template.

Canonical counterconditions already available and now mandatory across content:
1. beneficial adjacency/feeding/symbiosis must matter in a meaningful share of contracts;
2. lifecycle growth can make edge/corner placement worse because deterministic future cells become blocked/outside usable topology;
3. zone hazards can punish safe-looking edges;
4. limited hold geometry/blocked cells prevent universal spacing;
5. some contracts require a final zone, maturation, feeding, or wake-state objective that forces relationships;
6. support fixtures create localized opportunity costs.

Repair: authored campaign validation must classify each C09–C48 Bronze solution family by `isolation_ratio` and `beneficial_relation_count`. At least **two contracts per chapter from Chapters 2–6** must have certified Bronze solutions where high isolation is inferior or impossible for a rule-based reason. Generated challenge validator rejects a candidate if the best certified Bronze family is pure maximum-spacing and no dynamic relationship is necessary, unless the explicit challenge family is `separation under changing topology` and future change is the real problem.

Verdict: **REPAIRED**.

## L02 — Permanent central Hushling/soother anchor
Severity: **HIGH**

Attack: place Hushling or another soother centrally and build every cargo around it.

Existing resistance:
- Hushling capacity = one target;
- Hushling is Sensitive;
- soothing disables when AGITATED/PANICKED/ASLEEP;
- route pressure can target the central cluster;
- Baffle/separation can be superior;
- some organisms need feeding/growth positioning more than stress reduction.

Repair: no additional mechanic. Content/generator rule: never certify a challenge as varied if the same soother species occupies the same topology role in more than three surfaced challenges. Tier 4+ authored contracts must include explicit cases where a Hushling/Velvet Nurse/Moth Cushion is (a) unavailable, (b) vulnerable at the decisive window, or (c) strategically inferior to topology/support mitigation.

Verdict: **PASS + CONTENT GATE**.

## L03 — Reserve one permanent growth corner
Severity: **HIGH**

Attack: always point growth species toward the same empty corner/edge pocket.

Repair:
- authored hold rotation, irregular geometry, Thermal Gradient, route zones, and multi-growth species must change which reserved space is valuable;
- growth footprints differ (Domino, Corner, Bar, mastery 4-cell extension);
- at least one Chapter-3, one Chapter-4, and two Chapter-6 contracts must make the obvious edge reserve strategically bad because that future footprint enters a hazard zone, blocks another beneficial relation, or strands the mature body away from a required relation.

Verdict: **REPAIRED**.

## L04 — Emitter-to-edge universal template
Severity: **HIGH**

Attack: place every heat/alarm/spore emitter at edge cells to reduce propagation.

Repair: no arbitrary anti-edge modifier. Counter only through existing rules: route zone assignments, required relationships, local sinks, directed effects, growth, fixture competition, and irregular topology. Generator diversity fingerprint is extended conceptually: `source_edge_fraction` becomes a diagnostic metric; repeated challenges where all hazardous sources are optimally edge-parked are down-ranked/rejected.

Verdict: **REPAIRED**.

## L05 — Repeated zone template
Severity: **HIGH**

Attack: memorize `sources left, sensitive right, helper center` across authored layouts.

Repair: preserve five hold families and route-zone variation; authored validation records canonical Bronze zone allocation. No chapter after Chapter 2 may have more than **three consecutive contracts** whose certified primary Bronze family uses the same role-to-zone allocation pattern after symmetry normalization.

Verdict: **REPAIRED**.

---

# 4. Support-dominance attacks

## S-A01 — Cooler + Filter solves nearly everything
Severity: **CRITICAL**

Attack: always spend utility fixtures/power on Cooler and Filter, then treat social/growth problems as secondary.

Existing resistance:
- each is single-channel and capacity limited;
- both draw 2 power;
- Brownout can disable them;
- fixture availability varies;
- Gold may favor no powered support;
- living sinks exist;
- stress has no equivalent powered cleanser.

Repair:
1. Tier 3+ authored contracts must not make Cooler+Filter jointly available by default; allowance is contract-specific.
2. Across C17–C48, no more than **25%** of contracts may have Cooler+Filter as a certified primary Bronze support pair.
3. At least one contract in each of Chapters 3–6 must make one or both actively inferior because power priority, fixture location, beneficial contamination/heat timing, or another needed support creates a better family.
4. Generator retains the existing `same powered-support pair >3 consecutive` anti-streak rule and should reject candidates whose Bronze solver says Cooler+Filter strictly dominates every other legal support family when at least two families are intended.

Verdict: **REPAIRED**.

## S-A02 — Baffle + soother universal social answer
Severity: **HIGH**

Attack: isolate the loudest source with Baffle and park a soother by the remaining weak target.

Existing tradeoffs: Baffle consumes spatial opportunity, blocks beneficial influence/rays, may block growth; soothers are capacity/state limited.

Repair: no new mechanic. Authored content must include route timing and geometry where the source that should be separated changes state mid-transit or where Baffle breaks a required feeding/symbiotic relation. Generator rejects if Baffle+one soother neutralizes all stress decisions without creating another spatial/lifecycle tradeoff.

Verdict: **PASS + CONTENT GATE**.

## S-A03 — Nest Pad turns dangerous species off
Severity: **HIGH**

Attack: put the main emitter/helper on Nest Pad and bypass its downside.

Existing resistance: capacity one, compatibility, wake hazards, awake-only beneficial traits lost, arrival may require awake.

Repair: canonical clarification: **sleep never suppresses passive environmental output unless the species/trait explicitly states state-gating**. Nest Pad only changes behavior through documented state gates; it is not a generic off switch. No trait is implicitly disabled because the animation looks asleep.

Retest: for every species available with Nest Pad, validator enumerates awake/asleep trait gates and flags any undocumented disappearance of a harmful or beneficial output.

Verdict: **REPAIRED**.

## S-A04 — Monitor Beacon is either mandatory or worthless
Severity: **HIGH**

Attack A: discovery contracts are effectively guesswork without Monitor.  
Attack B: exact evidence is unnecessary, so Monitor is dead content.

Repair:
- every discovery Bronze must remain conservatively solvable without Monitor;
- Monitor must improve evidence quality, optional medal confidence, or intervention precision in at least one authored path;
- Monitor may never be a mandatory structural prerequisite for campaign Bronze;
- generated non-discovery content should not offer Monitor when there is no information value.

Verdict: **REPAIRED**.

## S-A05 — Living organisms obsolete supports
Severity: **HIGH**

Attack: Frost Finch makes Cooler pointless; Mire Sipper makes Filter pointless; Hushling makes Baffle pointless.

Expected: living substitutes trade footprint/state vulnerability for reduced power/fixture use.

Repair: define role distinction as canonical balance target:
- powered support = predictable, single-channel, fixture/power constrained, generally state-independent while powered;
- organism substitute = occupies cargo space, may provide secondary behavior, but can change state or create another cost;
- neither family may strictly dominate across the launch content set.

Phase-11 acceptance matrix must list at least one authored contract where each of S01–S06 is preferred, one where it is legal but inferior, and one where a living substitute creates a different valid Bronze family where applicable.

Verdict: **REPAIRED**.

---

# 5. Scoring / medal exploit attacks

## M01 — Harm welfare to trigger useful pulses or reduce complexity
Severity: **CRITICAL**

Attack: intentionally panic/contaminate/starve an organism because its pulse helps others, then still earn Gold.

Existing rule bans medals rewarding intentional critical harm, but non-critical induced distress could still be farmed.

Repair: optional medals may reward **controlled transient states** only when the state is the explicit taught mechanic and the final/maximum welfare bounds remain strict. Gold cannot require entering PANICKED, CRITICAL, or exceeding the ordinary contamination welfare ceiling unless the product's welfare framing is explicitly changed (not authorized). If a beneficial T10 pulse requires recovery from AGITATED, authored Gold may use it only when the organism never PANICS and finishes within safe thresholds.

Verdict: **REPAIRED**.

## M02 — Deliberately delay transit success / farm event counts
Severity: **HIGH**

Attack: exploit score based on event count, repeated recovery pulses, or prolonged unstable states.

Repair: medals/scoring never award raw event count, number of state transitions, elapsed wall-clock time, or extra playback ticks. Route tick count is fixed by contract. Reactive-pulse event guards/cooldowns remain bounded. Any predicate over transitions is a welfare/control bound (`never entered`, `max count <= n`), not a positive farming score.

Verdict: **REPAIRED**.

## M03 — Support spam for score
Severity: **MEDIUM/HIGH**

Attack: install every legal support because medal logic only checks survival.

Expected: Bronze may permit brute safety, Gold can ask for elegance.

Repair: no global score formula based on “fewer supports.” Optional Gold may use `support_count <= n`, `powered_support_count <= n`, or named restrictions only when the contract has at least two validated Bronze families. Support minimization must never force worse mandatory welfare.

Verdict: **PASS**.

## M04 — Empty-space farming
Severity: **HIGH**

Attack: medals reward unused cells, turning the game back into sparse packing.

Repair: unused-cell count is **not a launch-wide medal axis**. It may appear only as an authored contract-specific efficiency predicate when density itself creates a demonstrated dynamic transit tradeoff. No persistent score rewards empty area globally.

Verdict: **REPAIRED**.

## M05 — State-transition farming for Lantern Tick / reactive effects
Severity: **HIGH**

Attack: oscillate a creature across AGITATED/CALM repeatedly to generate food/cleansing pulses.

Existing guards already require distinct legal recovery and bounded cooldown/event guard.

Repair: every T10 definition must declare one of: `once_per_run`, `once_per_episode`, or explicit finite `max_triggers_per_run`. Unlimited transition-triggered resource generation is forbidden. Validator rejects positive feedback loops that can maintain or increase the resource enabling the same trigger indefinitely.

Verdict: **REPAIRED**.

---

# 6. Deterministic-causality attacks

## C01 — Simultaneous threshold crossings produce order-dependent results
Severity: **CRITICAL**

Attack: two organisms cross PANIC threshold on the same tick; one pulse could appear to prevent/trigger the other's crossing depending iteration order.

Existing canonical rule: all Phase-G threshold decisions use same Phase-F committed snapshot; same-tick state-entry pulses execute as a batch in H and cannot retroactively alter crossings.

Verdict: **PASS**.

## C02 — Multiple valid roots; review invents a single cause
Severity: **HIGH**

Attack: two independent heat sources are both necessary to cross a threshold, or two separate chains make a final predicate fail.

Repair/clarification: first decisive failure analyzer must emit a **multi-parent cause set** when no single sufficient root exists. Player-facing wording may say `combined causes` / group roots. It must not select one by event order for narrative convenience.

Verdict: **REPAIRED**.

## C03 — Delayed T10 output loses causal parent
Severity: **HIGH**

Attack: a scheduled next-tick pulse appears as an unexplained source event.

Repair: scheduled events persist `origin_event_id`, source rule ID, scheduled tick, and episode guard. When fired, causal parent is the original state-entry/recovery event plus any still-required enabling condition. Review jump-to-root traverses the scheduled boundary.

Verdict: **REPAIRED**.

## C04 — Brownout changes support state mid-tick ambiguously
Severity: **CRITICAL**

Attack: a support both operates and powers off on the same tick depending evaluation order.

Repair/confirmation: Brownout/available power is Phase A. Power allocation state for tick `t` is finalized before Phase C support output. A support that loses power in A produces **no Phase-C output on that tick** unless its definition explicitly has an already-scheduled non-powered consequence. Power restoration likewise enables output starting that tick after A.

Verdict: **REPAIRED**.

## C05 — Growth-block retry loop creates infinite stress/pulse exploit
Severity: **HIGH**

Attack: growth condition remains true forever while blocked, producing stress every tick and farming transition effects.

Repair: canonical blocked-growth semantics:
- growth attempt may recur while condition remains true because future space could become available only through state changes? In base game organisms do not move and supports do not disappear, so occupancy normally cannot clear during transit except body-state changes.
- Therefore a blocked growth attempt records `GROWTH_BLOCKED` and applies its species-defined block consequence **once per growth episode**, not every tick.
- It may re-attempt only when the relevant footprint legality changes or the growth condition becomes false then later true again.
- If no legal state change can free cells, repeated identical attempts are suppressed.

This removes stress farming and log spam while preserving the lesson that future space matters.

Verdict: **REPAIRED**.

## C06 — Contamination persistence ancestry becomes unreadable
Severity: **HIGH**

Attack: residue spreads over several ticks, mixes from multiple sources, and later infects a target; causal graph becomes enormous.

Repair: authoritative contamination field may aggregate source attribution for review as bounded contribution groups rather than keeping every microscopic propagation edge. For predicate explanation, preserve at least the top contributing root source groups and `mixed residual contamination` when exact decomposition is no longer uniquely useful. Debug trace can remain more detailed. This grouping is presentation/causal indexing only; channel arithmetic remains exact.

Verdict: **REPAIRED**.

## C07 — Grouped propagation hides a decisive threshold
Severity: **HIGH**

Attack: UI groups routine propagation so aggressively that it hides why a meter crossed.

Repair: any grouped event containing the decisive value change must expose exact before/delta/after on expansion and direct parent groups. P0/P1 decisive events can never be collapsed into an inaccessible aggregate.

Verdict: **REPAIRED**.

---

# 7. Planning/state-transition abuse

## P01 — Launch double-click / confirm race
Severity: **HIGH**

Attack: spam Launch/Cancel/Space so two committed runs or two progression writes are created.

Repair: Launch Confirm uses one transition token. First accepted confirm atomically freezes committed input and changes state; subsequent confirm/cancel input is ignored until transition completes. Exactly one `last_launch` snapshot is written per accepted launch.

Verdict: **REPAIRED**.

## P02 — Undo/reset during transition
Severity: **HIGH**

Attack: trigger undo/reset while Launch Confirm is closing or transit starts.

Repair: planning command queue is disabled after launch commit transition begins. Cancel before commit returns unchanged planning state. After commit, only transit controls are accepted. No input event may mutate `PlanningSession` shared with immutable committed input.

Verdict: **REPAIRED**.

## P03 — Retry spam duplicates progression
Severity: **CRITICAL**

Attack: rapidly enter Results/retry/back/map and cause multiple unlock writes.

Repair: campaign completion event uses stable `(profile_uuid, contract_id, completion_revision/run_id)` idempotency semantics. `Results finalization` is the only authority that writes campaign clear/medal/discovery progression for a run; replaying UI transitions cannot re-award anything meaningful because unlocks are set/maximum operations, not additive currency.

Verdict: **REPAIRED**.

## P04 — Abort transit to scout hidden information for free
Severity: **HIGH**

Attack: launch a discovery contract, observe early hidden behavior, abort, repack, and thereby bypass information opportunity cost.

Current Phase-9 rule allows non-punitive abort back to committed planning baseline.

Repair: learned **player knowledge** from observed transit is intentionally not erased; the game never pretends the player forgot. However profile-level `DOCUMENTED` codex unlock is granted only when the canonical evidence threshold is reached and finalized under the discovery rules. Abort cannot roll back observed reality but may prevent formal documentation/progression if evidence/finalization requirements were not reached. Discovery Bronze remains conservatively solvable without needing exploitative abort loops.

Verdict: **REPAIRED**.

## P05 — Settings/quit around authoritative boundaries
Severity: **HIGH**

Attack: quit or open settings during commit/result write.

Repair: settings are non-authoritative overlay. Quit request waits for the current atomic save transaction to finish or cancels before transaction begins; no partial payload becomes primary. On next boot, primary/backup validation applies. Results progression write must complete before map transition is considered committed.

Verdict: **REPAIRED**.

---

# 8. Persistence / recovery attacks

## R01 — Interrupted atomic write
Severity: **CRITICAL**

Expected: old valid primary or backup survives.

Canonical behavior: temp write -> parse/checksum verify -> rotate valid primary to backup -> atomic replace. On boot, invalid temp is ignored/cleaned. Never treat temp as primary merely because timestamp is newer.

Verdict: **PASS**.

## R02 — Corrupt primary + valid backup
Severity: **CRITICAL**

Repair/clarification: automatically load valid backup into `SAVE_RECOVERY`, explain that recovery occurred, and **do not overwrite the corrupt primary until the recovered profile is successfully re-saved**. Preserve corrupt file as diagnostic copy where practical.

Verdict: **REPAIRED**.

## R03 — Corrupt primary + corrupt backup
Severity: **CRITICAL**

Repair: never fabricate progress. Enter `SAVE_RECOVERY` with options to start a new profile and, where tooling exists, export diagnostics. Settings remain unaffected. If a valid cloud copy is separately available, platform recovery may offer it before new-profile creation. No silent reset.

Verdict: **REPAIRED**.

## R04 — Legacy rules/content version changes deterministic result
Severity: **CRITICAL**

Repair: in-progress committed transit/review can resume only if required content/rules version is available/migratable with checksum equivalence. Otherwise return safely to Planning using the committed layout under migrated current definitions **without claiming it is the same historical run**, mark prior transit as non-resumable, and preserve permanent campaign progress. Authored completed contract medals/progress are never invalidated by rebalance patches.

Verdict: **REPAIRED**.

## R05 — Cloud/local divergence
Severity: **HIGH**

Repair: never auto-merge active session/planning states. For profile state, union cleared contracts/codex unlocks and take best medal only if both saves share compatible campaign/content schema and graph invariants; otherwise present conflict choice. Monotonic revision/timestamp are recovery cues, not blind winner rules. Settings stay local.

Verdict: **PASS + CLARIFIED**.

## R06 — Demo migration mismatch
Severity: **HIGH**

Canonical Phase-9 rule is preserved:
- D01–D08 may certify C01–C08 onboarding clearance;
- D09–D10 remain demo-only records;
- full campaign resumes at Chapter 2;
- imported documented knowledge/settings persists;
- challenge mode cannot unlock before Tier-2 capstone;
- import is idempotent and never overwrites newer full progress.

Additional Phase-10 gate: migration tests must include import repeated twice, demo older than full, demo newer but partial, missing demo content IDs, and cloud/local split. None may duplicate unlocks or skip the Tier-2 Challenge gate.

Verdict: **PASS + TEST EXPANSION**.

## R07 — Transit checksum mismatch on resume
Severity: **CRITICAL**

Repair: do not continue at the saved cursor. Reconstruct from committed input; if checksum sequence differs from stored compatible-version sequence, reset playback to tick 0 or final verified boundary and show recovery notice. Never alter campaign progress. In release builds, capture diagnostic code/version IDs without exposing developer jargon as the main message.

Verdict: **REPAIRED**.

---

# 9. Accessibility / input attacks

## A01 — 1280x720 / Deck-like + 150–200% UI scale
Severity: **HIGH**

Attack: hold becomes unreadable or mandatory buttons fall off-screen.

Repair: existing tab/drawer fallback becomes mandatory. At high UI scale, manifest and inspector may not coexist side-by-side; central hold keeps minimum usable cell size and panels switch to explicit tabs. Launch/objectives remain reachable without horizontal scrolling. Exact pixel minimums belong implementation validation, but no mandatory information may exist only in a hover tooltip.

Verdict: **REPAIRED**.

## A02 — Reduced motion / reduced flashing
Severity: **HIGH**

Repair: state transitions use icon/pose/outline persistence in addition to animation. Reduced motion may snap/tween minimally between authoritative states. Reduced flashing replaces pulses with static/slow emphasis. Causal sequence remains readable through event markers/timeline.

Verdict: **PASS**.

## A03 — No audio
Severity: **HIGH**

All gameplay-critical audio cues have visual caption/icon alternatives. Event feed/timeline must represent hazard onset, panic, growth, contamination threshold, support power loss, and decisive failure.

Verdict: **PASS**.

## A04 — Color-blind / monochrome reading
Severity: **HIGH**

Heat/stress/contamination must differ by pattern/icon/motion language, not hue alone. Valid/invalid/warning placement uses shape/hatch/icon semantics in addition to color.

Verdict: **PASS**.

## A05 — Controller-only
Severity: **HIGH**

Grid-focus model is mandatory; no fake pointer-only requirement. Every drag action must have pick-up/move/place equivalents; overlay, rotate, inspect, link, power-priority, launch, review scrub, reset, and retry have semantic actions/focus paths.

Verdict: **PASS**.

## A06 — Keyboard-only
Severity: **MEDIUM/HIGH**

Repair: keyboard-only path may reuse logical focus navigation from controller. Pointer is preferred but not mandatory. All modal focus order must be testable with mouse disconnected.

Verdict: **REPAIRED**.

## A07 — Remapped controls collide with text entry/navigation
Severity: **MEDIUM**

Repair: semantic actions distinguish UI text-entry context from gameplay actions. Reset/backspace and letter hotkeys must not fire while search/text fields own focus. Conflict detection warns about duplicate mandatory actions.

Verdict: **REPAIRED**.

---

# 10. Campaign prerequisite attack

Attack: branching progression lets a player reach a mandatory contract before learning a species/trait/support/hazard it assumes.

Severity: **CRITICAL**.

Canonical validator requirements:
1. every campaign node declares explicit prerequisite contract IDs;
2. every assumed documented fact/support/hazard at node entry has at least one prerequisite ancestry path that guarantees its unlock;
3. because branches may bypass siblings, an assumed lesson cannot be supplied solely by an optional sibling unless that sibling is also a prerequisite;
4. tier capstone validates coverage of all mandatory lessons required by the next tier;
5. medals, generated challenges, achievements, and playtime never satisfy prerequisites;
6. D01–D08 import may satisfy only the mapped C01–C08 clear flags and associated guaranteed documentation; D09–D10 do not inject future chapter prerequisites.

Phase-10 paper result by chapter:
- C01–C08: linear/fundamental onboarding set is sufficient when mapped explicitly.
- C09–C16: contamination, Filter, Silt Grazer, Baffle, growth must all be ancestry-covered before C16 capstone.
- C17–C24: Cradle Moss, Feed Cartridge, Nest Pad, Vibration, lifecycle/growth must be ancestry-covered before C24.
- C25–C32: directed overlay, Brownout, power priority, composite social hazards before C32.
- C33–C40: Monitor introduction and discovery semantics before bounded unknown milestone C40.
- C41–C48: no new foundational rule; mastery nodes depend on full prior foundation, with Splitcap/Constricted Vault/Thermal Gradient/Oscillation introduced before any later node assuming them.

Repair: exact per-node edge table must be frozen in Phase 11 as data-level acceptance criteria; current chapter sequence alone is insufficient to implement branching without invention.

Verdict: **REPAIRED, PHASE-11 DETAIL REQUIRED**.

---

# 11. 22-species redundancy / readability attack

The roster is attacked by role, not merely by trait count.

## Simple foundations that remain necessary
- O01 Ember Pod — source + stress-cascade teacher; unique foundation identity.
- O02 Hushling — fragile one-target social stabilizer; required benchmark helper.
- O04 Spore Bell — contamination source/pulse; required contamination cascade identity.
- O10 Frost Finch — pure heat sink; required simple comparison against Cooler.
- O14 Mire Sipper — pure contamination sink; required simple comparison against Filter.

Verdict: **RETAIN**.

## Lifecycle/spatial differentiators
- O03 Silt Grazer — filtering feeds growth; dynamic topology.
- O08 Glass Larva — feeding causes Corner growth; future footprint different from O03.
- O13 Cinder Snail — heat-driven Bar growth; thermal timing/spatial pressure.
- O18 Spindle Bloom — contamination-driven growth + expanded spore source.
- O21 Pale Drifter — sleep/wake timed cleansing pulse; discovery/information role.
- O22 Splitcap — mastery composite filtering -> growth -> social risk.

These are non-redundant only if timing/footprint changes are materially used. O22 is intentionally late and excluded from low-tier generation.

Verdict: **RETAIN WITH COMPLEXITY GATE**.

## Social/support substitutes with potential redundancy
- O06 Cradle Moss — soother + food producer, state-coupled double benefit.
- O12 Velvet Nurse — soother + one-target contamination buffer, larger footprint.
- O16 Moth Cushion — broad footprint soother with sleep vulnerability.
- O05 Warmback — harmful heat + protective buffer.
- O19 Amber Leech — feeding dependency + protection link.
- O20 Whistle Crab — protector that becomes social hazard.

Attack: these can blur into “helper creature with downside.”

Repair: Phase-11 content acceptance table must show for each a **unique decision sentence** that cannot describe another species:
- O06: keep one organism awake/calm because two benefits disappear together;
- O12: spend a larger body footprint for targeted welfare+buffering;
- O16: broad-body soothing whose sleep timing can intentionally remove coverage;
- O05: accept continuous heat to gain narrow contamination protection;
- O19: protection is inseparable from food consumption/competition;
- O20: protector's own stress converts protection placement into alarm risk.

If playtest or implementation data makes two of these play identically across representative contracts, cut/merge one rather than adding a new trait.

Verdict: **PROTOTYPE CONTENT GATE**.

## Composite sinks/hazards
- O07 Pulse Mite — stress -> one-time heat cascade.
- O09 Ash Sponge — heat+contam sink -> delayed social cost.
- O11 Rattle Reed — directed alarm/orientation.
- O15 Lantern Tick — recovery pulse creates timed food.
- O17 Coal Urchin — heat sink becomes alarm liability.

These remain distinct if their state timing is clearly animated and causal review shows their conversion relationship.

Verdict: **RETAIN**.

## Three-trait readability ceiling
O09 and O22 use three mechanically significant traits. No launch species may exceed three. Three-trait species must:
1. enter only after all component families are separately learned;
2. have one sentence explaining its combined role;
3. use visible state gating so the player does not track three unrelated always-on exceptions;
4. remain excluded from first-contact discovery.

Verdict: **PASS + HARD CEILING**.

---

# 12. Generated challenge attacks

## G01 — Static-solvable output
Severity: **CRITICAL**

Existing Stage 6 rejection remains mandatory. Add validation metric: at least one certified Bronze solution must experience a decision-relevant dynamic event and changing the timing of that event inside template-safe bounds must alter solution quality or required arrangement.

Verdict: **REPAIRED**.

## G02 — Duplicate fingerprints just below 0.80
Severity: **HIGH**

Attack: generator varies one irrelevant dimension to evade similarity threshold.

Repair: similarity uses weighted dimensions; pressure channels, key lifecycle relation, canonical zone allocation, optimal support family, and hazard order weigh more than cosmetic species IDs. A challenge with high semantic-role similarity is rejected/down-ranked even if raw numeric fingerprint is below 0.80. Threshold is a floor, not a loophole.

Verdict: **REPAIRED**.

## G03 — Dominant support streak
Severity: **HIGH**

Existing rule: same powered-support pair optimal >3 consecutive surfaced challenges is rejected/down-ranked. Strengthen: track support **strategy family**, including living substitute + support combinations, so swapping Frost Finch for Cooler does not falsely count as variety when the causal strategy is identical.

Verdict: **REPAIRED**.

## G04 — Opaque causal chain
Severity: **HIGH**

Existing <=6 major links below Tier 6 and <=8 Tier 6 remains. Add: no generated Bronze may require remembering more than two hidden/scheduled state transitions simultaneously; no discovery generator may combine two undocumented mechanics.

Verdict: **PASS + CLARIFIED**.

## G05 — Solver timeout / false certification
Severity: **CRITICAL**

Repair:
- `timeout` is never `solvable`; only an explicit certified layout or known-valid source construction can prove Bronze;
- if Silver/Gold proof times out, omit that medal set or reject challenge; never surface an unproven objective;
- solver and authoritative simulator must share the same kernel; no simplified solver physics/rules may certify gameplay unless every abstraction is proven conservative and tested;
- validation record stores exact committed certified solution fingerprint + checksum sequence in QA data.

Verdict: **REPAIRED**.

## G06 — Cosmetic reskin sameness
Severity: **HIGH**

Attack: species names/colors change but role histogram and causal solution remain identical.

Repair: anti-template fingerprint is role/mechanic based. Cosmetic variants are ignored by diversity scoring. Challenge is considered equivalent if normalized role graph + hold/hazard/support strategy is equivalent within threshold.

Verdict: **REPAIRED**.

## G07 — Generator runtime scope explosion
Severity: **HIGH**

Attack: trying to prove two solution families for every high-tier seed creates unacceptable CPU stalls.

Repair: generator may preserve known-valid source layouts and perform bounded mutation. Two-family proof is a target `where tractable`, not a requirement that can freeze runtime. If second-family search exceeds budget, candidate may still surface only when its template is authored to allow one strong solution family and passes anti-degeneracy; otherwise reject and generate another seed. Never block UI waiting for unbounded exhaustive search.

Verdict: **REPAIRED**.

---

# 13. Demo-positioning attack

Severity: **CRITICAL commercial/product identity risk**.

Attack: player finishes demo believing the game is “cute packing with adjacency rules,” then full game appears to change genre.

Repair/gate:
1. dynamic transit consequence must appear within the first **10–15 minutes** for a normal new player;
2. by D04/C04-equivalent teaching, at least one route/state change must alter a trait or relationship after launch;
3. demo climax must include growth timing + route hazard + support tradeoff as already intended;
4. at least **5 of the 10 demo contracts**, excluding pure onboarding, must have a decisive Bronze/medal interaction that cannot be explained as static packing alone;
5. store capsule/screenshots may show packing, but trailer/video/gif set must include before/after transit state change and at least one causal cascade;
6. feedback prompt during demo playtest: `What is the main thing you are planning for?` A majority answer centered on `what happens during transit / creatures changing` is a prototype marketing gate.

Verdict: **REPAIRED + PROTOTYPE GATE**.

---

# 14. Technical scope attack

## T01 — Causal Review becomes a second giant product
Severity: **HIGH**

Repair: ship only the required review primitives already supported by structured events: timeline, decisive chain, focus filter, cause/root jump, start/final compare, medal breakdown. No freeform graph editor, statistical dashboard, or arbitrary query language.

Verdict: **PASS WITH SCOPE CAP**.

## T02 — Solver/generator becomes research project
Severity: **CRITICAL scope risk**

Repair: launch generator uses authored hold layouts, bounded template pools, known-valid construction + bounded mutation, and authoritative kernel certification. No arbitrary topology generation, no requirement for optimal exhaustive search, no ML solver, no live backend.

Verdict: **PASS WITH SCOPE CAP**.

## T03 — Save migration consumes disproportionate development
Severity: **HIGH**

Repair: support a small explicit migration chain and safe fallback; do not promise arbitrary historical in-progress transit preservation across rule-changing versions. Permanent campaign clears/knowledge/best medals are more important than exact legacy mid-transit reconstruction.

Verdict: **REPAIRED**.

## T04 — Localization + dynamic causal text explodes
Severity: **HIGH**

Repair: event records use fixed localization templates with structured named parameters; no concatenated sentence fragments. Species/trait/support data stores keys. Review vocabulary remains intentionally small.

Verdict: **PASS**.

## T05 — Animation/event synchronization changes authority
Severity: **CRITICAL**

Repair: sim resolves authoritative tick/event package independently; animation consumes package. Skipping, reduced motion, 0.5x/4x, frame drops, or audio failure cannot delay phase authority. Presentation cursor and authoritative result are separate.

Verdict: **PASS**.

## T06 — Content tooling becomes mandatory editor suite
Severity: **MEDIUM/HIGH**

Repair: canonical content is JSON + validators + batch simulator. A custom visual editor is optional productivity work, not a launch dependency. Do not block vertical slice on bespoke tooling UI.

Verdict: **REPAIRED**.

Overall technical-scope verdict: **PASS** within the compact production ceiling, provided generator remains bounded and Causal Review stays a focused diagnostic surface.

---

# 15. Programmer-facing ambiguity ledger

These are the questions Phase 10 found that would otherwise force a programmer to invent gameplay behavior. Clear answers are now canonical.

1. **Blocked growth repeated every tick?** No. One consequence per unchanged growth episode; re-attempt only on legality change or condition reset/re-entry.
2. **Does sleep implicitly disable traits?** No. Only explicit state gates disable/modify traits.
3. **Brownout support output on the brownout tick?** Phase A decides power first; off means no Phase-C output that tick.
4. **Multiple simultaneous causes?** Preserve multi-parent causal roots; do not choose one arbitrarily.
5. **Delayed event ancestry?** Scheduled events retain origin event/rule IDs.
6. **Launch spam?** Single transition token; one immutable commit per accepted confirm.
7. **Results progression write count?** Exactly once/idempotent set/max update at Results finalization.
8. **Abort discovery run erases player knowledge?** No; observed information cannot be unlearned, but formal codex/progression unlock follows canonical evidence/finalization rules.
9. **Solver timeout means success?** Never.
10. **Legacy incompatible transit resume?** Do not pretend equivalence; recover to safe Planning/current rules while preserving permanent progress.
11. **Primary+backup corruption?** No silent reset; recovery UI/new profile/cloud option if available.
12. **Keyboard-only mandatory?** Yes, via semantic logical focus paths.
13. **Global empty-space score?** No.
14. **Unlimited transition-triggered T10 effects?** No; every reactive effect has explicit finite event guard.
15. **Monitor required for Bronze discovery?** No.
16. **Static tutorial exception scope?** Only earliest onboarding; non-tutorial dynamic gates apply from early campaign onward.

Remaining implementation-flexible items that do **not** require inventing gameplay rules:
- exact UI pixel dimensions after responsive-layout testing;
- final balanced integer magnitudes within existing bands;
- final animation duration/easing;
- exact commercial title;
- final flavor copy and localization wording;
- whether optional custom content editor is built.

---

# 16. Phase-10 pass/fail checklist

- [x] Fundamental loop attacked for staticness, random retry, arithmetic, review fatigue, planning duration.
- [x] Edge isolation / spacing / emitter-edge / growth-corner / zone-template attacks constructed.
- [x] Cooler+Filter, Baffle+soother, Nest Pad, Monitor, and living-substitute support dominance attacked.
- [x] Welfare-hostile, delay, event-count, support-spam, empty-space, and state-transition scoring exploits attacked.
- [x] Simultaneous thresholds, multiple roots, delayed T10, brownout, blocked growth, contamination ancestry, and grouped propagation attacked.
- [x] Launch/cancel/undo/reset/retry/abort/settings/quit authority boundaries attacked.
- [x] Atomic write, backup recovery, double corruption, legacy version, cloud divergence, demo import, checksum mismatch attacked.
- [x] High UI scale, Deck-like resolution, reduced motion/flashing, no audio, non-color reading, controller-only, keyboard-only, remap context attacked.
- [x] Campaign prerequisite coverage rules attacked across all six chapters.
- [x] All 22 species reviewed for role overlap and 3-trait readability risk.
- [x] Generator attacked for staticness, near-duplicate fingerprints, support streaks, opacity, timeout certification, cosmetic sameness, runtime scope.
- [x] Demo identity attacked with quantitative dynamic-transit gate.
- [x] Technical production ceiling attacked.
- [x] Programmer-facing ambiguity ledger produced.
- [x] All clear high/critical paper issues repaired canonically.
- [x] Prototype-dependent uncertainty separated from paper-resolvable ambiguity.

**Phase-10 paper verdict: PASS WITH PROTOTYPE GATES.**

No paper attack currently requires abandoning Organism Cargo or adding a new foundation mechanic. The biggest remaining risks are empirical fun/readability risks, not undefined rules.

---

# 17. Explicit prototype-dependent risks — not design ambiguities

These must remain visible after specification freeze and become vertical-slice kill/pass metrics; they are not excuses to keep inventing design indefinitely.

## PG1 — Hypothesis-driven retry
Target: >=70% of failed validation shipments lead to a tester explaining a cause and naming a specific revision rather than random shuffling.

## PG2 — Transit significance
Target: at least half of interesting failures/memorable outcomes in the validation set depend on a post-launch state change; static inspection must not solve most contracts.

## PG3 — Planning duration
Normal non-mastery contracts should not routinely produce >8 minute median first-launch planning after rule familiarity.

## PG4 — Helper-species differentiation
O06/O12/O16 and O05/O19/O20 must produce recognizably different decisions in representative contracts; if pairs feel interchangeable, cut/merge content rather than add traits.

## PG5 — Demo positioning
Most demo testers should describe the central task as predicting what living cargo will do during transit, not arranging a tidy grid.

## PG6 — Review usefulness
After failure, decisive-chain review should let intended players locate the first actionable cause quickly without opening the raw event log.

These gates belong to implementation validation after `DESIGN COMPLETE`; failing them may reopen design with evidence.

---

# 18. Exact Phase-11 specification-freeze work list

Phase 11 must not invent new features. It must consolidate, reconcile, and freeze.

1. Fold every Phase-9 repair from `WHOLE_GAME_SIMULATION.md` into the authoritative source files.
2. Fold every Phase-10 repair from this file into `MECHANICS.md`, `DECISION_ARCHITECTURE.md`, `CONTENT_ARCHITECTURE.md`, `UX_ARCHITECTURE.md`, `ECONOMY_COMMERCIAL.md`, and `TECHNICAL_SPEC.md` where each rule belongs.
3. Replace stale `TBD` sections in `GAME_BIBLE.md` with references/summaries of the now-locked canonical specifications.
4. Freeze exact campaign prerequisite edge data for C01–C48 or an implementation-ready complete edge table/validator contract so programmers do not invent branch logic.
5. Freeze a support non-dominance acceptance matrix covering S01–S06, living substitutes, and representative authored contracts.
6. Freeze the 22-species unique-decision table and mark any intentional prototype kill/merge gates without changing launch roster unless paper contradiction exists.
7. Freeze dynamic-transit quotas/gates for authored campaign, demo, and generated challenges.
8. Freeze all T10 event-guard semantics and blocked-growth episode semantics in mechanical schemas.
9. Freeze result/progression idempotency, save-recovery states, incompatible-version fallback, and demo-migration tests in technical acceptance criteria.
10. Freeze accessibility acceptance matrix for mouse, keyboard-only, controller-only, reduced motion/flashing, no audio, non-color cues, 1280x720 + high UI scale.
11. Produce a unified acceptance-test index linking each major gameplay rule to at least one deterministic test case.
12. Run contradiction search across every canonical file for old demo counts, old transfer wording, stale transit-resume wording, stale gamepad priority language, or pre-repair blocked-growth behavior.
13. Mark prototype-dependent gates explicitly as empirical validation obligations, not unresolved specification questions.
14. Confirm there are no remaining programmer-facing gameplay questions that require invention.
15. Set `DESIGN COMPLETE = YES` only if all above pass and `GAME_BIBLE.md` is implementation-ready as the top-level contract.

Do not start production code until Phase 11 has completed this freeze.
