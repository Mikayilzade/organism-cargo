extends "res://src/sim/transit_stress_field_integrated_runner.gd"

const StressFieldResponseKernelScript := preload("res://src/sim/stress_field_response_kernel.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var base_result: Dictionary = super.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(base_result.get("ok", false)):
		return base_result

	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	if not snapshots_value is Array:
		return {"ok": false, "error": "invalid_end_tick_snapshots"}
	var snapshots: Array = snapshots_value
	if snapshots.is_empty():
		return base_result

	var first_snapshot_value: Variant = snapshots[0]
	if not first_snapshot_value is Dictionary:
		return {"ok": false, "error": "invalid_end_tick_snapshot"}
	var first_snapshot: Dictionary = first_snapshot_value
	var first_field_value: Variant = first_snapshot.get("stress_field_by_cell", null)
	var first_runtime_value: Variant = first_snapshot.get("organism_runtime", [])
	if not first_field_value is Dictionary:
		return base_result
	if not first_runtime_value is Array:
		return {"ok": false, "error": "invalid_organism_runtime_snapshot"}
	var first_field: Dictionary = first_field_value
	var first_runtime: Array = first_runtime_value
	if first_field.is_empty() or first_runtime.is_empty():
		return base_result

	var definitions_value: Variant = simulation_defs.get("organism_definitions", null)
	if not definitions_value is Dictionary:
		return {"ok": false, "error": "missing_organism_definitions_for_stress_field_response"}
	var organism_definitions: Dictionary = definitions_value
	var authority_result: Dictionary = _initial_stress_authority(first_runtime, organism_definitions)
	if not bool(authority_result.get("ok", false)):
		return authority_result
	var persisted_stress_by_id: Dictionary = authority_result["stress_by_id"]
	var persisted_state_by_id: Dictionary = authority_result["state_by_id"]
	var previous_base_stress_by_id: Dictionary = authority_result["stress_by_id"].duplicate(true)

	var checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return {"ok": false, "error": "invalid_base_tick_checksums"}
	var base_checksums: Array = []
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return {"ok": false, "error": "base_tick_checksum_count_mismatch"}

	var kernel: StressFieldResponseKernel = StressFieldResponseKernelScript.new()
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_events: Array = []
	var final_runtime: Array = []

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return {"ok": false, "error": "invalid_end_tick_snapshot"}
		var snapshot_source: Dictionary = raw_snapshot
		var snapshot: Dictionary = snapshot_source.duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var runtime_value: Variant = snapshot.get("organism_runtime", [])
		var field_value: Variant = snapshot.get("stress_field_by_cell", null)
		if not runtime_value is Array:
			return {"ok": false, "error": "invalid_organism_runtime_snapshot"}
		if not field_value is Dictionary:
			return {"ok": false, "error": "invalid_stress_field_snapshot"}
		var base_runtime: Array = runtime_value
		var stress_field_by_cell: Dictionary = field_value

		var composed_result: Dictionary = _compose_pre_field_runtime(
			base_runtime,
			persisted_stress_by_id,
			persisted_state_by_id,
			previous_base_stress_by_id
		)
		if not bool(composed_result.get("ok", false)):
			return composed_result
		var pre_field_runtime: Array = composed_result["organisms"]
		var upstream_delta_by_id: Dictionary = composed_result["upstream_stress_delta_by_id"]
		previous_base_stress_by_id = composed_result["base_stress_by_id"]

		var sampled: Dictionary = kernel.sample_phase_e(tick, pre_field_runtime, stress_field_by_cell)
		if not bool(sampled.get("ok", false)):
			return {"ok": false, "error": "phase_e_stress_field:%s" % String(sampled.get("error", "unknown"))}
		var phase_f: Dictionary = kernel.apply_phase_f(tick, pre_field_runtime, sampled["observations"])
		if not bool(phase_f.get("ok", false)):
			return {"ok": false, "error": "phase_f_stress_field:%s" % String(phase_f.get("error", "unknown"))}
		var phase_g: Dictionary = kernel.evaluate_phase_g(
			tick,
			phase_f["organisms"],
			phase_f["phase_f_event_id_by_instance_id"]
		)
		if not bool(phase_g.get("ok", false)):
			return {"ok": false, "error": "phase_g_stress_field:%s" % String(phase_g.get("error", "unknown"))}
		final_runtime = phase_g["organisms"]
		var persisted_result: Dictionary = _capture_persisted_stress(final_runtime)
		if not bool(persisted_result.get("ok", false)):
			return persisted_result
		persisted_stress_by_id = persisted_result["stress_by_id"]
		persisted_state_by_id = persisted_result["state_by_id"]

		var tick_events: Array = []
		for event_batch: Variant in [sampled.get("events", []), phase_f.get("events", []), phase_g.get("events", [])]:
			if not event_batch is Array:
				return {"ok": false, "error": "invalid_stress_field_response_events"}
			var events: Array = event_batch
			for raw_event: Variant in events:
				if not raw_event is Dictionary:
					return {"ok": false, "error": "invalid_stress_field_response_event"}
				var event: Dictionary = raw_event
				var next_event: Dictionary = event.duplicate(true)
				var instance_id: String = String(next_event.get("instance_id", ""))
				if next_event.get("phase", "") == "F":
					next_event["upstream_stress_delta"] = int(upstream_delta_by_id.get(instance_id, 0))
				tick_events.append(next_event)
				all_events.append(next_event.duplicate(true))

		snapshot["organism_runtime"] = final_runtime.duplicate(true)
		snapshot["stress_field_upstream_stress_delta_by_id"] = upstream_delta_by_id.duplicate(true)
		snapshot["stress_field_response_events"] = tick_events.duplicate(true)
		integrated_snapshots.append(snapshot)
		var checksum_material: String = "%s|stress_field_response=%s" % [
			String(base_checksums[index]),
			_serialize_stress_field_response(final_runtime, upstream_delta_by_id, tick_events),
		]
		integrated_checksums.append(checksum_material.sha256_text())

	base_result["end_tick_snapshots"] = integrated_snapshots
	base_result["tick_checksums"] = integrated_checksums
	base_result["stress_field_response_events"] = all_events
	base_result["final_organism_runtime"] = final_runtime.duplicate(true)
	return base_result

func _initial_stress_authority(base_runtime: Array, organism_definitions: Dictionary) -> Dictionary:
	var stress_by_id: Dictionary = {}
	var state_by_id: Dictionary = {}
	for raw_organism: Variant in base_runtime:
		if not raw_organism is Dictionary:
			return {"ok": false, "error": "invalid_organism_runtime_snapshot"}
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or stress_by_id.has(instance_id):
			return {"ok": false, "error": "invalid_organism_runtime_identity"}
		if not organism_definitions.has(instance_id) or not organism_definitions[instance_id] is Dictionary:
			return {"ok": false, "error": "missing_organism_definition:%s" % instance_id}
		var definition: Dictionary = organism_definitions[instance_id]
		var profile_value: Variant = organism.get("stress_profile", null)
		if not profile_value is Dictionary:
			return {"ok": false, "error": "missing_stress_profile:%s" % instance_id}
		var profile: Dictionary = profile_value
		var stress_min: int = int(profile.get("stress_min", 0))
		var stress_max: int = int(profile.get("stress_max", stress_min - 1))
		var initial_stress: int = int(definition.get("initial_stress", 0))
		if initial_stress < stress_min or initial_stress > stress_max:
			return {"ok": false, "error": "initial_stress_out_of_range:%s" % instance_id}
		var initial_state: String = String(definition.get("initial_state", "CALM"))
		if not initial_state in ["CALM", "AGITATED", "PANICKED"]:
			return {"ok": false, "error": "stress_field_initial_state_not_implemented:%s" % initial_state}
		stress_by_id[instance_id] = initial_stress
		state_by_id[instance_id] = initial_state
	return {"ok": true, "error": "", "stress_by_id": stress_by_id, "state_by_id": state_by_id}

func _compose_pre_field_runtime(
		base_runtime: Array,
		persisted_stress_by_id: Dictionary,
		persisted_state_by_id: Dictionary,
		previous_base_stress_by_id: Dictionary
) -> Dictionary:
	var results: Array = []
	var upstream_delta_by_id: Dictionary = {}
	var base_stress_by_id: Dictionary = {}
	for raw_organism: Variant in base_runtime:
		if not raw_organism is Dictionary:
			return {"ok": false, "error": "invalid_organism_runtime_snapshot"}
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if not persisted_stress_by_id.has(instance_id) or not persisted_state_by_id.has(instance_id) or not previous_base_stress_by_id.has(instance_id):
			return {"ok": false, "error": "stress_field_runtime_identity_mismatch:%s" % instance_id}
		var profile_value: Variant = organism.get("stress_profile", null)
		if not profile_value is Dictionary:
			return {"ok": false, "error": "missing_stress_profile:%s" % instance_id}
		var profile: Dictionary = profile_value
		var stress_min: int = int(profile.get("stress_min", 0))
		var stress_max: int = int(profile.get("stress_max", stress_min - 1))
		if stress_min > stress_max:
			return {"ok": false, "error": "invalid_stress_profile:%s" % instance_id}
		var base_stress: int = int(organism.get("stress", stress_min - 1))
		var previous_base_stress: int = int(previous_base_stress_by_id[instance_id])
		var upstream_delta: int = base_stress - previous_base_stress
		var persisted_stress: int = int(persisted_stress_by_id[instance_id])
		var composed_stress: int = clampi(persisted_stress + upstream_delta, stress_min, stress_max)
		var next: Dictionary = organism.duplicate(true)
		next["stress"] = composed_stress
		next["primary_state"] = String(persisted_state_by_id[instance_id])
		results.append(next)
		upstream_delta_by_id[instance_id] = upstream_delta
		base_stress_by_id[instance_id] = base_stress
	if results.size() != persisted_stress_by_id.size():
		return {"ok": false, "error": "incomplete_stress_field_runtime"}
	results.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))
	)
	return {
		"ok": true,
		"error": "",
		"organisms": results,
		"upstream_stress_delta_by_id": upstream_delta_by_id,
		"base_stress_by_id": base_stress_by_id,
	}

func _capture_persisted_stress(organisms: Array) -> Dictionary:
	var stress_by_id: Dictionary = {}
	var state_by_id: Dictionary = {}
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return {"ok": false, "error": "invalid_stress_field_response_runtime"}
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or stress_by_id.has(instance_id):
			return {"ok": false, "error": "invalid_stress_field_response_identity"}
		stress_by_id[instance_id] = int(organism.get("stress", 0))
		state_by_id[instance_id] = String(organism.get("primary_state", ""))
	return {"ok": true, "error": "", "stress_by_id": stress_by_id, "state_by_id": state_by_id}

func _serialize_stress_field_response(runtime: Array, upstream_delta_by_id: Dictionary, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_organism: Variant in runtime:
		if not raw_organism is Dictionary:
			continue
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		parts.append("organism=%s:%d:%s:%d" % [
			instance_id,
			int(organism.get("stress", 0)),
			String(organism.get("primary_state", "")),
			int(upstream_delta_by_id.get(instance_id, 0)),
		])
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
		parts.append("event=%s:%s:%s:%s:%d:%s" % [
			String(event.get("event_id", "")),
			String(event.get("phase", "")),
			String(event.get("kind", "")),
			String(event.get("instance_id", "")),
			int(event.get("stress_delta", event.get("stress_field_exposure", 0))),
			",".join(parents),
		])
	return "|".join(parts)
