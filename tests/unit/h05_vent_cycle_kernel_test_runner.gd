extends SceneTree

const H05VentCycleKernelScript := preload("res://src/sim/h05_vent_cycle_kernel.gd")
const PhaseDEnvironmentResolverScript := preload("res://src/sim/phase_d_environment_resolver.gd")
const ThermalResponseKernelScript := preload("res://src/sim/thermal_response_kernel.gd")
const ContaminationEnvironmentKernelScript := preload("res://src/sim/contamination_environment_kernel.gd")
const StressFieldEnvironmentKernelScript := preload("res://src/sim/stress_field_environment_kernel.gd")

var failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	_test_deterministic_composition_and_evidence()
	_test_inactive_h05_preserves_base_venting()
	_test_negative_effective_vent_rejected()
	_test_disabled_channel_rejected()
	_test_checksum_is_sensitive_to_authored_delta()
	_test_phase_d_production_boundary_all_three_channels()
	_test_phase_d_production_boundary_inactive_is_kernel_equivalent()
	if failures.is_empty():
		print("H05 Vent Cycle Phase-D modifier and integration-boundary tests: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("H05 Vent Cycle Phase-D modifier and integration-boundary tests: FAIL (%d)" % failures.size())
	quit(1)

func _test_deterministic_composition_and_evidence() -> void:
	var kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0", "1,0"])
	var base: Dictionary = {
		"heat": {"0,0": 1, "1,0": 0},
		"stress_field": {"0,0": 0, "1,0": 0},
		"contamination": {"0,0": 0, "1,0": 2},
	}
	var hazards: Dictionary = {
		"VENT_B": {"family": "H05", "vent_delta_by_channel": {"heat": {"0,0": -1}, "contamination": {"1,0": 1}}},
		"VENT_A": {"family": "H05", "vent_delta_by_channel": {"contamination": {"0,0": 3}, "heat": {"0,0": 2}}},
		"LEAK": {"family": "H03"},
	}
	var first: Dictionary = kernel.resolve_phase_d(2, cells, PackedStringArray(["VENT_B", "LEAK", "VENT_A"]), hazards, base)
	_expect(bool(first.get("ok", false)), "composed H05 authority should resolve")
	if not bool(first.get("ok", false)):
		return
	var vent_by_channel: Dictionary = first["vent_by_channel"]
	var heat: Dictionary = vent_by_channel["heat"]
	var contamination: Dictionary = vent_by_channel["contamination"]
	_expect(int(heat["0,0"]) == 2, "sorted H05 deltas should compose on heat venting")
	_expect(int(contamination["0,0"]) == 3, "H05 should add contamination venting")
	_expect(int(contamination["1,0"]) == 3, "H05 should preserve base venting plus delta")
	var events: Array = first["events"]
	_expect(events.size() == 4, "each non-zero H05 vent modification should emit deterministic evidence")
	if events.size() == 4:
		_expect(String(events[0]["event_id"]) == "H05:2:VENT_A:contamination:0,0", "events should follow stable hazard/channel/cell order")
		_expect(String(events[3]["event_id"]) == "H05:2:VENT_B:heat:0,0", "stable event order should not depend on input hazard order")
	_expect(not String(first["authority_checksum"]).is_empty(), "H05 authority must expose checksum evidence")
	var repeated: Dictionary = kernel.resolve_phase_d(2, cells, PackedStringArray(["VENT_A", "VENT_B", "LEAK"]), hazards, base)
	_expect(bool(repeated.get("ok", false)), "reordered active hazard input should resolve")
	if bool(repeated.get("ok", false)):
		_expect(first["vent_by_channel"] == repeated["vent_by_channel"], "H05 output must be independent of active-hazard input order")
		_expect(String(first["authority_payload"]) == String(repeated["authority_payload"]), "H05 authority payload must be deterministic")
		_expect(String(first["authority_checksum"]) == String(repeated["authority_checksum"]), "H05 checksum must be deterministic")

func _test_inactive_h05_preserves_base_venting() -> void:
	var kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0"])
	var base: Dictionary = {"heat": {"0,0": 2}}
	var result: Dictionary = kernel.resolve_phase_d(1, cells, PackedStringArray(["THERMAL"]), {"THERMAL": {"family": "H01"}}, base)
	_expect(bool(result.get("ok", false)), "non-H05 hazards should pass through H05 modifier authority")
	if bool(result.get("ok", false)):
		var heat: Dictionary = result["vent_by_channel"]["heat"]
		_expect(int(heat["0,0"]) == 2, "inactive H05 must preserve base venting")
		_expect((result["events"] as Array).is_empty(), "inactive H05 must emit no modification evidence")

func _test_negative_effective_vent_rejected() -> void:
	var kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var result: Dictionary = kernel.resolve_phase_d(
		1, PackedStringArray(["0,0"]), PackedStringArray(["VENT"]),
		{"VENT": {"family": "H05", "vent_delta_by_channel": {"heat": {"0,0": -1}}}}, {"heat": {"0,0": 0}}
	)
	_expect(not bool(result.get("ok", true)), "H05 may not produce negative effective venting")
	_expect(String(result.get("error", "")).begins_with("negative_h05_effective_vent:"), "negative effective venting should have typed rejection")

func _test_disabled_channel_rejected() -> void:
	var kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var result: Dictionary = kernel.resolve_phase_d(
		1, PackedStringArray(["0,0"]), PackedStringArray(["VENT"]),
		{"VENT": {"family": "H05", "vent_delta_by_channel": {"stress_field": {"0,0": 1}}}}, {"heat": {"0,0": 0}}
	)
	_expect(not bool(result.get("ok", true)), "H05 cannot silently create a channel absent from the Phase-D authority")
	_expect(String(result.get("error", "")).begins_with("h05_channel_not_enabled:"), "disabled-channel rejection should be typed")

func _test_checksum_is_sensitive_to_authored_delta() -> void:
	var kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0"])
	var base: Dictionary = {"contamination": {"0,0": 1}}
	var low: Dictionary = kernel.resolve_phase_d(3, cells, PackedStringArray(["VENT"]), {"VENT": {"family": "H05", "vent_delta_by_channel": {"contamination": {"0,0": 1}}}}, base)
	var high: Dictionary = kernel.resolve_phase_d(3, cells, PackedStringArray(["VENT"]), {"VENT": {"family": "H05", "vent_delta_by_channel": {"contamination": {"0,0": 2}}}}, base)
	_expect(bool(low.get("ok", false)) and bool(high.get("ok", false)), "checksum-sensitivity fixtures should resolve")
	if bool(low.get("ok", false)) and bool(high.get("ok", false)):
		_expect(String(low["authority_checksum"]) != String(high["authority_checksum"]), "authored H05 vent delta must affect deterministic checksum")

func _test_phase_d_production_boundary_all_three_channels() -> void:
	var resolver: PhaseDEnvironmentResolver = PhaseDEnvironmentResolverScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0", "1,0"])
	var generated: Dictionary = {
		"heat": {"0,0": 10, "1,0": 4},
		"stress_field": {"0,0": 10, "1,0": 4},
		"contamination": {"0,0": 10, "1,0": 4},
	}
	var rules: Dictionary = _phase_d_rules()
	var hazards: Dictionary = {
		"VENT": {
			"family": "H05",
			"vent_delta_by_channel": {
				"heat": {"0,0": 2},
				"stress_field": {"0,0": 3},
				"contamination": {"0,0": 4},
			},
		},
	}
	var result: Dictionary = resolver.resolve_phase_d(2, cells, PackedStringArray(["VENT"]), hazards, generated, rules)
	_expect(bool(result.get("ok", false)), "production Phase-D boundary should compose H05 across all enabled frozen channels")
	if not bool(result.get("ok", false)):
		return
	var environment: Dictionary = result["environment_by_channel"]
	var heat: Dictionary = environment["heat"]
	var stress_field: Dictionary = environment["stress_field"]
	var contamination: Dictionary = environment["contamination"]
	_expect(int(heat["0,0"]) == 7, "H05 heat vent must affect Phase-D exposure before response")
	_expect(int(stress_field["0,0"]) == 6, "H05 must map to existing stress-field decay authority")
	_expect(int(contamination["0,0"]) == 5, "H05 contamination vent must affect Phase-D exposure")
	_expect((result["h05_events"] as Array).size() == 3, "production boundary must retain deterministic H05 evidence")
	_expect(not String(result["authority_checksum"]).is_empty(), "production boundary must expose replay-sensitive authority checksum")

func _test_phase_d_production_boundary_inactive_is_kernel_equivalent() -> void:
	var resolver: PhaseDEnvironmentResolver = PhaseDEnvironmentResolverScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0", "1,0"])
	var generated: Dictionary = {
		"heat": {"0,0": 10, "1,0": 4},
		"stress_field": {"0,0": 10, "1,0": 4},
		"contamination": {"0,0": 10, "1,0": 4},
	}
	var rules: Dictionary = _phase_d_rules()
	var result: Dictionary = resolver.resolve_phase_d(1, cells, PackedStringArray(), {}, generated, rules)
	_expect(bool(result.get("ok", false)), "inactive H05 production boundary should resolve")
	if not bool(result.get("ok", false)):
		return
	var generated_heat: Dictionary = generated["heat"]
	var generated_stress: Dictionary = generated["stress_field"]
	var generated_contamination: Dictionary = generated["contamination"]
	var heat_rules: Dictionary = rules["heat"]
	var stress_rules: Dictionary = rules["stress_field"]
	var contamination_rules: Dictionary = rules["contamination"]
	var direct_heat: Dictionary = ThermalResponseKernelScript.new().propagate_heat(generated_heat, cells, heat_rules)
	var direct_stress: Dictionary = StressFieldEnvironmentKernelScript.new().propagate_phase_d(generated_stress, cells, stress_rules)
	var direct_contamination: Dictionary = ContaminationEnvironmentKernelScript.new().propagate_phase_d(generated_contamination, cells, contamination_rules)
	_expect(bool(direct_heat.get("ok", false)) and bool(direct_stress.get("ok", false)) and bool(direct_contamination.get("ok", false)), "direct existing Phase-D kernels should resolve reference fixture")
	if bool(direct_heat.get("ok", false)) and bool(direct_stress.get("ok", false)) and bool(direct_contamination.get("ok", false)):
		var environment: Dictionary = result["environment_by_channel"]
		_expect(environment["heat"] == direct_heat["heat_by_cell"], "inactive H05 must preserve existing heat result byte-equivalent")
		_expect(environment["stress_field"] == direct_stress["stress_field_by_cell"], "inactive H05 must preserve existing stress-field result byte-equivalent")
		_expect(environment["contamination"] == direct_contamination["contamination_by_cell"], "inactive H05 must preserve existing contamination result byte-equivalent")
	_expect((result["h05_events"] as Array).is_empty(), "inactive H05 production boundary must not invent events")

func _phase_d_rules() -> Dictionary:
	return {
		"heat": {"heat_min": 0, "heat_max": 100, "transfer_edges": [], "vent_by_cell": {"0,0": 1, "1,0": 1}},
		"stress_field": {"stress_field_min": 0, "stress_field_max": 100, "transfer_edges": [], "decay_by_cell": {"0,0": 1, "1,0": 1}},
		"contamination": {"contamination_min": 0, "contamination_max": 100, "transfer_edges": [], "vent_by_cell": {"0,0": 1, "1,0": 1}},
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
