extends SceneTree

const QualifierScript := preload("res://src/sim/t08_growth_qualifier.gd")
const PhaseBGrowthResolverScript := preload("res://src/sim/phase_b_growth_resolver.gd")

func _init() -> void:
	_test_exact_qualifying_duration_queues_next_tick()
	_test_uninterrupted_qualification_does_not_repeat_queue()
	_test_dequalification_resets_duration_and_changes_trigger_epoch()
	_test_definition_order_is_deterministic()
	_test_queued_request_composes_with_phase_b_growth()
	_test_invalid_duration_fails_closed()
	print("t08_growth_qualifier_test_runner: PASS")
	quit(0)

func _test_exact_qualifying_duration_queues_next_tick() -> void:
	var qualifier: T08GrowthQualifier = QualifierScript.new()
	var first: Dictionary = qualifier.evaluate_tick(1, [_definition("grower", 2)], {"grower": true})
	_assert_true(bool(first["ok"]), "first qualifying tick resolves")
	var first_requests: Array = first["queued_requests"]
	_assert_equal(first_requests.size(), 0, "T08 does not queue before required duration")
	var second: Dictionary = qualifier.evaluate_tick(2, [_definition("grower", 2)], {"grower": true}, first["state"])
	_assert_true(bool(second["ok"]), "second qualifying tick resolves")
	var second_requests: Array = second["queued_requests"]
	_assert_equal(second_requests.size(), 1, "exact required duration queues one growth request")
	var request: Dictionary = second_requests[0]
	_assert_equal(int(request["apply_tick"]), 3, "Phase-G qualification queues the transition for next-tick Phase B")
	_assert_equal(String(request["next_body_stage"]), "MATURE", "queued request names the declared next body stage")

func _test_uninterrupted_qualification_does_not_repeat_queue() -> void:
	var qualifier: T08GrowthQualifier = QualifierScript.new()
	var first: Dictionary = qualifier.evaluate_tick(1, [_definition("grower", 1)], {"grower": true})
	var second: Dictionary = qualifier.evaluate_tick(2, [_definition("grower", 1)], {"grower": true}, first["state"])
	var first_requests: Array = first["queued_requests"]
	var second_requests: Array = second["queued_requests"]
	_assert_equal(first_requests.size(), 1, "first satisfied window queues once")
	_assert_equal(second_requests.size(), 0, "unchanged qualifying window does not repeatedly queue the same stage")

func _test_dequalification_resets_duration_and_changes_trigger_epoch() -> void:
	var qualifier: T08GrowthQualifier = QualifierScript.new()
	var first: Dictionary = qualifier.evaluate_tick(1, [_definition("grower", 2)], {"grower": true})
	var second: Dictionary = qualifier.evaluate_tick(2, [_definition("grower", 2)], {"grower": true}, first["state"])
	var second_requests: Array = second["queued_requests"]
	var first_request: Dictionary = second_requests[0]
	var off: Dictionary = qualifier.evaluate_tick(3, [_definition("grower", 2)], {"grower": false}, second["state"])
	var again_one: Dictionary = qualifier.evaluate_tick(4, [_definition("grower", 2)], {"grower": true}, off["state"])
	var again_two: Dictionary = qualifier.evaluate_tick(5, [_definition("grower", 2)], {"grower": true}, again_one["state"])
	var again_one_requests: Array = again_one["queued_requests"]
	var again_two_requests: Array = again_two["queued_requests"]
	_assert_equal(again_one_requests.size(), 0, "dequalification resets consecutive qualifying duration")
	_assert_equal(again_two_requests.size(), 1, "a newly qualified window can queue again")
	var second_request: Dictionary = again_two_requests[0]
	_assert_true(String(first_request["growth_trigger_condition"]) != String(second_request["growth_trigger_condition"]), "new qualifying window changes trigger-condition identity for blocked-growth episode semantics")

func _test_definition_order_is_deterministic() -> void:
	var qualifier: T08GrowthQualifier = QualifierScript.new()
	var left: Dictionary = qualifier.evaluate_tick(
		1,
		[_definition("zeta", 1), _definition("alpha", 1)],
		{"zeta": true, "alpha": true}
	)
	var right: Dictionary = qualifier.evaluate_tick(
		1,
		[_definition("alpha", 1), _definition("zeta", 1)],
		{"alpha": true, "zeta": true}
	)
	_assert_true(bool(left["ok"]) and bool(right["ok"]), "ordering variants execute")
	_assert_equal(left["queued_requests"], right["queued_requests"], "definition insertion order cannot change authoritative queue order")

func _test_queued_request_composes_with_phase_b_growth() -> void:
	var qualifier: T08GrowthQualifier = QualifierScript.new()
	var qualified: Dictionary = qualifier.evaluate_tick(4, [_definition("grower", 1)], {"grower": true})
	var requests: Array = qualified["queued_requests"]
	_assert_equal(requests.size(), 1, "T08 creates one request for Phase B composition")
	var resolver: PhaseBGrowthResolver = PhaseBGrowthResolverScript.new()
	var growth: Dictionary = resolver.resolve_tick(
		[_organism("grower")],
		PackedStringArray(["0,0", "1,0"]),
		requests
	)
	_assert_true(bool(growth["ok"]), "queued T08 request is accepted by Phase-B footprint authority")
	var organisms: Array = growth["organisms"]
	var grower: Dictionary = organisms[0]
	_assert_equal(String(grower["body_stage"]), "MATURE", "Phase B installs the declared next stage")
	_assert_equal(grower["occupied_cells"], ["0,0", "1,0"], "Phase B remains sole footprint mutation owner")

func _test_invalid_duration_fails_closed() -> void:
	var qualifier: T08GrowthQualifier = QualifierScript.new()
	var result: Dictionary = qualifier.evaluate_tick(1, [_definition("grower", 0)], {"grower": true})
	_assert_false(bool(result["ok"]), "non-positive T08 duration is rejected")
	_assert_equal(String(result["error"]), "invalid_t08_definition", "invalid duration fails with stable error")

func _definition(instance_id: String, required_ticks: int) -> Dictionary:
	return {
		"instance_id": instance_id,
		"trigger_id": "heat-growth",
		"required_qualifying_ticks": required_ticks,
		"next_body_stage": "MATURE",
		"material_parent_ids": ["condition:%s" % instance_id],
	}

func _organism(instance_id: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"anchor": [0, 0],
		"orientation": 0,
		"body_stage": "JUVENILE",
		"body_stages": {
			"JUVENILE": {"footprints": {"0": [[0, 0]]}},
			"MATURE": {"footprints": {"0": [[0, 0], [1, 0]]}},
		},
		"occupied_cells": ["0,0"],
		"growth_episode_state": {},
		"growth_blocked": false,
	}

func _assert_true(value: bool, message: String) -> void:
	if not value:
		_fail(message)

func _assert_false(value: bool, message: String) -> void:
	if value:
		_fail(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])

func _fail(message: String) -> void:
	push_error("t08_growth_qualifier_test_runner: %s" % message)
	quit(1)
