extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_t03_only_enters_production_stress_path()
	_test_h02_and_t03_add_before_phase_d()
	_test_h05_applies_after_t03()
	_test_state_gate_suppresses_ineligible_source()
	_test_replay_is_deterministic()
	if failures == 0:
		print("t03_transit_integration_test_runner: PASS")
		quit(0)
	else:
		push_error("t03_transit_integration_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_t03_only_enters_production_stress_path() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var with_t03: Dictionary = runner.simulate(_record(), 1, _defs(true, false, false, "AGITATED"))
	var baseline: Dictionary = runner.simulate(_record(), 1, _defs(false, false, false, "AGITATED"))
	_expect_true(bool(with_t03.get("ok", false)), "production transit accepts T03 without requiring H02")
	_expect_true(bool(baseline.get("ok", false)), "baseline production transit resolves")
	if not bool(with_t03.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var snapshot: Dictionary = with_t03["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["stress_field_by_cell"]["0,0"]), 2, "T03 source enters Phase C before authored Phase-D decay")
	var events: Array = snapshot.get("stress_field_source_events", [])
	_expect_equal(events.size(), 1, "T03-only production path records one source event")
	if not events.is_empty():
		_expect_equal(String((events[0] as Dictionary).get("kind", "")), "T03_STRESS_FIELD_SOURCE", "T03 production evidence retains source identity")
	_expect_true(String(with_t03["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "T03 source authority is checksum-visible")
	var final_runtime: Array = with_t03.get("final_organism_runtime", [])
	_expect_true(not final_runtime.is_empty(), "T03 production result retains organism runtime")
	if not final_runtime.is_empty():
		_expect_true(int((final_runtime[0] as Dictionary).get("stress", 0)) >= 2, "internal stress changes only through downstream stress-field response")

func _test_h02_and_t03_add_before_phase_d() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(), 1, _defs(true, true, false, "AGITATED"))
	_expect_true(bool(result.get("ok", false)), "H02 plus T03 production composition resolves")
	if not bool(result.get("ok", false)):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["stress_field_by_cell"]["0,0"]), 4, "H02 and T03 add in Phase C before one Phase-D decay")
	var events: Array = snapshot.get("stress_field_source_events", [])
	_expect_equal(events.size(), 2, "H02 and T03 both remain checksum-visible source evidence")
	if events.size() == 2:
		_expect_equal(String((events[0] as Dictionary).get("kind", "")), "H02_STRESS_FIELD_SOURCE", "route stress source resolves before living alarm source")
		_expect_equal(String((events[1] as Dictionary).get("kind", "")), "T03_STRESS_FIELD_SOURCE", "T03 follows H02 inside Phase C")

func _test_h05_applies_after_t03() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(), 1, _defs(true, false, true, "AGITATED"))
	_expect_true(bool(result.get("ok", false)), "T03 plus H05 production composition resolves without H02")
	if not bool(result.get("ok", false)):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["stress_field_by_cell"]["0,0"]), 1, "H05 adds Phase-D decay after T03 Phase-C generation")
	var h05_events: Array = snapshot.get("h05_vent_events", [])
	var found: bool = false
	for raw_event: Variant in h05_events:
		if raw_event is Dictionary and String((raw_event as Dictionary).get("channel", "")) == "stress_field":
			found = true
			break
	_expect_true(found, "T03/H05 production path retains stress-field H05 evidence")

func _test_state_gate_suppresses_ineligible_source() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(), 1, _defs(true, false, false, "CALM"))
	_expect_true(bool(result.get("ok", false)), "state-ineligible T03 production run resolves")
	if not bool(result.get("ok", false)):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["stress_field_by_cell"]["0,0"]), 0, "CALM source does not emit when T03 is authored for AGITATED")
	_expect_equal((snapshot.get("stress_field_source_events", []) as Array).size(), 0, "ineligible T03 emits no source evidence")

func _test_replay_is_deterministic() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_record(), 2, _defs(true, true, true, "AGITATED", 2))
	var second: Dictionary = runner.simulate(_record(), 2, _defs(true, true, true, "AGITATED", 2))
	_expect_equal(first, second, "T03 production composition replays byte-equivalent")

func _record() -> Dictionary:
	return {
		"run_id": "t03-production-run",
		"rules_version": "rules-r1",
		"content_version": "t03-production-1",
		"canonical_committed_input": {
			"route_id": "route-t03-production",
			"seed": 303,
			"placements": [{"instance_id": "alarm-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _defs(include_t03: bool, include_h02: bool, include_h05: bool, initial_state: String, ticks: int = 1) -> Dictionary:
	var events: Array = []
	var hazards: Dictionary = {}
	if include_h02:
		events.append({"tick": 1, "duration_ticks": ticks, "hazard_id": "h02-stress", "authored_order": 0})
		hazards["h02-stress"] = {"id": "h02-stress", "family": "H02", "stress_field_delta": 2, "target_cells": ["0,0"]}
	if include_h05:
		events.append({"tick": 1, "duration_ticks": ticks, "hazard_id": "h05-stress", "authored_order": 1})
		hazards["h05-stress"] = {"id": "h05-stress", "family": "H05", "vent_delta_by_channel": {"stress_field": {"0,0": 1}}}
	var defs: Dictionary = {
		"route_profile": {"id": "route-t03-production", "tick_count": ticks, "events": events},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": hazards,
		"support_definitions_by_id": {},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {"0,0": 1}},
		"organism_definitions": {
			"alarm-a": {
				"initial_stress": 6 if initial_state == "AGITATED" else 0,
				"initial_state": initial_state,
				"stress_profile": {
					"stress_min": 0,
					"stress_max": 30,
					"agitated_enter": 5,
					"agitated_exit": 3,
					"panic_enter": 12,
					"panic_exit": 8,
				},
			},
		},
	}
	if include_t03:
		defs["t03_definitions"] = [{
			"instance_id": "alarm-a",
			"output_amount": 3,
			"active_primary_states": ["AGITATED"],
			"sleep_gated": false,
		}]
	return defs

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
