extends "res://src/sim/transit_power_integrated_runner_base.gd"

const ContaminationResponseKernelScript := preload("res://src/sim/contamination_response_kernel.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var base_result: Dictionary = super.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(base_result.get("ok", false)):
		return base_result

	var contamination_rules_value: Variant = simulation_defs.get("contamination_rules", null)
	if not contamination_rules_value is Dictionary:
		return base_result

	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	if not snapshots_value is Array:
		return _failure("invalid_end_tick_snapshots")
	var snapshots: Array = snapshots_value
	if snapshots.is_empty():
		return base_result

	var first_snapshot_value: Variant = snapshots[0]
	if not first_snapshot_value is Dictionary:
		return _failure("invalid_end_tick_snapshot")
	var first_snapshot: Dictionary = first_snapshot_value
	var first_contamination_value: Variant = first_snapshot.get("phase_d_contamination_exposure_by_cell", first_snapshot.get("contamination_by_cell", {}))
	var first_runtime_value: Variant = first_snapshot.get("organism_runtime", [])
	if not first_contamination_value is Dictionary:
		return _failure("invalid_contamination_snapshot")
	if not first_runtime_value is Array:
		return _failure("invalid_organism_runtime_snapshot")
	var first_contamination: Dictionary = first_contamination_value
	var first_runtime: Array = first_runtime_value
	if first_contamination.is_empty() or first_runtime.is_empty():
		return base_result

	var definitions_value: Variant = simulation_defs.get("organism_definitions", null)
	if not definitions_value is Dictionary:
		return _failure("missing_organism_definitions_for_contamination_response")
	var organism_definitions: Dictionary = definitions_value
	var response_kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var prepared: Dictionary = response_kernel.prepare_runtime(first_runtime, organism_definitions)
	if not bool(prepared.get("ok", false)):
		return _failure("contamination_prepare:%s" % String(prepared.get("error", "unknown")))
	var persisted_runtime: Array = prepared["organisms"]

	var integrated_snapshots: Array = []
	var all_response_events: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var base_checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not (base_checksums_value is Array or base_checksums_value is PackedStringArray):
		return _failure("invalid_base_tick_checksums")
	var base_checksums: Array = []
	for raw_checksum: Variant in base_checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return _failure("base_tick_checksum_count_mismatch")

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return _failure("invalid_end_tick_snapshot")
		var raw_snapshot_dictionary: Dictionary = raw_snapshot
		var snapshot: Dictionary = raw_snapshot_dictionary.duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var runtime_value: Variant = snapshot.get("organism_runtime", [])
		var contamination_value: Variant = snapshot.get("phase_d_contamination_exposure_by_cell", snapshot.get("contamination_by_cell", {}))
		if not runtime_value is Array:
			return _failure("invalid_organism_runtime_snapshot")
		if not contamination_value is Dictionary:
			return _failure("invalid_contamination_snapshot")
		var tick_runtime: Array = runtime_value
		var contamination_by_cell: Dictionary = contamination_value
		if index > 0:
			var merged_runtime: Dictionary = _merge_persisted_contamination(tick_runtime, persisted_runtime)
			if not bool(merged_runtime.get("ok", false)):
				return merged_runtime
			persisted_runtime = merged_runtime["organisms"]

		var sampled: Dictionary = response_kernel.sample_phase_e(tick, persisted_runtime, contamination_by_cell)
		if not bool(sampled.get("ok", false)):
			return _failure("phase_e:%s" % String(sampled.get("error", "unknown")))
		var phase_f: Dictionary = response_kernel.apply_phase_f(tick, persisted_runtime, sampled["observations"])
		if not bool(phase_f.get("ok", false)):
			return _failure("phase_f:%s" % String(phase_f.get("error", "unknown")))
		var phase_g: Dictionary = response_kernel.evaluate_phase_g(tick, phase_f["organisms"])
		if not bool(phase_g.get("ok", false)):
			return _failure("phase_g:%s" % String(phase_g.get("error", "unknown")))
		persisted_runtime = phase_g["organisms"]

		var tick_events: Array = []
		for event_batch: Variant in [sampled.get("events", []), phase_f.get("events", []), phase_g.get("events", [])]:
			if not event_batch is Array:
				return _failure("invalid_contamination_response_events")
			var events: Array = event_batch
			for raw_event: Variant in events:
				if not raw_event is Dictionary:
					return _failure("invalid_contamination_response_event")
				var event: Dictionary = raw_event
				tick_events.append(event.duplicate(true))
				all_response_events.append(event.duplicate(true))

		snapshot["organism_runtime"] = persisted_runtime.duplicate(true)
		snapshot["contamination_response_events"] = tick_events.duplicate(true)
		integrated_snapshots.append(snapshot)
		var checksum_material: String = "%s|contamination_response=%s" % [
			String(base_checksums[index]),
			_serialize_contamination_response(persisted_runtime, tick_events),
		]
		integrated_checksums.append(checksum_material.sha256_text())

	base_result["end_tick_snapshots"] = integrated_snapshots
	base_result["tick_checksums"] = integrated_checksums
	base_result["contamination_response_events"] = all_response_events
	base_result["final_organism_runtime"] = persisted_runtime.duplicate(true)
	return base_result

func _merge_persisted_contamination(current_runtime: Array, previous_runtime: Array) -> Dictionary:
	var previous_by_id: Dictionary = {}
	for raw_previous: Variant in previous_runtime:
		if not raw_previous is Dictionary:
			return _failure("invalid_previous_contamination_runtime")
		var previous: Dictionary = raw_previous
		var instance_id: String = String(previous.get("instance_id", ""))
		if instance_id.is_empty() or previous_by_id.has(instance_id):
			return _failure("invalid_previous_contamination_runtime_identity")
		previous_by_id[instance_id] = previous

	var merged: Array = []
	for raw_current: Variant in current_runtime:
		if not raw_current is Dictionary:
			return _failure("invalid_current_contamination_runtime")
		var current: Dictionary = raw_current
		var instance_id: String = String(current.get("instance_id", ""))
		if not previous_by_id.has(instance_id):
			return _failure("missing_previous_contamination_runtime:%s" % instance_id)
		var previous: Dictionary = previous_by_id[instance_id]
		var profile_value: Variant = previous.get("contamination_profile", null)
		if not profile_value is Dictionary:
			return _failure("missing_previous_contamination_profile:%s" % instance_id)
		var profile: Dictionary = profile_value
		var next: Dictionary = current.duplicate(true)
		next["contamination_profile"] = profile.duplicate(true)
		next["contamination_load"] = int(previous.get("contamination_load", 0))
		next["contaminated"] = bool(previous.get("contaminated", false))
		merged.append(next)
	if merged.size() != previous_runtime.size():
		return _failure("contamination_runtime_identity_mismatch")
	merged.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))
	)
	return {"ok": true, "error": "", "organisms": merged}

func _serialize_contamination_response(organisms: Array, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_organism: Variant in organisms:
		if raw_organism is Dictionary:
			var organism: Dictionary = raw_organism
			parts.append("org:%s:%d:%s" % [
				String(organism.get("instance_id", "")),
				int(organism.get("contamination_load", 0)),
				str(bool(organism.get("contaminated", false))),
			])
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			var parents_value: Variant = event.get("parent_event_ids", PackedStringArray())
			var parents: PackedStringArray = PackedStringArray()
			if parents_value is Array or parents_value is PackedStringArray:
				for raw_parent: Variant in parents_value:
					parents.append(String(raw_parent))
			parents.sort()
			parts.append("event:%s:%s:%s:%s" % [
				String(event.get("event_id", "")),
				String(event.get("phase", "")),
				String(event.get("kind", "")),
				",".join(parents),
			])
	return ";".join(parts)
