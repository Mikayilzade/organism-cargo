extends SceneTree

const ContaminationEnvironmentKernelScript := preload("res://src/sim/contamination_environment_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_h03_phase_c_adds_only_to_declared_cells_in_stable_order()
	_test_phase_d_uses_common_source_snapshot_for_transfer()
	_test_venting_decays_but_does_not_implicitly_erase_persistent_residue()
	_test_non_orthogonal_transfer_is_rejected()
	_test_transit_h03_s02_phase_c_then_phase_d_order()
	_test_transit_brownout_disabled_s02_has_zero_same_tick_mitigation()
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

func _test_transit_h03_s02_phase_c_then_phase_d_order() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_contamination_record(["filter-a"]), 1, _contamination_defs(false))
	_expect_true(bool(result.get("ok", false)), "production transit executes H03 plus powered S02")
	if not bool(result.get("ok", false)):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	var contamination: Dictionary = snapshot["contamination_by_cell"]
	_expect_equal(int(contamination["0,0"]), 2, "H03 adds five, S02 removes one, then Phase D transfers two from the common post-filter source snapshot")
	_expect_equal(int(contamination["1,0"]), 2, "Phase D publishes transferred contamination to the orthogonal neighbor")
	var environment_events: Array = snapshot["phase_c_environment_events"]
	_expect_equal(environment_events.size(), 1, "active H03 emits one deterministic Phase-C source event")
	_expect_equal(String(environment_events[0]["kind"]), "H03_CONTAMINATION_SOURCE", "production snapshot identifies the H03 source event")
	var support_events: Array = snapshot["phase_c_support_events"]
	_expect_equal(support_events.size(), 1, "authorized S02 emits one Phase-C mitigation event")
	_expect_equal(int(support_events[0]["removed_contamination"]), 1, "S02 mitigation event records exact contamination removal")
	_expect_equal(int(support_events[0]["contamination_before"]), 5, "S02 sees H03 output from the same Phase C before Phase-D propagation")

func _test_transit_brownout_disabled_s02_has_zero_same_tick_mitigation() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var filter_first: Dictionary = runner.simulate(_contamination_record(["filter-a", "monitor-a"]), 1, _contamination_defs(true))
	var monitor_first: Dictionary = runner.simulate(_contamination_record(["monitor-a", "filter-a"]), 1, _contamination_defs(true))
	_expect_true(bool(filter_first.get("ok", false)) and bool(monitor_first.get("ok", false)), "both legal Brownout priorities execute with H03 plus H04")
	if not bool(filter_first.get("ok", false)) or not bool(monitor_first.get("ok", false)):
		return
	var filter_snapshot: Dictionary = filter_first["end_tick_snapshots"][0]
	var monitor_snapshot: Dictionary = monitor_first["end_tick_snapshots"][0]
	_expect_equal(filter_snapshot["same_tick_effect_eligible_support_ids"], PackedStringArray(["filter-a"]), "filter-first priority authorizes S02 in Phase A")
	_expect_equal(monitor_snapshot["same_tick_effect_eligible_support_ids"], PackedStringArray(["monitor-a"]), "monitor-first priority disables S02 in Phase A")
	_expect_equal(int(filter_snapshot["contamination_by_cell"]["0,0"]), 2, "authorized S02 mitigates H03 before Phase-D propagation")
	_expect_equal(int(monitor_snapshot["contamination_by_cell"]["0,0"]), 3, "Brownout-disabled S02 leaves H03 source unmitigated before the same Phase-D transfer")
	_expect_equal(monitor_snapshot["phase_c_support_events"], [], "Brownout-disabled S02 emits no Phase-C mitigation event")
	_expect_true(String(filter_first["tick_checksums"][0]) != String(monitor_first["tick_checksums"][0]), "S02 Phase-C authority and contamination field are checksum-visible")

func _contamination_record(priority: Array) -> Dictionary:
	var supports: Array = [
		{"instance_id": "filter-a", "support_id": "S02", "anchor": [0, 0]},
	]
	if priority.size() > 1:
		supports.append({"instance_id": "monitor-a", "support_id": "S06"})
	return {
		"run_id": "contamination-integration-run",
		"rules_version": "rules-r1",
		"content_version": "contamination-integration-1",
		"canonical_committed_input": {
			"route_id": "route-contamination-test",
			"seed": 41,
			"placements": [
				{"instance_id": "specimen-a", "anchor": [1, 0], "orientation": 0},
			],
			"supports": supports,
			"brownout_priority": priority.duplicate(true),
		},
	}

func _contamination_defs(with_brownout: bool) -> Dictionary:
	var events: Array = [
		{"tick": 1, "duration_ticks": 1, "hazard_id": "h03-test", "authored_order": 0},
	]
	var hazards: Dictionary = {
		"h03-test": {
			"id": "h03-test",
			"family": "H03",
			"contamination_delta": 5,
			"target_cells": ["0,0"],
		},
	}
	if with_brownout:
		events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h04-test", "authored_order": 1})
		hazards["h04-test"] = {
			"id": "h04-test",
			"family": "H04",
			"target_scope": "hold",
			"power_reduction": 1,
		}
	return {
		"route_profile": {
			"id": "route-contamination-test",
			"tick_count": 1,
			"events": events,
		},
		"hold_definition": {
			"dimensions": [2, 1],
			"blocked_cells": [],
			"power_capacity": 3,
		},
		"hazards_by_id": hazards,
		"support_definitions_by_id": {
			"S02": {"id": "S02", "family": "S02", "powered": true, "power_draw": 2, "contamination_removal_capacity": 1},
			"S06": {"id": "S06", "family": "S06", "powered": true, "power_draw": 1},
		},
		"contamination_rules": {
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [
				{"from": "0,0", "to": "1,0", "amount": 2},
			],
			"vent_by_cell": {},
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