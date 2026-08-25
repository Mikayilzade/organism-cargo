extends SceneTree

const ValidatorScript := preload("res://src/content/authored_content_adversarial_validator.gd")
const CONTRACT_PATHS: Array[String] = [
	"res://content/contracts/campaign_chapter3_batch_01.json",
	"res://content/contracts/campaign_chapter4_batch_01.json",
	"res://content/contracts/campaign_chapter5_batch_01.json",
	"res://content/contracts/campaign_chapter6_batch_01.json",
]
const CHALLENGE_PATH := "res://content/challenges/launch_challenge_templates.json"

var failures: int = 0

func _init() -> void:
	_test_current_authored_content_resists_objective_dominance_gates()
	_test_cooler_filter_upper_bound_fails_closed()
	_test_maximum_spacing_and_growth_corner_gates_fail_closed()
	_test_support_and_helper_counterexamples_fail_closed()
	_test_generated_challenge_dominance_guards_fail_closed()
	if failures == 0:
		print("phase12f_authored_content_dominance_adversarial_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12f_authored_content_dominance_adversarial_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_current_authored_content_resists_objective_dominance_gates() -> void:
	var validator: AuthoredContentAdversarialValidator = ValidatorScript.new()
	var result: Dictionary = validator.validate(_campaign(), _challenge_document())
	_expect(bool(result.get("ok", false)), "current C17-C48 and generated challenge population pass objective anti-dominance gates")
	if not bool(result.get("ok", false)):
		return
	var campaign_metrics: Dictionary = _dict(result.get("campaign_metrics", {}))
	_expect_equal(int(campaign_metrics.get("cooler_filter_joint_availability_upper_bound", -1)), 1, "only one current authored contract jointly exposes Cooler+Filter, safely below the certified-primary ceiling")
	_expect_equal(_dict(campaign_metrics.get("maximum_spacing_counterexamples_by_chapter", {})), {3: 5, 4: 5, 5: 6, 6: 8}, "authored campaign contains chapter-wide maximum-spacing counterexamples")
	_expect_equal(_dict(campaign_metrics.get("growth_corner_counterexamples_by_chapter", {})).get(3), 3, "Chapter 3 has multiple permanent-growth-corner counterexamples")
	_expect_equal(_dict(campaign_metrics.get("growth_corner_counterexamples_by_chapter", {})).get(4), 1, "Chapter 4 has required permanent-growth-corner counterexample")
	_expect_equal(_dict(campaign_metrics.get("growth_corner_counterexamples_by_chapter", {})).get(6), 4, "Chapter 6 has multiple permanent-growth-corner counterexamples")
	_expect_equal(_dict(campaign_metrics.get("cooler_filter_inferior_counterexamples_by_chapter", {})), {3: 1, 4: 3, 5: 1, 6: 2}, "each Chapter 3-6 has explicit Cooler/Filter-inferior evidence")
	var gaps: Array = _array(result.get("diagnostic_gaps", []))
	_expect("authored_primary_bronze_role_zone_normalization_requires_certified_solution_geometry" in gaps, "role-to-zone gate is honestly retained as a geometry-certificate gap rather than guessed")
	_expect("isolation_ratio_and_beneficial_relation_count_require_certified_bronze_solution_geometry" in gaps, "quantitative isolation gate is retained as a solution-certificate gap")
	_expect("species_redundancy_preference_threshold_requires_representative_solution_or_playtest_evidence" in gaps, "70 percent species redundancy gate is retained as empirical evidence rather than invented scoring")

func _test_cooler_filter_upper_bound_fails_closed() -> void:
	var hostile: Array = _campaign()
	for index: int in range(9):
		var contract: Dictionary = _dict(hostile[index]).duplicate(true)
		contract["support_ids"] = ["S01", "S02"]
		contract["cooler_or_filter_inferior"] = true
		contract["inferior_support_reason"] = "hostile fixture keeps classification explicit"
		hostile[index] = contract
	var result: Dictionary = ValidatorScript.new().validate(hostile, _challenge_document())
	_expect(not bool(result.get("ok", true)), "more than eight jointly available Cooler+Filter authored contracts fail conservatively")
	_expect_equal(String(result.get("error", "")), "cooler_filter_joint_availability_upper_bound_exceeded:9", "Cooler+Filter ceiling attack has stable diagnosis")

func _test_maximum_spacing_and_growth_corner_gates_fail_closed() -> void:
	var spacing_attack: Array = _campaign()
	for index: int in range(8):
		var contract: Dictionary = _dict(spacing_attack[index]).duplicate(true)
		contract["maximum_spacing_inferior"] = false
		spacing_attack[index] = contract
	var spacing_result: Dictionary = ValidatorScript.new().validate(spacing_attack, _challenge_document())
	_expect(not bool(spacing_result.get("ok", true)), "Chapter 3 pure maximum-spacing regression fails")
	_expect_equal(String(spacing_result.get("error", "")), "maximum_spacing_counterexample_shortage:chapter3", "maximum-spacing regression is chapter-scoped")

	var growth_attack: Array = _campaign()
	for index: int in range(24, 32):
		var contract: Dictionary = _dict(growth_attack[index]).duplicate(true)
		contract["growth_reserve_edge_inferior"] = false
		growth_attack[index] = contract
	var growth_result: Dictionary = ValidatorScript.new().validate(growth_attack, _challenge_document())
	_expect(not bool(growth_result.get("ok", true)), "removing Chapter 6 permanent-growth-corner counterexamples fails")
	_expect_equal(String(growth_result.get("error", "")), "growth_corner_counterexample_shortage:chapter6", "growth-corner regression is chapter-scoped")

func _test_support_and_helper_counterexamples_fail_closed() -> void:
	var support_attack: Array = _campaign()
	for index: int in range(16, 24):
		var contract: Dictionary = _dict(support_attack[index]).duplicate(true)
		contract["cooler_or_filter_inferior"] = false
		contract["filter_inferior"] = false
		support_attack[index] = contract
	var support_result: Dictionary = ValidatorScript.new().validate(support_attack, _challenge_document())
	_expect(not bool(support_result.get("ok", true)), "Chapter 5 without an explicit Cooler/Filter-inferior case fails")
	_expect_equal(String(support_result.get("error", "")), "cooler_filter_inferior_counterexample_missing:chapter5", "support-dominance regression identifies missing chapter counterexample")

	var helper_attack: Array = _campaign()
	for index: int in range(8, 16):
		var contract: Dictionary = _dict(helper_attack[index]).duplicate(true)
		contract["helper_protector_downside"] = false
		contract["familiar_helper_inferior"] = false
		contract["universal_helper_solution_forbidden"] = false
		contract["anti_template_helper_liability"] = false
		helper_attack[index] = contract
	var helper_result: Dictionary = ValidatorScript.new().validate(helper_attack, _challenge_document())
	_expect(not bool(helper_result.get("ok", true)), "Chapter 4 without helper/protector downside evidence fails")
	_expect_equal(String(helper_result.get("error", "")), "helper_protector_counterexample_missing:chapter4", "helper/protector regression identifies missing chapter counterexample")

func _test_generated_challenge_dominance_guards_fail_closed() -> void:
	var spacing_policy_attack: Dictionary = _challenge_document()
	var spacing_payload: Dictionary = _dict(spacing_policy_attack.get("payload", {})).duplicate(true)
	var spacing_policy: Dictionary = _dict(spacing_payload.get("validation_policy", {})).duplicate(true)
	spacing_policy["pure_maximum_spacing_best"] = true
	spacing_payload["validation_policy"] = spacing_policy
	spacing_policy_attack["payload"] = spacing_payload
	var spacing_result: Dictionary = ValidatorScript.new().validate(_campaign(), spacing_policy_attack)
	_expect(not bool(spacing_result.get("ok", true)), "generated challenge policy cannot allow pure maximum-spacing best solution")
	_expect_equal(String(spacing_result.get("error", "")), "challenge_pure_maximum_spacing_policy_forbidden", "generated spacing policy regression is explicit")

	var pair_attack: Dictionary = _challenge_document()
	var pair_payload: Dictionary = _dict(pair_attack.get("payload", {})).duplicate(true)
	var pair_defs: Array = _array(pair_payload.get("definitions", [])).duplicate(true)
	for index: int in range(4):
		var definition: Dictionary = _dict(pair_defs[index]).duplicate(true)
		definition["supports"] = ["S01", "S02"]
		pair_defs[index] = definition
	pair_payload["definitions"] = pair_defs
	pair_attack["payload"] = pair_payload
	var pair_result: Dictionary = ValidatorScript.new().validate(_campaign(), pair_attack)
	_expect(not bool(pair_result.get("ok", true)), "four consecutive identical powered pairs fail the frozen anti-streak gate")
	_expect(String(pair_result.get("error", "")).begins_with("challenge_powered_pair_streak_exceeded:"), "powered pair anti-streak attack has stable diagnostic family")

	var helper_attack: Dictionary = _challenge_document()
	var helper_payload: Dictionary = _dict(helper_attack.get("payload", {})).duplicate(true)
	var helper_defs: Array = _array(helper_payload.get("definitions", [])).duplicate(true)
	for index: int in range(4):
		var definition: Dictionary = _dict(helper_defs[index]).duplicate(true)
		definition["species"] = ["O02", "O01", "O10"]
		definition["family"] = "hostile_repeated_soother"
		definition["fingerprint"] = "HF1|zone-hostile|soother-center"
		definition["supports"] = ["S03"]
		definition["similarity"] = 0.5
		helper_defs[index] = definition
	helper_payload["definitions"] = helper_defs
	helper_attack["payload"] = helper_payload
	var helper_result: Dictionary = ValidatorScript.new().validate(_campaign(), helper_attack)
	_expect(not bool(helper_result.get("ok", true)), "same soother in the same generated topology role more than three times fails")
	_expect_equal(String(helper_result.get("error", "")), "challenge_repeated_soother_role_exceeded:O02", "repeated helper role attack identifies the repeated soother")

func _campaign() -> Array:
	var result: Array = []
	for path: String in CONTRACT_PATHS:
		var document: Dictionary = _load_document(path)
		var payload: Dictionary = _dict(document.get("payload", {}))
		for raw_definition: Variant in _array(payload.get("definitions", [])):
			if raw_definition is Dictionary:
				result.append((raw_definition as Dictionary).duplicate(true))
	return result

func _challenge_document() -> Dictionary:
	return _load_document(CHALLENGE_PATH).duplicate(true)

func _load_document(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _array(value: Variant) -> Array:
	return value if value is Array else []

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
