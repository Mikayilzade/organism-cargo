extends "res://src/sim/transit_t10_contamination_t09_reconsumption_integrated_runner.gd"

const T10DormantContaminationResponseKernelScript := preload("res://src/sim/contamination_response_kernel.gd")
const T10DormantT09SymbioticBufferKernelScript := preload("res://src/sim/t09_symbiotic_buffer_kernel.gd")
const T10DormantTransitSliceRunnerScript := preload("res://src/sim/transit_slice_runner.gd")

# T10 CONTAMINATION_PULSE can be the first/only contamination producer in a run.
# The H05 stress-response composition delegates its base simulation through a
# sibling runner, so a top-level _prepare_power_authority override alone cannot
# establish the dormant contamination field. Normalize that missing zero-field
# authority at the T10 composition boundary before effect application and before
# the next-tick contamination/T09 reconsumption pass.
func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(result.get("ok", false)):
		return result
	return _ensure_dormant_contamination_authority(result, simulation_defs)

func integrate_effects(base_result: Dictionary, simulation_defs: Dictionary = {}) -> Dictionary:
	var prepared: Dictionary = _ensure_dormant_contamination_authority(base_result, simulation_defs)
	if not bool(prepared.get("ok", false)):
		return prepared
	return super.integrate_effects(prepared, simulation_defs)

func _ensure_dormant_contamination_authority(base_result: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var rules_value: Variant = simulation_defs.get("contamination_rules", null)
	if not rules_value is Dictionary:
		return base_result
	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	if not snapshots_value is Array:
		return _failure("invalid_t10_contamination_authority_snapshots")
	var snapshots: Array = snapshots_value as Array
	if snapshots.is_empty():
		return base_result
	var first_value: Variant = snapshots[0]
	if not first_value is Dictionary:
		return _failure("invalid_t10_contamination_authority_snapshot")
	var first: Dictionary = first_value as Dictionary
	var existing_field_value: Variant = first.get("phase_d_contamination_exposure_by_cell", null)
	# This normalization owns only the truly dormant channel case. If the inherited
	# production path already published a Phase-D contamination field, preserve that
	# path byte-for-byte even when a narrower test/consumer does not request organism
	# contamination-response evidence.
	if existing_field_value is Dictionary and not (existing_field_value as Dictionary).is_empty():
		return base_result

	var hold_value: Variant = simulation_defs.get("hold_definition", null)
	var definitions_value: Variant = simulation_defs.get("organism_definitions", null)
	if not hold_value is Dictionary:
		return _failure("missing_hold_definition_for_t10_contamination_authority")
	if not definitions_value is Dictionary:
		return _failure("missing_organism_definitions_for_t10_contamination_authority")
	var cell_order_result: Dictionary = T10DormantTransitSliceRunnerScript.new()._build_cell_order(hold_value as Dictionary)
	if not bool(cell_order_result.get("ok", false)):
		return _failure("t10_contamination_authority:%s" % String(cell_order_result.get("error", "invalid_hold")))
	var cell_order: PackedStringArray = cell_order_result["cell_order"] as PackedStringArray
	var zero_field: Dictionary = _zero_channel(cell_order)

	var first_runtime_value: Variant = first.get("organism_runtime", [])
	if not first_runtime_value is Array or (first_runtime_value as Array).is_empty():
		return _failure("missing_t10_contamination_runtime_authority")
	var response_kernel: ContaminationResponseKernel = T10DormantContaminationResponseKernelScript.new()
	var prepared_runtime: Dictionary = response_kernel.prepare_runtime(first_runtime_value as Array, definitions_value as Dictionary)
	if not bool(prepared_runtime.get("ok", false)):
		return _failure("t10_contamination_prepare:%s" % String(prepared_runtime.get("error", "unknown")))
	var persisted_runtime: Array = prepared_runtime["organisms"] as Array

	var t09_definitions_result: Dictionary = _prepare_t09_definitions(simulation_defs)
	if not bool(t09_definitions_result.get("ok", false)):
		return t09_definitions_result
	var t09_definitions: Array = t09_definitions_result["definitions"] as Array
	var t09_kernel: T09SymbioticBufferKernel = T10DormantT09SymbioticBufferKernelScript.new()

	var checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return _failure("invalid_t10_contamination_authority_checksums")
	var base_checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return _failure("t10_contamination_authority_checksum_count_mismatch")

	var rewritten_snapshots: Array = []
	var rewritten_checksums: PackedStringArray = PackedStringArray()
	var all_response_events: Array = []
	var all_t09_events: Array = []
	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return _failure("invalid_t10_contamination_authority_snapshot")
		var snapshot: Dictionary = (raw_snapshot as Dictionary).duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var runtime_value: Variant = snapshot.get("organism_runtime", [])
		if not runtime_value is Array:
			return _failure("invalid_t10_contamination_runtime_snapshot")
		var tick_runtime: Array = runtime_value as Array
		if index > 0:
			var merged_runtime: Dictionary = _merge_persisted_contamination(tick_runtime, persisted_runtime)
			if not bool(merged_runtime.get("ok", false)):
				return merged_runtime
			persisted_runtime = merged_runtime["organisms"] as Array

		var sampled: Dictionary = response_kernel.sample_phase_e(tick, persisted_runtime, zero_field)
		if not bool(sampled.get("ok", false)):
			return _failure("phase_e_t10_contamination_authority:%s" % String(sampled.get("error", "unknown")))
		var t09_result: Dictionary = t09_kernel.resolve_tick(tick, persisted_runtime, t09_definitions)
		if not bool(t09_result.get("ok", false)):
			return _failure("phase_e_t10_t09_authority:%s" % String(t09_result.get("error", "unknown")))
		var modifiers_value: Variant = t09_result.get("intake_multiplier_scaled_by_target_id", {})
		var t09_events_value: Variant = t09_result.get("events", [])
		if not modifiers_value is Dictionary or not t09_events_value is Array:
			return _failure("invalid_t10_contamination_t09_authority")
		var modifiers: Dictionary = modifiers_value as Dictionary
		var t09_events: Array = t09_events_value as Array

		var phase_f_input_result: Dictionary = _runtime_with_t09_intake_modifiers(persisted_runtime, modifiers)
		if not bool(phase_f_input_result.get("ok", false)):
			return phase_f_input_result
		var phase_f_input: Array = phase_f_input_result["organisms"] as Array
		var combined_by_id: Dictionary = phase_f_input_result["combined_intake_multiplier_scaled_by_id"] as Dictionary
		var phase_f: Dictionary = response_kernel.apply_phase_f(tick, phase_f_input, sampled["observations"] as Array)
		if not bool(phase_f.get("ok", false)):
			return _failure("phase_f_t10_contamination_authority:%s" % String(phase_f.get("error", "unknown")))
		var augmented_f: Dictionary = _augment_phase_f_t09_evidence(
			phase_f.get("events", []), persisted_runtime, modifiers, combined_by_id, t09_events
		)
		if not bool(augmented_f.get("ok", false)):
			return augmented_f
		var restored: Dictionary = _restore_contamination_profiles(phase_f.get("organisms", []), persisted_runtime)
		if not bool(restored.get("ok", false)):
			return restored
		var phase_g: Dictionary = response_kernel.evaluate_phase_g(tick, restored["organisms"] as Array)
		if not bool(phase_g.get("ok", false)):
			return _failure("phase_g_t10_contamination_authority:%s" % String(phase_g.get("error", "unknown")))
		persisted_runtime = phase_g["organisms"] as Array

		var tick_events: Array = []
		for batch: Variant in [sampled.get("events", []), t09_events, augmented_f["events"] as Array, phase_g.get("events", [])]:
			if not batch is Array:
				return _failure("invalid_t10_contamination_authority_event_batch")
			for raw_event: Variant in batch as Array:
				if not raw_event is Dictionary:
					return _failure("invalid_t10_contamination_authority_event")
				tick_events.append((raw_event as Dictionary).duplicate(true))
				all_response_events.append((raw_event as Dictionary).duplicate(true))
		for raw_t09_event: Variant in t09_events:
			if raw_t09_event is Dictionary:
				all_t09_events.append((raw_t09_event as Dictionary).duplicate(true))

		snapshot["phase_d_contamination_exposure_by_cell"] = zero_field.duplicate(true)
		snapshot["contamination_by_cell"] = zero_field.duplicate(true)
		snapshot["organism_runtime"] = persisted_runtime.duplicate(true)
		snapshot["t09_intake_multiplier_scaled_by_target_id"] = modifiers.duplicate(true)
		snapshot["t09_buffer_events"] = t09_events.duplicate(true)
		snapshot["contamination_response_events"] = tick_events.duplicate(true)
		rewritten_snapshots.append(snapshot)
		var checksum_material: String = "%s|t10_dormant_contamination=1|t09=%s|contamination_response=%s" % [
			String(base_checksums[index]),
			_serialize_t09_modifiers(modifiers),
			_serialize_contamination_response(persisted_runtime, tick_events),
		]
		rewritten_checksums.append(checksum_material.sha256_text())

	var result: Dictionary = base_result.duplicate(true)
	result["end_tick_snapshots"] = rewritten_snapshots
	result["tick_checksums"] = rewritten_checksums
	result["t09_buffer_events"] = all_t09_events
	result["contamination_response_events"] = all_response_events
	result["final_organism_runtime"] = persisted_runtime.duplicate(true)
	result["t10_dormant_contamination_authority"] = true
	return result

# Keep direct inherited-base callers correct as well. The primary production path
# currently reaches a sibling H05 runner, so this override is defensive rather
# than the only authority-establishment mechanism.
func _prepare_power_authority(committed_input: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var authority: Dictionary = super._prepare_power_authority(committed_input, simulation_defs)
	if not bool(authority.get("ok", false)):
		return authority
	if bool(authority.get("contamination_enabled", false)):
		return authority
	var rules_value: Variant = simulation_defs.get("contamination_rules", null)
	if not rules_value is Dictionary:
		return authority
	var next: Dictionary = authority.duplicate(true)
	next["contamination_enabled"] = true
	next["contamination_rules"] = (rules_value as Dictionary).duplicate(true)
	return next
