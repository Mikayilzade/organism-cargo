class_name ThermalResponseKernel
extends RefCounted

func propagate_heat(
		generated_heat: Dictionary,
		cell_order: PackedStringArray,
		rules: Dictionary
) -> Dictionary:
	var validation_error: String = _validate_heat_rules(generated_heat, cell_order, rules)
	if not validation_error.is_empty():
		return {"ok": false, "error": validation_error}

	var source_snapshot: Dictionary = {}
	for cell_key: String in cell_order:
		source_snapshot[cell_key] = int(generated_heat.get(cell_key, 0))
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
			return {"ok": false, "error": "heat_transfer_exceeds_source:%s" % cell_key}

	for raw_edge: Variant in transfer_edges:
		var edge: Dictionary = raw_edge
		var from_key: String = String(edge["from"])
		var to_key: String = String(edge["to"])
		var amount: int = int(edge["amount"])
		propagated[from_key] = int(propagated[from_key]) - amount
		propagated[to_key] = int(propagated[to_key]) + amount

	var vent_by_cell: Dictionary = rules.get("vent_by_cell", {})
	var heat_min: int = int(rules["heat_min"])
	var heat_max: int = int(rules["heat_max"])
	for cell_key: String in cell_order:
		var vent_amount: int = int(vent_by_cell.get(cell_key, 0))
		propagated[cell_key] = clampi(int(propagated[cell_key]) - vent_amount, heat_min, heat_max)

	return {"ok": true, "error": "", "heat_by_cell": propagated}

func apply_heat_response(
		organisms: Array,
		heat_by_cell: Dictionary
) -> Dictionary:
	var ordered: Array = organisms.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))
	)
	var results: Array = []
	for raw_organism: Variant in ordered:
		if not raw_organism is Dictionary:
			return {"ok": false, "error": "invalid_organism_runtime"}
		var organism: Dictionary = raw_organism
		var validated: Dictionary = _validate_organism(organism, heat_by_cell)
		if not bool(validated["ok"]):
			return validated
		var occupied_cells: Array = organism["occupied_cells"]
		var exposure: int = 0
		for raw_cell: Variant in occupied_cells:
			var cell_key: String = String(raw_cell)
			exposure = maxi(exposure, int(heat_by_cell[cell_key]))

		var stress_profile: Dictionary = organism["stress_profile"]
		var heat_safe_max: int = int(stress_profile["heat_safe_max"])
		var stress_per_heat_unit: int = int(stress_profile["stress_per_heat_unit"])
		var heat_excess: int = maxi(0, exposure - heat_safe_max)
		var stress_delta: int = heat_excess * stress_per_heat_unit
		var stress_min: int = int(stress_profile["stress_min"])
		var stress_max: int = int(stress_profile["stress_max"])
		var previous_stress: int = int(organism["stress"])
		var next_stress: int = clampi(previous_stress + stress_delta, stress_min, stress_max)
		var previous_state: String = String(organism["primary_state"])
		var next_state_result: Dictionary = _next_primary_state(previous_state, next_stress, stress_profile)
		if not bool(next_state_result["ok"]):
			return next_state_result
		results.append({
			"instance_id": String(organism["instance_id"]),
			"heat_exposure": exposure,
			"stress_delta": stress_delta,
			"stress": next_stress,
			"primary_state": String(next_state_result["state"]),
		})
	return {"ok": true, "error": "", "organisms": results}

func _validate_heat_rules(generated_heat: Dictionary, cell_order: PackedStringArray, rules: Dictionary) -> String:
	if not rules.has("heat_min") or not rules.has("heat_max"):
		return "missing_heat_bounds"
	var heat_min: int = int(rules["heat_min"])
	var heat_max: int = int(rules["heat_max"])
	if heat_min > heat_max:
		return "invalid_heat_bounds"
	var cell_set: Dictionary = {}
	for cell_key: String in cell_order:
		if not generated_heat.has(cell_key):
			return "missing_heat_cell:%s" % cell_key
		cell_set[cell_key] = true
	var transfer_edges: Array = rules.get("transfer_edges", [])
	for raw_edge: Variant in transfer_edges:
		if not raw_edge is Dictionary:
			return "invalid_heat_transfer_edge"
		var edge: Dictionary = raw_edge
		var from_key: String = String(edge.get("from", ""))
		var to_key: String = String(edge.get("to", ""))
		var amount: int = int(edge.get("amount", -1))
		if not cell_set.has(from_key) or not cell_set.has(to_key) or amount < 0:
			return "invalid_heat_transfer_edge"
		if not _orthogonally_adjacent(from_key, to_key):
			return "non_orthogonal_heat_transfer:%s>%s" % [from_key, to_key]
	var vent_by_cell: Dictionary = rules.get("vent_by_cell", {})
	for raw_key: Variant in vent_by_cell.keys():
		var cell_key: String = String(raw_key)
		if not cell_set.has(cell_key) or int(vent_by_cell[raw_key]) < 0:
			return "invalid_heat_vent:%s" % cell_key
	return ""

func _validate_organism(organism: Dictionary, heat_by_cell: Dictionary) -> Dictionary:
	var instance_id: String = String(organism.get("instance_id", ""))
	if instance_id.is_empty():
		return {"ok": false, "error": "missing_organism_instance_id"}
	if not organism.has("occupied_cells") or not organism["occupied_cells"] is Array:
		return {"ok": false, "error": "invalid_occupied_cells:%s" % instance_id}
	var occupied_cells: Array = organism["occupied_cells"]
	if occupied_cells.is_empty():
		return {"ok": false, "error": "invalid_occupied_cells:%s" % instance_id}
	for raw_cell: Variant in occupied_cells:
		var cell_key: String = String(raw_cell)
		if not heat_by_cell.has(cell_key):
			return {"ok": false, "error": "organism_cell_missing_from_heat:%s:%s" % [instance_id, cell_key]}
	if not organism.has("stress_profile") or not organism["stress_profile"] is Dictionary:
		return {"ok": false, "error": "missing_stress_profile:%s" % instance_id}
	var profile: Dictionary = organism["stress_profile"]
	for key: String in PackedStringArray([
		"heat_safe_max", "stress_per_heat_unit", "stress_min", "stress_max",
		"agitated_enter", "agitated_exit", "panic_enter", "panic_exit"
	]):
		if not profile.has(key):
			return {"ok": false, "error": "missing_stress_profile_field:%s:%s" % [instance_id, key]}
	var stress_min: int = int(profile["stress_min"])
	var stress_max: int = int(profile["stress_max"])
	var agitated_enter: int = int(profile["agitated_enter"])
	var agitated_exit: int = int(profile["agitated_exit"])
	var panic_enter: int = int(profile["panic_enter"])
	var panic_exit: int = int(profile["panic_exit"])
	if stress_min > stress_max or int(profile["stress_per_heat_unit"]) < 0:
		return {"ok": false, "error": "invalid_stress_profile:%s" % instance_id}
	if not (panic_enter > panic_exit and panic_exit >= agitated_enter and agitated_enter > agitated_exit and agitated_exit >= stress_min):
		return {"ok": false, "error": "invalid_stress_hysteresis:%s" % instance_id}
	if panic_enter > stress_max:
		return {"ok": false, "error": "panic_threshold_out_of_range:%s" % instance_id}
	var primary_state: String = String(organism.get("primary_state", ""))
	if not primary_state in ["CALM", "AGITATED", "PANICKED", "ASLEEP"]:
		return {"ok": false, "error": "slice_primary_state_not_implemented:%s" % primary_state}
	return {"ok": true, "error": ""}

func _next_primary_state(previous_state: String, stress: int, profile: Dictionary) -> Dictionary:
	if previous_state == "ASLEEP":
		return {"ok": true, "error": "", "state": "ASLEEP"}
	var agitated_enter: int = int(profile["agitated_enter"])
	var agitated_exit: int = int(profile["agitated_exit"])
	var panic_enter: int = int(profile["panic_enter"])
	var panic_exit: int = int(profile["panic_exit"])
	if previous_state == "PANICKED":
		if stress >= panic_exit:
			return {"ok": true, "error": "", "state": "PANICKED"}
		if stress >= agitated_exit:
			return {"ok": true, "error": "", "state": "AGITATED"}
		return {"ok": true, "error": "", "state": "CALM"}
	if previous_state == "AGITATED":
		if stress >= panic_enter:
			return {"ok": true, "error": "", "state": "PANICKED"}
		if stress >= agitated_exit:
			return {"ok": true, "error": "", "state": "AGITATED"}
		return {"ok": true, "error": "", "state": "CALM"}
	if stress >= panic_enter:
		return {"ok": true, "error": "", "state": "PANICKED"}
	if stress >= agitated_enter:
		return {"ok": true, "error": "", "state": "AGITATED"}
	return {"ok": true, "error": "", "state": "CALM"}

func _orthogonally_adjacent(left_key: String, right_key: String) -> bool:
	var left: PackedStringArray = left_key.split(",")
	var right: PackedStringArray = right_key.split(",")
	if left.size() != 2 or right.size() != 2:
		return false
	var dx: int = absi(int(left[0]) - int(right[0]))
	var dy: int = absi(int(left[1]) - int(right[1]))
	return dx + dy == 1
