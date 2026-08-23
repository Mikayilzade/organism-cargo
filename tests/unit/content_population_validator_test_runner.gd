extends SceneTree

const ContentPopulationValidatorScript := preload("res://src/content/content_population_validator.gd")

var failures: int = 0

func _init() -> void:
	_test_frozen_launch_population_accepts()
	_test_species_ceiling_rejects_overflow()
	_test_species_canon_rejects_drift()
	_test_campaign_graph_is_exact()
	_test_challenge_dynamic_gate_is_required()
	_test_demo_freeze_is_exact()
	if failures == 0:
		print("content_population_validator_test_runner: PASS")
		quit(0)
	else:
		push_error("content_population_validator_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_frozen_launch_population_accepts() -> void:
	var validator: ContentPopulationValidator = ContentPopulationValidatorScript.new()
	var result: Dictionary = validator.validate_launch_population(_valid_population())
	_expect_true(bool(result.get("ok", false)), "frozen launch population validates")
	if bool(result.get("ok", false)):
		_expect_equal(int(result.get("species_count", 0)), 22, "launch roster ceiling fixture contains 22 species")
		_expect_equal(int(result.get("support_count", 0)), 6, "launch support roster is exact")
		_expect_equal(int(result.get("campaign_count", 0)), 48, "campaign graph is exact")

func _test_species_ceiling_rejects_overflow() -> void:
	var population: Dictionary = _valid_population()
	var species: Array = (population["species"] as Array).duplicate(true)
	species.append({"id":"O23","name":"Forbidden overflow","body_plan_id":"B01","trait_ids":["T01"],"stress_profile":"Standard","contamination_profile":"Standard","tier_min":1,"tier_max":6,"readability":"fixture","special":{}})
	population["species"] = species
	var result: Dictionary = ContentPopulationValidatorScript.new().validate_launch_population(population)
	_expect_true(not bool(result.get("ok", true)), "23rd launch species is rejected")

func _test_species_canon_rejects_drift() -> void:
	var population: Dictionary = _valid_population()
	var species: Array = (population["species"] as Array).duplicate(true)
	var o01_value: Variant = species[0]
	if not o01_value is Dictionary:
		_expect_true(false, "O01 fixture is dictionary")
		return
	var o01: Dictionary = o01_value
	o01["trait_ids"] = ["T02"]
	species[0] = o01
	population["species"] = species
	var result: Dictionary = ContentPopulationValidatorScript.new().validate_launch_population(population)
	_expect_equal(String(result.get("error", "")), "species_trait_mismatch:O01", "frozen O01 trait identity cannot drift")

func _test_campaign_graph_is_exact() -> void:
	var population: Dictionary = _valid_population()
	var campaign: Array = (population["campaign"] as Array).duplicate(true)
	var c16_value: Variant = campaign[15]
	if not c16_value is Dictionary:
		_expect_true(false, "C16 fixture is dictionary")
		return
	var c16: Dictionary = c16_value
	c16["prerequisites"] = ["C15"]
	campaign[15] = c16
	population["campaign"] = campaign
	var result: Dictionary = ContentPopulationValidatorScript.new().validate_launch_population(population)
	_expect_equal(String(result.get("error", "")), "campaign_prerequisite_mismatch:C16", "C16 cannot drop C14 prerequisite")

func _test_challenge_dynamic_gate_is_required() -> void:
	var population: Dictionary = _valid_population()
	var challenges: Array = (population["challenges"] as Array).duplicate(true)
	var challenge_value: Variant = challenges[0]
	if not challenge_value is Dictionary:
		_expect_true(false, "challenge fixture is dictionary")
		return
	var challenge: Dictionary = challenge_value
	challenge["dynamic_significance"] = false
	challenges[0] = challenge
	population["challenges"] = challenges
	var result: Dictionary = ContentPopulationValidatorScript.new().validate_launch_population(population)
	_expect_equal(String(result.get("error", "")), "challenge_missing_dynamic_significance:G01", "static challenge template is rejected")

func _test_demo_freeze_is_exact() -> void:
	var population: Dictionary = _valid_population()
	var demo_value: Variant = population["demo"]
	if not demo_value is Dictionary:
		_expect_true(false, "demo fixture is dictionary")
		return
	var demo: Dictionary = demo_value
	demo["documented_species"] = 8
	demo["discovery_species"] = 2
	population["demo"] = demo
	var result: Dictionary = ContentPopulationValidatorScript.new().validate_launch_population(population)
	_expect_equal(String(result.get("error", "")), "demo_species_split_mismatch", "obsolete 8+2 demo split is rejected")

func _valid_population() -> Dictionary:
	var species: Array = []
	for number: int in range(1, 23):
		var species_id: String = "O%02d" % number
		var canon_value: Variant = ContentPopulationValidatorScript.SPECIES_CANON[species_id]
		if not canon_value is Dictionary:
			continue
		var canon: Dictionary = canon_value
		var traits_value: Variant = canon.get("trait_ids", [])
		var traits: Array = []
		if traits_value is Array or traits_value is PackedStringArray:
			for raw_trait: Variant in traits_value:
				traits.append(String(raw_trait))
		var special: Dictionary = {}
		if "T10" in traits:
			special["bounded_t10"] = {"finite_guard_required": true}
		if "T08" in traits:
			special["growth"] = {"fixture_contract": true}
		if species_id == "O21":
			special["bounded_t10"] = {"finite_guard_required": true, "guard": "once_per_episode"}
		species.append({"id":species_id,"name":"Fixture %s" % species_id,"body_plan_id":String(canon.get("body_plan_id", "")),"trait_ids":traits,"stress_profile":String(canon.get("stress_profile", "")),"contamination_profile":String(canon.get("contamination_profile", "")),"tier_min":1,"tier_max":6,"readability":"fixture readability","special":special})
	var supports: Array = [
		{"id":"S01","name":"Cooler","family":"S01","semantics":{}},
		{"id":"S02","name":"Filter","family":"S02","semantics":{}},
		{"id":"S03","name":"Baffle","family":"S03","semantics":{}},
		{"id":"S04","name":"Nest Pad","family":"S04","semantics":{"target_capacity":1}},
		{"id":"S05","name":"Feed Cartridge","family":"S05","semantics":{"finite_conserved_reserve":true}},
		{"id":"S06","name":"Monitor Beacon","family":"S06","information_only":true,"semantics":{"direct_mitigation":false}},
	]
	var campaign: Array = []
	for number: int in range(1, 49):
		var contract_id: String = "C%02d" % number
		var prerequisites_value: Variant = ContentPopulationValidatorScript.CAMPAIGN_PREREQUISITES[contract_id]
		var prerequisites: Array = []
		if prerequisites_value is Array:
			prerequisites = prerequisites_value.duplicate()
		campaign.append({"id":contract_id,"prerequisites":prerequisites,"has_dynamic_post_launch_change":number >= 5})
	var challenges: Array = [
		{"id":"G01","certified_bronze_solution":true,"dynamic_significance":true,"static_t0_solution_only":false},
		{"id":"G02","certified_bronze_solution":true,"dynamic_significance":true,"static_t0_solution_only":false},
		{"id":"G03","certified_bronze_solution":true,"dynamic_significance":true,"static_t0_solution_only":false},
	]
	return {"species":species,"supports":supports,"campaign":campaign,"challenges":challenges,"demo":{"species_total":10,"documented_species":9,"discovery_species":1,"support_ids":["S01","S02","S03","S05"],"authored_contracts":10,"challenge_templates":3,"discovery_contracts":1}}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
