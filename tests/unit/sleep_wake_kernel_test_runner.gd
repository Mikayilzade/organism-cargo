extends SceneTree

const SleepWakeKernelScript := preload("res://src/sim/sleep_wake_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_sleep_gate_is_explicit_only()
	_test_h02_wake_request_resolves_at_phase_b()
	_test_stress_only_h02_does_not_wake()
	_test_h02_wake_replay_is_deterministic()
	_test_invalid_target_is_rejected()
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
	var organisms: Array = [
		{"instance_id": "cargo-b", "primary_state": "ASLEEP"},
		{"instance_id": "cargo-a", "primary_state": "ASLEEP"},
	]
	var result: Dictionary = kernel.resolve_phase_b(
		3,
		organisms,
		PackedStringArray(["vibration"]),
		{
			"vibration": {
				"family": "H02",
				"wake_request": true,
				"wake_target_instance_ids": ["cargo-b"],
			},
		}
	)
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
	var result: Dictionary = kernel.resolve_phase_b(
		1,
		[{"instance_id": "cargo-a", "primary_state": "ASLEEP"}],
		PackedStringArray(["vibration"]),
		{"vibration": {"family": "H02", "stress_field_delta": 4}}
	)
	_expect_true(bool(result.get("ok", false)), "stress-only H02 remains a legal non-wake hazard")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(String(result["organisms"][0]["primary_state"]), "ASLEEP", "stress pressure alone does not imply wake")
	_expect_equal(result["events"], [], "no implicit wake event is invented")

func _test_h02_wake_replay_is_deterministic() -> void:
	var kernel: SleepWakeKernel = SleepWakeKernelScript.new()
	var organisms: Array = [
		{"instance_id": "cargo-c", "primary_state": "CALM"},
		{"instance_id": "cargo-b", "primary_state": "ASLEEP"},
		{"instance_id": "cargo-a", "primary_state": "ASLEEP"},
	]
	var hazards: Dictionary = {
		"vibration": {
			"family": "H02",
			"wake_request": true,
			"wake_target_instance_ids": ["cargo-b", "cargo-a", "cargo-c"],
		},
	}
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
	var result: Dictionary = kernel.resolve_phase_b(
		2,
		[{"instance_id": "cargo-a", "primary_state": "ASLEEP"}],
		PackedStringArray(["vibration"]),
		{
			"vibration": {
				"family": "H02",
				"wake_request": true,
				"wake_target_instance_ids": ["missing"],
			},
		}
	)
	_expect_true(not bool(result.get("ok", false)), "unknown explicit wake target is rejected")
	_expect_equal(String(result.get("error", "")), "unknown_h02_wake_target:vibration:missing", "wake target failure is exact")

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)
