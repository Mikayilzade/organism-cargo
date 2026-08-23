extends SceneTree

const T02HeatSinkKernelScript := preload("res://src/sim/t02_heat_sink_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_local_sink_removes_only_up_to_capacity()
	_test_multicell_sink_shares_one_capacity_deterministically()
	_test_multiple_sinks_use_stable_instance_order()
	_test_sleep_gating_is_explicit_only()
	_test_invalid_capacity_fails_closed()
	if failures == 0:
		print("t02_heat_sink_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("t02_heat_sink_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_local_sink_removes_only_up_to_capacity() -> void:
	var kernel: T02HeatSinkKernel = T02HeatSinkKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 7, "1,0": 5},
		[_organism("sink-a", ["0,0"], "CALM")],
		[_definition("sink-a", 3)]
	)
	_expect_true(bool(result.get("ok", false)), "T02 local sink resolves")
	_expect_equal(int(result["heat_by_cell"]["0,0"]), 4, "T02 removes exactly configured local capacity")
	_expect_equal(int(result["heat_by_cell"]["1,0"]), 5, "T02 does not affect unoccupied cells")
	var events: Array = result["events"]
	_expect_equal(events.size(), 1, "one material removal emits one event")
	_expect_equal(String(events[0]["phase"]), "C", "T02 owns Phase C")
	_expect_equal(int(events[0]["removed_heat"]), 3, "event records exact removal")

func _test_multicell_sink_shares_one_capacity_deterministically() -> void:
	var kernel: T02HeatSinkKernel = T02HeatSinkKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		2,
		{"0,0": 1, "1,0": 5},
		[_organism("sink-a", ["1,0", "0,0"], "CALM")],
		[_definition("sink-a", 4)]
	)
	_expect_true(bool(result.get("ok", false)), "multi-cell T02 resolves")
	_expect_equal(int(result["heat_by_cell"]["0,0"]), 0, "sorted first occupied cell consumes available heat")
	_expect_equal(int(result["heat_by_cell"]["1,0"]), 2, "remaining capacity is spent on next occupied cell")
	var events: Array = result["events"]
	_expect_equal(events.size(), 2, "multi-cell removal records both material cells")
	_expect_equal(String(events[0]["cell_key"]), "0,0", "occupied cells resolve in stable key order")
	_expect_equal(int(events[0]["removed_heat"]), 1, "first cell consumes one unit")
	_expect_equal(int(events[1]["removed_heat"]), 3, "second cell consumes remaining capacity")
	var sinks: Array = result["active_sinks"]
	_expect_equal(int(sinks[0]["removed_heat"]), 4, "one organism capacity is shared across its footprint")

func _test_multiple_sinks_use_stable_instance_order() -> void:
	var kernel: T02HeatSinkKernel = T02HeatSinkKernelScript.new()
	var organisms: Array = [
		_organism("sink-b", ["0,0"], "CALM"),
		_organism("sink-a", ["0,0"], "CALM"),
	]
	var definitions: Array = [_definition("sink-b", 3), _definition("sink-a", 2)]
	var first: Dictionary = kernel.apply_phase_c(1, {"0,0": 4}, organisms, definitions)
	definitions.reverse()
	organisms.reverse()
	var second: Dictionary = kernel.apply_phase_c(1, {"0,0": 4}, organisms, definitions)
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "multi-sink T02 resolves")
	_expect_equal(first, second, "input ordering does not change T02 authority")
	var events: Array = first["events"]
	_expect_equal(String(events[0]["instance_id"]), "sink-a", "sink allocation is stable by instance ID")
	_expect_equal(int(events[0]["removed_heat"]), 2, "first sink consumes its capacity")
	_expect_equal(int(events[1]["removed_heat"]), 2, "second sink consumes only remaining heat")
	_expect_equal(int(first["heat_by_cell"]["0,0"]), 0, "combined sinks clamp at available heat")

func _test_sleep_gating_is_explicit_only() -> void:
	var kernel: T02HeatSinkKernel = T02HeatSinkKernelScript.new()
	var passive_definition: Dictionary = _definition("sink-a", 2)
	var passive: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 5},
		[_organism("sink-a", ["0,0"], "ASLEEP")],
		[passive_definition]
	)
	_expect_true(bool(passive.get("ok", false)), "asleep non-gated sink resolves")
	_expect_equal(int(passive["heat_by_cell"]["0,0"]), 3, "sleep does not implicitly disable T02")
	var gated_definition: Dictionary = _definition("sink-a", 2)
	gated_definition["sleep_gated"] = true
	var gated: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 5},
		[_organism("sink-a", ["0,0"], "ASLEEP")],
		[gated_definition]
	)
	_expect_true(bool(gated.get("ok", false)), "explicit sleep-gated sink resolves as no-op")
	_expect_equal(int(gated["heat_by_cell"]["0,0"]), 5, "explicit sleep gate disables T02")
	_expect_equal((gated["events"] as Array).size(), 0, "disabled sink emits no material event")

func _test_invalid_capacity_fails_closed() -> void:
	var kernel: T02HeatSinkKernel = T02HeatSinkKernelScript.new()
	var result: Dictionary = kernel.apply_phase_c(
		1,
		{"0,0": 5},
		[_organism("sink-a", ["0,0"], "CALM")],
		[_definition("sink-a", 5)]
	)
	_expect_true(not bool(result.get("ok", false)), "out-of-band T02 capacity fails closed")
	_expect_equal(String(result.get("error", "")), "invalid_t02_capacity:sink-a", "invalid capacity has deterministic error")

func _organism(instance_id: String, occupied_cells: Array, primary_state: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"occupied_cells": occupied_cells.duplicate(true),
		"primary_state": primary_state,
	}

func _definition(instance_id: String, capacity: int) -> Dictionary:
	return {
		"instance_id": instance_id,
		"capacity": capacity,
		"active_primary_states": [],
		"sleep_gated": false,
	}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
