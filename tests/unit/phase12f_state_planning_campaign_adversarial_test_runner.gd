extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const StructuralResolverScript := preload("res://src/planning/structural_resolver.gd")
const PlanningFocusRouterScript := preload("res://src/ui/planning_focus_router.gd")
const CampaignProgressionGateScript := preload("res://src/run/campaign_progression_gate.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")

var failures: int = 0

func _init() -> void:
	_test_hostile_state_ordering()
	_test_modal_focus_escape_attempts()
	_test_impossible_planning_layouts()
	_test_campaign_lock_semantics()
	_test_campaign_progression_gate_attacks()
	_test_coordinator_progression_bypass_guards()
	if failures == 0:
		print("phase12f_state_planning_campaign_adversarial_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12f_state_planning_campaign_adversarial_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_hostile_state_ordering() -> void:
	var state: AppStateMachine = AppStateMachineScript.new()
	_expect(not state.transition_to(AppStateMachine.State.PLANNING), "BOOT cannot skip directly into Planning")
	_expect(not state.transition_to(AppStateMachine.State.TRANSIT_PLAYBACK), "BOOT cannot forge Transit ownership")
	_expect(state.transition_to(AppStateMachine.State.TITLE), "BOOT -> TITLE remains legal")
	_expect(not state.transition_to(AppStateMachine.State.PLANNING), "TITLE cannot bypass Campaign/Brief")
	_expect(state.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "TITLE -> CAMPAIGN_MAP")
	_expect(state.transition_to(AppStateMachine.State.CONTRACT_BRIEF), "MAP -> BRIEF")
	_expect(state.transition_to(AppStateMachine.State.PLANNING), "BRIEF -> PLANNING")
	_expect(not state.transition_to(AppStateMachine.State.TRANSIT_PLAYBACK), "Planning cannot bypass Launch confirmation")
	_expect(state.transition_to(AppStateMachine.State.LAUNCH_CONFIRM), "PLANNING -> LAUNCH_CONFIRM")
	_expect(not state.transition_to(AppStateMachine.State.CAUSAL_REVIEW), "Launch confirmation cannot forge Review")
	_expect(state.transition_to(AppStateMachine.State.TRANSIT_PLAYBACK), "LAUNCH_CONFIRM -> TRANSIT")
	_expect(not state.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "Transit cannot escape to map before completion")
	var malformed: Dictionary = {"ok": true, "completed": true, "next_state": "CAUSAL_REVIEW", "delivery_result": {"ok": false, "success": true}}
	_expect(not state.accept_completed_transit(malformed), "malformed completion cannot seize Review ownership")
	var valid: Dictionary = {"ok": true, "completed": true, "next_state": "CAUSAL_REVIEW", "delivery_result": {"ok": true, "success": false}}
	_expect(state.accept_completed_transit(valid), "authoritative failed delivery may enter Review")
	_expect_equal(state.current_state(), AppStateMachine.State.CAUSAL_REVIEW, "failed delivery still owns Causal Review")
	_expect(not state.accept_completed_transit(valid), "duplicate completion callback cannot transition twice")
	_expect(state.enter_codex(), "Review may enter Codex")
	_expect_equal(state.codex_return_state(), AppStateMachine.State.CAUSAL_REVIEW, "Codex remembers exact Review owner")
	_expect(state.exit_codex(), "Codex exits to exact prior state")
	_expect_equal(state.current_state(), AppStateMachine.State.CAUSAL_REVIEW, "Codex cannot redirect Review to another screen")

func _test_modal_focus_escape_attempts() -> void:
	var router: PlanningFocusRouter = PlanningFocusRouterScript.new()
	_expect(bool(router.configure_hold(3, 2).get("ok", false)), "hostile focus router configures representative hold")
	_expect(bool(router.set_region(&"HOLD").get("ok", false)), "hostile focus baseline reaches HOLD")
	_expect(bool(router.enter_modal(&"INSPECTOR").get("ok", false)), "modal takes explicit focus ownership")
	var next_region: Dictionary = router.semantic_request(&"region_next")
	_expect(not bool(next_region.get("ok", true)), "region-next cannot escape behind modal")
	_expect_equal(String(next_region.get("error", "")), "modal_focus_trap", "modal escape reports deterministic trap")
	var direct_escape: Dictionary = router.set_region(&"HOLD")
	_expect(not bool(direct_escape.get("ok", true)), "direct focus assignment cannot escape modal")
	_expect_equal(router.current_region(), &"INSPECTOR", "failed escape leaves modal region authoritative")
	var pointer_like_move: Dictionary = router.semantic_request(&"navigate_right")
	_expect(not bool(pointer_like_move.get("ok", true)), "grid navigation cannot mutate hidden HOLD while modal owns focus")
	var accept: Dictionary = router.semantic_request(&"accept")
	_expect(bool(accept.get("ok", false)), "modal accept remains semantically dispatchable")
	_expect_equal(accept.get("region"), &"INSPECTOR", "modal accept is scoped to modal owner")
	_expect(bool(router.exit_modal().get("ok", false)), "modal can release focus explicitly")
	_expect(bool(router.semantic_request(&"region_next").get("ok", false)), "region navigation resumes only after modal release")

func _test_impossible_planning_layouts() -> void:
	var contract: Dictionary = _contract()
	var hold: Dictionary = _hold()
	var species: Dictionary = _species()
	var legal: Dictionary = StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
	]))
	_expect(bool(legal.get("ok", false)), "legal adversarial baseline resolves")
	_expect(bool(_facts(legal).get("mandatory_manifest_placed", false)), "legal baseline places mandatory manifest")

	var overlap: Dictionary = StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
		{"instance_id":"b","anchor":[0,0],"orientation":0},
	]))
	_expect(not bool(_facts(overlap).get("overlap_free", true)), "overlap cannot pass structural facts")

	var blocked: Dictionary = StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[1,1],"orientation":0},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
	]))
	_expect(not bool(_facts(blocked).get("blocked_free", true)), "blocked hold cell cannot pass")

	var outside: Dictionary = StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[-1,0],"orientation":0},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
	]))
	_expect(not bool(_facts(outside).get("in_bounds", true)), "negative anchor cannot pass in-bounds check")

	var orientation: Dictionary = StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":3},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
	]))
	_expect(not bool(_facts(orientation).get("orientations_valid", true)), "forged illegal orientation cannot pass")

	var missing: Dictionary = StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
	]))
	_expect(not bool(_facts(missing).get("mandatory_manifest_placed", true)), "missing mandatory instance blocks Launch")

	var unknown: Dictionary = StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
		{"instance_id":"forged","anchor":[2,2],"orientation":0},
	]))
	_expect(not bool(_facts(unknown).get("structural_prerequisites_met", true)), "unknown injected instance cannot pass prerequisites")

	var zone_contract: Dictionary = _contract()
	(zone_contract["manifest"] as Array)[1]["allowed_zone_ids"] = ["cold"]
	var zone_hold: Dictionary = _hold()
	zone_hold["zones"] = {"cold":[[2,0]]}
	var zone_violation: Dictionary = StructuralResolverScript.resolve(zone_contract, zone_hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
		{"instance_id":"b","anchor":[2,2],"orientation":0},
	]))
	_expect(not bool(_facts(zone_violation).get("zones_valid", true)), "zone-restricted organism cannot be placed outside authored zone")

func _test_campaign_lock_semantics() -> void:
	var doc: Dictionary = _campaign_graph()
	_expect(not doc.is_empty(), "campaign graph fixture loads")
	var payload_value: Variant = doc.get("payload", {})
	var payload: Dictionary = payload_value if payload_value is Dictionary else {}
	_expect_equal(String(payload.get("progression_currency", "")), "Bronze completion", "campaign graph declares Bronze-only progression")
	_expect_equal(String(payload.get("challenge_mode_gate", "")), "Bronze(C16)", "Challenge gate is exact C16 Bronze")
	var definitions_value: Variant = payload.get("definitions", [])
	var definitions: Array = definitions_value if definitions_value is Array else []
	_expect_equal(definitions.size(), 48, "campaign graph owns exactly C01-C48")
	var by_id: Dictionary = {}
	for raw: Variant in definitions:
		if raw is Dictionary:
			var node: Dictionary = raw
			var id: String = String(node.get("id", ""))
			_expect(not id.is_empty() and not by_id.has(id), "campaign node ids are unique")
			by_id[id] = node
			_expect(bool(node.get("bronze_prerequisites_only", false)), "%s cannot use medal/knowledge lock bypass" % id)
	var c01: Dictionary = by_id["C01"] if by_id.has("C01") and by_id["C01"] is Dictionary else {}
	var c01_prerequisites_value: Variant = c01.get("prerequisites", [])
	var c01_prerequisites: Array = c01_prerequisites_value if c01_prerequisites_value is Array else []
	_expect(by_id.has("C01") and c01_prerequisites.is_empty(), "fresh profile exposes C01 root")
	_expect_equal((by_id["C16"] as Dictionary).get("prerequisites", []), ["C14", "C15"], "C16 exact capstone dependencies remain frozen")
	_expect_equal((by_id["C48"] as Dictionary).get("prerequisites", []), ["C47"], "final node cannot bypass C47")

func _test_campaign_progression_gate_attacks() -> void:
	var gate: CampaignProgressionGate = CampaignProgressionGateScript.new()
	_expect(bool(gate.configure(_campaign_graph()).get("ok", false)), "production campaign gate accepts frozen graph")
	var fresh: Dictionary = _profile([])
	var fresh_available: Dictionary = gate.available_contract_ids(fresh)
	_expect(bool(fresh_available.get("ok", false)), "fresh profile availability derives cleanly")
	_expect_equal(fresh_available.get("contract_ids", []), ["C01"], "fresh profile exposes only C01")
	var locked_c02: Dictionary = gate.can_select_contract("C02", fresh)
	_expect(not bool(locked_c02.get("ok", true)), "forged unavailable C02 selection is rejected")
	_expect(String(locked_c02.get("error", "")).begins_with("campaign_contract_locked:C02"), "locked C02 identifies missing Bronze prerequisite")
	_expect(bool(gate.can_select_contract("C01", fresh).get("ok", false)), "C01 remains selectable on fresh profile")
	var impossible: Dictionary = gate.validate_profile(_profile(["C02"]))
	_expect(not bool(impossible.get("ok", true)), "impossible Bronze child without prerequisite is rejected")
	_expect(String(impossible.get("error", "")).begins_with("impossible_bronze_profile:C02"), "impossible profile reports exact broken closure")
	var forged_unknown: Dictionary = gate.validate_profile(_profile(["C99"]))
	_expect(not bool(forged_unknown.get("ok", true)), "unknown forged Bronze id is rejected")

	var before_c16: Dictionary = _profile(_bronze_prefix(15))
	var challenge_before: Dictionary = gate.challenge_mode_unlocked(before_c16)
	_expect(bool(challenge_before.get("ok", false)) and not bool(challenge_before.get("unlocked", true)), "Challenge stays locked before Bronze C16 despite complete earlier prefix")
	before_c16["best_medal_by_contract"] = {"C01":"GOLD","C15":"GOLD"}
	before_c16["documented_fact_ids"] = ["all-rules"]
	_expect(not bool(gate.challenge_mode_unlocked(before_c16).get("unlocked", true)), "Gold/knowledge cannot substitute for C16 Bronze")
	var at_c16: Dictionary = gate.challenge_mode_unlocked(_profile(_bronze_prefix(16)))
	_expect(bool(at_c16.get("ok", false)) and bool(at_c16.get("unlocked", false)), "Bronze C16 unlocks Challenge exactly")

	var before_c48: Dictionary = gate.campaign_complete_available(_profile(_bronze_prefix(47)))
	_expect(bool(before_c48.get("ok", false)) and not bool(before_c48.get("available", true)), "campaign completion cannot fire before Bronze C48")
	var at_c48: Dictionary = gate.campaign_complete_available(_profile(_bronze_prefix(48)))
	_expect(bool(at_c48.get("ok", false)) and bool(at_c48.get("available", false)), "Bronze C48 enables campaign completion")

func _test_coordinator_progression_bypass_guards() -> void:
	var graph: Dictionary = _campaign_graph()
	var fresh_state: AppStateMachine = AppStateMachineScript.new()
	_expect(fresh_state.transition_to(AppStateMachine.State.TITLE), "coordinator guard baseline reaches TITLE")
	var fresh_flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(fresh_state, AtomicSaveStoreScript.new("user://phase12f_campaign_guard_fresh"))
	_expect(bool(fresh_flow.configure_campaign_progression(graph, _profile([])).get("ok", false)), "coordinator installs frozen campaign gate")
	_expect(fresh_flow.enter_campaign_map(), "guarded coordinator enters map")
	_expect(not fresh_flow.select_contract("C02"), "coordinator rejects forged unavailable contract selection")
	_expect_equal(fresh_flow.current_state(), AppStateMachine.State.CAMPAIGN_MAP, "rejected contract selection cannot change state")
	_expect(fresh_flow.select_contract("C01"), "coordinator permits exact available root")

	var challenge_state: AppStateMachine = AppStateMachineScript.new()
	_expect(challenge_state.transition_to(AppStateMachine.State.TITLE), "Challenge guard baseline reaches TITLE")
	var challenge_flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(challenge_state, AtomicSaveStoreScript.new("user://phase12f_campaign_guard_challenge"))
	_expect(bool(challenge_flow.configure_campaign_progression(graph, _profile(_bronze_prefix(15))).get("ok", false)), "Challenge guard accepts valid pre-C16 profile")
	var early_challenge: Dictionary = challenge_flow.enter_challenge_select()
	_expect(not bool(early_challenge.get("ok", true)), "coordinator blocks early Challenge entry")
	_expect_equal(String(early_challenge.get("error", "")), "challenge_mode_locked", "early Challenge rejection is explicit")
	_expect(bool(challenge_flow.update_campaign_profile(_profile(_bronze_prefix(16))).get("ok", false)), "coordinator accepts monotonic C16 profile update")
	_expect(bool(challenge_flow.enter_challenge_select().get("ok", false)), "coordinator permits Challenge after Bronze C16")

	var completion_state: AppStateMachine = AppStateMachineScript.new()
	_expect(completion_state.transition_to(AppStateMachine.State.TITLE), "completion guard baseline reaches TITLE")
	_expect(completion_state.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "completion guard baseline reaches MAP")
	var completion_flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(completion_state, AtomicSaveStoreScript.new("user://phase12f_campaign_guard_complete"))
	_expect(bool(completion_flow.configure_campaign_progression(graph, _profile(_bronze_prefix(47))).get("ok", false)), "completion guard accepts valid pre-C48 profile")
	var early_complete: Dictionary = completion_flow.enter_campaign_complete()
	_expect(not bool(early_complete.get("ok", true)), "coordinator blocks campaign completion before Bronze C48")
	_expect_equal(String(early_complete.get("error", "")), "campaign_not_complete", "early campaign completion rejection is explicit")
	_expect_equal(completion_flow.current_state(), AppStateMachine.State.CAMPAIGN_MAP, "early campaign completion cannot mutate state")
	_expect(bool(completion_flow.update_campaign_profile(_profile(_bronze_prefix(48))).get("ok", false)), "coordinator accepts complete Bronze closure")
	_expect(bool(completion_flow.enter_campaign_complete().get("ok", false)), "coordinator permits campaign completion only after Bronze C48")

func _profile(bronze_ids: Array) -> Dictionary:
	return {"profile_uuid":"phase12f-profile", "cleared_bronze_contract_ids":bronze_ids.duplicate(), "best_medal_by_contract":{}, "documented_fact_ids":[]}

func _bronze_prefix(count: int) -> Array:
	var ids: Array = []
	for index: int in range(1, count + 1):
		ids.append("C%02d" % index)
	return ids

func _campaign_graph() -> Dictionary:
	return _load_json("res://content/campaign/campaign_graph.json")

func _contract() -> Dictionary:
	return {"manifest":[
		{"instance_id":"a","species_id":"O-A","mandatory":true,"allowed_zone_ids":[]},
		{"instance_id":"b","species_id":"O-B","mandatory":true,"allowed_zone_ids":[]},
	], "structural_prerequisites":[], "support_allowance_max":0}

func _hold() -> Dictionary:
	return {"width":3,"height":3,"blocked_cells":[[1,1]],"zones":{}}

func _species() -> Dictionary:
	return {
		"O-A":{"legal_orientations":[0,1],"current_footprints":{"0":[[0,0]],"1":[[0,0]]}},
		"O-B":{"legal_orientations":[0],"current_footprints":{"0":[[0,0]]}},
	}

func _input(placements: Array) -> Dictionary:
	return {"route_id":"adversarial","manifest_instance_ids":["a","b"],"placements":placements,"supports":[],"seed":7}

func _facts(result: Dictionary) -> Dictionary:
	var value: Variant = result.get("structural_facts", {})
	return value if value is Dictionary else {}

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
