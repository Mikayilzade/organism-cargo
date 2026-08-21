extends SceneTree

const StressFieldEnvironmentKernelScript := preload("res://src/sim/stress_field_environment_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_h02_phase_c_stable_source_application()
	_test_phase_d_common_source_snapshot_and_decay()
	_test_diagonal_transfer_rejected()
	_test_deterministic_replay()
	if failures == 0:
		print("stress_field_environment_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("stress_field_environment_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_h02_phase_c_stable_source_application() -> void:
	var kernel: StressFieldEnvironmentKernel = StressFieldEnvironmentKernelScript.new()
	var original: Dictionary = {"0,0": 0, "1,0": 1, "2,0": 0}
	var before: Dictionary = original.duplicate(true)
	var result: Dictionary = kernel.apply_h02_phase_c(
		original,
		PackedStringArray(["0,0", "1,0", "2,0"]),
		PackedStringArray(["vibration-b", "vibration-a"]),
		{
			"vibration-a": {"family": "H02", "stress_field_delta": 2, "target_cells": ["1,0", "0,0"]},
			"vibration-b": {"family": "H02", "stress_field_delta": 3, "target_cells": ["1,0"]},
		}
	)
	_expect_true(bool(result.get("ok", false)), "H02 Phase-C source application succeeds")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(original, before, "H02 does not mutate the input snapshot")
	var field: Dictionary = result["stress_field_by_cell"]
	_expect_equal(field, {"0,0": 2, "1,0": 6, "2,0": 0}, "H02 sources combine additively")
	var events: Array = result["events"]
	_expect_equal(events.size(), 3, "H02 emits one causal source event per target cell")
	_expect_equal(String(events[0]["hazard_id"]), "vibration-a", "H02 hazard ordering is stable")
	_expect_equal(String(events[0]["cell_key"]), "0,0", "H02 target ordering is stable")

func _test_phase_d_common_source_snapshot_and_decay() -> void:
	var kernel: StressFieldEnvironmentKernel = StressFieldEnvironmentKernelScript.new()
	var result: Dictionary = kernel.propagate_phase_d(
		{"0,0": 5, "1,0": 1, "2,0": 0},
		PackedStringArray(["0,0", "1,0", "2,0"]),
		{
			"stress_field_min": 0,
			"stress_field_max": 20,
			"transfer_edges": [
				{"from": "0,0", "to": "1,0", "amount": 2},
				{"from": "1,0", "to": "2,0", "amount": 1},
			],
			"decay_by_cell": {"0,0": 1, "1,0": 1, "2,0": 1},
		}
	)
	_expect_true(bool(result.get("ok", false)), "Phase-D stress-field propagation succeeds")
	if not bool(result.get("ok", false)):
		return
	var field: Dictionary = result["stress_field_by_cell"]
	_expect_equal(int(field["0,0"]), 2, "source cell transfers then decays")
	_expect_equal(int(field["1,0"]), 1, "middle cell uses common source snapshot before decay")
	_expect_equal(int(field["2,0"]), 0, "same-tick incoming value does not chain before decay")

func _test_diagonal_transfer_rejected() -> void:
	var kernel: StressFieldEnvironmentKernel = StressFieldEnvironmentKernelScript.new()
	var result: Dictionary = kernel.propagate_phase_d(
		{"0,0": 3, "1,1": 0},
		PackedStringArray(["0,0", "1,1"]),
		{
			"stress_field_min": 0,
			"stress_field_max": 20,
			"transfer_edges": [{"from": "0,0", "to": "1,1", "amount": 1}],
			"decay_by_cell": {},
		}
	)
	_expect_true(not bool(result.get("ok", false)), "diagonal stress-field transfer is rejected")
	_expect_equal(String(result.get("error", "")), "non_orthogonal_stress_field_transfer:0,0>1,1", "diagonal rejection identifies edge")

func _test_deterministic_replay() -> void:
	var kernel: StressFieldEnvironmentKernel = StressFieldEnvironmentKernelScript.new()
	var field: Dictionary = {"0,0": 0, "1,0": 0}
	var cells: PackedStringArray = PackedStringArray(["0,0", "1,0"])
	var hazards: Dictionary = {"vibration": {"family": "H02", "stress_field_delta": 4, "target_cells": ["0,0"]}}
	var first_c: Dictionary = kernel.apply_h02_phase_c(field, cells, PackedStringArray(["vibration"]), hazards)
	var second_c: Dictionary = kernel.apply_h02_phase_c(field, cells, PackedStringArray(["vibration"]), hazards)
	_expect_equal(first_c, second_c, "H02 Phase-C replay is deterministic")
	var rules: Dictionary = {
		"stress_field_min": 0,
		"stress_field_max": 20,
		"transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}],
		"decay_by_cell": {"0,0": 1, "1,0": 1},
	}
	var first_d: Dictionary = kernel.propagate_phase_d(first_c["stress_field_by_cell"], cells, rules)
	var second_d: Dictionary = kernel.propagate_phase_d(second_c["stress_field_by_cell"], cells, rules)
	_expect_equal(first_d, second_d, "stress-field Phase-D replay is deterministic")

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
