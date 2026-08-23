class_name ContentPopulationValidator
extends RefCounted

const SPECIES_MAX: int = 22
const SUPPORT_IDS := PackedStringArray(["S01", "S02", "S03", "S04", "S05", "S06"])
const DEMO_SUPPORT_IDS := PackedStringArray(["S01", "S02", "S03", "S05"])
const TRAIT_IDS := PackedStringArray(["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08", "T09", "T10"])
const STRESS_PROFILES := PackedStringArray(["Hardy", "Standard", "Sensitive"])
const CONTAMINATION_PROFILES := PackedStringArray(["Resistant", "Standard", "Vulnerable"])
const CAMPAIGN_IDS := PackedStringArray([
	"C01", "C02", "C03", "C04", "C05", "C06", "C07", "C08",
	"C09", "C10", "C11", "C12", "C13", "C14", "C15", "C16",
	"C17", "C18", "C19", "C20", "C21", "C22", "C23", "C24",
	"C25", "C26", "C27", "C28", "C29", "C30", "C31", "C32",
	"C33", "C34", "C35", "C36", "C37", "C38", "C39", "C40",
	"C41", "C42", "C43", "C44", "C45", "C46", "C47", "C48",
])
const CAMPAIGN_PREREQUISITES := {
	"C01": [], "C02": ["C01"], "C03": ["C01"], "C04": ["C02"],
	"C05": ["C03"], "C06": ["C04"], "C07": ["C05", "C06"], "C08": ["C07"],
	"C09": ["C08"], "C10": ["C08"], "C11": ["C09", "C10"], "C12": ["C11"],
	"C13": ["C11"], "C14": ["C12", "C13"], "C15": ["C14"], "C16": ["C14", "C15"],
	"C17": ["C16"], "C18": ["C16"], "C19": ["C17", "C18"], "C20": ["C17"],
	"C21": ["C20"], "C22": ["C18", "C19"], "C23": ["C20", "C21"], "C24": ["C22", "C23"],
	"C25": ["C24"], "C26": ["C24"], "C27": ["C25"], "C28": ["C26"],
	"C29": ["C27", "C28"], "C30": ["C29"], "C31": ["C29"], "C32": ["C30", "C31"],
	"C33": ["C32"], "C34": ["C33"], "C35": ["C34"], "C36": ["C33"],
	"C37": ["C36"], "C38": ["C35", "C37"], "C39": ["C38"], "C40": ["C39"],
	"C41": ["C40"], "C42": ["C40"], "C43": ["C41", "C42"], "C44": ["C43"],
	"C45": ["C43"], "C46": ["C44", "C45"], "C47": ["C46"], "C48": ["C47"],
}
const SPECIES_CANON := {
	"O01": {"body_plan_id": "B01", "trait_ids": ["T01", "T03"], "stress_profile": "Standard", "contamination_profile": "Standard"},
	"O02": {"body_plan_id": "B01", "trait_ids": ["T04"], "stress_profile": "Sensitive", "contamination_profile": "Standard"},
	"O03": {"body_plan_id": "B01", "trait_ids": ["T06", "T08"], "stress_profile": "Standard", "contamination_profile": "Resistant"},
	"O04": {"body_plan_id": "B01", "trait_ids": ["T05", "T10"], "stress_profile": "Hardy", "contamination_profile": "Standard"},
	"O05": {"body_plan_id": "B02", "trait_ids": ["T01", "T09"], "stress_profile": "Hardy", "contamination_profile": "Resistant"},
	"O06": {"body_plan_id": "B01", "trait_ids": ["T04", "T07"], "stress_profile": "Sensitive", "contamination_profile": "Resistant"},
	"O07": {"body_plan_id": "B01", "trait_ids": ["T03", "T10"], "stress_profile": "Sensitive", "contamination_profile": "Standard"},
	"O08": {"body_plan_id": "B01", "trait_ids": ["T07", "T08"], "stress_profile": "Sensitive", "contamination_profile": "Vulnerable"},
	"O09": {"body_plan_id": "B02", "trait_ids": ["T02", "T06", "T10"], "stress_profile": "Hardy", "contamination_profile": "Resistant"},
	"O10": {"body_plan_id": "B01", "trait_ids": ["T02"], "stress_profile": "Sensitive", "contamination_profile": "Standard"},
	"O11": {"body_plan_id": "B04", "trait_ids": ["T03"], "stress_profile": "Standard", "contamination_profile": "Resistant"},
	"O12": {"body_plan_id": "B02", "trait_ids": ["T04", "T09"], "stress_profile": "Standard", "contamination_profile": "Standard"},
	"O13": {"body_plan_id": "B02", "trait_ids": ["T01", "T08"], "stress_profile": "Hardy", "contamination_profile": "Resistant"},
	"O14": {"body_plan_id": "B01", "trait_ids": ["T06"], "stress_profile": "Standard", "contamination_profile": "Resistant"},
	"O15": {"body_plan_id": "B01", "trait_ids": ["T10"], "stress_profile": "Sensitive", "contamination_profile": "Standard"},
	"O16": {"body_plan_id": "B03", "trait_ids": ["T04"], "stress_profile": "Sensitive", "contamination_profile": "Vulnerable"},
	"O17": {"body_plan_id": "B01", "trait_ids": ["T02", "T03"], "stress_profile": "Hardy", "contamination_profile": "Resistant"},
	"O18": {"body_plan_id": "B01", "trait_ids": ["T05", "T08"], "stress_profile": "Standard", "contamination_profile": "Standard"},
	"O19": {"body_plan_id": "B01", "trait_ids": ["T07", "T09"], "stress_profile": "Standard", "contamination_profile": "Resistant"},
	"O20": {"body_plan_id": "B03", "trait_ids": ["T03", "T09"], "stress_profile": "Hardy", "contamination_profile": "Standard"},
	"O21": {"body_plan_id": "B02", "trait_ids": ["T10"], "stress_profile": "Standard", "contamination_profile": "Vulnerable"},
	"O22": {"body_plan_id": "B02", "trait_ids": ["T06", "T08", "T03"], "stress_profile": "Sensitive", "contamination_profile": "Standard"},
}

func validate_launch_population(population: Dictionary) -> Dictionary:
	for field_name: String in ["species", "supports", "campaign", "challenges", "demo"]:
		if not population.has(field_name):
			return _failure("missing_population_field:%s" % field_name)

	var species_result: Dictionary = _validate_species(population["species"])
	if not bool(species_result.get("ok", false)):
		return species_result
	var support_result: Dictionary = _validate_supports(population["supports"])
	if not bool(support_result.get("ok", false)):
		return support_result
	var campaign_result: Dictionary = _validate_campaign(population["campaign"])
	if not bool(campaign_result.get("ok", false)):
		return campaign_result
	var challenge_result: Dictionary = _validate_challenges(population["challenges"])
	if not bool(challenge_result.get("ok", false)):
		return challenge_result
	var demo_result: Dictionary = _validate_demo(population["demo"])
	if not bool(demo_result.get("ok", false)):
		return demo_result

	return {
		"ok": true,
		"error": "",
		"species_count": int(species_result["count"]),
		"support_count": int(support_result["count"]),
		"campaign_count": int(campaign_result["count"]),
		"challenge_count": int(challenge_result["count"]),
	}

func validate_species_support_roster(species: Array, supports: Array) -> Dictionary:
	var species_result: Dictionary = _validate_species(species)
	if not bool(species_result.get("ok", false)):
		return species_result
	if int(species_result.get("count", 0)) != SPECIES_MAX:
		return _failure("incomplete_authored_species_roster:%d" % int(species_result.get("count", 0)))
	var seen_species_value: Variant = species_result.get("seen", {})
	if not seen_species_value is Dictionary:
		return _failure("invalid_species_validation_state")
	var seen_species: Dictionary = seen_species_value
	for raw_species_id: Variant in SPECIES_CANON.keys():
		var species_id: String = String(raw_species_id)
		if not seen_species.has(species_id):
			return _failure("missing_authored_species:%s" % species_id)

	var support_result: Dictionary = _validate_supports(supports)
	if not bool(support_result.get("ok", false)):
		return support_result
	return {
		"ok": true,
		"error": "",
		"species_count": int(species_result["count"]),
		"support_count": int(support_result["count"]),
	}

func _validate_species(value: Variant) -> Dictionary:
	if not value is Array:
		return _failure("invalid_species_population")
	var species: Array = value
	if species.is_empty() or species.size() > SPECIES_MAX:
		return _failure("invalid_launch_species_count:%d" % species.size())
	var seen: Dictionary = {}
	for raw_species: Variant in species:
		if not raw_species is Dictionary:
			return _failure("invalid_species_definition")
		var definition: Dictionary = raw_species
		var species_id: String = String(definition.get("id", ""))
		if not _valid_numbered_id(species_id, "O", 1, SPECIES_MAX) or seen.has(species_id):
			return _failure("invalid_species_id:%s" % species_id)
		if not SPECIES_CANON.has(species_id):
			return _failure("unknown_species_id:%s" % species_id)
		seen[species_id] = true

		var body_plan: String = String(definition.get("body_plan_id", definition.get("body_plan", "")))
		if body_plan not in ["B01", "B02", "B03", "B04"]:
			return _failure("invalid_species_body_plan:%s" % species_id)
		var traits_value: Variant = definition.get("trait_ids", definition.get("traits", null))
		if not (traits_value is Array or traits_value is PackedStringArray):
			return _failure("invalid_species_traits:%s" % species_id)
		var traits: PackedStringArray = PackedStringArray()
		for raw_trait: Variant in traits_value:
			var trait_id: String = String(raw_trait)
			if trait_id not in TRAIT_IDS or trait_id in traits:
				return _failure("invalid_species_trait:%s:%s" % [species_id, trait_id])
			traits.append(trait_id)
		if traits.is_empty() or traits.size() > 3:
			return _failure("invalid_species_trait_count:%s" % species_id)

		var stress_profile: String = String(definition.get("stress_profile", ""))
		var contamination_profile: String = String(definition.get("contamination_profile", ""))
		if stress_profile not in STRESS_PROFILES or contamination_profile not in CONTAMINATION_PROFILES:
			return _failure("invalid_species_profiles:%s" % species_id)
		var name: String = String(definition.get("name", ""))
		if name.strip_edges().is_empty():
			return _failure("missing_species_name:%s" % species_id)
		var tier_min: int = int(definition.get("tier_min", 0))
		var tier_max: int = int(definition.get("tier_max", 0))
		if tier_min < 1 or tier_max > 6 or tier_min > tier_max:
			return _failure("invalid_species_tier_band:%s" % species_id)
		var readability: String = String(definition.get("readability", ""))
		if readability.strip_edges().is_empty():
			return _failure("missing_species_readability:%s" % species_id)
		var special_value: Variant = definition.get("special", {})
		if not special_value is Dictionary:
			return _failure("invalid_species_special:%s" % species_id)
		var special: Dictionary = special_value

		var canon_value: Variant = SPECIES_CANON[species_id]
		if not canon_value is Dictionary:
			return _failure("invalid_species_canon:%s" % species_id)
		var canon: Dictionary = canon_value
		if body_plan != String(canon["body_plan_id"]):
			return _failure("species_body_plan_mismatch:%s" % species_id)
		var expected_traits_value: Variant = canon.get("trait_ids", [])
		var expected_traits: PackedStringArray = PackedStringArray()
		if expected_traits_value is Array or expected_traits_value is PackedStringArray:
			for raw_expected_trait: Variant in expected_traits_value:
				expected_traits.append(String(raw_expected_trait))
		if traits != expected_traits:
			return _failure("species_trait_mismatch:%s" % species_id)
		if stress_profile != String(canon["stress_profile"]) or contamination_profile != String(canon["contamination_profile"]):
			return _failure("species_profile_mismatch:%s" % species_id)

		if "T10" in traits:
			var bounded_value: Variant = special.get("bounded_t10", null)
			if not bounded_value is Dictionary or not bool((bounded_value as Dictionary).get("finite_guard_required", false)):
				return _failure("missing_bounded_t10_contract:%s" % species_id)
		if "T08" in traits:
			var growth_value: Variant = special.get("growth", null)
			if not growth_value is Dictionary:
				return _failure("missing_growth_contract:%s" % species_id)

		if species_id == "O21":
			var o21_t10_value: Variant = special.get("bounded_t10", null)
			if not o21_t10_value is Dictionary or String((o21_t10_value as Dictionary).get("guard", "")) != "once_per_episode":
				return _failure("o21_wake_guard_mismatch")
	return {"ok": true, "error": "", "count": species.size(), "seen": seen}

func _validate_supports(value: Variant) -> Dictionary:
	if not value is Array:
		return _failure("invalid_support_population")
	var supports: Array = value
	if supports.size() != SUPPORT_IDS.size():
		return _failure("invalid_launch_support_count:%d" % supports.size())
	var seen: Dictionary = {}
	for raw_support: Variant in supports:
		if not raw_support is Dictionary:
			return _failure("invalid_support_definition")
		var support: Dictionary = raw_support
		var support_id: String = String(support.get("id", ""))
		if support_id not in SUPPORT_IDS or seen.has(support_id):
			return _failure("invalid_support_id:%s" % support_id)
		seen[support_id] = true
		if String(support.get("family", "")) != support_id:
			return _failure("invalid_support_family:%s" % support_id)
		var name: String = String(support.get("name", ""))
		if name.strip_edges().is_empty():
			return _failure("missing_support_name:%s" % support_id)
		var semantics_value: Variant = support.get("semantics", null)
		if not semantics_value is Dictionary:
			return _failure("missing_support_semantics:%s" % support_id)
		if support_id == "S04" and int((semantics_value as Dictionary).get("target_capacity", 0)) != 1:
			return _failure("s04_capacity_mismatch")
		if support_id == "S05" and not bool((semantics_value as Dictionary).get("finite_conserved_reserve", false)):
			return _failure("s05_reserve_not_conserved")
		if support_id == "S06":
			if not bool(support.get("information_only", false)):
				return _failure("s06_not_information_only")
			if bool((semantics_value as Dictionary).get("direct_mitigation", true)):
				return _failure("s06_direct_mitigation_forbidden")
	for support_id: String in SUPPORT_IDS:
		if not seen.has(support_id):
			return _failure("missing_support:%s" % support_id)
	return {"ok": true, "error": "", "count": supports.size()}

func _validate_campaign(value: Variant) -> Dictionary:
	if not value is Array:
		return _failure("invalid_campaign_population")
	var campaign: Array = value
	if campaign.size() != CAMPAIGN_IDS.size():
		return _failure("invalid_campaign_count:%d" % campaign.size())
	var by_id: Dictionary = {}
	for raw_contract: Variant in campaign:
		if not raw_contract is Dictionary:
			return _failure("invalid_campaign_contract")
		var contract: Dictionary = raw_contract
		var contract_id: String = String(contract.get("id", ""))
		if contract_id not in CAMPAIGN_IDS or by_id.has(contract_id):
			return _failure("invalid_campaign_id:%s" % contract_id)
		by_id[contract_id] = contract
	for contract_id: String in CAMPAIGN_IDS:
		if not by_id.has(contract_id):
			return _failure("missing_campaign_contract:%s" % contract_id)
		var contract_value: Variant = by_id[contract_id]
		if not contract_value is Dictionary:
			return _failure("invalid_campaign_contract:%s" % contract_id)
		var contract: Dictionary = contract_value
		var prerequisites_result: Dictionary = _normalized_string_array(contract.get("prerequisites", []), "campaign_prerequisites:%s" % contract_id)
		if not bool(prerequisites_result.get("ok", false)):
			return prerequisites_result
		var prerequisites: PackedStringArray = prerequisites_result["values"]
		var expected: PackedStringArray = PackedStringArray(CAMPAIGN_PREREQUISITES[contract_id])
		expected.sort()
		if prerequisites != expected:
			return _failure("campaign_prerequisite_mismatch:%s" % contract_id)
		if contract_id >= "C05" and not bool(contract.get("has_dynamic_post_launch_change", false)):
			return _failure("missing_dynamic_post_launch_change:%s" % contract_id)
	return {"ok": true, "error": "", "count": campaign.size()}

func _validate_challenges(value: Variant) -> Dictionary:
	if not value is Array:
		return _failure("invalid_challenge_population")
	var challenges: Array = value
	if challenges.size() > 24:
		return _failure("launch_challenge_template_ceiling_exceeded:%d" % challenges.size())
	var seen: Dictionary = {}
	for raw_challenge: Variant in challenges:
		if not raw_challenge is Dictionary:
			return _failure("invalid_challenge_definition")
		var challenge: Dictionary = raw_challenge
		var challenge_id: String = String(challenge.get("id", ""))
		if challenge_id.is_empty() or seen.has(challenge_id):
			return _failure("invalid_challenge_id:%s" % challenge_id)
		seen[challenge_id] = true
		if not bool(challenge.get("certified_bronze_solution", false)):
			return _failure("challenge_missing_certified_bronze:%s" % challenge_id)
		if not bool(challenge.get("dynamic_significance", false)):
			return _failure("challenge_missing_dynamic_significance:%s" % challenge_id)
		if bool(challenge.get("static_t0_solution_only", false)):
			return _failure("challenge_static_t0_only:%s" % challenge_id)
	return {"ok": true, "error": "", "count": challenges.size()}

func _validate_demo(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _failure("invalid_demo_definition")
	var demo: Dictionary = value
	if int(demo.get("species_total", -1)) != 10:
		return _failure("demo_species_total_mismatch")
	if int(demo.get("documented_species", -1)) != 9 or int(demo.get("discovery_species", -1)) != 1:
		return _failure("demo_species_split_mismatch")
	if int(demo.get("authored_contracts", -1)) != 10:
		return _failure("demo_contract_count_mismatch")
	if int(demo.get("challenge_templates", -1)) != 3:
		return _failure("demo_challenge_count_mismatch")
	if int(demo.get("discovery_contracts", -1)) != 1:
		return _failure("demo_discovery_count_mismatch")
	var supports_result: Dictionary = _normalized_string_array(demo.get("support_ids", []), "demo_support_ids")
	if not bool(supports_result.get("ok", false)):
		return supports_result
	var support_ids: PackedStringArray = supports_result["values"]
	var expected_support_ids: PackedStringArray = DEMO_SUPPORT_IDS.duplicate()
	expected_support_ids.sort()
	if support_ids != expected_support_ids:
		return _failure("demo_support_set_mismatch")
	return {"ok": true, "error": ""}

func _normalized_string_array(value: Variant, label: String) -> Dictionary:
	if not (value is Array or value is PackedStringArray):
		return _failure("invalid_%s" % label)
	var values: PackedStringArray = PackedStringArray()
	for raw_value: Variant in value:
		var text: String = String(raw_value)
		if text.is_empty() or text in values:
			return _failure("invalid_%s" % label)
		values.append(text)
	values.sort()
	return {"ok": true, "error": "", "values": values}

func _valid_numbered_id(value: String, prefix: String, minimum: int, maximum: int) -> bool:
	if value.length() != 3 or not value.begins_with(prefix):
		return false
	var suffix: String = value.substr(1, 2)
	if not suffix.is_valid_int():
		return false
	var number: int = int(suffix)
	return number >= minimum and number <= maximum and value == "%s%02d" % [prefix, number]

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
