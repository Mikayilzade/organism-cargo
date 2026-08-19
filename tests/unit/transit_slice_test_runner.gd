extends SceneTree

const TransitSliceRunnerScript := preload("res://src/sim/transit_slice_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_deterministic_phase_order_and_checksums()
	_test_run_identity_does_not_change_authoritative_trace()
	_test_input_change_changes_authoritative_trace()
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

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
