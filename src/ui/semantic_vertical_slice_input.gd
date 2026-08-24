class_name SemanticVerticalSliceInput
extends Node

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const PlanningFocusRouterScript := preload("res://src/ui/planning_focus_router.gd")

var _control: AccessibleVerticalSliceControl
var _flow: VerticalSliceFlowCoordinator
var _router: PlanningFocusRouter
var _manifest_ids: Array[String] = []
var _manifest_focus_index: int = 0

func configure(control: AccessibleVerticalSliceControl, flow: VerticalSliceFlowCoordinator, context: Dictionary) -> Dictionary:
	_control = control
	_flow = flow
	_router = PlanningFocusRouterScript.new()
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
	return {"ok": true, "error": "", "snapshot": snapshot()}

func dispatch(action: StringName) -> Dictionary:
	if _control == null or _flow == null or _router == null:
		return _fail("semantic_input_not_configured")
	if not InputActionCatalogScript.REQUIRED_ACTIONS.has(action):
		return _fail("unknown_semantic_action")
	match _flow.current_state():
		AppStateMachine.State.TITLE, AppStateMachine.State.CAMPAIGN_MAP, AppStateMachine.State.CONTRACT_BRIEF:
			if action == &"accept":
				return _control.activate_primary_action()
		AppStateMachine.State.PLANNING:
			return _dispatch_planning(action)
		AppStateMachine.State.LAUNCH_CONFIRM:
			if action == &"cancel":
				var cancel_result: Dictionary = _control.activate_secondary_action()
				if bool(cancel_result.get("ok", false)):
					_router.exit_modal()
				return cancel_result
			if action == &"accept" or action == &"launch_focus":
				return _control.activate_primary_action()
		AppStateMachine.State.TRANSIT_PLAYBACK:
			if action == &"accept":
				return _control.activate_primary_action()
		AppStateMachine.State.CAUSAL_REVIEW:
			if action == &"accept":
				return _control.activate_primary_action()
	return _fail("action_not_available_in_state")

func snapshot() -> Dictionary:
	return {
		"router": {} if _router == null else _router.snapshot(),
		"manifest_focus_index": _manifest_focus_index,
		"manifest_focus_id": "" if _manifest_ids.is_empty() else _manifest_ids[_manifest_focus_index],
		"state": -1 if _flow == null else _flow.current_state(),
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
	if action == &"inspect":
		return _control.planning_inspect_selected()
	if action == &"rotate":
		return _control.planning_rotate_selected()
	if action == &"remove":
		return _control.planning_remove_selected()

	var region: StringName = _router.current_region()
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

static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
