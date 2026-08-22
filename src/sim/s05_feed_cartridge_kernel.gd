class_name S05FeedCartridgeKernel
extends RefCounted

func prepare_support_states(supports: Array, support_definitions_by_id: Dictionary) -> Dictionary:
	var states: Array = []
	var seen: Dictionary = {}
	for raw_support: Variant in supports:
		if not raw_support is Dictionary:
			return _failure("invalid_support_runtime")
		var support: Dictionary = raw_support
		var instance_id: String = String(support.get("instance_id", ""))
		var support_id: String = String(support.get("support_id", ""))
		if instance_id.is_empty() or support_id.is_empty():
			return _failure("invalid_support_runtime_identity")
		if not support_definitions_by_id.has(support_id) or not support_definitions_by_id[support_id] is Dictionary:
			return _failure("missing_support_definition:%s" % support_id)
		var definition: Dictionary = support_definitions_by_id[support_id]
		if String(definition.get("family", "")) != "S05":
			continue
		if seen.has(instance_id):
			return _failure("duplicate_s05_support_instance:%s" % instance_id)
		var capacity: int = int(definition.get("capacity", 0))
		if capacity <= 0:
			return _failure("invalid_s05_capacity:%s" % support_id)
		var fixture_id: String = String(support.get("fixture_id", ""))
		var anchor: Array = []
		var anchor_value: Variant = support.get("anchor", [])
		if anchor_value is Array:
			var anchor_array: Array = anchor_value
			if anchor_array.size() == 2:
				anchor = anchor_array.duplicate(true)
		if fixture_id.is_empty() and anchor.is_empty():
			return _failure("missing_s05_spatial_placement:%s" % instance_id)
		seen[instance_id] = true
		states.append({
			"instance_id": instance_id,
			"support_id": support_id,
			"fixture_id": fixture_id,
			"anchor": anchor,
			"initial_food_units": capacity,
			"remaining_food_units": capacity,
		})
	states.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	return {
		"ok": true,
		"error": "",
		"support_states": states,
		"events": [],
		"checksum_material": _checksum_material(states, []),
	}

func apply_phase_e_allocations(tick: int, support_states: Array, resolved_allocations: Array) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var state_result: Dictionary = _validated_states(support_states)
	if not bool(state_result.get("ok", false)):
		return state_result
	var next_states: Array = state_result["support_states"]
	var index_by_id: Dictionary = state_result["index_by_id"]
	var allocation_result: Dictionary = _normalized_allocations(resolved_allocations)
	if not bool(allocation_result.get("ok", false)):
		return allocation_result
	var allocations: Array = allocation_result["allocations"]

	var requested_by_support: Dictionary = {}
	for raw_allocation: Variant in allocations:
		var allocation: Dictionary = raw_allocation
		var support_instance_id: String = String(allocation["support_instance_id"])
		if not index_by_id.has(support_instance_id):
			return _failure("unknown_s05_support:%s" % support_instance_id)
		requested_by_support[support_instance_id] = int(requested_by_support.get(support_instance_id, 0)) + int(allocation["food_units"])
	for raw_support_id: Variant in requested_by_support.keys():
		var support_instance_id: String = String(raw_support_id)
		var state_index: int = int(index_by_id[support_instance_id])
		var state: Dictionary = next_states[state_index]
		if int(requested_by_support[support_instance_id]) > int(state["remaining_food_units"]):
			return _failure("s05_allocation_exceeds_reserve:%s" % support_instance_id)

	var events: Array = []
	for raw_allocation: Variant in allocations:
		var allocation: Dictionary = raw_allocation
		var support_instance_id: String = String(allocation["support_instance_id"])
		var consumer_id: String = String(allocation["consumer_id"])
		var food_units: int = int(allocation["food_units"])
		var state_index: int = int(index_by_id[support_instance_id])
		var current: Dictionary = next_states[state_index]
		var before: int = int(current["remaining_food_units"])
		var after: int = before - food_units
		var updated: Dictionary = current.duplicate(true)
		updated["remaining_food_units"] = after
		next_states[state_index] = updated
		events.append({
			"event_id": "t%04d:E:S05:%s:%s" % [tick, support_instance_id, consumer_id],
			"tick": tick,
			"phase": "E",
			"kind": "S05_FOOD_RESERVE_ALLOCATED",
			"support_instance_id": support_instance_id,
			"consumer_id": consumer_id,
			"food_units": food_units,
			"source_cost_units": food_units,
			"reserve_before": before,
			"reserve_after": after,
			"parent_event_ids": PackedStringArray(),
		})

	return {
		"ok": true,
		"error": "",
		"support_states": next_states,
		"allocations": allocations,
		"events": events,
		"checksum_material": _checksum_material(next_states, events),
	}

func _validated_states(support_states: Array) -> Dictionary:
	var states: Array = support_states.duplicate(true)
	states.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))
	)
	var index_by_id: Dictionary = {}
	for index: int in range(states.size()):
		if not states[index] is Dictionary:
			return _failure("invalid_s05_support_state")
		var state: Dictionary = states[index]
		var instance_id: String = String(state.get("instance_id", ""))
		var support_id: String = String(state.get("support_id", ""))
		var initial_food_units: int = int(state.get("initial_food_units", 0))
		var remaining_food_units: int = int(state.get("remaining_food_units", -1))
		if instance_id.is_empty() or support_id.is_empty() or index_by_id.has(instance_id):
			return _failure("invalid_s05_support_state_identity")
		if initial_food_units <= 0 or remaining_food_units < 0 or remaining_food_units > initial_food_units:
			return _failure("invalid_s05_reserve:%s" % instance_id)
		index_by_id[instance_id] = index
	return {"ok": true, "error": "", "support_states": states, "index_by_id": index_by_id}

func _normalized_allocations(resolved_allocations: Array) -> Dictionary:
	var units_by_pair: Dictionary = {}
	for raw_allocation: Variant in resolved_allocations:
		if not raw_allocation is Dictionary:
			return _failure("invalid_s05_allocation")
		var allocation: Dictionary = raw_allocation
		var support_instance_id: String = String(allocation.get("support_instance_id", ""))
		var consumer_id: String = String(allocation.get("consumer_id", ""))
		var food_units: int = int(allocation.get("food_units", 0))
		if support_instance_id.is_empty() or consumer_id.is_empty() or food_units <= 0:
			return _failure("invalid_s05_allocation")
		var pair_key: String = support_instance_id + "\u001f" + consumer_id
		units_by_pair[pair_key] = int(units_by_pair.get(pair_key, 0)) + food_units
	var pair_keys: Array = units_by_pair.keys()
	pair_keys.sort()
	var allocations: Array = []
	for raw_key: Variant in pair_keys:
		var pair_key: String = String(raw_key)
		var separator_index: int = pair_key.find("\u001f")
		if separator_index <= 0:
			return _failure("invalid_s05_allocation_key")
		allocations.append({
			"support_instance_id": pair_key.substr(0, separator_index),
			"consumer_id": pair_key.substr(separator_index + 1),
			"food_units": int(units_by_pair[pair_key]),
		})
	return {"ok": true, "error": "", "allocations": allocations}

func _checksum_material(states: Array, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_state: Variant in states:
		if raw_state is Dictionary:
			var state: Dictionary = raw_state
			parts.append("s:%s:%d:%d" % [
				String(state.get("instance_id", "")),
				int(state.get("initial_food_units", 0)),
				int(state.get("remaining_food_units", 0)),
			])
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			parts.append("e:%s:%s:%s:%d:%d" % [
				String(event.get("event_id", "")),
				String(event.get("support_instance_id", "")),
				String(event.get("consumer_id", "")),
				int(event.get("food_units", 0)),
				int(event.get("reserve_after", 0)),
			])
	return "|".join(parts)

func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"support_states": [],
		"allocations": [],
		"events": [],
		"checksum_material": "",
	}
