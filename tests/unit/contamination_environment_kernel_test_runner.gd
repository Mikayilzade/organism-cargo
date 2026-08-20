extends SceneTree

const ContaminationEnvironmentKernelScript := preload("res://src/sim/contamination_environment_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_h03_phase_c_adds_only_to_declared_cells_in_stable_order()
	_test_phase_d_uses_common_source_snapshot_for_transfer()
	_test_venting_decays_but_does_not_implicitly_erase_persistent_residue()
	_test_non_orthogonal_transfer_is_rejected()
	if failures == 0:
		print("contamination_environment_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("contamination_environment_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_h03_phase_c_adds_only_to_declared_cells_in_stable_order() -> void:
	var kernel: ContaminationEnvironmentKernel = ContaminationEnvironmentKernelScript.new()
	var result: Dictionary = kernel.apply_h03_phase_c(
		{"0,0": 1, "1,0": 0, "2,0": 4},
		PackedStringArray(["0,0", "1,0", "2,0"]),
		PackedStringArray(["leak-b", "leak-a"]),
		{
			"leak-a": {
				"family": "H03",
				"contamination_delta": 2,
				"target_cells": ["1,0", "0,0"],
			},
			"leak-b": {
				"family": "H03",
				"contamination_delta": 3,
				"target_cells": ["1,0"],
			},
		}
	)
	_expect_true(bool(result.get("ok", false)), "H03 Phase-C source application succeeds")
	var contamination: Dictionary = result["contamination_by_cell"]
	_expect_equal(int(contamination["0,0"]), 3, "H03 adds authored contamination to first declared cell")
	_expect_equal(int(contamination["1,0"]), 5, "multiple H03 sources add deterministically")
	_expect_equal(int(contamination["2,0"]), 4, "unselected cell preserves persistent contamination")
	var events: Array = result["events"]
	_expect_equal(events.size(), 3, "each H03 source-cell contribution emits one event")
	_expect_equal(String(events[0]["hazard_id"]), "leak-a", "H03 event order is stable by hazard ID")
	_expect_equal(String(events[0]["cell_key"]), "0,0", "H03 target-cell event order is stable")
	_expect_equal(String(events[2]["hazard_id"]), "leak-b", "later H03 event order remains deterministic")

func _test_phase_d_uses_common_source_snapshot_for_transfer() -> void:
	var kernel: ContaminationEnvironmentKernel = ContaminationEnvironmentKernelScript.new()
	var result: Dictionary = kernel.propagate_phase_d(
		{"0,0": 4, "1,0": 1, "2,0": 0},
		PackedStringArray(["0,0", "1,0", "2,0"]),
		{
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [
				{"from": "0,0", "to": "1,0", "amount": 2},
				{"from": "1,0", "to": "2,0", "amount": 1},
			],
			"vent_by_cell": {},
		}
	)
	_expect_true(bool(result.get("ok", false)), "Phase-D contamination propagation succeeds")
	var contamination: Dictionary = result["contamination_by_cell"]
	_expect_equal(int(contamination["0,0"]), 2, "first cell transfers only configured source-snapshot amount")
	_expect_equal(int(contamination["1,0"]), 2, "middle cell receives two while transferring its original one")
	_expect_equal(int(contamination["2,0"]), 1, "same-tick incoming contamination does not chain as new outgoing authority")

func _test_venting_decays_but_does_not_implicitly_erase_persistent_residue() -> void:
	var kernel: ContaminationEnvironmentKernel = ContaminationEnvironmentKernelScript.new()
	var rules: Dictionary = {
		"contamination_min": 0,
		"contamination_max": 20,
		"transfer_edges": [],
		"vent_by_cell": {"0,0": 2},
	}
	var first: Dictionary = kernel.propagate_phase_d(
		{"0,0": 5},
		PackedStringArray(["0,0"]),
		rules
	)
	_expect_true(bool(first.get("ok", false)), "first contamination vent step succeeds")
	_expect_equal(int(first["contamination_by_cell"]["0,0"]), 3, "venting subtracts only its configured amount")
	var second: Dictionary = kernel.propagate_phase_d(
		first["contamination_by_cell"],
		PackedStringArray(["0,0"]),
		rules
	)
	_expect_true(bool(second.get("ok", false)), "second contamination vent step succeeds")
	_expect_equal(int(second["contamination_by_cell"]["0,0"]), 1, "persistent residue survives when venting is smaller than stored contamination")

func _test_non_orthogonal_transfer_is_rejected() -> void:
	var kernel: ContaminationEnvironmentKernel = ContaminationEnvironmentKernelScript.new()
	var result: Dictionary = kernel.propagate_phase_d(
		{"0,0": 3, "1,1": 0},
		PackedStringArray(["0,0", "1,1"]),
		{
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [
				{"from": "0,0", "to": "1,1", "amount": 1},
			],
			"vent_by_cell": {},
		}
	)
	_expect_true(not bool(result.get("ok", false)), "diagonal contamination propagation is rejected")
	_expect_equal(
		String(result.get("error", "")),
		"non_orthogonal_contamination_transfer:0,0>1,1",
		"diagonal rejection reports the exact invalid edge"
	)

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
