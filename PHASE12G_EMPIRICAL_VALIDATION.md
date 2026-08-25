# PHASE 12G EMPIRICAL VALIDATION HARNESS

Status: **IN PROGRESS — EVIDENCE INFRASTRUCTURE / COLLECTION SUPPORT**

This file documents the Phase-12G empirical evidence path. It is not a gameplay design amendment and does not claim any human/prototype gate has passed. `PHASE11_FINAL_FREEZE.md` remains the highest implementation-sensitive authority.

## Separation of concerns

Production human observations live in `validation/phase12g/observations.v1.json`. Synthetic observations belong only in tests. The production file remains empty until real study observations are supplied.

`Phase12GEmpiricalEvidenceEvaluator` validates the frozen six observation kinds and evaluates the already-frozen thresholds. `Phase12GEmpiricalEvidenceStore` provides atomic raw capture. Neither mutates gameplay, campaign state, saves, simulation inputs, or content.

Increment 200 adds an operator layer rather than changing the base evidence math: `Phase12GEvidenceReportService` imports an external versioned JSON dataset, validates provenance/cohort declarations, filters only explicitly eligible cohorts, and emits stable machine-readable JSON plus a fixed-order human-readable gate report. `tools/phase12g_evidence_report.gd` is the command-line entry point.

## Observation schema

Evidence schema: `phase12g-evidence-v1`.

Every sample still requires:
- `sample_id`;
- `sample_type`;
- `tester_id`;
- `captured_at_unix`;
- the type-specific fields frozen in Increment 199.

Operator-import datasets additionally require:
- non-empty `dataset_id`;
- `collection_metadata.metadata_version = phase12g-collection-v1`;
- non-empty `source_id`, `collection_owner`, and `cohort_policy_version`;
- an explicit `cohort` on every observation.

Production metadata uses an explicit `UNASSIGNED_OPERATOR` / `EMPTY_AWAITING_REAL_OBSERVATIONS` state rather than fabricating study provenance.

## Cohort policy

Allowed cohorts are:
- `POST_ONBOARDING_FAMILIAR_ORDINARY`;
- `POST_ONBOARDING_MASTERY`;
- `TUTORIAL_ONBOARDING`;
- `DEMO_TEST`;
- `REDUNDANCY_CLUSTER`.

Filtering is deterministic and happens before threshold evaluation:
- failed-review retry, memorable-outcome, and Review-usability evidence may use post-onboarding ordinary or mastery observations;
- the frozen <=8 minute planning median uses only `POST_ONBOARDING_FAMILIAR_ORDINARY`, and those samples must also carry `ordinary_non_mastery=true` and `rule_familiarity=true`;
- mastery planning observations remain preserved in the source dataset but are excluded from that median;
- tutorial/onboarding samples cannot silently enter post-onboarding gates;
- `demo_identity` requires `DEMO_TEST`;
- `species_decision` requires `REDUNDANCY_CLUSTER`.

This filtering does not alter any frozen threshold.

## Frozen empirical gates

The base evaluator continues to apply:
- hypothesis-driven failed Retry >=70%;
- memorable outcomes depending on post-launch state/footprint/channel/support-power >=50%;
- ordinary familiar first-launch planning median <=480 seconds;
- O06/O12/O16 and O05/O19/O20 exact preferred decision similarity >=70% is a redundancy risk;
- demo `TRANSIT_BEHAVIOR` classification must be a strict majority;
- Causal Review usability remains `MEASURE_ONLY` because canon freezes no numeric speed/interaction cutoff.

A valid empty evidence dataset evaluates `INCOMPLETE`, never PASS.

## Operator report path

Example invocation from the repository root:

`godot --headless --path . --script tools/phase12g_evidence_report.gd -- --evidence=res://validation/phase12g/observations.v1.json --json-out=user://phase12g/report.json --text-out=user://phase12g/report.txt`

A gate result of PASS, FAIL, INCOMPLETE, or MEASURE_ONLY is valid report output; malformed evidence/provenance is an import error. The operator tool never writes back into gameplay/content data.

## Certified-Bronze geometry evidence

Phase 12F proved that no authoritative certified-solution geometry corpus currently exists. Increment 200 therefore adds a **separate** fail-closed schema rather than inventing solution data:

- schema: `phase12g-bronze-geometry-v1`;
- production template: `validation/phase12g/bronze_geometry.v1.json`;
- evaluator: `Phase12GBronzeGeometryEvidenceEvaluator`.

Each future solution entry carries a certified solution identity, contract/chapter/order, `isolation_ratio`, `beneficial_relation_count`, symmetry-normalized `normalized_role_to_zone`, high-isolation classification, and certified/primary-family flags.

The evaluator can check the frozen evidence-dependent content obligations once an authoritative corpus exists:
- Chapters 2–6 each need at least two certified Bronze contracts where high isolation is inferior or impossible for a rule-based reason;
- after Chapter 2, the certified primary Bronze family may not repeat the same normalized role-to-zone allocation for more than three consecutive campaign contracts;
- isolation/beneficial-relation values are reported as measurements without inventing a new global numeric threshold.

The production geometry template has `authoritative_corpus=false` and zero solutions. Its overall state is therefore `INSUFFICIENT_EVIDENCE`. Synthetic authoritative geometry exists only in the focused unit runner to verify aggregation and boundary logic.

## Validation policy

Unknown schema versions, malformed metadata, duplicate sample/solution IDs, invalid cohort membership, impossible numeric ranges, multiple primary solution families for one contract, and invalid classifications fail closed.

Harness existence is not empirical evidence. Phase 12G remains open until real human observations and, where required, an authoritative certified-Bronze corpus are actually supplied and evaluated.
