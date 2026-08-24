class_name PlanningSupportConfigModel
extends RefCounted

var _definitions: Array[Dictionary] = []
var _targets: Array[String] = []
var _support_index: int = 0
var _target_index: int = 0
var _links: Dictionary = {}
var _power_priority: Array[String] = []

func configure(definitions_value: Variant, targets_value: Variant) -> Dictionary:
	_definitions.clear()
	_targets.clear()
	_links.clear()
	_power_priority.clear()
	_support_index = 0
	_target_index = 0

	if typeof(definitions_value) == TYPE_DICTIONARY:
		definitions_value = (definitions_value as Dictionary).get("definitions", [])
	if typeof(definitions_value) != TYPE_ARRAY:
		return _fail("support_definitions_must_be_array")

	var seen: Dictionary = {}
	for raw_definition: Variant in definitions_value:
		if typeof(raw_definition) != TYPE_DICTIONARY:
			return _fail("support_definition_must_be_dictionary")
		var definition: Dictionary = (raw_definition as Dictionary).duplicate(true)
		var support_id: String = String(definition.get("id", ""))
		if support_id.is_empty():
			return _fail("support_id_required")
		if seen.has(support_id):
			return _fail("duplicate_support_id")
		seen[support_id] = true
		_definitions.append(definition)
		if bool(definition.get("requires_power", false)):
			_power_priority.append(support_id)

	if typeof(targets_value) != TYPE_ARRAY:
		return _fail("support_targets_must_be_array")
	for raw_target: Variant in targets_value:
		var target_id: String = ""
		if typeof(raw_target) == TYPE_DICTIONARY:
			target_id = String((raw_target as Dictionary).get("id", (raw_target as Dictionary).get("instance_id", "")))
		else:
			target_id = String(raw_target)
		if target_id.is_empty():
			continue
		if not _targets.has(target_id):
			_targets.append(target_id)

	return {"ok": true, "error": "", "snapshot": snapshot()}

func has_supports() -> bool:
	return not _definitions.is_empty()

func move_support(direction: int) -> Dictionary:
	if _definitions.is_empty():
		return _fail("support_list_empty")
	if direction == 0:
		return _fail("zero_support_direction")
	_support_index = posmod(_support_index + (1 if direction > 0 else -1), _definitions.size())
	return _ok_snapshot()

func move_target(direction: int) -> Dictionary:
	if _targets.is_empty():
		return _fail("support_target_list_empty")
	if direction == 0:
		return _fail("zero_target_direction")
	_target_index = posmod(_target_index + (1 if direction > 0 else -1), _targets.size())
	return _ok_snapshot()

func toggle_selected_link() -> Dictionary:
	if _definitions.is_empty():
		return _fail("support_list_empty")
	if _targets.is_empty():
		return _fail("support_target_list_empty")
	var support_id: String = selected_support_id()
	var target_id: String = selected_target_id()
	if String(_links.get(support_id, "")) == target_id:
		_links.erase(support_id)
	else:
		_links[support_id] = target_id
	return _ok_snapshot()

func change_selected_power_priority(direction: int) -> Dictionary:
	if direction == 0:
		return _fail("zero_priority_direction")
	var support_id: String = selected_support_id()
	var index: int = _power_priority.find(support_id)
	if index < 0:
		return _fail("selected_support_not_powered")
	var target_index: int = clampi(index + (1 if direction > 0 else -1), 0, _power_priority.size() - 1)
	if target_index == index:
		return _ok_snapshot()
	var displaced: String = _power_priority[target_index]
	_power_priority[target_index] = support_id
	_power_priority[index] = displaced
	return _ok_snapshot()

func command(action: StringName) -> Dictionary:
	match action:
		&"navigate_up":
			return move_support(-1)
		&"navigate_down":
			return move_support(1)
		&"navigate_left":
			return move_target(-1)
		&"navigate_right":
			return move_target(1)
		&"accept":
			return toggle_selected_link()
		&"overlay_previous":
			return change_selected_power_priority(-1)
		&"overlay_next":
			return change_selected_power_priority(1)
		&"inspect":
			return _ok_snapshot()
	return _fail("unsupported_support_command")

func selected_support_id() -> String:
	if _definitions.is_empty():
		return ""
	return String(_definitions[_support_index].get("id", ""))

func selected_target_id() -> String:
	if _targets.is_empty():
		return ""
	return _targets[_target_index]

func snapshot() -> Dictionary:
	var support_order: Array[String] = []
	for definition: Dictionary in _definitions:
		support_order.append(String(definition.get("id", "")))
	var link_rows: Array[Dictionary] = []
	for support_id: String in support_order:
		if _links.has(support_id):
			link_rows.append({"source": support_id, "target": String(_links[support_id])})
	var selected_definition: Dictionary = {}
	if not _definitions.is_empty():
		selected_definition = _definitions[_support_index]
	return {
		"support_order": support_order,
		"target_order": _targets.duplicate(),
		"selected_support_id": selected_support_id(),
		"selected_support_name": String(selected_definition.get("name", selected_support_id())),
		"selected_requires_power": bool(selected_definition.get("requires_power", false)),
		"selected_target_id": selected_target_id(),
		"links": link_rows,
		"power_priority": _power_priority.duplicate(),
		"instructions": "Up/Down source • Left/Right target • Accept link/unlink • Overlay Prev/Next Brownout priority",
	}

func _ok_snapshot() -> Dictionary:
	return {"ok": true, "error": "", "snapshot": snapshot()}

static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
