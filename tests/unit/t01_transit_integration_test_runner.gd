extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_t01_enters_production_phase_c_and_checksum()
	_test_s01_mitigates_t01_same_tick()
	_test_h05_modifies_t01_heat_in_phase_d()
	_test_replay_is_deterministic()
	if failures == 0:
		print("t01_transit_integration_test_runner: PASS")
		quit(0)
	else:
		push_error("t01_transit_integration_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_t01_enters_production_phase_c_and_checksum() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var with_t01: Dictionary = runner.simulate(_record(false), 1, _defs(true, false, false))
	var baseline: Dictionary = runner.simulate(_record(false), 1, _defs(false, false, false))
	_expect_true(bool(with_t01.get("ok", false)), "production transit accepts T01 authority")
	_expect_true(bool(baseline.get("ok", false)), "baseline production transit resolves")
	if not bool(with_t01.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var snapshot: Dictionary = with_t01["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["heat_by_cell"]["0,0"]), 3, "T01 Phase-C heat survives Phase-D publication")
	var organisms: Array = snapshot["organisms"]
	_expect_equal(int((organisms[0] as Dictionary).get("heat_exposure", -1)), 3, "Phase-E response consumes T01-generated heat")
	var events: Array = snapshot["phase_c_environment_events"]
	_expect_equal(events.size(), 1, "T01 emits one production Phase-C environmental event")
	if not events.is_empty():
		_expect_equal(String((events[0] as Dictionary).get("kind", "")), "T01_HEAT_SOURCE", "production evidence retains T01 source identity")
	_expect_true(String(with_t01["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "T01 authority changes deterministic checksum")

func _test_s01_mitigates_t01_same_tick() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(true), 1, _defs(true, true, false))
	_expect_true(bool(result.get("ok", false)), "T01 plus powered S01 production composition resolves")
	if not bool(result.get("ok", false)):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["heat_by_cell"]["0,0"]), 1, "S01 consumes T01 heat in the same Phase-C boundary before propagation")
	var support_events: Array = snapshot["phase_c_support_events"]
	_expect_equal(support_events.size(), 1, "same-tick S01 mitigation remains causal evidence")
	if not support_events.is_empty():
		_expect_equal(int((support_events[0] as Dictionary).get("removed_heat", -1)), 2, "S01 removes its authored capacity from T01 output")

func _test_h05_modifies_t01_heat_in_phase_d() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(false), 1, _defs(true, false, true))
	_expect_true(bool(result.get("ok", false)), "T01 remains composed on the H05 production path")
	if not bool(result.get("ok", false)):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["heat_by_cell"]["0,0"]), 2, "H05 Phase-D vent modifies already-generated T01 heat")
	var h05_events: Array = snapshot.get("h05_vent_events", [])
	_expect_equal(h05_events.size(), 1, "H05 evidence remains present beside T01 evidence")

func _test_replay_is_deterministic() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_record(true), 1, _defs(true, true, true))
	var second: Dictionary = runner.simulate(_record(true), 1, _defs(true, true, true))
	_expect_equal(first, second, "T01 production composition replays byte-equivalent")

func _record(with_cooler: bool) -> Dictionary:
	var supports: Array = []
	var priority: Array = []
	if with_cooler:
		supports = [{"instance_id": "cooler-a", "support_id": "S01", "anchor": [0, 0]}]
		priority = ["cooler-a"]
	return {
		"run_id": "t01-production-run",
		"rules_version": "rules-r1",
		"content_version": "t01-production-1",
		"canonical_committed_input": {
			"route_id": "route-t01-production",
			"seed": 101,
			"placements": [{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0}],
			"supports": supports,
			"brownout_priority": priority,
		},
	}

func _defs(include_t01: bool, with_cooler: bool, include_h05: bool) -> Dictionary:
	var events: Array = []
	var hazards: Dictionary = {}
	if include_h05:
		events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h05-heat", "authored_order": 0})
		hazards["h05-heat"] = {"id": "h05-heat", "family": "H05", "vent_delta_by_channel": {"heat": {"0,0": 1}}}
	var support_defs: Dictionary = {}
	if with_cooler:
		support_defs["S01"] = {"id": "S01", "family": "S01", "powered": true, "power_draw": 1, "heat_removal_capacity": 2}
	var defs: Dictionary = {
		"route_profile": {"id": "route-t01-production", "tick_count": 1, "events": events},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 1 if with_cooler else 0},
		"hazards_by_id": hazards,
		"support_definitions_by_id": support_defs,
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"organism_definitions": {
			"specimen-a": {
				"initial_stress": 0,
				"initial_state": "CALM",
				"stress_profile": {
					"heat_safe_max": 0,
					"stress_per_heat_unit": 1,
					"stress_min": 0,
					"stress_max": 20,
					"agitated_enter": 5,
					"agitated_exit": 3,
					"panic_enter": 10,
					"panic_exit": 7,
				},
			},
		},
	}
	if include_t01:
		defs["t01_definitions"] = [{"instance_id": "specimen-a", "output_amount": 3, "active_primary_states": ["CALM"], "sleep_gated": false}]
	return defs

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
