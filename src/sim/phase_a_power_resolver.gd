class_name PhaseAPowerResolver
extends RefCounted

func resolve(
		available_power: int,
		installed_supports: Array,
		priority_order: Array,
		previous_powered_by_id: Dictionary = {}
) -> Dictionary:
	if available_power < 0:
		return _failure("invalid_available_power")

	var normalized_by_id: Dictionary = {}
	var support_ids: PackedStringArray = PackedStringArray()
	var total_demand: int = 0
	for raw_support: Variant in installed_supports:
		if not raw_support is Dictionary:
			return _failure("invalid_support_definition")
		var support: Dictionary = raw_support
		var support_id: String = String(support.get("instance_id", ""))
		if support_id.is_empty():
			return _failure("missing_support_instance_id")
		if normalized_by_id.has(support_id):
			return _failure("duplicate_support_instance_id:%s" % support_id)
		if not bool(support.get("powered", false)):
			continue
		var power_draw: int = int(support.get("power_draw", -1))
		if power_draw <= 0:
			return _failure("invalid_power_draw:%s" % support_id)
		if bool(support.get("supports_degraded_operation", false)):
			return _failure("degraded_support_not_implemented:%s" % support_id)
		normalized_by_id[support_id] = {
			"instance_id": support_id,
			"power_draw": power_draw,
		}
		support_ids.append(support_id)
		total_demand += power_draw

	support_ids.sort()
	var powered_by_id: Dictionary = {}
	for support_id: String in support_ids:
		powered_by_id[support_id] = true

	if total_demand > available_power:
		var priority_result: Dictionary = _validate_priority(priority_order, support_ids)
		if not bool(priority_result["ok"]):
			return priority_result
		for support_id: String in support_ids:
			powered_by_id[support_id] = false
		var remaining: int = available_power
		for raw_id: Variant in priority_order:
			var support_id: String = String(raw_id)
			var support: Dictionary = normalized_by_id[support_id]
			var draw: int = int(support["power_draw"])
			if draw <= remaining:
				powered_by_id[support_id] = true
				remaining -= draw

	var powered_support_ids: PackedStringArray = PackedStringArray()
	var disabled_support_ids: PackedStringArray = PackedStringArray()
	var used_power: int = 0
	var events: Array = []
	for support_id: String in support_ids:
		var is_powered: bool = bool(powered_by_id[support_id])
		if is_powered:
			powered_support_ids.append(support_id)
			var support: Dictionary = normalized_by_id[support_id]
			used_power += int(support["power_draw"])
		else:
			disabled_support_ids.append(support_id)
		if previous_powered_by_id.has(support_id):
			var was_powered: bool = bool(previous_powered_by_id[support_id])
			if was_powered != is_powered:
				events.append({
					"type": "SUPPORT_POWER_STATE_CHANGED",
					"support_instance_id": support_id,
					"from_powered": was_powered,
					"to_powered": is_powered,
				})

	var authority_payload: String = _authority_payload(
		available_power,
		used_power,
		support_ids,
		powered_by_id
	)
	return {
		"ok": true,
		"error": "",
		"available_power": available_power,
		"used_power": used_power,
		"remaining_power": available_power - used_power,
		"total_installed_demand": total_demand,
		"brownout_active": total_demand > available_power,
		"powered_by_id": powered_by_id,
		"powered_support_ids": powered_support_ids,
		"disabled_support_ids": disabled_support_ids,
		"same_tick_effect_eligible_support_ids": powered_support_ids.duplicate(),
		"events": events,
		"authority_payload": authority_payload,
		"authority_checksum": authority_payload.sha256_text(),
	}

func _validate_priority(priority_order: Array, support_ids: PackedStringArray) -> Dictionary:
	if priority_order.size() != support_ids.size():
		return _failure("brownout_priority_must_cover_all_powered_supports")
	var expected: Dictionary = {}
	for support_id: String in support_ids:
		expected[support_id] = true
	var seen: Dictionary = {}
	for raw_id: Variant in priority_order:
		var support_id: String = String(raw_id)
		if support_id.is_empty() or not expected.has(support_id):
			return _failure("invalid_brownout_priority_id:%s" % support_id)
		if seen.has(support_id):
			return _failure("duplicate_brownout_priority_id:%s" % support_id)
		seen[support_id] = true
	return {"ok": true, "error": ""}

func _authority_payload(
		available_power: int,
		used_power: int,
		support_ids: PackedStringArray,
		powered_by_id: Dictionary
) -> String:
	var state_parts: PackedStringArray = PackedStringArray()
	for support_id: String in support_ids:
		state_parts.append("%s=%d" % [support_id, 1 if bool(powered_by_id[support_id]) else 0])
	return "phase_a_power|available=%d|used=%d|states=%s" % [
		available_power,
		used_power,
		",".join(state_parts),
	]

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
