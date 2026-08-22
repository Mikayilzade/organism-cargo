extends "res://src/sim/transit_stress_field_integrated_runner.gd"

const StressFieldResponseKernelScript := preload("res://src/sim/stress_field_response_kernel.gd")
const SleepWakeKernelScript := preload("res://src/sim/sleep_wake_kernel.gd")
const S04NestPadKernelScript := preload("res://src/sim/s04_nest_pad_kernel.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var s04_authority: Dictionary = _prepare_s04_authority(committed_run, simulation_defs)
	if not bool(s04_authority.get("ok", false)):
		return s04_authority
	var base_run: Dictionary = s04_authority["base_run"]
	var s04_supports: Array = s04_authority["s04_supports"]
	var support_definitions_by_id: Dictionary = s04_authority["support_definitions_by_id"]
	var s04_transition_schedule: Array = s04_authority["transition_schedule"]

	var base_result: Dictionary = super.simulate(base_run, total_ticks, simulation_defs)
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
	var hazards_value: Variant = simulation_defs.get("hazards_by_id", null)
	if not hazards_value is Dictionary:
		return {"ok": false, "error": "missing_sleep_wake_hazard_authority"}
	var hazards_by_id: Dictionary = hazards_value
	var authority_result: Dictionary = _initial_stress_authority(first_runtime, organism_definitions)
	if not bool(authority_result.get("ok", false)):
		return authority_result
	var persisted_stress_by_id: Dictionary = authority_result["stress_by_id"]
	var persisted_state_by_id: Dictionary = authority_result["state_by_id"]
	var previous_base_stress_by_id: Dictionary = persisted_stress_by_id.duplicate(true)

	var checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return {"ok": false, "error": "invalid_base_tick_checksums"}
	var base_checksums: Array = []
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return {"ok": false, "error": "base_tick_checksum_count_mismatch"}

	var kernel: StressFieldResponseKernel = StressFieldResponseKernelScript.new()
	var sleep_wake_kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	var s04_kernel: S04NestPadKernel = S04NestPadKernelScript.new()
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_events: Array = []
	var all_wake_events: Array = []
	var all_s04_events: Array = []
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

		var s04_events: Array = []
		if not s04_supports.is_empty():
			var sleep_eligibility_result: Dictionary = _with_sleep_eligibility(pre_field_runtime, organism_definitions)
			if not bool(sleep_eligibility_result.get("ok", false)):
				return sleep_eligibility_result
			pre_field_runtime = sleep_eligibility_result["organisms"]
			var s04_result: Dictionary = s04_kernel.resolve_phase_b(
				tick,
				pre_field_runtime,
				s04_supports,
				support_definitions_by_id,
				s04_transition_schedule
			)
			if not bool(s04_result.get("ok", false)):
				return {"ok": false, "error": "phase_b_s04:%s" % String(s04_result.get("error", "unknown"))}
			pre_field_runtime = s04_result["organisms"]
			var s04_events_value: Variant = s04_result.get("events", [])
			if not s04_events_value is Array:
				return {"ok": false, "error": "invalid_s04_transition_events"}
			s04_events = s04_events_value

		var active_value: Variant = snapshot.get("active_hazards", PackedStringArray())
		if not (active_value is Array or active_value is PackedStringArray):
			return {"ok": false, "error": "invalid_active_hazards_for_sleep_wake"}
		var active_hazard_ids: PackedStringArray = PackedStringArray()
		for raw_hazard_id: Variant in active_value:
			active_hazard_ids.append(String(raw_hazard_id))
		var wake_result: Dictionary = sleep_wake_kernel.resolve_phase_b(tick, pre_field_runtime, active_hazard_ids, hazards_by_id)
		if not bool(wake_result.get("ok", false)):
			return {"ok": false, "error": "phase_b_sleep_wake:%s" % String(wake_result.get("error", "unknown"))}
		pre_field_runtime = wake_result["organisms"]
		var wake_events_value: Variant = wake_result.get("events", [])
		if not wake_events_value is Array:
			return {"ok": false, "error": "invalid_sleep_wake_events"}
		var wake_events: Array = wake_events_value

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
		for raw_s04_event: Variant in s04_events:
			if not raw_s04_event is Dictionary:
				return {"ok": false, "error": "invalid_s04_transition_event"}
			var s04_event: Dictionary = raw_s04_event
			tick_events.append(s04_event.duplicate(true))
			all_events.append(s04_event.duplicate(true))
			all_s04_events.append(s04_event.duplicate(true))
		for raw_wake_event: Variant in wake_events:
			if not raw_wake_event is Dictionary:
				return {"ok": false, "error": "invalid_sleep_wake_event"}
			var wake_event: Dictionary = raw_wake_event
			tick_events.append(wake_event.duplicate(true))
			all_events.append(wake_event.duplicate(true))
			all_wake_events.append(wake_event.duplicate(true))
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
		snapshot["s04_transition_events"] = s04_events.duplicate(true)
		snapshot["sleep_wake_events"] = wake_events.duplicate(true)
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
	base_result["s04_transition_events"] = all_s04_events
	base_result["sleep_wake_events"] = all_wake_events
	base_result["stress_field_response_events"] = all_events
	base_result["final_organism_runtime"] = final_runtime.duplicate(true)
	return base_result

func _prepare_s04_authority(committed_run: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	if not committed_run.has("canonical_committed_input") or not committed_run["canonical_committed_input"] is Dictionary:
		return {"ok": false, "error": "missing_committed_input"}
	var committed_input: Dictionary = committed_run["canonical_committed_input"]
	var supports_value: Variant = committed_input.get("supports", [])
	if not supports_value is Array:
		return {"ok": false, "error": "invalid_committed_supports"}
	var support_definitions_value: Variant = simulation_defs.get("support_definitions_by_id", {})
	if not support_definitions_value is Dictionary:
		return {"ok": false, "error": "invalid_support_definitions"}
	var support_definitions_by_id: Dictionary = support_definitions_value
	var transition_schedule_value: Variant = simulation_defs.get("s04_transition_schedule", [])
	if not transition_schedule_value is Array:
		return {"ok": false, "error": "invalid_s04_transition_schedule"}
	var transition_schedule: Array = transition_schedule_value
	var retained_supports: Array = []
	var s04_supports: Array = []
	for raw_support: Variant in supports_value:
		if not raw_support is Dictionary:
			return {"ok": false, "error": "invalid_committed_support"}
		var support: Dictionary = raw_support
		var support_id: String = String(support.get("support_id", ""))
		if support_id.is_empty():
			return {"ok": false, "error": "invalid_committed_support_identity"}
		if not support_definitions_by_id.has(support_id) or not support_definitions_by_id[support_id] is Dictionary:
			return {"ok": false, "error": "missing_support_definition:%s" % support_id}
		var support_definition: Dictionary = support_definitions_by_id[support_id]
		if String(support_definition.get("family", support_id)) == "S04":
			s04_supports.append(support.duplicate(true))
		else:
			retained_supports.append(support.duplicate(true))
	if not transition_schedule.is_empty() and s04_supports.is_empty():
		return {"ok": false, "error": "s04_schedule_without_nest_pad"}
	var base_run: Dictionary = committed_run.duplicate(true)
	var base_input: Dictionary = committed_input.duplicate(true)
	base_input["supports"] = retained_supports
	base_run["canonical_committed_input"] = base_input
	return {
		"ok": true,
		"error": "",
		"base_run": base_run,
		"s04_supports": s04_supports,
		"support_definitions_by_id": support_definitions_by_id.duplicate(true),
		"transition_schedule": transition_schedule.duplicate(true),
	}

func _with_sleep_eligibility(organisms: Array, organism_definitions: Dictionary) -> Dictionary:
	var results: Array = []
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return {"ok": false, "error": "invalid_organism_runtime_snapshot"}
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or not organism_definitions.has(instance_id) or not organism_definitions[instance_id] is Dictionary:
			return {"ok": false, "error": "missing_organism_definition:%s" % instance_id}
		var definition: Dictionary = organism_definitions[instance_id]
		var next: Dictionary = organism.duplicate(true)
		next["can_sleep"] = bool(definition.get("can_sleep", false))
		results.append(next)
	return {"ok": true, "error": "", "organisms": results}

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
		if not initial_state in ["CALM", "AGITATED", "PANICKED", "ASLEEP"]:
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
		parts.append("event=%s:%s:%s:%s:%s:%s:%s:%s:%d:%s" % [
			String(event.get("event_id", "")),
			String(event.get("phase", "")),
			String(event.get("kind", "")),
			String(event.get("instance_id", "")),
			String(event.get("support_instance_id", "")),
			String(event.get("target_instance_id", "")),
			String(event.get("state_before", "")),
			String(event.get("state_after", "")),
			int(event.get("stress_delta", event.get("stress_field_exposure", 0))),
			",".join(parents),
		])
	return "|".join(parts)