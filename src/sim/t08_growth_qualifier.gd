class_name T08GrowthQualifier
extends RefCounted

func evaluate_tick(
		tick: int,
		trigger_definitions: Array,
		qualification_by_instance: Dictionary,
		previous_state: Dictionary = {}
) -> Dictionary:
	if tick <= 0:
		return _failure("invalid_tick")
	var definitions: Array = trigger_definitions.duplicate(true)
	definitions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_instance: String = String(left.get("instance_id", ""))
		var right_instance: String = String(right.get("instance_id", ""))
		if left_instance != right_instance:
			return left_instance < right_instance
		return String(left.get("trigger_id", "")) < String(right.get("trigger_id", ""))
	)
	var state: Dictionary = previous_state.duplicate(true)
	var queued_requests: Array = []
	var seen_instances: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			return _failure("invalid_t08_definition")
		var definition: Dictionary = raw_definition
		var instance_id: String = String(definition.get("instance_id", ""))
		var trigger_id: String = String(definition.get("trigger_id", ""))
		var next_body_stage: String = String(definition.get("next_body_stage", ""))
		var required_ticks: int = int(definition.get("required_qualifying_ticks", 0))
		if instance_id.is_empty() or trigger_id.is_empty() or next_body_stage.is_empty() or required_ticks <= 0:
			return _failure("invalid_t08_definition")
		if seen_instances.has(instance_id):
			return _failure("multiple_t08_triggers_per_instance_not_implemented")
		seen_instances[instance_id] = true
		var qualification_value: Variant = qualification_by_instance.get(instance_id, false)
		if not qualification_value is bool:
			return _failure("invalid_t08_qualification:%s" % instance_id)
		var qualified: bool = bool(qualification_value)
		var prior_value: Variant = state.get(instance_id, {})
		if not prior_value is Dictionary:
			return _failure("invalid_t08_state:%s" % instance_id)
		var prior: Dictionary = prior_value
		var consecutive_ticks: int = int(prior.get("consecutive_ticks", 0))
		var qualification_epoch: int = max(1, int(prior.get("qualification_epoch", 1)))
		var qualifying_active: bool = bool(prior.get("qualifying_active", false))
		var queued_in_active_window: bool = bool(prior.get("queued_in_active_window", false))

		if qualified:
			consecutive_ticks = consecutive_ticks + 1 if qualifying_active else 1
			qualifying_active = true
			if consecutive_ticks >= required_ticks and not queued_in_active_window:
				queued_in_active_window = true
				var parent_ids: Array = []
				var parent_ids_value: Variant = definition.get("material_parent_ids", [])
				if not parent_ids_value is Array:
					return _failure("invalid_t08_material_parents:%s" % instance_id)
				for raw_parent_id: Variant in parent_ids_value:
					var parent_id: String = String(raw_parent_id)
					if not parent_id.is_empty() and not parent_ids.has(parent_id):
						parent_ids.append(parent_id)
				parent_ids.sort()
				queued_requests.append({
					"instance_id": instance_id,
					"next_body_stage": next_body_stage,
					"growth_trigger_condition": "%s#%d" % [trigger_id, qualification_epoch],
					"material_parent_ids": parent_ids,
					"apply_tick": tick + 1,
				})
		else:
			if qualifying_active:
				qualification_epoch += 1
			consecutive_ticks = 0
			qualifying_active = false
			queued_in_active_window = false

		state[instance_id] = {
			"trigger_id": trigger_id,
			"next_body_stage": next_body_stage,
			"required_qualifying_ticks": required_ticks,
			"consecutive_ticks": consecutive_ticks,
			"qualification_epoch": qualification_epoch,
			"qualifying_active": qualifying_active,
			"queued_in_active_window": queued_in_active_window,
		}

	return {
		"ok": true,
		"error": "",
		"state": state,
		"queued_requests": queued_requests,
	}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error, "state": {}, "queued_requests": []}
