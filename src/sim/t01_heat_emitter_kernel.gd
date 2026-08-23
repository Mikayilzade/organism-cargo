class_name T01HeatEmitterKernel
extends RefCounted

const ALLOWED_OUTPUT_AMOUNTS := [2, 3, 4]
const AWAKE_PRIMARY_STATES := ["CALM", "AGITATED", "PANICKED"]

func apply_phase_c(
		tick: int,
		heat_by_cell: Dictionary,
		organisms: Array,
		definitions: Array
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_t01_tick")
	var validated: Dictionary = _validated_definitions(definitions)
	if not bool(validated.get("ok", false)):
		return validated

	var runtime_by_id: Dictionary = {}
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return _failure("invalid_t01_organism_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or runtime_by_id.has(instance_id):
			return _failure("invalid_t01_organism_identity")
		runtime_by_id[instance_id] = organism

	var next_heat: Dictionary = heat_by_cell.duplicate(true)
	var events: Array = []
	var active_sources: Array = []
	var ordered_definitions: Array = validated["definitions"]
	for raw_definition: Variant in ordered_definitions:
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition["instance_id"])
		if not runtime_by_id.has(instance_id):
			return _failure("missing_t01_organism_runtime:%s" % instance_id)
		var organism: Dictionary = runtime_by_id[instance_id]
		var eligibility: Dictionary = _is_active(organism, definition)
		if not bool(eligibility.get("ok", false)):
			return eligibility
		if not bool(eligibility["active"]):
			continue
		var occupied_result: Dictionary = _occupied_cells(organism, heat_by_cell)
		if not bool(occupied_result.get("ok", false)):
			return occupied_result
		var occupied_cells: PackedStringArray = occupied_result["cells"]
		var output_amount: int = int(definition["output_amount"])
		active_sources.append({
			"instance_id": instance_id,
			"trait_id": "T01",
			"output_amount": output_amount,
			"source_cells": Array(occupied_cells),
			"primary_state": String(organism.get("primary_state", "")),
		})
		for cell_key: String in occupied_cells:
			var before: int = int(next_heat.get(cell_key, 0))
			var after: int = before + output_amount
			next_heat[cell_key] = after
			events.append({
				"event_id": "t%04d:C:T01:%s:%s" % [tick, instance_id, cell_key],
				"tick": tick,
				"phase": "C",
				"kind": "T01_HEAT_SOURCE",
				"trait_id": "T01",
				"instance_id": instance_id,
				"cell_key": cell_key,
				"heat_delta": output_amount,
				"heat_before": before,
				"heat_after": after,
				"parent_event_ids": PackedStringArray(),
			})

	return {
		"ok": true,
		"error": "",
		"heat_by_cell": next_heat,
		"events": events,
		"active_sources": active_sources,
	}

func _validated_definitions(definitions: Array) -> Dictionary:
	var normalized: Array = []
	var seen_instances: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			return _failure("invalid_t01_definition")
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition.get("instance_id", ""))
		if instance_id.is_empty() or seen_instances.has(instance_id):
			return _failure("invalid_t01_instance_id")
		seen_instances[instance_id] = true
		var output_amount: int = int(definition.get("output_amount", 0))
		if output_amount not in ALLOWED_OUTPUT_AMOUNTS:
			return _failure("invalid_t01_output_amount:%s" % instance_id)
		var states_result: Dictionary = _normalized_states(definition.get("active_primary_states", []), instance_id)
		if not bool(states_result.get("ok", false)):
			return states_result
		normalized.append({
			"instance_id": instance_id,
			"output_amount": output_amount,
			"active_primary_states": states_result["values"],
			"sleep_gated": bool(definition.get("sleep_gated", false)),
		})
	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	return {"ok": true, "error": "", "definitions": normalized}

func _normalized_states(value: Variant, instance_id: String) -> Dictionary:
	if not (value is Array or value is PackedStringArray):
		return _failure("invalid_t01_active_primary_states:%s" % instance_id)
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_state: Variant in value:
		var state: String = String(raw_state)
		if state not in AWAKE_PRIMARY_STATES or seen.has(state):
			return _failure("invalid_t01_primary_state:%s:%s" % [instance_id, state])
		seen[state] = true
		result.append(state)
	result.sort()
	return {"ok": true, "error": "", "values": result}

func _is_active(organism: Dictionary, definition: Dictionary) -> Dictionary:
	var instance_id: String = String(definition["instance_id"])
	var primary_state: String = String(organism.get("primary_state", ""))
	if primary_state != "ASLEEP" and primary_state not in AWAKE_PRIMARY_STATES:
		return _failure("invalid_t01_runtime_primary_state:%s:%s" % [instance_id, primary_state])
	if primary_state == "ASLEEP":
		return {"ok": true, "error": "", "active": not bool(definition["sleep_gated"])}
	var active_states: PackedStringArray = definition["active_primary_states"]
	return {"ok": true, "error": "", "active": active_states.is_empty() or primary_state in active_states}

func _occupied_cells(organism: Dictionary, heat_by_cell: Dictionary) -> Dictionary:
	var instance_id: String = String(organism.get("instance_id", ""))
	var occupied_value: Variant = organism.get("occupied_cells", [])
	if not (occupied_value is Array or occupied_value is PackedStringArray):
		return _failure("invalid_t01_occupied_cells:%s" % instance_id)
	var cells: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_cell: Variant in occupied_value:
		var cell_key: String = String(raw_cell)
		if cell_key.is_empty() or seen.has(cell_key):
			return _failure("invalid_t01_occupied_cell:%s" % instance_id)
		if not heat_by_cell.has(cell_key):
			return _failure("t01_cell_outside_heat_field:%s:%s" % [instance_id, cell_key])
		seen[cell_key] = true
		cells.append(cell_key)
	if cells.is_empty():
		return _failure("invalid_t01_occupied_cells:%s" % instance_id)
	cells.sort()
	return {"ok": true, "error": "", "cells": cells}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
