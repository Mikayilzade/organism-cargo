extends SceneTree

const S04NestPadKernelScript := preload("res://src/sim/s04_nest_pad_kernel.gd")
const SleepWakeKernelScript := preload("res://src/sim/sleep_wake_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_authored_timing_and_capacity_one()
	_test_non_sleepable_target_is_rejected()
	_test_invalid_capacity_is_rejected()
	_test_h02_same_tick_wake_wins_after_s04_sleep_entry()
	_test_replay_and_checksum_sensitivity()
	_test_production_s04_precedes_h02_wake_and_is_checksum_visible()
	if failures == 0:
		print("s04_nest_pad_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("s04_nest_pad_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_authored_timing_and_capacity_one() -> void:
	var kernel: S04NestPadKernel = S04NestPadKernelScript.new()
	var schedule: Array = [{"tick": 2, "authored_order": 0, "support_instance_id": "nest-a", "target_instance_id": "cargo-a", "transition": "ENTER_SLEEP"}]
	var tick_one: Dictionary = kernel.resolve_phase_b(1, _organisms(), _supports(), _support_defs(1), schedule)
	var tick_two: Dictionary = kernel.resolve_phase_b(2, _organisms(), _supports(), _support_defs(1), schedule)
	_expect_true(bool(tick_one.get("ok", false)), "S04 accepts an explicit future authored transition")
	_expect_equal(String(tick_one["organisms"][0]["primary_state"]), "CALM", "S04 never sleeps a target before the authored Phase-B tick")
	_expect_equal(tick_one["events"], [], "no early S04 event is invented")
	_expect_true(bool(tick_two.get("ok", false)), "capacity-1 S04 transition resolves")
	if not bool(tick_two.get("ok", false)):
		return
	_expect_equal(String(tick_two["organisms"][0]["primary_state"]), "ASLEEP", "authored S04 entry changes only primary state at Phase B")
	_expect_equal(String(tick_two["events"][0]["kind"]), "S04_SLEEP_ENTER_APPLIED", "sleep entry is explicit S04 authority")
	_expect_equal(String(tick_two["events"][0]["phase"]), "B", "S04 sleep entry uses frozen Phase-B boundary")

func _test_non_sleepable_target_is_rejected() -> void:
	var kernel: S04NestPadKernel = S04NestPadKernelScript.new()
	var organisms: Array = [{"instance_id": "cargo-a", "primary_state": "CALM", "can_sleep": false}]
	var schedule: Array = [{"tick": 1, "support_instance_id": "nest-a", "target_instance_id": "cargo-a", "transition": "ENTER_SLEEP"}]
	var result: Dictionary = kernel.resolve_phase_b(1, organisms, _supports(), _support_defs(1), schedule)
	_expect_true(not bool(result.get("ok", false)), "Nest Pad does not invent universal sleep eligibility")
	_expect_equal(String(result.get("error", "")), "s04_target_cannot_sleep:cargo-a", "non-sleepable failure is exact")

func _test_invalid_capacity_is_rejected() -> void:
	var kernel: S04NestPadKernel = S04NestPadKernelScript.new()
	var schedule: Array = [{"tick": 1, "support_instance_id": "nest-a", "target_instance_id": "cargo-a", "transition": "ENTER_SLEEP"}]
	var result: Dictionary = kernel.resolve_phase_b(1, _organisms(), _supports(), _support_defs(2), schedule)
	_expect_true(not bool(result.get("ok", false)), "S04 refuses a definition that violates frozen capacity 1")
	_expect_equal(String(result.get("error", "")), "invalid_s04_capacity:S04", "capacity failure identifies S04 definition")

func _test_h02_same_tick_wake_wins_after_s04_sleep_entry() -> void:
	var s04: S04NestPadKernel = S04NestPadKernelScript.new()
	var wake: SleepWakeKernel = SleepWakeKernelScript.new()
	var schedule: Array = [{"tick": 3, "support_instance_id": "nest-a", "target_instance_id": "cargo-a", "transition": "ENTER_SLEEP"}]
	var slept: Dictionary = s04.resolve_phase_b(3, _organisms(), _supports(), _support_defs(1), schedule)
	_expect_true(bool(slept.get("ok", false)), "S04 same-tick sleep setup resolves")
	if not bool(slept.get("ok", false)):
		return
	var woke: Dictionary = wake.resolve_phase_b(3, slept["organisms"], PackedStringArray(["vibration"]), {"vibration": {"family": "H02", "wake_request": true, "wake_target_instance_ids": ["cargo-a"]}})
	_expect_true(bool(woke.get("ok", false)), "existing explicit H02 wake semantics remain compatible with S04")
	if not bool(woke.get("ok", false)):
		return
	_expect_equal(String(woke["organisms"][0]["primary_state"]), "CALM", "explicit H02 wake can undo same-tick authored S04 sleep when composed after S04")

func _test_replay_and_checksum_sensitivity() -> void:
	var kernel: S04NestPadKernel = S04NestPadKernelScript.new()
	var sleep_schedule: Array = [{"tick": 2, "support_instance_id": "nest-a", "target_instance_id": "cargo-a", "transition": "ENTER_SLEEP"}]
	var wake_schedule: Array = [{"tick": 2, "support_instance_id": "nest-a", "target_instance_id": "cargo-a", "transition": "RECOVER_WAKE"}]
	var first: Dictionary = kernel.resolve_phase_b(2, _organisms(), _supports(), _support_defs(1), sleep_schedule)
	var replay: Dictionary = kernel.resolve_phase_b(2, _organisms(), _supports(), _support_defs(1), sleep_schedule)
	var initially_asleep: Array = [{"instance_id": "cargo-a", "primary_state": "ASLEEP", "can_sleep": true}]
	var recovery: Dictionary = kernel.resolve_phase_b(2, initially_asleep, _supports(), _support_defs(1), wake_schedule)
	_expect_equal(first, replay, "S04 Phase-B replay is deterministic")
	_expect_true(bool(recovery.get("ok", false)), "authored S04 recovery/wake transition resolves")
	if not bool(first.get("ok", false)) or not bool(recovery.get("ok", false)):
		return
	_expect_equal(String(recovery["organisms"][0]["primary_state"]), "CALM", "S04 recovery exits ASLEEP at the authored Phase-B boundary")
	_expect_true(String(first["checksum_material"]) != String(recovery["checksum_material"]), "sleep-entry versus recovery authority is checksum-sensitive")

func _test_production_s04_precedes_h02_wake_and_is_checksum_visible() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var with_sleep: Dictionary = runner.simulate(_production_record(), 1, _production_defs(true))
	var replay: Dictionary = runner.simulate(_production_record(), 1, _production_defs(true))
	var without_sleep: Dictionary = runner.simulate(_production_record(), 1, _production_defs(false))
	_expect_true(bool(with_sleep.get("ok", false)), "production runner accepts committed S04 through its Phase-B wrapper")
	_expect_equal(with_sleep, replay, "production S04/H02 replay is deterministic")
	_expect_true(bool(without_sleep.get("ok", false)), "production comparison without authored sleep transition succeeds")
	if not bool(with_sleep.get("ok", false)) or not bool(without_sleep.get("ok", false)):
		return
	var snapshot: Dictionary = with_sleep["end_tick_snapshots"][0]
	_expect_equal(String(snapshot["organism_runtime"][0]["primary_state"]), "CALM", "same-tick H02 wake runs after S04 sleep entry")
	var s04_events: Array = snapshot["s04_transition_events"]
	var wake_events: Array = snapshot["sleep_wake_events"]
	var response_events: Array = snapshot["stress_field_response_events"]
	_expect_equal(s04_events.size(), 1, "production snapshot retains S04 transition evidence")
	_expect_equal(wake_events.size(), 1, "same-tick explicit H02 wake observes the S04 sleeper")
	_expect_equal(String(response_events[0]["kind"]), "S04_SLEEP_ENTER_APPLIED", "S04 is first at the composed Phase-B boundary")
	_expect_equal(String(response_events[1]["kind"]), "H02_WAKE_REQUEST_APPLIED", "H02 wake follows S04 in the same Phase-B boundary")
	_expect_true(String(with_sleep["tick_checksums"][0]) != String(without_sleep["tick_checksums"][0]), "S04 transition evidence is production-checksum visible even when final state matches")

func _production_record() -> Dictionary:
	return {
		"run_id": "s04-production-run",
		"rules_version": "rules-r1",
		"content_version": "s04-production-1",
		"canonical_committed_input": {
			"route_id": "route-s04",
			"seed": 41,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [{"instance_id": "nest-a", "support_id": "S04", "linked_target_instance_id": "cargo-a"}],
			"brownout_priority": [],
		},
	}

func _production_defs(include_sleep_transition: bool) -> Dictionary:
	var schedule: Array = []
	if include_sleep_transition:
		schedule.append({"tick": 1, "authored_order": 0, "support_instance_id": "nest-a", "target_instance_id": "cargo-a", "transition": "ENTER_SLEEP"})
	return {
		"route_profile": {
			"id": "route-s04",
			"tick_count": 1,
			"events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "vibration", "authored_order": 0}],
		},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": {
			"vibration": {
				"family": "H02",
				"stress_field_delta": 1,
				"target_cells": ["0,0"],
				"wake_request": true,
				"wake_target_instance_ids": ["cargo-a"],
			},
		},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {}},
		"organism_definitions": {
			"cargo-a": {
				"initial_stress": 0,
				"initial_state": "CALM",
				"can_sleep": true,
				"stress_profile": _stress_profile(),
			},
		},
		"support_definitions_by_id": {"S04": {"family": "S04", "capacity": 1, "powered": false}},
		"s04_transition_schedule": schedule,
	}

func _stress_profile() -> Dictionary:
	return {
		"heat_safe_max": 2,
		"stress_per_heat_unit": 1,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 5,
		"agitated_exit": 3,
		"panic_enter": 10,
		"panic_exit": 7,
	}

func _organisms() -> Array:
	return [{"instance_id": "cargo-a", "primary_state": "CALM", "can_sleep": true}]

func _supports() -> Array:
	return [{"instance_id": "nest-a", "support_id": "S04", "linked_target_instance_id": "cargo-a"}]

func _support_defs(capacity: int) -> Dictionary:
	return {"S04": {"family": "S04", "capacity": capacity}}

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)
