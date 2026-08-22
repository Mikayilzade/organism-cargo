class_name S04NestPadKernel
extends RefCounted

const VALID_STATES := ["CALM", "AGITATED", "PANICKED", "ASLEEP"]
const ENTER_SLEEP := "ENTER_SLEEP"
const RECOVER_WAKE := "RECOVER_WAKE"

func resolve_phase_b(
		tick: int,
		organisms: Array,
		supports: Array,
		support_definitions_by_id: Dictionary,
		transition_schedule: Array
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var organism_result: Dictionary = _ordered_organisms(organisms)
	if not bool(organism_result.get("ok", false)):
		return organism_result
	var ordered_organisms: Array = organism_result["organisms"]
	var organism_index_by_id: Dictionary = {}
	for index: int in range(ordered_organisms.size()):
		var organism: Dictionary = ordered_organisms[index]
		organism_index_by_id[String(organism["instance_id"])] = index

	var support_result: Dictionary = _validated_s04_supports(supports, support_definitions_by_id, organism_index_by_id)
	if not bool(support_result.get("ok", false)):
		return support_result
	var s04_by_instance_id: Dictionary = support_result["s04_by_instance_id"]

	var due: Array = []
	for raw_entry: Variant in transition_schedule:
		if not raw_entry is Dictionary:
			return _failure("invalid_s04_transition")
		var entry: Dictionary = raw_entry
		var scheduled_tick: int = int(entry.get("tick", 0))
		if scheduled_tick <= 0:
			return _failure("invalid_s04_transition_tick")
		if scheduled_tick != tick:
			continue
		due.append(entry.duplicate(true))
	due.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_order: int = int(left.get("authored_order", 0))
		var right_order: int = int(right.get("authored_order", 0))
		if left_order != right_order:
			return left_order < right_order
		var left_support: String = String(left.get("support_instance_id", ""))
		var right_support: String = String(right.get("support_instance_id", ""))
		if left_support != right_support:
			return left_support < right_support
		var left_target: String = String(left.get("target_instance_id", ""))
		var right_target: String = String(right.get("target_instance_id", ""))
		if left_target != right_target:
			return left_target < right_target
		return String(left.get("transition", "")) < String(right.get("transition", ""))
	)

	var events: Array = []
	for entry: Dictionary in due:
		var support_instance_id: String = String(entry.get("support_instance_id", ""))
		var target_instance_id: String = String(entry.get("target_instance_id", ""))
		var transition: String = String(entry.get("transition", ""))
		if support_instance_id.is_empty() or not s04_by_instance_id.has(support_instance_id):
			return _failure("unknown_s04_support:%s" % support_instance_id)
		var support: Dictionary = s04_by_instance_id[support_instance_id]
		var linked_target: String = String(support.get("linked_target_instance_id", ""))
		if target_instance_id.is_empty() or target_instance_id != linked_target:
			return _failure("s04_target_mismatch:%s:%s" % [support_instance_id, target_instance_id])
		if not organism_index_by_id.has(target_instance_id):
			return _failure("unknown_s04_target:%s" % target_instance_id)
		if not transition in [ENTER_SLEEP, RECOVER_WAKE]:
			return _failure("invalid_s04_transition_kind:%s" % transition)
		var organism_index: int = int(organism_index_by_id[target_instance_id])
		var current: Dictionary = ordered_organisms[organism_index]
		var state_before: String = String(current.get("primary_state", ""))
		var state_after: String = state_before
		var kind: String = ""
		if transition == ENTER_SLEEP:
			if not bool(current.get("can_sleep", false)):
				return _failure("s04_target_cannot_sleep:%s" % target_instance_id)
			if state_before == "ASLEEP":
				continue
			state_after = "ASLEEP"
			kind = "S04_SLEEP_ENTER_APPLIED"
		else:
			if state_before != "ASLEEP":
				continue
			state_after = "CALM"
			kind = "S04_RECOVER_WAKE_APPLIED"
		var next: Dictionary = current.duplicate(true)
		next["primary_state"] = state_after
		ordered_organisms[organism_index] = next
		var event_id: String = "s04:B:%d:%s:%s:%s" % [tick, support_instance_id, target_instance_id, transition.to_lower()]
		events.append({
			"event_id": event_id,
			"kind": kind,
			"phase": "B",
			"tick": tick,
			"authored_order": int(entry.get("authored_order", 0)),
			"support_instance_id": support_instance_id,
			"target_instance_id": target_instance_id,
			"state_before": state_before,
			"state_after": state_after,
			"parent_event_ids": PackedStringArray(),
		})

	return {
		"ok": true,
		"error": "",
		"organisms": ordered_organisms,
		"events": events,
		"checksum_material": _checksum_material(ordered_organisms, events),
	}

func _validated_s04_supports(supports: Array, support_definitions_by_id: Dictionary, organism_index_by_id: Dictionary) -> Dictionary:
	var s04_by_instance_id: Dictionary = {}
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
		if String(definition.get("family", "")) != "S04":
			continue
		if int(definition.get("capacity", 0)) != 1:
			return _failure("invalid_s04_capacity:%s" % support_id)
		if s04_by_instance_id.has(instance_id):
			return _failure("duplicate_s04_support_instance:%s" % instance_id)
		var linked_target: String = String(support.get("linked_target_instance_id", ""))
		if linked_target.is_empty() or not organism_index_by_id.has(linked_target):
			return _failure("invalid_s04_linked_target:%s" % instance_id)
		s04_by_instance_id[instance_id] = support.duplicate(true)
	return {"ok": true, "error": "", "s04_by_instance_id": s04_by_instance_id}

func _ordered_organisms(organisms: Array) -> Dictionary:
	var ordered: Array = organisms.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))
	)
	var seen: Dictionary = {}
	for raw_organism: Variant in ordered:
		if not raw_organism is Dictionary:
			return _failure("invalid_organism_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		var primary_state: String = String(organism.get("primary_state", ""))
		if instance_id.is_empty() or seen.has(instance_id):
			return _failure("invalid_organism_runtime_identity")
		if not primary_state in VALID_STATES:
			return _failure("invalid_primary_state:%s:%s" % [instance_id, primary_state])
		seen[instance_id] = true
	return {"ok": true, "error": "", "organisms": ordered}

func _checksum_material(organisms: Array, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for organism: Dictionary in organisms:
		parts.append("o:%s:%s" % [String(organism.get("instance_id", "")), String(organism.get("primary_state", ""))])
	for event: Dictionary in events:
		parts.append("e:%s:%s:%s" % [String(event.get("event_id", "")), String(event.get("state_before", "")), String(event.get("state_after", ""))])
	return "|".join(parts)

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error, "organisms": [], "events": [], "checksum_material": ""}
