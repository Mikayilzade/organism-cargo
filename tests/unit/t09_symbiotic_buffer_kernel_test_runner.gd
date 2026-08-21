extends SceneTree

const T09SymbioticBufferKernelScript := preload("res://src/sim/t09_symbiotic_buffer_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_nearest_then_instance_id_selects_one_target()
	_test_explicit_compatibility_and_range_prevent_universal_protection()
	_test_sleep_gate_disables_source_without_side_effects()
	_test_multiple_sources_combine_target_intake_multipliers_deterministically()
	_test_invalid_multi_target_capacity_fails_closed()
	if failures == 0:
		print("t09_symbiotic_buffer_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("t09_symbiotic_buffer_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_nearest_then_instance_id_selects_one_target() -> void:
	var kernel: T09SymbioticBufferKernel = T09SymbioticBufferKernelScript.new()
	var organisms: Array = [
		_organism("buffer", ["0,0"], "CALM"),
		_organism("target-b", ["0,1"], "CALM"),
		_organism("target-a", ["1,0"], "CALM"),
	]
	var result: Dictionary = kernel.resolve_tick(
		1,
		organisms,
		[_definition("buffer", ["target-b", "target-a"], 1, 500)]
	)
	_expect_true(bool(result.get("ok", false)), "nearest/id T09 case succeeds")
	if not bool(result.get("ok", false)):
		return
	var modifiers: Dictionary = result["intake_multiplier_scaled_by_target_id"]
	_expect_equal(modifiers.size(), 1, "one T09 source protects exactly one target")
	_expect_equal(int(modifiers["target-a"]), 500, "equal-distance tie resolves to lowest target instance_id")
	_expect_true(not modifiers.has("target-b"), "second compatible target is not also protected")
	var events: Array = result["events"]
	_expect_equal(events.size(), 1, "one assignment emits one causal event")
	if events.size() == 1:
		_expect_equal(String(events[0]["phase"]), "E", "T09 assignment is a Phase-E direct interaction")
		_expect_equal(String(events[0]["target_instance_id"]), "target-a", "causal evidence names selected target")

func _test_explicit_compatibility_and_range_prevent_universal_protection() -> void:
	var kernel: T09SymbioticBufferKernel = T09SymbioticBufferKernelScript.new()
	var organisms: Array = [
		_organism("buffer", ["0,0"], "CALM"),
		_organism("compatible-far", ["2,0"], "CALM"),
		_organism("incompatible-near", ["1,0"], "CALM"),
		_organism("compatible-too-far", ["3,0"], "CALM"),
	]
	var result: Dictionary = kernel.resolve_tick(
		2,
		organisms,
		[_definition("buffer", ["compatible-far", "compatible-too-far"], 2, 800)]
	)
	_expect_true(bool(result.get("ok", false)), "compatibility/range T09 case succeeds")
	if not bool(result.get("ok", false)):
		return
	var modifiers: Dictionary = result["intake_multiplier_scaled_by_target_id"]
	_expect_equal(modifiers.size(), 1, "compatibility plus one-target capacity prevents universal protection")
	_expect_equal(int(modifiers["compatible-far"]), 800, "eligible target inside authored range receives buffer")
	_expect_true(not modifiers.has("incompatible-near"), "closer but incompatible organism is never selected")
	_expect_true(not modifiers.has("compatible-too-far"), "compatible organism outside authored range is not protected")

func _test_sleep_gate_disables_source_without_side_effects() -> void:
	var kernel: T09SymbioticBufferKernel = T09SymbioticBufferKernelScript.new()
	var source: Dictionary = _organism("buffer", ["0,0"], "ASLEEP")
	source["marker"] = "preserve"
	var target: Dictionary = _organism("target", ["1,0"], "CALM")
	target["contamination_load"] = 7
	var definition: Dictionary = _definition("buffer", ["target"], 1, 500)
	definition["sleep_gated"] = true
	var organisms: Array = [source, target]
	var before: Array = organisms.duplicate(true)
	var result: Dictionary = kernel.resolve_tick(3, organisms, [definition])
	_expect_true(bool(result.get("ok", false)), "sleep-gated T09 case succeeds")
	if not bool(result.get("ok", false)):
		return
	_expect_equal(result["intake_multiplier_scaled_by_target_id"], {}, "sleep-gated source grants no intake modifier")
	_expect_equal(result["events"], [], "sleep-gated source emits no assignment event")
	_expect_equal(organisms, before, "T09 resolver never mutates organism runtime in place")

func _test_multiple_sources_combine_target_intake_multipliers_deterministically() -> void:
	var kernel: T09SymbioticBufferKernel = T09SymbioticBufferKernelScript.new()
	var organisms: Array = [
		_organism("buffer-b", ["2,0"], "CALM"),
		_organism("target", ["1,0"], "CALM"),
		_organism("buffer-a", ["0,0"], "CALM"),
	]
	var definitions: Array = [
		_definition("buffer-b", ["target"], 1, 800),
		_definition("buffer-a", ["target"], 1, 500),
	]
	var first: Dictionary = kernel.resolve_tick(4, organisms, definitions)
	var definition_second: Dictionary = definitions[1]
	var definition_first: Dictionary = definitions[0]
	var reversed_definitions: Array = [definition_second.duplicate(true), definition_first.duplicate(true)]
	var second: Dictionary = kernel.resolve_tick(4, organisms.duplicate(true), reversed_definitions)
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "stacked T09 cases succeed")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		return
	_expect_equal(first, second, "definition order cannot change deterministic T09 output")
	_expect_equal(int(first["intake_multiplier_scaled_by_target_id"]["target"]), 400, "same-category fixed-point modifiers combine deterministically")
	var events: Array = first["events"]
	_expect_equal(events.size(), 2, "both narrow sources emit one assignment each")
	if events.size() == 2:
		_expect_equal(String(events[0]["source_instance_id"]), "buffer-a", "source ordering is stable by instance_id")
		_expect_equal(int(events[1]["combined_target_intake_multiplier_scaled"]), 400, "second event exposes combined target modifier")

func _test_invalid_multi_target_capacity_fails_closed() -> void:
	var kernel: T09SymbioticBufferKernel = T09SymbioticBufferKernelScript.new()
	var definition: Dictionary = _definition("buffer", ["a", "b"], 2, 500)
	definition["max_targets"] = 2
	var result: Dictionary = kernel.resolve_tick(
		5,
		[
			_organism("buffer", ["0,0"], "CALM"),
			_organism("a", ["1,0"], "CALM"),
			_organism("b", ["0,1"], "CALM"),
		],
		[definition]
	)
	_expect_true(not bool(result.get("ok", false)), "multi-target T09 definition fails closed")
	_expect_equal(String(result.get("error", "")), "t09_must_be_one_target:buffer", "universal-protector shape is rejected explicitly")

func _organism(instance_id: String, cells: Array, primary_state: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"occupied_cells": cells.duplicate(true),
		"primary_state": primary_state,
		"body_stage": "MATURE",
	}

func _definition(instance_id: String, eligible_target_ids: Array, range_value: int, multiplier_scaled: int) -> Dictionary:
	return {
		"instance_id": instance_id,
		"eligible_target_ids": eligible_target_ids.duplicate(true),
		"range": range_value,
		"max_targets": 1,
		"intake_multiplier_scaled": multiplier_scaled,
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
