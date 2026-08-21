extends SceneTree

const FixedMathScript := preload("res://src/sim/fixed_math.gd")
const ChecksumScript := preload("res://src/sim/checksum/canonical_checksum.gd")
const SimulationInputScript := preload("res://src/sim/model/simulation_input.gd")
const T05SporeShedderKernelScript := preload("res://src/sim/t05_spore_shedder_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _initialize() -> void:
	_test_fixed_math()
	_test_canonical_checksum()
	_test_simulation_input()
	_test_t05_spore_shedder_phase_c_contract()
	_test_t05_production_phase_c_integration()
	if failures == 0:
		print("BOOTSTRAP TESTS PASS")
		quit(0)
	else:
		push_error("BOOTSTRAP TESTS FAIL: %d" % failures)
		quit(1)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func _test_fixed_math() -> void:
	_expect_equal(FixedMathScript.FIXED_SCALE, 1000, "fixed scale")
	_expect_equal(FixedMathScript.mul_non_negative(100, 500), 50, "0.5 scaled multiply")
	_expect_equal(FixedMathScript.mul_non_negative(100, 1500), 150, "1.5 scaled multiply")
	_expect_equal(FixedMathScript.div_floor_non_negative(7, 3), 2, "non-negative floor division")
	_expect_equal(FixedMathScript.div_toward_zero_signed(-7, 3), -2, "signed division toward zero")

func _test_canonical_checksum() -> void:
	var ids: Array[StringName] = [&"alpha", &"beta"]
	var values: Array[int] = [500, 1500]
	var serialized: String = ChecksumScript.serialize_bootstrap_state("r0", "c0", 0, ids, values)
	_expect_equal(serialized, "rules=r0|content=c0|tick=0|alpha=500|beta=1500", "canonical serialization")
	_expect_equal(ChecksumScript.sha256(serialized), "c0910e1b5609e66cdf8177e9815c3d191300824f28ec03d815f57449dca405f2", "deterministic SHA-256")

func _test_simulation_input() -> void:
	var input: SimulationInput = SimulationInputScript.new("c0", "r0", &"C01", &"route_intro", 42)
	_expect_equal(input.content_version, "c0", "input content version")
	_expect_equal(input.rules_version, "r0", "input rules version")
	_expect_equal(input.contract_id, &"C01", "input contract id")
	_expect_equal(input.route_profile_id, &"route_intro", "input route id")
	_expect_equal(input.seed, 42, "input seed")

func _test_t05_spore_shedder_phase_c_contract() -> void:
	var kernel: T05SporeShedderKernel = T05SporeShedderKernelScript.new()
	var field: Dictionary = {"0,0": 1, "1,0": 0}
	var before: Dictionary = field.duplicate(true)
	var definition: Dictionary = {
		"instance_id": "spore-a",
		"output_amount": 3,
		"active_primary_states": ["PANICKED"],
		"active_body_stages": [],
		"sleep_gated": false,
	}
	var panicked: Dictionary = kernel.apply_phase_c(
		1,
		field,
		[{
			"instance_id": "spore-a",
			"occupied_cells": ["1,0", "0,0"],
			"primary_state": "PANICKED",
			"body_stage": "MATURE",
		}],
		[definition]
	)
	_expect_equal(bool(panicked.get("ok", false)), true, "T05 active source succeeds")
	if not bool(panicked.get("ok", false)):
		return
	_expect_equal(panicked["contamination_by_cell"], {"0,0": 4, "1,0": 3}, "T05 emits from every occupied source cell")
	_expect_equal(field, before, "T05 input environment remains immutable")
	var events: Array = panicked["events"]
	_expect_equal(events.size(), 2, "T05 emits one causal record per source cell")
	var first_event: Dictionary = events[0]
	_expect_equal(String(first_event.get("cell_key", "")), "0,0", "T05 source order is stable")

	var calm: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 0},
		[{
			"instance_id": "spore-a",
			"occupied_cells": ["0,0"],
			"primary_state": "CALM",
			"body_stage": "MATURE",
		}],
		[definition]
	)
	var calm_field: Dictionary = calm.get("contamination_by_cell", {})
	_expect_equal(int(calm_field.get("0,0", -1)), 0, "T05 state gate suppresses nonmatching state")

	var asleep_not_gated: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 0},
		[{
			"instance_id": "spore-a",
			"occupied_cells": ["0,0"],
			"primary_state": "ASLEEP",
			"body_stage": "MATURE",
		}],
		[definition]
	)
	var asleep_not_gated_field: Dictionary = asleep_not_gated.get("contamination_by_cell", {})
	_expect_equal(int(asleep_not_gated_field.get("0,0", -1)), 3, "sleep does not suppress T05 without explicit sleep gating")

	var sleep_gated_definition: Dictionary = definition.duplicate(true)
	sleep_gated_definition["sleep_gated"] = true
	var asleep_gated: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 0},
		[{
			"instance_id": "spore-a",
			"occupied_cells": ["0,0"],
			"primary_state": "ASLEEP",
			"body_stage": "MATURE",
		}],
		[sleep_gated_definition]
	)
	var asleep_gated_field: Dictionary = asleep_gated.get("contamination_by_cell", {})
	_expect_equal(int(asleep_gated_field.get("0,0", -1)), 0, "explicit sleep gate suppresses T05")

func _test_t05_production_phase_c_integration() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var active_defs: Dictionary = _production_t05_defs("PANICKED", false, false)
	var active_record: Dictionary = _production_t05_record(false)
	var active: Dictionary = runner.simulate(active_record, 1, active_defs)
	_expect_true(bool(active.get("ok", false)), "production T05 active run succeeds")
	if not bool(active.get("ok", false)):
		return
	var active_snapshots: Array = active["end_tick_snapshots"]
	var active_snapshot: Dictionary = active_snapshots[0]
	var active_field: Dictionary = active_snapshot["contamination_by_cell"]
	_expect_equal(active_field, {"0,0": 3, "1,0": 3}, "production T05 uses current two-cell footprint before Phase D")
	var phase_c_events: Array = active_snapshot["phase_c_environment_events"]
	_expect_equal(phase_c_events.size(), 2, "production T05 exposes one Phase-C event per occupied cell")
	if phase_c_events.size() >= 1:
		var first_phase_c_event: Dictionary = phase_c_events[0]
		_expect_equal(String(first_phase_c_event.get("kind", "")), "T05_SPORE_SOURCE", "production T05 event kind is preserved")
		_expect_equal(String(first_phase_c_event.get("instance_id", "")), "spore-a", "production T05 causal source identity is preserved")

	var repeated: Dictionary = runner.simulate(active_record, 1, active_defs)
	_expect_true(bool(repeated.get("ok", false)), "production T05 deterministic replay succeeds")
	if bool(repeated.get("ok", false)):
		_expect_equal(repeated["tick_checksums"], active["tick_checksums"], "production T05 replay checksum is deterministic")

	var calm_defs: Dictionary = _production_t05_defs("CALM", false, false)
	var calm: Dictionary = runner.simulate(active_record, 1, calm_defs)
	_expect_true(bool(calm.get("ok", false)), "production T05 calm state-gate run succeeds")
	if bool(calm.get("ok", false)):
		var calm_snapshots: Array = calm["end_tick_snapshots"]
		var calm_snapshot: Dictionary = calm_snapshots[0]
		var calm_production_field: Dictionary = calm_snapshot["contamination_by_cell"]
		_expect_equal(calm_production_field, {"0,0": 0, "1,0": 0}, "production T05 state gate suppresses nonmatching runtime state")

	var asleep_open_defs: Dictionary = _production_t05_defs("ASLEEP", false, false)
	var asleep_open: Dictionary = runner.simulate(active_record, 1, asleep_open_defs)
	_expect_true(bool(asleep_open.get("ok", false)), "production T05 non-sleep-gated run succeeds")
	if bool(asleep_open.get("ok", false)):
		var asleep_open_snapshots: Array = asleep_open["end_tick_snapshots"]
		var asleep_open_snapshot: Dictionary = asleep_open_snapshots[0]
		var asleep_open_field: Dictionary = asleep_open_snapshot["contamination_by_cell"]
		_expect_equal(asleep_open_field, {"0,0": 3, "1,0": 3}, "ASLEEP does not suppress T05 without explicit sleep gate")

	var asleep_gated_defs: Dictionary = _production_t05_defs("ASLEEP", true, false)
	var asleep_gated: Dictionary = runner.simulate(active_record, 1, asleep_gated_defs)
	_expect_true(bool(asleep_gated.get("ok", false)), "production T05 sleep-gated run succeeds")
	if bool(asleep_gated.get("ok", false)):
		var asleep_gated_snapshots: Array = asleep_gated["end_tick_snapshots"]
		var asleep_gated_snapshot: Dictionary = asleep_gated_snapshots[0]
		var asleep_gated_field: Dictionary = asleep_gated_snapshot["contamination_by_cell"]
		_expect_equal(asleep_gated_field, {"0,0": 0, "1,0": 0}, "explicit sleep gate suppresses production T05")

	var combined_defs: Dictionary = _production_t05_defs("PANICKED", false, true)
	var combined_record: Dictionary = _production_t05_record(true)
	var combined: Dictionary = runner.simulate(combined_record, 1, combined_defs)
	_expect_true(bool(combined.get("ok", false)), "production T05 + H03 + S02 run succeeds")
	if bool(combined.get("ok", false)):
		var combined_snapshots: Array = combined["end_tick_snapshots"]
		var combined_snapshot: Dictionary = combined_snapshots[0]
		var combined_field: Dictionary = combined_snapshot["contamination_by_cell"]
		_expect_equal(combined_field, {"0,0": 4, "1,0": 3}, "Phase C orders T05 then H03 then authorized S02 before Phase D")
		var combined_environment_events: Array = combined_snapshot["phase_c_environment_events"]
		_expect_equal(combined_environment_events.size(), 3, "T05 and H03 source evidence coexist in Phase C")
		var support_events: Array = combined_snapshot["phase_c_support_events"]
		_expect_equal(support_events.size(), 1, "S02 remains the single mitigation event")
		if support_events.size() == 1:
			var filter_event: Dictionary = support_events[0]
			_expect_equal(int(filter_event.get("contamination_before", -1)), 5, "S02 observes additive T05 + H03 source field")

func _production_t05_record(with_filter: bool) -> Dictionary:
	var supports: Array = []
	var priority: Array = []
	if with_filter:
		supports.append({"instance_id": "filter-a", "support_id": "S02", "anchor": [0, 0]})
		priority.append("filter-a")
	return {
		"run_id": "t05-production-run",
		"rules_version": "rules-r1",
		"content_version": "t05-production-1",
		"canonical_committed_input": {
			"route_id": "route-t05-production",
			"seed": 51,
			"placements": [{"instance_id": "spore-a", "anchor": [0, 0], "orientation": 0}],
			"supports": supports,
			"brownout_priority": priority,
		},
	}

func _production_t05_defs(initial_state: String, sleep_gated: bool, with_h03_and_filter: bool) -> Dictionary:
	var events: Array = []
	var hazards: Dictionary = {}
	var support_definitions: Dictionary = {}
	var power_capacity: int = 0
	if with_h03_and_filter:
		events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h03-t05", "authored_order": 0})
		hazards["h03-t05"] = {
			"id": "h03-t05",
			"family": "H03",
			"contamination_delta": 2,
			"target_cells": ["0,0"],
		}
		support_definitions["S02"] = {
			"id": "S02",
			"family": "S02",
			"powered": true,
			"power_draw": 2,
			"contamination_removal_capacity": 1,
		}
		power_capacity = 2
	return {
		"route_profile": {
			"id": "route-t05-production",
			"tick_count": 1,
			"events": events,
		},
		"hold_definition": {
			"dimensions": [2, 1],
			"blocked_cells": [],
			"power_capacity": power_capacity,
		},
		"hazards_by_id": hazards,
		"support_definitions_by_id": support_definitions,
		"contamination_rules": {
			"contamination_min": 0,
			"contamination_max": 40,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"spore-a": {
				"initial_state": initial_state,
				"initial_stress": 0,
				"stress_profile": {
					"heat_safe_max": 99,
					"stress_per_heat_unit": 0,
					"stress_min": 0,
					"stress_max": 20,
					"agitated_enter": 6,
					"agitated_exit": 3,
					"panic_enter": 11,
					"panic_exit": 7,
				},
				"initial_body_stage": "MATURE",
				"body_stages": {
					"MATURE": {
						"footprints": {"0": [[0, 0], [1, 0]]},
					},
				},
				"contamination_profile": {
					"intake_multiplier_scaled": 1000,
					"load_min": 0,
					"load_max": 40,
					"contaminated_enter": 8,
					"contaminated_exit": 4,
				},
			},
		},
		"t05_definitions": [{
			"instance_id": "spore-a",
			"output_amount": 3,
			"active_primary_states": ["PANICKED"],
			"active_body_stages": ["MATURE"],
			"sleep_gated": sleep_gated,
		}],
	}
