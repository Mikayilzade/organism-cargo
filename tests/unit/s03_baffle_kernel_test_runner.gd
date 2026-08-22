extends SceneTree

const S03BaffleKernelScript := preload("res://src/sim/s03_baffle_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_stress_boundary_blocks_only_crossing_transfer()
	_test_boundary_is_bidirectional_without_inventing_magnitude()
	_test_directed_ray_stops_at_first_baffle_fixture()
	_test_invalid_boundary_is_rejected()
	_test_replay_and_checksum_sensitivity()
	_test_production_h02_s03_phase_d_binding()
	_test_production_s03_replay_and_unrelated_edge_preservation()
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

func _test_production_h02_s03_phase_d_binding() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _production_defs()
	var stress_rules: Dictionary = defs["stress_field_rules"]
	var original_rules: Dictionary = stress_rules.duplicate(true)
	var blocked: Dictionary = runner.simulate(_production_record(true), 1, defs)
	var open: Dictionary = runner.simulate(_production_record(false), 1, _production_defs())
	_expect_true(bool(blocked.get("ok", false)), "production H02 accepts a committed S03 Baffle bound to an authored hold boundary")
	_expect_true(bool(open.get("ok", false)), "production H02 open-boundary comparison resolves")
	if not bool(blocked.get("ok", false)) or not bool(open.get("ok", false)):
		return
	var blocked_snapshot: Dictionary = blocked["end_tick_snapshots"][0]
	var open_snapshot: Dictionary = open["end_tick_snapshots"][0]
	_expect_equal(blocked_snapshot["stress_field_by_cell"], {"0,0": 4, "1,0": 0, "2,0": 1}, "S03 blocks only the transfer crossing its authored fixture boundary")
	_expect_equal(open_snapshot["stress_field_by_cell"], {"0,0": 2, "1,0": 2, "2,0": 1}, "without S03 the same H02 field uses all authored transfer edges")
	_expect_equal(int(blocked_snapshot["stress_field_by_cell"]["2,0"]), 1, "unrelated Phase-D transfer remains unchanged behind the Baffle integration")
	var events: Array = blocked_snapshot["s03_stress_transfer_events"]
	_expect_equal(events.size(), 1, "production S03 emits one blocked-transfer event for one crossed edge")
	_expect_equal(String(events[0]["kind"]), "S03_STRESS_TRANSFER_BLOCKED", "production evidence uses canonical S03 event kind")
	_expect_equal(String(events[0]["support_instance_id"]), "support-s03-a", "blocked-transfer evidence retains committed support identity")
	_expect_equal(int(events[0]["tick"]), 1, "blocked-transfer evidence is tick-addressable")
	_expect_equal(int(events[0]["amount"]), 2, "production S03 evidence retains the exact upstream transfer amount")
	_expect_equal(defs["stress_field_rules"], original_rules, "production S03 never mutates authored upstream stress-field rules")
	_expect_equal(blocked["s03_support_boundaries"], [_boundary("support-s03-a", "0,0", "1,0")], "production result retains exact committed support-to-authored-boundary binding")
	_expect_true(String(blocked["tick_checksums"][0]) != String(open["tick_checksums"][0]), "committed S03 boundary/effect is checksum-visible")

func _test_production_s03_replay_and_unrelated_edge_preservation() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_production_record(true), 1, _production_defs())
	var replay: Dictionary = runner.simulate(_production_record(true), 1, _production_defs())
	_expect_equal(first, replay, "production S03 H02 integration replay is deterministic")
	if not bool(first.get("ok", false)):
		return
	var events: Array = first["s03_stress_transfer_events"]
	_expect_equal(events.size(), 1, "unrelated open edge never creates a false S03 block event")
	_expect_equal(String(events[0]["from"]), "0,0", "only crossing edge is reported as blocked")
	_expect_equal(String(events[0]["to"]), "1,0", "blocked edge endpoint is deterministic")

func _production_record(with_baffle: bool) -> Dictionary:
	var supports: Array = []
	if with_baffle:
		supports.append({
			"instance_id": "support-s03-a",
			"support_id": "support-baffle",
			"fixture_id": "fixture-baffle-a",
		})
	return {
		"run_id": "s03-production-run",
		"rules_version": "rules-r1",
		"content_version": "s03-production-1",
		"canonical_committed_input": {
			"route_id": "route-s03",
			"seed": 103,
			"placements": [{"instance_id": "cargo-a", "anchor": [2, 0], "orientation": 0}],
			"supports": supports,
			"brownout_priority": [],
		},
	}

func _production_defs() -> Dictionary:
	return {
		"route_profile": {
			"id": "route-s03",
			"tick_count": 1,
			"events": [
				{"tick": 1, "duration_ticks": 1, "hazard_id": "h02-left", "authored_order": 0},
				{"tick": 1, "duration_ticks": 1, "hazard_id": "h02-middle", "authored_order": 1},
			],
		},
		"hold_definition": {
			"dimensions": [3, 1],
			"blocked_cells": [],
			"power_capacity": 0,
			"authored_support_boundaries": [
				{"fixture_id": "fixture-baffle-a", "a": "0,0", "b": "1,0"},
			],
		},
		"hazards_by_id": {
			"h02-left": {"family": "H02", "stress_field_delta": 4, "target_cells": ["0,0"]},
			"h02-middle": {"family": "H02", "stress_field_delta": 1, "target_cells": ["1,0"]},
		},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"stress_field_rules": {
			"stress_field_min": 0,
			"stress_field_max": 20,
			"transfer_edges": [
				{"from": "0,0", "to": "1,0", "amount": 2},
				{"from": "1,0", "to": "2,0", "amount": 1},
			],
			"decay_by_cell": {},
		},
		"support_definitions_by_id": {
			"support-baffle": {"family": "S03"},
		},
	}

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
