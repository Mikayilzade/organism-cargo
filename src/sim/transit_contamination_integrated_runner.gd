extends "res://src/sim/transit_power_integrated_runner_base.gd"

const ContaminationResponseKernelScript := preload("res://src/sim/contamination_response_kernel.gd")
const T09SymbioticBufferKernelScript := preload("res://src/sim/t09_symbiotic_buffer_kernel.gd")
const FixedMathScript := preload("res://src/sim/fixed_math.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var base_result: Dictionary = super.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(base_result.get("ok", false)):
		return base_result

	var contamination_rules_value: Variant = simulation_defs.get("contamination_rules", null)
	if not contamination_rules_value is Dictionary:
		return base_result

	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	if not snapshots_value is Array:
		return _failure("invalid_end_tick_snapshots")
	var snapshots: Array = snapshots_value
	if snapshots.is_empty():
		return base_result

	var first_snapshot_value: Variant = snapshots[0]
	if not first_snapshot_value is Dictionary:
		return _failure("invalid_end_tick_snapshot")
	var first_snapshot: Dictionary = first_snapshot_value
	var first_contamination_value: Variant = first_snapshot.get("phase_d_contamination_exposure_by_cell", first_snapshot.get("contamination_by_cell", {}))
	var first_runtime_value: Variant = first_snapshot.get("organism_runtime", [])
	if not first_contamination_value is Dictionary:
		return _failure("invalid_contamination_snapshot")
	if not first_runtime_value is Array:
		return _failure("invalid_organism_runtime_snapshot")
	var first_contamination: Dictionary = first_contamination_value
	var first_runtime: Array = first_runtime_value
	if first_contamination.is_empty() or first_runtime.is_empty():
		return base_result

	var definitions_value: Variant = simulation_defs.get("organism_definitions", null)
	if not definitions_value is Dictionary:
		return _failure("missing_organism_definitions_for_contamination_response")
	var organism_definitions: Dictionary = definitions_value
	var response_kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var prepared: Dictionary = response_kernel.prepare_runtime(first_runtime, organism_definitions)
	if not bool(prepared.get("ok", false)):
		return _failure("contamination_prepare:%s" % String(prepared.get("error", "unknown")))
	var persisted_runtime: Array = prepared["organisms"]

	var t09_definitions_result: Dictionary = _prepare_t09_definitions(simulation_defs)
	if not bool(t09_definitions_result.get("ok", false)):
		return t09_definitions_result
	var t09_definitions: Array = t09_definitions_result["definitions"]
	var t09_kernel: T09SymbioticBufferKernel = T09SymbioticBufferKernelScript.new()

	var integrated_snapshots: Array = []
	var all_response_events: Array = []
	var all_t09_events: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var base_checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not (base_checksums_value is Array or base_checksums_value is PackedStringArray):
		return _failure("invalid_base_tick_checksums")
	var base_checksums: Array = []
	for raw_checksum: Variant in base_checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return _failure("base_tick_checksum_count_mismatch")

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return _failure("invalid_end_tick_snapshot")
		var raw_snapshot_dictionary: Dictionary = raw_snapshot
		var snapshot: Dictionary = raw_snapshot_dictionary.duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var runtime_value: Variant = snapshot.get("organism_runtime", [])
		var contamination_value: Variant = snapshot.get("phase_d_contamination_exposure_by_cell", snapshot.get("contamination_by_cell", {}))
		if not runtime_value is Array:
			return _failure("invalid_organism_runtime_snapshot")
		if not contamination_value is Dictionary:
			return _failure("invalid_contamination_snapshot")
		var tick_runtime: Array = runtime_value
		var contamination_by_cell: Dictionary = contamination_value
		if index > 0:
			var merged_runtime: Dictionary = _merge_persisted_contamination(tick_runtime, persisted_runtime)
			if not bool(merged_runtime.get("ok", false)):
				return merged_runtime
			persisted_runtime = merged_runtime["organisms"]

		# Phase E first samples the published Phase-D field, then resolves direct
		# interactions from the same pre-F organism snapshot. T09 changes only
		# the target intake multiplier consumed in Phase F.
		var sampled: Dictionary = response_kernel.sample_phase_e(tick, persisted_runtime, contamination_by_cell)
		if not bool(sampled.get("ok", false)):
			return _failure("phase_e:%s" % String(sampled.get("error", "unknown")))
		var t09_result: Dictionary = t09_kernel.resolve_tick(tick, persisted_runtime, t09_definitions)
		if not bool(t09_result.get("ok", false)):
			return _failure("phase_e_t09:%s" % String(t09_result.get("error", "unknown")))
		var t09_modifiers_value: Variant = t09_result.get("intake_multiplier_scaled_by_target_id", {})
		var t09_events_value: Variant = t09_result.get("events", [])
		if not t09_modifiers_value is Dictionary:
			return _failure("invalid_t09_modifier_map")
		if not t09_events_value is Array:
			return _failure("invalid_t09_events")
		var t09_modifiers: Dictionary = t09_modifiers_value
		var t09_events: Array = t09_events_value

		var phase_f_input_result: Dictionary = _runtime_with_t09_intake_modifiers(persisted_runtime, t09_modifiers)
		if not bool(phase_f_input_result.get("ok", false)):
			return phase_f_input_result
		var phase_f_input: Array = phase_f_input_result["organisms"]
		var combined_intake_by_id: Dictionary = phase_f_input_result["combined_intake_multiplier_scaled_by_id"]
		var phase_f: Dictionary = response_kernel.apply_phase_f(tick, phase_f_input, sampled["observations"])
		if not bool(phase_f.get("ok", false)):
			return _failure("phase_f:%s" % String(phase_f.get("error", "unknown")))
		var augmented_f_result: Dictionary = _augment_phase_f_t09_evidence(
			phase_f.get("events", []),
			persisted_runtime,
			t09_modifiers,
			combined_intake_by_id,
			t09_events
		)
		if not bool(augmented_f_result.get("ok", false)):
			return augmented_f_result
		var phase_f_events: Array = augmented_f_result["events"]
		var restored_f_result: Dictionary = _restore_contamination_profiles(phase_f["organisms"], persisted_runtime)
		if not bool(restored_f_result.get("ok", false)):
			return restored_f_result
		var phase_g: Dictionary = response_kernel.evaluate_phase_g(tick, restored_f_result["organisms"])
		if not bool(phase_g.get("ok", false)):
			return _failure("phase_g:%s" % String(phase_g.get("error", "unknown")))
		persisted_runtime = phase_g["organisms"]

		var tick_events: Array = []
		for event_batch: Variant in [sampled.get("events", []), t09_events, phase_f_events, phase_g.get("events", [])]:
			if not event_batch is Array:
				return _failure("invalid_contamination_response_events")
			var events: Array = event_batch
			for raw_event: Variant in events:
				if not raw_event is Dictionary:
					return _failure("invalid_contamination_response_event")
				var event: Dictionary = raw_event
				tick_events.append(event.duplicate(true))
				all_response_events.append(event.duplicate(true))
		for raw_t09_event: Variant in t09_events:
			if not raw_t09_event is Dictionary:
				return _failure("invalid_t09_event")
			var t09_event: Dictionary = raw_t09_event
			all_t09_events.append(t09_event.duplicate(true))

		snapshot["organism_runtime"] = persisted_runtime.duplicate(true)
		snapshot["t09_intake_multiplier_scaled_by_target_id"] = t09_modifiers.duplicate(true)
		snapshot["t09_buffer_events"] = t09_events.duplicate(true)
		snapshot["contamination_response_events"] = tick_events.duplicate(true)
		integrated_snapshots.append(snapshot)
		var checksum_material: String = "%s|t09=%s|contamination_response=%s" % [
			String(base_checksums[index]),
			_serialize_t09_modifiers(t09_modifiers),
			_serialize_contamination_response(persisted_runtime, tick_events),
		]
		integrated_checksums.append(checksum_material.sha256_text())

	base_result["end_tick_snapshots"] = integrated_snapshots
	base_result["tick_checksums"] = integrated_checksums
	base_result["t09_buffer_events"] = all_t09_events
	base_result["contamination_response_events"] = all_response_events
	base_result["final_organism_runtime"] = persisted_runtime.duplicate(true)
	return base_result

func _prepare_t09_definitions(simulation_defs: Dictionary) -> Dictionary:
	var value: Variant = simulation_defs.get("t09_definitions", [])
	if not value is Array:
		return _failure("invalid_t09_definitions")
	var definitions: Array = value
	return {"ok": true, "error": "", "definitions": definitions.duplicate(true)}

func _runtime_with_t09_intake_modifiers(organisms: Array, modifiers_by_target_id: Dictionary) -> Dictionary:
	var results: Array = []
	var combined_by_id: Dictionary = {}
	var matched_targets: Dictionary = {}
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return _failure("invalid_t09_phase_f_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty():
			return _failure("invalid_t09_phase_f_runtime_identity")
		var next: Dictionary = organism.duplicate(true)
		var profile_value: Variant = organism.get("contamination_profile", null)
		if not profile_value is Dictionary:
			return _failure("missing_contamination_profile:%s" % instance_id)
		var profile: Dictionary = profile_value
		var next_profile: Dictionary = profile.duplicate(true)
		var base_multiplier: int = int(profile.get("intake_multiplier_scaled", -1))
		if base_multiplier < 0:
			return _failure("invalid_base_contamination_intake_multiplier:%s" % instance_id)
		var t09_multiplier: int = int(modifiers_by_target_id.get(instance_id, 1000))
		if t09_multiplier <= 0 or t09_multiplier > 1000:
			return _failure("invalid_t09_target_multiplier:%s" % instance_id)
		if modifiers_by_target_id.has(instance_id):
			matched_targets[instance_id] = true
		var combined_multiplier: int = FixedMathScript.mul_non_negative(base_multiplier, t09_multiplier)
		next_profile["intake_multiplier_scaled"] = combined_multiplier
		next["contamination_profile"] = next_profile
		combined_by_id[instance_id] = combined_multiplier
		results.append(next)
	if matched_targets.size() != modifiers_by_target_id.size():
		return _failure("unknown_t09_target_modifier")
	return {
		"ok": true,
		"error": "",
		"organisms": results,
		"combined_intake_multiplier_scaled_by_id": combined_by_id,
	}

func _augment_phase_f_t09_evidence(
		events_value: Variant,
		pre_f_runtime: Array,
		t09_modifiers: Dictionary,
		combined_by_id: Dictionary,
		t09_events: Array
) -> Dictionary:
	if not events_value is Array:
		return _failure("invalid_phase_f_contamination_events")
	var base_multiplier_by_id: Dictionary = {}
	for raw_organism: Variant in pre_f_runtime:
		if not raw_organism is Dictionary:
			return _failure("invalid_pre_f_runtime")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		var profile_value: Variant = organism.get("contamination_profile", null)
		if not profile_value is Dictionary:
			return _failure("missing_contamination_profile:%s" % instance_id)
		var profile: Dictionary = profile_value
		base_multiplier_by_id[instance_id] = int(profile.get("intake_multiplier_scaled", -1))

	var parent_ids_by_target: Dictionary = {}
	for raw_t09_event: Variant in t09_events:
		if not raw_t09_event is Dictionary:
			return _failure("invalid_t09_event")
		var t09_event: Dictionary = raw_t09_event
		var target_id: String = String(t09_event.get("target_instance_id", ""))
		var event_id: String = String(t09_event.get("event_id", ""))
		if target_id.is_empty() or event_id.is_empty():
			return _failure("invalid_t09_event_identity")
		var existing_value: Variant = parent_ids_by_target.get(target_id, PackedStringArray())
		var existing: PackedStringArray = PackedStringArray()
		if existing_value is Array or existing_value is PackedStringArray:
			for raw_parent: Variant in existing_value:
				existing.append(String(raw_parent))
		existing.append(event_id)
		existing.sort()
		parent_ids_by_target[target_id] = existing

	var augmented: Array = []
	var events: Array = events_value
	for raw_event: Variant in events:
		if not raw_event is Dictionary:
			return _failure("invalid_phase_f_contamination_event")
		var event: Dictionary = raw_event
		var next: Dictionary = event.duplicate(true)
		var instance_id: String = String(event.get("instance_id", ""))
		if not base_multiplier_by_id.has(instance_id) or not combined_by_id.has(instance_id):
			return _failure("missing_t09_phase_f_multiplier_evidence:%s" % instance_id)
		var parent_value: Variant = event.get("parent_event_ids", PackedStringArray())
		var parents: PackedStringArray = PackedStringArray()
		if parent_value is Array or parent_value is PackedStringArray:
			for raw_parent: Variant in parent_value:
				parents.append(String(raw_parent))
		var t09_parent_value: Variant = parent_ids_by_target.get(instance_id, PackedStringArray())
		if t09_parent_value is Array or t09_parent_value is PackedStringArray:
			for raw_t09_parent: Variant in t09_parent_value:
				parents.append(String(raw_t09_parent))
		parents.sort()
		next["parent_event_ids"] = parents
		next["base_intake_multiplier_scaled"] = int(base_multiplier_by_id[instance_id])
		next["t09_intake_multiplier_scaled"] = int(t09_modifiers.get(instance_id, 1000))
		next["combined_intake_multiplier_scaled"] = int(combined_by_id[instance_id])
		augmented.append(next)
	return {"ok": true, "error": "", "events": augmented}

func _restore_contamination_profiles(current_runtime: Array, authority_runtime: Array) -> Dictionary:
	var profile_by_id: Dictionary = {}
	for raw_authority: Variant in authority_runtime:
		if not raw_authority is Dictionary:
			return _failure("invalid_contamination_profile_authority")
		var authority: Dictionary = raw_authority
		var instance_id: String = String(authority.get("instance_id", ""))
		var profile_value: Variant = authority.get("contamination_profile", null)
		if instance_id.is_empty() or not profile_value is Dictionary:
			return _failure("invalid_contamination_profile_authority")
		var profile: Dictionary = profile_value
		profile_by_id[instance_id] = profile.duplicate(true)
	var restored: Array = []
	for raw_current: Variant in current_runtime:
		if not raw_current is Dictionary:
			return _failure("invalid_phase_f_contamination_runtime")
		var current: Dictionary = raw_current
		var instance_id: String = String(current.get("instance_id", ""))
		if not profile_by_id.has(instance_id):
			return _failure("missing_contamination_profile_authority:%s" % instance_id)
		var next: Dictionary = current.duplicate(true)
		next["contamination_profile"] = profile_by_id[instance_id]
		restored.append(next)
	if restored.size() != authority_runtime.size():
		return _failure("contamination_profile_authority_identity_mismatch")
	return {"ok": true, "error": "", "organisms": restored}

func _merge_persisted_contamination(current_runtime: Array, previous_runtime: Array) -> Dictionary:
	var previous_by_id: Dictionary = {}
	for raw_previous: Variant in previous_runtime:
		if not raw_previous is Dictionary:
			return _failure("invalid_previous_contamination_runtime")
		var previous: Dictionary = raw_previous
		var instance_id: String = String(previous.get("instance_id", ""))
		if instance_id.is_empty() or previous_by_id.has(instance_id):
			return _failure("invalid_previous_contamination_runtime_identity")
		previous_by_id[instance_id] = previous

	var merged: Array = []
	for raw_current: Variant in current_runtime:
		if not raw_current is Dictionary:
			return _failure("invalid_current_contamination_runtime")
		var current: Dictionary = raw_current
		var instance_id: String = String(current.get("instance_id", ""))
		if not previous_by_id.has(instance_id):
			return _failure("missing_previous_contamination_runtime:%s" % instance_id)
		var previous: Dictionary = previous_by_id[instance_id]
		var profile_value: Variant = previous.get("contamination_profile", null)
		if not profile_value is Dictionary:
			return _failure("missing_previous_contamination_profile:%s" % instance_id)
		var profile: Dictionary = profile_value
		var next: Dictionary = current.duplicate(true)
		next["contamination_profile"] = profile.duplicate(true)
		next["contamination_load"] = int(previous.get("contamination_load", 0))
		next["contaminated"] = bool(previous.get("contaminated", false))
		merged.append(next)
	if merged.size() != previous_runtime.size():
		return _failure("contamination_runtime_identity_mismatch")
	merged.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))
	)
	return {"ok": true, "error": "", "organisms": merged}

func _serialize_t09_modifiers(modifiers: Dictionary) -> String:
	var ids: Array = modifiers.keys()
	ids.sort()
	var parts: PackedStringArray = PackedStringArray()
	for raw_id: Variant in ids:
		var instance_id: String = String(raw_id)
		parts.append("%s:%d" % [instance_id, int(modifiers[raw_id])])
	return ",".join(parts)

func _serialize_contamination_response(organisms: Array, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_organism: Variant in organisms:
		if raw_organism is Dictionary:
			var organism: Dictionary = raw_organism
			parts.append("org:%s:%d:%s" % [
				String(organism.get("instance_id", "")),
				int(organism.get("contamination_load", 0)),
				str(bool(organism.get("contaminated", false))),
			])
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			var parents_value: Variant = event.get("parent_event_ids", PackedStringArray())
			var parents: PackedStringArray = PackedStringArray()
			if parents_value is Array or parents_value is PackedStringArray:
				for raw_parent: Variant in parents_value:
					parents.append(String(raw_parent))
			parents.sort()
			parts.append("event:%s:%s:%s:%s:%s:%s:%d:%d:%d" % [
				String(event.get("event_id", "")),
				String(event.get("phase", "")),
				String(event.get("kind", "")),
				String(event.get("source_instance_id", "")),
				String(event.get("target_instance_id", event.get("instance_id", ""))),
				",".join(parents),
				int(event.get("base_intake_multiplier_scaled", 0)),
				int(event.get("t09_intake_multiplier_scaled", event.get("source_intake_multiplier_scaled", 0))),
				int(event.get("combined_intake_multiplier_scaled", event.get("combined_target_intake_multiplier_scaled", 0))),
			])
	return ";".join(parts)