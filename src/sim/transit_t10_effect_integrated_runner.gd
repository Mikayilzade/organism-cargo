extends "res://src/sim/transit_t10_integrated_runner.gd"

const CHANNEL_EFFECT_KIND_TO_FIELD := {
	"HEAT_PULSE": "heat_by_cell",
	"STRESS_FIELD_PULSE": "stress_field_by_cell",
	"CONTAMINATION_PULSE": "contamination_by_cell",
}
const INTERNAL_EFFECT_KIND_TO_FIELD := {
	"CONTAMINATION_CLEANSE": "contamination_load",
	"FOOD_PULSE": "satiety",
}

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var base_result: Dictionary = super.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(base_result.get("ok", false)):
		return base_result
	var effects_value: Variant = base_result.get("t10_effect_records", [])
	if not effects_value is Array or (effects_value as Array).is_empty():
		return base_result
	return integrate_effects(base_result, simulation_defs)

func integrate_effects(base_result: Dictionary, simulation_defs: Dictionary = {}) -> Dictionary:
	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	var checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not snapshots_value is Array:
		return _failure("invalid_end_tick_snapshots")
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return _failure("invalid_tick_checksums")
	var snapshots: Array = snapshots_value
	var base_checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return _failure("t10_effect_tick_checksum_count_mismatch")

	var carry: Dictionary = {
		"channel_delta_by_name": {},
		"organism_delta_by_id": {},
	}
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_application_events: Array = []

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return _failure("invalid_end_tick_snapshot")
		var snapshot: Dictionary = (raw_snapshot as Dictionary).duplicate(true)
		var carry_result: Dictionary = _apply_carry(snapshot, carry, simulation_defs)
		if not bool(carry_result.get("ok", false)):
			return carry_result
		snapshot = carry_result["snapshot"]

		var records_value: Variant = snapshot.get("t10_effect_records", [])
		if not records_value is Array:
			return _failure("invalid_t10_effect_records")
		var records: Array = records_value
		var applied_result: Dictionary = _apply_effect_records(snapshot, records, carry, simulation_defs)
		if not bool(applied_result.get("ok", false)):
			return applied_result
		snapshot = applied_result["snapshot"]
		carry = applied_result["carry"]
		var application_events: Array = applied_result["events"]
		snapshot["t10_effect_application_events"] = application_events.duplicate(true)
		snapshot["t10_effect_carry_state"] = carry.duplicate(true)
		integrated_snapshots.append(snapshot)
		for raw_event: Variant in application_events:
			if raw_event is Dictionary:
				all_application_events.append((raw_event as Dictionary).duplicate(true))
		var checksum_material: String = "%s|t10_effect_apply=%s|t10_effect_carry=%s" % [
			String(base_checksums[index]),
			_serialize_application_events(application_events),
			_serialize_carry(carry),
		]
		integrated_checksums.append(checksum_material.sha256_text())

	var result: Dictionary = base_result.duplicate(true)
	result["end_tick_snapshots"] = integrated_snapshots
	result["tick_checksums"] = integrated_checksums
	result["t10_effect_application_events"] = all_application_events
	result["t10_effect_carry_state"] = carry.duplicate(true)
	return result

func _apply_carry(snapshot: Dictionary, carry: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var next_snapshot: Dictionary = snapshot.duplicate(true)
	var channels_value: Variant = carry.get("channel_delta_by_name", {})
	if not channels_value is Dictionary:
		return _failure("invalid_t10_channel_carry")
	var channels: Dictionary = channels_value
	for raw_channel: Variant in channels.keys():
		var channel: String = String(raw_channel)
		var field_key: String = _field_key_for_channel(channel)
		if field_key.is_empty():
			return _failure("invalid_t10_carry_channel:%s" % channel)
		var field_value: Variant = next_snapshot.get(field_key, null)
		if not field_value is Dictionary or (field_value as Dictionary).is_empty():
			continue
		var bounds: Dictionary = _channel_bounds(channel, simulation_defs)
		if not bool(bounds.get("ok", false)):
			return bounds
		var field: Dictionary = (field_value as Dictionary).duplicate(true)
		var delta_value: Variant = channels[raw_channel]
		if not delta_value is Dictionary:
			return _failure("invalid_t10_channel_carry_map:%s" % channel)
		var delta_by_cell: Dictionary = delta_value
		for raw_cell: Variant in delta_by_cell.keys():
			var cell_key: String = String(raw_cell)
			if not field.has(cell_key):
				continue
			field[cell_key] = clampi(
				int(field[cell_key]) + int(delta_by_cell[raw_cell]),
				int(bounds["min"]),
				int(bounds["max"])
			)
		next_snapshot[field_key] = field

	var organism_carry_value: Variant = carry.get("organism_delta_by_id", {})
	if not organism_carry_value is Dictionary:
		return _failure("invalid_t10_organism_carry")
	var runtime_value: Variant = next_snapshot.get("organism_runtime", [])
	if runtime_value is Array and not (runtime_value as Array).is_empty():
		var runtime: Array = (runtime_value as Array).duplicate(true)
		var index_result: Dictionary = _runtime_index(runtime)
		if not bool(index_result.get("ok", false)):
			return index_result
		var index_by_id: Dictionary = index_result["index_by_id"]
		var organism_carry: Dictionary = organism_carry_value
		for raw_id: Variant in organism_carry.keys():
			var instance_id: String = String(raw_id)
			if not index_by_id.has(instance_id):
				continue
			var field_deltas_value: Variant = organism_carry[raw_id]
			if not field_deltas_value is Dictionary:
				return _failure("invalid_t10_organism_carry_fields:%s" % instance_id)
			var runtime_index: int = int(index_by_id[instance_id])
			var organism: Dictionary = runtime[runtime_index]
			var field_deltas: Dictionary = field_deltas_value
			for raw_field: Variant in field_deltas.keys():
				var field_name: String = String(raw_field)
				var bounds: Dictionary = _organism_field_bounds(organism, instance_id, field_name, simulation_defs)
				if not bool(bounds.get("available", false)):
					continue
				organism[field_name] = clampi(
					int(organism.get(field_name, 0)) + int(field_deltas[raw_field]),
					int(bounds["min"]),
					int(bounds["max"])
				)
			runtime[runtime_index] = organism
		next_snapshot["organism_runtime"] = runtime
	return {"ok": true, "error": "", "snapshot": next_snapshot}

func _apply_effect_records(snapshot: Dictionary, records: Array, carry: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var next_snapshot: Dictionary = snapshot.duplicate(true)
	var next_carry: Dictionary = carry.duplicate(true)
	var events: Array = []
	var ordered: Array = records.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("event_id", "")) < String(right.get("event_id", ""))
	)
	for raw_record: Variant in ordered:
		if not raw_record is Dictionary:
			return _failure("invalid_t10_effect_record")
		var record: Dictionary = raw_record
		var effect_kind: String = String(record.get("kind", ""))
		var magnitude: int = int(record.get("magnitude", 0))
		if magnitude <= 0:
			return _failure("invalid_t10_effect_magnitude:%s" % String(record.get("event_id", "")))
		if CHANNEL_EFFECT_KIND_TO_FIELD.has(effect_kind):
			var channel_result: Dictionary = _apply_channel_effect(next_snapshot, record, effect_kind, magnitude, next_carry, simulation_defs)
			if not bool(channel_result.get("ok", false)):
				return channel_result
			next_snapshot = channel_result["snapshot"]
			next_carry = channel_result["carry"]
			for raw_event: Variant in channel_result["events"]:
				events.append((raw_event as Dictionary).duplicate(true))
			continue
		if INTERNAL_EFFECT_KIND_TO_FIELD.has(effect_kind):
			var internal_result: Dictionary = _apply_internal_effect(next_snapshot, record, effect_kind, magnitude, next_carry, simulation_defs)
			if not bool(internal_result.get("ok", false)):
				return internal_result
			next_snapshot = internal_result["snapshot"]
			next_carry = internal_result["carry"]
			for raw_event: Variant in internal_result["events"]:
				events.append((raw_event as Dictionary).duplicate(true))
			continue
		return _failure("unsupported_t10_effect_kind:%s" % effect_kind)
	return {"ok": true, "error": "", "snapshot": next_snapshot, "carry": next_carry, "events": events}

func _apply_channel_effect(snapshot: Dictionary, record: Dictionary, effect_kind: String, magnitude: int, carry: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var channel: String = _channel_for_effect(effect_kind)
	var field_key: String = String(CHANNEL_EFFECT_KIND_TO_FIELD[effect_kind])
	var field_value: Variant = snapshot.get(field_key, null)
	if not field_value is Dictionary or (field_value as Dictionary).is_empty():
		return _skipped(snapshot, carry, record, "authority_unavailable")
	var bounds: Dictionary = _channel_bounds(channel, simulation_defs)
	if not bool(bounds.get("ok", false)):
		return bounds
	var target_result: Dictionary = _target_cells(snapshot, record)
	if not bool(target_result.get("ok", false)):
		return target_result
	var target_cells: PackedStringArray = target_result["cells"]
	var field: Dictionary = (field_value as Dictionary).duplicate(true)
	var next_carry: Dictionary = carry.duplicate(true)
	var events: Array = []
	for cell_key: String in target_cells:
		if not field.has(cell_key):
			return _failure("t10_effect_target_outside_channel:%s:%s" % [effect_kind, cell_key])
		var before: int = int(field[cell_key])
		var after: int = clampi(before + magnitude, int(bounds["min"]), int(bounds["max"]))
		var applied_delta: int = after - before
		field[cell_key] = after
		_next_channel_carry(next_carry, channel, cell_key, applied_delta)
		events.append(_application_event(record, effect_kind, before, after, applied_delta, cell_key))
	var next_snapshot: Dictionary = snapshot.duplicate(true)
	next_snapshot[field_key] = field
	return {"ok": true, "error": "", "snapshot": next_snapshot, "carry": next_carry, "events": events}

func _apply_internal_effect(snapshot: Dictionary, record: Dictionary, effect_kind: String, magnitude: int, carry: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var runtime_value: Variant = snapshot.get("organism_runtime", [])
	if not runtime_value is Array or (runtime_value as Array).is_empty():
		return _skipped(snapshot, carry, record, "authority_unavailable")
	var runtime: Array = (runtime_value as Array).duplicate(true)
	var index_result: Dictionary = _runtime_index(runtime)
	if not bool(index_result.get("ok", false)):
		return index_result
	var target_instance_id: String = String(record.get("target_instance_id", record.get("source_instance_id", "")))
	var index_by_id: Dictionary = index_result["index_by_id"]
	if target_instance_id.is_empty() or not index_by_id.has(target_instance_id):
		return _failure("invalid_t10_effect_target_instance:%s" % target_instance_id)
	var runtime_index: int = int(index_by_id[target_instance_id])
	var organism: Dictionary = runtime[runtime_index]
	var field_name: String = String(INTERNAL_EFFECT_KIND_TO_FIELD[effect_kind])
	var bounds: Dictionary = _organism_field_bounds(organism, target_instance_id, field_name, simulation_defs)
	if not bool(bounds.get("available", false)):
		return _skipped(snapshot, carry, record, "authority_unavailable")
	var before: int = int(organism.get(field_name, 0))
	var signed_delta: int = -magnitude if effect_kind == "CONTAMINATION_CLEANSE" else magnitude
	var after: int = clampi(before + signed_delta, int(bounds["min"]), int(bounds["max"]))
	var applied_delta: int = after - before
	organism[field_name] = after
	runtime[runtime_index] = organism
	var next_snapshot: Dictionary = snapshot.duplicate(true)
	next_snapshot["organism_runtime"] = runtime
	var next_carry: Dictionary = carry.duplicate(true)
	_next_organism_carry(next_carry, target_instance_id, field_name, applied_delta)
	return {
		"ok": true,
		"error": "",
		"snapshot": next_snapshot,
		"carry": next_carry,
		"events": [_application_event(record, effect_kind, before, after, applied_delta, "")],
	}

func _target_cells(snapshot: Dictionary, record: Dictionary) -> Dictionary:
	var explicit_value: Variant = record.get("target_cells", null)
	if explicit_value is Array or explicit_value is PackedStringArray:
		var explicit_cells: PackedStringArray = PackedStringArray()
		for raw_cell: Variant in explicit_value:
			explicit_cells.append(String(raw_cell))
		explicit_cells.sort()
		if explicit_cells.is_empty():
			return _failure("empty_t10_effect_target_cells")
		return {"ok": true, "error": "", "cells": explicit_cells}
	var target_instance_id: String = String(record.get("target_instance_id", record.get("source_instance_id", "")))
	var runtime_value: Variant = snapshot.get("organism_runtime", [])
	if not runtime_value is Array:
		return _failure("missing_t10_effect_runtime")
	for raw_runtime: Variant in runtime_value:
		if not raw_runtime is Dictionary:
			return _failure("invalid_t10_effect_runtime")
		var runtime: Dictionary = raw_runtime
		if String(runtime.get("instance_id", "")) != target_instance_id:
			continue
		var cells_value: Variant = runtime.get("occupied_cells", [])
		if not (cells_value is Array or cells_value is PackedStringArray):
			return _failure("invalid_t10_effect_target_cells:%s" % target_instance_id)
		var cells: PackedStringArray = PackedStringArray()
		for raw_cell: Variant in cells_value:
			cells.append(String(raw_cell))
		cells.sort()
		if cells.is_empty():
			return _failure("empty_t10_effect_target_cells:%s" % target_instance_id)
		return {"ok": true, "error": "", "cells": cells}
	return _failure("missing_t10_effect_target_instance:%s" % target_instance_id)

func _runtime_index(runtime: Array) -> Dictionary:
	var index_by_id: Dictionary = {}
	for index: int in range(runtime.size()):
		var raw_runtime: Variant = runtime[index]
		if not raw_runtime is Dictionary:
			return _failure("invalid_t10_effect_runtime")
		var organism: Dictionary = raw_runtime
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or index_by_id.has(instance_id):
			return _failure("invalid_t10_effect_runtime_identity")
		index_by_id[instance_id] = index
	return {"ok": true, "error": "", "index_by_id": index_by_id}

func _channel_bounds(channel: String, simulation_defs: Dictionary) -> Dictionary:
	var rules_key: String = ""
	var min_key: String = ""
	var max_key: String = ""
	match channel:
		"heat":
			rules_key = "thermal_rules"
			min_key = "heat_min"
			max_key = "heat_max"
		"stress_field":
			rules_key = "stress_field_rules"
			min_key = "stress_field_min"
			max_key = "stress_field_max"
		"contamination":
			rules_key = "contamination_rules"
			min_key = "contamination_min"
			max_key = "contamination_max"
		_:
			return _failure("invalid_t10_effect_channel:%s" % channel)
	var rules_value: Variant = simulation_defs.get(rules_key, null)
	if not rules_value is Dictionary:
		return _failure("missing_t10_effect_bounds:%s" % channel)
	var rules: Dictionary = rules_value
	if not rules.has(min_key) or not rules.has(max_key):
		return _failure("missing_t10_effect_bounds:%s" % channel)
	var min_value: int = int(rules[min_key])
	var max_value: int = int(rules[max_key])
	if min_value > max_value:
		return _failure("invalid_t10_effect_bounds:%s" % channel)
	return {"ok": true, "error": "", "min": min_value, "max": max_value}

func _organism_field_bounds(organism: Dictionary, instance_id: String, field_name: String, simulation_defs: Dictionary) -> Dictionary:
	if not organism.has(field_name):
		return {"available": false}
	if field_name == "contamination_load":
		var profile_value: Variant = organism.get("contamination_profile", null)
		if not profile_value is Dictionary:
			return {"available": false}
		var profile: Dictionary = profile_value
		if not profile.has("load_min") or not profile.has("load_max"):
			return {"available": false}
		return {"available": true, "min": int(profile["load_min"]), "max": int(profile["load_max"])}
	if field_name == "satiety":
		if organism.has("satiety_max"):
			return {"available": true, "min": int(organism.get("satiety_min", 0)), "max": int(organism["satiety_max"])}
		for definitions_key: String in ["t07_consumer_definitions", "t06_definitions"]:
			var definitions_value: Variant = simulation_defs.get(definitions_key, [])
			if not definitions_value is Array:
				continue
			for raw_definition: Variant in definitions_value:
				if raw_definition is Dictionary:
					var definition: Dictionary = raw_definition
					if String(definition.get("instance_id", "")) == instance_id and definition.has("satiety_max"):
						return {"available": true, "min": 0, "max": int(definition["satiety_max"])}
	return {"available": false}

func _next_channel_carry(carry: Dictionary, channel: String, cell_key: String, delta: int) -> void:
	if delta == 0:
		return
	var channels: Dictionary = carry.get("channel_delta_by_name", {})
	var delta_by_cell: Dictionary = channels.get(channel, {})
	delta_by_cell[cell_key] = int(delta_by_cell.get(cell_key, 0)) + delta
	channels[channel] = delta_by_cell
	carry["channel_delta_by_name"] = channels

func _next_organism_carry(carry: Dictionary, instance_id: String, field_name: String, delta: int) -> void:
	if delta == 0:
		return
	var organisms: Dictionary = carry.get("organism_delta_by_id", {})
	var fields: Dictionary = organisms.get(instance_id, {})
	fields[field_name] = int(fields.get(field_name, 0)) + delta
	organisms[instance_id] = fields
	carry["organism_delta_by_id"] = organisms

func _application_event(record: Dictionary, effect_kind: String, before: int, after: int, applied_delta: int, cell_key: String) -> Dictionary:
	var event_id: String = "%s:applied" % String(record.get("event_id", ""))
	if not cell_key.is_empty():
		event_id += ":%s" % cell_key
	var event: Dictionary = {
		"event_id": event_id,
		"kind": "T10_EFFECT_APPLIED",
		"phase": "H",
		"tick": int(record.get("tick", 0)),
		"effect_kind": effect_kind,
		"source_instance_id": String(record.get("source_instance_id", "")),
		"target_instance_id": String(record.get("target_instance_id", record.get("source_instance_id", ""))),
		"trait_id": String(record.get("trait_id", "")),
		"magnitude": int(record.get("magnitude", 0)),
		"value_before": before,
		"value_after": after,
		"applied_delta": applied_delta,
		"parent_event_ids": PackedStringArray([String(record.get("event_id", ""))]),
	}
	if not cell_key.is_empty():
		event["cell_key"] = cell_key
	return event

func _skipped(snapshot: Dictionary, carry: Dictionary, record: Dictionary, reason: String) -> Dictionary:
	return {
		"ok": true,
		"error": "",
		"snapshot": snapshot.duplicate(true),
		"carry": carry.duplicate(true),
		"events": [{
			"event_id": "%s:skipped" % String(record.get("event_id", "")),
			"kind": "T10_EFFECT_SKIPPED",
			"phase": "H",
			"tick": int(record.get("tick", 0)),
			"effect_kind": String(record.get("kind", "")),
			"reason": reason,
			"parent_event_ids": PackedStringArray([String(record.get("event_id", ""))]),
		}],
	}

func _field_key_for_channel(channel: String) -> String:
	match channel:
		"heat": return "heat_by_cell"
		"stress_field": return "stress_field_by_cell"
		"contamination": return "contamination_by_cell"
		_: return ""

func _channel_for_effect(effect_kind: String) -> String:
	match effect_kind:
		"HEAT_PULSE": return "heat"
		"STRESS_FIELD_PULSE": return "stress_field"
		"CONTAMINATION_PULSE": return "contamination"
		_: return ""

func _serialize_application_events(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			parts.append("%s:%s:%s:%d:%d" % [
				String(event.get("event_id", "")),
				String(event.get("kind", "")),
				String(event.get("effect_kind", "")),
				int(event.get("value_after", 0)),
				int(event.get("applied_delta", 0)),
			])
	return ";".join(parts)

func _serialize_carry(carry: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var channels: Dictionary = carry.get("channel_delta_by_name", {})
	var channel_keys: Array = channels.keys()
	channel_keys.sort()
	for raw_channel: Variant in channel_keys:
		var channel: String = String(raw_channel)
		var delta_by_cell: Dictionary = channels[raw_channel]
		var cell_keys: Array = delta_by_cell.keys()
		cell_keys.sort()
		for raw_cell: Variant in cell_keys:
			parts.append("c:%s:%s:%d" % [channel, String(raw_cell), int(delta_by_cell[raw_cell])])
	var organisms: Dictionary = carry.get("organism_delta_by_id", {})
	var organism_ids: Array = organisms.keys()
	organism_ids.sort()
	for raw_id: Variant in organism_ids:
		var instance_id: String = String(raw_id)
		var fields: Dictionary = organisms[raw_id]
		var field_names: Array = fields.keys()
		field_names.sort()
		for raw_field: Variant in field_names:
			parts.append("o:%s:%s:%d" % [instance_id, String(raw_field), int(fields[raw_field])])
	return ";".join(parts)

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
