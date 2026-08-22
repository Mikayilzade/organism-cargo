extends SceneTree

const H05VentCycleKernelScript := preload("res://src/sim/h05_vent_cycle_kernel.gd")

var failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	_test_deterministic_composition_and_evidence()
	_test_inactive_h05_preserves_base_venting()
	_test_negative_effective_vent_rejected()
	_test_disabled_channel_rejected()
	_test_checksum_is_sensitive_to_authored_delta()
	if failures.is_empty():
		print("H05 Vent Cycle Phase-D modifier tests: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("H05 Vent Cycle Phase-D modifier tests: FAIL (%d)" % failures.size())
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
		"VENT_B": {
			"family": "H05",
			"vent_delta_by_channel": {
				"heat": {"0,0": -1},
				"contamination": {"1,0": 1},
			},
		},
		"VENT_A": {
			"family": "H05",
			"vent_delta_by_channel": {
				"contamination": {"0,0": 3},
				"heat": {"0,0": 2},
			},
		},
		"LEAK": {"family": "H03"},
	}
	var first: Dictionary = kernel.resolve_phase_d(
		2, cells, PackedStringArray(["VENT_B", "LEAK", "VENT_A"]), hazards, base
	)
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

	var repeated: Dictionary = kernel.resolve_phase_d(
		2, cells, PackedStringArray(["VENT_A", "VENT_B", "LEAK"]), hazards, base
	)
	_expect(bool(repeated.get("ok", false)), "reordered active hazard input should resolve")
	if bool(repeated.get("ok", false)):
		_expect(first["vent_by_channel"] == repeated["vent_by_channel"], "H05 output must be independent of active-hazard input order")
		_expect(String(first["authority_payload"]) == String(repeated["authority_payload"]), "H05 authority payload must be deterministic")
		_expect(String(first["authority_checksum"]) == String(repeated["authority_checksum"]), "H05 checksum must be deterministic")

func _test_inactive_h05_preserves_base_venting() -> void:
	var kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0"])
	var base: Dictionary = {"heat": {"0,0": 2}}
	var result: Dictionary = kernel.resolve_phase_d(
		1, cells, PackedStringArray(["THERMAL"]), {"THERMAL": {"family": "H01"}}, base
	)
	_expect(bool(result.get("ok", false)), "non-H05 hazards should pass through H05 modifier authority")
	if bool(result.get("ok", false)):
		var heat: Dictionary = result["vent_by_channel"]["heat"]
		_expect(int(heat["0,0"]) == 2, "inactive H05 must preserve base venting")
		_expect((result["events"] as Array).is_empty(), "inactive H05 must emit no modification evidence")

func _test_negative_effective_vent_rejected() -> void:
	var kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var result: Dictionary = kernel.resolve_phase_d(
		1,
		PackedStringArray(["0,0"]),
		PackedStringArray(["VENT"]),
		{"VENT": {"family": "H05", "vent_delta_by_channel": {"heat": {"0,0": -1}}}},
		{"heat": {"0,0": 0}}
	)
	_expect(not bool(result.get("ok", true)), "H05 may not produce negative effective venting")
	_expect(String(result.get("error", "")).begins_with("negative_h05_effective_vent:"), "negative effective venting should have typed rejection")

func _test_disabled_channel_rejected() -> void:
	var kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var result: Dictionary = kernel.resolve_phase_d(
		1,
		PackedStringArray(["0,0"]),
		PackedStringArray(["VENT"]),
		{"VENT": {"family": "H05", "vent_delta_by_channel": {"stress_field": {"0,0": 1}}}},
		{"heat": {"0,0": 0}}
	)
	_expect(not bool(result.get("ok", true)), "H05 cannot silently create a channel absent from the Phase-D authority")
	_expect(String(result.get("error", "")).begins_with("h05_channel_not_enabled:"), "disabled-channel rejection should be typed")

func _test_checksum_is_sensitive_to_authored_delta() -> void:
	var kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var cells: PackedStringArray = PackedStringArray(["0,0"])
	var base: Dictionary = {"contamination": {"0,0": 1}}
	var low: Dictionary = kernel.resolve_phase_d(
		3, cells, PackedStringArray(["VENT"]),
		{"VENT": {"family": "H05", "vent_delta_by_channel": {"contamination": {"0,0": 1}}}}, base
	)
	var high: Dictionary = kernel.resolve_phase_d(
		3, cells, PackedStringArray(["VENT"]),
		{"VENT": {"family": "H05", "vent_delta_by_channel": {"contamination": {"0,0": 2}}}}, base
	)
	_expect(bool(low.get("ok", false)) and bool(high.get("ok", false)), "checksum-sensitivity fixtures should resolve")
	if bool(low.get("ok", false)) and bool(high.get("ok", false)):
		_expect(String(low["authority_checksum"]) != String(high["authority_checksum"]), "authored H05 vent delta must affect deterministic checksum")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
