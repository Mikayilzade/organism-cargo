class_name PhaseBGrowthResolver
extends RefCounted

const BlockedGrowthEpisodeResolverScript := preload("res://src/sim/blocked_growth_episode_resolver.gd")

func resolve_tick(
		organisms: Array,
		usable_cells: PackedStringArray,
		growth_requests: Array,
		retry_boundary: String = ""
) -> Dictionary:
	var by_id: Dictionary = {}
	var occupied: Dictionary = {}
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return _failure("invalid_organism_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or by_id.has(instance_id):
			return _failure("invalid_organism_runtime")
		by_id[instance_id] = organism.duplicate(true)
		var raw_cells: Variant = organism.get("occupied_cells", [])
		if not raw_cells is Array and not raw_cells is PackedStringArray:
			return _failure("invalid_organism_occupancy")
		for raw_cell: Variant in raw_cells:
			var cell: String = String(raw_cell)
			if cell.is_empty() or occupied.has(cell):
				return _failure("invalid_organism_occupancy")
			occupied[cell] = instance_id

	var usable: Dictionary = {}
	for cell: String in usable_cells:
		usable[cell] = true

	var requests: Array = growth_requests.duplicate(true)
	requests.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))
	)
	var reserved_targets: Dictionary = {}
	var events: Array = []
	for raw_request: Variant in requests:
		if not raw_request is Dictionary:
			return _failure("invalid_growth_request")
		var request: Dictionary = raw_request
		var instance_id: String = String(request.get("instance_id", ""))
		if instance_id.is_empty() or not by_id.has(instance_id):
			return _failure("unknown_growth_instance")
		var organism: Dictionary = by_id[instance_id]
		var next_stage: String = String(request.get("next_body_stage", ""))
		if next_stage.is_empty():
			return _failure("missing_next_body_stage")
		var footprint_result: Dictionary = _footprint_for_stage(organism, next_stage)
		if not bool(footprint_result["ok"]):
			return _failure(String(footprint_result["error"]))
		var next_cells: PackedStringArray = footprint_result["cells"]
		var current_cells: PackedStringArray = _sorted_cells(organism.get("occupied_cells", []))
		var required_cells: PackedStringArray = PackedStringArray()
		var illegal_cells: PackedStringArray = PackedStringArray()
		var required_occupancy: Dictionary = {}
		var legal: bool = true
		for cell: String in next_cells:
			if not current_cells.has(cell):
				required_cells.append(cell)
				if not usable.has(cell):
					illegal_cells.append(cell)
					legal = false
				elif occupied.has(cell) and String(occupied[cell]) != instance_id:
					required_occupancy[cell] = String(occupied[cell])
					legal = false
				elif reserved_targets.has(cell):
					return _failure("simultaneous_growth_conflict_not_implemented")
		for cell: String in required_cells:
			reserved_targets[cell] = instance_id
		var episode_state_value: Variant = organism.get("growth_episode_state", {})
		if not episode_state_value is Dictionary:
			return _failure("invalid_growth_episode_state")
		var episode_state: Dictionary = episode_state_value
		var attempt: Dictionary = {
			"legal": legal,
			"required_cells": Array(required_cells),
			"illegal_cells": Array(illegal_cells),
			"occupied_cells": required_occupancy,
			"orientation": str(int(organism.get("orientation", 0))),
			"body_condition": "%s_TO_%s" % [String(organism.get("body_stage", "")), next_stage],
			"growth_trigger_condition": String(request.get("growth_trigger_condition", "qualified")),
			"retry_boundary": String(request.get("retry_boundary", retry_boundary)),
			"material_parent_ids": request.get("material_parent_ids", []),
		}
		var episode_resolver: BlockedGrowthEpisodeResolver = BlockedGrowthEpisodeResolverScript.new()
		var resolved: Dictionary = episode_resolver.resolve_attempt(instance_id, episode_state, attempt)
		if not bool(resolved["ok"]):
			return _failure("blocked_growth:%s" % String(resolved["error"]))
		organism["growth_episode_state"] = resolved["state"]
		organism["growth_blocked"] = not bool(resolved["growth_allowed"])
		if bool(resolved["growth_allowed"]):
			for cell: String in current_cells:
				occupied.erase(cell)
			for cell: String in next_cells:
				occupied[cell] = instance_id
			organism["body_stage"] = next_stage
			organism["occupied_cells"] = Array(next_cells)
		else:
			var causal_value: Variant = resolved.get("causal_event", {})
			if causal_value is Dictionary:
				var causal_event: Dictionary = causal_value
				if not causal_event.is_empty():
					events.append(causal_event.duplicate(true))
		by_id[instance_id] = organism

	var next_organisms: Array = []
	var ids: Array = by_id.keys()
	ids.sort()
	for raw_id: Variant in ids:
		next_organisms.append(by_id[String(raw_id)])
	return {"ok": true, "error": "", "organisms": next_organisms, "growth_events": events}

func _footprint_for_stage(organism: Dictionary, stage: String) -> Dictionary:
	var stages_value: Variant = organism.get("body_stages", {})
	if not stages_value is Dictionary:
		return {"ok": false, "error": "missing_body_stages", "cells": PackedStringArray()}
	var stages: Dictionary = stages_value
	if not stages.has(stage) or not stages[stage] is Dictionary:
		return {"ok": false, "error": "missing_body_stage:%s" % stage, "cells": PackedStringArray()}
	var stage_definition: Dictionary = stages[stage]
	var footprints_value: Variant = stage_definition.get("footprints", {})
	if not footprints_value is Dictionary:
		return {"ok": false, "error": "missing_stage_footprints", "cells": PackedStringArray()}
	var footprints: Dictionary = footprints_value
	var orientation: int = int(organism.get("orientation", 0))
	var orientation_key: String = str(orientation)
	if not footprints.has(orientation_key) or not footprints[orientation_key] is Array:
		return {"ok": false, "error": "missing_stage_orientation", "cells": PackedStringArray()}
	var anchor_value: Variant = organism.get("anchor", [])
	if not anchor_value is Array:
		return {"ok": false, "error": "invalid_growth_anchor", "cells": PackedStringArray()}
	var anchor: Array = anchor_value
	if anchor.size() != 2:
		return {"ok": false, "error": "invalid_growth_anchor", "cells": PackedStringArray()}
	var cells: PackedStringArray = PackedStringArray()
	var offsets: Array = footprints[orientation_key]
	for raw_offset: Variant in offsets:
		if not raw_offset is Array:
			return {"ok": false, "error": "invalid_stage_footprint", "cells": PackedStringArray()}
		var offset: Array = raw_offset
		if offset.size() != 2:
			return {"ok": false, "error": "invalid_stage_footprint", "cells": PackedStringArray()}
		cells.append(_cell_key(int(anchor[0]) + int(offset[0]), int(anchor[1]) + int(offset[1])))
	cells.sort()
	return {"ok": true, "error": "", "cells": cells}

func _sorted_cells(value: Variant) -> PackedStringArray:
	var cells: PackedStringArray = PackedStringArray()
	if not value is Array and not value is PackedStringArray:
		return cells
	for raw_cell: Variant in value:
		cells.append(String(raw_cell))
	cells.sort()
	return cells

func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error, "organisms": [], "growth_events": []}
