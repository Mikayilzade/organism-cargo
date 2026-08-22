extends SceneTree

const S05FeedCartridgeKernelScript := preload("res://src/sim/s05_feed_cartridge_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_prepare_finite_reserve_and_spatial_identity()
	_test_reserve_is_conserved_across_ticks()
	_test_overallocation_is_rejected_without_mutation()
	_test_allocation_order_is_canonical_and_replay_safe()
	_test_missing_spatial_placement_is_rejected()
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

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)
