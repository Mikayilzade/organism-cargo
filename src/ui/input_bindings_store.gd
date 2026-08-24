class_name InputBindingsStore
extends RefCounted

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://organism_cargo/input_bindings.json"
const DEVICES: Array[StringName] = [InputActionCatalogScript.DEVICE_KEYBOARD, InputActionCatalogScript.DEVICE_CONTROLLER]

var _path: String

func _init(path: String = DEFAULT_PATH) -> void:
	_path = path

func path() -> String:
	return _path

func load_into(model: InputRemapModel) -> Dictionary:
	InputActionCatalogScript.ensure_registered()
	if not FileAccess.file_exists(_path):
		_reset_all(model)
		return {"ok": true, "error": "", "source": "defaults", "recovered_devices": []}
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		_reset_all(model)
		return {"ok": false, "error": "settings_open_failed", "recovered_devices": ["keyboard", "controller"]}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not (parser.data is Dictionary):
		_reset_all(model)
		var repaired := save(model)
		return {"ok": bool(repaired.get("ok", false)), "error": "settings_corrupt", "recovered": true, "recovered_devices": ["keyboard", "controller"]}
	var document: Dictionary = parser.data
	if int(document.get("schema_version", -1)) != SCHEMA_VERSION or not (document.get("devices", null) is Dictionary):
		_reset_all(model)
		var repaired := save(model)
		return {"ok": bool(repaired.get("ok", false)), "error": "settings_schema_invalid", "recovered": true, "recovered_devices": ["keyboard", "controller"]}
	var devices: Dictionary = document.get("devices", {})
	var recovered: Array[String] = []
	for device: StringName in DEVICES:
		var decoded := _decode_device(device, devices.get(String(device), null))
		if not bool(decoded.get("ok", false)) or not _restore_model_device(model, device, decoded.get("labels", {})):
			_reset_device(model, device)
			recovered.append(String(device))
			continue
		InputActionCatalogScript.reset_device_in_input_map(device)
		var events: Dictionary = decoded.get("events", {})
		var applied_ok := true
		for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
			var event: InputEvent = events.get(action, null)
			if event == null or not bool(InputActionCatalogScript.apply_binding_event(device, action, event).get("ok", false)):
				applied_ok = false
				break
		if not applied_ok:
			_reset_device(model, device)
			if not recovered.has(String(device)): recovered.append(String(device))
	if not recovered.is_empty():
		var repaired := save(model)
		return {"ok": bool(repaired.get("ok", false)), "error": "settings_device_recovered", "recovered": true, "recovered_devices": recovered}
	return {"ok": true, "error": "", "source": "device_local", "recovered": false, "recovered_devices": []}

func save(model: InputRemapModel) -> Dictionary:
	InputActionCatalogScript.ensure_registered()
	var devices: Dictionary = {}
	for device: StringName in DEVICES:
		var action_payloads: Dictionary = {}
		for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
			var event := _event_for_device(action, device)
			if event == null:
				return {"ok": false, "error": "binding_event_missing", "device": device, "action": action}
			var label := InputActionCatalogScript.physical_label_for_event(event)
			if label.is_empty() or label != model.binding(device, action):
				return {"ok": false, "error": "binding_model_inputmap_mismatch", "device": device, "action": action}
			action_payloads[String(action)] = {"label": label, "event": _encode_event(event)}
		devices[String(device)] = {"actions": action_payloads}
	var document := {"schema_version": SCHEMA_VERSION, "devices": devices}
	var directory := _path.get_base_dir()
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var tmp_path := _path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null: return {"ok": false, "error": "settings_tmp_open_failed"}
	file.store_string(JSON.stringify(document, "\t", true, true)); file.flush(); file = null
	var absolute_tmp := ProjectSettings.globalize_path(tmp_path)
	var absolute_target := ProjectSettings.globalize_path(_path)
	if FileAccess.file_exists(_path):
		var remove_error := DirAccess.remove_absolute(absolute_target)
		if remove_error != OK:
			DirAccess.remove_absolute(absolute_tmp)
			return {"ok": false, "error": "settings_replace_failed", "code": remove_error}
	var rename_error := DirAccess.rename_absolute(absolute_tmp, absolute_target)
	if rename_error != OK:
		DirAccess.remove_absolute(absolute_tmp)
		return {"ok": false, "error": "settings_install_failed", "code": rename_error}
	return {"ok": true, "error": "", "path": _path}

func reset_device(model: InputRemapModel, device: StringName) -> Dictionary:
	if not DEVICES.has(device): return {"ok": false, "error": "unknown_device"}
	_reset_device(model, device)
	return save(model)

func _decode_device(device: StringName, raw: Variant) -> Dictionary:
	if not (raw is Dictionary): return {"ok": false, "error": "device_payload_missing"}
	var actions_raw: Variant = (raw as Dictionary).get("actions", null)
	if not (actions_raw is Dictionary): return {"ok": false, "error": "device_actions_missing"}
	var actions: Dictionary = actions_raw
	var labels: Dictionary = {}
	var events: Dictionary = {}
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		var entry_raw: Variant = actions.get(String(action), null)
		if not (entry_raw is Dictionary): return {"ok": false, "error": "action_payload_missing", "action": action}
		var entry: Dictionary = entry_raw
		var label := String(entry.get("label", "")).strip_edges()
		var event := _decode_event(entry.get("event", null))
		if event == null or InputActionCatalogScript.device_for_event(event) != device: return {"ok": false, "error": "event_invalid", "action": action}
		if label.is_empty() or InputActionCatalogScript.physical_label_for_event(event) != label: return {"ok": false, "error": "event_label_mismatch", "action": action}
		labels[action] = label; events[action] = event
	return {"ok": true, "error": "", "labels": labels, "events": events}

func _restore_model_device(model: InputRemapModel, device: StringName, labels: Dictionary) -> bool:
	if labels.size() != InputActionCatalogScript.REQUIRED_ACTIONS.size(): return false
	model.reset_device(device)
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		var unique_placeholder := "__restore_%s_%s__" % [String(device), String(action)]
		if not bool(model.propose_binding(device, action, unique_placeholder).get("ok", false)): return false
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		if not bool(model.propose_binding(device, action, String(labels.get(action, ""))).get("ok", false)):
			model.reset_device(device)
			return false
	return bool(model.recovery_contract(device).get("recoverable", false))

func _reset_all(model: InputRemapModel) -> void:
	for device: StringName in DEVICES: _reset_device(model, device)

func _reset_device(model: InputRemapModel, device: StringName) -> void:
	model.reset_device(device)
	InputActionCatalogScript.reset_device_in_input_map(device)

func _event_for_device(action: StringName, device: StringName) -> InputEvent:
	for event: InputEvent in InputMap.action_get_events(action):
		if InputActionCatalogScript.device_for_event(event) == device: return event
	return null

func _encode_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {"kind": "key", "physical_keycode": int(key.physical_keycode), "keycode": int(key.keycode), "ctrl": key.ctrl_pressed, "alt": key.alt_pressed, "shift": key.shift_pressed, "meta": key.meta_pressed}
	if event is InputEventJoypadButton:
		return {"kind": "joy_button", "button_index": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {"kind": "joy_motion", "axis": motion.axis, "axis_value": motion.axis_value}
	return {}

func _decode_event(raw: Variant) -> InputEvent:
	if not (raw is Dictionary): return null
	var payload: Dictionary = raw
	match String(payload.get("kind", "")):
		"key":
			var key := InputEventKey.new(); key.physical_keycode = int(payload.get("physical_keycode", 0)); key.keycode = int(payload.get("keycode", 0)); key.ctrl_pressed = bool(payload.get("ctrl", false)); key.alt_pressed = bool(payload.get("alt", false)); key.shift_pressed = bool(payload.get("shift", false)); key.meta_pressed = bool(payload.get("meta", false)); return key
		"joy_button":
			var button := InputEventJoypadButton.new(); button.button_index = int(payload.get("button_index", -1)); return button if button.button_index >= 0 else null
		"joy_motion":
			var motion := InputEventJoypadMotion.new(); motion.axis = int(payload.get("axis", -1)); motion.axis_value = float(payload.get("axis_value", 1.0)); return motion if motion.axis >= 0 else null
	return null
