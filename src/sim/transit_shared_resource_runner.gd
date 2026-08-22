extends "res://src/sim/transit_shared_resource_runner_base.gd"

const S05_SOURCE_KIND := "S05"

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var authority: Dictionary = _prepare_s05_production_authority(committed_run, simulation_defs)
	if not bool(authority.get("ok", false)):
		return authority
	var base_run: Dictionary = authority["base_run"]
	var base_defs: Dictionary = authority["simulation_defs"]
	var initial_states: Array = authority["initial_states"]
	var result: Dictionary = super.simulate(base_run, total_ticks, base_defs)
	if not bool(result.get("ok", false)):
		return result
	return _integrate_s05_evidence(result, initial_states)

func _prepare_s05_production_authority(committed_run: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	if not committed_run.has("canonical_committed_input") or not committed_run["canonical_committed_input"] is Dictionary:
		return {"ok": false, "error": "missing_committed_input"}
	var committed_input: Dictionary = committed_run["canonical_committed_input"]
	var supports_value: Variant = committed_input.get("supports", [])
	if not supports_value is Array:
		return {"ok": false, "error": "invalid_committed_supports"}
	var support_definitions_value: Variant = simulation_defs.get("support_definitions_by_id", {})
	if not support_definitions_value is Dictionary:
		return {"ok": false, "error": "invalid_support_definitions"}
	var support_definitions: Dictionary = support_definitions_value
	var consumers_value: Variant = simulation_defs.get("t07_consumer_definitions", [])
	if not consumers_value is Array:
		return {"ok": false, "error": "invalid_t07_consumer_definitions"}
	var consumers: Array = consumers_value
	var producer_value: Variant = simulation_defs.get("t07_producer_definitions", [])
	if not producer_value is Array:
		return {"ok": false, "error": "invalid_t07_producer_definitions"}
	var authored_producers: Array = producer_value
	var producers: Array = authored_producers.duplicate(true)
	var retained_supports: Array = []
	var initial_states: Array = []
	var seen_support_instances: Dictionary = {}
	var producer_ids: Dictionary = {}
	for raw_producer: Variant in producers:
		if raw_producer is Dictionary:
			var authored_producer: Dictionary = raw_producer
			producer_ids[String(authored_producer.get("instance_id", ""))] = true

	for raw_support: Variant in supports_value:
		if not raw_support is Dictionary:
			return {"ok": false, "error": "invalid_committed_support"}
		var support: Dictionary = raw_support
		var instance_id: String = String(support.get("instance_id", ""))
		var support_id: String = String(support.get("support_id", ""))
		if instance_id.is_empty() or support_id.is_empty() or seen_support_instances.has(instance_id):
			return {"ok": false, "error": "invalid_committed_support_identity"}
		seen_support_instances[instance_id] = true
		if not support_definitions.has(support_id) or not support_definitions[support_id] is Dictionary:
			return {"ok": false, "error": "missing_support_definition:%s" % support_id}
		var definition: Dictionary = support_definitions[support_id]
		if String(definition.get("family", support_id)) != S05_SOURCE_KIND:
			retained_supports.append(support.duplicate(true))
			continue
		if producer_ids.has(instance_id):
			return {"ok": false, "error": "duplicate_s05_t07_producer_id:%s" % instance_id}
		var capacity: int = int(definition.get("capacity", 0))
		if capacity <= 0:
			return {"ok": false, "error": "invalid_s05_capacity:%s" % support_id}
		var anchor_value: Variant = support.get("anchor", null)
		if not anchor_value is Array:
			return {"ok": false, "error": "unresolved_s05_feeding_position:%s" % instance_id}
		var anchor: Array = anchor_value
		if anchor.size() != 2:
			return {"ok": false, "error": "unresolved_s05_feeding_position:%s" % instance_id}
		var cell_key: String = "%d,%d" % [int(anchor[0]), int(anchor[1])]
		var food_tags_value: Variant = definition.get("food_tags", [])
		if not (food_tags_value is Array or food_tags_value is PackedStringArray):
			return {"ok": false, "error": "invalid_s05_food_tags:%s" % support_id}
		var food_tags: PackedStringArray = PackedStringArray()
		for raw_tag: Variant in food_tags_value:
			var tag: String = String(raw_tag)
			if tag.is_empty() or tag in food_tags:
				return {"ok": false, "error": "invalid_s05_food_tags:%s" % support_id}
			food_tags.append(tag)
		food_tags.sort()
		if food_tags.is_empty():
			return {"ok": false, "error": "invalid_s05_food_tags:%s" % support_id}
		initial_states.append({
			"instance_id": instance_id,
			"support_id": support_id,
			"initial_food_units": capacity,
			"remaining_food_units": capacity,
			"occupied_cells": PackedStringArray([cell_key]),
		})
		if not consumers.is_empty():
			producers.append({
				"instance_id": instance_id,
				"output_units": capacity,
				"food_tags": food_tags,
				"active_primary_states": ["CALM"],
				"active_body_stages": [],
				"sleep_gated": false,
				"source_kind": S05_SOURCE_KIND,
				"finite_reserve_initial": capacity,
				"finite_reserve_remaining": capacity,
				"occupied_cells": PackedStringArray([cell_key]),
			})
			producer_ids[instance_id] = true

	initial_states.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	var base_run: Dictionary = committed_run.duplicate(true)
	var base_input: Dictionary = committed_input.duplicate(true)
	base_input["supports"] = retained_supports
	base_run["canonical_committed_input"] = base_input
	var base_defs: Dictionary = simulation_defs.duplicate(true)
	base_defs["t07_producer_definitions"] = producers
	return {
		"ok": true,
		"error": "",
		"base_run": base_run,
		"simulation_defs": base_defs,
		"initial_states": initial_states,
	}

func _integrate_s05_evidence(result: Dictionary, initial_states: Array) -> Dictionary:
	if initial_states.is_empty():
		result["s05_feed_events"] = []
		result["final_s05_support_states"] = []
		return result
	var snapshots_value: Variant = result.get("end_tick_snapshots", [])
	if not snapshots_value is Array:
		return {"ok": false, "error": "invalid_end_tick_snapshots"}
	var snapshots: Array = snapshots_value
	var checksums_value: Variant = result.get("tick_checksums", PackedStringArray())
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return {"ok": false, "error": "invalid_tick_checksums"}
	var base_checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return {"ok": false, "error": "s05_tick_checksum_count_mismatch"}

	var states: Array = initial_states.duplicate(true)
	var state_index_by_id: Dictionary = {}
	for index: int in range(states.size()):
		var state: Dictionary = states[index]
		state_index_by_id[String(state["instance_id"])] = index
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_events: Array = []
	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return {"ok": false, "error": "invalid_end_tick_snapshot"}
		var typed_snapshot: Dictionary = raw_snapshot
		var snapshot: Dictionary = typed_snapshot.duplicate(true)
		var events_value: Variant = snapshot.get("t07_events", [])
		if not events_value is Array:
			return {"ok": false, "error": "invalid_t07_events"}
		var tick_events: Array = []
		for raw_event: Variant in events_value:
			if not raw_event is Dictionary:
				return {"ok": false, "error": "invalid_t07_event"}
			var event: Dictionary = raw_event
			if String(event.get("kind", "")) != "S05_FOOD_RESERVE_ALLOCATED":
				continue
			var support_instance_id: String = String(event.get("support_instance_id", event.get("producer_id", "")))
			if not state_index_by_id.has(support_instance_id):
				return {"ok": false, "error": "unknown_s05_support_event:%s" % support_instance_id}
			var state_index: int = int(state_index_by_id[support_instance_id])
			var current: Dictionary = states[state_index]
			if int(event.get("reserve_before", -1)) != int(current["remaining_food_units"]):
				return {"ok": false, "error": "s05_reserve_event_discontinuity:%s" % support_instance_id}
			var after: int = int(event.get("reserve_after", -1))
			if after < 0 or after > int(current["remaining_food_units"]):
				return {"ok": false, "error": "invalid_s05_reserve_event:%s" % support_instance_id}
			var next_state: Dictionary = current.duplicate(true)
			next_state["remaining_food_units"] = after
			states[state_index] = next_state
			tick_events.append(event.duplicate(true))
			all_events.append(event.duplicate(true))
		snapshot["s05_feed_events"] = tick_events
		snapshot["s05_support_states"] = states.duplicate(true)
		integrated_snapshots.append(snapshot)
		var checksum_material: String = "%s|s05=%s" % [String(base_checksums[index]), _serialize_s05(states, tick_events)]
		integrated_checksums.append(checksum_material.sha256_text())

	result["end_tick_snapshots"] = integrated_snapshots
	result["tick_checksums"] = integrated_checksums
	result["s05_feed_events"] = all_events
	result["final_s05_support_states"] = states.duplicate(true)
	return result

func _serialize_s05(states: Array, events: Array) -> String:
	var encoded: PackedStringArray = PackedStringArray()
	for raw_state: Variant in states:
		if raw_state is Dictionary:
			var state: Dictionary = raw_state
			encoded.append("s:%s:%d:%d" % [
				String(state.get("instance_id", "")),
				int(state.get("initial_food_units", 0)),
				int(state.get("remaining_food_units", 0)),
			])
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			encoded.append("e:%s:%s:%s:%d:%d:%d" % [
				String(event.get("event_id", "")),
				String(event.get("support_instance_id", "")),
				String(event.get("consumer_id", "")),
				int(event.get("food_units", 0)),
				int(event.get("reserve_before", 0)),
				int(event.get("reserve_after", 0)),
			])
	return ";".join(encoded)
