extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const StructuralResolverScript := preload("res://src/planning/structural_resolver.gd")

var failures: int = 0

func _init() -> void:
	_test_hostile_state_ordering()
	_test_impossible_planning_layouts()
	_test_campaign_lock_semantics()
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

func _test_impossible_planning_layouts() -> void:
	var contract := _contract()
	var hold := _hold()
	var species := _species()
	var legal := StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
	]))
	_expect(bool(legal.get("ok", false)), "legal adversarial baseline resolves")
	_expect(bool(_facts(legal).get("mandatory_manifest_placed", false)), "legal baseline places mandatory manifest")

	var overlap := StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
		{"instance_id":"b","anchor":[0,0],"orientation":0},
	]))
	_expect(not bool(_facts(overlap).get("overlap_free", true)), "overlap cannot pass structural facts")

	var blocked := StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[1,1],"orientation":0},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
	]))
	_expect(not bool(_facts(blocked).get("blocked_free", true)), "blocked hold cell cannot pass")

	var outside := StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[-1,0],"orientation":0},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
	]))
	_expect(not bool(_facts(outside).get("in_bounds", true)), "negative anchor cannot pass in-bounds check")

	var orientation := StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":3},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
	]))
	_expect(not bool(_facts(orientation).get("orientations_valid", true)), "forged illegal orientation cannot pass")

	var missing := StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
	]))
	_expect(not bool(_facts(missing).get("mandatory_manifest_placed", true)), "missing mandatory instance blocks Launch")

	var unknown := StructuralResolverScript.resolve(contract, hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
		{"instance_id":"b","anchor":[2,0],"orientation":0},
		{"instance_id":"forged","anchor":[2,2],"orientation":0},
	]))
	_expect(not bool(_facts(unknown).get("structural_prerequisites_met", true)), "unknown injected instance cannot pass prerequisites")

	var zone_contract := _contract()
	(zone_contract["manifest"] as Array)[1]["allowed_zone_ids"] = ["cold"]
	var zone_hold := _hold()
	zone_hold["zones"] = {"cold":[[2,0]]}
	var zone_violation := StructuralResolverScript.resolve(zone_contract, zone_hold, species, _input([
		{"instance_id":"a","anchor":[0,0],"orientation":0},
		{"instance_id":"b","anchor":[2,2],"orientation":0},
	]))
	_expect(not bool(_facts(zone_violation).get("zones_valid", true)), "zone-restricted organism cannot be placed outside authored zone")

func _test_campaign_lock_semantics() -> void:
	var doc: Dictionary = _load_json("res://content/campaign/campaign_graph.json")
	_expect(not doc.is_empty(), "campaign graph fixture loads")
	var payload: Dictionary = doc.get("payload", {}) if doc.get("payload", {}) is Dictionary else {}
	_expect_equal(String(payload.get("progression_currency", "")), "Bronze completion", "campaign graph declares Bronze-only progression")
	_expect_equal(String(payload.get("challenge_mode_gate", "")), "Bronze(C16)", "Challenge gate is exact C16 Bronze")
	var definitions: Array = payload.get("definitions", []) if payload.get("definitions", []) is Array else []
	_expect_equal(definitions.size(), 48, "campaign graph owns exactly C01-C48")
	var by_id: Dictionary = {}
	for raw: Variant in definitions:
		if raw is Dictionary:
			var node: Dictionary = raw
			var id := String(node.get("id", ""))
			_expect(not id.is_empty() and not by_id.has(id), "campaign node ids are unique")
			by_id[id] = node
			_expect(bool(node.get("bronze_prerequisites_only", false)), "%s cannot use medal/knowledge lock bypass" % id)
	var c01: Dictionary = by_id["C01"] if by_id.has("C01") and by_id["C01"] is Dictionary else {}
	var c01_prerequisites: Array = c01.get("prerequisites", []) if c01.get("prerequisites", []) is Array else []
	_expect(by_id.has("C01") and c01_prerequisites.is_empty(), "fresh profile exposes C01 root")
	_expect_equal((by_id["C16"] as Dictionary).get("prerequisites", []), ["C14", "C15"], "C16 exact capstone dependencies remain frozen")
	_expect_equal((by_id["C48"] as Dictionary).get("prerequisites", []), ["C47"], "final node cannot bypass C47")
	var fake_profile := {"cleared_bronze_contract_ids":["C15"], "best_medal_by_contract":{"C01":"GOLD","C02":"GOLD","C15":"GOLD"}, "documented_fact_ids":["everything"], "achievements":["all"]}
	_expect(not _challenge_unlocked(fake_profile), "medals/knowledge/achievements cannot fake Challenge unlock")
	fake_profile["cleared_bronze_contract_ids"] = ["C16"]
	_expect(_challenge_unlocked(fake_profile), "Bronze C16 alone is the authoritative Challenge gate")

func _challenge_unlocked(profile: Dictionary) -> bool:
	var bronze: Variant = profile.get("cleared_bronze_contract_ids", [])
	return bronze is Array and "C16" in bronze

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
	if not FileAccess.file_exists(path): return {}
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
