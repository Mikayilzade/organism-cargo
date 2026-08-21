class_name StressFieldEnvironmentKernel
extends RefCounted

func apply_h02_phase_c(
		stress_field_by_cell: Dictionary,
		cell_order: PackedStringArray,
		active_hazards: PackedStringArray,
		hazards_by_id: Dictionary
) -> Dictionary:
	var validation_error: String = _validate_field(stress_field_by_cell, cell_order)
	if not validation_error.is_empty():
		return _failure(validation_error)
	var result_field: Dictionary = stress_field_by_cell.duplicate(true)
	var ordered_hazards: PackedStringArray = active_hazards.duplicate()
	ordered_hazards.sort()
	var events: Array = []
	for hazard_id: String in ordered_hazards:
		if not hazards_by_id.has(hazard_id) or not hazards_by_id[hazard_id] is Dictionary:
			return _failure("missing_hazard_definition:%s" % hazard_id)
		var hazard: Dictionary = hazards_by_id[hazard_id]
		if String(hazard.get("family", "")) != "H02":
			continue
		var stress_delta: int = int(hazard.get("stress_field_delta", 0))
		if stress_delta < 0:
			return _failure("invalid_h02_stress_field_delta:%s" % hazard_id)
		var target_cells_value: Variant = hazard.get("target_cells", [])
		if not target_cells_value is Array:
			return _failure("invalid_h02_target_cells:%s" % hazard_id)
		var target_cells: Array = []
		for raw_target_cell: Variant in target_cells_value:
			target_cells.append(raw_target_cell)
		target_cells.sort_custom(func(left: Variant, right: Variant) -> bool:
			return String(left) < String(right)
		)
		for raw_cell: Variant in target_cells:
			var cell_key: String = String(raw_cell)
			if not result_field.has(cell_key):
				return _failure("h02_target_outside_stress_field:%s:%s" % [hazard_id, cell_key])
			var before: int = int(result_field[cell_key])
			result_field[cell_key] = before + stress_delta
			events.append({
				"kind": "H02_STRESS_FIELD_SOURCE",
				"phase": "C",
				"hazard_id": hazard_id,
				"cell_key": cell_key,
				"stress_field_delta": stress_delta,
				"stress_field_before": before,
				"stress_field_after": int(result_field[cell_key]),
			})
	return {"ok": true, "error": "", "stress_field_by_cell": result_field, "events": events}

func propagate_phase_d(
		generated_stress_field: Dictionary,
		cell_order: PackedStringArray,
		rules: Dictionary
) -> Dictionary:
	var validation_error: String = _validate_phase_d_rules(generated_stress_field, cell_order, rules)
	if not validation_error.is_empty():
		return _failure(validation_error)
	var source_snapshot: Dictionary = {}
	for cell_key: String in cell_order:
		source_snapshot[cell_key] = int(generated_stress_field[cell_key])
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
			return _failure("stress_field_transfer_exceeds_source:%s" % cell_key)
	for raw_edge: Variant in transfer_edges:
		var edge: Dictionary = raw_edge
		var from_key: String = String(edge["from"])
		var to_key: String = String(edge["to"])
		var amount: int = int(edge["amount"])
		propagated[from_key] = int(propagated[from_key]) - amount
		propagated[to_key] = int(propagated[to_key]) + amount
	var decay_by_cell: Dictionary = rules.get("decay_by_cell", {})
	var stress_min: int = int(rules["stress_field_min"])
	var stress_max: int = int(rules["stress_field_max"])
	for cell_key: String in cell_order:
		var decay_amount: int = int(decay_by_cell.get(cell_key, 0))
		propagated[cell_key] = clampi(int(propagated[cell_key]) - decay_amount, stress_min, stress_max)
	return {"ok": true, "error": "", "stress_field_by_cell": propagated}

func _validate_phase_d_rules(field: Dictionary, cell_order: PackedStringArray, rules: Dictionary) -> String:
	var field_error: String = _validate_field(field, cell_order)
	if not field_error.is_empty():
		return field_error
	if not rules.has("stress_field_min") or not rules.has("stress_field_max"):
		return "missing_stress_field_bounds"
	var stress_min: int = int(rules["stress_field_min"])
	var stress_max: int = int(rules["stress_field_max"])
	if stress_min > stress_max:
		return "invalid_stress_field_bounds"
	var cell_set: Dictionary = {}
	for cell_key: String in cell_order:
		cell_set[cell_key] = true
	var transfer_value: Variant = rules.get("transfer_edges", [])
	if not transfer_value is Array:
		return "invalid_stress_field_transfer_edges"
	var transfer_edges: Array = transfer_value
	for raw_edge: Variant in transfer_edges:
		if not raw_edge is Dictionary:
			return "invalid_stress_field_transfer_edge"
		var edge: Dictionary = raw_edge
		var from_key: String = String(edge.get("from", ""))
		var to_key: String = String(edge.get("to", ""))
		var amount: int = int(edge.get("amount", -1))
		if not cell_set.has(from_key) or not cell_set.has(to_key) or amount < 0:
			return "invalid_stress_field_transfer_edge"
		if not _orthogonally_adjacent(from_key, to_key):
			return "non_orthogonal_stress_field_transfer:%s>%s" % [from_key, to_key]
	var decay_value: Variant = rules.get("decay_by_cell", {})
	if not decay_value is Dictionary:
		return "invalid_stress_field_decay_map"
	var decay_by_cell: Dictionary = decay_value
	for raw_key: Variant in decay_by_cell.keys():
		var cell_key: String = String(raw_key)
		if not cell_set.has(cell_key) or int(decay_by_cell[raw_key]) < 0:
			return "invalid_stress_field_decay:%s" % cell_key
	return ""

func _validate_field(field: Dictionary, cell_order: PackedStringArray) -> String:
	if cell_order.is_empty():
		return "missing_stress_field_cell_order"
	var seen: Dictionary = {}
	for cell_key: String in cell_order:
		if cell_key.is_empty() or seen.has(cell_key):
			return "invalid_stress_field_cell_order"
		if not field.has(cell_key):
			return "missing_stress_field_cell:%s" % cell_key
		if int(field[cell_key]) < 0:
			return "negative_stress_field:%s" % cell_key
		seen[cell_key] = true
	return ""

func _orthogonally_adjacent(left_key: String, right_key: String) -> bool:
	var left: PackedStringArray = left_key.split(",")
	var right: PackedStringArray = right_key.split(",")
	if left.size() != 2 or right.size() != 2:
		return false
	return absi(int(left[0]) - int(right[0])) + absi(int(left[1]) - int(right[1])) == 1

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
