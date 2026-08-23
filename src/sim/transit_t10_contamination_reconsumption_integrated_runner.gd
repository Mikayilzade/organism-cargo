extends "res://src/sim/transit_t10_environment_reconsumption_integrated_runner.gd"

func integrate_effects(base_result: Dictionary, simulation_defs: Dictionary = {}) -> Dictionary:
	var integrated: Dictionary = super.integrate_effects(base_result, simulation_defs)
	if not bool(integrated.get("ok", false)):
		return integrated
	return _reconsume_contamination_carry(integrated, simulation_defs)

func _reconsume_contamination_carry(result: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var snapshots_value: Variant = result.get("end_tick_snapshots", [])
	var checksums_value: Variant = result.get("tick_checksums", PackedStringArray())
	if not snapshots_value is Array:
		return _failure("invalid_t10_contamination_reconsumption_snapshots")
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return _failure("invalid_t10_contamination_reconsumption_checksums")
	var snapshots: Array = snapshots_value as Array
	var checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in checksums_value:
		checksums.append(String(raw_checksum))
	if checksums.size() != snapshots.size():
		return _failure("t10_contamination_reconsumption_checksum_count_mismatch")

	var rewritten_snapshots: Array = []
	var rewritten_checksums: PackedStringArray = PackedStringArray()
	var all_events: Array = []
	var previous_application_events: Array = []
	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return _failure("invalid_t10_contamination_reconsumption_snapshot")
		var snapshot: Dictionary = (raw_snapshot as Dictionary).duplicate(true)
		var tick_events: Array = []
		var contamination_applications: Array = _contamination_application_events(previous_application_events)
		if not contamination_applications.is_empty():
			var reconsumed: Dictionary = _reconsume_contamination_tick(snapshot, contamination_applications, simulation_defs)
			if not bool(reconsumed.get("ok", false)):
				return reconsumed
			snapshot = reconsumed["snapshot"] as Dictionary
			tick_events = reconsumed["events"] as Array
			for raw_event: Variant in tick_events:
				if raw_event is Dictionary:
					all_events.append((raw_event as Dictionary).duplicate(true))
		snapshot["t10_contamination_reconsumption_events"] = tick_events.duplicate(true)
		rewritten_snapshots.append(snapshot)
		var checksum_material: String = "%s|t10_contamination_reconsume=%s" % [
			String(checksums[index]),
			_serialize_contamination_reconsumption_events(tick_events),
		]
		rewritten_checksums.append(checksum_material.sha256_text())
		var application_value: Variant = snapshot.get("t10_effect_application_events", [])
		if not application_value is Array:
			return _failure("invalid_t10_effect_application_events")
		previous_application_events = (application_value as Array).duplicate(true)

	var next_result: Dictionary = result.duplicate(true)
	next_result["end_tick_snapshots"] = rewritten_snapshots
	next_result["tick_checksums"] = rewritten_checksums
	next_result["t10_contamination_reconsumption_events"] = all_events
	var aggregate_response_events: Array = []
	for raw_snapshot: Variant in rewritten_snapshots:
		if raw_snapshot is Dictionary:
			var response_value: Variant = (raw_snapshot as Dictionary).get("contamination_response_events", [])
			if response_value is Array:
				for raw_event: Variant in response_value:
					if raw_event is Dictionary:
						aggregate_response_events.append((raw_event as Dictionary).duplicate(true))
	next_result["contamination_response_events"] = aggregate_response_events
	if not rewritten_snapshots.is_empty():
		var final_snapshot: Dictionary = rewritten_snapshots[rewritten_snapshots.size() - 1] as Dictionary
		var final_runtime_value: Variant = final_snapshot.get("organism_runtime", [])
		if final_runtime_value is Array:
			next_result["final_organism_runtime"] = (final_runtime_value as Array).duplicate(true)
	return next_result

func _reconsume_contamination_tick(snapshot: Dictionary, application_events: Array, simulation_defs: Dictionary) -> Dictionary:
	var tick: int = int(snapshot.get("tick", 0))
	if tick <= 0:
		return _failure("invalid_t10_contamination_reconsumption_tick")
	var phase_d_value: Variant = snapshot.get("phase_d_contamination_exposure_by_cell", null)
	var runtime_value: Variant = snapshot.get("organism_runtime", null)
	var response_value: Variant = snapshot.get("contamination_response_events", null)
	if not phase_d_value is Dictionary or not runtime_value is Array or not response_value is Array:
		return _failure("missing_t10_contamination_reconsumption_authority")
	var rules_value: Variant = simulation_defs.get("contamination_rules", null)
	if not rules_value is Dictionary:
		return _failure("missing_t10_contamination_rules")
	var rules: Dictionary = rules_value
	var field: Dictionary = (phase_d_value as Dictionary).duplicate(true)
	for raw_application: Variant in application_events:
		if not raw_application is Dictionary:
			return _failure("invalid_t10_contamination_application_event")
		var application: Dictionary = raw_application
		var cell_key: String = String(application.get("cell_key", ""))
		if cell_key.is_empty() or not field.has(cell_key):
			continue
		field[cell_key] = clampi(
			int(field[cell_key]) + int(application.get("applied_delta", 0)),
			int(rules.get("contamination_min", 0)),
			int(rules.get("contamination_max", 0))
		)

	var pre_result: Dictionary = _reconstruct_pre_contamination_runtime(runtime_value as Array, response_value as Array)
	if not bool(pre_result.get("ok", false)):
		return pre_result
	var pre_runtime: Array = pre_result["organisms"] as Array
	var modifiers_value: Variant = snapshot.get("t09_intake_multiplier_scaled_by_target_id", {})
	if not modifiers_value is Dictionary:
		return _failure("invalid_t10_contamination_t09_modifiers")
	var modified_result: Dictionary = _runtime_with_t09_intake_modifiers(pre_runtime, modifiers_value as Dictionary)
	if not bool(modified_result.get("ok", false)):
		return modified_result
	var phase_f_input: Array = modified_result["organisms"] as Array

	var sampled: Dictionary = ContaminationResponseKernelScript.new().sample_phase_e(tick, phase_f_input, field)
	if not bool(sampled.get("ok", false)):
		return _failure("phase_e_t10_contamination:%s" % String(sampled.get("error", "unknown")))
	var sample_events_value: Variant = sampled.get("events", [])
	var observations_value: Variant = sampled.get("observations", [])
	if not sample_events_value is Array or not observations_value is Array:
		return _failure("invalid_t10_contamination_phase_e")
	var sample_events: Array = sample_events_value as Array
	var ancestry: Dictionary = _attach_contamination_ancestry(sample_events, phase_f_input, application_events)
	if not bool(ancestry.get("ok", false)):
		return ancestry
	sample_events = ancestry["events"] as Array

	var phase_f: Dictionary = ContaminationResponseKernelScript.new().apply_phase_f(tick, phase_f_input, observations_value as Array)
	if not bool(phase_f.get("ok", false)):
		return _failure("phase_f_t10_contamination:%s" % String(phase_f.get("error", "unknown")))
	var restored: Dictionary = _restore_contamination_profiles(phase_f.get("organisms", []), pre_runtime)
	if not bool(restored.get("ok", false)):
		return restored
	var phase_g: Dictionary = ContaminationResponseKernelScript.new().evaluate_phase_g(tick, restored["organisms"] as Array)
	if not bool(phase_g.get("ok", false)):
		return _failure("phase_g_t10_contamination:%s" % String(phase_g.get("error", "unknown")))

	var phase_f_events_value: Variant = phase_f.get("events", [])
	var phase_g_events_value: Variant = phase_g.get("events", [])
	if not phase_f_events_value is Array or not phase_g_events_value is Array:
		return _failure("invalid_t10_contamination_response_events")
	var replacement_events: Array = []
	for batch: Variant in [sample_events, phase_f_events_value as Array, phase_g_events_value as Array]:
		for raw_event: Variant in batch as Array:
			if raw_event is Dictionary:
				replacement_events.append((raw_event as Dictionary).duplicate(true))

	var next_snapshot: Dictionary = snapshot.duplicate(true)
	next_snapshot["phase_d_contamination_exposure_by_cell"] = field
	next_snapshot["organism_runtime"] = (phase_g["organisms"] as Array).duplicate(true)
	next_snapshot["contamination_response_events"] = replacement_events.duplicate(true)
	return {"ok": true, "error": "", "snapshot": next_snapshot, "events": replacement_events}

func _reconstruct_pre_contamination_runtime(runtime: Array, response_events: Array) -> Dictionary:
	var before_by_id: Dictionary = {}
	var contaminated_before_by_id: Dictionary = {}
	for raw_event: Variant in response_events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var instance_id: String = String(event.get("instance_id", ""))
		if String(event.get("kind", "")) == "CONTAMINATION_LOAD_INTAKE":
			before_by_id[instance_id] = int(event.get("contamination_before", 0))
		elif String(event.get("kind", "")) == "CONTAMINATED_ENTER":
			contaminated_before_by_id[instance_id] = false
		elif String(event.get("kind", "")) == "CONTAMINATED_EXIT":
			contaminated_before_by_id[instance_id] = true
	var reconstructed: Array = runtime.duplicate(true)
	for index: int in range(reconstructed.size()):
		var raw_runtime: Variant = reconstructed[index]
		if not raw_runtime is Dictionary:
			return _failure("invalid_t10_contamination_runtime")
		var organism: Dictionary = (raw_runtime as Dictionary).duplicate(true)
		var instance_id: String = String(organism.get("instance_id", ""))
		if not before_by_id.has(instance_id):
			return _failure("missing_t10_pre_contamination_authority:%s" % instance_id)
		organism["contamination_load"] = int(before_by_id[instance_id])
		if contaminated_before_by_id.has(instance_id):
			organism["contaminated"] = bool(contaminated_before_by_id[instance_id])
		reconstructed[index] = organism
	return {"ok": true, "error": "", "organisms": reconstructed}

func _attach_contamination_ancestry(sample_events: Array, runtime: Array, application_events: Array) -> Dictionary:
	var parents_by_cell: Dictionary = _application_parents_by_cell(application_events, "CONTAMINATION_PULSE")
	var runtime_by_id: Dictionary = {}
	for raw_runtime: Variant in runtime:
		if raw_runtime is Dictionary:
			var organism: Dictionary = raw_runtime
			runtime_by_id[String(organism.get("instance_id", ""))] = organism
	var rewritten: Array = []
	for raw_event: Variant in sample_events:
		if not raw_event is Dictionary:
			return _failure("invalid_t10_contamination_sample_event")
		var event: Dictionary = (raw_event as Dictionary).duplicate(true)
		var parent_ids: PackedStringArray = PackedStringArray()
		var instance_id: String = String(event.get("instance_id", ""))
		if runtime_by_id.has(instance_id):
			var organism: Dictionary = runtime_by_id[instance_id]
			var cells_value: Variant = organism.get("occupied_cells", [])
			if cells_value is Array or cells_value is PackedStringArray:
				for raw_cell: Variant in cells_value:
					var cell_parents: PackedStringArray = parents_by_cell.get(String(raw_cell), PackedStringArray())
					for parent_id: String in cell_parents:
						if not parent_id in parent_ids:
							parent_ids.append(parent_id)
		parent_ids.sort()
		event["parent_event_ids"] = parent_ids
		rewritten.append(event)
	return {"ok": true, "error": "", "events": rewritten}

func _contamination_application_events(events: Array) -> Array:
	var filtered: Array = []
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			if String(event.get("kind", "")) == "T10_EFFECT_APPLIED" and String(event.get("effect_kind", "")) == "CONTAMINATION_PULSE" and int(event.get("applied_delta", 0)) != 0:
				filtered.append(event.duplicate(true))
	filtered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("event_id", "")) < String(right.get("event_id", ""))
	)
	return filtered

func _serialize_contamination_reconsumption_events(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			parts.append("%s:%s:%s:%s" % [
				String(event.get("event_id", "")),
				String(event.get("kind", "")),
				String(event.get("instance_id", "")),
				str(event.get("parent_event_ids", PackedStringArray())),
			])
	return ";".join(parts)
