extends SceneTree

const S06MonitorBeaconKernelScript := preload("res://src/sim/s06_monitor_beacon_kernel.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")
const TransitWithoutMonitorRunnerScript := preload("res://src/sim/transit_contamination_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_bounded_fact_reveals_once_only_when_powered()
	_test_local_telemetry_reads_exact_snapshot_without_mutation()
	_test_one_information_contract_per_monitor_is_enforced()
	_test_production_brownout_delays_fact_and_replay_is_deterministic()
	if failures == 0:
		print("s06_monitor_beacon_kernel_test_runner: PASS")
		quit(0)
	else:
		push_error("s06_monitor_beacon_kernel_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_bounded_fact_reveals_once_only_when_powered() -> void:
	var kernel: S06MonitorBeaconKernel = S06MonitorBeaconKernelScript.new()
	var supports: Array = [{"instance_id": "monitor-a", "support_id": "S06", "anchor": [0, 0]}]
	var definitions: Dictionary = {"S06": {"id": "S06", "family": "S06", "powered": true, "power_draw": 1}}
	var revelations: Array = [{
		"revelation_id": "route-band",
		"support_instance_id": "monitor-a",
		"mode": "BOUNDED_FACT",
		"fact_id": "unknown_route_band",
		"value": "early_or_mid",
	}]
	var disabled: Dictionary = kernel.resolve_tick(1, supports, definitions, PackedStringArray(), revelations, {}, {})
	_expect_true(bool(disabled.get("ok", false)), "disabled monitor resolution succeeds")
	_expect_equal(disabled.get("events", []), [], "Brownout-disabled S06 reveals nothing on that tick")
	var disabled_state_value: Variant = disabled.get("revealed_fact_ids", {})
	var disabled_state: Dictionary = disabled_state_value if disabled_state_value is Dictionary else {}
	var powered: Dictionary = kernel.resolve_tick(2, supports, definitions, PackedStringArray(["monitor-a"]), revelations, {}, disabled_state)
	_expect_true(bool(powered.get("ok", false)), "powered monitor resolution succeeds")
	var powered_events_value: Variant = powered.get("events", [])
	var powered_events: Array = powered_events_value if powered_events_value is Array else []
	_expect_equal(powered_events.size(), 1, "powered S06 reveals its bounded fact once")
	if powered_events.size() == 1 and powered_events[0] is Dictionary:
		var event: Dictionary = powered_events[0]
		_expect_equal(String(event["fact_id"]), "unknown_route_band", "bounded fact identity is contract-authored")
		_expect_equal(event["value"], "early_or_mid", "bounded fact value passes through without solver inference")
	var powered_state_value: Variant = powered.get("revealed_fact_ids", {})
	var powered_state: Dictionary = powered_state_value if powered_state_value is Dictionary else {}
	var repeated: Dictionary = kernel.resolve_tick(3, supports, definitions, PackedStringArray(["monitor-a"]), revelations, {}, powered_state)
	_expect_true(bool(repeated.get("ok", false)), "repeat monitor resolution succeeds")
	_expect_equal(repeated.get("events", []), [], "same bounded fact is not emitted twice")

func _test_local_telemetry_reads_exact_snapshot_without_mutation() -> void:
	var kernel: S06MonitorBeaconKernel = S06MonitorBeaconKernelScript.new()
	var supports: Array = [{"instance_id": "monitor-a", "support_id": "S06", "anchor": [0, 0]}]
	var definitions: Dictionary = {"S06": {"id": "S06", "family": "S06", "powered": true, "power_draw": 1}}
	var revelations: Array = [{
		"revelation_id": "heat-probe",
		"support_instance_id": "monitor-a",
		"mode": "LOCAL_TELEMETRY",
		"channel": "heat",
		"cell_key": "0,0",
	}]
	var snapshot: Dictionary = {"heat_by_cell": {"0,0": 7, "1,0": 2}}
	var before: Dictionary = snapshot.duplicate(true)
	var result: Dictionary = kernel.resolve_tick(4, supports, definitions, PackedStringArray(["monitor-a"]), revelations, snapshot, {})
	_expect_true(bool(result.get("ok", false)), "local telemetry resolution succeeds")
	var events_value: Variant = result.get("events", [])
	var events: Array = events_value if events_value is Array else []
	_expect_equal(events.size(), 1, "powered S06 emits exact local telemetry")
	if events.size() == 1 and events[0] is Dictionary:
		var event: Dictionary = events[0]
		_expect_equal(int(event["value"]), 7, "local telemetry reports the exact published cell value")
		_expect_equal(String(event["cell_key"]), "0,0", "local telemetry remains single-cell/local")
	_expect_equal(snapshot, before, "S06 information sampling does not mutate authoritative environment state")

func _test_one_information_contract_per_monitor_is_enforced() -> void:
	var kernel: S06MonitorBeaconKernel = S06MonitorBeaconKernelScript.new()
	var supports: Array = [{"instance_id": "monitor-a", "support_id": "S06"}]
	var definitions: Dictionary = {"S06": {"id": "S06", "family": "S06", "powered": true, "power_draw": 1}}
	var result: Dictionary = kernel.resolve_tick(
		1,
		supports,
		definitions,
		PackedStringArray(["monitor-a"]),
		[
			{"revelation_id": "fact-a", "support_instance_id": "monitor-a", "mode": "BOUNDED_FACT", "fact_id": "a", "value": true},
			{"revelation_id": "fact-b", "support_instance_id": "monitor-a", "mode": "BOUNDED_FACT", "fact_id": "b", "value": false},
		],
		{},
		{}
	)
	_expect_true(not bool(result.get("ok", false)), "one S06 cannot become a multi-fact information engine")
	_expect_equal(String(result.get("error", "")), "s06_support_must_have_one_information_contract:monitor-a", "multiple information contracts fail closed")

func _test_production_brownout_delays_fact_and_replay_is_deterministic() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_record(), 2, _defs())
	var second: Dictionary = runner.simulate(_record(), 2, _defs())
	_expect_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "production S06 wrapper executes twice")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		return
	_expect_equal(first.get("tick_checksums", PackedStringArray()), second.get("tick_checksums", PackedStringArray()), "S06 information evidence is deterministic and checksum-visible")
	_expect_equal(first.get("s06_information_events", []), second.get("s06_information_events", []), "S06 information events replay identically")
	var events_value: Variant = first.get("s06_information_events", [])
	var events: Array = events_value if events_value is Array else []
	_expect_equal(events.size(), 1, "bounded fact is revealed exactly once in production")
	if events.size() == 1 and events[0] is Dictionary:
		var event: Dictionary = events[0]
		_expect_equal(int(event["tick"]), 2, "Phase-A Brownout prevents same-tick S06 evidence until the monitor is powered")
	var snapshots_value: Variant = first.get("end_tick_snapshots", [])
	var snapshots: Array = snapshots_value if snapshots_value is Array else []
	if snapshots.size() == 2 and snapshots[0] is Dictionary and snapshots[1] is Dictionary:
		var first_snapshot: Dictionary = snapshots[0]
		var second_snapshot: Dictionary = snapshots[1]
		_expect_equal(first_snapshot.get("s06_information_events", []), [], "disabled tick has no S06 information event")
		var second_events_value: Variant = second_snapshot.get("s06_information_events", [])
		var second_events: Array = second_events_value if second_events_value is Array else []
		_expect_equal(second_events.size(), 1, "first powered tick emits the bounded fact")
	var baseline_runner: TransitPowerIntegratedRunner = TransitWithoutMonitorRunnerScript.new()
	var baseline_defs: Dictionary = _defs()
	baseline_defs.erase("s06_revelations")
	var baseline: Dictionary = baseline_runner.simulate(_record(), 2, baseline_defs)
	_expect_true(bool(baseline.get("ok", false)), "mechanical baseline without S06 information wrapper executes")
	var baseline_snapshots_value: Variant = baseline.get("end_tick_snapshots", [])
	var baseline_snapshots: Array = baseline_snapshots_value if baseline_snapshots_value is Array else []
	if bool(baseline.get("ok", false)) and snapshots.size() == 2 and baseline_snapshots.size() == 2 and snapshots[1] is Dictionary and baseline_snapshots[1] is Dictionary:
		var monitor_snapshot: Dictionary = snapshots[1]
		var baseline_snapshot: Dictionary = baseline_snapshots[1]
		_expect_equal(monitor_snapshot.get("phase_a_power", {}), baseline_snapshot.get("phase_a_power", {}), "S06 wrapper does not change support power authority")
		_expect_equal(monitor_snapshot.get("heat_by_cell", {}), baseline_snapshot.get("heat_by_cell", {}), "S06 wrapper provides information only and does not mitigate the environment")

func _record() -> Dictionary:
	return {
		"run_id": "s06-production-run",
		"rules_version": "rules-r1",
		"content_version": "s06-1",
		"canonical_committed_input": {
			"route_id": "route-s06-test",
			"seed": 77,
			"placements": [{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [
				{"instance_id": "monitor-a", "support_id": "S06", "anchor": [0, 0]},
				{"instance_id": "monitor-b", "support_id": "S06", "anchor": [0, 0]},
			],
			"brownout_priority": ["monitor-b", "monitor-a"],
		},
	}

func _defs() -> Dictionary:
	return {
		"route_profile": {
			"id": "route-s06-test",
			"tick_count": 2,
			"events": [{"tick": 1, "duration_ticks": 1, "hazard_id": "h04-s06", "authored_order": 0}],
		},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 2},
		"hazards_by_id": {
			"h04-s06": {"id": "h04-s06", "family": "H04", "target_scope": "hold", "power_reduction": 1},
		},
		"support_definitions_by_id": {
			"S06": {"id": "S06", "family": "S06", "powered": true, "power_draw": 1},
		},
		"s06_revelations": [{
			"revelation_id": "bounded-route-fact",
			"support_instance_id": "monitor-a",
			"mode": "BOUNDED_FACT",
			"fact_id": "route_detail_band",
			"value": "second_half_clear",
		}],
	}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
