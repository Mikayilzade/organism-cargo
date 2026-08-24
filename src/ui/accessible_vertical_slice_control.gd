class_name AccessibleVerticalSliceControl
extends VerticalSliceControl

const AccessibilitySettingsModelScript := preload("res://src/ui/accessibility_settings_model.gd")
const CriticalSignalPresentationBuilderScript := preload("res://src/ui/critical_signal_presentation_builder.gd")

var _semantic_focus_label: Label
var _support_config_label: Label
var _accessibility_settings_model: Object = AccessibilitySettingsModelScript.new()
var _critical_signal_panel: VBoxContainer
var _critical_signal_summary: Label
var _critical_signal_list: VBoxContainer
var _critical_signals: Array = []

func configure(flow: VerticalSliceFlowCoordinator, context: Dictionary = {}) -> void:
	_load_accessibility_settings(context)
	super(flow, context)

func set_context(context: Dictionary) -> void:
	_load_accessibility_settings(context)
	super(context)

func sync_from_flow() -> void:
	super()
	_sync_critical_signal_panel()

func set_accessibility_settings(patch: Dictionary) -> Dictionary:
	if _accessibility_settings_model == null or not _accessibility_settings_model.has_method("apply_patch"):
		return {"ok": false, "error": "accessibility_settings_unavailable"}
	var applied_value: Variant = _accessibility_settings_model.call("apply_patch", patch)
	if not applied_value is Dictionary:
		return {"ok": false, "error": "invalid_accessibility_settings_result"}
	var applied: Dictionary = applied_value
	if bool(applied.get("ok", false)):
		var snapshot_value: Variant = _accessibility_settings_model.call("snapshot") if _accessibility_settings_model.has_method("snapshot") else {}
		if snapshot_value is Dictionary:
			_context["accessibility_settings"] = (snapshot_value as Dictionary).duplicate(true)
		_sync_critical_signal_panel()
	return applied

func critical_signal_snapshot() -> Array:
	return _critical_signals.duplicate(true)

func critical_signal_rendered_text() -> String:
	if _critical_signal_list == null:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	for child: Node in _critical_signal_list.get_children():
		if child is Label:
			lines.append((child as Label).text)
	return "\n".join(lines)

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

func _load_accessibility_settings(context: Dictionary) -> void:
	_accessibility_settings_model = AccessibilitySettingsModelScript.new()
	var settings_value: Variant = context.get("accessibility_settings", {})
	if typeof(settings_value) != TYPE_DICTIONARY:
		return
	var settings: Dictionary = settings_value
	if settings.is_empty() or _accessibility_settings_model == null or not _accessibility_settings_model.has_method("apply_patch"):
		return
	var applied_value: Variant = _accessibility_settings_model.call("apply_patch", settings)
	if not applied_value is Dictionary or not bool((applied_value as Dictionary).get("ok", false)):
		_accessibility_settings_model = AccessibilitySettingsModelScript.new()

func _sync_critical_signal_panel() -> void:
	_ensure_critical_signal_panel()
	if _critical_signal_panel == null:
		return
	_critical_signals.clear()
	if _flow == null:
		_critical_signal_panel.visible = false
		_clear_critical_signal_rows()
		return
	var state: int = _flow.current_state()
	if state != AppStateMachine.State.TRANSIT_PLAYBACK and state != AppStateMachine.State.CAUSAL_REVIEW:
		_critical_signal_panel.visible = false
		_clear_critical_signal_rows()
		return
	_critical_signal_panel.visible = true
	if state == AppStateMachine.State.TRANSIT_PLAYBACK:
		_critical_signal_summary.text = "TRANSIT SIGNALS — authoritative transit is resolving; critical cues remain visual and text-addressable."
		_clear_critical_signal_rows()
		return
	var builder: Object = CriticalSignalPresentationBuilderScript.new()
	if builder == null or not builder.has_method("build"):
		_critical_signal_summary.text = "CRITICAL TRANSIT / REVIEW SIGNALS — presentation unavailable."
		_clear_critical_signal_rows()
		return
	var built_value: Variant = builder.call(
		"build",
		_accessibility_settings_model,
		_flow.last_completed_result(),
		_flow.last_review(),
		_dictionary_context("simulation_defs")
	)
	_critical_signals = (built_value as Array).duplicate(true) if built_value is Array else []
	_render_critical_signal_rows()

func _render_critical_signal_rows() -> void:
	_clear_critical_signal_rows()
	if _critical_signal_summary == null or _critical_signal_list == null:
		return
	_critical_signal_summary.text = "CRITICAL TRANSIT / REVIEW SIGNALS — %d event(s). Audio is optional; source, label, icon, pattern and shape remain visible." % _critical_signals.size()
	for index: int in range(_critical_signals.size()):
		var signal_value: Variant = _critical_signals[index]
		if not signal_value is Dictionary:
			continue
		var row: Label = Label.new()
		row.name = "CriticalSignalRow%02d" % index
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = _critical_signal_row_text(signal_value)
		_critical_signal_list.add_child(row)

func _critical_signal_row_text(signal: Dictionary) -> String:
	var caption_line: String = String(signal.get("caption", "")) if bool(signal.get("caption_visible", false)) else "Caption disabled; visible source/label channels remain active."
	return "T%02d • %s • source=%s\n%s\nicon=%s • pattern=%s • shape=%s • motion=%s • flash=%s" % [
		int(signal.get("tick", 0)),
		String(signal.get("text_label", "EVENT")),
		String(signal.get("source", "System")),
		caption_line,
		String(signal.get("icon", "info")),
		String(signal.get("pattern", "solid_outline")),
		String(signal.get("shape", "outlined_badge")),
		String(signal.get("motion_mode", "standard")),
		String(signal.get("flash_mode", "bounded_fade")),
	]

func _clear_critical_signal_rows() -> void:
	if _critical_signal_list == null:
		return
	while _critical_signal_list.get_child_count() > 0:
		var child: Node = _critical_signal_list.get_child(0)
		_critical_signal_list.remove_child(child)
		child.queue_free()

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

func _ensure_critical_signal_panel() -> void:
	if _critical_signal_panel != null:
		return
	_critical_signal_panel = VBoxContainer.new()
	_critical_signal_panel.name = "CriticalSignalPanel"
	_critical_signal_panel.visible = false
	add_child(_critical_signal_panel)
	if _primary_button != null:
		move_child(_critical_signal_panel, _primary_button.get_index())
	_critical_signal_summary = Label.new()
	_critical_signal_summary.name = "CriticalSignalSummary"
	_critical_signal_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_critical_signal_panel.add_child(_critical_signal_summary)
	_critical_signal_list = VBoxContainer.new()
	_critical_signal_list.name = "CriticalSignalList"
	_critical_signal_panel.add_child(_critical_signal_list)
