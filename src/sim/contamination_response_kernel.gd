class_name ContaminationResponseKernel
extends RefCounted

const FixedMathScript := preload("res://src/sim/fixed_math.gd")

func prepare_runtime(organisms: Array, organism_definitions: Dictionary) -> Dictionary:
	var ordered: Array = organisms.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))
	)
	var prepared: Array = []
	for raw_organism: Variant in ordered:
		if not raw_organism is Dictionary:
			return _failure("invalid_organism_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty():
			return _failure("missing_organism_instance_id")
		if not organism_definitions.has(instance_id) or not organism_definitions[instance_id] is Dictionary:
			return _failure("missing_organism_definition:%s" % instance_id)
		var definition: Dictionary = organism_definitions[instance_id]
		var profile_value: Variant = definition.get("contamination_profile", null)
		if not profile_value is Dictionary:
			return _failure("missing_contamination_profile:%s" % instance_id)
		var profile: Dictionary = profile_value
		var profile_error: String = _validate_profile(profile, instance_id)
		if not profile_error.is_empty():
			return _failure(profile_error)
		var load_min: int = int(profile["load_min"])
		var load_max: int = int(profile["load_max"])
		var initial_load: int = int(definition.get("initial_contamination_load", load_min))
		if initial_load < load_min or initial_load > load_max:
			return _failure("initial_contamination_load_out_of_range:%s" % instance_id)
		var next_organism: Dictionary = organism.duplicate(true)
		next_organism["contamination_profile"] = profile.duplicate(true)
		next_organism["contamination_load"] = initial_load
		next_organism["contaminated"] = bool(definition.get("initial_contaminated", false))
		prepared.append(next_organism)
	return {"ok": true, "error": "", "organisms": prepared}

func sample_phase_e(tick: int, organisms: Array, contamination_by_cell: Dictionary) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var ordered_result: Dictionary = _ordered_runtime(organisms)
	if not bool(ordered_result["ok"]):
		return ordered_result
	var ordered: Array = ordered_result["organisms"]
	var observations: Array = []
	var events: Array = []
	for raw_organism: Variant in ordered:
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism["instance_id"])
		var occupied_value: Variant = organism.get("occupied_cells", [])
		if not (occupied_value is Array or occupied_value is PackedStringArray):
			return _failure("invalid_occupied_cells:%s" % instance_id)
		var occupied_cells: PackedStringArray = PackedStringArray()
		for raw_cell: Variant in occupied_value:
			var cell_key: String = String(raw_cell)
			if not contamination_by_cell.has(cell_key):
				return _failure("organism_cell_missing_from_contamination:%s:%s" % [instance_id, cell_key])
			occupied_cells.append(cell_key)
		if occupied_cells.is_empty():
			return _failure("invalid_occupied_cells:%s" % instance_id)
		occupied_cells.sort()
		var exposure: int = 0
		for cell_key: String in occupied_cells:
			exposure = maxi(exposure, int(contamination_by_cell[cell_key]))
		var event_id: String = "%d:E:contamination:%s" % [tick, instance_id]
		observations.append({
			"instance_id": instance_id,
			"contamination_exposure": exposure,
			"event_id": event_id,
		})
		events.append({
			"event_id": event_id,
			"phase": "E",
			"kind": "CONTAMINATION_EXPOSURE_SAMPLED",
			"instance_id": instance_id,
			"sampled_cells": Array(occupied_cells),
			"contamination_exposure": exposure,
			"parent_event_ids": PackedStringArray(),
		})
	return {"ok": true, "error": "", "observations": observations, "events": events}

func apply_phase_f(tick: int, organisms: Array, observations: Array) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var ordered_result: Dictionary = _ordered_runtime(organisms)
	if not bool(ordered_result["ok"]):
		return ordered_result
	var observations_by_id: Dictionary = {}
	for raw_observation: Variant in observations:
		if not raw_observation is Dictionary:
			return _failure("invalid_contamination_observation")
		var observation: Dictionary = raw_observation
		var instance_id: String = String(observation.get("instance_id", ""))
		if instance_id.is_empty() or observations_by_id.has(instance_id):
			return _failure("invalid_contamination_observation")
		observations_by_id[instance_id] = observation

	var results: Array = []
	var events: Array = []
	var ordered: Array = ordered_result["organisms"]
	for raw_organism: Variant in ordered:
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism["instance_id"])
		if not observations_by_id.has(instance_id):
			return _failure("missing_contamination_observation:%s" % instance_id)
		var profile_value: Variant = organism.get("contamination_profile", null)
		if not profile_value is Dictionary:
			return _failure("missing_contamination_profile:%s" % instance_id)
		var profile: Dictionary = profile_value
		var profile_error: String = _validate_profile(profile, instance_id)
		if not profile_error.is_empty():
			return _failure(profile_error)
		var observation: Dictionary = observations_by_id[instance_id]
		var exposure: int = int(observation.get("contamination_exposure", -1))
		if exposure < 0:
			return _failure("invalid_contamination_exposure:%s" % instance_id)
		var intake_multiplier_scaled: int = int(profile["intake_multiplier_scaled"])
		var intake: int = FixedMathScript.mul_non_negative(exposure, intake_multiplier_scaled)
		var previous_load: int = int(organism.get("contamination_load", int(profile["load_min"])))
		var next_load: int = clampi(
			previous_load + intake,
			int(profile["load_min"]),
			int(profile["load_max"])
		)
		var next_organism: Dictionary = organism.duplicate(true)
		next_organism["contamination_load"] = next_load
		results.append(next_organism)
		var event_id: String = "%d:F:contamination:%s" % [tick, instance_id]
		events.append({
			"event_id": event_id,
			"phase": "F",
			"kind": "CONTAMINATION_LOAD_INTAKE",
			"instance_id": instance_id,
			"contamination_exposure": exposure,
			"intake_multiplier_scaled": intake_multiplier_scaled,
			"contamination_intake": intake,
			"contamination_before": previous_load,
			"contamination_after": next_load,
			"parent_event_ids": PackedStringArray([String(observation.get("event_id", ""))]),
		})
	if observations_by_id.size() != results.size():
		return _failure("extra_contamination_observation")
	return {"ok": true, "error": "", "organisms": results, "events": events}

func evaluate_phase_g(tick: int, organisms: Array) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var ordered_result: Dictionary = _ordered_runtime(organisms)
	if not bool(ordered_result["ok"]):
		return ordered_result
	var results: Array = []
	var events: Array = []
	var ordered: Array = ordered_result["organisms"]
	for raw_organism: Variant in ordered:
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism["instance_id"])
		var profile_value: Variant = organism.get("contamination_profile", null)
		if not profile_value is Dictionary:
			return _failure("missing_contamination_profile:%s" % instance_id)
		var profile: Dictionary = profile_value
		var profile_error: String = _validate_profile(profile, instance_id)
		if not profile_error.is_empty():
			return _failure(profile_error)
		var load: int = int(organism.get("contamination_load", int(profile["load_min"])))
		var previous_contaminated: bool = bool(organism.get("contaminated", false))
		var next_contaminated: bool = false
		if previous_contaminated:
			next_contaminated = load >= int(profile["contaminated_exit"])
		else:
			next_contaminated = load >= int(profile["contaminated_enter"])
		var next_organism: Dictionary = organism.duplicate(true)
		next_organism["contaminated"] = next_contaminated
		results.append(next_organism)
		if previous_contaminated != next_contaminated:
			var kind: String = "CONTAMINATED_ENTER" if next_contaminated else "CONTAMINATED_EXIT"
			events.append({
				"event_id": "%d:G:contamination:%s" % [tick, instance_id],
				"phase": "G",
				"kind": kind,
				"instance_id": instance_id,
				"contamination_load": load,
				"contaminated_enter": int(profile["contaminated_enter"]),
				"contaminated_exit": int(profile["contaminated_exit"]),
				"parent_event_ids": PackedStringArray(["%d:F:contamination:%s" % [tick, instance_id]]),
			})
	return {"ok": true, "error": "", "organisms": results, "events": events}

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
	return {"ok": true, "error": "", "organisms": ordered}

func _validate_profile(profile: Dictionary, instance_id: String) -> String:
	for key: String in PackedStringArray([
		"intake_multiplier_scaled",
		"load_min",
		"load_max",
		"contaminated_enter",
		"contaminated_exit",
	]):
		if not profile.has(key):
			return "missing_contamination_profile_field:%s:%s" % [instance_id, key]
	var intake_multiplier_scaled: int = int(profile["intake_multiplier_scaled"])
	var load_min: int = int(profile["load_min"])
	var load_max: int = int(profile["load_max"])
	var contaminated_enter: int = int(profile["contaminated_enter"])
	var contaminated_exit: int = int(profile["contaminated_exit"])
	if intake_multiplier_scaled < 0 or load_min < 0 or load_min > load_max:
		return "invalid_contamination_profile:%s" % instance_id
	if not (contaminated_enter > contaminated_exit and contaminated_exit >= load_min):
		return "invalid_contamination_hysteresis:%s" % instance_id
	if contaminated_enter > load_max:
		return "contamination_threshold_out_of_range:%s" % instance_id
	return ""

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}