class_name BlockedGrowthEpisodeResolver
extends RefCounted

const CONDITION_FLAG := "GROWTH_BLOCKED"

func resolve_attempt(instance_id: String, runtime_state: Dictionary, attempt: Dictionary) -> Dictionary:
	if instance_id.is_empty():
		return _failure("missing_instance_id")
	if not attempt.has("legal"):
		return _failure("missing_attempt_legality")

	var state: Dictionary = _normalized_state(runtime_state)
	if bool(attempt["legal"]):
		state["active"] = false
		state["condition_signature"] = ""
		return {
			"ok": true,
			"error": "",
			"growth_allowed": true,
			"condition_flag": "",
			"entry_consequence_fired": false,
			"episode_started": false,
			"episode_index": int(state["episode_index"]),
			"causal_event": {},
			"state": state,
		}

	var signature_result: Dictionary = _condition_signature(attempt)
	if not bool(signature_result["ok"]):
		return _failure(String(signature_result["error"]))
	var signature: String = String(signature_result["signature"])
	var starts_new_episode: bool = not bool(state["active"]) or String(state["condition_signature"]) != signature
	if starts_new_episode:
		state["episode_index"] = int(state["episode_index"]) + 1
		state["active"] = true
		state["condition_signature"] = signature

	var causal_event: Dictionary = {}
	if starts_new_episode:
		causal_event = {
			"event_id": "growth-blocked:%s:%d" % [instance_id, int(state["episode_index"])],
			"event_type": CONDITION_FLAG,
			"instance_id": instance_id,
			"episode_index": int(state["episode_index"]),
			"condition_signature": signature,
			"parents": _sorted_strings(attempt.get("material_parent_ids", [])),
		}

	return {
		"ok": true,
		"error": "",
		"growth_allowed": false,
		"condition_flag": CONDITION_FLAG,
		"entry_consequence_fired": starts_new_episode,
		"episode_started": starts_new_episode,
		"episode_index": int(state["episode_index"]),
		"causal_event": causal_event,
		"state": state,
	}

func _normalized_state(runtime_state: Dictionary) -> Dictionary:
	return {
		"active": bool(runtime_state.get("active", false)),
		"episode_index": max(0, int(runtime_state.get("episode_index", 0))),
		"condition_signature": String(runtime_state.get("condition_signature", "")),
	}

func _condition_signature(attempt: Dictionary) -> Dictionary:
	var required_cells_result: Dictionary = _validated_string_array(attempt.get("required_cells", []), "required_cells")
	if not bool(required_cells_result["ok"]):
		return required_cells_result
	var illegal_cells_result: Dictionary = _validated_string_array(attempt.get("illegal_cells", []), "illegal_cells")
	if not bool(illegal_cells_result["ok"]):
		return illegal_cells_result
	var occupied_result: Dictionary = _occupied_signature(attempt.get("occupied_cells", {}))
	if not bool(occupied_result["ok"]):
		return occupied_result

	var signature_parts: PackedStringArray = PackedStringArray([
		"required=%s" % ",".join(required_cells_result["values"]),
		"illegal=%s" % ",".join(illegal_cells_result["values"]),
		"occupied=%s" % ",".join(occupied_result["values"]),
		"orientation=%s" % String(attempt.get("orientation", "")),
		"body=%s" % String(attempt.get("body_condition", "")),
		"trigger=%s" % String(attempt.get("growth_trigger_condition", "")),
		"retry=%s" % String(attempt.get("retry_boundary", "")),
	])
	return {"ok": true, "error": "", "signature": "|".join(signature_parts)}

func _validated_string_array(value: Variant, field_name: String) -> Dictionary:
	if not value is Array and not value is PackedStringArray:
		return {"ok": false, "error": "invalid_%s" % field_name, "values": PackedStringArray()}
	var values: PackedStringArray = PackedStringArray()
	for raw_value: Variant in value:
		var item: String = String(raw_value)
		if item.is_empty():
			return {"ok": false, "error": "invalid_%s" % field_name, "values": PackedStringArray()}
		values.append(item)
	values.sort()
	return {"ok": true, "error": "", "values": values}

func _occupied_signature(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": "invalid_occupied_cells", "values": PackedStringArray()}
	var occupied: Dictionary = value
	var keys: PackedStringArray = PackedStringArray()
	for raw_key: Variant in occupied.keys():
		var key: String = String(raw_key)
		if key.is_empty():
			return {"ok": false, "error": "invalid_occupied_cells", "values": PackedStringArray()}
		keys.append(key)
	keys.sort()
	var values: PackedStringArray = PackedStringArray()
	for key: String in keys:
		values.append("%s=%s" % [key, String(occupied[key])])
	return {"ok": true, "error": "", "values": values}

func _sorted_strings(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not value is Array and not value is PackedStringArray:
		return result
	for raw_value: Variant in value:
		result.append(String(raw_value))
	result.sort()
	return result

func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"growth_allowed": false,
		"condition_flag": "",
		"entry_consequence_fired": false,
		"episode_started": false,
		"episode_index": 0,
		"causal_event": {},
		"state": {},
	}
