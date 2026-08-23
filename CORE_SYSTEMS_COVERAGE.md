# ORGANISM CARGO — 12C CORE SYSTEMS COVERAGE INVENTORY

Status: **ACTIVE EXIT-GATE INVENTORY**
Date: 2026-08-23
Authority: `PHASE11_FINAL_FREEZE.md` -> frozen Phase-11 supplements -> domain canon.

This document maps frozen core-system obligations to concrete production authority and automated proof. It is an implementation inventory, not a design document.

## 1. Tick/order and global deterministic rules

| Obligation | Production authority | Existing proof | State |
|---|---|---|---|
| A–I deterministic phase order | transit runner chain / `transit_slice_runner.gd` | transit slice + vertical-slice deterministic replay | GREEN |
| Phase-A Brownout same-tick authority | `phase_a_power_resolver.gd`, production transit power chain | `phase_a_power_resolver_test_runner.gd`, H05/other production transit tests | GREEN |
| Phase-B growth legality | `phase_b_growth_resolver.gd` | `phase_b_growth_test_runner.gd` | GREEN |
| unchanged blocked-growth episode fires once | `blocked_growth_episode_resolver.gd` | `blocked_growth_episode_test_runner.gd` | GREEN |
| explicit sleep gating only | trait kernels + `sleep_wake_kernel.gd` | sleep/wake, T01, T02, T03, T04 focused contracts | GREEN |
| simultaneous/additive deterministic effects | channel and internal-response composition | T03 H02-addition, T04 direct+field aggregation, T10 carry/reconsumption | GREEN |
| deterministic replay/checksums | transit chain | vertical-slice replay plus subsystem replay tests | GREEN |

## 2. Trait families T01–T10

| Trait | Production authority | Focused proof | Production proof | State |
|---|---|---|---|---|
| T01 Heat Emitter | `t01_heat_emitter_kernel.gd` + production thermal transit | T01 kernel | `t01_transit_integration_test_runner.gd` | GREEN |
| T02 Heat Sink | `t02_heat_sink_kernel.gd` + production thermal transit | T02 kernel | `t02_transit_integration_test_runner.gd` | GREEN |
| T03 Alarm Emitter | `t03_alarm_emitter_kernel.gd` + T03 stress-field production layer | T03 kernel | `t03_transit_integration_test_runner.gd` | GREEN |
| T04 Soother | `t04_soother_kernel.gd` + stress response Phase-E/F/G chain | T04 kernel | `t04_transit_integration_test_runner.gd` | GREEN after Increment 145 CI |
| T05 Spore Shedder | `t05_spore_shedder_kernel.gd`, integrated in `transit_shared_resource_runner_base.gd` before H03 Phase C | no dedicated workflow contract | no dedicated production contract | **PROOF GAP** |
| T06 Filter Feeder | `t06_filter_feeder_kernel.gd`, shared-resource production chain | T06 kernel | no dedicated named production transit contract | **PROOF GAP** |
| T07 Feeding | `t07_feeding_kernel.gd`, shared-resource production chain | T07 kernel | shared-resource/S05/T10 paths exercise it, but no dedicated named production contract | **PROOF GAP** |
| T08 Growth | `t08_growth_qualifier.gd` + Phase-B growth resolver | T08 qualifier + Phase-B growth | real-data/transit growth coverage | GREEN |
| T09 Symbiotic Buffer | `t09_symbiotic_buffer_kernel.gd`, integrated in `transit_contamination_integrated_runner.gd` | T09 kernel | no dedicated named production transit contract | **PROOF GAP** |
| T10 Reactive Pulse | T10 kernel + layered production transit effect/carry/reconsumption chain | T10 kernel | multiple T10 production/carry/reconsumption contracts | GREEN |

The material trait implementation gap is therefore not a missing T05/T06/T07/T09 production code path; all four already have production integration authority. The remaining exit-gate weakness is explicit end-to-end proof that those integrations preserve phase order, conservation/targeting, checksum visibility and deterministic replay through the real production runner.

## 3. Support families S01–S06

| Support | Production authority | Proof state |
|---|---|---|
| S01 Cooler | shared-resource Phase-C production chain | focused S01 + production thermal/H05 composition; GREEN |
| S02 Filter | shared-resource contamination Phase-C production chain | focused S02 + production contamination composition; GREEN |
| S03 Baffle | stress-field production boundary transform | focused S03 + stress production paths; GREEN |
| S04 Nest Pad | Phase-B lifecycle integration in stress-response production chain | named production composition contract; GREEN |
| S05 Feed Cartridge | `transit_shared_resource_runner.gd` converts installed S05 into finite T07 producer authority | focused finite-reserve contract; production path exists; strengthen together with T07 proof |
| S06 Monitor Beacon | `transit_monitor_integrated_runner.gd` | focused information-only contract; production path exists; GREEN for core mechanics |

## 4. Hazard families / environmental authority

| Hazard/core route rule | Production authority | Proof state |
|---|---|---|
| H01 Thermal Surge / heat source | thermal transit + thermal response | GREEN |
| H02 Vibration/stress-field source + wake request | stress-field + sleep/wake production chain | GREEN |
| H03 Contamination source | contamination environment/response production chain | GREEN |
| H04 Brownout | Phase-A power resolver | GREEN |
| H05 Vent Cycle | common Phase-D resolver / H05 production bridges | named production contract; GREEN |
| H06 Zone Isolation | H06 Phase-D bridges | focused propagation contract + production bridge inheritance; GREEN |

## 5. Persistence, lifecycle and result authority

| Obligation | Authority/proof | State |
|---|---|---|
| exactly-once Launch / durable run identity | `launch_commit_service.gd` + launch commit tests | GREEN |
| deterministic reconstruction/mismatch policy | `transit_reconstruction_service.gd` + reconstruction tests | GREEN |
| atomic content/save storage | `atomic_save_store.gd` + storage/content tests | GREEN |
| idempotent Results/progression | `results_progression_service.gd` + progression tests | GREEN |
| Planning -> durable Launch | planning flow tests | GREEN |
| completion/fail handoff | delivery completion tests | GREEN |
| Targeted Retry identity/ownership | targeted retry tests | GREEN |
| causal evidence | causal review evidence builder/tests + checksum-visible subsystem evidence | GREEN |

## 6. CI integrity

The authoritative workflow now treats a Godot `SCRIPT ERROR:` / failed script load as a failed custom status even when Godot exits with code 0. This closes the previously observed false-green class and makes this inventory meaningful.

## 7. Remaining 12C exit work

Priority repair batch before 12C can close:

1. Add a dedicated T05 production contract proving living spore generation composes with H03 in Phase C, propagates once through Phase D, is checksum-visible and deterministic.
2. Add a shared-resource production contract for T06 + T07 + S05 proving conservation, compatibility/capacity allocation, finite reserve and deterministic replay through `TransitPowerIntegratedRunner`.
3. Add a T09 production contract proving the authored one-target resistance modifier is applied in the contamination response path, remains narrow/non-universal, checksum-visible and deterministic.
4. Re-run the full hardened suite. If green, re-evaluate this inventory for any uncovered persistence/interaction edge and only then mark the 12C exit gate complete.

No 12D content-population work is authorized until these proof gaps are green or explicitly demonstrated redundant by stronger existing production tests.
