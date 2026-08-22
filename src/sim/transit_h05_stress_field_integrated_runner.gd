extends "res://src/sim/transit_stress_field_integrated_runner.gd"

const PhaseDEnvironmentResolverScript := preload("res://src/sim/phase_d_environment_resolver.gd")
const H05S03BaffleKernelScript := preload("res://src/sim/s03_baffle_kernel.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	if not _has_relevant_h05_stress_route_event(simulation_defs, total_ticks):
		return super.simulate(committed_run, total_ticks, simulation_defs)
	if not _has_h02(simulation_defs):
		return {"ok": false, "error": "h05_channel_not_enabled:stress_field"}

	var base_result: Dictionary = super.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(base_result.get("ok", false)):
		return base_result
	var rules_value: Variant = simulation_defs.get("stress_field_rules", null)
	var hold_value: Variant = simulation_defs.get("hold_definition", null)
	var route_value: Variant = simulation_defs.get("route_profile", null)
	var hazards_value: Variant = simulation_defs.get("hazards_by_id", null)
	if not rules_value is Dictionary:
		return {"ok": false, "error": "missing_stress_field_rules"}
	if not hold_value is Dictionary:
		return {"ok": false, "error": "missing_hold_definition"}
	if not route_value is Dictionary or not hazards_value is Dictionary:
		return {"ok": false, "error": "missing_stress_field_route_authority"}
	var stress_field_rules: Dictionary = rules_value
	var hold_definition: Dictionary = hold_value
	var route_profile: Dictionary = route_value
	var hazards_by_id: Dictionary = hazards_value
	var cell_order_result: Dictionary = TransitSliceRunnerScript.new()._build_cell_order(hold_definition)
	if not bool(cell_order_result.get("ok", false)):
		return {"ok": false, "error": "stress_field:%s" % String(cell_order_result.get("error", "invalid_hold"))}
	var cell_order: PackedStringArray = cell_order_result["cell_order"]

	var phase_d_rules: Dictionary = stress_field_rules.duplicate(true)
	var boundaries_value: Variant = base_result.get("s03_support_boundaries", [])
	if not boundaries_value is Array:
		return {"ok": false, "error": "invalid_s03_support_boundaries"}
	var boundaries: Array = boundaries_value
	if not boundaries.is_empty():
		var transformed: Dictionary = H05S03BaffleKernelScript.new().apply_phase_d_transmission(stress_field_rules, boundaries)
		if not bool(transformed.get("ok", false)):
			return {"ok": false, "error": "phase_d_s03:%s" % String(transformed.get("error", "unknown"))}
		var transformed_rules_value: Variant = transformed.get("rules", null)
		if not transformed_rules_value is Dictionary:
			return {"ok": false, "error": "invalid_s03_phase_d_rules"}
		phase_d_rules = (transformed_rules_value as Dictionary).duplicate(true)

	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	var checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not snapshots_value is Array:
		return {"ok": false, "error": "invalid_end_tick_snapshots"}
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return {"ok": false, "error": "invalid_base_tick_checksums"}
	var snapshots: Array = snapshots_value
	var base_checksums: Array = []
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return {"ok": false, "error": "base_tick_checksum_count_mismatch"}

	var field: Dictionary = {}
	for cell_key: String in cell_order:
		field[cell_key] = 0
	var stress_kernel: StressFieldEnvironmentKernel = StressFieldEnvironmentKernelScript.new()
	var phase_d_resolver: PhaseDEnvironmentResolver = PhaseDEnvironmentResolverScript.new()
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_source_events: Array = []
	var all_h05_events: Array = []
	var prior_h05_events_value: Variant = base_result.get("h05_vent_events", [])
	if prior_h05_events_value is Array:
		for raw_prior_event: Variant in prior_h05_events_value:
			if raw_prior_event is Dictionary:
				all_h05_events.append((raw_prior_event as Dictionary).duplicate(true))

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return {"ok": false, "error": "invalid_end_tick_snapshot"}
		var source_snapshot: Dictionary = raw_snapshot
		var snapshot: Dictionary = source_snapshot.duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var active_all: PackedStringArray = _active_hazards_for_tick(tick, route_profile)
		var active_h02: PackedStringArray = PackedStringArray()
		for hazard_id: String in active_all:
			if hazards_by_id.has(hazard_id) and hazards_by_id[hazard_id] is Dictionary:
				var hazard: Dictionary = hazards_by_id[hazard_id]
				if String(hazard.get("family", "")) == "H02":
					active_h02.append(hazard_id)

		var phase_c: Dictionary = stress_kernel.apply_h02_phase_c(field, cell_order, active_h02, hazards_by_id)
		if not bool(phase_c.get("ok", false)):
			return {"ok": false, "error": "phase_c_stress_field:%s" % String(phase_c.get("error", "unknown"))}
		var scoped_h05: Dictionary = _scoped_h05_stress_authority(active_all, hazards_by_id)
		if not bool(scoped_h05.get("ok", false)):
			return scoped_h05
		var generated: Dictionary = {"stress_field": phase_c["stress_field_by_cell"]}
		var phase_d: Dictionary = phase_d_resolver.resolve_phase_d(
			tick,
			cell_order,
			scoped_h05["active_hazards"],
			scoped_h05["hazards_by_id"],
			generated,
			{"stress_field": phase_d_rules}
		)
		if not bool(phase_d.get("ok", false)):
			return {"ok": false, "error": "phase_d_stress_field:%s" % String(phase_d.get("error", "unknown"))}
		field = (phase_d["environment_by_channel"] as Dictionary)["stress_field"]

		var tick_source_events: Array = []
		var source_events_value: Variant = phase_c.get("events", [])
		if not source_events_value is Array:
			return {"ok": false, "error": "invalid_stress_field_source_events"}
		for raw_source_event: Variant in source_events_value:
			if not raw_source_event is Dictionary:
				return {"ok": false, "error": "invalid_stress_field_source_event"}
			var source_event: Dictionary = raw_source_event
			var with_tick: Dictionary = source_event.duplicate(true)
			with_tick["tick"] = tick
			tick_source_events.append(with_tick)
			all_source_events.append(with_tick.duplicate(true))

		var tick_h05_events: Array = (phase_d["h05_events"] as Array).duplicate(true)
		for raw_h05_event: Variant in tick_h05_events:
			if raw_h05_event is Dictionary:
				all_h05_events.append((raw_h05_event as Dictionary).duplicate(true))
		var old_field_value: Variant = source_snapshot.get("stress_field_by_cell", {})
		var old_field: Dictionary = old_field_value if old_field_value is Dictionary else {}
		var field_changed: bool = old_field != field
		snapshot["stress_field_by_cell"] = _ordered_h05_stress_field(field, cell_order)
		snapshot["stress_field_source_events"] = tick_source_events.duplicate(true)
		if not tick_h05_events.is_empty():
			var merged_h05_events: Array = []
			var existing_h05_value: Variant = snapshot.get("h05_vent_events", [])
			if existing_h05_value is Array:
				for raw_existing: Variant in existing_h05_value:
					if raw_existing is Dictionary:
						merged_h05_events.append((raw_existing as Dictionary).duplicate(true))
			for raw_new: Variant in tick_h05_events:
				if raw_new is Dictionary:
					merged_h05_events.append((raw_new as Dictionary).duplicate(true))
			merged_h05_events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return String(left.get("event_id", "")) < String(right.get("event_id", ""))
			)
			snapshot["h05_vent_events"] = merged_h05_events
			var merged_effective: Dictionary = {}
			var existing_effective_value: Variant = snapshot.get("phase_d_effective_vent_by_channel", {})
			if existing_effective_value is Dictionary:
				merged_effective = (existing_effective_value as Dictionary).duplicate(true)
			var phase_d_effective: Dictionary = phase_d["effective_vent_by_channel"]
			merged_effective["stress_field"] = (phase_d_effective["stress_field"] as Dictionary).duplicate(true)
			snapshot["phase_d_effective_vent_by_channel"] = merged_effective
			snapshot["phase_d_stress_authority_payload"] = String(phase_d["authority_payload"])
			snapshot["phase_d_stress_authority_checksum"] = String(phase_d["authority_checksum"])
		integrated_snapshots.append(snapshot)

		var checksum_material: String = String(base_checksums[index])
		if field_changed or not tick_h05_events.is_empty():
			checksum_material += "|h05_stress_field=" + _serialize_h05_stress_field(field, cell_order)
			checksum_material += "|h05_stress_phase_d=" + String(phase_d["authority_payload"])
			checksum_material += "|h05_stress_source=" + _serialize_h05_stress_events(tick_source_events)
			integrated_checksums.append(checksum_material.sha256_text())
		else:
			integrated_checksums.append(checksum_material)

	base_result["end_tick_snapshots"] = integrated_snapshots
	base_result["tick_checksums"] = integrated_checksums
	base_result["stress_field_source_events"] = all_source_events
	base_result["h05_vent_events"] = all_h05_events
	base_result["final_stress_field_by_cell"] = _ordered_h05_stress_field(field, cell_order)
	return base_result

func _has_relevant_h05_stress_route_event(simulation_defs: Dictionary, total_ticks: int) -> bool:
	var route_value: Variant = simulation_defs.get("route_profile", {})
	var hazards_value: Variant = simulation_defs.get("hazards_by_id", {})
	if not route_value is Dictionary or not hazards_value is Dictionary:
		return false
	var route_profile: Dictionary = route_value
	var hazards: Dictionary = hazards_value
	for raw_event: Variant in route_profile.get("events", []):
		if not raw_event is Dictionary:
			continue
		var route_event: Dictionary = raw_event
		var start_tick: int = int(route_event.get("tick", 0))
		var duration_ticks: int = int(route_event.get("duration_ticks", 0))
		if duration_ticks <= 0 or start_tick > total_ticks or start_tick + duration_ticks <= 1:
			continue
		var hazard_id: String = String(route_event.get("hazard_id", ""))
		var hazard_value: Variant = hazards.get(hazard_id, null)
		if not hazard_value is Dictionary:
			continue
		var hazard: Dictionary = hazard_value
		if String(hazard.get("family", "")) != "H05":
			continue
		var delta_value: Variant = hazard.get("vent_delta_by_channel", {})
		if delta_value is Dictionary and (delta_value as Dictionary).has("stress_field"):
			return true
	return false

func _scoped_h05_stress_authority(active_hazards: PackedStringArray, hazards_by_id: Dictionary) -> Dictionary:
	var scoped_active: PackedStringArray = PackedStringArray()
	var scoped_hazards: Dictionary = {}
	for hazard_id: String in active_hazards:
		if not hazards_by_id.has(hazard_id) or not hazards_by_id[hazard_id] is Dictionary:
			return {"ok": false, "error": "missing_hazard_definition:%s" % hazard_id}
		var hazard: Dictionary = hazards_by_id[hazard_id]
		if String(hazard.get("family", "")) != "H05":
			continue
		var delta_value: Variant = hazard.get("vent_delta_by_channel", null)
		if not delta_value is Dictionary:
			return {"ok": false, "error": "invalid_h05_vent_delta_by_channel:%s" % hazard_id}
		var delta_by_channel: Dictionary = delta_value
		if not delta_by_channel.has("stress_field"):
			continue
		var stress_delta_value: Variant = delta_by_channel["stress_field"]
		if not stress_delta_value is Dictionary:
			return {"ok": false, "error": "invalid_h05_cell_deltas:%s:stress_field" % hazard_id}
		var scoped_hazard: Dictionary = hazard.duplicate(true)
		scoped_hazard["vent_delta_by_channel"] = {"stress_field": (stress_delta_value as Dictionary).duplicate(true)}
		scoped_active.append(hazard_id)
		scoped_hazards[hazard_id] = scoped_hazard
	scoped_active.sort()
	return {"ok": true, "error": "", "active_hazards": scoped_active, "hazards_by_id": scoped_hazards}

func _ordered_h05_stress_field(field: Dictionary, cell_order: PackedStringArray) -> Dictionary:
	var ordered: Dictionary = {}
	for cell_key: String in cell_order:
		ordered[cell_key] = int(field.get(cell_key, 0))
	return ordered

func _serialize_h05_stress_field(field: Dictionary, cell_order: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for cell_key: String in cell_order:
		parts.append("%s:%d" % [cell_key, int(field.get(cell_key, 0))])
	return ",".join(parts)

func _serialize_h05_stress_events(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			parts.append("%s:%s:%d" % [
				String(event.get("event_id", "")),
				String(event.get("cell_key", "")),
				int(event.get("stress_field_delta", event.get("stress_delta", 0))),
			])
	return ";".join(parts)
