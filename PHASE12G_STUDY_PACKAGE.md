# PHASE 12G STUDY PACKAGE / COLLECTION INTEGRITY

Status: **AUTOMATABLE PLATFORM AND OPERATOR HANDOFF COMPLETE; REAL EVIDENCE STILL REQUIRED**

This document is an implementation/validation companion to `PHASE12G_EMPIRICAL_VALIDATION.md`. It does not change frozen gameplay or empirical thresholds. `PHASE11_FINAL_FREEZE.md` remains the highest implementation-sensitive authority.

## Session-bound evidence contract

Every future real operator dataset intended for a Phase-12G aggregate must be bound to a validated pre-collection `phase12g-study-session-v1` manifest. The binding records the manifest checksum plus session ID, prototype build ID, rules version, content version and declared cohort. The binding is checked against the manifest checksum registry before gate evaluation.

The dataset must not contain a sample type or contract ID that was not declared before collection. Every sample cohort must match the session-declared cohort. A missing, tampered or unknown manifest fails closed.

Multi-study aggregation additionally requires one compatible prototype build/rules/content identity. Evidence collected against different builds is retained as separate study material and cannot be silently pooled into one threshold report.

## Study-package audit

`Phase12GStudyPackageService` produces a deterministic audit with:
- source dataset IDs and session-manifest checksums;
- build identity coverage;
- cohort/sample coverage;
- sample-type coverage;
- explicit missing empirical evidence classes;
- certified-Bronze corpus state;
- deterministic audit checksum.

`eligible_for_gate_evaluation` means only that supplied sources are structurally valid and session-bound. It is not a PASS result. Missing evidence remains missing; an empty or partial study package never becomes PASS because tooling exists.

## Certified Bronze boundary

The existing `phase12g-certified-bronze-export-v1` adapter remains the only path from an external certified solver export into authoritative Bronze geometry evaluation. It requires a caller-provided trusted authority allowlist and canonical checksum validation. No repository template or synthetic unit fixture is promoted into an authoritative production corpus.

## Operator handoff boundary

`Phase12GOperatorPackageService` and `tools/phase12g_operator_package.gd` provide the operator-facing handoff around these contracts. The supported modes cover:
- pre-collection manifest creation and checksum validation;
- raw evidence validation and binding to one declared session without modifying the raw source;
- deterministic package merge/audit/report generation to separate output paths;
- certified-Bronze export validation/import through the trusted-authority and checksum boundary;
- dry-run validation/evaluation that performs no derived writes.

The tool deliberately treats `INCOMPLETE`, `FAIL`, and `INSUFFICIENT_EVIDENCE` as valid empirical outcomes rather than CLI failures. Only malformed, undeclared, incompatible, checksum-invalid, untrusted, or unsafe overwrite requests fail the operator command. Usage and safe collection order are documented in `PHASE12G_OPERATOR_TOOLING.md`.

## Production immutability

`validation/phase12g/observations.v1.json` remains the empty production placeholder until real study observations exist. `validation/phase12g/bronze_geometry.v1.json` remains non-authoritative until a real certified corpus exists. Source evidence and manifests are read as inputs; derived aggregates/audits must be written to separate explicit output paths.

## Remaining Phase-12G closure dependencies

### Automatable platform obligations
- evidence schema and fail-closed evaluator: COMPLETE;
- atomic evidence capture store: COMPLETE;
- cohort-aware operator import/reporting: COMPLETE;
- deterministic multi-study merge/provenance: COMPLETE;
- pre-collection study manifests/data minimization: COMPLETE;
- session-manifest checksum/build/rules/content binding: COMPLETE;
- cross-study compatible-build merge guard: COMPLETE;
- deterministic package audit/missing-evidence reporting: COMPLETE;
- trusted/checksummed certified-Bronze ingestion boundary: COMPLETE;
- operator CLI for manifest create/validate, bind, package audit/aggregate/report and certified-Bronze import: COMPLETE;
- non-destructive dry-run and source-overwrite guards: COMPLETE.

### Evidence dependencies that automation cannot fabricate
- representative failed-Retry causal-hypothesis observations for the >=70% gate;
- memorable-outcome attribution for the >=50% transit-significance gate;
- ordinary familiar first-launch planning-duration observations for the <=8 minute median;
- O06/O12/O16 and O05/O19/O20 representative decision-preference evidence;
- demo-tester identity descriptions;
- qualitative/actionability Causal Review usability observations;
- an externally certified authoritative Bronze solution corpus for isolation/beneficial-relation and normalized role-to-zone evidence-dependent content gates.

After the operator tooling passes executable CI, no further automatable Phase-12G platform gap is currently identified by the frozen authority chain. Phase 12G therefore remains **IN PROGRESS** solely because the required external evidence does not yet exist in the repository. Phase 12H may not begin until the required real human and certified-solver evidence is actually supplied, evaluated, and reconciled without inventing data.
