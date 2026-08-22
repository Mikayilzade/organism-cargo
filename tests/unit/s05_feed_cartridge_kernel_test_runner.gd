extends SceneTree

const S05FeedCartridgeKernelScript := preload("res://src/sim/s05_feed_cartridge_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_prepare_finite_reserve_and_spatial_identity()
	_test_reserve_is_conserved_across_ticks()
	_test_overallocation_is_rejected_without_mutation()
	_test_allocation_order_is_canonical_and_replay_safe()
	_test_missing_spatial_placement_is_rejected()
	_test_production_s05_t07_composition_and_depletion()
	if failures == 0:
		print("s05_feed_cartridge_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("s05_feed_cartridge_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_prepare_finite_reserve_and_spatial_identity() -> void:
	var kernel: S05FeedCartridgeKernel = S05FeedCartridgeKernelScript.new()
	var result: Dictionary = kernel.prepare_support_states(
		[
			{"instance_id": "feed-b", "support_id": "feed", "fixture_id": "fixture-b"},
			{"instance_id": "cooler-a", "support_id": "cooler", "fixture_id": "fixture-a"},
			{"instance_id": "feed-a", "support_id": "feed", "anchor": [1, 2]},
		],
		{
			"feed": {"family": "S05", "capacity": 4},
			"cooler": {"family": "S01", "capacity": 2},
		}
	)
	_expect_true(bool(result.get("ok", false)), "S05 finite reserve state prepares from committed supports")
	if not bool(result.get("ok", false)):
		return
	var states: Array = result["support_states"]
	_expect_equal(states.size(), 2, "only S05 supports become reserve states")
	_expect_equal(String(states[0]["instance_id"]), "feed-a", "S05 states are stable instance-id ordered")
	_expect_equal(int(states[0]["initial_food_units"]), 4, "authored support capacity becomes initial finite reserve")
	_expect_equal(int(states[0]["remaining_food_units"]), 4, "prepared reserve starts full")
	_expect_equal(states[0]["anchor"], [1, 2], "cell placement identity is retained")
	_expect_equal(String(states[1]["fixture_id"]), "fixture-b", "fixture placement identity is retained")

func _test_reserve_is_conserved_across_ticks() -> void:
	var kernel: S05FeedCartridgeKernel = S05FeedCartridgeKernelScript.new()
	var prepared: Dictionary = kernel.prepare_support_states(
		[{"instance_id": "feed-a", "support_id": "feed", "fixture_id": "fixture-a"}],
		{"feed": {"family": "S05", "capacity": 3}}
	)
	_expect_true(bool(prepared.get("ok", false)), "S05 reserve fixture prepares for conservation test")
	if not bool(prepared.get("ok", false)):
		return
	var tick1: Dictionary = kernel.apply_phase_e_allocations(
		1,
		prepared["support_states"],
		[{"support_instance_id": "feed-a", "consumer_id": "cargo-a", "food_units": 2}]
	)
	_expect_true(bool(tick1.get("ok", false)), "first S05 allocation resolves")
	if not bool(tick1.get("ok", false)):
		return
	_expect_equal(int(tick1["support_states"][0]["remaining_food_units"]), 1, "reserve loses exactly allocated food units")
	var events1: Array = tick1["events"]
	_expect_equal(int(events1[0]["source_cost_units"]), 2, "S05 allocation records equal source cost")
	_expect_equal(int(events1[0]["reserve_before"]), 3, "event records pre-allocation reserve")
	_expect_equal(int(events1[0]["reserve_after"]), 1, "event records post-allocation reserve")
	var tick2: Dictionary = kernel.apply_phase_e_allocations(
		2,
		tick1["support_states"],
		[{"support_instance_id": "feed-a", "consumer_id": "cargo-b", "food_units": 1}]
	)
	_expect_true(bool(tick2.get("ok", false)), "second S05 allocation resolves from persisted reserve")
	if bool(tick2.get("ok", false)):
		_expect_equal(int(tick2["support_states"][0]["remaining_food_units"]), 0, "finite reserve depletes and never replenishes implicitly")

func _test_overallocation_is_rejected_without_mutation() -> void:
	var kernel: S05FeedCartridgeKernel = S05FeedCartridgeKernelScript.new()
	var prepared: Dictionary = kernel.prepare_support_states(
		[{"instance_id": "feed-a", "support_id": "feed", "fixture_id": "fixture-a"}],
		{"feed": {"family": "S05", "capacity": 2}}
	)
	if not bool(prepared.get("ok", false)):
		_expect_true(false, "over-allocation fixture prepares")
		return
	var states: Array = prepared["support_states"]
	var before: Array = states.duplicate(true)
	var result: Dictionary = kernel.apply_phase_e_allocations(
		1,
		states,
		[{"support_instance_id": "feed-a", "consumer_id": "cargo-a", "food_units": 3}]
	)
	_expect_true(not bool(result.get("ok", false)), "S05 refuses allocations beyond remaining reserve")
	_expect_equal(String(result.get("error", "")), "s05_allocation_exceeds_reserve:feed-a", "over-allocation failure names the exhausted cartridge")
	_expect_equal(states, before, "failed S05 allocation never mutates caller state")

func _test_allocation_order_is_canonical_and_replay_safe() -> void:
	var kernel: S05FeedCartridgeKernel = S05FeedCartridgeKernelScript.new()
	var prepared: Dictionary = kernel.prepare_support_states(
		[{"instance_id": "feed-a", "support_id": "feed", "fixture_id": "fixture-a"}],
		{"feed": {"family": "S05", "capacity": 4}}
	)
	if not bool(prepared.get("ok", false)):
		_expect_true(false, "determinism fixture prepares")
		return
	var first: Dictionary = kernel.apply_phase_e_allocations(
		1,
		prepared["support_states"],
		[
			{"support_instance_id": "feed-a", "consumer_id": "cargo-b", "food_units": 1},
			{"support_instance_id": "feed-a", "consumer_id": "cargo-a", "food_units": 1},
			{"support_instance_id": "feed-a", "consumer_id": "cargo-a", "food_units": 1},
		]
	)
	var reordered: Dictionary = kernel.apply_phase_e_allocations(
		1,
		prepared["support_states"],
		[
			{"support_instance_id": "feed-a", "consumer_id": "cargo-a", "food_units": 2},
			{"support_instance_id": "feed-a", "consumer_id": "cargo-b", "food_units": 1},
		]
	)
	_expect_true(bool(first.get("ok", false)) and bool(reordered.get("ok", false)), "both equivalent allocation batches resolve")
	_expect_equal(first, reordered, "equivalent S05 allocations normalize to identical deterministic result")
	if bool(first.get("ok", false)):
		var allocations: Array = first["allocations"]
		_expect_equal(String(allocations[0]["consumer_id"]), "cargo-a", "normalized allocation events use canonical consumer order")
		_expect_equal(int(first["support_states"][0]["remaining_food_units"]), 1, "merged allocations conserve the same total reserve")

func _test_missing_spatial_placement_is_rejected() -> void:
	var kernel: S05FeedCartridgeKernel = S05FeedCartridgeKernelScript.new()
	var result: Dictionary = kernel.prepare_support_states(
		[{"instance_id": "feed-a", "support_id": "feed"}],
		{"feed": {"family": "S05", "capacity": 2}}
	)
	_expect_true(not bool(result.get("ok", false)), "S05 cannot exist without its declared cell or fixture opportunity cost")
	_expect_equal(String(result.get("error", "")), "missing_s05_spatial_placement:feed-a", "missing placement failure is exact")

func _test_production_s05_t07_composition_and_depletion() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_production_record(), 3, _production_defs(2))
	var replay: Dictionary = runner.simulate(_production_record(), 3, _production_defs(2))
	_expect_true(bool(first.get("ok", false)) and bool(replay.get("ok", false)), "production S05 composes through existing T07 feeding boundary")
	if not bool(first.get("ok", false)) or not bool(replay.get("ok", false)):
		return
	_expect_equal(first["tick_checksums"], replay["tick_checksums"], "production S05 replay checksums are deterministic")
	var snapshots: Array = first["end_tick_snapshots"]
	_expect_equal(snapshots.size(), 3, "production S05 keeps one authoritative snapshot per tick")
	var tick1_states: Array = snapshots[0]["s05_support_states"]
	var tick2_states: Array = snapshots[1]["s05_support_states"]
	var tick3_states: Array = snapshots[2]["s05_support_states"]
	_expect_equal(int(tick1_states[0]["remaining_food_units"]), 1, "tick one debits exactly one T07-resolved cartridge unit")
	_expect_equal(int(tick2_states[0]["remaining_food_units"]), 0, "tick two depletes the finite cartridge reserve")
	_expect_equal(int(tick3_states[0]["remaining_food_units"]), 0, "depleted reserve does not replenish on later ticks")
	var tick1_runtime: Dictionary = _runtime_by_id(snapshots[0]["organism_runtime"])
	var tick2_runtime: Dictionary = _runtime_by_id(snapshots[1]["organism_runtime"])
	var tick3_runtime: Dictionary = _runtime_by_id(snapshots[2]["organism_runtime"])
	_expect_equal(int(tick1_runtime["grazer"]["satiety"]), 1, "S05 allocation uses T07 consumer satiety authority on tick one")
	_expect_equal(int(tick2_runtime["grazer"]["satiety"]), 2, "S05 allocation persists through T07 Phase-F satiety on tick two")
	_expect_equal(int(tick3_runtime["grazer"]["satiety"]), 2, "zero reserve creates no phantom feeding on tick three")
	var tick1_events: Array = snapshots[0]["s05_feed_events"]
	var tick2_events: Array = snapshots[1]["s05_feed_events"]
	var tick3_events: Array = snapshots[2]["s05_feed_events"]
	_expect_equal(tick1_events.size(), 1, "tick one exposes one S05 reserve allocation event")
	_expect_equal(tick2_events.size(), 1, "tick two exposes one S05 reserve allocation event")
	_expect_equal(tick3_events.size(), 0, "depleted cartridge emits no later allocation event")
	_expect_equal(String(tick1_events[0]["consumer_id"]), "grazer", "S05 does not choose a parallel target; T07-selected consumer is retained")
	_expect_equal(int(tick1_events[0]["reserve_before"]), 2, "S05 event records reserve before T07-resolved debit")
	_expect_equal(int(tick1_events[0]["reserve_after"]), 1, "S05 event records reserve after T07-resolved debit")
	var final_states: Array = first["final_s05_support_states"]
	_expect_equal(int(final_states[0]["remaining_food_units"]), 0, "production result retains final finite reserve authority")
	var changed: Dictionary = runner.simulate(_production_record(), 3, _production_defs(1))
	_expect_true(bool(changed.get("ok", false)), "alternate authored S05 capacity resolves")
	if bool(changed.get("ok", false)):
		_expect_true(String(first["tick_checksums"][0]) != String(changed["tick_checksums"][0]), "S05 reserve state is checksum-visible")

func _production_record() -> Dictionary:
	return {
		"run_id": "s05-production-run",
		"rules_version": "rules-r1",
		"content_version": "s05-production-1",
		"canonical_committed_input": {
			"route_id": "route-s05-production",
			"seed": 105,
			"placements": [
				{"instance_id": "grazer", "anchor": [1, 0], "orientation": 0},
			],
			"supports": [
				{"instance_id": "feed-a", "support_id": "feed", "anchor": [0, 0]},
			],
			"brownout_priority": [],
		},
	}

func _production_defs(capacity: int) -> Dictionary:
	return {
		"route_profile": {
			"id": "route-s05-production",
			"tick_count": 3,
			"events": [],
		},
		"hold_definition": {
			"dimensions": [2, 1],
			"blocked_cells": [],
			"power_capacity": 0,
		},
		"hazards_by_id": {},
		"support_definitions_by_id": {
			"feed": {
				"family": "S05",
				"capacity": capacity,
				"food_tags": ["cartridge_food"],
			},
		},
		"organism_definitions": {
			"grazer": {
				"initial_stress": 0,
				"initial_state": "CALM",
				"initial_body_stage": "JUVENILE",
				"initial_satiety": 0,
				"stress_profile": _stress_profile(),
				"body_stages": {"JUVENILE": {"footprints": {"0": [[0, 0]]}}},
			},
		},
		"t07_producer_definitions": [],
		"t07_consumer_definitions": [{
			"instance_id": "grazer",
			"range": 1,
			"intake_cap": 1,
			"benefit_per_unit": 1,
			"satiety_max": 4,
			"accepted_food_tags": ["cartridge_food"],
			"active_primary_states": ["CALM", "AGITATED", "PANICKED"],
			"active_body_stages": ["JUVENILE"],
			"sleep_gated": false,
		}],
	}

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

func _runtime_by_id(organisms: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_runtime: Variant in organisms:
		if raw_runtime is Dictionary:
			var runtime: Dictionary = raw_runtime
			result[String(runtime.get("instance_id", ""))] = runtime
	return result

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)
