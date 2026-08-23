extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_phase_h_stress_pulse_is_reconsumed_by_next_tick_phase_e_f()
	_test_phase_h_heat_pulse_is_reconsumed_by_next_tick_thermal_response()
	_test_phase_h_contamination_pulse_reconsumes_with_t09_and_ancestry()
	if failures == 0:
		print("t10_reconsumption_test_runner: PASS")
		quit(0)
	else:
		push_error("t10_reconsumption_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_phase_h_stress_pulse_is_reconsumed_by_next_tick_phase_e_f() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _production_defs("STRESS_FIELD_PULSE")
	var baseline_defs: Dictionary = defs.duplicate(true)
	baseline_defs.erase("t10_definitions")
	var result: Dictionary = runner.simulate(_production_record("stress"), 2, defs)
	var replay: Dictionary = runner.simulate(_production_record("stress"), 2, defs)
	var baseline: Dictionary = runner.simulate(_production_record("stress"), 2, baseline_defs)
	_expect_true(bool(result.get("ok", false)), "T10 reconsumption production run resolves")
	_expect_equal(result, replay, "T10 reconsumption production replay is deterministic")
	_expect_true(bool(baseline.get("ok", false)), "T10 reconsumption baseline resolves")
	if not bool(result.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var result_snapshots: Array = result.get("end_tick_snapshots", [])
	var baseline_snapshots: Array = baseline.get("end_tick_snapshots", [])
	_expect_equal(result_snapshots.size(), 2, "T10 reconsumption preserves result tick count")
	_expect_equal(baseline_snapshots.size(), 2, "T10 reconsumption preserves baseline tick count")
	if result_snapshots.size() != 2 or baseline_snapshots.size() != 2:
		return
	var result_tick_two: Dictionary = result_snapshots[1]
	var baseline_tick_two: Dictionary = baseline_snapshots[1]
	var result_exposure: Dictionary = _find_event(result_tick_two.get("stress_field_response_events", []), "STRESS_FIELD_EXPOSURE", "cargo-a")
	var baseline_exposure: Dictionary = _find_event(baseline_tick_two.get("stress_field_response_events", []), "STRESS_FIELD_EXPOSURE", "cargo-a")
	_expect_true(not result_exposure.is_empty() and not baseline_exposure.is_empty(), "tick-2 Phase-E stress-field exposure evidence exists")
	if result_exposure.is_empty() or baseline_exposure.is_empty():
		return
	var expected_exposure: int = mini(20, int(baseline_exposure.get("stress_field_exposure", 0)) + 4)
	_expect_equal(int(result_exposure.get("stress_field_exposure", -1)), expected_exposure, "tick-1 Phase-H pulse changes tick-2 Phase-E sampled exposure")
	var result_phase_f: Dictionary = _find_event(result_tick_two.get("stress_field_response_events", []), "STRESS_FIELD_INTERNAL_STRESS", "cargo-a")
	_expect_true(not result_phase_f.is_empty(), "tick-2 Phase-F stress consumer evidence exists after reconsumption")
	if not result_phase_f.is_empty():
		_expect_equal(int(result_phase_f.get("stress_field_exposure", -1)), expected_exposure, "tick-2 Phase-F consumes the T10-adjusted exposure")
		var phase_f_parents: PackedStringArray = result_phase_f.get("parent_event_ids", PackedStringArray())
		_expect_equal(phase_f_parents.size(), 1, "tick-2 Phase-F retains Phase-E parent")
		if phase_f_parents.size() == 1:
			_expect_equal(String(phase_f_parents[0]), String(result_exposure.get("event_id", "")), "tick-2 Phase-F parent is the reconsumed Phase-E observation")
	var exposure_parents: PackedStringArray = result_exposure.get("parent_event_ids", PackedStringArray())
	_expect_true(not exposure_parents.is_empty(), "tick-2 Phase-E exposure retains T10 application ancestry")
	var tick_one_applications: Array = (result_snapshots[0] as Dictionary).get("t10_effect_application_events", [])
	if not exposure_parents.is_empty():
		_expect_true(_has_event_id(tick_one_applications, String(exposure_parents[0])), "tick-2 Phase-E ancestry resolves to tick-1 applied T10 pulse")
	var reconsumption_events: Array = result_tick_two.get("t10_reconsumption_events", [])
	_expect_true(not reconsumption_events.is_empty(), "tick-2 snapshot records explicit T10 reconsumption evidence")

func _test_phase_h_heat_pulse_is_reconsumed_by_next_tick_thermal_response() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _production_defs("HEAT_PULSE")
	var baseline_defs: Dictionary = defs.duplicate(true)
	baseline_defs.erase("t10_definitions")
	var result: Dictionary = runner.simulate(_production_record("heat"), 2, defs)
	var replay: Dictionary = runner.simulate(_production_record("heat"), 2, defs)
	var baseline: Dictionary = runner.simulate(_production_record("heat"), 2, baseline_defs)
	_expect_true(bool(result.get("ok", false)), "T10 heat reconsumption production run resolves")
	_expect_equal(result, replay, "T10 heat reconsumption replay is deterministic")
	_expect_true(bool(baseline.get("ok", false)), "T10 heat reconsumption baseline resolves")
	if not bool(result.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var result_snapshots: Array = result.get("end_tick_snapshots", [])
	var baseline_snapshots: Array = baseline.get("end_tick_snapshots", [])
	if result_snapshots.size() != 2 or baseline_snapshots.size() != 2:
		_expect_true(false, "T10 heat reconsumption preserves two ticks")
		return
	var result_tick_two: Dictionary = result_snapshots[1]
	var baseline_tick_two: Dictionary = baseline_snapshots[1]
	var result_thermal: Dictionary = _find_thermal(result_tick_two.get("organisms", []), "cargo-a")
	var baseline_thermal: Dictionary = _find_thermal(baseline_tick_two.get("organisms", []), "cargo-a")
	_expect_true(not result_thermal.is_empty() and not baseline_thermal.is_empty(), "tick-2 thermal response evidence exists")
	if result_thermal.is_empty() or baseline_thermal.is_empty():
		return
	var expected_exposure: int = mini(20, int(baseline_thermal.get("heat_exposure", 0)) + 4)
	_expect_equal(int(result_thermal.get("heat_exposure", -1)), expected_exposure, "tick-1 Phase-H HEAT_PULSE changes tick-2 thermal exposure")
	var expected_delta: int = maxi(0, expected_exposure - 2)
	_expect_equal(int(result_thermal.get("stress_delta", -1)), expected_delta, "tick-2 thermal consumer recomputes stress delta from carried heat")
	var heat_events: Array = result_tick_two.get("t10_heat_reconsumption_events", [])
	_expect_true(not heat_events.is_empty(), "tick-2 snapshot records explicit heat reconsumption evidence")
	if not heat_events.is_empty():
		var heat_event: Dictionary = heat_events[0]
		var parents: PackedStringArray = heat_event.get("parent_event_ids", PackedStringArray())
		_expect_true(not parents.is_empty(), "heat reconsumption evidence retains T10 application ancestry")
		if not parents.is_empty():
			var tick_one_applications: Array = (result_snapshots[0] as Dictionary).get("t10_effect_application_events", [])
			_expect_true(_has_event_id(tick_one_applications, String(parents[0])), "heat reconsumption ancestry resolves to tick-1 application")

func _test_phase_h_contamination_pulse_reconsumes_with_t09_and_ancestry() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _contamination_production_defs()
	var baseline_defs: Dictionary = defs.duplicate(true)
	baseline_defs.erase("t10_definitions")
	var result: Dictionary = runner.simulate(_contamination_record(), 2, defs)
	var replay: Dictionary = runner.simulate(_contamination_record(), 2, defs)
	var baseline: Dictionary = runner.simulate(_contamination_record(), 2, baseline_defs)
	_expect_true(bool(result.get("ok", false)), "T10 contamination reconsumption production run resolves")
	_expect_equal(result, replay, "T10 contamination reconsumption replay is deterministic")
	_expect_true(bool(baseline.get("ok", false)), "T10 contamination baseline resolves")
	if not bool(result.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var result_snapshots: Array = result.get("end_tick_snapshots", [])
	var baseline_snapshots: Array = baseline.get("end_tick_snapshots", [])
	if result_snapshots.size() != 2 or baseline_snapshots.size() != 2:
		_expect_true(false, "T10 contamination reconsumption preserves two ticks")
		return
	var result_tick_two: Dictionary = result_snapshots[1]
	var baseline_tick_two: Dictionary = baseline_snapshots[1]
	var result_exposure: Dictionary = _find_event(result_tick_two.get("contamination_response_events", []), "CONTAMINATION_EXPOSURE_SAMPLED", "cargo-a")
	var baseline_exposure: Dictionary = _find_event(baseline_tick_two.get("contamination_response_events", []), "CONTAMINATION_EXPOSURE_SAMPLED", "cargo-a")
	_expect_true(not result_exposure.is_empty() and not baseline_exposure.is_empty(), "tick-2 contamination Phase-E evidence exists")
	if result_exposure.is_empty() or baseline_exposure.is_empty():
		return
	var expected_exposure: int = mini(20, int(baseline_exposure.get("contamination_exposure", 0)) + 4)
	_expect_equal(int(result_exposure.get("contamination_exposure", -1)), expected_exposure, "tick-1 Phase-H CONTAMINATION_PULSE changes tick-2 Phase-E exposure")
	var phase_f: Dictionary = _find_event(result_tick_two.get("contamination_response_events", []), "CONTAMINATION_LOAD_INTAKE", "cargo-a")
	_expect_true(not phase_f.is_empty(), "tick-2 contamination Phase-F evidence exists")
	if not phase_f.is_empty():
		_expect_equal(int(phase_f.get("contamination_exposure", -1)), expected_exposure, "tick-2 Phase-F consumes T10-adjusted contamination exposure")
		_expect_equal(int(phase_f.get("base_intake_multiplier_scaled", -1)), 1000, "T10 contamination preserves base resistance authority")
		_expect_equal(int(phase_f.get("t09_intake_multiplier_scaled", -1)), 500, "T10 contamination preserves T09 intake modifier")
		_expect_equal(int(phase_f.get("combined_intake_multiplier_scaled", -1)), 500, "T10 contamination recomputes with combined T09 multiplier")
		_expect_equal(int(phase_f.get("contamination_intake", -1)), 2, "T10 contamination pulse is reduced by T09 before one final floor")
	var exposure_parents: PackedStringArray = result_exposure.get("parent_event_ids", PackedStringArray())
	_expect_true(not exposure_parents.is_empty(), "tick-2 contamination Phase-E retains T10 application ancestry")
	var tick_one_applications: Array = (result_snapshots[0] as Dictionary).get("t10_effect_application_events", [])
	if not exposure_parents.is_empty():
		_expect_true(_has_event_id(tick_one_applications, String(exposure_parents[0])), "contamination ancestry resolves to tick-1 T10 application")
	var modifiers: Dictionary = result_tick_two.get("t09_intake_multiplier_scaled_by_target_id", {})
	_expect_equal(int(modifiers.get("cargo-a", -1)), 500, "tick-2 snapshot retains T09 target assignment")
	var reconsumption_events: Array = result_tick_two.get("t10_contamination_reconsumption_events", [])
	_expect_true(not reconsumption_events.is_empty(), "tick-2 snapshot records explicit contamination reconsumption evidence")

func _production_record(suffix: String) -> Dictionary:
	return {
		"run_id": "t10-reconsumption-%s-run" % suffix,
		"rules_version": "rules-r1",
		"content_version": "t10-reconsumption-2",
		"canonical_committed_input": {
			"route_id": "route-t10-reconsumption",
			"seed": 613,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _production_defs(effect_kind: String) -> Dictionary:
	return {
		"route_profile": {"id": "route-t10-reconsumption", "tick_count": 2, "events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "panic-field", "authored_order": 0}]},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {"panic-field": {"family": "H02", "stress_field_delta": 12, "target_cells": ["0,0"]}},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"organism_definitions": {"cargo-a": {"initial_stress": 0, "initial_state": "CALM", "stress_profile": _stress_profile()}},
		"support_definitions_by_id": {},
		"t10_definitions": [{
			"source_instance_id": "cargo-a",
			"trait_id": "reconsumption-pulse",
			"trigger_event_kind": "PRIMARY_STATE_ENTERED_PANICKED",
			"trigger_guard": "once_per_run",
			"effects": [{"kind": effect_kind, "magnitude": 4, "target_instance_id": "cargo-a"}],
		}],
	}

func _contamination_record() -> Dictionary:
	return {
		"run_id": "t10-reconsumption-contamination-run",
		"rules_version": "rules-r1",
		"content_version": "t10-reconsumption-contamination-1",
		"canonical_committed_input": {
			"route_id": "route-t10-contamination",
			"seed": 617,
			"placements": [
				{"instance_id": "buffer", "anchor": [0, 0], "orientation": 0},
				{"instance_id": "cargo-a", "anchor": [1, 0], "orientation": 0},
			],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _contamination_production_defs() -> Dictionary:
	var profile: Dictionary = _contamination_profile()
	return {
		"route_profile": {"id": "route-t10-contamination", "tick_count": 2, "events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "panic-field", "authored_order": 0}]},
		"hold_definition": {"dimensions": [2, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {"panic-field": {"family": "H02", "stress_field_delta": 12, "target_cells": ["1,0"]}},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"contamination_rules": {"contamination_min": 0, "contamination_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"organism_definitions": {
			"buffer": {"initial_stress": 0, "initial_state": "CALM", "stress_profile": _stress_profile(), "contamination_profile": profile.duplicate(true)},
			"cargo-a": {"initial_stress": 0, "initial_state": "CALM", "stress_profile": _stress_profile(), "contamination_profile": profile.duplicate(true)},
		},
		"support_definitions_by_id": {},
		"t09_definitions": [{
			"instance_id": "buffer",
			"eligible_target_ids": ["cargo-a"],
			"range": 1,
			"max_targets": 1,
			"intake_multiplier_scaled": 500,
			"active_primary_states": ["CALM", "AGITATED", "PANICKED"],
			"active_body_stages": [],
			"sleep_gated": false,
		}],
		"t10_definitions": [{
			"source_instance_id": "cargo-a",
			"trait_id": "contamination-reconsumption-pulse",
			"trigger_event_kind": "PRIMARY_STATE_ENTERED_PANICKED",
			"trigger_guard": "once_per_run",
			"effects": [{"kind": "CONTAMINATION_PULSE", "magnitude": 4, "target_instance_id": "cargo-a"}],
		}],
	}

func _stress_profile() -> Dictionary:
	return {"heat_safe_max": 2, "stress_per_heat_unit": 1, "stress_min": 0, "stress_max": 40, "agitated_enter": 5, "agitated_exit": 3, "panic_enter": 10, "panic_exit": 7}

func _contamination_profile() -> Dictionary:
	return {"intake_multiplier_scaled": 1000, "load_min": 0, "load_max": 20, "contaminated_enter": 8, "contaminated_exit": 4}

func _find_event(events_value: Variant, kind: String, instance_id: String) -> Dictionary:
	if not events_value is Array:
		return {}
	for raw_event: Variant in events_value:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			if String(event.get("kind", "")) == kind and String(event.get("instance_id", "")) == instance_id:
				return event
	return {}

func _find_thermal(events_value: Variant, instance_id: String) -> Dictionary:
	if not events_value is Array:
		return {}
	for raw_event: Variant in events_value:
		if raw_event is Dictionary and String((raw_event as Dictionary).get("instance_id", "")) == instance_id:
			return (raw_event as Dictionary).duplicate(true)
	return {}

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
