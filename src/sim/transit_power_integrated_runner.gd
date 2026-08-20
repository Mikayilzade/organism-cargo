class_name TransitPowerIntegratedRunner
extends RefCounted

const TransitSliceRunnerScript := preload("res://src/sim/transit_slice_runner.gd")
const PhaseAPowerResolverScript := preload("res://src/sim/phase_a_power_resolver.gd")

const POWERED_SUPPORT_FAMILIES: PackedStringArray = PackedStringArray(["S01", "S02", "S06"])

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	if not committed_run.has("canonical_committed_input") or not committed_run["canonical_committed_input"] is Dictionary:
		return {"ok": false, "error": "missing_committed_input"}
	var committed_input: Dictionary = committed_run["canonical_committed_input"]
	var prepare_power: Dictionary = _prepare_power_authority(committed_input, simulation_defs)
	if not bool(prepare_power["ok"]):
		return {"ok": false, "error": String(prepare_power["error"])}

	var base_run: Dictionary = committed_run.duplicate(true)
	var base_input: Dictionary = committed_input.duplicate(true)
	base_input["supports"] = []
	base_run["canonical_committed_input"] = base_input
	var base_defs: Dictionary = _defs_without_h04(simulation_defs)
	var base_runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var result: Dictionary = base_runner.simulate(base_run, total_ticks, base_defs)
	if not bool(result.get("ok", false)):
		return result

	var route_profile: Dictionary = prepare_power["route_profile"]
	var hazards_by_id: Dictionary = prepare_power["hazards_by_id"]
	var installed_supports: Array = prepare_power["installed_supports"]
	var priority_order: Array = prepare_power["priority_order"]
	var base_power_capacity: int = int(prepare_power["base_power_capacity"])
	var power_resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var previous_powered_by_id: Dictionary = {}
	var all_power_events: Array = []
	var snapshots: Array = result.get("end_tick_snapshots", [])
	var checksums: PackedStringArray = result.get("tick_checksums", PackedStringArray())
	if snapshots.size() != total_ticks or checksums.size() != total_ticks:
		return {"ok": false, "error": "invalid_base_transit_shape"}

	for tick: int in range(1, total_ticks + 1):
		var active_hazards: PackedStringArray = _active_route_hazards(tick, route_profile)
		var available_result: Dictionary = _available_power_for_tick(base_power_capacity, active_hazards, hazards_by_id)
		if not bool(available_result["ok"]):
			return {"ok": false, "error": "phase_a:%s" % String(available_result["error"])}
		var resolved: Dictionary = power_resolver.resolve(
			int(available_result["available_power"]),
			installed_supports,
			priority_order,
			previous_powered_by_id
		)
		if not bool(resolved["ok"]):
			return {"ok": false, "error": "phase_a:%s" % String(resolved["error"])}

		var tick_events: Array = []
		for raw_event: Variant in resolved["events"]:
			if raw_event is Dictionary:
				var event: Dictionary = raw_event
				var with_tick: Dictionary = event.duplicate(true)
				with_tick["tick"] = tick
				tick_events.append(with_tick)
				all_power_events.append(with_tick)

		var snapshot_value: Variant = snapshots[tick - 1]
		if not snapshot_value is Dictionary:
			return {"ok": false, "error": "invalid_base_snapshot"}
		var snapshot: Dictionary = snapshot_value
		snapshot["active_hazards"] = active_hazards
		snapshot["phase_a_power"] = _power_snapshot(resolved)
		snapshot["support_power_events"] = tick_events
		snapshot["same_tick_effect_eligible_support_ids"] = resolved["same_tick_effect_eligible_support_ids"]
		snapshots[tick - 1] = snapshot

		checksums[tick - 1] = (String(checksums[tick - 1]) + "|active=" + ",".join(active_hazards) + "|" + String(resolved["authority_payload"])).sha256_text()
		previous_powered_by_id = resolved["powered_by_id"].duplicate(true)

	result["end_tick_snapshots"] = snapshots
	result["tick_checksums"] = checksums
	result["support_power_events"] = all_power_events
	result["final_support_powered_by_id"] = previous_powered_by_id
	return result

func _prepare_power_authority(committed_input: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var supports_value: Variant = committed_input.get("supports", [])
	if not supports_value is Array:
		return _failure("invalid_committed_supports")
	var committed_supports: Array = supports_value
	var priority_value: Variant = committed_input.get("brownout_priority", [])
	if not priority_value is Array:
		return _failure("invalid_brownout_priority")
	var priority_order: Array = priority_value

	if not simulation_defs.has("route_profile") or not simulation_defs["route_profile"] is Dictionary:
		return _failure("missing_route_profile")
	if not simulation_defs.has("hold_definition") or not simulation_defs["hold_definition"] is Dictionary:
		return _failure("missing_hold_definition")
	if not simulation_defs.has("hazards_by_id") or not simulation_defs["hazards_by_id"] is Dictionary:
		return _failure("missing_hazard_definitions")
	var route_profile: Dictionary = simulation_defs["route_profile"]
	var hold_definition: Dictionary = simulation_defs["hold_definition"]
	var hazards_by_id: Dictionary = simulation_defs["hazards_by_id"]
	var base_power_capacity: int = int(hold_definition.get("power_capacity", 0))
	if base_power_capacity < 0:
		return _failure("invalid_hold_power_capacity")

	var support_defs_value: Variant = simulation_defs.get("support_definitions_by_id", {})
	if not support_defs_value is Dictionary:
		return _failure("invalid_support_definitions")
	var support_definitions: Dictionary = support_defs_value
	var installed_supports: Array = []
	var seen_instances: Dictionary = {}
	for raw_support: Variant in committed_supports:
		if not raw_support is Dictionary:
			return _failure("invalid_committed_support")
		var committed_support: Dictionary = raw_support
		var instance_id: String = String(committed_support.get("instance_id", ""))
		var support_id: String = String(committed_support.get("support_id", ""))
		if instance_id.is_empty() or support_id.is_empty():
			return _failure("invalid_committed_support_identity")
		if seen_instances.has(instance_id):
			return _failure("duplicate_support_instance_id:%s" % instance_id)
		seen_instances[instance_id] = true
		if not support_definitions.has(support_id) or not support_definitions[support_id] is Dictionary:
			return _failure("missing_support_definition:%s" % support_id)
		var definition: Dictionary = support_definitions[support_id]
		var family: String = String(definition.get("family", support_id))
		if family not in POWERED_SUPPORT_FAMILIES:
			return _failure("transit_nonpowered_support_not_implemented:%s" % family)
		if not bool(definition.get("powered", false)):
			return _failure("powered_support_definition_required:%s" % support_id)
		var power_draw: int = int(definition.get("power_draw", -1))
		if power_draw <= 0:
			return _failure("invalid_support_power_draw:%s" % support_id)
		installed_supports.append({
			"instance_id": instance_id,
			"powered": true,
			"power_draw": power_draw,
			"supports_degraded_operation": bool(definition.get("supports_degraded_operation", false)),
		})

	return {
		"ok": true,
		"error": "",
		"route_profile": route_profile,
		"hazards_by_id": hazards_by_id,
		"base_power_capacity": base_power_capacity,
		"installed_supports": installed_supports,
		"priority_order": priority_order.duplicate(true),
	}

func _defs_without_h04(simulation_defs: Dictionary) -> Dictionary:
	var stripped: Dictionary = simulation_defs.duplicate(true)
	var route_value: Variant = stripped.get("route_profile", {})
	if route_value is Dictionary:
		var route_profile: Dictionary = route_value
		var retained_events: Array = []
		for raw_event: Variant in route_profile.get("events", []):
			if raw_event is Dictionary:
				var event: Dictionary = raw_event
				var hazard_id: String = String(event.get("hazard_id", ""))
				var hazards_value: Variant = simulation_defs.get("hazards_by_id", {})
				if hazards_value is Dictionary:
					var hazards: Dictionary = hazards_value
					var hazard_value: Variant = hazards.get(hazard_id, {})
					if hazard_value is Dictionary:
						var hazard: Dictionary = hazard_value
						if String(hazard.get("family", "")) == "H04":
							continue
			retained_events.append(event.duplicate(true))
		route_profile["events"] = retained_events
		stripped["route_profile"] = route_profile

	var hazards_value: Variant = stripped.get("hazards_by_id", {})
	if hazards_value is Dictionary:
		var hazards: Dictionary = hazards_value
		var retained_hazards: Dictionary = {}
		for raw_id: Variant in hazards.keys():
			var hazard_id: String = String(raw_id)
			var hazard_value: Variant = hazards[raw_id]
			if hazard_value is Dictionary:
				var hazard: Dictionary = hazard_value
				if String(hazard.get("family", "")) == "H04":
					continue
			retained_hazards[hazard_id] = hazard.duplicate(true)
		stripped["hazards_by_id"] = retained_hazards
	stripped.erase("support_definitions_by_id")
	return stripped

func _active_route_hazards(tick: int, route_profile: Dictionary) -> PackedStringArray:
	var active_events: Array = []
	for raw_event: Variant in route_profile.get("events", []):
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
	var ids: PackedStringArray = PackedStringArray()
	for event: Dictionary in active_events:
		ids.append(String(event.get("hazard_id", "")))
	return ids

func _available_power_for_tick(base_capacity: int, active_hazards: PackedStringArray, hazards_by_id: Dictionary) -> Dictionary:
	var reduction: int = 0
	for hazard_id: String in active_hazards:
		if not hazards_by_id.has(hazard_id) or not hazards_by_id[hazard_id] is Dictionary:
			return _failure("missing_hazard:%s" % hazard_id)
		var hazard: Dictionary = hazards_by_id[hazard_id]
		if String(hazard.get("family", "")) != "H04":
			continue
		if String(hazard.get("target_scope", "hold")) != "hold":
			return _failure("h04_scope_not_implemented")
		var power_reduction: int = int(hazard.get("power_reduction", -1))
		if power_reduction < 0:
			return _failure("missing_h04_power_reduction")
		reduction += power_reduction
	return {"ok": true, "error": "", "available_power": maxi(0, base_capacity - reduction)}

func _power_snapshot(resolved: Dictionary) -> Dictionary:
	return {
		"available_power": int(resolved["available_power"]),
		"used_power": int(resolved["used_power"]),
		"remaining_power": int(resolved["remaining_power"]),
		"total_installed_demand": int(resolved["total_installed_demand"]),
		"brownout_active": bool(resolved["brownout_active"]),
		"powered_support_ids": resolved["powered_support_ids"].duplicate(),
		"disabled_support_ids": resolved["disabled_support_ids"].duplicate(),
		"powered_by_id": resolved["powered_by_id"].duplicate(true),
		"authority_checksum": String(resolved["authority_checksum"]),
	}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
