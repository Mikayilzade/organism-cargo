# PHASE 12G OPERATOR PACKAGE TOOLING

Status: **AUTOMATABLE OPERATOR HANDOFF IMPLEMENTED; REAL EVIDENCE STILL REQUIRED**

This guide is an operational companion to `PHASE12G_EMPIRICAL_VALIDATION.md` and `PHASE12G_STUDY_PACKAGE.md`. It does not change frozen gameplay, empirical thresholds, cohort rules, or certification policy. Source evidence is treated as immutable input; every derived artifact must use a separate output path.

## Entry point

Run the operator tool with Godot 4.7.1 from the repository root:

```bash
godot --headless --path . --script tools/phase12g_operator_package.gd -- --mode=<mode> [options]
```

`--dry-run` validates and evaluates without writing derived files. A valid `INCOMPLETE`, `FAIL`, or `INSUFFICIENT_EVIDENCE` empirical state is printed and exits successfully; malformed, untrusted, checksum-invalid, undeclared, or incompatible input fails closed with exit code 2. Tooling existence never converts missing evidence into PASS.

## 1. Create a pre-collection manifest

Create this **before** collecting observations. Use only a pseudonymous study identifier; the manifest's data-minimization contract forbids real names, email addresses, and device serials.

```bash
godot --headless --path . --script tools/phase12g_operator_package.gd -- \
  --mode=manifest-create \
  --session-id=study-2026-001 \
  --prototype-build-id=<build-id> \
  --rules-version=<rules-version> \
  --content-version=<content-version> \
  --cohort=POST_ONBOARDING_FAMILIAR_ORDINARY \
  --sample-type=planning_duration \
  --sample-type=failed_review_retry \
  --contract-id=C10 \
  --created-at-unix=<collection-start-unix> \
  --manifest-out=study/session-001.manifest.json
```

Repeat `--sample-type` and `--contract-id` as needed. Omitting `--created-at-unix` uses current system time; supplying it is preferred for reproducible operator scripts. Validate an existing manifest with:

```bash
godot --headless --path . --script tools/phase12g_operator_package.gd -- \
  --mode=manifest-validate --manifest=study/session-001.manifest.json
```

## 2. Bind collected evidence without changing the raw file

The raw operator dataset must already satisfy the Phase-12G evidence schema and cohort policy. Binding checks that every observed sample type, contract, and cohort was declared by the pre-collection manifest.

```bash
godot --headless --path . --script tools/phase12g_operator_package.gd -- \
  --mode=bind \
  --manifest=study/session-001.manifest.json \
  --evidence=study/session-001.raw.json \
  --bound-out=derived/session-001.bound.json
```

The tool rejects any output path that would overwrite a manifest, raw evidence input, certified export, or geometry input. Use `--dry-run` first when checking an unfamiliar dataset.

## 3. Build the deterministic study package

Provide every manifest needed to resolve every bound evidence dataset. Multiple studies may be pooled only when prototype build, rules version, and content version match exactly.

```bash
godot --headless --path . --script tools/phase12g_operator_package.gd -- \
  --mode=package \
  --manifest=study/session-001.manifest.json \
  --evidence=derived/session-001.bound.json \
  --aggregate-out=derived/phase12g.aggregate.json \
  --audit-out=derived/phase12g.audit.json \
  --report-json-out=derived/phase12g.report.json \
  --report-text-out=derived/phase12g.report.txt
```

Repeat `--manifest` and `--evidence` for additional compatible sessions. After importing a certified Bronze export, add `--bronze-geometry=<derived-geometry-path>` so the package audit reports that corpus state. `aggregate`, `audit`, report JSON, and report text must all be separate outputs.

A package can be structurally eligible while still reporting missing evidence. This is expected until all required real observations exist.

## 4. Import a certified Bronze solver export

A solver export is accepted only when its format/version/certification fields are valid, its canonical checksum matches, it declares an authoritative corpus, and its `authority_id` appears in an operator-supplied trusted allowlist.

```bash
godot --headless --path . --script tools/phase12g_operator_package.gd -- \
  --mode=bronze-import \
  --bronze-export=external/certified-bronze-export.json \
  --trusted-authority=<approved-authority-id> \
  --geometry-out=derived/bronze.geometry.json \
  --geometry-report-out=derived/bronze.report.json
```

Repeat `--trusted-authority` only for authorities independently approved by the operator/release process. The tool never edits the certified source export and never treats a self-asserted authority as trusted.

## Safe operator sequence

1. Create and archive the session manifest before collection.
2. Collect real evidence into a new raw file; never edit repository production placeholders to simulate results.
3. Run `bind --dry-run`, then write a separate bound dataset.
4. Run `package --dry-run`; inspect `INCOMPLETE`, `FAIL`, missing-evidence classes, and build/cohort coverage.
5. Write aggregate/audit/reports only after validation succeeds.
6. Import certified Bronze data only through `bronze-import` with a trusted authority allowlist and preserve the source export.
7. Re-run `package` with the derived Bronze geometry path if appropriate.
8. Phase 12G remains IN PROGRESS until genuine human evidence and genuine certified-solver evidence satisfy the frozen gates. Do not begin 12H merely because the operator tooling is green.
