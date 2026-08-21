class_name T06FilterFeederKernel
extends RefCounted

const ALLOWED_CAPACITIES := [2, 3, 4]
const ALLOWED_ACTIVE_PRIMARY_STATES := ["CALM", "AGITATED", "PANICKED"]

func resolve_tick(
		tick: int,
		contamination_by_cell: Dictionary,
		organisms: Array,
		definitions: Array
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var validated: Dictionary = _validated_definitions(definitions)
	if not bool(validated.get("ok", false)):
		return validated

	var runtime_by_id: Dictionary = {}
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return _failure("invalid_organism_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or runtime_by_id.has(instance_id):
			return _failure("invalid_organism_runtime_identity")
		runtime_by_id[instance_id] = organism

	var consumers: Array = []
	var ordered_definitions: Array = validated["definitions"]
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
		var satiety: int = int(organism.get("satiety", -1))
		var satiety_max: int = int(definition["satiety_max"])
		if satiety < 0 or satiety > satiety_max:
			return _failure("invalid_satiety:%s" % instance_id)
		var benefit_per_unit: int = int(definition["benefit_per_unit"])
		var headroom_units: int = (satiety_max - satiety) / benefit_per_unit
		var effective_capacity: int = mini(int(definition["capacity"]), headroom_units)
		if effective_capacity <= 0:
			continue
		consumers.append({
			"instance_id": instance_id,
			"cells": occupied_result["cells"],
			"remaining_capacity": effective_capacity,
			"benefit_per_unit": benefit_per_unit,
			"satiety_before": satiety,
			"satiety_max": satiety_max,
			"consumed": 0,
			"consumed_by_cell": {},
		})

	var cell_keys: PackedStringArray = PackedStringArray()
	for raw_key: Variant in contamination_by_cell.keys():
		cell_keys.append(String(raw_key))
	cell_keys.sort()

	# Contamination is an integer resource. Each unit is indivisible, so contested
	# units use a stable round-robin selector by instance_id, as permitted by canon.
	for cell_key: String in cell_keys:
		var available: int = int(contamination_by_cell.get(cell_key, 0))
		if available < 0:
			return _failure("negative_contamination:%s" % cell_key)
		while available > 0:
			var allocated_this_round: bool = false
			for consumer_index: int in range(consumers.size()):
				var consumer: Dictionary = consumers[consumer_index]
				var cells: PackedStringArray = consumer["cells"]
				if cell_key not in cells or int(consumer["remaining_capacity"]) <= 0:
					continue
				consumer["remaining_capacity"] = int(consumer["remaining_capacity"]) - 1
				consumer["consumed"] = int(consumer["consumed"]) + 1
				var consumed_by_cell: Dictionary = consumer["consumed_by_cell"]
				consumed_by_cell[cell_key] = int(consumed_by_cell.get(cell_key, 0)) + 1
				consumer["consumed_by_cell"] = consumed_by_cell
				consumers[consumer_index] = consumer
				available -= 1
				allocated_this_round = true
				if available <= 0:
					break
			if not allocated_this_round:
				break

	var next_contamination: Dictionary = contamination_by_cell.duplicate(true)
	var next_organisms: Array = organisms.duplicate(true)
	var next_index_by_id: Dictionary = {}
	for index: int in range(next_organisms.size()):
		var runtime: Dictionary = next_organisms[index]
		next_index_by_id[String(runtime["instance_id"])] = index
	var events: Array = []
	for raw_consumer: Variant in consumers:
		var consumer: Dictionary = raw_consumer
		var consumed: int = int(consumer["consumed"])
		if consumed <= 0:
			continue
		var instance_id: String = String(consumer["instance_id"])
		var consumed_by_cell: Dictionary = consumer["consumed_by_cell"]
		var consumed_cells: PackedStringArray = PackedStringArray()
		for raw_cell: Variant in consumed_by_cell.keys():
			consumed_cells.append(String(raw_cell))
		consumed_cells.sort()
		var parent_ids: PackedStringArray = PackedStringArray()
		for cell_key: String in consumed_cells:
			var amount: int = int(consumed_by_cell[cell_key])
			var before: int = int(next_contamination[cell_key])
			var after: int = before - amount
			if after < 0:
				return _failure("t06_overconsumption:%s" % cell_key)
			next_contamination[cell_key] = after
			var consume_event_id: String = "t%04d:E:T06:%s:%s" % [tick, instance_id, cell_key]
			parent_ids.append(consume_event_id)
			events.append({
				"event_id": consume_event_id,
				"tick": tick,
				"phase": "E",
				"kind": "T06_CONTAMINATION_CONSUMED",
				"trait_id": "T06",
				"instance_id": instance_id,
				"cell_key": cell_key,
				"consumed_amount": amount,
				"contamination_before": before,
				"contamination_after": after,
				"parent_event_ids": PackedStringArray(),
			})
		var runtime_index: int = int(next_index_by_id[instance_id])
		var next_runtime: Dictionary = next_organisms[runtime_index]
		var benefit_per_unit: int = int(consumer["benefit_per_unit"])
		var satiety_before: int = int(next_runtime.get("satiety", 0))
		var satiety_gain: int = consumed * benefit_per_unit
		var satiety_after: int = mini(int(consumer["satiety_max"]), satiety_before + satiety_gain)
		next_runtime["satiety"] = satiety_after
		next_organisms[runtime_index] = next_runtime
		events.append({
			"event_id": "t%04d:F:T06:%s" % [tick, instance_id],
			"tick": tick,
			"phase": "F",
			"kind": "T06_SATIETY_BENEFIT",
			"trait_id": "T06",
			"instance_id": instance_id,
			"consumed_amount": consumed,
			"benefit_per_unit": benefit_per_unit,
			"satiety_delta": satiety_after - satiety_before,
			"satiety_before": satiety_before,
			"satiety_after": satiety_after,
			"parent_event_ids": parent_ids,
		})

	return {
		"ok": true,
		"error": "",
		"contamination_by_cell": next_contamination,
		"organisms": next_organisms,
		"events": events,
	}

func _validated_definitions(definitions: Array) -> Dictionary:
	var normalized: Array = []
	var seen: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			return _failure("invalid_t06_definition")
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition.get("instance_id", ""))
		if instance_id.is_empty() or seen.has(instance_id):
			return _failure("invalid_t06_instance_id")
		seen[instance_id] = true
		var capacity: int = int(definition.get("capacity", 0))
		if capacity not in ALLOWED_CAPACITIES:
			return _failure("invalid_t06_capacity:%s" % instance_id)
		var benefit_per_unit: int = int(definition.get("benefit_per_unit", 0))
		var satiety_max: int = int(definition.get("satiety_max", 0))
		if benefit_per_unit <= 0 or satiety_max <= 0:
			return _failure("invalid_t06_benefit:%s" % instance_id)
		var active_states_result: Dictionary = _normalized_string_array(definition.get("active_primary_states", []), "active_primary_states", instance_id)
		if not bool(active_states_result.get("ok", false)):
			return active_states_result
		var active_primary_states: PackedStringArray = active_states_result["values"]
		for state: String in active_primary_states:
			if state not in ALLOWED_ACTIVE_PRIMARY_STATES:
				return _failure("invalid_t06_primary_state:%s:%s" % [instance_id, state])
		var active_stages_result: Dictionary = _normalized_string_array(definition.get("active_body_stages", []), "active_body_stages", instance_id)
		if not bool(active_stages_result.get("ok", false)):
			return active_stages_result
		normalized.append({
			"instance_id": instance_id,
			"capacity": capacity,
			"benefit_per_unit": benefit_per_unit,
			"satiety_max": satiety_max,
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
	var active_states: PackedStringArray = definition["active_primary_states"]
	var state_active: bool = true
	if primary_state == "ASLEEP":
		state_active = not bool(definition["sleep_gated"])
	elif not active_states.is_empty():
		state_active = primary_state in active_states
	var active_stages: PackedStringArray = definition["active_body_stages"]
	var stage_active: bool = true
	if not active_stages.is_empty():
		var body_stage: String = String(organism.get("body_stage", ""))
		if body_stage.is_empty():
			return _failure("missing_body_stage:%s" % instance_id)
		stage_active = body_stage in active_stages
	return {"ok": true, "error": "", "active": state_active and stage_active}

func _occupied_cells(organism: Dictionary, contamination_by_cell: Dictionary) -> Dictionary:
	var instance_id: String = String(organism.get("instance_id", ""))
	var occupied_value: Variant = organism.get("occupied_cells", [])
	if not (occupied_value is Array or occupied_value is PackedStringArray):
		return _failure("invalid_occupied_cells:%s" % instance_id)
	var cells: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_cell: Variant in occupied_value:
		var cell_key: String = String(raw_cell)
		if cell_key.is_empty() or seen.has(cell_key) or not contamination_by_cell.has(cell_key):
			return _failure("invalid_occupied_cell:%s" % instance_id)
		seen[cell_key] = true
		cells.append(cell_key)
	if cells.is_empty():
		return _failure("invalid_occupied_cells:%s" % instance_id)
	cells.sort()
	return {"ok": true, "error": "", "cells": cells}

func _normalized_string_array(value: Variant, field_name: String, instance_id: String) -> Dictionary:
	if not (value is Array or value is PackedStringArray):
		return _failure("invalid_t06_%s:%s" % [field_name, instance_id])
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_value: Variant in value:
		var text: String = String(raw_value)
		if text.is_empty() or seen.has(text):
			return _failure("invalid_t06_%s:%s" % [field_name, instance_id])
		seen[text] = true
		result.append(text)
	result.sort()
	return {"ok": true, "error": "", "values": result}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
