class_name TransitSliceRunner
extends RefCounted

const PHASE_ORDER := PackedStringArray(["A", "B", "C", "D", "E", "F", "G", "H", "I"])

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

	var phase_trace: PackedStringArray = PackedStringArray()
	var tick_checksums: PackedStringArray = PackedStringArray()
	var end_tick_snapshots: Array = []
	for tick: int in range(1, total_ticks + 1):
		phase_trace.append("%d:A" % tick)
		var active_hazards: PackedStringArray = _phase_a_route_input(tick, route_events)

		phase_trace.append("%d:B" % tick)

		phase_trace.append("%d:C" % tick)
		var generated_environment: Dictionary = _phase_c_generate_channels(
			environment_state,
			active_hazards,
			hazards_by_id,
			cell_order
		)

		phase_trace.append("%d:D" % tick)
		environment_state = _phase_d_publish_exposure(generated_environment)

		for phase: String in PackedStringArray(["E", "F", "G", "H", "I"]):
			phase_trace.append("%d:%s" % [tick, phase])

		var snapshot: Dictionary = {
			"tick": tick,
			"active_hazards": active_hazards,
			"heat_by_cell": _heat_snapshot(environment_state, cell_order),
		}
		end_tick_snapshots.append(snapshot)
		var serialized_tick: String = _serialize_tick(
			committed_run,
			committed_input,
			canonical_placements,
			tick,
			active_hazards,
			environment_state,
			cell_order
		)
		tick_checksums.append(serialized_tick.sha256_text())

	return {
		"ok": true,
		"tick_checksums": tick_checksums,
		"phase_trace": phase_trace,
		"end_tick_snapshots": end_tick_snapshots,
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

	return {
		"ok": true,
		"error": "",
		"route_events": route_events,
		"hazards_by_id": hazards_by_id,
		"cell_order": cell_order,
		"initial_environment": {"heat": heat},
	}

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
	var heat: Dictionary = generated.get("heat", {}).duplicate(true)
	for hazard_id: String in active_hazards:
		var hazard: Dictionary = hazards_by_id[hazard_id]
		var heat_delta: int = int(hazard["heat_delta"])
		for cell_key: String in cell_order:
			heat[cell_key] = int(heat.get(cell_key, 0)) + heat_delta
	generated["heat"] = heat
	return generated

func _phase_d_publish_exposure(generated_environment: Dictionary) -> Dictionary:
	# The vertical slice now owns the Phase-D exposure boundary. Spatial transfer,
	# venting and clamps stay absent until their authored parameters are introduced.
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
		cell_order: PackedStringArray
) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("rules=" + String(committed_run.get("rules_version", "")))
	parts.append("content=" + String(committed_run.get("content_version", "")))
	parts.append("route=" + String(committed_input.get("route_id", "")))
	parts.append("seed=" + str(int(committed_input.get("seed", 0))))
	parts.append("tick=" + str(tick))
	parts.append("phases=" + ",".join(PHASE_ORDER))
	parts.append("active=" + ",".join(active_hazards))
	for placement: String in canonical_placements:
		parts.append("placement=" + placement)
	var heat: Dictionary = environment_state.get("heat", {})
	for cell_key: String in cell_order:
		parts.append("heat=%s:%d" % [cell_key, int(heat.get(cell_key, 0))])
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
	}
