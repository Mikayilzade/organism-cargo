extends SceneTree

const SleepWakeKernelScript := preload("res://src/sim/sleep_wake_kernel.gd")
const BlockedGrowthEpisodeResolverScript := preload("res://src/sim/blocked_growth_episode_resolver.gd")
const PhaseAPowerResolverScript := preload("res://src/sim/phase_a_power_resolver.gd")

var failures: int = 0

func _init() -> void:
	_test_simultaneous_h02_order_is_authoritatively_stable()
	_test_blocked_growth_signature_and_parent_order_are_stable()
	_test_blocked_growth_retry_boundary_and_clear_reset_episode_identity()
	_test_sleep_gate_is_explicit_only()
	_test_phase_a_brownout_is_input_order_invariant()
	_test_invalid_boundary_inputs_fail_closed()
	_finish()

func _test_simultaneous_h02_order_is_authoritatively_stable() -> void:
	var kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	var organisms: Array = [{"instance_id": "specimen-a", "primary_state": "ASLEEP"}]
	var hazards: Dictionary = {
		"h02-a": {"family": "H02", "wake_request": true, "wake_target_instance_ids": ["specimen-a"]},
		"h02-b": {"family": "H02", "wake_request": true, "wake_target_instance_ids": ["specimen-a"]},
	}
	var reversed: Dictionary = kernel.resolve_phase_b(4, organisms, PackedStringArray(["h02-b", "h02-a"]), hazards)
	var canonical: Dictionary = kernel.resolve_phase_b(4, organisms, PackedStringArray(["h02-a", "h02-b"]), hazards)
	_expect(bool(reversed.get("ok", false)) and bool(canonical.get("ok", false)), "simultaneous H02 requests resolve")
	_expect_equal(reversed.get("organisms"), canonical.get("organisms"), "H02 input order cannot change resulting organism state")
	_expect_equal(reversed.get("events"), canonical.get("events"), "H02 input order cannot change causal wake events")
	_expect_equal(reversed.get("wake_event_id_by_instance_id"), canonical.get("wake_event_id_by_instance_id"), "H02 input order cannot change wake-event identity map")
	var events_value: Variant = reversed.get("events", [])
	if events_value is Array:
		var events: Array = events_value
		_expect_equal(events.size(), 1, "same sleeping organism wakes once under simultaneous requests")
		if events.size() == 1 and events[0] is Dictionary:
			var event: Dictionary = events[0]
			_expect_equal(String(event.get("hazard_id", "")), "h02-a", "canonical hazard ordering deterministically owns the wake event")
			_expect_equal(event.get("parent_event_ids"), PackedStringArray(["route:A:4:h02-a"]), "wake ancestry is stable under input permutation")

func _test_blocked_growth_signature_and_parent_order_are_stable() -> void:
	var resolver: BlockedGrowthEpisodeResolver = BlockedGrowthEpisodeResolverScript.new()
	var first_attempt: Dictionary = _blocked_attempt("retry-1")
	first_attempt["required_cells"] = ["1,0", "0,0"]
	first_attempt["illegal_cells"] = ["1,0", "0,0"]
	first_attempt["occupied_cells"] = {"1,0": "crate-b", "0,0": "crate-a"}
	first_attempt["material_parent_ids"] = ["parent-b", "parent-a"]
	var first: Dictionary = resolver.resolve_attempt("specimen-a", {}, first_attempt)
	_expect(bool(first.get("ok", false)), "first blocked-growth attempt resolves")
	_expect(bool(first.get("entry_consequence_fired", false)), "first blocked obstruction opens exactly one episode")
	var first_event_value: Variant = first.get("causal_event", {})
	if first_event_value is Dictionary:
		var first_event: Dictionary = first_event_value
		_expect_equal(first_event.get("parents"), PackedStringArray(["parent-a", "parent-b"]), "blocked-growth material parents are canonicalized")

	var reordered_attempt: Dictionary = _blocked_attempt("retry-1")
	reordered_attempt["required_cells"] = ["0,0", "1,0"]
	reordered_attempt["illegal_cells"] = ["0,0", "1,0"]
	reordered_attempt["occupied_cells"] = {"0,0": "crate-a", "1,0": "crate-b"}
	reordered_attempt["material_parent_ids"] = ["parent-a", "parent-b"]
	var second: Dictionary = resolver.resolve_attempt("specimen-a", first.get("state", {}), reordered_attempt)
	_expect(bool(second.get("ok", false)), "permuted blocked-growth input resolves")
	_expect(not bool(second.get("entry_consequence_fired", true)), "permutation of the same obstruction cannot create a duplicate consequence")
	_expect(not bool(second.get("episode_started", true)), "permutation of the same obstruction remains inside the same episode")
	_expect_equal(int(second.get("episode_index", -1)), 1, "unchanged blocked episode keeps its identity")

func _test_blocked_growth_retry_boundary_and_clear_reset_episode_identity() -> void:
	var resolver: BlockedGrowthEpisodeResolver = BlockedGrowthEpisodeResolverScript.new()
	var first: Dictionary = resolver.resolve_attempt("specimen-a", {}, _blocked_attempt("retry-1"))
	var same: Dictionary = resolver.resolve_attempt("specimen-a", first.get("state", {}), _blocked_attempt("retry-1"))
	_expect(not bool(same.get("entry_consequence_fired", true)), "unchanged retry boundary does not repeat blocked-growth punishment")

	var retry_changed: Dictionary = resolver.resolve_attempt("specimen-a", same.get("state", {}), _blocked_attempt("retry-2"))
	_expect(bool(retry_changed.get("entry_consequence_fired", false)), "explicit retry-boundary change may begin a new blocked-growth episode")
	_expect_equal(int(retry_changed.get("episode_index", -1)), 2, "retry-boundary episode identity increments deterministically")
	var retry_same: Dictionary = resolver.resolve_attempt("specimen-a", retry_changed.get("state", {}), _blocked_attempt("retry-2"))
	_expect(not bool(retry_same.get("entry_consequence_fired", true)), "new retry episode still fires its consequence only once")

	var cleared: Dictionary = resolver.resolve_attempt("specimen-a", retry_same.get("state", {}), {"legal": true})
	_expect(bool(cleared.get("growth_allowed", false)), "legal growth clears the active blocked episode")
	var blocked_again: Dictionary = resolver.resolve_attempt("specimen-a", cleared.get("state", {}), _blocked_attempt("retry-2"))
	_expect(bool(blocked_again.get("entry_consequence_fired", false)), "a genuinely cleared obstruction may create a later new episode")
	_expect_equal(int(blocked_again.get("episode_index", -1)), 3, "cleared-then-blocked state advances episode identity exactly once")

func _test_sleep_gate_is_explicit_only() -> void:
	var kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	_expect(kernel.sleep_gate_allows("ASLEEP", false), "sleep does not implicitly suppress a non-sleep-gated trait")
	_expect(not kernel.sleep_gate_allows("ASLEEP", true), "explicit sleep gating suppresses only while asleep")
	_expect(kernel.sleep_gate_allows("PANICKED", true), "sleep gate does not suppress awake states")
	_expect(not kernel.sleep_gate_allows("INVALID", false), "unknown primary state fails closed")

func _test_phase_a_brownout_is_input_order_invariant() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var supports_a: Array = [
		{"instance_id": "cooler-a", "powered": true, "power_draw": 4, "supports_degraded_operation": false},
		{"instance_id": "monitor-a", "powered": true, "power_draw": 1, "supports_degraded_operation": false},
	]
	var supports_b: Array = [supports_a[1].duplicate(true), supports_a[0].duplicate(true)]
	var priority: Array = ["cooler-a", "monitor-a"]
	var first: Dictionary = resolver.resolve(4, supports_a, priority)
	var second: Dictionary = resolver.resolve(4, supports_b, priority)
	_expect(bool(first.get("ok", false)) and bool(second.get("ok", false)), "Brownout resolves for both support input permutations")
	_expect(bool(first.get("brownout_active", false)), "boundary demand above capacity activates Brownout")
	_expect_equal(first.get("powered_support_ids"), PackedStringArray(["cooler-a"]), "whole-support allocation honors player priority at exact capacity")
	_expect_equal(first.get("disabled_support_ids"), PackedStringArray(["monitor-a"]), "lower-priority support is fully disabled")
	_expect_equal(first.get("authority_checksum"), second.get("authority_checksum"), "support array order cannot alter Phase-A authority checksum")
	_expect_equal(first.get("same_tick_effect_eligible_support_ids"), second.get("same_tick_effect_eligible_support_ids"), "support array order cannot alter same-tick effect eligibility")

func _test_invalid_boundary_inputs_fail_closed() -> void:
	var sleep_kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	var invalid_tick: Dictionary = sleep_kernel.resolve_phase_b(0, [{"instance_id": "specimen-a", "primary_state": "ASLEEP"}], PackedStringArray(), {})
	_expect(not bool(invalid_tick.get("ok", true)), "tick zero is rejected at Phase-B boundary")
	_expect_equal(String(invalid_tick.get("error", "")), "invalid_tick", "invalid Phase-B tick has stable failure reason")

	var resolver: BlockedGrowthEpisodeResolver = BlockedGrowthEpisodeResolverScript.new()
	var malformed: Dictionary = resolver.resolve_attempt("specimen-a", {}, {"legal": false, "required_cells": "not-an-array"})
	_expect(not bool(malformed.get("ok", true)), "malformed blocked-growth signature input fails closed")
	_expect_equal(String(malformed.get("error", "")), "invalid_required_cells", "malformed growth input has deterministic failure reason")

func _blocked_attempt(retry_boundary: String) -> Dictionary:
	return {
		"legal": false,
		"required_cells": ["1,0"],
		"illegal_cells": ["1,0"],
		"occupied_cells": {"1,0": "crate-b"},
		"orientation": "E",
		"body_condition": "MATURE",
		"growth_trigger_condition": "qualified",
		"retry_boundary": retry_boundary,
		"material_parent_ids": ["parent-b", "parent-a"],
	}

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _finish() -> void:
	if failures == 0:
		print("phase12f_simulation_timing_adversarial_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12f_simulation_timing_adversarial_test_runner: %d failure(s)" % failures)
		quit(1)
