# ORGANISM CARGO — PHASE 11 CONSOLIDATION PASS 6

Status: **FINAL CONTRADICTION / READINESS AUDIT COMPLETE — DIRECT SOURCE FOLD-IN STILL REQUIRED**
Last updated: 2026-08-15
Production code started: **NO**

Purpose: execute the final semantic contradiction proof requested by `STATUS.md` after the Phase-11 supplements were frozen, re-read the full authority chain, classify the remaining stale statements, and prove whether any actual gameplay-design decision is still missing.

This pass adds no gameplay mechanic.

---

# 1. Files re-read in this pass

Authority and recovery chain inspected:
- `START_HERE.md`
- `STATUS.md`
- `GAME_BIBLE.md`
- `PHASE11_FREEZE.md`
- `MECHANICS.md`
- `DECISION_ARCHITECTURE.md`
- `CONTENT_ARCHITECTURE.md`
- `PHASE11_TECH_PERSISTENCE.md`
- `PHASE11_UX_ACCESSIBILITY.md`
- `PHASE11_PROGRESSION.md`
- `PHASE11_CONSOLIDATION_PASS5.md`
- `TECHNICAL_SPEC.md`
- `UX_ARCHITECTURE.md`
- `ECONOMY_COMMERCIAL.md`
- `PHASE11_HISTORY_RECONCILIATION.md`
- `WHOLE_GAME_SIMULATION.md`
- `ADVERSARIAL_REVIEW.md`
- `PHASE4_CLOSURE.md`
- `CROSS_ROUND_FINAL.md`
- `RESEARCH.md`
- `TOURNAMENT.md`
- `TOURNAMENT_ROUND2.md`

Selection-history files were treated as history only. They were checked to ensure that no obsolete pre-lock concept rule is being accidentally elevated above the Organism Cargo canonical set.

---

# 2. Final semantic contradiction findings

## 2.1 Technical persistence

`TECHNICAL_SPEC.md` already contains the core reconstruction rule in §10.5: transit is reconstructed from immutable committed input rather than serializing mutable mid-phase simulation internals. It also persists seed/rules/content/generator versions, uses checksum validation, atomic saves, backups and explicit recovery.

`PHASE11_TECH_PERSISTENCE.md` is nevertheless still required as the more specific Phase-11 authority because it additionally freezes:
- one durable `run_id` per launch commit;
- double-launch rejection/idempotency;
- deterministic `completion_id`;
- exactly-once progression application;
- crash boundaries around launch/results transactions;
- cloud/profile monotonic merge behavior;
- active-session non-merge behavior;
- legacy compatibility failure behavior;
- idempotent demo import.

No gameplay decision is missing here. Remaining task is authority/header fold-in so a builder cannot mistake Phase-8 wording for the final transaction contract.

## 2.2 UX transit resume

A concrete stale Category-A statement still exists in `UX_ARCHITECTURE.md` §2.2. It says Continue may return to a persisted transit state “if persistence supports that state” and otherwise reconstruct if Phase 8 chooses snapshot-only persistence.

That choice is no longer open.

Final semantic contract:
- authoritative truth = immutable committed input + run identity + compatible content/rules/generator versions + checksums;
- resume reconstructs transit deterministically;
- saved presentation tick/cursor is non-authoritative recovery metadata;
- runtime/platform snapshot may accelerate presentation recovery but is never the sole gameplay authority.

This stale sentence must be directly replaced before freeze.

## 2.3 UX mandatory input/accessibility

`UX_ARCHITECTURE.md` still contains older language such as “all shortcuts must be remappable where practical” and a mouse-first framing that predates the Phase-11 mandatory parity contract.

Final rule is not optional:
- mouse+keyboard complete path;
- keyboard-only complete path;
- controller-only complete path;
- Steam Deck built-in controls at 1280x800 complete path;
- gameplay remapping;
- no hover/right-click/wheel/drag-only mandatory action;
- no-audio completion;
- non-color-only critical information;
- Reduced Motion and Reduced Flashing preservation of all required cues;
- maximum UI-scale reachability.

No design choice is missing. Direct wording fold-in is still required.

## 2.4 Campaign graph and Challenge gate

`ECONOMY_COMMERCIAL.md` §6.1 still says exact authored dependencies are content data and §6.5 describes Challenge mode as unlocking after the Tier-2 capstone / roughly the first 16 contracts.

Those phrases are now shorthand only.

Final exact implementation rule:
- campaign prerequisite graph = the exact C01–C48 Bronze-only graph frozen in `PHASE11_FREEZE.md` and mirrored in `CONTENT_ARCHITECTURE.md`;
- `ChallengeModeUnlocked := Bronze(C16) == true`;
- Silver/Gold, documented knowledge, D09/D10, achievements, clear-count totals, XP/currency and challenge results do not substitute for C16;
- individual challenge templates may additionally require already-documented rule families after the mode itself is unlocked.

No design choice is missing. Direct source fold-in is still required.

## 2.5 Demo transfer

The canonical mapping is consistent across the final sources:
- 10 demo species = 9 documented + 1 bounded-discovery;
- D01–D08 may map to C01–C08 Bronze through validated version mapping;
- D09–D10 never auto-clear C09+;
- settings and valid documented knowledge may transfer;
- no mechanical power transfers;
- imported knowledge cannot bypass the C16 Challenge gate;
- import is monotonic and idempotent.

No remaining semantic contradiction was found in the final canonical chain.

## 2.6 Blocked growth

`WHOLE_GAME_SIMULATION.md` Representative Contract B still narrates:
`GROWTH_BLOCKED is recorded and stress increases; repeated pressure pushes Grazer...`

This is historically understandable but implementation-dangerous because it can be read as repeated punishment from the unchanged same obstruction.

Final rule:
- the first illegal attempt begins one `GROWTH_BLOCKED` episode;
- the configured consequence fires once on episode entry;
- unchanged blocked ticks do not repeat that consequence;
- later stress can still rise from independent continuing sources;
- a new blocked-growth consequence requires a relevant legality/occupancy/orientation/body/trigger/retry-boundary change.

`MECHANICS.md`, `PHASE11_FREEZE.md`, `PHASE4_CLOSURE.md` and `PHASE11_HISTORY_RECONCILIATION.md` already agree. The historical example must be directly rewritten.

## 2.7 Phase-9/10 authority status

`WHOLE_GAME_SIMULATION.md` still labels itself canonical Phase 9 and says its ambiguity repairs are canonical until folded in.

`ADVERSARIAL_REVIEW.md` still labels itself canonical Phase 10 and says its repairs become canonical until Phase-11 fold-in.

Phase 11 has already created the final homes. Therefore both files must now be labelled validation history in implementation-sensitive conflicts.

Their empirical prototype gates remain active obligations and are not deleted:
- >=70% failed validation cases should produce a specific causal explanation + intended revision rather than blind shuffle;
- >=50% memorable/interesting validation outcomes depend on post-launch state change;
- ordinary non-mastery first-launch planning median <=8 minutes after rule familiarity;
- helper/protector redundancy tests;
- demo identity recall test;
- Causal Review actionable-first-cause usability gate.

## 2.8 Phase-11 freeze header/precedence

`PHASE11_FREEZE.md` still says `CONSOLIDATION PASS 1 COMPLETE` and retains transitional wording where Phase-9/10 repairs can win until source fold-in.

Final precedence must be:
1. `GAME_BIBLE.md`;
2. `PHASE11_FREEZE.md`;
3. `PHASE11_TECH_PERSISTENCE.md`;
4. `PHASE11_UX_ACCESSIBILITY.md`;
5. `PHASE11_PROGRESSION.md`;
6. domain canon: `MECHANICS.md`, `DECISION_ARCHITECTURE.md`, `CONTENT_ARCHITECTURE.md`, `TECHNICAL_SPEC.md`, `UX_ARCHITECTURE.md`, `ECONOMY_COMMERCIAL.md`;
7. `PHASE4_CLOSURE.md` as mechanical validation evidence;
8. `WHOLE_GAME_SIMULATION.md`, `ADVERSARIAL_REVIEW.md` as validation history;
9. selection/research files as history only.

No Phase-9/10 historical sentence may outrank an existing Phase-11 canonical home.

---

# 3. Category-A repository scan

Fresh connector-backed indexed searches were repeated for:
- `TBD`;
- `TODO`;
- `to be decided`;
- `future work`;
- snapshot-only wording;
- optional-controller wording;
- vague Challenge-gate wording;
- repeated blocked-growth shorthand.

Indexed search returned no reliable hits. Direct file inspection is therefore the authority for known stale statements; code-search indexing is incomplete for this repository and cannot be used as the sole freeze proof.

Known direct-inspection Category-A stale statements remain exactly the finite classes listed in §2.2, §2.3, §2.4 and §2.6. No new gameplay-rule gap was discovered.

---

# 4. Fresh-session 20-question implementation-readiness proof

A fresh builder can answer all 20 questions without inventing gameplay, provided they follow the Phase-11 authority chain rather than stale historical wording.

1. **First boot -> C48 -> Challenges:** exact player journey exists; campaign is 48 nodes, Bronze-only graph; Challenge mode after Bronze(C16).
2. **Launch ownership:** application state machine owns exactly-once Launch transaction; duplicate requests return/reuse existing committed run rather than creating another.
3. **Authoritative transit identity:** committed input + stable run ID + contract/route/layout/support config + seed + rules/content/generator versions + checksums.
4. **Resume:** deterministic replay from committed input; presentation cursor restored afterward; runtime snapshot not sole authority.
5. **Results idempotency:** deterministic completion ID + durable applied-completion ledger / equivalent monotonic transaction.
6. **Tick/Brownout:** A–I phase order; Brownout finalized Phase A before powered-support effects.
7. **Simultaneous causes:** causal events preserve all material parent IDs/root ancestry.
8. **Blocked growth:** one consequence per unchanged blocked episode; new consequence only after relevant change/retry boundary.
9. **Sleep:** only explicitly sleep-gated traits are suppressed.
10. **Campaign graph:** exact C01–C48 prerequisite table in freeze/content docs.
11. **Challenge mode:** exact condition Bronze(C16).
12. **Demo transfer:** D01–D08 mapping only; D09/D10 do not clear C09+; knowledge/settings may transfer; no power; no early Challenge unlock.
13. **Content ceilings:** 22 launch species maximum before cuts, 6 supports, 48 authored contracts, 12 authored hold layouts/5 families, 7 hazard/profile families, 18 authored routes target, 24 challenge templates; redundancy gates may reduce species count.
14. **Generated challenge validity:** known-valid/certified Bronze source, deterministic validation, post-launch significance, documented-tier compliance, bounded opacity, anti-sameness checks.
15. **Anti-dominance:** explicit authored/generator gates against Cooler+Filter, maximum spacing, universal helper/protector, permanent growth corner and repeated role-zone templates.
16. **Input paths:** mouse+keyboard, keyboard-only, controller-only, Steam Deck 1280x800 all mandatory.
17. **Non-color/non-audio:** critical information has shape/icon/pattern/text and visual/caption equivalents; game completable at master volume 0.
18. **Causal Review:** failed predicate -> earliest actionable/direct cause -> parent/root ancestry -> start/final compare -> targeted Retry.
19. **Persistence:** separate profile/session/settings, atomic temp/verify/backup/replace, corruption recovery, versioned migration, reconstruction, cloud monotonic profile merge and no divergent active-session merge.
20. **Remaining uncertainty:** only empirical prototype gates and harmless implementation flexibility; no unresolved gameplay rule was found.

Readiness result: **20/20 deterministic at the semantic level.**

Important: this is not yet sufficient to set `DESIGN COMPLETE = YES` because old source files still present themselves as canonical and contain known stale sentences. Editorial contradiction is still an implementation-risk contradiction until removed.

---

# 5. Freeze decision

**DESIGN COMPLETE remains NO.**

The actual game design is substantively closed. The only remaining design-freeze blockers are direct source reconciliation and a post-edit verification pass:

1. `TECHNICAL_SPEC.md` — add explicit Phase-11 persistence authority note;
2. `UX_ARCHITECTURE.md` — replace transit-resume ambiguity and mandatory-input/remapping ambiguity;
3. `ECONOMY_COMMERCIAL.md` — replace vague graph/Challenge wording with exact Phase-11 progression authority;
4. `WHOLE_GAME_SIMULATION.md` — mark Phase-9 validation history and repair blocked-growth narrative;
5. `ADVERSARIAL_REVIEW.md` — mark Phase-10 validation history while retaining empirical gates;
6. `PHASE11_FREEZE.md` — update final status and precedence.

After those six direct edits, repeat the Category-A scan and the 20-question checklist. If no implementation-sensitive contradiction remains, update `GAME_BIBLE.md` and `STATUS.md` to `DESIGN COMPLETE = YES` and specification freeze complete.

---

# 6. No-new-design rule

No new mechanic, species, support, progression currency, channel, hold family, hazard family, campaign node, monetization layer or platform scope may be added during the remaining freeze work.

The next pass is editorial canonicalization only. If a direct edit exposes a genuine unresolved rule, reopen only that exact rule; otherwise do not expand scope.