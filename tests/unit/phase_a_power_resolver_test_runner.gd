extends SceneTree

const PhaseAPowerResolverScript := preload("res://src/sim/phase_a_power_resolver.gd")

var failures: int = 0

func _init() -> void:
	_test_no_brownout_powers_every_support_deterministically()
	_test_brownout_uses_unique_player_priority_and_full_on_off_allocation()
	_test_disabled_support_has_no_same_tick_effect_eligibility()
	_test_power_transition_event_is_emitted()
	_test_invalid_brownout_priority_fails_closed()
	_test_priority_changes_authoritative_checksum()
	if failures == 0:
		print("phase_a_power_resolver_test_runner: PASS")
		quit(0)
	else:
		push_error("phase_a_power_resolver_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_no_brownout_powers_every_support_deterministically() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var first: Dictionary = resolver.resolve(8, _supports(), [])
	var second: Dictionary = resolver.resolve(8, _supports_reordered(), [])
	_expect_true(bool(first["ok"]) and bool(second["ok"]), "sufficient power resolves without priority")
	_expect_equal(first["powered_support_ids"], PackedStringArray(["cooler-a", "filter-a", "monitor-a"]), "powered state is stable support-id ordered")
	_expect_equal(int(first["used_power"]), 8, "all powered-support demand is allocated when capacity is sufficient")
	_expect_equal(first["authority_checksum"], second["authority_checksum"], "input support ordering does not change Phase-A authority")

func _test_brownout_uses_unique_player_priority_and_full_on_off_allocation() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var result: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "monitor-a"])
	_expect_true(bool(result["ok"]), "Brownout allocation succeeds with complete unique priority")
	_expect_true(bool(result["brownout_active"]), "demand above temporary capacity marks Brownout active")
	_expect_equal(result["powered_support_ids"], PackedStringArray(["cooler-a", "monitor-a"]), "priority allocates whole supports without partial power")
	_expect_equal(result["disabled_support_ids"], PackedStringArray(["filter-a"]), "support that cannot fit remaining power is fully off")
	_expect_equal(int(result["used_power"]), 5, "priority allocation consumes only whole-support power draw")

func _test_disabled_support_has_no_same_tick_effect_eligibility() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var result: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "monitor-a"])
	_expect_equal(result["same_tick_effect_eligible_support_ids"], PackedStringArray(["cooler-a", "monitor-a"]), "Phase-A disabled support is absent from same-tick Phase-C/E effect eligibility")
	_expect_true(not bool(result["powered_by_id"]["filter-a"]), "disabled support authority is finalized off in Phase A")

func _test_power_transition_event_is_emitted() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var previous: Dictionary = {
		"cooler-a": true,
		"filter-a": true,
		"monitor-a": true,
	}
	var result: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "monitor-a"], previous)
	var events: Array = result["events"]
	_expect_equal(events.size(), 1, "only the support whose power state changes emits a causal transition event")
	var event: Dictionary = events[0]
	_expect_equal(String(event["support_instance_id"]), "filter-a", "transition event identifies the Brownout-disabled support")
	_expect_true(bool(event["from_powered"]) and not bool(event["to_powered"]), "transition event preserves powered-to-off direction")

func _test_invalid_brownout_priority_fails_closed() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var missing: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a"])
	var duplicate: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "filter-a"])
	_expect_true(not bool(missing["ok"]), "Brownout cannot invent a missing priority entry")
	_expect_equal(String(missing["error"]), "brownout_priority_must_cover_all_powered_supports", "missing priority has deterministic failure reason")
	_expect_true(not bool(duplicate["ok"]), "Brownout priority must be unique")
	_expect_equal(String(duplicate["error"]), "duplicate_brownout_priority_id:filter-a", "duplicate priority has deterministic failure reason")

func _test_priority_changes_authoritative_checksum() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var cooler_first: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "monitor-a"])
	var filter_first: Dictionary = resolver.resolve(5, _supports(), ["filter-a", "cooler-a", "monitor-a"])
	_expect_true(bool(cooler_first["ok"]) and bool(filter_first["ok"]), "both legal player priorities resolve")
	_expect_equal(filter_first["powered_support_ids"], PackedStringArray(["filter-a", "monitor-a"]), "changed player priority changes the powered support set")
	_expect_true(String(cooler_first["authority_checksum"]) != String(filter_first["authority_checksum"]), "different Phase-A power authority changes checksum evidence")

func _supports() -> Array:
	return [
		{"instance_id": "cooler-a", "powered": true, "power_draw": 4},
		{"instance_id": "filter-a", "powered": true, "power_draw": 3},
		{"instance_id": "monitor-a", "powered": true, "power_draw": 1},
		{"instance_id": "baffle-a", "powered": false, "power_draw": 0},
	]

func _supports_reordered() -> Array:
	return [
		{"instance_id": "monitor-a", "powered": true, "power_draw": 1},
		{"instance_id": "baffle-a", "powered": false, "power_draw": 0},
		{"instance_id": "filter-a", "powered": true, "power_draw": 3},
		{"instance_id": "cooler-a", "powered": true, "power_draw": 4},
	]

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
