extends SceneTree

const H06ZoneIsolationKernelScript := preload("res://src/sim/h06_zone_isolation_kernel.gd")
const PhaseDEnvironmentResolverScript := preload("res://src/sim/phase_d_environment_resolver.gd")

var failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	_test_h06_blocks_declared_boundary_for_all_enabled_channels()
	_test_h06_is_direction_independent()
	_test_inactive_h06_preserves_rules()
	_test_invalid_boundary_rejected()
	_test_phase_d_resolver_uses_h06_rules()
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

func _rules() -> Dictionary:
	return {
		"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}, {"from": "1,0", "to": "2,0", "amount": 1}], "vent_by_cell": {}},
		"stress_field": {"stress_field_min": 0, "stress_field_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}, {"from": "1,0", "to": "2,0", "amount": 1}], "decay_by_cell": {}},
		"contamination": {"contamination_min": 0, "contamination_max": 100, "transfer_edges": [{"from": "0,0", "to": "1,0", "amount": 2}, {"from": "1,0", "to": "2,0", "amount": 1}], "vent_by_cell": {}},
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
