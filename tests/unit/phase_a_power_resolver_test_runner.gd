extends SceneTree

const PhaseAPowerResolverScript := preload("res://src/sim/phase_a_power_resolver.gd")
const TransitPowerIntegratedRunnerScript := preload("res://src/sim/transit_power_integrated_runner.gd")

var failures: int = 0

func _init() -> void:
	_test_no_brownout_powers_every_support_deterministically()
	_test_brownout_uses_unique_player_priority_and_full_on_off_allocation()
	_test_disabled_support_has_no_same_tick_effect_eligibility()
	_test_power_transition_event_is_emitted()
	_test_invalid_brownout_priority_fails_closed()
	_test_priority_changes_authoritative_checksum()
	_test_transit_h04_priority_controls_same_tick_eligibility()
	_test_transit_h04_power_state_transitions_and_checksum_authority()
	_test_transit_s01_phase_c_changes_same_tick_heat_and_exposure()
	_test_transit_brownout_disabled_s01_has_zero_same_tick_mitigation()
	if failures == 0:
		print("phase_a_power_resolver_test_runner: PASS")
		quit(0)
	else:
		push_error("phase_a_power_resolver_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_no_brownout_powers_every_support_deterministically() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var first: Dictionary = resolver.resolve(8, _supports(), [])
	var second: Dictionary = resolver.resolve(8, _supports_reordered(), [])
	_expect_true(bool(first["ok"]) and bool(second["ok"]), "sufficient power resolves without priority")
	_expect_equal(first["powered_support_ids"], PackedStringArray(["cooler-a", "filter-a", "monitor-a"]), "powered state is stable support-id ordered")
	_expect_equal(int(first["used_power"]), 8, "all powered-support demand is allocated when capacity is sufficient")
	_expect_equal(first["authority_checksum"], second["authority_checksum"], "input support ordering does not change Phase-A authority")

func _test_brownout_uses_unique_player_priority_and_full_on_off_allocation() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var result: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "monitor-a"])
	_expect_true(bool(result["ok"]), "Brownout allocation succeeds with complete unique priority")
	_expect_true(bool(result["brownout_active"]), "demand above temporary capacity marks Brownout active")
	_expect_equal(result["powered_support_ids"], PackedStringArray(["cooler-a", "monitor-a"]), "priority allocates whole supports without partial power")
	_expect_equal(result["disabled_support_ids"], PackedStringArray(["filter-a"]), "support that cannot fit remaining power is fully off")
	_expect_equal(int(result["used_power"]), 5, "priority allocation consumes only whole-support power draw")

func _test_disabled_support_has_no_same_tick_effect_eligibility() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var result: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "monitor-a"])
	_expect_equal(result["same_tick_effect_eligible_support_ids"], PackedStringArray(["cooler-a", "monitor-a"]), "Phase-A disabled support is absent from same-tick Phase-C/E effect eligibility")
	_expect_true(not bool(result["powered_by_id"]["filter-a"]), "disabled support authority is finalized off in Phase A")

func _test_power_transition_event_is_emitted() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var previous: Dictionary = {
		"cooler-a": true,
		"filter-a": true,
		"monitor-a": true,
	}
	var result: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "monitor-a"], previous)
	var events: Array = result["events"]
	_expect_equal(events.size(), 1, "only the support whose power state changes emits a causal transition event")
	var event: Dictionary = events[0]
	_expect_equal(String(event["support_instance_id"]), "filter-a", "transition event identifies the Brownout-disabled support")
	_expect_true(bool(event["from_powered"]) and not bool(event["to_powered"]), "transition event preserves powered-to-off direction")

func _test_invalid_brownout_priority_fails_closed() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var missing: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a"])
	var duplicate: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "filter-a"])
	_expect_true(not bool(missing["ok"]), "Brownout cannot invent a missing priority entry")
	_expect_equal(String(missing["error"]), "brownout_priority_must_cover_all_powered_supports", "missing priority has deterministic failure reason")
	_expect_true(not bool(duplicate["ok"]), "Brownout priority must be unique")
	_expect_equal(String(duplicate["error"]), "duplicate_brownout_priority_id:filter-a", "duplicate priority has deterministic failure reason")

func _test_priority_changes_authoritative_checksum() -> void:
	var resolver: PhaseAPowerResolver = PhaseAPowerResolverScript.new()
	var cooler_first: Dictionary = resolver.resolve(5, _supports(), ["cooler-a", "filter-a", "monitor-a"])
	var filter_first: Dictionary = resolver.resolve(5, _supports(), ["filter-a", "cooler-a", "monitor-a"])
	_expect_true(bool(cooler_first["ok"]) and bool(filter_first["ok"]), "both legal player priorities resolve")
	_expect_equal(filter_first["powered_support_ids"], PackedStringArray(["filter-a", "monitor-a"]), "changed player priority changes the powered support set")
	_expect_true(String(cooler_first["authority_checksum"]) != String(filter_first["authority_checksum"]), "different Phase-A power authority changes checksum evidence")

func _test_transit_h04_priority_controls_same_tick_eligibility() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var cooler_first: Dictionary = runner.simulate(_power_record(["cooler-a", "monitor-a"]), 3, _power_defs())
	var monitor_first: Dictionary = runner.simulate(_power_record(["monitor-a", "cooler-a"]), 3, _power_defs())
	_expect_true(bool(cooler_first["ok"]) and bool(monitor_first["ok"]), "production transit path accepts powered supports plus H04")
	var cooler_snapshots: Array = cooler_first["end_tick_snapshots"]
	var monitor_snapshots: Array = monitor_first["end_tick_snapshots"]
	var cooler_brownout: Dictionary = cooler_snapshots[1]
	var monitor_brownout: Dictionary = monitor_snapshots[1]
	_expect_equal(cooler_brownout["active_hazards"], PackedStringArray(["h04-test"]), "H04 remains visible in the authoritative Phase-A snapshot")
	_expect_equal(int(cooler_brownout["phase_a_power"]["available_power"]), 4, "H04 reduces temporary available power before support effects")
	_expect_equal(cooler_brownout["same_tick_effect_eligible_support_ids"], PackedStringArray(["cooler-a"]), "cooler-first priority leaves only Cooler eligible in the Brownout tick")
	_expect_equal(monitor_brownout["same_tick_effect_eligible_support_ids"], PackedStringArray(["monitor-a"]), "monitor-first priority leaves only Monitor eligible in the same Brownout tick")
	_expect_true(String(cooler_first["tick_checksums"][1]) != String(monitor_first["tick_checksums"][1]), "player-declared Brownout priority changes authoritative transit checksum evidence")

func _test_transit_h04_power_state_transitions_and_checksum_authority() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_power_record(["cooler-a", "monitor-a"]), 3, _power_defs())
	_expect_true(bool(result["ok"]), "H04 transit executes across pre-brownout, brownout, and recovery ticks")
	var snapshots: Array = result["end_tick_snapshots"]
	var tick_one: Dictionary = snapshots[0]
	var tick_two: Dictionary = snapshots[1]
	var tick_three: Dictionary = snapshots[2]
	_expect_equal(tick_one["same_tick_effect_eligible_support_ids"], PackedStringArray(["cooler-a", "monitor-a"]), "both powered supports are eligible before H04")
	_expect_equal(tick_two["same_tick_effect_eligible_support_ids"], PackedStringArray(["cooler-a"]), "support disabled in Phase A is excluded from same-tick effect authority")
	_expect_equal(tick_three["same_tick_effect_eligible_support_ids"], PackedStringArray(["cooler-a", "monitor-a"]), "power eligibility recovers after H04 ends")
	var events: Array = result["support_power_events"]
	_expect_equal(events.size(), 2, "Brownout onset and recovery each emit one support power transition")
	var off_event: Dictionary = events[0]
	var on_event: Dictionary = events[1]
	_expect_equal(int(off_event["tick"]), 2, "disable transition is owned by the H04 Phase-A tick")
	_expect_equal(String(off_event["support_instance_id"]), "monitor-a", "lower-priority support is the deterministic Brownout casualty")
	_expect_true(not bool(off_event["to_powered"]), "Brownout transition records powered to off")
	_expect_equal(int(on_event["tick"]), 3, "recovery transition occurs at the next Phase-A boundary after H04 ends")
	_expect_true(bool(on_event["to_powered"]), "recovery transition restores powered state")
	_expect_true(String(result["tick_checksums"][0]) != String(result["tick_checksums"][1]), "H04 Phase-A authority contributes to tick checksum evidence")

func _test_transit_s01_phase_c_changes_same_tick_heat_and_exposure() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var result: Dictionary = runner.simulate(_cooler_thermal_record(["cooler-a", "monitor-a"]), 1, _cooler_thermal_defs(0))
	_expect_true(bool(result["ok"]), "S01 transit fixture executes with authored H01 heat")
	if not bool(result["ok"]):
		return
	var snapshot: Dictionary = result["end_tick_snapshots"][0]
	_expect_equal(int(snapshot["heat_by_cell"]["0,0"]), 2, "authorized Cooler removes four heat in Phase C before Phase D publication")
	var organisms: Array = snapshot["organisms"]
	var specimen: Dictionary = organisms[0]
	_expect_equal(int(specimen["heat_exposure"]), 2, "same-tick Phase-E exposure sees the post-Cooler Phase-D heat field")
	var events: Array = snapshot["phase_c_support_events"]
	_expect_equal(events.size(), 1, "authorized Cooler emits one deterministic Phase-C causal event")
	var cooler_event: Dictionary = events[0]
	_expect_equal(int(cooler_event["removed_heat"]), 4, "S01 causal event records exact removed heat")

func _test_transit_brownout_disabled_s01_has_zero_same_tick_mitigation() -> void:
	var runner: TransitPowerIntegratedRunner = TransitPowerIntegratedRunnerScript.new()
	var cooler_first: Dictionary = runner.simulate(_cooler_thermal_record(["cooler-a", "monitor-a"]), 1, _cooler_thermal_defs(1))
	var monitor_first: Dictionary = runner.simulate(_cooler_thermal_record(["monitor-a", "cooler-a"]), 1, _cooler_thermal_defs(1))
	_expect_true(bool(cooler_first["ok"]) and bool(monitor_first["ok"]), "both legal Brownout priorities execute with H01 plus H04")
	if not bool(cooler_first["ok"]) or not bool(monitor_first["ok"]):
		return
	var cooler_snapshot: Dictionary = cooler_first["end_tick_snapshots"][0]
	var monitor_snapshot: Dictionary = monitor_first["end_tick_snapshots"][0]
	_expect_equal(cooler_snapshot["same_tick_effect_eligible_support_ids"], PackedStringArray(["cooler-a"]), "Cooler-first Brownout priority authorizes S01")
	_expect_equal(int(cooler_snapshot["heat_by_cell"]["0,0"]), 2, "authorized S01 mitigates same-tick H01 heat")
	_expect_equal(monitor_snapshot["same_tick_effect_eligible_support_ids"], PackedStringArray(["monitor-a"]), "Monitor-first Brownout priority disables S01 in Phase A")
	_expect_equal(int(monitor_snapshot["heat_by_cell"]["0,0"]), 6, "Brownout-disabled S01 provides zero same-tick heat mitigation")
	_expect_equal(monitor_snapshot["phase_c_support_events"], [], "disabled S01 emits no Phase-C effect event")
	var monitor_organisms: Array = monitor_snapshot["organisms"]
	var monitor_specimen: Dictionary = monitor_organisms[0]
	_expect_equal(int(monitor_specimen["heat_exposure"]), 6, "Phase-E organism exposure receives unmitigated heat when S01 was disabled in Phase A")
	_expect_true(String(cooler_first["tick_checksums"][0]) != String(monitor_first["tick_checksums"][0]), "S01 Phase-C authority is checksum-visible")

func _power_record(priority: Array) -> Dictionary:
	return {
		"run_id": "power-run",
		"rules_version": "rules-r1",
		"content_version": "power-test-1",
		"canonical_committed_input": {
			"route_id": "route-power-test",
			"seed": 17,
			"placements": [
				{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			],
			"supports": [
				{"instance_id": "cooler-a", "support_id": "S01", "anchor": [0, 0]},
				{"instance_id": "monitor-a", "support_id": "S06"},
			],
			"brownout_priority": priority.duplicate(true),
		},
	}

func _power_defs() -> Dictionary:
	return {
		"route_profile": {
			"id": "route-power-test",
			"tick_count": 3,
			"events": [
				{"tick": 2, "duration_ticks": 1, "hazard_id": "h04-test", "authored_order": 0},
			],
		},
		"hold_definition": {
			"dimensions": [1, 1],
			"blocked_cells": [],
			"power_capacity": 5,
		},
		"hazards_by_id": {
			"h04-test": {
				"id": "h04-test",
				"family": "H04",
				"target_scope": "hold",
				"power_reduction": 1,
			},
		},
		"support_definitions_by_id": {
			"S01": {"id": "S01", "family": "S01", "powered": true, "power_draw": 4, "heat_removal_capacity": 2},
			"S06": {"id": "S06", "family": "S06", "powered": true, "power_draw": 1},
		},
	}

func _cooler_thermal_record(priority: Array) -> Dictionary:
	return {
		"run_id": "cooler-thermal-run",
		"rules_version": "rules-r1",
		"content_version": "cooler-test-1",
		"canonical_committed_input": {
			"route_id": "route-cooler-test",
			"seed": 29,
			"placements": [
				{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			],
			"supports": [
				{"instance_id": "cooler-a", "support_id": "S01", "anchor": [0, 0]},
				{"instance_id": "monitor-a", "support_id": "S06"},
			],
			"brownout_priority": priority.duplicate(true),
		},
	}

func _cooler_thermal_defs(h04_reduction: int) -> Dictionary:
	var events: Array = [
		{"tick": 1, "duration_ticks": 1, "hazard_id": "h01-test", "authored_order": 0},
	]
	var hazards: Dictionary = {
		"h01-test": {
			"id": "h01-test",
			"family": "H01",
			"target_scope": "hold",
			"heat_delta": 6,
		},
	}
	if h04_reduction > 0:
		events.append({"tick": 1, "duration_ticks": 1, "hazard_id": "h04-test", "authored_order": 1})
		hazards["h04-test"] = {
			"id": "h04-test",
			"family": "H04",
			"target_scope": "hold",
			"power_reduction": h04_reduction,
		}
	return {
		"route_profile": {
			"id": "route-cooler-test",
			"tick_count": 1,
			"events": events,
		},
		"hold_definition": {
			"dimensions": [1, 1],
			"blocked_cells": [],
			"power_capacity": 2,
		},
		"hazards_by_id": hazards,
		"support_definitions_by_id": {
			"S01": {"id": "S01", "family": "S01", "powered": true, "power_draw": 1, "heat_removal_capacity": 4},
			"S06": {"id": "S06", "family": "S06", "powered": true, "power_draw": 1},
		},
		"thermal_rules": {
			"heat_min": 0,
			"heat_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"specimen-a": {
				"initial_stress": 0,
				"initial_state": "CALM",
				"stress_profile": {
					"heat_safe_max": 0,
					"stress_per_heat_unit": 1,
					"stress_min": 0,
					"stress_max": 20,
					"agitated_enter": 5,
					"agitated_exit": 3,
					"panic_enter": 10,
					"panic_exit": 7,
				},
			},
		},
	}

func _supports() -> Array:
	return [
		{"instance_id": "cooler-a", "powered": true, "power_draw": 4},
		{"instance_id": "filter-a", "powered": true, "power_draw": 3},
		{"instance_id": "monitor-a", "powered": true, "power_draw": 1},
		{"instance_id": "baffle-a", "powered": false, "power_draw": 0},
	]

func _supports_reordered() -> Array:
	return [
		{"instance_id": "monitor-a", "powered": true, "power_draw": 1},
		{"instance_id": "baffle-a", "powered": false, "power_draw": 0},
		{"instance_id": "filter-a", "powered": true, "power_draw": 3},
		{"instance_id": "cooler-a", "powered": true, "power_draw": 4},
	]

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
