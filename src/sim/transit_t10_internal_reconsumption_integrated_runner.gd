extends "res://src/sim/transit_t10_once_carry_integrated_runner.gd"

const T10InternalT06KernelScript := preload("res://src/sim/t06_filter_feeder_kernel.gd")
const T10InternalT07KernelScript := preload("res://src/sim/t07_feeding_kernel.gd")
const T10InternalContaminationKernelScript := preload("res://src/sim/contamination_response_kernel.gd")
const T10InternalT09KernelScript := preload("res://src/sim/t09_symbiotic_buffer_kernel.gd")

const FOOD_EFFECT_KIND := "FOOD_PULSE"
const CLEANSE_EFFECT_KIND := "CONTAMINATION_CLEANSE"

func integrate_effects(base_result: Dictionary, simulation_defs: Dictionary = {}) -> Dictionary:
	var raw_snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	if not raw_snapshots_value is Array:
		return _failure("invalid_t10_internal_raw_snapshots")
	var raw_snapshots: Array = (raw_snapshots_value as Array).duplicate(true)
	var integrated: Dictionary = super.integrate_effects(base_result, simulation_defs)
	if not bool(integrated.get("ok", false)):
		return integrated
	return _reconsume_internal_effects(integrated, raw_snapshots, simulation_defs)

func _reconsume_internal_effects(result: Dictionary, raw_snapshots: Array, simulation_defs: Dictionary) -> Dictionary:
	var snapshots_value: Variant = result.get("end_tick_snapshots", [])
	var checksums_value: Variant = result.get("tick_checksums", PackedStringArray())
	if not snapshots_value is Array:
		return _failure("invalid_t10_internal_snapshots")
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return _failure("invalid_t10_internal_checksums")
	var snapshots: Array = snapshots_value as Array
	if raw_snapshots.size() != snapshots.size():
		return _failure("t10_internal_raw_snapshot_count_mismatch")
	var checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in checksums_value:
		checksums.append(String(raw_checksum))
	if checksums.size() != snapshots.size():
		return _failure("t10_internal_checksum_count_mismatch")

	var rewritten: Array = []
	var rewritten_checksums: PackedStringArray = PackedStringArray()
	var all_food_reconsumption_events: Array = []
	var all_cleanse_reconsumption_events: Array = []
	var food_state_diverged: bool = false
	var cleanse_state_diverged: bool = false

	for index: int in range(snapshots.size()):
		if not snapshots[index] is Dictionary or not raw_snapshots[index] is Dictionary:
			return _failure("invalid_t10_internal_snapshot")
		var snapshot: Dictionary = (snapshots[index] as Dictionary).duplicate(true)
		var raw_snapshot: Dictionary = raw_snapshots[index] as Dictionary
		var previous_snapshot: Dictionary = rewritten[index - 1] as Dictionary if index > 0 else {}
		var previous_food_apps: Array = _internal_application_events(previous_snapshot, FOOD_EFFECT_KIND)
		var previous_cleanse_apps: Array = _internal_application_events(previous_snapshot, CLEANSE_EFFECT_KIND)
		if not previous_food_apps.is_empty():
			food_state_diverged = true
		if not previous_cleanse_apps.is_empty():
			cleanse_state_diverged = true

		var tick_food_events: Array = []
		if food_state_diverged and index > 0:
			var food_result: Dictionary = _reconsume_food_tick(
				snapshot, previous_snapshot, previous_food_apps, simulation_defs
			)
			if not bool(food_result.get("ok", false)):
				return food_result
			snapshot = food_result["snapshot"] as Dictionary
			tick_food_events = food_result["events"] as Array
			for raw_event: Variant in tick_food_events:
				if raw_event is Dictionary:
					all_food_reconsumption_events.append((raw_event as Dictionary).duplicate(true))
		else:
			snapshot = _restore_raw_internal_field(snapshot, raw_snapshot, "satiety")

		var tick_cleanse_events: Array = []
		if cleanse_state_diverged and index > 0:
			var cleanse_result: Dictionary = _reconsume_cleanse_tick(
				snapshot, previous_snapshot, previous_cleanse_apps, simulation_defs
			)
			if not bool(cleanse_result.get("ok", false)):
				return cleanse_result
			snapshot = cleanse_result["snapshot"] as Dictionary
			tick_cleanse_events = cleanse_result["events"] as Array
			for raw_event: Variant in tick_cleanse_events:
				if raw_event is Dictionary:
					all_cleanse_reconsumption_events.append((raw_event as Dictionary).duplicate(true))
		else:
			snapshot = _restore_raw_internal_field(snapshot, raw_snapshot, "contamination_load")
			snapshot = _restore_raw_internal_field(snapshot, raw_snapshot, "contaminated")

		var reapplied: Dictionary = _reapply_current_internal_phase_h(snapshot, simulation_defs)
		if not bool(reapplied.get("ok", false)):
			return reapplied
		snapshot = reapplied["snapshot"] as Dictionary
		snapshot["t10_food_reconsumption_events"] = tick_food_events.duplicate(true)
		snapshot["t10_cleanse_reconsumption_events"] = tick_cleanse_events.duplicate(true)
		rewritten.append(snapshot)
		var checksum_material: String = "%s|t10_food_reconsume=%s|t10_cleanse_reconsume=%s|t10_internal_apps=%s" % [
			String(checksums[index]),
			_serialize_internal_reconsumption(tick_food_events),
			_serialize_internal_reconsumption(tick_cleanse_events),
			_serialize_application_events(snapshot.get("t10_effect_application_events", []) as Array),
		]
		rewritten_checksums.append(checksum_material.sha256_text())

	var next_result: Dictionary = result.duplicate(true)
	next_result["end_tick_snapshots"] = rewritten
	next_result["tick_checksums"] = rewritten_checksums
	next_result["t10_food_reconsumption_events"] = all_food_reconsumption_events
	next_result["t10_cleanse_reconsumption_events"] = all_cleanse_reconsumption_events
	_rebuild_internal_aggregates(next_result, rewritten)
	return next_result

func _reconsume_food_tick(
		snapshot: Dictionary,
		previous_snapshot: Dictionary,
		parent_applications: Array,
		simulation_defs: Dictionary
) -> Dictionary:
	var tick: int = int(snapshot.get("tick", 0))
	if tick <= 0:
		return _failure("invalid_t10_food_reconsumption_tick")
	var runtime_value: Variant = snapshot.get("organism_runtime", null)
	var previous_runtime_value: Variant = previous_snapshot.get("organism_runtime", null)
	if not runtime_value is Array or not previous_runtime_value is Array:
		return _failure("missing_t10_food_runtime_authority")
	var phase_runtime: Array = (runtime_value as Array).duplicate(true)
	var previous_by_id_result: Dictionary = _runtime_dictionary(previous_runtime_value as Array)
	if not bool(previous_by_id_result.get("ok", false)):
		return previous_by_id_result
	var previous_by_id: Dictionary = previous_by_id_result["runtime_by_id"] as Dictionary
	for index: int in range(phase_runtime.size()):
		if not phase_runtime[index] is Dictionary:
			return _failure("invalid_t10_food_runtime")
		var organism: Dictionary = (phase_runtime[index] as Dictionary).duplicate(true)
		var instance_id: String = String(organism.get("instance_id", ""))
		if previous_by_id.has(instance_id):
			var previous: Dictionary = previous_by_id[instance_id] as Dictionary
			if previous.has("satiety"):
				organism["satiety"] = int(previous["satiety"])
		phase_runtime[index] = organism
	_restore_pre_phase_g_primary_states(phase_runtime, snapshot)

	var events: Array = _internal_reconsumption_events(tick, FOOD_EFFECT_KIND, parent_applications, phase_runtime, "satiety")
	var parent_event_by_target: Dictionary = _reconsumption_event_id_by_target(events)
	var t06_value: Variant = simulation_defs.get("t06_definitions", [])
	var t07_producers_value: Variant = simulation_defs.get("t07_producer_definitions", [])
	var t07_consumers_value: Variant = simulation_defs.get("t07_consumer_definitions", [])
	if not t06_value is Array or not t07_producers_value is Array or not t07_consumers_value is Array:
		return _failure("invalid_t10_food_definitions")
	var t06_definitions: Array = (t06_value as Array).duplicate(true)
	var t07_consumers: Array = (t07_consumers_value as Array).duplicate(true)
	var producer_result: Dictionary = _t07_producers_for_food_tick(
		(t07_producers_value as Array).duplicate(true), previous_snapshot, simulation_defs
	)
	if not bool(producer_result.get("ok", false)):
		return producer_result
	var t07_producers: Array = producer_result["producers"] as Array

	var t06_result: Dictionary = {}
	if not t06_definitions.is_empty():
		var contamination_value: Variant = snapshot.get("phase_d_contamination_exposure_by_cell", null)
		if not contamination_value is Dictionary:
			return _failure("missing_t10_food_t06_contamination_authority")
		t06_result = T10InternalT06KernelScript.new().resolve_tick(
			tick, contamination_value as Dictionary, phase_runtime, t06_definitions
		)
		if not bool(t06_result.get("ok", false)):
			return _failure("phase_e_f_t10_food_t06:%s" % String(t06_result.get("error", "unknown")))

	var t07_result: Dictionary = {}
	if not t07_producers.is_empty() and not t07_consumers.is_empty():
		t07_result = T10InternalT07KernelScript.new().resolve_tick(
			tick, phase_runtime, t07_producers, t07_consumers
		)
		if not bool(t07_result.get("ok", false)):
			return _failure("phase_e_f_t10_food_t07:%s" % String(t07_result.get("error", "unknown")))

	var next_runtime: Array = phase_runtime.duplicate(true)
	var t06_events: Array = []
	var t07_events: Array = []
	var shared_events: Array = []
	if not t06_result.is_empty():
		t06_events = (t06_result.get("events", []) as Array).duplicate(true)
		_attach_food_ancestry(t06_events, parent_event_by_target)
	if not t07_result.is_empty():
		t07_events = (t07_result.get("events", []) as Array).duplicate(true)
		_attach_food_ancestry(t07_events, parent_event_by_target)
	if not t06_result.is_empty() and not t07_result.is_empty():
		var composed: Dictionary = _compose_shared_satiety_phase_f(
			tick, phase_runtime, t06_events, t07_events, t06_definitions, t07_consumers
		)
		if not bool(composed.get("ok", false)):
			return composed
		next_runtime = composed["organisms"] as Array
		shared_events = (composed["events"] as Array).duplicate(true)
		_attach_food_ancestry(shared_events, parent_event_by_target)
	elif not t06_result.is_empty():
		next_runtime = t06_result["organisms"] as Array
	elif not t07_result.is_empty():
		next_runtime = t07_result["organisms"] as Array

	var next_snapshot: Dictionary = snapshot.duplicate(true)
	_merge_satiety_into_runtime(next_snapshot, next_runtime)
	if not t06_result.is_empty():
		next_snapshot["contamination_by_cell"] = (t06_result["contamination_by_cell"] as Dictionary).duplicate(true)
		next_snapshot["t06_events"] = t06_events
	if not t07_result.is_empty():
		next_snapshot["t07_events"] = t07_events
		next_snapshot["t07_allocations"] = (t07_result.get("allocations", []) as Array).duplicate(true)
		_update_s05_food_authority(next_snapshot, previous_snapshot, t07_result)
	if not t06_result.is_empty() and not t07_result.is_empty():
		next_snapshot["shared_satiety_events"] = shared_events
	return {"ok": true, "error": "", "snapshot": next_snapshot, "events": events}

func _reconsume_cleanse_tick(
		snapshot: Dictionary,
		previous_snapshot: Dictionary,
		parent_applications: Array,
		simulation_defs: Dictionary
) -> Dictionary:
	var tick: int = int(snapshot.get("tick", 0))
	if tick <= 0:
		return _failure("invalid_t10_cleanse_reconsumption_tick")
	var runtime_value: Variant = snapshot.get("organism_runtime", null)
	var previous_runtime_value: Variant = previous_snapshot.get("organism_runtime", null)
	var field_value: Variant = snapshot.get("phase_d_contamination_exposure_by_cell", null)
	if not runtime_value is Array or not previous_runtime_value is Array or not field_value is Dictionary:
		return _failure("missing_t10_cleanse_authority")
	var runtime: Array = (runtime_value as Array).duplicate(true)
	var previous_by_id_result: Dictionary = _runtime_dictionary(previous_runtime_value as Array)
	if not bool(previous_by_id_result.get("ok", false)):
		return previous_by_id_result
	var previous_by_id: Dictionary = previous_by_id_result["runtime_by_id"] as Dictionary
	for index: int in range(runtime.size()):
		if not runtime[index] is Dictionary:
			return _failure("invalid_t10_cleanse_runtime")
		var organism: Dictionary = (runtime[index] as Dictionary).duplicate(true)
		var instance_id: String = String(organism.get("instance_id", ""))
		if previous_by_id.has(instance_id):
			var previous: Dictionary = previous_by_id[instance_id] as Dictionary
			for field_name: String in ["contamination_load", "contaminated"]:
				if previous.has(field_name):
					organism[field_name] = previous[field_name]
		runtime[index] = organism

	var t09_definitions_result: Dictionary = _prepare_t09_definitions(simulation_defs)
	if not bool(t09_definitions_result.get("ok", false)):
		return t09_definitions_result
	var t09_result: Dictionary = T10InternalT09KernelScript.new().resolve_tick(
		tick, runtime, t09_definitions_result["definitions"] as Array
	)
	if not bool(t09_result.get("ok", false)):
		return _failure("phase_e_t10_cleanse_t09:%s" % String(t09_result.get("error", "unknown")))
	var modifiers: Dictionary = t09_result.get("intake_multiplier_scaled_by_target_id", {}) as Dictionary
	var t09_events: Array = t09_result.get("events", []) as Array
	var modified_result: Dictionary = _runtime_with_t09_intake_modifiers(runtime, modifiers)
	if not bool(modified_result.get("ok", false)):
		return modified_result
	var phase_f_input: Array = modified_result["organisms"] as Array
	var combined_by_id: Dictionary = modified_result["combined_intake_multiplier_scaled_by_id"] as Dictionary
	var kernel: ContaminationResponseKernel = T10InternalContaminationKernelScript.new()
	var sampled: Dictionary = kernel.sample_phase_e(tick, phase_f_input, field_value as Dictionary)
	if not bool(sampled.get("ok", false)):
		return _failure("phase_e_t10_cleanse:%s" % String(sampled.get("error", "unknown")))
	var phase_f: Dictionary = kernel.apply_phase_f(tick, phase_f_input, sampled.get("observations", []) as Array)
	if not bool(phase_f.get("ok", false)):
		return _failure("phase_f_t10_cleanse:%s" % String(phase_f.get("error", "unknown")))
	var augmented_f: Dictionary = _augment_phase_f_t09_evidence(
		phase_f.get("events", []), runtime, modifiers, combined_by_id, t09_events
	)
	if not bool(augmented_f.get("ok", false)):
		return augmented_f
	var restored: Dictionary = _restore_contamination_profiles(phase_f.get("organisms", []), runtime)
	if not bool(restored.get("ok", false)):
		return restored
	var phase_g: Dictionary = kernel.evaluate_phase_g(tick, restored["organisms"] as Array)
	if not bool(phase_g.get("ok", false)):
		return _failure("phase_g_t10_cleanse:%s" % String(phase_g.get("error", "unknown")))

	var events: Array = _internal_reconsumption_events(
		tick, CLEANSE_EFFECT_KIND, parent_applications, runtime, "contamination_load"
	)
	var parent_event_by_target: Dictionary = _reconsumption_event_id_by_target(events)
	var phase_f_events: Array = (augmented_f["events"] as Array).duplicate(true)
	_attach_cleanse_ancestry(phase_f_events, parent_event_by_target)
	var replacement_events: Array = []
	for batch: Variant in [sampled.get("events", []) as Array, t09_events, phase_f_events, phase_g.get("events", []) as Array]:
		for raw_event: Variant in batch as Array:
			if raw_event is Dictionary:
				replacement_events.append((raw_event as Dictionary).duplicate(true))

	var next_snapshot: Dictionary = snapshot.duplicate(true)
	next_snapshot["organism_runtime"] = (phase_g["organisms"] as Array).duplicate(true)
	next_snapshot["t09_intake_multiplier_scaled_by_target_id"] = modifiers.duplicate(true)
	next_snapshot["t09_buffer_events"] = t09_events.duplicate(true)
	next_snapshot["contamination_response_events"] = replacement_events
	return {"ok": true, "error": "", "snapshot": next_snapshot, "events": events}

func _reapply_current_internal_phase_h(snapshot: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var records_value: Variant = snapshot.get("t10_effect_records", [])
	if not records_value is Array:
		return _failure("invalid_t10_internal_effect_records")
	var records: Array = (records_value as Array).duplicate(true)
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("event_id", "")) < String(right.get("event_id", ""))
	)
	var existing_value: Variant = snapshot.get("t10_effect_application_events", [])
	if not existing_value is Array:
		return _failure("invalid_t10_internal_application_events")
	var applications: Array = []
	for raw_event: Variant in existing_value:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			if String(event.get("effect_kind", "")) not in [FOOD_EFFECT_KIND, CLEANSE_EFFECT_KIND]:
				applications.append(event.duplicate(true))
	var carry_value: Variant = snapshot.get("t10_effect_carry_state", _empty_t10_carry())
	var carry: Dictionary = (carry_value as Dictionary).duplicate(true) if carry_value is Dictionary else _empty_t10_carry()
	var organism_carry: Dictionary = carry.get("organism_delta_by_id", {})
	for raw_id: Variant in organism_carry.keys():
		var fields_value: Variant = organism_carry[raw_id]
		if fields_value is Dictionary:
			var fields: Dictionary = fields_value
			fields.erase("satiety")
			fields.erase("contamination_load")
			if fields.is_empty():
				organism_carry.erase(raw_id)
			else:
				organism_carry[raw_id] = fields
	carry["organism_delta_by_id"] = organism_carry
	var next_snapshot: Dictionary = snapshot.duplicate(true)
	for raw_record: Variant in records:
		if not raw_record is Dictionary:
			return _failure("invalid_t10_internal_effect_record")
		var record: Dictionary = raw_record
		var effect_kind: String = String(record.get("kind", ""))
		if effect_kind not in [FOOD_EFFECT_KIND, CLEANSE_EFFECT_KIND]:
			continue
		var applied: Dictionary = _apply_internal_effect(
			next_snapshot, record, effect_kind, int(record.get("magnitude", 0)), carry, simulation_defs
		)
		if not bool(applied.get("ok", false)):
			return applied
		next_snapshot = applied["snapshot"] as Dictionary
		carry = applied["carry"] as Dictionary
		for raw_event: Variant in applied.get("events", []) as Array:
			if raw_event is Dictionary:
				applications.append((raw_event as Dictionary).duplicate(true))
	applications.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("event_id", "")) < String(right.get("event_id", ""))
	)
	next_snapshot["t10_effect_application_events"] = applications
	next_snapshot["t10_effect_carry_state"] = carry.duplicate(true)
	return {"ok": true, "error": "", "snapshot": next_snapshot}

func _t07_producers_for_food_tick(authored: Array, previous_snapshot: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var producers: Array = authored.duplicate(true)
	var states_value: Variant = previous_snapshot.get("s05_support_states", [])
	if not states_value is Array:
		return _failure("invalid_t10_food_s05_states")
	var definitions_value: Variant = simulation_defs.get("support_definitions_by_id", {})
	if not definitions_value is Dictionary:
		return _failure("invalid_t10_food_support_definitions")
	var definitions: Dictionary = definitions_value as Dictionary
	for raw_state: Variant in states_value:
		if not raw_state is Dictionary:
			return _failure("invalid_t10_food_s05_state")
		var state: Dictionary = raw_state
		var support_id: String = String(state.get("support_id", ""))
		var instance_id: String = String(state.get("instance_id", ""))
		if support_id.is_empty() or instance_id.is_empty() or not definitions.has(support_id):
			continue
		var definition_value: Variant = definitions[support_id]
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value
		if String(definition.get("family", support_id)) != "S05":
			continue
		producers.append({
			"instance_id": instance_id,
			"output_units": maxi(1, int(state.get("remaining_food_units", 0))),
			"food_tags": definition.get("food_tags", []),
			"active_primary_states": ["CALM"],
			"active_body_stages": [],
			"sleep_gated": false,
			"source_kind": "S05",
			"finite_reserve_initial": int(state.get("initial_food_units", definition.get("capacity", 0))),
			"finite_reserve_remaining": int(state.get("remaining_food_units", 0)),
			"occupied_cells": state.get("occupied_cells", []),
		})
	return {"ok": true, "error": "", "producers": producers}

func _update_s05_food_authority(snapshot: Dictionary, previous_snapshot: Dictionary, t07_result: Dictionary) -> void:
	var reserve_value: Variant = t07_result.get("producer_reserve_states", [])
	if not reserve_value is Array:
		return
	var reserves: Array = reserve_value
	var remaining_by_id: Dictionary = {}
	for raw_reserve: Variant in reserves:
		if raw_reserve is Dictionary:
			var reserve: Dictionary = raw_reserve
			remaining_by_id[String(reserve.get("instance_id", ""))] = int(reserve.get("remaining_food_units", 0))
	var states_value: Variant = previous_snapshot.get("s05_support_states", [])
	if states_value is Array:
		var states: Array = (states_value as Array).duplicate(true)
		for index: int in range(states.size()):
			if states[index] is Dictionary:
				var state: Dictionary = states[index]
				var instance_id: String = String(state.get("instance_id", ""))
				if remaining_by_id.has(instance_id):
					state["remaining_food_units"] = int(remaining_by_id[instance_id])
					states[index] = state
		snapshot["s05_support_states"] = states
	var feed_events: Array = []
	for raw_event: Variant in t07_result.get("events", []) as Array:
		if raw_event is Dictionary and String((raw_event as Dictionary).get("kind", "")) == "S05_FOOD_RESERVE_ALLOCATED":
			feed_events.append((raw_event as Dictionary).duplicate(true))
	snapshot["s05_feed_events"] = feed_events

func _internal_application_events(snapshot: Dictionary, effect_kind: String) -> Array:
	if snapshot.is_empty():
		return []
	var value: Variant = snapshot.get("t10_effect_application_events", [])
	if not value is Array:
		return []
	var events: Array = []
	for raw_event: Variant in value:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			if String(event.get("kind", "")) == "T10_EFFECT_APPLIED" and String(event.get("effect_kind", "")) == effect_kind and int(event.get("applied_delta", 0)) != 0:
				events.append(event.duplicate(true))
	events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("event_id", "")) < String(right.get("event_id", ""))
	)
	return events

func _internal_reconsumption_events(tick: int, effect_kind: String, applications: Array, runtime: Array, field_name: String) -> Array:
	var runtime_result: Dictionary = _runtime_dictionary(runtime)
	if not bool(runtime_result.get("ok", false)):
		return []
	var runtime_by_id: Dictionary = runtime_result["runtime_by_id"] as Dictionary
	var events: Array = []
	for raw_application: Variant in applications:
		if not raw_application is Dictionary:
			continue
		var application: Dictionary = raw_application
		var target_id: String = String(application.get("target_instance_id", ""))
		if target_id.is_empty() or not runtime_by_id.has(target_id):
			continue
		var organism: Dictionary = runtime_by_id[target_id] as Dictionary
		events.append({
			"event_id": "t%04d:E:T10:%s:%s" % [tick, effect_kind, target_id],
			"tick": tick,
			"phase": "E",
			"kind": "T10_INTERNAL_EFFECT_RECONSUMED",
			"effect_kind": effect_kind,
			"instance_id": target_id,
			"field_name": field_name,
			"carried_value": organism.get(field_name, 0),
			"parent_event_ids": PackedStringArray([String(application.get("event_id", ""))]),
		})
	return events

func _reconsumption_event_id_by_target(events: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			result[String(event.get("instance_id", ""))] = String(event.get("event_id", ""))
	return result

func _attach_food_ancestry(events: Array, parent_event_by_target: Dictionary) -> void:
	for index: int in range(events.size()):
		if not events[index] is Dictionary:
			continue
		var event: Dictionary = events[index]
		var target_id: String = String(event.get("instance_id", event.get("consumer_id", "")))
		if not parent_event_by_target.has(target_id):
			continue
		var parents: PackedStringArray = _string_array(event.get("parent_event_ids", PackedStringArray()))
		var parent_id: String = String(parent_event_by_target[target_id])
		if not parent_id.is_empty() and parent_id not in parents:
			parents.append(parent_id)
		parents.sort()
		event["parent_event_ids"] = parents
		events[index] = event

func _attach_cleanse_ancestry(events: Array, parent_event_by_target: Dictionary) -> void:
	for index: int in range(events.size()):
		if not events[index] is Dictionary:
			continue
		var event: Dictionary = events[index]
		if String(event.get("kind", "")) != "CONTAMINATION_LOAD_INTAKE":
			continue
		var target_id: String = String(event.get("instance_id", ""))
		if not parent_event_by_target.has(target_id):
			continue
		var parents: PackedStringArray = _string_array(event.get("parent_event_ids", PackedStringArray()))
		var parent_id: String = String(parent_event_by_target[target_id])
		if not parent_id.is_empty() and parent_id not in parents:
			parents.append(parent_id)
		parents.sort()
		event["parent_event_ids"] = parents
		events[index] = event

func _runtime_dictionary(runtime: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_organism: Variant in runtime:
		if not raw_organism is Dictionary:
			return _failure("invalid_t10_internal_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or result.has(instance_id):
			return _failure("invalid_t10_internal_runtime_identity")
		result[instance_id] = organism
	return {"ok": true, "error": "", "runtime_by_id": result}

func _restore_pre_phase_g_primary_states(runtime: Array, snapshot: Dictionary) -> void:
	var before_by_id: Dictionary = {}
	var response_value: Variant = snapshot.get("stress_field_response_events", [])
	if response_value is Array:
		for raw_event: Variant in response_value:
			if raw_event is Dictionary:
				var event: Dictionary = raw_event
				if String(event.get("kind", "")) == "STRESS_STATE_TRANSITION":
					before_by_id[String(event.get("instance_id", ""))] = String(event.get("state_before", ""))
	for index: int in range(runtime.size()):
		if runtime[index] is Dictionary:
			var organism: Dictionary = runtime[index]
			var instance_id: String = String(organism.get("instance_id", ""))
			if before_by_id.has(instance_id) and not String(before_by_id[instance_id]).is_empty():
				organism["primary_state"] = String(before_by_id[instance_id])
				runtime[index] = organism

func _merge_satiety_into_runtime(snapshot: Dictionary, satiety_runtime: Array) -> void:
	var value: Variant = snapshot.get("organism_runtime", [])
	if not value is Array:
		return
	var satiety_by_id: Dictionary = {}
	for raw_organism: Variant in satiety_runtime:
		if raw_organism is Dictionary:
			var organism: Dictionary = raw_organism
			if organism.has("satiety"):
				satiety_by_id[String(organism.get("instance_id", ""))] = int(organism["satiety"])
	var runtime: Array = (value as Array).duplicate(true)
	for index: int in range(runtime.size()):
		if runtime[index] is Dictionary:
			var organism: Dictionary = runtime[index]
			var instance_id: String = String(organism.get("instance_id", ""))
			if satiety_by_id.has(instance_id):
				organism["satiety"] = int(satiety_by_id[instance_id])
				runtime[index] = organism
	snapshot["organism_runtime"] = runtime

func _restore_raw_internal_field(snapshot: Dictionary, raw_snapshot: Dictionary, field_name: String) -> Dictionary:
	var runtime_value: Variant = snapshot.get("organism_runtime", [])
	var raw_runtime_value: Variant = raw_snapshot.get("organism_runtime", [])
	if not runtime_value is Array or not raw_runtime_value is Array:
		return snapshot
	var raw_result: Dictionary = _runtime_dictionary(raw_runtime_value as Array)
	if not bool(raw_result.get("ok", false)):
		return snapshot
	var raw_by_id: Dictionary = raw_result["runtime_by_id"] as Dictionary
	var runtime: Array = (runtime_value as Array).duplicate(true)
	for index: int in range(runtime.size()):
		if runtime[index] is Dictionary:
			var organism: Dictionary = runtime[index]
			var instance_id: String = String(organism.get("instance_id", ""))
			if raw_by_id.has(instance_id):
				var raw_organism: Dictionary = raw_by_id[instance_id] as Dictionary
				if raw_organism.has(field_name):
					organism[field_name] = raw_organism[field_name]
					runtime[index] = organism
	var next_snapshot: Dictionary = snapshot.duplicate(true)
	next_snapshot["organism_runtime"] = runtime
	return next_snapshot

func _rebuild_internal_aggregates(result: Dictionary, snapshots: Array) -> void:
	var applications: Array = []
	var t06_events: Array = []
	var t07_events: Array = []
	var t07_allocations: Array = []
	var shared_events: Array = []
	var contamination_events: Array = []
	for raw_snapshot: Variant in snapshots:
		if not raw_snapshot is Dictionary:
			continue
		var snapshot: Dictionary = raw_snapshot
		for pair: Variant in [
			["t10_effect_application_events", applications],
			["t06_events", t06_events],
			["t07_events", t07_events],
			["t07_allocations", t07_allocations],
			["shared_satiety_events", shared_events],
			["contamination_response_events", contamination_events],
		]:
			var key: String = String((pair as Array)[0])
			var target: Array = (pair as Array)[1]
			var value: Variant = snapshot.get(key, [])
			if value is Array:
				for item: Variant in value:
					if item is Dictionary:
						target.append((item as Dictionary).duplicate(true))
	result["t10_effect_application_events"] = applications
	result["t06_events"] = t06_events
	result["t07_events"] = t07_events
	result["t07_allocations"] = t07_allocations
	result["shared_satiety_events"] = shared_events
	result["contamination_response_events"] = contamination_events
	if not snapshots.is_empty() and snapshots[snapshots.size() - 1] is Dictionary:
		var final_snapshot: Dictionary = snapshots[snapshots.size() - 1]
		var runtime_value: Variant = final_snapshot.get("organism_runtime", [])
		if runtime_value is Array:
			result["final_organism_runtime"] = (runtime_value as Array).duplicate(true)
		result["t10_effect_carry_state"] = (final_snapshot.get("t10_effect_carry_state", _empty_t10_carry()) as Dictionary).duplicate(true)

func _serialize_internal_reconsumption(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			parts.append("%s:%s:%s:%s" % [
				String(event.get("event_id", "")),
				String(event.get("effect_kind", "")),
				String(event.get("instance_id", "")),
				str(event.get("parent_event_ids", PackedStringArray())),
			])
	return ";".join(parts)
