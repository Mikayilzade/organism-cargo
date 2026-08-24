class_name PlanningFocusRouter
extends RefCounted

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")

var _region_index: int = 0
var _hold_size: Vector2i = Vector2i.ONE
var _hold_cell: Vector2i = Vector2i.ZERO
var _modal_region: StringName = &""

func configure_hold(width: int, height: int) -> Dictionary:
	if width <= 0 or height <= 0:
		return {"ok": false, "error": "invalid_hold_dimensions"}
	_hold_size = Vector2i(width, height)
	_hold_cell.x = clampi(_hold_cell.x, 0, width - 1)
	_hold_cell.y = clampi(_hold_cell.y, 0, height - 1)
	return {"ok": true, "error": "", "hold_size": [width, height]}

func current_region() -> StringName:
	if not _modal_region.is_empty():
		return _modal_region
	return InputActionCatalogScript.PLANNING_FOCUS_REGIONS[_region_index]

func focus_visible() -> bool:
	return true

func set_region(region: StringName) -> Dictionary:
	if not InputActionCatalogScript.is_valid_focus_region(region):
		return {"ok": false, "error": "unknown_focus_region"}
	if not _modal_region.is_empty() and region != _modal_region:
		return {"ok": false, "error": "modal_focus_trap"}
	_region_index = InputActionCatalogScript.PLANNING_FOCUS_REGIONS.find(region)
	return {"ok": true, "error": "", "region": current_region()}

func cycle_region(direction: int) -> Dictionary:
	if direction == 0:
		return {"ok": false, "error": "zero_region_direction"}
	if not _modal_region.is_empty():
		return {"ok": false, "error": "modal_focus_trap", "region": current_region()}
	var count := InputActionCatalogScript.PLANNING_FOCUS_REGIONS.size()
	_region_index = posmod(_region_index + (1 if direction > 0 else -1), count)
	return {"ok": true, "error": "", "region": current_region()}

func move_hold_focus(delta_x: int, delta_y: int) -> Dictionary:
	if current_region() != &"HOLD":
		return {"ok": false, "error": "hold_region_not_focused", "focus": [_hold_cell.x, _hold_cell.y]}
	_hold_cell.x = clampi(_hold_cell.x + delta_x, 0, _hold_size.x - 1)
	_hold_cell.y = clampi(_hold_cell.y + delta_y, 0, _hold_size.y - 1)
	return {"ok": true, "error": "", "focus": [_hold_cell.x, _hold_cell.y]}

func set_hold_focus(x: int, y: int) -> Dictionary:
	if x < 0 or y < 0 or x >= _hold_size.x or y >= _hold_size.y:
		return {"ok": false, "error": "hold_focus_out_of_bounds"}
	_hold_cell = Vector2i(x, y)
	return {"ok": true, "error": "", "focus": [x, y]}

func enter_modal(region: StringName) -> Dictionary:
	if not InputActionCatalogScript.is_valid_focus_region(region):
		return {"ok": false, "error": "unknown_modal_region"}
	_modal_region = region
	_region_index = InputActionCatalogScript.PLANNING_FOCUS_REGIONS.find(region)
	return {"ok": true, "error": "", "region": current_region()}

func exit_modal() -> Dictionary:
	_modal_region = &""
	return {"ok": true, "error": "", "region": current_region()}

func semantic_request(action: StringName) -> Dictionary:
	if not InputActionCatalogScript.REQUIRED_ACTIONS.has(action):
		return {"ok": false, "error": "unknown_semantic_action"}
	match action:
		&"region_next":
			return cycle_region(1)
		&"region_previous":
			return cycle_region(-1)
		&"navigate_up":
			return move_hold_focus(0, -1)
		&"navigate_down":
			return move_hold_focus(0, 1)
		&"navigate_left":
			return move_hold_focus(-1, 0)
		&"navigate_right":
			return move_hold_focus(1, 0)
		&"accept":
			return _command("ACCEPT")
		&"cancel":
			return _command("CANCEL")
		&"inspect":
			return _command("INSPECT")
		&"rotate":
			return _command("ROTATE")
		&"remove":
			return _command("REMOVE")
		&"launch_focus":
			return _command("FOCUS_LAUNCH")
	return _command(String(action).to_upper())

func snapshot() -> Dictionary:
	return {
		"region": current_region(),
		"focus_visible": true,
		"hold_focus": [_hold_cell.x, _hold_cell.y],
		"hold_size": [_hold_size.x, _hold_size.y],
		"modal_trapped": not _modal_region.is_empty(),
		"modal_region": _modal_region,
	}

func _command(command: String) -> Dictionary:
	return {
		"ok": true,
		"error": "",
		"command": command,
		"region": current_region(),
		"hold_focus": [_hold_cell.x, _hold_cell.y],
	}
