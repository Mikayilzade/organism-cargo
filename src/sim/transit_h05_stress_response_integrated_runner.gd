extends "res://src/sim/transit_stress_response_integrated_runner.gd"

const H05StressFieldIntegratedRunnerScript := preload("res://src/sim/transit_h06_stress_field_integrated_runner.gd")
const H05StressFieldResponseKernelScript := preload("res://src/sim/stress_field_response_kernel.gd")
const H05SleepWakeKernelScript := preload("res://src/sim/sleep_wake_kernel.gd")
const H05S04NestPadKernelScript := preload("res://src/sim/s04_nest_pad_kernel.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var s04_authority: Dictionary = _prepare_s04_authority(committed_run, simulation_defs)
	if not bool(s04_authority.get("ok", false)):
		return s04_authority
	var base_run: Dictionary = s04_authority["base_run"]
	var s04_supports: Array = s04_authority["s04_supports"]
	var support_definitions_by_id: Dictionary = s04_authority["support_definitions_by_id"]
	var s04_transition_schedule: Array = s04_authority["transition_schedule"]

	var base_result: Dictionary = H05StressFieldIntegratedRunnerScript.new().simulate(base_run, total_ticks, simulation_defs)
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

	var kernel: StressFieldResponseKernel = H05StressFieldResponseKernelScript.new()
	var sleep_wake_kernel: SleepWakeKernel = H05SleepWakeKernelScript.new()
	var s04_kernel: S04NestPadKernel = H05S04NestPadKernelScript.new()
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
