extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_panicked_once_per_run_and_ancestry()
	_test_wake_episode_and_finite_max_guards()
	if failures == 0:
		print("t10_transit_integration_test_runner: PASS")
		quit(0)
	else:
		push_error("t10_transit_integration_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_panicked_once_per_run_and_ancestry() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_panic_record(), 1, _panic_defs())
	var replay: Dictionary = runner.simulate(_panic_record(), 1, _panic_defs())
	_expect_true(bool(first.get("ok", false)), "production PANICKED-entry T10 run resolves")
	_expect_equal(first, replay, "production PANICKED-entry T10 replay is deterministic")
	if not bool(first.get("ok", false)):
		return
	var pulses: Array = first.get("t10_pulse_events", [])
	_expect_equal(pulses.size(), 1, "once-per-run PANICKED-entry emits exactly one production T10 pulse")
	var t10_state: Dictionary = first.get("t10_runtime_state", {})
	var counts: Dictionary = t10_state.get("trigger_count_by_key", {})
	_expect_equal(int(counts.get("cargo-a|panic-pulse", 0)), 1, "once-per-run production guard persists exact count")
	var snapshot: Dictionary = first["end_tick_snapshots"][0]
	var triggers: Array = snapshot.get("t10_trigger_events", [])
	var semantic: Dictionary = _find_event(triggers, "PRIMARY_STATE_ENTERED_PANICKED")
	_expect_true(not semantic.is_empty(), "production stress transition exposes semantic PANICKED trigger")
	if pulses.size() == 1 and not semantic.is_empty():
		var pulse: Dictionary = pulses[0]
		_expect_equal(pulse.get("parent_event_ids", PackedStringArray()), PackedStringArray([String(semantic.get("event_id", ""))]), "T10 pulse points to semantic PANICKED trigger")
		var parent_ids: PackedStringArray = semantic.get("parent_event_ids", PackedStringArray())
		_expect_equal(parent_ids.size(), 1, "semantic PANICKED trigger retains one material Phase-G parent")
		if parent_ids.size() == 1:
			_expect_true(_has_event_id(snapshot.get("stress_field_response_events", []), String(parent_ids[0])), "semantic PANICKED ancestry resolves to production stress transition evidence")

func _test_wake_episode_and_finite_max_guards() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_wake_record(), 3, _wake_defs())
	var replay: Dictionary = runner.simulate(_wake_record(), 3, _wake_defs())
	_expect_true(bool(first.get("ok", false)), "production repeated wake T10 run resolves")
	_expect_equal(first, replay, "production repeated wake T10 replay is deterministic")
	if not bool(first.get("ok", false)):
		return
	var pulses: Array = first.get("t10_pulse_events", [])
	var episode_pulses: Array = _events_for_trait(pulses, "wake-episode-pulse")
	var capped_pulses: Array = _events_for_trait(pulses, "wake-capped-pulse")
	_expect_equal(episode_pulses.size(), 3, "once-per-episode guard permits one pulse for each distinct production wake episode")
	_expect_equal(capped_pulses.size(), 2, "max-triggers-per-run guard exhausts after authored finite cap")
	var t10_state: Dictionary = first.get("t10_runtime_state", {})
	var counts: Dictionary = t10_state.get("trigger_count_by_key", {})
	_expect_equal(int(counts.get("cargo-a|wake-episode-pulse", 0)), 3, "episode-scoped production count tracks all distinct wake episodes")
	_expect_equal(int(counts.get("cargo-a|wake-capped-pulse", 0)), 2, "finite production max count stops at two")
	var seen_episode_ids: Dictionary = {}
	for raw_pulse: Variant in episode_pulses:
		var pulse: Dictionary = raw_pulse
		var episode_id: String = String(pulse.get("episode_id", ""))
		_expect_true(not episode_id.is_empty(), "once-per-episode production pulse carries episode identity")
		_expect_true(not seen_episode_ids.has(episode_id), "each production wake episode fires at most once for episode-scoped trait")
		seen_episode_ids[episode_id] = true
	for raw_snapshot: Variant in first.get("end_tick_snapshots", []):
		var snapshot: Dictionary = raw_snapshot
		var semantic: Dictionary = _find_event(snapshot.get("t10_trigger_events", []), "PRIMARY_STATE_WOKE")
		_expect_true(not semantic.is_empty(), "each authored sleep/wake tick exposes semantic wake trigger")
		if not semantic.is_empty():
			var parent_ids: PackedStringArray = semantic.get("parent_event_ids", PackedStringArray())
			_expect_equal(parent_ids.size(), 1, "semantic wake trigger retains its material H02 wake parent")
			if parent_ids.size() == 1:
				_expect_true(_has_event_id(snapshot.get("sleep_wake_events", []), String(parent_ids[0])), "semantic wake ancestry resolves to production H02 wake evidence")

func _panic_record() -> Dictionary:
	return {
		"run_id": "t10-panic-production-run",
		"rules_version": "rules-r1",
		"content_version": "t10-production-1",
		"canonical_committed_input": {
			"route_id": "route-t10-panic",
			"seed": 510,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _panic_defs() -> Dictionary:
	return {
		"route_profile": {"id": "route-t10-panic", "tick_count": 1, "events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "panic-field", "authored_order": 0}]},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {"panic-field": {"family": "H02", "stress_field_delta": 12, "target_cells": ["0,0"]}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"organism_definitions": {"cargo-a": {"initial_stress": 0, "initial_state": "CALM", "stress_profile": _stress_profile()}},
		"support_definitions_by_id": {},
		"t10_definitions": [{
			"source_instance_id": "cargo-a",
			"trait_id": "panic-pulse",
			"trigger_event_kind": "PRIMARY_STATE_ENTERED_PANICKED",
			"trigger_guard": "once_per_run",
			"effects": [{"kind": "HEAT_PULSE", "magnitude": 2, "target_instance_id": "cargo-a"}],
		}],
	}

func _wake_record() -> Dictionary:
	return {
		"run_id": "t10-wake-production-run",
		"rules_version": "rules-r1",
		"content_version": "t10-production-1",
		"canonical_committed_input": {
			"route_id": "route-t10-wake",
			"seed": 511,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [{"instance_id": "nest-a", "support_id": "S04", "linked_target_instance_id": "cargo-a"}],
			"brownout_priority": [],
		},
	}

func _wake_defs() -> Dictionary:
	var schedule: Array = []
	for tick: int in range(1, 4):
		schedule.append({"tick": tick, "authored_order": 0, "support_instance_id": "nest-a", "target_instance_id": "cargo-a", "transition": "ENTER_SLEEP"})
	return {
		"route_profile": {"id": "route-t10-wake", "tick_count": 3, "events": [{"tick": 1, "duration_ticks": 3, "hazard_id": "wake-field", "authored_order": 0}]},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {"wake-field": {"family": "H02", "stress_field_delta": 0, "target_cells": ["0,0"], "wake_request": true, "wake_target_instance_ids": ["cargo-a"]}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"organism_definitions": {"cargo-a": {"initial_stress": 0, "initial_state": "CALM", "can_sleep": true, "stress_profile": _stress_profile()}},
		"support_definitions_by_id": {"S04": {"family": "S04", "capacity": 1, "powered": false}},
		"s04_transition_schedule": schedule,
		"t10_definitions": [
			{"source_instance_id": "cargo-a", "trait_id": "wake-episode-pulse", "trigger_event_kind": "PRIMARY_STATE_WOKE", "trigger_guard": "once_per_episode", "effects": [{"kind": "CONTAMINATION_CLEANSE", "magnitude": 1, "target_instance_id": "cargo-a"}]},
			{"source_instance_id": "cargo-a", "trait_id": "wake-capped-pulse", "trigger_event_kind": "PRIMARY_STATE_WOKE", "trigger_guard": "max_triggers_per_run", "max_triggers_per_run": 2, "effects": [{"kind": "FOOD_PULSE", "magnitude": 1, "target_instance_id": "cargo-a"}]},
		],
	}

func _stress_profile() -> Dictionary:
	return {"heat_safe_max": 2, "stress_per_heat_unit": 1, "stress_min": 0, "stress_max": 20, "agitated_enter": 5, "agitated_exit": 3, "panic_enter": 10, "panic_exit": 7}

func _find_event(events: Array, kind: String) -> Dictionary:
	for raw_event: Variant in events:
		if raw_event is Dictionary and String((raw_event as Dictionary).get("kind", "")) == kind:
			return (raw_event as Dictionary).duplicate(true)
	return {}

func _has_event_id(events: Array, event_id: String) -> bool:
	for raw_event: Variant in events:
		if raw_event is Dictionary and String((raw_event as Dictionary).get("event_id", "")) == event_id:
			return true
	return false

func _events_for_trait(events: Array, trait_id: String) -> Array:
	var selected: Array = []
	for raw_event: Variant in events:
		if raw_event is Dictionary and String((raw_event as Dictionary).get("trait_id", "")) == trait_id:
			selected.append((raw_event as Dictionary).duplicate(true))
	return selected

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
