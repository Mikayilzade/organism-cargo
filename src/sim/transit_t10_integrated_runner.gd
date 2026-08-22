extends "res://src/sim/transit_h05_stress_response_integrated_runner.gd"

const T10ReactivePulseKernelScript := preload("res://src/sim/t10_reactive_pulse_kernel.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var base_result: Dictionary = super.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(base_result.get("ok", false)):
		return base_result
	var definitions_value: Variant = simulation_defs.get("t10_definitions", [])
	if not definitions_value is Array:
		return {"ok": false, "error": "invalid_t10_definitions"}
	var definitions: Array = definitions_value
	if definitions.is_empty():
		return base_result
	return integrate_phase_h(base_result, definitions)

func integrate_phase_h(base_result: Dictionary, definitions: Array) -> Dictionary:
	var kernel: T10ReactivePulseKernel = T10ReactivePulseKernelScript.new()
	var validation: Dictionary = kernel.validate_definitions(definitions)
	if not bool(validation.get("ok", false)):
		return validation
	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	var checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not snapshots_value is Array:
		return {"ok": false, "error": "invalid_end_tick_snapshots"}
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return {"ok": false, "error": "invalid_tick_checksums"}
	var snapshots: Array = snapshots_value
	var base_checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return {"ok": false, "error": "t10_tick_checksum_count_mismatch"}

	var runtime_state: Dictionary = {}
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_trigger_events: Array = []
	var all_pulse_events: Array = []
	var all_effect_records: Array = []
	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return {"ok": false, "error": "invalid_end_tick_snapshot"}
		var snapshot: Dictionary = (raw_snapshot as Dictionary).duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var trigger_result: Dictionary = _collect_t10_trigger_events(snapshot)
		if not bool(trigger_result.get("ok", false)):
			return trigger_result
		var trigger_events: Array = trigger_result["events"]
		var resolved: Dictionary = kernel.resolve_phase_h(tick, trigger_events, definitions, runtime_state)
		if not bool(resolved.get("ok", false)):
			return {"ok": false, "error": "phase_h_t10:%s" % String(resolved.get("error", "unknown"))}
		runtime_state = resolved["state"]
		var pulse_events: Array = resolved["events"]
		var effect_records: Array = resolved["effects"]
		snapshot["t10_trigger_events"] = trigger_events.duplicate(true)
		snapshot["t10_pulse_events"] = pulse_events.duplicate(true)
		snapshot["t10_effect_records"] = effect_records.duplicate(true)
		snapshot["t10_authority_checksum"] = String(resolved["authority_checksum"])
		integrated_snapshots.append(snapshot)
		for raw_trigger: Variant in trigger_events:
			all_trigger_events.append((raw_trigger as Dictionary).duplicate(true))
		for raw_pulse: Variant in pulse_events:
			all_pulse_events.append((raw_pulse as Dictionary).duplicate(true))
		for raw_effect: Variant in effect_records:
			all_effect_records.append((raw_effect as Dictionary).duplicate(true))
		var checksum_material: String = "%s|t10=%s" % [String(base_checksums[index]), String(resolved["authority_payload"])]
		integrated_checksums.append(checksum_material.sha256_text())

	var result: Dictionary = base_result.duplicate(true)
	result["end_tick_snapshots"] = integrated_snapshots
	result["tick_checksums"] = integrated_checksums
	result["t10_trigger_events"] = all_trigger_events
	result["t10_pulse_events"] = all_pulse_events
	result["t10_effect_records"] = all_effect_records
	result["t10_runtime_state"] = runtime_state.duplicate(true)
	return result

func _collect_t10_trigger_events(snapshot: Dictionary) -> Dictionary:
	var candidates: Array = []
	for key: String in ["stress_field_response_events", "sleep_wake_events", "t10_named_trigger_events"]:
		var value: Variant = snapshot.get(key, [])
		if not value is Array:
			return {"ok": false, "error": "invalid_t10_trigger_source:%s" % key}
		for raw_event: Variant in value:
			if not raw_event is Dictionary:
				return {"ok": false, "error": "invalid_t10_trigger_source_event:%s" % key}
			var event: Dictionary = raw_event
			var event_tick: int = int(event.get("tick", int(snapshot.get("tick", 0))))
			if event_tick != int(snapshot.get("tick", event_tick)):
				continue
			candidates.append(event.duplicate(true))
			var semantic: Dictionary = _semantic_transition_event(event)
			if not semantic.is_empty():
				candidates.append(semantic)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("event_id", "")) < String(right.get("event_id", ""))
	)
	var seen: Dictionary = {}
	var unique: Array = []
	for raw_candidate: Variant in candidates:
		var candidate: Dictionary = raw_candidate
		var event_id: String = String(candidate.get("event_id", ""))
		var kind: String = String(candidate.get("kind", ""))
		var instance_id: String = String(candidate.get("instance_id", ""))
		if event_id.is_empty() or kind.is_empty() or instance_id.is_empty() or seen.has(event_id):
			continue
		seen[event_id] = true
		unique.append(candidate)
	return {"ok": true, "error": "", "events": unique}

func _semantic_transition_event(event: Dictionary) -> Dictionary:
	var kind: String = String(event.get("kind", ""))
	var instance_id: String = String(event.get("instance_id", ""))
	var event_id: String = String(event.get("event_id", ""))
	if instance_id.is_empty() or event_id.is_empty():
		return {}
	if kind == "STRESS_STATE_TRANSITION":
		var state_before: String = String(event.get("state_before", ""))
		var state_after: String = String(event.get("state_after", ""))
		if state_after == "PANICKED" and state_before != "PANICKED":
			return {"event_id": "%s:t10:panic-entry" % event_id, "kind": "PRIMARY_STATE_ENTERED_PANICKED", "phase": "G", "tick": int(event.get("tick", 0)), "instance_id": instance_id, "parent_event_ids": PackedStringArray([event_id])}
		if state_before == "AGITATED" and state_after == "CALM":
			return {"event_id": "%s:t10:calm-recovery" % event_id, "kind": "PRIMARY_STATE_RECOVERED_CALM", "phase": "G", "tick": int(event.get("tick", 0)), "instance_id": instance_id, "episode_id": "agitated-recovery:%s:%s" % [instance_id, event_id], "parent_event_ids": PackedStringArray([event_id])}
	if kind == "H02_WAKE_REQUEST_APPLIED":
		return {"event_id": "%s:t10:wake" % event_id, "kind": "PRIMARY_STATE_WOKE", "phase": "B", "tick": int(event.get("tick", 0)), "instance_id": instance_id, "episode_id": String(event.get("episode_id", "sleep-wake:%s" % event_id)), "parent_event_ids": PackedStringArray([event_id])}
	return {}
