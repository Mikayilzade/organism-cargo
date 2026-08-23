# ORGANISM CARGO — IMPLEMENTATION STATUS

Last updated: 2026-08-23
Repository: `Mikayilzade/organism-cargo`
Branch: `main`

## Master state
- Design frozen: **YES**
- Canonical implementation authority: **`PHASE11_FINAL_FREEZE.md` + frozen authority chain**
- 12A Technical Bootstrap: **COMPLETE**
- 12B Vertical Slice: **COMPLETE**
- 12C Core Systems: **IN PROGRESS**
- 12D Content Population: **NO**
- 12E UX / Accessibility / Controller / Deck: **NO**
- 12F Adversarial QA: **NO**
- 12G Empirical Gates: **NO**
- 12H Release Candidate: **NO**
- IMPLEMENTATION COMPLETE: **NO**

## Current implementation checkpoint — Increment 137

### Phase / subsystem
**12C Core Systems — deterministic completion identity and idempotent Results/progression application**

### Repository truth read before work
This run re-read the mandatory recovery chain:
- `IMPLEMENTATION_START_HERE.md`
- `IMPLEMENTATION_STATUS.md`
- `AUTONOMY_RULES.md`
- `DESIGN_STATUS.md`
- `PHASE11_FINAL_FREEZE.md`

For the exact persistence/progression subsystem it also re-read `PHASE11_TECH_PERSISTENCE.md` and `PHASE11_PROGRESSION.md`.

### Entry validation
- Repository `main` at start: `8e0fd59f75463e0fd5dd9eafc0d91268266eadef` (`12C: add deterministic transit reconstruction`).
- Explicit `organism-cargo/godot-headless` status for Increment 136: **SUCCESS**, workflow run `32657729065`.
- Therefore deterministic committed-run reconstruction and mismatch quarantine are green, and the exact recorded NEXT ACTION was the remaining idempotent Results/progression persistence gap.

### Implemented in Increment 137
- Added `ResultsProgressionService`, the atomic Results-side authority for successful campaign completion application.
- Deterministic `completion_id` is derived from the frozen tuple `(profile_uuid, run_id, contract_id, committed_result_checksum, rules_version, content_version)` using a canonical separator and SHA-256.
- Mandatory delivery failure returns a completed non-award result and creates no profile progression/completion ledger entry.
- Successful application performs only monotonic profile merges: Bronze cleared-contract set union, per-contract best-medal maximum, documented-fact union, and durable `applied_completion_ids` ledger append.
- Duplicate Results/reopen callbacks recompute the same completion ID, detect it in the durable ledger, award nothing again, and only ensure session lifecycle is repaired to `COMPLETION_APPLIED`.
- Profile write occurs before session lifecycle advancement. This implements the frozen crash boundary: if the process dies after the durable profile transaction but before session update, reopening detects the existing completion ledger entry and repairs the session without re-award.
- No independent campaign-node/challenge unlock counters are persisted; this checkpoint preserves the frozen rule that availability must be derived later from Bronze source truth and the authored graph.
- Added focused headless coverage for exactly-once application/reopen, monotonic medal and knowledge merge, simulated crash-after-profile-before-session repair, and mandatory-failure no-award behavior.

### Files changed
- `src/run/results_progression_service.gd` — deterministic completion identity and idempotent monotonic profile/session application authority.
- `tests/unit/results_progression_test_runner.gd` — duplicate/reopen, crash-boundary, medal/knowledge monotonicity and failure coverage.
- `.github/workflows/headless-tests.yml` — wires the Results progression contract into the notification-safe suite.
- `IMPLEMENTATION_STATUS.md` — records Increment 137 and exact continuation.

### Validation performed / available
- Increment 136 explicit custom headless status was verified green before this work.
- Static review verified the completion-id material exactly matches the Phase-11 persistence tuple and excludes presentation state.
- Static review verified permanent progression merges only set-union/max fields and never decrements Bronze, medals or knowledge.
- Static review verified duplicate completion callbacks cannot append a second ledger entry or downgrade an existing best medal.
- Static review verified profile durability precedes `COMPLETION_APPLIED` session persistence, and the regression fixture models the canonical crash boundary by pre-seeding the completion ledger while leaving session lifecycle at `REVIEWABLE`.
- This checkpoint requires one authoritative notification-safe GitHub headless run. Per anti-spam policy no speculative second push is stacked in this run.

### Deliberately not changed
- No canonical gameplay/design files.
- No campaign graph/content population yet; 12D remains closed.
- No H01–H06, T05–T10, supports, organism behavior or environmental semantics.
- No cloud merge, migration or demo-import implementation in this increment.

### Blockers / deferred known work
- **No user-action blocker.**
- 12C remains incomplete.
- Increment 137 requires authoritative headless validation.
- Remaining audited 12C work still includes unimplemented foundation trait families/production interaction coverage and additional persistence hardening obligations before the 12C exit gate can be claimed.

### Canonical contradictions
- **NONE discovered.** This increment implements the already-frozen exactly-once Results transaction and monotonic progression semantics without inventing currency, counters or alternative unlock rules.

## NEXT ACTION
At the start of the next run, query current `main` and explicit `organism-cargo/godot-headless` status for Increment 137.

- If the workflow fails, inspect the first exact compile/runtime/assertion failure in the new Results/progression contract and make one focused repair batch only.
- If the workflow is green, preserve the completion/progression authority and audit the remaining frozen 12C mechanical obligations against `MECHANICS.md`, `TECHNICAL_SPEC.md`, current simulation files and headless coverage. Select the next missing foundation trait/core interaction strictly from repository evidence and implement one coherent increment.
- Do not begin 12D, 12E or later phases until the full 12C exit gate is satisfied and recorded.
