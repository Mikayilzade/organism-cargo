extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")
const VerticalSliceControlScript := preload("res://src/ui/vertical_slice_control.gd")
const SettingsRemapScreenScript := preload("res://src/ui/settings_remap_screen.gd")
const Phase12ERenderedCriticalSignalAcceptanceScript := preload("res://tests/unit/phase12e_rendered_critical_signal_acceptance.gd")
const Phase12EReviewCodexAcceptanceScript := preload("res://tests/unit/phase12e_review_codex_acceptance.gd")
const Phase12ERecoveryCompletionAcceptanceScript := preload("res://tests/unit/phase12e_recovery_completion_acceptance.gd")
const Phase12EPreflightMatrixAcceptanceScript := preload("res://tests/unit/phase12e_preflight_matrix_acceptance.gd")

var failures: int = 0
var run_sequence: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_path := "user://vertical_slice_control_fixture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	for suffix: String in ["session.sav", "session.sav.bak", "session.sav.tmp"]:
		var path := root_path.path_join(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# Execute the complete player-facing Phase-12E acceptance cluster under the
	# frozen Deck stress target rather than only checking an abstract scale model.
	var previous_window_size: Vector2i = root.size
	var previous_content_scale: float = root.content_scale_factor
	root.size = Vector2i(1280, 800)
	root.content_scale_factor = 2.0
	await process_frame
	_expect(root.size == Vector2i(1280, 800), "rendered closure runs at Deck 1280x800")
	_expect(absf(root.content_scale_factor - 2.0) < 0.001, "rendered closure runs at actual 200 percent Window content scale")

	var state_machine: AppStateMachine = AppStateMachineScript.new()
	_expect(state_machine.transition_to(AppStateMachine.State.TITLE), "boot -> title")
	var store: AtomicSaveStore = AtomicSaveStoreScript.new(root_path)
	var flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(state_machine, store, Callable(self, "_next_run_id"))
	var control: VerticalSliceControl = VerticalSliceControlScript.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	control.custom_minimum_size = Vector2(640, 360)
	root.add_child(control)
	control.configure(flow, _context())
	await process_frame

	_expect_equal(control.state_title(), "Organism Cargo", "title presentation")
	_expect(bool(control.activate_primary_action().get("ok", false)), "title -> campaign map through UI")
	_expect_equal(control.state_title(), "Campaign", "campaign presentation")
	_expect(bool(control.activate_primary_action().get("ok", false)), "campaign -> brief through UI")
	_expect_equal(control.state_title(), "Contract Brief", "brief presentation")
	_expect(bool(control.activate_primary_action().get("ok", false)), "brief -> planning through UI")
	_expect(_control_inside_visible_rect(control.get_node_or_null("PrimaryAction") as Control), "Planning primary action remains on-screen at 1280x800/200 percent")
	_expect(_control_inside_visible_rect(control.get_node_or_null("PlanningPanel") as Control), "Planning panel remains inside the rendered Deck viewport at 200 percent")

	var revision := flow.apply_plan("revision-ui-a", _input(), _legal_facts())
	_expect(bool(revision.get("structural_legal", false)), "legal plan available to presentation")
	_expect(bool(control.activate_primary_action().get("ok", false)), "planning -> launch confirm through UI")
	_expect_equal(control.primary_action_text(), "Launch", "launch is deliberate second action")
	_expect(bool(control.activate_primary_action().get("ok", false)), "launch commit through UI")
	_expect_equal(flow.current_state(), AppStateMachine.State.TRANSIT_PLAYBACK, "UI launch owns transit state")
	_expect(bool(control.activate_primary_action().get("ok", false)), "transit completion through UI")
	_expect_equal(control.state_title(), "Causal Review", "review presentation")
	_expect(bool(control.activate_primary_action().get("ok", false)), "targeted Retry through UI")
	_expect_equal(flow.current_state(), AppStateMachine.State.PLANNING, "UI Retry returns to planning")

	control.queue_free()
	await process_frame
	var acceptance: Phase12ERenderedCriticalSignalAcceptance = Phase12ERenderedCriticalSignalAcceptanceScript.new()
	var rendered_failures: Array[String] = await acceptance.run(self, Callable(self, "_next_run_id"))
	for rendered_failure: String in rendered_failures:
		_expect(false, "Phase12E rendered critical signal acceptance: %s" % rendered_failure)

	var review_codex: Phase12EReviewCodexAcceptance = Phase12EReviewCodexAcceptanceScript.new()
	var review_codex_failures: Array[String] = await review_codex.run(self, Callable(self, "_next_run_id"))
	for review_codex_failure: String in review_codex_failures:
		_expect(false, "Phase12E review/Codex acceptance: %s" % review_codex_failure)

	var recovery_completion: Phase12ERecoveryCompletionAcceptance = Phase12ERecoveryCompletionAcceptanceScript.new()
	var recovery_completion_failures: Array[String] = await recovery_completion.run(self)
	for recovery_completion_failure: String in recovery_completion_failures:
		_expect(false, "Phase12E recovery/completion acceptance: %s" % recovery_completion_failure)

	var preflight_matrix: Phase12EPreflightMatrixAcceptance = Phase12EPreflightMatrixAcceptanceScript.new()
	var preflight_matrix_failures: Array[String] = await preflight_matrix.run(self)
	for preflight_matrix_failure: String in preflight_matrix_failures:
		_expect(false, "Phase12E preflight/matrix acceptance: %s" % preflight_matrix_failure)

	# Controls/remapping has many mandatory rows, so maximum-scale acceptance
	# requires a real scroll container plus independent keyboard/controller recovery.
	var settings: SettingsRemapScreen = SettingsRemapScreenScript.new()
	settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(settings)
	await process_frame
	var settings_snapshot: Dictionary = settings.rendered_snapshot()
	_expect(bool(settings_snapshot.get("keyboard_focusable", false)), "Controls Settings keyboard tab is focusable at 200 percent")
	_expect(bool(settings_snapshot.get("controller_focusable", false)), "Controls Settings controller tab is focusable at 200 percent")
	_expect(bool(settings_snapshot.get("reset_focusable", false)), "Controls Settings reset remains reachable at 200 percent")
	_expect(bool(settings_snapshot.get("close_focusable", false)), "Controls Settings close remains reachable at 200 percent")
	_expect(_contains_scroll_container(settings), "Controls Settings uses a real scroll container for mandatory remap rows at maximum scale")
	settings.focus_entry()
	await process_frame
	_expect(root.gui_get_focus_owner() != null, "Controls Settings keeps a keyboard/controller focus owner at maximum scale")
	settings.queue_free()
	await process_frame

	root.content_scale_factor = previous_content_scale
	root.size = previous_window_size
	await process_frame

	if failures == 0:
		print("vertical_slice_control_test_runner: PASS")
		quit(0)
	else:
		push_error("vertical_slice_control_test_runner: %d failure(s)" % failures)
		quit(1)

func _context() -> Dictionary:
	return {
		"launch_request_token": "launch-ui-a",
		"profile_uuid": "profile-ui",
		"contract_id": "VS01",
		"rules_version": "rules-r1",
		"content_version": "vertical-slice-test-1",
		"contract_definition_checksum": "vs01-definition-checksum",
		"total_ticks": 1,
		"simulation_defs": {
			"route_profile": {"id": "route-ui", "tick_count": 1, "events": []},
			"hold_definition": {"dimensions": [2, 2], "blocked_cells": []},
			"hazards_by_id": {},
			"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
			"organism_definitions": {
				"specimen-a": {"initial_stress": 1, "initial_state": "CALM", "stress_profile": _stress_profile()},
				"specimen-b": {"initial_stress": 1, "initial_state": "CALM", "stress_profile": _stress_profile()},
			},
		},
		"mandatory_predicates": [{"id": "m-state", "kind": "PRIMARY_STATE_IS", "instance_id": "specimen-a", "value": "CALM"}],
		"retry_revision_id": "revision-ui-b",
		"retry_structural_facts": _legal_facts(),
	}

func _input() -> Dictionary:
	return {
		"route_id": "route-ui",
		"manifest_instance_ids": ["specimen-a", "specimen-b"],
		"placements": [
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			{"instance_id": "specimen-b", "anchor": [1, 1], "orientation": 0},
		],
		"supports": [],
		"seed": 101,
	}

func _legal_facts() -> Dictionary:
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

func _stress_profile() -> Dictionary:
	return {
		"heat_safe_max": 2,
		"stress_per_heat_unit": 2,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 5,
		"agitated_exit": 3,
		"panic_enter": 10,
		"panic_exit": 7,
	}

func _control_inside_visible_rect(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	return root.get_visible_rect().encloses(control.get_global_rect())

func _contains_scroll_container(node: Node) -> bool:
	if node is ScrollContainer:
		return true
	for child: Node in node.get_children():
		if _contains_scroll_container(child):
			return true
	return false

func _next_run_id() -> String:
	run_sequence += 1
	return "run-ui-%d" % run_sequence

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
