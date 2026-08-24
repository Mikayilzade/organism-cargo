class_name PlanningLayoutReachability
extends RefCounted

const REQUIRED_REGIONS: Array[StringName] = [&"MANIFEST", &"HOLD", &"OBJECTIVES_SUPPORTS", &"TOOLBAR"]

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
