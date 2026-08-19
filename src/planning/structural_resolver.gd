class_name StructuralResolver
extends RefCounted

static func resolve(
	contract_payload: Dictionary,
	hold_payload: Dictionary,
	species_by_id: Dictionary,
	canonical_input: Dictionary
) -> Dictionary:
	var width_result: Dictionary = _integral_int(hold_payload.get("width", null))
	var height_result: Dictionary = _integral_int(hold_payload.get("height", null))
	if not bool(width_result["ok"]) or not bool(height_result["ok"]):
		return _failure("invalid_hold_dimensions")
	var width: int = int(width_result["value"])
	var height: int = int(height_result["value"])
	if width <= 0 or height <= 0:
		return _failure("invalid_hold_dimensions")

	var supports_value: Variant = canonical_input.get("supports", [])
	if typeof(supports_value) != TYPE_ARRAY:
		return _failure("invalid_supports")
	var supports: Array = supports_value
	if not supports.is_empty():
		return _failure("support_resolution_not_implemented")

	var structural_prerequisites_value: Variant = contract_payload.get("structural_prerequisites", [])
	if typeof(structural_prerequisites_value) != TYPE_ARRAY:
		return _failure("invalid_structural_prerequisites")
	var structural_prerequisites: Array = structural_prerequisites_value
	if not structural_prerequisites.is_empty():
		return _failure("structural_prerequisite_resolution_not_implemented")

	var blocked_result: Dictionary = _cell_set(hold_payload.get("blocked_cells", []))
	if not bool(blocked_result["ok"]):
		return _failure("invalid_blocked_cells")
	var blocked_cells: Dictionary = blocked_result["cells"]

	var zones_result: Dictionary = _zone_cell_sets(hold_payload.get("zones", {}))
	if not bool(zones_result["ok"]):
		return _failure("invalid_zones")
	var zone_cells_by_id: Dictionary = zones_result["zones"]

	var manifest_value: Variant = contract_payload.get("manifest", [])
	if typeof(manifest_value) != TYPE_ARRAY:
		return _failure("invalid_manifest")
	var manifest: Array = manifest_value
	var species_by_instance: Dictionary = {}
	var mandatory_instances: Dictionary = {}
	var allowed_zones_by_instance: Dictionary = {}
	for raw_manifest_entry: Variant in manifest:
		if typeof(raw_manifest_entry) != TYPE_DICTIONARY:
			return _failure("invalid_manifest_entry")
		var manifest_entry: Dictionary = raw_manifest_entry
		var instance_id: String = String(manifest_entry.get("instance_id", "")).strip_edges()
		var species_id: String = String(manifest_entry.get("species_id", "")).strip_edges()
		if instance_id.is_empty() or species_id.is_empty() or species_by_instance.has(instance_id):
			return _failure("invalid_manifest_entry")
		species_by_instance[instance_id] = species_id
		if bool(manifest_entry.get("mandatory", true)):
			mandatory_instances[instance_id] = true

		var allowed_zones_value: Variant = manifest_entry.get("allowed_zone_ids", [])
		if typeof(allowed_zones_value) != TYPE_ARRAY:
			return _failure("invalid_zone_restriction")
		var allowed_zone_ids: Array = []
		var raw_allowed_zones: Array = allowed_zones_value
		for raw_allowed_zone_id: Variant in raw_allowed_zones:
			var allowed_zone_id: String = String(raw_allowed_zone_id).strip_edges()
			if allowed_zone_id.is_empty() or not zone_cells_by_id.has(allowed_zone_id):
				return _failure("invalid_zone_restriction")
			if not allowed_zone_ids.has(allowed_zone_id):
				allowed_zone_ids.append(allowed_zone_id)
		allowed_zones_by_instance[instance_id] = allowed_zone_ids

	var placements_value: Variant = canonical_input.get("placements", [])
	if typeof(placements_value) != TYPE_ARRAY:
		return _failure("invalid_placements")
	var placements: Array = placements_value
	var placement_counts: Dictionary = {}
	var occupied_cells: Dictionary = {}
	var overlap_free: bool = true
	var blocked_free: bool = true
	var in_bounds: bool = true
	var orientations_valid: bool = true
	var zones_valid: bool = true
	var structural_prerequisites_met: bool = true

	for raw_placement: Variant in placements:
		if typeof(raw_placement) != TYPE_DICTIONARY:
			return _failure("invalid_placement")
		var placement: Dictionary = raw_placement
		var instance_id: String = String(placement.get("instance_id", "")).strip_edges()
		if instance_id.is_empty() or not species_by_instance.has(instance_id):
			structural_prerequisites_met = false
			continue
		placement_counts[instance_id] = int(placement_counts.get(instance_id, 0)) + 1
		var species_id: String = String(species_by_instance[instance_id])
		if not species_by_id.has(species_id):
			structural_prerequisites_met = false
			continue
		var species_value: Variant = species_by_id[species_id]
		if typeof(species_value) != TYPE_DICTIONARY:
			return _failure("invalid_species_payload")
		var species: Dictionary = species_value

		var orientation_result: Dictionary = _integral_int(placement.get("orientation", null))
		if not bool(orientation_result["ok"]):
			orientations_valid = false
			continue
		var orientation: int = int(orientation_result["value"])
		if not _orientation_allowed(species, orientation):
			orientations_valid = false
			continue

		var footprints_value: Variant = species.get("current_footprints", {})
		if typeof(footprints_value) != TYPE_DICTIONARY:
			return _failure("invalid_current_footprints")
		var footprints: Dictionary = footprints_value
		var orientation_key: String = str(orientation)
		if not footprints.has(orientation_key):
			orientations_valid = false
			continue
		var offsets_value: Variant = footprints[orientation_key]
		if typeof(offsets_value) != TYPE_ARRAY:
			return _failure("invalid_current_footprint")
		var offsets: Array = offsets_value

		var allowed_zone_ids_value: Variant = allowed_zones_by_instance.get(instance_id, [])
		if typeof(allowed_zone_ids_value) != TYPE_ARRAY:
			return _failure("invalid_zone_restriction")
		var allowed_zone_ids: Array = allowed_zone_ids_value

		var anchor_result: Dictionary = _cell(placement.get("anchor", null))
		if not bool(anchor_result["ok"]):
			return _failure("invalid_anchor")
		var anchor_x: int = int(anchor_result["x"])
		var anchor_y: int = int(anchor_result["y"])
		for raw_offset: Variant in offsets:
			var offset_result: Dictionary = _cell(raw_offset)
			if not bool(offset_result["ok"]):
				return _failure("invalid_current_footprint")
			var x: int = anchor_x + int(offset_result["x"])
			var y: int = anchor_y + int(offset_result["y"])
			var key: String = _cell_key(x, y)
			if x < 0 or x >= width or y < 0 or y >= height:
				in_bounds = false
				continue
			if blocked_cells.has(key):
				blocked_free = false
			if occupied_cells.has(key):
				overlap_free = false
			else:
				occupied_cells[key] = instance_id
			if not allowed_zone_ids.is_empty() and not _cell_in_any_zone(key, allowed_zone_ids, zone_cells_by_id):
				zones_valid = false

	var mandatory_manifest_placed: bool = true
	for raw_instance_id: Variant in mandatory_instances.keys():
		var mandatory_instance_id: String = String(raw_instance_id)
		if int(placement_counts.get(mandatory_instance_id, 0)) != 1:
			mandatory_manifest_placed = false

	var allowance_result: Dictionary = _integral_int(contract_payload.get("support_allowance_max", 0))
	if not bool(allowance_result["ok"]):
		return _failure("invalid_support_allowance")
	var support_resources_valid: bool = supports.size() <= int(allowance_result["value"])
	var facts: Dictionary = {
		"mandatory_manifest_placed": mandatory_manifest_placed,
		"overlap_free": overlap_free,
		"blocked_free": blocked_free,
		"in_bounds": in_bounds,
		"orientations_valid": orientations_valid,
		"zones_valid": zones_valid,
		"fixtures_valid": true,
		"links_valid": true,
		"support_resources_valid": support_resources_valid,
		"structural_prerequisites_met": structural_prerequisites_met,
	}
	return {
		"ok": true,
		"error": "",
		"structural_facts": facts,
		"occupied_cells": occupied_cells.duplicate(true),
	}

static func _orientation_allowed(species: Dictionary, orientation: int) -> bool:
	var legal_value: Variant = species.get("legal_orientations", [])
	if typeof(legal_value) != TYPE_ARRAY:
		return false
	var legal_orientations: Array = legal_value
	for raw_orientation: Variant in legal_orientations:
		var parsed: Dictionary = _integral_int(raw_orientation)
		if bool(parsed["ok"]) and int(parsed["value"]) == orientation:
			return true
	return false

static func _zone_cell_sets(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "zones": {}}
	var zone_definitions: Dictionary = value
	var zone_cells_by_id: Dictionary = {}
	var raw_zone_ids: Array = zone_definitions.keys()
	raw_zone_ids.sort()
	for raw_zone_id: Variant in raw_zone_ids:
		var zone_id: String = String(raw_zone_id).strip_edges()
		if zone_id.is_empty():
			return {"ok": false, "zones": {}}
		var cells_result: Dictionary = _cell_set(zone_definitions[raw_zone_id])
		if not bool(cells_result["ok"]):
			return {"ok": false, "zones": {}}
		zone_cells_by_id[zone_id] = cells_result["cells"]
	return {"ok": true, "zones": zone_cells_by_id}

static func _cell_in_any_zone(key: String, allowed_zone_ids: Array, zone_cells_by_id: Dictionary) -> bool:
	for raw_zone_id: Variant in allowed_zone_ids:
		var zone_id: String = String(raw_zone_id)
		var zone_cells_value: Variant = zone_cells_by_id.get(zone_id, {})
		if typeof(zone_cells_value) != TYPE_DICTIONARY:
			continue
		var zone_cells: Dictionary = zone_cells_value
		if zone_cells.has(key):
			return true
	return false

static func _cell_set(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {"ok": false, "cells": {}}
	var cells: Dictionary = {}
	var raw_cells: Array = value
	for raw_cell: Variant in raw_cells:
		var parsed: Dictionary = _cell(raw_cell)
		if not bool(parsed["ok"]):
			return {"ok": false, "cells": {}}
		cells[_cell_key(int(parsed["x"]), int(parsed["y"]))] = true
	return {"ok": true, "cells": cells}

static func _cell(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {"ok": false, "x": 0, "y": 0}
	var pair: Array = value
	if pair.size() != 2:
		return {"ok": false, "x": 0, "y": 0}
	var x_result: Dictionary = _integral_int(pair[0])
	var y_result: Dictionary = _integral_int(pair[1])
	if not bool(x_result["ok"]) or not bool(y_result["ok"]):
		return {"ok": false, "x": 0, "y": 0}
	return {"ok": true, "x": int(x_result["value"]), "y": int(y_result["value"])}

static func _integral_int(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_INT:
		return {"ok": true, "value": int(value)}
	if typeof(value) == TYPE_FLOAT:
		var numeric: float = float(value)
		if is_finite(numeric) and numeric == floor(numeric):
			return {"ok": true, "value": int(numeric)}
	return {"ok": false, "value": 0}

static func _cell_key(x: int, y: int) -> String:
	return "%d:%d" % [x, y]

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error, "structural_facts": {}, "occupied_cells": {}}
