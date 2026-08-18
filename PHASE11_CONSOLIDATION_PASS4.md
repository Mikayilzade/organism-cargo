# ORGANISM CARGO — PHASE 11 CONSOLIDATION PASS 4

Status: **COMPLETE — AUTHORITY/SWEEP AUDIT SAVED; DIRECT SOURCE FOLD-IN STILL PENDING**
Last updated: 2026-08-15
Production code started: **NO**

Purpose: perform the Phase-11 direct-source/contradiction audit without inventing new gameplay. This pass identifies every known implementation-sensitive stale phrase discovered in the current canonical/history set, fixes authority precedence, and converts remaining work into a finite source-fold-in checklist.

---

# 1. Final authority order during the remaining freeze work

An implementation session must resolve conflicts in this order:

1. `GAME_BIBLE.md` — product thesis, scope, non-negotiable differentiation.
2. `PHASE11_FREEZE.md` — cross-domain frozen rules and acceptance index.
3. `PHASE11_TECH_PERSISTENCE.md` — run identity, exactly-once Launch, idempotent completion, reconstruction, corruption recovery, migration, cloud conflict, legacy challenge and demo-import semantics.
4. `PHASE11_UX_ACCESSIBILITY.md` — mandatory mouse/keyboard/controller/Steam Deck/accessibility acceptance contract.
5. `PHASE11_PROGRESSION.md` — exact campaign prerequisite graph, exact C16 Challenge gate, demo-to-campaign progression mapping.
6. Domain sources: `MECHANICS.md`, `DECISION_ARCHITECTURE.md`, `CONTENT_ARCHITECTURE.md`, `TECHNICAL_SPEC.md`, `UX_ARCHITECTURE.md`, `ECONOMY_COMMERCIAL.md`.
7. `PHASE4_CLOSURE.md` — validation evidence only where it does not contradict later frozen sources.
8. `WHOLE_GAME_SIMULATION.md`, `ADVERSARIAL_REVIEW.md` — validation history only; they no longer outrank a later Phase-11 rule.
9. `CROSS_ROUND_FINAL.md`, `RESEARCH.md`, `TOURNAMENT*.md` — selection/research history only.

A future implementation session is forbidden from choosing between two conflicting old statements by taste. It must follow the above precedence and report any unresolved contradiction back to specification freeze.

---

# 2. Known stale implementation-sensitive wording and canonical replacements

## 2.1 Blocked growth

Historical example in `WHOLE_GAME_SIMULATION.md` says a blocked Silt Grazer receives `repeated pressure` after the initial `GROWTH_BLOCKED` event.

Canonical interpretation:
- one unchanged illegal deterministic growth condition starts one blocked-growth episode;
- the blocked-growth consequence fires once for that episode;
- identical obstruction on later ticks does not repeatedly inflict the same consequence;
- a new consequence is legal only after a relevant condition changes and a genuinely new blocked episode begins;
- later stress may still rise from independent route/organism/support causes.

Authority: `MECHANICS.md` + `PHASE11_FREEZE.md`.

## 2.2 Challenge mode gate

Historical phrases such as `after Tier 2`, `after Chapter-2 capstone`, `approximately after the first 16 contracts`, or `after enough knowledge is documented` are descriptive only.

Exact rule:

`ChallengeModeUnlocked := Bronze(C16) == true`.

No imported knowledge, demo completion, Silver/Gold, achievement, challenge-template knowledge, retry count or other flag substitutes for C16 Bronze.

Authority: `PHASE11_PROGRESSION.md`.

## 2.3 Campaign graph

Historical wording that exact prerequisite edges are merely later `content data` is superseded. The C01–C48 prerequisite table is already frozen and implementation data must match it exactly.

Authority: `PHASE11_FREEZE.md` + `PHASE11_PROGRESSION.md`.

## 2.4 Demo mapping

Exact rule:
- public demo has 10 species total: 9 normally documented + 1 bounded discovery species;
- D01–D08 may map to C01–C08 Bronze only through validated equivalence mapping;
- D09–D10 remain demo-only proof/discovery records and never auto-clear C09+;
- settings and valid knowledge transfer;
- imported knowledge does not grant mechanical power and never bypasses the C16 Challenge gate;
- incompatible mappings fail closed rather than partially skipping campaign teaching.

Any older `8 documented + 2 discovery`, D01–D10 = C01–C10, or vague `full transfer` wording is superseded.

Authority: `PHASE11_PROGRESSION.md` + `PHASE11_TECH_PERSISTENCE.md`.

## 2.5 Transit resume / snapshot authority

Historical conditional wording about whether persistence stores a runtime snapshot is superseded.

Exact rule:
- immutable committed input + rules/content/generator versions + identity/checksum metadata are authoritative;
- a playback cursor is presentation state;
- resume reconstructs deterministic authoritative transit from committed input and verifies compatible identity/checksum state;
- mutable mid-phase engine objects are never the source of truth;
- mismatch follows explicit recovery, never silent continuation under different rules.

Authority: `PHASE11_TECH_PERSISTENCE.md`.

## 2.6 Launch and Results exactly-once semantics

Historical `Launch creates...` and `Results writes progression` wording is shorthand only.

Exact rule:
- Launch has an exactly-once commit boundary producing immutable run identity/input;
- duplicate Launch requests cannot create two authoritative runs;
- completion/progression application is keyed by stable completion identity and is idempotent;
- opening/reopening Results, callbacks, crash recovery, cloud restore or repeated platform events cannot award the same completion twice.

Authority: `PHASE11_TECH_PERSISTENCE.md`.

## 2.7 Controller / Steam Deck status

Any early implication that controller support is optional is obsolete.

Exact rule:
- every mandatory path must be completable mouse+keyboard, keyboard-only, controller-only, and on Steam Deck at 1280x800;
- controller free-cursor emulation cannot be the only path;
- mandatory information cannot be hover-only;
- remapping and accessibility acceptance paths are release requirements.

Authority: `PHASE11_UX_ACCESSIBILITY.md`.

## 2.8 Empty space

There is no global reward for empty cells and no universal `more empty space is better` optimization axis.

`EMPTY_CELLS` is legal only as an explicit contract predicate when density itself creates an intended dynamic transit tradeoff.

Authority: `MECHANICS.md` + `PHASE11_FREEZE.md`.

---

# 3. History-file authority cleanup

`WHOLE_GAME_SIMULATION.md` and `ADVERSARIAL_REVIEW.md` remain useful because they contain scenario walkthroughs, exploit attacks, rationale and empirical gates. They are not implementation authorities after Phase 11.

Therefore:
- a repair in those files is canonical only to the extent it has a surviving canonical home in Phase-11/domain files;
- phrases saying a Phase-9/10 repair `is canonical immediately` are historical process descriptions, not present-day precedence rules;
- if a history example differs from the final state machine/progression/persistence/accessibility semantics, the later frozen source wins;
- no new gameplay rule may be inferred from narrative examples.

This removes the risk that a programmer treats an old validation scenario as a second rules engine.

---

# 4. Sweep classifications

The remaining repository-wide search vocabulary is classified as follows.

### Must be zero in implementation-authority contexts before freeze
- `TBD`
- `TODO`
- `to be decided`
- undefined `future work` that changes player-visible rules
- vague `exact dependencies are content data` after graph freeze
- `8 documented + 2 discovery`
- repeated unchanged blocked-growth punishment
- controller as optional for mandatory flows
- runtime snapshot as simulation authority
- non-idempotent `Results writes progression` interpretation
- Challenge unlock by anything other than Bronze(C16)

### Allowed only as history/rationale
- Phase-9/10 descriptions of repairs before fold-in;
- concept-selection alternatives;
- rejected mechanics;
- market hypotheses;
- prototype attack scenarios that have explicit canonical outcomes elsewhere.

### Allowed as empirical prototype gates
These are intentionally not paper-solvable design unknowns:
- >=70% failed representative cases produce a specific causal explanation and intended revision;
- >=50% memorable validation outcomes depend on post-launch change;
- ordinary learned non-mastery planning median <=8 minutes;
- helper/protector redundancy clusters must produce distinct choices or be cut/merged;
- demo testers predominantly describe planning for transit behavior rather than static packing;
- Causal Review exposes actionable first cause without raw-log reading.

Failure of an empirical gate may force simplification/cuts, but implementation may not invent a new system in advance to pre-solve it.

---

# 5. Fresh-session implementation-readiness test

A fresh builder must be able to answer all of the following without guessing:

- which concept is being built and what must differentiate it;
- every authoritative tick phase and blocked-growth behavior;
- legal planning/launch transitions;
- exact C01–C48 prerequisite graph;
- exact Challenge gate;
- exact demo progression boundary;
- support rules and non-dominance constraints;
- species roster and cut/merge empirical gates;
- deterministic challenge/version behavior;
- exactly-once Launch and idempotent completion semantics;
- crash/reconstruction/corruption/cloud/migration behavior;
- mandatory keyboard/controller/Deck/accessibility behavior;
- what history files may and may not override;
- what prototype gates can still invalidate content quality after implementation begins.

Current verdict: **YES, provided the Phase-11 supplement authority order is followed.**

However final `DESIGN COMPLETE` remains **NO** until the old domain/history source headers are directly reconciled or the final freeze explicitly makes the supplement authority permanent and a last contradiction/TBD sweep returns no implementation-relevant unresolved choice.

---

# 6. Finite remaining blockers

1. Amend authority headers in `TECHNICAL_SPEC.md`, `UX_ARCHITECTURE.md`, and `ECONOMY_COMMERCIAL.md` so each explicitly names its Phase-11 supplement as overriding final authority for the relevant domain.
2. Amend `WHOLE_GAME_SIMULATION.md` header to `validation history` and replace the `repeated pressure` blocked-growth narrative with episode-correct wording.
3. Amend `ADVERSARIAL_REVIEW.md` header so Phase-10 repairs are evidence/history when a later canonical home exists.
4. Amend `PHASE11_FREEZE.md` authority list/status to include all three final supplements and this consolidation result.
5. Run one last repository-wide placeholder/stale-term scan after those edits.
6. If that scan is clean, perform the final acceptance checklist and set `Specification freeze = YES`, `DESIGN COMPLETE = YES`.

No new gameplay-design phase is required unless that final scan exposes a real contradiction.