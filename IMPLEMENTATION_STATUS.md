# IMPLEMENTATION STATUS

Branch: `main`

## Phase state
- 12A Vertical Slice: **COMPLETE**
- 12B Core Simulation Expansion: **COMPLETE**
- 12C Full Gameplay Systems: **COMPLETE**
- 12D Full Content Population: **COMPLETE**
- 12E UX / Accessibility / Controller / Deck: **COMPLETE**
- 12F Adversarial QA / Persistence / Recovery: **COMPLETE**
- 12G Empirical validation / platform polish: **IN PROGRESS**
- 12H Release Candidate: **NO**
- IMPLEMENTATION COMPLETE: **NO**

## Current implementation checkpoint — Increment 202

### Phase / subsystem
**12G empirical validation — deterministic multi-study merge/provenance, pre-collection session manifests, and trusted certified-Bronze export ingestion**

### Repository truth / entry validation
- Re-read `IMPLEMENTATION_START_HERE.md`, this status file, `AUTONOMY_RULES.md`, `DESIGN_STATUS.md`, `PHASE11_FINAL_FREEZE.md`, then the exact current empirical/content authorities `ADVERSARIAL_REVIEW.md`, `PHASE11_UX_ACCESSIBILITY.md`, `CONTENT_ARCHITECTURE.md`, `PHASE12F_COVERAGE_RECONCILIATION.md`, and `PHASE12G_EMPIRICAL_VALIDATION.md`.
- Entry head: `7eaa37f7371797c26c59f5b6b49dda04d657a772` (Increment 201), commit `12G: repair simulation timing adversarial parse`.
- Inspected the exact Increment-201 workflow set on the entry SHA before implementation. All seven executable workflows completed **success**, including:
  - `Phase 12F Simulation Timing Adversarial` run `32901303990`;
  - `Godot Headless Tests` run `32901304016`;
  - `Phase 12G Empirical Evidence Harness` run `32901304008`;
  - `Content Population Validator` run `32901304083`;
  - the Phase-12F authored-content, state/planning/campaign, and persistence adversarial workflows.
- Therefore this run follows the green branch of Increment-201 `NEXT ACTION` and resumes the deferred substantial Phase-12G infrastructure cluster.

### Implemented in Increment 202
- Added `Phase12GStudyInfrastructure` as a fail-closed operator/study boundary over the existing frozen empirical evaluators.
- Added deterministic multi-file/multi-dataset evidence merge:
  - every source dataset is first validated by the existing operator/cohort contract;
  - duplicate dataset IDs are rejected;
  - incompatible cohort-policy versions are rejected rather than silently combined;
  - duplicate `sample_id` values across separate source datasets are rejected;
  - merged observations are sorted by stable sample ID and source manifests are sorted deterministically, so source input order does not change the aggregate;
  - every merged sample receives nested source provenance with source dataset ID/source ID/source key and the canonical source-dataset checksum;
  - the aggregate dataset receives a reproducible source-manifest checksum, deterministic aggregate ID/checksum, and a single aggregate gate report;
  - file-backed merge is read-only with respect to raw source evidence; source file paths are not copied into evidence provenance by default, avoiding unnecessary local-path disclosure.
- Extended `tools/phase12g_evidence_report.gd` to accept repeated `--evidence=<path>` arguments. A single source preserves the previous behavior; multiple sources pass through the deterministic merge path and emit one report with aggregate checksum/source manifest attached.
- Added pre-collection study-session manifest contract `phase12g-study-session-v1`:
  - snapshots explicit session ID, prototype build ID, rules version, content version, declared cohort, declared observation kinds/contracts, and collection-start timestamp;
  - normalizes observation kinds/contracts before hashing for reproducibility;
  - records explicit data-minimization policy forbidding real-name, email, and device-serial collection and permitting only a pseudonymous study identifier;
  - attaches a canonical SHA-256 manifest checksum, validates checksum integrity, and supports durable JSON export before collection.
- Added external certified-Bronze solver adapter contract `phase12g-certified-bronze-export-v1`:
  - requires an explicit format version, corpus/solver/content IDs, certification status, checksum method, authoritative-corpus flag, and external authority ID;
  - requires the caller to supply a trusted certification-authority allowlist rather than trusting self-asserted authority;
  - verifies a canonical SHA-256 export checksum before accepting solution geometry;
  - rejects unversioned, uncertified, non-authoritative, untrusted, or checksum-mismatched exports;
  - adapts only verified input into the existing `phase12g-bronze-geometry-v1` evaluator and preserves the external authority and source-export checksum in corpus provenance.
- Added `phase12g_study_infrastructure_test_runner.gd` covering:
  - deterministic aggregate equality under reversed source order;
  - source provenance and source-dataset checksums;
  - cross-file duplicate sample rejection;
  - incompatible cohort-policy rejection;
  - raw source-file immutability during file merge;
  - session manifest normalization, export, checksum tamper detection, cohort/type rejection, and data-minimization guarantees;
  - trusted certified-Bronze ingestion plus rejection of tampering, untrusted authorities, non-authoritative corpora, and unversioned exports.
- Wired the new runner into the dedicated `Phase 12G Empirical Evidence Harness`.
- No gameplay rule, frozen empirical threshold, simulation authority, content definition, campaign state, save semantics, accessibility rule, or production human/Bronze evidence was changed or fabricated.

### Validation / policy
- Increment-201 entry CI was green across all seven workflows before implementation.
- Static integration review confirms the new merge layer operates on duplicated parsed dictionaries and never writes raw study source files.
- Static review confirms the session manifest intentionally excludes direct personal fields and its checksum covers build/rules/content/cohort/declaration metadata.
- Static review confirms the Bronze adapter cannot mark an arbitrary export authoritative solely from its own payload: the authority ID must also be present in the caller-provided trusted list, and content integrity must match the declared canonical checksum.
- Synthetic observations/solver geometry exist only inside the focused unit runner to test contracts and failure modes; production `validation/phase12g/observations.v1.json` and `validation/phase12g/bronze_geometry.v1.json` remain unchanged and evidence-insufficient.
- No directly runnable local Godot 4.7.1 binary is available in this execution environment; the new focused runner is wired into fresh GitHub Actions after this single checkpoint push.
- All source/test/tool/workflow/status changes are batched into one Git tree + one normal checkpoint commit/push. No speculative second CI repair is made in this run.

### Blockers / cautions
- No user-action blocker for further automatable Phase-12G platform/instrumentation work.
- Fresh Increment-202 CI must confirm Godot 4.7.1 parses the new study infrastructure under warnings-as-errors and executes the new dedicated runner successfully.
- Real representative human observations remain absent. Hypothesis-driven Retry, memorable transit significance, ordinary planning duration, species decision distinctness, demo identity, and qualitative Causal Review usability cannot honestly be marked PASS by automation alone.
- No real externally certified authoritative Bronze solution export is present. The adapter now provides a trusted/checksummed ingestion boundary, but the production geometry gate remains evidence-insufficient until such a corpus actually exists.
- Phase 12G remains **IN PROGRESS**; 12H must not begin yet.

### Canonical contradictions
- **NONE discovered.**

## NEXT ACTION
At the start of the next run, inspect the exact Increment-202 workflow set on the new SHA, especially `Phase 12G Empirical Evidence Harness`, project import, and the core/adversarial workflows.

If any executable workflow is red, inspect the first exact executable failure and make one focused repair batch only.

If Increment-202 is green, continue the next substantial automatable 12G collection-integrity/platform cluster:
1. bind operator evidence datasets to validated study-session manifest identity/checksum and require compatible prototype build/rules/content identifiers during deterministic merge, so every future real observation is traceable to the declared pre-collection build rather than only to a source dataset;
2. add operator-facing manifest creation/validation and certified-Bronze import/report tooling around the new contracts, keeping production source/template files immutable by default;
3. produce a deterministic study-package audit summary that reports source manifests, build/cohort coverage, gate eligibility, missing evidence classes, and certified-corpus state without turning missing evidence into PASS;
4. reconcile the remaining Phase-12G checklist against the frozen authorities and separate automatable platform obligations from human/certified-solver evidence dependencies.

Do not begin 12H or report overall completion until Phase 12G evidence/platform obligations are actually satisfied and `IMPLEMENTATION COMPLETE = YES`.
