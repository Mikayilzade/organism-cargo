extends "res://src/sim/transit_t10_contamination_reconsumption_integrated_runner.gd"

const T10ContaminationResponseKernelScript := preload("res://src/sim/contamination_response_kernel.gd")
const T10T09SymbioticBufferKernelScript := preload("res://src/sim/t09_symbiotic_buffer_kernel.gd")

func _reconsume_contamination_tick(snapshot: Dictionary, application_events: Array, simulation_defs: Dictionary) -> Dictionary:
	var tick: int = int(snapshot.get("tick", 0))
	if tick <= 0:
		return _failure("invalid_t10_contamination_reconsumption_tick")
	var phase_d_value: Variant = snapshot.get("phase_d_contamination_exposure_by_cell", null)
	var runtime_value: Variant = snapshot.get("organism_runtime", null)
	var response_value: Variant = snapshot.get("contamination_response_events", null)
	if not phase_d_value is Dictionary or not runtime_value is Array or not response_value is Array:
		return _failure("missing_t10_contamination_reconsumption_authority")
	var rules_value: Variant = simulation_defs.get("contamination_rules", null)
	if not rules_value is Dictionary:
		return _failure("missing_t10_contamination_rules")
	var rules: Dictionary = rules_value
	var field: Dictionary = (phase_d_value as Dictionary).duplicate(true)
	for raw_application: Variant in application_events:
		if not raw_application is Dictionary:
			return _failure("invalid_t10_contamination_application_event")
		var application: Dictionary = raw_application
		var cell_key: String = String(application.get("cell_key", ""))
		if cell_key.is_empty() or not field.has(cell_key):
			continue
		field[cell_key] = clampi(
			int(field[cell_key]) + int(application.get("applied_delta", 0)),
			int(rules.get("contamination_min", 0)),
			int(rules.get("contamination_max", 0))
		)

	var pre_result: Dictionary = _reconstruct_pre_contamination_runtime(runtime_value as Array, response_value as Array)
	if not bool(pre_result.get("ok", false)):
		return pre_result
	var pre_runtime: Array = pre_result["organisms"] as Array

	# Re-resolve T09 from the reconstructed pre-F runtime instead of trusting a
	# post-hoc modifier map. This mirrors the canonical contamination runner's
	# Phase-E composition and keeps source state/range/target authority intact.
	var t09_definitions_result: Dictionary = _prepare_t09_definitions(simulation_defs)
	if not bool(t09_definitions_result.get("ok", false)):
		return t09_definitions_result
	var t09_result: Dictionary = T10T09SymbioticBufferKernelScript.new().resolve_tick(
		tick, pre_runtime, t09_definitions_result["definitions"] as Array
	)
	if not bool(t09_result.get("ok", false)):
		return _failure("phase_e_t10_t09:%s" % String(t09_result.get("error", "unknown")))
	var modifiers_value: Variant = t09_result.get("intake_multiplier_scaled_by_target_id", {})
	var t09_events_value: Variant = t09_result.get("events", [])
	if not modifiers_value is Dictionary or not t09_events_value is Array:
		return _failure("invalid_t10_contamination_t09_authority")
	var modifiers: Dictionary = modifiers_value as Dictionary
	var t09_events: Array = t09_events_value as Array

	var modified_result: Dictionary = _runtime_with_t09_intake_modifiers(pre_runtime, modifiers)
	if not bool(modified_result.get("ok", false)):
		return modified_result
	var phase_f_input: Array = modified_result["organisms"] as Array
	var combined_by_id: Dictionary = modified_result["combined_intake_multiplier_scaled_by_id"] as Dictionary

	var response_kernel: ContaminationResponseKernel = T10ContaminationResponseKernelScript.new()
	var sampled: Dictionary = response_kernel.sample_phase_e(tick, phase_f_input, field)
	if not bool(sampled.get("ok", false)):
		return _failure("phase_e_t10_contamination:%s" % String(sampled.get("error", "unknown")))
	var sample_events_value: Variant = sampled.get("events", [])
	var observations_value: Variant = sampled.get("observations", [])
	if not sample_events_value is Array or not observations_value is Array:
		return _failure("invalid_t10_contamination_phase_e")
	var sample_events: Array = sample_events_value as Array
	var ancestry: Dictionary = _attach_contamination_ancestry(sample_events, phase_f_input, application_events)
	if not bool(ancestry.get("ok", false)):
		return ancestry
	sample_events = ancestry["events"] as Array

	var phase_f: Dictionary = response_kernel.apply_phase_f(tick, phase_f_input, observations_value as Array)
	if not bool(phase_f.get("ok", false)):
		return _failure("phase_f_t10_contamination:%s" % String(phase_f.get("error", "unknown")))
	var augmented_f: Dictionary = _augment_phase_f_t09_evidence(
		phase_f.get("events", []), pre_runtime, modifiers, combined_by_id, t09_events
	)
	if not bool(augmented_f.get("ok", false)):
		return augmented_f
	var restored: Dictionary = _restore_contamination_profiles(phase_f.get("organisms", []), pre_runtime)
	if not bool(restored.get("ok", false)):
		return restored
	var phase_g: Dictionary = response_kernel.evaluate_phase_g(tick, restored["organisms"] as Array)
	if not bool(phase_g.get("ok", false)):
		return _failure("phase_g_t10_contamination:%s" % String(phase_g.get("error", "unknown")))

	var phase_g_events_value: Variant = phase_g.get("events", [])
	if not phase_g_events_value is Array:
		return _failure("invalid_t10_contamination_response_events")
	var replacement_events: Array = []
	for batch: Variant in [sample_events, t09_events, augmented_f["events"] as Array, phase_g_events_value as Array]:
		for raw_event: Variant in batch as Array:
			if raw_event is Dictionary:
				replacement_events.append((raw_event as Dictionary).duplicate(true))

	var next_snapshot: Dictionary = snapshot.duplicate(true)
	next_snapshot["phase_d_contamination_exposure_by_cell"] = field
	next_snapshot["organism_runtime"] = (phase_g["organisms"] as Array).duplicate(true)
	next_snapshot["t09_intake_multiplier_scaled_by_target_id"] = modifiers.duplicate(true)
	next_snapshot["t09_buffer_events"] = t09_events.duplicate(true)
	next_snapshot["contamination_response_events"] = replacement_events.duplicate(true)
	return {"ok": true, "error": "", "snapshot": next_snapshot, "events": replacement_events}
