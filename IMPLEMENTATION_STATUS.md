# ORGANISM CARGO — IMPLEMENTATION STATUS

Last updated: 2026-08-25
Repository: `Mikayilzade/organism-cargo`
Branch: `main`

## Master state
- Design frozen: **YES**
- Canonical implementation authority: **`PHASE11_FINAL_FREEZE.md` + frozen authority chain**
- 12A Technical Bootstrap: **COMPLETE**
- 12B Vertical Slice: **COMPLETE**
- 12C Core Systems: **COMPLETE**
- 12D Content Population: **COMPLETE**
- 12E UX / Accessibility / Controller / Deck: **COMPLETE**
- 12F Adversarial QA: **IN PROGRESS**
- 12G Empirical Gates: **NO**
- 12H Release Candidate: **NO**
- IMPLEMENTATION COMPLETE: **NO**

## Current implementation checkpoint — Increment 188

### Phase / subsystem
**12F adversarial persistence reconciliation — cloud/profile conflicts + migration/legacy boundaries + demo import bounds**

### Repository truth / entry validation
- Re-read `IMPLEMENTATION_START_HERE.md`, `IMPLEMENTATION_STATUS.md`, `AUTONOMY_RULES.md`, `DESIGN_STATUS.md`, `PHASE11_FINAL_FREEZE.md`, then the exact current persistence authority `PHASE11_TECH_PERSISTENCE.md`.
- Entry head: `609132f21cfb8b7f160a8c8c026c0f1f5721ada2` (Increment 187).
- Inspected all exact Increment-187 workflows on that SHA:
  - `Content Population Validator` run `32821629732` completed **success**;
  - dedicated `Phase 12F Persistence Adversarial` run `32821629726` completed **success**;
  - `Godot Headless Tests` run `32821629748` completed **success**.
- The first 12F persistence attack cluster is therefore executable-green under Godot 4.7.1, so this run followed the green branch of the previous `NEXT ACTION`.

### Implemented in Increment 188 — second 12F persistence attack cluster
- Added production `PersistenceReconciliationService` at `src/save/persistence_reconciliation_service.gd` to make the remaining Phase-11 persistence conflict rules explicit/testable rather than leaving them as UI/platform policy.
- Implemented **monotonic profile/cloud reconciliation**:
  - only schema-compatible branches with the same immutable `profile_uuid` may merge;
  - Bronze clears, documented facts, applied completion IDs, permanent unlock flags and demo-import IDs merge by set union;
  - best medal per contract merges by canonical Bronze < Silver < Gold maximum;
  - Challenge availability is re-derived from Bronze(C16), not copied from a counter/knowledge flag;
  - different profile UUIDs return an explicit keep-separate conflict with both branches retained rather than auto-merging.
- Implemented **active-session conflict reconciliation**:
  - same run ID + committed-input checksum may select a strictly later canonical lifecycle state;
  - divergent run IDs/checksums are never combined cell-by-cell and instead retain both recoverable copies for explicit player choice;
  - non-orderable/incomplete session identity also falls back to retain-both rather than guessing a winner.
- Implemented **sequential migration enforcement against `AtomicSaveStore`**:
  - source profile is first rewritten as the same validated generation so the atomic store retains an on-disk source backup before any transformation;
  - migration steps must be exact sequential `vN -> vN+1` callables;
  - each step must preserve profile UUID and monotonic permanent progress;
  - any missing/failed/rollback step returns failure without installing a partially advanced version and exposes the original source recovery payload;
  - successful target is atomically installed and an already-current pipeline is a no-op.
- Implemented **legacy generated-challenge identity validation**:
  - challenge identity requires template, seed, generator, rules and content versions;
  - only an exact supported compatibility package may construct gameplay;
  - unsupported identity returns explicit `legacy_challenge_version`, preserves the original identity for diagnostics and cannot silently regenerate a different puzzle from the visible seed.
- Implemented **demo -> full import reconciliation** using the canonical `content/demo/public_demo_mapping.json` contract:
  - deterministic `import_id` derives from target profile UUID, demo profile UUID, demo revision and import schema version;
  - only explicit D01-D08 -> C01-C08 Bronze mappings can add campaign clears;
  - D09/D10 are ignored for Bronze and cannot clear C09+;
  - documented knowledge transfers by union and settings may transfer because the canonical mapping permits them;
  - existing stronger full-game medals/progress remain untouched;
  - demo mechanical-power fields are deliberately never copied;
  - Challenge remains locked unless the resulting full profile actually has Bronze(C16);
  - replaying the same import ID is an idempotent no-op.
- Added `tests/unit/phase12f_reconciliation_adversarial_test_runner.gd` with hostile fixtures covering all four boundaries above, including profile rollback attempts, divergent committed layouts, migration failure after a successful intermediate step, unsupported legacy generator version, D09/D10 overreach attempts, imported-knowledge Challenge bypass attempts and repeat-import replay.
- Extended the existing dedicated `Phase 12F Persistence Adversarial` workflow to execute both the original run-identity/corruption/reconstruction cluster and the new reconciliation cluster after a single project import/parse gate.
- No simulation rule, tick order, checksum algorithm, campaign graph, Challenge gate, demo mapping, gameplay balance or frozen design behavior changed.

### Validation / policy
- Increment-187 dedicated adversarial, broad Godot headless and content-validator workflows were verified green before implementation.
- The new reconciliation runner is wired into the same dedicated hard-fail 12F workflow; no second workflow or burst of CI checkpoints was added.
- Static review ties every new policy directly to `PHASE11_TECH_PERSISTENCE.md` sections 8–11: sequential migrations, cloud conflict policy, legacy generated/versioned challenge identity and demo import.
- Cloud profile merge is monotonic only; non-monotonic active-session data is never merged.
- Migration failure never writes the intermediate in-memory result; the persisted profile remains at the source version and a validated source backup generation exists before transformation begins.
- Demo import consumes the existing canonical public mapping rather than inventing a new D->C translation.
- This runtime has no directly runnable local Godot binary; fresh GitHub Actions from this single checkpoint push are the executable validation path.
- All meaningful source/test/workflow/status changes are batched into one Git tree + one checkpoint commit/push. No speculative post-push CI repair is made in this run.

### Blockers / cautions
- No user-action blocker.
- Fresh Increment-188 CI must confirm Godot 4.7.1 parses the new reconciliation service/runner and that both dedicated persistence attack clusters pass together.
- 12F is still not complete. Persistence acceptance still needs hostile coverage for crash/interruption boundaries around durable Launch/Results writes, wider deterministic reconstruction/resume repetition, interrupted atomic-write generation survival, and additional cloud restore/replay interactions after already-applied completion.
- After the persistence acceptance list is exhausted, 12F must continue into the remaining non-persistence adversarial specification attacks before any 12G empirical gate work begins.
- If fresh CI exposes a concrete failure, the next run must inspect the first exact executable failure and make one focused repair batch only.

### Canonical contradictions
- **NONE discovered.**

## NEXT ACTION
At the start of the next run, inspect the exact Increment-188 `Phase 12F Persistence Adversarial`, `Godot Headless Tests`, and `Content Population Validator` workflows.

If any executable workflow is red, inspect the first exact executable failure and make one focused 12F repair batch only; do not stack speculative fixes.

If all executable workflows are green, take one substantial third 12F persistence attack cluster from `PHASE11_TECH_PERSISTENCE.md`:
1. attack crash/interruption boundaries around Launch and Results, including the profile-written/session-not-yet-updated Results window and interrupted atomic writes, proving at least one valid generation survives and completion cannot be re-awarded;
2. repeat deterministic reconstruction/resume aggressively (100+ same committed-input runs plus every valid playback cursor) and prove pause/speed/presentation metadata cannot alter authoritative tick/final hashes;
3. attack cloud restoration of an already-applied completion and same-lineage session lifecycle conflicts after permanent-profile merge, proving restored/stale state cannot roll back Bronze/medals or award the same completion twice.

Keep that cluster coherent and recoverable. When the persistence acceptance list is green, move 12F to the remaining adversarial gameplay/content/state-machine boundaries rather than beginning 12G prematurely.

Do not begin 12G until 12F adversarial acceptance has no known specification-breaking blocker.

Do not report overall completion until `IMPLEMENTATION COMPLETE = YES`.
