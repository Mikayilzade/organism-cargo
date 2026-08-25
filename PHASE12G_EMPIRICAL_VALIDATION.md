# PHASE 12G EMPIRICAL VALIDATION HARNESS

Status: **IN PROGRESS — EVIDENCE INFRASTRUCTURE ONLY**

This file documents the Phase-12G empirical evidence harness. It is not a gameplay design amendment and does not claim any human/prototype gate has passed. `PHASE11_FINAL_FREEZE.md` remains the highest implementation-sensitive authority.

## Separation of concerns

Production observations live in `validation/phase12g/observations.v1.json`. That file starts with an empty `samples` array and must contain real observations only. Synthetic observations belong only in tests.

`src/validation/phase12g_empirical_evidence_evaluator.gd` validates the observation schema and derives an evaluation report. The evaluator never mutates gameplay state, campaign state, saves, simulation inputs, contract content, or the production observation file.

Malformed samples fail closed. Unknown schema versions, sample kinds, species-cluster membership, post-launch dependency categories, missing required fields, duplicate sample IDs, and invalid numeric values are rejected rather than silently omitted.

## Schema version

Current schema: `phase12g-evidence-v1`.

Every sample has:
- `sample_id`: unique non-empty observation identifier;
- `sample_type`: one of the six kinds below;
- `tester_id`: non-empty participant identifier chosen by the study operator;
- `captured_at_unix`: positive observation timestamp.

The harness does not prescribe collection of personally identifying data. Tester IDs can and should be study-local pseudonyms where possible.

## Observation kinds

### `failed_review_retry`
Required additional fields: `contract_id`, `causal_explanation`, `intended_revision`, `blind_shuffle`.

The frozen >=70% retry gate counts a sample as hypothesis-driven only when the tester supplies both a non-empty specific causal explanation and a non-empty intended revision and the observation is not marked as blind shuffle.

### `memorable_outcome`
Required: `outcome_description`, `post_launch_dependency`.

Allowed dependency classifications: `STATE`, `FOOTPRINT`, `CHANNEL`, `SUPPORT_POWER`, `NONE`, `UNKNOWN`. The first four count toward the frozen >=50% post-launch-change target.

### `planning_duration`
Required: `contract_id`, `duration_seconds`, `ordinary_non_mastery`, `rule_familiarity`.

Only samples explicitly marked ordinary non-mastery and after rule familiarity enter the frozen <=8 minute median calculation.

### `species_decision`
Required: `contract_id`, `cluster_id`, `species_id`, `placement_choice`, `support_choice`, `revision_choice`.

Frozen comparison clusters are:
- `SOOTHER_HELPER`: O06, O12, O16;
- `PROTECTOR_HELPER`: O05, O19, O20.

Comparison is paired by `tester_id + contract_id`. The harness reports placement, support, revision and exact three-field similarity per species pair. Exact preferred-decision tuple similarity >=70% is flagged as representative redundancy risk, matching the Phase-12F empirical classification; it does not automatically rewrite or merge content.

### `demo_identity`
Required: `response_text`, `classification`.

Allowed classifications: `TRANSIT_BEHAVIOR`, `STATIC_PACKING`, `OTHER`. Canon says most demo testers should describe planning for transit behavior, so the evaluator requires a strict >50% `TRANSIT_BEHAVIOR` share when evidence exists.

### `review_usability`
Required: `contract_id`, `actionable_first_cause`, `raw_log_read`. Optional: `time_to_first_cause_seconds`, `interaction_count`.

The evaluator reports the actionable-without-raw-log rate plus median time and interaction count when supplied. Phase 11 freezes no numeric speed/interaction cutoff, so this gate is intentionally `MEASURE_ONLY` rather than inventing a threshold.

## Evaluation states

Each gate returns `PASS`, `FAIL`, `INSUFFICIENT_EVIDENCE`, or `MEASURE_ONLY` as applicable. A structurally valid empty production dataset therefore evaluates to `INCOMPLETE`, never PASS.

Automated tests use explicit synthetic fixtures generated inside `tests/unit/phase12g_empirical_evidence_test_runner.gd` only to verify aggregation math, threshold boundaries, exclusion rules, species-pair comparison, and hostile malformed-input rejection.

## Current evidence state

No real human observations have been added by this implementation increment. Phase 12G remains open until representative evidence is actually collected and evaluated, including any future certified-Bronze geometry evidence required for the remaining authored isolation/beneficial-relation and normalized role-to-zone obligations.
