class_name SettingsRemapScreen
extends Control

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const InputRemapModelScript := preload("res://src/ui/input_remap_model.gd")
const InputBindingsStoreScript := preload("res://src/ui/input_bindings_store.gd")

signal device_changed(device: StringName)
signal binding_changed(device: StringName, action: StringName, binding: String)
signal remap_feedback(message: String)
signal close_requested()

var _model: InputRemapModel
var _bindings_store: Variant
var _last_persistence_result: Dictionary = {}
var _active_device: StringName = InputActionCatalogScript.DEVICE_KEYBOARD
var _last_input_device: StringName = InputActionCatalogScript.DEVICE_KEYBOARD
var _capture_action: StringName = &""
var _rows: Dictionary = {}
var _device_title: Label
var _feedback: Label
var _recovery: Label
var _list: VBoxContainer
var _keyboard_button: Button
var _controller_button: Button
var _reset_button: Button
var _close_button: Button

func _init(model: InputRemapModel = null, bindings_store: Variant = null) -> void:
	_model = model if model != null else InputRemapModelScript.new()
	_bindings_store = bindings_store if bindings_store != null else InputBindingsStoreScript.new()

func _ready() -> void:
	if _list == null: _build_widgets()
	InputActionCatalogScript.ensure_registered()
	_last_persistence_result = _bindings_store.load_into(_model)
	if bool(_last_persistence_result.get("recovered", false)):
		_set_feedback("Local control settings were invalid for: %s. Only those bindings were reset to defaults; campaign progress was not touched." % ", ".join(PackedStringArray(_last_persistence_result.get("recovered_devices", []))))
	elif not bool(_last_persistence_result.get("ok", false)):
		_set_feedback("Local control settings could not be loaded. Default bindings remain available.")
	_refresh()

func model() -> InputRemapModel: return _model
func active_device() -> StringName: return _active_device
func last_input_device() -> StringName: return _last_input_device
func capture_action() -> StringName: return _capture_action
func persistence_snapshot() -> Dictionary: return _last_persistence_result.duplicate(true)

func set_active_device(device: StringName) -> Dictionary:
	if device != InputActionCatalogScript.DEVICE_KEYBOARD and device != InputActionCatalogScript.DEVICE_CONTROLLER: return {"ok": false, "error": "unknown_device"}
	_active_device = device; _capture_action = &""; _refresh(); device_changed.emit(device)
	return {"ok": true, "error": "", "device": device}

func note_input_source(device: StringName) -> Dictionary:
	if device != InputActionCatalogScript.DEVICE_KEYBOARD and device != InputActionCatalogScript.DEVICE_CONTROLLER: return {"ok": false, "error": "unknown_device"}
	_last_input_device = device; set_active_device(device)
	return {"ok": true, "error": "", "device": device}

func note_input_event(event: InputEvent) -> Dictionary:
	var device: StringName = InputActionCatalogScript.device_for_event(event)
	if device == &"": return {"ok": false, "error": "unsupported_input"}
	return note_input_source(device)

func begin_capture(action: StringName) -> Dictionary:
	if not InputActionCatalogScript.REQUIRED_ACTIONS.has(action): return {"ok": false, "error": "unknown_action"}
	_capture_action = action
	_set_feedback("Listening on %s for %s. Press a control on this same device; Cancel exits capture." % [_device_name(_active_device), _human_action(action)])
	_refresh(); return {"ok": true, "error": "", "action": action, "device": _active_device}

func cancel_capture() -> Dictionary:
	if _capture_action == &"": return {"ok": false, "error": "not_capturing"}
	var cancelled := _capture_action; _capture_action = &""; _set_feedback("Remap cancelled for %s." % _human_action(cancelled)); _refresh()
	return {"ok": true, "error": "", "action": cancelled}

func capture_event(event: InputEvent) -> Dictionary:
	if _capture_action == &"": return {"ok": false, "error": "not_capturing"}
	var device: StringName = InputActionCatalogScript.device_for_event(event)
	if device != _active_device:
		_set_feedback("Use a %s control for this remap; the other device is never required." % _device_name(_active_device))
		return {"ok": false, "error": "wrong_device"}
	var label: String = InputActionCatalogScript.physical_label_for_event(event)
	if label.is_empty(): return {"ok": false, "error": "unsupported_input"}
	var action := _capture_action
	var proposed: Dictionary = propose_binding(action, label)
	if not bool(proposed.get("ok", false)): return proposed
	var applied: Dictionary = InputActionCatalogScript.apply_binding_event(_active_device, action, event)
	if not bool(applied.get("ok", false)):
		_set_feedback("Binding model updated but InputMap application failed: %s." % String(applied.get("error", "unknown_error")))
		return applied
	_last_persistence_result = _bindings_store.save(_model)
	if not bool(_last_persistence_result.get("ok", false)):
		_set_feedback("Binding is active for this session but device-local save failed: %s." % String(_last_persistence_result.get("error", "unknown_error")))
		return {"ok": false, "error": "settings_save_failed", "detail": _last_persistence_result}
	_capture_action = &""; _set_feedback("%s bound to %s on %s and saved on this device." % [_human_action(action), label, _device_name(_active_device)]); _refresh()
	return {"ok": true, "error": "", "device": _active_device, "action": action, "binding": label, "durable": true}

func propose_binding(action: StringName, physical_label: String) -> Dictionary:
	var result: Dictionary = _model.propose_binding(_active_device, action, physical_label)
	if bool(result.get("ok", false)):
		var explanation := "Binding accepted."
		var reused: Variant = result.get("mutually_exclusive_reuse", [])
		if bool(result.get("explanation_required", false)) and reused is Array: explanation = "Binding accepted; reused only in mutually exclusive context(s): %s." % _join_actions(reused as Array)
		_set_feedback(explanation); _refresh(); binding_changed.emit(_active_device, action, String(result.get("binding", "")))
		return result
	var error := String(result.get("error", "unknown_error"))
	if error == "binding_conflict": _set_feedback("Conflict: this control is already required by %s in an overlapping context. Choose another control." % _human_action(StringName(result.get("conflicts_with", &""))))
	elif error == "accept_cancel_recovery_conflict": _set_feedback("Conflict: Accept and Cancel must remain different so this device can always recover from remapping.")
	else: _set_feedback("Binding not saved: %s." % error.replace("_", " "))
	return result

func reset_active_device() -> Dictionary:
	var result: Dictionary = _model.reset_device(_active_device)
	if bool(result.get("ok", false)):
		InputActionCatalogScript.reset_device_in_input_map(_active_device)
		_last_persistence_result = _bindings_store.save(_model)
		_capture_action = &""
		if bool(_last_persistence_result.get("ok", false)): _set_feedback("%s bindings reset to defaults and saved locally." % _device_name(_active_device))
		else: _set_feedback("%s defaults restored for this session, but local save failed." % _device_name(_active_device))
		_refresh()
		if not bool(_last_persistence_result.get("ok", false)): return {"ok": false, "error": "settings_save_failed", "detail": _last_persistence_result}
	return result

func recovery_snapshot() -> Dictionary: return _model.recovery_contract(_active_device)
func row_text(action: StringName) -> String:
	if not _rows.has(action): return ""
	return (_rows[action] as Button).text

func focus_entry() -> void:
	if _keyboard_button != null: _keyboard_button.grab_focus()

func rendered_snapshot() -> Dictionary:
	var rows: Dictionary = {}
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS: rows[String(action)] = row_text(action)
	return {"active_device": _active_device, "last_input_device": _last_input_device, "capture_action": _capture_action,
		"device_title": _device_title.text if _device_title != null else "", "feedback": _feedback.text if _feedback != null else "", "recovery": _recovery.text if _recovery != null else "", "rows": rows,
		"keyboard_focusable": _keyboard_button != null and _keyboard_button.focus_mode == Control.FOCUS_ALL, "controller_focusable": _controller_button != null and _controller_button.focus_mode == Control.FOCUS_ALL,
		"reset_focusable": _reset_button != null and _reset_button.focus_mode == Control.FOCUS_ALL, "close_focusable": _close_button != null and _close_button.focus_mode == Control.FOCUS_ALL,
		"device_local_persistence": true}

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and (event as InputEventKey).echo: return
	if _capture_action != &"":
		if _capture_action != &"cancel" and event.is_action_pressed(&"cancel"):
			cancel_capture(); get_viewport().set_input_as_handled(); return
		var result := capture_event(event)
		if bool(result.get("ok", false)) or String(result.get("error", "")) in ["wrong_device", "settings_save_failed"]: get_viewport().set_input_as_handled()
		return
	var device := InputActionCatalogScript.device_for_event(event)
	if device != &"":
		_last_input_device = device
		if device != _active_device: note_input_source(device)

func _build_widgets() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24); margin.add_theme_constant_override("margin_top", 20); margin.add_theme_constant_override("margin_right", 24); margin.add_theme_constant_override("margin_bottom", 20); add_child(margin)
	var root := VBoxContainer.new(); root.size_flags_vertical = Control.SIZE_EXPAND_FILL; margin.add_child(root)
	var header := HBoxContainer.new(); root.add_child(header)
	var heading := Label.new(); heading.text = "Settings — Controls"; heading.add_theme_font_size_override("font_size", 24); heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	_close_button = Button.new(); _close_button.text = "Close"; _close_button.focus_mode = Control.FOCUS_ALL; _close_button.pressed.connect(func() -> void: close_requested.emit()); header.add_child(_close_button)
	_device_title = Label.new(); _device_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(_device_title)
	var tabs := HBoxContainer.new(); root.add_child(tabs)
	_keyboard_button = Button.new(); _keyboard_button.text = "Keyboard"; _keyboard_button.focus_mode = Control.FOCUS_ALL; _keyboard_button.pressed.connect(func() -> void: set_active_device(InputActionCatalogScript.DEVICE_KEYBOARD)); tabs.add_child(_keyboard_button)
	_controller_button = Button.new(); _controller_button.text = "Controller"; _controller_button.focus_mode = Control.FOCUS_ALL; _controller_button.pressed.connect(func() -> void: set_active_device(InputActionCatalogScript.DEVICE_CONTROLLER)); tabs.add_child(_controller_button)
	_reset_button = Button.new(); _reset_button.text = "Reset bindings to default"; _reset_button.focus_mode = Control.FOCUS_ALL; _reset_button.pressed.connect(func() -> void: reset_active_device()); tabs.add_child(_reset_button)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
	_list = VBoxContainer.new(); _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(_list)
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		var row := Button.new(); row.alignment = HORIZONTAL_ALIGNMENT_LEFT; row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; row.focus_mode = Control.FOCUS_ALL
		row.tooltip_text = "Activate remap for %s, then provide a control from the same device." % _human_action(action); row.pressed.connect(begin_capture.bind(action)); _rows[action] = row; _list.add_child(row)
	_feedback = Label.new(); _feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _feedback.text = "Select a device and action. Conflicts are checked before saving."; root.add_child(_feedback)
	_recovery = Label.new(); _recovery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(_recovery)

func _refresh() -> void:
	if _list == null: return
	var marker := "[KB]" if _active_device == InputActionCatalogScript.DEVICE_KEYBOARD else "[PAD]"
	_device_title.text = "%s %s controls — glyph marker plus text is always shown." % [marker, _device_name(_active_device)]
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		var row: Button = _rows[action]
		row.text = "%s  %s  —  %s%s" % [marker, _human_action(action), _model.binding(_active_device, action), "  [LISTENING]" if action == _capture_action else ""]
	var recovery: Dictionary = _model.recovery_contract(_active_device)
	_recovery.text = "Recovery on this device: Accept = %s · Cancel = %s · %s" % [String(recovery.get("accept_binding", "")), String(recovery.get("cancel_binding", "")), "ready" if bool(recovery.get("recoverable", false)) else "BLOCKED"]
	_keyboard_button.disabled = _active_device == InputActionCatalogScript.DEVICE_KEYBOARD; _controller_button.disabled = _active_device == InputActionCatalogScript.DEVICE_CONTROLLER

func _set_feedback(message: String) -> void:
	if _feedback != null: _feedback.text = message
	remap_feedback.emit(message)

static func _device_name(device: StringName) -> String: return "Keyboard" if device == InputActionCatalogScript.DEVICE_KEYBOARD else "Controller"
static func _human_action(action: StringName) -> String: return String(action).replace("_", " ").capitalize()
static func _join_actions(actions: Array) -> String:
	var names := PackedStringArray(); for action: Variant in actions: names.append(_human_action(StringName(action)))
	return ", ".join(names)
