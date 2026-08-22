extends "res://src/sim/t07_feeding_kernel_base.gd"

const S05_SOURCE_KIND := "S05"

func resolve_tick(
		tick: int,
		organisms: Array,
		producer_definitions: Array,
		consumer_definitions: Array
) -> Dictionary:
	var augmented_organisms: Array = organisms.duplicate(true)
	var active_producers: Array = []
	var s05_ids: PackedStringArray = PackedStringArray()
	var definition_index_by_id: Dictionary = {}
	var reserve_before_by_id: Dictionary = {}

	for index: int in range(producer_definitions.size()):
		var raw_definition: Variant = producer_definitions[index]
		if not raw_definition is Dictionary:
			return _failure("invalid_t07_producer_definition")
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition.get("instance_id", ""))
		if String(definition.get("source_kind", "")) != S05_SOURCE_KIND:
			active_producers.append(definition.duplicate(true))
			continue
		if instance_id.is_empty() or definition_index_by_id.has(instance_id):
			return _failure("invalid_s05_t07_producer_identity")
		var occupied_value: Variant = definition.get("occupied_cells", [])
		if not (occupied_value is Array or occupied_value is PackedStringArray):
			return _failure("invalid_s05_t07_occupied_cells:%s" % instance_id)
		var occupied_cells: PackedStringArray = PackedStringArray()
		for raw_cell: Variant in occupied_value:
			var cell_key: String = String(raw_cell)
			if cell_key.is_empty() or cell_key in occupied_cells:
				return _failure("invalid_s05_t07_occupied_cells:%s" % instance_id)
			occupied_cells.append(cell_key)
		if occupied_cells.is_empty():
			return _failure("invalid_s05_t07_occupied_cells:%s" % instance_id)
		occupied_cells.sort()
		var remaining: int = int(definition.get("finite_reserve_remaining", -1))
		var initial: int = int(definition.get("finite_reserve_initial", 0))
		if initial <= 0 or remaining < 0 or remaining > initial:
			return _failure("invalid_s05_t07_reserve:%s" % instance_id)
		definition_index_by_id[instance_id] = index
		reserve_before_by_id[instance_id] = remaining
		s05_ids.append(instance_id)
		if remaining <= 0:
			continue
		var active_definition: Dictionary = definition.duplicate(true)
		active_definition["output_units"] = remaining
		active_definition.erase("source_kind")
		active_definition.erase("finite_reserve_initial")
		active_definition.erase("finite_reserve_remaining")
		active_definition.erase("occupied_cells")
		active_producers.append(active_definition)
		augmented_organisms.append({
			"instance_id": instance_id,
			"occupied_cells": occupied_cells,
			"primary_state": "CALM",
			"body_stage": "S05_SUPPORT",
		})

	var result: Dictionary = super.resolve_tick(tick, augmented_organisms, active_producers, consumer_definitions)
	if not bool(result.get("ok", false)):
		return result

	var allocation_value: Variant = result.get("allocations", [])
	if not allocation_value is Array:
		return _failure("invalid_t07_allocations")
	var allocations: Array = allocation_value
	var units_by_support: Dictionary = {}
	var units_by_pair: Dictionary = {}
	var parent_ids_by_pair: Dictionary = {}
	for allocation_index: int in range(allocations.size()):
		var raw_allocation: Variant = allocations[allocation_index]
		if not raw_allocation is Dictionary:
			return _failure("invalid_t07_allocation")
		var allocation: Dictionary = raw_allocation
		var producer_id: String = String(allocation.get("producer_id", ""))
		if producer_id not in s05_ids:
			continue
		var consumer_id: String = String(allocation.get("consumer_id", ""))
		units_by_support[producer_id] = int(units_by_support.get(producer_id, 0)) + 1
		var pair_key: String = producer_id + "\u001f" + consumer_id
		units_by_pair[pair_key] = int(units_by_pair.get(pair_key, 0)) + 1
		var parents: PackedStringArray = PackedStringArray()
		var existing_parents_value: Variant = parent_ids_by_pair.get(pair_key, PackedStringArray())
		if existing_parents_value is Array or existing_parents_value is PackedStringArray:
			for raw_parent: Variant in existing_parents_value:
				parents.append(String(raw_parent))
		parents.append("t%04d:E:T07:%s:%s:%03d" % [tick, producer_id, consumer_id, allocation_index])
		parent_ids_by_pair[pair_key] = parents
		var annotated: Dictionary = allocation.duplicate(true)
		annotated["source_kind"] = S05_SOURCE_KIND
		annotated["support_instance_id"] = producer_id
		annotated["food_units"] = 1
		allocations[allocation_index] = annotated

	for support_id: String in s05_ids:
		var used: int = int(units_by_support.get(support_id, 0))
		var before: int = int(reserve_before_by_id[support_id])
		if used > before:
			return _failure("s05_allocation_exceeds_reserve:%s" % support_id)
		var definition_index: int = int(definition_index_by_id[support_id])
		var source_definition: Dictionary = producer_definitions[definition_index]
		source_definition["finite_reserve_remaining"] = before - used
		producer_definitions[definition_index] = source_definition

	var events_value: Variant = result.get("events", [])
	if not events_value is Array:
		return _failure("invalid_t07_events")
	var base_events: Array = events_value
	var phase_e_events: Array = []
	var later_events: Array = []
	for raw_event: Variant in base_events:
		if not raw_event is Dictionary:
			return _failure("invalid_t07_event")
		var event: Dictionary = raw_event
		if String(event.get("phase", "")) == "E":
			phase_e_events.append(event.duplicate(true))
		else:
			later_events.append(event.duplicate(true))

	var pair_keys: Array = units_by_pair.keys()
	pair_keys.sort()
	for raw_pair_key: Variant in pair_keys:
		var pair_key: String = String(raw_pair_key)
		var separator: int = pair_key.find("\u001f")
		if separator <= 0:
			return _failure("invalid_s05_t07_pair_key")
		var support_id: String = pair_key.substr(0, separator)
		var consumer_id: String = pair_key.substr(separator + 1)
		var food_units: int = int(units_by_pair[pair_key])
		var before: int = int(reserve_before_by_id[support_id])
		var used_before_pair: int = 0
		for raw_prior_key: Variant in pair_keys:
			var prior_key: String = String(raw_prior_key)
			if prior_key == pair_key:
				break
			if prior_key.begins_with(support_id + "\u001f"):
				used_before_pair += int(units_by_pair[prior_key])
		var reserve_before: int = before - used_before_pair
		var reserve_after: int = reserve_before - food_units
		var parent_ids: PackedStringArray = PackedStringArray()
		var parent_value: Variant = parent_ids_by_pair.get(pair_key, PackedStringArray())
		if parent_value is Array or parent_value is PackedStringArray:
			for raw_parent: Variant in parent_value:
				parent_ids.append(String(raw_parent))
		phase_e_events.append({
			"event_id": "t%04d:E:S05:%s:%s" % [tick, support_id, consumer_id],
			"tick": tick,
			"phase": "E",
			"kind": "S05_FOOD_RESERVE_ALLOCATED",
			"trait_id": "S05",
			"producer_id": support_id,
			"support_instance_id": support_id,
			"consumer_id": consumer_id,
			"food_units": food_units,
			"source_cost_units": food_units,
			"reserve_before": reserve_before,
			"reserve_after": reserve_after,
			"parent_event_ids": parent_ids,
		})

	var organisms_value: Variant = result.get("organisms", [])
	if not organisms_value is Array:
		return _failure("invalid_t07_result_organisms")
	var result_organisms: Array = organisms_value
	var filtered_organisms: Array = []
	for raw_runtime: Variant in result_organisms:
		if not raw_runtime is Dictionary:
			return _failure("invalid_t07_result_runtime")
		var runtime: Dictionary = raw_runtime
		if String(runtime.get("instance_id", "")) in s05_ids:
			continue
		filtered_organisms.append(runtime.duplicate(true))

	var reserve_states: Array = []
	for support_id: String in s05_ids:
		var definition_index: int = int(definition_index_by_id[support_id])
		var definition: Dictionary = producer_definitions[definition_index]
		reserve_states.append({
			"instance_id": support_id,
			"initial_food_units": int(definition["finite_reserve_initial"]),
			"remaining_food_units": int(definition["finite_reserve_remaining"]),
		})
	reserve_states.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)

	phase_e_events.append_array(later_events)
	result["organisms"] = filtered_organisms
	result["allocations"] = allocations
	result["events"] = phase_e_events
	result["producer_reserve_states"] = reserve_states
	return result
