class_name InputActionCatalog
extends RefCounted

const DEVICE_KEYBOARD: StringName = &"keyboard"
const DEVICE_CONTROLLER: StringName = &"controller"

const REQUIRED_ACTIONS: Array[StringName] = [
	&"navigate_up", &"navigate_down", &"navigate_left", &"navigate_right", &"accept", &"cancel", &"inspect", &"rotate", &"remove",
	&"region_next", &"region_previous", &"overlay_next", &"overlay_previous", &"undo", &"redo", &"launch_focus", &"pause_playback",
	&"speed_up", &"speed_down", &"tick_step", &"review_event_previous", &"review_event_next", &"jump_failed_predicate", &"jump_root_cause",
	&"compare_start_final", &"panel_next", &"panel_previous",
]

const PLANNING_FOCUS_REGIONS: Array[StringName] = [&"MANIFEST", &"HOLD", &"INSPECTOR", &"ROUTE", &"OBJECTIVES_SUPPORTS", &"TOOLBAR"]

const KEYBOARD_DEFAULT_LABELS: Dictionary = {
	&"navigate_up": "Up Arrow", &"navigate_down": "Down Arrow", &"navigate_left": "Left Arrow", &"navigate_right": "Right Arrow",
	&"accept": "Enter", &"cancel": "Escape", &"inspect": "I", &"rotate": "R", &"remove": "Delete", &"region_next": "Tab",
	&"region_previous": "Shift+Tab", &"overlay_next": "]", &"overlay_previous": "[", &"undo": "Ctrl+Z", &"redo": "Ctrl+Y",
	&"launch_focus": "Space", &"pause_playback": "Space", &"speed_up": "]", &"speed_down": "[", &"tick_step": ".",
	&"review_event_previous": "Page Up", &"review_event_next": "Page Down", &"jump_failed_predicate": "F", &"jump_root_cause": "J",
	&"compare_start_final": "C", &"panel_next": "E", &"panel_previous": "Q",
}

const CONTROLLER_DEFAULT_LABELS: Dictionary = {
	&"navigate_up": "D-pad Up", &"navigate_down": "D-pad Down", &"navigate_left": "D-pad Left", &"navigate_right": "D-pad Right",
	&"accept": "South / A", &"cancel": "East / B", &"inspect": "North / Y", &"rotate": "West / X", &"remove": "Right Stick Click",
	&"region_next": "Right Shoulder", &"region_previous": "Left Shoulder", &"overlay_next": "Right Trigger", &"overlay_previous": "Left Trigger",
	&"undo": "Left Stick Click", &"redo": "Back / View", &"launch_focus": "Start / Menu", &"pause_playback": "South / A",
	&"speed_up": "Right Shoulder", &"speed_down": "Left Shoulder", &"tick_step": "West / X", &"review_event_previous": "Left Shoulder",
	&"review_event_next": "Right Shoulder", &"jump_failed_predicate": "West / X", &"jump_root_cause": "North / Y", &"compare_start_final": "Back / View",
	&"panel_next": "Right Trigger", &"panel_previous": "Left Trigger",
}

static func validate_required_actions(actions: Array[StringName]) -> bool:
	var seen: Dictionary = {}
	for action: StringName in actions:
		if String(action).strip_edges().is_empty() or seen.has(action): return false
		seen[action] = true
	for required: StringName in REQUIRED_ACTIONS:
		if not seen.has(required): return false
	return true

static func is_valid_focus_region(region: StringName) -> bool:
	return PLANNING_FOCUS_REGIONS.has(region)

static func default_binding_labels(device: StringName) -> Dictionary:
	match device:
		DEVICE_KEYBOARD: return KEYBOARD_DEFAULT_LABELS.duplicate(true)
		DEVICE_CONTROLLER: return CONTROLLER_DEFAULT_LABELS.duplicate(true)
	return {}

static func validate_default_device_profile(device: StringName) -> bool:
	var labels: Dictionary = default_binding_labels(device)
	if labels.size() != REQUIRED_ACTIONS.size(): return false
	for action: StringName in REQUIRED_ACTIONS:
		if not labels.has(action) or String(labels[action]).strip_edges().is_empty(): return false
	return true

static func ensure_registered() -> void:
	for action: StringName in REQUIRED_ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		if not _has_keyboard_event(action):
			var keyboard_event: InputEventKey = _keyboard_event(action)
			if keyboard_event != null: InputMap.action_add_event(action, keyboard_event)
		if not _has_controller_event(action):
			var controller_event: InputEvent = _controller_event(action)
			if controller_event != null: InputMap.action_add_event(action, controller_event)

static func device_for_event(event: InputEvent) -> StringName:
	if event is InputEventKey: return DEVICE_KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion: return DEVICE_CONTROLLER
	return &""

static func physical_label_for_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var base := _keyboard_key_label(key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode)
		var prefix := ""
		if key_event.ctrl_pressed: prefix += "Ctrl+"
		if key_event.alt_pressed: prefix += "Alt+"
		if key_event.shift_pressed: prefix += "Shift+"
		if key_event.meta_pressed: prefix += "Meta+"
		return prefix + base
	if event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			0: return "South / A"
			1: return "East / B"
			2: return "West / X"
			3: return "North / Y"
			4: return "Back / View"
			6: return "Start / Menu"
			7: return "Left Stick Click"
			8: return "Right Stick Click"
			9: return "Left Shoulder"
			10: return "Right Shoulder"
			11: return "D-pad Up"
			12: return "D-pad Down"
			13: return "D-pad Left"
			14: return "D-pad Right"
		return "Controller Button %d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == 4: return "Left Trigger"
		if motion.axis == 5: return "Right Trigger"
		return "Controller Axis %d %s" % [motion.axis, "+" if motion.axis_value >= 0.0 else "-"]
	return ""

static func apply_binding_event(device: StringName, action: StringName, event: InputEvent) -> Dictionary:
	if not REQUIRED_ACTIONS.has(action): return {"ok": false, "error": "unknown_action"}
	if device_for_event(event) != device: return {"ok": false, "error": "wrong_device"}
	if not InputMap.has_action(action): InputMap.add_action(action)
	for existing: InputEvent in InputMap.action_get_events(action).duplicate():
		if device_for_event(existing) == device: InputMap.action_erase_event(action, existing)
	var copy: InputEvent = event.duplicate()
	InputMap.action_add_event(action, copy)
	return {"ok": true, "error": "", "device": device, "action": action, "binding": physical_label_for_event(event)}

static func reset_device_in_input_map(device: StringName) -> Dictionary:
	if device != DEVICE_KEYBOARD and device != DEVICE_CONTROLLER: return {"ok": false, "error": "unknown_device"}
	for action: StringName in REQUIRED_ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for existing: InputEvent in InputMap.action_get_events(action).duplicate():
			if device_for_event(existing) == device: InputMap.action_erase_event(action, existing)
		var default_event: InputEvent = _keyboard_event(action) if device == DEVICE_KEYBOARD else _controller_event(action)
		if default_event != null: InputMap.action_add_event(action, default_event)
	return {"ok": true, "error": "", "device": device}

static func _keyboard_key_label(keycode: int) -> String:
	match keycode:
		KEY_UP: return "Up Arrow"
		KEY_DOWN: return "Down Arrow"
		KEY_LEFT: return "Left Arrow"
		KEY_RIGHT: return "Right Arrow"
		KEY_ENTER: return "Enter"
		KEY_ESCAPE: return "Escape"
		KEY_DELETE: return "Delete"
		KEY_TAB: return "Tab"
		KEY_SPACE: return "Space"
		KEY_BRACKETRIGHT: return "]"
		KEY_BRACKETLEFT: return "["
		KEY_PERIOD: return "."
		KEY_PAGEUP: return "Page Up"
		KEY_PAGEDOWN: return "Page Down"
	return OS.get_keycode_string(keycode)

static func _has_keyboard_event(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey: return true
	return false

static func _has_controller_event(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion: return true
	return false

static func _keyboard_event(action: StringName) -> InputEventKey:
	match action:
		&"navigate_up": return _key(KEY_UP)
		&"navigate_down": return _key(KEY_DOWN)
		&"navigate_left": return _key(KEY_LEFT)
		&"navigate_right": return _key(KEY_RIGHT)
		&"accept": return _key(KEY_ENTER)
		&"cancel": return _key(KEY_ESCAPE)
		&"inspect": return _key(KEY_I)
		&"rotate": return _key(KEY_R)
		&"remove": return _key(KEY_DELETE)
		&"region_next": return _key(KEY_TAB)
		&"region_previous": return _key(KEY_TAB, false, true)
		&"overlay_next": return _key(KEY_BRACKETRIGHT)
		&"overlay_previous": return _key(KEY_BRACKETLEFT)
		&"undo": return _key(KEY_Z, true)
		&"redo": return _key(KEY_Y, true)
		&"launch_focus": return _key(KEY_SPACE)
		&"pause_playback": return _key(KEY_SPACE)
		&"speed_up": return _key(KEY_BRACKETRIGHT)
		&"speed_down": return _key(KEY_BRACKETLEFT)
		&"tick_step": return _key(KEY_PERIOD)
		&"review_event_previous": return _key(KEY_PAGEUP)
		&"review_event_next": return _key(KEY_PAGEDOWN)
		&"jump_failed_predicate": return _key(KEY_F)
		&"jump_root_cause": return _key(KEY_J)
		&"compare_start_final": return _key(KEY_C)
		&"panel_next": return _key(KEY_E)
		&"panel_previous": return _key(KEY_Q)
	return null

static func _controller_event(action: StringName) -> InputEvent:
	match action:
		&"navigate_up": return _joy_button(11)
		&"navigate_down": return _joy_button(12)
		&"navigate_left": return _joy_button(13)
		&"navigate_right": return _joy_button(14)
		&"accept": return _joy_button(0)
		&"cancel": return _joy_button(1)
		&"inspect": return _joy_button(3)
		&"rotate": return _joy_button(2)
		&"remove": return _joy_button(8)
		&"region_next": return _joy_button(10)
		&"region_previous": return _joy_button(9)
		&"overlay_next": return _joy_axis(5)
		&"overlay_previous": return _joy_axis(4)
		&"undo": return _joy_button(7)
		&"redo": return _joy_button(4)
		&"launch_focus": return _joy_button(6)
		&"pause_playback": return _joy_button(0)
		&"speed_up": return _joy_button(10)
		&"speed_down": return _joy_button(9)
		&"tick_step": return _joy_button(2)
		&"review_event_previous": return _joy_button(9)
		&"review_event_next": return _joy_button(10)
		&"jump_failed_predicate": return _joy_button(2)
		&"jump_root_cause": return _joy_button(3)
		&"compare_start_final": return _joy_button(4)
		&"panel_next": return _joy_axis(5)
		&"panel_previous": return _joy_axis(4)
	return null

static func _key(keycode: int, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new(); event.physical_keycode = keycode; event.ctrl_pressed = ctrl; event.shift_pressed = shift; return event

static func _joy_button(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new(); event.button_index = button_index; return event

static func _joy_axis(axis_index: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new(); event.axis = axis_index; event.axis_value = 1.0; return event
