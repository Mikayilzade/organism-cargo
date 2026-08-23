extends SceneTree

const ContentRegistryScript := preload("res://src/content/content_registry.gd")
const ContentPopulationValidatorScript := preload("res://src/content/content_population_validator.gd")

var failures: int = 0

func _init() -> void:
	_test_real_launch_species_and_support_roster()
	if failures == 0:
		print("launch_roster_content_test_runner: PASS")
		quit(0)
	else:
		push_error("launch_roster_content_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_real_launch_species_and_support_roster() -> void:
	var registry: ContentRegistry = ContentRegistryScript.new()
	var loaded: Dictionary = registry.load_families({&"species": "res://content/species", &"supports": "res://content/supports"})
	_expect_true(bool(loaded.get("ok", false)), "real species/support directories load through ContentRegistry")
	if not bool(loaded.get("ok", false)):
		return

	var species_roster: Dictionary = _payload_by_id(registry.ordered_documents(&"species"), &"LAUNCH_ROSTER")
	var support_roster: Dictionary = _payload_by_id(registry.ordered_documents(&"supports"), &"LAUNCH_SUPPORTS")
	var species_value: Variant = species_roster.get("definitions", null)
	var supports_value: Variant = support_roster.get("definitions", null)
	_expect_true(species_value is Array, "launch species roster document exposes definitions")
	_expect_true(supports_value is Array, "launch support roster document exposes definitions")
	if not species_value is Array or not supports_value is Array:
		return

	var species: Array = species_value
	var supports: Array = supports_value
	var validated: Dictionary = ContentPopulationValidatorScript.new().validate_species_support_roster(species, supports)
	_expect_true(bool(validated.get("ok", false)), "real authored O01-O22/S01-S06 roster satisfies frozen validator")
	if not bool(validated.get("ok", false)):
		push_error("real roster validation error: %s" % String(validated.get("error", "")))
		return

	_expect_equal(species.size(), 22, "real authored species roster contains O01-O22")
	_expect_equal(supports.size(), 6, "real authored support roster contains S01-S06")

	var species_by_id: Dictionary = _by_id(species)
	var supports_by_id: Dictionary = _by_id(supports)
	var o03: Dictionary = _dict(species_by_id.get("O03", {}))
	var o21: Dictionary = _dict(species_by_id.get("O21", {}))
	var s06: Dictionary = _dict(supports_by_id.get("S06", {}))
	var o03_special: Dictionary = _dict(o03.get("special", {}))
	var o03_growth: Dictionary = _dict(o03_special.get("growth", {}))
	var o21_special: Dictionary = _dict(o21.get("special", {}))
	var o21_t10: Dictionary = _dict(o21_special.get("bounded_t10", {}))
	var s06_semantics: Dictionary = _dict(s06.get("semantics", {}))

	_expect_equal(String(o03_growth.get("target_body_plan_id", "")), "B02", "O03 keeps canonical B01 to B02 growth reference")
	_expect_equal(String(o21_t10.get("guard", "")), "once_per_episode", "O21 wake cleanse is one pulse per sleep episode")
	_expect_true(bool(s06.get("information_only", false)), "S06 is marked information-only")
	_expect_true(not bool(s06_semantics.get("direct_mitigation", true)), "S06 carries no direct mitigation")

	var o01_runtime: Dictionary = _payload_by_id(registry.ordered_documents(&"species"), &"O01")
	var footprint_value: Variant = o01_runtime.get("current_footprints", null)
	_expect_true(footprint_value is Dictionary, "existing O01 vertical-slice planning document remains available")

func _payload_by_id(documents: Array[ContentDocument], id: StringName) -> Dictionary:
	for document: ContentDocument in documents:
		if document.id == id:
			return document.payload.duplicate(true)
	return {}

func _by_id(definitions: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			continue
		var definition: Dictionary = raw_definition
		by_id[String(definition.get("id", ""))] = definition
	return by_id

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
