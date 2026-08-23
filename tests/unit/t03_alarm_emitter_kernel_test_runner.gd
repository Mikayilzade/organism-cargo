extends SceneTree

const T03AlarmEmitterKernelScript := preload("res://src/sim/t03_alarm_emitter_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_state_gate_and_local_source()
	_test_multiple_sources_resolve_in_stable_order()
	_test_sleep_requires_explicit_gate()
	_test_invalid_output_rejected()
	_test_replay_is_deterministic()
	if failures == 0:
		print("t03_alarm_emitter_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("t03_alarm_emitter_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_state_gate_and_local_source() -> void:
	var kernel: T03AlarmEmitterKernel = T03AlarmEmitterKernelScript.new()
	var field: Dictionary = {"0,0": 1, "1,0": 0}
	var organisms: Array = [
		{"instance_id": "alarm-a", "primary_state": "AGITATED", "occupied_cells": ["0,0"]},
		{"instance_id": "alarm-b", "primary_state": "CALM", "occupied_cells": ["1,0"]},
	]
	var defs: Array = [
		{"instance_id": "alarm-b", "output_amount": 2, "active_primary_states": ["AGITATED"], "sleep_gated": false},
		{"instance_id": "alarm-a", "output_amount": 3, "active_primary_states": ["AGITATED"], "sleep_gated": false},
	]
	var result: Dictionary = kernel.apply_phase_c(4, field, organisms, defs)
	_expect_true(bool(result.get("ok", false)), "T03 state-gated source resolves")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(result["stress_field_by_cell"], {"0,0": 4, "1,0": 0}, "only eligible alarm source contributes locally")
	var events: Array = result["events"]
	_expect_equal(events.size(), 1, "only active T03 source emits evidence")
	if not events.is_empty():
		var event: Dictionary = events[0]
		_expect_equal(String(event.get("kind", "")), "T03_STRESS_FIELD_SOURCE", "T03 evidence retains source identity")
		_expect_equal(int(event.get("tick", 0)), 4, "T03 evidence retains tick")
		_expect_equal(String(event.get("phase", "")), "C", "T03 evidence retains Phase C")
		_expect_equal(int(event.get("stress_field_delta", 0)), 3, "T03 evidence records output amount")

func _test_multiple_sources_resolve_in_stable_order() -> void:
	var kernel: T03AlarmEmitterKernel = T03AlarmEmitterKernelScript.new()
	var organisms: Array = [
		{"instance_id": "z-source", "primary_state": "PANICKED", "occupied_cells": ["1,0"]},
		{"instance_id": "a-source", "primary_state": "PANICKED", "occupied_cells": ["0,0"]},
	]
	var defs: Array = [
		{"instance_id": "z-source", "output_amount": 4, "active_primary_states": ["PANICKED"], "sleep_gated": false},
		{"instance_id": "a-source", "output_amount": 2, "active_primary_states": ["PANICKED"], "sleep_gated": false},
	]
	var result: Dictionary = kernel.apply_phase_c(1, {"0,0": 0, "1,0": 0}, organisms, defs)
	_expect_true(bool(result.get("ok", false)), "multiple T03 sources resolve")
	if not bool(result.get("ok", false)):
		return
	var events: Array = result["events"]
	_expect_equal(events.size(), 2, "multiple T03 sources each emit evidence")
	if events.size() == 2:
		_expect_equal(String((events[0] as Dictionary).get("instance_id", "")), "a-source", "T03 source ordering is stable by instance_id")
		_expect_equal(String((events[1] as Dictionary).get("instance_id", "")), "z-source", "later T03 source follows stable ordering")

func _test_sleep_requires_explicit_gate() -> void:
	var kernel: T03AlarmEmitterKernel = T03AlarmEmitterKernelScript.new()
	var organism: Array = [{"instance_id": "alarm-a", "primary_state": "ASLEEP", "occupied_cells": ["0,0"]}]
	var ungated: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 0},
		organism,
		[{"instance_id": "alarm-a", "output_amount": 2, "active_primary_states": ["AGITATED"], "sleep_gated": false}]
	)
	var gated: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 0},
		organism,
		[{"instance_id": "alarm-a", "output_amount": 2, "active_primary_states": ["AGITATED"], "sleep_gated": true}]
	)
	_expect_true(bool(ungated.get("ok", false)) and bool(gated.get("ok", false)), "sleep-gating variants resolve")
	if bool(ungated.get("ok", false)):
		_expect_equal(int(ungated["stress_field_by_cell"]["0,0"]), 2, "sleep alone does not suppress T03")
	if bool(gated.get("ok", false)):
		_expect_equal(int(gated["stress_field_by_cell"]["0,0"]), 0, "explicit sleep gate suppresses T03")

func _test_invalid_output_rejected() -> void:
	var kernel: T03AlarmEmitterKernel = T03AlarmEmitterKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 0},
		[{"instance_id": "alarm-a", "primary_state": "AGITATED", "occupied_cells": ["0,0"]}],
		[{"instance_id": "alarm-a", "output_amount": 5, "active_primary_states": ["AGITATED"], "sleep_gated": false}]
	)
	_expect_true(not bool(result.get("ok", false)), "T03 rejects output outside frozen continuous source bands")
	_expect_equal(String(result.get("error", "")), "invalid_t03_output_amount:alarm-a", "T03 invalid-band error is explicit")

func _test_replay_is_deterministic() -> void:
	var kernel: T03AlarmEmitterKernel = T03AlarmEmitterKernelScript.new()
	var field: Dictionary = {"0,0": 0, "1,0": 1}
	var organisms: Array = [
		{"instance_id": "alarm-a", "primary_state": "PANICKED", "occupied_cells": ["1,0", "0,0"]},
	]
	var defs: Array = [
		{"instance_id": "alarm-a", "output_amount": 3, "active_primary_states": ["PANICKED"], "sleep_gated": false},
	]
	var first: Dictionary = kernel.apply_phase_c(7, field, organisms, defs)
	var second: Dictionary = kernel.apply_phase_c(7, field, organisms, defs)
	_expect_equal(first, second, "T03 replay is byte-equivalent")

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
