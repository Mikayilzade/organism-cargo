class_name S03BaffleKernel
extends RefCounted

func apply_phase_d_transmission(base_rules: Dictionary, blocked_boundaries: Array) -> Dictionary:
	var transfer_value: Variant = base_rules.get("transfer_edges", [])
	if not transfer_value is Array:
		return _failure("invalid_s03_transfer_edges")
	var boundary_result: Dictionary = _normalized_boundaries(blocked_boundaries)
	if not bool(boundary_result.get("ok", false)):
		return boundary_result
	var boundary_by_key: Dictionary = boundary_result["boundary_by_key"]
	var retained_edges: Array = []
	var events: Array = []
	for raw_edge: Variant in transfer_value:
		if not raw_edge is Dictionary:
			return _failure("invalid_s03_transfer_edge")
		var edge: Dictionary = raw_edge
		var from_key: String = String(edge.get("from", ""))
		var to_key: String = String(edge.get("to", ""))
		var amount: int = int(edge.get("amount", -1))
		if from_key.is_empty() or to_key.is_empty() or amount < 0:
			return _failure("invalid_s03_transfer_edge")
		var edge_key: String = _boundary_key(from_key, to_key)
		if boundary_by_key.has(edge_key):
			var boundary: Dictionary = boundary_by_key[edge_key]
			events.append({
				"kind": "S03_STRESS_TRANSFER_BLOCKED",
				"phase": "D",
				"support_instance_id": String(boundary.get("support_instance_id", "")),
				"from": from_key,
				"to": to_key,
				"amount": amount,
			})
			continue
		retained_edges.append(edge.duplicate(true))
	var modified_rules: Dictionary = base_rules.duplicate(true)
	modified_rules["transfer_edges"] = retained_edges
	return {
		"ok": true,
		"error": "",
		"rules": modified_rules,
		"events": events,
		"checksum_material": _serialize_transmission(retained_edges, events),
	}

func clip_directed_ray(ray_cells: PackedStringArray, blockers: Array) -> Dictionary:
	var blocker_result: Dictionary = _normalized_blockers(blockers)
	if not bool(blocker_result.get("ok", false)):
		return blocker_result
	var blocker_by_cell: Dictionary = blocker_result["blocker_by_cell"]
	var visible_cells: PackedStringArray = PackedStringArray()
	var events: Array = []
	var previous: String = ""
	for cell_key: String in ray_cells:
		if cell_key.is_empty():
			return _failure("invalid_s03_directed_ray_cell")
		if not previous.is_empty() and not _orthogonally_adjacent(previous, cell_key):
			return _failure("non_contiguous_s03_directed_ray:%s>%s" % [previous, cell_key])
		if blocker_by_cell.has(cell_key):
			var blocker: Dictionary = blocker_by_cell[cell_key]
			events.append({
				"kind": "S03_DIRECTED_RAY_BLOCKED",
				"phase": "E",
				"support_instance_id": String(blocker.get("support_instance_id", "")),
				"cell_key": cell_key,
			})
			break
		visible_cells.append(cell_key)
		previous = cell_key
	return {
		"ok": true,
		"error": "",
		"visible_cells": visible_cells,
		"events": events,
		"checksum_material": _serialize_directed(visible_cells, events),
	}

func _normalized_boundaries(blocked_boundaries: Array) -> Dictionary:
	var ordered: Array = []
	for raw_boundary: Variant in blocked_boundaries:
		if not raw_boundary is Dictionary:
			return _failure("invalid_s03_boundary")
		var boundary: Dictionary = raw_boundary
		var support_instance_id: String = String(boundary.get("support_instance_id", ""))
		var left: String = String(boundary.get("a", ""))
		var right: String = String(boundary.get("b", ""))
		if support_instance_id.is_empty() or left.is_empty() or right.is_empty():
			return _failure("invalid_s03_boundary")
		if not _orthogonally_adjacent(left, right):
			return _failure("non_orthogonal_s03_boundary:%s>%s" % [left, right])
		ordered.append(boundary.duplicate(true))
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_key: String = _boundary_key(String(left.get("a", "")), String(left.get("b", "")))
		var right_key: String = _boundary_key(String(right.get("a", "")), String(right.get("b", "")))
		if left_key != right_key:
			return left_key < right_key
		return String(left.get("support_instance_id", "")) < String(right.get("support_instance_id", ""))
	)
	var boundary_by_key: Dictionary = {}
	for boundary: Dictionary in ordered:
		var key: String = _boundary_key(String(boundary["a"]), String(boundary["b"]))
		if boundary_by_key.has(key):
			return _failure("duplicate_s03_boundary:%s" % key)
		boundary_by_key[key] = boundary
	return {"ok": true, "error": "", "boundary_by_key": boundary_by_key}

func _normalized_blockers(blockers: Array) -> Dictionary:
	var ordered: Array = []
	for raw_blocker: Variant in blockers:
		if not raw_blocker is Dictionary:
			return _failure("invalid_s03_directed_blocker")
		var blocker: Dictionary = raw_blocker
		var support_instance_id: String = String(blocker.get("support_instance_id", ""))
		var cell_key: String = String(blocker.get("cell_key", ""))
		if support_instance_id.is_empty() or cell_key.is_empty():
			return _failure("invalid_s03_directed_blocker")
		ordered.append(blocker.duplicate(true))
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_cell: String = String(left.get("cell_key", ""))
		var right_cell: String = String(right.get("cell_key", ""))
		if left_cell != right_cell:
			return left_cell < right_cell
		return String(left.get("support_instance_id", "")) < String(right.get("support_instance_id", ""))
	)
	var blocker_by_cell: Dictionary = {}
	for blocker: Dictionary in ordered:
		var cell_key: String = String(blocker["cell_key"])
		if blocker_by_cell.has(cell_key):
			return _failure("duplicate_s03_directed_blocker:%s" % cell_key)
		blocker_by_cell[cell_key] = blocker
	return {"ok": true, "error": "", "blocker_by_cell": blocker_by_cell}

func _boundary_key(left: String, right: String) -> String:
	if left < right:
		return "%s|%s" % [left, right]
	return "%s|%s" % [right, left]

func _orthogonally_adjacent(left_key: String, right_key: String) -> bool:
	var left: PackedStringArray = left_key.split(",")
	var right: PackedStringArray = right_key.split(",")
	if left.size() != 2 or right.size() != 2:
		return false
	return absi(int(left[0]) - int(right[0])) + absi(int(left[1]) - int(right[1])) == 1

func _serialize_transmission(edges: Array, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for edge: Dictionary in edges:
		parts.append("edge:%s>%s:%d" % [String(edge.get("from", "")), String(edge.get("to", "")), int(edge.get("amount", 0))])
	for event: Dictionary in events:
		parts.append("block:%s:%s>%s:%d" % [String(event.get("support_instance_id", "")), String(event.get("from", "")), String(event.get("to", "")), int(event.get("amount", 0))])
	return "|".join(parts)

func _serialize_directed(cells: PackedStringArray, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for cell_key: String in cells:
		parts.append("cell:%s" % cell_key)
	for event: Dictionary in events:
		parts.append("block:%s:%s" % [String(event.get("support_instance_id", "")), String(event.get("cell_key", ""))])
	return "|".join(parts)

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error, "rules": {}, "visible_cells": PackedStringArray(), "events": [], "checksum_material": ""}
