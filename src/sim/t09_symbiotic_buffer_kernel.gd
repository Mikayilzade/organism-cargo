class_name T09SymbioticBufferKernel
extends RefCounted

const FixedMathScript := preload("res://src/sim/fixed_math.gd")
const FIXED_SCALE: int = 1000
const ALLOWED_RANGES := [1, 2]
const ALLOWED_PRIMARY_STATES := ["CALM", "AGITATED", "PANICKED"]

func resolve_tick(
		tick: int,
		organisms: Array,
		definitions: Array
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var runtime_result: Dictionary = _runtime_by_id(organisms)
	if not bool(runtime_result.get("ok", false)):
		return runtime_result
	var runtime_by_id: Dictionary = runtime_result["runtime_by_id"]
	var definitions_result: Dictionary = _validated_definitions(definitions)
	if not bool(definitions_result.get("ok", false)):
		return definitions_result

	var modifiers_by_target: Dictionary = {}
	var assignments: Array = []
	var ordered_definitions: Array = definitions_result["definitions"]
	for raw_definition: Variant in ordered_definitions:
		var definition: Dictionary = raw_definition
		var source_id: String = String(definition["instance_id"])
		if not runtime_by_id.has(source_id):
			return _failure("missing_t09_source_runtime:%s" % source_id)
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
		var eligible_target_ids: PackedStringArray = definition["eligible_target_ids"]
		for target_id: String in eligible_target_ids:
			if target_id == source_id:
				continue
			if not runtime_by_id.has(target_id):
				return _failure("missing_t09_target_runtime:%s" % target_id)
			var target: Dictionary = runtime_by_id[target_id]
			var target_cells_result: Dictionary = _occupied_cells(target)
			if not bool(target_cells_result.get("ok", false)):
				return target_cells_result
			var distance_result: Dictionary = _nearest_distance(source_cells, target_cells_result["cells"])
			if not bool(distance_result.get("ok", false)):
				return distance_result
			var distance: int = int(distance_result["distance"])
			if distance <= int(definition["range"]):
				candidates.append({"target_id": target_id, "distance": distance})
		candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_distance: int = int(left["distance"])
			var right_distance: int = int(right["distance"])
			if left_distance != right_distance:
				return left_distance < right_distance
			return String(left["target_id"]) < String(right["target_id"])
		)
		if candidates.is_empty():
			continue

		# Launch T09 roster semantics are one-target narrow protection. The
		# authored compatible set may contain alternatives, but one source can
		# never protect more than one target on the same tick.
		var selected: Dictionary = candidates[0]
		var target_id: String = String(selected["target_id"])
		var source_multiplier: int = int(definition["intake_multiplier_scaled"])
		var prior_multiplier: int = int(modifiers_by_target.get(target_id, FIXED_SCALE))
		var combined_multiplier: int = FixedMathScript.mul_non_negative(prior_multiplier, source_multiplier)
		modifiers_by_target[target_id] = combined_multiplier
		assignments.append({
			"event_id": "t%04d:E:T09:%s>%s" % [tick, source_id, target_id],
			"tick": tick,
			"phase": "E",
			"kind": "T09_BUFFER_ASSIGNED",
			"trait_id": "T09",
			"source_instance_id": source_id,
			"target_instance_id": target_id,
			"distance": int(selected["distance"]),
			"source_intake_multiplier_scaled": source_multiplier,
			"combined_target_intake_multiplier_scaled": combined_multiplier,
			"parent_event_ids": PackedStringArray(),
		})

	return {
		"ok": true,
		"error": "",
		"intake_multiplier_scaled_by_target_id": modifiers_by_target,
		"events": assignments,
	}

func _runtime_by_id(organisms: Array) -> Dictionary:
	var runtime_by_id: Dictionary = {}
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return _failure("invalid_organism_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or runtime_by_id.has(instance_id):
			return _failure("invalid_organism_runtime_identity")
		runtime_by_id[instance_id] = organism
	return {"ok": true, "error": "", "runtime_by_id": runtime_by_id}

func _validated_definitions(definitions: Array) -> Dictionary:
	var normalized: Array = []
	var seen: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			return _failure("invalid_t09_definition")
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition.get("instance_id", ""))
		if instance_id.is_empty() or seen.has(instance_id):
			return _failure("invalid_t09_instance_id")
		seen[instance_id] = true
		var range_value: int = int(definition.get("range", 0))
		if range_value not in ALLOWED_RANGES:
			return _failure("invalid_t09_range:%s" % instance_id)
		var max_targets: int = int(definition.get("max_targets", 0))
		if max_targets != 1:
			return _failure("t09_must_be_one_target:%s" % instance_id)
		var intake_multiplier_scaled: int = int(definition.get("intake_multiplier_scaled", 0))
		if intake_multiplier_scaled <= 0 or intake_multiplier_scaled > FIXED_SCALE:
			return _failure("invalid_t09_intake_multiplier:%s" % instance_id)
		var target_result: Dictionary = _normalized_string_array(
			definition.get("eligible_target_ids", []),
			"eligible_target_ids",
			instance_id
		)
		if not bool(target_result.get("ok", false)):
			return target_result
		var eligible_target_ids: PackedStringArray = target_result["values"]
		if eligible_target_ids.is_empty():
			return _failure("missing_t09_eligible_targets:%s" % instance_id)
		var active_states_result: Dictionary = _normalized_string_array(
			definition.get("active_primary_states", []),
			"active_primary_states",
			instance_id
		)
		if not bool(active_states_result.get("ok", false)):
			return active_states_result
		var active_primary_states: PackedStringArray = active_states_result["values"]
		for state: String in active_primary_states:
			if state not in ALLOWED_PRIMARY_STATES:
				return _failure("invalid_t09_primary_state:%s:%s" % [instance_id, state])
		var active_stages_result: Dictionary = _normalized_string_array(
			definition.get("active_body_stages", []),
			"active_body_stages",
			instance_id
		)
		if not bool(active_stages_result.get("ok", false)):
			return active_stages_result
		normalized.append({
			"instance_id": instance_id,
			"range": range_value,
			"max_targets": max_targets,
			"intake_multiplier_scaled": intake_multiplier_scaled,
			"eligible_target_ids": eligible_target_ids,
			"active_primary_states": active_primary_states,
			"active_body_stages": active_stages_result["values"],
			"sleep_gated": bool(definition.get("sleep_gated", false)),
		})
	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	return {"ok": true, "error": "", "definitions": normalized}

func _is_active(source: Dictionary, definition: Dictionary) -> Dictionary:
	var source_id: String = String(definition["instance_id"])
	var primary_state: String = String(source.get("primary_state", ""))
	if primary_state.is_empty():
		return _failure("missing_primary_state:%s" % source_id)
	var active_states: PackedStringArray = definition["active_primary_states"]
	var state_active: bool = true
	if primary_state == "ASLEEP":
		state_active = not bool(definition["sleep_gated"])
	elif not active_states.is_empty():
		state_active = primary_state in active_states
	var active_stages: PackedStringArray = definition["active_body_stages"]
	var stage_active: bool = true
	if not active_stages.is_empty():
		var body_stage: String = String(source.get("body_stage", ""))
		if body_stage.is_empty():
			return _failure("missing_body_stage:%s" % source_id)
		stage_active = body_stage in active_stages
	return {"ok": true, "error": "", "active": state_active and stage_active}

func _occupied_cells(organism: Dictionary) -> Dictionary:
	var instance_id: String = String(organism.get("instance_id", ""))
	var occupied_value: Variant = organism.get("occupied_cells", [])
	if not (occupied_value is Array or occupied_value is PackedStringArray):
		return _failure("invalid_occupied_cells:%s" % instance_id)
	var cells: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_cell: Variant in occupied_value:
		var cell_key: String = String(raw_cell)
		if cell_key.is_empty() or seen.has(cell_key) or not _valid_cell_key(cell_key):
			return _failure("invalid_occupied_cell:%s" % instance_id)
		seen[cell_key] = true
		cells.append(cell_key)
	if cells.is_empty():
		return _failure("invalid_occupied_cells:%s" % instance_id)
	cells.sort()
	return {"ok": true, "error": "", "cells": cells}

func _nearest_distance(left_cells: PackedStringArray, right_cells: PackedStringArray) -> Dictionary:
	var nearest: int = -1
	for left_key: String in left_cells:
		var left_parts: PackedStringArray = left_key.split(",")
		for right_key: String in right_cells:
			var right_parts: PackedStringArray = right_key.split(",")
			var distance: int = absi(int(left_parts[0]) - int(right_parts[0])) + absi(int(left_parts[1]) - int(right_parts[1]))
			if nearest < 0 or distance < nearest:
				nearest = distance
	if nearest < 0:
		return _failure("t09_distance_unavailable")
	return {"ok": true, "error": "", "distance": nearest}

func _valid_cell_key(cell_key: String) -> bool:
	var parts: PackedStringArray = cell_key.split(",")
	if parts.size() != 2:
		return false
	return String(parts[0]).is_valid_int() and String(parts[1]).is_valid_int()

func _normalized_string_array(value: Variant, field_name: String, instance_id: String) -> Dictionary:
	if not (value is Array or value is PackedStringArray):
		return _failure("invalid_t09_%s:%s" % [field_name, instance_id])
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_value: Variant in value:
		var text: String = String(raw_value)
		if text.is_empty() or seen.has(text):
			return _failure("invalid_t09_%s:%s" % [field_name, instance_id])
		seen[text] = true
		result.append(text)
	result.sort()
	return {"ok": true, "error": "", "values": result}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
