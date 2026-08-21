extends SceneTree

const FixedMathScript := preload("res://src/sim/fixed_math.gd")
const ChecksumScript := preload("res://src/sim/checksum/canonical_checksum.gd")
const SimulationInputScript := preload("res://src/sim/model/simulation_input.gd")
const T05SporeShedderKernelScript := preload("res://src/sim/t05_spore_shedder_kernel.gd")

var failures: int = 0

func _initialize() -> void:
	_test_fixed_math()
	_test_canonical_checksum()
	_test_simulation_input()
	_test_t05_spore_shedder_phase_c_contract()
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
	_expect_equal(String(events[0]["cell_key"]), "0,0", "T05 source order is stable")

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
