class_name SemanticVerticalSliceInput
extends Node

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const PlanningFocusRouterScript := preload("res://src/ui/planning_focus_router.gd")
const PlanningSupportConfigModelScript := preload("res://src/ui/planning_support_config_model.gd")
const TransitReviewNavigationModelScript := preload("res://src/ui/transit_review_navigation_model.gd")
const PHASE12E_NAVIGATION_SURFACE_PATH := "res://src/ui/phase12e_navigation_surface.gd"

var _control: AccessibleVerticalSliceControl
var _flow: VerticalSliceFlowCoordinator
var _router: PlanningFocusRouter
var _support_config: PlanningSupportConfigModel
var _transit_review: TransitReviewNavigationModel
var _navigation_surface: Object
var _manifest_ids: Array[String] = []
var _manifest_focus_index: int = 0

func configure(control: AccessibleVerticalSliceControl, flow: VerticalSliceFlowCoordinator, context: Dictionary) -> Dictionary:
	_control = control
	_flow = flow
	_router = PlanningFocusRouterScript.new()
	_support_config = PlanningSupportConfigModelScript.new()
	_transit_review = TransitReviewNavigationModelScript.new()
	var hold_value: Variant = context.get("planning_hold_payload", {})
	if typeof(hold_value) == TYPE_DICTIONARY:
		var hold: Dictionary = hold_value
		var configured: Dictionary = _router.configure_hold(int(hold.get("width", 1)), int(hold.get("height", 1)))
		if not bool(configured.get("ok", false)):
			return configured
	_manifest_ids.clear()
	var contract_value: Variant = context.get("planning_contract_payload", {})
	if typeof(contract_value) == TYPE_DICTIONARY:
		var contract: Dictionary = contract_value
		var manifest_value: Variant = contract.get("manifest", [])
		if typeof(manifest_value) == TYPE_ARRAY:
			for raw_entry: Variant in manifest_value:
				if typeof(raw_entry) == TYPE_DICTIONARY:
					var instance_id: String = String((raw_entry as Dictionary).get("instance_id", ""))
					if not instance_id.is_empty():
						_manifest_ids.append(instance_id)
	_manifest_focus_index = 0
	var support_definitions: Variant = context.get("planning_support_definitions", [])
	if typeof(support_definitions) == TYPE_DICTIONARY:
		support_definitions = (support_definitions as Dictionary).get("definitions", [])
	var support_targets: Variant = context.get("planning_support_targets", _manifest_ids)
	var support_configured: Dictionary = _support_config.configure(support_definitions, support_targets)
	if not bool(support_configured.get("ok", false)):
		return support_configured
	var transit_configured: Dictionary = _transit_review.configure_transit(context)
	if not bool(transit_configured.get("ok", false)):
		return transit_configured
	_navigation_surface = _new_navigation_surface()
	if _navigation_surface == null or not _navigation_surface is Control or not _navigation_surface.has_method("configure"):
		return _fail("phase12e_navigation_surface_unavailable")
	_control.add_child(_navigation_surface as Control)
	var nav_configured_value: Variant = _navigation_surface.call("configure", _control, _flow, context)
	if not nav_configured_value is Dictionary or not bool((nav_configured_value as Dictionary).get("ok", false)):
		return _fail("phase12e_navigation_surface_configure_failed")
	_render_planning_semantics()
	return {"ok": true, "error": "", "snapshot": snapshot()}

func dispatch(action: StringName) -> Dictionary:
	if _control == null or _flow == null or _router == null or _support_config == null or _transit_review == null:
		return _fail("semantic_input_not_configured")
	if not InputActionCatalogScript.REQUIRED_ACTIONS.has(action):
		return _fail("unknown_semantic_action")
	var result: Dictionary = _fail("action_not_available_in_state")
	match _flow.current_state():
		AppStateMachine.State.TITLE, AppStateMachine.State.CAMPAIGN_MAP, AppStateMachine.State.CONTRACT_BRIEF:
			if action == &"accept":
				result = _control.activate_primary_action()
			elif action == &"inspect":
				result = _navigation_call("open_codex")
		AppStateMachine.State.PLANNING:
			result = _dispatch_planning(action)
		AppStateMachine.State.LAUNCH_CONFIRM:
			if action == &"cancel":
				var cancel_result: Dictionary = _control.activate_secondary_action()
				if bool(cancel_result.get("ok", false)):
					_router.exit_modal()
				result = cancel_result
			elif action == &"accept" or action == &"launch_focus":
				result = _control.activate_primary_action()
		AppStateMachine.State.TRANSIT_PLAYBACK:
			result = _dispatch_transit(action)
		AppStateMachine.State.CAUSAL_REVIEW:
			result = _dispatch_review(action)
		AppStateMachine.State.CODEX:
			result = _dispatch_codex(action)
	if _flow.current_state() == AppStateMachine.State.PLANNING:
		_render_planning_semantics()
	_sync_navigation_surface()
	return result

func snapshot() -> Dictionary:
	return {
		"router": {} if _router == null else _router.snapshot(),
		"manifest_focus_index": _manifest_focus_index,
		"manifest_focus_id": "" if _manifest_ids.is_empty() else _manifest_ids[_manifest_focus_index],
		"support_config": {} if _support_config == null else _support_config.snapshot(),
		"state": -1 if _flow == null else _flow.current_state(),
		"transit": {} if _transit_review == null else _transit_review.transit_snapshot(),
		"review": {} if _transit_review == null else _transit_review.review_snapshot(),
		"review_exit_action": &"" if _navigation_surface == null or not _navigation_surface.has_method("selected_review_action") else _navigation_surface.call("selected_review_action"),
	}

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		if event.is_action_pressed(action):
			var result: Dictionary = dispatch(action)
			if bool(result.get("ok", false)):
				get_viewport().set_input_as_handled()
				return

func _dispatch_planning(action: StringName) -> Dictionary:
	if action == &"region_next" or action == &"region_previous":
		return _router.semantic_request(action)
	if action == &"launch_focus":
		var launch_result: Dictionary = _control.activate_primary_action()
		if bool(launch_result.get("ok", false)):
			_router.enter_modal(&"TOOLBAR")
		return launch_result
	if action == &"cancel":
		return _control.planning_clear_selection()
	if action == &"rotate":
		return _control.planning_rotate_selected()
	if action == &"remove":
		return _control.planning_remove_selected()
	if action == &"inspect" and _router.current_region() == &"TOOLBAR":
		return _navigation_call("open_codex")

	var region: StringName = _router.current_region()
	if region == &"OBJECTIVES_SUPPORTS" and _support_config.has_supports():
		if action in [&"navigate_up", &"navigate_down", &"navigate_left", &"navigate_right", &"accept", &"overlay_previous", &"overlay_next", &"inspect"]:
			return _support_config.command(action)
	if action == &"inspect":
		return _control.planning_inspect_selected()
	if action in [&"navigate_up", &"navigate_down", &"navigate_left", &"navigate_right"]:
		if region == &"HOLD":
			var before: Dictionary = _router.snapshot()
			var moved: Dictionary = _router.semantic_request(action)
			if not bool(moved.get("ok", false)):
				return moved
			var old_focus: Array = before.get("hold_focus", [0, 0])
			var new_focus: Array = moved.get("focus", old_focus)
			return _control.planning_move_focus(int(new_focus[0]) - int(old_focus[0]), int(new_focus[1]) - int(old_focus[1]))
		if region == &"MANIFEST":
			return _move_manifest_focus(action)
		return _router.semantic_request(action)
	if action == &"accept":
		if region == &"MANIFEST":
			if _manifest_ids.is_empty():
				return _fail("manifest_empty")
			return _control.planning_select_manifest(_manifest_ids[_manifest_focus_index])
		if region == &"HOLD":
			return _control.planning_activate_focused_cell()
		return _router.semantic_request(action)
	return _router.semantic_request(action)

func _dispatch_transit(action: StringName) -> Dictionary:
	if action == &"accept":
		var completed: Dictionary = _control.activate_primary_action()
		if bool(completed.get("ok", false)) and _flow.current_state() == AppStateMachine.State.CAUSAL_REVIEW:
			var configured: Dictionary = _transit_review.configure_review(_flow.last_review())
			if not bool(configured.get("ok", false)):
				return configured
		return completed
	if action in [
		&"pause_playback", &"speed_up", &"speed_down", &"tick_step",
		&"navigate_up", &"navigate_down", &"navigate_left", &"navigate_right",
		&"region_next", &"region_previous", &"panel_next", &"panel_previous", &"inspect"
	]:
		return _transit_review.transit_command(action)
	return _fail("action_not_available_in_transit")

func _dispatch_review(action: StringName) -> Dictionary:
	var ensure_result: Dictionary = _ensure_review_configured()
	if not bool(ensure_result.get("ok", false)):
		return ensure_result
	if action == &"accept":
		return _navigation_call("review_activate_selected")
	if action == &"navigate_left":
		return _navigation_call("review_move", -1)
	if action == &"navigate_right":
		return _navigation_call("review_move", 1)
	if action == &"cancel":
		return _flow.return_to_campaign_map()
	if action == &"inspect":
		return _navigation_call("open_codex")
	if action in [
		&"review_event_previous", &"review_event_next", &"jump_failed_predicate", &"jump_root_cause",
		&"compare_start_final", &"panel_next", &"panel_previous", &"region_next", &"region_previous"
	]:
		return _transit_review.review_command(action)
	return _fail("action_not_available_in_review")

func _dispatch_codex(action: StringName) -> Dictionary:
	if action == &"cancel" or action == &"accept":
		return _navigation_call("close_codex")
	if action == &"navigate_up" or action == &"panel_previous":
		return _navigation_call("codex_scroll", -1)
	if action == &"navigate_down" or action == &"panel_next":
		return _navigation_call("codex_scroll", 1)
	return _fail("action_not_available_in_codex")

func _ensure_review_configured() -> Dictionary:
	var review_snapshot: Dictionary = _transit_review.review_snapshot()
	if int(review_snapshot.get("event_count", 0)) > 0:
		return {"ok": true, "error": ""}
	var review: Dictionary = _flow.last_review()
	if review.is_empty():
		return _fail("review_not_available")
	return _transit_review.configure_review(review)

func _move_manifest_focus(action: StringName) -> Dictionary:
	if _manifest_ids.is_empty():
		return _fail("manifest_empty")
	var direction: int = -1 if action == &"navigate_left" or action == &"navigate_up" else 1
	_manifest_focus_index = posmod(_manifest_focus_index + direction, _manifest_ids.size())
	return {
		"ok": true,
		"error": "",
		"region": &"MANIFEST",
		"manifest_focus_id": _manifest_ids[_manifest_focus_index],
	}

func _render_planning_semantics() -> void:
	if _control == null or _router == null or _support_config == null:
		return
	_control.planning_render_semantic_state(_router.snapshot(), _support_config.snapshot(), "" if _manifest_ids.is_empty() else _manifest_ids[_manifest_focus_index])

func _new_navigation_surface() -> Object:
	var script: GDScript = load(PHASE12E_NAVIGATION_SURFACE_PATH) as GDScript
	return null if script == null else script.new()

func _navigation_call(method: StringName, arg: Variant = null) -> Dictionary:
	if _navigation_surface == null or not _navigation_surface.has_method(method):
		return _fail("phase12e_navigation_surface_unavailable")
	var value: Variant = _navigation_surface.call(method) if arg == null else _navigation_surface.call(method, arg)
	if not value is Dictionary:
		return _fail("phase12e_navigation_surface_invalid_result")
	return value

func _sync_navigation_surface() -> void:
	if _navigation_surface != null and _navigation_surface.has_method("sync_from_flow"):
		_navigation_surface.call("sync_from_flow")

static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
