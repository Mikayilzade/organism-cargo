class_name T07FeedingKernel
extends RefCounted

const ALLOWED_RANGES := [1, 2]
const ALLOWED_INTAKE_CAPS := [1, 2, 3]
const ALLOWED_ACTIVE_PRIMARY_STATES := ["CALM", "AGITATED", "PANICKED"]

func resolve_tick(
		tick: int,
		organisms: Array,
		producer_definitions: Array,
		consumer_definitions: Array
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var runtime_result: Dictionary = _runtime_by_id(organisms)
	if not bool(runtime_result.get("ok", false)):
		return runtime_result
	var runtime_by_id: Dictionary = runtime_result["runtime_by_id"]
	var producer_result: Dictionary = _validated_producers(producer_definitions, runtime_by_id)
	if not bool(producer_result.get("ok", false)):
		return producer_result
	var consumer_result: Dictionary = _validated_consumers(consumer_definitions, runtime_by_id)
	if not bool(consumer_result.get("ok", false)):
		return consumer_result
	var producers: Array = producer_result["definitions"]
	var consumers: Array = consumer_result["definitions"]

	var remaining_intake_by_id: Dictionary = {}
	var consumed_by_consumer: Dictionary = {}
	var allocations: Array = []
	for raw_consumer: Variant in consumers:
		var consumer: Dictionary = raw_consumer
		var consumer_id: String = String(consumer["instance_id"])
		var runtime: Dictionary = runtime_by_id[consumer_id]
		var active_result: Dictionary = _is_active(runtime, consumer)
		if not bool(active_result.get("ok", false)):
			return active_result
		if not bool(active_result["active"]):
			remaining_intake_by_id[consumer_id] = 0
			continue
		var satiety: int = int(runtime.get("satiety", -1))
		var satiety_max: int = int(consumer["satiety_max"])
		var benefit_per_unit: int = int(consumer["benefit_per_unit"])
		if satiety < 0 or satiety > satiety_max:
			return _failure("invalid_satiety:%s" % consumer_id)
		var headroom_units: int = (satiety_max - satiety) / benefit_per_unit
		remaining_intake_by_id[consumer_id] = mini(int(consumer["intake_cap"]), headroom_units)
		consumed_by_consumer[consumer_id] = 0

	for raw_producer: Variant in producers:
		var producer: Dictionary = raw_producer
		var producer_id: String = String(producer["instance_id"])
		var producer_runtime: Dictionary = runtime_by_id[producer_id]
		var producer_active_result: Dictionary = _is_active(producer_runtime, producer)
		if not bool(producer_active_result.get("ok", false)):
			return producer_active_result
		if not bool(producer_active_result["active"]):
			continue
		var available_units: int = int(producer["output_units"])
		var candidates: Array = []
		for raw_consumer: Variant in consumers:
			var consumer: Dictionary = raw_consumer
			var consumer_id: String = String(consumer["instance_id"])
			if int(remaining_intake_by_id.get(consumer_id, 0)) <= 0:
				continue
			if not _tags_overlap(producer["food_tags"], consumer["accepted_food_tags"]):
				continue
			var distance_result: Dictionary = _distance(producer_runtime, runtime_by_id[consumer_id])
			if not bool(distance_result.get("ok", false)):
				return distance_result
			var distance: int = int(distance_result["distance"])
			if distance > int(consumer["range"]):
				continue
			candidates.append({"instance_id": consumer_id, "distance": distance})
		candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_distance: int = int(left["distance"])
			var right_distance: int = int(right["distance"])
			if left_distance != right_distance:
				return left_distance < right_distance
			return String(left["instance_id"]) < String(right["instance_id"])
		)
		while available_units > 0:
			var allocated_this_round: bool = false
			for raw_candidate: Variant in candidates:
				var candidate: Dictionary = raw_candidate
				var consumer_id: String = String(candidate["instance_id"])
				if int(remaining_intake_by_id.get(consumer_id, 0)) <= 0:
					continue
				remaining_intake_by_id[consumer_id] = int(remaining_intake_by_id[consumer_id]) - 1
				consumed_by_consumer[consumer_id] = int(consumed_by_consumer.get(consumer_id, 0)) + 1
				available_units -= 1
				allocated_this_round = true
				allocations.append({
					"producer_id": producer_id,
					"consumer_id": consumer_id,
					"distance": int(candidate["distance"]),
				})
				if available_units <= 0:
					break
			if not allocated_this_round:
				break

	var next_organisms: Array = organisms.duplicate(true)
	var index_by_id: Dictionary = {}
	for index: int in range(next_organisms.size()):
		var runtime: Dictionary = next_organisms[index]
		index_by_id[String(runtime["instance_id"])] = index
	var events: Array = []
	for allocation_index: int in range(allocations.size()):
		var allocation: Dictionary = allocations[allocation_index]
		var producer_id: String = String(allocation["producer_id"])
		var consumer_id: String = String(allocation["consumer_id"])
		events.append({
			"event_id": "t%04d:E:T07:%s:%s:%03d" % [tick, producer_id, consumer_id, allocation_index],
			"tick": tick,
			"phase": "E",
			"kind": "T07_FOOD_ALLOCATED",
			"trait_id": "T07",
			"producer_id": producer_id,
			"consumer_id": consumer_id,
			"distance": int(allocation["distance"]),
			"food_units": 1,
			"source_cost_units": 1,
			"parent_event_ids": PackedStringArray(),
		})

	for raw_consumer: Variant in consumers:
		var consumer: Dictionary = raw_consumer
		var consumer_id: String = String(consumer["instance_id"])
		var consumed: int = int(consumed_by_consumer.get(consumer_id, 0))
		if consumed <= 0:
			continue
		var runtime_index: int = int(index_by_id[consumer_id])
		var next_runtime: Dictionary = next_organisms[runtime_index]
		var before: int = int(next_runtime.get("satiety", 0))
		var benefit_per_unit: int = int(consumer["benefit_per_unit"])
		var after: int = mini(int(consumer["satiety_max"]), before + consumed * benefit_per_unit)
		next_runtime["satiety"] = after
		next_organisms[runtime_index] = next_runtime
		var parents: PackedStringArray = PackedStringArray()
		for raw_event: Variant in events:
			var event: Dictionary = raw_event
			if String(event.get("consumer_id", "")) == consumer_id:
				parents.append(String(event["event_id"]))
		events.append({
			"event_id": "t%04d:F:T07:%s" % [tick, consumer_id],
			"tick": tick,
			"phase": "F",
			"kind": "T07_SATIETY_GAIN",
			"trait_id": "T07",
			"consumer_id": consumer_id,
			"food_units": consumed,
			"benefit_per_unit": benefit_per_unit,
			"satiety_before": before,
			"satiety_after": after,
			"satiety_delta": after - before,
			"parent_event_ids": parents,
		})

	return {
		"ok": true,
		"error": "",
		"organisms": next_organisms,
		"allocations": allocations,
		"events": events,
	}

func _runtime_by_id(organisms: Array) -> Dictionary:
	var runtime_by_id: Dictionary = {}
	for raw_runtime: Variant in organisms:
		if not raw_runtime is Dictionary:
			return _failure("invalid_organism_runtime")
		var runtime: Dictionary = raw_runtime
		var instance_id: String = String(runtime.get("instance_id", ""))
		if instance_id.is_empty() or runtime_by_id.has(instance_id):
			return _failure("invalid_organism_runtime_identity")
		runtime_by_id[instance_id] = runtime
	return {"ok": true, "error": "", "runtime_by_id": runtime_by_id}

func _validated_producers(definitions: Array, runtime_by_id: Dictionary) -> Dictionary:
	var normalized: Array = []
	var seen: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			return _failure("invalid_t07_producer_definition")
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition.get("instance_id", ""))
		if instance_id.is_empty() or seen.has(instance_id) or not runtime_by_id.has(instance_id):
			return _failure("invalid_t07_producer_instance:%s" % instance_id)
		seen[instance_id] = true
		var output_units: int = int(definition.get("output_units", 0))
		if output_units <= 0:
			return _failure("invalid_t07_output_units:%s" % instance_id)
		var tags_result: Dictionary = _normalized_tags(definition.get("food_tags", []), instance_id, "food_tags")
		if not bool(tags_result.get("ok", false)):
			return tags_result
		var gates_result: Dictionary = _normalized_gates(definition, instance_id)
		if not bool(gates_result.get("ok", false)):
			return gates_result
		normalized.append({
			"instance_id": instance_id,
			"output_units": output_units,
			"food_tags": tags_result["values"],
			"active_primary_states": gates_result["active_primary_states"],
			"active_body_stages": gates_result["active_body_stages"],
			"sleep_gated": bool(gates_result["sleep_gated"]),
		})
	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	return {"ok": true, "error": "", "definitions": normalized}

func _validated_consumers(definitions: Array, runtime_by_id: Dictionary) -> Dictionary:
	var normalized: Array = []
	var seen: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			return _failure("invalid_t07_consumer_definition")
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition.get("instance_id", ""))
		if instance_id.is_empty() or seen.has(instance_id) or not runtime_by_id.has(instance_id):
			return _failure("invalid_t07_consumer_instance:%s" % instance_id)
		seen[instance_id] = true
		var range_value: int = int(definition.get("range", 0))
		var intake_cap: int = int(definition.get("intake_cap", 0))
		var benefit_per_unit: int = int(definition.get("benefit_per_unit", 0))
		var satiety_max: int = int(definition.get("satiety_max", 0))
		if range_value not in ALLOWED_RANGES or intake_cap not in ALLOWED_INTAKE_CAPS or benefit_per_unit <= 0 or satiety_max <= 0:
			return _failure("invalid_t07_consumer_parameters:%s" % instance_id)
		var tags_result: Dictionary = _normalized_tags(definition.get("accepted_food_tags", []), instance_id, "accepted_food_tags")
		if not bool(tags_result.get("ok", false)):
			return tags_result
		var gates_result: Dictionary = _normalized_gates(definition, instance_id)
		if not bool(gates_result.get("ok", false)):
			return gates_result
		normalized.append({
			"instance_id": instance_id,
			"range": range_value,
			"intake_cap": intake_cap,
			"benefit_per_unit": benefit_per_unit,
			"satiety_max": satiety_max,
			"accepted_food_tags": tags_result["values"],
			"active_primary_states": gates_result["active_primary_states"],
			"active_body_stages": gates_result["active_body_stages"],
			"sleep_gated": bool(gates_result["sleep_gated"]),
		})
	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	return {"ok": true, "error": "", "definitions": normalized}

func _normalized_gates(definition: Dictionary, instance_id: String) -> Dictionary:
	var states_result: Dictionary = _normalized_tags(definition.get("active_primary_states", []), instance_id, "active_primary_states", true)
	if not bool(states_result.get("ok", false)):
		return states_result
	var states: PackedStringArray = states_result["values"]
	for state: String in states:
		if state not in ALLOWED_ACTIVE_PRIMARY_STATES:
			return _failure("invalid_t07_primary_state:%s:%s" % [instance_id, state])
	var stages_result: Dictionary = _normalized_tags(definition.get("active_body_stages", []), instance_id, "active_body_stages", true)
	if not bool(stages_result.get("ok", false)):
		return stages_result
	return {
		"ok": true,
		"error": "",
		"active_primary_states": states,
		"active_body_stages": stages_result["values"],
		"sleep_gated": bool(definition.get("sleep_gated", false)),
	}

func _is_active(runtime: Dictionary, definition: Dictionary) -> Dictionary:
	var instance_id: String = String(definition["instance_id"])
	var state: String = String(runtime.get("primary_state", ""))
	if state.is_empty():
		return _failure("missing_primary_state:%s" % instance_id)
	var states: PackedStringArray = definition["active_primary_states"]
	var state_active: bool = true
	if state == "ASLEEP":
		state_active = not bool(definition["sleep_gated"])
	elif not states.is_empty():
		state_active = state in states
	var stages: PackedStringArray = definition["active_body_stages"]
	var stage_active: bool = true
	if not stages.is_empty():
		var body_stage: String = String(runtime.get("body_stage", ""))
		if body_stage.is_empty():
			return _failure("missing_body_stage:%s" % instance_id)
		stage_active = body_stage in stages
	return {"ok": true, "error": "", "active": state_active and stage_active}

func _normalized_tags(value: Variant, instance_id: String, field_name: String, allow_empty: bool = false) -> Dictionary:
	if not (value is Array or value is PackedStringArray):
		return _failure("invalid_t07_%s:%s" % [field_name, instance_id])
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_value: Variant in value:
		var text: String = String(raw_value)
		if text.is_empty() or seen.has(text):
			return _failure("invalid_t07_%s:%s" % [field_name, instance_id])
		seen[text] = true
		result.append(text)
	if result.is_empty() and not allow_empty:
		return _failure("invalid_t07_%s:%s" % [field_name, instance_id])
	result.sort()
	return {"ok": true, "error": "", "values": result}

func _tags_overlap(left: PackedStringArray, right: PackedStringArray) -> bool:
	for tag: String in left:
		if tag in right:
			return true
	return false

func _distance(left: Dictionary, right: Dictionary) -> Dictionary:
	var left_cells_result: Dictionary = _occupied_cells(left)
	if not bool(left_cells_result.get("ok", false)):
		return left_cells_result
	var right_cells_result: Dictionary = _occupied_cells(right)
	if not bool(right_cells_result.get("ok", false)):
		return right_cells_result
	var minimum: int = 2147483647
	for left_key: String in left_cells_result["cells"]:
		var left_parts: PackedStringArray = left_key.split(",")
		if left_parts.size() != 2:
			return _failure("invalid_cell_key:%s" % left_key)
		for right_key: String in right_cells_result["cells"]:
			var right_parts: PackedStringArray = right_key.split(",")
			if right_parts.size() != 2:
				return _failure("invalid_cell_key:%s" % right_key)
			var distance: int = absi(int(left_parts[0]) - int(right_parts[0])) + absi(int(left_parts[1]) - int(right_parts[1]))
			minimum = mini(minimum, distance)
	return {"ok": true, "error": "", "distance": minimum}

func _occupied_cells(runtime: Dictionary) -> Dictionary:
	var instance_id: String = String(runtime.get("instance_id", ""))
	var value: Variant = runtime.get("occupied_cells", [])
	if not (value is Array or value is PackedStringArray):
		return _failure("invalid_occupied_cells:%s" % instance_id)
	var cells: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_cell: Variant in value:
		var cell_key: String = String(raw_cell)
		if cell_key.is_empty() or seen.has(cell_key):
			return _failure("invalid_occupied_cells:%s" % instance_id)
		seen[cell_key] = true
		cells.append(cell_key)
	if cells.is_empty():
		return _failure("invalid_occupied_cells:%s" % instance_id)
	cells.sort()
	return {"ok": true, "error": "", "cells": cells}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
