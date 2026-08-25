class_name Phase12EReviewCodexAcceptance
extends RefCounted

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")
const AccessibleVerticalSliceControlScript := preload("res://src/ui/accessible_vertical_slice_control.gd")
const SemanticVerticalSliceInputScript := preload("res://src/ui/semantic_vertical_slice_input.gd")

var _failures: Array[String] = []

func run(tree: SceneTree, run_id_factory: Callable) -> Array[String]:
	_failures.clear()
	var root_path: String = "user://phase12e_review_codex_fixture"
	_clear_store(root_path)
	var state: AppStateMachine = AppStateMachineScript.new()
	_expect(state.transition_to(AppStateMachine.State.TITLE), "boot -> title")
	var store: AtomicSaveStore = AtomicSaveStoreScript.new(root_path)
	var flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(state, store, run_id_factory)
	var control: AccessibleVerticalSliceControl = AccessibleVerticalSliceControlScript.new()
	tree.root.add_child(control)
	var context: Dictionary = _context()
	control.configure(flow, context)
	var semantic: SemanticVerticalSliceInput = SemanticVerticalSliceInputScript.new()
	tree.root.add_child(semantic)
	var configured: Dictionary = semantic.configure(control, flow, context)
	_expect(bool(configured.get("ok", false)), "semantic 12E navigation surface configures")
	await tree.process_frame

	_expect(bool(semantic.dispatch(&"accept").get("ok", false)), "title -> map")
	_expect(bool(semantic.dispatch(&"inspect").get("ok", false)), "map Inspect opens Codex without pointer")
	_expect_equal(flow.current_state(), AppStateMachine.State.CODEX, "Codex state is entered")
	var surface: Node = control.get_node_or_null("Phase12ENavigationSurface")
	_expect(surface != null, "rendered 12E navigation surface exists")
	var codex_panel: Control = control.get_node_or_null("Phase12ENavigationSurface/CodexPanel") as Control
	_expect(codex_panel != null and codex_panel.visible, "Codex panel is rendered")
	var codex_scroll: ScrollContainer = control.get_node_or_null("Phase12ENavigationSurface/CodexPanel/CodexScroll") as ScrollContainer
	_expect(codex_scroll != null, "Codex exact-rule content owns a scroll container")
	if codex_scroll != null:
		_expect(codex_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Codex wraps rather than requiring horizontal precision")
	var exact_rules: RichTextLabel = control.get_node_or_null("Phase12ENavigationSurface/CodexPanel/CodexScroll/CodexExactRules") as RichTextLabel
	_expect(exact_rules != null, "Codex exact-rule text is rendered")
	if exact_rules != null:
		_expect(exact_rules.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Codex exact rules wrap at maximum scale")
		_expect(exact_rules.text.contains("stress_per_heat_unit"), "Codex exposes exact arithmetic from documented species data")
		_expect(not exact_rules.text.contains("..."), "Codex exact arithmetic is not ellipsized")
	_expect(bool(semantic.dispatch(&"navigate_down").get("ok", false)), "Codex scroll is semantic keyboard/controller reachable")
	_expect(bool(semantic.dispatch(&"cancel").get("ok", false)), "Codex Cancel returns to prior state")
	_expect_equal(flow.current_state(), AppStateMachine.State.CAMPAIGN_MAP, "Codex returns to map")

	_expect(bool(semantic.dispatch(&"accept").get("ok", false)), "map -> brief")
	_expect(bool(semantic.dispatch(&"accept").get("ok", false)), "brief -> planning")
	var revision: Dictionary = flow.apply_plan("review-nav-a", _input(), _legal_facts())
	_expect(bool(revision.get("structural_legal", false)), "review navigation fixture plan is legal")
	_expect(bool(control.activate_primary_action().get("ok", false)), "planning -> launch confirm")
	_expect(bool(control.activate_primary_action().get("ok", false)), "launch commits")
	_expect(bool(semantic.dispatch(&"accept").get("ok", false)), "transit -> review")
	_expect_equal(flow.current_state(), AppStateMachine.State.CAUSAL_REVIEW, "fixture reaches review")
	await tree.process_frame
	var review_panel: Control = control.get_node_or_null("Phase12ENavigationSurface/ReviewExitPanel") as Control
	_expect(review_panel != null and review_panel.visible, "Retry / Reset / Return to map panel is rendered")
	_expect_equal(String(semantic.snapshot().get("review_exit_action", "")), "retry", "Retry is default safe review action")

	_expect(bool(semantic.dispatch(&"navigate_right").get("ok", false)), "review action focus moves without pointer")
	_expect_equal(String(semantic.snapshot().get("review_exit_action", "")), "reset_contract", "Reset contract is keyboard/controller selectable")
	_expect(bool(semantic.dispatch(&"accept").get("ok", false)), "Reset contract activates semantically")
	_expect_equal(flow.current_state(), AppStateMachine.State.PLANNING, "Reset contract returns to planning")
	var reset_snapshot: Dictionary = flow.planning_snapshot()
	_expect(bool(reset_snapshot.get("ok", false)), "reset planning baseline exists")
	_expect_equal((reset_snapshot.get("canonical_input", {}) as Dictionary).get("placements", []), [], "Reset contract clears placements to authored initial setup")

	# Re-enter a completed review to verify Return to map and Retry are independently reachable.
	_expect(bool(flow.apply_plan("review-nav-b", _input(), _legal_facts()).get("structural_legal", false)), "second legal plan applies")
	_expect(bool(flow.request_launch_confirm().get("ok", false)), "second launch confirm")
	_expect(bool(flow.commit_launch("launch-review-nav-b", "profile-review-nav", "VS01", "rules-r1", "content-r1", "checksum-review-nav").get("ok", false)), "second launch commits")
	_expect(bool(flow.complete_transit(1, _defs(), _predicates()).get("ok", false)), "second transit completes")
	semantic.dispatch(&"navigate_right")
	semantic.dispatch(&"navigate_right")
	_expect_equal(String(semantic.snapshot().get("review_exit_action", "")), "return_to_map", "Return to map is semantic third review action")
	_expect(bool(semantic.dispatch(&"accept").get("ok", false)), "Return to map activates")
	_expect_equal(flow.current_state(), AppStateMachine.State.CAMPAIGN_MAP, "Return to map reaches campaign map")

	control.queue_free()
	semantic.queue_free()
	await tree.process_frame
	return _failures.duplicate()

func _context() -> Dictionary:
	return {
		"launch_request_token": "launch-review-nav-a",
		"profile_uuid": "profile-review-nav",
		"contract_id": "VS01",
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"contract_definition_checksum": "checksum-review-nav",
		"planning_route_id": "route-review-nav",
		"planning_seed": 101,
		"planning_contract_payload": {"manifest": [{"instance_id": "specimen-a", "species_id": "O01"}]},
		"planning_hold_payload": {"width": 1, "height": 1, "blocked_cells": []},
		"planning_species_by_id": {
			"O01": {
				"name": "Codex Test Species",
				"stress_profile": _stress_profile(),
				"documented_rule": "stress += max(0, heat - heat_safe_max) * stress_per_heat_unit",
			}
		},
		"total_ticks": 1,
		"simulation_defs": _defs(),
		"mandatory_predicates": _predicates(),
		"retry_revision_id": "review-nav-retry",
		"retry_structural_facts": _legal_facts(),
		"reset_revision_id": "review-nav-reset",
		"reset_contract_input": {"route_id": "route-review-nav", "manifest_instance_ids": ["specimen-a"], "placements": [], "supports": [], "seed": 101},
		"reset_structural_facts": _reset_facts(),
	}

func _input() -> Dictionary:
	return {"route_id": "route-review-nav", "manifest_instance_ids": ["specimen-a"], "placements": [{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0}], "supports": [], "seed": 101}

func _defs() -> Dictionary:
	return {"route_profile": {"id": "route-review-nav", "tick_count": 1, "events": []}, "hold_definition": {"dimensions": [1, 1], "blocked_cells": []}, "hazards_by_id": {}, "thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}}, "organism_definitions": {"specimen-a": {"initial_stress": 1, "initial_state": "CALM", "stress_profile": _stress_profile()}}}

func _predicates() -> Array:
	return [{"id": "m-state", "kind": "PRIMARY_STATE_IS", "instance_id": "specimen-a", "value": "CALM"}]

func _legal_facts() -> Dictionary:
	return {"mandatory_manifest_placed": true, "overlap_free": true, "blocked_free": true, "in_bounds": true, "orientations_valid": true, "zones_valid": true, "fixtures_valid": true, "links_valid": true, "support_resources_valid": true, "structural_prerequisites_met": true}

func _reset_facts() -> Dictionary:
	return {"mandatory_manifest_placed": false, "overlap_free": true, "blocked_free": true, "in_bounds": true, "orientations_valid": true, "zones_valid": true, "fixtures_valid": true, "links_valid": true, "support_resources_valid": true, "structural_prerequisites_met": false}

func _stress_profile() -> Dictionary:
	return {"heat_safe_max": 2, "stress_per_heat_unit": 2, "stress_min": 0, "stress_max": 20, "agitated_enter": 5, "agitated_exit": 3, "panic_enter": 10, "panic_exit": 7}

func _clear_store(root_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	for suffix: String in ["session.sav", "session.sav.bak", "session.sav.tmp"]:
		var path: String = root_path.path_join(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(value: bool, label: String) -> void:
	if not value:
		_failures.append(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
