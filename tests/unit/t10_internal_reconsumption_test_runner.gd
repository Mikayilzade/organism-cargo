extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_food_pulse_changes_next_tick_feeding_headroom()
	_test_cleanse_recomputes_next_tick_contamination_state()
	if failures == 0:
		print("t10_internal_reconsumption_test_runner: PASS")
		quit(0)
	else:
		push_error("t10_internal_reconsumption_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_food_pulse_changes_next_tick_feeding_headroom() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _food_defs()
	var baseline_defs: Dictionary = defs.duplicate(true)
	baseline_defs.erase("t10_definitions")
	var result: Dictionary = runner.simulate(_food_record(), 2, defs)
	var replay: Dictionary = runner.simulate(_food_record(), 2, defs)
	var baseline: Dictionary = runner.simulate(_food_record(), 2, baseline_defs)
	_expect_true(bool(result.get("ok", false)), "FOOD_PULSE production run resolves | error=%s" % String(result.get("error", "")))
	_expect_equal(result, replay, "FOOD_PULSE internal reconsumption replay is deterministic")
	_expect_true(bool(baseline.get("ok", false)), "FOOD_PULSE baseline resolves")
	if not bool(result.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var snapshots: Array = result.get("end_tick_snapshots", [])
	var baseline_snapshots: Array = baseline.get("end_tick_snapshots", [])
	if snapshots.size() != 2 or baseline_snapshots.size() != 2:
		_expect_true(false, "FOOD_PULSE preserves two ticks")
		return
	var tick_one: Dictionary = snapshots[0]
	var tick_two: Dictionary = snapshots[1]
	var baseline_tick_two: Dictionary = baseline_snapshots[1]
	var tick_one_food_apps: Array = _effect_applications(tick_one, "FOOD_PULSE")
	_expect_equal(tick_one_food_apps.size(), 1, "tick-1 FOOD_PULSE applies once")
	var tick_two_allocations: Array = _consumer_allocations(tick_two, "cargo-a")
	var baseline_allocations: Array = _consumer_allocations(baseline_tick_two, "cargo-a")
	_expect_equal(tick_two_allocations.size(), 0, "tick-1 FOOD_PULSE fills satiety headroom before tick-2 Phase-E allocation")
	_expect_equal(baseline_allocations.size(), 1, "without FOOD_PULSE tick-2 still allocates one food unit")
	var cargo: Dictionary = _runtime(tick_two, "cargo-a")
	_expect_equal(int(cargo.get("satiety", -1)), 4, "FOOD_PULSE satiety persists through next-tick feeding resolution")
	var reconsumed: Array = tick_two.get("t10_food_reconsumption_events", [])
	_expect_equal(reconsumed.size(), 1, "tick-2 records explicit FOOD_PULSE reconsumption evidence")
	if reconsumed.size() == 1 and tick_one_food_apps.size() == 1:
		var parents: PackedStringArray = (reconsumed[0] as Dictionary).get("parent_event_ids", PackedStringArray())
		_expect_equal(parents.size(), 1, "FOOD_PULSE reconsumption has one direct parent")
		if parents.size() == 1:
			_expect_equal(String(parents[0]), String((tick_one_food_apps[0] as Dictionary).get("event_id", "")), "FOOD_PULSE reconsumption ancestry resolves to tick-1 application")

func _test_cleanse_recomputes_next_tick_contamination_state() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _cleanse_defs()
	var baseline_defs: Dictionary = defs.duplicate(true)
	baseline_defs.erase("t10_definitions")
	var result: Dictionary = runner.simulate(_cleanse_record(), 2, defs)
	var replay: Dictionary = runner.simulate(_cleanse_record(), 2, defs)
	var baseline: Dictionary = runner.simulate(_cleanse_record(), 2, baseline_defs)
	_expect_true(bool(result.get("ok", false)), "CONTAMINATION_CLEANSE production run resolves | error=%s" % String(result.get("error", "")))
	_expect_equal(result, replay, "CONTAMINATION_CLEANSE internal reconsumption replay is deterministic")
	_expect_true(bool(baseline.get("ok", false)), "CONTAMINATION_CLEANSE baseline resolves")
	if not bool(result.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var snapshots: Array = result.get("end_tick_snapshots", [])
	var baseline_snapshots: Array = baseline.get("end_tick_snapshots", [])
	if snapshots.size() != 2 or baseline_snapshots.size() != 2:
		_expect_true(false, "CONTAMINATION_CLEANSE preserves two ticks")
		return
	var tick_one: Dictionary = snapshots[0]
	var tick_two: Dictionary = snapshots[1]
	var baseline_tick_two: Dictionary = baseline_snapshots[1]
	var tick_one_apps: Array = _effect_applications(tick_one, "CONTAMINATION_CLEANSE")
	_expect_equal(tick_one_apps.size(), 1, "tick-1 CONTAMINATION_CLEANSE applies once")
	var cargo: Dictionary = _runtime(tick_two, "cargo-a")
	var baseline_cargo: Dictionary = _runtime(baseline_tick_two, "cargo-a")
	_expect_equal(int(cargo.get("contamination_load", -1)), 1, "cleanse-adjusted load is authoritative at tick-2 Phase-F")
	_expect_equal(bool(cargo.get("contaminated", true)), false, "tick-2 Phase-G consumes cleanse-adjusted load and exits contaminated state")
	_expect_equal(bool(baseline_cargo.get("contaminated", false)), true, "baseline remains contaminated without cleanse")
	var exit_event: Dictionary = _find_event(tick_two.get("contamination_response_events", []), "CONTAMINATED_EXIT", "cargo-a")
	_expect_true(not exit_event.is_empty(), "tick-2 contamination response records canonical exit transition")
	var intake_event: Dictionary = _find_event(tick_two.get("contamination_response_events", []), "CONTAMINATION_LOAD_INTAKE", "cargo-a")
	_expect_true(not intake_event.is_empty(), "tick-2 cleanse reconsumption retains Phase-F intake evidence")
	var reconsumed: Array = tick_two.get("t10_cleanse_reconsumption_events", [])
	_expect_equal(reconsumed.size(), 1, "tick-2 records explicit CONTAMINATION_CLEANSE reconsumption evidence")
	if not intake_event.is_empty() and reconsumed.size() == 1:
		var intake_parents: PackedStringArray = intake_event.get("parent_event_ids", PackedStringArray())
		_expect_true(String((reconsumed[0] as Dictionary).get("event_id", "")) in intake_parents, "Phase-F contamination load retains cleanse reconsumption ancestry")
	if reconsumed.size() == 1 and tick_one_apps.size() == 1:
		var parents: PackedStringArray = (reconsumed[0] as Dictionary).get("parent_event_ids", PackedStringArray())
		_expect_equal(parents.size(), 1, "cleanse reconsumption has one direct parent")
		if parents.size() == 1:
			_expect_equal(String(parents[0]), String((tick_one_apps[0] as Dictionary).get("event_id", "")), "cleanse reconsumption ancestry resolves to tick-1 application")

func _food_record() -> Dictionary:
	return {
		"run_id": "t10-internal-food-run",
		"rules_version": "rules-r1",
		"content_version": "t10-internal-1",
		"canonical_committed_input": {
			"route_id": "route-t10-internal-food",
			"seed": 619,
			"placements": [
				{"instance_id": "feeder-b", "anchor": [0, 0], "orientation": 0},
				{"instance_id": "cargo-a", "anchor": [1, 0], "orientation": 0},
			],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _food_defs() -> Dictionary:
	return {
		"route_profile": {"id": "route-t10-internal-food", "tick_count": 2, "events": [
			{"tick": 1, "duration_ticks": 1, "hazard_id": "panic-field", "authored_order": 0},
		]},
		"hold_definition": {"dimensions": [2, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {"panic-field": {"family": "H02", "stress_field_delta": 12, "target_cells": ["1,0"]}},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"organism_definitions": {
			"cargo-a": {"initial_stress": 0, "initial_state": "CALM", "initial_satiety": 0, "stress_profile": _stress_profile()},
			"feeder-b": {"initial_stress": 0, "initial_state": "CALM", "stress_profile": _stress_profile()},
		},
		"support_definitions_by_id": {},
		"t07_producer_definitions": [{
			"instance_id": "feeder-b",
			"output_units": 3,
			"food_tags": ["protein"],
			"active_primary_states": [],
			"active_body_stages": [],
			"sleep_gated": false,
		}],
		"t07_consumer_definitions": [{
			"instance_id": "cargo-a",
			"range": 1,
			"intake_cap": 3,
			"benefit_per_unit": 1,
			"satiety_max": 4,
			"accepted_food_tags": ["protein"],
			"active_primary_states": [],
			"active_body_stages": [],
			"sleep_gated": false,
		}],
		"t10_definitions": [{
			"source_instance_id": "cargo-a",
			"trait_id": "food-pulse-test",
			"trigger_event_kind": "PRIMARY_STATE_ENTERED_PANICKED",
			"trigger_guard": "once_per_run",
			"effects": [{"kind": "FOOD_PULSE", "magnitude": 3, "target_instance_id": "cargo-a"}],
		}],
	}

func _cleanse_record() -> Dictionary:
	return {
		"run_id": "t10-internal-cleanse-run",
		"rules_version": "rules-r1",
		"content_version": "t10-internal-1",
		"canonical_committed_input": {
			"route_id": "route-t10-internal-cleanse",
			"seed": 620,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _cleanse_defs() -> Dictionary:
	return {
		"route_profile": {"id": "route-t10-internal-cleanse", "tick_count": 2, "events": [
			{"tick": 1, "duration_ticks": 1, "hazard_id": "panic-field", "authored_order": 0},
		]},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {"panic-field": {"family": "H02", "stress_field_delta": 12, "target_cells": ["0,0"]}},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"contamination_rules": {"contamination_min": 0, "contamination_max": 10, "transfer_edges": [], "vent_by_cell": {}},
		"organism_definitions": {"cargo-a": {
			"initial_stress": 0,
			"initial_state": "CALM",
			"stress_profile": _stress_profile(),
			"initial_contamination_load": 4,
			"initial_contaminated": true,
			"contamination_profile": {
				"intake_multiplier_scaled": 1000,
				"load_min": 0,
				"load_max": 10,
				"contaminated_enter": 4,
				"contaminated_exit": 2,
			},
		}},
		"support_definitions_by_id": {},
		"t10_definitions": [{
			"source_instance_id": "cargo-a",
			"trait_id": "cleanse-pulse-test",
			"trigger_event_kind": "PRIMARY_STATE_ENTERED_PANICKED",
			"trigger_guard": "once_per_run",
			"effects": [{"kind": "CONTAMINATION_CLEANSE", "magnitude": 3, "target_instance_id": "cargo-a"}],
		}],
	}

func _stress_profile() -> Dictionary:
	return {
		"heat_safe_max": 2,
		"stress_per_heat_unit": 1,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 5,
		"agitated_exit": 3,
		"panic_enter": 10,
		"panic_exit": 7,
	}

func _runtime(snapshot: Dictionary, instance_id: String) -> Dictionary:
	var value: Variant = snapshot.get("organism_runtime", [])
	if value is Array:
		for raw_runtime: Variant in value:
			if raw_runtime is Dictionary and String((raw_runtime as Dictionary).get("instance_id", "")) == instance_id:
				return raw_runtime as Dictionary
	return {}

func _effect_applications(snapshot: Dictionary, effect_kind: String) -> Array:
	var events: Array = []
	var value: Variant = snapshot.get("t10_effect_application_events", [])
	if value is Array:
		for raw_event: Variant in value:
			if raw_event is Dictionary and String((raw_event as Dictionary).get("effect_kind", "")) == effect_kind and String((raw_event as Dictionary).get("kind", "")) == "T10_EFFECT_APPLIED":
				events.append(raw_event)
	return events

func _consumer_allocations(snapshot: Dictionary, consumer_id: String) -> Array:
	var result: Array = []
	var value: Variant = snapshot.get("t07_allocations", [])
	if value is Array:
		for raw_allocation: Variant in value:
			if raw_allocation is Dictionary and String((raw_allocation as Dictionary).get("consumer_id", "")) == consumer_id:
				result.append(raw_allocation)
	return result

func _find_event(events_value: Variant, kind: String, instance_id: String) -> Dictionary:
	if events_value is Array:
		for raw_event: Variant in events_value:
			if raw_event is Dictionary:
				var event: Dictionary = raw_event
				if String(event.get("kind", "")) == kind and String(event.get("instance_id", "")) == instance_id:
					return event
	return {}

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
