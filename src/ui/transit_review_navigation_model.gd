class_name TransitReviewNavigationModel
extends RefCounted

const PLAYBACK_SPEEDS: Array[float] = [0.5, 1.0, 2.0, 4.0]
const REVIEW_PANELS: Array[StringName] = [&"TIMELINE", &"INSPECTOR", &"OBJECTIVES"]

var _paused: bool = false
var _speed_index: int = 1
var _step_requests: int = 0
var _focus_mode: StringName = &"CELL"
var _hold_width: int = 1
var _hold_height: int = 1
var _cell_focus: Vector2i = Vector2i.ZERO
var _entity_ids: Array[String] = []
var _entity_focus_index: int = 0

var _review: Dictionary = {}
var _events: Array = []
var _event_index: int = 0
var _compare_start_final: bool = false
var _panel_index: int = 0

func configure_transit(context: Dictionary) -> Dictionary:
	_paused = false
	_speed_index = 1
	_step_requests = 0
	_focus_mode = &"CELL"
	_cell_focus = Vector2i.ZERO
	_entity_ids.clear()
	_entity_focus_index = 0
	var hold_value: Variant = context.get("planning_hold_payload", {})
	if typeof(hold_value) == TYPE_DICTIONARY:
		var hold: Dictionary = hold_value
		_hold_width = maxi(1, int(hold.get("width", 1)))
		_hold_height = maxi(1, int(hold.get("height", 1)))
	var contract_value: Variant = context.get("planning_contract_payload", {})
	if typeof(contract_value) == TYPE_DICTIONARY:
		var manifest_value: Variant = (contract_value as Dictionary).get("manifest", [])
		if typeof(manifest_value) == TYPE_ARRAY:
			for raw_entry: Variant in manifest_value:
				if typeof(raw_entry) != TYPE_DICTIONARY:
					continue
				var instance_id: String = String((raw_entry as Dictionary).get("instance_id", ""))
				if not instance_id.is_empty():
					_entity_ids.append(instance_id)
	_entity_ids.sort()
	return {"ok": true, "error": "", "snapshot": transit_snapshot()}

func transit_command(action: StringName) -> Dictionary:
	match action:
		&"pause_playback":
			_paused = not _paused
		&"speed_up":
			_speed_index = mini(_speed_index + 1, PLAYBACK_SPEEDS.size() - 1)
		&"speed_down":
			_speed_index = maxi(_speed_index - 1, 0)
		&"tick_step":
			if not _paused:
				return _failure("tick_step_requires_pause")
			_step_requests += 1
		&"region_next", &"panel_next":
			_focus_mode = &"ENTITY" if _focus_mode == &"CELL" else &"CELL"
		&"region_previous", &"panel_previous":
			_focus_mode = &"ENTITY" if _focus_mode == &"CELL" else &"CELL"
		&"navigate_up":
			return _move_focus(0, -1)
		&"navigate_down":
			return _move_focus(0, 1)
		&"navigate_left":
			return _move_focus(-1, 0)
		&"navigate_right":
			return _move_focus(1, 0)
		&"inspect":
			return transit_inspection()
		_:
			return _failure("transit_action_not_supported")
	return {"ok": true, "error": "", "snapshot": transit_snapshot()}

func transit_snapshot() -> Dictionary:
	return {
		"paused": _paused,
		"speed": PLAYBACK_SPEEDS[_speed_index],
		"step_requests": _step_requests,
		"focus_mode": _focus_mode,
		"cell_focus": [_cell_focus.x, _cell_focus.y],
		"entity_focus_id": "" if _entity_ids.is_empty() else _entity_ids[_entity_focus_index],
	}

func transit_inspection() -> Dictionary:
	if _focus_mode == &"ENTITY":
		if _entity_ids.is_empty():
			return _failure("no_transit_entities")
		return {"ok": true, "error": "", "kind": &"ENTITY", "entity_id": _entity_ids[_entity_focus_index]}
	return {"ok": true, "error": "", "kind": &"CELL", "cell": [_cell_focus.x, _cell_focus.y]}

func configure_review(review: Dictionary) -> Dictionary:
	if not bool(review.get("ok", false)):
		return _failure("invalid_review")
	var events_value: Variant = review.get("events", [])
	if typeof(events_value) != TYPE_ARRAY:
		return _failure("invalid_review_events")
	_review = review.duplicate(true)
	_events = (events_value as Array).duplicate(true)
	_event_index = 0
	_compare_start_final = false
	_panel_index = 0
	var first_actionable: String = String(review.get("first_actionable_event_id", ""))
	if not first_actionable.is_empty():
		_select_event_id(first_actionable)
	return {"ok": true, "error": "", "snapshot": review_snapshot()}

func review_command(action: StringName) -> Dictionary:
	if _review.is_empty():
		return _failure("review_not_configured")
	match action:
		&"review_event_previous":
			if not _events.is_empty():
				_event_index = posmod(_event_index - 1, _events.size())
		&"review_event_next":
			if not _events.is_empty():
				_event_index = posmod(_event_index + 1, _events.size())
		&"jump_failed_predicate":
			return _jump_failed_predicate()
		&"jump_root_cause":
			return _jump_root_cause()
		&"compare_start_final":
			_compare_start_final = not _compare_start_final
		&"panel_next", &"region_next":
			_panel_index = posmod(_panel_index + 1, REVIEW_PANELS.size())
		&"panel_previous", &"region_previous":
			_panel_index = posmod(_panel_index - 1, REVIEW_PANELS.size())
		&"inspect":
			return review_inspection()
		_:
			return _failure("review_action_not_supported")
	return {"ok": true, "error": "", "snapshot": review_snapshot()}

func review_snapshot() -> Dictionary:
	return {
		"event_index": _event_index,
		"event_id": _current_event_id(),
		"compare_start_final": _compare_start_final,
		"panel": REVIEW_PANELS[_panel_index],
		"event_count": _events.size(),
	}

func review_inspection() -> Dictionary:
	if _events.is_empty():
		return _failure("no_review_events")
	var event_value: Variant = _events[_event_index]
	if typeof(event_value) != TYPE_DICTIONARY:
		return _failure("invalid_review_event")
	return {"ok": true, "error": "", "event": (event_value as Dictionary).duplicate(true)}

func _move_focus(delta_x: int, delta_y: int) -> Dictionary:
	if _focus_mode == &"ENTITY":
		if _entity_ids.is_empty():
			return _failure("no_transit_entities")
		var delta: int = delta_x if delta_x != 0 else delta_y
		_entity_focus_index = posmod(_entity_focus_index + delta, _entity_ids.size())
	else:
		_cell_focus.x = clampi(_cell_focus.x + delta_x, 0, _hold_width - 1)
		_cell_focus.y = clampi(_cell_focus.y + delta_y, 0, _hold_height - 1)
	return {"ok": true, "error": "", "snapshot": transit_snapshot()}

func _jump_failed_predicate() -> Dictionary:
	var objective_value: Variant = _review.get("objective_events", [])
	if typeof(objective_value) != TYPE_ARRAY:
		return _failure("invalid_objective_events")
	for raw_event: Variant in objective_value:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = raw_event
		if not bool(event.get("passed", false)):
			if _select_event_id(String(event.get("event_id", ""))):
				return {"ok": true, "error": "", "snapshot": review_snapshot()}
	return _failure("no_failed_predicate")

func _jump_root_cause() -> Dictionary:
	if _events.is_empty():
		return _failure("no_review_events")
	var visited: Dictionary = {}
	var current_id: String = _current_event_id()
	while not current_id.is_empty() and not visited.has(current_id):
		visited[current_id] = true
		var event: Dictionary = _event_by_id(current_id)
		if event.is_empty():
			break
		var parents: PackedStringArray = _parent_ids(event)
		if parents.is_empty():
			_select_event_id(current_id)
			return {"ok": true, "error": "", "snapshot": review_snapshot()}
		parents.sort()
		current_id = parents[0]
	return _failure("root_cause_unavailable")

func _select_event_id(event_id: String) -> bool:
	for index: int in range(_events.size()):
		var event_value: Variant = _events[index]
		if typeof(event_value) == TYPE_DICTIONARY and String((event_value as Dictionary).get("event_id", "")) == event_id:
			_event_index = index
			return true
	return false

func _current_event_id() -> String:
	if _events.is_empty():
		return ""
	var event_value: Variant = _events[_event_index]
	if typeof(event_value) != TYPE_DICTIONARY:
		return ""
	return String((event_value as Dictionary).get("event_id", ""))

func _event_by_id(event_id: String) -> Dictionary:
	for event_value: Variant in _events:
		if typeof(event_value) == TYPE_DICTIONARY and String((event_value as Dictionary).get("event_id", "")) == event_id:
			return (event_value as Dictionary)
	return {}

func _parent_ids(event: Dictionary) -> PackedStringArray:
	var raw: Variant = event.get("parent_event_ids", PackedStringArray())
	var parents := PackedStringArray()
	if raw is PackedStringArray:
		for value: String in (raw as PackedStringArray):
			parents.append(value)
	elif typeof(raw) == TYPE_ARRAY:
		for value: Variant in raw:
			parents.append(String(value))
	return parents

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
