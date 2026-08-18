# ORGANISM CARGO — PHASE 11 CONSOLIDATION PASS 5

Status: **SOURCE-FOLD-IN AUDIT COMPLETE / DIRECT EDIT QUEUE FROZEN**
Last updated: 2026-08-15
Production code started: **NO**

Purpose: convert the last Phase-11 reconciliation work into a finite direct-edit queue and a final-sweep classification. This file adds no gameplay. It records exactly what must be changed in the older canonical/history files before `DESIGN COMPLETE` may become `YES`.

---

# 1. Result of this pass

The design itself is no longer missing a game rule. The remaining blockers are stale authority wording in older source files and proof that no implementation-sensitive placeholder survives outside the final authority chain.

Fresh repository searches in this run found no indexed `TBD` or `TODO` hits. The previously known obsolete demo phrase `8 documented + 2 discovery` also produced no indexed code-search hit. These search results are supporting evidence only: they do not replace direct inspection of the known stale files.

The critical stale wording that was directly re-observed is in `UX_ARCHITECTURE.md` §2.2: it still says transit resume may depend on whether persistence supports a paused state or whether Phase 8 chooses snapshot-only persistence. That choice is no longer open. `PHASE11_TECH_PERSISTENCE.md` froze deterministic reconstruction from committed input/seed/version/checksum plus saved presentation cursor/recovery metadata; a platform/runtime snapshot is never sole authority.

`WHOLE_GAME_SIMULATION.md` and `ADVERSARIAL_REVIEW.md` also still describe their repairs as canonical until future fold-in. Phase 11 has now superseded that transitional wording: both are validation history whenever a later canonical home exists.

---

# 2. Frozen direct-edit queue

The next source-edit pass must make the following exact semantic changes. No reinterpretation is allowed.

## 2.1 `TECHNICAL_SPEC.md`

Header/authority note must explicitly name `PHASE11_TECH_PERSISTENCE.md` as the final authority for:
- exactly-once Launch transition;
- idempotent completion/progression application;
- deterministic transit reconstruction/resume;
- atomic persistence/recovery semantics;
- authority of committed input + content/rules version + seed/checksum over runtime snapshots.

If any older paragraph implies a runtime snapshot can be the only authoritative resume source, replace it with the frozen reconstruction contract.

## 2.2 `UX_ARCHITECTURE.md`

Header/authority note must explicitly name `PHASE11_UX_ACCESSIBILITY.md` for mandatory keyboard-only, controller-only, Steam Deck/1280×800, remapping, non-color, non-audio and precision-independent acceptance rules.

Replace the stale Main Menu / Continue sentence with this semantic contract:

> If the player quit during transit, Continue restores the same committed run by deterministic reconstruction from the authoritative committed input and saved recovery cursor/metadata, then returns to paused playback at the recovered presentation position. A platform/runtime snapshot may accelerate recovery but is never the sole source of gameplay truth.

Remove any implication that controller support is optional or merely “where practical” for required gameplay actions. Required gameplay paths must satisfy the Phase-11 input/accessibility acceptance suite.

## 2.3 `ECONOMY_COMMERCIAL.md`

Header/authority note must explicitly name `PHASE11_PROGRESSION.md` as the final authority for:
- exact campaign unlock semantics;
- Challenge-mode gate;
- demo-to-full migration/mapping;
- knowledge transfer versus progression transfer;
- medal/non-medal progression separation.

Any vague dependency language such as “later progression decision”, “normal gate”, or implementation-selected dependency must be replaced by the exact frozen progression rule. Campaign prerequisites are Bronze-only according to the exact 48-node graph. Imported demo knowledge never bypasses the canonical Challenge gate.

## 2.4 `WHOLE_GAME_SIMULATION.md`

Change status/authority language from independent canonical repair authority to **Phase-9 validation history** once a later canonical home exists.

Its authority paragraph must state that Phase-11 canonical sources supersede its repaired wording in implementation-sensitive conflicts.

Any blocked-growth example that can be read as repeated per-tick stress/damage for the same unchanged obstruction must be rewritten to the episode rule:
- first illegal growth attempt begins/continues one `GROWTH_BLOCKED` episode;
- consequence fires once for that unchanged episode;
- subsequent unchanged blocked ticks do not repeat punishment;
- a new consequence requires a relevant legality/body/trigger/retry-boundary change.

## 2.5 `ADVERSARIAL_REVIEW.md`

Change authority language to **Phase-10 validation history** for repairs already folded into `GAME_BIBLE.md`, `PHASE11_FREEZE.md`, `MECHANICS.md`, `DECISION_ARCHITECTURE.md`, `CONTENT_ARCHITECTURE.md`, `PHASE11_TECH_PERSISTENCE.md`, `PHASE11_UX_ACCESSIBILITY.md`, `PHASE11_PROGRESSION.md`, `TECHNICAL_SPEC.md`, `UX_ARCHITECTURE.md` or `ECONOMY_COMMERCIAL.md`.

Prototype gates remain valid empirical obligations; they are not superseded merely because the design rule around them is frozen.

## 2.6 `PHASE11_FREEZE.md`

Update status from the old early-consolidation wording to a final-consolidation state.

Replace its transitional authority order with the final precedence used by `STATUS.md`:
1. `GAME_BIBLE.md`;
2. `PHASE11_FREEZE.md`;
3. `PHASE11_TECH_PERSISTENCE.md`;
4. `PHASE11_UX_ACCESSIBILITY.md`;
5. `PHASE11_PROGRESSION.md`;
6. domain canonical files (`MECHANICS.md`, `DECISION_ARCHITECTURE.md`, `CONTENT_ARCHITECTURE.md`, `TECHNICAL_SPEC.md`, `UX_ARCHITECTURE.md`, `ECONOMY_COMMERCIAL.md`);
7. `PHASE4_CLOSURE.md` as mechanical validation evidence;
8. `WHOLE_GAME_SIMULATION.md` and `ADVERSARIAL_REVIEW.md` as validation history;
9. selection/research files as history only.

Remove wording that says Phase-9/10 can still win merely because a repair has not yet been folded in. Phase 11 has already supplied the final canonical homes.

---

# 3. Final stale-term classification

The final repository sweep must classify hits, not blindly delete words.

## Category A — forbidden unresolved implementation choice
Must be zero in canonical implementation-authority contexts:
- `TBD` / `TODO` for gameplay, progression, state, persistence, accessibility, content counts or acceptance behavior;
- `to be decided` / `future work` when it delegates a required design choice to the implementer;
- optional-controller wording for mandatory gameplay;
- snapshot-only authority;
- non-idempotent completion/results wording;
- Challenge progression described by an unfrozen shorthand rather than the canonical gate;
- campaign dependencies described vaguely instead of the exact graph;
- obsolete demo counts/mapping;
- repeated unchanged blocked-growth punishment;
- a universal “maximize empty space” or permanent growth-corner strategy implied as canonical.

Any Category-A hit blocks `DESIGN COMPLETE` until repaired.

## Category B — intentional validation history
Allowed only when the file is explicitly marked historical/validation evidence and later authority is named:
- old candidate scores and selection hypotheses;
- Phase-9/10 attack descriptions;
- superseded alternatives preserved to explain why a repair was made.

Historical wording must not present itself as current implementation authority.

## Category C — empirical prototype gate
Allowed and required. These are not missing design:
- >=70% causal-hypothesis/revision validation target after representative failures;
- >=50% memorable/interesting outcomes depending on post-launch change;
- normal non-mastery median first-launch planning target <=8 minutes after familiarity;
- helper/protector redundancy tests;
- demo identity recall test;
- Causal Review first-cause usability test.

A prototype can fail these gates and cause later redesign; their existence does not prevent specification freeze.

## Category D — harmless implementation flexibility
Allowed only when gameplay truth is unchanged, for example:
- commercial title;
- cosmetic timing/easing;
- non-authoritative animation implementation;
- internal class/module organization below the frozen architectural boundaries;
- optional performance optimizations that preserve deterministic checksums and acceptance tests.

---

# 4. Fresh-session implementation-readiness checklist

Before setting `DESIGN COMPLETE = YES`, a fresh builder must be able to answer all of the following without inventing design:

1. What does the player do from first boot through C48 and Challenge mode?
2. What exact state transition owns Launch and how is double-launch prevented?
3. What data uniquely defines an authoritative transit?
4. How is a transit resumed after interruption without trusting a runtime snapshot?
5. How are Results/progression writes made exactly once?
6. What are the authoritative tick phases and same-tick power/Brownout rules?
7. How are simultaneous material causes represented?
8. What happens when the same growth remains blocked for multiple ticks?
9. Which traits are suppressed by sleep and which are not?
10. What exact graph unlocks C01–C48?
11. What unlocks Challenge mode?
12. What demo progress/knowledge transfers and what cannot auto-unlock?
13. What are the launch species/support/content ceilings and redundancy gates?
14. How does a generated challenge prove validity and dynamic significance?
15. What prevents Cooler+Filter, maximum spacing, one universal protector or permanent growth-corner templates from dominating?
16. What keyboard-only/controller-only/Deck paths are mandatory?
17. Which game-critical information has non-color and non-audio equivalents?
18. What exactly must Causal Review show about first cause and ancestry?
19. What is saved, when, with what atomic/recovery contract?
20. Which remaining uncertainties are empirical prototype gates rather than undefined game rules?

Current Phase-11 supplements provide deterministic answers to all 20. The remaining proof obligation is editorial/direct-source consistency so a builder cannot encounter an older canonical-looking sentence that contradicts those answers.

---

# 5. Gate decision

**Do not set `DESIGN COMPLETE = YES` in this pass.**

Reason: the final design contract is substantively closed, but the known stale source wording has not yet been directly rewritten in all six named files. The user explicitly defined completion as the whole game being fully described, and `STATUS.md` explicitly requires the direct-source/final-sweep proof before specification freeze.

Next pass is mechanical editorial reconciliation, not new design.