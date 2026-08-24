class_name SettingsRemapControl
extends PanelContainer

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")

signal close_requested

var _model: InputRemapModel
var _active_device: StringName = InputActionCatalogScript.DEVICE_KEYBOARD
var _selected_action: StringName = &"accept"
var _last_status: String = ""

var _title_label: Label
var _device_label: Label
var _actions_box: VBoxContainer
var _binding_input: LineEdit
var _status_label: Label
var _recovery_label: Label

func _ready() -> void:
	if _actions_box == null:
		_build_widgets()
	_refresh()

func configure(model: InputRemapModel) -> Dictionary:
	if model == null:
		return {"ok": false, "error": "remap_model_required"}
	_model = model
	if _actions_box == null:
		_build_widgets()
	_refresh()
	return {"ok": true, "error": "", "device": _active_device}

func notify_input_source(device: StringName) -> Dictionary:
	if device not in [InputActionCatalogScript.DEVICE_KEYBOARD, InputActionCatalogScript.DEVICE_CONTROLLER]:
		return {"ok": false, "error": "unknown_device"}
	_active_device = device
	_refresh()
	return {"ok": true, "error": "", "device": _active_device}

func active_device() -> StringName:
	return _active_device

func select_action(action: StringName) -> Dictionary:
	if not InputActionCatalogScript.REQUIRED_ACTIONS.has(action):
		return {"ok": false, "error": "unknown_action"}
	_selected_action = action
	if _binding_input != null and _model != null:
		_binding_input.text = _model.binding(_active_device, _selected_action)
	_refresh_action_rows()
	return {"ok": true, "error": "", "action": _selected_action}

func attempt_rebind(action: StringName, physical_label: String) -> Dictionary:
	if _model == null:
		return {"ok": false, "error": "remap_model_required"}
	var result: Dictionary = _model.propose_binding(_active_device, action, physical_label)
	if not bool(result.get("ok", false)):
		var error: String = String(result.get("error", "unknown"))
		if error == "binding_conflict":
			_last_status = "Conflict: %s is already used by %s in an overlapping context." % [physical_label.strip_edges(), String(result.get("conflicts_with", "another action"))]
		elif error == "accept_cancel_recovery_conflict":
			_last_status = "Conflict: Accept and Cancel must stay distinct on this device so Settings always remains recoverable."
		else:
			_last_status = "Binding not saved: %s." % error
		_refresh()
		return result
	_selected_action = action
	if bool(result.get("explanation_required", false)):
		var reused_labels := PackedStringArray()
		var reused_value: Variant = result.get("mutually_exclusive_reuse", [])
		if typeof(reused_value) == TYPE_ARRAY:
			for reused_action: Variant in reused_value:
				reused_labels.append(String(reused_action))
		_last_status = "Saved. This binding is also used by %s, but only in mutually exclusive contexts." % ", ".join(reused_labels)
	else:
		_last_status = "Saved %s for %s." % [physical_label.strip_edges(), String(action)]
	_refresh()
	return result

func reset_active_device() -> Dictionary:
	if _model == null:
		return {"ok": false, "error": "remap_model_required"}
	var result: Dictionary = _model.reset_device(_active_device)
	if bool(result.get("ok", false)):
		_last_status = "%s bindings reset to defaults." % _device_name(_active_device)
	_refresh()
	return result

func recovery_snapshot() -> Dictionary:
	if _model == null:
		return {}
	return _model.recovery_contract(_active_device)

func screen_snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	if _model != null:
		for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
			rows.append({
				"action": action,
				"binding": _model.binding(_active_device, action),
				"display": _action_display(action),
			})
	return {
		"active_device": _active_device,
		"selected_action": _selected_action,
		"device_display": _device_display(_active_device),
		"rows": rows,
		"status": _last_status,
		"recovery": recovery_snapshot(),
	}

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		notify_input_source(InputActionCatalogScript.DEVICE_CONTROLLER)
	elif event is InputEventKey:
		notify_input_source(InputActionCatalogScript.DEVICE_KEYBOARD)

func _build_widgets() -> void:
	custom_minimum_size = Vector2(520.0, 520.0)
	var root := VBoxContainer.new()
	root.name = "SettingsLayout"
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_title_label = Label.new()
	_title_label.text = "Settings — Controls"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title_label)

	var device_row := HBoxContainer.new()
	root.add_child(device_row)
	_device_label = Label.new()
	_device_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	device_row.add_child(_device_label)
	var keyboard_button := Button.new()
	keyboard_button.text = "⌨ Keyboard"
	keyboard_button.pressed.connect(func() -> void: notify_input_source(InputActionCatalogScript.DEVICE_KEYBOARD))
	device_row.add_child(keyboard_button)
	var controller_button := Button.new()
	controller_button.text = "◉ Controller"
	controller_button.pressed.connect(func() -> void: notify_input_source(InputActionCatalogScript.DEVICE_CONTROLLER))
	device_row.add_child(controller_button)

	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroller)
	_actions_box = VBoxContainer.new()
	_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(_actions_box)

	var edit_row := HBoxContainer.new()
	root.add_child(edit_row)
	_binding_input = LineEdit.new()
	_binding_input.placeholder_text = "Physical key/button label"
	_binding_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_row.add_child(_binding_input)
	var apply_button := Button.new()
	apply_button.text = "Apply binding"
	apply_button.pressed.connect(_on_apply_pressed)
	edit_row.add_child(apply_button)

	var footer := HBoxContainer.new()
	root.add_child(footer)
	var reset_button := Button.new()
	reset_button.text = "Reset this device"
	reset_button.pressed.connect(func() -> void: reset_active_device())
	footer.add_child(reset_button)
	var close_button := Button.new()
	close_button.text = "Back"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	footer.add_child(close_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)
	_recovery_label = Label.new()
	_recovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_recovery_label)

func _refresh() -> void:
	if _device_label == null:
		return
	_device_label.text = "Active input: %s" % _device_display(_active_device)
	_refresh_action_rows()
	if _binding_input != null and _model != null:
		_binding_input.text = _model.binding(_active_device, _selected_action)
	if _status_label != null:
		_status_label.text = _last_status
	if _recovery_label != null:
		var recovery: Dictionary = recovery_snapshot()
		_recovery_label.text = "Same-device recovery: Accept %s · Cancel %s" % [String(recovery.get("accept_binding", "—")), String(recovery.get("cancel_binding", "—"))]

func _refresh_action_rows() -> void:
	if _actions_box == null:
		return
	for child: Node in _actions_box.get_children():
		child.queue_free()
	if _model == null:
		return
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		var button := Button.new()
		button.text = _action_display(action)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = action == _selected_action
		button.pressed.connect(_select_action_from_button.bind(action))
		_actions_box.add_child(button)

func _select_action_from_button(action: StringName) -> void:
	select_action(action)

func _on_apply_pressed() -> void:
	if _binding_input == null:
		return
	attempt_rebind(_selected_action, _binding_input.text)

func _action_display(action: StringName) -> String:
	var binding_label: String = "—" if _model == null else _model.binding(_active_device, action)
	return "%s %s — %s" % [_device_glyph(_active_device), String(action).replace("_", " ").capitalize(), binding_label]

static func _device_display(device: StringName) -> String:
	return "%s %s" % [_device_glyph(device), _device_name(device)]

static func _device_glyph(device: StringName) -> String:
	return "◉" if device == InputActionCatalogScript.DEVICE_CONTROLLER else "⌨"

static func _device_name(device: StringName) -> String:
	return "Controller" if device == InputActionCatalogScript.DEVICE_CONTROLLER else "Keyboard"
