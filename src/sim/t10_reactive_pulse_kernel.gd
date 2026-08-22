class_name T10ReactivePulseKernel
extends RefCounted

const GUARD_ONCE_PER_RUN := "once_per_run"
const GUARD_ONCE_PER_EPISODE := "once_per_episode"
const GUARD_MAX_TRIGGERS := "max_triggers_per_run"
const ALLOWED_GUARDS := [GUARD_ONCE_PER_RUN, GUARD_ONCE_PER_EPISODE, GUARD_MAX_TRIGGERS]

func validate_definitions(definitions: Array) -> Dictionary:
	var ordered: Array = definitions.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _definition_key(left) < _definition_key(right)
	)
	var seen: Dictionary = {}
	for raw_definition: Variant in ordered:
		if not raw_definition is Dictionary:
			return _failure("invalid_t10_definition")
		var definition: Dictionary = raw_definition
		var source_instance_id: String = String(definition.get("source_instance_id", ""))
		var trait_id: String = String(definition.get("trait_id", ""))
		var trigger_event_kind: String = String(definition.get("trigger_event_kind", ""))
		var guard: String = String(definition.get("trigger_guard", ""))
		if source_instance_id.is_empty() or trait_id.is_empty() or trigger_event_kind.is_empty():
			return _failure("invalid_t10_identity")
		var key: String = _definition_key(definition)
		if seen.has(key):
			return _failure("duplicate_t10_definition:%s" % key)
		seen[key] = true
		if not guard in ALLOWED_GUARDS:
			return _failure("invalid_t10_trigger_guard:%s" % key)
		if guard == GUARD_MAX_TRIGGERS and int(definition.get("max_triggers_per_run", 0)) <= 0:
			return _failure("invalid_t10_max_triggers:%s" % key)
		var effects_value: Variant = definition.get("effects", null)
		if not effects_value is Array:
			return _failure("invalid_t10_effects:%s" % key)
		var effects: Array = effects_value
		if effects.is_empty():
			return _failure("empty_t10_effects:%s" % key)
		for raw_effect: Variant in effects:
			if not raw_effect is Dictionary:
				return _failure("invalid_t10_effect:%s" % key)
			var effect: Dictionary = raw_effect
			var effect_kind: String = String(effect.get("kind", ""))
			if effect_kind.is_empty():
				return _failure("invalid_t10_effect_kind:%s" % key)
			var target_instance_id: String = String(effect.get("target_instance_id", source_instance_id))
			if target_instance_id == source_instance_id and effect_kind == trigger_event_kind:
				return _failure("recursive_same_tick_t10_trigger:%s" % key)
	return {"ok": true, "error": "", "definitions": ordered}

func resolve_phase_h(
		tick: int,
		trigger_events: Array,
		definitions: Array,
		runtime_state: Dictionary = {}
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var validation: Dictionary = validate_definitions(definitions)
	if not bool(validation.get("ok", false)):
		return validation
	var ordered_definitions: Array = validation["definitions"]
	var ordered_triggers_result: Dictionary = _ordered_trigger_events(trigger_events)
	if not bool(ordered_triggers_result.get("ok", false)):
		return ordered_triggers_result
	var ordered_triggers: Array = ordered_triggers_result["events"]
	var state: Dictionary = _normalized_state(runtime_state)
	var count_by_key: Dictionary = state["trigger_count_by_key"]
	var fired_episode_keys: Dictionary = state["fired_episode_keys"]
	var pulse_events: Array = []
	var effect_records: Array = []

	for raw_trigger: Variant in ordered_triggers:
		var trigger: Dictionary = raw_trigger
		var trigger_kind: String = String(trigger["kind"])
		var trigger_instance_id: String = String(trigger["instance_id"])
		for raw_definition: Variant in ordered_definitions:
			var definition: Dictionary = raw_definition
			if String(definition["source_instance_id"]) != trigger_instance_id:
				continue
			if String(definition["trigger_event_kind"]) != trigger_kind:
				continue
			var key: String = _definition_key(definition)
			var guard: String = String(definition["trigger_guard"])
			var count: int = int(count_by_key.get(key, 0))
			if guard == GUARD_ONCE_PER_RUN and count >= 1:
				continue
			if guard == GUARD_MAX_TRIGGERS and count >= int(definition["max_triggers_per_run"]):
				continue
			var episode_key: String = ""
			if guard == GUARD_ONCE_PER_EPISODE:
				var episode_id: String = String(trigger.get("episode_id", ""))
				if episode_id.is_empty():
					return _failure("missing_t10_episode_id:%s" % key)
				episode_key = "%s|%s" % [key, episode_id]
				if fired_episode_keys.has(episode_key):
					continue

			var next_count: int = count + 1
			var pulse_event_id: String = "T10:H:%d:%s:%s:%d" % [
				tick,
				String(definition["source_instance_id"]),
				String(definition["trait_id"]),
				next_count,
			]
			var pulse_event: Dictionary = {
				"event_id": pulse_event_id,
				"kind": "T10_REACTIVE_PULSE",
				"phase": "H",
				"tick": tick,
				"instance_id": String(definition["source_instance_id"]),
				"trait_id": String(definition["trait_id"]),
				"trigger_guard": guard,
				"trigger_count": next_count,
				"trigger_event_kind": trigger_kind,
				"parent_event_ids": PackedStringArray([String(trigger["event_id"])]),
			}
			if not episode_key.is_empty():
				pulse_event["episode_id"] = String(trigger["episode_id"])
			pulse_events.append(pulse_event)
			count_by_key[key] = next_count
			if not episode_key.is_empty():
				fired_episode_keys[episode_key] = true

			var effects: Array = definition["effects"]
			for effect_index: int in range(effects.size()):
				var raw_effect: Variant = effects[effect_index]
				var effect: Dictionary = (raw_effect as Dictionary).duplicate(true)
				effect["event_id"] = "T10:effect:%d:%s:%s:%d:%d" % [
					tick,
					String(definition["source_instance_id"]),
					String(definition["trait_id"]),
					next_count,
					effect_index,
				]
				effect["phase"] = "H"
				effect["tick"] = tick
				effect["source_instance_id"] = String(definition["source_instance_id"])
				effect["trait_id"] = String(definition["trait_id"])
				effect["parent_event_ids"] = PackedStringArray([pulse_event_id])
				effect_records.append(effect)

	state["trigger_count_by_key"] = count_by_key
	state["fired_episode_keys"] = fired_episode_keys
	var authority_payload: String = _serialize_authority(state, pulse_events, effect_records)
	return {
		"ok": true,
		"error": "",
		"state": state,
		"events": pulse_events,
		"effects": effect_records,
		"authority_payload": authority_payload,
		"authority_checksum": authority_payload.sha256_text(),
	}

func _ordered_trigger_events(trigger_events: Array) -> Dictionary:
	var ordered: Array = trigger_events.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("event_id", "")) < String(right.get("event_id", ""))
	)
	var seen: Dictionary = {}
	for raw_event: Variant in ordered:
		if not raw_event is Dictionary:
			return _failure("invalid_t10_trigger_event")
		var event: Dictionary = raw_event
		var event_id: String = String(event.get("event_id", ""))
		var kind: String = String(event.get("kind", ""))
		var instance_id: String = String(event.get("instance_id", ""))
		if event_id.is_empty() or kind.is_empty() or instance_id.is_empty() or seen.has(event_id):
			return _failure("invalid_t10_trigger_event_identity")
		seen[event_id] = true
	return {"ok": true, "error": "", "events": ordered}

func _normalized_state(runtime_state: Dictionary) -> Dictionary:
	var state: Dictionary = runtime_state.duplicate(true)
	var counts_value: Variant = state.get("trigger_count_by_key", {})
	var episodes_value: Variant = state.get("fired_episode_keys", {})
	state["trigger_count_by_key"] = (counts_value as Dictionary).duplicate(true) if counts_value is Dictionary else {}
	state["fired_episode_keys"] = (episodes_value as Dictionary).duplicate(true) if episodes_value is Dictionary else {}
	return state

func _definition_key(definition: Dictionary) -> String:
	return "%s|%s" % [String(definition.get("source_instance_id", "")), String(definition.get("trait_id", ""))]

func _serialize_authority(state: Dictionary, events: Array, effects: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var counts: Dictionary = state.get("trigger_count_by_key", {})
	var count_keys: Array = counts.keys()
	count_keys.sort()
	for raw_key: Variant in count_keys:
		var key: String = String(raw_key)
		parts.append("count:%s:%d" % [key, int(counts[key])])
	var episodes: Dictionary = state.get("fired_episode_keys", {})
	var episode_keys: Array = episodes.keys()
	episode_keys.sort()
	for raw_key: Variant in episode_keys:
		parts.append("episode:%s" % String(raw_key))
	for raw_event: Variant in events:
		var event: Dictionary = raw_event
		parts.append("event:%s:%s:%d" % [String(event["event_id"]), String(event["trait_id"]), int(event["trigger_count"])])
	for raw_effect: Variant in effects:
		var effect: Dictionary = raw_effect
		parts.append("effect:%s:%s" % [String(effect["event_id"]), String(effect["kind"])])
	return ";".join(parts)

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
