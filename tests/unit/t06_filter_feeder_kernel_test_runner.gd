extends SceneTree

const T06FilterFeederKernelScript := preload("res://src/sim/t06_filter_feeder_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_conservation_and_satiety_cap()
	_test_contested_resource_is_deterministic()
	_test_inactive_consumer_does_not_mutate_unrelated_state()
	_test_production_tick_order_and_carry_forward()
	_test_production_replay_is_deterministic()
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

func _test_production_tick_order_and_carry_forward() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_production_record(), 2, _production_defs())
	_expect_true(bool(result.get("ok", false)), "production T06 transit succeeds")
	if not bool(result.get("ok", false)):
		return
	var snapshots: Array = result["end_tick_snapshots"]
	_expect_equal(snapshots.size(), 2, "two production snapshots are emitted")
	if snapshots.size() != 2:
		return
	var tick1: Dictionary = snapshots[0]
	var tick2: Dictionary = snapshots[1]
	_expect_equal(int(tick1["phase_d_contamination_exposure_by_cell"]["0,0"]), 4, "tick 1 publishes full Phase-D exposure before T06")
	_expect_equal(int(tick1["contamination_by_cell"]["0,0"]), 2, "tick 1 Phase-F T06 commit reduces carried field")
	_expect_equal(int(tick2["phase_d_contamination_exposure_by_cell"]["0,0"]), 2, "tick 2 begins from prior post-F reduced field")
	_expect_equal(int(tick2["contamination_by_cell"]["0,0"]), 0, "tick 2 T06 consumes remaining finite contamination")
	var tick1_runtime: Dictionary = tick1["organism_runtime"][0]
	var tick2_runtime: Dictionary = tick2["organism_runtime"][0]
	_expect_equal(int(tick1_runtime["satiety"]), 2, "tick 1 satiety gains exactly consumed amount")
	_expect_equal(int(tick2_runtime["satiety"]), 4, "T06 satiety persists to tick 2")
	_expect_equal(int(tick1_runtime["contamination_load"]), 4, "same-tick organism intake samples pre-T06 Phase-D exposure")
	_expect_equal(int(tick2_runtime["contamination_load"]), 6, "tick 2 organism intake again samples before same-tick T06 reduction")
	var tick1_events: Array = tick1["t06_events"]
	_expect_equal(tick1_events.size(), 2, "T06 emits Phase-E consumption plus Phase-F satiety evidence")
	if tick1_events.size() == 2:
		_expect_equal(String(tick1_events[0]["phase"]), "E", "T06 consumption evidence is Phase E")
		_expect_equal(String(tick1_events[1]["phase"]), "F", "T06 satiety evidence is Phase F")
	_expect_equal(int(result["final_organism_runtime"][0]["satiety"]), 4, "final integrated runtime preserves T06 satiety")

func _test_production_replay_is_deterministic() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_production_record(), 2, _production_defs())
	var second: Dictionary = runner.simulate(_production_record(), 2, _production_defs())
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "both production T06 replays succeed")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		return
	_expect_equal(first["tick_checksums"], second["tick_checksums"], "production T06 checksums are deterministic")
	_expect_equal(first["end_tick_snapshots"], second["end_tick_snapshots"], "production T06 snapshots are deterministic")

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

func _production_record() -> Dictionary:
	return {
		"run_id": "t06-production-run",
		"rules_version": "rules-r1",
		"content_version": "t06-production-1",
		"canonical_committed_input": {
			"route_id": "route-t06-production",
			"seed": 606,
			"placements": [
				{"instance_id": "filter-feeder-a", "anchor": [0, 0], "orientation": 0},
			],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _production_defs() -> Dictionary:
	return {
		"route_profile": {
			"id": "route-t06-production",
			"tick_count": 2,
			"events": [
				{"tick": 1, "duration_ticks": 1, "hazard_id": "h03-t06", "authored_order": 0},
			],
		},
		"hold_definition": {
			"dimensions": [1, 1],
			"blocked_cells": [],
			"power_capacity": 0,
		},
		"hazards_by_id": {
			"h03-t06": {
				"id": "h03-t06",
				"family": "H03",
				"contamination_delta": 4,
				"target_cells": ["0,0"],
			},
		},
		"support_definitions_by_id": {},
		"contamination_rules": {
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"filter-feeder-a": {
				"stress_profile": {},
				"initial_state": "CALM",
				"initial_satiety": 0,
				"contamination_profile": {
					"intake_multiplier_scaled": 1000,
					"load_min": 0,
					"load_max": 20,
					"contaminated_enter": 8,
					"contaminated_exit": 4,
				},
			},
		},
		"t06_definitions": [
			{
				"instance_id": "filter-feeder-a",
				"capacity": 2,
				"benefit_per_unit": 1,
				"satiety_max": 10,
				"active_primary_states": ["CALM", "AGITATED", "PANICKED"],
				"active_body_stages": [],
				"sleep_gated": false,
			},
		],
	}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
