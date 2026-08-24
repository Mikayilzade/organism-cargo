class_name AccessibleVerticalSliceControl
extends VerticalSliceControl

var _semantic_focus_label: Label
var _support_config_label: Label

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

func planning_render_semantic_state(router_snapshot: Dictionary, support_snapshot: Dictionary, manifest_focus_id: String) -> void:
	_ensure_semantic_labels()
	var region: String = String(router_snapshot.get("region", "MANIFEST"))
	_semantic_focus_label.text = "FOCUS REGION: %s  •  Region Previous / Next changes region" % region
	_semantic_focus_label.visible = true

	_refresh_planning_widgets()
	if region == "MANIFEST" and not manifest_focus_id.is_empty() and _manifest_buttons.has(manifest_focus_id):
		var manifest_button: Button = _manifest_buttons[manifest_focus_id]
		manifest_button.text = "[FOCUS] %s" % manifest_button.text
		manifest_button.grab_focus()
	elif region == "HOLD":
		var focus_value: Variant = router_snapshot.get("hold_focus", [0, 0])
		if typeof(focus_value) == TYPE_ARRAY and (focus_value as Array).size() >= 2:
			var focus: Array = focus_value
			var key: String = _cell_key(int(focus[0]), int(focus[1]))
			if _cell_buttons.has(key):
				var cell_button: Button = _cell_buttons[key]
				cell_button.text = "[FOCUS] %s" % cell_button.text
				cell_button.grab_focus()

	var support_order_value: Variant = support_snapshot.get("support_order", [])
	var support_order: Array = support_order_value if typeof(support_order_value) == TYPE_ARRAY else []
	_support_config_label.visible = not support_order.is_empty()
	if support_order.is_empty():
		_support_config_label.text = ""
		return
	var selected_support: String = String(support_snapshot.get("selected_support_name", support_snapshot.get("selected_support_id", "")))
	var selected_target: String = String(support_snapshot.get("selected_target_id", "none"))
	var links_value: Variant = support_snapshot.get("links", [])
	var links: Array = links_value if typeof(links_value) == TYPE_ARRAY else []
	var link_text: String = "none"
	for raw_link: Variant in links:
		if typeof(raw_link) == TYPE_DICTIONARY and String((raw_link as Dictionary).get("source", "")) == String(support_snapshot.get("selected_support_id", "")):
			link_text = String((raw_link as Dictionary).get("target", "none"))
			break
	var power_value: Variant = support_snapshot.get("power_priority", [])
	var power_priority: Array = power_value if typeof(power_value) == TYPE_ARRAY else []
	var focus_prefix: String = "[FOCUS] " if region == "OBJECTIVES_SUPPORTS" else ""
	_support_config_label.text = "%sSUPPORT CONFIG — Source: %s • Target: %s • Linked: %s\nBrownout priority: %s\n%s" % [
		focus_prefix,
		selected_support,
		selected_target,
		link_text,
		" > ".join(power_priority),
		String(support_snapshot.get("instructions", "")),
	]

func _ensure_semantic_labels() -> void:
	if _planning_panel == null:
		return
	if _semantic_focus_label == null:
		_semantic_focus_label = Label.new()
		_semantic_focus_label.name = "SemanticFocusRegion"
		_semantic_focus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_planning_panel.add_child(_semantic_focus_label)
		_planning_panel.move_child(_semantic_focus_label, 0)
	if _support_config_label == null:
		_support_config_label = Label.new()
		_support_config_label.name = "SupportConfigStatus"
		_support_config_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_planning_panel.add_child(_support_config_label)
