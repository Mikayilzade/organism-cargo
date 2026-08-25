class_name SleepWakeKernel
extends RefCounted

func resolve_phase_b(
		tick: int,
		organisms: Array,
		active_hazard_ids: PackedStringArray,
		hazards_by_id: Dictionary
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var ordered_result: Dictionary = _ordered_runtime(organisms)
	if not bool(ordered_result.get("ok", false)):
		return ordered_result
	var ordered: Array = ordered_result["organisms"]
	var index_by_id: Dictionary = {}
	for index: int in range(ordered.size()):
		var organism: Dictionary = ordered[index]
		index_by_id[String(organism["instance_id"])] = index

	# Active hazards are an authoritative same-tick set. Normalize processing order so
	# simultaneous H02 wake requests cannot make causal ownership depend on caller order.
	var ordered_hazard_ids: PackedStringArray = active_hazard_ids.duplicate()
	ordered_hazard_ids.sort()

	var events: Array = []
	var wake_event_id_by_instance_id: Dictionary = {}
	for hazard_id: String in ordered_hazard_ids:
		if not hazards_by_id.has(hazard_id) or not hazards_by_id[hazard_id] is Dictionary:
			return _failure("missing_active_hazard:%s" % hazard_id)
		var hazard: Dictionary = hazards_by_id[hazard_id]
		if String(hazard.get("family", "")) != "H02":
			continue
		if not bool(hazard.get("wake_request", false)):
			continue
		var targets_value: Variant = hazard.get("wake_target_instance_ids", null)
		if not (targets_value is Array or targets_value is PackedStringArray):
			return _failure("invalid_h02_wake_targets:%s" % hazard_id)
		var targets: PackedStringArray = PackedStringArray()
		for raw_target: Variant in targets_value:
			var target_id: String = String(raw_target)
			if target_id.is_empty():
				return _failure("invalid_h02_wake_target:%s" % hazard_id)
			targets.append(target_id)
		targets.sort()
		var previous_target: String = ""
		for instance_id: String in targets:
			if instance_id == previous_target:
				return _failure("duplicate_h02_wake_target:%s:%s" % [hazard_id, instance_id])
			previous_target = instance_id
			if not index_by_id.has(instance_id):
				return _failure("unknown_h02_wake_target:%s:%s" % [hazard_id, instance_id])
			var organism_index: int = int(index_by_id[instance_id])
			var organism: Dictionary = ordered[organism_index]
			if String(organism.get("primary_state", "")) != "ASLEEP":
				continue
			var next: Dictionary = organism.duplicate(true)
			next["primary_state"] = "CALM"
			ordered[organism_index] = next
			var event_id: String = "sleep-wake:B:%d:%s:%s" % [tick, hazard_id, instance_id]
			wake_event_id_by_instance_id[instance_id] = event_id
			events.append({
				"event_id": event_id,
				"kind": "H02_WAKE_REQUEST_APPLIED",
				"phase": "B",
				"tick": tick,
				"hazard_id": hazard_id,
				"instance_id": instance_id,
				"state_before": "ASLEEP",
				"state_after": "CALM",
				"parent_event_ids": PackedStringArray(["route:A:%d:%s" % [tick, hazard_id]]),
			})

	return {
		"ok": true,
		"error": "",
		"organisms": ordered,
		"events": events,
		"wake_event_id_by_instance_id": wake_event_id_by_instance_id,
	}

func sleep_gate_allows(primary_state: String, sleep_gated: bool) -> bool:
	if not primary_state in ["CALM", "AGITATED", "PANICKED", "ASLEEP"]:
		return false
	return not sleep_gated or primary_state != "ASLEEP"

func _ordered_runtime(organisms: Array) -> Dictionary:
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
		if instance_id.is_empty() or seen.has(instance_id):
			return _failure("invalid_organism_runtime_identity")
		seen[instance_id] = true
		var primary_state: String = String(organism.get("primary_state", ""))
		if not primary_state in ["CALM", "AGITATED", "PANICKED", "ASLEEP"]:
			return _failure("invalid_primary_state:%s:%s" % [instance_id, primary_state])
	return {"ok": true, "error": "", "organisms": ordered}

func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"organisms": [],
		"events": [],
		"wake_event_id_by_instance_id": {},
	}
