class_name TransitSliceRunner
extends RefCounted

const ThermalResponseKernelScript := preload("res://src/sim/thermal_response_kernel.gd")
const PhaseBGrowthResolverScript := preload("res://src/sim/phase_b_growth_resolver.gd")
const PHASE_ORDER_CSV := "A,B,C,D,E,F,G,H,I"

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	if total_ticks <= 0:
		return {"ok": false, "error": "invalid_total_ticks"}
	if not committed_run.has("canonical_committed_input"):
		return {"ok": false, "error": "missing_committed_input"}
	var committed_input: Dictionary = committed_run["canonical_committed_input"]
	var supports: Array = committed_input.get("supports", [])
	if not supports.is_empty():
		return {"ok": false, "error": "slice_supports_not_implemented"}
	var canonical_placements: PackedStringArray = _canonical_placements(committed_input)
	if canonical_placements.is_empty():
		return {"ok": false, "error": "missing_placements"}

	var prepared: Dictionary = _prepare_definitions(committed_input, total_ticks, simulation_defs)
	if not bool(prepared["ok"]):
		return {"ok": false, "error": String(prepared["error"])}
	var route_events: Array = prepared["route_events"]
	var hazards_by_id: Dictionary = prepared["hazards_by_id"]
	var cell_order: PackedStringArray = prepared["cell_order"]
	var environment_state: Dictionary = prepared["initial_environment"]
	var thermal_enabled: bool = bool(prepared["thermal_enabled"])
	var thermal_rules: Dictionary = prepared["thermal_rules"]
	var organism_state: Array = prepared["organisms"]
	var growth_requests_by_tick: Dictionary = prepared["growth_requests_by_tick"]
	var thermal_kernel: ThermalResponseKernel = ThermalResponseKernelScript.new()
	var growth_resolver: PhaseBGrowthResolver = PhaseBGrowthResolverScript.new()

	var phase_trace: PackedStringArray = PackedStringArray()
	var tick_checksums: PackedStringArray = PackedStringArray()
	var end_tick_snapshots: Array = []
	var growth_events: Array = []
	for tick: int in range(1, total_ticks + 1):
		phase_trace.append("%d:A" % tick)
		var active_hazards: PackedStringArray = _phase_a_route_input(tick, route_events)

		phase_trace.append("%d:B" % tick)
		var tick_growth_events: Array = []
		var tick_growth_requests: Array = _growth_requests_for_tick(growth_requests_by_tick, tick)
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
					var event_with_tick: Dictionary = growth_event.duplicate(true)
					event_with_tick["tick"] = tick
					growth_events.append(event_with_tick)

		phase_trace.append("%d:C" % tick)
		var generated_environment: Dictionary = _phase_c_generate_channels(
			environment_state,
			active_hazards,
			hazards_by_id,
			cell_order
		)

		phase_trace.append("%d:D" % tick)
		if thermal_enabled:
			var propagated: Dictionary = thermal_kernel.propagate_heat(
				generated_environment.get("heat", {}),
				cell_order,
				thermal_rules
			)
			if not bool(propagated["ok"]):
				return {"ok": false, "error": "phase_d:%s" % String(propagated["error"])}
			environment_state = {"heat": propagated["heat_by_cell"]}
		else:
			environment_state = _phase_d_publish_exposure(generated_environment)

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
			var merged: Dictionary = _merge_organism_response(organism_state, organism_tick_snapshot)
			if not bool(merged["ok"]):
				return {"ok": false, "error": String(merged["error"])}
			organism_state = merged["organisms"]
		phase_trace.append("%d:F" % tick)
		phase_trace.append("%d:G" % tick)
		phase_trace.append("%d:H" % tick)
		phase_trace.append("%d:I" % tick)

		var snapshot: Dictionary = {
			"tick": tick,
			"active_hazards": active_hazards,
			"heat_by_cell": _heat_snapshot(environment_state, cell_order),
			"growth_events": tick_growth_events.duplicate(true),
		}
		if thermal_enabled:
			snapshot["organisms"] = organism_tick_snapshot
		if not organism_state.is_empty():
			snapshot["organism_runtime"] = organism_state.duplicate(true)
		end_tick_snapshots.append(snapshot)
		var serialized_tick: String = _serialize_tick(
			committed_run,
			committed_input,
			canonical_placements,
			tick,
			active_hazards,
			environment_state,
			cell_order,
			organism_state
		)
		tick_checksums.append(serialized_tick.sha256_text())

	return {
		"ok": true,
		"tick_checksums": tick_checksums,
		"phase_trace": phase_trace,
		"end_tick_snapshots": end_tick_snapshots,
		"growth_events": growth_events,
		"final_tick": total_ticks,
		"completed": true,
	}

func _prepare_definitions(committed_input: Dictionary, total_ticks: int, simulation_defs: Dictionary) -> Dictionary:
	if simulation_defs.is_empty():
		return {
			"ok": true,
			"error": "",
			"route_events": [],
			"hazards_by_id": {},
			"cell_order": PackedStringArray(),
			"initial_environment": {"heat": {}},
			"thermal_enabled": false,
			"thermal_rules": {},
			"organisms": [],
			"growth_requests_by_tick": {},
		}
	if not simulation_defs.has("route_profile") or not simulation_defs["route_profile"] is Dictionary:
		return _definition_failure("missing_route_profile")
	if not simulation_defs.has("hold_definition") or not simulation_defs["hold_definition"] is Dictionary:
		return _definition_failure("missing_hold_definition")
	if not simulation_defs.has("hazards_by_id") or not simulation_defs["hazards_by_id"] is Dictionary:
		return _definition_failure("missing_hazard_definitions")

	var route_profile: Dictionary = simulation_defs["route_profile"]
	var route_id: String = String(committed_input.get("route_id", ""))
	if route_id.is_empty() or String(route_profile.get("id", "")) != route_id:
		return _definition_failure("route_profile_mismatch")
	if int(route_profile.get("tick_count", 0)) != total_ticks:
		return _definition_failure("route_tick_count_mismatch")

	var hazards_by_id: Dictionary = simulation_defs["hazards_by_id"]
	var route_events: Array = []
	var raw_events: Array = route_profile.get("events", [])
	for raw_event: Variant in raw_events:
		if not raw_event is Dictionary:
			return _definition_failure("invalid_route_event")
		var event: Dictionary = raw_event
		var tick: int = int(event.get("tick", 0))
		var duration_ticks: int = int(event.get("duration_ticks", 0))
		var hazard_id: String = String(event.get("hazard_id", ""))
		if tick < 1 or tick > total_ticks or duration_ticks <= 0 or hazard_id.is_empty():
			return _definition_failure("invalid_route_event")
		if not hazards_by_id.has(hazard_id) or not hazards_by_id[hazard_id] is Dictionary:
			return _definition_failure("missing_hazard:%s" % hazard_id)
		var hazard: Dictionary = hazards_by_id[hazard_id]
		var family: String = String(hazard.get("family", ""))
		if family != "H01":
			return _definition_failure("slice_hazard_not_implemented:%s" % family)
		if String(hazard.get("target_scope", "")) != "hold":
			return _definition_failure("slice_hazard_scope_not_implemented")
		if not hazard.has("heat_delta"):
			return _definition_failure("missing_h01_heat_delta")
		var normalized: Dictionary = {
			"tick": tick,
			"duration_ticks": duration_ticks,
			"hazard_id": hazard_id,
			"authored_order": int(event.get("authored_order", route_events.size())),
		}
		_insert_route_event(route_events, normalized)

	var hold_definition: Dictionary = simulation_defs["hold_definition"]
	var cell_order_result: Dictionary = _build_cell_order(hold_definition)
	if not bool(cell_order_result["ok"]):
		return _definition_failure(String(cell_order_result["error"]))
	var cell_order: PackedStringArray = cell_order_result["cell_order"]
	var heat: Dictionary = {}
	for cell_key: String in cell_order:
		heat[cell_key] = 0

	var growth_requests_by_tick: Dictionary = {}
	var growth_requests_value: Variant = simulation_defs.get("growth_requests_by_tick", {})
	if not growth_requests_value is Dictionary:
		return _definition_failure("invalid_growth_requests_by_tick")
	growth_requests_by_tick = growth_requests_value

	var thermal_rules_value: Variant = simulation_defs.get("thermal_rules", null)
	var organism_definitions_value: Variant = simulation_defs.get("organism_definitions", null)
	var thermal_enabled: bool = thermal_rules_value != null
	var organisms_required: bool = organism_definitions_value != null or not growth_requests_by_tick.is_empty()
	var thermal_rules: Dictionary = {}
	var organisms: Array = []
	if thermal_enabled:
		if not thermal_rules_value is Dictionary:
			return _definition_failure("missing_thermal_rules")
		var thermal_rules_dictionary: Dictionary = thermal_rules_value
		thermal_rules = thermal_rules_dictionary
	if organisms_required:
		if not organism_definitions_value is Dictionary:
			return _definition_failure("missing_organism_definitions")
		var organism_definitions: Dictionary = organism_definitions_value
		var organism_result: Dictionary = _prepare_organisms(
			committed_input,
			organism_definitions,
			cell_order
		)
		if not bool(organism_result["ok"]):
			return _definition_failure(String(organism_result["error"]))
		organisms = organism_result["organisms"]

	return {
		"ok": true,
		"error": "",
		"route_events": route_events,
		"hazards_by_id": hazards_by_id,
		"cell_order": cell_order,
		"initial_environment": {"heat": heat},
		"thermal_enabled": thermal_enabled,
		"thermal_rules": thermal_rules,
		"organisms": organisms,
		"growth_requests_by_tick": growth_requests_by_tick,
	}

func _prepare_organisms(
		committed_input: Dictionary,
		organism_definitions: Dictionary,
		cell_order: PackedStringArray
) -> Dictionary:
	var valid_cells: Dictionary = {}
	for cell_key: String in cell_order:
		valid_cells[cell_key] = true
	var placements: Array = committed_input.get("placements", [])
	var organisms: Array = []
	var seen: Dictionary = {}
	for raw_placement: Variant in placements:
		if not raw_placement is Dictionary:
			return {"ok": false, "error": "invalid_placement_for_organism_runtime", "organisms": []}
		var placement: Dictionary = raw_placement
		var instance_id: String = String(placement.get("instance_id", ""))
		var anchor: Array = placement.get("anchor", [])
		if instance_id.is_empty() or anchor.size() != 2 or seen.has(instance_id):
			return {"ok": false, "error": "invalid_placement_for_organism_runtime", "organisms": []}
		seen[instance_id] = true
		if not organism_definitions.has(instance_id) or not organism_definitions[instance_id] is Dictionary:
			return {"ok": false, "error": "missing_organism_definition:%s" % instance_id, "organisms": []}
		var cell_key: String = _cell_key(int(anchor[0]), int(anchor[1]))
		if not valid_cells.has(cell_key):
			return {"ok": false, "error": "organism_anchor_not_usable:%s" % instance_id, "organisms": []}
		var definition: Dictionary = organism_definitions[instance_id]
		if not definition.has("stress_profile") or not definition["stress_profile"] is Dictionary:
			return {"ok": false, "error": "missing_stress_profile:%s" % instance_id, "organisms": []}
		var orientation: int = int(placement.get("orientation", 0))
		var occupied_cells: Array = [cell_key]
		var body_stage: String = String(definition.get("initial_body_stage", ""))
		var body_stages_value: Variant = definition.get("body_stages", {})
		if not body_stages_value is Dictionary:
			return {"ok": false, "error": "invalid_body_stages:%s" % instance_id, "organisms": []}
		var body_stages: Dictionary = body_stages_value
		if not body_stage.is_empty() or not body_stages.is_empty():
			if body_stage.is_empty() or body_stages.is_empty():
				return {"ok": false, "error": "incomplete_body_stage_definition:%s" % instance_id, "organisms": []}
			var stage_cells_result: Dictionary = _stage_cells(anchor, orientation, body_stages, body_stage)
			if not bool(stage_cells_result["ok"]):
				return {"ok": false, "error": "%s:%s" % [String(stage_cells_result["error"]), instance_id], "organisms": []}
			var stage_cells: PackedStringArray = stage_cells_result["cells"]
			for stage_cell: String in stage_cells:
				if not valid_cells.has(stage_cell):
					return {"ok": false, "error": "organism_footprint_not_usable:%s" % instance_id, "organisms": []}
			occupied_cells = Array(stage_cells)
		organisms.append({
			"instance_id": instance_id,
			"anchor": anchor.duplicate(true),
			"orientation": orientation,
			"occupied_cells": occupied_cells,
			"body_stage": body_stage,
			"body_stages": body_stages.duplicate(true),
			"growth_episode_state": {},
			"growth_blocked": false,
			"stress": int(definition.get("initial_stress", 0)),
			"primary_state": String(definition.get("initial_state", "CALM")),
			"stress_profile": definition["stress_profile"],
		})
	organisms.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	return {"ok": true, "error": "", "organisms": organisms}

func _stage_cells(anchor: Array, orientation: int, body_stages: Dictionary, stage: String) -> Dictionary:
	if not body_stages.has(stage) or not body_stages[stage] is Dictionary:
		return {"ok": false, "error": "missing_body_stage", "cells": PackedStringArray()}
	var stage_definition: Dictionary = body_stages[stage]
	var footprints_value: Variant = stage_definition.get("footprints", {})
	if not footprints_value is Dictionary:
		return {"ok": false, "error": "missing_stage_footprints", "cells": PackedStringArray()}
	var footprints: Dictionary = footprints_value
	var orientation_key: String = str(orientation)
	if not footprints.has(orientation_key) or not footprints[orientation_key] is Array:
		return {"ok": false, "error": "missing_stage_orientation", "cells": PackedStringArray()}
	var offsets: Array = footprints[orientation_key]
	var cells: PackedStringArray = PackedStringArray()
	for raw_offset: Variant in offsets:
		if not raw_offset is Array:
			return {"ok": false, "error": "invalid_stage_footprint", "cells": PackedStringArray()}
		var offset: Array = raw_offset
		if offset.size() != 2:
			return {"ok": false, "error": "invalid_stage_footprint", "cells": PackedStringArray()}
		cells.append(_cell_key(int(anchor[0]) + int(offset[0]), int(anchor[1]) + int(offset[1])))
	cells.sort()
	return {"ok": true, "error": "", "cells": cells}

func _growth_requests_for_tick(growth_requests_by_tick: Dictionary, tick: int) -> Array:
	var direct_key: String = str(tick)
	var value: Variant = growth_requests_by_tick.get(direct_key, growth_requests_by_tick.get(tick, []))
	if not value is Array:
		return []
	var requests: Array = value
	return requests.duplicate(true)

func _merge_organism_response(previous: Array, response: Array) -> Dictionary:
	var previous_by_id: Dictionary = {}
	for raw_previous: Variant in previous:
		if not raw_previous is Dictionary:
			return {"ok": false, "error": "invalid_previous_organism_runtime", "organisms": []}
		var previous_organism: Dictionary = raw_previous
		previous_by_id[String(previous_organism["instance_id"])] = previous_organism
	var merged: Array = []
	for raw_response: Variant in response:
		if not raw_response is Dictionary:
			return {"ok": false, "error": "invalid_organism_response", "organisms": []}
		var response_organism: Dictionary = raw_response
		var instance_id: String = String(response_organism.get("instance_id", ""))
		if not previous_by_id.has(instance_id):
			return {"ok": false, "error": "unknown_organism_response:%s" % instance_id, "organisms": []}
		var previous_organism: Dictionary = previous_by_id[instance_id]
		var next_organism: Dictionary = previous_organism.duplicate(true)
		next_organism["stress"] = int(response_organism["stress"])
		next_organism["primary_state"] = String(response_organism["primary_state"])
		merged.append(next_organism)
	if merged.size() != previous.size():
		return {"ok": false, "error": "incomplete_organism_response", "organisms": []}
	merged.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["instance_id"]) < String(right["instance_id"])
	)
	return {"ok": true, "error": "", "organisms": merged}

func _insert_route_event(events: Array, event: Dictionary) -> void:
	var insert_at: int = events.size()
	for index: int in range(events.size()):
		var existing: Dictionary = events[index]
		if _route_event_less(event, existing):
			insert_at = index
			break
	events.insert(insert_at, event)

func _route_event_less(left: Dictionary, right: Dictionary) -> bool:
	var left_tick: int = int(left["tick"])
	var right_tick: int = int(right["tick"])
	if left_tick != right_tick:
		return left_tick < right_tick
	var left_order: int = int(left["authored_order"])
	var right_order: int = int(right["authored_order"])
	if left_order != right_order:
		return left_order < right_order
	return String(left["hazard_id"]) < String(right["hazard_id"])

func _build_cell_order(hold_definition: Dictionary) -> Dictionary:
	var dimensions_value: Variant = hold_definition.get("dimensions", [])
	if not dimensions_value is Array:
		return {"ok": false, "error": "invalid_hold_dimensions", "cell_order": PackedStringArray()}
	var dimensions: Array = dimensions_value
	if dimensions.size() != 2:
		return {"ok": false, "error": "invalid_hold_dimensions", "cell_order": PackedStringArray()}
	var width: int = int(dimensions[0])
	var height: int = int(dimensions[1])
	if width <= 0 or height <= 0:
		return {"ok": false, "error": "invalid_hold_dimensions", "cell_order": PackedStringArray()}
	var blocked: Dictionary = {}
	var blocked_cells: Array = hold_definition.get("blocked_cells", [])
	for raw_cell: Variant in blocked_cells:
		if not raw_cell is Array:
			return {"ok": false, "error": "invalid_blocked_cell", "cell_order": PackedStringArray()}
		var cell: Array = raw_cell
		if cell.size() != 2:
			return {"ok": false, "error": "invalid_blocked_cell", "cell_order": PackedStringArray()}
		blocked[_cell_key(int(cell[0]), int(cell[1]))] = true
	var cell_order: PackedStringArray = PackedStringArray()
	for y: int in range(height):
		for x: int in range(width):
			var key: String = _cell_key(x, y)
			if not blocked.has(key):
				cell_order.append(key)
	if cell_order.is_empty():
		return {"ok": false, "error": "hold_has_no_usable_cells", "cell_order": PackedStringArray()}
	return {"ok": true, "error": "", "cell_order": cell_order}

func _phase_a_route_input(tick: int, route_events: Array) -> PackedStringArray:
	var active: PackedStringArray = PackedStringArray()
	for raw_event: Variant in route_events:
		var event: Dictionary = raw_event
		var start_tick: int = int(event["tick"])
		var end_tick_exclusive: int = start_tick + int(event["duration_ticks"])
		if tick >= start_tick and tick < end_tick_exclusive:
			active.append(String(event["hazard_id"]))
	return active

func _phase_c_generate_channels(
		previous_environment: Dictionary,
		active_hazards: PackedStringArray,
		hazards_by_id: Dictionary,
		cell_order: PackedStringArray
) -> Dictionary:
	var generated: Dictionary = previous_environment.duplicate(true)
	var generated_heat: Dictionary = generated.get("heat", {})
	var heat: Dictionary = generated_heat.duplicate(true)
	for hazard_id: String in active_hazards:
		var hazard: Dictionary = hazards_by_id[hazard_id]
		var heat_delta: int = int(hazard["heat_delta"])
		for cell_key: String in cell_order:
			heat[cell_key] = int(heat.get(cell_key, 0)) + heat_delta
	generated["heat"] = heat
	return generated

func _phase_d_publish_exposure(generated_environment: Dictionary) -> Dictionary:
	return generated_environment.duplicate(true)

func _heat_snapshot(environment_state: Dictionary, cell_order: PackedStringArray) -> Dictionary:
	var heat: Dictionary = environment_state.get("heat", {})
	var ordered: Dictionary = {}
	for cell_key: String in cell_order:
		ordered[cell_key] = int(heat.get(cell_key, 0))
	return ordered

func _canonical_placements(committed_input: Dictionary) -> PackedStringArray:
	var placements: Array = committed_input.get("placements", [])
	var encoded: PackedStringArray = PackedStringArray()
	for raw: Variant in placements:
		if not raw is Dictionary:
			return PackedStringArray()
		var placement: Dictionary = raw
		var instance_id: String = String(placement.get("instance_id", ""))
		var anchor: Array = placement.get("anchor", [])
		if instance_id.is_empty() or anchor.size() != 2:
			return PackedStringArray()
		encoded.append("%s@%s,%s:%s" % [
			instance_id,
			str(int(anchor[0])),
			str(int(anchor[1])),
			str(int(placement.get("orientation", 0))),
		])
	encoded.sort()
	return encoded

func _serialize_tick(
		committed_run: Dictionary,
		committed_input: Dictionary,
		canonical_placements: PackedStringArray,
		tick: int,
		active_hazards: PackedStringArray,
		environment_state: Dictionary,
		cell_order: PackedStringArray,
		organisms: Array
) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("rules=" + String(committed_run.get("rules_version", "")))
	parts.append("content=" + String(committed_run.get("content_version", "")))
	parts.append("route=" + String(committed_input.get("route_id", "")))
	parts.append("seed=" + str(int(committed_input.get("seed", 0))))
	parts.append("tick=" + str(tick))
	parts.append("phases=" + PHASE_ORDER_CSV)
	parts.append("active=" + ",".join(active_hazards))
	for placement: String in canonical_placements:
		parts.append("placement=" + placement)
	var heat: Dictionary = environment_state.get("heat", {})
	for cell_key: String in cell_order:
		parts.append("heat=%s:%d" % [cell_key, int(heat.get(cell_key, 0))])
	for raw_organism: Variant in organisms:
		var organism: Dictionary = raw_organism
		var occupied: PackedStringArray = PackedStringArray()
		var occupied_value: Variant = organism.get("occupied_cells", [])
		if occupied_value is Array or occupied_value is PackedStringArray:
			for raw_cell: Variant in occupied_value:
				occupied.append(String(raw_cell))
			occupied.sort()
		parts.append("organism=%s:%d:%s:%s:%s:%s" % [
			String(organism["instance_id"]),
			int(organism["stress"]),
			String(organism["primary_state"]),
			String(organism.get("body_stage", "")),
			",".join(occupied),
			str(bool(organism.get("growth_blocked", false))),
		])
	return "|".join(parts)

func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _definition_failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"route_events": [],
		"hazards_by_id": {},
		"cell_order": PackedStringArray(),
		"initial_environment": {"heat": {}},
		"thermal_enabled": false,
		"thermal_rules": {},
		"organisms": [],
		"growth_requests_by_tick": {},
	}
