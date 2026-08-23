extends SceneTree

const ContentRegistryScript := preload("res://src/content/content_registry.gd")
const ContentPopulationValidatorScript := preload("res://src/content/content_population_validator.gd")

const BODY_IDS := ["B01", "B02", "B03", "B04"]
const TRAIT_IDS := ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08", "T09", "T10"]
const CAMPAIGN_IDS := [
	"C01","C02","C03","C04","C05","C06","C07","C08","C09","C10","C11","C12",
	"C13","C14","C15","C16","C17","C18","C19","C20","C21","C22","C23","C24",
	"C25","C26","C27","C28","C29","C30","C31","C32","C33","C34","C35","C36",
	"C37","C38","C39","C40","C41","C42","C43","C44","C45","C46","C47","C48"
]

var failures: int = 0

func _init() -> void:
	_test_real_launch_content()
	if failures == 0:
		print("launch_roster_content_test_runner: PASS")
		quit(0)
	else:
		push_error("launch_roster_content_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_real_launch_content() -> void:
	var registry: ContentRegistry = ContentRegistryScript.new()
	var loaded: Dictionary = registry.load_families({
		&"body_plans": "res://content/body_plans",
		&"campaign": "res://content/campaign",
		&"species": "res://content/species",
		&"supports": "res://content/supports",
		&"traits": "res://content/traits",
	})
	_expect_true(bool(loaded.get("ok", false)), "real launch content directories load through ContentRegistry")
	if not bool(loaded.get("ok", false)):
		push_error("registry load error: %s" % String(loaded.get("error", "")))
		return

	var species: Array = _definitions(registry, &"species", &"LAUNCH_ROSTER")
	var supports: Array = _definitions(registry, &"supports", &"LAUNCH_SUPPORTS")
	var body_plans: Array = _definitions(registry, &"body_plans", &"LAUNCH_BODY_PLANS")
	var traits: Array = _definitions(registry, &"traits", &"FOUNDATION_TRAITS")
	var campaign: Array = _definitions(registry, &"campaign", &"CAMPAIGN_GRAPH")

	var validated: Dictionary = ContentPopulationValidatorScript.new().validate_species_support_roster(species, supports)
	_expect_true(bool(validated.get("ok", false)), "real authored O01-O22/S01-S06 roster satisfies frozen validator")
	if not bool(validated.get("ok", false)):
		push_error("real roster validation error: %s" % String(validated.get("error", "")))

	_expect_equal(_sorted_ids(body_plans), PackedStringArray(BODY_IDS), "body-plan registry exposes exact B01-B04 set")
	_expect_equal(_sorted_ids(traits), PackedStringArray(TRAIT_IDS), "trait registry exposes exact T01-T10 set")
	_expect_equal(_sorted_ids(campaign), PackedStringArray(CAMPAIGN_IDS), "campaign registry exposes exact C01-C48 set")

	var body_ids: Dictionary = _id_set(body_plans)
	var trait_ids: Dictionary = _id_set(traits)
	for raw_species: Variant in species:
		var definition: Dictionary = _dict(raw_species)
		var species_id: String = String(definition.get("id", ""))
		var body_plan_id: String = String(definition.get("body_plan_id", ""))
		_expect_true(body_ids.has(body_plan_id), "%s body-plan reference resolves through registry" % species_id)
		var refs: Variant = definition.get("trait_ids", [])
		_expect_true(refs is Array, "%s trait references are an array" % species_id)
		if refs is Array:
			for raw_trait_id: Variant in refs:
				_expect_true(trait_ids.has(String(raw_trait_id)), "%s trait reference %s resolves through registry" % [species_id, String(raw_trait_id)])
		var special: Dictionary = _dict(definition.get("special", {}))
		var growth: Dictionary = _dict(special.get("growth", {}))
		if not growth.is_empty():
			var target_body_plan_id: String = String(growth.get("target_body_plan_id", ""))
			if not target_body_plan_id.is_empty():
				_expect_true(body_ids.has(target_body_plan_id), "%s growth target body-plan resolves through registry" % species_id)

	var campaign_ids: Dictionary = _id_set(campaign)
	var successor_counts: Dictionary = {}
	for raw_contract: Variant in campaign:
		var contract: Dictionary = _dict(raw_contract)
		var contract_id: String = String(contract.get("id", ""))
		var prereqs: Variant = contract.get("prerequisites", [])
		_expect_true(prereqs is Array, "%s prerequisites are an array" % contract_id)
		_expect_true(bool(contract.get("bronze_prerequisites_only", false)), "%s progression prerequisites are Bronze-only" % contract_id)
		_expect_equal(bool(contract.get("dynamic_post_launch_required", false)), int(contract_id.trim_prefix("C")) >= 5, "%s dynamic gate matches C05-C48 freeze" % contract_id)
		if prereqs is Array:
			for raw_prereq: Variant in prereqs:
				var prereq: String = String(raw_prereq)
				_expect_true(campaign_ids.has(prereq), "%s prerequisite %s resolves through registry" % [contract_id, prereq])
				successor_counts[prereq] = int(successor_counts.get(prereq, 0)) + 1

	var campaign_payload: Dictionary = _payload_by_id(registry.ordered_documents(&"campaign"), &"CAMPAIGN_GRAPH")
	_expect_equal(String(campaign_payload.get("progression_currency", "")), "Bronze completion", "campaign progression currency is frozen")
	_expect_equal(String(campaign_payload.get("challenge_mode_gate", "")), "Bronze(C16)", "Challenge gate is frozen")
	_expect_true(not successor_counts.has("C48"), "C48 is terminal")
	for index: int in range(1, 48):
		var cid: String = "C%02d" % index
		_expect_true(successor_counts.has(cid), "%s has at least one campaign successor" % cid)

	var species_by_id: Dictionary = _by_id(species)
	var supports_by_id: Dictionary = _by_id(supports)
	var o03: Dictionary = _dict(species_by_id.get("O03", {}))
	var o21: Dictionary = _dict(species_by_id.get("O21", {}))
	var s06: Dictionary = _dict(supports_by_id.get("S06", {}))
	var o03_growth: Dictionary = _dict(_dict(o03.get("special", {})).get("growth", {}))
	var o21_t10: Dictionary = _dict(_dict(o21.get("special", {})).get("bounded_t10", {}))
	var s06_semantics: Dictionary = _dict(s06.get("semantics", {}))
	_expect_equal(String(o03_growth.get("target_body_plan_id", "")), "B02", "O03 keeps canonical B01 to B02 growth reference")
	_expect_equal(String(o21_t10.get("guard", "")), "once_per_episode", "O21 wake cleanse is one pulse per sleep episode")
	_expect_true(bool(s06.get("information_only", false)), "S06 is marked information-only")
	_expect_true(not bool(s06_semantics.get("direct_mitigation", true)), "S06 carries no direct mitigation")

	var o01_runtime: Dictionary = _payload_by_id(registry.ordered_documents(&"species"), &"O01")
	_expect_true(o01_runtime.get("current_footprints", null) is Dictionary, "existing O01 vertical-slice planning document remains available")

func _definitions(registry: ContentRegistry, kind: StringName, id: StringName) -> Array:
	var payload: Dictionary = _payload_by_id(registry.ordered_documents(kind), id)
	var value: Variant = payload.get("definitions", null)
	_expect_true(value is Array, "%s/%s exposes definitions" % [String(kind), String(id)])
	return value if value is Array else []

func _payload_by_id(documents: Array[ContentDocument], id: StringName) -> Dictionary:
	for document: ContentDocument in documents:
		if document.id == id:
			return document.payload.duplicate(true)
	return {}

func _by_id(definitions: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for raw_definition: Variant in definitions:
		var definition: Dictionary = _dict(raw_definition)
		by_id[String(definition.get("id", ""))] = definition
	return by_id

func _id_set(definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_definition: Variant in definitions:
		var definition: Dictionary = _dict(raw_definition)
		result[String(definition.get("id", ""))] = true
	return result

func _sorted_ids(definitions: Array) -> PackedStringArray:
	var ids := PackedStringArray()
	for raw_definition: Variant in definitions:
		ids.append(String(_dict(raw_definition).get("id", "")))
	ids.sort()
	return ids

func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
