extends SceneTree

const T06FilterFeederKernelScript := preload("res://src/sim/t06_filter_feeder_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_conservation_and_satiety_cap()
	_test_contested_resource_is_deterministic()
	_test_inactive_consumer_does_not_mutate_unrelated_state()
	if failures == 0:
		print("t06_filter_feeder_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("t06_filter_feeder_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_conservation_and_satiety_cap() -> void:
	var kernel: T06FilterFeederKernel = T06FilterFeederKernelScript.new()
	var original_field: Dictionary = {"0,0": 5, "1,0": 1}
	var result: Dictionary = kernel.resolve_tick(
		1,
		original_field,
		[_organism("grazer-a", ["0,0", "1,0"], 4, "CALM")],
		[_definition("grazer-a", 4, 2, 10)]
	)
	_expect_true(bool(result.get("ok", false)), "T06 conservation case succeeds")
	if not bool(result.get("ok", false)):
		return
	var field: Dictionary = result["contamination_by_cell"]
	var runtime: Dictionary = result["organisms"][0]
	_expect_equal(int(field["0,0"]) + int(field["1,0"]), 3, "exactly three contamination units remain after capped consumption")
	_expect_equal(int(runtime["satiety"]), 10, "satiety gain is capped exactly at authored maximum")
	_expect_equal(int(original_field["0,0"]), 5, "input contamination snapshot is not mutated in place")
	var consumed_total: int = 0
	for raw_event: Variant in result["events"]:
		var event: Dictionary = raw_event
		if String(event.get("kind", "")) == "T06_CONTAMINATION_CONSUMED":
			consumed_total += int(event["consumed_amount"])
	_expect_equal(consumed_total, 3, "consumption evidence equals field reduction")

func _test_contested_resource_is_deterministic() -> void:
	var kernel: T06FilterFeederKernel = T06FilterFeederKernelScript.new()
	var organisms: Array = [
		_organism("b", ["0,0"], 0, "CALM"),
		_organism("a", ["0,0"], 0, "CALM"),
	]
	var definitions: Array = [
		_definition("b", 2, 1, 10),
		_definition("a", 2, 1, 10),
	]
	var first: Dictionary = kernel.resolve_tick(2, {"0,0": 3}, organisms, definitions)
	var second: Dictionary = kernel.resolve_tick(2, {"0,0": 3}, organisms.duplicate(true), definitions.duplicate(true))
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "contested T06 runs succeed")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		return
	_expect_equal(first, second, "identical contested input produces identical allocation and evidence")
	var satiety_by_id: Dictionary = {}
	for raw_runtime: Variant in first["organisms"]:
		var runtime: Dictionary = raw_runtime
		satiety_by_id[String(runtime["instance_id"])] = int(runtime["satiety"])
	_expect_equal(int(satiety_by_id["a"]), 2, "stable instance-id order receives first and third indivisible units")
	_expect_equal(int(satiety_by_id["b"]), 1, "second consumer receives second indivisible unit")
	_expect_equal(int(first["contamination_by_cell"]["0,0"]), 0, "contested consumers cannot overdraw the resource")

func _test_inactive_consumer_does_not_mutate_unrelated_state() -> void:
	var kernel: T06FilterFeederKernel = T06FilterFeederKernelScript.new()
	var organism: Dictionary = _organism("sleepy", ["0,0"], 3, "ASLEEP")
	organism["stress"] = 7
	organism["marker"] = "preserve"
	var definition: Dictionary = _definition("sleepy", 2, 1, 10)
	definition["sleep_gated"] = true
	var result: Dictionary = kernel.resolve_tick(3, {"0,0": 4}, [organism], [definition])
	_expect_true(bool(result.get("ok", false)), "sleep-gated T06 case succeeds")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(int(result["contamination_by_cell"]["0,0"]), 4, "inactive T06 consumes no contamination")
	var runtime: Dictionary = result["organisms"][0]
	_expect_equal(int(runtime["satiety"]), 3, "inactive T06 changes no satiety")
	_expect_equal(int(runtime["stress"]), 7, "T06 does not mutate unrelated stress")
	_expect_equal(String(runtime["marker"]), "preserve", "T06 preserves unrelated runtime fields")
	_expect_equal(result["events"], [], "inactive T06 emits no causal events")

func _organism(instance_id: String, cells: Array, satiety: int, primary_state: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"occupied_cells": cells.duplicate(true),
		"satiety": satiety,
		"primary_state": primary_state,
		"body_stage": "MATURE",
	}

func _definition(instance_id: String, capacity: int, benefit_per_unit: int, satiety_max: int) -> Dictionary:
	return {
		"instance_id": instance_id,
		"capacity": capacity,
		"benefit_per_unit": benefit_per_unit,
		"satiety_max": satiety_max,
		"active_primary_states": ["CALM", "AGITATED", "PANICKED"],
		"active_body_stages": [],
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
