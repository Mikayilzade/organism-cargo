extends "res://src/sim/transit_t10_reconsumption_integrated_runner.gd"

func integrate_effects(base_result: Dictionary, simulation_defs: Dictionary = {}) -> Dictionary:
	var integrated: Dictionary = super.integrate_effects(base_result, simulation_defs)
	if not bool(integrated.get("ok", false)):
		return integrated
	return _reconsume_heat_carry(integrated)

func _reconsume_heat_carry(result: Dictionary) -> Dictionary:
	var snapshots_value: Variant = result.get("end_tick_snapshots", [])
	var checksums_value: Variant = result.get("tick_checksums", PackedStringArray())
	if not snapshots_value is Array:
		return _failure("invalid_t10_heat_reconsumption_snapshots")
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return _failure("invalid_t10_heat_reconsumption_checksums")
	var snapshots: Array = snapshots_value as Array
	var checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in checksums_value:
		checksums.append(String(raw_checksum))
	if checksums.size() != snapshots.size():
		return _failure("t10_heat_reconsumption_checksum_count_mismatch")

	var rewritten_snapshots: Array = []
	var rewritten_checksums: PackedStringArray = PackedStringArray()
	var all_events: Array = []
	var previous_application_events: Array = []
	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return _failure("invalid_t10_heat_reconsumption_snapshot")
		var snapshot: Dictionary = (raw_snapshot as Dictionary).duplicate(true)
		var tick_events: Array = []
		var heat_applications: Array = _heat_application_events(previous_application_events)
		if not heat_applications.is_empty():
			var reconsumed: Dictionary = _reconsume_heat_tick(snapshot, heat_applications)
			if not bool(reconsumed.get("ok", false)):
				return reconsumed
			snapshot = reconsumed["snapshot"] as Dictionary
			tick_events = reconsumed["events"] as Array
			for raw_event: Variant in tick_events:
				if raw_event is Dictionary:
					all_events.append((raw_event as Dictionary).duplicate(true))
		snapshot["t10_heat_reconsumption_events"] = tick_events.duplicate(true)
		rewritten_snapshots.append(snapshot)
		var checksum_material: String = "%s|t10_heat_reconsume=%s" % [
			String(checksums[index]),
			_serialize_heat_reconsumption_events(tick_events),
		]
		rewritten_checksums.append(checksum_material.sha256_text())
		var application_value: Variant = snapshot.get("t10_effect_application_events", [])
		if not application_value is Array:
			return _failure("invalid_t10_effect_application_events")
		previous_application_events = (application_value as Array).duplicate(true)

	var next_result: Dictionary = result.duplicate(true)
	next_result["end_tick_snapshots"] = rewritten_snapshots
	next_result["tick_checksums"] = rewritten_checksums
	next_result["t10_heat_reconsumption_events"] = all_events
	if not rewritten_snapshots.is_empty():
		var final_snapshot: Dictionary = rewritten_snapshots[rewritten_snapshots.size() - 1] as Dictionary
		var final_runtime_value: Variant = final_snapshot.get("organism_runtime", [])
		if final_runtime_value is Array:
			next_result["final_organism_runtime"] = (final_runtime_value as Array).duplicate(true)
	return next_result

func _reconsume_heat_tick(snapshot: Dictionary, application_events: Array) -> Dictionary:
	var tick: int = int(snapshot.get("tick", 0))
	if tick <= 0:
		return _failure("invalid_t10_heat_reconsumption_tick")
	var heat_value: Variant = snapshot.get("heat_by_cell", null)
	var thermal_value: Variant = snapshot.get("organisms", null)
	var runtime_value: Variant = snapshot.get("organism_runtime", null)
	if not heat_value is Dictionary or not thermal_value is Array or not runtime_value is Array:
		return _failure("missing_t10_heat_reconsumption_authority")
	var baseline_by_id: Dictionary = {}
	for raw_thermal: Variant in thermal_value as Array:
		if not raw_thermal is Dictionary:
			return _failure("invalid_t10_heat_baseline_response")
		var thermal: Dictionary = raw_thermal
		var instance_id: String = String(thermal.get("instance_id", ""))
		if instance_id.is_empty():
			return _failure("invalid_t10_heat_baseline_identity")
		baseline_by_id[instance_id] = thermal.duplicate(true)

	var thermal_inputs: Array = []
	for raw_runtime: Variant in runtime_value as Array:
		if not raw_runtime is Dictionary:
			return _failure("invalid_t10_heat_runtime")
		var organism: Dictionary = (raw_runtime as Dictionary).duplicate(true)
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or not baseline_by_id.has(instance_id):
			return _failure("missing_t10_heat_baseline:%s" % instance_id)
		var profile_value: Variant = organism.get("stress_profile", null)
		if not profile_value is Dictionary:
			return _failure("missing_t10_heat_stress_profile:%s" % instance_id)
		var profile: Dictionary = profile_value
		var baseline: Dictionary = baseline_by_id[instance_id]
		organism["stress"] = clampi(
			int(baseline.get("stress", 0)) - int(baseline.get("stress_delta", 0)),
			int(profile.get("stress_min", 0)),
			int(profile.get("stress_max", 0))
		)
		thermal_inputs.append(organism)

	var response: Dictionary = ThermalResponseKernelScript.new().apply_heat_response(
		thermal_inputs,
		heat_value as Dictionary
	)
	if not bool(response.get("ok", false)):
		return _failure("t10_heat_reconsumption:%s" % String(response.get("error", "unknown")))
	var recomputed_value: Variant = response.get("organisms", [])
	if not recomputed_value is Array:
		return _failure("invalid_t10_heat_recomputed_response")
	var recomputed: Array = recomputed_value as Array
	var recomputed_by_id: Dictionary = {}
	for raw_recomputed: Variant in recomputed:
		if not raw_recomputed is Dictionary:
			return _failure("invalid_t10_heat_recomputed_organism")
		var item: Dictionary = raw_recomputed
		recomputed_by_id[String(item.get("instance_id", ""))] = item

	var runtime: Array = (runtime_value as Array).duplicate(true)
	var stress_delta_by_id: Dictionary = {}
	var events: Array = []
	var parents_by_cell: Dictionary = _application_parents_by_cell(application_events, "HEAT_PULSE")
	for index: int in range(runtime.size()):
		var raw_runtime: Variant = runtime[index]
		if not raw_runtime is Dictionary:
			return _failure("invalid_t10_heat_runtime")
		var organism: Dictionary = (raw_runtime as Dictionary).duplicate(true)
		var instance_id: String = String(organism.get("instance_id", ""))
		if not baseline_by_id.has(instance_id) or not recomputed_by_id.has(instance_id):
			return _failure("missing_t10_heat_response:%s" % instance_id)
		var baseline: Dictionary = baseline_by_id[instance_id]
		var next_thermal: Dictionary = recomputed_by_id[instance_id]
		var stress_delta_change: int = int(next_thermal.get("stress_delta", 0)) - int(baseline.get("stress_delta", 0))
		stress_delta_by_id[instance_id] = stress_delta_change
		var profile: Dictionary = organism.get("stress_profile", {})
		organism["stress"] = clampi(
			int(organism.get("stress", 0)) + stress_delta_change,
			int(profile.get("stress_min", 0)),
			int(profile.get("stress_max", 0))
		)
		runtime[index] = organism
		var parent_ids: PackedStringArray = PackedStringArray()
		var occupied_value: Variant = organism.get("occupied_cells", [])
		if occupied_value is Array or occupied_value is PackedStringArray:
			for raw_cell: Variant in occupied_value:
				var cell_parents: PackedStringArray = parents_by_cell.get(String(raw_cell), PackedStringArray())
				for parent_id: String in cell_parents:
					if not parent_id in parent_ids:
						parent_ids.append(parent_id)
		parent_ids.sort()
		if not parent_ids.is_empty():
			events.append({
				"event_id": "t10-heat-reconsume-%03d-%s" % [tick, instance_id],
				"kind": "T10_HEAT_RECONSUMED",
				"phase": "E_F_G",
				"tick": tick,
				"instance_id": instance_id,
				"heat_exposure_before": int(baseline.get("heat_exposure", 0)),
				"heat_exposure_after": int(next_thermal.get("heat_exposure", 0)),
				"stress_delta_before": int(baseline.get("stress_delta", 0)),
				"stress_delta_after": int(next_thermal.get("stress_delta", 0)),
				"applied_stress_delta_change": stress_delta_change,
				"parent_event_ids": parent_ids,
			})

	var next_snapshot: Dictionary = snapshot.duplicate(true)
	next_snapshot["organisms"] = recomputed.duplicate(true)
	next_snapshot["organism_runtime"] = runtime
	next_snapshot["t10_heat_reconsumed_stress_delta_by_instance_id"] = stress_delta_by_id
	return {"ok": true, "error": "", "snapshot": next_snapshot, "events": events}

func _application_parents_by_cell(events: Array, effect_kind: String) -> Dictionary:
	var parents_by_cell: Dictionary = {}
	for raw_event: Variant in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		if String(event.get("kind", "")) != "T10_EFFECT_APPLIED" or String(event.get("effect_kind", "")) != effect_kind:
			continue
		var cell_key: String = String(event.get("cell_key", ""))
		var event_id: String = String(event.get("event_id", ""))
		if cell_key.is_empty() or event_id.is_empty():
			continue
		var parents: PackedStringArray = parents_by_cell.get(cell_key, PackedStringArray())
		if not event_id in parents:
			parents.append(event_id)
			parents.sort()
		parents_by_cell[cell_key] = parents
	return parents_by_cell

func _heat_application_events(events: Array) -> Array:
	var filtered: Array = []
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			if String(event.get("kind", "")) == "T10_EFFECT_APPLIED" and String(event.get("effect_kind", "")) == "HEAT_PULSE" and int(event.get("applied_delta", 0)) != 0:
				filtered.append(event.duplicate(true))
	filtered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("event_id", "")) < String(right.get("event_id", ""))
	)
	return filtered

func _serialize_heat_reconsumption_events(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_event: Variant in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var parents_value: Variant = event.get("parent_event_ids", PackedStringArray())
		var parents: PackedStringArray = PackedStringArray()
		if parents_value is Array or parents_value is PackedStringArray:
			for raw_parent: Variant in parents_value:
				parents.append(String(raw_parent))
		parents.sort()
		parts.append("%s:%s:%d:%d:%s" % [
			String(event.get("event_id", "")),
			String(event.get("instance_id", "")),
			int(event.get("heat_exposure_after", 0)),
			int(event.get("stress_delta_after", 0)),
			",".join(parents),
		])
	return ";".join(parts)
