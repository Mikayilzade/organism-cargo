extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_t02_removes_current_local_heat_in_production_phase_c()
	_test_t01_then_t02_share_same_phase_c_authority()
	_test_t02_then_s01_stack_before_phase_d()
	_test_h05_consumes_post_t02_heat_authority()
	_test_replay_is_deterministic()
	if failures == 0:
		print("t02_transit_integration_test_runner: PASS")
		quit(0)
	else:
		push_error("t02_transit_integration_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_t02_removes_current_local_heat_in_production_phase_c() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var with_t02: Dictionary = runner.simulate(_record(false), 1, _defs(false, true, false, false))
	var baseline: Dictionary = runner.simulate(_record(false), 1, _defs(false, false, false, false))
	_expect_true(bool(with_t02.get("ok", false)), "production transit accepts T02 authority")
	_expect_true(bool(baseline.get("ok", false)), "H01 baseline production transit resolves")
	if not bool(with_t02.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var snapshot: Dictionary = with_t02["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["heat_by_cell"]["0,0"]), 3, "T02 removes its local capacity before Phase-D publication")
	var events: Array = snapshot["phase_c_environment_events"]
	_expect_equal(events.size(), 1, "T02 emits one production Phase-C environmental event")
	if not events.is_empty():
		var event: Dictionary = events[0]
		_expect_equal(String(event.get("kind", "")), "T02_HEAT_SINK", "production evidence retains T02 sink identity")
		_expect_equal(int(event.get("removed_heat", -1)), 3, "production evidence records exact removed heat")
	_expect_true(String(with_t02["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "T02 authority changes deterministic checksum")

func _test_t01_then_t02_share_same_phase_c_authority() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(false), 1, _defs(true, true, false, false))
	_expect_true(bool(result.get("ok", false)), "T01 plus T02 production composition resolves")
	if not bool(result.get("ok", false)):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["heat_by_cell"]["0,0"]), 6, "T01 source is available to bounded T02 sink in the same Phase-C boundary")
	var events: Array = snapshot["phase_c_environment_events"]
	_expect_equal(events.size(), 2, "T01 and T02 both retain checksum-visible Phase-C evidence")
	if events.size() == 2:
		_expect_equal(String((events[0] as Dictionary).get("kind", "")), "T01_HEAT_SOURCE", "living heat source resolves before living sink")
		_expect_equal(String((events[1] as Dictionary).get("kind", "")), "T02_HEAT_SINK", "living sink follows source inside Phase C")

func _test_t02_then_s01_stack_before_phase_d() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(true), 1, _defs(false, true, true, false))
	_expect_true(bool(result.get("ok", false)), "T02 plus powered S01 production composition resolves")
	if not bool(result.get("ok", false)):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["heat_by_cell"]["0,0"]), 0, "living T02 sink and powered S01 mitigation both act before Phase D")
	var environment_events: Array = snapshot["phase_c_environment_events"]
	var support_events: Array = snapshot["phase_c_support_events"]
	_expect_equal(environment_events.size(), 1, "T02 remains living environmental evidence rather than support evidence")
	_expect_equal(support_events.size(), 1, "S01 remains distinct powered-support evidence")
	if not support_events.is_empty():
		_expect_equal(int((support_events[0] as Dictionary).get("removed_heat", -1)), 3, "S01 consumes only heat remaining after T02")

func _test_h05_consumes_post_t02_heat_authority() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(false), 1, _defs(false, true, false, true))
	_expect_true(bool(result.get("ok", false)), "T02 remains composed on the H05 production path")
	if not bool(result.get("ok", false)):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["heat_by_cell"]["0,0"]), 2, "H05 Phase-D vent applies after T02 Phase-C removal")
	var h05_events: Array = snapshot.get("h05_vent_events", [])
	_expect_equal(h05_events.size(), 1, "H05 evidence remains present beside T02 evidence")

func _test_replay_is_deterministic() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_record(true), 1, _defs(true, true, true, true))
	var second: Dictionary = runner.simulate(_record(true), 1, _defs(true, true, true, true))
	_expect_equal(first, second, "T02 production composition replays byte-equivalent")

func _record(with_cooler: bool) -> Dictionary:
	var supports: Array = []
	var priority: Array = []
	if with_cooler:
		supports = [{"instance_id": "cooler-a", "support_id": "S01", "anchor": [0, 0]}]
		priority = ["cooler-a"]
	return {
		"run_id": "t02-production-run",
		"rules_version": "rules-r1",
		"content_version": "t02-production-1",
		"canonical_committed_input": {
			"route_id": "route-t02-production",
			"seed": 202,
			"placements": [{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0}],
			"supports": supports,
			"brownout_priority": priority,
		},
	}

func _defs(include_t01: bool, include_t02: bool, with_cooler: bool, include_h05: bool) -> Dictionary:
	var events: Array = [
		{"tick": 1, "duration_ticks": 1, "hazard_id": "h01-heat", "authored_order": 0},
	]
	var hazards: Dictionary = {
		"h01-heat": {"id": "h01-heat", "family": "H01", "target_scope": "hold", "heat_delta": 6},
	}
	if include_h05:
		events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h05-heat", "authored_order": 1})
		hazards["h05-heat"] = {"id": "h05-heat", "family": "H05", "vent_delta_by_channel": {"heat": {"0,0": 1}}}
	var support_defs: Dictionary = {}
	if with_cooler:
		support_defs["S01"] = {"id": "S01", "family": "S01", "powered": true, "power_draw": 1, "heat_removal_capacity": 3}
	var defs: Dictionary = {
		"route_profile": {"id": "route-t02-production", "tick_count": 1, "events": events},
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
	if include_t02:
		defs["t02_definitions"] = [{"instance_id": "specimen-a", "capacity": 3, "active_primary_states": ["CALM"], "sleep_gated": false}]
	return defs

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
