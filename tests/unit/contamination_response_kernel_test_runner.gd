extends SceneTree

const ContaminationResponseKernelScript := preload("res://src/sim/contamination_response_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_phase_e_samples_max_without_mutating_field()
	_test_phase_f_fixed_point_resistance()
	_test_phase_g_hysteresis()
	_test_kernel_chain_deterministic()
	_test_production_response_persists_and_preserves_environment()
	_test_production_exit_and_replay()
	_test_production_t09_modifies_intake_not_environment_and_replays()
	if failures == 0:
		print("contamination_response_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("contamination_response_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_phase_e_samples_max_without_mutating_field() -> void:
	var kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var field: Dictionary = {"0,0": 3, "1,0": 7}
	var before: Dictionary = field.duplicate(true)
	var organisms: Array = [_runtime("specimen-a", ["1,0", "0,0"], _profile(1000, 8, 4), 0, false)]
	var result: Dictionary = kernel.sample_phase_e(1, organisms, field)
	_expect_true(bool(result.get("ok", false)), "Phase E sampling succeeds")
	if not bool(result.get("ok", false)):
		return
	var observations: Array = result["observations"]
	var events: Array = result["events"]
	_expect_equal(int(observations[0]["contamination_exposure"]), 7, "Phase E samples max occupied-cell contamination")
	_expect_equal(events[0]["sampled_cells"], ["0,0", "1,0"], "Phase E sampled cells are stable-sorted")
	_expect_equal(field, before, "Phase E does not mutate environment authority")

func _test_phase_f_fixed_point_resistance() -> void:
	var kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var organisms: Array = [
		_runtime("resistant", ["0,0"], _profile(500, 11, 5), 1, false),
		_runtime("standard", ["0,0"], _profile(1000, 8, 4), 1, false),
		_runtime("vulnerable", ["0,0"], _profile(1500, 7, 3), 1, false),
	]
	var sampled: Dictionary = kernel.sample_phase_e(2, organisms, {"0,0": 7})
	var applied: Dictionary = kernel.apply_phase_f(2, organisms, sampled.get("observations", []))
	_expect_true(bool(applied.get("ok", false)), "Phase F intake succeeds")
	if not bool(applied.get("ok", false)):
		return
	var by_id: Dictionary = _by_id(applied["organisms"])
	_expect_equal(int(by_id["resistant"]["contamination_load"]), 4, "Resistant x0.5 floors intake")
	_expect_equal(int(by_id["standard"]["contamination_load"]), 8, "Standard x1.0 intake")
	_expect_equal(int(by_id["vulnerable"]["contamination_load"]), 11, "Vulnerable x1.5 floors scaled intake")

func _test_phase_g_hysteresis() -> void:
	var kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var standard: Dictionary = _profile(1000, 8, 4)
	var organisms: Array = [
		_runtime("enter", ["0,0"], standard, 8, false),
		_runtime("hold", ["0,0"], standard, 4, true),
		_runtime("exit", ["0,0"], standard, 3, true),
	]
	var result: Dictionary = kernel.evaluate_phase_g(3, organisms)
	_expect_true(bool(result.get("ok", false)), "Phase G hysteresis succeeds")
	if not bool(result.get("ok", false)):
		return
	var by_id: Dictionary = _by_id(result["organisms"])
	_expect_true(bool(by_id["enter"]["contaminated"]), "enter threshold is inclusive")
	_expect_true(bool(by_id["hold"]["contaminated"]), "exit threshold holds contaminated state")
	_expect_true(not bool(by_id["exit"]["contaminated"]), "exit occurs only below exit threshold")

func _test_kernel_chain_deterministic() -> void:
	var kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var organisms: Array = [_runtime("specimen-a", ["0,0"], _profile(1000, 8, 4), 0, false)]
	var first_e: Dictionary = kernel.sample_phase_e(4, organisms, {"0,0": 8})
	var first_f: Dictionary = kernel.apply_phase_f(4, organisms, first_e.get("observations", []))
	var first_g: Dictionary = kernel.evaluate_phase_g(4, first_f.get("organisms", []))
	var second_e: Dictionary = kernel.sample_phase_e(4, organisms, {"0,0": 8})
	var second_f: Dictionary = kernel.apply_phase_f(4, organisms, second_e.get("observations", []))
	var second_g: Dictionary = kernel.evaluate_phase_g(4, second_f.get("organisms", []))
	_expect_equal(first_e, second_e, "Phase E replays deterministically")
	_expect_equal(first_f, second_f, "Phase F replays deterministically")
	_expect_equal(first_g, second_g, "Phase G replays deterministically")
	if bool(first_g.get("ok", false)):
		var intake_events: Array = first_f["events"]
		var threshold_events: Array = first_g["events"]
		_expect_equal(intake_events[0]["parent_event_ids"], PackedStringArray([String(first_e["events"][0]["event_id"])]), "F parents to E")
		_expect_equal(threshold_events[0]["parent_event_ids"], PackedStringArray([String(intake_events[0]["event_id"])]), "G parents to F")

func _test_production_response_persists_and_preserves_environment() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var standard: Dictionary = runner.simulate(_record("specimen-a"), 2, _defs(_profile(1000, 8, 4), 4, 2, 0, false))
	var resistant: Dictionary = runner.simulate(_record("specimen-a"), 2, _defs(_profile(500, 11, 5), 4, 2, 0, false))
	_expect_true(bool(standard.get("ok", false)) and bool(resistant.get("ok", false)), "production contamination E/F/G runs for Standard and Resistant")
	if not bool(standard.get("ok", false)) or not bool(resistant.get("ok", false)):
		return
	var standard_snapshots: Array = standard["end_tick_snapshots"]
	var resistant_snapshots: Array = resistant["end_tick_snapshots"]
	_expect_equal(standard_snapshots[0]["contamination_by_cell"], resistant_snapshots[0]["contamination_by_cell"], "resistance does not change tick-1 environment field")
	_expect_equal(standard_snapshots[1]["contamination_by_cell"], resistant_snapshots[1]["contamination_by_cell"], "resistance does not change tick-2 environment field")
	var standard_tick1: Dictionary = _by_id(standard_snapshots[0]["organism_runtime"])["specimen-a"]
	var standard_tick2: Dictionary = _by_id(standard_snapshots[1]["organism_runtime"])["specimen-a"]
	var resistant_tick1: Dictionary = _by_id(resistant_snapshots[0]["organism_runtime"])["specimen-a"]
	var resistant_tick2: Dictionary = _by_id(resistant_snapshots[1]["organism_runtime"])["specimen-a"]
	_expect_equal(int(standard_tick1["contamination_load"]), 4, "Standard tick-1 intake uses published field")
	_expect_equal(int(standard_tick2["contamination_load"]), 12, "Standard contamination load persists across ticks")
	_expect_true(bool(standard_tick2["contaminated"]), "Standard enters CONTAMINATED at accumulated load")
	_expect_equal(int(resistant_tick1["contamination_load"]), 2, "Resistant tick-1 intake is halved")
	_expect_equal(int(resistant_tick2["contamination_load"]), 6, "Resistant persisted load remains below enter threshold")
	_expect_true(not bool(resistant_tick2["contaminated"]), "Resistant stays clear under same environment authority")
	var tick2_events: Array = standard_snapshots[1]["contamination_response_events"]
	_expect_equal(String(tick2_events[0]["phase"]), "E", "production event chain starts at Phase E")
	_expect_equal(String(tick2_events[1]["phase"]), "F", "production event chain continues at Phase F")
	_expect_equal(String(tick2_events[2]["phase"]), "G", "production threshold event is Phase G")
	_expect_equal(tick2_events[1]["parent_event_ids"], PackedStringArray([String(tick2_events[0]["event_id"])]), "production F event parents to E")
	_expect_equal(tick2_events[2]["parent_event_ids"], PackedStringArray([String(tick2_events[1]["event_id"])]), "production G event parents to F")

func _test_production_exit_and_replay() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _defs(_profile(1000, 8, 4), 0, 1, 3, true)
	var first: Dictionary = runner.simulate(_record("specimen-a"), 1, defs)
	var second: Dictionary = runner.simulate(_record("specimen-a"), 1, defs)
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "production contamination replay succeeds")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		return
	var runtime: Dictionary = _by_id(first["end_tick_snapshots"][0]["organism_runtime"])["specimen-a"]
	_expect_equal(int(runtime["contamination_load"]), 3, "zero exposure preserves initial contamination load")
	_expect_true(not bool(runtime["contaminated"]), "initial contaminated state exits below authored exit threshold")
	_expect_equal(first["tick_checksums"], second["tick_checksums"], "integrated contamination checksum replays deterministically")
	_expect_equal(first["contamination_response_events"], second["contamination_response_events"], "integrated causal events replay deterministically")
	_expect_equal(first["end_tick_snapshots"], second["end_tick_snapshots"], "integrated snapshots replay deterministically")

func _test_production_t09_modifies_intake_not_environment_and_replays() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var defs: Dictionary = _t09_production_defs()
	var first: Dictionary = runner.simulate(_t09_record(), 1, defs)
	var second: Dictionary = runner.simulate(_t09_record(), 1, defs)
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "production T09 contamination integration succeeds")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		return
	var snapshot: Dictionary = first["end_tick_snapshots"][0]
	var field: Dictionary = snapshot["contamination_by_cell"]
	_expect_equal(int(field["1,0"]), 8, "T09 never mutates published contamination field")
	var modifiers: Dictionary = snapshot["t09_intake_multiplier_scaled_by_target_id"]
	_expect_equal(modifiers.size(), 1, "one T09 source protects exactly one production target")
	_expect_equal(int(modifiers["target"]), 500, "production target receives authored T09 x0.5 modifier")
	_expect_true(not modifiers.has("other"), "compatible alternative outside range is not protected")
	var runtime: Dictionary = _by_id(snapshot["organism_runtime"])
	_expect_equal(int(runtime["target"]["contamination_load"]), 2, "Resistant x0.5 combined with T09 x0.5 yields x0.25 intake before one final floor")
	_expect_equal(int(runtime["other"]["contamination_load"]), 0, "unexposed alternative remains unchanged")
	var t09_events: Array = snapshot["t09_buffer_events"]
	_expect_equal(t09_events.size(), 1, "production T09 emits one Phase-E assignment event")
	if t09_events.size() == 1:
		_expect_equal(String(t09_events[0]["source_instance_id"]), "buffer", "T09 evidence names source")
		_expect_equal(String(t09_events[0]["target_instance_id"]), "target", "T09 evidence names selected target")
	var f_event: Dictionary = _event_by_phase_instance(snapshot["contamination_response_events"], "F", "target")
	_expect_true(not f_event.is_empty(), "target Phase-F contamination event exists")
	if not f_event.is_empty():
		_expect_equal(int(f_event["base_intake_multiplier_scaled"]), 500, "Phase-F evidence preserves base resistance multiplier")
		_expect_equal(int(f_event["t09_intake_multiplier_scaled"]), 500, "Phase-F evidence records T09 target multiplier")
		_expect_equal(int(f_event["combined_intake_multiplier_scaled"]), 250, "same-category multipliers combine before intake floor")
		var parents: PackedStringArray = f_event["parent_event_ids"]
		_expect_true(parents.has("1:E:contamination:target"), "Phase-F target event retains contamination exposure parent")
		_expect_true(parents.has("t0001:E:T09:buffer>target"), "Phase-F target event retains T09 assignment parent")
	_expect_equal(first["tick_checksums"], second["tick_checksums"], "T09 production checksum replays deterministically")
	_expect_equal(first["t09_buffer_events"], second["t09_buffer_events"], "T09 causal evidence replays deterministically")
	_expect_equal(first["end_tick_snapshots"], second["end_tick_snapshots"], "T09 production snapshots replay deterministically")

func _record(instance_id: String) -> Dictionary:
	return {
		"run_id": "contamination-response-production-run",
		"rules_version": "rules-r1",
		"content_version": "contamination-response-production-1",
		"canonical_committed_input": {
			"route_id": "route-contamination-response",
			"seed": 53,
			"placements": [{"instance_id": instance_id, "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _defs(profile: Dictionary, hazard_delta: int, ticks: int, initial_load: int, initial_contaminated: bool) -> Dictionary:
	return {
		"route_profile": {
			"id": "route-contamination-response",
			"tick_count": ticks,
			"events": [{"tick": 1, "duration_ticks": ticks, "hazard_id": "h03-response", "authored_order": 0}],
		},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {
			"h03-response": {"id": "h03-response", "family": "H03", "contamination_delta": hazard_delta, "target_cells": ["0,0"]},
		},
		"support_definitions_by_id": {},
		"contamination_rules": {
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"specimen-a": {
				"stress_profile": _stress_profile(),
				"contamination_profile": profile.duplicate(true),
				"initial_contamination_load": initial_load,
				"initial_contaminated": initial_contaminated,
			},
		},
	}

func _t09_record() -> Dictionary:
	return {
		"run_id": "t09-production-run",
		"rules_version": "rules-r1",
		"content_version": "t09-production-1",
		"canonical_committed_input": {
			"route_id": "route-t09-production",
			"seed": 67,
			"placements": [
				{"instance_id": "buffer", "anchor": [0, 0], "orientation": 0},
				{"instance_id": "target", "anchor": [1, 0], "orientation": 0},
				{"instance_id": "other", "anchor": [2, 0], "orientation": 0},
			],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _t09_production_defs() -> Dictionary:
	return {
		"route_profile": {
			"id": "route-t09-production",
			"tick_count": 1,
			"events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "h03-t09", "authored_order": 0}],
		},
		"hold_definition": {"dimensions": [3, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {
			"h03-t09": {"id": "h03-t09", "family": "H03", "contamination_delta": 8, "target_cells": ["1,0"]},
		},
		"support_definitions_by_id": {},
		"contamination_rules": {
			"contamination_min": 0,
			"contamination_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"buffer": {
				"stress_profile": _stress_profile(),
				"contamination_profile": _profile(1000, 8, 4),
			},
			"target": {
				"stress_profile": _stress_profile(),
				"contamination_profile": _profile(500, 11, 5),
			},
			"other": {
				"stress_profile": _stress_profile(),
				"contamination_profile": _profile(1000, 8, 4),
			},
		},
		"t09_definitions": [
			{
				"instance_id": "buffer",
				"eligible_target_ids": ["target", "other"],
				"range": 1,
				"max_targets": 1,
				"intake_multiplier_scaled": 500,
				"active_primary_states": ["CALM", "AGITATED", "PANICKED"],
				"active_body_stages": [],
				"sleep_gated": false,
			},
		],
	}

func _stress_profile() -> Dictionary:
	return {
		"heat_safe_max": 0,
		"stress_per_heat_unit": 0,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 6,
		"agitated_exit": 3,
		"panic_enter": 11,
		"panic_exit": 7,
	}

func _profile(multiplier_scaled: int, enter_threshold: int, exit_threshold: int) -> Dictionary:
	return {
		"intake_multiplier_scaled": multiplier_scaled,
		"load_min": 0,
		"load_max": 20,
		"contaminated_enter": enter_threshold,
		"contaminated_exit": exit_threshold,
	}

func _runtime(instance_id: String, occupied_cells: Array, profile: Dictionary, load: int, contaminated: bool) -> Dictionary:
	return {
		"instance_id": instance_id,
		"occupied_cells": occupied_cells.duplicate(true),
		"contamination_profile": profile.duplicate(true),
		"contamination_load": load,
		"contaminated": contaminated,
	}

func _event_by_phase_instance(events: Array, phase: String, instance_id: String) -> Dictionary:
	for raw_event: Variant in events:
		if raw_event is Dictionary:
			var event: Dictionary = raw_event
			if String(event.get("phase", "")) == phase and String(event.get("instance_id", "")) == instance_id:
				return event
	return {}

func _by_id(organisms: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_organism: Variant in organisms:
		if raw_organism is Dictionary:
			var organism: Dictionary = raw_organism
			result[String(organism.get("instance_id", ""))] = organism
	return result

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])