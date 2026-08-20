extends SceneTree

const S01CoolerKernelScript := preload("res://src/sim/s01_cooler_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_eligible_cooler_removes_only_local_heat_up_to_capacity()
	_test_brownout_disabled_cooler_has_zero_same_tick_effect()
	_test_multiple_coolers_are_deterministic_and_capacity_limited()
	if failures == 0:
		print("s01_cooler_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("s01_cooler_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_eligible_cooler_removes_only_local_heat_up_to_capacity() -> void:
	var kernel: S01CoolerKernel = S01CoolerKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		{"0,0": 7, "1,0": 5},
		[_support("cooler-a", "S01-basic", [0, 0])],
		_defs(3),
		PackedStringArray(["cooler-a"])
	)
	_expect_true(bool(result.get("ok", false)), "eligible S01 application succeeds")
	var heat: Dictionary = result["heat_by_cell"]
	_expect_equal(int(heat["0,0"]), 4, "S01 removes exactly its configured local capacity")
	_expect_equal(int(heat["1,0"]), 5, "S01 does not remove heat from another cell")
	var events: Array = result["events"]
	_expect_equal(events.size(), 1, "one eligible S01 emits one Phase-C event")
	_expect_equal(String(events[0]["phase"]), "C", "S01 effect declares canonical Phase-C ownership")
	_expect_equal(int(events[0]["removed_heat"]), 3, "event records exact removed heat")

func _test_brownout_disabled_cooler_has_zero_same_tick_effect() -> void:
	var kernel: S01CoolerKernel = S01CoolerKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		{"0,0": 7},
		[_support("cooler-a", "S01-basic", [0, 0])],
		_defs(3),
		PackedStringArray()
	)
	_expect_true(bool(result.get("ok", false)), "disabled S01 is a legal no-op")
	_expect_equal(int(result["heat_by_cell"]["0,0"]), 7, "Brownout-disabled S01 removes zero same-tick heat")
	_expect_equal((result["events"] as Array).size(), 0, "disabled S01 emits no mitigation event")

func _test_multiple_coolers_are_deterministic_and_capacity_limited() -> void:
	var kernel: S01CoolerKernel = S01CoolerKernelScript.new()
	var supports: Array = [
		_support("cooler-b", "S01-basic", [0, 0]),
		_support("cooler-a", "S01-basic", [0, 0]),
	]
	var eligible := PackedStringArray(["cooler-b", "cooler-a"])
	var first: Dictionary = kernel.apply_phase_c({"0,0": 4}, supports, _defs(3), eligible)
	supports.reverse()
	var second: Dictionary = kernel.apply_phase_c({"0,0": 4}, supports, _defs(3), eligible)
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "multi-S01 applications succeed")
	_expect_equal(int(first["heat_by_cell"]["0,0"]), 0, "combined local removal clamps at available heat")
	_expect_equal(first["heat_by_cell"], second["heat_by_cell"], "committed support ordering does not change authoritative heat")
	var first_events: Array = first["events"]
	var second_events: Array = second["events"]
	_expect_equal(String(first_events[0]["instance_id"]), "cooler-a", "capacity consumption order is stable by instance ID")
	_expect_equal(first_events, second_events, "S01 causal event order is deterministic")
	_expect_equal(int(first_events[0]["removed_heat"]), 3, "first cooler consumes at most capacity")
	_expect_equal(int(first_events[1]["removed_heat"]), 1, "second cooler consumes only remaining local heat")

func _support(instance_id: String, support_id: String, anchor: Array) -> Dictionary:
	return {
		"instance_id": instance_id,
		"support_id": support_id,
		"anchor": anchor,
	}

func _defs(capacity: int) -> Dictionary:
	return {
		"S01-basic": {
			"id": "S01-basic",
			"family": "S01",
			"powered": true,
			"heat_removal_capacity": capacity,
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
