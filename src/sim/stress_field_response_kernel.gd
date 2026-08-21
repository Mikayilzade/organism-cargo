class_name StressFieldResponseKernel
extends RefCounted

const ThermalResponseKernelScript := preload("res://src/sim/thermal_response_kernel.gd")

func sample_phase_e(tick: int, organisms: Array, stress_field_by_cell: Dictionary) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var ordered_result: Dictionary = _ordered_validated_runtime(organisms)
	if not bool(ordered_result["ok"]):
		return ordered_result
	var ordered: Array = ordered_result["organisms"]
	var observations: Array = []
	var events: Array = []
	for raw_organism: Variant in ordered:
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism["instance_id"])
		var occupied_cells: Array = organism["occupied_cells"]
		var exposure: int = 0
		for raw_cell: Variant in occupied_cells:
			var cell_key: String = String(raw_cell)
			if not stress_field_by_cell.has(cell_key):
				return _failure("organism_cell_missing_from_stress_field:%s:%s" % [instance_id, cell_key])
			exposure = maxi(exposure, int(stress_field_by_cell[cell_key]))
		var event_id: String = "stress-field:E:%d:%s" % [tick, instance_id]
		observations.append({
			"instance_id": instance_id,
			"stress_field_exposure": exposure,
			"event_id": event_id,
		})
		events.append({
			"event_id": event_id,
			"kind": "STRESS_FIELD_EXPOSURE",
			"phase": "E",
			"tick": tick,
			"instance_id": instance_id,
			"stress_field_exposure": exposure,
			"parent_event_ids": PackedStringArray(),
		})
	return {
		"ok": true,
		"error": "",
		"observations": observations,
		"events": events,
	}

func apply_phase_f(tick: int, organisms: Array, observations: Array) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var ordered_result: Dictionary = _ordered_validated_runtime(organisms)
	if not bool(ordered_result["ok"]):
		return ordered_result
	var ordered: Array = ordered_result["organisms"]
	var observations_by_id: Dictionary = {}
	for raw_observation: Variant in observations:
		if not raw_observation is Dictionary:
			return _failure("invalid_stress_field_observation")
		var observation: Dictionary = raw_observation
		var instance_id: String = String(observation.get("instance_id", ""))
		if instance_id.is_empty() or observations_by_id.has(instance_id):
			return _failure("invalid_stress_field_observation_identity")
		var exposure: int = int(observation.get("stress_field_exposure", -1))
		var event_id: String = String(observation.get("event_id", ""))
		if exposure < 0 or event_id.is_empty():
			return _failure("invalid_stress_field_observation:%s" % instance_id)
		observations_by_id[instance_id] = observation

	var results: Array = []
	var events: Array = []
	var phase_f_event_id_by_instance_id: Dictionary = {}
	for raw_organism: Variant in ordered:
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism["instance_id"])
		if not observations_by_id.has(instance_id):
			return _failure("missing_stress_field_observation:%s" % instance_id)
		var observation: Dictionary = observations_by_id[instance_id]
		var profile: Dictionary = organism["stress_profile"]
		var stress_min: int = int(profile["stress_min"])
		var stress_max: int = int(profile["stress_max"])
		var stress_before: int = int(organism["stress"])
		var stress_delta: int = int(observation["stress_field_exposure"])
		var stress_after: int = clampi(stress_before + stress_delta, stress_min, stress_max)
		var next: Dictionary = organism.duplicate(true)
		next["stress"] = stress_after
		results.append(next)
		var event_id: String = "stress-field:F:%d:%s" % [tick, instance_id]
		phase_f_event_id_by_instance_id[instance_id] = event_id
		events.append({
			"event_id": event_id,
			"kind": "STRESS_FIELD_INTERNAL_STRESS",
			"phase": "F",
			"tick": tick,
			"instance_id": instance_id,
			"stress_field_exposure": stress_delta,
			"stress_delta": stress_delta,
			"stress_before": stress_before,
			"stress_after": stress_after,
			"parent_event_ids": PackedStringArray([String(observation["event_id"])]),
		})
	if observations_by_id.size() != results.size():
		return _failure("unknown_stress_field_observation")
	return {
		"ok": true,
		"error": "",
		"organisms": results,
		"events": events,
		"phase_f_event_id_by_instance_id": phase_f_event_id_by_instance_id,
	}

func evaluate_phase_g(
		tick: int,
		organisms: Array,
		phase_f_event_id_by_instance_id: Dictionary
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var ordered_result: Dictionary = _ordered_validated_runtime(organisms)
	if not bool(ordered_result["ok"]):
		return ordered_result
	var ordered: Array = ordered_result["organisms"]
	var thermal_kernel: ThermalResponseKernel = ThermalResponseKernelScript.new()
	var results: Array = []
	var events: Array = []
	for raw_organism: Variant in ordered:
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism["instance_id"])
		if not phase_f_event_id_by_instance_id.has(instance_id):
			return _failure("missing_phase_f_stress_event:%s" % instance_id)
		var previous_state: String = String(organism["primary_state"])
		var profile: Dictionary = organism["stress_profile"]
		var next_state_result: Dictionary = thermal_kernel._next_primary_state(previous_state, int(organism["stress"]), profile)
		if not bool(next_state_result.get("ok", false)):
			return _failure("stress_hysteresis:%s" % String(next_state_result.get("error", "unknown")))
		var next_state: String = String(next_state_result["state"])
		var next: Dictionary = organism.duplicate(true)
		next["primary_state"] = next_state
		results.append(next)
		if next_state != previous_state:
			events.append({
				"event_id": "stress-field:G:%d:%s" % [tick, instance_id],
				"kind": "STRESS_STATE_TRANSITION",
				"phase": "G",
				"tick": tick,
				"instance_id": instance_id,
				"stress": int(organism["stress"]),
				"state_before": previous_state,
				"state_after": next_state,
				"parent_event_ids": PackedStringArray([String(phase_f_event_id_by_instance_id[instance_id])]),
			})
	return {
		"ok": true,
		"error": "",
		"organisms": results,
		"events": events,
	}

func _ordered_validated_runtime(organisms: Array) -> Dictionary:
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
		var occupied_value: Variant = organism.get("occupied_cells", null)
		if not occupied_value is Array:
			return _failure("invalid_occupied_cells:%s" % instance_id)
		var occupied_cells: Array = occupied_value
		if occupied_cells.is_empty():
			return _failure("invalid_occupied_cells:%s" % instance_id)
		var profile_value: Variant = organism.get("stress_profile", null)
		if not profile_value is Dictionary:
			return _failure("missing_stress_profile:%s" % instance_id)
		var profile: Dictionary = profile_value
		for key: String in PackedStringArray([
			"stress_min", "stress_max",
			"agitated_enter", "agitated_exit",
			"panic_enter", "panic_exit"
		]):
			if not profile.has(key):
				return _failure("missing_stress_profile_field:%s:%s" % [instance_id, key])
		var stress_min: int = int(profile["stress_min"])
		var stress_max: int = int(profile["stress_max"])
		var agitated_enter: int = int(profile["agitated_enter"])
		var agitated_exit: int = int(profile["agitated_exit"])
		var panic_enter: int = int(profile["panic_enter"])
		var panic_exit: int = int(profile["panic_exit"])
		if stress_min > stress_max:
			return _failure("invalid_stress_profile:%s" % instance_id)
		if not (panic_enter > panic_exit and panic_exit >= agitated_enter and agitated_enter > agitated_exit and agitated_exit >= stress_min):
			return _failure("invalid_stress_hysteresis:%s" % instance_id)
		if panic_enter > stress_max:
			return _failure("panic_threshold_out_of_range:%s" % instance_id)
		var primary_state: String = String(organism.get("primary_state", ""))
		if not primary_state in ["CALM", "AGITATED", "PANICKED"]:
			return _failure("stress_field_primary_state_not_implemented:%s" % primary_state)
		var stress: int = int(organism.get("stress", stress_min - 1))
		if stress < stress_min or stress > stress_max:
			return _failure("stress_out_of_range:%s" % instance_id)
	return {"ok": true, "error": "", "organisms": ordered}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
