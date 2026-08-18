# ORGANISM CARGO — PHASE 11 PROGRESSION RECONCILIATION

Status: **CANONICAL PHASE-11 FREEZE SUPPLEMENT — PROGRESSION/DEMO**
Last updated: 2026-08-15

This file supersedes vague progression wording in older Phase-7/9 sources until folded into them. It adds no economy.

## 1. Campaign authority

Campaign progression is Bronze-only. A campaign node unlocks when all exact prerequisites in the C01–C48 table frozen in `PHASE11_FREEZE.md` are Bronze-complete.

No implementation may replace that graph with “tier completion”, medal totals, contract-count totals, XP, money, challenge completion, achievements, retry counts or knowledge flags.

The phrase `exact authored dependencies are content data` in `ECONOMY_COMMERCIAL.md` is not discretionary authority. The exact data is already frozen in `PHASE11_FREEZE.md` and mirrored in `CONTENT_ARCHITECTURE.md`; implementation copies it without reinterpretation.

Capstones remain C08, C16, C24, C32, C40 and C48. Branches may affect which currently available contract the player chooses first, but they do not alter prerequisite truth.

## 2. Challenge-mode gate

Generated/recombined Challenge mode unlocks only after **C16 is Bronze-complete**, because C16 is the frozen Tier-2/Chapter-2 capstone.

`roughly the first 16 contracts`, `Tier-2 capstone`, and `Chapter-2 capstone` all mean the exact condition `Bronze(C16) == true`.

Imported demo knowledge, extra medals, clearing D09/D10, Codex completion, achievements or a high contract-clear count cannot unlock Challenge mode early.

Challenge templates inside the mode may additionally require that their referenced rule families are documented, but documentation can restrict individual template availability only after the mode itself is unlocked; it cannot bypass or replace the C16 gate.

## 3. Demo transfer

Demo profile transfer is monotonic and idempotent.

Allowed:
- settings transfer;
- Codex/documented knowledge transfer where stable IDs/version mappings validate;
- D01–D08 -> C01–C08 Bronze mapping only;
- best medal mapping for those same mapped nodes when medal semantics are compatible;
- explicit cosmetic/profile recognition that gives no power.

Forbidden:
- D09/D10 auto-clearing C09 or any later campaign node;
- demo completion unlocking C09+ by contract-count logic;
- demo knowledge unlocking Challenge mode before C16;
- any stat, currency, support quantity or mechanical power bonus;
- replacing stronger full-game progress with weaker demo state.

## 4. Medal authority

Bronze = mandatory delivery success and is the sole campaign-clear state.
Silver/Gold are optional mastery evidence.

Silver/Gold never gate:
- campaign nodes;
- chapter transitions;
- Challenge mode;
- species required for campaign;
- supports required for campaign;
- mandatory Codex knowledge;
- save/accessibility features.

Medals are maxima, not spendable currency.

## 5. Progression persistence

Permanent progression is monotonic:
- cleared Bronze set: union;
- best medals: per-contract max;
- documented knowledge: union;
- challenge-template availability: re-derived from C16 gate + documented-rule requirements;
- campaign-node availability: re-derived from exact frozen graph.

The save system must not persist independent unlock counters whose values can drift away from these source truths.

## 6. Acceptance tests

Mandatory tests:
1. fresh profile exposes only C01;
2. every C01–C48 node unlocks exactly when its frozen prerequisites become Bronze;
3. Silver/Gold changes never unlock a campaign node by themselves;
4. C16 Bronze unlocks Challenge mode; C15 plus any number of medals/knowledge does not;
5. demo import can mark only mapped C01–C08 Bronze;
6. D09/D10 do not clear C09+;
7. imported knowledge with C16 uncleared does not unlock Challenge mode;
8. cloud/profile merge re-derives node availability from merged Bronze set and cannot create impossible graph state;
9. retry/failure never removes permanent progression;
10. replaying a cleared contract is never required for currency/XP because neither exists.

## 7. Freeze verdict

Progression, Challenge gating and demo transfer now have exact implementation semantics. Remaining price, title, discount timing and store-art choices remain commercially flexible and do not affect design freeze.