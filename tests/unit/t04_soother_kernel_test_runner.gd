extends SceneTree

const T04SootherKernelScript := preload("res://src/sim/t04_soother_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_capacity_and_distance_order()
	_test_state_and_sleep_gates()
	_test_multiple_soothers_add_commutatively()
	_test_invalid_bands_rejected()
	_test_replay_is_deterministic()
	if failures == 0:
		print("t04_soother_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("t04_soother_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_capacity_and_distance_order() -> void:
	var kernel: T04SootherKernel = T04SootherKernelScript.new()
	var organisms: Array = [
		{"instance_id": "soother", "primary_state": "CALM", "occupied_cells": ["0,0"]},
		{"instance_id": "near-b", "primary_state": "AGITATED", "occupied_cells": ["1,0"]},
		{"instance_id": "near-a", "primary_state": "AGITATED", "occupied_cells": ["0,1"]},
		{"instance_id": "far", "primary_state": "AGITATED", "occupied_cells": ["2,0"]},
	]
	var result: Dictionary = kernel.resolve_phase_e(3, organisms, [{
		"instance_id": "soother",
		"amount": 2,
		"range": 2,
		"max_targets": 2,
		"eligible_target_ids": ["far", "near-b", "near-a"],
		"active_primary_states": ["CALM"],
		"sleep_gated": true,
	}])
	_expect_true(bool(result.get("ok", false)), "T04 capacity-limited selection resolves")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(result["stress_delta_by_target_id"], {"near-a": -2, "near-b": -2}, "T04 selects nearest targets then stable ID within capacity")
	var events: Array = result["events"]
	_expect_equal(events.size(), 2, "capacity two emits exactly two soothing assignments")
	if events.size() == 2:
		_expect_equal(String((events[0] as Dictionary).get("target_instance_id", "")), "near-a", "stable target tie-break uses lowest instance ID")
		_expect_equal(String((events[1] as Dictionary).get("target_instance_id", "")), "near-b", "second equal-distance target follows stable order")

func _test_state_and_sleep_gates() -> void:
	var kernel: T04SootherKernel = T04SootherKernelScript.new()
	var base: Array = [
		{"instance_id": "soother", "primary_state": "AGITATED", "occupied_cells": ["0,0"]},
		{"instance_id": "target", "primary_state": "AGITATED", "occupied_cells": ["1,0"]},
	]
	var definition: Dictionary = {
		"instance_id": "soother", "amount": 1, "range": 1, "max_targets": 1,
		"eligible_target_ids": ["target"], "active_primary_states": ["CALM"], "sleep_gated": true,
	}
	var gated_by_state: Dictionary = kernel.resolve_phase_e(1, base, [definition])
	_expect_true(bool(gated_by_state.get("ok", false)), "state-gated T04 resolves")
	if bool(gated_by_state.get("ok", false)):
		_expect_equal((gated_by_state["events"] as Array).size(), 0, "ineligible source state emits no soothing")
	var asleep: Array = base.duplicate(true)
	(asleep[0] as Dictionary)["primary_state"] = "ASLEEP"
	var gated_sleep: Dictionary = kernel.resolve_phase_e(1, asleep, [definition])
	_expect_true(bool(gated_sleep.get("ok", false)), "sleep-gated T04 resolves")
	if bool(gated_sleep.get("ok", false)):
		_expect_equal((gated_sleep["events"] as Array).size(), 0, "explicit sleep gate suppresses soothing")
	definition["sleep_gated"] = false
	var ungated_sleep: Dictionary = kernel.resolve_phase_e(1, asleep, [definition])
	_expect_true(bool(ungated_sleep.get("ok", false)), "non-sleep-gated T04 resolves")
	if bool(ungated_sleep.get("ok", false)):
		_expect_equal(int((ungated_sleep["stress_delta_by_target_id"] as Dictionary).get("target", 0)), -1, "sleep does not suppress T04 unless authored")

func _test_multiple_soothers_add_commutatively() -> void:
	var kernel: T04SootherKernel = T04SootherKernelScript.new()
	var organisms: Array = [
		{"instance_id": "z-soother", "primary_state": "CALM", "occupied_cells": ["2,0"]},
		{"instance_id": "a-soother", "primary_state": "CALM", "occupied_cells": ["0,0"]},
		{"instance_id": "target", "primary_state": "AGITATED", "occupied_cells": ["1,0"]},
	]
	var defs: Array = [
		{"instance_id": "z-soother", "amount": 1, "range": 1, "max_targets": 1, "eligible_target_ids": ["target"], "active_primary_states": ["CALM"], "sleep_gated": false},
		{"instance_id": "a-soother", "amount": 3, "range": 1, "max_targets": 1, "eligible_target_ids": ["target"], "active_primary_states": ["CALM"], "sleep_gated": false},
	]
	var result: Dictionary = kernel.resolve_phase_e(2, organisms, defs)
	_expect_true(bool(result.get("ok", false)), "multiple T04 sources resolve")
	if bool(result.get("ok", false)):
		_expect_equal(int((result["stress_delta_by_target_id"] as Dictionary).get("target", 0)), -4, "multiple direct social reductions combine additively")
		var events: Array = result["events"]
		_expect_equal(String((events[0] as Dictionary).get("source_instance_id", "")), "a-soother", "source resolution is stable by instance ID")

func _test_invalid_bands_rejected() -> void:
	var kernel: T04SootherKernel = T04SootherKernelScript.new()
	var result: Dictionary = kernel.resolve_phase_e(1, [
		{"instance_id": "s", "primary_state": "CALM", "occupied_cells": ["0,0"]},
		{"instance_id": "t", "primary_state": "CALM", "occupied_cells": ["1,0"]},
	], [{"instance_id": "s", "amount": 4, "range": 1, "max_targets": 1, "eligible_target_ids": ["t"], "active_primary_states": ["CALM"], "sleep_gated": false}])
	_expect_true(not bool(result.get("ok", false)), "T04 rejects direct-social magnitude outside frozen 1/2/3 band")
	_expect_equal(String(result.get("error", "")), "invalid_t04_amount:s", "invalid T04 amount error is explicit")

func _test_replay_is_deterministic() -> void:
	var kernel: T04SootherKernel = T04SootherKernelScript.new()
	var organisms: Array = [
		{"instance_id": "s", "primary_state": "CALM", "occupied_cells": ["0,0"]},
		{"instance_id": "t", "primary_state": "AGITATED", "occupied_cells": ["1,0"]},
	]
	var defs: Array = [{"instance_id": "s", "amount": 2, "range": 1, "max_targets": 1, "eligible_target_ids": ["t"], "active_primary_states": ["CALM"], "sleep_gated": false}]
	_expect_equal(kernel.resolve_phase_e(9, organisms, defs), kernel.resolve_phase_e(9, organisms, defs), "T04 replay is byte-equivalent")

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
