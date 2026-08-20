class_name S01CoolerKernel
extends RefCounted

func apply_phase_c(
		heat_by_cell: Dictionary,
		committed_supports: Array,
		support_definitions_by_id: Dictionary,
		same_tick_effect_eligible_support_ids: PackedStringArray
) -> Dictionary:
	var result_heat: Dictionary = heat_by_cell.duplicate(true)
	var eligible: Dictionary = {}
	for instance_id: String in same_tick_effect_eligible_support_ids:
		eligible[instance_id] = true

	var coolers: Array = []
	for raw_support: Variant in committed_supports:
		if not raw_support is Dictionary:
			return _failure("invalid_committed_support")
		var support: Dictionary = raw_support
		var instance_id: String = String(support.get("instance_id", ""))
		var support_id: String = String(support.get("support_id", ""))
		if instance_id.is_empty() or support_id.is_empty():
			return _failure("invalid_committed_support_identity")
		if not support_definitions_by_id.has(support_id) or not support_definitions_by_id[support_id] is Dictionary:
			return _failure("missing_support_definition:%s" % support_id)
		var definition: Dictionary = support_definitions_by_id[support_id]
		if String(definition.get("family", support_id)) != "S01":
			continue
		if not eligible.has(instance_id):
			continue
		if not bool(definition.get("powered", false)):
			return _failure("s01_powered_definition_required:%s" % support_id)
		var capacity: int = int(definition.get("heat_removal_capacity", 0))
		if capacity <= 0:
			return _failure("invalid_s01_heat_removal_capacity:%s" % support_id)
		var anchor_result: Dictionary = _anchor_cell_key(support)
		if not bool(anchor_result["ok"]):
			return _failure("%s:%s" % [String(anchor_result["error"]), instance_id])
		var cell_key: String = String(anchor_result["cell_key"])
		if not result_heat.has(cell_key):
			return _failure("s01_anchor_outside_heat_field:%s" % instance_id)
		coolers.append({
			"instance_id": instance_id,
			"support_id": support_id,
			"cell_key": cell_key,
			"capacity": capacity,
		})

	coolers.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)

	var events: Array = []
	for cooler: Dictionary in coolers:
		var cell_key: String = String(cooler["cell_key"])
		var before: int = int(result_heat[cell_key])
		var removed: int = mini(before, int(cooler["capacity"]))
		result_heat[cell_key] = before - removed
		events.append({
			"kind": "S01_COOLER_HEAT_REMOVAL",
			"phase": "C",
			"instance_id": String(cooler["instance_id"]),
			"support_id": String(cooler["support_id"]),
			"cell_key": cell_key,
			"capacity": int(cooler["capacity"]),
			"removed_heat": removed,
			"heat_before": before,
			"heat_after": int(result_heat[cell_key]),
		})

	return {
		"ok": true,
		"error": "",
		"heat_by_cell": result_heat,
		"events": events,
	}

func _anchor_cell_key(support: Dictionary) -> Dictionary:
	var anchor_value: Variant = support.get("anchor", null)
	if not anchor_value is Array:
		return _failure("invalid_s01_anchor")
	var anchor: Array = anchor_value
	if anchor.size() != 2:
		return _failure("invalid_s01_anchor")
	return {
		"ok": true,
		"error": "",
		"cell_key": "%d,%d" % [int(anchor[0]), int(anchor[1])],
	}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
