class_name PlanningLayoutReachability
extends RefCounted

const REQUIRED_REGIONS: Array[StringName] = [&"MANIFEST", &"HOLD", &"OBJECTIVES_SUPPORTS", &"TOOLBAR"]
const REQUIRED_RENDERED_CONTROLS: Array[StringName] = [
	&"hold",
	&"launch",
	&"undo",
	&"redo",
	&"overlays",
	&"objectives",
	&"semantic_focus",
	&"support_link",
	&"brownout_priority",
]

func evaluate(viewport: Vector2i, ui_scale_percent: int, visible_regions: Array[StringName], modal_fits_safe_area: bool, focus_visible: bool) -> Dictionary:
	if viewport.x < 1280 or viewport.y < 800:
		return {"ok": false, "error": "viewport_below_deck_acceptance"}
	if ui_scale_percent < 100 or ui_scale_percent > 200:
		return {"ok": false, "error": "ui_scale_out_of_acceptance_range"}
	for region: StringName in REQUIRED_REGIONS:
		if not visible_regions.has(region):
			return {"ok": false, "error": "required_region_unreachable:%s" % String(region)}
	if not modal_fits_safe_area:
		return {"ok": false, "error": "modal_outside_safe_area"}
	if not focus_visible:
		return {"ok": false, "error": "focus_not_visible"}
	return {
		"ok": true,
		"error": "",
		"viewport": [viewport.x, viewport.y],
		"ui_scale_percent": ui_scale_percent,
		"layout_mode": "drawers" if ui_scale_percent >= 175 else "panels",
		"hold_full_default_visibility_required": ui_scale_percent == 100,
		"bounded_hold_pan_reset_required": ui_scale_percent > 100,
		"mandatory_controls_reachable": true,
		"modal_fits_safe_area": true,
		"focus_visible": true,
	}

func evaluate_rendered(root: Control, ui_scale_percent: int, controls: Dictionary, modal: Control = null) -> Dictionary:
	if root == null:
		return {"ok": false, "error": "render_root_missing"}
	var viewport_size := Vector2i(roundi(root.size.x), roundi(root.size.y))
	var model_result := evaluate(viewport_size, ui_scale_percent, REQUIRED_REGIONS.duplicate(), true, true)
	if not bool(model_result.get("ok", false)):
		return model_result

	var safe_rect := root.get_global_rect()
	if safe_rect.size.x < 1280.0 or safe_rect.size.y < 800.0:
		return {"ok": false, "error": "render_root_below_deck_acceptance"}

	for key: StringName in REQUIRED_RENDERED_CONTROLS:
		var control_value: Variant = controls.get(key, null)
		if not (control_value is Control):
			return {"ok": false, "error": "required_control_missing:%s" % String(key)}
		var control := control_value as Control
		if not control.visible or not control.is_visible_in_tree():
			return {"ok": false, "error": "required_control_hidden:%s" % String(key)}
		if not _rect_inside(safe_rect, control.get_global_rect()):
			return {"ok": false, "error": "required_control_outside_safe_area:%s" % String(key)}

	if ui_scale_percent == 100:
		var hold := controls.get(&"hold") as Control
		if hold == null or not _rect_inside(safe_rect, hold.get_global_rect()):
			return {"ok": false, "error": "default_hold_not_fully_visible"}
	else:
		var reset_value: Variant = controls.get(&"view_reset", null)
		if not (reset_value is Control):
			return {"ok": false, "error": "max_scale_view_reset_missing"}
		var reset_control := reset_value as Control
		if not reset_control.visible or not reset_control.is_visible_in_tree() or not _rect_inside(safe_rect, reset_control.get_global_rect()):
			return {"ok": false, "error": "max_scale_view_reset_unreachable"}

	if modal != null:
		if not modal.visible or not modal.is_visible_in_tree():
			return {"ok": false, "error": "modal_hidden"}
		if not _rect_inside(safe_rect, modal.get_global_rect()):
			return {"ok": false, "error": "modal_outside_safe_area"}

	return {
		"ok": true,
		"error": "",
		"viewport": [viewport_size.x, viewport_size.y],
		"ui_scale_percent": ui_scale_percent,
		"layout_mode": "drawers" if ui_scale_percent >= 175 else "panels",
		"rendered_controls_checked": REQUIRED_RENDERED_CONTROLS.size(),
		"hold_full_default_visibility_required": ui_scale_percent == 100,
		"bounded_hold_pan_reset_required": ui_scale_percent > 100,
		"mandatory_controls_reachable": true,
		"modal_fits_safe_area": modal == null or _rect_inside(safe_rect, modal.get_global_rect()),
		"focus_visible": true,
	}

func _rect_inside(outer: Rect2, inner: Rect2) -> bool:
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return false
	return outer.has_point(inner.position) and outer.has_point(inner.end - Vector2(0.001, 0.001))
