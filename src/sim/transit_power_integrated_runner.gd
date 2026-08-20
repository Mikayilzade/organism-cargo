class_name TransitPowerIntegratedRunner
extends RefCounted

const TransitSliceRunnerScript := preload("res://src/sim/transit_slice_runner.gd")
const PhaseAPowerResolverScript := preload("res://src/sim/phase_a_power_resolver.gd")
const ThermalResponseKernelScript := preload("res://src/sim/thermal_response_kernel.gd")
const PhaseBGrowthResolverScript := preload("res://src/sim/phase_b_growth_resolver.gd")
const T08GrowthQualifierScript := preload("res://src/sim/t08_growth_qualifier.gd")
const S01CoolerKernelScript := preload("res://src/sim/s01_cooler_kernel.gd")
const S02FilterKernelScript := preload("res://src/sim/s02_filter_kernel.gd")
const ContaminationEnvironmentKernelScript := preload("res://src/sim/contamination_environment_kernel.gd")

const POWERED_SUPPORT_FAMILIES := ["S01", "S02", "S06"]

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	if total_ticks <= 0:
		return {"ok": false, "error": "invalid_total_ticks"}
	if not committed_run.has("canonical_committed_input") or not committed_run["canonical_committed_input"] is Dictionary:
		return {"ok": false, "error": "missing_committed_input"}
	var committed_input: Dictionary = committed_run["canonical_committed_input"]
	var canonical_placements_runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var canonical_placements: PackedStringArray = canonical_placements_runner._canonical_placements(committed_input)
	if canonical_placements.is_empty():
		return {"ok": false, "error": "missing_placements"}

	var prepare_power: Dictionary = _prepare_power_authority(committed_input, simulation_defs)
	if not bool(prepare_power["ok"]):
		return {"ok": false, "error": String(prepare_power["error"])}

	var base_input: Dictionary = committed_input.duplicate(true)
	base_input["supports"] = []
	var base_defs: Dictionary = _defs_without_integrated_hazards(simulation_defs)
	var base_runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var prepared: Dictionary = base_runner._prepare_definitions(base_input, total_ticks, base_defs)
	if not bool(prepared["ok"]):
		return {"ok": false, "error": String(prepared["error"])}

	var route_events: Array = prepared["route_events"]
	var base_hazards_by_id: Dictionary = prepared["hazards_by_id"]
	var cell_order: PackedStringArray = prepared["cell_order"]
	var environment_state: Dictionary = prepared["initial_environment"]
	var thermal_enabled: bool = bool(prepared["thermal_enabled"])
	var thermal_rules: Dictionary = prepared["thermal_rules"]
	var organism_state: Array = prepared["organisms"]
	var growth_requests_by_tick: Dictionary = prepared["growth_requests_by_tick"]
	var t08_trigger_definitions: Array = prepared["t08_trigger_definitions"]
	var t08_qualification_by_tick: Dictionary = prepared["t08_qualification_by_tick"]
	var t08_qualification_state: Dictionary = {}

	var route_profile: Dictionary = prepare_power["route_profile"]
	var all_hazards_by_id: Dictionary = prepare_power["hazards_by_id"]
	var installed_supports: Array = prepare_power["installed_supports"]
	var priority_order: Array = prepare_power["priority_order"]
	var base_power_capacity: int = int(prepare_power["base_power_capacity"])
	var committed_supports: Array = prepare_power["committed_supports"]
	var support_definitions_by_id: Dictionary = prepare_power["support_definitions_by_id"]
	var has_s01: bool = bool(prepare_power["has_s01"])
	var has_s02: bool = bool(prepare_power["has_s02"])
	var contamination_enabled: bool = bool(prepare_power["contamination_enabled"])
	var contamination_rules: Dictionary = prepare_power["contamination_rules"]
	if contamination_enabled:
		environment_state["contamination"] = _zero_channel(cell_order)

	var power_resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var thermal_kernel: ThermalResponseKernel = ThermalResponseKernelScript.new()
	var growth_resolver: PhaseBGrowthResolver = PhaseBGrowthResolverScript.new()
	var t08_qualifier: T08GrowthQualifier = T08GrowthQualifierScript.new()
	var s01_kernel: S01CoolerKernel = S01CoolerKernelScript.new()
	var s02_kernel: S02FilterKernel = S02FilterKernelScript.new()
	var contamination_kernel: ContaminationEnvironmentKernel = ContaminationEnvironmentKernelScript.new()

	var previous_powered_by_id: Dictionary = {}
	var phase_trace: PackedStringArray = PackedStringArray()
	var tick_checksums: PackedStringArray = PackedStringArray()
	var end_tick_snapshots: Array = []
	var growth_events: Array = []
	var all_power_events: Array = []
	var all_phase_c_support_events: Array = []
	var all_phase_c_environment_events: Array = []

	for tick: int in range(1, total_ticks + 1):
		phase_trace.append("%d:A" % tick)
		var active_hazards: PackedStringArray = _active_route_hazards(tick, route_profile)
		var available_result: Dictionary = _available_power_for_tick(base_power_capacity, active_hazards, all_hazards_by_id)
		if not bool(available_result["ok"]):
			return {"ok": false, "error": "phase_a:%s" % String(available_result["error"])}
		var resolved_power: Dictionary = power_resolver.resolve(
			int(available_result["available_power"]),
			installed_supports,
			priority_order,
			previous_powered_by_id
		)
		if not bool(resolved_power["ok"]):
			return {"ok": false, "error": "phase_a:%s" % String(resolved_power["error"])}
		var same_tick_eligible: PackedStringArray = resolved_power["same_tick_effect_eligible_support_ids"]
		var tick_power_events: Array = []
		var resolved_events: Array = resolved_power["events"]
		for raw_power_event: Variant in resolved_events:
			if not raw_power_event is Dictionary:
				continue
			var power_event: Dictionary = raw_power_event
			var with_tick: Dictionary = power_event.duplicate(true)
			with_tick["tick"] = tick
			tick_power_events.append(with_tick)
			all_power_events.append(with_tick)

		phase_trace.append("%d:B" % tick)
		var tick_growth_events: Array = []
		var tick_growth_requests: Array = base_runner._growth_requests_for_tick(growth_requests_by_tick, tick)
		if not tick_growth_requests.is_empty():
			var growth_result: Dictionary = growth_resolver.resolve_tick(
				organism_state,
				cell_order,
				tick_growth_requests,
				String(committed_input.get("retry_boundary", ""))
			)
			if not bool(growth_result["ok"]):
				return {"ok": false, "error": "phase_b:%s" % String(growth_result["error"])}
			organism_state = growth_result["organisms"]
			tick_growth_events = growth_result["growth_events"]
			for raw_growth_event: Variant in tick_growth_events:
				if raw_growth_event is Dictionary:
					var growth_event: Dictionary = raw_growth_event
					var growth_with_tick: Dictionary = growth_event.duplicate(true)
					growth_with_tick["tick"] = tick
					growth_events.append(growth_with_tick)

		phase_trace.append("%d:C" % tick)
		var active_base_hazards: PackedStringArray = base_runner._phase_a_route_input(tick, route_events)
		var generated_environment: Dictionary = base_runner._phase_c_generate_channels(
			environment_state,
			active_base_hazards,
			base_hazards_by_id,
			cell_order
		)
		var tick_phase_c_environment_events: Array = []
		if contamination_enabled:
			var source_result: Dictionary = contamination_kernel.apply_h03_phase_c(
				environment_state.get("contamination", _zero_channel(cell_order)),
				cell_order,
				active_hazards,
				all_hazards_by_id
			)
			if not bool(source_result["ok"]):
				return {"ok": false, "error": "phase_c:%s" % String(source_result["error"])}
			generated_environment["contamination"] = source_result["contamination_by_cell"]
			var source_events: Array = source_result["events"]
			for raw_source_event: Variant in source_events:
				if not raw_source_event is Dictionary:
					continue
				var source_event: Dictionary = raw_source_event
				var source_with_tick: Dictionary = source_event.duplicate(true)
				source_with_tick["tick"] = tick
				tick_phase_c_environment_events.append(source_with_tick)
				all_phase_c_environment_events.append(source_with_tick)

		var tick_phase_c_support_events: Array = []
		if has_s01:
			var cooler_result: Dictionary = s01_kernel.apply_phase_c(
				generated_environment.get("heat", {}),
				committed_supports,
				support_definitions_by_id,
				same_tick_eligible
			)
			if not bool(cooler_result["ok"]):
				return {"ok": false, "error": "phase_c:%s" % String(cooler_result["error"])}
			generated_environment["heat"] = cooler_result["heat_by_cell"]
			var cooler_events: Array = cooler_result["events"]
			for raw_cooler_event: Variant in cooler_events:
				if not raw_cooler_event is Dictionary:
					continue
				var cooler_event: Dictionary = raw_cooler_event
				var cooler_with_tick: Dictionary = cooler_event.duplicate(true)
				cooler_with_tick["tick"] = tick
				tick_phase_c_support_events.append(cooler_with_tick)
				all_phase_c_support_events.append(cooler_with_tick)
		if has_s02:
			var filter_result: Dictionary = s02_kernel.apply_phase_c(
				generated_environment.get("contamination", {}),
				committed_supports,
				support_definitions_by_id,
				same_tick_eligible
			)
			if not bool(filter_result["ok"]):
				return {"ok": false, "error": "phase_c:%s" % String(filter_result["error"])}
			generated_environment["contamination"] = filter_result["contamination_by_cell"]
			var filter_events: Array = filter_result["events"]
			for raw_filter_event: Variant in filter_events:
				if not raw_filter_event is Dictionary:
					continue
				var filter_event: Dictionary = raw_filter_event
				var filter_with_tick: Dictionary = filter_event.duplicate(true)
				filter_with_tick["tick"] = tick
				tick_phase_c_support_events.append(filter_with_tick)
				all_phase_c_support_events.append(filter_with_tick)

		phase_trace.append("%d:D" % tick)
		var next_environment: Dictionary = generated_environment.duplicate(true)
		if thermal_enabled:
			var propagated: Dictionary = thermal_kernel.propagate_heat(
				generated_environment.get("heat", {}),
				cell_order,
				thermal_rules
			)
			if not bool(propagated["ok"]):
				return {"ok": false, "error": "phase_d:%s" % String(propagated["error"])}
			next_environment["heat"] = propagated["heat_by_cell"]
		if contamination_enabled:
			var contamination_result: Dictionary = contamination_kernel.propagate_phase_d(
				generated_environment.get("contamination", {}),
				cell_order,
				contamination_rules
			)
			if not bool(contamination_result["ok"]):
				return {"ok": false, "error": "phase_d:%s" % String(contamination_result["error"])}
			next_environment["contamination"] = contamination_result["contamination_by_cell"]
		environment_state = next_environment

		phase_trace.append("%d:E" % tick)
		var organism_tick_snapshot: Array = []
		if thermal_enabled:
			var response: Dictionary = thermal_kernel.apply_heat_response(
				organism_state,
				environment_state.get("heat", {})
			)
			if not bool(response["ok"]):
				return {"ok": false, "error": "phase_e_f_g:%s" % String(response["error"])}
			organism_tick_snapshot = response["organisms"]
			var merged: Dictionary = base_runner._merge_organism_response(organism_state, organism_tick_snapshot)
			if not bool(merged["ok"]):
				return {"ok": false, "error": String(merged["error"])}
			organism_state = merged["organisms"]

		phase_trace.append("%d:F" % tick)
		phase_trace.append("%d:G" % tick)
		var tick_t08_queued_requests: Array = []
		if not t08_trigger_definitions.is_empty():
			var qualification_result: Dictionary = base_runner._t08_qualification_for_tick(t08_qualification_by_tick, tick)
			if not bool(qualification_result["ok"]):
				return {"ok": false, "error": "phase_g:%s" % String(qualification_result["error"])}
			var qualifier_result: Dictionary = t08_qualifier.evaluate_tick(
				tick,
				t08_trigger_definitions,
				qualification_result["qualification"],
				t08_qualification_state
			)
			if not bool(qualifier_result["ok"]):
				return {"ok": false, "error": "phase_g:%s" % String(qualifier_result["error"])}
			t08_qualification_state = qualifier_result["state"]
			tick_t08_queued_requests = qualifier_result["queued_requests"]
			var append_result: Dictionary = base_runner._append_qualified_growth_requests(
				growth_requests_by_tick,
				tick_t08_queued_requests,
				tick
			)
			if not bool(append_result["ok"]):
				return {"ok": false, "error": "phase_g:%s" % String(append_result["error"])}

		phase_trace.append("%d:H" % tick)
		phase_trace.append("%d:I" % tick)

		var snapshot: Dictionary = {
			"tick": tick,
			"active_hazards": active_hazards,
			"phase_a_power": _power_snapshot(resolved_power),
			"support_power_events": tick_power_events.duplicate(true),
			"same_tick_effect_eligible_support_ids": same_tick_eligible.duplicate(),
			"phase_c_environment_events": tick_phase_c_environment_events.duplicate(true),
			"phase_c_support_events": tick_phase_c_support_events.duplicate(true),
			"heat_by_cell": base_runner._heat_snapshot(environment_state, cell_order),
			"contamination_by_cell": _channel_snapshot(environment_state, "contamination", cell_order),
			"growth_events": tick_growth_events.duplicate(true),
			"t08_qualification_state": t08_qualification_state.duplicate(true),
			"t08_queued_growth_requests": tick_t08_queued_requests.duplicate(true),
		}
		if thermal_enabled:
			snapshot["organisms"] = organism_tick_snapshot
		if not organism_state.is_empty():
			snapshot["organism_runtime"] = organism_state.duplicate(true)
		end_tick_snapshots.append(snapshot)

		var serialized_tick: String = base_runner._serialize_tick(
			committed_run,
			committed_input,
			canonical_placements,
			tick,
			active_hazards,
			environment_state,
			cell_order,
			organism_state,
			t08_qualification_state
		)
		serialized_tick += "|" + String(resolved_power["authority_payload"])
		serialized_tick += "|phase_c_environment=" + _serialize_phase_c_environment_events(tick_phase_c_environment_events)
		serialized_tick += "|phase_c_support=" + _serialize_phase_c_support_events(tick_phase_c_support_events)
		serialized_tick += "|contamination=" + _serialize_channel(environment_state, "contamination", cell_order)
		tick_checksums.append(serialized_tick.sha256_text())
		var powered_by_id: Dictionary = resolved_power["powered_by_id"]
		previous_powered_by_id = powered_by_id.duplicate(true)

	return {
		"ok": true,
		"tick_checksums": tick_checksums,
		"phase_trace": phase_trace,
		"end_tick_snapshots": end_tick_snapshots,
		"growth_events": growth_events,
		"t08_qualification_state": t08_qualification_state.duplicate(true),
		"support_power_events": all_power_events,
		"phase_c_environment_events": all_phase_c_environment_events,
		"phase_c_support_events": all_phase_c_support_events,
		"final_support_powered_by_id": previous_powered_by_id,
		"final_tick": total_ticks,
		"completed": true,
	}

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
	var has_s01: bool = false
	var has_s02: bool = false
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
		if family == "S01":
			has_s01 = true
		elif family == "S02":
			has_s02 = true
		installed_supports.append({
			"instance_id": instance_id,
			"powered": true,
			"power_draw": power_draw,
			"supports_degraded_operation": bool(definition.get("supports_degraded_operation", false)),
		})

	var has_h03: bool = _has_hazard_family(hazards_by_id, "H03")
	var contamination_enabled: bool = has_h03 or has_s02
	var contamination_rules: Dictionary = {}
	if contamination_enabled:
		var contamination_rules_value: Variant = simulation_defs.get("contamination_rules", null)
		if not contamination_rules_value is Dictionary:
			return _failure("missing_contamination_rules")
		contamination_rules = contamination_rules_value

	return {
		"ok": true,
		"error": "",
		"route_profile": route_profile,
		"hazards_by_id": hazards_by_id,
		"base_power_capacity": base_power_capacity,
		"installed_supports": installed_supports,
		"priority_order": priority_order.duplicate(true),
		"committed_supports": committed_supports.duplicate(true),
		"support_definitions_by_id": support_definitions.duplicate(true),
		"has_s01": has_s01,
		"has_s02": has_s02,
		"contamination_enabled": contamination_enabled,
		"contamination_rules": contamination_rules.duplicate(true),
	}

func _defs_without_integrated_hazards(simulation_defs: Dictionary) -> Dictionary:
	var stripped: Dictionary = simulation_defs.duplicate(true)
	var route_value: Variant = stripped.get("route_profile", {})
	if route_value is Dictionary:
		var route_profile: Dictionary = route_value
		var retained_events: Array = []
		var route_events: Array = route_profile.get("events", [])
		for raw_event: Variant in route_events:
			if not raw_event is Dictionary:
				continue
			var route_event: Dictionary = raw_event
			var hazard_id: String = String(route_event.get("hazard_id", ""))
			var hazards_value_for_event: Variant = simulation_defs.get("hazards_by_id", {})
			if hazards_value_for_event is Dictionary:
				var hazards_for_event: Dictionary = hazards_value_for_event
				var hazard_value_for_event: Variant = hazards_for_event.get(hazard_id, {})
				if hazard_value_for_event is Dictionary:
					var hazard_for_event: Dictionary = hazard_value_for_event
					var family: String = String(hazard_for_event.get("family", ""))
					if family == "H03" or family == "H04":
						continue
			retained_events.append(route_event.duplicate(true))
		route_profile["events"] = retained_events
		stripped["route_profile"] = route_profile

	var hazards_value: Variant = stripped.get("hazards_by_id", {})
	if hazards_value is Dictionary:
		var hazards: Dictionary = hazards_value
		var retained_hazards: Dictionary = {}
		for raw_id: Variant in hazards.keys():
			var hazard_id: String = String(raw_id)
			var hazard_value: Variant = hazards[raw_id]
			if not hazard_value is Dictionary:
				continue
			var hazard_definition: Dictionary = hazard_value
			var family: String = String(hazard_definition.get("family", ""))
			if family == "H03" or family == "H04":
				continue
			retained_hazards[hazard_id] = hazard_definition.duplicate(true)
		stripped["hazards_by_id"] = retained_hazards
	stripped.erase("support_definitions_by_id")
	stripped.erase("contamination_rules")
	return stripped

func _active_route_hazards(tick: int, route_profile: Dictionary) -> PackedStringArray:
	var active_events: Array = []
	var route_events: Array = route_profile.get("events", [])
	for raw_event: Variant in route_events:
		if not raw_event is Dictionary:
			continue
		var route_event: Dictionary = raw_event
		var start_tick: int = int(route_event.get("tick", 0))
		var duration_ticks: int = int(route_event.get("duration_ticks", 0))
		if tick >= start_tick and tick < start_tick + duration_ticks:
			active_events.append(route_event)
	active_events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_order: int = int(left.get("authored_order", 0))
		var right_order: int = int(right.get("authored_order", 0))
		if left_order != right_order:
			return left_order < right_order
		return String(left.get("hazard_id", "")) < String(right.get("hazard_id", ""))
	)
	var ids: PackedStringArray = PackedStringArray()
	for route_event: Dictionary in active_events:
		ids.append(String(route_event.get("hazard_id", "")))
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
	var powered_support_ids: PackedStringArray = resolved["powered_support_ids"]
	var disabled_support_ids: PackedStringArray = resolved["disabled_support_ids"]
	var powered_by_id: Dictionary = resolved["powered_by_id"]
	return {
		"available_power": int(resolved["available_power"]),
		"used_power": int(resolved["used_power"]),
		"remaining_power": int(resolved["remaining_power"]),
		"total_installed_demand": int(resolved["total_installed_demand"]),
		"brownout_active": bool(resolved["brownout_active"]),
		"powered_support_ids": powered_support_ids.duplicate(),
		"disabled_support_ids": disabled_support_ids.duplicate(),
		"powered_by_id": powered_by_id.duplicate(true),
		"authority_checksum": String(resolved["authority_checksum"]),
	}

func _zero_channel(cell_order: PackedStringArray) -> Dictionary:
	var channel: Dictionary = {}
	for cell_key: String in cell_order:
		channel[cell_key] = 0
	return channel

func _channel_snapshot(environment_state: Dictionary, channel_name: String, cell_order: PackedStringArray) -> Dictionary:
	var channel_value: Variant = environment_state.get(channel_name, {})
	var channel: Dictionary = channel_value if channel_value is Dictionary else {}
	var ordered: Dictionary = {}
	for cell_key: String in cell_order:
		ordered[cell_key] = int(channel.get(cell_key, 0))
	return ordered

func _serialize_channel(environment_state: Dictionary, channel_name: String, cell_order: PackedStringArray) -> String:
	var channel: Dictionary = _channel_snapshot(environment_state, channel_name, cell_order)
	var encoded: PackedStringArray = PackedStringArray()
	for cell_key: String in cell_order:
		encoded.append("%s:%d" % [cell_key, int(channel[cell_key])])
	return ",".join(encoded)

func _serialize_phase_c_environment_events(events: Array) -> String:
	var encoded: PackedStringArray = PackedStringArray()
	for raw_event: Variant in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		encoded.append("%s:%s:%s:%d:%d" % [
			String(event.get("kind", "")),
			String(event.get("hazard_id", "")),
			String(event.get("cell_key", "")),
			int(event.get("contamination_delta", 0)),
			int(event.get("contamination_after", 0)),
		])
	return ";".join(encoded)

func _serialize_phase_c_support_events(events: Array) -> String:
	var encoded: PackedStringArray = PackedStringArray()
	for raw_event: Variant in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		encoded.append("%s:%s:%s:%d:%d:%d:%d:%d" % [
			String(event.get("kind", "")),
			String(event.get("instance_id", "")),
			String(event.get("cell_key", "")),
			int(event.get("capacity", 0)),
			int(event.get("removed_heat", 0)),
			int(event.get("heat_after", 0)),
			int(event.get("removed_contamination", 0)),
			int(event.get("contamination_after", 0)),
		])
	return ";".join(encoded)

func _has_hazard_family(hazards_by_id: Dictionary, family: String) -> bool:
	for raw_hazard: Variant in hazards_by_id.values():
		if raw_hazard is Dictionary:
			var hazard: Dictionary = raw_hazard
			if String(hazard.get("family", "")) == family:
				return true
	return false

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
