# ORGANISM CARGO — PHASE 11 TECHNICAL PERSISTENCE CONTRACT

Status: **CANONICAL PHASE-11 FREEZE SUPPLEMENT — TECHNICAL/PERSISTENCE**
Last updated: 2026-08-15
Production code started: **NO**

This document closes the remaining persistence/idempotency/reconstruction ambiguity identified by `STATUS.md`. Until these rules are folded verbatim or semantically into `TECHNICAL_SPEC.md`, this file is the more specific Phase-11 authority for save, launch, transit reconstruction, Results/progression application, cloud reconciliation, migrations, legacy seeds and demo import. It adds no gameplay mechanic.

The implementation goal is simple: **one player commitment creates one immutable run identity; any number of duplicate callbacks, reloads, UI reopenings, cloud restores or process restarts may observe that run, but may not create a second launch or apply its progression twice.**

---

# 1. Stable identities

Every profile has immutable `profile_uuid`.

Every committed run has immutable `run_id` generated at successful Launch commit. `run_id` is a 128-bit UUID or equivalently collision-resistant stable identifier stored in the session envelope. It is not regenerated on resume, Review reopening, retry baseline loading, cloud restoration or Results reopening.

Every campaign completion application has a deterministic `completion_id`:

`completion_id = HASH(profile_uuid, run_id, contract_id, committed_result_checksum, rules_version, content_version)`

Every demo import operation has deterministic `import_id`:

`import_id = HASH(target_profile_uuid, demo_profile_uuid, demo_profile_revision, import_schema_version)`

Every migration execution records `(source_save_format_version, target_save_format_version, source_payload_checksum)` so the same source cannot be transformed twice as if it were two independent migrations.

---

# 2. Exactly-once Launch transaction

Launch is a transaction from editable `PlanningSession` to immutable `CommittedRun`.

Canonical sequence:
1. UI requests launch with a `launch_request_token` scoped to the current planning revision.
2. application state machine rejects the request unless state is `LAUNCH_CONFIRM`, structural legality is true, and no committed run already exists for that planning revision;
3. canonicalize all authoritative input: contract ID, route, manifest instance IDs/order, anchors/orientations, supports/links/power priority, initial states, seed, rules/content/generator versions;
4. compute `committed_input_checksum` over canonical serialization;
5. allocate `run_id` once;
6. write a complete `CommittedRunRecord` to `session.sav.tmp`, validate parse/checksum, then atomically replace `session.sav` while retaining backup generation;
7. only after the durable committed record exists, transition to `TRANSIT_PLAYBACK`;
8. duplicate launch UI events/callbacks for the same planning revision return the existing `run_id` and never allocate another run;
9. a crash after step 6 resumes the committed run; a crash before step 6 leaves the planning session uncommitted.

There is no state in which transit is considered authoritative while the only durable save still says “uncommitted planning”.

`CommittedRunRecord` minimum fields:
- profile UUID;
- run ID;
- contract ID;
- planning revision ID;
- canonical committed input;
- committed-input checksum;
- rules version;
- content version;
- generator version where relevant;
- expected contract-definition checksum;
- launch timestamp for recovery UX only;
- lifecycle state: `COMMITTED`, `SIMULATED`, `REVIEWABLE`, `COMPLETION_APPLIED`, `ABANDONED/INVALIDATED`;
- optional last presented tick cursor;
- final result checksum when known;
- completion ID when success result is known.

---

# 3. Deterministic transit reconstruction

Mutable mid-phase simulation objects are never the sole persistence authority.

On resume of `COMMITTED`, `SIMULATED` or `REVIEWABLE` run:
1. load committed input and compatibility versions;
2. verify envelope checksum and committed-input checksum;
3. resolve exact compatible rules/content definitions;
4. run the deterministic simulation from time zero;
5. recompute tick checksum sequence and final result checksum;
6. if stored final/checkpoint checksums exist, compare them;
7. reconstruct Causal Review indexes from authoritative event data;
8. restore presentation cursor to the highest fully presented stored tick or Review boundary; presentation state is not authoritative.

No resume path applies only “the remaining ticks” from a serialized mutable object unless a future optimization proves byte-for-byte semantic identity against reconstruction fixtures. The default contract remains full reconstruction because routes are short.

---

# 4. Checksum mismatch policy

Checksum mismatch is never ignored.

Classes:

## A. Presentation cursor mismatch only
Authoritative run checksums match; only saved playback position is invalid. Reset presentation to tick 0 or Review boundary without altering result/progression.

## B. Reconstructable compatibility mismatch
The save references a retained legacy rules/content package. Re-run under that exact compatibility package. If hashes match, continue normally.

## C. Authoritative reconstruction mismatch
Committed input is valid but reconstructed authoritative checksum differs from stored authoritative checksum under the claimed same rules/content version.

Required response:
- do not apply completion/progression from the suspect result;
- preserve the committed input and both checksum traces in recovery diagnostics;
- mark session `RECONSTRUCTION_MISMATCH`;
- offer `Restart this transit from committed layout` under current compatible canonical version only when that cannot silently change a previously granted completion;
- if completion had already been durably applied, preserve permanent progression and invalidate only the resumable session view;
- development/test builds fail loudly; release build uses explicit recovery messaging, never silent continuation.

## D. Missing compatibility package
If a legacy in-progress run references rules/content no longer executable, preserve the committed layout as a planning baseline, mark the old run invalidated, explain that the transit must restart under the current version, and do not fabricate the old outcome.

A completed historical contract never loses Bronze because an old replay can no longer be reconstructed.

---

# 5. Idempotent Results and progression application

Progression is a pure monotonic merge driven by `completion_id`, not by screen entry.

Profile stores `applied_completion_ids` or an equivalent compact durable ledger sufficient to reject duplicates.

Canonical success application:
1. authoritative simulation completes;
2. mandatory predicates and medals are finalized;
3. compute final result checksum;
4. if mandatory success is false, no campaign-clear completion is created;
5. if success is true, derive deterministic `completion_id`;
6. begin atomic profile transaction;
7. if `completion_id` already exists, return existing derived progression state with no new award;
8. otherwise merge: contract Bronze clear, best medal maxima, documented facts legitimately earned by this run, graph-derived unlock availability, achievements if their platform layer supports idempotent set semantics;
9. append `completion_id` to durable ledger;
10. write/verify/atomically replace profile save;
11. only then mark session lifecycle `COMPLETION_APPLIED` and persist it.

If process crashes after profile step 10 but before session step 11, reopening Results recomputes the same `completion_id`, sees it already applied, and only repairs session lifecycle state.

Reopening Results, entering/leaving Causal Review, pressing Continue repeatedly, duplicate animation callbacks, repeated Steam achievement callbacks and cloud restoration therefore cannot double-award anything.

Best medal merge is `max(existing, new)` by canonical Bronze < Silver < Gold order; it is never additive currency.

Codex/documentation facts are set-union flags with explicit source evidence; duplicates are harmless.

Campaign graph availability is derived from Bronze flags and canonical prerequisites, not stored as an independently incremented counter.

---

# 6. Retry identity

`Retry from last launch` does not reuse the old `run_id` as a new authoritative attempt.

It clones the old committed layout into a new editable PlanningSession baseline. Once the player commits again, a **new run_id** is created even if the arrangement is byte-identical. This preserves run history and prevents completion-ledger ambiguity.

Same committed input under two run IDs must still generate identical authoritative checksum sequences when rules/content/seed are identical.

---

# 7. Primary/backup corruption recovery

On boot/load:
1. validate primary envelope parse, schema, payload checksum and internal references;
2. if valid, load primary;
3. if invalid, validate newest backup generation;
4. if backup valid, load backup and create a fresh primary only after explicit recovery path is established;
5. if both invalid, enter `SAVE_RECOVERY`.

`SAVE_RECOVERY` offers only truthful choices:
- restore another validated local/cloud generation if available;
- export/retain corrupt files for support diagnostics where practical;
- create a new profile.

Never synthesize guessed campaign progress from partial/corrupt JSON. Never erase corrupt files before a replacement is successfully persisted.

Settings corruption resets only settings to defaults; it does not touch campaign/profile files.

---

# 8. Save migrations

Migrations are sequential and one-directional by declared schema chain, e.g. v3 -> v4 -> v5. Skipping a required intermediate migrator is invalid unless a direct migrator is explicitly tested.

Migration procedure:
1. copy source envelope to immutable recovery generation;
2. validate source checksum;
3. run migration in memory;
4. validate target schema plus campaign/content invariants;
5. serialize target to temp;
6. parse/checksum-verify target;
7. atomically install target;
8. retain source recovery generation until at least one subsequent validated save.

Failure at any step leaves source recoverable and enters explicit recovery messaging. A failed migration may not partially advance the stored format version.

Migration tests use fixed old-version fixtures and are rerunnable. Applying migration pipeline twice to an already-current save is a no-op.

Campaign migrations preserve monotonic permanent progress: cleared contracts, best medals and documented facts may be renamed/remapped only through explicit stable-ID migration tables; they may not be inferred from playtime or counters.

---

# 9. Cloud conflict policy

Newest timestamp alone is never enough to select a winner.

Cloud/local conflict handling distinguishes `profile.sav` from `session.sav`.

## Profile merge
When both profile envelopes are valid descendants of the same profile UUID and schema-compatible, merge only monotonic fields:
- Bronze cleared-contract set = union;
- best medal per contract = max;
- documented Codex facts = union;
- applied completion IDs = union;
- non-consumable permanent unlock flags = union when those flags are derivable/valid;
- campaign graph availability is re-derived after merge.

Do not merge fields that are not mathematically monotonic unless an explicit merge rule exists.

If profile UUIDs differ, present them as separate profiles; never merge automatically.

## Active session conflict
Never combine two divergent planning or committed-run sessions cell-by-cell.

If one session's run ID exists and the other is older same-lineage state, prefer the state whose lifecycle is strictly later only when committed-input checksum and run ID agree. Otherwise retain both recoverable copies and ask the player to choose via clear summary (contract, state, timestamp, device label if platform provides it).

Choosing a session cannot roll back already merged permanent profile progress.

Settings remain local by default.

---

# 10. Legacy generated seeds and versioned challenge codes

A challenge identity is at minimum `(template_id, seed, generator_version, rules_version, content_version)`.

If all compatibility versions are available, reconstruct exactly.

If versions differ and no compatibility package exists:
- show `Legacy challenge version`;
- do not silently regenerate a different puzzle from the same visible seed;
- archived featured seeds may map through an explicit authored migration table only if the resulting challenge is intentionally treated as a new version with a new identity;
- old completion/badge history remains historical and is never invalidated merely because the challenge can no longer regenerate.

Shared-code parser must reject malformed/unsupported versions before constructing gameplay state.

---

# 11. Demo -> full-game import

Canonical demo transfer is exactly the frozen boundary:
- settings may transfer;
- documented knowledge may transfer;
- D01–D08 may map to C01–C08 Bronze completion when mapping/version tables validate;
- D09–D10 never auto-clear C09+;
- no import grants mechanical power;
- imported knowledge/progress cannot unlock Challenge mode before the canonical C16/Tier-2 capstone gate.

Import is idempotent via `import_id` and monotonic merge semantics.

If target full profile already has more progress, import can only add valid union/max fields; it never overwrites stronger full-game state.

If demo/full content IDs diverged across versions, only explicit import mapping tables are legal. Unknown IDs are skipped with a recorded diagnostic; they are not guessed by names.

If shared Steam Cloud App ID is used, the same logical profile rules apply; “shared storage” does not bypass import/schema/version validation.

---

# 12. Acceptance tests — mandatory before design freeze can claim implementability

## Launch/idempotency
- double-click Launch, key repeat, controller repeat and duplicate callback all produce exactly one durable `run_id`;
- crash before durable commit returns to planning; crash after durable commit resumes same run;
- repeated Results opening applies one `completion_id` exactly once;
- crash after profile application but before session lifecycle update repairs state without re-award;
- platform achievement callback retries do not alter local progression more than once.

## Reconstruction
- same committed input run 100+ times produces identical tick checksum sequence;
- resume from every possible playback tick reconstructs same final result/causal graph;
- changing playback speed, pause, skip, reduced motion or audio settings never changes authoritative hashes;
- stored checksum mismatch follows explicit recovery class and never silently continues.

## Corruption/migration
- corrupt primary + valid backup recovers backup;
- corrupt primary + corrupt backup enters recovery/new-profile flow without guessed progress;
- interrupted atomic write retains at least one valid generation;
- each historical migration fixture reaches current schema with cleared contracts/medals/knowledge preserved;
- migration failure leaves original recovery copy intact;
- rerunning current migration pipeline is no-op.

## Cloud
- two compatible profile branches merge set/max fields without losing Bronze or best medals;
- two divergent active sessions are never auto-merged;
- different profile UUIDs remain separate;
- cloud restore of already-applied completion cannot award twice.

## Legacy/demo
- legacy challenge code either reproduces exact compatible challenge or is explicitly rejected as legacy; never silently changes puzzle;
- demo import can clear only mapped C01–C08;
- D09/D10 cannot clear C09+;
- imported knowledge cannot unlock Challenge mode before C16;
- repeating demo import is no-op beyond monotonic max/union state.

---

# 13. Freeze verdict for this domain

The technical persistence domain is now design-complete at the rule level. Remaining engineering choices such as the exact checksum algorithm, UUID library, binary/JSON save encoding and Steam Cloud wrapper remain implementation-flexible only if they satisfy every semantic invariant and acceptance test above.

No developer implementing persistence should need to invent what happens on duplicate launch, duplicate Results, crash boundaries, reconstruction mismatch, corruption, migration, cloud conflict, legacy challenge version or demo transfer.