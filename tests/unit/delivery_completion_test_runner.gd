extends SceneTree

const DeliveryCompletionRunnerScript := preload("res://src/sim/delivery_completion_runner.gd")
const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")

var failures: int = 0

func _init() -> void:
	_test_phase_i_delivery_success_is_deterministic()
	_test_phase_i_delivery_failure_is_authoritative()
	_test_completed_success_and_failure_enter_causal_review()
	_test_invalid_predicate_is_rejected()
	if failures == 0:
		print("delivery_completion_test_runner: PASS")
		quit(0)
	else:
		push_error("delivery_completion_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_phase_i_delivery_success_is_deterministic() -> void:
	var runner: DeliveryCompletionRunner = DeliveryCompletionRunnerScript.new()
	var first: Dictionary = runner.simulate_and_complete(_record("run-a"), 3, _defs(), _success_predicates())
	var second: Dictionary = runner.simulate_and_complete(_record("run-b"), 3, _defs(), _success_predicates())
	_expect_true(bool(first.get("ok", false)), "successful delivery completion executes")
	_expect_true(bool(first["delivery_result"]["success"]), "all mandatory final-state predicates pass")
	_expect_equal(String(first["next_state"]), "CAUSAL_REVIEW", "completed transit owns the handoff to Causal Review")
	_expect_equal(String(first["completion_checksum"]), String(second["completion_checksum"]), "run identity does not change authoritative completion checksum")
	var results: Array = first["delivery_result"]["predicate_results"]
	_expect_equal(results.size(), 2, "both authored mandatory predicates are evaluated")
	_expect_equal(int(results[0]["observed"]), 17, "Phase-I stress predicate reads authoritative final stress")
	_expect_equal(String(results[1]["observed"]), "PANICKED", "Phase-I state predicate reads authoritative final primary state")

func _test_phase_i_delivery_failure_is_authoritative() -> void:
	var runner: DeliveryCompletionRunner = DeliveryCompletionRunnerScript.new()
	var success: Dictionary = runner.simulate_and_complete(_record("run-a"), 3, _defs(), _success_predicates())
	var failure: Dictionary = runner.simulate_and_complete(_record("run-a"), 3, _defs(), _failure_predicates())
	_expect_true(bool(failure.get("ok", false)), "failed delivery is a completed authoritative result rather than a simulation error")
	_expect_true(not bool(failure["delivery_result"]["success"]), "one failed mandatory predicate fails delivery")
	_expect_true(String(success["completion_checksum"]) != String(failure["completion_checksum"]), "mandatory outcome is checksum-visible")

func _test_completed_success_and_failure_enter_causal_review() -> void:
	var runner: DeliveryCompletionRunner = DeliveryCompletionRunnerScript.new()
	var success_result: Dictionary = runner.simulate_and_complete(_record("run-a"), 3, _defs(), _success_predicates())
	var failure_result: Dictionary = runner.simulate_and_complete(_record("run-a"), 3, _defs(), _failure_predicates())
	var success_state: AppStateMachine = _state_at_transit()
	var failure_state: AppStateMachine = _state_at_transit()
	_expect_true(success_state.accept_completed_transit(success_result), "successful transit hands ownership to Causal Review")
	_expect_equal(success_state.current_state(), AppStateMachine.State.CAUSAL_REVIEW, "success reaches Causal Review before Results")
	_expect_true(failure_state.accept_completed_transit(failure_result), "failed transit also hands ownership to Causal Review")
	_expect_equal(failure_state.current_state(), AppStateMachine.State.CAUSAL_REVIEW, "failure reaches Causal Review before retry/results")

func _test_invalid_predicate_is_rejected() -> void:
	var runner: DeliveryCompletionRunner = DeliveryCompletionRunnerScript.new()
	var invalid: Array = [
		{"id": "m-bad", "kind": "STRESS_AT_MOST", "instance_id": "missing", "value": 20},
	]
	var result: Dictionary = runner.simulate_and_complete(_record("run-a"), 3, _defs(), invalid)
	_expect_true(not bool(result.get("ok", false)), "unknown mandatory target is rejected")
	_expect_true(String(result.get("error", "")).begins_with("phase_i:unknown_mandatory_instance"), "predicate validation failure is scoped to Phase I")

func _state_at_transit() -> AppStateMachine:
	var state: AppStateMachine = AppStateMachineScript.new()
	_expect_true(state.transition_to(AppStateMachine.State.TITLE), "test path boot -> title")
	_expect_true(state.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "test path title -> map")
	_expect_true(state.transition_to(AppStateMachine.State.CONTRACT_BRIEF), "test path map -> brief")
	_expect_true(state.transition_to(AppStateMachine.State.PLANNING), "test path brief -> planning")
	_expect_true(state.transition_to(AppStateMachine.State.LAUNCH_CONFIRM), "test path planning -> launch confirm")
	_expect_true(state.transition_to(AppStateMachine.State.TRANSIT_PLAYBACK), "test path launch -> transit")
	return state

func _success_predicates() -> Array:
	return [
		{"id": "m-stress", "kind": "STRESS_AT_MOST", "instance_id": "specimen-a", "value": 20},
		{"id": "m-state", "kind": "PRIMARY_STATE_IS", "instance_id": "specimen-a", "value": "PANICKED"},
	]

func _failure_predicates() -> Array:
	return [
		{"id": "m-stress", "kind": "STRESS_AT_MOST", "instance_id": "specimen-a", "value": 9},
		{"id": "m-state", "kind": "PRIMARY_STATE_IS", "instance_id": "specimen-a", "value": "PANICKED"},
	]

func _record(run_id: String) -> Dictionary:
	return {
		"run_id": run_id,
		"rules_version": "rules-r1",
		"content_version": "vertical-slice-test-1",
		"canonical_committed_input": {
			"route_id": "route-slice",
			"seed": 101,
			"placements": [
				{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			],
			"supports": [],
		},
	}

func _defs() -> Dictionary:
	return {
		"route_profile": {
			"id": "route-slice",
			"tick_count": 3,
			"events": [
				{"tick": 2, "duration_ticks": 1, "hazard_id": "h01-slice", "authored_order": 0},
			],
		},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": []},
		"hazards_by_id": {
			"h01-slice": {"id": "h01-slice", "family": "H01", "target_scope": "hold", "heat_delta": 6},
		},
		"thermal_rules": {
			"heat_min": 0,
			"heat_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"specimen-a": {
				"initial_stress": 1,
				"initial_state": "CALM",
				"stress_profile": {
					"heat_safe_max": 2,
					"stress_per_heat_unit": 2,
					"stress_min": 0,
					"stress_max": 20,
					"agitated_enter": 5,
					"agitated_exit": 3,
					"panic_enter": 10,
					"panic_exit": 7,
				},
			},
		},
	}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
