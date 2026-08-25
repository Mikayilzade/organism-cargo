# PHASE 12F ADVERSARIAL COVERAGE RECONCILIATION

Status: **12F CLOSURE AUDIT COMPLETE — INCREMENT 198**

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

## Authored-content / dominance coverage

`AuthoredContentAdversarialValidator` and its hostile runner turn every objectively representable Phase-10/11 anti-dominance gate currently encoded in authoritative content into executable checks without inventing a hidden score or solver:

- C17–C48 Cooler+Filter joint availability is a conservative upper bound on certified-primary dependence and must remain <=8. Current upper bound: **1**.
- Every Chapter 3–6 contains an explicit Cooler/Filter-inferior counterexample backed by authored reason text.
- Every Chapter 3–6 contains at least two explicit maximum-spacing counterexamples.
- Permanent growth-corner counterexamples are required in Chapter 3 >=1, Chapter 4 >=1 and Chapter 6 >=2.
- Chapters 4–6 retain explicit helper/protector downside or familiar-helper-inferior evidence.
- Generated challenge policy forbids pure maximum-spacing as best, preserves dynamic/timing significance, stays within declared similarity bounds, and enforces the frozen <=3 identical powered-pair streak.
- Repeating the exact same soother species in the same generated family/fingerprint role more than three times is rejected.
- Hostile mutations prove each gate fails closed rather than merely checking the current happy-path corpus.

## Final Increment-198 closure audit

Increment 197 was inspected on exact head `99f9afff5d2f6776889f2fa672c9bf016e61aff5`. All six workflows completed successfully, including `Phase 12F Authored Content Dominance Adversarial`, `Phase 12F Simulation Timing Adversarial`, `Godot Headless Tests`, `Content Population Validator`, `Phase 12F Persistence Adversarial`, and `Phase 12F State Planning Campaign Adversarial`.

A repository-wide code/content search was then performed for authoritative certified-solution geometry and the exact derived metrics needed by the remaining Phase-10 content attacks: `isolation_ratio`, `beneficial_relation_count`, normalized role-to-zone allocation, certified Bronze solution geometry, and equivalent solution-geometry metadata. No such authoritative solution corpus or derived metric source exists in the repository.

Therefore the following cannot be promoted into deterministic 12F assertions without inventing a solver score or fabricating solution data:

- exact authored `isolation_ratio` and `beneficial_relation_count` for certified Bronze solution families;
- normalized authored primary-Bronze role-to-zone allocation streaks.

These are **not implementation defects** in the existing deterministic game/runtime. They are validation obligations whose required evidence is certified solution geometry that does not presently exist. Creating synthetic geometry solely to make the audit green would violate the frozen no-new-design/no-fake-evidence rule.

The >=70% preferred-placement/support/revision similarity threshold for O06/O12/O16 and O05/O19/O20 is explicitly representative preference/playtest evidence and is empirical by definition.

## Deterministic-vs-empirical classification

After the final hostile audit, no known objectively testable Phase-11 adversarial requirement remains uncovered by deterministic implementation where the required authoritative inputs exist.

The unresolved obligations are classified as Phase-12G empirical/prototype evidence:

1. >=70% of representative failures yield a specific causal explanation plus intended revision rather than blind shuffle.
2. >=50% of memorable outcomes depend on post-launch change.
3. Ordinary first-launch planning median <=8 minutes after familiarity.
4. Helper/protector species decision distinctness keep/cut evidence, including the >=70% preferred-decision similarity gate.
5. Demo identity description favors planning for transit behavior over static packing.
6. Causal Review surfaces an actionable first cause without raw-log reading.
7. Authored certified-Bronze isolation/beneficial-relation and normalized role-to-zone metrics remain evidence-dependent on a future certified solution corpus; they must be measured in 12G if/when that corpus is produced, not guessed in 12F.

## 12F closure decision

- Increment-197 executable CI: **GREEN**.
- Known deterministic adversarial gaps with available authoritative inputs: **NONE**.
- Remaining unresolved items: **EMPIRICAL / EVIDENCE-DEPENDENT 12G GATES**.
- Phase 12F: **COMPLETE**.

The next implementation run should begin Phase 12G by building the smallest evidence-capture/validation harness that can record representative failure explanation + intended revision, memorable post-launch-change attribution, planning-time samples, species-cluster decision choices, demo identity response, and Causal Review first-cause usability without changing gameplay rules. The harness must separate captured observations from pass/fail thresholds and must not synthesize human evidence.