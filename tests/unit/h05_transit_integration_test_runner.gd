extends SceneTree

const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_heat_phase_d_h05_changes_exposure_and_checksum()
	_test_contamination_phase_d_h05_changes_exposure_and_evidence()
	_test_stress_phase_d_h05_changes_field_and_evidence()
	_test_inactive_future_h05_is_byte_equivalent()
	_test_replay_is_deterministic()
	if failures == 0:
		print("h05_transit_integration_test_runner: PASS")
		quit(0)
	else:
		push_error("h05_transit_integration_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_heat_phase_d_h05_changes_exposure_and_checksum() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var with_h05: Dictionary = runner.simulate(_record("route-heat"), 1, _heat_defs(true))
	var baseline: Dictionary = runner.simulate(_record("route-heat"), 1, _heat_defs(false))
	_expect_true(bool(with_h05.get("ok", false)), "production heat H05 route resolves")
	_expect_true(bool(baseline.get("ok", false)), "production heat baseline resolves")
	if not bool(with_h05.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var h05_snapshot: Dictionary = with_h05["end_tick_snapshots"][0]
	var base_snapshot: Dictionary = baseline["end_tick_snapshots"][0]
	_expect_equal(int(base_snapshot["heat_by_cell"]["0,0"]), 5, "baseline H01 heat uses authored base vent")
	_expect_equal(int(h05_snapshot["heat_by_cell"]["0,0"]), 3, "H05 heat vent modifies Phase-D exposure before response")
	_expect_true(String(with_h05["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "active heat H05 changes authoritative tick checksum")
	_expect_h05_event(h05_snapshot, "heat", 2, 3)

func _test_contamination_phase_d_h05_changes_exposure_and_evidence() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var with_h05: Dictionary = runner.simulate(_record("route-contamination"), 1, _contamination_defs(true))
	var baseline: Dictionary = runner.simulate(_record("route-contamination"), 1, _contamination_defs(false))
	_expect_true(bool(with_h05.get("ok", false)), "production contamination H05 route resolves")
	_expect_true(bool(baseline.get("ok", false)), "production contamination baseline resolves")
	if not bool(with_h05.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var h05_snapshot: Dictionary = with_h05["end_tick_snapshots"][0]
	var base_snapshot: Dictionary = baseline["end_tick_snapshots"][0]
	_expect_equal(int(base_snapshot["phase_d_contamination_exposure_by_cell"]["0,0"]), 7, "baseline H03 contamination uses authored base vent")
	_expect_equal(int(h05_snapshot["phase_d_contamination_exposure_by_cell"]["0,0"]), 4, "H05 contamination vent modifies published Phase-D exposure")
	_expect_equal(int(h05_snapshot["contamination_by_cell"]["0,0"]), 4, "H05 contamination result persists as environment authority")
	_expect_true(String(with_h05["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "active contamination H05 changes authoritative tick checksum")
	_expect_h05_event(h05_snapshot, "contamination", 3, 4)

func _test_stress_phase_d_h05_changes_field_and_evidence() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var with_h05: Dictionary = runner.simulate(_record("route-stress"), 1, _stress_defs(true))
	var baseline: Dictionary = runner.simulate(_record("route-stress"), 1, _stress_defs(false))
	_expect_true(bool(with_h05.get("ok", false)), "production stress H05 route resolves")
	_expect_true(bool(baseline.get("ok", false)), "production stress baseline resolves")
	if not bool(with_h05.get("ok", false)) or not bool(baseline.get("ok", false)):
		return
	var h05_snapshot: Dictionary = with_h05["end_tick_snapshots"][0]
	var base_snapshot: Dictionary = baseline["end_tick_snapshots"][0]
	_expect_equal(int(base_snapshot["stress_field_by_cell"]["0,0"]), 4, "baseline H02 stress field uses authored base decay")
	_expect_equal(int(h05_snapshot["stress_field_by_cell"]["0,0"]), 2, "H05 modifies existing stress-field Phase-D decay")
	_expect_true(String(with_h05["tick_checksums"][0]) != String(baseline["tick_checksums"][0]), "active stress H05 changes authoritative tick checksum")
	_expect_h05_event(h05_snapshot, "stress_field", 2, 3)

func _test_inactive_future_h05_is_byte_equivalent() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var future: Dictionary = _contamination_defs(false)
	var future_hazards: Dictionary = future["hazards_by_id"]
	future_hazards["h05-future"] = _h05("contamination", 2)
	future["hazards_by_id"] = future_hazards
	var future_route: Dictionary = future["route_profile"]
	var future_events: Array = future_route["events"]
	future_events.append({"tick": 3, "duration_ticks": 1, "hazard_id": "h05-future", "authored_order": 9})
	future_route["events"] = future_events
	future["route_profile"] = future_route
	var future_result: Dictionary = runner.simulate(_record("route-contamination"), 1, future)
	var baseline: Dictionary = runner.simulate(_record("route-contamination"), 1, _contamination_defs(false))
	_expect_true(bool(future_result.get("ok", false)) and bool(baseline.get("ok", false)), "inactive future H05 and baseline both resolve")
	if bool(future_result.get("ok", false)) and bool(baseline.get("ok", false)):
		_expect_equal(future_result, baseline, "H05 outside the simulated window preserves prior production output byte-equivalent")

func _test_replay_is_deterministic() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var first: Dictionary = runner.simulate(_record("route-contamination"), 1, _contamination_defs(true))
	var second: Dictionary = runner.simulate(_record("route-contamination"), 1, _contamination_defs(true))
	_expect_equal(first, second, "active H05 production replay is deterministic")

func _record(route_id: String) -> Dictionary:
	return {
		"run_id": "h05-production-run",
		"rules_version": "rules-r1",
		"content_version": "h05-production-1",
		"canonical_committed_input": {
			"route_id": route_id,
			"seed": 505,
			"placements": [{"instance_id": "cargo-a", "anchor": [0, 0], "orientation": 0}],
			"supports": [],
			"brownout_priority": [],
		},
	}

func _heat_defs(include_h05: bool) -> Dictionary:
	var events: Array = [{"tick": 1, "duration_ticks": 1, "hazard_id": "h01-heat", "authored_order": 0}]
	var hazards: Dictionary = {
		"h01-heat": {"id": "h01-heat", "family": "H01", "target_scope": "hold", "heat_delta": 6},
	}
	if include_h05:
		events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h05-heat", "authored_order": 1})
		hazards["h05-heat"] = _h05("heat", 2)
	return {
		"route_profile": {"id": "route-heat", "tick_count": 1, "events": events},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": hazards,
		"support_definitions_by_id": {},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {"0,0": 1}},
	}

func _contamination_defs(include_h05: bool) -> Dictionary:
	var events: Array = [{"tick": 1, "duration_ticks": 1, "hazard_id": "h03-contamination", "authored_order": 0}]
	var hazards: Dictionary = {
		"h03-contamination": {"id": "h03-contamination", "family": "H03", "contamination_delta": 8, "target_cells": ["0,0"]},
	}
	if include_h05:
		events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h05-contamination", "authored_order": 1})
		hazards["h05-contamination"] = _h05("contamination", 3)
	return {
		"route_profile": {"id": "route-contamination", "tick_count": 1, "events": events},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": hazards,
		"support_definitions_by_id": {},
		"contamination_rules": {"contamination_min": 0, "contamination_max": 20, "transfer_edges": [], "vent_by_cell": {"0,0": 1}},
	}

func _stress_defs(include_h05: bool) -> Dictionary:
	var events: Array = [{"tick": 1, "duration_ticks": 1, "hazard_id": "h02-stress", "authored_order": 0}]
	var hazards: Dictionary = {
		"h02-stress": {"id": "h02-stress", "family": "H02", "stress_field_delta": 5, "target_cells": ["0,0"]},
	}
	if include_h05:
		events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h05-stress", "authored_order": 1})
		hazards["h05-stress"] = _h05("stress_field", 2)
	return {
		"route_profile": {"id": "route-stress", "tick_count": 1, "events": events},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": [], "power_capacity": 0},
		"hazards_by_id": hazards,
		"support_definitions_by_id": {},
		"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
		"stress_field_rules": {"stress_field_min": 0, "stress_field_max": 20, "transfer_edges": [], "decay_by_cell": {"0,0": 1}},
	}

func _h05(channel: String, delta: int) -> Dictionary:
	return {
		"id": "h05-%s" % channel,
		"family": "H05",
		"vent_delta_by_channel": {channel: {"0,0": delta}},
	}

func _expect_h05_event(snapshot: Dictionary, channel: String, delta: int, vent_after: int) -> void:
	var events_value: Variant = snapshot.get("h05_vent_events", [])
	_expect_true(events_value is Array, "H05 snapshot evidence is an array")
	if not events_value is Array:
		return
	var events: Array = events_value
	var matched: Dictionary = {}
	for raw_event: Variant in events:
		if raw_event is Dictionary and String((raw_event as Dictionary).get("channel", "")) == channel:
			matched = raw_event
			break
	_expect_true(not matched.is_empty(), "H05 snapshot contains channel-specific H05_VENT_MODIFIED evidence for %s" % channel)
	if matched.is_empty():
		return
	_expect_equal(String(matched.get("kind", "")), "H05_VENT_MODIFIED", "production H05 evidence keeps canonical event kind")
	_expect_equal(String(matched.get("phase", "")), "D", "production H05 evidence remains Phase D")
	_expect_equal(int(matched.get("vent_delta", 0)), delta, "production H05 evidence records authored delta")
	_expect_equal(int(matched.get("vent_after", -1)), vent_after, "production H05 evidence records effective vent/decay")
	var effective_value: Variant = snapshot.get("phase_d_effective_vent_by_channel", {})
	_expect_true(effective_value is Dictionary, "production H05 snapshot exposes effective vent/decay authority")
	if effective_value is Dictionary:
		var effective: Dictionary = effective_value
		_expect_true(effective.has(channel), "effective vent/decay evidence contains affected channel")
		if effective.has(channel) and effective[channel] is Dictionary:
			_expect_equal(int((effective[channel] as Dictionary).get("0,0", -1)), vent_after, "effective vent/decay map records affected cell")

func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
