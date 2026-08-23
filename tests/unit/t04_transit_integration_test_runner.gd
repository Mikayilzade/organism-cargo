extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_t04_only_changes_internal_stress_in_production()
	_test_t04_and_environment_combine_before_phase_f_clamp()
	_test_source_state_gate_suppresses_soothing()
	_test_sleep_gate_is_explicit()
	_test_replay_is_deterministic()
	if failures == 0:
		print("t04_transit_integration_test_runner: PASS")
		quit(0)
	else:
		push_error("t04_transit_integration_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_t04_only_changes_internal_stress_in_production() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(), 1, _defs(true, false, "CALM", false))
	_expect_true(bool(result.get("ok", false)), "T04-only production run resolves without environmental stress source")
	if not bool(result.get("ok", false)):
		return
	var target: Dictionary = _runtime_by_id(result.get("final_organism_runtime", []), "target")
	_expect_equal(int(target.get("stress", -1)), 4, "T04 direct social reduction applies in Phase F")
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	var events: Array = snapshot.get("t04_soothing_events", [])
	_expect_equal(events.size(), 1, "T04 production path records one Phase-E soothing assignment")
	if not events.is_empty():
		_expect_equal(String((events[0] as Dictionary).get("kind", "")), "T04_SOOTHING_ASSIGNED", "T04 production evidence keeps trait identity")
	var response_events: Array = snapshot.get("stress_field_response_events", [])
	var found_parent: bool = false
	for raw_event: Variant in response_events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		if String(event.get("phase", "")) != "F" or String(event.get("instance_id", "")) != "target":
			continue
		_expect_equal(int(event.get("direct_stress_delta", 0)), -2, "Phase-F stress event exposes direct T04 contribution")
		var parents: PackedStringArray = event.get("parent_event_ids", PackedStringArray())
		for parent_id: String in parents:
			if parent_id.begins_with("t0001:E:T04:soother>target"):
				found_parent = true
	_expect_true(found_parent, "Phase-F target stress event retains T04 causal parent")

func _test_t04_and_environment_combine_before_phase_f_clamp() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(), 1, _defs(true, true, "CALM", false))
	_expect_true(bool(result.get("ok", false)), "T04 plus H02 production run resolves")
	if not bool(result.get("ok", false)):
		return
	var target: Dictionary = _runtime_by_id(result.get("final_organism_runtime", []), "target")
	_expect_equal(int(target.get("stress", -1)), 7, "H02 +3 exposure and T04 -2 aggregate to net +1 before Phase-F clamp")
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int((snapshot.get("t04_stress_delta_by_target_id", {}) as Dictionary).get("target", 0)), -2, "snapshot exposes deterministic T04 direct delta authority")

func _test_source_state_gate_suppresses_soothing() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_record(), 1, _defs(true, false, "AGITATED", false))
	_expect_true(bool(result.get("ok", false)), "state-ineligible T04 production run resolves")
	if not bool(result.get("ok", false)):
		return
	var target: Dictionary = _runtime_by_id(result.get("final_organism_runtime", []), "target")
	_expect_equal(int(target.get("stress", -1)), 6, "source outside authored state gate does not soothe")
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal((snapshot.get("t04_soothing_events", []) as Array).size(), 0, "state-ineligible source emits no T04 evidence")

func _test_sleep_gate_is_explicit() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var gated: Dictionary = runner.simulate(_record(), 1, _defs(true, false, "ASLEEP", true))
	var ungated: Dictionary = runner.simulate(_record(), 1, _defs(true, false, "ASLEEP", false))
	_expect_true(bool(gated.get("ok", false)) and bool(ungated.get("ok", false)), "sleep-gated and ungated T04 production runs resolve")
	if bool(gated.get("ok", false)):
		_expect_equal(int(_runtime_by_id(gated.get("final_organism_runtime", []), "target").get("stress", -1)), 6, "explicit sleep gate suppresses T04")
	if bool(ungated.get("ok", false)):
		_expect_equal(int(_runtime_by_id(ungated.get("final_organism_runtime", []), "target").get("stress", -1)), 4, "sleep alone does not suppress T04")

func _test_replay_is_deterministic() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_record(), 2, _defs(true, true, "CALM", false, 2))
	var second: Dictionary = runner.simulate(_record(), 2, _defs(true, true, "CALM", false, 2))
	_expect_equal(first, second, "T04 production replay is byte-equivalent")

func _record() -> Dictionary:
	return {
		"run_id": "t04-production-run",
		"rules_version": "rules-r1",
		"content_version": "t04-production-1",
		"canonical_committed_input": {
			"route_id": "route-t04-production",
			"seed": 404,
			"placements": [
				{"instance_id": "soother", "anchor": [0, 0], "orientation": 0},
				{"instance_id": "target", "anchor": [1, 0], "orientation": 0},
			],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _defs(include_t04: bool, include_h02: bool, soother_state: String, sleep_gated: bool, ticks: int = 1) -> Dictionary:
	var events: Array = []
	var hazards: Dictionary = {}
	if include_h02:
		events.append({"tick": 1, "duration_ticks": ticks, "hazard_id": "h02-target", "authored_order": 0})
		hazards["h02-target"] = {"id": "h02-target", "family": "H02", "stress_field_delta": 3, "target_cells": ["1,0"]}
	var defs: Dictionary = {
		"route_profile": {"id": "route-t04-production", "tick_count": ticks, "events": events},
		"hold_definition": {"dimensions": [2, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": hazards,
		"support_definitions_by_id": {},
		"organism_definitions": {
			"soother": {
				"initial_stress": 0 if soother_state in ["CALM", "ASLEEP"] else 6,
				"initial_state": soother_state,
				"stress_profile": _profile(),
			},
			"target": {
				"initial_stress": 6,
				"initial_state": "AGITATED",
				"stress_profile": _profile(),
			},
		},
	}
	if include_h02:
		defs["stress_field_rules"] = {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {"0,0": 0, "1,0": 0}}
	if include_t04:
		defs["t04_definitions"] = [{
			"instance_id": "soother",
			"amount": 2,
			"range": 1,
			"max_targets": 1,
			"eligible_target_ids": ["target"],
			"active_primary_states": ["CALM"],
			"sleep_gated": sleep_gated,
		}]
	return defs

func _profile() -> Dictionary:
	return {
		"stress_min": 0,
		"stress_max": 30,
		"agitated_enter": 5,
		"agitated_exit": 3,
		"panic_enter": 12,
		"panic_exit": 8,
	}

func _runtime_by_id(runtime_value: Variant, instance_id: String) -> Dictionary:
	if not runtime_value is Array:
		return {}
	for raw_organism: Variant in runtime_value:
		if raw_organism is Dictionary and String((raw_organism as Dictionary).get("instance_id", "")) == instance_id:
			return raw_organism
	return {}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
