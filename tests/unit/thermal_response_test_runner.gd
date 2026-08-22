extends SceneTree

const ThermalResponseKernelScript := preload("res://src/sim/thermal_response_kernel.gd")

var failures: int = 0

func _init() -> void:
	_test_authored_transfer_vent_and_clamp()
	_test_heat_response_changes_stress_and_state()
	_test_hysteresis_recovery()
	_test_asleep_heat_response_preserves_state_and_stress()
	_test_non_orthogonal_transfer_rejected()
	if failures == 0:
		print("thermal_response_test_runner: PASS")
		quit(0)
	else:
		push_error("thermal_response_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_authored_transfer_vent_and_clamp() -> void:
	var kernel: ThermalResponseKernel = ThermalResponseKernelScript.new()
	var result: Dictionary = kernel.propagate_heat(
		{"0,0": 0, "1,0": 8},
		PackedStringArray(["0,0", "1,0"]),
		{
			"heat_min": 0,
			"heat_max": 20,
			"transfer_edges": [{"from": "1,0", "to": "0,0", "amount": 2}],
			"vent_by_cell": {"0,0": 1, "1,0": 1},
		}
	)
	_expect_true(bool(result["ok"]), "authored orthogonal heat transfer succeeds")
	var heat: Dictionary = result["heat_by_cell"]
	_expect_equal(int(heat["0,0"]), 1, "Phase D applies transfer then authored vent at first cell")
	_expect_equal(int(heat["1,0"]), 5, "Phase D conserves authored transfer then vents source cell")

func _test_heat_response_changes_stress_and_state() -> void:
	var kernel: ThermalResponseKernel = ThermalResponseKernelScript.new()
	var result: Dictionary = kernel.apply_heat_response([_organism("specimen-a", 1, "CALM")], {"0,0": 1, "1,0": 5})
	_expect_true(bool(result["ok"]), "heat response applies to authored organism runtime")
	var specimen: Dictionary = result["organisms"][0]
	_expect_equal(int(specimen["heat_exposure"]), 5, "Phase E samples occupied-cell heat exposure")
	_expect_equal(int(specimen["stress_delta"]), 6, "authored excess-heat conversion produces deterministic stress delta")
	_expect_equal(int(specimen["stress"]), 7, "Phase F applies and clamps internal stress")
	_expect_equal(String(specimen["primary_state"]), "AGITATED", "Phase G enters AGITATED at authored threshold")

func _test_hysteresis_recovery() -> void:
	var kernel: ThermalResponseKernel = ThermalResponseKernelScript.new()
	var retained: Dictionary = kernel.apply_heat_response([_organism("specimen-a", 4, "AGITATED")], {"0,0": 0, "1,0": 0})
	_expect_equal(String(retained["organisms"][0]["primary_state"]), "AGITATED", "AGITATED persists above lower exit threshold")
	var recovered: Dictionary = kernel.apply_heat_response([_organism("specimen-a", 2, "AGITATED")], {"0,0": 0, "1,0": 0})
	_expect_equal(String(recovered["organisms"][0]["primary_state"]), "CALM", "AGITATED exits only below authored lower threshold")

func _test_asleep_heat_response_preserves_state_and_stress() -> void:
	var kernel: ThermalResponseKernel = ThermalResponseKernelScript.new()
	var result: Dictionary = kernel.apply_heat_response([_organism("sleeper", 1, "ASLEEP")], {"0,0": 1, "1,0": 5})
	_expect_true(bool(result.get("ok", false)), "ASLEEP runtime remains valid through thermal E/F/G")
	if not bool(result.get("ok", false)):
		return
	var sleeper: Dictionary = result["organisms"][0]
	_expect_equal(int(sleeper["heat_exposure"]), 5, "sleep does not suppress ungated heat exposure")
	_expect_equal(int(sleeper["stress_delta"]), 6, "sleep does not suppress ungated thermal stress intake")
	_expect_equal(int(sleeper["stress"]), 7, "ASLEEP organism still accumulates internal stress")
	_expect_equal(String(sleeper["primary_state"]), "ASLEEP", "thermal threshold alone never wakes an organism")

func _test_non_orthogonal_transfer_rejected() -> void:
	var kernel: ThermalResponseKernel = ThermalResponseKernelScript.new()
	var result: Dictionary = kernel.propagate_heat(
		{"0,0": 4, "1,1": 0},
		PackedStringArray(["0,0", "1,1"]),
		{
			"heat_min": 0,
			"heat_max": 20,
			"transfer_edges": [{"from": "0,0", "to": "1,1", "amount": 1}],
			"vent_by_cell": {},
		}
	)
	_expect_true(not bool(result["ok"]), "diagonal heat transfer is rejected")
	_expect_equal(String(result["error"]), "non_orthogonal_heat_transfer:0,0>1,1", "rejection names the illegal transfer")

func _organism(instance_id: String, stress: int, primary_state: String) -> Dictionary:
	return {
		"instance_id": instance_id,
		"occupied_cells": ["1,0"],
		"stress": stress,
		"primary_state": primary_state,
		"stress_profile": {
			"heat_safe_max": 2,
			"stress_per_heat_unit": 2,
			"stress_min": 0,
			"stress_max": 20,
			"agitated_enter": 5,
			"agitated_exit": 3,
			"panic_enter": 10,
			"panic_exit": 7,
		},
	}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
