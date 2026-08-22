extends SceneTree

const S03BaffleKernelScript := preload("res://src/sim/s03_baffle_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_stress_boundary_blocks_only_crossing_transfer()
	_test_boundary_is_bidirectional_without_inventing_magnitude()
	_test_directed_ray_stops_at_first_baffle_fixture()
	_test_invalid_boundary_is_rejected()
	_test_replay_and_checksum_sensitivity()
	if failures == 0:
		print("s03_baffle_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("s03_baffle_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_stress_boundary_blocks_only_crossing_transfer() -> void:
	var kernel: S03BaffleKernel = S03BaffleKernelScript.new()
	var base: Dictionary = _rules([
		{"from": "0,0", "to": "1,0", "amount": 2},
		{"from": "1,0", "to": "2,0", "amount": 1},
	])
	var original: Dictionary = base.duplicate(true)
	var result: Dictionary = kernel.apply_phase_d_transmission(base, [_boundary("baffle-a", "0,0", "1,0")])
	_expect_true(bool(result.get("ok", false)), "S03 accepts an authored orthogonal boundary")
	if not bool(result.get("ok", false)):
		return
	var edges: Array = result["rules"]["transfer_edges"]
	_expect_equal(edges.size(), 1, "S03 removes only stress transfer crossing its boundary")
	_expect_equal(String(edges[0]["from"]), "1,0", "unrelated transmission edge remains")
	_expect_equal(int(edges[0]["amount"]), 1, "S03 does not invent a replacement transmission magnitude")
	_expect_equal(base, original, "S03 transmission transform does not mutate upstream Phase-D rules")
	_expect_equal(String(result["events"][0]["kind"]), "S03_STRESS_TRANSFER_BLOCKED", "blocked transmission is causally visible")
	_expect_equal(String(result["events"][0]["phase"]), "D", "stress transmission modification occurs at Phase D")

func _test_boundary_is_bidirectional_without_inventing_magnitude() -> void:
	var kernel: S03BaffleKernel = S03BaffleKernelScript.new()
	var result: Dictionary = kernel.apply_phase_d_transmission(
		_rules([{"from": "1,0", "to": "0,0", "amount": 3}]),
		[_boundary("baffle-a", "0,0", "1,0")]
	)
	_expect_true(bool(result.get("ok", false)), "S03 boundary applies independent of authored transfer direction")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(result["rules"]["transfer_edges"], [], "reverse stress transfer across same physical boundary is blocked")
	_expect_equal(int(result["events"][0]["amount"]), 3, "event records the exact blocked upstream amount rather than a new S03 value")

func _test_directed_ray_stops_at_first_baffle_fixture() -> void:
	var kernel: S03BaffleKernel = S03BaffleKernelScript.new()
	var ray: PackedStringArray = PackedStringArray(["1,0", "2,0", "3,0"])
	var result: Dictionary = kernel.clip_directed_ray(ray, [
		{"support_instance_id": "baffle-far", "cell_key": "3,0"},
		{"support_instance_id": "baffle-near", "cell_key": "2,0"},
	])
	_expect_true(bool(result.get("ok", false)), "S03 can participate in canonical directed fixture interception")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(result["visible_cells"], PackedStringArray(["1,0"]), "directed relation stops at the first Baffle fixture cell")
	_expect_equal(String(result["events"][0]["support_instance_id"]), "baffle-near", "first blocker is selected by ray order, not dictionary/support order")
	_expect_equal(String(result["events"][0]["phase"]), "E", "directed relation interception is a Phase-E authority")

func _test_invalid_boundary_is_rejected() -> void:
	var kernel: S03BaffleKernel = S03BaffleKernelScript.new()
	var result: Dictionary = kernel.apply_phase_d_transmission(
		_rules([{"from": "0,0", "to": "1,0", "amount": 1}]),
		[_boundary("baffle-a", "0,0", "1,1")]
	)
	_expect_true(not bool(result.get("ok", false)), "S03 refuses diagonal/non-orthogonal boundaries")
	_expect_equal(String(result.get("error", "")), "non_orthogonal_s03_boundary:0,0>1,1", "invalid boundary failure is exact")

func _test_replay_and_checksum_sensitivity() -> void:
	var kernel: S03BaffleKernel = S03BaffleKernelScript.new()
	var base: Dictionary = _rules([{"from": "0,0", "to": "1,0", "amount": 2}])
	var blocked: Array = [_boundary("baffle-a", "0,0", "1,0")]
	var first: Dictionary = kernel.apply_phase_d_transmission(base, blocked)
	var replay: Dictionary = kernel.apply_phase_d_transmission(base, blocked)
	var open: Dictionary = kernel.apply_phase_d_transmission(base, [])
	_expect_equal(first, replay, "S03 transmission replay is deterministic")
	_expect_true(bool(first.get("ok", false)) and bool(open.get("ok", false)), "checksum comparison fixtures resolve")
	if not bool(first.get("ok", false)) or not bool(open.get("ok", false)):
		return
	_expect_true(String(first["checksum_material"]) != String(open["checksum_material"]), "S03 blocked relation is checksum-visible")

func _rules(edges: Array) -> Dictionary:
	return {
		"stress_field_min": 0,
		"stress_field_max": 20,
		"transfer_edges": edges,
		"decay_by_cell": {},
	}

func _boundary(instance_id: String, left: String, right: String) -> Dictionary:
	return {"support_instance_id": instance_id, "a": left, "b": right}

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)
