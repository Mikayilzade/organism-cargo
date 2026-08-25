# PHASE 12F ADVERSARIAL COVERAGE RECONCILIATION

Status: **LIVE 12F CLOSURE MAP — INCREMENT 197**

This document reconciles implemented hostile coverage against the Phase-11 final implementation-readiness index. It is an implementation QA map, not a design amendment. `PHASE11_FINAL_FREEZE.md` remains the highest authority.

## Covered deterministic obligations

1. **First boot / campaign / Challenges** — content population, authored chapter tests, campaign progression gate, shell boot, and Phase-12F state/planning/campaign hostile coverage validate the exact C01–C48 graph and Bronze(C16) Challenge gate.
2. **Exactly-once Launch / durable run identity** — launch commit tests plus Phase-12F persistence attacks cover duplicate requests and durable run ownership.
3. **Transit reconstruction / resume** — transit reconstruction, save recovery, crash/resume and compatibility hostile suites cover immutable committed input, cursor reconstruction and fail-closed version mismatch.
4. **Exactly-once completion / progression** — results progression and persistence reconciliation suites cover deterministic completion identity and idempotent permanent writes.
5. **A–I timing / Brownout / causal determinism** — core simulation suite plus Phase-12F simulation-timing attacks cover same-tick authority, Brownout order invariance, H02 wake ordering, blocked-growth episode boundaries and malformed timing inputs.
6. **Campaign/demo monotonicity** — state/campaign and reconciliation hostile suites cover Bronze prerequisites, demo D01–D08 mapping bounds, D09/D10 non-transfer and Challenge re-derivation.
7. **Mandatory input/accessibility** — completed Phase-12E acceptance covers keyboard/controller/Deck, remapping, maximum scale, preflight, no-audio/non-color critical signaling, Reduced Motion/Flashing, Retry/Reset/map, Codex and recovery/completion surfaces.
8. **Persistence/cloud/profile semantics** — Phase-12F persistence, crash/resume, compatibility and reconciliation suites cover atomic generations, corrupted primary recovery, profile UUID separation, monotonic cloud merge, active-session conflict retention, migration source preservation and legacy challenge rejection.

## Increment-197 authored-content / dominance coverage

`AuthoredContentAdversarialValidator` and its hostile runner now turn the objectively representable Phase-10/11 anti-dominance gates into executable checks without inventing a hidden score or solver:

- C17–C48 Cooler+Filter joint availability is treated as a conservative upper bound on certified-primary dependence and must remain <=8. Current upper bound: **1**.
- Every Chapter 3–6 must contain an explicit Cooler/Filter-inferior counterexample backed by authored reason text.
- Every Chapter 3–6 must contain at least two explicit maximum-spacing counterexamples.
- Permanent growth-corner counterexamples are required in Chapter 3 >=1, Chapter 4 >=1 and Chapter 6 >=2.
- Chapters 4–6 must retain explicit helper/protector downside or familiar-helper-inferior evidence.
- Generated challenge policy must forbid pure maximum-spacing as best, preserve dynamic/timing significance, stay within declared similarity bounds, and enforce the frozen <=3 identical powered-pair streak.
- Repeating the exact same soother species in the same generated family/fingerprint role more than three times is rejected.
- Hostile mutations explicitly prove each gate fails closed rather than merely checking the current happy-path data.

## Honest non-inferred gaps

The following requirements are not converted into fake pass/fail assertions because the repository does not currently contain the required certified solution geometry or representative preference/playtest dataset:

- exact authored `isolation_ratio` and `beneficial_relation_count` for certified Bronze solution families;
- normalized authored primary-Bronze role-to-zone allocation streaks;
- the >=70% species redundancy preferred-placement/support/revision similarity test for O06/O12/O16 and O05/O19/O20.

The first two require solver/certified-solution geometry if they are to become deterministic 12F checks. The redundancy threshold is explicitly prototype/representative-evidence dependent and belongs with empirical validation unless a certified solution corpus is authored first.

## Phase-12G empirical gates deliberately not claimed here

These remain empirical prototype obligations from `PHASE11_FINAL_FREEZE.md`, not missing deterministic implementation rules:

- >=70% of representative failures yield a specific causal explanation plus intended revision rather than blind shuffle;
- >=50% of memorable outcomes depend on post-launch change;
- ordinary first-launch planning median <=8 minutes after familiarity;
- helper/protector species decision distinctness keep/cut evidence;
- demo identity description favors planning for transit behavior over static packing;
- Causal Review surfaces an actionable first cause without raw-log reading.

## 12F closure rule

12F may be marked complete only after Increment-197 executable CI is green and a final hostile audit confirms that no objectively testable Phase-11 adversarial obligation remains uncovered. Any remaining item must be classified explicitly as either:

1. a deterministic implementation gap to repair before 12G; or
2. an empirical Phase-12G gate requiring prototype/playtest evidence.

Do not use this reconciliation to waive a deterministic requirement, and do not invent synthetic scores merely to turn an empirical gate green.
