extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_once_per_run_heat_pulse_is_not_reapplied_on_tick_three()
	if failures == 0:
		print("t10_once_carry_test_runner: PASS")
		quit(0)
	else:
		push_error("t10_once_carry_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_once_per_run_heat_pulse_is_not_reapplied_on_tick_three() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _defs()
	var baseline_defs: Dictionary = defs.duplicate(true)
	baseline_defs.erase("t10_definitions")
	var result: Dictionary = runner.simulate(_record("with-t10"), 3, defs)
	var replay: Dictionary = runner.simulate(_record("with-t10"), 3, defs)
	var baseline: Dictionary = runner.simulate(_record("baseline"), 3, baseline_defs)
	_expect_true(bool(result.get("ok", false)), "three-tick T10 production run resolves | error=%s" % String(result.get("error", "")))
	_expect_equal(result, replay, "three-tick T10 replay is deterministic")
	_expect_true(bool(baseline.get("ok", false)), "three-tick baseline resolves")
	if not bool(result.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var snapshots: Array = result.get("end_tick_snapshots", [])
	var baseline_snapshots: Array = baseline.get("end_tick_snapshots", [])
	_expect_equal(snapshots.size(), 3, "T10 production result has three ticks")
	_expect_equal(baseline_snapshots.size(), 3, "T10 production baseline has three ticks")
	if snapshots.size() != 3 or baseline_snapshots.size() != 3:
		return

	var tick_two: Dictionary = snapshots[1]
	var baseline_tick_two: Dictionary = baseline_snapshots[1]
	var tick_two_thermal: Dictionary = _find_thermal(tick_two.get("organisms", []), "cargo-a")
	var baseline_tick_two_thermal: Dictionary = _find_thermal(baseline_tick_two.get("organisms", []), "cargo-a")
	_expect_true(not tick_two_thermal.is_empty() and not baseline_tick_two_thermal.is_empty(), "tick-2 thermal evidence exists")
	if not tick_two_thermal.is_empty() and not baseline_tick_two_thermal.is_empty():
		var expected_tick_two: int = mini(20, int(baseline_tick_two_thermal.get("heat_exposure", 0)) + 4)
		_expect_equal(int(tick_two_thermal.get("heat_exposure", -1)), expected_tick_two, "tick-1 Phase-H pulse is consumed at tick-2")
	_expect_true(not (tick_two.get("t10_heat_reconsumption_events", []) as Array).is_empty(), "tick-2 records T10 heat reconsumption")
	_expect_true(_carry_is_empty(tick_two.get("t10_effect_carry_state", {})), "tick-2 consumed carry is empty when no new T10 record fires")

	var tick_three: Dictionary = snapshots[2]
	var baseline_tick_three: Dictionary = baseline_snapshots[2]
	var tick_three_thermal: Dictionary = _find_thermal(tick_three.get("organisms", []), "cargo-a")
	var baseline_tick_three_thermal: Dictionary = _find_thermal(baseline_tick_three.get("organisms", []), "cargo-a")
	_expect_true(not tick_three_thermal.is_empty() and not baseline_tick_three_thermal.is_empty(), "tick-3 thermal evidence exists")
	if not tick_three_thermal.is_empty() and not baseline_tick_three_thermal.is_empty():
		_expect_equal(int(tick_three_thermal.get("heat_exposure", -1)), int(baseline_tick_three_thermal.get("heat_exposure", -2)), "once-per-run Phase-H pulse is not re-applied on tick-3")
	_expect_true((tick_three.get("t10_heat_reconsumption_events", []) as Array).is_empty(), "tick-3 has no stale T10 heat reconsumption evidence")
	_expect_true(_carry_is_empty(result.get("t10_effect_carry_state", {})), "final T10 carry is empty after one-boundary consumption")

func _record(suffix: String) -> Dictionary:
	return {
		"run_id": "t10-once-carry-%s" % suffix,
		"rules_version": "rules-r1",
		"content_version": "t10-once-carry-1",
		"canonical_committed_input": {
			"route_id": "route-t10-once-carry",
			"seed": 631,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _defs() -> Dictionary:
	return {
		"route_profile": {"id": "route-t10-once-carry", "tick_count": 3, "events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "panic-field", "authored_order": 0}]},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {"panic-field": {"family": "H02", "stress_field_delta": 12, "target_cells": ["0,0"]}},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"organism_definitions": {"cargo-a": {"initial_stress": 0, "initial_state": "CALM", "stress_profile": _stress_profile()}},
		"support_definitions_by_id": {},
		"t10_definitions": [{
			"source_instance_id": "cargo-a",
			"trait_id": "once-carry-heat-pulse",
			"trigger_event_kind": "PRIMARY_STATE_ENTERED_PANICKED",
			"trigger_guard": "once_per_run",
			"effects": [{"kind": "HEAT_PULSE", "magnitude": 4, "target_instance_id": "cargo-a"}],
		}],
	}

func _stress_profile() -> Dictionary:
	return {"heat_safe_max": 2, "stress_per_heat_unit": 1, "stress_min": 0, "stress_max": 40, "agitated_enter": 5, "agitated_exit": 3, "panic_enter": 10, "panic_exit": 7}

func _find_thermal(events_value: Variant, instance_id: String) -> Dictionary:
	if not events_value is Array:
		return {}
	for raw_event: Variant in events_value:
		if raw_event is Dictionary and String((raw_event as Dictionary).get("instance_id", "")) == instance_id:
			return (raw_event as Dictionary).duplicate(true)
	return {}

func _carry_is_empty(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var carry: Dictionary = value as Dictionary
	var channels: Variant = carry.get("channel_delta_by_name", {})
	var organisms: Variant = carry.get("organism_delta_by_id", {})
	return channels is Dictionary and (channels as Dictionary).is_empty() and organisms is Dictionary and (organisms as Dictionary).is_empty()

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
