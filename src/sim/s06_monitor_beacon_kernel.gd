class_name S06MonitorBeaconKernel
extends RefCounted

const MODE_BOUNDED_FACT := "BOUNDED_FACT"
const MODE_LOCAL_TELEMETRY := "LOCAL_TELEMETRY"

func resolve_tick(
		tick: int,
		committed_supports: Array,
		support_definitions_by_id: Dictionary,
		same_tick_eligible_support_ids: PackedStringArray,
		revelations: Array,
		snapshot: Dictionary,
		revealed_fact_ids: Dictionary = {}
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var support_result: Dictionary = _monitor_supports_by_instance(committed_supports, support_definitions_by_id)
	if not bool(support_result["ok"]):
		return support_result
	var monitors_by_id: Dictionary = support_result["monitors_by_id"]
	var normalized_result: Dictionary = _normalize_revelations(revelations, monitors_by_id)
	if not bool(normalized_result["ok"]):
		return normalized_result
	var normalized: Array = normalized_result["revelations"]
	var next_revealed: Dictionary = revealed_fact_ids.duplicate(true)
	var events: Array = []
	for raw_revelation: Variant in normalized:
		var revelation: Dictionary = raw_revelation
		var support_instance_id: String = String(revelation["support_instance_id"])
		if not same_tick_eligible_support_ids.has(support_instance_id):
			continue
		var mode: String = String(revelation["mode"])
		var revelation_id: String = String(revelation["revelation_id"])
		if mode == MODE_BOUNDED_FACT:
			if next_revealed.has(revelation_id):
				continue
			var fact_value: Variant = revelation["value"]
			events.append({
				"event_id": "s06:%d:%s:%s" % [tick, support_instance_id, revelation_id],
				"kind": "S06_BOUNDED_FACT_REVEALED",
				"phase": "E",
				"tick": tick,
				"support_instance_id": support_instance_id,
				"revelation_id": revelation_id,
				"fact_id": String(revelation["fact_id"]),
				"value": fact_value,
				"parent_event_ids": PackedStringArray(),
			})
			next_revealed[revelation_id] = true
		elif mode == MODE_LOCAL_TELEMETRY:
			var channel: String = String(revelation["channel"])
			var cell_key: String = String(revelation["cell_key"])
			var channel_result: Dictionary = _telemetry_channel(snapshot, channel)
			if not bool(channel_result["ok"]):
				return channel_result
			var channel_by_cell: Dictionary = channel_result["channel_by_cell"]
			if not channel_by_cell.has(cell_key):
				return _failure("s06_telemetry_cell_missing:%s:%s" % [channel, cell_key])
			events.append({
				"event_id": "s06:%d:%s:%s" % [tick, support_instance_id, revelation_id],
				"kind": "S06_LOCAL_TELEMETRY",
				"phase": "E",
				"tick": tick,
				"support_instance_id": support_instance_id,
				"revelation_id": revelation_id,
				"channel": channel,
				"cell_key": cell_key,
				"value": int(channel_by_cell[cell_key]),
				"parent_event_ids": PackedStringArray(),
			})
	return {
		"ok": true,
		"error": "",
		"events": events,
		"revealed_fact_ids": next_revealed,
	}

func _monitor_supports_by_instance(committed_supports: Array, support_definitions_by_id: Dictionary) -> Dictionary:
	var monitors_by_id: Dictionary = {}
	for raw_support: Variant in committed_supports:
		if not raw_support is Dictionary:
			return _failure("invalid_committed_support")
		var support: Dictionary = raw_support
		var instance_id: String = String(support.get("instance_id", ""))
		var support_id: String = String(support.get("support_id", ""))
		if instance_id.is_empty() or support_id.is_empty():
			return _failure("invalid_committed_support_identity")
		if not support_definitions_by_id.has(support_id) or not support_definitions_by_id[support_id] is Dictionary:
			return _failure("missing_support_definition:%s" % support_id)
		var definition: Dictionary = support_definitions_by_id[support_id]
		if String(definition.get("family", support_id)) != "S06":
			continue
		if not bool(definition.get("powered", false)):
			return _failure("s06_must_be_powered:%s" % support_id)
		if monitors_by_id.has(instance_id):
			return _failure("duplicate_s06_instance_id:%s" % instance_id)
		monitors_by_id[instance_id] = support.duplicate(true)
	return {"ok": true, "error": "", "monitors_by_id": monitors_by_id}

func _normalize_revelations(revelations: Array, monitors_by_id: Dictionary) -> Dictionary:
	var normalized: Array = []
	var seen_revelation_ids: Dictionary = {}
	var seen_support_ids: Dictionary = {}
	for raw_revelation: Variant in revelations:
		if not raw_revelation is Dictionary:
			return _failure("invalid_s06_revelation")
		var revelation: Dictionary = raw_revelation
		var revelation_id: String = String(revelation.get("revelation_id", ""))
		var support_instance_id: String = String(revelation.get("support_instance_id", ""))
		var mode: String = String(revelation.get("mode", ""))
		if revelation_id.is_empty() or support_instance_id.is_empty():
			return _failure("invalid_s06_revelation_identity")
		if seen_revelation_ids.has(revelation_id):
			return _failure("duplicate_s06_revelation_id:%s" % revelation_id)
		if seen_support_ids.has(support_instance_id):
			return _failure("s06_support_must_have_one_information_contract:%s" % support_instance_id)
		if not monitors_by_id.has(support_instance_id):
			return _failure("s06_revelation_unknown_monitor:%s" % support_instance_id)
		if mode != MODE_BOUNDED_FACT and mode != MODE_LOCAL_TELEMETRY:
			return _failure("unsupported_s06_revelation_mode:%s" % mode)
		var next: Dictionary = revelation.duplicate(true)
		if mode == MODE_BOUNDED_FACT:
			var fact_id: String = String(revelation.get("fact_id", ""))
			if fact_id.is_empty() or not revelation.has("value"):
				return _failure("invalid_s06_bounded_fact:%s" % revelation_id)
			if not _is_bounded_scalar(revelation["value"]):
				return _failure("s06_fact_value_must_be_scalar:%s" % revelation_id)
		else:
			var channel: String = String(revelation.get("channel", ""))
			var cell_key: String = String(revelation.get("cell_key", ""))
			if channel.is_empty() or cell_key.is_empty():
				return _failure("invalid_s06_local_telemetry:%s" % revelation_id)
		seen_revelation_ids[revelation_id] = true
		seen_support_ids[support_instance_id] = true
		normalized.append(next)
	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_support: String = String(left["support_instance_id"])
		var right_support: String = String(right["support_instance_id"])
		if left_support != right_support:
			return left_support < right_support
		return String(left["revelation_id"]) < String(right["revelation_id"])
	)
	return {"ok": true, "error": "", "revelations": normalized}

func _telemetry_channel(snapshot: Dictionary, channel: String) -> Dictionary:
	var value: Variant = null
	if channel == "heat":
		value = snapshot.get("heat_by_cell", null)
	elif channel == "contamination":
		value = snapshot.get("phase_d_contamination_exposure_by_cell", snapshot.get("contamination_by_cell", null))
	elif channel == "stress_field":
		value = snapshot.get("stress_field_by_cell", null)
	else:
		return _failure("unsupported_s06_telemetry_channel:%s" % channel)
	if not value is Dictionary:
		return _failure("missing_s06_telemetry_channel:%s" % channel)
	var channel_by_cell: Dictionary = value
	return {"ok": true, "error": "", "channel_by_cell": channel_by_cell}

func _is_bounded_scalar(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_BOOL or value_type == TYPE_INT or value_type == TYPE_STRING

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
