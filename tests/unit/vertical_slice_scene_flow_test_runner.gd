extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const ContentRegistryScript := preload("res://src/content/content_registry.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")

var failures: int = 0
var run_sequence: int = 0

func _init() -> void:
	_test_complete_scene_flow_and_changed_retry_identity()
	if failures == 0:
		print("vertical_slice_scene_flow_test_runner: PASS")
		quit(0)
	else:
		push_error("vertical_slice_scene_flow_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_complete_scene_flow_and_changed_retry_identity() -> void:
	var root: String = "user://vertical_slice_scene_flow_fixture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_remove_if_exists(root.path_join("session.sav"))
	_remove_if_exists(root.path_join("session.sav.bak"))
	_remove_if_exists(root.path_join("session.sav.tmp"))

	var registry: ContentRegistry = ContentRegistryScript.new()
	var loaded_content: Dictionary = registry.load_families({
		"contract": "res://tests/fixtures/vertical_slice/contracts",
		"hold": "res://tests/fixtures/vertical_slice/holds",
		"species": "res://tests/fixtures/vertical_slice/species",
	})
	_expect_true(bool(loaded_content.get("ok", false)), "VS01 structural fixtures load")
	if not bool(loaded_content.get("ok", false)):
		return
	var contract_payload: Dictionary = _payload(registry, &"contract", &"VS01")
	var hold_payload: Dictionary = _payload(registry, &"hold", &"VS_HOLD_01")
	var species_by_id: Dictionary = {}
	for document: ContentDocument in registry.ordered_documents(&"species"):
		species_by_id[String(document.id)] = document.payload.duplicate(true)

	var state_machine: AppStateMachine = AppStateMachineScript.new()
	_expect_true(state_machine.transition_to(AppStateMachine.State.TITLE), "boot -> title")
	var save_store: AtomicSaveStore = AtomicSaveStoreScript.new(root)
	var flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(
		state_machine,
		save_store,
		Callable(self, "_next_run_id")
	)
	_expect_true(flow.enter_campaign_map(), "title -> campaign map")
	_expect_true(flow.select_contract(), "campaign map -> contract brief")
	_expect_true(flow.begin_planning(), "contract brief -> planning")

	var canonical_input: Dictionary = _input([
		{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
		{"instance_id": "specimen-b", "anchor": [1, 1], "orientation": 0},
	])
	var revision: Dictionary = flow.apply_plan_from_content(
		"revision-vs01-a",
		canonical_input,
		contract_payload,
		hold_payload,
		species_by_id
	)
	_expect_true(bool(revision.get("structural_legal", false)), "VS01 plan is structurally legal")
	var confirm: Dictionary = flow.request_launch_confirm()
	_expect_true(bool(confirm.get("ok", false)), "legal plan enters launch confirmation")
	var first_launch: Dictionary = flow.commit_launch(
		"launch-vs01-a",
		"profile-vs01",
		"VS01",
		"rules-r1",
		"vertical-slice-test-1",
		"vs01-definition-checksum"
	)
	_expect_true(bool(first_launch.get("ok", false)), "confirmed plan commits exactly once")
	_expect_equal(String(first_launch.get("run_id", "")), "run-vs01-1", "first durable run identity")
	_expect_equal(flow.current_state(), AppStateMachine.State.TRANSIT_PLAYBACK, "Launch hands ownership to transit")

	var completed: Dictionary = flow.complete_transit(3, _defs(), _success_predicates())
	_expect_true(bool(completed.get("ok", false)), "deterministic transit completes through coordinator")
	_expect_equal(flow.current_state(), AppStateMachine.State.CAUSAL_REVIEW, "completed transit enters Causal Review")
	var review: Dictionary = completed.get("review", {})
	_expect_true(bool(review.get("ok", false)), "Causal Review evidence is built")
	_expect_true(not String(review.get("first_actionable_event_id", "")).is_empty(), "review exposes an actionable event")

	var retry: Dictionary = flow.begin_retry("revision-vs01-b", _legal_structural_facts())
	_expect_true(bool(retry.get("ok", false)), "targeted Retry returns to editable planning")
	_expect_equal(String(retry.get("source_run_id", "")), "run-vs01-1", "Retry retains source run identity")
	_expect_equal(flow.current_state(), AppStateMachine.State.PLANNING, "Retry owns planning state")

	var changed_input: Dictionary = _input([
		{"instance_id": "specimen-a", "anchor": [1, 1], "orientation": 0},
		{"instance_id": "specimen-b", "anchor": [0, 0], "orientation": 0},
	])
	var changed_revision: Dictionary = flow.apply_plan("revision-vs01-b", changed_input, _legal_structural_facts())
	_expect_true(bool(changed_revision.get("structural_legal", false)), "Retry revision remains legal after targeted edit")
	_expect_true(bool(flow.request_launch_confirm().get("ok", false)), "changed Retry enters confirmation")
	var second_launch: Dictionary = flow.commit_launch(
		"launch-vs01-b",
		"profile-vs01",
		"VS01",
		"rules-r1",
		"vertical-slice-test-1",
		"vs01-definition-checksum"
	)
	_expect_true(bool(second_launch.get("ok", false)), "changed Retry commits")
	_expect_equal(String(second_launch.get("run_id", "")), "run-vs01-2", "changed Retry receives new run identity")
	_expect_true(String(second_launch.get("run_id", "")) != String(first_launch.get("run_id", "")), "Retry never reuses prior run identity")

func _next_run_id() -> String:
	run_sequence += 1
	return "run-vs01-%d" % run_sequence

func _payload(registry: ContentRegistry, kind: StringName, id: StringName) -> Dictionary:
	for document: ContentDocument in registry.ordered_documents(kind):
		if document.id == id:
			return document.payload.duplicate(true)
	failures += 1
	push_error("FAIL: missing fixture %s/%s" % [String(kind), String(id)])
	return {}

func _input(placements: Array) -> Dictionary:
	return {
		"route_id": "route-slice",
		"manifest_instance_ids": ["specimen-a", "specimen-b"],
		"placements": placements,
		"supports": [],
		"seed": 101,
	}

func _legal_structural_facts() -> Dictionary:
	return {
		"mandatory_manifest_placed": true,
		"overlap_free": true,
		"blocked_free": true,
		"in_bounds": true,
		"orientations_valid": true,
		"zones_valid": true,
		"fixtures_valid": true,
		"links_valid": true,
		"support_resources_valid": true,
		"structural_prerequisites_met": true,
	}

func _success_predicates() -> Array:
	return [
		{"id": "m-stress", "kind": "STRESS_AT_MOST", "instance_id": "specimen-a", "value": 20},
		{"id": "m-state", "kind": "PRIMARY_STATE_IS", "instance_id": "specimen-a", "value": "PANICKED"},
	]

func _defs() -> Dictionary:
	var stress_profile: Dictionary = {
		"heat_safe_max": 2,
		"stress_per_heat_unit": 2,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 5,
		"agitated_exit": 3,
		"panic_enter": 10,
		"panic_exit": 7,
	}
	return {
		"route_profile": {
			"id": "route-slice",
			"tick_count": 3,
			"events": [
				{"tick": 2, "duration_ticks": 1, "hazard_id": "h01-slice", "authored_order": 0},
			],
		},
		"hold_definition": {"dimensions": [2, 2], "blocked_cells": []},
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
			"specimen-a": {"initial_stress": 1, "initial_state": "CALM", "stress_profile": stress_profile.duplicate(true)},
			"specimen-b": {"initial_stress": 1, "initial_state": "CALM", "stress_profile": stress_profile.duplicate(true)},
		},
	}

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
