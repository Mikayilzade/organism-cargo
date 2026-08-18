extends SceneTree

const FixedMathScript := preload("res://src/sim/fixed_math.gd")
const ChecksumScript := preload("res://src/sim/checksum/canonical_checksum.gd")
const SimulationInputScript := preload("res://src/sim/model/simulation_input.gd")

var failures: int = 0

func _initialize() -> void:
	_test_fixed_math()
	_test_canonical_checksum()
	_test_simulation_input()
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
	var input = SimulationInputScript.new("c0", "r0", &"C01", &"route_intro", 42)
	_expect_equal(input.content_version, "c0", "input content version")
	_expect_equal(input.rules_version, "r0", "input rules version")
	_expect_equal(input.contract_id, &"C01", "input contract id")
	_expect_equal(input.route_profile_id, &"route_intro", "input route id")
	_expect_equal(input.seed, 42, "input seed")
