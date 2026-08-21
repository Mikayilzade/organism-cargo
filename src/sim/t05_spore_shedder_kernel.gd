class_name T05SporeShedderKernel
extends RefCounted

const ALLOWED_OUTPUT_AMOUNTS := [2, 3, 4]
const ALLOWED_ACTIVE_PRIMARY_STATES := ["CALM", "AGITATED", "PANICKED"]

func apply_phase_c(
		tick: int,
		contamination_by_cell: Dictionary,
		organisms: Array,
		definitions: Array
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var validated_definitions: Dictionary = _validated_definitions(definitions)
	if not bool(validated_definitions.get("ok", false)):
		return validated_definitions

	var runtime_by_id: Dictionary = {}
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return _failure("invalid_organism_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or runtime_by_id.has(instance_id):
			return _failure("invalid_organism_runtime_identity")
		runtime_by_id[instance_id] = organism

	var next_contamination: Dictionary = contamination_by_cell.duplicate(true)
	var events: Array = []
	var active_sources: Array = []
	var ordered_definitions: Array = validated_definitions["definitions"]
	for raw_definition: Variant in ordered_definitions:
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition["instance_id"])
		if not runtime_by_id.has(instance_id):
			return _failure("missing_organism_runtime:%s" % instance_id)
		var organism: Dictionary = runtime_by_id[instance_id]
		var eligibility: Dictionary = _is_active(organism, definition)
		if not bool(eligibility.get("ok", false)):
			return eligibility
		if not bool(eligibility["active"]):
			continue

		var occupied_result: Dictionary = _occupied_cells(organism, contamination_by_cell)
		if not bool(occupied_result.get("ok", false)):
			return occupied_result
		var occupied_cells: PackedStringArray = occupied_result["cells"]
		var output_amount: int = int(definition["output_amount"])
		var primary_state: String = String(organism.get("primary_state", ""))
		var body_stage: String = String(organism.get("body_stage", ""))
		active_sources.append({
			"instance_id": instance_id,
			"trait_id": "T05",
			"output_amount": output_amount,
			"source_cells": Array(occupied_cells),
			"primary_state": primary_state,
			"body_stage": body_stage,
		})

		for cell_key: String in occupied_cells:
			var before: int = int(next_contamination.get(cell_key, 0))
			var after: int = before + output_amount
			next_contamination[cell_key] = after
			events.append({
				"event_id": "t%04d:C:T05:%s:%s" % [tick, instance_id, cell_key],
				"tick": tick,
				"phase": "C",
				"kind": "T05_SPORE_SOURCE",
				"trait_id": "T05",
				"instance_id": instance_id,
				"cell_key": cell_key,
				"contamination_delta": output_amount,
				"contamination_before": before,
				"contamination_after": after,
				"primary_state": primary_state,
				"body_stage": body_stage,
				"parent_event_ids": PackedStringArray(),
			})

	return {
		"ok": true,
		"error": "",
		"contamination_by_cell": next_contamination,
		"events": events,
		"active_sources": active_sources,
	}

func _validated_definitions(definitions: Array) -> Dictionary:
	var normalized: Array = []
	var seen_instances: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			return _failure("invalid_t05_definition")
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition.get("instance_id", ""))
		if instance_id.is_empty():
			return _failure("missing_t05_instance_id")
		if seen_instances.has(instance_id):
			return _failure("duplicate_t05_instance_id:%s" % instance_id)
		seen_instances[instance_id] = true
		var output_amount: int = int(definition.get("output_amount", 0))
		if output_amount not in ALLOWED_OUTPUT_AMOUNTS:
			return _failure("invalid_t05_output_amount:%s" % instance_id)

		var active_states_result: Dictionary = _normalized_string_array(
			definition.get("active_primary_states", []),
			"active_primary_states",
			instance_id
		)
		if not bool(active_states_result.get("ok", false)):
			return active_states_result
		var active_primary_states: PackedStringArray = active_states_result["values"]
		for state: String in active_primary_states:
			if state not in ALLOWED_ACTIVE_PRIMARY_STATES:
				return _failure("invalid_t05_primary_state:%s:%s" % [instance_id, state])

		var active_stages_result: Dictionary = _normalized_string_array(
			definition.get("active_body_stages", []),
			"active_body_stages",
			instance_id
		)
		if not bool(active_stages_result.get("ok", false)):
			return active_stages_result

		normalized.append({
			"instance_id": instance_id,
			"output_amount": output_amount,
			"active_primary_states": active_primary_states,
			"active_body_stages": active_stages_result["values"],
			"sleep_gated": bool(definition.get("sleep_gated", false)),
		})

	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	return {"ok": true, "error": "", "definitions": normalized}

func _is_active(organism: Dictionary, definition: Dictionary) -> Dictionary:
	var instance_id: String = String(definition["instance_id"])
	var primary_state: String = String(organism.get("primary_state", ""))
	if primary_state.is_empty():
		return _failure("missing_primary_state:%s" % instance_id)

	var active_primary_states: PackedStringArray = definition["active_primary_states"]
	var state_active: bool = true
	if primary_state == "ASLEEP":
		state_active = not bool(definition["sleep_gated"])
	elif not active_primary_states.is_empty():
		state_active = primary_state in active_primary_states

	var active_body_stages: PackedStringArray = definition["active_body_stages"]
	var stage_active: bool = true
	if not active_body_stages.is_empty():
		var body_stage: String = String(organism.get("body_stage", ""))
		if body_stage.is_empty():
			return _failure("missing_body_stage:%s" % instance_id)
		stage_active = body_stage in active_body_stages

	return {
		"ok": true,
		"error": "",
		"active": state_active and stage_active,
	}

func _occupied_cells(organism: Dictionary, contamination_by_cell: Dictionary) -> Dictionary:
	var instance_id: String = String(organism.get("instance_id", ""))
	var occupied_value: Variant = organism.get("occupied_cells", [])
	if not (occupied_value is Array or occupied_value is PackedStringArray):
		return _failure("invalid_occupied_cells:%s" % instance_id)
	var cells: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_cell: Variant in occupied_value:
		var cell_key: String = String(raw_cell)
		if cell_key.is_empty() or seen.has(cell_key):
			return _failure("invalid_occupied_cell:%s" % instance_id)
		if not contamination_by_cell.has(cell_key):
			return _failure("organism_cell_missing_from_contamination:%s:%s" % [instance_id, cell_key])
		seen[cell_key] = true
		cells.append(cell_key)
	if cells.is_empty():
		return _failure("invalid_occupied_cells:%s" % instance_id)
	cells.sort()
	return {"ok": true, "error": "", "cells": cells}

func _normalized_string_array(value: Variant, field_name: String, instance_id: String) -> Dictionary:
	if not (value is Array or value is PackedStringArray):
		return _failure("invalid_t05_%s:%s" % [field_name, instance_id])
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_value: Variant in value:
		var text: String = String(raw_value)
		if text.is_empty() or seen.has(text):
			return _failure("invalid_t05_%s:%s" % [field_name, instance_id])
		seen[text] = true
		result.append(text)
	result.sort()
	return {"ok": true, "error": "", "values": result}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
