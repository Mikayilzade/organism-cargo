extends "res://src/sim/transit_shared_resource_runner_base.gd"

const PhaseDEnvironmentResolverScript := preload("res://src/sim/phase_d_environment_resolver.gd")

const H05_ENVIRONMENT_CHANNELS := PackedStringArray(["heat", "contamination"])

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	if not _has_relevant_h05_route_event(simulation_defs, total_ticks, H05_ENVIRONMENT_CHANNELS):
		return super.simulate(committed_run, total_ticks, simulation_defs)
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
	var t07_prepare: Dictionary = _prepare_t07_definitions(simulation_defs)
	if not bool(t07_prepare.get("ok", false)):
		return t07_prepare
	var t07_producers: Array = t07_prepare["producers"]
	var t07_consumers: Array = t07_prepare["consumers"]

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
	var t05_definitions: Array = prepare_power["t05_definitions"]
	var t06_definitions: Array = prepare_power["t06_definitions"]
	var contamination_enabled: bool = bool(prepare_power["contamination_enabled"])
	var contamination_rules: Dictionary = prepare_power["contamination_rules"]
	var h05_channel_validation: Dictionary = _validate_h05_environment_channels(
		simulation_defs, total_ticks, thermal_enabled, contamination_enabled
	)
	if not bool(h05_channel_validation.get("ok", false)):
		return h05_channel_validation
	if contamination_enabled:
		environment_state["contamination"] = _zero_channel(cell_order)
	if not t06_definitions.is_empty() or not t07_consumers.is_empty():
		var satiety_runtime_result: Dictionary = _prepare_shared_satiety_runtime(
			organism_state, simulation_defs, t06_definitions, t07_consumers
		)
		if not bool(satiety_runtime_result.get("ok", false)):
			return satiety_runtime_result
		organism_state = satiety_runtime_result["organisms"]

	var power_resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var thermal_kernel: ThermalResponseKernel = ThermalResponseKernelScript.new()
	var growth_resolver: PhaseBGrowthResolver = PhaseBGrowthResolverScript.new()
	var t08_qualifier: T08GrowthQualifier = T08GrowthQualifierScript.new()
	var t05_kernel: T05SporeShedderKernel = T05SporeShedderKernelScript.new()
	var t06_kernel: T06FilterFeederKernel = T06FilterFeederKernelScript.new()
	var t07_kernel: T07FeedingKernel = T07FeedingKernelScript.new()
	var s01_kernel: S01CoolerKernel = S01CoolerKernelScript.new()
	var s02_kernel: S02FilterKernel = S02FilterKernelScript.new()
	var contamination_kernel: ContaminationEnvironmentKernel = ContaminationEnvironmentKernelScript.new()
	var phase_d_resolver: PhaseDEnvironmentResolver = PhaseDEnvironmentResolverScript.new()

	var previous_powered_by_id: Dictionary = {}
	var phase_trace: PackedStringArray = PackedStringArray()
	var tick_checksums: PackedStringArray = PackedStringArray()
	var end_tick_snapshots: Array = []
	var growth_events: Array = []
	var all_power_events: Array = []
	var all_phase_c_support_events: Array = []
	var all_phase_c_environment_events: Array = []
	var all_t06_events: Array = []
	var all_t07_events: Array = []
	var all_t07_allocations: Array = []
	var all_shared_satiety_events: Array = []
	var all_h05_vent_events: Array = []

	for tick: int in range(1, total_ticks + 1):
		phase_trace.append("%d:A" % tick)
		var active_hazards: PackedStringArray = _active_route_hazards(tick, route_profile)
		var available_result: Dictionary = _available_power_for_tick(base_power_capacity, active_hazards, all_hazards_by_id)
		if not bool(available_result["ok"]):
			return {"ok": false, "error": "phase_a:%s" % String(available_result["error"])}
		var resolved_power: Dictionary = power_resolver.resolve(
			int(available_result["available_power"]), installed_supports, priority_order, previous_powered_by_id
		)
		if not bool(resolved_power["ok"]):
			return {"ok": false, "error": "phase_a:%s" % String(resolved_power["error"])}
		var same_tick_eligible: PackedStringArray = resolved_power["same_tick_effect_eligible_support_ids"]
		var tick_power_events: Array = []
		for raw_power_event: Variant in resolved_power["events"]:
			if raw_power_event is Dictionary:
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
				organism_state, cell_order, tick_growth_requests, String(committed_input.get("retry_boundary", ""))
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
			environment_state, active_base_hazards, base_hazards_by_id, cell_order
		)
		var tick_phase_c_environment_events: Array = []
		if contamination_enabled:
			var contamination_source_field: Dictionary = environment_state.get("contamination", _zero_channel(cell_order))
			if not t05_definitions.is_empty():
				var t05_result: Dictionary = t05_kernel.apply_phase_c(tick, contamination_source_field, organism_state, t05_definitions)
				if not bool(t05_result["ok"]):
					return {"ok": false, "error": "phase_c:%s" % String(t05_result["error"])}
				contamination_source_field = t05_result["contamination_by_cell"]
				for raw_t05_event: Variant in t05_result["events"]:
					if raw_t05_event is Dictionary:
						var t05_event: Dictionary = raw_t05_event
						var t05_with_tick: Dictionary = t05_event.duplicate(true)
						t05_with_tick["tick"] = tick
						tick_phase_c_environment_events.append(t05_with_tick)
						all_phase_c_environment_events.append(t05_with_tick)
			var source_result: Dictionary = contamination_kernel.apply_h03_phase_c(
				contamination_source_field, cell_order, active_hazards, all_hazards_by_id
			)
			if not bool(source_result["ok"]):
				return {"ok": false, "error": "phase_c:%s" % String(source_result["error"])}
			generated_environment["contamination"] = source_result["contamination_by_cell"]
			for raw_source_event: Variant in source_result["events"]:
				if raw_source_event is Dictionary:
					var source_event: Dictionary = raw_source_event
					var source_with_tick: Dictionary = source_event.duplicate(true)
					source_with_tick["tick"] = tick
					tick_phase_c_environment_events.append(source_with_tick)
					all_phase_c_environment_events.append(source_with_tick)

		var tick_phase_c_support_events: Array = []
		if has_s01:
			var cooler_result: Dictionary = s01_kernel.apply_phase_c(
				generated_environment.get("heat", {}), committed_supports, support_definitions_by_id, same_tick_eligible
			)
			if not bool(cooler_result["ok"]):
				return {"ok": false, "error": "phase_c:%s" % String(cooler_result["error"])}
			generated_environment["heat"] = cooler_result["heat_by_cell"]
			for raw_cooler_event: Variant in cooler_result["events"]:
				if raw_cooler_event is Dictionary:
					var cooler_event: Dictionary = raw_cooler_event
					var cooler_with_tick: Dictionary = cooler_event.duplicate(true)
					cooler_with_tick["tick"] = tick
					tick_phase_c_support_events.append(cooler_with_tick)
					all_phase_c_support_events.append(cooler_with_tick)
		if has_s02:
			var filter_result: Dictionary = s02_kernel.apply_phase_c(
				generated_environment.get("contamination", {}), committed_supports, support_definitions_by_id, same_tick_eligible
			)
			if not bool(filter_result["ok"]):
				return {"ok": false, "error": "phase_c:%s" % String(filter_result["error"])}
			generated_environment["contamination"] = filter_result["contamination_by_cell"]
			for raw_filter_event: Variant in filter_result["events"]:
				if raw_filter_event is Dictionary:
					var filter_event: Dictionary = raw_filter_event
					var filter_with_tick: Dictionary = filter_event.duplicate(true)
					filter_with_tick["tick"] = tick
					tick_phase_c_support_events.append(filter_with_tick)
					all_phase_c_support_events.append(filter_with_tick)

		phase_trace.append("%d:D" % tick)
		var next_environment: Dictionary = generated_environment.duplicate(true)
		var tick_h05_events: Array = []
		var tick_h05_effective_vent: Dictionary = {}
		var tick_h05_authority_payload: String = ""
		var phase_d_generated: Dictionary = {}
		var phase_d_rules: Dictionary = {}
		if thermal_enabled:
			phase_d_generated["heat"] = generated_environment.get("heat", {})
			phase_d_rules["heat"] = thermal_rules
		if contamination_enabled:
			phase_d_generated["contamination"] = generated_environment.get("contamination", {})
			phase_d_rules["contamination"] = contamination_rules
		if not phase_d_generated.is_empty():
			var scoped_h05: Dictionary = _scoped_h05_authority(active_hazards, all_hazards_by_id, H05_ENVIRONMENT_CHANNELS)
			if not bool(scoped_h05.get("ok", false)):
				return scoped_h05
			var phase_d_result: Dictionary = phase_d_resolver.resolve_phase_d(
				tick,
				cell_order,
				scoped_h05["active_hazards"],
				scoped_h05["hazards_by_id"],
				phase_d_generated,
				phase_d_rules
			)
			if not bool(phase_d_result.get("ok", false)):
				return {"ok": false, "error": "phase_d:%s" % String(phase_d_result.get("error", "unknown"))}
			var resolved_environment: Dictionary = phase_d_result["environment_by_channel"]
			for raw_channel: Variant in resolved_environment.keys():
				next_environment[String(raw_channel)] = (resolved_environment[raw_channel] as Dictionary).duplicate(true)
			tick_h05_events = (phase_d_result["h05_events"] as Array).duplicate(true)
			if not tick_h05_events.is_empty():
				tick_h05_effective_vent = (phase_d_result["effective_vent_by_channel"] as Dictionary).duplicate(true)
				tick_h05_authority_payload = String(phase_d_result["authority_payload"])
				for raw_h05_event: Variant in tick_h05_events:
					if raw_h05_event is Dictionary:
						all_h05_vent_events.append((raw_h05_event as Dictionary).duplicate(true))
		environment_state = next_environment
		var phase_d_contamination_exposure: Dictionary = {}
		if contamination_enabled:
			phase_d_contamination_exposure = _channel_snapshot(environment_state, "contamination", cell_order)

		phase_trace.append("%d:E" % tick)
		var organism_tick_snapshot: Array = []
		if thermal_enabled:
			var response: Dictionary = thermal_kernel.apply_heat_response(organism_state, environment_state.get("heat", {}))
			if not bool(response["ok"]):
				return {"ok": false, "error": "phase_e_f_g:%s" % String(response["error"])}
			organism_tick_snapshot = response["organisms"]
			var merged: Dictionary = base_runner._merge_organism_response(organism_state, organism_tick_snapshot)
			if not bool(merged["ok"]):
				return {"ok": false, "error": String(merged["error"])}
			organism_state = merged["organisms"]
		var pre_f_organism_state: Array = organism_state.duplicate(true)
		var t06_result: Dictionary = {}
		if not t06_definitions.is_empty():
			t06_result = t06_kernel.resolve_tick(tick, phase_d_contamination_exposure, pre_f_organism_state, t06_definitions)
			if not bool(t06_result.get("ok", false)):
				return {"ok": false, "error": "phase_e_t06:%s" % String(t06_result.get("error", "unknown"))}
		var t07_result: Dictionary = {}
		if not t07_producers.is_empty():
			t07_result = t07_kernel.resolve_tick(tick, pre_f_organism_state, t07_producers, t07_consumers)
			if not bool(t07_result.get("ok", false)):
				return {"ok": false, "error": "phase_e_t07:%s" % String(t07_result.get("error", "unknown"))}

		phase_trace.append("%d:F" % tick)
		var tick_t06_events: Array = []
		var tick_t07_events: Array = []
		var tick_t07_allocations: Array = []
		var tick_shared_satiety_events: Array = []
		if not t06_result.is_empty():
			environment_state["contamination"] = t06_result["contamination_by_cell"]
			for raw_t06_event: Variant in t06_result["events"]:
				if not raw_t06_event is Dictionary:
					return {"ok": false, "error": "invalid_t06_event"}
				var t06_event: Dictionary = raw_t06_event
				tick_t06_events.append(t06_event.duplicate(true))
				all_t06_events.append(t06_event.duplicate(true))
		if not t07_result.is_empty():
			for raw_t07_event: Variant in t07_result["events"]:
				if not raw_t07_event is Dictionary:
					return {"ok": false, "error": "invalid_t07_event"}
				var t07_event: Dictionary = raw_t07_event
				tick_t07_events.append(t07_event.duplicate(true))
				all_t07_events.append(t07_event.duplicate(true))
			for raw_allocation: Variant in t07_result["allocations"]:
				if not raw_allocation is Dictionary:
					return {"ok": false, "error": "invalid_t07_allocation"}
				var allocation: Dictionary = raw_allocation
				var allocation_with_tick: Dictionary = allocation.duplicate(true)
				allocation_with_tick["tick"] = tick
				tick_t07_allocations.append(allocation.duplicate(true))
				all_t07_allocations.append(allocation_with_tick)

		if not t06_result.is_empty() and not t07_result.is_empty():
			var composed: Dictionary = _compose_shared_satiety_phase_f(
				tick, pre_f_organism_state, tick_t06_events, tick_t07_events, t06_definitions, t07_consumers
			)
			if not bool(composed.get("ok", false)):
				return composed
			organism_state = composed["organisms"]
			tick_shared_satiety_events = composed["events"]
			for raw_shared_event: Variant in tick_shared_satiety_events:
				if raw_shared_event is Dictionary:
					var shared_event: Dictionary = raw_shared_event
					all_shared_satiety_events.append(shared_event.duplicate(true))
		elif not t06_result.is_empty():
			organism_state = t06_result["organisms"]
		elif not t07_result.is_empty():
			organism_state = t07_result["organisms"]

		phase_trace.append("%d:G" % tick)
		var tick_t08_queued_requests: Array = []
		if not t08_trigger_definitions.is_empty():
			var qualification_result: Dictionary = base_runner._t08_qualification_for_tick(t08_qualification_by_tick, tick)
			if not bool(qualification_result["ok"]):
				return {"ok": false, "error": "phase_g:%s" % String(qualification_result["error"])}
			var qualifier_result: Dictionary = t08_qualifier.evaluate_tick(
				tick, t08_trigger_definitions, qualification_result["qualification"], t08_qualification_state
			)
			if not bool(qualifier_result["ok"]):
				return {"ok": false, "error": "phase_g:%s" % String(qualifier_result["error"])}
			t08_qualification_state = qualifier_result["state"]
			tick_t08_queued_requests = qualifier_result["queued_requests"]
			var append_result: Dictionary = base_runner._append_qualified_growth_requests(
				growth_requests_by_tick, tick_t08_queued_requests, tick
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
			"phase_d_contamination_exposure_by_cell": phase_d_contamination_exposure.duplicate(true),
			"contamination_by_cell": _channel_snapshot(environment_state, "contamination", cell_order),
			"t06_events": tick_t06_events.duplicate(true),
			"t07_events": tick_t07_events.duplicate(true),
			"t07_allocations": tick_t07_allocations.duplicate(true),
			"shared_satiety_events": tick_shared_satiety_events.duplicate(true),
			"growth_events": tick_growth_events.duplicate(true),
			"t08_qualification_state": t08_qualification_state.duplicate(true),
			"t08_queued_growth_requests": tick_t08_queued_requests.duplicate(true),
		}
		if thermal_enabled:
			snapshot["organisms"] = organism_tick_snapshot
		if not organism_state.is_empty():
			snapshot["organism_runtime"] = organism_state.duplicate(true)
		if not tick_h05_events.is_empty():
			snapshot["h05_vent_events"] = tick_h05_events.duplicate(true)
			snapshot["phase_d_effective_vent_by_channel"] = tick_h05_effective_vent.duplicate(true)
			snapshot["phase_d_environment_authority_payload"] = tick_h05_authority_payload
			snapshot["phase_d_environment_authority_checksum"] = tick_h05_authority_payload.sha256_text()
		end_tick_snapshots.append(snapshot)

		var serialized_tick: String = base_runner._serialize_tick(
			committed_run, committed_input, canonical_placements, tick, active_hazards,
			environment_state, cell_order, organism_state, t08_qualification_state
		)
		serialized_tick += "|" + String(resolved_power["authority_payload"])
		serialized_tick += "|phase_c_environment=" + _serialize_phase_c_environment_events(tick_phase_c_environment_events)
		serialized_tick += "|phase_c_support=" + _serialize_phase_c_support_events(tick_phase_c_support_events)
		serialized_tick += "|phase_d_contamination=" + _serialize_channel_value(phase_d_contamination_exposure, cell_order)
		serialized_tick += "|t06=" + _serialize_t06_events(tick_t06_events)
		serialized_tick += "|t07=" + _serialize_t07_events(tick_t07_events)
		serialized_tick += "|shared_satiety=" + _serialize_shared_satiety_events(tick_shared_satiety_events)
		serialized_tick += "|contamination=" + _serialize_channel(environment_state, "contamination", cell_order)
		if not tick_h05_events.is_empty():
			serialized_tick += "|h05_phase_d=" + tick_h05_authority_payload
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
		"t06_events": all_t06_events,
		"t07_events": all_t07_events,
		"t07_allocations": all_t07_allocations,
		"shared_satiety_events": all_shared_satiety_events,
		"h05_vent_events": all_h05_vent_events,
		"final_organism_runtime": organism_state.duplicate(true),
		"final_support_powered_by_id": previous_powered_by_id,
		"final_tick": total_ticks,
		"completed": true,
	}

func _defs_without_integrated_hazards(simulation_defs: Dictionary) -> Dictionary:
	var stripped: Dictionary = super._defs_without_integrated_hazards(simulation_defs)
	var route_value: Variant = stripped.get("route_profile", {})
	var hazards_value: Variant = stripped.get("hazards_by_id", {})
	if route_value is Dictionary and hazards_value is Dictionary:
		var route_profile: Dictionary = route_value
		var hazards: Dictionary = hazards_value
		var retained_events: Array = []
		for raw_event: Variant in route_profile.get("events", []):
			if not raw_event is Dictionary:
				continue
			var route_event: Dictionary = raw_event
			var hazard_id: String = String(route_event.get("hazard_id", ""))
			var hazard_value: Variant = hazards.get(hazard_id, {})
			if hazard_value is Dictionary and String((hazard_value as Dictionary).get("family", "")) == "H05":
				continue
			retained_events.append(route_event.duplicate(true))
		route_profile["events"] = retained_events
		var retained_hazards: Dictionary = {}
		for raw_id: Variant in hazards.keys():
			var hazard_id: String = String(raw_id)
			var hazard_value: Variant = hazards[raw_id]
			if hazard_value is Dictionary and String((hazard_value as Dictionary).get("family", "")) == "H05":
				continue
			retained_hazards[hazard_id] = (hazard_value as Dictionary).duplicate(true) if hazard_value is Dictionary else hazard_value
		stripped["route_profile"] = route_profile
		stripped["hazards_by_id"] = retained_hazards
	return stripped

func _has_relevant_h05_route_event(
		simulation_defs: Dictionary,
		total_ticks: int,
		channels: PackedStringArray
) -> bool:
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
		if not delta_value is Dictionary:
			return true
		var delta_by_channel: Dictionary = delta_value
		for channel: String in channels:
			if delta_by_channel.has(channel):
				return true
	return false

func _validate_h05_environment_channels(
		simulation_defs: Dictionary,
		total_ticks: int,
		thermal_enabled: bool,
		contamination_enabled: bool
) -> Dictionary:
	var route_value: Variant = simulation_defs.get("route_profile", {})
	var hazards_value: Variant = simulation_defs.get("hazards_by_id", {})
	if not route_value is Dictionary or not hazards_value is Dictionary:
		return {"ok": false, "error": "missing_h05_route_authority"}
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
			return {"ok": false, "error": "missing_hazard_definition:%s" % hazard_id}
		var hazard: Dictionary = hazard_value
		if String(hazard.get("family", "")) != "H05":
			continue
		var delta_value: Variant = hazard.get("vent_delta_by_channel", null)
		if not delta_value is Dictionary:
			return {"ok": false, "error": "invalid_h05_vent_delta_by_channel:%s" % hazard_id}
		var delta_by_channel: Dictionary = delta_value
		if delta_by_channel.has("heat") and not thermal_enabled:
			return {"ok": false, "error": "h05_channel_not_enabled:%s:heat" % hazard_id}
		if delta_by_channel.has("contamination") and not contamination_enabled:
			return {"ok": false, "error": "h05_channel_not_enabled:%s:contamination" % hazard_id}
	return {"ok": true, "error": ""}

func _scoped_h05_authority(
		active_hazards: PackedStringArray,
		hazards_by_id: Dictionary,
		channels: PackedStringArray
) -> Dictionary:
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
		var scoped_delta: Dictionary = {}
		for channel: String in channels:
			if delta_by_channel.has(channel):
				scoped_delta[channel] = (delta_by_channel[channel] as Dictionary).duplicate(true) if delta_by_channel[channel] is Dictionary else delta_by_channel[channel]
		if scoped_delta.is_empty():
			continue
		var scoped_hazard: Dictionary = hazard.duplicate(true)
		scoped_hazard["vent_delta_by_channel"] = scoped_delta
		scoped_active.append(hazard_id)
		scoped_hazards[hazard_id] = scoped_hazard
	scoped_active.sort()
	return {"ok": true, "error": "", "active_hazards": scoped_active, "hazards_by_id": scoped_hazards}
