extends SceneTree

const SleepWakeKernelScript := preload("res://src/sim/sleep_wake_kernel.gd")
const StressFieldResponseKernelScript := preload("res://src/sim/stress_field_response_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_sleep_gate_is_explicit_only()
	_test_h02_wake_request_resolves_at_phase_b()
	_test_stress_only_h02_does_not_wake()
	_test_h02_wake_replay_is_deterministic()
	_test_invalid_target_is_rejected()
	_test_asleep_state_survives_stress_field_e_f_g_without_explicit_wake()
	_test_production_mixed_h01_h02_wake_before_stress_response()
	if failures == 0:
		print("sleep_wake_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("sleep_wake_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_sleep_gate_is_explicit_only() -> void:
	var kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	_expect_true(not kernel.sleep_gate_allows("ASLEEP", true), "sleep-gated behavior is disabled while ASLEEP")
	_expect_true(kernel.sleep_gate_allows("ASLEEP", false), "ungated behavior remains active while ASLEEP")
	_expect_true(kernel.sleep_gate_allows("CALM", true), "sleep-gated behavior is active after wake")
	_expect_true(not kernel.sleep_gate_allows("UNKNOWN", false), "unknown state never passes sleep gating")

func _test_h02_wake_request_resolves_at_phase_b() -> void:
	var kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	var organisms: Array = [{"instance_id": "cargo-b", "primary_state": "ASLEEP"}, {"instance_id": "cargo-a", "primary_state": "ASLEEP"}]
	var result: Dictionary = kernel.resolve_phase_b(3, organisms, PackedStringArray(["vibration"]), {"vibration": {"family": "H02", "wake_request": true, "wake_target_instance_ids": ["cargo-b"]}})
	_expect_true(bool(result.get("ok", false)), "H02 explicit wake request resolves")
	if not bool(result.get("ok", false)):
		return
	var runtime: Array = result["organisms"]
	_expect_equal(String(runtime[0]["instance_id"]), "cargo-a", "runtime identity order is stable")
	_expect_equal(String(runtime[0]["primary_state"]), "ASLEEP", "untargeted sleeper remains asleep")
	_expect_equal(String(runtime[1]["primary_state"]), "CALM", "targeted sleeper wakes at the Phase-B boundary")
	var events: Array = result["events"]
	_expect_equal(events.size(), 1, "one actual ASLEEP-to-awake transition emits one event")
	_expect_equal(String(events[0]["phase"]), "B", "wake event records exact canonical Phase B")
	_expect_equal(String(events[0]["kind"]), "H02_WAKE_REQUEST_APPLIED", "wake event is explicit H02 authority")
	_expect_equal(events[0]["parent_event_ids"], PackedStringArray(["route:A:3:vibration"]), "wake transition retains route-hazard parentage")
	_expect_true(kernel.sleep_gate_allows(String(runtime[1]["primary_state"]), true), "same-tick post-Phase-B sleep gate sees the organism awake")

func _test_stress_only_h02_does_not_wake() -> void:
	var kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	var result: Dictionary = kernel.resolve_phase_b(1, [{"instance_id": "cargo-a", "primary_state": "ASLEEP"}], PackedStringArray(["vibration"]), {"vibration": {"family": "H02", "stress_field_delta": 4}})
	_expect_true(bool(result.get("ok", false)), "stress-only H02 remains a legal non-wake hazard")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(String(result["organisms"][0]["primary_state"]), "ASLEEP", "stress pressure alone does not imply wake")
	_expect_equal(result["events"], [], "no implicit wake event is invented")

func _test_h02_wake_replay_is_deterministic() -> void:
	var kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	var organisms: Array = [{"instance_id": "cargo-c", "primary_state": "CALM"}, {"instance_id": "cargo-b", "primary_state": "ASLEEP"}, {"instance_id": "cargo-a", "primary_state": "ASLEEP"}]
	var hazards: Dictionary = {"vibration": {"family": "H02", "wake_request": true, "wake_target_instance_ids": ["cargo-b", "cargo-a", "cargo-c"]}}
	var first: Dictionary = kernel.resolve_phase_b(4, organisms, PackedStringArray(["vibration"]), hazards)
	var second: Dictionary = kernel.resolve_phase_b(4, organisms, PackedStringArray(["vibration"]), hazards)
	_expect_equal(first, second, "H02 wake replay is deterministic")
	if not bool(first.get("ok", false)):
		return
	var events: Array = first["events"]
	_expect_equal(events.size(), 2, "already-awake target does not emit a fake wake transition")
	_expect_equal(String(events[0]["instance_id"]), "cargo-a", "wake target processing is stable by instance ID")
	_expect_equal(String(events[1]["instance_id"]), "cargo-b", "wake target processing remains stable")

func _test_invalid_target_is_rejected() -> void:
	var kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	var result: Dictionary = kernel.resolve_phase_b(2, [{"instance_id": "cargo-a", "primary_state": "ASLEEP"}], PackedStringArray(["vibration"]), {"vibration": {"family": "H02", "wake_request": true, "wake_target_instance_ids": ["missing"]}})
	_expect_true(not bool(result.get("ok", false)), "unknown explicit wake target is rejected")
	_expect_equal(String(result.get("error", "")), "unknown_h02_wake_target:vibration:missing", "wake target failure is exact")

func _test_asleep_state_survives_stress_field_e_f_g_without_explicit_wake() -> void:
	var kernel: StressFieldResponseKernel = StressFieldResponseKernelScript.new()
	var organism: Dictionary = {"instance_id": "cargo-a", "occupied_cells": ["0,0"], "stress": 1, "primary_state": "ASLEEP", "stress_profile": {"stress_min": 0, "stress_max": 10, "agitated_enter": 4, "agitated_exit": 2, "panic_enter": 8, "panic_exit": 6}}
	var sampled: Dictionary = kernel.sample_phase_e(1, [organism], {"0,0": 5})
	_expect_true(bool(sampled.get("ok", false)), "ASLEEP organism still samples ungated environmental stress")
	if not bool(sampled.get("ok", false)):
		return
	var phase_f: Dictionary = kernel.apply_phase_f(1, [organism], sampled["observations"])
	_expect_true(bool(phase_f.get("ok", false)), "ASLEEP organism still accumulates internal stress")
	if not bool(phase_f.get("ok", false)):
		return
	_expect_equal(int(phase_f["organisms"][0]["stress"]), 6, "sleep does not silently suppress stress-field intake")
	var phase_g: Dictionary = kernel.evaluate_phase_g(1, phase_f["organisms"], phase_f["phase_f_event_id_by_instance_id"])
	_expect_true(bool(phase_g.get("ok", false)), "Phase G accepts canonical ASLEEP primary state")
	if not bool(phase_g.get("ok", false)):
		return
	_expect_equal(String(phase_g["organisms"][0]["primary_state"]), "ASLEEP", "stress threshold alone never wakes an organism")
	_expect_equal(phase_g["events"], [], "no fake wake or mood transition is emitted while ASLEEP")

func _test_production_mixed_h01_h02_wake_before_stress_response() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var wake_defs: Dictionary = _production_sleep_defs(true)
	var first: Dictionary = runner.simulate(_production_sleep_record(), 1, wake_defs)
	var replay: Dictionary = runner.simulate(_production_sleep_record(), 1, wake_defs)
	var no_wake: Dictionary = runner.simulate(_production_sleep_record(), 1, _production_sleep_defs(false))
	_expect_true(bool(first.get("ok", false)), "mixed H01/H02 production run accepts an authored ASLEEP organism")
	_expect_equal(first, replay, "mixed H01/H02 wake production replay is deterministic")
	_expect_true(bool(no_wake.get("ok", false)), "comparison run without explicit wake remains valid")
	if not bool(first.get("ok", false)) or not bool(no_wake.get("ok", false)):
		return
	var snapshot: Dictionary = first["end_tick_snapshots"][0]
	var runtime: Array = snapshot["organism_runtime"]
	_expect_equal(int(runtime[0]["stress"]), 5, "thermal stress is preserved before H02 stress-field intake")
	_expect_equal(String(runtime[0]["primary_state"]), "AGITATED", "Phase-B wake allows same-tick Phase-G hysteresis after combined stress")
	var wake_events: Array = snapshot["sleep_wake_events"]
	_expect_equal(wake_events.size(), 1, "production snapshot records one explicit wake transition")
	_expect_equal(String(wake_events[0]["phase"]), "B", "production wake remains at canonical Phase B")
	_expect_equal(String(wake_events[0]["kind"]), "H02_WAKE_REQUEST_APPLIED", "production wake retains explicit H02 authority")
	_expect_equal(wake_events[0]["parent_event_ids"], PackedStringArray(["route:A:1:h02-vibration"]), "production wake retains route-hazard causal parent")
	var response_events: Array = snapshot["stress_field_response_events"]
	_expect_equal(response_events.size(), 4, "checksum-visible response evidence contains B wake then E/F/G response")
	_expect_equal(String(response_events[0]["phase"]), "B", "wake evidence precedes stress-field E/F/G evidence")
	_expect_equal(String(response_events[1]["phase"]), "E", "stress exposure follows Phase-B wake")
	_expect_equal(String(response_events[2]["phase"]), "F", "internal meter update follows exposure")
	_expect_equal(String(response_events[3]["phase"]), "G", "mood threshold is evaluated after wake and meter update")
	var sleeping_snapshot: Dictionary = no_wake["end_tick_snapshots"][0]
	_expect_equal(int(sleeping_snapshot["organism_runtime"][0]["stress"]), 5, "removing wake request does not remove ungated stress intake")
	_expect_equal(String(sleeping_snapshot["organism_runtime"][0]["primary_state"]), "ASLEEP", "without explicit wake the organism remains ASLEEP despite threshold stress")
	_expect_equal(sleeping_snapshot["sleep_wake_events"], [], "comparison run emits no fake wake evidence")
	_expect_true(String(first["tick_checksums"][0]) != String(no_wake["tick_checksums"][0]), "explicit wake authority is checksum-visible")

func _production_sleep_record() -> Dictionary:
	return {
		"run_id": "sleep-wake-production-run",
		"rules_version": "rules-r1",
		"content_version": "sleep-wake-integration-1",
		"canonical_committed_input": {
			"route_id": "route-sleep-wake",
			"seed": 93,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _production_sleep_defs(with_wake: bool) -> Dictionary:
	return {
		"route_profile": {
			"id": "route-sleep-wake",
			"tick_count": 1,
			"events": [
				{"tick": 1, "duration_ticks": 1, "hazard_id": "h02-vibration", "authored_order": 0},
				{"tick": 1, "duration_ticks": 1, "hazard_id": "h01-heat", "authored_order": 1},
			],
		},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {
			"h02-vibration": {"family": "H02", "stress_field_delta": 3, "target_cells": ["0,0"], "wake_request": with_wake, "wake_target_instance_ids": ["cargo-a"]},
			"h01-heat": {"family": "H01", "target_scope": "hold", "heat_delta": 4},
		},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"organism_definitions": {
			"cargo-a": {
				"initial_stress": 0,
				"initial_state": "ASLEEP",
				"stress_profile": _production_stress_profile(),
			},
		},
		"support_definitions_by_id": {},
	}

func _production_stress_profile() -> Dictionary:
	return {
		"heat_safe_max": 2,
		"stress_per_heat_unit": 1,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 5,
		"agitated_exit": 3,
		"panic_enter": 10,
		"panic_exit": 7,
	}

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)
