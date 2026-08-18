# ORGANISM CARGO — PHASE 11 VALIDATION-HISTORY RECONCILIATION

Status: **RECONCILED — PHASE 9/10 DEMOTED TO VALIDATION HISTORY**
Last updated: 2026-08-15

`WHOLE_GAME_SIMULATION.md` and `ADVERSARIAL_REVIEW.md` preserve scenario validation, exploit attacks, rationale, and prototype gates. They are no longer independent gameplay authorities whenever a later Phase-11 or domain source contains the final rule.

Current precedence for implementation-sensitive conflicts:
1. `GAME_BIBLE.md`;
2. `PHASE11_FREEZE.md`;
3. `PHASE11_TECH_PERSISTENCE.md`;
4. `PHASE11_UX_ACCESSIBILITY.md`;
5. `PHASE11_PROGRESSION.md`;
6. `MECHANICS.md`, `DECISION_ARCHITECTURE.md`, `CONTENT_ARCHITECTURE.md`, `TECHNICAL_SPEC.md`, `UX_ARCHITECTURE.md`, `ECONOMY_COMMERCIAL.md` in their domains;
7. Phase-9/10 files as validation history only.

`PHASE11_CONSOLIDATION_PASS4.md` records the current direct-source cleanup audit and finite remaining blockers.

## 1. Whole-game simulation stale blocked-growth narrative

Representative Contract B currently narrates one blocked growth event followed by `repeated pressure pushes Grazer...`.

Do **not** implement repeated unchanged every-tick blocked-growth stress/damage.

Canonical rule:
- unchanged illegal deterministic growth begins one `GROWTH_BLOCKED` episode;
- the episode consequence fires once;
- no repeated same-obstruction punishment occurs until a relevant legality/occupancy/orientation/growth-trigger/retry-boundary condition changes;
- later stress may still rise from independent continuing causes or a genuinely new blocked-growth episode.

Authority: `MECHANICS.md` + `PHASE11_FREEZE.md`.

## 2. Challenge gate terminology

Any Phase-7/9 phrase such as `after Tier 2`, `after Chapter-2 capstone`, `roughly the first 16 contracts`, or `after enough rules are documented` is descriptive shorthand only.

Exact rule:

`ChallengeModeUnlocked := Bronze(C16) == true`.

Documented rule families may gate individual challenge templates after the mode is unlocked; they cannot unlock the mode before C16.

Authority: `PHASE11_PROGRESSION.md`.

## 3. Campaign graph terminology

Historical wording that exact dependencies are merely unspecified future content data is obsolete. The exact C01–C48 prerequisite graph is frozen implementation data in `PHASE11_FREEZE.md` / `PHASE11_PROGRESSION.md`.

No implementation session may invent or rebalance prerequisite edges without reopening specification freeze.

## 4. Demo mapping terminology

Any older demo wording is normalized to:
- 10 demo species total = 9 documented + 1 bounded discovery;
- D01–D08 may map to C01–C08 Bronze only through the validated equivalence mapping;
- D09–D10 never auto-clear C09+;
- settings/valid knowledge may transfer;
- imported knowledge never bypasses C16 Challenge gate;
- no mechanical power transfers;
- incompatible mappings fail closed rather than partially skipping campaign teaching.

Authority: `PHASE11_PROGRESSION.md` + `PHASE11_TECH_PERSISTENCE.md`.

## 5. Empty-space terminology

Any generic language implying that more unused cells is globally better is superseded. There is no global empty-space score or normal optimization axis.

`EMPTY_CELLS` is legal only as an explicit contract-specific predicate where density itself creates a demonstrated dynamic transit tradeoff.

Authority: `MECHANICS.md` + `PHASE11_FREEZE.md`.

## 6. Resume terminology

Any history wording suggesting that a platform/runtime snapshot itself is authoritative is superseded by `PHASE11_TECH_PERSISTENCE.md`:
- immutable committed input + compatible versions + run identity/checksums are authoritative;
- resume reconstructs transit deterministically;
- playback cursor is presentation state;
- mutable mid-phase engine state is not a save authority;
- checksum/version mismatch follows explicit recovery logic.

## 7. Launch / completion / progression terminology

Any phrase such as `Launch creates a run` or `Results writes progression` is shorthand only.

Final semantic contract:
- Launch has an exactly-once commit boundary;
- immutable `run_id` / deterministic `completion_id` identity prevents duplicate authoritative runs or awards;
- completion application is idempotent;
- reopening Results, repeated callbacks, crash recovery, cloud restoration, or duplicate platform events cannot double-apply campaign progression.

Authority: `PHASE11_TECH_PERSISTENCE.md`.

## 8. Controller / Deck terminology

Any older implication that controller support is optional is obsolete.

Mandatory release paths:
- mouse+keyboard;
- keyboard-only;
- controller-only;
- Steam Deck at 1280x800;
- no mandatory hover-only information;
- no controller free-cursor-only implementation;
- remapping and the frozen no-audio/non-color/reduced-motion/reduced-flash paths.

Authority: `PHASE11_UX_ACCESSIBILITY.md`.

## 9. Phase-10 repairs already folded into canonical sources

The following major Phase-10 repairs now have canonical homes and Phase-10 text is evidence/history only:
- dynamic-transit significance quotas -> `CONTENT_ARCHITECTURE.md` / `PHASE11_FREEZE.md`;
- max-spacing and repeated role-template counterexamples -> content/freeze sources;
- Cooler+Filter <=8 C17–C48 primary Bronze cap -> content/freeze sources;
- living-vs-powered support role distinction -> content/freeze sources;
- sleep explicit trait gates -> `MECHANICS.md` / `DECISION_ARCHITECTURE.md` / freeze;
- no global empty-space optimization -> `MECHANICS.md` / freeze;
- finite T10 reactive pulses -> `MECHANICS.md` / freeze;
- simultaneous material causes preserve multi-parent ancestry -> `MECHANICS.md` / freeze;
- Brownout Phase-A authority -> `MECHANICS.md` / freeze;
- species redundancy clusters and >=70% cut/merge gate -> `CONTENT_ARCHITECTURE.md` / freeze;
- exact campaign graph -> `PHASE11_FREEZE.md` / `PHASE11_PROGRESSION.md`;
- exactly-once launch/idempotent completion/reconstruction/cloud/migration/demo import -> `PHASE11_TECH_PERSISTENCE.md`;
- complete keyboard/controller/Deck/no-audio/non-color/reduced-motion/reduced-flash paths -> `PHASE11_UX_ACCESSIBILITY.md`;
- C16 Challenge gate and exact demo progression boundary -> `PHASE11_PROGRESSION.md`.

## 10. Prototype gates remain valid but are not undefined design

Phase-10 empirical gates remain obligations:
- >=70% representative failures produce a specific causal explanation + intended revision rather than blind shuffle;
- at least half of memorable validation outcomes depend on post-launch change;
- ordinary non-mastery planning median should not exceed 8 minutes after rule familiarity;
- helper/protector redundancy clusters are cut/merged if decisions overlap >=70%;
- demo testers predominantly describe planning for transit behavior, not static packing;
- Causal Review surfaces an actionable first cause without raw-log reading.

These gates can fail the prototype and force simplification/cuts. They do not authorize implementation to invent new mechanics before testing.

## 11. Remaining history/source work

The semantic reconciliation itself is complete. Remaining work is editorial/source consolidation so future readers do not need this map for obvious stale sentences:
- mark `WHOLE_GAME_SIMULATION.md` and `ADVERSARIAL_REVIEW.md` headers explicitly as validation history;
- replace the blocked-growth `repeated pressure` example;
- add permanent Phase-11 supplement authority notes to `TECHNICAL_SPEC.md`, `UX_ARCHITECTURE.md`, `ECONOMY_COMMERCIAL.md`;
- refresh `PHASE11_FREEZE.md` authority order/status;
- run the final repository-wide placeholder/stale-term scan.

Until those direct edits land, this file and `PHASE11_CONSOLIDATION_PASS4.md` prevent the known historical wording from competing with the final rules.