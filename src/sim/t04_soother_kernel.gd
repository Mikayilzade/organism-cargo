class_name T04SootherKernel
extends RefCounted

const ALLOWED_RANGES := [1, 2]
const ALLOWED_AMOUNTS := [1, 2, 3]
const ALLOWED_PRIMARY_STATES := ["CALM", "AGITATED", "PANICKED"]

func resolve_phase_e(tick: int, organisms: Array, definitions: Array) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_t04_tick")
	var runtime_result: Dictionary = _runtime_by_id(organisms)
	if not bool(runtime_result.get("ok", false)):
		return runtime_result
	var runtime_by_id: Dictionary = runtime_result["runtime_by_id"]
	var definitions_result: Dictionary = _validated_definitions(definitions)
	if not bool(definitions_result.get("ok", false)):
		return definitions_result

	var stress_delta_by_target_id: Dictionary = {}
	var parent_event_ids_by_target_id: Dictionary = {}
	var events: Array = []
	for raw_definition: Variant in definitions_result["definitions"]:
		var definition: Dictionary = raw_definition
		var source_id: String = String(definition["instance_id"])
		if not runtime_by_id.has(source_id):
			return _failure("missing_t04_source_runtime:%s" % source_id)
		var source: Dictionary = runtime_by_id[source_id]
		var active_result: Dictionary = _is_active(source, definition)
		if not bool(active_result.get("ok", false)):
			return active_result
		if not bool(active_result["active"]):
			continue
		var source_cells_result: Dictionary = _occupied_cells(source)
		if not bool(source_cells_result.get("ok", false)):
			return source_cells_result
		var source_cells: PackedStringArray = source_cells_result["cells"]

		var candidates: Array = []
		for target_id: String in definition["eligible_target_ids"]:
			if target_id == source_id:
				continue
			if not runtime_by_id.has(target_id):
				return _failure("missing_t04_target_runtime:%s" % target_id)
			var target: Dictionary = runtime_by_id[target_id]
			var target_cells_result: Dictionary = _occupied_cells(target)
			if not bool(target_cells_result.get("ok", false)):
				return target_cells_result
			var distance: int = _nearest_distance(source_cells, target_cells_result["cells"])
			if distance <= int(definition["range"]):
				candidates.append({"target_id": target_id, "distance": distance})
		candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_distance: int = int(left["distance"])
			var right_distance: int = int(right["distance"])
			if left_distance != right_distance:
				return left_distance < right_distance
			return String(left["target_id"]) < String(right["target_id"])
		)
		var selected_count: int = mini(int(definition["max_targets"]), candidates.size())
		for candidate_index: int in range(selected_count):
			var selected: Dictionary = candidates[candidate_index]
			var target_id: String = String(selected["target_id"])
			var amount: int = int(definition["amount"])
			var delta: int = -amount
			stress_delta_by_target_id[target_id] = int(stress_delta_by_target_id.get(target_id, 0)) + delta
			var event_id: String = "t%04d:E:T04:%s>%s" % [tick, source_id, target_id]
			var parents: PackedStringArray = parent_event_ids_by_target_id.get(target_id, PackedStringArray())
			parents.append(event_id)
			parent_event_ids_by_target_id[target_id] = parents
			events.append({
				"event_id": event_id,
				"tick": tick,
				"phase": "E",
				"kind": "T04_SOOTHING_ASSIGNED",
				"trait_id": "T04",
				"source_instance_id": source_id,
				"target_instance_id": target_id,
				"distance": int(selected["distance"]),
				"stress_delta": delta,
				"parent_event_ids": PackedStringArray(),
			})

	return {
		"ok": true,
		"error": "",
		"stress_delta_by_target_id": stress_delta_by_target_id,
		"parent_event_ids_by_target_id": parent_event_ids_by_target_id,
		"events": events,
	}

func _runtime_by_id(organisms: Array) -> Dictionary:
	var runtime_by_id: Dictionary = {}
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return _failure("invalid_t04_organism_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or runtime_by_id.has(instance_id):
			return _failure("invalid_t04_organism_identity")
		runtime_by_id[instance_id] = organism
	return {"ok": true, "error": "", "runtime_by_id": runtime_by_id}

func _validated_definitions(definitions: Array) -> Dictionary:
	var normalized: Array = []
	var seen: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			return _failure("invalid_t04_definition")
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition.get("instance_id", ""))
		if instance_id.is_empty() or seen.has(instance_id):
			return _failure("invalid_t04_instance_id")
		seen[instance_id] = true
		var amount: int = int(definition.get("amount", 0))
		if amount not in ALLOWED_AMOUNTS:
			return _failure("invalid_t04_amount:%s" % instance_id)
		var range_value: int = int(definition.get("range", 0))
		if range_value not in ALLOWED_RANGES:
			return _failure("invalid_t04_range:%s" % instance_id)
		var max_targets: int = int(definition.get("max_targets", 0))
		if max_targets <= 0 or max_targets > 3:
			return _failure("invalid_t04_capacity:%s" % instance_id)
		var targets_result: Dictionary = _normalized_strings(definition.get("eligible_target_ids", []), "eligible_target_ids", instance_id)
		if not bool(targets_result.get("ok", false)):
			return targets_result
		var eligible_target_ids: PackedStringArray = targets_result["values"]
		if eligible_target_ids.is_empty():
			return _failure("missing_t04_eligible_targets:%s" % instance_id)
		var states_result: Dictionary = _normalized_strings(definition.get("active_primary_states", []), "active_primary_states", instance_id)
		if not bool(states_result.get("ok", false)):
			return states_result
		var active_primary_states: PackedStringArray = states_result["values"]
		for state: String in active_primary_states:
			if state not in ALLOWED_PRIMARY_STATES:
				return _failure("invalid_t04_primary_state:%s:%s" % [instance_id, state])
		normalized.append({
			"instance_id": instance_id,
			"amount": amount,
			"range": range_value,
			"max_targets": max_targets,
			"eligible_target_ids": eligible_target_ids,
			"active_primary_states": active_primary_states,
			"sleep_gated": bool(definition.get("sleep_gated", false)),
		})
	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	return {"ok": true, "error": "", "definitions": normalized}

func _is_active(source: Dictionary, definition: Dictionary) -> Dictionary:
	var source_id: String = String(definition["instance_id"])
	var primary_state: String = String(source.get("primary_state", ""))
	if primary_state != "ASLEEP" and primary_state not in ALLOWED_PRIMARY_STATES:
		return _failure("invalid_t04_runtime_primary_state:%s:%s" % [source_id, primary_state])
	if primary_state == "ASLEEP":
		return {"ok": true, "error": "", "active": not bool(definition["sleep_gated"])}
	var active_states: PackedStringArray = definition["active_primary_states"]
	return {"ok": true, "error": "", "active": active_states.is_empty() or primary_state in active_states}

func _occupied_cells(organism: Dictionary) -> Dictionary:
	var instance_id: String = String(organism.get("instance_id", ""))
	var occupied_value: Variant = organism.get("occupied_cells", [])
	if not (occupied_value is Array or occupied_value is PackedStringArray):
		return _failure("invalid_t04_occupied_cells:%s" % instance_id)
	var cells: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_cell: Variant in occupied_value:
		var cell_key: String = String(raw_cell)
		if cell_key.is_empty() or seen.has(cell_key) or not _valid_cell_key(cell_key):
			return _failure("invalid_t04_occupied_cell:%s" % instance_id)
		seen[cell_key] = true
		cells.append(cell_key)
	if cells.is_empty():
		return _failure("invalid_t04_occupied_cells:%s" % instance_id)
	cells.sort()
	return {"ok": true, "error": "", "cells": cells}

func _nearest_distance(left_cells: PackedStringArray, right_cells: PackedStringArray) -> int:
	var nearest: int = 2147483647
	for left_key: String in left_cells:
		var left_parts: PackedStringArray = left_key.split(",")
		for right_key: String in right_cells:
			var right_parts: PackedStringArray = right_key.split(",")
			var distance: int = absi(int(left_parts[0]) - int(right_parts[0])) + absi(int(left_parts[1]) - int(right_parts[1]))
			nearest = mini(nearest, distance)
	return nearest

func _valid_cell_key(cell_key: String) -> bool:
	var parts: PackedStringArray = cell_key.split(",")
	return parts.size() == 2 and String(parts[0]).is_valid_int() and String(parts[1]).is_valid_int()

func _normalized_strings(value: Variant, field_name: String, instance_id: String) -> Dictionary:
	if not (value is Array or value is PackedStringArray):
		return _failure("invalid_t04_%s:%s" % [field_name, instance_id])
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_value: Variant in value:
		var text: String = String(raw_value)
		if text.is_empty() or seen.has(text):
			return _failure("invalid_t04_%s:%s" % [field_name, instance_id])
		seen[text] = true
		result.append(text)
	result.sort()
	return {"ok": true, "error": "", "values": result}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
