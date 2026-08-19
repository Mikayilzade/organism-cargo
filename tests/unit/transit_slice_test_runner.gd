extends SceneTree

const TransitSliceRunnerScript := preload("res://src/sim/transit_slice_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_deterministic_phase_order_and_checksums()
	_test_run_identity_does_not_change_authoritative_trace()
	_test_input_change_changes_authoritative_trace()
	_test_authored_thermal_route_changes_environment_and_organism_state()
	_test_thermal_trace_is_reproducible()
	_test_route_timing_changes_authoritative_trace()
	if failures == 0:
		print("transit_slice_test_runner: PASS")
		quit(0)
	else:
		push_error("transit_slice_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_deterministic_phase_order_and_checksums() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var first: Dictionary = runner.simulate(_record("run-a", _input()), 3)
	var second: Dictionary = runner.simulate(_record("run-a", _input_reordered()), 3)
	_expect_true(bool(first["ok"]), "first deterministic transit slice succeeds")
	_expect_true(bool(second["ok"]), "reordered placement input succeeds")
	_expect_equal(first["tick_checksums"], second["tick_checksums"], "stable placement ordering produces identical checksum sequence")
	var trace: PackedStringArray = first["phase_trace"]
	_expect_equal(trace.size(), 27, "three ticks execute exactly nine named phases")
	_expect_equal(trace[0], "1:A", "tick begins at Phase A")
	_expect_equal(trace[8], "1:I", "tick ends at Phase I")
	_expect_equal(trace[9], "2:A", "next tick restarts at Phase A")
	_expect_equal(int(first["final_tick"]), 3, "slice completes configured route length")

func _test_run_identity_does_not_change_authoritative_trace() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var first: Dictionary = runner.simulate(_record("run-a", _input()), 4)
	var second: Dictionary = runner.simulate(_record("run-b", _input()), 4)
	_expect_equal(first["tick_checksums"], second["tick_checksums"], "run_id is persistence identity, not simulation entropy")

func _test_input_change_changes_authoritative_trace() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var baseline: Dictionary = runner.simulate(_record("run-a", _input()), 2)
	var changed_input: Dictionary = _input()
	changed_input["placements"][1]["anchor"] = [2, 1]
	var changed: Dictionary = runner.simulate(_record("run-a", changed_input), 2)
	_expect_true(baseline["tick_checksums"] != changed["tick_checksums"], "committed placement change changes authoritative checksum trace")

func _test_authored_thermal_route_changes_environment_and_organism_state() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var result: Dictionary = runner.simulate(_record("run-a", _thermal_input()), 3, _thermal_defs(2))
	_expect_true(bool(result["ok"]), "authored H01 route with thermal organism response executes")
	var snapshots: Array = result["end_tick_snapshots"]
	_expect_equal(snapshots.size(), 3, "one end-of-tick authoritative snapshot is retained per tick")
	var tick_one: Dictionary = snapshots[0]
	var tick_two: Dictionary = snapshots[1]
	var tick_three: Dictionary = snapshots[2]
	_expect_equal(tick_one["active_hazards"], PackedStringArray(), "thermal surge is inactive before scheduled tick")
	_expect_equal(tick_two["active_hazards"], PackedStringArray(["h01-slice"]), "Phase A activates thermal surge on scheduled tick")
	_expect_equal(tick_three["active_hazards"], PackedStringArray(), "thermal surge deactivates after declared duration")
	_expect_equal(int(tick_one["heat_by_cell"]["0,0"]), 0, "heat starts at zero")
	_expect_equal(int(tick_two["heat_by_cell"]["0,0"]), 6, "Phase C H01 heat survives authored zero-transfer Phase D")
	_expect_equal(int(tick_three["heat_by_cell"]["0,0"]), 6, "heat persists when authored vent is zero")

	var tick_one_organisms: Array = tick_one["organisms"]
	var tick_two_organisms: Array = tick_two["organisms"]
	var tick_three_organisms: Array = tick_three["organisms"]
	var first_tick_a: Dictionary = tick_one_organisms[0]
	var second_tick_a: Dictionary = tick_two_organisms[0]
	var third_tick_a: Dictionary = tick_three_organisms[0]
	_expect_equal(String(first_tick_a["instance_id"]), "specimen-a", "organism snapshots are stable instance-id ordered")
	_expect_equal(int(first_tick_a["stress"]), 1, "safe pre-hazard exposure leaves stress unchanged")
	_expect_equal(String(first_tick_a["primary_state"]), "CALM", "pre-hazard state remains CALM")
	_expect_equal(int(second_tick_a["heat_exposure"]), 6, "Phase E samples authored H01 heat")
	_expect_equal(int(second_tick_a["stress"]), 9, "Phase F applies deterministic excess-heat stress")
	_expect_equal(String(second_tick_a["primary_state"]), "AGITATED", "Phase G enters AGITATED at the authored threshold")
	_expect_equal(int(third_tick_a["stress"]), 17, "persistent environmental heat continues to affect the next tick")
	_expect_equal(String(third_tick_a["primary_state"]), "PANICKED", "later accumulated stress enters PANICKED deterministically")

func _test_thermal_trace_is_reproducible() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var first: Dictionary = runner.simulate(_record("run-a", _thermal_input()), 3, _thermal_defs(2))
	var second: Dictionary = runner.simulate(_record("run-b", _thermal_input_reordered()), 3, _thermal_defs(2))
	_expect_true(bool(first["ok"]) and bool(second["ok"]), "thermal replay variants both execute")
	_expect_equal(first["tick_checksums"], second["tick_checksums"], "same committed thermal plan reproduces heat/stress/state checksum trace")

func _test_route_timing_changes_authoritative_trace() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var tick_two_route: Dictionary = runner.simulate(_record("run-a", _thermal_input()), 3, _thermal_defs(2))
	var tick_one_route: Dictionary = runner.simulate(_record("run-a", _thermal_input()), 3, _thermal_defs(1))
	_expect_true(tick_two_route["tick_checksums"] != tick_one_route["tick_checksums"], "authored route timing changes organism-state checksum sequence")

func _thermal_defs(event_tick: int) -> Dictionary:
	return {
		"route_profile": {
			"id": "route-slice",
			"tick_count": 3,
			"events": [
				{"tick": event_tick, "duration_ticks": 1, "hazard_id": "h01-slice", "authored_order": 0},
			],
		},
		"hold_definition": {
			"dimensions": [2, 1],
			"blocked_cells": [],
		},
		"hazards_by_id": {
			"h01-slice": {
				"id": "h01-slice",
				"family": "H01",
				"target_scope": "hold",
				"heat_delta": 6,
			},
		},
		"thermal_rules": {
			"heat_min": 0,
			"heat_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"specimen-a": {
				"initial_stress": 1,
				"initial_state": "CALM",
				"stress_profile": _stress_profile(2),
			},
			"specimen-b": {
				"initial_stress": 0,
				"initial_state": "CALM",
				"stress_profile": _stress_profile(10),
			},
		},
	}

func _stress_profile(heat_safe_max: int) -> Dictionary:
	return {
		"heat_safe_max": heat_safe_max,
		"stress_per_heat_unit": 2,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 5,
		"agitated_exit": 3,
		"panic_enter": 10,
		"panic_exit": 7,
	}

func _record(run_id: String, committed_input: Dictionary) -> Dictionary:
	return {
		"run_id": run_id,
		"rules_version": "rules-r1",
		"content_version": "vertical-slice-test-1",
		"canonical_committed_input": committed_input,
	}

func _input() -> Dictionary:
	return {
		"route_id": "route-slice",
		"seed": 101,
		"placements": [
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			{"instance_id": "specimen-b", "anchor": [1, 1], "orientation": 0},
		],
		"supports": [],
	}

func _input_reordered() -> Dictionary:
	return {
		"route_id": "route-slice",
		"seed": 101,
		"placements": [
			{"instance_id": "specimen-b", "anchor": [1, 1], "orientation": 0},
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
		],
		"supports": [],
	}

func _thermal_input() -> Dictionary:
	return {
		"route_id": "route-slice",
		"seed": 101,
		"placements": [
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			{"instance_id": "specimen-b", "anchor": [1, 0], "orientation": 0},
		],
		"supports": [],
	}

func _thermal_input_reordered() -> Dictionary:
	return {
		"route_id": "route-slice",
		"seed": 101,
		"placements": [
			{"instance_id": "specimen-b", "anchor": [1, 0], "orientation": 0},
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
		],
		"supports": [],
	}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
