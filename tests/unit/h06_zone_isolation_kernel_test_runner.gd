extends SceneTree

const H06ZoneIsolationKernelScript := preload("res://src/sim/h06_zone_isolation_kernel.gd")
const PhaseDEnvironmentResolverScript := preload("res://src/sim/phase_d_environment_resolver.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	_test_h06_blocks_declared_boundary_for_all_enabled_channels()
	_test_h06_is_direction_independent()
	_test_inactive_h06_preserves_rules()
	_test_invalid_boundary_rejected()
	_test_phase_d_resolver_uses_h06_rules()
	_test_production_contamination_h06_changes_exposure_and_checksum()
	_test_production_stress_h06_changes_field_and_checksum()
	_test_future_h06_is_byte_equivalent_in_production()
	_test_active_h06_production_replay_is_deterministic()
	if failures.is_empty():
		print("H06 Zone Isolation Phase-D propagation tests: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("H06 Zone Isolation Phase-D propagation tests: FAIL (%d)" % failures.size())
	quit(1)

func _test_h06_blocks_declared_boundary_for_all_enabled_channels() -> void:
	var kernel: H06ZoneIsolationKernel = H06ZoneIsolationKernelScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0", "1,0", "2,0"])
	var rules: Dictionary = _rules()
	var hazards: Dictionary = {
		"ISO": {"family": "H06", "isolated_edges": [{"a": "0,0", "b": "1,0"}]},
	}
	var result: Dictionary = kernel.resolve_phase_d(2, cells, PackedStringArray(["ISO"]), hazards, rules)
	_expect(bool(result.get("ok", false)), "active H06 should resolve")
	if not bool(result.get("ok", false)):
		return
	var effective: Dictionary = result["rules_by_channel"]
	for channel: String in PackedStringArray(["heat", "stress_field", "contamination"]):
		var channel_rules: Dictionary = effective[channel]
		var edges: Array = channel_rules["transfer_edges"]
		_expect(edges.size() == 1, "H06 should remove only the transfer crossing its declared boundary for %s" % channel)
		if edges.size() == 1:
			_expect(String(edges[0]["from"]) == "1,0" and String(edges[0]["to"]) == "2,0", "H06 should preserve non-crossing transfer for %s" % channel)
	_expect((result["events"] as Array).size() == 3, "H06 should emit one deterministic evidence event per removed channel transfer")
	_expect(not String(result["authority_checksum"]).is_empty(), "H06 should expose replay-sensitive checksum evidence")

func _test_h06_is_direction_independent() -> void:
	var kernel: H06ZoneIsolationKernel = H06ZoneIsolationKernelScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0", "1,0"])
	var rules: Dictionary = {
		"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [{"from": "1,0", "to": "0,0", "amount": 2}], "vent_by_cell": {}},
	}
	var hazards: Dictionary = {"ISO": {"family": "H06", "isolated_edges": [{"a": "0,0", "b": "1,0"}]}}
	var result: Dictionary = kernel.resolve_phase_d(1, cells, PackedStringArray(["ISO"]), hazards, rules)
	_expect(bool(result.get("ok", false)), "reverse-direction H06 fixture should resolve")
	if bool(result.get("ok", false)):
		var heat_rules: Dictionary = result["rules_by_channel"]["heat"]
		_expect((heat_rules["transfer_edges"] as Array).is_empty(), "H06 boundary should block propagation in either direction")

func _test_inactive_h06_preserves_rules() -> void:
	var kernel: H06ZoneIsolationKernel = H06ZoneIsolationKernelScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0", "1,0", "2,0"])
	var rules: Dictionary = _rules()
	var result: Dictionary = kernel.resolve_phase_d(3, cells, PackedStringArray(["H01"]), {"H01": {"family": "H01"}}, rules)
	_expect(bool(result.get("ok", false)), "non-H06 hazards should pass through H06 authority")
	if bool(result.get("ok", false)):
		_expect(result["rules_by_channel"] == rules, "inactive H06 must preserve propagation rules byte-equivalent")
		_expect((result["events"] as Array).is_empty(), "inactive H06 must emit no isolation evidence")

func _test_invalid_boundary_rejected() -> void:
	var kernel: H06ZoneIsolationKernel = H06ZoneIsolationKernelScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0", "1,0", "2,0"])
	var result: Dictionary = kernel.resolve_phase_d(
		1,
		cells,
		PackedStringArray(["ISO"]),
		{"ISO": {"family": "H06", "isolated_edges": [{"a": "0,0", "b": "2,0"}]}},
		{"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [], "vent_by_cell": {}}}
	)
	_expect(not bool(result.get("ok", true)), "non-orthogonal H06 boundary must be rejected")
	_expect(String(result.get("error", "")).begins_with("non_orthogonal_h06_boundary:"), "invalid H06 boundary should have typed rejection")

func _test_phase_d_resolver_uses_h06_rules() -> void:
	var resolver: PhaseDEnvironmentResolver = PhaseDEnvironmentResolverScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0", "1,0"])
	var generated: Dictionary = {
		"heat": {"0,0": 10, "1,0": 0},
		"stress_field": {"0,0": 10, "1,0": 0},
		"contamination": {"0,0": 10, "1,0": 0},
	}
	var rules: Dictionary = {
		"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 3}], "vent_by_cell": {}},
		"stress_field": {"stress_field_min": 0, "stress_field_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 3}], "decay_by_cell": {}},
		"contamination": {"contamination_min": 0, "contamination_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 3}], "vent_by_cell": {}},
	}
	var hazards: Dictionary = {"ISO": {"family": "H06", "isolated_edges": [{"a": "0,0", "b": "1,0"}]}}
	var result: Dictionary = resolver.resolve_phase_d(1, cells, PackedStringArray(["ISO"]), hazards, generated, rules)
	_expect(bool(result.get("ok", false)), "Phase-D resolver should compose H06")
	if not bool(result.get("ok", false)):
		return
	var environment: Dictionary = result["environment_by_channel"]
	for channel: String in PackedStringArray(["heat", "stress_field", "contamination"]):
		var field: Dictionary = environment[channel]
		_expect(int(field["0,0"]) == 10 and int(field["1,0"]) == 0, "H06 should prevent Phase-D transfer for %s" % channel)
	_expect((result["h06_events"] as Array).size() == 3, "Phase-D resolver should retain H06 evidence")

func _test_production_contamination_h06_changes_exposure_and_checksum() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var active: Dictionary = runner.simulate(_production_record("route-h06-contamination"), 1, _production_contamination_defs(true, 1))
	var baseline: Dictionary = runner.simulate(_production_record("route-h06-contamination"), 1, _production_contamination_defs(false, 1))
	_expect(bool(active.get("ok", false)), "production contamination H06 route should resolve")
	_expect(bool(baseline.get("ok", false)), "production contamination H06 baseline should resolve")
	if not bool(active.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var active_snapshot: Dictionary = active["end_tick_snapshots"][0]
	var base_snapshot: Dictionary = baseline["end_tick_snapshots"][0]
	var active_exposure: Dictionary = active_snapshot["phase_d_contamination_exposure_by_cell"]
	var base_exposure: Dictionary = base_snapshot["phase_d_contamination_exposure_by_cell"]
	_expect(int(active_exposure.get("1,0", -1)) == 0, "active H06 should prevent contamination crossing the isolated production boundary")
	_expect(int(base_exposure.get("1,0", 0)) > 0, "baseline production contamination should cross the unisolated boundary")
	_expect(active_exposure != base_exposure, "active H06 should change published contamination Phase-D exposure")
	_expect(String(active["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "active contamination H06 should change authoritative production checksum")

func _test_production_stress_h06_changes_field_and_checksum() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var active: Dictionary = runner.simulate(_production_record("route-h06-stress"), 1, _production_stress_defs(true, 1))
	var baseline: Dictionary = runner.simulate(_production_record("route-h06-stress"), 1, _production_stress_defs(false, 1))
	_expect(bool(active.get("ok", false)), "production stress H06 route should resolve")
	_expect(bool(baseline.get("ok", false)), "production stress H06 baseline should resolve")
	if not bool(active.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var active_snapshot: Dictionary = active["end_tick_snapshots"][0]
	var base_snapshot: Dictionary = baseline["end_tick_snapshots"][0]
	var active_field: Dictionary = active_snapshot["stress_field_by_cell"]
	var base_field: Dictionary = base_snapshot["stress_field_by_cell"]
	_expect(int(active_field.get("1,0", -1)) == 0, "active H06 should prevent stress-field propagation across the isolated production boundary")
	_expect(int(base_field.get("1,0", 0)) > 0, "baseline production stress field should cross the unisolated boundary")
	_expect(active_field != base_field, "active H06 should change production stress-field snapshot authority")
	_expect(String(active["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "active stress H06 should change authoritative production checksum")

func _test_future_h06_is_byte_equivalent_in_production() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var future: Dictionary = runner.simulate(_production_record("route-h06-contamination"), 1, _production_contamination_defs(true, 3))
	var baseline: Dictionary = runner.simulate(_production_record("route-h06-contamination"), 1, _production_contamination_defs(false, 1))
	_expect(bool(future.get("ok", false)) and bool(baseline.get("ok", false)), "future H06 production fixture and baseline should resolve")
	if bool(future.get("ok", false)) and bool(baseline.get("ok", false)):
		_expect(future == baseline, "H06 outside the simulated window must preserve production output byte-equivalent")

func _test_active_h06_production_replay_is_deterministic() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_production_record("route-h06-contamination"), 1, _production_contamination_defs(true, 1))
	var second: Dictionary = runner.simulate(_production_record("route-h06-contamination"), 1, _production_contamination_defs(true, 1))
	_expect(first == second, "active H06 production replay should be deterministic")

func _production_record(route_id: String) -> Dictionary:
	return {
		"run_id": "h06-production-run",
		"rules_version": "rules-r1",
		"content_version": "h06-production-1",
		"canonical_committed_input": {
			"route_id": route_id,
			"seed": 606,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _production_contamination_defs(include_h06: bool, h06_tick: int) -> Dictionary:
	var events: Array = [{"tick": 1, "duration_ticks": 1, "hazard_id": "h03-source", "authored_order": 0}]
	var hazards: Dictionary = {
		"h03-source": {"id": "h03-source", "family": "H03", "contamination_delta": 8, "target_cells": ["0,0"]},
	}
	if include_h06:
		events.append({"tick": h06_tick, "duration_ticks": 1, "hazard_id": "h06-isolate", "authored_order": 1})
		hazards["h06-isolate"] = _production_h06()
	return {
		"route_profile": {"id": "route-h06-contamination", "tick_count": max(1, h06_tick), "events": events},
		"hold_definition": {"dimensions": [2, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": hazards,
		"support_definitions_by_id": {},
		"contamination_rules": {
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 3}],
			"vent_by_cell": {},
		},
	}

func _production_stress_defs(include_h06: bool, h06_tick: int) -> Dictionary:
	var events: Array = [{"tick": 1, "duration_ticks": 1, "hazard_id": "h02-source", "authored_order": 0}]
	var hazards: Dictionary = {
		"h02-source": {"id": "h02-source", "family": "H02", "stress_field_delta": 5, "target_cells": ["0,0"]},
	}
	if include_h06:
		events.append({"tick": h06_tick, "duration_ticks": 1, "hazard_id": "h06-isolate", "authored_order": 1})
		hazards["h06-isolate"] = _production_h06()
	return {
		"route_profile": {"id": "route-h06-stress", "tick_count": max(1, h06_tick), "events": events},
		"hold_definition": {"dimensions": [2, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": hazards,
		"support_definitions_by_id": {},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"stress_field_rules": {
			"stress_field_min": 0,
			"stress_field_max": 20,
			"transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}],
			"decay_by_cell": {},
		},
	}

func _production_h06() -> Dictionary:
	return {
		"id": "h06-isolate",
		"family": "H06",
		"isolated_edges": [{"a": "0,0", "b": "1,0"}],
	}

func _rules() -> Dictionary:
	return {
		"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}, {"from": "1,0", "to": "2,0", "amount": 1}], "vent_by_cell": {}},
		"stress_field": {"stress_field_min": 0, "stress_field_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}, {"from": "1,0", "to": "2,0", "amount": 1}], "decay_by_cell": {}},
		"contamination": {"contamination_min": 0, "contamination_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}, {"from": "1,0", "to": "2,0", "amount": 1}], "vent_by_cell": {}},
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
