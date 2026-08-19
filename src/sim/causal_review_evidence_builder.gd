class_name CausalReviewEvidenceBuilder
extends RefCounted

func build(completed_result: Dictionary) -> Dictionary:
	if not bool(completed_result.get("ok", false)) or not bool(completed_result.get("completed", false)):
		return _failure("incomplete_authoritative_result")
	var snapshots_value: Variant = completed_result.get("end_tick_snapshots", null)
	if not snapshots_value is Array:
		return _failure("missing_transit_snapshots")
	var snapshots: Array = snapshots_value
	if snapshots.is_empty():
		return _failure("missing_transit_snapshots")
	var delivery_value: Variant = completed_result.get("delivery_result", null)
	if not delivery_value is Dictionary:
		return _failure("missing_delivery_result")
	var delivery_result: Dictionary = delivery_value
	var predicate_results_value: Variant = delivery_result.get("predicate_results", null)
	if not predicate_results_value is Array:
		return _failure("missing_predicate_results")
	var predicate_results: Array = predicate_results_value

	var events: Array = []
	var previous_organisms: Dictionary = {}
	var latest_organism_event: Dictionary = {}
	var first_meaningful_event_id: String = ""
	var first_actionable_event_id: String = ""
	var final_tick: int = 0

	for snapshot_value: Variant in snapshots:
		if not snapshot_value is Dictionary:
			return _failure("invalid_transit_snapshot")
		var snapshot: Dictionary = snapshot_value
		var tick: int = int(snapshot.get("tick", 0))
		if tick <= final_tick:
			return _failure("non_monotonic_snapshot_tick")
		final_tick = tick

		var same_tick_roots: PackedStringArray = PackedStringArray()
		var hazards_value: Variant = snapshot.get("active_hazards", PackedStringArray())
		var hazard_ids: PackedStringArray = _normalized_string_list(hazards_value)
		for hazard_id: String in hazard_ids:
			var hazard_event_id: String = "t%06d:h:%s" % [tick, hazard_id]
			events.append({
				"event_id": hazard_event_id,
				"tick": tick,
				"kind": "HAZARD_ACTIVE",
				"source_id": hazard_id,
				"parent_event_ids": PackedStringArray(),
			})
			same_tick_roots.append(hazard_event_id)
			if first_meaningful_event_id.is_empty():
				first_meaningful_event_id = hazard_event_id

		var organisms_value: Variant = snapshot.get("organisms", [])
		if not organisms_value is Array:
			return _failure("invalid_snapshot_organisms")
		var organisms: Array = organisms_value
		var ordered_ids: PackedStringArray = PackedStringArray()
		var current_by_id: Dictionary = {}
		for organism_value: Variant in organisms:
			if not organism_value is Dictionary:
				return _failure("invalid_snapshot_organism")
			var organism: Dictionary = organism_value
			var instance_id: String = String(organism.get("instance_id", ""))
			if instance_id.is_empty() or current_by_id.has(instance_id):
				return _failure("invalid_snapshot_organism_id")
			current_by_id[instance_id] = organism
			ordered_ids.append(instance_id)
		ordered_ids.sort()

		for instance_id: String in ordered_ids:
			var current_organism: Dictionary = current_by_id[instance_id]
			if previous_organisms.has(instance_id):
				var previous_value: Variant = previous_organisms[instance_id]
				if not previous_value is Dictionary:
					return _failure("invalid_previous_organism")
				var previous_organism: Dictionary = previous_value
				var previous_stress: int = int(previous_organism.get("stress", 0))
				var current_stress: int = int(current_organism.get("stress", 0))
				var previous_state: String = String(previous_organism.get("primary_state", ""))
				var current_state: String = String(current_organism.get("primary_state", ""))
				if previous_stress != current_stress or previous_state != current_state:
					var response_event_id: String = "t%06d:o:%s" % [tick, instance_id]
					events.append({
						"event_id": response_event_id,
						"tick": tick,
						"kind": "ORGANISM_RESPONSE",
						"instance_id": instance_id,
						"stress_before": previous_stress,
						"stress_after": current_stress,
						"state_before": previous_state,
						"state_after": current_state,
						"parent_event_ids": same_tick_roots.duplicate(),
					})
					latest_organism_event[instance_id] = response_event_id
					if first_meaningful_event_id.is_empty():
						first_meaningful_event_id = response_event_id
					if first_actionable_event_id.is_empty():
						first_actionable_event_id = response_event_id
		previous_organisms = current_by_id.duplicate(true)

	var objective_events: Array = []
	for predicate_value: Variant in predicate_results:
		if not predicate_value is Dictionary:
			return _failure("invalid_predicate_result")
		var predicate_result: Dictionary = predicate_value
		var predicate_id: String = String(predicate_result.get("id", ""))
		var instance_id: String = String(predicate_result.get("instance_id", ""))
		if predicate_id.is_empty() or instance_id.is_empty():
			return _failure("invalid_predicate_result")
		var parents: PackedStringArray = PackedStringArray()
		if latest_organism_event.has(instance_id):
			parents.append(String(latest_organism_event[instance_id]))
		var objective_event: Dictionary = {
			"event_id": "result:p:%s" % predicate_id,
			"tick": final_tick,
			"kind": "MANDATORY_PREDICATE",
			"predicate_id": predicate_id,
			"instance_id": instance_id,
			"predicate_kind": String(predicate_result.get("kind", "")),
			"required": predicate_result.get("required", null),
			"observed": predicate_result.get("observed", null),
			"passed": bool(predicate_result.get("passed", false)),
			"parent_event_ids": parents,
		}
		objective_events.append(objective_event)
		events.append(objective_event)

	return {
		"ok": true,
		"events": events,
		"objective_events": objective_events,
		"first_meaningful_event_id": first_meaningful_event_id,
		"first_actionable_event_id": first_actionable_event_id,
		"delivery_success": bool(delivery_result.get("success", false)),
		"review_checksum": _checksum(events, delivery_result),
	}

func _normalized_string_list(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		result = value
	elif value is Array:
		var values: Array = value
		for raw_value: Variant in values:
			result.append(String(raw_value))
	result.sort()
	return result

func _checksum(events: Array, delivery_result: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("delivery_success=%s" % ("1" if bool(delivery_result.get("success", false)) else "0"))
	for event_value: Variant in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		parts.append(JSON.stringify(event, "", true, true))
	return "|".join(parts).sha256_text()

func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"events": [],
		"objective_events": [],
		"first_meaningful_event_id": "",
		"first_actionable_event_id": "",
		"delivery_success": false,
		"review_checksum": "",
	}
