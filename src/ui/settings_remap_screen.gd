class_name SettingsRemapScreen
extends Control

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const InputRemapModelScript := preload("res://src/ui/input_remap_model.gd")

signal device_changed(device: StringName)
signal binding_changed(device: StringName, action: StringName, binding: String)
signal remap_feedback(message: String)

var _model: InputRemapModel
var _active_device: StringName = InputActionCatalogScript.DEVICE_KEYBOARD
var _last_input_device: StringName = InputActionCatalogScript.DEVICE_KEYBOARD
var _rows: Dictionary = {}
var _device_title: Label
var _feedback: Label
var _recovery: Label
var _list: VBoxContainer
var _keyboard_button: Button
var _controller_button: Button
var _reset_button: Button

func _init(model: InputRemapModel = null) -> void:
	_model = model if model != null else InputRemapModelScript.new()

func _ready() -> void:
	if _list == null:
		_build_widgets()
	_refresh()

func model() -> InputRemapModel:
	return _model

func active_device() -> StringName:
	return _active_device

func last_input_device() -> StringName:
	return _last_input_device

func set_active_device(device: StringName) -> Dictionary:
	if device != InputActionCatalogScript.DEVICE_KEYBOARD and device != InputActionCatalogScript.DEVICE_CONTROLLER:
		return {"ok": false, "error": "unknown_device"}
	_active_device = device
	_refresh()
	device_changed.emit(device)
	return {"ok": true, "error": "", "device": device}

func note_input_source(device: StringName) -> Dictionary:
	if device != InputActionCatalogScript.DEVICE_KEYBOARD and device != InputActionCatalogScript.DEVICE_CONTROLLER:
		return {"ok": false, "error": "unknown_device"}
	_last_input_device = device
	# Instructions follow the most recent input source without hiding text labels.
	set_active_device(device)
	return {"ok": true, "error": "", "device": device}

func propose_binding(action: StringName, physical_label: String) -> Dictionary:
	var result: Dictionary = _model.propose_binding(_active_device, action, physical_label)
	if bool(result.get("ok", false)):
		var explanation: String = "Binding saved."
		var reused: Variant = result.get("mutually_exclusive_reuse", [])
		if bool(result.get("explanation_required", false)) and reused is Array:
			explanation = "Binding saved; reused only in mutually exclusive context(s): %s." % _join_actions(reused as Array)
		_set_feedback(explanation)
		_refresh()
		binding_changed.emit(_active_device, action, String(result.get("binding", "")))
		return result
	var error: String = String(result.get("error", "unknown_error"))
	if error == "binding_conflict":
		_set_feedback("Conflict: this control is already required by %s in an overlapping context. Choose another control." % _human_action(StringName(result.get("conflicts_with", &""))))
	elif error == "accept_cancel_recovery_conflict":
		_set_feedback("Conflict: Accept and Cancel must remain different so this device can always recover from remapping.")
	else:
		_set_feedback("Binding not saved: %s." % error.replace("_", " "))
	return result

func reset_active_device() -> Dictionary:
	var result: Dictionary = _model.reset_device(_active_device)
	if bool(result.get("ok", false)):
		_set_feedback("%s bindings reset to defaults." % _device_name(_active_device))
		_refresh()
	return result

func recovery_snapshot() -> Dictionary:
	return _model.recovery_contract(_active_device)

func row_text(action: StringName) -> String:
	if not _rows.has(action):
		return ""
	var row: Label = _rows[action]
	return row.text

func rendered_snapshot() -> Dictionary:
	var rows: Dictionary = {}
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		rows[String(action)] = row_text(action)
	return {
		"active_device": _active_device,
		"last_input_device": _last_input_device,
		"device_title": _device_title.text if _device_title != null else "",
		"feedback": _feedback.text if _feedback != null else "",
		"recovery": _recovery.text if _recovery != null else "",
		"rows": rows,
		"keyboard_focusable": _keyboard_button != null and _keyboard_button.focus_mode == Control.FOCUS_ALL,
		"controller_focusable": _controller_button != null and _controller_button.focus_mode == Control.FOCUS_ALL,
		"reset_focusable": _reset_button != null and _reset_button.focus_mode == Control.FOCUS_ALL,
	}

func _build_widgets() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var heading := Label.new()
	heading.text = "Settings — Controls"
	heading.add_theme_font_size_override("font_size", 24)
	root.add_child(heading)

	_device_title = Label.new()
	_device_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_device_title)

	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	_keyboard_button = Button.new()
	_keyboard_button.text = "Keyboard"
	_keyboard_button.focus_mode = Control.FOCUS_ALL
	_keyboard_button.pressed.connect(func() -> void: set_active_device(InputActionCatalogScript.DEVICE_KEYBOARD))
	tabs.add_child(_keyboard_button)
	_controller_button = Button.new()
	_controller_button.text = "Controller"
	_controller_button.focus_mode = Control.FOCUS_ALL
	_controller_button.pressed.connect(func() -> void: set_active_device(InputActionCatalogScript.DEVICE_CONTROLLER))
	tabs.add_child(_controller_button)
	_reset_button = Button.new()
	_reset_button.text = "Reset bindings to default"
	_reset_button.focus_mode = Control.FOCUS_ALL
	_reset_button.pressed.connect(func() -> void: reset_active_device())
	tabs.add_child(_reset_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.focus_mode = Control.FOCUS_ALL
		row.tooltip_text = "Activate remap for %s, then provide a control from the same device." % _human_action(action)
		_rows[action] = row
		_list.add_child(row)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.text = "Select a device and action. Conflicts are checked before saving."
	root.add_child(_feedback)
	_recovery = Label.new()
	_recovery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_recovery)

func _refresh() -> void:
	if _list == null:
		return
	var marker: String = "[KB]" if _active_device == InputActionCatalogScript.DEVICE_KEYBOARD else "[PAD]"
	_device_title.text = "%s %s controls — glyph marker plus text is always shown." % [marker, _device_name(_active_device)]
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		var row: Label = _rows[action]
		row.text = "%s  %s  —  %s" % [marker, _human_action(action), _model.binding(_active_device, action)]
	var recovery: Dictionary = _model.recovery_contract(_active_device)
	_recovery.text = "Recovery on this device: Accept = %s · Cancel = %s · %s" % [
		String(recovery.get("accept_binding", "")),
		String(recovery.get("cancel_binding", "")),
		"ready" if bool(recovery.get("recoverable", false)) else "BLOCKED",
	]
	_keyboard_button.disabled = _active_device == InputActionCatalogScript.DEVICE_KEYBOARD
	_controller_button.disabled = _active_device == InputActionCatalogScript.DEVICE_CONTROLLER

func _set_feedback(message: String) -> void:
	if _feedback != null:
		_feedback.text = message
	remap_feedback.emit(message)

static func _device_name(device: StringName) -> String:
	return "Keyboard" if device == InputActionCatalogScript.DEVICE_KEYBOARD else "Controller"

static func _human_action(action: StringName) -> String:
	return String(action).replace("_", " ").capitalize()

static func _join_actions(actions: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for action: Variant in actions:
		names.append(_human_action(StringName(action)))
	return ", ".join(names)
