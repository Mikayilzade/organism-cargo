extends SceneTree

const ResolverScript := preload("res://src/sim/blocked_growth_episode_resolver.gd")

func _init() -> void:
	var resolver: BlockedGrowthEpisodeResolver = ResolverScript.new()
	var state: Dictionary = {}
	var first_attempt: Dictionary = _blocked_attempt("cargo-02", "", "planning-retry-0")
	var first: Dictionary = resolver.resolve_attempt("cargo-01", state, first_attempt)
	_assert_true(bool(first["ok"]), "first blocked attempt resolves")
	_assert_true(bool(first["entry_consequence_fired"]), "first blocked attempt fires one entry consequence")
	_assert_equal(int(first["episode_index"]), 1, "first blocked attempt starts episode one")
	_assert_equal(String(first["condition_flag"]), "GROWTH_BLOCKED", "blocked condition remains visible")
	_assert_equal(String(first["causal_event"]["event_id"]), "growth-blocked:cargo-01:1", "blocked episode owns one stable causal root")
	state = first["state"]

	var unchanged: Dictionary = resolver.resolve_attempt("cargo-01", state, first_attempt)
	_assert_true(bool(unchanged["ok"]), "unchanged blocked attempt resolves")
	_assert_false(bool(unchanged["entry_consequence_fired"]), "unchanged obstruction does not repeat consequence")
	_assert_equal(int(unchanged["episode_index"]), 1, "unchanged obstruction stays in same episode")
	_assert_true(unchanged["causal_event"].is_empty(), "unchanged obstruction does not create another causal root")
	state = unchanged["state"]

	var reordered: Dictionary = _blocked_attempt("cargo-02", "", "planning-retry-0")
	reordered["required_cells"] = ["2,1", "1,1"]
	reordered["occupied_cells"] = {"3,3": "", "2,1": "cargo-02"}
	var reordered_result: Dictionary = resolver.resolve_attempt("cargo-01", state, reordered)
	_assert_false(bool(reordered_result["entry_consequence_fired"]), "canonical condition signature ignores collection insertion order")
	_assert_equal(int(reordered_result["episode_index"]), 1, "reordered equivalent obstruction stays in same episode")
	state = reordered_result["state"]

	var changed_occupancy: Dictionary = _blocked_attempt("cargo-03", "", "planning-retry-0")
	var second_episode: Dictionary = resolver.resolve_attempt("cargo-01", state, changed_occupancy)
	_assert_true(bool(second_episode["entry_consequence_fired"]), "changed occupancy begins a new blocked-growth episode")
	_assert_equal(int(second_episode["episode_index"]), 2, "changed occupancy advances episode identity")
	state = second_episode["state"]

	var legal_attempt: Dictionary = {"legal": true}
	var cleared: Dictionary = resolver.resolve_attempt("cargo-01", state, legal_attempt)
	_assert_true(bool(cleared["growth_allowed"]), "legal growth attempt is allowed")
	_assert_equal(String(cleared["condition_flag"]), "", "successful growth clears blocked condition")
	state = cleared["state"]

	var blocked_again: Dictionary = resolver.resolve_attempt("cargo-01", state, changed_occupancy)
	_assert_true(bool(blocked_again["entry_consequence_fired"]), "blocked attempt after successful clearance begins a new episode")
	_assert_equal(int(blocked_again["episode_index"]), 3, "post-clear blockage advances episode identity")
	state = blocked_again["state"]

	var retry_changed: Dictionary = _blocked_attempt("cargo-03", "", "planning-retry-1")
	var retry_episode: Dictionary = resolver.resolve_attempt("cargo-01", state, retry_changed)
	_assert_true(bool(retry_episode["entry_consequence_fired"]), "explicit retry-boundary change permits a new episode")
	_assert_equal(int(retry_episode["episode_index"]), 4, "retry boundary advances episode identity")

	var orientation_changed: Dictionary = _blocked_attempt("cargo-03", "east", "planning-retry-1")
	var orientation_episode: Dictionary = resolver.resolve_attempt("cargo-01", retry_episode["state"], orientation_changed)
	_assert_true(bool(orientation_episode["entry_consequence_fired"]), "orientation change permits a new episode")
	_assert_equal(int(orientation_episode["episode_index"]), 5, "orientation change advances episode identity")

	print("blocked_growth_episode_test_runner: PASS")
	quit(0)

func _blocked_attempt(occupant: String, orientation: String, retry_boundary: String) -> Dictionary:
	return {
		"legal": false,
		"required_cells": ["1,1", "2,1"],
		"illegal_cells": [],
		"occupied_cells": {"2,1": occupant, "3,3": ""},
		"orientation": orientation,
		"body_condition": "JUVENILE_TO_MATURE",
		"growth_trigger_condition": "qualified",
		"retry_boundary": retry_boundary,
		"material_parent_ids": ["growth-trigger:cargo-01"],
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
	push_error("blocked_growth_episode_test_runner: %s" % message)
	quit(1)
