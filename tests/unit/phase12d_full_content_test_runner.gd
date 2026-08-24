extends SceneTree

const ContentPopulationValidatorScript := preload("res://src/content/content_population_validator.gd")
var failures: int = 0

func _init() -> void:
	_validate_campaign()
	_validate_challenges()
	_validate_demo()
	if failures == 0:
		print("phase12d_full_content_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12d_full_content_test_runner: %d failure(s)" % failures)
		quit(1)

func _validate_campaign() -> void:
	var graph: Dictionary = _load_json("res://content/campaign/campaign_graph.json")
	var graph_defs: Array = _definitions(graph)
	_expect_equal(graph_defs.size(), 48, "campaign graph contains exactly 48 nodes")
	_expect_equal(String(_payload(graph).get("challenge_mode_gate", "")), "Bronze(C16)", "Challenge gate is exact")
	for raw_node: Variant in graph_defs:
		var node: Dictionary = raw_node
		var id: String = String(node.get("id", ""))
		_expect_true(bool(node.get("bronze_prerequisites_only", false)), "%s uses Bronze-only prerequisites" % id)
		var expected: Array = (ContentPopulationValidatorScript.CAMPAIGN_PREREQUISITES.get(id, []) as Array).duplicate()
		var actual: Array = (node.get("prerequisites", []) as Array).duplicate()
		_expect_equal(actual, expected, "%s exact prerequisite set" % id)

	var authored_by_id: Dictionary = {}
	for chapter: int in range(1, 7):
		for raw_contract: Variant in _definitions(_load_json("res://content/contracts/campaign_chapter%d_batch_01.json" % chapter)):
			var contract: Dictionary = raw_contract
			authored_by_id[String(contract.get("id", ""))] = contract
	_expect_equal(authored_by_id.size(), 48, "authored campaign contains exactly C01-C48")
	var two_change_count: int = 0
	for number: int in range(1, 49):
		var id: String = "C%02d" % number
		_expect_true(authored_by_id.has(id), "authored campaign contains %s" % id)
		if not authored_by_id.has(id):
			continue
		var contract: Dictionary = authored_by_id[id]
		if number >= 5:
			_expect_true(bool(contract.get("requires_post_launch_change", false)), "%s has dynamic post-launch significance" % id)
		if number >= 9 and int(contract.get("temporally_separated_changes", 0)) >= 2:
			two_change_count += 1
	_expect_true(two_change_count >= 20, "C09-C48 include at least 20 two-change Bronze cases")

	for chapter: int in range(2, 7):
		var max_spacing_count: int = 0
		var support_inferior_count: int = 0
		for number: int in range((chapter - 1) * 8 + 1, chapter * 8 + 1):
			var contract: Dictionary = authored_by_id["C%02d" % number]
			if bool(contract.get("maximum_spacing_inferior", false)):
				max_spacing_count += 1
			if bool(contract.get("cooler_or_filter_inferior", false)) or bool(contract.get("filter_inferior", false)):
				support_inferior_count += 1
		_expect_true(max_spacing_count >= 2, "chapter %d has >=2 maximum-spacing anti-template cases" % chapter)
		if chapter >= 3:
			_expect_true(support_inferior_count >= 1, "chapter %d has Cooler/Filter inferior evidence" % chapter)

	for chapter: int in [3, 4, 6]:
		var growth_edge_count: int = 0
		for number: int in range((chapter - 1) * 8 + 1, chapter * 8 + 1):
			if bool((authored_by_id["C%02d" % number] as Dictionary).get("growth_reserve_edge_inferior", false)):
				growth_edge_count += 1
		_expect_true(growth_edge_count >= (2 if chapter == 6 else 1), "chapter %d growth-edge anti-template quota" % chapter)

	var cooler_filter_pair_count: int = 0
	for number: int in range(17, 49):
		var supports: Array = (authored_by_id["C%02d" % number] as Dictionary).get("support_ids", [])
		if "S01" in supports and "S02" in supports:
			cooler_filter_pair_count += 1
	_expect_true(cooler_filter_pair_count <= 8, "Cooler+Filter count remains <=8")

func _validate_challenges() -> void:
	var root: Dictionary = _load_json("res://content/challenges/launch_challenge_templates.json")
	var payload: Dictionary = _payload(root)
	var defs: Array = _definitions(root)
	_expect_equal(defs.size(), 24, "launch Challenge set has exactly 24 templates")
	_expect_equal(int(payload.get("template_ceiling", -1)), 24, "launch Challenge ceiling is 24")
	_expect_equal(String(payload.get("mode_unlock_gate", "")), "Bronze(C16)", "Challenge set cannot bypass C16 Bronze")
	var policy: Dictionary = payload.get("validation_policy", {})
	for raw_challenge: Variant in defs:
		var challenge: Dictionary = raw_challenge
		var id: String = String(challenge.get("id", ""))
		_expect_true(bool(challenge.get("bronze", false)), "%s has certified Bronze" % id)
		_expect_true(bool(challenge.get("dynamic", false)), "%s is dynamically significant" % id)
		_expect_true(not bool(challenge.get("static_t0", true)), "%s is not static-t0-only" % id)
		_expect_true(bool(challenge.get("timing_matters", false)), "%s timing perturbation matters" % id)
		_expect_true(bool(challenge.get("medals_certified", false)), "%s medals are certified" % id)
		_expect_true(not bool(challenge.get("timeout_only", true)), "%s does not use timeout-only proof" % id)
		_expect_true(float(challenge.get("similarity", 1.0)) <= float(policy.get("max_recent_similarity", 0.8)), "%s similarity gate" % id)
		_expect_true(int(challenge.get("unseen", 99)) <= int(policy.get("max_unseen_state_changes", 2)), "%s unseen-state burden" % id)
		var tier: int = int(challenge.get("tier", 0))
		var limit: int = int(policy.get("causal_limit_tier6", 8)) if tier >= 6 else int(policy.get("causal_limit_below_tier6", 6))
		_expect_true(int(challenge.get("causal_links", 99)) <= limit, "%s causal opacity gate" % id)
		for field: String in ["source", "hold", "route", "family", "validation_hash", "qa", "fingerprint"]:
			_expect_true(not String(challenge.get(field, "")).is_empty(), "%s freeze metadata %s" % [id, field])

func _validate_demo() -> void:
	var payload: Dictionary = _payload(_load_json("res://content/demo/public_demo_mapping.json"))
	var species: Dictionary = payload.get("species", {})
	_expect_equal(species.get("documented", []), ["O01","O02","O03","O04","O06","O07","O08","O10","O14"], "demo documented species are exact 9")
	_expect_equal(species.get("bounded_discovery", []), ["O13"], "demo discovery species is exactly O13")
	_expect_equal(payload.get("support_ids", []), ["S01","S02","S03","S05"], "demo supports are exact four")
	_expect_equal(payload.get("hold_ids", []), ["H01","H02","H04"], "demo holds are exact three")
	_expect_equal(payload.get("hold_family_ids", []), ["HF1","HF2"], "demo uses exactly two hold families")
	_expect_equal(payload.get("hazard_family_ids", []), ["RH1","RH2","RH3"], "demo hazards are exact three")
	_expect_equal(int(payload.get("authored_contract_count", -1)), 10, "demo has 10 authored contracts")
	_expect_equal(payload.get("challenge_template_ids", []), ["G01","G02","G03"], "demo has exactly three Challenge mappings")
	_expect_equal(payload.get("discovery_contract_ids", []), ["D09"], "demo has exactly one discovery contract")
	var contracts: Array = payload.get("contracts", [])
	_expect_equal(contracts.size(), 10, "demo D01-D10 payload count")
	var dynamic_count: int = 0
	for index: int in range(contracts.size()):
		var contract: Dictionary = contracts[index]
		var id: String = "D%02d" % (index + 1)
		_expect_equal(String(contract.get("id", "")), id, "demo contract sequence %s" % id)
		if bool(contract.get("bronze_relevant_post_launch_change", false)):
			dynamic_count += 1
		if index == 2:
			_expect_true(bool(contract.get("bronze_relevant_post_launch_change", false)), "D03 identity gate")
		if index == 8:
			_expect_true(bool(contract.get("discovery", false)), "D09 discovery contract")
			_expect_equal(String(contract.get("discovery_species_id", "")), "O13", "D09 discovery species")
	_expect_true(dynamic_count >= 5, "at least 5/10 demo contracts are dynamically Bronze-relevant")
	var transfer: Dictionary = payload.get("transfer", {})
	_expect_true(bool(transfer.get("settings", false)) and bool(transfer.get("documented_knowledge", false)), "demo settings/knowledge transfer")
	_expect_true(bool(transfer.get("monotonic", false)) and bool(transfer.get("idempotent", false)), "demo import monotonic/idempotent")
	_expect_true(not bool(transfer.get("D09_D10_clear_C09_plus", true)), "D09/D10 never clear C09+")
	_expect_true(not bool(transfer.get("mechanical_power", true)), "demo transfers no mechanical power")
	_expect_equal(String(transfer.get("challenge_unlock_requires", "")), "Bronze(C16)", "demo cannot unlock Challenges early")
	var mapping: Dictionary = transfer.get("bronze_mapping", {})
	_expect_equal(mapping.size(), 8, "demo Bronze mapping has exactly D01-D08")
	for number: int in range(1, 9):
		_expect_equal(String(mapping.get("D%02d" % number, "")), "C%02d" % number, "demo mapping %d" % number)

func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("invalid JSON document: %s" % path)
		return {}
	return parsed

func _payload(root: Dictionary) -> Dictionary:
	var value: Variant = root.get("payload", {})
	return value if value is Dictionary else {}

func _definitions(root: Dictionary) -> Array:
	var value: Variant = _payload(root).get("definitions", [])
	return value if value is Array else []

func _expect_true(value: bool, label: String) -> void:
	if not value:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	failures += 1
	push_error("FAIL: %s" % message)
