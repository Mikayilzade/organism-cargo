extends "res://src/sim/transit_monitor_integrated_runner.gd"

const StressFieldEnvironmentKernelScript := preload("res://src/sim/stress_field_environment_kernel.gd")
const TransitSliceRunnerScript := preload("res://src/sim/transit_slice_runner.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var has_h02: bool = _has_h02(simulation_defs)
	var base_defs: Dictionary = _defs_without_h02(simulation_defs) if has_h02 else simulation_defs
	var base_result: Dictionary = super.simulate(committed_run, total_ticks, base_defs)
	if not bool(base_result.get("ok", false)):
		return base_result
	if not has_h02:
		return base_result

	var rules_value: Variant = simulation_defs.get("stress_field_rules", null)
	if not rules_value is Dictionary:
		return {"ok": false, "error": "missing_stress_field_rules"}
	var stress_field_rules: Dictionary = rules_value
	var hold_value: Variant = simulation_defs.get("hold_definition", null)
	if not hold_value is Dictionary:
		return {"ok": false, "error": "missing_hold_definition"}
	var hold_definition: Dictionary = hold_value
	var cell_order_result: Dictionary = TransitSliceRunnerScript.new()._build_cell_order(hold_definition)
	if not bool(cell_order_result.get("ok", false)):
		return {"ok": false, "error": "stress_field:%s" % String(cell_order_result.get("error", "invalid_hold"))}
	var cell_order: PackedStringArray = cell_order_result["cell_order"]
	var route_value: Variant = simulation_defs.get("route_profile", null)
	var hazards_value: Variant = simulation_defs.get("hazards_by_id", null)
	if not route_value is Dictionary or not hazards_value is Dictionary:
		return {"ok": false, "error": "missing_stress_field_route_authority"}
	var route_profile: Dictionary = route_value
	var hazards_by_id: Dictionary = hazards_value

	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	if not snapshots_value is Array:
		return {"ok": false, "error": "invalid_end_tick_snapshots"}
	var snapshots: Array = snapshots_value
	var checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return {"ok": false, "error": "invalid_base_tick_checksums"}
	var base_checksums: Array = []
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return {"ok": false, "error": "base_tick_checksum_count_mismatch"}

	var field: Dictionary = {}
	for cell_key: String in cell_order:
		field[cell_key] = 0
	var kernel: StressFieldEnvironmentKernel = StressFieldEnvironmentKernelScript.new()
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_source_events: Array = []

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return {"ok": false, "error": "invalid_end_tick_snapshot"}
		var snapshot_source: Dictionary = raw_snapshot
		var snapshot: Dictionary = snapshot_source.duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var active_all: PackedStringArray = _active_hazards_for_tick(tick, route_profile)
		var active_h02: PackedStringArray = PackedStringArray()
		for hazard_id: String in active_all:
			if hazards_by_id.has(hazard_id) and hazards_by_id[hazard_id] is Dictionary:
				var hazard: Dictionary = hazards_by_id[hazard_id]
				if String(hazard.get("family", "")) == "H02":
					active_h02.append(hazard_id)

		var phase_c: Dictionary = kernel.apply_h02_phase_c(field, cell_order, active_h02, hazards_by_id)
		if not bool(phase_c.get("ok", false)):
			return {"ok": false, "error": "phase_c_stress_field:%s" % String(phase_c.get("error", "unknown"))}
		var phase_d: Dictionary = kernel.propagate_phase_d(phase_c["stress_field_by_cell"], cell_order, stress_field_rules)
		if not bool(phase_d.get("ok", false)):
			return {"ok": false, "error": "phase_d_stress_field:%s" % String(phase_d.get("error", "unknown"))}
		field = phase_d["stress_field_by_cell"]

		var tick_events: Array = []
		var events_value: Variant = phase_c.get("events", [])
		if not events_value is Array:
			return {"ok": false, "error": "invalid_stress_field_source_events"}
		for raw_event: Variant in events_value:
			if not raw_event is Dictionary:
				return {"ok": false, "error": "invalid_stress_field_source_event"}
			var event: Dictionary = raw_event
			var with_tick: Dictionary = event.duplicate(true)
			with_tick["tick"] = tick
			tick_events.append(with_tick)
			all_source_events.append(with_tick.duplicate(true))

		snapshot["active_hazards"] = active_all
		snapshot["stress_field_source_events"] = tick_events.duplicate(true)
		snapshot["stress_field_by_cell"] = _ordered_field(field, cell_order)
		integrated_snapshots.append(snapshot)
		var checksum_material: String = String(base_checksums[index]) + "|stress_field=" + _serialize_field(field, cell_order) + "|h02=" + _serialize_events(tick_events)
		integrated_checksums.append(checksum_material.sha256_text())

	base_result["end_tick_snapshots"] = integrated_snapshots
	base_result["tick_checksums"] = integrated_checksums
	base_result["stress_field_source_events"] = all_source_events
	base_result["final_stress_field_by_cell"] = _ordered_field(field, cell_order)
	return base_result

func _has_h02(simulation_defs: Dictionary) -> bool:
	var hazards_value: Variant = simulation_defs.get("hazards_by_id", {})
	if not hazards_value is Dictionary:
		return false
	var hazards: Dictionary = hazards_value
	for raw_hazard: Variant in hazards.values():
		if raw_hazard is Dictionary:
			var hazard: Dictionary = raw_hazard
			if String(hazard.get("family", "")) == "H02":
				return true
	return false

func _defs_without_h02(simulation_defs: Dictionary) -> Dictionary:
	var stripped: Dictionary = simulation_defs.duplicate(true)
	var hazards_value: Variant = stripped.get("hazards_by_id", {})
	var retained_hazards: Dictionary = {}
	if hazards_value is Dictionary:
		var hazards: Dictionary = hazards_value
		for raw_id: Variant in hazards.keys():
			var hazard_id: String = String(raw_id)
			var hazard_value: Variant = hazards[raw_id]
			if not hazard_value is Dictionary:
				continue
			var hazard: Dictionary = hazard_value
			if String(hazard.get("family", "")) == "H02":
				continue
			retained_hazards[hazard_id] = hazard.duplicate(true)
	stripped["hazards_by_id"] = retained_hazards
	var route_value: Variant = stripped.get("route_profile", {})
	if route_value is Dictionary:
		var route: Dictionary = route_value
		var retained_events: Array = []
		var events_value: Variant = route.get("events", [])
		if events_value is Array:
			for raw_event: Variant in events_value:
				if not raw_event is Dictionary:
					continue
				var route_event: Dictionary = raw_event
				var hazard_id: String = String(route_event.get("hazard_id", ""))
				if retained_hazards.has(hazard_id):
					retained_events.append(route_event.duplicate(true))
		route["events"] = retained_events
		stripped["route_profile"] = route
	stripped.erase("stress_field_rules")
	return stripped

func _active_hazards_for_tick(tick: int, route_profile: Dictionary) -> PackedStringArray:
	var active_events: Array = []
	var events_value: Variant = route_profile.get("events", [])
	if events_value is Array:
		for raw_event: Variant in events_value:
			if not raw_event is Dictionary:
				continue
			var event: Dictionary = raw_event
			var start_tick: int = int(event.get("tick", 0))
			var duration_ticks: int = int(event.get("duration_ticks", 0))
			if tick >= start_tick and tick < start_tick + duration_ticks:
				active_events.append(event)
	active_events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_order: int = int(left.get("authored_order", 0))
		var right_order: int = int(right.get("authored_order", 0))
		if left_order != right_order:
			return left_order < right_order
		return String(left.get("hazard_id", "")) < String(right.get("hazard_id", ""))
	)
	var result: PackedStringArray = PackedStringArray()
	for event: Dictionary in active_events:
		result.append(String(event.get("hazard_id", "")))
	return result

func _ordered_field(field: Dictionary, cell_order: PackedStringArray) -> Dictionary:
	var ordered: Dictionary = {}
	for cell_key: String in cell_order:
		ordered[cell_key] = int(field.get(cell_key, 0))
	return ordered

func _serialize_field(field: Dictionary, cell_order: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for cell_key: String in cell_order:
		parts.append("%s:%d" % [cell_key, int(field.get(cell_key, 0))])
	return ",".join(parts)

func _serialize_events(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_event: Variant in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		parts.append("%s:%s:%s:%d:%d" % [
			String(event.get("kind", "")),
			String(event.get("hazard_id", "")),
			String(event.get("cell_key", "")),
			int(event.get("stress_field_delta", 0)),
			int(event.get("stress_field_after", 0)),
		])
	return ";".join(parts)
