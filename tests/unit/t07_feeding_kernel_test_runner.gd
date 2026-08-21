extends SceneTree

const T07FeedingKernelScript := preload("res://src/sim/t07_feeding_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_compatible_nearest_then_id_allocation_and_conservation()
	_test_range_and_tag_mismatch_block_feeding()
	_test_consumer_intake_cap_and_satiety_headroom()
	_test_sleep_gate_disables_declared_producer_output_only()
	_test_definition_order_does_not_change_result()
	_test_production_t07_phase_e_f_persists_satiety_and_causal_evidence()
	_test_production_t07_replay_checksum_and_t06_coexistence_fail_closed()
	if failures == 0:
		print("t07_feeding_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("t07_feeding_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_compatible_nearest_then_id_allocation_and_conservation() -> void:
	var kernel: T07FeedingKernel = T07FeedingKernelScript.new()
	var result: Dictionary = kernel.resolve_tick(3, _organisms(), _producers(), _consumers())
	_expect_true(bool(result.get("ok", false)), "compatible T07 feeding resolves")
	if not bool(result.get("ok", false)):
		return
	var allocations: Array = result["allocations"]
	_expect_equal(allocations.size(), 2, "producer output is conserved and allocates exactly two units")
	_expect_equal(String(allocations[0]["consumer_id"]), "grazer-a", "nearest tied consumer resolves by lowest instance_id")
	_expect_equal(String(allocations[1]["consumer_id"]), "grazer-b", "second indivisible food unit round-robins to next eligible consumer")
	var organisms: Array = result["organisms"]
	var by_id: Dictionary = _by_id(organisms)
	_expect_equal(int(by_id["grazer-a"]["satiety"]), 5, "first grazer gains one satiety")
	_expect_equal(int(by_id["grazer-b"]["satiety"]), 5, "second grazer gains one satiety")
	var events: Array = result["events"]
	_expect_equal(events.size(), 4, "two allocation events and two Phase-F satiety events are emitted")
	_expect_equal(String(events[0]["phase"]), "E", "food allocation is Phase E")
	_expect_equal(String(events[2]["phase"]), "F", "satiety commit is Phase F")
	var parents: PackedStringArray = events[2]["parent_event_ids"]
	_expect_equal(parents.size(), 1, "satiety event retains exact allocation parent")

func _test_range_and_tag_mismatch_block_feeding() -> void:
	var kernel: T07FeedingKernel = T07FeedingKernelScript.new()
	var organisms: Array = _organisms()
	var consumers: Array = _consumers()
	var consumer_b: Dictionary = consumers[1]
	consumer_b["accepted_food_tags"] = ["mineral"]
	consumers[1] = consumer_b
	var far_runtime: Dictionary = organisms[2]
	far_runtime["occupied_cells"] = ["4,0"]
	organisms[2] = far_runtime
	var result: Dictionary = kernel.resolve_tick(1, organisms, _producers(), consumers)
	_expect_true(bool(result.get("ok", false)), "ineligible feeding case resolves without failure")
	if not bool(result.get("ok", false)):
		return
	var allocations: Array = result["allocations"]
	_expect_equal(allocations.size(), 2, "both conserved units may flow to the only compatible in-range consumer")
	_expect_equal(String(allocations[0]["consumer_id"]), "grazer-a", "range and compatibility gate the first allocation")
	_expect_equal(String(allocations[1]["consumer_id"]), "grazer-a", "ineligible consumers do not consume the producer's remaining unit")

func _test_consumer_intake_cap_and_satiety_headroom() -> void:
	var kernel: T07FeedingKernel = T07FeedingKernelScript.new()
	var organisms: Array = _organisms()
	var grazer_a: Dictionary = organisms[1]
	grazer_a["satiety"] = 6
	organisms[1] = grazer_a
	var consumers: Array = _consumers()
	var consumer_a: Dictionary = consumers[0]
	consumer_a["intake_cap"] = 3
	consumer_a["satiety_max"] = 7
	consumers[0] = consumer_a
	var producers: Array = _producers()
	var producer: Dictionary = producers[0]
	producer["output_units"] = 4
	producers[0] = producer
	var result: Dictionary = kernel.resolve_tick(2, organisms, producers, consumers)
	_expect_true(bool(result.get("ok", false)), "headroom-limited feeding resolves")
	if not bool(result.get("ok", false)):
		return
	var by_id: Dictionary = _by_id(result["organisms"])
	_expect_equal(int(by_id["grazer-a"]["satiety"]), 7, "satiety headroom caps consumer even above authored intake cap")
	_expect_true(int(by_id["grazer-b"]["satiety"]) <= 7, "second consumer also respects satiety maximum")

func _test_sleep_gate_disables_declared_producer_output_only() -> void:
	var kernel: T07FeedingKernel = T07FeedingKernelScript.new()
	var organisms: Array = _organisms()
	var moss: Dictionary = organisms[0]
	moss["primary_state"] = "ASLEEP"
	organisms[0] = moss
	var producers: Array = _producers()
	var producer: Dictionary = producers[0]
	producer["sleep_gated"] = true
	producers[0] = producer
	var result: Dictionary = kernel.resolve_tick(5, organisms, producers, _consumers())
	_expect_true(bool(result.get("ok", false)), "sleep-gated producer case resolves")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(result["allocations"], [], "explicit sleep gate removes T07 producer output")
	var by_id: Dictionary = _by_id(result["organisms"])
	_expect_equal(int(by_id["grazer-a"]["satiety"]), 4, "sleep gating does not invent unrelated satiety changes")

func _test_definition_order_does_not_change_result() -> void:
	var kernel: T07FeedingKernel = T07FeedingKernelScript.new()
	var producers: Array = _producers()
	var consumers: Array = _consumers()
	var reversed_consumers: Array = []
	var second_consumer: Dictionary = consumers[1]
	var first_consumer: Dictionary = consumers[0]
	reversed_consumers.append(second_consumer.duplicate(true))
	reversed_consumers.append(first_consumer.duplicate(true))
	var first: Dictionary = kernel.resolve_tick(7, _organisms(), producers, consumers)
	var second: Dictionary = kernel.resolve_tick(7, _organisms(), producers, reversed_consumers)
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "both replay orders resolve")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		return
	_expect_equal(first["allocations"], second["allocations"], "allocation is independent of authored definition array order")
	_expect_equal(first["events"], second["events"], "causal evidence is deterministic across definition order")

func _test_production_t07_phase_e_f_persists_satiety_and_causal_evidence() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_production_record(), 2, _production_defs(false))
	_expect_true(bool(result.get("ok", false)), "production T07 transit resolves")
	if not bool(result.get("ok", false)):
		return
	var snapshots: Array = result["end_tick_snapshots"]
	_expect_equal(snapshots.size(), 2, "production T07 keeps one snapshot per tick")
	var tick_one_runtime: Dictionary = _by_id(snapshots[0]["organism_runtime"])
	var tick_two_runtime: Dictionary = _by_id(snapshots[1]["organism_runtime"])
	_expect_equal(int(tick_one_runtime["grazer"]["satiety"]), 5, "Phase-F T07 gain commits on tick one")
	_expect_equal(int(tick_two_runtime["grazer"]["satiety"]), 6, "T07 satiety persists into the next production tick")
	var tick_one_events: Array = snapshots[0]["t07_events"]
	_expect_equal(tick_one_events.size(), 2, "production tick records one allocation and one satiety event")
	_expect_equal(String(tick_one_events[0]["phase"]), "E", "production allocation evidence remains Phase E")
	_expect_equal(String(tick_one_events[1]["phase"]), "F", "production satiety evidence remains Phase F")
	var parents: PackedStringArray = tick_one_events[1]["parent_event_ids"]
	_expect_equal(parents, PackedStringArray([String(tick_one_events[0]["event_id"])]), "production satiety event retains the allocation parent")
	var allocations: Array = result["t07_allocations"]
	_expect_equal(allocations.size(), 2, "finite producer output allocates one unit on each tick")
	_expect_equal(int(allocations[0]["tick"]), 1, "aggregate allocation evidence includes tick identity")
	var final_runtime: Dictionary = _by_id(result["final_organism_runtime"])
	_expect_equal(int(final_runtime["grazer"]["satiety"]), 6, "production final runtime carries T07 satiety authority")

func _test_production_t07_replay_checksum_and_t06_coexistence_fail_closed() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_production_record(), 2, _production_defs(false))
	var second: Dictionary = runner.simulate(_production_record(), 2, _production_defs(false))
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "production T07 deterministic replay resolves twice")
	if bool(first.get("ok", false)) and bool(second.get("ok", false)):
		_expect_equal(first["tick_checksums"], second["tick_checksums"], "production T07 replay checksums are deterministic")
		var changed_defs: Dictionary = _production_defs(false)
		var changed_consumers: Array = changed_defs["t07_consumer_definitions"]
		var changed_consumer: Dictionary = changed_consumers[0]
		changed_consumer["benefit_per_unit"] = 2
		changed_consumers[0] = changed_consumer
		changed_defs["t07_consumer_definitions"] = changed_consumers
		var changed: Dictionary = runner.simulate(_production_record(), 2, changed_defs)
		_expect_true(bool(changed.get("ok", false)), "changed authored T07 benefit still resolves")
		if bool(changed.get("ok", false)):
			_expect_true(String(first["tick_checksums"][0]) != String(changed["tick_checksums"][0]), "T07 satiety/evidence is checksum-visible")

	var coexistence: Dictionary = runner.simulate(_production_record(), 2, _production_defs(true))
	_expect_true(not bool(coexistence.get("ok", false)), "T06 plus T07 currently fails closed instead of using post-F headroom")
	_expect_equal(String(coexistence.get("error", "")), "t07_t06_shared_phase_f_composition_not_implemented", "cross-trait Phase-E/F composition exposes the explicit recoverable blocker")

func _organisms() -> Array:
	return [
		{"instance_id": "moss", "occupied_cells": ["0,0"], "primary_state": "CALM", "body_stage": "MATURE", "satiety": 6},
		{"instance_id": "grazer-a", "occupied_cells": ["1,0"], "primary_state": "CALM", "body_stage": "JUVENILE", "satiety": 4},
		{"instance_id": "grazer-b", "occupied_cells": ["0,1"], "primary_state": "CALM", "body_stage": "JUVENILE", "satiety": 4},
	]

func _producers() -> Array:
	return [{
		"instance_id": "moss",
		"output_units": 2,
		"food_tags": ["moss_food"],
		"active_primary_states": ["CALM", "AGITATED"],
		"active_body_stages": ["MATURE"],
		"sleep_gated": true,
	}]

func _consumers() -> Array:
	return [
		{
			"instance_id": "grazer-a",
			"range": 1,
			"intake_cap": 2,
			"benefit_per_unit": 1,
			"satiety_max": 7,
			"accepted_food_tags": ["moss_food"],
			"active_primary_states": ["CALM", "AGITATED", "PANICKED"],
			"active_body_stages": ["JUVENILE"],
			"sleep_gated": false,
		},
		{
			"instance_id": "grazer-b",
			"range": 1,
			"intake_cap": 2,
			"benefit_per_unit": 1,
			"satiety_max": 7,
			"accepted_food_tags": ["moss_food"],
			"active_primary_states": ["CALM", "AGITATED", "PANICKED"],
			"active_body_stages": ["JUVENILE"],
			"sleep_gated": false,
		},
	]

func _production_record() -> Dictionary:
	return {
		"run_id": "t07-production-run",
		"rules_version": "rules-r1",
		"content_version": "t07-production-1",
		"canonical_committed_input": {
			"route_id": "route-t07-production",
			"seed": 73,
			"placements": [
				{"instance_id": "moss", "anchor": [0, 0], "orientation": 0},
				{"instance_id": "grazer", "anchor": [1, 0], "orientation": 0},
			],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _production_defs(with_t06: bool) -> Dictionary:
	var defs: Dictionary = {
		"route_profile": {
			"id": "route-t07-production",
			"tick_count": 2,
			"events": [],
		},
		"hold_definition": {
			"dimensions": [2, 1],
			"blocked_cells": [],
			"power_capacity": 0,
		},
		"hazards_by_id": {},
		"support_definitions_by_id": {},
		"organism_definitions": {
			"moss": {
				"initial_stress": 0,
				"initial_state": "CALM",
				"initial_body_stage": "MATURE",
				"stress_profile": _stress_profile(),
				"body_stages": {"MATURE": {"footprints": {"0": [[0, 0]]}}},
			},
			"grazer": {
				"initial_stress": 0,
				"initial_state": "CALM",
				"initial_body_stage": "JUVENILE",
				"initial_satiety": 4,
				"stress_profile": _stress_profile(),
				"body_stages": {"JUVENILE": {"footprints": {"0": [[0, 0]]}}},
			},
		},
		"t07_producer_definitions": [{
			"instance_id": "moss",
			"output_units": 1,
			"food_tags": ["moss_food"],
			"active_primary_states": ["CALM", "AGITATED"],
			"active_body_stages": ["MATURE"],
			"sleep_gated": true,
		}],
		"t07_consumer_definitions": [{
			"instance_id": "grazer",
			"range": 1,
			"intake_cap": 1,
			"benefit_per_unit": 1,
			"satiety_max": 7,
			"accepted_food_tags": ["moss_food"],
			"active_primary_states": ["CALM", "AGITATED", "PANICKED"],
			"active_body_stages": ["JUVENILE"],
			"sleep_gated": false,
		}],
	}
	if with_t06:
		defs["contamination_rules"] = {
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		}
		defs["t06_definitions"] = [{
			"instance_id": "grazer",
			"consume_capacity": 1,
			"satiety_per_unit": 1,
			"satiety_max": 7,
			"active_primary_states": ["CALM", "AGITATED", "PANICKED"],
			"active_body_stages": ["JUVENILE"],
			"sleep_gated": false,
		}]
	return defs

func _stress_profile() -> Dictionary:
	return {
		"heat_safe_max": 99,
		"stress_per_heat_unit": 1,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 6,
		"agitated_exit": 3,
		"panic_enter": 11,
		"panic_exit": 7,
	}

func _by_id(organisms: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_runtime: Variant in organisms:
		var runtime: Dictionary = raw_runtime
		result[String(runtime["instance_id"])] = runtime
	return result

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
