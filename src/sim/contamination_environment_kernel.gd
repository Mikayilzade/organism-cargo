class_name ContaminationEnvironmentKernel
extends RefCounted

func apply_h03_phase_c(
		contamination_by_cell: Dictionary,
		cell_order: PackedStringArray,
		active_hazards: PackedStringArray,
		hazards_by_id: Dictionary
) -> Dictionary:
	var validation_error: String = _validate_field(contamination_by_cell, cell_order)
	if not validation_error.is_empty():
		return _failure(validation_error)

	var result_contamination: Dictionary = contamination_by_cell.duplicate(true)
	var ordered_hazards: PackedStringArray = active_hazards.duplicate()
	ordered_hazards.sort()
	var events: Array = []

	for hazard_id: String in ordered_hazards:
		if not hazards_by_id.has(hazard_id) or not hazards_by_id[hazard_id] is Dictionary:
			return _failure("missing_hazard_definition:%s" % hazard_id)
		var hazard: Dictionary = hazards_by_id[hazard_id]
		if String(hazard.get("family", "")) != "H03":
			continue
		var contamination_delta: int = int(hazard.get("contamination_delta", 0))
		if contamination_delta < 0:
			return _failure("invalid_h03_contamination_delta:%s" % hazard_id)
		var target_cells_value: Variant = hazard.get("target_cells", [])
		if not target_cells_value is Array:
			return _failure("invalid_h03_target_cells:%s" % hazard_id)
		var target_cells: Array = []
		for raw_target_cell: Variant in target_cells_value:
			target_cells.append(raw_target_cell)
		target_cells.sort_custom(func(left: Variant, right: Variant) -> bool:
			return String(left) < String(right)
		)
		for raw_cell: Variant in target_cells:
			var cell_key: String = String(raw_cell)
			if not result_contamination.has(cell_key):
				return _failure("h03_target_outside_contamination_field:%s:%s" % [hazard_id, cell_key])
			var before: int = int(result_contamination[cell_key])
			result_contamination[cell_key] = before + contamination_delta
			events.append({
				"kind": "H03_CONTAMINATION_SOURCE",
				"phase": "C",
				"hazard_id": hazard_id,
				"cell_key": cell_key,
				"contamination_delta": contamination_delta,
				"contamination_before": before,
				"contamination_after": int(result_contamination[cell_key]),
			})

	return {
		"ok": true,
		"error": "",
		"contamination_by_cell": result_contamination,
		"events": events,
	}

func propagate_phase_d(
		generated_contamination: Dictionary,
		cell_order: PackedStringArray,
		rules: Dictionary
) -> Dictionary:
	var validation_error: String = _validate_phase_d_rules(generated_contamination, cell_order, rules)
	if not validation_error.is_empty():
		return _failure(validation_error)

	var source_snapshot: Dictionary = {}
	for cell_key: String in cell_order:
		source_snapshot[cell_key] = int(generated_contamination[cell_key])
	var propagated: Dictionary = source_snapshot.duplicate(true)

	var outgoing_by_cell: Dictionary = {}
	var transfer_edges: Array = rules.get("transfer_edges", [])
	for raw_edge: Variant in transfer_edges:
		var edge: Dictionary = raw_edge
		var from_key: String = String(edge["from"])
		var amount: int = int(edge["amount"])
		outgoing_by_cell[from_key] = int(outgoing_by_cell.get(from_key, 0)) + amount

	for cell_key: String in cell_order:
		if int(outgoing_by_cell.get(cell_key, 0)) > int(source_snapshot[cell_key]):
			return _failure("contamination_transfer_exceeds_source:%s" % cell_key)

	for raw_edge: Variant in transfer_edges:
		var edge: Dictionary = raw_edge
		var from_key: String = String(edge["from"])
		var to_key: String = String(edge["to"])
		var amount: int = int(edge["amount"])
		propagated[from_key] = int(propagated[from_key]) - amount
		propagated[to_key] = int(propagated[to_key]) + amount

	var vent_by_cell: Dictionary = rules.get("vent_by_cell", {})
	var contamination_min: int = int(rules["contamination_min"])
	var contamination_max: int = int(rules["contamination_max"])
	for cell_key: String in cell_order:
		var vent_amount: int = int(vent_by_cell.get(cell_key, 0))
		propagated[cell_key] = clampi(
			int(propagated[cell_key]) - vent_amount,
			contamination_min,
			contamination_max
		)

	return {
		"ok": true,
		"error": "",
		"contamination_by_cell": propagated,
	}

func _validate_phase_d_rules(
		generated_contamination: Dictionary,
		cell_order: PackedStringArray,
		rules: Dictionary
) -> String:
	var field_error: String = _validate_field(generated_contamination, cell_order)
	if not field_error.is_empty():
		return field_error
	if not rules.has("contamination_min") or not rules.has("contamination_max"):
		return "missing_contamination_bounds"
	var contamination_min: int = int(rules["contamination_min"])
	var contamination_max: int = int(rules["contamination_max"])
	if contamination_min > contamination_max:
		return "invalid_contamination_bounds"

	var cell_set: Dictionary = {}
	for cell_key: String in cell_order:
		cell_set[cell_key] = true

	var transfer_edges_value: Variant = rules.get("transfer_edges", [])
	if not transfer_edges_value is Array:
		return "invalid_contamination_transfer_edges"
	var transfer_edges: Array = transfer_edges_value
	for raw_edge: Variant in transfer_edges:
		if not raw_edge is Dictionary:
			return "invalid_contamination_transfer_edge"
		var edge: Dictionary = raw_edge
		var from_key: String = String(edge.get("from", ""))
		var to_key: String = String(edge.get("to", ""))
		var amount: int = int(edge.get("amount", -1))
		if not cell_set.has(from_key) or not cell_set.has(to_key) or amount < 0:
			return "invalid_contamination_transfer_edge"
		if not _orthogonally_adjacent(from_key, to_key):
			return "non_orthogonal_contamination_transfer:%s>%s" % [from_key, to_key]

	var vent_value: Variant = rules.get("vent_by_cell", {})
	if not vent_value is Dictionary:
		return "invalid_contamination_vent_map"
	var vent_by_cell: Dictionary = vent_value
	for raw_key: Variant in vent_by_cell.keys():
		var cell_key: String = String(raw_key)
		if not cell_set.has(cell_key) or int(vent_by_cell[raw_key]) < 0:
			return "invalid_contamination_vent:%s" % cell_key
	return ""

func _validate_field(contamination_by_cell: Dictionary, cell_order: PackedStringArray) -> String:
	if cell_order.is_empty():
		return "missing_contamination_cell_order"
	var seen: Dictionary = {}
	for cell_key: String in cell_order:
		if cell_key.is_empty() or seen.has(cell_key):
			return "invalid_contamination_cell_order"
		if not contamination_by_cell.has(cell_key):
			return "missing_contamination_cell:%s" % cell_key
		if int(contamination_by_cell[cell_key]) < 0:
			return "negative_contamination:%s" % cell_key
		seen[cell_key] = true
	return ""

func _orthogonally_adjacent(left_key: String, right_key: String) -> bool:
	var left: PackedStringArray = left_key.split(",")
	var right: PackedStringArray = right_key.split(",")
	if left.size() != 2 or right.size() != 2:
		return false
	var dx: int = absi(int(left[0]) - int(right[0]))
	var dy: int = absi(int(left[1]) - int(right[1]))
	return dx + dy == 1

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
