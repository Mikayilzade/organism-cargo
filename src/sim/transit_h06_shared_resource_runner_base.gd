extends "res://src/sim/transit_h05_shared_resource_runner_base.gd"

# Production Phase-D bridge for H06. The H05 runner already owns the real
# heat/contamination transit composition; this subclass widens only the hazard
# authority passed into the frozen shared Phase-D resolver.
func _has_relevant_h05_route_event(
		simulation_defs: Dictionary,
		total_ticks: int,
		channels: PackedStringArray
) -> bool:
	return super._has_relevant_h05_route_event(simulation_defs, total_ticks, channels) \
		or _has_relevant_h06_route_event(simulation_defs, total_ticks)

func _defs_without_integrated_hazards(simulation_defs: Dictionary) -> Dictionary:
	var stripped: Dictionary = super._defs_without_integrated_hazards(simulation_defs)
	var route_value: Variant = stripped.get("route_profile", {})
	var hazards_value: Variant = stripped.get("hazards_by_id", {})
	if not route_value is Dictionary or not hazards_value is Dictionary:
		return stripped
	var route_profile: Dictionary = route_value
	var hazards: Dictionary = hazards_value
	var retained_events: Array = []
	for raw_event: Variant in route_profile.get("events", []):
		if not raw_event is Dictionary:
			continue
		var route_event: Dictionary = raw_event
		var hazard_id: String = String(route_event.get("hazard_id", ""))
		var hazard_value: Variant = hazards.get(hazard_id, {})
		if hazard_value is Dictionary and String((hazard_value as Dictionary).get("family", "")) == "H06":
			continue
		retained_events.append(route_event.duplicate(true))
	route_profile["events"] = retained_events
	var retained_hazards: Dictionary = {}
	for raw_id: Variant in hazards.keys():
		var hazard_id: String = String(raw_id)
		var hazard_value: Variant = hazards[raw_id]
		if hazard_value is Dictionary and String((hazard_value as Dictionary).get("family", "")) == "H06":
			continue
		retained_hazards[hazard_id] = (hazard_value as Dictionary).duplicate(true) if hazard_value is Dictionary else hazard_value
	stripped["route_profile"] = route_profile
	stripped["hazards_by_id"] = retained_hazards
	return stripped

func _scoped_h05_authority(
		active_hazards: PackedStringArray,
		hazards_by_id: Dictionary,
		channels: PackedStringArray
) -> Dictionary:
	var scoped: Dictionary = super._scoped_h05_authority(active_hazards, hazards_by_id, channels)
	if not bool(scoped.get("ok", false)):
		return scoped
	var scoped_active: PackedStringArray = scoped["active_hazards"]
	var scoped_hazards: Dictionary = scoped["hazards_by_id"]
	for hazard_id: String in active_hazards:
		if not hazards_by_id.has(hazard_id) or not hazards_by_id[hazard_id] is Dictionary:
			return {"ok": false, "error": "missing_hazard_definition:%s" % hazard_id}
		var hazard: Dictionary = hazards_by_id[hazard_id]
		if String(hazard.get("family", "")) != "H06":
			continue
		if not hazard.get("isolated_edges", null) is Array:
			return {"ok": false, "error": "invalid_h06_isolated_edges:%s" % hazard_id}
		if not hazard_id in scoped_active:
			scoped_active.append(hazard_id)
		scoped_hazards[hazard_id] = hazard.duplicate(true)
	scoped_active.sort()
	return {"ok": true, "error": "", "active_hazards": scoped_active, "hazards_by_id": scoped_hazards}

func _has_relevant_h06_route_event(simulation_defs: Dictionary, total_ticks: int) -> bool:
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
		if hazard_value is Dictionary and String((hazard_value as Dictionary).get("family", "")) == "H06":
			return true
	return false
