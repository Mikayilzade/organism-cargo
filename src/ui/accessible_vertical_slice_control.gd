class_name AccessibleVerticalSliceControl
extends VerticalSliceControl

func planning_rotate_selected() -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.PLANNING:
		return _fail("planning_not_active")
	if _selected_manifest_instance.is_empty() or not _placements_by_instance.has(_selected_manifest_instance):
		return _fail("placed_selection_required")
	var placement_value: Variant = _placements_by_instance[_selected_manifest_instance]
	if typeof(placement_value) != TYPE_DICTIONARY:
		return _fail("invalid_placement")
	var placement: Dictionary = placement_value
	placement["orientation"] = posmod(int(placement.get("orientation", 0)) + 1, 4)
	_placements_by_instance[_selected_manifest_instance] = placement
	var result: Dictionary = _apply_current_plan()
	_refresh_planning_widgets()
	_render_planning_status()
	return result

func planning_remove_selected() -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.PLANNING:
		return _fail("planning_not_active")
	if _selected_manifest_instance.is_empty() or not _placements_by_instance.has(_selected_manifest_instance):
		return _fail("placed_selection_required")
	_placements_by_instance.erase(_selected_manifest_instance)
	var result: Dictionary = _apply_current_plan()
	_refresh_planning_widgets()
	_render_planning_status()
	return result

func planning_inspect_selected() -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.PLANNING:
		return _fail("planning_not_active")
	if _selected_manifest_instance.is_empty():
		return _fail("manifest_selection_required")
	var species_id: String = ""
	var manifest_value: Variant = _planning_contract_payload.get("manifest", [])
	if typeof(manifest_value) == TYPE_ARRAY:
		for raw_entry: Variant in manifest_value:
			if typeof(raw_entry) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = raw_entry
			if String(entry.get("instance_id", "")) == _selected_manifest_instance:
				species_id = String(entry.get("species_id", ""))
				break
	return {
		"ok": true,
		"error": "",
		"instance_id": _selected_manifest_instance,
		"species_id": species_id,
		"species": _planning_species_by_id.get(species_id, {}),
		"placement": _placements_by_instance.get(_selected_manifest_instance, {}),
		"focus": [_focused_cell.x, _focused_cell.y],
	}

func planning_clear_selection() -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.PLANNING:
		return _fail("planning_not_active")
	_selected_manifest_instance = ""
	_refresh_planning_widgets()
	_render_planning_status()
	return {"ok": true, "error": ""}
