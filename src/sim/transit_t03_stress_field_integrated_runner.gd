extends "res://src/sim/transit_h05_stress_field_integrated_runner.gd"

const T03TransitMonitorIntegratedRunnerScript := preload("res://src/sim/transit_monitor_integrated_runner.gd")
const T03PhaseDEnvironmentResolverScript := preload("res://src/sim/phase_d_environment_resolver.gd")
const T03S03BaffleKernelScript := preload("res://src/sim/s03_baffle_kernel.gd")
const T03AlarmEmitterKernelScript := preload("res://src/sim/t03_alarm_emitter_kernel.gd")

# T03 needs the same authoritative stress-field C->D path as H02, but it is a
# living state-gated source rather than a route hazard. This layer is entered
# only when authored T03 definitions exist. With no T03 it delegates byte-for-
# byte to the already-green H02/S03/H05 implementation.
func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var t03_value: Variant = simulation_defs.get("t03_definitions", [])
	if not t03_value is Array:
		return {"ok": false, "error": "invalid_t03_definitions"}
	var t03_definitions: Array = t03_value
	if t03_definitions.is_empty():
		return super.simulate(committed_run, total_ticks, simulation_defs)
	if total_ticks <= 0:
		return {"ok": false, "error": "invalid_total_ticks"}

	var has_h02: bool = _has_h02(simulation_defs)
	var s03_authority: Dictionary = _prepare_s03_authority(committed_run, simulation_defs)
	if not bool(s03_authority.get("ok", false)):
		return s03_authority
	var base_run: Dictionary = s03_authority["base_run"]
	var s03_supports: Array = s03_authority["s03_supports"]

	# Bypass the pre-existing stress-field postprocessor here so H02 is not
	# integrated once there and then a second time beside T03 below.
	var base_defs: Dictionary = _defs_without_h02(simulation_defs) if has_h02 else simulation_defs.duplicate(true)
	base_defs.erase("stress_field_rules")
	base_defs.erase("t03_definitions")
	var base_result: Dictionary = T03TransitMonitorIntegratedRunnerScript.new().simulate(base_run, total_ticks, base_defs)
	if not bool(base_result.get("ok", false)):
		return base_result

	var rules_value: Variant = simulation_defs.get("stress_field_rules", null)
	var hold_value: Variant = simulation_defs.get("hold_definition", null)
	var route_value: Variant = simulation_defs.get("route_profile", null)
	var hazards_value: Variant = simulation_defs.get("hazards_by_id", null)
	if not rules_value is Dictionary:
		return {"ok": false, "error": "missing_stress_field_rules"}
	if not hold_value is Dictionary:
		return {"ok": false, "error": "missing_hold_definition"}
	if not route_value is Dictionary or not hazards_value is Dictionary:
		return {"ok": false, "error": "missing_stress_field_route_authority"}
	var stress_field_rules: Dictionary = rules_value
	var hold_definition: Dictionary = hold_value
	var route_profile: Dictionary = route_value
	var hazards_by_id: Dictionary = hazards_value
	var cell_order_result: Dictionary = TransitSliceRunnerScript.new()._build_cell_order(hold_definition)
	if not bool(cell_order_result.get("ok", false)):
		return {"ok": false, "error": "stress_field:%s" % String(cell_order_result.get("error", "invalid_hold"))}
	var cell_order: PackedStringArray = cell_order_result["cell_order"]

	var boundary_result: Dictionary = _resolve_s03_boundaries(s03_supports, hold_definition)
	if not bool(boundary_result.get("ok", false)):
		return boundary_result
	var s03_boundaries: Array = boundary_result["boundaries"]
	var phase_d_rules: Dictionary = stress_field_rules.duplicate(true)
	var s03_event_templates: Array = []
	if not s03_boundaries.is_empty():
		var transformed: Dictionary = T03S03BaffleKernelScript.new().apply_phase_d_transmission(stress_field_rules, s03_boundaries)
		if not bool(transformed.get("ok", false)):
			return {"ok": false, "error": "phase_d_s03:%s" % String(transformed.get("error", "unknown"))}
		var transformed_rules_value: Variant = transformed.get("rules", null)
		var event_templates_value: Variant = transformed.get("events", [])
		if not transformed_rules_value is Dictionary or not event_templates_value is Array:
			return {"ok": false, "error": "invalid_s03_phase_d_authority"}
		phase_d_rules = (transformed_rules_value as Dictionary).duplicate(true)
		for raw_template: Variant in event_templates_value:
			if not raw_template is Dictionary:
				return {"ok": false, "error": "invalid_s03_phase_d_event"}
			s03_event_templates.append((raw_template as Dictionary).duplicate(true))

	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	var checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not snapshots_value is Array:
		return {"ok": false, "error": "invalid_end_tick_snapshots"}
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return {"ok": false, "error": "invalid_base_tick_checksums"}
	var snapshots: Array = snapshots_value
	var base_checksums: Array = []
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return {"ok": false, "error": "base_tick_checksum_count_mismatch"}

	var field: Dictionary = {}
	for cell_key: String in cell_order:
		field[cell_key] = 0
	var stress_kernel: StressFieldEnvironmentKernel = StressFieldEnvironmentKernelScript.new()
	var t03_kernel: T03AlarmEmitterKernel = T03AlarmEmitterKernelScript.new()
	var phase_d_resolver: PhaseDEnvironmentResolver = T03PhaseDEnvironmentResolverScript.new()
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_source_events: Array = []
	var all_s03_events: Array = []
	var all_h05_events: Array = []
	var prior_h05_value: Variant = base_result.get("h05_vent_events", [])
	if prior_h05_value is Array:
		for raw_prior: Variant in prior_h05_value:
			if raw_prior is Dictionary:
				all_h05_events.append((raw_prior as Dictionary).duplicate(true))

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return {"ok": false, "error": "invalid_end_tick_snapshot"}
		var source_snapshot: Dictionary = raw_snapshot
		var snapshot: Dictionary = source_snapshot.duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var runtime_value: Variant = snapshot.get("organism_runtime", [])
		if not runtime_value is Array:
			return {"ok": false, "error": "invalid_t03_organism_runtime_snapshot"}
		var organism_runtime: Array = runtime_value
		if organism_runtime.is_empty():
			return {"ok": false, "error": "t03_requires_organism_runtime"}

		var active_all: PackedStringArray = _active_hazards_for_tick(tick, route_profile)
		var active_h02: PackedStringArray = PackedStringArray()
		for hazard_id: String in active_all:
			if hazards_by_id.has(hazard_id) and hazards_by_id[hazard_id] is Dictionary:
				var hazard: Dictionary = hazards_by_id[hazard_id]
				if String(hazard.get("family", "")) == "H02":
					active_h02.append(hazard_id)

		# Phase C: existing field -> H02 route sources -> T03 living sources.
		var h02_phase_c: Dictionary = stress_kernel.apply_h02_phase_c(field, cell_order, active_h02, hazards_by_id)
		if not bool(h02_phase_c.get("ok", false)):
			return {"ok": false, "error": "phase_c_stress_field:%s" % String(h02_phase_c.get("error", "unknown"))}
		var t03_phase_c: Dictionary = t03_kernel.apply_phase_c(
			tick,
			h02_phase_c["stress_field_by_cell"],
			organism_runtime,
			t03_definitions
		)
		if not bool(t03_phase_c.get("ok", false)):
			return {"ok": false, "error": "phase_c_t03:%s" % String(t03_phase_c.get("error", "unknown"))}

		# Phase D remains the single frozen propagation/decay authority, including
		# S03 transmission transforms and H05/H06 modifiers supplied by subclasses.
		var scoped_h05: Dictionary = _scoped_h05_stress_authority(active_all, hazards_by_id)
		if not bool(scoped_h05.get("ok", false)):
			return scoped_h05
		var phase_d: Dictionary = phase_d_resolver.resolve_phase_d(
			tick,
			cell_order,
			scoped_h05["active_hazards"],
			scoped_h05["hazards_by_id"],
			{"stress_field": t03_phase_c["stress_field_by_cell"]},
			{"stress_field": phase_d_rules}
		)
		if not bool(phase_d.get("ok", false)):
			return {"ok": false, "error": "phase_d_stress_field:%s" % String(phase_d.get("error", "unknown"))}
		var phase_d_channels: Dictionary = phase_d["environment_by_channel"]
		field = (phase_d_channels["stress_field"] as Dictionary).duplicate(true)

		var tick_source_events: Array = []
		var h02_events_value: Variant = h02_phase_c.get("events", [])
		var t03_events_value: Variant = t03_phase_c.get("events", [])
		if not h02_events_value is Array or not t03_events_value is Array:
			return {"ok": false, "error": "invalid_stress_field_source_events"}
		for raw_h02_event: Variant in h02_events_value:
			if not raw_h02_event is Dictionary:
				return {"ok": false, "error": "invalid_stress_field_source_event"}
			var h02_event: Dictionary = (raw_h02_event as Dictionary).duplicate(true)
			h02_event["tick"] = tick
			tick_source_events.append(h02_event)
			all_source_events.append(h02_event.duplicate(true))
		for raw_t03_event: Variant in t03_events_value:
			if not raw_t03_event is Dictionary:
				return {"ok": false, "error": "invalid_t03_source_event"}
			var t03_event: Dictionary = (raw_t03_event as Dictionary).duplicate(true)
			tick_source_events.append(t03_event)
			all_source_events.append(t03_event.duplicate(true))

		var s03_tick_events: Array = []
		for raw_template: Variant in s03_event_templates:
			var s03_event: Dictionary = (raw_template as Dictionary).duplicate(true)
			s03_event["tick"] = tick
			s03_tick_events.append(s03_event)
			all_s03_events.append(s03_event.duplicate(true))

		var tick_h05_events: Array = (phase_d["h05_events"] as Array).duplicate(true)
		for raw_h05_event: Variant in tick_h05_events:
			if raw_h05_event is Dictionary:
				all_h05_events.append((raw_h05_event as Dictionary).duplicate(true))

		snapshot["active_hazards"] = active_all
		snapshot["stress_field_source_events"] = tick_source_events.duplicate(true)
		snapshot["s03_stress_transfer_events"] = s03_tick_events.duplicate(true)
		snapshot["stress_field_by_cell"] = _ordered_h05_stress_field(field, cell_order)
		if not tick_h05_events.is_empty():
			var merged_h05_events: Array = []
			var existing_h05_value: Variant = snapshot.get("h05_vent_events", [])
			if existing_h05_value is Array:
				for raw_existing: Variant in existing_h05_value:
					if raw_existing is Dictionary:
						merged_h05_events.append((raw_existing as Dictionary).duplicate(true))
			for raw_new: Variant in tick_h05_events:
				if raw_new is Dictionary:
					merged_h05_events.append((raw_new as Dictionary).duplicate(true))
			merged_h05_events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return String(left.get("event_id", "")) < String(right.get("event_id", ""))
			)
			snapshot["h05_vent_events"] = merged_h05_events
			var effective_value: Variant = phase_d.get("effective_vent_by_channel", {})
			if effective_value is Dictionary:
				var merged_effective: Dictionary = {}
				var existing_effective: Variant = snapshot.get("phase_d_effective_vent_by_channel", {})
				if existing_effective is Dictionary:
					merged_effective = (existing_effective as Dictionary).duplicate(true)
				var effective: Dictionary = effective_value
				if effective.has("stress_field") and effective["stress_field"] is Dictionary:
					merged_effective["stress_field"] = (effective["stress_field"] as Dictionary).duplicate(true)
				snapshot["phase_d_effective_vent_by_channel"] = merged_effective
			snapshot["phase_d_stress_authority_payload"] = String(phase_d.get("authority_payload", ""))
			snapshot["phase_d_stress_authority_checksum"] = String(phase_d.get("authority_checksum", ""))
		integrated_snapshots.append(snapshot)

		var checksum_material: String = String(base_checksums[index]) \
			+ "|t03_stress_field=" + _serialize_h05_stress_field(field, cell_order) \
			+ "|t03_stress_phase_d=" + String(phase_d.get("authority_payload", "")) \
			+ "|t03_stress_source=" + _serialize_h05_stress_events(tick_source_events) \
			+ "|t03_s03_boundaries=" + _serialize_s03_boundaries(s03_boundaries) \
			+ "|t03_s03_events=" + _serialize_s03_events(s03_tick_events)
		integrated_checksums.append(checksum_material.sha256_text())

	base_result["end_tick_snapshots"] = integrated_snapshots
	base_result["tick_checksums"] = integrated_checksums
	base_result["stress_field_source_events"] = all_source_events
	base_result["s03_stress_transfer_events"] = all_s03_events
	base_result["s03_support_boundaries"] = s03_boundaries.duplicate(true)
	base_result["h05_vent_events"] = all_h05_events
	base_result["final_stress_field_by_cell"] = _ordered_h05_stress_field(field, cell_order)
	return base_result
