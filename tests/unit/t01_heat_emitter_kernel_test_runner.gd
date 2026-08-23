extends SceneTree

const T01HeatEmitterKernelScript := preload("res://src/sim/t01_heat_emitter_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_emits_on_each_occupied_cell_in_stable_order()
	_test_sleep_is_not_implicit_suppression()
	_test_explicit_sleep_gate_suppresses()
	_test_state_gate_and_parameter_band_validation()
	if failures == 0:
		print("t01_heat_emitter_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("t01_heat_emitter_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_emits_on_each_occupied_cell_in_stable_order() -> void:
	var kernel: T01HeatEmitterKernel = T01HeatEmitterKernelScript.new()
	var heat: Dictionary = {"0,0": 1, "1,0": 2, "2,0": 0}
	var organisms: Array = [
		{"instance_id": "b", "primary_state": "CALM", "occupied_cells": ["2,0"]},
		{"instance_id": "a", "primary_state": "AGITATED", "occupied_cells": ["1,0", "0,0"]},
	]
	var definitions: Array = [
		{"instance_id": "b", "output_amount": 2, "active_primary_states": []},
		{"instance_id": "a", "output_amount": 3, "active_primary_states": ["AGITATED"]},
	]
	var result: Dictionary = kernel.apply_phase_c(4, heat, organisms, definitions)
	_expect_true(bool(result.get("ok", false)), "T01 deterministic Phase-C emission resolves")
	if not bool(result.get("ok", false)):
		return
	var next_heat: Dictionary = result["heat_by_cell"]
	_expect_equal(int(next_heat["0,0"]), 4, "first occupied cell receives authored continuous output")
	_expect_equal(int(next_heat["1,0"]), 5, "second occupied cell receives authored continuous output")
	_expect_equal(int(next_heat["2,0"]), 2, "second source emits independently")
	var events: Array = result["events"]
	_expect_equal(events.size(), 3, "one evidence event is emitted per affected occupied cell")
	if events.size() == 3:
		var e0: Dictionary = events[0]
		var e1: Dictionary = events[1]
		var e2: Dictionary = events[2]
		_expect_equal(String(e0["event_id"]), "t0004:C:T01:a:0,0", "definitions and cells use stable canonical ordering")
		_expect_equal(String(e1["event_id"]), "t0004:C:T01:a:1,0", "multi-cell body ordering is stable")
		_expect_equal(String(e2["event_id"]), "t0004:C:T01:b:2,0", "later source follows stable instance identity")

func _test_sleep_is_not_implicit_suppression() -> void:
	var kernel: T01HeatEmitterKernel = T01HeatEmitterKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 0},
		[{"instance_id": "sleeper", "primary_state": "ASLEEP", "occupied_cells": ["0,0"]}],
		[{"instance_id": "sleeper", "output_amount": 4, "active_primary_states": [], "sleep_gated": false}]
	)
	_expect_true(bool(result.get("ok", false)), "ungated sleeping T01 source resolves")
	if bool(result.get("ok", false)):
		var heat: Dictionary = result["heat_by_cell"]
		_expect_equal(int(heat["0,0"]), 4, "sleep alone does not suppress passive heat emission")
		_expect_equal((result["events"] as Array).size(), 1, "ungated sleeper remains an authoritative source")

func _test_explicit_sleep_gate_suppresses() -> void:
	var kernel: T01HeatEmitterKernel = T01HeatEmitterKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		2,
		{"0,0": 3},
		[{"instance_id": "gated", "primary_state": "ASLEEP", "occupied_cells": ["0,0"]}],
		[{"instance_id": "gated", "output_amount": 2, "active_primary_states": [], "sleep_gated": true}]
	)
	_expect_true(bool(result.get("ok", false)), "explicitly sleep-gated T01 source resolves")
	if bool(result.get("ok", false)):
		var heat: Dictionary = result["heat_by_cell"]
		_expect_equal(int(heat["0,0"]), 3, "explicit sleep gate suppresses output")
		_expect_true((result["events"] as Array).is_empty(), "suppressed source emits no causal heat event")

func _test_state_gate_and_parameter_band_validation() -> void:
	var kernel: T01HeatEmitterKernel = T01HeatEmitterKernelScript.new()
	var inactive: Dictionary = kernel.apply_phase_c(
		3,
		{"0,0": 0},
		[{"instance_id": "stateful", "primary_state": "CALM", "occupied_cells": ["0,0"]}],
		[{"instance_id": "stateful", "output_amount": 3, "active_primary_states": ["PANICKED"]}]
	)
	_expect_true(bool(inactive.get("ok", false)), "legal inactive state gate resolves")
	if bool(inactive.get("ok", false)):
		var heat: Dictionary = inactive["heat_by_cell"]
		_expect_equal(int(heat["0,0"]), 0, "state-gated source emits only in declared state")
	var invalid_amount: Dictionary = kernel.apply_phase_c(
		3,
		{"0,0": 0},
		[{"instance_id": "bad", "primary_state": "CALM", "occupied_cells": ["0,0"]}],
		[{"instance_id": "bad", "output_amount": 5, "active_primary_states": []}]
	)
	_expect_true(not bool(invalid_amount.get("ok", true)), "continuous output outside frozen weak/standard/strong band is rejected")
	_expect_equal(String(invalid_amount.get("error", "")), "invalid_t01_output_amount:bad", "invalid T01 magnitude has typed rejection")

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
