extends "res://src/sim/transit_t10_authority_guard_integrated_runner.gd"

const StressFieldResponseKernelScript := preload("res://src/sim/stress_field_response_kernel.gd")

const STRESS_RESPONSE_EVENT_KINDS := [
	"STRESS_FIELD_EXPOSURE",
	"STRESS_FIELD_INTERNAL_STRESS",
	"STRESS_STATE_TRANSITION",
]

func integrate_effects(base_result: Dictionary, simulation_defs: Dictionary = {}) -> Dictionary:
	var integrated: Dictionary = super.integrate_effects(base_result, simulation_defs)
	if not bool(integrated.get("ok", false)):
		return integrated
	return _reconsume_stress_field_carry(integrated)

func _reconsume_stress_field_carry(result: Dictionary) -> Dictionary:
	var snapshots_value: Variant = result.get("end_tick_snapshots", [])
	var checksums_value: Variant = result.get("tick_checksums", PackedStringArray())
	if not snapshots_value is Array:
		return _failure("invalid_t10_reconsumption_snapshots")
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return _failure("invalid_t10_reconsumption_checksums")
	var snapshots: Array = snapshots_value as Array
	var checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in checksums_value:
		checksums.append(String(raw_checksum))
	if checksums.size() != snapshots.size():
		return _failure("t10_reconsumption_checksum_count_mismatch")

	var rewritten_snapshots: Array = []
	var rewritten_checksums: PackedStringArray = PackedStringArray()
	var all_reconsumption_events: Array = []
	var previous_application_events: Array = []

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return _failure("invalid_t10_reconsumption_snapshot")
		var snapshot: Dictionary = (raw_snapshot as Dictionary).duplicate(true)
		var tick_reconsumption_events: Array = []
		var stress_application_events: Array = _stress_application_events(previous_application_events)
		if not stress_application_events.is_empty():
			var reconsumed: Dictionary = _reconsume_stress_field_tick(snapshot, stress_application_events)
			if not bool(reconsumed.get("ok", false)):
				return reconsumed
			snapshot = reconsumed["snapshot"] as Dictionary
			tick_reconsumption_events = reconsumed["events"] as Array
			for raw_event: Variant in tick_reconsumption_events:
				if raw_event is Dictionary:
					all_reconsumption_events.append((raw_event as Dictionary).duplicate(true))
		snapshot["t10_reconsumption_events"] = tick_reconsumption_events.duplicate(true)
		rewritten_snapshots.append(snapshot)
		var checksum_material: String = "%s|t10_reconsume=%s" % [
			String(checksums[index]),
			_serialize_reconsumption_events(tick_reconsumption_events),
		]
		rewritten_checksums.append(checksum_material.sha256_text())
		var application_value: Variant = snapshot.get("t10_effect_application_events", [])
		if not application_value is Array:
			return _failure("invalid_t10_effect_application_events")
		previous_application_events = (application_value as Array).duplicate(true)

	var next_result: Dictionary = result.duplicate(true)
	next_result["end_tick_snapshots"] = rewritten_snapshots
	next_result["tick_checksums"] = rewritten_checksums
	next_result["t10_reconsumption_events"] = all_reconsumption_events
	var aggregate_stress_events: Array = []
	for raw_snapshot: Variant in rewritten_snapshots:
		if not raw_snapshot is Dictionary:
			continue
		var events_value: Variant = (raw_snapshot as Dictionary).get("stress_field_response_events", [])
		if events_value is Array:
			for raw_event: Variant in events_value:
				if raw_event is Dictionary:
					aggregate_stress_events.append((raw_event as Dictionary).duplicate(true))
	next_result["stress_field_response_events"] = aggregate_stress_events
	if not rewritten_snapshots.is_empty():
		var final_snapshot: Dictionary = rewritten_snapshots[rewritten_snapshots.size() - 1] as Dictionary
		var final_runtime_value: Variant = final_snapshot.get("organism_runtime", [])
		if final_runtime_value is Array:
			next_result["final_organism_runtime"] = (final_runtime_value as Array).duplicate(true)
	return next_result

func _reconsume_stress_field_tick(
		snapshot: Dictionary,
		application_events: Array
) -> Dictionary:
	var tick: int = int(snapshot.get("tick", 0))
	if tick <= 0:
		return _failure("invalid_t10_reconsumption_tick")
	var field_value: Variant = snapshot.get("stress_field_by_cell", null)
	var runtime_value: Variant = snapshot.get("organism_runtime", null)
	var response_value: Variant = snapshot.get("stress_field_response_events", null)
	if not field_value is Dictionary or not runtime_value is Array or not response_value is Array:
		return _failure("missing_t10_stress_reconsumption_authority")
	var pre_runtime_result: Dictionary = _reconstruct_pre_stress_runtime(
		runtime_value as Array,
		response_value as Array,
		tick
	)
	if not bool(pre_runtime_result.get("ok", false)):
		return pre_runtime_result
	var pre_runtime: Array = pre_runtime_result["organisms"] as Array
	var sampled: Dictionary = StressFieldResponseKernelScript.new().sample_phase_e(tick, pre_runtime, field_value as Dictionary)
	if not bool(sampled.get("ok", false)):
		return _failure("phase_e_t10_reconsumption:%s" % String(sampled.get("error", "unknown")))
	var sample_events: Array = sampled.get("events", []) as Array
	var ancestry_result: Dictionary = _attach_t10_stress_ancestry(sample_events, pre_runtime, application_events)
	if not bool(ancestry_result.get("ok", false)):
		return ancestry_result
	sample_events = ancestry_result["events"] as Array
	var phase_f: Dictionary = StressFieldResponseKernelScript.new().apply_phase_f(tick, pre_runtime, sampled["observations"] as Array)
	if not bool(phase_f.get("ok", false)):
		return _failure("phase_f_t10_reconsumption:%s" % String(phase_f.get("error", "unknown")))
	var phase_f_events: Array = phase_f.get("events", []) as Array
	var upstream_by_id: Dictionary = pre_runtime_result["upstream_by_id"] as Dictionary
	for index: int in range(phase_f_events.size()):
		var raw_event: Variant = phase_f_events[index]
		if not raw_event is Dictionary:
			return _failure("invalid_t10_reconsumption_phase_f_event")
		var event: Dictionary = (raw_event as Dictionary).duplicate(true)
		var instance_id: String = String(event.get("instance_id", ""))
		event["upstream_stress_delta"] = int(upstream_by_id.get(instance_id, 0))
		phase_f_events[index] = event
	var phase_g: Dictionary = StressFieldResponseKernelScript.new().evaluate_phase_g(
		tick,
		phase_f["organisms"] as Array,
		phase_f["phase_f_event_id_by_instance_id"] as Dictionary
	)
	if not bool(phase_g.get("ok", false)):
		return _failure("phase_g_t10_reconsumption:%s" % String(phase_g.get("error", "unknown")))

	var preserved_events: Array = []
	for raw_event: Variant in response_value:
		if not raw_event is Dictionary:
			return _failure("invalid_t10_reconsumption_response_event")
		var event: Dictionary = raw_event
		if String(event.get("kind", "")) in STRESS_RESPONSE_EVENT_KINDS:
			continue
		preserved_events.append(event.duplicate(true))
	var replacement_events: Array = []
	var phase_g_events: Array = phase_g.get("events", []) as Array
	for batch: Array in [sample_events, phase_f_events, phase_g_events]:
		for raw_event: Variant in batch:
			if not raw_event is Dictionary:
				return _failure("invalid_t10_reconsumption_event")
			replacement_events.append((raw_event as Dictionary).duplicate(true))
			preserved_events.append((raw_event as Dictionary).duplicate(true))

	var next_snapshot: Dictionary = snapshot.duplicate(true)
	next_snapshot["organism_runtime"] = (phase_g["organisms"] as Array).duplicate(true)
	next_snapshot["stress_field_response_events"] = preserved_events
	return {"ok": true, "error": "", "snapshot": next_snapshot, "events": replacement_events}

func _reconstruct_pre_stress_runtime(runtime: Array, response_events: Array, tick: int) -> Dictionary:
	var stress_before_by_id: Dictionary = {}
	var state_before_by_id: Dictionary = {}
	var upstream_by_id: Dictionary = {}
	for raw_event: Variant in response_events:
		if not raw_event is Dictionary:
			return _failure("invalid_t10_reconsumption_response_event")
		var event: Dictionary = raw_event
		if int(event.get("tick", tick)) != tick:
			continue
		var instance_id: String = String(event.get("instance_id", ""))
		if String(event.get("kind", "")) == "STRESS_FIELD_INTERNAL_STRESS":
			stress_before_by_id[instance_id] = int(event.get("stress_before", 0))
			upstream_by_id[instance_id] = int(event.get("upstream_stress_delta", 0))
		elif String(event.get("kind", "")) == "STRESS_STATE_TRANSITION":
			state_before_by_id[instance_id] = String(event.get("state_before", ""))
	var reconstructed: Array = runtime.duplicate(true)
	for index: int in range(reconstructed.size()):
		var raw_runtime: Variant = reconstructed[index]
		if not raw_runtime is Dictionary:
			return _failure("invalid_t10_reconsumption_runtime")
		var organism: Dictionary = (raw_runtime as Dictionary).duplicate(true)
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or not stress_before_by_id.has(instance_id):
			return _failure("missing_t10_pre_stress_authority:%s" % instance_id)
		organism["stress"] = int(stress_before_by_id[instance_id])
		if state_before_by_id.has(instance_id):
			organism["primary_state"] = String(state_before_by_id[instance_id])
		reconstructed[index] = organism
	return {"ok": true, "error": "", "organisms": reconstructed, "upstream_by_id": upstream_by_id}

func _attach_t10_stress_ancestry(sample_events: Array, runtime: Array, application_events: Array) -> Dictionary:
	var parents_by_cell: Dictionary = {}
	for raw_application: Variant in application_events:
		if not raw_application is Dictionary:
			return _failure("invalid_t10_stress_application_event")
		var application: Dictionary = raw_application
		if String(application.get("kind", "")) != "T10_EFFECT_APPLIED" or String(application.get("effect_kind", "")) != "STRESS_FIELD_PULSE":
			continue
		var cell_key: String = String(application.get("cell_key", ""))
		var event_id: String = String(application.get("event_id", ""))
		if cell_key.is_empty() or event_id.is_empty():
			continue
		var parents: PackedStringArray = parents_by_cell.get(cell_key, PackedStringArray())
		if not event_id in parents:
			parents.append(event_id)
			parents.sort()
		parents_by_cell[cell_key] = parents
	var runtime_by_id: Dictionary = {}
	for raw_runtime: Variant in runtime:
		if raw_runtime is Dictionary:
			var organism: Dictionary = raw_runtime
			runtime_by_id[String(organism.get("instance_id", ""))] = organism
	var rewritten: Array = []
	for raw_event: Variant in sample_events:
		if not raw_event is Dictionary:
			return _failure("invalid_t10_stress_sample_event")
		var event: Dictionary = (raw_event as Dictionary).duplicate(true)
		var instance_id: String = String(event.get("instance_id", ""))
		var parent_ids: PackedStringArray = PackedStringArray()
		if runtime_by_id.has(instance_id):
			var organism: Dictionary = runtime_by_id[instance_id]
			var occupied_value: Variant = organism.get("occupied_cells", [])
			if occupied_value is Array or occupied_value is PackedStringArray:
				for raw_cell: Variant in occupied_value:
					var cell_key: String = String(raw_cell)
					var cell_parents: PackedStringArray = parents_by_cell.get(cell_key, PackedStringArray())
					for parent_id: String in cell_parents:
						if not parent_id in parent_ids:
							parent_ids.append(parent_id)
		parent_ids.sort()
		event["parent_event_ids"] = parent_ids
		rewritten.append(event)
	return {"ok": true, "error": "", "events": rewritten}

func _stress_application_events(events: Array) -> Array:
	var filtered: Array = []
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			if String(event.get("kind", "")) == "T10_EFFECT_APPLIED" and String(event.get("effect_kind", "")) == "STRESS_FIELD_PULSE" and int(event.get("applied_delta", 0)) != 0:
				filtered.append(event.duplicate(true))
	filtered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("event_id", "")) < String(right.get("event_id", ""))
	)
	return filtered

func _serialize_reconsumption_events(events: Array) -> String:
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
		parts.append("%s:%s:%s" % [
			String(event.get("event_id", "")),
			String(event.get("kind", "")),
			",".join(parents),
		])
	return ";".join(parts)
