class_name AuthoredContentAdversarialValidator
extends RefCounted

const REQUIRED_IDS: Array[String] = [
	"C17", "C18", "C19", "C20", "C21", "C22", "C23", "C24",
	"C25", "C26", "C27", "C28", "C29", "C30", "C31", "C32",
	"C33", "C34", "C35", "C36", "C37", "C38", "C39", "C40",
	"C41", "C42", "C43", "C44", "C45", "C46", "C47", "C48",
]
const POWERED_SUPPORT_IDS: Array[String] = ["S01", "S02", "S06"]
const SOOTHER_IDS: Array[String] = ["O02", "O12", "O16"]
const COOLER_FILTER_LIMIT: int = 8

func validate(campaign: Array, challenge_document: Dictionary) -> Dictionary:
	var campaign_result: Dictionary = _validate_campaign_dominance(campaign)
	if not bool(campaign_result.get("ok", false)):
		return campaign_result
	var challenge_result: Dictionary = _validate_challenge_dominance(challenge_document)
	if not bool(challenge_result.get("ok", false)):
		return challenge_result
	return {
		"ok": true,
		"error": "",
		"campaign_metrics": campaign_result.get("metrics", {}).duplicate(true),
		"challenge_metrics": challenge_result.get("metrics", {}).duplicate(true),
		"diagnostic_gaps": [
			"authored_primary_bronze_role_zone_normalization_requires_certified_solution_geometry",
			"isolation_ratio_and_beneficial_relation_count_require_certified_bronze_solution_geometry",
			"species_redundancy_preference_threshold_requires_representative_solution_or_playtest_evidence",
		],
	}

func _validate_campaign_dominance(campaign: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for raw_contract: Variant in campaign:
		if not raw_contract is Dictionary:
			return _failure("invalid_authored_contract")
		var contract: Dictionary = raw_contract
		var contract_id: String = String(contract.get("id", ""))
		if contract_id not in REQUIRED_IDS or by_id.has(contract_id):
			return _failure("invalid_authored_contract_id:%s" % contract_id)
		by_id[contract_id] = contract
	if by_id.size() != REQUIRED_IDS.size():
		return _failure("incomplete_authored_dominance_set:%d" % by_id.size())
	for contract_id: String in REQUIRED_IDS:
		if not by_id.has(contract_id):
			return _failure("missing_authored_dominance_contract:%s" % contract_id)

	var maximum_spacing_by_chapter: Dictionary = {3: 0, 4: 0, 5: 0, 6: 0}
	var growth_corner_by_chapter: Dictionary = {3: 0, 4: 0, 5: 0, 6: 0}
	var support_inferior_by_chapter: Dictionary = {3: 0, 4: 0, 5: 0, 6: 0}
	var helper_counterexamples_by_chapter: Dictionary = {3: 0, 4: 0, 5: 0, 6: 0}
	var cooler_filter_joint_availability: int = 0

	for contract_id: String in REQUIRED_IDS:
		var contract: Dictionary = by_id[contract_id]
		var chapter: int = _chapter_for_contract(contract_id)
		if bool(contract.get("maximum_spacing_inferior", false)):
			maximum_spacing_by_chapter[chapter] = int(maximum_spacing_by_chapter[chapter]) + 1
		if bool(contract.get("growth_reserve_edge_inferior", false)):
			growth_corner_by_chapter[chapter] = int(growth_corner_by_chapter[chapter]) + 1
		if _has_support_inferior_evidence(contract):
			support_inferior_by_chapter[chapter] = int(support_inferior_by_chapter[chapter]) + 1
		if _has_helper_counterexample(contract):
			helper_counterexamples_by_chapter[chapter] = int(helper_counterexamples_by_chapter[chapter]) + 1

		var supports: PackedStringArray = _strings(contract.get("support_ids", []))
		if "S01" in supports and "S02" in supports:
			cooler_filter_joint_availability += 1

	# Joint availability is a conservative upper bound on certified-primary dependence.
	# If the pair is not jointly available, it cannot be a certified primary pair.
	if cooler_filter_joint_availability > COOLER_FILTER_LIMIT:
		return _failure("cooler_filter_joint_availability_upper_bound_exceeded:%d" % cooler_filter_joint_availability)

	for chapter: int in [3, 4, 5, 6]:
		if int(maximum_spacing_by_chapter[chapter]) < 2:
			return _failure("maximum_spacing_counterexample_shortage:chapter%d" % chapter)
		if int(support_inferior_by_chapter[chapter]) < 1:
			return _failure("cooler_filter_inferior_counterexample_missing:chapter%d" % chapter)
	for chapter: int in [4, 5, 6]:
		if int(helper_counterexamples_by_chapter[chapter]) < 1:
			return _failure("helper_protector_counterexample_missing:chapter%d" % chapter)
	if int(growth_corner_by_chapter[3]) < 1:
		return _failure("growth_corner_counterexample_shortage:chapter3")
	if int(growth_corner_by_chapter[4]) < 1:
		return _failure("growth_corner_counterexample_shortage:chapter4")
	if int(growth_corner_by_chapter[6]) < 2:
		return _failure("growth_corner_counterexample_shortage:chapter6")

	return {
		"ok": true,
		"error": "",
		"metrics": {
			"cooler_filter_joint_availability_upper_bound": cooler_filter_joint_availability,
			"maximum_spacing_counterexamples_by_chapter": maximum_spacing_by_chapter.duplicate(true),
			"growth_corner_counterexamples_by_chapter": growth_corner_by_chapter.duplicate(true),
			"cooler_filter_inferior_counterexamples_by_chapter": support_inferior_by_chapter.duplicate(true),
			"helper_protector_counterexamples_by_chapter": helper_counterexamples_by_chapter.duplicate(true),
		},
	}

func _validate_challenge_dominance(challenge_document: Dictionary) -> Dictionary:
	var payload_value: Variant = challenge_document.get("payload", {})
	if not payload_value is Dictionary:
		return _failure("invalid_challenge_payload")
	var payload: Dictionary = payload_value
	var policy_value: Variant = payload.get("validation_policy", {})
	if not policy_value is Dictionary:
		return _failure("missing_challenge_validation_policy")
	var policy: Dictionary = policy_value
	if bool(policy.get("pure_maximum_spacing_best", true)):
		return _failure("challenge_pure_maximum_spacing_policy_forbidden")
	var max_pair_streak: int = int(policy.get("max_consecutive_same_powered_pair", 0))
	if max_pair_streak <= 0 or max_pair_streak > 3:
		return _failure("invalid_powered_pair_streak_policy:%d" % max_pair_streak)
	var max_similarity: float = float(policy.get("max_recent_similarity", -1.0))
	if max_similarity <= 0.0 or max_similarity > 1.0:
		return _failure("invalid_similarity_policy")

	var definitions_value: Variant = payload.get("definitions", [])
	if not definitions_value is Array:
		return _failure("invalid_challenge_definitions")
	var definitions: Array = definitions_value
	if definitions.size() != 24:
		return _failure("invalid_challenge_dominance_population:%d" % definitions.size())

	var previous_pair: String = ""
	var current_pair_streak: int = 0
	var largest_pair_streak: int = 0
	var helper_role_counts: Dictionary = {}
	for index: int in range(definitions.size()):
		var raw_definition: Variant = definitions[index]
		if not raw_definition is Dictionary:
			return _failure("invalid_challenge_definition:%d" % index)
		var definition: Dictionary = raw_definition
		var challenge_id: String = String(definition.get("id", ""))
		if challenge_id.is_empty():
			return _failure("missing_challenge_id:%d" % index)
		if not bool(definition.get("dynamic", false)) or bool(definition.get("static_t0", true)):
			return _failure("challenge_dynamic_significance_lost:%s" % challenge_id)
		if not bool(definition.get("timing_matters", false)):
			return _failure("challenge_timing_not_material:%s" % challenge_id)
		if float(definition.get("similarity", 2.0)) > max_similarity:
			return _failure("challenge_similarity_policy_exceeded:%s" % challenge_id)
		var fingerprint: String = String(definition.get("fingerprint", ""))
		if fingerprint.is_empty():
			return _failure("missing_challenge_fingerprint:%s" % challenge_id)

		var pair_key: String = _powered_pair_key(definition.get("supports", []))
		if not pair_key.is_empty() and pair_key == previous_pair:
			current_pair_streak += 1
		elif not pair_key.is_empty():
			previous_pair = pair_key
			current_pair_streak = 1
		else:
			previous_pair = ""
			current_pair_streak = 0
		largest_pair_streak = maxi(largest_pair_streak, current_pair_streak)
		if current_pair_streak > max_pair_streak:
			return _failure("challenge_powered_pair_streak_exceeded:%s" % challenge_id)

		var family: String = String(definition.get("family", ""))
		var species: PackedStringArray = _strings(definition.get("species", []))
		for soother_id: String in SOOTHER_IDS:
			if soother_id in species:
				var role_key: String = "%s|%s|%s" % [soother_id, family, fingerprint]
				helper_role_counts[role_key] = int(helper_role_counts.get(role_key, 0)) + 1
				if int(helper_role_counts[role_key]) > 3:
					return _failure("challenge_repeated_soother_role_exceeded:%s" % soother_id)

	return {
		"ok": true,
		"error": "",
		"metrics": {
			"challenge_count": definitions.size(),
			"largest_consecutive_powered_pair_streak": largest_pair_streak,
			"exact_soother_role_keys": helper_role_counts.size(),
		},
	}

func _has_support_inferior_evidence(contract: Dictionary) -> bool:
	if bool(contract.get("cooler_or_filter_inferior", false)):
		return not String(contract.get("inferior_support_reason", "")).strip_edges().is_empty()
	if bool(contract.get("filter_inferior", false)):
		return not String(contract.get("filter_inferior_reason", "")).strip_edges().is_empty()
	return false

func _has_helper_counterexample(contract: Dictionary) -> bool:
	return bool(contract.get("helper_protector_downside", false)) \
		or bool(contract.get("familiar_helper_inferior", false)) \
		or bool(contract.get("universal_helper_solution_forbidden", false)) \
		or bool(contract.get("anti_template_helper_liability", false))

func _powered_pair_key(value: Variant) -> String:
	var support_ids: PackedStringArray = _strings(value)
	var powered: PackedStringArray = PackedStringArray()
	for support_id: String in support_ids:
		if support_id in POWERED_SUPPORT_IDS:
			powered.append(support_id)
	powered.sort()
	if powered.size() < 2:
		return ""
	return "+".join(powered)

func _strings(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is Array or value is PackedStringArray:
		for raw_value: Variant in value:
			result.append(String(raw_value))
	result.sort()
	return result

func _chapter_for_contract(contract_id: String) -> int:
	var number: int = int(contract_id.substr(1))
	if number <= 24:
		return 3
	if number <= 32:
		return 4
	if number <= 40:
		return 5
	return 6

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
