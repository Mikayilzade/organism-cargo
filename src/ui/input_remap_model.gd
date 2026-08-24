class_name InputRemapModel
extends RefCounted

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")

const ACTION_CONTEXTS: Dictionary = {
	&"navigate_up": [&"global"], &"navigate_down": [&"global"], &"navigate_left": [&"global"], &"navigate_right": [&"global"],
	&"accept": [&"global"], &"cancel": [&"global"], &"inspect": [&"planning", &"transit", &"review"],
	&"rotate": [&"planning"], &"remove": [&"planning"], &"region_next": [&"planning"], &"region_previous": [&"planning"],
	&"overlay_next": [&"planning", &"transit"], &"overlay_previous": [&"planning", &"transit"], &"undo": [&"planning"], &"redo": [&"planning"],
	&"launch_focus": [&"planning", &"launch_confirm"], &"pause_playback": [&"transit"], &"speed_up": [&"transit"], &"speed_down": [&"transit"],
	&"tick_step": [&"transit"], &"review_event_previous": [&"review"], &"review_event_next": [&"review"],
	&"jump_failed_predicate": [&"review"], &"jump_root_cause": [&"review"], &"compare_start_final": [&"review"],
	&"panel_next": [&"global"], &"panel_previous": [&"global"],
}

var _bindings: Dictionary = {}

func _init() -> void:
	reset_device(InputActionCatalogScript.DEVICE_KEYBOARD)
	reset_device(InputActionCatalogScript.DEVICE_CONTROLLER)

func reset_device(device: StringName) -> Dictionary:
	var defaults: Dictionary = InputActionCatalogScript.default_binding_labels(device)
	if defaults.is_empty():
		return {"ok": false, "error": "unknown_device"}
	_bindings[device] = defaults.duplicate(true)
	return {"ok": true, "error": "", "device": device, "bindings": defaults.duplicate(true)}

func binding(device: StringName, action: StringName) -> String:
	if not _bindings.has(device):
		return ""
	return String((_bindings[device] as Dictionary).get(action, ""))

func propose_binding(device: StringName, action: StringName, physical_label: String) -> Dictionary:
	if not _bindings.has(device):
		return {"ok": false, "error": "unknown_device"}
	if not InputActionCatalogScript.REQUIRED_ACTIONS.has(action):
		return {"ok": false, "error": "unknown_action"}
	var label: String = physical_label.strip_edges()
	if label.is_empty():
		return {"ok": false, "error": "empty_binding"}
	var profile: Dictionary = _bindings[device]
	var explained: Array[StringName] = []
	for raw_action: Variant in profile.keys():
		var other: StringName = StringName(raw_action)
		if other == action or String(profile[raw_action]).to_lower() != label.to_lower():
			continue
		if _contexts_overlap(action, other):
			return {"ok": false, "error": "binding_conflict", "conflicts_with": other}
		explained.append(other)
	profile[action] = label
	if String(profile.get(&"accept", "")).to_lower() == String(profile.get(&"cancel", "")).to_lower():
		return {"ok": false, "error": "accept_cancel_recovery_conflict"}
	_bindings[device] = profile
	return {
		"ok": true,
		"error": "",
		"device": device,
		"action": action,
		"binding": label,
		"mutually_exclusive_reuse": explained,
		"explanation_required": not explained.is_empty(),
	}

func recovery_contract(device: StringName) -> Dictionary:
	return {
		"device": device,
		"accept_binding": binding(device, &"accept"),
		"cancel_binding": binding(device, &"cancel"),
		"other_device_required": false,
		"recoverable": not binding(device, &"accept").is_empty() and not binding(device, &"cancel").is_empty() and binding(device, &"accept").to_lower() != binding(device, &"cancel").to_lower(),
	}

func snapshot() -> Dictionary:
	return {
		"keyboard": (_bindings.get(InputActionCatalogScript.DEVICE_KEYBOARD, {}) as Dictionary).duplicate(true),
		"controller": (_bindings.get(InputActionCatalogScript.DEVICE_CONTROLLER, {}) as Dictionary).duplicate(true),
	}

static func _contexts_overlap(a: StringName, b: StringName) -> bool:
	var a_contexts: Array = ACTION_CONTEXTS.get(a, [&"global"])
	var b_contexts: Array = ACTION_CONTEXTS.get(b, [&"global"])
	if a_contexts.has(&"global") or b_contexts.has(&"global"):
		return true
	for context: Variant in a_contexts:
		if b_contexts.has(context):
			return true
	return false
