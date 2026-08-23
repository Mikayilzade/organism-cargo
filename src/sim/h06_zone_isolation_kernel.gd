class_name H06ZoneIsolationKernel
extends RefCounted

const CHANNEL_ORDER := ["heat", "stress_field", "contamination"]

func resolve_phase_d(
		tick: int,
		cell_order: PackedStringArray,
		active_hazards: PackedStringArray,
		hazards_by_id: Dictionary,
		rules_by_channel: Dictionary
) -> Dictionary:
	var cell_error: String = _validate_cell_order(cell_order)
	if not cell_error.is_empty():
		return _failure(cell_error)
	var isolated_by_edge: Dictionary = {}
	var ordered_hazards: PackedStringArray = active_hazards.duplicate()
	ordered_hazards.sort()
	for hazard_id: String in ordered_hazards:
		if not hazards_by_id.has(hazard_id) or not hazards_by_id[hazard_id] is Dictionary:
			return _failure("missing_hazard_definition:%s" % hazard_id)
		var hazard: Dictionary = hazards_by_id[hazard_id]
		if String(hazard.get("family", "")) != "H06":
			continue
		var edges_value: Variant = hazard.get("isolated_edges", null)
		if not edges_value is Array:
			return _failure("invalid_h06_isolated_edges:%s" % hazard_id)
		var seen_for_hazard: Dictionary = {}
		for raw_edge: Variant in edges_value:
			if not raw_edge is Dictionary:
				return _failure("invalid_h06_isolated_edge:%s" % hazard_id)
			var edge: Dictionary = raw_edge
			var a: String = String(edge.get("a", ""))
			var b: String = String(edge.get("b", ""))
			if a.is_empty() or b.is_empty() or not a in cell_order or not b in cell_order:
				return _failure("invalid_h06_isolated_edge:%s" % hazard_id)
			if not _orthogonally_adjacent(a, b):
				return _failure("non_orthogonal_h06_boundary:%s:%s>%s" % [hazard_id, a, b])
			var edge_key: String = _edge_key(a, b)
			if seen_for_hazard.has(edge_key):
				return _failure("duplicate_h06_isolated_edge:%s:%s" % [hazard_id, edge_key])
			seen_for_hazard[edge_key] = true
			var hazard_ids: PackedStringArray = isolated_by_edge.get(edge_key, PackedStringArray())
			hazard_ids.append(hazard_id)
			hazard_ids.sort()
			isolated_by_edge[edge_key] = hazard_ids

	var effective_rules: Dictionary = rules_by_channel.duplicate(true)
	var events: Array = []
	for channel: String in CHANNEL_ORDER:
		if not effective_rules.has(channel):
			continue
		if not effective_rules[channel] is Dictionary:
			return _failure("invalid_h06_channel_rules:%s" % channel)
		var rules: Dictionary = (effective_rules[channel] as Dictionary).duplicate(true)
		var transfer_value: Variant = rules.get("transfer_edges", [])
		if not transfer_value is Array:
			return _failure("invalid_h06_transfer_edges:%s" % channel)
		var retained: Array = []
		for raw_transfer: Variant in transfer_value:
			if not raw_transfer is Dictionary:
				return _failure("invalid_h06_transfer_edge:%s" % channel)
			var transfer: Dictionary = raw_transfer
			var from_key: String = String(transfer.get("from", ""))
			var to_key: String = String(transfer.get("to", ""))
			var edge_key: String = _edge_key(from_key, to_key)
			if isolated_by_edge.has(edge_key):
				events.append({
					"kind": "H06_PROPAGATION_ISOLATED",
					"phase": "D",
					"tick": tick,
					"channel": channel,
					"from": from_key,
					"to": to_key,
					"amount": int(transfer.get("amount", 0)),
					"hazard_ids": (isolated_by_edge[edge_key] as PackedStringArray).duplicate(),
				})
				continue
			retained.append(transfer.duplicate(true))
		rules["transfer_edges"] = retained
		effective_rules[channel] = rules

	events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_key: String = "%s|%s|%s" % [String(left.get("channel", "")), String(left.get("from", "")), String(left.get("to", ""))]
		var right_key: String = "%s|%s|%s" % [String(right.get("channel", "")), String(right.get("from", "")), String(right.get("to", ""))]
		return left_key < right_key
	)
	var payload: String = _serialize_authority(tick, isolated_by_edge, events)
	return {
		"ok": true,
		"error": "",
		"rules_by_channel": effective_rules,
		"isolated_edges": isolated_by_edge.duplicate(true),
		"events": events,
		"authority_payload": payload,
		"authority_checksum": payload.sha256_text(),
	}

func _validate_cell_order(cell_order: PackedStringArray) -> String:
	if cell_order.is_empty():
		return "missing_h06_cell_order"
	var seen: Dictionary = {}
	for cell_key: String in cell_order:
		if cell_key.is_empty() or seen.has(cell_key):
			return "invalid_h06_cell_order"
		seen[cell_key] = true
	return ""

func _edge_key(a: String, b: String) -> String:
	return "%s>%s" % [a, b] if a < b else "%s>%s" % [b, a]

func _orthogonally_adjacent(left_key: String, right_key: String) -> bool:
	var left: PackedStringArray = left_key.split(",")
	var right: PackedStringArray = right_key.split(",")
	if left.size() != 2 or right.size() != 2:
		return false
	return absi(int(left[0]) - int(right[0])) + absi(int(left[1]) - int(right[1])) == 1

func _serialize_authority(tick: int, isolated_by_edge: Dictionary, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray(["tick=%d" % tick])
	var edge_keys: Array = isolated_by_edge.keys()
	edge_keys.sort_custom(func(left: Variant, right: Variant) -> bool:
		return String(left) < String(right)
	)
	for raw_edge_key: Variant in edge_keys:
		var edge_key: String = String(raw_edge_key)
		var hazard_ids: PackedStringArray = isolated_by_edge[raw_edge_key]
		parts.append("edge=%s:%s" % [edge_key, ",".join(hazard_ids)])
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			parts.append("event=%s:%s>%s:%d" % [
				String(event.get("channel", "")),
				String(event.get("from", "")),
				String(event.get("to", "")),
				int(event.get("amount", 0)),
			])
	return "|".join(parts)

func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"rules_by_channel": {},
		"isolated_edges": {},
		"events": [],
		"authority_payload": "",
		"authority_checksum": "",
	}
