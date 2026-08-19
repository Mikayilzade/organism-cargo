extends SceneTree

const DeliveryCompletionRunnerScript := preload("res://src/sim/delivery_completion_runner.gd")
const CausalReviewEvidenceBuilderScript := preload("res://src/sim/causal_review_evidence_builder.gd")

var failures: int = 0

func _init() -> void:
	_test_h01_review_evidence_is_deterministic()
	_test_failed_predicate_binds_to_latest_organism_event()
	_test_malformed_result_is_rejected()
	if failures == 0:
		print("causal_review_evidence_test_runner: PASS")
		quit(0)
	else:
		push_error("causal_review_evidence_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_h01_review_evidence_is_deterministic() -> void:
	var completion_runner: DeliveryCompletionRunner = DeliveryCompletionRunnerScript.new()
	var builder: CausalReviewEvidenceBuilder = CausalReviewEvidenceBuilderScript.new()
	var first_completed: Dictionary = completion_runner.simulate_and_complete(_record("run-a"), 3, _defs(), _failure_predicates())
	var second_completed: Dictionary = completion_runner.simulate_and_complete(_record("run-b"), 3, _defs(), _failure_predicates())
	var first: Dictionary = builder.build(first_completed)
	var second: Dictionary = builder.build(second_completed)
	_expect_true(bool(first.get("ok", false)), "review evidence builds from authoritative completed transit")
	_expect_equal(String(first["review_checksum"]), String(second["review_checksum"]), "review evidence ignores persistence-only run identity")
	_expect_equal(String(first["first_meaningful_event_id"]), "t000002:h:h01-slice", "H01 activation is the earliest meaningful event in the tiny trace")
	_expect_equal(String(first["first_actionable_event_id"]), "t000002:o:specimen-a", "first organism response is the earliest plan-revisable evidence node")
	var events: Array = first["events"]
	_expect_true(events.size() >= 4, "review payload contains hazard, organism response and predicate evidence")
	var response: Dictionary = _event_by_id(events, "t000002:o:specimen-a")
	var parents: PackedStringArray = response.get("parent_event_ids", PackedStringArray())
	_expect_equal(parents.size(), 1, "H01 organism response preserves its immediate root")
	_expect_equal(String(parents[0]), "t000002:h:h01-slice", "H01 hazard is parent of the same-tick organism response")

func _test_failed_predicate_binds_to_latest_organism_event() -> void:
	var completion_runner: DeliveryCompletionRunner = DeliveryCompletionRunnerScript.new()
	var builder: CausalReviewEvidenceBuilder = CausalReviewEvidenceBuilderScript.new()
	var completed: Dictionary = completion_runner.simulate_and_complete(_record("run-a"), 3, _defs(), _failure_predicates())
	var review: Dictionary = builder.build(completed)
	var objectives: Array = review["objective_events"]
	var failed: Dictionary = {}
	for objective_value: Variant in objectives:
		if not objective_value is Dictionary:
			continue
		var objective: Dictionary = objective_value
		if String(objective.get("predicate_id", "")) == "m-stress":
			failed = objective
			break
	_expect_true(not failed.is_empty(), "failed mandatory predicate is exposed in review payload")
	_expect_true(not bool(failed.get("passed", true)), "predicate failure remains authoritative review evidence")
	var parents: PackedStringArray = failed.get("parent_event_ids", PackedStringArray())
	_expect_equal(parents.size(), 1, "objective evidence points to the latest relevant organism event")
	_expect_equal(String(parents[0]), "t000003:o:specimen-a", "final failed stress predicate descends from the latest organism response")

func _test_malformed_result_is_rejected() -> void:
	var builder: CausalReviewEvidenceBuilder = CausalReviewEvidenceBuilderScript.new()
	var review: Dictionary = builder.build({"ok": true, "completed": false})
	_expect_true(not bool(review.get("ok", false)), "incomplete transit cannot fabricate review evidence")
	_expect_equal(String(review.get("error", "")), "incomplete_authoritative_result", "malformed review input returns explicit error")

func _event_by_id(events: Array, event_id: String) -> Dictionary:
	for event_value: Variant in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		if String(event.get("event_id", "")) == event_id:
			return event
	return {}

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
