class_name CriticalSignalPresentationBuilder
extends RefCounted

func build(settings: Object, completed: Dictionary, review: Dictionary, simulation_defs: Dictionary) -> Array:
	var output: Array = []
	if settings == null or completed.is_empty():
		return output
	_append_snapshot_signals(output, settings, completed, simulation_defs)
	_append_growth_signals(output, settings, completed)
	_append_review_signals(output, settings, review)
	_append_completion_signal(output, settings, completed)
	output.sort_custom(_signal_less)
	for index: int in range(output.size()):
		var signal_value: Variant = output[index]
		if signal_value is Dictionary:
			var signal_data: Dictionary = signal_value
			signal_data.erase("_sequence")
			output[index] = signal_data
	return output

func _signal_less(left_value: Variant, right_value: Variant) -> bool:
	if not left_value is Dictionary or not right_value is Dictionary:
		return false
	var left: Dictionary = left_value
	var right: Dictionary = right_value
	var left_tick: int = int(left.get("tick", 0))
	var right_tick: int = int(right.get("tick", 0))
	if left_tick != right_tick:
		return left_tick < right_tick
	return int(left.get("_sequence", 0)) < int(right.get("_sequence", 0))

func _append_snapshot_signals(output: Array, settings: Object, completed: Dictionary, simulation_defs: Dictionary) -> void:
	var snapshots_value: Variant = completed.get("end_tick_snapshots", [])
	if not snapshots_value is Array:
		return
	var snapshots: Array = snapshots_value
	var previous_hazards: Dictionary = {}
	var previous_disabled: Dictionary = {}
	for raw_snapshot: Variant in snapshots:
		if not raw_snapshot is Dictionary:
			continue
		var snapshot: Dictionary = raw_snapshot
		var tick: int = int(snapshot.get("tick", 0))
		var hazard_ids: PackedStringArray = _normalized_string_list(snapshot.get("active_hazards", PackedStringArray()))
		var current_hazards: Dictionary = _string_set(hazard_ids)
		for hazard_id: String in hazard_ids:
			if not previous_hazards.has(hazard_id):
				_append_signal(output, settings, &"hazard_onset", _hazard_source_label(hazard_id, simulation_defs), "route hazard active at tick %d" % tick, _hazard_channel(hazard_id, simulation_defs), tick)
		var ended_hazards: PackedStringArray = PackedStringArray()
		var previous_hazard_keys: Array = previous_hazards.keys()
		for raw_previous_hazard: Variant in previous_hazard_keys:
			var previous_hazard: String = String(raw_previous_hazard)
			if not current_hazards.has(previous_hazard):
				ended_hazards.append(previous_hazard)
		ended_hazards.sort()
		for ended_hazard_id: String in ended_hazards:
			_append_signal(output, settings, &"hazard_end", _hazard_source_label(ended_hazard_id, simulation_defs), "route hazard ended before tick %d" % tick, _hazard_channel(ended_hazard_id, simulation_defs), tick)
		previous_hazards = current_hazards

		var phase_a_value: Variant = snapshot.get("phase_a_power", {})
		if not phase_a_value is Dictionary:
			previous_disabled = {}
			continue
		var phase_a: Dictionary = phase_a_value
		var disabled_ids: PackedStringArray = _normalized_string_list(phase_a.get("disabled_support_ids", PackedStringArray()))
		var current_disabled: Dictionary = _string_set(disabled_ids)
		for support_id: String in disabled_ids:
			if not previous_disabled.has(support_id):
				_append_signal(output, settings, &"brownout_power_loss", support_id, "Brownout disabled support at tick %d (available %d / demand %d)" % [tick, int(phase_a.get("available_power", 0)), int(phase_a.get("total_installed_demand", 0))], &"", tick)
		previous_disabled = current_disabled

func _append_growth_signals(output: Array, settings: Object, completed: Dictionary) -> void:
	var growth_events_value: Variant = completed.get("growth_events", [])
	if not growth_events_value is Array:
		return
	var growth_events: Array = growth_events_value
	for raw_event: Variant in growth_events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		if String(event.get("event_type", "")) != "GROWTH_BLOCKED":
			continue
		var tick: int = int(event.get("tick", 0))
		_append_signal(output, settings, &"blocked_growth", String(event.get("instance_id", "Organism")), "growth blocked episode %d at tick %d" % [int(event.get("episode_index", 0)), tick], &"", tick)

func _append_review_signals(output: Array, settings: Object, review: Dictionary) -> void:
	var events_value: Variant = review.get("events", [])
	if events_value is Array:
		var events: Array = events_value
		for raw_event: Variant in events:
			if not raw_event is Dictionary:
				continue
			var event: Dictionary = raw_event
			if String(event.get("kind", "")) != "ORGANISM_RESPONSE":
				continue
			var before: String = String(event.get("state_before", ""))
			var after: String = String(event.get("state_after", ""))
			if before == after:
				continue
			var tick: int = int(event.get("tick", 0))
			var source: String = String(event.get("instance_id", "Organism"))
			var detail: String = "%s -> %s at tick %d (stress %d -> %d)" % [before, after, tick, int(event.get("stress_before", 0)), int(event.get("stress_after", 0))]
			_append_signal(output, settings, &"state_transition", source, detail, &"stress", tick)
			if after.to_upper().contains("PANIC"):
				_append_signal(output, settings, &"alarm_panic", source, "panic state entered at tick %d" % tick, &"stress", tick)

	var objectives_value: Variant = review.get("objective_events", [])
	if not objectives_value is Array:
		return
	var objectives: Array = objectives_value
	for raw_objective: Variant in objectives:
		if not raw_objective is Dictionary:
			continue
		var objective: Dictionary = raw_objective
		if bool(objective.get("passed", false)):
			continue
		var tick: int = int(objective.get("tick", 0))
		var detail: String = "%s failed at tick %d - required %s, observed %s" % [String(objective.get("predicate_id", "mandatory")), tick, str(objective.get("required", null)), str(objective.get("observed", null))]
		_append_signal(output, settings, &"predicate_failure", String(objective.get("instance_id", "Objective")), detail, &"", tick)

func _append_completion_signal(output: Array, settings: Object, completed: Dictionary) -> void:
	if not bool(completed.get("completed", false)):
		return
	var tick: int = int(completed.get("final_tick", 0))
	var delivery_value: Variant = completed.get("delivery_result", {})
	var success: bool = false
	if delivery_value is Dictionary:
		var delivery: Dictionary = delivery_value
		success = bool(delivery.get("success", false))
	var outcome: String = "SUCCESS" if success else "FAILURE"
	_append_signal(output, settings, &"transit_completion", "Transit", "tick %d - %s; Causal Review ready" % [tick, outcome], &"", tick)

func _append_signal(output: Array, settings: Object, kind: StringName, source: String, detail: String, channel: StringName, tick: int) -> void:
	if settings == null or not settings.has_method("critical_signal"):
		return
	var signal_value: Variant = settings.call("critical_signal", kind, source, detail, channel)
	if not signal_value is Dictionary:
		return
	var signal_data: Dictionary = signal_value
	if not bool(signal_data.get("ok", false)):
		return
	signal_data["tick"] = tick
	signal_data["_sequence"] = output.size()
	output.append(signal_data)

func _hazard_source_label(hazard_id: String, simulation_defs: Dictionary) -> String:
	var hazards_value: Variant = simulation_defs.get("hazards_by_id", {})
	if hazards_value is Dictionary:
		var hazards: Dictionary = hazards_value
		var hazard_value: Variant = hazards.get(hazard_id, {})
		if hazard_value is Dictionary:
			var hazard: Dictionary = hazard_value
			var authored_name: String = String(hazard.get("name", "")).strip_edges()
			if not authored_name.is_empty():
				return "%s (%s)" % [authored_name, hazard_id]
	return hazard_id

func _hazard_channel(hazard_id: String, simulation_defs: Dictionary) -> StringName:
	var hazards_value: Variant = simulation_defs.get("hazards_by_id", {})
	if not hazards_value is Dictionary:
		return &""
	var hazards: Dictionary = hazards_value
	var hazard_value: Variant = hazards.get(hazard_id, {})
	if not hazard_value is Dictionary:
		return &""
	var hazard: Dictionary = hazard_value
	var family: String = String(hazard.get("family", "")).to_upper()
	if hazard.has("heat_delta") or hazard.has("heat_delta_by_cell") or family == "H01":
		return &"heat"
	if hazard.has("contamination_delta") or hazard.has("contamination_by_cell") or family == "H03":
		return &"contamination"
	if hazard.has("stress_delta") or family == "H02":
		return &"stress"
	return &""

func _normalized_string_list(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed_values: PackedStringArray = value
		for item: String in packed_values:
			result.append(item)
	elif value is Array:
		var array_values: Array = value
		for raw_item: Variant in array_values:
			result.append(String(raw_item))
	result.sort()
	return result

func _string_set(values: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for value: String in values:
		result[value] = true
	return result
