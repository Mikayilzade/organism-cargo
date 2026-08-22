class_name H05VentCycleKernel
extends RefCounted

const FROZEN_CHANNEL_ORDER := ["heat", "stress_field", "contamination"]

func resolve_phase_d(
		tick: int,
		cell_order: PackedStringArray,
		active_hazards: PackedStringArray,
		hazards_by_id: Dictionary,
		base_vent_by_channel: Dictionary
) -> Dictionary:
	var validation_error: String = _validate_base(tick, cell_order, base_vent_by_channel)
	if not validation_error.is_empty():
		return _failure(validation_error)

	var effective: Dictionary = _copy_vent_maps(base_vent_by_channel, cell_order)
	var ordered_hazards: PackedStringArray = active_hazards.duplicate()
	ordered_hazards.sort()
	var seen_hazards: Dictionary = {}
	var events: Array = []
	for hazard_id: String in ordered_hazards:
		if hazard_id.is_empty() or seen_hazards.has(hazard_id):
			return _failure("invalid_h05_active_hazard_order")
		seen_hazards[hazard_id] = true
		if not hazards_by_id.has(hazard_id) or not hazards_by_id[hazard_id] is Dictionary:
			return _failure("missing_hazard_definition:%s" % hazard_id)
		var hazard: Dictionary = hazards_by_id[hazard_id]
		if String(hazard.get("family", "")) != "H05":
			continue
		var delta_value: Variant = hazard.get("vent_delta_by_channel", null)
		if not delta_value is Dictionary:
			return _failure("invalid_h05_vent_delta_by_channel:%s" % hazard_id)
		var delta_by_channel: Dictionary = delta_value
		var channel_keys: Array = delta_by_channel.keys()
		channel_keys.sort_custom(func(left: Variant, right: Variant) -> bool:
			return String(left) < String(right)
		)
		for raw_channel: Variant in channel_keys:
			var channel: String = String(raw_channel)
			if not channel in FROZEN_CHANNEL_ORDER:
				return _failure("invalid_h05_channel:%s:%s" % [hazard_id, channel])
			if not effective.has(channel):
				return _failure("h05_channel_not_enabled:%s:%s" % [hazard_id, channel])
			var cell_deltas_value: Variant = delta_by_channel[raw_channel]
			if not cell_deltas_value is Dictionary:
				return _failure("invalid_h05_cell_deltas:%s:%s" % [hazard_id, channel])
			var cell_deltas: Dictionary = cell_deltas_value
			var delta_cells: Array = cell_deltas.keys()
			delta_cells.sort_custom(func(left: Variant, right: Variant) -> bool:
				return String(left) < String(right)
			)
			var channel_vent: Dictionary = effective[channel]
			for raw_cell: Variant in delta_cells:
				var cell_key: String = String(raw_cell)
				if not cell_key in cell_order:
					return _failure("h05_cell_outside_hold:%s:%s:%s" % [hazard_id, channel, cell_key])
				var delta_result: Dictionary = _integral_int(cell_deltas[raw_cell])
				if not bool(delta_result["ok"]):
					return _failure("invalid_h05_vent_delta:%s:%s:%s" % [hazard_id, channel, cell_key])
				var delta: int = int(delta_result["value"])
				var before: int = int(channel_vent.get(cell_key, 0))
				var after: int = before + delta
				if after < 0:
					return _failure("negative_h05_effective_vent:%s:%s:%s" % [hazard_id, channel, cell_key])
				channel_vent[cell_key] = after
				if delta != 0:
					events.append({
						"event_id": "H05:%d:%s:%s:%s" % [tick, hazard_id, channel, cell_key],
						"kind": "H05_VENT_MODIFIED",
						"phase": "D",
						"tick": tick,
						"hazard_id": hazard_id,
						"channel": channel,
						"cell_key": cell_key,
						"vent_delta": delta,
						"vent_before": before,
						"vent_after": after,
					})
			effective[channel] = channel_vent

	var authority_payload: String = _serialize_authority(tick, effective, cell_order, events)
	return {
		"ok": true,
		"error": "",
		"vent_by_channel": effective,
		"events": events,
		"authority_payload": authority_payload,
		"authority_checksum": authority_payload.sha256_text(),
	}

func _validate_base(tick: int, cell_order: PackedStringArray, base_vent_by_channel: Dictionary) -> String:
	if tick <= 0:
		return "invalid_h05_tick"
	if cell_order.is_empty():
		return "missing_h05_cell_order"
	var cell_set: Dictionary = {}
	for cell_key: String in cell_order:
		if cell_key.is_empty() or cell_set.has(cell_key):
			return "invalid_h05_cell_order"
		cell_set[cell_key] = true
	if base_vent_by_channel.is_empty():
		return "missing_h05_base_vent_channels"
	for raw_channel: Variant in base_vent_by_channel.keys():
		var channel: String = String(raw_channel)
		if not channel in FROZEN_CHANNEL_ORDER:
			return "invalid_h05_base_channel:%s" % channel
		var map_value: Variant = base_vent_by_channel[raw_channel]
		if not map_value is Dictionary:
			return "invalid_h05_base_vent_map:%s" % channel
		var vent_map: Dictionary = map_value
		for raw_cell: Variant in vent_map.keys():
			var cell_key: String = String(raw_cell)
			if not cell_set.has(cell_key):
				return "h05_base_cell_outside_hold:%s:%s" % [channel, cell_key]
			var amount_result: Dictionary = _integral_int(vent_map[raw_cell])
			if not bool(amount_result["ok"]) or int(amount_result["value"]) < 0:
				return "invalid_h05_base_vent:%s:%s" % [channel, cell_key]
	return ""

func _copy_vent_maps(base_vent_by_channel: Dictionary, cell_order: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for channel: String in FROZEN_CHANNEL_ORDER:
		if not base_vent_by_channel.has(channel):
			continue
		var source: Dictionary = base_vent_by_channel[channel]
		var copied: Dictionary = {}
		for cell_key: String in cell_order:
			copied[cell_key] = int(source.get(cell_key, 0))
		result[channel] = copied
	return result

func _serialize_authority(tick: int, vent_by_channel: Dictionary, cell_order: PackedStringArray, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray(["tick=%d" % tick])
	for channel: String in FROZEN_CHANNEL_ORDER:
		if not vent_by_channel.has(channel):
			continue
		var vent_map: Dictionary = vent_by_channel[channel]
		for cell_key: String in cell_order:
			parts.append("v:%s:%s:%d" % [channel, cell_key, int(vent_map.get(cell_key, 0))])
	for raw_event: Variant in events:
		var event: Dictionary = raw_event
		parts.append("e:%s:%d:%d:%d" % [
			String(event["event_id"]),
			int(event["vent_delta"]),
			int(event["vent_before"]),
			int(event["vent_after"]),
		])
	return "|".join(parts)

func _integral_int(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_INT:
		return {"ok": true, "value": int(value)}
	if typeof(value) == TYPE_FLOAT:
		var numeric: float = float(value)
		if is_finite(numeric) and numeric == floor(numeric):
			return {"ok": true, "value": int(numeric)}
	return {"ok": false, "value": 0}

func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"vent_by_channel": {},
		"events": [],
		"authority_payload": "",
		"authority_checksum": "",
	}
