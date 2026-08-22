extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")
const TransitT10EffectIntegratedRunnerScript := preload("res://src/sim/transit_t10_effect_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_all_effect_authorities_clamp_carry_and_ancestry()
	_test_production_stress_field_pulse_is_next_tick_observable()
	if failures == 0:
		print("t10_effect_application_test_runner: PASS")
		quit(0)
	else:
		push_error("t10_effect_application_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_all_effect_authorities_clamp_carry_and_ancestry() -> void:
	var runner: Object = TransitT10EffectIntegratedRunnerScript.new()
	var base_result: Dictionary = {
		"ok": true,
		"tick_checksums": PackedStringArray(["base-1", "base-2"]),
		"end_tick_snapshots": [
			_snapshot(1, 9, 9, 4, 1, 5, _effect_records()),
			_snapshot(2, 0, 0, 0, 3, 1, []),
		],
	}
	var defs: Dictionary = _effect_defs()
	var first: Dictionary = runner.call("integrate_effects", base_result, defs)
	var replay: Dictionary = runner.call("integrate_effects", base_result, defs)
	_expect_true(bool(first.get("ok", false)), "T10 effect integration resolves")
	_expect_equal(first, replay, "T10 effect integration replay is deterministic")
	if not bool(first.get("ok", false)):
		return
	var snapshots: Array = first.get("end_tick_snapshots", [])
	_expect_equal(snapshots.size(), 2, "T10 effect integration preserves tick count")
	if snapshots.size() != 2:
		return
	var first_tick: Dictionary = snapshots[0]
	var second_tick: Dictionary = snapshots[1]
	_expect_equal(int((first_tick.get("heat_by_cell", {}) as Dictionary).get("0,0", -1)), 10, "HEAT_PULSE clamps at heat_max")
	_expect_equal(int((first_tick.get("stress_field_by_cell", {}) as Dictionary).get("0,0", -1)), 10, "STRESS_FIELD_PULSE clamps at stress_field_max")
	_expect_equal(int((first_tick.get("contamination_by_cell", {}) as Dictionary).get("0,0", -1)), 5, "CONTAMINATION_PULSE clamps at contamination_max")
	var first_runtime: Dictionary = (first_tick.get("organism_runtime", []) as Array)[0]
	_expect_equal(int(first_runtime.get("contamination_load", -1)), 0, "CONTAMINATION_CLEANSE clamps at load_min")
	_expect_equal(int(first_runtime.get("satiety", -1)), 6, "FOOD_PULSE clamps at satiety_max")

	_expect_equal(int((second_tick.get("heat_by_cell", {}) as Dictionary).get("0,0", -1)), 1, "applied heat delta persists into next authoritative tick")
	_expect_equal(int((second_tick.get("stress_field_by_cell", {}) as Dictionary).get("0,0", -1)), 1, "applied stress-field delta persists into next authoritative tick")
	_expect_equal(int((second_tick.get("contamination_by_cell", {}) as Dictionary).get("0,0", -1)), 1, "applied contamination delta persists into next authoritative tick")
	var second_runtime: Dictionary = (second_tick.get("organism_runtime", []) as Array)[0]
	_expect_equal(int(second_runtime.get("contamination_load", -1)), 2, "applied contamination-load cleanse persists into next authoritative tick")
	_expect_equal(int(second_runtime.get("satiety", -1)), 2, "applied satiety gain persists into next authoritative tick")

	var applications: Array = first.get("t10_effect_application_events", [])
	_expect_equal(applications.size(), 5, "all five authored effect records produce application evidence")
	for raw_event: Variant in applications:
		if not raw_event is Dictionary:
			_expect_true(false, "T10 application evidence is dictionary")
			continue
		var event: Dictionary = raw_event
		_expect_equal(String(event.get("kind", "")), "T10_EFFECT_APPLIED", "T10 application evidence is semantic")
		var parents: PackedStringArray = event.get("parent_event_ids", PackedStringArray())
		_expect_equal(parents.size(), 1, "T10 application evidence retains one raw-effect parent")
		if parents.size() == 1:
			_expect_true(_has_event_id(_effect_records(), String(parents[0])), "T10 application ancestry resolves to authored raw effect")

func _test_production_stress_field_pulse_is_next_tick_observable() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _production_defs()
	var baseline_defs: Dictionary = defs.duplicate(true)
	baseline_defs.erase("t10_definitions")
	var result: Dictionary = runner.simulate(_production_record(), 2, defs)
	var baseline: Dictionary = runner.simulate(_production_record(), 2, baseline_defs)
	_expect_true(bool(result.get("ok", false)) and bool(baseline.get("ok", false)), "production T10 stress-field pulse and baseline resolve")
	if not bool(result.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var pulses: Array = result.get("t10_pulse_events", [])
	_expect_equal(pulses.size(), 1, "once-per-run production guard still fires exactly once with applied effects")
	var result_snapshots: Array = result.get("end_tick_snapshots", [])
	var baseline_snapshots: Array = baseline.get("end_tick_snapshots", [])
	var result_tick_two: Dictionary = result_snapshots[1]
	var baseline_tick_two: Dictionary = baseline_snapshots[1]
	var result_field: Dictionary = result_tick_two.get("stress_field_by_cell", {})
	var baseline_field: Dictionary = baseline_tick_two.get("stress_field_by_cell", {})
	_expect_equal(int(result_field.get("0,0", -1)), mini(20, int(baseline_field.get("0,0", 0)) + 4), "Phase-H stress-field pulse is observable on next production tick")
	var applications: Array = result.get("t10_effect_application_events", [])
	_expect_equal(applications.size(), 1, "production stress-field pulse creates one applied-effect event")
	if applications.size() == 1:
		var event: Dictionary = applications[0]
		var parents: PackedStringArray = event.get("parent_event_ids", PackedStringArray())
		_expect_equal(parents.size(), 1, "production applied effect retains raw effect ancestry")
		if parents.size() == 1:
			_expect_true(_has_event_id(result.get("t10_effect_records", []), String(parents[0])), "production applied effect ancestry resolves to T10 effect record")

func _snapshot(tick: int, heat: int, stress_field: int, contamination: int, load: int, satiety: int, effects: Array) -> Dictionary:
	return {
		"tick": tick,
		"heat_by_cell": {"0,0": heat},
		"stress_field_by_cell": {"0,0": stress_field},
		"contamination_by_cell": {"0,0": contamination},
		"organism_runtime": [{
			"instance_id": "cargo-a",
			"occupied_cells": PackedStringArray(["0,0"]),
			"contamination_load": load,
			"contamination_profile": {"load_min": 0, "load_max": 5},
			"satiety": satiety,
			"satiety_min": 0,
			"satiety_max": 6,
		}],
		"t10_effect_records": effects.duplicate(true),
	}

func _effect_records() -> Array:
	return [
		_effect("e-heat", "HEAT_PULSE", 5),
		_effect("e-stress", "STRESS_FIELD_PULSE", 5),
		_effect("e-contam", "CONTAMINATION_PULSE", 10),
		_effect("e-clean", "CONTAMINATION_CLEANSE", 4),
		_effect("e-food", "FOOD_PULSE", 10),
	]

func _effect(event_id: String, kind: String, magnitude: int) -> Dictionary:
	return {
		"event_id": event_id,
		"kind": kind,
		"phase": "H",
		"tick": 1,
		"source_instance_id": "cargo-a",
		"target_instance_id": "cargo-a",
		"trait_id": "effect-test",
		"magnitude": magnitude,
		"parent_event_ids": PackedStringArray(["pulse-parent"]),
	}

func _effect_defs() -> Dictionary:
	return {
		"thermal_rules": {"heat_min": 0, "heat_max": 10},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 10},
		"contamination_rules": {"contamination_min": 0, "contamination_max": 5},
	}

func _production_record() -> Dictionary:
	return {
		"run_id": "t10-effect-production-run",
		"rules_version": "rules-r1",
		"content_version": "t10-effect-1",
		"canonical_committed_input": {
			"route_id": "route-t10-effect",
			"seed": 612,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _production_defs() -> Dictionary:
	return {
		"route_profile": {"id": "route-t10-effect", "tick_count": 2, "events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "panic-field", "authored_order": 0}]},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {"panic-field": {"family": "H02", "stress_field_delta": 12, "target_cells": ["0,0"]}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"organism_definitions": {"cargo-a": {"initial_stress": 0, "initial_state": "CALM", "stress_profile": _stress_profile()}},
		"support_definitions_by_id": {},
		"t10_definitions": [{
			"source_instance_id": "cargo-a",
			"trait_id": "stress-field-pulse",
			"trigger_event_kind": "PRIMARY_STATE_ENTERED_PANICKED",
			"trigger_guard": "once_per_run",
			"effects": [{"kind": "STRESS_FIELD_PULSE", "magnitude": 4, "target_instance_id": "cargo-a"}],
		}],
	}

func _stress_profile() -> Dictionary:
	return {"heat_safe_max": 2, "stress_per_heat_unit": 1, "stress_min": 0, "stress_max": 20, "agitated_enter": 5, "agitated_exit": 3, "panic_enter": 10, "panic_exit": 7}

func _has_event_id(events: Array, event_id: String) -> bool:
	for raw_event: Variant in events:
		if raw_event is Dictionary and String((raw_event as Dictionary).get("event_id", "")) == event_id:
			return true
	return false

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
