extends SceneTree

const ContaminationResponseKernelScript := preload("res://src/sim/contamination_response_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_phase_e_samples_max_occupied_cell_without_mutating_field()
	_test_phase_f_resistance_uses_fixed_point_floor_intake()
	_test_phase_g_contaminated_hysteresis_boundaries()
	_test_response_chain_is_deterministic()
	if failures == 0:
		print("contamination_response_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("contamination_response_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_phase_e_samples_max_occupied_cell_without_mutating_field() -> void:
	var kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var field: Dictionary = {"0,0": 3, "1,0": 7}
	var before: Dictionary = field.duplicate(true)
	var organisms: Array = [
		_runtime_organism("specimen-a", ["1,0", "0,0"], _profile(1000, 8, 4), 0, false),
	]
	var result: Dictionary = kernel.sample_phase_e(1, organisms, field)
	_expect_true(bool(result.get("ok", false)), "Phase E contamination exposure sampling succeeds")
	if not bool(result.get("ok", false)):
		return
	var observations: Array = result["observations"]
	_expect_equal(observations.size(), 1, "one organism produces one Phase-E observation")
	_expect_equal(int(observations[0]["contamination_exposure"]), 7, "multi-cell organism samples maximum occupied-cell contamination")
	var events: Array = result["events"]
	_expect_equal(events[0]["sampled_cells"], ["0,0", "1,0"], "sampled cells are causal-evidence stable-sorted")
	_expect_equal(field, before, "Phase E sampling does not mutate the authoritative environment field")

func _test_phase_f_resistance_uses_fixed_point_floor_intake() -> void:
	var kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var organisms: Array = [
		_runtime_organism("resistant", ["0,0"], _profile(500, 11, 5), 1, false),
		_runtime_organism("standard", ["0,0"], _profile(1000, 8, 4), 1, false),
		_runtime_organism("vulnerable", ["0,0"], _profile(1500, 7, 3), 1, false),
	]
	var sampled: Dictionary = kernel.sample_phase_e(2, organisms, {"0,0": 7})
	_expect_true(bool(sampled.get("ok", false)), "shared exposure sampling succeeds before resistance intake")
	if not bool(sampled.get("ok", false)):
		return
	var applied: Dictionary = kernel.apply_phase_f(2, organisms, sampled["observations"])
	_expect_true(bool(applied.get("ok", false)), "Phase F contamination intake succeeds")
	if not bool(applied.get("ok", false)):
		return
	var by_id: Dictionary = _runtime_by_id(applied["organisms"])
	_expect_equal(int(by_id["resistant"]["contamination_load"]), 4, "Resistant x0.5 floors 7 exposure to 3 intake before adding initial load")
	_expect_equal(int(by_id["standard"]["contamination_load"]), 8, "Standard x1.0 applies exact exposure as intake")
	_expect_equal(int(by_id["vulnerable"]["contamination_load"]), 11, "Vulnerable x1.5 floors scaled 10.5 intake to 10")
	var events: Array = applied["events"]
	_expect_equal(int(events[0]["contamination_intake"]), 3, "resistance intake event records floor-rounded fixed-point intake")
	_expect_equal(int(events[2]["contamination_intake"]), 10, "vulnerable intake event records floor-rounded fixed-point intake")

func _test_phase_g_contaminated_hysteresis_boundaries() -> void:
	var kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var standard: Dictionary = _profile(1000, 8, 4)
	var organisms: Array = [
		_runtime_organism("enter", ["0,0"], standard, 8, false),
		_runtime_organism("hold", ["0,0"], standard, 4, true),
		_runtime_organism("exit", ["0,0"], standard, 3, true),
	]
	var result: Dictionary = kernel.evaluate_phase_g(3, organisms)
	_expect_true(bool(result.get("ok", false)), "Phase G contamination hysteresis evaluation succeeds")
	if not bool(result.get("ok", false)):
		return
	var by_id: Dictionary = _runtime_by_id(result["organisms"])
	_expect_true(bool(by_id["enter"]["contaminated"]), "not-contaminated organism enters at the inclusive enter threshold")
	_expect_true(bool(by_id["hold"]["contaminated"]), "already-contaminated organism remains contaminated at the exit threshold")
	_expect_true(not bool(by_id["exit"]["contaminated"]), "already-contaminated organism exits only below the exit threshold")
	var events: Array = result["events"]
	_expect_equal(events.size(), 2, "only actual condition transitions emit threshold events")
	_expect_equal(String(events[0]["kind"]), "CONTAMINATED_ENTER", "stable instance order records enter transition first")
	_expect_equal(String(events[1]["kind"]), "CONTAMINATED_EXIT", "stable instance order records exit transition second")

func _test_response_chain_is_deterministic() -> void:
	var kernel: ContaminationResponseKernel = ContaminationResponseKernelScript.new()
	var organisms: Array = [
		_runtime_organism("specimen-a", ["0,0"], _profile(1000, 8, 4), 0, false),
	]
	var first_e: Dictionary = kernel.sample_phase_e(4, organisms, {"0,0": 8})
	var first_f: Dictionary = kernel.apply_phase_f(4, organisms, first_e.get("observations", []))
	var first_g: Dictionary = kernel.evaluate_phase_g(4, first_f.get("organisms", []))
	var second_e: Dictionary = kernel.sample_phase_e(4, organisms, {"0,0": 8})
	var second_f: Dictionary = kernel.apply_phase_f(4, organisms, second_e.get("observations", []))
	var second_g: Dictionary = kernel.evaluate_phase_g(4, second_f.get("organisms", []))
	_expect_true(bool(first_e.get("ok", false)) and bool(first_f.get("ok", false)) and bool(first_g.get("ok", false)), "first E/F/G contamination chain succeeds")
	_expect_true(bool(second_e.get("ok", false)) and bool(second_f.get("ok", false)) and bool(second_g.get("ok", false)), "replayed E/F/G contamination chain succeeds")
	if not bool(first_g.get("ok", false)) or not bool(second_g.get("ok", false)):
		return
	_expect_equal(first_e, second_e, "Phase-E observations and causal evidence replay deterministically")
	_expect_equal(first_f, second_f, "Phase-F intake and causal evidence replay deterministically")
	_expect_equal(first_g, second_g, "Phase-G threshold state and causal evidence replay deterministically")
	var intake_events: Array = first_f["events"]
	var threshold_events: Array = first_g["events"]
	_expect_equal(intake_events[0]["parent_event_ids"], PackedStringArray([String(first_e["events"][0]["event_id"])]), "Phase-F intake causally parents to Phase-E sampling")
	_expect_equal(threshold_events[0]["parent_event_ids"], PackedStringArray([String(intake_events[0]["event_id"])]), "Phase-G transition causally parents to Phase-F intake")

func _profile(multiplier_scaled: int, enter_threshold: int, exit_threshold: int) -> Dictionary:
	return {
		"intake_multiplier_scaled": multiplier_scaled,
		"load_min": 0,
		"load_max": 20,
		"contaminated_enter": enter_threshold,
		"contaminated_exit": exit_threshold,
	}

func _runtime_organism(
		instance_id: String,
		occupied_cells: Array,
		profile: Dictionary,
		load: int,
		contaminated: bool
) -> Dictionary:
	return {
		"instance_id": instance_id,
		"occupied_cells": occupied_cells.duplicate(true),
		"contamination_profile": profile.duplicate(true),
		"contamination_load": load,
		"contaminated": contaminated,
	}

func _runtime_by_id(organisms: Array) -> Dictionary:
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