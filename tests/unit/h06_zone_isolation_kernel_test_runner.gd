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
	_test_dormant_h06_is_byte_equivalent_in_production()
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
	var cells := PackedStringArray(["0,0", "1,0", "2,0"])
	var result: Dictionary = H06ZoneIsolationKernelScript.new().resolve_phase_d(
		2, cells, PackedStringArray(["ISO"]),
		{"ISO": {"family": "H06", "isolated_edges": [{"a": "0,0", "b": "1,0"}]}},
		_rules()
	)
	_expect(bool(result.get("ok", false)), "active H06 should resolve")
	if not bool(result.get("ok", false)):
		return
	for channel: String in PackedStringArray(["heat", "stress_field", "contamination"]):
		var edges: Array = result["rules_by_channel"][channel]["transfer_edges"]
		_expect(edges.size() == 1, "H06 should remove only the crossing transfer for %s" % channel)
		if edges.size() == 1:
			_expect(String(edges[0]["from"]) == "1,0" and String(edges[0]["to"]) == "2,0", "H06 should preserve the non-crossing transfer for %s" % channel)
	_expect((result["events"] as Array).size() == 3, "H06 should emit one evidence event per removed channel transfer")
	_expect(not String(result["authority_checksum"]).is_empty(), "H06 should expose replay-sensitive checksum evidence")

func _test_h06_is_direction_independent() -> void:
	var result: Dictionary = H06ZoneIsolationKernelScript.new().resolve_phase_d(
		1, PackedStringArray(["0,0", "1,0"]), PackedStringArray(["ISO"]),
		{"ISO": {"family": "H06", "isolated_edges": [{"a": "0,0", "b": "1,0"}]}},
		{"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [{"from": "1,0", "to": "0,0", "amount": 2}], "vent_by_cell": {}}}
	)
	_expect(bool(result.get("ok", false)), "reverse-direction H06 fixture should resolve")
	if bool(result.get("ok", false)):
		_expect((result["rules_by_channel"]["heat"]["transfer_edges"] as Array).is_empty(), "H06 boundary should block propagation in either direction")

func _test_inactive_h06_preserves_rules() -> void:
	var rules: Dictionary = _rules()
	var result: Dictionary = H06ZoneIsolationKernelScript.new().resolve_phase_d(
		3, PackedStringArray(["0,0", "1,0", "2,0"]), PackedStringArray(["H01"]), {"H01": {"family": "H01"}}, rules
	)
	_expect(bool(result.get("ok", false)), "non-H06 hazards should pass through H06 authority")
	if bool(result.get("ok", false)):
		_expect(result["rules_by_channel"] == rules, "inactive H06 must preserve propagation rules byte-equivalent")
		_expect((result["events"] as Array).is_empty(), "inactive H06 must emit no isolation evidence")

func _test_invalid_boundary_rejected() -> void:
	var result: Dictionary = H06ZoneIsolationKernelScript.new().resolve_phase_d(
		1, PackedStringArray(["0,0", "1,0", "2,0"]), PackedStringArray(["ISO"]),
		{"ISO": {"family": "H06", "isolated_edges": [{"a": "0,0", "b": "2,0"}]}},
		{"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [], "vent_by_cell": {}}}
	)
	_expect(not bool(result.get("ok", true)), "non-orthogonal H06 boundary must be rejected")
	_expect(String(result.get("error", "")).begins_with("non_orthogonal_h06_boundary:"), "invalid H06 boundary should have typed rejection")

func _test_phase_d_resolver_uses_h06_rules() -> void:
	var generated := {"heat": {"0,0": 10, "1,0": 0}, "stress_field": {"0,0": 10, "1,0": 0}, "contamination": {"0,0": 10, "1,0": 0}}
	var result: Dictionary = PhaseDEnvironmentResolverScript.new().resolve_phase_d(
		1, PackedStringArray(["0,0", "1,0"]), PackedStringArray(["ISO"]),
		{"ISO": {"family": "H06", "isolated_edges": [{"a": "0,0", "b": "1,0"}]}}, generated, _two_cell_rules()
	)
	_expect(bool(result.get("ok", false)), "Phase-D resolver should compose H06")
	if not bool(result.get("ok", false)):
		return
	for channel: String in PackedStringArray(["heat", "stress_field", "contamination"]):
		var field: Dictionary = result["environment_by_channel"][channel]
		_expect(int(field["0,0"]) == 10 and int(field["1,0"]) == 0, "H06 should prevent Phase-D transfer for %s" % channel)
	_expect((result["h06_events"] as Array).size() == 3, "Phase-D resolver should retain H06 evidence")

func _test_production_contamination_h06_changes_exposure_and_checksum() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var active: Dictionary = runner.simulate(_record("route-h06-contamination"), 1, _contamination_defs(true, true))
	var baseline: Dictionary = runner.simulate(_record("route-h06-contamination"), 1, _contamination_defs(false, false))
	_expect(bool(active.get("ok", false)), "production contamination H06 route should resolve: %s" % String(active.get("error", "")))
	_expect(bool(baseline.get("ok", false)), "production contamination H06 baseline should resolve: %s" % String(baseline.get("error", "")))
	if not bool(active.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var active_exposure: Dictionary = active["end_tick_snapshots"][0]["phase_d_contamination_exposure_by_cell"]
	var base_exposure: Dictionary = baseline["end_tick_snapshots"][0]["phase_d_contamination_exposure_by_cell"]
	_expect(int(active_exposure.get("1,0", -1)) == 0, "active H06 should prevent contamination crossing the isolated production boundary")
	_expect(int(base_exposure.get("1,0", 0)) > 0, "baseline production contamination should cross the unisolated boundary")
	_expect(active_exposure != base_exposure, "active H06 should change published contamination Phase-D exposure")
	_expect(String(active["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "active contamination H06 should change authoritative production checksum")

func _test_production_stress_h06_changes_field_and_checksum() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var active: Dictionary = runner.simulate(_record("route-h06-stress"), 1, _stress_defs(true))
	var baseline: Dictionary = runner.simulate(_record("route-h06-stress"), 1, _stress_defs(false))
	_expect(bool(active.get("ok", false)), "production stress H06 route should resolve: %s" % String(active.get("error", "")))
	_expect(bool(baseline.get("ok", false)), "production stress H06 baseline should resolve: %s" % String(baseline.get("error", "")))
	if not bool(active.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var active_field: Dictionary = active["end_tick_snapshots"][0]["stress_field_by_cell"]
	var base_field: Dictionary = baseline["end_tick_snapshots"][0]["stress_field_by_cell"]
	_expect(int(active_field.get("1,0", -1)) == 0, "active H06 should prevent stress-field propagation across the isolated production boundary")
	_expect(int(base_field.get("1,0", 0)) > 0, "baseline production stress field should cross the unisolated boundary")
	_expect(active_field != base_field, "active H06 should change production stress-field snapshot authority")
	_expect(String(active["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "active stress H06 should change authoritative production checksum")

func _test_dormant_h06_is_byte_equivalent_in_production() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var dormant: Dictionary = runner.simulate(_record("route-h06-contamination"), 1, _contamination_defs(true, false))
	var baseline: Dictionary = runner.simulate(_record("route-h06-contamination"), 1, _contamination_defs(false, false))
	_expect(bool(dormant.get("ok", false)) and bool(baseline.get("ok", false)), "dormant H06 production fixture and baseline should resolve")
	if bool(dormant.get("ok", false)) and bool(baseline.get("ok", false)):
		_expect(dormant == baseline, "an authored but unscheduled H06 must preserve production output byte-equivalent")

func _test_active_h06_production_replay_is_deterministic() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_record("route-h06-contamination"), 1, _contamination_defs(true, true))
	var second: Dictionary = runner.simulate(_record("route-h06-contamination"), 1, _contamination_defs(true, true))
	_expect(first == second, "active H06 production replay should be deterministic")

func _record(route_id: String) -> Dictionary:
	return {"run_id": "h06-production-run", "rules_version": "rules-r1", "content_version": "h06-production-1", "canonical_committed_input": {"route_id": route_id, "seed": 606, "placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}], "supports": [], "brownout_priority": []}}

func _contamination_defs(include_h06_definition: bool, schedule_h06: bool) -> Dictionary:
	var events: Array = [{"tick": 1, "duration_ticks": 1, "hazard_id": "h03-source", "authored_order": 0}]
	var hazards: Dictionary = {"h03-source": {"id": "h03-source", "family": "H03", "contamination_delta": 8, "target_cells": ["0,0"]}}
	if include_h06_definition:
		hazards["h06-isolate"] = _production_h06()
		if schedule_h06:
			events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h06-isolate", "authored_order": 1})
	return {"route_profile": {"id": "route-h06-contamination", "tick_count": 1, "events": events}, "hold_definition": {"dimensions": [2, 1], "blocked_cells": [], "power_capacity": 0}, "hazards_by_id": hazards, "support_definitions_by_id": {}, "contamination_rules": {"contamination_min": 0, "contamination_max": 20, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 3}], "vent_by_cell": {}}}

func _stress_defs(include_h06: bool) -> Dictionary:
	var events: Array = [{"tick": 1, "duration_ticks": 1, "hazard_id": "h02-source", "authored_order": 0}]
	var hazards: Dictionary = {"h02-source": {"id": "h02-source", "family": "H02", "stress_field_delta": 5, "target_cells": ["0,0"]}}
	if include_h06:
		events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h06-isolate", "authored_order": 1})
		hazards["h06-isolate"] = _production_h06()
	return {"route_profile": {"id": "route-h06-stress", "tick_count": 1, "events": events}, "hold_definition": {"dimensions": [2, 1], "blocked_cells": [], "power_capacity": 0}, "hazards_by_id": hazards, "support_definitions_by_id": {}, "thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}}, "stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}], "decay_by_cell": {}}}

func _production_h06() -> Dictionary:
	return {"id": "h06-isolate", "family": "H06", "isolated_edges": [{"a": "0,0", "b": "1,0"}]}

func _rules() -> Dictionary:
	return {"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}, {"from": "1,0", "to": "2,0", "amount": 1}], "vent_by_cell": {}}, "stress_field": {"stress_field_min": 0, "stress_field_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}, {"from": "1,0", "to": "2,0", "amount": 1}], "decay_by_cell": {}}, "contamination": {"contamination_min": 0, "contamination_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}, {"from": "1,0", "to": "2,0", "amount": 1}], "vent_by_cell": {}}}

func _two_cell_rules() -> Dictionary:
	return {"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 3}], "vent_by_cell": {}}, "stress_field": {"stress_field_min": 0, "stress_field_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 3}], "decay_by_cell": {}}, "contamination": {"contamination_min": 0, "contamination_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 3}], "vent_by_cell": {}}}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
