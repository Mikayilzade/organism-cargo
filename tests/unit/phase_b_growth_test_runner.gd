extends SceneTree

const ResolverScript := preload("res://src/sim/phase_b_growth_resolver.gd")
const TransitSliceRunnerScript := preload("res://src/sim/transit_slice_runner.gd")

func _init() -> void:
	_test_legal_growth_changes_body_stage()
	_test_unchanged_blockage_fires_one_root()
	_test_relevant_trigger_change_starts_new_episode()
	_test_transit_runner_invokes_growth_in_phase_b()
	_test_transit_blocked_growth_replay_is_stable()
	_test_transit_t08_qualification_queues_next_tick_growth()
	_test_transit_t08_qualification_state_is_checksum_authoritative()
	print("phase_b_growth_test_runner: PASS")
	quit(0)

func _test_legal_growth_changes_body_stage() -> void:
	var resolver: PhaseBGrowthResolver = ResolverScript.new()
	var result: Dictionary = resolver.resolve_tick(
		[_organism("grower", [0, 0])],
		PackedStringArray(["0,0", "1,0"]),
		[_request("grower", "qualified")]
	)
	_assert_true(bool(result["ok"]), "legal Phase-B growth resolves")
	var organisms: Array = result["organisms"]
	var grower: Dictionary = organisms[0]
	_assert_equal(String(grower["body_stage"]), "MATURE", "legal growth advances body stage")
	_assert_equal(grower["occupied_cells"], ["0,0", "1,0"], "legal growth installs declared orientation footprint")
	_assert_false(bool(grower["growth_blocked"]), "legal growth clears blocked condition")

func _test_unchanged_blockage_fires_one_root() -> void:
	var resolver: PhaseBGrowthResolver = ResolverScript.new()
	var organisms: Array = [_organism("grower", [0, 0]), _static_organism("blocker", [1, 0])]
	var first: Dictionary = resolver.resolve_tick(
		organisms,
		PackedStringArray(["0,0", "1,0"]),
		[_request("grower", "qualified")]
	)
	_assert_true(bool(first["ok"]), "blocked Phase-B growth resolves")
	var first_events: Array = first["growth_events"]
	_assert_equal(first_events.size(), 1, "first blocked episode emits one causal root")
	var second: Dictionary = resolver.resolve_tick(
		first["organisms"],
		PackedStringArray(["0,0", "1,0"]),
		[_request("grower", "qualified")]
	)
	_assert_true(bool(second["ok"]), "unchanged blocked Phase-B growth resolves")
	var second_events: Array = second["growth_events"]
	_assert_equal(second_events.size(), 0, "unchanged obstruction emits no repeated causal root")
	var second_organisms: Array = second["organisms"]
	var grower: Dictionary = _organism_by_id(second_organisms, "grower")
	_assert_equal(String(grower["body_stage"]), "JUVENILE", "blocked growth does not mutate body stage")
	_assert_true(bool(grower["growth_blocked"]), "blocked condition remains visible")

func _test_relevant_trigger_change_starts_new_episode() -> void:
	var resolver: PhaseBGrowthResolver = ResolverScript.new()
	var organisms: Array = [_organism("grower", [0, 0]), _static_organism("blocker", [1, 0])]
	var first: Dictionary = resolver.resolve_tick(
		organisms,
		PackedStringArray(["0,0", "1,0"]),
		[_request("grower", "qualified-a")]
	)
	var second: Dictionary = resolver.resolve_tick(
		first["organisms"],
		PackedStringArray(["0,0", "1,0"]),
		[_request("grower", "qualified-b")]
	)
	var events: Array = second["growth_events"]
	_assert_equal(events.size(), 1, "growth-trigger condition change starts a new blocked episode")
	var event: Dictionary = events[0]
	_assert_equal(int(event["episode_index"]), 2, "new relevant condition advances blocked-growth episode identity")

func _test_transit_runner_invokes_growth_in_phase_b() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var result: Dictionary = runner.simulate(_run_record(_committed_input(false)), 2, _simulation_defs(false))
	_assert_true(bool(result["ok"]), "TransitSliceRunner accepts qualified growth request")
	var snapshots: Array = result["end_tick_snapshots"]
	var tick_one: Dictionary = snapshots[0]
	var runtime: Array = tick_one["organism_runtime"]
	var grower: Dictionary = _organism_by_id(runtime, "grower")
	_assert_equal(String(grower["body_stage"]), "MATURE", "TransitSliceRunner resolves growth in Phase B before later phases")
	_assert_equal(grower["occupied_cells"], ["0,0", "1,0"], "transit runtime carries declared mature footprint")
	var events: Array = result["growth_events"]
	_assert_equal(events.size(), 0, "legal growth creates no blocked-growth causal event")

func _test_transit_blocked_growth_replay_is_stable() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var first: Dictionary = runner.simulate(_run_record(_committed_input(true)), 2, _simulation_defs(true))
	var second: Dictionary = runner.simulate(_run_record(_committed_input(true)), 2, _simulation_defs(true))
	_assert_true(bool(first["ok"]) and bool(second["ok"]), "blocked-growth transit replay variants execute")
	var events: Array = first["growth_events"]
	_assert_equal(events.size(), 1, "same obstruction across two ticks creates one blocked-growth root")
	_assert_equal(first["tick_checksums"], second["tick_checksums"], "blocked-growth body/condition state participates in deterministic tick replay")

func _test_transit_t08_qualification_queues_next_tick_growth() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var result: Dictionary = runner.simulate(
		_run_record(_committed_input(false)),
		3,
		_t08_simulation_defs({"1": {"grower": true}, "2": {"grower": true}, "3": {"grower": true}}, 3, 2)
	)
	_assert_true(bool(result["ok"]), "TransitSliceRunner evaluates T08 qualification inside Phase G")
	var snapshots: Array = result["end_tick_snapshots"]
	var tick_two: Dictionary = snapshots[1]
	var queued: Array = tick_two["t08_queued_growth_requests"]
	_assert_equal(queued.size(), 1, "exact T08 duration queues one next-tick request during Phase G")
	var queued_request: Dictionary = queued[0]
	_assert_equal(int(queued_request["apply_tick"]), 3, "Phase G schedules the qualified transition for next-tick Phase B")
	var tick_three: Dictionary = snapshots[2]
	var runtime: Array = tick_three["organism_runtime"]
	var grower: Dictionary = _organism_by_id(runtime, "grower")
	_assert_equal(String(grower["body_stage"]), "MATURE", "queued T08 request mutates the footprint only in the following Phase B")
	_assert_equal(grower["occupied_cells"], ["0,0", "1,0"], "next-tick Phase B installs the declared mature footprint")

func _test_transit_t08_qualification_state_is_checksum_authoritative() -> void:
	var runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var uninterrupted: Dictionary = runner.simulate(
		_run_record(_committed_input(false)),
		2,
		_t08_simulation_defs({"1": {"grower": true}, "2": {"grower": true}}, 2, 3)
	)
	var interrupted: Dictionary = runner.simulate(
		_run_record(_committed_input(false)),
		2,
		_t08_simulation_defs({"1": {"grower": true}, "2": {"grower": false}}, 2, 3)
	)
	_assert_true(bool(uninterrupted["ok"]) and bool(interrupted["ok"]), "T08 checksum variants execute")
	var uninterrupted_checksums: PackedStringArray = uninterrupted["tick_checksums"]
	var interrupted_checksums: PackedStringArray = interrupted["tick_checksums"]
	_assert_true(uninterrupted_checksums[1] != interrupted_checksums[1], "qualification accumulator state participates in authoritative tick checksums")
	var uninterrupted_snapshots: Array = uninterrupted["end_tick_snapshots"]
	var interrupted_snapshots: Array = interrupted["end_tick_snapshots"]
	var uninterrupted_tick_two: Dictionary = uninterrupted_snapshots[1]
	var interrupted_tick_two: Dictionary = interrupted_snapshots[1]
	_assert_true(uninterrupted_tick_two["t08_qualification_state"] != interrupted_tick_two["t08_qualification_state"], "end-of-tick replay evidence exposes T08 qualification state")

func _run_record(committed_input: Dictionary) -> Dictionary:
	return {
		"run_id": "growth-run",
		"rules_version": "rules-r1",
		"content_version": "growth-test-1",
		"canonical_committed_input": committed_input,
	}

func _committed_input(with_blocker: bool) -> Dictionary:
	var placements: Array = [
		{"instance_id": "grower", "anchor": [0, 0], "orientation": 0},
	]
	if with_blocker:
		placements.append({"instance_id": "blocker", "anchor": [1, 0], "orientation": 0})
	return {
		"route_id": "route-growth",
		"seed": 41,
		"placements": placements,
		"supports": [],
	}

func _simulation_defs(with_blocker: bool) -> Dictionary:
	var definitions: Dictionary = {
		"grower": _runtime_definition(true),
	}
	if with_blocker:
		definitions["blocker"] = _runtime_definition(false)
	return {
		"route_profile": {"id": "route-growth", "tick_count": 2, "events": []},
		"hold_definition": {"dimensions": [2, 1], "blocked_cells": []},
		"hazards_by_id": {},
		"organism_definitions": definitions,
		"growth_requests_by_tick": {
			"1": [_request("grower", "qualified")],
			"2": [_request("grower", "qualified")],
		},
	}

func _t08_simulation_defs(qualification_by_tick: Dictionary, tick_count: int, required_ticks: int) -> Dictionary:
	return {
		"route_profile": {"id": "route-growth", "tick_count": tick_count, "events": []},
		"hold_definition": {"dimensions": [2, 1], "blocked_cells": []},
		"hazards_by_id": {},
		"organism_definitions": {"grower": _runtime_definition(true)},
		"growth_requests_by_tick": {},
		"t08_trigger_definitions": [{
			"instance_id": "grower",
			"trigger_id": "heat-growth",
			"required_qualifying_ticks": required_ticks,
			"next_body_stage": "MATURE",
			"material_parent_ids": ["condition:grower"],
		}],
		"t08_qualification_by_tick": qualification_by_tick,
	}

func _runtime_definition(can_grow: bool) -> Dictionary:
	var stages: Dictionary = {
		"JUVENILE": {"footprints": {"0": [[0, 0]]}},
	}
	if can_grow:
		stages["MATURE"] = {"footprints": {"0": [[0, 0], [1, 0]]}}
	else:
		stages["STATIC"] = {"footprints": {"0": [[0, 0]]}}
	return {
		"initial_stress": 0,
		"initial_state": "CALM",
		"stress_profile": {
			"heat_safe_max": 99,
			"stress_per_heat_unit": 0,
			"stress_min": 0,
			"stress_max": 20,
			"agitated_enter": 5,
			"agitated_exit": 3,
			"panic_enter": 10,
			"panic_exit": 7,
		},
		"initial_body_stage": "JUVENILE" if can_grow else "STATIC",
		"body_stages": stages,
	}

func _organism(instance_id: String, anchor: Array) -> Dictionary:
	return {
		"instance_id": instance_id,
		"anchor": anchor,
		"orientation": 0,
		"body_stage": "JUVENILE",
		"body_stages": {
			"JUVENILE": {"footprints": {"0": [[0, 0]]}},
			"MATURE": {"footprints": {"0": [[0, 0], [1, 0]]}},
		},
		"occupied_cells": ["%d,%d" % [int(anchor[0]), int(anchor[1])]],
		"growth_episode_state": {},
		"growth_blocked": false,
	}

func _static_organism(instance_id: String, anchor: Array) -> Dictionary:
	return {
		"instance_id": instance_id,
		"anchor": anchor,
		"orientation": 0,
		"body_stage": "STATIC",
		"body_stages": {"STATIC": {"footprints": {"0": [[0, 0]]}}},
		"occupied_cells": ["%d,%d" % [int(anchor[0]), int(anchor[1])]],
		"growth_episode_state": {},
		"growth_blocked": false,
	}

func _request(instance_id: String, trigger: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"next_body_stage": "MATURE",
		"growth_trigger_condition": trigger,
		"material_parent_ids": ["growth-trigger:%s" % instance_id],
	}

func _organism_by_id(organisms: Array, instance_id: String) -> Dictionary:
	for raw_organism: Variant in organisms:
		if raw_organism is Dictionary:
			var organism: Dictionary = raw_organism
			if String(organism.get("instance_id", "")) == instance_id:
				return organism
	return {}

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
	push_error("phase_b_growth_test_runner: %s" % message)
	quit(1)
