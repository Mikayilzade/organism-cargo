class_name S02FilterKernel
extends RefCounted

func apply_phase_c(
		contamination_by_cell: Dictionary,
		committed_supports: Array,
		support_definitions_by_id: Dictionary,
		same_tick_effect_eligible_support_ids: PackedStringArray
) -> Dictionary:
	var result_contamination: Dictionary = contamination_by_cell.duplicate(true)
	var eligible: Dictionary = {}
	for instance_id: String in same_tick_effect_eligible_support_ids:
		eligible[instance_id] = true

	var filters: Array = []
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
		if String(definition.get("family", support_id)) != "S02":
			continue
		if not eligible.has(instance_id):
			continue
		if not bool(definition.get("powered", false)):
			return _failure("s02_powered_definition_required:%s" % support_id)
		var capacity: int = int(definition.get("contamination_removal_capacity", 0))
		if capacity <= 0:
			return _failure("invalid_s02_contamination_removal_capacity:%s" % support_id)
		var anchor_result: Dictionary = _anchor_cell_key(support)
		if not bool(anchor_result["ok"]):
			return _failure("%s:%s" % [String(anchor_result["error"]), instance_id])
		var cell_key: String = String(anchor_result["cell_key"])
		if not result_contamination.has(cell_key):
			return _failure("s02_anchor_outside_contamination_field:%s" % instance_id)
		filters.append({
			"instance_id": instance_id,
			"support_id": support_id,
			"cell_key": cell_key,
			"capacity": capacity,
		})

	filters.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)

	var events: Array = []
	for filter: Dictionary in filters:
		var cell_key: String = String(filter["cell_key"])
		var before: int = int(result_contamination[cell_key])
		var removed: int = mini(before, int(filter["capacity"]))
		result_contamination[cell_key] = before - removed
		events.append({
			"kind": "S02_FILTER_CONTAMINATION_REMOVAL",
			"phase": "C",
			"instance_id": String(filter["instance_id"]),
			"support_id": String(filter["support_id"]),
			"cell_key": cell_key,
			"capacity": int(filter["capacity"]),
			"removed_contamination": removed,
			"contamination_before": before,
			"contamination_after": int(result_contamination[cell_key]),
		})

	return {
		"ok": true,
		"error": "",
		"contamination_by_cell": result_contamination,
		"events": events,
	}

func _anchor_cell_key(support: Dictionary) -> Dictionary:
	var anchor_value: Variant = support.get("anchor", null)
	if not anchor_value is Array:
		return _failure("invalid_s02_anchor")
	var anchor: Array = anchor_value
	if anchor.size() != 2:
		return _failure("invalid_s02_anchor")
	return {
		"ok": true,
		"error": "",
		"cell_key": "%d,%d" % [int(anchor[0]), int(anchor[1])],
	}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
