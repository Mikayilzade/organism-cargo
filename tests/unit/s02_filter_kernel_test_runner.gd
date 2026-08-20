extends SceneTree

const S02FilterKernelScript := preload("res://src/sim/s02_filter_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_eligible_filter_removes_only_local_contamination_up_to_capacity()
	_test_brownout_disabled_filter_has_zero_same_tick_effect()
	_test_multiple_filters_are_deterministic_and_capacity_limited()
	if failures == 0:
		print("s02_filter_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("s02_filter_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_eligible_filter_removes_only_local_contamination_up_to_capacity() -> void:
	var kernel: S02FilterKernel = S02FilterKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		{"0,0": 7, "1,0": 5},
		[_support("filter-a", "S02-basic", [0, 0])],
		_defs(3),
		PackedStringArray(["filter-a"])
	)
	_expect_true(bool(result.get("ok", false)), "eligible S02 application succeeds")
	var contamination: Dictionary = result["contamination_by_cell"]
	_expect_equal(int(contamination["0,0"]), 4, "S02 removes exactly its configured local capacity")
	_expect_equal(int(contamination["1,0"]), 5, "S02 does not remove contamination from another cell")
	var events: Array = result["events"]
	_expect_equal(events.size(), 1, "one eligible S02 emits one Phase-C event")
	_expect_equal(String(events[0]["phase"]), "C", "S02 effect declares canonical Phase-C ownership")
	_expect_equal(int(events[0]["removed_contamination"]), 3, "event records exact removed contamination")

func _test_brownout_disabled_filter_has_zero_same_tick_effect() -> void:
	var kernel: S02FilterKernel = S02FilterKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		{"0,0": 7},
		[_support("filter-a", "S02-basic", [0, 0])],
		_defs(3),
		PackedStringArray()
	)
	_expect_true(bool(result.get("ok", false)), "disabled S02 is a legal no-op")
	_expect_equal(int(result["contamination_by_cell"]["0,0"]), 7, "Brownout-disabled S02 removes zero same-tick contamination")
	_expect_equal((result["events"] as Array).size(), 0, "disabled S02 emits no mitigation event")

func _test_multiple_filters_are_deterministic_and_capacity_limited() -> void:
	var kernel: S02FilterKernel = S02FilterKernelScript.new()
	var supports: Array = [
		_support("filter-b", "S02-basic", [0, 0]),
		_support("filter-a", "S02-basic", [0, 0]),
	]
	var eligible := PackedStringArray(["filter-b", "filter-a"])
	var first: Dictionary = kernel.apply_phase_c({"0,0": 4}, supports, _defs(3), eligible)
	supports.reverse()
	var second: Dictionary = kernel.apply_phase_c({"0,0": 4}, supports, _defs(3), eligible)
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "multi-S02 applications succeed")
	_expect_equal(int(first["contamination_by_cell"]["0,0"]), 0, "combined local removal clamps at available contamination")
	_expect_equal(first["contamination_by_cell"], second["contamination_by_cell"], "committed support ordering does not change authoritative contamination")
	var first_events: Array = first["events"]
	var second_events: Array = second["events"]
	_expect_equal(String(first_events[0]["instance_id"]), "filter-a", "capacity consumption order is stable by instance ID")
	_expect_equal(first_events, second_events, "S02 causal event order is deterministic")
	_expect_equal(int(first_events[0]["removed_contamination"]), 3, "first filter consumes at most capacity")
	_expect_equal(int(first_events[1]["removed_contamination"]), 1, "second filter consumes only remaining local contamination")

func _support(instance_id: String, support_id: String, anchor: Array) -> Dictionary:
	return {
		"instance_id": instance_id,
		"support_id": support_id,
		"anchor": anchor,
	}

func _defs(capacity: int) -> Dictionary:
	return {
		"S02-basic": {
			"id": "S02-basic",
			"family": "S02",
			"powered": true,
			"contamination_removal_capacity": capacity,
		},
	}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
