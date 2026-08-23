extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_t05_production_composes_with_h03_once_and_replays()
	_test_t09_production_applies_one_target_modifier_and_replays()
	if failures == 0:
		print("core_trait_production_closure_test_runner: PASS")
		quit(0)
	else:
		push_error("core_trait_production_closure_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_t05_production_composes_with_h03_once_and_replays() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_t05_record(), 1, _t05_defs(true))
	var replay: Dictionary = runner.simulate(_t05_record(), 1, _t05_defs(true))
	var baseline: Dictionary = runner.simulate(_t05_record(), 1, _t05_defs(false))
	_expect_true(bool(first.get("ok", false)) and bool(replay.get("ok", false)) and bool(baseline.get("ok", false)), "T05 production/baseline runs resolve")
	if not bool(first.get("ok", false)) or not bool(replay.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	_expect_equal(first["tick_checksums"], replay["tick_checksums"], "T05 production replay checksum is deterministic")
	_expect_equal(first["end_tick_snapshots"], replay["end_tick_snapshots"], "T05 production replay snapshots are deterministic")
	var snapshot: Dictionary = first["end_tick_snapshots"][0]
	var baseline_snapshot: Dictionary = baseline["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["phase_d_contamination_exposure_by_cell"]["0,0"]), 5, "T05 + H03 Phase-C sources compose before one Phase-D publication")
	_expect_equal(int(baseline_snapshot["phase_d_contamination_exposure_by_cell"]["0,0"]), 2, "H03-only baseline exposes only route contamination")
	var events: Array = snapshot["phase_c_environment_events"]
	_expect_equal(events.size(), 2, "T05 plus H03 emit exactly two Phase-C source events")
	if events.size() == 2:
		_expect_equal(String(events[0].get("kind", "")), "T05_SPORE_SOURCE", "living T05 source resolves before H03 route source")
		_expect_equal(String(events[1].get("kind", "")), "H03_CONTAMINATION_SOURCE", "H03 source follows T05 in the same Phase-C source snapshot")
	_expect_true(String(first["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "T05 production contribution is checksum-visible")

func _test_t09_production_applies_one_target_modifier_and_replays() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_t09_record(), 1, _t09_defs(true))
	var replay: Dictionary = runner.simulate(_t09_record(), 1, _t09_defs(true))
	var baseline: Dictionary = runner.simulate(_t09_record(), 1, _t09_defs(false))
	_expect_true(bool(first.get("ok", false)) and bool(replay.get("ok", false)) and bool(baseline.get("ok", false)), "T09 production/baseline runs resolve")
	if not bool(first.get("ok", false)) or not bool(replay.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	_expect_equal(first["tick_checksums"], replay["tick_checksums"], "T09 production replay checksum is deterministic")
	_expect_equal(first["end_tick_snapshots"], replay["end_tick_snapshots"], "T09 production replay snapshots are deterministic")
	var snapshot: Dictionary = first["end_tick_snapshots"][0]
	var modifiers: Dictionary = snapshot["t09_intake_multiplier_scaled_by_target_id"]
	_expect_equal(modifiers.size(), 1, "one T09 source protects exactly one production target")
	_expect_equal(int(modifiers.get("target-a", -1)), 500, "nearest/id stable selector chooses target-a")
	_expect_true(not modifiers.has("target-b"), "equally near second compatible target is not universally protected")
	var runtime: Dictionary = _runtime_by_id(first["final_organism_runtime"])
	var baseline_runtime: Dictionary = _runtime_by_id(baseline["final_organism_runtime"])
	_expect_equal(int(runtime["target-a"]["contamination_load"]), 2, "T09 halves target-a contamination intake in Phase F")
	_expect_equal(int(runtime["target-b"]["contamination_load"]), 4, "unselected target-b keeps full contamination intake")
	_expect_equal(int(baseline_runtime["target-a"]["contamination_load"]), 4, "without T09 target-a receives full intake")
	var t09_events: Array = snapshot["t09_buffer_events"]
	_expect_equal(t09_events.size(), 1, "production snapshot exposes one T09 assignment event")
	if t09_events.size() == 1:
		_expect_equal(String(t09_events[0].get("phase", "")), "E", "T09 assignment remains a Phase-E direct interaction")
		_expect_equal(String(t09_events[0].get("target_instance_id", "")), "target-a", "T09 evidence names the protected target")
	var found_augmented_intake: bool = false
	for raw_event: Variant in snapshot["contamination_response_events"]:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			if String(event.get("kind", "")) == "CONTAMINATION_LOAD_INTAKE" and String(event.get("instance_id", "")) == "target-a":
				found_augmented_intake = int(event.get("intake_multiplier_scaled", -1)) == 500 and int(event.get("contamination_intake", -1)) == 2
				break
	_expect_true(found_augmented_intake, "Phase-F contamination evidence carries the T09-adjusted intake authority")
	_expect_true(String(first["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "T09 assignment/intake effect is checksum-visible")

func _t05_record() -> Dictionary:
	return {
		"run_id": "t05-production-closure",
		"rules_version": "rules-r1",
		"content_version": "t05-production-closure-1",
		"canonical_committed_input": {
			"route_id": "route-t05-production-closure",
			"seed": 505,
			"placements": [{"instance_id": "spore", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _t05_defs(include_t05: bool) -> Dictionary:
	var defs: Dictionary = {
		"route_profile": {
			"id": "route-t05-production-closure",
			"tick_count": 1,
			"events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "h03-t05", "authored_order": 0}],
		},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {
			"h03-t05": {"id": "h03-t05", "family": "H03", "contamination_delta": 2, "target_cells": ["0,0"]},
		},
		"support_definitions_by_id": {},
		"contamination_rules": {
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"spore": _organism_definition("MATURE"),
		},
	}
	if include_t05:
		defs["t05_definitions"] = [{
			"instance_id": "spore",
			"output_amount": 3,
			"active_primary_states": ["CALM"],
			"active_body_stages": ["MATURE"],
			"sleep_gated": false,
		}]
	return defs

func _t09_record() -> Dictionary:
	return {
		"run_id": "t09-production-closure",
		"rules_version": "rules-r1",
		"content_version": "t09-production-closure-1",
		"canonical_committed_input": {
			"route_id": "route-t09-production-closure",
			"seed": 909,
			"placements": [
				{"instance_id": "buffer", "anchor": [0, 0], "orientation": 0},
				{"instance_id": "target-a", "anchor": [1, 0], "orientation": 0},
				{"instance_id": "target-b", "anchor": [0, 1], "orientation": 0},
			],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _t09_defs(include_t09: bool) -> Dictionary:
	var defs: Dictionary = {
		"route_profile": {
			"id": "route-t09-production-closure",
			"tick_count": 1,
			"events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "h03-t09", "authored_order": 0}],
		},
		"hold_definition": {"dimensions": [2, 2], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {
			"h03-t09": {"id": "h03-t09", "family": "H03", "contamination_delta": 4, "target_cells": ["1,0", "0,1"]},
		},
		"support_definitions_by_id": {},
		"contamination_rules": {
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"buffer": _organism_definition("MATURE"),
			"target-a": _organism_definition("MATURE"),
			"target-b": _organism_definition("MATURE"),
		},
	}
	if include_t09:
		defs["t09_definitions"] = [{
			"instance_id": "buffer",
			"eligible_target_ids": ["target-b", "target-a"],
			"range": 1,
			"max_targets": 1,
			"intake_multiplier_scaled": 500,
			"active_primary_states": ["CALM"],
			"active_body_stages": ["MATURE"],
			"sleep_gated": false,
		}]
	return defs

func _organism_definition(stage: String) -> Dictionary:
	return {
		"initial_stress": 0,
		"initial_state": "CALM",
		"initial_body_stage": stage,
		"stress_profile": _stress_profile(),
		"body_stages": {stage: {"footprints": {"0": [[0, 0]]}}},
		"contamination_profile": {
			"intake_multiplier_scaled": 1000,
			"load_min": 0,
			"load_max": 20,
			"contaminated_enter": 8,
			"contaminated_exit": 4,
		},
	}

func _stress_profile() -> Dictionary:
	return {
		"heat_safe_max": 99,
		"stress_per_heat_unit": 1,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 6,
		"agitated_exit": 3,
		"panic_enter": 11,
		"panic_exit": 7,
	}

func _runtime_by_id(organisms: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_runtime: Variant in organisms:
		if raw_runtime is Dictionary:
			var runtime: Dictionary = raw_runtime
			result[String(runtime.get("instance_id", ""))] = runtime
	return result

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
