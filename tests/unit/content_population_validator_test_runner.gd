extends SceneTree

const ContentPopulationValidatorScript := preload("res://src/content/content_population_validator.gd")

var failures: int = 0

func _init() -> void:
	_test_frozen_launch_population_accepts()
	_test_species_ceiling_rejects_overflow()
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
	species.append({
		"id": "O23",
		"body_plan": "B01",
		"traits": ["T01"],
		"stress_profile": "Standard",
		"contamination_profile": "Standard",
	})
	population["species"] = species
	var result: Dictionary = ContentPopulationValidatorScript.new().validate_launch_population(population)
	_expect_true(not bool(result.get("ok", true)), "23rd launch species is rejected")

func _test_campaign_graph_is_exact() -> void:
	var population: Dictionary = _valid_population()
	var campaign: Array = (population["campaign"] as Array).duplicate(true)
	var c16: Dictionary = campaign[15]
	c16["prerequisites"] = ["C15"]
	campaign[15] = c16
	population["campaign"] = campaign
	var result: Dictionary = ContentPopulationValidatorScript.new().validate_launch_population(population)
	_expect_equal(String(result.get("error", "")), "campaign_prerequisite_mismatch:C16", "C16 cannot drop C14 prerequisite")

func _test_challenge_dynamic_gate_is_required() -> void:
	var population: Dictionary = _valid_population()
	var challenges: Array = (population["challenges"] as Array).duplicate(true)
	var challenge: Dictionary = challenges[0]
	challenge["dynamic_significance"] = false
	challenges[0] = challenge
	population["challenges"] = challenges
	var result: Dictionary = ContentPopulationValidatorScript.new().validate_launch_population(population)
	_expect_equal(String(result.get("error", "")), "challenge_missing_dynamic_significance:G01", "static challenge template is rejected")

func _test_demo_freeze_is_exact() -> void:
	var population: Dictionary = _valid_population()
	var demo: Dictionary = (population["demo"] as Dictionary).duplicate(true)
	demo["documented_species"] = 8
	demo["discovery_species"] = 2
	population["demo"] = demo
	var result: Dictionary = ContentPopulationValidatorScript.new().validate_launch_population(population)
	_expect_equal(String(result.get("error", "")), "demo_species_split_mismatch", "obsolete 8+2 demo split is rejected")

func _valid_population() -> Dictionary:
	var species: Array = []
	for number: int in range(1, 23):
		species.append({
			"id": "O%02d" % number,
			"body_plan": ["B01", "B02", "B03", "B04"][(number - 1) % 4],
			"traits": ["T%02d" % (((number - 1) % 10) + 1)],
			"stress_profile": "Standard",
			"contamination_profile": "Standard",
		})
	var supports: Array = []
	for number: int in range(1, 7):
		var support_id: String = "S%02d" % number
		supports.append({"id": support_id, "family": support_id})
	var campaign: Array = []
	for number: int in range(1, 49):
		var contract_id: String = "C%02d" % number
		var prerequisites: Array = ContentPopulationValidatorScript.CAMPAIGN_PREREQUISITES[contract_id]
		campaign.append({
			"id": contract_id,
			"prerequisites": prerequisites.duplicate(),
			"has_dynamic_post_launch_change": number >= 5,
		})
	var challenges: Array = [
		{"id": "G01", "certified_bronze_solution": true, "dynamic_significance": true, "static_t0_solution_only": false},
		{"id": "G02", "certified_bronze_solution": true, "dynamic_significance": true, "static_t0_solution_only": false},
		{"id": "G03", "certified_bronze_solution": true, "dynamic_significance": true, "static_t0_solution_only": false},
	]
	return {
		"species": species,
		"supports": supports,
		"campaign": campaign,
		"challenges": challenges,
		"demo": {
			"species_total": 10,
			"documented_species": 9,
			"discovery_species": 1,
			"support_ids": ["S01", "S02", "S03", "S05"],
			"authored_contracts": 10,
			"challenge_templates": 3,
			"discovery_contracts": 1,
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
